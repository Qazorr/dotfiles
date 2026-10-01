#!/usr/bin/env bash
# Runs step_stow into a throwaway $HOME, from a copy of the tracked tree: once a
# package is folded into a symlink, step_stow's mv would rename files inside
# the checkout.
set -euo pipefail
# shellcheck disable=SC2034  # read by check_finish in lib.sh
CHECK_NAME="stow"
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! have stow; then
    check_head "Stow"
    check_skip "stow not installed"
    check_finish
fi

FAKE_HOME="$(mktemp -d)"
WORK="$(mktemp -d)"
MINI="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME" "$WORK" "$MINI"' EXIT

git -C "$CHECK_REPO" ls-files -z \
    | tar -C "$CHECK_REPO" --null -T - -cf - \
    | tar -C "$WORK" -xf -
REPO="$WORK"

# Before sourcing: lib/paths.sh reads $HOME at source time.
export HOME="$FAKE_HOME"
# An empty home would fold every package into one symlink.
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"

# shellcheck source=../../lib/common.sh
source "$REPO/lib/common.sh"
# shellcheck source=../../lib/paths.sh
source "$REPO/lib/paths.sh"
# shellcheck source=../../lib/steps.sh
source "$REPO/lib/steps.sh"
stow_files=("$REPO"/setup/steps/*-stow.sh)
stow_file="${stow_files[0]#"$REPO"/}"
# shellcheck source=/dev/null
source "$REPO/$stow_file"

check_head "step_stow"
for run in 1 2; do
    # As run_steps calls it: set -e on, and not in a conditional context.
    set +e
    out="$(set -e; step_stow 2>&1)"
    rc=$?
    set -e
    if [ "$rc" = "0" ]; then
        check_ok "run $run"
    else
        check_fail "$stow_file" "run $run exited $rc: $out"
    fi
    if [ "$run" = "2" ]; then
        moved="$(printf '%s\n' "$out" | grep -c 'Moving aside' || true)"
        [ "$moved" -gt 0 ] \
            && check_fail "$stow_file" "the second run moved $moved already-stowed file(s) aside"
    fi
done

mapfile -t aside < <(find "$HOME" -name '*.pre-dotfiles')
if [ ${#aside[@]} -eq 0 ]; then
    check_ok "no *.pre-dotfiles left behind"
else
    for f in "${aside[@]}"; do
        check_fail "$stow_file" "a restow moved an already-stowed file aside: ${f#"$HOME"/}"
    done
fi

# Covers step_stow's -ef guard; no tracked file is such a link yet.
check_head "Restow over a link that resolves outside the repo"
mkdir -p "$MINI/repo/pkg/.config/mini" "$MINI/outside" "$HOME/.config/mini"
echo real > "$MINI/outside/real.conf"
# Relative: stow refuses absolute symlinks.
ln -s ../../../../outside/real.conf "$MINI/repo/pkg/.config/mini/real.conf"
mini_out="$(
    REPO="$MINI/repo"
    STOW_PACKAGES=(pkg)
    step_stow >/dev/null 2>&1
    step_stow 2>&1
)" || true
mapfile -t mini_aside < <(find "$HOME/.config/mini" -name '*.pre-dotfiles')
if [ ${#mini_aside[@]} -eq 0 ] && ! printf '%s' "$mini_out" | grep -q 'Moving aside'; then
    check_ok "a package's own link out of the repo survives a restow"
else
    check_fail "$stow_file" "a restow moved a package's own symlink aside — the -ef check in the move-aside loop is what stops that"
fi

check_head "Stowed files"
for pkg in "${STOW_PACKAGES[@]}"; do
    bad=0 n=0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        n=$((n + 1))
        rel="${f#"$pkg"/}"
        target="$HOME/$rel"
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
            check_fail "$f" "stow left ~/$rel missing"
            bad=1; continue
        fi
        resolved="$(readlink -f "$target" 2>/dev/null || true)"
        # shellcheck disable=SC2088  # ~/ is printed for a human, not expanded
        [ "$resolved" = "$REPO/$f" ] \
            || { check_fail "$f" "~/$rel doesn't resolve back to this file — edits there wouldn't be tracked"; bad=1; }
    done < <(git -C "$CHECK_REPO" ls-files "$pkg")
    [ "$bad" = "0" ] && check_ok "$pkg ($n files)"
done

# shellcheck disable=SC2088  # ~/ is printed for a human, not expanded
if [ -L "$HOME/.local/share/applications" ]; then
    check_fail "$stow_file" "~/.local/share/applications came out a symlink into the repo — a .desktop file written there lands in git"
else
    check_ok "~/.local/share/applications is a real directory"
fi

# Hyprland won't start on a missing source =; step_stow creates two of them.
check_head "hyprland.conf sources"
conf="$HOME/.config/hypr/hyprland.conf"
rel_conf="hypr/.config/hypr/hyprland.conf"
if [ ! -e "$conf" ]; then
    check_fail "$rel_conf" "not stowed, so its sources can't be checked"
else
    bad=0 n=0
    while IFS= read -r line; do
        lineno="${line%%:*}"
        target="${line#*=}"
        target="${target#"${target%%[![:space:]]*}"}"
        target="${target%"${target##*[![:space:]]}"}"
        raw="$target"
        # shellcheck disable=SC2088  # matching the literal ~/ hyprland.conf holds
        case "$target" in
            "~/"*)     target="$HOME/${target#\~/}" ;;
            '$HOME/'*) target="$HOME/${target#\$HOME/}" ;;
        esac
        n=$((n + 1))
        [ -e "$target" ] \
            || { check_fail "$rel_conf:$lineno" "source = $raw doesn't exist after a stow — Hyprland won't start"; bad=1; }
    done < <(grep -nE '^[[:space:]]*source[[:space:]]*=' "$conf")
    [ "$bad" = "0" ] && check_ok "$n source = lines resolve"
fi

check_finish
