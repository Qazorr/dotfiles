# shellcheck shell=bash
# dharmx/walls: a personal wallpaper collection, ~3.7GB of images (all
# content, essentially no history to shallow-clone away). --optional so a
# fresh bootstrap doesn't pull multiple gigabytes unattended; run by name
# when wanted: ./bootstrap.sh walls
register_step walls \
    --desc "dharmx/walls wallpaper collection, ~3.7GB (opt-in: ./bootstrap.sh walls)" \
    --group personal --optional --needs prereqs \
    --provides "$HOME/.local/share/wallpapers/walls/.git"

# Not ~/Pictures: lands inside the wallpaper package's whole-dir stow symlink
# (~/.local/share/wallpapers -> wallpaper/.local/share/wallpapers), same as
# quickCapture/krkCommute land inside their stowed parent — gitignored there.
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

    # Best-effort: point DMS's wallpaper picker at the new folder by setting
    # a wallpaper from it, so it opens there next time (SUPER+W). No-op
    # unless the shell is already running — same guard as dms_enable_plugin.
    if pgrep -x qs >/dev/null 2>&1 && command -v dms >/dev/null 2>&1; then
        local pic
        pic="$(find -L "$WALLS_DIR" -maxdepth 2 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
            2>/dev/null | sort | head -1)"
        [ -n "$pic" ] && dms ipc call wallpaper set "$pic" >/dev/null 2>&1
    fi
}
