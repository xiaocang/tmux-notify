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

# Get current window ID
get_current_window() {
    tmux display-message -p '#{window_id}'
}

# Dismiss all notifications for panes in a window
dismiss_window_notifications() {
    local binary="$1"
    local window="$2"

    # Get all pane IDs in the window
    local panes
    panes=$(tmux list-panes -t "$window" -F '#{pane_id}' 2>/dev/null)

    for pane in $panes; do
        "$binary" dismiss "$pane" &>/dev/null
    done
}

# Main
main() {
    local binary
    binary=$(get_binary_path)

    if [[ -z "$binary" ]]; then
        return
    fi

    local current_window
    current_window=$(get_current_window)

    local last_window
    last_window=$(tmux show-option -gqv '@notify_last_window')

    # Check if this is a window switch
    if [[ -n "$last_window" && "$last_window" != "$current_window" ]]; then
        # Dismiss notifications from the previous window (user was already viewing it)
        dismiss_window_notifications "$binary" "$last_window"
    fi

    # Update last window tracker
    tmux set-option -g '@notify_last_window' "$current_window"

    local pane
    pane=$(get_current_pane)

    if [[ -n "$pane" ]]; then
        # Mark notifications for this pane as read
        # Run silently in background to not block pane switching
        "$binary" mark-read "$pane" &>/dev/null &
    fi

    # Run cleanup with configured retention (passive cleanup on pane/window switch)
    local retention
    retention=$(tmux show-option -gqv '@notify_retention_hours')
    retention=${retention:-24}
    "$binary" cleanup --retention "$retention" &>/dev/null &
}

main "$@"
