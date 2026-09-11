# Test VM

A throwaway Debian 13 (trixie) VM for testing this dotfiles repo — bootstrap
script, Hyprland config, the DankMaterialShell install, the works — without
risking a working machine. Plain QEMU/KVM, no libvirt.

## First-time setup

```
./install.sh
```

Creates `disk/debian13.qcow2` (40G, override with `DOTFILES_VM_DISK_SIZE`) if
it isn't there, then boots the Debian netinst installer against it. To start
over, delete that file and run this again. Do a normal
install (guided partitioning is fine, 40G disk). **Uncheck every desktop
environment** in tasksel — this dotfiles setup provides its own Hyprland +
Quickshell session, and a preinstalled DE just gets in the way. Do install
the "SSH server" task — handy for copying files in / running commands
from the host later. When install finishes and the VM shuts itself down,
you're done with this script for good.

## Day-to-day use

```
./run.sh
```

Boots the installed system. GPU-accelerated Wayland via virtio-gpu-gl, so
Hyprland should get real OpenGL instead of falling back to llvmpipe.
SSH is forwarded to `localhost:2222` (`ssh -p 2222 user@localhost`).

### Make the guest debuggable

Once, on the host — the key is gitignored, it's local machine access rather
than repo content:

```
ssh-keygen -t ed25519 -N '' -C dotfiles-vm-access -f vm/host-access/id_ed25519
```

Then once, inside the guest. The ISO already put the repo in `~/dotfiles`, so
there is nothing to copy in first:

```
~/dotfiles/vm/guest-setup.sh
```

That mounts the host's repo at `/mnt/host` across reboots, makes the journal
persistent so `journalctl -b -1` still works after a crash and a reboot,
enables lingering so `/run/user/$UID` — where Hyprland writes its log —
outlives the session that crashed, puts you in `adm` so `journalctl` needs no
sudo, and installs the host key. After it, the host can just:

```
ssh -p 2222 -i vm/host-access/id_ed25519 <user>@localhost
```

If the guest has no network it is usually the interface name: the installer
writes `/etc/network/interfaces` naming the NIC it saw, and adding or removing
a QEMU device shifts PCI addresses and renames it. `run.sh` and `install.sh`
pin the NIC to a fixed address so they agree, but a machine installed before
that pin still has the old name baked in. Letting NetworkManager have the
device instead is name-independent:

```
sudo sed -i '/^allow-hotplug/,$d' /etc/network/interfaces
sudo systemctl restart NetworkManager
```

## Getting the repo into the VM

This repo isn't pushed anywhere, and for the edit-on-host/test-in-guest loop
you'll be doing, scp'ing a fresh copy after every change would get old fast.
`run.sh` instead shares the whole repo into the guest live via a QEMU 9p
mount — edit here, the guest sees it immediately, no sync step.

`guest-setup.sh` above sets this up at `/mnt/host`, including the
`9pnet_virtio` module — `mount -t 9p` pulls in the `9p` module but not the
virtio transport, so without it the mount fails with "special device dotfiles
does not exist".

`/mnt/host` inside the guest is this repo on the host, live. Run
`bootstrap.sh` from there to test an edit without committing or copying
anything.

Inside the VM, skip both snapshot steps — the qcow2 snapshots below already
give you a faster, cheaper rollback than timeshift copying the whole rootfs
onto a virtual disk:

```
DOTFILES_SKIP_BACKUP=1 DOTFILES_SKIP_TIMESHIFT=1 ./bootstrap.sh
```

A bare `./bootstrap.sh` runs everything not already done, which is what you
want here — the point of the VM is to test what a fresh machine gets. The two
variables are the same thing as leaving out the `safety` group.

If you'd genuinely rather have a real independent clone in the guest (e.g.
to commit VM-only test changes) — `git bundle create /tmp/dotfiles.bundle
--all` on the host, copy the bundle in via the 9p mount, then `git clone
/mnt/dotfiles-transfer/dotfiles.bundle ~/dotfiles` in the guest. Not needed
for the normal workflow.

## Snapshots

Right after the base install (desktop-free, SSH working), take a clean
snapshot so a broken `bootstrap.sh` run is a 5-second revert instead of a
reinstall:

```
./snapshot.sh save clean
```

Then, whenever a test run leaves the VM in a bad state:

```
./snapshot.sh restore clean
```

`./snapshot.sh list` / `delete <name>` round out the basics.

## Notes

- `iso/` and `disk/` are gitignored — they're multi-GB binaries, not
  something to commit.
- If the guest feels sluggish or GL doesn't come up, drop `,gl=on` from
  the `-display gtk` line in `run.sh`/`install.sh` to fall back to
  software rendering — slower but rules out a GPU-passthrough issue
  while debugging everything else.
- This VM validates `bootstrap.sh` and general behavior on real Debian
  13. It does *not* have your actual GPU, so don't chase GPU-specific
  Hyprland issues (rendering artifacts, monitor/output quirks) here —
  that still needs bare-metal or the nested-session route.
