import { useEffect, useMemo, useRef, useState } from 'react'
import { actions, uid, useData } from '../store'
import type { BodyPhoto, PhotoPose } from '../types'
import { ConfirmButton, Seg, Sheet, toast } from '../components/ui'
import { deleteImage, fileDate, getImage, putImage, shrink } from '../lib/photos'
import { estimateAll, kindLabel, type Estimated } from '../lib/estimate'
import { labelDate, todayKey } from '../lib/format'

const POSES: { id: PhotoPose; label: string }[] = [
  { id: 'front', label: '正面' },
  { id: 'side', label: '横' },
  { id: 'back', label: '背面' },
]

function useImageUrl(id: string) {
  const [url, setUrl] = useState<string>()
  useEffect(() => {
    let u: string | undefined
    let alive = true
    getImage(id).then((b) => { if (b && alive) { u = URL.createObjectURL(b); setUrl(u) } }).catch(() => {})
    return () => { alive = false; if (u) URL.revokeObjectURL(u) }
  }, [id])
  return url
}

function Thumb(props: { photo: BodyPhoto; onClick?: () => void; big?: boolean }) {
  const url = useImageUrl(props.photo.id)
  return (
    <button onClick={props.onClick} className="thumb" style={props.big ? { width: '100%', aspectRatio: '3 / 4' } : undefined}>
      {url ? <img src={url} alt={`${props.photo.date} ${props.photo.pose}`} /> : <span className="sub">…</span>}
      <span className="thumb-tag">{POSES.find((p) => p.id === props.photo.pose)?.label}</span>
    </button>
  )
}

function CompLine(props: { label: string; e?: Estimated; unit: string }) {
  if (!props.e) return <span className="comp"><span className="sub">{props.label}</span> —</span>
  const est = props.e.kind !== 'measured'
  return (
    <span className="comp" title={`${kindLabel[props.e.kind]}${props.e.basis.length ? `：${props.e.basis.join('・')}` : ''}`}>
      <span className="sub">{props.label}</span> <b style={est ? { color: 'var(--sub)' } : undefined}>{est && '≈'}{props.e.value.toFixed(1)}</b>
      <span className="sub">{props.unit}</span>{est && <span className="est">推定</span>}
    </span>
  )
}

function Composition(props: { date: string }) {
  const { bodies } = useData()
  const c = estimateAll(bodies, props.date)
  return (
    <div className="row" style={{ flexWrap: 'wrap', gap: 12 }}>
      <CompLine label="体重" e={c.weight} unit="kg" />
      <CompLine label="体脂肪率" e={c.bodyFat} unit="%" />
      <CompLine label="筋肉量" e={c.muscle} unit="kg" />
    </div>
  )
}

