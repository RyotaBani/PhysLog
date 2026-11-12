import { useSyncExternalStore } from 'react'
import type { AppData, Member } from './types'
import SEED from './seed.json'

// すべてブラウザの localStorage に保存する（外部送信なし。iOS 版と同じ方針）。
const KEY = 'physlog.v1'
export const DEFAULT_MEMBER = 'me'

const empty = (): AppData => ({
  version: 1,
  profile: { name: '', sport: '' },
  members: [{ id: DEFAULT_MEMBER, name: '自分' }],
  activeMemberId: DEFAULT_MEMBER,
  bodies: [],
  abilities: [],
  sessions: [],
  conditions: [],
})

function normalize(d: Partial<AppData>): AppData {
  const base = { ...empty(), ...d, version: 1 as const }
  if (!base.members?.length) base.members = empty().members
  if (!base.members.some((m) => m.id === base.activeMemberId)) base.activeMemberId = base.members[0].id
  return base
}

function load(): AppData {
  try {
    const raw = localStorage.getItem(KEY)
    const base = raw ? normalize(JSON.parse(raw)) : empty()
    // プレビュー版（1ファイル版）だけ、手元の記録を入れた状態で始める。
    // 一度入れた記録は消しても戻らないよう、入れたIDを覚えておく。
    if (import.meta.env.MODE !== 'single') return base
    const SEEDED = KEY + '.seeded'
    const done = new Set<string>(JSON.parse(localStorage.getItem(SEEDED) ?? '[]'))
    const seed = SEED as Partial<AppData>
    const pick = <T extends { id: string }>(l: T[] = []) => l.filter((x) => !done.has(x.id))
    const fresh = { members: seed.members, sessions: pick(seed.sessions), bodies: pick(seed.bodies), abilities: pick(seed.abilities), conditions: pick(seed.conditions) }
    // 既に入れたセッションに後から足した種目は、種目単位で追記する
    // 訂正で差し替えた種目（古いID）は一度だけ取り除く
    const removed = ((SEED as { removedExerciseIds?: string[] }).removedExerciseIds ?? []).filter((id) => !done.has('rm:' + id))
    removed.forEach((id) => done.add('rm:' + id))
    const sessions = base.sessions.map((s0) => {
      const s = removed.length ? { ...s0, exercises: s0.exercises.filter((e) => !removed.includes(e.id)) } : s0
      const src = seed.sessions?.find((x) => x.id === s.id)
      if (!src) return s
      const add = src.exercises.filter((e) => !done.has(e.id) && !s.exercises.some((x) => x.id === e.id))
      return add.length ? { ...s, exercises: [...s.exercises, ...add] } : s
    })
    ;[fresh.sessions, fresh.bodies, fresh.abilities, fresh.conditions].forEach((l) => l.forEach((x) => done.add(x.id)))
    seed.sessions?.forEach((x) => x.exercises.forEach((e) => done.add(e.id)))
    localStorage.setItem(SEEDED, JSON.stringify([...done]))
    return mergeInto({ ...base, sessions }, fresh)
  } catch {
    return empty()
  }
}

const belongs = (memberId: string | undefined, active: string) => (memberId ?? DEFAULT_MEMBER) === active

const mergeList = <T extends { id: string }>(a: T[], b: T[] = []) => {
  const ids = new Set(a.map((x) => x.id))
  return [...a, ...b.filter((x) => !ids.has(x.id))]
}

function mergeInto(state: AppData, d: Partial<AppData>): AppData {
  const members = [...state.members]
  const idMap = new Map<string, string>()
  for (const m of d.members ?? []) {
    const i = members.findIndex((x) => x.id === m.id || x.name === m.name)
    if (i >= 0) {
      idMap.set(m.id, members[i].id)
      // 初期名「自分」のままなら取り込んだ名前を使う
      if (members[i].name === '自分' && m.name) members[i] = { ...members[i], name: m.name }
    } else {
      members.push(m)
      idMap.set(m.id, m.id)
    }
  }
  const remap = <T extends { memberId?: string }>(l: T[] = []) =>
    l.map((x) => ({ ...x, memberId: idMap.get(x.memberId ?? DEFAULT_MEMBER) ?? x.memberId ?? DEFAULT_MEMBER }))
  return {
    ...state,
    members,
    bodies: mergeList(state.bodies, remap(d.bodies)),
    abilities: mergeList(state.abilities, remap(d.abilities)),
    sessions: mergeList(state.sessions, remap(d.sessions)),
    conditions: mergeList(state.conditions, remap(d.conditions)),
  }
}

