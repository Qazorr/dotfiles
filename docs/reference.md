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


## Login


`greetd` + `dms-greeter`, so the login screen matches the shell. It lists
whatever is in `/usr/share/wayland-sessions`; pick **Hyprland**, not
"Hyprland (uwsm-managed)" — the plain entry runs `start-hyprland`, which is
what this config's `exec-once` autostarts assume.

`dms-greeter enable` puts it on **VT 7** and disables `getty@tty1`. Worth
knowing, because it means a greeter that fails to start leaves a black
screen with no visible console: `Ctrl+Alt+F2` is the way back in. It also
runs a whole Quickshell compositor as the `greeter` user, so it needs the
same `qml6-module-*` runtime the shell does — a missing one takes down the
greeter and the bar together (see `setup/steps/desktop.sh`).

`tuigreet` is the lightweight alternative — a terminal greeter with no Qt,
no GPU requirement, essentially nothing to crash. Only
`setup/steps/login.sh` changes.


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


Hyprland 0.55 removed matcher support from hyprlang `windowrule` — use inline
rules on the exec dispatcher instead:

```
bindd = $mainMod SHIFT, C, Audio visualizer (cava), exec, [float; size 640 360; center] $terminal --class cava -e cava
```

That covers anything launched from a keybind. Windows opened by other apps
(PiP, VS Code's quick-open popup) can't be ruled on from hyprlang right now.


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

**oh-my-zsh plugins** (`bootstrap.sh ohmyzsh`) — `docker`, `fzf`, `extract`,
`command-not-found` ship with oh-my-zsh; `zsh-autosuggestions` and
`zsh-syntax-highlighting` are cloned separately into `custom/plugins/`.
Order matters: syntax-highlighting must be last.

## Notes


- **Theming** is matugen (wallpaper → Material palette), driven by DMS.
- **Idle/lock** stays on `hypridle` + `hyprlock`. `hypridle`'s `lock_cmd`
  goes through `scripts/.local/bin/lock-session` rather than the documented
  `pidof hyprlock || hyprlock`, which let a hung hyprlock stop the session
  from ever locking again. `--dry-run` reports what it would do.
- **DMS versions are pinned** in `setup/steps/dms.sh` — the QML and CLI share
  an API version, so bump `DMS_VERSION` and the QML together.

