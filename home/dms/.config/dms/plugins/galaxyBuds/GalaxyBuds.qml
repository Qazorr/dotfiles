import QtQuick
import Quickshell
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
    // GalaxyBudsClient doesn't publish this over D-Bus; its battery history
    // logs it with every status change. 0 off, 1 ANC, 2 ambient, 3 adaptive.
    property int noiseMode: -1

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

    // Only toggles exist: AncToggle lands on ANC from off or ambient, and
    // turns ANC off; AmbientToggle mirrors that.
    function setNoiseMode(mode) {
        if (mode === noiseMode || noiseMode < 0)
            return;
        if (mode === 0)
            execute(noiseMode === 2 ? "AmbientToggle" : "AncToggle");
        else
            execute(mode === 1 ? "AncToggle" : "AmbientToggle");
        noiseMode = mode;
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
                modeProc.running = true;
                return;
            } catch (e) {}
        }
        appRunning = !/not provided|ServiceUnknown|NameHasNoOwner/i.test(err);
        connected = false;
        device = {};
        noiseMode = -1;
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
        id: modeProc
        command: ["python3", "-I", "-c", "import sqlite3,sys\nc=sqlite3.connect(f'file:{sys.argv[1]}?mode=ro',uri=True)\nr=c.execute('select NoiseControlMode from Records order by Id desc limit 1').fetchone()\nprint(r[0] if r and r[0] is not None else -1)", Quickshell.env("HOME") + "/.local/share/GalaxyBudsClient/battery_stats_" + (root.device.Address || "").replace(/:/g, "") + ".db"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text);
                root.noiseMode = isNaN(n) ? -1 : n;
            }
        }
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
        property int level: -1
        property string detail: ""

        width: (parent.width - Theme.spacingS * 2) / 3
        height: 108
        radius: Theme.cornerRadius
        color: Theme.cardSurface

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DRingGauge {
                width: 54
                height: 54
                value: tile.level >= 0 ? tile.level / 100 : -1
                ringColor: root.batteryColor(tile.level)
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    anchors.centerIn: parent
                    text: tile.level >= 0 ? tile.level : "—"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: tile.level >= 0 ? Theme.surfaceText : Theme.surfaceVariantText
                }
            }

            StyledText {
                text: tile.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: tile.detail || " "
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    component SectionLabel: StyledText {
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
        leftPadding: Theme.spacingXS
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: root.device.Name || "Galaxy Buds"
            detailsText: root.device.Model ? root.device.Model + (root.device.FirmwareVersion ? " · " + root.device.FirmwareVersion : "") : ""

            Component.onCompleted: root.refresh()

            Column {
                width: parent.width
                spacing: Theme.spacingS

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

                Item {
                    width: 1
                    height: Theme.spacingXS
                }

                SectionLabel {
                    text: "Noise control"
                }

                StyledRect {
                    id: modes
                    readonly property var options: [
                        { mode: 0, icon: "volume_off", label: "Off" },
                        { mode: 1, icon: "noise_control_off", label: "ANC" },
                        { mode: 2, icon: "hearing", label: "Ambient" }
                    ]
                    readonly property real segWidth: (width - 8) / options.length
                    readonly property int index: options.findIndex(o => o.mode === root.noiseMode)

                    width: parent.width
                    height: 48
                    radius: Theme.cornerRadius
                    color: Theme.cardSurface

                    StyledRect {
                        visible: modes.index >= 0
                        x: 4 + modes.index * modes.segWidth
                        y: 4
                        width: modes.segWidth
                        height: parent.height - 8
                        radius: Theme.cornerRadius - 4
                        color: Theme.primary

                        Behavior on x {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Row {
                        x: 4
                        y: 4

                        Repeater {
                            model: modes.options

                            Item {
                                id: seg
                                required property var modelData
                                required property int index
                                readonly property bool active: modes.index === index

                                width: modes.segWidth
                                height: modes.height - 8

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DIcon {
                                        name: seg.modelData.icon
                                        size: Theme.iconSize - 4
                                        filled: seg.active
                                        color: seg.active ? Theme.primaryText : segMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: seg.modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: seg.active ? Font.Medium : Font.Normal
                                        color: seg.active ? Theme.primaryText : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: segMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: seg.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: root.setNoiseMode(seg.modelData.mode)
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: 44
                    radius: Theme.cornerRadius
                    color: managerMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.cardSurface

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DIcon {
                            name: "open_in_new"
                            size: Theme.iconSize - 4
                            color: managerMouse.containsMouse ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Open manager"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: managerMouse
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
