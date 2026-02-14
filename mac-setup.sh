#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Mac Studio Companion Setup                                     ║
# ║  Pairs with the HP Dev One (Pop!_OS) vibe coding setup         ║
# ║                                                                 ║
# ║  Installs: Tailscale, RustDesk, NoMachine, Homebrew,           ║
# ║            Ollama, Claude Code, Gemini CLI, dev tools           ║
# ║                                                                 ║
# ║  Safe to re-run (idempotent). MIT License.                     ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Usage:
#   chmod +x mac-setup.sh
#   ./mac-setup.sh
#
# Options:
#   --skip-remote   Skip remote access tools
#   --skip-ai       Skip AI CLI tools
#   --dry-run       Preview without installing
#   --help          Show this help message

set -euo pipefail

# ─── Colors & Helpers ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="$HOME/.mac-dev-setup.log"
ERRORS=()
WARNINGS=()

log()    { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; WARNINGS+=("$1"); }
error()  { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; ERRORS+=("$1"); }
info()   { echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE"; }
header() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}" | tee -a "$LOG_FILE"; }

# ─── Parse Arguments ──────────────────────────────────────────────
SKIP_REMOTE=false
SKIP_AI=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --skip-remote) SKIP_REMOTE=true ;;
        --skip-ai)     SKIP_AI=true ;;
        --dry-run)     DRY_RUN=true ;;
        --help)
            head -22 "$0" | grep "^#" | sed 's/^# *//'
            exit 0
            ;;
    esac
done

# ─── Pre-flight ───────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is for macOS only. Use setup.sh for Pop!_OS/Ubuntu."
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    error "Do not run as root."
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🍎 Mac Studio Companion Setup                        ║${NC}"
echo -e "${CYAN}║   Remote Access + AI Tools + Dev Essentials             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"

if $DRY_RUN; then
    warn "DRY RUN MODE — nothing will be installed"
fi

# ─── Helpers ──────────────────────────────────────────────────────
is_installed() {
    command -v "$1" &>/dev/null
}

is_brew_installed() {
    brew list "$1" &>/dev/null 2>&1
}

is_cask_installed() {
    brew list --cask "$1" &>/dev/null 2>&1
}

run() {
    if $DRY_RUN; then
        info "[dry-run] Would execute: $*"
    else
        "$@"
    fi
}

# ══════════════════════════════════════════════════════════════════
# 1. HOMEBREW
# ══════════════════════════════════════════════════════════════════
header "1/8 — Homebrew"

if ! is_installed brew; then
    if ! $DRY_RUN; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            BREW_LINE='eval "$(/opt/homebrew/bin/brew shellenv)"'
            for rcfile in "$HOME/.zprofile" "$HOME/.bash_profile"; do
                if [[ ! -f "$rcfile" ]] || ! grep -q "homebrew" "$rcfile"; then
                    echo "$BREW_LINE" >> "$rcfile"
                fi
            done
        fi
        log "Homebrew installed"
    else
        info "[dry-run] Would install Homebrew"
    fi
else
    log "Homebrew already installed"
    run brew update
fi

# ══════════════════════════════════════════════════════════════════
# 2. ENABLE REMOTE LOGIN (SSH)
# ══════════════════════════════════════════════════════════════════
if ! $SKIP_REMOTE; then

header "2/8 — Enable Remote Login (SSH)"

if ! $DRY_RUN; then
    # Check if Remote Login is enabled
    SSH_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null | awk '{print $NF}')
    if [[ "$SSH_STATUS" != "On" ]]; then
        sudo systemsetup -setremotelogin on
        log "Remote Login (SSH) enabled"
        info "Your Linux machine can now SSH into this Mac"
    else
        log "Remote Login (SSH) already enabled"
    fi
else
    info "[dry-run] Would enable Remote Login"
fi

# Prevent sleep when display is off (critical for remote access)
if ! $DRY_RUN; then
    sudo pmset -c displaysleep 10 sleep 0 disksleep 0
    log "Sleep disabled on AC power (display sleeps after 10min, Mac stays awake)"
else
    info "[dry-run] Would disable sleep on AC power"
fi

