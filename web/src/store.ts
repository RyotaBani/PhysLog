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
    if (raw) return normalize(JSON.parse(raw))
    // プレビュー版（1ファイル版）だけ、初回は手元の記録を入れた状態で始める
    return import.meta.env.MODE === 'single' ? normalize(SEED as Partial<AppData>) : empty()
  } catch {
    return empty()
  }
}

const belongs = (memberId: string | undefined, active: string) => (memberId ?? DEFAULT_MEMBER) === active

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

const mergeList = <T extends { id: string }>(a: T[], b: T[] = []) => {
  const ids = new Set(a.map((x) => x.id))
  return [...a, ...b.filter((x) => !ids.has(x.id))]
}

export const actions = {
  saveBody: (b: ItemOf<'bodies'>) => upsert('bodies', b),
  saveAbility: (a: ItemOf<'abilities'>) => upsert('abilities', a),
  saveSession: (s: ItemOf<'sessions'>) => upsert('sessions', s),
  saveCondition: (c: ItemOf<'conditions'>) => upsert('conditions', c),
  remove,
  setProfile: (p: AppData['profile']) => commit({ ...state, profile: p }),

  setActiveMember: (id: string) => commit({ ...state, activeMemberId: id }),
  addMember: (name: string): Member => {
    const m = { id: uid(), name }
    commit({ ...state, members: [...state.members, m], activeMemberId: m.id })
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
  merge: (d: Partial<AppData>) => {
    const members = [...state.members]
    const idMap = new Map<string, string>()
    for (const m of d.members ?? []) {
      const i = members.findIndex((x) => x.id === m.id || x.name === m.name)
      if (i >= 0) {
        idMap.set(m.id, members[i].id)
        // 初期名「自分」のままなら取り込んだ名前を使う
        if (members[i].name === '自分' && m.name) members[i] = { ...members[i], name: m.name }
      }
      else { members.push(m); idMap.set(m.id, m.id) }
    }
    const remap = <T extends { memberId?: string }>(l: T[] = []) =>
      l.map((x) => ({ ...x, memberId: idMap.get(x.memberId ?? DEFAULT_MEMBER) ?? x.memberId ?? DEFAULT_MEMBER }))
    commit({
      ...state,
      members,
      bodies: mergeList(state.bodies, remap(d.bodies)),
      abilities: mergeList(state.abilities, remap(d.abilities)),
      sessions: mergeList(state.sessions, remap(d.sessions)),
      conditions: mergeList(state.conditions, remap(d.conditions)),
    })
  },
  /** 選択中メンバーの記録だけ消す */
  clearActive: () => {
    const a = state.activeMemberId
    const keep = <T extends { memberId?: string }>(l: T[]) => l.filter((x) => !belongs(x.memberId, a))
    commit({ ...state, bodies: keep(state.bodies), abilities: keep(state.abilities), sessions: keep(state.sessions), conditions: keep(state.conditions) })
  },
  getState: () => state,
}
