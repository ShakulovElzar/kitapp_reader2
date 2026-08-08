import { FormEvent, ReactNode, useEffect, useMemo, useState } from 'react';
import { api, auth } from './api';
import type {
  AuditLog,
  Author,
  Book,
  Category,
  Dashboard,
  Reader,
  SalesReport,
  Transaction,
} from './types';

type Page = 'dashboard' | 'books' | 'directories' | 'readers' | 'orders' | 'reports' | 'audit';

const navigation: Array<{ id: Page; icon: string; label: string }> = [
  { id: 'dashboard', icon: '⌂', label: 'Башкы бет' },
  { id: 'books', icon: '▤', label: 'Китептер' },
  { id: 'directories', icon: '◫', label: 'Авторлор жана жанрлар' },
  { id: 'readers', icon: '♙', label: 'Окурмандар' },
  { id: 'orders', icon: '₸', label: 'Сатуулар жана ижара' },
  { id: 'reports', icon: '↗', label: 'Отчёттор' },
  { id: 'audit', icon: '✓', label: 'Аракеттер журналы' },
];

const som = (value: string | number) => `${Number(value).toLocaleString('ru-RU')} сом`;
const date = (value: string) => new Intl.DateTimeFormat('ky-KG', { dateStyle: 'medium' }).format(new Date(value));
const statusLabel = (value: Book['status']) => ({ DRAFT: 'Долбоор', PUBLISHED: 'Жарыяланган', ARCHIVED: 'Архив' })[value];

export function App() {
  const [loggedIn, setLoggedIn] = useState(Boolean(auth.token()));
  if (!loggedIn) return <Login onSuccess={() => setLoggedIn(true)} />;
  return <AdminShell onLogout={() => { auth.clear(); setLoggedIn(false); }} />;
}

function Login({ onSuccess }: { onSuccess: () => void }) {
  const [email, setEmail] = useState('admin@kitapp.kg');
  const [password, setPassword] = useState('Kitapp123!');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      const result = await api<{ token: string }>('/auth/admin/login', {
        method: 'POST', body: JSON.stringify({ email, password }),
      });
      auth.save(result.token);
      onSuccess();
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Кирүү мүмкүн болгон жок');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-brand">
        <Logo large />
        <h1>Кыргыз китептерин башкаруунун бирдиктүү борбору</h1>
        <p>Каталогду жаңыртыңыз, сатууларды көзөмөлдөңүз жана окурмандар менен иштеңиз.</p>
      </section>
      <form className="login-card" onSubmit={submit}>
        <span className="eyebrow">АДМИН-ПАНЕЛЬ</span>
        <h2>Кош келиңиз</h2>
        <p>Улантуу үчүн аккаунтуңузга кириңиз.</p>
        <Field label="Email">
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </Field>
        <Field label="Сырсөз">
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </Field>
        {error && <div className="alert error">{error}</div>}
        <button className="primary wide" disabled={loading}>{loading ? 'Күтүңүз…' : 'Кирүү'}</button>
        <small>Локалдык кирүү: admin@kitapp.kg / Kitapp123!</small>
      </form>
    </main>
  );
}

function AdminShell({ onLogout }: { onLogout: () => void }) {
  const [page, setPage] = useState<Page>('dashboard');
  const active = navigation.find((item) => item.id === page)!;
  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <Logo />
        <nav>
          {navigation.map((item) => (
            <button key={item.id} className={page === item.id ? 'active' : ''} onClick={() => setPage(item.id)}>
              <span>{item.icon}</span>{item.label}
            </button>
          ))}
        </nav>
        <div className="sidebar-user">
          <div className="avatar">БА</div>
          <div><strong>Башкы админ</strong><small>Superadmin</small></div>
          <button title="Чыгуу" onClick={onLogout}>↪</button>
        </div>
      </aside>
      <main className="workspace">
        <header className="topbar">
          <div><span className="eyebrow">KITAPP БАШКАРУУ</span><h1>{active.label}</h1></div>
          <div className="live"><i /> Система иштеп жатат</div>
        </header>
        {page === 'dashboard' && <DashboardPage onNavigate={setPage} />}
        {page === 'books' && <BooksPage />}
        {page === 'directories' && <DirectoriesPage />}
        {page === 'readers' && <ReadersPage />}
        {page === 'orders' && <OrdersPage />}
        {page === 'reports' && <ReportsPage />}
        {page === 'audit' && <AuditPage />}
      </main>
    </div>
  );
}

