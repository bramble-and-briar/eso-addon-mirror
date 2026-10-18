--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local Loads = {}
FG.Loads = Loads

local NS = FG.name .. "Loads"
local RESUME_AGE_SEC = 300
local MAX_LOAD_MS = 600000

local listening = false
local hooked = false
local left_at
local reload_from

function Loads.On()
	return FG.saved ~= nil and FG.saved.record_loads == true
end

function Loads.Forget()
	if not FG.saved then return end
	FG.saved.resume_rec, FG.saved.resume_at = nil, nil
end

local function Keep()
	local rec = FG.Sampler.ProgressCopy()
	if not rec then return end
	FG.saved.resume_rec = rec
	FG.saved.resume_at = { ms = GetGameTimeMilliseconds(), ts = GetTimeStamp() }
end

local function OnDeactivated()
	if not Loads.On() then return end
	left_at = GetGameTimeMilliseconds()
	FG.Sampler.SetPaused(true)
	Keep()
end

local function OnActivated()
	FG.Sampler.SetPaused(false)
	local now = GetGameTimeMilliseconds()
	if reload_from then
		local ms = reload_from.ms and now - reload_from.ms
		if not ms or ms <= 0 or ms > MAX_LOAD_MS then
			ms = reload_from.ts and (GetTimeStamp() - reload_from.ts) * 1000 or nil
		end
		reload_from = nil
		if ms then FG.Sampler.NoteLoad("reload", ms / 1000) end
		FG.RefreshResults()
		return
	end
	if not left_at then return end
	local ms = now - left_at
	left_at = nil
	Loads.Forget()
	if ms > 0 and ms < MAX_LOAD_MS then FG.Sampler.NoteLoad("load", ms / 1000) end
	FG.RefreshResults()
end

function Loads.Apply()
	if Loads.On() then
		if not hooked then
			hooked = true
			ZO_PreHook("ReloadUI", function()
				if Loads.On() then Keep() end
			end)
		end
		if not listening then
			listening = true
			EVENT_MANAGER:RegisterForEvent(NS, EVENT_PLAYER_DEACTIVATED, OnDeactivated)
			EVENT_MANAGER:RegisterForEvent(NS, EVENT_PLAYER_ACTIVATED, OnActivated)
		end
		return true
	end
	if listening then
		listening = false
		EVENT_MANAGER:UnregisterForEvent(NS, EVENT_PLAYER_DEACTIVATED)
		EVENT_MANAGER:UnregisterForEvent(NS, EVENT_PLAYER_ACTIVATED)
	end
	left_at, reload_from = nil, nil
	FG.Sampler.SetPaused(false)
	return false
end

function Loads.Resume()
	local saved_rec, at = FG.saved.resume_rec, FG.saved.resume_at
	Loads.Forget()
	if not (Loads.On() and type(saved_rec) == "table" and type(at) == "table") then return false end
	if GetTimeStamp() - (at.ts or 0) > RESUME_AGE_SEC then return false end
	if not FG.Sampler.ResumeRecording(saved_rec) then return false end
	reload_from = at
	FG.Sampler.SetPaused(true)
	Loads.Apply()
	return true
end
