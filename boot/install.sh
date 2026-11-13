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

# The initramfs hook ships the fonts as these two names and fontconfig prefers
# them. The splash keeps that font list after it moves onto the real root,
# where the names don't exist, and text drawn from then on comes out as boxes.
# Fontconfig on the root must not see them, or the hook copies a link to itself.
cat > /etc/fonts/conf.d/99-dotfiles-plymouth.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <selectfont><rejectfont><glob>/usr/share/fonts/Plymouth*.ttf</glob></rejectfont></selectfont>
</fontconfig>
EOF
ln -sfn "$(readlink -f "$(fc-match -f '%{file}')")" /usr/share/fonts/Plymouth.ttf
ln -sfn "$(readlink -f "$(fc-match -f '%{file}' monospace)")" /usr/share/fonts/Plymouth-monospace.ttf

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
