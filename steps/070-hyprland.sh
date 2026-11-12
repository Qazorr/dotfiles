register_step hyprland \
    --desc "Hyprland and its portal, from backports" \
    --group desktop --root --needs backports \
    --provides Hyprland

step_hyprland() {
    log "Installing Hyprland from trixie-backports"
    apt_install_backports \
        hyprland \
        hyprland-guiutils \
        xdg-desktop-portal-hyprland
}
