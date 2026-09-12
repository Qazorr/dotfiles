# Test VM

A throwaway Debian 13 (trixie) VM for testing this repo without risking a
working machine. Plain QEMU/KVM, no libvirt.

## First-time setup

```
./install.sh
```

Creates `disk/debian13.qcow2` (40G, override with `DOTFILES_VM_DISK_SIZE`) if
missing, then boots the netinst installer. Guided partitioning is fine.
**Uncheck every desktop environment** in tasksel — this setup provides its
own Hyprland + Quickshell session. Install the "SSH server" task. Delete the
disk file and re-run to start over.

## Day-to-day use

```
./run.sh
```

Boots the installed system. GPU-accelerated Wayland via virtio-gpu-gl. SSH is
forwarded to `localhost:2222` (`ssh -p 2222 user@localhost`).

### Make the guest debuggable

Once, on the host (the key is gitignored — machine access, not repo content):

```
ssh-keygen -t ed25519 -N '' -C dotfiles-vm-access -f vm/host-access/id_ed25519
```

Then once, inside the guest:

```
~/dotfiles/vm/guest-setup.sh
```

Mounts the host repo at `/mnt/host` across reboots, makes the journal
persistent (`journalctl -b -1` survives a crash), enables lingering so
`/run/user/$UID` outlives a crashed session, adds you to `adm`, installs the
host key. After it:

```
ssh -p 2222 -i vm/host-access/id_ed25519 <user>@localhost
```

No network in the guest is usually the NIC name changing (adding/removing a
QEMU device shifts PCI addresses). `run.sh`/`install.sh` pin the NIC address;
a VM installed before that pin still has the old name. Fix by handing the
device to NetworkManager:

```
sudo sed -i '/^allow-hotplug/,$d' /etc/network/interfaces
sudo systemctl restart NetworkManager
```

## Getting the repo into the VM

`run.sh` shares the whole repo into the guest live via a QEMU 9p mount at
`/mnt/host` — edit on the host, the guest sees it immediately, no scp/sync
step. Run `bootstrap.sh` from there to test an edit before committing.

Inside the VM, skip both snapshot steps — the qcow2 snapshots below are
already a faster rollback than a full-rootfs timeshift copy:

```
DOTFILES_SKIP_BACKUP=1 DOTFILES_SKIP_TIMESHIFT=1 ./bootstrap.sh
```

For a genuinely independent clone in the guest instead (e.g. to commit
VM-only test changes), just `git clone https://github.com/Qazorr/dotfiles.git
~/dotfiles` there. Not needed for the normal workflow.

## Snapshots

Right after the base install (desktop-free, SSH working):

```
./snapshot.sh save clean
```

Then whenever a test run leaves the VM in a bad state:

```
./snapshot.sh restore clean
```

`./snapshot.sh list` / `delete <name>` round out the basics.

## Notes

- `iso/` and `disk/` are gitignored — multi-GB binaries.
- If the guest feels sluggish or GL doesn't come up, drop `,gl=on` from the
  `-display gtk` line in `run.sh`/`install.sh` to rule out a
  GPU-passthrough issue.
- This VM has no GPU passthrough, so it validates `bootstrap.sh` and general
  behavior, not GPU-specific Hyprland issues — that still needs bare metal.
