#!/bin/sh
# Points the initramfs fontconfig at the theme folder, where the splash fonts
# ship; the same path exists after the switch to the real root.
PREREQ="plymouth"
prereqs() { echo "$PREREQ"; }
case "$1" in prereqs)
    prereqs
    exit 0
    ;;
esac
[ -d "${DESTDIR}/etc/fonts/conf.d" ] || exit 0
cat >"${DESTDIR}/etc/fonts/conf.d/99-dotfiles-plymouth-fonts.conf" <<'CONF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig><dir>@PLYMOUTH_DIR@</dir></fontconfig>
CONF
