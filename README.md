# dotfiles

Personal Hyprland + Quickshell setup for Debian 13 (trixie). No waybar, no
rofi, no wlogout — Quickshell covers the bar, app launcher, power menu,
monitor-profile picker, and keybind cheat sheet; mako handles notifications;
swww + wallust drive wallpaper-based theming.

## Install

One command, on a fresh Debian 13 (trixie) machine:

```
git clone <this-repo-url> ~/dotfiles && cd ~/dotfiles && ./bootstrap.sh
```

That installs every package/dependency (Hyprland stack from trixie-backports,
Quickshell built from source, swww/wallust via cargo, a Nerd Font), then
symlinks every dotfile into `$HOME` via GNU Stow. Nothing else to run — and
it's safe to re-run any time (e.g. just to re-symlink after editing a
dotfile), it skips anything already installed/built.

Log out and back in afterward (group membership needs a fresh login), then
log into **tty1** — `.zprofile` execs Hyprland automatically, no display
manager involved.

## Layout

```
hypr/.config/hypr/              Hyprland, hyprlock, hypridle config
quickshell/.config/quickshell/  Bar, launcher, power menu, monitor picker (QML)
kitty/.config/kitty/            Terminal
zsh/                             Shell (.zshrc, .zprofile — the latter autostarts
                                  Hyprland on tty1 login)
mako/.config/mako/              Notification daemon config
wallust/.config/wallust/        Wallpaper -> color palette -> Hyprland + Quickshell theme
fastfetch/.config/fastfetch/    System info banner (runs on new terminals)
cava/.config/cava/              Audio visualizer (standalone + bar widget configs)
scripts/.local/bin/             monitor-switch, wallust-apply
bootstrap.sh                     Single entrypoint: packages + build + symlinks
vm/                               Throwaway QEMU test VM, see vm/README.md
```

## Key bindings

Full list (with descriptions) via `SUPER+SHIFT+/`, live from
`hyprctl binds -j`. Highlights, all in `hypr/.config/hypr/conf.d/keybindings.conf`:

| Binding | Action |
|---|---|
| `SUPER+Return` | Terminal |
| `SUPER+D` | App launcher |
| `SUPER+V` | Power menu |
| `SUPER+M` | Monitor-profile picker |
| `SUPER+Escape` | Lock |
| `SUPER+hjkl` | Focus |
| `SUPER+SHIFT+hjkl` | Move window |
| `SUPER+CTRL+hjkl` | Resize |
| `SUPER+ALT+hjkl` | Swap window |
| `SUPER+1-0` | Workspaces |
| `SUPER+ALT+C` | Audio visualizer (cava) |
| `SUPER+ALT+N` | Network manager |
| `SUPER+ALT+B` | Bluetooth manager |

Monitor profiles live in `hypr/.config/hypr/conf.d/monitors/*.conf` — add one
per layout you actually use (real output names from `hyprctl monitors`),
switch live with `monitor-switch <name>` or `SUPER+M`.
