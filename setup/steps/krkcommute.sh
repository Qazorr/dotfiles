# Part of bootstrap.sh — sourced by it, not meant to run standalone.
#
# krk-commute: a personal, actively-developed project (private repo, no
# version tags), not a stable third-party release — so this step re-clones/
# pulls to stay current, rather than pinning + skipping like the other
# upstream installs in this file.
step_krkcommute() { # krk-commute: transit-departure bar widget (private repo)
    # ~/Projects is just this machine's convention, not something krk-commute
    # itself requires — override if you keep projects somewhere else.
    local dir="${DOTFILES_KRKCOMMUTE_DIR:-$HOME/Projects/krk-commute}"

    if [ -d "$dir/.git" ]; then
        log "Updating krk-commute"
        git -C "$dir" pull --ff-only || warn "krk-commute: git pull failed, using what's already there"
    else
        log "Cloning krk-commute"
        mkdir -p "$(dirname "$dir")"
        # Private repo. Not fatal to the rest of bootstrap.sh if this fails
        # (wrong machine, no gh/SSH auth set up yet) — everything else here
        # should still install.
        if command -v gh >/dev/null 2>&1; then
            gh repo clone Qazorr/krk-commute "$dir" || { warn "couldn't clone krk-commute (private repo — need gh or SSH auth), skipping"; return 0; }
        else
            git clone git@github.com:Qazorr/krk-commute.git "$dir" \
                || { warn "couldn't clone krk-commute (private repo — need gh or SSH auth), skipping"; return 0; }
        fi
    fi

    command -v uv >/dev/null 2>&1 || { warn "uv not on PATH — run the uv step first, skipping krk-commute"; return 0; }

    log "Installing krk-commute's Python dependencies"
    ( cd "$dir" && uv sync --locked --no-dev )

    # Not ~/.local/bin: stow symlink into this repo, same reasoning as every
    # other non-apt tool here.
    local bin_dir="$HOME/.local/share/krk-commute/bin"
    mkdir -p "$bin_dir"
    ln -sf "$dir/.venv/bin/krk-commute" "$bin_dir/krk-commute"

    log "Installing the krk-commute user service"
    # The shipped unit hardcodes ExecStart=%h/.local/bin/krk-commute — wrong
    # here for the same reason. Substitute the real path when installing it,
    # rather than symlinking the unit file itself.
    mkdir -p "$HOME/.config/systemd/user"
    sed "s|%h/.local/bin/krk-commute|$bin_dir/krk-commute|" \
        "$dir/systemd/krk-commute.service" > "$HOME/.config/systemd/user/krk-commute.service"
    systemctl --user daemon-reload
    systemctl --user enable --now krk-commute.service

    # DMS widget: a port of the repo's own Omarchy-flavoured plugin/, living
    # at plugin-dms/ in the same repo (co-located with the daemon it talks
    # to, not vendored into these dotfiles). Symlinked, not copied, so it
    # tracks the repo without a separate install step of its own.
    mkdir -p "$HOME/.config/DankMaterialShell/plugins"
    ln -sfn "$dir/plugin-dms" "$HOME/.config/DankMaterialShell/plugins/krkCommute"
    if pgrep -x qs >/dev/null 2>&1 && command -v dms >/dev/null 2>&1; then
        dms ipc call plugin-scan scan >/dev/null 2>&1 || true
        dms ipc call plugins enable krkCommute >/dev/null 2>&1 || true
    fi

    if [ ! -f "$HOME/.config/krk-commute/config.toml" ]; then
        warn "krk-commute has no saved routes yet — run 'krk-commute configure' to add some (the widget shows a warning icon until then, which is correct, not broken)."
    fi
}
