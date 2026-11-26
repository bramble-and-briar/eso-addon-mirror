--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.CreateMenuLabelRefresher(addonPrefix, panelGetter)
	local refreshable = {}
	local next_id = 1

	local function collect_from(list)
		for _, entry in ipairs(list) do
			if type(entry) == "table" then
				if (entry.type == "checkbox" or entry.type == "slider" or entry.type == "button" or entry.type == "dropdown")
					and type(entry.name) == "function" then
					entry.reference = entry.reference or (addonPrefix .. tostring(next_id))
					next_id = next_id + 1
					table.insert(refreshable, { reference = entry.reference, kind = entry.type })
				end
				if entry.type == "submenu" and entry.controls then
					collect_from(entry.controls)
				end
			end
		end
	end

	local function refresh(control)
		local lam = LibAddonMenu2 or _G["LibAddonMenu2"]
		if not lam or not lam.util or not lam.util.GetTopPanel then return end
		if lam.util.GetTopPanel(control) ~= panelGetter() then return end
		for _, entry in ipairs(refreshable) do
			local ctrl = _G[entry.reference]
			if ctrl and ctrl.data then
				local text = lam.util.GetStringFromValue(ctrl.data.name)
				if entry.kind == "button" then
					if ctrl.button then ctrl.button:SetText(text) end
				elseif ctrl.label then
					ctrl.label:SetText(text)
				end
			end
		end
	end

	return { CollectFrom = collect_from, Refresh = refresh }
end
