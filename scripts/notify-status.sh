#!/usr/bin/env bash
#
# notify-status.sh - Status line segment for tmux-notify
#
# Usage:
#   notify-status.sh         # Full status: count [pane]
#   notify-status.sh count   # Just the unread count
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

# Query notifications from daemon
query_notifications() {
    local tn_path
    tn_path=$(get_tn_path)

    # Query daemon, suppress errors if not running
    "$tn_path" -query 2>/dev/null
}

# Get unread count
get_unread_count() {
    local json
    json=$(query_notifications)

    if [[ -z "$json" ]] || [[ "$json" == *'"ok":false'* ]]; then
        echo "0"
        return
    fi

    # Count unread notifications using jq if available, otherwise grep
    if command -v jq &>/dev/null; then
        echo "$json" | jq '[.notifications[] | select(.state == "unread")] | length' 2>/dev/null || echo "0"
    else
        # Fallback: count "unread" occurrences
        echo "$json" | grep -o '"state":"unread"' | wc -l | tr -d ' '
    fi
}

# Get latest notification pane
get_latest_pane() {
    local json
    json=$(query_notifications)

    if [[ -z "$json" ]] || [[ "$json" == *'"ok":false'* ]]; then
        echo ""
        return
    fi

    # Get pane of first unread notification (sorted by date desc)
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r '[.notifications[] | select(.state == "unread")] | .[0].pane // empty' 2>/dev/null
    else
        # Fallback: extract first pane value
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
        # No unread notifications - show nothing or minimal indicator
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
