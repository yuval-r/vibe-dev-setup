#!/usr/bin/env bash
#
# 🚀 Vibe Coding Dev Setup — One-Line Installer
#
# Detects your OS and runs the correct setup script.
#
# Usage (run directly from GitHub):
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/yuval-r/vibe-dev-setup/master/install.sh)
#
# With options:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/yuval-r/vibe-dev-setup/master/install.sh) --dry-run
#

set -euo pipefail

REPO="yuval-r/vibe-dev-setup"
BRANCH="master"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🚀 Vibe Coding Dev Setup — One-Line Installer        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

OS="$(uname)"

if [[ "$OS" == "Darwin" ]]; then
    echo -e "${GREEN}[✓]${NC} Detected macOS — downloading mac-setup.sh..."
    SCRIPT_URL="${BASE_URL}/mac-setup.sh"
    SCRIPT_NAME="mac-setup.sh"
elif [[ "$OS" == "Linux" ]]; then
    echo -e "${GREEN}[✓]${NC} Detected Linux — downloading devone-setup.sh..."
    SCRIPT_URL="${BASE_URL}/devone-setup.sh"
    SCRIPT_NAME="devone-setup.sh"
else
    echo -e "${RED}[✗]${NC} Unsupported OS: $OS"
    echo "    This installer supports macOS and Linux (Pop!_OS / Ubuntu)."
    exit 1
fi

# Download to temp location
TMPDIR=$(mktemp -d)
SCRIPT_PATH="${TMPDIR}/${SCRIPT_NAME}"

curl -fsSL "$SCRIPT_URL?nocache=$(date +%s)" -o "$SCRIPT_PATH"

if [[ ! -s "$SCRIPT_PATH" ]]; then
    echo -e "${RED}[✗]${NC} Download failed. Check your internet connection and repo URL."
    echo "    URL: $SCRIPT_URL"
    rm -rf "$TMPDIR"
    exit 1
fi

chmod +x "$SCRIPT_PATH"

echo -e "${GREEN}[✓]${NC} Downloaded ${SCRIPT_NAME}"
echo ""

# Pass through any arguments (--dry-run, --minimal, etc.)
exec bash "$SCRIPT_PATH" "$@"
