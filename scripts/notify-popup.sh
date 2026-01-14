#!/usr/bin/env bash
#
# notify-popup.sh - Popup notification viewer for tmux-notify
#
# Shows notifications in a tmux popup with fzf for selection.
# Selected notification can be dismissed or its pane can be opened.
#

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get terminal-notifier path from tmux option or use default
get_tn_path() {
    local path
    path=$(tmux show-option -gqv "@notify_terminal_notifier_path" 2>/dev/null)
    if [[ -z "$path" ]]; then
        echo "terminal-notifier"
    else
        echo "$path"
    fi
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
        "\t" + .identifier' 2>/dev/null
}

# Show popup with fzf
show_popup() {
    local tn_path
    tn_path=$(get_tn_path)

    # Query notifications
    local json
    json=$("$tn_path" -query 2>/dev/null)

    if [[ -z "$json" ]] || [[ "$json" == *'"ok":false'* ]]; then
        tmux display-message "No notifications (daemon not running)"
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
        --bind='ctrl-d:execute-silent($tn_path -dismiss {-1})+reload(cat $tmpfile)' \
        --preview-window=hidden")

    rm -f "$tmpfile"

    if [[ -n "$selected" ]]; then
        # Extract pane from selection (format: "* [%5] Title: Message\tID")
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
