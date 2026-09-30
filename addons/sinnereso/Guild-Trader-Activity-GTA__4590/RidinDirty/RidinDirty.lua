RidinDirty = {
	name = "RidinDirty",
	author = "@sinnereso",
	version = "2026.09.29",
	svName = "RidinDirtyVars",
	svVersion = 1,
	tradeTable = {},
}
local RD = RidinDirty
local rdLogo = "|c6666FF[RD]|r "
local hasPassenger = false
local passengerName = ""
local chatMods = false
local traderMods = false
local searchDelay = 300
local oldGuildLabel = ""
local playerSearch = nil
local houseSearch = nil
local chatStamp = nil
local goldIcon = "|t18:18:/esoui/art/currency/currency_gold.dds|t"
local apIcon = "|t18:18:/esoui/art/currency/alliancepoints.dds|t"
local telvarIcon = "|t18:18:/esoui/art/currency/currency_telvar.dds|t"
local voucherIcon = "|t18:18:/esoui/art/currency/currency_writvoucher.dds|t"
local veterancyIcon = "|t18:18:/esoui/art/notifications/notificationicon_veterancyrankrewards.dds|t"
local avpData = {
	allianceGained = 0,
	telvarDifference = 0,
	veterancyGained = 0,
	}
local avpProcessing = false
local TICK_REASON = nil
local REASON_INFO = nil
local LCK = LibCharacterKnowledge
---------------------------------------------
--------- HELPER FUNCTIONS --
---------------------------------------------
local function InAlphaList(name)
	local names = {
	"@sinnereso",
	"@MisBHaven",
	"@snipareso",
	}
	for _, userName in ipairs(names) do
		if userName == name then return true end
	end
	return false
end
--/script df(tostring(DistanceToUnit("group1")))--player--companion--reticleover--reticleovertarget--groupX--groupXcompanion--playerpetX
local function DistanceToUnit(unitID)
	local _, selfX, selfY, selfH = GetUnitWorldPosition("player")
	local _, targetX, targetY, targetH = GetUnitWorldPosition(unitID)
	local nDistance = zo_distance3D(targetX, targetY, targetH, selfX, selfY, selfH) / 100
	return nDistance
end

local function HasWritQuest()
	for quest = 1, MAX_JOURNAL_QUESTS do
		if GetJournalQuestType(quest) == QUEST_TYPE_CRAFTING then return true end
	end
	return false
end
--IsCollectibleUnlocked(GetCollectibleIdFromLink(itemLink))--if itemType == ITEMTYPE_COLLECTIBLE
local function IsKnowledgeUnknown(itemId, itemLink, itemType, specialType)
	if IsItemLinkSetCollectionPiece(itemLink) and not IsItemSetCollectionPieceUnlocked(itemId) then return "|cFB2C36(+)|r" end
	if LibCharacterKnowledge then
		if specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE and CanItemLinkBeUsedToLearn(itemLink) then return "|cFB2C36(+)|r" end
		if LCK.GetItemKnowledgeForCharacter(itemId, nil, GetCurrentCharacterId()) == LCK.KNOWLEDGE_UNKNOWN then return "|cFB2C36(+)|r" end
		local characters = LCK.GetItemKnowledgeList(itemLink)
		for i = 1, GetNumCharacters() do
			local charName, charGender, charLevel, charClassID, charRaceID, charAlliance, charID, charLocatonID = GetCharacterInfo(i)
			for c, character in ipairs(characters) do
				if (character.id == charID) then
					if LCK.GetItemKnowledgeForCharacter(itemId, nil, charID) == LCK.KNOWLEDGE_UNKNOWN then return "|cff8000(+)|r" end--C99912
				end
			end
		end
	else
		if CanItemLinkBeUsedToLearn(itemLink) then return "|cFB2C36(+)|r" end
		if itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT then
			local isItemUseTypeCraftedAbilityScript = GetItemLinkItemUseType(itemLink) == ITEM_USE_TYPE_CRAFTED_ABILITY_SCRIPT
			local craftedAbilityScriptId = isItemUseTypeCraftedAbilityScript and GetItemLinkItemUseReferenceId(itemLink) or 0
			if not IsCraftedAbilityScriptUnlocked(craftedAbilityScriptId) then return "|cFB2C36(+)|r" end
		end
	end
	return false
end

local function GetLastDailyReset()
	local utcReset = {["NA Megaserver"] = 10, ["EU Megaserver"] = 3, ["PTS"] = 10,}
	local time = os.time()
	local local_table = os.date("*t", time)
	local_table.isdst = false
	local utc_table = os.date("!*t", time)
	local local_sec = os.time(local_table)
	local utc_sec = os.time(utc_table)
	local offset = os.difftime(local_sec, utc_sec) / 3600
	local t = os.date("!*t", time)
	t.hour = (utcReset[GetWorldName()] + offset)
	local lastReset = os.time({year = t.year, month = t.month, day = t.day, hour = t.hour, min = 0, sec = 0})
	if lastReset > time then lastReset = lastReset - 86400 end
	--df("Last Reset: " .. tostring(os.date("%Y-%m-%d %H:%M:%S", lastReset)) .. ", Stamp: " .. tostring(lastReset) .. ", Timezone: (" .. tostring(offset) .. ")")
	return lastReset
end

local function SettingsPanelCharacterList()
	local charList = {}
	local disabled = "|ccc0000*DISABLED*|r"
	local count = 1
	for i = 1, GetNumCharacters() do
		local charName = GetCharacterInfo(i)
		charName = charName:sub(1, charName:find("%^") - 1)
		if count == 1 then table.insert(charList, disabled) end
		if (nil == charList[charName]) then
			table.insert(charList, charName)
		end
		count = (count + 1)
	end
	return charList
end

local function GetHomeCampLeadScore()
	for index = 1, GetNumCampaignAllianceLeaderboardEntries(GetAssignedCampaignId(), GetUnitAlliance("player")) do
		local isPlayer, rank, name, points, class, displayName = GetCampaignAllianceLeaderboardEntryInfo(GetAssignedCampaignId(), GetUnitAlliance("player"), index)
		if isPlayer then
			return rank, ZO_LocalizeDecimalNumber(points)
		end
	end
	return false
end
--/script SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState) d(scene:GetName() .. " " .. newState) end)
local function GetLowPopCyroCampaignId()
	QueryCampaignSelectionData()
	for index = 1, GetNumSelectionCampaigns() do
		local campaignId = GetSelectionCampaignId(index)
		local campaignPopEstimate = GetSelectionCampaignPopulationData(index, GetUnitAlliance("player"))
		if not IsImperialCityCampaign(campaignId) and not CanCampaignBeAllianceLocked(campaignId) and campaignPopEstimate <= 2 then return campaignId end
	end
	return false
end

local function GetLastBGModeItem(modeName)
    for i, item in ipairs(BATTLEGROUND_FINDER_KEYBOARD.filterComboBox.m_sortedItems) do
        if item.name == modeName then return item end
    end
end

local function GetVeterancyTier()
	local trackType = REWARD_TRACK_TYPE_AVA_VETERANCY
	local _, currTierIndex, currProgress = GetInfoForRewardTrack(trackType, GetActiveReferenceTrackIdsForRewardTrackType(trackType))
	CURRENT_TIER_INDEX = currTierIndex
end

local function GetUnlockedAssistant()
	for index = 1, GetTotalCollectiblesByCategoryType(8) do
		local collectibleID = GetCollectibleIdFromType(8, index)
		if IsCollectibleUnlocked(collectibleID) then
			return collectibleID
		end
	end
	return false
end

local function GetPassengerName()
	local displayNamePref = nil
	for iD = 1, GetGroupSize() do
		local playerID = GetGroupUnitTagByIndex(iD)
		local charName = GetUnitName(playerID)
		local displayName = GetUnitDisplayName(playerID)
		local mountedState, hasEnabledGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(displayName)
		if mountedState == MOUNTED_STATE_MOUNT_PASSENGER and DistanceToUnit(playerID) < 0.1 then
			if not ZO_ShouldPreferUserId() then displayNamePref = charName else displayNamePref = displayName end
			displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
			passengerName = displayNamePref
			return displayNamePref
		end
	end
	return "UNKNOWN"
end

local function PassengerStateChange(eventCode, isMounted)
	local mountedState, hasEnabledGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(GetUnitDisplayName("player"))
	if mountedState ~= MOUNTED_STATE_MOUNT_RIDER or not hasEnabledGroupMount then
		hasPassenger = false
		return
	elseif mountedState == MOUNTED_STATE_MOUNT_RIDER and hasEnabledGroupMount and hasFreePassengerSlot and hasPassenger then
		hasPassenger = false CENTER_SCREEN_ANNOUNCE:AddMessage( 0, CSA_CATEGORY_SMALL_TEXT, "New_Mail", ("|cC99912" .. tostring(passengerName) .. " has dismounted|r"), nil, nil, nil, nil, nil, 5000, nil)
	elseif mountedState == MOUNTED_STATE_MOUNT_RIDER and hasEnabledGroupMount and not hasFreePassengerSlot and not hasPassenger then
		hasPassenger = true CENTER_SCREEN_ANNOUNCE:AddMessage( 0, CSA_CATEGORY_SMALL_TEXT, "New_Mail", ("|cC99912" .. tostring(GetPassengerName()) .. " is RidinDirty|r"), nil, nil, nil, nil, nil, 5000, nil)
	end
	if mountedState == MOUNTED_STATE_MOUNT_RIDER and hasEnabledGroupMount then zo_callLater(function() PassengerStateChange() end, 1000) end
end

local function CheckBankMemory()
	local displayMessage = true
	local itemFound = false
	for i, v in pairs(RidinDirty.savedVariables["Banked Memory"]) do
		if i ~= nil and i ~= "version" and i ~= "default" then
			for slotIndex = 0, GetBagSize(BAG_BANK) - 1 do
				if i == GetItemId(BAG_BANK, slotIndex) then itemFound = true break end
			end
			if IsESOPlusSubscriber() then
				for slotIndex = 0, GetBagSize(BAG_SUBSCRIBER_BANK) - 1 do
					if i == GetItemId(BAG_SUBSCRIBER_BANK, slotIndex) then itemFound = true break end
				end
			end
			if not itemFound then
				if displayMessage then displayMessage = false df("--- Missing From Bank ---") end
				df(rdLogo .. tostring(v))
			end
		end
		itemFound = false
	end
end

local function SaveBankMemory()
	ZO_ClearTable(RidinDirty.savedVariables["Banked Memory"])
	RidinDirty.bankedMemory["version"] = 1
	for slotIndex = 0, GetBagSize(BAG_BANK) - 1 do
		itemId = GetItemId(BAG_BANK, slotIndex)
		itemLink = GetItemLink(BAG_BANK, slotIndex, LINK_STYLE_BRACKETS)
		if itemId ~= nil and itemId ~= 0 then RidinDirty.bankedMemory[itemId] = itemLink end
	end
	if IsESOPlusSubscriber() then
		for slotIndex = 0, GetBagSize(BAG_SUBSCRIBER_BANK) - 1 do
			itemId = GetItemId(BAG_SUBSCRIBER_BANK, slotIndex)
			itemLink = GetItemLink(BAG_SUBSCRIBER_BANK, slotIndex, LINK_STYLE_BRACKETS)
			if itemId ~= nil and itemId ~= 0 then RidinDirty.bankedMemory[itemId] = itemLink end
		end
	end
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "Bank memory saved.")
end

local function PvPAddonSave()
	local addOnManager = GetAddOnManager()
	local numAddOns = addOnManager:GetNumAddOns()
	ZO_ClearTable(RidinDirty.savedVariables["Addon Memory"])
	RidinDirty.addonMemory["version"] = 1
	for addonIndex = 1, numAddOns do
		local addonName, addonTitle, addonAuthor, addonDescription, isEnabled, addonState, isOutOfDate, isLibrary = addOnManager:GetAddOnInfo(addonIndex)
		if (isEnabled and addonState == 2) or (addonName == "RidinDirty") then RidinDirty.addonMemory[addonIndex] = addonName end
	end
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("Performance mode addons saved."))
end	
--local statusControl = control:GetNamedChild("StatusTexture")--("StatusIcon")--("Status")
--if not statusControl then return end
--df(nameText .. " - " .. tostring(statusControl:IsHidden()))--statusControl:SetHidden(true)
--local RDPrice = ((ttcPriceData.Avg + (ttcPriceData.SaleAvg or ttcPriceData.Avg)) / 2)--<< UNUSED
local function NeedsAndPrice(control, slot)
	local itemData = control.dataEntry and control.dataEntry.data
	local bagId = itemData.bagId
	local slotIndex = itemData.slotIndex
	local itemLink = GetItemLink(bagId, slotIndex)
	if not bagId then itemLink = itemData.itemLink or GetStoreItemLink(slot.slotIndex) end
	if slot.lootId then
		local lootID = slot.lootId
		itemLink = GetLootItemLink(lootID)
	end
	if not itemLink then return end
	local itemId = GetItemLinkItemId(itemLink)
	local itemType, specialType = GetItemLinkItemType(itemLink)
	local nameControl = control:GetNamedChild("Name")
	if not nameControl then return end
	--local nameText = nameControl:GetText()
	local nameText = string.gsub(nameControl:GetText(), "%(%+%)", "")
	if RidinDirty.savedVariables.lootManager then
		if IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) then
			nameControl:SetText(IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) .. nameText)
		end
	end
	if slot.lootId or STORE_FRAGMENT:IsShowing() then return end
	if bagId and (IsItemBound(bagId, slotIndex) or IsItemBoPAndTradeable(bagId, slotIndex)) then return end
	if not TamrielTradeCentre or not (RidinDirty.savedVariables.lootManager and RidinDirty.savedVariables.ttcPricing) then return end
	local SellPriceControl = control:GetNamedChild("SellPriceText") or control:GetNamedChild("SellPrice")
	if not SellPriceControl then return end
	--local originalPrice = SellPriceControl:GetText()--purchasePrice
	local ttcPriceData = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
	if not ttcPriceData then return end
	local TTCPrice = ttcPriceData[RidinDirty.savedVariables.ttcPricing] or ttcPriceData.Avg
	local TTCStackPrice = (TTCPrice * itemData.stackCount)
	if itemData.purchasePrice and RidinDirty.savedVariables.traderEnhance then
		if itemData.stackCount > 1 and TRADING_HOUSE:GetCurrentMode() == ZO_TRADING_HOUSE_MODE_LISTINGS then
			if itemData.purchasePrice > (TTCStackPrice * 1.2) then
				SellPriceControl:SetText("|cFFA2A2" .. ZO_LocalizeDecimalNumber(itemData.purchasePrice) .. " |t18:18:/esoui/art/currency/currency_gold.dds|t|r\n@ " .. ZO_LocalizeDecimalNumber(zo_roundToNearest((tonumber(itemData.purchasePrice) / tonumber(itemData.stackCount)), 1)))
			else
				SellPriceControl:SetText(ZO_LocalizeDecimalNumber(itemData.purchasePrice) .. " |t18:18:/esoui/art/currency/currency_gold.dds|t\n@ " .. ZO_LocalizeDecimalNumber(zo_roundToNearest((tonumber(itemData.purchasePrice) / tonumber(itemData.stackCount)), 1)))
			end
		elseif itemData.purchasePrice > (TTCStackPrice * 1.2) then
			SellPriceControl:SetText("|cFFA2A2" .. ZO_LocalizeDecimalNumber(itemData.purchasePrice) .. " |t18:18:/esoui/art/currency/currency_gold.dds|t|r")
		elseif itemData.purchasePrice < (TTCStackPrice * 0.95) and TRADING_HOUSE:GetCurrentMode() ~= ZO_TRADING_HOUSE_MODE_LISTINGS then
			SellPriceControl:SetText("|c7BF1A8" .. ZO_LocalizeDecimalNumber(itemData.purchasePrice) .. " |t18:18:/esoui/art/currency/currency_gold.dds|t|r")
		end
	elseif TRADING_HOUSE:GetCurrentMode() ~= ZO_TRADING_HOUSE_MODE_BROWSE and TRADING_HOUSE:GetCurrentMode() ~= ZO_TRADING_HOUSE_MODE_LISTINGS then
		if itemData.stackCount > 1 then
			SellPriceControl:SetText("|cC99912" .. tostring(ZO_LocalizeDecimalNumber(zo_roundToNearest(TTCStackPrice, 1))) .. " |t18:18:/esoui/art/currency/currency_gold.dds|t\n@ " .. tostring(ZO_LocalizeDecimalNumber(zo_roundToNearest(TTCPrice, 1))))
		else
			SellPriceControl:SetText("|cC99912" .. tostring(ZO_LocalizeDecimalNumber(zo_roundToNearest(TTCStackPrice, 1))) .. " |t18:18:/esoui/art/currency/currency_gold.dds|t" .. "|r")
		end
	end
end
--local zone = GetAntiquityZoneId(antiquityId)
local function TooltipLeadInfo(control, slot)
	local lootId = GetLootItemInfo(slot)--slot.lootId?
	local antiquityId = GetStoreEntryAntiquityId(slot)
	if lootId ~= 0 then
		antiquityId = GetLootAntiquityLeadId(lootId)
	end
	if not antiquityId or antiquityId == 0 then return end
	local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()
	local numAcquired, numEntries = GetNumAntiquityLoreEntriesAcquired(antiquityId), GetNumAntiquityLoreEntries(antiquityId)
	if numAcquired > 0 or DoesAntiquityHaveLead(antiquityId) then
		control:AddLine("")
		ZO_Tooltip_AddDivider(control)
		control:AddLine(("Collected: " .. tostring(numAcquired) .. " / " .. tostring(numEntries)), "ZoFontWinH4", r, g, b)
	else
		control:AddLine("")
		control:AddLine("|c00FF00Use to add to your codex library.|r")
		ZO_Tooltip_AddDivider(control)
		control:AddLine(("Collected: " .. tostring(numAcquired) .. " / " .. tostring(numEntries)), "ZoFontWinH4", r, g, b)
	end
end
--STORE_WINDOW:RefreshCurrency()
--STORE_WINDOW:GetStoreItems()
--STORE_WINDOW:UpdateList()
--STORE_WINDOW:InitializeStore()
--zo_callLater(function() ZO_ScrollList_Commit(STORE_WINDOW.list) end, 500)
local function RefreshStore()
	if not STORE_FRAGMENT:IsHidden() then
		ZO_ScrollList_Commit(STORE_WINDOW.list)
		return
	end
end

local function GetSoulGemSlot()
	for slotId = 0, GetBagSize(BAG_BACKPACK) do
		if IsItemSoulGem(SOUL_GEM_TYPE_FILLED, BAG_BACKPACK, slotId) then
			return slotId
		end
	end
end
--IsItemNonCrownRepairKit(BAG_BACKPACK, slotId)
local function GetRepairKitSlot()
	for slotId = 0, GetBagSize(BAG_BACKPACK) do
		if IsItemRepairKit(BAG_BACKPACK, slotId) and IsItemNonGroupRepairKit(BAG_BACKPACK, slotId) then
			return slotId
		end
	end
end

--if IsItemChargeable(BAG_WORN, slotIndex) or DoesItemHaveDurability(BAG_WORN, slotIndex) then df(tostring(GetItemName(BAG_WORN, slotIndex))) end
local function AutoRepCharge(_, bagId, slotIndex, _, _, updateReason)
	if updateReason == INVENTORY_UPDATE_REASON_ITEM_CHARGE then
		local minCharge = 50--500 max
		local charge, maxCharge = GetChargeInfoForItem(bagId, slotIndex)
		if IsItemChargeable(bagId, slotIndex) and charge <= minCharge and not IsUnitDeadOrReincarnating("player") then
			local gemSlot = GetSoulGemSlot()
			if gemSlot ~= nil then
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "InventoryItem_ApplyCharge", (GetItemName(bagId, slotIndex) .. " recharged."))
				ChargeItemWithSoulGem(bagId, slotIndex, BAG_BACKPACK, gemSlot)
			else
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("No soul gems to recharge " .. GetItemName(bagId, slotIndex) .. "."))
			end
		end
	elseif updateReason == INVENTORY_UPDATE_REASON_DURABILITY_CHANGE then
		local minDura = 10--100 max
		if DoesItemHaveDurability(bagId, slotIndex) and GetItemCondition(bagId, slotIndex) <= minDura and not IsUnitDeadOrReincarnating("player") then
			local kitSlot = GetRepairKitSlot()
			if kitSlot ~= nil then
				PlaySound("InventoryItem_ApplyCharge")
				RepairItemWithRepairKit(bagId, slotIndex, BAG_BACKPACK, kitSlot)
			else
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("No repair kits to repair " .. GetItemName(bagId, slotIndex) .. "."))
			end
		end
	end
end
--if RidinDirty.savedVariables.autoRecharge then zo_callLater(function() BrokenGearCheck() end, 2000) end--<< RUN AUTO RECHARGE IF ENABLED
local function BrokenGearCheck()
	local equipment = {
		EQUIP_SLOT_MAIN_HAND,
		EQUIP_SLOT_OFF_HAND,
		EQUIP_SLOT_BACKUP_MAIN,
		EQUIP_SLOT_BACKUP_OFF,
		EQUIP_SLOT_CHEST,
		EQUIP_SLOT_LEGS,
		EQUIP_SLOT_HEAD,
		EQUIP_SLOT_SHOULDERS,
		EQUIP_SLOT_FEET,
		EQUIP_SLOT_HAND,
		EQUIP_SLOT_WAIST,
	}
	for _, slotIndex in ipairs(equipment) do
		local charge, maxCharge = GetChargeInfoForItem(BAG_WORN, slotIndex)
		if IsItemChargeable(BAG_WORN, slotIndex) and charge == 0 and not IsUnitDeadOrReincarnating("player") then
			local gemSlot = GetSoulGemSlot()
			if gemSlot ~= nil then
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "InventoryItem_ApplyCharge", (GetItemName(BAG_WORN, slotIndex) .. " recharged."))
				ChargeItemWithSoulGem(BAG_WORN, slotIndex, BAG_BACKPACK, gemSlot)
				zo_callLater(function() BrokenGearCheck() end, 2000)
				return
			else
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("No soul gems to recharge " .. GetItemName(BAG_WORN, slotIndex) .. "."))
				break
			end
		elseif DoesItemHaveDurability(BAG_WORN, slotIndex) and GetItemCondition(BAG_WORN, slotIndex) == 0 and not IsUnitDeadOrReincarnating("player") then
			local kitSlot = GetRepairKitSlot()
			if kitSlot ~= nil then
				PlaySound("InventoryItem_ApplyCharge")
				RepairItemWithRepairKit(BAG_WORN, slotIndex, BAG_BACKPACK, kitSlot)
				zo_callLater(function() BrokenGearCheck() end, 2000)
				return
			else
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("No repair kits to repair " .. GetItemName(BAG_WORN, slotIndex) .. "."))
				break
			end
		end
	end
