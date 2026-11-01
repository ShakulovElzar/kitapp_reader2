import { useEffect, useState } from 'react';
import { api } from '../api';
import { bishkekToday, day, missingFiles, phone, som } from '../format';
import { go } from '../route';
import type { Book, Dashboard, SalesReport, Transaction } from '../types';
import { Empty, ErrorBox, Icon, Loading, PageHeader, Stat } from '../ui';
import { Cover } from './BooksPage';

type Payment = Transaction & { kind: 'sale' | 'rental' };
type Data = { dashboard: Dashboard; books: Book[]; payments?: Payment[]; report?: SalesReport };

/** What is wrong with a book that keeps it from readers, or null. */
function problem(book: Book) {
  if (!book.coverKey && !book.epubKey) return 'Мукаба жана EPUB жок';
  if (!book.coverKey) return 'Мукаба жок';
  if (!book.epubKey) return 'EPUB жок';
  if (!book.description.trim()) return 'Сүрөттөмө жок';
  if (book.status === 'DRAFT') return 'Долбоор, жарыялана элек';
  return null;
}

export function HomePage({ isSuper, profileLoaded }: { isSuper: boolean; profileLoaded: boolean }) {
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState('');

  async function load() {
    setError('');
    try {
      const [dashboard, books] = await Promise.all([api<Dashboard>('/admin/dashboard'), api<Book[]>('/admin/books')]);
      if (!isSuper) { setData({ dashboard, books }); return; }
      const today = bishkekToday();
      const [sales, rentals, report] = await Promise.all([
        api<Transaction[]>('/admin/purchases'),
        api<Transaction[]>('/admin/rentals'),
        api<SalesReport>(`/admin/reports/sales?from=${today.slice(0, 7)}-01&to=${today}`),
      ]);
      const payments = [
        ...sales.map((item) => ({ ...item, kind: 'sale' as const })),
        ...rentals.map((item) => ({ ...item, kind: 'rental' as const })),
      ].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).slice(0, 6);
      setData({ dashboard, books, payments, report });
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Маалымат жүктөлгөн жок');
    }
  }
  // Wait for the role: superadmins get money data too.
  useEffect(() => { if (profileLoaded) void load(); }, [profileLoaded, isSuper]);

  if (error) return <><PageHeader title="Башкы бет" /><ErrorBox text={error} onRetry={() => void load()} /></>;
  if (!data) return <><PageHeader title="Башкы бет" /><Loading /></>;

  const { dashboard, books, payments, report } = data;
  const published = books.filter((book) => book.status === 'PUBLISHED' && !missingFiles(book)).length;
  const attention = books.map((book) => ({ book, problem: problem(book) })).filter((item) => item.problem);

  return (
    <>
      <PageHeader title="Башкы бет" note={`Бүгүн ${day(new Date().toISOString())}`}>
        <button className="primary" onClick={() => go('books', 'new')}><Icon name="plus" />Китеп кошуу</button>
      </PageHeader>

      <section className="stats">
        <Stat label="Каталогдо" value={published} note={`${books.length} китептин ичинен`} />
        {dashboard.revenue !== undefined && <>
          <Stat label="Окурмандар" value={dashboard.readers ?? 0} note="катталган" />
          <Stat label="Сатуулар" value={dashboard.sales ?? 0} note={`${dashboard.activeRentals ?? 0} активдүү ижара`} />
          <Stat label="Жалпы киреше" value={som(dashboard.revenue)} note={`Бул айда ${som(report?.totalRevenue ?? 0)}`} />
        </>}
      </section>

      <div className="columns">
        <section className="card">
          <header className="card-header">
            <h2>Көңүл буруу керек</h2>
            <span className="muted">{attention.length} китеп</span>
          </header>
          {attention.length ? (
            <ul className="rows">
              {attention.slice(0, 8).map(({ book, problem }) => (
                <li key={book.id}>
                  <button className="row-button" onClick={() => go('books', book.id)}>
                    <Cover book={book} />
                    <span className="grow"><strong>{book.title}</strong><small>{book.author.name}</small></span>
                    <span className="warn">{problem}</span>
                    <Icon name="arrow" size={16} />
                  </button>
                </li>
              ))}
            </ul>
          ) : <Empty title="Баары даяр" text="Ар бир китептин мукабасы, файлы жана сүрөттөмөсү бар." />}
          {attention.length > 8 && (
            <button className="link card-more" onClick={() => go('books')}>Баарын көрүү ({attention.length})</button>
          )}
        </section>

        {payments && (
          <section className="card">
            <header className="card-header">
              <h2>Акыркы төлөмдөр</h2>
              <button className="link" onClick={() => go('orders')}>Баары</button>
            </header>
            {payments.length ? (
              <ul className="rows">
                {payments.map((item) => (
                  <li key={`${item.kind}-${item.id}`} className="row">
                    <span className="grow">
                      <strong>{item.book.title}</strong>
                      <small>{phone(item.reader.phone)} · {day(item.createdAt)}</small>
                    </span>
                    <span className="muted">{item.kind === 'sale' ? 'Сатуу' : 'Ижара'}</span>
                    <strong className="amount">{som(item.amount)}</strong>
                  </li>
                ))}
              </ul>
            ) : <Empty title="Төлөм жок" />}
          </section>
        )}
      </div>

      {report && (
        <section className="card">
          <header className="card-header">
            <h2>Бул айдагы эң көп киреше алып келген китептер</h2>
            <button className="link" onClick={() => go('reports')}>Толук отчёт</button>
          </header>
          {report.items.length ? (
            <ul className="rows">
              {report.items.slice(0, 5).map((item, index) => (
                <li key={item.bookId} className="row">
                  <span className="rank">{index + 1}</span>
                  <span className="grow"><strong>{item.title}</strong><small>{item.author}</small></span>
                  <span className="muted">{item.quantity} сатуу · {item.rentals} ижара</span>
                  <strong className="amount">{som(item.revenue)}</strong>
                </li>
              ))}
            </ul>
          ) : <Empty title="Бул айда сатуу болгон жок" />}
        </section>
      )}
    </>
  );
}
