import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

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

}
