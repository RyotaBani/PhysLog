import { useMemo, useRef, useState } from 'react'
import { fromKey, shortDate } from '../lib/format'

const W = 640
const PAD = { l: 44, r: 14, t: 14, b: 26 }

function niceTicks(min: number, max: number, count = 4) {
  if (min === max) { min -= 1; max += 1 }
  const raw = (max - min) / count
  const mag = Math.pow(10, Math.floor(Math.log10(raw)))
  const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? raw
  const lo = Math.floor(min / step) * step
  const hi = Math.ceil(max / step) * step
  const ticks: number[] = []
  for (let v = lo; v <= hi + step / 2; v += step) ticks.push(Math.round(v * 1000) / 1000)
  return { lo, hi, ticks }
}

const fmtTick = (v: number) => (Math.abs(v) >= 1000 ? `${Math.round(v / 100) / 10}k` : String(v))

export function LineChart(props: {
  data: { date: string; value: number }[]
  color: string
  unit: string
  height?: number
  digits?: number
}) {
  const H = props.height ?? 220
  const ref = useRef<SVGSVGElement>(null)
  const [sel, setSel] = useState<number | null>(null)
  const { pts, ticks, xLabels } = useMemo(() => {
    const d = props.data
    if (!d.length) return { pts: [], ticks: [], xLabels: [] }
    const t0 = fromKey(d[0].date).getTime()
    const t1 = fromKey(d[d.length - 1].date).getTime()
    const span = Math.max(t1 - t0, 1)
    const vs = d.map((p) => p.value)
    const { lo, hi, ticks } = niceTicks(Math.min(...vs), Math.max(...vs))
    const x = (k: string) => PAD.l + ((fromKey(k).getTime() - t0) / span) * (W - PAD.l - PAD.r) * (d.length > 1 ? 1 : 0) + (d.length > 1 ? 0 : (W - PAD.l - PAD.r) / 2)
    const y = (v: number) => PAD.t + (1 - (v - lo) / (hi - lo || 1)) * (H - PAD.t - PAD.b)
    const pts = d.map((p) => ({ ...p, x: x(p.date), y: y(p.value) }))
    const idx = d.length <= 4 ? d.map((_, i) => i) : [0, Math.floor((d.length - 1) / 3), Math.floor(((d.length - 1) * 2) / 3), d.length - 1]
    return { pts, ticks: ticks.map((v) => ({ v, y: y(v) })), xLabels: idx.map((i) => pts[i]) }
  }, [props.data, H])

  if (!pts.length) return <div className="empty">まだデータがありません</div>

  const path = pts.map((p, i) => `${i ? 'L' : 'M'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ')
  const area = `${path} L${pts[pts.length - 1].x},${H - PAD.b} L${pts[0].x},${H - PAD.b} Z`
  const gid = 'g' + props.color.replace('#', '')

  const pick = (clientX: number) => {
    const svg = ref.current
    if (!svg) return
    const rect = svg.getBoundingClientRect()
    const sx = ((clientX - rect.left) / rect.width) * W
    let best = 0
    pts.forEach((p, i) => { if (Math.abs(p.x - sx) < Math.abs(pts[best].x - sx)) best = i })
    setSel(best)
  }
  const s = sel != null ? pts[sel] : pts[pts.length - 1]

  return (
    <div>
      <div className="tip">
        <span style={{ color: props.color }}>{s.value.toFixed(props.digits ?? 1)}{props.unit}</span>
        <span className="sub" style={{ marginLeft: 8 }}>{shortDate(s.date)}{sel == null ? '（最新）' : ''}</span>
      </div>
      <svg
        ref={ref}
        className="chart"
        viewBox={`0 0 ${W} ${H}`}
        onPointerDown={(e) => pick(e.clientX)}
        onPointerMove={(e) => (e.buttons || e.pointerType === 'mouse') && pick(e.clientX)}
        onPointerLeave={() => setSel(null)}
      >
        <defs>
          <linearGradient id={gid} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor={props.color} stopOpacity="0.22" />
            <stop offset="1" stopColor={props.color} stopOpacity="0" />
          </linearGradient>
        </defs>
        {ticks.map((t) => (
          <g key={t.v}>
            <line className="grid" x1={PAD.l} x2={W - PAD.r} y1={t.y} y2={t.y} />
            <text x={PAD.l - 6} y={t.y + 4} textAnchor="end">{fmtTick(t.v)}</text>
          </g>
        ))}
        {xLabels.map((p, i) => (
          <text key={i} x={p.x} y={H - 8} textAnchor={i === 0 ? 'start' : i === xLabels.length - 1 ? 'end' : 'middle'}>
            {shortDate(p.date)}
          </text>
        ))}
        <path d={area} fill={`url(#${gid})`} />
        <path d={path} fill="none" stroke={props.color} strokeWidth="2.5" strokeLinejoin="round" strokeLinecap="round" />
        {pts.length <= 40 && pts.map((p, i) => <circle key={i} cx={p.x} cy={p.y} r="3" fill={props.color} />)}
        <line x1={s.x} x2={s.x} y1={PAD.t} y2={H - PAD.b} stroke={props.color} strokeOpacity="0.35" strokeDasharray="3 3" />
        <circle cx={s.x} cy={s.y} r="6" fill="var(--card)" stroke={props.color} strokeWidth="3" />
      </svg>
    </div>
  )
}

export function Scatter(props: { points: { x: number; y: number }[]; xLabel: string; yLabel: string; color: string }) {
  const H = 240
  const ps = props.points
  if (!ps.length) return <div className="empty">同じ日のデータがまだありません</div>
  const xs = niceTicks(Math.min(...ps.map((p) => p.x)), Math.max(...ps.map((p) => p.x)))
  const ys = niceTicks(Math.min(...ps.map((p) => p.y)), Math.max(...ps.map((p) => p.y)))
  const X = (v: number) => PAD.l + ((v - xs.lo) / (xs.hi - xs.lo || 1)) * (W - PAD.l - PAD.r)
  const Y = (v: number) => PAD.t + (1 - (v - ys.lo) / (ys.hi - ys.lo || 1)) * (H - PAD.t - PAD.b - 10)
  return (
    <svg className="chart" viewBox={`0 0 ${W} ${H}`}>
      {ys.ticks.map((t) => (
        <g key={'y' + t}>
          <line className="grid" x1={PAD.l} x2={W - PAD.r} y1={Y(t)} y2={Y(t)} />
          <text x={PAD.l - 6} y={Y(t) + 4} textAnchor="end">{fmtTick(t)}</text>
        </g>
      ))}
      {xs.ticks.map((t) => (
        <text key={'x' + t} x={X(t)} y={H - 18} textAnchor="middle">{fmtTick(t)}</text>
      ))}
      <text x={W - PAD.r} y={H - 3} textAnchor="end">{props.xLabel} →</text>
      <text x={PAD.l} y={10}>↑ {props.yLabel}</text>
      {ps.map((p, i) => (
        <circle key={i} cx={X(p.x)} cy={Y(p.y)} r="6" fill={props.color} fillOpacity="0.55" stroke={props.color} />
      ))}
    </svg>
  )
}
