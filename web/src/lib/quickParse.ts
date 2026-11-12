// 1行メモ形式のトレーニング記録を読み取る。
//
//   トレーニング記録 2026/11/12
//   Ryota,Katsura
//   BSQ 20kg 5rep 1set,60kg 5rep 3set
//   2db
//   ランジ→2up 10kg 5 3
//
// 方針：略称・表記ゆれ・打ち間違いは推測して埋めるが、推測した箇所は
// confidence を下げて確認画面で目立たせる（勝手に確定させない）。

import type { SetEntry } from '../types'
import { EXERCISES, EXERCISE_ALIASES } from './presets'
import { toKey } from './format'

export interface ParsedExercise {
  key: string
  raw: string
  name: string
  /** exact: 辞書・履歴と一致 / alias: 略称から変換 / fuzzy: 打ち間違いを推測 / unknown: 不明 / missing: 種目名なし */
  match: 'exact' | 'alias' | 'fuzzy' | 'unknown' | 'missing'
  sets: SetEntry[]
  note?: string
}

export interface ParsedBlock {
  key: string
  date: string
  members: string[] // メンバー名（未登録の名前も含む）
  exercises: ParsedExercise[]
}

export interface ParseResult {
  blocks: ParsedBlock[]
  ignored: string[]
}

const norm = (s: string) =>
  s.normalize('NFKC').replace(/\s+/g, '').toUpperCase()
    // カタカナ・ひらがなの揺れ
    .replace(/[ぁ-ゖ]/g, (c) => String.fromCharCode(c.charCodeAt(0) + 0x60))
    .replace(/ー/g, '')

function levenshtein(a: string, b: string) {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)])
  for (let j = 1; j <= b.length; j++) dp[0][j] = j
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++)
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
  return dp[a.length][b.length]
}

// 打ち間違いで混ざりやすい表記（2 = to、など）も略称として持つ
const EXTRA_ALIASES: Record<string, string> = {
  UP: 'ステップアップ', STEPUP: 'ステップアップ', '2UP': 'ステップアップ', TOUP: 'ステップアップ', SU: 'ステップアップ',
  LUNGE: 'ランジ', LEGPRESS: 'レッグプレス', 'レッグプレ': 'レッグプレス',
  DEADLIFT: 'デッドリフト', SQUAT: 'スクワット', BACKSQUAT: 'バックスクワット', FRONTSQUAT: 'フロントスクワット',
  BENCH: 'ベンチプレス', BENCHPRESS: 'ベンチプレス', CLEAN: 'ハングクリーン', HANGCLEAN: 'ハングクリーン',
  ROW: 'ベントオーバーロウ', LATPULL: 'ラットプルダウン', CURL: 'ダンベルカール', PLANK: 'プランク',
  CALF: 'カーフレイズ', 'ダイアゴナル': 'ストレッチポール ダイアゴナル', CABLECRUNCH: 'ケーブルクランチ', 'ロープクランチ': 'ケーブルクランチ', 'ニーリングケーブルクランチ': 'ケーブルクランチ', 'ケーブル腹筋': 'ケーブルクランチ', PU: '懸垂', CHIN: '懸垂', PULLUP: '懸垂', DIPS: 'ディップス',
}

export function resolveName(raw: string, known: string[]): { name: string; match: ParsedExercise['match'] } {
  const q = norm(raw)
  if (!q) return { name: '', match: 'missing' }
  const dict = [...new Set([...known, ...EXERCISES.flatMap((c) => c.items)])]
  const exact = dict.find((n) => norm(n) === q)
  if (exact) return { name: exact, match: 'exact' }
  const aliases: Record<string, string> = { ...EXERCISE_ALIASES, ...EXTRA_ALIASES }
  if (aliases[q]) return { name: aliases[q], match: 'alias' }
  // 部分一致（「スクワ」→スクワット など）。候補が1つに絞れるときだけ
  const partial = dict.filter((n) => norm(n).includes(q))
  if (partial.length === 1) return { name: partial[0], match: 'fuzzy' }
  // 打ち間違い：編集距離が短いもの
  let best = '', bestD = Infinity
  for (const n of [...dict, ...Object.keys(aliases)]) {
    const d = levenshtein(q, norm(n))
    if (d < bestD) { bestD = d; best = n }
  }
  const limit = q.length <= 3 ? 1 : q.length <= 6 ? 2 : 3
  if (bestD <= limit) return { name: aliases[norm(best)] ?? best, match: 'fuzzy' }
  return { name: raw.trim(), match: 'unknown' }
}

