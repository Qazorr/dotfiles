# shellcheck shell=bash
# Per-step run records. In ~/.local/state, never in the repo — a committed
# record would tell a fresh clone everything was already installed.

DOTFILES_STATE_DIR="${DOTFILES_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles}"
STAMP_DIR="$DOTFILES_STATE_DIR/steps"

# The step file's hash, not a done-flag: editing a step must re-run it.
_stamp_hash() {
    local h
    h="$(sha256sum "$REPO/setup/steps/$1.sh" 2>/dev/null)"
    printf '%s' "${h%% *}"
}

# 0 = done and unchanged since, 1 = never recorded, 2 = the step file changed.
step_stamp_state() {
    local f="$STAMP_DIR/$1" first
    # -f first: a missing file makes the redirection itself print an error.
    [ -f "$f" ] || return 1
    read -r first < "$f" || return 1
    [ "$first" = "$(_stamp_hash "$1")" ] || return 2
    return 0
}

step_stamp_when() {
    local f="$STAMP_DIR/$1" when
    [ -f "$f" ] || return 0
    # line 1 is the hash, line 2 the timestamp
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

# For a step returning 0 without having finished (krkcommute with no clone
# auth): don't record it, so the next run retries. run_steps resets this.
# shellcheck disable=SC2034  # STAMP_SKIP is read by bootstrap.sh's run_steps
stamp_skip() { STAMP_SKIP=1; }
