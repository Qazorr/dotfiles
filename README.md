# dotfiles

Personal Hyprland setup for Debian 13 (trixie), with
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) as the
desktop shell — it provides the bar, launcher, control centre, notifications,
clipboard history, polkit agent, wallpaper and theming. No waybar, no rofi,
no wlogout, no mako.

## Install

On a machine that already has Debian 13 (trixie):

```
sudo apt install -y git                    # Debian's minimal install has no git
git clone git@github.com:Qazorr/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

The repo is private, so that clone needs an SSH key or `gh auth login` first —
and for the same reason there's no `curl | bash` one-liner.

**From bare metal**, `./iso/build.sh` builds a Debian netinst image with the
repo already on it, so a new machine needs no credentials at install time. See
[iso/README.md](iso/README.md).

`./bootstrap.sh` with no arguments runs every step in order, and stays the
command you use afterwards — after adding a step, or changing one.

### It remembers what it has already done

Each finished step gets a file under `~/.local/state/dotfiles/steps`, and the
next run skips it. First run: 15-20 minutes. Second: a couple of seconds.

The record is a hash of the step's own file, not just a done flag. Add a
package to `setup/steps/cli.sh` or bump `LAZYDOCKER_VERSION` in `devtools.sh`,
and the next run notices and redoes that step — only that step. A plain flag
would skip your edit forever.

Four steps are exempt and always run: the two snapshots, `stow` (you re-run
bootstrap precisely because a dotfile changed) and `summary`. The snapshots
also sit out a run with nothing left to install — nothing to roll back from.

Failures aren't recorded, so the next run retries. Neither is a step that
returns early without finishing; `krkcommute` calls `stamp_skip` to say so
when the private repo won't clone.

```
./bootstrap.sh --list             every step, with install and run status
./bootstrap.sh --force            run it all again, records or no records
./bootstrap.sh --forget cli       drop one record
./bootstrap.sh --mark-done        record what already looks installed, run nothing
./bootstrap.sh --dry-run          print the plan, change nothing
```

`--mark-done` is for a machine set up before any of this existed: it records
every step whose `--provides` probe already passes, so the next run does only
the genuinely-remaining work. Name steps explicitly to vouch for ones it
can't probe.

### Running less than everything

Naming steps runs them whatever the records say:

```
./bootstrap.sh dms vscode         named steps (prerequisites pulled in)
./bootstrap.sh --profile desktop  a named set of groups
./bootstrap.sh --group dev        one group
./bootstrap.sh --missing          only what isn't installed yet
./bootstrap.sh --pick             choose interactively
```

Profiles: `full`, `desktop` (no dev tooling or personal projects), `cli`
(shell only — no Hyprland, fine on a server) and `dev`. Groups: `core safety
shell desktop apps dev personal`.

`--pick` lists every step by group, all ticked, marked `(done)` or
`(installed)`. `core` steps show `[*]` and can't be unticked.

```
  1 5 9   toggle those steps        a  everything
  g dev   toggle a whole group      n  nothing but the locked steps
  p cli   apply a profile           m  only what looks missing
  Enter   run the ticked steps      q  quit
