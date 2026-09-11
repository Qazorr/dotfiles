# The step registry: each setup/steps/<name>.sh declares its own metadata, so
# bootstrap.sh only owns the run order. steps_validate() turns drift into a
# startup error rather than a silent bug.

declare -A STEP_DESC=() STEP_GROUP=() STEP_NEEDS=() STEP_ROOT=() STEP_PROVIDES=() \
           STEP_ALWAYS=()

# register_step <name> --desc "..." [--group <group>] [--root] [--always]
#                      [--needs <step>...] [--provides <cmd-or-path>...]
#
#   --root      calls sudo, so a run containing it asks for a password
#   --always    never recorded, so it runs every time (stow, summary)
#   --needs     must already be done for this step's INSTALL to succeed;
#               pulled in automatically. Install-time only — `bootstrap.sh
#               dms` must not trigger an NVIDIA driver install.
#   --provides  a command or path that exists once the step has run. Drives
#               --list, --missing and --doctor.
register_step() {
    local name="$1"; shift
    local desc="" group=core root=0 always=0 needs="" provides=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --desc)  desc="$2"; shift 2 ;;
            --group) group="$2"; shift 2 ;;
            --root)  root=1; shift ;;
            --always) always=1; shift ;;
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
    STEP_NEEDS[$name]="$needs"
    STEP_PROVIDES[$name]="$provides"
}

step_known()     { [ -n "${STEP_DESC[$1]+x}" ]; }
step_is_root()   { [ "${STEP_ROOT[$1]:-0}" = "1" ]; }
step_is_always() { [ "${STEP_ALWAYS[$1]:-0}" = "1" ]; }

# 0 = all present, 1 = something missing, 2 = no probe declared.
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

# Expand a request into a full plan: pull in --needs, then sort back into
# STEPS order so nothing runs before its prerequisite.
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

# Which of $@ came from --needs rather than being asked for.
steps_added() {
    local requested="$1"; shift
    local s
    for s in "$@"; do
        [[ " $requested " == *" $s "* ]] || printf '%s\n' "$s"
    done
    return 0
}

steps_validate() {
    local s n idx=0
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
        done
    done
}
