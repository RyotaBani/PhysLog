import SwiftUI

// MARK: - オンボーディング

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName")  private var userName = ""
    @AppStorage("userSport") private var userSport = ""

    @State private var page = 0
    @State private var nameInput = ""
    @State private var sportInput = ""

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                featurePage.tag(1)
                profilePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomBar
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: ページ1 — ようこそ

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.physlogPrimary.opacity(0.12))
                    .frame(width: 150, height: 150)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(Color.physlogPrimary)
            }

            VStack(spacing: 10) {
                Text("PhysLog")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("身体の変化を、ずっと残す。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("体重や筋トレだけでなく、垂直跳び・50m走・握力といった\n競技につながる数値も記録できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: ページ2 — できること

    private var featurePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()

            Text("できること")
                .font(.title.bold())
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(
                    icon: "scalemass.fill",
                    color: .physlogPrimary,
                    title: "身体測定",
                    detail: "体重・体脂肪率・筋肉量を記録"
                )
                FeatureRow(
                    icon: "figure.run",
                    color: .physlogAccent,
                    title: "身体能力",
                    detail: "垂直跳び・50m走・握力など15種目"
                )
                FeatureRow(
                    icon: "dumbbell.fill",
                    color: .physlogOrange,
                    title: "トレーニング",
                    detail: "種目・重量・回数から総挙上量を自動計算"
                )
                FeatureRow(
                    icon: "heart.fill",
                    color: .physlogPink,
                    title: "コンディション",
                    detail: "睡眠・疲労度・体調を1〜5で記録"
                )
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .physlogPurple,
                    title: "グラフ",
                    detail: "期間を切り替えて成長を可視化"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: ページ3 — プロフィール

    private var profilePage: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 8) {
                Text("はじめる準備")
                    .font(.title.bold())
                Text("あとから設定タブで変更できます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                LabeledField(
                    icon: "person.fill",
                    placeholder: "お名前（任意）",
                    text: $nameInput
                )
                LabeledField(
                    icon: "sportscourt.fill",
                    placeholder: "競技名（任意）",
                    text: $sportInput
                )
            }
            .padding(.horizontal, 32)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("入力した内容は端末内にのみ保存されます")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
    }

    // MARK: 下部ボタン

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    complete()
                }
            } label: {
                Text(page < 2 ? "次へ" : "はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.physlogPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }

            Button("スキップ") { complete() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(page < 2 ? 1 : 0)
                .disabled(page >= 2)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func complete() {
        userName = nameInput.trimmingCharacters(in: .whitespaces)
        userSport = sportInput.trimmingCharacters(in: .whitespaces)
        withAnimation { hasCompletedOnboarding = true }
    }
}

// MARK: - 部品

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LabeledField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.physlogPrimary)
                .frame(width: 24)
            TextField(placeholder, text: $text)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    OnboardingView()
}
