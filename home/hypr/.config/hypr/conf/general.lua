hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 4,
		border_size = 2,
		col = {
			active_border = { colors = { "rgb(D0BCFF)", "rgb(CCC2DC)" }, angle = 45 },
			inactive_border = "rgb(49454E)",
		},
		layout = "dwindle",
		resize_on_border = true,
		allow_tearing = false,
	},

	dwindle = {
		preserve_split = true,
	},

	group = {
		col = {
			border_active = "rgb(CCC2DC)",
		},

		groupbar = {
			col = {
				active = "rgb(211F24)",
			},
		},
	},

	binds = {
		workspace_back_and_forth = true,
		allow_workspace_cycles = true,
	},

	misc = {
		middle_click_paste = false,
		focus_on_activate = true,

		allow_session_lock_restore = true,
	},
})
