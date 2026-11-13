// 測っていない日の体組成を、前後の実測から推定する（段階1：写真は使わない）。
//
// 項目ごとに独立して判断する：
//   measured     その日に実測あり
//   interpolated 前後の実測を日数で按分（両側とも MAX_GAP 日以内）
//   carried      片側しかないときは直近の実測をそのまま（CARRY_DAYS 日以内）
// 遠すぎる場合は出さない。推定は必ず「推定」と分かる形で表示する。

import type { BodyMeasurement } from '../types'
import { fromKey } from './format'

export type Field = 'weight' | 'bodyFat' | 'muscle'
export type Kind = 'measured' | 'interpolated' | 'carried'

export interface Estimated {
  value: number
  kind: Kind
  /** 推定の根拠にした実測日 */
  basis: string[]
}

const MAX_GAP = 60
const CARRY_DAYS = 21
const days = (a: string, b: string) => Math.round((fromKey(b).getTime() - fromKey(a).getTime()) / 86400000)

export function estimateField(bodies: BodyMeasurement[], date: string, field: Field): Estimated | undefined {
  const pts = bodies
    .filter((b) => b[field] != null)
    .map((b) => ({ date: b.date, v: b[field] as number }))
    .sort((a, b) => a.date.localeCompare(b.date))
  const same = pts.filter((p) => p.date === date).at(-1)
  if (same) return { value: same.v, kind: 'measured', basis: [date] }
  const prev = [...pts].reverse().find((p) => p.date < date)
  const next = pts.find((p) => p.date > date)
  if (prev && next && days(prev.date, date) <= MAX_GAP && days(date, next.date) <= MAX_GAP) {
    const t = days(prev.date, date) / days(prev.date, next.date)
    return { value: prev.v + (next.v - prev.v) * t, kind: 'interpolated', basis: [prev.date, next.date] }
  }
  const near = [prev, next]
    .filter((p): p is { date: string; v: number } => !!p)
    .sort((a, b) => Math.abs(days(a.date, date)) - Math.abs(days(b.date, date)))[0]
  if (near && Math.abs(days(near.date, date)) <= CARRY_DAYS) return { value: near.v, kind: 'carried', basis: [near.date] }
  return undefined
}

export function estimateAll(bodies: BodyMeasurement[], date: string) {
  return {
    weight: estimateField(bodies, date, 'weight'),
    bodyFat: estimateField(bodies, date, 'bodyFat'),
    muscle: estimateField(bodies, date, 'muscle'),
  }
}

export const kindLabel: Record<Kind, string> = {
  measured: '実測',
  interpolated: '推定（前後の測定から）',
  carried: '推定（直近の測定値）',
}