/** 「→」でつないだ複合種目は、部分ごとに解決してつなぎ直す */
function resolveCombo(raw: string, known: string[]): { name: string; match: ParsedExercise['match'] } {
  const parts = raw.split(/→|->|＞|>/).map((p) => p.trim()).filter(Boolean)
  if (parts.length <= 1) return resolveName(raw, known)
  const whole = resolveName(raw, known)
  if (whole.match === 'exact') return whole
  const rs = parts.map((p) => resolveName(p, known))
  const rank = { exact: 0, alias: 1, fuzzy: 2, unknown: 3, missing: 4 } as const
  const worst = rs.reduce((w, r) => (rank[r.match] > rank[w] ? r.match : w), 'exact' as ParsedExercise['match'])
  return { name: rs.map((r) => r.name).join('→'), match: worst === 'exact' ? 'exact' : worst }
}

const DATE_RE = /(?:(\d{4})\s*[/\-.年]\s*)?(\d{1,2})\s*[/\-.月]\s*(\d{1,2})\s*日?/

function parseDate(line: string, fallbackYear: number): string | null {
  const m = line.normalize('NFKC').match(DATE_RE)
  if (!m) return null
  const y = m[1] ? Number(m[1]) : fallbackYear
  const mo = Number(m[2]), d = Number(m[3])
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null
  return toKey(new Date(y, mo - 1, d))
}

/**
 * セット表記を読む。区切り（, 、 /）ごとに「重量 回数 セット数」。
 *   "20kg 5rep 1set" "60kg×5×3" "10kg 5 3" "132kg 10回 3セット" "自重 10 3"
 */
function parseSets(text: string): SetEntry[] | null {
  const segs = text.normalize('NFKC').split(/[,、/]|\s{2,}/).map((s) => s.trim()).filter(Boolean)
  const out: SetEntry[] = []
  for (const seg of segs) {
    const s = seg.toLowerCase().replace(/[x×*]/g, ' ')
    let weight: number | undefined, reps: number | undefined, sets: number | undefined, sec: number | undefined
    const sm = s.match(/(\d+)\s*(?:秒|sec|s(?![a-z])|キープ|keep)/)
    if (sm) sec = Number(sm[1])
    const s2 = sm ? s.replace(sm[0], ' ') : s
    const w = s2.match(/(\d+(?:\.\d+)?)\s*(?:kg|ｋｇ|キロ)/)
    const r = s2.match(/(\d+)\s*(?:rep|reps|回|r\b)/)
    const st = s2.match(/(\d+)\s*(?:set|sets|セット)/)
    if (w) weight = Number(w[1])
    if (r) reps = Number(r[1])
    if (st) sets = Number(st[1])
    // 単位のない数字は「重量 回数 セット」の順で空いている所に入れる
    const rest = s2
      .replace(w?.[0] ?? '\u0000', ' ').replace(r?.[0] ?? '\u0000', ' ').replace(st?.[0] ?? '\u0000', ' ')
      .match(/\d+(?:\.\d+)?/g)?.map(Number) ?? []
    const isBodyweight = /自重|bw/.test(s) || sec != null
    for (const n of rest) {
      if (weight == null && !isBodyweight && !(reps != null && sets == null && rest.length === 1)) weight = n
      else if (reps == null) reps = n
      else if (sets == null) sets = n
    }
    if (weight == null && reps == null && sec == null) continue
    const count = Math.min(Math.max(sets ?? 1, 1), 20)
    for (let i = 0; i < count; i++) out.push(sec != null ? { weight, reps, sec } : { weight, reps })
  }
  return out.length ? out : null
}

