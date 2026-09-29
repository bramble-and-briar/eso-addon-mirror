--[[
MasterThief - Intelligent Stealing Assistant
Created by: Adalan@Aruntas
Support, Fixes, Improvements by: WolfStar07
--]]

----------------------------------------
-- INITIALIZE TABLES
----------------------------------------
MasterThief = MasterThief or {}

-- Prevent multiple initialization
if MasterThief._initialized then
	d("[MasterThief] Already initialized!")
	return
end

-- Addon metadata
MasterThief._addon = {
	Name = "MasterThief",
	DisplayName = "MasterThief",
	Author = "Adalan & WolfStar07",
	Version = "1.8",
}

ZO_CreateStringId("SI_ITEM_ACTION_MASTERTHIEF_MARK", "Mark for Auto-Loot")

-- Local shortcut
local MT = MasterThief

-- Legacy compatibility - old code uses these
MT.name = MT._addon.Name
MT.version = MT._addon.Version

----------------------------------------
-- GLOBAL VARIABLES
----------------------------------------
-- Lockpicking state
bLockpickSuccessful = true
lockpickSuccessTime = 0
lockpickChecked = false
lockpickTargetType = nil
lootClosedTime = 0

-- Inventory management
local iFreeSpaceLeft = 0
local gPlayerChar = "unknown"
stolenTotal = 0

-- UI and display
local bShowFenceSellLimitAgain = false
local bShowFenceTransferLimitAgain = false
local bFenceValuesUpdated = false
local scrollList = nil

-- Stealth mode
local bInSneak = false

-- Justice tracking
hadBountyBeforeDeath = false
bountyIncreaseTime = 0

-- Pickpocketing
pickpocketInProgress = false
pickpocketItemCount = 0

-- Blade of Woe
local bladeOfWoeEventCount = 0
local bladeOfWoeEventTimer = nil

-- Loot processing
processedLootInThisSession = {}
scrollListData = {}

-- Message queue
local _EventList = {}

-- UI colors/styles
local TAB_INACTIVE_BG = { 0.15, 0.15, 0.15, 0.9 }
local TAB_ACTIVE_BG   = { 0.22, 0.24, 0.25, 0.95 }

----------------------------------------
-- DATA TABLES
----------------------------------------
MT.ItemTypes = {
	ITEMTYPE_RACIAL_STYLE_MOTIF,
	ITEMTYPE_RECIPE,
	ITEMTYPE_FURNISHING,
	ITEMTYPE_TREASURE_MAP,
	ITEMTYPE_CONTAINER_CURRENCY,
	ITEMTYPE_TROPHY,
}

MT.KnownRecipes = {}
MT.LootlistItems = {}
MT.LootlistItems.Worthful = {}

----------------------------------------
-- HELPER FUNCTIONS
----------------------------------------
-- These are called by multiple modules so they MUST be in main file

function MasterThief:fCheckItemType(itemType)
	for _, specialType in ipairs(MasterThief.ItemTypes) do
		if itemType == specialType then
			return true
		end
	end
	return false
end

-- Specialized type lookup tables for furnishing plans and recipes.
-- Values confirmed in-game (Update 49). Kept here for future use
-- (e.g. pickpocket stat routing). Loot window routing uses
-- ITEMTYPE_RECIPE and SPECIALIZED_ITEMTYPE_FURNISHING_DESIGN instead.
local furnishingPlanTypes = {
	[172] = true,  -- diagram  (RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING)
	[173] = true,  -- pattern  (RECIPE_CLOTHIER_PATTERN_FURNISHING)
	[174] = true,  -- praxis   (RECIPE_PROVISIONING_DESIGN_FURNISHING)
	[175] = true,  -- formula  (RECIPE_ALCHEMY_FORMULA_FURNISHING)
	[176] = true,  -- design   (RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING)
	[177] = true,  -- blueprint(RECIPE_WOODWORKING_BLUEPRINT_FURNISHING)
	[178] = true,  -- sketch   (RECIPE_ENCHANTING_SCHEMATIC_FURNISHING)
}
local standardRecipeTypes = {
	[170] = true,  -- food  (RECIPE_PROVISIONING_STANDARD_FOOD)
	[171] = true,  -- drink (RECIPE_PROVISIONING_STANDARD_DRINK)
}

