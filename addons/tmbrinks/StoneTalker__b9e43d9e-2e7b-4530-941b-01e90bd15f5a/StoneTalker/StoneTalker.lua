StoneTalker = StoneTalker or { }
local StoneTalker = StoneTalker

local EM		= GetEventManager()

local LCA = LibCombatAlerts

StoneTalker.name		= "StoneTalker"
StoneTalker.version		= "1.1.1"
StoneTalker.varVersion 	= "1"

StoneTalker.IDs 		= {
	[154783] = true,
	--[109084] = true,
}
StoneTalker.downTime	= 0

StoneTalker.UPDATE_INTERVAL	= 100

StoneTalker.COLORS = {
	["UP"] = {
		0, 1, 0,
	},
	["DOWN"] = {
		1, 0, 0,
	}
}

StoneTalker.TYPES = {
	[1] = "|H0:item:174019:362:50:0:0:0:0:0:0:0:0:0:0:0:2048:122:0:0:0:10000:0|h|h",
	[2] = "|H1:item:174831:364:50:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
}

StoneTalker.defaults	= {
	["timerSize"]	= 48,
	["passiveHide"]	= false,
	["COLORS"]	= StoneTalker.COLORS,
}

function StoneTalker.equipCheck()
	local np, p = 0
	_,_,_,_,_,_,p = GetItemLinkSetInfo(StoneTalker.TYPES[1], true)
	_,_,_,np = GetItemLinkSetInfo(StoneTalker.TYPES[2], true)
	local total = 0
		total = np + p
	if (total >= 3) then return true end
	return false
end

function StoneTalker.gearUpdate()
	if StoneTalker.equipCheck() then
		StoneTalker.hideFrame()
		EM:RegisterForEvent(StoneTalker.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, StoneTalker.hideFrame)
		EM:RegisterForEvent(StoneTalker.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, StoneTalker.combatState)

		EM:RegisterForEvent(StoneTalker.name.."ECE", EVENT_COMBAT_EVENT, StoneTalker.combatEvent)
		EM:AddFilterForEvent(StoneTalker.name.."ECE", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
	else
		StoneTalkerFrame:SetHidden(true)
		EM:UnregisterForEvent(StoneTalker.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, StoneTalker.hideFrame)
		EM:UnregisterForEvent(StoneTalker.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, StoneTalker.combatState)

		EM:UnregisterForEvent(StoneTalker.name.."ECE", EVENT_COMBAT_EVENT, StoneTalker.combatEvent)
	end
end

function StoneTalker.combatState()
	if not StoneTalker.equipCheck() then return end
	StoneTalker.hideOutOfCombat()
end

function StoneTalker.setPos()
local handler = LCA.MoveableControl:New(StoneTalkerFrame)
	handler:UpdatePosition(StoneTalker.savedVars.pos)
	handler:RegisterCallback("StoneTalker", LCA.EVENT_CONTROL_MOVE_STOP, function(newPos)
		StoneTalker.savedVars.pos = newPos
	end)
	StoneTalker.posHandler = handler
end

--[[function StoneTalker.setPos()
	local x, y = StoneTalker.savedVars.offsetX, StoneTalker.savedVars.offsetY
	StoneTalkerFrame:ClearAnchors()
	StoneTalkerFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function StoneTalker.savePos()
	StoneTalker.savedVars.offsetX = StoneTalkerFrame:GetLeft()
	StoneTalker.savedVars.offsetY = StoneTalkerFrame:GetTop()
end]]

function StoneTalker.hideOutOfCombat()
	if StoneTalker.savedVars.passiveHide then 
		StoneTalkerFrame:SetHidden(not IsUnitInCombat("player"))
	end
end

function StoneTalker.hideFrame()
	StoneTalkerFrame:SetHidden(IsReticleHidden())
	if not IsReticleHidden() then StoneTalker.hideOutOfCombat() end
end

function StoneTalker.setFontSize(size)
	StoneTalkerFrameTime:SetFont(string.format('%s|%d|%s', '$(CHAT_FONT)', size, 'soft-shadow-thick'))
end

function StoneTalker.countDown()
 	if not StoneTalker.active and (StoneTalker.downTime - GetGameTimeMilliseconds()/1000 > 0) then
		StoneTalkerFrameTime:SetText(string.format("%.1f", StoneTalker.time(StoneTalker.downTime)))
	else
		StoneTalkerFrameTime:SetColor(unpack(StoneTalker.savedVars.COLORS.UP))
		StoneTalkerFrameTime:SetText("0.0")
		EM:UnregisterForUpdate(StoneTalker.name.."Update")
	end
end

function StoneTalker.time(nd)
	return math.floor((nd - GetGameTimeMilliseconds()/1000) * 10 + 0.5)/10
end

function StoneTalker.combatEvent(_, _, _, _, _, _, sourceName, _, _, _, _, _, _, _, _, _, abilityID)
	-- TODO: filter for player
	if StoneTalker.IDs[abilityID] and zo_strformat(SI_UNIT_NAME, sourceName) == zo_strformat(SI_UNIT_NAME, GetUnitName("player")) then
		EM:RegisterForUpdate(StoneTalker.name.."Update", StoneTalker.UPDATE_INTERVAL, StoneTalker.countDown)
		StoneTalker.downTime = GetGameTimeMilliseconds()/1000 + 10	-- 10 seconds after StoneTalker procs
		StoneTalkerFrameTime:SetColor(unpack(StoneTalker.savedVars.COLORS.DOWN))
		StoneTalker.active = false
	end
end

function StoneTalker.Init(event, addon)
	if addon ~= StoneTalker.name then return end
	EM:UnregisterForEvent(StoneTalker.name.."Load", EVENT_ADD_ON_LOADED)

	StoneTalker.savedVars = ZO_SavedVars:NewAccountWide(StoneTalker.name.."SavedVars", StoneTalker.varVersion, nil, StoneTalker.defaults, nil, "$InstallationWide")
	local sv = StoneTalker.savedVars
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
	
	StoneTalker.setFontSize(StoneTalker.savedVars.timerSize)
	StoneTalker.setPos()
	StoneTalkerFrame:SetHidden(IsReticleHidden())
	StoneTalkerFrameTime:SetColor(unpack(StoneTalker.savedVars.COLORS.UP))

	StoneTalker.setupMenu()
	StoneTalker.hideOutOfCombat()

	EM:RegisterForEvent(StoneTalker.name.."Hide", EVENT_RETICLE_HIDDEN_UPDATE, StoneTalker.hideFrame)
	EM:RegisterForEvent(StoneTalker.name.."PassiveHide", EVENT_PLAYER_COMBAT_STATE, StoneTalker.combatState)

	EM:RegisterForEvent(StoneTalker.name.."ECE", EVENT_COMBAT_EVENT, StoneTalker.combatEvent)
	EM:AddFilterForEvent(StoneTalker.name.."ECE", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)

	EM:RegisterForEvent(StoneTalker.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, StoneTalker.gearUpdate)
	EM:AddFilterForEvent(StoneTalker.name.."GearUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

	StoneTalker.gearUpdate()

end

EM:RegisterForEvent(StoneTalker.name.."Load", EVENT_ADD_ON_LOADED, StoneTalker.Init)
