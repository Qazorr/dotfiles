# Part of bootstrap.sh — sourced by it, not meant to run standalone.
step_desktop() { # Terminal, shell, screenshot/clipboard, network, Qt runtime
    # -t trixie-backports here too. Note qt6-base-dev is NOT in backports at
    # all (it resolves from main either way) — the flag matters because it
    # keeps apt resolving consistently against backports before the quickshell
    # step pulls the newer libxkbcommon from there (see the note there).
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
