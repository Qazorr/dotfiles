import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../theme"

// Connectivity via nmcli (NetworkManager is installed + enabled by
// bootstrap.sh). Shows wifi SSID with signal strength, or a plain wired
// indicator for ethernet. Click opens nm-connection-editor — the same
// editor SUPER+ALT+N is bound to.
Rectangle {
    id: root

    property string kind: "none"     // wifi | ethernet | none
    property string label: "-"       // connection name / SSID
    property int signalPct: 0

    readonly property bool online: kind !== "none"

    Layout.preferredWidth: netText.implicitWidth + 10
    Layout.preferredHeight: 24
    radius: 4
    color: hover.hovered ? Colors.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: netText
        anchors.centerIn: parent
        text: root.kind === "wifi" ? "WIFI " + root.signalPct + "%"
            : root.kind === "ethernet" ? "ETH"
            : "OFFLINE"
        color: !root.online ? Colors.urgent
             : root.kind === "wifi" && root.signalPct < 35 ? "#f9e2af"
             : "#94e2d5"
    }

    HoverHandler { id: hover }
    ToolTip.delay: 400
    ToolTip.visible: hover.hovered
    ToolTip.text: !root.online
        ? "No active connection\nClick to open network settings"
        : (root.kind === "wifi"
            ? "Wi-Fi: " + root.label + "\nSignal: " + root.signalPct + "%"
            : "Wired: " + root.label)
          + "\nClick to open network settings"

    TapHandler {
        onTapped: {
            opener.running = true;
        }
    }

    Process {
        id: opener
        command: ["nm-connection-editor"]
    }

    Process {
        id: sampler
        // Line 1: device type, line 2: connection name, line 3: wifi signal.
        // grep -E "^[^:]+:connected" avoids matching the "disconnected"
        // state, which a bare ":connected" substring test would not.
        command: ["sh", "-c",
            't=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null ' +
            '| grep -E "^[^:]+:connected" | head -1); ' +
            'if [ -n "$t" ]; then echo "$t" | cut -d: -f1; echo "$t" | cut -d: -f3; ' +
            'else echo none; echo "-"; fi; ' +
            'sig=$(nmcli -t -f IN-USE,SIGNAL device wifi 2>/dev/null ' +
            '| grep "^\\*" | head -1 | cut -d: -f2); echo "${sig:-0}"'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 3) return;
                root.kind = l[0] === "802-3-ethernet" || l[0] === "ethernet"
                    ? "ethernet"
                    : (l[0] === "wifi" ? "wifi" : "none");
                root.label = l[1] || "-";
                root.signalPct = parseInt(l[2]) || 0;
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