```

**Sudo is asked for once, at the start**, and only if the chosen steps need
root — `./bootstrap.sh stow` never prompts. A keepalive refreshes the
timestamp, since the hyprmon build and a full apt upgrade can outlast sudo's
15-minute timeout with no sudo call in between. apt runs with `DEBIAN_FRONTEND=noninteractive` and
`--force-confold`, so no conffile dialog can stall it.

Every step also checks its own work independently of the records, so it still
behaves on a machine whose records were wiped. A failing step stops the run
and prints the command to resume from (`--keep-going` runs the rest and lists
failures at the end).

The first two steps are a config backup and a timeshift snapshot; skip either
with `DOTFILES_SKIP_BACKUP=1` / `DOTFILES_SKIP_TIMESHIFT=1`.

Pre-existing config a stow package wants to own is moved to
`<name>.pre-dotfiles` first, so the run can't die on a stow conflict — notably
oh-my-zsh's own `.zshrc`. Deliberately not `stow --adopt`, which would pull
the foreign contents *into* this repo.

Afterwards reboot. `greetd` takes over tty1 with `tuigreet`, a terminal
greeter — pick **Hyprland** and it remembers the choice. The reboot is also
what picks up your new group membership and login shell.

### Checking a machine

```
./bootstrap.sh --doctor
```

Reads, never writes. Reports which steps aren't installed, whether the stow
symlinks still point into this repo, whether the four copies of the `PATH`
additions agree, group membership, leftover `.pre-dotfiles` files, and — with
`shellcheck` installed — whether the repo's scripts lint clean.

The check that earns its keep is **writethrough**: `~/.local/bin`,
`~/.config/hypr`, `~/.config/kitty` and `~/.config/DankMaterialShell/plugins`
are stow symlinks *into this repo*, so anything writing there writes inside a
tracked git checkout. That has happened seven times — uv, the krk-commute
installer, Claude Code's self-updater, matugen's generated themes — each
caught by eye in `git status`. `--doctor` flags any untracked file under a
stow package, so the eighth is caught by a command instead.

### Adding or changing a step

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
| `--always` | never recorded, so it runs every time. Only where repeating is the point: the snapshots, `stow`, `summary` |
| `--needs` | must *already be done* for this step's install to succeed; pulled in automatically. Install-time only, not "would be nice at runtime" — otherwise `./bootstrap.sh dms` would drag in an NVIDIA driver install |
| `--provides` | a command or path that exists once the step has run. Drives `--list`, `--missing` and `--doctor`. Steps that only change system state declare none |

A step returning 0 without having done its work should call `stamp_skip`, so
it isn't recorded and the next run retries. A non-zero return needs nothing.

The only other thing to touch is `STEPS` in `bootstrap.sh` — the run order,
the one fact that can't live in the step's own file. `steps_validate()` aborts
at startup if the two disagree: an unregistered name, a registered step with
no function, or a `--needs` pointing at something that runs later.

Every step must be **idempotent**. `set -euo pipefail` is on, so guard
anything that can legitimately fail — `step_groups` wraps `usermod -aG docker`
in a `getent group docker` test, because `usermod` against a nonexistent group
is a hard abort.

### Adding something you just installed

The loop this repo is built for: try a thing by hand, and if you keep it, fold
it in so the next machine gets it too. Which file you touch depends only on
where the thing comes from.

**An apt package from Debian** — add it to the list in `setup/steps/cli.sh`
(shell tools) or `desktop.sh` (anything graphical). Nothing else. If it is
worth `--doctor` checking, add the command name to that step's `--provides`.

**A tool with its own apt repo** (vendor-published) — a new step, using the
two helpers:

```bash
ensure_apt_key  https://vendor.example/gpg /etc/apt/keyrings/vendor.asc
ensure_apt_list /etc/apt/sources.list.d/vendor.list \
    "deb [signed-by=/etc/apt/keyrings/vendor.asc] https://vendor.example/deb stable main" \
    "vendor.example"