function MasterThief:IsFurnishingPlan(specializedType)
	return furnishingPlanTypes[specializedType] == true
end

function MasterThief:IsStandardRecipe(specializedType)
	return standardRecipeTypes[specializedType] == true
end

-- Stores the loot source type from the most recent loot window open.
-- Set by GetLootTargetInfo() in LootUpdated.
lastLootTargetType = nil
function MasterThief:IsSellPriceOk(sellPrice)
	if not sellPrice then return false end
	return sellPrice >= MasterThief.SavedVarsOptions.MinSellPrice
end

function MasterThief:IsStolenItemUseless(itemType, iSellPrice)
	local bSpecialItem = MasterThief:fCheckItemType(itemType)
	if bSpecialItem then
		return false
	end
	
	if iSellPrice < MasterThief.SavedVarsOptions.MinSellPrice then
		return true
	end
	
	return false
end

function MasterThief:CountStolenItems(value)
	-- Count stolen items in inventory
	-- value: 1 = regular stolen items, 2 = special items (motifs/recipes/etc)
	local count = 0
	
	for bagSlot = 0, GetBagSize(BAG_BACKPACK) - 1 do
		if IsItemStolen(BAG_BACKPACK, bagSlot) then
			local itemType = GetItemType(BAG_BACKPACK, bagSlot)
			local isSpecial = MasterThief:fCheckItemType(itemType)
			
			if value == 1 and not isSpecial then
				count = count + 1
			elseif value == 2 and isSpecial then
				count = count + 1
			end
		end
	end
	
	return count
end

----------------------------------------
-- STEALTH MODE MANAGEMENT
----------------------------------------
function MasterThief:UpdatedSlot(eventCode, iBagId, iSlotId, bNewItem, UpdateReason)
	-- This is for pickpocketing, which also updates the slot.
	local _, iStack, iSellPrice, _, _, _, _, iQuality = GetItemInfo(iBagId, iSlotId) 
	local itemLink = GetItemLink(iBagId, iSlotId, LINK_STYLE_DEFAULT)
	local itemType = GetItemLinkItemType(itemLink)
	
	-- check about if its a stolen item, which we want here
	if (IsItemStolen(iBagId, iSlotId)) then		
		-- check for special item found and announce it
		local bSpecialItem = MasterThief:fCheckItemType(itemType)
		if (bSpecialItem) then
			if MasterThief.SavedVarsOptions.SpecialOnScreenMsg or MasterThief.SavedVarsOptions.SpecialChatMsg then
				-- Get item quality for coloring
				local quality = GetItemLinkQuality(itemLink)
				local qualityColor = GetItemQualityColor(quality)
				local coloredName = qualityColor:Colorize(GetItemLinkName(itemLink))
				MasterThief:ShowMessage(coloredName, 0)
			end
		-- check for useless item found and announce it
		elseif (MasterThief:IsStolenItemUseless(itemType, iSellPrice) and MasterThief.SavedVarsOptions.AnnounceUselessItem) then 
			MasterThief:ShowMessage(GetString(MT_MISC_TRASH_TEXT)..MasterThief:FixLinkName(itemLink),1)
		end
		MasterThief:CheckFreeSlots()
		MasterThief:CheckMaxFenceLimit()
	end
end

