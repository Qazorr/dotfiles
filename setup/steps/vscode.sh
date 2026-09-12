# shellcheck shell=bash
register_step vscode \
    --desc "VS Code from Microsoft's apt repo" \
    --group apps --root --needs prereqs \
    --provides code

step_vscode() {
    if command -v code >/dev/null 2>&1; then
        log "VS Code already installed, skipping"
        return 0
    fi
    # Not in any Debian release. Preferred over the flatpak, which makes
    # reaching toolchains outside the sandbox awkward.
    log "Adding Microsoft apt repo and installing VS Code"
    ensure_apt_key https://packages.microsoft.com/keys/microsoft.asc \
        /usr/share/keyrings/microsoft.gpg dearmor
    ensure_apt_list /etc/apt/sources.list.d/vscode.list \
        "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        "packages.microsoft.com/repos/code"
    apt_install code
}
