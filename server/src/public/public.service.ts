import { BadRequestException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AccessType, BookStatus, PaymentStatus } from '../generated/prisma/enums.js';
import type { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';
import type { ReadingProgressDto } from './public.dto.js';

@Injectable()
export class PublicService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async catalog() {
    const books = await this.prisma.book.findMany({
      where: this.publicBookWhere(),
      include: { author: true, category: true, _count: { select: { readingProgress: { where: { activeSeconds: { gte: 120 } } } } } },
      orderBy: [{ isNew: 'desc' }, { publishedAt: 'desc' }],
    });
    return Promise.all(books.map((book) => this.presentBook(book)));
  }

  categories() {
    return this.prisma.category.findMany({
      where: { deletedAt: null, books: { some: this.publicBookWhere() } },
      orderBy: { name: 'asc' },
    });
  }

  async book(slug: string) {
    const book = await this.prisma.book.findFirst({
      where: { slug, ...this.publicBookWhere() },
      include: { author: true, category: true, _count: { select: { readingProgress: { where: { activeSeconds: { gte: 120 } } } } } },
    });
    if (!book) throw new NotFoundException('Китеп табылган жок');
    return this.presentBook(book);
  }

  async buy(readerId: string, bookId: string) {
    const book = await this.requirePublishedBook(bookId);
    if (book.accessType === AccessType.FREE) {
      await this.addToLibrary(readerId, bookId);
      return { success: true, accessType: AccessType.FREE };
    }
    if (book.accessType === AccessType.RENTAL) {
      throw new BadRequestException('Бул китеп ижарага гана берилет');
    }
    this.requireLocalPayments();
    const existing = await this.prisma.purchase.findFirst({
      where: { readerId, bookId, status: PaymentStatus.COMPLETED },
    });
    if (existing) throw new BadRequestException('Бул китеп мурда сатып алынган');
    const purchase = await this.prisma.purchase.create({ data: {
      readerId, bookId, amount: book.price, reference: `local-purchase-${randomUUID()}`,
    } });
    return { success: true, purchase };
  }

  async rent(readerId: string, bookId: string) {
    const book = await this.requirePublishedBook(bookId);
    if (book.accessType === AccessType.FREE || !book.rentalPrice) {
      throw new BadRequestException('Бул китеп ижарага берилбейт');
    }
    this.requireLocalPayments();
    const [purchase, activeRental] = await Promise.all([
      this.prisma.purchase.findFirst({ where: { readerId, bookId, status: PaymentStatus.COMPLETED } }),
      this.prisma.rental.findFirst({ where: { readerId, bookId, status: PaymentStatus.COMPLETED, endsAt: { gt: new Date() } } }),
    ]);
    if (purchase) throw new BadRequestException('Бул китеп сизде бар');
    if (activeRental) throw new BadRequestException('Бул китептин ижарасы активдүү');
    const startsAt = new Date();
    const endsAt = new Date(startsAt.getTime() + book.rentalDays * 24 * 60 * 60 * 1000);
    const rental = await this.prisma.rental.create({
      data: {
        readerId,
        bookId,
        amount: book.rentalPrice,
        startsAt,
        endsAt,
      },
    });
    return { success: true, rental };
  }

  /**
   * "My books": everything bought (even if later archived), active rentals, and free
   * books the reader added or opened while they are still in the catalog.
   */
  async library(readerId: string) {
    const ownedBook = { epubKey: { not: null } } as const;
    const [purchases, rentals, entries] = await Promise.all([
      this.prisma.purchase.findMany({
        where: { readerId, status: PaymentStatus.COMPLETED, book: ownedBook },
        include: { book: { include: { author: true, category: true } } },
      }),
      this.prisma.rental.findMany({
        where: { readerId, status: PaymentStatus.COMPLETED, endsAt: { gt: new Date() }, book: ownedBook },
        include: { book: { include: { author: true, category: true } } },
        orderBy: { endsAt: 'desc' },
      }),
      this.prisma.libraryEntry.findMany({
        where: { readerId, book: { accessType: AccessType.FREE, ...this.publicBookWhere() } },
        include: { book: { include: { author: true, category: true } } },
        orderBy: { createdAt: 'desc' },
      }),
    ]);
    type Item = { book: (typeof entries)[number]['book']; readerAccess: string; rentalEndsAt?: Date };
    const unique = new Map<string, Item>();
    for (const item of entries) unique.set(item.book.id, { book: item.book, readerAccess: AccessType.FREE });
    for (const item of rentals) {
      if (!unique.has(item.book.id) || unique.get(item.book.id)!.readerAccess === AccessType.FREE) {
        unique.set(item.book.id, { book: item.book, readerAccess: AccessType.RENTAL, rentalEndsAt: item.endsAt });
      }
    }
    for (const item of purchases) unique.set(item.book.id, { book: item.book, readerAccess: AccessType.PURCHASE });
    return Promise.all([...unique.values()].map(async (item) => ({
      ...await this.presentBook(item.book),
      readerAccess: item.readerAccess,
      rentalEndsAt: item.rentalEndsAt ?? null,
    })));
  }

  async readerFile(readerId: string, bookId: string) {
    const book = await this.prisma.book.findFirst({ where: { id: bookId, epubKey: { not: null } } });
    if (!book?.epubKey) throw new NotFoundException('Китеп табылган жок');
    if (!(await this.hasAccess(readerId, book))) {
      throw new BadRequestException('Китепке жеткилик жок');
    }
    if (book.accessType === AccessType.FREE) await this.addToLibrary(readerId, bookId);
    const url = await this.storage.signedUrl(book.epubKey);
    return { url, manifestUrl: url };
  }

  async saveProgress(readerId: string, dto: ReadingProgressDto) {
    const book = await this.prisma.book.findUnique({ where: { id: dto.bookId } });
    if (!book || !(await this.hasAccess(readerId, book))) {
      throw new NotFoundException('Китеп табылган жок');
    }
    return this.prisma.readingProgress.upsert({
      where: { readerId_bookId: { readerId, bookId: dto.bookId } },
      create: {
        readerId, bookId: dto.bookId, progression: dto.progression,
        activeSeconds: dto.activeSeconds, locator: dto.locator as Prisma.InputJsonValue | undefined,
      },
      update: {
        progression: dto.progression, locator: dto.locator as Prisma.InputJsonValue | undefined,
        activeSeconds: { increment: dto.activeSeconds }, lastReadAt: new Date(),
      },
    });
  }

  /** Where the reader stopped in a book, so another device can resume there. */
  async readingPosition(readerId: string, bookId: string) {
    const progress = await this.prisma.readingProgress.findUnique({
      where: { readerId_bookId: { readerId, bookId } },
      select: { locator: true, progression: true, lastReadAt: true },
    });
    return progress ?? { locator: null, progression: 0, lastReadAt: null };
  }

  async recent(readerId: string) {
    const items = await this.prisma.readingProgress.findMany({
      where: { readerId, activeSeconds: { gte: 120 } },
      include: { book: { include: { author: true, category: true } } },
      orderBy: { lastReadAt: 'desc' },
      take: 10,
    });
    const visible = [];
    for (const item of items) {
      if (visible.length === 3) break;
      if (await this.hasAccess(readerId, item.book)) visible.push(item);
    }
    return Promise.all(visible.map(async (item) => ({
      ...item,
      book: await this.presentBook(item.book),
    })));
  }

  /** Bought or actively rented books stay readable even after they leave the catalog. */
  private async hasAccess(
    readerId: string,
    book: { id: string; accessType: AccessType; status: BookStatus; deletedAt: Date | null; coverKey: string | null; epubKey: string | null },
  ) {
    const isPublic = book.status === BookStatus.PUBLISHED && !book.deletedAt && Boolean(book.coverKey && book.epubKey);
    if (book.accessType === AccessType.FREE) return isPublic;
    const [purchase, rental] = await Promise.all([
      this.prisma.purchase.findFirst({ where: { readerId, bookId: book.id, status: PaymentStatus.COMPLETED }, select: { id: true } }),
      this.prisma.rental.findFirst({
        where: { readerId, bookId: book.id, status: PaymentStatus.COMPLETED, endsAt: { gt: new Date() } },
        select: { id: true },
      }),
    ]);
    return Boolean(purchase || rental);
  }

  /**
   * Purchases and rentals complete instantly with no real payment. That is only
   * allowed with PAYMENT_MODE=local (the default outside production).
   */
  private requireLocalPayments() {
    const mode = process.env.PAYMENT_MODE ?? (process.env.NODE_ENV === 'production' ? 'none' : 'local');
    if (mode !== 'local') {
      throw new ServiceUnavailableException('Төлөм системасы азырынча туташтырылган эмес');
    }
  }

  private async addToLibrary(readerId: string, bookId: string) {
    await this.prisma.libraryEntry.upsert({
      where: { readerId_bookId: { readerId, bookId } },
      create: { readerId, bookId },
      update: {},
    });
  }

  private async requirePublishedBook(id: string) {
    const book = await this.prisma.book.findFirst({
      where: { id, ...this.publicBookWhere() },
    });
    if (!book) throw new NotFoundException('Китеп табылган жок');
    return book;
  }

  private publicBookWhere() {
    return {
      status: BookStatus.PUBLISHED,
      deletedAt: null,
      coverKey: { not: null },
      epubKey: { not: null },
    } as const;
  }

  private async presentBook<T extends {
    coverKey: string | null;
    epubKey?: string | null;
    price: unknown;
    rentalPrice: unknown;
    _count?: { readingProgress?: number };
  }>(book: T) {
    const { _count, ...rest } = book;
    return {
      ...rest,
      price: Number(book.price),
      rentalPrice: book.rentalPrice == null ? null : Number(book.rentalPrice),
      coverUrl: book.coverKey ? await this.storage.signedUrl(book.coverKey) : null,
      // Language comes from the EPUB itself; readers = people who read at least 2 minutes.
      language: book.epubKey ? await this.storage.publicationLanguage(book.epubKey) : null,
      readersCount: _count?.readingProgress ?? null,
    };
  }
}
