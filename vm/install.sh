#!/usr/bin/env bash
# One-time: create the disk image if it's missing, then boot the Debian 13
# installer against it. `once=d` so the post-install reboot goes to the disk
# rather than back into the installer. Use run.sh from then on.
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

# An array, not a backslash-continued command — see the note in run.sh.
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
  # Pinned, matching run.sh (which has an extra -virtfs device ahead of this
  # one) — a fixed address keeps the interface name stable across scripts;
  # otherwise /etc/network/interfaces names one that doesn't exist.
  -device virtio-net-pci,netdev=net0,addr=0x5
  -netdev user,id=net0
  -vga none
  -device "$VM_GPU"
  -display "$VM_DISPLAY"
  -device virtio-tablet-pci
  -device intel-hda -device hda-duplex
)
exec qemu-system-x86_64 "${args[@]}" "$@"
