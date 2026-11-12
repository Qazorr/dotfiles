register_step cli \
    --desc "ripgrep, fd, bat, fzf, zoxide, eza, jq, tmux, direnv, gh, btop, neovim, shellcheck, tldr, xh, hyperfine" \
    --group shell --root \
    --provides rg fdfind batcat fzf zoxide eza btop nvim jq tmux direnv gh shellcheck \
        tldr xh hyperfine

step_cli() {
    log "Installing CLI tooling"
    apt_install \
        ripgrep fd-find bat fzf zoxide eza \
        btop htop git-delta neovim \
        tree unzip jq tmux direnv gh command-not-found \
        shellcheck tealdeer xh hyperfine
}
