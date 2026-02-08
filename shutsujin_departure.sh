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
    echo "✅ config/settings.yaml を作成しました（デフォルト: Gemini backend）。"
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
            echo "  -k, --kessen        決戦の陣（全足軽をOpus Thinkingで起動）"
            echo "                      未指定時は平時の陣（足軽1-4=Sonnet, 足軽5-8=Opus）"
            echo "  -s, --setup-only    tmuxセッションのセットアップのみ（Claude起動なし）"
            echo "  -t, --terminal      Windows Terminal で新しいタブを開く"
            echo "  -shell, --shell SH  シェルを指定（bash または zsh）"
            echo "                      未指定時は config/settings.yaml の設定を使用"
            echo "  -h, --help          このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./shutsujin_departure.sh              # 前回の状態を維持して出陣"
            echo "  ./shutsujin_departure.sh -c           # クリーンスタート（キューリセット）"
            echo "  ./shutsujin_departure.sh -s           # セットアップのみ（手動でClaude起動）"
            echo "  ./shutsujin_departure.sh -t           # 全エージェント起動 + ターミナルタブ展開"
            echo "  ./shutsujin_departure.sh -shell bash  # bash用プロンプトで起動"
            echo "  ./shutsujin_departure.sh -k           # 決戦の陣（全足軽Opus Thinking）"
            echo "  ./shutsujin_departure.sh -c -k         # クリーンスタート＋決戦の陣"
            echo "  ./shutsujin_departure.sh -shell zsh   # zsh用プロンプトで起動"
            echo ""
            echo "モデル構成:"
            echo "  将軍:      Opus（thinking無効）"
            echo "  家老:      Opus Thinking"
            echo "  足軽1-4:   Sonnet Thinking"
            echo "  足軽5-8:   Opus Thinking"
            echo ""
            echo "陣形:"
            echo "  平時の陣（デフォルト）: 足軽1-4=Sonnet Thinking, 足軽5-8=Opus Thinking"
            echo "  決戦の陣（--kessen）:   全足軽=Opus Thinking"
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
    echo -e "\033[1;31m║\033[0m     \033[1;33m███████╗██╗  ██╗██╗   ██╗████████╗███████╗██╗   ██╗     ██╗██╗███╗   ██╗\033[0m     \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m     \033[1;33m██╔════╝██║  ██║██║   ██║╚══██╔══╝██╔════╝██║   ██║     ██║██║████╗  ██║\033[0m     \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m     \033[1;33m███████╗███████║██║   ██║   ██║   ███████╗██║   ██║     ██║██║██╔██╗ ██║\033[0m     \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m     \033[1;33m╚════██║██╔══██║██║   ██║   ██║   ╚════██║██║   ██║██   ██║██║██║╚██╗██║\033[0m     \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m     \033[1;33m███████║██║  ██║╚██████╔╝   ██║   ███████║╚██████╔╝╚█████╔╝██║██║ ╚████║\033[0m     \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m     \033[1;33m╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝  ╚════╝ ╚═╝╚═╝  ╚═══╝\033[0m     \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m             \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35m天下布武！\033[0m                              \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # 足軽隊列（オリジナル）
    # ═══════════════════════════════════════════════════════════════════════════
    echo -e "\033[1;34m  ╔═════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m  ║\033[0m                    \033[1;37m【 足 軽 隊 列 ・ 八 名 配 備 】\033[0m                         \033[1;34m║\033[0m"
    echo -e "\033[1;34m  ╚═════════════════════════════════════════════════════════════════════════════╝\033[0m"

    cat << 'ASHIGARU_EOF'

       /\      /\      /\      /\      /\      /\      /\      /\
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
     /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\
       ||      ||      ||      ||      ||      ||      ||      ||
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
      /  \    /  \    /  \    /  \    /  \    /  \    /  \    /  \
     [足1]   [足2]   [足3]   [足4]   [足5]   [足6]   [足7]   [足8]

