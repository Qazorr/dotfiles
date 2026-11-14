PYTHON_VERSION=3.13

register_step python \
    --desc "Python $PYTHON_VERSION, uv and ruff via mise" \
    --group dev --root --needs web \
    --provides "$HOME/.local/share/mise/shims/python" \
               "$HOME/.local/share/mise/shims/uv" \
               "$HOME/.local/share/mise/shims/ruff"

step_python() {
    log "Installing Python $PYTHON_VERSION, uv, ruff"
    mise use --global python@$PYTHON_VERSION uv@latest ruff@latest
    mise reshim
}
