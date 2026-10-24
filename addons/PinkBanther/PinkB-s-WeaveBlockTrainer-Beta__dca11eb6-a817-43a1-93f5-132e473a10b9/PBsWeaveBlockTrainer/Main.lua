-- PB's Weave & Block Trainer
-- Author: PinkBanther
--
-- A timing aid for two habits every damage rotation is built on:
--
--     * weaving     -- a light attack just before each skill, so both land inside one
--                      1-second global cooldown;
--     * block-cancel -- tapping block right after an instant skill, to cut its animation.
--
-- ---------------------------------------------------------------------------------------
-- WHAT THIS ADD-ON DOES NOT DO
-- ---------------------------------------------------------------------------------------
--
-- It never presses anything. Add-on Lua cannot attack, cast or block -- there is no API for
-- it, and automating combat input is against the game's terms. Everything below reads game
-- events and draws a bar; the player's own buttons do the rest.
--
-- ---------------------------------------------------------------------------------------
-- HOW THE TIMING IS READ
-- ---------------------------------------------------------------------------------------
--
-- EVENT_ACTION_SLOT_ABILITY_USED fires when a slotted skill (slots 3-7, ultimate 8) goes off.
-- That is the anchor: the next skill is possible one cycle later, and the light attack belongs
-- in the last few hundred ms before it. With no new skill the bar keeps counting whole cycles
-- from the last anchor, so the rhythm survives a missed cast.
--
-- Light attacks have no "used" event of their own. They are recognised from EVENT_COMBAT_EVENT
-- by abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK with the player as source. That is
-- the unmeasured part of this add-on; /weave debug prints what actually arrives.
--
-- The block cue skips channelled and cast-time skills (GetAbilityCastInfo), because blocking
-- interrupts them. Success is a rising edge of IsBlockActive() inside the window, so holding
-- block through a cast does not count as a cancel.
--
-- The HUD is only drawn while the hud / hudui scene is up. That is a "StateChange" callback
-- registered beside the client's own -- nothing of the client's is hooked or called.
-- ---------------------------------------------------------------------------------------

if PBS_WEAVEBLOCKTRAINER then
	return
end

local addon = {
	name = "PBsWeaveBlockTrainer",
	title = "PB’s Weave & Block Trainer",
	author = "PinkBanther",
	version = "1.4.0", -- keep in step with ## Version in the manifest
}
PBS_WEAVEBLOCKTRAINER = addon

local em = EVENT_MANAGER
local wm = WINDOW_MANAGER

local FIRST_SKILL_SLOT = 3
local LAST_SKILL_SLOT = 8 -- ultimate
local IDLE_CYCLES = 4 -- out of combat, the bar stops after this many cycles with no skill
-- Long enough to read the numbers under the box. The next skill clears it anyway, so in a
-- rotation these are never reached.
local OK_SHOW_MS = 800
local EXCELLENT_SHOW_MS = 1500
local BLOCK_BOX_WIDTH = 160
local EXCELLENT_BOX_WIDTH = 280
local BAR_WIDTH = 320
local BAR_HEIGHT = 14

addon.DEFAULTS = {
	enabled = true,
	metronome = true,
	sound = true,
	cycleMs = 1000,
	leadMs = 250,
	combatOnly = true,
	blockCue = true,
	windowMs = 300,
	offsetX = 0,
	offsetY = 180,
}

-- ---- state --------------------------------------------------------------------------
local state = {
	anchor = nil, -- ms of the last skill (or combat start)
	zoneBeat = -1, -- cycle index whose zone has already ticked
	lastLA = nil, -- ms of the last light attack
	inCombat = false,
	hudShown = false,
	debug = false,

	blockOpenAt = nil, -- ms the current window opened, nil when closed
	blockHeldAtOpen = false,
	blockOkUntil = 0,
	weaveMs = nil, -- light attack > skill, in ms, for the skill that opened the block window; nil if no light attack came first
	blockMs = nil, -- skill > block, in ms, once the block lands
	totalMs = nil, -- light attack > block, in ms; only when the whole chain is made
	excellent = false, -- the block that closed it made the whole chain: light attack > skill > block
}

local ui = {}

local function Now()
	return GetFrameTimeMilliseconds()
end

local function Debug(fmt, ...)
	if state.debug then
		d(string.format("[WeaveBlock %d] " .. fmt, Now(), ...))
	end
end

