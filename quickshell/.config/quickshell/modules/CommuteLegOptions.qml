pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../theme"

// One leg's upcoming departures, as reported by `krk-commute show --json`.
//
// "→" marks the trip currently chosen for the chain. "✗" marks trips that
// leave before you could physically be at the transfer stop (the first
// leg's arrival plus the configured walking buffer, which the backend
// reports as earliest_boardable_epoch) — i.e. ones that are chronologically
// next but that you would actually miss.
ColumnLayout {
    id: root
    spacing: 1

    property string title: ""
    property var departures: []
    property string chosenTripId: ""
    // null for the first leg: every option there is a valid "just leave
    // later instead" choice, so nothing is unreachable.
    property var boardableEpoch: null

    readonly property color muted: Qt.darker(Colors.foreground, 1.4)

    visible: departures && departures.length > 0

    function fmtClock(epoch) {
        if (epoch === null || epoch === undefined) return "?";
        return Qt.formatDateTime(new Date(epoch * 1000), "hh:mm");
    }

    function iconFor(route) { return route === "50" ? "\uf238" : "\uf207"; }

    Text {
        Layout.fillWidth: true
        color: root.muted
        font.pixelSize: 12
        text: root.title
    }

    Repeater {
        model: root.departures

        delegate: Text {
            required property var modelData

            readonly property bool missed: root.boardableEpoch !== null
                && root.boardableEpoch !== undefined
                && modelData.epoch < root.boardableEpoch
            readonly property bool chosen: root.chosenTripId.length > 0
                && root.chosenTripId === modelData.trip_id
            readonly property bool hasArrival: modelData.arrival_epoch !== null
                && modelData.arrival_epoch !== undefined

            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: "monospace"
            font.pixelSize: 12
            font.bold: chosen
            color: missed ? Qt.darker(root.muted, 1.3)
                : (chosen ? Colors.foreground : root.muted)

            text: (chosen ? "→ " : (missed ? "✗ " : "   "))
                + root.iconFor(modelData.route) + " " + modelData.route
                + " " + root.fmtClock(modelData.epoch)
                + (hasArrival ? " → " + root.fmtClock(modelData.arrival_epoch) : "")
                + "  " + modelData.headsign
                + "  [" + modelData.source + (hasArrival ? "/" + modelData.arrival_source : "") + "]"
        }
    }
}
