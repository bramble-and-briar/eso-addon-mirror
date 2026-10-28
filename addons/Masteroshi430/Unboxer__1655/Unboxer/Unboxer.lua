Unboxer = {
    name = "Unboxer",
    title = GetString(SI_UNBOXER),
    author = "silvereyes, |c3CB371@Masteroshi430|r",
    version = "2026.10.27", -- 3.9.3
    itemSlotStack = {},
    defaultLanguage = "en",
    debugMode = false,
    classes = {
        rules = {},
    },
    rules = {},
    submenuOptions = {},
    containerItemTypes = {
        [ITEMTYPE_CONTAINER]          = true,
        [ITEMTYPE_CONTAINER_CURRENCY] = true,
        [ITEMTYPE_COLLECTIBLE]        = true,
		    [ITEMTYPE_CONTAINER_STACKABLE]  = true,
    },
    slotTypes = {
        [SLOT_TYPE_ITEM]                       = true,
        [SLOT_TYPE_EQUIPMENT]                  = true,
        [SLOT_TYPE_BANK_ITEM]                  = true,
        [SLOT_TYPE_GUILD_BANK_ITEM]            = true,
        [SLOT_TYPE_MY_TRADE]                   = true,
        [SLOT_TYPE_MAIL_QUEUED_ATTACHMENT]     = true,
        [SLOT_TYPE_TRADING_HOUSE_POST_ITEM]    = true,
        [SLOT_TYPE_REPAIR]                     = true,
        [SLOT_TYPE_CRAFTING_COMPONENT]         = true,
        [SLOT_TYPE_PENDING_CRAFTING_COMPONENT] = true,
        [SLOT_TYPE_DYEABLE_EQUIPMENT]          = true,
        [SLOT_TYPE_GUILD_SPECIFIC_ITEM]        = true,
        [SLOT_TYPE_GAMEPAD_INVENTORY_ITEM]     = true,
        [SLOT_TYPE_CRAFT_BAG_ITEM]             = true,
        [SLOT_TYPE_PENDING_RETRAIT_ITEM]       = true,
    },
    slotUniqueContentItemIds = {},
}

local addon = Unboxer
local LCM = LibCustomMenu
local GetItemLinkQuality = GetItemLinkFunctionalQuality or GetItemLinkQuality

-- Output formatted message to chat window, if configured
function addon.Print(input)
    local self = addon
    local output = self.prefix .. input .. self.suffix
    self.chat:Print(output)
end

-- Same as Print, but successive messages with the same text are not printed
local printOnceLastInput
function addon.PrintOnce(input)
    if printOnceLastInput and input == printOnceLastInput then
        return
    end
    addon.Print(input)
    printOnceLastInput = input
end

--[[ 
     Cheap pre-check for whether a Debug() call would actually log anything.
     Lua evaluates a function call's arguments before the call happens, so
     addon.Debug("..." .. tostring(x) .. "...", debug) always builds the full
     message string even when logging is disabled (the default). On hot paths
     (fired per loot item, per inventory slot update, per unboxable check),
     that string-building/zo_strformat cost adds up fast for no benefit.
     Call sites on hot paths should guard with:
         if addon.IsDebugEnabled(debug) then addon.Debug("...", debug) end
     so the concatenation is skipped entirely when nobody's going to see it.
]]--
function addon.IsDebugEnabled(force)
    return force or Unboxer.debugMode
end
function addon.Debug(input, force)
    if not addon.IsDebugEnabled(force) then
        return
    end
    d("[UB-DEBUG] " .. input)
