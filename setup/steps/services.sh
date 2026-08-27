# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_services() { # Enable NetworkManager + Bluetooth
    log "Enabling NetworkManager + Bluetooth services"
    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now bluetooth
}
