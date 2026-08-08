export type Dashboard = {
  books: number;
  readers: number;
  sales: number;
  rentals: number;
  revenue: number;
  currency: string;
};

export type Author = { id: string; name: string; bio?: string; _count?: { books: number } };
export type Category = { id: string; name: string; slug: string; _count?: { books: number } };

export type Book = {
  id: string;
  slug: string;
  title: string;
  description: string;
  price: string | number;
  rentalPrice?: string | number | null;
  rentalDays: number;
  pages: number;
  status: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
  accessType: 'FREE' | 'PURCHASE' | 'RENTAL';
  isAdult: boolean;
  isNew: boolean;
  coverKey?: string;
  epubKey?: string;
  authorId: string;
  categoryId: string;
  author: Author;
  category: Category;
  _count?: { purchases: number; rentals: number };
};

export type Reader = {
  id: string;
  phone: string;
  name?: string;
  isBlocked: boolean;
  blockNote?: string;
  createdAt: string;
  _count: { purchases: number; rentals: number };
};

export type Transaction = {
  id: string;
  amount: string | number;
  currency: string;
  status: string;
  createdAt: string;
  endsAt?: string;
  book: Book;
  reader: Reader;
};

export type SalesReport = {
  from: string;
  to: string;
  totalQuantity: number;
  totalRevenue: number;
  items: Array<{
    bookId: string;
    title: string;
    author: string;
    quantity: number;
    revenue: number;
  }>;
};

export type AuditLog = {
  id: string;
  action: string;
  entity: string;
  entityId?: string;
  createdAt: string;
  admin: { name: string; email: string };
};
