#!/bin/bash
# PhysLog: ビルド → シミュレータ起動 → インストール → 実行 まで一括
#
#   chmod +x run.sh
#   ./run.sh

set -o pipefail
cd "$(dirname "$0")"

SCHEME="PhysLog"
PROJECT="PhysLog.xcodeproj"
BUNDLE_ID="com.ryotabani.PhysLog"
DERIVED="build"
LOG="build.log"

echo "=============================================="
echo " PhysLog ビルド & 実行"
echo "=============================================="

command -v xcodebuild >/dev/null 2>&1 || {
  echo "xcodebuild が見つかりません。"
  echo "  sudo xcode-select -s /Applications/Xcode.app"
  exit 1
}
echo "$(xcodebuild -version | head -1)"

# --- シミュレータを選ぶ ---------------------------------------
UDID=$(xcrun simctl list devices available \
  | grep "iPhone" | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')

if [ -z "$UDID" ]; then
  echo "利用可能な iPhone シミュレータがありません。"
  echo "Xcode → Settings → Components から追加してください。"
  exit 1
fi
NAME=$(xcrun simctl list devices available | grep "$UDID" | sed -E 's/^ *//; s/ \(.*//')
echo "実行先: $NAME"
echo ""
echo "ビルド中... (初回は数分かかります)"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build > "$LOG" 2>&1
STATUS=$?

if [ $STATUS -ne 0 ]; then
  echo ""
  echo "=============================================="
  echo " ビルド失敗"
  echo "=============================================="
  grep -E "error:" "$LOG" | sed 's|.*/PhysLog/||' | sort -u | head -60
  echo ""
  echo "エラー件数: $(grep -c 'error:' "$LOG")"
  echo "完全なログ: $LOG"
  exit 1
fi

echo "ビルド成功"
WARN=$(grep -c "warning:" "$LOG" 2>/dev/null || echo 0)
echo "警告: ${WARN}件"

APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [ ! -d "$APP" ]; then
  echo "アプリが見つかりません: $APP"
  exit 1
fi

# --- 起動 -----------------------------------------------------
echo ""
echo "シミュレータを起動中..."
xcrun simctl boot "$UDID" 2>/dev/null
open -a Simulator
# 起動完了を待つ
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1

echo "インストール中..."
xcrun simctl install "$UDID" "$APP" || { echo "インストール失敗"; exit 1; }

echo "起動中..."
xcrun simctl launch "$UDID" "$BUNDLE_ID" || { echo "起動失敗"; exit 1; }

echo ""
echo "=============================================="
echo " 起動しました"
echo "=============================================="
echo ""
echo "確認する順序:"
echo "  1. オンボーディングを3ページ進んで「はじめる」"
echo "  2. 設定タブ →「デモデータを追加」"
echo "  3. グラフタブ → 6指標すべてに線が出るか"
echo "  4. グラフ右上「分析」→ ぼかし →「詳しく見る」"
echo "  5. ペイウォールで購入 → 分析が見えるか"
echo "  6. 記録タブ → 各カテゴリの追加・編集・スワイプ削除"
echo ""
echo "※ 広告は AdMob SDK 未追加のため表示されません（想定どおり）"
