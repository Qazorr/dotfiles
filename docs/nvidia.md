# NVIDIA


`nvidia` is an `--optional` step: a plain `./bootstrap.sh` run skips it, so a
fresh install can't come up to a black screen over a driver problem. Run it
deliberately once you're ready to deal with it:

```
./bootstrap.sh nvidia
```

Detects the card via PCI vendor `10de` and no-ops without one. Sets
`nvidia-drm modeset=1`, blacklists nouveau (modprobe.d and the kernel command
line), rebuilds the initramfs and GRUB config. Reboot afterwards to actually
switch drivers.

### Choosing a driver

`./bootstrap.sh nvidia` asks once, up front — before sudo, before anything
installs — then the run is unattended like every other step:

```
Which NVIDIA driver?  (nvidia)
  1) Debian repo (nvidia-driver) — trails upstream, but what this machine already uses  (default)
  2) NVIDIA's own repo, open kernel modules — required on RTX 5000-series+
  3) NVIDIA's own repo, proprietary (cuda-drivers)
  4) Uninstall and revert to the in-kernel driver
>
```

| Choice | Package | Source | When |
|---|---|---|---|
| Debian repo (default) | `nvidia-driver` | Debian's own repo (`contrib`/`non-free`) | what this machine's GTX 1660 Ti uses; trails upstream on testing/unstable |
| Open kernel modules | `nvidia-open` | NVIDIA's own CUDA repo | **required** on RTX 5000-series and newer |
| Proprietary | `cuda-drivers` | NVIDIA's own CUDA repo | latest upstream release |
| Revert | — | — | uninstalls whatever's installed, reverts to the in-kernel driver |

Switching removes the previously-installed variant first (reverting included
— picking it after debian/open/nvidia purges the driver, un-blacklists
nouveau, and drops the GRUB/initramfs/Hyprland-env changes). Picking what's
already installed is close to a no-op: it re-checks modeset/blacklist/
initramfs state without reinstalling.

For a non-interactive run (CI, a second machine, `--yes`), set
`DOTFILES_NVIDIA_MODE=debian|open|nvidia|nouveau` beforehand and the prompt is
skipped — set, it wins; unset with no terminal to ask on (or under `--yes`),
it falls back to the default:

```
DOTFILES_NVIDIA_MODE=open ./bootstrap.sh nvidia
```

This is `register_option` (`lib/steps.sh`) — any step can declare a small set
of choices the same way; `resolve_step_options` (`lib/options.sh`) asks for
all of them together, right before sudo, for whatever ends up in the plan.

Follows JaKooLit's `Debian-Hyprland/install-scripts/nvidia.sh` for the
`debian` path; the driver choices and the NVIDIA CUDA repo plumbing follow
that project's successor,
[LinuxBeginnings/Debian-Hyprland](https://github.com/LinuxBeginnings/Debian-Hyprland)'s
newer `nvidia.sh` — asked up front here instead of interleaved with its own
install output, so it fits this repo's "every prompt happens before any step
runs" rule.

**Secure Boot check**, from the same newer script: an unsigned kernel module
can fail to load under Secure Boot, and with nouveau also blacklisted that's
**no** KMS driver at all — a black screen on every boot, not just software
rendering. The step warns up front if `mokutil --sb-state` reports Secure
Boot on. If you land on a black screen anyway: switch to a text console
(Ctrl+Alt+F3), log in, and run `./bootstrap.sh --doctor` — it tells apart
"just reboot" from "Secure Boot blocked the module" and gives the exact fix
(disable Secure Boot, or `sudo mokutil --disable-validation` + reboot + enrol
at the MOK prompt).

### Hybrid laptops

The NVIDIA Hyprland env goes in `~/.config/hypr/conf.d/local.conf` —
untracked, because `GBM_BACKEND=nvidia-drm` on a card-less machine breaks
rendering outright. `hyprland.conf` sources it last; `step_stow` creates an
empty one so that source always resolves.

- **Discrete only** — the full block: `LIBVA_DRIVER_NAME`,
  `__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND`, `GBM_BACKEND`.
- **Hybrid** (e.g. Renoir + GTX 1660 Ti) — none of them; the session stays on
  the iGPU, single apps go to the NVIDIA card with `prime-run blender`.

If Hyprland picks the wrong GPU to render on, `AQ_DRM_DEVICES` in
`local.conf` pins it to a specific `/dev/dri/by-path/...` node.

