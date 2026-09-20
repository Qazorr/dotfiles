# shellcheck shell=bash
register_step prereqs \
    --desc "curl, git, gnupg, unzip — what every other step assumes exists" \
    --group core --root \
    --provides curl git gpg unzip

step_prereqs() {
    log "Installing base prerequisites"
    apt_install curl git ca-certificates gnupg unzip fontconfig pciutils
}
