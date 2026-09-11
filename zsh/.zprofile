# Login shells only. Hyprland is started by greetd (setup/steps/login.sh), not
# from here — this file only sets up the environment a login inherits.
#
# Keep in sync with lib/paths.sh — ./bootstrap.sh --doctor checks.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/share/uv/bin:$HOME/.local/share/krk-commute/bin:$HOME/.local/bin:$PATH"