function DashboardPage({ onNavigate }: { onNavigate: (page: Page) => void }) {
  const [data, setData] = useState<Dashboard | null>(null);
  const [books, setBooks] = useState<Book[]>([]);
  useEffect(() => { void Promise.all([api<Dashboard>('/admin/dashboard'), api<Book[]>('/admin/books')]).then(([d, b]) => { setData(d); setBooks(b.slice(0, 5)); }); }, []);
  if (!data) return <Loading />;
  return (
    <div className="page-grid">
      <section className="metrics">
        <Metric label="Китептер" value={data.books} note="Каталогдогу жалпы сан" tone="green" />
        <Metric label="Окурмандар" value={data.readers} note="Катталган аккаунттар" tone="blue" />
        <Metric label="Сатуулар" value={data.sales} note="Ийгиликтүү сатып алуулар" tone="orange" />
        <Metric label="Киреше" value={som(data.revenue)} note={`${data.rentals} активдүү ижара`} tone="rose" />
      </section>
      <section className="panel span-2">
        <PanelHeader title="Акыркы китептер" action="Баарын көрүү" onAction={() => onNavigate('books')} />
        <BookTable books={books} compact />
      </section>
      <section className="panel quick-panel">
        <PanelHeader title="Тез аракеттер" />
        <button onClick={() => onNavigate('books')}><b>＋</b><span>Жаңы китеп кошуу<small>EPUB жана мукаба жүктөө</small></span></button>
        <button onClick={() => onNavigate('reports')}><b>↗</b><span>Сатуу отчёту<small>Мезгил боюнча талдоо</small></span></button>
        <button onClick={() => onNavigate('readers')}><b>♙</b><span>Окурмандар<small>Аккаунттарды башкаруу</small></span></button>
      </section>
    </div>
  );
}

const emptyBook = {
  title: '', slug: '', description: '', authorId: '', categoryId: '', price: 299,
  rentalPrice: 99, rentalDays: 14, pages: 1, status: 'DRAFT' as Book['status'],
  accessType: 'PURCHASE' as Book['accessType'], isAdult: false, isNew: false,
};

