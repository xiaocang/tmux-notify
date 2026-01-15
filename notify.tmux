#!/usr/bin/env bash
#
# tmux-notify - TPM plugin for notification management
#
# This plugin provides:
# - Status line widget showing unread notification count
# - Keybinding to show notification popup
# - Auto mark-read when switching panes
#

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default options
default_popup_key=""
default_mark_read_on_pane_switch="on"
default_retention_hours="24"

# Get tmux option with default
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    if [[ -z "$option_value" ]]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Set up format strings for status line
setup_notify_interpolation() {
    local notify_status_interpolation="\#{notify_status}"
    local notify_count_interpolation="\#{notify_count}"

    # Update status-right if it contains our interpolation strings
    local status_right
    status_right=$(tmux show-option -gqv "status-right")

    if [[ "$status_right" == *"#{notify_status}"* ]] || [[ "$status_right" == *"#{notify_count}"* ]]; then
        # Replace #{notify_status} with script call
        status_right="${status_right//\#\{notify_status\}/#($CURRENT_DIR/scripts/notify-status.sh)}"
        status_right="${status_right//\#\{notify_count\}/#($CURRENT_DIR/scripts/notify-status.sh count)}"
        tmux set-option -g "status-right" "$status_right"
    fi
}

# Set up keybinding for popup
setup_popup_keybinding() {
    local popup_key
    popup_key=$(get_tmux_option "@notify_popup_key" "$default_popup_key")

    if [[ -n "$popup_key" ]]; then
        tmux bind-key "$popup_key" run-shell "$CURRENT_DIR/scripts/notify-popup.sh"
    fi
}

# Set up pane/window switch hooks for auto mark-read
setup_pane_switch_hook() {
    local mark_read_on_switch
    mark_read_on_switch=$(get_tmux_option "@notify_mark_read_on_pane_switch" "$default_mark_read_on_pane_switch")

    if [[ "$mark_read_on_switch" == "on" ]]; then
        tmux set-hook -g after-select-pane "run-shell '$CURRENT_DIR/scripts/notify-hook.sh'"
        tmux set-hook -g after-select-window "run-shell '$CURRENT_DIR/scripts/notify-hook.sh'"
    fi
}

# Ensure binary is installed
ensure_binary_installed() {
    "$CURRENT_DIR/scripts/install.sh" 2>/dev/null || true
}

# Main setup
main() {
    ensure_binary_installed
    setup_notify_interpolation
    setup_popup_keybinding
    setup_pane_switch_hook
}

main
