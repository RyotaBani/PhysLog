import Foundation
import SwiftData

// MARK: - ジム

/// トレーニング場所ごとの器具構成。
///
/// 同じ「ベンチプレス 60kg」でも、ジムによって成立するかどうかが変わる。
/// バーが 15kg のジムでは、20kg バー前提の組み合わせが作れないため。
/// 記録時に入力候補を絞り込むための情報を持つ。
@Model
final class Gym {
    var name: String = ""
    var memo: String = ""
    /// 記録画面で既定として選ばれるジム
    var isDefault: Bool = false
    var createdAt: Date = Date()

    // MARK: バーベル

    /// 置いてあるバーの重さ（kg）。複数種類ある場合は全部入れる。
    /// 例: [20, 15, 10]
    var barWeights: [Double] = [20]

    /// プレートの刻み（kg）。片側1枚あたりの重さ。
    /// 1.25kg を置いていないジムがあるため、ジムごとに持つ。
    /// 例: [1.25, 2.5, 5, 10, 15, 20]
    var plateWeights: [Double] = [1.25, 2.5, 5, 10, 15, 20]

    // MARK: ダンベル

    var dumbbellMin: Double = 1
    var dumbbellMax: Double = 40
    /// ダンベルの刻み（kg）。2kg 刻みのジムでは 15kg は存在しない。
    var dumbbellStep: Double = 2

    // MARK: マシン

    /// マシンの重量表記。ポンド表記や独自の段階表記のジムがある。
    var machineUnitRaw: String = MachineUnit.kilogram.rawValue

    var machineUnit: MachineUnit {
        get { MachineUnit(rawValue: machineUnitRaw) ?? .kilogram }
        set { machineUnitRaw = newValue.rawValue }
    }

    /// 段階表記（1番、2番…）の場合、1段あたり何kg相当か。
    /// 実測が分からない場合は nil のままでよい。
    var machineStepWeight: Double?

    init(
        name: String,
        memo: String = "",
        isDefault: Bool = false,
        barWeights: [Double] = [20],
        plateWeights: [Double] = [1.25, 2.5, 5, 10, 15, 20],
        dumbbellMin: Double = 1,
        dumbbellMax: Double = 40,
        dumbbellStep: Double = 2,
        machineUnit: MachineUnit = .kilogram,
        machineStepWeight: Double? = nil
    ) {
        self.name = name
        self.memo = memo
        self.isDefault = isDefault
        self.createdAt = Date()
        self.barWeights = barWeights
        self.plateWeights = plateWeights
        self.dumbbellMin = dumbbellMin
        self.dumbbellMax = dumbbellMax
        self.dumbbellStep = dumbbellStep
        self.machineUnitRaw = machineUnit.rawValue
        self.machineStepWeight = machineStepWeight
    }
}

// MARK: - マシンの重量表記

enum MachineUnit: String, CaseIterable, Identifiable {
    case kilogram = "kg"
    case pound    = "lb"
    case stack    = "段階"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kilogram: return "キログラム（kg）"
        case .pound:    return "ポンド（lb）"
        case .stack:    return "段階表記（1番・2番…）"
        }
    }

    var hint: String {
        switch self {
        case .kilogram: return "一般的な表記です"
        case .pound:    return "海外製マシンに多い表記。記録は kg に換算して保存します"
        case .stack:    return "重量ではなく番号で表示されるマシン"
        }
    }
}

// MARK: - 重量の換算

enum WeightConverter {

    /// 1ポンド = 0.45359237 キログラム（国際ヤード・ポンド）
    static let poundToKilogram = 0.45359237

    static func toKilogram(_ value: Double, from unit: MachineUnit, stepWeight: Double?) -> Double? {
        switch unit {
        case .kilogram:
            return value
        case .pound:
            return (value * poundToKilogram * 10).rounded() / 10
        case .stack:
            // 1段あたりの重量が分からなければ換算できない。
            // 総挙上量の計算からは除外する（推測値を混ぜると数字が壊れるため）。
            guard let stepWeight else { return nil }
            return (value * stepWeight * 10).rounded() / 10
        }
    }

