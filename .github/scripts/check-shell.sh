#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC2034  # read by check_finish in lib.sh
CHECK_NAME="shell"
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$CHECK_REPO"

# Must match --doctor's _doc_check_lint, so the two agree on "clean".
check_head "Parity with --doctor"
_frag_ok=1
for _frag in \
    "git ls-files '*.sh' bootstrap.sh" \
    "grep -lE '^#!.*sh' \"\$REPO\"/scripts/.local/bin/*" \
    "shellcheck --severity=warning --external-sources"
do
    grep -qF -- "$_frag" lib/doctor.sh || {
        check_fail "lib/doctor.sh" "_doc_check_lint no longer contains: $_frag — update .github/scripts/check-shell.sh to match"
        _frag_ok=0
    }
done
[ "$_frag_ok" = "1" ] && check_ok "_doc_check_lint's file set and flags are unchanged"

# scripts/.local/bin also holds Python.
files=()
mapfile -t files < <(git ls-files '*.sh' bootstrap.sh)
mapfile -t -O "${#files[@]}" files < <(grep -lE '^#!.*sh' scripts/.local/bin/* 2>/dev/null)

check_head "shellcheck (${#files[@]} files)"
if have shellcheck; then
    out="$(shellcheck --severity=warning --external-sources --format=gcc "${files[@]}" 2>&1 || true)"
    if [ -z "$out" ]; then
        check_ok "no findings at --severity=warning"
    else
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            if [[ "$line" =~ ^([^:]+):([0-9]+):([0-9]+):[[:space:]](.*)$ ]]; then
                check_fail "${BASH_REMATCH[1]}:${BASH_REMATCH[2]}" "${BASH_REMATCH[4]}"
            else
                check_fail "" "$line"
            fi
        done <<<"$out"
    fi
else
    check_skip "shellcheck not installed"
fi

check_head "bash -n"
bad=0
for f in "${files[@]}"; do
    err="$(bash -n "$f" 2>&1)" || { check_fail "$f" "bash -n: $err"; bad=1; }
done
[ "$bad" = "0" ] && check_ok "${#files[@]} files parse"

check_head "zsh -n"
mapfile -t zfiles < <(git ls-files zsh)
if have zsh; then
    bad=0
    for f in "${zfiles[@]}"; do
        err="$(zsh -n "$f" 2>&1)" || { check_fail "$f" "zsh -n: $err"; bad=1; }
    done
    [ "$bad" = "0" ] && check_ok "${#zfiles[@]} files parse"
else
    check_skip "zsh not installed — ${zfiles[*]} not syntax-checked"
fi

check_finish
