register_step prereqs \
    --desc "curl, git, gnupg, unzip, zsh, stow — what every other step assumes exists" \
    --group core --root \
    --provides curl git gpg unzip zsh stow

step_prereqs() {
    log "Installing base prerequisites"
    apt_install curl git ca-certificates gnupg unzip fontconfig pciutils zsh stow
}
