#!/usr/bin/env bash
#
# notify-popup.sh - Popup notification viewer for tmux-notify
#
# Shows notifications in a tmux popup with fzf for selection.
# Selected notification can be dismissed or its pane can be opened.
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

# Format notification for display
format_notification() {
    local json="$1"

    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required for popup viewer"
        return 1
    fi

    echo "$json" | jq -r '.notifications[] |
        (if .state == "unread" then "*" else " " end) + " " +
        "[" + .pane + "] " +
        .title + ": " + .message +
        "\t" + .pane' 2>/dev/null
}

# Show popup with fzf
show_popup() {
    local binary
    binary=$(get_binary_path)

    if [[ -z "$binary" ]]; then
        tmux display-message "Error: tmux-notify binary not found"
        return 1
    fi

    # Query notifications
    local json
    json=$("$binary" query 2>/dev/null)

    if [[ -z "$json" ]] || [[ "$json" == *'"ok":false'* ]]; then
        tmux display-message "Error querying notifications"
        return 1
    fi

    # Check if there are notifications
    local count
    count=$(echo "$json" | jq '.notifications | length' 2>/dev/null)

    if [[ "$count" == "0" ]] || [[ -z "$count" ]]; then
        tmux display-message "No notifications"
        return 0
    fi

    # Format notifications for fzf
    local formatted
    formatted=$(format_notification "$json")

    if [[ -z "$formatted" ]]; then
        tmux display-message "No notifications"
        return 0
    fi

    # Create temp file with formatted notifications
    local tmpfile
    tmpfile=$(mktemp)
    echo "$formatted" > "$tmpfile"

    # Show fzf popup
    # Actions: Enter = go to pane, Ctrl-D = dismiss
    local selected
    selected=$(tmux popup -E -w 80% -h 60% "cat '$tmpfile' | fzf \
        --ansi \
        --header='Enter: go to pane | Ctrl-D: dismiss | Esc: close' \
        --bind='ctrl-d:execute-silent($binary dismiss {-1})+reload(cat $tmpfile)' \
        --preview-window=hidden")

    rm -f "$tmpfile"

    if [[ -n "$selected" ]]; then
        # Extract pane from selection (format: "* [%5] Title: Message\tPANE")
        local pane
        pane=$(echo "$selected" | grep -o '\[%[0-9]*\]' | tr -d '[]')

        if [[ -n "$pane" ]]; then
            # Switch to the pane
            tmux select-pane -t "$pane" 2>/dev/null || \
                tmux display-message "Pane $pane not found"
        fi
    fi
}

# Main
main() {
    # Check for fzf
    if ! command -v fzf &>/dev/null; then
        tmux display-message "Error: fzf is required for popup viewer"
        return 1
    fi

    show_popup
}

main "$@"