export function Photos() {
  const d = useData()
  const input = useRef<HTMLInputElement>(null)
  const [pending, setPending] = useState<File[] | null>(null)
  const [viewing, setViewing] = useState<BodyPhoto | null>(null)
  const [compare, setCompare] = useState<string[]>([])
  const [comparing, setComparing] = useState(false)

  const byDate = useMemo(() => {
    const m = new Map<string, BodyPhoto[]>()
    for (const p of [...d.photos].sort((a, b) => b.date.localeCompare(a.date))) {
      if (!m.has(p.date)) m.set(p.date, [])
      m.get(p.date)!.push(p)
    }
    return [...m.entries()]
  }, [d.photos])

  const toggleCompare = (date: string) =>
    setCompare((l) => (l.includes(date) ? l.filter((x) => x !== date) : [...l, date].slice(-2)))

  return (
    <div className="wrap">
      <div className="row" style={{ marginBottom: 12 }}>
        <button className="btn primary grow" onClick={() => input.current?.click()}>📷 写真を追加</button>
        {byDate.length >= 2 && (
          <button className={'btn' + (comparing ? ' primary' : '')} onClick={() => { setComparing((v) => !v); setCompare([]) }}>
            {comparing ? '比較をやめる' : '⇆ 比べる'}
          </button>
        )}
      </div>
      <input ref={input} type="file" accept="image/*" multiple hidden
        onChange={(e) => { const f = [...(e.target.files ?? [])]; if (f.length) setPending(f); e.target.value = '' }} />

      {comparing && (
        <div className="card">
          <div className="sub" style={{ fontWeight: 700 }}>比べる日を2つ選んでください（{compare.length}/2）</div>
          {compare.length === 2 && <CompareView dates={[...compare].sort()} photos={d.photos} />}
        </div>
      )}

      {byDate.length === 0 && (
        <div className="card">
          <div className="empty" style={{ paddingBottom: 8 }}>まだ写真がありません</div>
          <Guide />
        </div>
      )}

      {byDate.map(([date, list]) => (
        <div className="card" key={date} style={comparing && compare.includes(date) ? { outline: '2px solid var(--primary)' } : undefined}
          onClick={comparing ? () => toggleCompare(date) : undefined}>
          <div className="row" style={{ marginBottom: 8 }}>
            <b className="grow">{labelDate(date)}</b>
            {comparing && <span className={'chip' + (compare.includes(date) ? ' on' : '')}>{compare.includes(date) ? '選択中' : '選ぶ'}</span>}
          </div>
          <Composition date={date} />
          <div className="thumbs" style={{ marginTop: 10 }}>
            {list.sort((a, b) => POSES.findIndex((p) => p.id === a.pose) - POSES.findIndex((p) => p.id === b.pose)).map((p) => (
              <Thumb key={p.id} photo={p} onClick={comparing ? undefined : () => setViewing(p)} />
            ))}
          </div>
        </div>
      ))}

      {byDate.length > 0 && (
        <details className="card"><summary style={{ fontWeight: 700, cursor: 'pointer' }}>撮り方のコツ</summary><div style={{ marginTop: 10 }}><Guide /></div></details>
      )}
      <p className="sub">写真はこの端末の中だけに保存されます（外部には送りません）。「推定」は前後の測定値から計算した参考値です。バックアップ（JSON）には写真は含まれません。</p>

      {pending && <AddSheet files={pending} onClose={() => setPending(null)} />}
      {viewing && <Viewer photo={viewing} onClose={() => setViewing(null)} />}
    </div>
  )
}

function Guide() {
  return (
    <ul className="sub" style={{ margin: 0, paddingLeft: 18, lineHeight: 1.8 }}>
      <li>同じ場所・同じ明るさ・同じ時間帯（例：朝の起床後、トイレの後）で撮る</li>
      <li>正面・横・背面の3枚。カメラは胸〜へその高さ、全身が入る距離で固定</li>
      <li>力を抜いた自然な立ち方と、決めたポーズの両方があると変化が分かりやすい</li>
      <li>撮った日に体重・体脂肪も測ると、その写真に実測値がつきます</li>
    </ul>
  )
}

function AddSheet(props: { files: File[]; onClose: () => void }) {
  const [date, setDate] = useState(() => {
    const k = fileDate(props.files[0])
    return k > todayKey() ? todayKey() : k
  })
  const [poses, setPoses] = useState<PhotoPose[]>(() => props.files.map((_, i) => POSES[i % 3].id))
  const [memo, setMemo] = useState('')
  const [busy, setBusy] = useState(false)
  const previews = useMemo(() => props.files.map((f) => URL.createObjectURL(f)), [props.files])
  useEffect(() => () => previews.forEach((u) => URL.revokeObjectURL(u)), [previews])

  const save = async () => {
    setBusy(true)
    try {
      for (let i = 0; i < props.files.length; i++) {
        const id = uid()
        await putImage(id, await shrink(props.files[i]))
        actions.savePhoto({ id, date, pose: poses[i], memo })
      }
      toast(`写真を${props.files.length}枚保存しました`)
      props.onClose()
    } catch {
      toast('保存できませんでした（この環境では写真を保存できない可能性があります）')
      setBusy(false)
    }
  }
  return (
    <Sheet title="写真を保存" onClose={props.onClose} onSave={save} canSave={!busy} saveLabel={busy ? '保存中…' : `${props.files.length}枚を保存`}>
      <div className="row" style={{ marginBottom: 12 }}>
        <span className="sub" style={{ fontWeight: 700 }}>撮影日</span>
        <input type="date" value={date} max={todayKey()} onChange={(e) => e.target.value && setDate(e.target.value)} style={{ width: 'auto', padding: '6px 10px' }} />
      </div>
      <div className="card" style={{ padding: 12 }}>
        <div className="sub" style={{ fontWeight: 700, marginBottom: 6 }}>この日の体組成</div>
        <Composition date={date} />
      </div>
      {props.files.map((f, i) => (
        <div key={i} className="row" style={{ marginBottom: 10, alignItems: 'center' }}>
          <img src={previews[i]} alt={f.name} style={{ width: 72, height: 96, objectFit: 'cover', borderRadius: 10, flexShrink: 0 }} />
          <div className="grow"><Seg value={poses[i]} onChange={(v) => setPoses((l) => l.map((x, j) => (j === i ? v : x)))} options={POSES} /></div>
        </div>
      ))}
      <label className="label">メモ</label>
      <textarea value={memo} onChange={(e) => setMemo(e.target.value)} placeholder="朝・起床後、減量3週目 など" />
    </Sheet>
  )
}

