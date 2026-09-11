register_step summary \
    --desc "Print what to do next" \
    --group core --always

step_summary() {
    cat <<'TXT'

Done.

- You were added to video/render/input groups, and zsh is now your login
  shell — log out and back in (or reboot) for both to take effect.
- greetd is enabled but not started, so the greeter comes up on the next
  reboot (VT 7). Pick "Hyprland" — not "Hyprland (uwsm-managed)" — and it
  remembers the choice. If it ever fails, Ctrl+Alt+F2 gets you a console.
- First real boot: SUPER+SHIFT+M opens hyprmon's layout editor — arrange
  your actual monitors and press P to save a profile, then SUPER+M switches
  to it.
- Roll back config with: dotfiles-backup --list / --restore <name>
- Roll back the whole system with: sudo timeshift --restore
TXT
}
