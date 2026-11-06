PvPQoL = {}
PvPQoL.name = "PvPQoL"

local PQ = PvPQoL

local ICON_DEATH = "esoui/art/treeicons/gamepad/gp_tutorial_idexicon_death.dds"
local ICON_EXECUTE = "esoui/art/icons/poi/poi_battlefield_complete.dds"
local ICON_SUCCESS = "PvPQoL/Textures/yes.dds"
local ICON_NO = "PvPQoL/Textures/no.dds"

ZO_CreateStringId("SI_BINDING_NAME_PVPQOL_STATS", "Show Stats")

PQ.Defaults = {
	killsToday = 0,
	deathsToday = 0,
	windowOffsetX = 20,
	windowOffsetY = 20,
	anchor = "LEFT",
	isHidden = false,
	todayIC = false,
	todayBG = false,
	todayCYRO = false,
	enableStandIns = false,
	standInsPerFrame = 8,
	uiScale = 1.0,

	victimColor		 = "FFA500",
	killerColor		 = "FF0000",
	killFlashColor	 = "FFA500",
	arrowColor		 = "FFD700",
	abilityColor	 = "FFD700",
	hideArrowAndSkill = false,
	disableKillSound = false,
	disableKillFlash = false,
	hideKillIcons	 = false,
	useUnifiedStats	 = false,
	hideAPGains		 = false,
	hideTelvarGains	 = false,
	showEverywhere	 = false,
	hideKillMessages = false,
	hideDeathMessages = false,
	useAccountNames = false,
	showRankIcon = false,
	helpIC = false,
	helpBG = false,
	helpCYRO = false,
	minTelvarMessage = 100,
	minAPMessage = 100,
	lifetimeKills = 0,
	lifetimeDeaths = 0,
	lifetimeAP = 0,
	lifetimeTelvar = 0,
	lifetimeTelvarFromKills = 0,
	trackItems = true,
	lootedBG = false,
	lootedIC = false,
	lootedCyro = false,

	hideKeepTooltip = true,

	autoQueue = false,
	chatQueue = false,
}

PQ.suppressQuestHelpers = false
PQ.playerName = nil
PQ.isBgActive = false
PQ.isInAvA = false

PQ.bgKills = 0
PQ.bgDeaths = 0

PQ.SV = {}
PQ.rankIcons = {}

local pendingCurrencyMessages = {}
local CURRENCY_DELAY_MS = 1000

local COLOR_WHITE = "|cFFFFFF"
local COLOR_AP	  = "|c38EE32"
local COLOR_TV	  = "|c5698ED"

local ICON_AP = GetCurrencyKeyboardIcon(CURT_ALLIANCE_POINTS)
local ICON_TV = GetCurrencyKeyboardIcon(CURT_TELVAR_STONES)

-- =========================
-- Tracked Item IDs
-- =========================
local TRACKED_ITEMS = {
	[212235] = { svFlag = "lootedBG", icon = "esoui/art/treeicons/gamepad/tutorial_idexicon_battlegrounds.dds", order = 1 },
	[151939] = { svFlag = "lootedIC", icon = "esoui/art/compass/ava_imperialcity_neutral.dds", order = 2 },
	[138783] = { svFlag = "lootedCyro", icon = "esoui/art/leveluprewards/levelup_cyrodiil_64.dds", order = 3 },
}

function PQ.CacheRankIcons()
	for rank = 1, 50 do
		local texture = GetLargeAvARankIcon(rank)
		if texture and texture ~= "" then
			PQ.rankIcons[rank] = texture
		end
	end
end

function PvPQoL_ShowStatsTooltip()
	local centerX = GuiRoot:GetWidth() / 2
	local centerY = GuiRoot:GetHeight() / 2

	InitializeTooltip(InformationTooltip, GuiRoot, CENTER, centerX, centerY, 0)
	SetTooltipText(InformationTooltip, table.concat(PQ.GetStatsTooltipLines(), "\n"))

	zo_callLater(function()
		ClearTooltip(InformationTooltip)
	end, 5000)
end

-- =========================
-- Reticle Target Tracking
-- =========================
PQ.targetCache = {}

local function IsTargetEnemy(targetAlliance)
	local playerAlliance = GetUnitAlliance("player")
	return targetAlliance ~= playerAlliance and targetAlliance ~= ALLIANCE_NONE
end

