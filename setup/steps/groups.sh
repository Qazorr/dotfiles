# shellcheck shell=bash
register_step groups \
    --desc "video/render/input/docker groups, and zsh as the login shell" \
    --group core --root

step_groups() {
    log "Ensuring $USER is in video/render/input groups (DRM/input access without a display manager)"
    sudo usermod -aG video,render,input "$USER"

    if getent group docker >/dev/null 2>&1; then
        log "Ensuring $USER is in the docker group (run docker without sudo)"
        sudo usermod -aG docker "$USER"
    fi

    local want=/usr/bin/zsh
    if [ ! -x "$want" ]; then
        warn "zsh isn't installed yet — run the desktop step, then this one"
        stamp_skip
    elif [ "$(getent passwd "$USER" | cut -d: -f7)" != "$want" ]; then
        log "Making zsh $USER's login shell"
        sudo chsh -s "$want" "$USER"
    fi
}
