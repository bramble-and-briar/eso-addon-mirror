--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not AutoLuaMemoryCleaner then return end
local ALC = AutoLuaMemoryCleaner
ALC.PC = ALC.PC or {}
local ALC_PC = ALC.PC

function ALC_PC.get_active_memory_mb()
	return ALC.get_hybrid_memory_data()
end

function ALC_PC.get_threshold()
	return ALC.settings.threshold_pc
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
		name = function() return ALC.L("SLIDER_PC_RELOAD_THRESHOLD") end,
		min = 100, max = 1500, step = 10,
		getFunc = function() return ALC.settings.reload_threshold_pc end,
		setFunc = function(v) ALC.settings.reload_threshold_pc = v end,
		disabled = function() return not ALC.settings.is_enabled end
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