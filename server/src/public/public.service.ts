import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
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
      include: { author: true, category: true },
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
      include: { author: true, category: true },
    });
    if (!book) throw new NotFoundException('Китеп табылган жок');
    return this.presentBook(book);
  }

  async buy(readerId: string, bookId: string) {
    const book = await this.requirePublishedBook(bookId);
    if (book.accessType === AccessType.FREE) {
      return { success: true, accessType: AccessType.FREE };
    }
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
    if (!book.rentalPrice) throw new BadRequestException('Бул китеп ижарага берилбейт');
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

  async library(readerId: string) {
    const [purchases, rentals, freeBooks] = await Promise.all([
      this.prisma.purchase.findMany({
        where: { readerId, status: PaymentStatus.COMPLETED, book: this.publicBookWhere() },
        include: { book: { include: { author: true, category: true } } },
      }),
      this.prisma.rental.findMany({
        where: { readerId, status: PaymentStatus.COMPLETED, endsAt: { gt: new Date() }, book: this.publicBookWhere() },
        include: { book: { include: { author: true, category: true } } },
      }),
      this.prisma.book.findMany({
        where: { accessType: AccessType.FREE, ...this.publicBookWhere() },
        include: { author: true, category: true },
      }),
    ]);
    const unique = new Map<string, { book: (typeof freeBooks)[number]; readerAccess: string; rentalEndsAt?: Date }>();
    for (const book of freeBooks) unique.set(book.id, { book, readerAccess: AccessType.FREE });
    for (const item of rentals) unique.set(item.book.id, { book: item.book, readerAccess: AccessType.RENTAL, rentalEndsAt: item.endsAt });
    for (const item of purchases) unique.set(item.book.id, { book: item.book, readerAccess: AccessType.PURCHASE });
    return Promise.all([...unique.values()].map(async (item) => ({
      ...await this.presentBook(item.book),
      readerAccess: item.readerAccess,
      rentalEndsAt: item.rentalEndsAt ?? null,
    })));
  }

  async readerFile(readerId: string, bookId: string) {
    const book = await this.prisma.book.findFirst({
      where: { id: bookId, coverKey: { not: null }, epubKey: { not: null } },
    });
    if (!book) throw new NotFoundException('Китеп табылган жок');
    const hasPurchase = await this.prisma.purchase.findFirst({
      where: { readerId, bookId, status: PaymentStatus.COMPLETED },
    });
    const hasRental = await this.prisma.rental.findFirst({
      where: { readerId, bookId, status: PaymentStatus.COMPLETED, endsAt: { gt: new Date() } },
    });
    const isPublicFree = book.status === BookStatus.PUBLISHED && !book.deletedAt
      && book.accessType === AccessType.FREE;
    if (!isPublicFree && !hasPurchase && !hasRental) {
      throw new BadRequestException('Китепке жеткилик жок');
    }
    if (!book.epubKey) throw new NotFoundException('EPUB файлы жүктөлө элек');
    const url = await this.storage.signedUrl(book.epubKey);
    return { url, manifestUrl: url };
  }

  async saveProgress(readerId: string, dto: ReadingProgressDto) {
    await this.requirePublishedBook(dto.bookId);
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

  async recent(readerId: string) {
    const items = await this.prisma.readingProgress.findMany({
      where: { readerId, activeSeconds: { gte: 120 }, book: { status: BookStatus.PUBLISHED, deletedAt: null } },
      include: { book: { include: { author: true, category: true } } },
      orderBy: { lastReadAt: 'desc' },
      take: 3,
    });
    return Promise.all(items.map(async (item) => ({
      ...item,
      book: await this.presentBook(item.book),
    })));
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

  private async presentBook<T extends { coverKey: string | null; price: unknown; rentalPrice: unknown }>(book: T) {
    return {
      ...book,
      price: Number(book.price),
      rentalPrice: book.rentalPrice == null ? null : Number(book.rentalPrice),
      coverUrl: book.coverKey ? await this.storage.signedUrl(book.coverKey) : null,
    };
  }
}