end
--StackBag(BAG_BACKPACK)
-- /script df(tostring(GetPlayerActiveZoneName()))
local function InZoneWhitelist(value)
	local zones = {
	"Alik'r Desert",
	"Apocrypha",
	"Artaeum",
	"Auridon",
	"Bal Foyen",
	"Bangkorai",
	"Betnikh",
	"Blackreach: Arkthzand Cavern",
	"Blackreach: Greymoor Caverns",
	"Blackwood",
	"Bleakrock Isle",
	"Clockwork City",
	"Coldharbour",
	"Craglorn",
	"Deshaan",
	"Eastmarch",
	"Fargrave",
	"Galen",
	"Glenumbra",
	"Gold Coast",
	"Grahtwood",
	"Greenshade",
	"Hew's Bane",
	"High Isle",
	"Khenarthi's Roost",
	"Malabal Tor",
	"Murkmire",
	"Night Market",
	"Northern Elsweyr",
	"Reaper's March",
	"Rivenspire",
	"Shadowfen",
	"Southern Elsweyr",
	"Solstice",
	"Stirk",
	"Stonefalls",
	"Stormhaven",
	"Stros M'Kai",
	"Summerset",
	"Telvanni Peninsula",
	"The Brass Fortress",
	"The Deadlands",
	"The Reach",
	"The Rift",
	"The Scholarium",
	"The Shambles",
	"Tideholm",
	"Vvardenfell",
	"Western Skyrim",
	"West Weald",
	"Wrothgar",
	}
	for _, zoneName in ipairs(zones) do
		if zoneName == value then return true end
	end
	return false
end
--<< /script df(tostring(GetCurrentZoneHouseId()))-- /script df("HouseName --> " .. GetHousingLink(106, RidinDirty.author))
local function GetHouseID(value)
	local playerHouses = {
	["Mara's Kiss Public House"] = 1,
	["The Rosy Lion"] = 2,
	["The Ebony Flask Inn Room"] = 3,
	["Barbed Hook Private Room"] = 4,
	["Sisters of the Sands Apartment"] = 5,
	["Flaming Nix Deluxe Garret"] = 6,
	["Black Vine Villa"] = 7,
	["Cliffshade"] = 8,
	["Mathiisen Manor"] = 9,
	["Humblemud"] = 10,
	["The Ample Domicile"] = 11,
	["Stay-Moist Mansion"] = 12,
	["Snugpod"] = 13,
	["Bouldertree Refuge"] = 14,
	["The Gorinir Estate"] = 15,
	["Captain Margaux's Place"] = 16,
	["Ravenhurst"] = 17,
	["Gardner House"] = 18,
	["Kragenhome"] = 19,
	["Velothi Reverie"] = 20,
	["Quondam Indorilia"] = 21,
	["Moonmirth House"] = 22,
	["Sleek Creek House"] = 23,
	["Dawnshadow"] = 24,
	["Cyrodilic Jungle House"] = 25,
	["Domus Phrasticus"] = 26,
	["Strident Springs Demesne"] = 27,
	["Autumn's-Gate"] = 28,
	["Grymharth's Woe"] = 29,
	["Old Mistveil Manor"] = 30,
	["Hammerdeath Bungalow"] = 31,
	["Mournoth Keep"] = 32,
	["Forsaken Stronghold"] = 33,
	["Twin Arches"] = 34,
	["House of the Silent Magnifico"] = 35,
	["Hunding's Palatial Hall"] = 36,
	["Serenity Falls Estate"] = 37,
	["Daggerfall Overlook"] = 38,
	["Ebonheart Chateau"] = 39,
	["Grand Topal Hideaway"] = 40,
	["Earthtear Cavern"] = 41,
	["Saint Delyn Penthouse"] = 42,
	["Amaya Lake Lodge"] = 43,
	["Ald Velothi Harbor House"] = 44,
	["Tel Galen"] = 45,
	["Linchal Grand Manor"] = 46,
	["Coldharbour Surreal Estate"] = 47,
	["Hakkvild's High Hall"] = 48,
	["Exorcised Coven Cottage"] = 49,
	["Pariah's Pinnacle"] = 54,
	["The Orbservatory Prior"] = 55,
	["The Erstwhile Sanctuary"] = 56,
	["Princely Dawnlight Palace"] = 57,
	["Golden Gryphon Garret"] = 58,
	["Alinor Crest Townhouse"] = 59,
	["Colossal Aldmeri Grotto"] = 60,
	["Hunter's Glade"] = 61,
	["Grand Psijic Villa"] = 62,
	["Enchanted Snow Globe Home"] = 63,
	["Lakemire Xanmeer Manor"] = 64,
	["Frostvault Chasm"] = 65,
	["Elinhir Private Arena"] = 66,
	["Sugar Bowl Suite"] = 68,
	["Jode's Embrace"] = 69,
	["Hall of the Lunar Champion"] = 70,
	["Moon-Sugar Meadow"] = 71,
	["Wraithhome"] = 72,
	["Lucky Cat Landing"] = 73,
	["Potentate's Retreat"] = 74,
	["Forgemaster Falls"] = 75,
	["Thieves' Oasis"] = 76,
	["Snowmelt Suite"] = 77,
	["Proudspire Manor"] = 78,
	["Bastion Sanguinaris"] = 79,
	["Stillwaters Retreat"] = 80,
	["Antiquarian's Alpine Gallery"] = 81,
	["Shalidor's Shrouded Realm"] = 82,
	["Stone Eagle Aerie"] = 83,
	["Kushalit Sanctuary"] = 85,
	["Varlaisvea Ayleid Ruins"] = 86,
	["Pilgrim's Rest"] = 87,
	["Water's Edge"] = 88,
	["Pantherfang Chapel"] = 89,
	["Doomchar Plateau"] = 90,
	["Sweetwater Cascades"] = 91,
	["Ossa Accentium"] = 92,
	["Agony's Ascent"] = 93,
	["Seaveil Spire"] = 94,
	["Ancient Anchor Berth"] = 95,
	["Highhallow Hold"] = 96,
	["Fogbreak Lighthouse"] = 98,
	["Fair Winds"] = 99,
	["Journey's End Lodgings"] = 100,
	["Emissary's Enclave"] = 101,
	["Shadow Queen's Labyrinth"] = 102,
	["Sword-Singer's Redoubt"] = 103,
	["Kelesan'ruhn"] = 104,
	["Gladesong Arboretum"] = 105,
	["Tower of Unutterable Truths"] = 106,
	["Willowpond Haven"] = 107,
	["Zhan Khaj Crest"] = 108,
	["Rosewine Retreat"] = 109,
	["Merryvine Estate"] = 110,
	["Seabloom Villa"] = 111,
	["Haven of the Five Companions"] = 112,
	["Kthendral Deep Mines"] = 113,
	["Grand Gallery of Tamriel"] = 114,
	["Shattered Mirror Isle"] = 115,
	["Castle Skingrad"] = 116,
	["Bismuth Steam Baths"] = 117,
	["Sleepy Sloth"] = 118,
	["Theater of the Ancestors"] = 119,
	["Hiddenspring Cottage"] = 120,
	["Wildgrown Chapel of Julianos"] = 121,
	["Cradle of the Worm Colossus"] = 122,
	["Druidspring Conservatory"] = 123,
	["Night's Den"] = 124,
	["Buccaneer Bay"] = 125,
	["Rogue's Refuge"] = 128,
	["Dancing Waters Wellspring"] = 129,
	["Star-Gazer's Vigil"] = 130,
	}
	for houseName, houseId in pairs(playerHouses) do
		if string.find(string.lower(houseName), string.lower(value), 1, true) ~= nil then return houseId end
	end
	return nil
end
--|H1:item:190013:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h
local function InLootWhitelist(value)
	local items = {
	114895,--heartwood
	114892,--mundane rune
	114894,--decorative wax
	139411,--aurbic amber
	139409,--dawn prism
	139412,--gilding wax
	139414,--slaughterstone
	56862,--fortified nirncrux
	56863,--potent nirncrux
	68342,--hakeijo
	166045,--indeko
	204881,--luminous ink
	178470,--Hidden Treasure Bag
	197790,--Research Portfolio
	188144,--Fallen Knight's Pack
	187747,--Hidden Wallet
	135005,--Prisoner's Ragged Style Box
	78003,--Large Laundered Shipment
	79677,--Assassin's Potion Kit
	126012,--Waterlogged Strong Box
	197853,--Abyss-Drenched Folio Volume
	217654,--Algae-Laden Sunport Pack
	}
	local greened = {
	187909,--Tribute Roister Purse
	134583,--Trans Geode 1
	171531,--Trans Geode 3
	134622,--Uncracked Trans Geode 1-3
	114889,--regulas
	114890,--bast
	114891,--clean pelt
	114893,--alchemical resin
	135161,--ochre
	}
	if RidinDirty.savedVariables.lootQuality == ITEM_DISPLAY_QUALITY_MAGIC then
		for _, itemId in ipairs(greened) do
			if itemId == value then return true end
		end
		for _, itemId in ipairs(items) do
			if itemId == value then return true end
		end
	else
		for _, itemId in ipairs(items) do
			if itemId == value then return true end
		end
	end
	return false
end
---------------------------------------------
------ SETTINGS PANEL --
---------------------------------------------
local function RDInitializeControls()
	local panelName = "RidinDirtySettingsPanel"
	local panelData = {
		type = "panel",
		name = "RidinDirty",
		displayName = "|c6666FFRIDINDIRTY|r",
		author = RidinDirty.author,
		version = RidinDirty.version,
		feedback = "https://www.esoui.com/downloads/info3560-RidinDirty.html#comments",
		registerForRefresh = true,
	}
	local optionsData = {
    {
		type = "header",
		name = "|c999900TRAVEL SETTINGS|r",
		width = "full",
    },
    {
		type = "description",
		text = ("Saved Player: " .. RidinDirty.savedVariables.savedPlayer),
		reference = "RIDINDIRTY_SETTINGS_SAVEDPLAYER_TEXT",
		width = "half",
	},
	{
		type = "checkbox",
		name = "/tp home (outside = on, inside = off)",
		getFunc = function() return RidinDirty.savedVariables.travelOutside end,
		setFunc = function(value) RidinDirty.savedVariables.travelOutside = (value) end,
		width = "half",
	},
	{
		type = "submenu",
		name = "|c999900STORAGE MANAGER|r",
		controls = {
			{
				type = "checkbox",
				name = "Custom Withdrawls",
				tooltip = "Adds popup withdraw 1 and withdraw (custom amount) from all storages if stack size permits",
				getFunc = function() return RidinDirty.savedVariables.withdrawOne end,
				setFunc = function(value) RidinDirty.WithdrawOneToggle(value) end,
				width = "half",
			},
			{
				type = "slider",
				name = "Custom Withdraw Amount",
				tooltip = "Amount for custom withdraw option from all storages if stack size permits",
				min = 5,
				max = 50,
				step = 5,
				getFunc = function() return RidinDirty.savedVariables.withdrawAmount end,
				setFunc = function(value) RidinDirty.savedVariables.withdrawAmount = (value) end,
				disabled = function() return not RidinDirty.savedVariables.withdrawOne end,
				width = "half",
			},
			{
				type = "checkbox",
				name = "Bank Manager",
				tooltip = "Fills select existing stacks in bank. Does not stack foods, drinks, potions, poisons, soul gems or tools",
				getFunc = function() return RidinDirty.savedVariables.bankManager end,
				setFunc = function(value) RidinDirty.savedVariables.bankManager = (value) end,
				warning = "Temporarily disables while crafting writ active",
			},
			{
				type = "checkbox",
				name = "Bank ALL",
				tooltip = "Fills ALL existing stacks in bank",
				getFunc = function() return RidinDirty.savedVariables.bankALL end,
				setFunc = function(value) RidinDirty.savedVariables.bankALL = (value) end,
				disabled = function() return not RidinDirty.savedVariables.bankManager end,
			},
			{
				type = "checkbox",
				name = "Storage Manager",
				tooltip = "Fills select existing stacks in house storages. Does not stack foods, drinks, potions, poisons, soul gems or tools",
				getFunc = function() return RidinDirty.savedVariables.storageManager end,
				setFunc = function(value) RidinDirty.savedVariables.storageManager = (value) end,
				warning = "Temporarily disables while crafting writ active",
			},
			{
				type = "checkbox",
				name = "Store ALL",
				tooltip = "Fills ALL existing stacks in house storages",
				getFunc = function() return RidinDirty.savedVariables.storageAll end,
				setFunc = function(value) RidinDirty.savedVariables.storageAll = (value) end,
				disabled = function() return not RidinDirty.savedVariables.storageManager end,
			},
			{
				type = "checkbox",
				name = "Check Bank Memory",
				tooltip = "Automatically compares the current bank inventory to the saved bank memory when opening the bank. Currently ONLY works for the bank",
				getFunc = function() return RidinDirty.savedVariables.checkBankMemory end,
				setFunc = function(value) RidinDirty.savedVariables.checkBankMemory = (value) end,
				warning = "Requires Bank Manager. Temporarily disables while crafting writ active",
				disabled = function() return not RidinDirty.savedVariables.bankManager end,
			},
			{
				type = "button",
				name = "SAVE BANK MEMORY",
				tooltip = "Saves current bank inventory to memory for comparison when opening the bank",
				func = function() SaveBankMemory() end,
				disabled = function() return not RidinDirty.savedVariables.bankManager end,
				isDangerous = true,
			},
			{
				type = "header",
				name = "|c999900CURRENCY SETTINGS|r",
				width = "full",
			},
			{
				type = "checkbox",
				name = "Gold Deposit",
				tooltip = "Auto deposits or withdraws gold above or below GOLD RESERVE to or from bank",
				getFunc = function() return RidinDirty.savedVariables.goldDeposit end,
				setFunc = function(value) RidinDirty.savedVariables.goldDeposit = (value) end,
				warning = "Temporarily disables while crafting writ active",
			},
			{
				type = "dropdown",
				name = "Gold Reserve",
				tooltip = "Maximum gold to reserve on each character",
				choices = {"|t18:18:/esoui/art/currency/currency_gold.dds|t" .. "0", "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. "10,000", "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. "50,000", "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. "100,000", "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. "500,000", "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. "1,000,000", "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. "10,000,000"},
				choicesValues = {0, 10000, 50000, 100000, 500000, 1000000, 10000000},
				getFunc = function() return RidinDirty.savedVariables.goldReserve end,
				setFunc = function(var) RidinDirty.savedVariables.goldReserve = (var) end,
				disabled = function() return not RidinDirty.savedVariables.goldDeposit end,
			},
			{
				type = "dropdown",
				name = "Gold Hoarder",
				tooltip = "Character that does not auto deposit gold per account",
				choices = SettingsPanelCharacterList(),
				getFunc = function() return RidinDirty.savedVariables.noDeposit end,
				setFunc = function(var) RidinDirty.savedVariables.noDeposit = (var) end,
				disabled = function() return not RidinDirty.savedVariables.goldDeposit end,
			},
			{
				type = "checkbox",
				name = "(AP) Deposit",
				tooltip = "Auto deposits ALL alliance points into bank",
				getFunc = function() return RidinDirty.savedVariables.apDeposit end,
				setFunc = function(value) RidinDirty.savedVariables.apDeposit = (value) end,
				warning = "Temporarily disables while crafting writ active",
			},
			{
				type = "dropdown",
				name = "(AP) Reserve",
				tooltip = "Maximum AP to reserve on each character",
				choices = {"|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "0", "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "10,000", "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "50,000", "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "100,000", "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "500,000", "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "1,000,000", "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "10,000,000"},
				choicesValues = {0, 10000, 50000, 100000, 500000, 1000000, 10000000},
				getFunc = function() return RidinDirty.savedVariables.apReserve end,
				setFunc = function(var) RidinDirty.savedVariables.apReserve = (var) end,
				disabled = function() return not RidinDirty.savedVariables.apDeposit end,
			},
			{
				type = "checkbox",
				name = "Telvar Deposit",
				tooltip = "Auto deposits or withdraws telvar stones above or below TELVAR RESERVE to or from bank",
				getFunc = function() return RidinDirty.savedVariables.telvarDeposit end,
				setFunc = function(value) RidinDirty.savedVariables.telvarDeposit = (value) end,
				warning = "Temporarily disables while crafting writ active",
			},
			{
				type = "dropdown",
				name = "Telvar Reserve",
				tooltip = "Maximum telvar to reserve on each character for X multiplier",
				choices = {"|t18:18:/esoui/art/currency/currency_telvar.dds|t" .. "0", "|t18:18:/esoui/art/currency/currency_telvar.dds|t" .. "99", "|t18:18:/esoui/art/currency/currency_telvar.dds|t" .. "1,000", "|t18:18:/esoui/art/currency/currency_telvar.dds|t" .. "10,000"},
				choicesValues = {0, 99, 1000, 10000},
				choicesTooltips = {"No Multiplier", "2X Queue Max", "3X Multiplier", "4X Multiplier"},
				getFunc = function() return RidinDirty.savedVariables.telvarReserve end,
				setFunc = function(var) RidinDirty.savedVariables.telvarReserve = (var) end,
				disabled = function() return not RidinDirty.savedVariables.telvarDeposit end,
			},
			{
				type = "checkbox",
				name = "Voucher Deposit",
				tooltip = "Auto deposits ALL writ vouchers into bank",
				getFunc = function() return RidinDirty.savedVariables.voucherDeposit end,
				setFunc = function(value) RidinDirty.savedVariables.voucherDeposit = (value) end,
				warning = "Temporarily disables while crafting writ active",
			},
			{
				type = "checkbox",
				name = "Display Bank Balances",
				tooltip = "Displays all banked balances to chat when opening the bank or after auto balancing",
				getFunc = function() return RidinDirty.savedVariables.balanceDisplay end,
				setFunc = function(value) RidinDirty.savedVariables.balanceDisplay = (value) end,
			},
		},
	},
	{
		type = "submenu",
		name = "|c999900JUNK MANAGER|r",
		controls = {
			{
				type = "checkbox",
				name = "Junk Manager",
				tooltip = "Marks & sells all trash, monster trophy's, rare fish and ornates plus enabled options below. Also self cleans junk list of enabled options below as looted and repairs all gear at merchants & with kits and gems",
				getFunc = function() return RidinDirty.savedVariables.junkManager end,
				setFunc = function(value) RidinDirty.JunkManagerToggle(value) end,
				width = "half",
			},
			{
				type = "checkbox",
				name = "Silent Junk Mode",
				tooltip = "Silently move junk without chat output",
				getFunc = function() return RidinDirty.savedVariables.junkSilentMode end,
				setFunc = function(value) RidinDirty.savedVariables.junkSilentMode = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
				width = "half",
			},
			{
				type = "checkbox",
				name = "Save Craftables",
				tooltip = "Don't move all newly crafted items to junk",
				getFunc = function() return RidinDirty.savedVariables.saveCraftables end,
				setFunc = function(value) RidinDirty.savedVariables.saveCraftables = (value) end,
				disabled = function() return RidinDirty.savedVariables.junkManager or not RidinDirty.savedVariables.junkManager end,
				warning = "Forced on for crafting writ compatibility",
			},
			{
				type = "checkbox",
				name = "Junk Intricates",
				tooltip = "Move all newly looted intricates to junk",
				getFunc = function() return RidinDirty.savedVariables.junkIntricates end,
				setFunc = function(value) RidinDirty.savedVariables.junkIntricates = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
			},
			{
				type = "checkbox",
				name = "Junk Treasures",
				tooltip = "Move all newly looted treasures with a value greater than 0 to junk",
				getFunc = function() return RidinDirty.savedVariables.junkTreasures end,
				setFunc = function(value) RidinDirty.savedVariables.junkTreasures = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
			},
			{
				type = "checkbox",
				name = "Junk Stolen Items",
				tooltip = "Move all newly looted stolen items to junk",
				getFunc = function() return RidinDirty.savedVariables.junkStolen end,
				setFunc = function(value) RidinDirty.savedVariables.junkStolen = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
			},
			{
				type = "checkbox",
				name = "Junk Known Scripts",
				tooltip = "Move all newly looted known scribing scripts to junk",
				getFunc = function() return RidinDirty.savedVariables.junkKnownScripts end,
				setFunc = function(value) RidinDirty.savedVariables.junkKnownScripts = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
				warning = "Requires LibCharacterKnowledge to detect what is knownst on other characters",
			},
			{
				type = "checkbox",
				name = "Junk Treasure Maps",
				tooltip = "Move all newly looted treasure maps to junk",
				getFunc = function() return RidinDirty.savedVariables.junkMaps end,
				setFunc = function(value) RidinDirty.savedVariables.junkMaps = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
			},
			{
				type = "checkbox",
				name = "DESTROY LQ Stolen Items",
				tooltip = "DESTROYS all newly looted low quality stolen items(not crafting materials) of white quality or less valued < 60 and indicate carried value for the professional thief",
				getFunc = function() return RidinDirty.savedVariables.destroyLQStolen end,
				setFunc = function(value) RidinDirty.savedVariables.destroyLQStolen = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
			},
			{
				type = "checkbox",
				name = "DESTROY Marked Unsellable",
				tooltip = "DESTROYS all newly looted unsellable items that have been marked as permanent junk ONLY",
				getFunc = function() return RidinDirty.savedVariables.destroyUnsellable end,
				setFunc = function(value) RidinDirty.savedVariables.destroyUnsellable = (value) end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
			},
			{
				type = "button",
				name = "RESET JUNK MEMORY",
				tooltip = "Completely clears junk memory",
				func = function() RidinDirty.ClearJunkMemory() end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
				isDangerous = true,
				width = "half",
			},
			{
				type = "button",
				name = "EDIT JUNK MEMORY",
				tooltip = "Brings up the junk memory window so you can remove items as needed",
				func = function() RidinDirty.JunkMemory:ToggleHidden() PlaySound("Click") end,
				disabled = function() return not RidinDirty.savedVariables.junkManager end,
				width = "half",
			},
		},
	},
	{
		type = "submenu",
        name = "|c999900LOOT MANAGER|r",
        controls = {
			{
				type = "checkbox",
				name = "Loot Manager",
				tooltip = "Outputs group loot to chat and filters out most trash and anything below selected quality with a minimal whitelist",
				getFunc = function() return RidinDirty.savedVariables.lootManager end,
				setFunc = function(value) RidinDirty.lootManagerToggle(value) end,
				warning = "NOT compatible with Loot Log. Requires LibCharacterKnowledge to detect what is knownst on other characters",
			},
			{
				type = "dropdown",
				name = "Minimum Quality",
				tooltip = "Minimum general loot quality to log to chat",
				choices = {"|cF8FAFCWHITE|r", "|c7CCF35GREEN|r", "|c2B7FFFBLUE|r", "|cAD46FFPURPLE|r", "|cFFDF20GOLD|r"},
				choicesValues = {1, 2, 3, 4, 5},
				getFunc = function() return RidinDirty.savedVariables.lootQuality end,
				setFunc = function(var) RidinDirty.savedVariables.lootQuality = (var) end,
				disabled = function() return not RidinDirty.savedVariables.lootManager end,
			},
			{
				type = "dropdown",
				name = "TTC Inventory Pricing",
				tooltip = "Show inventory values using selected TTC data with a fallback to listing average if no select data available",
				choices = {"|ccc0000*DISABLED*|r", "SuggestedPrice", "Sales Average", "List Average", "List Minumum", "List Maximum"},
				choicesValues = {false, "SuggestedPrice", "SaleAvg", "Avg", "Min", "Max"},
				getFunc = function() return RidinDirty.savedVariables.ttcPricing end,
				setFunc = function(var) RidinDirty.savedVariables.ttcPricing = (var) end,
				disabled = function() return not RidinDirty.savedVariables.lootManager end,
				warning = "Requires Loot Manager because they share the same function for efficiency and TTC for pricing data",
			},
			{
				type = "divider",
				alpha = 0.5,
				width = "full",
			},
			{
				type = "checkbox",
				name = "Trader Enhancements",
				tooltip = "Adds some QoL features to the trader window including active trader cycling by clicking guild name(skips non trading guilds with no listings), auto searching last search, listing counts",
				getFunc = function() return RidinDirty.savedVariables.traderEnhance end,
				setFunc = function(value) RidinDirty.TraderEnhanceToggle(value) end,
				warning = "NOT compatible with AwesomeGuildStore. Requires LibCharacterKnowledge to detect what is knownst on other characters & TTC for pricing data",
			},
		},
	},
	{
		type = "submenu",
		name = "|c999900PvP MANAGER|r",
		controls = {
			{
				type = "checkbox",
				name = "AP, Vet & Telvar Log to Chat",
				tooltip = "If either conditions below are met then all cached data will be output",
				getFunc = function() return RidinDirty.savedVariables.avtLog end,
				setFunc = function(value) RidinDirty.AVTLogToggle(value) end,
				width = "full",
			},
			{
				type = "slider",
				name = "Output Sensitivity",
				tooltip = "Minimum ap, telvar or veterancy gain to trigger chat output",
				min = 20,
				max = 400,
				step = 20,
				getFunc = function() return RidinDirty.savedVariables.minimumAVT end,
				setFunc = function(value) RidinDirty.savedVariables.minimumAVT = (value) end,
				disabled = function() return not RidinDirty.savedVariables.avtLog end,
				width = "full",
			},
			{
				type = "slider",
				name = "BOMB Sensitivity Delay",
				tooltip = "Adjusts wait duration to compile several events into a single output 1000 = 1sec",
				min = 100,
				max = 2000,
				step = 100,
				getFunc = function() return RidinDirty.savedVariables.bombSensitivity end,
				setFunc = function(value) RidinDirty.savedVariables.bombSensitivity = (value) end,
				disabled = function() return not RidinDirty.savedVariables.avtLog end,
				width = "full",
			},
			{
				type = "divider",
				alpha = 0.5,
				width = "full",
			},
			{
				type = "checkbox",
				name = "PvP Personal / Group Kill Feed",
				tooltip = "Enables personal / group kill feed including personal total daily killing blows, deaths and ratio% in cyrodiil, imperial city, battlegrounds & adds a forward camp reuse timer to cyrodiil map",
				getFunc = function() return RidinDirty.savedVariables.pvpKillFeed end,
				setFunc = function(value) RidinDirty.PvpKillFeedToggle(value) end,
				warning = "Audio feedback only if ingame global kill feed is enabled",
				width = "full",
			},
			{
				type = "button",
				name = "CLEAR & SET",
				tooltip = "Set to current time for daily reset & clear daily statistics for pvp personal kill feed",
				func = function() RidinDirty.SetClearKillFeed(true) end,
				disabled = function() return not RidinDirty.savedVariables.pvpKillFeed end,
				isDangerous = true,
				width = "half",
			},
			{
				type = "button",
				name = "RESET TO DEFAULT",
				tooltip = "Reset to default original daily reset time for pvp personal kill feed",
				func = function() RidinDirty.ResetKillFeed() end,
				disabled = function() return not RidinDirty.savedVariables.pvpKillFeed end,
				isDangerous = true,
				width = "half",
			},
		},
	},
	{
		type = "header",
		name = "|c999900ADDITIONAL FEATURES|r",
		width = "full",
    },
	{
		type = "dropdown",
		name = "Channel Notifications",
		tooltip = "Audio notification of whispers, group and yells with enhanced saved player login / logout / away info",
		choices = {"|ccc0000*DISABLED*|r", "Selection 1", "Selection 2", "Selection 3", "Selection 4", "Selection 5"},
		choicesValues = {false, "Book_Acquired", "InventoryItem_ApplyCharge", "New_Mail", "New_NotificationTimed", "Ability_Companion_Ultimate_Ready_Sound"},
		getFunc = function() return RidinDirty.savedVariables.chatNotify end,
		setFunc = function(value) RidinDirty.ChatNotifyToggle(value) end,
	},
	{
		type = "dropdown",
		name = "Nameplate Font Boost",
		tooltip = "Increase nameplate font size from 20pt to 26, 32, 38 and 44pt",
		choices = {"|ccc0000*DISABLED*|r", "Slightly Bigger", "Considerably Bigger", "Massively Bigger", "Hugemungusly Bigger"},
		choicesValues = {false, 26, 32, 38, 44},
		getFunc = function() return RidinDirty.savedVariables.fontBoost end,
		setFunc = function(value) RidinDirty.NamePlatesToggle(value) end,
	},
	{
		type = "checkbox",
		name = "Lock Armory Save Build",
		tooltip = "Locks armory save build button from accidental use",
		getFunc = function() return RidinDirty.savedVariables.lockArmory end,
		setFunc = function(value) RidinDirty.LockArmoryToggle(value) end,
	},
	{
		type = "checkbox",
		name = "Stack Attribute Bars",
		tooltip = "Stacks all default attribute bars into a tight pyramid above the ability bars. Does not modify anything else and works well with UI scaling.",
		getFunc = function() return RidinDirty.savedVariables.stackAttributes end,
		setFunc = function(value) RidinDirty.StackAttributesToggle(value) end,
	},
	{
		type = "checkbox",
		name = "Log Companion Info",
		tooltip = "Logs companion rapport changes to chat with display of current / maximum rapport & notifies on companion death",
		getFunc = function() return RidinDirty.savedVariables.companionRapport end,
		setFunc = function(value) RidinDirty.CompanionRapportToggle(value) end,
	},
	{
		type = "checkbox",
		name = "Auto Accept Queues",
		tooltip = "Auto accept queues for dungeons, battlegrounds, cyrodiil and imperial city",
		getFunc = function() return RidinDirty.savedVariables.autoQueue end,
		setFunc = function(value) RidinDirty.AutoQueueToggle(value) end,
	},
	{
		type = "checkbox",
		name = "Combat & Taunt Reticle",
		tooltip = "Shows if in combat or target taunt time left, including companion taunts, as well as taunt immunity in the center of reticle",
		getFunc = function() return RidinDirty.savedVariables.combatReticle end,
		setFunc = function(value) RidinDirty.CombatReticleToggle(value) end,
	},
	{
		type = "header",
		name = "|c999900SLASH FUNCTIONS|r",
		width = "full",
    },
	{
		type = "description",
		text = ("/tp home OR partialoverworldzonename\n/tp exact@name partialhousename\n/rdlink = group trade links for unneeded bop tradeable or set pieces\n/rdfc = time left to use forward camp in cyrodiil\n/rdpvp = pvp performance mode toggle for saved addons"),
	},
	{
		type = "button",
		name = "SAVE ENABLED ADDONS",
		tooltip = "Saves currently selected addons you want for PvP performance mode. Only needs to be selected in addons list",
		func = function() PvPAddonSave() end,
		isDangerous = true,
	},
	}
	local LAM2 = LibAddonMenu2
	RidinDirty.settingsPanel = LAM2:RegisterAddonPanel(panelName, panelData)
	LAM2:RegisterOptionControls(panelName, optionsData)
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
		if panel ~= RidinDirty.settingsPanel then return end
		RidinDirty.UpdateSettingsSavedPlayer(RidinDirty.savedVariables.savedPlayer)
		local junkMemory = RidinDirty.PopulateJunkMemory()
		RidinDirty.UpdateJunkMemoryList(RidinDirty.JunkMemoryList, junkMemory, 1)
	end)
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
		if panel ~= RidinDirty.settingsPanel then return end
		RidinDirty.JunkMemory:SetHidden(true)
	end)
	--CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
		--if panel ~= RidinDirty.settingsPanel then return end
		--RidinDirty.UpdateSettingsSavedPlayer(RidinDirty.savedVariables.savedPlayer)
	--end)
