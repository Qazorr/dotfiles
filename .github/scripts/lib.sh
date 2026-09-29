# shellcheck disable=SC2034  # read by every check-*.sh
CHECK_REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CHECK_NAME="${CHECK_NAME:-check}"
CHECK_FAILURES=0

# Newlines must be escaped or the annotation stops at the first one.
_check_annotate() {
    [ -n "${GITHUB_ACTIONS:-}" ] || return 0
    local loc="$1" msg="$2" file="" line=""
    file="${loc%%:*}"
    [[ "$loc" == *:* ]] && line="${loc#*:}"
    msg="${msg//'%'/%25}"
    msg="${msg//$'\r'/%0D}"
    msg="${msg//$'\n'/%0A}"
    if [ -n "$file" ]; then
        printf '::error file=%s%s::%s\n' "$file" "${line:+,line=$line}" "$msg"
    else
        printf '::error::%s\n' "$msg"
    fi
    return 0
}

# check_fail <file[:line] | ""> <message...>
check_fail() {
    local loc="$1"; shift
    printf '  \033[1;31mbad\033[0m   %s%s\n' "${loc:+$loc: }" "$*"
    _check_annotate "$loc" "$*"
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
    return 0
}

check_ok()   { printf '  \033[1;32mok\033[0m    %s\n' "$*"; }
check_skip() { printf '  \033[1;33mskip\033[0m  %s\n' "$*"; }
check_head() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# A missing tool skips; ci.yml asserts each one is present.
have() { command -v "$1" >/dev/null 2>&1; }

check_finish() {
    printf '\n'
    if [ "$CHECK_FAILURES" -gt 0 ]; then
        printf '\033[1;31mxx\033[0m %s: %d finding(s)\n' "$CHECK_NAME" "$CHECK_FAILURES"
        exit 1
    fi
    printf '\033[1;32m==>\033[0m %s: clean\n' "$CHECK_NAME"
    exit 0
}
