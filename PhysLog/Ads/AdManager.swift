import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// 広告SDKの初期化と、トラッキング許可の取得をまとめる。
enum AdManager {

    /// アプリ起動時に一度だけ呼ぶ。
    static func start() {
        guard AdConfig.isEnabled else { return }

        // App ID の記載漏れ・取り違えは起動直後のクラッシュにつながるため、
        // 開発中に気づけるよう照合しておく（DEBUG のみ動作）。
        AdConfig.verifyAppIDConsistency()

        #if canImport(GoogleMobileAds)
        MobileAds.shared.start()
        #endif
    }

    /// ATT（トラッキング許可）ダイアログを表示する。
    ///
    /// 許可されれば広告のパーソナライズが有効になり単価が上がるが、
    /// 拒否されても広告自体は非パーソナライズで配信されるため収益はゼロにならない。
    ///
    /// 起動直後に出すと拒否率が高く、また Apple の審査でも
    /// 「文脈なくダイアログを出す」ことが指摘されやすい。
    /// そのため初回起動から少し遅らせて呼び出す想定にしている。
    @MainActor
    static func requestTrackingAuthorizationIfNeeded() async {
        guard AdConfig.isEnabled else { return }

        #if canImport(AppTrackingTransparency)
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        // システムダイアログが起動アニメーションと重ならないよう少し待つ
        try? await Task.sleep(for: .seconds(1.5))
        _ = await ATTrackingManager.requestTrackingAuthorization()
        #endif
    }
}