function Viewer(props: { photo: BodyPhoto; onClose: () => void }) {
  const url = useImageUrl(props.photo.id)
  const [date, setDate] = useState(props.photo.date)
  const [pose, setPose] = useState(props.photo.pose)
  const [memo, setMemo] = useState(props.photo.memo)
  return (
    <Sheet title={labelDate(date)} onClose={props.onClose}
      onSave={() => { actions.savePhoto({ ...props.photo, date, pose, memo }); toast('保存しました'); props.onClose() }}>
      {url && <img src={url} alt="" style={{ width: '100%', borderRadius: 14, display: 'block', marginBottom: 12 }} />}
      <div className="card" style={{ padding: 12 }}><Composition date={date} /></div>
      <div className="row" style={{ marginBottom: 10 }}>
        <input type="date" value={date} max={todayKey()} onChange={(e) => e.target.value && setDate(e.target.value)} style={{ width: 'auto', padding: '6px 10px' }} />
        <div className="grow"><Seg value={pose} onChange={setPose} options={POSES} /></div>
      </div>
      <textarea value={memo} onChange={(e) => setMemo(e.target.value)} placeholder="メモ" />
      <ConfirmButton className="btn danger block" style={{ marginTop: 12 }} label="この写真を削除" confirmLabel="もう一度押すと削除"
        onConfirm={() => { deleteImage(props.photo.id).catch(() => {}); actions.remove('photos', props.photo.id); props.onClose() }} />
    </Sheet>
  )
}

function CompareView(props: { dates: string[]; photos: BodyPhoto[] }) {
  const { bodies } = useData()
  const [pose, setPose] = useState<PhotoPose>('front')
  const [a, b] = props.dates
  const pa = props.photos.find((p) => p.date === a && p.pose === pose)
  const pb = props.photos.find((p) => p.date === b && p.pose === pose)
  const ca = estimateAll(bodies, a), cb = estimateAll(bodies, b)
  const diff = (x?: Estimated, y?: Estimated, unit = '') =>
    x && y ? `${y.value - x.value > 0 ? '+' : ''}${(y.value - x.value).toFixed(1)}${unit}${x.kind !== 'measured' || y.kind !== 'measured' ? '（推定含む）' : ''}` : '—'
  return (
    <div style={{ marginTop: 10 }} onClick={(e) => e.stopPropagation()}>
      <Seg value={pose} onChange={setPose} options={POSES} />
      <div className="grid2" style={{ marginTop: 10 }}>
        {[{ d: a, p: pa }, { d: b, p: pb }].map(({ d, p }) => (
          <div key={d}>
            <div className="sub" style={{ fontWeight: 700, marginBottom: 4 }}>{labelDate(d)}</div>
            {p ? <Thumb photo={p} big /> : <div className="thumb" style={{ width: '100%', aspectRatio: '3 / 4' }}><span className="sub">この向きの写真なし</span></div>}
          </div>
        ))}
      </div>
      <div className="list-item"><span className="grow sub">体重</span><b>{diff(ca.weight, cb.weight, 'kg')}</b></div>
      <div className="list-item"><span className="grow sub">体脂肪率</span><b>{diff(ca.bodyFat, cb.bodyFat, '%')}</b></div>
      <div className="list-item"><span className="grow sub">筋肉量</span><b>{diff(ca.muscle, cb.muscle, 'kg')}</b></div>
    </div>
  )
}
