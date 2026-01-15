# tmux-notify

A tmux plugin for managing notifications with:
- Unread notification count in your tmux status line
- Popup viewer to browse/dismiss notifications
- Automatic mark-as-read when switching to a notification's pane

## Features

- **Status line widget**: Show unread count and latest pane
- **Popup viewer**: Browse/dismiss notifications with `fzf`
- **Auto mark-read**: Mark notifications read on pane switch
- **One notification per pane**: New messages overwrite previous ones

## Requirements

- `tmux` (with popup support for the viewer)
- `tmux-notify` binary (pre-built or compiled from source)
- Optional:
  - `jq` (for popup viewer formatting)
  - `fzf` (required for the popup viewer)

## Installation

### With TPM (Tmux Plugin Manager)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'xiaocang/tmux-notify'
```

Reload tmux config and press `prefix + I` to install.

The binary will be automatically downloaded for your platform (macOS/Linux, x86_64/arm64).

### Building from Source

Requires Rust toolchain:

```bash
cd ~/.tmux/plugins/tmux-notify
cargo build --release
# Binary is at target/release/tmux-notify
```

## Configuration

Place options **before** the plugin line in `~/.tmux.conf`.

| Option | Default | Meaning |
| --- | --- | --- |
| `@notify_popup_key` | *(empty)* | Key (after prefix) to open popup viewer |
| `@notify_mark_read_on_pane_switch` | `on` | `on`/`off` for marking notifications read on pane switch |
| `@notify_retention_hours` | `24` | Hours to keep notifications before auto-cleanup |

Example:

```tmux
set -g @notify_popup_key "n"
set -g @notify_mark_read_on_pane_switch "on"
set -g @notify_retention_hours "24"
```

## Usage

### Status line

Add `#{notify_status}` or `#{notify_count}` to your status line:

```tmux
# Shows: "3 [%5]" (count and latest pane)
set -g status-right "#{notify_status} | %H:%M"

# Shows: "3" (count only)
set -g status-right "#{notify_count} | %H:%M"
```

### CLI

```
$ tmux-notify --help
Notification storage for tmux

Usage: tmux-notify [OPTIONS] <COMMAND>

Commands:
  add        Add or replace a notification for a pane
  query      Query all notifications (JSON output)
  count      Get unread notification count
  mark-read  Mark notification as read for a pane
  dismiss    Dismiss (delete) notification for a pane
  cleanup    Manually cleanup old notifications
  reset      Reset (delete) the entire notification database
  help       Print this message or the help of the given subcommand(s)

Options:
      --db-path <DB_PATH>  Custom database path
  -h, --help               Print help
```

### Popup viewer

Press `prefix + n` (or your configured `@notify_popup_key`):

- **Enter**: Switch to the notification's pane
- **Ctrl-D**: Dismiss the selected notification
- **Esc**: Close popup

## Data Storage

Notifications are stored in SQLite at:
- `$XDG_DATA_HOME/tmux-notify/notifications.db`
- Fallback: `~/.local/share/tmux-notify/notifications.db`

## Integration Examples

Example hook scripts are provided in `examples/` for integrating with AI coding assistants.

### Claude Code

Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": ["~/.tmux/plugins/tmux-notify/examples/claude-code-notify.sh"]
      }
    ]
  }
}
```

### OpenAI Codex

Use `examples/codex-notify.sh` as a hook script for Codex CLI.

## License

MIT
