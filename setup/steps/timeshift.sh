# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_timeshift() { # Full-system snapshot (rsync mode) before install
    if [ "${DOTFILES_SKIP_TIMESHIFT:-0}" = "1" ]; then
        warn "DOTFILES_SKIP_TIMESHIFT=1, no system snapshot taken"
        return 0
    fi

    command -v timeshift >/dev/null 2>&1 || { log "Installing timeshift"; apt_install timeshift; }

    # Only snapshot if there isn't already a recent one. Without this, a
    # re-run of bootstrap.sh (which is meant to be cheap) would spend ten
    # minutes and several GB duplicating a snapshot you already have.
    local recent
    recent="$(sudo find /timeshift -maxdepth 3 -name 'info.json' -mtime -1 2>/dev/null | head -1 || true)"
    if [ -n "$recent" ]; then
        log "A timeshift snapshot from the last 24h already exists, skipping"
        return 0
    fi

    # This machine is a single ext4 root — no btrfs, so rsync mode it is.
    # Snapshots land on the same disk, which protects against a bad install
    # but NOT against disk failure. Keep real backups elsewhere.
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
    # --rsync explicitly: timeshift picks btrfs mode when it detects a btrfs
    # root, and we want the same behaviour regardless of what it guesses.
    # --tags O marks it on-demand, so timeshift's own retention policy for
    # scheduled snapshots won't rotate this one away.
    sudo timeshift --create --rsync \
        --snapshot-device "$root_dev" \
        --comments "before dotfiles bootstrap $(date +%F-%H%M)" \
        --tags O \
        || warn "timeshift snapshot failed — continuing without a system rollback point"
}
