register_step quickshell \
    --desc "Quickshell (DMS runs on it)" \
    --group desktop --root --needs prereqs backports danklinux \
    --provides qs /usr/lib/x86_64-linux-gnu/qt6/qml/QtQuick/Effects

step_quickshell() {
    # Backports is priority 100 and the OBS repo 500; unpinned, the next upgrade
    # swaps in OBS's deprecated build.
    log "Pinning quickshell to Debian's build"
    sudo tee /etc/apt/preferences.d/quickshell-from-debian >/dev/null <<'EOF'
Package: quickshell
Pin: release o=Debian
Pin-Priority: 990
EOF

    log "Installing Quickshell and DMS's QML runtime"
    # DMS's QML runtime; one missing module and the bar and dms-greeter exit
    # instantly.
    apt_install_backports quickshell \
        qml6-module-qtmultimedia qml6-module-qtcore qml6-module-qtqml \
        qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
        qml6-module-qtquick-window \
        qml6-module-qtquick-effects qml6-module-qtquick-shapes \
        qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qt5compat-graphicaleffects
}
