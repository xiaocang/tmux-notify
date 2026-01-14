#!/usr/bin/env bash
#
# notify-hook.sh - Pane switch hook handler for tmux-notify
#
# Called by tmux after-select-pane hook to mark notifications as read
# when switching to a pane that has notifications.
#

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

# Get current pane ID
get_current_pane() {
    tmux display-message -p '#{pane_id}'
}

# Main
main() {
    local tn_path
    tn_path=$(get_tn_path)

    local pane
    pane=$(get_current_pane)

    if [[ -n "$pane" ]]; then
        # Mark notifications for this pane as read
        # Run silently in background to not block pane switching
        "$tn_path" -mark-read "$pane" &>/dev/null &
    fi
}

main "$@"
