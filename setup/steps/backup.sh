# shellcheck shell=bash
register_step backup \
    --desc "Snapshot current dotfiles before changing anything" \
    --group safety --always

step_backup() {
    if [ "${DOTFILES_SKIP_BACKUP:-0}" = "1" ]; then
        warn "DOTFILES_SKIP_BACKUP=1, no config snapshot taken"
        return 0
    fi
    log "Snapshotting current config"
    "$REPO/scripts/.local/bin/dotfiles-backup" \
        || warn "backup failed — continuing, but you have no config rollback point"
}
