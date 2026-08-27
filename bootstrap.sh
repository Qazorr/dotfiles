#!/usr/bin/env bash
# Single entrypoint: installs every package/dependency this setup needs,
# builds Quickshell/hyprmon from source, installs DankMaterialShell + Quick
# Capture, then symlinks the dotfiles into $HOME via stow.
#
# This file is just the runner. Each stage lives in its own file under
# setup/steps/ (step_<name>() { # description ... }), sourced below; shared
# helpers (log/warn/die, apt wrappers, GitHub-release fetching) live in lib/.
# Add a step by dropping a new setup/steps/<name>.sh and adding <name> to the
# STEPS array (and ROOT_STEPS, if it calls sudo) — nothing else changes.
#
#   ./bootstrap.sh                 run everything, in order
#   ./bootstrap.sh --list          show the steps
#   ./bootstrap.sh dms             reinstall just DankMaterialShell
#   ./bootstrap.sh vscode cli      just the apps
#   ./bootstrap.sh stow            just re-symlink after editing a dotfile
#
# Idempotent: each step checks whether its work is already done and skips
# if so. Package/version facts below were re-verified 2026-08-27 on a fresh
# trixie install; both apt's package set and Hyprland's config schema drift,
# so try the test VM first (vm/README.md) before trusting a change here on
# real hardware.
#
#  - Hyprland + hyprlock/hypridle/xdg-desktop-portal-hyprland ship from
#    trixie-backports (0.55.2), not plain trixie.
#  - Quickshell and hyprmon aren't packaged for Debian at all; built from
#    source. Qt 6.8.2 from trixie is new enough for Quickshell; hyprmon's
#    go.mod needs Go 1.26, only in backports.
#  - DMS and Quick Capture ship prebuilt binaries/QML from pinned upstream
#    releases — no toolchain needed for either. Both install to a REAL
#    directory outside any stow package (~/.config/quickshell/dms,
#    ~/.config/DankMaterialShell/plugins/quickCapture) since they're
#    upstream software, not a dotfile, and get replaced wholesale on
#    version bumps.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"
# shellcheck source=lib/apt.sh
source "$REPO/lib/apt.sh"
# shellcheck source=lib/fetch.sh
source "$REPO/lib/fetch.sh"

# Never let apt or debconf stop to ask a question halfway through an
# unattended run. --force-confold keeps any config file you have already
# modified, rather than opening the interactive conffile prompt.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_OPTS=(-y -o "Dpkg::Options::=--force-confold" -o "Dpkg::Options::=--force-confdef")

# Some steps (krkcommute) shell out to a tool another step installs (uv) to a
# real, non-stow location. .zprofile/.zshrc put these on PATH too, but only
# for shells started after that line was added — a script invocation from an
# already-open terminal, or `./bootstrap.sh krkcommute` on its own without
# `uv` run first in the same process, would still miss it even though the
# binary is genuinely there. Set it here as well so this run sees it
# regardless. Directories that don't exist yet (nothing installed there so
# far) are harmless on PATH. Keep in sync with zsh/.zprofile, zsh/.zshrc, and
# hypr/.config/hypr/conf.d/environment.conf.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/share/uv/bin:$HOME/.local/share/krk-commute/bin:$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
# Steps that call sudo. Used to decide whether to ask for a password at all:
# `./bootstrap.sh stow` should never prompt.
ROOT_STEPS=" timeshift backports hyprland desktop services quickshell cli vscode hyprmon claudedesktop brave groups "

# Every stow package this repo has. Named once here; step_stow uses it twice
# (moving conflicts aside, then the actual restow) instead of repeating the list.
STOW_PACKAGES=(hypr kitty zsh scripts fastfetch cava wallpaper dms)

SUDO_KEEPALIVE_PID=""

cleanup() {
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    return 0
}
trap cleanup EXIT

# Only the steps that actually build or download something care about disk
# space; `./bootstrap.sh stow` should not refuse to run on a full disk.
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

    # Refresh the timestamp until this script exits. Without this, the
    # Quickshell build (10-20 minutes with no sudo call in between) outlasts
    # the default 15-minute timeout and the next sudo silently blocks on a
    # password prompt you have already walked away from.
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

    # Fail fast and say why, rather than dying twenty minutes in.
    command -v sudo >/dev/null || die "sudo is not installed. Install it and add yourself to the sudo group first."
    command -v apt  >/dev/null || die "apt not found — is this really Debian?"

    if ! curl -fsS --max-time 10 -o /dev/null http://deb.debian.org/debian/ 2>/dev/null; then
        # curl may legitimately be missing on a minimal install; only treat a
        # reachable-network failure as fatal, not a missing tool.
        if command -v curl >/dev/null 2>&1; then
            die "can't reach deb.debian.org — check your network connection."
        fi
        warn "curl not installed yet; skipping the network check (the desktop step installs it)."
    fi
}

# ---------------------------------------------------------------------------
# Steps — one file per stage under setup/steps/, sourced here. Order of
# definition doesn't matter; the STEPS array below controls run order.
# ---------------------------------------------------------------------------
for _step_file in "$REPO"/setup/steps/*.sh; do
    # shellcheck source=/dev/null
    source "$_step_file"
done
unset _step_file

STEPS=(
    backup timeshift backports hyprland desktop services ohmyzsh
    quickshell hyprmon cli vscode claudedesktop brave dms quickcapture uv krkcommute fonts groups stow summary
)

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
list_steps() {
    echo "Steps, in run order:"
    local s desc
    for s in "${STEPS[@]}"; do
        # The trailing comment on each function definition is its description.
        desc="$(sed -n "s/^step_$s() { # \(.*\)$/\1/p" "$REPO/setup/steps/$s.sh" 2>/dev/null)"
        printf '  %-12s %s\n' "$s" "$desc"
    done
    cat <<'EOF'

Run all:          ./bootstrap.sh
Run some:         ./bootstrap.sh dms vscode
Skip a snapshot:  DOTFILES_SKIP_TIMESHIFT=1 ./bootstrap.sh
                  DOTFILES_SKIP_BACKUP=1 ./bootstrap.sh
Different projects dir:  DOTFILES_KRKCOMMUTE_DIR=~/code/krk-commute ./bootstrap.sh krkcommute
EOF
}

main() {
    case "${1:-}" in
        --list|-l) list_steps; exit 0 ;;
        --help|-h) list_steps; exit 0 ;;
    esac

    check_environment

    local to_run=()
    if [ $# -gt 0 ]; then
        to_run=("$@")
        local s
        for s in "${to_run[@]}"; do
            declare -F "step_$s" >/dev/null \
                || die "unknown step: $s (see ./bootstrap.sh --list)"
        done
    else
        to_run=("${STEPS[@]}")
    fi

    # Ask for the password once, up front, before any long build — but only
    # if something in this run actually needs it.
    local s needs_root=0
    for s in "${to_run[@]}"; do
        [[ "$ROOT_STEPS" == *" $s "* ]] && needs_root=1 && break
    done
    [ "$needs_root" = "1" ] && ensure_sudo

    local total=${#to_run[@]} i=0
    for s in "${to_run[@]}"; do
        i=$((i + 1))
        printf '\033[1;35m[%d/%d]\033[0m %s\n' "$i" "$total" "$s"
        "step_$s"
    done
}

main "$@"
