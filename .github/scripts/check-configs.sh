#!/usr/bin/env bash
# The tracked files that aren't shell.
set -euo pipefail
# shellcheck disable=SC2034  # read by check_finish in lib.sh
CHECK_NAME="configs"
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$CHECK_REPO"

check_head "JSON"
mapfile -t jsonf < <(git ls-files '*.json')
if have jq; then
    bad=0
    for f in "${jsonf[@]}"; do
        err="$(jq empty "$f" 2>&1)" || { check_fail "$f" "invalid JSON: $err"; bad=1; }
    done
    [ "$bad" = "0" ] && check_ok "${#jsonf[@]} files parse"
else
    check_skip "jq not installed — ${#jsonf[@]} .json files unchecked"
fi

# String-aware: config.jsonc's $schema URL contains //.
_strip_jsonc() {
    python3 - "$1" <<'PY'
import sys
src = open(sys.argv[1], encoding='utf-8').read()
out, i, n = [], 0, len(src)
while i < n:
    if src[i] == '"':
        j = i + 1
        while j < n and src[j] != '"':
            j += 2 if src[j] == '\\' else 1
        out.append(src[i:j + 1]); i = j + 1
    elif src.startswith('//', i):
        j = src.find('\n', i); i = n if j < 0 else j
    elif src.startswith('/*', i):
        j = src.find('*/', i + 2); i = n if j < 0 else j + 2
    else:
        out.append(src[i]); i += 1
sys.stdout.write(''.join(out))
PY
}

check_head "JSONC"
mapfile -t jsoncf < <(git ls-files '*.jsonc')
if have jq && have python3; then
    bad=0
    for f in "${jsoncf[@]}"; do
        err="$(_strip_jsonc "$f" | jq empty 2>&1)" || { check_fail "$f" "invalid JSONC: $err"; bad=1; }
    done
    [ "$bad" = "0" ] && check_ok "${#jsoncf[@]} files parse once comments are stripped"
else
    check_skip "jq or python3 not installed — ${#jsoncf[@]} .jsonc files unchecked"
fi

check_head "Desktop entries"
mapfile -t deskf < <(git ls-files '*.desktop')
if have desktop-file-validate; then
    bad=0
    for f in "${deskf[@]}"; do
        # Hints print on clean files too; only the exit code counts.
        out="$(desktop-file-validate "$f" 2>&1)" || { check_fail "$f" "$out"; bad=1; }
    done
    [ "$bad" = "0" ] && check_ok "${#deskf[@]} entries validate"
else
    check_skip "desktop-file-validate not installed (desktop-file-utils) — ${#deskf[@]} entries unchecked"
fi

check_head "Python"
mapfile -t pyf < <({ git ls-files '*.py'; grep -lE '^#!.*python' scripts/.local/bin/* 2>/dev/null; } | sort -u)
if have python3; then
    bad=0
    for f in "${pyf[@]}"; do
        # Not py_compile: its __pycache__ lands in a stow package, and a .pyc
        # got committed that way once.
        err="$(python3 -c '
import sys
p = sys.argv[1]
try:
    compile(open(p, encoding="utf-8").read(), p, "exec")
except SyntaxError as e:
    print(f"{e.lineno or 0}:{e.msg}")
    sys.exit(1)
' "$f" 2>&1)" || { check_fail "$f:${err%%:*}" "syntax error: ${err#*:}"; bad=1; }
    done
    [ "$bad" = "0" ] && check_ok "${#pyf[@]} files compile"
else
    check_skip "python3 not installed — ${#pyf[@]} files unchecked"
fi

check_head "ruff"
if have ruff && [ ${#pyf[@]} -gt 0 ]; then
    # --no-cache keeps .ruff_cache out of the repo.
    out="$(ruff check --isolated --no-cache --select E9,F --output-format=concise "${pyf[@]}" 2>&1 || true)"
    if printf '%s' "$out" | grep -qE '^[^ ].*:[0-9]+:[0-9]+: '; then
        while IFS= read -r line; do
            [[ "$line" =~ ^([^:]+):([0-9]+):[0-9]+:[[:space:]](.*)$ ]] || continue
            check_fail "${BASH_REMATCH[1]}:${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        done <<<"$out"
    else
        check_ok "no findings in ${#pyf[@]} files"
    fi
else
    check_skip "ruff not installed"
fi

# These files can't source lib/paths.sh; drift shows up later as "binary could
# not be found" from a keybind.
check_head "PATH consistency (lib/paths.sh is the reference)"
# shellcheck source=../../lib/paths.sh
source "$CHECK_REPO/lib/paths.sh"
for f in zsh/.zprofile zsh/.zshrc hypr/.config/hypr/conf.d/environment.conf; do
    missing=""
    for dir in "${DOTFILES_PATH_DIRS[@]}"; do
        grep -q "\$HOME/${dir#"$HOME"/}" "$f" || missing+="${dir#"$HOME"/} "
    done
    if [ -n "$missing" ]; then
        check_fail "$f" "missing from its PATH: ${missing% }"
    else
        check_ok "$f"
    fi
done

# One-directional: custom.js is 755 with no shebang.
check_head "Executable bits"
bad=0 n=0
while IFS=$'\t' read -r meta path; do
    [ -n "$path" ] || continue
    [ "$(head -c 2 "$path" 2>/dev/null)" = '#!' ] || continue
    n=$((n + 1))
    [ "${meta%% *}" = "100755" ] \
        || { check_fail "$path:1" "has a shebang but is committed mode ${meta%% *} — git update-index --chmod=+x '$path'"; bad=1; }
done < <(git ls-files -s)
[ "$bad" = "0" ] && check_ok "$n files with a shebang are +x"

# Stowed dirs are symlinks into the repo, so tool output there lands in git.
check_head "Generated files"
bad=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    check_fail "$f" "tracked but generated — git rm --cached it, and gitignore it"
    bad=1
done < <(git ls-files | grep -E '(^|/)(__pycache__|\.ruff_cache)/|\.py[co]$' || true)
while IFS= read -r f; do
    [ -n "$f" ] || continue
    check_fail "$f" "tracked but matched by a .gitignore rule — git rm --cached it, or narrow the rule"
    bad=1
done < <(git ls-files -ci --exclude-standard || true)
[ "$bad" = "0" ] && check_ok "nothing generated is tracked"

check_head "Markdown links"
bad=0 n=0
while IFS= read -r f; do
    dir="$(dirname "$f")"
    while IFS=: read -r lineno target; do
        case "$target" in http://*|https://*|mailto:*|'#'*) continue ;; esac
        target="${target%%#*}"
        [ -n "$target" ] || continue
        n=$((n + 1))
        [ -e "$dir/$target" ] \
            || { check_fail "$f:$lineno" "links to '$target', which doesn't exist"; bad=1; }
    done < <(grep -noE '\]\([^)]+\)' "$f" | sed 's/^\([0-9]*\):](\(.*\))$/\1:\2/')
done < <(git ls-files '*.md')
[ "$bad" = "0" ] && check_ok "$n relative link(s) resolve"

check_finish
