# shellcheck shell=bash
register_step desktop \
    --desc "Terminal, shell, screenshot/clipboard, network, Qt runtime, cursor" \
    --group desktop --root --needs backports \
    --provides kitty zsh stow grim slurp wl-copy fastfetch cava \
               /usr/share/icons/Bibata-Modern-Classic

step_desktop() {
    log "Installing terminal, shell, screenshot/clipboard, network tools"
    apt_install_backports \
        kitty zsh stow \
        grim slurp wl-clipboard \
        playerctl brightnessctl \
        fontconfig unzip curl git jq socat gnupg ca-certificates \
        imagemagick img2pdf tesseract-ocr zbar-tools \
        fastfetch cava \
        accountsservice qt6ct mesa-utils \
        network-manager network-manager-gnome \
        blueman bluez \
        bibata-cursor-theme

    gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic 2>/dev/null \
        || warn "Couldn't set the GTK cursor theme (no session bus?) — re-run this step from inside Hyprland"
}
