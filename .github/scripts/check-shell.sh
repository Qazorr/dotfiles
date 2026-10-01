#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC2034  # read by check_finish in lib.sh
CHECK_NAME="shell"
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$CHECK_REPO"

# shell_files and SHELLCHECK_ARGS come from --doctor, so the two agree on
# what clean means.
# shellcheck disable=SC2034  # read by shell_files
REPO="$CHECK_REPO"
# shellcheck source=../../lib/doctor.sh
source lib/doctor.sh
mapfile -t files < <(shell_files)

check_head "shellcheck (${#files[@]} files)"
if have shellcheck; then
    out="$(shellcheck "${SHELLCHECK_ARGS[@]}" --format=gcc "${files[@]}" 2>&1 || true)"
    if [ -z "$out" ]; then
        check_ok "no findings with ${SHELLCHECK_ARGS[*]}"
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
