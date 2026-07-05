#!/usr/bin/env bash
#
# setup-tmux.sh — reproduce this machine's tmux environment from scratch.
#
# What it does (idempotent — safe to re-run):
#   1. Checks tmux + git are available.
#   2. Writes ~/.tmux.conf (backing up any existing one).
#   3. Clones/updates TPM and tmux-powerkit under ~/.tmux/plugins/.
#   4. Installs the TPM-managed plugins (sensible, resurrect, logging,
#      continuum, yank, fzf).
#   4b. Installs CLI tools the config uses: fzf (tmux-fzf) and yazi (file
#       explorer), as user-level binaries in ~/.local/bin.
#   5. Installs a safe tmux-resurrect systemd user timer.
#   6. Adds tmux.service restart-on-failure hardening when systemd user units exist.
#   7. Reloads the config if a tmux server is already running.
#
# Usage:  bash setup-tmux.sh
#
set -euo pipefail

PLUGIN_DIR="${HOME}/.tmux/plugins"
CONF="${HOME}/.tmux.conf"

log()  { printf '\033[1;32m[setup-tmux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[setup-tmux]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[setup-tmux]\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Prerequisites -------------------------------------------------------
command -v git  >/dev/null 2>&1 || die "git not found. Install git first (e.g. apt-get install -y git)."
if ! command -v tmux >/dev/null 2>&1; then
  warn "tmux not found. Attempting install..."
  if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y tmux
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y tmux
  elif command -v brew    >/dev/null 2>&1; then brew install tmux
  else die "Could not auto-install tmux. Install it manually, then re-run."
  fi
fi
log "tmux $(tmux -V | awk '{print $2}'), git $(git --version | awk '{print $3}')"

# --- 2. Write ~/.tmux.conf --------------------------------------------------
if [ -f "${CONF}" ]; then
  backup="${CONF}.bak.$(date +%Y%m%d%H%M%S)"
  cp "${CONF}" "${backup}"
  log "Backed up existing ~/.tmux.conf -> ${backup}"
fi

cat > "${CONF}" <<'TMUXCONF'
# ~/.tmux.conf

# --- 1. Basic behavior ---
set -g mouse on
set -g history-limit 300000
set -g default-terminal "screen-256color"
set -g status-style bg=black,fg=white
setw -g mode-keys vi
set-option -g allow-rename off

# --- 2. Prefix and core bindings ---
set -g prefix C-a
set -g prefix2 C-b
bind C-a send-prefix
bind C-b send-prefix -2

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

bind c new-window -c "#{pane_current_path}"
bind r source-file ~/.tmux.conf \; display "Reloaded ~/.tmux.conf"

# Open the yazi file explorer in a new window at the current pane's path.
bind e new-window -c "#{pane_current_path}" "yazi"

# --- 3. Vim-style pane navigation and resizing ---
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

bind -n S-Left previous-window
bind -n S-Right next-window

bind-key -n C-S-Left swap-window -t -1
bind-key -n C-S-Right swap-window -t +1

# --- 4. Convenience ---
set -g base-index 1
setw -g pane-base-index 1
set -sg escape-time 0

# Pane title helpers.
bind T if -F "#{==:#{pane-border-status},off}" "setw pane-border-status top" "setw pane-border-status off"
bind t command-prompt -p "(rename-pane)" -I "#T" "select-pane -T '%%'"

# --- 5. TPM and plugins ---
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-logging'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'sainnhe/tmux-fzf'

# Auto-save sessions every 15 min + auto-restore on tmux start (uses resurrect).
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
set -g @continuum-boot 'on'
# Save and restore pane contents / scrollback snapshots.
set -g @resurrect-capture-pane-contents 'on'
# Restore common long-running pane processes after tmux-resurrect reloads panes.
set -g @resurrect-processes '"~node" "~codex" "~omx" "~claude" "~python" "~python3" "~ollama" "bash"'

# PowerKit with Tokyo Night theme.
set -g @powerkit_plugins "git,cpu,memory,iops,netspeed,disk,datetime,hostname"
set -g @powerkit_bar_layout "double"
# Auto-detect the primary (default-route) network interface so netspeed
# works on any machine, not just this one.
run-shell 'tmux set -g @powerkit_plugin_netspeed_interface "$(ip route 2>/dev/null | awk "/^default/{print \$5; exit}")"'
set -g @powerkit_plugin_netspeed_icon "net"
set -g @powerkit_plugin_netspeed_icon_download "↓"
set -g @powerkit_plugin_netspeed_icon_upload "↑"
set -g @powerkit_plugin_iops_icon "io"
set -g @powerkit_plugin_iops_icon_read "↑"
set -g @powerkit_plugin_iops_icon_write "↓"
set -g @powerkit_plugin_cpu_icon "cpu"
set -g @powerkit_plugin_memory_icon "mem"
set -g @powerkit_plugin_disk_icon "disk"
set -g @powerkit_plugin_git_icon "git"
set -g @powerkit_plugin_git_icon_modified "git"
set -g @powerkit_plugin_datetime_icon " "
set -g @powerkit_plugin_hostname_icon " "
set -g @powerkit_session_icon " "
set -g @powerkit_session_prefix_icon "^A"
set -g @powerkit_active_window_icon " "
set -g @powerkit_inactive_window_icon " "
set -g @powerkit_window_default_icon " "
set -g @powerkit_theme "tokyo-night"
set -g @powerkit_theme_variant "night"
set -g @powerkit_separator_style "none"
set -g @powerkit_icon_padding "0"
set -g @powerkit_session_show_mode "false"
set -g @powerkit_edge_separator_style "none"
set -g @powerkit_initial_separator_style "none"
set -g @powerkit_active_window_show_index "false"
set -g @powerkit_inactive_window_show_index "false"
set -g @powerkit_active_window_title "#I:#W"
set -g @powerkit_inactive_window_title "#I:#W"
set -g @powerkit_elements_spacing "both"
set -g @powerkit_status_interval "5"
run-shell '~/.tmux/plugins/tmux-powerkit/tmux-powerkit.tmux'

# TPM initialization. Keep this at the bottom.
run '~/.tmux/plugins/tpm/tpm'
TMUXCONF
log "Wrote ~/.tmux.conf"

# --- 3. Clone / update plugins ---------------------------------------------
mkdir -p "${PLUGIN_DIR}"

clone_or_update() {
  local url="$1" dest="$2"
  if [ -d "${dest}/.git" ]; then
    log "Updating ${dest##*/}"
    git -C "${dest}" pull --ff-only --quiet || warn "Could not fast-forward ${dest##*/} (left as-is)."
  else
    log "Cloning ${dest##*/}"
    git clone --depth 1 --quiet "${url}" "${dest}"
  fi
}

# TPM (manages the @plugin entries above) and PowerKit (loaded via run-shell).
clone_or_update "https://github.com/tmux-plugins/tpm"            "${PLUGIN_DIR}/tpm"
clone_or_update "https://github.com/fabioluciano/tmux-powerkit.git" "${PLUGIN_DIR}/tmux-powerkit"

# --- 4. Install TPM-managed plugins ----------------------------------------
# install_plugins reads the @plugin lines from ~/.tmux.conf and clones any
# that are missing (tmux-sensible, tmux-resurrect, tmux-logging).
if [ -x "${PLUGIN_DIR}/tpm/bin/install_plugins" ]; then
  log "Installing TPM plugins..."
  "${PLUGIN_DIR}/tpm/bin/install_plugins" || warn "TPM plugin install reported an issue."
fi

# --- 4b. CLI tools the config relies on (Linux x86_64) ----------------------
# fzf powers tmux-fzf (prefix+F); yazi is the file explorer (prefix+e).
# Both install as user-level binaries into ~/.local/bin (no sudo, no rc edits).
mkdir -p "${HOME}/.local/bin"
if ! command -v fzf >/dev/null 2>&1 && [ ! -x "${HOME}/.local/bin/fzf" ]; then
  log "Installing fzf (binary)"
  [ -d "${HOME}/.fzf" ] || git clone --depth 1 --quiet https://github.com/junegunn/fzf "${HOME}/.fzf"
  "${HOME}/.fzf/install" --bin >/dev/null 2>&1 && ln -sf "${HOME}/.fzf/bin/fzf" "${HOME}/.local/bin/fzf"
fi
if ! command -v yazi >/dev/null 2>&1 && [ ! -x "${HOME}/.local/bin/yazi" ]; then
  if [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ]; then
    log "Installing yazi (file explorer)"
    _tmp="$(mktemp -d)"
    if curl -fsSL -o "${_tmp}/yazi.zip" \
         "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip"; then
      unzip -oq "${_tmp}/yazi.zip" -d "${_tmp}"
      find "${_tmp}" -type f -name yazi -exec install -m755 {} "${HOME}/.local/bin/yazi" \;
      find "${_tmp}" -type f -name ya   -exec install -m755 {} "${HOME}/.local/bin/ya" \;
    else
      warn "Could not download yazi (offline?); 'prefix + e' stays inert until installed."
    fi
    rm -rf "${_tmp}"
  else
    warn "yazi auto-install only wired for Linux x86_64; install manually for this platform."
  fi
fi

# --- 5. Safe tmux-resurrect timer ------------------------------------------
# tmux-continuum normally saves from the tmux status line. That is convenient,
# but fragile: if systemd-oomd kills the tmux server first, the final save can
# produce an empty snapshot and move the `last` symlink to that corrupt file.
# This wrapper runs from a real systemd user timer and refuses invalid snapshots.
SAFE_SAVE_BIN="${HOME}/.local/bin/tmux-resurrect-safe-save"
mkdir -p "${HOME}/.local/bin" "${HOME}/.config/systemd/user" "${HOME}/.config/systemd/user/tmux.service.d"
cat > "${SAFE_SAVE_BIN}" <<'SAFESAVE'
#!/usr/bin/env bash
set -u

resurrect_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
save_script="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
log_file="$resurrect_dir/safe-save.log"
last_link="$resurrect_dir/last"

mkdir -p "$resurrect_dir"
log() { printf '%s %s\n' "$(date -Is)" "$*" >> "$log_file"; }

is_valid_snapshot() {
  local file="$1"
  [ -s "$file" ] || return 1
  grep -q $'^pane\t' "$file" || return 1
  grep -q $'^window\t' "$file" || return 1
}

best_valid_snapshot_basename() {
  find "$resurrect_dir" -maxdepth 1 -type f -name 'tmux_resurrect_*.txt' -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn \
    | while read -r _ file; do
        if is_valid_snapshot "$file"; then
          basename "$file"
          return 0
        fi
      done
}

if ! tmux has-session >/dev/null 2>&1; then
  log "skip: no tmux server"
  exit 0
fi

prev=""
if [ -L "$last_link" ]; then
  prev="$(readlink "$last_link" || true)"
fi

if [ ! -x "$save_script" ]; then
  log "error: save script missing: $save_script"
  exit 1
fi

"$save_script" quiet >/dev/null 2>&1 || true

new=""
if [ -L "$last_link" ]; then
  new="$(readlink "$last_link" || true)"
fi
new_file="$resurrect_dir/$new"

if [ -n "$new" ] && is_valid_snapshot "$new_file"; then
  log "saved: $new"
  exit 0
fi

fallback=""
if [ -n "$prev" ] && is_valid_snapshot "$resurrect_dir/$prev"; then
  fallback="$prev"
else
  fallback="$(best_valid_snapshot_basename || true)"
fi

if [ -n "$fallback" ]; then
  ln -sfn "$fallback" "$last_link"
  log "invalid snapshot '${new:-<none>}' rejected; restored last -> $fallback"
  exit 1
fi

log "error: invalid snapshot '${new:-<none>}' and no valid fallback"
exit 1
SAFESAVE
chmod +x "${SAFE_SAVE_BIN}"

cat > "${HOME}/.config/systemd/user/tmux-resurrect-safe-save.service" <<'UNIT'
[Unit]
Description=Safely save tmux-resurrect snapshot

[Service]
Type=oneshot
ExecStart=%h/.local/bin/tmux-resurrect-safe-save
UNIT

cat > "${HOME}/.config/systemd/user/tmux-resurrect-safe-save.timer" <<'UNIT'
[Unit]
Description=Run safe tmux-resurrect snapshot periodically

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s
Persistent=true
Unit=tmux-resurrect-safe-save.service

[Install]
WantedBy=timers.target
UNIT

cat > "${HOME}/.config/systemd/user/tmux.service.d/restart.conf" <<'UNIT'
[Service]
Restart=on-failure
RestartSec=2
UNIT

if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload || warn "systemd user daemon-reload failed."
  systemctl --user enable --now tmux-resurrect-safe-save.timer || warn "Could not enable safe save timer."
  systemctl --user reset-failed tmux.service >/dev/null 2>&1 || true
  log "Installed safe tmux-resurrect systemd timer and tmux.service restart hardening."
else
  warn "systemd --user is unavailable; safe-save script was installed but timer was not enabled."
fi

# --- 7. Reload if a server is running --------------------------------------
if tmux info >/dev/null 2>&1; then
  tmux source-file "${CONF}" && log "Reloaded config into the running tmux server."
else
  log "No running tmux server — config applies on next 'tmux'."
fi

log "Done. Start tmux and press 'Ctrl-a I' once if any plugin looks missing."
