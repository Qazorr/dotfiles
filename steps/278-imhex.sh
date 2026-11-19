IMHEX_BIN="$HOME/.local/bin/ImHex.AppImage"

# The .deb on the releases page is built for Ubuntu (libmbedtls14, which Debian
# 13 doesn't have), so the AppImage is the upstream build that runs here.
register_step imhex \
    --desc "ImHex hex editor: latest upstream AppImage in ~/.local/bin" \
    --group apps --root --needs prereqs \
    --provides "$IMHEX_BIN"

# Prints the newest release tag. /releases/latest redirects to
# /releases/tag/<tag>, so there's no API rate limit to hit.
imhex_latest_tag() {
    local url
    url="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        https://github.com/WerWolv/ImHex/releases/latest)" || return 1
    printf '%s\n' "${url##*/}"
}

imhex_install_appimage() { # imhex_install_appimage <tag>
    local tag="$1" ver="${1#v}"
    if [ -x "$IMHEX_BIN" ] && [ "$(cat "$IMHEX_BIN.version" 2>/dev/null)" = "$ver" ]; then
        log "ImHex $ver already installed, skipping"
        return 0
    fi
    log "Installing ImHex $ver"
    apt_install libfuse2t64 # the AppImage mounts itself with it
    mkdir -p "${IMHEX_BIN%/*}"
    curl -fsSL -o "$IMHEX_BIN.new" \
        "https://github.com/WerWolv/ImHex/releases/download/$tag/imhex-$ver-x86_64.AppImage"
    chmod +x "$IMHEX_BIN.new"
    mv "$IMHEX_BIN.new" "$IMHEX_BIN"
    echo "$ver" >"$IMHEX_BIN.version"
}

# The AppImage carries its own launcher and icon; point its Exec at the file.
# --appimage-extract needs no FUSE.
imhex_install_launcher() {
    local tmp icons="$HOME/.local/share/icons/hicolor/scalable/apps"
    local apps="$HOME/.local/share/applications"
    scratch_dir tmp
    (cd "$tmp" && "$IMHEX_BIN" --appimage-extract imhex.desktop \
        && "$IMHEX_BIN" --appimage-extract imhex.svg) >/dev/null
    mkdir -p "$icons" "$apps"
    install -m644 "$tmp/squashfs-root/imhex.svg" "$icons/imhex.svg"
    sed "s|^Exec=imhex|Exec=$IMHEX_BIN|" "$tmp/squashfs-root/imhex.desktop" \
        >"$apps/imhex.desktop"
}

step_imhex() {
    local tag
    tag="$(imhex_latest_tag)" || die "couldn't work out the latest ImHex release"
    imhex_install_appimage "$tag"
    imhex_install_launcher
}
