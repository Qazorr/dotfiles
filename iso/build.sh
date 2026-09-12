#!/usr/bin/env bash
# Build a Debian 13 netinst ISO with this repo already on it. See iso/README.md.
#
#   ./iso/build.sh
#
# Ships the private repo as a git bundle (no install-time credentials needed);
# preseed/late_command clones it into ~/dotfiles. Doesn't run bootstrap.sh —
# leaves a motd saying to. Adds one boot entry, "Install Debian + dotfiles";
# partitioning/disk/username stay interactive on purpose.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$REPO/lib/common.sh"

DEBIAN_VERSION="${DOTFILES_DEBIAN_VERSION:-13.6.0}"
SRC_ISO="${DOTFILES_NETINST_ISO:-$REPO/vm/iso/debian-$DEBIAN_VERSION-amd64-netinst.iso}"
OUT_ISO="${DOTFILES_ISO_OUT:-$REPO/vm/iso/debian-$DEBIAN_VERSION-amd64-dotfiles.iso}"
MIRROR="https://cdimage.debian.org/debian-cd/$DEBIAN_VERSION/amd64/iso-cd"

command -v xorriso >/dev/null 2>&1 \
    || die "xorriso is not installed. sudo apt install xorriso"
command -v git >/dev/null 2>&1 || die "git is not installed."

# A bundle carries commits, not the working tree — a dirty build ships an ISO
# quietly missing your latest work.
if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
    if [ "${DOTFILES_ISO_ALLOW_DIRTY:-0}" = "1" ]; then
        warn "working tree is dirty — the ISO will ship the last COMMIT, not what's on disk"
    else
        git -C "$REPO" status --short >&2
        die "uncommitted changes: the ISO would ship the last commit instead. Commit them, or set DOTFILES_ISO_ALLOW_DIRTY=1 if that's what you want."
    fi
fi

# --- source ISO ------------------------------------------------------------
if [ ! -f "$SRC_ISO" ]; then
    log "Downloading Debian $DEBIAN_VERSION netinst"
    mkdir -p "$(dirname "$SRC_ISO")"
    curl -fL --progress-bar -o "$SRC_ISO" \
        "$MIRROR/debian-$DEBIAN_VERSION-amd64-netinst.iso" \
        || { rm -f "$SRC_ISO"; die "download failed"; }
fi

# This becomes a bootable image; a truncated download fails much later and
# far more confusingly.
log "Verifying the source ISO checksum"
expected="$(curl -fsSL "$MIRROR/SHA256SUMS" \
    | awk -v f="debian-$DEBIAN_VERSION-amd64-netinst.iso" '$2 == f || $2 == "*"f {print $1}')"
[ -n "$expected" ] || die "couldn't find a published checksum for debian-$DEBIAN_VERSION-amd64-netinst.iso"
actual="$(sha256sum "$SRC_ISO" | cut -d' ' -f1)"
[ "$expected" = "$actual" ] \
    || die "checksum mismatch on $SRC_ISO — delete it and re-run to fetch a fresh copy."

# --- unpack ----------------------------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
tree="$work/iso"

log "Unpacking $SRC_ISO"
xorriso -osirrox on -indev "$SRC_ISO" -extract / "$tree" >/dev/null 2>&1
# xorriso extracts read-only, matching the ISO.
chmod -R u+w "$tree"

# The source ISO's first 432 bytes are its MBR — keeps the result BIOS-bootable
# as well as UEFI.
dd if="$SRC_ISO" bs=1 count=432 of="$work/isohdpfx.bin" status=none

# Debian's layout has drifted before. Fail here rather than emit an ISO that
# doesn't boot. install.amd/gtk/* is the graphical (GTK) frontend's own
# kernel+initrd, separate from the text frontend's install.amd/*.
for f in isolinux/isolinux.bin boot/grub/efi.img isolinux/isolinux.cfg \
    boot/grub/grub.cfg install.amd/gtk/vmlinuz install.amd/gtk/initrd.gz; do
    [ -f "$tree/$f" ] || die "$f missing from the source ISO — Debian's layout changed, this script needs updating."
