import Foundation
import SwiftData

// MARK: - デモデータ生成

enum SampleData {

    /// 過去3ヶ月分のリアルなデータを投入する
    @MainActor
    static func populate(into context: ModelContext) {
        let cal = Calendar.current
        let today = Date()

        // ── 身体測定（週1回・12週分）──────────────────────
        for week in stride(from: 12, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -week * 7, to: today) else { continue }
            let progress = Double(12 - week) / 12.0
            let weight = 72.0 - progress * 2.6 + Double.random(in: -0.4...0.4)
            let fat = 18.5 - progress * 3.2 + Double.random(in: -0.3...0.3)
            let muscle = weight * (1 - fat / 100) * 0.53

            context.insert(BodyMeasurement(
                date: date,
                weight: (weight * 10).rounded() / 10,
                bodyFatPercentage: (fat * 10).rounded() / 10,
                muscleMass: (muscle * 10).rounded() / 10
            ))
        }

        // ── 身体能力（月1回・種目別）─────────────────────
        let abilityPlan: [(String, String, Double, Double)] = [
            ("垂直跳び",          "cm", 62.0, 5.0),
            ("50m走",             "秒",  6.8, -0.25),
            ("握力（右）",        "kg", 44.0, 3.0),
            ("ベンチプレス(MAX)", "kg", 75.0, 10.0),
            ("スクワット(MAX)",   "kg", 95.0, 15.0),
        ]
        for (name, unit, start, delta) in abilityPlan {
            for month in stride(from: 3, through: 0, by: -1) {
                guard let date = cal.date(byAdding: .month, value: -month, to: today) else { continue }
                let progress = Double(3 - month) / 3.0
                let value = start + delta * progress
                context.insert(PhysicalAbility(
                    date: date,
                    type: name,
                    value: (value * 100).rounded() / 100,
                    unit: unit
                ))
            }
        }

        // ── トレーニング（週3回・8週分）──────────────────
        let routines: [(String, [(String, Double, Int, Int)])] = [
            ("ウェイトトレーニング", [
                ("ベンチプレス", 70, 8, 4),
                ("インクラインベンチプレス", 50, 10, 3),
                ("ショルダープレス", 40, 10, 3),
                ("プレスダウン", 30, 12, 3),
            ]),
            ("ウェイトトレーニング", [
                ("デッドリフト", 110, 5, 4),
                ("ラットプルダウン", 55, 10, 4),
                ("ベントオーバーロウ", 50, 10, 3),
                ("ダンベルカール", 14, 12, 3),
            ]),
            ("ウェイトトレーニング", [
                ("スクワット", 90, 8, 4),
                ("レッグプレス", 140, 12, 3),
                ("ブルガリアンスクワット", 20, 10, 3),
                ("カーフレイズ", 40, 15, 3),
            ]),
        ]

        for week in stride(from: 7, through: 0, by: -1) {
            for (dayOffset, routine) in routines.enumerated() {
                let daysAgo = week * 7 + dayOffset * 2
                guard let date = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

                let session = TrainingSession(date: date, sport: routine.0)
                context.insert(session)

                let progressBonus = Double(7 - week) * 1.25
                for (i, item) in routine.1.enumerated() {
                    let set = TrainingSet(
                        exercise: item.0,
                        weight: item.1 + progressBonus,
                        reps: item.2,
                        sets: item.3,
                        order: i
                    )
                    set.session = session
                    context.insert(set)
                }
            }
        }

        // ── コンディション（週4回・8週分）────────────────
        for day in stride(from: 56, through: 0, by: -2) {
            guard let date = cal.date(byAdding: .day, value: -day, to: today) else { continue }
            context.insert(ConditionRecord(
                date: date,
                sleepHours: Double.random(in: 5.5...8.5).rounded(toPlaces: 1),
                fatigue: Int.random(in: 1...4),
                condition: Int.random(in: 1...3)
            ))
        }

        try? context.save()
    }

    /// 全データ削除
    @MainActor
    static func deleteAll(from context: ModelContext) {
        try? context.delete(model: TrainingSet.self)
        try? context.delete(model: TrainingSession.self)
        try? context.delete(model: BodyMeasurement.self)
        try? context.delete(model: PhysicalAbility.self)
        try? context.delete(model: ConditionRecord.self)
        try? context.save()
    }
}

// MARK: - Preview 用インメモリコンテナ

enum PreviewData {
    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([
            BodyMeasurement.self,
            PhysicalAbility.self,
            TrainingSession.self,
            TrainingSet.self,
            ConditionRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        SampleData.populate(into: container.mainContext)
        return container
    }()
}

// MARK: - Helper

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
