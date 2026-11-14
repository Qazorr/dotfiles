-- Your keybinds. dms setup never overwrites this file.
-- Loaded after binds.lua: binding a stock key here replaces it, hl.unbind("SUPER + X") frees it.
-- Saving in the DMS keybind editor rewrites this file and keeps only hl.bind/hl.unbind lines.

hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.exec_cmd("dms ipc call wallpaperCarousel toggle"), { description = "Wallpaper carousel" })
