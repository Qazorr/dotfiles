# shellcheck shell=bash

# shellcheck disable=SC2034  # read by picker/options/doctor/bootstrap
declare -A STEP_DESC=() STEP_GROUP=() STEP_NEEDS=() STEP_ROOT=() STEP_PROVIDES=() \
           STEP_ALWAYS=() STEP_OPTIONAL=()

# register_step <name> --desc "..." [--group g] [--root] [--always]
#                      [--optional] [--needs s...] [--provides cmd-or-path...]
#
#   --root      calls sudo, so a run containing it asks for a password
#   --always    never recorded, runs every time (stow, summary)
#   --optional  only runs when named, or ticked in --pick
#   --needs     must already be done for this step's INSTALL to succeed;
#               install-time only, so `bootstrap.sh dms` can't pull in nvidia
#   --provides  exists once the step has run; drives --list/--missing/--doctor
register_step() {
    local name="$1"; shift
    local desc="" group=core root=0 always=0 optional=0 needs="" provides=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --desc)  desc="$2"; shift 2 ;;
            --group) group="$2"; shift 2 ;;
            --root)  root=1; shift ;;
            --always) always=1; shift ;;
            --optional) optional=1; shift ;;
            --needs)
                shift
                while [ $# -gt 0 ] && [[ "$1" != --* ]]; do needs+="$1 "; shift; done ;;
            --provides)
                shift
                while [ $# -gt 0 ] && [[ "$1" != --* ]]; do provides+="$1 "; shift; done ;;
            *) die "register_step $name: unknown option '$1'" ;;
        esac
    done
    [ -n "$desc" ] || die "register_step $name: --desc is required (it's what --list prints)"
    STEP_DESC[$name]="$desc"
    STEP_GROUP[$name]="$group"
    STEP_ROOT[$name]="$root"
    STEP_ALWAYS[$name]="$always"
    STEP_OPTIONAL[$name]="$optional"
    STEP_NEEDS[$name]="$needs"
    STEP_PROVIDES[$name]="$provides"
}

step_known()     { [ -n "${STEP_DESC[$1]+x}" ]; }
step_is_root()   { [ "${STEP_ROOT[$1]:-0}" = "1" ]; }
step_is_always() { [ "${STEP_ALWAYS[$1]:-0}" = "1" ]; }
step_is_optional() { [ "${STEP_OPTIONAL[$1]:-0}" = "1" ]; }
step_auto_excluded() { step_is_optional "$1" && [ -z "${NAMED[$1]+x}" ]; }

# shellcheck disable=SC2034  # read by picker/options/doctor/bootstrap
declare -A OPTION_STEP=() OPTION_PROMPT=() OPTION_CHOICES=() OPTION_DEFAULT=()
OPTION_VARS=()   # registration order, so prompts come out in a stable order

# register_option <step> <ENV_VAR> --prompt "..." --choices "value:label"... --default v
#
# The step reads $<ENV_VAR>. Already set when the step runs means no prompt,
# which is what keeps DOTFILES_NVIDIA_MODE=open unattended.
register_option() {
    local step="$1" var="$2"; shift 2
    local prompt="" default="" choices=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --prompt)  prompt="$2"; shift 2 ;;
            --default) default="$2"; shift 2 ;;
            --choices)
                shift
                while [ $# -gt 0 ] && [[ "$1" != --* ]]; do choices+=("$1"); shift; done ;;
            *) die "register_option $step $var: unknown option '$1'" ;;
        esac
    done
    [ -n "$prompt" ]        || die "register_option $step $var: --prompt is required"
    [ ${#choices[@]} -gt 0 ] || die "register_option $step $var: --choices is required"
    [ -n "$default" ]       || die "register_option $step $var: --default is required"
    OPTION_STEP[$var]="$step"
    OPTION_PROMPT[$var]="$prompt"
    OPTION_CHOICES[$var]="$(printf '%s\n' "${choices[@]}")"
    OPTION_DEFAULT[$var]="$default"
    OPTION_VARS+=("$var")
}

step_installed() {
    local list="${STEP_PROVIDES[$1]:-}" p
    [ -n "$list" ] || return 2
    for p in $list; do
        case "$p" in
            /*) [ -e "$p" ] || return 1 ;;
            *)  command -v "$p" >/dev/null 2>&1 || return 1 ;;
        esac
    done
    return 0
}

# Expand a request into a plan: pull in --needs, then sort back into STEPS
# order so nothing runs before its prerequisite.
steps_resolve() {
    local -A chosen=()
    local queue=("$@") s n
    while [ ${#queue[@]} -gt 0 ]; do
        s="${queue[0]}"; queue=("${queue[@]:1}")
        [ -n "${chosen[$s]+x}" ] && continue
        chosen[$s]=1
        for n in ${STEP_NEEDS[$s]:-}; do
            [ -n "${chosen[$n]+x}" ] || queue+=("$n")
        done
    done
    for s in "${STEPS[@]}"; do
        [ -n "${chosen[$s]+x}" ] && printf '%s\n' "$s"
    done
    return 0
}

steps_added() {
    local requested="$1"; shift
    local s
    for s in "$@"; do
        [[ " $requested " == *" $s "* ]] || printf '%s\n' "$s"
    done
    return 0
}

steps_validate() {
    local s n v idx=0
    local -A pos=()
    for s in "${STEPS[@]}"; do
        step_known "$s" \
            || die "bootstrap.sh's STEPS names '$s', but setup/steps/$s.sh has no register_step for it."
        [ -z "${pos[$s]+x}" ] || die "'$s' appears twice in STEPS."
        pos[$s]=$((idx++))
    done
    for s in "${!STEP_DESC[@]}"; do
        [ -n "${pos[$s]+x}" ] \
            || die "setup/steps/$s.sh registers '$s', but it's missing from bootstrap.sh's STEPS — it would never run."
        declare -F "step_$s" >/dev/null \
            || die "'$s' is registered but defines no step_$s() function."
        for n in ${STEP_NEEDS[$s]}; do
            step_known "$n" || die "'$s' needs '$n', which isn't a step."
            [ "${pos[$n]}" -lt "${pos[$s]}" ] \
                || die "'$s' needs '$n', but '$n' runs later in STEPS — reorder it."
            step_is_optional "$n" \
                && die "'$s' needs '$n', which is --optional — it must not be pulled in automatically."
        done
    done
    for v in "${OPTION_VARS[@]}"; do
        step_known "${OPTION_STEP[$v]}" \
            || die "register_option $v: '${OPTION_STEP[$v]}' isn't a step."
    done
}
