import QtQuick
import QtQuick.Layouts
import "../theme"

// One direction of the commute ("Leaving work" / "Leaving home"): the
// chained headline, the clock-time detail for each leg, and a collapsible
// list of the other trams/buses on both legs.
ColumnLayout {
    id: root
    spacing: 4

    property string title: ""
    property var chain: null
    property bool expanded: false

    readonly property color muted: Qt.darker(Colors.foreground, 1.4)

    function fmtMin(m) {
        if (m === null || m === undefined) return "?";
        const r = Math.round(m);
        return r <= 0 ? "now" : (r + "m");
    }

    function fmtClock(epoch) {
        if (epoch === null || epoch === undefined) return "?";
        return Qt.formatDateTime(new Date(epoch * 1000), "hh:mm");
    }

    function iconFor(route) { return route === "50" ? "\uf238" : "\uf207"; }

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

    Text {
        Layout.fillWidth: true
        color: Colors.accent2
        font.pixelSize: 12
        font.bold: true
        text: root.title
    }

    // Shown instead of the headline when there is nothing to chain yet.
    Text {
        Layout.fillWidth: true
        visible: !root.chain || !root.chain.first
        wrapMode: Text.WordWrap
        color: root.muted
        text: root.chain ? root.statusLabel(root.chain.status) : "loading…"
    }

    // Headline: first leg, then the wait for the connection.
    RowLayout {
        visible: !!(root.chain && root.chain.first)
        spacing: 8

        Text {
            font.pixelSize: 17
            font.bold: true
            color: root.chain && root.chain.first && root.chain.first.minutes <= 2
                ? Colors.urgent : Colors.foreground
            text: root.chain && root.chain.first
                ? root.iconFor(root.chain.first.route) + " " + root.chain.first.route
                    + " " + root.fmtMin(root.chain.first.minutes)
                : ""
        }

        Text {
            visible: !!(root.chain && root.chain.second)
            font.pixelSize: 17
            color: root.muted
            text: "→"
        }

        Text {
            visible: !!(root.chain && root.chain.second)
            font.pixelSize: 17
            font.bold: true
            color: Colors.foreground
            text: root.chain && root.chain.second
                ? root.iconFor(root.chain.second.route) + " " + root.chain.second.route
                    + " +" + root.fmtMin(root.chain.wait_minutes)
                : ""
        }
    }

    // One line per leg rather than one wrapped run-on sentence, so it is
    // obvious which clock times belong to which vehicle.
    Text {
        Layout.fillWidth: true
        visible: !!(root.chain && root.chain.first)
        wrapMode: Text.WordWrap
        color: root.muted
        font.pixelSize: 12
        text: {
            if (!root.chain || !root.chain.first) return "";
            const f = root.chain.first;
            let t = root.fmtClock(f.epoch) + " " + f.headsign + " [" + f.source + "]";
            if (f.arrival_epoch !== null && f.arrival_epoch !== undefined) {
                t += "  ·  arrive hub " + root.fmtClock(f.arrival_epoch)
                    + " [" + (f.arrival_source || "?") + "]";
            }
            return t;
        }
    }

    Text {
        visible: !!(root.chain && root.chain.second)
        color: root.muted
        font.pixelSize: 12
        text: "   ↓ then"
    }

    Text {
        Layout.fillWidth: true
        visible: !!(root.chain && root.chain.first)
        wrapMode: Text.WordWrap
        color: root.muted
        font.pixelSize: 12
        text: {
            if (!root.chain) return "";
            if (root.chain.second) {
                const s = root.chain.second;
                return root.fmtClock(s.epoch) + " " + s.headsign + " [" + s.source + "]";
            }
            return root.chain.first ? root.statusLabel(root.chain.status) : "";
        }
    }

    // Collapsed by default: the common case is a glance at the next
    // departure, not the full timetable.
    Text {
        id: toggle
        visible: !!(root.chain && root.chain.first)
        color: Colors.accent
        font.pixelSize: 12
        text: root.expanded ? "▴ hide other trams/buses" : "▾ show other trams/buses"

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.expanded = !root.expanded }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.expanded
        spacing: 6

        CommuteLegOptions {
            Layout.fillWidth: true
            title: "first leg (" + (root.chain && root.chain.first_leg ? root.chain.first_leg : "") + "):"
            departures: root.chain && root.chain.first_leg && root.chain.legs
                ? root.chain.legs[root.chain.first_leg] : []
            chosenTripId: root.chain && root.chain.first ? root.chain.first.trip_id : ""
            boardableEpoch: null
        }

        CommuteLegOptions {
            Layout.fillWidth: true
            title: "connections at the hub (" + (root.chain && root.chain.second_leg ? root.chain.second_leg : "") + "):"
            departures: root.chain && root.chain.second_leg && root.chain.legs
                ? root.chain.legs[root.chain.second_leg] : []
            chosenTripId: root.chain && root.chain.second ? root.chain.second.trip_id : ""
            boardableEpoch: root.chain ? root.chain.earliest_boardable_epoch : null
        }
    }
}
