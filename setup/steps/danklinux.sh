# shellcheck shell=bash
# DankLinux's own Debian 13 repo (the DankMaterialShell author's). It packages
# Quickshell and the DMS greeter, neither of which is in Debian proper — see
# setup/steps/quickshell.sh for what that replaced.
register_step danklinux \
    --desc "DankLinux apt repo (Quickshell, dms-greeter)" \
    --group desktop --root --needs prereqs

# downloadcontent, not download: the latter is MirrorBrain and redirects to
# a nearby mirror, which can serve a .deb that doesn't match the index yet
# ("File has unexpected size", apt refuses it). This host serves directly.
DANKLINUX_REPO=https://downloadcontent.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13

step_danklinux() {
    log "Adding the DankLinux apt repo"
    local key=/etc/apt/keyrings/danklinux.asc
    sudo install -m0755 -d /etc/apt/keyrings
    # Served ASCII-armored, and signed-by= takes that as-is from a .asc —
    # same as Anthropic's, unlike Microsoft's which needs dearmoring.
    ensure_apt_key "$DANKLINUX_REPO/Release.key" "$key"
    sudo chmod a+r "$key"
    # A flat repo: no suite or component, hence the bare trailing "/".
    ensure_apt_list /etc/apt/sources.list.d/danklinux.list \
        "deb [signed-by=$key] $DANKLINUX_REPO/ /" \
        "AvengeMedia:/danklinux"
}
