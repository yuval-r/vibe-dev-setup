# 🚀 Vibe Coding Dev Setup — HP Dev One + Mac Studio

One-command setup script to transform your HP Dev One (Pop!_OS / Ubuntu) and Mac Studio into an AI-powered vibe coding setup with seamless remote access between them.

## Quick Start

### One-Line Install (works on both machines)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yuval-r/vibe-dev-setup/master/install.sh)
```

It auto-detects your OS — runs `devone-setup.sh` on Linux, `mac-setup.sh` on macOS.

Preview first without installing:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yuval-r/vibe-dev-setup/master/install.sh) --dry-run
```

### Or clone and run manually

**On your HP Dev One (Pop!_OS):**
```bash
git clone https://github.com/yuval-r/vibe-dev-setup.git
cd vibe-dev-setup
chmod +x devone-setup.sh
./devone-setup.sh
```

**On your Mac Studio:**
```bash
git clone https://github.com/yuval-r/vibe-dev-setup.git
cd vibe-dev-setup
chmod +x mac-setup.sh
./mac-setup.sh
```

See [MAC-SETUP.md](MAC-SETUP.md) for full Mac documentation including Ollama remote access.

## Options

**Linux (`devone-setup.sh`):**

| Flag | What it does |
|------|-------------|
| `--dry-run` | Preview everything without installing |
| `--minimal` | AI tools + languages only (skip tuning, remote, CLI extras) |
| `--skip-git` | Skip git name/email prompt |
| `--skip-remote` | Skip all remote access tools |
| `--skip-gui-remote` | Keep Tailscale+SSH but skip NoMachine |
| `--help` | Show help |

**Mac (`mac-setup.sh`):**

| Flag | What it does |
|------|-------------|
| `--dry-run` | Preview without installing |
| `--skip-remote` | Skip remote access tools |
| `--skip-ai` | Skip AI CLI tools (Claude Code, Gemini CLI) |
| `--help` | Show help |

## What Gets Installed

### 🤖 AI & Vibe Coding Tools

| Tool | What it does | First run |
|------|-------------|-----------|
| **Claude Code** | Anthropic's AI coding agent in terminal | `claude` → authenticate with Anthropic account |
| **Gemini CLI** | Google's AI coding agent in terminal | `gemini` → authenticate with Google account |
| **Ollama** | Run AI models locally (no cloud needed) | `ollama pull qwen2.5-coder:32b` (64GB RAM handles large models) |
| **Google Antigravity** | Agent-first AI IDE (VS Code fork by Google) | Launch from app menu → sign in with Google |
| **Warp Terminal** | Modern AI-powered terminal | Launch from app menu |
| **Wave Terminal** | Open-source modern terminal with AI | Launch from app menu |

### 🛠 Languages & Dev Tools

| Tool | What it does | Usage |
|------|-------------|-------|
| **Node.js 22 LTS** | JavaScript runtime (needed by Claude Code & Gemini CLI) | `node -v` |
| **Python 3.12** | Installed via pyenv for version management | `python --version`, `pyenv install 3.13` for other versions |
| **Rust** | Installed via rustup | `rustc --version`, `cargo new my-project` |
| **Docker + Compose** | Containerization | `docker run hello-world` (log out & back in first) |
| **VS Code** | Code editor | `code .` to open current folder |
| **uv** | Fast Python package manager & project tool | `uv pip install`, `uv run` |
| **pipx** | Install Python CLI tools in isolated envs | `pipx install black` |

### ⌨ CLI Power Tools

| Tool | What it does | Usage |
|------|-------------|-------|
| **bat** | `cat` with syntax highlighting & line numbers | `bat README.md` |
| **ripgrep (rg)** | Blazing fast recursive text search | `rg "TODO" --type py` |
| **fd** | Fast & user-friendly `find` replacement | `fd "\.py$"` to find all Python files |
| **fzf** | Fuzzy finder — search anything interactively | `Ctrl+R` for command history, `Ctrl+T` for files |
| **direnv** | Auto-load `.envrc` env vars per project directory | Create `.envrc` in project, run `direnv allow` |
| **gh** | GitHub CLI — PRs, issues, repos from terminal | `gh auth login`, then `gh pr create` |
| **lazygit** | Beautiful terminal UI for git | `lazygit` inside any git repo |
| **lazydocker** | Terminal UI for Docker containers & images | `lazydocker` |

### 🌐 Remote Access (Linux ↔ Mac)

This setup installs three layers of remote access so you can connect from your HP Dev One to your Mac Studio (or any other machine) from anywhere.

| Tool | Type | What it does | Setup |
|------|------|-------------|-------|
| **Tailscale** | VPN / Network layer | Creates encrypted mesh network between your devices. No port forwarding needed. | Install on both machines, run `sudo tailscale up` on each |
| **SSH** | Terminal access | Secure command-line access to your Mac | Edit `~/.ssh/config` with your Mac's Tailscale IP |
| **NoMachine** | GUI remote desktop | Fastest remote desktop (NX protocol) | Install on both machines, connect via Tailscale IP |

#### How to connect to your Mac from Pop!_OS:

**Step 1: Set up Tailscale (do this on BOTH machines)**
```bash
# On Pop!_OS (already installed by script):
sudo tailscale up

# On Mac:
# Install from https://tailscale.com/download/mac
# Or: brew install --cask tailscale
# Open Tailscale, sign in with same account
```

