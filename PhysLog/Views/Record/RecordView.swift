import SwiftUI

enum RecordCategory: String, CaseIterable, Identifiable {
    case body      = "身体測定"
    case ability   = "身体能力"
    case training  = "トレーニング"
    case condition = "コンディション"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .body:      return "scalemass.fill"
        case .ability:   return "figure.run"
        case .training:  return "dumbbell.fill"
        case .condition: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .body:      return .physlogPrimary
        case .ability:   return .physlogAccent
        case .training:  return .physlogOrange
        case .condition: return .physlogPink
        }
    }
}

struct RecordView: View {
    @State private var selected: RecordCategory = .body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // カテゴリは4つで固定なので、横スクロールにせず必ず画面内に収める。
                // 横スクロールだと右端が見切れ、隠れた項目に気づけない。
                HStack(spacing: 6) {
                    ForEach(RecordCategory.allCases) { category in
                        CategoryTab(
                            category: category,
                            isSelected: selected == category
                        ) {
                            selected = category
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))

                Divider()

                Group {
                    switch selected {
                    case .body:      BodyMeasurementListView()
                    case .ability:   PhysicalAbilityListView()
                    case .training:  TrainingListView()
                    case .condition: ConditionListView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
            .adBanner()
            .navigationTitle("記録")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 記録タブのカテゴリ切り替え。
/// アイコンを上、ラベルを下に置くことで横幅を抑え、
/// 小さい端末でも4つが1行に収まるようにしている。
struct CategoryTab: View {
    let category: RecordCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 15, weight: .medium))
                Text(category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                isSelected ? category.color : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .foregroundStyle(isSelected ? .white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.rawValue)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    RecordView()
        .modelContainer(PreviewData.container)
}
