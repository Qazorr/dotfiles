# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_backports() { # Enable trixie-backports and refresh apt
    log "Ensuring trixie-backports is enabled"
    if ! grep -Rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        echo "deb http://deb.debian.org/debian trixie-backports main" \
            | sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
    fi
    sudo apt update
}
