#!/usr/bin/env bash
# Run this INSIDE the test VM, once, after installing:
#
#   ~/dotfiles/vm/guest-setup.sh
#
# Makes the guest debuggable from the host. None of this belongs on a real
# machine, which is why it is here and not a bootstrap step.
#
#   - 9p share of the host's repo at /mnt/host, across reboots
#   - persistent journal, so `journalctl -b -1` survives a reboot. Without it
#     every crash investigation starts after the evidence is gone.
#   - lingering, so /run/user/$UID outlives the session — that is where
#     Hyprland writes hyprland.log, and it is wiped when the session ends
#   - the host's key in authorized_keys, so the host can ssh in on :2222
#   - you in `adm`, so journalctl needs no sudo
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

[ "$EUID" -ne 0 ] || { echo "Run as your normal user, not root." >&2; exit 1; }
sudo -v

# --- host share ------------------------------------------------------------
# mount -t 9p pulls in the 9p module but not the virtio transport, so without
# this the mount fails with "special device dotfiles does not exist".
if ! lsmod | grep -q '^9pnet_virtio'; then
    log "Loading 9pnet_virtio"
    sudo modprobe 9pnet_virtio
fi
grep -qx 9pnet_virtio /etc/modules 2>/dev/null \
    || echo 9pnet_virtio | sudo tee -a /etc/modules >/dev/null

sudo mkdir -p /mnt/host
if ! grep -q '^dotfiles /mnt/host ' /etc/fstab 2>/dev/null; then
    log "Adding the 9p share to /etc/fstab"
    echo 'dotfiles /mnt/host 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail 0 0' \
        | sudo tee -a /etc/fstab >/dev/null
fi
mountpoint -q /mnt/host || sudo mount /mnt/host \
    || warn "couldn't mount the 9p share — is the VM running under vm/run.sh?"

# --- logs that survive a reboot -------------------------------------------
if [ ! -d /var/log/journal ]; then
    log "Making the journal persistent"
    sudo mkdir -p /var/log/journal
    sudo systemd-tmpfiles --create --prefix /var/log/journal
    sudo systemctl kill --kill-who=main --signal=SIGUSR1 systemd-journald
fi

id -nG | grep -qw adm || { log "Adding $USER to adm (journalctl without sudo)"; sudo usermod -aG adm "$USER"; }

# Hyprland logs to $XDG_RUNTIME_DIR/hypr/<sig>/hyprland.log, and that whole
# tree is removed when your last session ends — which is exactly when a
# compositor crash is worth reading. Lingering keeps it.
loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes' \
    || { log "Enabling lingering (keeps /run/user/$UID, and Hyprland's log, after logout)"; sudo loginctl enable-linger "$USER"; }

# --- host ssh access -------------------------------------------------------
pub=/mnt/host/vm/host-access/id_ed25519.pub
if [ -f "$pub" ]; then
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    if ! grep -qFf "$pub" ~/.ssh/authorized_keys 2>/dev/null; then
        log "Installing the host's access key"
        cat "$pub" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
    fi
else
    warn "no $pub — generate it on the host first (see vm/README.md)"
fi

printf '\n'
log "Done. From the host:"
printf '    ssh -p 2222 -i vm/host-access/id_ed25519 %s@localhost\n\n' "$USER"
ip -br addr | grep -v '^lo '