---------------------------------------------
------ CONTROLS & ANIMATIONS
---------------------------------------------
	-- Ouroboros Hourglass Animation --
	RidinDirty.HourGlass = WINDOW_MANAGER:CreateTopLevelWindow("HourGlass")
	--RidinDirty.HourGlass = WINDOW_MANAGER:CreateControl("HourGlass", GuiRoot, CT_CONTROL)
	RidinDirty.HourGlass:SetAnchor(CENTER, GuiRoot, TOP, 0, 300)
	--RidinDirty.HourGlass:SetParent(GuiRoot)
	RidinDirty.HourGlass:SetDimensions(64,64)
	RidinDirty.HourGlass.image = WINDOW_MANAGER:CreateControl("HourGlassImage", RidinDirty.HourGlass, CT_TEXTURE)
	RidinDirty.HourGlass.image:SetAnchorFill(RidinDirty.HourGlass)
	--RidinDirty.HourGlass.image:SetTexture("/esoui/art/screens_app/load_ourosboros.dds")--original
	RidinDirty.HourGlass.image:SetTexture("/esoui/art/login/credits_ourosboros.dds")
	RidinDirty.HourGlass.label = WINDOW_MANAGER:CreateControl("HourGlassLabel", RidinDirty.HourGlass, CT_LABEL)
	RidinDirty.HourGlass.label:SetAnchor(CENTER, RidinDirty.HourGlass, CENTER, 0, -60)
	RidinDirty.HourGlass.label:SetColor(128,128,0,0.8)
	RidinDirty.HourGlass.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.HourGlass.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.HourGlass.label:SetFont("ZoFontWinH2")
	RidinDirty.HourGlass.label:SetText ("")
	RidinDirty.HourGlass.animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("LoadIconAnimation", RidinDirty.HourGlass.image)
	RidinDirty.HourGlass.animation:GetFirstAnimation():SetDuration(6000)
	--RidinDirty.HourGlass:SetTopmost()
	local hourglassFrag = ZO_SimpleSceneFragment:New(RidinDirty.HourGlass)
	RidinDirty.HourGlass:SetHidden(true)
	
	-- JunkMemory Scroll Window --
	--RidinDirty.JunkMemory = WINDOW_MANAGER:CreateTopLevelWindow("JunkMemory")
	RidinDirty.JunkMemory = WINDOW_MANAGER:CreateControl("JunkMemory", LAMAddonSettingsWindow, CT_CONTROL)
	RidinDirty.JunkMemory:SetAnchor(LEFT, LAMAddonSettingsWindow, RIGHT, 0, 0)
	RidinDirty.JunkMemory:SetParent(LAMAddonSettingsWindow)
	RidinDirty.JunkMemory:SetDimensions(350, 700)
	RidinDirty.JunkMemory.label = WINDOW_MANAGER:CreateControl("JunkMemoryLabel", RidinDirty.JunkMemory, CT_LABEL)
	RidinDirty.JunkMemory.label:SetAnchor(CENTER, RidinDirty.JunkMemory, TOP, 0, 0)
	RidinDirty.JunkMemory.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.JunkMemory.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.JunkMemory.label:SetFont("ZoFontWinH2")
	RidinDirty.JunkMemory.label:SetColor(1, 1, 0.9, 1)
	RidinDirty.JunkMemory.label:SetText ("Junk Memory")
	RidinDirty.JunkMemoryBackground = WINDOW_MANAGER:CreateControlFromVirtual("JunkMemoryBg", RidinDirty.JunkMemory, "ZO_DefaultBackdrop")
	RidinDirty.JunkMemoryBackground:SetCenterColor(0, 0, 0, 0.9)
	RidinDirty.JunkMemoryBackground:SetEdgeColor(0, 0, 0, 0)
	RidinDirty.JunkMemoryBackground:SetAnchorFill(RidinDirty.JunkMemory)
	RidinDirty.JunkMemoryList = WINDOW_MANAGER:CreateControlFromVirtual("JunkMemoryList", RidinDirty.JunkMemory, "ZO_ScrollList")
	local width, height = RidinDirty.JunkMemory:GetDimensions()
	RidinDirty.JunkMemoryList:SetDimensions((width - 40), (height - 40))
	RidinDirty.JunkMemoryList:SetAnchor(CENTER, RidinDirty.JunkMemory, CENTER)
	local control = RidinDirty.JunkMemoryList
	local typeId = 1
	local templateName = "ZO_SelectableLabel"
	local height = 25
	local setupFunction = RidinDirty.JunkMemoryLayoutRow
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil
	local selectTemplate = "ZO_ThinListHighlight"
	--local selectCallback = RidinDirty.OnRowSelect
	ZO_ScrollList_AddDataType(control, typeId, templateName, height, setupFunction, hideCallback, dataTypeSelectSound, resetControlCallback)
	--ZO_ScrollList_EnableSelection(control, selectTemplate, selectCallback)
	RidinDirty.JunkMemory:SetHidden(true)
	
	-- Combat Indicator --
	RidinDirty.Combat = WINDOW_MANAGER:CreateTopLevelWindow("Combat")
	--RidinDirty.Combat = WINDOW_MANAGER:CreateControl("Combat", GuiRoot, CT_CONTROL)
	RidinDirty.Combat:SetAnchor(CENTER, GuiRoot, CENTER)
	RidinDirty.Combat:SetDimensions(32,32)
	RidinDirty.Combat.image = WINDOW_MANAGER:CreateControl("CombatImage", RidinDirty.Combat, CT_TEXTURE)
	RidinDirty.Combat.image:SetAnchorFill(RidinDirty.Combat)
	RidinDirty.Combat.image:SetTexture("/esoui/art/mainmenu/menubar_map_up.dds")
	RidinDirty.Combat.image:SetTransformRotationZ(math.rad(45))
	RidinDirty.Combat.image:SetColor(128,0,0,1)
	--RidinDirty.Combat:SetTopmost()
	local combatFrag = ZO_SimpleSceneFragment:New(RidinDirty.Combat)
	RidinDirty.Combat:SetHidden(true)
	
	-- Taunt Timer Indicator --
	RidinDirty.TauntCounter = WINDOW_MANAGER:CreateTopLevelWindow("TauntCounter")
	--RidinDirty.TauntCounter = WINDOW_MANAGER:CreateControl("TauntCounter", GuiRoot, CT_CONTROL)
	RidinDirty.TauntCounter:SetAnchor(CENTER, GuiRoot, CENTER)
	RidinDirty.TauntCounter:SetDimensions(32,32)
	RidinDirty.TauntCounter.label = WINDOW_MANAGER:CreateControl("TauntCounterLabel", RidinDirty.TauntCounter, CT_LABEL)
	RidinDirty.TauntCounter.label:SetAnchor(CENTER, RidinDirty.TauntCounter, CENTER, 0, 0)
	RidinDirty.TauntCounter.label:SetColor(128,128,128,1)
	RidinDirty.TauntCounter.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.TauntCounter.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.TauntCounter.label:SetFont("ZoFontWinH3")
	RidinDirty.TauntCounter.label:SetText ("")
	--RidinDirty.TauntCounter:SetTopmost()
	local tauntFrag = ZO_SimpleSceneFragment:New(RidinDirty.TauntCounter)
	RidinDirty.TauntCounter:SetHidden(true)
	
	-- Trader Listing Count Indicator --
	--RidinDirty.ListingCounter = WINDOW_MANAGER:CreateTopLevelWindow("ListingCounter")
	RidinDirty.ListingCounter = WINDOW_MANAGER:CreateControl("ListingCounter", ZO_TradingHouse, CT_CONTROL)
	RidinDirty.ListingCounter:SetAnchor(BOTTOM, ZO_TradingHouse, TOP, 0, 10)-- -22 for ags
	RidinDirty.ListingCounter:SetParent(ZO_TradingHouse)
	RidinDirty.ListingCounter:SetDimensions(64,64)
	RidinDirty.ListingCounter.label = WINDOW_MANAGER:CreateControl("ListingCounterLabel", RidinDirty.ListingCounter, CT_LABEL)
	RidinDirty.ListingCounter.label:SetAnchor(CENTER, RidinDirty.ListingCounter, CENTER, 0, 0)
	RidinDirty.ListingCounter.label:SetColor(128,128,128,1)
	RidinDirty.ListingCounter.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.ListingCounter.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	RidinDirty.ListingCounter.label:SetFont("ZoFontWinH2")
	RidinDirty.ListingCounter.label:SetText ("")
	--RidinDirty.ListingCounter:SetTopmost()
	local listingFrag = ZO_SimpleSceneFragment:New(RidinDirty.ListingCounter)
	RidinDirty.ListingCounter:SetHidden(true)
	
	-- ArmoryUnlock Button --
	--RidinDirty.ArmoryLock = WINDOW_MANAGER:CreateTopLevelWindow("ArmoryLock")
	RidinDirty.ArmoryLock = WINDOW_MANAGER:CreateControl("ArmoryLock", ZO_Armory_Keyboard_TopLevelTitleSectionHeader, CT_BUTTON)
	RidinDirty.ArmoryLock:SetDimensions(32, 32)
	RidinDirty.ArmoryLock:SetAnchor(LEFT, ZO_Armory_Keyboard_TopLevelTitleSectionHeader, RIGHT, 10, 0)
	--RidinDirty.ArmoryLock:SetNormalTexture("/esoui/art/buttons/btn_normal.dds")
	--RidinDirty.ArmoryLock:SetPressedTexture("/esoui/art/buttons/btn_pressed.dds")
	--RidinDirty.ArmoryLock:SetMouseOverTexture("/esoui/art/buttons/btn_mouseover.dds")
	RidinDirty.ArmoryLock:SetFont("ZoFontWinH3")
	RidinDirty.ArmoryLock:SetText("")
	RidinDirty.ArmoryLock:SetMouseEnabled(false)
	RidinDirty.ArmoryLock:SetHidden(true)
	RidinDirty.ArmoryLock:SetHandler("OnMouseUp", function(self, mouseButton, upInside)
		if upInside then
			RidinDirty.ArmoryUnlock()
		end
	end)
	RidinDirty.ArmoryLock:SetHandler("OnMouseEnter", function(self)
		InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
		SetTooltipText(InformationTooltip, "CLICK TO UNLOCK")
	end)
	RidinDirty.ArmoryLock:SetHandler("OnMouseExit", function(self)
		ClearTooltip(InformationTooltip)
	end)
	local armoryFrag = ZO_SimpleSceneFragment:New(RidinDirty.ArmoryLock)
	RidinDirty.ArmoryLock:SetHidden(true)
	RidinDirty.ArmoryLock:SetAlpha(0)
	
	-- Apply Fragments --
	local hudscene = SCENE_MANAGER:GetScene("hud")
	local traderscene = SCENE_MANAGER:GetScene("tradinghouse")
	local armoryscene = SCENE_MANAGER:GetScene("armoryKeyboard")
	local fragmentGroup1 = { hourglassFrag, combatFrag, tauntFrag }
	local fragmentGroup2 = { listingFrag }
	local fragmentGroup4 = { armoryFrag }
	hudscene:AddFragmentGroup(fragmentGroup1)
	traderscene:AddFragmentGroup(fragmentGroup2)
	armoryscene:AddFragmentGroup(fragmentGroup4)
	
	RidinDirty.HourGlass:SetAlpha(0)
	RidinDirty.TauntCounter:SetAlpha(0)
	RidinDirty.Combat:SetAlpha(0)
end
---------------------------------------------
-------- PLAYER ACTIVATED --
---------------------------------------------
local function OnPlayerActivated()
	if RidinDirty.savedVariables.lockArmory then
		if ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled ~= false then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "Armory save build auto locked.") end
		ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled = false
		ARMORY_KEYBOARD.keybindStripDescriptor[2].name = ("Save Locked")
		RidinDirty.ArmoryLock:SetText("|t32:32:ESOUI/art/miscellaneous/locked_up.dds|t")
		RidinDirty.ArmoryLock:SetMouseEnabled(true)
		RidinDirty.ArmoryLock:SetAlpha(1)
	end
	if RidinDirty.savedVariables.lootManager and not chatMods then
		chatMods = true
		local origFormatter = CHAT_ROUTER:GetRegisteredMessageFormatters()[EVENT_CHAT_MESSAGE_CHANNEL]
			CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, function(channelType, fromName, text, isCustomerService, fromDisplayName)
				local formattedText, saveTarget, _, originalText = origFormatter(channelType, fromName, text, isCustomerService, fromDisplayName)
				if formattedText then
					local newFormatted = formattedText
					for itemLink in formattedText:gmatch("|H.-|h.-|h") do
						if not itemLink then break end
						local itemId = GetItemLinkItemId(itemLink)
						local itemType, specialType = GetItemLinkItemType(itemLink)
						if not (itemId and itemType and specialType) then break end
						if IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) then 
							local newLink = (IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) .. itemLink) or itemLink
							newFormatted = string.gsub(newFormatted, itemLink, newLink)
							break--<< TESTING
						end
					end
					return newFormatted, saveTarget, fromDisplayName, originalText
				else
					return formattedText, saveTarget, fromDisplayName, originalText
				end
			end)
	end
	if RidinDirty.savedVariables.stackAttributes then
		ZO_PlayerAttributeHealth:SetAnchor(TOP, ZO_BuffDebuffTopLevelSelfContainer, BOTTOM, 0, 24)
		ZO_PlayerAttributeMagicka:SetAnchor(TOPRIGHT, ZO_PlayerAttributeHealth, BOTTOM, 0, 8)
		ZO_PlayerAttributeStamina:SetAnchor(TOPLEFT, ZO_PlayerAttributeHealth, BOTTOM, 0, 8)
	end
	if RidinDirty.savedVariables.fontBoost then
		SetNameplateKeyboardFont(string.format("%s|%d", "$(BOLD_FONT)", RidinDirty.savedVariables.fontBoost), FONT_STYLE_SOFT_SHADOW_THIN)
	end
	PassengerStateChange()
end
---------------------------------------------
---------- SAVE PLAYER --
---------------------------------------------
function RidinDirty.SaveMenu(data)
	if data.displayName == GetUnitDisplayName("player") then return end
	AddCustomMenuItem("Save for RidinDirty", function() RidinDirty.SavePlayer(data.displayName) end)
end

function RidinDirty.SavePlayer(displayName)
	RidinDirty.savedVariables.savedPlayer = displayName
	df(rdLogo .. "Saving: " .. displayName)
	RidinDirty.UpdateSettingsSavedPlayer(displayName)
end

function RidinDirty.UpdateSettingsSavedPlayer(displayName)
	if RIDINDIRTY_SETTINGS_SAVEDPLAYER_TEXT ~= nil then
		RIDINDIRTY_SETTINGS_SAVEDPLAYER_TEXT.data.text = ("Saved Player: " .. displayName)
		RIDINDIRTY_SETTINGS_SAVEDPLAYER_TEXT:UpdateValue()
	end
