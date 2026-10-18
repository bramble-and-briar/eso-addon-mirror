--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local NAME, Say = AB.NAME, AB.Say

local MEM = {}
AB.MEM = MEM

function MEM.Set(on, quiet)
	AB.saved.memory_display = on or nil
	LibAPH.SetMemoryDisplay(NAME, on)
	if not quiet then Say("Memory display " .. (on and "on." or "off.")) end
end

function MEM.Toggle()
	MEM.Set(not AB.saved.memory_display)
end
