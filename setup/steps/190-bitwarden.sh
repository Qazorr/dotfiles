BITWARDEN_VERSION=2026.9.0
BITWARDEN_SHA256=51066f8fbaf4546626a2e77a9c0d3abfeef7a13685aca046cb30e07ebf3cf979

register_step bitwarden \
    --desc "Bitwarden desktop, from its GitHub release .deb (no apt repo)" \
    --group apps --root --needs prereqs \
    --provides bitwarden

step_bitwarden() {
    if [ "$(dpkg-query -W -f='${Version}' bitwarden 2>/dev/null)" = "$BITWARDEN_VERSION" ]; then
        log "Bitwarden $BITWARDEN_VERSION already installed, skipping"
        return 0
    fi
    log "Installing Bitwarden $BITWARDEN_VERSION"
    apt_install_deb "https://github.com/bitwarden/clients/releases/download/desktop-v$BITWARDEN_VERSION/Bitwarden-$BITWARDEN_VERSION-amd64.deb" \
        "$BITWARDEN_SHA256"
}