ASHIGARU_EOF

    echo -e "                    \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # システム情報
    # ═══════════════════════════════════════════════════════════════════════════
    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-shogun\033[0m  〜 \033[1;36m戦国マルチエージェント統率システム\033[0m 〜          \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m将軍\033[0m: プロジェクト統括    \033[1;31m家老\033[0m: タスク管理    \033[1;34m足軽\033[0m: 実働部隊×8         \033[1;33m┃\033[0m"
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
    NUM_ASHIGARU=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "num_ashigaru:" | awk '{print $2}' || echo "3")
else
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

    # キューファイルリセット
    cat > ./queue/shogun_to_karo.yaml << 'EOF'
queue: []
EOF

    cat > ./queue/karo_to_ashigaru.yaml << 'EOF'
assignments:
  ashigaru1:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru2:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru3:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru4:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru5:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru6:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru7:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru8:
    task_id: null
    description: null
    target_path: null
    status: idle
EOF

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
    echo "  ║  まず first_setup.sh を実行してください:                  ║"
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
echo ""

# pane-base-index を取得（1 の環境ではペインは 1,2,... になる）
PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5.1: multiagent セッション作成（動的ペイン数）
# ═══════════════════════════════════════════════════════════════════════════════

# 最初のペイン作成
if ! tmux new-session -d -s multiagent -n "agents" 2>/dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] Failed to create tmux session 'multiagent'        ║"
    echo "  ║  tmux セッション 'multiagent' の作成に失敗しました              ║"
    echo "  ╠════════════════════════════════════════════════════════════╣"
    echo "  ║  An existing session may be running.                       ║"
    echo "  ║  既存セッションが残っている可能性があります                       ║"
    echo "  ║                                                            ║"
    echo "  ║  Check: tmux ls                                            ║"
    echo "  ║  Kill:  tmux kill-session -t multiagent                    ║"
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
    # 5ペイン以上: 3x3グリッド
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
    PANE_TITLES+=("karo(Opus)")
    MODEL_NAMES+=("Opus Thinking")
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
        MODEL_NAMES+=("Opus Thinking")
    else
        if [ $i -le 4 ]; then
            PANE_TITLES+=("ashigaru${i}(Sonnet)")
            MODEL_NAMES+=("Sonnet Thinking")
        else
            PANE_TITLES+=("ashigaru${i}(Opus)")
            MODEL_NAMES+=("Opus Thinking")
        fi
    fi
done

# 各ペインに設定を適用
for i in $(seq 0 $NUM_ASHIGARU); do
    p=$((PANE_BASE + i))
    tmux select-pane -t "multiagent:agents.${p}" -T "${PANE_TITLES[$i]}"
    tmux set-option -p -t "multiagent:agents.${p}" @agent_id "${AGENT_IDS[$i]}"
    tmux set-option -p -t "multiagent:agents.${p}" @model_name "${MODEL_NAMES[$i]}"
    PROMPT_STR=$(generate_prompt "${PANE_LABELS[$i]}" "${PANE_COLORS[$i]}" "$SHELL_SETTING")
    tmux send-keys -t "multiagent:agents.${p}" "cd \"$(pwd)\" && export PS1='${PROMPT_STR}' && clear" Enter
done

# pane-border-format でモデル名を常時表示（Claude Codeがペインタイトルを上書きしても消えない）
tmux set-option -t multiagent -w pane-border-status top
tmux set-option -t multiagent -w pane-border-format '#{pane_index} #{@agent_id} (#{?#{==:#{@model_name},},unknown,#{@model_name}})'

log_success "  └─ 家老・足軽の陣、構築完了"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: LLM CLI 起動（-s / --setup-only のときはスキップ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$SETUP_ONLY" = false ]; then

    log_info "バックエンド: $BACKEND"
    log_info "足軽数: $NUM_ASHIGARU"
    log_war "⚔️ 家老・足軽の陣を構築中（$((NUM_ASHIGARU + 1))名配備）..."

    # CLI コマンドの存在チェック
    if [ "$BACKEND" = "gemini" ]; then
        if ! command -v gemini &> /dev/null; then
            log_info "⚠️  gemini コマンドが見つかりません"
            echo "  first_setup.sh を再実行してください:"
            echo "    ./first_setup.sh"
            exit 1
        fi
        CLI_NAME="Gemini CLI"
    else
        if ! command -v claude &> /dev/null; then
            log_info "⚠️  claude コマンドが見つかりません"
            echo "  first_setup.sh を再実行してください:"
            echo "    ./first_setup.sh"
            exit 1
        fi
        CLI_NAME="Claude Code"
    fi

    log_war "👑 全軍に ${CLI_NAME} を召喚中..."

    # エージェント起動コマンド生成関数
    get_agent_cmd() {
        local role=$1  # shogun, karo, ashigaru_strong, ashigaru_fast
        
        if [ "$BACKEND" = "gemini" ]; then
            # Gemini CLI - settings.yamlからモデル名を読み込み
            case $role in
                shogun)
                    MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_shogun:" | awk '{print $2}' || echo "gemini-3-pro-preview")
                    echo "gemini --model $MODEL --yolo"
                    ;;
                karo)
                    MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_karo:" | awk '{print $2}' || echo "gemini-3-pro-preview")
                    echo "gemini --model $MODEL --yolo"
                    ;;
                ashigaru_strong)
                    MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_ashigaru_strong:" | awk '{print $2}' || echo "gemini-3-pro-preview")
                    echo "gemini --model $MODEL --yolo"
                    ;;
                ashigaru_fast)
                    MODEL=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "model_ashigaru_fast:" | awk '{print $2}' || echo "gemini-3-flash-preview")
                    echo "gemini --model $MODEL --yolo"
                    ;;
            esac
        else
            # Claude Code CLI
            case $role in
                shogun)
                    echo "MAX_THINKING_TOKENS=0 claude --model opus --dangerously-skip-permissions"
                    ;;
                karo)
                    echo "claude --model opus --dangerously-skip-permissions"
                    ;;
                ashigaru_strong)
                    echo "claude --model opus --dangerously-skip-permissions"
                    ;;
                ashigaru_fast)
                    echo "claude --model sonnet --dangerously-skip-permissions"
                    ;;
            esac
        fi
    }

    # 将軍
    SHOGUN_CMD=$(get_agent_cmd "shogun")
    tmux send-keys -t shogun:main "$SHOGUN_CMD"
    tmux send-keys -t shogun:main Enter
    log_info "  └─ 将軍、召喚完了"

    # 少し待機（安定のため）
    sleep 1

    # 家老（pane 0）
    p=$((PANE_BASE + 0))
    KARO_CMD=$(get_agent_cmd "karo")
    tmux send-keys -t "multiagent:agents.${p}" "$KARO_CMD"
    tmux send-keys -t "multiagent:agents.${p}" Enter
    log_info "  └─ 家老、召喚完了"

    if [ "$KESSEN_MODE" = true ]; then
        # 決戦の陣: 全足軽 強モデル
        for i in $(seq 1 $NUM_ASHIGARU); do
            p=$((PANE_BASE + i))
            ASHIGARU_CMD=$(get_agent_cmd "ashigaru_strong")
            tmux send-keys -t "multiagent:agents.${p}" "$ASHIGARU_CMD"
            tmux send-keys -t "multiagent:agents.${p}" Enter
        done
        log_info "  └─ 足軽1-${NUM_ASHIGARU}（強モデル）、決戦の陣で召喚完了"
    else
        # 平時の陣: モデル切り替え対応
        if [ "$BACKEND" = "gemini" ]; then
            STRONG_COUNT=$(grep -A20 "^gemini:" ./config/settings.yaml 2>/dev/null | grep "strong_ashigaru_count:" | awk '{print $2}' || echo "1")
            for i in $(seq 1 $NUM_ASHIGARU); do
                p=$((PANE_BASE + i))
                if [ $i -le $STRONG_COUNT ]; then
                    ASHIGARU_CMD=$(get_agent_cmd "ashigaru_strong")
                else
                    ASHIGARU_CMD=$(get_agent_cmd "ashigaru_fast")
                fi
                tmux send-keys -t "multiagent:agents.${p}" "$ASHIGARU_CMD"
                tmux send-keys -t "multiagent:agents.${p}" Enter
            done
            log_info "  └─ 足軽1-${STRONG_COUNT}（強モデル）、足軽$((STRONG_COUNT+1))-${NUM_ASHIGARU}（高速モデル）、召喚完了"
        else
            # Claude版: 従来通り全て同じモデル
            for i in $(seq 1 $NUM_ASHIGARU); do
                p=$((PANE_BASE + i))
                ASHIGARU_CMD=$(get_agent_cmd "ashigaru_strong")
                tmux send-keys -t "multiagent:agents.${p}" "$ASHIGARU_CMD"
                tmux send-keys -t "multiagent:agents.${p}" Enter
            done
            log_info "  └─ 足軽1-${NUM_ASHIGARU}、召喚完了"
        fi
    fi

    if [ "$KESSEN_MODE" = true ]; then
        log_success "✅ 決戦の陣で出陣！全軍強モデル！ (Backend: $BACKEND)"
    else
        log_success "✅ 平時の陣で出陣 (Backend: $BACKEND)"
    fi
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 6.5: 各エージェントに指示書を読み込ませる
    # ═══════════════════════════════════════════════════════════════════════════
    log_war "📜 各エージェントに指示書を読み込ませ中..."
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # 忍者戦士（syntax-samurai/ryu - CC0 1.0 Public Domain）
    # ═══════════════════════════════════════════════════════════════════════════
    echo -e "\033[1;35m  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐\033[0m"
    echo -e "\033[1;35m  │\033[0m                              \033[1;37m【 忍 者 戦 士 】\033[0m  Ryu Hayabusa (CC0 Public Domain)                        \033[1;35m│\033[0m"
    echo -e "\033[1;35m  └────────────────────────────────────────────────────────────────────────────────────────────────────────────┘\033[0m"

    cat << 'NINJA_EOF'
