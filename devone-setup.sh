#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Vibe Coding Dev Setup for HP Dev One (Pop!_OS / Ubuntu)       ║
# ║                                                                 ║
# ║  AI Tools: Claude Code, Gemini CLI, Warp, Antigravity, Ollama ║
# ║  Dev:      Python, Rust, Docker, Node.js, VS Code             ║
# ║  Shell:    Zsh + Oh-My-Zsh + plugins                          ║
# ║  Remote:   Tailscale, RustDesk, NoMachine, SSH                ║
# ║  CLI:      lazygit, lazydocker, bat, ripgrep, fd, fzf, gh     ║
# ║  System:   TLP, UFW, Timeshift, firmware updates              ║
# ║                                                                 ║
# ║  Safe to re-run (idempotent). MIT License.                     ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# Options:
#   --skip-git        Skip git config prompt
#   --skip-remote     Skip remote access tools (Tailscale, RustDesk, NoMachine)
#   --skip-gui-remote Skip GUI remote tools (RustDesk, NoMachine) but keep Tailscale+SSH
#   --minimal         Only install AI tools + languages (skip system tuning, remote, CLI extras)
#   --dry-run         Show what would be installed without installing
#   --help            Show this help message

set -euo pipefail

# ─── Colors & Helpers ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="$HOME/.vibe-dev-setup.log"
ERRORS=()
WARNINGS=()

log()    { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; WARNINGS+=("$1"); }
error()  { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; ERRORS+=("$1"); }
info()   { echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE"; }
header() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}" | tee -a "$LOG_FILE"; }

# ─── Parse Arguments ──────────────────────────────────────────────
SKIP_GIT=false
SKIP_REMOTE=false
SKIP_GUI_REMOTE=false
MINIMAL=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --skip-git)        SKIP_GIT=true ;;
        --skip-remote)     SKIP_REMOTE=true ;;
        --skip-gui-remote) SKIP_GUI_REMOTE=true ;;
        --minimal)         MINIMAL=true ;;
        --dry-run)         DRY_RUN=true ;;
        --help)
            head -28 "$0" | grep "^#" | sed 's/^# *//'
            exit 0
            ;;
    esac
done

# ─── Pre-flight Checks ───────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root. It will ask for sudo when needed."
    exit 1
fi

if ! command -v apt &>/dev/null; then
    error "This script requires apt (Debian/Ubuntu/Pop!_OS). Exiting."
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🚀 Vibe Coding Dev Setup — HP Dev One / Pop!_OS      ║${NC}"
echo -e "${CYAN}║   v2.0 — AI Tools, Remote Access, System Tuning        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"

if $DRY_RUN; then
    warn "DRY RUN MODE — nothing will be installed"
fi
if $MINIMAL; then
    info "MINIMAL MODE — skipping system tuning, remote tools, CLI extras"
fi

# ─── Helpers ──────────────────────────────────────────────────────
is_installed() {
    command -v "$1" &>/dev/null
}

is_apt_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

run() {
    if $DRY_RUN; then
        info "[dry-run] Would execute: $*"
    else
        "$@"
    fi
}

get_ubuntu_codename() {
    local codename
    codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    if [[ -z "$codename" ]] || [[ "$codename" == "null" ]]; then
        codename=$(lsb_release -cs 2>/dev/null || echo "jammy")
    fi
    case "$codename" in
        *pop*|cosmic|disco|eoan|impish|kinetic|lunar|mantic)
            codename="jammy"
            ;;
    esac
    echo "$codename"
}

# ══════════════════════════════════════════════════════════════════
# 1. SYSTEM UPDATE & BASE PACKAGES
# ══════════════════════════════════════════════════════════════════
header "1/16 — System Update & Base Packages"

BASE_PACKAGES=(
    build-essential curl wget git unzip zip jq htop tree
    software-properties-common apt-transport-https
    ca-certificates gnupg lsb-release
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev
    libsqlite3-dev libncursesw5-dev xz-utils tk-dev
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    pkg-config cmake
)

run sudo apt update -y
run sudo apt upgrade -y

