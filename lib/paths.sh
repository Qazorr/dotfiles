# The PATH directories this setup adds.
#
# ~/.local/bin is a stow symlink into this repo, so anything installing there
# writes into git. Non-apt tools go under ~/.local/share instead, which then
# needs adding to PATH by hand.
#
# zsh/.zprofile, zsh/.zshrc and hypr/conf.d/environment.conf repeat this list
# literally and can't source it; --doctor checks all three against this one.
DOTFILES_PATH_DIRS=(
    "$HOME/.local/share/dms/bin"
    "$HOME/.local/share/uv/bin"
    "$HOME/.local/share/krk-commute/bin"
    "$HOME/.local/bin"
)
DOTFILES_PATH_PREFIX="$(IFS=:; printf '%s' "${DOTFILES_PATH_DIRS[*]}")"
