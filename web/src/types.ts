// iOS 版（SwiftData）のモデルをそのまま写したもの。
// 日付は端末ローカルの "YYYY-MM-DD" 文字列で持つ（タイムゾーンずれを避けるため）。

export interface BodyMeasurement {
  id: string
  /** 誰の記録か（Member.id）。未設定は既定メンバー */
  memberId?: string
  date: string
  weight?: number // kg
  bodyFat?: number // %
  muscle?: number // kg
  memo: string
}

export interface PhysicalAbility {
  id: string
  /** 誰の記録か（Member.id）。未設定は既定メンバー */
  memberId?: string
  date: string
  type: string
  value: number
  unit: string
  memo: string
}

export interface SetEntry {
  weight?: number
  reps?: number
  /** キープ系の種目の秒数（プランク・ダイアゴナルなど） */
  sec?: number
}

export interface ExerciseLog {
  id: string
  name: string
  sets: SetEntry[]
}

export interface TrainingSession {
  id: string
  /** 誰の記録か（Member.id）。未設定は既定メンバー */
  memberId?: string
  date: string
  sport: string
  memo: string
  exercises: ExerciseLog[]
}

export interface ConditionRecord {
  id: string
  /** 誰の記録か（Member.id）。未設定は既定メンバー */
  memberId?: string
  date: string
  sleep?: number // 時間
  fatigue?: number // 1 = ほぼなし … 5 = 非常に高い
  condition?: number // 1 = 最高 … 5 = 不調
  memo: string
}

export interface Profile {
  name: string
  sport: string
}

/** 記録する人。コーチが複数人の記録を取る用途のため */
export interface Member {
  id: string
  name: string
}

export interface AppData {
  version: 1
  profile: Profile
  members: Member[]
  activeMemberId: string
  bodies: BodyMeasurement[]
  abilities: PhysicalAbility[]
  sessions: TrainingSession[]
  conditions: ConditionRecord[]
}
