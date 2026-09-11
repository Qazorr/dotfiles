# `./bootstrap.sh --doctor` — check this machine against what the repo expects,
# changing nothing. Every check here is a mistake that actually happened.

DOCTOR_PROBLEMS=0
DOCTOR_NOTES=0

_doc_ok()   { printf '  \033[1;32mok\033[0m    %s\n' "$*"; }
_doc_note() { printf '  \033[1;33mnote\033[0m  %s\n' "$*"; DOCTOR_NOTES=$((DOCTOR_NOTES + 1)); }
_doc_bad()  { printf '  \033[1;31mbad\033[0m   %s\n' "$*"; DOCTOR_PROBLEMS=$((DOCTOR_PROBLEMS + 1)); }
_doc_head() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ~/.local/bin, ~/.config/hypr, ~/.config/kitty and the DMS plugins dir are
# stow symlinks INTO this repo, so writing there writes into git. Seven times
# so far.
_doc_check_writethrough() {
    _doc_head "Stow writethrough (files that landed in the repo)"
    local untracked tracked pkg found=0 f

    # Untracked files inside a stow package: something wrote through a symlink.
    untracked="$(git -C "$REPO" ls-files --others --exclude-standard || true)"
    if [ -z "$untracked" ]; then
        _doc_ok "no untracked files anywhere in the repo"
    else
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            for pkg in "${STOW_PACKAGES[@]}"; do
                if [[ "$f" == "$pkg/"* ]]; then
                    _doc_note "$f — untracked inside a stow package. Yours? git add it. Written through the symlink by some tool? gitignore it."
                    found=1
                    break
                fi
            done
        done <<<"$untracked"
        [ "$found" = "0" ] && _doc_ok "no untracked files inside a stow package"
    fi

    # That scan only sees UNTRACKED files, so a writethrough someone committed
    # is invisible to it — which is how a __pycache__ .pyc from keybind-help
    # ended up in the repo. Build artifacts are never ours, tracked or not.
    tracked="$(git -C "$REPO" ls-files \
        | grep -E '(^|/)(__pycache__|\.venv|node_modules)/|\.(pyc|pyo|o|so)$' || true)"
    if [ -n "$tracked" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            _doc_bad "$f is tracked but is a build artifact — git rm --cached it, and gitignore it"
        done <<<"$tracked"
    else
        _doc_ok "no build artifacts tracked in the repo"
    fi
    return 0
}

# A real file where a symlink belongs means stow never ran, or something
# replaced the link — either way those edits aren't in git.
_doc_check_stow() {
    _doc_head "Stow symlinks"
    local pkg rel target resolved bad
    for pkg in "${STOW_PACKAGES[@]}"; do
        [ -d "$REPO/$pkg" ] || { _doc_bad "$pkg: no such stow package"; continue; }
        bad=0
        while IFS= read -r rel; do
            rel="${rel#./}"
            target="$HOME/$rel"
            if [ ! -e "$target" ] && [ ! -L "$target" ]; then
                _doc_bad "$pkg: $rel is not linked into \$HOME (run ./bootstrap.sh stow)"
                bad=1; break
            fi
            resolved="$(readlink -f "$target" 2>/dev/null || true)"
            if [[ "$resolved" != "$REPO"/* ]]; then
                _doc_bad "$pkg: ~/$rel is a real file, not a link into this repo — its contents are NOT tracked"
                bad=1; break
            fi
        done < <(cd "$REPO/$pkg" && git ls-files | head -40)
        [ "$bad" = "0" ] && _doc_ok "$pkg"
    done
    return 0
}

# Three files repeat this list and can't source lib/paths.sh. Drift surfaces
# much later as "binary could not be found" from a keybind.
_doc_check_path() {
    _doc_head "PATH consistency (lib/paths.sh is the reference)"
    local f dir missing
    for f in zsh/.zprofile zsh/.zshrc hypr/.config/hypr/conf.d/environment.conf; do
        missing=""
        for dir in "${DOTFILES_PATH_DIRS[@]}"; do
            grep -q "\$HOME/${dir#"$HOME"/}" "$REPO/$f" || missing+="${dir#"$HOME"/} "
        done
        if [ -n "$missing" ]; then
            _doc_bad "$f is missing: $missing"
        else
            _doc_ok "$f"
        fi
    done
    for dir in "${DOTFILES_PATH_DIRS[@]}"; do
        [[ ":$PATH:" == *":$dir:"* ]] || _doc_note "$dir is not on this shell's PATH (log out and back in, or exec zsh)"
    done
    return 0
}

_doc_check_steps() {
    _doc_head "Steps"
    local s rc missing=() unknown=0
    for s in "${STEPS[@]}"; do
        rc=0; step_installed "$s" || rc=$?
        case "$rc" in
            0) ;;
            2) unknown=$((unknown + 1)) ;;   # no probe declared
            *) missing+=("$s") ;;
        esac
    done
    if [ ${#missing[@]} -eq 0 ]; then
        _doc_ok "every step that can be probed looks installed"
    else
        _doc_note "not installed: ${missing[*]}"
        _doc_note "install them with: ./bootstrap.sh ${missing[*]}"
    fi
    [ "$unknown" -gt 0 ] && _doc_ok "$unknown step(s) have no install probe (they only change system state)"
    return 0
}

# A record says what ran, not what survived: a step recorded as done whose
# probe now fails means something was removed underneath it.
_doc_check_state() {
    _doc_head "Run records ($STAMP_DIR)"
    local s rc rc2 never=() changed=() gone=() done_=0
    for s in "${STEPS[@]}"; do
        step_is_always "$s" && continue
        rc=0; step_stamp_state "$s" || rc=$?
        case "$rc" in
            0) done_=$((done_ + 1))
               rc2=0; step_installed "$s" || rc2=$?
               [ "$rc2" = "1" ] && gone+=("$s") ;;
            2) changed+=("$s") ;;
            *) never+=("$s") ;;
        esac
    done
    _doc_ok "$done_ step(s) recorded as done"
    [ ${#never[@]}   -gt 0 ] && _doc_note "never run here: ${never[*]}"
    [ ${#changed[@]} -gt 0 ] && _doc_note "edited since they ran, so the next run redoes them: ${changed[*]}"
    [ ${#gone[@]}    -gt 0 ] && _doc_bad "recorded as done but not installed any more: ${gone[*]} (./bootstrap.sh ${gone[*]})"
    return 0
}

# Whether a graphical session can actually start, as opposed to whether the
# packages are installed. Every check here is a way this has already failed:
# a greeter with no DRM access restart-looped until systemd gave up on greetd,
# and a 2D-only GPU device left Hyprland on llvmpipe.
_doc_check_session() {
    _doc_head "Graphical session"
    local n missing drv

    if command -v Hyprland >/dev/null 2>&1; then
        if Hyprland --verify-config 2>&1 | grep -q 'config ok'; then
            _doc_ok "Hyprland config parses"
        else
            _doc_bad "Hyprland config has errors — run: Hyprland --verify-config"
        fi
    fi

    # card0 is root:video, renderD128 is root:render, both 0660. No render
    # node means EGL falls back to software and Hyprland limps or dies.
    for n in /dev/dri/card0 /dev/dri/renderD128; do
        if [ ! -e "$n" ]; then
            _doc_note "$n missing — no DRM device (expected on a headless machine)"
        elif [ -r "$n" ]; then
            _doc_ok "$n readable by $USER"
        else
            _doc_bad "$n not readable by $USER — ./bootstrap.sh groups, then log out and back in"
        fi
    done

    # The greeter runs its own compositor and needs the same access. Nothing
    # in the dms-greeter package grants it.
    if getent passwd greeter >/dev/null 2>&1; then
        missing=""
        for n in video render; do
            id -nG greeter 2>/dev/null | grep -qw "$n" || missing+="$n "
        done
        if [ -n "$missing" ]; then
            _doc_bad "greeter user is not in: ${missing% } — greetd will restart-loop (./bootstrap.sh login)"
        else
            _doc_ok "greeter user can reach the DRM devices"
        fi
    fi

    if command -v eglinfo >/dev/null 2>&1; then
        # `|| true` inside the substitution: awk's early exit SIGPIPEs eglinfo,
        # and pipefail would otherwise make a successful read look like failure.
        drv="$(eglinfo 2>/dev/null | awk -F': ' '/^EGL driver name/{print $2; exit}' || true)"
        case "${drv:-}" in
            "")                    _doc_note "EGL reported no driver — rendering may not work at all" ;;
            swrast|llvmpipe|softpipe) _doc_bad "EGL is on $drv (software) — Hyprland will be unusably slow. No render node, or the GPU driver isn't loaded" ;;
            *)                     _doc_ok "EGL driver: $drv" ;;
        esac
    else
        _doc_note "eglinfo not installed (mesa-utils) — can't tell hardware from software rendering"
    fi

    [ -f /usr/share/wayland-sessions/hyprland.desktop ] \
        && _doc_ok "hyprland.desktop session entry present" \
        || _doc_bad "no /usr/share/wayland-sessions/hyprland.desktop — a login manager has no Hyprland to offer"

    if systemctl list-unit-files greetd.service >/dev/null 2>&1; then
        case "$(systemctl is-active greetd 2>/dev/null)" in
            failed) _doc_bad "greetd has failed — systemctl status greetd, and note it needs 'systemctl reset-failed greetd' after a start-limit-hit" ;;
            active) _doc_ok "greetd is running" ;;
            *)      _doc_note "greetd is enabled but not running (normal until the next reboot)" ;;
        esac
    fi
    return 0
}

_doc_check_groups() {
    _doc_head "Group membership"
    local g current
    current="$(id -nG)"
    for g in video render input docker; do
        getent group "$g" >/dev/null 2>&1 || { _doc_ok "$g: group doesn't exist on this machine (nothing installed it)"; continue; }
        if [[ " $current " == *" $g "* ]]; then
            _doc_ok "$g"
        elif id -nG "$USER" 2>/dev/null | grep -qw "$g"; then
            _doc_note "$g: you're a member, but this session predates it — log out and back in"
        else
            _doc_note "$g: not a member (./bootstrap.sh groups)"
        fi
    done
    return 0
}

# step_stow moves conflicting files aside rather than clobbering them; those
# copies are meant to be read once and deleted.
_doc_check_leftovers() {
    _doc_head "Leftovers"
    local found f
    found="$(find "$HOME" -maxdepth 4 -name '*.pre-dotfiles' -not -path '*/.cache/*' 2>/dev/null | head -20)"
    if [ -n "$found" ]; then
        _doc_note "pre-existing configs moved aside by the stow step (review, then delete):"
        while IFS= read -r f; do printf '        %s\n' "$f"; done <<<"$found"
    else
        _doc_ok "no *.pre-dotfiles files left over"
    fi
    return 0
}

# Advisory: shellcheck arrives with the cli step, which must run on a machine
# that has nothing.
_doc_check_lint() {
    _doc_head "Lint"
    if ! command -v shellcheck >/dev/null 2>&1; then
        _doc_ok "shellcheck not installed (./bootstrap.sh cli) — skipped"
        return 0
    fi
    local out n
    out="$(cd "$REPO" && shellcheck --severity=warning --external-sources \
        bootstrap.sh lib/*.sh setup/steps/*.sh scripts/.local/bin/* 2>&1 || true)"
    n="$(printf '%s' "$out" | grep -c '^In .* line ' || true)"
    if [ "${n:-0}" -eq 0 ]; then
        _doc_ok "shellcheck is clean"
    else
        _doc_note "shellcheck has $n finding(s) — see: shellcheck --severity=warning bootstrap.sh lib/*.sh setup/steps/*.sh"
    fi
    return 0
}

run_doctor() {
    printf '\033[1;35mdotfiles doctor\033[0m — %s\n' "$REPO"
    _doc_check_steps
    _doc_check_state
    _doc_check_writethrough
    _doc_check_stow
    _doc_check_path
    _doc_check_groups
    _doc_check_session
    _doc_check_leftovers
    _doc_check_lint
    printf '\n'
    if [ "$DOCTOR_PROBLEMS" -gt 0 ]; then
        warn "$DOCTOR_PROBLEMS problem(s), $DOCTOR_NOTES note(s)."
        return 1
    fi
    log "No problems. $DOCTOR_NOTES note(s)."
    return 0
}