end
--[[ 
     Caches of GetString(stringId) .. LocaleAwareToLower() results, keyed by stringId.
     Every rule's Match() function calls StringContainsStringIdOrDefault() with a fixed,
     hardcoded string id on every single item examined. The looked-up/lowercased string
     never changes during a session (locale doesn't change without a UI reload), so
     recomputing it on every call is pure waste. Only cache the no-vararg case, since
     that's the only way any rule in this addon calls it.
]]--
local resolvedStringCache = {}
local resolvedDefaultStringCache = {}
function addon:StringContainsStringIdOrDefault(searchIn, stringId, ...)
    if not stringId then
        return
    end
    local hasVarArgs = select("#", ...) > 0
    local searchFor
    if hasVarArgs then
        searchFor = LocaleAwareToLower(GetString(stringId, ...))
    else
        searchFor = resolvedStringCache[stringId]
        if searchFor == nil then
            searchFor = LocaleAwareToLower(GetString(stringId))
            resolvedStringCache[stringId] = searchFor
        end
    end
    local startIndex, endIndex
    if searchFor and searchFor ~= "" then
        startIndex, endIndex = string.find(searchIn, searchFor)
    end
    if startIndex or self:IsDefaultLanguageSelected() then
        return startIndex, endIndex
    end
    -- Default strings are stored at the next esostrings index higher.
    -- See localization/CreateStrings.lua for initialization logic that guarantees this.
    local defaultStringId
    if type(stringId) == "string" then
        defaultStringId = _G[stringId] + 1
    else
        defaultStringId = stringId + 1
    end
    if hasVarArgs then
        searchFor = LocaleAwareToLower(GetString(defaultStringId, ...))
    else
        searchFor = resolvedDefaultStringCache[defaultStringId]
        if searchFor == nil then
            searchFor = LocaleAwareToLower(GetString(defaultStringId))
            resolvedDefaultStringCache[defaultStringId] = searchFor
        end
    end
    if searchFor and searchFor ~= "" then
        return string.find(searchIn, searchFor)
    end
end
local localeUsesDifferentPunctuationColon = GetString(SI_UNBOXER_PUNCTUATION_COLON) ~= ":"
function addon:StringContainsPunctuationColon(searchIn)
    if string.find(searchIn, ":") then
        return true
    end
    if localeUsesDifferentPunctuationColon 
       and string.find(searchIn, GetString(SI_UNBOXER_PUNCTUATION_COLON))
    then
        return true
    end
end
function addon:StringContainsNotAtStart(searchIn, stringId, ...)
    local startIndex, endIndex = self:StringContainsStringIdOrDefault(searchIn, stringId, ...)
    if not startIndex or startIndex == 1 then return end
    return startIndex, endIndex
end

function addon:IsItemLinkUnboxable(itemLink, slotData, autolooting)
  
    if not itemLink then return false end
    
    local itemType = GetItemLinkItemType(itemLink)
    if not self.containerItemTypes[itemType] then 
        return false
    end
    
    local data = self:GetItemLinkData(itemLink, nil, slotData)
    
    -- not sure why there's no item id, but return false to be safe
    if not data.itemId then return false end
	
	-- Only autoloot stolen while in stealth
	if addon.settings.noAutoLootStolen and autolooting then
	   local isStolen = IsItemLinkStolen(itemLink)
	   local stealthState = GetUnitStealthState("player")
	   local isPlayerHidden = stealthState == STEALTH_STATE_HIDDEN or stealthState == STEALTH_STATE_STEALTH
	   if isStolen and not isPlayerHidden then
	      return false
	   end
	end
    
    -- Detect containers that are protected due to a cooldown (e.g. Rewards for the Worthy)
    if self.protector:IsCooldownProtected(data.itemId) and self.protector:GetCooldownRemaining(data.itemId)
    then
        return false, data.rule
    end
    
    -- No rules matched
    if not data.rule then
        return false
    end
    
    local isUnboxable = data.isUnboxable and data.rule:IsEnabled()
    if not isUnboxable then
        return false, data.rule
    end
    
    if autolooting and not data.rule:IsAutolootEnabled() then
        return false, data.rule
    end
    
    -- Check inventory for any known unique items that the container contains
    if slotData and slotData.slotIndex and self.slotUniqueContentItemIds[slotData.slotIndex] then
        local slotUniqueItemIds = {}
        
        for bagId, itemIds in pairs(self.unboxAll.uniqueItemSlotIndexes) do
            for _, slotUniqueItemId in pairs(itemIds) do
                slotUniqueItemIds[slotUniqueItemId] = true
            end
        end
        for uniqueItemId, _ in pairs(self.slotUniqueContentItemIds[slotData.slotIndex]) do
            if slotUniqueItemIds[uniqueItemId] then
                isUnboxable = false
                break
            end
        end
    end
    
    return isUnboxable, data.rule
end

function addon:IsItemUnboxable(bagId, slotIndex, autolooting)
    if bagId ~= BAG_BACKPACK then return false end
    
    local itemLink = GetItemLink(bagId, slotIndex)
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex)
	
	-- Only autoloot stolen while in stealth
	if addon.settings.noAutoLootStolen and autolooting then
	   local isStolen = IsItemStolen(bagId, slotIndex)
	   local stealthState = GetUnitStealthState("player")
	   local isPlayerHidden = stealthState == STEALTH_STATE_HIDDEN or stealthState == STEALTH_STATE_STEALTH
	   if isStolen and not isPlayerHidden then
	      return false
	   end
	end

    local unboxable, matchedRule = self:IsItemLinkUnboxable(itemLink, slotData, autolooting)    
    local usable, onlyFromActionSlot = IsItemUsable(bagId, slotIndex)
    if self.IsDebugEnabled() then
        self.Debug(tostring(itemLink)..", unboxable: "..tostring(unboxable)..", usable: "..tostring(usable)..", onlyFromActionSlot: "..tostring(onlyFromActionSlot)..", matchedRule: "..(matchedRule and matchedRule.name or ""))
    end
    return unboxable and usable and not onlyFromActionSlot, matchedRule
