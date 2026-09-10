#!/usr/bin/env bash
# One-time: create the disk image if it's missing, then boot the Debian 13
# installer against it. After the install finishes, use run.sh from then on.
# Start over with: rm -f vm/disk/debian13.qcow2
#
# DOTFILES_TEST_ISO points this at a different image — that's how iso/build.sh's
# output gets tested before it goes anywhere near real hardware.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolved before the cd below, so a path relative to the repo root works —
# that's how iso/build.sh and both READMEs spell it.
ISO="${DOTFILES_TEST_ISO:-$HERE/iso/debian-13.6.0-amd64-netinst.iso}"
[ -f "$ISO" ] || [ ! -f "$HERE/$ISO" ] || ISO="$HERE/$ISO"
[ -f "$ISO" ] || { echo "no such ISO: $ISO" >&2; exit 1; }
ISO="$(readlink -f "$ISO")"

cd "$HERE"

# disk/ is gitignored, so it doesn't exist on a fresh clone and qemu-img won't
# create a missing parent.
DISK=disk/debian13.qcow2
if [ ! -f "$DISK" ]; then
    mkdir -p "$(dirname "$DISK")"
    qemu-img create -f qcow2 "$DISK" "${DOTFILES_VM_DISK_SIZE:-40G}"
fi

exec qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 6 \
  -m 6G \
  -drive file=disk/debian13.qcow2,if=virtio,cache=writeback \
  -cdrom "$ISO" \
  -boot d \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -vga virtio \
  -display gtk,gl=on \
  -device virtio-tablet-pci \
  -device intel-hda -device hda-duplex \
  "$@"
