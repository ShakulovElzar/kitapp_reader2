import { useMemo, useState } from 'react';
import { api } from '../api';
import { day, dayTime, phone, som } from '../format';
import type { Transaction } from '../types';
import { Badge, Empty, ErrorBox, Loading, PageHeader, Search, Segmented, Tone, useLoad } from '../ui';

type Tab = 'sales' | 'rentals';

const paymentStatus: Record<Transaction['status'], [string, Tone]> = {
  COMPLETED: ['Төлөндү', 'green'],
  PENDING: ['Күтүлүүдө', 'amber'],
  REFUNDED: ['Кайтарылды', 'gray'],
  CANCELLED: ['Жокко чыгарылды', 'gray'],
};

function status(item: Transaction, tab: Tab): [string, Tone] {
  if (tab === 'rentals' && item.status === 'COMPLETED' && item.endsAt) {
    return new Date(item.endsAt) > new Date() ? [`${day(item.endsAt)} чейин`, 'green'] : ['Мөөнөтү бүттү', 'gray'];
  }
  return paymentStatus[item.status] ?? [item.status, 'gray'];
}

const load = async () => {
  const [sales, rentals] = await Promise.all([api<Transaction[]>('/admin/purchases'), api<Transaction[]>('/admin/rentals')]);
  return { sales, rentals };
};

export function OrdersPage() {
  const { data, error, reload } = useLoad(load);
  const [tab, setTab] = useState<Tab>('sales');
  const [query, setQuery] = useState('');

  const visible = useMemo(() => {
    const items = data?.[tab] ?? [];
    const text = query.trim().toLowerCase();
    const digits = query.replace(/\D/g, '');
    return items.filter((item) => !text
      || item.book.title.toLowerCase().includes(text)
      || item.book.author.name.toLowerCase().includes(text)
      || (digits && item.reader.phone.replace(/\D/g, '').includes(digits)));
  }, [data, tab, query]);

  const paid = visible.filter((item) => item.status === 'COMPLETED');
  const total = paid.reduce((sum, item) => sum + Number(item.amount), 0);

  return (
    <>
      <PageHeader title="Төлөмдөр" note="Китеп сатуулары жана ижаралары" />
      <div className="toolbar">
        <Segmented<Tab> label="Түрү" value={tab} onChange={setTab} options={[
          { value: 'sales', label: 'Сатуулар', count: data?.sales.length },
          { value: 'rentals', label: 'Ижаралар', count: data?.rentals.length },
        ]} />
        <Search value={query} onChange={setQuery} placeholder="Китеп, автор же телефон" />
        {data && <span className="toolbar-note">Төлөнгөнү: <strong>{som(total)}</strong></span>}
      </div>
      {error && <ErrorBox text={error} onRetry={() => void reload()} />}
      {!data && !error && <Loading />}
      {data && (
        <div className="table-card">
          <table>
            <thead>
              <tr><th>Китеп</th><th>Окурман</th><th>Күнү</th><th className="num">Сумма</th><th>Статус</th></tr>
            </thead>
            <tbody>
              {visible.map((item) => {
                const [label, tone] = status(item, tab);
                return (
                  <tr key={item.id}>
                    <td><strong>{item.book.title}</strong><small>{item.book.author.name}</small></td>
                    <td>{phone(item.reader.phone)}</td>
                    <td>{dayTime(item.createdAt)}</td>
                    <td className="num"><strong>{som(item.amount)}</strong></td>
                    <td><Badge tone={tone}>{label}</Badge></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {!visible.length && <Empty title={query ? 'Табылган жок' : 'Азырынча төлөм жок'} />}
        </div>
      )}
    </>
  );
}
