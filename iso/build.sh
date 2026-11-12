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

for tool in xorriso cpio gzip curl git sha256sum md5sum; do
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

write_preseed() {
    cat <<EOF
d-i debian-installer/locale string $INSTALL_LOCALE
d-i keyboard-configuration/xkb-keymap select $INSTALL_KEYMAP

d-i netcfg/choose_interface select auto
d-i netcfg/get_domain string
d-i hw-detect/load_firmware boolean true

d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

d-i passwd/root-login boolean false

d-i clock-setup/utc boolean true
d-i time/zone string $INSTALL_TIMEZONE
d-i clock-setup/ntp boolean true

d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/disable-cdrom-entries boolean true
d-i apt-setup/use_mirror boolean true
d-i apt-setup/contrib boolean true
d-i apt-setup/non-free boolean true
d-i apt-setup/non-free-firmware boolean true

tasksel tasksel/first multiselect standard
# network-manager here makes the installer hand its network setup, Wi-Fi
# password included, to NetworkManager instead of /etc/network/interfaces.
d-i pkgsel/include string git sudo curl ca-certificates network-manager
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false

d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

d-i finish-install/reboot_in_progress note
d-i preseed/late_command string sh /cdrom/dotfiles/late.sh
EOF
    if [ -n "$INSTALL_HOSTNAME" ]; then
        printf 'd-i netcfg/get_hostname string %s\n' "$INSTALL_HOSTNAME"
        printf 'd-i netcfg/hostname string %s\n' "$INSTALL_HOSTNAME"
    fi
    [ -z "$INSTALL_FULLNAME" ] || printf 'd-i passwd/user-fullname string %s\n' "$INSTALL_FULLNAME"
    [ -z "$INSTALL_USER" ]     || printf 'd-i passwd/username string %s\n' "$INSTALL_USER"
    [ -z "$INSTALL_PASSWORD_HASH" ] \
        || printf 'd-i passwd/user-password-crypted password %s\n' "$INSTALL_PASSWORD_HASH"
    if [ -n "$INSTALL_DISK" ]; then
        cat <<EOF
d-i partman-auto/disk string $INSTALL_DISK
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
EOF
    fi
}

BOOT_ARGS="auto=true priority=high"

write_grub_cfg() {
    cat <<EOF
if loadfont \$prefix/font.pf2 ; then
  set gfxmode=800x600
  set gfxpayload=keep
  insmod efi_gop
  insmod efi_uga
  insmod gfxterm
  terminal_output gfxterm
fi
set timeout=5
set default=0

menuentry 'Install Debian 13 + dotfiles' {
    linux    /install.amd/vmlinuz $BOOT_ARGS --- quiet
    initrd   /install.amd/initrd.gz
}
EOF
}

write_isolinux_cfg() {
    cat <<EOF
path
default vesamenu.c32
prompt 0
timeout 50
menu title Debian 13 + dotfiles
label install
	menu label ^Install Debian 13 + dotfiles
	menu default
	kernel /install.amd/vmlinuz
	append $BOOT_ARGS vga=788 initrd=/install.amd/initrd.gz --- quiet
EOF
}

BASE="$(base_iso)"
log "Base image: $BASE"

log "Extracting the installer's initrd"
xorriso -osirrox on -indev "$BASE" \
    -extract /install.amd/initrd.gz "$WORK/initrd.gz" \
    -extract /md5sum.txt "$WORK/md5sum.txt" >/dev/null 2>&1 \
    || die "couldn't read $BASE — is it a Debian netinst image?"
chmod u+w "$WORK/initrd.gz" "$WORK/md5sum.txt"

# The kernel unpacks concatenated archives in order, so appending is enough
# to put /preseed.cfg in the installer's root.
mkdir "$WORK/initrd-add"
write_preseed > "$WORK/initrd-add/preseed.cfg"
( cd "$WORK/initrd-add" && echo preseed.cfg | cpio --quiet -H newc -o | gzip -9 ) >> "$WORK/initrd.gz"

log "Bundling $BRANCH at $(git -C "$REPO" rev-parse --short HEAD)"
mkdir "$WORK/dotfiles"
git -C "$REPO" bundle create --quiet "$WORK/dotfiles/repo.bundle" HEAD "$BRANCH"
cp "$HERE/late.sh" "$HERE/firstboot.sh" "$HERE/dotfiles-firstboot.service" "$WORK/dotfiles/"
{
    printf 'BRANCH=%q\n'    "$BRANCH"
    printf 'REPO_URL=%q\n'  "$REPO_URL"
    printf 'GIT_NAME=%q\n'  "$GIT_NAME"
    printf 'GIT_EMAIL=%q\n' "$GIT_EMAIL"
    printf 'PROFILE=%q\n'   "$INSTALL_PROFILE"
    printf 'STEPS=%q\n'     "$INSTALL_STEPS"
} > "$WORK/dotfiles/firstboot.conf"

write_grub_cfg     > "$WORK/grub.cfg"
write_isolinux_cfg > "$WORK/isolinux.cfg"

# md5sum.txt is what the installer's "verify the media" checks.
maps=(
    "$WORK/initrd.gz"     /install.amd/initrd.gz
    "$WORK/grub.cfg"      /boot/grub/grub.cfg
    "$WORK/isolinux.cfg"  /isolinux/isolinux.cfg
)
for f in "$WORK"/dotfiles/*; do
    maps+=("$f" "/dotfiles/${f##*/}")
done
map_args=()
for ((i = 0; i < ${#maps[@]}; i += 2)); do
    src="${maps[i]}" dst="${maps[i + 1]}"
    map_args+=(-map "$src" "$dst")
    grep -vF "  .$dst" "$WORK/md5sum.txt" > "$WORK/md5sum.new" || true
    printf '%s  .%s\n' "$(md5sum < "$src" | cut -d' ' -f1)" "$dst" >> "$WORK/md5sum.new"
    mv "$WORK/md5sum.new" "$WORK/md5sum.txt"
done

log "Writing $OUT"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
# `replay` rebuilds the BIOS and UEFI boot records exactly as the base image
# has them.
xorriso -indev "$BASE" -outdev "$OUT" \
    -boot_image any replay \
    "${map_args[@]}" \
    -map "$WORK/md5sum.txt" /md5sum.txt \
    -chown_r 0 /dotfiles -- -chgrp_r 0 /dotfiles -- \
    >"$WORK/xorriso.log" 2>&1 \
    || { cat "$WORK/xorriso.log" >&2; die "xorriso failed"; }

log "Built $OUT ($(du -h "$OUT" | cut -f1))"
asked=()
[ -n "$INSTALL_HOSTNAME" ]      || asked+=(hostname)
[ -n "$INSTALL_USER" ]          || asked+=(user)
[ -n "$INSTALL_PASSWORD_HASH" ] || asked+=(password)
[ -n "$INSTALL_DISK" ]          || asked+=(partitioning)
if [ ${#asked[@]} -gt 0 ]; then
    log "The installer will ask for: ${asked[*]}"
else
    warn "Fully unattended: booting this erases $INSTALL_DISK without a question."
fi
printf '\n    sudo dd if=%s of=/dev/sdX bs=4M status=progress oflag=sync\n' "$OUT"
printf '    vm/install.sh    try it in a VM first\n'
