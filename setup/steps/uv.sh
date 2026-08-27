# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_uv() { # uv, for krk-commute's Python venv/dependency management
    local dir="$HOME/.local/share/uv/bin"
    if [ -x "$dir/uv" ]; then
        log "uv already installed, skipping"
        return 0
    fi
    log "Installing uv"
    # UV_INSTALL_DIR, not the installer's own default of ~/.local/bin — that
    # path is a stow symlink into this repo, and the default would silently
    # write uv/uvx straight into git (exactly what happened once already,
    # before this step existed: found untracked in scripts/.local/bin while
    # installing krk-commute).
    mkdir -p "$dir"
    UV_INSTALL_DIR="$dir" sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"
}
