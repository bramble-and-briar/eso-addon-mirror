Stunned = {}

local S = Stunned
local EM = EVENT_MANAGER

S.name = "Stunned"

local playerName = nil
local StunAlert = nil
local StunNotification = nil

local activeStunID = nil
local debugEnabled = false

local BLOCKED_ABILITIES = {
	[163818] = true, -- Teleport (Encounter In Progress)
	[163850] = true, -- Teleport (Encounter In Progress) -- DSR
	[167948] = true, -- Coral Aerie | Maligalig Tornadoe Silence
	[159551] = true, -- Coral Aerie | Maligalig Tornadoe Stuns
	[166794] = true, -- DSR | Water Charms
	[167949] = true, -- DSR | Water Silence
	[263940] = true, -- MoS | Tarcyr Teleport
	[264680] = true, -- MoS | Tarcyr Ghostly Indriks
}

local combatResults = {
	ACTION_RESULT_STUNNED,
	ACTION_RESULT_FEARED,
	ACTION_RESULT_CHARMED,
	ACTION_RESULT_ROOTED,
	ACTION_RESULT_SILENCED,
	ACTION_RESULT_PACIFIED,
	ACTION_RESULT_OFFBALANCE,
	ACTION_RESULT_STAGGERED,
	ACTION_RESULT_EFFECT_FADED,
}

local defaultSV = {
	blurOnStun = true,
	hideGameUI = false,
	alertFontSize = 48,
	notificationFontSize = 36,

	trackStun = true,
	textStun = true,
	stunSoundEnabled = true,
	stunSound = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
	stunColor = "FF0000",

	trackFear = true,
	textFear = true,
	fearSoundEnabled = true,
	fearSound = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
	fearColor = "FF0000",

	trackCharm = true,
	textCharm = true,
	charmSoundEnabled = true,
	charmSound = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
	charmColor = "FF0000",

	trackRooted = true,
	rootedSoundEnabled = true,
	rootedSound = "DEATH_RECAP_KILLING_BLOW_SHOWN",
	rootedColor = "FF8C00",

	trackSilenced = true,
	silencedSoundEnabled = true,
	silencedSound = "DEATH_RECAP_KILLING_BLOW_SHOWN",
	silencedColor = "4169E1",

	trackPacified = true,
	pacifiedSoundEnabled = true,
	pacifiedSound = "DEATH_RECAP_KILLING_BLOW_SHOWN",
	pacifiedColor = "4169E1",

	trackOffBalance = true,
	offBalanceSoundEnabled = true,
	offBalanceSound = "DEATH_RECAP_KILLING_BLOW_SHOWN",
	offBalanceColor = "00CED1",

	trackStaggered = true,
	staggeredSoundEnabled = true,
	staggeredSound = "DEATH_RECAP_KILLING_BLOW_SHOWN",
	staggeredColor = "FFD700",
}

function S.CreateUI()
	StunAlert = WINDOW_MANAGER:CreateTopLevelWindow("StunAlert")
	StunAlert:SetDimensions(800, 150)
	local alertLabel = StunAlert:CreateControl(nil, CT_LABEL)
	alertLabel:SetFont(string.format("$(BOLD_FONT)|$(KB_%d)|soft-shadow-thick", S.SV.alertFontSize))
	alertLabel:SetAnchor(CENTER, StunAlert, CENTER, 0, 0)
	alertLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	alertLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	StunAlert.label = alertLabel

	StunNotification = WINDOW_MANAGER:CreateTopLevelWindow("StunNotification")
	StunNotification:SetDimensions(800, 150)
	local notifLabel = StunNotification:CreateControl(nil, CT_LABEL)
	notifLabel:SetFont(string.format("$(BOLD_FONT)|$(KB_%d)|soft-shadow-thick", S.SV.notificationFontSize))
	notifLabel:SetAnchor(CENTER, StunNotification, CENTER, 0, 0)
	notifLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	notifLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	StunNotification.label = notifLabel
end

function S.ShowStunAlert(msgText, soundName, color, showText)
	if S.SV.hideGameUI then
		ToggleShowIngameGui()
	end

	if S.SV.blurOnStun then
		SetFullscreenEffect(FULLSCREEN_EFFECT_UNIFORM_BLUR)
	end

	if soundName then
		PlaySound(SOUNDS[soundName])
	end

	if showText then
		local screenWidth, screenHeight = GuiRoot:GetDimensions()
		local xPos = screenWidth / 2
		local yPos = screenHeight / 3

		StunAlert:ClearAnchors()
		StunAlert:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, xPos - 400, yPos - 75)

		StunAlert.label:SetText("|c" .. color .. msgText .. "|r")
		StunAlert:SetHidden(false)
	end
end

function S.ShowNotification(msgText, soundName, color, duration)
	if soundName then
		PlaySound(SOUNDS[soundName])
	end

	StunNotification:ClearAnchors()
	StunNotification:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)

	StunNotification.label:SetText("|c" .. color .. msgText .. "|r")
	StunNotification:SetHidden(false)

	zo_callLater(function()
		StunNotification:SetHidden(true)
	end, duration)
end

function S.RemoveStunnedMode()
	if activeStunID ~= nil then
		if S.SV.blurOnStun then SetFullscreenEffect(FULLSCREEN_EFFECT_NONE) end
		if S.SV.hideGameUI then ToggleShowIngameGui() end
	end
	activeStunID = nil
	StunAlert:SetHidden(true)
end

