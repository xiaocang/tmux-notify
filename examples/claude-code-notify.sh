#!/bin/bash
# ABOUTME: Claude Code notification hook - integrates with tmux-notify
#
# Usage in ~/.claude/settings.json:
# {
#   "hooks": {
#     "Notification": [
#       {
#         "matcher": "",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "/path/to/this/claude-code-notify.sh"
#           }
#         ]
#       }
#     ],
#     "Stop": [
#       {
#         "matcher": "",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "/path/to/this/claude-code-notify.sh"
#           }
#         ]
#       }
#     ]
#   }
# }
#
# The hook receives JSON via stdin with notification details.
# It walks up the process tree to find the correct tmux pane.

# Find tmux pane ID and window info by walking up the process tree
# Sets: PANE_ID, WINDOW_INDEX
get_tmux_info() {
    PANE_ID=""
    WINDOW_INDEX=""

    if [ -z "$TMUX" ]; then
        return
    fi

    # Get all pane PIDs with pane ID and window index
    local pane_info
    pane_info=$(tmux list-panes -a -F "#{pane_pid}|#{pane_id}|#{window_index}" 2>/dev/null)

    if [ -z "$pane_info" ]; then
        return
    fi

    # Walk up the process tree from current PID to find matching pane
    local current_pid=$$
    while [ "$current_pid" -gt 1 ]; do
        local match
        match=$(echo "$pane_info" | awk -F'|' -v pid="$current_pid" '$1 == pid {print $2 "|" $3; exit}')
        if [ -n "$match" ]; then
            PANE_ID=$(echo "$match" | cut -d'|' -f1)
            WINDOW_INDEX=$(echo "$match" | cut -d'|' -f2)
            return
        fi

        # Get parent PID
        current_pid=$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ')
        if [ -z "$current_pid" ]; then
            break
        fi
    done
}

# Find tmux-notify binary
find_binary() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check for bundled binary (TPM install)
    if [ -x "$script_dir/../bin/tmux-notify" ]; then
        echo "$script_dir/../bin/tmux-notify"
        return
    fi

    # Check for development build
    if [ -x "$script_dir/../target/release/tmux-notify" ]; then
        echo "$script_dir/../target/release/tmux-notify"
        return
    fi

    # Fall back to PATH
    if command -v tmux-notify &>/dev/null; then
        echo "tmux-notify"
        return
    fi

    echo ""
}

# Read notification data from stdin
NOTIFICATION_JSON=$(cat)

# Extract message from JSON
if printf '%s' "$NOTIFICATION_JSON" | jq . >/dev/null 2>&1; then
    EXTRACTED=$(printf '%s' "$NOTIFICATION_JSON" | jq -r '.notification.message // .tool_input.message // empty' 2>/dev/null)
    if [ -n "$EXTRACTED" ] && [ "$EXTRACTED" != "null" ]; then
        MESSAGE=$(printf '%s' "$EXTRACTED" | head -c 200)
    else
        MESSAGE="Task completed"
    fi
else
    MESSAGE="Claude Code notification"
fi

# Get tmux info (sets PANE_ID and WINDOW_INDEX)
get_tmux_info

if [ -n "$PANE_ID" ]; then
    NOTIFY_BIN=$(find_binary)

    if [ -n "$NOTIFY_BIN" ]; then
        # Get current count before adding (new notification will make it +1)
        CURRENT_COUNT=$("$NOTIFY_BIN" count 2>/dev/null || echo "0")
        TOTAL_COUNT=$((CURRENT_COUNT + 1))

        # Build title: N:{window_index} T:{total_count}
        TITLE="N:${WINDOW_INDEX:-?} T:${TOTAL_COUNT}"

        # Add notification
        "$NOTIFY_BIN" add -t "$TITLE" -m "$MESSAGE" -p "$PANE_ID" 2>/dev/null
    fi
fi

# Always continue
echo '{"continue":true}'
