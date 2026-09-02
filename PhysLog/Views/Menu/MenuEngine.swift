import SwiftUI

// MARK: - 入力条件

enum TrainingGoal: String, CaseIterable, Identifiable {
    case strength  = "筋力・筋量UP"
    case speed     = "スピード・瞬発力"
    case endurance = "持久力UP"
    case fatLoss   = "体脂肪を落とす"
    case sports    = "競技パフォーマンス"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .strength:  return "dumbbell.fill"
        case .speed:     return "bolt.fill"
        case .endurance: return "lungs.fill"
        case .fatLoss:   return "flame.fill"
        case .sports:    return "sportscourt.fill"
        }
    }

    var color: Color {
        switch self {
        case .strength:  return .physlogPrimary
        case .speed:     return .physlogPurple
        case .endurance: return .physlogAccent
        case .fatLoss:   return .physlogPink
        case .sports:    return .physlogOrange
        }
    }

    var summary: String {
        switch self {
        case .strength:  return "高重量・低〜中回数で筋力と筋断面積を伸ばします"
        case .speed:     return "神経系と発揮スピードに刺激を入れます"
        case .endurance: return "有酸素能力と乳酸閾値を引き上げます"
        case .fatLoss:   return "消費カロリーを稼ぎつつ筋量を維持します"
        case .sports:    return "動きの再現性と切り返し能力を高めます"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Identifiable {
    case beginner     = "初心者"
    case intermediate = "中級者"
    case advanced     = "上級者"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .beginner:     return "〜6ヶ月"
        case .intermediate: return "6ヶ月〜2年"
        case .advanced:     return "2年以上"
        }
    }
}

// MARK: - 出力

struct MenuItem: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: String
    let rest: String
    let tip: String
}

struct MenuDay: Identifiable {
    let id = UUID()
    let label: String
    let focus: String
    let items: [MenuItem]
}

// MARK: - ルールエンジン

enum MenuEngine {

    static func build(goal: TrainingGoal, level: ExperienceLevel, days: Int) -> [MenuDay] {
        let pool = template(for: goal, level: level)
        // 週の日数に合わせてローテーションを組む
        return (0..<days).map { index in
            let source = pool[index % pool.count]
            return MenuDay(
                label: "Day \(index + 1)",
                focus: source.focus,
                items: source.items
            )
        }
    }

    /// 経験レベルに応じたセット数の補正
    private static func setCount(_ base: Int, _ level: ExperienceLevel) -> Int {
        switch level {
        case .beginner:     return max(base - 1, 2)
        case .intermediate: return base
        case .advanced:     return base + 1
        }
    }

    /// レベルに応じた主要種目のレップ範囲
    private static func mainReps(_ level: ExperienceLevel) -> String {
        switch level {
        case .beginner:     return "8〜10回"
        case .intermediate: return "6〜8回"
        case .advanced:     return "3〜5回"
        }
    }

    private static func mainRest(_ level: ExperienceLevel) -> String {
        switch level {
        case .beginner:     return "90秒"
        case .intermediate: return "2分"
        case .advanced:     return "3分"
        }
    }

    // MARK: テンプレート

    private static func template(for goal: TrainingGoal, level: ExperienceLevel) -> [MenuDay] {
        switch goal {
        case .strength:  return strength(level)
        case .speed:     return speed(level)
        case .endurance: return endurance(level)
        case .fatLoss:   return fatLoss(level)
        case .sports:    return sports(level)
        }
    }

    // MARK: 筋力・筋量

