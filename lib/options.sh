# shellcheck shell=bash
# Prompts for step options (register_option, lib/steps.sh) once, up front,
# for whatever's in the plan — so the run itself never stops to ask again.
# Plain bash, same reasoning as lib/picker.sh: no whiptail/dialog/fzf.

# resolve_step_options <yes: 0|1> <plan step>...
# yes=1 (--yes, "never prompt") is treated like no terminal: use the default.
resolve_step_options() {
    local yes="$1"; shift
    local plan=("$@") var step default tok
    for var in "${OPTION_VARS[@]}"; do
        step="${OPTION_STEP[$var]}"
        [[ " ${plan[*]} " == *" $step "* ]] || continue

        if [ -n "${!var:-}" ]; then
            log "$var=${!var} (already set, not asking)"
            continue
        fi

        default="${OPTION_DEFAULT[$var]}"
        local -a choices=(); mapfile -t choices <<<"${OPTION_CHOICES[$var]}"
        if [ ! -t 0 ] || [ "$yes" = "1" ]; then
            log "$var not set — using the default: $default"
            export "$var=$default"
            continue
        fi

        printf '\n\033[1;35m%s\033[0m  \033[2m(%s)\033[0m\n' "${OPTION_PROMPT[$var]}" "$step"
        local i=0 c val lbl mark
        for c in "${choices[@]}"; do
            i=$((i + 1))
            val="${c%%:*}"; lbl="${c#*:}"
            mark=""; [ "$val" = "$default" ] && mark=$'  \033[2m(default)\033[0m'
            printf '  %d) %s%s\n' "$i" "$lbl" "$mark"
        done

        local sel=""
        while true; do
            read -r -p "> " tok || { printf '\n'; tok=""; }
            if [ -z "$tok" ]; then
                sel="$default"; break
            elif [[ "$tok" =~ ^[0-9]+$ ]] && [ "$tok" -ge 1 ] && [ "$tok" -le "${#choices[@]}" ]; then
                sel="${choices[$((tok - 1))]%%:*}"; break
            fi
            warn "enter a number 1-${#choices[@]}, or press Enter for the default ($default)"
        done
        export "$var=$sel"
        log "$var=$sel"
    done
    return 0
}
