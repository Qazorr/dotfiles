#!/usr/bin/env bash
# Boot the installed Debian 13 VM (no installer ISO attached).
# Use this for day-to-day dotfiles testing.
set -euo pipefail
cd "$(dirname "$0")"

[ -f disk/debian13.qcow2 ] \
    || { echo "no VM disk yet — run vm/install.sh first" >&2; exit 1; }

exec qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 6 \
  -m 6G \
  -drive file=disk/debian13.qcow2,if=virtio,cache=writeback \
  -virtfs local,path=..,mount_tag=dotfiles,security_model=mapped-xattr,readonly=off \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -vga virtio \
  -display gtk,gl=on \
  -device virtio-tablet-pci \
  -device intel-hda -device hda-duplex \
  "$@"
