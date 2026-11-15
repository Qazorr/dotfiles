import QtQuick
import qs.Common
import qs.Modules.DBar
import qs.Modules.Plugins
import qs.DCommon.Widgets
import qs.Widgets
import qs.Services

BasePill {
    id: root

    property var widgetData: null
    property var surfaceContext: null
    property bool compactMode: false
    readonly property bool showNotificationBadge: SettingsData.widgetOption("clock", widgetData, "clockNotificationBadge")
    readonly property int notificationCount: surfaceContext?.notificationCount ?? 0
    signal clockClicked

    onClicked: clockClicked()
    onRightClicked: SessionService.toggleIdleInhibit()

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.contentThickness : layout.implicitWidth
            implicitHeight: root.isVerticalOrientation ? layout.implicitHeight : root.contentThickness

            Rectangle {
                anchors.fill: parent
                anchors.margins: -root.horizontalPadding
                radius: root.outerRadius
                color: "transparent"
                border.width: 1.5
                border.color: Theme.primary
                visible: SessionService.idleInhibited
            }

            Binding {
                target: root
                property: "splitOffset"
                value: clock.split ? root.horizontalPadding + layout.x + clock.x + clock.splitOffset : 0
            }

            Grid {
                id: layout
                anchors.centerIn: parent
                columns: root.isVerticalOrientation ? 1 : Math.max(1, layout.visibleChildren.length)
                spacing: root.isVerticalOrientation ? Theme.spacingXXS : Theme.spacingXS
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                ClockContent {
                    id: clock
                    cupSeparator: SessionService.idleInhibited
                    vertical: root.isVerticalOrientation
                    segmented: root.surfaceContext?.kind !== "dock" && BarMetrics.widgetStyle(root.barConfig) === "segments" && !root.noBackground
                    displayMode: SettingsData.widgetOption("clock", root.widgetData, "clockCompactMode") ? "time" : "both"
                    dateFirst: root.widgetData?.clockDateOrder === "dateFirst"
                    fontSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    availableWidth: root.widgetThickness
                    textColor: root.contentColor
                    dateColor: vertical ? Theme.primary : root.contentColor
                }

                Rectangle {
                    visible: root.showNotificationBadge && root.notificationCount > 0
                    width: Math.max(height, badgeText.implicitWidth + Theme.spacingXS * 2)
                    height: badgeText.implicitHeight + Theme.spacingXXS * 2
                    radius: Theme.fullRadius(width, height)
                    color: Theme.error

                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.notificationCount
                        font.pixelSize: Math.round(clock.fontSize * 0.75)
                        font.weight: Theme.fontWeightMedium
                        color: Theme.onError
                    }
                }
            }
        }
    }
}
