DOTFILES_PATH_DIRS=(
    "$HOME/.local/share/dms/bin"
    "$HOME/.local/share/uv/bin"
    "$HOME/.local/share/krk-commute/bin"
    "$HOME/.local/share/mise/shims"
    "$HOME/.local/bin"
)
# shellcheck disable=SC2034  # read by bootstrap.sh
DOTFILES_PATH_PREFIX="$(IFS=:; printf '%s' "${DOTFILES_PATH_DIRS[*]}")"

# These repeat DOTFILES_PATH_DIRS and can't source this file; --doctor and CI
# compare them against it.
# shellcheck disable=SC2034
DOTFILES_PATH_FILES=(zsh/.zprofile zsh/.zshrc hypr/.config/hypr/conf.d/environment.conf)

# Every top-level directory holding a dotfile (hypr/.config, zsh/.zshrc).
# shellcheck disable=SC2034  # read by step_stow, --doctor and dotfiles-backup
STOW_PACKAGES=()
for _d in "$(dirname "${BASH_SOURCE[0]}")"/../*/; do
    compgen -G "$_d.[!.]*" >/dev/null && STOW_PACKAGES+=("$(basename "$_d")")
done
unset _d
