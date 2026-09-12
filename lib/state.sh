# shellcheck shell=bash
# Per-step run records. In ~/.local/state, never in the repo — a committed
# record would tell a fresh clone everything was already installed.

DOTFILES_STATE_DIR="${DOTFILES_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles}"
STAMP_DIR="$DOTFILES_STATE_DIR/steps"

_stamp_file() { printf '%s/%s' "$STAMP_DIR" "$1"; }

# The step file's hash, not a done-flag: editing a step must re-run it.
_stamp_hash() { sha256sum "$REPO/setup/steps/$1.sh" 2>/dev/null | cut -d' ' -f1; }

# 0 = done and unchanged since, 1 = never recorded, 2 = the step file changed.
step_stamp_state() {
    local f; f="$(_stamp_file "$1")"
    [ -f "$f" ] || return 1
    [ "$(sed -n 1p "$f" 2>/dev/null)" = "$(_stamp_hash "$1")" ] || return 2
    return 0
}

step_stamp_when() { sed -n 2p "$(_stamp_file "$1")" 2>/dev/null | cut -dT -f1; }

step_stamp_write() {
    mkdir -p "$STAMP_DIR"
    printf '%s\n%s\n%s\n' \
        "$(_stamp_hash "$1")" \
        "$(date -Iseconds)" \
        "$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
        > "$(_stamp_file "$1")"
}

step_stamp_clear() { rm -f "$(_stamp_file "$1")"; }

# For a step returning 0 without having finished (krkcommute with no clone
# auth): don't record it, so the next run retries. run_steps resets this.
# shellcheck disable=SC2034  # STAMP_SKIP is read by bootstrap.sh's run_steps
stamp_skip() { STAMP_SKIP=1; }