function PQ.OnReticleTargetChanged(eventCode, unitTag)
	if not (PQ.isInAvA or PQ.isBgActive) and not PQ.SV.showEverywhere then return end
	local unitTagReticle = 'reticleover'

	if not DoesUnitExist(unitTagReticle) then return end

	if not IsUnitPlayer(unitTagReticle) then return end

	local targetName = GetUnitName(unitTagReticle)
	targetName = zo_strformat("<<1>>", targetName)

	local targetAlliance = GetUnitAlliance(unitTagReticle)
	local isInBG = PQ.isBgActive

	if not isInBG then
		local playerAlliance = GetUnitAlliance("player")
		local isEnemy = targetAlliance ~= playerAlliance and targetAlliance ~= ALLIANCE_NONE
		if not isEnemy then return end
	else
		if not IsUnitAttackable(unitTagReticle) then return end
	end

	local accountName = GetUnitDisplayName(unitTagReticle)

	local rank = 0
	if PQ.SV.showRankIcon then
		rank = GetUnitAvARank(unitTagReticle)
	end

	PQ.targetCache[targetName] = {
		account = accountName,
		alliance = targetAlliance,
		allianceName = GetAllianceName(targetAlliance),
		rank = rank,
	}
end

function PQ.CleanupTargetCache()
	PQ.targetCache = {}
end

function PQ.GetCachedTargetInfo(targetName)
	return PQ.targetCache[targetName]
end

function PQ.TriggerKillAlert()
	if not PQ.SV.disableKillFlash then
		PvPQoLAlertBorder.Flash:PlayFromStart()
	end

	if not PQ.SV.disableKillSound then
		PlaySound(SOUNDS.LOCKPICKING_SUCCESS_CELEBRATION)
	end
end

-- =========================
-- PvPQoL Alert Border Styling
-- =========================
function PQ.SetupAlertBorderColors()
	local border = WINDOW_MANAGER:GetControlByName("PvPQoLAlertBorder")
	if border then
		local overlay = WINDOW_MANAGER:GetControlByName("PvPQoLAlertBorderOverlay")
		if overlay then
			local r, g, b = ZO_ColorDef:New(PQ.SV.killFlashColor):UnpackRGB()
			overlay:SetEdgeColor(r, g, b, 1)
		end
		border.Flash = ANIMATION_MANAGER:CreateTimelineFromVirtual("PvPQoLAlertBorderAnimation", border)
	end
end

local function FormatNumber(amount)
	local formatted = tostring(amount)
	local k
	while true do
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

-- =========================
-- UI Creation
-- =========================
local function clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

