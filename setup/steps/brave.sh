# shellcheck shell=bash
register_step brave \
    --desc "Brave, from its own apt repo" \
    --group apps --root --needs prereqs \
    --provides brave-browser

step_brave() {
    local key=/usr/share/keyrings/brave-browser-archive-keyring.gpg
    if [ ! -f "$key" ]; then
        log "Adding Brave's apt repo"
        sudo curl -fsSLo "$key" \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    fi
    # Brave's documented method is a whole pre-written deb822 .sources file,
    # not ensure_apt_list's single .list line. Verified 2026-08-27.
    if [ ! -f /etc/apt/sources.list.d/brave-browser-release.sources ]; then
        sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
            https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
        apt_update
    fi
    log "Installing Brave"
    apt_install brave-browser
}
