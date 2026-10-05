local Azurah		= _G['Azurah'] -- grab addon table from global
local LMP			= LibMediaProvider

-- UPVALUES --
local IsUnitChampion					= IsUnitChampion
local GetUnitChampionPoints				= GetUnitChampionPoints
local GetUnitChampionPointsMax			= 3600
local GetUnitXP							= GetUnitXP
local GetUnitXPMax						= GetUnitXPMax
local IsChampionSystemUnlocked			= IsChampionSystemUnlocked
local GetPlayerChampionXP				= GetPlayerChampionXP
local GetNumChampionXPInChampionPoint	= GetNumChampionXPInChampionPoint
local GetPlayerChampionPointsEarned		= GetPlayerChampionPointsEarned
local strformat							= string.format
local zo_callLater						= zo_callLater
local hasMaxXP							= false
local hasMaxCP							= false
local overlayExp, overlayChamp
local FormatExp
local isUpdating
local db

local tDB = {
	["ZO_PlayerProgressTemplate"] = true,
	["ZO_PlayerChampionProgressTemplate"] = true,
	["ZO_GamepadPlayerProgressTemplate"] = true,
	["ZO_GamepadPlayerChampionProgressTemplate"] = true
}

local function OnCraftStart()
	if (db.displayStyle == 2) then
		ZO_PlayerProgressBar:SetAlpha(0)
	end
end

local function OnCraftEnd()
	if (db.displayStyle == 2) then
		ZO_PlayerProgressBar:SetAlpha(1)
	end
end

local function UpdateExperienceBarOverlayValues()
	local isChampion = IsUnitChampion('player')

	if (not hasMaxXP) then
		local current, max

		if (isChampion) then
			current, max = GetUnitChampionPoints('player'), GetUnitChampionPointsMax
			hasMaxXP = (current == max)
		else
			current, max = GetUnitXP('player'), GetUnitXPMax('player')
		end

		overlayExp:SetText(FormatExp(current, nil, max))
	end

	if (not hasMaxCP and isChampion) then
		if (IsChampionSystemUnlocked()) then
			local earnedCP = GetPlayerChampionPointsEarned()
			local inRankCP = GetNumChampionXPInChampionPoint(earnedCP)
			if (inRankCP ~= nil) then
				local championXP = GetPlayerChampionXP()
				overlayChamp:SetText(FormatExp(championXP, nil, inRankCP))
			end
			hasMaxCP = earnedCP == 3600
		end
	end

	isUpdating = false
end

local function OnExpGain(_, unit)
	if (unit ~= 'player') then return end -- only care about the player

	if (not isUpdating) then
		isUpdating = true
		zo_callLater(UpdateExperienceBarOverlayValues, 1000) -- called later as exp bar doesn't show new values immediately
	end
end

function Azurah:ConfigureExperienceBarOverlay()

-- override to prevent re-application of XML template constantly re-docking progress bar (Phinix)
	local ProgressDock = ApplyTemplateToControl
	ApplyTemplateToControl = function(control, templateName)
		if tDB[templateName] then
			return
		else
			ProgressDock(control, templateName)
		end
	end

	if (db.overlay > 1) then -- showing overlay, enable tracking
		local current, max, earnedCP, inRankCP
		local isChampion = IsUnitChampion('player')

		local fontStr = strformat('%s|%d|%s', LMP:Fetch('font', db.fontFace), db.fontSize, db.fontOutline)
		FormatExp = self.overlayFuncs[db.overlay + ((db.overlayFancy) and 10 or 0)]

		overlayChamp:SetFont(fontStr)
		overlayChamp:SetColor(db.fontColour.r, db.fontColour.g, db.fontColour.b, db.fontColour.a)
		current= GetUnitChampionPoints('player')
		overlayExp:SetFont(fontStr)
		overlayExp:SetColor(db.fontColour.r, db.fontColour.g, db.fontColour.b, db.fontColour.a)

		if (isChampion) then
			max	= GetUnitChampionPointsMax
			earnedCP = GetPlayerChampionPointsEarned()
			inRankCP = GetNumChampionXPInChampionPoint(earnedCP)
			hasMaxXP = (current == max)
			hasMaxCP = (earnedCP == max)
		else
			current, max = GetUnitXP('player'), GetUnitXPMax('player')
		end

		if (not hasMaxXP) then
			overlayExp:SetHidden(false)
			overlayExp:SetText(FormatExp(current, nil, max))
		else
			overlayExp:SetHidden(true)
		end

		if (IsChampionSystemUnlocked() and isChampion and not hasMaxCP) then
			overlayExp:SetHidden(true)
			overlayChamp:SetHidden(false)
			overlayChamp:SetText(strformat("%s", FormatExp(GetPlayerChampionXP(), nil, inRankCP)))
		else
			overlayExp:SetHidden(false)
			overlayChamp:SetHidden(true)
		end

		EVENT_MANAGER:RegisterForEvent(self.name .. 'Experience', EVENT_EXPERIENCE_UPDATE, OnExpGain)
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Experience', EVENT_CHAMPION_POINT_UPDATE, OnExpGain)

	else -- no overlay being shown, disable tracking
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Experience', EVENT_EXPERIENCE_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Experience', EVENT_CHAMPION_POINT_UPDATE)

		overlayExp:SetHidden(true)
		overlayChamp:SetHidden(true)

	end
end

function Azurah:ConfigureExperienceBarDisplay()
	-- Visibility code for Experience Bar is by Garkin (http://www.esoui.com/forums/member.php?u=524)\and used with permission.
	PLAYER_PROGRESS_BAR_FRAGMENT:SetConditional(function() return not (db.displayStyle == 3) end)
	PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT:SetConditional(function() return not (db.displayStyle == 3) end)

	if (db.displayStyle == 2) then
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Experience', EVENT_CRAFTING_STATION_INTERACT,	OnCraftStart)
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Experience', EVENT_END_CRAFTING_STATION_INTERACT,OnCraftEnd)
		--HUD_SCENE:AddFragment(PLAYER_PROGRESS_BAR_FRAGMENT)
		HUD_SCENE:AddFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
		--HUD_UI_SCENE:AddFragment(PLAYER_PROGRESS_BAR_FRAGMENT)
		HUD_UI_SCENE:AddFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
		LOOT_SCENE:AddFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
	else
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Experience', EVENT_CRAFTING_STATION_INTERACT)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Experience', EVENT_END_CRAFTING_STATION_INTERACT)
		--HUD_SCENE:RemoveFragment(PLAYER_PROGRESS_BAR_FRAGMENT)
		HUD_SCENE:RemoveFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
		--HUD_UI_SCENE:RemoveFragment(PLAYER_PROGRESS_BAR_FRAGMENT)
		HUD_UI_SCENE:RemoveFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
		LOOT_SCENE:RemoveFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
	end
end


-- ------------------------
-- INITIALIZATION
-- ------------------------
function Azurah:InitializeExperienceBar()
	db = self.db.experienceBar

	overlayExp = self:CreateOverlay(ZO_PlayerProgressBar, CENTER, CENTER, 0, 0, nil, nil, nil, TEXT_ALIGN_LEFT)
	overlayChamp = self:CreateOverlay(ZO_PlayerProgressBar, CENTER, CENTER, 0, 0, nil, nil, nil, TEXT_ALIGN_LEFT)

	-- set 'dummy' display function
	FormatExp = self.overlayFuncs[1]

	self:ConfigureExperienceBarDisplay()
	self:ConfigureExperienceBarOverlay()
end