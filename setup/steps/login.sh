# shellcheck shell=bash
# greetd, with a choice of greeter. Session entries in
# /usr/share/wayland-sessions start Hyprland via Debian's hyprland.desktop
# (Exec=/usr/bin/start-hyprland) — launching the Hyprland binary directly
# earns a "started without start-hyprland" warning.
# --needs covers both greeters: the option is chosen after the plan is
# resolved, so dms-greeter's Quickshell runtime has to be pulled in either
# way. tuigreet needs neither, and pays only an apt repo it already has.
register_step login \
    --desc "greetd + a greeter (dms-greeter or tuigreet)" \
    --group desktop --root --needs hyprland danklinux quickshell \
    --provides /etc/greetd/config.toml

# dms-greeter is themed to match the shell, but it runs a whole Quickshell
# compositor as the greeter user and comes from DankLinux's OBS repo, whose
# mirrors desync. tuigreet is in Debian proper and has nothing to crash —
# the fallback when the pretty one won't install or won't start.
register_option login DOTFILES_GREETER \
    --prompt "Which login screen?" \
    --choices \
        "dms:dms-greeter — themed to match the shell (needs Quickshell + DankLinux repo)" \
        "tuigreet:tuigreet — plain terminal greeter from Debian, nothing to break" \
    --default dms

_login_dms() {
    log "Installing greetd + dms-greeter"
    apt_install dms-greeter || return 1

    # The package's own command: it also disables conflicting display
    # managers and sets graphical.target, which `systemctl enable` doesn't.
    # Escalates on its own; DMS_PRIVESC skips its sudo-vs-run0 picker.
    log "Enabling dms-greeter in greetd"
    dms-greeter enable -y || return 1

    getent passwd greeter >/dev/null 2>&1 \
        || die "dms-greeter installed but the 'greeter' user is missing — its postinst did not complete."

    # Copies this user's theme and wallpaper into the greeter cache. Only
    # meaningful once DMS has settings worth copying, so not fatal this early.
    dms-greeter sync -y >/dev/null 2>&1 \
        || warn "dms-greeter sync failed — the greeter works, it just won't match your theme. Re-run 'dms-greeter sync' once DMS is set up."
}

_login_tuigreet() {
    log "Installing greetd + tuigreet"
    apt_install greetd tuigreet || return 1

    # greetd's own config: tuigreet lists /usr/share/wayland-sessions, so
    # Hyprland appears without this file naming it.
    log "Writing /etc/greetd/config.toml"
    sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --sessions /usr/share/wayland-sessions"
user = "greeter"
EOF

    # greetd's postinst makes the greeter user; nothing else will.
    getent passwd greeter >/dev/null 2>&1 \
        || die "greetd installed but the 'greeter' user is missing — its postinst did not complete."

    # Two readers on one terminal otherwise, both echoing your keystrokes.
    sudo systemctl disable getty@tty1.service >/dev/null 2>&1 || true
    sudo systemctl set-default graphical.target >/dev/null
    sudo systemctl enable greetd.service >/dev/null
}

step_login() {
    case "${DOTFILES_GREETER:-dms}" in
        dms)      _login_dms || return 1 ;;
        tuigreet) _login_tuigreet || return 1 ;;
        *) die "DOTFILES_GREETER must be dms or tuigreet (got '${DOTFILES_GREETER}')" ;;
    esac

    # Whichever greeter: it runs on its own VT and needs the DRM devices, or
    # it can't open a render node and greetd burns its 5 restarts.
    log "Adding the greeter user to video/render/input"
    sudo usermod -aG video,render,input greeter

    # Deliberately not started here: it would switch to its VT and kill the
    # terminal this run is printing to. It comes up on the next boot.
    log "greetd is enabled; the greeter comes up on the next reboot"
}
