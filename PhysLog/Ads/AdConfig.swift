import Foundation

/// 広告まわりの設定を一箇所に集約する。
///
/// 本番IDへの差し替えは `productionAppID` / `productionBannerUnitID` の
/// 2箇所だけを書き換えれば済むようにしてある。
enum AdConfig {

    // MARK: - 有効・無効

    /// 広告全体のマスタースイッチ。
    /// トラブル時や審査用ビルドではここを false にすれば広告が完全に消える。
    static let isEnabled = true

    // MARK: - ID

    /// Google が公開しているテスト用 App ID（`~` 区切り）。
    /// コードからは参照しない。Info.plist を書き換える際の参照用に残している。
    private static let testAppID = "ca-app-pub-3940256099942544~1458002511"

    /// Google が公開しているテスト用バナー広告ユニットID（`/` 区切り）
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    /// AdMob 管理画面で発行された本番 App ID（区切りは `~`）。
    /// 実際に使われるのは Info.plist の `GADApplicationIdentifier` の値であり、
    /// ここは両者を突き合わせて確認するための控え。
    private static let productionAppID = "ca-app-pub-5619606203492593~5658384269"

    /// AdMob 管理画面で発行された本番バナー広告ユニットID（区切りは `/`）
    private static let productionBannerUnitID = "ca-app-pub-5619606203492593/8176736392"

    // MARK: - 実際に使われる値

    /// 実際にコードから参照されるのはこの広告ユニットIDだけ。
    /// App ID は SDK が Info.plist の `GADApplicationIdentifier` を直接読むため、
    /// ここで切り替えることはできない（Info.plist には本番IDを記載している）。
    ///
    /// DEBUG ビルドでは必ずテストの広告ユニットを使う。
    /// 開発中に本番の広告を表示・タップすると「無効なトラフィック」と判定され、
    /// 最悪の場合 AdMob アカウントが停止されるため、この分岐は外さないこと。
    static var bannerUnitID: String {
        #if DEBUG
        return testBannerUnitID
        #else
        return productionBannerUnitID
        #endif
    }

    /// 本番IDが未設定のままかどうか（設定漏れの検知に使う）
    static var isUsingPlaceholderID: Bool {
        productionBannerUnitID.contains("0000000000")
    }

    /// Info.plist の `GADApplicationIdentifier` と `productionAppID` の食い違いを検知する。
    ///
    /// App ID は2箇所（このファイルと Info.plist）に書く必要があり、
    /// 片方だけ更新する事故が起きやすい。DEBUG ビルドの起動時に照合して
    /// ずれていれば警告を出す。
    static func verifyAppIDConsistency() {
        #if DEBUG
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String

        guard let plistValue, !plistValue.isEmpty else {
            print("[Ad] 警告: Info.plist に GADApplicationIdentifier がありません。起動時にクラッシュします。")
            return
        }
        if plistValue.contains("/") {
            print("[Ad] 警告: GADApplicationIdentifier が `/` 区切りです。App ID は `~` 区切りです。")
        }
        if plistValue != testAppID && plistValue != productionAppID {
            print("[Ad] 警告: Info.plist の App ID が AdConfig の値と一致しません。")
            print("       Info.plist : \(plistValue)")
            print("       AdConfig   : \(productionAppID)")
        }
        if isUsingPlaceholderID {
            print("[Ad] 警告: 広告ユニットIDがプレースホルダのままです。")
        }
        #endif
    }

    // MARK: - 表示制御

    /// バナー高さの初期値。
    ///
    /// 実際の高さは largeAnchoredAdaptiveBanner が端末幅から決めるため（50〜150pt）、
    /// この値が使われるのは SDK 未導入時のプレースホルダと、
    /// 実寸が確定するまでのごく短い間だけ。
    static let reservedHeight: CGFloat = 50
}
