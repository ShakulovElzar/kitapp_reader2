import { useMemo, useState } from 'react';
import { api } from '../api';
import { day, errorText, phone } from '../format';
import { toast } from '../toast';
import type { Reader } from '../types';
import { Badge, Confirm, Dialog, Empty, ErrorBox, Field, Loading, PageHeader, Search, Segmented, useLoad } from '../ui';

type Filter = 'all' | 'active' | 'blocked';

export function ReadersPage() {
  const { data, error, reload } = useLoad(() => api<Reader[]>('/admin/readers'));
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [blocking, setBlocking] = useState<Reader | null>(null);
  const [unblocking, setUnblocking] = useState<Reader | null>(null);

  const readers = data ?? [];
  const blocked = readers.filter((reader) => reader.isBlocked).length;
  const visible = useMemo(() => {
    const digits = query.replace(/\D/g, '');
    const text = query.trim().toLowerCase();
    return readers.filter((reader) =>
      (filter === 'all' || (filter === 'blocked') === reader.isBlocked)
      && (!text || (digits && reader.phone.replace(/\D/g, '').includes(digits)) || reader.name?.toLowerCase().includes(text)));
  }, [readers, query, filter]);

  return (
    <>
      <PageHeader title="Окурмандар" note={data ? `${readers.length} катталган · ${blocked} бөгөттөлгөн` : undefined} />
      <div className="toolbar">
        <Search value={query} onChange={setQuery} placeholder="Телефон же аты" />
        <Segmented<Filter> label="Статус" value={filter} onChange={setFilter} options={[
          { value: 'all', label: 'Баары', count: readers.length },
          { value: 'active', label: 'Активдүү', count: readers.length - blocked },
          { value: 'blocked', label: 'Бөгөттөлгөн', count: blocked },
        ]} />
      </div>
      {error && <ErrorBox text={error} onRetry={() => void reload()} />}
      {!data && !error && <Loading />}
      {data && (
        <div className="table-card">
          <table>
            <thead>
              <tr><th>Телефон</th><th>Катталган</th><th className="num">Сатып алган</th><th className="num">Ижара</th><th>Статус</th><th /></tr>
            </thead>
            <tbody>
              {visible.map((reader) => (
                <tr key={reader.id}>
                  <td><strong>{phone(reader.phone)}</strong>{reader.name && <small>{reader.name}</small>}</td>
                  <td>{day(reader.createdAt)}</td>
                  <td className="num">{reader._count.purchases}</td>
                  <td className="num">{reader._count.rentals}</td>
                  <td>
                    {reader.isBlocked
                      ? <><Badge tone="red">Бөгөттөлгөн</Badge>{reader.blockNote && <small>{reader.blockNote}</small>}</>
                      : <Badge tone="green">Активдүү</Badge>}
                  </td>
                  <td className="actions">
                    {reader.isBlocked
                      ? <button className="link" onClick={() => setUnblocking(reader)}>Бөгөттөн чыгаруу</button>
                      : <button className="link danger" onClick={() => setBlocking(reader)}>Бөгөттөө</button>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!visible.length && <Empty title="Окурман табылган жок" />}
        </div>
      )}
      {blocking && <BlockDialog reader={blocking} onClose={() => setBlocking(null)} onDone={reload} />}
      {unblocking && (
        <Confirm
          title="Бөгөттөн чыгаруу"
          text={`${phone(unblocking.phone)} кайра кирип, китептерин окуй алат.`}
          confirmLabel="Бөгөттөн чыгаруу"
          onClose={() => setUnblocking(null)}
          onConfirm={async () => {
            await api(`/admin/readers/${unblocking.id}/block`, { method: 'PATCH', body: JSON.stringify({ isBlocked: false }) });
            toast('Окурман бөгөттөн чыгарылды');
            await reload();
          }}
        />
      )}
    </>
  );
}

function BlockDialog({ reader, onClose, onDone }: { reader: Reader; onClose: () => void; onDone: () => Promise<void> }) {
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function block() {
    setBusy(true);
    try {
      await api(`/admin/readers/${reader.id}/block`, {
        method: 'PATCH',
        body: JSON.stringify({ isBlocked: true, blockNote: note.trim() || 'Администратор тарабынан бөгөттөлдү' }),
      });
      toast(`${phone(reader.phone)} бөгөттөлдү`);
      onClose();
      await onDone();
    } catch (value) {
      setError(errorText(value));
      setBusy(false);
    }
  }

  return (
    <Dialog title="Окурманды бөгөттөө" onClose={onClose} actions={<>
      <button className="secondary" onClick={onClose}>Жокко чыгаруу</button>
      <button className="danger" disabled={busy} onClick={() => void block()}>{busy ? 'Күтүңүз…' : 'Бөгөттөө'}</button>
    </>}>
      <p>{phone(reader.phone)} дароо чыгарылат жана китептерин ача албай калат.</p>
      <Field label="Себеби" hint="Ички белги, окурман аны көрбөйт">
        <textarea rows={3} value={note} onChange={(e) => setNote(e.target.value)} placeholder="Мисалы: шектүү төлөмдөр" />
      </Field>
      {error && <ErrorBox text={error} />}
    </Dialog>
  );
}