MISSING_PKGS=()
for pkg in "${BASE_PACKAGES[@]}"; do
    if ! is_apt_installed "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    info "Installing ${#MISSING_PKGS[@]} missing base packages..."
    run sudo apt install -y "${MISSING_PKGS[@]}"
    log "Base packages installed"
else
    log "Base packages already installed"
fi

# ══════════════════════════════════════════════════════════════════
# 2. GIT CONFIGURATION + SSH KEY
# ══════════════════════════════════════════════════════════════════
header "2/16 — Git Configuration + SSH Key"

if ! $SKIP_GIT; then
    CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
    CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

    if [[ -z "$CURRENT_NAME" ]] || [[ -z "$CURRENT_EMAIL" ]]; then
        if ! $DRY_RUN; then
            echo ""
            read -rp "Enter your Git name (e.g. John Doe): " GIT_NAME
            read -rp "Enter your Git email: " GIT_EMAIL
            git config --global user.name "$GIT_NAME"
            git config --global user.email "$GIT_EMAIL"
            log "Git configured: $GIT_NAME <$GIT_EMAIL>"
        else
            info "[dry-run] Would prompt for git name/email"
        fi
    else
        log "Git already configured: $CURRENT_NAME <$CURRENT_EMAIL>"
    fi

    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global push.autoSetupRemote true
    git config --global core.editor "code --wait"
    git config --global diff.tool vscode
    git config --global merge.tool vscode

    # Generate SSH key
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        if ! $DRY_RUN; then
            GIT_EMAIL_FOR_KEY=$(git config --global user.email 2>/dev/null || echo "dev@localhost")
            ssh-keygen -t ed25519 -C "$GIT_EMAIL_FOR_KEY" -f "$HOME/.ssh/id_ed25519" -N ""
            eval "$(ssh-agent -s)" &>/dev/null
            ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null
            log "SSH key generated at ~/.ssh/id_ed25519"
            info "Add to GitHub: cat ~/.ssh/id_ed25519.pub"
        fi
    else
        log "SSH key already exists"
    fi
else
    info "Skipping git config (--skip-git)"
fi

# ══════════════════════════════════════════════════════════════════
# 3. ZSH + OH-MY-ZSH
# ══════════════════════════════════════════════════════════════════
header "3/16 — Zsh + Oh-My-Zsh"

if ! is_installed zsh; then
    run sudo apt install -y zsh
    log "Zsh installed"
else
    log "Zsh already installed"
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would install Oh-My-Zsh"
    else
        RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log "Oh-My-Zsh installed"
    fi
else
    log "Oh-My-Zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A ZSH_PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
)

for plugin_name in "${!ZSH_PLUGINS[@]}"; do
    if [[ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]]; then
        run git clone "${ZSH_PLUGINS[$plugin_name]}" "$ZSH_CUSTOM/plugins/$plugin_name" 2>/dev/null || true
        log "$plugin_name installed"
    else
        log "$plugin_name already installed"
    fi
done

if ! $DRY_RUN && [[ -f "$HOME/.zshrc" ]]; then
    if grep -q "plugins=(git)" "$HOME/.zshrc"; then
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions docker docker-compose direnv fzf)/' "$HOME/.zshrc"
        log "Updated .zshrc plugins"
    fi
fi

if [[ "$SHELL" != *"zsh"* ]]; then
    if ! $DRY_RUN; then
        sudo chsh -s "$(which zsh)" "$USER"
        log "Default shell changed to Zsh"
    fi
else
    log "Zsh is already default shell"
fi

# ══════════════════════════════════════════════════════════════════
# 4. NODE.JS
# ══════════════════════════════════════════════════════════════════
header "4/16 — Node.js"