function BooksPage() {
  const [books, setBooks] = useState<Book[]>([]);
  const [authors, setAuthors] = useState<Author[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [form, setForm] = useState({ ...emptyBook });
  const [editing, setEditing] = useState<string | null>(null);
  const [cover, setCover] = useState<File | null>(null);
  const [epub, setEpub] = useState<File | null>(null);
  const [open, setOpen] = useState(false);
  const [message, setMessage] = useState('');

  async function load() {
    const [bookList, authorList, categoryList] = await Promise.all([
      api<Book[]>('/admin/books'), api<Author[]>('/admin/authors'), api<Category[]>('/admin/categories'),
    ]);
    setBooks(bookList); setAuthors(authorList); setCategories(categoryList);
  }
  useEffect(() => { void load(); }, []);

  function startCreate() {
    setEditing(null); setForm({ ...emptyBook, authorId: authors[0]?.id ?? '', categoryId: categories[0]?.id ?? '' });
    setCover(null); setEpub(null); setMessage(''); setOpen(true);
  }

  function startEdit(book: Book) {
    setEditing(book.id);
    setForm({
      title: book.title, slug: book.slug, description: book.description, authorId: book.authorId,
      categoryId: book.categoryId, price: Number(book.price), rentalPrice: Number(book.rentalPrice ?? 0),
      rentalDays: book.rentalDays, pages: book.pages, status: book.status, accessType: book.accessType,
      isAdult: book.isAdult, isNew: book.isNew,
    });
    setCover(null); setEpub(null); setMessage(''); setOpen(true);
  }

  async function save(event: FormEvent) {
    event.preventDefault(); setMessage('');
    try {
      const payload = { ...form, rentalPrice: form.rentalPrice || undefined };
      const book = await api<Book>(editing ? `/admin/books/${editing}` : '/admin/books', {
        method: editing ? 'PATCH' : 'POST', body: JSON.stringify(payload),
      });
      if (cover || epub) {
        const files = new FormData();
        if (cover) files.append('cover', cover);
        if (epub) files.append('epub', epub);
        await api(`/admin/books/${book.id}/files`, { method: 'POST', body: files });
      }
      setOpen(false); await load();
    } catch (value) { setMessage(value instanceof Error ? value.message : 'Сакталган жок'); }
  }

  async function togglePublish(book: Book) {
    await api(`/admin/books/${book.id}`, { method: 'PATCH', body: JSON.stringify({ status: book.status === 'PUBLISHED' ? 'DRAFT' : 'PUBLISHED' }) });
    await load();
  }

  async function remove(book: Book) {
    if (!window.confirm(`«${book.title}» китебин архивге өткөрөсүзбү?`)) return;
    await api(`/admin/books/${book.id}`, { method: 'DELETE' }); await load();
  }

  return (
    <section className="panel">
      <PanelHeader title={`Каталог · ${books.length} китеп`} action="＋ Китеп кошуу" onAction={startCreate} />
      <BookTable books={books} onEdit={startEdit} onPublish={togglePublish} onDelete={remove} />
      {open && (
        <Modal title={editing ? 'Китепти өзгөртүү' : 'Жаңы китеп'} onClose={() => setOpen(false)}>
          <form className="form-grid" onSubmit={save}>
            <Field label="Китептин аталышы"><input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value, slug: editing ? form.slug : slugify(e.target.value) })} required /></Field>
            <Field label="URL белгиси"><input value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} required /></Field>
            <Field label="Автор"><select value={form.authorId} onChange={(e) => setForm({ ...form, authorId: e.target.value })} required><option value="">Тандаңыз</option>{authors.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></Field>
            <Field label="Категория"><select value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value })} required><option value="">Тандаңыз</option>{categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></Field>
            <Field label="Баасы"><input type="number" min="0" value={form.price} onChange={(e) => setForm({ ...form, price: Number(e.target.value) })} /></Field>
            <Field label="Ижара баасы"><input type="number" min="0" value={form.rentalPrice} onChange={(e) => setForm({ ...form, rentalPrice: Number(e.target.value) })} /></Field>
            <Field label="Беттер"><input type="number" min="1" value={form.pages} onChange={(e) => setForm({ ...form, pages: Number(e.target.value) })} /></Field>
            <Field label="Статус"><select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value as Book['status'] })}><option value="DRAFT">Долбоор</option><option value="PUBLISHED">Жарыяланган</option></select></Field>
            <Field label="Мукаба"><input type="file" accept="image/*" onChange={(e) => setCover(e.target.files?.[0] ?? null)} /></Field>
            <Field label="EPUB"><input type="file" accept=".epub,application/epub+zip" onChange={(e) => setEpub(e.target.files?.[0] ?? null)} /></Field>
            <Field label="Сүрөттөмө" wide><textarea rows={4} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} required /></Field>
            <label className="check"><input type="checkbox" checked={form.isNew} onChange={(e) => setForm({ ...form, isNew: e.target.checked })} /> Жаңы китеп</label>
            <label className="check"><input type="checkbox" checked={form.isAdult} onChange={(e) => setForm({ ...form, isAdult: e.target.checked })} /> 18+ мазмун</label>
            {message && <div className="alert error full">{message}</div>}
            <div className="modal-actions full"><button type="button" className="ghost" onClick={() => setOpen(false)}>Жокко чыгаруу</button><button className="primary">Сактоо</button></div>
          </form>
        </Modal>
      )}
    </section>
  );
}