local function CreateUI()
	local window = WINDOW_MANAGER:CreateTopLevelWindow("PvPQoLWindow")
	window:SetDimensions(100, 32)
	window:SetMouseEnabled(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)

	local anchor = PQ.SV.anchor
	local x = tonumber(PQ.SV.windowOffsetX)
	local y = tonumber(PQ.SV.windowOffsetY)

	local scale = PQ.SV.uiScale
	window:SetScale(scale)

	if anchor == "RIGHT" then
		window:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -(x * scale), y * scale)
	else
		window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x * scale, y * scale)
	end
	window:SetHandler("OnMoveStop", function(self)
		local scale = self:GetScale()
		local screenW = GuiRoot:GetWidth()

		local left = self:GetLeft() / scale
		local right = (screenW - self:GetRight()) / scale
		local top = self:GetTop() / scale

		local centerX = self:GetCenter()

		if centerX > screenW / 2 then
			PQ.SV.anchor = "RIGHT"
			PQ.SV.windowOffsetX = right
		else
			PQ.SV.anchor = "LEFT"
			PQ.SV.windowOffsetX = left
		end

		PQ.SV.windowOffsetY = top
	end)

	local background = WINDOW_MANAGER:CreateControl("PvPQoLBackground", window, CT_BACKDROP)
	background:SetAnchorFill()
	background:SetEdgeTexture("PvPQoL/Textures/centerscreen_floating_edge.dds", 256, 256, 8)
	background:SetCenterTexture("PvPQoL/Textures/centerscreen_floating_center.dds")
	background:SetInsets(8, 8, -8, -8)
	background:SetIntegralWrapping(true)
	background:SetAlpha(0.5)
	background:SetCenterColor(0, 0, 0, 1)
	background:SetEdgeColor(0, 0, 0, 1)

	local killIcon = WINDOW_MANAGER:CreateControl("PvPQoLKillIcon", window, CT_TEXTURE)
	killIcon:SetDimensions(24, 24)
	killIcon:SetAnchor(LEFT, window, LEFT, 6, 0)
	killIcon:SetTexture(ICON_EXECUTE)

	local killCount = WINDOW_MANAGER:CreateControl("PvPQoLKillCount", window, CT_LABEL)
	killCount:SetDimensions(50, 24)
	killCount:SetAnchor(LEFT, killIcon, RIGHT, 0, 0)
	killCount:SetFont("ZoFontWinH4")
	killCount:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

	local deathIcon = WINDOW_MANAGER:CreateControl("PvPQoLDeathIcon", window, CT_TEXTURE)
	deathIcon:SetDimensions(24, 24)
	deathIcon:SetAnchor(LEFT, killCount, RIGHT, -30, 0)
	deathIcon:SetTexture(ICON_DEATH)

	local deathCount = WINDOW_MANAGER:CreateControl("PvPQoLDeathCount", window, CT_LABEL)
	deathCount:SetDimensions(50, 24)
	deathCount:SetAnchor(LEFT, deathIcon, RIGHT, 0, 0)
	deathCount:SetFont("ZoFontWinH4")
	deathCount:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

	killCount:SetFont("ZoFontWinH4")
	killCount:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	killCount:SetVerticalAlignment(TEXT_ALIGN_CENTER)

	deathCount:SetFont("ZoFontWinH4")
	deathCount:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	deathCount:SetVerticalAlignment(TEXT_ALIGN_CENTER)

	local fragment = ZO_HUDFadeSceneFragment:New(window)
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)

	local originalShow = fragment.Show
	function fragment:Show(force)
		if not force and (PQ.SV.isHidden or (not (PQ.isInAvA or PQ.isBgActive) and not PQ.SV.showEverywhere)) then
			return
		end
		originalShow(self)
	end

	window:SetHandler("OnMouseEnter", function(self)
		PlaySound(SOUNDS.GAMEPAD_MENU_UP)

		local side = (PQ.SV.anchor == "LEFT") and RIGHT or LEFT
		local offset = (PQ.SV.anchor == "LEFT") and 5 or -5

		InitializeTooltip(InformationTooltip, self, side, offset, 0)
		SetTooltipText(InformationTooltip, table.concat(PQ.GetStatsTooltipLines(), "\n"))
	end)

	window:SetHandler("OnMouseExit", function(self)
		ClearTooltip(InformationTooltip)
	end)

	return {
		window = window,
		killIcon = killIcon,
		killCount = killCount,
		deathIcon = deathIcon,
		deathCount = deathCount,
		background = background,
		fragment = fragment
	}
end

-- =========================
-- Build Stats Tooltip Lines
-- =========================
function PQ.GetStatsTooltipLines()
	local lines = {}

	local kills = PQ.SV.lifetimeKills
	local deaths = PQ.SV.lifetimeDeaths

	table.insert(lines, string.format(" |t22:22:%s|t %s", ICON_EXECUTE, FormatNumber(PQ.SV.lifetimeKills)))
	table.insert(lines, string.format(" |t20:20:%s|t %s", ICON_DEATH, FormatNumber(PQ.SV.lifetimeDeaths)))
	table.insert(lines, string.format(" K/D: %.2f", kills / deaths))
	table.insert(lines, string.format("|t140:5:esoui/art/guild/sectiondivider_left.dds|t"))
	table.insert(lines, string.format(" |t20:20:%s|t %s", ICON_TV, FormatNumber(PQ.SV.lifetimeTelvar)))
	table.insert(lines, string.format(" |t20:20:%s|t %s |t22:22:%s|t", ICON_TV, FormatNumber(PQ.SV.lifetimeTelvarFromKills), ICON_EXECUTE))
	table.insert(lines, string.format(" |t20:20:%s|t %s", ICON_AP, FormatNumber(PQ.SV.lifetimeAP)))

	 if PQ.SV.trackItems then
		table.insert(lines, string.format("|t140:5:esoui/art/guild/sectiondivider_left.dds|t"))

		local sortedItems = {}
		for itemId, item in pairs(TRACKED_ITEMS) do
			table.insert(sortedItems, { id = itemId, data = item })
		end
		table.sort(sortedItems, function(a, b) return a.data.order < b.data.order end)

		for _, entry in ipairs(sortedItems) do
			local looted = PQ.SV[entry.data.svFlag]
			local status = looted and string.format("|t20:20:%s|t", ICON_SUCCESS) or ""
			table.insert(lines, string.format("|t30:30:%s|t|t30:30:esoui/art/icons/fragment_gladiator_proof.dds|t%s",
				entry.data.icon,
				status))
		end
	end

	return lines
end

