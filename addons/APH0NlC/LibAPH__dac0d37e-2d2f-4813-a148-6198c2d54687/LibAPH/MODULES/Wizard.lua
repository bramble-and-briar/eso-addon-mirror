--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.ScheduleWizardIfNeeded(isCompleted, runFn, delayMs)
	if isCompleted then return end
	zo_callLater(runFn, delayMs or 3000)
end

function LibAPH.AutoUnloadWizardModule(settings, toggleFn)
	if not (settings.module_disabled and settings.module_disabled.wizard) then
		toggleFn("wizard", true)
	end
end
