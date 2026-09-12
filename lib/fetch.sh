# shellcheck shell=bash
# Install a single binary from a GitHub release tarball. Only that shape —
# DMS's tarball (binary plus QML tree) and the build-from-source steps are
# hand-written.
#
#   install_github_release_binary <owner/repo> <tag> <asset-filename> \
#       <binary-name-inside-tarball> <install-path> <scratch-dir>
install_github_release_binary() {
    local repo="$1" tag="$2" asset="$3" bin_in_tarball="$4" dest="$5" tmp="$6"
    curl -fsSL -o "$tmp/$asset" \
        "https://github.com/$repo/releases/download/$tag/$asset"
    tar xzf "$tmp/$asset" -C "$tmp"
    # /usr/local/bin needs root; ~/.local/share/*/bin doesn't.
    if [ -w "$(dirname "$dest")" ]; then
        install -m755 "$tmp/$bin_in_tarball" "$dest"
    else
        sudo install -m755 "$tmp/$bin_in_tarball" "$dest"
    fi
}
