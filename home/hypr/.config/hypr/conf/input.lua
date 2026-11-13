hl.config({
	input = {
		kb_layout = "pl",
		repeat_delay = 300,
		repeat_rate = 50,
		numlock_by_default = true,
		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
})

local zoom = require("conf.zoom")

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = zoom(1.5) })
hl.gesture({ fingers = 3, direction = "down", action = zoom(1 / 1.5) })
hl.gesture({ fingers = 4, direction = "up", action = function()
	hl.exec_cmd("dms ipc call dash toggle")
end })
hl.gesture({ fingers = 4, direction = "down", action = "float" })
