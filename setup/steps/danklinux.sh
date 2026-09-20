# shellcheck shell=bash
# DankLinux's own Debian 13 repo, packaging Quickshell and the DMS greeter.
#
# --always, because the step is two idempotent file checks and recording it is
# what broke it: stamped done, it was skipped forever, so a danklinux.list
# rewritten behind our back kept every dms-greeter install failing on a
# desynced mirror.
register_step danklinux \
    --desc "DankLinux apt repo (Quickshell, dms-greeter)" \
    --group desktop --root --always --needs prereqs

# downloadcontent, not download: the latter is MirrorBrain and redirects to a
# nearby mirror, which can serve a .deb that does not match the index yet
# ("File has unexpected size"). This host serves directly.
DANKLINUX_REPO=https://downloadcontent.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13

step_danklinux() {
    log "Adding the DankLinux apt repo"
    local key=/etc/apt/keyrings/danklinux.asc
    sudo install -m0755 -d /etc/apt/keyrings
    ensure_apt_key "$DANKLINUX_REPO/Release.key" "$key"
    sudo chmod a+r "$key"
    # A flat repo: no suite or component, hence the bare trailing "/".
    ensure_apt_list /etc/apt/sources.list.d/danklinux.list \
        "deb [signed-by=$key] $DANKLINUX_REPO/ /" \
        "AvengeMedia:/danklinux"
}