export function parseQuickText(text: string, opts: { memberNames: string[]; knownExercises: string[]; today: string }): ParseResult {
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean)
  const year = Number(opts.today.slice(0, 4))
  const blocks: ParsedBlock[] = []
  const ignored: string[] = []
  let date = opts.today
  let members: string[] = []
  let dumbbellPair = false
  // 種目名だけの行のあとに続く「数字だけの行」は、その種目のセットとして足す
  //   オーバーヘッドランジ
  //   20 10 1
  //   33 10 1
  let open: ParsedExercise | null = null
  let k = 0

  const current = () => {
    let b = blocks[blocks.length - 1]
    if (!b || b.date !== date || b.members.join('|') !== members.join('|')) {
      b = { key: 'b' + k++, date, members: [...members], exercises: [] }
      blocks.push(b)
    }
    return b
  }
  const isMemberToken = (t: string) =>
    opts.memberNames.some((m) => norm(m) === norm(t)) || /^[A-Z][a-z]+$/.test(t) || /^[一-鿿]{1,4}(さん|くん|ちゃん)?$/.test(t)

  for (const line of lines) {
    const d = parseDate(line, year)
    // 日付だけ（＋見出し語）の行
    if (d && !/\d+\s*(kg|rep|回|set|セット)/i.test(line)) {
      open = null
      date = d
      continue
    }
    // ダンベル2個の指定（2db / db×2 / ダンベル2）
    if (/^(2\s*db|db\s*[x×]?\s*2|ダンベル\s*2(個|本)?)$/i.test(line.normalize('NFKC'))) {
      dumbbellPair = true
      continue
    }
    // メンバー行：数字を含まず、区切られた全部が人名らしい
    if (!/\d/.test(line)) {
      const toks = line.split(/[,、・&＆\s]+|と(?=[A-Z一-鿿])/).map((t) => t.trim()).filter(Boolean)
      if (toks.length && toks.every(isMemberToken) && toks.every((t) => resolveName(t, opts.knownExercises).match !== 'exact')) {
        members = toks.map((t) => opts.memberNames.find((m) => norm(m) === norm(t)) ?? t)
        open = null
        continue
      }
    }
    // 種目行：最初の数字の手前までを種目名とみなす
    const n = line.normalize('NFKC')
    const firstNum = n.search(/(?<![A-Za-z])\d+(?:\.\d+)?\s*(kg|キロ|rep|回|set|セット|秒|sec|キープ|s(?=[\s,、]|$)|[x×*]|\s|$)/i)
    let namePart = (firstNum >= 0 ? n.slice(0, firstNum) : n).replace(/[:：\-–]\s*$/, '').trim()
    let setsPart = firstNum >= 0 ? n.slice(firstNum) : ''
    // 「懸垂 自重 8 3」の「自重」は種目名ではなくセット側の情報
    const bw = namePart.match(/\s*(自重|BW)$/i)
    if (bw) { namePart = namePart.slice(0, bw.index).trim(); setsPart = '自重 ' + setsPart }
    const sets = setsPart ? parseSets(setsPart) : null
    if (!sets && !namePart) { ignored.push(line); continue }
    if (!sets) {
      // 種目名だけの行は、数字なしの記録として残す（確認画面で入力できる）
      const r = resolveCombo(namePart, opts.knownExercises)
      if (r.match === 'unknown' && namePart.length > 30) { ignored.push(line); continue }
      open = { key: 'e' + k++, raw: line, name: r.name, match: r.match, sets: [] }
      if (dumbbellPair) {
        if (!open.name.startsWith('ダンベル')) open.name = 'ダンベル' + open.name
        open.note = 'ダンベル2個（重量は片手）'
        dumbbellPair = false
      }
      current().exercises.push(open)
      continue
    }
    if (!namePart && open) {
      open.sets.push(...sets)
      open.raw += ' / ' + line
      continue
    }
    open = null
    let r = resolveCombo(namePart, opts.knownExercises)
    let note: string | undefined
    if (dumbbellPair) {
      if (r.name && !r.name.startsWith('ダンベル')) r = { ...r, name: 'ダンベル' + r.name }
      note = 'ダンベル2個（重量は片手）'
      dumbbellPair = false
    }
    current().exercises.push({ key: 'e' + k++, raw: line, name: r.name, match: r.match, sets, note })
  }
  return { blocks: blocks.filter((b) => b.exercises.length), ignored }
}

/** 確認画面でセットを手直しするための、往復できる短い表記 */
export const setsToText = (sets: SetEntry[]) => {
  const groups: { s: SetEntry; n: number }[] = []
  for (const x of sets) {
    const g = groups[groups.length - 1]
    if (g && g.s.weight === x.weight && g.s.reps === x.reps && g.s.sec === x.sec) g.n++
    else groups.push({ s: x, n: 1 })
  }
  return groups.map(({ s, n }) => [
    s.weight != null ? `${s.weight}kg` : s.sec == null ? '自重' : '',
    s.reps != null ? `${s.reps}回` : '',
    s.sec != null ? `${s.sec}秒` : '',
    n > 1 ? `${n}set` : '',
  ].filter(Boolean).join(' ')).join(', ')
}
export const textToSets = (t: string) => parseSets(t) ?? []
