import { useMemo, useState } from 'react'
import { useData } from '../store'
import { LineChart } from '../components/charts'
import { Seg } from '../components/ui'
import { addDays, sessionVolume, todayKey } from '../lib/format'
import { isLowerBetter } from '../lib/presets'

type Metric = 'weight' | 'bodyFat' | 'muscle' | 'lbm' | 'volume' | 'lift' | 'ability' | 'sleep' | 'condition'
const METRICS: { id: Metric; label: string; color: string; unit: string }[] = [
  { id: 'weight', label: '体重', color: '#0087ff', unit: 'kg' },
  { id: 'bodyFat', label: '体脂肪率', color: '#ff9500', unit: '%' },
  { id: 'muscle', label: '筋肉量', color: '#33c759', unit: 'kg' },
  { id: 'lbm', label: '除脂肪体重', color: '#14b8a6', unit: 'kg' },
  { id: 'lift', label: '種目別の重量', color: '#ff3b61', unit: 'kg' },
  { id: 'volume', label: '総挙上量', color: '#8f59f7', unit: 'kg' },
  { id: 'ability', label: '身体能力', color: '#eab308', unit: '' },
  { id: 'sleep', label: '睡眠', color: '#6366f1', unit: '時間' },
  { id: 'condition', label: '体調', color: '#22c55e', unit: '' },
]
type Period = '30' | '90' | '180' | '365' | 'all'

