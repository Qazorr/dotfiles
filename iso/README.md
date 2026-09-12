# Install ISO

A Debian 13 netinst image that installs Debian and sets this repo up.

```
sudo apt install xorriso
./iso/build.sh
```

Downloads Debian's netinst (verifying its published SHA256), unpacks it, adds
a preseed and a post-install script, and repacks it bootable on both BIOS and
UEFI. Output lands in `vm/iso/` (gitignored).

## What it actually does

Preseeds the boring installer questions, then `preseed/late_command` runs
[`late.sh`](late.sh), which clones the repo into `~/dotfiles` and repoints
`origin` at the SSH URL so pushing works once a key is on the machine. If the
clone fails it says so in the motd rather than pointing at a directory that
isn't there.

No repo content is baked into the image, so an ISO built months ago still
installs the current dotfiles — and a dirty working tree doesn't matter when
building one.

## Boot entry

One entry, `Install Debian + dotfiles`, set as the menu default (isolinux and
GRUB). Boots the **graphical (GTK) installer**, not the text/ncurses one —
`install.amd/gtk/{vmlinuz,initrd.gz}` — for an actual wizard flow (mouse,
proper network/WiFi picker) instead of the main-menu-driven text frontend.
Preseeds locale, keymap, mirror, timezone, tasksel and packages.

**Partitioning, the target disk, your username, the hostname and the network
step all stay interactive** — no unattended variant, on purpose. The network
one matters for WiFi; see below.

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

## WiFi during the install

`preseed.cfg` deliberately leaves `netcfg/choose_interface` unset. Debian's
own example sets it to `auto`, documented as: *"netcfg will choose an
interface that has link if possible. This makes it skip displaying a list if
there is more than one interface."* On a laptop with an empty ethernet port
that picks the wired NIC, DHCP fails, and the wireless card is never offered
— "network autoconfiguration failed" with no ESSID prompt, while the stock
"Graphical install" entry on the same ISO works fine because it asks. Note a
preseeded answer is used whatever `priority` is set to, so raising priority
does not bring the question back; the line has to go.

The boot entry also doesn't pass `auto=true` — that's the Automated-install
mechanism, for network-fetched preseeds, and we want an interactive install.

If a machine genuinely has no wireless interface (its chip isn't covered by
the media's firmware), **USB-tether a phone**, or use a dongle or a cable:
tethering enumerates as a normal CDC/RNDIS ethernet device with an in-tree
driver, so DHCP just works. Afterwards `apt install firmware-realtek` (or
whatever `lspci -k` and `dmesg | grep -i firmware` name) gets WiFi going on
the installed system.

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

`preseed.cfg` keeps its keymap in step with `hypr/.config/hypr/conf.d/input.conf`
(`us`), and the timezone matches this machine (`Europe/Warsaw`). Both are
plain preseed lines — change them there.
