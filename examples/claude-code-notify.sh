#!/bin/bash
# claude-code-notify.sh
# Hook script for Claude Code: shows notification when input is required
#
# Usage in ~/.claude/settings.json:
# {
#   "hooks": {
#     "PreToolUse": [
#       {
#         "matcher": ".*",
#         "hooks": ["~/.tmux/plugins/tmux-notify/examples/claude-code-notify.sh"]
#       }
#     ]
#   }
# }
#
# Environment variables from Claude Code:
# - CLAUDE_CWD: Current working directory
# - TOOL_NAME: Name of the tool being executed (for tool hooks)
# - SESSION_ID: Session identifier

set -e

# Find tmux-notify binary
find_binary() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check for bundled binary
    if [[ -x "$script_dir/../bin/tmux-notify" ]]; then
        echo "$script_dir/../bin/tmux-notify"
        return
    fi

    # Check for development build
    if [[ -x "$script_dir/../target/release/tmux-notify" ]]; then
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

# Get tmux pane ID
get_pane_id() {
    if [[ -n "$TMUX" ]]; then
        tmux display-message -p '#{pane_id}' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Get tmux window info for display
get_tmux_info() {
    if [[ -n "$TMUX" ]]; then
        local window_index window_name
        window_index=$(tmux display-message -p '#{window_index}' 2>/dev/null)
        window_name=$(tmux display-message -p '#{window_name}' 2>/dev/null)
        if [[ -n "$window_index" && -n "$window_name" ]]; then
            echo "[${window_index}] ${window_name}"
        else
            echo "[tmux]"
        fi
    else
        echo "[terminal]"
    fi
}

# Main
main() {
    local binary
    binary=$(find_binary)

    if [[ -z "$binary" ]]; then
        echo "tmux-notify binary not found" >&2
        exit 0
    fi

    local pane_id
    pane_id=$(get_pane_id)

    if [[ -z "$pane_id" ]]; then
        # Not in tmux, skip notification
        exit 0
    fi

    local tmux_info
    tmux_info=$(get_tmux_info)

    local project_name
    project_name=$(basename "${CLAUDE_CWD:-$(pwd)}")

    local notify_title="Claude Code $tmux_info ($project_name)"
    local notify_message="${TOOL_NAME:-Input required}"

    "$binary" add -t "$notify_title" -m "$notify_message" -p "$pane_id" &>/dev/null || true
}

main "$@"