function PQ.ApplyUIScale()
	if not PQ.ui then return end

	local window = PQ.ui.window
	local oldScale = window:GetScale()
	local newScale = clamp(PQ.SV.uiScale, 1.0, 2.0)

	local screenW = GuiRoot:GetWidth()

	local left = window:GetLeft() / oldScale
	local right = (screenW - window:GetRight()) / oldScale
	local top = window:GetTop() / oldScale

	window:SetScale(newScale)

	if PQ.SV.anchor == "RIGHT" then
		PQ.SV.windowOffsetX = right
	else
		PQ.SV.windowOffsetX = left
	end
	PQ.SV.windowOffsetY = top

	window:ClearAnchors()

	if PQ.SV.anchor == "RIGHT" then
		window:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, - (right * newScale), top * newScale)
	else
		window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left * newScale, top * newScale)
	end
end

function PQ.SetUIScale(scale)
	scale = clamp(scale, 1.0, 2.0)
	PQ.SV.uiScale = scale
	PQ.ApplyUIScale()
	PQ.UpdateUI()
end

function PQ.UpdateUI()
	if not PQ.ui then return end

	local window = PQ.ui.window
	local screenW = GuiRoot:GetWidth()
	local scale = window:GetScale()

	local kills, deaths
	if PQ.isBgActive and not PQ.SV.useUnifiedStats then
		kills = PQ.bgKills
		deaths = PQ.bgDeaths
	else
		kills = PQ.SV.killsToday
		deaths = PQ.SV.deathsToday
	end

	local killText = tostring(kills)
	local deathText = tostring(deaths)

	PQ.ui.killCount:SetText(killText)
	PQ.ui.deathCount:SetText(deathText)

	local killWidth = PQ.ui.killCount:GetStringWidth(killText)
	PQ.ui.killCount:SetWidth(killWidth)

	PQ.ui.deathIcon:ClearAnchors()
	PQ.ui.deathIcon:SetAnchor(LEFT, PQ.ui.killCount, RIGHT, 6, 0)

	local deathWidth = PQ.ui.deathCount:GetStringWidth(deathText)
	PQ.ui.deathCount:SetWidth(deathWidth)

	local newWidth = 74 + killWidth + deathWidth

	local rightDist = (screenW - window:GetRight()) / scale
	local isNearRightEdge = rightDist <= 2

	window:SetWidth(newWidth)

	if isNearRightEdge and PQ.SV.anchor ~= "RIGHT" then
		PQ.SV.anchor = "RIGHT"
		PQ.SV.windowOffsetX = rightDist

		window:ClearAnchors()
		window:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, - (rightDist * scale), PQ.SV.windowOffsetY * scale)

	elseif not isNearRightEdge and PQ.SV.anchor ~= "LEFT" then
		local left = window:GetLeft() / scale

		PQ.SV.anchor = "LEFT"
		PQ.SV.windowOffsetX = left

		window:ClearAnchors()
		window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left * scale, PQ.SV.windowOffsetY * scale)
	end

	PQ.ui.background:ClearAnchors()
	PQ.ui.background:SetAnchorFill()
end

function PQ.UpdateVisibility()
	if not PQ.ui or not PQ.ui.fragment then return end

	if PQ.SV.isHidden then
		PQ.ui.fragment:Hide()
	elseif PQ.SV.showEverywhere or (PQ.isInAvA or PQ.isBgActive) then
		PQ.ui.fragment:Show()
	else
		PQ.ui.fragment:Hide()
	end
end

local function IsIgnoredCurrencyReason(reason)
	return reason == CURRENCY_CHANGE_REASON_PLAYER_INIT
		or reason == CURRENCY_CHANGE_REASON_BANK_DEPOSIT
		or reason == CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
		or reason == CURRENCY_CHANGE_REASON_GUILD_BANK_DEPOSIT
		or reason == CURRENCY_CHANGE_REASON_GUILD_BANK_WITHDRAWAL
end

local function FlushPendingCurrencyMessages()
	local now = GetFrameTimeMilliseconds()
	local remaining = {}

	for _, entry in ipairs(pendingCurrencyMessages) do
		if now - entry.time >= CURRENCY_DELAY_MS then
			if not (entry.isSmallTelvar or entry.isSmallAP) then
				CHAT_SYSTEM:AddMessage(entry.msg)
			end
		else
			table.insert(remaining, entry)
		end
	end

	pendingCurrencyMessages = remaining

	if #pendingCurrencyMessages > 0 then
		zo_callLater(FlushPendingCurrencyMessages, CURRENCY_DELAY_MS)
	end
