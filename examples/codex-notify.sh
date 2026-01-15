#!/bin/bash
# codex-notify.sh
# Hook script for OpenAI Codex CLI: shows notification when input is required
#
# Supports hooks:
# - session_completed: when session finishes processing
# - input_required: when permission or question needs user input
#
# Environment variables from Codex:
# - SESSION_ID, SESSION_TITLE, PROJECT_DIR, CODEX_CWD
# - INPUT_TYPE (permission_required | question_asked)
# - PERMISSION_NAME (e.g., bash, edit)
# - QUESTION_HEADER (question title)

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
# Walks up the process tree to find the tmux pane
get_tmux_info_by_pid() {
    local start_pid="$1"
    [[ -z "$start_pid" ]] && return 0

    command -v tmux &>/dev/null || return 0

    local pane_info
    pane_info=$(tmux list-panes -a -F "#{pane_pid}|#{window_index}|#{window_name}" 2>/dev/null)
    [[ -z "$pane_info" ]] && return 0

    local current_pid="$start_pid"
    while [[ -n "$current_pid" ]] && [[ "$current_pid" -gt 1 ]]; do
        local match
        match=$(printf '%s\n' "$pane_info" | awk -F'|' -v pid="$current_pid" '$1 == pid {print $2 "|" $3; exit}')
        if [[ -n "$match" ]]; then
            local window_index window_name
            window_index=$(printf '%s' "$match" | cut -d'|' -f1)
            window_name=$(printf '%s' "$match" | cut -d'|' -f2)
            if [[ -n "$window_index" ]] && [[ -n "$window_name" ]]; then
                echo "[${window_index}] ${window_name}"
                return 0
            fi
        fi

        current_pid=$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ')
        [[ -z "$current_pid" ]] && break
    done
}

# Get tmux info string
get_tmux_info() {
    if [[ -n "$TMUX" ]]; then
        local info
        info=$(get_tmux_info_by_pid "${CODEX_PID:-$PPID}")
        if [[ -z "$info" ]]; then
            info="[tmux]"
        fi
        echo "$info"
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
    project_name=$(basename "${PROJECT_DIR:-${CODEX_CWD:-$(pwd)}}")

    local notify_title="Codex $tmux_info ($project_name)"
    local notify_message

    # Build message based on hook type
    if [[ "$INPUT_TYPE" == "permission_required" ]]; then
        notify_message="Permission: ${PERMISSION_NAME:-unknown}"
    elif [[ "$INPUT_TYPE" == "question_asked" ]]; then
        notify_message="Question: ${QUESTION_HEADER:-input needed}"
    else
        # session_completed (no INPUT_TYPE)
        notify_message="${SESSION_TITLE:-Session completed}"
    fi

    # Print to stderr (captured by codex logs)
    echo "$notify_title: $notify_message" >&2

    "$binary" add -t "$notify_title" -m "$notify_message" -p "$pane_id" &>/dev/null || true
}

main "$@"
