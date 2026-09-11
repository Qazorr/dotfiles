# dotfiles

Personal Hyprland setup for Debian 13 (trixie), with
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) as the
desktop shell — bar, launcher, control centre, notifications, clipboard
history, polkit agent, wallpaper and theming. No waybar, no rofi, no wlogout,
no mako.

## Install

On a machine that already has Debian 13 (trixie):

```
sudo apt install -y git                    # Debian's minimal install has no git
git clone git@github.com:Qazorr/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

The repo is private, so that clone needs an SSH key or `gh auth login` first.

**From bare metal**, `./iso/build.sh` builds a Debian netinst image with the
repo already on it — see [iso/README.md](iso/README.md).

`./bootstrap.sh` with no arguments runs every non-optional step in order, and
stays the command you use afterwards.

Afterwards reboot. `greetd` takes over tty1 with `tuigreet`; pick
**Hyprland** and it remembers the choice. The reboot also picks up your new
group membership and login shell.

### It remembers what it has already done

Each finished step gets a file under `~/.local/state/dotfiles/steps`, and the
next run skips it — a hash of the step's own file, not just a done flag, so
editing `setup/steps/cli.sh` makes the next run redo just that step.

```
./bootstrap.sh --list             every step, with install and run status
./bootstrap.sh --force            run it all again, records or no records
./bootstrap.sh --forget cli       drop one record
./bootstrap.sh --mark-done        record what already looks installed, run nothing
./bootstrap.sh --dry-run          print the plan, change nothing
```

Failures aren't recorded, so the next run retries.

### Running less than everything

```
./bootstrap.sh dms vscode         named steps (prerequisites pulled in)
./bootstrap.sh --profile desktop  a named set of groups
./bootstrap.sh --group dev        one group
./bootstrap.sh --missing          only what isn't installed yet
./bootstrap.sh --pick             choose interactively
```

Profiles: `full`, `desktop` (no dev tooling or personal projects), `cli`
(shell only) and `dev`. Groups: `core safety shell desktop apps dev personal`.

`--pick` lists every step by group: `[*]` locked (`core`), `[x]` ticked,
`[ ]` not. Opt-in steps (see below) start unticked unless named.

```
  1 5 9   toggle those steps        a  everything
  g dev   toggle a whole group      n  nothing but the locked steps
  p cli   apply a profile           m  only what looks missing
  Enter   run the ticked steps      q  quit
```

**Sudo is asked for once, at the start**, only if the chosen steps need root.
A keepalive refreshes it so a long apt upgrade doesn't hit sudo's 15-minute
timeout mid-run.

A failing step stops the run and prints the command to resume from
(`--keep-going` runs the rest and lists failures at the end).

The first two steps are a config backup and a timeshift snapshot; skip either
with `DOTFILES_SKIP_BACKUP=1` / `DOTFILES_SKIP_TIMESHIFT=1`.

### Checking a machine

```
./bootstrap.sh --doctor
```

Read-only. Reports steps not installed, whether stow symlinks still point
into this repo (**writethrough**: `~/.local/bin`, `~/.config/hypr`,
`~/.config/kitty`, `~/.config/DankMaterialShell/plugins` are stow symlinks
*into this repo*, so anything writing there writes inside a tracked git
checkout — this has happened seven times, each caught by eye in `git status`
until `--doctor` started flagging it directly), PATH consistency, group
membership, leftover `.pre-dotfiles` files, and — with `shellcheck` — lint.

## Adding or changing a step

Each stage is one self-describing file under `setup/steps/`:

```bash
# setup/steps/docker.sh
register_step docker \
    --desc "Docker Engine + Compose/Buildx plugins, from Docker's own apt repo" \
    --group dev --root --needs prereqs \
    --provides docker

step_docker() {
    ...
}
```

| | |
|---|---|
| `--desc` | what `--list` and the picker print |
| `--group` | which group/profile it belongs to |
| `--root` | it calls `sudo`; decides whether a run asks for a password at all |
| `--always` | never recorded, runs every time (the snapshots, `stow`, `summary`) |
| `--optional` | never auto-selected — not by a plain run, `--profile`, `--group` or `--missing`, only by naming it or ticking it in `--pick`. For a step risky enough that it shouldn't run unattended (`nvidia`) |
| `--needs` | must *already be done* for this step's install to succeed; pulled in automatically. Install-time only, not "would be nice at runtime" |
| `--provides` | a command or path that exists once the step has run. Drives `--list`, `--missing`, `--doctor` |

A step returning 0 without having done its work should call `stamp_skip`, so
it isn't recorded and the next run retries.

A step that needs the user to pick something (which driver, say) declares it
with `register_option`, right in its own file, next to `register_step`:

```bash
register_option nvidia DOTFILES_NVIDIA_MODE \
    --prompt "Which NVIDIA driver?" \
    --choices "debian:..." "open:..." \
    --default debian
