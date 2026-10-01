# DRM/input access without a display manager, and docker without sudo. Each
# is joined only if it exists; --doctor checks the same list.
USER_GROUPS=(video render input docker)

register_step groups \
    --desc "${USER_GROUPS[*]} groups, and zsh as the login shell" \
    --group core --root

step_groups() {
    local g
    for g in "${USER_GROUPS[@]}"; do
        getent group "$g" >/dev/null 2>&1 || continue
        log "Ensuring $USER is in the $g group"
        sudo usermod -aG "$g" "$USER"
    done

    local want=/usr/bin/zsh
    if [ ! -x "$want" ]; then
        warn "zsh isn't installed yet — run the desktop step, then this one"
        stamp_skip
    elif [ "$(getent passwd "$USER" | cut -d: -f7)" != "$want" ]; then
        log "Making zsh $USER's login shell"
        sudo chsh -s "$want" "$USER"
    fi
}
