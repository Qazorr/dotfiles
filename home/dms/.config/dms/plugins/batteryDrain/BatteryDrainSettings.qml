import QtQuick
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

PluginSettings {
    pluginId: "batteryDrain"

    SettingsCard {
        title: "Battery Drain"
        iconName: "battery_alert"

        ToggleSetting {
            settingKey: "highlight"
            label: "Highlight while on battery"
            description: "Off hides the pill entirely"
            defaultValue: true
        }

        SelectionSetting {
            settingKey: "color"
            label: "Color"
            description: "From the wallpaper palette; turns to the error color when low"
            options: [
                { label: "Primary", value: "primary" },
                { label: "Tertiary", value: "tertiary" },
                { label: "Secondary", value: "secondary" }
            ]
            defaultValue: "primary"
        }

        ToggleSetting {
            settingKey: "pulse"
            label: "Pulse"
            defaultValue: true
        }

        ToggleSetting {
            settingKey: "showRate"
            label: "Show drain rate"
            defaultValue: true
        }

        ToggleSetting {
            settingKey: "showTime"
            label: "Show time left"
            defaultValue: true
        }
    }
}
