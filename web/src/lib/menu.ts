// iOS 版 MenuEngine.swift の移植（ルールエンジン。APIは使わない）
export type Goal = 'strength' | 'speed' | 'endurance' | 'fatLoss' | 'sports'
export type Level = 'beginner' | 'intermediate' | 'advanced'

export const GOALS: { id: Goal; label: string; icon: string; color: string; summary: string }[] = [
  { id: 'strength', label: '筋力・筋量UP', icon: '🏋️', color: '#0087ff', summary: '高重量・低〜中回数で筋力と筋断面積を伸ばします' },
  { id: 'speed', label: 'スピード・瞬発力', icon: '⚡', color: '#8f59f7', summary: '神経系と発揮スピードに刺激を入れます' },
  { id: 'endurance', label: '持久力UP', icon: '🫁', color: '#33c759', summary: '有酸素能力と乳酸閾値を引き上げます' },
  { id: 'fatLoss', label: '体脂肪を落とす', icon: '🔥', color: '#ff3b61', summary: '消費カロリーを稼ぎつつ筋量を維持します' },
  { id: 'sports', label: '競技パフォーマンス', icon: '🏀', color: '#ff9500', summary: '動きの再現性と切り返し能力を高めます' },
]

export const LEVELS: { id: Level; label: string; detail: string }[] = [
  { id: 'beginner', label: '初心者', detail: '〜6ヶ月' },
  { id: 'intermediate', label: '中級者', detail: '6ヶ月〜2年' },
  { id: 'advanced', label: '上級者', detail: '2年以上' },
]

export interface Item { name: string; sets: number; reps: string; rest: string; tip: string }
export interface Day { focus: string; items: Item[] }

const setCount = (base: number, l: Level) => (l === 'beginner' ? Math.max(base - 1, 2) : l === 'intermediate' ? base : base + 1)
const mainReps = (l: Level) => (l === 'beginner' ? '8〜10回' : l === 'intermediate' ? '6〜8回' : '3〜5回')
const mainRest = (l: Level) => (l === 'beginner' ? '90秒' : l === 'intermediate' ? '2分' : '3分')

export function buildMenu(goal: Goal, level: Level, days: number): (Day & { label: string })[] {
  const pool = { strength, speed, endurance, fatLoss, sports }[goal](level)
  return Array.from({ length: days }, (_, i) => ({ label: `Day ${i + 1}`, ...pool[i % pool.length] }))
}

function strength(level: Level): Day[] {
        const s = setCount(4, level)
        const reps = mainReps(level)
        const rest = mainRest(level)

        return [
            { focus: "プッシュ（胸・肩・三頭）", items: [
                { name: "ベンチプレス", sets: s, reps: reps, rest: rest, tip: "肩甲骨を寄せて下制。バーはみぞおち付近に下ろす" },
                { name: "インクラインダンベルプレス", sets: s - 1, reps: "8〜12回", rest: "90秒", tip: "胸の上部を狙う。肘は開きすぎない" },
                { name: "ショルダープレス", sets: s - 1, reps: "8〜12回", rest: "90秒", tip: "腰を反らせず、体幹を固めて真上に押す" },
                { name: "サイドレイズ", sets: 3, reps: "12〜15回", rest: "60秒", tip: "軽い重量で構わない。反動を使わない" },
                { name: "プレスダウン", sets: 3, reps: "10〜15回", rest: "60秒", tip: "肘の位置を固定して伸展だけで動かす" },
            ]},
            { focus: "プル（背中・二頭）", items: [
                { name: "デッドリフト", sets: s, reps: reps, rest: rest, tip: "腰を丸めない。股関節から折りたたむ意識" },
                { name: "懸垂 / ラットプルダウン", sets: s - 1, reps: "8〜12回", rest: "90秒", tip: "肩をすくめず、肩甲骨を下げてから引く" },
                { name: "ベントオーバーロウ", sets: s - 1, reps: "8〜12回", rest: "90秒", tip: "上体は45度前後。みぞおちに向けて引く" },
                { name: "フェイスプル", sets: 3, reps: "15回", rest: "60秒", tip: "肩の後面を鍛えて姿勢と怪我予防に" },
                { name: "ダンベルカール", sets: 3, reps: "10〜12回", rest: "60秒", tip: "下ろす動作を2〜3秒かけてコントロール" },
            ]},
            { focus: "レッグ（脚・体幹）", items: [
                { name: "バーベルスクワット", sets: s, reps: reps, rest: rest, tip: "膝とつま先の向きを揃える。最低でも太腿が床と平行まで" },
                { name: "ルーマニアンデッドリフト", sets: s - 1, reps: "8〜12回", rest: "90秒", tip: "ハムストリングスの伸びを感じる範囲で止める" },
                { name: "レッグプレス", sets: 3, reps: "10〜15回", rest: "90秒", tip: "膝を完全にロックさせない" },
                { name: "カーフレイズ", sets: 3, reps: "15〜20回", rest: "45秒", tip: "可動域を大きく。最上部で1秒止める" },
                { name: "プランク", sets: 3, reps: "40〜60秒", rest: "45秒", tip: "頭からかかとまで一直線をキープ" },
            ]},
        ]
}

