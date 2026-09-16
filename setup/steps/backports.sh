# shellcheck shell=bash
register_step backports \
    --desc "Enable trixie-backports and refresh the package lists" \
    --group core --root

step_backports() {
    log "Ensuring trixie-backports is enabled"
    if ! grep -Rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        echo "deb http://deb.debian.org/debian trixie-backports main" \
            | sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
    fi
    apt_update
}
