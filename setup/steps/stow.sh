# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_stow() { # Symlink the dotfiles into $HOME
    log "Stowing dotfiles"
    cd "$REPO"

    # stow aborts the whole package if any target already exists as a real
    # file, and `set -e` would then kill the run. On a fresh machine that is
    # easy to hit: oh-my-zsh writes its own .zshrc (its --keep-zshrc only
    # preserves one that ALREADY exists), and any app run once before this
    # point may have created its own config.
    #
    # So move every conflicting target aside first. Deterministic, and the
    # backup step already has a copy. Deliberately NOT `stow --adopt`, which
    # would pull the foreign file's contents INTO this repo and overwrite the
    # version-controlled one.
    local pkg rel target moved=0
    for pkg in "${STOW_PACKAGES[@]}"; do
        [ -d "$pkg" ] || continue
        while IFS= read -r rel; do
            rel="${rel#./}"
            target="$HOME/$rel"
            [ -e "$target" ] || [ -L "$target" ] || continue
            # Already ours: a symlink resolving back into this repo.
            [[ "$(readlink -f "$target" 2>/dev/null)" == "$REPO"/* ]] && continue
            warn "Moving aside $rel -> $rel.pre-dotfiles"
            mv "$target" "$target.pre-dotfiles"
            moved=$((moved + 1))
        done < <(cd "$pkg" && find . -type f -o -type l)
    done
    [ "$moved" -gt 0 ] && log "Moved $moved pre-existing file(s) aside; originals kept as *.pre-dotfiles"

    # `dms` carries ~/.config/DankMaterialShell/settings.json. DMS rewrites
    # that file in place rather than atomically, so the stow symlink survives
    # and your shell settings track into this repo automatically.
    for pkg in "${STOW_PACKAGES[@]}"; do
        [ -d "$pkg" ] || { warn "no such stow package: $pkg (skipping)"; continue; }
        stow --target="$HOME" --restow "$pkg"
    done
}