-- ---- UI -----------------------------------------------------------------------------
local function Solid(name, parent, r, g, b, a)
	local tex = wm:CreateControl(name, parent, CT_TEXTURE)
	tex:SetColor(r, g, b, a)
	return tex
end

local function BuildUI()
	local top = wm:CreateTopLevelWindow("PBsWeaveBlockTrainerTop")
	top:SetDimensions(BAR_WIDTH, 120)
	top:SetMouseEnabled(false)
	top:SetMovable(false)
	top:SetHidden(true)
	ui.top = top

	-- metronome
	local cue = wm:CreateControl("$(parent)Cue", top, CT_LABEL)
	cue:SetFont("ZoFontGamepadBold27")
	cue:SetAnchor(BOTTOM, top, TOP, 0, 38)
	cue:SetText(GetString(SI_PBSWT_CUE))
	ui.cue = cue

	local bg = Solid("$(parent)BarBg", top, 0, 0, 0, 0.55)
	bg:SetDimensions(BAR_WIDTH, BAR_HEIGHT)
	bg:SetAnchor(TOP, top, TOP, 0, 42)
	ui.barBg = bg

	local zone = Solid("$(parent)Zone", bg, 1, 0.8, 0.2, 0.35)
	zone:SetAnchor(TOPRIGHT, bg, TOPRIGHT, 0, 0)
	zone:SetDrawLevel(1)
	ui.zone = zone

	local fill = Solid("$(parent)Fill", bg, 0.4, 0.75, 1, 0.9)
	fill:SetAnchor(TOPLEFT, bg, TOPLEFT, 0, 0)
	fill:SetDrawLevel(2)
	ui.fill = fill

	local result = wm:CreateControl("$(parent)Result", top, CT_LABEL)
	result:SetFont("ZoFontGamepad22")
	result:SetAnchor(TOP, bg, BOTTOM, 0, 2)
	ui.result = result

	-- block cue
	local blockBg = Solid("$(parent)BlockBg", top, 1, 0.85, 0.1, 0.85)
	blockBg:SetDimensions(160, 40)
	blockBg:SetAnchor(TOP, bg, BOTTOM, 0, 34)
	ui.blockBg = blockBg

	local block = wm:CreateControl("$(parent)Block", blockBg, CT_LABEL)
	block:SetFont("ZoFontGamepadBold27")
	block:SetAnchor(CENTER, blockBg, CENTER, 0, 0)
	block:SetColor(0, 0, 0, 1)
	block:SetDrawLevel(1)
	ui.block = block

	-- skill > block time, and the total when the chain is complete
	local detail = wm:CreateControl("$(parent)Detail", top, CT_LABEL)
	detail:SetFont("ZoFontGamepad22")
	detail:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	detail:SetAnchor(TOP, blockBg, BOTTOM, 0, 4)
	ui.detail = detail
end

function addon:ApplyLayout()
	local sv = self.sv
	ui.top:ClearAnchors()
	ui.top:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX, sv.offsetY)
	ui.zone:SetDimensions(BAR_WIDTH * math.min(1, sv.leadMs / sv.cycleMs), BAR_HEIGHT)
end

-- ---- visibility ---------------------------------------------------------------------
-- The top-level control only receives OnUpdate while it is shown, so hiding it is also what
-- stops the per-frame work.
local function MetronomeActive(now)
	local sv = addon.sv
	if not sv.metronome or not state.anchor then
		return false
	end
	if state.inCombat then
		return true
	end
	if sv.combatOnly then
		return false
	end
	return now - state.anchor < sv.cycleMs * IDLE_CYCLES
end

local function BlockActive(now)
	return state.blockOpenAt ~= nil or now < state.blockOkUntil
end

local function RefreshVisibility()
	local now = Now()
	local want = addon.sv.enabled and state.hudShown and (MetronomeActive(now) or BlockActive(now))
	ui.top:SetHidden(not want)
end

