# Part of bootstrap.sh — sourced by it, not meant to run standalone.
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
    apt_install_backports \
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
