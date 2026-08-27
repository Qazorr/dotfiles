# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_hyprland() { # Hyprland + hyprlock/hypridle/portal, from backports
    log "Installing Hyprland + companions from trixie-backports"
    apt_install_backports \
        hyprland \
        hyprland-guiutils \
        hypridle \
        hyprlock \
        hyprpolkitagent \
        xdg-desktop-portal-hyprland
}
