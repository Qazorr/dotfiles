#!/usr/bin/env bash
# Single entrypoint: installs every package/dependency this setup needs,
# builds Quickshell from source, installs DankMaterialShell, then symlinks
# the dotfiles into $HOME via stow.
#
# Every stage is its own function, and any of them can be run on its own:
#
#   ./bootstrap.sh                 run everything, in order
#   ./bootstrap.sh --list          show the steps
#   ./bootstrap.sh dms             reinstall just DankMaterialShell
#   ./bootstrap.sh vscode cli      just the apps
#   ./bootstrap.sh stow            just re-symlink after editing a dotfile
#
# Idempotent: safe to re-run. Each step checks whether its work is already
# done and skips if so.
#
# Facts this script relies on (re-verified 2026-08-27 on a fresh trixie
# install):
#  - Hyprland + hyprlock/hypridle/xdg-desktop-portal-hyprland and the
#    libhypr* libraries are packaged in trixie-backports (NOT plain trixie)
#    as of Hyprland 0.55.2. `Hyprland --verify-config` reports the conf.d/
#    tree clean against it.
#  - Quickshell is not packaged for any Debian release; built from source
#    (CMake + Ninja + Qt6). Qt 6.8.2 from trixie is new enough.
#  - DankMaterialShell ships prebuilt static binaries and its QML; no Go or
#    Rust toolchain needed. Its QML is installed to ~/.config/quickshell/dms
#    as a REAL directory, deliberately not stowed — it's upstream software,
#    not a dotfile.
#  - DMS bundles Inter / Material Symbols / FiraCode Nerd Font and loads them
#    at runtime via QML FontLoader, so they don't need installing system-wide.
#
# Run this on the test VM first (see vm/README.md) before trusting it on
# real hardware — package lists and Hyprland's own config schema both drift.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Never let apt or debconf stop to ask a question halfway through an
# unattended run. --force-confold keeps any config file you have already
# modified, rather than opening the interactive conffile prompt.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_OPTS=(-y -o "Dpkg::Options::=--force-confold" -o "Dpkg::Options::=--force-confdef")

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
# Steps that call sudo. Used to decide whether to ask for a password at all:
# `./bootstrap.sh stow` should never prompt.
ROOT_STEPS=" timeshift backports hyprland desktop services quickshell cli vscode hyprmon groups "

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
# Steps
# ---------------------------------------------------------------------------

step_backup() { # Snapshot current dotfiles before changing anything
    if [ "${DOTFILES_SKIP_BACKUP:-0}" = "1" ]; then
        warn "DOTFILES_SKIP_BACKUP=1, no config snapshot taken"
        return 0
    fi
    log "Snapshotting current config"
    "$REPO/scripts/.local/bin/dotfiles-backup" \
        || warn "backup failed — continuing, but you have no config rollback point"
}

step_timeshift() { # Full-system snapshot (rsync mode) before install
    if [ "${DOTFILES_SKIP_TIMESHIFT:-0}" = "1" ]; then
        warn "DOTFILES_SKIP_TIMESHIFT=1, no system snapshot taken"
        return 0
    fi

    if ! command -v timeshift >/dev/null 2>&1; then
        log "Installing timeshift"
        sudo apt install "${APT_OPTS[@]}" timeshift
    fi

    # Only snapshot if there isn't already a recent one. Without this, a
    # re-run of bootstrap.sh (which is meant to be cheap) would spend ten
    # minutes and several GB duplicating a snapshot you already have.
    local recent
    recent="$(sudo find /timeshift -maxdepth 3 -name 'info.json' -mtime -1 2>/dev/null | head -1 || true)"
    if [ -n "$recent" ]; then
        log "A timeshift snapshot from the last 24h already exists, skipping"
        return 0
    fi

    # This machine is a single ext4 root — no btrfs, so rsync mode it is.
    # Snapshots land on the same disk, which protects against a bad install
    # but NOT against disk failure. Keep real backups elsewhere.
    local root_dev
    root_dev="$(findmnt -no SOURCE / 2>/dev/null || true)"
    [ -n "$root_dev" ] || { warn "couldn't determine the root device, skipping timeshift"; return 0; }

    local avail_gb
    avail_gb="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
    if [ "${avail_gb:-0}" -lt 25 ]; then
        warn "only ${avail_gb}GB free on / — skipping timeshift (a first snapshot needs ~15GB)"
        return 0
    fi

    log "Creating a timeshift snapshot on $root_dev (first one takes a while)"
    # --rsync explicitly: timeshift picks btrfs mode when it detects a btrfs
    # root, and we want the same behaviour regardless of what it guesses.
    # --tags O marks it on-demand, so timeshift's own retention policy for
    # scheduled snapshots won't rotate this one away.
    sudo timeshift --create --rsync \
        --snapshot-device "$root_dev" \
        --comments "before dotfiles bootstrap $(date +%F-%H%M)" \
        --tags O \
        || warn "timeshift snapshot failed — continuing without a system rollback point"
}

