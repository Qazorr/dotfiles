# shellcheck shell=bash
register_step walls \
    --desc "dharmx/walls wallpaper collection, ~3.7GB (opt-in: ./bootstrap.sh walls)" \
    --group personal --optional --needs prereqs \
    --provides "$HOME/.local/share/wallpapers/walls/.git"

WALLS_DIR="$HOME/.local/share/wallpapers/walls"

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

    if pgrep -x qs >/dev/null 2>&1 && command -v dms >/dev/null 2>&1; then
        local pic
        pic="$(find -L "$WALLS_DIR" -maxdepth 2 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
            2>/dev/null | sort | head -1)"
        [ -n "$pic" ] && dms ipc call wallpaper set "$pic" >/dev/null 2>&1
    fi
}
