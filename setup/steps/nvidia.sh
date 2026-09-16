# shellcheck shell=bash
# Follows JaKooLit's Debian-Hyprland install-scripts/nvidia.sh, plus the
# driver-variant selection from its successor, LinuxBeginnings/Debian-Hyprland.
# --optional so a fresh install can't black-screen on it unattended; run by
# name when ready.
register_step nvidia \
    --desc "NVIDIA driver — asks which one (opt-in: ./bootstrap.sh nvidia)" \
    --group desktop --root --optional --needs prereqs
# No --provides: succeeds on a card-less machine, and --provides nvidia-smi
# would then have --doctor call it "recorded as done but not installed".

NVIDIA_MODPROBE_CONF=/etc/modprobe.d/zz-dotfiles-nvidia.conf
NVIDIA_APT_LIST=/etc/apt/sources.list.d/debian-nonfree.list
# NVIDIA's own CUDA apt repo, for the open/nvidia modes — Debian has no
# packaged nvidia-open, and its nvidia-driver trails upstream.
NVIDIA_CUDA_SUITE=debian13
NVIDIA_CUDA_KEYRING_VERSION=1.1-1
NVIDIA_MODE_DEFAULT=debian

# Asked once, up front, alongside every step's options — see register_option
# in lib/steps.sh. DOTFILES_NVIDIA_MODE set beforehand (CI, --yes) skips it.
register_option nvidia DOTFILES_NVIDIA_MODE \
    --prompt "Which NVIDIA driver?" \
    --choices \
        "debian:Debian repo (nvidia-driver) — trails upstream, but what this machine already uses" \
        "open:NVIDIA's own repo, open kernel modules — required on RTX 5000-series+" \
        "nvidia:NVIDIA's own repo, proprietary (cuda-drivers)" \
        "nouveau:Uninstall and revert to the in-kernel driver" \
    --default "$NVIDIA_MODE_DEFAULT"

# 10de is NVIDIA's PCI vendor ID.
_nvidia_present() {
    lspci -nn 2>/dev/null | grep -Ei 'vga compatible controller|3d controller' \
        | grep -q '\[10de:'
}

_nvidia_mode() {
    local m="${DOTFILES_NVIDIA_MODE:-$NVIDIA_MODE_DEFAULT}"
    case "$m" in
        debian|open|nvidia|nouveau) printf '%s' "$m" ;;
        *) die "DOTFILES_NVIDIA_MODE must be debian, open, nvidia or nouveau (got '$m')" ;;
    esac
}

# Which variant, if any, is currently installed — so switching modes removes
# the right packages first, and re-running the same mode is a no-op.
_nvidia_installed_variant() {
    dpkg -s nvidia-open   >/dev/null 2>&1 && { echo open; return; }
    dpkg -s cuda-drivers  >/dev/null 2>&1 && { echo nvidia; return; }
    dpkg -s nvidia-driver >/dev/null 2>&1 && { echo debian; return; }
    echo nouveau
}

_nvidia_purge_variant() {
    case "$1" in
        debian) apt_purge nvidia-driver nvidia-kernel-dkms \
                    libnvidia-egl-wayland1 libva-wayland2 nvidia-vaapi-driver ;;
        open)   apt_purge nvidia-open ;;
        nvidia) apt_purge cuda-drivers ;;
    esac
}

# 0 = Secure Boot on, 1 = off, 2 = mokutil couldn't tell (not installed yet).
# An unsigned kernel module under Secure Boot leaves nouveau blacklisted AND
# nvidia not loaded — no KMS driver at all, not just a slow one. Borrowed
# from LinuxBeginnings/Debian-Hyprland's nvidia.sh, which warns about this.
_nvidia_secureboot_enabled() {
    command -v mokutil >/dev/null 2>&1 || return 2
    mokutil --sb-state 2>/dev/null | grep -qi enabled
}

# A hybrid laptop needs a different Hyprland env — see _nvidia_write_hypr_env.
_nvidia_discrete_only() {
    local others
    others="$(lspci -nn 2>/dev/null | grep -Ei 'vga compatible controller|3d controller' \
        | grep -vc '\[10de:' || true)"
    [ "${others:-0}" -eq 0 ]
}

# Separate file, not a rewrite of sources.list; no non-free-firmware, or apt
# warns about a component configured twice. debian mode only — the CUDA repo
# ships its own packages, no Debian component needed.
_nvidia_enable_nonfree() {
    [ -f "$NVIDIA_APT_LIST" ] && return 0
    log "Enabling contrib + non-free (nvidia-driver lives in non-free)"
    local codename; codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    sudo tee "$NVIDIA_APT_LIST" >/dev/null <<EOF
deb http://deb.debian.org/debian $codename contrib non-free
deb http://deb.debian.org/debian $codename-updates contrib non-free
deb http://security.debian.org/debian-security $codename-security contrib non-free
EOF
    apt_update
}

# open/nvidia modes only. Same method NVIDIA's own install instructions use:
# the keyring .deb also drops the repo's sources.list.d entry.
_nvidia_enable_cuda_repo() {
    dpkg -s cuda-keyring >/dev/null 2>&1 && return 0
    log "Adding NVIDIA's CUDA apt repo ($NVIDIA_CUDA_SUITE)"
    local tmp; tmp="$(mktemp)"
    curl -fsSL -o "$tmp" \
        "https://developer.download.nvidia.com/compute/cuda/repos/$NVIDIA_CUDA_SUITE/x86_64/cuda-keyring_${NVIDIA_CUDA_KEYRING_VERSION}_all.deb"
    sudo dpkg -i "$tmp"
    rm -f "$tmp"
    apt_update
}

