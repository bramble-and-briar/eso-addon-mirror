Stunned = {}

local S = Stunned
local EM = EVENT_MANAGER

S.name = "Stunned"

local stunnedMode = false
local playerName = nil
local StunAlert = nil
local StunNotification = nil

local combatResults = {
	ACTION_RESULT_FEARED,
	ACTION_RESULT_CHARMED,
	ACTION_RESULT_ROOTED,
	ACTION_RESULT_SILENCED,
	ACTION_RESULT_PACIFIED,
	ACTION_RESULT_OFFBALANCE,
	ACTION_RESULT_STAGGERED
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
	fearBlurDuration = 1000,
	fearColor = "FF0000",

	trackCharm = true,
	textCharm = true,
	charmSoundEnabled = true,
	charmSound = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
	charmBlurDuration = 1000,
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

function S.ShowStunAlert(msgText, soundName, color, duration, showText)
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
		S.HideAlert()

		if not StunAlert then
			StunAlert = WINDOW_MANAGER:CreateTopLevelWindow("StunAlert")
			StunAlert:SetDimensions(800, 150)

			local label = StunAlert:CreateControl(nil, CT_LABEL)
			local fontString = string.format("$(BOLD_FONT)|$(KB_%d)|soft-shadow-thick", S.SV.alertFontSize)
			label:SetFont(fontString)
			label:SetAnchor(CENTER, StunAlert, CENTER, 0, 0)
			label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
			label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
			StunAlert.label = label
		end

		local screenWidth, screenHeight = GuiRoot:GetDimensions()
		local xPos = screenWidth / 2
		local yPos = screenHeight / 3

		StunAlert:ClearAnchors()
		StunAlert:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, xPos - 400, yPos - 75)

		StunAlert.label:SetText("|c" .. color .. msgText .. "|r")
		StunAlert:SetHidden(false)
	end

	if duration then
		zo_callLater(function()
			S.HideAlert()
			if S.SV.blurOnStun then
				SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
			end
			if S.SV.hideGameUI then
				ToggleShowIngameGui()
			end
		end, duration)
	end
end

function S.HideAlert()
	if StunAlert then
		StunAlert:SetHidden(true)
	end
end

function S.ShowNotification(msgText, soundName, color, duration)
	if soundName then
		PlaySound(SOUNDS[soundName])
	end

	S.HideNotification()

	if not StunNotification then
		StunNotification = WINDOW_MANAGER:CreateTopLevelWindow("StunNotification")
		StunNotification:SetDimensions(800, 150)

		local label = StunNotification:CreateControl(nil, CT_LABEL)
		local fontString = string.format("$(BOLD_FONT)|$(KB_%d)|soft-shadow-thick", S.SV.notificationFontSize)
		label:SetFont(fontString)
		label:SetAnchor(CENTER, StunNotification, CENTER, 0, 0)
		label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		StunNotification.label = label
	end

	StunNotification:ClearAnchors()
	StunNotification:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)

	StunNotification.label:SetText("|c" .. color .. msgText .. "|r")
	StunNotification:SetHidden(false)

	zo_callLater(function()
		S.HideNotification()
	end, duration)
end

function S.HideNotification()
	if StunNotification then
		StunNotification:SetHidden(true)
	end
end

function S.SetStunState(_, stunned)
	if stunned then
		if not stunnedMode and IsUnitInCombat("player") then
			stunnedMode = true

			if S.SV.hideGameUI then
				ToggleShowIngameGui()
			end

			if S.SV.blurOnStun then
				SetFullscreenEffect(FULLSCREEN_EFFECT_UNIFORM_BLUR)
			end

			if S.SV.stunSoundEnabled then
				PlaySound(SOUNDS[S.SV.stunSound])
			end

			S.ShowStunAlert("STUNNED!", nil, S.SV.stunColor, nil, S.SV.textStun)
		end
	else
		if stunnedMode then
			if S.SV.blurOnStun then
				SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
			end

			if S.SV.hideGameUI then
				ToggleShowIngameGui()
			end

			stunnedMode = false
			S.HideAlert()
		end
	end
end

function S.CombatEventHandler(_, result, _, _, _, _, _, _, targetName, ...)
	if not IsUnitInCombat("player") then return end

	local normalizedTarget = zo_strformat("<<1>>", targetName)

	if normalizedTarget == playerName then
		if result == ACTION_RESULT_FEARED and S.SV.trackFear then
			local sound = S.SV.fearSoundEnabled and S.SV.fearSound
			S.ShowStunAlert("FEARED!", sound, S.SV.fearColor, S.SV.fearBlurDuration, S.SV.textFear)
			stunnedMode = true
			zo_callLater(function() stunnedMode = false end, S.SV.fearBlurDuration)

		elseif result == ACTION_RESULT_CHARMED and S.SV.trackCharm then
			local sound = S.SV.charmSoundEnabled and S.SV.charmSound
			S.ShowStunAlert("CHARMED!", sound, S.SV.charmColor, S.SV.charmBlurDuration, S.SV.textCharm)
			stunnedMode = true
			zo_callLater(function() stunnedMode = false end, S.SV.charmBlurDuration)

		elseif result == ACTION_RESULT_ROOTED and S.SV.trackRooted then
			local sound = S.SV.rootedSoundEnabled and S.SV.rootedSound
			S.ShowNotification("ROOTED!", sound, S.SV.rootedColor, 1000)

		elseif result == ACTION_RESULT_SILENCED and S.SV.trackSilenced then
			local sound = S.SV.silencedSoundEnabled and S.SV.silencedSound
			S.ShowNotification("SILENCED!", sound, S.SV.silencedColor, 1000)

		elseif result == ACTION_RESULT_PACIFIED and S.SV.trackPacified then
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

function S.OnPlayerActivated()
	S.HideAlert()
	if stunnedMode then
		SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
		if S.SV.hideGameUI then
			ToggleShowIngameGui()
		end
		stunnedMode = false
	end
end

function S.OnInitPlayerActivated()
	playerName = GetUnitName("player")

	EVENT_MANAGER:UnregisterForEvent(S.name, EVENT_PLAYER_ACTIVATED)
	EVENT_MANAGER:RegisterForEvent(S.name, EVENT_PLAYER_ACTIVATED, S.OnPlayerActivated)
end

function S.OnAddonLoaded(_, addonName)
	if addonName == S.name then
		EM:UnregisterForEvent(S.name, EVENT_ADD_ON_LOADED)

		S.SV = ZO_SavedVars:NewAccountWide("Stunned_SV", 1, nil, defaultSV)
		S.RegisterLAMPanel()

		EM:RegisterForEvent(S.name, EVENT_PLAYER_STUNNED_STATE_CHANGED, S.SetStunState)
		EM:RegisterForEvent(S.name, EVENT_PLAYER_ACTIVATED, S.OnInitPlayerActivated)

		for _, result in ipairs(combatResults) do
			local ns = S.name .. "_" .. tostring(result)
			EM:RegisterForEvent(ns, EVENT_COMBAT_EVENT, S.CombatEventHandler)
			EM:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, result)
		end
	end
end

EM:RegisterForEvent(S.name, EVENT_ADD_ON_LOADED, S.OnAddonLoaded)