function DirectoriesPage() {
  const [authors, setAuthors] = useState<Author[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [authorName, setAuthorName] = useState('');
  const [categoryName, setCategoryName] = useState('');
  async function load() { const [a, c] = await Promise.all([api<Author[]>('/admin/authors'), api<Category[]>('/admin/categories')]); setAuthors(a); setCategories(c); }
  useEffect(() => { void load(); }, []);
  async function addAuthor(event: FormEvent) { event.preventDefault(); await api('/admin/authors', { method: 'POST', body: JSON.stringify({ name: authorName }) }); setAuthorName(''); await load(); }
  async function addCategory(event: FormEvent) { event.preventDefault(); await api('/admin/categories', { method: 'POST', body: JSON.stringify({ name: categoryName, slug: slugify(categoryName) }) }); setCategoryName(''); await load(); }
  return (
    <div className="split-panels">
      <section className="panel"><PanelHeader title={`Авторлор · ${authors.length}`} /><form className="inline-form" onSubmit={addAuthor}><input placeholder="Автордун аты" value={authorName} onChange={(e) => setAuthorName(e.target.value)} required /><button className="primary">Кошуу</button></form><SimpleList items={authors.map((a) => ({ id: a.id, title: a.name, note: `${a._count?.books ?? 0} китеп` }))} /></section>
      <section className="panel"><PanelHeader title={`Категориялар · ${categories.length}`} /><form className="inline-form" onSubmit={addCategory}><input placeholder="Категориянын аталышы" value={categoryName} onChange={(e) => setCategoryName(e.target.value)} required /><button className="primary">Кошуу</button></form><SimpleList items={categories.map((c) => ({ id: c.id, title: c.name, note: `${c._count?.books ?? 0} китеп` }))} /></section>
    </div>
  );
}

function ReadersPage() {
  const [readers, setReaders] = useState<Reader[]>([]);
  async function load() { setReaders(await api('/admin/readers')); }
  useEffect(() => { void load(); }, []);
  async function toggle(reader: Reader) { await api(`/admin/readers/${reader.id}/block`, { method: 'PATCH', body: JSON.stringify({ isBlocked: !reader.isBlocked, blockNote: !reader.isBlocked ? 'Администратор тарабынан бөгөттөлдү' : undefined }) }); await load(); }
  return <section className="panel"><PanelHeader title={`Окурмандар · ${readers.length}`} /><div className="table-wrap"><table><thead><tr><th>Окурман</th><th>Телефон</th><th>Сатып алуу</th><th>Ижара</th><th>Статус</th><th /></tr></thead><tbody>{readers.map((reader) => <tr key={reader.id}><td><strong>{reader.name ?? 'Аты көрсөтүлгөн эмес'}</strong><small>{date(reader.createdAt)} катталган</small></td><td>{reader.phone}</td><td>{reader._count.purchases}</td><td>{reader._count.rentals}</td><td><Badge tone={reader.isBlocked ? 'red' : 'green'}>{reader.isBlocked ? 'Бөгөттөлгөн' : 'Активдүү'}</Badge></td><td><button className="text-button" onClick={() => void toggle(reader)}>{reader.isBlocked ? 'Ачуу' : 'Бөгөттөө'}</button></td></tr>)}</tbody></table></div></section>;
}

function OrdersPage() {
  const [tab, setTab] = useState<'sales' | 'rentals'>('sales');
  const [sales, setSales] = useState<Transaction[]>([]);
  const [rentals, setRentals] = useState<Transaction[]>([]);
  useEffect(() => { void Promise.all([api<Transaction[]>('/admin/purchases'), api<Transaction[]>('/admin/rentals')]).then(([a, b]) => { setSales(a); setRentals(b); }); }, []);
  const items = tab === 'sales' ? sales : rentals;
  return <section className="panel"><div className="tab-header"><div><h2>Төлөмдөр</h2><p>Локалдык төлөм провайдеринин операциялары</p></div><div className="tabs"><button className={tab === 'sales' ? 'active' : ''} onClick={() => setTab('sales')}>Сатуулар</button><button className={tab === 'rentals' ? 'active' : ''} onClick={() => setTab('rentals')}>Ижаралар</button></div></div><div className="table-wrap"><table><thead><tr><th>Китеп</th><th>Окурман</th><th>Күнү</th><th>Сумма</th><th>Статус</th></tr></thead><tbody>{items.map((item) => <tr key={item.id}><td><strong>{item.book.title}</strong><small>{item.book.author.name}</small></td><td>{item.reader.phone}</td><td>{date(item.createdAt)}</td><td><strong>{som(item.amount)}</strong></td><td><Badge tone="green">Төлөндү</Badge></td></tr>)}</tbody></table></div></section>;
}

function ReportsPage() {
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().slice(0, 10);
  const [from, setFrom] = useState(monthStart);
  const [to, setTo] = useState(now.toISOString().slice(0, 10));
  const [report, setReport] = useState<SalesReport | null>(null);
  async function load() { setReport(await api(`/admin/reports/sales?from=${from}&to=${to}`)); }
  useEffect(() => { void load(); }, []);
  const maximum = useMemo(() => Math.max(1, ...(report?.items.map((item) => item.quantity) ?? [1])), [report]);
  return (
    <div className="report-page">
      <section className="panel report-filter"><div><h2>Китеп сатуу отчёту</h2><p>Кайсы автордун кайсы китеби канча сатылганын көрүңүз.</p></div><div className="date-filter"><Field label="Башталган күн"><input type="date" value={from} onChange={(e) => setFrom(e.target.value)} /></Field><Field label="Аяктаган күн"><input type="date" value={to} onChange={(e) => setTo(e.target.value)} /></Field><button className="primary" onClick={() => void load()}>Көрсөтүү</button></div></section>
      {report ? <><section className="metrics two"><Metric label="Сатылган китеп" value={report.totalQuantity} note={`${from} — ${to}`} tone="green" /><Metric label="Жалпы киреше" value={som(report.totalRevenue)} note="Кайтаруулар эсептелбейт" tone="orange" /></section><section className="panel"><PanelHeader title="Китептер жана авторлор боюнча" /><div className="table-wrap"><table><thead><tr><th>Китеп</th><th>Автор</th><th>Сатылганы</th><th>Үлүшү</th><th>Киреше</th></tr></thead><tbody>{report.items.map((item) => <tr key={item.bookId}><td><strong>{item.title}</strong></td><td>{item.author}</td><td><strong>{item.quantity}</strong></td><td><div className="bar"><i style={{ width: `${(item.quantity / maximum) * 100}%` }} /></div></td><td><strong>{som(item.revenue)}</strong></td></tr>)}{!report.items.length && <tr><td colSpan={5}><Empty text="Бул мезгилде сатуу болгон жок" /></td></tr>}</tbody></table></div></section></> : <Loading />}
    </div>
  );
}

function AuditPage() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  useEffect(() => { void api<AuditLog[]>('/admin/audit-logs').then(setLogs); }, []);
  return <section className="panel"><PanelHeader title="Администраторлордун аракеттери" /><div className="timeline">{logs.map((log) => <article key={log.id}><i /><div><strong>{log.admin.name}</strong> · {actionName(log.action)} {entityName(log.entity)}<small>{new Date(log.createdAt).toLocaleString('ky-KG')} · {log.admin.email}</small></div></article>)}{!logs.length && <Empty text="Азырынча аракеттер жок" />}</div></section>;
}

