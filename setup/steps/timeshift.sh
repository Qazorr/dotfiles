register_step timeshift \
    --desc "Full-system snapshot (rsync mode) before install" \
    --group safety --root --always \
    --provides timeshift

step_timeshift() {
    if [ "${DOTFILES_SKIP_TIMESHIFT:-0}" = "1" ]; then
        warn "DOTFILES_SKIP_TIMESHIFT=1, no system snapshot taken"
        return 0
    fi

    command -v timeshift >/dev/null 2>&1 || { log "Installing timeshift"; apt_install timeshift; }

    # Without this, a re-run would spend ten minutes and several GB
    # duplicating a snapshot you already have.
    local recent
    recent="$(sudo find /timeshift -maxdepth 3 -name 'info.json' -mtime -1 2>/dev/null | head -1 || true)"
    if [ -n "$recent" ]; then
        log "A timeshift snapshot from the last 24h already exists, skipping"
        return 0
    fi

    # Snapshots land on the same disk: protects against a bad install, not
    # against disk failure.
    local root_dev
    root_dev="$(findmnt -no SOURCE / 2>/dev/null || true)"
    [ -n "$root_dev" ] || { warn "couldn't determine the root device, skipping timeshift"; return 0; }

    local avail_gb
    avail_gb="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
    if [ "${avail_gb:-0}" -lt 25 ]; then
        warn "only ${avail_gb}GB free on / — skipping timeshift (a first snapshot needs ~15GB)"
        return 0
    fi

    log "Creating a timeshift snapshot on $root_dev (first one takes a while)"
    # --rsync explicitly, so behaviour doesn't change on a btrfs root.
    # --tags O marks it on-demand, so retention won't rotate it away.
    sudo timeshift --create --rsync \
        --snapshot-device "$root_dev" \
        --comments "before dotfiles bootstrap $(date +%F-%H%M)" \
        --tags O \
        || warn "timeshift snapshot failed — continuing without a system rollback point"
}
