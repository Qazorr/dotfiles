# greetd + dms-greeter: a DMS-themed login screen (syncs theme/wallpaper).
# Session entries in /usr/share/wayland-sessions start Hyprland via Debian's
# hyprland.desktop (Exec=/usr/bin/start-hyprland) — launching the Hyprland
# binary directly earns a "started without start-hyprland" warning.
register_step login \
    --desc "greetd + dms-greeter: DMS-themed login screen" \
    --group desktop --root --needs hyprland danklinux \
    --provides /etc/greetd/config.toml dms-greeter

step_login() {
    log "Installing greetd + dms-greeter"
    apt_install dms-greeter

    # The package's own command, not a hand-written config.toml: it also
    # disables conflicting display managers and sets graphical.target — a bare
    # `systemctl enable greetd` does neither, leaving getty@tty1 to fight it
    # for the same terminal. Not wrapped in sudo: it escalates on its own;
    # -y skips confirmation, DMS_PRIVESC skips its sudo-vs-run0 picker.
    log "Enabling dms-greeter in greetd"
    dms-greeter enable -y

    getent passwd greeter >/dev/null 2>&1 \
        || die "dms-greeter is installed but the 'greeter' user is missing — its postinst did not complete."

    # The greeter runs its own compositor and needs the DRM devices
    # (/dev/dri/card0 root:video, renderD128 root:render). Without this
    # Hyprland fails to open a render node, greetd burns its 5 restarts, and
    # the tty falls back to getty.
    log "Adding the greeter user to video/render/input"
    sudo usermod -aG video,render,input greeter

    # Copies this user's DMS theme and wallpaper into the greeter cache. Only
    # meaningful once DMS has settings worth copying, so not fatal this early.
    dms-greeter sync -y >/dev/null 2>&1 \
        || warn "dms-greeter sync failed — the greeter still works, it just won't match your theme. Re-run 'dms-greeter sync' once DMS is set up."

    # Deliberately not started here: it would seize vt1 and kill the terminal
    # this run is printing to. It comes up on the next boot.
    log "greetd is enabled; the greeter comes up on the next reboot"
}
