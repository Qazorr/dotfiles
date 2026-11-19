-- dms-greeter's own Hyprland config, plus the session's monitor, input and
-- cursor settings so the greeter gets the same scale and keyboard layout.
hl.env("DMS_RUN_GREETER", "1")
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true } })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local home = "@HOME@"
for _, f in ipairs({
	"/.config/hypr/conf/input.lua",
	"/.config/monitor-profiles/active.lua",
	"/.config/hypr/dms/outputs.lua",
	"/.config/hypr/dms/input.lua",
	"/.config/hypr/dms/cursor.lua",
}) do
	pcall(dofile, home .. f)
end
