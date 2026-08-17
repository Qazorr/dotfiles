# Runs once on login shells. No display manager is installed on purpose
# (see bootstrap.sh) — autostart Hyprland when logging into tty1 with no
# graphical session already running.
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