    private static func strength(_ level: ExperienceLevel) -> [MenuDay] {
        let s = setCount(4, level)
        let reps = mainReps(level)
        let rest = mainRest(level)

        return [
            MenuDay(label: "", focus: "プッシュ（胸・肩・三頭）", items: [
                MenuItem(name: "ベンチプレス", sets: s, reps: reps, rest: rest,
                         tip: "肩甲骨を寄せて下制。バーはみぞおち付近に下ろす"),
                MenuItem(name: "インクラインダンベルプレス", sets: s - 1, reps: "8〜12回", rest: "90秒",
                         tip: "胸の上部を狙う。肘は開きすぎない"),
                MenuItem(name: "ショルダープレス", sets: s - 1, reps: "8〜12回", rest: "90秒",
                         tip: "腰を反らせず、体幹を固めて真上に押す"),
                MenuItem(name: "サイドレイズ", sets: 3, reps: "12〜15回", rest: "60秒",
                         tip: "軽い重量で構わない。反動を使わない"),
                MenuItem(name: "プレスダウン", sets: 3, reps: "10〜15回", rest: "60秒",
                         tip: "肘の位置を固定して伸展だけで動かす"),
            ]),
            MenuDay(label: "", focus: "プル（背中・二頭）", items: [
                MenuItem(name: "デッドリフト", sets: s, reps: reps, rest: rest,
                         tip: "腰を丸めない。股関節から折りたたむ意識"),
                MenuItem(name: "懸垂 / ラットプルダウン", sets: s - 1, reps: "8〜12回", rest: "90秒",
                         tip: "肩をすくめず、肩甲骨を下げてから引く"),
                MenuItem(name: "ベントオーバーロウ", sets: s - 1, reps: "8〜12回", rest: "90秒",
                         tip: "上体は45度前後。みぞおちに向けて引く"),
                MenuItem(name: "フェイスプル", sets: 3, reps: "15回", rest: "60秒",
                         tip: "肩の後面を鍛えて姿勢と怪我予防に"),
                MenuItem(name: "ダンベルカール", sets: 3, reps: "10〜12回", rest: "60秒",
                         tip: "下ろす動作を2〜3秒かけてコントロール"),
            ]),
            MenuDay(label: "", focus: "レッグ（脚・体幹）", items: [
                MenuItem(name: "バーベルスクワット", sets: s, reps: reps, rest: rest,
                         tip: "膝とつま先の向きを揃える。最低でも太腿が床と平行まで"),
                MenuItem(name: "ルーマニアンデッドリフト", sets: s - 1, reps: "8〜12回", rest: "90秒",
                         tip: "ハムストリングスの伸びを感じる範囲で止める"),
                MenuItem(name: "レッグプレス", sets: 3, reps: "10〜15回", rest: "90秒",
                         tip: "膝を完全にロックさせない"),
                MenuItem(name: "カーフレイズ", sets: 3, reps: "15〜20回", rest: "45秒",
                         tip: "可動域を大きく。最上部で1秒止める"),
                MenuItem(name: "プランク", sets: 3, reps: "40〜60秒", rest: "45秒",
                         tip: "頭からかかとまで一直線をキープ"),
            ]),
        ]
    }

    // MARK: スピード・瞬発力