end
---------------------------------------------
-------- MOUNT GROUP MEMBER --
---------------------------------------------
function RidinDirty.MountPlayer()
	if IsUnitDeadOrReincarnating("player") then return end
	local displayNamePref = nil
	local isMountable = false
	for iD = 1, GetGroupSize() do
		local playerID = GetGroupUnitTagByIndex(iD)
		local playerCharName = GetUnitName(playerID)
		local playerDisplayName = GetUnitDisplayName(playerID)
		local mountedState, hasEnabledGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(playerDisplayName)
		if mountedState == MOUNTED_STATE_MOUNT_RIDER and hasEnabledGroupMount and hasFreePassengerSlot then isMountable = true else isMountable = false end
		if not ZO_ShouldPreferUserId() then displayNamePref = playerCharName else displayNamePref = playerDisplayName end
		displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
		if playerDisplayName ~= GetUnitDisplayName("player") and IsUnitOnline(playerID) and IsUnitInGroupSupportRange(playerID) and isMountable and DistanceToUnit(playerID) < 5.0 then
			if IsMounted() then CallSecureProtected("ToggleMount") end
			CENTER_SCREEN_ANNOUNCE:AddMessage( 0, CSA_CATEGORY_SMALL_TEXT, "New_Mail", ("|cC99912Mounting " .. displayNamePref .. "|r"), nil, nil, nil, nil, nil, 5000, nil)
			UseMountAsPassenger(playerDisplayName)
			return
		end
	end
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "No group member in range.")
end
---------------------------------------------
------- TRAVEL TO PRIMARY HOME -- --ForceCancelMounted *private* ()
---------------------------------------------
function RidinDirty.TeleportDeathState()
	if IsUnitDead("player") then
		EVENT_MANAGER:UnregisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE)
		EVENT_MANAGER:UnregisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
		RidinDirty.HourGlass:SetAlpha(0)
		RidinDirty.HourGlass.animation:Stop()
	end
end

function RidinDirty.TravelToHome()
	if IsPlayerInAvAWorld() or IsActiveWorldBattleground() then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("You cannot travel from this location.")) return end
	if IsUnitDeadOrReincarnating("player") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("You are dead and cannot travel.")) return end
	local travelOutside = RidinDirty.savedVariables.travelOutside
	if IsUnitInCombat("player") then
		if RidinDirty.HourGlass:GetAlpha() == 1 then
			RidinDirty.TeleportHomeQueueOff()
			return
		else
			RidinDirty.TeleportHomeQueueOn()
			return
		end
	else
		if IsMounted() then CallSecureProtected("ToggleMount") end
		if InAlphaList(GetUnitDisplayName("player")) then--<< TESTING
			df(rdLogo .. "|cFF3399Headin To The LOOOVE SHACK BAEEEBY!!!|r")
		else
			if travelOutside then
				df(rdLogo .. "Traveling to " .. tostring(GetCollectibleNickname(GetCollectibleIdForHouse(GetHousingPrimaryHouse()))) .. " (Outside)")
			else
				df(rdLogo .. "Traveling to " .. tostring(GetCollectibleNickname(GetCollectibleIdForHouse(GetHousingPrimaryHouse()))) .. " (Inside)")
			end
		end
		RequestJumpToHouse(GetHousingPrimaryHouse(), travelOutside)
		return
	end
end

function RidinDirty.TeleportHomeQueueOn()
	EVENT_MANAGER:RegisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE, RidinDirty.TeleportHomeQueue)
	EVENT_MANAGER:RegisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED, RidinDirty.TeleportDeathState)
	EVENT_MANAGER:AddFilterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "player")
	PlaySound("GuildRoster_Added")
	RidinDirty.HourGlass.label:SetText (rdLogo .. "Travel Home Combat Queued")
	RidinDirty.HourGlass:SetAlpha(1)
	RidinDirty.HourGlass.animation:PlayForward()
	if InAlphaList(GetUnitDisplayName("player")) then--<< TESTING
		if GetUnitGender("player") == GENDER_MALE then
			if SCENE_MANAGER:GetCurrentScene() == HUD_SCENE and IsCollectibleUnlocked(9863) then DoCommand("/ritualcasting") end
		else
			if SCENE_MANAGER:GetCurrentScene() == HUD_SCENE and IsCollectibleUnlocked(9004) then DoCommand("/dayoflights") end
		end
	end
end

function RidinDirty.TeleportHomeQueue()
	EVENT_MANAGER:UnregisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE)
	EVENT_MANAGER:UnregisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
	RidinDirty.HourGlass:SetAlpha(0)
	RidinDirty.HourGlass.animation:Stop()
	RidinDirty.TravelToHome()
end

function RidinDirty.TeleportHomeQueueOff()
	EVENT_MANAGER:UnregisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE)
	EVENT_MANAGER:UnregisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
	RidinDirty.HourGlass:SetAlpha(0)
	RidinDirty.HourGlass.animation:Stop()
end
---------------------------------------------
-------- TRAVEL TO SAVED PLAYER OR In Zone --
---------------------------------------------
local function spInGroup()
	local savedPlayer = RidinDirty.savedVariables.savedPlayer
	for iD = 1, GetGroupSize() do
		local playerID = GetGroupUnitTagByIndex(iD)
		local playerDisplayName = GetUnitDisplayName(playerID)
		if playerDisplayName ~= GetUnitDisplayName("player") and playerDisplayName == savedPlayer and IsUnitOnline(playerID) then
			return true
		end
	end
	return false
end

function RidinDirty.TravelToPlayer()
	if IsPlayerInAvAWorld() or IsActiveWorldBattleground() then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("You cannot travel from this location.")) return end
	if IsUnitDeadOrReincarnating("player") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("You are dead and cannot travel.")) return end
	local savedPlayer = RidinDirty.savedVariables.savedPlayer
	local displayNamePref = nil
	local spInGroup = spInGroup()
	for iD = 1, GetGroupSize() do
		local playerID = GetGroupUnitTagByIndex(iD)
		local playerCharName = GetUnitName(playerID)
		local playerDisplayName = GetUnitDisplayName(playerID)
		local zoneName = GetUnitZone(playerID)
		if not ZO_ShouldPreferUserId() then displayNamePref = playerCharName else displayNamePref = playerDisplayName end
		displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
		if playerDisplayName ~= GetUnitDisplayName("player") and (playerDisplayName == savedPlayer or (zoneName == GetUnitZone("player") and not spInGroup))and IsUnitOnline(playerID) then
			if IsUnitInCombat("player") then
				if RidinDirty.HourGlass:GetAlpha() == 1 then
					RidinDirty.TeleportPlayerQueueOff()
					return
				else
					RidinDirty.TeleportPlayerQueueOn(displayNamePref)
					return
				end
			else
				if IsMounted() then CallSecureProtected("ToggleMount") end
				local targetLocation = "zone"
				if spInGroup then targetLocation = zoneName end
				df(rdLogo .. "Traveling to " .. displayNamePref .. " in " .. targetLocation)
				JumpToGroupMember(playerDisplayName)
				return
			end
		end
	end
	for friendIndex = 1, GetNumFriends() do
		local friendName, _, friendStatus = GetFriendInfo(friendIndex)
		local _, friendCharName, friendZone = GetFriendCharacterInfo(friendIndex)
		if not ZO_ShouldPreferUserId() then displayNamePref = friendCharName else displayNamePref = friendName end
		displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
		if friendZone == GetUnitZone("player") and friendStatus ~= PLAYER_STATUS_OFFLINE then
			if IsUnitInCombat("player") then
				if RidinDirty.HourGlass:GetAlpha() == 1 then
					RidinDirty.TeleportPlayerQueueOff()
					return
				else
					RidinDirty.TeleportPlayerQueueOn(displayNamePref)
					return
				end
			else
				if IsMounted() then CallSecureProtected("ToggleMount") end
				df(rdLogo .. "Traveling to " .. displayNamePref .. " in zone")
				JumpToFriend(friendName)
				return
			end
		end
	end
	for guildIndex = 1, GetNumGuilds() do
		local guildId = GetGuildId(guildIndex)
		local memberNumber = GetNumGuildMembers(guildId)
		local myIndex = GetPlayerGuildMemberIndex(guildId)
		for memberIndex = 1, memberNumber, 1 do
			local memberName, _, _, memberStatus = GetGuildMemberInfo(guildId, memberIndex)
			local _, memberCharName, memberZone = GetGuildMemberCharacterInfo(guildId, memberIndex)
			if not ZO_ShouldPreferUserId() then displayNamePref = memberCharName else displayNamePref = memberName end
			displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
			if memberIndex ~= myIndex and memberName ~= GetUnitDisplayName("player") and memberZone == GetUnitZone("player") and memberStatus ~= PLAYER_STATUS_OFFLINE then
				if IsUnitInCombat("player") then
					if RidinDirty.HourGlass:GetAlpha() == 1 then
						RidinDirty.TeleportPlayerQueueOff()
						return
					else
						RidinDirty.TeleportPlayerQueueOn(displayNamePref)
						return
					end
				else
					if IsMounted() then CallSecureProtected("ToggleMount") end
					df(rdLogo .. "Traveling to " .. displayNamePref .. " in zone")
					JumpToGuildMember(memberName)
					return
				end
			end
		end
	end
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "No player found in zone.")
end

function RidinDirty.TeleportPlayerQueueOn(playerName)
	EVENT_MANAGER:RegisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE, RidinDirty.TeleportPlayerQueue)
	EVENT_MANAGER:RegisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED, RidinDirty.TeleportDeathState)
	EVENT_MANAGER:AddFilterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "player")
	PlaySound("GuildRoster_Added")
	RidinDirty.HourGlass.label:SetText (rdLogo .. "Travel To " .. playerName .. " Combat Queued")
	RidinDirty.HourGlass:SetAlpha(1)
	RidinDirty.HourGlass.animation:PlayForward()
	if InAlphaList(GetUnitDisplayName("player")) then--<< TESTING
		if GetUnitGender("player") == GENDER_MALE then
			if SCENE_MANAGER:GetCurrentScene() == HUD_SCENE and IsCollectibleUnlocked(9863) then DoCommand("/ritualcasting") end
		else
			if SCENE_MANAGER:GetCurrentScene() == HUD_SCENE and IsCollectibleUnlocked(9004) then DoCommand("/dayoflights") end
		end
	end
end

function RidinDirty.TeleportPlayerQueue()
	EVENT_MANAGER:UnregisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE)
	EVENT_MANAGER:UnregisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
	RidinDirty.HourGlass:SetAlpha(0)
	RidinDirty.HourGlass.animation:Stop()
	RidinDirty.TravelToPlayer()
end

function RidinDirty.TeleportPlayerQueueOff()
	EVENT_MANAGER:UnregisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE)
	EVENT_MANAGER:UnregisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
	RidinDirty.HourGlass:SetAlpha(0)
	RidinDirty.HourGlass.animation:Stop()
end
---------------------------------------------
------ TRAVEL TO HOUSE OR ZONES /tp --
---------------------------------------------
function RidinDirty.Teleport(value1, value2)
	if IsPlayerInAvAWorld() or IsActiveWorldBattleground() then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("You cannot travel from this location.")) return end
	if IsUnitDeadOrReincarnating("player") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("You are dead and cannot travel.")) return end
	local displayNamePref = nil
	if playerSearch ~= nil then
		value1 = playerSearch
		value2 = houseSearch
		playerSearch = nil
		houseSearch = nil
	end
	if value2 ~= nil and value2 ~= "" then
		if IsUnitInCombat("player") then
			if RidinDirty.HourGlass:GetAlpha() == 1 then
				RidinDirty.TeleportZoneQueueOff()
				return
			else
				playerSearch = value1
				houseSearch = value2
				RidinDirty.TeleportZoneQueueOn(value1, value2)
				return
			end
		else
			if IsMounted() then CallSecureProtected("ToggleMount") end
			df(rdLogo .. "Traveling to " .. GetHousingLink(GetHouseID(value2), value1))
			JumpToSpecificHouse(value1, GetHouseID(value2))
			return
		end
	end
	for iD = 1, GetGroupSize() do
		local playerID = GetGroupUnitTagByIndex(iD)
		local zoneIndex = GetUnitZoneIndex(playerID)
		local zoneID = GetZoneId(zoneIndex)
		local memberZone = GetUnitZone(playerID)
		local memberName = GetUnitDisplayName(playerID)
		local memberCharName = GetUnitName(playerID)
		if not ZO_ShouldPreferUserId() then displayNamePref = memberCharName else displayNamePref = memberName end
		displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
		if memberName ~= GetUnitDisplayName("player") and string.find(string.lower(memberZone), string.lower(value1), 1, true) ~= nil and IsUnitOnline(playerID) and InZoneWhitelist(memberZone) then
			if IsUnitInCombat("player") then
				if RidinDirty.HourGlass:GetAlpha() == 1 then
					RidinDirty.TeleportZoneQueueOff()
					return
				else
					playerSearch = value1
					RidinDirty.TeleportZoneQueueOn(displayNamePref)
					return
				end
			else
				if IsMounted() then CallSecureProtected("ToggleMount") end
				df(rdLogo .. "Traveling to " .. displayNamePref .. " in " .. memberZone)
				JumpToGroupMember(memberName)
				return
			end
		end
	end
	for friendIndex = 1, GetNumFriends() do
		local friendName, _, friendStatus = GetFriendInfo(friendIndex)
		local _, friendCharName, friendZone, _, _, _, _, friendzoneID = GetFriendCharacterInfo(friendIndex)
		if not ZO_ShouldPreferUserId() then displayNamePref = friendCharName else displayNamePref = friendName end
		displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
		if string.find(string.lower(friendZone), string.lower(value1), 1, true) ~= nil and friendStatus ~= PLAYER_STATUS_OFFLINE and InZoneWhitelist(friendZone) then
			if IsUnitInCombat("player") then
				if RidinDirty.HourGlass:GetAlpha() == 1 then
					RidinDirty.TeleportZoneQueueOff()
					return
				else
					playerSearch = value1
					RidinDirty.TeleportZoneQueueOn(displayNamePref)
					return
				end
			else
				if IsMounted() then CallSecureProtected("ToggleMount") end
				df(rdLogo .. "Traveling to " .. displayNamePref .. " in " .. friendZone)
				JumpToFriend(friendName)
				return
			end
		end
	end
	for guildIndex = 1, GetNumGuilds() do
		local guildId = GetGuildId(guildIndex)
		local memberNumber = GetNumGuildMembers(guildId)
		local myIndex = GetPlayerGuildMemberIndex(guildId)
		for memberIndex = 1, memberNumber, 1 do
			local memberName, _, _, memberStatus = GetGuildMemberInfo(guildId, memberIndex)
			local _, memberCharName, memberZone, _, _, _, _, memberzoneID = GetGuildMemberCharacterInfo(guildId, memberIndex)
			if not ZO_ShouldPreferUserId() then displayNamePref = memberCharName else displayNamePref = memberName end
			displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
			if memberIndex ~= myIndex and string.find(string.lower(memberZone), string.lower(value1), 1, true) ~= nil and memberStatus ~= PLAYER_STATUS_OFFLINE and InZoneWhitelist(memberZone) then
				if IsUnitInCombat("player") then
					if RidinDirty.HourGlass:GetAlpha() == 1 then
						RidinDirty.TeleportZoneQueueOff()
						return
					else
						playerSearch = value1
						RidinDirty.TeleportZoneQueueOn(displayNamePref)
						return
					end
				else
					if IsMounted() then CallSecureProtected("ToggleMount") end
					df(rdLogo .. "Traveling to " .. displayNamePref .. " in " .. memberZone)
					JumpToGuildMember(memberName)
					return
				end
			end
		end
	end
	if value2 == nil or value2 == "" then
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("No player found anywhere matching: " .. value1 .. "."))
	end
	return
end

function RidinDirty.TeleportZoneQueueOn(value1, value2)
	EVENT_MANAGER:RegisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE, RidinDirty.TeleportZoneQueue)
	EVENT_MANAGER:RegisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED, RidinDirty.TeleportDeathState)
	EVENT_MANAGER:AddFilterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "player")
	PlaySound("GuildRoster_Added")
	local teleportTarget = nil
	if value2 == nil then teleportTarget = value1 else teleportTarget = GetHousingLink(GetHouseID(value2), value1) end
	RidinDirty.HourGlass.label:SetText (rdLogo .. "Travel To " .. teleportTarget .. " Combat Queued")
	RidinDirty.HourGlass:SetAlpha(1)
	RidinDirty.HourGlass.animation:PlayForward()
	if InAlphaList(GetUnitDisplayName("player")) then--<< TESTING
		if GetUnitGender("player") == GENDER_MALE then
			if SCENE_MANAGER:GetCurrentScene() == HUD_SCENE and IsCollectibleUnlocked(9863) then DoCommand("/ritualcasting") end
		else
			if SCENE_MANAGER:GetCurrentScene() == HUD_SCENE and IsCollectibleUnlocked(9004) then DoCommand("/dayoflights") end
		end
	end
end

function RidinDirty.TeleportZoneQueue()
	local value1 = playerSearch
	local value2 = houseSearch
	EVENT_MANAGER:UnregisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE)
	EVENT_MANAGER:UnregisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
	RidinDirty.HourGlass:SetAlpha(0)
	RidinDirty.HourGlass.animation:Stop()
	RidinDirty.Teleport(value1, value2)
end

