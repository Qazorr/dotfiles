register_step summary \
    --desc "Print what to do next" \
    --group core --always

step_summary() {
    cat <<'TXT'

Done.

- You were added to video/render/input groups, and zsh is now your login
  shell — log out and back in (or reboot) for both to take effect.
- greetd is enabled but not started, so it takes over tty1 on the next
  reboot. Pick "Hyprland" at the greeter; it remembers your choice after
  that.
- First real boot: SUPER+SHIFT+M opens hyprmon's layout editor — arrange
  your actual monitors and press P to save a profile, then SUPER+M switches
  to it.
- Roll back config with: dotfiles-backup --list / --restore <name>
- Roll back the whole system with: sudo timeshift --restore
TXT
}
