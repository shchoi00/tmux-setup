# tmux-setup

One-shot, idempotent bootstrap that reproduces my tmux environment on a fresh machine.

## Usage

```bash
bash setup-tmux.sh
```

## What it sets up

- Writes `~/.tmux.conf` (backs up any existing one).
- Prefix `C-a` (with `C-b` as a secondary prefix), vim-style pane nav/resize,
  mouse on, 100k scrollback.
- TPM + plugins: tmux-sensible, tmux-resurrect, **tmux-continuum** (auto
  save/restore sessions), tmux-yank, **tmux-fzf**.
- CLI tools into `~/.local/bin`: **fzf** (tmux-fzf) and **yazi** (file explorer,
  `prefix + e`).
- PowerKit status bar (2-line, **text-only / no Nerd Font required**) showing:
  `git · cpu · mem · disk I/O · net speed · disk usage · clock · host`.

Linux x86_64. Re-running is safe.
