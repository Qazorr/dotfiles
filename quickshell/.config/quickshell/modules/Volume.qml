import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../theme"

// Default sink volume + mute state via wpctl (WirePlumber, Debian's default
// audio stack — same tool the XF86Audio* binds in keybindings.conf use, so
// the bar and the media keys can't disagree about what "volume" means).
// Scroll to adjust, click to toggle mute.
Rectangle {
    id: root

    property int percent: 0
    property bool muted: false

    Layout.preferredWidth: volText.implicitWidth + 10
    Layout.preferredHeight: 24
    radius: 4
    color: hover.hovered ? Colors.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: volText
        anchors.centerIn: parent
        text: root.muted ? "VOL mute" : "VOL " + root.percent + "%"
        color: root.muted ? Colors.urgent : "#89dceb"
    }

    HoverHandler { id: hover }
    ToolTip.delay: 400
    ToolTip.visible: hover.hovered
    ToolTip.text: (root.muted ? "Muted" : "Volume: " + root.percent + "%")
                + "\nScroll to adjust · click to toggle mute"

    TapHandler {
        onTapped: root.apply("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    }

    WheelHandler {
        onWheel: event => {
            // -l 1.5 on the way up mirrors the keybind: allows boost past
            // 100% but caps it, so a stray scroll can't blow out the sink.
            root.apply(event.angleDelta.y > 0
                ? "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
                : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-");
        }
    }

    // Run a wpctl mutation, then immediately re-poll so the readout doesn't
    // wait up to a full poll interval to catch up.
    function apply(cmd) {
        // Changing command on a still-running Process is an error in
        // Quickshell; a fast scroll can outpace wpctl, so drop the extra
        // step rather than tearing down the in-flight one.
        if (setter.running) return;
        setter.command = ["sh", "-c", cmd];
        setter.running = true;
    }

    Process {
        id: setter
        onExited: sampler.running = true
    }

    Process {
        id: sampler
        // "Volume: 0.45" or "Volume: 0.45 [MUTED]"
        command: ["sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 0.00'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s*([0-9.]+)/);
                if (m) root.percent = Math.round(parseFloat(m[1]) * 100);
                root.muted = text.indexOf("[MUTED]") !== -1;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }
}