function speed(level: Level): Day[] {
        const s = setCount(4, level)

        return [
            { focus: "スプリント（加速局面）", items: [
                { name: "ダイナミックストレッチ", sets: 1, reps: "10分", rest: "—", tip: "股関節と足首を中心に可動域を広げる" },
                { name: "加速走 20〜30m", sets: s + 2, reps: "1本", rest: "3分", tip: "完全回復してから次の1本。質を最優先" },
                { name: "スレッドプッシュ / 坂道ダッシュ", sets: s, reps: "20m", rest: "2〜3分", tip: "前傾を保ったまま地面を後方に押す" },
                { name: "ノルディックハムストリング", sets: 3, reps: "5〜8回", rest: "2分", tip: "肉離れ予防に有効。ゆっくり耐える" },
            ]},
            { focus: "プライオメトリクス", items: [
                { name: "ボックスジャンプ", sets: s, reps: "5回", rest: "90秒", tip: "着地は静かに。膝を内側に入れない" },
                { name: "デプスジャンプ", sets: s, reps: "5回", rest: "2分", tip: "接地時間を最短に。上級者向けなので段階的に" },
                { name: "バウンディング", sets: 3, reps: "20m", rest: "90秒", tip: "1歩を大きく。前方への推進力を意識" },
                { name: "メディシンボールスロー", sets: 4, reps: "5回", rest: "90秒", tip: "下半身から生まれた力を上半身に伝える" },
            ]},
            { focus: "パワー系ウェイト", items: [
                { name: "ハングクリーン", sets: s, reps: "3回", rest: "3分", tip: "重量よりフォーム優先。爆発的に引き上げる" },
                { name: "ジャンプスクワット（軽重量）", sets: s, reps: "5回", rest: "2分", tip: "体重の20〜30%程度。速度が落ちたら終了" },
                { name: "ヒップスラスト", sets: 4, reps: "6〜8回", rest: "2分", tip: "股関節の伸展力はスプリント速度に直結する" },
                { name: "片脚バランスドリル", sets: 3, reps: "30秒", rest: "45秒", tip: "着地の安定性を高めて怪我を防ぐ" },
            ]},
        ]
}

function endurance(level: Level): Day[] {
        const intervalSets = level === 'beginner' ? 4 : level === 'intermediate' ? 6 : 8

        return [
            { focus: "LSD（低強度長時間）", items: [
                { name: "ジョギング", sets: 1, reps: "40〜60分", rest: "—", tip: "会話ができるペース。心拍は最大の60〜70%" },
                { name: "クールダウンストレッチ", sets: 1, reps: "10分", rest: "—", tip: "ふくらはぎ・ハム・股関節を丁寧に" },
            ]},
            { focus: "インターバル", items: [
                { name: "ウォームアップジョグ", sets: 1, reps: "10分", rest: "—", tip: "徐々にペースを上げて体温を上げる" },
                { name: "400mラン", sets: intervalSets, reps: "80〜90%強度", rest: "同距離ジョグ", tip: "全本数を同じタイムで揃えることを目標に" },
                { name: "クールダウンジョグ", sets: 1, reps: "10分", rest: "—", tip: "心拍を徐々に下げて回復を促す" },
            ]},
            { focus: "テンポ走＋筋持久力", items: [
                { name: "テンポラン", sets: 1, reps: "20〜30分", rest: "—", tip: "ややきついが持続できるペース。乳酸閾値を狙う" },
                { name: "スクワット（軽重量高回数）", sets: 3, reps: "15〜20回", rest: "45秒", tip: "フォームが崩れない範囲で回数を重ねる" },
                { name: "プランク", sets: 3, reps: "60秒", rest: "45秒", tip: "走行フォームを支える体幹を強化" },
            ]},
        ]
}

