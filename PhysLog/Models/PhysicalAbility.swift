import Foundation
import SwiftData

// MARK: - 種目定義

struct AbilityPreset: Identifiable, Hashable {
    let id: String          // = name。安定した識別子として使う
    let name: String
    let unit: String
    let icon: String
    /// タイムなど「小さいほど良い」種目は true
    let isLowerBetter: Bool

    init(_ name: String, unit: String, icon: String, isLowerBetter: Bool = false) {
        self.id = name
        self.name = name
        self.unit = unit
        self.icon = icon
        self.isLowerBetter = isLowerBetter
    }

    static let all: [AbilityPreset] = [
        AbilityPreset("垂直跳び",           unit: "cm", icon: "arrow.up.circle.fill"),
        AbilityPreset("立ち幅跳び",         unit: "cm", icon: "arrow.forward.circle.fill"),
        AbilityPreset("50m走",              unit: "秒", icon: "figure.run", isLowerBetter: true),
        AbilityPreset("100m走",             unit: "秒", icon: "figure.run", isLowerBetter: true),
        AbilityPreset("20mスプリント",      unit: "秒", icon: "figure.run", isLowerBetter: true),
        AbilityPreset("握力（右）",         unit: "kg", icon: "hand.raised.fill"),
        AbilityPreset("握力（左）",         unit: "kg", icon: "hand.raised.fill"),
        AbilityPreset("反復横跳び",         unit: "回", icon: "arrow.left.arrow.right"),
        AbilityPreset("シャトルラン",       unit: "回", icon: "arrow.triangle.2.circlepath"),
        AbilityPreset("長座体前屈",         unit: "cm", icon: "figure.flexibility"),
        AbilityPreset("ベンチプレス(MAX)",  unit: "kg", icon: "dumbbell.fill"),
        AbilityPreset("スクワット(MAX)",    unit: "kg", icon: "dumbbell.fill"),
        AbilityPreset("デッドリフト(MAX)",  unit: "kg", icon: "dumbbell.fill"),
        AbilityPreset("腕立て伏せ",         unit: "回", icon: "figure.strengthtraining.traditional"),
        AbilityPreset("懸垂",               unit: "回", icon: "figure.climbing"),
    ]

    static func find(_ name: String) -> AbilityPreset? {
        all.first { $0.name == name }
    }

    /// 未知の種目名でも安全にアイコンを引く
    static func icon(for name: String) -> String {
        if let p = find(name) { return p.icon }
        if name.contains("跳") { return "arrow.up.circle.fill" }
        if name.contains("走") || name.contains("ラン") { return "figure.run" }
        if name.contains("握力") { return "hand.raised.fill" }
        if name.contains("MAX") || name.contains("プレス") { return "dumbbell.fill" }
        return "star.fill"
    }

    static func isLowerBetter(_ name: String) -> Bool {
        find(name)?.isLowerBetter ?? false
    }
}

// MARK: - SwiftData モデル

@Model
final class PhysicalAbility {
    var date: Date = Date()
    var type: String = ""     // プリセット名 or 自由入力
    var value: Double = 0.0
    var unit: String = ""
    var memo: String = ""

    init(
        date: Date = Date(),
        type: String,
        value: Double,
        unit: String,
        memo: String = ""
    ) {
        self.date = date
        self.type = type
        self.value = value
        self.unit = unit
        self.memo = memo
    }

    /// 秒単位は小数2桁、それ以外は1桁で表示
    var formattedValue: String {
        String(format: unit == "秒" ? "%.2f" : "%.1f", value)
    }
}
