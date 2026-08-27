# Part of bootstrap.sh — sourced by it, not meant to run standalone.
QUICKCAPTURE_VERSION=v5.1.4

step_quickcapture() { # Quick Capture: DMS screenshot/annotation plugin
    local dir="$HOME/.config/DankMaterialShell/plugins/quickCapture"
    if [ -f "$dir/plugin.json" ] \
        && grep -q "\"version\": \"${QUICKCAPTURE_VERSION#v}\"" "$dir/plugin.json" 2>/dev/null; then
        log "Quick Capture $QUICKCAPTURE_VERSION already installed, skipping"
        return 0
    fi

    log "Installing Quick Capture $QUICKCAPTURE_VERSION"
    # Replaced wholesale, matching the DMS QML step: this is upstream plugin
    # code (with its own .git history, docs, Rust source), not vendored into
    # this repo — same reasoning as Quickshell/DMS/hyprmon. What IS tracked
    # is the enablement state, which lives in dms/.config/DankMaterialShell/
    # (plugin_settings.json + settings.json's rightWidgets) and survives this
    # rm -rf untouched since it's a separate stow-managed path.
    mkdir -p "$(dirname "$dir")"
    rm -rf "$dir"
    git clone --depth=1 --branch "$QUICKCAPTURE_VERSION" \
        https://github.com/hthienloc/dms-quick-capture "$dir"

    log "Installing the verified Rust capture backend"
    sh "$dir/scripts/install-backend.sh" --version "$QUICKCAPTURE_VERSION"

    # After a fresh install (not a reinstall) dms needs to discover it before
    # `plugins enable` finds anything to enable. Harmless no-op if dms isn't
    # running yet (e.g. a first bootstrap run, before autostart has fired).
    if pgrep -x qs >/dev/null 2>&1 && command -v dms >/dev/null 2>&1; then
        dms ipc call plugin-scan scan >/dev/null 2>&1 || true
        dms ipc call plugins enable quickCapture >/dev/null 2>&1 || true
    fi
}
