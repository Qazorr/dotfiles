# packages.list holds the apt packages added by hand since the install. Three
# sets decide what counts as "by hand": the baseline (everything marked manual
# when this machine was first seen), what the steps installed, and the list.
PACKAGES_LIST="$REPO/packages.list"
PACKAGES_BASELINE="$DOTFILES_STATE_DIR/packages.baseline"
PACKAGES_KNOWN="$DOTFILES_STATE_DIR/packages.known"

packages_listed() {
    [ -f "$PACKAGES_LIST" ] || return 0
    sed 's/#.*//' "$PACKAGES_LIST" | awk 'NF { print $1 }' | LC_ALL=C sort -u
}

packages_installed() { # packages_installed <name>
    [[ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" == ii* ]]
}

packages_baseline_init() {
    [ -f "$PACKAGES_BASELINE" ] && return 0
    mkdir -p "$DOTFILES_STATE_DIR"
    apt-mark showmanual | LC_ALL=C sort -u >"$PACKAGES_BASELINE"
}

# Marked manual, and in none of the three sets.
packages_new() {
    packages_baseline_init
    LC_ALL=C comm -23 \
        <(apt-mark showmanual | LC_ALL=C sort -u) \
        <({
            cat "$PACKAGES_BASELINE" "$PACKAGES_KNOWN" 2>/dev/null || true
            packages_listed
        } | LC_ALL=C sort -u)
}

# Listed, but not on this machine.
packages_missing() {
    local p
    while IFS= read -r p; do
        packages_installed "$p" || printf '%s\n' "$p"
    done < <(packages_listed)
}

packages_add() { # packages_add <name>...
    printf '%s\n' "$@" >>"$PACKAGES_LIST"
}
