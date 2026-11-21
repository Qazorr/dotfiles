// Modules/DBar/Widgets/Battery.qml from DMS v2.1.2, changed to: fill the pill with a matugen color (error when low)
// while running on battery, with a down arrow, the drain rate and the time left.
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: battery
    readonly property var log: Log.scoped("Battery")

    Component.onCompleted: BatteryService.addRef()
    Component.onDestruction: BatteryService.removeRef()

    property bool batteryPopupVisible: false
    property var popoutTarget: null
    property var widgetData: null
    readonly property bool showPercentOnlyOnBattery: SettingsData.widgetOption("battery", widgetData, "showBatteryPercentOnlyOnBattery")
    readonly property bool showPercent: {
        const base = SettingsData.widgetOption("battery", widgetData, "showBatteryPercent");
        return base && !(showPercentOnlyOnBattery && BatteryService.isPluggedIn);
    }
    readonly property bool showTime: SettingsData.widgetOption("battery", widgetData, "showBatteryTime")
    readonly property bool showTimeOnlyOnBattery: SettingsData.widgetOption("battery", widgetData, "showBatteryTimeOnlyOnBattery")
    readonly property string batteryStyle: SettingsData.widgetOption("battery", widgetData, "batteryStyle")
    readonly property bool pillStyle: battery.batteryStyle !== "icon"
    readonly property bool levelColors: (barConfig?.batteryColorMode ?? "theme") === "level"
    readonly property bool showPowerCharging: SettingsData.widgetOption("battery", widgetData, "showBatteryPowerCharging")
    readonly property bool showPowerDischarging: SettingsData.widgetOption("battery", widgetData, "showBatteryPowerDischarging")
    readonly property bool showPower: BatteryService.isCharging ? showPowerCharging : (showPowerDischarging || (draining && drainRate))
    readonly property bool critical: SettingsData.batteryCriticalAnimation && BatteryService.isCriticalBattery && !BatteryService.isCharging

    property bool drainHighlight: true
    property bool drainPulse: true
    property bool drainRate: true
    property bool drainTime: true
    readonly property bool draining: drainHighlight && BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    property string drainColor: "primary"
    readonly property var drainPalette: ({
            "primary": [Theme.primary, Theme.onPrimary],
            "tertiary": [Theme.tertiaryContainer, Theme.onTertiaryContainer],
            "secondary": [Theme.secondaryContainer, Theme.onSecondaryContainer]
        })
    readonly property var drainPair: BatteryService.isLowBattery ? [Theme.error, Theme.onError] : (drainPalette[drainColor] ?? drainPalette.primary)
    readonly property color drainAccent: drainPair[0]
    readonly property color drainInk: drainPair[1]
    property real drainGlow: 1
    property int drainTick: 0

    Timer {
        interval: 80
        repeat: true
        running: battery.draining && battery.drainPulse && battery.surfaceLive && !SettingsData.reduceMotion
        onRunningChanged: {
            battery.drainTick = 0;
            battery.drainGlow = 1;
        }
        onTriggered: {
            battery.drainTick = (battery.drainTick + 1) % 30;
            battery.drainGlow = 0.55 + 0.45 * Math.abs(15 - battery.drainTick) / 15;
        }
    }
    property real criticalPulse: 0
    readonly property color criticalForeground: noBackground ? battery.mixColor(Theme.error, defaultContentColor, criticalPulse) : battery.mixColor(Theme.error, Theme.surface, criticalPulse)

    fillColor: draining ? Qt.alpha(drainAccent, drainGlow) : critical && !noBackground ? battery.mixColor(defaultFillColor, Theme.error, criticalPulse) : defaultFillColor
    contentColor: draining ? drainInk : critical ? (noBackground ? criticalForeground : battery.mixColor(defaultContentColor, Theme.surface, criticalPulse)) : defaultContentColor

    function mixColor(from, to, progress) {
        return Qt.rgba(from.r + (to.r - from.r) * progress, from.g + (to.g - from.g) * progress, from.b + (to.b - from.b) * progress, from.a + (to.a - from.a) * progress);
    }

    property int criticalTick: 0

    // Stepped on purpose: an Animation repaints the bar at the full refresh rate.
    Timer {
        interval: 50
        repeat: true
        running: battery.critical && battery.surfaceLive && !SettingsData.reduceMotion
        onRunningChanged: {
            battery.criticalTick = 0;
            battery.criticalPulse = 0;
        }
        onTriggered: {
            battery.criticalTick = (battery.criticalTick + 1) % 40;
            battery.criticalPulse = 1 - Math.abs(20 - battery.criticalTick) / 20;
        }
    }

    // Signed charge/discharge rate, e.g. "+45W" while charging, "-8.4W" while
    // draining. Empty (and therefore hidden) whenever the battery is idle.
    readonly property string batteryPowerText: showPower ? BatteryService.formatPowerRate(false) : ""
    readonly property string verticalBatteryPowerText: showPower ? BatteryService.formatPowerRate(true) : ""

    readonly property bool timeShown: showTime || (draining && drainTime)
    readonly property string batteryTimeText: {
        if (showTimeOnlyOnBattery && BatteryService.isPluggedIn) {
            return "";
        }
        const time = BatteryService.formatTimeRemaining();
        return time !== "Unknown" ? time : "";
    }

    readonly property string verticalBatteryTimeText: {
        if (!batteryTimeText)
            return "";

        // Parse batteryTimeText, e.g., "2h 41m" or "41m"
        let hours = 0;
        let minutes = 0;

        const hourMatch = batteryTimeText.match(/(\d+)h/);
        const minMatch = batteryTimeText.match(/(\d+)m/);

        if (hourMatch) {
            hours = parseInt(hourMatch[1], 10);
        }
        if (minMatch) {
            minutes = parseInt(minMatch[1], 10);
        }

        const hoursStr = hours < 10 ? "0" + hours : hours.toString();
        const minutesStr = minutes < 10 ? "0" + minutes : minutes.toString();

        return `${hoursStr}\n${minutesStr}`;
    }

    readonly property string horizontalDisplayText: {
        const parts = [];
        if (showPercent) {
            parts.push(`${BatteryService.displayBatteryLevelText}%`);
        }
        if (timeShown && batteryTimeText) {
            parts.push(showPercent ? `(${batteryTimeText})` : batteryTimeText);
        }
        if (batteryPowerText) {
            parts.push(batteryPowerText);
        }
        return parts.join(" ");
    }

    // Percent stays inside the pill unless the duo glyph occupies it; time and wattage show beside it.
    readonly property string horizontalSideText: {
        if (!pillStyle) {
            return horizontalDisplayText;
        }
        const parts = [];
        if (showPercent && batteryStyle === "duo") {
            parts.push(`${BatteryService.displayBatteryLevelText}%`);
        }
        if (timeShown && batteryTimeText) {
            parts.push(batteryTimeText);
        }
        if (batteryPowerText) {
            parts.push(batteryPowerText);
        }
        return parts.join(" ");
    }

    readonly property string verticalDisplayText: {
        const lines = [];
        if (showPercent) {
            lines.push(BatteryService.displayBatteryLevelText);
        }
        if (timeShown && batteryTimeText) {
            lines.push(verticalBatteryTimeText);
        }
        if (verticalBatteryPowerText) {
            lines.push(verticalBatteryPowerText);
        }
        return lines.join("\n");
    }

    property real touchpadAccumulator: 0

    readonly property int barPosition: {
        switch (axis?.edge) {
        case "top":
            return 0;
        case "bottom":
            return 1;
        case "left":
            return 2;
        case "right":
            return 3;
        default:
            return 0;
        }
    }

    signal toggleBatteryPopup

    visible: true

    content: Component {
        Item {
            implicitWidth: battery.isVerticalOrientation ? (battery.widgetThickness - battery.horizontalPadding * 2) : batteryContent.implicitWidth
            implicitHeight: battery.isVerticalOrientation ? batteryColumn.implicitHeight : (battery.widgetThickness - battery.horizontalPadding * 2)

            Column {
                id: batteryColumn
                visible: battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DIcon {
                    name: "arrow_downward"
                    visible: battery.draining
                    size: Theme.barIconSize(battery.barThickness, -4, battery.barConfig?.maximizeWidgetIcons, battery.barConfig?.iconScale)
                    color: battery.drainInk
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                DIcon {
                    name: BatteryService.getBatteryIcon()
                    visible: !battery.pillStyle
                    size: Theme.barIconSize(battery.barThickness, undefined, battery.barConfig?.maximizeWidgetIcons, battery.barConfig?.iconScale)
                    color: {
                        if (!BatteryService.batteryAvailable) {
                            return Theme.widgetIconColor;
                        }

                        if (battery.critical) {
                            return battery.criticalForeground;
                        }

                        if (battery.levelColors) {
                            return BatteryService.levelColor;
                        }

                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error;
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                BatteryMeter {
                    visible: battery.pillStyle
                    vertical: true
                    showNumber: false
                    meterStyle: battery.batteryStyle
                    levelColors: battery.levelColors
                    colorOverride: battery.critical ? battery.criticalForeground : battery.draining ? battery.drainInk : "transparent"
                    maxDiameter: battery.widgetThickness - Theme.spacingXS
                    thickness: Theme.barIconSize(battery.barThickness, undefined, battery.barConfig?.maximizeWidgetIcons, battery.barConfig?.iconScale)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: battery.verticalDisplayText
                    font.pixelSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    color: battery.contentColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: BatteryService.batteryAvailable && battery.verticalDisplayText !== ""
                }
            }

            Row {
                id: batteryContent
                visible: !battery.isVerticalOrientation
                anchors.centerIn: parent
                spacing: (barConfig?.noBackground ?? false) ? 1 : 2

                DIcon {
                    name: "arrow_downward"
                    visible: battery.draining
                    size: Theme.barIconSize(battery.barThickness, -4, battery.barConfig?.maximizeWidgetIcons, battery.barConfig?.iconScale)
                    color: battery.drainInk
                    anchors.verticalCenter: parent.verticalCenter
                }

                DIcon {
                    name: BatteryService.getBatteryIcon()
                    visible: !battery.pillStyle
                    size: Theme.barIconSize(battery.barThickness, -4, battery.barConfig?.maximizeWidgetIcons, battery.barConfig?.iconScale)
                    color: {
                        if (!BatteryService.batteryAvailable) {
                            return Theme.widgetIconColor;
                        }

                        if (battery.critical) {
                            return battery.criticalForeground;
                        }

                        if (battery.levelColors) {
                            return BatteryService.levelColor;
                        }

                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error;
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                BatteryMeter {
                    visible: battery.pillStyle
                    showNumber: battery.showPercent
                    meterStyle: battery.batteryStyle
                    levelColors: battery.levelColors
                    colorOverride: battery.critical ? battery.criticalForeground : battery.draining ? battery.drainInk : "transparent"
                    maxDiameter: battery.widgetThickness - Theme.spacingXS
                    thickness: Theme.barIconSize(battery.barThickness, -4, battery.barConfig?.maximizeWidgetIcons, battery.barConfig?.iconScale)
                    fontSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    anchors.verticalCenter: parent.verticalCenter
                }

                NumericText {
                    text: battery.horizontalSideText
                    font.weight: battery.draining ? Font.Bold : Font.Normal
                    font.pixelSize: Theme.barTextSize(battery.barThickness, battery.barConfig?.fontScale, battery.barConfig?.maximizeWidgetText)
                    color: battery.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BatteryService.batteryAvailable && battery.horizontalSideText !== ""
                }
            }
        }
    }

    MouseArea {
        x: -battery.leftMargin
        y: -battery.topMargin
        width: battery.width + battery.leftMargin + battery.rightMargin
        height: battery.height + battery.topMargin + battery.bottomMargin
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            battery.triggerRipple(this, mouse.x, mouse.y);
            if (mouse.button === Qt.LeftButton) {
                toggleBatteryPopup();
            } else if (mouse.button === Qt.RightButton) {
                if (PowerProfileWatcher.available) {
                    PowerProfileWatcher.cycleProfile();
                } else {
                    ToastService.showError(I18n.tr("power-profiles-daemon not available"));
                }
            }
        }
        onWheel: wheel => {
            var delta = wheel.angleDelta.y;
            if (delta === 0)
                return;

            // Check if this is a touchpad
            if (delta !== 120 && delta !== -120) {
                touchpadAccumulator += delta;
                if (Math.abs(touchpadAccumulator) < 500)
                    return;
                delta = touchpadAccumulator;
                touchpadAccumulator = 0;
            }

            if (!BrightnessService.brightnessAvailable) {
                return;
            }

            const step = 5;
            const change = delta > 0 ? step : -step;
            const newBrightness = Math.max(0, Math.min(100, BrightnessService.brightnessLevel + change));
            BrightnessService.setBrightness(newBrightness, "", false);
        }
    }
}
