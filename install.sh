#!/bin/sh
# shellcheck shell=dash
# docker-network-extractor installer

set -e

# Some shells don't have `local`. Alias it to `typeset` if needed.
has_local() {
    # shellcheck disable=SC2034
    local _has_local
}
has_local 2>/dev/null || alias local=typeset

VERSION="1.0.0"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="docker-network-extractor"
INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"
ALIAS_NAME="dne"
ALIAS_PATH="$INSTALL_DIR/$ALIAS_NAME"

# GitHub repository URL (update this with your actual repository)
REPO_URL="https://raw.githubusercontent.com/SangHakLee/docker-network-extractor/main"
SCRIPT_URL="$REPO_URL/run.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper functions
check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

need_cmd() {
    if ! check_cmd "$1"; then
        printf "${RED}❌ Error: need '%s' (command not found)${NC}\n" "$1" >&2
        exit 1
    fi
}

say() {
    printf "%s\n" "$1"
}

err() {
    printf "${RED}ERROR${NC}: %s\n" "$1" >&2
    exit 1
}

# Check if running as root for installation
check_root() {
    if [ "$(id -u)" -ne 0 ] && [ ! -w "$INSTALL_DIR" ]; then
        say "$(printf "${YELLOW}⚠️  This script requires sudo privileges to install to $INSTALL_DIR${NC}")"
        say "$(printf "${BLUE}💡 Re-running with sudo...${NC}")"
        exec sudo "$0" "$@"
    fi
}

# Uninstall function
uninstall() {
    say "$(printf "${CYAN}Uninstalling docker-network-extractor...${NC}")"

    local removed=false
    if [ -f "$INSTALL_PATH" ]; then
        rm -f "$INSTALL_PATH"
        say "$(printf "${GREEN}✅ Removed: $INSTALL_PATH${NC}")"
        removed=true
    fi

    if [ -L "$ALIAS_PATH" ] || [ -f "$ALIAS_PATH" ]; then
        rm -f "$ALIAS_PATH"
        say "$(printf "${GREEN}✅ Removed alias: $ALIAS_PATH${NC}")"
        removed=true
    fi

    if [ "$removed" = true ]; then
        say "$(printf "${GREEN}✅ Successfully uninstalled docker-network-extractor${NC}")"
    else
        say "$(printf "${YELLOW}⚠️  docker-network-extractor is not installed${NC}")"
        exit 1
    fi
}

# Install function
install() {
    say "$(printf "${CYAN}Installing docker-network-extractor v${VERSION}...${NC}")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check required commands
    need_cmd curl
    need_cmd mktemp
    need_cmd chmod
    need_cmd mkdir
    need_cmd rm
    need_cmd cp

    # Create temp directory
    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Download the script
    say "$(printf "${BLUE}📥 Downloading script...${NC}")"
    if ! curl -fsSL "$SCRIPT_URL" -o "$TMP_DIR/run.sh"; then
        err "Failed to download script from $SCRIPT_URL"
    fi

    # Verify download
    if [ ! -s "$TMP_DIR/run.sh" ]; then
        err "Downloaded file is empty"
    fi

    # Install to target directory
    say "$(printf "${BLUE}📦 Installing to $INSTALL_PATH...${NC}")"
    cp "$TMP_DIR/run.sh" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    # Create alias symlink
    say "$(printf "${BLUE}🔗 Creating alias '$ALIAS_NAME'...${NC}")"
    ln -sf "$BINARY_NAME" "$ALIAS_PATH"

    # Verify installation
    if [ -x "$INSTALL_PATH" ] && [ -L "$ALIAS_PATH" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        say "$(printf "${GREEN}✅ Successfully installed docker-network-extractor!${NC}")"
        say "$(printf "${GREEN}✅ Alias '$ALIAS_NAME' is now available${NC}")"
        echo ""
        say "$(printf "${YELLOW}Quick Start:${NC}")"
        printf "  ${CYAN}dne${NC}                       # Extract networks\n"
        echo ""
        say "$(printf "${BLUE}💡 You can use either 'dne' or 'docker-network-extractor'${NC}")"
    else
        err "Installation failed"
    fi
}

# Main
main() {
    case "${1:-}" in
        --uninstall|-u)
            check_root "$@"
            uninstall
            ;;
        *)
            check_root "$@"
            install
            ;;
    esac
}

main "$@"