if ! is_installed node || [[ $(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1) -lt 18 ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would install Node.js 22.x"
    else
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt install -y nodejs
        log "Node.js installed"
    fi
else
    log "Node.js $(node -v) already installed"
fi

if [[ ! -d "$HOME/.npm-global" ]]; then
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
fi

NPM_PATH_LINE='export PATH="$HOME/.npm-global/bin:$PATH"'
for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rcfile" ]] && ! grep -q ".npm-global/bin" "$rcfile"; then
        echo "$NPM_PATH_LINE" >> "$rcfile"
    fi
done
export PATH="$HOME/.npm-global/bin:$PATH"

# ══════════════════════════════════════════════════════════════════
# 5. PYTHON (pyenv + pipx)
# ══════════════════════════════════════════════════════════════════
header "5/16 — Python (pyenv + pipx)"

if ! is_installed pyenv; then
    if $DRY_RUN; then
        info "[dry-run] Would install pyenv + Python 3.12"
    else
        curl -fsSL https://pyenv.run | bash
        PYENV_INIT='
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
'
        for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
            if [[ -f "$rcfile" ]] && ! grep -q "PYENV_ROOT" "$rcfile"; then
                echo "$PYENV_INIT" >> "$rcfile"
            fi
        done
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
        info "Installing Python 3.12 (may take a few minutes)..."
        pyenv install 3.12 --skip-existing
        pyenv global 3.12
        log "Python 3.12 installed via pyenv"
    fi
else
    log "pyenv already installed"
fi

if ! is_installed pipx; then
    if is_installed pip3; then
        run pip3 install --user pipx 2>/dev/null || run sudo apt install -y pipx
    else
        run sudo apt install -y pipx
    fi
    run pipx ensurepath 2>/dev/null || true
    log "pipx installed"
else
    log "pipx already installed"
fi

# uv (fast Python package manager)
if ! is_installed uv; then
    if $DRY_RUN; then
        info "[dry-run] Would install uv"
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh
        log "uv installed"
    fi
else
    log "uv already installed"
fi

# ══════════════════════════════════════════════════════════════════
# 6. RUST (rustup)
# ══════════════════════════════════════════════════════════════════
header "6/16 — Rust (rustup)"

if ! is_installed rustc; then
    if $DRY_RUN; then
        info "[dry-run] Would install Rust via rustup"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        source "$HOME/.cargo/env"
        log "Rust $(rustc --version | awk '{print $2}') installed"
    fi
else
    log "Rust $(rustc --version | awk '{print $2}') already installed"
fi

CARGO_LINE='source "$HOME/.cargo/env"'
for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rcfile" ]] && ! grep -q "cargo/env" "$rcfile"; then
        echo "$CARGO_LINE" >> "$rcfile"
    fi
done

# ══════════════════════════════════════════════════════════════════
# 7. DOCKER + DOCKER COMPOSE
# ══════════════════════════════════════════════════════════════════
header "7/16 — Docker + Docker Compose"

if ! is_installed docker; then
    if $DRY_RUN; then
        info "[dry-run] Would install Docker + Docker Compose"
    else
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        UBUNTU_CODENAME=$(get_ubuntu_codename)
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update -y
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker "$USER"
        log "Docker + Compose installed"
    fi
else
    log "Docker already installed"
fi

# ══════════════════════════════════════════════════════════════════
# 8. VS CODE
# ══════════════════════════════════════════════════════════════════
header "8/16 — VS Code"

if ! is_installed code; then
    if $DRY_RUN; then
        info "[dry-run] Would install VS Code"
    else
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
            sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        sudo apt update -y
        sudo apt install -y code
        log "VS Code installed"
    fi
else
    log "VS Code already installed"
fi

# ══════════════════════════════════════════════════════════════════
# 9. WARP TERMINAL
# ══════════════════════════════════════════════════════════════════
header "9/16 — Warp Terminal"

if ! is_installed warp-terminal; then
    if $DRY_RUN; then
        info "[dry-run] Would install Warp Terminal"
    else
        wget -qO- https://releases.warp.dev/linux/keys/warp.gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/warp-gpg-keyring.gpg > /dev/null
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/warp-gpg-keyring.gpg] https://releases.warp.dev/linux/deb stable main" | \
            sudo tee /etc/apt/sources.list.d/warp.list > /dev/null
        sudo apt update -y
        sudo apt install -y warp-terminal
        log "Warp Terminal installed"
    fi
else
    log "Warp Terminal already installed"
fi

# ══════════════════════════════════════════════════════════════════
# 10. GOOGLE ANTIGRAVITY IDE
# ══════════════════════════════════════════════════════════════════
header "10/16 — Google Antigravity IDE"

if ! is_apt_installed antigravity; then
    if $DRY_RUN; then
        info "[dry-run] Would install Antigravity IDE"
    else
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
            sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg
        echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
            sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
        sudo apt update -y
        sudo apt install -y antigravity
        # Fix Zsh completion permissions bug
        if [[ -d /usr/share/zsh/vendor-completions ]]; then
            sudo chmod -R 755 /usr/share/zsh/vendor-completions
            sudo chown -R root:root /usr/share/zsh/vendor-completions
        fi
        log "Antigravity IDE installed"
    fi
else
    log "Antigravity already installed"
fi

# ══════════════════════════════════════════════════════════════════
# 11. AI CLI TOOLS
# ══════════════════════════════════════════════════════════════════
header "11/16 — AI CLI Tools"

if ! is_installed claude; then
    run npm install -g @anthropic-ai/claude-code
    log "Claude Code installed"
else
    log "Claude Code already installed"
fi

if ! is_installed gemini; then
    run npm install -g @google/gemini-cli
    log "Gemini CLI installed"
else
    log "Gemini CLI already installed"
fi

if ! is_installed ollama; then
    if $DRY_RUN; then
        info "[dry-run] Would install Ollama"
    else
        curl -fsSL https://ollama.com/install.sh | sh
        log "Ollama installed"
    fi
else
    log "Ollama already installed"
fi

# ══════════════════════════════════════════════════════════════════
# 12. MODERN CLI TOOLS
# ══════════════════════════════════════════════════════════════════
if ! $MINIMAL; then

header "12/16 — Modern CLI Tools"

# bat
if ! is_installed bat && ! is_installed batcat; then
    run sudo apt install -y bat
    if ! $DRY_RUN && is_installed batcat && ! is_installed bat; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
    fi
    log "bat installed"
else
    log "bat already installed"
fi

# ripgrep
if ! is_installed rg; then
    run sudo apt install -y ripgrep
    log "ripgrep installed"
else
    log "ripgrep already installed"
fi

# fd
if ! is_installed fd && ! is_installed fdfind; then
    run sudo apt install -y fd-find
    if ! $DRY_RUN && is_installed fdfind && ! is_installed fd; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    fi
    log "fd installed"
else
    log "fd already installed"
fi

# fzf
if ! is_installed fzf; then
    run sudo apt install -y fzf
    log "fzf installed"
else
    log "fzf already installed"
fi

# direnv
if ! is_installed direnv; then
    run sudo apt install -y direnv
    for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rcfile" ]] && ! grep -q "direnv hook" "$rcfile"; then
            if [[ "$rcfile" == *"zshrc"* ]]; then
                echo 'eval "$(direnv hook zsh)"' >> "$rcfile"
            else
                echo 'eval "$(direnv hook bash)"' >> "$rcfile"
            fi
        fi
    done
    log "direnv installed"
else
    log "direnv already installed"
fi

# GitHub CLI
if ! is_installed gh; then
    if $DRY_RUN; then
        info "[dry-run] Would install GitHub CLI"
    else
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
            sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update -y
        sudo apt install -y gh
        log "GitHub CLI installed"
    fi
else
    log "GitHub CLI already installed"
fi

# lazygit
if ! is_installed lazygit; then
    if $DRY_RUN; then
        info "[dry-run] Would install lazygit"
    else
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name' | sed 's/v//')
        if [[ -n "$LAZYGIT_VERSION" && "$LAZYGIT_VERSION" != "null" ]]; then
            curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
            sudo install /tmp/lazygit /usr/local/bin
            rm -f /tmp/lazygit /tmp/lazygit.tar.gz
            log "lazygit installed"
        else
            warn "Could not fetch lazygit — skipping"
        fi
    fi
else
    log "lazygit already installed"
fi

# lazydocker
if ! is_installed lazydocker; then
    if $DRY_RUN; then
        info "[dry-run] Would install lazydocker"
    else
        LAZYDOCKER_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | jq -r '.tag_name' | sed 's/v//')
        if [[ -n "$LAZYDOCKER_VERSION" && "$LAZYDOCKER_VERSION" != "null" ]]; then
            curl -Lo /tmp/lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz"
            tar xf /tmp/lazydocker.tar.gz -C /tmp lazydocker
            sudo install /tmp/lazydocker /usr/local/bin
            rm -f /tmp/lazydocker /tmp/lazydocker.tar.gz
            log "lazydocker installed"
        else
            warn "Could not fetch lazydocker — skipping"
        fi
    fi
