# `./bootstrap.sh --pick`. Sets PICKED; returns 1 if the user backed out.
# Plain bash, no whiptail/dialog/fzf — runs on tty1 before curl exists.

# Every other step assumes core ran, so it's locked rather than offered.
_pick_locked() { [ "${STEP_GROUP[$1]}" = "core" ]; }

_pick_render() {
    local -n _sel=$1
    local g s i status mark
    printf '\n'
    for g in "${GROUP_ORDER[@]}"; do
        printf '\033[1m%s\033[0m\n' "$g"
        for i in "${!STEPS[@]}"; do
            s="${STEPS[$i]}"
            [ "${STEP_GROUP[$s]}" = "$g" ] || continue
            if _pick_locked "$s"; then mark='[*]'
            elif [ "${_sel[$i]}" = "1" ]; then mark='[x]'
            else mark='[ ]'; fi
            # The record beats the probe: a step can be done and have
            # nothing to probe for.
            status=""
            if step_is_always "$s"; then :
            elif step_stamp_state "$s"; then status=$'\033[2m  (done)\033[0m'
            elif step_installed "$s"; then status=$'\033[2m  (installed)\033[0m'
            fi
            printf '  %2d %s %-13s %s%s\n' "$((i + 1))" "$mark" "$s" "${STEP_DESC[$s]}" "$status"
        done
    done
    cat <<'TXT'

  1 5 9   toggle those steps        a  everything
  g dev   toggle a whole group      n  nothing but the locked steps
  p cli   apply a profile           m  only what looks missing
TXT
    printf '  \033[1mEnter\033[0m   run the ticked steps          q  quit\n\n'
}

_pick_set_group() {
    local -n s2=$1; local group="$2" value="$3" i
    for i in "${!STEPS[@]}"; do
        _pick_locked "${STEPS[$i]}" && continue
        [ "${STEP_GROUP[${STEPS[$i]}]}" = "$group" ] && s2[$i]="$value"
    done
}

pick_steps() {
    local i s tok
    local sel=()
    for i in "${!STEPS[@]}"; do
        sel[$i]=0
        for s in "$@"; do [ "$s" = "${STEPS[$i]}" ] && sel[$i]=1; done
        # Optional steps (nvidia) start unticked even when swept in by a
        # default "everything" selection — NAMED is bootstrap.sh's record of
        # what was actually typed on the command line.
        if step_is_optional "${STEPS[$i]}" && [ -z "${NAMED[${STEPS[$i]}]+x}" ]; then
            sel[$i]=0
        fi
        _pick_locked "${STEPS[$i]}" && sel[$i]=1
    done

    printf '\033[1;35mPick what to install.\033[0m Locked [*] steps are always included.\n'
    local line
    while true; do
        _pick_render sel
        read -r -p "> " line || { printf '\n'; return 1; }
        case "${line// /}" in
            "")  break ;;
            q|Q) return 1 ;;
        esac
        # A line can carry several commands ("1 4 g dev").
        local -a toks; read -r -a toks <<<"$line"
        i=0
        while [ $i -lt ${#toks[@]} ]; do
            tok="${toks[$i]}"
            case "$tok" in
                a|all)  for s in "${!STEPS[@]}"; do sel[$s]=1; done ;;
                n|none) for s in "${!STEPS[@]}"; do
                            _pick_locked "${STEPS[$s]}" || sel[$s]=0
                        done ;;
                m|missing)
                    # No probe counts as missing; those steps are cheap.
                    for s in "${!STEPS[@]}"; do
                        step_installed "${STEPS[$s]}" && sel[$s]=0 || sel[$s]=1
                        _pick_locked "${STEPS[$s]}" && sel[$s]=1
                    done ;;
                g|group)
                    i=$((i + 1)); local grp="${toks[$i]:-}"
                    if [[ " ${GROUP_ORDER[*]} " != *" $grp "* ]]; then
                        warn "no such group: ${grp:-<none>} (have: ${GROUP_ORDER[*]})"
                    else
                        # Anything off -> turn the group on, else all off.
                        local any_off=0
                        for s in "${!STEPS[@]}"; do
                            [ "${STEP_GROUP[${STEPS[$s]}]}" = "$grp" ] \
                                && [ "${sel[$s]}" = "0" ] && any_off=1
                        done
                        _pick_set_group sel "$grp" "$any_off"
                    fi ;;
                p|profile)
                    i=$((i + 1)); local prof="${toks[$i]:-}"
                    if [ -z "${PROFILES[$prof]:-}" ]; then
                        warn "no such profile: ${prof:-<none>} (have: ${!PROFILES[*]})"
                    else
                        for s in "${!STEPS[@]}"; do
                            _pick_locked "${STEPS[$s]}" || sel[$s]=0
                        done
                        local grp2
                        for grp2 in ${PROFILES[$prof]}; do
                            _pick_set_group sel "$grp2" 1
                        done
                    fi ;;
                *[!0-9]*) warn "don't know what to do with '$tok'" ;;
                *)  local idx=$((tok - 1))
                    # Bash reads a negative index from the END of the array,
                    # so a stray "0" would toggle the last step.
                    if [ "$idx" -lt 0 ] || [ -z "${STEPS[$idx]:-}" ]; then
                        warn "no step number $tok"
                    elif _pick_locked "${STEPS[$idx]}"; then
                        warn "${STEPS[$idx]} is a locked step — it always runs"
                    elif [ "${sel[$idx]}" = "1" ]; then sel[$idx]=0
                    else sel[$idx]=1; fi ;;
            esac
            i=$((i + 1))
        done
    done

    PICKED=()
    for i in "${!STEPS[@]}"; do
        [ "${sel[$i]}" = "1" ] && PICKED+=("${STEPS[$i]}")
    done
    return 0
}
