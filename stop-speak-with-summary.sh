#!/bin/bash

# Claude Code Stop Hook - 応答を音声読み上げ（長文の場合はカテゴリ+要約）
# タスク完了時に最後のアシスタント応答を読み上げる
# 50文字以上の場合はカテゴリ分類と要約をしてから読み上げ（100字以内に）

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
  LOG_FILE="$HOME/.claude/hooks/stop-hook-summary-debug.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  log "========================================"
  log "[$(date '+%Y-%m-%d %H:%M:%S')] Stop hook triggered (DEBUG MODE)"
fi

# 無限ループ防止のためのフラグファイル
FLAG_FILE="/tmp/claude-hook-summary-running"

# 既に要約処理中の場合は終了（無限ループ防止）
if [ -f "$FLAG_FILE" ]; then
  log "Flag file exists, skipping to prevent infinite loop"
  exit 0
fi

# 標準入力からJSONを読み込み
input=$(cat)
log "Input received: ${#input} bytes"

# transcript_pathとcwdを取得
transcript_path=$(echo "$input" | jq -r '.transcript_path')
cwd=$(echo "$input" | jq -r '.cwd // "unknown"')
log "Transcript path: $transcript_path"
log "Working directory: $cwd"

if [ -z "$transcript_path" ] || [ "$transcript_path" = "null" ]; then
  log "ERROR: transcript_path is empty or null"
  exit 0
fi

