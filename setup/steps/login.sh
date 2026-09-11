# greetd is a tiny login daemon; dms-greeter is DankMaterialShell's own greeter
# for it, so the login screen matches the shell (it syncs DMS's theme, wallpaper
# and settings). The package ships no greetd config — that part is below.
#
# The session entries in /usr/share/wayland-sessions are what actually start
# Hyprland, and Debian's hyprland.desktop is Exec=/usr/bin/start-hyprland.
# Launching the Hyprland binary directly earns a "started without
# start-hyprland" warning on every login.
register_step login \
    --desc "greetd + dms-greeter: DMS-themed login screen" \
    --group desktop --root --needs hyprland danklinux \
    --provides /etc/greetd/config.toml dms-greeter

GREETD_CONFIG=/etc/greetd/config.toml

step_login() {
    log "Installing greetd + dms-greeter"
    apt_install dms-greeter

    # The package's postinst creates this; without it greetd has no account to
    # drop the greeter to and the machine has no way in but a tty.
    getent passwd greeter >/dev/null 2>&1 \
        || die "dms-greeter is installed but the 'greeter' user is missing — its postinst did not complete."

    # Written out rather than left to `dms-greeter enable`, so a re-run can
    # tell whether anything actually changed.
    local want
    want="$(cat <<'EOF'
# Written by dotfiles bootstrap.sh (step_login).
[terminal]
vt = 1

[default_session]
user = "greeter"
command = "/usr/bin/dms-greeter --command hyprland"
EOF
)"
    if [ -f "$GREETD_CONFIG" ] && [ "$(sudo cat "$GREETD_CONFIG")" = "$want" ]; then
        log "greetd already configured, skipping"
    else
        log "Writing $GREETD_CONFIG"
        sudo install -d -m755 "$(dirname "$GREETD_CONFIG")"
        printf '%s\n' "$want" | sudo tee "$GREETD_CONFIG" >/dev/null
    fi

    # Copies this user's DMS theme and wallpaper into the greeter cache. Only
    # meaningful once DMS has settings to copy, so not fatal this early.
    if command -v dms-greeter >/dev/null 2>&1; then
        dms-greeter sync >/dev/null 2>&1 \
            || warn "dms-greeter sync failed — the greeter works, it just won't match your theme yet. Re-run 'dms-greeter sync' after DMS is configured."
    fi

    # enable, not --now: starting it here would seize vt1 and kill the terminal
    # this run is printing to.
    sudo systemctl enable greetd.service >/dev/null
}
