#!/bin/bash
# PhysLog ビルド確認スクリプト
#
# xcodebuild の出力は数千行になるため、エラーだけを抜き出して表示します。
# 完全なログは build.log に残ります。
#
# 使い方:
#   chmod +x build.sh
#   ./build.sh

set -o pipefail
cd "$(dirname "$0")"

SCHEME="PhysLog"
PROJECT="PhysLog.xcodeproj"
LOG="build.log"

echo "=============================================="
echo " PhysLog ビルド確認"
echo "=============================================="

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild が見つかりません。Xcode をインストールし、"
  echo "  sudo xcode-select -s /Applications/Xcode.app"
  echo "を実行してください。"
  exit 1
fi

echo "Xcode: $(xcodebuild -version | head -1)"

# 利用可能なシミュレータから iPhone を1つ選ぶ
DEST=$(xcrun simctl list devices available 2>/dev/null \
  | grep -oE 'iPhone [0-9A-Za-z ]*\([0-9A-F-]{36}\)' \
  | head -1 \
  | grep -oE '[0-9A-F-]{36}')

if [ -n "$DEST" ]; then
  DESTINATION="id=$DEST"
  echo "実行先: シミュレータ ($DEST)"
else
  DESTINATION="generic/platform=iOS Simulator"
  echo "実行先: generic/platform=iOS Simulator"
fi

echo ""
echo "ビルド中... (初回は数分かかります)"
echo ""

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build > "$LOG" 2>&1
STATUS=$?

echo "=============================================="
if [ $STATUS -eq 0 ]; then
  echo " ビルド成功"
  echo "=============================================="
  WARN=$(grep -c "warning:" "$LOG" 2>/dev/null || echo 0)
  echo "警告: ${WARN}件"
  if [ "$WARN" -gt 0 ]; then
    echo ""
    echo "--- 警告（重複を除いた先頭20件）---"
    grep "warning:" "$LOG" | sed 's|.*/PhysLog/||' | sort -u | head -20
  fi
  exit 0
fi

echo " ビルド失敗"
echo "=============================================="
echo ""
echo "--- エラー一覧（重複を除く）---"
grep -E "error:" "$LOG" \
  | sed 's|/Users/[^ ]*/PhysLog/||' \
  | sort -u

echo ""
echo "--- エラー件数: $(grep -c 'error:' "$LOG" 2>/dev/null || echo 0) 件 ---"
echo ""
echo "--- ファイル別の内訳 ---"
grep -E "error:" "$LOG" \
  | sed 's|.*/\([A-Za-z]*\.swift\):.*|\1|' \
  | sort | uniq -c | sort -rn | head -15

echo ""
echo "=============================================="
echo " 上の「エラー一覧」をそのままコピーして"
echo " 貼り付けてください。完全なログは $LOG にあります。"
echo "=============================================="
exit 1
