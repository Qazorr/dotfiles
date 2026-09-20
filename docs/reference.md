# Reference

Per-feature notes: the bits worth remembering, none of it needed to install.

## Layout


```
hypr/.config/hypr/              Hyprland, hyprlock, hypridle config
kitty/.config/kitty/            Terminal
zsh/                            Shell (.zshrc, .zprofile)
fastfetch/.config/fastfetch/    System info banner (new terminals)
cava/.config/cava/              Audio visualizer (SUPER+SHIFT+C)
dms/.config/DankMaterialShell/  DMS settings.json, plugin_settings.json,
                                  the idleInhibitToggle plugin
scripts/.local/bin/             dotfiles-backup, idle-inhibit, keybind-help,
                                  lock-session, monitor-profile, new-app, pkgs,
                                  prime-run, screenshare
wallpaper/.local/share/wallpapers/  Default wallpaper (+ dharmx/walls, opt-in)
vscode/.config/vscode-custom/   VS Code UI tweaks (custom.css/.js), see below
bootstrap.sh                    Entrypoint: run order + command line
setup/steps/                    One file per stage: register_step + step_<name>()
lib/common.sh                   log / warn / die
lib/paths.sh                    The PATH dirs this setup adds
lib/apt.sh                      nala install + third-party repo-add wrappers
lib/fetch.sh                    GitHub-release fetching
lib/steps.sh                    The step registry
lib/state.sh                    What has already run
lib/picker.sh                   --pick's interactive picker
lib/doctor.sh                   --doctor's checks
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


## Login


The `login` step asks which greeter you want:

- **dms-greeter** — themed to match the shell. It runs a whole Quickshell
  compositor as the `greeter` user, so it needs the same `qml6-module-*`
  runtime the bar does, and it comes from DankLinux's OBS repo, whose mirrors
  desync (`File has unexpected size`). Prettier, more to go wrong.
- **tuigreet** — a plain terminal greeter from Debian proper. No Qt, no GPU
  requirement, essentially nothing to crash.

Either lists whatever is in `/usr/share/wayland-sessions`; pick **Hyprland**,
not "Hyprland (uwsm-managed)" — the plain entry runs `start-hyprland`, which
is what this config's `exec-once` autostarts assume.

Set it non-interactively with `DOTFILES_GREETER=tuigreet ./bootstrap.sh login`.

`dms-greeter enable` puts greetd on **VT 7** and disables `getty@tty1`; the
tuigreet path uses VT 1. Either way a greeter that fails to start leaves a
black screen with no visible console — `Ctrl+Alt+F2` is the way back in.

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


## Wallpapers (dharmx/walls)


`bootstrap.sh walls` clones [dharmx/walls](https://github.com/dharmx/walls)
(~3.7GB of images, shallow) into `~/.local/share/wallpapers/walls`, next to
the stowed `default.png`. It's `--optional`: a plain `bootstrap.sh` run never
pulls it, since it's a multi-gigabyte download. Re-running the step does a
`git pull --ff-only` instead of a fresh clone.

If DMS is already running, the step also sets one image from the collection
as the current wallpaper, so the picker (`SUPER+W`) opens straight into that
folder; otherwise browse to `~/.local/share/wallpapers/walls` there once
manually.


## Ricing DMS


`dms/.config/DankMaterialShell/settings.json` is stowed, and DMS rewrites it
in place — the symlink survives, and anything changed in the settings UI
(`SUPER+S`) shows up as a diff here.

`dms ipc call settings dump` prints the whole config; `dms ipc call settings
set <key> <value>` sets one. Themes live under `currentThemeName` /
`matugenScheme`.

kitty follows the shell theme automatically via `globinclude dank-*.conf` in
`kitty.conf`, with a hardcoded fallback for a fresh clone.


## Window rules


Rules live in `hypr/.config/hypr/conf.d/windowrules.conf`, in the 0.53+
syntax where matchers are `match:<prop>` fields:

```
windowrule {
  name = wireshark
  match:class = ^(.*Wireshark.*)$
  float = true
}

