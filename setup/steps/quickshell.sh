# DMS runs on Quickshell. This used to build it from source — Debian doesn't
# package it — which cost 10-20 minutes and ~8GB of Qt build dependencies.
# DankLinux packages the identical upstream version, so it's an apt install.
register_step quickshell \
    --desc "Quickshell (DMS runs on it)" \
    --group desktop --root --needs prereqs danklinux \
    --provides qs

step_quickshell() {
    # A leftover from when this step built from source: cmake's default prefix
    # is /usr/local, which comes before /usr/bin on PATH, so the old binary
    # would silently win over the packaged one.
    if [ -x /usr/local/bin/qs ] && ! dpkg -S /usr/local/bin/qs >/dev/null 2>&1; then
        warn "/usr/local/bin/qs is a leftover source build and shadows the packaged one."
        warn "Remove it with: sudo rm -f /usr/local/bin/qs /usr/local/bin/quickshell"
    fi

    log "Installing Quickshell"
    apt_install quickshell
}