...................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                        ...................................
..................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                        ...................................
..................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                        ...................................
..................................░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                        ...................................
..................................░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                        ...................................
..................................░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░▒▒▒▒▒▒                         ...................................
..................................░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░▒▒▒▒▒▒▒                         ...................................
..................................░░░░░░░░░░░░░░░░▒▒▒▒          ▒▒▒▒▒▒▒▒░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒▒                             ...................................
..................................░░░░░░░░░░░░░░▒▒▒▒               ▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                                ...................................
..................................░░░░░░░░░░░░░▒▒▒                    ▒▒▒▒░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                                    ...................................
..................................░░░░░░░░░░░░▒                            ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                                        ...................................
..................................░░░░░░░░░░░      ░░░░░░░░░░░░░                                      ░░░░░░░░░░░░       ▒          ...................................
..................................░░░░░░░░░░ ▒    ░░░▓▓▓▓▓▓▓▓▓▓▓▓░░                                 ░░░░░░░░░░░░░░░ ░               ...................................
..................................░░░░░░░░░░     ░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░                          ░░░░░░░░░░░░░░░░░░░                ...................................
..................................░░░░░░░░░ ▒  ░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░             ░░▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░  ░   ▒         ...................................
..................................░░░░░░░░ ░  ░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░ ░  ▒         ...................................
..................................░░░░░░░░ ░  ░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░  ░    ▒        ...................................
..................................░░░░░░░░░▒  ░ ░               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓░                 ░            ...................................
.................................░░░░░░░░░░   ░░░  ░                 ▓▓▓▓▓▓▓▓░▓▓▓▓░░░▓░░░░░░▓▓▓▓▓                    ░ ░   ▒         ..................................
.................................░░░░░░░░▒▒   ░░░░░ ░                  ▓▓▓▓▓▓░▓▓▓▓░░▓▓▓░░░░░░▓▓                    ░  ░ ░  ▒         ..................................
.................................░░░░░░░░▒    ░░░░░░░░░ ░                 ░▓░░▓▓▓▓▓░▓▓▓░░░░░                   ░ ░░ ░░ ░   ▒         ..................................
.................................░░░░░░░▒▒    ░░░░░░░   ░░                    ▓▓▓▓▓▓▓▓▓░░                   ░░    ░ ░░ ░    ▒        ..................................
.................................░░░░░░░▒▒    ░░░░░░░░░░                      ░▓▓▓▓▓▓▓░░░                     ░░░  ░  ░ ░   ▒        ..................................
.................................░░░░░░░ ▒    ░░░░░░                         ░░░▓▓▓░▓░░░░      ░                  ░ ░░ ░    ▒        ..................................
.................................░░░░░░░ ▒    ░░░░░░░     ▓▓        ▓  ░░ ░░░░░░░░░░░░░  ░   ░░  ▓        █▓       ░  ░ ░   ▒▒       ..................................
..................................░░░░░▒ ▒    ░░░░░░░░  ▓▓██  ▓  ██ ██▓  ▓ ░░░▓░  ░ ░ ░░░░  ▓   ██ ▓█  ▓  ██▓▓  ░░░░  ░ ░    ▒      ...................................
..................................░░░░░▒ ▒▒   ░░░░░░░░░  ▓██  ▓▓  ▓ ██▓  ▓░░░░▓▓░  ░░░░░░░░ ▓  ▓██ ▓   ▓  ██▓▓ ░░░░░░░ ░     ▒      ...................................
..................................░░░░░  ▒░   ░░░░░░░▓░░ ▓███  ▓▓▓▓ ███░  ░░░░▓▓░░░░░░░░░░    ░▓██  ▓▓▓  ███▓ ░░▓▓░░  ░    ▒ ▒      ...................................
...................................░░░░  ▒░    ░░░░▓▓▓▓▓▓░  ███    ██      ░░░░░▓▓▓▓▓░░░░░░░     ███   ████ ░░▓▓▓▓░░  ░    ▒ ▒      ...................................
...................................░░░░ ▒ ░▒    ░░▓▓▓▓▓▓▓▓▓▓ ██████  ▓▓▓░░ ░░░░▓▓▓▓▓▓░░░░░░░░░▓▓▓   █████  ▓▓▓▓▓▓▓░░░░    ▒▒ ▒      ...................................
...................................░░░░ ░ ░░     ░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓█░░░░░░░▓▓▓▓▓▓▓░░░░ ░░   ░░▓░▓▓░░░░░░░▓▓▓▓▓▓░░      ▒▒ ▒      ...................................
...................................░░░░ ░ ░░      ░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓██  ░░░░░░░▓▓▓▓▓▓▓░░░░  ░░░░░   ░░░░░░░░░▓▓▓▓▓░░ ░    ▒▒  ▒      ...................................
...................................░░░░▒░░▒░░      ░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░▓▓▓▓▓▓▓▓░░░  ░░░░░░░░░░░░░░░░░░▓▓░░░░      ▒▒  ▒     ....................................
...................................░░░░▒░░ ░░       ░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░▓▓▓▓▓▓▓▓▓░░░░  ░░░░░░░░░░░░░░░░░░░░░        ▒▒  ▒     ....................................
...................................░░░░░░░ ▒░▒       ░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░▓▓▓░░   ░░░░░  ░░░░░░░░░░░░░░░░░░░░         ▒   ▒     ....................................
...................................░░░░░░░░░░░           ░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓              ░    ░░░░░░░░░░░░░░░            ▒   ▒     ....................................
....................................░░░░░░░░░░░▒  ▒▒        ▓▓▓▓▓▓▓▓▓▓▓▓▓  ░░░░░░░░░░▒▒                         ▒▒▒▒▒   ▒    ▒    .....................................
....................................░░░░░░░░░░ ░▒ ▒▒▒░░░        ▓▓▓▓▓▓   ░░░░░░░░░░░░░▒▒▒      ▒▒▒▒▒░░░░▒▒    ▒▒▒▒▒▒▒  ▒▒    ▒    .....................................
....................................░░░░░░░░░░ ░░░ ▒▒▒░░░░░░          ░░░░░ ░░░░░░░░░░▒░▒     ▒▒▒▒▒▒░░░░░░▒▒▒▒▒░▒▒▒▒   ▒▒         .....................................
.....................................░░░░░░░░░░ ░░░░░  ▒▒░░░░░░░░░░░░░    ░░░░░░░░░  ▒░▒▒    ▒▒▒▒▒░░░░▒▒▒▒▒▒░░▒▒▒   ▒▒▒         ......................................
.....................................░░░░░░░░░░░░░░░░░░  ▒░░░░░░░░░░░   ░░░░░░░░░░░░░░   ▒   ▒▒▒▒▒▒▒░▒▒▒▒▒▒░░░░▒▒▒   ▒▒          ......................................
.....................................░░░░░░░░░░░ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░      ▒▒▒▒▒▒▒    ▒  ░░░▒▒▒▒  ▒▒▒          ......................................
......................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ▒░▒▒▒ ▒▒▒    ▒░░░░░░░░░░▒   ▒▒▒▒      ▒   .......................................
......................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒  ░░▒▒▒▒▒▒░░░░░░░░░░░░░▒  ░▒▒▒▒       ▒   .......................................
......................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒ ▒▒░▒▒▒▒▒▒▒░░░░░░░░░░  ░░▒▒▒▒▒       ▒   .......................................
......................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒ ░▒▒▒▒▒▒▒▒▒░░▒░░░░░░ ░░▒▒▒▒▒▒      ▒    .......................................
.......................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒░░▒░▒▒▒ ▒▒▒▒▒░░░░░░░░░▒▒▒▒▒        ▒    .......................................
.......................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒░▒▒▒▒▒     ░░░░░░░░▒▒▒▒▒▒        ▒    .......................................
.......................................░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒░░▒░▒▒▒▒▒▒  ▒░░░░░░░▒▒▒▒▒▒        ▒     .......................................
NINJA_EOF

    echo ""
    echo -e "                                    \033[1;35m「 天下布武！勝利を掴め！ 」\033[0m"
    echo ""
    echo -e "                               \033[0;36m[ASCII Art: syntax-samurai/ryu - CC0 1.0 Public Domain]\033[0m"
    echo ""

    echo "  ${CLI_NAME} の起動を待機中（最大30秒）..."

    # 将軍の起動を確認（最大30秒待機）
    for i in {1..30}; do
        if [ "$BACKEND" = "gemini" ]; then
            # Gemini CLIの起動確認（プロンプトが表示されているか）
            if tmux capture-pane -t shogun:main -p | grep -qE "(gemini|>|❯)"; then
                echo "  └─ 将軍の ${CLI_NAME} 起動確認完了（${i}秒）"
                break
            fi
        else
            # Claude Code CLIの起動確認
            if tmux capture-pane -t shogun:main -p | grep -q "bypass permissions"; then
                echo "  └─ 将軍の ${CLI_NAME} 起動確認完了（${i}秒）"
                break
            fi
        fi
        sleep 1
    done

    # 将軍に指示書を読み込ませる（委譲ルールを強調）
    log_info "  └─ 将軍に指示書を伝達中..."
    tmux send-keys -t shogun:main "汝は将軍なり。instructions/shogun.md を読め。【絶対禁止】自分でタスクを実行するな（F001違反）。全ての作業は queue/shogun_to_karo.yaml に書いて家老（multiagent:agents.0）に委譲せよ。"
    sleep 0.5
    tmux send-keys -t shogun:main Enter

    # 家老に指示書を読み込ませる（タスク分配ルールと足軽数を伝達）
    sleep 2
    log_info "  └─ 家老に指示書を伝達中..."
    if [ "$BACKEND" = "gemini" ]; then
        tmux send-keys -t "multiagent:agents.${PANE_BASE}" "汝は家老なり。instructions/karo_gemini.md を読め。足軽は${NUM_ASHIGARU}体である。将軍からの指示は queue/shogun_to_karo.yaml で受け取り、タスクを足軽用YAMLファイルに分配せよ。"
    else
        tmux send-keys -t "multiagent:agents.${PANE_BASE}" "汝は家老なり。instructions/karo.md を読め。足軽は${NUM_ASHIGARU}体である。将軍からの指示は queue/shogun_to_karo.yaml で受け取り、タスクを足軽用YAMLファイルに分配せよ。"
    fi
    sleep 0.5
    tmux send-keys -t "multiagent:agents.${PANE_BASE}" Enter

    # 足軽に指示書を読み込ませる
    sleep 2
    log_info "  └─ 足軽に指示書を伝達中..."
    for i in $(seq 1 $NUM_ASHIGARU); do
        p=$((PANE_BASE + i))
        tmux send-keys -t "multiagent:agents.${p}" "汝は足軽${i}号なり。instructions/ashigaru.md を読め。queue/tasks/ashigaru${i}.yaml からタスクを受け取り、完了後は queue/reports/ashigaru${i}_report.yaml に報告せよ。"
        sleep 0.3
        tmux send-keys -t "multiagent:agents.${p}" Enter
        sleep 0.5
    done

    log_success "✅ 全軍に指示書伝達完了"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: 環境確認・完了メッセージ
