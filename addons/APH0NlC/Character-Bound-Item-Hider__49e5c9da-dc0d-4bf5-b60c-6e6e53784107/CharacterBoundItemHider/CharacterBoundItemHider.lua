--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local ADDON_NAME = "CharacterBoundItemHider"

local function IsCharacterBound(bagId, slotIndex)
	if not bagId or not slotIndex then return false end
	if not IsItemBound(bagId, slotIndex) then return false end
	local link = GetItemLink(bagId, slotIndex)
	if not link or link == "" then return false end
	return GetItemLinkBindType(link) == BIND_TYPE_ON_PICKUP_BACKPACK
end

local function SlotIsCharacterBound(slot)
	if type(slot) ~= "table" then return false end
	return IsCharacterBound(slot.bagId, slot.slotIndex)
end

local function WrapLayout(fragment)
	if type(fragment) ~= "table" or type(fragment.layoutData) ~= "table" then return false end
	local layout = fragment.layoutData
	if layout[ADDON_NAME] then return true end
	local previous = layout.additionalFilter
	layout[ADDON_NAME] = true
	layout.additionalFilter = function(slot)
		if previous and not previous(slot) then return false end
		return not SlotIsCharacterBound(slot)
	end
	return true
end

local function ApplyToStorageLayouts()
	local wrapped = 0
	for _, name in ipairs({
		"BACKPACK_BANK_LAYOUT_FRAGMENT",
		"BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT",
	}) do
		if WrapLayout(_G[name]) then wrapped = wrapped + 1 end
	end
	return wrapped
end

local function WrapGamepadList(list)
	if type(list) ~= "table" or type(list.SetItemFilterFunction) ~= "function" then return false end
	if list[ADDON_NAME] then return true end
	local previous = list.itemFilterFunction
	list[ADDON_NAME] = true
	list:SetItemFilterFunction(function(slot)
		if previous and not previous(slot) then return false end
		return not SlotIsCharacterBound(slot)
	end)
	return true
end

local function ApplyToGamepadBanking()
	local banking = GAMEPAD_BANKING
	if type(banking) ~= "table" then return false end
	if not banking[ADDON_NAME] then
		banking[ADDON_NAME] = true
		ZO_PostHook(banking, "SetDepositList", function(_, list) WrapGamepadList(list) end)
	end
	if banking.depositList then WrapGamepadList(banking.depositList) end
	return true
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
	if name ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
	ApplyToStorageLayouts()
	ApplyToGamepadBanking()
end)

CharacterBoundItemHider = {
	IsCharacterBound = IsCharacterBound,
	SlotIsCharacterBound = SlotIsCharacterBound,
	ApplyToStorageLayouts = ApplyToStorageLayouts,
	ApplyToGamepadBanking = ApplyToGamepadBanking,
}