done

# --- payload ---------------------------------------------------------------
log "Bundling the repo ($(git -C "$REPO" rev-parse --abbrev-ref HEAD) @ $(git -C "$REPO" log --oneline -1))"
git -C "$REPO" bundle create "$tree/dotfiles.bundle" --all >/dev/null
cp "$HERE/preseed.cfg" "$tree/"

# --- boot menus ------------------------------------------------------------
# Written to isolinux (BIOS) and grub (UEFI) — which one runs depends on how
# the machine boots.
log "Adding boot entries"
# No auto=true: it's the Automated-install mechanism, and its documented
# effect is delaying the locale/keyboard questions until a network-fetched
# preseed has had a chance to answer them (installation guide B.2.3). Ours
# comes off the CD and we want an interactive install, so it buys nothing.
#
# priority=medium asks strictly more than the installer's default of high —
# it can only add prompts, never skip one.
common_args="priority=medium"

# Graphical (GTK) frontend, not the text/newt one: a proper wizard — mouse
# and keyboard, a real network/WiFi picker — instead of the ncurses main-menu
# screen, which drops back to itself after every step once anything (like
# loading preseed.cfg) doesn't go perfectly. Same preseed support either way.
#
# gtk.cfg claims the default before txt.cfg is even included, so an appended
# `menu default` below would lose and Enter would boot stock, un-preseeded
# Debian. Drop its claim so ours is the only one.
sed -i -e '/^default installgui$/d' -e '/^[[:space:]]*menu default$/d' \
    "$tree/isolinux/gtk.cfg"

cat >> "$tree/isolinux/gtk.cfg" <<EOF

label dotfiles
    menu label ^Install Debian + dotfiles
    menu default
    kernel /install.amd/gtk/vmlinuz
    append vga=788 initrd=/install.amd/gtk/initrd.gz preseed/file=/cdrom/preseed.cfg $common_args ---

default dotfiles
EOF

cat >> "$tree/boot/grub/grub.cfg" <<EOF

menuentry 'Install Debian + dotfiles' {
    set background_color=black
    linux /install.amd/gtk/vmlinuz preseed/file=/cdrom/preseed.cfg $common_args ---
    initrd /install.amd/gtk/initrd.gz
}
# grub.cfg is sourced whole before the menu draws, so this overrides the
# implicit entry 0 ('Graphical install'). Same reasoning as isolinux above.
set default='Install Debian + dotfiles'
EOF

# Otherwise the installer's optional integrity check fails on the files we
# just changed.
if [ -f "$tree/md5sum.txt" ]; then
    ( cd "$tree" && find . -type f ! -name md5sum.txt -print0 \
        | xargs -0 md5sum > md5sum.txt )
fi

# --- repack ----------------------------------------------------------------
# Flag set per Debian's RepackBootableISO wiki page; its files checked above.
log "Building $OUT_ISO"
mkdir -p "$(dirname "$OUT_ISO")"
xorriso -as mkisofs \
    -r -V "Debian $DEBIAN_VERSION dotfiles" \
    -o "$OUT_ISO" \
    -J -joliet-long -cache-inodes \
    -isohybrid-mbr "$work/isohdpfx.bin" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 -boot-info-table -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    "$tree" >/dev/null 2>&1

log "Done: $OUT_ISO"
cat <<EOF

Test it in the VM before touching real hardware:

    rm -f vm/disk/debian13.qcow2        # only if you want a clean disk
    DOTFILES_TEST_ISO="$OUT_ISO" vm/install.sh

Pick "Install Debian + dotfiles" — it is the default, but the menu's speech-
synthesis countdown will boot something else if you let it lapse, so press a
key. On real hardware, write it with:

    sudo dd if="$OUT_ISO" of=/dev/sdX bs=4M status=progress oflag=sync

Partitioning and your username are asked either way.
EOF
