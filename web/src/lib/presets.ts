// iOS 版 PhysicalAbility.swift / TrainingModels.swift のプリセットを移植

export interface AbilityPreset {
  name: string
  unit: string
  icon: string
  lowerBetter?: boolean
}

export const ABILITY_PRESETS: AbilityPreset[] = [
  { name: '垂直跳び', unit: 'cm', icon: '⤴️' },
  { name: '立ち幅跳び', unit: 'cm', icon: '➡️' },
  { name: '50m走', unit: '秒', icon: '🏃', lowerBetter: true },
  { name: '100m走', unit: '秒', icon: '🏃', lowerBetter: true },
  { name: '20mスプリント', unit: '秒', icon: '🏃', lowerBetter: true },
  { name: '握力（右）', unit: 'kg', icon: '✊' },
  { name: '握力（左）', unit: 'kg', icon: '✊' },
  { name: '反復横跳び', unit: '回', icon: '↔️' },
  { name: 'シャトルラン', unit: '回', icon: '🔁' },
  { name: '長座体前屈', unit: 'cm', icon: '🧘' },
  { name: 'ベンチプレス(MAX)', unit: 'kg', icon: '🏋️' },
  { name: 'スクワット(MAX)', unit: 'kg', icon: '🏋️' },
  { name: 'デッドリフト(MAX)', unit: 'kg', icon: '🏋️' },
  { name: '腕立て伏せ', unit: '回', icon: '💪' },
  { name: '懸垂', unit: '回', icon: '🧗' },
]

export const findAbility = (name: string) => ABILITY_PRESETS.find((p) => p.name === name)

export const isLowerBetter = (name: string) => findAbility(name)?.lowerBetter ?? false

export const abilityIcon = (name: string) => {
  const p = findAbility(name)
  if (p) return p.icon
  if (name.includes('跳')) return '⤴️'
  if (name.includes('走') || name.includes('ラン')) return '🏃'
  if (name.includes('握力')) return '✊'
  if (name.includes('MAX') || name.includes('プレス')) return '🏋️'
  return '⭐'
}

export const EXERCISES: { category: string; items: string[] }[] = [
  { category: '胸', items: ['ベンチプレス', 'インクラインベンチプレス', 'ダンベルプレス', 'ダンベルフライ', 'チェストプレス', 'プッシュアップ'] },
  { category: '背中', items: ['デッドリフト', '懸垂', 'ラットプルダウン', 'ベントオーバーロウ', 'シーテッドロウ'] },
  { category: '肩', items: ['ショルダープレス', 'サイドレイズ', 'フロントレイズ', 'リアレイズ', 'フェイスプル'] },
  { category: '腕', items: ['バーベルカール', 'ダンベルカール', 'ハンマーカール', 'プレスダウン', 'ディップス'] },
  { category: '脚', items: ['スクワット', 'バックスクワット', 'フロントスクワット', 'オーバーヘッドスクワット', 'レッグプレス', 'ランジ', 'オーバーヘッドランジ', 'ダンベルランジ→ステップアップ', 'ステップアップ', 'ブルガリアンスクワット', 'レッグカール', 'レッグエクステンション', 'カーフレイズ'] },
  { category: '体幹', items: ['プランク', 'クランチ', 'レッグレイズ', 'ロシアンツイスト', 'アブローラー'] },
  { category: '有酸素', items: ['ランニング', 'バイク', '縄跳び', 'バーピー', 'ケトルベルスイング'] },
]

export const SPORTS = [
  'ウェイトトレーニング', 'バスケットボール', 'サッカー', '野球',
  'バレーボール', '陸上', '水泳', 'テニス', 'ランニング', 'その他',
]

export const CONDITION_LABELS = ['最高', '良好', '普通', 'やや不調', '不調']
export const FATIGUE_LABELS = ['ほぼなし', '少しある', '中程度', 'かなり', '非常に高い']
export const CONDITION_COLORS = ['#22c55e', '#3b82f6', '#eab308', '#f97316', '#ef4444']

/** 略称での検索用（BSQ と打てばバックスクワットが出る） */
export const EXERCISE_ALIASES: Record<string, string> = {
  BSQ: 'バックスクワット', OHSQ: 'オーバーヘッドスクワット', OHS: 'オーバーヘッドスクワット', SQ: 'スクワット', FSQ: 'フロントスクワット',
  BP: 'ベンチプレス', DL: 'デッドリフト', RDL: 'ルーマニアンデッドリフト',
  OHP: 'ショルダープレス', LP: 'レッグプレス',
}
export const resolveAlias = (q: string) => EXERCISE_ALIASES[q.trim().toUpperCase()]