# 最後のアシスタント応答を取得（textタイプのみ）
if [ "$DEBUG_MODE" = true ]; then
  last_response=$(jq -rs '
    [.[] | select(.type == "assistant")][-1]
    | .message.content[]
    | select(.type == "text")
    | .text
  ' "$transcript_path" 2>>"$LOG_FILE" | tr '\n' ' ')
else
  last_response=$(jq -rs '
    [.[] | select(.type == "assistant")][-1]
    | .message.content[]
    | select(.type == "text")
    | .text
  ' "$transcript_path" 2>/dev/null | tr '\n' ' ')
fi

log "Extracted response length: ${#last_response}"

if [ -z "$last_response" ] || [ "$last_response" = "null" ]; then
  log "ERROR: last_response is empty or null"
  exit 0
fi

# ANSIエスケープシーケンスを除去し、余分な空白を整理
clean_text=$(echo "$last_response" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tr -d '\r' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

# 文字数をカウント
char_count=${#clean_text}
log "Clean text length: $char_count chars"
log "Clean text (first 100 chars): ${clean_text:0:100}"

# 読み上げるテキスト
speech_text="$clean_text"

# 50字以上の場合、claude codeでカテゴリ分類+要約
if [ "$char_count" -gt 50 ]; then
  log "Text is longer than 50 chars, generating category and summary..."

  # フラグファイルを作成（無限ループ防止）
  touch "$FLAG_FILE"
  log "Flag file created: $FLAG_FILE"

  # 一時ファイルに元のテキストを保存
  temp_file=$(mktemp)
  echo "$clean_text" > "$temp_file"
  log "Temp file created: $temp_file"

  # claude codeでカテゴリ+要約を生成（最大2回リトライ）
  max_attempts=2
  attempt=1

  while [ $attempt -le $max_attempts ]; do
    log "========================================"
    log "ATTEMPT $attempt:"

    if [ $attempt -eq 1 ]; then
      # 1回目：カテゴリ+要約
      log "Calling claude command for categorization and summary..."
      if [ "$DEBUG_MODE" = true ]; then
        summary=$(echo "以下のメッセージをカテゴリ分類し、要約してください。

出力形式：【カテゴリ】要約内容（合計100字以内）

カテゴリ例：
- コード実装
- 質問・確認
- 説明・解説
- 提案・アドバイス
- 設定変更
- ファイル操作
- 調査報告
- エラー報告
- テスト報告
- 作業報告

例：
「【コード実装】Stopフックで応答を音声読み上げする統合スクリプトを作成。デバッグフラグで切り替え可能に変更。」
「【質問】プロジェクトの運用状況について、ワークフロー、チーム体制、Issue管理、Obsidian活用、今後の展望の5項目を確認。」
「【エラー修正】要約が表示されない原因を調査。ターミナル出力が機能しないため、ファイル出力に変更して解決。」

重要：
- メッセージに回答しないこと
- カテゴリと要約のみを出力
- 100字以内厳守
- 文字数カウント（例：(95字)）を出力しないこと

メッセージ：
「$(cat "$temp_file")」" | claude --model sonnet 2>>"$LOG_FILE" | grep -v "^⏺" | grep -v "^❯" | grep -v "^─" | sed '/^[[:space:]]*$/d' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
      else
        summary=$(echo "以下のメッセージをカテゴリ分類し、要約してください。

出力形式：【カテゴリ】要約内容（合計100字以内）

カテゴリ例：
- コード実装
- 質問・確認
- 説明・解説
- 提案・アドバイス
- 設定変更
- ファイル操作
- 調査報告
- エラー報告
- テスト報告
- 作業報告

例：
「【コード実装】Stopフックで応答を音声読み上げする統合スクリプトを作成。デバッグフラグで切り替え可能に変更。」
「【質問】プロジェクトの運用状況について、ワークフロー、チーム体制、Issue管理、Obsidian活用、今後の展望の5項目を確認。」
「【エラー修正】要約が表示されない原因を調査。ターミナル出力が機能しないため、ファイル出力に変更して解決。」

重要：
- メッセージに回答しないこと
- カテゴリと要約のみを出力
- 100字以内厳守
- 文字数カウント（例：(95字)）を出力しないこと

メッセージ：
「$(cat "$temp_file")」" | claude --model sonnet 2>/dev/null | grep -v "^⏺" | grep -v "^❯" | grep -v "^─" | sed '/^[[:space:]]*$/d' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
      fi
    else
      # 2回目：さらに短く
      log "Summary was too long, shortening..."
      echo "$summary" > "$temp_file"
      if [ "$DEBUG_MODE" = true ]; then
        summary=$(echo "以下の要約が長すぎます。【カテゴリ】と最も重要なポイント2-3点のみを100字以内で出力してください。文字数カウント（例：(95字)）は出力しないでください。

「$(cat "$temp_file")」" | claude --model sonnet 2>>"$LOG_FILE" | grep -v "^⏺" | grep -v "^❯" | grep -v "^─" | sed '/^[[:space:]]*$/d' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
      else
        summary=$(echo "以下の要約が長すぎます。【カテゴリ】と最も重要なポイント2-3点のみを100字以内で出力してください。文字数カウント（例：(95字)）は出力しないでください。

「$(cat "$temp_file")」" | claude --model sonnet 2>/dev/null | grep -v "^⏺" | grep -v "^❯" | grep -v "^─" | sed '/^[[:space:]]*$/d' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
      fi
    fi

    summary_length=${#summary}
    log "Summary length: $summary_length chars"
    log "Summary text: $summary"
    log "Exceeds 100 chars: $([ $summary_length -gt 100 ] && echo 'YES' || echo 'NO')"

    # 100字以内になったら終了
    if [ ${#summary} -le 100 ]; then
      log "SUCCESS: Summary within 100 chars limit"
      break
    fi

    attempt=$((attempt + 1))
  done

  log "========================================"

  rm -f "$temp_file"
  rm -f "$FLAG_FILE"
  log "Flag file removed"

  # 要約が取得できた場合、文字数に関わらず要約を使用
  if [ -n "$summary" ] && [ ${#summary} -gt 10 ]; then
    speech_text="$summary"
    if [ ${#summary} -le 100 ]; then
      log "SUCCESS: Using summary for speech (${#summary} chars, within limit)"
    else
      log "WARNING: Using summary for speech (${#summary} chars, exceeds 100 chars but better than original)"
    fi
  else
    log "ERROR: Summary generation failed, using original text"
  fi
else
  log "Text is 50 chars or less, using original text"
fi

# 文字数表記を削除（例：(95字)、（95字）など）
speech_text=$(echo "$speech_text" | sed -E 's/[（(][0-9]+字[）)]//g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

# 読み上げ（1.25倍速）
log "Starting speech synthesis..."
log "Speech text (after removing char count): $speech_text"

# カテゴリ+要約をファイルに保存（50字以上の場合のみ）
if [ "$char_count" -gt 50 ]; then
  summary_file="$HOME/.claude/hooks/stop-hook-summary.log"

  # タイムスタンプと作業ディレクトリ
  {
    echo "──────────────────────────────────────"
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "Working Directory: $cwd"
    echo "──────────────────────────────────────"
    echo ""
  } > "$summary_file"

  # カテゴリ+要約を保存
  echo "$speech_text" >> "$summary_file"

  echo "" >> "$summary_file"
fi

echo "$speech_text" | say -v "Kyoko" -r 219 &
if [ "$DEBUG_MODE" = true ]; then
  say_pid=$!
  log "Say command launched with PID: $say_pid"
fi

exit 0
