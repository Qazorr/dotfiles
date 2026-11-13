#!/usr/bin/env bash
# boot/install.sh USER — as root: renders the themes from USER's wallpaper and
# DMS colours, and installs them if they changed.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${1:?usage: boot/install.sh USER}"
GRUB_DIR=/boot/grub/themes/dotfiles
PLYMOUTH_DIR=/usr/share/plymouth/themes/dotfiles

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
chown "$USER_NAME" "$tmp"
runuser -u "$USER_NAME" -- env HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)" \
    "$SRC/build.sh" "$tmp/out"

if diff -rq "$tmp/out/grub" "$GRUB_DIR" >/dev/null 2>&1 \
    && diff -rq "$tmp/out/plymouth" "$PLYMOUTH_DIR" >/dev/null 2>&1 \
    && [ "$(plymouth-set-default-theme)" = dotfiles ]; then
    echo "boot themes unchanged"
    exit 0
fi

for pair in "grub:$GRUB_DIR" "plymouth:$PLYMOUTH_DIR"; do
    rm -rf "${pair#*:}"
    install -d "${pair#*:}"
    install -m644 "$tmp/out/${pair%%:*}"/* "${pair#*:}/"
done
plymouth-set-default-theme dotfiles
# The splash is read from the initramfs at boot; only the running kernel's.
update-initramfs -u
echo "boot themes updated"
