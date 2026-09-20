# Test VM

Throwaway Debian 13 VM for testing this repo, on plain QEMU/KVM.

## Setup

```
./install.sh
```

Creates `disk/debian13.qcow2` (40G, `DOTFILES_VM_DISK_SIZE` to change) and
boots the netinst installer. **Uncheck every desktop environment** in
tasksel; install the "SSH server" task. Delete the disk and re-run to start
over.

## Use

```
./run.sh
```

GPU-accelerated Wayland via virtio-gpu-gl, SSH on `localhost:2222`.

The repo is shared live at `/mnt/host` over 9p — edit on the host, run
`bootstrap.sh` from there. Skip both snapshot steps inside the VM:

```
DOTFILES_SKIP_BACKUP=1 DOTFILES_SKIP_TIMESHIFT=1 ./bootstrap.sh
```

## Snapshots

```
./snapshot.sh save clean        right after the base install
./snapshot.sh restore clean     when a test run breaks it
./snapshot.sh list | delete <name>
```

## Debuggable guest

Once on the host (gitignored — machine access, not repo content):

```
ssh-keygen -t ed25519 -N '' -C dotfiles-vm-access -f vm/host-access/id_ed25519
```

Once in the guest, `~/dotfiles/vm/guest-setup.sh` mounts the host repo across
reboots, makes the journal persistent, enables lingering, adds you to `adm`
and installs the key. Then:

```
ssh -p 2222 -i vm/host-access/id_ed25519 <user>@localhost
```

## Notes

- `iso/` and `disk/` are gitignored.
- No network in the guest usually means the NIC name changed. `run.sh`
  pins the address now; on an older VM, hand the device to NetworkManager:
  `sudo sed -i '/^allow-hotplug/,$d' /etc/network/interfaces && sudo systemctl restart NetworkManager`
- Sluggish or no GL: drop `,gl=on` from the `-display gtk` line.
- No GPU passthrough, so this validates `bootstrap.sh`, not GPU-specific
  Hyprland issues.
