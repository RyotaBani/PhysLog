import Foundation
import SwiftData

@Model
final class ConditionRecord {
    var date: Date = Date()
    var sleepHours: Double?
    var fatigue: Int?     // 1 = ほぼなし … 5 = 非常に高い
    var condition: Int?   // 1 = 最高 … 5 = 不調
    var memo: String = ""
    /// ヘルスケアから睡眠を取り込んだ日を表すキー（yyyy-MM-dd）。重複防止用。
    var externalID: String?

    init(
        date: Date = Date(),
        sleepHours: Double? = nil,
        fatigue: Int? = nil,
        condition: Int? = nil,
        memo: String = "",
        externalID: String? = nil
    ) {
        self.date = date
        self.sleepHours = sleepHours
        self.fatigue = fatigue
        self.condition = condition
        self.memo = memo
        self.externalID = externalID
    }

    var conditionLabel: String {
        switch condition {
        case 1: return "最高"
        case 2: return "良好"
        case 3: return "普通"
        case 4: return "やや不調"
        case 5: return "不調"
        default: return "未記録"
        }
    }

    var conditionEmoji: String {
        switch condition {
        case 1: return "🟢"
        case 2: return "🔵"
        case 3: return "🟡"
        case 4: return "🟠"
        case 5: return "🔴"
        default: return "—"
        }
    }

    var fatigueLabel: String {
        switch fatigue {
        case 1: return "ほぼなし"
        case 2: return "少しある"
        case 3: return "中程度"
        case 4: return "かなり"
        case 5: return "非常に高い"
        default: return "未記録"
        }
    }

    var sleepLabel: String {
        guard let h = sleepHours else { return "未記録" }
        return String(format: "%.1f時間", h)
    }
}
