# shellcheck shell=bash
register_step docker \
    --desc "Docker Engine + Compose/Buildx plugins, from Docker's own apt repo" \
    --group dev --root --needs prereqs \
    --provides docker

step_docker() {
    if command -v docker >/dev/null 2>&1; then
        log "Docker already installed, skipping"
        return 0
    fi

    # Debian's docker.io trails upstream badly; this repo is docker.com's own
    # documented method.
    log "Adding Docker's apt repo"
    local key=/etc/apt/keyrings/docker.asc
    sudo install -m0755 -d /etc/apt/keyrings
    ensure_apt_key https://download.docker.com/linux/debian/gpg "$key"
    sudo chmod a+r "$key"
    ensure_apt_list /etc/apt/sources.list.d/docker.list \
        "deb [arch=$(dpkg --print-architecture) signed-by=$key] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        "download.docker.com/linux/debian"

    log "Installing Docker Engine"
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker

    # step_groups adds $USER to the docker group this created; that needs a
    # fresh login to take effect.
}
