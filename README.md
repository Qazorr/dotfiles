# dotfiles

Personal Hyprland setup for Debian 13 (trixie), with
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) as the
desktop shell — it provides the bar, launcher, control centre, notifications,
clipboard history, polkit agent, wallpaper and theming. No waybar, no rofi,
no wlogout, no mako.

## Install

On a fresh Debian 13 (trixie) machine:

```
sudo apt install -y git                    # Debian's minimal install has no git
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

**It asks for your sudo password once, at the start, then runs unattended.**
A background keepalive refreshes the sudo timestamp for the duration, because
the Quickshell build takes 10-20 minutes with no sudo call in between and
would otherwise hit the default 15-minute timeout and silently block on a
password prompt. apt runs with `DEBIAN_FRONTEND=noninteractive` and
`--force-confold`, so no conffile dialog can stall it either.

Expect roughly 25-40 minutes, most of it the Quickshell build and the first
timeshift snapshot.

That installs the Hyprland stack from trixie-backports, builds Quickshell
from source (not packaged for any Debian release), installs DankMaterialShell
and its helper binaries from upstream release tarballs, installs the apps
below, then symlinks the dotfiles into `$HOME` via GNU Stow. Safe to re-run —
each step checks whether its work is already done.

Every stage is a separate function and can be run on its own:

```
./bootstrap.sh --list          show the steps
./bootstrap.sh dms             reinstall just DankMaterialShell
./bootstrap.sh vscode cli      just the apps
./bootstrap.sh stow            just re-symlink after editing a dotfile
```

The first two steps are snapshots — a config backup and a full-system
timeshift snapshot — so there's a way back before anything changes. Skip
either with `DOTFILES_SKIP_BACKUP=1` / `DOTFILES_SKIP_TIMESHIFT=1` (the test
VM wants both).

Any pre-existing config file that a stow package wants to own is moved aside
to `<name>.pre-dotfiles` first, so the run can't die on a stow conflict. That
covers oh-my-zsh's own `.zshrc` (its `--keep-zshrc` only preserves one that
*already* exists, so on a genuinely fresh machine it writes its own) and
anything an app created before bootstrap ran. Deliberately not `stow --adopt`,
which would pull the foreign file's contents *into* this repo.

Log out and back in afterward (group membership needs a fresh login), then
log into **tty1** — `.zprofile` execs Hyprland automatically, no display
manager involved.

## Screenshots (Quick Capture)

Screenshots go through [Quick Capture](https://github.com/hthienloc/dms-quick-capture)
— a DMS plugin with a full annotation editor (arrows, redact, stamps, text,
OCR text recognition, QR scanning, scroll capture, PDF/WebP export), not a
raw grim/slurp dump. It replaced an earlier grim/slurp
`scripts/.local/bin/screenshot`.

Installed by `bootstrap.sh quickcapture`, pinned to `v5.1.4` (its own repo,
not vendored into this one — same reasoning as Quickshell/DMS/hyprmon: it's
upstream code with its own Rust source and translations, refetched fresh
each install rather than committed here). Its dedicated Rust capture
backend is downloaded as a version-matched, checksum-verified release
binary — no Rust toolchain needed. `imagemagick`, `img2pdf`,
`tesseract-ocr`, and `zbar-tools` cover the export/OCR/QR extras.

All the `Print`-key binds plus `SUPER+SHIFT+S` open the annotator after
capture (`dms ipc call quickCapture screenshot <mode> edit`). DMS has no
native capture delay, so the two delayed variants wrap the IPC call in a
plain `sleep`. The bar also carries a Quick Capture icon
(`rightWidgets` in `settings.json`) — click for the same thing, or middle-
click it directly for a region capture (per the plugin's own shortcuts).

## Transit widget (krk-commute)

`bootstrap.sh krkcommute` installs [krk-commute](https://github.com/Qazorr/krk-commute)
— a personal GTFS/GTFS-Realtime departure-countdown project, private repo,
not vendored into these dotfiles. It clones to `~/Projects/krk-commute` (the
path its own docs assume) and re-`pull`s on every run rather than pinning a
tag: unlike DMS/hyprmon/Quick Capture, this one has no releases and changes
whenever its own repo does.

Two processes joined only by a JSON file: a `systemd --user` daemon
(`krk-commute.service`) polls the live feed and writes
`~/.cache/krk-commute/state.json`; a bar widget reads that file via
`krk-commute show --json` — no network on the widget side, so it can poll
every few seconds for free.

The widget was originally built for a different shell (Omarchy's own
Quickshell fork); `plugin-dms/` is a DMS-native port living inside the
krk-commute repo itself (co-located with the daemon it talks to, not
duplicated into this repo), symlinked from
`~/.config/DankMaterialShell/plugins/krkCommute`. Same countdown logic, only
the surrounding widget-library components changed (DMS's `PluginComponent`/
`Theme`/`DankFlickable` in place of Omarchy's `Panel`/`Style`/`Color`).

Its own installer (`install.sh`) and uv both default to symlinking their
binary into `~/.local/bin` — which here is a stow symlink into this repo,
so that default would silently commit a binary to git. Both are redirected
(`XDG_BIN_HOME` / `UV_INSTALL_DIR`) to `~/.local/share/krk-commute/bin` and
`~/.local/share/uv/bin` instead, added to `PATH` in `.zprofile`/`.zshrc`.
The shipped systemd unit also hardcodes `ExecStart=%h/.local/bin/krk-commute`
— wrong for the same reason — so the bootstrap step `sed`s in the real path
when installing the unit rather than copying it as-is.

Routes aren't configured by this step — that's an interactive wizard asking
about your actual commute, which nothing here can answer for you:

```bash
krk-commute configure
```

Until you do, the daemon exits (no `config.toml` yet) and the bar widget
shows a warning-triangle icon — correct, not broken. `krk-commute
favourites` lists saved route names for the plugin's settings panel
(`favourite`, under the widget's own gear icon).

## Applications

Installed by `bootstrap.sh` alongside the desktop:

| | |
|---|---|
| `code` | VS Code, from Microsoft's apt repo (not in any Debian release). The `code` alias in `.zshrc` adds `--ozone-platform=wayland` so it runs natively rather than through XWayland. |
| `claude-desktop` | Claude Desktop, from Anthropic's own apt repo. |
| `brave-browser` | Brave, from its own apt repo (deb822 `.sources` file, per brave.com/linux's current documented method). |
| `ripgrep` `fd-find` `bat` `fzf` `zoxide` `eza` | Search/navigation tooling. Debian renames two of these — `fd-find` installs `fdfind`, `bat` installs `batcat` — and `.zshrc` aliases them back. |
| `btop` `htop` `git-delta` `neovim` | Monitoring, diffs, editing. |

## Layout

```
hypr/.config/hypr/              Hyprland, hyprlock, hypridle config
kitty/.config/kitty/            Terminal
zsh/                            Shell (.zshrc, .zprofile — the latter sets PATH
                                  and autostarts Hyprland on tty1 login)
