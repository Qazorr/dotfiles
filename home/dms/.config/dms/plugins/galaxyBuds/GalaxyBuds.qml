import QtQuick
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string service: "me.timschneeberger.GalaxyBudsClient"
    readonly property string appPath: "/me/timschneeberger/galaxybudsclient"
    readonly property string appIface: service + ".Application"
    readonly property string devicePath: appPath + "/device"
    readonly property string deviceIface: service + ".Device"

    property bool appRunning: false
    property bool connected: false
    property var device: ({})

    // A bud that isn't connected reports 0, and so does the case with no bud in it.
    readonly property int batteryLeft: device.WearStateLeft === "Disconnected" ? -1 : (device.BatteryLeft ?? -1)
    readonly property int batteryRight: device.WearStateRight === "Disconnected" ? -1 : (device.BatteryRight ?? -1)
    readonly property int batteryCase: ["Case", "ClosedCase"].some(s => s === device.WearStateLeft || s === device.WearStateRight) ? (device.BatteryCase ?? -1) : -1
    readonly property int batteryLow: {
        const known = [batteryLeft, batteryRight].filter(v => v >= 0);
        return known.length ? Math.min(...known) : -1;
    }

    popoutWidth: 380

    onConnectedChanged: setVisibilityOverride(connected)
    Component.onCompleted: {
        setVisibilityOverride(false);
        refresh();
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function execute(action) {
        actionProc.command = ["busctl", "--user", "call", service, appPath, appIface, "ExecuteAction", "s", action];
        actionProc.running = true;
    }

    function activateApp() {
        actionProc.command = ["busctl", "--user", "call", service, appPath, appIface, "Activate"];
        actionProc.running = true;
        closePopout();
    }

    // busctl --json=short wraps every variant as {type, data}.
    function unwrap(v) {
        if (v && typeof v === "object" && "type" in v && "data" in v)
            return unwrap(v.data);
        if (Array.isArray(v))
            return v.map(unwrap);
        if (v && typeof v === "object") {
            const out = {};
            for (const k in v)
                out[k] = unwrap(v[k]);
            return out;
        }
        return v;
    }

    function parseStatus(out, err, exitCode) {
        if (exitCode === 0) {
            try {
                const data = unwrap(JSON.parse(out));
                device = Array.isArray(data) ? data[0] : data;
                appRunning = true;
                connected = true;
                return;
            } catch (e) {}
        }
        appRunning = !/not provided|ServiceUnknown|NameHasNoOwner/i.test(err);
        connected = false;
        device = {};
    }

    function batteryColor(level) {
        if (level < 0)
            return Theme.surfaceVariantText;
        if (level <= 15)
            return Theme.error;
        if (level <= 30)
            return Theme.warning;
        return Theme.primary;
    }

    function wearLabel(state) {
        switch (state) {
        case "Wearing":
            return "In ear";
        case "Idle":
            return "Out";
        case "Case":
        case "ClosedCase":
            return "In case";
        case "Disconnected":
            return "Asleep";
        case undefined:
            return "—";
        default:
            return state;
        }
    }

    Process {
        id: statusProc
        property string out: ""
        property string err: ""
        command: ["busctl", "--user", "--json=short", "call", root.service, root.devicePath, "org.freedesktop.DBus.Properties", "GetAll", "s", root.deviceIface]
        stdout: StdioCollector {
            onStreamFinished: statusProc.out = text
        }
        stderr: StdioCollector {
            onStreamFinished: statusProc.err = text
        }
        onExited: code => root.parseStatus(out, err, code)
    }

    Process {
        id: actionProc
        onExited: refreshSoon.restart()
    }

    Timer {
        id: refreshSoon
        interval: 1500
        onTriggered: root.refresh()
    }

    Timer {
        interval: root.connected ? 30000 : 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DIcon {
                name: "earbuds"
                size: root.iconSize
                color: root.batteryLow >= 0 && root.batteryLow <= 15 ? Theme.error : Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.batteryLow >= 0
                text: root.batteryLow + "%"
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DIcon {
                name: "earbuds"
                size: root.iconSize
                color: root.batteryLow >= 0 && root.batteryLow <= 15 ? Theme.error : Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.batteryLow >= 0
                text: root.batteryLow
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    component BatteryTile: StyledRect {
        id: tile
        property string label
        property string icon
        property int level: -1
        property string detail: ""

        width: (parent.width - Theme.spacingS * 2) / 3
        height: 104
        radius: Theme.cornerRadius
        color: Theme.cardSurface

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DRingGauge {
                width: 52
                height: 52
                value: tile.level >= 0 ? tile.level / 100 : -1
                ringColor: root.batteryColor(tile.level)
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    anchors.centerIn: parent
                    text: tile.level >= 0 ? tile.level : "—"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
            }

            StyledText {
                text: tile.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: tile.detail.length > 0
                text: tile.detail
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    component ActionTile: StyledRect {
        id: action
        property string icon
        property string label
        property string actionId

        width: (parent.width - Theme.spacingS * 2) / 3
        height: 64
        radius: Theme.cornerRadius
        color: mouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.14) : Theme.cardSurface

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DIcon {
                name: action.icon
                size: Theme.iconSize
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: action.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.execute(action.actionId)
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: root.device.Name || "Galaxy Buds"
            detailsText: root.device.Model ? root.device.Model + (root.device.FirmwareVersion ? " · " + root.device.FirmwareVersion : "") : ""

            Component.onCompleted: root.refresh()

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    BatteryTile {
                        label: "Left"
                        level: root.batteryLeft
                        detail: root.wearLabel(root.device.WearStateLeft)
                    }
                    BatteryTile {
                        label: "Right"
                        level: root.batteryRight
                        detail: root.wearLabel(root.device.WearStateRight)
                    }
                    BatteryTile {
                        label: "Case"
                        level: root.batteryCase
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    ActionTile {
                        icon: "noise_control_off"
                        label: "ANC"
                        actionId: "AncToggle"
                    }
                    ActionTile {
                        icon: "hearing"
                        label: "Ambient"
                        actionId: "AmbientToggle"
                    }
                    ActionTile {
                        icon: "touch_app"
                        label: "Touch lock"
                        actionId: "LockTouchpadToggle"
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    ActionTile {
                        icon: "graphic_eq"
                        label: "Next EQ"
                        actionId: "EqualizerNextPreset"
                    }
                    ActionTile {
                        icon: "location_searching"
                        label: "Find"
                        actionId: "StartStopFind"
                    }
                    StyledRect {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        height: 64
                        radius: Theme.cornerRadius
                        color: openMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.14) : Theme.cardSurface

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DIcon {
                                name: "open_in_new"
                                size: Theme.iconSize
                                color: Theme.primary
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: "Manager"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            id: openMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activateApp()
                        }
                    }
                }
            }
        }
    }
}
