#!/usr/bin/env bash
# Remasters the Debian 13 netinst image into one that installs this repo:
# iso/config answers the installer's questions, the repo rides along as a git
# bundle, and the first boot runs bootstrap.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$REPO/lib/common.sh"

OUT="${1:-$HERE/out/dotfiles-trixie-amd64.iso}"
CDIMAGE=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd

# shellcheck source=config
source "$HERE/config"
# shellcheck source=/dev/null
[ -f "$HERE/config.local" ] && source "$HERE/config.local"

# Whole-disk install erases INSTALL_DISK without a question, on whatever machine boots
# the ISO. Ask for the disk twice so a stale or mistyped value can't wipe a data disk.
if [ -n "${INSTALL_DISK:-}" ] && [ "${INSTALL_DISK_ERASE:-}" != "$INSTALL_DISK" ]; then
    die "INSTALL_DISK=$INSTALL_DISK erases that whole disk unasked. Leave it empty to partition by hand, or also set INSTALL_DISK_ERASE=\"$INSTALL_DISK\" to confirm."
fi

for tool in xorriso cpio gzip curl git sha256sum; do
    command -v "$tool" >/dev/null || die "$tool is not installed — sudo apt install xorriso cpio curl git"
done

BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" != HEAD ] || die "detached HEAD — check out the branch the installed machine should follow"
REPO_URL="$(git -C "$REPO" remote get-url origin 2>/dev/null)" \
    || die "no origin remote — the installed machine would have nowhere to push"
GIT_NAME="$(git -C "$REPO" config user.name || true)"
GIT_EMAIL="$(git -C "$REPO" config user.email || true)"
if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
    warn "uncommitted changes are NOT on the ISO — it carries $BRANCH as committed ($(git -C "$REPO" rev-parse --short HEAD))"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

base_iso() {
    local sums name sum
    sums="$(curl -fsSL "$CDIMAGE/SHA256SUMS")" || die "can't reach $CDIMAGE"
    read -r sum name < <(grep -E ' debian-[0-9.]+-amd64-netinst\.iso$' <<<"$sums") \
        || die "no netinst image listed in $CDIMAGE/SHA256SUMS"
    mkdir -p "$HERE/cache"
    if ! echo "$sum  $HERE/cache/$name" | sha256sum -c --quiet - 2>/dev/null; then
        log "Downloading $name" >&2
        curl -fL --retry 3 -o "$HERE/cache/$name" "$CDIMAGE/$name" >&2
        echo "$sum  $HERE/cache/$name" | sha256sum -c --quiet - >&2 \
            || die "$name: checksum mismatch"
    fi
    printf '%s' "$HERE/cache/$name"
}

# iso/preseed.cfg, plus whichever optional answers iso/config fills in.
preseed() {
    render "$HERE/preseed.cfg" LOCALE="$INSTALL_LOCALE" KEYMAP="$INSTALL_KEYMAP" \
        TIMEZONE="$INSTALL_TIMEZONE"
    if [ -n "$INSTALL_HOSTNAME" ]; then
        printf 'd-i netcfg/get_hostname string %s\n' "$INSTALL_HOSTNAME"
        printf 'd-i netcfg/hostname string %s\n' "$INSTALL_HOSTNAME"
    fi
    [ -z "$INSTALL_FULLNAME" ] || printf 'd-i passwd/user-fullname string %s\n' "$INSTALL_FULLNAME"
    [ -z "$INSTALL_USER" ] || printf 'd-i passwd/username string %s\n' "$INSTALL_USER"
    [ -z "$INSTALL_PASSWORD_HASH" ] \
        || printf 'd-i passwd/user-password-crypted password %s\n' "$INSTALL_PASSWORD_HASH"
    [ -z "$INSTALL_DISK" ] || render "$HERE/preseed-disk.cfg" DISK="$INSTALL_DISK"
}

BOOT_ARGS="auto=true priority=high"

BASE="$(base_iso)"
log "Base image: $BASE"

log "Extracting the installer's initrd"
xorriso -osirrox on -indev "$BASE" \
    -extract /install.amd/initrd.gz "$WORK/initrd.gz" >/dev/null 2>&1 \
    || die "couldn't read $BASE — is it a Debian netinst image?"
chmod u+w "$WORK/initrd.gz"

# The kernel unpacks concatenated archives in order, so appending is enough
# to put /preseed.cfg in the installer's root.
mkdir "$WORK/initrd-add"
preseed >"$WORK/initrd-add/preseed.cfg"
(cd "$WORK/initrd-add" && echo preseed.cfg | cpio --quiet -H newc -o | gzip -9) >>"$WORK/initrd.gz"

log "Bundling $BRANCH at $(git -C "$REPO" rev-parse --short HEAD)"
mkdir "$WORK/dotfiles"
git -C "$REPO" bundle create --quiet "$WORK/dotfiles/repo.bundle" HEAD "$BRANCH"
cp "$HERE/late.sh" "$HERE/firstboot.sh" "$HERE/dotfiles-firstboot.service" "$WORK/dotfiles/"
{
    printf 'BRANCH=%q\n' "$BRANCH"
    printf 'REPO_URL=%q\n' "$REPO_URL"
    printf 'GIT_NAME=%q\n' "$GIT_NAME"
    printf 'GIT_EMAIL=%q\n' "$GIT_EMAIL"
    printf 'PROFILE=%q\n' "$INSTALL_PROFILE"
    printf 'STEPS=%q\n' "$INSTALL_STEPS"
} >"$WORK/dotfiles/firstboot.conf"

render "$HERE/grub.cfg" BOOT_ARGS="$BOOT_ARGS" >"$WORK/grub.cfg"
render "$HERE/isolinux.cfg" BOOT_ARGS="$BOOT_ARGS" >"$WORK/isolinux.cfg"

log "Writing $OUT"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
# `replay` rebuilds the BIOS and UEFI boot records exactly as the base image
# has them.
xorriso -indev "$BASE" -outdev "$OUT" \
    -boot_image any replay \
    -map "$WORK/initrd.gz" /install.amd/initrd.gz \
    -map "$WORK/grub.cfg" /boot/grub/grub.cfg \
    -map "$WORK/isolinux.cfg" /isolinux/isolinux.cfg \
    -map "$WORK/dotfiles" /dotfiles \
    -chown_r 0 /dotfiles -- -chgrp_r 0 /dotfiles -- \
    >"$WORK/xorriso.log" 2>&1 \
    || {
        cat "$WORK/xorriso.log" >&2
        die "xorriso failed"
    }

log "Built $OUT ($(du -h "$OUT" | cut -f1))"
printf '\n    sudo dd if=%s of=/dev/sdX bs=4M status=progress oflag=sync\n' "$OUT"
# dd erases the target completely: show which disks are USB so the right one is picked.
printf '\nUSB disks now (pick the stick for /dev/sdX; everything on it is lost):\n'
lsblk -o NAME,SIZE,TRAN,MODEL,LABEL -e 7 \
    | awk 'NR == 1 { print; next } /^[a-z]/ { usb = ($3 == "usb") } usb' | sed 's/^/    /'

printf '    vm/install.sh    try it in a VM first\n'
