# dotfiles

[![ci](https://github.com/Qazorr/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Qazorr/dotfiles/actions/workflows/ci.yml)

Hyprland on Debian 13 (trixie) with
[Dux Modular Shell](https://github.com/duxlabs-dev/dux-shell) (DMS), built
into an installer ISO. Heavily inspired by
[JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) (now
LinuxBeginnings).

## Install

```
sudo apt install -y xorriso
iso/build.sh
sudo dd if=iso/out/dotfiles-trixie-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot the stick and answer what it asks. It installs Debian, reboots, sets up
the desktop on the console (15-20 minutes, needs network) and reboots into
the login screen. Pick **Hyprland** there, not "Hyprland (uwsm-managed)".

[iso/config](iso/config) holds the installer's answers; anything left empty
is asked on screen. Machine-specific ones go in an untracked
`iso/config.local`:

```
INSTALL_HOSTNAME="desk"
INSTALL_USER="kacper"
INSTALL_DISK="/dev/nvme0n1"       # erased without a question
INSTALL_STEPS="nvidia"
```

On a machine that already runs Debian 13:

```
git clone https://github.com/Qazorr/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

`./bootstrap.sh --help` lists the profiles and single steps.
`vm/install.sh` tries the ISO in a VM first.

## Keeping it in sync

Config in `$HOME` is symlinked into `~/dotfiles`, so every edit is already a
change in the repo.

```
dotfiles status                  what this machine has that the repo doesn't
dotfiles sync                    commit it, pull, push
dotfiles update                  pull, then install what changed
dotfiles track ~/.config/nvim    move a config into the repo
```

`sync` also offers to record apt packages installed by hand in
[packages.list](packages.list), which every other machine then installs.
Pushing over https needs `gh auth login && gh auth setup-git` once.

## Keys

`SUPER+H` lists every binding. Movement is on the arrow keys.

| Binding | Action |
|---|---|
| `SUPER+Return` / `E` / `B` / `C` | Terminal / files / browser / VS Code |
| `SUPER+D` / `A` / `S` | Launcher / dashboard / settings |
| `SUPER+Q` | Close window |
| `SUPER+Escape` / `SUPER+V` | Lock / power menu |
| `SUPER+arrows` | Focus — `CTRL` moves, `ALT` swaps, `SHIFT` resizes |
| `SUPER+1-0` | Workspace — `SHIFT` moves the window there |
| `SUPER+SHIFT+S` | Screenshot a region |
| `SUPER+W` / `SUPER+T` | Wallpaper / theme |
| `SUPER+M` / `SUPER+SHIFT+M` | Monitor profile status / layout editor |
| `SUPER+ALT+I` | Install packages |

## Extending

- **A config:** `dotfiles track <path>`. Every directory under `home/` is
  stowed into `$HOME`.
- **A package:** install it, then `dotfiles sync`.
- **An install step:** one file in `steps/`, named `<NNN>-<name>.sh`, with a
  `register_step` line and a `step_<name>` function. Copy a neighbour.
  Nothing may install into `~/.local/bin`: it is a symlink into this repo.

## Notes

- **NVIDIA** is opt-in: `./bootstrap.sh nvidia`, or `INSTALL_STEPS="nvidia"`
  on the ISO. RTX 5000-series needs `DOTFILES_NVIDIA_MODE=open`. With Secure
  Boot on, an unsigned module means a black screen.
  On hybrid laptops `prime-run <app>` uses the NVIDIA card.
- **Monitors:** arrange them with `SUPER+SHIFT+M` and save a profile. It
  applies whenever those monitors are connected.
- **Screen sharing:** `~/.config/hypr/screenshare.conf` holds Hyprland
  options applied while something is capturing.
- **Home or office:** `netloc add office` names the network you are on, by
  its gateway, so Wi-Fi and Ethernet count as the same place. `netloc` then
  prints `office`, for scripts to branch on. Personal shell config goes in an
  untracked `~/.zshrc.local`.
- **Boot screens:** the GRUB menu and Plymouth splash live in `boot/`.
  `boot/preview grub` opens the menu in a QEMU window, `boot/preview plymouth`
  (or `plymouth shutdown`) plays the splash in a window. `./bootstrap.sh grub`
  installs them; both use a blurred copy of the current wallpaper and DMS's
  colours, and re-theme themselves whenever the wallpaper changes
  (`journalctl -u dotfiles-boot-theme` shows each run).
- **DMS versions** are pinned in `steps/200-dms.sh`; bump them together.

## License

MIT — see [LICENSE](LICENSE). Third-party software keeps its own licensing.
