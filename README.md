# Claude Code 音声読み上げ with カテゴリ+要約 + 確認ダイアログ読み上げ

Claude Codeの応答メッセージと確認ダイアログをmacOSの`say`コマンドで自動的に音声読み上げ。長文の場合は自動でカテゴリ分類と要約を生成し、効率的に内容を把握できます。

## 特徴

### 応答の音声読み上げ（Stopフック）
- ✅ **インテリジェント**: 50文字以上の応答を自動要約（100字以内）
- ✅ **カテゴリ分類**: 応答の種類を自動分類（コード実装、調査報告、質問など）
- ✅ **ファイル出力**: 要約を `~/.claude/hooks/stop-hook-summary.log` に保存

### 確認ダイアログの音声読み上げ（PermissionRequestフック）
- ✅ **即座に通知**: 確認ダイアログ表示と同時に読み上げ
- ✅ **ツール別メッセージ**: Bash、Read、Write等、ツールに応じたメッセージ
- ✅ **簡潔**: 「Bashコマンドを実行して良いですか？」など短いメッセージ

### 共通
- ✅ **デバッグモード**: `--debug` フラグでログ出力制御
- ✅ **確実**: Claude Code公式フックを使用
- ✅ **保守性**: 公式データフォーマットに依存

## セットアップ

### 自動セットアップ（推奨）

セットアップスクリプトを使用すると、すべての設定が自動で完了します。

```bash
# このディレクトリに移動
cd /path/to/claude-code-speech

# セットアップスクリプトを実行
./setup.sh
```

セットアップスクリプトは以下を自動的に実行します：
- jqコマンドの確認
- ディレクトリの作成
- スクリプトのコピーと実行権限付与
- settings.jsonの設定（既存の設定がある場合はマージ）

### 手動セットアップ

自動セットアップが使えない場合、以下の手順で手動設定できます。

#### 1. jqコマンドのインストール（未インストールの場合）

```bash
brew install jq
```

#### 2. スクリプトの配置

```bash
mkdir -p ~/.claude/hooks
cp stop-speak-with-summary.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/stop-speak-with-summary.sh
```

#### 3. settings.jsonの設定

`~/.claude/settings.json` に以下を追加：

```json
{
  "model": "sonnet",
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/YOUR_USERNAME/.claude/hooks/stop-speak-with-summary.sh --debug"
          }
        ]
      }
    ]
  }
}
```

**⚠️ 重要（必須）**:
- **`YOUR_USERNAME` を実際のユーザー名に必ず置き換えてください**（例: `/Users/john/.claude/hooks/...`）
- `~` や `$HOME` は使用できません。フルパスが必須です
- `--debug` フラグを付けるとログ出力が有効になります（推奨）
- デバッグ不要な場合は `--debug` を削除してください

#### 4. 設定の確認

```bash
cat ~/.claude/settings.json
```

## 使い方

### 基本的な使用方法

設定後は、通常通りClaude Codeを使用するだけです。

```bash
claude
```

タスクが完了すると、自動的に応答が音声で読み上げられます。

### 要約の確認

長文の応答（50文字以上）の場合、カテゴリ+要約が `~/.claude/hooks/stop-hook-summary.log` に保存されます。

別のターミナルで監視：

```bash
tail -f ~/.claude/hooks/stop-hook-summary.log
```

出力例：

```
──────────────────────────────────────
2026-01-11 17:19:06
Working Directory: /Users/username/projects/my-project
──────────────────────────────────────

【調査報告】NISA金投資を調査。2026年価格5000ドル予測。成長投資枠でETF活用。低コストは1328、信頼性は314A推奨。ポートフォリオ10-15%配分が基本。
```

## 仕組み

1. Claude Codeがタスクを完了（Stop イベント発火）
2. フックスクリプトが自動実行される
3. transcript.jsonlから最後のアシスタント応答を取得
4. jqで `type == "text"` のコンテンツのみを抽出
5. **50文字以下**: そのまま読み上げ（1.25倍速、日本語音声）
6. **50文字以上**: Claude Codeで要約生成
   - カテゴリ自動分類（コード実装、調査報告、質問など）
   - 100字以内に要約
   - 要約をファイルに保存
   - 要約を読み上げ

### カテゴリ例

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

### コア実装

```bash
# 最後のアシスタント応答からテキストのみを抽出
last_response=$(jq -rs '
  [.[] | select(.type == "assistant")][-1]
  | .message.content[]
  | select(.type == "text")
  | .text
' "$transcript_path" | tr '\n' ' ')

# 50文字以上の場合、claude codeで要約生成
if [ "$char_count" -gt 50 ]; then
  summary=$(echo "以下のメッセージをカテゴリ分類し、要約してください。

出力形式：【カテゴリ】要約内容（合計100字以内）
..." | claude --model sonnet 2>/dev/null | ...)

  # 要約をファイルに保存
  echo "$summary" > ~/.claude/hooks/stop-hook-summary.log

  # 要約を読み上げ
  speech_text="$summary"
fi

# ANSIエスケープを除去して読み上げ（1.25倍速）
echo "$speech_text" | say -v "Kyoko" -r 219 &
```

