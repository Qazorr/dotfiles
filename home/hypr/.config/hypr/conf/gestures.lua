local zoom = require("conf.zoom")

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = zoom(1.5) })
hl.gesture({ fingers = 3, direction = "down", action = zoom(1 / 1.5) })
hl.gesture({ fingers = 4, direction = "up", action = function()
	hl.exec_cmd("dms ipc call dash toggle overview")
end })
hl.gesture({ fingers = 4, direction = "down", action = "float" })
