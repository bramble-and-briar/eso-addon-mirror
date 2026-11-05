BindAll = BindAll or {}
local BA = BindAll
BA.name = "BindAll"
BA.version = "1.5"

BA.cumulativeBinding = {}

-- Some inventory bag constants are absent on the console UI build.
-- Never use a nil global as a table key during addon loading.
BA.disabledBags = {}
for _, bagName in ipairs({ "BAG_GUILDBANK", "BAG_BUYBACK", "BAG_DELETE" }) do
    local bagId = _G[bagName]
    if type(bagId) == "number" then
        BA.disabledBags[bagId] = true
    end
end

function BA.BindAllUnknown(bag)
	
	if bag == nil then
        bag = type(GetBankingBag) == "function" and GetBankingBag() or nil
    end
    if type(bag) ~= "number" then bag = BAG_BACKPACK end
	
	-- filter bags
	if BA.disabledBags[bag] ~= nil then bag = BAG_BACKPACK end
	
	-- also iterate the eso plus bank
	if bag == BAG_BANK and IsESOPlusSubscriber() == true then BA.BindAllUnknown(BAG_SUBSCRIBER_BANK) end
	
	local items = {}
	
	-- scan bag
	for slot = 0, GetBagSize(bag) - 1 do
		local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
		if IsItemLinkSetCollectionPiece(itemLink) == true and IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink)) == false then
			local itemName = GetItemLinkName(itemLink)
			if items[itemName] == nil then
				items[itemName] = {}
				items[itemName].link = itemLink
				items[itemName].slot = slot
			end
		end
	end
	
	-- bind items
	for item, info in pairs(items) do
		if BA.IsItemProtected(bag, info.slot) == false then
			BindItem(bag, info.slot)
			if BA.savedVariables and BA.savedVariables.printToChat == true then
				d("Item bound: " .. info.link)
			end
		end
	end
end

function BA.BindUnknown(bag, slot)
	if BA.IsItemProtected(bag, slot) == false then
		local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
		if IsItemLinkSetCollectionPiece(itemLink) == true and IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink)) == false then
			BindItem(bag, slot)
			if BA.savedVariables and BA.savedVariables.printToChat == true then
				d("Item bound: " .. itemLink)
			end
		end
	end
end

function BA.OnInventoryUpdate(_, bag, slot, isNew, _, updateReason, _)
	if BA.savedVariables and BA.savedVariables.autoBind == true then
        if type(bag) ~= "number" then return end
        if BA.cumulativeBinding[bag] ~= true then
			BA.cumulativeBinding[bag] = true
			zo_callLater(function()
				BA.cumulativeBinding[bag] = nil
				BA.BindAllUnknown(bag)
			end, 2000)
		end
	end
end

function BA.IsItemProtected(bagId, slotIndex)
	if FCOIS then
		if FCOIS.addonVars.gPlayerActivated then
			local marked = FCOIS.IsMarked(bagId, slotIndex, -1, nil)
			return marked
		end
	end
	return false
end

function BA.OnAddOnLoaded(_, addonName)
	if addonName ~= "MyUI" then return end
	
	BA.initMenu()
	
	ZO_CreateStringId("SI_BINDING_NAME_BINDALL", "Bind all not collected items")
	SLASH_COMMANDS["/bindall"] = function() BA.BindAllUnknown() end
	
	EVENT_MANAGER:RegisterForEvent(BA.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, BA.OnInventoryUpdate)
	EVENT_MANAGER:AddFilterForEvent(BA.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
	EVENT_MANAGER:AddFilterForEvent(BA.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
end

EVENT_MANAGER:RegisterForEvent(BA.name, EVENT_ADD_ON_LOADED, BA.OnAddOnLoaded)