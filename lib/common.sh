# Shared shell helpers, sourced by bootstrap.sh and scripts/.local/bin/*.
# Not a stow package (nothing here belongs symlinked into $HOME) — just a
# plain file consumers reach via their own resolved $REPO path.

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
