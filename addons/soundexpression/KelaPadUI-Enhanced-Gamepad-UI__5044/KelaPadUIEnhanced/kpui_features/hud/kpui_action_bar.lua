-- Gamepad action bar enhancements.
-- Decorates the game's own action bar instead of replacing it:
--   * stack counts on both bars, including stacks kept on a separate player buff
--     (Seething Fury for Molten Whip, Crux for Arcanist skills, and so on);
--   * the inactive (back) bar timer turns red shortly before it ends;
--   * the inactive bar can be raised to show more of each skill icon, and its
--     thin timer bar can be replaced with a seconds countdown.
-- The game builds the inactive bar from ZO_ActionBarTimer objects (controls
-- ActionBarTimer3..8). They sit behind the front buttons and only peek out
-- above them.

local NAMESPACE = "KelaPadUIEnhanced_ActionBar"
local KELA_OPTIONS_SCENE_NAME = "kela_options_root"

local FIRST_SLOT = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local LAST_NORMAL_SLOT = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1
local ULTIMATE_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1

-- Matches the game's own stack count label on gamepad buttons.
local STACK_FONT_FRONT = "ZoFontGamepad27"
-- The back row's stack count takes the largest of these that fits beside the
-- countdown (see FitBackStackFont).
local STACK_FONTS_BACK = { "ZoFontGamepadBold25", "ZoFontGamepad25", "ZoFontGamepadBold22", "ZoFontGamepad22", "ZoFontGamepadBold20", "ZoFontGamepad20" }
local SECONDS_FONT = "ZoFontGamepad22"
-- The gamepad back-slot frame art spends its top 12 pixels on the timer bar:
-- a 3 px top border, then the bar's groove (the bar itself sits at 3-11), above
-- the 44 px icon. Seconds mode cuts that strip out of the slot so no empty
-- groove is left behind, and redraws the 3 px border on top of what remains.
local TIMER_STRIP_HEIGHT = 12
local TIMER_TOP_LINE_HEIGHT = 3
-- The back row's stack count and countdown share one height: their bottom edges
-- sit this far below the front button's top edge.
local BACK_LABEL_DROP = 2
-- The countdown is a smaller font than the count, so its text sits lower in the
-- same box height; lifting it lines the two up by eye.
local BACK_TIMER_LIFT = 2
-- Fired by the Ability Bar settings rows so changes apply while the menu is open.
local SETTINGS_CHANGED_EVENT = "KELA_ACTIONBAR_SETTINGS_CHANGED"
local STACK_COLOR = ZO_ColorDef:New("DCD822")
local WARN_COLOR = ZO_ColorDef:New("FF6B6B")
local SECONDS_COLOR = ZO_ColorDef:New("FFFFFF")
local WARN_GRADIENT = { ZO_ColorDef:New("D44B4B"), ZO_ColorDef:New("FF6B6B") }
-- The back row's countdown (left) and stack count (right) sit this far in from
-- the back slot's own edges.
local BACK_TIMER_INSET_X = 8
local BACK_STACK_INSET_X = 8
-- The widest each can get, and the least space left between them: the countdown
-- under 2 s shows tenths ("8.8"), the count is one digit.
local TIMER_SAMPLE_TEXT = "8.8"
local STACK_SAMPLE_TEXT = "8"
local BACK_LABEL_MIN_GAP = 3
-- The game's own timers switch to tenths of a second under this (ms).
local DECIMAL_UNDER_MS = (ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S or 2) * 1000
local backStackFont
-- The native front stack label sits at CENTER +23,-20 on gamepad buttons.
local FRONT_STACK_OFFSET_X = 23
local FRONT_STACK_OFFSET_Y = -20

