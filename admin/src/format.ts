import type { Book } from './types';

export const som = (value: string | number | null | undefined) =>
  `${Number(value ?? 0).toLocaleString('ru-RU')} сом`;

const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const timeFormat = new Intl.DateTimeFormat('ru-RU', { hour: '2-digit', minute: '2-digit' });

export function day(value: string) {
  const date = new Date(value);
  return `${date.getDate()} ${months[date.getMonth()]} ${date.getFullYear()}`;
}
export const dayTime = (value: string) => `${day(value)}, ${timeFormat.format(new Date(value))}`;
export const time = (value: string) => timeFormat.format(new Date(value));

/** "0700112299", "996700112299" and "+996 700…" all become "+996 700 112 299". */
export function phone(value: string) {
  const digits = value.replace(/\D/g, '');
  const local = digits.startsWith('996') ? digits.slice(3) : digits.startsWith('0') ? digits.slice(1) : digits;
  const match = /^(\d{3})(\d{3})(\d{3})$/.exec(local);
  return match ? `+996 ${match[1]} ${match[2]} ${match[3]}` : value;
}

export const statusLabel: Record<Book['status'], string> = {
  DRAFT: 'Долбоор',
  PUBLISHED: 'Жарыяланган',
  ARCHIVED: 'Архив',
};

/** How a reader gets the book, in one short line. */
export function accessLabel(book: Pick<Book, 'accessType' | 'price' | 'rentalPrice' | 'rentalDays'>) {
  if (book.accessType === 'FREE') return 'Акысыз';
  const rental = book.rentalPrice ? `ижара ${som(book.rentalPrice)} / ${book.rentalDays} күн` : '';
  if (book.accessType === 'RENTAL') return rental ? rental[0].toUpperCase() + rental.slice(1) : 'Ижара';
  return rental ? `${som(book.price)} · ${rental}` : som(book.price);
}

export const missingFiles = (book: Book) => !book.coverKey || !book.epubKey;

const latin: Record<string, string> = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'yo', ж: 'zh', з: 'z', и: 'i', й: 'y',
  к: 'k', л: 'l', м: 'm', н: 'n', ң: 'ng', о: 'o', ө: 'o', п: 'p', р: 'r', с: 's', т: 't',
  у: 'u', ү: 'u', ф: 'f', х: 'h', ц: 'ts', ч: 'ch', ш: 'sh', щ: 'sch', ъ: '', ы: 'y', ь: '',
  э: 'e', ю: 'yu', я: 'ya',
};

/** Latin URL slug from a Kyrgyz or Russian title. */
export const slugify = (value: string) =>
  value
    .toLowerCase()
    .split('')
    .map((char) => latin[char] ?? char)
    .join('')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

export const errorText = (value: unknown, fallback = 'Сурам аткарылган жок') =>
  value instanceof Error ? value.message : fallback;

/** Today in Bishkek (UTC+6) as YYYY-MM-DD; reports count Bishkek days. */
export const bishkekToday = () => new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString().slice(0, 10);