end

local isDefaultLanguageSelectedCache
function addon:IsDefaultLanguageSelected()
    if isDefaultLanguageSelectedCache == nil then
        isDefaultLanguageSelectedCache = GetCVar("language.2") == self.defaultLanguage
    end
    return isDefaultLanguageSelectedCache
end

function addon:GetItemLinkData(itemLink, language, slotData)
    
    local itemId = GetItemLinkItemId(itemLink)
    local itemType, specializedItemType
    if slotData then
        itemType = slotData.itemType
        specializedItemType = slotData.specializedItemType
        if not slotData.bindType then
            slotData.bindType = GetItemLinkBindType(itemLink)
        end
        if not slotData.flavorText then
            slotData.flavorText = GetItemLinkFlavorText(itemLink)
        end
        if not slotData.collectibleId then
            local collectibleId = GetItemLinkContainerCollectibleId(itemLink)
            if collectibleId > 0 then
                slotData.collectibleId = collectibleId
            end
        end
    else
        slotData = {}
        itemType, specializedItemType = GetItemLinkItemType(itemLink)
    end
    local icon = LocaleAwareToLower(slotData.iconFile or GetItemLinkIcon(itemLink))
    local name = LocaleAwareToLower(slotData.name or GetItemLinkTradingHouseItemSearchName(itemLink))
    local quality = slotData.quality or GetItemLinkQuality(itemLink)
    local flavorText = LocaleAwareToLower(slotData.flavorText or GetItemLinkFlavorText(itemLink))
    local bindType = slotData.bindType or GetItemLinkBindType(itemLink)
    local collectibleId = slotData.collectibleId or GetItemLinkContainerCollectibleId(itemLink)
    if type(collectibleId) == "number" and collectibleId > 0 and not slotData.collectibleCategoryType then
        slotData["collectibleCategoryType"] = GetCollectibleCategoryType(collectibleId)
        slotData["collectibleUnlocked"]     = IsCollectibleUnlocked(collectibleId)
    end

    local data = {
        ["itemId"]                  = itemId,
        ["itemLink"]                = itemLink,
        ["itemType"]                = itemType,
        ["specializedItemType"]     = specializedItemType,
        ["bindType"]                = bindType,
        ["name"]                    = name,
        ["flavorText"]              = flavorText,
        ["quality"]                 = quality,
        ["icon"]                    = icon,
        ["collectibleId"]           = collectibleId,
        ["collectibleCategoryType"] = slotData["collectibleCategoryType"],
        ["collectibleUnlocked"]     = slotData["collectibleUnlocked"],
    }
  
    data["containerType"] = "unknown"
    -- O(1) lookup instead of scanning every rule's knownIds table in order.
    local candidateRule = self.knownIdRuleLookup and self.knownIdRuleLookup[itemId]
    if candidateRule and candidateRule:MatchKnownIds(data) then
        data["containerType"] = candidateRule.name
        if data["isUnboxable"] == nil then
            data["isUnboxable"] = slotData["collectibleUnlocked"] == nil or not slotData["collectibleUnlocked"]
        end
        data.rule = candidateRule
    end
    if not data.rule then
        for _, rule in ipairs(self.rules) do
            if rule:Match(data) then
                data["containerType"] = rule.name
                if data["isUnboxable"] == nil then
                    data["isUnboxable"] = slotData["collectibleUnlocked"] == nil or not slotData["collectibleUnlocked"]
                end
                data.rule = rule
                break
            end
        end
    end
    return data