fi # end !SKIP_REMOTE

# ══════════════════════════════════════════════════════════════════
# 3. TAILSCALE
# ══════════════════════════════════════════════════════════════════
if ! $SKIP_REMOTE; then

header "3/8 — Tailscale"

if ! is_cask_installed tailscale && ! is_installed tailscale; then
    if ! $DRY_RUN; then
        brew install --cask tailscale
        log "Tailscale installed"
        info "Open Tailscale from app menu and sign in with same account as your Linux machine"
    fi
else
    log "Tailscale already installed"
fi

fi # end !SKIP_REMOTE

# ══════════════════════════════════════════════════════════════════
# 4. RUSTDESK
# ══════════════════════════════════════════════════════════════════
if ! $SKIP_REMOTE; then

header "4/8 — RustDesk"

if ! is_cask_installed rustdesk; then
    if ! $DRY_RUN; then
        brew install --cask rustdesk
        log "RustDesk installed"
        info "Open RustDesk to see your ID (share with Linux machine)"
    fi
else
    log "RustDesk already installed"
fi

fi # end !SKIP_REMOTE

# ══════════════════════════════════════════════════════════════════
# 5. NOMACHINE
# ══════════════════════════════════════════════════════════════════
if ! $SKIP_REMOTE; then

header "5/8 — NoMachine"

if ! is_cask_installed nomachine && [[ ! -d "/Applications/NoMachine.app" ]]; then
    if ! $DRY_RUN; then
        brew install --cask nomachine
        log "NoMachine installed"
        info "NoMachine starts automatically — your Linux machine can connect via Tailscale IP"
    fi
else
    log "NoMachine already installed"
fi

fi # end !SKIP_REMOTE

# ══════════════════════════════════════════════════════════════════
# 6. NODE.JS + AI CLI TOOLS
# ══════════════════════════════════════════════════════════════════
if ! $SKIP_AI; then

header "6/8 — Node.js + AI CLI Tools"

# Node.js
if ! is_installed node || [[ $(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1) -lt 18 ]]; then
    run brew install node@22
    log "Node.js installed"
else
    log "Node.js $(node -v) already installed"
fi

# npm global without sudo
if [[ ! -d "$HOME/.npm-global" ]]; then
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
fi

NPM_PATH_LINE='export PATH="$HOME/.npm-global/bin:$PATH"'
for rcfile in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [[ -f "$rcfile" ]] && ! grep -q ".npm-global/bin" "$rcfile"; then
        echo "$NPM_PATH_LINE" >> "$rcfile"
    fi
done
export PATH="$HOME/.npm-global/bin:$PATH"

# Claude Code
if ! is_installed claude; then
    run npm install -g @anthropic-ai/claude-code
    log "Claude Code installed"
else
    log "Claude Code already installed"
fi

# Gemini CLI
if ! is_installed gemini; then
    run npm install -g @google/gemini-cli
    log "Gemini CLI installed"
else
    log "Gemini CLI already installed"
fi

fi # end !SKIP_AI

# ══════════════════════════════════════════════════════════════════
# 7. OLLAMA + DEV ESSENTIALS
# ══════════════════════════════════════════════════════════════════
header "7/8 — Ollama + Dev Essentials"

# Ollama
if ! is_installed ollama; then
    if ! $DRY_RUN; then
        brew install ollama
        log "Ollama installed"
        info "With M3 Ultra + 96GB: ollama pull qwen2.5-coder:32b"
        info "Or even: ollama pull deepseek-coder-v2:33b"
    fi
else
    log "Ollama already installed"
fi

# Essential CLI tools
BREW_PACKAGES=(
    git
    jq
    htop
    tree
    bat
    ripgrep
    fd
    fzf
    direnv
    gh
    lazygit
    lazydocker
    wget
    cmake
    openvpn
    uv
)

MISSING_BREWS=()
for pkg in "${BREW_PACKAGES[@]}"; do
    if ! is_brew_installed "$pkg"; then
        MISSING_BREWS+=("$pkg")
    fi
done

