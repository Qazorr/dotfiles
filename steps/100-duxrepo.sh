# --always: once recorded as done, a dux-repo.list rewritten behind our back
# was never fixed and dms-greeter kept failing.
register_step duxrepo \
    --desc "Dux Labs apt repo (Quickshell, dux-greeter)" \
    --group desktop --root --always --needs prereqs

# downloadcontent serves directly; download redirects to mirrors that can lag
# the index ("File has unexpected size").
DUX_REPO=https://downloadcontent.opensuse.org/repositories/home:/duxlabs-dev:/dux-repo/Debian_13

step_duxrepo() {
    log "Adding the Dux Labs apt repo"
    local key=/etc/apt/keyrings/dux-repo.asc
    sudo install -m0755 -d /etc/apt/keyrings
    ensure_apt_key "$DUX_REPO/Release.key" "$key"
    sudo chmod a+r "$key"
    # The AvengeMedia project publishes the same packages; two sources for
    # one package means two indexes to go stale.
    sudo rm -f /etc/apt/sources.list.d/danklinux.list /etc/apt/keyrings/danklinux.asc
    ensure_apt_list /etc/apt/sources.list.d/dux-repo.list \
        "deb [signed-by=$key] $DUX_REPO/ /" \
        "duxlabs-dev:/dux-repo"
}
