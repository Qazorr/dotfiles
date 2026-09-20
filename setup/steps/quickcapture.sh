# shellcheck shell=bash
QUICKCAPTURE_VERSION=v5.1.4

register_step quickcapture \
    --desc "Quick Capture: DMS screenshot/annotation plugin" \
    --group desktop --needs prereqs \
    --provides "$HOME/.config/DankMaterialShell/plugins/quickCapture/plugin.json"

step_quickcapture() {
    local dir="$HOME/.config/DankMaterialShell/plugins/quickCapture"
    if [ -f "$dir/plugin.json" ] \
        && grep -q "\"version\": \"${QUICKCAPTURE_VERSION#v}\"" "$dir/plugin.json" 2>/dev/null; then
        log "Quick Capture $QUICKCAPTURE_VERSION already installed, skipping"
        return 0
    fi

    log "Installing Quick Capture $QUICKCAPTURE_VERSION"
    mkdir -p "$(dirname "$dir")"
    rm -rf "$dir"
    git clone --depth=1 --branch "$QUICKCAPTURE_VERSION" \
        https://github.com/hthienloc/dms-quick-capture "$dir"

    log "Installing the verified Rust capture backend"
    sh "$dir/scripts/install-backend.sh" --version "$QUICKCAPTURE_VERSION"

    dms_enable_plugin quickCapture
}
