import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../theme"

// Backlight level via brightnessctl (installed by bootstrap.sh, and already
// driven by the XF86MonBrightness* binds). `-m` gives machine-readable
// output: "amdgpu_bl1,backlight,128,50%,255" — field 4 is the percentage.
// Scroll to adjust.
Rectangle {
    id: root

    property int percent: -1
    // Hidden on hardware with no backlight class (desktops, external-only
    // setups) rather than showing a permanently-zero readout.
    readonly property bool present: percent >= 0

    visible: present
    Layout.preferredWidth: brText.implicitWidth + 10
    Layout.preferredHeight: 24
    radius: 4
    color: hover.hovered ? Colors.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: brText
        anchors.centerIn: parent
        text: "BRT " + root.percent + "%"
        color: "#fab387"
    }

    HoverHandler { id: hover }
    ToolTip.delay: 400
    ToolTip.visible: hover.hovered
    ToolTip.text: "Brightness: " + root.percent + "%\nScroll to adjust"

    WheelHandler {
        onWheel: event => {
            // See Volume.qml: don't re-command a Process that's still running.
            if (setter.running) return;
            setter.command = ["sh", "-c", event.angleDelta.y > 0
                ? "brightnessctl set 5%+"
                : "brightnessctl set 5%-"];
            setter.running = true;
        }
    }

    Process {
        id: setter
        onExited: sampler.running = true
    }

    Process {
        id: sampler
        command: ["sh", "-c",
            'v=$(brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4 | tr -d "%"); ' +
            'echo "${v:--1}"']
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                root.percent = isNaN(v) ? -1 : v;
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }
}
