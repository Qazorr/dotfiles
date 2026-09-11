# Install ISO

A Debian 13 netinst image with this repo already on it.

```
sudo apt install xorriso
./iso/build.sh
```

Downloads Debian's netinst (verifying its published SHA256), unpacks it, adds
a preseed and a git bundle of this repo, and repacks it bootable on both BIOS
and UEFI. Output lands in `vm/iso/` (gitignored).

## Why a bundle instead of a download

The repo is private, so the installer can't fetch it — nothing to
authenticate with on a machine that doesn't exist yet. `preseed/late_command`
clones the bundle into `~/dotfiles` and repoints `origin` at the SSH URL, so
once you add a key, `git pull` works normally.

A bundle holds commits, not your working tree. `build.sh` refuses to run with
uncommitted changes for that reason.

## Boot entry

One entry, `Install Debian + dotfiles`, set as the menu default (isolinux and
GRUB). Preseeds locale, keymap, network, mirror, timezone, tasksel and
packages, and clones the repo into `~/dotfiles`.

**Partitioning, the target disk and your username stay interactive** — no
unattended variant, on purpose. **So does WiFi**, if `netcfg/choose_interface`
picks a wireless interface: `priority=medium` (not `high`) means the
installer stops to ask for an ESSID and passphrase instead of failing DHCP
silently and showing "network autoconfiguration failed".

The menu's speech-synthesis countdown boots a plain un-preseeded installer if
you let it lapse — press a key when the menu appears.

It doesn't run `bootstrap.sh` (needs a real user session, takes ~half an
hour); the installed system gets an motd saying so:

```
cd ~/dotfiles && ./bootstrap.sh
```

`bootstrap.sh` skips the `nvidia` step by default now — see the README's
[NVIDIA](../README.md#nvidia--opt-in) section before running it on real
hardware.

## No Linux box handy? Build it on CI

`xorriso` has no good Windows/macOS build, so `.github/workflows/build-iso.yml`
runs the same `iso/build.sh` on a GitHub Actions runner instead. Manual
trigger only — it's slow and bandwidth-heavy, nothing should kick it off by
itself.

From the Actions tab: **Build ISO** → **Run workflow**, then download the
`debian-dotfiles-iso` artifact once it finishes (~5-10 min).

From the CLI (`gh`):

```
gh workflow run build-iso.yml --ref <branch>
gh run watch --exit-status $(gh run list --workflow=build-iso.yml -L1 --json databaseId -q '.[0].databaseId')
gh run download --name debian-dotfiles-iso
```

It builds from whatever is committed and pushed on `--ref` — same
uncommitted-changes rule as running `build.sh` locally, just enforced by
pushing rather than `git status`.

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