```

`resolve_step_options` asks for every registered option once, up front —
before sudo, before anything runs — for whichever of those steps ended up in
the plan. Setting the env var beforehand skips the prompt for that one; see
[NVIDIA](#nvidia--opt-in) for the full picture. Steps read the variable
themselves (`${DOTFILES_NVIDIA_MODE:-debian}`) same as any other override —
`register_option` only drives the prompt, not the step's behavior.

`STEPS` in `bootstrap.sh` is the run order — the one fact that can't live in
a step's own file. `steps_validate()` aborts at startup if the two disagree.

Every step must be **idempotent**; `set -euo pipefail` is on, so guard
anything that can legitimately fail.

### Adding something you just installed

- **An apt package from Debian** — add it to `setup/steps/cli.sh` (shell
  tools) or `desktop.sh` (graphical). Nothing else.
- **A tool with its own apt repo** — a new step using `ensure_apt_key` /
  `ensure_apt_list` / `apt_install`. `docker.sh`, `vscode.sh`, `brave.sh`,
  `danklinux.sh` are worked examples.
- **A single binary from a GitHub release** — a new step using
  `install_github_release_binary` (see `devtools.sh`), pinned to a tag.
- **A dotfile change** — just edit the file; the stowed dirs are symlinks
  into this repo.

**Never install anything into `~/.local/bin`** — it's a stow symlink into
this repo, so anything written there gets committed to git. Use
`/usr/local/bin` (system-wide) or `~/.local/share/<tool>/bin` (per-user, add
it to `DOTFILES_PATH_DIRS` in `lib/paths.sh` and the three files that repeat
that list — `--doctor` checks they agree).

Then `./bootstrap.sh` (editing a step file un-records just that step) and
`./bootstrap.sh --doctor` (catches anything installed by hand that wrote into
the repo behind your back).

Anything that could cost you the machine — a driver, the bootloader, the
login manager — belongs in the VM first (`vm/README.md`).

## NVIDIA — opt-in

`nvidia` is an `--optional` step: a plain `./bootstrap.sh` run skips it, so a
fresh install can't come up to a black screen over a driver problem. Run it
deliberately once you're ready to deal with it:

```
./bootstrap.sh nvidia
```

Detects the card via PCI vendor `10de` and no-ops without one. Sets
`nvidia-drm modeset=1`, blacklists nouveau (modprobe.d and the kernel command
line), rebuilds the initramfs and GRUB config. Reboot afterwards to actually
switch drivers.

### Choosing a driver

`./bootstrap.sh nvidia` asks once, up front — before sudo, before anything
installs — then the run is unattended like every other step:

```
Which NVIDIA driver?  (nvidia)
  1) Debian repo (nvidia-driver) — trails upstream, but what this machine already uses  (default)
  2) NVIDIA's own repo, open kernel modules — required on RTX 5000-series+
  3) NVIDIA's own repo, proprietary (cuda-drivers)
  4) Uninstall and revert to the in-kernel driver
