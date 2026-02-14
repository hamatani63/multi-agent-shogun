<div align="center">

# multi-agent-shogun

**Command your AI army like a feudal warlord.**

Run 3-10 AI coding agents in parallel — **Gemini CLI, Claude Code, OpenAI Codex, GitHub Copilot, Kimi Code** — orchestrated through a samurai-inspired hierarchy with zero coordination overhead.

**Talk Coding, not Vibe Coding. Speak to your phone, AI executes.**

[![GitHub Stars](https://img.shields.io/github/stars/yohey-w/multi-agent-shogun?style=social)](https://github.com/yohey-w/multi-agent-shogun)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![v3.0 Multi-CLI](https://img.shields.io/badge/v3.0-Multi--CLI_Support-ff6600?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNiIgaGVpZ2h0PSIxNiI+PHRleHQgeD0iMCIgeT0iMTIiIGZvbnQtc2l6ZT0iMTIiPuKalTwvdGV4dD48L3N2Zz4=)](https://github.com/yohey-w/multi-agent-shogun)
[![Gemini CLI](https://img.shields.io/badge/Supports-Gemini_CLI-blue)](https://github.com/google-gemini/gemini-cli)
[![Shell](https://img.shields.io/badge/Shell%2FBash-100%25-green)]()

[English](README.md) | [日本語](README_ja.md)

</div>

<p align="center">
  <img src="images/screenshots/hero/latest-translucent-20260210-190453.png" alt="Latest translucent command session in the Shogun pane" width="940">
</p>

<p align="center">
  <img src="images/screenshots/hero/latest-translucent-20260208-084602.png" alt="Quick natural-language command in the Shogun pane" width="420">
  <img src="images/company-creed-all-panes.png" alt="Karo and Ashigaru panes reacting in parallel" width="520">
</p>

<p align="center"><i>One Karo (manager) coordinating 3-8 Ashigaru (workers) — real session, no mock data.</i></p>

---

## What is this?

**multi-agent-shogun** is a system that runs multiple AI coding CLI instances simultaneously, orchestrating them like a feudal Japanese army. Supports **Gemini CLI**, **Claude Code**, **OpenAI Codex**, **GitHub Copilot**, and **Kimi Code**.

**Why use it?**
- One command spawns 3-8 AI workers executing in parallel
- Zero wait time — give your next order while tasks run in the background
- AI remembers your preferences across sessions (Memory MCP)
- Real-time progress on a dashboard

```
        You (上様 / The Lord)
             │
             ▼  Give orders
      ┌─────────────┐
      │   SHOGUN    │  ← Receives your command, delegates instantly
      └──────┬──────┘
             │  YAML + tmux
      ┌──────▼──────┐
      │    KARO     │  ← Distributes tasks to workers
      └──────┬──────┘
             │
    ┌─┬─┬─┬─┴─┬─┬─┬─┐
    │1│2│3│4│5│6│7│8│  ← 3-8 workers execute in parallel
    └─┴─┴─┴─┴─┴─┴─┴─┘
         ASHIGARU
```

---

## Why Shogun?

Most multi-agent frameworks burn API tokens on coordination. Shogun doesn't.

| | Claude Code `Task` tool | LangGraph | CrewAI | **multi-agent-shogun** |
|---|---|---|---|---|
| **Architecture** | Subagents inside one process | Graph-based state machine | Role-based agents | Feudal hierarchy via tmux |
| **Parallelism** | Sequential (one at a time) | Parallel nodes (v0.2+) | Limited | **3-8 independent agents** |
| **Coordination cost** | API calls per Task | API + infra (Postgres/Redis) | API + CrewAI platform | **Zero** (YAML + tmux) |
| **Observability** | Claude logs only | LangSmith integration | OpenTelemetry | **Live tmux panes** + dashboard |
| **Skill discovery** | None | None | None | **Bottom-up auto-proposal** |
| **Setup** | Built into Claude Code | Heavy (infra required) | pip install | Shell scripts |

### What makes this different

**Zero coordination overhead** — Agents talk through YAML files on disk. The only API calls are for actual work, not orchestration. Run 8 agents and pay only for 8 agents' work.

**Full transparency** — Every agent runs in a visible tmux pane. Every instruction, report, and decision is a plain YAML file you can read, diff, and version-control. No black boxes.

**Battle-tested hierarchy** — The Shogun → Karo → Ashigaru chain of command prevents conflicts by design: clear ownership, dedicated files per agent, event-driven communication, no polling.

---

## Why CLI (Not API)?

Most AI coding tools charge per token. Running 8 Opus-grade agents through the API costs **$100+/hour**. CLI subscriptions flip this:

| | API (Per-Token) | CLI (Flat-Rate) |
|---|---|---|
| **8 agents × Opus** | ~$100+/hour | ~$200/month |
| **Cost predictability** | Unpredictable spikes | Fixed monthly bill |
| **Usage anxiety** | Every token counts | Unlimited |
| **Experimentation budget** | Constrained | Deploy freely |

**"Use AI recklessly"** — With flat-rate CLI subscriptions, deploy 8 agents without hesitation. The cost is the same whether they work 1 hour or 24 hours. No more choosing between "good enough" and "thorough" — just run more agents.

### Multi-CLI Support

Shogun isn't locked to one vendor. The system supports 5 CLI tools, each with unique strengths:

| CLI | Key Strength | Default Model |
|-----|-------------|---------------|
| **Gemini CLI** | **Rate limit friendly**, Free tier available (1k req/day), **1M token context** | Gemini 1.5 Pro / Flash |
| **Claude Code** | Battle-tested tmux integration, Memory MCP, dedicated file tools (Read/Write/Edit/Glob/Grep) | Claude Sonnet 4.5 |
| **OpenAI Codex** | Sandbox execution, JSONL structured output, `codex exec` headless mode, **per-model `--model` flag** | gpt-5.3-codex / **gpt-5.3-codex-spark** |
| **GitHub Copilot** | Built-in GitHub MCP, 4 specialized agents (Explore/Task/Plan/Code-review), `/delegate` to coding agent | Claude Sonnet 4.5 |
| **Kimi Code** | Free tier available, strong multilingual support | Kimi k2 |

A unified instruction build system generates CLI-specific instruction files from shared templates:

```
instructions/
├── common/              # Shared rules (all CLIs)
├── cli_specific/        # CLI-specific tool descriptions
│   ├── claude_tools.md  # Claude Code tools & features
│   └── copilot_tools.md # GitHub Copilot CLI tools & features
└── roles/               # Role definitions (shogun, karo, ashigaru)
    ↓ build
CLAUDE.md / AGENTS.md / copilot-instructions.md  ← Generated per CLI
```

One source of truth, zero sync drift. Change a rule once, all CLIs get it.

---

## Bottom-Up Skill Discovery

This is the feature no other framework has.

As Ashigaru execute tasks, they **automatically identify reusable patterns** and propose them as skill candidates. The Karo aggregates these proposals in `dashboard.md`, and you — the Lord — decide what gets promoted to a permanent skill.

```
Ashigaru finishes a task
    ↓
Notices: "I've done this pattern 3 times across different projects"
    ↓
Reports in YAML:  skill_candidate:
                     found: true
                     name: "api-endpoint-scaffold"
                     reason: "Same REST scaffold pattern used in 3 projects"
    ↓
Appears in dashboard.md → You approve → Skill created in .claude/commands/
    ↓
Any agent can now invoke /api-endpoint-scaffold
```

Skills grow organically from real work — not from a predefined template library. Your skill set becomes a reflection of **your** workflow.

---

## Quick Start

### Windows (WSL2)

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **Download the repository**

[Download ZIP](https://github.com/yohey-w/multi-agent-shogun/archive/refs/heads/main.zip) and extract to `C:\tools\multi-agent-shogun`

*Or use git:* `git clone https://github.com/yohey-w/multi-agent-shogun.git C:\tools\multi-agent-shogun`

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **Run `install.bat`**

Right-click → "Run as Administrator" (if WSL2 is not installed). Sets up WSL2 + Ubuntu automatically.

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

🐧 **Open Ubuntu and run** (first time only)

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

✅ **Deploy!**

```bash
./shutsujin_departure.sh
```

</td>
</tr>
</table>

#### First-time only: Authentication

After `first_setup.sh`, run these commands once to authenticate:

```bash
# 1. Apply PATH changes
source ~/.bashrc

# 2. Authenticate (Command depends on your CLI backend)
claude --dangerously-skip-permissions  # For Claude
gemini login                           # For Gemini
```

### Linux / macOS

```bash
# 1. Clone
git clone https://github.com/yohey-w/multi-agent-shogun.git ~/multi-agent-shogun
cd ~/multi-agent-shogun && chmod +x *.sh

# 2. Setup + Deploy
./first_setup.sh          # One-time: installs dependencies
./shutsujin_departure.sh  # Deploy your army
```

### Daily startup

```bash
cd /path/to/multi-agent-shogun
./shutsujin_departure.sh           # Normal startup (resumes existing tasks)
./shutsujin_departure.sh -c        # Clean startup (resets task queues, preserves command history)
tmux attach-session -t shogun      # Connect and give orders
```

**Startup options:**
- **Default**: Resumes with existing task queues and command history intact
- **`-c` / `--clean`**: Resets task queues for a fresh start while preserving command history in `queue/shogun_to_karo.yaml`. Previously assigned tasks are backed up before reset.

<details>
<summary><b>Convenient aliases</b> (added by first_setup.sh)</summary>

```bash
alias csst='cd /mnt/c/tools/multi-agent-shogun && ./shutsujin_departure.sh'
alias css='tmux attach-session -t shogun'
alias csm='tmux attach-session -t multiagent'
```

</details>

### 📱 Mobile Access (Command from anywhere)

Control your AI army from your phone — bed, café, or bathroom.

**Requirements:**
- [Tailscale](https://tailscale.com/) (free) — creates a secure tunnel to your WSL
- [Termux](https://termux.dev/) (free) — terminal app for Android
- SSH — already installed

**Setup:**

1. Install Tailscale on both WSL and your phone
2. In WSL (auth key method — browser not needed):
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscaled &
   sudo tailscale up --authkey tskey-auth-XXXXXXXXXXXX
   sudo service ssh start
   ```
3. In Termux on your phone:
   ```sh
   pkg update && pkg install openssh
   ssh youruser@your-tailscale-ip
   css    # Connect to Shogun
   ```
4. Open a new Termux window (+ button) for workers:
   ```sh
   ssh youruser@your-tailscale-ip
   csm    # See all 9 panes
   ```

**Disconnect:** Just swipe the Termux window closed. tmux sessions survive — agents keep working.

**Voice input:** Use your phone's voice keyboard to speak commands. The Shogun understands natural language, so typos from speech-to-text don't matter.

---

## Configuration

### Language

```yaml
# config/settings.yaml
language: ja   # Samurai Japanese only
language: en   # Samurai Japanese + English translation
```

### Backend Switching

```yaml
# config/settings.yaml

# Claude backend (default)
# backend: claude

# Gemini backend
backend: gemini
```

### 🧠 Gemini Configuration

The Gemini CLI configuration is designed for **rate limit efficiency** and **response speed**.

```yaml
gemini:
  model_shogun: gemini-3-flash-preview
  model_karo: gemini-3-pro-preview
  model_ashigaru_strong: gemini-3-pro-preview
  model_ashigaru_fast: gemini-3-flash-preview
  num_ashigaru: 3  # Reduced from 8 to avoid rate limits
  auth_method: oauth
```

| Agent | Model | Role | Reason |
|-------|-------|------|--------|
| **Shogun** | Flash | Commander | High speed & context handling (1M tokens) |
| **Karo** | **Pro** | Manager | Critical task allocation & management |
| **Ashigaru 1** | **Pro** | Main Force | Complex reasoning & coding (Strong Model) |
| **Ashigaru 2-3** | Flash | Support | Fast research & simple tasks (Fast Model) |

#### Formation Modes (Gemini)

| Mode | Ashigaru 1 | Ashigaru 2-3 | Command |
|------|------------|--------------|---------|
| **Normal** (Default) | **Pro** | Flash | `./shutsujin_departure.sh` |
| **Kessen** (Battle) | **Pro** | **Pro** | `./shutsujin_departure.sh -k` |

### 🧠 Claude Configuration

| Agent | Default Model | Thinking |
|-------|--------------|----------|
| Shogun | Opus | Disabled |
| Karo | Opus | Enabled |
| Ashigaru 1–4 | Sonnet | Enabled |
| Ashigaru 5–8 | Opus | Enabled |

#### Formation Modes (Claude)

- **Normal**: Half Sonnet, Half Opus
- **Kessen**: All Opus (`-k` option)

---

## MCP servers (Setup Guide)

#### Gemini CLI

For Gemini CLI, edit `~/.gemini/settings.json` directly to add MCP servers.

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
# Memory (auto-configured by first_setup.sh)
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/shogun_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory

# Notion
claude mcp add notion -e NOTION_TOKEN=your_token -- npx -y @notionhq/notion-mcp-server

# GitHub
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat -- npx -y @modelcontextprotocol/server-github

# Playwright (browser automation)
claude mcp add playwright -- npx @playwright/mcp@latest
```

---

## Advanced

<details>
<summary><b>Script Architecture</b></summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                      First-time Setup (Run once)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  install.bat (Windows)                                              │
│      │                                                              │
│      ├── Check/Install WSL2                                         │
│      └── Check/Install Ubuntu                                       │
│                                                                     │
│  first_setup.sh (Ubuntu/WSL Manual Run)                             │
│      │                                                              │
│      ├── Check/Install tmux                                         │
│      ├── Check/Install Node.js v20+ (via nvm)                       │
│      ├── Check/Install Claude Code CLI                              │
│      └── Configure Memory MCP Server                                │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                      Daily Startup (Run daily)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  shutsujin_departure.sh                                             │
│      │                                                              │
│      ├──▶ Create tmux sessions                                      │
│      │         • "shogun" (1 pane)                                  │
│      │         • "multiagent" (4-9 panes)                           │
│      │                                                              │
│      ├──▶ Reset queue files and dashboard                           │
│      │                                                              │
│      └──▶ Launch Claude/Gemini in all agents                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

</details>

<details>
<summary><b>Technical Details</b></summary>

- **Agent self-identification** (`@agent_id`) — Stable identity via tmux user options, immune to pane reordering
- **Battle mode** (`-k` flag) — All-Opus/Pro formation for maximum capability
- **Task dependency system** (`blockedBy`) — Automatic unblocking of dependent tasks

</details>

---

## Contributing

Issues and pull requests are welcome.

- **Bug reports**: Open an issue with reproduction steps
- **Feature ideas**: Open a discussion first
- **Skills**: Skills are personal by design and not included in this repo

## Credits

Based on [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa.

## License

[MIT](LICENSE)

---

<div align="center">

**One command. Eight agents. Zero coordination cost.**

⭐ Star this repo if you find it useful — it helps others discover it.

</div>