function MasterThief:LootUpdated()
    local iNumLootItems = GetNumLootItems()
    
    -- Capture loot source type for potential use by other systems
    local _, targetType = GetLootTargetInfo()
    lastLootTargetType = targetType
	
    -- Check if we should process this loot based on stealth state
    local isStealthed = (GetUnitStealthState("player") > 0)

	-- Only process loot when stealthed
	if not isStealthed then
		return
	end
    
    -- Check if this loot came from a lockpick
    if not lockpickChecked and iNumLootItems > 0 then
        local timeSinceLockpick = GetGameTimeMilliseconds() - lockpickSuccessTime
        
        if timeSinceLockpick < 7000 then
            
            -- Check if any items are stolen
            local hasStolenItems = false
            for iLootIndex = 1, iNumLootItems do
                local iInstancedLootId = GetLootItemInfo(iLootIndex)
                local itemLootLink = GetLootItemLink(iInstancedLootId, LINK_STYLE_DEFAULT)
                if IsItemLinkStolen(itemLootLink) then
                    hasStolenItems = true
                    break
                end
            end
            
            lockpickChecked = true  -- Always set this
            
            if hasStolenItems then
				MasterThief:TrackSafeboxLockpicked()
			end
        end
    end

    if (bLockpickSuccessful) then
        bLockpickSuccessful = false
    end
    
    LootMoney()
    
    -- Main loot processing loop
    for iLootIndex = 1, iNumLootItems do
		local iInstancedLootId = GetLootItemInfo(iLootIndex)
		local itemLootLink = GetLootItemLink(iInstancedLootId, LINK_STYLE_DEFAULT)
		local sName = GetItemLinkName(itemLootLink)
		local iQuality = GetItemLinkQuality(itemLootLink)
		local _, iSellPrice = GetItemLinkInfo(itemLootLink)
		local itemType = GetItemLinkItemType(itemLootLink)
		local itemId = GetItemLinkItemId(itemLootLink)

		if IsItemLinkStolen(itemLootLink) then
			-- Check if we've already processed this item in this loot session
			if processedLootInThisSession[iInstancedLootId] then
				-- Already evaluated this item, skip it
			else
				-- Mark this item as processed
				processedLootInThisSession[iInstancedLootId] = true
				
				-- PRIORITY-BASED DECISION TREE - Only ONE path executes per item
				
				-- Priority 1: Items on loot list (highest priority)
				if MasterThief:isWorthfulItemOnScrollList(itemLootLink) and MasterThief.SavedVarsOptions.lootlist then
					LootItemById(iInstancedLootId)
					MasterThief:TrackItemLooted(itemLootLink, iSellPrice, itemType)
				
				-- Priority 1.5: Always-loot item IDs (treasure maps, edicts, portfolios, wallets)
				elseif itemId == 224681 or itemId == 71779 or itemId == 73754
					or itemId == 197790 or itemId == 187747 then
					LootItemById(iInstancedLootId)
					MasterThief:TrackItemLooted(itemLootLink, iSellPrice, itemType)
	
				-- Priority 2: Special items (recipes, motifs, furnishings, treasure maps)
				elseif MasterThief:fCheckItemType(itemType) then
					-- Recipes need knowledge checks
					if itemType == ITEMTYPE_RECIPE then
						MasterThief:DoActionLootItemRecipe(sName, iQuality, iInstancedLootId, itemLootLink)
					
					-- Furnishing plans need knowledge checks
					elseif itemType == ITEMTYPE_FURNISHING then
						local _, specializedType = GetItemLinkItemType(itemLootLink)
						if specializedType == SPECIALIZED_ITEMTYPE_FURNISHING_DESIGN then
							-- It's a furnishing plan - needs knowledge check
							MasterThief:DoActionLootItemRecipe(sName, iQuality, iInstancedLootId, itemLootLink)
						else
							-- It's a regular furnishing - always loot
							LootItemById(iInstancedLootId)
							MasterThief:TrackItemLooted(itemLootLink, iSellPrice, itemType)
						end
						
					-- Treasure maps and motifs - always loot
					else
						LootItemById(iInstancedLootId)
						MasterThief:TrackItemLooted(itemLootLink, iSellPrice, itemType)
					end
				
				-- Priority 3: Items meeting price threshold
				elseif MasterThief:IsSellPriceOk(iSellPrice) then
					LootItemById(iInstancedLootId)
					MasterThief:TrackItemLooted(itemLootLink, iSellPrice, itemType)
				
				-- Priority 4: Everything else - skip
				else
					MasterThief:TrackItemSkipped()
				end
			end
		end
	end  -- End of main loot loop
