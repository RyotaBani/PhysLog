import { useEffect, useState, useSyncExternalStore } from 'react'
import { Seg } from './ui'

// ワークアウトタイマー。画面を移っても動き続けるよう、状態はモジュールに置く。
// 経過は Date.now() との差で計算する（タブが裏に回って setInterval が間引かれても狂わない）。

type Mode = 'rest' | 'interval' | 'stopwatch'
interface TimerState {
  mode: Mode
  running: boolean
  /** カウントダウンの終了時刻 / ストップウォッチの開始時刻（ms） */
  anchor: number
  /** 一時停止中の残り（カウントダウン）または経過（ストップウォッチ）ms */
  held: number
  restSec: number
  work: number
  rest: number
  rounds: number
  round: number
  phase: 'work' | 'rest'
  laps: number[]
}

let st: TimerState = {
  mode: 'rest', running: false, anchor: 0, held: 90_000, restSec: 90,
  work: 40, rest: 20, rounds: 8, round: 1, phase: 'work', laps: [],
}
const subs = new Set<() => void>()
const set = (p: Partial<TimerState>) => { st = { ...st, ...p }; subs.forEach((f) => f()) }
const useTimer = () => useSyncExternalStore((cb) => { subs.add(cb); return () => { subs.delete(cb) } }, () => st)

let audio: AudioContext | null = null
function beep(times = 3, freq = 880) {
  try {
    audio ??= new AudioContext()
    for (let i = 0; i < times; i++) {
      const o = audio.createOscillator(), g = audio.createGain()
      o.frequency.value = freq
      o.connect(g); g.connect(audio.destination)
      const t = audio.currentTime + i * 0.25
      g.gain.setValueAtTime(0.25, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.18)
      o.start(t); o.stop(t + 0.2)
    }
  } catch { /* 音が出せない環境は無視 */ }
  try { navigator.vibrate?.([200, 100, 200]) } catch { /* 無視 */ }
}

const remaining = (now: number) => (st.running ? Math.max(0, st.anchor - now) : st.held)
const elapsed = (now: number) => (st.running ? now - st.anchor : st.held)

function startCountdown(ms: number) { set({ running: true, anchor: Date.now() + ms, held: ms }) }

export const timerActions = {
  startRest: (sec: number) => { audio ??= new AudioContext(); set({ mode: 'rest', restSec: sec, laps: [] }); startCountdown(sec * 1000) },
  pause: () => set({ running: false, held: st.mode === 'stopwatch' ? elapsed(Date.now()) : remaining(Date.now()) }),
  resume: () => (st.mode === 'stopwatch' ? set({ running: true, anchor: Date.now() - st.held }) : startCountdown(st.held)),
  add: (sec: number) => {
    if (st.running) set({ anchor: st.anchor + sec * 1000 })
    else set({ held: Math.max(0, st.held + sec * 1000) })
  },
  reset: () => set({ running: false, held: st.mode === 'rest' ? st.restSec * 1000 : st.mode === 'interval' ? st.work * 1000 : 0, round: 1, phase: 'work', laps: [] }),
  startInterval: () => { audio ??= new AudioContext(); set({ mode: 'interval', round: 1, phase: 'work' }); startCountdown(st.work * 1000) },
  startStopwatch: () => { audio ??= new AudioContext(); set({ mode: 'stopwatch', running: true, anchor: Date.now(), held: 0, laps: [] }) },
  lap: () => set({ laps: [...st.laps, elapsed(Date.now())] }),
}

