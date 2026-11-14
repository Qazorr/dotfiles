import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.DBar.Widgets as Stock
import qs.Modules.Plugins

// Hosts the stock WorkspaceSwitcher unchanged and swaps the line of every
// workspace that is playing sound for a flowing wave.
PluginComponent {
    id: root

    readonly property string script: Qt.resolvedUrl("audio-workspaces.sh").toString().replace("file://", "")
    property var playing: []
    property var widgetData: null

    width: switcher.width
    height: switcher.height

    Stock.WorkspaceSwitcher {
        id: switcher

        axis: root.axis
        section: root.section
        parentScreen: root.parentScreen
        screenName: root.parentScreen?.name ?? ""
        widgetThickness: root.widgetThickness
        barThickness: root.barThickness
        barSpacing: root.barSpacing
        barConfig: root.barConfig
        blurBarWindow: root.blurBarWindow
        isFirst: root.isFirst
        isLast: root.isLast
        segmentRole: root.segmentRole
        isLeftBarEdge: root.isLeftBarEdge
        isRightBarEdge: root.isRightBarEdge
        isTopBarEdge: root.isTopBarEdge
        isBottomBarEdge: root.isBottomBarEdge
        sectionSpacing: root.sectionSpacing
        crossEdgeExtension: root.crossEdgeExtension
        surfaceContext: root.surfaceContext
        hyprlandOverviewLoader: root.surfaceContext?.hyprlandOverviewLoader ?? null
        widgetData: root.widgetData

        onWorkspaceListChanged: Qt.callLater(root.attachOutlines)
    }

    readonly property real period: 12

    // Replaces a workspace's line with a flowing sine wave while it is playing sound.
    Component {
        id: waveComponent

        Item {
            id: wave
            objectName: "audioOutline"
            property Item pill
            readonly property var rec: pill?.record
            readonly property int wsId: rec?.id ?? rec?.idx ?? -1
            readonly property bool hasSound: !root.isVertical && wsId >= 0 && root.playing.indexOf(wsId) >= 0
            readonly property Item surface: pill.children.find(c => c.joinedStart !== undefined) ?? null
            readonly property real thickness: Math.max(1.5, pill.visualHeight * 0.45)
            readonly property real period: root.period
            readonly property real amp: Math.max(1.5, pill.visualHeight * 0.6)
            readonly property real centerY: (root.widgetThickness - pill.visualHeight) / 2 + pill.underlineLineShift + pill.visualHeight / 2

            width: pill.visualWidth
            height: amp * 2 + thickness
            x: (pill.width - width) / 2
            y: centerY - height / 2
            clip: true
            opacity: hasSound ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Binding {
                target: wave.surface
                property: "color"
                value: "transparent"
                when: wave.hasSound && wave.surface !== null
                restoreMode: Binding.RestoreBinding
            }

            // One rasterised period, tiled and slid.
            readonly property string svg: {
                const c = pill.displayColor, h = Math.ceil(height), mid = h / 2, P = period, q = P / 4;
                const hex = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
                const color = "#" + hex(c.r) + hex(c.g) + hex(c.b);
                const path = "M" + (-P / 2) + " " + mid + " Q" + (-q) + " " + (mid - 2 * amp) + " 0 " + mid
                    + " T" + P / 2 + " " + mid + " T" + P + " " + mid + " T" + P * 1.5 + " " + mid;
                return "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' width='" + P + "' height='" + h
                    + "' viewBox='0 0 " + P + " " + h + "'><path d='" + path + "' fill='none' stroke='" + color + "' stroke-opacity='" + c.a + "' stroke-width='" + thickness
                    + "' stroke-linecap='round'/></svg>");
            }

            Image {
                id: tile
                width: wave.width + wave.period
                height: wave.height
                source: wave.svg
                sourceSize: Qt.size(wave.period, Math.ceil(wave.height))
                fillMode: Image.TileHorizontally
                smooth: true


                NumberAnimation on x {
                    from: 0
                    to: -wave.period
                    duration: 1100
                    loops: Animation.Infinite
                    running: wave.hasSound
                }
            }
        }
    }

    // Workspace pills are the stock delegates: items carrying `record` and `isPlaceholder`.
    function findPills(item, out) {
        for (const child of item.children) {
            if (child.isPlaceholder !== undefined && child.visualWidth !== undefined)
                out.push(child);
            else
                findPills(child, out);
        }
        return out;
    }

    function attachOutlines() {
        for (const pill of findPills(switcher, [])) {
            if (pill.isPlaceholder)
                continue;
            if (pill.children.some(c => c.objectName === "audioOutline"))
                continue;
            waveComponent.createObject(pill, {pill: pill});
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.attachOutlines();
            if (!poll.running)
                poll.running = true;
        }
    }

    Process {
        id: poll
        command: ["bash", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.playing = JSON.parse(text);
                } catch (e) {
                    root.playing = [];
                }
            }
        }
    }
}
