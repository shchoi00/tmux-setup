# tmux-setup

One-shot, idempotent bootstrap that reproduces my tmux environment on a fresh machine.

## Usage

```bash
bash setup-tmux.sh
```

## What it sets up

- Writes `~/.tmux.conf` (backs up any existing one).
- Prefix `C-a` (with `C-b` as a secondary prefix), vim-style pane nav/resize,
  mouse on, 300k scrollback.
- TPM + plugins: tmux-sensible, tmux-resurrect, **tmux-continuum** (auto
  save/restore sessions), tmux-yank, **tmux-fzf**.
- Saves/restores tmux pane contents / scrollback snapshots with tmux-resurrect.
- Adds a real `systemd --user` timer that safely saves tmux-resurrect snapshots
  every 5 minutes, rejects empty/corrupt snapshots, and keeps `last` pointing at
  the newest valid backup.
- Adds `Restart=on-failure` hardening for the user `tmux.service` when present.
- CLI tools into `~/.local/bin`: **fzf** (tmux-fzf) and **yazi** (file explorer,
  `prefix + e`).
- PowerKit status bar (2-line, **text-only / no Nerd Font required**) showing:
  `git · cpu · mem · disk I/O · net speed · disk usage · clock · host`.

Linux x86_64. Re-running is safe.

## Heavy jobs

Keep large training/data jobs out of the tmux service cgroup when possible:

```bash
systemd-run --user --scope --same-dir --unit my-heavy-job bash -lc 'python train.py'
```

This lets systemd-oomd kill the heavy job scope without taking the tmux server
and every pane down with it.