end

local flushingScheduled = false

local function PrintCurrencyMessage(entry)
	entry.time = GetFrameTimeMilliseconds()
	table.insert(pendingCurrencyMessages, entry)

	if not flushingScheduled then
		flushingScheduled = true
		zo_callLater(function()
			FlushPendingCurrencyMessages()
			flushingScheduled = false
		end, CURRENCY_DELAY_MS)
	end
end

function PQ.OnAlliancePointUpdate(eventCode, alliancePoints, playSound, difference, reason, reasonSupplementaryInfo)
	if PQ.SV.hideAPGains then return end
	if difference <= 0 or not (PQ.isInAvA or PQ.isBgActive) or IsIgnoredCurrencyReason(reason) then return end

	local minAmount = PQ.SV.minAPMessage
	local isSmall = difference < minAmount

	PQ.SV.lifetimeAP = PQ.SV.lifetimeAP + difference

	PrintCurrencyMessage({
		msg = string.format(
			"%s+%s|r|t16:16:%s|t",
			COLOR_WHITE,
			COLOR_AP .. FormatNumber(difference),
			ICON_AP
		),
		isSmallAP = isSmall,
		amount = difference,
		fromKill = false
	})
end

function PQ.OnTelvarUpdate(eventCode, newTelvar, oldTelvar, reason, reasonSupplementaryInfo)
	if PQ.SV.hideTelvarGains then return end
	if newTelvar <= oldTelvar or not (PQ.isInAvA or PQ.isBgActive) or IsIgnoredCurrencyReason(reason) then return end

	local amount = newTelvar - oldTelvar
	local minAmount = PQ.SV.minTelvarMessage
	local isSmall = amount < minAmount

	PQ.SV.lifetimeTelvar = PQ.SV.lifetimeTelvar + amount

	PrintCurrencyMessage({
		msg = string.format(
			"%s+%s|r|t16:16:%s|t",
			COLOR_WHITE,
			COLOR_TV .. FormatNumber(amount),
			ICON_TV
		),
		isSmallTelvar = isSmall,
		amount = amount,
		fromKill = false
	})
end

local function AutoAcceptQueue(eventCode, campaignId, isGroup, state)
	if state == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then

		if PQ.SV.chatQueue then
			CHAT_SYSTEM:AddMessage(string.format("|c33ff33%s|r", GetCampaignName(campaignId)))
		end
		ConfirmCampaignEntry(campaignId, isGroup, true)
	end
end

function PQ.ApplyStandInsSetting()
	if not PQ.SV.enableStandIns then return end

	if PQ.isInAvA or PQ.isBgActive then
		SetCVar("PlayerStandInsEnabled.2", "1")
		SetCVar("PlayerStandInsMaxPerFrame", tostring(PQ.SV.standInsPerFrame))
	else
		SetCVar("PlayerStandInsEnabled.2", "0")
	end
end