export function Graph() {
  const d = useData()
  const [metric, setMetric] = useState<Metric>('weight')
  const [period, setPeriod] = useState<Period>('90')
  const [liftMode, setLiftMode] = useState<'max' | 'e1rm'>('max')

  const abilityTypes = useMemo(() => [...new Set(d.abilities.map((a) => a.type))], [d.abilities])
  const exercises = useMemo(() => {
    const c = new Map<string, number>()
    for (const s of d.sessions) for (const x of s.exercises) if (x.sets.some((y) => y.weight)) c.set(x.name, (c.get(x.name) ?? 0) + 1)
    return [...c.entries()].sort((a, b) => b[1] - a[1]).map(([n]) => n)
  }, [d.sessions])
  const [abilityType, setAbilityType] = useState('')
  const [exercise, setExercise] = useState('')
  const aType = abilityTypes.includes(abilityType) ? abilityType : abilityTypes[0] ?? ''
  const ex = exercises.includes(exercise) ? exercise : exercises[0] ?? ''

  const meta = METRICS.find((m) => m.id === metric)!
  const unit = metric === 'ability' ? d.abilities.find((a) => a.type === aType)?.unit ?? '' : meta.unit
  const lower = metric === 'ability' ? isLowerBetter(aType) : metric === 'bodyFat' || metric === 'condition'

  const series = useMemo(() => {
    const from = period === 'all' ? '0000' : addDays(todayKey(), -Number(period))
    const byDay = new Map<string, number>()
    const put = (k: string, v: number | undefined, agg: 'last' | 'sum' | 'max' = 'last') => {
      if (v == null || k < from) return
      const cur = byDay.get(k)
      byDay.set(k, cur == null ? v : agg === 'sum' ? cur + v : agg === 'max' ? Math.max(cur, v) : v)
    }
    const bodies = [...d.bodies].sort((a, b) => a.date.localeCompare(b.date))
    switch (metric) {
      case 'weight': bodies.forEach((b) => put(b.date, b.weight)); break
      case 'bodyFat': bodies.forEach((b) => put(b.date, b.bodyFat)); break
      case 'muscle': bodies.forEach((b) => put(b.date, b.muscle)); break
      case 'lbm': bodies.forEach((b) => put(b.date, b.weight != null && b.bodyFat != null ? b.weight * (1 - b.bodyFat / 100) : undefined)); break
      case 'volume': d.sessions.forEach((s) => sessionVolume(s) > 0 && put(s.date, sessionVolume(s), 'sum')); break
      case 'lift':
        d.sessions.forEach((s) => s.exercises.filter((x) => x.name === ex).forEach((x) => x.sets.forEach((y) => {
          if (y.weight == null) return
          // 推定1RM（Epley式）: 重量 × (1 + 回数/30)
          const v = liftMode === 'max' ? y.weight : y.reps ? y.weight * (1 + y.reps / 30) : y.weight
          put(s.date, Math.round(v * 10) / 10, 'max')
        })))
        break
      case 'ability': d.abilities.filter((a) => a.type === aType).forEach((a) => put(a.date, a.value)); break
      case 'sleep': d.conditions.forEach((c) => put(c.date, c.sleep)); break
      case 'condition': d.conditions.forEach((c) => put(c.date, c.condition)); break
    }
    return [...byDay.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([date, value]) => ({ date, value }))
  }, [d, metric, period, aType, ex, liftMode])

  const digits = unit === '秒' ? 2 : 1
  const vs = series.map((s) => s.value)
  const first = vs[0], last = vs[vs.length - 1]
  const change = vs.length > 1 ? last - first : undefined
  const good = change == null ? null : lower ? change < 0 : change > 0

  return (
    <div className="wrap">
      <div className="chips scroll" style={{ marginBottom: 10 }}>
        {METRICS.map((m) => <button key={m.id} className={'chip' + (metric === m.id ? ' on' : '')} onClick={() => setMetric(m.id)}>{m.label}</button>)}
      </div>
      {metric === 'ability' && abilityTypes.length > 0 && (
        <div className="chips scroll" style={{ marginBottom: 10 }}>
          {abilityTypes.map((t) => <button key={t} className={'chip' + (aType === t ? ' on' : '')} onClick={() => setAbilityType(t)}>{t}</button>)}
        </div>
      )}
      {metric === 'lift' && exercises.length > 0 && (
        <>
          <div className="chips scroll" style={{ marginBottom: 10 }}>
            {exercises.map((t) => <button key={t} className={'chip' + (ex === t ? ' on' : '')} onClick={() => setExercise(t)}>{t}</button>)}
          </div>
          <div style={{ marginBottom: 10 }}>
            <Seg value={liftMode} onChange={setLiftMode} options={[{ id: 'max', label: 'その日の最大重量' }, { id: 'e1rm', label: '推定1RM' }]} />
          </div>
        </>
      )}
      <div className="card">
        <div className="card-h">
          <h2>{metric === 'ability' ? aType || '身体能力' : metric === 'lift' ? ex || '種目別の重量' : meta.label}</h2>
        </div>
        <LineChart data={series} color={meta.color} unit={unit} digits={digits} />
        <div style={{ marginTop: 12 }}>
          <Seg value={period} onChange={setPeriod} options={[{ id: '30', label: '1ヶ月' }, { id: '90', label: '3ヶ月' }, { id: '180', label: '半年' }, { id: '365', label: '1年' }, { id: 'all', label: '全期間' }]} />
        </div>
      </div>
      {vs.length > 0 && (
        <div className="grid2">
          <div className="card stat" style={{ margin: 0 }}><div className="l">最新</div><div className="v">{last.toFixed(digits)}<small>{unit}</small></div></div>
          <div className="card stat" style={{ margin: 0 }}>
            <div className="l">期間の変化</div>
            <div className="v" style={{ color: good == null ? undefined : good ? 'var(--green)' : 'var(--pink)' }}>
              {change == null ? '—' : `${change > 0 ? '+' : ''}${change.toFixed(digits)}`}<small>{change == null ? '' : unit}</small>
            </div>
          </div>
          <div className="card stat" style={{ margin: 0 }}><div className="l">最高</div><div className="v">{Math.max(...vs).toFixed(digits)}<small>{unit}</small></div></div>
          <div className="card stat" style={{ margin: 0 }}><div className="l">最低</div><div className="v">{Math.min(...vs).toFixed(digits)}<small>{unit}</small></div></div>
        </div>
      )}
      {metric === 'lift' && liftMode === 'e1rm' && <p className="sub">推定1RMはEpley式（重量×(1+回数÷30)）で、その日のセットのうち最大の値です。</p>}
      {metric === 'condition' && <p className="sub">体調は 1＝最高、5＝不調 です。</p>}
    </div>
  )
}
