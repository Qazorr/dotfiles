ensure_nala() {
    command -v nala >/dev/null 2>&1 && return 0
    log "Installing nala"
    sudo apt install "${APT_OPTS[@]}" nala
}
_nala() { ensure_nala; sudo nala "$@"; }

apt_update() { _nala update; }
# nala autoremoves on install by default; only apt_purge should remove.
apt_install() { _nala install "${APT_OPTS[@]}" --no-autoremove "$@"; }
apt_install_backports() { apt_install -t trixie-backports "$@"; }

# nala refuses an unauthenticated .deb URL under --yes, so verify a pinned hash
# and hand apt-get the local file.
apt_install_deb() {   # apt_install_deb <url> <sha256>
    local dir; scratch_dir dir
    local deb="$dir/${1##*/}"
    curl -fsSL -o "$deb" "$1" || return 1
    echo "$2  $deb" | sha256sum -c --quiet - || { warn "${1##*/}: checksum mismatch"; return 1; }
    chmod 755 "$dir"   # apt's _apt user has to read it
    sudo /usr/bin/apt-get install "${APT_OPTS[@]}" "$deb"
}

apt_purge() {
    _nala purge "${APT_OPTS[@]}" "$@" || true
    _nala autoremove -y || true
}

# $3 = "dearmor" for vendors serving ASCII-armored keys.
ensure_apt_key() {
    local url="$1" path="$2" mode="${3:-}"
    [ -f "$path" ] && return 0
    if [ "$mode" = "dearmor" ]; then
        curl -fsSL "$url" | gpg --dearmor | sudo tee "$path" >/dev/null
    else
        curl -fsSL "$url" | sudo tee "$path" >/dev/null
    fi
}

# Matches on the source line's content, not our filename, so a repo added by
# hand is found too — and a repo that moves host reaches machines that already
# had the old URL.
ensure_apt_list() {
    local list_path="$1" deb_line="$2" needle="$3"
    if [ -f "$list_path" ]; then
        [ "$(cat "$list_path")" = "$deb_line" ] && return 0
        log "apt source changed, rewriting $list_path"
    elif grep -Rqs "$needle" /etc/apt/sources.list.d/ 2>/dev/null; then
        return 0    # added by hand under another filename; leave it alone
    fi
    echo "$deb_line" | sudo tee "$list_path" >/dev/null
    apt_update
}
