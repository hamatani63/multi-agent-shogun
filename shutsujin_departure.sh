#!/bin/bash
# 🏯 multi-agent-shogun 出陣スクリプト（毎日の起動用）
# Daily Deployment Script for Multi-Agent Orchestration System
#
# 使用方法:
#   ./shutsujin_departure.sh           # 全エージェント起動（前回の状態を維持）
#   ./shutsujin_departure.sh -c        # キューをリセットして起動（クリーンスタート）
#   ./shutsujin_departure.sh -s        # セットアップのみ（Claude起動なし）
#   ./shutsujin_departure.sh -h        # ヘルプ表示

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 設定ファイルが存在しない場合、exampleから作成
if [ ! -f "./config/settings.yaml" ] && [ -f "./config/settings.yaml.example" ]; then
    echo "⚠️ config/settings.yaml が見つかりません。デフォルト設定を作成します..."
    cp ./config/settings.yaml.example ./config/settings.yaml
    echo "✅ config/settings.yaml を作成しました。"
fi

# 言語設定を読み取り（デフォルト: ja）
LANG_SETTING="ja"
if [ -f "./config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# シェル設定を読み取り（デフォルト: bash）
SHELL_SETTING="bash"
if [ -f "./config/settings.yaml" ]; then
    SHELL_SETTING=$(grep "^shell:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "bash")
fi

# CLI Adapter読み込み（Multi-CLI Support）
if [ -f "$SCRIPT_DIR/lib/cli_adapter.sh" ]; then
    source "$SCRIPT_DIR/lib/cli_adapter.sh"
    CLI_ADAPTER_LOADED=true
else
    CLI_ADAPTER_LOADED=false
fi

# 色付きログ関数（戦国風）
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_war() {
    echo -e "\033[1;31m【戦】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# プロンプト生成関数（bash/zsh対応）
# ───────────────────────────────────────────────────────────────────────────────
# 使用法: generate_prompt "ラベル" "色" "シェル"
# 色: red, green, blue, magenta, cyan, yellow
# ═══════════════════════════════════════════════════════════════════════════════
generate_prompt() {
    local label="$1"
    local color="$2"
    local shell_type="$3"

    if [ "$shell_type" == "zsh" ]; then
        # zsh用: %F{color}%B...%b%f 形式
        echo "(%F{${color}}%B${label}%b%f) %F{green}%B%~%b%f%# "
    else
        # bash用: \[\033[...m\] 形式
        local color_code
        case "$color" in
            red)     color_code="1;31" ;;
            green)   color_code="1;32" ;;
            yellow)  color_code="1;33" ;;
            blue)    color_code="1;34" ;;
            magenta) color_code="1;35" ;;
            cyan)    color_code="1;36" ;;
            *)       color_code="1;37" ;;  # white (default)
        esac
        echo "(\[\033[${color_code}m\]${label}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ "
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# オプション解析
# ═══════════════════════════════════════════════════════════════════════════════
SETUP_ONLY=false
OPEN_TERMINAL=false
CLEAN_MODE=false
KESSEN_MODE=false
SHOGUN_NO_THINKING=false
SILENT_MODE=false
SHELL_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--setup-only)
            SETUP_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        -k|--kessen)
            KESSEN_MODE=true
            shift
            ;;
        -t|--terminal)
            OPEN_TERMINAL=true
            shift
            ;;
        --shogun-no-thinking)
            SHOGUN_NO_THINKING=true
            shift
            ;;
        -S|--silent)
            SILENT_MODE=true
            shift
            ;;
        -shell|--shell)
            if [[ -n "$2" && "$2" != -* ]]; then
                SHELL_OVERRIDE="$2"
                shift 2
            else
                echo "エラー: -shell オプションには bash または zsh を指定してください"
                exit 1
            fi
            ;;
        -h|--help)
            echo ""
            echo "🏯 multi-agent-shogun 出陣スクリプト"
            echo ""
            echo "使用方法: ./shutsujin_departure.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -c, --clean         キューとダッシュボードをリセットして起動（クリーンスタート）"
            echo "                      未指定時は前回の状態を維持して起動"
            echo "  -k, --kessen        決戦の陣（全足軽を強モデル[Opus/Pro]で起動）"
            echo "                      未指定時は平時の陣"
            echo "  -s, --setup-only    tmuxセッションのセットアップのみ（エージェント起動なし）"
            echo "  -t, --terminal      Windows Terminal で新しいタブを開く"
            echo "  -shell, --shell SH  シェルを指定（bash または zsh）"
            echo "                      未指定時は config/settings.yaml の設定を使用"
            echo "  -S, --silent        サイレントモード（足軽の戦国echo表示を無効化・API節約）"
            echo "                      未指定時はshoutモード（タスク完了時に戦国風echo表示）"
            echo "  --shogun-no-thinking  将軍のthinkingを無効化（中継特化・Claudeのみ）"
            echo "  -h, --help          このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./shutsujin_departure.sh              # 前回の状態を維持して出陣"
            echo "  ./shutsujin_departure.sh -c           # クリーンスタート（キューリセット）"
            echo "  ./shutsujin_departure.sh -s           # セットアップのみ（手動で起動）"
            echo "  ./shutsujin_departure.sh -t           # 全エージェント起動 + ターミナルタブ展開"
            echo "  ./shutsujin_departure.sh -shell bash  # bash用プロンプトで起動"
            echo "  ./shutsujin_departure.sh -k           # 決戦の陣"
            echo "  ./shutsujin_departure.sh -c -k        # クリーンスタート＋決戦の陣"
            echo "  ./shutsujin_departure.sh -S           # サイレントモード"
            echo ""
            echo "エイリアス:"
            echo "  csst  → cd /mnt/c/tools/multi-agent-shogun && ./shutsujin_departure.sh"
            echo "  css   → tmux attach-session -t shogun"
            echo "  csm   → tmux attach-session -t multiagent"
            echo ""
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            echo "./shutsujin_departure.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# シェル設定のオーバーライド（コマンドラインオプション優先）
if [ -n "$SHELL_OVERRIDE" ]; then
    if [[ "$SHELL_OVERRIDE" == "bash" || "$SHELL_OVERRIDE" == "zsh" ]]; then
        SHELL_SETTING="$SHELL_OVERRIDE"
    else
        echo "エラー: -shell オプションには bash または zsh を指定してください（指定値: $SHELL_OVERRIDE）"
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 出陣バナー表示（CC0ライセンスASCIIアート使用）
# ───────────────────────────────────────────────────────────────────────────────
# 【著作権・ライセンス表示】
# 忍者ASCIIアート: syntax-samurai/ryu - CC0 1.0 Universal (Public Domain)
# 出典: https://github.com/syntax-samurai/ryu
# "all files and scripts in this repo are released CC0 / kopimi!"
# ═══════════════════════════════════════════════════════════════════════════════
show_battle_cry() {
    clear

    # タイトルバナー（色付き）
    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗██╗  ██╗██╗   ██╗████████╗███████╗██╗   ██╗     ██╗██╗███╗   ██╗\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m██╔════╝██║  ██║██║   ██║╚══██╔══╝██╔════╝██║   ██║     ██║██║████╗  ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗███████║██║   ██║   ██║   ███████╗██║   ██║     ██║██║██╔██╗ ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚════██║██╔══██║██║   ██║   ██║   ╚════██║██║   ██║██   ██║██║██║╚██╗██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████║██║  ██║╚██████╔╝   ██║   ███████║╚██████╔╝╚█████╔╝██║██║ ╚████║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝  ╚════╝ ╚═╝╚═╝  ╚═══╝\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m       \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35m天下布武！\033[0m                          \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    # 足軽隊列（オリジナル）
    echo -e "\033[1;34m  ╔═════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m  ║\033[0m                    \033[1;37m【 足 軽 隊 列 ・ 配 備 】\033[0m                          \033[1;34m║\033[0m"
    echo -e "\033[1;34m  ╚═════════════════════════════════════════════════════════════════════════════╝\033[0m"

    cat << 'ASHIGARU_EOF'

       /\      /\      /\      /\      /\      /\      /\      /\ 
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\ 
     /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\ 
       ||      ||      ||      ||      ||      ||      ||      ||  
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\ 
      /  \    /  \    /  \    /  \    /  \    /  \    /  \    /  \ 
     [足1]   [足2]   [足3]   ...     ...     ...     ...     [足N]

ASHIGARU_EOF

    echo -e "                    \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""

    # システム情報
    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-shogun\033[0m  〜 \033[1;36m戦国マルチエージェント統率システム\033[0m 〜           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m将軍\033[0m: プロジェクト統括    \033[1;31m家老\033[0m: タスク管理    \033[1;34m足軽\033[0m: 実働部隊          \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# バナー表示実行
show_battle_cry

echo -e "  \033[1;33m天下布武！陣立てを開始いたす\033[0m (Setting up the battlefield)"
echo ""

# バックエンド設定と足軽数を早期読み込み（CLEAN_MODE処理で必要）
BACKEND="claude"
if [ -f "./config/settings.yaml" ]; then
    BACKEND=$(grep "^backend:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "claude")
fi

# 足軽数を読み込み（バックエンド別）
if [ "$BACKEND" = "gemini" ]; then
    # Gemini defaults to 3 to avoid rate limits
    NUM_ASHIGARU=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "num_ashigaru:" | awk '{print $2}' || echo "3")
else
    # Upstream default is 8
    NUM_ASHIGARU=$(grep -A10 "^claude:" ./config/settings.yaml 2>/dev/null | grep "num_ashigaru:" | awk '{print $2}' || echo "8")
fi
NUM_ASHIGARU=${NUM_ASHIGARU:-8}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 0.5: バックエンド別 .gitignore 生成
# ═══════════════════════════════════════════════════════════════════════════════
if [ -f "./.gitignore.base" ] && [ -f "./.gitignore.${BACKEND}" ]; then
    log_info "📜 .gitignore を生成中（${BACKEND}版）..."
    cat ./.gitignore.base ./.gitignore.${BACKEND} > ./.gitignore
    log_info "  └─ .gitignore.base + .gitignore.${BACKEND} → .gitignore"
else
    log_info "⚠️  .gitignore テンプレートが見つかりません（既存の.gitignoreを使用）"
fi

# Gemini版: .git/info/exclude にランタイムファイルを追加
# (Gitからは除外するが、Gemini CLIからはアクセス可能にする)
if [ "$BACKEND" = "gemini" ] && [ -d "./.git/info" ]; then
    log_info "📜 .git/info/exclude を設定中（Gemini用）..."
    cat > ./.git/info/exclude << 'EXCLUDE_EOF'
# ============================================
# Auto-generated by shutsujin_departure.sh
# Local Git exclusions for Gemini CLI backend
# ============================================
# These files are needed by Gemini CLI but should not be committed

# Runtime queue files
queue/
queue/*.yaml
queue/tasks/
queue/reports/
queue/research/

# Dashboard
dashboard.md

# Config and status
config/settings.yaml
status/
EXCLUDE_EOF
    log_info "  └─ queue/, dashboard.md, config/settings.yaml, status/ をGitから除外（Gemini CLIアクセス許可）"
fi


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: 既存セッションクリーンアップ
# ═══════════════════════════════════════════════════════════════════════════════
log_info "🧹 既存の陣を撤収中..."
tmux kill-session -t multiagent 2>/dev/null && log_info "  └─ multiagent陣、撤収完了" || log_info "  └─ multiagent陣は存在せず"
tmux kill-session -t shogun 2>/dev/null && log_info "  └─ shogun本陣、撤収完了" || log_info "  └─ shogun本陣は存在せず"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1.5: 前回記録のバックアップ（--clean時のみ、内容がある場合）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$CLEAN_MODE" = true ]; then
    BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
    NEED_BACKUP=false

    if [ -f "./dashboard.md" ]; then
        if grep -q "cmd_" "./dashboard.md" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    # 既存の dashboard.md 判定の後に追加
    if [ -f "./queue/shogun_to_karo.yaml" ]; then
        if grep -q "id: cmd_" "./queue/shogun_to_karo.yaml" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    if [ "$NEED_BACKUP" = true ]; then
        mkdir -p "$BACKUP_DIR" || true
        cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/tasks" "$BACKUP_DIR/" 2>/dev/null || true
        cp "./queue/shogun_to_karo.yaml" "$BACKUP_DIR/" 2>/dev/null || true
        log_info "📦 前回の記録をバックアップ: $BACKUP_DIR"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: キューディレクトリ確保 + リセット（--clean時のみリセット）
# ═══════════════════════════════════════════════════════════════════════════════

# queue ディレクトリが存在しない場合は作成（初回起動時に必要）
[ -d ./queue/reports ] || mkdir -p ./queue/reports
[ -d ./queue/tasks ] || mkdir -p ./queue/tasks

# inbox はLinux FSにシンボリックリンク（WSL2の/mnt/c/ではinotifywaitが動かないため）
# inbox はLinux FSにシンボリックリンク（WSL2の/mnt/c/ではinotifywaitが動かないため）
# ただし Gemini CLI (macOS/Native) の場合はシンボリックリンク不可（ワークスペース外アクセス禁止）
if [ "$BACKEND" = "gemini" ]; then
    if [ -L ./queue/inbox ]; then
        rm ./queue/inbox
        mkdir -p ./queue/inbox
        log_info "  └─ inbox をローカルディレクトリに戻しました（Gemini用）"
    elif [ ! -d ./queue/inbox ]; then
        mkdir -p ./queue/inbox
        log_info "  └─ inbox ディレクトリ作成（Gemini用）"
    fi
else
    INBOX_LINUX_DIR="$HOME/.local/share/multi-agent-shogun/inbox"
    if [ ! -L ./queue/inbox ]; then
        mkdir -p "$INBOX_LINUX_DIR"
        [ -d ./queue/inbox ] && cp ./queue/inbox/*.yaml "$INBOX_LINUX_DIR/" 2>/dev/null && rm -rf ./queue/inbox
        ln -sf "$INBOX_LINUX_DIR" ./queue/inbox
        log_info "  └─ inbox → Linux FS ($INBOX_LINUX_DIR) にシンボリックリンク作成"
    fi
fi

if [ "$CLEAN_MODE" = true ]; then
    log_info "📜 前回の軍議記録を破棄中..."

    # 足軽タスクファイルリセット
    for i in $(seq 1 $NUM_ASHIGARU); do
        cat > ./queue/tasks/ashigaru${i}.yaml << EOF
# 足軽${i}専用タスクファイル
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
    done

    # 足軽レポートファイルリセット
    for i in $(seq 1 $NUM_ASHIGARU); do
        cat > ./queue/reports/ashigaru${i}_report.yaml << EOF
worker_id: ashigaru${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    done

    # ntfy inbox リセット
    echo "inbox:" > ./queue/ntfy_inbox.yaml

    # agent inbox リセット
    # Dynamically create inbox for all agents
    echo "messages:" > "./queue/inbox/shogun.yaml"
    echo "messages:" > "./queue/inbox/karo.yaml"
    for i in $(seq 1 $NUM_ASHIGARU); do
        echo "messages:" > "./queue/inbox/ashigaru${i}.yaml"
    done

    log_success "✅ 陣払い完了"
else
    log_info "📜 前回の陣容を維持して出陣..."
    log_success "✅ キュー・報告ファイルはそのまま継続"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: ダッシュボード初期化（--clean時のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$CLEAN_MODE" = true ]; then
    log_info "📊 戦況報告板を初期化中..."
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

    if [ "$LANG_SETTING" = "ja" ]; then
        # 日本語のみ
        cat > ./dashboard.md << EOF
# 📊 戦況報告
最終更新: ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております
なし

## 🔄 進行中 - 只今、戦闘中でござる
なし

## ✅ 本日の戦果
| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち
なし

## 🛠️ 生成されたスキル
なし

## ⏸️ 待機中
なし

## ❓ 伺い事項
なし
EOF
    else
        # 日本語 + 翻訳併記
        cat > ./dashboard.md << EOF
# 📊 戦況報告 (Battle Status Report)
最終更新 (Last Updated): ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております (Action Required - Awaiting Lord's Decision)
なし (None)

## 🔄 進行中 - 只今、戦闘中でござる (In Progress - Currently in Battle)
なし (None)

## ✅ 本日の戦果 (Today's Achievements)
| 時刻 (Time) | 戦場 (Battlefield) | 任務 (Mission) | 結果 (Result) |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち (Skill Candidates - Pending Approval)
なし (None)

## 🛠️ 生成されたスキル (Generated Skills)
なし (None)

## ⏸️ 待機中 (On Standby)
なし (None)

## ❓ 伺い事項 (Questions for Lord)
なし (None)
EOF
    fi

    log_success "  └─ ダッシュボード初期化完了 (言語: $LANG_SETTING, シェル: $SHELL_SETTING)"
else
    log_info "📊 前回のダッシュボードを維持"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: tmux の存在確認
# ═══════════════════════════════════════════════════════════════════════════════
if ! command -v tmux &> /dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] tmux not found!                              ║"
    echo "  ║  tmux が見つかりません                                 ║"
    echo "  ╠════════════════════════════════════════════════════════╣"
    echo "  ║  Run first_setup.sh first:                            ║"
    echo "  ║  まず first_setup.sh を実行してください:               ║"
    echo "  ║     ./first_setup.sh                                  ║"
    echo "  ╚════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: shogun セッション作成（1ペイン・window 0 を必ず確保）
# ═══════════════════════════════════════════════════════════════════════════════
log_war "👑 将軍の本陣を構築中..."

# shogun セッションがなければ作る（-s 時もここで必ず shogun が存在するようにする）
# window 0 のみ作成し -n main で名前付け（第二 window にするとアタッチ時に空ペインが開くため 1 window に限定）
if ! tmux has-session -t shogun 2>/dev/null; then
    tmux new-session -d -s shogun -n main
fi

# 将軍ペインはウィンドウ名 "main" で指定（base-index 1 環境でも動く）
SHOGUN_PROMPT=$(generate_prompt "将軍" "magenta" "$SHELL_SETTING")
tmux send-keys -t shogun:main "cd \"$(pwd)\" && export PS1='${SHOGUN_PROMPT}' && clear" Enter
tmux select-pane -t shogun:main -P 'bg=#002b36'  # 将軍の Solarized Dark
tmux set-option -p -t shogun:main @agent_id "shogun"

log_success "  └─ 将軍の本陣、構築完了"

# Gemini: Start Shogun agent if not setup-only
if [ "$BACKEND" = "gemini" ] && [ "$SETUP_ONLY" = false ]; then
    log_info "👑 将軍(Gemini)を起動中..."
    SHOGUN_MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_shogun:" | awk '{print $2}' || echo "gemini-3-flash-preview")
    
    CMD="gemini --model $SHOGUN_MODEL --yolo"
    tmux send-keys -t shogun:main "$CMD" Enter
    
    # Send instructions via tmux buffer
    if [ -f "instructions/shogun.md" ]; then
        sleep 2
        tmux load-buffer "instructions/shogun.md"
        tmux paste-buffer -t shogun:main
        tmux send-keys -t shogun:main Enter
    fi
    log_success "  └─ 将軍起動完了"
fi

echo ""

# pane-base-index を取得（1 の環境ではペインは 1,2,... になる）
PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5.1: multiagent セッション作成（動的ペイン数）
# ═══════════════════════════════════════════════════════════════════════════════
log_war "⚔️ 家老・足軽の陣を構築中（${NUM_ASHIGARU}名配備）..."

# 最初のペイン作成
if ! tmux new-session -d -s multiagent -n "agents" 2>/dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] Failed to create tmux session 'multiagent'      ║"
    echo "  ║  tmux セッション 'multiagent' の作成に失敗しました       ║"
    echo "  ╠════════════════════════════════════════════════════════════╣"
    echo "  ║  An existing session may be running.                     ║"
    echo "  ║  既存セッションが残っている可能性があります              ║"
    echo "  ║                                                          ║"
    echo "  ║  Check: tmux ls                                          ║"
    echo "  ║  Kill:  tmux kill-session -t multiagent                  ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# 動的ペイン作成（NUM_ASHIGARU + 1（家老）ペイン）
# ペイン番号は pane-base-index に依存（0 または 1）
TOTAL_PANES=$((NUM_ASHIGARU + 1))  # 家老 + 足軽

# 必要なペイン数だけ作成
if [ "$TOTAL_PANES" -eq 1 ]; then
    # 1ペインのみ（家老のみ）- 何もしない
    :
elif [ "$TOTAL_PANES" -eq 2 ]; then
    # 2ペイン: 横に1つ分割
    tmux split-window -h -t "multiagent:agents"
elif [ "$TOTAL_PANES" -ge 3 ] && [ "$TOTAL_PANES" -le 4 ]; then
    # 3-4ペイン: 2x2グリッドベース
    # 3ペインの場合も4ペイン作成してから調整
    # ペイン配置（PANE_BASE=0の場合）:
    #   [0(家老)] [2(足軽2)]
    #   [1(足軽1)] [3(足軽3 or 空)]
    tmux split-window -h -t "multiagent:agents"
    tmux select-pane -t "multiagent:agents.${PANE_BASE}"
    tmux split-window -v
    tmux select-pane -t "multiagent:agents.$((PANE_BASE+2))"
    tmux split-window -v
else
    # 5ペイン以上: 3x3グリッド (Upstream logic adapted)
    tmux split-window -h -t "multiagent:agents"
    tmux split-window -h -t "multiagent:agents"
    
    tmux select-pane -t "multiagent:agents.${PANE_BASE}"
    tmux split-window -v
    tmux split-window -v
    
    tmux select-pane -t "multiagent:agents.$((PANE_BASE+3))"
    tmux split-window -v
    tmux split-window -v
    
    tmux select-pane -t "multiagent:agents.$((PANE_BASE+6))"
    tmux split-window -v
    tmux split-window -v
fi

# DISPLAY_MODE: shout (default) or silent (--silent flag)
if [ "$SILENT_MODE" = true ]; then
    tmux set-environment -t multiagent DISPLAY_MODE "silent"
    echo "  📢 表示モード: サイレント（echo表示なし）"
else
    tmux set-environment -t multiagent DISPLAY_MODE "shout"
fi

# ペインラベル設定（動的生成）
PANE_LABELS=("karo")
PANE_TITLES=()
PANE_COLORS=("red")
AGENT_IDS=("karo")
MODEL_NAMES=()

# 家老のモデル名とタイトル
if [ "$BACKEND" = "gemini" ]; then
    KARO_MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_karo:" | awk '{print $2}' || echo "gemini-3-pro-preview")
    PANE_TITLES+=("karo($KARO_MODEL)")
    MODEL_NAMES+=("$KARO_MODEL")
else
    # Upstream logic usage for Karo (fallback to Opus/Default)
    PANE_TITLES+=("karo(Opus)")
    MODEL_NAMES+=("Opus")
fi

# 足軽のラベル・タイトル・色を動的生成
for i in $(seq 1 $NUM_ASHIGARU); do
    PANE_LABELS+=("ashigaru${i}")
    PANE_COLORS+=("blue")
    AGENT_IDS+=("ashigaru${i}")
    
    if [ "$BACKEND" = "gemini" ]; then
        # Gemini版: strong_ashigaru_countに応じてモデル切り替え
        STRONG_COUNT=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "strong_ashigaru_count:" | awk '{print $2}' || echo "1")
        if [ $i -le $STRONG_COUNT ]; then
            ASHIGARU_MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_ashigaru_strong:" | awk '{print $2}' || echo "gemini-3-pro-preview")
        else
            ASHIGARU_MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_ashigaru_fast:" | awk '{print $2}' || echo "gemini-3-flash-preview")
        fi
        PANE_TITLES+=("ashigaru${i}($ASHIGARU_MODEL)")
        MODEL_NAMES+=("$ASHIGARU_MODEL")
    elif [ "$KESSEN_MODE" = true ]; then
        PANE_TITLES+=("ashigaru${i}(Opus)")
        MODEL_NAMES+=("Opus")
    else
        if [ $i -le 4 ]; then
            PANE_TITLES+=("ashigaru${i}(Sonnet)")
            MODEL_NAMES+=("Sonnet")
        else
            PANE_TITLES+=("ashigaru${i}(Opus)")
            MODEL_NAMES+=("Opus")
        fi
    fi
done

# 各ペインに設定を適用
for i in $(seq 0 $NUM_ASHIGARU); do
    p=$((PANE_BASE + i))
    
    # ペインが存在するか確認（念の為）
    if tmux list-panes -t "multiagent:agents" -F "#{pane_index}" | grep -q "^${p}$"; then
        tmux select-pane -t "multiagent:agents.${p}" -T "${PANE_TITLES[$i]}"
        tmux set-option -p -t "multiagent:agents.${p}" @agent_id "${AGENT_IDS[$i]}"
        tmux set-option -p -t "multiagent:agents.${p}" @model_name "${MODEL_NAMES[$i]}"
        
        # CLI Adapter override for non-Gemini backends (if adapter loaded)
        if [ "$BACKEND" != "gemini" ] && [ "$CLI_ADAPTER_LOADED" = true ]; then
           _agent="${AGENT_IDS[$i]}"
           _cli=$(get_cli_type "$_agent")
           # For codex, update title
           if [ "$_cli" = "codex" ]; then
                _codex_model=$(get_agent_model "$_agent")
                if [[ -n "$_codex_model" ]]; then
                    MODEL_NAMES[$i]="codex/${_codex_model}"
                else
                    _codex_effort=$(grep '^model_reasoning_effort' ~/.codex/config.toml 2>/dev/null | head -1 | sed 's/.*= *"\(.*\)"/\1/')
                    _codex_effort=${_codex_effort:-high}
                    MODEL_NAMES[$i]="codex/${_codex_effort}"
                fi
                tmux set-option -p -t "multiagent:agents.${p}" @model_name "${MODEL_NAMES[$i]}"
           fi
        fi
    fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5.5: Inbox Watcher 起動 (Background Service)
# ═══════════════════════════════════════════════════════════════════════════════
log_info "👀 Inbox Watcher を起動中..."

# ログディレクトリ確保
mkdir -p "$SCRIPT_DIR/logs"

# 既存のwatcherプロセスをkill（簡易的）
pkill -f "inbox_watcher.sh" 2>/dev/null || true

# Watcher用CLI種別決定
_watcher_cli="$BACKEND"
# Upstream defaults to "claude" if not gemini
if [ "$BACKEND" != "gemini" ]; then
    _watcher_cli="claude"
fi

# 将軍のwatcher
nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" shogun "shogun:main" "$_watcher_cli" \
    >> "$SCRIPT_DIR/logs/inbox_watcher_shogun.log" 2>&1 &

# 家老のwatcher
nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" karo "multiagent:agents.${PANE_BASE}" "$_watcher_cli" \
    >> "$SCRIPT_DIR/logs/inbox_watcher_karo.log" 2>&1 &

# 足軽のwatcher
for i in $(seq 1 $NUM_ASHIGARU); do
    p=$((PANE_BASE + i))
    nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" "ashigaru${i}" "multiagent:agents.${p}" "$_watcher_cli" \
        >> "$SCRIPT_DIR/logs/inbox_watcher_ashigaru${i}.log" 2>&1 &
done

log_success "  └─ Inbox Watchers 起動完了"


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5.6: ntfy Listener 起動 (Optional)
# ═══════════════════════════════════════════════════════════════════════════════
NTFY_TOPIC=$(grep 'ntfy_topic:' "./config/settings.yaml" | awk '{print $2}' | tr -d '"' || echo "")

if [ -n "$NTFY_TOPIC" ]; then
    log_info "📱 ntfy Listener を起動中 (topic: $NTFY_TOPIC)..."
    
    # 既存プロセスkill
    pkill -f "ntfy_listener.sh" 2>/dev/null || true
    
    nohup bash "$SCRIPT_DIR/scripts/ntfy_listener.sh" \
        >> "$SCRIPT_DIR/logs/ntfy_listener.log" 2>&1 &
        
    log_success "  └─ ntfy Listener 起動完了"
else
    log_info "📱 ntfy Listener はスキップ (ntfy_topic 未設定)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: エージェント起動（-s オプション指定時はスキップ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$SETUP_ONLY" = true ]; then
    log_success "✅ セッション構築完了（エージェントは未起動）。"
    echo "  起動するには各ペインでコマンドを実行するか、再度 ./shutsujin_departure.sh を実行してください。"
else
    # 待機時間を計算（APIレートリミット対策）
    # Geminiの場合、少し長めに待つ（安全策）
    if [ "$BACKEND" = "gemini" ]; then
        SLEEP_INTERVAL=3
    else
        SLEEP_INTERVAL=2
    fi

    log_success "🚀 全エージェント起動開始（${SLEEP_INTERVAL}秒間隔）..."

    # エージェント起動ループ
    for i in $(seq 0 $NUM_ASHIGARU); do
        p=$((PANE_BASE + i))
        AGENT_ID="${AGENT_IDS[$i]}"
        COLOR="${PANE_COLORS[$i]}"
        PROMPT=$(generate_prompt "$AGENT_ID" "$COLOR" "$SHELL_SETTING")
        LABEL="${PANE_LABELS[$i]}"
        
        # プロンプト設定とクリア
        tmux send-keys -t "multiagent:agents.${p}" "cd \"$(pwd)\" && export PS1='${PROMPT}' && clear" Enter
        
        # エージェントコマンド構築
        CMD=""
        if [ "$BACKEND" = "gemini" ]; then
             # Gemini CLI command
             # Determine model
             if [ "$AGENT_ID" = "karo" ]; then
                 MODEL="$KARO_MODEL"
             else
                 # Determine ashigaru model again (simplified)
                 IDX=${AGENT_ID#ashigaru} # remove 'ashigaru' prefix
                 STRONG_COUNT=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "strong_ashigaru_count:" | awk '{print $2}' || echo "1")
                 if [ $IDX -le $STRONG_COUNT ]; then
                     MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_ashigaru_strong:" | awk '{print $2}' || echo "gemini-3-pro-preview")
                 else
                     MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_ashigaru_fast:" | awk '{print $2}' || echo "gemini-3-flash-preview")
                 fi
             fi
             CMD="gemini --model $MODEL --yolo"

             # Determine instruction file
             if [ "$AGENT_ID" = "karo" ]; then
                 INSTRUCTION_FILE="instructions/karo.md"
             else
                 INSTRUCTION_FILE="instructions/ashigaru.md"
             fi
        else
            # Claude/Other (Upstream logic)
            if [ "$CLI_ADAPTER_LOADED" = true ]; then
                CMD=$(build_cli_command "$AGENT_ID")
            else
                # Fallback legacy claude command
                CMD="claude --dangerously-skip-permissions"
                if [ "$KESSEN_MODE" = true ]; then
                    CMD="$CMD --model opus"
                elif [[ "$AGENT_ID" == "ashigaru"* ]]; then
                     IDX=${AGENT_ID#ashigaru}
                     if [ "$IDX" -le 4 ]; then
                         CMD="$CMD --model sonnet"
                     else
                         CMD="$CMD --model opus"
                     fi
                fi
            fi
        fi

        log_info "  ├─ ${AGENT_ID} 起動..."
        tmux send-keys -t "multiagent:agents.${p}" "$CMD" Enter
        
        # Gemini: Send system instruction via tmux buffer
        if [ "$BACKEND" = "gemini" ] && [ -n "$INSTRUCTION_FILE" ]; then
            sleep 2  # Wait for REPL to start
            tmux load-buffer "$INSTRUCTION_FILE"
            tmux paste-buffer -t "multiagent:agents.${p}"
            tmux send-keys -t "multiagent:agents.${p}" Enter
        fi

        sleep "$SLEEP_INTERVAL"
    done
    
    log_success "✅ 全エージェント出陣！"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: ターミナル自動展開（-t オプション時）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$OPEN_TERMINAL" = true ]; then
    log_info "💻 Windows Terminal を展開中..."
    
    # Windows Terminal が利用可能か確認
    if command -v wt.exe &> /dev/null; then
        wt.exe -w 0 new-tab wsl.exe -e bash -c "tmux attach-session -t shogun" \; new-tab wsl.exe -e bash -c "tmux attach-session -t multiagent"
        log_success "  └─ ターミナルタブ展開完了"
    else
        log_info "  └─ wt.exe が見つかりません。手動でアタッチしてください。"
    fi
    echo ""
fi
