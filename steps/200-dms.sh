# Pinned: the suite releases together, so bump these together.
DMS_VERSION=v2.1.2
DGOP_VERSION=v2.1.1
DSEARCH_VERSION=v2.1.1
MATUGEN_VERSION=v4.2.0

# Outside ~/.local/bin, which is a stow symlink into this repo.
DMS_BIN="$HOME/.local/share/dms/bin"
# The stock UI with dms-shell/ laid over it; autostart.lua runs `dms run -c` on it.
DMS_SHELL="$HOME/.local/share/dms/shell"
DMS_OVERLAY="$REPO/dms-shell"

register_step dms \
    --desc "Dux Modular Shell (DMS) + dgop, dsearch, matugen" \
    --group desktop --needs prereqs quickshell \
    --provides "$HOME/.local/share/dms/bin/dms"

# MediaBody.qml in the mediaGlow plugin is a patched copy of this version's Media widget.
MEDIA_BODY="$REPO/home/dms/.config/dms/plugins/mediaGlow/MediaBody.qml"
check_media_body() {
    grep -q "DMS $DMS_VERSION" "$MEDIA_BODY" \
        || warn "mediaGlow/MediaBody.qml is a copy of another DMS version; re-copy the stock Media.qml and reapply its changes"
}

# Changes whenever the pinned version or any overlay file does.
shell_stamp() {
    {
        echo "$DMS_VERSION"
        find "$DMS_OVERLAY" -type f -exec sha256sum {} + | sort -k2
    } | sha256sum | cut -d' ' -f1
}

build_shell() {
    local stock="$1"
    [ "$(cat "$DMS_OVERLAY/BASE")" = "$DMS_VERSION" ] \
        || warn "dms-shell/ is based on DMS $(cat "$DMS_OVERLAY/BASE"), not $DMS_VERSION; re-copy the stock files and reapply its changes"
    rm -rf "$DMS_SHELL"
    cp -r "$stock" "$DMS_SHELL"
    cp -r "$DMS_OVERLAY"/. "$DMS_SHELL"/
    rm -f "$DMS_SHELL/BASE"
    shell_stamp >"$DMS_SHELL/.overlay-stamp"
}

step_dms() {
    local have_bin=0 have_shell=0
    [ -x "$DMS_BIN/dms" ] && [ "$("$DMS_BIN/dms" version 2>/dev/null | head -1)" = "dms $DMS_VERSION" ] && have_bin=1
    [ "$(cat "$DMS_SHELL/.overlay-stamp" 2>/dev/null)" = "$(shell_stamp)" ] && have_shell=1
    if [ $have_bin = 1 ] && [ $have_shell = 1 ]; then
        log "DMS $DMS_VERSION already installed, skipping"
        check_media_body
        return 0
    fi

    require_disk_space 2
    log "Installing DMS $DMS_VERSION"
    mkdir -p "$DMS_BIN"
    local tmp
    scratch_dir tmp

    curl -fsSL -o "$tmp/dms.tar.gz" \
        "https://github.com/duxlabs-dev/dux-shell/releases/download/$DMS_VERSION/dms-full-amd64.tar.gz"
    mkdir -p "$tmp/dms" && tar xzf "$tmp/dms.tar.gz" -C "$tmp/dms"
    build_shell "$tmp/dms/dms"
    [ $have_bin = 1 ] && {
        check_media_body
        return 0
    }
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

    check_media_body
}
