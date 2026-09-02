# ローンチ手順

上から順に実行すれば提出まで到達します。**並行して進められるものは並行**と記載しています。

---

## 現在地

| 項目 | 状態 |
|------|------|
| 実装 | 完了 |
| ビルド | 成功（シミュレータ動作確認済み） |
| アプリアイコン | 生成済み |
| スクリーンショット | 生成済み（1320×2868 / 5枚） |
| 申請文・プライバシーポリシー | 用意済み |
| iPhone専用に設定 | 完了 |
| **AdMob SDK 追加** | **未実施** |
| **Apple Developer Program** | **要確認** |
| **実機テスト** | **未実施** |
| **プライバシーポリシー公開** | **未実施** |

---

## Step 0. 先に始めておくもの（待ち時間があるため）

### Apple Developer Program（年 12,980円）

未登録なら**今すぐ申し込んでください。** 承認まで1〜2日かかることがあり、これが完了しないと提出できません。

https://developer.apple.com/programs/

登録済みなら次へ。

### AdMob アカウント

https://admob.google.com で作成します。こちらは即時です。

```
アプリを追加 → iOS → 「App Store に公開済みですか？」→ いいえ
→ アプリ名: PhysLog
→ アプリ ID（ca-app-pub-XXXX~XXXX）を控える
→ 広告ユニット → バナー → 広告ユニット ID（ca-app-pub-XXXX/XXXX）を控える
```

> **注意**: アプリ ID は `~`、広告ユニット ID は `/` です。取り違えると起動時にクラッシュします。

---

## Step 1. AdMob SDK を追加する（Xcode GUI）

```
Xcode で PhysLog.xcodeproj を開く
→ File → Add Package Dependencies...
→ https://github.com/googleads/swift-package-manager-google-mobile-ads.git
→ Add Package
→ Package Product「GoogleMobileAds」の Add to Target が「PhysLog」であることを確認
→ Add Package
```

SDK は無料です。追加すると `#if canImport(GoogleMobileAds)` の分岐が実 SDK 側に切り替わります。

### 追加後の確認

```bash
cd ~/PhysLog && ./run.sh
```

- [ ] 「Test Ad」バナーが画面下部に表示される
- [ ] **記録タブの「＋」がバナーに隠れていない**
- [ ] **メニュー・設定タブが最下部までスクロールできる**
- [ ] グラフがバナーに重なっていない

> 実バナーの高さはプレースホルダ（50pt）と異なります。
> レイアウトが崩れていないかここで必ず確認してください。

**表示された広告をタップしないでください。** DEBUG ビルドではテストIDが使われるため安全ですが、習慣にしないこと。

---

## Step 2. 本番IDに差し替える

**`PhysLog/Ads/AdConfig.swift`**

```swift
private static let productionAppID = "ca-app-pub-XXXX~XXXX"
private static let productionBannerUnitID = "ca-app-pub-XXXX/XXXX"
```

**`Info.plist`**

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXX~XXXX</string>
```

差し替え後も DEBUG ビルドでは「Test Ad」のままです。これが正常な動作です。

---

## Step 3. 実機テスト

シミュレータでは判断できない項目があります。**必ず実機で確認してください。**

```
Xcode → Signing & Capabilities → Team に自分の Apple ID
→ 実行先を iPhone に変更 → ⌘R
```

初回は iPhone 側で
`設定 → 一般 → VPNとデバイス管理 → デベロッパApp → 信頼`

### 必ず見る項目

- [ ] 体重入力で**数字キーボード**が出る
- [ ] キーボードが入力欄を隠さない（特にメモ欄）
- [ ] タブバー5項目を親指で押し分けられる
- [ ] 右下「＋」に親指が届く
- [ ] ダークモードで文字が読める
- [ ] 文字サイズを大きくしても崩れない
- [ ] 機内モードで起動しても落ちない・空の帯が残らない
- [ ] アイコンがホーム画面で正しく見える
- [ ] 削除→再インストールで落ちない

詳細は `docs/TESTING.md` にあります。

---

## Step 4. プライバシーポリシーを公開する（Step 1〜3 と並行可能）

App Store 提出でプライバシーポリシー URL は**必須**です。

### GitHub Pages を使う場合

```bash
cd ~/PhysLog
git init
git add .
git commit -m "feat: PhysLog v1.0"
gh repo create RyotaBani/PhysLog --public --source=. --push
```

```
GitHub → Settings → Pages
→ Source: Deploy from a branch
→ Branch: main / docs
→ Save
```

数分後に公開されます。

- `https://ryotabani.github.io/PhysLog/privacy.html`
- `https://ryotabani.github.io/PhysLog/support.html`