-- Buffs that hold a stack count for a slotted skill whose own effect does not.
-- [buff ability ID] = { slotted skill IDs that show the count }.
-- IDs cross-checked against Fancy Action Bar+ (config.lua stackMap).
local STACK_BUFFS =
{
	-- Seething Fury (Dragonknight Molten Whip)
	[122658] = { 20805 },
	-- Grim Focus, Merciless Resolve, Relentless Focus (Nightblade)
	[122585] = { 61902 },
	[122586] = { 61919 },
	[122587] = { 61927 },
	-- Bound Armaments (Sorcerer)
	[203447] = { 24165 },
	-- Crux (Arcanist): each skill appears with its magicka and stamina IDs.
	[184220] =
	{
		185794, 188658, -- Runeblades
		185803, 188787, -- Writhing Runeblades
		182977, 188780, -- Escalating Runeblades
		185805, 193331, -- Fatecarver
		183122, 193397, -- Exhausting Fatecarver
		186366, 193398, -- Pragmatic Fatecarver
		183261, 198282, -- Runemend
		186189, 198288, -- Evolving Runemend
		186191, 198292, -- Audacious Runemend
		183537, 198309, -- Remedy Cascade
		186193, 198330, -- Cascading Fortune
		186200, 198537, -- Curative Surge
		183447, 198563, -- Chakram Shields
		186207, 198564, -- Chakram of Destiny
		186209, 198567, -- Tidal Chakram
		183241, 184362, -- Impervious Runeward
		185901, -- Spiteward
		185823, -- Tentacular Dread
		238174, -- Vengeance Fatecarver
		238249, -- Vengeance Runespite Ward
		238482, -- Vengeance Remedy Cascade
	},
}

local SLOTTED_TO_BUFF = {}
for buffId, skillIds in pairs(STACK_BUFFS) do
	for _, skillId in ipairs(skillIds) do
		SLOTTED_TO_BUFF[skillId] = buffId
	end
end

local buffStacks = {}
-- When a tracked buff ends (game time in seconds, as GetFrameTimeSeconds reports
-- it) and how long it lasts in ms; nil for a buff without an expiry.
local buffEnds = {}
local buffDurationsMS = {}
local loggedBuffs = {}
local backTimers = {}
local frontStackLabels = {}
local backStackLabels = {}
local secondsLabels = {}
local hooksInstalled = false

-- Settings are read on setup and whenever the add-on's settings close, so the
-- per-frame timer hook never touches saved variables.
local settings =
{
	showStacks = true,
	warnMS = 3000,
	raise = 0,
	showBar = true,
	showNumbers = false,
	alwaysShow = false,
}

local function Log(level, message)
	local logger = KelaPadUI and KelaPadUI.log
	if logger then
		logger[level](logger, message)
	end
end

local function IsGamepad()
	return IsInGamepadPreferredMode()
end

local function RefreshSettings()
	settings.showStacks = KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_ACTIONBAR_STACKS)
	settings.warnMS = (KelaGetSetting_Number(SETTING_TYPE_KELA, KELA_SETTING_PANEL_ACTIONBAR_EXPIRY_WARNING) or 0) * 1000
	settings.raise = KelaGetSetting_Number(SETTING_TYPE_KELA, KELA_SETTING_PANEL_ACTIONBAR_RAISE) or 0
	settings.showBar = KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_ACTIONBAR_BAR)
	settings.showNumbers = KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_ACTIONBAR_SECONDS)
	settings.alwaysShow = KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_ACTIONBAR_ALWAYS_SHOW)
end

local function ForEachSlot(callback)
	for slot = FIRST_SLOT, LAST_NORMAL_SLOT do
		callback(slot)
	end
	callback(ULTIMATE_SLOT)
end

local function GetBackHotbarCategory()
	local active = GetActiveHotbarCategory()
	if active == HOTBAR_CATEGORY_PRIMARY then
		return HOTBAR_CATEGORY_BACKUP
	elseif active == HOTBAR_CATEGORY_BACKUP then
		return HOTBAR_CATEGORY_PRIMARY
	end
	return nil
end

-- The ZO_ActionBarTimer for a physical slot. ZO_ActionBar_GetButton returns it
-- for whichever category is currently the back bar.
local function FindBackTimer(slot)
	if backTimers[slot] then
		return backTimers[slot]
	end
	for _, category in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
		local object = ZO_ActionBar_GetButton(slot, category)
		if object and object.fillStatusBar then
			backTimers[slot] = object
			return object
		end
	end
	return nil
end

local function GetSlottedAbilityId(slot, category)
	local id = GetSlotBoundId(slot, category)
	if id and id ~= 0 and GetSlotType(slot, category) == ACTION_TYPE_CRAFTED_ABILITY then
		id = GetAbilityIdForCraftedAbilityId(id)
	end
	return id
end

local function GetLinkedStacks(slot, category)
	if not category then
		return 0
	end
	local buffId = SLOTTED_TO_BUFF[GetSlottedAbilityId(slot, category)]
	return buffId and buffStacks[buffId] or 0
end

local function CreateLabel(name, parent, font)
	local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	label:SetFont(font)
	label:SetDrawTier(DT_HIGH)
	label:SetHidden(true)
	return label
end

