register_step rust \
    --desc "rustup toolchain and cargo tools: spotify_player" \
    --group dev --root --needs prereqs \
    --provides rustup cargo spotify_player

step_rust() {
    if ! command -v rustup >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
        log "Installing rustup"
        curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path
    fi
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
}
