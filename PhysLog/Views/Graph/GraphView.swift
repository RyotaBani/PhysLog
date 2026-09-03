import SwiftUI
import SwiftData
import Charts

// MARK: - グラフ種別

enum GraphMetric: String, CaseIterable, Identifiable {
    case weight     = "体重"
    case bodyFat    = "体脂肪率"
    case muscleMass = "筋肉量"
    case ability    = "身体能力"
    case volume     = "挙上量"
    case condition  = "体調"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weight:     return "scalemass.fill"
        case .bodyFat:    return "chart.pie.fill"
        case .muscleMass: return "figure.arms.open"
        case .ability:    return "figure.run"
        case .volume:     return "dumbbell.fill"
        case .condition:  return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .weight:     return .physlogPrimary
        case .bodyFat:    return .physlogOrange
        case .muscleMass: return .physlogAccent
        case .ability:    return .physlogPurple
        case .volume:     return .physlogOrange
        case .condition:  return .physlogPink
        }
    }
}

enum GraphRange: Int, CaseIterable, Identifiable {
    case month1 = 1
    case month3 = 3
    case month6 = 6
    case year1  = 12
    case all    = 0

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .month1: return "1ヶ月"
        case .month3: return "3ヶ月"
        case .month6: return "6ヶ月"
        case .year1:  return "1年"
        case .all:    return "全期間"
        }
    }

    var cutoff: Date? {
        guard self != .all else { return nil }
        return Calendar.current.date(byAdding: .month, value: -rawValue, to: Date())
    }
}

// MARK: - データ点

struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - メイン画面

struct GraphView: View {
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @Query(sort: \PhysicalAbility.date) private var abilities: [PhysicalAbility]
    @Query(sort: \TrainingSession.date) private var sessions: [TrainingSession]
    @Query(sort: \ConditionRecord.date) private var conditions: [ConditionRecord]

    @State private var metric: GraphMetric = .weight
    @State private var range: GraphRange = .month3
    @State private var abilityType: String = ""

    private var abilityTypes: [String] {
        Array(Set(abilities.map(\.type))).sorted()
    }

    private var currentUnit: String {
        switch metric {
        case .weight, .muscleMass: return "kg"
        case .bodyFat:             return "%"
        case .volume:              return "kg"
        case .ability:
            return abilities.first { $0.type == abilityType }?.unit ?? ""
        case .condition:           return ""
        }
    }

    /// 選択中の指標の系列データ
    private var points: [DataPoint] {
        let cutoff = range.cutoff

        switch metric {
        case .weight:
            return measurements
                .filter { cutoff == nil || $0.date >= cutoff! }
                .compactMap { m in m.weight.map { DataPoint(date: m.date, value: $0) } }

        case .bodyFat:
            return measurements
                .filter { cutoff == nil || $0.date >= cutoff! }
                .compactMap { m in m.bodyFatPercentage.map { DataPoint(date: m.date, value: $0) } }

        case .muscleMass:
            return measurements
                .filter { cutoff == nil || $0.date >= cutoff! }
                .compactMap { m in m.muscleMass.map { DataPoint(date: m.date, value: $0) } }

        case .ability:
            return abilities
                .filter { $0.type == abilityType && (cutoff == nil || $0.date >= cutoff!) }
                .map { DataPoint(date: $0.date, value: $0.value) }

        case .volume:
            let filtered = sessions.filter { cutoff == nil || $0.date >= cutoff! }
            let grouped = Dictionary(grouping: filtered) { session -> Date in
                Calendar.current.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
            }
            return grouped
                .map { DataPoint(date: $0.key, value: $0.value.reduce(0) { $0 + $1.totalVolume }) }
                .sorted { $0.date < $1.date }

        case .condition:
            return []
        }
    }

    /// 変化量を色で評価してよい指標かどうか。
    ///
    /// 体組成（体重・体脂肪率・筋肉量）は、増やしたいのか減らしたいのかが
    /// 競技や時期によって変わるため、アプリ側で良し悪しを決めない。
    /// 方向が明確な身体能力と挙上量だけ色を付ける。
    private var judgesDirection: Bool {
        switch metric {
        case .ability, .volume: return true
        default:                return false
        }
    }

