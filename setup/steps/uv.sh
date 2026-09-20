# shellcheck shell=bash
register_step uv \
    --desc "uv, for krk-commute's Python venv/dependency management" \
    --group dev --needs prereqs \
    --provides "$HOME/.local/share/uv/bin/uv"

step_uv() {
    local dir="$HOME/.local/share/uv/bin"
    if [ -x "$dir/uv" ]; then
        log "uv already installed, skipping"
        return 0
    fi
    log "Installing uv"
    mkdir -p "$dir"
    UV_INSTALL_DIR="$dir" sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"
}
