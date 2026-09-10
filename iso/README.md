# Install ISO

A Debian 13 netinst image with this repo already on it.

```
sudo apt install xorriso
./iso/build.sh
```

Downloads Debian's netinst (verifying its published SHA256), unpacks it, adds
a preseed and a git bundle of this repo, and repacks it so it still boots on
both BIOS and UEFI. Output lands in `vm/iso/`, which is gitignored.

## Why a bundle instead of a download

The repo is private, so an installer can't fetch it — there is nothing to
authenticate with on a machine that doesn't exist yet. The ISO carries the
repo instead. `preseed/late_command` clones the bundle into the new user's
`~/dotfiles` and repoints `origin` at the SSH URL, so once you add a key,
`git pull` works normally.

A bundle holds commits, not your working tree. `build.sh` refuses to run with
uncommitted changes for that reason — otherwise you find out on a freshly
installed machine that the ISO shipped last week's code.

## Boot entry

One entry, `Install Debian + dotfiles`, set as the menu default in both
isolinux (BIOS) and GRUB (UEFI). It preseeds locale, keymap, network, mirror,
timezone, tasksel and packages, and clones the repo into `~/dotfiles`.

**Partitioning, the target disk and your username stay interactive.** There is
deliberately no unattended variant: an entry that erases a disk on its own is
one mis-boot away from being a disaster, and it isn't worth the saved minute.

The menu's speech-synthesis countdown boots a plain, un-preseeded installer if
you let it lapse — press a key when the menu appears.

It doesn't run `bootstrap.sh`. That has to run as your normal user in a real
session and takes half an hour; the installed system gets an motd saying so:

```
cd ~/dotfiles && ./bootstrap.sh
```

## Test it before real hardware

```
rm -f vm/disk/debian13.qcow2        # only if you want a clean disk
DOTFILES_TEST_ISO=vm/iso/debian-13.6.0-amd64-dotfiles.iso vm/install.sh
```

`install.sh` creates the disk image if it's missing. Guided partitioning on
the whole virtual disk is fine in the VM.

Then write it to a USB stick:

```
sudo dd if=vm/iso/debian-13.6.0-amd64-dotfiles.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Overrides

| | |
|---|---|
| `DOTFILES_DEBIAN_VERSION` | point at a different point release (default `13.6.0`) |
| `DOTFILES_NETINST_ISO` | use a netinst you already have |
| `DOTFILES_ISO_OUT` | where to write the result |
| `DOTFILES_ISO_ALLOW_DIRTY=1` | build anyway with a dirty tree, shipping the last commit |

`preseed.cfg` keeps its keymap in step with `hypr/.config/hypr/conf.d/input.conf`
(`us`), and the timezone matches this machine (`Europe/Warsaw`). Both are
plain preseed lines — change them there.
