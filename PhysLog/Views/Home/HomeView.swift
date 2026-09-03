import SwiftUI
import SwiftData

struct HomeView: View {
    @AppStorage("userName") private var userName = ""

    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \ConditionRecord.date, order: .reverse) private var conditions: [ConditionRecord]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \PhysicalAbility.date, order: .reverse) private var abilities: [PhysicalAbility]

    private var latest: BodyMeasurement? { measurements.first }
    private var latestCondition: ConditionRecord? { conditions.first }

    private var weeklyCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoff }.count
    }

    private var weeklyVolume: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoff }.reduce(0) { $0 + $1.totalVolume }
    }

    /// 体重の前回比
    private var weightDelta: Double? {
        let withWeight = measurements.compactMap { m -> Double? in m.weight }
        guard withWeight.count >= 2 else { return nil }
        return withWeight[0] - withWeight[1]
    }

    /// 種目ごとの最新記録
    private var latestAbilities: [PhysicalAbility] {
        var seen = Set<String>()
        var result: [PhysicalAbility] = []
        for a in abilities where !seen.contains(a.type) {
            seen.insert(a.type)
            result.append(a)
        }
        return result
    }

    private var hasAnyData: Bool {
        !measurements.isEmpty || !sessions.isEmpty || !conditions.isEmpty || !abilities.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    header

                    if !hasAnyData {
                        Card {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.physlogPrimary.opacity(0.4))
                                Text("記録をはじめましょう")
                                    .font(.headline)
                                Text("「記録」タブから体重やトレーニングを入力すると、\nここに成長のサマリーが表示されます。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal)
                    } else {
                        statGrid
                        trainingSection
                        abilitySection
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .adBanner()
            .navigationTitle("PhysLog")
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !userName.isEmpty {
                Text("\(userName) さん")
                    .font(.title2.bold())
            }
        }
        .padding(.horizontal)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11:  return "おはようございます"
        case 11..<17: return "こんにちは"
        case 17..<22: return "こんばんは"
        default:      return "お疲れさまです"
        }
    }

    // MARK: - サマリーカード

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {

            StatCard(
                title: "体重",
                value: latest?.weight.map { String(format: "%.1f", $0) } ?? "—",
                unit: "kg",
                icon: "scalemass.fill",
                color: .physlogPrimary,
                caption: latest.map { $0.date.relativeJP },
                delta: weightDelta.map { String(format: "%+.1f kg", $0) }
            )

            StatCard(
                title: "体脂肪率",
                value: latest?.bodyFatPercentage.map { String(format: "%.1f", $0) } ?? "—",
                unit: "%",
                icon: "chart.pie.fill",
                color: .physlogOrange,
                caption: latest.map { $0.date.relativeJP }
            )

            StatCard(
                title: "今週のトレーニング",
                value: "\(weeklyCount)",
                unit: "回",
                icon: "dumbbell.fill",
                color: .physlogAccent,
                caption: weeklyVolume > 0 ? String(format: "%.0f kg 総挙上", weeklyVolume) : nil
            )

            StatCard(
                title: "体調",
                value: latestCondition?.conditionEmoji ?? "—",
                unit: latestCondition?.conditionLabel ?? "",
                icon: "heart.fill",
                color: .physlogPink,
                caption: latestCondition.map { $0.date.relativeJP }
            )
        }
        .padding(.horizontal)
    }

    // MARK: - 最近のトレーニング

    @ViewBuilder
    private var trainingSection: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("最近のトレーニング")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(sessions.prefix(3)) { session in
                    Card(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell.fill")
                                .foregroundStyle(Color.physlogOrange)
                                .frame(width: 40, height: 40)
                                .background(Color.physlogOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.displayTitle)
                                    .font(.subheadline.weight(.semibold))
                                Text(session.date.relativeJP)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(session.exerciseCount) 種目")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.physlogOrange)
                                if session.totalVolume > 0 {
                                    Text(String(format: "%.0f kg", session.totalVolume))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - 身体能力

    @ViewBuilder
    private var abilitySection: some View {
        if !latestAbilities.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("最新の身体能力")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(latestAbilities.prefix(8)) { ability in
                            VStack(spacing: 6) {
                                Image(systemName: AbilityPreset.icon(for: ability.type))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.physlogAccent)
                                Text(ability.type)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                HStack(alignment: .lastTextBaseline, spacing: 1) {
                                    Text(ability.formattedValue)
                                        .font(.title3.bold())
                                    Text(ability.unit)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 104)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal)
                }
                .fadeTrailingEdge()
            }
        }
    }
}

// MARK: - サマリーカード部品

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    var caption: String? = nil
    var delta: String? = nil

    /// 変化量を色で評価するか。
    ///
    /// 体重・体脂肪率・筋肉量は、増やしたいのか減らしたいのかが
    /// 競技や時期（増量期・減量期）によって変わる。
    /// アプリが一方向を「良い」と決めつけないよう、既定では色を付けない。
    var deltaJudgement: DeltaJudgement = .neutral

    enum DeltaJudgement {
        case neutral        // 良し悪しを判定しない
        case higherIsBetter
        case lowerIsBetter
    }

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.14), in: Circle())
                    Spacer()
                    if let caption {
                        Text(caption)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let delta {
                    Text(delta)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(deltaColor(for: delta))
                }
            }
        }
    }

    private func deltaColor(for text: String) -> Color {
        switch deltaJudgement {
        case .neutral:
            return .secondary
        case .higherIsBetter:
            return text.hasPrefix("-") ? .physlogPink : .physlogAccent
        case .lowerIsBetter:
            return text.hasPrefix("-") ? .physlogAccent : .physlogPink
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
