register_step walls \
    --desc "dharmx/walls wallpaper collection, ~3.7GB (opt-in: ./bootstrap.sh walls)" \
    --group personal --optional --needs prereqs \
    --provides "$HOME/.local/share/wallpapers/walls/.git"

WALLS_DIR="$HOME/.local/share/wallpapers/walls"
WALLS_ALL_DIR="$HOME/.local/share/wallpapers/all"

# The DMS wallpaper browser lists one folder without recursing, so flatten the
# category folders into symlinks named <category>_<file>.
link_walls_flat() {
    rm -rf "$WALLS_ALL_DIR"
    mkdir -p "$WALLS_ALL_DIR"
    local f rel
    while IFS= read -r -d '' f; do
        rel="${f#"$WALLS_DIR"/}"
        ln -s "../walls/$rel" "$WALLS_ALL_DIR/${rel//\//_}"
    done < <(find "$WALLS_DIR" -path "$WALLS_DIR/.git" -prune -o -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) \
        -print0)
    log "Linked $(find "$WALLS_ALL_DIR" -type l | wc -l) wallpapers into $WALLS_ALL_DIR"
}

step_walls() {
    if [ -d "$WALLS_DIR/.git" ]; then
        log "Updating dharmx/walls"
        git -C "$WALLS_DIR" pull --ff-only || warn "dharmx/walls: git pull failed, using what's already there"
    else
        require_disk_space 5
        log "Cloning dharmx/walls (~3.7GB, this will take a while)"
        mkdir -p "$(dirname "$WALLS_DIR")"
        git clone --depth=1 https://github.com/dharmx/walls "$WALLS_DIR"
    fi

    link_walls_flat

    if pgrep -x qs >/dev/null 2>&1 && command -v dms >/dev/null 2>&1; then
        local pic
        pic="$(find -L "$WALLS_ALL_DIR" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
            2>/dev/null | sort | head -1 || true)"
        [ -z "$pic" ] || dms ipc call wallpaper set "$pic" >/dev/null 2>&1 || true
    fi
}
