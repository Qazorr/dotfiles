import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// MediaBody is the stock Media widget with two fixes: it collapses to its controls
// while paused, and keeps the cover when consecutive tracks share one. This runs a
// segment of light around its edge while a player is playing.
PluginComponent {
    id: root

    property var widgetData: null
    readonly property bool playing: media.activePlayer?.playbackState === 1

    width: media.width
    height: media.height

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

    Process {
        id: dash
        command: ["dms", "ipc", "call", "dash", "toggle", "media"]
    }

    Shape {
        id: glow

        readonly property real sw: 2
        readonly property real r: Math.min(media.outerRadius, media.height / 2)
        readonly property real w: width - sw
        readonly property real h: height - sw
        readonly property real perimeter: 2 * (w - 2 * r) + 2 * (h - 2 * r) + 2 * Math.PI * r

        anchors.centerIn: media
        width: media.width - media.leftMargin - media.rightMargin
        height: media.widgetThickness
        opacity: root.playing ? 1 : 0
        visible: opacity > 0
        layer.enabled: true
        layer.samples: 4
        Behavior on opacity { NumberAnimation { duration: 300 } }

        ShapePath {
            id: line

            strokeColor: Theme.primary
            strokeStyle: ShapePath.DashLine
            strokeWidth: glow.sw
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            // Dash lengths are in stroke widths: one segment a third of the way round.
            dashPattern: [glow.perimeter / 3 / glow.sw, glow.perimeter * 2 / 3 / glow.sw]

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

            NumberAnimation on dashOffset {
                from: 0
                to: -glow.perimeter / glow.sw
                duration: 3500
                loops: Animation.Infinite
                running: root.playing
            }
        }
    }
}
