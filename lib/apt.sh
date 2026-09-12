# shellcheck shell=bash
# apt helpers. bootstrap.sh defines APT_OPTS.

apt_install() { sudo apt install "${APT_OPTS[@]}" "$@"; }
apt_install_backports() { sudo apt install "${APT_OPTS[@]}" -t trixie-backports "$@"; }

# Purge + autoremove, tolerating packages that were never installed (e.g.
# switching NVIDIA driver variants only ever has one of them present).
apt_purge() {
    sudo apt purge "${APT_OPTS[@]}" "$@" || true
    sudo apt autoremove -y || true
}

# Fetch a signing key to $2 if missing. $3 = "dearmor" for vendors serving
# ASCII-armored keys (Microsoft); omit for keys signed-by= takes as-is.
ensure_apt_key() {
    local url="$1" path="$2" mode="${3:-}"
    [ -f "$path" ] && return 0
    if [ "$mode" = "dearmor" ]; then
        curl -fsSL "$url" | gpg --dearmor | sudo tee "$path" >/dev/null
    else
        curl -fsSL "$url" | sudo tee "$path" >/dev/null
    fi
}

# Write a one-line apt source and refresh, unless $3 (a substring unique to
# it) already appears in sources.list.d — matching content, not our filename,
# so a repo added by hand is found too.
ensure_apt_list() {
    local list_path="$1" deb_line="$2" needle="$3"
    grep -Rqs "$needle" /etc/apt/sources.list.d/ 2>/dev/null && return 0
    echo "$deb_line" | sudo tee "$list_path" >/dev/null
    sudo apt update
}
