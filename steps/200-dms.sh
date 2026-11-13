# Pinned: the suite releases together, so bump these together.
DMS_VERSION=v2.1.2
DGOP_VERSION=v2.1.1
DSEARCH_VERSION=v2.1.1
MATUGEN_VERSION=v4.2.0

# Outside ~/.local/bin, which is a stow symlink into this repo.
DMS_BIN="$HOME/.local/share/dms/bin"

register_step dms \
    --desc "Dux Modular Shell (DMS) + dgop, dsearch, matugen" \
    --group desktop --needs prereqs quickshell \
    --provides "$HOME/.local/share/dms/bin/dms"

step_dms() {
    if [ -x "$DMS_BIN/dms" ] && [ "$("$DMS_BIN/dms" version 2>/dev/null | head -1)" = "dms $DMS_VERSION" ]; then
        log "DMS $DMS_VERSION already installed, skipping"
        return 0
    fi

    require_disk_space 2
    log "Installing DMS $DMS_VERSION"
    mkdir -p "$DMS_BIN"
    local tmp; scratch_dir tmp

    # The UI is embedded in the binary.
    curl -fsSL -o "$tmp/dms.tar.gz" \
        "https://github.com/duxlabs-dev/dux-shell/releases/download/$DMS_VERSION/dms-full-amd64.tar.gz"
    mkdir -p "$tmp/dms" && tar xzf "$tmp/dms.tar.gz" -C "$tmp/dms"
    install -m755 "$tmp/dms/bin/dms" "$DMS_BIN/dms"
    # `dms doctor` reports the version of a QML tree it finds here.
    rm -rf "$HOME/.config/quickshell/dms"

    log "Installing dgop (metrics), dsearch (file search), matugen (theming)"
    install_github_release_binary duxlabs-dev/dux-gop "$DGOP_VERSION" \
        dgop-linux-amd64.tar.gz dgop-linux-amd64 "$DMS_BIN/dgop" "$tmp"
    install_github_release_binary duxlabs-dev/dux-search "$DSEARCH_VERSION" \
        dsearch-linux-amd64.tar.gz dsearch-linux-amd64 "$DMS_BIN/dsearch" "$tmp"
    install_github_release_binary InioX/matugen "$MATUGEN_VERSION" \
        "matugen-${MATUGEN_VERSION#v}-x86_64.tar.gz" matugen "$DMS_BIN/matugen" "$tmp"
}
