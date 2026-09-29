#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[ -f disk/debian13.qcow2 ] \
    || { echo "no VM disk yet — run vm/install.sh first" >&2; exit 1; }

# `-vga virtio` is 2D-only and can come up black. If the VM shows nothing:
# DOTFILES_VM_GPU=VGA DOTFILES_VM_DISPLAY=gtk vm/run.sh
VM_GPU="${DOTFILES_VM_GPU:-virtio-vga-gl}"
VM_DISPLAY="${DOTFILES_VM_DISPLAY:-gtk,gl=on}"

# shellcheck disable=SC2054  # commas belong to qemu's argument syntax
# An array: a `#` in a backslash-continued command once dropped the network.
args=(
  -enable-kvm
  -machine q35
  -cpu host
  -smp 6
  -m 6G
  -drive file=disk/debian13.qcow2,if=virtio,cache=writeback
  -virtfs local,path=..,mount_tag=dotfiles,security_model=mapped-xattr,readonly=off
  # Must match install.sh, or the guest's NIC gets renamed.
  -device virtio-net-pci,netdev=net0,addr=0x5
  -netdev user,id=net0,hostfwd=tcp::2222-:22
  -vga none
  -device "$VM_GPU"
  -display "$VM_DISPLAY"
  -device virtio-tablet-pci
  -device intel-hda -device hda-duplex
)
exec qemu-system-x86_64 "${args[@]}" "$@"
