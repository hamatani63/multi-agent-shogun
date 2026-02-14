<div align="center">

# multi-agent-shogun

**Gemini CLI / Claude Code マルチエージェント統率システム**

*コマンド1つで、3−10体のAIエージェントが並列稼働*

**Gemini CLI, Claude Code, OpenAI Codex, GitHub Copilot, Kimi Code 対応！**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![v3.0 Multi-CLI](https://img.shields.io/badge/v3.0-Multi--CLI_Support-ff6600?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNiIgaGVpZ2h0PSIxNiI+PHRleHQgeD0iMCIgeT0iMTIiIGZvbnQtc2l6ZT0iMTIiPuKalTwvdGV4dD48L3N2Zz4=)](https://github.com/yohey-w/multi-agent-shogun)
[![Gemini CLI](https://img.shields.io/badge/Supports-Gemini_CLI-blue)](https://github.com/google-gemini/gemini-cli)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

[English](README.md) | [日本語](README_ja.md)

</div>

<p align="center">
  <img src="images/screenshots/hero/latest-translucent-20260210-190453.png" alt="Latest translucent command session in the Shogun pane" width="940">
</p>

<p align="center">
  <img src="images/screenshots/hero/latest-translucent-20260208-084602.png" alt="Quick natural-language command in the Shogun pane" width="420">
  <img src="images/company-creed-all-panes.png" alt="Karo and Ashigaru panes reacting in parallel" width="520">
</p>

<p align="center"><i>One Karo (manager) coordinating 8 Ashigaru (workers) — real session, no mock data.</i></p>

---

## これは何？

**multi-agent-shogun** は、複数のAIコーディングCLIインスタンスを同時に実行し、戦国時代の軍制のように統率するシステムです。**Gemini CLI**, **Claude Code**, **OpenAI Codex**, **GitHub Copilot**, **Kimi Code** に対応しています。

**なぜ使うのか？**
- 1つの命令で、3〜10体のAIワーカーが並列で実行
- 待ち時間なし - タスクがバックグラウンドで実行中も次の命令を出せる
- AIがセッションを跨いであなたの好みを記憶（Memory MCP）
- ダッシュボードでリアルタイム進捗確認

```
      あなた（上様）
           │
           ▼ 命令を出す
    ┌─────────────┐
    │   SHOGUN    │  ← 命令を受け取り、即座に委譲
    └──────┬──────┘
           │ YAMLファイル + tmux
    ┌──────▼──────┐
    │    KARO     │  ← タスクをワーカーに分配
    └──────┬──────┘
           │
    ┌───┬──┴──┬───┐
    │ 1 │  2  │ 3 │  ← 3〜8体のワーカーが並列実行
    └───┴─────┴───┘
        ASHIGARU
```

---

## なぜ将軍（Shogun）なのか？

多くのマルチエージェントフレームワークは調整のたびにAPIトークンを消費しますが、Shogunは違います。

| | Claude Code `Task` | LangGraph | CrewAI | **multi-agent-shogun** |
|---|---|---|---|---|
| **アーキテクチャ** | 1プロセス内のサブエージェント | グラフベースの状態遷移 | ロールベース | tmuxによる封建的階層構造 |
| **並列性** | 順次実行（1つずつ） | 並列ノード (v0.2+) | 制限あり | **3〜8体の独立エージェント** |
| **調整コスト** | タスクごとのAPIコール | API + インフラ (DB) | API + 基盤 | **ゼロ** (YAML + tmux) |
| **可観測性** | ログのみ | LangSmith連携 | OpenTelemetry | **tmuxペインで常時可視化** |
| **スキル発見** | なし | なし | なし | **ボトムアップ提案型** |
| **セットアップ** | 組み込み | 重厚（インフラ構成要） | pip install | シェルスクリプトのみ |

### 決定的な違い

**ゼロ・コーディネーション・オーバーヘッド** — エージェントはファイル経由で会話します。APIコールは実作業のみに使われ、調整や会話には一切消費しません。8体動かせば、純粋に8体分の作業コストのみが発生します。

**完全な透明性** — 全エージェントがtmuxペインで見えます。指示、報告、意思決定はすべてYAMLファイルとして残り、Git管理可能です。ブラックボックスはありません。

**実戦的な階層構造** — 将軍→家老→足軽の指揮系統により、競合を防ぎます。明確なオーナーシップ、専用ファイル、イベント駆動通信により、ポーリングも不要です。

---

## なぜCLIなのか？（APIではなく）

多くのAIコーディングツールはトークンごとの従量課金です。Opus級のエージェントをAPIで8体動かせば、**1時間で$100以上**かかります。CLIの定額制（サブスクリプション）なら話は別です：

| | API (従量課金) | CLI (定額制) |
|---|---|---|
| **8エージェント × Opus** | ~$100+/時間 | ~$200/月（推定） |
| **コスト予測** | 不可（スパイク恐怖） | 固定（安心） |
| **使用の心理的障壁** | 1トークンも無駄にできない | 無制限に試行錯誤できる |
| **実験の自由度** | 制約あり | 自由にデプロイ可能 |

**「AIを無謀に使え」** — 定額制CLIなら、8体のエージェントを躊躇なく投入できます。1時間働かせても24時間働かせてもコストは同じ。「そこそこでいいや」と妥協せず、徹底的にやらせることができます。

### マルチCLI対応 (Multi-CLI Support)

Shogunは単一ベンダーにロックインされません。特徴の異なる5つのCLIツールをサポートしています：

| CLI | 主な強み | デフォルトモデル |
|-----|----------|-----------------|
| **Gemini CLI** | **レート制限に寛容**、無料枠あり、**100万トークンコンテキスト** | Gemini 1.5 Pro / Flash |
| **Claude Code** | tmux統合が盤石、Memory MCP、強力なファイル操作 | Claude Sonnet 4.5 |
| **OpenAI Codex** | サンドボックス実行、JSONL構造化出力、ヘッドレスモード | gpt-5.3-codex / **spark** |
| **GitHub Copilot** | GitHub MCP内蔵、4つの専門エージェント、`/delegate`機能 | Claude Sonnet 4.5 |
| **Kimi Code** | 無料枠あり、強力な多言語対応 | Kimi k2 |

統一された指示書ビルドシステムにより、共通テンプレートから各CLI専用の指示書（instructions）を自動生成します一箇所修正すれば全CLIに反映されます。

---

## ボトムアップ・スキル発見

これは他のフレームワークにはない機能です。

足軽がタスクを実行する中で、**再利用可能なパターンを自動的に発見**し、スキル候補として提案します。家老がこれをダッシュボードに集約し、殿（あなた）が承認することで、正式なスキルとして採用されます。

```
足軽がタスク完了
    ↓
「このパターン、他のプロジェクトでも3回使ったな」と気づく
    ↓
YAMLで報告:  skill_candidate:
                found: true
                name: "api-endpoint-scaffold"
                reason: "3つのプロジェクトで共通のREST雛形"
    ↓
ダッシュボードに表示 → あなたが承認 → .claude/commands/ にスキル生成
    ↓
全エージェントが /api-endpoint-scaffold を使えるようになる
```

スキルはライブラリから探すのではなく、日々の実戦から有機的に成長します。あなたのスキルセットは、**あなたのワークフローそのもの**になります。

---

## 🚀 クイックスタート

### Windows (WSL2)

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **リポジトリをダウンロード**

```markdown
[ZIPダウンロード](https://github.com/hamatani63/multi-agent-shogun/archive/refs/heads/main.zip) して `C:\tools\multi-agent-shogun` に展開

*または git を使用:* `git clone https://github.com/hamatani63/multi-agent-shogun.git C:\tools\multi-agent-shogun`
```

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **`install.bat` を実行**

右クリック→「管理者として実行」（WSL2が未インストールの場合）。WSL2 + Ubuntu をセットアップします。

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

🐧 **Ubuntu を開いて以下を実行**（初回のみ）

```bash
cd /mnt/c/tools/multi-agent-shogun
./first_setup.sh
```

</td>
</tr>
<tr>
<td>

**Step 4**

</td>
<td>

✅ **出陣！**

```bash
./shutsujin_departure.sh
```

</td>
</tr>
</table>

#### 初回のみ：認証

`first_setup.sh` の後、一度だけ実行して認証してください：

```bash
# 1. パス反映
source ~/.bashrc

# 2. 認証 (使用するバックエンドに合わせて)
claude --dangerously-skip-permissions  # Claudeの場合
gemini login                           # Geminiの場合
```

### Linux / macOS

```bash
# 1. リポジトリをクローン
git clone https://github.com/hamatani63/multi-agent-shogun.git ~/multi-agent-shogun
cd ~/multi-agent-shogun

# 2. スクリプトに実行権限を付与
chmod +x *.sh

# 3. 初回セットアップを実行
./first_setup.sh
```

### 毎日の起動

```bash
cd ~/multi-agent-shogun
./shutsujin_departure.sh           # 通常起動（前回のタスクを継続）
./shutsujin_departure.sh -c        # クリーン起動（キューをリセット、履歴は保持）
tmux attach-session -t shogun      # 将軍に接続して命令を出す
```

**起動オプション:**
- **デフォルト**: 前回のタスクキューとコマンド履歴を維持して再開
- **`-c` / `--clean`**: タスクキューをリセットして再出発（履歴 `shogun_to_karo.yaml` は保持）。

### 📱 スマホからアクセス（どこからでも指揮）

ベッドから、カフェから、トイレから。スマホでAI部下を操作できる。

**必要なもの（全部無料）：**
- [Tailscale](https://tailscale.com/) - 安全なトンネル
- [Termux](https://termux.dev/) - Android用ターミナル
- SSH - Ubuntuにインストール済み

**手順：**

1. WSLとスマホの両方にTailscaleをインストール
2. WSL側（Auth key方式）：
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscaled &
   sudo tailscale up --authkey tskey-auth-XXXXXXXXXXXX
   sudo service ssh start
   ```
3. スマホのTermuxから：
   ```sh
   pkg update && pkg install openssh
   ssh あなたのユーザー名@あなたのTailscale IP
   css    # 将軍に繋がる
   ```
4. ＋ボタンで新しいウィンドウを開いて、部下の様子も見る：
   ```sh
   ssh あなたのユーザー名@あなたのTailscale IP
   csm    # 家老+足軽の全ペインが広がる
   ```

**切り方：** Termuxのウィンドウをスワイプで閉じるだけ。tmuxセッションは生き残る。

---

## ⚙️ 設定

### 言語設定

```yaml
# config/settings.yaml
language: ja   # 日本語のみ
# language: en   # 日本語 + 英訳併記
```

### バックエンド切替

```yaml
# config/settings.yaml

# Claude バックエンド（デフォルト）
# backend: claude

# Gemini バックエンド
backend: gemini
```

### 🧠 Gemini 設定

Gemini CLI向けに、レート制限と応答速度を考慮した構成になっています。

```yaml
gemini:
  model_shogun: gemini-3-flash-preview
  model_karo: gemini-3-pro-preview
  model_ashigaru_strong: gemini-3-pro-preview
  model_ashigaru_fast: gemini-3-flash-preview
  num_ashigaru: 3  # レート制限回避のため8→3に削減
  auth_method: oauth
```

| エージェント | モデル | 役割 | 理由 |
|-------------|--------|----------|------|
| **将軍** | Flash | 指揮官 | 高速な応答とコンテキスト処理能力（100万トークン） |
| **家老** | **Pro** | 管理者 | タスク分配と進捗管理（強モデル） |
| **足軽1** | **Pro** | 主力 | 複雑な推論やコーディングを担当（強モデル） |
| **足軽2-3** | Flash | 遊撃 | 調査や単純作業を高速に処理（高速モデル） |

#### 陣形モード（Gemini版）

| 陣形 | 足軽1 | 足軽2-3 | コマンド |
|------|---------|---------|---------|
| **平時の陣**（デフォルト） | **Pro** | Flash | `./shutsujin_departure.sh` |
| **決戦の陣**（全力） | **Pro** | **Pro** | `./shutsujin_departure.sh -k` |

### 🧠 Claude 設定

| エージェント | デフォルトモデル | 思考モード |
|-------------|-----------------|------------|
| 将軍 | Opus | 無効 |
| 家老 | Opus | 有効 |
| 足軽1-4 | Sonnet | 有効 |
| 足軽5-8 | Opus | 有効 |

#### 陣形モード（Claude版）

- **平時の陣**: 足軽半数がSonnet、半数がOpus
- **決戦の陣**: 全足軽がOpus（`-k` オプション）

---

## MCPサーバー設定ガイド

#### Gemini CLI

Gemini CLIでは、設定ファイル `~/.gemini/settings.json` を直接編集してMCPサーバーを追加します。

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_FILE_PATH": "/absolute/path/to/multi-agent-shogun/memory/shogun_memory.jsonl"
      }
    }
  }
}
```

#### Claude Code CLI

```bash
# Memory (first_setup.shで自動設定済み)
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/shogun_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory

