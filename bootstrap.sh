#!/usr/bin/env bash
# Single entrypoint: installs every package/dependency this setup needs,
# builds Quickshell from source, then symlinks the dotfiles into $HOME via
# stow. Idempotent-ish: safe to re-run (e.g. just to re-symlink after
# editing a dotfile — it'll skip anything already installed/built).
#
# Facts this script relies on (re-verified 2026-08-27 on a fresh trixie
# install; backports had moved 0.54.x -> 0.55.2 since the first pass):
#  - Hyprland + hyprlock/hypridle/hyprpolkitagent/xdg-desktop-portal-hyprland/
#    hyprland-guiutils and the libhypr* libraries are packaged in
#    trixie-backports (NOT plain trixie) as of Hyprland 0.55.2. No source
#    build, no compiler-compat patching required. `Hyprland --verify-config`
#    reports the conf.d/ tree clean against 0.55.2.
#  - Quickshell is not packaged for any Debian release; built from source
#    (CMake + Ninja + Qt6). Its BUILD.md build is a plain configure/build/
#    install, no source patching.
#  - swww and wallust are Rust, not packaged for Debian; installed via cargo.
#
# Run this on the test VM first (see vm/README.md) before trusting it on
# real hardware — package lists and Hyprland's own config schema both drift.
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ "$EUID" -ne 0 ] || die "Run this as your normal user, not root/sudo — it calls sudo itself for the specific steps that need it. Running the whole script as root leaves ~/.cargo etc. root-owned."

[ -f /etc/debian_version ] || die "This targets Debian; /etc/debian_version not found."
if ! grep -q '^VERSION_CODENAME=trixie' /etc/os-release 2>/dev/null; then
    warn "This was written for Debian 13 (trixie). Continuing anyway, but expect drift."
fi

# --- 1. Enable trixie-backports ------------------------------------------
log "Ensuring trixie-backports is enabled"
BACKPORTS_LIST=/etc/apt/sources.list.d/trixie-backports.list
if ! grep -Rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    echo "deb http://deb.debian.org/debian trixie-backports main" | sudo tee "$BACKPORTS_LIST" >/dev/null
fi
sudo apt update

# --- 2. Hyprland stack, from backports ------------------------------------
log "Installing Hyprland + companions from trixie-backports"
sudo apt install -y -t trixie-backports \
    hyprland \
    hyprland-guiutils \
    hypridle \
    hyprlock \
    hyprpolkitagent \
    xdg-desktop-portal-hyprland

# --- 3. General desktop/dev packages ---------------------------------------
# -t trixie-backports here too. Note qt6-base-dev is NOT in backports at all
# (it resolves from main either way) — the flag matters because it keeps apt
# resolving consistently against backports before step 4 pulls the newer
# libxkbcommon from there (see the libxkbcommon note in step 4).
log "Installing terminal, shell, notifications, screenshot/clipboard tools"
sudo apt install -y -t trixie-backports \
    kitty zsh stow \
    mako-notifier \
    grim slurp wl-clipboard \
    playerctl brightnessctl \
    fontconfig unzip curl git jq \
    fastfetch cava \
    network-manager network-manager-gnome \
    blueman bluez \
    liblz4-dev \
    qt6-base-dev

log "Enabling NetworkManager + Bluetooth services"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing oh-my-zsh (unattended, keeping our own .zshrc)"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc
fi

# --- 4. Quickshell, built from source --------------------------------------
QS_SRC="$HOME/.cache/dotfiles-build/quickshell-src"
QS_BUILD="$HOME/.cache/dotfiles-build/quickshell-build"

