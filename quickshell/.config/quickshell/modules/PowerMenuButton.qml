import QtQuick
import QtQuick.Layouts
import "../theme"

// Shared button used by PowerMenu.qml — same directory, so no import needed.
Rectangle {
    id: btn
    property string label
    property color textColor: Colors.foreground
    signal clicked()

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 8
    color: hover.hovered ? Colors.surface : "transparent"

    Text {
        anchors.centerIn: parent
        color: btn.textColor
        text: btn.label
    }
    HoverHandler { id: hover }
    TapHandler { onTapped: btn.clicked() }
}
