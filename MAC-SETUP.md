# 🍎 Mac Studio Companion Setup

This script prepares your Mac Studio (M3 Ultra, 96GB) to be remotely accessed from your HP Dev One running Pop!_OS, and installs matching AI/dev tools on both machines.

## Quick Start

```bash
# On your Mac:
chmod +x mac-setup.sh
./mac-setup.sh
```

## Options

| Flag | What it does |
|------|-------------|
| `--dry-run` | Preview without installing |
| `--skip-remote` | Skip remote access tools |
| `--skip-ai` | Skip AI CLI tools |
| `--help` | Show help |

## What Gets Installed

### 🌐 Remote Access

| Tool | What it does | Notes |
|------|-------------|-------|
| **SSH (Remote Login)** | Enables terminal access to your Mac | Script enables it automatically via System Settings |
| **Prevent Sleep** | Keeps Mac awake on AC power | Display sleeps after 10min, but Mac stays on for remote access |
| **Tailscale** | Encrypted mesh VPN between your devices | Sign in with same account on both machines |
| **RustDesk** | Open-source GUI remote desktop | Share your RustDesk ID with your Linux machine |
| **NoMachine** | High-performance GUI remote desktop | Connect via Tailscale IP from Linux |

### 🤖 AI Tools

| Tool | What it does | Recommended models (96GB RAM) |
|------|-------------|-------------------------------|
| **Claude Code** | Anthropic's AI coding agent | `claude` to start |
| **Gemini CLI** | Google's AI coding agent | `gemini` to start |
| **Ollama** | Local AI models | `qwen2.5-coder:32b`, `deepseek-coder-v2:33b`, `llama3.1:70b` |

> With your M3 Ultra + 96GB RAM, you can run 70B parameter models locally. That's enterprise-grade AI running on your desk with no cloud dependency.

### ⌨ CLI Tools

Same set as the Linux machine for consistent workflow:

| Tool | Usage |
|------|-------|
| **bat** | `bat file.py` — cat with syntax highlighting |
| **ripgrep** | `rg "pattern"` — fast recursive search |
| **fd** | `fd "\.rs$"` — fast file finder |
| **fzf** | `Ctrl+R` — fuzzy history search |
| **direnv** | Auto-load `.envrc` per project |
| **gh** | `gh pr create` — GitHub CLI |
| **lazygit** | `lazygit` — terminal git UI |
| **lazydocker** | `lazydocker` — terminal Docker UI |

## Connecting Linux → Mac

After running both scripts (`setup.sh` on Linux, `mac-setup.sh` on Mac):

### Step 1: Tailscale on both machines

```bash
# Mac: Open Tailscale app, sign in

# Linux:
sudo tailscale up
# Sign in with SAME account
```

### Step 2: Get Mac's Tailscale IP

```bash
# On Mac:
tailscale ip -4
# Example output: 100.64.23.45
```

### Step 3: Configure Linux SSH

```bash
# On Linux, edit SSH config:
nano ~/.ssh/config

# Uncomment and fill in:
Host mac
    HostName 100.64.23.45    # ← your Mac's Tailscale IP
    User yourmacusername     # ← your Mac username
    ForwardAgent yes
```

### Step 4: Connect!

```bash
# Terminal access:
ssh mac

# Copy files Mac → Linux:
scp mac:~/project/file.txt .

# Sync a folder:
rsync -avz mac:~/projects/myapp/ ./myapp/

# GUI access:
# Open RustDesk or NoMachine on Linux, connect to Mac's Tailscale IP
```

## Ollama on M3 Ultra (96GB)

Your Mac Studio is a beast for local AI. Here's what fits:

| Model | Size | RAM needed | Best for |
|-------|------|-----------|----------|
| `qwen2.5-coder:7b` | 4.7GB | ~8GB | Quick code tasks |
| `qwen2.5-coder:32b` | 18GB | ~24GB | Serious coding, large context |
| `deepseek-coder-v2:33b` | 19GB | ~26GB | Complex code generation |
| `llama3.1:70b` | 40GB | ~48GB | General purpose, reasoning |
| `codestral:22b` | 12GB | ~16GB | Mistral's code model |

```bash
# Start Ollama server (runs in background):
ollama serve

# Pull models:
ollama pull qwen2.5-coder:32b
ollama pull llama3.1:70b

# Run interactively:
ollama run qwen2.5-coder:32b

# Use from your Linux machine over Tailscale:
# On Mac: OLLAMA_HOST=0.0.0.0 ollama serve
# On Linux: OLLAMA_HOST=100.64.23.45 ollama run qwen2.5-coder:32b
```

> **Pro tip:** Run Ollama on your Mac Studio and access it from your HP Dev One over Tailscale. This gives you M3 Ultra GPU inference from your laptop anywhere in the world.

## Expose Ollama to Linux via Tailscale

To use your Mac's Ollama from your Linux machine:

**On Mac (one-time setup):**
```bash
# Create a launchd plist to start Ollama bound to all interfaces:
sudo tee /Library/LaunchDaemons/com.ollama.serve.plist > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.serve</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Or simply run manually:
OLLAMA_HOST=0.0.0.0 ollama serve
```

**On Linux:**
```bash
# Set your Mac's Tailscale IP as the Ollama host:
export OLLAMA_HOST=100.64.23.45

# Now use it like it's local:
ollama run qwen2.5-coder:32b

# Add to .zshrc for persistence:
echo 'export OLLAMA_HOST=100.64.23.45' >> ~/.zshrc
```

> Tailscale encrypts all traffic, so this is secure even over the internet.

## macOS Permissions

The script may trigger macOS permission dialogs for:

- **Remote Login:** Needs admin password
- **Tailscale:** Network extension permission
- **RustDesk:** Screen Recording + Accessibility permissions (System Settings → Privacy & Security)
- **NoMachine:** Screen Recording + Accessibility permissions

Grant these when prompted — they're required for remote access to work.

## Tested On

- macOS Sonoma 14.x (Apple Silicon)
- macOS Sequoia 15.x (Apple Silicon)
- Mac Studio M3 Ultra

## License

MIT
