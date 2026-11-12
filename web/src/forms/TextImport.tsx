import { useMemo, useState } from 'react'
import { actions, uid, useRawData } from '../store'
import type { ExerciseLog } from '../types'
import { Sheet, toast } from '../components/ui'
import { EXERCISES } from '../lib/presets'
import { labelDate, todayKey } from '../lib/format'
import { parseQuickText, setsToText, textToSets, type ParsedBlock, type ParsedExercise } from '../lib/quickParse'

// 下書きはブラウザに残す。ジムでメモだけ書いて、取り込みは後からでもよいように
const DRAFT = 'physlog.textDraft'
const loadDraft = () => { try { return localStorage.getItem(DRAFT) ?? '' } catch { return '' } }
const saveDraft = (v: string) => { try { localStorage.setItem(DRAFT, v) } catch { /* 無視 */ } }

const EXAMPLE = `例）
11/12
Ryota,Katsura
BSQ 20kg 5rep 1set, 60kg 5rep 3set
OHSQ 20kg 5 3
2db
ランジ 10kg 5 3`

const MATCH_LABEL: Record<ParsedExercise['match'], { text: string; color: string } | null> = {
  exact: null,
  alias: { text: '略称から変換', color: 'var(--primary)' },
  fuzzy: { text: '推測・要確認', color: 'var(--orange)' },
  unknown: { text: '辞書にない名前', color: 'var(--orange)' },
  missing: { text: '種目名を入れてください', color: 'var(--pink)' },
}

interface EditExercise extends ParsedExercise { setsText: string }
interface EditBlock extends Omit<ParsedBlock, 'exercises'> { exercises: EditExercise[] }

