register_step tailscale \
    --desc "Tailscale, from its own apt repo; 'sudo tailscale up' to log in (opt-in: ./bootstrap.sh tailscale)" \
    --group apps --root --optional --needs prereqs \
    --provides tailscale

step_tailscale() {
    local key=/usr/share/keyrings/tailscale-archive-keyring.gpg codename
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    log "Adding Tailscale's apt repo"
    ensure_apt_key "https://pkgs.tailscale.com/stable/debian/$codename.noarmor.gpg" "$key"
    ensure_apt_list /etc/apt/sources.list.d/tailscale.list \
        "deb [signed-by=$key] https://pkgs.tailscale.com/stable/debian $codename main" \
        "pkgs.tailscale.com/stable/debian"

    log "Installing Tailscale"
    apt_install tailscale
    sudo systemctl enable --now tailscaled
}