-- =========================
-- Combat events
-- =========================
function PQ.OnKillingBlow(_, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, _, _, _, _)

	if not abilityName or abilityName == "" then return end
	abilityName = abilityName:gsub("%^.*", "")

	local source = zo_strformat("<<1>>", sourceName)
	local target = zo_strformat("<<1>>", targetName)

	if not ((sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET)
		and (targetType == COMBAT_UNIT_TYPE_OTHER or targetType == COMBAT_UNIT_TYPE_GROUP or targetType == COMBAT_UNIT_TYPE_PLAYER)) then
		return
	end

	local now = GetFrameTimeMilliseconds()

	PQ.SV.killsToday = PQ.SV.killsToday + 1
	PQ.SV.lifetimeKills = PQ.SV.lifetimeKills + 1

	PQ.UpdateUI()
	PQ.TriggerKillAlert()

	local cachedInfo = PQ.GetCachedTargetInfo(target)
	local cachedAccount = cachedInfo and cachedInfo.account

	local displayName = target
	if PQ.SV.useAccountNames then
		if cachedAccount and cachedAccount ~= "" then
			displayName = cachedAccount
		end
	end

	local targetLink = ZO_LinkHandler_CreatePlayerLink(displayName)

	local rankIcon = ""
	if PQ.SV.showRankIcon and cachedInfo and cachedInfo.rank and cachedInfo.rank > 0 then
		local rankTexture = PQ.rankIcons[cachedInfo.rank]
		if rankTexture then
			rankIcon = string.format("|t24:24:%s|t", rankTexture)
		end
	end

	local icon = PQ.SV.hideKillIcons and "" or string.format("|t28:28:%s|t ", ICON_EXECUTE)
	local arrowAndSkill = ""

	if not PQ.SV.hideArrowAndSkill then
		local spaceBeforeArrow = ""
		if not PQ.SV.showRankIcon or rankIcon == "" then
			spaceBeforeArrow = " "
		end
		arrowAndSkill = string.format(
			"%s|c%s→|r |c%s%s|r",
			spaceBeforeArrow,
			PQ.SV.arrowColor,
			PQ.SV.abilityColor,
			abilityName
		)
	end

	local killMessage = string.format("%s|c%s%s|r%s%s",
		icon,
		PQ.SV.victimColor,
		targetLink,
		rankIcon,
		arrowAndSkill
	)

	if not PQ.SV.hideKillMessages then
		CHAT_SYSTEM:AddMessage(killMessage)
	end

	-- Process pending currency msg
	local remainingMessages = {}
	local apMessages = {}
	local tvMessages = {}

	for _, entry in ipairs(pendingCurrencyMessages) do
		if now - entry.time <= CURRENCY_DELAY_MS then
			if entry.msg:find(ICON_AP) then
				table.insert(apMessages, entry)
			elseif entry.msg:find(ICON_TV) then
				table.insert(tvMessages, entry)
			end
		else
			table.insert(remainingMessages, entry)
		end
	end

	for _, entry in ipairs(apMessages) do
		CHAT_SYSTEM:AddMessage(entry.msg)
	end

	for _, entry in ipairs(tvMessages) do
		CHAT_SYSTEM:AddMessage(entry.msg)
		if entry.amount then
			entry.fromKill = true
			PQ.SV.lifetimeTelvarFromKills = PQ.SV.lifetimeTelvarFromKills + entry.amount
		end
	end

	pendingCurrencyMessages = remainingMessages
end
--==========================================================

function PQ.OnBattlegroundKill(eventCode, killedPlayerCharacterName, killedPlayerDisplayName, killedPlayerBattlegroundTeam,
									killingPlayerCharacterName, killingPlayerDisplayName, killingPlayerBattlegroundTeam,
									battlegroundKillType, killingAbilityId)

	killedPlayerCharacterName = zo_strformat("<<1>>", killedPlayerCharacterName)
	killingPlayerCharacterName = zo_strformat("<<1>>", killingPlayerCharacterName)
	killedPlayerDisplayName = zo_strformat("<<1>>", killedPlayerDisplayName)
	killingPlayerDisplayName = zo_strformat("<<1>>", killingPlayerDisplayName)

	local abilityName = ""
	if killingAbilityId and killingAbilityId > 0 then
		abilityName = GetAbilityName(killingAbilityId)
		if abilityName then
			abilityName = abilityName:gsub("%^.*", "")
		end
	end

	if abilityName == "" then
		abilityName = "???"
	end

	if battlegroundKillType == BATTLEGROUND_KILL_TYPE_KILLING_BLOW then
		if killingPlayerCharacterName == PQ.playerName then
			local target = killedPlayerCharacterName

			if not PQ.SV.useUnifiedStats then
				PQ.bgKills = PQ.bgKills + 1
			else
				PQ.SV.killsToday = PQ.SV.killsToday + 1
			end

			PQ.SV.lifetimeKills = PQ.SV.lifetimeKills + 1

			PQ.UpdateUI()
			PQ.TriggerKillAlert()

			local displayName = target
			if PQ.SV.useAccountNames and killedPlayerDisplayName and killedPlayerDisplayName ~= "" then
				displayName = killedPlayerDisplayName
			end

			local targetLink = ZO_LinkHandler_CreatePlayerLink(displayName)

			local cachedInfo = PQ.GetCachedTargetInfo(target)
			local rankIcon = ""
			if PQ.SV.showRankIcon and cachedInfo and cachedInfo.rank and cachedInfo.rank > 0 then
				local rankTexture = PQ.rankIcons[cachedInfo.rank]
				if rankTexture then
					rankIcon = string.format("|t24:24:%s|t", rankTexture)
				end
			end

			local icon = PQ.SV.hideKillIcons and "" or string.format("|t28:28:%s|t ", ICON_EXECUTE)
			local arrowAndSkill = ""

			if not PQ.SV.hideArrowAndSkill then
				local spaceBeforeArrow = ""
				if not PQ.SV.showRankIcon or rankIcon == "" then
					spaceBeforeArrow = " "
				end
				arrowAndSkill = string.format(
					"%s|c%s→|r |c%s%s|r",
					spaceBeforeArrow,
					PQ.SV.arrowColor,
					PQ.SV.abilityColor,
					abilityName
				)
			end

			local killMessage = string.format("%s|c%s%s|r%s%s",
				icon,
				PQ.SV.victimColor,
				targetLink,
				rankIcon,
				arrowAndSkill
			)

			if not PQ.SV.hideKillMessages then
				CHAT_SYSTEM:AddMessage(killMessage)
			end
		end
	end

	if battlegroundKillType == BATTLEGROUND_KILL_TYPE_KILLED_BY_ENEMY_TEAM then
		if killedPlayerCharacterName == PQ.playerName then

			if not PQ.SV.useUnifiedStats then
				PQ.bgDeaths = PQ.bgDeaths + 1
			else
				PQ.SV.deathsToday = PQ.SV.deathsToday + 1
			end

			PQ.SV.lifetimeDeaths = PQ.SV.lifetimeDeaths + 1

			PQ.UpdateUI()

			if not PQ.SV.hideDeathMessages then
				local displayKiller = killingPlayerCharacterName
				if PQ.SV.useAccountNames and killingPlayerDisplayName and killingPlayerDisplayName ~= "" then
					displayKiller = killingPlayerDisplayName
				end

				local killerLink = ZO_LinkHandler_CreatePlayerLink(displayKiller)
				local icon = PQ.SV.hideKillIcons and "" or string.format("|t28:28:%s|t ", ICON_DEATH)

				local deathMessage = string.format("%s|c%s%s|r",
					icon,
					PQ.SV.killerColor,
					killerLink
				)

				CHAT_SYSTEM:AddMessage(deathMessage)
			end
		end
	end
