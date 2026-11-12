import { useMemo, useState } from 'react'
import { actions, uid, useData } from '../store'
import type { BodyMeasurement, ConditionRecord, PhysicalAbility, TrainingSession } from '../types'
import { DateNav, Scale, toast } from '../components/ui'
import { AbilityForm, BodyForm, ConditionForm, TrainingForm } from '../forms/Forms'
import { TextImport } from '../forms/TextImport'
import { CONDITION_COLORS, abilityIcon, isLowerBetter } from '../lib/presets'
import { addDays, num, sessionVolume, setsSummary, todayKey } from '../lib/format'

export type Editing =
  | { kind: 'body'; date: string; item?: BodyMeasurement }
  | { kind: 'condition'; date: string; item?: ConditionRecord }
  | { kind: 'ability'; date: string; item?: PhysicalAbility }
  | { kind: 'training'; date: string; item?: TrainingSession }
  | { kind: 'text' }

export function EditorHost(props: { editing: Editing | null; onClose: () => void }) {
  const e = props.editing
  if (!e) return null
  if (e.kind === 'text') return <TextImport onClose={props.onClose} />
  const p = { date: e.date, onClose: props.onClose }
  switch (e.kind) {
    case 'body': return <BodyForm {...p} existing={e.item} />
    case 'condition': return <ConditionForm {...p} existing={e.item} />
    case 'ability': return <AbilityForm {...p} existing={e.item} />
    case 'training': return <TrainingForm {...p} existing={e.item} />
  }
}

