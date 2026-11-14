VESKTOP_VERSION=1.6.9
VESKTOP_SHA256=8487a3ba56c7cd0bb230c1d6b42373fa0a8a23bab6f0809c903988b4f3e9cefc

register_step vesktop \
    --desc "Vesktop (Discord), from its GitHub release .deb (no apt repo)" \
    --group apps --root --needs prereqs \
    --provides vesktop

step_vesktop() {
    if [ "$(dpkg-query -W -f='${Version}' vesktop 2>/dev/null)" = "$VESKTOP_VERSION" ]; then
        log "Vesktop $VESKTOP_VERSION already installed, skipping"
        return 0
    fi
    log "Installing Vesktop $VESKTOP_VERSION"
    apt_install_deb "https://github.com/Vencord/Vesktop/releases/download/v$VESKTOP_VERSION/vesktop_${VESKTOP_VERSION}_amd64.deb" \
        "$VESKTOP_SHA256"
}
