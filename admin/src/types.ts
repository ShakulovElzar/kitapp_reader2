export type Dashboard = {
  books: number;
  // Only present for SUPERADMIN.
  readers?: number;
  sales?: number;
  activeRentals?: number;
  salesRevenue?: number;
  rentalRevenue?: number;
  revenue?: number;
  currency?: string;
};

export type AdminProfile = {
  id: string;
  name: string;
  email: string;
  role: 'SUPERADMIN' | 'EDITOR';
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
  coverKey?: string | null;
  epubKey?: string | null;
  coverUrl?: string | null;
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
  status: 'PENDING' | 'COMPLETED' | 'REFUNDED' | 'CANCELLED';
  createdAt: string;
  endsAt?: string;
  book: Book;
  reader: Reader;
};

export type SalesReport = {
  from: string;
  to: string;
  timeZone: string;
  totalQuantity: number;
  totalRentals: number;
  salesRevenue: number;
  rentalRevenue: number;
  totalRevenue: number;
  items: Array<{
    bookId: string;
    title: string;
    author: string;
    quantity: number;
    rentals: number;
    salesRevenue: number;
    rentalRevenue: number;
    revenue: number;
  }>;
};

export type AuditLog = {
  id: string;
  action: string;
  entity: string;
  entityId?: string;
  metadata?: Record<string, unknown> | null;
  createdAt: string;
  admin: { name: string; email: string };
};