apt_install thetool
```

`docker.sh`, `vscode.sh`, `brave.sh` and `danklinux.sh` are four worked
examples; copy whichever is closest.

**A single binary from a GitHub release** — a new step using
`install_github_release_binary` (see `devtools.sh`), pinned to a tag rather
than "latest", so a machine built today and one built next month match.

**A dotfile change** — just edit the file. `~/.config/hypr`, `~/.config/kitty`
and the rest are stow symlinks *into this repo*, so editing them in place is
editing the repo. `git diff` shows what moved; no bootstrap run needed.

#### The one rule that matters

**Never install anything into `~/.local/bin`.** It is a stow symlink into this
repo, so a binary written there is a binary committed to git. It has happened
eight times. Install to `/usr/local/bin` (system-wide, like `devtools.sh`) or
`~/.local/share/<tool>/bin` (per-user, like `uv.sh`) — and if you choose the
latter, add it to `DOTFILES_PATH_DIRS` in `lib/paths.sh` and to the three
files that repeat that list. `--doctor` checks they agree.

#### Then

```bash
./bootstrap.sh
```

Editing a step file changes its hash, so that step un-records itself and the
next run redoes just it, skipping everything else. You do not need to name it
or pass `--force`.

```bash
./bootstrap.sh --doctor
```

Which is also how you find out whether the thing you installed by hand wrote
into the repo behind your back — that check exists because it keeps happening.

Anything that could cost you the machine — a driver, the bootloader, the login
manager — belongs in the VM first (`vm/README.md`). Everything else is safe to
try live, because `backup` and `timeshift` run before any of it.

## Screenshots (Quick Capture)

Screenshots go through [Quick Capture](https://github.com/hthienloc/dms-quick-capture),
a DMS plugin with a full annotation editor (arrows, redact, stamps, text, OCR,
QR scanning, scroll capture, PDF/WebP export) rather than a raw grim/slurp
dump.

Installed by `bootstrap.sh quickcapture`, pinned to `v5.1.4` and refetched
each install rather than vendored here — same reasoning as
Quickshell/DMS/hyprmon. Its Rust capture backend comes as a version-matched,
checksum-verified release binary, so no toolchain is needed. `imagemagick`,
`img2pdf`, `tesseract-ocr` and `zbar-tools` cover the export/OCR/QR extras.

All `Print`-key binds plus `SUPER+SHIFT+S` open the annotator after capture
(`dms ipc call quickCapture screenshot <mode> edit`). DMS has no native
capture delay, so the delayed variants wrap the IPC call in a `sleep`. The bar
also carries a Quick Capture icon — click for the same thing, middle-click for
a region capture.

## Transit widget (krk-commute)

`bootstrap.sh krkcommute` installs [krk-commute](https://github.com/Qazorr/krk-commute),
a personal GTFS/GTFS-Realtime departure-countdown project — private repo, not
vendored here. It clones to `~/Projects/krk-commute` (override with
`DOTFILES_KRKCOMMUTE_DIR`) and re-`pull`s each run rather than pinning: unlike
DMS/hyprmon/Quick Capture it has no releases.

Two processes joined by a JSON file: a `systemd --user` daemon polls the live
feed into `~/.cache/krk-commute/state.json`, and a bar widget reads it via
`krk-commute show --json` — no network on the widget side, so it can poll
every few seconds for free.

The widget was built for a different shell (Omarchy's Quickshell fork);
`plugin-dms/` is a DMS-native port living in the krk-commute repo next to the
daemon it talks to, symlinked from
`~/.config/DankMaterialShell/plugins/krkCommute`. Same countdown logic, only
the widget-library components differ.

Its installer and uv both default to symlinking their binary into
`~/.local/bin` — a stow symlink into this repo, so that default would commit a
binary to git. Both are redirected (`XDG_BIN_HOME` / `UV_INSTALL_DIR`) under
`~/.local/share`, which `.zprofile`/`.zshrc` add to `PATH`. The shipped
systemd unit hardcodes the same wrong path, so the step `sed`s in the real one.

Routes aren't configured here — that's an interactive wizard about your actual
commute:

```bash
krk-commute configure
```

Until then the daemon exits (no `config.toml`) and the widget shows a warning
triangle, which is correct rather than broken. `krk-commute favourites` lists
saved route names for the plugin's settings panel.

## Applications

Installed by `bootstrap.sh` alongside the desktop:

| | |
|---|---|
| `code` | VS Code, from Microsoft's apt repo (not in any Debian release). The `code` alias in `.zshrc` adds `--ozone-platform=wayland` so it runs natively rather than through XWayland. |
| `claude-desktop` | Claude Desktop, from Anthropic's own apt repo. |
| `brave-browser` | Brave, from its own apt repo (deb822 `.sources` file, per brave.com/linux's current documented method). |
| `ripgrep` `fd-find` `bat` `fzf` `zoxide` `eza` | Search/navigation tooling. Debian renames two of these — `fd-find` installs `fdfind`, `bat` installs `batcat` — and `.zshrc` aliases them back. |
| `btop` `htop` `git-delta` `neovim` | Monitoring, diffs, editing. |
| `jq` `tmux` `direnv` `gh` `command-not-found` | JSON, multiplexing, per-project env vars, GitHub CLI (also what `krkcommute` clones its private repo with), the plugin that makes zsh's `command-not-found` suggestion actually fire. |
| `shellcheck` | This repo is almost entirely bash and a quoting mistake here half-provisions a machine. `--doctor` runs it over `bootstrap.sh`, `lib/`, `setup/steps/` and `scripts/` when it's installed. |
| `curl` `git` `gnupg` `unzip` `fontconfig` | The `prereqs` step — what every other step assumes already exists. Debian's minimal install has none of them. |

## Developer tooling

**Docker** (`bootstrap.sh docker`) — Engine + Compose/Buildx from Docker's own
apt repo, not Debian's `docker.io`, which trails upstream badly. `bootstrap.sh
groups` adds `$USER` to the `docker` group once it exists; like
`video`/`render`/`input` that needs a fresh login, not just a re-run.

**lazydocker** / **lazygit** (`bootstrap.sh devtools`) — pinned release
binaries (`v0.25.2` / `v0.64.1`) in `/usr/local/bin`, the same non-stow
location hyprmon uses and for the same reason.

**oh-my-zsh plugins** (`bootstrap.sh ohmyzsh`) — `docker`, `fzf`, `extract`
and `command-not-found` ship with oh-my-zsh and only need naming in `.zshrc`.
`zsh-autosuggestions` and `zsh-syntax-highlighting` are separate repos, cloned
into `custom/plugins/` and re-`pull`ed later (no tags to pin). Order matters:
syntax-highlighting must be last, or anything after it is silently ignored.

## Login

`greetd` plus `tuigreet` — two packages, no further dependencies, no Qt or
GTK. It runs on tty1 and lists whatever is in `/usr/share/wayland-sessions`,
so Hyprland shows up without this repo naming it anywhere.

That indirection matters: Debian's `hyprland.desktop` is
`Exec=/usr/bin/start-hyprland`, and launching the `Hyprland` binary directly
gets you a *"started without start-hyprland, this is highly not recommended"*
banner on every login. Going through the session entry uses the launcher
upstream actually wants.

An earlier version had no login manager at all — `~/.zprofile` checked for
tty1 and `exec`ed Hyprland from the login shell. It worked, but only if zsh
was your login shell, which Debian doesn't do by default, so a fresh install
dropped you at a bash prompt with no way in. greetd is both standard and
fewer moving parts.

`sddm` is the usual pairing if you want a graphical greeter instead — same
session entries, so only `setup/steps/login.sh` changes. It pulls Qt6.

## NVIDIA

`bootstrap.sh nvidia` sets up Debian's packaged NVIDIA driver, following
JaKooLit's `Debian-Hyprland/install-scripts/nvidia.sh`. It detects the card
itself (PCI vendor `10de`) and no-ops without one, so it's safe in a full run.

- Enables `contrib`/`non-free` in a separate `sources.list.d` file — a stock
  trixie install has `main non-free-firmware` only, and `nvidia-driver`
  (550.163.01) is in `non-free`.
- Installs `nvidia-driver`, `nvidia-kernel-dkms`, `firmware-misc-nonfree`,
  `linux-headers-amd64`, and the Wayland/VA-API bits. `linux-headers-amd64`
  rather than `linux-headers-$(uname -r)` so dkms still has headers after the
  next kernel upgrade.
- `options nvidia-drm modeset=1 fbdev=1` (modeset is what makes the driver
  usable under Wayland at all) and `NVreg_PreserveVideoMemoryAllocations=1`,
  plus the `nvidia-suspend`/`resume`/`hibernate` units it depends on.
- Puts the nvidia modules in the initramfs and blacklists nouveau on the
  kernel command line, then rebuilds the initramfs and GRUB config.

Reboot afterwards to actually switch off nouveau.

### Hybrid laptops

The NVIDIA Hyprland env goes in `~/.config/hypr/conf.d/local.conf` —
untracked, because `GBM_BACKEND=nvidia-drm` on a card-less machine breaks
rendering outright. `hyprland.conf` sources it last and `step_stow` creates an
empty one so that source always resolves. (A glob would be tidier, but
Hyprland 0.55 errors with `source= globbing error: found no match` when one
matches nothing.)

- **Discrete only** — the full block: `LIBVA_DRIVER_NAME`,
  `__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND`, `GBM_BACKEND`.
- **Hybrid** (e.g. this machine's Renoir + GTX 1660 Ti) — none of them.
  Pointing GBM/GLX at the discrete card forces the whole session onto it:
  hotter, slower to the internal panel, and on some laptops the panel stays
  dark. The session stays on the iGPU; single apps go to the NVIDIA card with
  `prime-run`:

```
prime-run blender
```

If Hyprland picks the wrong GPU to render on, `AQ_DRM_DEVICES` in
`local.conf` pins it to a specific `/dev/dri/by-path/...` node.

## Layout

```
hypr/.config/hypr/              Hyprland, hyprlock, hypridle config
kitty/.config/kitty/            Terminal
zsh/                            Shell (.zshrc, .zprofile — the latter sets the
                                  PATH a login session inherits)
