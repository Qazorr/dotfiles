# shellcheck shell=bash
# A private repo with no version tags, so this pulls rather than pinning.
register_step krkcommute \
    --desc "krk-commute: transit-departure bar widget (private repo)" \
    --group personal --needs prereqs cli uv \
    --provides "$HOME/.local/share/krk-commute/bin/krk-commute"

step_krkcommute() {
    local dir="${DOTFILES_KRKCOMMUTE_DIR:-$HOME/Projects/krk-commute}"

    if [ -d "$dir/.git" ]; then
        log "Updating krk-commute"
        git -C "$dir" pull --ff-only || warn "krk-commute: git pull failed, using what's already there"
    else
        log "Cloning krk-commute"
        mkdir -p "$(dirname "$dir")"
        if command -v gh >/dev/null 2>&1; then
            gh repo clone Qazorr/krk-commute "$dir"
        else
            git clone git@github.com:Qazorr/krk-commute.git "$dir"
        fi || { warn "couldn't clone krk-commute (private repo — need gh or SSH auth), skipping"; stamp_skip; return 0; }
    fi

    command -v uv >/dev/null 2>&1 || { warn "uv not on PATH — run the uv step first, skipping krk-commute"; stamp_skip; return 0; }

    log "Installing krk-commute's Python dependencies"
    ( cd "$dir" && uv sync --locked --no-dev )

    # Not ~/.local/bin: stow symlink into this repo.
    local bin_dir="$HOME/.local/share/krk-commute/bin"
    mkdir -p "$bin_dir"
    ln -sf "$dir/.venv/bin/krk-commute" "$bin_dir/krk-commute"

    log "Installing the krk-commute user service"
    # The shipped unit hardcodes %h/.local/bin/krk-commute — wrong for the
    # same reason, so substitute the path instead of symlinking the unit.
    mkdir -p "$HOME/.config/systemd/user"
    sed "s|%h/.local/bin/krk-commute|$bin_dir/krk-commute|" \
        "$dir/systemd/krk-commute.service" > "$HOME/.config/systemd/user/krk-commute.service"
    systemctl --user daemon-reload
    systemctl --user enable --now krk-commute.service

    # The widget lives in krk-commute's own repo next to its daemon;
    # symlinked so it tracks that repo.
    mkdir -p "$HOME/.config/DankMaterialShell/plugins"
    ln -sfn "$dir/plugin-dms" "$HOME/.config/DankMaterialShell/plugins/krkCommute"
    dms_enable_plugin krkCommute

    if [ ! -f "$HOME/.config/krk-commute/config.toml" ]; then
        warn "krk-commute has no saved routes yet — run 'krk-commute configure' to add some (the widget shows a warning icon until then, which is correct, not broken)."
    fi
}
