hl.on("hyprland.start", function()
	-- Absolute path: this doesn't source ~/.zshrc, and the binaries live
	-- outside ~/.local/bin.
	hl.exec_cmd(os.getenv("HOME") .. "/.local/share/dms/bin/dms run -c " .. os.getenv("HOME") .. "/.local/share/dms/shell")

	hl.exec_cmd("monitor-profile --watch")

	-- Applies ~/.config/hypr/screenshare.conf while anything is capturing, and
	-- is what lets `screenshare status` answer at all.
	hl.exec_cmd("screenshare watch")

	-- GalaxyBudsClient behind the bus filter that keeps its D-Bus service (and
	-- the DMS galaxyBuds plugin) alive; exits quietly when it isn't installed.
	hl.exec_cmd("galaxybuds /StartMinimized")

	-- Hyprland doesn't run /etc/xdg/autostart, and the DMS plugin only talks
	-- to an already-running daemon.
	hl.exec_cmd("/usr/bin/kdeconnectd")
end)
