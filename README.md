# dotfiles

Personal Hyprland setup for Debian 13 (trixie), with
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) as the
desktop shell — bar, launcher, control centre, notifications, clipboard
history, polkit agent, wallpaper and theming. No waybar, no rofi, no wlogout,
no mako.

It's a personal config for my hardware: expect to fork it and change the
keymap, timezone and monitor setup rather than run it as-is.

Layout and keybindings take after
[JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots); the
NVIDIA step follows
[LinuxBeginnings/Debian-Hyprland](https://github.com/LinuxBeginnings/Debian-Hyprland).

## Built on

| | |
|---|---|
| [Hyprland](https://hypr.land) | The compositor, plus [hypridle](https://github.com/hyprwm/hypridle) and [hyprlock](https://github.com/hyprwm/hyprlock) for idle/lock |
| [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) | Bar, launcher, control centre, notifications — running on [Quickshell](https://quickshell.org) |
| [matugen](https://github.com/InioX/matugen) | Wallpaper → Material palette, driving the theming |
| [greetd](https://sr.ht/~kennylevinsen/greetd/) | Login screen — the step asks whether you want dms-greeter (themed) or [tuigreet](https://github.com/apognu/tuigreet) (plain, from Debian) |
| [hyprmon](https://github.com/erans/hyprmon) | Monitor layout and profiles |
| [Quick Capture](https://github.com/hthienloc/dms-quick-capture) | Screenshots with an annotation editor |
| [kitty](https://sw.kovidgoyal.net/kitty/) · [fastfetch](https://github.com/fastfetch-cli/fastfetch) · [cava](https://github.com/karlstav/cava) | Terminal, banner, audio visualizer |
| [GNU Stow](https://www.gnu.org/software/stow/) | Symlinks the dotfiles into `$HOME` |
| [Timeshift](https://github.com/linuxmint/timeshift) | Full-system snapshot before the first run |

## Install

On Debian 13 (trixie):

```
sudo apt install -y git
git clone https://github.com/Qazorr/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

Takes 15-20 minutes. Reboot afterwards — `greetd` comes up, pick **Hyprland**
(not "Hyprland (uwsm-managed)"), and the reboot picks up your new groups and
login shell.

On a fresh machine, install Debian 13 with the stock installer first (the
graphical one; pick your WiFi network when it asks), then run the above.

Re-run `./bootstrap.sh` any time; it records what it has already done and
skips it. Editing a step re-runs just that step.

```
./bootstrap.sh --list       every step, with install and run status
./bootstrap.sh --pick       choose interactively
./bootstrap.sh --missing    only what isn't installed yet
./bootstrap.sh --doctor     check this machine, change nothing
./bootstrap.sh --help       everything else
```

`nvidia` is opt-in and won't run on its own — see [docs/nvidia.md](docs/nvidia.md).

## Key bindings

**Movement is on the arrow keys**, which frees `H/J/K/L` for mnemonics.
`SUPER+H` opens a fuzzy-searchable list of every binding (`keys` in a shell),
read live from `hyprctl binds -j`, so it can't drift from this table.

| Binding | Action |
|---|---|
| `SUPER+Return` | Terminal |
| `SUPER+E` | File manager |
| `SUPER+B` | Browser |
| `SUPER+C` | VS Code |
| `SUPER+D` | App launcher |
| `SUPER+A` | Dashboard overview |
| `SUPER+H` | Help / cheat sheet |
| `SUPER+S` | Settings |
| `SUPER+SHIFT+E` | Control centre |
| `SUPER+T` | Theme switcher |
| `SUPER+N` / `SUPER+SHIFT+N` | Night light / notifications |
| `SUPER+ALT+V` | Clipboard manager |
| `SUPER+W` | Wallpaper picker |
| `SUPER+M` | Monitor profile status |
| `SUPER+SHIFT+M` | Monitor layout editor (hyprmon, writes into the active profile) |
| `SUPER+I` | Toggle idle inhibit |
| `SUPER+SHIFT+C` | Audio visualizer (cava) |
| `SUPER+SHIFT+P` | Process list |
| `SUPER+ALT+N` / `SUPER+ALT+B` | Network / Bluetooth manager |
| `SUPER+CTRL+ALT+B` | Toggle the DMS bar |
| `SUPER+Q` / `SUPER+SHIFT+Q` | Close window / exit Hyprland |
| `SUPER+Escape` / `SUPER+V` | Lock / power menu |
| `SUPER+SPACE` | Float window |
| `ALT+Tab` | Cycle windows |
| `SUPER+SHIFT+F` / `SUPER+CTRL+F` | Fullscreen / maximize |
| `SUPER+arrows` | Focus |
| `SUPER+CTRL+arrows` | Move window |
| `SUPER+ALT+arrows` | Swap window |
| `SUPER+SHIFT+arrows` | Resize |
| `SUPER+ALT+scroll` | Desktop zoom |
| Touchpad, 3 fingers | Swipe: workspaces · up/down: zoom |
| Touchpad, 4 fingers | Up: dashboard · down: float window |
| `SUPER+1-0` | Workspaces — again on the current one jumps back to the previous |
| `SUPER+SHIFT+1-0` / `SUPER+CTRL+1-0` | Move window there / move silently |
| `SUPER+U` / `SUPER+SHIFT+U` | Special workspace (scratchpad) |
| `SUPER+CTRL+F9-F12` | Move workspace to another monitor |
| `Print` variants | Screenshot: `SUPER` full, `+SHIFT` region, `ALT` window, `+CTRL` 5s, `+CTRL+SHIFT` 10s |
| `SUPER+SHIFT+S` | Screenshot (region) — same as `SUPER+SHIFT+Print` |

## Docs

- [docs/bootstrap.md](docs/bootstrap.md) — how the installer works, and how to add a step
- [docs/nvidia.md](docs/nvidia.md) — driver choices, Secure Boot, hybrid graphics
- [docs/reference.md](docs/reference.md) — layout, login, backups, screenshots, theming, window rules
- [vm/README.md](vm/README.md) — the throwaway test VM

## License

MIT — see [LICENSE](LICENSE).

The keybinding layout is adapted from
[JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) (MIT).
Third-party software this installs keeps its own licensing — none of it is
vendored here.