end
function addon.PrintUnboxedLink(itemLink)
    local self = addon
    if not itemLink 
       or not self.settings 
       or not self.settings.chatContainerOpen
    then
        return
    end
    if self.settings.chatContainerIcons then
        itemLink = string.format("|t90%%:90%%:%s|t%s", GetItemLinkIcon(itemLink), itemLink)
    end
    self.Print(zo_strformat(SI_UNBOXER_UNBOXED, itemLink))
end
local function InventoryStateChange(oldState, newState)
    if newState == SCENE_SHOWING then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(addon.unboxAllKeybindButtonGroup)
    end
end
function addon:GetKeybindName()
    if self.unboxAll:IsActive() then
        return GetString(SI_UNBOXER_CANCEL)
    else
        return GetString(SI_UNBOXER_UNBOX_ALL)
    end
end
local function RefreshUnboxAllKeybind()
    local self = addon
    self.unboxAllKeybindButton.name = self:GetKeybindName()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.unboxAllKeybindButtonGroup)
end

local function OnContainerOpened(itemLink, lootReceived, rule)
    local self = addon
    self.PrintUnboxedLink(itemLink)
    if not rule then
        self.Debug("No match rule passed to 'Opened' callback")
    elseif not addon.settings.chatContentsSummary.enabled then
        self.Debug("All chat summaries are disabled.")
    elseif not rule:IsSummaryEnabled() then
        self.Debug("Rule "..rule.name.." is not configured to output summaries.")
    else
        if #lootReceived == 0 then
            self.Debug("'Opened' callback parameter 'lootReceived' contains no items.")
        end
        for _, loot in ipairs(lootReceived) do
            if loot.lootedBySelf and loot.lootType == LOOT_TYPE_ITEM then
                self.summary:AddItemLink(loot.itemLink, loot.quantity)
            end
        end
        self.summary:IncrementCounter()
    end
    addon.Debug("Opened " .. tostring(itemLink) .. " containing " .. tostring(#lootReceived) .. " items. Matched rule "
                .. (rule and rule.name or ""))
    RefreshUnboxAllKeybind()
end

function addon.CancelUnboxAll()
    local self = addon
    self.unboxAll:Reset()
    RefreshUnboxAllKeybind()
    -- Print summary
    self.summary:Print()
    return true
end
function addon.UnboxAll()
    local self = addon
    
    if self.unboxAll:IsActive() then
        return self.CancelUnboxAll()
    end
    
    self.unboxAll:QueueAllInBackpack()
    
    if #self.unboxAll.queue == 0 then
        return false
    end
    
    self.unboxAll:SetAutoQueueManual(true)
    self.unboxAll:Start()
    return true
    
end

function addon:AddKeyBind()
    self.unboxAllKeybindButton = {
        keybind = "UNBOX_ALL",
        enabled = true,
        visible = function() return self.unboxAll:HasUnboxableSlots() end,
        order = 100,
        callback = self.UnboxAll,
    }
    self.unboxAllKeybindButtonGroup = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        self.unboxAllKeybindButton
    }
    BACKPACK_MENU_BAR_LAYOUT_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWN then
            self.unboxAllKeybindButton.name = self:GetKeybindName()
            KEYBIND_STRIP:AddKeybindButtonGroup(addon.unboxAllKeybindButtonGroup)
        elseif newState == SCENE_HIDING then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(addon.unboxAllKeybindButtonGroup)
        end
    end )
    INVENTORY_FRAGMENT:RegisterCallback("StateChange", InventoryStateChange)
