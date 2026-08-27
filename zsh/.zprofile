# Runs once on login shells. No display manager is installed on purpose
# (see bootstrap.sh) — autostart Hyprland when logging into tty1 with no
# graphical session already running.

# DankMaterialShell's binaries (dms, dgop, dsearch, matugen) live here rather
# than ~/.local/bin, because that path is a stow symlink into the dotfiles
# repo and anything written there would land in git.
# This must be set in .zprofile, not .zshrc: a login shell runs .zprofile and
# execs Hyprland from it, so .zshrc never runs and its PATH would be invisible
# to Hyprland's exec-once and keybinds.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/bin:$PATH"

if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
