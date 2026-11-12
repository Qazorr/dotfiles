# Test VM

Throwaway Debian 13 VM for testing this repo, on plain QEMU/KVM.

```
../iso/build.sh      build the ISO
./install.sh         boot it on a fresh 40G disk and install
./run.sh             boot the installed disk
```

`install.sh` creates `disk/debian13.qcow2` (`DOTFILES_VM_DISK_SIZE` to
change); delete it and re-run to start over. `DOTFILES_TEST_ISO=<path>` boots
another image.

```
./snapshot.sh save clean        right after the install
./snapshot.sh restore clean     when a test run breaks it
./snapshot.sh list | delete <name>
```

- `disk/` is gitignored.
- Sluggish or no GL: `DOTFILES_VM_GPU=VGA DOTFILES_VM_DISPLAY=gtk ./run.sh`.
- No GPU passthrough, so this validates the install, not GPU-specific
  Hyprland issues.
