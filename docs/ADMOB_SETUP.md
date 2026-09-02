# AdMob SDK 追加手順

コード側の下準備は完了しています。**残っているのは Xcode でのパッケージ追加だけ**です。

| 項目 | 状態 |
|------|------|
| `-ObjC` リンカフラグ | 設定済み |
| `GADApplicationIdentifier`（本番ID） | 設定済み |
| `NSUserTrackingUsageDescription` | 設定済み |
| `SKAdNetworkItems` | 設定済み |
| バナー表示コード | 実装済み（`#if canImport` でガード） |
| **SPM でのパッケージ追加** | **未実施** |

SDK は Google が無料で配布しています。購入もライセンス費用も不要です。

---

## Step 1. パッケージを追加する（Xcode での手動操作）

この操作だけはコマンドラインから確実に行えないため、Xcode の GUI で実行してください。

```
1. Xcode で PhysLog.xcodeproj を開く
2. メニュー File → Add Package Dependencies...
3. 右上の検索欄に貼り付け:
   https://github.com/googleads/swift-package-manager-google-mobile-ads.git
4. Dependency Rule: Up to Next Major Version（既定のまま）
5. Add Package
6. 解決後のダイアログで Package Product「GoogleMobileAds」の
   Add to Target が「PhysLog」になっていることを確認 → Add Package
```

初回は依存の解決に数分かかります。

---

## Step 2. ビルドして表示を確認する

```bash
cd ~/PhysLog && ./run.sh
```

追加が成功していれば、`#if canImport(GoogleMobileAds)` の分岐が実 SDK 側に切り替わり、
プレースホルダの「広告枠（SDK 未導入）」が**実際のテストバナー**に変わります。

### 確認すること

- [ ] 「Test Ad」と書かれたバナーが画面下部に表示される
- [ ] 記録タブの右下「＋」ボタンが**バナーに隠れていない**
- [ ] メニュータブを最下部までスクロールし、「メニューを作成」が押せる
- [ ] 設定タブを最下部までスクロールできる
- [ ] グラフタブのグラフがバナーに重なっていない
- [ ] 機内モード（シミュレータでは Wi-Fi を切る）で起動しても空の帯が残らない

**バナーの実高さはプレースホルダ（50pt）と異なります。**
アダプティブバナーは画面幅に応じて 50〜100pt の範囲で変わるため、
レイアウトが崩れないかをここで必ず確認してください。

---

## Step 3. 絶対にやってはいけないこと

**表示された広告を自分でタップしないでください。**

テスト広告であれば問題ありませんが、誤って本番広告をタップすると
「無効なトラフィック」と判定され、**AdMob アカウントが永久停止される**ことがあります。

`AdConfig.swift` には DEBUG ビルドで必ずテストIDを使う分岐が入っているため、
Xcode から実行している限りは安全です。この分岐は外さないでください。

```swift
static var bannerUnitID: String {
    #if DEBUG
    return testBannerUnitID     // ← 開発中は必ずこちら
    #else
    return productionBannerUnitID
    #endif
}
```

---

## Step 4. 本番IDへの差し替え（**完了済み**）

以下の値を設定済みです。

| 項目 | 値 |
|------|-----|
| App ID | `ca-app-pub-5619606203492593~5658384269` |
| バナー広告ユニットID | `ca-app-pub-5619606203492593/8176736392` |

DEBUG ビルドでは `AdConfig.swift` の分岐によりテストIDが使われるため、
Xcode から実行している限り表示は「Test Ad」のままです。これが正常です。
本番広告が配信されるのは Release ビルド（Archive）以降になります。

<details>
<summary>参考: 差し替え手順（別アプリで再利用する場合）</summary>


### AdMob アカウントの作成

1. https://admob.google.com にアクセスし、Google アカウントでログイン
2. 「アプリを追加」→ プラットフォーム: iOS
3. 「App Store に公開済みですか？」→ **いいえ**
4. アプリ名: PhysLog を入力して追加
5. 表示された **アプリ ID**（`ca-app-pub-XXXXXXXX~XXXXXXXX`）を控える
6. 「広告ユニット」→「バナー」を選択、名前は「PhysLog Banner」など
7. 発行された **広告ユニット ID**（`ca-app-pub-XXXXXXXX/XXXXXXXX`）を控える

### 差し替える箇所は2ファイル

**`PhysLog/Ads/AdConfig.swift`**

```swift
private static let productionAppID = "ca-app-pub-XXXXXXXX~XXXXXXXX"
private static let productionBannerUnitID = "ca-app-pub-XXXXXXXX/XXXXXXXX"
```

**`Info.plist`**

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXX~XXXXXXXX</string>
```

> **区切り記号に注意**
> アプリ ID は `~`（チルダ）、広告ユニット ID は `/`（スラッシュ）です。
> 取り違えると起動直後に `GADInvalidInitializationException` でクラッシュします。

### 差し替え後の確認

```bash
cd ~/PhysLog && ./run.sh
```

DEBUG ビルドではテストIDが使われるため、**表示は「Test Ad」のままで正常**です。
本番広告が出るのは Release ビルド（Archive）以降になります。

---

</details>

## Step 5. 配信地域の判断

Google は EEA・英国のユーザーに広告を配信する場合、認定 CMP による同意取得を義務付けています。

| 方針 | 対応 |
|------|------|
| **日本のみ配信**（初回リリース推奨） | App Store Connect の配信地域で日本のみを選択。追加実装は不要 |
| 全世界配信 | Google UMP SDK を追加し、同意フローを実装 |

まず日本のみで公開し、必要になってから広げるのが現実的です。

---

## トラブル時の対処

### `Undefined symbol` でリンクエラーになる

`-ObjC` フラグが効いていない可能性があります。確認：

```bash
grep -A 3 "OTHER_LDFLAGS" PhysLog.xcodeproj/project.pbxproj
```

`"-ObjC"` が2箇所（Debug / Release）にあれば正常です。

### バナーが表示されない

1. コンソールに `[Ad] バナー読み込み失敗` が出ていないか確認
2. 出ている場合はネットワーク接続を確認
3. `GADApplicationIdentifier` が `~` 区切りになっているか確認

読み込みに失敗した場合、バナーは高さ0に畳まれる実装になっています。
空の帯が残らないのは意図した動作です。

### パッケージの解決に失敗する

```
File → Packages → Reset Package Caches
```

を実行してから再度お試しください。
