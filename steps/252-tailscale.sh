register_step tailscale \
    --desc "Tailscale and the Dankscale DMS plugin; 'tailscale up' to log in (opt-in: ./bootstrap.sh tailscale)" \
    --group apps --root --optional --needs prereqs dms \
    --provides tailscale "$HOME/.config/dms/plugins/dankscale"

step_tailscale() {
    local key=/usr/share/keyrings/tailscale-archive-keyring.gpg codename
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    log "Adding Tailscale's apt repo"
    ensure_apt_key "https://pkgs.tailscale.com/stable/debian/$codename.noarmor.gpg" "$key"
    ensure_apt_list /etc/apt/sources.list.d/tailscale.list \
        "deb [signed-by=$key] https://pkgs.tailscale.com/stable/debian $codename main" \
        "pkgs.tailscale.com/stable/debian"

    # Without it Tailscale owns /etc/resolv.conf and VPN DNS stops resolving;
    # resolved routes each domain to its own link's DNS.
    log "Installing systemd-resolved"
    apt_install systemd-resolved
    sudo systemctl enable --now systemd-resolved
    printf '[main]\ndns=systemd-resolved\n' \
        | sudo tee /etc/NetworkManager/conf.d/dns-resolved.conf >/dev/null
    local stub=/run/systemd/resolve/stub-resolv.conf
    if [ "$(readlink /etc/resolv.conf)" != "$stub" ]; then
        sudo ln -sf "$stub" /etc/resolv.conf
        # Both pick their DNS backend at startup; this drops an active VPN.
        sudo systemctl restart NetworkManager
        ! systemctl is-active -q tailscaled || sudo systemctl restart tailscaled
    fi

    log "Installing Tailscale"
    apt_install tailscale
    sudo systemctl enable --now tailscaled

    # Lets the user, and Dankscale, log in and switch accounts without sudo.
    sudo tailscale set --operator="$USER" \
        || warn "couldn't make $USER the Tailscale operator; run: sudo tailscale set --operator=$USER"

    # Installed here, not via dms-plugins.lock.json, so it only lands where Tailscale is.
    if [ ! -d "$HOME/.config/dms/plugins/dankscale" ]; then
        log "Installing the Dankscale DMS plugin"
        dms plugins install dankscale
    fi
    dms_enable_plugin dankscale
}
