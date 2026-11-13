-- The shadow is drawn at range 3 as a window outline, so it takes the border
-- colours, whichever theme set them.
local function border(key)
	local value = hl.get_config(key)
	return type(value) == "table" and value.colors[1] or value
end

hl.config({
	decoration = {
		shadow = {
			color = border("general.col.active_border"),
			color_inactive = border("general.col.inactive_border"),
		},
	},
})
