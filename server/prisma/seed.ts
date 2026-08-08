import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';
import {
  AccessType,
  AdminRole,
  BookStatus,
  PrismaClient,
} from '../src/generated/prisma/client.js';

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error('DATABASE_URL is required');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString }) });

const books = [
  ['diamond-snake', 'Бриллиант жылан', 'Чолпонбек Абдыкеев', 'Детектив', 299, 352, true],
  ['sun-secret', 'Күнгө сырдын артында', 'Чолпонбек Абдыкеев', 'Роман', 299, 417, false],
  ['moon-city', 'Айкөлдүн жоктоосу', 'Элмира Сариева', 'Тарыхый', 299, 286, true],
  ['faith-light', 'Ыйман нуру', 'Азиз Мырза', 'Дин', 199, 224, false],
  ['ancient-city', 'Байыркы шаар', 'Талант Асанов', 'Тарыхый', 299, 390, false],
  ['mountain-path', 'Тоодогу жол', 'Асел Токтосунова', 'Роман', 249, 312, false],
  ['new-life', 'Жаңы жашоо', 'Жылдыз Жапарова', 'Роман', 199, 265, true],
  ['two-worlds', 'Эки дүйнө', 'Нурбек Осмонов', 'Фантастика', 349, 480, false],
  ['hope', 'Үмүт', 'Айдана Касымова', 'Поэзия', 0, 164, false],
  ['honor', 'Намыс', 'Калыс Сыдыков', 'Драма', 249, 338, false],
  ['white-cloud', 'Ак булут', 'Мээрим Асанова', 'Балдар үчүн', 149, 128, false],
  ['last-letter', 'Акыркы кат', 'Сезим Ибраева', 'Роман', 199, 276, false],
  ['legends', 'Кыргыз уламыштары', 'Элдик чыгарма', 'Балдар үчүн', 0, 198, false],
  ['red-castle', 'Кызыл сепил', 'Бакыт Эсенов', 'Фантастика', 399, 532, false],
  ['garden', 'Жан дүйнө багы', 'Айпери Муратова', 'Психология', 249, 240, false],
  ['samurai', 'Самурай жолу', 'Кайрат Бектуров', 'Тарыхый', 299, 405, false],
] as const;

async function seed() {
  const passwordHash = await bcrypt.hash(process.env.ADMIN_PASSWORD ?? 'Kitapp123!', 12);
  await prisma.admin.upsert({
    where: { email: process.env.ADMIN_EMAIL ?? 'admin@kitapp.kg' },
    create: {
      email: process.env.ADMIN_EMAIL ?? 'admin@kitapp.kg',
      passwordHash,
      name: 'Башкы администратор',
      role: AdminRole.SUPERADMIN,
    },
    update: { passwordHash },
  });

  const authorIds = new Map<string, string>();
  const categoryIds = new Map<string, string>();
  for (const [, , authorName, categoryName] of books) {
    if (!authorIds.has(authorName)) {
      const author = await prisma.author.upsert({
        where: { name: authorName },
        create: { name: authorName },
        update: { deletedAt: null },
      });
      authorIds.set(authorName, author.id);
    }
    if (!categoryIds.has(categoryName)) {
      const category = await prisma.category.upsert({
        where: { name: categoryName },
        create: {
          name: categoryName,
          slug: categoryName.toLowerCase().replaceAll(' ', '-'),
        },
        update: { deletedAt: null },
      });
      categoryIds.set(categoryName, category.id);
    }
  }

  const bookIds = new Map<string, string>();
  for (const [slug, title, author, category, price, pages, isNew] of books) {
    const book = await prisma.book.upsert({
      where: { slug },
      create: {
        slug,
        title,
        description: 'Бул чыгарма окурманды өзгөчө дүйнөгө жетелеп, адамдык тандоо, сүйүү жана үмүт жөнүндө баяндайт.',
        price,
        rentalPrice: price > 0 ? Math.max(49, Math.round(price * 0.35)) : null,
        rentalDays: 14,
        pages,
        rating: 4.7,
        isNew,
        accessType: price === 0 ? AccessType.FREE : AccessType.PURCHASE,
        status: BookStatus.PUBLISHED,
        publishedAt: new Date(),
        authorId: authorIds.get(author)!,
        categoryId: categoryIds.get(category)!,
      },
      update: { deletedAt: null },
    });
    bookIds.set(slug, book.id);
  }

  const readers = await Promise.all([
    prisma.reader.upsert({ where: { phone: '+996555123456' }, create: { phone: '+996555123456', name: 'Айжан' }, update: {} }),
    prisma.reader.upsert({ where: { phone: '+996700987654' }, create: { phone: '+996700987654', name: 'Бекзат' }, update: {} }),
  ]);
  const sales = [
    [readers[0].id, 'diamond-snake', 2],
    [readers[1].id, 'diamond-snake', 7],
    [readers[0].id, 'moon-city', 12],
    [readers[1].id, 'new-life', 18],
    [readers[0].id, 'white-cloud', 35],
  ] as const;
  for (const [readerId, slug, daysAgo] of sales) {
    const bookId = bookIds.get(slug)!;
    const book = await prisma.book.findUniqueOrThrow({ where: { id: bookId } });
    await prisma.purchase.upsert({
      where: { reference: `seed-${readerId}-${slug}` },
      create: {
        readerId,
        bookId,
        amount: book.price,
        reference: `seed-${readerId}-${slug}`,
        createdAt: new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000),
      },
      update: {},
    });
  }
}

seed()
  .finally(() => prisma.$disconnect());
