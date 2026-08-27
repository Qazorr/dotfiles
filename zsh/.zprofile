# Runs once on login shells. No display manager is installed on purpose
# (see bootstrap.sh) — autostart Hyprland when logging into tty1 with no
# graphical session already running.

# DankMaterialShell's binaries (dms, dgop, dsearch, matugen) and uv (uv, uvx)
# live outside ~/.local/bin on purpose: that path is a stow symlink into the
# dotfiles repo, and anything written there lands in git — which is exactly
# what happened to uv/uvx before this line existed, silently, until noticed
# while installing krk-commute (untracked, never committed, but real).
# This must be set in .zprofile, not .zshrc: a login shell runs .zprofile and
# execs Hyprland from it, so .zshrc never runs and its PATH would be invisible
# to Hyprland's exec-once and keybinds.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/share/uv/bin:$HOME/.local/share/krk-commute/bin:$HOME/.local/bin:$PATH"

if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
