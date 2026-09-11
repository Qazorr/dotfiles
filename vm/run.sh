#!/usr/bin/env bash
# Boot the installed Debian 13 VM (no installer ISO attached).
# Use this for day-to-day dotfiles testing.
set -euo pipefail
cd "$(dirname "$0")"

[ -f disk/debian13.qcow2 ] \
    || { echo "no VM disk yet — run vm/install.sh first" >&2; exit 1; }

# An array, not a backslash-continued command: a `#` comment after a trailing
# `\` silently comments out the REST of the command, which once dropped the
# network and -vga virtio here without any syntax error.
args=(
  -enable-kvm
  -machine q35
  -cpu host
  -smp 6
  -m 6G
  -drive file=disk/debian13.qcow2,if=virtio,cache=writeback
  -virtfs local,path=..,mount_tag=dotfiles,security_model=mapped-xattr,readonly=off
  # Pinned, and must match install.sh: qemu assigns PCI slots in command-line
  # order, so a device added here would otherwise rename the guest's NIC.
  -device virtio-net-pci,netdev=net0,addr=0x5
  -netdev user,id=net0,hostfwd=tcp::2222-:22
  # virtio-gpu, not the default stdvga: Hyprland needs a real DRM render node.
  -vga virtio
  -display gtk,gl=on
  -device virtio-tablet-pci
  -device intel-hda -device hda-duplex
)
exec qemu-system-x86_64 "${args[@]}" "$@"
