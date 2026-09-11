# Follows JaKooLit's Debian-Hyprland install-scripts/nvidia.sh; no-ops with no
# NVIDIA card. trixie 2026-09-01: nvidia-driver 550.163.01, in non-free, which
# a stock install doesn't enable.
register_step nvidia \
    --desc "NVIDIA driver + nouveau blacklist + DRM modeset (skipped if no card)" \
    --group desktop --root --needs prereqs
# Deliberately no --provides: this step completes successfully on a machine
# with no NVIDIA card, where nvidia-smi will never exist. Declaring it made
# --doctor report "recorded as done but not installed any more" forever.

NVIDIA_MODPROBE_CONF=/etc/modprobe.d/zz-dotfiles-nvidia.conf
NVIDIA_APT_LIST=/etc/apt/sources.list.d/debian-nonfree.list

# 10de is NVIDIA's PCI vendor ID.
_nvidia_present() {
    lspci -nn 2>/dev/null | grep -Ei 'vga compatible controller|3d controller' \
        | grep -q '\[10de:'
}

# A hybrid laptop renders on the iGPU and offloads per-app, so it needs a
# different Hyprland env — see _nvidia_write_hypr_env.
_nvidia_discrete_only() {
    local others
    others="$(lspci -nn 2>/dev/null | grep -Ei 'vga compatible controller|3d controller' \
        | grep -vc '\[10de:' || true)"
    [ "${others:-0}" -eq 0 ]
}

# A separate file, not a rewrite of the installer's sources.list, and without
# non-free-firmware — apt warns loudly about a component configured twice.
_nvidia_enable_nonfree() {
    [ -f "$NVIDIA_APT_LIST" ] && return 0
    log "Enabling contrib + non-free (nvidia-driver lives in non-free)"
    local codename; codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    sudo tee "$NVIDIA_APT_LIST" >/dev/null <<EOF
deb http://deb.debian.org/debian $codename contrib non-free
deb http://deb.debian.org/debian $codename-updates contrib non-free
deb http://security.debian.org/debian-security $codename-security contrib non-free
EOF
    sudo apt update
}

_nvidia_write_modprobe() {
    local want
    want="$(cat <<'EOF'
# Written by dotfiles bootstrap.sh (step_nvidia).
# modeset=1 is what makes the driver usable under Wayland at all.
options nvidia-drm modeset=1 fbdev=1
# Keeps VRAM across suspend. Needs the nvidia-suspend/resume/hibernate units,
# enabled below.
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
)"
    [ -f "$NVIDIA_MODPROBE_CONF" ] && [ "$(sudo cat "$NVIDIA_MODPROBE_CONF")" = "$want" ] && return 1
    log "Writing $NVIDIA_MODPROBE_CONF"
    printf '%s\n' "$want" | sudo tee "$NVIDIA_MODPROBE_CONF" >/dev/null
    return 0
}

# Without these the console flickers through a driverless modeset at boot.
_nvidia_initramfs_modules() {
    local m changed=1
    for m in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
        grep -qx "$m" /etc/initramfs-tools/modules 2>/dev/null && continue
        echo "$m" | sudo tee -a /etc/initramfs-tools/modules >/dev/null
        changed=0
    done
    return "$changed"
}

# nvidia-driver blacklists nouveau in modprobe.d already; also on the kernel
# command line, so it can't win the race from the initramfs.
_nvidia_grub_cmdline() {
    local add="modprobe.blacklist=nouveau nvidia-drm.modeset=1"
    [ -f /etc/default/grub ] || { warn "no /etc/default/grub — skipping the nouveau blacklist on the kernel command line"; return 1; }
    command -v update-grub >/dev/null 2>&1 || { warn "no update-grub — skipping the kernel command line change"; return 1; }
    grep -q 'modprobe.blacklist=nouveau' /etc/default/grub && return 1
    log "Blacklisting nouveau on the kernel command line"
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $add\"|" \
        /etc/default/grub
    sudo update-grub
    return 0
}

# local.conf is untracked: GBM_BACKEND=nvidia-drm on a card-less machine
# breaks rendering outright. Rewritten between markers so re-runs don't stack.
_nvidia_write_hypr_env() {
    local conf="$HOME/.config/hypr/conf.d/local.conf"
    local begin="# >>> nvidia (bootstrap.sh) >>>"
    local end="# <<< nvidia (bootstrap.sh) <<<"
    [ -f "$conf" ] || printf '%s\n' "# Machine-local Hyprland config. Not tracked in the dotfiles repo." > "$conf"

    local body
    if _nvidia_discrete_only; then
        body="$(cat <<'EOF'
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = GBM_BACKEND,nvidia-drm
EOF
)"
    else
        # Pointing GBM/GLX at the discrete card forces the whole session
        # onto it — hotter, slower, and on some laptops the panel stays dark.
        body="# Hybrid graphics: session renders on the integrated GPU on purpose.
# Put one app on the NVIDIA card with: prime-run <app>"
    fi

    local tmp; tmp="$(mktemp)"
    awk -v b="$begin" -v e="$end" '
        $0 == b { skip = 1 } { if (!skip) print } $0 == e { skip = 0 }
    ' "$conf" > "$tmp"
    printf '%s\n%s\n%s\n' "$begin" "$body" "$end" >> "$tmp"
    mv "$tmp" "$conf"
    log "Wrote the NVIDIA env block to $conf"
}

step_nvidia() {
    if ! _nvidia_present; then
        log "No NVIDIA GPU found, skipping"
        return 0
    fi
    log "NVIDIA GPU found: $(lspci -nn | grep -Ei 'vga compatible controller|3d controller' | grep '\[10de:' | sed 's/.*: //')"

    _nvidia_enable_nonfree

    log "Installing the NVIDIA driver"
    # linux-headers-amd64, not $(uname -r): tracks kernel upgrades, so dkms
    # still has headers after the next one.
    apt_install \
        nvidia-driver nvidia-kernel-dkms firmware-misc-nonfree \
        linux-headers-amd64 \
        libnvidia-egl-wayland1 libva-wayland2 nvidia-vaapi-driver

    local need_initramfs=1
    _nvidia_write_modprobe && need_initramfs=0
    _nvidia_initramfs_modules && need_initramfs=0
    if [ "$need_initramfs" = "0" ]; then
        log "Rebuilding the initramfs"
        sudo update-initramfs -u
    fi

    _nvidia_grub_cmdline || true

    # Shipped but not enabled; NVreg_PreserveVideoMemoryAllocations above has
    # nothing to hook into without them.
    local unit
    for unit in nvidia-suspend nvidia-resume nvidia-hibernate; do
        systemctl list-unit-files "$unit.service" >/dev/null 2>&1 \
            && sudo systemctl enable "$unit.service" >/dev/null 2>&1 || true
    done

    _nvidia_write_hypr_env

    warn "Reboot to switch from nouveau to the NVIDIA driver."
}