    static func fromKilogram(_ kg: Double, to unit: MachineUnit, stepWeight: Double?) -> Double? {
        switch unit {
        case .kilogram:
            return kg
        case .pound:
            return (kg / poundToKilogram * 10).rounded() / 10
        case .stack:
            guard let stepWeight, stepWeight > 0 else { return nil }
            return (kg / stepWeight).rounded()
        }
    }
}

// MARK: - 入力候補の生成

extension Gym {

    /// バーベルで作れる重量の一覧。
    ///
    /// プレートは左右対称に付けるため、片側の合計を2倍してバーに足す。
    /// 「1.25kg プレートがないジムで 62.5kg」のような、
    /// そのジムでは物理的に作れない重量を候補から除ける。
    func barbellWeights(maxWeight: Double = 300) -> [Double] {
        guard !barWeights.isEmpty, !plateWeights.isEmpty else { return [] }

        var results = Set<Double>()
        let sortedPlates = plateWeights.sorted()

        for bar in barWeights {
            // 片側に載せられるプレートの合計を、動的計画法で列挙する。
            // 同じプレートを何枚も使えるので、無制限ナップサックと同じ形。
            var oneSideTotals = Set<Double>([0])
            var frontier: Set<Double> = [0]

            while !frontier.isEmpty {
                var next = Set<Double>()
                for total in frontier {
                    for plate in sortedPlates {
                        let sum = total + plate
                        // 両側 + バーが上限を超えたら打ち切る
                        if bar + sum * 2 > maxWeight { continue }
                        if oneSideTotals.insert(sum).inserted {
                            next.insert(sum)
                        }
                    }
                }
                frontier = next
            }

            for side in oneSideTotals {
                results.insert(bar + side * 2)
            }
        }
        return results.sorted()
    }

    /// ダンベルの重量一覧
    func dumbbellWeightList() -> [Double] {
        guard dumbbellStep > 0, dumbbellMax >= dumbbellMin else { return [] }
        var results: [Double] = []
        var w = dumbbellMin
        while w <= dumbbellMax + 0.001 {
            results.append((w * 100).rounded() / 100)
            w += dumbbellStep
        }
        return results
    }

    /// 表示用のまとめ
    var summary: String {
        var parts: [String] = []
        if !barWeights.isEmpty {
            parts.append("バー " + barWeights.map { fmt($0) + "kg" }.joined(separator: "/"))
        }
        if let minPlate = plateWeights.min() {
            parts.append("プレート最小 \(fmt(minPlate))kg")
        }
        parts.append("ダンベル \(fmt(dumbbellMin))〜\(fmt(dumbbellMax))kg（\(fmt(dumbbellStep))kg刻み）")
        if machineUnit != .kilogram {
            parts.append("マシン \(machineUnit.rawValue)")
        }
        return parts.joined(separator: " ・ ")
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
            .replacingOccurrences(of: "0$", with: "", options: .regularExpression)
    }
}

// MARK: - よくある構成のプリセット

extension Gym {

    /// 新規登録時の出発点。ゼロから全部入力させると続かないため、
    /// 近いものを選んでから差分を直す形にする。
    struct Preset {
        let name: String
        let detail: String
        let make: (String) -> Gym
    }

    static let presets: [Preset] = [
        Preset(
            name: "一般的なジム",
            detail: "20kgバー / 1.25kgプレートあり / ダンベル1〜40kg",
            make: { Gym(name: $0) }
        ),
        Preset(
            name: "プレートが粗いジム",
            detail: "20kgバー / 最小2.5kgプレート / ダンベル2kg刻み",
            make: {
                Gym(name: $0,
                    plateWeights: [2.5, 5, 10, 15, 20],
                    dumbbellMin: 2, dumbbellStep: 2)
            }
        ),
        Preset(
            name: "軽量バーもあるジム",
            detail: "20/15/10kgバー / 1.25kgプレートあり",
            make: {
                Gym(name: $0, barWeights: [20, 15, 10])
            }
        ),
        Preset(
            name: "ポンド表記のマシン",
            detail: "マシンが lb 表記。記録は kg に換算されます",
            make: {
                Gym(name: $0, machineUnit: .pound)
            }
        ),
    ]
}