fastfetch/.config/fastfetch/    System info banner (runs on new terminals)
cava/.config/cava/              Audio visualizer (SUPER+ALT+C)
dms/.config/DankMaterialShell/  DMS settings.json, plugin_settings.json, and
                                  the idleInhibitToggle plugin — your shell
                                  config, everything else in that directory
                                  is upstream (see below)
scripts/.local/bin/             dotfiles-backup, idle-inhibit, keybind-help,
                                  lock-session, new-app
wallpaper/.local/share/wallpapers/  Default wallpaper
bootstrap.sh                    Thin entrypoint — sourcing + the runner only
setup/steps/                    One file per install stage (step_<name>() {
                                  # description ... }); add a step by adding
                                  a file here and to bootstrap.sh's STEPS
lib/                            Shared helpers: log/warn/die, apt install +
                                  repo-add wrappers, GitHub-release fetching
                                  — sourced by bootstrap.sh and scripts/
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
shell). Type to filter across the key combo, the description and the command;
**Enter runs the selected binding**. JaKooLit's rofi version deliberately
disables that — "pressing ENTER will have NO function" — but running it is
genuinely useful for the bindings you can never remember, so instead the
destructive ones (exit, poweroff, reboot, suspend, lock) ask for confirmation
first.

```
keybind-help              fuzzy search (fzf)
keybind-help --list       plain grouped list
keybind-help workspace    open with a filter already applied
```

It reads `hyprctl binds -j`, so it always matches the live config — add a
`bindd` line and it appears with no extra work. Without a terminal or without
fzf it degrades to the plain list rather than failing.

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
job, not a hand-rolled script. It replaced an earlier
`conf.d/monitors/*.conf` + `monitor-switch` setup — built from source
(`bootstrap.sh hyprmon`, pinned to `v0.0.17`; Go isn't packaged for Debian
at a new enough version, so it's built the same way Quickshell is).

- `SUPER+SHIFT+M` — the layout editor: a visual "desk map" TUI, drag monitors
  into place with the mouse or arrow keys, set resolution/refresh/scale/HDR/
  rotation, then `P` to save a named profile.
- `SUPER+M` — the profile picker: pick a saved profile and switch live.

hyprmon's own profile store (`~/.config/hyprmon/profiles/*.json`) is
deliberately **not** tracked in this repo — profiles are specific to actual
attached hardware, discovered by using the tool, not something meaningful to
ship from a machine that only ever had one panel to test against. First time
on a new machine: `SUPER+SHIFT+M`, arrange things, `P` to save, then `SUPER+M`
to switch between whatever you've saved.

Nothing in `hyprland.conf` declares a `monitor=` line any more — with none
present, Hyprland's own default (preferred mode, auto-arranged) covers a
fresh install until hyprmon profiles exist.

**One thing worth knowing before you hit `S` (save to config) instead of
just applying live**: read hyprmon's own source
(`writeHyprlangConfig` in `hyprland.go`) confirmed it only scans the
top-level `hyprland.conf` for existing `monitor=` lines to replace. Since
this config never declares one there, a save appends fresh lines at the end
instead of erroring — which works (last declaration wins), but if any
`source`d conf.d file ever gains a `monitor=` line again, that file would go
silently overridden rather than actually doing anything. There isn't one now
(this section replaced the one that did), so it's not live risk today — just
the trap to remember before adding monitor config anywhere but hyprmon.

### Idle inhibitor

`SUPER+I` toggles "don't lock or dim the screen right now" — the JaKooLit
feature, a different mechanism. JaKooLit's version (a waybar module) works by
killing and restarting the whole `hypridle` process, which cancels dpms-off
and suspend too, not just the lock — a bigger hammer than the job needs.

`scripts/.local/bin/idle-inhibit` instead takes a real `systemd-inhibit
--what=idle` lock — the same mechanism a video player or presentation app
takes automatically, and one hypridle explicitly checks for
(`general:ignore_systemd_inhibit`). Verified directly against hypridle's own
log output: with the lock held it logs `Ignoring from onIdled(), inhibit
locks: 1` and skips the timeout; releasing it lets the next timeout fire
normally. Feedback is a DMS toast (falls back to `notify-send`, then to
nothing, rather than erroring if neither is available).

```
idle-inhibit on|off|toggle|status
```

There's also a bar widget and `SUPER+I` — same script either way, so the
icon can never disagree with what's actually inhibited. It's a DMS plugin
(`dms/.config/DankMaterialShell/plugins/idleInhibitToggle/`), not a patch to
DMS's own QML: anything edited directly in `~/.config/quickshell/dms` gets
wiped by `bootstrap.sh dms` (it does `rm -rf` and re-extracts the pinned
release), but `~/.config/DankMaterialShell/plugins/` is a separate directory
DMS's own plugin scanner watches, untouched by that step. The plugin polls
`idle-inhibit status` every 4s via `Proc.runCommand` rather than tracking its
own boolean, so it reflects reality even if you toggle it from the keybind or
a terminal instead of clicking the bar icon.

Enabling it took two files DMS itself writes and isn't obvious from the
plugin.json alone, both now tracked in `dms/.config/DankMaterialShell/`:
`plugin_settings.json` (holds `{"enabled": true}`, in a separate file from
`settings.json` — found by watching what actually changed on disk after
`dms ipc call plugins enable idleInhibitToggle`, not by reading the docs,
which describe a different config shape than this version actually uses) and
the `idleInhibitToggle` entry in `settings.json`'s `rightWidgets`.

A Control Center toggle was attempted too (`ccWidgetIcon`/`ccWidgetToggled`
etc., documented in DMS's own plugin README) and dropped — it rendered as a
bare "Unknown" tile with a question-mark icon instead of picking up those
properties. Bar-only for now; the code for it wasn't kept.

**Not the same thing as `dms ipc call inhibit toggle`.** DMS ships its own
idle/lock/suspend system (`Services/IdleService.qml`) with a real bar widget
for it (`Widgets/IdleInhibitor.qml`, not enabled in this bar's default
layout) — but its toggle flips a flag private to DMS's own system, with no
D-Bus, systemd, or Wayland-protocol registration at all. It has zero effect
on hypridle, which is what's actually locking this session. Verified by
reading `Services/SessionService.qml`: `idleInhibited` is consulted only by
DMS's own `IdleService`, nowhere else. Enabling that bar widget would give
you a toggle that looks like it worked and locks you out anyway — left off
on purpose.

(Also probably explains why DMS's own idle timeouts default to 0 in
`settings.json` rather than actually being off: at 0, `IdleService` falls
back to a 24-hour timeout rather than disabling itself, and it runs whether
or not hypridle also does. Two independent lock/suspend systems, on very
different timescales, is a low-risk mismatch as long as it's understood.)

### What didn't port

JaKooLit's emoji picker and calculator are rofi scripts. DMS 1.5.3's spotlight
has neither built in — verified by querying it directly (`=2+2` and `:smile`
both return nothing). They're available in DMS's plugin registry
(plugins.danklinux.com) if you want them; binding dead keys would be worse
than leaving them free.

Also dropped, with no DMS or Hyprland equivalent: game mode, animations menu,
rofi theme selector, oh-my-zsh theme switcher, and the waybar style/layout
menus (there's no waybar here — `SUPER+CTRL+ALT+B` toggles the DMS bar
instead).

Monitor layout/profiles are hyprmon's job now, not a conf.d file — see
[Monitor management (hyprmon)](#monitor-management-hyprmon) above.

## Ricing DMS

`dms/.config/DankMaterialShell/settings.json` is stowed, and DMS rewrites it
in place rather than atomically — so the symlink survives and everything you
change in the shell's settings UI (`SUPER+S`) lands in this repo as a diff.
Change something, then `git diff dms/` to see exactly which key moved.

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

Verified against DMS's actual launcher (Quickshell's `DesktopEntries`,
which scans `~/.local/share/applications`): a genuinely new file appears in
`SUPER+D` within a second or two, no restart needed. Two things worth
knowing, both found by testing rather than assumed:

- An **icon given as a file path** renders reliably. An **icon given as a
  bare theme name** (e.g. `firefox`) depends on whatever icon theme is
  currently active and can silently fall back to a plain letter avatar —
  verified with a real icon (`utilities-terminal`) that exists in the
  `gnome` theme but wasn't found through DMS's own icon lookup. `new-app`
  warns when a theme name can't be found in any installed theme, but can't
  promise a name that *is* found will actually render.
- **Editing an existing entry in place doesn't reliably refresh live** —
  only a genuinely new filename is guaranteed to show up immediately.
  Re-running `new-app` on the same name may need a moment, or a DMS
  restart, before the change is visible.

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

The file list is **derived from the stow packages**, not hardcoded, so it
can't drift: add a file to any package and it's covered automatically. Files
that already resolve into this repo are skipped (they're version-controlled
already), so re-running after install saves ~150KB, not 88MB. DMS's ~570
upstream QML files are deliberately excluded — they're pinned by version in
`bootstrap.sh` and a download replaces them exactly.

Each snapshot also records system state you can't restore automatically but
will want to read if an install goes wrong: `dpkg --get-selections`,
`apt-mark showmanual`, `/etc/apt/sources.list*`, and your group membership.

`--restore` replaces stow symlinks with the original files. It materialises
any parent directory that is a stow symlink first — restoring
`~/.config/hypr/hyprland.conf` while `~/.config/hypr` is a symlink would
otherwise write *through* it and overwrite the repo's own copy.

### What this does not cover

It backs up config, not the system. `apt` changes, the Hyprland/Quickshell
install and the DMS binaries are not rolled back — only recorded. For real
system-level rollback on this ext4 setup there's no cheap CoW snapshot, so
either:

- **`bootstrap.sh timeshift`** — runs automatically as step 2. Installs
  timeshift, then takes a full-system rsync-mode snapshot before anything is
  touched. It skips itself if a snapshot from the last 24h already exists (so
  re-running bootstrap stays cheap) or if `/` has under 25GB free. Roll back
  with `sudo timeshift --restore`.

  This is a single ext4 root, so snapshots land on the same disk. That covers
  a bad install; it does **not** cover disk failure. Keep real backups
  elsewhere.

- **`vm/`** — try `bootstrap.sh` in the throwaway QEMU VM first. Still the
  safest option, and what the script's own header recommends.

## Keyboard shortcuts

`SUPER+SHIFT+/` opens `keybind-help` (also `keys` in a shell). It renders
`hyprctl binds -j` — the *live* binds — so it can't drift from the config,
and it picks up the descriptions from the `bindd` lines automatically. Add a
binding with a description and it shows up with no extra work.

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

  `hypridle`'s `lock_cmd` goes through `scripts/.local/bin/lock-session`
  rather than the documented `pidof hyprlock || hyprlock`. That documented
  form has a real failure mode, hit on this machine: hyprlock started, hung
  without ever presenting a lock surface, and stayed running. `pidof` then
  succeeds forever, so every later idle timeout thinks a lock is already up
  and the session silently stops locking altogether. `lock-session` checks
  whether hyprlock is *actually* locking (owns a session-lock surface), not
  merely running, and clears a hung one before starting a fresh lock.
  `lock-session --dry-run` reports what it would do.
- **DMS versions are pinned** in `bootstrap.sh`. The QML and the CLI share an
  API version (the shell logs `Connected (API vNN)` at startup), so bump
  `DMS_VERSION` and the QML together, not independently.
