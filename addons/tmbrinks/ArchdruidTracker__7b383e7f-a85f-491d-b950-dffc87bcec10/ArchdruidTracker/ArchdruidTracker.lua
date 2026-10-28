ArchdruidTracker = ArchdruidTracker or { }
local ArchdruidTracker = ArchdruidTracker

local EM		= GetEventManager()

local LCA = LibCombatAlerts

ArchdruidTracker.name		= "ArchdruidTracker"
ArchdruidTracker.version		= "1.1.1"
ArchdruidTracker.varVersion 	= "1"

local ECE_NAME = ArchdruidTracker.name.."ECE"
local function StartListening( )
	EM:RegisterForEvent(ECE_NAME, EVENT_COMBAT_EVENT, ArchdruidTracker.combatEvent)
	EM:AddFilterForEvent(ECE_NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
	EM:AddFilterForEvent(ECE_NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 176813)
end

ArchdruidTracker.IDs 		= {
	[176813] = true, -- bear proc
}
ArchdruidTracker.downTime	= 0

ArchdruidTracker.UPDATE_INTERVAL	= 100

ArchdruidTracker.COLORS = {
	["UP"] = {
		0, 1, 0,
	},
	["DOWN"] = {
		1, 0, 0,
	},
	["WARNING"] = {
		1, 0.5, 0,
	},
	["OTHER"] = {
		0, 1, 1,
	}
}

ArchdruidTracker.TYPES = {
	[1] = "|H1:item:189351:364:50:26582:370:50:18:0:0:0:0:0:0:0:2049:67:0:1:0:10000:0|h|h",
}

ArchdruidTracker.defaults	= {
	["timerSize"]	= 48,
	["passiveHide"]	= false,
	["COLORS"]	= ArchdruidTracker.COLORS,
}

function ArchdruidTracker.equipCheck()
	local np, p = 0
	_,_,_,_,_,_,p = GetItemLinkSetInfo(ArchdruidTracker.TYPES[1], true)
	_,_,_,np = GetItemLinkSetInfo(ArchdruidTracker.TYPES[1], true)
	local total = 0
		total = np + p
	if (total >= 2) then return true end
	return false
end

function ArchdruidTracker.gearUpdate()
	if ArchdruidTracker.equipCheck() then
		ArchdruidTracker.hideFrame()
		EM:RegisterForEvent(ArchdruidTracker.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, ArchdruidTracker.hideFrame)
		EM:RegisterForEvent(ArchdruidTracker.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, ArchdruidTracker.combatState)

		StartListening()
	else
		ArchdruidTrackerFrame:SetHidden(true)
		EM:UnregisterForEvent(ArchdruidTracker.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, ArchdruidTracker.hideFrame)
		EM:UnregisterForEvent(ArchdruidTracker.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, ArchdruidTracker.combatState)

		EM:UnregisterForEvent(ECE_NAME, EVENT_COMBAT_EVENT)
	end
end

function ArchdruidTracker.combatState()
	if not ArchdruidTracker.equipCheck() then return end
	ArchdruidTracker.hideOutOfCombat()
end

function ArchdruidTracker.setPos()
local handler = LCA.MoveableControl:New(ArchdruidTrackerFrame)
	handler:UpdatePosition(ArchdruidTracker.savedVars.pos)
	handler:RegisterCallback("ArchdruidTracker", LCA.EVENT_CONTROL_MOVE_STOP, function(newPos)
		ArchdruidTracker.savedVars.pos = newPos
	end)
	ArchdruidTracker.posHandler = handler
end

--[[function ArchdruidTracker.setPos()
	local x, y = ArchdruidTracker.savedVars.offsetX, ArchdruidTracker.savedVars.offsetY
	ArchdruidTrackerFrame:ClearAnchors()
	ArchdruidTrackerFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end]]

--[[function ArchdruidTracker.savePos()
	ArchdruidTracker.savedVars.offsetX = ArchdruidTrackerFrame:GetLeft()
	ArchdruidTracker.savedVars.offsetY = ArchdruidTrackerFrame:GetTop()
end]]

function ArchdruidTracker.hideOutOfCombat()
	if ArchdruidTracker.savedVars.passiveHide then 
		ArchdruidTrackerFrame:SetHidden(not IsUnitInCombat("player"))
	end
end

function ArchdruidTracker.hideFrame()
	ArchdruidTrackerFrame:SetHidden(IsReticleHidden())
	if not IsReticleHidden() then ArchdruidTracker.hideOutOfCombat() end
end

function ArchdruidTracker.setFontSize(size)
	ArchdruidTrackerFrameTime:SetFont(string.format('%s|%d|%s', '$(CHAT_FONT)', size, 'soft-shadow-thick'))
end

function ArchdruidTracker.countDown()
 	if not ArchdruidTracker.active and (ArchdruidTracker.downTime - GetGameTimeMilliseconds()/1000 > 0) then
		ArchdruidTrackerFrameTime:SetText(string.format("%.1f", ArchdruidTracker.time(ArchdruidTracker.downTime)))
		if (ArchdruidTracker.downTime - GetGameTimeMilliseconds ()/1000 < 2) then	
			ArchdruidTrackerFrameTime:SetColor(unpack(ArchdruidTracker.savedVars.COLORS.WARNING))
		end
	else
		ArchdruidTrackerFrameTime:SetColor(unpack(ArchdruidTracker.savedVars.COLORS.UP))
		ArchdruidTrackerFrameTime:SetText("0.0")
		ArchdruidTracker.downTime = 0
		EM:UnregisterForUpdate(ArchdruidTracker.name.."Update")
	end
end

function ArchdruidTracker.time(nd)
	return math.floor((nd - GetGameTimeMilliseconds()/1000) * 10 + 0.5)/10
end

function ArchdruidTracker.combatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
	EM:RegisterForUpdate(ArchdruidTracker.name.."Update", ArchdruidTracker.UPDATE_INTERVAL, ArchdruidTracker.countDown)
	if sourceType == COMBAT_UNIT_TYPE_NONE and ArchdruidTracker.downTime < GetGameTimeMilliseconds()/1000 + 7 then
		ArchdruidTracker.downTime = GetGameTimeMilliseconds()/1000 + 7
		ArchdruidTrackerFrameTime:SetColor(unpack(ArchdruidTracker.savedVars.COLORS.OTHER))
	elseif sourceType == COMBAT_UNIT_TYPE_PLAYER then
		ArchdruidTracker.downTime = GetGameTimeMilliseconds()/1000 + 15
		ArchdruidTrackerFrameTime:SetColor(unpack(ArchdruidTracker.savedVars.COLORS.DOWN))
	end
	
	--ArchdruidTracker.downTime = GetGameTimeMilliseconds()/1000 + 15	-- 15 seconds after Archdruid procs
	ArchdruidTracker.active = false
end

function ArchdruidTracker.Init(event, addon)
	if addon ~= ArchdruidTracker.name then return end
	EM:UnregisterForEvent(ArchdruidTracker.name.."Load", EVENT_ADD_ON_LOADED)

	ArchdruidTracker.savedVars = ZO_SavedVars:NewAccountWide(ArchdruidTracker.name.."SavedVars", ArchdruidTracker.varVersion, nil, ArchdruidTracker.defaults, nil, "$InstallationWide")
	local sv = ArchdruidTracker.savedVars
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
	
	ArchdruidTracker.setFontSize(ArchdruidTracker.savedVars.timerSize)
	ArchdruidTracker.setPos()
	ArchdruidTrackerFrame:SetHidden(IsReticleHidden())
	ArchdruidTrackerFrameTime:SetColor(unpack(ArchdruidTracker.savedVars.COLORS.UP))

	ArchdruidTracker.setupMenu()
	ArchdruidTracker.hideOutOfCombat()

	EM:RegisterForEvent(ArchdruidTracker.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, ArchdruidTracker.hideFrame)
	EM:RegisterForEvent(ArchdruidTracker.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, ArchdruidTracker.combatState)

	StartListening()

	EM:RegisterForEvent(ArchdruidTracker.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ArchdruidTracker.gearUpdate)
	EM:AddFilterForEvent(ArchdruidTracker.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

	ArchdruidTracker.gearUpdate()

end

EM:RegisterForEvent(ArchdruidTracker.name.."Load", EVENT_ADD_ON_LOADED, ArchdruidTracker.Init)
