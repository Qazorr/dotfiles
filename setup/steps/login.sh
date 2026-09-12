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

# gdm3 (installed by Debian's GNOME task) owns
# /etc/systemd/system/display-manager.service. greetd's postinst presets its
# own unit, that preset fails on a symlink pointing elsewhere, and the postinst
# aborts - leaving greetd half-configured and the greeter user uncreated.
# Disabling gdm3 drops the symlink. No --now: that would kill the session this
# is running inside.
_login_free_display_manager() {
    local link=/etc/systemd/system/display-manager.service dm
    if [ -L "$link" ]; then
        dm="$(basename "$(readlink -f "$link")")"
        if [ "$dm" != greetd.service ]; then
            log "Disabling $dm, which owns display-manager.service and blocks greetd"
            sudo systemctl disable "$dm" >/dev/null 2>&1 || true
            sudo rm -f "$link"
        fi
    fi
    # Finish anything a previous failed run left half-configured, or apt
    # refuses to do anything else.
    sudo dpkg --configure -a >/dev/null 2>&1 || true
}

# Debian's greetd postinst creates this; if it died above, it did not. Both
# config.toml and dms-greeter run the session as this exact user.
_login_ensure_greeter_user() {
    getent passwd greeter >/dev/null 2>&1 && return 0
    log "Creating the greeter user"
    sudo adduser --system --group --home /var/lib/greetd \
        --shell /usr/sbin/nologin --quiet greeter \
        || die "could not create the 'greeter' user"
}

_login_dms() {
    log "Installing greetd + dms-greeter"
    # OBS rebuilds the .deb under the same version; an index older than the
    # rebuild makes apt reject the download on size ("File has unexpected
    # size"). A refresh is the whole fix, so don't fail the run over it.
    if ! apt_install dms-greeter; then
        warn "dms-greeter wouldn't download — refreshing the package index and retrying once"
        sudo apt update
        apt_install dms-greeter || return 1
    fi
    _login_ensure_greeter_user

    # The package's own command: it also disables conflicting display
    # managers and sets graphical.target, which `systemctl enable` doesn't.
    # Escalates on its own; DMS_PRIVESC skips its sudo-vs-run0 picker.
    log "Enabling dms-greeter in greetd"
    dms-greeter enable -y || return 1
    # Copies this user's theme and wallpaper into the greeter cache. Only
    # meaningful once DMS has settings worth copying, so not fatal this early.
    dms-greeter sync -y >/dev/null 2>&1 \
        || warn "dms-greeter sync failed — the greeter works, it just won't match your theme. Re-run 'dms-greeter sync' once DMS is set up."
}

_login_tuigreet() {
    log "Installing greetd + tuigreet"
    apt_install greetd tuigreet || return 1
    _login_ensure_greeter_user

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
    # Two readers on one terminal otherwise, both echoing your keystrokes.
    sudo systemctl disable getty@tty1.service >/dev/null 2>&1 || true
    sudo systemctl set-default graphical.target >/dev/null
    sudo systemctl enable greetd.service >/dev/null
}

step_login() {
    _login_free_display_manager

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