-- Stack labels are parented to the front buttons, so they show even when the
-- game hides a back slot (it does so for skills without a running effect).
local function GetFrontStackLabel(slot, button)
	local label = frontStackLabels[slot]
	if not label then
		label = CreateLabel("KelaFrontStack" .. slot, button.slot, STACK_FONT_FRONT)
		label:SetColor(STACK_COLOR:UnpackRGBA())
		label:SetAnchor(CENTER, button.slot, CENTER, FRONT_STACK_OFFSET_X, FRONT_STACK_OFFSET_Y)
		frontStackLabels[slot] = label
	end
	return label
end

-- Picks the largest stack count font that fits beside the countdown in the room
-- the back slot leaves between them, measured with the labels' own fonts. The
-- label is left set to the font it picked.
local function FitBackStackFont(label, slotWidth)
	label:SetFont(SECONDS_FONT)
	local timerWidth = label:GetStringWidth(TIMER_SAMPLE_TEXT) or 0
	local room = slotWidth - BACK_TIMER_INSET_X - BACK_STACK_INSET_X - timerWidth - BACK_LABEL_MIN_GAP
	local chosen, chosenWidth = STACK_FONTS_BACK[#STACK_FONTS_BACK], 0
	for _, font in ipairs(STACK_FONTS_BACK) do
		label:SetFont(font)
		local width = label:GetStringWidth(STACK_SAMPLE_TEXT) or 0
		chosen, chosenWidth = font, width
		if width <= room then
			break
		end
	end
	label:SetFont(chosen)
	Log("Info", string.format("Action bar: back row text: countdown %.1f px, count %.1f px (%s), room %.1f px", timerWidth, chosenWidth, chosen, room))
	return chosen
end

local function GetBackStackLabel(slot, button)
	local label = backStackLabels[slot]
	if not label then
		label = CreateLabel("KelaBackBarStack" .. slot, button.slot, backStackFont or STACK_FONTS_BACK[1])
		label:SetColor(STACK_COLOR:UnpackRGBA())
		backStackLabels[slot] = label
		if not backStackFont then
			local timer = FindBackTimer(slot)
			backStackFont = FitBackStackFont(label, timer and timer.slot:GetWidth() or 52)
		end
	end
	-- The back slot is narrower than the front button and centered on it; keep
	-- the count inside the back icon's right edge, just above the front button.
	local timer = FindBackTimer(slot)
	local inset = 0
	if timer then
		inset = zo_max(0, (button.slot:GetWidth() - timer.slot:GetWidth()) / 2)
	end
	-- Anchors only change when the inset does, not on every refresh.
	if label.kelaInset ~= inset then
		label.kelaInset = inset
		label:ClearAnchors()
		label:SetAnchor(BOTTOMRIGHT, button.slot, TOPRIGHT, -(inset + BACK_STACK_INSET_X), BACK_LABEL_DROP)
	end
	return label
end

-- Shows a count, or hides the label for 0. The text is only set when it changes.
local function ShowCount(label, count)
	if count > 0 then
		if label.kelaCount ~= count then
			label.kelaCount = count
			label:SetText(count)
		end
		label:SetHidden(false)
	else
		label:SetHidden(true)
	end
end

local function RefreshSlotStacks(slot)
	local button = ZO_ActionBar_GetButton(slot)
	if not button or not button.slot then
		return
	end
	local frontLabel = GetFrontStackLabel(slot, button)
	local backLabel = GetBackStackLabel(slot, button)
	if not settings.showStacks or not IsGamepad() then
		frontLabel:SetHidden(true)
		backLabel:SetHidden(true)
		return
	end

	local frontCategory = GetActiveHotbarCategory()
	local backCategory = GetBackHotbarCategory()

	-- Front bar: the game already shows the slot's own effect stacks when the
	-- Action Bar Timers option is on, so only add linked buff stacks.
	local nativeFront = GetActionSlotEffectStackCount(slot, frontCategory)
	local nativeShown = nativeFront > 0 and GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS)
	local linkedFront = GetLinkedStacks(slot, frontCategory)
	ShowCount(frontLabel, nativeShown and 0 or linkedFront)

	-- Back bar: the game shows no stacks there at all.
	local backCount = 0
	if backCategory then
		backCount = zo_max(GetActionSlotEffectStackCount(slot, backCategory), GetLinkedStacks(slot, backCategory))
	end
	ShowCount(backLabel, backCount)
end

-- The game ignores effects under this many ms (MINIMUM_ACTION_BAR_TIMER_DISPLAYED_TIME_MS).
local NATIVE_TIMER_MIN_MS = 1000

