import Foundation
import StoreKit

/// Pro の購入状態を一元管理する。
///
/// 「広告を消す」「相関分析を開く」の両方がここの `isPro` を見て判断するため、
/// 課金判定のロジックはこのクラスの外に散らばらせないこと。
@Observable
@MainActor
final class ProStore {

    static let shared = ProStore()

    // MARK: - 商品ID

    enum ProductID {
        static let monthly  = "com.ryotabani.PhysLog.pro.monthly"
        static let yearly   = "com.ryotabani.PhysLog.pro.yearly"
        static let lifetime = "com.ryotabani.PhysLog.pro.lifetime"

        /// 表示順（年額を中央かつ推奨として置く）
        static let all: [String] = [monthly, yearly, lifetime]
    }

    // MARK: - 状態

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var loadFailed = false

    /// Pro 機能が使えるか。UI 側はこの1つだけを見る。
    var isPro: Bool { !purchasedProductIDs.isEmpty }

    /// 監視対象の状態ではないため @ObservationIgnored を付ける。
    /// @Observable と deinit の組み合わせで並行性チェックに引っかかるが、
    /// 代入は init 内のみ、Task 自体は Sendable なので nonisolated(unsafe) で安全。
    @ObservationIgnored
    private nonisolated(unsafe) var updateListener: Task<Void, Never>?

    // MARK: - 初期化

    private init() {
        // アプリ外での購入・返金・失効を取りこぼさないよう常時監視する
        updateListener = Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    deinit {
        updateListener?.cancel()
    }

    // MARK: - 読み込み

    func load() async {
        // 課金導線を出していない構成では App Store への問い合わせも行わない。
        // 既に購入済みのユーザーがいる可能性を考え、権利の確認だけは続ける。
        await refreshEntitlements()
        guard FeatureFlags.isProEnabled else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        loadFailed = false
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: ProductID.all)
            // 指定した順に並べ替える
            products = ProductID.all.compactMap { id in
                fetched.first { $0.id == id }
            }
            loadFailed = products.isEmpty
        } catch {
            loadFailed = true
            #if DEBUG
            print("[Pro] 商品情報の取得に失敗: \(error.localizedDescription)")
            #endif
        }
    }

    /// 現在有効な購入を洗い直す
    func refreshEntitlements() async {
        var active: Set<String> = []

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }

            // 返金・失効済みは除外する
            if transaction.revocationDate != nil { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }

            active.insert(transaction.productID)
        }

        purchasedProductIDs = active
    }

    // MARK: - 購入

    enum PurchaseOutcome {
        case success
        case cancelled
        case pending      // ファミリー共有の承認待ちなど
        case failed(String)
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("購入の検証に失敗しました。")
                }
                await transaction.finish()
                await refreshEntitlements()
                return .success

            case .userCancelled:
                return .cancelled

            case .pending:
                return .pending

            @unknown default:
                return .failed("不明な結果が返されました。")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// 購入の復元（機種変更・再インストール時）
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return isPro
        } catch {
            #if DEBUG
            print("[Pro] 復元に失敗: \(error.localizedDescription)")
            #endif
            return false
        }
    }
}

// MARK: - 表示用の補助

extension Product {

    /// 「¥2,000 / 年」のような表記
    var priceLabel: String {
        guard let period = subscription?.subscriptionPeriod else {
            return displayPrice
        }
        return "\(displayPrice) / \(period.japaneseLabel)"
    }

    /// 買い切りかどうか
    var isLifetime: Bool { subscription == nil }
}

extension Product.SubscriptionPeriod {
    var japaneseLabel: String {
        switch unit {
        case .day:   return value == 1 ? "日" : "\(value)日"
        case .week:  return value == 1 ? "週" : "\(value)週"
        case .month: return value == 1 ? "月" : "\(value)ヶ月"
        case .year:  return value == 1 ? "年" : "\(value)年"
        @unknown default: return ""
        }
    }
}