-- ---- per frame ----------------------------------------------------------------------
local function UpdateMetronome(now)
	local sv = addon.sv
	local active = MetronomeActive(now)
	ui.cue:SetHidden(not active)
	ui.barBg:SetHidden(not active)
	ui.result:SetHidden(not active)
	if not active then
		return
	end

	local cycle = sv.cycleMs
	local elapsed = now - state.anchor
	local beat = zo_floor(elapsed / cycle)
	local inCycle = elapsed - beat * cycle
	local inZone = inCycle >= cycle - sv.leadMs

	ui.fill:SetDimensions(zo_max(1, BAR_WIDTH * inCycle / cycle), BAR_HEIGHT)
	if inZone then
		ui.fill:SetColor(1, 0.8, 0.2, 1)
		ui.cue:SetColor(1, 0.85, 0.2, 1)
		if state.zoneBeat ~= beat then
			state.zoneBeat = beat
			if sv.sound then
				PlaySound(SOUNDS.COUNTDOWN_TICK)
			end
		end
	else
		ui.fill:SetColor(0.4, 0.75, 1, 0.9)
		ui.cue:SetColor(1, 1, 1, 0.45)
	end
end

local function UpdateBlock(now)
	local blocking = IsBlockActive()
	if state.blockOpenAt then
		if blocking and not state.blockHeldAtOpen then
			state.blockMs = now - state.blockOpenAt
			state.blockOpenAt = nil
			state.excellent = state.weaveMs ~= nil
			state.totalMs = state.excellent and (state.weaveMs + state.blockMs) or nil
			Debug("block cancel +%d ms", state.blockMs)
			state.blockOkUntil = now + (state.excellent and EXCELLENT_SHOW_MS or OK_SHOW_MS)
			if state.excellent then
				Debug("excellent: light attack > skill > block, total %d ms", state.totalMs)
			end
		elseif now - state.blockOpenAt > addon.sv.windowMs then
			Debug("block window closed without a block")
			state.blockOpenAt = nil
		elseif not blocking then
			state.blockHeldAtOpen = false
		end
	end

	if state.blockOpenAt then
		ui.blockBg:SetHidden(false)
		ui.blockBg:SetDimensions(BLOCK_BOX_WIDTH, 40)
		ui.blockBg:SetColor(1, 0.85, 0.1, 0.85)
		ui.block:SetText(GetString(SI_PBSWT_BLOCK))
		ui.detail:SetHidden(true)
	elseif now < state.blockOkUntil then
		ui.blockBg:SetHidden(false)
		if state.excellent then
			ui.blockBg:SetDimensions(EXCELLENT_BOX_WIDTH, 40)
			ui.blockBg:SetColor(1, 0.41, 0.71, 0.95)
			ui.block:SetText(GetString(SI_PBSWT_EXCELLENT))
			ui.detail:SetText(
				string.format(GetString(SI_PBSWT_BLOCK_TIME), state.blockMs)
					.. "\n"
					.. string.format(GetString(SI_PBSWT_TOTAL), state.totalMs)
			)
		else
			ui.blockBg:SetDimensions(BLOCK_BOX_WIDTH, 40)
			ui.blockBg:SetColor(0.3, 0.9, 0.4, 0.85)
			ui.block:SetText(GetString(SI_PBSWT_BLOCK_OK))
			ui.detail:SetText(string.format(GetString(SI_PBSWT_BLOCK_TIME), state.blockMs))
		end
		ui.detail:SetHidden(false)
	else
		ui.blockBg:SetHidden(true)
		ui.detail:SetHidden(true)
	end
end

local function OnUpdate()
	local now = Now()
	UpdateMetronome(now)
	UpdateBlock(now)
	if not (MetronomeActive(now) or BlockActive(now)) then
		ui.top:SetHidden(true)
	end
end

-- ---- events -------------------------------------------------------------------------
local function SlotAbilityId(slot)
	local hotbar = GetActiveHotbarCategory()
	local id = GetSlotBoundId(slot, hotbar)
	if GetSlotType(slot, hotbar) == ACTION_TYPE_CRAFTED_ABILITY and GetAbilityIdForCraftedAbilityId then
		id = GetAbilityIdForCraftedAbilityId(id)
	end
	return id
end

