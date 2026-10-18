--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local UI, TIMING = AB.UI, AB.TIMING

local SEED = 20261013
local START_GAP_S = 2
local MENU_ROOM_MB = 4
local AFTER_COMBAT_S = 5
local FIRST = { { kind = "idle", length = 6 }, { kind = "combat", length = 3 }, { kind = "menu", length = 7 } }
local ACTIONS = {
	{ kind = "idle", weight = 40, low = 6, high = 30 },
	{ kind = "menu", weight = 35, low = 7, high = 20 },
	{ kind = "combat", weight = 25, low = 3, high = 8 },
}
local MENU_SCENES = { inventory = true, gamepad_inventory_root = true }

local PLAYER = { plans = {} }

function PLAYER.Plan(seconds)
	local plan = PLAYER.plans[seconds]
	if plan then return plan end
	local state = SEED + seconds
	local function Roll(low, high)
		state = state * 16807 % 2147483647
		return low + state % (high - low + 1)
	end
	plan = {}
	local at = math.min(TIMING.force_at, seconds * 500) / 1000 + START_GAP_S
	local function Add(kind, length)
		local last = plan[#plan]
		if last and last.kind == kind then
			last.to = at + length
		else
			plan[#plan + 1] = { kind = kind, from = at, to = at + length }
		end
		at = at + length
	end
	for _, first in ipairs(FIRST) do
		if at + first.length <= seconds then Add(first.kind, first.length) end
	end
	while true do
		local left = seconds - at
		local roll, action = Roll(1, 100), ACTIONS[#ACTIONS]
		for _, entry in ipairs(ACTIONS) do
			if roll <= entry.weight then
				action = entry
				break
			end
			roll = roll - entry.weight
		end
		if action.low > left then
			action = nil
			for _, entry in ipairs(ACTIONS) do
				if entry.low <= left and (not action or entry.low < action.low) then action = entry end
			end
		end
		if not action then break end
		Add(action.kind, math.min(Roll(action.low, action.high), left))
	end
	PLAYER.plans[seconds] = plan
	return plan
end

local function SceneName()
	local scene = SCENE_MANAGER:GetCurrentScene()
	return scene and scene:GetName(), scene
end

local function HudShown()
	local name, scene = SceneName()
	return (name == "hud" or name == "hudui") and scene:GetState() == SCENE_SHOWN
end

local function MenuOpen()
	return MENU_SCENES[SceneName() or ""] == true
end

local function Mark(phase, kind, second)
	local stats = phase.stats
	phase.player_event = { at = math.floor(second * 10 + 0.5) / 10, player = kind }
	stats.events[#stats.events + 1] = phase.player_event
end

local function OpenInventory()
	local menu = SYSTEMS and SYSTEMS:GetObject("mainMenu")
	if not (menu and menu.ToggleCategory) then return false end
	menu:ToggleCategory(MENU_CATEGORY_INVENTORY)
	return true
end

function PLAYER.Doing()
	local t = AB.test
	if not (t and t.player) then return nil end
	local ended = t.combat_ended_at
	if t.action_kind ~= "menu" and ended and GetGameTimeMilliseconds() - ended <= AFTER_COMBAT_S * 1000 then return "after_combat" end
	return t.action_kind
end

function PLAYER.Held(phase, who)
	local stats = phase and phase.stats
	if not (stats and phase.player_on) then return end
	phase.held_seen = phase.held_seen or {}
	local seen = phase.player_on .. who
	if phase.held_seen[seen] then return end
	phase.held_seen[seen] = true
	stats["held_" .. who] = (stats["held_" .. who] or 0) + 1
	stats.events[#stats.events + 1] = { at = math.floor((GetGameTimeMilliseconds() - stats.started) / 100 + 0.5) / 10, held = who }
end

function PLAYER.Stop(phase, second)
	local index = phase.player_on
	if not index then return end
	local action = PLAYER.Plan(AB.test.seconds)[index]
	local stats, event = phase.stats, phase.player_event
	phase.player_on, phase.player_event, AB.test.action_kind = nil, nil, nil
	second = second or (GetGameTimeMilliseconds() - AB.test.state_at) / 1000
	local length = math.max(math.min(second, action.to) - phase.player_from, 0)
	local kind = action.kind
	if kind == "combat" then
		AB.test.sim_combat, AB.test.combat_ended_at = nil, GetGameTimeMilliseconds()
	elseif kind == "menu" then
		if MenuOpen() then SCENE_MANAGER:ShowBaseScene() end
		if not event then return end
	end
	stats["player_" .. kind .. "s"] = (stats["player_" .. kind .. "s"] or 0) + 1
	stats["player_" .. kind .. "_s"] = (stats["player_" .. kind .. "_s"] or 0) + length
	if event then event.length = math.floor(length + 0.5) end
end

function PLAYER.Step(phase, now)
	local plan = PLAYER.Plan(AB.test.seconds)
	local second = (now - AB.test.state_at) / 1000
	local index = phase.player_at or 1
	while plan[index] and second >= plan[index].to do
		if phase.player_on == index then PLAYER.Stop(phase, second) end
		index = index + 1
	end
	phase.player_at = index
	local action = plan[index]
	if phase.player_on then
		if action.kind == "menu" and not phase.player_event and MenuOpen() then Mark(phase, "menu", second) end
		return
	end
	if not action or second < action.from or phase.player_done == index then return end
	if action.kind == "menu" then
		if not HudShown() then return end
		if UI.RoomMB() < MENU_ROOM_MB then
			phase.player_done = index
			phase.stats.player_skipped = (phase.stats.player_skipped or 0) + 1
			return
		end
		if not OpenInventory() then
			phase.player_done = index
			return
		end
	else
		if action.kind == "combat" then AB.test.sim_combat = true end
		Mark(phase, action.kind, second)
	end
	phase.player_on, phase.player_done, phase.player_from = index, index, second
	AB.test.action_kind = action.kind
end
AB.PLAYER = PLAYER
