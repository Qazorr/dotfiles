# greetd is a tiny login daemon and tuigreet its terminal greeter — two
# packages, no extra dependencies, no Qt or GTK. It launches the session
# entries in /usr/share/wayland-sessions, and hyprland.desktop there is
# Exec=/usr/bin/start-hyprland, which is the launcher Hyprland itself asks
# for. Starting the Hyprland binary directly gets you a "started without
# start-hyprland" warning on every login.
register_step login \
    --desc "greetd + tuigreet: a minimal login manager on tty1" \
    --group desktop --root --needs hyprland \
    --provides /etc/greetd/config.toml

GREETD_CONFIG=/etc/greetd/config.toml

step_login() {
    command -v greetd >/dev/null 2>&1 || [ -x /usr/sbin/greetd ] \
        || { log "Installing greetd + tuigreet"; apt_install greetd tuigreet; }

    # The package creates this account for the greeter to drop to; without it
    # greetd refuses to start and the machine has no way in but a tty.
    getent passwd _greetd >/dev/null 2>&1 \
        || die "greetd is installed but the _greetd user is missing — the package's postinst did not complete."

    # --sessions rather than a hardcoded --cmd, so this file doesn't need
    # editing to add a session, and --remember-session makes the common case
    # one Enter.
    local want
    want="$(cat <<'EOF'
# Written by dotfiles bootstrap.sh (step_login).
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --sessions /usr/share/wayland-sessions"
user = "_greetd"
EOF
)"
    if [ -f "$GREETD_CONFIG" ] && [ "$(sudo cat "$GREETD_CONFIG")" = "$want" ]; then
        log "greetd already configured, skipping"
    else
        log "Writing $GREETD_CONFIG"
        sudo install -d -m755 "$(dirname "$GREETD_CONFIG")"
        printf '%s\n' "$want" | sudo tee "$GREETD_CONFIG" >/dev/null
    fi

    # enable, not --now: starting it here would take over vt1 and kill the
    # terminal this run is printing to.
    sudo systemctl enable greetd.service >/dev/null
}
