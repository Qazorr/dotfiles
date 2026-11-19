#!/usr/bin/env bash
# What CI and the pre-commit hook run. A check whose tool is missing is skipped.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

fail=0
ok() { printf '  \033[1;32mok\033[0m    %s\n' "$*"; }
bad() {
    printf '  \033[1;31mbad\033[0m   %s\n' "$*"
    fail=1
}
skip() { printf '  \033[1;33mskip\033[0m  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

mapfile -t scripts < <(git ls-files home/scripts/.local/bin)
mapfile -t shell < <(
    git ls-files '*.sh'
    grep -lE '^#!.*sh' "${scripts[@]}"
)

if have shellcheck; then
    if shellcheck --severity=warning --external-sources "${shell[@]}"; then
        ok "shellcheck (${#shell[@]} files)"
    else
        bad "shellcheck"
    fi
else
    skip "shellcheck not installed"
fi

if have shfmt; then
    # Style comes from .editorconfig.
    if shfmt -d "${shell[@]}"; then
        ok "shfmt (${#shell[@]} files)"
    else
        bad "shfmt — run: shfmt -w \$(git ls-files '*.sh') home/scripts/.local/bin/*"
    fi
else
    skip "shfmt not installed"
fi

for f in "${shell[@]}"; do
    bash -n "$f" || bad "bash -n $f"
done

if have zsh; then
    while read -r f; do
        zsh -n "$f" || bad "zsh -n $f"
    done < <(git ls-files home/zsh)
    ok "zsh -n"
else
    skip "zsh not installed"
fi

if have jq; then
    while read -r f; do
        jq empty "$f" 2>/dev/null || bad "$f is not valid JSON"
    done < <(git ls-files '*.json')
    ok "JSON"
else
    skip "jq not installed"
fi

# A script committed without +x works here and fails on a fresh clone.
while read -r mode _ _ path; do
    [ -f "$path" ] && [ "$(head -c 2 "$path")" = '#!' ] && [ "$mode" != 100755 ] \
        && bad "$path has a shebang but isn't executable — git update-index --chmod=+x $path"
done < <(git ls-files -s)

# --list sources every step and runs steps_validate.
if DOTFILES_STATE_DIR="$(mktemp -d)" ./bootstrap.sh --list >/dev/null; then
    ok "step registry"
else
    bad "./bootstrap.sh --list"
fi

# Two packages claiming one path only shows up when they are stowed together.
if have stow; then
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/.config" "$tmp/.local/share"
    # shellcheck disable=SC2046  # one argument per package
    if stow --simulate --dir=home --target="$tmp" $(ls home) 2>/dev/null; then
        ok "stow packages don't collide"
    else
        bad "stow reports a conflict between packages in home/"
    fi
    rm -rf "$tmp"
else
    skip "stow not installed"
fi

exit "$fail"
