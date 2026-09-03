# 広告（AdMob）導入手順

コード側の実装はすべて完了しています。残っているのは **Xcode でのSDK追加** と **本番IDの差し替え** の2つです。

---

## 設計の考え方

`#if canImport(GoogleMobileAds)` で分岐しているため、**SDK を追加していない状態でもプロジェクトはビルドできます。**

| 状態 | 挙動 |
|------|------|
| SDK 未追加 | 広告は表示されない（DEBUGビルドでは「広告枠」のプレースホルダのみ） |
| SDK 追加後 | コード変更なしで実際のバナーが表示される |

先にビルドを通してアプリの動作確認をしてから、広告を有効化する順序で進められます。

---

## Step 1. SDK を追加する

Xcode で以下を実行します。

```
File → Add Package Dependencies...
→ 検索欄に貼り付け:
   https://github.com/googleads/swift-package-manager-google-mobile-ads.git
→ Dependency Rule: Up to Next Major Version
→ Add Package
→ Package Product: GoogleMobileAds を PhysLog ターゲットに追加
```

`-ObjC` リンカフラグはビルド設定に追加済みです。これが無いとリンクエラーになります。

追加後にビルドすれば、この時点でテスト広告が表示されます。

---

## Step 2. 動作確認

```
⌘R で実行 → 各タブの下部にテストバナーが出ることを確認
```

確認すべき点:

- [ ] バナーがタブバーの上に表示される
- [ ] スクロールしてもコンテンツが広告の裏に隠れない
- [ ] 記録の追加シートを開いたとき広告が重ならない
- [ ] 機内モードで起動しても空の帯が残らない（畳まれる）
- [ ] 画面幅の異なる端末（iPhone SE など）でバナーが崩れない

**テスト広告以外は絶対に自分でタップしないでください。** 自分の広告をクリックすると無効なトラフィックと判定され、AdMob アカウントが永久停止されることがあります。

---

## Step 3. AdMob アカウントと本番ID

1. https://admob.google.com でアカウント作成
2. 「アプリ」→「アプリを追加」→ iOS →「App Store に未公開」を選択
3. アプリ名: PhysLog を登録 → **App ID**（`ca-app-pub-XXXX~XXXX`）を取得
4. 「広告ユニット」→「バナー」を作成 → **広告ユニットID**（`ca-app-pub-XXXX/XXXX`）を取得

取得した2つのIDを差し替えます。

### 差し替え箇所1: `PhysLog/Ads/AdConfig.swift`

```swift
private static let productionAppID = "ca-app-pub-XXXX~XXXX"          // ← App ID
private static let productionBannerUnitID = "ca-app-pub-XXXX/XXXX"   // ← 広告ユニットID
```

### 差し替え箇所2: `PhysLog/Info.plist`

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXX~XXXX</string>   <!-- ← App ID（区切りは ~） -->
```

> `~` と `/` を取り違えると起動直後に `GADInvalidInitializationException` でクラッシュします。
> App ID は `~`、広告ユニットIDは `/` です。

DEBUG ビルドでは `AdConfig.swift` の分岐により常にテストIDが使われるため、開発中に誤って本番IDへアクセスする事故は起きません。

---

## Step 4. 配信地域の判断（重要）

Google は EEA・英国のユーザーに広告を配信する場合、認定CMPによる同意取得を義務付けています。

| 方針 | 対応内容 |
|------|---------|
| **A. 日本のみ配信**（初回リリース推奨） | App Store Connect の配信地域で日本のみを選択。追加実装は不要 |
| B. 全世界配信 | Google UMP SDK を追加し同意フローを実装 |

まずは A で公開し、必要になってから B へ移行するのが現実的です。

---

## Step 5. App Store Connect の申告を変更する

**広告導入により、プライバシー申告の内容が変わります。** ここを直さないまま提出すると虚偽申告になります。

- App Privacy の回答を「データを収集しません」→「収集します」に変更
- 収集項目として識別子・使用状況データ・診断・大まかな位置情報を申告

詳細な回答内容は `docs/AppStore.md` の「App Privacy」節に記載しています。

プライバシーポリシー（`docs/privacy.html`）も広告記載ありの内容に更新済みです。公開URLの内容が最新になっているか確認してください。

---

## 収益の目安について

正直なところ、バナー広告の収益はダウンロード数に強く依存します。

日本のバナー広告の eCPM はおおむね **¥100〜400 / 1000インプレッション** 程度です。仮に MAU 100人が1日2回起動して各3画面見るとすると、月間インプレッションは約18,000。これで **月数百円〜2,000円程度** になります。

つまり **数千DL規模に届くまでは、収益はサーバー代にもならない水準**だと考えておくのが現実的です。

当初の企画では「収益の出口は受託開発の実績」とされていました。その観点では、以下のトレードオフがあります。

| | 広告なし | 広告あり |
|---|---|---|
| ポートフォリオとしての見栄え | クリーンで訴求しやすい | 「無料アプリの体裁」に見える |
| 審査・保守の手間 | 少ない | プライバシー申告・同意管理・SDK更新が発生 |
| 収益 | ゼロ | 規模次第。小規模なら数百円 |

判断材料として、`AdConfig.isEnabled` を `false` にすれば広告を完全に無効化できるようにしてあります。一度リリースして反応を見てから決める、という進め方も可能です。

---

## 広告を止めたくなったら

`PhysLog/Ads/AdConfig.swift` の1行を変えるだけです。

```swift
static let isEnabled = false
```

SDK自体は残りますが広告リクエストは発生しなくなります。完全に取り除く場合は、Package Dependencies から `GoogleMobileAds` を削除し、`Info.plist` の広告関連キーとプライバシー申告も戻してください。
