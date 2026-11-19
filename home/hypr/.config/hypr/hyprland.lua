-- Entry point. Config lives in conf/, split by concern; dms/ holds what DMS
-- writes from its settings.
require("conf.environment")
require("conf.autostart")
require("conf.input")
require("conf.gestures")
require("conf.general")
require("conf.decoration")
require("conf.animations")
require("conf.workspaces")
require("conf.windowrules")
require("conf.keybindings")
require("conf.monitors")

-- After conf/, so the theme and anything edited in DMS settings win.
require("dms.colors")
require("dms.background")
require("conf.outline")
require("dms.binds-user")
require("dms.windowrules")

-- Machine-local, last so it wins.
require("conf.local")
require("dms.outputs")
require("dms.input")
require("dms.cursor")
