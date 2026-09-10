register_step desktop \
    --desc "Terminal, shell, screenshot/clipboard, network, Qt runtime" \
    --group desktop --root --needs backports \
    --provides kitty zsh stow grim slurp wl-copy fastfetch cava

step_desktop() {
    # -t trixie-backports keeps apt resolving consistently against backports
    # before the quickshell step pulls the newer libxkbcommon from there.
    log "Installing terminal, shell, screenshot/clipboard, network tools"
    apt_install_backports \
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
