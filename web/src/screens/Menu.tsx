import { useState } from 'react'
import { GOALS, LEVELS, buildMenu, type Goal, type Level } from '../lib/menu'
import { Seg } from '../components/ui'

export function Menu() {
  const [goal, setGoal] = useState<Goal>('strength')
  const [level, setLevel] = useState<Level>('intermediate')
  const [days, setDays] = useState(3)
  const g = GOALS.find((x) => x.id === goal)!
  const menu = buildMenu(goal, level, days)
  return (
    <div className="wrap">
      <label className="label">目的</label>
      <div className="chips">
        {GOALS.map((x) => (
          <button key={x.id} className={'chip' + (goal === x.id ? ' on' : '')} style={goal === x.id ? { background: x.color } : undefined} onClick={() => setGoal(x.id)}>
            {x.icon} {x.label}
          </button>
        ))}
      </div>
      <p className="sub">{g.summary}</p>
      <label className="label">経験レベル</label>
      <Seg value={level} onChange={setLevel} options={LEVELS.map((l) => ({ id: l.id, label: `${l.label}（${l.detail}）` }))} />
      <label className="label">週の日数</label>
      <Seg value={String(days)} onChange={(v) => setDays(Number(v))} options={[2, 3, 4, 5].map((n) => ({ id: String(n), label: `週${n}日` }))} />
      <div style={{ height: 14 }} />
      {menu.map((day) => (
        <div className="card" key={day.label}>
          <div className="card-h">
            <span className="chip" style={{ background: g.color, color: '#fff' }}>{day.label}</span>
            <h2>{day.focus}</h2>
          </div>
          {day.items.map((it) => (
            <div className="list-item" key={it.name} style={{ alignItems: 'flex-start' }}>
              <div className="grow">
                <div className="row"><b className="grow">{it.name}</b><span style={{ fontWeight: 700, fontSize: 14 }}>{it.sets}×{it.reps}</span></div>
                <div className="sub">休憩 {it.rest}・{it.tip}</div>
              </div>
            </div>
          ))}
        </div>
      ))}
    </div>
  )
}
