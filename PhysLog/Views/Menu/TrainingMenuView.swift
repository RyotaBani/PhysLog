import SwiftUI

struct TrainingMenuView: View {
    @AppStorage("menuGoal")  private var storedGoal = TrainingGoal.strength.rawValue
    @AppStorage("menuLevel") private var storedLevel = ExperienceLevel.beginner.rawValue
    @AppStorage("menuDays")  private var days = 3

    @State private var showResult = false

    private var goal: TrainingGoal {
        TrainingGoal(rawValue: storedGoal) ?? .strength
    }

    private var level: ExperienceLevel {
        ExperienceLevel(rawValue: storedLevel) ?? .beginner
    }

    private var menu: [MenuDay] {
        MenuEngine.build(goal: goal, level: level, days: days)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    goalSection
                    levelSection
                    daysSection
                    generateButton

                    if showResult {
                        resultSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .adBanner()
            .navigationTitle("メニュー提案")
        }
    }

    // MARK: - 目的

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("目的")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(TrainingGoal.allCases) { item in
                    GoalTile(goal: item, isSelected: goal == item) {
                        storedGoal = item.rawValue
                        showResult = false
                    }
                }
            }
            .padding(.horizontal)

            Text(goal.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    // MARK: - レベル

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("トレーニング歴")
                .font(.headline)
                .padding(.horizontal)

            Card(padding: 12) {
                HStack(spacing: 8) {
                    ForEach(ExperienceLevel.allCases) { item in
                        Button {
                            storedLevel = item.rawValue
                            showResult = false
                        } label: {
                            VStack(spacing: 3) {
                                Text(item.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.detail)
                                    .font(.caption2)
                                    .opacity(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(level == item ? goal.color : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(level == item ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 週の日数

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("週あたりの実施日数")
                .font(.headline)
                .padding(.horizontal)

            Card(padding: 12) {
                HStack(spacing: 8) {
                    ForEach(2...5, id: \.self) { d in
                        Button {
                            days = d
                            showResult = false
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(d)")
                                    .font(.title3.bold())
                                Text("日")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(days == d ? goal.color : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(days == d ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 生成ボタン

    private var generateButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) { showResult = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("メニューを作成")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(goal.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .padding(.horizontal)
    }

    // MARK: - 結果

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.icon)
                    .foregroundStyle(goal.color)
                Text("\(goal.rawValue) / \(level.rawValue) / 週\(days)日")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal)

            ForEach(menu) { day in
                MenuDayCard(day: day, color: goal.color)
                    .padding(.horizontal)
            }

            Text("※ 提案は一般的なトレーニング原則に基づく目安です。痛みや違和感がある場合は中止し、必要に応じて専門家に相談してください。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
        }
    }
}

// MARK: - 目的タイル

struct GoalTile: View {
    let goal: TrainingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: goal.icon)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : goal.color)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? goal.color : goal.color.opacity(0.14), in: Circle())

                Text(goal.rawValue)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? goal.color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 日別カード

struct MenuDayCard: View {
    let day: MenuDay
    let color: Color

    @State private var isExpanded = true

    var body: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text(day.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(color)
                            .frame(width: 52, alignment: .leading)

                        Text(day.focus)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(item.sets)セット × \(item.reps)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(color)
                                }

                                if item.rest != "—" {
                                    Label("休憩 \(item.rest)", systemImage: "timer")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Text(item.tip)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)

                            if index < day.items.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TrainingMenuView()
}
