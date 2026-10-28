Olorime = Olorime or { }
local Olorime = Olorime

local EM		= GetEventManager()
local LCA = LibCombatAlerts

Olorime.name		= "Olorime"
Olorime.version		= "2.3.1"
Olorime.varVersion 	= "1"

Olorime.IDs 		= {
	[107141] = true,
	[109084] = true,
}
Olorime.downTime	= 0

Olorime.UPDATE_INTERVAL	= 100

Olorime.COLORS = {
	["UP"] = {
		0, 1, 0,
	},
	["DOWN"] = {
		1, 0, 0,
	}
}

Olorime.TYPES = {
	[1] = "|H1:item:137418:364:50:0:0:0:0:0:0:0:0:0:0:0:1:73:0:1:0:34:0|h|h",
	[2] = "|H1:item:138634:364:50:0:0:0:0:0:0:0:0:0:0:0:1:73:0:1:0:489:0|h|h",
}

Olorime.defaults	= {
	["timerSize"]	= 48,
	["passiveHide"]	= false,
	["COLORS"]	= Olorime.COLORS,
}

function Olorime.equipCheck()
	local np, p = 0
	_,_,_,_,_,_,p = GetItemLinkSetInfo(Olorime.TYPES[2], true)
	_,_,_,np = GetItemLinkSetInfo(Olorime.TYPES[1], true)
	local total = 0
		total = np + p
	if (total >= 3) then return true end
	return false
end

function Olorime.gearUpdate()
	if Olorime.equipCheck() then
		Olorime.hideFrame()
		EM:RegisterForEvent(Olorime.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, Olorime.hideFrame)
		EM:RegisterForEvent(Olorime.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, Olorime.combatState)

		EM:RegisterForEvent(Olorime.name.."ECE", EVENT_COMBAT_EVENT, Olorime.combatEvent)
		EM:AddFilterForEvent(Olorime.name.."ECE", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
	else
		OlorimeFrame:SetHidden(true)
		EM:UnregisterForEvent(Olorime.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, Olorime.hideFrame)
		EM:UnregisterForEvent(Olorime.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, Olorime.combatState)

		EM:UnregisterForEvent(Olorime.name.."ECE", EVENT_COMBAT_EVENT, Olorime.combatEvent)
	end
end

function Olorime.combatState()
	if not Olorime.equipCheck() then return end
	Olorime.hideOutOfCombat()
end

function Olorime.setPos()
local handler = LCA.MoveableControl:New(OlorimeFrame)
	handler:UpdatePosition(Olorime.savedVars.pos)
	handler:RegisterCallback("Olorime", LCA.EVENT_CONTROL_MOVE_STOP, function(newPos)
		Olorime.savedVars.pos = newPos
	end)
	Olorime.posHandler = handler
end

--[[function Olorime.savePos()
	Olorime.savedVars.offsetX = OlorimeFrame:GetLeft()
	Olorime.savedVars.offsetY = OlorimeFrame:GetTop()
end]]

function Olorime.hideOutOfCombat()
	if Olorime.savedVars.passiveHide then 
		OlorimeFrame:SetHidden(not IsUnitInCombat("player"))
	end
end

function Olorime.hideFrame()
	OlorimeFrame:SetHidden(IsReticleHidden())
	if not IsReticleHidden() then Olorime.hideOutOfCombat() end
end

function Olorime.setFontSize(size)
	OlorimeFrameTime:SetFont(string.format('%s|%d|%s', '$(CHAT_FONT)', size, 'soft-shadow-thick'))
end

function Olorime.countDown()
 	if not Olorime.active and (Olorime.downTime - GetGameTimeMilliseconds()/1000 > 0) then
		OlorimeFrameTime:SetText(string.format("%.1f", Olorime.time(Olorime.downTime)))
	else
		OlorimeFrameTime:SetColor(unpack(Olorime.savedVars.COLORS.UP))
		OlorimeFrameTime:SetText("0.0")
		EM:UnregisterForUpdate(Olorime.name.."Update")
	end
end

function Olorime.time(nd)
	return math.floor((nd - GetGameTimeMilliseconds()/1000) * 10 + 0.5)/10
end

function Olorime.combatEvent(_, _, _, _, _, _, sourceName, _, _, _, _, _, _, _, _, _, abilityID)
	-- TODO: filter for player
	if Olorime.IDs[abilityID] and zo_strformat(SI_UNIT_NAME, sourceName) == zo_strformat(SI_UNIT_NAME, GetUnitName("player")) then
		EM:RegisterForUpdate(Olorime.name.."Update", Olorime.UPDATE_INTERVAL, Olorime.countDown)
		Olorime.downTime = GetGameTimeMilliseconds()/1000 + 10	-- 10 seconds after olorime procs
		OlorimeFrameTime:SetColor(unpack(Olorime.savedVars.COLORS.DOWN))
		Olorime.active = false
	end
end

function Olorime.Init(event, addon)
	if addon ~= Olorime.name then return end
	EM:UnregisterForEvent(Olorime.name.."Load", EVENT_ADD_ON_LOADED)

	Olorime.savedVars = ZO_SavedVars:NewAccountWide(Olorime.name.."SavedVars", Olorime.varVersion, nil, Olorime.defaults, nil, "$InstallationWide")
	local sv = Olorime.savedVars
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
	
	Olorime.setFontSize(Olorime.savedVars.timerSize)
	Olorime.setPos()
	OlorimeFrame:SetHidden(IsReticleHidden())
	OlorimeFrameTime:SetColor(unpack(Olorime.savedVars.COLORS.UP))

	Olorime.setupMenu()
	Olorime.hideOutOfCombat()
	

	EM:RegisterForEvent(Olorime.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, Olorime.hideFrame)
	EM:RegisterForEvent(Olorime.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, Olorime.combatState)

	EM:RegisterForEvent(Olorime.name.."ECE", EVENT_COMBAT_EVENT, Olorime.combatEvent)
	EM:AddFilterForEvent(Olorime.name.."ECE", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)

	EM:RegisterForEvent(Olorime.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Olorime.gearUpdate)
	EM:AddFilterForEvent(Olorime.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
	
	Olorime.gearUpdate()

end

EM:RegisterForEvent(Olorime.name.."Load", EVENT_ADD_ON_LOADED, Olorime.Init)
