--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local NAME = "APHProfiler_UiLoad"
local SETTLE_MS = 2000
local RELOAD_DELAY_MS = 500
local RESUME_AGE_SEC = 300
local MAX_LOAD_MS = 600000
local AUTOSTART_CVAR = "StartLuaProfilingOnUILoad"

local settling = false

function APHP.CanProfileUiLoad()
	return not IsConsoleUI() and type(GetCVar) == "function" and type(SetCVar) == "function" and type(ReloadUI) == "function"
		and type(IsScriptProfilerEnabled) == "function"
end

function APHP.ProfilesUiLoad()
	return APHP.saved.profile_ui_load == true and APHP.CanProfileUiLoad()
end

function APHP.IsUiLoadSettling()
	return settling
end

local function Reload()
	APHP.saved.ui_load_scan = { ts = GetTimeStamp(), ms = GetGameTimeMilliseconds() }
	SetCVar(AUTOSTART_CVAR, "1")
	APHP.Print(APHP.L("RELOADING_TO_PROFILE_UI_LOAD"), true)
	zo_callLater(function() ReloadUI("ingame") end, RELOAD_DELAY_MS)
	return true
end

function APHP.StartUiLoadScan()
	if not APHP.CanProfileUiLoad() then return false end
	return Reload()
end

local function StopAfterSettle()
	settling = true
	EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_PLAYER_ACTIVATED)
		EVENT_MANAGER:RegisterForUpdate(NAME, SETTLE_MS, function()
			EVENT_MANAGER:UnregisterForUpdate(NAME)
			settling = false
			if APHP.IsRunning() then APHP.Stop() end
		end)
	end)
end

function APHP.ResumeUiLoadScan()
	local pending = APHP.saved.ui_load_scan
	APHP.saved.ui_load_scan = nil
	if type(pending) ~= "table" then return false end
	if APHP.CanProfileUiLoad() and GetCVar(AUTOSTART_CVAR) == "1" then SetCVar(AUTOSTART_CVAR, "0") end
	local age = GetTimeStamp() - (pending.ts or 0)
	if not (age <= RESUME_AGE_SEC and APHP.CanProfileUiLoad() and IsScriptProfilerEnabled()) then
		if APHP.CanProfileUiLoad() and IsScriptProfilerEnabled() then StopScriptProfiler() end
		APHP.Print(APHP.L("THE_UI_LOAD_WAS_NOT_PROFILED"), true)
		return false
	end
	local now = GetGameTimeMilliseconds()
	local started_at = pending.ms
	if type(started_at) ~= "number" or now - started_at <= 0 or now - started_at > MAX_LOAD_MS then started_at = now end
	if not APHP.AdoptRecording(started_at, "ui_load") then return false end
	StopAfterSettle()
	return true
end