end

function MT.CheckStealthMode(iEventCode, sUnitTag, iStealthState)
	-- Called when stealth state changes
	if sUnitTag == "player" then
		MT:SetStealMode(iStealthState)
	end
end

function MasterThief:SetStealMode(iStealthState)
		if (iStealthState == 3 and bInSneak == false) then -- to get into at first (i am already in stealth)
			MasterThief:ShowMessage(GetString(MT_MISC_SNEAKMODE_ACTIVE), 2)
			bInSneak = true
			MT:CompanionOnEnterStealth()
			EVENT_MANAGER:RegisterForEvent(MasterThief.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)
				MasterThief:UpdatedSlot(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)
				
				if isNewItem and bagId == BAG_BACKPACK then
					local itemLink = GetItemLink(bagId, slotId)
					if IsItemLinkStolen(itemLink) then
						if pickpocketInProgress then
							pickpocketItemCount = pickpocketItemCount + 1
							
							local itemType = GetItemLinkItemType(itemLink)
							local itemName = GetItemLinkName(itemLink)
							local _, sellPrice = GetItemLinkInfo(itemLink)
							local _, specType = GetItemLinkItemType(itemLink)
							local shouldTrack = false
							
							-- Always track motifs and actual furnishings (not plans/recipes)
							if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or
							   (itemType == ITEMTYPE_FURNISHING and not MasterThief:IsFurnishingPlan(specType) and not MasterThief:IsStandardRecipe(specType)) then
								shouldTrack = true
							
							-- Recipes: check knowledge and quality
							elseif itemType == ITEMTYPE_FURNISHING and MasterThief:IsStandardRecipe(specType) then
								local known = IsItemLinkRecipeKnown(itemLink)
								local quality = GetItemLinkQuality(itemLink) - 1
								if not known and quality >= MasterThief.SavedVarsOptions.MinRecipeQuality then
									shouldTrack = true
								end
							
							-- Furnishing plans: check knowledge and quality
							elseif itemType == ITEMTYPE_FURNISHING and MasterThief:IsFurnishingPlan(specType) then
								local known = IsItemLinkRecipeKnown(itemLink)
								local quality = GetItemLinkQuality(itemLink) - 1
								if not known and quality >= MasterThief.SavedVarsOptions.MinRecipeQuality then
									shouldTrack = true
								end
							
							-- Other items: check sell price
							elseif sellPrice and sellPrice >= MasterThief.SavedVarsOptions.MinSellPrice then
								shouldTrack = true
							end
							
							-- ALWAYS track special items by ID regardless of filters
							local itemId = GetItemLinkItemId(itemLink)
							if itemId == 187747 or itemId == 197790 or itemId == 71779 or itemId == 73754 then
								shouldTrack = true
							end
							
							if shouldTrack then
								MasterThief:TrackItemLooted(itemLink, sellPrice, itemType)
							else
								MasterThief:TrackItemSkipped()
							end
							
							if pickpocketItemCount == 1 then
								MasterThief:TrackSuccessfulPickpocket()
								MT:RecordPickpocketForReticle()
							end
							
							zo_callLater(function()
								if pickpocketInProgress then pickpocketInProgress = false end
							end, 1000)
						end
					end
				end
			end)
			EVENT_MANAGER:RegisterForEvent(MasterThief.name, EVENT_LOOT_UPDATED, function (...) MasterThief:LootUpdated(...) end)
		elseif (iStealthState == 5 and MasterThief.SavedVarsOptions.AnnounceBeCareful) then
			local iStolenItems = MasterThief:CountStolenItems(1)
			local iStolenSpecials = MasterThief:CountStolenItems(2)
			if (iStolenItems + iStolenSpecials > 0) then 
				MasterThief:ShowMessage("|cFF3311"..GetString(MT_MISC_BE_CAREFUL).."|r", 2)
			else 
				MasterThief:ShowMessage(GetString(MT_MISC_BE_CAREFUL), 2)
			end
		elseif (iStealthState == 0 and bInSneak == true) then -- i am not in stealth mode, DEACTIVATE all EVENTS
			bInSneak = false
			MasterThief:ShowMessage(GetString(MT_MISC_SNEAKMODE_SLEEPING), 2)
			MT:CompanionOnLeaveStealth()
			EVENT_MANAGER:UnregisterForEvent(MasterThief.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
			EVENT_MANAGER:UnregisterForEvent(MasterThief.name, EVENT_LOOT_UPDATED) 
		end
end

----------------------------------------
-- EVENT REGISTRATION
----------------------------------------
function MT:SetEvents()
		-- Justice system events
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_OPEN_FENCE, function(...) MT.FenceOpened(...) end)
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_JUSTICE_GOLD_REMOVED, function(...) MT.JusticeGoldRemoved(...) end)
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_JUSTICE_STOLEN_ITEMS_REMOVED, function(...) MT.JusticeStolenItemsRemoved(...) end)
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, function(...) MT.BountyPayoff(...) end)
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_MONEY_UPDATE, function(...) MT.OnMoneyUpdate(...) end)
		
		-- Lockpicking events
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_BEGIN_LOCKPICK, function(...) MT.BEGIN_LOCKPICK(...) end)
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_LOOT_CLOSED, function(...) MT.LOOT_CLOSED(...) end)
		
		-- Change system autoloot setting
		MT:ChangeSystemSettings()
		
		-- Player death tracking
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_PLAYER_DEAD, function()
			MT:PlayerDied()
		end)
		
		-- Bounty polling (for real-time tracking)
		EVENT_MANAGER:RegisterForUpdate(MT.name .. "BountyPoll", 1000, function()
			local currentBounty = GetFullBountyPayoffAmount() or GetBounty() or 0
			
			if not MT.lastKnownBounty then
				MT.lastKnownBounty = currentBounty
			end
			
			if currentBounty ~= MT.lastKnownBounty then
				if currentBounty > MT.lastKnownBounty then
					hadBountyBeforeDeath = true
					bountyIncreaseTime = GetGameTimeMilliseconds()
				end
				
				MT:BountyChanged(currentBounty, MT.lastKnownBounty)
				MT.lastKnownBounty = currentBounty
			end
		end)
		
		-- Pickpocket, Thieves Trove, container, + companion blocking.
		local STR_PICKPOCKET = GetString(SI_GAMECAMERAACTIONTYPE21)
		local STR_SEARCH = GetString(SI_GAMECAMERAACTIONTYPE20)
		local trovesLootedThisSession = {}
		
		-- Returns true if Isobel's personal quest is currently active, exempting her
		-- from outlaw refuge blocking.
		local ISOBEL_QUEST_ID = 6790
		local function IsIsobelQuestActive()
			for i = 1, GetNumJournalQuests() do
				if GetJournalQuestId(i) == ISOBEL_QUEST_ID then
					return true
				end
			end
			return false
		end

		local _origStartInteraction = INTERACTIVE_WHEEL_MANAGER.StartInteraction
		INTERACTIVE_WHEEL_MANAGER.StartInteraction = function(self, interactionType, ...)
			local action, interactableName, _, isOwned = GetGameCameraInteractableActionInfo()
			local actionName = zo_strformat(SI_GAME_CAMERA_TARGET, action)

			-- Debug: uncomment to identify interaction values in chat
			-- d("[MT] type="..tostring(interactionType).." action="..tostring(actionName).." name="..tostring(interactableName).." owned="..tostring(isOwned))

			-- Outlaw Refuge / Thieves Den entry.
			-- Exempt if Isobel's personal quest "A Mother's Request" is active.
			if interactableName and (interactableName:lower():find("outlaw") or interactableName:lower():find("thieves den")) then
				if not IsIsobelQuestActive() then
					if MT:CompanionOnOutlawRefuge() then
						return true  -- blocked
					end
				end

			-- Paying bounty to a guard
			elseif interactionType == INTERACTION_PAY_BOUNTY then
				MT:CompanionOnPayBounty()
				
			-- Pickpocket detection and companion block
			elseif action and action:find("Pickpocket") then
				if MT:CompanionOnPickpocket() then
					return true  -- blocked
				end
				pickpocketInProgress = true
				pickpocketItemCount = 0
				zo_callLater(function()
					if pickpocketInProgress then pickpocketInProgress = false end
				end, 5000)

			-- Search interactions: Thieves Troves, stolen containers, and corpses.
			elseif actionName == STR_SEARCH then
				interactableName = zo_strformat("<<1>>", interactableName)
				local lowerName = interactableName:lower()
				if lowerName:find("trove") or (lowerName:find("thieves") and not lowerName:find("den")) then
					-- Thieves Trove — track stat and check companion
					local posx, posy = GetMapPlayerPosition("player")
					local key = string.format("%.3f_%.3f", posx, posy)
					if not trovesLootedThisSession[key] then
						trovesLootedThisSession[key] = true
						MT.SavedVarsLifetimeStats.thievesTrovesLooted = (MT.SavedVarsLifetimeStats.thievesTrovesLooted or 0) + 1
					else
						d("[DEBUG] Trove already counted at this location")
					end
					if MT:CompanionOnTroveOrContainer(true) then
						return true  -- blocked
					end
				elseif DoesUnitExist("reticleover") then
					-- Corpse — warn only, cannot reliably block
					MT:CompanionOnCorpse()
				else
					-- Container (not a trove, not a corpse) — blockable
					if MT:CompanionOnTroveOrContainer(false) then
						return true  -- blocked
					end
				end
			end
			
			return _origStartInteraction(self, interactionType, ...)
		end
		-- Blade of Woe tracking
		EVENT_MANAGER:RegisterForEvent(MT.name .. "_BoW", EVENT_COMBAT_EVENT, function(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
			if targetName and targetName ~= "" then
				bladeOfWoeEventCount = bladeOfWoeEventCount + 1
				
				if bladeOfWoeEventTimer then
					zo_removeCallLater(bladeOfWoeEventTimer)
				end
				
				bladeOfWoeEventTimer = zo_callLater(function()
					if bladeOfWoeEventCount > 0 then
						MT:TrackBladeOfWoeKill()
						MT:CompanionOnBladeOfWoe()
						bladeOfWoeEventCount = 0
						bladeOfWoeEventTimer = nil
					end
				end, 2000)
			end
		end)
		EVENT_MANAGER:AddFilterForEvent(MT.name .. "_BoW", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 76325)
		
		-- Blade of Woe synergy blocking/warning via SYNERGY object hook.
		-- ZO_PreHook on SYNERGY.OnSynergyAbilityChanged allows us to suppress the
		-- synergy prompt entirely (return true = blocked, same pattern as SynergyToggle).
		ZO_PreHook(SYNERGY, "OnSynergyAbilityChanged", function(self)
			local synergyName, synergyFile = GetSynergyInfo()
			if synergyFile and synergyFile:find("_darkbrotherhood_003") then
				-- Block or warn based on companion and settings
				if MT:CompanionOnBladeOfWoeAvailable() then
					-- Suppress the synergy prompt so the player can't activate BoW
					SHARED_INFORMATION_AREA:SetHidden(SYNERGY, true)
					return true
				end
			end
		end)
		
		-- Sneak mode setup: LOOT_UPDATED and INVENTORY_SINGLE_SLOT_UPDATE are
		-- managed by SetStealMode and only active while sneaking.
		EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_STEALTH_STATE_CHANGED, function(...) MT.CheckStealthMode(...) end)

		-- Companion DB Sanctuary detection (Mirri, Isobel)
		EVENT_MANAGER:RegisterForEvent(MT.name .. "_CompanionZone", EVENT_ZONE_CHANGED, function(_, zoneName, subZoneName, _, zoneId)
			MT:CompanionOnZoneChange(zoneName, subZoneName, zoneId)
		end)

		-- Companion: warn when arrested (all companions with warnOnArrested)
		EVENT_MANAGER:RegisterForEvent(MT.name .. "_CompanionArrest", EVENT_JUSTICE_BEING_ARRESTED, function()
			MT:CompanionOnArrested()
		end)
		
		MT:RegisterCompanionPerkEvents()
