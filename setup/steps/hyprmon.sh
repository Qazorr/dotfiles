HYPRMON_VERSION=v0.0.17

register_step hyprmon \
    --desc "hyprmon: monitor layout/profile manager (build from source)" \
    --group desktop --root --needs prereqs backports \
    --provides hyprmon

step_hyprmon() {
    if command -v hyprmon >/dev/null 2>&1 \
        && hyprmon --version 2>/dev/null | grep -q "$HYPRMON_VERSION"; then
        log "hyprmon $HYPRMON_VERSION already installed, skipping"
        return 0
    fi

    require_disk_space 2
    log "Installing golang-go (build dependency for hyprmon)"
    # go.mod needs go 1.26; trixie main has 1.24. Go would auto-fetch it
    # mid-build, at the cost of a second ~100MB download.
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
    # /usr/local/bin, matching hyprmon's own documented install method.
    sudo install -m755 "$src/hyprmon" /usr/local/bin/hyprmon
}
