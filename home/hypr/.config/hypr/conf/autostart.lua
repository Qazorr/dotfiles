hl.on("hyprland.start", function()
	-- Absolute path: this doesn't source ~/.zshrc, and the binaries live
	-- outside ~/.local/bin.
	hl.exec_cmd(os.getenv("HOME") .. "/.local/share/dms/bin/dms run")

	hl.exec_cmd("monitor-profile --watch")

	-- Applies ~/.config/hypr/screenshare.conf while anything is capturing, and
	-- is what lets `screenshare status` answer at all.
	hl.exec_cmd("screenshare watch")
end)
