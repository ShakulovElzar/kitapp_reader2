import { FormEvent, useMemo, useState } from 'react';
import { api } from '../api';
import { errorText, slugify } from '../format';
import { toast } from '../toast';
import type { Author, Category } from '../types';
import { Confirm, Empty, ErrorBox, Icon, Loading, PageHeader, Search, useLoad } from '../ui';

type Item = { id: string; name: string; books: number };

export function DirectoriesPage() {
  const authors = useLoad(() => api<Author[]>('/admin/authors'));
  const categories = useLoad(() => api<Category[]>('/admin/categories'));

  return (
    <>
      <PageHeader title="Авторлор жана жанрлар" note="Китепти кошкондо ушул тизмелерден тандайсыз." />
      <div className="columns">
        <Directory
          title="Авторлор"
          noun="автор"
          placeholder="Жаңы автордун аты"
          items={authors.data?.map((a) => ({ id: a.id, name: a.name, books: a._count?.books ?? 0 }))}
          error={authors.error}
          searchable
          onReload={authors.reload}
          onCreate={(name) => api('/admin/authors', { method: 'POST', body: JSON.stringify({ name }) })}
          onRename={(id, name) => api(`/admin/authors/${id}`, { method: 'PATCH', body: JSON.stringify({ name }) })}
          onDelete={(id) => api(`/admin/authors/${id}`, { method: 'DELETE' })}
        />
        <Directory
          title="Жанрлар"
          noun="жанр"
          placeholder="Жаңы жанрдын аталышы"
          items={categories.data?.map((c) => ({ id: c.id, name: c.name, books: c._count?.books ?? 0 }))}
          error={categories.error}
          onReload={categories.reload}
          onCreate={(name) => api('/admin/categories', { method: 'POST', body: JSON.stringify({ name, slug: slugify(name) }) })}
          onRename={(id, name) => api(`/admin/categories/${id}`, { method: 'PATCH', body: JSON.stringify({ name, slug: slugify(name) }) })}
          onDelete={(id) => api(`/admin/categories/${id}`, { method: 'DELETE' })}
        />
      </div>
    </>
  );
}

function Directory({ title, noun, placeholder, items, error, searchable, onReload, onCreate, onRename, onDelete }: {
  title: string;
  noun: string;
  placeholder: string;
  items?: Item[];
  error: string;
  searchable?: boolean;
  onReload: () => Promise<void>;
  onCreate: (name: string) => Promise<unknown>;
  onRename: (id: string, name: string) => Promise<unknown>;
  onDelete: (id: string) => Promise<unknown>;
}) {
  const [name, setName] = useState('');
  const [query, setQuery] = useState('');
  const [editing, setEditing] = useState<{ id: string; name: string } | null>(null);
  const [deleting, setDeleting] = useState<Item | null>(null);

  const visible = useMemo(() => {
    const text = query.trim().toLowerCase();
    return (items ?? []).filter((item) => !text || item.name.toLowerCase().includes(text));
  }, [items, query]);

  async function create(event: FormEvent) {
    event.preventDefault();
    try {
      await onCreate(name.trim());
      toast(`«${name.trim()}» кошулду`);
      setName('');
      await onReload();
    } catch (value) {
      toast(errorText(value), 'error');
    }
  }

  async function rename(event: FormEvent) {
    event.preventDefault();
    if (!editing) return;
    try {
      await onRename(editing.id, editing.name.trim());
      toast('Сакталды');
      setEditing(null);
      await onReload();
    } catch (value) {
      toast(errorText(value), 'error');
    }
  }

  return (
    <section className="card">
      <header className="card-header">
        <h2>{title}</h2>
        <span className="muted">{items?.length ?? ''}</span>
      </header>
      <form className="inline-form" onSubmit={create}>
        <input placeholder={placeholder} value={name} minLength={2} onChange={(e) => setName(e.target.value)} required />
        <button className="secondary"><Icon name="plus" />Кошуу</button>
      </form>
      {searchable && <div className="card-search"><Search value={query} onChange={setQuery} placeholder={`${title} ичинен издөө`} /></div>}
      {error && <ErrorBox text={error} onRetry={() => void onReload()} />}
      {!items && !error && <Loading />}
      {items && (
        <ul className="rows">
          {visible.map((item) => (
            <li key={item.id} className="row">
              {editing?.id === item.id ? (
                <form className="inline-form grow" onSubmit={rename}>
                  <input value={editing.name} minLength={2} required autoFocus
                    onChange={(e) => setEditing({ id: item.id, name: e.target.value })}
                    onKeyDown={(e) => e.key === 'Escape' && setEditing(null)} />
                  <button className="primary">Сактоо</button>
                  <button type="button" className="secondary" onClick={() => setEditing(null)}>Жокко чыгаруу</button>
                </form>
              ) : <>
                <span className="grow"><strong>{item.name}</strong><small>{item.books} китеп</small></span>
                <button className="icon-button" title="Атын өзгөртүү" aria-label={`${item.name}: атын өзгөртүү`}
                  onClick={() => setEditing({ id: item.id, name: item.name })}><Icon name="edit" size={16} /></button>
                <button className="icon-button danger" title="Өчүрүү" aria-label={`${item.name}: өчүрүү`}
                  onClick={() => setDeleting(item)}><Icon name="trash" size={16} /></button>
              </>}
            </li>
          ))}
        </ul>
      )}
      {items && !visible.length && <Empty title={query ? 'Табылган жок' : `Азырынча ${noun} жок`} />}
      {deleting && (
        <Confirm
          title={`${noun[0].toUpperCase()}${noun.slice(1)} өчүрүү`}
          text={`«${deleting.name}» өчүрүлөт. Анын активдүү китептери болсо, адегенде аларды башка ${noun}га өткөрүңүз.`}
          confirmLabel="Өчүрүү"
          danger
          onClose={() => setDeleting(null)}
          onConfirm={async () => {
            await onDelete(deleting.id);
            toast(`«${deleting.name}» өчүрүлдү`);
            await onReload();
          }}
        />
      )}
    </section>
  );
}
