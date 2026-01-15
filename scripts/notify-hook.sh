#!/usr/bin/env bash
#
# notify-hook.sh - Pane switch hook handler for tmux-notify
#
# Called by tmux after-select-pane hook to mark notifications as read
# when switching to a pane that has notifications.
#

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the tmux-notify binary path
get_binary_path() {
    local bin_path

    # Check for bundled binary first
    bin_path="${CURRENT_DIR}/../bin/tmux-notify"
    if [[ -x "$bin_path" ]]; then
        echo "$bin_path"
        return
    fi

    # Check for development build
    bin_path="${CURRENT_DIR}/../target/release/tmux-notify"
    if [[ -x "$bin_path" ]]; then
        echo "$bin_path"
        return
    fi

    # Fall back to PATH
    if command -v tmux-notify &>/dev/null; then
        echo "tmux-notify"
        return
    fi

    echo ""
}

# Get current pane ID
get_current_pane() {
    tmux display-message -p '#{pane_id}'
}

# Main
main() {
    local binary
    binary=$(get_binary_path)

    if [[ -z "$binary" ]]; then
        return
    fi

    local pane
    pane=$(get_current_pane)

    if [[ -n "$pane" ]]; then
        # Mark notifications for this pane as read
        # Run silently in background to not block pane switching
        "$binary" mark-read "$pane" &>/dev/null &
    fi
}

main "$@"
