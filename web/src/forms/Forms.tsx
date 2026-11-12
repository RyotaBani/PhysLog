import { useMemo, useState } from 'react'
import { actions, uid, useData } from '../store'
import type {
  BodyMeasurement, ConditionRecord, ExerciseLog, PhysicalAbility, TrainingSession,
} from '../types'
import { DateField, Scale, Sheet, Stepper, UnitInput, toast } from '../components/ui'
import {
  ABILITY_PRESETS, CONDITION_COLORS, EXERCISES, SPORTS, abilityIcon, findAbility, isLowerBetter, resolveAlias,
} from '../lib/presets'
import { exerciseVolume, fullDate, kg, labelDate, num, parseNum, sessionVolume, setsSummary } from '../lib/format'

const str = (v?: number) => (v == null ? '' : String(v))
const byDateDesc = <T extends { date: string }>(a: T, b: T) => b.date.localeCompare(a.date)

// ─────────────────────────────────────────────
// 身体測定
// ─────────────────────────────────────────────
export function BodyForm(props: { date: string; existing?: BodyMeasurement; onClose: () => void }) {
  const [date, setDate] = useState(props.date)
  const { bodies } = useData()
  const prev = useMemo(
    () => [...bodies].filter((b) => b.date < date || (b.date === date && b.id !== props.existing?.id)).sort(byDateDesc)[0],
    [bodies, date, props.existing],
  )
  const e = props.existing
  const [w, setW] = useState(str(e?.weight))
  const [f, setF] = useState(str(e?.bodyFat))
  const [m, setM] = useState(str(e?.muscle))
  const [memo, setMemo] = useState(e?.memo ?? '')
  const ok = [w, f, m].some((x) => parseNum(x) != null)
  const save = () => {
    actions.saveBody({ id: e?.id ?? uid(), date: date, weight: parseNum(w), bodyFat: parseNum(f), muscle: parseNum(m), memo })
    toast('身体測定を保存しました')
    props.onClose()
  }
  return (
    <Sheet
      title={`身体測定・${labelDate(date)}`}
      onClose={props.onClose}
      onSave={save}
      canSave={ok}
      onDelete={e ? () => { actions.remove('bodies', e.id); props.onClose() } : undefined}
    >
      <DateField value={date} onChange={setDate} />
      <label className="label">体重</label>
      <UnitInput value={w} onChange={setW} unit="kg" placeholder={prev?.weight ? `前回 ${prev.weight}` : '例 70.5'} autoFocus />
      <div className="grid2">
        <div>
          <label className="label">体脂肪率</label>
          <UnitInput value={f} onChange={setF} unit="%" placeholder={prev?.bodyFat ? `前回 ${prev.bodyFat}` : '任意'} />
        </div>
        <div>
          <label className="label">筋肉量</label>
          <UnitInput value={m} onChange={setM} unit="kg" placeholder={prev?.muscle ? `前回 ${prev.muscle}` : '任意'} />
        </div>
      </div>
      <label className="label">メモ</label>
      <textarea value={memo} onChange={(ev) => setMemo(ev.target.value)} placeholder="朝・起床後など" />
    </Sheet>
  )
}

// ─────────────────────────────────────────────
// コンディション
// ─────────────────────────────────────────────
export function ConditionForm(props: { date: string; existing?: ConditionRecord; onClose: () => void }) {
  const [date, setDate] = useState(props.date)
  const e = props.existing
  const [sleep, setSleep] = useState(str(e?.sleep))
  const [fatigue, setFatigue] = useState(e?.fatigue)
  const [cond, setCond] = useState(e?.condition)
  const [memo, setMemo] = useState(e?.memo ?? '')
  const ok = parseNum(sleep) != null || fatigue != null || cond != null || memo.trim() !== ''
  const save = () => {
    actions.saveCondition({ id: e?.id ?? uid(), date: date, sleep: parseNum(sleep), fatigue, condition: cond, memo })
    toast('コンディションを保存しました')
    props.onClose()
  }
  return (
    <Sheet
      title={`コンディション・${labelDate(date)}`}
      onClose={props.onClose}
      onSave={save}
      canSave={ok}
      onDelete={e ? () => { actions.remove('conditions', e.id); props.onClose() } : undefined}
    >
      <DateField value={date} onChange={setDate} />
      <label className="label">睡眠時間</label>
      <div className="chips" style={{ marginBottom: 8 }}>
        {[5, 6, 6.5, 7, 7.5, 8, 9].map((h) => (
          <button key={h} className={'chip' + (parseNum(sleep) === h ? ' on' : '')} onClick={() => setSleep(String(h))}>{h}h</button>
        ))}
      </div>
      <UnitInput value={sleep} onChange={setSleep} unit="時間" placeholder="例 7.5" />
      <label className="label">体調</label>
      <Scale value={cond} onChange={setCond} colors={CONDITION_COLORS} low="1 最高" high="5 不調" />
      <label className="label">疲労度</label>
      <Scale value={fatigue} onChange={setFatigue} colors={CONDITION_COLORS} low="1 ほぼなし" high="5 非常に高い" />
      <label className="label">メモ</label>
      <textarea value={memo} onChange={(ev) => setMemo(ev.target.value)} placeholder="痛み・気になること" />
    </Sheet>
  )
}

