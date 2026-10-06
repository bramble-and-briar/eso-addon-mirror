--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC
ALC.PC = ALC.PC or {}
local ALC_PC = ALC.PC

function ALC_PC.get_active_memory_mb()
	return ALC.get_hybrid_memory_data()
end

function ALC_PC.get_threshold()
	return ALC.settings.threshold_pc
end

function ALC_PC.get_pool_threshold()
	return ALC.settings.pool_threshold_pc
end

function ALC_PC.build_threshold_slider(build_data)
	table.insert(build_data, {
		type = "slider",
		name = function() return ALC.L("SLIDER_PC_LUA_THRESHOLD") end,
		min = 50, max = 800, step = 1,
		getFunc = function() return ALC.settings.threshold_pc end,
		setFunc = function(v) ALC.settings.threshold_pc = v end,
		disabled = function() return not ALC.settings.is_enabled end
	})
end

function ALC_PC.build_pool_threshold_slider(build_data)
	table.insert(build_data, {
		type = "slider",
		name = function() return ALC.L("SLIDER_PC_POOL_THRESHOLD") end,
		min = 0.01, max = 800, step = 0.5, decimals = 2,
		getFunc = function() return ALC.settings.pool_threshold_pc end,
		setFunc = function(v) ALC.settings.pool_threshold_pc = v end,
		disabled = function() return not ALC.settings.auto_clear_pool_on_teleport end
	})
end

function ALC_PC.build_extra_options(build_data)
	table.insert(build_data, {
		type = "checkbox",
		name = function() return ALC.L("CHK_CHAT_LOGS") end,
		getFunc = function() return ALC.settings.is_log_enabled end,
		setFunc = function(v) ALC.settings.is_log_enabled = v end
	})
end