import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Bar pill + Control Center toggle for scripts/.local/bin/idle-inhibit — the
// same script SUPER+I runs; just another way to reach it, not a second
// inhibitor.
//
// DMS's own idle-inhibitor toggle (IdleInhibitor.qml, SessionService.idle
// Inhibited) is left disabled: that flag has no D-Bus/systemd/Wayland
// registration, so it doesn't affect hypridle, which is what actually locks
// this session — see the README's "Idle inhibitor" section.
//
// Polls `idle-inhibit status` rather than tracking a local boolean, so it
// can't disagree with the real lock state (keybind, another bar, a terminal).
PluginComponent {
    id: root

    property bool inhibiting: false
    property bool busy: false

    function refresh() {
        Proc.runCommand(
            "idleInhibitToggle.status",
            ["idle-inhibit", "status"],
            (stdout) => { root.inhibiting = stdout.trim() === "on"; },
            50
        );
    }

    function toggle() {
        if (root.busy)
            return;
        root.busy = true;
        Proc.runCommand(
            "idleInhibitToggle.toggle",
            ["idle-inhibit", "toggle"],
            (stdout) => {
                root.inhibiting = stdout.trim() === "on";
                root.busy = false;
            },
            50
        );
    }

    Component.onCompleted: refresh()
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    readonly property string iconName: root.inhibiting ? "motion_sensor_active" : "motion_sensor_idle"

    horizontalBarPill: Component {
        Item {
            implicitWidth: icon.width
            implicitHeight: root.widgetThickness
            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: root.iconName
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: root.inhibiting ? Theme.primary : Theme.widgetTextColor
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: icon.height
            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: root.iconName
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: root.inhibiting ? Theme.primary : Theme.widgetTextColor
            }
        }
    }

    pillClickAction: () => root.toggle()

    // Control Center integration (ccWidgetIcon etc.) was tried and dropped —
    // it rendered as a bare "Unknown" tile instead of picking those up, and
    // debugging DMS's Control Center internals was out of scope. Bar-only.
}
