#!/bin/bash

# Claude Code 音声読み上げ with カテゴリ+要約 - セットアップスクリプト

set -e

echo "=========================================="
echo "Claude Code 音声読み上げ - セットアップ"
echo "=========================================="
echo ""

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

# 1. jqの確認
echo "[1/4] jqコマンドの確認..."
if ! command -v jq &> /dev/null; then
    echo "❌ エラー: jqがインストールされていません"
    echo ""
    echo "以下のコマンドでインストールしてください:"
    echo "  brew install jq"
    exit 1
fi
echo "✓ jqが見つかりました"
echo ""

# 2. ディレクトリ作成
echo "[2/4] ディレクトリの準備..."
mkdir -p "$HOOKS_DIR"
echo "✓ $HOOKS_DIR を作成しました"
echo ""

# 3. スクリプトのコピーと実行権限付与
echo "[3/4] スクリプトのコピー..."
if [ ! -f "$SCRIPT_DIR/stop-speak-with-summary.sh" ]; then
    echo "❌ エラー: stop-speak-with-summary.sh が見つかりません"
    exit 1
fi
if [ ! -f "$SCRIPT_DIR/permission-speak.sh" ]; then
    echo "❌ エラー: permission-speak.sh が見つかりません"
    exit 1
fi

cp "$SCRIPT_DIR/stop-speak-with-summary.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/permission-speak.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/stop-speak-with-summary.sh"
chmod +x "$HOOKS_DIR/permission-speak.sh"
echo "✓ スクリプトをコピーし、実行権限を付与しました"
echo ""

# 4. settings.jsonの設定
echo "[4/4] settings.jsonの設定..."

# settings.jsonが存在しない場合、新規作成
if [ ! -f "$SETTINGS_FILE" ]; then
    cat > "$SETTINGS_FILE" <<'EOF'
{
  "model": "sonnet",
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/stop-speak-with-summary.sh --debug"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/permission-speak.sh --debug"
          }
        ]
      }
    ]
  }
}
EOF
    # パスを実際の値に置換
    sed -i '' "s|\$HOOKS_DIR|$HOOKS_DIR|g" "$SETTINGS_FILE"
    echo "✓ settings.jsonを新規作成しました"
else
    # 既存のsettings.jsonを更新
    # バックアップを作成
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    echo "✓ 既存のsettings.jsonのバックアップを作成しました"

    # Stopフックの設定を追加/更新
    HOOK_COMMAND="$HOOKS_DIR/stop-speak-with-summary.sh --debug"

    # hooksセクションがない場合、追加
    if ! jq -e '.hooks' "$SETTINGS_FILE" > /dev/null 2>&1; then
        jq '. + {"hooks": {}}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi

    # hooks.Stopがない場合、追加
    if ! jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
        jq '.hooks.Stop = []' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi

    # 既存のStopフック設定を確認
    EXISTING_HOOK=$(jq -r '.hooks.Stop[] | select(.matcher == "") | .hooks[] | select(.type == "command") | .command' "$SETTINGS_FILE" 2>/dev/null || echo "")

    if [ -n "$EXISTING_HOOK" ]; then
        # 既存のフック設定がある場合、上書き
        jq --arg cmd "$HOOK_COMMAND" '
          .hooks.Stop = [.hooks.Stop[] | if .matcher == "" then .hooks[0].command = $cmd else . end]
        ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo "✓ 既存のStopフック設定を更新しました"
    else
        # 新規にStopフック設定を追加
        jq --arg cmd "$HOOK_COMMAND" '
          .hooks.Stop += [{
            "matcher": "",
            "hooks": [{
              "type": "command",
              "command": $cmd
            }]
          }]
        ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo "✓ Stopフック設定を追加しました"
    fi

    # PermissionRequestフックの設定を追加/更新
    PERMISSION_HOOK_COMMAND="$HOOKS_DIR/permission-speak.sh --debug"

    # hooks.PermissionRequestがない場合、追加
    if ! jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
        jq '.hooks.PermissionRequest = []' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi

    # 既存のPermissionRequestフック設定を確認
    EXISTING_PERMISSION_HOOK=$(jq -r '.hooks.PermissionRequest[] | select(.matcher == "") | .hooks[] | select(.type == "command") | .command' "$SETTINGS_FILE" 2>/dev/null || echo "")

    if [ -n "$EXISTING_PERMISSION_HOOK" ]; then
        # 既存のフック設定がある場合、上書き
        jq --arg cmd "$PERMISSION_HOOK_COMMAND" '
          .hooks.PermissionRequest = [.hooks.PermissionRequest[] | if .matcher == "" then .hooks[0].command = $cmd else . end]
        ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo "✓ 既存のPermissionRequestフック設定を更新しました"
    else
        # 新規にPermissionRequestフック設定を追加
        jq --arg cmd "$PERMISSION_HOOK_COMMAND" '
          .hooks.PermissionRequest += [{
            "matcher": "",
            "hooks": [{
              "type": "command",
              "command": $cmd
            }]
          }]
        ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo "✓ PermissionRequestフック設定を追加しました"
    fi

    # modelがない場合、追加
    if ! jq -e '.model' "$SETTINGS_FILE" > /dev/null 2>&1; then
        jq '.model = "sonnet"' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo "✓ モデル設定を追加しました"
    fi
fi

echo ""
echo "=========================================="
echo "✅ セットアップが完了しました！"
echo "=========================================="
echo ""
echo "📝 設定内容:"
echo "  Stopフック: $HOOKS_DIR/stop-speak-with-summary.sh"
echo "  PermissionRequestフック: $HOOKS_DIR/permission-speak.sh"
echo "  設定ファイル: $SETTINGS_FILE"
echo "  デバッグモード: 有効 (--debug)"
echo ""
echo "🔍 要約の確認方法:"
echo "  tail -f ~/.claude/hooks/stop-hook-summary.log"
echo ""
echo "📋 デバッグログの確認方法:"
echo "  Stopフック: tail -f ~/.claude/hooks/stop-hook-summary-debug.log"
echo "  PermissionRequestフック: tail -f ~/.claude/hooks/permission-hook-debug.log"
echo ""
echo "🎤 使い方:"
echo "  通常通りClaudeを使用するだけで、自動的に音声読み上げされます"
echo "  - 応答完了時: 50文字以上の応答は自動でカテゴリ分類+要約されます"
echo "  - 確認ダイアログ表示時: 簡潔な確認メッセージが読み上げられます"
echo ""
