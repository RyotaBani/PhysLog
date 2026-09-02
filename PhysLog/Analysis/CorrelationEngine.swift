import Foundation

// MARK: - 分析の入力となる変数

/// コンディション側（原因になりうる側）の変数
enum ConditionVariable: String, CaseIterable, Identifiable {
    case sleep     = "睡眠時間"
    case fatigue   = "疲労度"
    case condition = "体調"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .sleep:  return "時間"
        default:      return ""
        }
    }

    /// 値が大きいほど「良い状態」か。
    /// 疲労度・体調は 1 が良い側なので反転が必要になる。
    var higherIsBetter: Bool {
        switch self {
        case .sleep:  return true
        case .fatigue, .condition: return false
        }
    }

    func value(from record: ConditionRecord) -> Double? {
        switch self {
        case .sleep:     return record.sleepHours
        case .fatigue:   return record.fatigue.map(Double.init)
        case .condition: return record.condition.map(Double.init)
        }
    }
}

/// パフォーマンス側（結果になる側）の変数
enum PerformanceVariable: Identifiable, Hashable {
    case trainingVolume
    case ability(String)

    var id: String {
        switch self {
        case .trainingVolume:  return "__volume__"
        case .ability(let t):  return t
        }
    }

    var label: String {
        switch self {
        case .trainingVolume:  return "総挙上量"
        case .ability(let t):   return t
        }
    }
}

// MARK: - 分析結果

struct CorrelationResult: Identifiable {
    let id = UUID()
    let conditionVar: ConditionVariable
    let performanceVar: PerformanceVariable
    let points: [CorrelationPoint]
    /// ピアソンの積率相関係数（-1.0 〜 1.0）
    let coefficient: Double

    var sampleSize: Int { points.count }

    /// 相関の強さの区分
    var strength: Strength {
        switch abs(coefficient) {
        case 0.7...:     return .strong
        case 0.4..<0.7:  return .moderate
        case 0.2..<0.4:  return .weak
        default:         return .negligible
        }
    }

    enum Strength {
        case strong, moderate, weak, negligible

        var label: String {
            switch self {
            case .strong:     return "強い関係"
            case .moderate:   return "中程度の関係"
            case .weak:       return "弱い関係"
            case .negligible: return "ほぼ関係なし"
            }
        }
    }

    /// 「良い方向の関係」かどうか。
    /// 例: 疲労度は数値が小さいほど良いので、負の相関がパフォーマンス向上を意味する。
    var isFavorableDirection: Bool {
        conditionVar.higherIsBetter ? coefficient > 0 : coefficient < 0
    }

    /// 統計的に語れるだけのデータがあるか
    var hasEnoughData: Bool { sampleSize >= CorrelationEngine.minimumSampleSize }
}

struct CorrelationPoint: Identifiable {
    let id = UUID()
    let date: Date
    let conditionValue: Double
    let performanceValue: Double
}

/// 「睡眠7時間以上/未満」のような2群比較の結果。
/// 相関係数より直感的に伝わるため、文章化に使う。
struct GroupComparison {
    let thresholdLabel: String
    let highGroupMean: Double
    let lowGroupMean: Double
    let highGroupCount: Int
    let lowGroupCount: Int

    var difference: Double { highGroupMean - lowGroupMean }

    var percentDifference: Double {
        guard lowGroupMean != 0 else { return 0 }
        return (difference / lowGroupMean) * 100
    }

    var isReliable: Bool { highGroupCount >= 3 && lowGroupCount >= 3 }
}

// MARK: - 分析エンジン

enum CorrelationEngine {

    /// これ未満のデータ数では相関を提示しない。
    /// 少数のデータで相関を語ると、偶然の一致を法則のように見せてしまうため。
    static let minimumSampleSize = 8

    /// コンディション記録と同じ日のパフォーマンスを突き合わせる
    static func analyze(
        conditionVar: ConditionVariable,
        performanceVar: PerformanceVariable,
        conditions: [ConditionRecord],
        sessions: [TrainingSession],
        abilities: [PhysicalAbility]
    ) -> CorrelationResult {

        let calendar = Calendar.current

        // パフォーマンス値を「日付 → 値」に正規化する
        var performanceByDay: [Date: Double] = [:]

        switch performanceVar {
        case .trainingVolume:
            for session in sessions where session.totalVolume > 0 {
                let day = calendar.startOfDay(for: session.date)
                // 同日に複数セッションがある場合は合算
                performanceByDay[day, default: 0] += session.totalVolume
            }

        case .ability(let type):
            for ability in abilities where ability.type == type {
                let day = calendar.startOfDay(for: ability.date)
                performanceByDay[day] = ability.value
            }
        }

        // コンディションと同日で突き合わせ
        var points: [CorrelationPoint] = []
        for record in conditions {
            let day = calendar.startOfDay(for: record.date)
            guard let conditionValue = conditionVar.value(from: record),
                  let performanceValue = performanceByDay[day] else { continue }
            points.append(CorrelationPoint(
                date: day,
                conditionValue: conditionValue,
                performanceValue: performanceValue
            ))
        }
        points.sort { $0.date < $1.date }

        return CorrelationResult(
            conditionVar: conditionVar,
            performanceVar: performanceVar,
            points: points,
            coefficient: pearson(points.map(\.conditionValue), points.map(\.performanceValue))
        )
    }

