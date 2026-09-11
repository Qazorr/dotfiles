#!/usr/bin/env bash
# Boot the installed Debian 13 VM (no installer ISO attached).
# Use this for day-to-day dotfiles testing.
set -euo pipefail
cd "$(dirname "$0")"

[ -f disk/debian13.qcow2 ] \
    || { echo "no VM disk yet — run vm/install.sh first" >&2; exit 1; }

# An array, not a backslash-continued command: a `#` after a trailing `\`
# silently comments out the rest of the command — this once dropped the
# network and -vga virtio with no syntax error.
# virtio-vga-gl, not `-vga virtio`: the latter is 2D-only, so gl=on gives no
# 3D — Mesa falls back to llvmpipe and the window can come up black.
#
# If the VM shows nothing, fall back to software rendering (still boots,
# ssh still forwards on 2222):
#   DOTFILES_VM_GPU=VGA DOTFILES_VM_DISPLAY=gtk vm/run.sh
VM_GPU="${DOTFILES_VM_GPU:-virtio-vga-gl}"
VM_DISPLAY="${DOTFILES_VM_DISPLAY:-gtk,gl=on}"

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
  -vga none
  -device "$VM_GPU"
  -display "$VM_DISPLAY"
  -device virtio-tablet-pci
  -device intel-hda -device hda-duplex
)
exec qemu-system-x86_64 "${args[@]}" "$@"
