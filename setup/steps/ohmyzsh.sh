register_step ohmyzsh \
    --desc "oh-my-zsh, keeping this repo's .zshrc, + autosuggestions/highlighting" \
    --group shell --needs prereqs \
    --provides "$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

step_ohmyzsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "oh-my-zsh already installed, skipping"
    else
        log "Installing oh-my-zsh (unattended, keeping our own .zshrc)"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            "" --unattended --keep-zshrc
    fi

    # Separate repos, unlike the bundled plugins .zshrc also names. Cloned
    # where oh-my-zsh already looks.
    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local name url
    for name in zsh-autosuggestions zsh-syntax-highlighting; do
        url="https://github.com/zsh-users/$name"
        if [ -d "$custom/plugins/$name" ]; then
            git -C "$custom/plugins/$name" pull --ff-only --quiet \
                || warn "$name: git pull failed, using what's already there"
        else
            log "Installing $name"
            git clone --quiet --depth=1 "$url" "$custom/plugins/$name"
        fi
    done
}
