# shellcheck shell=bash
DOTFILES_PATH_DIRS=(
    "$HOME/.local/share/dms/bin"
    "$HOME/.local/share/uv/bin"
    "$HOME/.local/share/krk-commute/bin"
    "$HOME/.local/bin"
)
# shellcheck disable=SC2034  # read by bootstrap.sh
DOTFILES_PATH_PREFIX="$(IFS=:; printf '%s' "${DOTFILES_PATH_DIRS[*]}")"

# shellcheck disable=SC2034  # read by step_stow, --doctor and dotfiles-backup
STOW_PACKAGES=(hypr kitty zsh scripts fastfetch cava wallpaper dms vscode)
