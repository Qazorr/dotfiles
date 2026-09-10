register_step summary \
    --desc "Print what to do next" \
    --group core --always

step_summary() {
    cat <<'TXT'

Done.

- You were added to video/render/input groups — log out and back in (or
  reboot the VM) for that to take effect.
- No display manager was installed on purpose. Hyprland starts from a TTY
  login via ~/.zprofile — log into tty1 and it launches automatically.
- First real boot: SUPER+SHIFT+M opens hyprmon's layout editor — arrange
  your actual monitors and press P to save a profile, then SUPER+M switches
  to it.
- Roll back config with: dotfiles-backup --list / --restore <name>
- Roll back the whole system with: sudo timeshift --restore
TXT
}
