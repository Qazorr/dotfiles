# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_claudedesktop() { # Claude Desktop, from Anthropic's own apt repo
    local key=/usr/share/keyrings/claude-desktop-archive-keyring.asc
    log "Ensuring Anthropic's apt repo is set up"
    ensure_apt_key https://downloads.claude.ai/claude-desktop/key.asc "$key"
    ensure_apt_list /etc/apt/sources.list.d/claude-desktop.list \
        "deb [arch=amd64,arm64 signed-by=$key] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
        "downloads.claude.ai/claude-desktop"
    log "Installing Claude Desktop"
    apt_install claude-desktop
}
