import { useRef, useState } from 'react'
import { actions, useData, useRawData } from '../store'
import type { AppData } from '../types'
import { ConfirmButton, toast } from '../components/ui'
import { makeSample } from '../lib/sample'
import { SPORTS } from '../lib/presets'
import { sessionVolume, todayKey } from '../lib/format'

function download(name: string, text: string, type: string) {
  const blob = new Blob([text], { type })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = name
  a.click()
  setTimeout(() => URL.revokeObjectURL(a.href), 1000)
}

const esc = (v: unknown) => {
  const s = v == null ? '' : String(v)
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}

/** iOS 版と同じく BOM 付き UTF-8 の CSV（Excel で文字化けしない） */
function toCSV(d: AppData, memberName: string) {
  const lines = [['人', 'カテゴリ', '日付', '項目', '値', '単位', '詳細', 'メモ'].join(',')]
  const push = (...c: unknown[]) => lines.push([memberName, ...c].map(esc).join(','))
  for (const b of d.bodies) {
    if (b.weight != null) push('身体測定', b.date, '体重', b.weight, 'kg', '', b.memo)
    if (b.bodyFat != null) push('身体測定', b.date, '体脂肪率', b.bodyFat, '%', '', b.memo)
    if (b.muscle != null) push('身体測定', b.date, '筋肉量', b.muscle, 'kg', '', b.memo)
  }
  for (const a of d.abilities) push('身体能力', a.date, a.type, a.value, a.unit, '', a.memo)
  for (const s of d.sessions)
    for (const x of s.exercises)
      x.sets.forEach((y, i) => push('トレーニング', s.date, x.name, y.weight ?? '', 'kg', `${i + 1}セット目 ${y.reps ?? ''}回`, s.memo))
  for (const s of d.sessions) push('トレーニング', s.date, '総挙上量', sessionVolume(s), 'kg', s.sport, '')
  for (const c of d.conditions) {
    if (c.sleep != null) push('コンディション', c.date, '睡眠時間', c.sleep, '時間', '', c.memo)
    if (c.fatigue != null) push('コンディション', c.date, '疲労度', c.fatigue, '1-5', '', c.memo)
    if (c.condition != null) push('コンディション', c.date, '体調', c.condition, '1-5', '', c.memo)
  }
  return '﻿' + lines.join('\r\n')
}

export function Settings() {
  const raw = useRawData()
  const view = useData()
  const file = useRef<HTMLInputElement>(null)
  const [newName, setNewName] = useState('')
  const [paste, setPaste] = useState('')
  const active = raw.members.find((m) => m.id === raw.activeMemberId)!
  const count = (id: string) =>
    [raw.bodies, raw.abilities, raw.sessions, raw.conditions].reduce((a, l) => a + l.filter((x) => (x.memberId ?? 'me') === id).length, 0)

  const onImport = async (f: File) => {
    try {
      const data = JSON.parse(await f.text()) as Partial<AppData>
      if (!data || typeof data !== 'object') throw new Error()
      actions.merge(data)
      toast('取り込みました（既存の記録はそのまま）')
    } catch {
      toast('ファイルを読み込めませんでした')
    }
  }

  return (
    <div className="wrap">
      <div className="card">
        <div className="card-h"><h2>記録する人</h2></div>
        {raw.members.map((m) => (
          <div key={m.id} className="list-item">
            <input
              value={m.name}
              onChange={(e) => actions.renameMember(m.id, e.target.value)}
              style={{ fontWeight: 700, background: 'none', border: 'none', padding: 0 }}
            />
            <span className="sub" style={{ whiteSpace: 'nowrap' }}>{count(m.id)}件</span>
            {m.id === raw.activeMemberId ? (
              <span className="chip on">選択中</span>
            ) : (
              <button className="chip" onClick={() => actions.setActiveMember(m.id)}>切替</button>
            )}
            {raw.members.length > 1 && (
              <ConfirmButton className="chip" label="✕" confirmLabel={`記録${count(m.id)}件ごと削除`} onConfirm={() => actions.deleteMember(m.id)} />
            )}
          </div>
        ))}
        <div className="row" style={{ marginTop: 10 }}>
          <input placeholder="名前を追加（例：選手名）" value={newName} onChange={(e) => setNewName(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter' && newName.trim()) { actions.addMember(newName.trim()); setNewName('') } }} />
          <button className="btn sm primary" disabled={!newName.trim()} onClick={() => { actions.addMember(newName.trim()); setNewName('') }}>追加</button>
        </div>
      </div>

      <div className="card">
        <div className="card-h"><h2>プロフィール</h2></div>
        <label className="label">普段の競技（トレーニング記録の初期値）</label>
        <select value={raw.profile.sport} onChange={(e) => actions.setProfile({ ...raw.profile, sport: e.target.value })}>
          <option value="">未設定</option>
          {SPORTS.map((s) => <option key={s}>{s}</option>)}
        </select>
      </div>

      <div className="card">
        <div className="card-h"><h2>データ</h2></div>
        <div className="sub" style={{ marginBottom: 10 }}>記録はこのブラウザの中だけに保存されます（外部には送信しません）。機種変更やバックアップには「書き出し」を使ってください。</div>
        <div className="grid2">
          <button className="btn" onClick={() => download(`physlog-${todayKey()}.json`, JSON.stringify(raw, null, 2), 'application/json')}>バックアップ（全員）</button>
          <button className="btn" onClick={() => download(`physlog-${active.name}-${todayKey()}.csv`, toCSV(view, active.name), 'text/csv')}>CSV（{active.name}）</button>
          <button className="btn" onClick={() => file.current?.click()}>ファイルから取り込む</button>
          <button className="btn" onClick={() => {
            const sm = makeSample()
            const tag = <T extends object>(l: T[]) => l.map((x) => ({ ...x, memberId: active.id }))
            actions.merge({ bodies: tag(sm.bodies), abilities: tag(sm.abilities), sessions: tag(sm.sessions), conditions: tag(sm.conditions), members: [] })
            toast('デモデータを追加しました')
          }}>デモデータを追加</button>
        </div>
        <input ref={file} type="file" accept="application/json,.json" hidden onChange={(e) => { const f = e.target.files?.[0]; if (f) onImport(f); e.target.value = '' }} />
        <ConfirmButton className="btn danger block" style={{ marginTop: 12 }} label={`${active.name} の記録をすべて削除`}
          confirmLabel={`もう一度押すと ${count(active.id)}件を削除（元に戻せません）`} onConfirm={() => actions.clearActive()} />
        <details style={{ marginTop: 12 }}>
          <summary className="sub" style={{ cursor: 'pointer' }}>ダウンロードできないとき（テキストでコピー・貼り付け）</summary>
          <div className="row" style={{ marginTop: 8 }}>
            <button className="btn sm" onClick={() => navigator.clipboard.writeText(JSON.stringify(raw)).then(() => toast('コピーしました'), () => toast('コピーできませんでした'))}>バックアップをコピー</button>
          </div>
          <textarea placeholder="バックアップのテキストを貼り付け" value={paste} onChange={(e) => setPaste(e.target.value)} style={{ marginTop: 8 }} />
          <button className="btn sm" disabled={!paste.trim()} onClick={() => {
            try { actions.merge(JSON.parse(paste)); setPaste(''); toast('取り込みました') } catch { toast('読み込めませんでした') }
          }}>貼り付けた内容を取り込む</button>
        </details>
      </div>
      <p className="sub" style={{ textAlign: 'center' }}>PhysLog Web 0.1</p>
    </div>
  )
}
