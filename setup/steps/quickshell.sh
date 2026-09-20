# shellcheck shell=bash
# DMS runs on Quickshell, which Debian proper doesn't package; backports does.
register_step quickshell \
    --desc "Quickshell (DMS runs on it)" \
    --group desktop --root --needs prereqs backports danklinux \
    --provides qs /usr/lib/x86_64-linux-gnu/qt6/qml/QtQuick/Effects

step_quickshell() {
    # Quickshell must come from backports, but backports is NotAutomatic
    # (priority 100) while the OBS repo gets the default 500 — without this pin
    # the next `apt upgrade` silently swaps in the deprecated build.
    log "Pinning quickshell to Debian's build"
    sudo tee /etc/apt/preferences.d/quickshell-from-debian >/dev/null <<'EOF'
Package: quickshell
Pin: release o=Debian
Pin-Priority: 990
EOF

    log "Installing Quickshell and DMS's QML runtime"
    # The qml6-module-* list is DMS's QML runtime, which the quickshell package
    # doesn't depend on. One missing module fails the whole shell: QtQuick.Effects
    # alone takes qs.Common/Services/Widgets down, so the bar and dms-greeter
    # both exit instantly.
    apt_install_backports quickshell \
        qml6-module-qtmultimedia qml6-module-qtcore qml6-module-qtqml \
        qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
        qml6-module-qtquick-window \
        qml6-module-qtquick-effects qml6-module-qtquick-shapes \
        qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qt5compat-graphicaleffects
}
