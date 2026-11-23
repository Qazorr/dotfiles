#!/usr/bin/env bash
# Looks for credentials in files. Used by .github/scripts/check.sh (CI and the
# pre-commit hook) and `dotfiles sync`.
#
#   scan-secrets --staged    the staged version of every staged file
#   scan-secrets --tracked   every file git tracks
#   scan-secrets <file>...   these files
#
# Exits 1 and prints file:line (value redacted) on a hit. A line containing
# "secret-scan: allow" is skipped; use it only for a documented fake value.
set -euo pipefail

PATTERNS=(
    'gl(pat|dt|rt|ptt|soat|oas|cbt|imt|ft|agent)-[A-Za-z0-9_-]{15,}' # GitLab tokens
    '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'
    'sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{40,}'
    'AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}'
    '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
    '[a-z][a-z0-9+.-]*://[^/[:space:]:@$]+:[^/[:space:]@$<{]{6,}@' # user:password@host
)
# key = value: a value of 16+ characters that contains a digit (QML like
# `showPassword: passwordBox.showPassword` has none).
KEY='(token|secret|passw(or)?d|api[_-]?key|client[_-]?secret)["'\'']?[[:space:]]*[:=][[:space:]]*["'\'']?'
GENERIC_LONG="${KEY}[A-Za-z0-9+_.=-][A-Za-z0-9/+_.=-]{15,}"
GENERIC_DIGIT="${KEY}[A-Za-z0-9+_.=-][A-Za-z0-9/+_.=-]*[0-9]"
PATTERN=$(
    IFS='|'
    printf '%s' "${PATTERNS[*]}"
)
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
SELF=.github/scripts/scan-secrets.sh

hits=0
scan() { # label (content on stdin)
    local out
    cat >"$TMP"
    out=$(
        {
            grep -nIiE -- "$PATTERN" "$TMP"
            grep -nIiE -- "$GENERIC_LONG" "$TMP" | grep -iE -- "$GENERIC_DIGIT"
        } | sort -t: -k1,1n -u | grep -v 'secret-scan: allow' || true
    )
    [[ -n $out ]] || return 0
    hits=1
    while IFS= read -r line; do
        printf '  %s:%s:<redacted>\n' "$1" "${line%%:*}" >&2
    done <<<"$out"
}

mode=${1:-}
case $mode in
--staged)
    while IFS= read -r -d '' f; do
        [[ $f == "$SELF" ]] && continue
        git show ":$f" 2>/dev/null | scan "$f"
    done < <(git diff --cached --name-only --diff-filter=ACMR -z)
    ;;
--tracked)
    while IFS= read -r -d '' f; do
        [[ $f == "$SELF" || ! -f $f ]] && continue
        scan "$f" <"$f"
    done < <(git ls-files -z)
    ;;
"" | -h | --help)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    [[ -n $mode ]]
    exit
    ;;
*)
    for f in "$@"; do scan "$f" <"$f"; done
    ;;
esac

if [[ $hits -ne 0 ]]; then
    echo "scan-secrets: the lines above look like credentials. This repo is public: keep them in an untracked" >&2
    echo "file (~/.zshrc.local) or env vars. A documented fake value can carry a 'secret-scan: allow' comment." >&2
fi
exit "$hits"