fastfetch/.config/fastfetch/    System info banner (runs on new terminals)
cava/.config/cava/              Audio visualizer (SUPER+ALT+C)
dms/.config/DankMaterialShell/  DMS settings.json, plugin_settings.json and
                                  the idleInhibitToggle plugin. Everything
                                  else in that directory is upstream
scripts/.local/bin/             dotfiles-backup, idle-inhibit, keybind-help,
                                  lock-session, new-app, prime-run
wallpaper/.local/share/wallpapers/  Default wallpaper
bootstrap.sh                    Entrypoint: the run order and command line
setup/steps/                    One self-describing file per stage:
                                  register_step + step_<name>()
lib/common.sh                   log / warn / die
lib/paths.sh                    The PATH dirs this setup adds — the reference
                                  the other three copies are checked against
lib/apt.sh                      apt install + third-party repo-add wrappers
lib/fetch.sh                    GitHub-release fetching
lib/steps.sh                    The step registry: metadata, dependency
                                  resolution, drift validation
lib/state.sh                    What has already run, one file per step under
                                  ~/.local/state/dotfiles/steps
lib/picker.sh                   --pick's interactive picker (plain bash: runs
                                  on tty1 before anything is installed)
lib/doctor.sh                   --doctor's checks
iso/                            Builds a netinst image with this repo baked
                                  in, see iso/README.md
