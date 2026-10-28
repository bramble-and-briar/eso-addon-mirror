TurningTide = TurningTide or { }
local TurningTide = TurningTide

local EM		= GetEventManager()

local LCA = LibCombatAlerts

TurningTide.name		= "TurningTide"
TurningTide.version		= "1.1.1"
TurningTide.varVersion 	= "1"

TurningTide.IDs 		= {
	[167350] = true,
}

TurningTide.downTime	= 0

TurningTide.UPDATE_INTERVAL	= 100

TurningTide.COLORS = {
	["UP"] = {
		0, 1, 0,
	},
	["DOWN"] = {
		1, 0, 0,
	},
	["WARNING"] = {
		1, 0.5, 0,
	}
}

TurningTide.TYPES = {
	[1] = "|H1:item:181739:364:50:0:0:0:0:0:0:0:0:0:0:0:1:128:0:1:0:10000:0|h|h",
}

TurningTide.defaults	= {
	["timerSize"]	= 48,
	["passiveHide"]	= true,
	["COLORS"]	= TurningTide.COLORS,
}

function TurningTide.equipCheck()
	local np = 0
	_,_,_,np = GetItemLinkSetInfo(TurningTide.TYPES[1], true)
	local total = 0
		total = np
	if (total >= 3) then return true end
	return false
end