**Step 2: Get your Mac's Tailscale IP**
```bash
# On your Mac:
tailscale ip -4
# Returns something like 100.64.x.x
```

**Step 3a: SSH access (terminal)**
```bash
# Edit SSH config on Pop!_OS:
nano ~/.ssh/config

# Uncomment and fill in the Mac section:
# Host mac
#     HostName 100.64.x.x    ← your Mac's Tailscale IP
#     User yourmacusername
#     ForwardAgent yes

# Then connect:
ssh mac
```

> **Mac prerequisite:** Enable Remote Login in System Settings → General → Sharing → Remote Login

**Step 3b: GUI access (NoMachine)**

Install NoMachine on Mac from [nomachine.com](https://nomachine.com) (or via `mac-setup.sh`). On Pop!_OS, open NoMachine, add your Mac's Tailscale IP (100.64.x.x).

#### When to use what:

| Scenario | Best tool |
|----------|-----------|
| Run a command on Mac, access files | SSH (`ssh mac`) |
| GUI access to Mac desktop | NoMachine (fastest remote desktop) |
| File transfer | `scp`, `rsync` over Tailscale |

### 🔒 System Security

| Tool | What it does | Usage |
|------|-------------|-------|
| **UFW Firewall** | Block incoming connections by default, allow SSH + remote tools | `sudo ufw status` to check |
| **SSH Key (Ed25519)** | Secure key-based authentication | `cat ~/.ssh/id_ed25519.pub` → add to GitHub |
| **Timeshift** | System snapshots — roll back if something breaks | `sudo timeshift --create` for manual snapshot |

### ⚡ Power & Performance

| Setting | What it does | Details |
|---------|-------------|---------|
| **TLP** | Advanced power management for AMD laptops | Auto-starts on boot, saves significant battery |
| **inotify watchers** | Increased to 524288 (default 8192) | Prevents "too many files" errors in VS Code/Antigravity |
| **Swappiness** | Reduced to 1 (default 60) | With 64GB RAM, almost never need swap |
| **tmpfs /tmp** | /tmp mounted in RAM (16GB) | Faster builds, compilation, temp files |
| **File descriptors** | Increased to 65536 per user | Prevents Docker & Node.js hitting limits |
| **Bluetooth** | Auto-start disabled | Saves battery; turn on manually when needed |
| **Firmware updates** | Checks via fwupd | Important for HP Dev One BIOS updates |

### 🪟 Productivity

| Tool | What it does | Usage |
|------|-------------|-------|
| **Zsh + Oh-My-Zsh** | Better shell with plugins | Auto-suggestions as you type, syntax highlighting |
| **GNOME Tweaks** | Fine-tune fonts, themes, window behavior | Open from app menu |
| **Flameshot** | Advanced screenshot tool | `flameshot gui` or set a keyboard shortcut |
| **Slack** | Team communication | Launch from app menu |
| **Telegram** | Messaging | Launch from app menu |
| **WhatsApp** | Messaging | Launch from app menu |
| **OpenVPN** | VPN client | Settings → Network → VPN → Import .ovpn file |
| **Auto-Tiling** | Built into Pop!_OS | `Super + Y` to toggle (already available, no install needed) |

## Post-Install Checklist

After running the script, complete these steps:

```bash
# 1. Log out and back in (activates Docker group + Zsh)

# 2. Authenticate AI tools
claude                          # Anthropic account
gemini                          # Google account

# 3. Launch Antigravity from app menu → sign in with Google

# 4. Set up remote access
sudo tailscale up               # Connect to Tailscale
nano ~/.ssh/config              # Add Mac's Tailscale IP

# 5. GitHub setup
gh auth login                   # Authenticate GitHub CLI
cat ~/.ssh/id_ed25519.pub       # Copy & add to GitHub SSH keys

# 6. Optional
ollama pull qwen2.5-coder:32b   # 64GB RAM handles 32B param models
sudo timeshift --create         # First system snapshot
```

## Pro Tips

**Pop!_OS Auto-Tiling:** Press `Super + Y` to toggle. Arrange windows side-by-side automatically while coding.

**Warp + Claude Code:** Open Warp, type `claude`, and you have an AI coding agent with beautiful terminal UI.

**direnv for projects:** Create a `.envrc` in each project folder with env vars. They load/unload automatically when you `cd` in/out.

**lazygit shortcuts:** Press `?` inside lazygit for all keybindings. Game changer for git workflow.

**Battery on the go:** TLP handles most optimization automatically. For extra savings, use Pop!_OS power profiles: click battery icon → choose Battery mode.

## Tested On

- Pop!_OS 22.04 LTS (HP Dev One)
- Pop!_OS 24.04
- Ubuntu 22.04 / 24.04
- macOS Sequoia 15.7.3 (Apple Silicon)

## Troubleshooting

**Docker permission denied:** Log out and back in after install (script adds you to docker group).

**npm global install errors:** The script configures `~/.npm-global` — if issues persist, check `npm config get prefix`.

**Antigravity Zsh warnings:** The script patches this automatically. If you still see warnings: `sudo chmod -R 755 /usr/share/zsh/vendor-completions`.

**Tailscale not connecting:** Check `sudo tailscale status`. Make sure you're signed into the same Tailscale account on both machines.

**NoMachine download fails:** Version URL may have changed. Download manually from [nomachine.com/download](https://www.nomachine.com/download).

## License

MIT
