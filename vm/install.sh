#!/usr/bin/env bash
# One-time: boot the Debian 13 installer against the empty disk image.
# After install completes and the VM shuts itself down, use run.sh from then on.
#
# DOTFILES_TEST_ISO points this at a different image — that's how iso/build.sh's
# output gets tested before it goes anywhere near real hardware.
set -euo pipefail
cd "$(dirname "$0")"

ISO="${DOTFILES_TEST_ISO:-iso/debian-13.6.0-amd64-netinst.iso}"
[ -f "$ISO" ] || { echo "no such ISO: $ISO" >&2; exit 1; }

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