// 0.25秒ごとに終了判定（どの画面にいても1か所で回す）
let ticking = false
function ensureTicker() {
  if (ticking) return
  ticking = true
  setInterval(() => {
    if (!st.running || st.mode === 'stopwatch') return
    if (remaining(Date.now()) > 0) return
    if (st.mode === 'rest') { beep(3); set({ running: false, held: 0 }); return }
    // インターバル：作業→休憩→次のラウンド
    if (st.phase === 'work') {
      if (st.round >= st.rounds) { beep(5, 1200); set({ running: false, held: 0 }); return }
      beep(2, 660); set({ phase: 'rest' }); startCountdown(st.rest * 1000)
    } else {
      beep(1, 1000); set({ phase: 'work', round: st.round + 1 }); startCountdown(st.work * 1000)
    }
  }, 250)
}

const fmt = (ms: number, tenths = false) => {
  const total = Math.max(0, ms)
  const m = Math.floor(total / 60000), s = Math.floor((total % 60000) / 1000)
  return `${m}:${String(s).padStart(2, '0')}${tenths ? '.' + Math.floor((total % 1000) / 100) : ''}`
}

/** 再描画用。動いている間だけ細かく回す */
function useNow(active: boolean) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    if (!active) return
    const id = setInterval(() => setNow(Date.now()), 100)
    return () => clearInterval(id)
  }, [active])
  return now
}

/** 動いている間、画面上部に出す小さな表示。押すとタイマーを開く */
export function TimerMini(props: { onOpen: () => void }) {
  ensureTicker()
  const t = useTimer()
  const now = useNow(t.running)
  const active = t.running || (t.mode === 'stopwatch' ? t.held > 0 : t.held > 0 && t.held < (t.mode === 'rest' ? t.restSec : t.work) * 1000)
  if (!active) return null
  const label = t.mode === 'rest' ? 'レスト' : t.mode === 'interval' ? `${t.phase === 'work' ? '運動' : '休憩'} ${t.round}/${t.rounds}` : 'ストップウォッチ'
  const val = t.mode === 'stopwatch' ? fmt(elapsed(now)) : fmt(remaining(now))
  const done = t.mode !== 'stopwatch' && !t.running && t.held === 0
  return (
    <button className="timer-mini" onClick={props.onOpen} style={done ? { background: 'var(--green)' } : t.mode === 'interval' && t.phase === 'rest' ? { background: 'var(--orange)' } : undefined}>
      ⏱ {label} <b>{done ? '終了' : val}</b>{!t.running && !done && '（停止中）'}
    </button>
  )
}