step_backports() { # Enable trixie-backports and refresh apt
    log "Ensuring trixie-backports is enabled"
    if ! grep -Rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        echo "deb http://deb.debian.org/debian trixie-backports main" \
            | sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
    fi
    sudo apt update
}

step_hyprland() { # Hyprland + hyprlock/hypridle/portal, from backports
    log "Installing Hyprland + companions from trixie-backports"
    sudo apt install "${APT_OPTS[@]}" -t trixie-backports \
        hyprland \
        hyprland-guiutils \
        hypridle \
        hyprlock \
        hyprpolkitagent \
        xdg-desktop-portal-hyprland
}

step_desktop() { # Terminal, shell, screenshot/clipboard, network, Qt runtime
    # -t trixie-backports here too. Note qt6-base-dev is NOT in backports at
    # all (it resolves from main either way) — the flag matters because it
    # keeps apt resolving consistently against backports before the quickshell
    # step pulls the newer libxkbcommon from there (see the note there).
    log "Installing terminal, shell, screenshot/clipboard, network tools"
    sudo apt install "${APT_OPTS[@]}" -t trixie-backports \
        kitty zsh stow \
        grim slurp wl-clipboard \
        playerctl brightnessctl \
        fontconfig unzip curl git jq gnupg ca-certificates \
        imagemagick img2pdf tesseract-ocr zbar-tools \
        fastfetch cava \
        accountsservice qt6ct \
        qml6-module-qtmultimedia qml6-module-qtcore qml6-module-qtqml \
        qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
        qml6-module-qtquick-window \
        network-manager network-manager-gnome \
        blueman bluez \
        liblz4-dev \
        qt6-base-dev
}

step_services() { # Enable NetworkManager + Bluetooth
    log "Enabling NetworkManager + Bluetooth services"
    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now bluetooth
}

step_ohmyzsh() { # oh-my-zsh, keeping this repo's .zshrc
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "oh-my-zsh already installed, skipping"
        return 0
    fi
    log "Installing oh-my-zsh (unattended, keeping our own .zshrc)"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc
}

step_quickshell() { # Build Quickshell from source (DMS runs on it)
    if command -v qs >/dev/null 2>&1; then
        log "Quickshell already installed, skipping build"
        return 0
    fi

    local src="$HOME/.cache/dotfiles-build/quickshell-src"
    local build="$HOME/.cache/dotfiles-build/quickshell-build"

    require_disk_space 8
    log "Installing Quickshell build dependencies"
    # -t trixie-backports matters here, not just cosmetic: the hyprland step
    # already pulled a newer libxkbcommon0 from backports (Hyprland 0.55 needs
    # it). Without this flag, plain `apt install` pulls qt6-base-private-dev's
    # libxkbcommon-dev from trixie main, which demands the exact main-suite
    # libxkbcommon0 — a hard version conflict with what's already installed.
    sudo apt install "${APT_OPTS[@]}" -t trixie-backports \
        build-essential cmake ninja-build pkg-config \
        qt6-base-dev qt6-base-private-dev \
        qt6-declarative-dev qt6-declarative-private-dev qt6-shadertools-dev \
        qt6-tools-dev qt6-tools-dev-tools \
        qt6-wayland qt6-wayland-dev qt6-wayland-private-dev \
        libxkbcommon-dev libxkbcommon-x11-dev libxkbregistry-dev \
        libwayland-dev wayland-protocols \
        libdrm-dev libgbm-dev \
        libegl-dev libegl1-mesa-dev libgl-dev libglvnd-dev libglx-dev \
        libopengl-dev mesa-common-dev \
        libvulkan-dev vulkan-utility-libraries-dev \
        libpipewire-0.3-dev libpam0g-dev libglib2.0-dev \
        libpolkit-gobject-1-dev libpolkit-agent-1-dev \
        libjemalloc-dev libxcb1-dev \
        qt6-svg-dev \
        libcli11-dev libunwind-dev libdwarf-dev \
        zlib1g-dev libcurl4-openssl-dev autoconf automake libtool \
        spirv-tools \
        qml6-module-qtquick-effects qml6-module-qtquick-shapes \
        qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qt5compat-graphicaleffects

    log "Cloning and building Quickshell (this takes a while)"
    rm -rf "$src" "$build"
    mkdir -p "$(dirname "$src")"
    git clone --depth=1 https://git.outfoxxed.me/quickshell/quickshell "$src"
    cmake -S "$src" -B "$build" -GNinja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DDISTRIBUTOR="kacper-dotfiles" \
        -DVENDOR_CPPTRACE=ON
    cmake --build "$build"
    sudo cmake --install "$build"
}