end
--[[ 
     Builds a single itemId -> rule lookup table by merging every rule's knownIds table.
     Called once, after all rules are registered, so that GetItemLinkData() can resolve
     the vast majority of items (anything with a hardcoded itemId) in O(1) instead of
     scanning every rule's knownIds table in order on every single item link processed.
     Rules earlier in self.rules take priority for a given itemId, matching the original
     scan order.
]]--
function addon:BuildKnownIdLookup()
    local lookup = {}
    for _, rule in ipairs(self.rules) do
        for itemId, _ in pairs(rule:GetKnownIds()) do
            if lookup[itemId] == nil then
                lookup[itemId] = rule
            end
        end
    end
    self.knownIdRuleLookup = lookup
end
function addon:GetRuleInsertIndex(instance)
    
    for ruleIndex = 1, #self.rules do
        local rule = self.rules[ruleIndex]
        if rule:IsDependentUpon(instance) then
            return ruleIndex
        end
    end
    
    return #self.rules + 1
end
function addon:Namespace(ns)
    local nsTable = self.classes
    for scope in string.gmatch(ns, "%w+") do
        if not nsTable[scope] then
            nsTable[scope] = {}
        end
        nsTable = nsTable[scope]
    end
    return nsTable
end
function addon:RegisterCategoryRule(class)
    if type(class) == "string" then
        class = self.classes[class]
    end
    if not class then return end
    
    -- Create the new rule
    local rule = class:New()
    
    -- Get the index the new rule needs to be inserted at in
    -- order to satisfy existing rule dependencies on it.
    local insertIndex = self:GetRuleInsertIndex(rule)
    
    -- Detect rules that the new rule is dependent upon that need
    -- shifted up in priority to satisfy the dependency
    local rulesToMove = {}
    for ruleIndex=insertIndex + 1, #self.rules do
        local compareToRule = self.rules[ruleIndex]
        if rule:IsDependentUpon(compareToRule) then
            table.insert(rulesToMove, ruleIndex)
        end
    end
    
    -- Move the existing rules that need to be moved
    for _, ruleIndex in ipairs(rulesToMove) do
        local ruleToMove = table.remove(self.rules, ruleIndex)
        table.insert(self.rules, insertIndex, ruleToMove)
        insertIndex = insertIndex + 1
    end
    
    -- Register the new rule
    table.insert(self.rules, insertIndex, rule)
    
    return rule
end

local function AddContextMenu(inventorySlot, slotActions)
    local self = addon
    if not self.slotTypes[ZO_InventorySlot_GetType(inventorySlot)] then
        return
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or not slotIndex then
        return
    end
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex)
    if not slotData or not self.containerItemTypes[slotData.itemType] then
        return
    end
    
    local itemLink = GetItemLink(bagId, slotIndex)
    
    local data = addon:GetItemLinkData(itemLink, nil, slotData)
    if not data.rule or data.rule.hidden then
        return
    end
    
    local toggleRule = function() 
        self.settings[data.rule.name] = not self.settings[data.rule.name]
        RefreshUnboxAllKeybind()
    end
    local subMenu = {
        {
            label = "  " .. data.rule.title,
            callback = toggleRule,
            checked = function() return self.settings[data.rule.name] end,
            itemType = MENU_ADD_OPTION_CHECKBOX,
        }
    }
    
    AddCustomSubMenuItem(self.title, subMenu)
end

