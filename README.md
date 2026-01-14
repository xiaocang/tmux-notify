# tmux-notify

A tmux plugin that integrates with `terminal-notifier` **daemon mode** to:
- Show unread notification count in your tmux status line
- Open a popup viewer to browse/dismiss notifications
- Automatically mark notifications as read when you switch to the triggering pane

## Features

- **Status line widget**: show unread count (and latest pane)
- **Popup viewer**: browse/dismiss notifications with `fzf`
- **Auto mark-read**: mark notifications read on pane switch

## Requirements

- macOS (uses `terminal-notifier`)
- `tmux`
- `terminal-notifier` with daemon commands (`-query`, `-mark-read`, `-dismiss`)
- Optional (recommended):
  - `jq` (better JSON parsing)
  - `fzf` (required for the popup viewer)

Notes:
- The popup viewer uses `tmux popup`, which needs a recent tmux version.
- If you only use the status counter, `fzf` is not required.

## Installation

### With TPM (Tmux Plugin Manager)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'xiaocang/tmux-notify'
```

Reload tmux config and press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/xiaocang/tmux-notify ~/.tmux/plugins/tmux-notify
```

Add to `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-notify/notify.tmux
```

## Configuration

Place options **before** the plugin line in `~/.tmux.conf`.

### Config reference

| Option | Default | Meaning |
| --- | --- | --- |
| `@notify_terminal_notifier_path` | `terminal-notifier` | Path to `terminal-notifier` binary |
| `@notify_popup_key` | `n` | Key (after prefix) to open popup viewer; set empty to disable |
| `@notify_mark_read_on_pane_switch` | `on` | `on`/`off` for marking notifications read on pane switch |

Example:

```tmux
set -g @notify_terminal_notifier_path "/opt/homebrew/bin/terminal-notifier"
set -g @notify_popup_key "n"
set -g @notify_mark_read_on_pane_switch "on"
```

## Usage

### Status line

Add `#{notify_status}` or `#{notify_count}` to your status line:

```tmux
# Shows: "3 [%5]"
set -g status-right "#{notify_status} | %H:%M"

# Shows: "3"
set -g status-right "#{notify_count} | %H:%M"
```

### Sending notifications

Associate a notification with the current pane:

```bash
terminal-notifier -message "Build complete" -title "CI" -pane "$(tmux display-message -p '#{pane_id}')"
```

### Popup viewer

Press `prefix + n` (or your configured `@notify_popup_key`):

- **Enter**: switch to the notification’s pane
- **Ctrl-D**: dismiss the selected notification
- **Esc**: close popup

## FAQ

### `#{notify_count}` always shows 0
- Ensure your `terminal-notifier` supports daemon commands and `-query` works.
- If you set `@notify_terminal_notifier_path`, confirm the path is correct.
- When `-query` returns `"ok": false`, the daemon is likely not running or not the expected build.

### Popup viewer says `jq` or `fzf` is required
- The popup viewer requires `fzf`.
- The current formatting requires `jq`; install both or disable the popup key: `set -g @notify_popup_key ""`.

### "Pane %X not found"
- The notification points to a pane that no longer exists (window/session closed).

### Popup does not open
- Your tmux may not support `tmux popup`. Upgrade tmux or disable the popup key.

### Disable auto mark-read

```tmux
set -g @notify_mark_read_on_pane_switch "off"
```

## License

MIT
