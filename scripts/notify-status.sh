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

# Cache file for daemon support check
CACHE_FILE="${TMPDIR:-/tmp}/.tmux-notify-daemon-check"

# Check if terminal-notifier supports daemon mode
# Returns 0 if patched version, 1 if standard version
# Result is cached to avoid repeated timeout delays
is_daemon_supported() {
    local tn_path
    tn_path=$(get_tn_path)

    # Check cache first (valid for current session)
    if [[ -f "$CACHE_FILE" ]]; then
        local cached_path cached_result
        read -r cached_path cached_result < "$CACHE_FILE"
        if [[ "$cached_path" == "$tn_path" ]]; then
            return "$cached_result"
        fi
    fi

    # Use timeout to detect standard version (hangs on -query)
    # Patched version returns JSON immediately
    local result
    result=$(timeout 1 "$tn_path" -query 2>/dev/null)
    local exit_code=$?

    # timeout returns 124 if command times out
    if [[ $exit_code -eq 124 ]]; then
        echo "$tn_path 1" > "$CACHE_FILE"
        return 1
    fi

    # Check if we got valid JSON response (patched version)
    if [[ "$result" == *'"ok":'* ]]; then
        echo "$tn_path 0" > "$CACHE_FILE"
        return 0
    fi

    echo "$tn_path 1" > "$CACHE_FILE"
    return 1
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

    # Check if terminal-notifier supports daemon mode
    if ! is_daemon_supported; then
        echo ""
        return
    fi

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