local function OnSlotAbilityUsed(_, slot)
	if slot < FIRST_SKILL_SLOT or slot > LAST_SKILL_SLOT then
		Debug("slot %d used (not a skill slot)", slot)
		return
	end
	local now = Now()
	local sv = addon.sv

	-- feedback on the weave that just finished
	local weaveMs
	local wove = state.lastLA ~= nil
		and state.anchor ~= nil
		and state.lastLA > state.anchor
		and now - state.lastLA <= sv.cycleMs
	if wove then
		weaveMs = now - state.lastLA
		ui.result:SetText(string.format(GetString(SI_PBSWT_WOVE), weaveMs))
		ui.result:SetColor(0.5, 1, 0.5, 1)
	else
		ui.result:SetText(GetString(SI_PBSWT_NO_LA))
		ui.result:SetColor(0.7, 0.7, 0.7, 1)
	end

	state.anchor = now
	state.zoneBeat = -1
	-- a new skill ends whatever the last one left on screen, and decides the next chain
	state.weaveMs = weaveMs
	state.blockMs = nil
	state.totalMs = nil
	state.excellent = false
	state.blockOkUntil = 0

	local abilityId = SlotAbilityId(slot)
	local channeled, castMs = GetAbilityCastInfo(abilityId, nil, "player")
	local instant = not channeled and (castMs or 0) <= 0
	Debug(
		"skill slot %d id %d %s channeled=%s cast=%s",
		slot,
		abilityId or 0,
		GetAbilityName(abilityId, "player") or "?",
		tostring(channeled),
		tostring(castMs)
	)

	if sv.blockCue and instant then
		state.blockOpenAt = now
		state.blockHeldAtOpen = IsBlockActive()
	end
	RefreshVisibility()
end

local function OnCombatEvent(_, result, isError, abilityName, _, slotType, _, _, _, _, _, _, _, _, _, _, abilityId)
	if isError or slotType ~= ACTION_SLOT_TYPE_LIGHT_ATTACK then
		return
	end
	local now = Now()
	-- one light attack can report several results; count it once
	if state.lastLA and now - state.lastLA < 150 then
		return
	end
	state.lastLA = now
	Debug("light attack result %d id %d %s", result, abilityId or 0, abilityName or "?")
end

local function OnCombatState(_, inCombat)
	state.inCombat = inCombat
	if inCombat and not state.anchor then
		state.anchor = Now()
		state.zoneBeat = -1
	elseif not inCombat and addon.sv.combatOnly then
		state.anchor = nil
		ui.result:SetText("")
	end
	Debug("combat %s", tostring(inCombat))
	RefreshVisibility()
end

local function OnHudStateChange()
	state.hudShown = HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()
	RefreshVisibility()
end

-- ---- public -------------------------------------------------------------------------
function addon:SetEnabled(value)
	self.sv.enabled = value
	RefreshVisibility()
end

function addon:Set(key, value)
	self.sv[key] = value
	self:ApplyLayout()
	RefreshVisibility()
end

function addon:Reset()
	for key, value in pairs(self.DEFAULTS) do
		self.sv[key] = value
	end
	self:ApplyLayout()
	RefreshVisibility()
end

local function OnSlash(arg)
	arg = zo_strlower(zo_strtrim(arg or ""))
	if arg == "on" then
		addon:SetEnabled(true)
		d(GetString(SI_PBSWT_ON))
	elseif arg == "off" then
		addon:SetEnabled(false)
		d(GetString(SI_PBSWT_OFF))
	elseif arg == "debug" then
		state.debug = not state.debug
		d(GetString(state.debug and SI_PBSWT_DEBUG_ON or SI_PBSWT_DEBUG_OFF))
	else
		d(GetString(SI_PBSWT_HELP))
	end
end

-- ---- load ---------------------------------------------------------------------------
local function OnPlayerActivated()
	em:UnregisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED)
	-- chat is up by now; a line printed at EVENT_ADD_ON_LOADED is lost
	d(string.format(GetString(SI_PBSWT_LOADED), addon.version))
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.sv = ZO_SavedVars:NewAccountWide("PBsWeaveBlockTrainer_Data", 1, nil, addon.DEFAULTS)

	BuildUI()
	addon:ApplyLayout()
	ui.top:SetHandler("OnUpdate", OnUpdate)

	state.inCombat = IsUnitInCombat("player")

	em:RegisterForEvent(addon.name, EVENT_ACTION_SLOT_ABILITY_USED, OnSlotAbilityUsed)
	em:RegisterForEvent(addon.name, EVENT_COMBAT_EVENT, OnCombatEvent)
	em:AddFilterForEvent(addon.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
	em:RegisterForEvent(addon.name, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
	em:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

	HUD_SCENE:RegisterCallback("StateChange", OnHudStateChange)
	HUD_UI_SCENE:RegisterCallback("StateChange", OnHudStateChange)
	OnHudStateChange()

	SLASH_COMMANDS["/weave"] = OnSlash

	if addon.InitSettings then
		addon:InitSettings()
	end
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