>
```

| Choice | Package | Source | When |
|---|---|---|---|
| Debian repo (default) | `nvidia-driver` | Debian's own repo (`contrib`/`non-free`) | what this machine's GTX 1660 Ti uses; trails upstream on testing/unstable |
| Open kernel modules | `nvidia-open` | NVIDIA's own CUDA repo | **required** on RTX 5000-series and newer |
| Proprietary | `cuda-drivers` | NVIDIA's own CUDA repo | latest upstream release |
| Revert | — | — | uninstalls whatever's installed, reverts to the in-kernel driver |

Switching removes the previously-installed variant first (reverting included
— picking it after debian/open/nvidia purges the driver, un-blacklists
nouveau, and drops the GRUB/initramfs/Hyprland-env changes). Picking what's
already installed is close to a no-op: it re-checks modeset/blacklist/
initramfs state without reinstalling.

For a non-interactive run (CI, a second machine, `--yes`), set
`DOTFILES_NVIDIA_MODE=debian|open|nvidia|nouveau` beforehand and the prompt is
skipped — set, it wins; unset with no terminal to ask on (or under `--yes`),
it falls back to the default:

```
DOTFILES_NVIDIA_MODE=open ./bootstrap.sh nvidia
```

This is `register_option` (`lib/steps.sh`) — any step can declare a small set
of choices the same way; `resolve_step_options` (`lib/options.sh`) asks for
all of them together, right before sudo, for whatever ends up in the plan.

Follows JaKooLit's `Debian-Hyprland/install-scripts/nvidia.sh` for the
`debian` path; the driver choices and the NVIDIA CUDA repo plumbing follow
that project's successor,
[LinuxBeginnings/Debian-Hyprland](https://github.com/LinuxBeginnings/Debian-Hyprland)'s
newer `nvidia.sh` — asked up front here instead of interleaved with its own
install output, so it fits this repo's "every prompt happens before any step
runs" rule.

**Secure Boot check**, from the same newer script: an unsigned kernel module
can fail to load under Secure Boot, and with nouveau also blacklisted that's
**no** KMS driver at all — a black screen on every boot, not just software
rendering. The step warns up front if `mokutil --sb-state` reports Secure
Boot on. If you land on a black screen anyway: switch to a text console
(Ctrl+Alt+F3), log in, and run `./bootstrap.sh --doctor` — it tells apart
"just reboot" from "Secure Boot blocked the module" and gives the exact fix
(disable Secure Boot, or `sudo mokutil --disable-validation` + reboot + enrol
at the MOK prompt).

### Hybrid laptops

The NVIDIA Hyprland env goes in `~/.config/hypr/conf.d/local.conf` —
untracked, because `GBM_BACKEND=nvidia-drm` on a card-less machine breaks
rendering outright. `hyprland.conf` sources it last; `step_stow` creates an
empty one so that source always resolves.

- **Discrete only** — the full block: `LIBVA_DRIVER_NAME`,
  `__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND`, `GBM_BACKEND`.
- **Hybrid** (e.g. Renoir + GTX 1660 Ti) — none of them; the session stays on
  the iGPU, single apps go to the NVIDIA card with `prime-run blender`.

If Hyprland picks the wrong GPU to render on, `AQ_DRM_DEVICES` in
`local.conf` pins it to a specific `/dev/dri/by-path/...` node.

## Login

`greetd` + `tuigreet` — two packages, no Qt or GTK. Runs on tty1 and lists
whatever is in `/usr/share/wayland-sessions`. Going through the session entry
(rather than launching `Hyprland` directly) avoids Debian's *"started
without start-hyprland"* warning.

`sddm` is the usual alternative if you want a graphical greeter — same
session entries, only `setup/steps/login.sh` changes.

## Layout

```
hypr/.config/hypr/              Hyprland, hyprlock, hypridle config
kitty/.config/kitty/            Terminal
zsh/                            Shell (.zshrc, .zprofile)
fastfetch/.config/fastfetch/    System info banner (new terminals)
cava/.config/cava/              Audio visualizer (SUPER+ALT+C)
dms/.config/DankMaterialShell/  DMS settings.json, plugin_settings.json,
                                  the idleInhibitToggle plugin
scripts/.local/bin/             dotfiles-backup, idle-inhibit, keybind-help,
                                  lock-session, new-app, prime-run
