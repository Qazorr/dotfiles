# Login shells only. No display manager is installed on purpose, so Hyprland
# starts from a tty1 login below.

# Has to be here rather than .zshrc: a login shell execs Hyprland from this
# file, so .zshrc never runs and its PATH would be invisible to Hyprland.
# Keep in sync with lib/paths.sh — ./bootstrap.sh --doctor checks.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/share/uv/bin:$HOME/.local/share/krk-commute/bin:$HOME/.local/bin:$PATH"

if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