_nvidia_write_modprobe() {
    local want
    want="$(cat <<'EOF'
# Written by dotfiles bootstrap.sh (step_nvidia).
# modeset=1: required for the driver to work under Wayland at all.
options nvidia-drm modeset=1 fbdev=1
# Keeps VRAM across suspend; needs the suspend/resume/hibernate units below.
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

# Drop the env block entirely rather than leave the hybrid-graphics comment
# behind — once nothing's installed, there's no GPU choice to explain.
_nvidia_remove_hypr_env() {
    local conf="$HOME/.config/hypr/conf.d/local.conf"
    [ -f "$conf" ] || return 0
    local tmp; tmp="$(mktemp)"
    awk '
        /^# >>> nvidia \(bootstrap\.sh\) >>>$/ { skip = 1 }
        !skip { print }
        /^# <<< nvidia \(bootstrap\.sh\) <<<$/ { skip = 0 }
    ' "$conf" > "$tmp"
    mv "$tmp" "$conf"
}

# DOTFILES_NVIDIA_MODE=nouveau: undo the above, back to the in-kernel driver.
# Doesn't touch the CUDA repo/keyring if one was added — harmless to leave,
# and removing it risks a half-broken apt state for no benefit.
_nvidia_revert_to_nouveau() {
    local current="$1"
    if [ "$current" = "nouveau" ]; then
        log "Already on nouveau (no NVIDIA driver installed) — nothing to revert"
        return 0
    fi
    log "Reverting to nouveau: removing the $current driver"
    _nvidia_purge_variant "$current"

    [ -f "$NVIDIA_MODPROBE_CONF" ] && { log "Removing $NVIDIA_MODPROBE_CONF"; sudo rm -f "$NVIDIA_MODPROBE_CONF"; }

    if [ -f /etc/default/grub ] && grep -q 'modprobe.blacklist=nouveau' /etc/default/grub; then
        log "Un-blacklisting nouveau on the kernel command line"
        sudo sed -i -E 's/ ?modprobe\.blacklist=nouveau nvidia-drm\.modeset=1//' /etc/default/grub
        command -v update-grub >/dev/null 2>&1 && sudo update-grub
    fi

    if [ -f /etc/initramfs-tools/modules ] && grep -qx nvidia /etc/initramfs-tools/modules; then
        log "Removing NVIDIA modules from the initramfs"
        sudo sed -i -E '/^(nvidia|nvidia_modeset|nvidia_uvm|nvidia_drm)$/d' /etc/initramfs-tools/modules
        sudo update-initramfs -u
    fi

    _nvidia_remove_hypr_env
    warn "Reboot to actually switch back to nouveau."
}

step_nvidia() {
    if ! _nvidia_present; then
        log "No NVIDIA GPU found, skipping"
        return 0
    fi
    log "NVIDIA GPU found: $(lspci -nn | grep -Ei 'vga compatible controller|3d controller' | grep '\[10de:' | sed 's/.*: //')"

    local mode; mode="$(_nvidia_mode)"
    local current; current="$(_nvidia_installed_variant)"

    if [ "$mode" = "nouveau" ]; then
        _nvidia_revert_to_nouveau "$current"
        return 0
    fi

    if [ "$current" != "nouveau" ] && [ "$current" != "$mode" ]; then
        log "Switching NVIDIA driver: $current -> $mode"
        _nvidia_purge_variant "$current"
    fi

    apt_install mokutil    # needed for the Secure Boot check, and by --doctor later
    local sb_rc=0
    _nvidia_secureboot_enabled || sb_rc=$?
    if [ "$sb_rc" = "0" ]; then
        warn "Secure Boot is ON. An unsigned NVIDIA kernel module can fail to load after reboot — with nouveau blacklisted too, that's no KMS driver at all (black screen, not just software rendering). Either disable Secure Boot in firmware setup, or enrol a MOK first: sudo mokutil --disable-validation, reboot, enrol at the blue MOK Manager prompt, reboot again — then re-run this step."
    fi

    # linux-headers-amd64, not $(uname -r): tracks kernel upgrades, so dkms
    # still has headers after the next one. Needed for all three variants —
    # nvidia-open is DKMS-built too.
    apt_install linux-headers-amd64

    case "$mode" in
        debian)
            _nvidia_enable_nonfree
            log "Installing the NVIDIA driver (Debian repo)"
            apt_install nvidia-driver nvidia-kernel-dkms firmware-misc-nonfree \
                libnvidia-egl-wayland1 libva-wayland2 nvidia-vaapi-driver
            ;;
        open)
            _nvidia_enable_cuda_repo
            log "Installing the NVIDIA driver (open kernel modules, NVIDIA's CUDA repo)"
            apt_install nvidia-open
            ;;
        nvidia)
            _nvidia_enable_cuda_repo
            log "Installing the NVIDIA driver (proprietary, NVIDIA's CUDA repo)"
            apt_install cuda-drivers
            ;;
    esac

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

    warn "Reboot to switch from nouveau to the NVIDIA driver ($mode). If you land on a black screen: switch to a text console (Ctrl+Alt+F3), log in, and run ./bootstrap.sh --doctor — it checks whether the module actually loaded and, if not, whether Secure Boot is why."
}