function RidinDirty.TeleportZoneQueueOff()
	EVENT_MANAGER:UnregisterForEvent("RidinDirtyQueue", EVENT_PLAYER_COMBAT_STATE)
	EVENT_MANAGER:UnregisterForEvent("RDTeleportDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
	RidinDirty.HourGlass:SetAlpha(0)
	RidinDirty.HourGlass.animation:Stop()
end
---------------------------------------------
------ AUTO BANK & STORAGE STACKER --
---------------------------------------------
local function BankBalances(eventCode, bagId, carriedGold, carriedAP, carriedTelvar, carriedVoucher, moveGold, moveAP, moveTelvar, moveVoucher)
	--if not RidinDirty.savedVariables.balanceDisplay then return end
	local bankedCurrencies = (rdLogo .. "Balances:")
	local curbankGold = GetBankedCurrencyAmount(CURT_MONEY)
	local curbankAP = GetBankedCurrencyAmount(CURT_ALLIANCE_POINTS)
	local curbankTelvar = GetBankedCurrencyAmount(CURT_TELVAR_STONES)
	local curbankVouchers = GetBankedCurrencyAmount(CURT_WRIT_VOUCHERS)
	if moveGold then curbankGold = (carriedGold + GetBankedCurrencyAmount(CURT_MONEY)) moveGold = false end
	if moveAP then curbankAP = (carriedAP + GetBankedCurrencyAmount(CURT_ALLIANCE_POINTS)) moveAP = false end
	if moveTelvar then curbankTelvar = (carriedTelvar + GetBankedCurrencyAmount(CURT_TELVAR_STONES)) moveTelvar = false end
	if moveVoucher then curbankVouchers = (carriedVoucher + GetBankedCurrencyAmount(CURT_WRIT_VOUCHERS)) moveVoucher = false end
	if curbankGold > 0 then
		bankedCurrencies = (bankedCurrencies .. " " .. "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. ZO_LocalizeDecimalNumber(curbankGold))
	end
	if curbankAP > 0 then
		bankedCurrencies = (bankedCurrencies .. " " .. "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "|c339933" .. ZO_LocalizeDecimalNumber(curbankAP) .. "|r")
	end
	if curbankTelvar > 0 then
		bankedCurrencies = (bankedCurrencies .. " " .. "|t18:18:/esoui/art/currency/currency_telvar.dds|t" .. "|c33CCCC" .. ZO_LocalizeDecimalNumber(curbankTelvar) .. "|r")
	end
	if curbankVouchers > 0 then
		bankedCurrencies = (bankedCurrencies .. " " .. "|t18:18:/esoui/art/currency/currency_writvoucher.dds|t" .. "|cFFEECC" .. ZO_LocalizeDecimalNumber(curbankVouchers) .. "|r")
	end
	if bankedCurrencies ~= (rdLogo .. "Balances:") then df(bankedCurrencies) end
end

local function DepositCurrency(eventCode, bagId)
	local moveGold = false
	local moveAP = false
	local moveTelvar = false
	local moveVoucher = false
	local carriedGold = GetCarriedCurrencyAmount(CURT_MONEY)
	local goldReserve = RidinDirty.savedVariables.goldReserve
	local withdrawGold = 0
	local carriedAP = GetCarriedCurrencyAmount(CURT_ALLIANCE_POINTS)
	local apReserve = RidinDirty.savedVariables.apReserve
	local withdrawAP = 0
	local carriedTelvar = GetCarriedCurrencyAmount(CURT_TELVAR_STONES)
	local telvarReserve = RidinDirty.savedVariables.telvarReserve
	local withdrawTelvar = 0
	local carriedVoucher = GetCarriedCurrencyAmount(CURT_WRIT_VOUCHERS)
	if RidinDirty.savedVariables.goldDeposit and GetUnitName("player") ~= RidinDirty.savedVariables.noDeposit then
		if (carriedGold < goldReserve) and ((goldReserve - carriedGold) < GetBankedCurrencyAmount(CURT_MONEY)) then
			moveGold = true
			withdrawGold = (goldReserve - carriedGold)
			carriedGold = (withdrawGold - (withdrawGold*2))
			WithdrawCurrencyFromBank(CURT_MONEY, withdrawGold)
			df(rdLogo .. "Withdrew: " .. "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. ZO_LocalizeDecimalNumber(carriedGold))
		elseif (carriedGold > goldReserve) then
			moveGold = true
			carriedGold = (carriedGold - goldReserve)
			DepositCurrencyIntoBank(CURT_MONEY, carriedGold)
			df(rdLogo .. "Deposited: " .. "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. ZO_LocalizeDecimalNumber(carriedGold))
		end
	end
	if RidinDirty.savedVariables.apDeposit then
		if (carriedAP < apReserve) and ((apReserve - carriedAP) < GetBankedCurrencyAmount(CURT_ALLIANCE_POINTS)) then
			moveAP = true
			withdrawAP = (apReserve - carriedAP)
			carriedAP = (withdrawAP - (withdrawAP*2))
			WithdrawCurrencyFromBank(CURT_ALLIANCE_POINTS, withdrawAP)
			df(rdLogo .. "Withdrew: " .. "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "|c339933" .. ZO_LocalizeDecimalNumber(carriedAP) .. "|r")
		elseif (carriedAP > apReserve) then
			moveAP = true
			carriedAP = (carriedAP - apReserve)
			DepositCurrencyIntoBank(CURT_ALLIANCE_POINTS, carriedAP)
			df(rdLogo .. "Deposited: " .. "|t18:18:/esoui/art/currency/alliancepoints.dds|t" .. "|c339933" .. ZO_LocalizeDecimalNumber(carriedAP) .. "|r")
		end
	end
	if RidinDirty.savedVariables.telvarDeposit then
		if (carriedTelvar < telvarReserve) and ((telvarReserve - carriedTelvar) < GetBankedCurrencyAmount(CURT_TELVAR_STONES)) then
			moveTelvar = true
			withdrawTelvar = (telvarReserve - carriedTelvar)
			carriedTelvar = (withdrawTelvar - (withdrawTelvar*2))
			WithdrawCurrencyFromBank(CURT_TELVAR_STONES, withdrawTelvar)
			df(rdLogo .. "Withdrew: " .. "|t18:18:/esoui/art/currency/currency_telvar.dds|t" .. "|c33CCCC" .. ZO_LocalizeDecimalNumber(carriedTelvar) .. "|r")
		elseif (carriedTelvar > telvarReserve) then
			moveTelvar = true
			carriedTelvar = (carriedTelvar - telvarReserve)
			DepositCurrencyIntoBank(CURT_TELVAR_STONES, carriedTelvar)
			df(rdLogo .. "Deposited: " .. "|t18:18:/esoui/art/currency/currency_telvar.dds|t" .. "|c33CCCC" .. ZO_LocalizeDecimalNumber(carriedTelvar) .. "|r")
		end
	end
	if RidinDirty.savedVariables.voucherDeposit then
		if (carriedVoucher > 0) then
			moveVoucher = true
			DepositCurrencyIntoBank(CURT_WRIT_VOUCHERS, carriedVoucher)
			df(rdLogo .. "Deposited: " .. "|t18:18:/esoui/art/currency/currency_writvoucher.dds|t" .. "|cFFEECC" .. ZO_LocalizeDecimalNumber(carriedVoucher) .. "|r")
		end
	end
	if RidinDirty.savedVariables.balanceDisplay then
		BankBalances(eventCode, bagId, carriedGold, carriedAP, carriedTelvar, carriedVoucher, moveGold, moveAP, moveTelvar, moveVoucher)
	end
	if RidinDirty.savedVariables.checkBankMemory then
		CheckBankMemory()
	end
end

local function BankManager(eventCode, bagId)
	if bagId ~= BAG_BANK and not RidinDirty.savedVariables.storageManager then return end
	if HasWritQuest() then ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "Auto deposit disabled while writ quests active.") return end--<< CRAFTING WRIT COMPATIBILITY
	local bankCache = SHARED_INVENTORY:GetOrCreateBagCache(bagId)
	local bagCache  = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
	if (RidinDirty.savedVariables.bankManager and bagId == BAG_BANK) or (RidinDirty.savedVariables.storageManager and bagId ~= BAG_BANK) then
		for bankSlot, bankSlotData in pairs(bankCache) do
			local bankStack, bankMaxStack = GetSlotStackSize(bagId, bankSlot)
			if bankStack > 0 and bankStack < bankMaxStack then
				for bagSlot, bagSlotData in pairs(bagCache) do
					if ((bagId == BAG_BANK and not RidinDirty.savedVariables.bankALL) or (bagId ~= BAG_BANK and not RidinDirty.savedVariables.storageAll))
						and (bankSlotData.itemType == ITEMTYPE_FOOD or bankSlotData.itemType == ITEMTYPE_DRINK or bankSlotData.itemType == ITEMTYPE_POTION
						or bankSlotData.itemType == ITEMTYPE_POISON or bankSlotData.itemType == ITEMTYPE_SOUL_GEM or bankSlotData.itemType == ITEMTYPE_TOOL
						or bankSlotData.itemType == ITEMTYPE_AVA_REPAIR or bankSlotData.itemType == ITEMTYPE_RECALL_STONE or bankSlotData.itemType == ITEMTYPE_SIEGE) then break end
					if bankSlotData.rawName == bagSlotData.rawName and not bagSlotData.stolen and not (bagSlotData.itemType == ITEMTYPE_SIEGE and select(23, ZO_LinkHandler_ParseLink(GetItemLink(BAG_BACKPACK, bagSlot, LINK_STYLE_DEFAULT))) ~= "0") then
						local bagStack, bagMaxStack = GetSlotStackSize(BAG_BACKPACK, bagSlot)
						local bagItemLink = GetItemLink(BAG_BACKPACK, bagSlot, LINK_STYLE_DEFAULT)
						local quantity = zo_min(bagStack, bankMaxStack - bankStack)
						if IsProtectedFunction("RequestMoveItem") then
							CallSecureProtected("RequestMoveItem", BAG_BACKPACK, bagSlot, bagId, bankSlot, quantity)
						else
							RequestMoveItem(BAG_BACKPACK, bagSlot, bagId, bankSlot, quantity)
						end
						df(zo_strformat(rdLogo .. "Deposited: [<<1>>/<<2>>] <<t:3>>", quantity, bagStack, bagItemLink))
						local bankStack = bankStack + quantity
						if bankStack == bankMaxStack then
							break
						end
					end
				end
			end
		end
	end
	if IsESOPlusSubscriber() then
		local subBankCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_SUBSCRIBER_BANK)
		local subBagCache  = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
		if (RidinDirty.savedVariables.bankManager and bagId == BAG_BANK) then
			for bankSlot, bankSlotData in pairs(subBankCache) do
				local bankStack, bankMaxStack = GetSlotStackSize(BAG_SUBSCRIBER_BANK, bankSlot)
				if bankStack > 0 and bankStack < bankMaxStack then
					for bagSlot, bagSlotData in pairs(subBagCache) do
						if (bagId == BAG_BANK and not RidinDirty.savedVariables.bankALL)
							and (bankSlotData.itemType == ITEMTYPE_FOOD or bankSlotData.itemType == ITEMTYPE_DRINK or bankSlotData.itemType == ITEMTYPE_POTION
							or bankSlotData.itemType == ITEMTYPE_POISON or bankSlotData.itemType == ITEMTYPE_SOUL_GEM or bankSlotData.itemType == ITEMTYPE_TOOL
							or bankSlotData.itemType == ITEMTYPE_AVA_REPAIR or bankSlotData.itemType == ITEMTYPE_RECALL_STONE or bankSlotData.itemType == ITEMTYPE_SIEGE) then break end
						if bankSlotData.rawName == bagSlotData.rawName and not bagSlotData.stolen and not (bagSlotData.itemType == ITEMTYPE_SIEGE and select(23, ZO_LinkHandler_ParseLink(GetItemLink(BAG_BACKPACK, bagSlot, LINK_STYLE_DEFAULT))) ~= "0") then
							local bagStack, bagMaxStack = GetSlotStackSize(BAG_BACKPACK, bagSlot)
							local bagItemLink = GetItemLink(BAG_BACKPACK, bagSlot, LINK_STYLE_DEFAULT)
							local quantity = zo_min(bagStack, bankMaxStack - bankStack)
							if IsProtectedFunction("RequestMoveItem") then
								CallSecureProtected("RequestMoveItem", BAG_BACKPACK, bagSlot, BAG_SUBSCRIBER_BANK, bankSlot, quantity)
							else
								RequestMoveItem(BAG_BACKPACK, bagSlot, BAG_SUBSCRIBER_BANK, bankSlot, quantity)
							end
							df(zo_strformat(rdLogo .. "Deposited: [<<1>>/<<2>>] <<t:3>>", quantity, bagStack, bagItemLink))
							local bankStack = bankStack + quantity
							if bankStack == bankMaxStack then
								break
							end
						end
					end
				end
			end
		end
	end
	if bagId ~= BAG_BANK then return end
	DepositCurrency(eventCode, bagId)
end
---------------------------------------------
----- WITHDRAW 1 and CUSTOM POPUP MENU --
---------------------------------------------
--local function RidinDirty.CloseGuildBank(eventCode)
	--EVENT_MANAGER:UnregisterForEvent("RidinDirtyWithdrawOne", EVENT_CLOSE_GUILD_BANK)
--end

local function WithdrawReturn(bagId, slotIndex, targetSlot)
	return function(eventCode, _bagId, _slotIndex, isNewItem, itemSoundCategory, updateReason, stackChange)
		if not (targetSlot == _slotIndex) then return end
		EVENT_MANAGER:UnregisterForEvent("RidinDirtyWithdrawOne", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		TransferToGuildBank(bagId, slotIndex)
		--EVENT_MANAGER:RegisterForEvent("RidinDirtyWithdrawOne", EVENT_CLOSE_GUILD_BANK, RidinDirty.CloseGuildBank)
	end
end

local function WithdrawSplit(itemId, quantity, amount)
	return function(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackChange)
		if not (bagId == BAG_BACKPACK) then return end
		local itemLink = GetItemLink(bagId, slotIndex)
		local _itemId = GetItemLinkItemId(itemLink)
		if not (_itemId == itemId) then return end
		local _quantity = GetSlotStackSize(bagId, slotIndex)
		if not (_quantity == quantity) then return end
		EVENT_MANAGER:UnregisterForEvent("RidinDirtyWithdrawOne", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
		EVENT_MANAGER:RegisterForEvent("RidinDirtyWithdrawOne", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, WithdrawReturn(bagId, slotIndex, targetSlot))
		EVENT_MANAGER:AddFilterForEvent("RidinDirtyWithdrawOne", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, targetSlot, amount)
	end
end

local function WithdrawTake(inventorySlot, selectedID, amount)
	local slotType = ZO_InventorySlot_GetType(inventorySlot)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	if not slotIndex then return end
	local itemLink = GetItemLink(bagId, slotIndex)
	local itemId = GetItemLinkItemId(itemLink)
	if not (itemId == selectedID) then return end
	local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
	if not targetSlot then return end
	local quantity = GetSlotStackSize(bagId, slotIndex)
	if (slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_CRAFT_BAG_ITEM or slotType == SLOT_TYPE_FURNITURE_VAULT) then
		for stackIndex = 1, GetBagSize(BAG_BACKPACK) do
			local bagitemId = GetItemId(BAG_BACKPACK, stackIndex)
			local stackAmount, maxStack = GetSlotStackSize(BAG_BACKPACK, stackIndex)
			if itemId == bagitemId and stackAmount < maxStack then
				CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, stackIndex, amount)
				return
			end
		end
		CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, targetSlot, amount)
	elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM then
	    EVENT_MANAGER:RegisterForEvent("RidinDirtyWithdrawOne", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, WithdrawSplit(itemId, quantity, amount))
		EVENT_MANAGER:AddFilterForEvent("RidinDirtyWithdrawOne", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		TransferFromGuildBank(slotIndex)	
	end
end

local function ValidWithdrawContainer(inventorySlot, amount)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	if not (slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM or slotType == SLOT_TYPE_CRAFT_BAG_ITEM or slotType == SLOT_TYPE_FURNITURE_VAULT) then return false end
	if not (GetSlotStackSize(bagId, slotIndex) > amount) then return false end
	if slotType == SLOT_TYPE_GUILD_BANK_ITEM then
		local guildId = GetSelectedGuildBankId()
		if not guildId then return false end
		if not DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT) then
			return false
		elseif not (DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT) and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW)) then
			return false
		end
	end
	if (slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_CRAFT_BAG_ITEM or slotType == SLOT_TYPE_FURNITURE_VAULT) and not CheckInventorySpaceSilently(1) then 
	    return false
	elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM and not CheckInventorySpaceSilently(2) then
	    return false
	end
	return true
end

local function WithdrawMenu(inventorySlot, slotActions)
	if not ValidWithdrawContainer(inventorySlot, 1) then return end
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local itemId = GetItemId(bagId, slotIndex)
	AddCustomMenuItem("Withdraw 1", function() WithdrawTake(inventorySlot, itemId, 1) end)
	if ValidWithdrawContainer(inventorySlot, RidinDirty.savedVariables.withdrawAmount) then
		AddCustomMenuItem(("Withdraw " .. tostring(RidinDirty.savedVariables.withdrawAmount)), function() WithdrawTake(inventorySlot, itemId, RidinDirty.savedVariables.withdrawAmount) end)
	end
end

function RidinDirty.WithdrawOneToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.withdrawOne = toggle
		local primary = LibCustomMenu.CATEGORY_PRIMARY
		LibCustomMenu:RegisterContextMenu(WithdrawMenu, primary)
	else
		RidinDirty.savedVariables.withdrawOne = toggle
		ReloadUI()
	end
end
---------------------------------------------
-------- JUNK MANAGER --
---------------------------------------------
--INVENTORY_UPDATE_REASON_DURABILITY_CHANGE--INVENTORY_UPDATE_REASON_ITEM_CHARGE--ZO_SharedInventoryManager:ClearNewStatus(bagId, slotIndex)
local function JunkManager(eventCode, bagId, slotIndex, isNewItem, soundCategory, updateReason, stackChange, byCharacterName, byDisplayName, isLastUpdate, bonusDropSource)
	if bagId == BAG_WORN and (updateReason == INVENTORY_UPDATE_REASON_DURABILITY_CHANGE or updateReason == INVENTORY_UPDATE_REASON_ITEM_CHARGE) then
		AutoRepCharge(_, bagId, slotIndex, _, _, updateReason)
		return
	end
	if not isNewItem or bagId ~= BAG_BACKPACK then return end
	local itemId = GetItemId(bagId, slotIndex)
	local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
	local itemType, specialType = GetItemType(bagId, slotIndex)
	local itemTrait = GetItemTraitInformation(bagId, slotIndex)
	local itemValue = GetItemSellValueWithBonuses(bagId, slotIndex)
	local isCrafted = (IsItemLinkCrafted(itemLink) and (itemType ~= ITEMTYPE_BLACKSMITHING_MATERIAL and
		itemType ~= ITEMTYPE_CLOTHIER_MATERIAL and itemType ~= ITEMTYPE_WOODWORKING_MATERIAL and
			itemType ~= ITEMTYPE_JEWELRYCRAFTING_MATERIAL and itemType ~= ITEMTYPE_ENCHANTING_RUNE_ASPECT and
				itemType ~= ITEMTYPE_ENCHANTING_RUNE_ESSENCE and itemType ~= ITEMTYPE_ENCHANTING_RUNE_POTENCY))
	local isTrash = (itemType == ITEMTYPE_TRASH or itemTrait == ITEM_TRAIT_INFORMATION_ORNATE or
		(itemType == ITEMTYPE_COLLECTIBLE and specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_MONSTER_TROPHY) or
			(itemType == ITEMTYPE_COLLECTIBLE and specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH) or
				(RidinDirty.savedVariables.junkIntricates and itemTrait == ITEM_TRAIT_INFORMATION_INTRICATE) or
					(RidinDirty.savedVariables.junkTreasures and itemType == ITEMTYPE_TREASURE and itemValue > 0) or
						(RidinDirty.savedVariables.junkStolen and IsItemStolen(bagId, slotIndex)) or
							(RidinDirty.savedVariables.junkMaps and (itemType == ITEMTYPE_TROPHY and specialType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP and not CanItemBeUsedToLearn(bagId, slotIndex))) or
								(RidinDirty.savedVariables.junkKnownScripts and (itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT and IsItemBound(bagId, slotIndex) and not IsKnowledgeUnknown(itemId, itemLink, itemType, specialType))))
	if RidinDirty.savedVariables.destroyLQStolen and IsItemStolen(bagId, slotIndex) and GetItemSellValueWithBonuses(bagId, slotIndex) >= 100 then
		local stolenValue = 0
		for slotIndex = 0, GetBagSize(bagId) do
			if IsItemStolen(bagId, slotIndex) and GetItemSellValueWithBonuses(bagId, slotIndex) >= 100 then
				stolenValue = (stolenValue + (GetItemSellValueWithBonuses(bagId, slotIndex) * GetSlotStackSize(bagId, slotIndex)) * ((GetTotalFenceHagglingBonus() + 100) / 100))
			end
		end
		if stolenValue > 0 then
			df(rdLogo .. "|cFFA2A2*PREMIUM EXPORTS*|r --> " .. "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. ZO_LocalizeDecimalNumber(stolenValue)
				.. " (+" .. (GetItemSellValueWithBonuses(bagId, slotIndex) * ((GetTotalFenceHagglingBonus() + 100) / 100)) .. ")")
		end
	end
	if not IsItemJunk(bagId, slotIndex) and (RidinDirty.junkMemory[itemId] ~= nil or isTrash) and not IsItemPlayerLocked(bagId, slotIndex) then
		if isCrafted then RidinDirty.junkMemory[itemId] = nil return end--<< Cleanup
		if isTrash and not IsItemStolen(bagId, slotIndex) then RidinDirty.junkMemory[itemId] = nil end--<< Cleanup
		if RidinDirty.savedVariables.destroyLQStolen and IsItemStolen(bagId, slotIndex) and GetItemLinkDisplayQuality(itemLink) <= 1 and
			(GetItemSellValueWithBonuses(bagId, slotIndex) < 60 and not InLootWhitelist(itemId)) then
				DestroyItem(bagId, slotIndex)
				if not RidinDirty.savedVariables.junkSilentMode then df(rdLogo .. "|cFFA2A2Destroying|r " .. itemLink) end
		elseif RidinDirty.savedVariables.destroyUnsellable and RidinDirty.junkMemory[itemId] ~= nil and
			GetItemSellInformation(bagId, slotIndex) == ITEM_SELL_INFORMATION_CANNOT_SELL then
				DestroyItem(bagId, slotIndex)
				if not RidinDirty.savedVariables.junkSilentMode then df(rdLogo .. "|cFFA2A2Destroying|r " .. itemLink) end
		else
			SetItemIsJunk(bagId, slotIndex, true)
			if not RidinDirty.savedVariables.junkSilentMode then df(rdLogo .. "Moved " .. itemLink .. " to junk!") end
		end
	end
end

local function MarkPermJunkMenu(inventorySlot, slotActions)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	local itemId = GetItemId(bagId, slotIndex)
	local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
	local itemType, specialType = GetItemType(bagId, slotIndex)
	local itemTrait = GetItemTraitInformation(bagId, slotIndex)
	local itemValue = GetItemSellValueWithBonuses(bagId, slotIndex)
	local isCrafted = (IsItemLinkCrafted(itemLink) and (itemType ~= ITEMTYPE_BLACKSMITHING_MATERIAL and
		itemType ~= ITEMTYPE_CLOTHIER_MATERIAL and itemType ~= ITEMTYPE_WOODWORKING_MATERIAL and
			itemType ~= ITEMTYPE_JEWELRYCRAFTING_MATERIAL and itemType ~= ITEMTYPE_ENCHANTING_RUNE_ASPECT and
				itemType ~= ITEMTYPE_ENCHANTING_RUNE_ESSENCE and itemType ~= ITEMTYPE_ENCHANTING_RUNE_POTENCY))
	local isTrash = (itemType == ITEMTYPE_TRASH or itemTrait == ITEM_TRAIT_INFORMATION_ORNATE or
		(itemType == ITEMTYPE_COLLECTIBLE and specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_MONSTER_TROPHY) or
			(itemType == ITEMTYPE_COLLECTIBLE and specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH) or
				(RidinDirty.savedVariables.junkIntricates and itemTrait == ITEM_TRAIT_INFORMATION_INTRICATE) or
					(RidinDirty.savedVariables.junkTreasures and itemType == ITEMTYPE_TREASURE and itemValue > 0) or
						(RidinDirty.savedVariables.junkStolen and IsItemStolen(bagId, slotIndex)) or
							(RidinDirty.savedVariables.junkMaps and (itemType == ITEMTYPE_TROPHY and specialType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP and not CanItemBeUsedToLearn(bagId, slotIndex))) or
								(RidinDirty.savedVariables.junkKnownScripts and (itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT and IsItemBound(bagId, slotIndex) and not IsKnowledgeUnknown(itemId, itemLink, itemType, specialType))))
	if IsItemJunk(bagId, slotIndex) or IsItemPlayerLocked(bagId, slotIndex) or bagId ~= BAG_BACKPACK or not CanItemBeMarkedAsJunk(bagId, slotIndex) or RidinDirty.junkMemory[itemId] ~= nil or isCrafted or isTrash then return end
	AddCustomMenuItem("Mark Perm Junk", function() RidinDirty.junkMemory[itemId] = itemLink
		SetItemIsJunk(bagId, slotIndex, true) df(rdLogo .. "Added " .. itemLink .. " to junk memory!")
			local junkMemory = RidinDirty.PopulateJunkMemory() RidinDirty.UpdateJunkMemoryList(RidinDirty.JunkMemoryList, junkMemory, 1) end)
end

local function UnMarkPermJunkMenu(inventorySlot, slotActions)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	local itemId = GetItemId(bagId, slotIndex)
	local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
	local itemType, specialType = GetItemType(bagId, slotIndex)
	local itemTrait = GetItemTraitInformation(bagId, slotIndex)
	local itemValue = GetItemSellValueWithBonuses(bagId, slotIndex)
	local isCrafted = (IsItemLinkCrafted(itemLink) and (itemType ~= ITEMTYPE_BLACKSMITHING_MATERIAL and
		itemType ~= ITEMTYPE_CLOTHIER_MATERIAL and itemType ~= ITEMTYPE_WOODWORKING_MATERIAL and
			itemType ~= ITEMTYPE_JEWELRYCRAFTING_MATERIAL and itemType ~= ITEMTYPE_ENCHANTING_RUNE_ASPECT and
				itemType ~= ITEMTYPE_ENCHANTING_RUNE_ESSENCE and itemType ~= ITEMTYPE_ENCHANTING_RUNE_POTENCY))
	local isTrash = (itemType == ITEMTYPE_TRASH or itemTrait == ITEM_TRAIT_INFORMATION_ORNATE or
		(itemType == ITEMTYPE_COLLECTIBLE and specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_MONSTER_TROPHY) or
			(itemType == ITEMTYPE_COLLECTIBLE and specialType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH) or
				(RidinDirty.savedVariables.junkIntricates and itemTrait == ITEM_TRAIT_INFORMATION_INTRICATE) or
					(RidinDirty.savedVariables.junkTreasures and itemType == ITEMTYPE_TREASURE and itemValue > 0) or
						(RidinDirty.savedVariables.junkStolen and IsItemStolen(bagId, slotIndex)) or
							(RidinDirty.savedVariables.junkMaps and (itemType == ITEMTYPE_TROPHY and specialType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP and not CanItemBeUsedToLearn(bagId, slotIndex))) or
								(RidinDirty.savedVariables.junkKnownScripts and (itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT and IsItemBound(bagId, slotIndex) and not IsKnowledgeUnknown(itemId, itemLink, itemType, specialType))))
	if not IsItemJunk(bagId, slotIndex) or bagId ~= BAG_BACKPACK or RidinDirty.junkMemory[itemId] == nil or isCrafted or isTrash then return end
	AddCustomMenuItem("UnMark Perm Junk", function() RidinDirty.junkMemory[itemId] = nil
		SetItemIsJunk(bagId, slotIndex, false) df(rdLogo .. "Removed " .. itemLink .. " from junk memory!")
			local junkMemory = RidinDirty.PopulateJunkMemory() RidinDirty.UpdateJunkMemoryList(RidinDirty.JunkMemoryList, junkMemory, 1) end)
end

function RidinDirty.ClearJunkMemory()
	ZO_ClearTable(RidinDirty.savedVariables["Junk Memory"])
	RidinDirty.junkMemory["version"] = 1
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "Junk memory cleared.")
end

function RidinDirty.PopulateJunkMemory()
	local junkMemory = {}
	local counter = 0
	for i, v in pairs(RidinDirty.savedVariables["Junk Memory"]) do
		if i ~= nil and i ~= "version" then
			counter = counter + 1
			junkMemory[counter] = {
				index = i,
				itemLink = v,
				name = GetItemLinkName(v),
			}
		end
	end
	return junkMemory
end

function RidinDirty.UpdateJunkMemoryList(control, data, rowType)
	local dataCopy = ZO_DeepTableCopy(data)
	local dataList = ZO_ScrollList_GetDataList(control)
	ZO_ScrollList_Clear(control)
	for key, value in ipairs(dataCopy) do
		local entry = ZO_ScrollList_CreateDataEntry(rowType, value)
		table.insert(dataList, entry)
	end
	table.sort(dataList, function(a,b) return a.data.name < b.data.name end)
	ZO_ScrollList_Commit(control)
end

function RidinDirty.JunkMemoryLayoutRow(rowControl, data, scrollList)
	rowControl:SetFont("ZoFontWinH4")
	rowControl:SetMaxLineCount(1)
	rowControl:SetText(data.itemLink)
	rowControl:SetHandler("OnMouseUp", function(control, button, upInside)
		local itemData = control.dataEntry and control.dataEntry.data
		local itemLink = itemData.itemLink
		local itemId = GetItemLinkItemId(itemLink)
		if button == 2 and upInside then
			ClearMenu()
			--AddMenuItem("Link in Chat", function()
				--CHAT_SYSTEM:Maximize()
				--CHAT_SYSTEM.textEntry:GetEditControl():InsertText(itemLink)
			--end)
			AddMenuItem("Unmark Perm Junk", function()
				local dataList = ZO_ScrollList_GetDataList(control)
				RidinDirty.junkMemory[itemId] = nil
				local junkMemory = RidinDirty.PopulateJunkMemory()
				RidinDirty.UpdateJunkMemoryList(RidinDirty.JunkMemoryList, junkMemory, 1)
				for slotIndex = 0, GetBagSize(BAG_BACKPACK) do
					if itemId == GetItemId(BAG_BACKPACK, slotIndex) then
						SetItemIsJunk(BAG_BACKPACK, slotIndex, false)
					end
				end
			end)
			ShowMenu(rowControl)
		end
	end)
end

local function ChatLinkUnMarkMenu(itemLink, button, _, _, linkType, ...)--<< UNUSED
	local itemId = GetItemLinkItemId(itemLink)
	local itemType, specialType = GetItemLinkItemType(itemLink)
	if button == MOUSE_BUTTON_INDEX_RIGHT and linkType == ITEM_LINK_TYPE and RidinDirty.junkMemory[itemId] ~= nil then
		zo_callLater(function()
			AddCustomMenuItem("UnMark Perm Junk", function() RidinDirty.junkMemory[itemId] = nil
			for slotIndex = 1, GetBagSize(BAG_BACKPACK) do
				local bagitemId = GetItemId(BAG_BACKPACK, slotIndex)
				if IsItemJunk(BAG_BACKPACK, slotIndex) and bagitemId == itemId then
					SetItemIsJunk(BAG_BACKPACK, slotIndex, false)
				end
			end
			df(rdLogo .. "Removed " .. itemLink .. " from junk list!")
			end, MENU_ADD_OPTION_LABEL)
			ShowMenu()
		end, hookDelay)
	end
end

local function AutoSellRepair()
	local junkValue = 0
	if HasAnyJunk(BAG_BACKPACK, true) then
		for slotIndex = 1, GetNumBagUsedSlots(BAG_BACKPACK) do
			if IsItemJunk(BAG_BACKPACK, slotIndex) and not IsItemStolen(BAG_BACKPACK, slotIndex) then
				junkValue = junkValue + (GetItemSellValueWithBonuses(BAG_BACKPACK, slotIndex) * GetSlotStackSize(BAG_BACKPACK, slotIndex))
			end
		end
		if junkValue > 0 then
			df(rdLogo .. "All junk sold for " .. "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. ZO_LocalizeDecimalNumber(junkValue))
		end
		SellAllJunk()
	end
	local repairCost = GetRepairAllCost()
	if not CanStoreRepair() then return end
	if repairCost > 0 and repairCost < GetCurrentMoney() then
		df(rdLogo .. "All items repaired for " .. "|t18:18:/esoui/art/currency/currency_gold.dds|t" .. ZO_LocalizeDecimalNumber(repairCost))
		RepairAll()
	elseif repairCost > 0 and repairCost > GetCurrentMoney() then
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "Insufficient gold for repairs.")
	end
end

function RidinDirty.JunkManagerToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.junkManager = toggle
		local tertiary = LibCustomMenu.CATEGORY_TERTIARY
		LibCustomMenu:RegisterContextMenu(MarkPermJunkMenu, tertiary)
		LibCustomMenu:RegisterContextMenu(UnMarkPermJunkMenu, tertiary)
		--LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, ChatLinkUnMarkMenu)
		EVENT_MANAGER:RegisterForEvent("RidinDirtyJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, JunkManager)
		--EVENT_MANAGER:AddFilterForEvent("RidinDirtyJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		EVENT_MANAGER:RegisterForEvent("RidinDirtyJunk", EVENT_OPEN_STORE, AutoSellRepair)
	else
		RidinDirty.savedVariables.junkManager = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirtyJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent("RidinDirtyJunk", EVENT_OPEN_STORE)
		ReloadUI()
	end
end
---------------------------------------------
------ LOOT MANAGER AND PRICING --
---------------------------------------------
local function LootManager(eventCode, receivedBy, itemLink, quantity, _, lootType, isSelf, isPickpocket, questItemIcon, itemId, isStolen)
	local itemType, specialType = GetItemLinkItemType(itemLink)
	local _, _, _, equipType, itemStyleId = GetItemLinkInfo(itemLink)
	local leadHeader = ""
	local needHeader = ""
	if (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON) and not (GetItemLinkSetInfo(itemLink, false) or GetItemStyleName(itemStyleId) == (nil or "")) then return end
	if IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) then needHeader = IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) end
	if (GetItemLinkDisplayQuality(itemLink) >= RidinDirty.savedVariables.lootQuality and itemType ~= ITEMTYPE_TRASH and itemType ~= ITEMTYPE_TREASURE and itemType ~= ITEMTYPE_SOUL_GEM)--(itemType == ITEMTYPE_TREASURE and isStolen)
	or (lootType == LOOT_TYPE_ANTIQUITY_LEAD) or (InLootWhitelist(itemId)) or needHeader ~= "" then
		local traitType, traitDesc = GetItemLinkTraitInfo(itemLink)
		local traitName = ""
		if lootType == LOOT_TYPE_ANTIQUITY_LEAD then leadHeader = "LEAD: " end
		if traitType ~= 0 then traitName = (" |cC0C0C0[" .. string.lower(GetString("SI_ITEMTRAITTYPE", traitType)) .. "]|r") end
		if quantity > 1 then quantity = (" x" .. quantity) else quantity = "" end
		if isSelf then receivedBy = "" else receivedBy = (" --> " .. ZO_LinkHandler_CreatePlayerLink(zo_strformat("<<1>>", receivedBy))) end
		df(zo_strformat(rdLogo .. leadHeader .. needHeader .. itemLink .. traitName .. quantity .. receivedBy))
	end
