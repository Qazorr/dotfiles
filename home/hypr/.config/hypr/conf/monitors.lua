-- The profile for whichever desk this is. Outside the repo: EDID descriptions
-- carry monitor serials. step_stow leaves a placeholder so this always loads.
dofile((os.getenv("MONITOR_PROFILES_DIR") or os.getenv("HOME") .. "/.config/monitor-profiles") .. "/active.lua")
