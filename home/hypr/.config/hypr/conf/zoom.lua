return function(factor)
	return function()
		local current = math.max(hl.get_config("cursor.zoom_factor") or 1, 1)
		hl.config({ ["cursor.zoom_factor"] = math.max(current * factor, 1) })
	end
end
