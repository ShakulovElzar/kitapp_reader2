import { useEffect, useState } from 'react';
import { api } from '../api';
import { bishkekToday, errorText, som } from '../format';
import type { SalesReport } from '../types';
import { Empty, ErrorBox, Field, Icon, Loading, PageHeader, Stat } from '../ui';

const shift = (date: string, days: number) => {
  const value = new Date(`${date}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
};

/** Ready-made periods; all days are Bishkek calendar days. */
function presets() {
  const today = bishkekToday();
  const monthStart = `${today.slice(0, 7)}-01`;
  const lastMonthEnd = shift(monthStart, -1);
  return [
    { label: 'Бул ай', from: monthStart, to: today },
    { label: 'Өткөн ай', from: `${lastMonthEnd.slice(0, 7)}-01`, to: lastMonthEnd },
    { label: 'Акыркы 7 күн', from: shift(today, -6), to: today },
    { label: 'Акыркы 30 күн', from: shift(today, -29), to: today },
    { label: 'Бул жыл', from: `${today.slice(0, 4)}-01-01`, to: today },
  ];
}

function downloadCsv(report: SalesReport) {
  const rows = [
    ['Китеп', 'Автор', 'Сатылганы', 'Сатуудан киреше', 'Ижара', 'Ижарадан киреше', 'Жалпы киреше'],
    ...report.items.map((item) => [item.title, item.author, item.quantity, item.salesRevenue, item.rentals, item.rentalRevenue, item.revenue]),
    ['Жыйынтык', '', report.totalQuantity, report.salesRevenue, report.totalRentals, report.rentalRevenue, report.totalRevenue],
  ];
  const csv = rows.map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(',')).join('\n');
  // The BOM makes Excel read the Cyrillic text correctly.
  const url = URL.createObjectURL(new Blob(['﻿', csv], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = `kitapp-otchet-${report.from}-${report.to}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

export function ReportsPage() {
  const options = presets();
  const [from, setFrom] = useState(options[0].from);
  const [to, setTo] = useState(options[0].to);
  const [report, setReport] = useState<SalesReport | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!from || !to) return;
    let current = true;
    setLoading(true);
    setError('');
    api<SalesReport>(`/admin/reports/sales?from=${from}&to=${to}`)
      .then((value) => { if (current) setReport(value); })
      .catch((value) => { if (current) setError(errorText(value, 'Отчёт жүктөлгөн жок')); })
      .finally(() => { if (current) setLoading(false); });
    return () => { current = false; };
  }, [from, to]);

  const maximum = Math.max(1, ...(report?.items.map((item) => item.revenue) ?? []));

  return (
    <>
      <PageHeader title="Отчёт" note="Сатуулар жана ижаралар, Бишкек убактысы боюнча">
        {report && report.items.length > 0 && (
          <button className="secondary" onClick={() => downloadCsv(report)}><Icon name="download" />CSV жүктөп алуу</button>
        )}
      </PageHeader>

      <div className="toolbar">
        <div className="chips">
          {options.map((option) => (
            <button key={option.label} className={option.from === from && option.to === to ? 'chip active' : 'chip'}
              onClick={() => { setFrom(option.from); setTo(option.to); }}>
              {option.label}
            </button>
          ))}
        </div>
        <div className="date-range">
          <Field label="Башталышы"><input type="date" value={from} max={to} onChange={(e) => setFrom(e.target.value)} /></Field>
          <Field label="Аягы"><input type="date" value={to} min={from} onChange={(e) => setTo(e.target.value)} /></Field>
        </div>
      </div>

      {error && <ErrorBox text={error} />}
      {!report && !error && <Loading />}
      {report && (
        <div className={loading ? 'stale' : ''}>
          <section className="stats">
            <Stat label="Жалпы киреше" value={som(report.totalRevenue)} note="сатуу + ижара" />
            <Stat label="Сатылган китеп" value={report.totalQuantity} note={som(report.salesRevenue)} />
            <Stat label="Ижаралар" value={report.totalRentals} note={som(report.rentalRevenue)} />
            <Stat label="Сатылган аталыштар" value={report.items.length} note="ар кандай китеп" />
          </section>
          <div className="table-card">
            <table>
              <thead>
                <tr><th>Китеп</th><th className="num">Сатуу</th><th className="num">Ижара</th><th>Үлүшү</th><th className="num">Киреше</th></tr>
              </thead>
              <tbody>
                {report.items.map((item) => (
                  <tr key={item.bookId}>
                    <td><strong>{item.title}</strong><small>{item.author}</small></td>
                    <td className="num">{item.quantity}</td>
                    <td className="num">{item.rentals}</td>
                    <td><div className="bar"><i style={{ width: `${(item.revenue / maximum) * 100}%` }} /></div></td>
                    <td className="num"><strong>{som(item.revenue)}</strong></td>
                  </tr>
                ))}
              </tbody>
            </table>
            {!report.items.length && <Empty title="Бул мезгилде сатуу болгон жок" text="Башка мезгилди тандап көрүңүз." />}
          </div>
        </div>
      )}
    </>
  );
}