function BookTable({ books, compact, onEdit, onPublish, onDelete }: { books: Book[]; compact?: boolean; onEdit?: (book: Book) => void; onPublish?: (book: Book) => void; onDelete?: (book: Book) => void }) {
  return <div className="table-wrap"><table><thead><tr><th>Китеп</th><th>Автор</th><th>Категория</th><th>Баасы</th><th>Статус</th>{!compact && <><th>Файлдар</th><th /></>}</tr></thead><tbody>{books.map((book) => <tr key={book.id}><td><div className="book-cell"><div className="mini-cover">{book.title.slice(0, 1)}</div><div><strong>{book.title}</strong><small>{book.pages} бет · {book._count?.purchases ?? 0} сатуу</small></div></div></td><td>{book.author.name}</td><td>{book.category.name}</td><td><strong>{som(book.price)}</strong></td><td><Badge tone={book.status === 'PUBLISHED' ? 'green' : 'amber'}>{statusLabel(book.status)}</Badge></td>{!compact && <><td><span className={book.coverKey ? 'file-ok' : 'file-missing'}>Мукаба</span> <span className={book.epubKey ? 'file-ok' : 'file-missing'}>EPUB</span></td><td><div className="row-actions"><button onClick={() => onEdit?.(book)}>Өзгөртүү</button><button onClick={() => onPublish?.(book)}>{book.status === 'PUBLISHED' ? 'Жашыруу' : 'Жарыялоо'}</button><button className="danger" onClick={() => onDelete?.(book)}>Архив</button></div></td></>}</tr>)}</tbody></table></div>;
}