else
    log "lazydocker already installed"
fi

fi # end !MINIMAL

# ══════════════════════════════════════════════════════════════════
# 13. REMOTE ACCESS (Tailscale, RustDesk, NoMachine)
# ══════════════════════════════════════════════════════════════════
if ! $MINIMAL && ! $SKIP_REMOTE; then

header "13/16 — Remote Access Tools"

# Tailscale
if ! is_installed tailscale; then
    if $DRY_RUN; then
        info "[dry-run] Would install Tailscale"
    else
        curl -fsSL https://tailscale.com/install.sh | sh
        log "Tailscale installed"
    fi
else
    log "Tailscale already installed"
fi

# Enable Tailscale to start on boot and connect
if ! $DRY_RUN && is_installed tailscale; then
    sudo systemctl enable --now tailscaled 2>/dev/null || true
    sudo tailscale up 2>/dev/null || true
    log "Tailscale enabled on boot and connected"
else
    info "[dry-run] Would enable Tailscale on boot"
fi

if ! $SKIP_GUI_REMOTE; then

# RustDesk
if ! is_installed rustdesk; then
    if $DRY_RUN; then
        info "[dry-run] Would install RustDesk"
    else
        RUSTDESK_VERSION=$(curl -s "https://api.github.com/repos/rustdesk/rustdesk/releases/latest" | jq -r '.tag_name' | sed 's/v//')
        if [[ -n "$RUSTDESK_VERSION" && "$RUSTDESK_VERSION" != "null" ]]; then
            wget -qO /tmp/rustdesk.deb "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-${RUSTDESK_VERSION}-x86_64.deb"
            sudo apt install -y /tmp/rustdesk.deb 2>/dev/null || sudo apt --fix-broken install -y
            rm -f /tmp/rustdesk.deb
            log "RustDesk installed"
        else
            warn "Could not fetch RustDesk — install manually from rustdesk.com"
        fi
    fi