let state: AppData = load()
let view: AppData = scope(state)
const listeners = new Set<() => void>()

/** 選択中のメンバーの記録だけに絞った見え方 */
function scope(s: AppData): AppData {
  const a = s.activeMemberId
  return {
    ...s,
    bodies: s.bodies.filter((x) => belongs(x.memberId, a)),
    abilities: s.abilities.filter((x) => belongs(x.memberId, a)),
    sessions: s.sessions.filter((x) => belongs(x.memberId, a)),
    conditions: s.conditions.filter((x) => belongs(x.memberId, a)),
  }
}

function commit(next: AppData) {
  state = next
  view = scope(next)
  try {
    localStorage.setItem(KEY, JSON.stringify(next))
  } catch {
    // 容量超過などは無視（画面上のデータは保持される）
  }
  listeners.forEach((l) => l())
}

const subscribe = (cb: () => void) => {
  listeners.add(cb)
  return () => { listeners.delete(cb) }
}

/** 選択中メンバーの記録 */
export const useData = (): AppData => useSyncExternalStore(subscribe, () => view)
/** 全メンバー分（設定・書き出し用） */
export const useRawData = (): AppData => useSyncExternalStore(subscribe, () => state)

export const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8)

type Collection = 'bodies' | 'abilities' | 'sessions' | 'conditions'
type ItemOf<C extends Collection> = AppData[C][number]

function upsert<C extends Collection>(col: C, item: ItemOf<C>) {
  const withMember = { ...item, memberId: item.memberId ?? state.activeMemberId }
  const list = state[col] as ItemOf<C>[]
  const exists = list.some((x) => x.id === item.id)
  const next = exists ? list.map((x) => (x.id === item.id ? withMember : x)) : [...list, withMember]
  commit({ ...state, [col]: next })
}

function remove(col: Collection, id: string) {
  const list = state[col] as { id: string }[]
  commit({ ...state, [col]: list.filter((x) => x.id !== id) })
}

export const actions = {
  saveBody: (b: ItemOf<'bodies'>) => upsert('bodies', b),
  saveAbility: (a: ItemOf<'abilities'>) => upsert('abilities', a),
  saveSession: (s: ItemOf<'sessions'>) => upsert('sessions', s),
  saveCondition: (c: ItemOf<'conditions'>) => upsert('conditions', c),
  remove,
  setProfile: (p: AppData['profile']) => commit({ ...state, profile: p }),

  setActiveMember: (id: string) => commit({ ...state, activeMemberId: id }),
  addMember: (name: string, activate = true): Member => {
    const m = { id: uid(), name }
    commit({ ...state, members: [...state.members, m], activeMemberId: activate ? m.id : state.activeMemberId })
    return m
  },
  renameMember: (id: string, name: string) =>
    commit({ ...state, members: state.members.map((m) => (m.id === id ? { ...m, name } : m)) }),
  /** メンバーと、その人の記録をすべて消す */
  deleteMember: (id: string) => {
    if (state.members.length <= 1) return
    const keep = <T extends { memberId?: string }>(l: T[]) => l.filter((x) => (x.memberId ?? DEFAULT_MEMBER) !== id)
    const members = state.members.filter((m) => m.id !== id)
    commit({
      ...state,
      members,
      activeMemberId: state.activeMemberId === id ? members[0].id : state.activeMemberId,
      bodies: keep(state.bodies),
      abilities: keep(state.abilities),
      sessions: keep(state.sessions),
      conditions: keep(state.conditions),
    })
  },

  replaceAll: (d: Partial<AppData>) => commit(normalize(d)),
  /** 取り込み。同じIDは上書きしない。メンバーも名前で突き合わせて追加 */
  merge: (d: Partial<AppData>) => commit(mergeInto(state, d)),
  /** 選択中メンバーの記録だけ消す */
  clearActive: () => {
    const a = state.activeMemberId
    const keep = <T extends { memberId?: string }>(l: T[]) => l.filter((x) => !belongs(x.memberId, a))
    commit({ ...state, bodies: keep(state.bodies), abilities: keep(state.abilities), sessions: keep(state.sessions), conditions: keep(state.conditions) })
  },
  getState: () => state,
}
