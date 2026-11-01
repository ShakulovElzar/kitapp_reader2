import { FormEvent, useEffect, useState } from 'react';
import { api, auth } from './api';
import { errorText } from './format';
import { AuditPage } from './pages/AuditPage';
import { BooksPage } from './pages/BooksPage';
import { DirectoriesPage } from './pages/DirectoriesPage';
import { HomePage } from './pages/HomePage';
import { OrdersPage } from './pages/OrdersPage';
import { ReadersPage } from './pages/ReadersPage';
import { ReportsPage } from './pages/ReportsPage';
import type { Page } from './route';
import type { AdminProfile } from './types';
import { ErrorBox, Icon, IconName } from './ui';

const navigation: Array<{ id: Page; icon: IconName; label: string; superOnly?: boolean }> = [
  { id: 'home', icon: 'home', label: 'Башкы бет' },
  { id: 'books', icon: 'book', label: 'Китептер' },
  { id: 'directories', icon: 'tag', label: 'Авторлор жана жанрлар' },
  { id: 'readers', icon: 'users', label: 'Окурмандар', superOnly: true },
  { id: 'orders', icon: 'receipt', label: 'Төлөмдөр', superOnly: true },
  { id: 'reports', icon: 'chart', label: 'Отчёт', superOnly: true },
  { id: 'audit', icon: 'history', label: 'Аракеттер журналы', superOnly: true },
];

type Route = { page: Page; id?: string };

function readRoute(): Route {
  const [page, id] = window.location.hash.replace(/^#\/?/, '').split('/');
  const known = navigation.some((item) => item.id === page);
  return { page: known ? (page as Page) : 'home', id: id || undefined };
}

function useRoute() {
  const [route, setRoute] = useState(readRoute);
  useEffect(() => {
    const listener = () => setRoute(readRoute());
    window.addEventListener('hashchange', listener);
    return () => window.removeEventListener('hashchange', listener);
  }, []);
  return route;
}

export function App() {
  const [loggedIn, setLoggedIn] = useState(Boolean(auth.token()));
  if (!loggedIn) return <Login onSuccess={() => setLoggedIn(true)} />;
  return <AdminShell onLogout={() => { auth.clear(); setLoggedIn(false); }} />;
}

function Login({ onSuccess }: { onSuccess: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
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
      setError(errorText(value, 'Кирүү мүмкүн болгон жок'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <form className="login-card" onSubmit={submit}>
        <div className="wordmark">Kitapp <span>башкаруу</span></div>
        <h1>Кирүү</h1>
        <p>Каталогду, окурмандарды жана төлөмдөрдү башкаруу үчүн кириңиз.</p>
        <label className="field">
          <span className="field-label">Email</span>
          <input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus />
        </label>
        <label className="field">
          <span className="field-label">Сырсөз</span>
          <input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        {error && <ErrorBox text={error} />}
        <button className="primary wide" disabled={loading}>{loading ? 'Күтүңүз…' : 'Кирүү'}</button>
      </form>
    </main>
  );
}

function AdminShell({ onLogout }: { onLogout: () => void }) {
  const route = useRoute();
  const [profile, setProfile] = useState<AdminProfile | null>(null);
  useEffect(() => { void api<AdminProfile>('/admin/me').then(setProfile).catch(() => undefined); }, []);
  const isSuper = profile?.role === 'SUPERADMIN';
  const pages = navigation.filter((item) => !item.superOnly || isSuper);
  // Until the role is known, superadmin pages wait instead of flashing the home page.
  const page = profile && !pages.some((item) => item.id === route.page) ? 'home' : route.page;

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="wordmark">Kitapp <span>башкаруу</span></div>
        <nav>
          {pages.map((item) => (
            <a key={item.id} href={`#/${item.id}`} className={page === item.id ? 'active' : ''}>
              <Icon name={item.icon} />
              {item.label}
            </a>
          ))}
        </nav>
        <div className="sidebar-user">
          <div>
            <strong>{profile?.name ?? '…'}</strong>
            <small>{profile ? (isSuper ? 'Башкы админ' : 'Редактор') : ''}</small>
          </div>
          <button className="icon-button" title="Чыгуу" aria-label="Чыгуу" onClick={onLogout}><Icon name="logout" /></button>
        </div>
      </aside>
      <main className="workspace">
        {page === 'home' && <HomePage isSuper={isSuper} profileLoaded={Boolean(profile)} />}
        {page === 'books' && <BooksPage selectedId={route.id} />}
        {page === 'directories' && <DirectoriesPage />}
        {isSuper && page === 'readers' && <ReadersPage />}
        {isSuper && page === 'orders' && <OrdersPage />}
        {isSuper && page === 'reports' && <ReportsPage />}
        {isSuper && page === 'audit' && <AuditPage />}
      </main>
    </div>
  );
}
