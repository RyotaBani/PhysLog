// iOS 版 CorrelationEngine.swift の移植。
// 断定を避け「〜傾向がありました」で統一する方針もそのまま。

import type { ConditionRecord, PhysicalAbility, TrainingSession } from '../types'
import { sessionVolume } from './format'

export type ConditionVar = 'sleep' | 'fatigue' | 'condition'
export const CONDITION_VARS: { id: ConditionVar; label: string; unit: string; higherIsBetter: boolean }[] = [
  { id: 'sleep', label: '睡眠時間', unit: '時間', higherIsBetter: true },
  { id: 'fatigue', label: '疲労度', unit: '', higherIsBetter: false },
  { id: 'condition', label: '体調', unit: '', higherIsBetter: false },
]

export const MIN_SAMPLE = 8
export const VOLUME_ID = '__volume__'

export interface Point {
  date: string
  x: number
  y: number
}

export interface Result {
  cv: (typeof CONDITION_VARS)[number]
  perfLabel: string
  points: Point[]
  r: number
}

export function pearson(xs: number[], ys: number[]) {
  if (xs.length !== ys.length || xs.length < 2) return 0
  const n = xs.length
  const mx = xs.reduce((a, b) => a + b, 0) / n
  const my = ys.reduce((a, b) => a + b, 0) / n
  let num = 0, sx = 0, sy = 0
  for (let i = 0; i < n; i++) {
    const dx = xs[i] - mx, dy = ys[i] - my
    num += dx * dy
    sx += dx * dx
    sy += dy * dy
  }
  const den = Math.sqrt(sx * sy)
  return den > 0 ? num / den : 0
}

export function analyze(
  cvId: ConditionVar,
  perfId: string,
  conditions: ConditionRecord[],
  sessions: TrainingSession[],
  abilities: PhysicalAbility[],
): Result {
  const cv = CONDITION_VARS.find((c) => c.id === cvId)!
  const byDay = new Map<string, number>()
  if (perfId === VOLUME_ID) {
    for (const s of sessions) {
      const v = sessionVolume(s)
      if (v > 0) byDay.set(s.date, (byDay.get(s.date) ?? 0) + v)
    }
  } else {
    for (const a of abilities) if (a.type === perfId) byDay.set(a.date, a.value)
  }
  const points: Point[] = []
  for (const c of conditions) {
    const x = c[cvId]
    const y = byDay.get(c.date)
    if (x == null || y == null) continue
    points.push({ date: c.date, x, y })
  }
  points.sort((a, b) => a.date.localeCompare(b.date))
  return {
    cv,
    perfLabel: perfId === VOLUME_ID ? '総挙上量' : perfId,
    points,
    r: pearson(points.map((p) => p.x), points.map((p) => p.y)),
  }
}

export const strengthLabel = (r: number) => {
  const a = Math.abs(r)
  if (a >= 0.7) return '強い関係'
  if (a >= 0.4) return '中程度の関係'
  if (a >= 0.2) return '弱い関係'
  return 'ほぼ関係なし'
}

export function summary(res: Result) {
  const n = res.points.length
  if (n < MIN_SAMPLE) {
    return `データが${n}件しかないため、まだ傾向を読み取れません。同じ日に「コンディション」と「${res.perfLabel}」の両方を記録した日が${MIN_SAMPLE}日分たまると分析できます。`
  }
  if (Math.abs(res.r) < 0.2) {
    return `この期間では、${res.cv.label}と${res.perfLabel}の間にはっきりした関係は見られませんでした。`
  }
  const favorable = res.cv.higherIsBetter ? res.r > 0 : res.r < 0
  const pos = res.r > 0
  const phrase =
    res.cv.id === 'sleep'
      ? pos ? '睡眠時間が長い日' : '睡眠時間が短い日'
      : res.cv.id === 'fatigue'
        ? pos ? '疲労を強く感じた日' : '疲労が少なかった日'
        : pos ? '体調が優れなかった日' : '体調が良かった日'
  return `${phrase}ほど、${res.perfLabel}が${favorable ? '高い' : '低い'}傾向がありました（${strengthLabel(res.r)}・${n}日分のデータ）。`
}

const median = (s: number[]) => {
  if (!s.length) return 0
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

/** 中央値で2群に分けた平均の比較文。信頼できない場合は null */
export function comparison(res: Result): string | null {
  if (res.points.length < MIN_SAMPLE) return null
  const th = median(res.points.map((p) => p.x).sort((a, b) => a - b))
  const hi = res.points.filter((p) => p.x >= th)
  const lo = res.points.filter((p) => p.x < th)
  if (hi.length < 3 || lo.length < 3) return null
  const mh = hi.reduce((a, p) => a + p.y, 0) / hi.length
  const ml = lo.reduce((a, p) => a + p.y, 0) / lo.length
  if (ml === 0) return null
  const pct = ((mh - ml) / ml) * 100
  if (Math.abs(pct) < 5) return null
  const label = res.cv.id === 'sleep' ? `${th.toFixed(1)}時間` : th.toFixed(0)
  const subject =
    res.cv.id === 'sleep' ? `睡眠が${label}以上の日` : res.cv.id === 'fatigue' ? `疲労度が${label}以上の日` : `体調スコアが${label}以上の日`
  const u = res.perfLabel === '総挙上量' ? 'kg' : ''
  return `${subject}の平均は ${mh.toFixed(1)}${u}、それ未満の日は ${ml.toFixed(1)}${u} でした（差は約${Math.abs(pct).toFixed(0)}%${pct > 0 ? '高い' : '低い'}）。`
}