// ─────────────────────────────────────────────
// 身体能力
// ─────────────────────────────────────────────
export function AbilityForm(props: { date: string; existing?: PhysicalAbility; onClose: () => void }) {
  const [date, setDate] = useState(props.date)
  const { abilities } = useData()
  const e = props.existing
  const recent = useMemo(() => {
    const seen: string[] = []
    for (const a of [...abilities].sort(byDateDesc)) if (!seen.includes(a.type)) seen.push(a.type)
    return seen
  }, [abilities])
  const [type, setType] = useState(e?.type ?? recent[0] ?? '')
  const [custom, setCustom] = useState('')
  const [unit, setUnit] = useState(e?.unit ?? findAbility(type)?.unit ?? '')
  const [value, setValue] = useState(str(e?.value))
  const [memo, setMemo] = useState(e?.memo ?? '')

  const choose = (t: string) => {
    setType(t)
    setUnit(findAbility(t)?.unit ?? abilities.find((a) => a.type === t)?.unit ?? unit)
  }
  const history = abilities.filter((a) => a.type === type && a.id !== e?.id)
  const lower = isLowerBetter(type)
  const best = history.length ? (lower ? Math.min : Math.max)(...history.map((a) => a.value)) : undefined
  const last = [...history].sort(byDateDesc)[0]
  const v = parseNum(value)
  const isPB = v != null && best != null && (lower ? v < best : v > best)

  const others = ABILITY_PRESETS.map((p) => p.name).filter((n) => !recent.includes(n))
  const ok = type.trim() !== '' && v != null
  const save = () => {
    actions.saveAbility({ id: e?.id ?? uid(), date: date, type: type.trim(), value: v!, unit, memo })
    toast(isPB ? '🎉 自己ベスト更新！' : '身体能力を保存しました')
    props.onClose()
  }
  return (
    <Sheet
      title={`身体能力・${labelDate(date)}`}
      onClose={props.onClose}
      onSave={save}
      canSave={ok}
      onDelete={e ? () => { actions.remove('abilities', e.id); props.onClose() } : undefined}
    >
      <DateField value={date} onChange={setDate} />
      <label className="label">種目</label>
      <div className="chips">
        {[...recent, ...others].map((n) => (
          <button key={n} className={'chip' + (type === n ? ' on' : '')} onClick={() => choose(n)}>
            {abilityIcon(n)} {n}
          </button>
        ))}
      </div>
      <div className="row" style={{ marginTop: 8 }}>
        <input placeholder="その他の種目を入力" value={custom} onChange={(ev) => setCustom(ev.target.value)} />
        <button className="btn sm" disabled={!custom.trim()} onClick={() => { choose(custom.trim()); setCustom('') }}>使う</button>
      </div>
      {type && (
        <>
          <label className="label">{type} の記録</label>
          <div className="row">
            <div className="grow"><UnitInput value={value} onChange={setValue} unit={unit || '—'} placeholder={last ? `前回 ${last.value}` : ''} autoFocus /></div>
            {!findAbility(type) && (
              <input style={{ width: 80 }} value={unit} onChange={(ev) => setUnit(ev.target.value)} placeholder="単位" />
            )}
          </div>
          <div className="sub" style={{ marginTop: 6 }}>
            {best != null ? <>自己ベスト {best}{unit}{lower ? '（小さいほど良い）' : ''}</> : '初めての記録です'}
            {isPB && <span className="badge" style={{ marginLeft: 8 }}>PB更新</span>}
          </div>
        </>
      )}
      <label className="label">メモ</label>
      <textarea value={memo} onChange={(ev) => setMemo(ev.target.value)} placeholder="測定条件など" />
    </Sheet>
  )
}