-- How long the buff linked to a slot's skill has left, and how long it lasts,
-- in ms. 0 when the skill has no linked buff running, the buff has no expiry,
-- or stack counts are off.
local function GetLinkedTimer(slot, category)
	if not settings.showStacks or not category or not IsGamepad() then
		return 0, 0
	end
	local buffId = SLOTTED_TO_BUFF[GetSlottedAbilityId(slot, category)]
	local endS = buffId and buffEnds[buffId]
	if not endS then
		return 0, 0
	end
	local remainingMS = (endS - GetFrameTimeSeconds()) * 1000
	if remainingMS <= 0 then
		return 0, 0
	end
	return remainingMS, buffDurationsMS[buffId]
end

-- A skill whose stacks sit on a separate buff (Seething Fury for Molten Whip)
-- has no timer of its own. Its buff's expiry is fed into the game's own timer
-- for the slot: the text on the front button, the bar and numbers on the back
-- row. The skill's own timer wins when it has one, and the game's timer then
-- counts down by itself. `kelaLinkedTimer` marks a timer that is ours, so only
-- ours is cleared when the buff ends early.
local function SyncFrontLinkedTimer(slot)
	local button = ZO_ActionBar_GetButton(slot)
	local category = GetActiveHotbarCategory()
	if not button or not button.SetTimer or (category ~= HOTBAR_CATEGORY_PRIMARY and category ~= HOTBAR_CATEGORY_BACKUP) then
		return
	end
	if GetActionSlotEffectTimeRemaining(slot, category) > NATIVE_TIMER_MIN_MS then
		return
	end
	local remainingMS = GetLinkedTimer(slot, category)
	if remainingMS > 0 then
		button.kelaLinkedTimer = true
		button:SetTimer(remainingMS)
		-- The game dims a button while its timer runs; these skills stay usable.
		button.timerOverlay:SetHidden(true)
	elseif button.kelaLinkedTimer then
		button.kelaLinkedTimer = false
		button:SetTimer(0)
	end
end

local function SyncBackLinkedTimer(slot)
	local timer = FindBackTimer(slot)
	local category = GetBackHotbarCategory()
	if not timer or not category then
		return
	end
	if GetActionSlotEffectTimeRemaining(slot, category) > NATIVE_TIMER_MIN_MS then
		return
	end
	local remainingMS, durationMS = GetLinkedTimer(slot, category)
	if remainingMS > 0 then
		timer.kelaLinkedTimer = true
		timer:SetFillBar(remainingMS, durationMS)
	elseif timer.kelaLinkedTimer then
		timer.kelaLinkedTimer = false
		timer:SetFillBar(0, 0)
	end
end

local function SyncAllLinkedTimers()
	ForEachSlot(function(slot)
		SyncFrontLinkedTimer(slot)
		SyncBackLinkedTimer(slot)
	end)
end

local function RefreshAllStacks()
	ForEachSlot(RefreshSlotStacks)
	SyncAllLinkedTimers()
end

-- The events that change stacks (every effect tick on a slot, every change of a
-- tracked buff, every slot update) can arrive many times a second in a big
-- fight. Requests are collected and applied at most once per STACK_REFRESH_MS,
-- so the work stays bounded however busy the fight is. Settings changes and
-- loading screens refresh immediately instead.
local STACK_REFRESH_MS = 100
local STACK_REFRESH_UPDATE = NAMESPACE .. "_StackRefresh"
local stackRefreshAll = false
local stackRefreshSlots = {}
local stackRefreshQueued = false

local function FlushStackRefresh()
	EVENT_MANAGER:UnregisterForUpdate(STACK_REFRESH_UPDATE)
	stackRefreshQueued = false
	if stackRefreshAll then
		stackRefreshAll = false
		ZO_ClearTable(stackRefreshSlots)
		RefreshAllStacks()
		return
	end
	-- Each slot is refreshed on its own, so the order does not matter.
	for slot in pairs(stackRefreshSlots) do
		stackRefreshSlots[slot] = nil
		RefreshSlotStacks(slot)
	end
end

-- With no slot, every slot is refreshed.
local function QueueStackRefresh(slot)
	if slot then
		stackRefreshSlots[slot] = true
	else
		stackRefreshAll = true
	end
	if not stackRefreshQueued then
		stackRefreshQueued = true
		EVENT_MANAGER:RegisterForUpdate(STACK_REFRESH_UPDATE, STACK_REFRESH_MS, FlushStackRefresh)
	end
