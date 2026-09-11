# greetd is a tiny login daemon; dms-greeter is DankMaterialShell's own greeter
# for it, so the login screen matches the shell (it syncs DMS's theme, wallpaper
# and settings).
#
# The session entries in /usr/share/wayland-sessions are what actually start
# Hyprland, and Debian's hyprland.desktop is Exec=/usr/bin/start-hyprland.
# Launching the Hyprland binary directly earns a "started without
# start-hyprland" warning on every login.
register_step login \
    --desc "greetd + dms-greeter: DMS-themed login screen" \
    --group desktop --root --needs hyprland danklinux \
    --provides /etc/greetd/config.toml dms-greeter

step_login() {
    log "Installing greetd + dms-greeter"
    apt_install dms-greeter

    # The package's own command rather than a hand-written config.toml: it also
    # disables conflicting display managers and sets graphical.target. A bare
    # `systemctl enable greetd` does neither, and leaving getty@tty1 in play
    # puts two readers on one terminal — both echoing your keystrokes into
    # their own login prompt.
    #
    # Not wrapped in sudo: the tool escalates on its own, and bootstrap.sh has
    # already taken a sudo timestamp by now. -y skips its confirmation prompt;
    # bootstrap.sh's DMS_PRIVESC skips its sudo-vs-run0 picker, which -y does
    # not and which would otherwise stall the run.
    log "Enabling dms-greeter in greetd"
    dms-greeter enable -y

    getent passwd greeter >/dev/null 2>&1 \
        || die "dms-greeter is installed but the 'greeter' user is missing — its postinst did not complete."

    # The greeter runs a whole compositor, so it needs the DRM devices —
    # /dev/dri/card0 is root:video and renderD128 is root:render, both 0660.
    # Neither the package nor `dms-greeter enable` does this. Without it
    # Hyprland starts, fails to open a render node ("egl: failed to create
    # dri2 screen"), falls back to software, exits, and greetd burns through
    # its five restarts and leaves the tty to getty.
    log "Adding the greeter user to video/render/input"
    sudo usermod -aG video,render,input greeter

    # Copies this user's DMS theme and wallpaper into the greeter cache. Only
    # meaningful once DMS has settings worth copying, so not fatal this early.
    dms-greeter sync -y >/dev/null 2>&1 \
        || warn "dms-greeter sync failed — the greeter still works, it just won't match your theme. Re-run 'dms-greeter sync' once DMS is set up."

    # Deliberately not started here: it would seize vt1 and kill the terminal
    # this run is printing to. It comes up on the next boot.
    log "greetd is enabled; it takes over tty1 on the next reboot"
}