# ═══════════════════════════════════════════════════════════════════════════════
log_info "🔍 陣容を確認中..."
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📺 Tmux陣容 (Sessions)                                  │"
echo "  └──────────────────────────────────────────────────────────┘"
tmux list-sessions | sed 's/^/     /'
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📋 布陣図 (Formation)                                   │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "     【shogunセッション】将軍の本陣"
echo "     ┌─────────────────────────────┐"
echo "     │  Pane 0: 将軍 (SHOGUN)      │  ← 総大将・プロジェクト統括"
echo "     └─────────────────────────────┘"
echo ""
if [ "$BACKEND" = "gemini" ]; then
    echo "     【multiagentセッション】家老・足軽の陣（2x2 = 4ペイン）"
    echo "     ┌─────────┬─────────┐"
    echo "     │  karo   │ashigaru2│"
    echo "     │  (家老) │ (足軽2) │"
    echo "     ├─────────┼─────────┤"
    echo "     │ashigaru1│ashigaru3│"
    echo "     │ (足軽1) │ (足軽3) │"
    echo "     └─────────┴─────────┘"
else
    echo "     【multiagentセッション】家老・足軽の陣（3x3 = 9ペイン）"
    echo "     ┌─────────┬─────────┬─────────┐"
    echo "     │  karo   │ashigaru3│ashigaru6│"
    echo "     │  (家老) │ (足軽3) │ (足軽6) │"
    echo "     ├─────────┼─────────┼─────────┤"
    echo "     │ashigaru1│ashigaru4│ashigaru7│"
    echo "     │ (足軽1) │ (足軽4) │ (足軽7) │"
    echo "     ├─────────┼─────────┼─────────┤"
    echo "     │ashigaru2│ashigaru5│ashigaru8│"
    echo "     │ (足軽2) │ (足軽5) │ (足軽8) │"
    echo "     └─────────┴─────────┴─────────┘"
