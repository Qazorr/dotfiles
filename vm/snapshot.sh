#!/usr/bin/env bash
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
