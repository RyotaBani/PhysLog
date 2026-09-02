# PhysLog

スポーツ選手・ジム利用者のための身体データ記録アプリ（iOS / iPadOS）

Physical（身体的な）+ Log（記録）。体重や筋トレだけでなく、**垂直跳び・50m走・握力といった競技パフォーマンスの土台になる数値**を長期的に残していけることが、一般的な筋トレ記録アプリとの違いです。

---

## 動作環境

| 項目 | 要件 |
|------|------|
| Xcode | 16.0 以降 |
| iOS / iPadOS | 17.0 以降 |
| 依存ライブラリ | なし（Apple 標準フレームワークのみ） |

SwiftUI / SwiftData / Swift Charts で構成しています。外部パッケージは一切使っていないため、`Package.resolved` の解決や CocoaPods の導入は不要です。

---

## 使い方

1. `PhysLog.xcodeproj` をダブルクリックして Xcode で開く
2. 上部のスキーム選択から任意のシミュレータ（iPhone 15 など）を選ぶ
3. **⌘R** で実行

実機で動かす場合は、`PhysLog` ターゲット → **Signing & Capabilities** で自分の Apple ID チームを選択してください。Bundle Identifier は `com.ryotabani.PhysLog` を初期値にしてあります。重複する場合は任意の値に変更してください。

### すぐにグラフを確認したいとき

起動直後はデータが空なのでグラフが表示されません。
**設定タブ → データ → デモデータを追加** を実行すると、過去3ヶ月分のサンプル記録が入り、全画面の動作を確認できます。

---

## 画面構成

| タブ | 内容 |
|------|------|
| ホーム | 最新の体重・体脂肪率・今週のトレーニング回数・体調のサマリー |
| 記録 | 身体測定 / 身体能力 / トレーニング / コンディションの4カテゴリ |
| グラフ | 6指標の推移（体重・体脂肪率・筋肉量・身体能力・挙上量・体調） |
| メニュー | 目的 × 経験レベル × 週の日数からトレーニングメニューを提案 |
| 設定 | プロフィール、記録件数、CSV書き出し、データ削除 |

---

## ディレクトリ構成

```
PhysLog/
├── PhysLog.xcodeproj/
└── PhysLog/
    ├── PhysLogApp.swift          アプリ起動・ModelContainer 構築
    ├── ContentView.swift         タブ構成
    ├── Models/                   SwiftData モデル4種
    │   ├── BodyMeasurement.swift
    │   ├── PhysicalAbility.swift
    │   ├── TrainingModels.swift
    │   └── ConditionRecord.swift
    ├── Views/
    │   ├── Onboarding/           初回起動時の紹介・プロフィール入力
    │   ├── Home/                 ダッシュボード
    │   ├── Record/               記録の一覧・追加・編集
    │   ├── Graph/                Swift Charts によるグラフ
    │   ├── Menu/                 メニュー提案（ルールエンジン）
    │   └── Settings/             設定・CSV書き出し
    ├── Utilities/
    │   ├── Theme.swift           配色と共通UI部品
    │   └── SampleData.swift      デモデータ生成
    └── Assets.xcassets/
        └── AppIcon.appiconset/   1024×1024 アイコン同梱済み

docs/
├── privacy.html                  プライバシーポリシー（GitHub Pages 用）
├── support.html                  サポート・FAQ（GitHub Pages 用）
└── AppStore.md                   App Store Connect 登録内容と提出チェックリスト
```

Xcode 16 の同期グループ（synchronized folder）形式を採用しているため、**ファイルを追加してもプロジェクトへの登録作業は不要**です。フォルダに置けばそのままビルド対象になります。

---

## データ設計

すべて端末内の SwiftData に保存され、外部への送信は行いません。

### BodyMeasurement（身体測定）
`date` / `weight` / `bodyFatPercentage` / `muscleMass` / `memo`

### PhysicalAbility（身体能力）
`date` / `type` / `value` / `unit` / `memo`

垂直跳び・50m走・握力など15種目をプリセットとして持ち、自由入力にも対応します。50m走のようなタイム種目は「小さいほど良い記録」として自己ベスト判定と変化量の色分けに反映されます。

### TrainingSession ⇄ TrainingSet（トレーニング）
セッション1件に対して種目を複数持つ1対多構成（`deleteRule: .cascade`）。重量 × 回数 × セット数から総挙上量を自動計算します。

### ConditionRecord（コンディション）
`date` / `sleepHours` / `fatigue` (1–5) / `condition` (1–5) / `memo`

---

## 実装済みの主な機能

- 初回起動時のオンボーディング（3ページ・スキップ可）
- 4カテゴリの記録追加・**編集**・スワイプ削除
- 種目プリセットからの選択（カテゴリ別・検索対応）
- 自己ベストの自動判定バッジ
- 総挙上量の自動計算（入力中もリアルタイム表示）
- 期間フィルタ付きグラフ（1ヶ月〜全期間）
- 最新 / 最高 / 最低 / 変化量のサマリー表示
- 目的別トレーニングメニュー提案（5目的 × 3レベル × 週2〜5日）
- CSV 書き出し（BOM付きUTF-8 / Excel対応）
- デモデータ生成・全削除

---

## 今後の拡張候補

| フェーズ | 内容 |
|---------|------|
| Phase 2 | Supabase 連携によるクラウドバックアップ・機種変更時の引き継ぎ |
| Phase 3 | HealthKit 連携（体重・睡眠の自動取り込み）、Apple Watch 対応 |
| Phase 4 | ウィジェット、通知によるリマインド |

---

## リリースに向けて

App Store Connect への登録内容（アプリ名・説明文・キーワード・審査メモなど）と提出前チェックリストは **[docs/AppStore.md](docs/AppStore.md)** にまとめてあります。コピー&ペーストできる形で用意しているので、そのまま入力欄に貼り付けられます。

### 残っている作業

1. **Bundle Identifier の変更** — `com.ryotabani.PhysLog` を自分のものに
2. **Signing チームの選択** — Xcode の Signing & Capabilities
3. **プライバシーポリシー / サポートページの公開** — `docs/` の2ファイルを GitHub Pages へ（手順は AppStore.md に記載）
4. **スクリーンショット撮影** — デモデータを入れた状態で iPhone 6.9インチ と iPad 13インチ の2サイズ
5. **Archive & 提出**

アイコン・輸出コンプライアンス設定・免責文言・プライバシー対応はすべて実装済みです。

---

## 設計上の判断

**なぜクラウド同期を入れなかったか**

初回リリースの目的は「動くものを世に出して実績にする」ことなので、審査リスクとメンテナンスコストの低い端末内完結の構成にしました。データ収集をゼロにすることで App Privacy の申告が「収集なし」で済み、プライバシーポリシーもシンプルになります。引き継ぎ需要には CSV 書き出しで暫定対応しています。

**なぜメニュー提案をAPIではなくルールエンジンにしたか**

完全無料で運営するため、ランニングコストが発生する構成を避けました。目的×レベル×日数の組み合わせはルールで十分表現でき、オフラインでも動作します。
