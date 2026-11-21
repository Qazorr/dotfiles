import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

// BatteryBody is the stock Battery widget that turns amber while running on battery.
// It replaces the stock widget in the bar, so it opens the stock battery popout itself.
PluginComponent {
    id: root

    property var widgetData: null

    width: battery.width
    height: battery.height

    BatteryBody {
        id: battery

        axis: root.axis
        section: root.section
        parentScreen: root.parentScreen
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
        surfaceLive: root.surfaceLive
        widgetData: root.widgetData
        popoutTarget: PopoutService.batteryPopoutLoader?.item ?? null
        batteryPopupVisible: PopoutService.batteryPopoutLoader?.item?.shouldBeVisible ?? false

        drainHighlight: root.pluginData.highlight ?? true
        drainPulse: root.pluginData.pulse ?? true
        drainRate: root.pluginData.showRate ?? true
        drainTime: root.pluginData.showTime ?? true
        drainColor: root.pluginData.color ?? "primary"

        onToggleBatteryPopup: root.toggleBatteryPopout()
    }

    function toggleBatteryPopout() {
        const loader = PopoutService.batteryPopoutLoader;
        if (!loader)
            return;
        loader.active = true;
        const popout = loader.item ?? PopoutService.batteryPopout;
        if (!popout) {
            Qt.callLater(toggleBatteryPopout);
            return;
        }
        if (popout.shouldBeVisible) {
            popout.close();
            return;
        }
        const anchor = surfaceContext?.popupAnchor ? surfaceContext.popupAnchor(battery, section) : null;
        if (anchor)
            popout.setTriggerPosition(anchor.trigger.x, anchor.trigger.y, anchor.trigger.width, section, anchor.screen, anchor.position, anchor.thickness, anchor.spacing, anchor.config, battery);
        if (typeof popout.prepareForTrigger === "function")
            popout.prepareForTrigger("battery", "click");
        PopoutManager.requestPopout(popout, undefined, "battery");
    }
}