end

----------------------------------------
-- INITIALIZATION
----------------------------------------
function MT:Initialize()
	-- Load SavedVariables
	MT.SavedVarsValues = ZO_SavedVars:New("MasterThiefVars", 1, "Values", MT.StolenValuesDefault)
	MT.SavedVarsOptions = ZO_SavedVars:New("MasterThiefVars", 1, "Options", MT.OptionsDefault)
	MT.SavedVarsLoots = ZO_SavedVars:New("MasterThiefLoot", 1, nil, MT.LootlistItems.Worthful)
	MT.SavedVarsLifetimeStats = ZO_SavedVars:New("MasterThiefVars", 1, "LifetimeStats", MT.LifetimeStatsDefault)
	-- Initialize recipe qualities now that strings are loaded
	MT:InitializeRecipeQualities()
	MT.AccountSavedVariables = ZO_SavedVars:NewAccountWide("MasterThiefAccount", 1, nil, {
		LootList = {},
		KnownRecipes = {}
	})
	
	-- Initialize session stats
	MT.SessionStats = {}
	for key, value in pairs(MT.SessionStatsDefault) do
		if type(value) == "table" then
			MT.SessionStats[key] = {link = "", value = 0}
		else
			MT.SessionStats[key] = value
		end
	end
	
	-- Initialize session knowledge cache
	MT.SessionKnowledgeCache = {}
	
	-- Load scrollList data
	if not MT.SavedVarsLoots.Worthful then
		MT.SavedVarsLoots.Worthful = {}
	end
	
	scrollListData = {}
	for idx, obj in ipairs(MT.SavedVarsLoots.Worthful) do
		table.insert(scrollListData, {obj[1]})
	end
	
	-- Initialize variables
	stolenTotal = MT.SavedVarsValues.stolenValuesTotal
	gPlayerChar = GetUnitName("player")
	
	-- Wait for player activation for UI setup
	EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_PLAYER_ACTIVATED, function()
		ZO_PreHook("ZO_InventorySlot_ShowContextMenu", MasterThief.CreateContextMenuEntry)
		
		-- Create UI elements
		MT:CreateMessageBox()
		MT:RestorePosition()
		
		-- Register dialogs
		ZO_Dialogs_RegisterCustomDialog("MT_CONFIRM_RESET_LIFETIME", {
			title   = { text = GetString(MT_DIALOG_RESET_LIFETIME_TITLE) },
			mainText = { text = GetString(MT_DIALOG_RESET_LIFETIME_TEXT) },
			buttons = {
				{ text = GetString(MT_DIALOG_RESET_LIFETIME_CONFIRM), callback = function() MT:ResetLifetimeStats() end },
				{ text = GetString(MT_DIALOG_RESET_LIFETIME_CANCEL) },
			},
		})
		
		-- One-time migration: Move old SavedVarsValues.stolenValuesTotal to totalFencedGold
		if MasterThief.SavedVarsValues.stolenValuesTotal and MasterThief.SavedVarsValues.stolenValuesTotal > 0 then
			-- Only migrate if lifetime stats don't already have a value
			if not MasterThief.SavedVarsLifetimeStats.totalFencedGold or MasterThief.SavedVarsLifetimeStats.totalFencedGold == 0 then
				MasterThief.SavedVarsLifetimeStats.totalFencedGold = MasterThief.SavedVarsValues.stolenValuesTotal
				d("[MasterThief] Migrated fenced gold total to new stats system")
			end
			-- Clear the old value to prevent re-migration
			MasterThief.SavedVarsValues.stolenValuesTotal = 0
		end  -- Closes migration if
		
		-- Set default message delay if not set
		if not MasterThief.SavedVarsOptions.MessageBoxDelay or MasterThief.SavedVarsOptions.MessageBoxDelay < 2000 then
			MasterThief.SavedVarsOptions.MessageBoxDelay = 3000
		end

		-- Setup hooks and tooltips
		MT:InventarTooltip()
		MT:LootTooltip()
		
		-- Setup known recipes
		MT:SaveKnownRecipes(nil, false)
		
		-- Create settings menu (only once — EVENT_PLAYER_ACTIVATED can fire multiple times)
		if not MT._settingsMenuCreated then
			MT:CreateSettingsMenu()
			MT._settingsMenuCreated = true
		end
		
		-- Setup chat button
		if LibChatMenuButton then
			local button = LibChatMenuButton.addChatButton(
				"MasterThief",
				"/esoui/art/icons/servicemappins/servicepin_fence.dds",
				"Toggle MasterThief Loot Window",
				function() MT:ToggleLootlistWindow() end
			)
			if button then button:show() end
		end

		-- Add context menu for marking items
		if LibCustomMenu then
			local function AddMasterThiefMenu(inventorySlot, slotActions)
				local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
				
				if not bagId or not slotIndex then return end
				
				local itemLink = GetItemLink(bagId, slotIndex)
				
				-- Only show for stolen items that aren't already on the list
				if IsItemStolen(bagId, slotIndex) then
					local alreadyOnList = MasterThief:isWorthfulItemOnScrollList(itemLink)
					
					if not alreadyOnList then
						slotActions:AddCustomSlotAction(
							SI_ITEM_ACTION_MASTERTHIEF_MARK,
							function()
								MasterThief:addToLootList(itemLink)  -- Use existing function
							end,
							"secondary"
						)
					end
				end
			end
			
			LibCustomMenu:RegisterContextMenu(AddMasterThiefMenu, LibCustomMenu.CATEGORY_PRIMARY)
		end
		
		-- Setup all event handlers
		MT:SetEvents()
		MT:InitPickpocketCounter()
		
		-- Initialize stealth mode if active
		local stealthState = GetUnitStealthState("player")
			if stealthState == 3 then
				bInSneak = false
			else
				bInSneak = true
			end
			MT:SetStealMode(stealthState)
		
		-- Mark as initialized
		MT._initialized = true
		CALLBACK_MANAGER:FireCallbacks("MasterThief_Initialized")
		EVENT_MANAGER:UnregisterForEvent(MT.name, EVENT_PLAYER_ACTIVATED)
	end)
