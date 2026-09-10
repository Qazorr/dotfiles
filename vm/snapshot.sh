#!/usr/bin/env bash
# Manage internal qcow2 snapshots of the VM disk, so a broken bootstrap.sh
# run can be reverted in seconds instead of reinstalling Debian.
#
# Usage:
#   ./snapshot.sh save <name>     # snapshot current disk state
#   ./snapshot.sh restore <name>  # revert disk to a saved snapshot
#   ./snapshot.sh list            # list snapshots
#   ./snapshot.sh delete <name>   # remove a snapshot
#
# Typical flow: install Debian -> shut down -> `save clean` -> run.sh,
# try bootstrap.sh -> if it breaks something, `restore clean` and retry.
set -euo pipefail
cd "$(dirname "$0")"

DISK=disk/debian13.qcow2
[ -f "$DISK" ] || { echo "no VM disk yet — run vm/install.sh first" >&2; exit 1; }
cmd="${1:-}"
name="${2:-}"

case "$cmd" in
  save)
    [ -n "$name" ] || { echo "usage: $0 save <name>" >&2; exit 1; }
    qemu-img snapshot -c "$name" "$DISK"
    ;;
  restore)
    [ -n "$name" ] || { echo "usage: $0 restore <name>" >&2; exit 1; }
    qemu-img snapshot -a "$name" "$DISK"
    ;;
  list)
    qemu-img snapshot -l "$DISK"
    ;;
  delete)
    [ -n "$name" ] || { echo "usage: $0 delete <name>" >&2; exit 1; }
    qemu-img snapshot -d "$name" "$DISK"
    ;;
  *)
    echo "usage: $0 {save|restore|list|delete} [name]" >&2
    exit 1
    ;;
esac
