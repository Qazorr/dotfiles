# shellcheck shell=bash
# What every other step assumes exists; Debian's minimal install has none of
# it. These used to arrive incidentally with the `desktop` step, so
# `bootstrap.sh devtools` on a fresh machine failed on a missing curl.
register_step prereqs \
    --desc "curl, git, gnupg, unzip — what every other step assumes exists" \
    --group core --root \
    --provides curl git gpg unzip

step_prereqs() {
    log "Installing base prerequisites"
    apt_install curl git ca-certificates gnupg unzip fontconfig pciutils
}
