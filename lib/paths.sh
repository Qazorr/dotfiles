# shellcheck shell=bash
# ~/.local/bin is a stow symlink into this repo, so non-apt tools install to
# ~/.local/share instead and need PATH set by hand. zsh/.zprofile, zsh/.zshrc
# and hypr/conf.d/environment.conf repeat this list; --doctor checks them.
DOTFILES_PATH_DIRS=(
    "$HOME/.local/share/dms/bin"
    "$HOME/.local/share/uv/bin"
    "$HOME/.local/share/krk-commute/bin"
    "$HOME/.local/bin"
)
# shellcheck disable=SC2034  # read by bootstrap.sh
DOTFILES_PATH_PREFIX="$(IFS=:; printf '%s' "${DOTFILES_PATH_DIRS[*]}")"
