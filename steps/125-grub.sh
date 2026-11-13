GRUB_THEME_DIR=/boot/grub/themes/dotfiles
BOOT_THEME_UNIT=dotfiles-boot-theme

register_step grub \
    --desc "Boot menu and splash in the wallpaper's colours, kept in step with DMS" \
    --group desktop --root --needs prereqs \
    --provides "$GRUB_THEME_DIR/theme.txt"

# A system unit, since the splash lives in the initramfs; it watches the file
# DMS rewrites whenever the wallpaper's palette changes.
_grub_watch_colours() {
    local home; home="$(getent passwd "$USER" | cut -d: -f6)"
    sudo tee "/etc/systemd/system/$BOOT_THEME_UNIT.path" >/dev/null <<EOF
[Unit]
Description=Re-theme the boot screens when the DMS colours change

[Path]
PathChanged=$home/.cache/dms/dms-colors.json

[Install]
WantedBy=multi-user.target
EOF
    sudo tee "/etc/systemd/system/$BOOT_THEME_UNIT.service" >/dev/null <<EOF
[Unit]
Description=Re-theme the boot screens from the DMS colours

[Service]
Type=oneshot
ExecStart=$REPO/boot/install.sh $USER
Nice=10
IOSchedulingClass=idle
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$BOOT_THEME_UNIT.path" >/dev/null
}

step_grub() {
    command -v update-grub >/dev/null 2>&1 \
        || { warn "no GRUB on this machine, skipping its theme"; stamp_skip; return 0; }
    apt_install fonts-dejavu-core imagemagick desktop-base plymouth plymouth-themes plymouth-label

    log "Rendering and installing the boot themes"
    sudo "$REPO/boot/install.sh" "$USER"

    # GRUB_BACKGROUND puts the same image behind the "Loading Linux" text.
    # loglevel=3 hides the ACPI errors and driver warnings quiet still prints.
    sudo install -d /etc/default/grub.d
    sudo tee /etc/default/grub.d/dotfiles.cfg >/dev/null <<EOF
GRUB_THEME=$GRUB_THEME_DIR/theme.txt
GRUB_BACKGROUND=$GRUB_THEME_DIR/background.png
GRUB_GFXMODE=auto
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0"
EOF
    sudo update-grub

    log "Watching the DMS colours to re-theme on wallpaper changes"
    _grub_watch_colours
}