> リポジトリを public にする場合、本番の広告 ID がコミットされていないか確認してください。
> 気になる場合は private にして、Pages 用に docs だけ別リポジトリにする方法もあります。

公開できたら `docs/AppStore.md` 内の URL 記載を実際のものに更新します。

---

## Step 5. App Store Connect に登録する

### 5-1. アプリを作成

```
https://appstoreconnect.apple.com → マイApp → +（新規App）

プラットフォーム : iOS
名前            : PhysLog - 身体データ記録
プライマリ言語   : 日本語
バンドルID       : com.ryotabani.PhysLog
SKU             : physlog-001
ユーザーアクセス : 制限なし
```

> **バンドルIDは後から変更できません。** 慎重に。

### 5-2. 情報を入力

`docs/AppStore.md` の内容を転記します。

| 欄 | 内容 |
|----|------|
| サブタイトル | 選手のための身体能力ログ |
| プロモーションテキスト | AppStore.md 参照 |
| 説明 | AppStore.md 参照 |
| キーワード | AppStore.md 参照 |
| サポートURL | Step 4 で取得した support.html |
| プライバシーポリシーURL | Step 4 で取得した privacy.html |
| カテゴリ | ヘルスケア/フィットネス（第2: スポーツ） |
| 価格 | 無料 |

### 5-3. スクリーンショット

`screenshots/` の5枚を、iPhone 6.9インチの枠にドラッグします。番号順にアップロードしてください。

### 5-4. App Privacy（重要）

**広告を入れているため「データを収集します」を選びます。**

「収集しません」と回答すると虚偽申告になり、発覚時にアプリが削除されます。

| データ種別 | 用途 | ユーザーに紐づく | トラッキング |
|-----------|------|----------------|-------------|
| 識別子 → デバイスID | サードパーティ広告 | はい | **はい** |
| 使用状況データ → 広告データ | サードパーティ広告 | はい | **はい** |
| 診断 → クラッシュ/パフォーマンス | 分析 | いいえ | いいえ |
| 位置情報 → 大まかな位置 | サードパーティ広告 | はい | はい |

詳細は `docs/AppStore.md` の App Privacy 節にあります。

### 5-5. 配信地域

**初回は日本のみを推奨します。**

EEA・英国に配信する場合、Google の要件で認定 CMP（同意管理）の実装が必要になります。日本限定なら追加実装は不要です。

```
価格および配信状況 → 配信地域 → 日本のみ選択
```

---

## Step 6. アップロード

```
Xcode → Product → Destination → Any iOS Device (arm64)
Xcode → Product → Archive
→ Organizer → Distribute App → App Store Connect → Upload
```

処理完了まで10〜30分。完了後、App Store Connect でビルドを選択します。

---

## Step 7. 審査に出す

### App Review Information の「メモ」に記載する

これを書いておくと、データが空でグラフが出ないことによる差し戻しを防げます。

```
本アプリはログイン不要・オフライン動作です。

データが空の状態では一部のグラフと分析機能が表示されないため、
「設定」タブ →「デモデータを追加」を実行いただくと、
3ヶ月分のサンプルデータで全機能をご確認いただけます。

コンディション分析は、同じ日にコンディションとトレーニングを
記録したデータが8日分以上ある場合に表示されます。
デモデータには十分な件数が含まれています。

広告は Google AdMob を使用しています。
HealthKit から取得したデータは端末内にのみ保存され、
広告目的では一切利用していません。
```

### 提出

すべて入力したら「審査へ提出」。通常1〜3日で結果が出ます。

---

## 審査で落ちやすい点と対策

| 指摘 | 状態 |
|------|------|
| 2.1 情報不足（機能が確認できない） | 審査メモにデモデータの案内を記載 |
| 5.1.1 プライバシー | ポリシー公開・広告について明記済み |
| 5.1.3 HealthKit データの広告利用 | 端末内保存のみ。審査メモにも明記 |
| 1.4.1 健康に関する助言 | メニュー画面に免責文を表示済み |
| アイコンにアルファチャンネル | RGB（アルファなし）で生成済み |
| スクショの寸法違い | 1320×2868 で厳密に生成済み |
| 「広告なし」と記載しつつ広告表示 | 記載を修正済み |

---

## リジェクトされたら

慌てないでください。初回リリースでは珍しくありません。

1. Resolution Center の指摘内容を確認
2. 指摘文をそのまま持ってきていただければ対応を考えます
3. 修正して再提出（審査は最初からやり直しですが、通常は早い）

---

## 公開後にやること

- [ ] Xcode Organizer → Crashes でクラッシュを確認
- [ ] AdMob 管理画面で表示回数・収益を確認
- [ ] レビューへの返信（App Store Connect から可能）
- [ ] 次バージョンの検討（HealthKit 自動同期、Apple Watch、Pro 機能）
