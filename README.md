# tmux-notify

A tmux plugin for integrating with terminal-notifier's daemon mode. Shows notifications in your tmux status line and automatically marks them as read when you switch to the triggering pane.

## Features

- **Status line widget** - Shows unread notification count and latest pane
- **Popup viewer** - Browse and manage notifications with fzf
- **Auto mark-read** - Notifications marked as read when switching to their pane

## Requirements

- [terminal-notifier](https://github.com/julienXX/terminal-notifier) with daemon mode support
- [TPM](https://github.com/tmux-plugins/tpm) (Tmux Plugin Manager)
- [fzf](https://github.com/junegunn/fzf) (for popup viewer)
- [jq](https://stedolan.github.io/jq/) (recommended, for JSON parsing)

## Installation

### With TPM

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'julienXX/terminal-notifier:tmux-notify'
```

Then press `prefix + I` to install.

### Manual Installation

```bash
git clone https://github.com/julienXX/terminal-notifier.git ~/.tmux/plugins/terminal-notifier
```

Add to `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/terminal-notifier/tmux-notify/notify.tmux
```

## Configuration

Add these to your `~/.tmux.conf` before the plugin line:

```bash
# Path to terminal-notifier (default: "terminal-notifier")
set -g @notify_terminal_notifier_path "/path/to/terminal-notifier"

# Keybinding for popup viewer (default: "n")
set -g @notify_popup_key "n"

# Auto mark-read on pane switch (default: "on")
set -g @notify_mark_read_on_pane_switch "on"
```

## Usage

### Status Line

Add `#{notify_status}` or `#{notify_count}` to your status line:

```bash
# Show count and latest pane: "3 [%5]"
set -g status-right "#{notify_status} | %H:%M"

# Show just the count: "3"
set -g status-right "#{notify_count} | %H:%M"
```

### Sending Notifications

From your scripts or command line:

```bash
# Send notification associated with current pane
terminal-notifier -message "Build complete" -title "CI" -pane "$(tmux display-message -p '#{pane_id}')"
```

### Popup Viewer

Press `prefix + n` (or your configured key) to open the popup viewer:

- **Enter** - Switch to the notification's pane
- **Ctrl-D** - Dismiss the selected notification
- **Esc** - Close popup

### Manual Commands

```bash
# Query all notifications
terminal-notifier -query

# Mark notifications as read for a pane
terminal-notifier -mark-read %5

# Dismiss a notification by ID
terminal-notifier -dismiss <uuid>
```

## How It Works

1. **Send notification**: Your script calls `terminal-notifier -message "..." -pane %X`
2. **Daemon stores it**: The daemon keeps the notification in memory with state "unread"
3. **Status shows count**: `#{notify_status}` shows the unread count
4. **Switch to pane**: When you switch to pane %X, the hook calls `-mark-read %X`
5. **State changes**: The notification state changes to "read" (dimmed in popup)
6. **Dismiss**: Use Ctrl-D in popup or `-dismiss <id>` to remove permanently

## License

MIT
