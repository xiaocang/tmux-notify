#!/usr/bin/env bash
#
# notify-status.sh - Status line segment for tmux-notify
#
# Usage:
#   notify-status.sh         # Full status: count [pane]
#   notify-status.sh count   # Just the unread count
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

    # Not found
    echo ""
}

# Get unread count
get_unread_count() {
    local binary
    binary=$(get_binary_path)

    if [[ -z "$binary" ]]; then
        echo "0"
        return
    fi

    "$binary" count 2>/dev/null || echo "0"
}

# Get latest notification pane
get_latest_pane() {
    local binary
    binary=$(get_binary_path)

    if [[ -z "$binary" ]]; then
        echo ""
        return
    fi

    local json
    json=$("$binary" query 2>/dev/null)

    if [[ -z "$json" ]]; then
        echo ""
        return
    fi

    # Get pane of first unread notification
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r '[.notifications[] | select(.state == "unread")] | .[0].pane // empty' 2>/dev/null
    else
        # Fallback: extract first pane value from unread notifications
        echo "$json" | grep -o '"pane":"[^"]*"' | head -1 | sed 's/"pane":"//;s/"//'
    fi
}

# Main
main() {
    local mode="${1:-full}"

    if [[ "$mode" == "count" ]]; then
        get_unread_count
        return
    fi

    # Full status mode
    local count
    count=$(get_unread_count)

    if [[ "$count" == "0" ]] || [[ -z "$count" ]]; then
        # No unread notifications - show nothing
        echo ""
        return
    fi

    local pane
    pane=$(get_latest_pane)

    if [[ -n "$pane" ]]; then
        echo "${count} [${pane}]"
    else
        echo "${count}"
    fi
}

main "$@"