end

function PQ.OnKilled(eventCode)
	local killer, _, _, _, isPlayer = GetKillingAttackerInfo()
	if not isPlayer or not killer or killer == "" then return end

	if PQ.isBgActive and not PQ.SV.useUnifiedStats then
		PQ.bgDeaths = PQ.bgDeaths + 1
	else
		PQ.SV.deathsToday = PQ.SV.deathsToday + 1
	end

	PQ.SV.lifetimeDeaths = PQ.SV.lifetimeDeaths + 1

	PQ.UpdateUI()

	killer = zo_strformat("<<1>>", killer)

	local cachedInfo = PQ.GetCachedTargetInfo(killer)
	local cachedAccount = cachedInfo and cachedInfo.account

	local displayName = killer
	if PQ.SV.useAccountNames then
		if cachedAccount and cachedAccount ~= "" then
			displayName = cachedAccount
		end
	end

	local killerLink = ZO_LinkHandler_CreatePlayerLink(displayName)

	local icon = PQ.SV.hideKillIcons and "" or string.format("|t28:28:%s|t ", ICON_DEATH)

	if not PQ.SV.hideDeathMessages then
		local deathMessage = string.format("%s|c%s%s|r",
			icon,
			PQ.SV.killerColor,
			killerLink
		)
		CHAT_SYSTEM:AddMessage(deathMessage)
	end
end

function PQ.FlushBGCountersIfLeft()
	if not PQ.isBgActive and (PQ.bgKills > 0 or PQ.bgDeaths > 0) then
		PQ.SV.killsToday = PQ.SV.killsToday + PQ.bgKills
		PQ.SV.deathsToday = PQ.SV.deathsToday + PQ.bgDeaths

		PQ.bgKills = 0
		PQ.bgDeaths = 0

		PQ.UpdateUI()
	end
end

-- =========================
-- Tracked Item Loot Handler
-- =========================

function PQ.OnLootReceived(_, _, _, _, _, lootType, isMe, _, _, itemId)
	if not isMe then return end
	if lootType ~= LOOT_TYPE_ITEM then return end

	local trackedItem = TRACKED_ITEMS[itemId]
	if trackedItem then
		PQ.SV[trackedItem.svFlag] = true
	end
end


-- =========================
-- Daily Reset
-- =========================
function PQ.ResetDaily()
	PQ.SV.killsToday = 0
	PQ.SV.deathsToday = 0
	PQ.SV.todayIC = false
	PQ.SV.todayBG = false
	PQ.SV.todayCYRO = false

	for _, item in pairs(TRACKED_ITEMS) do
		PQ.SV[item.svFlag] = false
	end

	PQ.UpdateUI()
end

