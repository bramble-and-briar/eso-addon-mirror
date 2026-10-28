RoaringOpportunist = RoaringOpportunist or { }
local RO = RoaringOpportunist
local EM = GetEventManager()
local LCA = LibCombatAlerts

RO.name = "RoaringOpportunist"
RO.version = "2.5.1"

local colors = {
	["UP"] = {
		0, 1, 0,
	},
	["DOWN"] = {
		1, 0, 0,
	},
	["SLAYERTIMER"] = {
		0, 1, 1,
	},
	["SLAYERLOW"] = {
		1, 1, 0,
	},
	["PROC"] = {
		1, 0, 0,
	}
}

--local pCooldown = 137985
local npCooldown = 135924

--local pSlayer = 137986
local npSlayer = 135923

local types = {
	[1] = "|H1:item:162509:364:50:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
	[2] = "|H1:item:162044:363:50:0:0:0:0:0:0:0:0:0:0:0:1:102:0:1:0:10000:0|h|h",
}

local defaults = {
	["passiveHide"] = false,
	["colors"] = colors,
	["showProcTime"] = true,
	["scale"] = 1,
}

local cooldown1 = 0
local cooldown2 = 0
local starttime1 = 0
local starttime2 = 0
local elapsed1 = 0
local elapsed2 = 0
local newtime1 = 0
local newtime2 = 0
local slayer1 = 0
local slayer2 = 0
local numReceived = 0
local count = 0


local function equipCheck()
	--return true
	local np, p = 0, 0
	_,_,_,_,_,_,p = GetItemLinkSetInfo(types[1], true)
	_,_,_,np = GetItemLinkSetInfo(types[2], true)
	local total = 0
		total = np + p
	if (total >= 3) then return true end
	return false
end

function RO.combatUpdate(e, inCombat)
	if RO.savedVars.passiveHide and not inCombat then
		RO.setHudDisplay(false, true)
	elseif RO.savedVars.passiveHide and inCombat then
		RO.setHudDisplay(true, false)
	end
end

local function setSlayer(frame, time)
	EM:UnregisterForUpdate(RO.name.."SetSlayerTime")
	local g = GetGroupSize()
	if RO.savedVars.slayercount == true then
		count = .1	
	else	
		count = 0
	end
	if frame == 1 then
		slayer1 = time/1000
		if g > 0 and numReceived < g / 2 then
			RO.UI.slayer1:SetColor(unpack(RO.savedVars.colors.SLAYERLOW))
		end
		RO.UI.slayer1:SetText(string.format("%.1f", slayer1))
		EM:RegisterForUpdate(RO.name.."Coundown3", 100, function()
			slayer1 = slayer1 - count
			if slayer1 < 0 then	
				slayer1 = 0
				RO.UI.slayer1:SetColor(unpack(RO.savedVars.colors.SLAYERTIMER))
				RO.UI.slayer1:SetText('0.0')
				EM:UnregisterForEvent(RO.name.."Coundown3")
			end
			RO.UI.slayer1:SetText(string.format("%.1f", slayer1))
		end)		
	else
		slayer2 = time/1000
		if g > 0 and numReceived < g / 2 then
			RO.UI.slayer2:SetColor(unpack(RO.savedVars.colors.SLAYERLOW))
		end
		RO.UI.slayer2:SetText(string.format("%.1f", slayer2))
		EM:RegisterForUpdate(RO.name.."Coundown4", 100, function()
			slayer2 = slayer2 - count
			if slayer2 < 0 then	
				slayer2 = 0
				RO.UI.slayer2:SetColor(unpack(RO.savedVars.colors.SLAYERTIMER))
				RO.UI.slayer2:SetText('0.0')
				EM:UnregisterForEvent(RO.name.."Coundown4")
			end
			RO.UI.slayer2:SetText(string.format("%.1f", slayer2))
		end)
	end
	numReceived = 0
end

