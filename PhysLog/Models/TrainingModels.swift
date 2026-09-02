import Foundation
import SwiftData

// MARK: - トレーニングセッション（1日分）

@Model
final class TrainingSession {
    var date: Date = Date()
    var sport: String = ""
    var memo: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TrainingSet.session)
    var exercises: [TrainingSet]? = []

    init(date: Date = Date(), sport: String = "", memo: String = "") {
        self.date = date
        self.sport = sport
        self.memo = memo
        self.exercises = []
    }

    /// 表示順に並べた種目リスト
    var sortedExercises: [TrainingSet] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var exerciseCount: Int { exercises?.count ?? 0 }

    /// 総ボリューム = Σ(重量 × 回数 × セット数)
    var totalVolume: Double {
        (exercises ?? []).reduce(0) { sum, set in
            guard let w = set.weight, let r = set.reps, let s = set.sets else { return sum }
            return sum + w * Double(r) * Double(s)
        }
    }

    var displayTitle: String {
        sport.isEmpty ? "トレーニング" : sport
    }
}

// MARK: - 種目1件

@Model
final class TrainingSet {
    var exercise: String = ""
    var weight: Double?      // kg（自重種目は nil）
    var reps: Int?           // 回数
    var sets: Int?           // セット数
    var order: Int = 0

    var session: TrainingSession?

    init(
        exercise: String,
        weight: Double? = nil,
        reps: Int? = nil,
        sets: Int? = nil,
        order: Int = 0
    ) {
        self.exercise = exercise
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.order = order
    }

    /// "60.0kg × 10回 × 3セット" の形式
    var summary: String {
        var parts: [String] = []
        if let w = weight { parts.append(String(format: "%.1fkg", w)) }
        if let r = reps { parts.append("\(r)回") }
        if let s = sets { parts.append("\(s)セット") }
        return parts.isEmpty ? "—" : parts.joined(separator: " × ")
    }

    var volume: Double {
        guard let w = weight, let r = reps, let s = sets else { return 0 }
        return w * Double(r) * Double(s)
    }
}

// MARK: - 種目プリセット

enum ExerciseLibrary {
    static let byCategory: [(category: String, items: [String])] = [
        ("胸",     ["ベンチプレス", "インクラインベンチプレス", "ダンベルプレス", "ダンベルフライ", "チェストプレス", "プッシュアップ"]),
        ("背中",   ["デッドリフト", "懸垂", "ラットプルダウン", "ベントオーバーロウ", "シーテッドロウ"]),
        ("肩",     ["ショルダープレス", "サイドレイズ", "フロントレイズ", "リアレイズ", "フェイスプル"]),
        ("腕",     ["バーベルカール", "ダンベルカール", "ハンマーカール", "プレスダウン", "ディップス"]),
        ("脚",     ["スクワット", "レッグプレス", "ランジ", "ブルガリアンスクワット", "レッグカール", "レッグエクステンション", "カーフレイズ"]),
        ("体幹",   ["プランク", "クランチ", "レッグレイズ", "ロシアンツイスト", "アブローラー"]),
        ("有酸素", ["ランニング", "バイク", "縄跳び", "バーピー", "ケトルベルスイング"]),
    ]

    static let flat: [String] = byCategory.flatMap { $0.items }

    static let sports: [String] = [
        "ウェイトトレーニング", "バスケットボール", "サッカー", "野球",
        "バレーボール", "陸上", "水泳", "テニス", "ランニング", "その他"
    ]
}
