// iOS 版 SampleData.swift と同じ考え方のデモデータ（過去3ヶ月分）
import type { AppData, ExerciseLog, TrainingSession } from '../types'
import { addDays, todayKey } from './format'
import { uid } from '../store'

const r1 = (v: number) => Math.round(v * 10) / 10
const rnd = (a: number, b: number) => a + Math.random() * (b - a)
const round25 = (v: number) => Math.round(v / 2.5) * 2.5

export function makeSample(): Pick<AppData, 'bodies' | 'abilities' | 'sessions' | 'conditions'> {
  const t = todayKey()
  const bodies: AppData['bodies'] = []
  for (let w = 12; w >= 0; w--) {
    const p = (12 - w) / 12
    const weight = 72 - p * 2.6 + rnd(-0.4, 0.4)
    const fat = 18.5 - p * 3.2 + rnd(-0.3, 0.3)
    bodies.push({
      id: uid(), date: addDays(t, -w * 7), memo: '',
      weight: r1(weight), bodyFat: r1(fat), muscle: r1(weight * (1 - fat / 100) * 0.53),
    })
  }

  const abilities: AppData['abilities'] = []
  const plan: [string, string, number, number][] = [
    ['垂直跳び', 'cm', 62, 5],
    ['50m走', '秒', 6.8, -0.25],
    ['握力（右）', 'kg', 44, 3],
    ['ベンチプレス(MAX)', 'kg', 75, 10],
    ['スクワット(MAX)', 'kg', 95, 15],
  ]
  for (const [name, unit, start, delta] of plan) {
    for (let m = 3; m >= 0; m--) {
      abilities.push({
        id: uid(), date: addDays(t, -m * 30), type: name, unit, memo: '',
        value: Math.round((start + (delta * (3 - m)) / 3) * 100) / 100,
      })
    }
  }

  const routines: [string, number, number, number][][] = [
    [['ベンチプレス', 70, 8, 4], ['インクラインベンチプレス', 50, 10, 3], ['ショルダープレス', 40, 10, 3], ['プレスダウン', 30, 12, 3]],
    [['デッドリフト', 110, 5, 4], ['ラットプルダウン', 55, 10, 4], ['ベントオーバーロウ', 50, 10, 3], ['ダンベルカール', 14, 12, 3]],
    [['スクワット', 90, 8, 4], ['レッグプレス', 140, 12, 3], ['ブルガリアンスクワット', 20, 10, 3], ['カーフレイズ', 40, 15, 3]],
  ]
  const sessions: TrainingSession[] = []
  const conditions: AppData['conditions'] = []
  for (let w = 7; w >= 0; w--) {
    routines.forEach((routine, d) => {
      const date = addDays(t, -(w * 7 + d * 2))
      const sleep = r1(rnd(5.5, 8.5))
      const quality = (sleep - 5.5) / 3 // 0〜1。睡眠が長いほど調子が良い想定
      const bonus = (7 - w) * 1.25 + quality * 5
      const exercises: ExerciseLog[] = routine.map(([name, base, reps, sets]) => {
        const top = round25(base + bonus)
        const main = ['ベンチプレス', 'スクワット', 'デッドリフト'].includes(name)
        return {
          id: uid(), name,
          sets: main
            ? [
                { weight: round25(top * 0.5), reps: reps + 4 },
                { weight: round25(top * 0.75), reps: reps + 2 },
                ...Array.from({ length: sets - 1 }, () => ({ weight: top, reps })),
              ]
            : Array.from({ length: sets }, () => ({ weight: top, reps })),
        }
      })
      sessions.push({ id: uid(), date, sport: 'ウェイトトレーニング', memo: '', exercises })
      conditions.push({
        id: uid(), date, sleep, memo: '',
        fatigue: Math.min(5, Math.max(1, Math.round(4 - quality * 3 + rnd(-0.6, 0.6)))),
        condition: Math.min(5, Math.max(1, Math.round(4 - quality * 3 + rnd(-0.6, 0.6)))),
      })
    })
  }
  return { bodies, abilities, sessions, conditions }
}
