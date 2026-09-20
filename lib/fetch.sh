# shellcheck shell=bash
install_github_release_binary() {
    local repo="$1" tag="$2" asset="$3" bin_in_tarball="$4" dest="$5" tmp="$6"
    curl -fsSL -o "$tmp/$asset" \
        "https://github.com/$repo/releases/download/$tag/$asset"
    tar xzf "$tmp/$asset" -C "$tmp"
    if [ -w "$(dirname "$dest")" ]; then
        install -m755 "$tmp/$bin_in_tarball" "$dest"
    else
        sudo install -m755 "$tmp/$bin_in_tarball" "$dest"
    fi
}

dms_enable_plugin() {
    pgrep -x qs >/dev/null 2>&1 && command -v dms >/dev/null 2>&1 || return 0
    dms ipc call plugin-scan scan >/dev/null 2>&1 || true
    dms ipc call plugins enable "$1" >/dev/null 2>&1 || true
}