    private static func speed(_ level: ExperienceLevel) -> [MenuDay] {
        let s = setCount(4, level)

        return [
            MenuDay(label: "", focus: "スプリント（加速局面）", items: [
                MenuItem(name: "ダイナミックストレッチ", sets: 1, reps: "10分", rest: "—",
                         tip: "股関節と足首を中心に可動域を広げる"),
                MenuItem(name: "加速走 20〜30m", sets: s + 2, reps: "1本", rest: "3分",
                         tip: "完全回復してから次の1本。質を最優先"),
                MenuItem(name: "スレッドプッシュ / 坂道ダッシュ", sets: s, reps: "20m", rest: "2〜3分",
                         tip: "前傾を保ったまま地面を後方に押す"),
                MenuItem(name: "ノルディックハムストリング", sets: 3, reps: "5〜8回", rest: "2分",
                         tip: "肉離れ予防に有効。ゆっくり耐える"),
            ]),
            MenuDay(label: "", focus: "プライオメトリクス", items: [
                MenuItem(name: "ボックスジャンプ", sets: s, reps: "5回", rest: "90秒",
                         tip: "着地は静かに。膝を内側に入れない"),
                MenuItem(name: "デプスジャンプ", sets: s, reps: "5回", rest: "2分",
                         tip: "接地時間を最短に。上級者向けなので段階的に"),
                MenuItem(name: "バウンディング", sets: 3, reps: "20m", rest: "90秒",
                         tip: "1歩を大きく。前方への推進力を意識"),
                MenuItem(name: "メディシンボールスロー", sets: 4, reps: "5回", rest: "90秒",
                         tip: "下半身から生まれた力を上半身に伝える"),
            ]),
            MenuDay(label: "", focus: "パワー系ウェイト", items: [
                MenuItem(name: "ハングクリーン", sets: s, reps: "3回", rest: "3分",
                         tip: "重量よりフォーム優先。爆発的に引き上げる"),
                MenuItem(name: "ジャンプスクワット（軽重量）", sets: s, reps: "5回", rest: "2分",
                         tip: "体重の20〜30%程度。速度が落ちたら終了"),
                MenuItem(name: "ヒップスラスト", sets: 4, reps: "6〜8回", rest: "2分",
                         tip: "股関節の伸展力はスプリント速度に直結する"),
                MenuItem(name: "片脚バランスドリル", sets: 3, reps: "30秒", rest: "45秒",
                         tip: "着地の安定性を高めて怪我を防ぐ"),
            ]),
        ]
    }

    // MARK: 持久力

    private static func endurance(_ level: ExperienceLevel) -> [MenuDay] {
        let intervalSets: Int = {
            switch level {
            case .beginner: return 4
            case .intermediate: return 6
            case .advanced: return 8
            }
        }()

        return [
            MenuDay(label: "", focus: "LSD（低強度長時間）", items: [
                MenuItem(name: "ジョギング", sets: 1, reps: "40〜60分", rest: "—",
                         tip: "会話ができるペース。心拍は最大の60〜70%"),
                MenuItem(name: "クールダウンストレッチ", sets: 1, reps: "10分", rest: "—",
                         tip: "ふくらはぎ・ハム・股関節を丁寧に"),
            ]),
            MenuDay(label: "", focus: "インターバル", items: [
                MenuItem(name: "ウォームアップジョグ", sets: 1, reps: "10分", rest: "—",
                         tip: "徐々にペースを上げて体温を上げる"),
                MenuItem(name: "400mラン", sets: intervalSets, reps: "80〜90%強度", rest: "同距離ジョグ",
                         tip: "全本数を同じタイムで揃えることを目標に"),
                MenuItem(name: "クールダウンジョグ", sets: 1, reps: "10分", rest: "—",
                         tip: "心拍を徐々に下げて回復を促す"),
            ]),
            MenuDay(label: "", focus: "テンポ走＋筋持久力", items: [
                MenuItem(name: "テンポラン", sets: 1, reps: "20〜30分", rest: "—",
                         tip: "ややきついが持続できるペース。乳酸閾値を狙う"),
                MenuItem(name: "スクワット（軽重量高回数）", sets: 3, reps: "15〜20回", rest: "45秒",
                         tip: "フォームが崩れない範囲で回数を重ねる"),
                MenuItem(name: "プランク", sets: 3, reps: "60秒", rest: "45秒",
                         tip: "走行フォームを支える体幹を強化"),
            ]),
        ]
    }

    // MARK: 体脂肪を落とす

