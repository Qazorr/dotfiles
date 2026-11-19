GALAXYBUDS_VERSION=5.2.1
GALAXYBUDS_DIR="$HOME/.local/share/galaxybudsclient"

register_step galaxybuds \
    --desc "GalaxyBudsClient: Galaxy Buds manager behind the DMS galaxyBuds plugin" \
    --group apps --needs prereqs \
    --provides "$GALAXYBUDS_DIR/GalaxyBudsClient"

step_galaxybuds() {
    if [ -x "$GALAXYBUDS_DIR/GalaxyBudsClient" ] \
        && [ "$(cat "$GALAXYBUDS_DIR/.version" 2>/dev/null)" = "$GALAXYBUDS_VERSION" ]; then
        log "GalaxyBudsClient $GALAXYBUDS_VERSION already installed, skipping"
        return 0
    fi

    log "Installing GalaxyBudsClient $GALAXYBUDS_VERSION"
    local tmp
    scratch_dir tmp
    curl -fsSL -o "$tmp/gbc.zip" \
        "https://github.com/timschneeb/GalaxyBudsClient/releases/download/$GALAXYBUDS_VERSION/GalaxyBudsClient_linux-amd64_portable.zip"
    unzip -q "$tmp/gbc.zip" -d "$tmp/gbc"

    local bin
    bin="$(find "$tmp/gbc" -type f -name GalaxyBudsClient | head -1)"
    [ -n "$bin" ] || die "GalaxyBudsClient binary not found in the release zip"

    rm -rf "$GALAXYBUDS_DIR"
    mkdir -p "$GALAXYBUDS_DIR"
    cp -a "$(dirname "$bin")/." "$GALAXYBUDS_DIR/"
    chmod +x "$GALAXYBUDS_DIR/GalaxyBudsClient"
    echo "$GALAXYBUDS_VERSION" >"$GALAXYBUDS_DIR/.version"

    dms_enable_plugin galaxyBuds
}
