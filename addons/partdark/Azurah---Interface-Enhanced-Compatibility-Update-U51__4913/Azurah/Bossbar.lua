local Azurah		= _G['Azurah'] -- grab addon table from global
local LMP			= LibMediaProvider

-- UPVALUES --
local AZ_POWERTYPE_HEALTH 	= COMBAT_MECHANIC_FLAGS_HEALTH
local DoesUnitExist			= DoesUnitExist
local GetUnitPower			= GetUnitPower
local strformat				= string.format

local overlayBossbar
local FormatBossbar
local db
local bossUnitTags = {}
local bossHealthValues = {}

local function RefreshBossOverlay()
	local totalHealth		= 0
	local totalMaxHealth	= 0

	for unitTag, bossEntry in pairs(bossHealthValues) do
		totalHealth = totalHealth + bossEntry.health
		totalMaxHealth = totalMaxHealth + bossEntry.maxHealth
	end

	overlayBossbar:SetText(FormatBossbar(totalHealth, totalMaxHealth, totalMaxHealth))
end

local function RefreshBossHealth(unitTag)
	local health, maxHealth = GetUnitPower(unitTag, AZ_POWERTYPE_HEALTH)
	local bossEntry = bossHealthValues[unitTag]
	if bossEntry then
		bossEntry.health = health
		bossEntry.maxHealth = maxHealth
	end
end

local function AddBoss(unitTag)
	bossHealthValues[unitTag] = {}
	RefreshBossHealth(unitTag)
end

local function RefreshAllBosses()
	--if there are multiple bosses and one of them dies and despawns in the middle of the fight we
	--still want to show them as part of the boss bar (otherwise it will reset to 100%).
	local currentBossCount = 0
	for unitTag in pairs(bossUnitTags) do
		if (DoesUnitExist(unitTag)) then
			AddBoss(unitTag)
			currentBossCount = currentBossCount + 1
		end
	end

	--if there are no bosses left it's safe to reset everything
	if (currentBossCount == 0 and next(bossHealthValues) ~= nil) then
		bossHealthValues = {}
	end

	RefreshBossOverlay()
end

local function OnPowerUpdate(_, unitTag, _, powerType)
	if (bossUnitTags[unitTag] and powerType == AZ_POWERTYPE_HEALTH) then
		RefreshBossHealth(unitTag)
		RefreshBossOverlay()
	end
end

function Azurah:ConfigureBossbarOverlay()
--	if (not IsInGamepadPreferredMode() and db.overlay > 1) then -- showing overlay, enabled tracking
	if db.overlay > 1 then -- showing overlay, enabled tracking
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Bossbar', EVENT_POWER_UPDATE,		OnPowerUpdate)
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Bossbar', EVENT_BOSSES_CHANGED,	RefreshAllBosses)
--		EVENT_MANAGER:RegisterForEvent(self.name .. 'Bossbar', EVENT_PLAYER_ACTIVATED,	RefreshAllBosses)
	else -- no overlay being shown, disable tracking
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Bossbar', EVENT_POWER_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Bossbar', EVENT_BOSSES_CHANGED)
--		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Bossbar', EVENT_PLAYER_ACTIVATED)
	end

	local fontStr, value, max, maxEff

--	if (db.overlay > 1 and not IsInGamepadPreferredMode()) then
	if db.overlay > 1 then
		fontStr = strformat('%s|%d|%s', LMP:Fetch('font', db.fontFace), db.fontSize, db.fontOutline)

		overlayBossbar:SetFont(fontStr)
		overlayBossbar:SetColor(db.fontColour.r, db.fontColour.g, db.fontColour.b, db.fontColour.a)
		overlayBossbar:SetHidden(false)

		FormatBossbar = self.overlayFuncs[db.overlay + ((db.overlayFancy) and 10 or 0)]

		RefreshAllBosses()
	else -- not showing
		overlayBossbar:SetHidden(true)
	end
end


-- ------------------------
-- INITIALIZATION
-- ------------------------
function Azurah:InitializeBossbar()
	db = self.db.bossbar

	-- create overlay
	overlayBossbar = self:CreateOverlay(ZO_BossBarHealth, CENTER, CENTER, 0, -0.5)

	-- set 'dummy' display function
	FormatTarget = self.overlayFuncs[1]

	for i = 1, MAX_BOSSES do
		bossUnitTags["boss"..i] = true
	end
	
	self:ConfigureBossbarOverlay()
end
