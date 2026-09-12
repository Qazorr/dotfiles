# shellcheck shell=bash
register_step desktop \
    --desc "Terminal, shell, screenshot/clipboard, network, Qt runtime" \
    --group desktop --root --needs backports \
    --provides kitty zsh stow grim slurp wl-copy fastfetch cava

step_desktop() {
    # -t trixie-backports throughout: Hyprland comes from there and pulls a
    # newer libxkbcommon, so resolving these against main too would conflict.
    #
    log "Installing terminal, shell, screenshot/clipboard, network tools"
    apt_install_backports \
        kitty zsh stow \
        grim slurp wl-clipboard \
        playerctl brightnessctl \
        fontconfig unzip curl git jq gnupg ca-certificates \
        imagemagick img2pdf tesseract-ocr zbar-tools \
        fastfetch cava \
        accountsservice qt6ct mesa-utils \
        network-manager network-manager-gnome \
        blueman bluez
}