export function TimerPanel(props: { onClose: () => void }) {
  ensureTicker()
  const t = useTimer()
  const now = useNow(t.running)
  const [tab, setTab] = useState<Mode>(t.mode)
  const isCurrent = tab === t.mode
  const big = !isCurrent
    ? tab === 'rest' ? fmt(t.restSec * 1000) : tab === 'interval' ? fmt(t.work * 1000) : '0:00'
    : t.mode === 'stopwatch' ? fmt(elapsed(now), true) : fmt(remaining(now))
  const color = t.mode === 'interval' && isCurrent ? (t.phase === 'work' ? 'var(--primary)' : 'var(--orange)') : 'var(--text)'
  const started = isCurrent && (t.running || (t.mode === 'stopwatch' ? t.held > 0 : t.held !== (t.mode === 'rest' ? t.restSec : t.work) * 1000))

  const num = (v: number, on: (n: number) => void, step: number, unit: string) => (
    <div className="stepper" style={{ flex: 1 }}>
      <button onClick={() => on(Math.max(step, v - step))}>−</button>
      <input value={v} inputMode="numeric" onChange={(e) => on(Math.max(1, Number(e.target.value) || 1))} />
      <span className="u">{unit}</span>
      <button onClick={() => on(v + step)}>＋</button>
    </div>
  )

  return (
    <div className="sheet-bg" onClick={props.onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        <div className="sheet-h">
          <button className="btn" onClick={props.onClose}>閉じる</button>
          <h3>タイマー</h3>
          <span style={{ width: 64 }} />
        </div>
        <div className="sheet-b">
          <Seg value={tab} onChange={setTab} options={[{ id: 'rest', label: 'レスト' }, { id: 'interval', label: 'インターバル' }, { id: 'stopwatch', label: 'ストップウォッチ' }]} />
          <div style={{ textAlign: 'center', margin: '22px 0 8px' }}>
            {tab === 'interval' && isCurrent && <div className="sub" style={{ fontWeight: 800, color }}>{t.phase === 'work' ? '運動' : '休憩'}　ラウンド {t.round} / {t.rounds}</div>}
            <div style={{ fontSize: 72, fontWeight: 800, letterSpacing: '-0.03em', fontVariantNumeric: 'tabular-nums', color }}>{big}</div>
          </div>

          {tab === 'rest' && (
            <>
              <div className="grid3" style={{ gridTemplateColumns: 'repeat(5, 1fr)', marginBottom: 12 }}>
                {[30, 60, 90, 120, 180].map((sec) => (
                  <button key={sec} className={'btn sm' + (t.restSec === sec && isCurrent ? ' primary' : '')} onClick={() => timerActions.startRest(sec)}>
                    {sec < 60 ? `${sec}秒` : `${Math.floor(sec / 60)}分${sec % 60 ? '半' : ''}`}
                  </button>
                ))}
              </div>
              {started && (
                <div className="grid3" style={{ marginBottom: 12 }}>
                  <button className="btn" onClick={() => timerActions.add(-15)}>−15秒</button>
                  <button className="btn primary" onClick={t.running ? timerActions.pause : timerActions.resume}>{t.running ? '一時停止' : '再開'}</button>
                  <button className="btn" onClick={() => timerActions.add(15)}>＋15秒</button>
                </div>
              )}
              <p className="sub" style={{ textAlign: 'center' }}>時間を押すとすぐ始まります。終わると音と振動でお知らせします。</p>
            </>
          )}

          {tab === 'interval' && (
            <>
              <label className="label">運動</label>{num(t.work, (n) => set({ work: n, ...(isCurrent && !started ? { held: n * 1000 } : {}) }), 5, '秒')}
              <label className="label">休憩</label>{num(t.rest, (n) => set({ rest: n }), 5, '秒')}
              <label className="label">ラウンド</label>{num(t.rounds, (n) => set({ rounds: n }), 1, '回')}
              <div className="row" style={{ marginTop: 16 }}>
                {started ? (
                  <>
                    <button className="btn grow" onClick={timerActions.reset}>リセット</button>
                    <button className="btn primary grow" onClick={t.running ? timerActions.pause : timerActions.resume}>{t.running ? '一時停止' : '再開'}</button>
                  </>
                ) : (
                  <button className="btn primary block" onClick={timerActions.startInterval}>スタート（合計 {fmt((t.work * t.rounds + t.rest * (t.rounds - 1)) * 1000)}）</button>
                )}
              </div>
            </>
          )}

          {tab === 'stopwatch' && (
            <>
              <div className="row">
                {!started ? (
                  <button className="btn primary block" onClick={timerActions.startStopwatch}>スタート</button>
                ) : (
                  <>
                    <button className="btn grow" onClick={t.running ? timerActions.lap : timerActions.reset}>{t.running ? 'ラップ' : 'リセット'}</button>
                    <button className="btn primary grow" onClick={t.running ? timerActions.pause : timerActions.resume}>{t.running ? '停止' : '再開'}</button>
                  </>
                )}
              </div>
              {isCurrent && t.laps.length > 0 && (
                <div className="card" style={{ marginTop: 12 }}>
                  {t.laps.map((l, i) => (
                    <div key={i} className="list-item">
                      <span className="sub grow">ラップ {i + 1}</span>
                      <span className="sub">+{fmt(l - (t.laps[i - 1] ?? 0), true)}</span>
                      <b style={{ marginLeft: 12, fontVariantNumeric: 'tabular-nums' }}>{fmt(l, true)}</b>
                    </div>
                  )).reverse()}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}
