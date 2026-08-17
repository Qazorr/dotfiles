import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import "." as Modules
import "../theme"

Rectangle {
    id: bar
    color: Colors.background

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 12

        // --- Workspaces ---
        RowLayout {
            spacing: 4
            Repeater {
                model: Hyprland.workspaces
                delegate: Rectangle {
                    id: wsPill
                    required property var modelData
                    width: 24
                    height: 24
                    radius: 4
                    color: modelData.active ? Colors.accent : (hover.hovered ? Colors.surface : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: wsPill.modelData.id
                        color: wsPill.modelData.active ? Colors.background : Colors.foreground
                    }
                    HoverHandler { id: hover }
                    TapHandler { onTapped: Hyprland.dispatch("workspace " + wsPill.modelData.id) }
                }
            }
        }

        // --- Active window title ---
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            color: Colors.foreground
            text: Hyprland.activeToplevel?.title ?? ""
        }

        // --- Audio visualizer ---
        Modules.CavaViz {}

        // --- CPU / mem ---
        Modules.SysMonitor {}

        // --- System tray ---
        RowLayout {
            spacing: 4
            Repeater {
                model: SystemTray.items
                delegate: Rectangle {
                    id: trayItem
                    required property var modelData
                    width: 24
                    height: 24
                    radius: 4
                    color: hover.hovered ? Colors.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Image {
                        anchors.centerIn: parent
                        source: trayItem.modelData.icon
                        sourceSize: Qt.size(16, 16)
                    }
                    HoverHandler { id: hover }
                    ToolTip.text: trayItem.modelData.tooltipTitle || trayItem.modelData.title || ""
                    ToolTip.visible: hover.hovered && ToolTip.text.length > 0
                    ToolTip.delay: 400
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) trayItem.modelData.activate();
                            else trayItem.modelData.secondaryActivate();
                        }
                    }
                }
            }
        }

        // --- Clock ---
        Rectangle {
            id: clockPill
            Layout.preferredWidth: clockText.implicitWidth + 12
            Layout.preferredHeight: 24
            radius: 4
            color: clockHover.hovered ? Colors.surface : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: clockText
                anchors.centerIn: parent
                color: Colors.foreground
                text: Qt.formatDateTime(new Date(), "ddd d MMM  hh:mm")

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd d MMM  hh:mm")
                }
            }
            HoverHandler { id: clockHover }
            ToolTip.text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
            ToolTip.visible: clockHover.hovered
            ToolTip.delay: 400
        }
    }
}
