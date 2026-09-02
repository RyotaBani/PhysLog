import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store

    @State private var selectedProductID = ProStore.ProductID.yearly
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showRestoreResult = false
    @State private var restoreSucceeded = false

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedProductID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    benefits

                    if store.isLoadingProducts {
                        ProgressView().padding(.vertical, 40)
                    } else if store.loadFailed {
                        loadFailedView
                    } else {
                        planPicker
                        purchaseButton
                    }

                    legalFooter
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("PhysLog Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("復元") { Task { await restore() } }
                        .font(.subheadline)
                }
            }
            .task { await store.loadProducts() }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert(restoreSucceeded ? "復元しました" : "購入が見つかりません",
                   isPresented: $showRestoreResult) {
                Button("OK") { if restoreSucceeded { dismiss() } }
            } message: {
                Text(restoreSucceeded
                     ? "Pro機能がご利用いただけます。"
                     : "このApple IDでの購入履歴が見つかりませんでした。")
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 44))
                .foregroundStyle(Color.physlogPrimary)
                .frame(width: 84, height: 84)
                .background(Color.physlogPrimary.opacity(0.12), in: Circle())

            Text("記録から、伸びる条件を見つける")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("睡眠や疲労とパフォーマンスの関係を分析し、\n広告のない環境で記録に集中できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    // MARK: - 特典

    private var benefits: some View {
        VStack(spacing: 12) {
            BenefitRow(
                icon: "chart.dots.scatter",
                color: .physlogPurple,
                title: "コンディション分析",
                detail: "睡眠・疲労・体調とパフォーマンスの関係を可視化します"
            )
            BenefitRow(
                icon: "megaphone.fill",
                color: .physlogOrange,
                title: "広告の非表示",
                detail: "すべての画面から広告がなくなります"
            )
            BenefitRow(
                icon: "heart.fill",
                color: .physlogPink,
                title: "開発の継続",
                detail: "個人開発のアプリです。今後の機能追加を支えられます"
            )
        }
        .padding(.horizontal)
    }

    // MARK: - プラン選択

    private var planPicker: some View {
        VStack(spacing: 10) {
            ForEach(store.products) { product in
                PlanRow(
                    product: product,
                    isSelected: selectedProductID == product.id,
                    isRecommended: product.id == ProStore.ProductID.yearly,
                    savingLabel: savingLabel(for: product)
                ) {
                    selectedProductID = product.id
                }
            }
        }
        .padding(.horizontal)
    }

    /// 月額との比較で年額の割安感を出す
    private func savingLabel(for product: Product) -> String? {
        guard product.id == ProStore.ProductID.yearly,
              let monthly = store.products.first(where: { $0.id == ProStore.ProductID.monthly })
        else { return nil }

        let yearlyIfMonthly = monthly.price * 12
        guard yearlyIfMonthly > product.price else { return nil }

        let rate = ((yearlyIfMonthly - product.price) / yearlyIfMonthly) * 100
        return "約\(Int(NSDecimalNumber(decimal: rate).doubleValue))%お得"
    }

    // MARK: - 購入ボタン

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(selectedProduct?.isLifetime == true ? "購入する" : "はじめる")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.physlogPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(isPurchasing || selectedProduct == nil)

            if let product = selectedProduct, !product.isLifetime {
                Text("\(product.priceLabel)・いつでも解約できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var loadFailedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("価格を読み込めませんでした")
                .font(.subheadline.weight(.medium))
            Text("通信環境をご確認のうえ、もう一度お試しください。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("再読み込み") {
                Task { await store.loadProducts() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 30)
    }

    // MARK: - 法的表記（サブスクリプションでは必須）

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text("サブスクリプションは期間終了の24時間前までに解約されない限り自動更新されます。解約は iPhone の「設定」→ Apple ID →「サブスクリプション」からいつでも行えます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("プライバシーポリシー", destination: URL(string: "https://ryotabani.github.io/physlog/privacy.html")!)
            }
            .font(.caption2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    // MARK: - 処理

    private func purchase() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        switch await store.purchase(product) {
        case .success:
            break               // onChange(of: isPro) で閉じる
        case .cancelled:
            break
        case .pending:
            errorMessage = "購入の承認待ちです。承認され次第、自動的に反映されます。"
        case .failed(let message):
            errorMessage = message
        }
    }

    private func restore() async {
        restoreSucceeded = await store.restore()
        showRestoreResult = true
    }
}

// MARK: - 部品

private struct BenefitRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        Card(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct PlanRow: View {
    let product: Product
    let isSelected: Bool
    let isRecommended: Bool
    let savingLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.physlogPrimary : Color.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(planName)
                            .font(.subheadline.weight(.semibold))
                        if isRecommended {
                            Text("おすすめ")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.physlogPrimary, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    if let savingLabel {
                        Text(savingLabel)
                            .font(.caption)
                            .foregroundStyle(Color.physlogAccent)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.physlogPrimary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var planName: String {
        switch product.id {
        case ProStore.ProductID.monthly:  return "月額プラン"
        case ProStore.ProductID.yearly:   return "年額プラン"
        case ProStore.ProductID.lifetime: return "買い切り"
        default: return product.displayName
        }
    }
}
