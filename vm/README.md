# Test VM

A throwaway Debian 13 (trixie) VM for testing this dotfiles repo — bootstrap
script, Hyprland config, the DankMaterialShell install, the works — without
risking a working machine. Plain QEMU/KVM, no libvirt.

## First-time setup

```
./install.sh
```

Boots the Debian netinst installer against the empty disk. Do a normal
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

## Getting the repo into the VM

This repo isn't pushed anywhere, and for the edit-on-host/test-in-guest loop
you'll be doing, scp'ing a fresh copy after every change would get old fast.
`run.sh` instead shares the whole repo into the guest live via a QEMU 9p
mount — edit here, the guest sees it immediately, no sync step.

One-time, inside the guest:

```
sudo mkdir -p /mnt/dotfiles
echo 'dotfiles /mnt/dotfiles 9p trans=virtio,version=9p2000.L,rw,_netdev 0 0' | sudo tee -a /etc/fstab
sudo mount -a
```

`/mnt/dotfiles` inside the guest is now this repo on the host, live. Run
`bootstrap.sh` from there, or symlink it into `~/dotfiles` if you'd rather
not type `/mnt/dotfiles` every time.

Inside the VM, skip both snapshot steps — the qcow2 snapshots below already
give you a faster, cheaper rollback than timeshift copying the whole rootfs
onto a virtual disk:

```
DOTFILES_SKIP_BACKUP=1 DOTFILES_SKIP_TIMESHIFT=1 ./bootstrap.sh --all
```

`--all` skips the interactive picker a bare `./bootstrap.sh` would open: the
point of the VM is to test what a fresh machine gets, so run the lot. (Or
untick the `safety` group in the picker, which is the same thing as those two
environment variables.)

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
