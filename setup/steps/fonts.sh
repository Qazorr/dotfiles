# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_fonts() { # JetBrainsMono Nerd Font, for the terminal
    # DMS bundles and FontLoader's its own fonts; this one is for kitty.
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
