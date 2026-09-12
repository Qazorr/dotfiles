# shellcheck shell=bash
register_step hyprland \
    --desc "Hyprland + hyprlock/hypridle/portal, from backports" \
    --group desktop --root --needs backports \
    --provides Hyprland hyprlock hypridle

step_hyprland() {
    log "Installing Hyprland + companions from trixie-backports"
    apt_install_backports \
        hyprland \
        hyprland-guiutils \
        hypridle \
        hyprlock \
        hyprpolkitagent \
        xdg-desktop-portal-hyprland
}
