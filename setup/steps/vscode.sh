# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_vscode() { # VS Code from Microsoft's apt repo
    if command -v code >/dev/null 2>&1; then
        log "VS Code already installed, skipping"
        return 0
    fi
    # Not in any Debian release. Preferred over the flatpak because the
    # .zshrc `code` alias passes --ozone-platform=wayland, and a sandboxed
    # build makes reaching toolchains outside it awkward.
    log "Adding Microsoft apt repo and installing VS Code"
    ensure_apt_key https://packages.microsoft.com/keys/microsoft.asc \
        /usr/share/keyrings/microsoft.gpg dearmor
    ensure_apt_list /etc/apt/sources.list.d/vscode.list \
        "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        "packages.microsoft.com/repos/code"
    apt_install code
}
