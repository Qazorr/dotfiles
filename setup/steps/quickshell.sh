# shellcheck shell=bash
# DMS runs on Quickshell, which Debian doesn't package. DankLinux's repo has
# the identical upstream version, so it's an apt install rather than the
# 10-20 minute, ~8GB Qt source build this step used to do.
register_step quickshell \
    --desc "Quickshell (DMS runs on it)" \
    --group desktop --root --needs prereqs danklinux \
    --provides qs

step_quickshell() {
    log "Installing Quickshell"
    apt_install quickshell
}