function fatLoss(level: Level): Day[] {
        const circuits = setCount(4, level)

        return [
            { focus: "サーキット（全身）", items: [
                { name: "バーピー", sets: circuits, reps: "12回", rest: "30秒", tip: "全身を使うため消費カロリーが大きい" },
                { name: "ジャンプスクワット", sets: circuits, reps: "15回", rest: "30秒", tip: "着地を柔らかく。膝への負担を減らす" },
                { name: "マウンテンクライマー", sets: circuits, reps: "20回", rest: "30秒", tip: "腰が上がらないよう体幹を締める" },
                { name: "プッシュアップ", sets: circuits, reps: "10〜15回", rest: "60秒", tip: "1周したら60秒休んで次のセットへ" },
            ]},
            { focus: "HIIT", items: [
                { name: "スプリント or バイク", sets: 8, reps: "20秒全力", rest: "10秒", tip: "タバタ式。合計4分でも効果は高い" },
                { name: "ケトルベルスイング", sets: 4, reps: "15回", rest: "45秒", tip: "腕で持ち上げず股関節の伸展で振る" },
                { name: "ウォーキング", sets: 1, reps: "15分", rest: "—", tip: "終了後の低強度有酸素で脂肪燃焼を後押し" },
            ]},
            { focus: "筋量維持（レジスタンス）", items: [
                { name: "スクワット", sets: 3, reps: "12〜15回", rest: "60秒", tip: "減量中こそ筋量維持が基礎代謝を守る" },
                { name: "ベンチプレス", sets: 3, reps: "12〜15回", rest: "60秒", tip: "重量は落としすぎず、刺激を維持する" },
                { name: "ラットプルダウン", sets: 3, reps: "12〜15回", rest: "60秒", tip: "背中の筋量を保って見た目も引き締める" },
                { name: "アブローラー", sets: 3, reps: "10回", rest: "60秒", tip: "腰を反らさない範囲で転がす" },
            ]},
        ]
}

function sports(level: Level): Day[] {
        const s = setCount(4, level)

        return [
            { focus: "パワー", items: [
                { name: "ハングクリーン", sets: s, reps: "3〜5回", rest: "2〜3分", tip: "全身の連動を鍛える。フォーム最優先" },
                { name: "ボックスジャンプ", sets: 4, reps: "5回", rest: "90秒", tip: "高さより着地の質を重視" },
                { name: "スクワット（爆発的に挙上）", sets: s, reps: "5回", rest: "2分", tip: "下ろすのはゆっくり、上げるのは全力で" },
            ]},
            { focus: "アジリティ（方向転換）", items: [
                { name: "ラダードリル", sets: 4, reps: "30秒", rest: "60秒", tip: "最初は正確さ、慣れたらスピードを上げる" },
                { name: "Tドリル", sets: 4, reps: "1往復", rest: "90秒", tip: "切り返しでは重心を低く保つ" },
                { name: "サイドシャッフル", sets: 3, reps: "20m", rest: "60秒", tip: "足をクロスさせず、常に構えを維持" },
                { name: "片脚ホップ", sets: 3, reps: "10m", rest: "90秒", tip: "着地の安定性が怪我予防につながる" },
            ]},
            { focus: "基礎筋力", items: [
                { name: "デッドリフト", sets: s, reps: "5回", rest: "3分", tip: "後方の筋群はほぼ全競技で土台になる" },
                { name: "ブルガリアンスクワット", sets: 3, reps: "8回（片脚）", rest: "90秒", tip: "左右差を把握して弱い側を丁寧に" },
                { name: "懸垂", sets: 4, reps: "限界まで", rest: "2分", tip: "上半身の引く力と体幹の安定性を同時に" },
                { name: "パロフプレス", sets: 3, reps: "10回（左右）", rest: "60秒", tip: "回旋に耐える体幹は接触プレーで効く" },
            ]},
        ]
}