if ! command -v qs >/dev/null 2>&1; then
    log "Installing Quickshell build dependencies"
    # -t trixie-backports matters here, not just cosmetic: step 2 already
    # pulled a newer libxkbcommon0 from backports (Hyprland 0.55 needs it).
    # Without this flag, plain `apt install` pulls qt6-base-private-dev's
    # libxkbcommon-dev from trixie main, which demands the exact main-suite
    # libxkbcommon0 — a hard version conflict with what's already installed.
    # Same fix Debian-Hyprland's install_dep() applies for this exact case.
    sudo apt install -y -t trixie-backports \
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
        qt6-svg-dev libqt6svg6-dev \
        libcli11-dev libunwind-dev libdwarf-dev \
        zlib1g-dev libcurl4-openssl-dev autoconf automake libtool \
        spirv-tools \
        qml6-module-qtquick-effects qml6-module-qtquick-shapes \
        qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qt5compat-graphicaleffects

    log "Cloning and building Quickshell (this takes a while)"
    rm -rf "$QS_SRC" "$QS_BUILD"
    mkdir -p "$(dirname "$QS_SRC")"
    git clone --depth=1 https://git.outfoxxed.me/quickshell/quickshell "$QS_SRC"
    cmake -S "$QS_SRC" -B "$QS_BUILD" -GNinja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DDISTRIBUTOR="kacper-dotfiles" \
        -DVENDOR_CPPTRACE=ON
    cmake --build "$QS_BUILD"
    sudo cmake --install "$QS_BUILD"
else
    log "Quickshell already installed, skipping build"
fi

# --- 5. Rust tools: swww (wallpaper) + wallust (palette generator) --------
if ! command -v cargo >/dev/null 2>&1; then
    log "Installing Rust toolchain via rustup (Debian's apt cargo/rustc lag too far behind)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env"
fi

if ! command -v swww >/dev/null 2>&1; then
    log "Installing swww via cargo (not on crates.io, building from its git repo)"
    # The repo has two binary crates (swww, swww-daemon) — `cargo install
    # --git` needs each named explicitly rather than installing "the repo".
    cargo install --locked --git https://github.com/LGFae/swww swww
    cargo install --locked --git https://github.com/LGFae/swww swww-daemon
fi
if ! command -v wallust >/dev/null 2>&1; then
    log "Installing wallust via cargo"
    cargo install --locked wallust
fi

# --- 6. A Nerd Font, for bar glyphs/icons ----------------------------------
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
if [ ! -d "$FONT_DIR" ]; then
    log "Installing JetBrainsMono Nerd Font"
    mkdir -p "$FONT_DIR"
    TMP_ZIP="$(mktemp --suffix=.zip)"
    curl -L -o "$TMP_ZIP" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -oq "$TMP_ZIP" -d "$FONT_DIR"
    rm -f "$TMP_ZIP"
    fc-cache -f "$FONT_DIR" >/dev/null
fi

# --- 7. User groups needed for a DM-less Hyprland session ------------------
log "Ensuring $USER is in video/render/input groups (DRM/input access without a display manager)"
sudo usermod -aG video,render,input "$USER"

# --- 8. Stow the actual dotfiles -------------------------------------------
log "Stowing dotfiles"
cd "$(dirname "${BASH_SOURCE[0]}")"

# oh-my-zsh's --keep-zshrc only preserves a .zshrc that ALREADY exists; on a
# genuinely fresh machine there is none, so its installer writes its own
# template and stow then (correctly) refuses to clobber it. Move any
# non-symlink dotfile we're about to own out of the way first.
for f in .zshrc .zprofile; do
    if [ -e "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
        warn "Backing up existing $f -> $f.pre-dotfiles"
        mv "$HOME/$f" "$HOME/$f.pre-dotfiles"
    fi
done

# wallust rewrites colors-hyprland.conf on every wallpaper change. Because
# ~/.config/hypr is a stow symlink into this repo, that write lands on a
# tracked file and leaves the repo permanently dirty. Ship the palette as a
# .default and seed the generated copy from it (gitignored) instead.
HYPR_WALLUST="hypr/.config/hypr/wallust"
if [ -f "$HYPR_WALLUST/colors-hyprland.conf.default" ] \
   && [ ! -f "$HYPR_WALLUST/colors-hyprland.conf" ]; then
    cp "$HYPR_WALLUST/colors-hyprland.conf.default" \
       "$HYPR_WALLUST/colors-hyprland.conf"
fi
for pkg in hypr quickshell kitty zsh mako wallust scripts fastfetch cava wallpaper; do
    stow --target="$HOME" --restow "$pkg"
done

cat <<EOF

Done.

- You were added to video/render/input groups — log out and back in (or
  reboot the VM) for that to take effect.
- No display manager was installed on purpose. Hyprland starts from a TTY
  login via ~/.zprofile (see zsh/.zprofile in this repo) — log into tty1
  and it launches automatically.
- First real boot: check 'hyprctl monitors' output and fill in
  hypr/.config/hypr/conf.d/monitors/*.conf with your actual monitor names.
EOF