end

-- A buff that ends (endS > beginS) shows as a timer; one that does not has none.
-- A buff refreshed to a later end time lasts from now, not from its first begin.
local function SetBuffTime(buffId, beginS, endS)
	if beginS and endS and endS > beginS then
		local previousEndS = buffEnds[buffId]
		if previousEndS and endS > previousEndS then
			beginS = GetFrameTimeSeconds()
		end
		buffEnds[buffId] = endS
		buffDurationsMS[buffId] = (endS - beginS) * 1000
	else
		buffEnds[buffId] = nil
		buffDurationsMS[buffId] = nil
	end
end

local function SetBuffStacks(buffId, stackCount, buffName)
	buffStacks[buffId] = stackCount
	if stackCount > 0 and not loggedBuffs[buffId] then
		loggedBuffs[buffId] = true
		Log("Debug", string.format("Action bar: stacking buff %d (%s) at %d", buffId, tostring(buffName), stackCount))
	end
end

local function RescanBuffStacks()
	for buffId in pairs(STACK_BUFFS) do
		buffStacks[buffId] = 0
		buffEnds[buffId] = nil
		buffDurationsMS[buffId] = nil
	end
	for buffIndex = 1, GetNumBuffs("player") do
		local buffName, timeStarted, timeEnding, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
		if STACK_BUFFS[abilityId] then
			SetBuffStacks(abilityId, stackCount or 0, buffName)
			SetBuffTime(abilityId, timeStarted, timeEnding)
		end
	end
end

local function OnStackBuffChanged(_, changeType, _, effectName, unitTag, beginTime, endTime, stackCount, _, _, _, _, _, _, _, abilityId)
	-- The registration is filtered to the tracked buffs on the player; this
	-- keeps a dropped filter from turning every effect in the game into work.
	if not STACK_BUFFS[abilityId] or (unitTag ~= nil and unitTag ~= "player") then
		return
	end
	local faded = changeType == EFFECT_RESULT_FADED
	local count = faded and 0 or (stackCount or 0)
	local hasExpiry = not faded and beginTime and endTime and endTime > beginTime
	if buffStacks[abilityId] == count and buffEnds[abilityId] == (hasExpiry and endTime or nil) then
		return
	end
	SetBuffStacks(abilityId, count, effectName)
	SetBuffTime(abilityId, hasExpiry and beginTime or nil, hasExpiry and endTime or nil)
	QueueStackRefresh()
end

-- The back slot's center offset from its front button. The game anchors it at
-- (CENTER, front button, CENTER, 0, base offset); the raise lifts it. Without
-- the progress bar the slot is trimmed: its top strip is gone, but its 3 px
-- border is redrawn above it, and the slot is moved up so that border stays
-- where the top edge was with the bar. That lifts the icon by the strip minus
-- the border (9 px) compared to the same slot with the bar, using the freed
-- space to show more of the icon.
local function GetRaisedOffsetY(timer)
	local raise = IsGamepad() and settings.raise or 0
	local trimShift = timer.kelaTrimmed and (TIMER_TOP_LINE_HEIGHT - TIMER_STRIP_HEIGHT / 2) or 0
	return timer.kelaBaseOffsetY - raise + trimShift
end

-- Sets the bar-swap slide to end at offsetY. Every bar swap resets it to the
-- game's default offset first (PlayBackBarSwapAnimation), which is why newly
-- shown skills used to land back at the standard height.
local function SetSwapAnimationOffset(timer, offsetY)
	local timeline = timer.backBarSwapAnimation
	if timeline then
		timeline:GetAnimation(1):SetStartOffsetY(offsetY)
		timeline:GetAnimation(4):SetEndOffsetY(offsetY)
	end
end

-- The countdown is left-aligned on the back slot, at the same height as the
-- stack count on the right: both hang from the front button's top edge, so
-- neither moves with the raise or the trim.
local function PositionSecondsLabel(timer, label)
	local front = timer.kelaTarget
	if not front then
		return
	end
	local inset = zo_max(0, (front:GetWidth() - timer.slot:GetWidth()) / 2)
	label:ClearAnchors()
	label:SetAnchor(BOTTOMLEFT, front, TOPLEFT, inset + BACK_TIMER_INSET_X, BACK_LABEL_DROP - BACK_TIMER_LIFT)
end

