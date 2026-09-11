register_step desktop \
    --desc "Terminal, shell, screenshot/clipboard, network, Qt runtime" \
    --group desktop --root --needs backports \
    --provides kitty zsh stow grim slurp wl-copy fastfetch cava

step_desktop() {
    # -t trixie-backports throughout: Hyprland comes from there and pulls a
    # newer libxkbcommon, so resolving these against main too would conflict.
    #
    # The qml6-module-* list is DMS's QML runtime, which the apt quickshell
    # package doesn't depend on. One missing module fails the whole shell:
    # QtQuick.Effects alone takes qs.Common/Services/Widgets down with it
    # ("module not installed"), so the bar and dms-greeter both exit instantly.
    log "Installing terminal, shell, screenshot/clipboard, network tools"
    apt_install_backports \
        kitty zsh stow \
        grim slurp wl-clipboard \
        playerctl brightnessctl \
        fontconfig unzip curl git jq gnupg ca-certificates \
        imagemagick img2pdf tesseract-ocr zbar-tools \
        fastfetch cava \
        accountsservice qt6ct mesa-utils \
        qml6-module-qtmultimedia qml6-module-qtcore qml6-module-qtqml \
        qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
        qml6-module-qtquick-window \
        qml6-module-qtquick-effects qml6-module-qtquick-shapes \
        qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qt5compat-graphicaleffects \
        network-manager network-manager-gnome \
        blueman bluez
}
