#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

ISO="${DOTFILES_TEST_ISO:-$HERE/iso/debian-13.6.0-amd64-netinst.iso}"
[ -f "$ISO" ] || [ ! -f "$HERE/$ISO" ] || ISO="$HERE/$ISO"
[ -f "$ISO" ] || { echo "no such ISO: $ISO" >&2; exit 1; }
ISO="$(readlink -f "$ISO")"

cd "$HERE"

DISK=disk/debian13.qcow2
if [ ! -f "$DISK" ]; then
    mkdir -p "$(dirname "$DISK")"
    qemu-img create -f qcow2 "$DISK" "${DOTFILES_VM_DISK_SIZE:-40G}"
fi

VM_GPU="${DOTFILES_VM_GPU:-virtio-vga-gl}"
VM_DISPLAY="${DOTFILES_VM_DISPLAY:-gtk,gl=on}"

# shellcheck disable=SC2054  # commas belong to qemu's argument syntax
args=(
  -enable-kvm
  -machine q35
  -cpu host
  -smp 6
  -m 6G
  -drive file=disk/debian13.qcow2,if=virtio,cache=writeback
  -cdrom "$ISO"
  -boot once=d
  -device virtio-net-pci,netdev=net0,addr=0x5
  -netdev user,id=net0
  -vga none
  -device "$VM_GPU"
  -display "$VM_DISPLAY"
  -device virtio-tablet-pci
  -device intel-hda -device hda-duplex
)
exec qemu-system-x86_64 "${args[@]}" "$@"