    private static func fatLoss(_ level: ExperienceLevel) -> [MenuDay] {
        let circuits = setCount(4, level)

        return [
            MenuDay(label: "", focus: "サーキット（全身）", items: [
                MenuItem(name: "バーピー", sets: circuits, reps: "12回", rest: "30秒",
                         tip: "全身を使うため消費カロリーが大きい"),
                MenuItem(name: "ジャンプスクワット", sets: circuits, reps: "15回", rest: "30秒",
                         tip: "着地を柔らかく。膝への負担を減らす"),
                MenuItem(name: "マウンテンクライマー", sets: circuits, reps: "20回", rest: "30秒",
                         tip: "腰が上がらないよう体幹を締める"),
                MenuItem(name: "プッシュアップ", sets: circuits, reps: "10〜15回", rest: "60秒",
                         tip: "1周したら60秒休んで次のセットへ"),
            ]),
            MenuDay(label: "", focus: "HIIT", items: [
                MenuItem(name: "スプリント or バイク", sets: 8, reps: "20秒全力", rest: "10秒",
                         tip: "タバタ式。合計4分でも効果は高い"),
                MenuItem(name: "ケトルベルスイング", sets: 4, reps: "15回", rest: "45秒",
                         tip: "腕で持ち上げず股関節の伸展で振る"),
                MenuItem(name: "ウォーキング", sets: 1, reps: "15分", rest: "—",
                         tip: "終了後の低強度有酸素で脂肪燃焼を後押し"),
            ]),
            MenuDay(label: "", focus: "筋量維持（レジスタンス）", items: [
                MenuItem(name: "スクワット", sets: 3, reps: "12〜15回", rest: "60秒",
                         tip: "減量中こそ筋量維持が基礎代謝を守る"),
                MenuItem(name: "ベンチプレス", sets: 3, reps: "12〜15回", rest: "60秒",
                         tip: "重量は落としすぎず、刺激を維持する"),
                MenuItem(name: "ラットプルダウン", sets: 3, reps: "12〜15回", rest: "60秒",
                         tip: "背中の筋量を保って見た目も引き締める"),
                MenuItem(name: "アブローラー", sets: 3, reps: "10回", rest: "60秒",
                         tip: "腰を反らさない範囲で転がす"),
            ]),
        ]
    }

    // MARK: 競技パフォーマンス

    private static func sports(_ level: ExperienceLevel) -> [MenuDay] {
        let s = setCount(4, level)

        return [
            MenuDay(label: "", focus: "パワー", items: [
                MenuItem(name: "ハングクリーン", sets: s, reps: "3〜5回", rest: "2〜3分",
                         tip: "全身の連動を鍛える。フォーム最優先"),
                MenuItem(name: "ボックスジャンプ", sets: 4, reps: "5回", rest: "90秒",
                         tip: "高さより着地の質を重視"),
                MenuItem(name: "スクワット（爆発的に挙上）", sets: s, reps: "5回", rest: "2分",
                         tip: "下ろすのはゆっくり、上げるのは全力で"),
            ]),
            MenuDay(label: "", focus: "アジリティ（方向転換）", items: [
                MenuItem(name: "ラダードリル", sets: 4, reps: "30秒", rest: "60秒",
                         tip: "最初は正確さ、慣れたらスピードを上げる"),
                MenuItem(name: "Tドリル", sets: 4, reps: "1往復", rest: "90秒",
                         tip: "切り返しでは重心を低く保つ"),
                MenuItem(name: "サイドシャッフル", sets: 3, reps: "20m", rest: "60秒",
                         tip: "足をクロスさせず、常に構えを維持"),
                MenuItem(name: "片脚ホップ", sets: 3, reps: "10m", rest: "90秒",
                         tip: "着地の安定性が怪我予防につながる"),
            ]),
            MenuDay(label: "", focus: "基礎筋力", items: [
                MenuItem(name: "デッドリフト", sets: s, reps: "5回", rest: "3分",
                         tip: "後方の筋群はほぼ全競技で土台になる"),
                MenuItem(name: "ブルガリアンスクワット", sets: 3, reps: "8回（片脚）", rest: "90秒",
                         tip: "左右差を把握して弱い側を丁寧に"),
                MenuItem(name: "懸垂", sets: 4, reps: "限界まで", rest: "2分",
                         tip: "上半身の引く力と体幹の安定性を同時に"),
                MenuItem(name: "パロフプレス", sets: 3, reps: "10回（左右）", rest: "60秒",
                         tip: "回旋に耐える体幹は接触プレーで効く"),
            ]),
        ]
    }
}
