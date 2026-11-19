register_step rust \
    --desc "Rust toolchain via rustup" \
    --group dev --needs prereqs \
    --provides "$HOME/.cargo/bin/rustup" "$HOME/.cargo/bin/cargo"

step_rust() {
    if [ -x "$HOME/.cargo/bin/rustup" ]; then
        log "rustup already installed, skipping"
        return 0
    fi
    log "Installing rustup"
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path
}