end

function RidinDirty.lootManagerToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.lootManager = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_LOOT_RECEIVED, LootManager)
		ZO_PostHook(ItemTooltip, "SetStoreItem", TooltipLeadInfo)
		ZO_PostHook(ItemTooltip, "SetLootItem", TooltipLeadInfo)
		--ZO_PostHook(ItemTooltip, "SetBagItem", function(control, bagId, slotIndex)
			--ZO_Tooltip_AddDivider(ItemTooltip)
		--end)
		for _, i in pairs(PLAYER_INVENTORY.inventories) do
			local ListView = i.listView
			if ListView and ListView.dataTypes and ListView.dataTypes[1] and ListView:GetName() ~= "ZO_PlayerInventoryQuest" then
				local DataType = ListView.dataTypes[1]
				SecurePostHook(DataType, 'setupCallback', function(control, slot)
					if SCENE_MANAGER:GetCurrentScene() ~= STABLES_SCENE then
						NeedsAndPrice(control, slot)
					end
				end)
			end
		end
		--deconstruction (assistant)
		SecurePostHook(ZO_UniversalDeconstructionTopLevel_KeyboardPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--deconstruction (crafting stations)
		SecurePostHook(ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--refinement (crafting stations)
		SecurePostHook(ZO_SmithingTopLevelRefinementPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--improvement (crafting stations)
		SecurePostHook(ZO_SmithingTopLevelImprovementPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--enchanting (crafting stations)
		SecurePostHook(ZO_EnchantingTopLevelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--loot window
		SecurePostHook(ZO_LootAlphaContainerList.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		EVENT_MANAGER:RegisterForEvent("RidinDirtyLoot", EVENT_COLLECTION_UPDATED, RefreshStore)
		SecurePostHook(ZO_StoreManager, "SetUpBuySlot", function(self, control, slot)
			NeedsAndPrice(control, slot)
		end)
		SecurePostHook(TRADING_HOUSE, "OpenTradingHouse", function()
			if RidinDirty.savedVariables.traderEnhance then
				zo_callLater(function() if TRADING_HOUSE_SEARCH:CanDoCommonOperation() then TRADING_HOUSE_SEARCH:DoSearch() end end, searchDelay)
			end
			if not traderMods then
				traderMods = true
				local oldSearch = ZO_ScrollList_GetDataTypeTable(ZO_TradingHouseBrowseItemsRightPaneSearchResults, 1).setupCallback
				local oldListing = ZO_ScrollList_GetDataTypeTable(ZO_TradingHousePostedItemsList, 2).setupCallback
					ZO_ScrollList_GetDataTypeTable(ZO_TradingHouseBrowseItemsRightPaneSearchResults, 1).setupCallback = function(control, slot)
						oldSearch(control, slot) NeedsAndPrice(control, slot) end
					ZO_ScrollList_GetDataTypeTable(ZO_TradingHousePostedItemsList, 2).setupCallback = function(control, slot)
						oldListing(control, slot) NeedsAndPrice(control, slot) end
			end
		end)
		ReloadUI()
	else
		RidinDirty.savedVariables.lootManager = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_LOOT_RECEIVED)
		ReloadUI()
	end
end
---------------------------------------------
-------- TRADER ENHANCE --
---------------------------------------------
--ZO_MenuBar_SelectDescriptor(TRADING_HOUSE.menuBar, ZO_TRADING_HOUSE_MODE_BROWSE, true, true)
--CanSellOnTradingHouse(guildId)--HasTradingHouseListings()--ZO_TRADING_HOUSE_MODE_BROWSE--ZO_TRADING_HOUSE_MODE_SELL--ZO_TRADING_HOUSE_MODE_LISTINGS
--GetChatterOptionCount() do
local function TraderChatter(eventCode, optionCount, debugSource)
	for i = 1, optionCount do
		local _, choice = GetChatterOption(i)
		if i == 1 and choice == CHATTER_START_TRADINGHOUSE then
			SelectChatterOption(i)
		end
	end
end

function RidinDirty.CycleTradingGuilds()
	if SCENE_MANAGER:GetCurrentScene() == TRADING_HOUSE_SCENE and GetNumTradingHouseGuilds() > 1 then
		local currentId = GetSelectedTradingHouseGuildId()
		local numGuilds = GetNumTradingHouseGuilds()
		local nextIndex = 1
		for i = 1, numGuilds do
			local guildId = GetTradingHouseGuildDetails(i)
			if guildId == currentId then
				nextIndex = (i % numGuilds) + 1
				break
			end
		end
		local nextGuildId = GetTradingHouseGuildDetails(nextIndex)
		SelectTradingHouseGuildId(nextGuildId)
		if not CanSellOnTradingHouse(GetCurrentTradingHouseGuildDetails()) and not HasTradingHouseListings() then RidinDirty.CycleTradingGuilds() return end
		if TRADING_HOUSE:GetCurrentMode() == ZO_TRADING_HOUSE_MODE_BROWSE then
			zo_callLater(function() if TRADING_HOUSE_SEARCH:CanDoCommonOperation() then TRADING_HOUSE_SEARCH:DoSearch() end end, searchDelay)
		end
	end
end

function RidinDirty.TraderEnhanceToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.traderEnhance = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_CHATTER_BEGIN, TraderChatter)
		ZO_TradingHouseTitleLabel:SetMouseEnabled(true)
		ZO_TradingHouseTitleLabel:SetHandler("OnMouseUp", function(self, mouseButton, upInside)
			if upInside then
				PlaySound("Click")
				RidinDirty.CycleTradingGuilds()
			end
		end)
		ZO_TradingHouseTitleLabel:SetHandler("OnMouseEnter", function(self)
			InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
			SetTooltipText(InformationTooltip, "CLICK TO CYCLE TRADING GUILDS")
		end)
		ZO_TradingHouseTitleLabel:SetHandler("OnMouseExit", function(self)
			ClearTooltip(InformationTooltip)
		end)
		SecurePostHook(TRADING_HOUSE, "UpdateForGuildChange", function()
			local count, countmax = GetTradingHouseListingCounts()
			RidinDirty.ListingCounter.label:SetText ("Listings " .. tostring(count) .. " of " .. tostring(countmax))
		end)
		SecurePostHook(TRADING_HOUSE, "OnResponseReceived", function(responseType, result)
			if result == TRADING_HOUSE_RESULT_POST_PENDING or result == TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING then
				local count, countmax = GetTradingHouseListingCounts()
				RidinDirty.ListingCounter.label:SetText ("Listings " .. tostring(count) .. " of " .. tostring(countmax))
			end
		end)
		if not RidinDirty.savedVariables.lootManager then
			SecurePostHook(TRADING_HOUSE, "OpenTradingHouse", function()
				zo_callLater(function() if TRADING_HOUSE_SEARCH:CanDoCommonOperation() then TRADING_HOUSE_SEARCH:DoSearch() end end, searchDelay)
			end)
		end
	else
		RidinDirty.savedVariables.traderEnhance = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_CHATTER_BEGIN)
		ReloadUI()
	end
end
---------------------------------------------
-------- AP, VET & TELVAR LOG TO CHAT --
---------------------------------------------
local function OutputAVPData()
	local dataReady = avpData.allianceGained > RidinDirty.savedVariables.minimumAVT or
		avpData.telvarDifference > RidinDirty.savedVariables.minimumAVT or avpData.telvarDifference < -RidinDirty.savedVariables.minimumAVT or
			avpData.veterancyGained > RidinDirty.savedVariables.minimumAVT
	local formattedText = ""
	local tickReason = "Gained: "
	if dataReady and avpData.allianceGained ~= 0 then
		if TICK_REASON and REASON_INFO and TICK_REASON == CURRENCY_CHANGE_REASON_OFFENSIVE_KEEP_REWARD then
			tickReason = (GetKeepName(REASON_INFO) .. " Capture: ")
		elseif TICK_REASON and REASON_INFO and TICK_REASON == CURRENCY_CHANGE_REASON_DEFENSIVE_KEEP_REWARD then
			tickReason = (GetKeepName(REASON_INFO) .. " Defence: ")
		elseif TICK_REASON and REASON_INFO and TICK_REASON == CURRENCY_CHANGE_REASON_KEEP_REPAIR then
			tickReason = (GetKeepName(REASON_INFO) .. " Repair: ")
		end
		tickReason = tickReason:gsub("Castle ", ""):gsub("Fort ", ""):gsub(" Keep", ""):gsub(" Outpost", ""):gsub(" District", "")
		formattedText = tostring(rdLogo .. tickReason .. apIcon .. "|c339933" .. ZO_LocalizeDecimalNumber(avpData.allianceGained) .. "|r")
	end
	if dataReady and avpData.telvarDifference ~= 0 then
		if formattedText == "" then
			if avpData.telvarDifference > 0 then
				formattedText = tostring(rdLogo .. tickReason .. telvarIcon .. "|c33CCCC" .. ZO_LocalizeDecimalNumber(avpData.telvarDifference) .. " [" .. ZO_LocalizeDecimalNumber(GetCarriedCurrencyAmount(CURT_TELVAR_STONES)) .. "]|r")
			else
				formattedText = tostring(rdLogo .. tickReason .. telvarIcon .. "|ccc0000" .. ZO_LocalizeDecimalNumber(avpData.telvarDifference) .. " [" .. ZO_LocalizeDecimalNumber(GetCarriedCurrencyAmount(CURT_TELVAR_STONES)) .. "]|r")
			end
		else
			if avpData.telvarDifference > 0 then
				formattedText = tostring(formattedText .. " " .. telvarIcon .. "|c33CCCC" .. ZO_LocalizeDecimalNumber(avpData.telvarDifference) .. " [" .. ZO_LocalizeDecimalNumber(GetCarriedCurrencyAmount(CURT_TELVAR_STONES)) .. "]|r")
			else
				formattedText = tostring(formattedText .. " " .. telvarIcon .. "|ccc0000" .. ZO_LocalizeDecimalNumber(avpData.telvarDifference) .. " [" .. ZO_LocalizeDecimalNumber(GetCarriedCurrencyAmount(CURT_TELVAR_STONES)) .. "]|r")
			end
		end
	end
	if dataReady and avpData.veterancyGained ~= 0 then
		local trackType = REWARD_TRACK_TYPE_AVA_VETERANCY
		local _, currTierIndex, currProgress = GetInfoForRewardTrack(trackType, GetActiveReferenceTrackIdsForRewardTrackType(trackType))
		local rewardTrackId = GetRewardTrackIdFromReferenceTrackId(trackType, GetActiveReferenceTrackIdsForRewardTrackType(trackType))
		local totalNeeded = GetTotalProgressAtRewardTrackTier(rewardTrackId, currTierIndex)
		local percent = (currProgress / totalNeeded) * 100
		if formattedText == "" then
			if percent > 100 then percent = percent - (math.floor(percent / 100) * 100) end
			formattedText = tostring(rdLogo .. tickReason .. veterancyIcon .. "|cC0C0C0" .. zo_roundToNearest(percent, 0.01) .. "%%|r")
		else
			if percent > 100 then percent = percent - (math.floor(percent / 100) * 100) end
			formattedText = tostring(formattedText .. " " .. veterancyIcon .. "|cC0C0C0" .. zo_roundToNearest(percent, 0.01) .. "%%|r")
		end
	end
	if formattedText ~= "" then
		if TICK_REASON and (TICK_REASON == CURRENCY_CHANGE_REASON_OFFENSIVE_KEEP_REWARD or TICK_REASON == CURRENCY_CHANGE_REASON_DEFENSIVE_KEEP_REWARD) then
			PlaySound("Duel_Accepted")
		else
			PlaySound("AlliancePoint_Transact")
		end
		avpData.allianceGained = 0
		avpData.telvarDifference = 0
		avpData.veterancyGained = 0
		TICK_REASON = nil
		REASON_INFO = nil
		df(tostring(formattedText))
		avpProcessing = false
	else
		avpData.allianceGained = 0
		avpData.telvarDifference = 0
		avpData.veterancyGained = 0
		TICK_REASON = nil
		REASON_INFO = nil
		avpProcessing = false
	end
end
--ZO_ClearTable(avpData)--avpData.veterancyGained % totalNeeded == 0-----if percent > 100 then percent = percent - (math.floor(percent / 100) * 100) end
local function CollectAVPData(allianceGained, telvarDifference, veterancyGained)
	if allianceGained then
		avpData.allianceGained = avpData.allianceGained + allianceGained
	end
	if telvarDifference then
		avpData.telvarDifference = avpData.telvarDifference + telvarDifference
	end
	if veterancyGained then
		avpData.veterancyGained = avpData.veterancyGained + veterancyGained
	end
	if not avpProcessing then
        avpProcessing = true
		zo_callLater(function() OutputAVPData() end, RidinDirty.savedVariables.bombSensitivity)
    end
end

local function ApLog(eventCode, _, _, currencyAmount, changeReason, reasonInfo)
	if changeReason ~= CURRENCY_CHANGE_REASON_BANK_DEPOSIT and changeReason ~= CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL and changeReason ~= CURRENCY_CHANGE_REASON_VENDOR then
		if changeReason == CURRENCY_CHANGE_REASON_OFFENSIVE_KEEP_REWARD then
			TICK_REASON = CURRENCY_CHANGE_REASON_OFFENSIVE_KEEP_REWARD
			REASON_INFO = reasonInfo
		elseif changeReason == CURRENCY_CHANGE_REASON_DEFENSIVE_KEEP_REWARD then
			TICK_REASON = CURRENCY_CHANGE_REASON_DEFENSIVE_KEEP_REWARD
			REASON_INFO = reasonInfo
		elseif changeReason == CURRENCY_CHANGE_REASON_KEEP_REPAIR and not TICK_REASON then
			TICK_REASON = CURRENCY_CHANGE_REASON_KEEP_REPAIR
			REASON_INFO = reasonInfo
		end
		CollectAVPData(currencyAmount, nil, nil)
	end
end

local function TelvarLog(eventCode, newStones, oldStones, updateReason)
	if updateReason ~= CURRENCY_CHANGE_REASON_PVP_KILL_TRANSFER and updateReason ~= CURRENCY_CHANGE_REASON_LOOT and
		updateReason ~= CURRENCY_CHANGE_REASON_LOOT_CURRENCY_CONTAINER and updateReason ~= CURRENCY_CHANGE_REASON_DEATH then return end
	local difference = newStones - oldStones
	CollectAVPData(nil, difference, nil)
end

local function VetLog(eventCode, trackType, trackId, prevTierIndex, tierIndex, newProgress)
	if trackType ~= REWARD_TRACK_TYPE_AVA_VETERANCY then return end
	local rewardTrackId = GetRewardTrackIdFromReferenceTrackId(REWARD_TRACK_TYPE_AVA_VETERANCY, GetActiveReferenceTrackIdsForRewardTrackType(REWARD_TRACK_TYPE_AVA_VETERANCY))
	local totalNeeded = GetTotalProgressAtRewardTrackTier(rewardTrackId, tierIndex)
	local veterancyGained = newProgress - RidinDirty.charVariables.veterancyProgress
	if veterancyGained < 0 then
		local totalPrevNeeded = GetTotalProgressAtRewardTrackTier(rewardTrackId, prevTierIndex)
		veterancyGained = newProgress + (totalPrevNeeded - RidinDirty.charVariables.veterancyProgress)
	end
	RidinDirty.charVariables.veterancyProgress = newProgress
	CollectAVPData(nil, nil, veterancyGained)
end

function RidinDirty.AVTLogToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.avtLog = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_ALLIANCE_POINT_UPDATE, ApLog)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_REWARD_TRACK_PROGRESS_GAINED, VetLog)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_TELVAR_STONE_UPDATE, TelvarLog)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_PENDING_CURRENCY_REWARD_CACHED, ApLog)
	else
		RidinDirty.savedVariables.avtLog = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_PENDING_CURRENCY_REWARD_CACHED)
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_ALLIANCE_POINT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_REWARD_TRACK_PROGRESS_GAINED)
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_TELVAR_STONE_UPDATE)
	end