step_cli() { # ripgrep, fd, bat, fzf, zoxide, eza, btop, neovim…
    log "Installing CLI tooling"
    # Debian renames two of these: fd-find installs `fdfind` and bat installs
    # `batcat`, both to avoid clashing with older packages. zsh/.zshrc aliases
    # them back to `fd` and `bat`.
    sudo apt install "${APT_OPTS[@]}" \
        ripgrep fd-find bat fzf zoxide eza \
        btop htop git-delta neovim \
        tree unzip
}

step_vscode() { # VS Code from Microsoft's apt repo
    if command -v code >/dev/null 2>&1; then
        log "VS Code already installed, skipping"
        return 0
    fi
    # Not in any Debian release. Preferred over the flatpak because the
    # .zshrc `code` alias passes --ozone-platform=wayland, and a sandboxed
    # build makes reaching toolchains outside it awkward.
    log "Adding Microsoft apt repo and installing VS Code"
    local key=/usr/share/keyrings/microsoft.gpg
    if [ ! -f "$key" ]; then
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor | sudo tee "$key" >/dev/null
    fi
    if ! grep -Rqs "packages.microsoft.com/repos/code" /etc/apt/sources.list.d/ 2>/dev/null; then
        echo "deb [arch=amd64,arm64,armhf signed-by=$key] https://packages.microsoft.com/repos/code stable main" \
            | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        sudo apt update
    fi
    sudo apt install "${APT_OPTS[@]}" code
}

# DMS is the desktop shell: bar, launcher, control centre, notifications,
# polkit agent, wallpaper and matugen theming.
#
# Pinned rather than "latest": DMS moves fast and its QML tracks the CLI's
# API version (the shell logs "Connected (API vNN)" on start). Bump these
# together after testing, not independently.
DMS_VERSION=v1.5.3
DGOP_VERSION=v0.2.3
DSEARCH_VERSION=v0.3.2
MATUGEN_VERSION=v4.2.0

# Not ~/.local/bin: that path is a stow symlink into this repo, so anything
# written there would land in git.
DMS_BIN="$HOME/.local/share/dms/bin"
DMS_QML="$HOME/.config/quickshell/dms"

step_dms() { # DankMaterialShell + dgop, dsearch, matugen
    if [ -x "$DMS_BIN/dms" ] && [ "$("$DMS_BIN/dms" version 2>/dev/null | head -1)" = "dms $DMS_VERSION" ]; then
        log "DankMaterialShell $DMS_VERSION already installed, skipping"
        return 0
    fi

    require_disk_space 2
    log "Installing DankMaterialShell $DMS_VERSION"
    mkdir -p "$DMS_BIN"
    local tmp; tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    curl -fsSL -o "$tmp/dms.tar.gz" \
        "https://github.com/AvengeMedia/DankMaterialShell/releases/download/$DMS_VERSION/dms-full-amd64.tar.gz"
    mkdir -p "$tmp/dms" && tar xzf "$tmp/dms.tar.gz" -C "$tmp/dms"
    install -m755 "$tmp/dms/bin/dms" "$DMS_BIN/dms"

    # QML goes to a real directory. Replaced wholesale on upgrade so removed
    # upstream files don't linger; user settings live in
    # ~/.config/DankMaterialShell and are untouched by this.
    mkdir -p "$(dirname "$DMS_QML")"
    rm -rf "$DMS_QML"
    cp -r "$tmp/dms/dms" "$DMS_QML"

    log "Installing dgop (metrics), dsearch (file search), matugen (theming)"
    curl -fsSL -o "$tmp/dgop.tar.gz" \
        "https://github.com/AvengeMedia/dgop/releases/download/$DGOP_VERSION/dgop-linux-amd64.tar.gz"
    tar xzf "$tmp/dgop.tar.gz" -C "$tmp" && install -m755 "$tmp/dgop-linux-amd64" "$DMS_BIN/dgop"

    curl -fsSL -o "$tmp/dsearch.tar.gz" \
        "https://github.com/AvengeMedia/danksearch/releases/download/$DSEARCH_VERSION/dsearch-linux-amd64.tar.gz"
    tar xzf "$tmp/dsearch.tar.gz" -C "$tmp" && install -m755 "$tmp/dsearch-linux-amd64" "$DMS_BIN/dsearch"

    curl -fsSL -o "$tmp/matugen.tar.gz" \
        "https://github.com/InioX/matugen/releases/download/$MATUGEN_VERSION/matugen-${MATUGEN_VERSION#v}-x86_64.tar.gz"
    tar xzf "$tmp/matugen.tar.gz" -C "$tmp" && install -m755 "$tmp/matugen" "$DMS_BIN/matugen"
}

