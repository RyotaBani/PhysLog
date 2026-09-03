import SwiftUI

// MARK: - 公開インターフェース
//
// このファイルは Google Mobile Ads SDK が未導入でもコンパイルが通るように
// `#if canImport(GoogleMobileAds)` で分岐している。
//
//   SDK 未導入 → 何も表示しない（レイアウトにも影響しない）
//   SDK 導入済 → 実際のバナーを表示
//
// つまり「先にコードを入れておいて、あとから Xcode でパッケージを追加する」
// という順序で作業できる。

/// 画面下部に差し込むバナー広告。
/// 読み込みに失敗した場合は高さ0に畳まれ、空白の帯が残らない。
struct AdBannerView: View {
    @Environment(ProStore.self) private var store

    var body: some View {
        // Pro 購入者には表示しない（レイアウト上の余白も残さない）。
        // 課金導線を出していない構成では購入者が存在しないため、全員に表示される。
        if AdConfig.isEnabled && !(FeatureFlags.isProEnabled && store.isPro) {
            AdBannerContent()
        }
    }
}

/// 任意のビューの下端にバナーを差し込む修飾子。
/// `.safeAreaInset` を使うため、スクロール内容が広告の裏に隠れない。
extension View {
    /// 画面の下端にバナーを差し込む。
    ///
    /// **必ず NavigationStack の「内側」に適用すること。**
    /// NavigationStack は UIKit ベースのため、外側から注入した safeAreaInset を
    /// 内部のスクロール領域へ伝えない。外側に付けるとバナーがコンテンツに重なり、
    /// 一番下のボタンや FAB が隠れてしまう。
    ///
    /// VStack で積む方法も試したが、ScrollView の高さ計算が壊れて
    /// スクロールできなくなるため採用していない。
    ///
    /// push で表示される画面（InsightsView など）には個別に適用する。
    func adBanner() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            AdBannerView()
        }
    }

    /// 画面右下に追加ボタンを浮かせる。
    ///
    /// safeAreaInset で差し込むことで、外側の広告バナーの inset と積み重なり、
    /// バナーの上に正しく配置される。
    /// リスト末尾の行がボタンに隠れなくなる利点もある。
    func floatingAddButton(action: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            FloatingAddButton(action: action)
        }
    }
}

// MARK: - SDK 導入済みの実装

#if canImport(GoogleMobileAds)
import GoogleMobileAds

private struct AdBannerContent: View {

    /// 読み込みの状態。
    /// 失敗時に高さ0まで畳むため、単純な Bool ではなく3状態で持つ。
    enum LoadState: Equatable {
        case loading   // 場所は確保するが中身は見せない（読み込み中のちらつき防止）
        case loaded    // 実際のバナー高さで表示
        case failed    // 在庫なし・オフラインなど。空の帯を残さないよう畳む
    }

    @State private var state: LoadState = .loading
    @State private var height: CGFloat = AdConfig.reservedHeight

    /// 表示上の高さ。
    ///
    /// 読み込み中も実際のバナー高さを確保しておく。
    /// 固定値（50pt）で確保してから実寸に切り替えると、
    /// アダプティブバナーの高さ次第で最大 100pt 近くレイアウトが跳ねるため。
    private var displayHeight: CGFloat {
        state == .failed ? 0 : height
    }

    var body: some View {
        GeometryReader { geo in
            AdBannerRepresentable(
                width: geo.size.width,
                state: $state,
                height: $height
            )
        }
        .frame(height: displayHeight)
        .frame(maxWidth: .infinity)
        .background(state == .failed ? Color.clear : Color(.secondarySystemBackground))
        .opacity(state == .loaded ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: state)
        .animation(.easeInOut(duration: 0.25), value: height)
    }
}

private struct AdBannerRepresentable: UIViewRepresentable {
    let width: CGFloat
    @Binding var state: AdBannerContent.LoadState
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> BannerView {
        // 画面幅に合わせた「アンカー型アダプティブバナー」を要求する。
        // currentOrientationAnchoredAdaptiveBanner は非推奨になったため
        // largeAnchoredAdaptiveBanner を使う。高さは 50〜150pt の範囲で
        // 端末に応じて決まり、従来（50〜90pt）より高くなることがある。
        let size = largeAnchoredAdaptiveBanner(width: max(width, 320))

        let banner = BannerView(adSize: size)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = context.coordinator.rootViewController
        banner.load(Request())

        DispatchQueue.main.async {
            height = size.size.height
        }
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // 回転などで幅が変わったときだけサイズを取り直す
        let newSize = largeAnchoredAdaptiveBanner(width: max(width, 320))
        if abs(banner.adSize.size.width - newSize.size.width) > 1 {
            banner.adSize = newSize
            DispatchQueue.main.async {
                height = newSize.size.height
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: $state)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let state: Binding<AdBannerContent.LoadState>

        init(state: Binding<AdBannerContent.LoadState>) {
            self.state = state
        }

        /// バナーに rootViewController が必要なため、現在の window から取得する
        var rootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .keyWindow?.rootViewController
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            state.wrappedValue = .loaded
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            // 在庫がない・オフラインなどで日常的に起きる。
            // 空の帯を残さないよう高さ0まで畳む。リトライは SDK 側に任せる。
            state.wrappedValue = .failed
            #if DEBUG
            print("[Ad] バナー読み込み失敗: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - SDK 未導入時のスタブ

#else

private struct AdBannerContent: View {
    var body: some View {
        #if DEBUG
        // 開発中に「広告枠がここに入る」ことが分かるようにしておく
        Text("広告枠（SDK 未導入）")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: AdConfig.reservedHeight)
            .background(Color(.secondarySystemBackground))
            .overlay(alignment: .top) { Divider() }
        #else
        EmptyView()
        #endif
    }
}

#endif
