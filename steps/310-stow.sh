register_step stow \
    --desc "Symlink the dotfiles into \$HOME" \
    --group core --always

step_stow() {
    log "Stowing dotfiles"
    cd "$STOW_DIR" || die "can't cd to $STOW_DIR"

    # DMS renames this dir itself on its first 2.x start. Done here first, the
    # stow links land in the dir it will read.
    local legacy="$HOME/.config/DankMaterialShell"
    if [ -d "$legacy" ] && [ ! -L "$legacy" ] && [ ! -e "$HOME/.config/dms" ]; then
        mv "$legacy" "$HOME/.config/dms"
        ln -s dms "$legacy"
    fi

    # stow aborts on a target that's already a real file (oh-my-zsh's .zshrc).
    # Move those aside; `stow --adopt` would pull them INTO the repo instead.
    local pkg rel target moved=0
    for pkg in "${STOW_PACKAGES[@]}"; do
        [ -d "$pkg" ] || continue
        while IFS= read -r rel; do
            rel="${rel#./}"
            target="$HOME/$rel"
            [ -e "$target" ] || [ -L "$target" ] || continue
            # A dangling link holds nothing worth keeping; a package that moved
            # inside the repo leaves these behind.
            [ -L "$target" ] && [ ! -e "$target" ] && {
                rm -f "$target"
                continue
            }
            [[ "$(readlink -f "$target" 2>/dev/null)" == "$REPO"/* ]] && continue
            # A link inside a package pointing outside the repo is also ours;
            # without this, restow renames our own file aside.
            [ "$target" -ef "$pkg/$rel" ] && continue
            warn "Moving aside $rel -> $rel.pre-dotfiles"
            mv "$target" "$target.pre-dotfiles"
            moved=$((moved + 1))
        done < <(cd "$pkg" && find . -type f -o -type l)
    done
    [ "$moved" -gt 0 ] && log "Moved $moved pre-existing file(s) aside; originals kept as *.pre-dotfiles"

    # A missing target dir gets folded into one symlink to the repo, and every
    # app that later adds a launcher there would write into git.
    mkdir -p "$HOME/.local/share/applications" "$HOME/.config/dms" "$HOME/.config/systemd/user/xdg-desktop-portal-hyprland.service.d"
    for pkg in "${STOW_PACKAGES[@]}"; do
        [ -d "$pkg" ] || {
            warn "no such stow package: $pkg (skipping)"
            continue
        }
        stow --target="$HOME" --restow "$pkg"
    done

    # hyprland.lua loads these three unconditionally, so they must exist even
    # when empty. -e rather than -f below: a dangling link (profile deleted)
    # fails the load the same way a missing file does.
    local local_lua="$HOME/.config/hypr/conf/local.lua"
    if [ ! -f "$local_lua" ]; then
        printf '%s\n' \
            "-- Machine-local Hyprland config. Not tracked in the dotfiles repo." \
            "-- bootstrap.sh writes the NVIDIA env block here when it finds a card." \
            >"$local_lua"
    fi

    # DMS writes the theme's colours here on its first start.
    local colors="$HOME/.config/hypr/dms/colors.lua"
    [ -f "$colors" ] || printf '%s\n' "-- Written by DMS on every theme change." >"$colors"

    # DMS points qt6ct at its KDE-format DankMatugen.colors, which qt6ct can't
    # read. colors/matugen.conf is the qt6ct-format palette it writes too.
    local qt6ct="$HOME/.config/qt6ct/qt6ct.conf"
    mkdir -p "${qt6ct%/*}"
    [ -f "$qt6ct" ] && grep -q '^\[Appearance\]' "$qt6ct" || printf '[Appearance]\n' >>"$qt6ct"
    sed -i -e '/^custom_palette=/d' -e '/^color_scheme_path=/d' -e '/^style=/d' "$qt6ct"
    sed -i "/^\[Appearance\]/a custom_palette=true\ncolor_scheme_path=$HOME/.config/qt6ct/colors/matugen.conf\nstyle=Fusion" "$qt6ct"

    local profiles="$HOME/.config/monitor-profiles"
    if [ ! -e "$profiles/active.lua" ]; then
        mkdir -p "$profiles"
        printf '%s\n' \
            "-- No monitor profile matches the connected monitors — Hyprland defaults." \
            >"$profiles/hyprmon.lua"
        ln -sfn hyprmon.lua "$profiles/active.lua"
    fi
}
