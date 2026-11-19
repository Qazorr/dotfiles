register_step duxapps \
    --desc "Dux Files (file manager), Dux Calendar, KDE Connect" \
    --group desktop --root --needs prereqs quickshell duxrepo \
    --provides dfiles dcal kdeconnectd

step_duxapps() {
    log "Installing Dux Files, Dux Calendar and KDE Connect"
    # kdeconnect: the daemon autostart.lua runs, behind the dankKDEConnect plugin.
    apt_install dux-files dux-calendar poppler-utils bubblewrap udisks2 kdeconnect
    systemctl --user enable dfiles dcal \
        || warn "Could not enable dfiles/dcal; run: systemctl --user enable dfiles dcal"
}
