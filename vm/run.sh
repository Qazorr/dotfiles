#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[ -f disk/debian13.qcow2 ] \
    || { echo "no VM disk yet — run vm/install.sh first" >&2; exit 1; }

# virtio-vga-gl, not `-vga virtio`: the latter is 2D-only, so gl=on gives no 3D,
# Mesa falls back to llvmpipe and the window can come up black. If the VM shows
# nothing: DOTFILES_VM_GPU=VGA DOTFILES_VM_DISPLAY=gtk vm/run.sh
VM_GPU="${DOTFILES_VM_GPU:-virtio-vga-gl}"
VM_DISPLAY="${DOTFILES_VM_DISPLAY:-gtk,gl=on}"

# shellcheck disable=SC2054  # commas belong to qemu's argument syntax
# An array, not a backslash-continued command: a `#` after a trailing `\`
# silently comments out the rest, which once dropped the network and the GPU
# with no syntax error.
args=(
  -enable-kvm
  -machine q35
  -cpu host
  -smp 6
  -m 6G
  -drive file=disk/debian13.qcow2,if=virtio,cache=writeback
  -virtfs local,path=..,mount_tag=dotfiles,security_model=mapped-xattr,readonly=off
  # Pinned, and must match install.sh: qemu assigns PCI slots in command-line
  # order, so a device added here would rename the guest's NIC.
  -device virtio-net-pci,netdev=net0,addr=0x5
  -netdev user,id=net0,hostfwd=tcp::2222-:22
  -vga none
  -device "$VM_GPU"
  -display "$VM_DISPLAY"
  -device virtio-tablet-pci
  -device intel-hda -device hda-duplex
)
exec qemu-system-x86_64 "${args[@]}" "$@"