    /// ピアソンの積率相関係数
    static func pearson(_ xs: [Double], _ ys: [Double]) -> Double {
        guard xs.count == ys.count, xs.count >= 2 else { return 0 }

        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var numerator = 0.0
        var sumSqX = 0.0
        var sumSqY = 0.0

        for (x, y) in zip(xs, ys) {
            let dx = x - meanX
            let dy = y - meanY
            numerator += dx * dy
            sumSqX += dx * dx
            sumSqY += dy * dy
        }

        let denominator = (sumSqX * sumSqY).squareRoot()
        // 片方の値が全て同じ場合は分母が0になる（相関は定義できない）
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    /// 中央値を境に2群へ分けて平均を比べる
    static func compare(_ result: CorrelationResult) -> GroupComparison? {
        guard result.hasEnoughData else { return nil }

        let conditionValues = result.points.map(\.conditionValue).sorted()
        let threshold = median(conditionValues)

        let high = result.points.filter { $0.conditionValue >= threshold }
        let low  = result.points.filter { $0.conditionValue < threshold }

        guard !high.isEmpty, !low.isEmpty else { return nil }

        let unit = result.conditionVar.unit
        let label: String
        switch result.conditionVar {
        case .sleep:
            label = String(format: "%.1f%@", threshold, unit)
        case .fatigue, .condition:
            label = String(format: "%.0f", threshold)
        }

        return GroupComparison(
            thresholdLabel: label,
            highGroupMean: high.map(\.performanceValue).reduce(0, +) / Double(high.count),
            lowGroupMean: low.map(\.performanceValue).reduce(0, +) / Double(low.count),
            highGroupCount: high.count,
            lowGroupCount: low.count
        )
    }

    static func median(_ sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    // MARK: - 文章化

    /// 分析結果を日本語の所見にする。
    ///
    /// 断定を避け「〜傾向がありました」という記述に統一している。
    /// 相関は因果ではないため、行動を指示する書き方はしない。
    static func summary(for result: CorrelationResult) -> String {
        guard result.hasEnoughData else {
            return "データが\(result.sampleSize)件しかないため、まだ傾向を読み取れません。同じ日に「コンディション」と「\(result.performanceVar.label)」の両方を記録した日が\(minimumSampleSize)日分たまると分析できます。"
        }

        guard result.strength != .negligible else {
            return "この期間では、\(result.conditionVar.rawValue)と\(result.performanceVar.label)の間にはっきりした関係は見られませんでした。"
        }

        let direction = result.isFavorableDirection ? "高い" : "低い"
        let conditionPhrase: String
        switch result.conditionVar {
        case .sleep:
            conditionPhrase = result.coefficient > 0 ? "睡眠時間が長い日" : "睡眠時間が短い日"
        case .fatigue:
            conditionPhrase = result.coefficient > 0 ? "疲労を強く感じた日" : "疲労が少なかった日"
        case .condition:
            conditionPhrase = result.coefficient > 0 ? "体調が優れなかった日" : "体調が良かった日"
        }

        return "\(conditionPhrase)ほど、\(result.performanceVar.label)が\(direction)傾向がありました（\(result.strength.label)・\(result.sampleSize)日分のデータ）。"
    }

    /// 2群比較の文章
    static func comparisonSummary(_ comparison: GroupComparison, for result: CorrelationResult) -> String? {
        guard comparison.isReliable, abs(comparison.percentDifference) >= 5 else { return nil }

        let higher = comparison.difference > 0
        let unitSuffix = result.performanceVar.label == "総挙上量" ? "kg" : ""

        let subject: String
        switch result.conditionVar {
        case .sleep:      subject = "睡眠が\(comparison.thresholdLabel)以上の日"
        case .fatigue:    subject = "疲労度が\(comparison.thresholdLabel)以上の日"
        case .condition:  subject = "体調スコアが\(comparison.thresholdLabel)以上の日"
        }

        return String(
            format: "%@の平均は %.1f%@、それ未満の日は %.1f%@ でした（差は約%.0f%%%@）。",
            subject,
            comparison.highGroupMean, unitSuffix,
            comparison.lowGroupMean, unitSuffix,
            abs(comparison.percentDifference),
            higher ? "高い" : "低い"
        )
    }
}