local function ApplyRaise(timer)
	if not timer.kelaTarget then
		local isValid, _, relativeTo, _, _, offsetY = timer.slot:GetAnchor(0)
		if not isValid then
			return
		end
		timer.kelaTarget = relativeTo
		timer.kelaBaseOffsetY = offsetY
	end
	local offsetY = GetRaisedOffsetY(timer)
	timer.slot:ClearAnchors()
	timer.slot:SetAnchor(CENTER, timer.kelaTarget, CENTER, 0, offsetY)
	if timer.backBarSwapAnimation then
		-- Also refreshes the swap animation's sizes after a trim change.
		timer:ApplySwapAnimationStyle(offsetY)
	end
	local label = secondsLabels[timer.slot.slotNum]
	if label then
		PositionSecondsLabel(timer, label)
	end
end

local function GetSecondsLabel(timer)
	local slot = timer.slot.slotNum
	local label = secondsLabels[slot]
	if not label then
		label = CreateLabel("KelaBackBarTimer" .. slot, timer.slot, SECONDS_FONT)
		secondsLabels[slot] = label
		PositionSecondsLabel(timer, label)
	end
	return label
end

-- The frame's own top border, redrawn above the trimmed frame. It is the first
-- rows of the same frame texture, so it matches the art.
local function GetTopLine(timer)
	local line = timer.kelaTopLine
	if not line then
		line = WINDOW_MANAGER:CreateControl("KelaBackBarTopLine" .. timer.slot.slotNum, timer.slot, CT_TEXTURE)
		line:SetTexture(timer.frame:GetTextureFileName())
		line:SetDrawLevel(2)
		line:SetHidden(true)
		timer.kelaTopLine = line
	end
	return line
end

-- Trims (or restores) the top strip of the slot: the slot and its frame get
-- shorter, the frame textures skip the strip's rows, the icon moves to the top,
-- and the top border is redrawn just above the frame. The swap animation sizes
-- the frame from the slot, so trimming the slot itself keeps the trim through
-- bar swaps. The game's ApplyStyle reapplies the template, which undoes the
-- trim (see the ApplyStyle hook).
local function SetTimerStripTrimmed(timer, trimmed)
	if trimmed == (timer.kelaTrimmed == true) then
		if timer.kelaTopLine and not trimmed then
			timer.kelaTopLine:SetHidden(true)
		end
		return
	end
	local textures = { timer.frame, timer.slot:GetNamedChild("BG"), timer.slot:GetNamedChild("Overlay") }
	if trimmed then
		local width, height = timer.slot:GetDimensions()
		local frameWidth, frameHeight = timer.frame:GetDimensions()
		local saved = { width = width, height = height, frameWidth = frameWidth, frameHeight = frameHeight, coords = {} }
		for index, texture in ipairs(textures) do
			local left, right, top, bottom = texture:GetTextureCoords()
			saved.coords[index] = { left, right, top, bottom }
			-- Texture rows per coordinate unit, from the frame's own size.
			local stripCoord = TIMER_STRIP_HEIGHT * (bottom - top) / frameHeight
			texture:SetTextureCoords(left, right, top + stripCoord, bottom)
			if index == 1 then
				-- The frame's first rows are the top border.
				local lineCoord = TIMER_TOP_LINE_HEIGHT * (bottom - top) / frameHeight
				local line = GetTopLine(timer)
				line:SetTextureCoords(left, right, top, top + lineCoord)
				line:ClearAnchors()
				line:SetAnchor(BOTTOMLEFT, timer.frame, TOPLEFT, 0, 0)
				line:SetAnchor(BOTTOMRIGHT, timer.frame, TOPRIGHT, 0, 0)
				line:SetHeight(TIMER_TOP_LINE_HEIGHT)
				line:SetHidden(false)
			end
		end
		timer.kelaUntrimmed = saved
		timer.slot:SetDimensions(width, height - TIMER_STRIP_HEIGHT)
		timer.frame:SetDimensions(frameWidth, frameHeight - TIMER_STRIP_HEIGHT)
		timer.iconTexture:ClearAnchors()
		timer.iconTexture:SetAnchor(TOP, timer.slot, TOP, 0, 0)
	else
		if timer.kelaTopLine then
			timer.kelaTopLine:SetHidden(true)
		end
		local saved = timer.kelaUntrimmed
		if saved then
			timer.slot:SetDimensions(saved.width, saved.height)
			timer.frame:SetDimensions(saved.frameWidth, saved.frameHeight)
			for index, texture in ipairs(textures) do
				texture:SetTextureCoords(unpack(saved.coords[index]))
			end
		end
		timer.iconTexture:ClearAnchors()
		timer.iconTexture:SetAnchor(CENTER, timer.slot, CENTER, 0, 0)
	end
	timer.kelaTrimmed = trimmed
