# dotfiles

Personal Hyprland setup for Debian 13 (trixie), with
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) as the
desktop shell — bar, launcher, control centre, notifications, clipboard,
polkit agent, wallpaper and theming.

A personal config for my hardware: fork it and change the keymap, timezone
and monitor setup to match yours.

## Built on

| | |
|---|---|
| [Hyprland](https://hypr.land) | Compositor, with [hypridle](https://github.com/hyprwm/hypridle) / [hyprlock](https://github.com/hyprwm/hyprlock) |
| [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) | Bar, launcher, control centre, on [Quickshell](https://quickshell.org) |
| [matugen](https://github.com/InioX/matugen) | Wallpaper → Material palette |
| [greetd](https://sr.ht/~kennylevinsen/greetd/) | Login — dms-greeter or [tuigreet](https://github.com/apognu/tuigreet) |
| [hyprmon](https://github.com/erans/hyprmon) | Monitor layout |
| [Quick Capture](https://github.com/hthienloc/dms-quick-capture) | Screenshots with annotation |
| [kitty](https://sw.kovidgoyal.net/kitty/) · [fastfetch](https://github.com/fastfetch-cli/fastfetch) · [cava](https://github.com/karlstav/cava) | Terminal, banner, visualizer |
| [GNU Stow](https://www.gnu.org/software/stow/) | Symlinks into `$HOME` |
| [Timeshift](https://github.com/linuxmint/timeshift) | Snapshot before the first run |

## Install

```
sudo apt install -y git
git clone https://github.com/Qazorr/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

15-20 minutes. Reboot, then pick **Hyprland** (not "Hyprland
(uwsm-managed)") at greetd. Re-run any time: it records what it has done and
skips it, and editing a step re-runs just that step.

```
./bootstrap.sh --list       every step, with status
./bootstrap.sh --pick       choose interactively
./bootstrap.sh --missing    only what isn't installed
./bootstrap.sh --doctor     check this machine, change nothing
./bootstrap.sh --help       everything else
```

## Key bindings

**Movement is on the arrow keys**, freeing `H/J/K/L` for mnemonics.
`SUPER+H` lists every binding live from `hyprctl binds -j` (`keys` in a
shell), so it can't drift from this table.

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
| `SUPER+ALT+I` / `SUPER+ALT+SHIFT+I` | Install / remove packages (fzf over apt, through nala — also in the launcher, `pkgs` in a shell) |
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

## Layout

```
hypr/ kitty/ zsh/ fastfetch/ cava/   Config, stowed into $HOME
dms/                                 DMS settings + idleInhibitToggle plugin
scripts/.local/bin/                  dotfiles-backup, idle-inhibit, keybind-help,
                                       lock-session, monitor-profile, new-app,
                                       pkgs, prime-run, screenshare
bootstrap.sh                         Entrypoint: run order + command line
setup/steps/                         One file per stage
lib/                                 Step registry, state, apt/fetch helpers, doctor
vm/                                  Throwaway QEMU test VM
```

DankMaterialShell installs to `~/.config/quickshell/dms` and its binaries to
`~/.local/share/dms/bin`. Generated theme files are gitignored; matugen
rewrites them on every theme change.

## Adding a step

One self-describing file in `setup/steps/`:

```bash
register_step docker \
    --desc "Docker Engine + Compose/Buildx plugins" \
    --group dev --root --needs prereqs --provides docker

step_docker() { ...; }
```

`--optional` keeps it out of unattended runs, `--always` never records it,
`--needs` must already be done, `--provides` drives `--list`/`--missing`/
`--doctor`. `STEPS` in `bootstrap.sh` is the run order and
`steps_validate()` aborts if the two disagree. Steps must be idempotent, and
should call `stamp_skip` if they return without doing their work. A step
needing a choice declares `register_option`; all options are asked up front,
before sudo.

**Never install into `~/.local/bin`** — it's a stow symlink into this repo,
so anything written there gets committed. Use `/usr/local/bin` or
`~/.local/share/<tool>/bin` (add it to `DOTFILES_PATH_DIRS` in `lib/paths.sh`).

Anything that could cost you the machine — driver, bootloader, login manager
— goes in the VM first (`vm/README.md`).

## NVIDIA

`--optional`, so a plain run skips it and a fresh install can't come up to a
black screen:

```
./bootstrap.sh nvidia
```

Asks which driver up front — Debian's `nvidia-driver` (default),
`nvidia-open` (**required** on RTX 5000-series+), `cuda-drivers`, or revert
to nouveau. Set `DOTFILES_NVIDIA_MODE=debian|open|nvidia|nouveau` to skip the
prompt. Switching removes the previous variant first. Reboot afterwards.

An unsigned module under Secure Boot can fail to load, and with nouveau
blacklisted that's no KMS driver at all — a black screen, not just software
rendering. The step warns first; if it happens, Ctrl+Alt+F3 and
`./bootstrap.sh --doctor` gives the exact fix.

On hybrid laptops the session stays on the iGPU and single apps go to the
NVIDIA card with `prime-run blender`. The NVIDIA env lives in untracked
`conf.d/local.conf`, since `GBM_BACKEND=nvidia-drm` breaks rendering on a
card-less machine.

## Monitors

One file per desk in `~/.config/monitor-profiles/`, outside this repo because
EDID descriptions carry serials. `monitor-profile --watch` (autostart) points
`active.conf` at the profile whose `monitor = desc:…` lines are all connected,
on login and every hotplug.

```
monitor-profile --status       what's connected, what matches (SUPER+M)
monitor-profile --save <name>  keep the current layout as a profile
```

## Screen sharing

Hyprland hides a window from viewers with a `no_screen_share` window rule,
which applies to every capture, screenshots included. There's a template at
the end of `conf.d/windowrules.conf`.

To change options only while sharing, `screenshare watch` (autostart) applies
`~/.config/hypr/screenshare.conf` for the duration and restores it after.
The config is Hyprland option names, one per line:

```
decoration:blur:enabled = 0
general:gaps_out        = 5 5 5 5
```

Anything `hyprctl keyword` takes works; `exec-start` / `exec-stop` run a
command. `screenshare status` reports `on`/`off`, or `unknown` when the
watcher isn't running — Hyprland announces capture as an event, so the watcher
has to be up to answer. `screenshare test 5` previews the profile.

Colour options (`general:col.*`) don't survive the round trip, so keep them
out of that file. `general:border_size = 0` covers borders.

## Notes

- **Idle/lock** is hypridle + hyprlock, with `lock_cmd` going through
  `lock-session` so a hung hyprlock can't stop the session locking.
- **DMS versions are pinned** in `setup/steps/dms.sh` — the QML and CLI share
  an API version, so bump both together.
- **Cursor** is Bibata-Modern-Classic, XCursor only.

## License

MIT — see [LICENSE](LICENSE). Keybinding layout adapted from
[JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) (MIT).
Third-party software keeps its own licensing.