function Logo({ large }: { large?: boolean }) { return <div className={`logo ${large ? 'large' : ''}`}><span>▤</span><strong>Kitapp</strong>{!large && <small>Башкаруу</small>}</div>; }
function Metric({ label, value, note, tone }: { label: string; value: ReactNode; note: string; tone: string }) { return <article className={`metric ${tone}`}><span>{label}</span><strong>{value}</strong><small>{note}</small></article>; }
function PanelHeader({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) { return <div className="panel-header"><h2>{title}</h2>{action && <button className="primary small" onClick={onAction}>{action}</button>}</div>; }
function Field({ label, children, wide }: { label: string; children: ReactNode; wide?: boolean }) { return <label className={wide ? 'field wide' : 'field'}><span>{label}</span>{children}</label>; }
function Badge({ children, tone }: { children: ReactNode; tone: 'green' | 'amber' | 'red' }) { return <span className={`badge ${tone}`}>{children}</span>; }
function Loading() { return <div className="loading"><i /><span>Маалымат жүктөлүүдө…</span></div>; }
function Empty({ text }: { text: string }) { return <div className="empty">{text}</div>; }
function Modal({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) { return <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}><section className="modal"><div className="modal-title"><h2>{title}</h2><button onClick={onClose}>×</button></div>{children}</section></div>; }
function SimpleList({ items }: { items: Array<{ id: string; title: string; note: string }> }) { return <div className="simple-list">{items.map((item) => <article key={item.id}><div className="avatar light">{item.title.slice(0, 1)}</div><strong>{item.title}</strong><small>{item.note}</small></article>)}</div>; }
const slugify = (value: string) => value.toLowerCase().trim().replace(/[^a-zа-яёүөң0-9]+/gi, '-').replace(/^-|-$/g, '');
const actionName = (value: string) => ({ CREATE: 'кошту', UPDATE: 'өзгөрттү', DELETE: 'архивдеди', UPLOAD: 'файл жүктөдү', BLOCK: 'бөгөттөдү', UNBLOCK: 'ачты' })[value] ?? value;
const entityName = (value: string) => ({ Book: 'китепти', Author: 'авторду', Category: 'категорияны', Reader: 'окурманды' })[value] ?? value;
