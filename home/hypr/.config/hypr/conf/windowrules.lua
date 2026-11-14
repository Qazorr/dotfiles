-- Find a window's class and title with `hyprctl clients`. Windows launched
-- from a keybind can carry rules on the exec dispatcher instead — see
-- keybindings.lua.
hl.window_rule({ match = { title = "^(.*MdfAvi.*)$" }, tag = "+mdf-tools" })
hl.window_rule({ match = { title = "^(.*MdfViewer.*)$" }, tag = "+mdf-tools" })
hl.window_rule({ match = { title = "^(.*BusViewer.*)$" }, tag = "+mdf-tools" })
hl.window_rule({ match = { title = "^(.*ProtocolDescriptionExplorer.*)$" }, tag = "+mdf-tools" })

hl.window_rule({
	name = "mdf-tools",
	match = { tag = "mdf-tools" },
	float = true,
})

hl.window_rule({
	name = "wireshark",
	match = { class = "^(.*Wireshark.*)$" },
	float = true,
	rounding = 10,
})

hl.window_rule({
	name = "file-managers",
	match = { class = "^(dev.duxlabs.files|org.gnome.Nautilus|[Tt]hunar)$" },
	float = true,
	size = "monitor_w*0.6 monitor_h*0.7",
	center = true,
})

hl.window_rule({
	name = "vlc",
	match = { class = "^vlc$" },
	float = true,
})

hl.window_rule({
	name = "pkgs",
	match = { class = "^pkgs$" },
	float = true,
	size = "monitor_w*0.75 monitor_h*0.85",
	center = true,
})

hl.window_rule({
	name = "whatsapp",
	match = { title = "^([Ww]hats[Aa]pp Web)$" },
	workspace = "9",
})

hl.window_rule({
	name = "discord",
	match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$" },
	workspace = "9",
})

hl.window_rule({
	name = "teams",
	match = { title = "^(Microsoft Teams.*)$" },
	workspace = "10",
})

hl.window_rule({
	name = "outlook",
	match = { title = "^(.*Outlook.*)$" },
	workspace = "10",
})

-- Blanked for anyone capturing the screen, including screenshots. Evaluated
-- when a window opens, so it lives here rather than being toggled at runtime.
-- hl.window_rule({
-- 	name = "no-screen-share",
-- 	match = { class = "^(1Password|Bitwarden|KeePassXC)$" },
-- 	no_screen_share = true,
-- })
