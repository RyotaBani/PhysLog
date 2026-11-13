import { useState } from 'react'
import { actions, useRawData } from './store'
import { Today, EditorHost, type Editing } from './screens/Today'
import { History } from './screens/History'
import { Graph } from './screens/Graph'
import { Insights } from './screens/Insights'
import { Menu } from './screens/Menu'
import { Photos } from './screens/Photos'
import { Settings } from './screens/Settings'
import { ToastHost } from './components/ui'
import { TimerMini, TimerPanel } from './components/Timer'

type Tab = 'today' | 'history' | 'graph' | 'photos' | 'insights' | 'menu' | 'settings'
const TABS: { id: Tab; label: string; icon: string; title: string }[] = [
  { id: 'today', label: '記録', icon: '✏️', title: '今日の記録' },
  { id: 'history', label: '履歴', icon: '🗂️', title: '履歴' },
  { id: 'graph', label: 'グラフ', icon: '📈', title: 'グラフ' },
  { id: 'photos', label: '写真', icon: '📷', title: '体の写真' },
  { id: 'insights', label: '分析', icon: '🔍', title: 'コンディション分析' },
  { id: 'menu', label: 'メニュー', icon: '📋', title: 'メニュー提案' },
  { id: 'settings', label: '設定', icon: '⚙️', title: '設定' },
]

function MemberSwitch() {
  const d = useRawData()
  if (d.members.length < 2) return null
  return (
    <select
      value={d.activeMemberId}
      onChange={(e) => actions.setActiveMember(e.target.value)}
      style={{ width: 'auto', fontWeight: 700, padding: '7px 28px 7px 12px', borderRadius: 999 }}
      aria-label="記録する人"
    >
      {d.members.map((m) => <option key={m.id} value={m.id}>👤 {m.name}</option>)}
    </select>
  )
}

export function App() {
  const [tab, setTab] = useState<Tab>(() => (location.hash.slice(1) as Tab) || 'today')
  const [editing, setEditing] = useState<Editing | null>(null)
  const [timerOpen, setTimerOpen] = useState(false)
  const go = (t: Tab) => { setTab(t); history.replaceState(null, '', '#' + t); window.scrollTo(0, 0) }
  const cur = TABS.find((t) => t.id === tab) ?? TABS[0]

  return (
    <div className="app">
      <aside className="side">
        <div className="brand">Phys<span>Log</span></div>
        <nav className="side-nav">
          {TABS.map((t) => (
            <button key={t.id} className={tab === t.id ? 'on' : ''} onClick={() => go(t.id)}>
              <span>{t.icon}</span>{t.label === "記録" ? "今日の記録" : t.label}
            </button>
          ))}
        </nav>
      </aside>
      <main className="main">
        <header className="topbar">
          <div className="topbar-in">
            <h1>{cur.title}</h1>
            <MemberSwitch />
            <button className="icon-btn" onClick={() => setTimerOpen(true)} aria-label="タイマー">⏱</button>
            {tab !== 'settings' && (
              <button className="icon-btn mobile-only" onClick={() => go('settings')} aria-label="設定">⚙️</button>
            )}
          </div>
          <div className="topbar-in"><TimerMini onOpen={() => setTimerOpen(true)} /></div>
        </header>
        {tab === 'today' && <Today onEdit={setEditing} />}
        {tab === 'history' && <History onEdit={setEditing} />}
        {tab === 'graph' && <Graph />}
        {tab === 'photos' && <Photos />}
        {tab === 'insights' && <Insights />}
        {tab === 'menu' && <Menu />}
        {tab === 'settings' && <Settings onOpenMenu={() => go('menu')} />}
      </main>
      <nav className="tabbar">
        {TABS.filter((t) => t.id !== 'settings' && t.id !== 'menu').map((t) => (
          <button key={t.id} className={tab === t.id ? 'on' : ''} onClick={() => go(t.id)}>
            <span className="ic">{t.icon}</span>{t.label}
          </button>
        ))}
      </nav>
      <EditorHost editing={editing} onClose={() => setEditing(null)} />
      {timerOpen && <TimerPanel onClose={() => setTimerOpen(false)} />}
      <ToastHost />
    </div>
  )
}