fi
echo ""

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 出陣準備完了！天下布武！                             ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

if [ "$SETUP_ONLY" = true ]; then
    # バックエンド設定を読み込み（セットアップモード用）
    BACKEND_MSG="claude"
    CLI_CMD="claude --dangerously-skip-permissions"
    if [ -f "./config/settings.yaml" ]; then
        BACKEND_MSG=$(grep "^backend:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "claude")
    fi
    if [ "$BACKEND_MSG" = "gemini" ]; then
        CLI_CMD="gemini --model gemini-3-flash-preview --yolo"
        CLI_DISPLAY="Gemini CLI"
    else
        CLI_DISPLAY="Claude Code"
    fi
    
    echo "  ⚠️  セットアップのみモード: ${CLI_DISPLAY}は未起動です"
    echo ""
    echo "  手動で${CLI_DISPLAY}を起動するには:"
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  # 将軍を召喚                                              │"
    echo "  │  tmux send-keys -t shogun:main \\                         │"
    echo "  │    '${CLI_CMD}' Enter                                    │"
    echo "  │                                                          │"
    echo "  │  # 家老・足軽を一斉召喚                                     │"
    echo "  │  for p in \$(seq $PANE_BASE $((PANE_BASE+8))); do        │"
    echo "  │      tmux send-keys -t multiagent:agents.\$p \\          │"
    echo "  │      '${CLI_CMD}' Enter                                  │"
    echo "  │  done                                                    │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
fi

echo "  次のステップ:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  将軍の本陣にアタッチして命令を開始:                     │"
echo "  │     tmux attach-session -t shogun   (または: css)        │"
echo "  │                                                          │"
echo "  │  家老・足軽の陣を確認する:                               │"
echo "  │     tmux attach-session -t multiagent   (または: csm)    │"
echo "  │                                                          │"
echo "  │  ※ 各エージェントは指示書を読み込み済み。                │"
echo "  │    すぐに命令を開始できます。                            │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   天下布武！勝利を掴め！ (Tenka Fubu! Seize victory!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: Windows Terminal でタブを開く（-t オプション時のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$OPEN_TERMINAL" = true ]; then
    log_info "📺 Windows Terminal でタブを展開中..."

    # Windows Terminal が利用可能か確認
    if command -v wt.exe &> /dev/null; then
        wt.exe -w 0 new-tab wsl.exe -e bash -c "tmux attach-session -t shogun" \; new-tab wsl.exe -e bash -c "tmux attach-session -t multiagent"
        log_success "  └─ ターミナルタブ展開完了"
    else
        log_info "  └─ wt.exe が見つかりません。手動でアタッチしてください。"
    fi
    echo ""
fi
