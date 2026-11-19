#!/usr/bin/env bash
# boot/install.sh USER — as root: renders the themes from USER's wallpaper and
# DMS colours, and installs them if they changed.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${1:?usage: boot/install.sh USER}"
GRUB_DIR=/boot/grub/themes/dotfiles
PLYMOUTH_DIR=/usr/share/plymouth/themes/dotfiles
# Present only while the initramfs holds the installed splash.
BUILT=/var/lib/dotfiles-boot-theme.built

install -m644 "$SRC/plymouth/reject-fonts.conf" /etc/fonts/conf.d/99-dotfiles-plymouth.conf
ln -sfn "$(readlink -f "$(fc-match -f '%{file}')")" /usr/share/fonts/Plymouth.ttf
ln -sfn "$(readlink -f "$(fc-match -f '%{file}' monospace)")" /usr/share/fonts/Plymouth-monospace.ttf

# A changed hook leaves the initramfs out of date, whether or not the themes changed.
HOOK=/etc/initramfs-tools/hooks/dotfiles-plymouth-fonts
hook="$(sed "s|@PLYMOUTH_DIR@|$PLYMOUTH_DIR|g" "$SRC/plymouth/initramfs-hook.sh")"
if [ "$(cat "$HOOK" 2>/dev/null)" != "$hook" ]; then
    printf '%s\n' "$hook" >"$HOOK"
    chmod 755 "$HOOK"
    rm -f "$BUILT"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
chown "$USER_NAME" "$tmp"
runuser -u "$USER_NAME" -- env HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)" \
    "$SRC/build.sh" "$tmp/out"

if diff -rq "$tmp/out/grub" "$GRUB_DIR" >/dev/null 2>&1 \
    && diff -rq "$tmp/out/plymouth" "$PLYMOUTH_DIR" >/dev/null 2>&1 \
    && [ "$(plymouth-set-default-theme)" = dotfiles ] && [ -e "$BUILT" ]; then
    echo "boot themes unchanged"
    exit 0
fi

rm -f "$BUILT"
for pair in "grub:$GRUB_DIR" "plymouth:$PLYMOUTH_DIR"; do
    rm -rf "${pair#*:}"
    install -d "${pair#*:}"
    install -m644 "$tmp/out/${pair%%:*}"/* "${pair#*:}/"
done
plymouth-set-default-theme dotfiles
# The splash is read from the initramfs at boot; only the running kernel's.
update-initramfs -u
touch "$BUILT"
echo "boot themes updated"
