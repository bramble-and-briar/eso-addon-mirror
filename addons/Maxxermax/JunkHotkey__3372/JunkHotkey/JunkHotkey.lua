--[[
-------------------------------------------------------------------------------
-- JunkHotkey, by Maxxermax, code snippets lent from Dustman https://esoui.com
-------------------------------------------------------------------------------
This software is under : CreativeCommons CC BY-NC-SA 4.0
Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

You are free to:

    Share — copy and redistribute the material in any medium or format
    Adapt — remix, transform, and build upon the material
    The licensor cannot revoke these freedoms as long as you follow the license terms.


Under the following terms:

    Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
    NonCommercial — You may not use the material for commercial purposes.
    ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from anything the license permits.


Please read full licence at : 
http://creativecommons.org
]]

-- Leaked for menu & data
JunkHotkey = {}

local ADDON_NAME = "JunkHotkey"

-- Local variables ------------------------------------------------------------
local hoveredBagId
local hoveredSlotId
local junkHotkeyJunkKeybind
local hoveredItemCanBeJunked
local isItemJunk
local descriptorName = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)

local function OnSlotMouseEnter(inventorySlot)
	
	if not inventorySlot then return end

	-- 1. Standard-Erkennung
	if inventorySlot.dataEntry and inventorySlot.dataEntry.data then
		local data = inventorySlot.dataEntry.data
		hoveredBagId = data.bagId
		hoveredSlotId = data.slotIndex

		-- ESO-Fallback für verschachtelte Daten (dataSource)
		if not hoveredBagId and data.dataSource then
			hoveredBagId = data.dataSource.bagId
			hoveredSlotId = data.dataSource.slotIndex
		end
	end

	-- 2. Fallback, falls die IDs direkt am Slot hängen
	if not hoveredBagId then
		hoveredBagId = inventorySlot.bagId
		hoveredSlotId = inventorySlot.slotIndex
	end

	-- 3. Sicherster ESO-API-Sicherheitsnetz-Fallback
	if not hoveredBagId and type(inventorySlot.GetBagAndSlot) == "function" then
		hoveredBagId, hoveredSlotId = inventorySlot:GetBagAndSlot()
	end

	-- 4. Überarbeitete Junk-Prüfung
	if hoveredBagId and hoveredSlotId and CanItemBeMarkedAsJunk(hoveredBagId, hoveredSlotId) then
		hoveredItemCanBeJunked = true
		isItemJunk = IsItemJunk(hoveredBagId, hoveredSlotId)
		
		-- FIX: Nicht mehr AddKeybind aufrufen, sondern nur das Update triggern.
		-- Das überlässt ESO die richtige, dynamische Reihenfolge in der Leiste.
		KEYBIND_STRIP:UpdateKeybindButtonGroup(junkHotkeyJunkKeybind)
	end

end

local function OnSlotMouseExit()
	
	hoveredBagId = nil
	hoveredSlotId = nil
	hoveredItemCanBeJunked = false
	isItemJunk = false
	
	KEYBIND_STRIP:UpdateKeybindButtonGroup(junkHotkeyJunkKeybind)
	
end

local function CanHoveredItemBeJunked()
	return hoveredItemCanBeJunked
end

local function JunkHoveredItem()
	if CanHoveredItemBeJunked() then
		local isCompanionItem = nil
        local actorCategory = GetItemActorCategory(hoveredBagId, hoveredSlotId)
        isCompanionItem = (actorCategory ~= nil and actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION) or false
		
		SetItemIsJunk(hoveredBagId, hoveredSlotId, not isItemJunk)
		if isCompanionItem == false then
			PlaySound(isItemJunk and SOUNDS.INVENTORY_ITEM_UNJUNKED or SOUNDS.INVENTORY_ITEM_JUNKED)
		end
		
		isItemJunk = IsItemJunk(hoveredBagId, hoveredSlotId)
		KEYBIND_STRIP:UpdateKeybindButtonGroup(junkHotkeyJunkKeybind)
	end
end

local function UpdateAndDisplayKeybind()
	
	if isItemJunk then
		descriptorName = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK)
	else
		descriptorName = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
	end
	
	return CanHoveredItemBeJunked()

end

local function InitializeInventoryKeybind()

	ZO_PreHook("ZO_InventorySlot_OnMouseEnter", OnSlotMouseEnter)
	ZO_PreHook("ZO_InventorySlot_OnMouseExit", OnSlotMouseExit)

	ZO_CreateStringId("SI_BINDING_NAME_JUNKHOTKEY_JUNK", descriptorName)
	
	junkHotkeyJunkKeybind =
	{
		-- Wieder zurück auf CENTER gestellt, damit es sich natürlich einreiht
		alignment = KEYBIND_STRIP_ALIGN_CENTER, 
		{
			name = function() return descriptorName end,
			keybind = "JUNKHOTKEY_JUNK", 
			callback = JunkHoveredItem,
			visible = UpdateAndDisplayKeybind,
		},
	}
	
	local function OnStateChanged(oldState, newState)
		if newState == SCENE_SHOWING then
			KEYBIND_STRIP:AddKeybindButtonGroup(junkHotkeyJunkKeybind)
		elseif newState == SCENE_HIDDEN then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(junkHotkeyJunkKeybind)
		end
	end
	
	INVENTORY_FRAGMENT:RegisterCallback("StateChange", OnStateChanged)
	BANK_FRAGMENT:RegisterCallback("StateChange", OnStateChanged)
	HOUSE_BANK_FRAGMENT:RegisterCallback("StateChange", OnStateChanged)

	-- Der sauberste ESO-Weg: Wir hängen uns in das Refresh-System der Item-Keybinds ein.
	-- Immer wenn das Spiel die Hotkeys für einen Slot neu aufbaut, aktualisieren wir unseren Zustand mit.
	ZO_PostHook("ZO_InventorySlot_ShowKeybinds", function(slot)
		if KEYBIND_STRIP and junkHotkeyJunkKeybind then
			KEYBIND_STRIP:UpdateKeybindButtonGroup(junkHotkeyJunkKeybind)
		end
	end)

end

function JunkHotkey_JunkHoveredItem()
	JunkHoveredItem()
end

local function OnLoad(eventCode, addonName)

	if addonName == "JunkHotkey" then
		EVENT_MANAGER:UnregisterForEvent("JunkHotkey", EVENT_ADD_ON_LOADED)
		InitializeInventoryKeybind()
	end
end

EVENT_MANAGER:RegisterForEvent("JunkHotkey", EVENT_ADD_ON_LOADED, OnLoad)