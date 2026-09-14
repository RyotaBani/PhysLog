import Foundation
import SwiftData

// MARK: - トレーニングセッション（1日分）

@Model
final class TrainingSession {
    var date: Date = Date()
    var sport: String = ""
    var memo: String = ""

    /// トレーニングした場所。
    /// Gym への参照ではなく名前で持つ。ジム登録を消しても
    /// 過去の記録が壊れないようにするため。
    var gymName: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TrainingSet.session)
    var exercises: [TrainingSet]? = []

    init(date: Date = Date(), sport: String = "", memo: String = "", gymName: String = "") {
        self.date = date
        self.sport = sport
        self.memo = memo
        self.gymName = gymName
        self.exercises = []
    }

    /// 表示順に並べた種目リスト
    var sortedExercises: [TrainingSet] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var exerciseCount: Int { exercises?.count ?? 0 }

    /// 総ボリューム = Σ(各セットの 重量 × 回数)
    var totalVolume: Double {
        (exercises ?? []).reduce(0) { $0 + $1.volume }
    }

    var displayTitle: String {
        sport.isEmpty ? "トレーニング" : sport
    }
}

// MARK: - 種目1件

@Model
final class TrainingSet {
    var exercise: String = ""
    var order: Int = 0

    var session: TrainingSession?

    /// セットごとの重量・回数。
    ///
    /// ウォームアップから本番へ重量を上げていく記録に対応するため、
    /// セット単位で持つ。空の場合は下の旧フィールドから組み立てる。
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exerciseSet)
    var entries: [SetEntry]? = []

    // MARK: 旧フィールド（v1.1 以前の記録用）
    //
    // 「重量 × 回数 × セット数」で1行にまとめていた頃のデータ。
    // 消すと過去の記録が失われるため残している。
    // entries が空のときだけ参照される。

    var weight: Double?
    var reps: Int?
    var sets: Int?

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
        self.entries = []
    }

    /// セット一覧。旧形式の記録は、同じ内容をセット数ぶん並べたものとして扱う。
    var resolvedSets: [(weight: Double?, reps: Int?)] {
        let list = (entries ?? []).sorted { $0.order < $1.order }
        if !list.isEmpty {
            return list.map { ($0.weight, $0.reps) }
        }
        // 旧形式からの復元
        guard let count = sets, count > 0 else {
            return (weight == nil && reps == nil) ? [] : [(weight, reps)]
        }
        return Array(repeating: (weight, reps), count: count)
    }

    /// セットごとの重量が揃っているか。
    /// 揃っていれば "60kg × 10回 × 3セット" と短く書ける。
    var isUniform: Bool {
        let list = resolvedSets
        guard let first = list.first else { return true }
        return list.allSatisfy { $0.weight == first.weight && $0.reps == first.reps }
    }

    /// 揃っていれば "60kg × 10回 × 3セット"
    /// バラバラなら "20kg×10 / 40kg×5 / 60kg×3"
    var summary: String {
        let list = resolvedSets
        guard !list.isEmpty else { return "—" }

        if isUniform, let first = list.first {
            var parts: [String] = []
            if let w = first.weight { parts.append(fmtWeight(w)) }
            if let r = first.reps { parts.append("\(r)回") }
            if list.count > 1 { parts.append("\(list.count)セット") }
            return parts.isEmpty ? "—" : parts.joined(separator: " × ")
        }

        return list.map { entry in
            var s = ""
            if let w = entry.weight { s += fmtWeight(w) }
            if let r = entry.reps { s += s.isEmpty ? "\(r)回" : "×\(r)" }
            return s.isEmpty ? "—" : s
        }.joined(separator: " / ")
    }

    var volume: Double {
        resolvedSets.reduce(0) { sum, entry in
            guard let w = entry.weight, let r = entry.reps else { return sum }
            return sum + w * Double(r)
        }
    }

    private func fmtWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w))kg" : String(format: "%.1fkg", w)
    }
}

// MARK: - セット1本分

@Model
final class SetEntry {
    var weight: Double?
    var reps: Int?
    var order: Int = 0

    var exerciseSet: TrainingSet?

    init(weight: Double? = nil, reps: Int? = nil, order: Int = 0) {
        self.weight = weight
        self.reps = reps
        self.order = order
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