function TurningTide.gearUpdate()
	if TurningTide.equipCheck() then
		TurningTide.hideFrame()
		EM:RegisterForEvent(TurningTide.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, TurningTide.hideFrame)
		EM:RegisterForEvent(TurningTide.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, TurningTide.combatState)

		EM:RegisterForEvent(TurningTide.name.."EEC", EVENT_EFFECT_CHANGED, TurningTide.combatEvent)
		EM:AddFilterForEvent(TurningTide.name.."EEC", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
	else
		TurningTideFrame:SetHidden(true)
		EM:UnregisterForEvent(TurningTide.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, TurningTide.hideFrame)
		EM:UnregisterForEvent(TurningTide.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, TurningTide.combatState)

		EM:UnregisterForEvent(TurningTide.name.."EEC", EVENT_COMBAT_EVENT, TurningTide.combatEvent)
	end
end

function TurningTide.combatState()
	if not TurningTide.equipCheck() then return end
	TurningTide.hideOutOfCombat()
end

function TurningTide.setPos()
	local handler = LCA.MoveableControl:New(TurningTideFrame)
	handler:UpdatePosition(TurningTide.savedVars.pos)
	handler:RegisterCallback("TurningTide", LCA.EVENT_CONTROL_MOVE_STOP, function(newPos)
		TurningTide.savedVars.pos = newPos
	end)
	TurningTide.posHandler = handler
end

--[[function TurningTide.savePos()
	TurningTide.savedVars.offsetX = TurningTideFrame:GetLeft()
	TurningTide.savedVars.offsetY = TurningTideFrame:GetTop()
end]]

function TurningTide.hideOutOfCombat()
	if TurningTide.savedVars.passiveHide then 
		TurningTideFrame:SetHidden(not IsUnitInCombat("player"))
	end
end

function TurningTide.hideFrame()
	TurningTideFrame:SetHidden(IsReticleHidden())
	if not IsReticleHidden() then TurningTide.hideOutOfCombat() end
end

function TurningTide.setFontSize(size)
	TurningTideFrameTime:SetFont(string.format('%s|%d|%s', '$(CHAT_FONT)', size, 'soft-shadow-thick'))
	TurningTideFrameCountdown:SetFont(string.format('%s|%d|%s', '$(CHAT_FONT)', size-12, 'soft-shadow-thick'))
end

function TurningTide.countDown()
 	if not TurningTide.active then
		TurningTideFrameTime:SetText(string.format("BASH", TurningTide.time(TurningTide.downTime)))
	else
		TurningTideFrameTime:SetColor(unpack(TurningTide.savedVars.COLORS.DOWN))
		TurningTideFrameTime:SetText("DOWN")
		EM:UnregisterForUpdate(TurningTide.name.."Update")
	end
end

function TurningTide.countDown2()
	if not TurningTide.active and (TurningTide.downTime - GetGameTimeMilliseconds()/1000 > 0) then	
		TurningTideFrameCountdown:SetText(string.format("%.0f", TurningTide.time(TurningTide.downTime)))
		if (TurningTide.downTime - GetGameTimeMilliseconds()/1000 < 8.5) then	
			TurningTideFrameCountdown:SetColor(unpack(TurningTide.savedVars.COLORS.WARNING))
		end
		if (TurningTide.downTime - GetGameTimeMilliseconds()/1000 < 5.5) then
			TurningTideFrameCountdown:SetColor(unpack(TurningTide.savedVars.COLORS.DOWN))
		end
	else
		TurningTideFrameCountdown:SetColor(unpack(TurningTide.savedVars.COLORS.DOWN))
		TurningTideFrameCountdown:SetText("0")
		EM:UnregisterForUpdate(TurningTide.name.."Update2")
	end
	
end

function TurningTide.time(nd)
	return math.floor((nd - GetGameTimeMilliseconds()/1000) * 10 + 0.5)/10
end

function TurningTide.combatEvent(_, changeType, _, _, _, _, _, _, _, _, _, _, _, _, _, abilityID)
	if TurningTide.IDs[abilityID] and changeType == EFFECT_RESULT_GAINED then
		EM:RegisterForUpdate(TurningTide.name.."Update", TurningTide.UPDATE_INTERVAL, TurningTide.countDown)
		EM:RegisterForUpdate(TurningTide.name.."Update2", TurningTide.UPDATE_INTERVAL, TurningTide.countDown2)
		TurningTide.downTime = GetGameTimeMilliseconds()/1000 + 15		-- 15 seconds after TurningTide procs
		TurningTideFrameTime:SetColor(unpack(TurningTide.savedVars.COLORS.UP))
		TurningTideFrameCountdown:SetColor(unpack(TurningTide.savedVars.COLORS.UP))
		TurningTide.active = false
	end
	if TurningTide.IDs[abilityID] and changeType == EFFECT_RESULT_FADED then	
		TurningTideFrameTime:SetColor(unpack(TurningTide.savedVars.COLORS.DOWN))
		TurningTideFrameTime:SetText("DOWN")
		EM:UnregisterForUpdate(TurningTide.name.."Update")
	end
end

function TurningTide.Init(event, addon)
	if addon ~= TurningTide.name then return end
	EM:UnregisterForEvent(TurningTide.name.."Load", EVENT_ADD_ON_LOADED)

	TurningTide.savedVars = ZO_SavedVars:NewAccountWide(TurningTide.name.."SavedVars", TurningTide.varVersion, nil, TurningTide.defaults, nil, "$InstallationWide")
	local sv = TurningTide.savedVars
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
	
	TurningTide.setFontSize(TurningTide.savedVars.timerSize)
	TurningTide.setPos()
	TurningTideFrame:SetHidden(true)
	TurningTideFrameTime:SetColor(unpack(TurningTide.savedVars.COLORS.DOWN))
	TurningTideFrameCountdown:SetColor(unpack(TurningTide.savedVars.COLORS.DOWN))

	TurningTide.setupMenu()
	TurningTide.hideOutOfCombat()
	
	EM:RegisterForEvent(TurningTide.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, TurningTide.hideFrame)
	EM:RegisterForEvent(TurningTide.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, TurningTide.combatState)

	EM:RegisterForEvent(TurningTide.name.."EEC", EVENT_EFFECT_CHANGED, TurningTide.combatEvent)
	EM:AddFilterForEvent(TurningTide.name.."EEC", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

	EM:RegisterForEvent(TurningTide.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, TurningTide.gearUpdate)
	EM:AddFilterForEvent(TurningTide.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
	
	TurningTide.equipCheck()
	TurningTide.gearUpdate()

end

EM:RegisterForEvent(TurningTide.name.."Load", EVENT_ADD_ON_LOADED, TurningTide.Init)


