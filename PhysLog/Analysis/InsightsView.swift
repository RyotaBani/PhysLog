import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(ProStore.self) private var store

    @Query(sort: \ConditionRecord.date) private var conditions: [ConditionRecord]
    @Query(sort: \TrainingSession.date) private var sessions: [TrainingSession]
    @Query(sort: \PhysicalAbility.date) private var abilities: [PhysicalAbility]

    @State private var conditionVar: ConditionVariable = .sleep
    @State private var performanceVar: PerformanceVariable = .trainingVolume
    @State private var showPaywall = false

    /// 選択できるパフォーマンス指標
    private var performanceOptions: [PerformanceVariable] {
        var options: [PerformanceVariable] = []
        if sessions.contains(where: { $0.totalVolume > 0 }) {
            options.append(.trainingVolume)
        }
        let types = Array(Set(abilities.map(\.type))).sorted()
        options.append(contentsOf: types.map { PerformanceVariable.ability($0) })
        return options
    }

    private var result: CorrelationResult {
        CorrelationEngine.analyze(
            conditionVar: conditionVar,
            performanceVar: performanceVar,
            conditions: conditions,
            sessions: sessions,
            abilities: abilities
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if performanceOptions.isEmpty {
                    EmptyStateView(
                        icon: "chart.dots.scatter",
                        title: "分析できるデータがありません",
                        message: "コンディションとトレーニング（または身体能力）を\n同じ日に記録すると、その関係を分析できます"
                    )
                    .padding(.top, 40)
                } else {
                    selectors

                    // v1.0 は分析を無料開放しているため、
                    // ぼかしとロックは表示されない（FeatureFlags で切り替え）
                    let unlocked = FeatureFlags.canUseInsights(isPro: store.isPro)

                    ZStack {
                        analysisContent
                            .blur(radius: unlocked ? 0 : 7)
                            .disabled(!unlocked)
                            .allowsHitTesting(unlocked)

                        if !unlocked {
                            lockOverlay
                        }
                    }

                    disclaimer
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .adBanner()
        .navigationTitle("コンディション分析")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            if FeatureFlags.isProEnabled { PaywallView() }
        }
        .onAppear {
            if let first = performanceOptions.first,
               !performanceOptions.contains(performanceVar) {
                performanceVar = first
            }
        }
    }

    // MARK: - 変数選択

    private var selectors: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("コンディション")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // 3項目固定なので横スクロールにせず画面内に収める
                HStack(spacing: 8) {
                    ForEach(ConditionVariable.allCases) { item in
                        Button {
                            conditionVar = item
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    conditionVar == item
                                        ? Color.physlogPurple
                                        : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .foregroundStyle(conditionVar == item ? .white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("パフォーマンス")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(performanceOptions) { item in
                            Chip(label: item.label,
                                 isSelected: performanceVar == item,
                                 color: .physlogAccent) {
                                performanceVar = item
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .fadeTrailingEdge()
            }
        }
    }

    // MARK: - 分析結果

    private var analysisContent: some View {
        let current = result
        let comparison = CorrelationEngine.compare(current)

        return VStack(spacing: 14) {
            // 所見
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.magnifyingglass")
                            .foregroundStyle(Color.physlogPurple)
                        Text("わかったこと")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text(CorrelationEngine.summary(for: current))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    if let comparison,
                       let text = CorrelationEngine.comparisonSummary(comparison, for: current) {
                        Divider()
                        Text(text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal)

            // 散布図
            if current.hasEnoughData {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("散布図")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("相関係数 \(String(format: "%.2f", current.coefficient))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.physlogPurple)
                        }

                        ScatterPlot(result: current)

                        HStack {
                            Text("横軸: \(current.conditionVar.rawValue)")
                            Spacer()
                            Text("縦軸: \(current.performanceVar.label)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - ロック表示

    private var lockOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Color.physlogPrimary, in: Circle())

            Text("Pro機能です")
                .font(.headline)

            Text("あなたの記録から、パフォーマンスが\n伸びる条件を見つけます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                Text("詳しく見る")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.physlogPrimary, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 32)
    }

    // MARK: - 注意書き

    private var disclaimer: some View {
        Text("この分析は記録された数値の関係を示すものであり、原因と結果を証明するものではありません。体調やパフォーマンスには記録していない要因も影響します。参考情報としてご覧ください。")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
    }
}

// MARK: - 散布図

struct ScatterPlot: View {
    let result: CorrelationResult

    /// 最小二乗法で求めた回帰直線の両端。描画できない場合は空配列。
    private var trendLine: [CorrelationPoint] {
        let xs = result.points.map(\.conditionValue)
        let ys = result.points.map(\.performanceValue)
        guard xs.count >= 2, let minX = xs.min(), let maxX = xs.max(), minX != maxX else { return [] }

        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var num = 0.0, den = 0.0
        for (x, y) in zip(xs, ys) {
            num += (x - meanX) * (y - meanY)
            den += (x - meanX) * (x - meanX)
        }
        guard den > 0 else { return [] }

        let slope = num / den
        let intercept = meanY - slope * meanX

        return [
            CorrelationPoint(date: Date(), conditionValue: minX, performanceValue: slope * minX + intercept),
            CorrelationPoint(date: Date(), conditionValue: maxX, performanceValue: slope * maxX + intercept)
        ]
    }

    var body: some View {
        Chart {
            ForEach(result.points) { point in
                PointMark(
                    x: .value(result.conditionVar.rawValue, point.conditionValue),
                    y: .value(result.performanceVar.label, point.performanceValue)
                )
                .foregroundStyle(Color.physlogPurple.opacity(0.75))
                .symbolSize(60)
            }

            // RuleMark は水平・垂直の線しか引けないため、
            // 傾きのある回帰直線は2点を結ぶ LineMark で描く
            ForEach(trendLine) { point in
                LineMark(
                    x: .value(result.conditionVar.rawValue, point.conditionValue),
                    y: .value(result.performanceVar.label, point.performanceValue),
                    series: .value("系列", "回帰直線")
                )
                .foregroundStyle(Color.physlogOrange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.1f", v)).font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v >= 1000 ? "\(Int(v))" : String(format: "%.1f", v))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 240)
    }
}
