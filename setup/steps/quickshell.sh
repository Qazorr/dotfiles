# shellcheck shell=bash
# DMS runs on Quickshell, which Debian doesn't package. DankLinux's repo has
# the identical upstream version, so it's an apt install rather than the
# 10-20 minute, ~8GB Qt source build this step used to do.
register_step quickshell \
    --desc "Quickshell (DMS runs on it)" \
    --group desktop --root --needs prereqs backports danklinux \
    --provides qs /usr/lib/x86_64-linux-gnu/qt6/qml/QtQuick/Effects

step_quickshell() {
    # The qml6-module-* list is DMS's QML runtime, which the quickshell
    # package doesn't depend on. One missing module fails the whole shell:
    # QtQuick.Effects alone takes qs.Common/Services/Widgets down with it
    # ("module not installed"), so the bar and dms-greeter both exit instantly.
    # Upstream deprecated the DankLinux OBS quickshell for Debian: it must come
    # from backports. But backports is NotAutomatic (priority 100) while the OBS
    # repo gets the default 500, so without this pin the next `apt upgrade`
    # silently swaps in the deprecated build.
    log "Pinning quickshell to Debian's build"
    sudo tee /etc/apt/preferences.d/quickshell-from-debian >/dev/null <<'EOF'
Package: quickshell
Pin: release o=Debian
Pin-Priority: 990
EOF

    log "Installing Quickshell and DMS's QML runtime"
    apt_install_backports quickshell \
        qml6-module-qtmultimedia qml6-module-qtcore qml6-module-qtqml \
        qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
        qml6-module-qtquick-window \
        qml6-module-qtquick-effects qml6-module-qtquick-shapes \
        qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qt5compat-graphicaleffects
}