local function startCountdown(frame, time)
	EM:UnregisterForUpdate(RO.name.."StartCountdown")
	if frame == 1 then
		starttime1 = GetGameTimeMilliseconds()/1000
		cooldown1 = time/1000
		RO.UI.countdown1:SetColor(unpack(RO.savedVars.colors.DOWN))
		RO.UI.countdown1:SetText(string.format("%.1f", cooldown1))
		EM:RegisterForUpdate(RO.name.."Coundown1", 100, function()
			newtime1 = GetGameTimeMilliseconds()/1000
			elapsed1 = newtime1 - starttime1
			starttime1 = newtime1
			cooldown1 = cooldown1 - elapsed1
			if cooldown1 < 2 then
				RO.UI.countdown1:SetColor(unpack(RO.savedVars.colors.PROC))
			end
			if cooldown1 < 0 then
				cooldown1 = 0
				RO.UI.countdown1:SetColor(unpack(RO.savedVars.colors.UP))
				RO.UI.slayer1:SetColor(unpack(RO.savedVars.colors.SLAYERTIMER))
				RO.UI.slayer1:SetText('0.0')
				slayer1 = 0
				EM:UnregisterForUpdate(RO.name.."Coundown1")
			end
			RO.UI.countdown1:SetText(string.format("%.1f", cooldown1))
		end)
	else
		starttime2 = GetGameTimeMilliseconds()/1000
		cooldown2 = time/1000
		RO.UI.countdown2:SetColor(unpack(RO.savedVars.colors.DOWN))
		RO.UI.countdown2:SetText(string.format("%.1f", cooldown2))
		EM:RegisterForUpdate(RO.name.."Coundown2", 100, function()
			newtime2 = GetGameTimeMilliseconds()/1000
			elapsed2 = newtime2 - starttime2
			starttime2 = newtime2
			cooldown2 = cooldown2 - elapsed2
			if cooldown2 < 2 then	
				RO.UI.countdown2:SetColor(unpack(RO.savedVars.colors.PROC))
			end
			if cooldown2 < 0 then
				cooldown2 = 0
				RO.UI.countdown2:SetColor(unpack(RO.savedVars.colors.UP))
				RO.UI.slayer2:SetColor(unpack(RO.savedVars.colors.SLAYERTIMER))
				RO.UI.slayer2:SetText('0.0')
				slayer2 = 0
				EM:UnregisterForUpdate(RO.name.."Coundown2")
			end
			RO.UI.countdown2:SetText(string.format("%.1f", cooldown2))
		end)
	end
end

local function cooldownHandler(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
	if cooldown1 <= 0.1 then
		EM:UnregisterForUpdate(RO.name.."StartCountdown")
		EM:RegisterForUpdate(RO.name.."StartCountdown", 5, function() startCountdown(1, hitValue) end)
	elseif cooldown2 <= 0.1 then
		EM:UnregisterForUpdate(RO.name.."StartCountdown")
		EM:RegisterForUpdate(RO.name.."StartCountdown", 5, function() startCountdown(2, hitValue) end)
	end
end

local function slayerHandler(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
	if slayer1 == 0 then
		numReceived = numReceived + 1
		EM:UnregisterForUpdate(RO.name.."SetSlayerTime")
		EM:RegisterForUpdate(RO.name.."SetSlayerTime", 5, function() setSlayer(1, hitValue) end)
	elseif slayer2 == 0 then
		numReceived = numReceived + 1
		EM:UnregisterForUpdate(RO.name.."SetSlayerTime")
		EM:RegisterForUpdate(RO.name.."SetSlayerTime", 5, function() setSlayer(2, hitValue) end)
	end
end

function RO.gearUpdate()
	if equipCheck() then
		RO.setHudDisplay(true, false)
		RO.combatUpdate(nil, IsUnitInCombat('player'))
		EM:RegisterForEvent(RO.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, RO.combatUpdate)

		--EM:RegisterForEvent(RO.name.."pCooldown", EVENT_COMBAT_EVENT, cooldownHandler)
		--EM:AddFilterForEvent(RO.name.."pCooldown", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, pCooldown, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
		EM:RegisterForEvent(RO.name.."npCooldown", EVENT_COMBAT_EVENT, cooldownHandler)
		EM:AddFilterForEvent(RO.name.."npCooldown", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, npCooldown, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

		--EM:RegisterForEvent(RO.name.."pSlayerTime", EVENT_COMBAT_EVENT, slayerHandler)
		--EM:AddFilterForEvent(RO.name.."pSlayerTime", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, pSlayer, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
		EM:RegisterForEvent(RO.name.."npSlayerTime", EVENT_COMBAT_EVENT, slayerHandler)
		EM:AddFilterForEvent(RO.name.."npSlayerTime", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, npSlayer, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
	else
		RO.setHudDisplay(false, true)
		EM:UnregisterForEvent(RO.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE)
		--EM:UnregisterForEvent(RO.name.."pCooldown", EVENT_COMBAT_EVENT)
		EM:UnregisterForEvent(RO.name.."npCooldown", EVENT_COMBAT_EVENT)
		--EM:UnregisterForEvent(RO.name.."pSlayerTime", EVENT_COMBAT_EVENT)
		EM:UnregisterForEvent(RO.name.."npSlayerTime", EVENT_COMBAT_EVENT)
	end
end

local function init(e, addon)
	if addon ~= RO.name then return end
	EM:UnregisterForEvent(RO.name.."Load", EVENT_ADD_ON_LOADED)

	RO.savedVars = ZO_SavedVars:NewAccountWide("RoaringOpportunistSavedVars", 2, nil, defaults, nil, "$InstallationWide")
	local sv = RoaringOpportunist.savedVars
	if (type(sv.offsetX) == "number" and type(sv.offsetY) == "number") then
        sv.pos = {
            left = sv.offsetX,
            top = sv.offsetY,
        }
        sv.offsetX = nil
        sv.offsetY = nil
	end
	if (not sv.pos) then
		sv.pos = {
			left = 500,
			top	= 500,
		}
	end
	RO.setupUI()

	RO.gearUpdate()

	RO.buildMenu()

	EM:RegisterForEvent(RO.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, RO.gearUpdate)
	EM:AddFilterForEvent(RO.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

end

EM:RegisterForEvent(RO.name.."Load", EVENT_ADD_ON_LOADED, init)

