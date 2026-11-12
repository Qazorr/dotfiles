#!/bin/sh
# The installer's late_command. Runs in the installer, not the installed
# system: /cdrom is this ISO, /target the new root.
set -eu

SRC=/cdrom/dotfiles
# shellcheck source=/dev/null
. "$SRC/firstboot.conf"

user="$(awk -F: '$3 == 1000 { print $1 }' /target/etc/passwd)"
[ -n "$user" ] || { echo "dotfiles: the installer created no user" >&2; exit 1; }

cp "$SRC/repo.bundle" /target/tmp/dotfiles.bundle
chmod 644 /target/tmp/dotfiles.bundle
in-target su - "$user" -c "git clone --quiet --branch '$BRANCH' /tmp/dotfiles.bundle ~/dotfiles"
in-target su - "$user" -c "git -C ~/dotfiles remote set-url origin '$REPO_URL'"
[ -z "$GIT_NAME" ]  || in-target su - "$user" -c "git -C ~/dotfiles config user.name '$GIT_NAME'"
[ -z "$GIT_EMAIL" ] || in-target su - "$user" -c "git -C ~/dotfiles config user.email '$GIT_EMAIL'"
rm -f /target/tmp/dotfiles.bundle

cp "$SRC/firstboot.conf" /target/etc/dotfiles-firstboot.conf
cp "$SRC/firstboot.sh" /target/usr/local/sbin/dotfiles-firstboot
chmod 755 /target/usr/local/sbin/dotfiles-firstboot
cp "$SRC/dotfiles-firstboot.service" /target/etc/systemd/system/
in-target systemctl enable dotfiles-firstboot.service
