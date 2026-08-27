# Download helpers for upstream release artifacts, sourced by setup/steps/.
# Not a stow package, not standalone-executable.

# Download a GitHub release tarball containing a single binary, and install
# it. Only fits the "one binary at the root of the tarball" shape — DMS's
# own tarball (a binary plus a whole QML tree) and Quick Capture/hyprmon
# (git-clone-and-build) are different enough to stay hand-written in their
# own step rather than forced through this.
#
#   install_github_release_binary <owner/repo> <tag> <asset-filename> \
#       <binary-name-inside-tarball> <install-path> <scratch-dir>
install_github_release_binary() {
    local repo="$1" tag="$2" asset="$3" bin_in_tarball="$4" dest="$5" tmp="$6"
    curl -fsSL -o "$tmp/$asset" \
        "https://github.com/$repo/releases/download/$tag/$asset"
    tar xzf "$tmp/$asset" -C "$tmp"
    install -m755 "$tmp/$bin_in_tarball" "$dest"
}
