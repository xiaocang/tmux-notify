#!/usr/bin/env bash
#
# install.sh - Download the correct tmux-notify binary for this platform
#
# Called by notify.tmux on first run or when binary is missing.
#

set -e

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$CURRENT_DIR")"
BIN_DIR="$PLUGIN_DIR/bin"
BINARY_PATH="$BIN_DIR/tmux-notify"

REPO="xiaocang/tmux-notify"
VERSION="v0.1.1"

# Detect OS and architecture
detect_platform() {
    local os arch

    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    # Normalize OS
    case "$os" in
        darwin) os="apple-darwin" ;;
        linux)  os="unknown-linux-gnu" ;;
        *)
            echo "Unsupported OS: $os" >&2
            return 1
            ;;
    esac

    # Normalize architecture
    case "$arch" in
        x86_64|amd64)   arch="x86_64" ;;
        aarch64|arm64)  arch="aarch64" ;;
        *)
            echo "Unsupported architecture: $arch" >&2
            return 1
            ;;
    esac

    echo "${arch}-${os}"
}


# Download and install binary
install_binary() {
    local platform="$1"
    local version="$2"

    local filename="tmux-notify-${platform}.tar.gz"
    local url="https://github.com/$REPO/releases/download/${version}/${filename}"

    echo "Downloading tmux-notify ${version} for ${platform}..."

    mkdir -p "$BIN_DIR"

    if command -v curl &>/dev/null; then
        curl -sL "$url" | tar -xz -C "$BIN_DIR"
    elif command -v wget &>/dev/null; then
        wget -qO- "$url" | tar -xz -C "$BIN_DIR"
    else
        echo "Error: curl or wget required" >&2
        return 1
    fi

    chmod +x "$BINARY_PATH"
    echo "Installed tmux-notify to $BINARY_PATH"
}

# Main
main() {
    # Skip if binary already exists
    if [[ -x "$BINARY_PATH" ]]; then
        exit 0
    fi

    # Skip if development build exists
    if [[ -x "$PLUGIN_DIR/target/release/tmux-notify" ]]; then
        exit 0
    fi

    local platform
    platform=$(detect_platform) || exit 1

    install_binary "$platform" "$VERSION"
}

main "$@"
