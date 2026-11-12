# PhysLog Web

iOS 版 PhysLog の Web 版（React + Vite + TypeScript、外部ライブラリなし）。
記録はブラウザの localStorage に保存し、外部へは送信しない。

## 開発

```
cd web
npm install
npm run dev
```

## ビルド

- `npm run build` … `docs/app/` に出力（GitHub Pages で `/app/` として配信）
- `npm run build:single` … `dist-single/index.html` に1ファイル版（プレビュー共有用。初回は `src/seed.json` の記録入り）

## iOS 版からの主な変更

- 「今日の記録」1画面に4カテゴリを集約。日付は ‹ › で移動
- コンディション（体調・睡眠）はシートを開かず1タップで保存
- トレーニングは「過去のメニューをコピー」、種目追加時に前回のセットを自動入力、±ボタンで重量2.5kg・回数1回刻み
- 種目の略称検索（BSQ → バックスクワット、BP、DL など）
- 記録する人を切り替え可能（コーチが複数人を記録する用途）
- グラフに「種目別の重量（最大／推定1RM）」を追加
- 移植済み：身体能力のPB判定、コンディション分析（相関）、メニュー提案、CSV書き出し、デモデータ
- 未移植：ジム設定、ヘルスケア・OCR取り込み、広告・課金
