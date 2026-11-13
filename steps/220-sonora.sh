SONORA_VERSION=0.49.1
SONORA_SHA256=dc253d9cb8eb3bd44bf4e127ff1191cd142bc25bdd15efc287038a409861f9f8
SONORA_DIR="$HOME/.local/lib/sonora"

register_step sonora \
    --desc "Sonora: native music streaming client" \
    --group apps --root --needs prereqs \
    --provides "$SONORA_DIR/sonora"

step_sonora() {
    apt_install libasound2t64 libxkbcommon-x11-0 libsqlite3-0 libvulkan1 libwebkit2gtk-4.1-0

    if [ -x "$SONORA_DIR/sonora" ] \
        && [ "$(cat "$SONORA_DIR/.version" 2>/dev/null)" = "$SONORA_VERSION" ]; then
        log "Sonora $SONORA_VERSION already installed, skipping"
        return 0
    fi

    log "Installing Sonora $SONORA_VERSION"
    local tmp; scratch_dir tmp
    local url=https://github.com/sonorahq/sonora
    curl -fsSL -o "$tmp/sonora" \
        "$url/releases/download/v$SONORA_VERSION/sonora-v$SONORA_VERSION-x86_64-unknown-linux-gnu"
    echo "$SONORA_SHA256  $tmp/sonora" | sha256sum -c --quiet - || die "sonora: checksum mismatch"
    curl -fsSL "$url/archive/refs/tags/v$SONORA_VERSION.tar.gz" | tar -xz -C "$tmp"
    local src="$tmp/sonora-$SONORA_VERSION/assets/linux"

    mkdir -p "$SONORA_DIR"
    install -m755 "$tmp/sonora" "$SONORA_DIR/sonora"

    local share="$HOME/.local/share"
    sed "s|^Exec=sonora|Exec=$SONORA_DIR/sonora|" "$src/sonora.desktop" \
        | install -Dm644 /dev/stdin "$share/applications/sonora.desktop"
    install -Dm644 "$src/sonora.svg" "$share/icons/hicolor/scalable/apps/sonora.svg"
    local icon size
    for icon in "$src"/icons/hicolor/*/apps/sonora.png; do
        size="$(basename "$(dirname "$(dirname "$icon")")")"
        install -Dm644 "$icon" "$share/icons/hicolor/$size/apps/sonora.png"
    done
    update-desktop-database "$share/applications" 2>/dev/null || true

    echo "$SONORA_VERSION" > "$SONORA_DIR/.version"
}