HYPRMON_VERSION=v0.0.17

step_hyprmon() { # hyprmon: monitor layout/profile manager (build from source)
    if command -v hyprmon >/dev/null 2>&1 \
        && hyprmon --version 2>/dev/null | grep -q "$HYPRMON_VERSION"; then
        log "hyprmon $HYPRMON_VERSION already installed, skipping"
        return 0
    fi

    require_disk_space 2
    log "Installing golang-go (build dependency for hyprmon)"
    # From backports specifically: go.mod requires go 1.26, which trixie
    # main's golang-go (1.24) doesn't have. Go's own toolchain auto-upgrade
    # would fetch 1.26 anyway on a version mismatch, but that means a second,
    # separate ~100MB+ download mid-build — pulling the matching version from
    # apt up front avoids that.
    sudo apt install "${APT_OPTS[@]}" -t trixie-backports golang-go

    local src="$HOME/.cache/dotfiles-build/hyprmon-src"
    log "Cloning and building hyprmon $HYPRMON_VERSION"
    rm -rf "$src"
    git clone --depth=1 --branch "$HYPRMON_VERSION" \
        https://github.com/erans/hyprmon "$src"

    local commit; commit="$(git -C "$src" rev-parse --short HEAD)"
    ( cd "$src" && go build \
        -ldflags="-s -w -X main.Version=$HYPRMON_VERSION -X main.GitCommit=$commit" \
        -o hyprmon . )
    # /usr/local/bin, matching hyprmon's own documented install method —
    # a normal system location, not a stow-managed path.
    sudo install -m755 "$src/hyprmon" /usr/local/bin/hyprmon
}

QUICKCAPTURE_VERSION=v5.1.4

step_quickcapture() { # Quick Capture: DMS screenshot/annotation plugin
    local dir="$HOME/.config/DankMaterialShell/plugins/quickCapture"
    if [ -f "$dir/plugin.json" ] \
        && grep -q "\"version\": \"${QUICKCAPTURE_VERSION#v}\"" "$dir/plugin.json" 2>/dev/null; then
        log "Quick Capture $QUICKCAPTURE_VERSION already installed, skipping"
        return 0
    fi

    log "Installing Quick Capture $QUICKCAPTURE_VERSION"
    # Replaced wholesale, matching the DMS QML step: this is upstream plugin
    # code (with its own .git history, docs, Rust source), not vendored into
    # this repo — same reasoning as Quickshell/DMS/hyprmon. What IS tracked
    # is the enablement state, which lives in dms/.config/DankMaterialShell/
    # (plugin_settings.json + settings.json's rightWidgets) and survives this
    # rm -rf untouched since it's a separate stow-managed path.
    mkdir -p "$(dirname "$dir")"
    rm -rf "$dir"
    git clone --depth=1 --branch "$QUICKCAPTURE_VERSION" \
        https://github.com/hthienloc/dms-quick-capture "$dir"

    log "Installing the verified Rust capture backend"
    sh "$dir/scripts/install-backend.sh" --version "$QUICKCAPTURE_VERSION"

    # After a fresh install (not a reinstall) dms needs to discover it before
    # `plugins enable` finds anything to enable. Harmless no-op if dms isn't
    # running yet (e.g. a first bootstrap run, before autostart has fired).
    if pgrep -x qs >/dev/null 2>&1 && command -v dms >/dev/null 2>&1; then
        dms ipc call plugin-scan scan >/dev/null 2>&1 || true
        dms ipc call plugins enable quickCapture >/dev/null 2>&1 || true
    fi
}

