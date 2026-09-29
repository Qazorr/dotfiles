# --always: once recorded as done, a danklinux.list rewritten behind our back
# was never fixed and dms-greeter kept failing.
register_step danklinux \
    --desc "DankLinux apt repo (Quickshell, dms-greeter)" \
    --group desktop --root --always --needs prereqs

# downloadcontent serves directly; download redirects to mirrors that can lag
# the index ("File has unexpected size").
DANKLINUX_REPO=https://downloadcontent.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13

step_danklinux() {
    log "Adding the DankLinux apt repo"
    local key=/etc/apt/keyrings/danklinux.asc
    sudo install -m0755 -d /etc/apt/keyrings
    ensure_apt_key "$DANKLINUX_REPO/Release.key" "$key"
    sudo chmod a+r "$key"
    ensure_apt_list /etc/apt/sources.list.d/danklinux.list \
        "deb [signed-by=$key] $DANKLINUX_REPO/ /" \
        "AvengeMedia:/danklinux"
}
