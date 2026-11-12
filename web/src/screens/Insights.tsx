import { useMemo, useState } from 'react'
import { useData } from '../store'
import { Scatter } from '../components/charts'
import { Seg } from '../components/ui'
import { CONDITION_VARS, MIN_SAMPLE, VOLUME_ID, analyze, comparison, strengthLabel, summary, type ConditionVar } from '../lib/analysis'

export function Insights() {
  const d = useData()
  const [cv, setCv] = useState<ConditionVar>('sleep')
  const perfOptions = useMemo(() => [VOLUME_ID, ...new Set(d.abilities.map((a) => a.type))], [d.abilities])
  const [perf, setPerf] = useState(VOLUME_ID)
  const p = perfOptions.includes(perf) ? perf : VOLUME_ID
  const res = useMemo(() => analyze(cv, p, d.conditions, d.sessions, d.abilities), [cv, p, d])
  const comp = comparison(res)
  const enough = res.points.length >= MIN_SAMPLE

  return (
    <div className="wrap">
      <p className="sub" style={{ marginTop: 0 }}>同じ日に記録した「コンディション」と「パフォーマンス」を突き合わせて、関係の強さを調べます。</p>
      <label className="label">コンディション</label>
      <Seg value={cv} onChange={setCv} options={CONDITION_VARS.map((c) => ({ id: c.id, label: c.label }))} />
      <label className="label">パフォーマンス</label>
      <div className="chips scroll" style={{ marginBottom: 12 }}>
        {perfOptions.map((o) => <button key={o} className={'chip' + (p === o ? ' on' : '')} onClick={() => setPerf(o)}>{o === VOLUME_ID ? '総挙上量' : o}</button>)}
      </div>
      <div className="card">
        <div className="card-h">
          <h2>所見</h2>
          {enough && <span className="chip" style={{ background: 'var(--fill)' }}>r = {res.r.toFixed(2)}・{strengthLabel(res.r)}</span>}
        </div>
        <p style={{ margin: 0, lineHeight: 1.7 }}>{summary(res)}</p>
        {comp && <p style={{ margin: '8px 0 0', lineHeight: 1.7 }}>{comp}</p>}
      </div>
      <div className="card">
        <div className="card-h"><h2>散布図</h2><span className="sub">{res.points.length}日分</span></div>
        <Scatter points={res.points} xLabel={res.cv.label} yLabel={res.perfLabel} color="#0087ff" />
      </div>
      <p className="sub">※ 相関は因果関係を示すものではありません。データが{MIN_SAMPLE}日分未満のときは、偶然の一致を傾向と見誤らないよう表示しません。</p>
    </div>
  )
}
