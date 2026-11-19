log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
    exit 1
}

# render <template> KEY=value... — prints the template with each @KEY@ filled
# in; a placeholder left unfilled is an error.
render() {
    local out kv value args=()
    for kv in "${@:2}"; do
        value="${kv#*=}"
        value="${value//\\/\\\\}"
        value="${value//|/\\|}"
        value="${value//&/\\&}"
        args+=(-e "s|@${kv%%=*}@|$value|g")
    done
    out="$(sed "${args[@]}" "$1")" || return 1
    if grep -qE '@[A-Z_]+@' <<<"$out"; then
        die "render $1: unfilled $(grep -oE '@[A-Z_]+@' <<<"$out" | sort -u | tr '\n' ' ')"
    fi
    printf '%s\n' "$out"
}

# render_to <dest> <template> KEY=value... — renders as root; dest is only
# written once the whole template has rendered.
render_to() {
    local out
    out="$(render "${@:2}")" || return 1
    printf '%s\n' "$out" | sudo tee "$1" >/dev/null
}
