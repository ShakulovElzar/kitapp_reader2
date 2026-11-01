import { FormEvent, useEffect, useMemo, useState } from 'react';
import { api } from '../api';
import { accessLabel, errorText, missingFiles, slugify, statusLabel } from '../format';
import { go } from '../route';
import { toast } from '../toast';
import type { Author, Book, Category } from '../types';
import {
  Badge, Confirm, Drawer, Empty, ErrorBox, Field, Icon, Loading, PageHeader, Search, Segmented, useLoad,
} from '../ui';

type StatusFilter = 'all' | 'PUBLISHED' | 'DRAFT' | 'incomplete';
type Catalog = { books: Book[]; authors: Author[]; categories: Category[] };

const loadCatalog = async (): Promise<Catalog> => {
  const [books, authors, categories] = await Promise.all([
    api<Book[]>('/admin/books'), api<Author[]>('/admin/authors'), api<Category[]>('/admin/categories'),
  ]);
  return { books, authors, categories };
};

/** `selectedId` comes from the URL: "new" opens an empty form, a book id opens that book. */
export function BooksPage({ selectedId }: { selectedId?: string }) {
  const { data, error, reload } = useLoad(loadCatalog);
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<StatusFilter>('all');
  const [categoryId, setCategoryId] = useState('');

  const books = data?.books ?? [];
  const counts = useMemo(() => ({
    all: books.length,
    PUBLISHED: books.filter((book) => book.status === 'PUBLISHED').length,
    DRAFT: books.filter((book) => book.status === 'DRAFT').length,
    incomplete: books.filter(missingFiles).length,
    live: books.filter((book) => book.status === 'PUBLISHED' && !missingFiles(book)).length,
  }), [books]);

  const visible = useMemo(() => {
    const text = query.trim().toLowerCase();
    return books.filter((book) =>
      (!text || book.title.toLowerCase().includes(text) || book.author.name.toLowerCase().includes(text))
      && (!categoryId || book.categoryId === categoryId)
      && (status === 'all' || (status === 'incomplete' ? missingFiles(book) : book.status === status)));
  }, [books, query, status, categoryId]);

  const selected = selectedId === 'new' ? null : books.find((book) => book.id === selectedId);
  const editorOpen = Boolean(data) && (selectedId === 'new' || Boolean(selected));

  async function togglePublish(book: Book) {
    const next = book.status === 'PUBLISHED' ? 'DRAFT' : 'PUBLISHED';
    try {
      await api(`/admin/books/${book.id}`, { method: 'PATCH', body: JSON.stringify({ status: next }) });
      toast(next === 'PUBLISHED' ? `«${book.title}» жарыяланды` : `«${book.title}» жашырылды`);
      await reload();
    } catch (value) {
      toast(errorText(value), 'error');
    }
  }

  return (
    <>
      <PageHeader
        title="Китептер"
        note={data ? `${counts.all} китеп · ${counts.live} окурмандарга көрүнөт` : undefined}
      >
        <button className="primary" onClick={() => go('books', 'new')}><Icon name="plus" />Китеп кошуу</button>
      </PageHeader>

      <div className="toolbar">
        <Search value={query} onChange={setQuery} placeholder="Аталышы же автору" />
        <Segmented<StatusFilter> label="Статус" value={status} onChange={setStatus} options={[
          { value: 'all', label: 'Баары', count: counts.all },
          { value: 'PUBLISHED', label: 'Жарыяланган', count: counts.PUBLISHED },
          { value: 'DRAFT', label: 'Долбоор', count: counts.DRAFT },
          { value: 'incomplete', label: 'Файлы жок', count: counts.incomplete },
        ]} />
        <select className="compact" value={categoryId} onChange={(e) => setCategoryId(e.target.value)} aria-label="Жанр">
          <option value="">Бардык жанрлар</option>
          {data?.categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
        </select>
      </div>

      {error && <ErrorBox text={error} onRetry={() => void reload()} />}
      {!data && !error && <Loading />}
      {data && (
        <div className="table-card">
          <table>
            <thead>
              <tr><th>Китеп</th><th>Жанр</th><th>Баасы</th><th className="num">Сатуу / ижара</th><th>Статус</th><th /></tr>
            </thead>
            <tbody>
              {visible.map((book) => (
                <tr key={book.id} className="clickable" onClick={() => go('books', book.id)}>
                  <td>
                    <div className="book-cell">
                      <Cover book={book} />
                      <div>
                        <strong>{book.title}</strong>
                        <small>{book.author.name}{book.isAdult ? ' · 18+' : ''}</small>
                      </div>
                    </div>
                  </td>
                  <td>{book.category.name}</td>
                  <td>{accessLabel(book)}</td>
                  <td className="num">{book._count?.purchases ?? 0} / {book._count?.rentals ?? 0}</td>
                  <td>
                    {missingFiles(book)
                      ? <Badge tone="red">Файлы жок</Badge>
                      : <Badge tone={book.status === 'PUBLISHED' ? 'green' : 'gray'}>{statusLabel[book.status]}</Badge>}
                  </td>
                  <td className="actions">
                    {!missingFiles(book) && (
                      <button className="link" onClick={(event) => { event.stopPropagation(); void togglePublish(book); }}>
                        {book.status === 'PUBLISHED' ? 'Жашыруу' : 'Жарыялоо'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!visible.length && <Empty title="Китеп табылган жок" text="Издөөнү же чыпканы өзгөртүп көрүңүз." />}
        </div>
      )}

      {editorOpen && data && (
        <BookEditor
          key={selectedId}
          book={selected ?? null}
          authors={data.authors}
          categories={data.categories}
          onClose={() => go('books')}
          onSaved={async () => { go('books'); await reload(); }}
        />
      )}
    </>
  );
}

export function Cover({ book, large }: { book: Pick<Book, 'title' | 'coverUrl'>; large?: boolean }) {
  return book.coverUrl
    ? <img className={large ? 'cover large' : 'cover'} src={book.coverUrl} alt="" loading="lazy" />
    : <div className={large ? 'cover large empty' : 'cover empty'}>{book.title.slice(0, 1)}</div>;
}

type Access = Book['accessType'];
const NEW_AUTHOR = '__new';

function formFromBook(book: Book | null, authors: Author[], categories: Category[]) {
  if (!book) {
    return {
      title: '', slug: '', description: '', authorId: authors[0]?.id ?? '', categoryId: categories[0]?.id ?? '',
      accessType: 'PURCHASE' as Access, price: 249, rentable: true, rentalPrice: 69, rentalDays: 14,
      pages: 100, status: 'DRAFT' as Book['status'], isAdult: false, isNew: true,
    };
  }
  const rentalPrice = Number(book.rentalPrice ?? 0);
  return {
    title: book.title, slug: book.slug, description: book.description, authorId: book.authorId,
    categoryId: book.categoryId, accessType: book.accessType, price: Number(book.price),
    rentable: rentalPrice > 0, rentalPrice: rentalPrice || 69, rentalDays: book.rentalDays,
    pages: book.pages, status: book.status, isAdult: book.isAdult, isNew: book.isNew,
  };
}

function BookEditor({ book, authors, categories, onClose, onSaved }: {
  book: Book | null;
  authors: Author[];
  categories: Category[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const [form, setForm] = useState(() => formFromBook(book, authors, categories));
  const [slugTouched, setSlugTouched] = useState(Boolean(book));
  const [newAuthor, setNewAuthor] = useState('');
  const [cover, setCover] = useState<File | null>(null);
  const [epub, setEpub] = useState<File | null>(null);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [archiving, setArchiving] = useState(false);
  const set = (patch: Partial<typeof form>) => setForm((current) => ({ ...current, ...patch }));

  const coverPreview = useMemo(() => (cover ? URL.createObjectURL(cover) : null), [cover]);
  useEffect(() => () => { if (coverPreview) URL.revokeObjectURL(coverPreview); }, [coverPreview]);

  const hasCover = Boolean(cover || book?.coverKey);
  const hasEpub = Boolean(epub || book?.epubKey);

  async function save(event: FormEvent) {
    event.preventDefault();
    setError('');
    if (form.status === 'PUBLISHED' && (!hasCover || !hasEpub)) {
      setError('Жарыялоо үчүн мукаба жана EPUB керек. Аларды жүктөңүз же долбоор катары сактаңыз.');
      return;
    }
    if (!book && (!cover || !epub)) {
      setError('Жаңы китепке мукаба жана EPUB файлын тандаңыз.');
      return;
    }
    setSaving(true);
    try {
      let authorId = form.authorId;
      if (authorId === NEW_AUTHOR) {
        const created = await api<Author>('/admin/authors', { method: 'POST', body: JSON.stringify({ name: newAuthor.trim() }) });
        authorId = created.id;
      }
      const free = form.accessType === 'FREE';
      const rental = form.accessType === 'RENTAL' || (form.accessType === 'PURCHASE' && form.rentable);
      const payload = {
        title: form.title.trim(),
        slug: form.slug.trim(),
        description: form.description.trim(),
        authorId,
        categoryId: form.categoryId,
        accessType: form.accessType,
        // Rental-only books have no sale price.
        price: form.accessType === 'PURCHASE' ? form.price : 0,
        rentalPrice: rental ? form.rentalPrice : null,
        rentalDays: free ? undefined : form.rentalDays,
        pages: form.pages,
        status: form.status,
        isAdult: form.isAdult,
        isNew: form.isNew,
      };
      if (!book) {
        const files = new FormData();
        files.append('data', JSON.stringify(payload));
        files.append('cover', cover!);
        files.append('epub', epub!);
        await api('/admin/books-with-files', { method: 'POST', body: files });
        toast(`«${payload.title}» кошулду`);
      } else {
        // Files go first, so a book can get its EPUB and be published in one save.
        if (cover || epub) {
          const files = new FormData();
          if (cover) files.append('cover', cover);
          if (epub) files.append('epub', epub);
          await api(`/admin/books/${book.id}/files`, { method: 'POST', body: files });
        }
        await api(`/admin/books/${book.id}`, { method: 'PATCH', body: JSON.stringify(payload) });
        toast('Өзгөртүүлөр сакталды');
      }
      await onSaved();
    } catch (value) {
      setError(errorText(value, 'Сакталган жок'));
      setSaving(false);
    }
  }

  return (
    <Drawer
      title={book ? book.title : 'Жаңы китеп'}
      subtitle={book ? `${book.author.name} · ${book._count?.purchases ?? 0} сатуу, ${book._count?.rentals ?? 0} ижара` : 'Маалыматты толтуруп, файлдарды жүктөңүз'}
      onClose={onClose}
      footer={<>
        {book && <button type="button" className="link danger" onClick={() => setArchiving(true)}>Архивге жиберүү</button>}
        <span className="spacer" />
        {error && <span className="footer-error">{error}</span>}
        <button type="button" className="secondary" onClick={onClose}>Жокко чыгаруу</button>
        <button type="submit" form="book-form" className="primary" disabled={saving}>{saving ? 'Сакталууда…' : 'Сактоо'}</button>
      </>}
    >
      <form id="book-form" className="editor" onSubmit={save}>
        <section className="files">
          {coverPreview
            ? <img className="cover large" src={coverPreview} alt="" />
            : <Cover book={{ title: form.title || '?', coverUrl: book?.coverUrl }} large />}
          <div className="file-list">
            <FilePick
              label="Мукаба"
              accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp"
              hint="JPG, PNG же WebP, 2:3"
              file={cover}
              uploaded={Boolean(book?.coverKey)}
              onChange={setCover}
            />
            <FilePick
              label="Китеп файлы"
              accept=".epub,application/epub+zip"
              hint="EPUB, 50 МБ чейин"
              file={epub}
              uploaded={Boolean(book?.epubKey)}
              onChange={setEpub}
            />
          </div>
        </section>

        <section>
          <h3>Негизги маалымат</h3>
          <div className="grid">
            <Field label="Аталышы" wide>
              <input value={form.title} required minLength={2} onChange={(e) => set({
                title: e.target.value, ...(slugTouched ? {} : { slug: slugify(e.target.value) }),
              })} />
            </Field>
            <Field label="Автор">
              <select value={form.authorId} required onChange={(e) => set({ authorId: e.target.value })}>
                <option value="" disabled>Тандаңыз</option>
                {authors.map((author) => <option key={author.id} value={author.id}>{author.name}</option>)}
                <option value={NEW_AUTHOR}>＋ Жаңы автор…</option>
              </select>
            </Field>
            <Field label="Жанр">
              <select value={form.categoryId} required onChange={(e) => set({ categoryId: e.target.value })}>
                <option value="" disabled>Тандаңыз</option>
                {categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
              </select>
            </Field>
            {form.authorId === NEW_AUTHOR && (
              <Field label="Жаңы автордун аты" hint="Китеп сакталганда автор да кошулат" wide>
                <input value={newAuthor} required minLength={2} autoFocus onChange={(e) => setNewAuthor(e.target.value)} />
              </Field>
            )}
            <Field label="Сүрөттөмө" wide>
              <textarea rows={5} value={form.description} required onChange={(e) => set({ description: e.target.value })} />
            </Field>
          </div>
        </section>

        <section>
          <h3>Окурман китепти кантип алат</h3>
          <Segmented<Access> label="Жеткиликтүүлүк" value={form.accessType} onChange={(accessType) => set({ accessType })} options={[
            { value: 'PURCHASE', label: 'Сатып алуу' },
            { value: 'RENTAL', label: 'Ижара гана' },
            { value: 'FREE', label: 'Акысыз' },
          ]} />
          <div className="grid">
            {form.accessType === 'PURCHASE' && (
              <Field label="Баасы, сом">
                <input type="number" min={1} value={form.price} required onChange={(e) => set({ price: Number(e.target.value) })} />
              </Field>
            )}
            {form.accessType === 'PURCHASE' && (
              <label className="check align-end">
                <input type="checkbox" checked={form.rentable} onChange={(e) => set({ rentable: e.target.checked })} />
                Ижарага да берүү
              </label>
            )}
            {(form.accessType === 'RENTAL' || (form.accessType === 'PURCHASE' && form.rentable)) && <>
              <Field label="Ижара баасы, сом">
                <input type="number" min={1} value={form.rentalPrice} required onChange={(e) => set({ rentalPrice: Number(e.target.value) })} />
              </Field>
              <Field label="Ижара мөөнөтү, күн">
                <input type="number" min={1} value={form.rentalDays} required onChange={(e) => set({ rentalDays: Number(e.target.value) })} />
              </Field>
            </>}
            {form.accessType === 'FREE' && <p className="muted wide">Китепти ар бир катталган окурман акысыз окуй алат.</p>}
          </div>
        </section>

        <section>
          <h3>Жарыялоо</h3>
          <Segmented<Book['status']> label="Статус" value={form.status} onChange={(status) => set({ status })} options={[
            { value: 'DRAFT', label: 'Долбоор' },
            { value: 'PUBLISHED', label: 'Жарыяланган' },
          ]} />
          <p className="muted">
            {form.status === 'PUBLISHED' ? 'Китеп каталогдо көрүнөт.' : 'Китепти окурмандар көрбөйт.'}
          </p>
          <div className="checks">
            <label className="check"><input type="checkbox" checked={form.isNew} onChange={(e) => set({ isNew: e.target.checked })} /> «Жаңы келгендер» тизмесинде көрсөтүү</label>
            <label className="check"><input type="checkbox" checked={form.isAdult} onChange={(e) => set({ isAdult: e.target.checked })} /> 18+ мазмун</label>
          </div>
        </section>

        <details className="more">
          <summary>Кошумча</summary>
          <div className="grid">
            <Field label="Беттердин саны">
              <input type="number" min={1} value={form.pages} required onChange={(e) => set({ pages: Number(e.target.value) })} />
            </Field>
            <Field label="URL белгиси" hint="Китептин шилтемесинде колдонулат">
              <input value={form.slug} required minLength={2} onChange={(e) => { setSlugTouched(true); set({ slug: e.target.value }); }} />
            </Field>
          </div>
        </details>
      </form>

      {archiving && book && (
        <Confirm
          title="Китепти архивге жиберүү"
          text={`«${book.title}» каталогдон алынат. Аны сатып алган окурмандар окуй беришет.`}
          confirmLabel="Архивге жиберүү"
          danger
          onClose={() => setArchiving(false)}
          onConfirm={async () => {
            await api(`/admin/books/${book.id}`, { method: 'DELETE' });
            toast(`«${book.title}» архивге жиберилди`);
            await onSaved();
          }}
        />
      )}
    </Drawer>
  );
}

function FilePick({ label, accept, hint, file, uploaded, onChange }: {
  label: string;
  accept: string;
  hint: string;
  file: File | null;
  uploaded: boolean;
  onChange: (file: File | null) => void;
}) {
  const state = file ? file.name : uploaded ? 'Жүктөлгөн' : 'Жүктөлө элек';
  return (
    <label className={`file-pick ${file || uploaded ? 'ok' : 'missing'}`}>
      <Icon name={file || uploaded ? 'check' : 'upload'} />
      <span>
        <strong>{label}</strong>
        <small>{state} · {hint}</small>
      </span>
      <span className="link">{file || uploaded ? 'Алмаштыруу' : 'Тандоо'}</span>
      <input type="file" accept={accept} onChange={(e) => onChange(e.target.files?.[0] ?? null)} />
    </label>
  );
}