// ─────────────────────────────────────────────
// トレーニング
// ─────────────────────────────────────────────
export function TrainingForm(props: { date: string; existing?: TrainingSession; onClose: () => void }) {
  const [date, setDate] = useState(props.date)
  const { sessions, profile } = useData()
  const e = props.existing
  const past = useMemo(
    () => [...sessions].filter((s) => s.id !== e?.id && s.date <= date).sort(byDateDesc),
    [sessions, e, date],
  )
  const [sport, setSport] = useState(e?.sport ?? past[0]?.sport ?? (profile.sport || 'ウェイトトレーニング'))
  const [memo, setMemo] = useState(e?.memo ?? '')
  const [exs, setExs] = useState<ExerciseLog[]>(() => e?.exercises.map((x) => ({ ...x, sets: x.sets.map((s) => ({ ...s })) })) ?? [])
  const [picking, setPicking] = useState(exs.length === 0 && past.length === 0)

  const lastOf = (name: string) => {
    for (const s of past) {
      const hit = s.exercises.find((x) => x.name === name)
      if (hit) return { date: s.date, ex: hit }
    }
    return undefined
  }

  const addExercise = (name: string) => {
    const last = lastOf(name)
    setExs((l) => [...l, {
      id: uid(), name,
      sets: last ? last.ex.sets.map((s) => ({ ...s })) : [{ weight: undefined, reps: 10 }],
    }])
    setPicking(false)
  }
  const copyLast = (s: TrainingSession) => {
    setExs(s.exercises.map((x) => ({ id: uid(), name: x.name, sets: x.sets.map((y) => ({ ...y })) })))
    if (s.sport) setSport(s.sport)
  }
  const update = (id: string, fn: (x: ExerciseLog) => ExerciseLog) => setExs((l) => l.map((x) => (x.id === id ? fn(x) : x)))
  const total = exs.reduce((a, x) => a + exerciseVolume(x), 0)
  const ok = exs.length > 0 || memo.trim() !== ''

  const save = () => {
    const cleaned = exs.map((x) => ({ ...x, sets: x.sets.filter((s) => s.weight != null || s.reps != null) }))
    actions.saveSession({ id: e?.id ?? uid(), date: date, sport, memo, exercises: cleaned })
    toast('トレーニングを保存しました')
    props.onClose()
  }

  // 前回と違うメニュー（同じ種目構成は1つにまとめる）を最大3件
  const templates = useMemo(() => {
    const out: TrainingSession[] = []
    const keys = new Set<string>()
    for (const s of past) {
      const k = s.exercises.map((x) => x.name).join('|')
      if (!k || keys.has(k)) continue
      keys.add(k)
      out.push(s)
      if (out.length >= 3) break
    }
    return out
  }, [past])

  return (
    <Sheet
      title={`トレーニング・${labelDate(date)}`}
      onClose={props.onClose}
      onSave={save}
      canSave={ok}
      saveLabel={total > 0 ? `保存（総挙上量 ${Math.round(total).toLocaleString()}kg）` : '保存'}
      onDelete={e ? () => { actions.remove('sessions', e.id); props.onClose() } : undefined}
    >
      <DateField value={date} onChange={setDate} />
      <div className="chips scroll" style={{ marginBottom: 12 }}>
        {SPORTS.map((s) => (
          <button key={s} className={'chip' + (sport === s ? ' on' : '')} onClick={() => setSport(s)}>{s}</button>
        ))}
      </div>

      {exs.length === 0 && templates.length > 0 && (
        <div className="card">
          <div className="sub" style={{ marginBottom: 8, fontWeight: 700 }}>過去のメニューから始める</div>
          {templates.map((s) => (
            <div key={s.id} className="list-item tap" onClick={() => copyLast(s)}>
              <div className="grow">
                <div style={{ fontWeight: 700, fontSize: 14 }}>{s.exercises.map((x) => x.name).join('・')}</div>
                <div className="sub">{fullDate(s.date)}・{Math.round(sessionVolume(s)).toLocaleString()}kg</div>
              </div>
              <span className="btn sm primary">コピー</span>
            </div>
          ))}
        </div>
      )}

      {exs.map((x) => {
        const last = lastOf(x.name)
        return (
          <div className="ex" key={x.id}>
            <div className="ex-h">
              <b>{x.name}</b>
              <span className="sub">{exerciseVolume(x) > 0 ? `${Math.round(exerciseVolume(x)).toLocaleString()}kg` : ''}</span>
              <button className="icon-btn" style={{ width: 30, height: 30, fontSize: 13 }} onClick={() => setExs((l) => l.filter((y) => y.id !== x.id))} aria-label="種目を削除">✕</button>
            </div>
            {last && <div className="sub" style={{ marginBottom: 8 }}>前回 {fullDate(last.date)}：{setsSummary(last.ex.sets)}</div>}
            <div className="set-head"><span>SET</span><span>重量</span><span>回数</span><span /></div>
            {x.sets.map((s, i) => (
              <div className="set-row" key={i}>
                <span className="n">{i + 1}</span>
                <Stepper value={s.weight} step={2.5} unit="kg" onChange={(v) => update(x.id, (y) => ({ ...y, sets: y.sets.map((z, j) => (j === i ? { ...z, weight: v } : z)) }))} />
                <Stepper value={s.reps} step={1} unit="回" onChange={(v) => update(x.id, (y) => ({ ...y, sets: y.sets.map((z, j) => (j === i ? { ...z, reps: v == null ? undefined : Math.round(v) } : z)) }))} />
                <button className="muted" onClick={() => update(x.id, (y) => ({ ...y, sets: y.sets.filter((_, j) => j !== i) }))} aria-label="セットを削除">✕</button>
              </div>
            ))}
            <button
              className="btn sm block"
              style={{ marginTop: 4 }}
              onClick={() => update(x.id, (y) => ({ ...y, sets: [...y.sets, { ...(y.sets[y.sets.length - 1] ?? { reps: 10 }) }] }))}
            >＋ セットを追加（同じ内容）</button>
          </div>
        )
      })}

      {picking ? (
        <ExercisePicker past={past} onPick={addExercise} onCancel={exs.length ? () => setPicking(false) : undefined} />
      ) : (
        <button className="btn block" style={{ border: '2px dashed var(--line)', background: 'none' }} onClick={() => setPicking(true)}>＋ 種目を追加</button>
      )}

      <label className="label">メモ</label>
      <textarea value={memo} onChange={(ev) => setMemo(ev.target.value)} placeholder="練習内容・感覚など" />
    </Sheet>
  )
}

