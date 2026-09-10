register_step stow \
    --desc "Symlink the dotfiles into \$HOME" \
    --group core --always

step_stow() {
    log "Stowing dotfiles"
    cd "$REPO"

    # stow aborts on a target that already exists as a real file, killing the
    # run under `set -e` — oh-my-zsh's own .zshrc does this on a fresh machine.
    # Move conflicts aside first. Not `stow --adopt`, which would pull the
    # foreign contents INTO this repo.
    local pkg rel target moved=0
    for pkg in "${STOW_PACKAGES[@]}"; do
        [ -d "$pkg" ] || continue
        while IFS= read -r rel; do
            rel="${rel#./}"
            target="$HOME/$rel"
            [ -e "$target" ] || [ -L "$target" ] || continue
            # Already ours: a symlink resolving back into this repo.
            [[ "$(readlink -f "$target" 2>/dev/null)" == "$REPO"/* ]] && continue
            # Also ours: a link inside a package pointing outside the repo,
            # so it resolves outside — the gitignored claude and krkCommute
            # links. Same file as the repo's, reached through the package
            # symlink; without this, restow renames our own file aside.
            [ "$target" -ef "$pkg/$rel" ] && continue
            warn "Moving aside $rel -> $rel.pre-dotfiles"
            mv "$target" "$target.pre-dotfiles"
            moved=$((moved + 1))
        done < <(cd "$pkg" && find . -type f -o -type l)
    done
    [ "$moved" -gt 0 ] && log "Moved $moved pre-existing file(s) aside; originals kept as *.pre-dotfiles"

    for pkg in "${STOW_PACKAGES[@]}"; do
        [ -d "$pkg" ] || { warn "no such stow package: $pkg (skipping)"; continue; }
        stow --target="$HOME" --restow "$pkg"
    done

    # hyprland.conf sources this unconditionally, so it must exist even when
    # empty. Untracked; step_nvidia writes into it.
    local local_conf="$HOME/.config/hypr/conf.d/local.conf"
    if [ ! -f "$local_conf" ]; then
        printf '%s\n' \
            "# Machine-local Hyprland config. Not tracked in the dotfiles repo." \
            "# bootstrap.sh writes the NVIDIA env block here when it finds a card." \
            > "$local_conf"
    fi
}