export function Today(props: { onEdit: (e: Editing) => void }) {
  const d = useData()
  const [date, setDate] = useState(todayKey())

  const daySessions = d.sessions.filter((s) => s.date === date)
  const body = d.bodies.filter((b) => b.date === date).at(-1)
  const cond = d.conditions.filter((c) => c.date === date).at(-1)
  const dayAbilities = d.abilities.filter((a) => a.date === date)

  const prevBody = useMemo(
    () => [...d.bodies].filter((b) => b.date < date && b.weight != null).sort((a, b) => b.date.localeCompare(a.date))[0],
    [d.bodies, date],
  )
  const weekCount = useMemo(() => {
    const from = addDays(date, -6)
    return new Set(d.sessions.filter((s) => s.date >= from && s.date <= date).map((s) => s.date)).size
  }, [d.sessions, date])
  const weekVolume = useMemo(() => {
    const from = addDays(date, -6)
    return d.sessions.filter((s) => s.date >= from && s.date <= date).reduce((a, s) => a + sessionVolume(s), 0)
  }, [d.sessions, date])

  // コンディションはシートを開かずにその場で1タップ保存できるようにする
  const quickCond = (patch: Partial<ConditionRecord>) => {
    actions.saveCondition({ id: cond?.id ?? uid(), date, memo: cond?.memo ?? '', sleep: cond?.sleep, fatigue: cond?.fatigue, condition: cond?.condition, ...patch })
    toast('保存しました')
  }

  const pb = (a: PhysicalAbility) => {
    const others = d.abilities.filter((x) => x.type === a.type && x.date < a.date)
    if (!others.length) return false
    const lower = isLowerBetter(a.type)
    const best = (lower ? Math.min : Math.max)(...others.map((x) => x.value))
    return lower ? a.value < best : a.value > best
  }

  const weightDelta = body?.weight != null && prevBody?.weight != null ? body.weight - prevBody.weight : undefined

  return (
    <div className="wrap">
      <div className="row" style={{ justifyContent: 'center', marginBottom: 12 }}>
        <DateNav value={date} onChange={setDate} />
      </div>
      <button className="btn block" style={{ marginBottom: 12, background: 'var(--card)', justifyContent: 'flex-start', gap: 10 }} onClick={() => props.onEdit({ kind: 'text' })}>
        <span style={{ fontSize: 18 }}>📝</span>
        <span className="grow" style={{ textAlign: 'left' }}>テキストで入力<span className="sub" style={{ display: 'block', fontWeight: 500 }}>「BSQ 60kg 5 3」のように書いて・貼り付けて取り込む</span></span>
        <span className="muted">›</span>
      </button>

      <div className="grid3" style={{ marginBottom: 12 }}>
        <div className="card stat" style={{ margin: 0 }}>
          <div className="l">体重</div>
          <div className="v">{num(body?.weight ?? prevBody?.weight)}<small>kg</small></div>
          {weightDelta != null ? (
            <div className={weightDelta <= 0 ? 'delta-up' : 'delta-down'}>{weightDelta > 0 ? '+' : ''}{weightDelta.toFixed(1)}</div>
          ) : (
            <div className="sub" style={{ fontSize: 11 }}>{body ? '' : prevBody ? '前回値' : ''}</div>
          )}
        </div>
        <div className="card stat" style={{ margin: 0 }}>
          <div className="l">直近7日</div>
          <div className="v">{weekCount}<small>日</small></div>
          <div className="sub" style={{ fontSize: 11 }}>トレーニング</div>
        </div>
        <div className="card stat" style={{ margin: 0 }}>
          <div className="l">7日の挙上量</div>
          <div className="v">{weekVolume >= 10000 ? (weekVolume / 1000).toFixed(1) : Math.round(weekVolume)}<small>{weekVolume >= 10000 ? 't' : 'kg'}</small></div>
          <div className="sub" style={{ fontSize: 11 }}>合計</div>
        </div>
      </div>

      {/* トレーニング */}
      <div className="card">
        <div className="card-h">
          <span className="ic" style={{ background: '#e6f3ff' }}>🏋️</span>
          <h2>トレーニング</h2>
          <button className="btn sm primary" onClick={() => props.onEdit({ kind: 'training', date })}>＋ 記録</button>
        </div>
        {daySessions.length === 0 ? (
          <div className="sub">この日の記録はまだありません</div>
        ) : (
          daySessions.map((s) => (
            <div key={s.id} className="list-item tap" onClick={() => props.onEdit({ kind: 'training', date, item: s })}>
              <div className="grow">
                <div className="row" style={{ marginBottom: 4 }}>
                  <b className="grow">{s.sport || 'トレーニング'}</b>
                  {sessionVolume(s) > 0 && <span className="sub">{Math.round(sessionVolume(s)).toLocaleString()}kg</span>}
                </div>
                {s.exercises.map((x) => (
                  <div key={x.id} style={{ fontSize: 14, lineHeight: 1.6 }}>
                    <span style={{ fontWeight: 600 }}>{x.name}</span>
                    <span className="sub" style={{ marginLeft: 8 }}>{setsSummary(x.sets)}</span>
                  </div>
                ))}
                {s.memo && <div className="sub" style={{ marginTop: 4 }}>{s.memo}</div>}
              </div>
            </div>
          ))
        )}
      </div>

      <div className="grid-auto">
        {/* コンディション */}
        <div className="card">
          <div className="card-h">
            <span className="ic" style={{ background: '#e9f9ee' }}>😊</span>
            <h2>コンディション</h2>
            <button className="btn sm" onClick={() => props.onEdit({ kind: 'condition', date, item: cond })}>詳細</button>
          </div>
          <div className="sub" style={{ marginBottom: 6, fontWeight: 700 }}>体調</div>
          <Scale value={cond?.condition} onChange={(v) => quickCond({ condition: v })} colors={CONDITION_COLORS} low="最高" high="不調" />
          <div className="row" style={{ marginTop: 12 }}>
            <div className="sub grow" style={{ fontWeight: 700 }}>睡眠</div>
            <div className="chips">
              {[6, 7, 8].map((h) => (
                <button key={h} className={'chip' + (cond?.sleep === h ? ' on' : '')} onClick={() => quickCond({ sleep: cond?.sleep === h ? undefined : h })}>{h}h</button>
              ))}
              {cond?.sleep != null && ![6, 7, 8].includes(cond.sleep) && <span className="chip on">{cond.sleep}h</span>}
            </div>
          </div>
          {cond?.fatigue != null && <div className="sub" style={{ marginTop: 8 }}>疲労度 {cond.fatigue}</div>}
        </div>

        {/* 身体測定 */}
        <div className="card">
          <div className="card-h">
            <span className="ic" style={{ background: '#fff3e0' }}>⚖️</span>
            <h2>身体測定</h2>
            <button className={'btn sm' + (body ? '' : ' primary')} onClick={() => props.onEdit({ kind: 'body', date, item: body })}>{body ? '編集' : '＋ 記録'}</button>
          </div>
          {body ? (
            <div className="grid3">
              <div className="stat"><div className="l">体重</div><div className="v" style={{ fontSize: 20 }}>{num(body.weight)}<small>kg</small></div></div>
              <div className="stat"><div className="l">体脂肪率</div><div className="v" style={{ fontSize: 20 }}>{num(body.bodyFat)}<small>%</small></div></div>
              <div className="stat"><div className="l">筋肉量</div><div className="v" style={{ fontSize: 20 }}>{num(body.muscle)}<small>kg</small></div></div>
            </div>
          ) : (
            <div className="sub">{prevBody ? `前回 ${prevBody.weight}kg（${prevBody.date.slice(5).replace('-', '/')}）` : 'まだ記録がありません'}</div>
          )}
        </div>
      </div>

      {/* 身体能力 */}
      <div className="card">
        <div className="card-h">
          <span className="ic" style={{ background: '#f1ebff' }}>⚡</span>
          <h2>身体能力</h2>
          <button className="btn sm" onClick={() => props.onEdit({ kind: 'ability', date })}>＋ 記録</button>
        </div>
        {dayAbilities.length === 0 ? (
          <div className="sub">垂直跳び・50m走・握力など</div>
        ) : (
          dayAbilities.map((a) => (
            <div key={a.id} className="list-item tap" onClick={() => props.onEdit({ kind: 'ability', date, item: a })}>
              <span style={{ fontSize: 18 }}>{abilityIcon(a.type)}</span>
              <span className="grow" style={{ fontWeight: 600 }}>{a.type}</span>
              {pb(a) && <span className="badge">PB</span>}
              <b>{a.unit === '秒' ? a.value.toFixed(2) : num(a.value)}{a.unit}</b>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