end

-- The progress bar and the countdown numbers are independent. Without the bar,
-- the strip of the frame art that holds its groove is trimmed away.
local function ApplyTimerMode(timer)
	local barHidden = not settings.showBar and IsGamepad()
	timer.fillStatusBar:SetHidden(barHidden)
	SetTimerStripTrimmed(timer, barHidden)
	if not (settings.showNumbers and IsGamepad()) then
		GetSecondsLabel(timer):SetHidden(true)
	end
	timer.kelaSeconds = nil
	timer.kelaWarn = nil
end

-- The game shows a back slot only while an effect is running on it: it hides
-- the slot when the style is applied, when the slot changes, and when a timer
-- ends. With "always show", the slot is shown again after each of those whenever
-- it holds a skill. The ultimate slot is left alone. The game's own Back Row
-- option and bars without a back row (timer.active, timer.showBackRowSlot)
-- still decide whether it can show at all.
local function ShowIdleSlot(timer)
	if not settings.alwaysShow or not timer.active or not timer.showBackRowSlot or not IsGamepad() then
		return
	end
	if timer:GetSlot() == ULTIMATE_SLOT then
		return
	end
	local category = timer:GetHotbarCategory()
	if category ~= HOTBAR_CATEGORY_PRIMARY and category ~= HOTBAR_CATEGORY_BACKUP then
		return
	end
	if GetSlotType(timer:GetSlot(), category) == ACTION_TYPE_NOTHING then
		return
	end
	if timer.slot:IsHidden() then
		timer.slot:SetHidden(false)
	end
end

-- Runs every frame for each back slot with a running timer (from the game's
-- own OnUpdate), so it only changes controls when a value actually changes.
local function OnFillBarUpdated(timer)
	ShowIdleSlot(timer)
	local remainingMS
	if timer.endTimeMS and timer.durationMS and timer.durationMS ~= 0 then
		remainingMS = timer.endTimeMS - GetFrameTimeMilliseconds()
	end
	local running = remainingMS ~= nil and remainingMS > 0
	local warn = running and settings.warnMS > 0 and remainingMS <= settings.warnMS and IsGamepad()

	if warn ~= timer.kelaWarn then
		timer.kelaWarn = warn
		ZO_StatusBar_SetGradientColor(timer.fillStatusBar, warn and WARN_GRADIENT or ZO_CAST_BAR_COLORS[ZO_CAST_STATE_BEGIN_CHARGE_UP])
		if secondsLabels[timer.slot.slotNum] then
			secondsLabels[timer.slot.slotNum]:SetColor((warn and WARN_COLOR or SECONDS_COLOR):UnpackRGBA())
		end
	end

	if settings.showNumbers and IsGamepad() then
		local label = GetSecondsLabel(timer)
		if running then
			-- The front bar's format: whole seconds, then tenths under 2 s. The text
			-- is rebuilt only when what it shows would change.
			local key = remainingMS >= DECIMAL_UNDER_MS and (1000 + zo_floor(remainingMS / 1000)) or zo_floor(remainingMS / 100)
			if key ~= timer.kelaSeconds then
				timer.kelaSeconds = key
				label:SetText(ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(remainingMS / 1000, ZO_ONE_MINUTE_IN_SECONDS, DECIMAL_UNDER_MS / 1000, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT))
				label:SetColor((warn and WARN_COLOR or SECONDS_COLOR):UnpackRGBA())
			end
			label:SetHidden(false)
		else
			timer.kelaSeconds = nil
			label:SetHidden(true)
		end
	end
end

local function ApplyAllBackTimers()
	ForEachSlot(function(slot)
		local timer = FindBackTimer(slot)
		if timer then
			-- Trim first: the raise offset depends on it.
			ApplyTimerMode(timer)
			ApplyRaise(timer)
			if settings.alwaysShow and slot ~= ULTIMATE_SLOT then
				ShowIdleSlot(timer)
			elseif not timer:HasValidDuration() then
				-- Back to the game's rule: an idle slot is hidden.
				timer.slot:SetHidden(true)
			end
		end
	end)
end

local function RefreshAll()
	RefreshSettings()
	ApplyAllBackTimers()
	RefreshAllStacks()
end

