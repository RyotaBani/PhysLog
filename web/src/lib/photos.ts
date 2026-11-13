// 体の写真は IndexedDB に端末内保存する（外部へは送らない）。
// 一覧用の情報（日付・向き・メモ）は通常の記録と一緒に localStorage、画像本体だけ IndexedDB。

const DB = 'physlog-photos'
const STORE = 'images'

function open(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB, 1)
    req.onupgradeneeded = () => req.result.createObjectStore(STORE)
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

async function tx<T>(mode: IDBTransactionMode, fn: (s: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const db = await open()
  return new Promise((resolve, reject) => {
    const r = fn(db.transaction(STORE, mode).objectStore(STORE))
    r.onsuccess = () => resolve(r.result)
    r.onerror = () => reject(r.error)
  })
}

export const putImage = (id: string, blob: Blob) => tx('readwrite', (s) => s.put(blob, id))
export const getImage = (id: string) => tx<Blob | undefined>('readonly', (s) => s.get(id))
export const deleteImage = (id: string) => tx('readwrite', (s) => s.delete(id))

/** 長辺を maxSide に縮めて JPEG にする（容量を抑える） */
export async function shrink(file: File, maxSide = 1400): Promise<Blob> {
  const url = URL.createObjectURL(file)
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const i = new Image()
      i.onload = () => resolve(i)
      i.onerror = reject
      i.src = url
    })
    const scale = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight))
    const c = document.createElement('canvas')
    c.width = Math.round(img.naturalWidth * scale)
    c.height = Math.round(img.naturalHeight * scale)
    c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height)
    return await new Promise<Blob>((resolve, reject) => c.toBlob((b) => (b ? resolve(b) : reject(new Error('変換失敗'))), 'image/jpeg', 0.85))
  } finally {
    URL.revokeObjectURL(url)
  }
}

/** 撮影日時（EXIF）が読めなければファイルの更新日 */
export function fileDate(file: File) {
  const d = new Date(file.lastModified || Date.now())
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}
