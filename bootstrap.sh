#!/usr/bin/env bash
# Provisions a Hyprland desktop on Debian 13 (trixie). See README.md.
#
#   ./bootstrap.sh              run everything not done yet
#   ./bootstrap.sh --list       the steps, and what has already run
#   ./bootstrap.sh --doctor     check this machine, change nothing
#
# Completed steps are recorded in ~/.local/state/dotfiles/steps (lib/state.sh)
# and skipped next time; editing a step's file un-records it.
#
# This file owns the run order and the command line. Steps live in
# setup/steps/, helpers in lib/. Test changes in the VM first (vm/README.md).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"
# shellcheck source=lib/paths.sh
source "$REPO/lib/paths.sh"
# shellcheck source=lib/apt.sh
source "$REPO/lib/apt.sh"
# shellcheck source=lib/fetch.sh
source "$REPO/lib/fetch.sh"
# shellcheck source=lib/steps.sh
source "$REPO/lib/steps.sh"
# shellcheck source=lib/state.sh
source "$REPO/lib/state.sh"
# shellcheck source=lib/picker.sh
source "$REPO/lib/picker.sh"
# shellcheck source=lib/doctor.sh
source "$REPO/lib/doctor.sh"

# --force-confold keeps your modified config files instead of opening the
# conffile prompt, which would stall an unattended run.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_OPTS=(-y -o "Dpkg::Options::=--force-confold" -o "Dpkg::Options::=--force-confdef")

# So this run sees a binary an earlier step just installed.
export PATH="$DOTFILES_PATH_PREFIX:$PATH"

# Used by step_stow and by --doctor's writethrough check.
STOW_PACKAGES=(hypr kitty zsh scripts fastfetch cava wallpaper dms)