# Notion
claude mcp add notion -e NOTION_TOKEN=your_token -- npx -y @notionhq/notion-mcp-server

# GitHub
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat -- npx -y @modelcontextprotocol/server-github

# Playwright (ブラウザ操作)
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## 🛠️ 上級者向け情報

<details>
<summary><b>スクリプトアーキテクチャ</b></summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                      初回セットアップ（1回だけ実行）                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  install.bat (Windows)                                              │
│      │                                                              │
│      ├── WSL2のチェック/インストール案内                              │
│      └── Ubuntuのチェック/インストール案内                            │
│                                                                     │
│  first_setup.sh (Ubuntu/WSLで手動実行)                               │
│      │                                                              │
│      ├── tmuxのチェック/インストール                                  │
│      ├── Node.js v20+のチェック/インストール (nvm経由)                │
│      ├── Claude Code CLIのチェック/インストール                      │
│      └── Memory MCPサーバー設定                                      │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                      毎日の起動（毎日実行）                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  shutsujin_departure.sh                                             │
│      │                                                              │
│      ├──▶ tmuxセッションを作成                                       │
│      │         • "shogun"セッション（1ペイン）                        │
│      │         • "multiagent"セッション（9ペイン、3x3グリッド）        │
│      │                                                              │
│      ├──▶ キューファイルとダッシュボードをリセット                     │
│      │                                                              │
│      └──▶ 全エージェントでClaude Codeを起動                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

</details>

<details>
<summary><b>技術的な詳細</b></summary>

- **エージェント識別** (`@agent_id`) — tmuxユーザーオプションでIDを固定。ペイン入れ替えの影響を受けない。
- **決戦モード**（`-k` フラグ）— 全足軽Opus/Proの最大火力陣形。
- **タスク依存関係システム**（`blockedBy`）— 依存タスク完了時に自動でブロック解除。

</details>

---

## コントリビューション

Issue、Pull Requestを歓迎します。

- **バグ報告**: 再現手順を添えてIssueを作成してください
- **機能アイデア**: まずDiscussionで提案してください
- **スキル**: スキルは個人のワークフローに最適化されるものであり、このリポジトリには含めません

## 🙏 クレジット

[Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa をベースに開発。

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。

---

<div align="center">

**コマンド1つ。エージェント8体。連携コストゼロ。**

⭐ 役に立ったらスターをお願いします — 他の人にも見つけてもらえます。

</div>