    /// タイム種目は下降がプラス評価
    private var lowerIsBetter: Bool {
        metric == .ability && AbilityPreset.isLowerBetter(abilityType)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    metricSelector
                    rangeSelector

                    if metric == .ability {
                        abilitySelector
                    }

                    chartCard

                    if metric != .condition && !points.isEmpty {
                        summaryCard
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .adBanner()
            .navigationTitle("グラフ")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Label("分析", systemImage: "chart.dots.scatter")
                    }
                }
            }
        }
        .onAppear {
            if abilityType.isEmpty { abilityType = abilityTypes.first ?? "" }
        }
    }

    // MARK: - セレクター

    private var metricSelector: some View {
        // 6項目あるため横スクロールだと右端が見切れる。
        // 3列×2行に折り返して全項目を常に見せる。
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(GraphMetric.allCases) { m in
                Button {
                    metric = m
                    if m == .ability, abilityType.isEmpty {
                        abilityType = abilityTypes.first ?? ""
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(m.rawValue)
                            .font(.system(size: 12.5, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        metric == m ? m.color : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .foregroundStyle(metric == m ? .white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var rangeSelector: some View {
        Picker("期間", selection: $range) {
            ForEach(GraphRange.allCases) { r in
                Text(r.label).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var abilitySelector: some View {
        if abilityTypes.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(abilityTypes, id: \.self) { type in
                        Chip(label: type, isSelected: abilityType == type, color: .physlogPurple) {
                            abilityType = type
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .fadeTrailingEdge()
        }
    }

    // MARK: - グラフ本体

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text(chartTitle)
                    .font(.headline)

                if metric == .condition {
                    ConditionChart(records: conditions.filter { range.cutoff == nil || $0.date >= range.cutoff! })
                } else if points.count < 2 {
                    insufficientDataView
                } else if metric == .volume {
                    VolumeChart(points: points)
                } else {
                    TrendChart(points: points, color: metric.color, unit: currentUnit)
                }
            }
        }
        .padding(.horizontal)
    }

    private var chartTitle: String {
        switch metric {
        case .ability: return abilityType.isEmpty ? "身体能力の推移" : "\(abilityType) の推移"
        case .volume:  return "週ごとの総挙上量"
        case .condition: return "体調・疲労度の推移"
        default:       return "\(metric.rawValue) の推移"
        }
    }

    private var insufficientDataView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(points.isEmpty ? "データがありません" : "データが1件のみです")
                .font(.subheadline.weight(.medium))
            Text("2件以上記録するとグラフが表示されます")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - サマリー

    private var summaryCard: some View {
        let values = points.map(\.value)
        let first = values.first ?? 0
        let last = values.last ?? 0
        let change = last - first

        // 良し悪しを判定しない指標は中立色にする
        let changeColor: Color
        if judgesDirection {
            let isGood = lowerIsBetter ? change <= 0 : change >= 0
            changeColor = isGood ? .physlogAccent : .physlogPink
        } else {
            changeColor = .secondary
        }

        return Card(padding: 14) {
            HStack(spacing: 0) {
                SummaryCell(label: "最新", text: format(last), color: metric.color)
                Divider().frame(height: 36)
                SummaryCell(label: "最高", text: format(values.max() ?? 0), color: .physlogAccent)
                Divider().frame(height: 36)
                SummaryCell(label: "最低", text: format(values.min() ?? 0), color: .physlogPrimary)
                Divider().frame(height: 36)
                SummaryCell(
                    label: "変化",
                    text: (change >= 0 ? "+" : "") + format(change),
                    color: changeColor
                )
            }
        }
        .padding(.horizontal)
    }

    private func format(_ value: Double) -> String {
        if metric == .volume { return String(format: "%.0f", value) }
        return String(format: currentUnit == "秒" ? "%.2f" : "%.1f", value)
    }
}

// MARK: - サマリーセル

struct SummaryCell: View {
    let label: String
    let text: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 折れ線グラフ

struct TrendChart: View {
    let points: [DataPoint]
    let color: Color
    let unit: String

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let padding = max((maxV - minV) * 0.15, 0.5)
        return (minV - padding)...(maxV + padding)
    }

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("日付", point.date),
                y: .value("値", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.28), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("日付", point.date),
                y: .value("値", point.value)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("日付", point.date),
                y: .value("値", point.value)
            )
            .foregroundStyle(color)
            .symbolSize(28)
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.shortJP).font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: unit == "秒" ? "%.2f" : "%.1f", v))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 230)
    }
}

// MARK: - 棒グラフ（挙上量）

struct VolumeChart: View {
    let points: [DataPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("週", point.date, unit: .weekOfYear),
                y: .value("挙上量", point.value)
            )
            .foregroundStyle(Color.physlogOrange.gradient)
            .cornerRadius(5)
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.shortJP).font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))").font(.caption2)
                    }
                }
            }
        }
        .frame(height: 230)
    }
}

// MARK: - コンディショングラフ

struct ConditionChart: View {
    let records: [ConditionRecord]

    /// 1(最高) → 5 を、グラフ上では 5(良い) → 1 に反転して「上が良い」状態にする
    private var series: [(label: String, points: [DataPoint])] {
        let conditionPoints = records.compactMap { r in
            r.condition.map { DataPoint(date: r.date, value: Double(6 - $0)) }
        }
        let fatiguePoints = records.compactMap { r in
            r.fatigue.map { DataPoint(date: r.date, value: Double(6 - $0)) }
        }
        return [
            ("体調", conditionPoints),
            ("疲労の軽さ", fatiguePoints)
        ].filter { !$0.points.isEmpty }
    }

    var body: some View {
        if series.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 34))
                    .foregroundStyle(.tertiary)
                Text("コンディションのデータがありません")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(series, id: \.label) { item in
                        ForEach(item.points) { point in
                            LineMark(
                                x: .value("日付", point.date),
                                y: .value("スコア", point.value)
                            )
                            .foregroundStyle(by: .value("項目", item.label))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "体調": Color.physlogPink,
                    "疲労の軽さ": Color.physlogOrange
                ])
                .chartYScale(domain: 0.5...5.5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(scoreLabel(v)).font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortJP).font(.caption2)
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 230)

                Text("グラフは上にあるほど良い状態を表します")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scoreLabel(_ v: Int) -> String {
        switch v {
        case 5: return "良"
        case 3: return "中"
        case 1: return "不"
        default: return ""
        }
    }
}

#Preview {
    GraphView()
        .modelContainer(PreviewData.container)
        .environment(ProStore.shared)
}
