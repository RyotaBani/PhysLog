# リリース手順書

PhysLog v1.0.0 を App Store に提出するまでの実作業手順です。
上から順に実行すれば提出まで到達できるように並べています。

---

## 現在のステータス

| 項目 | 状態 |
|------|------|
| 実装 | 完了（全画面・全機能） |
| アプリアイコン | 生成済み（1024×1024・アルファなし） |
| プライバシーマニフェスト | 作成済み（`PrivacyInfo.xcprivacy`） |
| 輸出コンプライアンス申告 | ビルド設定に埋め込み済み |
| App Store 申請文 | `docs/AppStore.md` に用意済み |
| プライバシーポリシー / サポートページ | `docs/` に HTML で用意済み |
| **Xcode でのビルド確認** | **未実施（要対応）** |
| **実機での動作確認** | **未実施（要対応）** |
| スクリーンショット | 未作成（要対応） |
| 広告（AdMob） | 実装済み・SDK追加と本番ID差し替えが必要（`docs/ADS.md`） |
| Pro課金（StoreKit 2） | 実装済み・App Store Connect への商品登録が必要（`docs/PRO.md`） |
| 有料アプリケーション契約 | **未締結（最優先）** 締結前は商品情報を取得できません |
| Apple Developer Program 登録 | 要確認 |

**この環境では Swift のコンパイルができないため、ビルド確認だけは手元の Xcode で必ず実施してください。** 静的な整合性検査（型の重複、括弧バランス、参照解決、プロジェクトファイルの構造）は通していますが、コンパイルエラーの完全な排除は保証できません。

---

## Step 1. ビルド確認

```
1. PhysLog.xcodeproj を Xcode 16 で開く
2. スキーム: PhysLog / 実行先: iPhone 16 シミュレータ
3. ⌘B でビルド
```

エラーが出た場合はメッセージを控えてください。想定される主な箇所は Swift Charts の API 差分と SwiftData のリレーション定義です。

続いて ⌘R で実行し、以下を確認します。

- オンボーディングが表示され、3ページ進んで「はじめる」で本体に入る
- 設定 → デモデータを追加 → グラフタブで6指標すべてに線が出る
- 各記録の追加・編集・スワイプ削除が動く
- ダークモード（⌘⇧A）でも文字が読める

---

## Step 2. 署名設定

```
PhysLog ターゲット → Signing & Capabilities
├── Automatically manage signing: ON
├── Team: 自分の Apple Developer アカウント
└── Bundle Identifier: com.ryotabani.PhysLog
```

Bundle Identifier が他で使われている場合は変更してください。一度 App Store Connect に登録すると**後から変更できません**。

Apple Developer Program（年間 12,980円）が未登録の場合はここで登録が必要です。承認まで1〜2日かかることがあります。

---

## Step 3. 実機確認

シミュレータでは検出できない問題があるため、実機で以下を確認します。

- [ ] アプリアイコンがホーム画面で正しく表示される
- [ ] 起動時間が許容範囲（3秒以内）
- [ ] キーボード表示時に入力欄が隠れない
- [ ] CSV書き出しから共有シートが開き、ファイルが保存できる
- [ ] アプリを削除→再インストールしてもクラッシュしない
- [ ] 機内モードでも全機能が動く（オフライン前提のため）

---

## Step 4. スクリーンショット作成

必須サイズは **6.9インチ（1320×2868）** の1種類です。iPhone 16 Pro Max シミュレータで ⌘S で撮影できます。

`docs/AppStore.md` に推奨する5枚の構成を記載しています。

---

## Step 5. プライバシーポリシーの公開

`docs/privacy.html` と `docs/support.html` を Web 上に公開し、URL を控えます。

GitHub Pages を使う場合:

```bash
# physlog リポジトリを作成し、docs/ を push
# リポジトリ設定 → Pages → Source: main branch / docs folder
```

公開URLの例:
- `https://ryotabani.github.io/physlog/privacy.html`
- `https://ryotabani.github.io/physlog/support.html`

`docs/AppStore.md` 内のURL記載も実際のものに合わせて更新してください。

---

## Step 6. App Store Connect への登録

```
1. https://appstoreconnect.apple.com → マイApp → 新規App
2. プラットフォーム: iOS
   名前: PhysLog
   プライマリ言語: 日本語
   バンドルID: com.ryotabani.PhysLog
   SKU: physlog-001
3. docs/AppStore.md の内容を各欄に転記
4. App Privacy → 「データを収集しません」を選択
```

---

## Step 7. アップロード

```
Xcode → Product → Destination → Any iOS Device (arm64)
Xcode → Product → Archive
Organizer → Distribute App → App Store Connect → Upload
```

アップロード後、App Store Connect で処理完了（10〜30分）を待ち、ビルドを選択して「審査へ提出」します。

---

## 審査で落ちやすい点

| 指摘 | 対策 |
|------|------|
| Guideline 2.1 情報不足 | デモデータ追加機能があることを審査メモに記載する |
| Guideline 5.1.1 プライバシー | 端末内保存のみである旨をポリシーに明記済み |
| Guideline 1.4.1 健康情報 | メニュー提案画面下部に免責文を表示済み |
| アイコンにアルファチャンネル | 生成済みアイコンはRGB（アルファなし）で対応済み |

審査メモ（App Review Information → Notes）には以下を記載しておくと通りやすくなります。

```
本アプリはログイン不要・オフライン動作です。
データが空の状態では一部のグラフが表示されないため、
「設定」タブ →「デモデータを追加」を実行すると
サンプルデータで全機能をご確認いただけます。
```

---

## リリース後の優先タスク

1. クラッシュログの確認（Xcode Organizer → Crashes）
2. HealthKit 連携（体重・睡眠の自動取り込み）
3. Supabase 連携によるバックアップ・機種変更時の引き継ぎ
4. ウィジェット対応
