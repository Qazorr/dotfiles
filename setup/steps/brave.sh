# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_brave() { # Brave, from its own apt repo
    local key=/usr/share/keyrings/brave-browser-archive-keyring.gpg
    if [ ! -f "$key" ]; then
        log "Adding Brave's apt repo"
        sudo curl -fsSLo "$key" \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    fi
    # Brave's own documented method: a deb822 .sources file fetched directly,
    # not hand-built — verified against https://brave.com/linux/ 2026-08-27.
    # Different enough from ensure_apt_list's single-line .list shape (this
    # fetches a whole pre-written file) that it stays hand-written here.
    if [ ! -f /etc/apt/sources.list.d/brave-browser-release.sources ]; then
        sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
            https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
        sudo apt update
    fi
    log "Installing Brave"
    apt_install brave-browser
}
