import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Bar pill + Control Center toggle for scripts/.local/bin/idle-inhibit.
// Same script SUPER+I runs (hypr/conf.d/keybindings.conf) — this widget is
// just another way to reach it, not a second inhibitor mechanism.
//
// DMS ships its own native idle-inhibitor widget/toggle
// (Modules/DankBar/Widgets/IdleInhibitor.qml, SessionService.idleInhibited).
// It's left disabled on purpose: that flag has no D-Bus, systemd, or
// Wayland-protocol registration at all, so it does not affect hypridle —
// which is what's actually locking this session. See idle-inhibit's own
// header comment and the dotfiles README for how that was verified.
//
// Polls `idle-inhibit status` rather than tracking its own local boolean, so
// it stays correct if toggled elsewhere (the keybind, another monitor's bar,
// a terminal) — it can never show a state the real inhibitor lock disagrees
// with.
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

    // Control Center integration (ccWidgetIcon/ccWidgetPrimaryText/etc) was
    // tried and dropped: it rendered as a bare "Unknown" tile with a
    // question-mark icon rather than picking up these properties, and
    // debugging DMS's Control Center widget internals further was out of
    // scope for what was asked (a bar toggle). Bar-only for now.
}
