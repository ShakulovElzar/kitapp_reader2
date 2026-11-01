import { ReactNode, useCallback, useEffect, useState } from 'react';
import { errorText } from './format';

const icons = {
  home: 'M3 10.5 12 3l9 7.5M5 9v11h5v-6h4v6h5V9',
  book: 'M5 4h10a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3V4Zm0 13a3 3 0 0 1 3-3h10',
  tag: 'M4 7V4h3m-3 0 9.5 9.5M20 13l-7 7-9-9V4h7l9 9Z',
  users: 'M16 19v-1a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1M9.5 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM21 19v-1a4 4 0 0 0-3-3.9M15 4.1a3 3 0 0 1 0 5.8',
  receipt: 'M6 3h12v18l-3-2-3 2-3-2-3 2V3Zm3 5h6m-6 4h6',
  chart: 'M4 20V10m6 10V4m6 16v-7m4 7H2',
  history: 'M3 12a9 9 0 1 0 3-6.7L3 8m0-5v5h5m4-1v5l3 2',
  logout: 'M15 4h4v16h-4M10 8l-4 4 4 4m-4-4h11',
  plus: 'M12 5v14M5 12h14',
  search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14Zm9 2-4-4',
  close: 'M6 6l12 12M18 6 6 18',
  edit: 'M4 20h4L19 9l-4-4L4 16v4Zm9-13 4 4',
  trash: 'M4 7h16M9 7V4h6v3m-8 0 1 13h8l1-13',
  upload: 'M12 16V4m0 0-4 4m4-4 4 4M4 16v4h16v-4',
  download: 'M12 4v12m0 0-4-4m4 4 4-4M4 16v4h16v-4',
  check: 'M5 12.5 10 17l9-10',
  alert: 'M12 8v5m0 3.5v.5M10.3 3.9 2.6 17.5A2 2 0 0 0 4.3 20.5h15.4a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z',
  arrow: 'M9 6l6 6-6 6',
} as const;

export type IconName = keyof typeof icons;

export function Icon({ name, size = 18 }: { name: IconName; size?: number }) {
  return (
    <svg className="icon" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
      strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={icons[name]} />
    </svg>
  );
}

/** Loads data once, and again on reload(). Keeps the last data while reloading. */
export function useLoad<T>(load: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState('');
  // The loaders passed in are fixed per page, so they are not a dependency.
  const reload = useCallback(async () => {
    try {
      setData(await load());
      setError('');
    } catch (value) {
      setError(errorText(value, 'Маалымат жүктөлгөн жок'));
    }
  }, []);
  useEffect(() => { void reload(); }, [reload]);
  return { data, error, reload };
}

export function PageHeader({ title, note, children }: { title: string; note?: ReactNode; children?: ReactNode }) {
  return (
    <header className="page-header">
      <div>
        <h1>{title}</h1>
        {note && <p>{note}</p>}
      </div>
      {children && <div className="page-actions">{children}</div>}
    </header>
  );
}

export function Field({ label, hint, children, wide }: { label: string; hint?: string; children: ReactNode; wide?: boolean }) {
  return (
    <label className={wide ? 'field wide' : 'field'}>
      <span className="field-label">{label}</span>
      {children}
      {hint && <small className="field-hint">{hint}</small>}
    </label>
  );
}

export type Tone = 'green' | 'amber' | 'red' | 'gray';

export function Badge({ children, tone }: { children: ReactNode; tone: Tone }) {
  return <span className={`badge ${tone}`}>{children}</span>;
}

export function Stat({ label, value, note }: { label: string; value: ReactNode; note?: ReactNode }) {
  return (
    <div className="stat">
      <span>{label}</span>
      <strong>{value}</strong>
      {note && <small>{note}</small>}
    </div>
  );
}

export function Loading({ text = 'Жүктөлүүдө…' }: { text?: string }) {
  return <div className="loading"><i />{text}</div>;
}

export function Empty({ title, text }: { title: string; text?: string }) {
  return <div className="empty"><strong>{title}</strong>{text && <span>{text}</span>}</div>;
}

export function ErrorBox({ text, onRetry }: { text: string; onRetry?: () => void }) {
  return (
    <div className="alert error">
      <Icon name="alert" />
      <span>{text}</span>
      {onRetry && <button className="link" onClick={onRetry}>Кайра аракет кылуу</button>}
    </div>
  );
}

export function Search({ value, onChange, placeholder }: { value: string; onChange: (value: string) => void; placeholder: string }) {
  return (
    <label className="search">
      <Icon name="search" size={16} />
      <input type="search" value={value} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}

export function Segmented<T extends string>({ value, options, onChange, label }: {
  value: T;
  options: Array<{ value: T; label: string; count?: number }>;
  onChange: (value: T) => void;
  label?: string;
}) {
  return (
    <div className="segmented" role="radiogroup" aria-label={label}>
      {options.map((option) => (
        <button key={option.value} type="button" role="radio" aria-checked={value === option.value}
          className={value === option.value ? 'active' : ''} onClick={() => onChange(option.value)}>
          {option.label}
          {option.count !== undefined && <span className="count">{option.count}</span>}
        </button>
      ))}
    </div>
  );
}

function useEscape(onClose: () => void) {
  useEffect(() => {
    const listener = (event: KeyboardEvent) => { if (event.key === 'Escape') onClose(); };
    window.addEventListener('keydown', listener);
    return () => window.removeEventListener('keydown', listener);
  }, [onClose]);
}

/** Side panel for editing one record; the list behind it stays visible. */
export function Drawer({ title, subtitle, onClose, children, footer }: {
  title: string;
  subtitle?: string;
  onClose: () => void;
  children: ReactNode;
  footer: ReactNode;
}) {
  useEscape(onClose);
  return (
    <div className="overlay" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <aside className="drawer" role="dialog" aria-modal="true" aria-label={title}>
        <header className="drawer-header">
          <div>
            <h2>{title}</h2>
            {subtitle && <p>{subtitle}</p>}
          </div>
          <button className="icon-button" onClick={onClose} aria-label="Жабуу"><Icon name="close" /></button>
        </header>
        <div className="drawer-body">{children}</div>
        <footer className="drawer-footer">{footer}</footer>
      </aside>
    </div>
  );
}

export function Dialog({ title, children, onClose, actions }: {
  title: string;
  children?: ReactNode;
  onClose: () => void;
  actions: ReactNode;
}) {
  useEscape(onClose);
  return (
    <div className="overlay center" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className="dialog" role="dialog" aria-modal="true" aria-label={title}>
        <h2>{title}</h2>
        {children}
        <div className="dialog-actions">{actions}</div>
      </section>
    </div>
  );
}

/** Asks before an action that is hard to undo, and shows its error in place. */
export function Confirm({ title, text, confirmLabel, danger, onConfirm, onClose }: {
  title: string;
  text: ReactNode;
  confirmLabel: string;
  danger?: boolean;
  onConfirm: () => Promise<void>;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function run() {
    setBusy(true);
    setError('');
    try {
      await onConfirm();
      onClose();
    } catch (value) {
      setError(errorText(value));
      setBusy(false);
    }
  }
  return (
    <Dialog title={title} onClose={onClose} actions={<>
      <button className="secondary" onClick={onClose}>Жокко чыгаруу</button>
      <button className={danger ? 'danger' : 'primary'} disabled={busy} onClick={() => void run()}>
        {busy ? 'Күтүңүз…' : confirmLabel}
      </button>
    </>}>
      <p>{text}</p>
      {error && <ErrorBox text={error} />}
    </Dialog>
  );
}
