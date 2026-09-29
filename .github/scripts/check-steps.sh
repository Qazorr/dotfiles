#!/usr/bin/env bash
# The step registry: everything steps_validate() doesn't already refuse.
set -euo pipefail
# shellcheck disable=SC2034  # read by check_finish in lib.sh
CHECK_NAME="step registry"
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Keep --list and logging out of this machine's ~/.local/state.
DOTFILES_STATE_DIR="$(mktemp -d)"
export DOTFILES_STATE_DIR
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$DOTFILES_STATE_DIR" "$SCRATCH"' EXIT

# --list/--help exit before check_environment, so they run anywhere and still
# prove every file sources and steps_validate passes.
check_head "bootstrap.sh smoke test"
list_out=""
for flag in --list --help; do
    rc=0
    out="$("$CHECK_REPO/bootstrap.sh" "$flag" 2>&1)" || rc=$?
    if [ "$rc" = "0" ]; then
        check_ok "./bootstrap.sh $flag"
        [ "$flag" = "--list" ] && list_out="$out"
    else
        check_fail "bootstrap.sh" "./bootstrap.sh $flag exited $rc: $out"
    fi
done

# A copy without the final `main "$@"` gives STEPS and the STEP_* maps without
# installing anything. It finds lib/ and setup/ via its own dirname.
grep -qxF 'main "$@"' "$CHECK_REPO/bootstrap.sh" \
    || { check_fail "bootstrap.sh" 'no final `main "$@"` line to strip — refusing to source it, it would run the installer'; check_finish; }
grep -vxF 'main "$@"' "$CHECK_REPO/bootstrap.sh" > "$SCRATCH/bootstrap.sh"
ln -s "$CHECK_REPO/lib" "$SCRATCH/lib"
ln -s "$CHECK_REPO/setup" "$SCRATCH/setup"
# shellcheck source=/dev/null
source "$SCRATCH/bootstrap.sh"
# Its `trap cleanup EXIT` replaced ours.
rm -rf "$SCRATCH"
# shellcheck disable=SC2034
REPO="$CHECK_REPO"

declare -A STEP_AT=()
for _i in "${!STEPS[@]}"; do STEP_AT[${STEPS[$_i]}]=$_i; done

_in_list() {   # _in_list <needle> <haystack...>
    local n="$1"; shift
    [[ " $* " == *" $n "* ]]
}

_line_of() {   # _line_of <file> <grep -E pattern>
    local n
    n="$(grep -nE -m1 -- "$2" "$CHECK_REPO/$1" 2>/dev/null | cut -d: -f1)"
    printf '%s' "${1}${n:+:$n}"
}

# An unknown --group isn't an error anywhere; the step silently drops out of
# --list and every profile.
check_head "Groups"
bad=0
for s in "${STEPS[@]}"; do
    _in_list "${STEP_GROUP[$s]}" "${GROUP_ORDER[@]}" \
        || { check_fail "$(_line_of "setup/steps/$s.sh" '\-\-group')" "--group ${STEP_GROUP[$s]} isn't in bootstrap.sh's GROUP_ORDER — $s vanishes from --list and from every profile"; bad=1; }
done
[ "$bad" = "0" ] && check_ok "every step's group is in GROUP_ORDER"

listed="$(printf '%s\n' "$list_out" | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^  [^ ]* /    /' | awk '/^    /{print $1}')"
bad=0
for s in "${STEPS[@]}"; do
    _in_list "$s" $listed || { check_fail "bootstrap.sh" "$s is in STEPS but --list never prints it"; bad=1; }
done
[ "$bad" = "0" ] && check_ok "--list prints all ${#STEPS[@]} steps"

# A typo'd group in PROFILES quietly selects nothing.
check_head "Profiles"
bad=0
for p in "${!PROFILES[@]}"; do
    n=0
    for g in ${PROFILES[$p]}; do
        if ! _in_list "$g" "${GROUP_ORDER[@]}"; then
            check_fail "bootstrap.sh" "PROFILES[$p] names group '$g', which isn't in GROUP_ORDER — --profile $p selects nothing for it"
            bad=1; continue
        fi
        for s in "${STEPS[@]}"; do
            [ "${STEP_GROUP[$s]}" = "$g" ] && n=$((n + 1))
        done
    done
    [ "$n" -gt 0 ] || { check_fail "bootstrap.sh" "--profile $p selects no steps at all"; bad=1; }
done
[ "$bad" = "0" ] && check_ok "${#PROFILES[@]} profiles name real, non-empty groups"

