GRUB_THEME_DIR=/boot/grub/themes/dotfiles
BOOT_THEME_UNIT=dotfiles-boot-theme

register_step grub \
    --desc "Boot menu and splash in the wallpaper's colours, kept in step with DMS" \
    --group desktop --root --needs prereqs \
    --provides "$GRUB_THEME_DIR/theme.txt"

# A system unit, since the splash lives in the initramfs.
_grub_watch() {
    local home unit
    home="$(getent passwd "$USER" | cut -d: -f6)"
    for unit in "$BOOT_THEME_UNIT.path" "$BOOT_THEME_UNIT.service"; do
        render_to "/etc/systemd/system/$unit" "$REPO/boot/systemd/$unit" \
            HOME="$home" REPO="$REPO" USER="$USER"
    done
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$BOOT_THEME_UNIT.path" >/dev/null
}

step_grub() {
    command -v update-grub >/dev/null 2>&1 \
        || {
            warn "no GRUB on this machine, skipping its theme"
            stamp_skip
            return 0
        }
    apt_install fonts-dejavu-core imagemagick librsvg2-bin desktop-base plymouth plymouth-themes plymouth-label

    log "Rendering and installing the boot themes"
    sudo "$REPO/boot/install.sh" "$USER"

    sudo install -d /etc/default/grub.d
    render_to /etc/default/grub.d/dotfiles.cfg "$REPO/boot/grub/default.cfg" THEME_DIR="$GRUB_THEME_DIR"
    sudo update-grub

    log "Watching what the boot themes are built from, to re-theme them on changes"
    _grub_watch
}
