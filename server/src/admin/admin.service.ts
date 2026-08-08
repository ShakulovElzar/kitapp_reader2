import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import type { Express } from 'express';
import { BookStatus, PaymentStatus } from '../generated/prisma/enums.js';
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

  async dashboard() {
    const [books, readers, completedSales, revenue, rentals] = await Promise.all([
      this.prisma.book.count({ where: { deletedAt: null } }),
      this.prisma.reader.count({ where: { deletedAt: null } }),
      this.prisma.purchase.count({ where: { status: PaymentStatus.COMPLETED } }),
      this.prisma.purchase.aggregate({
        where: { status: PaymentStatus.COMPLETED },
        _sum: { amount: true },
      }),
      this.prisma.rental.count({ where: { status: PaymentStatus.COMPLETED } }),
    ]);
    return {
      books,
      readers,
      sales: completedSales,
      rentals,
      revenue: Number(revenue._sum.amount ?? 0),
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
    const book = await this.prisma.book.create({
      data: {
        ...dto,
        publishedAt: dto.status === BookStatus.PUBLISHED ? new Date() : null,
      },
      include: { author: true, category: true },
    });
    await this.audit(adminId, 'CREATE', 'Book', book.id, { title: book.title });
    return book;
  }

  async updateBook(id: string, dto: UpdateBookDto, adminId: string) {
    const current = await this.requireBook(id);
    if (dto.authorId) await this.requireAuthor(dto.authorId);
    if (dto.categoryId) await this.requireCategory(dto.categoryId);
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
    await this.requireBook(id);
    const coverKey = files.cover?.[0]
      ? await this.storage.upload('covers', files.cover[0])
      : undefined;
    const epubKey = files.epub?.[0]
      ? await this.storage.upload('epubs', files.epub[0])
      : undefined;
    if (!coverKey && !epubKey) throw new BadRequestException('Файл тандалган жок');
    const book = await this.prisma.book.update({
      where: { id },
      data: { coverKey, epubKey },
      include: { author: true, category: true },
    });
    await this.audit(adminId, 'UPLOAD', 'Book', id, { coverKey, epubKey });
    return book;
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

  async salesReport(from?: string, to?: string) {
    const period = this.period(from, to);
    const groups = await this.prisma.purchase.groupBy({
      by: ['bookId'],
      where: { status: PaymentStatus.COMPLETED, createdAt: period },
      _count: { _all: true },
      _sum: { amount: true },
      orderBy: { _sum: { amount: 'desc' } },
    });
    const books = await this.prisma.book.findMany({
      where: { id: { in: groups.map((item) => item.bookId) } },
      include: { author: true },
    });
    const byId = new Map(books.map((book) => [book.id, book]));
    const items = groups.map((group) => ({
      bookId: group.bookId,
      title: byId.get(group.bookId)?.title ?? 'Белгисиз китеп',
      author: byId.get(group.bookId)?.author.name ?? 'Белгисиз автор',
      quantity: group._count._all,
      revenue: Number(group._sum.amount ?? 0),
      currency: 'KGS',
    }));
    return {
      from: period.gte.toISOString(),
      to: period.lte.toISOString(),
      totalQuantity: items.reduce((sum, item) => sum + item.quantity, 0),
      totalRevenue: items.reduce((sum, item) => sum + item.revenue, 0),
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

  private period(from?: string, to?: string) {
    const now = new Date();
    const gte = from ? new Date(`${from}T00:00:00.000Z`) : new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const lte = to ? new Date(`${to}T23:59:59.999Z`) : now;
    if (Number.isNaN(gte.getTime()) || Number.isNaN(lte.getTime()) || gte > lte) {
      throw new BadRequestException('Отчёт мезгили туура эмес');
    }
    return { gte, lte };
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
