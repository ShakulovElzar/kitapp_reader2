import { useMemo, useState } from 'react';
import { api } from '../api';
import { day, time } from '../format';
import type { AuditLog } from '../types';
import { Empty, ErrorBox, Loading, PageHeader, Segmented, useLoad } from '../ui';

type Entity = 'all' | 'Book' | 'Author' | 'Category' | 'Reader';

const actions: Record<string, string> = {
  CREATE: 'кошту', UPDATE: 'өзгөрттү', DELETE: 'өчүрдү', UPLOAD: 'файл жүктөдү', BLOCK: 'бөгөттөдү', UNBLOCK: 'бөгөттөн чыгарды',
};
const entities: Record<string, string> = { Book: 'китеп', Author: 'автор', Category: 'жанр', Reader: 'окурман' };

/** The record's name when the log kept it (title on create, name on rename). */
function subject(log: AuditLog) {
  const meta = log.metadata ?? {};
  const value = meta.title ?? meta.name;
  return typeof value === 'string' ? `«${value}»` : '';
}

export function AuditPage() {
  const { data, error, reload } = useLoad(() => api<AuditLog[]>('/admin/audit-logs'));
  const [entity, setEntity] = useState<Entity>('all');

  const groups = useMemo(() => {
    const result: Array<{ day: string; logs: AuditLog[] }> = [];
    for (const log of data ?? []) {
      if (entity !== 'all' && log.entity !== entity) continue;
      const label = day(log.createdAt);
      if (result.at(-1)?.day !== label) result.push({ day: label, logs: [] });
      result.at(-1)!.logs.push(log);
    }
    return result;
  }, [data, entity]);

  return (
    <>
      <PageHeader title="Аракеттер журналы" note="Администраторлордун акыркы 200 аракети" />
      <div className="toolbar">
        <Segmented<Entity> label="Түрү" value={entity} onChange={setEntity} options={[
          { value: 'all', label: 'Баары' },
          { value: 'Book', label: 'Китептер' },
          { value: 'Author', label: 'Авторлор' },
          { value: 'Category', label: 'Жанрлар' },
          { value: 'Reader', label: 'Окурмандар' },
        ]} />
      </div>
      {error && <ErrorBox text={error} onRetry={() => void reload()} />}
      {!data && !error && <Loading />}
      {data && (
        <div className="card">
          {groups.map((group) => (
            <section key={group.day} className="log-day">
              <h3>{group.day}</h3>
              <ul className="rows">
                {group.logs.map((log) => (
                  <li key={log.id} className="row">
                    <span className="time">{time(log.createdAt)}</span>
                    <span className="grow">
                      <strong>{log.admin.name}</strong> {log.action === 'DELETE' && log.entity === 'Book' ? 'архивге жиберди' : actions[log.action] ?? log.action}: {entities[log.entity] ?? log.entity} {subject(log)}
                      <small>{log.admin.email}</small>
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          ))}
          {!groups.length && <Empty title="Аракеттер жок" />}
        </div>
      )}
    </>
  );
}
