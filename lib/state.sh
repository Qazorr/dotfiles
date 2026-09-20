# shellcheck shell=bash

DOTFILES_STATE_DIR="${DOTFILES_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles}"
STAMP_DIR="$DOTFILES_STATE_DIR/steps"

# The step file's hash, not a done-flag: editing a step must re-run it.
_stamp_hash() {
    local h
    h="$(sha256sum "$REPO/setup/steps/$1.sh" 2>/dev/null)"
    printf '%s' "${h%% *}"
}

# 0 = done and unchanged, 1 = never recorded, 2 = the step file changed.
step_stamp_state() {
    local f="$STAMP_DIR/$1" first
    [ -f "$f" ] || return 1
    read -r first < "$f" || return 1
    [ "$first" = "$(_stamp_hash "$1")" ] || return 2
    return 0
}

step_stamp_when() {
    local f="$STAMP_DIR/$1" when
    [ -f "$f" ] || return 0
    { read -r _; read -r when; } < "$f" || return 0
    printf '%s' "${when%%T*}"
}

step_stamp_write() {
    mkdir -p "$STAMP_DIR"
    printf '%s\n%s\n%s\n' \
        "$(_stamp_hash "$1")" \
        "$(date -Iseconds)" \
        "$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
        > "$STAMP_DIR/$1"
}

step_stamp_clear() { rm -f "$STAMP_DIR/$1"; }

# shellcheck disable=SC2034  # STAMP_SKIP is read by bootstrap.sh's run_steps
# For a step returning 0 without finishing: don't record it, so the next run
# retries. run_steps resets this.
stamp_skip() { STAMP_SKIP=1; }
