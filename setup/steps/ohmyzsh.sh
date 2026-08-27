# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_ohmyzsh() { # oh-my-zsh, keeping this repo's .zshrc
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "oh-my-zsh already installed, skipping"
        return 0
    fi
    log "Installing oh-my-zsh (unattended, keeping our own .zshrc)"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc
}
