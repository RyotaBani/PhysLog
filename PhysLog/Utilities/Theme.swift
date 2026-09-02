import SwiftUI

// MARK: - カラーテーマ

extension Color {
    static let physlogPrimary = Color(red: 0.00, green: 0.53, blue: 1.00)
    static let physlogAccent  = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let physlogOrange  = Color(red: 1.00, green: 0.58, blue: 0.00)
    static let physlogPink    = Color(red: 1.00, green: 0.23, blue: 0.38)
    static let physlogPurple  = Color(red: 0.56, green: 0.35, blue: 0.97)
}

// MARK: - カードコンテナ

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 空状態

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 46))
                .foregroundStyle(Color.physlogPrimary.opacity(0.35))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - 1〜5 のスケール入力

struct ScalePicker: View {
    let title: String
    let lowLabel: String
    let highLabel: String
    let color: Color
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        value = (value == i) ? nil : i
                    } label: {
                        Text("\(i)")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(value == i ? color : Color(.tertiarySystemFill))
                            .foregroundStyle(value == i ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 数値入力行

struct NumberInputRow: View {
    let label: String
    let placeholder: String
    let unit: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
        }
    }
}

// MARK: - 選択チップ

struct Chip: View {
    let label: String
    let isSelected: Bool
    var icon: String? = nil
    var color: Color = .physlogPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.caption)
                }
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - フローティング追加ボタン

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.physlogPrimary, in: Circle())
                .shadow(color: Color.physlogPrimary.opacity(0.35), radius: 10, y: 4)
        }
        .padding(20)
    }
}

// MARK: - 日付フォーマット

extension Date {
    var shortJP: String {
        formatted(.dateTime.month(.defaultDigits).day().locale(Locale(identifier: "ja_JP")))
    }

    var relativeJP: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "今日" }
        if cal.isDateInYesterday(self) { return "昨日" }
        return shortJP
    }

    var weekdayJP: String {
        formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }
}

// MARK: - 横スクロールの端フェード

extension View {
    /// 横スクロール領域の右端を薄くフェードさせ、
    /// 「まだ項目が続く」ことを視覚的に示す。
    /// 項目数が可変で1画面に収めきれない場合にのみ使う。
    func fadeTrailingEdge() -> some View {
        self.mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.88),
                    .init(color: .black.opacity(0.15), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}
