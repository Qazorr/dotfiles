import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Modules.Plugins

// MediaBody is the stock Media widget with two fixes: it collapses to its controls
// while paused, and keeps the cover when consecutive tracks share one. This runs a
// segment of light around its edge while a player is playing.
PluginComponent {
    id: root

    property var widgetData: null
    readonly property bool playing: media.activePlayer?.playbackState === 1

    // Hidden once nothing has played for a while; playing again brings it back.
    property bool idleHidden: false
    visible: media.playerAvailable && !idleHidden
    width: visible ? media.width : 0
    height: visible ? media.height : 0

    MediaBody {
        id: media

        axis: root.axis
        section: root.section
        parentScreen: root.parentScreen
        widgetThickness: Theme.barWidgetThickness(root.barConfig?.innerPadding ?? SettingsData.barInnerPaddingDefault, root.parentScreen ? CompositorService.getScreenScale(root.parentScreen) : 1)
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
        widgetData: root.widgetData

        onClicked: dash.running = true
    }

    Timer {
        interval: 5 * 60 * 1000
        running: media.playerAvailable && !root.playing
        onTriggered: root.idleHidden = true
    }

    Process {
        id: dash
        command: ["dms", "ipc", "call", "dash", "toggle", "media"]
    }

    // level follows the beat gently and drives thickness and brightness; slowLevel follows the
    // loudness of the passage and drives the length, which must not jump around.
    property real level: 0
    property real slowLevel: 0
    // cava's levels sit in a narrow band that depends on the track and volume, so
    // the level is taken between a slowly moving floor and peak.
    property real floorLevel: 0
    property real peakLevel: 0.2
    property real phase: 0

    Loader {
        active: root.playing && CavaService.cavaAvailable
        sourceComponent: Ref { service: CavaService }
    }

    Connections {
        target: CavaService
        enabled: root.playing
        function onValuesChanged() {
            const v = CavaService.values;
            let sum = 0;
            for (let i = 0; i < v.length; i++)
                sum += Math.sqrt(Math.max(0, Math.min(100, v[i])) * 0.01);
            const raw = v.length ? sum / v.length : 0;
            root.floorLevel += (raw - root.floorLevel) * (raw < root.floorLevel ? 0.3 : 0.003);
            root.peakLevel += (raw - root.peakLevel) * (raw > root.peakLevel ? 0.3 : 0.003);
            const norm = Math.max(0, Math.min(1, (raw - root.floorLevel) / Math.max(root.peakLevel - root.floorLevel, 0.06)));
            root.level += (norm - root.level) * (norm > root.level ? 0.2 : 0.06);
            root.slowLevel += (norm - root.slowLevel) * 0.03;
        }
    }

    onPlayingChanged: {
        if (playing) {
            idleHidden = false;
        } else {
            level = 0;
            slowLevel = 0;
        }
    }

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 3500
        loops: Animation.Infinite
        running: root.playing
    }

    Shape {
        id: glow

        readonly property real sw: 2
        readonly property real thickness: 0.25 + 3 * root.level
        readonly property real segment: 0.22 + 0.18 * root.slowLevel
        readonly property real r: Math.min(media.outerRadius, media.height / 2)
        readonly property real w: width - sw
        readonly property real h: height - sw
        readonly property real perimeter: 2 * (w - 2 * r) + 2 * (h - 2 * r) + 2 * Math.PI * r

        anchors.centerIn: media
        width: media.width
        height: media.widgetThickness
        opacity: root.playing ? 1 : 0
        visible: opacity > 0
        layer.enabled: true
        layer.samples: 4
        Behavior on opacity { NumberAnimation { duration: 300 } }

        ShapePath {
            id: line

            strokeStyle: ShapePath.DashLine
            strokeWidth: glow.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            strokeColor: Qt.alpha(Theme.primary, 0.15 + 0.85 * root.level)
            // Dash lengths are in stroke widths.
            dashPattern: [glow.segment * glow.perimeter / glow.thickness, (1 - glow.segment) * glow.perimeter / glow.thickness]
            dashOffset: -root.phase * glow.perimeter / glow.thickness

            startX: glow.sw / 2 + glow.r
            startY: glow.sw / 2

            PathLine { x: glow.sw / 2 + glow.w - glow.r; y: glow.sw / 2 }
            PathArc { x: glow.sw / 2 + glow.w; y: glow.sw / 2 + glow.r; radiusX: glow.r; radiusY: glow.r }
            PathLine { x: glow.sw / 2 + glow.w; y: glow.sw / 2 + glow.h - glow.r }
            PathArc { x: glow.sw / 2 + glow.w - glow.r; y: glow.sw / 2 + glow.h; radiusX: glow.r; radiusY: glow.r }
            PathLine { x: glow.sw / 2 + glow.r; y: glow.sw / 2 + glow.h }
            PathArc { x: glow.sw / 2; y: glow.sw / 2 + glow.h - glow.r; radiusX: glow.r; radiusY: glow.r }
            PathLine { x: glow.sw / 2; y: glow.sw / 2 + glow.r }
            PathArc { x: glow.sw / 2 + glow.r; y: glow.sw / 2; radiusX: glow.r; radiusY: glow.r }
        }
    }
}
