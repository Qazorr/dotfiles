DOTFILES_PATH_DIRS=(
    "$HOME/.local/share/dms/bin"
    "$HOME/.local/share/mise/shims"
    "$HOME/.local/bin"
)
# shellcheck disable=SC2034  # read by bootstrap.sh
DOTFILES_PATH_PREFIX="$(
    IFS=:
    printf '%s' "${DOTFILES_PATH_DIRS[*]}"
)"

# home/zsh/.zprofile, home/zsh/.zshrc and hypr's conf/environment.lua repeat
# this list and can't source this file.

# Every directory under home/ is a stow package.
# shellcheck disable=SC2034  # read by step_stow and dotfiles
STOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../home" && pwd)"
# shellcheck disable=SC2034
STOW_PACKAGES=()
for _d in "$STOW_DIR"/*/; do
    [ -d "$_d" ] && STOW_PACKAGES+=("$(basename "$_d")")
done
unset _d
