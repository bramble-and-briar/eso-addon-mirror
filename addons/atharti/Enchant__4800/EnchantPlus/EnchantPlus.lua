local EnchantPlus = {}
local EP = EnchantPlus
EP.name = "EnchantPlus"

local LCM = LibCustomMenu

ZO_CreateStringId("SI_ENCHANTER_PLUS_OPTION", "Enchant+")

function EP.BuildGlyphEntries(bag, index)
	local entries = {}

	local itemList = PLAYER_INVENTORY:GenerateListOfVirtualStackedItems(
		INVENTORY_BACKPACK,
		function(enchantBag, enchantSlot)
			return CanItemTakeEnchantment(bag, index, enchantBag, enchantSlot)
		end
	)

	local tempEntries = {}
	for _, itemInfo in pairs(itemList) do
		local glyphBag = itemInfo.bag
		local glyphSlot = itemInfo.index

		local itemLink = GetItemLink(glyphBag, glyphSlot)
		local rawName = GetItemName(glyphBag, glyphSlot)

		table.insert(tempEntries, {
			link = itemLink,
			name = rawName,
			bag = glyphBag,
			slot = glyphSlot,
		})
	end

	table.sort(tempEntries, function(a, b)
		return a.name < b.name
	end)

	for _, entry in ipairs(tempEntries) do
		table.insert(entries, {
			label = entry.link,
			tooltip = function(control, inside)
				if inside then
					InitializeTooltip(ItemTooltip, control, ANCHOR_CURSOR, 0, 0)
					ItemTooltip:SetBagItem(entry.bag, entry.slot)
					ZO_Tooltips_SetupDynamicTooltipAnchors(ItemTooltip, control)
				else
					ClearTooltip(ItemTooltip)
				end
			end,
			callback = function()
				local function DoEnchant()
					EnchantItem(bag, index, entry.bag, entry.slot)
				end

				if IsItemPlayerLocked(bag, index) then
					ZO_Dialogs_ShowPlatformDialog(
						"CONFIRM_ENCHANT_LOCKED_ITEM",
						{ onAcceptCallback = DoEnchant },
						{ mainTextParams = { GetString(SI_PERFORM_ACTION_CONFIRMATION) } }
					)
				else
					DoEnchant()
				end
			end
		})
	end

	return entries
end

function EP.ContextMenuCallback(inventorySlot, slotActions)
	local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
	if not bag or not index then return end

	if not IsItemEnchantable(bag, index) then return end

	local entries = EP.BuildGlyphEntries(bag, index)
	if #entries == 0 then return end

	AddCustomSubMenuItem(
		GetString(SI_ENCHANTER_PLUS_OPTION),
		function()
			return entries
		end
	)
end

-- =========================
-- Default Entry Removal
-- =========================
function EP.HookRemoveDefaultEnchant()
	local function AddSlotActionHook(self, actionStringId)
		if actionStringId == SI_ITEM_ACTION_ENCHANT then
			return true
		end
	end

	ZO_PreHook(ZO_InventorySlotActions, "AddSlotAction", AddSlotActionHook)
end

-- =========================
-- Init
-- =========================
function EP.OnAddonLoaded(event, addonName)
	if addonName ~= EP.name then return end
	EVENT_MANAGER:UnregisterForEvent(EP.name, EVENT_ADD_ON_LOADED)

	LCM:RegisterContextMenu(EP.ContextMenuCallback, LCM.CATEGORY_PRIMARY)
	EP.HookRemoveDefaultEnchant()
end

EVENT_MANAGER:RegisterForEvent(EP.name, EVENT_ADD_ON_LOADED, EP.OnAddonLoaded)