vm/                             Throwaway QEMU test VM, see vm/README.md
```

### What is deliberately NOT in this repo

- **DankMaterialShell itself** lives at `~/.config/quickshell/dms` as a real
  directory, installed by `bootstrap.sh` from the pinned upstream release.
  It's upstream software, not a dotfile, and it's ~570 QML files.
- **DMS binaries** (`dms`, `dgop`, `dsearch`, `matugen`) go to
  `~/.local/share/dms/bin`, *not* `~/.local/bin`. That path is a stow symlink
  into this repo, so anything written there would land in git.
- **Generated theme files** are gitignored: `kitty/…/dank-*.conf` and
  `hypr/…/dms/colors.lua`. matugen rewrites them on every theme change, and
  since those config dirs are stow symlinks, the writes land in this repo.

## Key bindings

Laid out after [JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots)
(MIT). **Movement is on the arrow keys** — that's what frees `H/J/K/L` for
letter mnemonics, and it's why the layout can't be mixed with vim-style hjkl
movement.

`SUPER+H` opens a **fuzzy-searchable** list of every binding (`keys` in a
shell), filtering across combo, description and command. **Enter runs the
selected binding** — JaKooLit's rofi version disables that, but it's useful
for the ones you can never remember, so destructive bindings (exit, poweroff,
reboot, suspend, lock) confirm first instead.

```
keybind-help              fuzzy search (fzf)
keybind-help --list       plain grouped list
keybind-help workspace    open with a filter already applied
```

It reads `hyprctl binds -j`, so it always matches the live config. Without a
terminal or fzf it degrades to the plain list rather than failing.

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

Monitor layout and profiles are [hyprmon](https://github.com/erans/hyprmon)'s
job, replacing an earlier `conf.d/monitors/*.conf` + `monitor-switch` setup.
Built from source (`bootstrap.sh hyprmon`, pinned to `v0.0.17`) since Debian's
Go is too old.

- `SUPER+SHIFT+M` — the layout editor: a visual "desk map" TUI, drag monitors
  into place with the mouse or arrow keys, set resolution/refresh/scale/HDR/
  rotation, then `P` to save a named profile.
- `SUPER+M` — the profile picker: pick a saved profile and switch live.

hyprmon's profile store (`~/.config/hyprmon/profiles/*.json`) is deliberately
**not** tracked: profiles are specific to actually-attached hardware. On a new
machine, `SUPER+SHIFT+M`, arrange, `P` to save.

Nothing declares a `monitor=` line any more; with none present Hyprland's
default (preferred mode, auto-arranged) covers a fresh install.

**Before using `S` (save to config) rather than applying live**: hyprmon's
`writeHyprlangConfig` only scans the top-level `hyprland.conf` for existing
`monitor=` lines to replace. Since this config declares none there, a save
appends at the end — which works (last declaration wins), but a `monitor=`
line in any `source`d conf.d file would be silently overridden. There isn't
one today; it's the trap to remember before putting monitor config anywhere
but hyprmon.

### Idle inhibitor

`SUPER+I` toggles "don't lock or dim right now". JaKooLit's version kills and
restarts `hypridle` entirely, cancelling dpms-off and suspend too — a bigger
hammer than the job needs.

`scripts/.local/bin/idle-inhibit` takes a real `systemd-inhibit --what=idle`
lock instead, the same one a video player takes and one hypridle explicitly
honours (`general:ignore_systemd_inhibit`). Verified against hypridle's log:
with the lock held it logs `Ignoring from onIdled(), inhibit locks: 1`.

```
idle-inhibit on|off|toggle|status
```

The bar widget and `SUPER+I` both call that script, so the icon can't disagree
with reality — it polls `idle-inhibit status` every 4s rather than tracking
its own boolean. It's a DMS plugin
(`dms/.config/DankMaterialShell/plugins/idleInhibitToggle/`), not a patch to
DMS's QML: `bootstrap.sh dms` does `rm -rf` and re-extracts the pinned
release, so anything edited in `~/.config/quickshell/dms` is wiped, while
`~/.config/DankMaterialShell/plugins/` is untouched.

Enabling it takes two files DMS writes itself, both tracked here:
`plugin_settings.json` (`{"enabled": true}` — a separate file from
`settings.json`, found by watching what changed on disk, since the docs
describe a different config shape) and the `idleInhibitToggle` entry in
`settings.json`'s `rightWidgets`. A Control Center tile was tried and dropped:
it rendered as a bare "Unknown" instead of picking up `ccWidgetIcon` etc.

**Not the same as `dms ipc call inhibit toggle`.** DMS's own idle system
(`Services/IdleService.qml`) flips a flag private to itself, with no D-Bus,
systemd or Wayland registration — zero effect on hypridle, which is what
actually locks this session (`idleInhibited` is read only by `IdleService`).
Its bar widget would look like it worked and lock you out anyway, so it's left
off. That also explains DMS's idle timeouts defaulting to 0: at 0 `IdleService`
falls back to 24 hours rather than disabling itself, and runs alongside
hypridle regardless.

### What didn't port

JaKooLit's emoji picker and calculator are rofi scripts, and DMS 1.5.3's
spotlight has neither (`=2+2` and `:smile` both return nothing). Both exist in
DMS's plugin registry if wanted; binding dead keys would be worse.

Also dropped, with no DMS or Hyprland equivalent: game mode, animations menu,
rofi theme selector, oh-my-zsh theme switcher, and the waybar style/layout
menus (there's no waybar here — `SUPER+CTRL+ALT+B` toggles the DMS bar
instead).

Monitor layout/profiles are hyprmon's job now, not a conf.d file — see
[Monitor management (hyprmon)](#monitor-management-hyprmon) above.

## Ricing DMS

`dms/.config/DankMaterialShell/settings.json` is stowed, and DMS rewrites it
in place rather than atomically — so the symlink survives and anything changed
in the settings UI (`SUPER+S`) lands here as a diff. `git diff dms/` shows
exactly which key moved.

`dms ipc call settings dump` prints the whole current config; `dms ipc call
settings set <key> <value>` sets one. Themes live under `currentThemeName` /
`matugenScheme`.

kitty follows the shell theme automatically — `kitty.conf` ends with
`globinclude dank-*.conf`, picking up matugen's generated palette, with a
hardcoded fallback above it for a fresh clone.

## Adding a new app launcher

`new-app` scaffolds a `.desktop` file for anything that doesn't ship its
own — a script, an AppImage, a one-off tool:

```
new-app "My Tool" /path/to/my-tool --icon /path/to/icon.png
new-app "My Tool" /path/to/my-tool [icon] [--terminal] [--comment "..."] [--categories "Cat;"]
```

A genuinely new file appears in `SUPER+D` within a second or two, no restart
needed. Two things found by testing:

- Give the **icon as a file path**. A bare theme name depends on the active
  icon theme and can silently fall back to a letter avatar — `utilities-terminal`
  exists in the `gnome` theme but wasn't found through DMS's own lookup.
  `new-app` warns on a name it can't find anywhere, but can't promise one it
  does find will render.
- **Editing an existing entry doesn't reliably refresh live.** Only a new
  filename is guaranteed to appear immediately; re-running `new-app` on the
  same name may need a DMS restart.

## Backups

`bootstrap.sh` snapshots your config before it changes anything (step 0).
You can also run it by hand:

```
dotfiles-backup                     # snapshot now
dotfiles-backup --list              # what's saved
dotfiles-backup --restore <name>    # roll back (prompts first)
```

Snapshots go to `~/.local/share/dotfiles-backups/`, newest 10 kept. They live
outside the repo on purpose — a backup a bad `git checkout` can delete is not
a backup.

The file list is **derived from the stow packages**, so it can't drift — add
a file to any package and it's covered. Files already resolving into this repo
are skipped (they're version-controlled), so a post-install run saves ~150KB,
not 88MB. DMS's ~570 upstream QML files are excluded: pinned by version, and a
download replaces them exactly.

Each snapshot also records system state you can't restore automatically but
will want if an install goes wrong: `dpkg --get-selections`, `apt-mark
showmanual`, `/etc/apt/sources.list*`, group membership.

`--restore` replaces stow symlinks with the original files, materialising any
parent directory that is itself a symlink first — otherwise restoring
`~/.config/hypr/hyprland.conf` writes *through* it onto the repo's own copy.

### What this does not cover

It backs up config, not the system. `apt` changes, the Hyprland/Quickshell
install and the DMS binaries are not rolled back — only recorded. For real
system-level rollback on this ext4 setup there's no cheap CoW snapshot, so
either:

- **`bootstrap.sh timeshift`** — step 2, a full-system rsync snapshot before
  anything is touched. Skipped if one from the last 24h exists, if `/` has
  under 25GB free, or if the run has nothing left to install. Roll back with
  `sudo timeshift --restore`. Single ext4 root, so snapshots land on the same
  disk: that covers a bad install, not disk failure.

- **`vm/`** — try `bootstrap.sh` in the throwaway QEMU VM first.

## Keyboard shortcuts

`SUPER+SHIFT+/` opens `keybind-help` (also `keys` in a shell). It renders
`hyprctl binds -j` — the *live* binds — so it can't drift, and picks up
descriptions from the `bindd` lines. Add a described binding and it appears.

DMS ships its own keybind viewer, but it only parses Hyprland's Lua config
format; on this hyprlang config `dms keybinds show hyprland` returns
`readOnly` and no binds at all.

## Window rules: read this before adding one

Hyprland 0.55 **removed matcher support from hyprlang `windowrule`**. Verified
on 0.55.2:

- `windowrule = float on, class:^(x)$` → *"invalid field class:^(x)$"*, the
  same error a completely made-up field name produces
- `windowrulev2 = float,class:^(x)$` → *"windowrulev2 is deprecated"*, no effect
- even `windowrule = float on` with no matcher does nothing

Rule matching now lives in the Lua config (`hl.window_rule({ match = {...} })`).
Until/unless this config migrates to `hyprland.lua`, use **inline rules on the
exec dispatcher**, which do still work:

```
bindd = $mainMod ALT, C, Audio visualizer, exec, [float; size 640 360; center] kitty --class cava -e cava
```

That covers anything launched from a keybind. Windows opened by other apps
(Picture-in-Picture, VS Code's quick-open popup) can't be ruled on from
hyprlang at all right now.

## Notes

- **Theming** is matugen (wallpaper → Material palette), driven by DMS. The
  old wallust/swww setup was removed when DMS took over.
- **Idle/lock** stays on `hypridle` + `hyprlock`. DMS ships its own lock; to
  use it instead, drop `hypridle` from `conf.d/autostart.conf` and bind
  `dms ipc call lock lock`.

  `hypridle`'s `lock_cmd` goes through `scripts/.local/bin/lock-session`, not
  the documented `pidof hyprlock || hyprlock`. That form failed here: hyprlock
  hung without presenting a lock surface but kept running, so `pidof` succeeded
  forever and the session stopped locking altogether. `lock-session` checks
  whether hyprlock owns a session-lock surface, not merely that it's running,
  and clears a hung one first. `--dry-run` reports what it would do.
- **DMS versions are pinned** in `bootstrap.sh`. The QML and the CLI share an
  API version (the shell logs `Connected (API vNN)` at startup), so bump
  `DMS_VERSION` and the QML together, not independently.
