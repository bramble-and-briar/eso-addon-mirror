local VoidBash = {}
local VB = VoidBash
local EM = EVENT_MANAGER

VB.name = "VoidBash"

local ABILITY_ID = 147747
local COOLDOWN = 13000
local ICON = GetAbilityIcon(ABILITY_ID)

local SET_NORMAL = 558
local SET_PERFECT = 564
local SET_PIECES = 2

local EDGE = 2
local EDGE_INNER = 2

local AR, AG, AB, AA = 0, 1, 0, 1
local CR, CG, CB, CA = 1, 0, 0, 1
local SR, SG, SB, SA = 0, 0, 0, 0.3

local defaultSV = {
	left = 400,
	top = 400,
	size = 35,
}

local buffEndTime = 0
local cdEndTime = 0
local wornSlots = 0
local isUpdateRegistered = false

local lastDisplayedSec = -1
local currentState = nil

local function GetScaledFont(size)
	return "$(BOLD_FONT)|" .. math.floor(size * 22 / 35) .. "|thick-outline"
end

function VB.CreateUI()
	local size = VB.SV.size

	local control = WINDOW_MANAGER:CreateTopLevelWindow("VoidBashTimer")
	control:SetClampedToScreen(true)
	control:SetMouseEnabled(true)
	control:SetMovable(true)
	control:SetDimensions(size, size)
	control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, VB.SV.left, VB.SV.top)
	control:SetHidden(true)

	local edge = WINDOW_MANAGER:CreateControl("VoidBashTimerEdge", control, CT_BACKDROP)
	edge:SetAnchorFill(control)
	edge:SetEdgeColor(0, 0, 0, 1)
	edge:SetCenterColor(SR, SG, SB, SA)
	edge:SetEdgeTexture(nil, EDGE, EDGE, EDGE)

	local icon = WINDOW_MANAGER:CreateControl("VoidBashTimerIcon", control, CT_TEXTURE)
	icon:SetDimensions(size - 2 * (EDGE + EDGE_INNER), size - 2 * (EDGE + EDGE_INNER))
	icon:SetAnchor(TOPLEFT, control, TOPLEFT, EDGE + EDGE_INNER, EDGE + EDGE_INNER)
	icon:SetTexture(ICON)

	local label = WINDOW_MANAGER:CreateControl("VoidBashTimerLabel", control, CT_LABEL)
	label:SetAnchor(CENTER, control, CENTER, 0, 4)
	label:SetDimensions(size, size)
	label:SetFont(GetScaledFont(size))
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	label:SetColor(1, 1, 1, 1)
	label:SetText("")

	control:SetHandler("OnMoveStop", function()
		VB.SV.left = control:GetLeft()
		VB.SV.top = control:GetTop()
	end)

	control.edge = edge
	control.icon = icon
	control.label = label
	VB.control = control
	VB.frag = ZO_SimpleSceneFragment:New(control)
end

function VB.ApplySize(size)
	VB.SV.size = size
	local control = VB.control
	control:SetDimensions(size, size)
	control.icon:SetDimensions(size - 2 * (EDGE + EDGE_INNER), size - 2 * (EDGE + EDGE_INNER))
	control.icon:SetAnchor(TOPLEFT, control, TOPLEFT, EDGE + EDGE_INNER, EDGE + EDGE_INNER)
	control.label:SetDimensions(size, size)
	control.label:SetFont(GetScaledFont(size))
	control.label:SetAnchor(CENTER, control, CENTER, 0, 4)
end

function VB.SetStandbyVisuals()
	if currentState == "STANDBY" then return end
	currentState = "STANDBY"
	lastDisplayedSec = -1

	local control = VB.control
	control.edge:SetCenterColor(SR, SG, SB, SA)
	control.label:SetColor(1, 1, 1, 1)
	control.label:SetText("")
end

function VB.StopUpdateLoop()
	if isUpdateRegistered then
		EM:UnregisterForUpdate(VB.name .. "Update")
		isUpdateRegistered = false
	end
	VB.SetStandbyVisuals()
end

function VB.StartUpdateLoop()
	if not isUpdateRegistered then
		EM:RegisterForUpdate(VB.name .. "Update", 100, VB.OnUpdate)
		isUpdateRegistered = true
	end
end