function ExercisePicker(props: { past: TrainingSession[]; onPick: (name: string) => void; onCancel?: () => void }) {
  const [q, setQ] = useState('')
  const [cat, setCat] = useState('よく使う')
  const recent = useMemo(() => {
    const count = new Map<string, number>()
    for (const s of props.past.slice(0, 30)) for (const x of s.exercises) count.set(x.name, (count.get(x.name) ?? 0) + 1)
    return [...count.entries()].sort((a, b) => b[1] - a[1]).map(([n]) => n).slice(0, 12)
  }, [props.past])
  const cats = [...(recent.length ? ['よく使う'] : []), ...EXERCISES.map((c) => c.category)]
  const current = cat === 'よく使う' && recent.length ? recent : EXERCISES.find((c) => c.category === cat)?.items ?? EXERCISES[0].items
  const all = [...new Set([...recent, ...EXERCISES.flatMap((c) => c.items)])]
  const alias = resolveAlias(q)
  const list = q.trim()
    ? [...new Set([...(alias ? [alias] : []), ...all.filter((n) => n.toLowerCase().includes(q.trim().toLowerCase()))])]
    : current
  return (
    <div className="card">
      <div className="row" style={{ marginBottom: 10 }}>
        <input autoFocus placeholder="種目を検索 / 入力" value={q} onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter' && q.trim()) props.onPick(list[0] ?? q.trim()) }} />
        {props.onCancel && <button className="btn sm" onClick={props.onCancel}>閉じる</button>}
      </div>
      {!q.trim() && (
        <div className="chips scroll" style={{ marginBottom: 10 }}>
          {cats.map((c) => <button key={c} className={'chip' + ((cat === c || (!recent.length && c === '胸' && cat === 'よく使う')) ? ' on' : '')} onClick={() => setCat(c)}>{c}</button>)}
        </div>
      )}
      <div className="chips">
        {list.map((n) => <button key={n} className="chip" onClick={() => props.onPick(n)}>{n}</button>)}
        {q.trim() && !alias && !all.includes(q.trim()) && (
          <button className="chip on" onClick={() => props.onPick(q.trim())}>「{q.trim()}」を追加</button>
        )}
      </div>
    </div>
  )
}

export { kg, num }