export function TextImport(props: { onClose: () => void }) {
  const raw = useRawData()
  const [text, setText] = useState(loadDraft)
  const [blocks, setBlocks] = useState<EditBlock[] | null>(null)
  const [ignored, setIgnored] = useState<string[]>([])

  const known = useMemo(() => {
    const s = new Set<string>()
    raw.sessions.forEach((x) => x.exercises.forEach((e) => s.add(e.name)))
    return [...s]
  }, [raw.sessions])
  const allNames = useMemo(() => [...new Set([...known, ...EXERCISES.flatMap((c) => c.items)])], [known])
  const activeName = raw.members.find((m) => m.id === raw.activeMemberId)?.name ?? ''

  const read = () => {
    const r = parseQuickText(text, { memberNames: raw.members.map((m) => m.name), knownExercises: known, today: todayKey() })
    setBlocks(r.blocks.map((b) => ({
      ...b,
      members: b.members.length ? b.members : [activeName],
      exercises: b.exercises.map((e) => ({ ...e, setsText: e.sets.length ? setsToText(e.sets) : '' })),
    })))
    setIgnored(r.ignored)
  }

  const patchBlock = (key: string, fn: (b: EditBlock) => EditBlock) => setBlocks((l) => l && l.map((b) => (b.key === key ? fn(b) : b)))
  const patchEx = (bk: string, ek: string, p: Partial<EditExercise>) =>
    patchBlock(bk, (b) => ({ ...b, exercises: b.exercises.map((e) => (e.key === ek ? { ...e, ...p } : e)) }))

  const problems = blocks?.flatMap((b) => [
    ...(b.members.length ? [] : ['人が選ばれていない日があります']),
    ...b.exercises.filter((e) => !e.name.trim()).map(() => '種目名が空の行があります'),
  ]) ?? []
  const exerciseCount = blocks?.reduce((a, b) => a + b.exercises.length * b.members.length, 0) ?? 0

  const save = () => {
    if (!blocks) return
    const state = actions.getState()
    const idByName = new Map(state.members.map((m) => [m.name, m.id]))
    for (const b of blocks) for (const name of b.members) if (!idByName.has(name)) idByName.set(name, actions.addMember(name, false).id)
    let added = 0
    for (const b of blocks) {
      for (const name of b.members) {
        const memberId = idByName.get(name)!
        const logs: ExerciseLog[] = b.exercises.map((e) => ({ id: uid(), name: e.name.trim(), sets: textToSets(e.setsText) }))
        const cur = actions.getState()
        const existing = cur.sessions.find((s) => s.date === b.date && (s.memberId ?? 'me') === memberId)
        const notes = b.exercises.filter((e) => e.note).map((e) => `${e.name.trim()}：${e.note}`)
        if (existing) {
          // 同じ内容の種目が既にあれば重ねない（同じメモを2回取り込んでも増えない）
          const fresh = logs.filter((l) => !existing.exercises.some((x) => x.name === l.name && JSON.stringify(x.sets) === JSON.stringify(l.sets)))
          added += fresh.length
          const memo = [existing.memo, ...notes.filter((n) => !existing.memo.includes(n))].filter(Boolean).join('\n')
          actions.saveSession({ ...existing, memo, exercises: [...existing.exercises, ...fresh], start: existing.start ?? b.start, end: existing.end ?? b.end })
        } else {
          added += logs.length
          actions.saveSession({ id: uid(), memberId, date: b.date, sport: cur.profile.sport || 'ウェイトトレーニング', memo: notes.join('\n'), exercises: logs, start: b.start, end: b.end })
        }
      }
    }
    saveDraft('')
    toast(added ? `${added}件の種目を取り込みました` : '新しい記録はありませんでした（取り込み済み）')
    props.onClose()
  }

  if (!blocks) {
    return (
      <Sheet title="テキストで入力" onClose={props.onClose} onSave={read} saveLabel="読み取って確認する" canSave={text.trim() !== ''}>
        <p className="sub" style={{ marginTop: 0 }}>
          メモ帳やLINEに書いた記録をそのまま貼り付けられます。略称（BSQ・OHSQ・BP…）や打ち間違いも読み取り、保存の前に確認画面で直せます。
        </p>
        <textarea
          autoFocus
          value={text}
          placeholder={EXAMPLE}
          onChange={(e) => { setText(e.target.value); saveDraft(e.target.value) }}
          style={{ minHeight: 260, fontSize: 16, lineHeight: 1.6, fontFamily: 'inherit' }}
        />
        <div className="sub" style={{ marginTop: 8, lineHeight: 1.7 }}>
          ・日付の行（11/12）、人の行（Ryota,Katsura）は次の行から有効<br />
          ・「20kg 5rep 3set」「20kg×5×3」「20 5 3」どれでも可。カンマで重量違いを並べられます<br />
          ・「2db」の次の行はダンベル2個（重量は片手）<br />
          ・「19:30-20:45」の行でトレーニング時間も入ります<br />
          ・「30秒」「60s」でキープ時間<br />
          ・書きかけは自動で残ります
        </div>
      </Sheet>
    )
  }

  return (
    <Sheet
      title="取り込む内容の確認"
      onClose={props.onClose}
      onSave={save}
      canSave={problems.length === 0 && exerciseCount > 0}
      saveLabel={problems[0] ?? `この内容で保存（${exerciseCount}件）`}
    >
      <button className="btn sm" onClick={() => setBlocks(null)} style={{ marginBottom: 12 }}>‹ テキストに戻る</button>
      {blocks.length === 0 && <div className="card empty">トレーニングの行を読み取れませんでした。書き方の例を参考にしてください。</div>}
      {blocks.map((b) => {
        const extra = b.members.filter((n) => !raw.members.some((m) => m.name === n))
        return (
          <div className="card" key={b.key}>
            <div className="row" style={{ marginBottom: 10, flexWrap: 'wrap' }}>
              <input type="date" value={b.date} max={todayKey()} onChange={(e) => e.target.value && patchBlock(b.key, (x) => ({ ...x, date: e.target.value }))} style={{ width: 'auto', padding: '6px 10px', fontWeight: 700 }} />
              <span className="sub">{labelDate(b.date)}</span>
              <input type="time" value={b.start ?? ''} onChange={(e) => patchBlock(b.key, (x) => ({ ...x, start: e.target.value || undefined }))} style={{ width: 'auto', padding: '6px 8px' }} aria-label="開始" />
              <span className="muted">〜</span>
              <input type="time" value={b.end ?? ''} onChange={(e) => patchBlock(b.key, (x) => ({ ...x, end: e.target.value || undefined }))} style={{ width: 'auto', padding: '6px 8px' }} aria-label="終了" />
            </div>
            <div className="chips" style={{ marginBottom: 12 }}>
              {[...raw.members.map((m) => m.name), ...extra].map((n) => {
                const on = b.members.includes(n)
                return (
                  <button key={n} className={'chip' + (on ? ' on' : '')}
                    onClick={() => patchBlock(b.key, (x) => ({ ...x, members: on ? x.members.filter((y) => y !== n) : [...x.members, n] }))}>
                    👤 {n}{extra.includes(n) ? '（新規）' : ''}
                  </button>
                )
              })}
            </div>
            {b.exercises.map((e) => {
              const badge = e.name.trim() ? MATCH_LABEL[e.match] : MATCH_LABEL.missing
              return (
                <div key={e.key} className="ex" style={{ background: 'var(--fill2)', border: badge && badge.color !== 'var(--primary)' ? `1.5px solid ${badge.color}` : '1px solid var(--line)' }}>
                  <div className="row" style={{ marginBottom: 6 }}>
                    <input list="ex-names" value={e.name} placeholder="種目名" onChange={(ev) => patchEx(b.key, e.key, { name: ev.target.value, match: 'exact' })} style={{ fontWeight: 700 }} />
                    <button className="icon-btn" style={{ width: 32, height: 32, fontSize: 13, flexShrink: 0 }} aria-label="この行を外す"
                      onClick={() => patchBlock(b.key, (x) => ({ ...x, exercises: x.exercises.filter((y) => y.key !== e.key) }))}>✕</button>
                  </div>
                  <input value={e.setsText} placeholder="例 60kg 5回 3set, 70kg 3回" onChange={(ev) => patchEx(b.key, e.key, { setsText: ev.target.value })} />
                  <div className="sub" style={{ marginTop: 6, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    {badge && <span style={{ color: badge.color, fontWeight: 700 }}>{badge.text}</span>}
                    <span>元の行：{e.raw}</span>
                    {e.note && <span>・{e.note}</span>}
                  </div>
                </div>
              )
            })}
          </div>
        )
      })}
      {ignored.length > 0 && (
        <div className="card">
          <div className="sub" style={{ fontWeight: 700, marginBottom: 4 }}>読み取らなかった行</div>
          {ignored.map((l, i) => <div key={i} className="sub">・{l}</div>)}
        </div>
      )}
      <datalist id="ex-names">{allNames.map((n) => <option key={n} value={n} />)}</datalist>
    </Sheet>
  )
}
