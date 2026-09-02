import Foundation

/// リリース構成の切り替えを一箇所にまとめる。
///
/// v1.0 は「完全無料 + バナー広告」で出す。
/// Pro（課金）の実装は残してあるが、入口を塞いで表に出していない。
/// ユーザーが定着し、課金する価値のある機能（クラウド同期など）が
/// 揃った段階で `isProEnabled` を true にすれば有効化できる。
enum FeatureFlags {

    /// 課金導線を表示するか。
    ///
    /// false のとき:
    ///   - 設定画面の「Proにアップグレード」「購入を復元」が消える
    ///   - 分析画面のぼかしとロックが外れ、誰でも使える
    ///   - ペイウォールはどこからも開かない
    ///   - StoreKit への商品問い合わせも行わない
    ///
    /// StoreKit のコードや PaywallView は残してあるため、
    /// true に戻すだけで課金導線が復活する。
    static let isProEnabled = false

    /// 相関分析を無料で開放するか。
    ///
    /// この機能が PhysLog の差別化そのものなので、
    /// v1.0 では全ユーザーに開放して認知を取りにいく。
    /// 既に無料で出した機能を後から有料化すると反発を招くため、
    /// 将来課金する場合も、この機能ではなく新機能を対象にする想定。
    static let isInsightsFree = true

    /// 分析機能を利用できるか（購入状態を加味した最終判定）
    static func canUseInsights(isPro: Bool) -> Bool {
        if isInsightsFree { return true }
        return isPro
    }
}