local function OnAddonLoaded(event, name)
  
    if name ~= addon.name then return end
    local self = addon
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)

    self:AddKeyBind()
    
    local rules = self.classes.rules
    self:RegisterCategoryRule(rules.hidden.Excluded)
    self:RegisterCategoryRule(rules.hidden.Excluded2)
    self:RegisterCategoryRule(rules.hidden.Excluded3)
    self:RegisterCategoryRule(rules.hidden.Pts)
    self:RegisterCategoryRule(rules.hidden.TreasureMaps)
    self:RegisterCategoryRule(rules.collectibles.Runeboxes)
    self:RegisterCategoryRule(rules.collectibles.StylePages)
    self:RegisterCategoryRule(rules.crafting.CraftingRewards)
    self:RegisterCategoryRule(rules.crafting.Materials)
	self:RegisterCategoryRule(rules.crafting.UnknownWrits)
	self:RegisterCategoryRule(rules.crafting.UnidentifiedSurveys)
    self:RegisterCategoryRule(rules.currency.TelVar)
    local transmutationRule = 
        self:RegisterCategoryRule(rules.currency.Transmutation)
    --if ITEMFILTERTYPE_COMPANION then -- removed because passives without the companion apparently not triggering the unboxing  
        self:RegisterCategoryRule(rules.general.Companions)
    --end
    self:RegisterCategoryRule(rules.general.Festival)
    self:RegisterCategoryRule(rules.general.Fishing)
    self:RegisterCategoryRule(rules.general.Legerdemain)
    self:RegisterCategoryRule(rules.general.ShadowySupplier)
    self:RegisterCategoryRule(rules.general.UnopenedTreasureMaps)
    self:RegisterCategoryRule(rules.rewards.Dragons)
    self:RegisterCategoryRule(rules.rewards.Dungeon)
    self:RegisterCategoryRule(rules.rewards.PvP)
    self:RegisterCategoryRule(rules.rewards.Solo)
    self:RegisterCategoryRule(rules.rewards.SoloRepeatable)
    self:RegisterCategoryRule(rules.rewards.Trial)
    self:RegisterCategoryRule(rules.rewards.Tribute)
    self:RegisterCategoryRule(rules.vendor.Furnisher)
    self:RegisterCategoryRule(rules.vendor.LoreLibraryReprints)
    self:RegisterCategoryRule(rules.vendor.VendorGear)
	self:RegisterCategoryRule(rules.currency.ArchivalFortunes)
    
    self:BuildKnownIdLookup()
    
    self:SetupSavedVars()
    
    self.unboxAll = self.classes.UnboxAll:New(self.unboxAll)
    self.unboxAll:RegisterCallback("Stopped", self.CancelUnboxAll)
    self.unboxAll:RegisterCallback("Opened", OnContainerOpened)
    self.unboxAll:RegisterCallback("BeforeOpen", RefreshUnboxAllKeybind)
    
    -- Protect Rewards for the Worthy containers when their transmutation geode loot is on 20-hour cooldown
    self.protector = self.classes.BoxProtector:New(self.unboxAll)
    local rewardsForTheWorthyItemIds = {145577, 146019, 146020, 146021, 146022, 146023, 146024, 146025, 146026, 146027, 146028, 146029, 146030, 146031, 146032, 146033, 146034, 146035, 146036, 134619, 181436, 204404, 184171, 190009, 194353, 190343, 210866, 214239, 224367} 
    local transmutationItemIds = {}
    for itemId, _ in pairs(transmutationRule:GetKnownIds()) do
        table.insert(transmutationItemIds, itemId)
    end
    table.sort(transmutationItemIds, function(a, b) return a > b end)
    self.protector:Protect( rewardsForTheWorthyItemIds, transmutationItemIds, ZO_ONE_HOUR_IN_SECONDS * 20 )
    
    --[[ Testing cooldown protection w/ Unfathomable Wooden Weapon boxes
    if false then
        local itemLinkFormatStringId = _G["SI_UNBOXER_ITEMLINK_FORMAT"]
        SafeAddVersion(itemLinkFormatStringId, 1)
        SafeAddString(itemLinkFormatStringId, "|H1:item:%u:424:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", 1)
        self.protector:Protect( {71230}, {43549,43556,43557,43558,43559,43560,45051,45052,45086,45087,45110,45118,45151,45154,45156,45189,45192,45285,45297}, ZO_ONE_DAY_IN_SECONDS )
    end]]
    
    self:SetupSettings()
    LCM:RegisterContextMenu(AddContextMenu, LCM.CATEGORY_LATE)
	local LSC = LibSlashCommander
	if LSC then
	    LSC:Register("/ub", function() Unboxer.UnboxAll() end, "["..GetString(SI_UNBOXER).."] "..GetString(SI_UNBOXER_UNBOX_ALL))
	else
	    SLASH_COMMANDS["/ub"] = function() Unboxer.UnboxAll()   end
	end
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