end
---------------------------------------------
--------- PVP PERSONAL / GROUP KILL FEED ----GetDate() = "20231009"--GetTimeString() >= "06:00:00"
---------------------------------------------
local function PvpKillFeed(eventCode, killLocation, killerDisplayName, killerCharacterName, killerAlliance, killerRank, victomDisplayName, victomCharacterName, victomAlliance, victomRank, isKillLocation)
	if (GetUnitDisplayName('player') == killerDisplayName or IsPlayerInGroup(killerDisplayName)) and not isKillLocation then
		if GetUnitDisplayName('player') == killerDisplayName then RidinDirty.savedVariables.pvpKills = (RidinDirty.savedVariables.pvpKills + 1) end
		PlaySound("Ability_Companion_Ultimate_Ready_Sound")
		if GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_PVP_KILL_FEED_NOTIFICATIONS) then return end
		if not ZO_ShouldPreferUserId() then
			victomCharacterName = zo_strformat("<<1>>", victomCharacterName)--<< Strip gemders
			killerCharacterName = zo_strformat("<<1>>", killerCharacterName)--<< Strip gemders
			if GetUnitDisplayName('player') == killerDisplayName then
				df(rdLogo .. " |cCC6600You killed " .. tostring(victomCharacterName) .. " [K-" .. tostring(RidinDirty.savedVariables.pvpKills) .. " / D-" .. tostring(RidinDirty.savedVariables.pvpDeaths) .. " / " .. tostring(zo_round((RidinDirty.savedVariables.pvpKills / math.max(1, RidinDirty.savedVariables.pvpDeaths)) * 100)) .. "%%]|r")
			else
				df(rdLogo .. " |cCC6600" .. killerCharacterName .. " killed " .. tostring(victomCharacterName) .. "|r")
			end
		else
			if GetUnitDisplayName('player') == killerDisplayName then
				df(rdLogo .. " |cCC6600You killed " .. tostring(victomDisplayName) .. " [K-" .. tostring(RidinDirty.savedVariables.pvpKills) .. " / D-" .. tostring(RidinDirty.savedVariables.pvpDeaths) .. " / " .. tostring(zo_round((RidinDirty.savedVariables.pvpKills / math.max(1, RidinDirty.savedVariables.pvpDeaths)) * 100)) .. "%%]|r")
			else
				df(rdLogo .. " |cCC6600" .. killerDisplayName .. " killed " .. tostring(victomDisplayName) .. "|r")
			end
		end
	elseif (GetUnitDisplayName('player') == victomDisplayName or IsPlayerInGroup(victomDisplayName)) and not isKillLocation then
		if GetUnitDisplayName('player') == victomDisplayName then RidinDirty.savedVariables.pvpDeaths = (RidinDirty.savedVariables.pvpDeaths + 1) end
		if GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_PVP_KILL_FEED_NOTIFICATIONS) then return end
		if not ZO_ShouldPreferUserId() then
			killerCharacterName = zo_strformat("<<1>>", killerCharacterName)--<< Strip genders
			victomCharacterName = zo_strformat("<<1>>", victomCharacterName)--<< Strip genders
			if GetUnitDisplayName('player') == victomDisplayName then
				df(rdLogo .. "|cCC6600Killed by " .. tostring(killerCharacterName) .. " [K-" .. tostring(RidinDirty.savedVariables.pvpKills) .. " / D-" .. tostring(RidinDirty.savedVariables.pvpDeaths) .. "]|r")
			else
				df(rdLogo .. "|cCC6600" .. victomCharacterName .. " killed by " .. tostring(killerCharacterName) .. "|r")
			end
		else
			if GetUnitDisplayName('player') == victomDisplayName then
				df(rdLogo .. "|cCC6600Killed by " .. tostring(killerDisplayName) .. " [K-" .. tostring(RidinDirty.savedVariables.pvpKills) .. " / D-" .. tostring(RidinDirty.savedVariables.pvpDeaths) .. "]|r")
			else
				df(rdLogo .. "|cCC6600" .. victomDisplayName .. " killed by " .. tostring(killerDisplayName) .. "|r")
			end
		end
	end
end

function RidinDirty.SetClearKillFeed(isSetting)
	if isSetting then
		--PlaySound("Click")
		local time = os.time()
		local t = os.date("*t", time)
		local resetTime = os.time({year = t.year, month = t.month, day = t.day, hour = t.hour, min = 0, sec = 0})
		RidinDirty.savedVariables.pvpKillsReset = resetTime
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("PvP Kill Feed cleared and set to " .. tostring(os.date("%H:%M:%S", resetTime)) .. " daily."))
	else
		local ONE_DAY = 86400
		local time = os.time()
		local lastReset = RidinDirty.savedVariables.pvpKillsReset
		--local r = os.date("!*t", lastReset)
		--local t = os.date("!*t", time)
		local diff_secs = os.difftime(time, lastReset)
		local diff_days = diff_secs / ONE_DAY
		local whole_days = math.floor(diff_days)
		local wholedays_secs = whole_days * ONE_DAY
		RidinDirty.savedVariables.pvpKillsReset = RidinDirty.savedVariables.pvpKillsReset + wholedays_secs
		zo_callLater(function() df(rdLogo .. "|cCC6600PvP Kill Feed *DAILY RESET*|r") end, 7000)
	end
	RidinDirty.savedVariables.pvpKills = 0
	RidinDirty.savedVariables.pvpDeaths = 0
end

function RidinDirty.ResetKillFeed()
	RidinDirty.savedVariables.pvpKillsReset = GetLastDailyReset()
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("PvP Kill Feed reset to default " .. tostring(os.date("%H:%M:%S", RidinDirty.savedVariables.pvpKillsReset)) .. " daily."))
end

function RidinDirty.PvpKillFeedToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.pvpKillFeed = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_PVP_KILL_FEED_DEATH, PvpKillFeed)
	else
		RidinDirty.savedVariables.pvpKillFeed = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_PVP_KILL_FEED_DEATH)
	end
end
---------------------------------------------
-------- NAMEPLATE FONT BOOST --
---------------------------------------------
function RidinDirty.NamePlatesToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.fontBoost = toggle
		SetNameplateKeyboardFont(string.format("%s|%d", "$(BOLD_FONT)", RidinDirty.savedVariables.fontBoost), FONT_STYLE_SOFT_SHADOW_THIN)
	else
		RidinDirty.savedVariables.fontBoost = toggle
		SetNameplateKeyboardFont(string.format("%s|%d", "$(BOLD_FONT)", "20"), FONT_STYLE_SOFT_SHADOW_THIN)
	end
end
---------------------------------------------
--------- LOCK ARMORY SAVE BUILD --
---------------------------------------------
function RidinDirty.ArmoryUnlock()
	local armoryScene = SCENE_MANAGER:GetScene("armoryKeyboard")
	if RidinDirty.savedVariables.lockArmory and armoryScene:GetState() == SCENE_SHOWN then
		if not ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled then
			PlaySound("Click")
			SCENE_MANAGER:Show("hud")
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "Armory save temporarily enabled.")
			ARMORY_KEYBOARD.keybindStripDescriptor[2].name = ("Save Build")
			ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled = true
			RidinDirty.ArmoryLock:SetText("|t32:32:ESOUI/art/miscellaneous/unlocked_down.dds|t")
			RidinDirty.ArmoryLock:SetHandler("OnMouseEnter", function(self)
				InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
				SetTooltipText(InformationTooltip, "CLICK TO LOCK")
			end)
			RidinDirty.ArmoryLock:SetHandler("OnMouseExit", function(self)
				ClearTooltip(InformationTooltip)
			end)
		else
			PlaySound("Click")
			SCENE_MANAGER:Show("hud")
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "Armory save build locked.")
			ARMORY_KEYBOARD.keybindStripDescriptor[2].name = ("Save Locked")
			ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled = false
			RidinDirty.ArmoryLock:SetText("|t32:32:ESOUI/art/miscellaneous/locked_up.dds|t")
			RidinDirty.ArmoryLock:SetHandler("OnMouseEnter", function(self)
				InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
				SetTooltipText(InformationTooltip, "CLICK TO UNLOCK")
			end)
			RidinDirty.ArmoryLock:SetHandler("OnMouseExit", function(self)
				ClearTooltip(InformationTooltip)
			end)
		end
	end
end

function RidinDirty.LockArmoryToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.lockArmory = toggle
		ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled = false
		ARMORY_KEYBOARD.keybindStripDescriptor[2].name = ("Save Locked")
		RidinDirty.ArmoryLock:SetText("|t32:32:ESOUI/art/miscellaneous/locked_up.dds|t")
		RidinDirty.ArmoryLock:SetMouseEnabled(true)
		RidinDirty.ArmoryLock:SetAlpha(1)
	else
		RidinDirty.savedVariables.lockArmory = toggle
		ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled = true
		RidinDirty.ArmoryLock:SetText("")
		RidinDirty.ArmoryLock:SetMouseEnabled(false)
		RidinDirty.ArmoryLock:SetAlpha(0)
	end
end
---------------------------------------------
--------- STACK ATTRIBUTE BARS --
---------------------------------------------
function RidinDirty.StackAttributesToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.stackAttributes = toggle
		ZO_PlayerAttributeHealth:SetAnchor(TOP, ZO_BuffDebuffTopLevelSelfContainer, BOTTOM, 0, 24)
		ZO_PlayerAttributeMagicka:SetAnchor(TOPRIGHT, ZO_PlayerAttributeHealth, BOTTOM, 0, 8)
		ZO_PlayerAttributeStamina:SetAnchor(TOPLEFT, ZO_PlayerAttributeHealth, BOTTOM, 0, 8)
	else
		RidinDirty.savedVariables.stackAttributes = toggle
		ReloadUI()
	end
end
---------------------------------------------------------
-------- CHAT NOTIFICATIONS --
---------------------------------------------------------
--or IsFriend(fromDisplayName)
local function ChatNotify(eventId, channelType, fromName, chatText, isCustomerService, fromDisplayName)
	if (channelType == CHAT_CHANNEL_WHISPER or channelType == CHAT_CHANNEL_PARTY or channelType == CHAT_CHANNEL_YELL) and fromDisplayName ~= GetUnitDisplayName("player") then
		PlaySound(RidinDirty.savedVariables.chatNotify)
	end
end

function RidinDirty.FSC(eventCode, displayName, charName, oldStatus, newStatus)
	if displayName == GetUnitDisplayName("player") or displayName ~= RidinDirty.savedVariables.savedPlayer or GetTimeStamp() == chatStamp then return end
	local guildId = nil
	local zoneName = RidinDirty.GetFriendZone(charName)
	RidinDirty.GSC(eventCode, guildId, displayName, oldStatus, newStatus, charName, zoneName)
end

function RidinDirty.GetFriendZone(characterName)
	for friendIndex = 1, GetNumFriends() do
		local hasCharacter, charName, zoneName, classType, alliance, level, championRank, zoneId, consoleId = GetFriendCharacterInfo(friendIndex)
		if charName == characterName then
			return zoneName
		end
	end
end

function RidinDirty.GSC(eventCode, guildId, displayName, oldStatus, newStatus, charName, zoneName)
	if displayName == GetUnitDisplayName("player") or displayName ~= RidinDirty.savedVariables.savedPlayer or IsIgnored(displayName) or GetTimeStamp() == chatStamp then return end
	local displayNamePref = nil
	if guildId ~= nil then _, charName, zoneName = GetGuildMemberCharacterInfo(guildId, GetGuildMemberIndexFromDisplayName(guildId, displayName)) end
	if not ZO_ShouldPreferUserId() then displayNamePref = charName else displayNamePref = displayName end
	local displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
	chatStamp = GetTimeStamp()
	if not IsFriend(displayName) and newStatus ~= PLAYER_STATUS_OFFLINE and oldStatus == PLAYER_STATUS_OFFLINE then
		--PlaySound(RidinDirty.savedVariables.chatNotify)
		df(rdLogo .. " " .. tostring(ZO_FormatClockTime()) .. " " .. tostring(displayNamePref) .. " logged on in " .. zoneName)
	elseif not IsFriend(displayName) and newStatus == PLAYER_STATUS_OFFLINE then
		--PlaySound(RidinDirty.savedVariables.chatNotify)
		df(rdLogo .. " " .. tostring(ZO_FormatClockTime()) .. " " .. tostring(displayNamePref) .. " logged off in " .. zoneName)
	elseif newStatus == PLAYER_STATUS_ONLINE and oldStatus == PLAYER_STATUS_AWAY then
		--PlaySound(RidinDirty.savedVariables.chatNotify)
		df(rdLogo .. " " .. tostring(ZO_FormatClockTime()) .. " " .. tostring(displayNamePref) .. " is BACK in " .. zoneName)
	elseif newStatus == PLAYER_STATUS_AWAY and oldStatus == PLAYER_STATUS_ONLINE then
		--PlaySound(RidinDirty.savedVariables.chatNotify)
		df(rdLogo .. " " .. tostring(ZO_FormatClockTime()) .. " " .. tostring(displayNamePref) .. " is AWAY in " .. zoneName)
	end
end

function RidinDirty.ChatNotifyToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.chatNotify = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_CHAT_MESSAGE_CHANNEL, ChatNotify)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_FRIEND_PLAYER_STATUS_CHANGED, RidinDirty.FSC)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, RidinDirty.GSC)
		PlaySound(RidinDirty.savedVariables.chatNotify)
	else
		RidinDirty.savedVariables.chatNotify = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_CHAT_MESSAGE_CHANNEL)
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_FRIEND_PLAYER_STATUS_CHANGED)
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED)
	end
end
---------------------------------------------
-------- LOG COMPANION RAPPORT & DEATH --
---------------------------------------------
local function CompanionRapport(eventCode, companionId, prevRapport, currRapport, rapportChange)
	local companionName = zo_strformat("<<1>>", GetCompanionName(companionId))--<< Strip Genders
	df(rdLogo .. companionName .. " Rapport: " .. tostring(currRapport - prevRapport) .. " ( " .. currRapport .. " / " .. GetMaximumRapport() .. " )")
end

--and IsUnitInCombat("player") and not IsUnitDeadOrReincarnating("player") then
local function CompanionReSummon()
	local collectibleID = GetUnlockedAssistant()
	if collectibleID and not HasPendingCompanion() and not IsUnitDeadOrReincarnating("player") then
		UseCollectible(collectibleID)
	else
		EVENT_MANAGER:UnregisterForUpdate("RDCompanion")
	end
end

local function CompanionDeathState(eventCode, unitTag, isDead)
	if IsUnitDead("companion") then
		local companionName = zo_strformat("<<1>>", GetUnitName(unitTag))--<< Strip Genders
		CENTER_SCREEN_ANNOUNCE:AddMessage( 0, CSA_CATEGORY_LARGE_TEXT, "Console_Game_Enter", ("|ccc0000WARNING! " .. companionName .. " DIED...|r"), nil, nil, nil, nil, nil, 5000, nil)
		if InAlphaList(GetUnitDisplayName("player")) and not IsUnitDeadOrReincarnating("player") then--and IsUnitInCombat("player")
			local collectibleID = GetUnlockedAssistant()
			if collectibleID then UseCollectible(collectibleID) end
			EVENT_MANAGER:RegisterForUpdate("RDCompanion", 2200, CompanionReSummon)
		end
	else
		EVENT_MANAGER:UnregisterForUpdate("RDCompanion")
	end
end

local function CompanionSummonResult(eventID, summonResult, companionId)
	--df("SUMMONING COMPANION - " .. tostring(summonResult) .. " - " .. tostring(companionId))
	if summonResult == 4 or summonResult == 11 or IsUnitDeadOrReincarnating("player") then
		EVENT_MANAGER:UnregisterForUpdate("RDCompanion")
	end
end

function RidinDirty.CompanionRapportToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.companionRapport = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_COMPANION_RAPPORT_UPDATE, CompanionRapport)
		EVENT_MANAGER:RegisterForEvent("RDCompDeath", EVENT_UNIT_DEATH_STATE_CHANGED, CompanionDeathState)
		EVENT_MANAGER:AddFilterForEvent("RDCompDeath", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "companion")
		if InAlphaList(GetUnitDisplayName("player")) then--<< TESTING
			EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_COMPANION_SUMMON_RESULT, CompanionSummonResult)
		end
	else
		RidinDirty.savedVariables.companionRapport = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_COMPANION_RAPPORT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent("RDCompDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_COMPANION_SUMMON_RESULT)
	end
end
---------------------------------------------
------ AUTO ACCEPT QUEUES --
---------------------------------------------
local function AutoQueue(eventCode, queueStatus)
	if queueStatus ~= ACTIVITY_FINDER_STATUS_READY_CHECK then
		return
	elseif IsActiveWorldBattleground() then
		return
	elseif HasLFGReadyCheckNotification() then
		AcceptLFGReadyCheckNotification()
		return
	end
end

local function PvPAutoQueue(eventCode, id, isGroup, state)
	if state == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
		PlaySound("GuildRoster_Added")
		RidinDirty.HourGlass.label:SetText (rdLogo .. "|cCCCC00Entering (" .. GetCampaignName(id) .. ")|r")
		RidinDirty.HourGlass:SetAlpha(1)
		RidinDirty.HourGlass.animation:PlayForward()
		ConfirmCampaignEntry(id, isGroup, true)
		zo_callLater(function()
			RidinDirty.HourGlass:SetAlpha(0)
			RidinDirty.HourGlass.animation:Stop()
		 end, 4000)
	end
end

function RidinDirty.AutoQueueToggle(toggle)
   if toggle then
		RidinDirty.savedVariables.autoQueue = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_ACTIVITY_FINDER_STATUS_UPDATE, AutoQueue)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, PvPAutoQueue)
	else
		RidinDirty.savedVariables.autoQueue = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_ACTIVITY_FINDER_STATUS_UPDATE)
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_CAMPAIGN_QUEUE_STATE_CHANGED)
	end
end
---------------------------------------------
------------ COMBAT RETICLE --
---------------------------------------------
--eventCode(131123)--Taunt(38254)--TauntStacks(52790)--TauntImmunity(52788)--OffBalance(45902)--OffBalanceImmunity(134599)--MinorVul(79717)--MajorVul(106754)--CCI(28301)--taunt counter(52790)
--157235provoke--(tauntID)Blazing grasp--193132scathing rune--213165perigean armor--157242savage instinct--159179frost blast
--df(tostring(buffName) .. " - " .. tostring(abilityId) .. " - " .. tostring(zo_roundToNearest(timeEnding - GetFrameTimeSeconds(), 1)))
--IsUnitAttackable(target) ----IsUnitDead(target)
--taunt=ABILITY_TYPE_SETTARGET=7, 
local function CombatReticle()
	local target = "reticleover"
	if DoesUnitExist(target) and not IsUnitPlayer(target) then
		local tauntEnd, immuneEnd, playerTaunt = 0, 0, false
		for buff = 1, GetNumBuffs(target) do
			local buffName, timeStarted, timeEnd, _, stackCount, _, buffType, effectType, abilityType, statusType, abilityId, _, playerCast = GetUnitBuffInfo(target, buff)
			if abilityId == 52788 then
				immuneEnd = timeEnd
				break
			elseif abilityType == 7 then
				tauntEnd = timeEnd
				if playerCast then playerTaunt = true end
			end
		end
		if immuneEnd ~= 0 then
			RidinDirty.TauntCounter.label:SetColor(128,0,0,1)
			RidinDirty.TauntCounter.label:SetText("IMMUNE")
			RidinDirty.Combat:SetAlpha(0)
			RidinDirty.TauntCounter:SetAlpha(1)
			return
		elseif tauntEnd ~= 0 then
			local timeLeft = zo_roundToNearest(tauntEnd - GetFrameTimeSeconds(), 1)
			if playerTaunt then
				if timeLeft <= 3 then
					RidinDirty.TauntCounter.label:SetColor(128,128,0,1)
				else
					RidinDirty.TauntCounter.label:SetColor(0,128,0,1)
				end
			else
				RidinDirty.TauntCounter.label:SetColor(128,128,128,1)
			end
			RidinDirty.TauntCounter.label:SetText(timeLeft)
			RidinDirty.Combat:SetAlpha(0)
			RidinDirty.TauntCounter:SetAlpha(1)
			return
		end
		RidinDirty.TauntCounter:SetAlpha(0)
		RidinDirty.Combat:SetAlpha(1)
	else
		RidinDirty.TauntCounter:SetAlpha(0)
		RidinDirty.Combat:SetAlpha(1)
	end
end

local function CombatState()
	if IsUnitInCombat("player") and not IsUnitDead("player") then
		if not IsPlayerInAvAWorld() and not IsActiveWorldBattleground() then
			EVENT_MANAGER:RegisterForUpdate("RDTaunt", 500, CombatReticle)
			EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_RETICLE_TARGET_CHANGED, CombatReticle)
		else
			RidinDirty.Combat:SetAlpha(1)
		end
	else
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_RETICLE_TARGET_CHANGED)
		EVENT_MANAGER:UnregisterForUpdate("RDTaunt")
		RidinDirty.TauntCounter:SetAlpha(0)
		RidinDirty.Combat:SetAlpha(0)
	end
end

function RidinDirty.CombatReticleToggle(toggle)
	if toggle then
		RidinDirty.savedVariables.combatReticle = toggle
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_PLAYER_COMBAT_STATE, CombatState)
		EVENT_MANAGER:RegisterForEvent("RDCombatDeath", EVENT_PLAYER_DEAD, CombatState)
		EVENT_MANAGER:RegisterForEvent("RDCombatAlive", EVENT_PLAYER_ALIVE, CombatState)
	else
		RidinDirty.savedVariables.combatReticle = toggle
		EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_PLAYER_COMBAT_STATE)
		EVENT_MANAGER:UnregisterForEvent("RDCombatDeath", EVENT_PLAYER_DEAD)
		EVENT_MANAGER:UnregisterForEvent("RDCombatAlive", EVENT_PLAYER_ALIVE)
	end
end
---------------------------------------------
--------- LEAVE GROUP & EXIT INSTANCE --
---------------------------------------------
function RidinDirty.GroupLeave()
	if IsUnitGrouped("player") then
		GroupLeave()
		if CanExitInstanceImmediately() then
			ExitInstanceImmediately()
			--LeaveBattleground()???
		end
	elseif CanExitInstanceImmediately() then
		ExitInstanceImmediately()
		--LeaveBattleground()???
	elseif not IsUnitGrouped("player") then
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", ("Inviting " .. RidinDirty.savedVariables.savedPlayer .. " to group."))
		GroupInviteByName(RidinDirty.savedVariables.savedPlayer)
	end
end
---------------------------------------------
-------- SIEGE CAMERA TOGLE --
---------------------------------------------
function RidinDirty.SiegeCameraToggle()
	if IsUnitDeadOrReincarnating("player") then return end
	PlaySound("GuildRoster_Added")
	local setting = GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_THIRD_PERSON_SIEGE_WEAPONRY)
    if setting == "1" then setting = "0" else setting = "1" end
    SetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_THIRD_PERSON_SIEGE_WEAPONRY, setting, 1)
