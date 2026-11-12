import type { ExerciseLog, SetEntry, TrainingSession } from '../types'

const pad = (n: number) => String(n).padStart(2, '0')

export const toKey = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`

export const todayKey = () => toKey(new Date())

export const fromKey = (k: string) => {
  const [y, m, d] = k.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export const addDays = (k: string, n: number) => {
  const d = fromKey(k)
  d.setDate(d.getDate() + n)
  return toKey(d)
}

const WD = ['日', '月', '火', '水', '木', '金', '土']

export const shortDate = (k: string) => {
  const d = fromKey(k)
  return `${d.getMonth() + 1}/${d.getDate()}`
}

export const labelDate = (k: string) => {
  const t = todayKey()
  if (k === t) return '今日'
  if (k === addDays(t, -1)) return '昨日'
  const d = fromKey(k)
  const sameYear = d.getFullYear() === new Date().getFullYear()
  return `${sameYear ? '' : d.getFullYear() + '/'}${d.getMonth() + 1}/${d.getDate()}（${WD[d.getDay()]}）`
}

export const fullDate = (k: string) => {
  const d = fromKey(k)
  return `${d.getMonth() + 1}月${d.getDate()}日（${WD[d.getDay()]}）`
}

export const num = (v: number | undefined, digits = 1) =>
  v == null || Number.isNaN(v) ? '—' : Number.isInteger(v) ? String(v) : v.toFixed(digits)

export const kg = (v: number) => (Number.isInteger(v) ? `${v}kg` : `${v.toFixed(1)}kg`)

export const exerciseVolume = (e: ExerciseLog) =>
  e.sets.reduce((s, x) => (x.weight != null && x.reps != null ? s + x.weight * x.reps : s), 0)

export const sessionVolume = (s: TrainingSession) =>
  s.exercises.reduce((sum, e) => sum + exerciseVolume(e), 0)

/** 連続する同じセットをまとめる: "20kg×5 ・ 110kg×5×3セット" */
export const setsSummary = (sets: SetEntry[]) => {
  if (sets.length === 0) return '—'
  const groups: { s: SetEntry; n: number }[] = []
  for (const x of sets) {
    const g = groups[groups.length - 1]
    if (g && g.s.weight === x.weight && g.s.reps === x.reps && g.s.sec === x.sec) g.n++
    else groups.push({ s: x, n: 1 })
  }
  return groups
    .map(({ s, n }) => {
      let t = s.weight != null ? kg(s.weight) : ''
      if (s.reps != null) t += t ? `×${s.reps}` : `${s.reps}回`
      if (s.sec != null) t += t ? `×${s.sec}秒` : `${s.sec}秒`
      if (!t) t = '—'
      return n > 1 ? `${t}×${n}セット` : t
    })
    .join(' ・ ')
}

export const parseNum = (s: string): number | undefined => {
  const v = parseFloat(s.replace(',', '.'))
  return Number.isFinite(v) ? v : undefined
}