if [[ ${#MISSING_BREWS[@]} -gt 0 ]]; then
    info "Installing ${#MISSING_BREWS[@]} brew packages..."
    run brew install "${MISSING_BREWS[@]}"
    log "Dev essentials installed"
else
    log "Dev essentials already installed"
fi

# Slack
if ! is_cask_installed slack; then
    run brew install --cask slack
    log "Slack installed"
else
    log "Slack already installed"
fi

# Telegram
if ! is_cask_installed telegram; then
    run brew install --cask telegram
    log "Telegram installed"
else
    log "Telegram already installed"
fi

# WhatsApp
if ! is_cask_installed whatsapp; then
    run brew install --cask whatsapp
    log "WhatsApp installed"
else
    log "WhatsApp already installed"
fi

# direnv hook
if [[ -f "$HOME/.zshrc" ]] && ! grep -q "direnv hook" "$HOME/.zshrc"; then
    echo 'eval "$(direnv hook zsh)"' >> "$HOME/.zshrc"
fi

# ══════════════════════════════════════════════════════════════════
# 8. SSH KEY + MACOS SETTINGS
# ══════════════════════════════════════════════════════════════════
header "8/8 — SSH Key + macOS Settings"

# SSH key
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    if ! $DRY_RUN; then
        GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "dev@localhost")
        ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
        eval "$(ssh-agent -s)" &>/dev/null

        # Add to macOS keychain
        ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null || ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null

        # SSH config for keychain persistence
        if [[ ! -f "$HOME/.ssh/config" ]]; then
            cat > "$HOME/.ssh/config" << 'EOF'
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
            chmod 600 "$HOME/.ssh/config"
        fi

        log "SSH key generated (stored in macOS Keychain)"
        info "Add to GitHub: cat ~/.ssh/id_ed25519.pub"
    fi
else
    log "SSH key already exists"
fi

# Show Tailscale IP for reference
if is_installed tailscale; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "not connected")
    if [[ "$TS_IP" != "not connected" ]]; then
        info "Your Tailscale IP: $TS_IP (use this in Linux SSH config)"
    fi
fi

# ─── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  ✅ Mac Setup Complete!                   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if ! $SKIP_REMOTE; then
echo -e "${BOLD}🌐 Remote Access:${NC}"
echo "  Tailscale, RustDesk, NoMachine, SSH (Remote Login enabled)"
echo ""
fi

if ! $SKIP_AI; then
echo -e "${BOLD}🤖 AI Tools:${NC}"
echo "  Claude Code, Gemini CLI, Ollama"
echo ""
fi

echo -e "${BOLD}⌨  CLI Tools:${NC}"
echo "  bat, ripgrep, fd, fzf, direnv, lazygit, lazydocker, gh"
echo ""

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠  Warnings during setup (${#WARNINGS[@]}):${NC}"
    for w in "${WARNINGS[@]}"; do
        echo -e "  ${YELLOW}• $w${NC}"
    done
    echo ""
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo -e "${RED}⚠  Errors during setup (${#ERRORS[@]}):${NC}"
    for err in "${ERRORS[@]}"; do
        echo -e "  ${RED}• $err${NC}"
    done
    echo ""
fi

echo -e "${YELLOW}⚠  Post-Install Steps:${NC}"
echo ""
echo "  1. Open Tailscale app → sign in (same account as Linux machine)"
echo "  2. Get your Tailscale IP:  tailscale ip -4"
echo "  3. Share the IP with your Linux machine (edit ~/.ssh/config there)"
echo ""

if ! $SKIP_AI; then
echo "  4. claude            → authenticate with Anthropic"
echo "  5. gemini            → authenticate with Google"
echo ""
echo "  Ollama (M3 Ultra + 96GB RAM — go big!):"
echo "  6. ollama serve                        (start server)"
echo "  7. ollama pull qwen2.5-coder:32b       (32B param model)"
echo "  8. ollama pull deepseek-coder-v2:33b   (alternative)"
echo "  9. ollama pull llama3.1:70b            (general purpose)"
echo ""
fi

echo "Log: $LOG_FILE"
echo "Completed: $(date)" >> "$LOG_FILE"
echo -e "${CYAN}Your Mac is ready to be accessed from your HP Dev One! 🎶${NC}"