local function InstallHooks()
	if hooksInstalled then
		return
	end
	hooksInstalled = true

	SecurePostHook(ZO_ActionBarTimer, "ApplyAnchor", function(timer, target, offsetY)
		timer.kelaTarget = target
		timer.kelaBaseOffsetY = offsetY
		ApplyRaise(timer)
	end)
	-- The game reapplies its slot template on every slot change, which restores
	-- the slot's full size, frame texture coords, and icon anchor.
	SecurePostHook(ZO_ActionBarTimer, "ApplyStyle", function(timer)
		-- A slot still at its trimmed height was not reset; anything else was.
		local saved = timer.kelaUntrimmed
		timer.kelaTrimmed = timer.kelaTrimmed and saved ~= nil and timer.slot:GetHeight() == saved.height - TIMER_STRIP_HEIGHT
		ApplyTimerMode(timer)
		if timer.kelaBaseOffsetY then
			ApplyRaise(timer)
		end
		ShowIdleSlot(timer)
	end)
	SecurePostHook(ZO_ActionBarTimer, "SetupBackRowSlot", ShowIdleSlot)
	-- Each bar swap sets the slide back to the game's default offset before it
	-- plays; point it at the raised offset instead.
	SecurePostHook(ZO_ActionBarTimer, "ApplySwapAnimationStyle", function(timer, offsetY)
		if offsetY == nil or timer.kelaBaseOffsetY == nil then
			return
		end
		local wanted = GetRaisedOffsetY(timer)
		if offsetY ~= wanted then
			SetSwapAnimationOffset(timer, wanted)
		end
	end)
	SecurePostHook(ZO_ActionBarTimer, "UpdateFillBar", OnFillBarUpdated)
	-- The game sets every slot's timer to 0 when the slot's own effect is gone;
	-- put the linked buff's timer back. Calls that set a time (including ours)
	-- are left alone, which also keeps this from calling itself.
	SecurePostHook(ActionButton, "SetTimer", function(button, remainingMS)
		if remainingMS and remainingMS > 0 then
			return
		end
		local slot = button:GetSlot()
		if slot and ZO_ActionBar_GetButton(slot) == button then
			SyncFrontLinkedTimer(slot)
		end
	end)
	SecurePostHook(ZO_ActionBarTimer, "SetFillBar", function(timer, remainingMS, durationMS)
		if durationMS and durationMS > 0 then
			return
		end
		SyncBackLinkedTimer(timer:GetSlot())
	end)
	CALLBACK_MANAGER:RegisterCallback(SETTINGS_CHANGED_EVENT, RefreshAll)

	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_ACTION_SLOT_EFFECT_UPDATE, function(_, _, slot)
		QueueStackRefresh(slot)
	end)
	local function QueueAllStacks()
		QueueStackRefresh()
	end
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_ACTION_SLOT_EFFECTS_CLEARED, QueueAllStacks)
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, QueueAllStacks)
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, QueueAllStacks)
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_HOTBAR_SLOT_UPDATED, QueueAllStacks)
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, RefreshAll)

	-- One registration per stack buff, filtered to that buff on the player, so
	-- the handler never runs for unrelated effects.
	for buffId in pairs(STACK_BUFFS) do
		local eventName = NAMESPACE .. "_Buff" .. buffId
		EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, OnStackBuffChanged)
		EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, buffId, REGISTER_FILTER_UNIT_TAG, "player")
	end

	local optionsScene = SCENE_MANAGER:GetScene(KELA_OPTIONS_SCENE_NAME)
	if optionsScene then
		optionsScene:RegisterCallback("StateChange", function(_, newState)
			if newState == SCENE_HIDDEN then
				RefreshAll()
			end
		end)
	end
end

-- Add-ons that replace the inactive bar; ours stays off while one is loaded.
local function GetConflictingAddOnName()
	if FancyActionBar then
		return "Fancy Action Bar+"
	elseif ActionDurationReminder then
		return "Action Duration Reminder"
	end
	return nil
end

local function OnPlayerActivated()
	local conflict = GetConflictingAddOnName()
	if conflict then
		Log("Info", string.format("Action bar: %s is loaded, so KelaPadUI's action bar changes stay off", conflict))
		EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED)
		return
	end
	InstallHooks()
	RescanBuffStacks()
	RefreshAll()
end

function KelaSetupActionBar()
	if KelaPadUI.KelaActionBarInitialized then
		return
	end
	KelaPadUI.KelaActionBarInitialized = true

	-- Every activation (zone change, reload) rescans buffs; hooks install once.
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end
