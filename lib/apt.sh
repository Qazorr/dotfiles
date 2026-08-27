# apt helpers, sourced by bootstrap.sh (which defines APT_OPTS) and the step
# files under setup/steps/. Not a stow package, not standalone-executable.

apt_install() { sudo apt install "${APT_OPTS[@]}" "$@"; }
apt_install_backports() { sudo apt install "${APT_OPTS[@]}" -t trixie-backports "$@"; }

# Fetch a signing key to $2 if it isn't there yet. Pass "dearmor" as $3 for
# vendors that serve an ASCII-armored PGP key needing conversion to a binary
# keyring (e.g. Microsoft's); omit it for vendors whose key is already in a
# form apt's signed-by= accepts directly (e.g. Anthropic's .asc — verified
# working as-is, no dearmor, on this machine).
ensure_apt_key() {
    local url="$1" path="$2" mode="${3:-}"
    [ -f "$path" ] && return 0
    if [ "$mode" = "dearmor" ]; then
        curl -fsSL "$url" | gpg --dearmor | sudo tee "$path" >/dev/null
    else
        curl -fsSL "$url" | sudo tee "$path" >/dev/null
    fi
}

# Idempotently write a one-line "deb [...] URL suite component" apt source
# and refresh apt. $1 = target .list path, $2 = the full deb line, $3 = a
# substring already unique to this source, used to detect one already
# present (from a previous run, or set up by hand before this repo existed)
# without needing to know it was written by this exact mechanism.
ensure_apt_list() {
    local list_path="$1" deb_line="$2" needle="$3"
    grep -Rqs "$needle" /etc/apt/sources.list.d/ 2>/dev/null && return 0
    echo "$deb_line" | sudo tee "$list_path" >/dev/null
    sudo apt update
}