function S.CombatEventHandler(_, result, isError, abilityName, _, _, sourceName, _, targetName, _, _, _, _, _, _, _, abilityId)
	-- if not IsUnitInCombat("player") then return end
	if isError then
		if result == ACTION_RESULT_STUNNED or result == ACTION_RESULT_FEARED or result == ACTION_RESULT_CHARMED then
			if debugEnabled then d(string.format("|cFF0000ERROR|r %s abilityId=%s name=%s", tostring(result), tostring(abilityId), tostring(abilityName))) end
			return
		end
	end

	local normalizedSource = zo_strformat("<<1>>", sourceName)
	if normalizedSource == playerName then return end
	if BLOCKED_ABILITIES[abilityId] then return end
	local normalizedTarget = zo_strformat("<<1>>", targetName)
	
	if normalizedTarget == playerName then
		if result == ACTION_RESULT_STUNNED and S.SV.trackStun then
			if activeStunID == nil then
				if debugEnabled then d(string.format("STUNNED: abilityId=%s name=%s source=%s", tostring(abilityId), tostring(abilityName), tostring(normalizedSource))) end

				local sound = S.SV.stunSoundEnabled and S.SV.stunSound
				S.ShowStunAlert("STUNNED!", sound, S.SV.stunColor, S.SV.textStun)
				activeStunID = abilityId
			end

		elseif result == ACTION_RESULT_FEARED and S.SV.trackFear then
			if activeStunID == nil then
				if debugEnabled then d(string.format("FEARED: abilityId=%s name=%s", tostring(abilityId), tostring(abilityName))) end

				local sound = S.SV.fearSoundEnabled and S.SV.fearSound
				S.ShowStunAlert("FEARED!", sound, S.SV.fearColor, S.SV.textFear)
				activeStunID = abilityId
			end

		elseif result == ACTION_RESULT_CHARMED and S.SV.trackCharm then
			if activeStunID == nil then
				if debugEnabled then d(string.format("CHARMED: abilityId=%s name=%s", tostring(abilityId), tostring(abilityName))) end

				local sound = S.SV.charmSoundEnabled and S.SV.charmSound
				S.ShowStunAlert("CHARMED!", sound, S.SV.charmColor, S.SV.textCharm)
				activeStunID = abilityId
			end

		elseif result == ACTION_RESULT_EFFECT_FADED then
			if abilityId == activeStunID then
				S.RemoveStunnedMode()
			end

		elseif result == ACTION_RESULT_ROOTED and S.SV.trackRooted then
			local sound = S.SV.rootedSoundEnabled and S.SV.rootedSound
			S.ShowNotification("ROOTED!", sound, S.SV.rootedColor, 1000)

		elseif result == ACTION_RESULT_SILENCED and S.SV.trackSilenced then
			if debugEnabled then d(string.format("SILENCED: abilityId=%s name=%s source=%s", tostring(abilityId), tostring(abilityName), tostring(normalizedSource))) end

			local sound = S.SV.silencedSoundEnabled and S.SV.silencedSound
			S.ShowNotification("SILENCED!", sound, S.SV.silencedColor, 1000)

		elseif result == ACTION_RESULT_PACIFIED and S.SV.trackPacified then
			if debugEnabled then d(string.format("PACIFIED: abilityId=%s name=%s", tostring(abilityId), tostring(abilityName))) end

			local sound = S.SV.pacifiedSoundEnabled and S.SV.pacifiedSound
			S.ShowNotification("PACIFIED!", sound, S.SV.pacifiedColor, 1000)

		elseif result == ACTION_RESULT_OFFBALANCE and S.SV.trackOffBalance then
			local sound = S.SV.offBalanceSoundEnabled and S.SV.offBalanceSound
			S.ShowNotification("OFF-BALANCE!", sound, S.SV.offBalanceColor, 1000)

		elseif result == ACTION_RESULT_STAGGERED and S.SV.trackStaggered then
			local sound = S.SV.staggeredSoundEnabled and S.SV.staggeredSound
			S.ShowNotification("STAGGER!", sound, S.SV.staggeredColor, 1000)
		end
	end
end

function S.NoStunAfterTP()
	S.RemoveStunnedMode()
end

function S.OnInitPlayerActivated()
	playerName = GetUnitName("player")
	S.CreateUI()

	EM:UnregisterForEvent(S.name, EVENT_PLAYER_ACTIVATED)
	--EM:RegisterForEvent(S.name, EVENT_PLAYER_ACTIVATED, S.NoStunAfterTP)
end

function S.OnAddonLoaded(_, addonName)
	if addonName == S.name then
		EM:UnregisterForEvent(S.name, EVENT_ADD_ON_LOADED)

		S.SV = ZO_SavedVars:NewAccountWide("Stunned_SV", 1, nil, defaultSV)
		S.RegisterLAMPanel()

		EM:RegisterForEvent(S.name, EVENT_PLAYER_ACTIVATED, S.OnInitPlayerActivated)

		for _, result in ipairs(combatResults) do
			local ns = S.name .. "_" .. tostring(result)
			EM:RegisterForEvent(ns, EVENT_COMBAT_EVENT, S.CombatEventHandler)
			EM:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, result)
		end

		SLASH_COMMANDS["/stundbg"] = function()
			debugEnabled = not debugEnabled
			d(string.format("Stunned debug: %s", debugEnabled and "|c00FF00ON|r" or "|cFF0000OFF|r"))
		end
	end
end

EM:RegisterForEvent(S.name, EVENT_ADD_ON_LOADED, S.OnAddonLoaded)