function PQ.ManageEventHandlers()
	local inBG = PQ.isBgActive
	local inCyroOrIC = PQ.isInAvA
	local showEverywhere = PQ.SV.showEverywhere

	if not showEverywhere and not inBG and not inCyroOrIC then
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_COMBAT_EVENT)
		EVENT_MANAGER:UnregisterForEvent(PQ.name .. "_BG", EVENT_BATTLEGROUND_KILL)
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_PLAYER_DEAD)
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_TELVAR_STONE_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_ALLIANCE_POINT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_RETICLE_TARGET_CHANGED)
		return
	end

	if not inBG and not PQ.SV.hideDeathMessages then
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_PLAYER_DEAD, PQ.OnKilled)
	else
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_PLAYER_DEAD)
	end

	if inCyroOrIC or inBG then
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_TELVAR_STONE_UPDATE, PQ.OnTelvarUpdate)
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_ALLIANCE_POINT_UPDATE, PQ.OnAlliancePointUpdate)
	else
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_TELVAR_STONE_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_ALLIANCE_POINT_UPDATE)
	end

	if inBG or inCyroOrIC or showEverywhere then
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_RETICLE_TARGET_CHANGED, PQ.OnReticleTargetChanged)
	else
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_RETICLE_TARGET_CHANGED)
	end

	if inBG then
		EVENT_MANAGER:RegisterForEvent(PQ.name .. "_BG", EVENT_BATTLEGROUND_KILL, PQ.OnBattlegroundKill)
		EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_COMBAT_EVENT)
	else
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_COMBAT_EVENT, PQ.OnKillingBlow)
		EVENT_MANAGER:AddFilterForEvent(PQ.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW)
		EVENT_MANAGER:UnregisterForEvent(PQ.name .. "_BG", EVENT_BATTLEGROUND_KILL)
	end
end

function PQ.HideKeepTooltipLines()
	SafeAddString(SI_TOOLTIP_KEEP_GUILD_OWNER, "", 3)
	SafeAddString(SI_TOOLTIP_KEEP_ALLIANCE_OWNER, "", 3)
end

-- =========================
-- Addon Loaded
-- =========================
function PQ.OnAddOnLoaded(eventCode, addonName)
	if addonName ~= PQ.name then return end

	PQ.SV = ZO_SavedVars:NewAccountWide("PvPQoL_SavedVariables", 1, nil, PQ.Defaults)

	PQ.RegisterLAMPanel()
	PQ.ui = CreateUI()
	PQ.UpdateUI()
	PQ.UpdateVisibility()
	PQ.CacheRankIcons()

	if PQ.SV.hideKeepTooltip then
		PQ.HideKeepTooltipLines()
	end

	if PQ.SV.isHidden then
		PQ.ui.fragment:Hide()
	else
		PQ.ui.fragment:Show()
	end

	PQ.SetupAlertBorderColors()

	if PQ.SV.trackItems then
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_LOOT_RECEIVED, PQ.OnLootReceived)
	end

	if PQ.SV.helpIC or PQ.SV.helpBG or PQ.SV.helpCYRO then
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_QUEST_ADDED, PQ.OnQuestAdded)
	end


	if PQ.SV.autoQueue then
		EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, AutoAcceptQueue)
	end

	EVENT_MANAGER:RegisterForEvent(PQ.name .. "_Main", EVENT_PLAYER_ACTIVATED, function()
		PQ.playerName = GetUnitName("player")
		PQ.isBgActive = IsActiveWorldBattleground()
		PQ.isInAvA = IsPlayerInAvAWorld()
		PQ.ManageEventHandlers()
		PQ.FlushBGCountersIfLeft()
		PQ.UpdateUI()
		PQ.ApplyStandInsSetting()
		PQ.CleanupTargetCache()

		local fragment = PQ.ui.fragment
		if not fragment then return end

		if not PQ.SV.isHidden and (PQ.SV.showEverywhere or (PQ.isInAvA or PQ.isBgActive)) then
			fragment:Show()
		else
			fragment:Hide()
		end
	end)

	LibDailyReset.RegisterCallback("OnDailyReset", function()
		PQ.ResetDaily()
	end)

	SLASH_COMMANDS["/pqh"] = function()
		PQ.suppressQuestHelpers = not PQ.suppressQuestHelpers

		local statusIcon = PQ.suppressQuestHelpers and ICON_NO or ICON_SUCCESS

		d(string.format("|cFFD700[PvP QoL]|r |cFFFFFFQuest Helpers|r |t20:20:%s|t", statusIcon))
	end

	EVENT_MANAGER:UnregisterForEvent(PQ.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(PQ.name, EVENT_ADD_ON_LOADED, PQ.OnAddOnLoaded)