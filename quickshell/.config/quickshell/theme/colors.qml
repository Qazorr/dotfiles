pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Singleton (declared in qmldir) so every module can `import "../theme"`
// and reference Colors.accent etc. directly.
QtObject {
    id: root

    // Catppuccin Mocha fallback, used until wallust has generated
    // ~/.cache/wallust/colors.json (see wallust/.config/wallust/wallust.toml
    // and scripts/.local/bin/wallust-apply).
    property color background: "#1e1e2e"
    property color foreground: "#cdd6f4"
    property color accent: "#89b4fa"
    property color accent2: "#cba6f7"
    property color urgent: "#f38ba8"
    property color surface: "#313244"

    property string home: Quickshell.env("HOME") ?? "/home/kacper"

    // QtObject has no default property, so this can't be a bare child
    // declaration — it needs an explicit property name to attach to.
    property FileView colorsFile: FileView {
        path: root.home + "/.cache/wallust/colors.json"
        watchChanges: true
        onLoaded: {
            try {
                const c = JSON.parse(text());
                root.background = c.background;
                root.foreground = c.foreground;
                root.accent = c.color4;
                root.accent2 = c.color5;
                root.urgent = c.color1;
                root.surface = c.color0;
            } catch (e) {
                console.warn("theme/colors.qml: failed to parse wallust output:", e);
            }
        }
    }
}