else
    log "RustDesk already installed"
fi

# NoMachine
if ! is_apt_installed nomachine && [[ ! -f /usr/NX/bin/nxplayer ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would install NoMachine"
    else
        NOMACHINE_URL="https://download.nomachine.com/download/8.16/Linux/nomachine_8.16.1_1_amd64.deb"
        wget -qO /tmp/nomachine.deb "$NOMACHINE_URL" 2>/dev/null
        if [[ -s /tmp/nomachine.deb ]]; then
            sudo dpkg -i /tmp/nomachine.deb 2>/dev/null || sudo apt --fix-broken install -y
            rm -f /tmp/nomachine.deb
            log "NoMachine installed"
        else
            warn "NoMachine download failed — install manually from nomachine.com"
        fi
    fi
else
    log "NoMachine already installed"
fi

fi # end !SKIP_GUI_REMOTE

# SSH config
if [[ ! -f "$HOME/.ssh/config" ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would create SSH config"
    else
        mkdir -p "$HOME/.ssh"
        cat > "$HOME/.ssh/config" << 'EOF'
# ─── Mac Studio via Tailscale ────────────────
# Uncomment and edit after running 'tailscale up' on both machines
# Host mac
#     HostName 100.x.x.x        # Your Mac's Tailscale IP
#     User yourusername
#     IdentityFile ~/.ssh/id_ed25519
#     ForwardAgent yes

# ─── Defaults ────────────────────────────────
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 "$HOME/.ssh/config"
        log "SSH config created"
    fi
else
    log "SSH config already exists"
fi

fi # end !SKIP_REMOTE

# ══════════════════════════════════════════════════════════════════
# 14. SYSTEM SECURITY & FIREWALL
# ══════════════════════════════════════════════════════════════════
if ! $MINIMAL; then

header "14/16 — Security & Firewall"

if ! is_installed ufw; then
    run sudo apt install -y ufw
fi

if $DRY_RUN; then
    info "[dry-run] Would configure UFW firewall rules"
else
    if ! sudo ufw status | grep -q "Status: active"; then
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        sudo ufw allow in on tailscale0 2>/dev/null || true
        sudo ufw allow 21115:21119/tcp 2>/dev/null || true
        sudo ufw allow 21116/udp 2>/dev/null || true
        sudo ufw allow 4000/tcp 2>/dev/null || true
        sudo ufw --force enable
        log "UFW firewall enabled"
    else
        log "UFW already active"
    fi
fi

fi # end !MINIMAL

# ══════════════════════════════════════════════════════════════════
# 15. POWER MANAGEMENT & PERFORMANCE TUNING
# ══════════════════════════════════════════════════════════════════
if ! $MINIMAL; then

header "15/16 — Power & Performance"

# TLP
if ! is_installed tlp; then
    run sudo apt install -y tlp tlp-rdw
    if $DRY_RUN; then
        info "[dry-run] Would enable TLP power management"
    else
        sudo systemctl enable tlp
        sudo systemctl start tlp
        log "TLP power management installed"
    fi
else
    log "TLP already installed"
fi

# Sysctl tuning
SYSCTL_CONF="/etc/sysctl.d/99-dev-tuning.conf"
if [[ ! -f "$SYSCTL_CONF" ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would apply kernel tuning (sysctl) and tmpfs /tmp"
    else
        sudo tee "$SYSCTL_CONF" > /dev/null << 'EOF'
# Increase inotify watchers for IDEs
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024

# Reduce swappiness (64GB RAM — almost never need swap)
vm.swappiness=1

# Increase file descriptors
fs.file-max=2097152
EOF
        sudo sysctl --system &>/dev/null
        log "Kernel tuning applied"

        # Mount /tmp as tmpfs for faster builds (safe with 64GB RAM)
        if ! grep -q "tmpfs /tmp" /etc/fstab; then
            echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,size=16G 0 0" | sudo tee -a /etc/fstab > /dev/null
            log "tmpfs on /tmp enabled (16GB — takes effect on reboot)"
        fi
    fi
else
    log "Kernel tuning already applied"
fi

# User file limits
LIMITS_CONF="/etc/security/limits.d/99-dev-limits.conf"
if [[ ! -f "$LIMITS_CONF" ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would increase user file limits"
    else
        sudo tee "$LIMITS_CONF" > /dev/null << EOF
$USER soft nofile 65536
$USER hard nofile 65536
EOF
        log "User file limits increased"
    fi
else
    log "User file limits already set"
fi

# Firmware updates
if is_installed fwupdmgr; then
    if $DRY_RUN; then
        info "[dry-run] Would check for firmware updates"
    else
        info "Checking firmware updates..."
        sudo fwupdmgr get-updates 2>/dev/null || true
        sudo fwupdmgr update -y 2>/dev/null || true
        log "Firmware check complete"
    fi
fi

# Timeshift
if ! is_installed timeshift; then
    run sudo apt install -y timeshift
    log "Timeshift installed"
else
    log "Timeshift already installed"
fi

# GNOME Tweaks
if ! is_apt_installed gnome-tweaks; then
    run sudo apt install -y gnome-tweaks
    log "GNOME Tweaks installed"
else
    log "GNOME Tweaks already installed"
fi

# Flameshot
if ! is_installed flameshot; then
    run sudo apt install -y flameshot
    log "Flameshot installed"
else
    log "Flameshot already installed"
fi

# Slack
if ! is_installed slack && ! is_apt_installed slack-desktop; then
    if $DRY_RUN; then
        info "[dry-run] Would install Slack"
    else
        wget -qO /tmp/slack.deb "https://downloads.slack-edge.com/desktop-releases/linux/x64/4.41.105/slack-desktop-4.41.105-amd64.deb" 2>/dev/null
        if [[ -s /tmp/slack.deb ]]; then
            sudo apt install -y /tmp/slack.deb || sudo apt --fix-broken install -y
            rm -f /tmp/slack.deb
            log "Slack installed"
        else
            # Fallback: try snap
            if is_installed snap; then
                sudo snap install slack
                log "Slack installed (via snap)"
            else
                warn "Slack download failed — install manually from slack.com/downloads/linux"
            fi
        fi
    fi
else
    log "Slack already installed"
fi

# Telegram
if ! is_installed telegram-desktop && ! is_apt_installed telegram-desktop; then
    if $DRY_RUN; then
        info "[dry-run] Would install Telegram"
    else
        if is_installed snap; then
            sudo snap install telegram-desktop
            log "Telegram installed (via snap)"
        else
            sudo apt install -y telegram-desktop 2>/dev/null || warn "Telegram install failed — install manually from desktop.telegram.org"
            log "Telegram installed"
        fi
    fi
else
    log "Telegram already installed"
fi

# WhatsApp
if ! snap list whatsapp-linux-app &>/dev/null 2>&1 && ! is_installed whatsapp-for-linux; then
    if $DRY_RUN; then
        info "[dry-run] Would install WhatsApp"
    else
        if is_installed snap; then
            sudo snap install whatsapp-linux-app 2>/dev/null && log "WhatsApp installed (via snap)" \
                || warn "WhatsApp snap not found — use https://web.whatsapp.com or install manually"
        else
            warn "WhatsApp requires snap — use https://web.whatsapp.com or install snapd first"
        fi
    fi
else
    log "WhatsApp already installed"
fi

# OpenVPN
if ! is_installed openvpn; then
    run sudo apt install -y openvpn openvpn-systemd-resolved network-manager-openvpn network-manager-openvpn-gnome
    log "OpenVPN installed (use Settings → Network → VPN to import .ovpn files)"
else
    log "OpenVPN already installed"
fi

# Disable Bluetooth auto-start
if [[ -f /etc/bluetooth/main.conf ]]; then
    if ! grep -q "AutoEnable=false" /etc/bluetooth/main.conf; then
        if $DRY_RUN; then
            info "[dry-run] Would disable Bluetooth auto-start"
        else
            sudo sed -i 's/^#*AutoEnable.*/AutoEnable=false/' /etc/bluetooth/main.conf 2>/dev/null || true
            log "Bluetooth auto-start disabled"
        fi
    else
        log "Bluetooth auto-start already disabled"
    fi
fi

fi # end !MINIMAL

# ══════════════════════════════════════════════════════════════════
# 16. CLEANUP & SUMMARY
# ══════════════════════════════════════════════════════════════════
header "16/16 — Cleanup"

if $DRY_RUN; then
    info "[dry-run] Would run apt autoremove/autoclean"
else
    sudo apt autoremove -y 2>/dev/null || true
    sudo apt autoclean 2>/dev/null || true
    log "Cleaned up"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  ✅ Setup Complete!                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}🤖 AI & Vibe Coding:${NC}"
echo "  Claude Code, Gemini CLI, Ollama, Antigravity IDE, Warp Terminal"
echo ""
echo -e "${BOLD}🛠  Languages & Tools:${NC}"
echo "  Node.js, Python 3.12 (pyenv + uv), Rust, Docker + Compose, VS Code"
echo ""

if ! $MINIMAL; then
echo -e "${BOLD}⌨  CLI Power Tools:${NC}"
echo "  bat, ripgrep, fd, fzf, direnv, lazygit, lazydocker, gh"
echo ""

if ! $SKIP_REMOTE; then
echo -e "${BOLD}🌐 Remote Access:${NC}"
echo "  Tailscale (VPN), SSH"
if ! $SKIP_GUI_REMOTE; then
echo "  RustDesk (GUI), NoMachine (GUI)"
fi
echo ""
fi

echo -e "${BOLD}🔒 System:${NC}"
echo "  UFW firewall, TLP power mgmt, Timeshift, Flameshot, GNOME Tweaks"
echo ""
fi

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
echo "  1. Log out & back in        (Docker group + Zsh)"
echo "  2. claude                    (authenticate Anthropic)"
echo "  3. gemini                    (authenticate Google)"
echo "  4. Launch Antigravity        (sign in with Google)"
echo "  5. sudo tailscale up         (connect VPN)"
echo "  6. gh auth login             (GitHub CLI auth)"
echo "  7. Edit ~/.ssh/config        (add Mac's Tailscale IP)"
echo ""
echo "  Optional:"
echo "  8. ollama pull qwen2.5-coder:32b    (64GB RAM can handle 32B models)"
echo "  9. cat ~/.ssh/id_ed25519.pub  (add to GitHub)"
echo " 10. sudo timeshift --create    (first snapshot)"
echo ""
echo "Log: $LOG_FILE"
echo "Completed: $(date)" >> "$LOG_FILE"
echo -e "${CYAN}Happy vibe coding! 🎶${NC}"
