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

## Boot entries

| Entry | Behaviour |
|---|---|
| `Install Debian + dotfiles` | Preseeds locale, mirror, tasksel and packages. **Partitioning, target disk and your username stay interactive**, so a mis-boot can't erase anything. |
| `Install Debian + dotfiles (auto)` | Fully unattended, **erases `/dev/vda`**. For the test VM only. Its password is in this repo and on every copy of the ISO. |

Neither runs `bootstrap.sh`. It has to run as your normal user in a real
session and takes half an hour; the installed system gets an motd saying so:

```
cd ~/dotfiles && ./bootstrap.sh
```

## Test it before real hardware

```
rm -f vm/disk/debian13.qcow2
qemu-img create -f qcow2 vm/disk/debian13.qcow2 40G
DOTFILES_TEST_ISO=vm/iso/debian-13.6.0-amd64-dotfiles.iso vm/install.sh
```

Pick the auto entry there — `/dev/vda` is the VM's virtio disk. Then write it
to a USB stick:

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
