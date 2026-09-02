import Foundation
import SwiftData

#if canImport(HealthKit)
import HealthKit
#endif

/// Appleヘルスケアからのデータ取り込みを担当する。
///
/// タニタ（ヘルスプラネット / TANITA Record）も InBody アプリも、
/// 測定結果をヘルスケアへ書き込む。そのため各メーカーと個別に連携する必要はなく、
/// ヘルスケアを1つのハブとして読むだけで両方に対応できる。
/// Withings・オムロン・Apple Watch なども同じ経路で入ってくる。
@Observable
@MainActor
final class HealthKitManager {

    static let shared = HealthKitManager()

    enum Status: Equatable {
        case unavailable          // 端末が非対応（iPad の一部など）
        case notRequested
        case denied
        case authorized
    }

    private(set) var status: Status = .notRequested
    private(set) var isImporting = false
    private(set) var lastResult: ImportResult?

    struct ImportResult: Equatable {
        var bodyAdded = 0
        var bodyUpdated = 0
        var sleepAdded = 0
        var isEmpty: Bool { bodyAdded == 0 && bodyUpdated == 0 && sleepAdded == 0 }

        var message: String {
            if isEmpty { return "新しいデータはありませんでした。" }
            var parts: [String] = []
            if bodyAdded > 0 { parts.append("身体測定 \(bodyAdded)件を追加") }
            if bodyUpdated > 0 { parts.append("\(bodyUpdated)件を更新") }
            if sleepAdded > 0 { parts.append("睡眠 \(sleepAdded)件を追加") }
            return parts.joined(separator: "、") + "しました。"
        }
    }

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    /// 読み取る種別。書き込みは行わないため read のみ要求する。
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(t) }
        return types
    }
    #endif

    private init() {
        refreshAvailability()
    }

    func refreshAvailability() {
        #if canImport(HealthKit)
        status = HKHealthStore.isHealthDataAvailable() ? .notRequested : .unavailable
        #else
        status = .unavailable
        #endif
    }

    // MARK: - 許可

    func requestAuthorization() async {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit は読み取り許可の可否を直接返さない（プライバシー保護のため）。
            // 実際に読めるかどうかは取り込みを試して判断する。
            status = .authorized
        } catch {
            status = .denied
        }
        #endif
    }

    // MARK: - 取り込み

    /// 過去12ヶ月分を取り込む
    func importAll(into context: ModelContext) async {
        #if canImport(HealthKit)
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        let start = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        var result = ImportResult()

        let weights = await fetchQuantities(.bodyMass, unit: .gramUnit(with: .kilo), since: start)
        let fats = await fetchQuantities(.bodyFatPercentage, unit: .percent(), since: start)

        // 体重と体脂肪率は別サンプルとして入ってくるため、同じ日にまとめる
        var byDay: [Date: (weight: Double?, fat: Double?, id: String)] = [:]
        for s in weights {
            let day = Calendar.current.startOfDay(for: s.date)
            var e = byDay[day] ?? (nil, nil, s.id)
            e.weight = s.value
            e.id = s.id
            byDay[day] = e
        }
        for s in fats {
            let day = Calendar.current.startOfDay(for: s.date)
            var e = byDay[day] ?? (nil, nil, s.id)
            // 体脂肪率は 0〜1 の割合で入るため % に直す
            e.fat = s.value * 100
            if e.id.isEmpty { e.id = s.id }
            byDay[day] = e
        }

        let existingBody = (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []

        for (day, entry) in byDay {
            guard entry.weight != nil || entry.fat != nil else { continue }

            // 同じ日にヘルスケア由来の記録があれば更新、なければ追加。
            // 手入力の記録は上書きしない（利用者が入れた値を勝手に変えない）。
            if let existing = existingBody.first(where: {
                $0.isFromHealthKit && Calendar.current.isDate($0.date, inSameDayAs: day)
            }) {
                var changed = false
                if let w = entry.weight, existing.weight != w { existing.weight = w; changed = true }
                if let f = entry.fat, existing.bodyFatPercentage != f { existing.bodyFatPercentage = f; changed = true }
                if changed { result.bodyUpdated += 1 }
            } else if !existingBody.contains(where: {
                !$0.isFromHealthKit && Calendar.current.isDate($0.date, inSameDayAs: day)
            }) {
                context.insert(BodyMeasurement(
                    date: day,
                    weight: entry.weight.map { ($0 * 10).rounded() / 10 },
                    bodyFatPercentage: entry.fat.map { ($0 * 10).rounded() / 10 },
                    externalID: entry.id
                ))
                result.bodyAdded += 1
            }
        }

        // 睡眠
        let sleepByDay = await fetchSleepHours(since: start)
        let existingCond = (try? context.fetch(FetchDescriptor<ConditionRecord>())) ?? []

        for (day, hours) in sleepByDay where hours >= 0.5 {
            let key = Self.dayKey(day)
            if let existing = existingCond.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: day)
            }) {
                // その日の記録が既にあり、睡眠が未入力のときだけ埋める
                if existing.sleepHours == nil {
                    existing.sleepHours = (hours * 10).rounded() / 10
                    existing.externalID = key
                    result.sleepAdded += 1
                }
            } else {
                context.insert(ConditionRecord(
                    date: day,
                    sleepHours: (hours * 10).rounded() / 10,
                    externalID: key
                ))
                result.sleepAdded += 1
            }
        }

        try? context.save()
        lastResult = result
        #endif
    }

    // MARK: - 取得処理

    #if canImport(HealthKit)
    private struct Sample { let id: String; let date: Date; let value: Double }

    private func fetchQuantities(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        since: Date
    ) async -> [Sample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let result = (samples as? [HKQuantitySample])?.map {
                    Sample(id: $0.uuid.uuidString,
                           date: $0.startDate,
                           value: $0.quantity.doubleValue(for: unit))
                } ?? []
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    /// 睡眠は複数の区間に分割して記録されるため、実際に眠っていた時間を合算する。
    /// 「就寝日」ではなく「起床日」に紐づけたほうが体感と一致する。
    private func fetchSleepHours(since: Date) async -> [Date: Double] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date())

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        // 「ベッドにいた時間」は除外し、実際の睡眠のみを数える
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        var byDay: [Date: Double] = [:]
        for s in samples where asleepValues.contains(s.value) {
            let day = Calendar.current.startOfDay(for: s.endDate)
            byDay[day, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 3600
        }
        return byDay
    }
    #endif

    private static func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "hk-sleep-" + f.string(from: d)
    }
}