function VB.OnUpdate()
	local now = GetGameTimeMilliseconds()
	local buffRem = buffEndTime - now
	local cdRem	  = cdEndTime - now

	if buffRem > 0 then
		if currentState ~= "ACTIVE" then
			currentState = "ACTIVE"
			VB.control.edge:SetCenterColor(AR, AG, AB, AA)
			VB.control.label:SetColor(AR, AG, AB, AA)
		end

		local sec = math.ceil(buffRem / 1000)
		if sec ~= lastDisplayedSec then
			lastDisplayedSec = sec
			VB.control.label:SetText(tostring(sec))
		end
	elseif cdRem > 0 then
		if currentState ~= "COOLDOWN" then
			currentState = "COOLDOWN"
			VB.control.edge:SetCenterColor(CR, CG, CB, CA)
			VB.control.label:SetColor(CR, CG, CB, CA)
		end

		local sec = math.ceil(cdRem / 1000)
		if sec ~= lastDisplayedSec then
			lastDisplayedSec = sec
			VB.control.label:SetText(tostring(sec))
		end
	else
		VB.StopUpdateLoop()
	end
end

function VB.OnCombatEvent(_, result, _, _, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)
	if abilityId ~= ABILITY_ID then return end
	if result ~= ACTION_RESULT_EFFECT_GAINED
		and result ~= ACTION_RESULT_EFFECT_GAINED_DURATION
		and result ~= ACTION_RESULT_DAMAGE
		and result ~= ACTION_RESULT_CRITICAL_DAMAGE then
		return
	end

	local now = GetGameTimeMilliseconds()
	buffEndTime = now + GetAbilityDuration(ABILITY_ID)
	cdEndTime	= now + COOLDOWN

	VB.StartUpdateLoop()
end

function VB.HasVoidBashEquipped()
	local count = 0
	for slot = 0, wornSlots - 1 do
		local link = GetItemLink(BAG_WORN, slot)
		if link and link ~= "" then
			local _, _, _, _, _, setId = GetItemLinkSetInfo(link)
			if setId == SET_NORMAL or setId == SET_PERFECT then
				count = count + 1
				if count >= SET_PIECES then
					return true
				end
			end
		end
	end
	return false
end

function VB.RefreshEquippedState()
	HUD_SCENE:RemoveFragment(VB.frag)
	HUD_UI_SCENE:RemoveFragment(VB.frag)

	if VB.HasVoidBashEquipped() then
		HUD_SCENE:AddFragment(VB.frag)
		HUD_UI_SCENE:AddFragment(VB.frag)
	else
		buffEndTime = 0
		cdEndTime = 0
		VB.StopUpdateLoop()
	end
end

function VB.OnPlayerActivated()
	EM:UnregisterForEvent(VB.name, EVENT_PLAYER_ACTIVATED)

	wornSlots = GetBagSize(BAG_WORN)
	VB.RefreshEquippedState()

	EM:RegisterForEvent(VB.name .. "Equip", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, VB.RefreshEquippedState)
	EM:AddFilterForEvent(VB.name .. "Equip", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

	EM:RegisterForEvent(VB.name .. "Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function(_, result)
		if result == ARMORY_BUILD_RESTORE_RESULT_SUCCESS then
			VB.RefreshEquippedState()
		end
	end)
end

SLASH_COMMANDS["/voidbash"] = function(input)
	local size = tonumber(input)
	if not size then return end
	size = zo_max(10, zo_min(200, math.floor(size)))
	VB.ApplySize(size)
end

function VB.OnAddonLoaded(_, addonName)
	if addonName ~= VB.name then return end
	EM:UnregisterForEvent(VB.name, EVENT_ADD_ON_LOADED)

	VB.SV = ZO_SavedVars:NewAccountWide("VoidBash_SV", 1, nil, defaultSV)

	VB.CreateUI()

	EM:RegisterForEvent(VB.name .. "Combat", EVENT_COMBAT_EVENT, VB.OnCombatEvent)
	EM:AddFilterForEvent(VB.name .. "Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, ABILITY_ID)
	EM:AddFilterForEvent(VB.name .. "Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

	EM:RegisterForEvent(VB.name, EVENT_PLAYER_ACTIVATED, VB.OnPlayerActivated)
end

EM:RegisterForEvent(VB.name, EVENT_ADD_ON_LOADED, VB.OnAddonLoaded)