import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AccessType, BookStatus, PaymentStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';

@Injectable()
export class PublicService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async catalog() {
    const books = await this.prisma.book.findMany({
      where: { status: BookStatus.PUBLISHED, deletedAt: null },
      include: { author: true, category: true },
      orderBy: [{ isNew: 'desc' }, { publishedAt: 'desc' }],
    });
    return Promise.all(books.map((book) => this.presentBook(book)));
  }

  categories() {
    return this.prisma.category.findMany({
      where: { deletedAt: null, books: { some: { status: BookStatus.PUBLISHED, deletedAt: null } } },
      orderBy: { name: 'asc' },
    });
  }

  async book(slug: string) {
    const book = await this.prisma.book.findFirst({
      where: { slug, status: BookStatus.PUBLISHED, deletedAt: null },
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
    const purchase = await this.prisma.purchase.upsert({
      where: { reference: `local-purchase-${readerId}-${bookId}` },
      create: {
        readerId,
        bookId,
        amount: book.price,
        reference: `local-purchase-${readerId}-${bookId}`,
      },
      update: { status: PaymentStatus.COMPLETED },
    });
    return { success: true, purchase };
  }

  async rent(readerId: string, bookId: string) {
    const book = await this.requirePublishedBook(bookId);
    if (!book.rentalPrice) throw new BadRequestException('Бул китеп ижарага берилбейт');
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
        where: { readerId, status: PaymentStatus.COMPLETED },
        include: { book: { include: { author: true, category: true } } },
      }),
      this.prisma.rental.findMany({
        where: { readerId, status: PaymentStatus.COMPLETED, endsAt: { gt: new Date() } },
        include: { book: { include: { author: true, category: true } } },
      }),
      this.prisma.book.findMany({
        where: { accessType: AccessType.FREE, status: BookStatus.PUBLISHED, deletedAt: null },
        include: { author: true, category: true },
      }),
    ]);
    const unique = new Map(
      [...purchases.map((item) => item.book), ...rentals.map((item) => item.book), ...freeBooks]
        .map((book) => [book.id, book]),
    );
    return Promise.all([...unique.values()].map((book) => this.presentBook(book)));
  }

  async readerFile(readerId: string, bookId: string) {
    const book = await this.requirePublishedBook(bookId);
    const hasPurchase = await this.prisma.purchase.findFirst({
      where: { readerId, bookId, status: PaymentStatus.COMPLETED },
    });
    const hasRental = await this.prisma.rental.findFirst({
      where: { readerId, bookId, status: PaymentStatus.COMPLETED, endsAt: { gt: new Date() } },
    });
    if (book.accessType !== AccessType.FREE && !hasPurchase && !hasRental) {
      throw new BadRequestException('Китепке жеткилик жок');
    }
    if (!book.epubKey) throw new NotFoundException('EPUB файлы жүктөлө элек');
    return { url: await this.storage.signedUrl(book.epubKey), expiresInSeconds: 900 };
  }

  private async requirePublishedBook(id: string) {
    const book = await this.prisma.book.findFirst({
      where: { id, status: BookStatus.PUBLISHED, deletedAt: null },
    });
    if (!book) throw new NotFoundException('Китеп табылган жок');
    return book;
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
