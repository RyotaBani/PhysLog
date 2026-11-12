import { useEffect, useState, type ReactNode } from 'react'
import type React from 'react'
import { addDays, labelDate, parseNum, todayKey } from '../lib/format'

export function Sheet(props: {
  title: string
  onClose: () => void
  onSave?: () => void
  saveLabel?: string
  canSave?: boolean
  onDelete?: () => void
  children: ReactNode
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') props.onClose()
      if (e.key === 'Enter' && (e.metaKey || e.ctrlKey) && props.onSave && props.canSave !== false) props.onSave()
    }
    window.addEventListener('keydown', onKey)
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = ''
    }
  }, [props])
  return (
    <div className="sheet-bg" onClick={props.onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={props.title}>
        <div className="sheet-h">
          <button className="btn" onClick={props.onClose}>閉じる</button>
          <h3>{props.title}</h3>
          {props.onDelete ? (
            <button className="btn danger" onClick={props.onDelete}>削除</button>
          ) : (
            <span style={{ width: 64 }} />
          )}
        </div>
        <div className="sheet-b">{props.children}</div>
        {props.onSave && (
          <div className="sheet-f">
            <button className="btn primary block" disabled={props.canSave === false} onClick={props.onSave}>
              {props.saveLabel ?? '保存'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

/** 単位付きの数値入力。前回値をプレースホルダに出す */
export function UnitInput(props: {
  value: string
  onChange: (v: string) => void
  unit: string
  placeholder?: string
  autoFocus?: boolean
}) {
  return (
    <div className="unit-input">
      <input
        inputMode="decimal"
        value={props.value}
        placeholder={props.placeholder}
        autoFocus={props.autoFocus}
        onChange={(e) => props.onChange(e.target.value)}
      />
      <span>{props.unit}</span>
    </div>
  )
}

/** −/＋ で刻める数値入力（重量・回数用） */
export function Stepper(props: {
  value?: number
  onChange: (v: number | undefined) => void
  step: number
  unit: string
  min?: number
}) {
  const [text, setText] = useState(props.value == null ? '' : String(props.value))
  useEffect(() => {
    setText(props.value == null ? '' : String(props.value))
  }, [props.value])
  const bump = (d: number) => {
    const next = Math.max(props.min ?? 0, Math.round(((props.value ?? 0) + d) * 100) / 100)
    props.onChange(next)
  }
  return (
    <div className="stepper">
      <button type="button" onClick={() => bump(-props.step)} aria-label="減らす">−</button>
      <input
        inputMode="decimal"
        value={text}
        onChange={(e) => {
          setText(e.target.value)
          props.onChange(parseNum(e.target.value))
        }}
        onFocus={(e) => e.target.select()}
      />
      <span className="u">{props.unit}</span>
      <button type="button" onClick={() => bump(props.step)} aria-label="増やす">＋</button>
    </div>
  )
}

/** 1〜5 の選択。もう一度押すと解除 */
export function Scale(props: {
  value?: number
  onChange: (v: number | undefined) => void
  colors: string[]
  low: string
  high: string
}) {
  return (
    <div>
      <div className="scale">
        {[1, 2, 3, 4, 5].map((i) => {
          const on = props.value === i
          return (
            <button
              key={i}
              type="button"
              style={on ? { background: props.colors[i - 1], color: '#fff' } : undefined}
              onClick={() => props.onChange(on ? undefined : i)}
            >
              {i}
            </button>
          )
        })}
      </div>
      <div className="scale-labels"><span>{props.low}</span><span>{props.high}</span></div>
    </div>
  )
}

export function Seg<T extends string>(props: { value: T; options: { id: T; label: string }[]; onChange: (v: T) => void }) {
  return (
    <div className="seg">
      {props.options.map((o) => (
        <button key={o.id} className={props.value === o.id ? 'on' : ''} onClick={() => props.onChange(o.id)}>
          {o.label}
        </button>
      ))}
    </div>
  )
}

export function DateNav(props: { value: string; onChange: (v: string) => void }) {
  const t = todayKey()
  return (
    <div className="date-nav">
      <button className="icon-btn" onClick={() => props.onChange(addDays(props.value, -1))} aria-label="前の日">‹</button>
      <div className="d">
        {labelDate(props.value)}
        <input type="date" value={props.value} max={t} onChange={(e) => e.target.value && props.onChange(e.target.value)} />
      </div>
      <button
        className="icon-btn"
        disabled={props.value >= t}
        style={props.value >= t ? { opacity: 0.3 } : undefined}
        onClick={() => props.onChange(addDays(props.value, 1))}
        aria-label="次の日"
      >›</button>
    </div>
  )
}

let toastSetter: ((s: string | null) => void) | null = null
export const toast = (s: string) => toastSetter?.(s)
export function ToastHost() {
  const [msg, setMsg] = useState<string | null>(null)
  useEffect(() => {
    toastSetter = setMsg
    return () => { toastSetter = null }
  }, [])
  useEffect(() => {
    if (!msg) return
    const t = setTimeout(() => setMsg(null), 1800)
    return () => clearTimeout(t)
  }, [msg])
  return msg ? <div className="toast">{msg}</div> : null
}

/** 2回押しで実行するボタン（confirm() が使えない環境でも動くように） */
export function ConfirmButton(props: { label: string; confirmLabel: string; onConfirm: () => void; className?: string; style?: React.CSSProperties }) {
  const [armed, setArmed] = useState(false)
  useEffect(() => {
    if (!armed) return
    const t = setTimeout(() => setArmed(false), 4000)
    return () => clearTimeout(t)
  }, [armed])
  return (
    <button
      className={props.className}
      style={{ ...props.style, ...(armed ? { background: 'var(--pink)', color: '#fff' } : {}) }}
      onClick={() => (armed ? (setArmed(false), props.onConfirm()) : setArmed(true))}
    >
      {armed ? props.confirmLabel : props.label}
    </button>
  )
}
