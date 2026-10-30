import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import type { Express } from 'express';
import { AccessType, BookStatus, PaymentStatus } from '../generated/prisma/enums.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { StorageService } from '../storage/storage.service.js';
import {
  BlockReaderDto,
  CreateAuthorDto,
  CreateBookDto,
  CreateCategoryDto,
  UpdateAuthorDto,
  UpdateBookDto,
  UpdateCategoryDto,
} from './admin.dto.js';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  me(id: string) {
    return this.prisma.admin.findUniqueOrThrow({
      where: { id },
      select: { id: true, name: true, email: true, role: true },
    });
  }

  /** Editors only see catalog numbers; money and readers are for superadmins. */
  async dashboard(full: boolean) {
    const books = await this.prisma.book.count({ where: { deletedAt: null } });
    if (!full) return { books };
    const completed = { status: PaymentStatus.COMPLETED };
    const [readers, sales, salesRevenue, activeRentals, rentalRevenue] = await Promise.all([
      this.prisma.reader.count({ where: { deletedAt: null } }),
      this.prisma.purchase.count({ where: completed }),
      this.prisma.purchase.aggregate({ where: completed, _sum: { amount: true } }),
      this.prisma.rental.count({ where: { ...completed, endsAt: { gt: new Date() } } }),
      this.prisma.rental.aggregate({ where: completed, _sum: { amount: true } }),
    ]);
    const sale = Number(salesRevenue._sum.amount ?? 0);
    const rental = Number(rentalRevenue._sum.amount ?? 0);
    return {
      books,
      readers,
      sales,
      activeRentals,
      salesRevenue: sale,
      rentalRevenue: rental,
      revenue: sale + rental,
      currency: 'KGS',
    };
  }

  listAuthors() {
    return this.prisma.author.findMany({
      where: { deletedAt: null },
      include: { _count: { select: { books: true } } },
      orderBy: { name: 'asc' },
    });
  }

  async createAuthor(dto: CreateAuthorDto, adminId: string) {
    const author = await this.prisma.author.create({ data: dto });
    await this.audit(adminId, 'CREATE', 'Author', author.id, { name: author.name });
    return author;
  }

  async updateAuthor(id: string, dto: UpdateAuthorDto, adminId: string) {
    await this.requireAuthor(id);
    const author = await this.prisma.author.update({ where: { id }, data: dto });
    await this.audit(adminId, 'UPDATE', 'Author', id, dto);
    return author;
  }

  async deleteAuthor(id: string, adminId: string) {
    await this.requireAuthor(id);
    const books = await this.prisma.book.count({ where: { authorId: id, deletedAt: null } });
    if (books) throw new BadRequestException('Автордун активдүү китептери бар');
    await this.prisma.author.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.audit(adminId, 'DELETE', 'Author', id);
    return { success: true };
  }

  listCategories() {
    return this.prisma.category.findMany({
      where: { deletedAt: null },
      include: { _count: { select: { books: true } } },
      orderBy: { name: 'asc' },
    });
  }

  async createCategory(dto: CreateCategoryDto, adminId: string) {
    const category = await this.prisma.category.create({ data: dto });
    await this.audit(adminId, 'CREATE', 'Category', category.id, { name: category.name });
    return category;
  }

  async updateCategory(id: string, dto: UpdateCategoryDto, adminId: string) {
    await this.requireCategory(id);
    const category = await this.prisma.category.update({ where: { id }, data: dto });
    await this.audit(adminId, 'UPDATE', 'Category', id, dto);
    return category;
  }

  async deleteCategory(id: string, adminId: string) {
    await this.requireCategory(id);
    const books = await this.prisma.book.count({ where: { categoryId: id, deletedAt: null } });
    if (books) throw new BadRequestException('Категориянын активдүү китептери бар');
    await this.prisma.category.update({ where: { id }, data: { deletedAt: new Date() } });
    await this.audit(adminId, 'DELETE', 'Category', id);
    return { success: true };
  }

  listBooks() {
    return this.prisma.book.findMany({
      where: { deletedAt: null },
      include: {
        author: true,
        category: true,
        _count: { select: { purchases: true, rentals: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createBook(dto: CreateBookDto, adminId: string) {
    await Promise.all([this.requireAuthor(dto.authorId), this.requireCategory(dto.categoryId)]);
    this.validateAccess(dto);
    if (dto.status === BookStatus.PUBLISHED) {
      throw new BadRequestException('Жарыялоо үчүн мукаба жана EPUB жүктөңүз');
    }
    const book = await this.prisma.book.create({
      data: {
        ...dto,
        publishedAt: null,
      },
      include: { author: true, category: true },
    });
    await this.audit(adminId, 'CREATE', 'Book', book.id, { title: book.title });
    return book;
  }

  async createBookWithFiles(
    dto: CreateBookDto,
    files: { cover?: Express.Multer.File[]; epub?: Express.Multer.File[] },
    adminId: string,
  ) {
    const cover = files.cover?.[0];
    const epub = files.epub?.[0];
    if (!cover || !epub) throw new BadRequestException('Жаңы китепке мукаба жана EPUB милдеттүү');
    await Promise.all([this.requireAuthor(dto.authorId), this.requireCategory(dto.categoryId)]);
    this.validateAccess(dto);
    let coverKey: string | undefined;
    let epubKey: string | undefined;
    try {
      coverKey = await this.storage.upload('covers', cover);
      epubKey = await this.storage.upload('epubs', epub);
      const book = await this.prisma.book.create({
        data: {
          ...dto,
          coverKey,
          epubKey,
          publishedAt: dto.status === BookStatus.PUBLISHED ? new Date() : null,
        },
        include: { author: true, category: true },
      });
      await this.audit(adminId, 'CREATE', 'Book', book.id, { title: book.title, files: true });
      return book;
    } catch (error) {
      await Promise.all([this.storage.remove(coverKey), this.storage.remove(epubKey)]);
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Мындай URL белгиси бар китеп мурунтан бар');
      }
      throw error;
    }
  }

  async updateBook(id: string, dto: UpdateBookDto, adminId: string) {
    const current = await this.requireBook(id);
    if (dto.authorId) await this.requireAuthor(dto.authorId);
    if (dto.categoryId) await this.requireCategory(dto.categoryId);
    this.validateAccess({ ...current, ...dto });
    if (dto.status === BookStatus.PUBLISHED && (!current.coverKey || !current.epubKey)) {
      throw new BadRequestException('Жарыялоо үчүн мукаба жана EPUB жүктөңүз');
    }
    const book = await this.prisma.book.update({
      where: { id },
      data: {
        ...dto,
        publishedAt:
          dto.status === BookStatus.PUBLISHED && !current.publishedAt
            ? new Date()
            : dto.status && dto.status !== BookStatus.PUBLISHED
              ? null
              : undefined,
      },
      include: { author: true, category: true },
    });
    await this.audit(adminId, 'UPDATE', 'Book', id, dto);
    return book;
  }

  async deleteBook(id: string, adminId: string) {
    await this.requireBook(id);
    await this.prisma.book.update({
      where: { id },
      data: { deletedAt: new Date(), status: BookStatus.ARCHIVED },
    });
    await this.audit(adminId, 'DELETE', 'Book', id);
    return { success: true };
  }

  async uploadBookFiles(
    id: string,
    files: { cover?: Express.Multer.File[]; epub?: Express.Multer.File[] },
    adminId: string,
  ) {
    const current = await this.requireBook(id);
    let coverKey: string | undefined;
    let epubKey: string | undefined;
    try {
      coverKey = files.cover?.[0] ? await this.storage.upload('covers', files.cover[0]) : undefined;
      epubKey = files.epub?.[0] ? await this.storage.upload('epubs', files.epub[0]) : undefined;
      if (!coverKey && !epubKey) throw new BadRequestException('Файл тандалган жок');
      const book = await this.prisma.book.update({
        where: { id }, data: { coverKey, epubKey }, include: { author: true, category: true },
      });
      await Promise.all([
        coverKey ? this.storage.remove(current.coverKey) : Promise.resolve(),
        epubKey ? this.storage.remove(current.epubKey) : Promise.resolve(),
      ]);
      await this.audit(adminId, 'UPLOAD', 'Book', id, { coverKey, epubKey });
      return book;
    } catch (error) {
      await Promise.all([this.storage.remove(coverKey), this.storage.remove(epubKey)]);
      throw error;
    }
  }

  listReaders() {
    return this.prisma.reader.findMany({
      where: { deletedAt: null },
      include: { _count: { select: { purchases: true, rentals: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async blockReader(id: string, dto: BlockReaderDto, adminId: string) {
    const reader = await this.prisma.reader.update({
      where: { id },
      data: {
        isBlocked: dto.isBlocked,
        blockNote: dto.isBlocked ? dto.blockNote : null,
      },
    });
    await this.audit(adminId, dto.isBlocked ? 'BLOCK' : 'UNBLOCK', 'Reader', id, {
      note: dto.blockNote,
    });
    return reader;
  }

  listPurchases() {
    return this.prisma.purchase.findMany({
      include: { book: { include: { author: true } }, reader: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  listRentals() {
    return this.prisma.rental.findMany({
      include: { book: { include: { author: true } }, reader: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Sales and rentals per book for a period of Bishkek calendar days. */
  async salesReport(from?: string, to?: string) {
    const period = this.period(from, to);
    const where = { status: PaymentStatus.COMPLETED, createdAt: { gte: period.gte, lte: period.lte } };
    const [salesGroups, rentalGroups] = await Promise.all([
      this.prisma.purchase.groupBy({ by: ['bookId'], where, _count: { _all: true }, _sum: { amount: true } }),
      this.prisma.rental.groupBy({ by: ['bookId'], where, _count: { _all: true }, _sum: { amount: true } }),
    ]);
    const ids = [...new Set([...salesGroups, ...rentalGroups].map((group) => group.bookId))];
    const books = await this.prisma.book.findMany({ where: { id: { in: ids } }, include: { author: true } });
    const byId = new Map(books.map((book) => [book.id, book]));
    const salesById = new Map(salesGroups.map((group) => [group.bookId, group]));
    const rentalsById = new Map(rentalGroups.map((group) => [group.bookId, group]));
    const items = ids.map((bookId) => {
      const sale = salesById.get(bookId);
      const rental = rentalsById.get(bookId);
      const salesRevenue = Number(sale?._sum.amount ?? 0);
      const rentalRevenue = Number(rental?._sum.amount ?? 0);
      return {
        bookId,
        title: byId.get(bookId)?.title ?? 'Белгисиз китеп',
        author: byId.get(bookId)?.author.name ?? 'Белгисиз автор',
        quantity: sale?._count._all ?? 0,
        rentals: rental?._count._all ?? 0,
        salesRevenue,
        rentalRevenue,
        revenue: salesRevenue + rentalRevenue,
        currency: 'KGS',
      };
    }).sort((a, b) => b.revenue - a.revenue);
    const sum = (key: 'quantity' | 'rentals' | 'salesRevenue' | 'rentalRevenue' | 'revenue') =>
      items.reduce((total, item) => total + item[key], 0);
    return {
      from: period.from,
      to: period.to,
      timeZone: 'Asia/Bishkek',
      totalQuantity: sum('quantity'),
      totalRentals: sum('rentals'),
      salesRevenue: sum('salesRevenue'),
      rentalRevenue: sum('rentalRevenue'),
      totalRevenue: sum('revenue'),
      items,
    };
  }

  auditLogs() {
    return this.prisma.auditLog.findMany({
      include: { admin: { select: { name: true, email: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  /** Calendar days in Bishkek (UTC+6, no daylight saving). Defaults to this month so far. */
  private period(from?: string, to?: string) {
    const offset = '+06:00';
    const today = new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const fromDay = from ?? `${today.slice(0, 7)}-01`;
    const toDay = to ?? today;
    const valid = (day: string) => /^\d{4}-\d{2}-\d{2}$/.test(day);
    const gte = new Date(`${fromDay}T00:00:00.000${offset}`);
    const lte = new Date(`${toDay}T23:59:59.999${offset}`);
    if (!valid(fromDay) || !valid(toDay) || Number.isNaN(gte.getTime()) || Number.isNaN(lte.getTime()) || gte > lte) {
      throw new BadRequestException('Отчёт мезгили туура эмес');
    }
    return { gte, lte, from: fromDay, to: toDay };
  }

  private async requireAuthor(id: string) {
    const value = await this.prisma.author.findFirst({ where: { id, deletedAt: null } });
    if (!value) throw new NotFoundException('Автор табылган жок');
    return value;
  }

  private async requireCategory(id: string) {
    const value = await this.prisma.category.findFirst({ where: { id, deletedAt: null } });
    if (!value) throw new NotFoundException('Категория табылган жок');
    return value;
  }

  private async requireBook(id: string) {
    const value = await this.prisma.book.findFirst({ where: { id, deletedAt: null } });
    if (!value) throw new NotFoundException('Китеп табылган жок');
    return value;
  }

  /** FREE = read for free; PURCHASE = buy (optionally rent); RENTAL = rent only. */
  private validateAccess(dto: {
    accessType?: AccessType;
    price?: unknown;
    rentalPrice?: unknown;
    rentalDays?: number;
  }) {
    const price = Number(dto.price ?? 0);
    const rentalPrice = dto.rentalPrice == null ? null : Number(dto.rentalPrice);
    if (dto.accessType === AccessType.FREE) {
      if (price !== 0) throw new BadRequestException('Акысыз китептин баасы 0 болушу керек');
      if (rentalPrice) throw new BadRequestException('Акысыз китепти ижарага берүүгө болбойт');
      return;
    }
    if (dto.accessType === AccessType.PURCHASE && !(price > 0)) {
      throw new BadRequestException('Сатылуучу китептин баасы 0дон чоң болушу керек');
    }
    if (dto.accessType === AccessType.RENTAL && (!rentalPrice || rentalPrice <= 0 || !dto.rentalDays)) {
      throw new BadRequestException('Ижара баасын жана мөөнөтүн көрсөтүңүз');
    }
  }

  private audit(
    adminId: string,
    action: string,
    entity: string,
    entityId?: string,
    metadata?: object,
  ) {
    return this.prisma.auditLog.create({
      data: { adminId, action, entity, entityId, metadata },
    });
  }
}