end

----------------------------------------
-- ADDON LOAD HANDLER
----------------------------------------
function MT.OnAddOnLoaded(event, addonName)
	if addonName == MT.name then
		MT:Initialize()
	end
end

EVENT_MANAGER:RegisterForEvent(MT.name, EVENT_ADD_ON_LOADED, MT.OnAddOnLoaded)

----------------------------------------
-- SLASH COMMANDS
----------------------------------------
local function MTDestroyUselessItemsFromBag(value)
	if value == "delete" then
		MT:DestroyUselessItems(true)
	else
		MT:DestroyUselessItems(false)
	end
end

local function MTDisplayHelp()
	d(GetString(MT_MISC_MASTERTHIEF_COMMANDS))
	d("/mt_junk = " .. GetString(MT_MISC_CMD_LIST_ALL_USELESS_ITEMS))
	d("/mt_junk delete = " .. GetString(MT_MISC_CMD_DESTROY_ALL_USELESS_ITEMS))
	d("/mtloot = " .. GetString(MT_MISC_LOOTLIST_TEXT))
end

SLASH_COMMANDS["/masterthief"] = MTDisplayHelp
SLASH_COMMANDS["/mt_junk"] = MTDestroyUselessItemsFromBag
SLASH_COMMANDS["/mtloot"] = function() MT:ToggleLootlistWindow() end