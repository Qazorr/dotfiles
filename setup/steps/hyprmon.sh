# Part of bootstrap.sh — sourced by it, not meant to run standalone.
HYPRMON_VERSION=v0.0.17

step_hyprmon() { # hyprmon: monitor layout/profile manager (build from source)
    if command -v hyprmon >/dev/null 2>&1 \
        && hyprmon --version 2>/dev/null | grep -q "$HYPRMON_VERSION"; then
        log "hyprmon $HYPRMON_VERSION already installed, skipping"
        return 0
    fi

    require_disk_space 2
    log "Installing golang-go (build dependency for hyprmon)"
    # From backports specifically: go.mod requires go 1.26, which trixie
    # main's golang-go (1.24) doesn't have. Go's own toolchain auto-upgrade
    # would fetch 1.26 anyway on a version mismatch, but that means a second,
    # separate ~100MB+ download mid-build — pulling the matching version from
    # apt up front avoids that.
    apt_install_backports golang-go

    local src="$HOME/.cache/dotfiles-build/hyprmon-src"
    log "Cloning and building hyprmon $HYPRMON_VERSION"
    rm -rf "$src"
    git clone --depth=1 --branch "$HYPRMON_VERSION" \
        https://github.com/erans/hyprmon "$src"

    local commit; commit="$(git -C "$src" rev-parse --short HEAD)"
    ( cd "$src" && go build \
        -ldflags="-s -w -X main.Version=$HYPRMON_VERSION -X main.GitCommit=$commit" \
        -o hyprmon . )
    # /usr/local/bin, matching hyprmon's own documented install method —
    # a normal system location, not a stow-managed path.
    sudo install -m755 "$src/hyprmon" /usr/local/bin/hyprmon
}