## カスタマイズ

### 読み上げ速度の変更

`stop-speak-with-summary.sh` の `-r 219` を変更：

- `-r 175`: デフォルト速度（1.0倍）
- `-r 210`: 1.2倍速
- `-r 219`: 1.25倍速（現在の設定）
- `-r 262`: 1.5倍速
- `-r 350`: 2.0倍速

### 要約の文字数制限の変更

50文字の閾値を変更したい場合、スクリプト内の以下を編集：

```bash
if [ "$char_count" -gt 50 ]; then
```

### カテゴリの追加

スクリプト内のプロンプト部分で、カテゴリ例に追加可能：

```bash
カテゴリ例：
- コード実装
- 調査報告
- あなたのカテゴリ  # 追加
```

### 音声の変更

日本語音声: `-v "Kyoko"`（デフォルト）
英語音声: `-v "Samantha"` など

利用可能な音声を確認：

```bash
say -v ?
```

## トラブルシューティング

### 音声が読み上げられない場合

1. **jqがインストールされているか確認**:
   ```bash
   which jq
   ```

2. **スクリプトが実行可能か確認**:
   ```bash
   ls -la ~/.claude/hooks/stop-speak-with-summary.sh
   ```

3. **settings.jsonの設定を確認**:
   ```bash
   cat ~/.claude/settings.json
   ```
   - `"matcher": ""` が空文字列になっているか
   - パスが正しいか
   - `--debug` フラグが付いているか（推奨）

4. **手動でテスト**:
   ```bash
   echo "テスト" | say -v "Kyoko" -r 219
   ```

### デバッグログの確認

`--debug` フラグを有効にしている場合、ログで詳細を確認できます：

```bash
# ログをリアルタイム監視
tail -f ~/.claude/hooks/stop-hook-summary-debug.log

# ログの最後50行を表示
tail -50 ~/.claude/hooks/stop-hook-summary-debug.log
```

ログには以下の情報が記録されます：
- 応答文字数
- 要約生成の試行回数
- 要約結果とその文字数
- 読み上げテキスト

## 開発経緯

### バージョン履歴

1. **v1.0 - シンプル版**（2026-01-11）
   - 33行のStopフック版
   - 応答をそのまま読み上げ

2. **v2.0 - 要約機能追加**（2026-01-11）
   - 50文字以上の応答を自動要約
   - カテゴリ分類機能を追加
   - 要約をファイル出力
   - デバッグモードの統合

3. **v2.1 - 確認ダイアログ読み上げ追加**（2026-01-11）
   - PermissionRequestフックを追加
   - 確認ダイアログ表示時に即座に音声通知
   - ツール別の簡潔なメッセージ生成

### 設計思想

バイブコーディングなどで大量のAI応答に目を通す必要がある際、以下の課題がありました：

1. **認知負荷が高い**: 大量の文章を読む必要がある
2. **的外れな応答**: 読んでみて初めてわかることが多い
3. **効率性の低下**: 不要な応答まで全文読む必要がある

この問題を解決するために、**事前にカテゴリと要約で内容を把握**できる仕組みを実装しました。これにより、応答の種類を即座に判断し、必要な部分のみを確認できるようになります。

## ファイル構成

```
claude-code-speech/
├── README.md                          # このファイル
├── setup.sh                           # セットアップスクリプト
├── stop-speak-with-summary.sh         # Stopフックスクリプト（応答の要約読み上げ）
├── permission-speak.sh                # PermissionRequestフックスクリプト（確認ダイアログ読み上げ）
└── settings.json                      # 設定例
```

## 参考

- Zenn記事: [Claude Code の音声通知をフックで実装する](https://zenn.dev/yatabis/articles/claude-code-hooks-voice-notification)
- Claude Code公式ドキュメント: https://docs.anthropic.com/claude/docs/claude-code

---

**作成日**: 2026-01-11
**現在のバージョン**: 2.1 (カテゴリ+要約 + 確認ダイアログ読み上げ)
**推奨度**: ★★★★★

### 変更履歴

- **v2.1** (2026-01-11): PermissionRequestフックを追加、確認ダイアログの音声読み上げに対応
- **v2.0** (2026-01-11): カテゴリ分類+要約機能を追加、デバッグモード統合
- **v1.0** (2026-01-11): 初版リリース（シンプル音声読み上げ）
