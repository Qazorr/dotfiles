register_step groups \
    --desc "video/render/input/docker, for a DM-less session + rootless containers" \
    --group core --root

step_groups() {
    log "Ensuring $USER is in video/render/input groups (DRM/input access without a display manager)"
    sudo usermod -aG video,render,input "$USER"

    # The group doesn't exist until docker-ce creates it, and usermod on a
    # nonexistent group is a hard abort under set -e.
    if getent group docker >/dev/null 2>&1; then
        log "Ensuring $USER is in the docker group (run docker without sudo)"
        sudo usermod -aG docker "$USER"
    fi
}
