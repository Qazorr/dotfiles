import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

PanelWindow {
    id: root
    visible: false
    focusable: true
    anchors { top: true }
    margins.top: 80
    implicitWidth: 320
    implicitHeight: 76
    color: "transparent"

    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.visible = !root.visible }
    }

    function run(cmd) {
        Quickshell.execDetached(cmd);
        root.visible = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Colors.background
        border.color: Colors.surface
        border.width: 1
        focus: true
        Keys.onEscapePressed: root.visible = false

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            PowerMenuButton { label: "Lock"; textColor: Colors.foreground; onClicked: root.run(["hyprlock"]) }
            PowerMenuButton { label: "Logout"; textColor: Colors.foreground; onClicked: root.run(["hyprctl", "dispatch", "exit"]) }
            PowerMenuButton { label: "Reboot"; textColor: Colors.foreground; onClicked: root.run(["systemctl", "reboot"]) }
            PowerMenuButton { label: "Shutdown"; textColor: Colors.urgent; onClicked: root.run(["systemctl", "poweroff"]) }
        }
    }
}
