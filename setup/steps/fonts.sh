register_step fonts \
    --desc "JetBrainsMono Nerd Font, for the terminal" \
    --group shell --needs prereqs \
    --provides "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"

step_fonts() {
    # DMS bundles its own fonts; this one is for kitty.
    local dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    if [ -d "$dir" ]; then
        log "JetBrainsMono Nerd Font already installed, skipping"
        return 0
    fi
    log "Installing JetBrainsMono Nerd Font"
    mkdir -p "$dir"
    local zip; zip="$(mktemp --suffix=.zip)"
    curl -L -o "$zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -oq "$zip" -d "$dir"
    rm -f "$zip"
    fc-cache -f "$dir" >/dev/null
}
