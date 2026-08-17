import Quickshell
import "modules" as Modules

ShellRoot {
    // One bar per connected monitor.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32
            color: "transparent"

            Modules.Bar {
                anchors.fill: parent
            }
        }
    }

    Modules.Launcher {}
    Modules.PowerMenu {}
    Modules.MonitorPicker {}
    Modules.KeyHints {}
}