wallpaper/.local/share/wallpapers/  Default wallpaper
bootstrap.sh                    Entrypoint: run order + command line
setup/steps/                    One file per stage: register_step + step_<name>()
lib/common.sh                   log / warn / die
lib/paths.sh                    The PATH dirs this setup adds
lib/apt.sh                      apt install + third-party repo-add wrappers
lib/fetch.sh                    GitHub-release fetching
lib/steps.sh                    The step registry
lib/state.sh                    What has already run
lib/picker.sh                   --pick's interactive picker
lib/doctor.sh                   --doctor's checks
iso/                             Netinst image with this repo baked in
vm/                              Throwaway QEMU test VM
```

### What is deliberately NOT in this repo

- **DankMaterialShell itself** lives at `~/.config/quickshell/dms` as a real
  directory, from the pinned upstream release — upstream software, not a
  dotfile.
- **DMS binaries** (`dms`, `dgop`, `dsearch`, `matugen`) go to
  `~/.local/share/dms/bin`, not `~/.local/bin`.
- **Generated theme files** are gitignored (`kitty/…/dank-*.conf`,
  `hypr/…/dms/colors.lua`) — matugen rewrites them on every theme change.

## Key bindings

Laid out after [JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots)
(MIT). **Movement is on the arrow keys**, freeing `H/J/K/L` for mnemonics.

`SUPER+H` opens a fuzzy-searchable list of every binding (`keys` in a shell).
**Enter runs the selected binding** — destructive ones (exit, poweroff,
reboot, suspend, lock) confirm first.

```
keybind-help              fuzzy search (fzf)
keybind-help --list       plain grouped list
keybind-help workspace    open with a filter already applied
```

| Binding | Action |
|---|---|
| `SUPER+Return` | Terminal |
| `SUPER+E` | File manager |
| `SUPER+B` | Browser |
| `SUPER+D` | App launcher |
| `SUPER+A` | Dashboard overview |
| `SUPER+H` | Help / cheat sheet |
| `SUPER+S` | Settings |
| `SUPER+SHIFT+E` | Control centre |
| `SUPER+T` | Theme switcher |
| `SUPER+N` / `SUPER+SHIFT+N` | Night light / notifications |
| `SUPER+ALT+V` | Clipboard manager |
| `SUPER+W` | Wallpaper picker |
| `SUPER+M` | Monitor profile picker (hyprmon) |
| `SUPER+SHIFT+M` | Monitor layout editor (hyprmon) |
| `SUPER+I` | Toggle idle inhibit |
| `SUPER+Q` / `SUPER+SHIFT+Q` | Close window / exit Hyprland |
| `SUPER+Escape` / `SUPER+V` | Lock / power menu |
| `SUPER+SPACE` | Float window |
| `SUPER+SHIFT+F` / `SUPER+CTRL+F` | Fullscreen / maximize |
| `SUPER+arrows` | Focus |
| `SUPER+CTRL+arrows` | Move window |
| `SUPER+ALT+arrows` | Swap window |
| `SUPER+SHIFT+arrows` | Resize |
| `SUPER+ALT+scroll` | Desktop zoom |
| `SUPER+1-0` | Workspaces |
| `Print` variants | Screenshot: `SUPER` full, `+SHIFT` region, `ALT` window, `+CTRL` 5s, `+CTRL+SHIFT` 10s |

`dms ipc` lists all 46 IPC targets if you want to bind more.

### Monitor management (hyprmon)

[hyprmon](https://github.com/erans/hyprmon), built from source
(`bootstrap.sh hyprmon`, pinned to `v0.0.17`).

- `SUPER+SHIFT+M` — layout editor: drag monitors into place, set resolution/
  refresh/scale/HDR/rotation, `P` to save a named profile.
- `SUPER+M` — profile picker.

`~/.config/hyprmon/profiles/*.json` is deliberately untracked — hardware-
specific. Nothing declares a `monitor=` line any more; Hyprland's default
(preferred mode, auto-arranged) covers a fresh install.

**Before using `S` (save to config) rather than applying live**: it only
scans the top-level `hyprland.conf` for existing `monitor=` lines to
replace, so a save appends at the end. That works today (no `monitor=` line
exists anywhere else), but a `monitor=` line in any `source`d conf.d file
would be silently overridden.

### Idle inhibitor

`SUPER+I` toggles "don't lock or dim right now" via a real
`systemd-inhibit --what=idle` lock (`scripts/.local/bin/idle-inhibit`), the
same kind a video player takes and one hypridle explicitly honours.

```
idle-inhibit on|off|toggle|status
```

**Not the same as `dms ipc call inhibit toggle`** — DMS's own idle system has
no effect on hypridle, which is what actually locks the session; that path is
left off on purpose.

### What didn't port

JaKooLit's emoji picker and calculator (rofi scripts, no DMS equivalent).
Also dropped: game mode, animations menu, rofi theme selector, oh-my-zsh
theme switcher, waybar style/layout menus (no waybar here —
`SUPER+CTRL+ALT+B` toggles the DMS bar instead).

## Ricing DMS

`dms/.config/DankMaterialShell/settings.json` is stowed, and DMS rewrites it
in place — the symlink survives, and anything changed in the settings UI
(`SUPER+S`) shows up as a diff here.

`dms ipc call settings dump` prints the whole config; `dms ipc call settings
set <key> <value>` sets one. Themes live under `currentThemeName` /
`matugenScheme`.

kitty follows the shell theme automatically via `globinclude dank-*.conf` in
`kitty.conf`, with a hardcoded fallback for a fresh clone.

## Adding a new app launcher

```
new-app "My Tool" /path/to/my-tool [icon] [--terminal] [--comment "..."] [--categories "Cat;"]
```

Scaffolds a `.desktop` file for anything that doesn't ship its own. Give the
**icon as a file path** — a bare theme name can silently fall back to a
letter avatar. Editing an existing entry doesn't reliably refresh live; a new
filename appears within a second or two.

## Backups

```
dotfiles-backup                     # snapshot now
dotfiles-backup --list              # what's saved
dotfiles-backup --restore <name>    # roll back (prompts first)
```

Snapshots go to `~/.local/share/dotfiles-backups/` (newest 10 kept), outside
the repo on purpose. The file list is derived from the stow packages, so it
can't drift. Each snapshot also records `dpkg --get-selections`,
`apt-mark showmanual`, `/etc/apt/sources.list*` and group membership — not
restored automatically, but useful if an install goes wrong.

`bootstrap.sh timeshift` (step 2) is the full-system counterpart — an rsync
snapshot before anything is touched, skipped if one from the last 24h
exists, `/` has under 25GB free, or the run has nothing to install. Roll back
with `sudo timeshift --restore`.

Try `bootstrap.sh` in the throwaway QEMU VM (`vm/`) first for anything that
could cost you the machine.

## Screenshots (Quick Capture)

[Quick Capture](https://github.com/hthienloc/dms-quick-capture), a DMS plugin
with a full annotation editor (arrows, redact, stamps, text, OCR, QR
scanning, scroll capture, PDF/WebP export). Installed by
`bootstrap.sh quickcapture`, pinned to `v5.1.4`.

All `Print`-key binds plus `SUPER+SHIFT+S` open the annotator after capture.
The bar also carries a Quick Capture icon — click for the same thing,
middle-click for a region capture.

## Transit widget (krk-commute)

`bootstrap.sh krkcommute` installs [krk-commute](https://github.com/Qazorr/krk-commute)
(private repo, not vendored here) to `~/Projects/krk-commute` (override with
`DOTFILES_KRKCOMMUTE_DIR`). A `systemd --user` daemon polls the live feed
into `~/.cache/krk-commute/state.json`; a bar widget reads it via
`krk-commute show --json`.

Routes aren't configured here:

```
krk-commute configure
```

Until then the daemon exits and the widget shows a warning triangle — that's
correct, not broken. `krk-commute favourites` lists saved route names.

## Window rules

Hyprland 0.55 removed matcher support from hyprlang `windowrule` — use inline
rules on the exec dispatcher instead:

```
bindd = $mainMod ALT, C, Audio visualizer, exec, [float; size 640 360; center] kitty --class cava -e cava
```

That covers anything launched from a keybind. Windows opened by other apps
(PiP, VS Code's quick-open popup) can't be ruled on from hyprlang right now.

## Notes

- **Theming** is matugen (wallpaper → Material palette), driven by DMS.
- **Idle/lock** stays on `hypridle` + `hyprlock`. `hypridle`'s `lock_cmd`
  goes through `scripts/.local/bin/lock-session` rather than the documented
  `pidof hyprlock || hyprlock`, which let a hung hyprlock stop the session
  from ever locking again. `--dry-run` reports what it would do.
- **DMS versions are pinned** in `bootstrap.sh` — the QML and CLI share an
  API version, so bump `DMS_VERSION` and the QML together.

## Applications

Installed by `bootstrap.sh` alongside the desktop:

| | |
|---|---|
| `code` | VS Code, Microsoft's apt repo. `.zshrc`'s `code` alias adds `--ozone-platform=wayland`. |
| `claude-desktop` | Anthropic's own apt repo. |
| `brave-browser` | Own apt repo (deb822 `.sources`). |
| `ripgrep` `fd-find` `bat` `fzf` `zoxide` `eza` | Search/navigation. Debian renames `fd-find`→`fdfind`, `bat`→`batcat`; `.zshrc` aliases them back. |
| `btop` `htop` `git-delta` `neovim` | Monitoring, diffs, editing. |
| `jq` `tmux` `direnv` `gh` `command-not-found` | JSON, multiplexing, per-project env vars, GitHub CLI, zsh's suggestion plugin. |
| `shellcheck` | `--doctor` lints `bootstrap.sh`, `lib/`, `setup/steps/`, `scripts/` when installed. |
| `curl` `git` `gnupg` `unzip` `fontconfig` | `prereqs` — what every other step assumes exists. |

**Docker** (`bootstrap.sh docker`) — Engine + Compose/Buildx from Docker's
own apt repo, not Debian's `docker.io`. `bootstrap.sh groups` adds `$USER` to
`docker`; needs a fresh login like `video`/`render`/`input`.

**lazydocker** / **lazygit** (`bootstrap.sh devtools`) — pinned release
binaries (`v0.25.2` / `v0.64.1`) in `/usr/local/bin`.

**oh-my-zsh plugins** (`bootstrap.sh ohmyzsh`) — `docker`, `fzf`, `extract`,
`command-not-found` ship with oh-my-zsh; `zsh-autosuggestions` and
`zsh-syntax-highlighting` are cloned separately into `custom/plugins/`.
Order matters: syntax-highlighting must be last.
