# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_cli() { # ripgrep, fd, bat, fzf, zoxide, eza, btop, neovim…
    log "Installing CLI tooling"
    # Debian renames two of these: fd-find installs `fdfind` and bat installs
    # `batcat`, both to avoid clashing with older packages. zsh/.zshrc aliases
    # them back to `fd` and `bat`.
    apt_install \
        ripgrep fd-find bat fzf zoxide eza \
        btop htop git-delta neovim \
        tree unzip
}
