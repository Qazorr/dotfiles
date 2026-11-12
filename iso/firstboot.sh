#!/bin/bash
# Installed as /usr/local/sbin/dotfiles-firstboot by late.sh, run as root by
# dotfiles-firstboot.service on every boot until bootstrap.sh has succeeded.
set -u

CONF=/etc/dotfiles-firstboot.conf
# shellcheck source=/dev/null
. "$CONF"

user="$(getent passwd 1000 | cut -d: -f1)"
sudoers=/etc/sudoers.d/dotfiles-firstboot

say() { printf '\n\033[1;35m[dotfiles]\033[0m %s\n' "$*"; }

cleanup() {
    rm -f "$sudoers"
    loginctl disable-linger "$user" 2>/dev/null
}
trap cleanup EXIT

say "Finishing the install. This takes 15-20 minutes and reboots when it is done."

for _ in $(seq 60); do
    getent hosts deb.debian.org >/dev/null 2>&1 && break
    sleep 2
done

# bootstrap.sh runs as the user and calls sudo itself.
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$user" > "$sudoers"
chmod 0440 "$sudoers"

# A user manager, for the steps that call systemctl --user.
loginctl enable-linger "$user"
for _ in $(seq 20); do
    [ -S "/run/user/1000/bus" ] && break
    sleep 0.5
done

as_user() {
    runuser -l "$user" -c "export TERM=linux XDG_RUNTIME_DIR=/run/user/1000 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus GIT_TERMINAL_PROMPT=0; $*" </dev/null
}

# An old ISO still installs the current repo.
as_user "git -C ~/dotfiles pull --ff-only --quiet" \
    || say "couldn't update ~/dotfiles — installing the version on the ISO"

# shellcheck disable=SC2153  # PROFILE and STEPS come from $CONF
as_user "cd ~/dotfiles && ./bootstrap.sh --yes --profile $PROFILE $STEPS"
rc=$?

if [ "$rc" != "0" ]; then
    say "bootstrap.sh failed (exit $rc). It runs again on the next boot, and picks up where it stopped."
    say "Or log in and run ~/dotfiles/bootstrap.sh yourself. To stop the retries: sudo rm $CONF"
    exit "$rc"
fi

rm -f "$CONF"
systemctl disable dotfiles-firstboot.service >/dev/null 2>&1
say "Done. Rebooting in 10 seconds."
sleep 10
systemctl --no-block reboot
