--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local GS = AB.GS

function GS.HeldText(held)
	local names = LibAPH.GetHeldGameSettingNames(held)
	if #names == 0 then return nil end
	return "Off during the test: " .. table.concat(names, ", ") .. "."
end

function GS.SetFps(text)
	if AB.test then return AB.Say("Not while a test is running; a new FPS cap would change the test's conditions.") end
	local word = string.lower(zo_strtrim(tostring(text or "")))
	if word == "" then
		return AB.Say(string.format("Type /alcbench setfps followed by %d to %d, or uncapped.", LibAPH.FPS_CAP_MIN, LibAPH.FPS_CAP_MAX))
	end
	if not LibAPH.SetFpsCap(word) then
		return AB.Say(string.format("Type a number from %d to %d, or uncapped. Example: /alcbench setfps 60", LibAPH.FPS_CAP_MIN, LibAPH.FPS_CAP_MAX))
	end
	local cap = LibAPH.GetFpsCap()
	local done = (cap and ("FPS cap: " .. cap) or "No FPS cap set") .. "."
	AB.Say(done)
	LibAPH.SafeCSA(true, "ALC Benchmark", done, 4000)
end

function AB.FillHold()
	local saved, timing = AB.saved, AB.TIMING
	local advanced = saved.advanced_test == true
	local hold_s = advanced and saved.fill_hold_s or nil
	if IsConsoleUI() then return nil, advanced and saved.fill_hold_pool or timing.fill_hold_pool_console, hold_s end
	return advanced and saved.fill_hold_mb or timing.fill_hold_mb_pc, nil, hold_s
end
