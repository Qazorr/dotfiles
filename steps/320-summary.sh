register_step summary \
    --desc "Print what to do next" \
    --group core --always

step_summary() {
    cat <<'TXT'

Done. Next:

- Reboot. Group changes and zsh as login shell need a new session.
- At the greeter pick "Hyprland", not "Hyprland (uwsm-managed)".
  Ctrl+Alt+F2 gives a console if it fails.
- SUPER+SHIFT+M: arrange monitors in hyprmon, press P to save a profile.
  It applies whenever those monitors are connected; SUPER+M shows status.
- Keep the repo current:  dotfiles status, dotfiles sync, dotfiles update
TXT
}
