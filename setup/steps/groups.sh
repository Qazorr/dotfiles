# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_groups() { # video/render/input, for a DM-less Hyprland session
    log "Ensuring $USER is in video/render/input groups (DRM/input access without a display manager)"
    sudo usermod -aG video,render,input "$USER"
}
