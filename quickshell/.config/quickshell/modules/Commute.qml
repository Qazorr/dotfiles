import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

// Live Kraków tram+bus commute countdown.
//
// The backend (krk-commute, its own project) runs as a systemd --user daemon
// that polls ZTP Kraków's GTFS-Realtime feeds and writes a cache file. This
// widget only ever shells out to `krk-commute show --json`, which reads that
// cache and never touches the network — that's what makes it safe to call
// from a Timer in the bar without janking it.
//
// Click opens the detail panel (CommutePanel.qml) through the same
// `qs ipc call <target> toggle` mechanism the keybind-driven pickers use.
RowLayout {
    id: root
    spacing: 4

    // Path to the krk-commute executable. Set this to wherever the backend
    // is installed — it is deliberately not part of this repo.
    property string binary: Quickshell.env("HOME") + "/Projects/krk-commute/.venv/bin/krk-commute"
    // Which chain drives the compact label: "work" (leaving work) or "home".
    property string direction: "work"
    property int refreshIntervalMs: 20000
    // How clicking the pill opens CommutePanel. The default addresses the
    // only running instance, which is all a normal session has; override it
    // to target a specific instance (`qs ipc -p <config> ...`) when running
    // a second Quickshell alongside another shell, e.g. to test this widget.
    property var toggleCommand: ["qs", "ipc", "call", "commute", "toggle"]

    property var chain: null
    property bool failed: false
    // True between kicking off a poll and getting an answer of any kind.
    property bool pending: false

    function refresh() {
        if (proc.running) return;
        pending = true;
        proc.running = true;
    }

    // A backend that is missing or cannot start produces no stdout at all,
    // so StdioCollector.onStreamFinished never fires for it. Without this
    // the widget would sit on its placeholder forever rather than saying
    // something is wrong.
    function settle() {
        if (!pending) return;
        pending = false;
        failed = true;
        chain = null;
    }

    // Font Awesome codepoints from the Nerd Font bootstrap.sh installs.
    readonly property string trainIcon: "\uf238"   // fa-train (rail glyph, used for tram 50)
    readonly property string busIcon: "\uf207"     // fa-bus
    readonly property string warningIcon: "\uf071" // fa-exclamation-triangle

    // Tram is always line 50 in this fixed commute; anything else is a bus.
    function iconFor(route) { return route === "50" ? trainIcon : busIcon; }

    function fmtMin(m) {
        if (m === null || m === undefined) return "?";
        const r = Math.round(m);
        return r <= 0 ? "now" : (r + "m");
    }

    function statusLabel(status) {
        switch (status) {
        case "no_data": return "no data yet — is krk-commute.service running?";
        case "stale": return "cached data is stale — backend stopped updating";
        case "unresolved": return "route/stop not resolved — run `krk-commute resolve`";
        case "no_first_leg": return "no upcoming departure found";
        case "no_arrival_estimate": return "no arrival estimate for the first leg";
        case "no_connecting_departure": return "no connecting departure in range";
        default: return status || "";
        }
    }

    readonly property string label: {
        // Three distinct non-departure states, so the bar does not show the
        // same shrug for "broken", "nothing running" and "still starting up".
        if (failed) return warningIcon;
        if (!chain) return trainIcon + " …";
        if (!chain.first) return trainIcon + " –";
        let t = iconFor(chain.first.route) + " " + chain.first.route + " " + fmtMin(chain.first.minutes);
        if (chain.second) {
            t += "  →  " + iconFor(chain.second.route) + " " + chain.second.route + " +" + fmtMin(chain.wait_minutes);
        } else {
            // Known "nothing connects", not "unknown" -- the panel spells
            // out which of the no-connection statuses it is.
            t += "  →  –";
        }
        return t;
    }

    readonly property string tip: {
        if (failed) return "Kraków commute: backend unavailable\n" + root.binary;
        if (!chain) return "Kraków commute: waiting for data";
        if (!chain.first) return "Kraków commute: " + statusLabel(chain.status);
        let t = chain.first.route + " (" + chain.first.headsign + ") departs in "
            + fmtMin(chain.first.minutes) + " [" + chain.first.source + "]";
        if (chain.second) {
            t += "\nthen " + chain.second.route + " (" + chain.second.headsign + ") — wait "
                + fmtMin(chain.wait_minutes) + " at the transfer [" + chain.second.source + "]";
        } else {
            t += "\n" + statusLabel(chain.status);
        }
        return t;
    }

    Rectangle {
        Layout.preferredWidth: labelText.implicitWidth + 12
        Layout.preferredHeight: 24
        radius: 4
        color: hover.hovered ? Colors.surface : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: labelText
            anchors.centerIn: parent
            color: root.chain && root.chain.first && root.chain.first.minutes <= 2
                ? Colors.urgent : Colors.foreground
            text: root.label
        }

        HoverHandler { id: hover }
        ToolTip.text: root.tip
        ToolTip.visible: hover.hovered && ToolTip.text.length > 0
        ToolTip.delay: 400
        TapHandler {
            onTapped: Quickshell.execDetached(root.toggleCommand)
        }
    }

    Process {
        id: proc
        command: [root.binary, "show", "--direction", root.direction, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.chain = JSON.parse(text);
                    root.failed = false;
                } catch (e) {
                    console.warn("Commute.qml: failed to parse krk-commute output:", e);
                    root.chain = null;
                    root.failed = true;
                }
                root.pending = false;
            }
        }
        // Deferred a turn so a stream that finishes after the process exits
        // still wins over the failure path.
        onRunningChanged: if (!proc.running) Qt.callLater(root.settle)
    }

    Timer {
        interval: root.refreshIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