# register_step runs at source time, so this must follow lib/steps.sh.
for _step_file in "$REPO"/setup/steps/*.sh; do
    # shellcheck source=/dev/null
    source "$_step_file"
done
unset _step_file

# Run order — the one fact that can't live in a step's own file. A step's
# --needs must appear before it; steps_validate enforces that.
STEPS=(
    backup timeshift prereqs backports nvidia hyprland desktop services ohmyzsh
    quickshell hyprmon cli vscode claudedesktop brave dms quickcapture
    uv krkcommute docker devtools fonts groups stow summary
)

# `core` is never optional: locked in the picker, implicit in every profile.
GROUP_ORDER=(core safety shell desktop apps dev personal)

# Named sets of groups, on top of core.
declare -A PROFILES=(
    [full]="safety shell desktop apps dev personal"
    [desktop]="safety shell desktop"
    [cli]="safety shell"
    [dev]="safety shell apps dev"
)

steps_validate

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
SUDO_KEEPALIVE_PID=""

cleanup() {
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    return 0
}
trap cleanup EXIT

# Only called by steps that build or download, so `./bootstrap.sh stow`
# doesn't refuse to run on a full disk.
require_disk_space() {
    local need_gb="$1" avail_gb
    avail_gb="$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')"
    [ "${avail_gb:-0}" -ge "$need_gb" ] \
        || die "only ${avail_gb}GB free on $HOME — this step needs ~${need_gb}GB."
}

ensure_sudo() {
    if sudo -n true 2>/dev/null; then
        return 0    # already authenticated or passwordless
    fi
    if [ ! -t 0 ]; then
        die "This needs sudo but there's no terminal to ask on. Run it from a shell, or pre-authenticate with 'sudo -v' first."
    fi
    log "Installing system packages needs sudo — asking once, now, so the rest runs unattended."
    sudo -v || die "sudo authentication failed"

    # The Quickshell build outlasts sudo's 15-minute timeout with no sudo call
    # in between, so without this the next one blocks on an unattended prompt.
    ( while true; do
          sleep 50
          kill -0 "$$" 2>/dev/null || exit 0
          sudo -n true 2>/dev/null || exit 0
      done ) &
    SUDO_KEEPALIVE_PID=$!
}

check_environment() {
    [ "$EUID" -ne 0 ] || die "Run this as your normal user, not root/sudo — it calls sudo itself for the specific steps that need it. Running the whole script as root leaves ~/.cache etc. root-owned."
    [ -f /etc/debian_version ] || die "This targets Debian; /etc/debian_version not found."
    if ! grep -q '^VERSION_CODENAME=trixie' /etc/os-release 2>/dev/null; then
        warn "This was written for Debian 13 (trixie). Continuing anyway, but expect drift."
    fi

    command -v sudo >/dev/null || die "sudo is not installed. Install it and add yourself to the sudo group first."
    command -v apt  >/dev/null || die "apt not found — is this really Debian?"

    if ! curl -fsS --max-time 10 -o /dev/null http://deb.debian.org/debian/ 2>/dev/null; then
        # Missing curl is normal on a minimal install; only a real network
        # failure is fatal.
        if command -v curl >/dev/null 2>&1; then
            die "can't reach deb.debian.org — check your network connection."
        fi
        warn "curl not installed yet; skipping the network check (the prereqs step installs it)."
    fi
}

# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------
list_steps() {
    local g s rc status root needs done_
    printf 'Steps, in run order. sudo = needs root.\n'
    for g in "${GROUP_ORDER[@]}"; do
        printf '\n\033[1m%s\033[0m\n' "$g"
        for s in "${STEPS[@]}"; do
            [ "${STEP_GROUP[$s]}" = "$g" ] || continue
            rc=0; step_installed "$s" || rc=$?
            case "$rc" in
                0) status=$'\033[32m✓\033[0m' ;;
                1) status=$'\033[33m·\033[0m' ;;
                *) status=' ' ;;
            esac
            root=""; step_is_root "$s" && root=" [sudo]"
            needs=""; [ -n "${STEP_NEEDS[$s]}" ] && needs=" (needs: ${STEP_NEEDS[$s]% })"
            done_="$(_list_ran "$s")"
            printf '  %s %-13s %s%s%s%s\n' \
                "$status" "$s" "${STEP_DESC[$s]}" "$root" "$needs" "$done_"
        done
    done
    printf '\n  \033[32m✓\033[0m installed   \033[33m·\033[0m not installed   (blank: nothing to probe)\n'
    printf '  The trailing note is what a previous run recorded, in %s\n' "$STAMP_DIR"
}

# The run-record note at the end of a --list line.
_list_ran() {
    local rc=0
    step_is_always "$1" && { printf '\033[2m  (always runs)\033[0m'; return 0; }
    step_stamp_state "$1" || rc=$?
    case "$rc" in
        0) printf '\033[2m  ran %s\033[0m' "$(step_stamp_when "$1")" ;;
        2) printf '\033[33m  changed since it ran\033[0m' ;;
    esac
    return 0
}

usage() {
    cat <<EOF
Usage: ./bootstrap.sh [options] [step ...]

  (no arguments)     every step that hasn't run yet, in order

Choosing less than everything:
  --profile <name>   a named set of groups: ${!PROFILES[*]}
  --group <name>     one group: ${GROUP_ORDER[*]}
  --missing          only steps whose tools aren't installed yet
  --pick             choose interactively
  <step> ...         named steps; anything they --need is pulled in too.
                     Naming a step runs it even if it's recorded as done.

What has already run is remembered in
$STAMP_DIR — one file per step, so a
re-run skips it. Editing setup/steps/<name>.sh un-remembers that step.
  --force, -f        run everything selected, done or not
  --forget [step…]   drop those records (all of them if none named)
  --mark-done [step…]  record steps as done without running them. With no
                     names, every step that already looks installed — for a
                     machine set up before these records existed

  --list, -l         show every step, grouped, with install and run status
  --doctor           check this machine against the repo, change nothing
  --dry-run, -n      print the plan and stop
  --keep-going, -k   don't abort on the first failing step
  --all, -a          same as no arguments, kept for older muscle memory
  --yes, -y          never prompt
  --help, -h         this

Environment overrides:
  DOTFILES_SKIP_BACKUP=1      skip the config snapshot
  DOTFILES_SKIP_TIMESHIFT=1   skip the full-system snapshot
  DOTFILES_KRKCOMMUTE_DIR=…   clone krk-commute somewhere other than ~/Projects
  DOTFILES_STATE_DIR=…        keep the run records somewhere else
EOF
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
run_steps() {
    local plan=("$@")
    local total=${#plan[@]} i=0 s failed=()
    for s in "${plan[@]}"; do
        i=$((i + 1))
        printf '\033[1;35m[%d/%d]\033[0m %s\n' "$i" "$total" "$s"
        STAMP_SKIP=0
        if "step_$s"; then
            # --always steps are never recorded; nor is one that called
            # stamp_skip, meaning it returned 0 without finishing.
            if ! step_is_always "$s" && [ "$STAMP_SKIP" != "1" ]; then
                step_stamp_write "$s" || warn "ran $s but couldn't record it in $STAMP_DIR"
            fi
            continue
        fi
        failed+=("$s")
        if [ "$KEEP_GOING" = "1" ]; then
            warn "step '$s' failed — continuing because of --keep-going"
            continue
        fi
        # So a 40-minute install isn't restarted from the top over one 404.
        warn "step '$s' failed."
        warn "Resume with: ./bootstrap.sh ${plan[*]:$((i - 1))}"
        return 1
    done
    if [ ${#failed[@]} -gt 0 ]; then
        warn "${#failed[@]} step(s) failed: ${failed[*]}"
        warn "Retry them with: ./bootstrap.sh ${failed[*]}"
        return 1
    fi
    return 0
}

KEEP_GOING=0
FORCE=0
# NAMED holds the steps named literally on the command line.
declare -A NAMED=()

# Split a plan into PENDING and SKIPPED, by run record.
plan_pending() {
    PENDING=(); SKIPPED=()
    local s rc
    for s in "$@"; do
        # Naming a step means run it now, record or no record.
        if [ "$FORCE" = "1" ] || [ -n "${NAMED[$s]+x}" ] || step_is_always "$s"; then
            PENDING+=("$s"); continue
        fi
        rc=0; step_stamp_state "$s" || rc=$?
        case "$rc" in
            0) SKIPPED+=("$s") ;;
            2) log "setup/steps/$s.sh changed since it last ran — doing it again"
               PENDING+=("$s") ;;
            *) PENDING+=("$s") ;;
        esac
    done
    return 0
}

main() {
    local requested=() mode="" dry=0 pick=0 yes=0
    local s grp rc needs_root=0 plan=() added=() forget=() real=0 keep=() still=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --list|-l)     list_steps; exit 0 ;;
            --help|-h)     usage; exit 0 ;;
            --doctor)      run_doctor; exit $? ;;
            --all|-a)      mode=all; shift ;;
            --missing)     mode=missing; shift ;;
            --pick)        pick=1; shift ;;
            --dry-run|-n)  dry=1; shift ;;
            --keep-going|-k) KEEP_GOING=1; shift ;;
            --force|-f)    FORCE=1; shift ;;
            --yes|-y)      yes=1; shift ;;
            # For a machine set up before these records existed. With no
            # names, every step whose --provides probe already passes.
            --mark-done)
                shift
                while [ $# -gt 0 ] && [[ "$1" != -* ]]; do
                    step_known "$1" || die "unknown step: $1 (see ./bootstrap.sh --list)"
                    forget+=("$1"); shift
                done
                if [ ${#forget[@]} -eq 0 ]; then
                    for s in "${STEPS[@]}"; do
                        step_is_always "$s" && continue
                        step_installed "$s" && forget+=("$s")
                    done
                fi
                for s in "${forget[@]}"; do
                    step_is_always "$s" && { warn "$s always runs — nothing to record"; continue; }
                    step_stamp_write "$s"
                done
                log "Recorded as done without running: ${forget[*]:-nothing}"
                exit 0 ;;
            --forget)
                shift
                while [ $# -gt 0 ] && [[ "$1" != -* ]]; do
                    step_known "$1" || die "unknown step: $1 (see ./bootstrap.sh --list)"
                    forget+=("$1"); shift
                done
                [ ${#forget[@]} -gt 0 ] || forget=("${STEPS[@]}")
                for s in "${forget[@]}"; do step_stamp_clear "$s"; done
                log "Forgot ${#forget[@]} run record(s) — the next run does those steps again."
                exit 0 ;;
            --profile)
                [ -n "${2:-}" ] || die "--profile needs a name (${!PROFILES[*]})"
                [ -n "${PROFILES[$2]:-}" ] || die "unknown profile: $2 (have: ${!PROFILES[*]})"
                mode=set
                for grp in core ${PROFILES[$2]}; do
                    for s in "${STEPS[@]}"; do
                        [ "${STEP_GROUP[$s]}" = "$grp" ] && requested+=("$s")
                    done
                done
                shift 2 ;;
            --group)
                [ -n "${2:-}" ] || die "--group needs a name (${GROUP_ORDER[*]})"
                [[ " ${GROUP_ORDER[*]} " == *" $2 "* ]] || die "unknown group: $2 (have: ${GROUP_ORDER[*]})"
                mode=set
                for s in "${STEPS[@]}"; do
                    [ "${STEP_GROUP[$s]}" = "$2" ] && requested+=("$s")
                done
                shift 2 ;;
            -*)            die "unknown option: $1 (see ./bootstrap.sh --help)" ;;
            *)
                step_known "$1" || die "unknown step: $1 (see ./bootstrap.sh --list)"
                mode=set; requested+=("$1"); NAMED[$1]=1; shift ;;
        esac
    done

    check_environment

    case "$mode" in
        all)     requested=("${STEPS[@]}") ;;
        missing) for s in "${STEPS[@]}"; do
                     # rc 2 is "no probe, can't tell" — include it anyway.
                     rc=0; step_installed "$s" || rc=$?
                     [ "$rc" != "0" ] && requested+=("$s")
                 done
                 [ ${#requested[@]} -gt 0 ] || { log "Nothing missing."; exit 0; } ;;
        set)     ;;
        # Nothing chosen: everything. The records below cut it back.
        *)       requested=("${STEPS[@]}") ;;
    esac

    if [ "$pick" = "1" ] && [ "$yes" != "1" ]; then
        [ -t 0 ] || die "--pick needs a terminal to ask on."
        pick_steps "${requested[@]}" || { log "Nothing to do."; exit 0; }
        requested=("${PICKED[@]}")
    fi

    [ ${#requested[@]} -gt 0 ] || { log "Nothing selected."; exit 0; }

    mapfile -t plan < <(steps_resolve "${requested[@]}")
    mapfile -t added < <(steps_added "${requested[*]}" "${plan[@]}")

    plan_pending "${plan[@]}"
    [ ${#SKIPPED[@]} -gt 0 ] && log "Already done, skipping: ${SKIPPED[*]}"

    # Nothing left to install means nothing to roll back from — don't spend
    # ten minutes and several GB snapshotting it. (The safety steps are
    # --always so that a run which DOES install always gets its snapshot.)
    for s in "${PENDING[@]}"; do
        [ "${STEP_GROUP[$s]}" = "safety" ] && continue
        step_is_always "$s" || real=1
    done
    if [ "$real" = "0" ]; then
        for s in "${PENDING[@]}"; do
            [ "${STEP_GROUP[$s]}" = "safety" ] || keep+=("$s")
        done
        PENDING=("${keep[@]}")
    fi

    plan=("${PENDING[@]}")
    [ ${#plan[@]} -gt 0 ] || { log "Everything is already done. Redo it all with --force."; exit 0; }
    [ "$real" = "0" ] && log "Nothing new to install — just re-stowing."

    # Only worth saying for prerequisites that survived the skip filter.
    still=()
    for s in "${added[@]}"; do
        [[ " ${plan[*]} " == *" $s "* ]] && still+=("$s")
    done
    [ ${#still[@]} -gt 0 ] && log "Also running (required by what you picked): ${still[*]}"

    if [ "$dry" = "1" ]; then
        log "Plan (${#plan[@]} steps): ${plan[*]}"
        exit 0
    fi

    # Once, up front, before any long build — and only if this run needs it.
    for s in "${plan[@]}"; do
        step_is_root "$s" && needs_root=1 && break
    done
    [ "$needs_root" = "1" ] && ensure_sudo

    run_steps "${plan[@]}"
}

main "$@"
