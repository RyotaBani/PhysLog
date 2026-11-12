import { useMemo, useState } from 'react'
import { useData } from '../store'
import type { Editing } from './Today'
import { abilityIcon } from '../lib/presets'
import { labelDate, num, sessionVolume, setsSummary } from '../lib/format'
import { CONDITION_LABELS } from '../lib/presets'

type Filter = 'all' | 'training' | 'body' | 'ability' | 'condition'
const FILTERS: { id: Filter; label: string }[] = [
  { id: 'all', label: 'すべて' },
  { id: 'training', label: '🏋️ トレーニング' },
  { id: 'body', label: '⚖️ 身体測定' },
  { id: 'ability', label: '⚡ 身体能力' },
  { id: 'condition', label: '😊 コンディション' },
]

interface Row { date: string; key: string; edit: Editing; icon: string; title: string; detail: string; right?: string }

export function History(props: { onEdit: (e: Editing) => void }) {
  const d = useData()
  const [filter, setFilter] = useState<Filter>('all')
  const [q, setQ] = useState('')
  const [limit, setLimit] = useState(30)

  const groups = useMemo(() => {
    const rows: Row[] = []
    if (filter === 'all' || filter === 'training')
      for (const s of d.sessions)
        rows.push({
          date: s.date, key: s.id, edit: { kind: 'training', date: s.date, item: s }, icon: '🏋️',
          title: s.sport || 'トレーニング',
          detail: s.exercises.map((x) => `${x.name} ${setsSummary(x.sets)}`).join('\n') + (s.memo ? `\n${s.memo}` : ''),
          right: sessionVolume(s) ? `${Math.round(sessionVolume(s)).toLocaleString()}kg` : undefined,
        })
    if (filter === 'all' || filter === 'body')
      for (const b of d.bodies)
        rows.push({
          date: b.date, key: b.id, edit: { kind: 'body', date: b.date, item: b }, icon: '⚖️', title: '身体測定',
          detail: [b.weight != null && `体重 ${num(b.weight)}kg`, b.bodyFat != null && `体脂肪 ${num(b.bodyFat)}%`, b.muscle != null && `筋肉量 ${num(b.muscle)}kg`].filter(Boolean).join('・'),
        })
    if (filter === 'all' || filter === 'ability')
      for (const a of d.abilities)
        rows.push({
          date: a.date, key: a.id, edit: { kind: 'ability', date: a.date, item: a }, icon: abilityIcon(a.type), title: a.type,
          detail: a.memo, right: `${a.unit === '秒' ? a.value.toFixed(2) : num(a.value)}${a.unit}`,
        })
    if (filter === 'all' || filter === 'condition')
      for (const c of d.conditions)
        rows.push({
          date: c.date, key: c.id, edit: { kind: 'condition', date: c.date, item: c }, icon: '😊', title: 'コンディション',
          detail: [c.condition && `体調 ${CONDITION_LABELS[c.condition - 1]}`, c.fatigue && `疲労 ${c.fatigue}`, c.sleep != null && `睡眠 ${c.sleep}h`, c.memo].filter(Boolean).join('・'),
        })
    const query = q.trim()
    const filtered = query ? rows.filter((r) => (r.title + r.detail).includes(query)) : rows
    filtered.sort((a, b) => b.date.localeCompare(a.date))
    const map = new Map<string, Row[]>()
    for (const r of filtered) {
      if (!map.has(r.date)) map.set(r.date, [])
      map.get(r.date)!.push(r)
    }
    return [...map.entries()]
  }, [d, filter, q])

  return (
    <div className="wrap">
      <div className="chips scroll" style={{ marginBottom: 10 }}>
        {FILTERS.map((f) => <button key={f.id} className={'chip' + (filter === f.id ? ' on' : '')} onClick={() => setFilter(f.id)}>{f.label}</button>)}
      </div>
      <div className="row" style={{ marginBottom: 12 }}>
        <input placeholder="🔍 種目名・メモで検索" value={q} onChange={(e) => setQ(e.target.value)} />
        <button className="btn sm" style={{ whiteSpace: 'nowrap' }} onClick={() => props.onEdit({ kind: 'text' })}>📝 メモから取り込む</button>
      </div>
      <p className="sub" style={{ margin: '-4px 4px 12px' }}>記録を押すと、日付も含めて直せます。</p>
      {groups.length === 0 && <div className="card empty">記録がありません</div>}
      {groups.slice(0, limit).map(([date, rows]) => (
        <div key={date} style={{ marginBottom: 14 }}>
          <div className="sub" style={{ fontWeight: 800, margin: '0 4px 6px' }}>{labelDate(date)}</div>
          <div className="card" style={{ padding: '4px 16px' }}>
            {rows.map((r) => (
              <div key={r.key} className="list-item tap" onClick={() => props.onEdit(r.edit)} style={{ alignItems: 'flex-start' }}>
                <span style={{ fontSize: 18, lineHeight: '22px' }}>{r.icon}</span>
                <div className="grow">
                  <div style={{ fontWeight: 700 }}>{r.title}</div>
                  {r.detail && <div className="sub" style={{ whiteSpace: 'pre-line', lineHeight: 1.6 }}>{r.detail}</div>}
                </div>
                {r.right && <b style={{ whiteSpace: 'nowrap' }}>{r.right}</b>}
              </div>
            ))}
          </div>
        </div>
      ))}
      {groups.length > limit && <button className="btn block" onClick={() => setLimit((l) => l + 30)}>さらに表示</button>}
    </div>
  )
}
