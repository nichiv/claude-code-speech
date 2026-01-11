#!/bin/bash

# Claude Code PermissionRequest Hook - 確認ダイアログを音声読み上げ
# ユーザーへの確認ダイアログ表示時に簡潔なメッセージを読み上げる

# デバッグモードの判定
DEBUG_MODE=false
if [[ "$1" == "--debug" || "$1" == "-d" ]]; then
  DEBUG_MODE=true
fi

# ログ出力関数
log() {
  if [ "$DEBUG_MODE" = true ]; then
    local message="$1"
    echo "$message" >> "$LOG_FILE"
  fi
}

# デバッグモードの場合、ログファイルを準備
if [ "$DEBUG_MODE" = true ]; then
  LOG_FILE="$HOME/.claude/hooks/permission-hook-debug.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  log "========================================"
  log "[$(date '+%Y-%m-%d %H:%M:%S')] PermissionRequest hook triggered (DEBUG MODE)"
fi

# 標準入力からJSONを読み込み
input=$(cat)
log "Input received: ${#input} bytes"

# ツール名を直接取得（PermissionRequestフックには直接tool_nameが含まれる）
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
log "Tool name: $tool_name"

# tool_inputも取得可能（必要に応じて）
tool_input=$(echo "$input" | jq -c '.tool_input // {}')
log "Tool input: $tool_input"

# ツール名に基づいて簡潔なメッセージを生成
case "$tool_name" in
  "Bash")
    speech_text="Bashコマンドを実行して良いですか？"
    ;;
  "Read")
    speech_text="ファイルを読み込んで良いですか？"
    ;;
  "Write")
    speech_text="ファイルに書き込んで良いですか？"
    ;;
  "Edit")
    speech_text="ファイルを編集して良いですか？"
    ;;
  "Glob")
    speech_text="ファイルを検索して良いですか？"
    ;;
  "Grep")
    speech_text="コードを検索して良いですか？"
    ;;
  *)
    # ツール名が取得できない場合、汎用メッセージ
    speech_text="この操作を実行して良いですか？"
    log "Unknown tool name, using generic message"
    ;;
esac

log "Speech text: $speech_text"

# 読み上げ（1.25倍速）
echo "$speech_text" | say -v "Kyoko" -r 219 &
if [ "$DEBUG_MODE" = true ]; then
  say_pid=$!
  log "Say command launched with PID: $say_pid"
fi

# フックは判断を下さず、ユーザーに委ねる（JSON出力なし）
exit 0