end
---------------------------------------------
--------- SLASH COMMANDS --
---------------------------------------------
if not Teleport and not EasyTravel then-- Compatibility
	SLASH_COMMANDS["/tp"] = function (option)
		if (option == nil or option == "") then df(rdLogo .. " /tp partialzonename => overland zones")
			df(rdLogo .. " /tp home => your primary residence")
				df(rdLogo .. " /tp exact@name partialhousename => player houses") return end
		if string.lower(option) == "home" then RidinDirty.TravelToHome() return end
		local options = {}
		local searchResult = { string.match(option, "^(%S*)%s*(%S*)$") }
		for i, v in pairs(searchResult) do
			if (v ~= nil and v ~= "") then
				options[i] = v
			end
		end
		if options[1] ~= nil and not string.find(options[1], "^(@)") and options[2] == nil then
			RidinDirty.Teleport(options[1])
		elseif options[1] ~= nil and string.find(options[1], "^(@)") and options[1] ~= GetUnitDisplayName("player") and options[2] ~= nil and GetHouseID(options[2]) then
			RidinDirty.Teleport(options[1], options[2])
		else
			df(rdLogo .. " /tp partialzonename => overland zones") df(rdLogo .. " /tp exact@name partialhousename => player houses")
		end
	end
end

SLASH_COMMANDS["/rdlink"] = function (option)
	local bagId = BAG_BACKPACK
	for slotIndex = 0, GetBagSize(bagId) do
		if IsItemBoPAndTradeable(bagId, slotIndex) and IsUnitInDungeon("player") then
			RidinDirty.RDBopTradeable()
			return
		end
	end
	RidinDirty.RDUnboundSets()
end

function RidinDirty.RDBopTradeable()
	local bagId = BAG_BACKPACK
	local count = 0
	local links = ""
	for slotIndex = 0, GetBagSize(bagId) do
		local itemId = GetItemId(bagId, slotIndex)
		local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
		local itemType, specialType = GetItemType(bagId, slotIndex)
		if count < 4 and IsItemBoPAndTradeable(bagId, slotIndex) and not IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) and not RidinDirty.InTradeTable(itemLink) then
			local isTradeable = false
			for iD = 1, GetGroupSize() do
				local playerID = GetGroupUnitTagByIndex(iD)
				local playerDisplayName = GetUnitDisplayName(playerID)
				if playerDisplayName ~= GetUnitDisplayName("player") and string.find(GetItemBoPTradeableDisplayNamesString(bagId, slotIndex), playerDisplayName) then
					isTradeable = true
					break
				end
			end
			if isTradeable then
				count = count + 1
				table.insert(RidinDirty.tradeTable, itemLink)
				links = (links .. itemLink)
			end
		end
	end
	if links == "" then
		RidinDirty.tradeTable = {} df(rdLogo .. "*Linking complete*") CHAT_SYSTEM.textEntry:GetEditControl():LoseFocus()
	else
		StartChatInput(links, CHAT_CHANNEL_PARTY)
		RidinDirty.TradeLinkWait("bops")
	end
end

function RidinDirty.RDUnboundSets()
	local bagId = BAG_BACKPACK
	local count = 0
	local links = ""
	for slotIndex = 0, GetBagSize(bagId) do
		local itemId = GetItemId(bagId, slotIndex)
		local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
		local itemType, specialType = GetItemType(bagId, slotIndex)
		if count < 4 and not IsItemBound(bagId, slotIndex) and not IsItemBoPAndTradeable(bagId, slotIndex) and IsItemLinkSetCollectionPiece(itemLink) and IsItemSetCollectionPieceUnlocked(itemId) and not RidinDirty.InTradeTable(itemLink) then
			count = count + 1
			table.insert(RidinDirty.tradeTable, itemLink)
			if count == 1 then links = (links .. itemLink) else links = (links .. "-" .. itemLink) end
		end
	end
	if links == "" then
		RidinDirty.tradeTable = {} df(rdLogo .. "*Linking complete*") CHAT_SYSTEM.textEntry:GetEditControl():LoseFocus()
	else
		StartChatInput(links, CHAT_CHANNEL_PARTY)
		RidinDirty.TradeLinkWait("sets")
	end
end

function RidinDirty.InTradeTable(itemLink)
	for _, link in ipairs(RidinDirty.tradeTable) do
		if link == itemLink then return true end
	end
	return false
end

function RidinDirty.TradeLinkWait(decision)
	if CHAT_SYSTEM.textEntry:GetEditControl():GetText() ~= "" then
		zo_callLater(function() RidinDirty.TradeLinkWait(decision) end, 1000)
	elseif decision == "sets" then
		RidinDirty.RDUnboundSets()
	elseif decision == "bops" then
		RidinDirty.RDBopTradeable()
	end
end

SLASH_COMMANDS["/rdpvp"] = function (option)
	local addOnManager = GetAddOnManager()
	local numAddOns = addOnManager:GetNumAddOns()
	local pvpMode = false
	for addonIndex = 1, numAddOns do
		local addonName, addonTitle, addonAuthor, addonDescription, isEnabled, addonState, isOutOfDate, isLibrary = addOnManager:GetAddOnInfo(addonIndex)
		if not isEnabled and addonName ~= "merTorchbug" and addonName ~= "Zgoo" and addonName ~= "TextureIt" and addonName ~= "SoundBoard" then pvpMode = true break end
	end
	if pvpMode then
		for addonIndex = 1, numAddOns do
			local addonName, addonTitle, addonAuthor, addonDescription, isEnabled, addonState, isOutOfDate, isLibrary = addOnManager:GetAddOnInfo(addonIndex)
			if addonName ~= "merTorchbug" and addonName ~= "Zgoo" and addonName ~= "TextureIt" and addonName ~= "SoundBoard" then
				addOnManager:SetAddOnEnabled(addonIndex, true)
			end
		end
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "PvP performance mode disabled.")
	else
		for addonIndex = 1, numAddOns do
			addOnManager:SetAddOnEnabled(addonIndex, false)
			local addonName, addonTitle, addonAuthor, addonDescription, isEnabled, addonState, isOutOfDate, isLibrary = addOnManager:GetAddOnInfo(addonIndex)
			for i, v in pairs(RidinDirty.savedVariables["Addon Memory"]) do
				if i ~= nil and i ~= "version" then
					if v == addonName then addOnManager:SetAddOnEnabled(addonIndex, true) end
				end
			end
		end
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", "PvP performance mode enabled.")
	end
	zo_callLater(function() ReloadUI() end, 2000)
end

SLASH_COMMANDS["/rdfc"] = function (option)
	local secondsLeft = ((GetNextForwardCampRespawnTime() - GetGameTimeMilliseconds()) / 1000)
	if GetNextForwardCampRespawnTime() ~= 0 and secondsLeft > 0 then
		local respawnTime = ZO_FormatTimeAsDecimalWhenBelowThreshold(secondsLeft)
		df(rdLogo .. "Forward Camp Use Available In " .. tostring(respawnTime))
	else
		df(rdLogo .. "Forward Camp Use Available")
	end
end

if InAlphaList(GetUnitDisplayName("player")) then
	SLASH_COMMANDS["/rdadmin"] = function (option)--<< ADMIN INVENTORY DATA FUNCTION
		if option ~= "" then
			local links = ("|H1:item:" .. option .. ":1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
			StartChatInput(links, CHAT_CHANNEL_PARTY)
		else
			local bagId = BAG_BACKPACK
			for slotIndex = 0, GetBagSize(bagId) do
				local itemId = GetItemId(bagId, slotIndex)
				local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
				local itemType, specialType = GetItemType(bagId, slotIndex)
				if IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) then itemLink = (IsKnowledgeUnknown(itemId, itemLink, itemType, specialType) .. itemLink) end
				if itemLink ~= (nil or "") then
					df(itemLink .. " - " .. itemId .. " - " .. itemType .. " - " .. specialType)
				end
			end
		end
	end
end

if InAlphaList(GetUnitDisplayName("player")) then
	SLASH_COMMANDS["/rdtest"] = function (option)--<< ADMIN TEST FUNCTION
		--ZO_PlayerAttributeHealth:SetAnchor(TOP, ZO_BuffDebuffTopLevelSelfContainer, BOTTOM, 0, 24)
		--ZO_PlayerAttributeMagicka:SetAnchor(TOPRIGHT, ZO_PlayerAttributeHealth, BOTTOM, 0, 8)
		--ZO_PlayerAttributeStamina:SetAnchor(TOPLEFT, ZO_PlayerAttributeHealth, BOTTOM, 0, 8)
		local hisValid, hpoint, hrelativeTo, hrelativePoint, hoffsetX, hoffsetY = ZO_PlayerAttributeHealth:GetAnchor()
		local misValid, mpoint, mrelativeTo, mrelativePoint, moffsetX, moffsetY = ZO_PlayerAttributeMagicka:GetAnchor()
		local sisValid, spoint, srelativeTo, srelativePoint, soffsetX, soffsetY = ZO_PlayerAttributeStamina:GetAnchor()
		df("H: " .. tostring(hpoint) .. " - " .. tostring(hrelativeTo) .. " - " .. tostring(hrelativePoint) .. " - " .. tostring(hoffsetX) .. " - " .. tostring(hoffsetY))
		df("M: " .. tostring(mpoint) .. " - " .. tostring(mrelativeTo) .. " - " .. tostring(mrelativePoint) .. " - " .. tostring(moffsetX) .. " - " .. tostring(moffsetY))
		df("S: " .. tostring(spoint) .. " - " .. tostring(srelativeTo) .. " - " .. tostring(srelativePoint) .. " - " .. tostring(soffsetX) .. " - " .. tostring(soffsetY))
	end
end

local function RDInitializeSettings()
	--- BASE FEATURES --
	local late = LibCustomMenu.CATEGORY_LATE
	LibCustomMenu:RegisterGuildRosterContextMenu(RidinDirty.SaveMenu, late)
	LibCustomMenu:RegisterFriendsListContextMenu(RidinDirty.SaveMenu, late)
	LibCustomMenu:RegisterGroupListContextMenu(RidinDirty.SaveMenu, late)
	EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_MOUNTED_STATE_CHANGED, PassengerStateChange)
	-- ADDITIONAL FEATURES --
	if RidinDirty.savedVariables.bankManager or RidinDirty.savedVariables.storageManager or RidinDirty.savedVariables.goldDeposit or
		RidinDirty.savedVariables.apDeposit or RidinDirty.savedVariables.telvarDeposit or RidinDirty.savedVariables.voucherDeposit or
			RidinDirty.savedVariables.balanceDisplay then EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_OPEN_BANK, BankManager)
	end
	if RidinDirty.savedVariables.junkManager then
		local tertiary = LibCustomMenu.CATEGORY_TERTIARY
		LibCustomMenu:RegisterContextMenu(MarkPermJunkMenu, tertiary)
		LibCustomMenu:RegisterContextMenu(UnMarkPermJunkMenu, tertiary)
		--LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, ChatLinkUnMarkMenu)
		EVENT_MANAGER:RegisterForEvent("RidinDirtyJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, JunkManager)
		--EVENT_MANAGER:AddFilterForEvent("RidinDirtyJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		EVENT_MANAGER:RegisterForEvent("RidinDirtyJunk", EVENT_OPEN_STORE, AutoSellRepair)
	end
	if RidinDirty.savedVariables.lockArmory then
		ARMORY_KEYBOARD.keybindStripDescriptor[2].enabled = false
		ARMORY_KEYBOARD.keybindStripDescriptor[2].name = ("Save Locked")
	end
	if RidinDirty.savedVariables.chatNotify then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_CHAT_MESSAGE_CHANNEL, ChatNotify)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_FRIEND_PLAYER_STATUS_CHANGED, RidinDirty.FSC)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, RidinDirty.GSC)
	end
	if RidinDirty.savedVariables.companionRapport then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_COMPANION_RAPPORT_UPDATE, CompanionRapport)
		EVENT_MANAGER:RegisterForEvent("RDCompDeath", EVENT_UNIT_DEATH_STATE_CHANGED, CompanionDeathState)
		EVENT_MANAGER:AddFilterForEvent("RDCompDeath", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "companion")
		if InAlphaList(GetUnitDisplayName("player")) then--<< TESTING
			EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_COMPANION_SUMMON_RESULT, CompanionSummonResult)
		end
	end
	if RidinDirty.savedVariables.autoQueue then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_ACTIVITY_FINDER_STATUS_UPDATE, AutoQueue)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, PvPAutoQueue)
	end
	if RidinDirty.savedVariables.combatReticle then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_PLAYER_COMBAT_STATE, CombatState)
		EVENT_MANAGER:RegisterForEvent("RDCombatDeath", EVENT_PLAYER_DEAD, CombatState)
		EVENT_MANAGER:RegisterForEvent("RDCombatAlive", EVENT_PLAYER_ALIVE, CombatState)
	end
	if RidinDirty.savedVariables.withdrawOne then
		local primary = LibCustomMenu.CATEGORY_PRIMARY
		LibCustomMenu:RegisterContextMenu(WithdrawMenu, primary)
	end
	if RidinDirty.savedVariables.avtLog then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_ALLIANCE_POINT_UPDATE, ApLog)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_REWARD_TRACK_PROGRESS_GAINED, VetLog)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_TELVAR_STONE_UPDATE, TelvarLog)
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_PENDING_CURRENCY_REWARD_CACHED, ApLog)
		if InAlphaList(GetUnitDisplayName("player")) then--<< TESTING
			ZO_PostHook(BATTLEGROUND_FINDER_KEYBOARD.filterComboBox, 'SelectItem', function(_, item)
				if not item then return end
				if not BATTLEGROUND_FINDER_KEYBOARD.filterComboBox:IsDropdownVisible() then return end
				RidinDirty.savedVariables.lastBGMode = item.name
			end)
			ZO_PostHook(BATTLEGROUND_FINDER_KEYBOARD, 'RefreshFilters', function()
				local lastBGMode = RidinDirty.savedVariables.lastBGMode and GetLastBGModeItem(RidinDirty.savedVariables.lastBGMode)
				if lastBGMode and lastBGMode.name ~= BATTLEGROUND_FINDER_KEYBOARD.filterComboBox:GetSelectedItemData().name and BATTLEGROUND_FINDER_KEYBOARD.fragment:IsShowing() then
					BATTLEGROUND_FINDER_KEYBOARD.filterComboBox:SelectItem(lastBGMode)
				end
			end)
		end
	end
	if RidinDirty.savedVariables.lootManager then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_LOOT_RECEIVED, LootManager)
		ZO_PostHook(ItemTooltip, "SetStoreItem", TooltipLeadInfo)
		ZO_PostHook(ItemTooltip, "SetLootItem", TooltipLeadInfo)
		--ZO_PostHook(ItemTooltip, "SetBagItem", function(control, bagId, slotIndex)
			--ZO_Tooltip_AddDivider(ItemTooltip)
		--end)
		for _, i in pairs(PLAYER_INVENTORY.inventories) do
			local ListView = i.listView
			if ListView and ListView.dataTypes and ListView.dataTypes[1] and ListView:GetName() ~= "ZO_PlayerInventoryQuest" then
				local DataType = ListView.dataTypes[1]
				SecurePostHook(DataType, 'setupCallback', function(control, slot)
					if SCENE_MANAGER:GetCurrentScene() ~= STABLES_SCENE then
						NeedsAndPrice(control, slot)
					end
				end)
			end
		end
		--deconstruction (assistant)
		SecurePostHook(ZO_UniversalDeconstructionTopLevel_KeyboardPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--deconstruction (crafting stations)
		SecurePostHook(ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--refinement (crafting stations)
		SecurePostHook(ZO_SmithingTopLevelRefinementPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--improvement (crafting stations)
		SecurePostHook(ZO_SmithingTopLevelImprovementPanelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--enchanting (crafting stations)
		SecurePostHook(ZO_EnchantingTopLevelInventoryBackpack.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		--loot window
		SecurePostHook(ZO_LootAlphaContainerList.dataTypes[1], "setupCallback", function(control, slot)
			NeedsAndPrice(control, slot)
		end)
		EVENT_MANAGER:RegisterForEvent("RidinDirtyLoot", EVENT_COLLECTION_UPDATED, RefreshStore)
		SecurePostHook(ZO_StoreManager, "SetUpBuySlot", function(self, control, slot)
			NeedsAndPrice(control, slot)
		end)
		SecurePostHook(TRADING_HOUSE, "OpenTradingHouse", function()
			if RidinDirty.savedVariables.traderEnhance then
				zo_callLater(function() if TRADING_HOUSE_SEARCH:CanDoCommonOperation() then TRADING_HOUSE_SEARCH:DoSearch() end end, searchDelay)
			end
			if not traderMods then
				traderMods = true
				local oldSearch = ZO_ScrollList_GetDataTypeTable(ZO_TradingHouseBrowseItemsRightPaneSearchResults, 1).setupCallback
				local oldListing = ZO_ScrollList_GetDataTypeTable(ZO_TradingHousePostedItemsList, 2).setupCallback
					ZO_ScrollList_GetDataTypeTable(ZO_TradingHouseBrowseItemsRightPaneSearchResults, 1).setupCallback = function(control, slot)
						oldSearch(control, slot) NeedsAndPrice(control, slot) end
					ZO_ScrollList_GetDataTypeTable(ZO_TradingHousePostedItemsList, 2).setupCallback = function(control, slot)
						oldListing(control, slot) NeedsAndPrice(control, slot) end
			end
		end)
	end
	if RidinDirty.savedVariables.traderEnhance then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_CHATTER_BEGIN, TraderChatter)
		ZO_TradingHouseTitleLabel:SetMouseEnabled(true)
		ZO_TradingHouseTitleLabel:SetHandler("OnMouseUp", function(self, mouseButton, upInside)
			if upInside then
				PlaySound("Click")
				RidinDirty.CycleTradingGuilds()
			end
		end)
		ZO_TradingHouseTitleLabel:SetHandler("OnMouseEnter", function(self)
			InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
			SetTooltipText(InformationTooltip, "CLICK TO CYCLE TRADING GUILDS")
		end)
		ZO_TradingHouseTitleLabel:SetHandler("OnMouseExit", function(self)
			ClearTooltip(InformationTooltip)
		end)
		SecurePostHook(TRADING_HOUSE, "UpdateForGuildChange", function()
			local count, countmax = GetTradingHouseListingCounts()
			RidinDirty.ListingCounter.label:SetText ("Listings " .. tostring(count) .. " of " .. tostring(countmax))
		end)
		SecurePostHook(TRADING_HOUSE, "OnResponseReceived", function(responseType, result)
			if result == TRADING_HOUSE_RESULT_POST_PENDING or result == TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING then
				local count, countmax = GetTradingHouseListingCounts()
				RidinDirty.ListingCounter.label:SetText ("Listings " .. tostring(count) .. " of " .. tostring(countmax))
			end
		end)
		if not RidinDirty.savedVariables.lootManager then
			SecurePostHook(TRADING_HOUSE, "OpenTradingHouse", function()
				zo_callLater(function() if TRADING_HOUSE_SEARCH:CanDoCommonOperation() then TRADING_HOUSE_SEARCH:DoSearch() end end, searchDelay)
			end)
		end
	end
	if RidinDirty.savedVariables.pvpKillFeed then
		EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_PVP_KILL_FEED_DEATH, PvpKillFeed)
	end
	EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

local function AddOnLoaded(eventCode, addOnName)
	if addOnName ~= "RidinDirty" then return end
	ZO_CreateStringId("SI_BINDING_NAME_MOUNT_PLAYER", "Mount Group Member")
	ZO_CreateStringId("SI_BINDING_NAME_TRAVEL_TO_PLAYER", "Travel To Player & In Zone")
	ZO_CreateStringId("SI_BINDING_NAME_LEAVE_GROUP", "Leave Group & Exit Instance")
	if not BUI then ZO_CreateStringId("SI_BINDING_NAME_SIEGE_CAMERA_TOGGLE", "Siege Camera Toggle") end
	local defaultAccountVars = {
		savedPlayer = "|ccc0000@NotSet|r",
		travelOutside = false,
		bankManager = false,
		bankALL = false,
		storageManager = false,
		storageAll = false,
		withdrawOne = false,
		withdrawAmount = 25,
		checkBankMemory = false,
		goldDeposit = false,
		noDeposit = "|ccc0000*DISABLED*|r",
		goldReserve = 10000,
		apDeposit = false,
		apReserve = 0,
		telvarDeposit = false,
		telvarReserve = 0,
		voucherDeposit = false,
		balanceDisplay = false,
		junkManager = false,
		junkSilentMode = false,
		saveCraftables = true,
		junkTreasures = false,
		junkIntricates = false,
		junkStolen = false,
		junkMaps = false,
		junkKnownScripts = false,
		destroyLQStolen = false,
		destroyUnsellable = false,
		autoRecharge = false,
		lootManager = false,
		lootQuality = 2,
		ttcPricing = false,
		traderEnhance = false,
		avtLog = false,
		minimumAVT = 100,
		bombSensitivity = 500,
		pvpKillFeed = false,
		pvpKillsReset = GetLastDailyReset(),
		pvpKills = 0,
		pvpDeaths = 0,
		chatNotify = false,
		fontBoost = false,
		lockArmory = false,
		stackAttributes = false,
		companionRapport = false,
		combatReticle = false,
		autoQueue = false,
	}
	local defaultCharVars = {
		charClass = GetUnitClass("player"),
		veterancyProgress = 0,
	}
	local defaultJunkVars = {
	}
	local defaultAddonVars = {
	}
	local defaultBankedVars = {
	}
	RidinDirty.savedVariables = ZO_SavedVars:NewAccountWide( RidinDirty.svName, RidinDirty.svVersion, nil, defaultAccountVars )
	RidinDirty.charVariables = ZO_SavedVars:NewAccountWide( RidinDirty.svName, RidinDirty.svVersion, GetUnitName("player"), defaultCharVars )
	RidinDirty.junkMemory = ZO_SavedVars:NewAccountWide( RidinDirty.svName, RidinDirty.svVersion, "Junk Memory", defaultJunkVars )
	RidinDirty.addonMemory = ZO_SavedVars:NewAccountWide( RidinDirty.svName, RidinDirty.svVersion, "Addon Memory", defaultAddonVars )
	RidinDirty.bankedMemory = ZO_SavedVars:NewAccountWide( RidinDirty.svName, RidinDirty.svVersion, "Banked Memory", defaultBankedVars )
	--RidinDirty.savedVariables.lowStack = nil--<< SAVE
	--RidinDirty.charVariables.veterancyPoints = nil--<< SAVE
	--RidinDirty.charVariables.veterancyRank = nil--<< SAVE
	RDInitializeControls()
	RDInitializeSettings()
	if GetTimeStamp() > (RidinDirty.savedVariables.pvpKillsReset + 86400) then RidinDirty.SetClearKillFeed(false) end
	EVENT_MANAGER:UnregisterForEvent("RidinDirty", EVENT_ADD_ON_LOADED)
end
EVENT_MANAGER:RegisterForEvent("RidinDirty", EVENT_ADD_ON_LOADED, AddOnLoaded)