step_fonts() { # JetBrainsMono Nerd Font, for the terminal
    # DMS bundles and FontLoader's its own fonts; this one is for kitty.
    local dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    if [ -d "$dir" ]; then
        log "JetBrainsMono Nerd Font already installed, skipping"
        return 0
    fi
    log "Installing JetBrainsMono Nerd Font"
    mkdir -p "$dir"
    local zip; zip="$(mktemp --suffix=.zip)"
    curl -L -o "$zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -oq "$zip" -d "$dir"
    rm -f "$zip"
    fc-cache -f "$dir" >/dev/null
}

step_groups() { # video/render/input, for a DM-less Hyprland session
    log "Ensuring $USER is in video/render/input groups (DRM/input access without a display manager)"
    sudo usermod -aG video,render,input "$USER"
}

step_stow() { # Symlink the dotfiles into $HOME
    log "Stowing dotfiles"
    cd "$REPO"

    # stow aborts the whole package if any target already exists as a real
    # file, and `set -e` would then kill the run. On a fresh machine that is
    # easy to hit: oh-my-zsh writes its own .zshrc (its --keep-zshrc only
    # preserves one that ALREADY exists), and any app run once before this
    # point may have created its own config.
    #
    # So move every conflicting target aside first. Deterministic, and the
    # backup step already has a copy. Deliberately NOT `stow --adopt`, which
    # would pull the foreign file's contents INTO this repo and overwrite the
    # version-controlled one.
    local pkg rel target moved=0
    for pkg in hypr kitty zsh scripts fastfetch cava wallpaper dms; do
        [ -d "$pkg" ] || continue
        while IFS= read -r rel; do
            rel="${rel#./}"
            target="$HOME/$rel"
            [ -e "$target" ] || [ -L "$target" ] || continue
            # Already ours: a symlink resolving back into this repo.
            [[ "$(readlink -f "$target" 2>/dev/null)" == "$REPO"/* ]] && continue
            warn "Moving aside $rel -> $rel.pre-dotfiles"
            mv "$target" "$target.pre-dotfiles"
            moved=$((moved + 1))
        done < <(cd "$pkg" && find . -type f -o -type l)
    done
    [ "$moved" -gt 0 ] && log "Moved $moved pre-existing file(s) aside; originals kept as *.pre-dotfiles"

    # `dms` carries ~/.config/DankMaterialShell/settings.json. DMS rewrites
    # that file in place rather than atomically, so the stow symlink survives
    # and your shell settings track into this repo automatically.
    for pkg in hypr kitty zsh scripts fastfetch cava wallpaper dms; do
        [ -d "$pkg" ] || { warn "no such stow package: $pkg (skipping)"; continue; }
        stow --target="$HOME" --restow "$pkg"
    done
}

step_summary() { # Print what to do next
    cat <<EOF

Done.

- You were added to video/render/input groups — log out and back in (or
  reboot the VM) for that to take effect.
- No display manager was installed on purpose. Hyprland starts from a TTY
  login via ~/.zprofile — log into tty1 and it launches automatically.
- First real boot: check 'hyprctl monitors' output and fill in
  hypr/.config/hypr/conf.d/monitors/*.conf with your actual monitor names.
- Roll back config with: dotfiles-backup --list / --restore <name>
- Roll back the whole system with: sudo timeshift --restore
EOF
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
STEPS=(
    backup timeshift backports hyprland desktop services ohmyzsh
    quickshell hyprmon cli vscode dms quickcapture fonts groups stow summary
)

list_steps() {
    echo "Steps, in run order:"
    local s desc
    for s in "${STEPS[@]}"; do
        # The trailing comment on each function definition is its description.
        desc="$(sed -n "s/^step_$s() { # \(.*\)$/\1/p" "${BASH_SOURCE[0]}")"
        printf '  %-12s %s\n' "$s" "$desc"
    done
    cat <<'EOF'

Run all:          ./bootstrap.sh
Run some:         ./bootstrap.sh dms vscode
Skip a snapshot:  DOTFILES_SKIP_TIMESHIFT=1 ./bootstrap.sh
                  DOTFILES_SKIP_BACKUP=1 ./bootstrap.sh
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
