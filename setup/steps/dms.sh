# Part of bootstrap.sh — sourced by it, not meant to run standalone.
#
# DMS is the desktop shell: bar, launcher, control centre, notifications,
# polkit agent, wallpaper and matugen theming.
#
# Pinned rather than "latest": DMS moves fast and its QML tracks the CLI's
# API version (the shell logs "Connected (API vNN)" on start). Bump these
# together after testing, not independently.
DMS_VERSION=v1.5.3
DGOP_VERSION=v0.2.3
DSEARCH_VERSION=v0.3.2
MATUGEN_VERSION=v4.2.0

# Not ~/.local/bin: that path is a stow symlink into this repo, so anything
# written there would land in git.
DMS_BIN="$HOME/.local/share/dms/bin"
DMS_QML="$HOME/.config/quickshell/dms"

step_dms() { # DankMaterialShell + dgop, dsearch, matugen
    if [ -x "$DMS_BIN/dms" ] && [ "$("$DMS_BIN/dms" version 2>/dev/null | head -1)" = "dms $DMS_VERSION" ]; then
        log "DankMaterialShell $DMS_VERSION already installed, skipping"
        return 0
    fi

    require_disk_space 2
    log "Installing DankMaterialShell $DMS_VERSION"
    mkdir -p "$DMS_BIN"
    local tmp; tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    # DMS's own tarball isn't a bare binary release (it's a binary plus a
    # whole QML tree that gets copied elsewhere), so it stays hand-written
    # rather than going through install_github_release_binary.
    curl -fsSL -o "$tmp/dms.tar.gz" \
        "https://github.com/AvengeMedia/DankMaterialShell/releases/download/$DMS_VERSION/dms-full-amd64.tar.gz"
    mkdir -p "$tmp/dms" && tar xzf "$tmp/dms.tar.gz" -C "$tmp/dms"
    install -m755 "$tmp/dms/bin/dms" "$DMS_BIN/dms"

    # QML goes to a real directory. Replaced wholesale on upgrade so removed
    # upstream files don't linger; user settings live in
    # ~/.config/DankMaterialShell and are untouched by this.
    mkdir -p "$(dirname "$DMS_QML")"
    rm -rf "$DMS_QML"
    cp -r "$tmp/dms/dms" "$DMS_QML"

    log "Installing dgop (metrics), dsearch (file search), matugen (theming)"
    install_github_release_binary AvengeMedia/dgop "$DGOP_VERSION" \
        dgop-linux-amd64.tar.gz dgop-linux-amd64 "$DMS_BIN/dgop" "$tmp"
    install_github_release_binary AvengeMedia/danksearch "$DSEARCH_VERSION" \
        dsearch-linux-amd64.tar.gz dsearch-linux-amd64 "$DMS_BIN/dsearch" "$tmp"
    install_github_release_binary InioX/matugen "$MATUGEN_VERSION" \
        "matugen-${MATUGEN_VERSION#v}-x86_64.tar.gz" matugen "$DMS_BIN/matugen" "$tmp"
}
