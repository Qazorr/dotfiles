import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../theme"

// Charge level + charging state, polled from /sys/class/power_supply.
// sysfs rather than upower: no extra dependency (bootstrap.sh doesn't
// install upower), and it works identically under a locked session.
// Handles both energy_*/power_now (Wh) and charge_*/current_now (Ah)
// kernels — laptops differ on which pair they expose.
Rectangle {
    id: root

    property int percent: 0
    property string status: "Unknown"
    property real hoursLeft: -1

    readonly property bool charging: status === "Charging"
    readonly property bool full: status === "Full"
    // Hidden entirely on machines with no battery, so the same bar config
    // works unchanged on a desktop.
    readonly property bool present: percent > 0 || status !== "Unknown"

    visible: present
    Layout.preferredWidth: batText.implicitWidth + 10
    Layout.preferredHeight: 24
    radius: 4
    color: hover.hovered ? Colors.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: batText
        anchors.centerIn: parent
        text: root.full ? "FULL"
            : (root.charging ? "CHG " : "BAT ") + root.percent + "%"
        color: root.charging || root.full ? "#a6e3a1"
             : root.percent <= 15 ? Colors.urgent
             : root.percent <= 30 ? "#f9e2af"
             : Colors.foreground
    }

    HoverHandler { id: hover }
    ToolTip.delay: 400
    ToolTip.visible: hover.hovered
    ToolTip.text: {
        let t = "Battery " + root.percent + "% — " + root.status;
        if (root.hoursLeft > 0) {
            const h = Math.floor(root.hoursLeft);
            const m = Math.round((root.hoursLeft - h) * 60);
            t += "\n" + (root.charging ? "Until full: " : "Remaining: ")
               + h + "h " + m + "m";
        }
        return t;
    }

    Process {
        id: sampler
        command: ["sh", "-c",
            'for b in /sys/class/power_supply/BAT*; do ' +
            '[ -d "$b" ] || continue; ' +
            'cat "$b/capacity" 2>/dev/null || echo 0; ' +
            'cat "$b/status" 2>/dev/null || echo Unknown; ' +
            'if [ -r "$b/energy_now" ]; then ' +
            'cat "$b/energy_now"; cat "$b/energy_full"; ' +
            'cat "$b/power_now" 2>/dev/null || echo 0; ' +
            'elif [ -r "$b/charge_now" ]; then ' +
            'cat "$b/charge_now"; cat "$b/charge_full"; ' +
            'cat "$b/current_now" 2>/dev/null || echo 0; ' +
            'else echo 0; echo 0; echo 0; fi; ' +
            'break; done'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 5) return;
                root.percent = parseInt(l[0]) || 0;
                root.status  = l[1] || "Unknown";
                const now  = parseFloat(l[2]) || 0;
                const cap  = parseFloat(l[3]) || 0;
                const rate = parseFloat(l[4]) || 0;
                // rate == 0 while idle/full — no meaningful estimate then.
                root.hoursLeft = rate > 0
                    ? (root.charging ? (cap - now) / rate : now / rate)
                    : -1;
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }
}
