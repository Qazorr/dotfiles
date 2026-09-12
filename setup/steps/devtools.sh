# shellcheck shell=bash
# Not packaged for Debian, so fetched as GitHub release tarballs.
# /usr/local/bin rather than ~/.local/bin, which is a stow symlink into this
# repo — same as hyprmon.
LAZYDOCKER_VERSION=v0.25.2
LAZYGIT_VERSION=v0.64.1

register_step devtools \
    --desc "lazydocker, lazygit: TUIs for containers/git" \
    --group dev --root --needs prereqs \
    --provides lazydocker lazygit

step_devtools() {
    require_disk_space 1
    local tmp; scratch_dir tmp

    if command -v lazydocker >/dev/null 2>&1 \
        && lazydocker --version 2>/dev/null | grep -q "${LAZYDOCKER_VERSION#v}"; then
        log "lazydocker $LAZYDOCKER_VERSION already installed, skipping"
    else
        log "Installing lazydocker $LAZYDOCKER_VERSION"
        install_github_release_binary jesseduffield/lazydocker "$LAZYDOCKER_VERSION" \
            "lazydocker_${LAZYDOCKER_VERSION#v}_Linux_x86_64.tar.gz" lazydocker \
            /usr/local/bin/lazydocker "$tmp"
    fi

    if command -v lazygit >/dev/null 2>&1 \
        && lazygit --version 2>/dev/null | grep -q "${LAZYGIT_VERSION#v}"; then
        log "lazygit $LAZYGIT_VERSION already installed, skipping"
    else
        log "Installing lazygit $LAZYGIT_VERSION"
        install_github_release_binary jesseduffield/lazygit "$LAZYGIT_VERSION" \
            "lazygit_${LAZYGIT_VERSION#v}_linux_x86_64.tar.gz" lazygit \
            /usr/local/bin/lazygit "$tmp"
    fi
}
