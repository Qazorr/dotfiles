register_step services \
    --desc "Enable NetworkManager + Bluetooth" \
    --group desktop --root --needs desktop

step_services() {
    log "Enabling NetworkManager + Bluetooth services"
    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now bluetooth
}