# Run records hash setup/steps/<step>.sh, so a step named differently from its
# file tracks the wrong file, or none and re-runs forever.
check_head "Step files"
bad=0
for f in "$CHECK_REPO"/setup/steps/*.sh; do
    base="$(basename "$f" .sh)"
    mapfile -t names < <(sed -n 's/^register_step[[:space:]]\+\([A-Za-z0-9_-]\+\).*/\1/p' "$f")
    if [ ${#names[@]} -eq 0 ]; then
        check_fail "setup/steps/$base.sh" "no register_step — nothing in this file can ever run"
        bad=1; continue
    fi
    for n in "${names[@]}"; do
        [ "$n" = "$base" ] || {
            check_fail "$(_line_of "setup/steps/$base.sh" "^register_step[[:space:]]+$n")" "registers '$n', but run records are keyed off setup/steps/$n.sh's hash — rename the file or the step"
            bad=1
        }
    done
done
for s in "${STEPS[@]}"; do
    [ -f "$CHECK_REPO/setup/steps/$s.sh" ] \
        || { check_fail "bootstrap.sh" "STEPS names '$s', but there is no setup/steps/$s.sh for its run record to hash"; bad=1; }
done
[ "$bad" = "0" ] && check_ok "every step is registered by the file it's named after"

# Asserts properties rather than re-implementing the walk, which would agree
# with a bug in it.
check_head "steps_resolve"
_check_plan() {
    local label="$1"; shift
    local requested=("$@") plan=() s n i pos=-1 rc=0
    mapfile -t plan < <(steps_resolve "${requested[@]}")
    local -A in_plan=() at=()
    for i in "${!plan[@]}"; do
        s="${plan[$i]}"
        [ -n "${in_plan[$s]+x}" ] && { check_fail "lib/steps.sh" "steps_resolve $label: '$s' appears twice — it would run twice"; rc=1; }
        in_plan[$s]=1; at[$s]=$i
    done
    for s in "${requested[@]}"; do
        [ -n "${in_plan[$s]+x}" ] || { check_fail "lib/steps.sh" "steps_resolve $label: dropped the requested step '$s'"; rc=1; }
    done
    for s in "${plan[@]}"; do
        for n in ${STEP_NEEDS[$s]:-}; do
            if [ -z "${in_plan[$n]+x}" ]; then
                check_fail "lib/steps.sh" "steps_resolve $label: '$s' needs '$n', which the plan leaves out"
                rc=1
            elif [ "${at[$n]}" -ge "${at[$s]}" ]; then
                check_fail "lib/steps.sh" "steps_resolve $label: '$n' is planned after '$s', which needs it"
                rc=1
            fi
        done
    done
    for s in "${plan[@]}"; do
        if [ "${STEP_AT[$s]}" -le "$pos" ]; then
            check_fail "lib/steps.sh" "steps_resolve $label: '$s' comes out of STEPS order"
            rc=1
        fi
        pos="${STEP_AT[$s]}"
    done
    return "$rc"
}
bad=0
for s in "${STEPS[@]}"; do _check_plan "$s" "$s" || bad=1; done
_check_plan "every step" "${STEPS[@]}" || bad=1
for p in "${!PROFILES[@]}"; do
    sel=()
    for g in core ${PROFILES[$p]}; do
        for s in "${STEPS[@]}"; do
            [ "${STEP_GROUP[$s]}" = "$g" ] && sel+=("$s")
        done
    done
    [ ${#sel[@]} -gt 0 ] && { _check_plan "--profile $p" "${sel[@]}" || bad=1; }
done
# Reverse order in, STEPS order out.
_reversed=()
for ((_i = ${#STEPS[@]} - 1; _i >= 0; _i--)); do _reversed+=("${STEPS[$_i]}"); done
_check_plan "STEPS reversed" "${_reversed[@]}" || bad=1
[ "$bad" = "0" ] && check_ok "plans keep their --needs and STEPS order"

# Every unattended run takes the default, so it must be one of the choices.
check_head "Step options"
bad=0
for v in "${OPTION_VARS[@]}"; do
    step="${OPTION_STEP[$v]}"
    found=0
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        [[ "$c" == *:* ]] || { check_fail "setup/steps/$step.sh" "register_option $v: choice '$c' isn't value:label"; bad=1; }
        [ "${c%%:*}" = "${OPTION_DEFAULT[$v]}" ] && found=1
    done <<<"${OPTION_CHOICES[$v]}"
    [ "$found" = "1" ] || {
        check_fail "$(_line_of "setup/steps/$step.sh" '\-\-default')" "register_option $v --default '${OPTION_DEFAULT[$v]}' isn't one of its --choices — every unattended run uses it"
        bad=1
    }
done
[ "$bad" = "0" ] && check_ok "${#OPTION_VARS[@]} option default(s) are one of their own choices"

check_finish
