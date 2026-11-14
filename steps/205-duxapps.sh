register_step duxapps \
    --desc "Dux Files (file manager) + Dux Calendar" \
    --group desktop --root --needs prereqs quickshell duxrepo \
    --provides dfiles dcal

step_duxapps() {
    log "Installing Dux Files and Dux Calendar"
    apt_install dux-files dux-calendar poppler-utils bubblewrap udisks2
    systemctl --user enable dfiles dcal \
        || warn "Could not enable dfiles/dcal; run: systemctl --user enable dfiles dcal"
}
