--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.TrackSubmenuOpenState(savedTable, reference)
	local control = _G[reference]
	if not control or not control.label or control.__libAPHSubmenuStateTracked then return end
	control.__libAPHSubmenuStateTracked = true

	local function save_state()
		savedTable[reference] = control.open
	end

	local function chain(existing)
		return function(...)
			if existing then existing(...) end
			save_state()
		end
	end

	control.label:SetHandler("OnMouseUp", chain(control.label:GetHandler("OnMouseUp")))
	if control.icon then
		control.icon:SetHandler("OnMouseUp", chain(control.icon:GetHandler("OnMouseUp")))
	end
	if control.btmToggle then
		control.btmToggle:SetHandler("OnMouseUp", chain(control.btmToggle:GetHandler("OnMouseUp")))
	end
end

function LibAPH.RestoreSubmenuOpenState(savedTable, reference)
	if not savedTable[reference] then return end
	local control = _G[reference]
	if not control or control.open or control.disabled or not control.animation then return end
	control.open = true
	control.animation:PlayFromStart()
end

function LibAPH.PersistSubmenuOpenState(savedTable, reference)
	LibAPH.RestoreSubmenuOpenState(savedTable, reference)
	LibAPH.TrackSubmenuOpenState(savedTable, reference)
end