windowrule = match:class ^vlc$, float on
```

The pre-0.53 form, `windowrule = float, class:^(x)$`, fails with "invalid
field", and `windowrulev2` is deprecated — both verified on 0.55.2.
`hyprctl clients` shows a window's class and title.

Anything launched from a keybind can instead carry inline rules on the exec
dispatcher:

```
bindd = $mainMod SHIFT, C, Audio visualizer (cava), exec, [float; size 640 360; center] $terminal --class cava -e cava
```


## VS Code UI tweaks


`vscode/.config/vscode-custom/` holds `custom.css` and `custom.js`: heavier
line numbers, boxed tabs, and a floating command palette with a blurred
backdrop. VS Code doesn't load these itself — the
[Custom UI Style](https://marketplace.visualstudio.com/items?itemName=subframe7536.custom-ui-style)
extension injects them by patching VS Code's install, so it needs write
access to `/usr/share/code`. An `apt upgrade` of `code` puts root ownership
back, so redo this after updates:

```
sudo chown -R "$USER" /usr/share/code
```

Then in VS Code's `settings.json` (not tracked here):

```json
"custom-ui-style.external.imports": [
    "file:///home/<you>/.config/vscode-custom/custom.css",
    "file:///home/<you>/.config/vscode-custom/custom.js"
]
```

and run the extension's reload command from the command palette. The older
[Custom CSS and JS Loader](https://marketplace.visualstudio.com/items?itemName=be5invis.vscode-custom-css)
takes the same two URLs under `vscode_custom_css.imports`.


## Monitor profiles


One file per desk in `~/.config/monitor-profiles/`: `monitor=` rules,
`workspace=` pinning, and anything else that desk needs (lid binds, say).
Deliberately not in this repo — external monitors are matched by EDID
description, which includes the serial number, and the repo is public.
`dotfiles-backup` snapshots them; bootstrap doesn't recreate them.

`monitor-profile --watch` (autostart) points `active.conf`, the file
`hyprland.conf` sources, at the profile whose `monitor = desc:…` lines are all
connected — on login and on every plug/unplug. The profile with the most
matching lines wins; none means no rules at all, Hyprland's defaults.
Workspaces already open move to the monitor their rule names.

```
monitor-profile --status       what's connected, which profile matches (SUPER+M)
monitor-profile                re-check now
monitor-profile --save <name>  keep the current unmatched layout as a profile
```

Setting up a new desk: plug in, `SUPER+SHIFT+M` (hyprmon), arrange, turn on
**Write as desc:** for each external monitor in its display settings (`C`),
then `S` — hyprmon is pointed at `active.conf`, so the monitor lines land
there. `monitor-profile --save <desk>` keeps them; add `workspace =` lines by
hand. Name the laptop panel `eDP-1` rather than by `desc:`, so a profile
survives swapping laptops.

hyprmon leaves `active.conf.bak.<timestamp>` backups next to the profiles.


## Screen sharing


Two separate things, deliberately kept apart.

**Hiding a window from viewers** is native to Hyprland and needs no daemon: a
`no_screen_share` window rule draws the window as a black rectangle for anyone
capturing, while it stays normal on your own screen. There's a commented
template in `conf.d/windowrules.conf`. Rules are evaluated when a window opens,
so this is config, not something toggled mid-session — and it applies to every
capture, screenshots included, which is what you want for a password manager.

**Switching options for the duration** is the part nothing else does, and what
`screenshare` is for. `screenshare watch` (autostart) listens for Hyprland's
`screencast` events and applies `~/.config/hypr/screenshare.conf` while
anything is capturing, then puts it back.

```
screenshare status          on | off | unknown
screenshare status --json   {"active":true,"kind":"monitor","count":1,...}
screenshare test [seconds]  apply the profile briefly, without a real call
```

The config is Hyprland option names and values written the way you'd write
them anywhere else, one per line:

```
decoration:blur:enabled = 0
general:gaps_out        = 5 5 5 5
```

Anything `hyprctl keyword` accepts works, multi-word values included; check a
name with `hyprctl getoption <name>`. Two reserved names, `exec-start` and
`exec-stop`, run a command instead. Each option's value is read and stored
before it's changed and restored from that snapshot, so a themer moving it
meanwhile doesn't get clobbered back to a default. Ships with blur and
animations off while sharing: both are expensive to encode and the first things
a call's compression smears.

For the bar indicator, DMS's own `privacyIndicator` widget is enabled rather
than anything custom — it also covers mic and camera. It detects sharing by
matching PipeWire node names, so it sees portal casts and won't false-positive
on a screenshot. Note that DMS's *control centre* screen-share icon
(`controlCenterShowScreenSharingIcon`) is Niri-only and does nothing here.

Worth knowing, all verified against 0.55.2 rather than assumed:

- There is no "am I being captured?" query, only events. That is why the
  watcher has to be running for `status` to answer at all — with no watcher it
  says `unknown`, never a confident `off`.
- The events fire for **any** screencopy client, not just a browser call, so a
  plain `grim` screenshot emits the same start/stop pair a real share does.
  The watcher waits a second (`SCREENSHARE_SETTLE`) before acting, which the
  pair cancels out inside.
- Hyprland does **not** aggregate: six clients produce six starts and six
  stops. The watcher counts rather than assigns, or the first viewer to leave
  a call would look like the whole share ending.
- `hyprctl` exits 0 whatever happens, so success is the literal `ok` it prints.
- `hyprctl reload` drops every runtime `keyword`, so the watcher re-applies on
  `configreloaded`.


## Adding a new app launcher


```
new-app "My Tool" /path/to/my-tool [icon] [--terminal] [--comment "..."] [--categories "Cat;"]
```

Scaffolds a `.desktop` file for anything that doesn't ship its own. Give the
**icon as a file path** — a bare theme name can silently fall back to a
letter avatar. Editing an existing entry doesn't reliably refresh live; a new
filename appears within a second or two.


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

**nala** (`bootstrap.sh nala`) — the bootstrap installs everything through
it, and `/usr/local/bin/apt` is a shim that hands it `apt install`, `upgrade`,
`search` and the like from any shell, script or `sudo`. It falls through to
the real apt when there's no terminal, for a flag nala doesn't share
(`-s`, `--reinstall`, `--no-install-recommends`…) or a verb it lacks
(`policy`, `edit-sources`). `apt-get` is untouched.

For anything critical, `sudo /usr/bin/apt …` is plain apt, guaranteed: it's a
path, not a flag the shim reads, so it works even if the shim or nala itself
is broken. `sudo rm /usr/local/bin/apt` turns the shim off entirely.

`pkgs` (`SUPER+ALT+I`, or **Install Packages** in the launcher) is an fzf
picker over every package not yet installed, searchable by name and
description; `pkgs remove` (`SUPER+ALT+SHIFT+I`, **Remove Packages**) lists
only manually installed ones. Both hand the picks to nala, which still shows
its summary and asks first. The launchers are stowed from
`scripts/.local/share/applications/`; the popup's size is a window rule on
class `pkgs`.

**oh-my-zsh plugins** (`bootstrap.sh ohmyzsh`) — `docker`, `fzf`, `extract`,
`command-not-found` ship with oh-my-zsh; `zsh-autosuggestions` and
`zsh-syntax-highlighting` are cloned separately into `custom/plugins/`.
Order matters: syntax-highlighting must be last.

## Notes


- **Theming** is matugen (wallpaper → Material palette), driven by DMS.
- **Cursor** is Bibata-Modern-Classic from Debian's `bibata-cursor-theme`
  (XCursor only, no hyprcursor build): `XCURSOR_THEME` in
  `conf.d/environment.conf` for Hyprland, gsettings (desktop step) for GTK
  apps and DMS.
- **Idle/lock** stays on `hypridle` + `hyprlock`. `hypridle`'s `lock_cmd`
  goes through `scripts/.local/bin/lock-session` rather than the documented
  `pidof hyprlock || hyprlock`, which let a hung hyprlock stop the session
  from ever locking again. `--dry-run` reports what it would do.
- **DMS versions are pinned** in `setup/steps/dms.sh` — the QML and CLI share
  an API version, so bump `DMS_VERSION` and the QML together.

