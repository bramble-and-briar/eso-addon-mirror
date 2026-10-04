local LB = {}

LB.name = "Lagerblick"
LB.version = "2.0.2"
LB.savedVariablesName = "LagerblickSavedVariables"
LB.savedVariablesVersion = 1
LB.dataVersion = 2
LB.snapshotUpdateName = LB.name .. "_SnapshotUpdate"

local defaults = {
    welcomed = false,
    welcomeVersion = 0,
    dataVersion = 1,
    characters = {},
    companions = {},
}

local HOUSE_BANKS = {
    { bag = BAG_HOUSE_BANK_ONE,   option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_ONE,   number = 1 },
    { bag = BAG_HOUSE_BANK_TWO,   option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_TWO,   number = 2 },
    { bag = BAG_HOUSE_BANK_THREE, option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_THREE, number = 3 },
    { bag = BAG_HOUSE_BANK_FOUR,  option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_FOUR,  number = 4 },
    { bag = BAG_HOUSE_BANK_FIVE,  option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_FIVE,  number = 5 },
    { bag = BAG_HOUSE_BANK_SIX,   option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_SIX,   number = 6 },
    { bag = BAG_HOUSE_BANK_SEVEN, option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_SEVEN, number = 7 },
    { bag = BAG_HOUSE_BANK_EIGHT, option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_EIGHT, number = 8 },
    { bag = BAG_HOUSE_BANK_NINE,  option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_NINE,  number = 9 },
    { bag = BAG_HOUSE_BANK_TEN,   option = INVENTORY_COUNT_BAG_OPTION_HOUSE_BANK_TEN,   number = 10 },
}

local COLOR_LINE    = { 0.82, 0.80, 0.73 }
local COLOR_TOTAL   = { 0.90, 0.84, 0.66 }
local COLOR_NONE    = { 0.68, 0.66, 0.60 }

local INLINE_SEPARATOR = "  |  "
local INLINE_WRAP_AT = 52
local MAX_LOCATION_LINES = 6

local function S(stringId)
    return GetString(stringId)
end

local function CleanText(text)
    if not text then
        return ""
    end
    return zo_strformat("<<1>>", text)
end

local function GetPlayerName()
    local name = GetRawUnitName("player")
    if not name or name == "" then
        name = GetUnitName("player")
    end
    if not name or name == "" then
        name = S(SI_LAGERBLICK_CURRENT_CHARACTER)
    end
    return CleanText(name)
end

local function GetLegacyItemKey(itemLink)
    if not itemLink or itemLink == "" then
        return nil
    end

    local payload = string.match(itemLink, "|H%d+:item:([^|]+)|h")
    if payload then
        return "item:" .. payload
    end

    return nil
end

local function RebuildItemLinkFromLegacyKey(key)
    if type(key) ~= "string" or string.sub(key, 1, 5) ~= "item:" then
        return nil
    end
    return "|H1:" .. key .. "|h|h"
end

local function NumberOrZero(value)
    return tonumber(value) or 0
end

local function BoolNumber(value)
    return value and 1 or 0
end

local function GetItemIdentityKey(itemLink)
    if not itemLink or itemLink == "" then
        return nil
    end

    local itemId = NumberOrZero(GetItemLinkItemId(itemLink))
    if itemId <= 0 then
        return GetLegacyItemKey(itemLink)
    end

    local itemType, specializedItemType = GetItemLinkItemType(itemLink)

    -- Crafted potions and poisons can share a base item id while their effects differ.
    -- Keep their complete item payload so different mixtures are never merged.
    if itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON then
        return GetLegacyItemKey(itemLink) or ("id:" .. tostring(itemId))
    end

    local traitType = 0
    if GetItemLinkTraitInfo then
        traitType = NumberOrZero(select(1, GetItemLinkTraitInfo(itemLink)))
    end

    local hasSet, setId = false, 0
    if GetItemLinkSetInfo then
        local hasItemSet, _, _, _, _, foundSetId = GetItemLinkSetInfo(itemLink, false)
        hasSet = hasItemSet == true
        setId = NumberOrZero(foundSetId)
    end

    local values = {
        "v2",
        itemId,
        NumberOrZero(itemType),
        NumberOrZero(specializedItemType),
        GetItemLinkFunctionalQuality and NumberOrZero(GetItemLinkFunctionalQuality(itemLink)) or 0,
        GetItemLinkRequiredLevel and NumberOrZero(GetItemLinkRequiredLevel(itemLink)) or 0,
        GetItemLinkRequiredChampionPoints and NumberOrZero(GetItemLinkRequiredChampionPoints(itemLink)) or 0,
        traitType,
        GetItemLinkItemStyle and NumberOrZero(GetItemLinkItemStyle(itemLink)) or 0,
        GetItemLinkAppliedEnchantId and NumberOrZero(GetItemLinkAppliedEnchantId(itemLink)) or 0,
        GetItemLinkFinalEnchantId and NumberOrZero(GetItemLinkFinalEnchantId(itemLink)) or 0,
        GetItemLinkEquipType and NumberOrZero(GetItemLinkEquipType(itemLink)) or 0,
        GetItemLinkArmorType and NumberOrZero(GetItemLinkArmorType(itemLink)) or 0,
        GetItemLinkWeaponType and NumberOrZero(GetItemLinkWeaponType(itemLink)) or 0,
        hasSet and setId or 0,
        GetItemLinkOnUseAbilityId and NumberOrZero(GetItemLinkOnUseAbilityId(itemLink)) or 0,
        GetItemLinkCombinationId and NumberOrZero(GetItemLinkCombinationId(itemLink)) or 0,
        IsItemLinkCrafted and BoolNumber(IsItemLinkCrafted(itemLink)) or 0,
    }

    for index, value in ipairs(values) do
        values[index] = tostring(value)
    end

    return table.concat(values, ":")
end

local function CountInventory(itemLink, option)
    if not itemLink or itemLink == "" or option == nil or not GetItemLinkInventoryCount then
        return 0
    end

    return NumberOrZero(GetItemLinkInventoryCount(itemLink, option))
end

local function AddBagToMaps(legacyTarget, identityTarget, bagId)
    if bagId == nil then
        return
    end

    local bagSize = NumberOrZero(GetBagSize(bagId))
    for slotIndex = 0, bagSize - 1 do
        local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
        if itemLink and itemLink ~= "" then
            local stackSize = NumberOrZero(GetSlotStackSize(bagId, slotIndex))
            if stackSize > 0 then
                local legacyKey = GetLegacyItemKey(itemLink)
                if legacyKey then
                    legacyTarget[legacyKey] = (legacyTarget[legacyKey] or 0) + stackSize
                end

                local identityKey = GetItemIdentityKey(itemLink)
                if identityKey then
                    identityTarget[identityKey] = (identityTarget[identityKey] or 0) + stackSize
                end
            end
        end
    end
end

local function CountBagByIdentity(itemLink, bagId)
    if not itemLink or itemLink == "" or bagId == nil then
        return 0
    end

    local identityKey = GetItemIdentityKey(itemLink)
    if not identityKey then
        return 0
    end

    local count = 0
    local bagSize = NumberOrZero(GetBagSize(bagId))
    for slotIndex = 0, bagSize - 1 do
        local candidateLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
        if candidateLink and candidateLink ~= "" and GetItemIdentityKey(candidateLink) == identityKey then
            count = count + NumberOrZero(GetSlotStackSize(bagId, slotIndex))
        end
    end

    return count
end

local function CountFurnitureVault(itemLink)
    if not itemLink or itemLink == "" then
        return 0
    end

    local nativeCount = 0
    if GetItemLinkStacks then
        nativeCount = NumberOrZero(select(5, GetItemLinkStacks(itemLink)))
    elseif INVENTORY_COUNT_BAG_OPTION_FURNITURE then
        nativeCount = CountInventory(itemLink, INVENTORY_COUNT_BAG_OPTION_FURNITURE)
    end

    if BAG_FURNITURE_VAULT == nil then
        return nativeCount
    end

    local targetItemId = NumberOrZero(GetItemLinkItemId(itemLink))
    if targetItemId <= 0 then
        return nativeCount
    end

    local scannedCount = 0
    local bagSize = NumberOrZero(GetBagSize(BAG_FURNITURE_VAULT))
    for slotIndex = 0, bagSize - 1 do
        local candidateLink = GetItemLink(BAG_FURNITURE_VAULT, slotIndex, LINK_STYLE_DEFAULT)
        if candidateLink and candidateLink ~= "" and NumberOrZero(GetItemLinkItemId(candidateLink)) == targetItemId then
            scannedCount = scannedCount + NumberOrZero(GetSlotStackSize(BAG_FURNITURE_VAULT, slotIndex))
        end
    end

    if scannedCount > 0 then
        return scannedCount
    end

    return nativeCount
end

local function BuildIdentityMapFromLegacy(legacyMap)
    if type(legacyMap) ~= "table" then
        return {}
    end

    local identityMap = {}
    for key, count in pairs(legacyMap) do
        count = NumberOrZero(count)
        if count > 0 then
            local itemLink = RebuildItemLinkFromLegacyKey(key)
            local identityKey = itemLink and GetItemIdentityKey(itemLink) or nil
            if identityKey then
                identityMap[identityKey] = (identityMap[identityKey] or 0) + count
            end
        end
    end

    return identityMap
end

local function GetSnapshotCount(entry, legacyField, identityField, itemLink)
    if type(entry) ~= "table" then
        return 0
    end

    local identityKey = GetItemIdentityKey(itemLink)
    if identityKey and type(entry[identityField]) == "table" then
        local count = NumberOrZero(entry[identityField][identityKey])
        if count > 0 then
            return count
        end
    end

    local legacyMap = entry[legacyField]
    if type(legacyMap) ~= "table" then
        return 0
    end

    if identityKey then
        local directIdentityCount = NumberOrZero(legacyMap[identityKey])
        if directIdentityCount > 0 then
            return directIdentityCount
        end
    end

    local legacyKey = GetLegacyItemKey(itemLink)
    if legacyKey then
        local exactCount = NumberOrZero(legacyMap[legacyKey])
        if exactCount > 0 then
            return exactCount
        end
    end

    local itemId = NumberOrZero(GetItemLinkItemId(itemLink))
    if itemId > 0 then
        local compatibilityKeys = {
            tostring(itemId),
            "id:" .. tostring(itemId),
            "itemid:" .. tostring(itemId),
            "itemId:" .. tostring(itemId),
            "stack:" .. tostring(itemId),
        }
        for _, key in ipairs(compatibilityKeys) do
            local count = NumberOrZero(legacyMap[key])
            if count > 0 then
                return count
            end
        end
    end

    return 0
end

function LB:GetHouseBankName(definition)
    if not definition or not definition.bag then
        return S(SI_LAGERBLICK_HOUSE_STORAGE)
    end

    if GetCollectibleForBag then
        local collectibleId = GetCollectibleForBag(definition.bag)
        if collectibleId and collectibleId > 0 then
            local name = GetCollectibleNickname and GetCollectibleNickname(collectibleId) or ""
            if name and name ~= "" then
                return CleanText(name)
            end

            name = GetCollectibleDefaultNickname and GetCollectibleDefaultNickname(collectibleId) or ""
            if name and name ~= "" then
                return CleanText(name)
            end

            name = GetCollectibleName and GetCollectibleName(collectibleId) or ""
            if name and name ~= "" then
                return CleanText(name)
            end
        end
    end

    return string.format("%s %d", S(SI_LAGERBLICK_HOUSE_STORAGE), definition.number or 0)
end

function LB:SaveCurrentCharacter()
    if not self.sv then
        return
    end

    local characterId = tostring(GetCurrentCharacterId() or "")
    if characterId == "" then
        return
    end

    local entry = self.sv.characters[characterId] or {}
    entry.name = GetPlayerName()
    entry.backpack = {}
    entry.worn = {}
    entry.backpackV2 = {}
    entry.wornV2 = {}

    AddBagToMaps(entry.backpack, entry.backpackV2, BAG_BACKPACK)
    AddBagToMaps(entry.worn, entry.wornV2, BAG_WORN)

    entry.snapshotVersion = self.dataVersion
    entry.updatedAt = GetTimeStamp()
    self.sv.characters[characterId] = entry

    self.currentCharacterId = characterId
    self.currentCharacterName = entry.name
end

function LB:SaveActiveCompanion()
    if not self.sv or BAG_COMPANION_WORN == nil or not HasActiveCompanion or not HasActiveCompanion() then
        return
    end

    local companionId = GetActiveCompanionDefId and NumberOrZero(GetActiveCompanionDefId()) or 0
    if companionId <= 0 then
        return
    end

    local entry = self.sv.companions[tostring(companionId)] or {}
    local name = GetCompanionName and GetCompanionName(companionId) or ""
    if name and name ~= "" then
        entry.name = CleanText(name)
    elseif not entry.name or entry.name == "" then
        entry.name = string.format("%s %d", S(SI_LAGERBLICK_COMPANION), companionId)
    end

    entry.worn = {}
    entry.wornV2 = {}
    AddBagToMaps(entry.worn, entry.wornV2, BAG_COMPANION_WORN)

    entry.snapshotVersion = self.dataVersion
    entry.updatedAt = GetTimeStamp()
    self.sv.companions[tostring(companionId)] = entry
end

function LB:SaveSnapshots()
    self:SaveCurrentCharacter()
    self:SaveActiveCompanion()
end

function LB:ScheduleSnapshot()
    if not self.sv then
        return
    end

    EVENT_MANAGER:UnregisterForUpdate(self.snapshotUpdateName)
    EVENT_MANAGER:RegisterForUpdate(self.snapshotUpdateName, 200, function()
        EVENT_MANAGER:UnregisterForUpdate(self.snapshotUpdateName)
        LB:SaveSnapshots()
    end)
end

local function AddRow(rows, label, count)
    count = NumberOrZero(count)
    if count <= 0 then
        return 0
    end

    rows[#rows + 1] = {
        label = label,
        count = count,
    }

    return count
end

function LB:GetLocations(itemLink)
    local identityKey = GetItemIdentityKey(itemLink)
    if not identityKey then
        return {}, 0
    end

    local rows = {}
    local total = 0
    local currentName = self.currentCharacterName or GetPlayerName()

    total = total + AddRow(rows, currentName, CountInventory(itemLink, INVENTORY_COUNT_BAG_OPTION_BACKPACK))
    total = total + AddRow(rows, currentName .. " (" .. S(SI_LAGERBLICK_EQUIPPED) .. ")", CountInventory(itemLink, INVENTORY_COUNT_BAG_OPTION_WORN))

    local activeCompanionId = 0
    if BAG_COMPANION_WORN ~= nil and HasActiveCompanion and HasActiveCompanion() then
        activeCompanionId = GetActiveCompanionDefId and NumberOrZero(GetActiveCompanionDefId()) or 0
        if activeCompanionId > 0 then
            local companionName = GetCompanionName and CleanText(GetCompanionName(activeCompanionId)) or ""
            if companionName == "" then
                companionName = string.format("%s %d", S(SI_LAGERBLICK_COMPANION), activeCompanionId)
            end
            total = total + AddRow(
                rows,
                companionName .. " (" .. S(SI_LAGERBLICK_COMPANION) .. ")",
                CountBagByIdentity(itemLink, BAG_COMPANION_WORN)
            )
        end
    end

    total = total + AddRow(rows, S(SI_LAGERBLICK_BANK), CountInventory(itemLink, INVENTORY_COUNT_BAG_OPTION_BANK))
    total = total + AddRow(rows, S(SI_LAGERBLICK_CRAFT_BAG), CountInventory(itemLink, INVENTORY_COUNT_BAG_OPTION_CRAFT_BAG))

    for _, definition in ipairs(HOUSE_BANKS) do
        if definition.option ~= nil then
            total = total + AddRow(rows, self:GetHouseBankName(definition), CountInventory(itemLink, definition.option))
        end
    end

    total = total + AddRow(rows, S(SI_LAGERBLICK_FURNITURE_VAULT), CountFurnitureVault(itemLink))

    local otherCharacters = {}
    local currentCharacterId = self.currentCharacterId or tostring(GetCurrentCharacterId() or "")

    for characterId, entry in pairs(self.sv.characters or {}) do
        if tostring(characterId) ~= currentCharacterId and type(entry) == "table" and entry.name then
            otherCharacters[#otherCharacters + 1] = {
                entry = entry,
                name = entry.name,
            }
        end
    end

    table.sort(otherCharacters, function(a, b)
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    for _, character in ipairs(otherCharacters) do
        local entry = character.entry
        total = total + AddRow(rows, character.name, GetSnapshotCount(entry, "backpack", "backpackV2", itemLink))
        total = total + AddRow(
            rows,
            character.name .. " (" .. S(SI_LAGERBLICK_EQUIPPED) .. ")",
            GetSnapshotCount(entry, "worn", "wornV2", itemLink)
        )
    end

    local companions = {}
    for companionId, entry in pairs(self.sv.companions or {}) do
        if NumberOrZero(companionId) ~= activeCompanionId and type(entry) == "table" and entry.name then
            companions[#companions + 1] = {
                entry = entry,
                name = entry.name,
            }
        end
    end

    table.sort(companions, function(a, b)
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    for _, companion in ipairs(companions) do
        total = total + AddRow(
            rows,
            companion.name .. " (" .. S(SI_LAGERBLICK_COMPANION) .. ")",
            GetSnapshotCount(companion.entry, "worn", "wornV2", itemLink)
        )
    end

    return rows, total
end

function LB:AddCenteredLine(tooltip, text, font, color)
    tooltip:AddLine(
        text,
        font,
        color[1], color[2], color[3],
        CENTER,
        MODIFY_TEXT_TYPE_NONE,
        TEXT_ALIGN_CENTER,
        true
    )
end

function LB:BuildInlineLines(rows)
    local lines = {}
    local currentRich = ""
    local currentPlain = ""
    local currentRowCount = 0

    for _, row in ipairs(rows) do
        local plainPiece = string.format("%s: %s", row.label, ZO_LocalizeDecimalNumber(row.count))
        local richPiece = string.format("%s: |cFFF6DE%s|r", row.label, ZO_LocalizeDecimalNumber(row.count))

        if currentPlain == "" then
            currentPlain = plainPiece
            currentRich = richPiece
            currentRowCount = 1
        else
            local candidatePlain = currentPlain .. INLINE_SEPARATOR .. plainPiece
            local candidateRich = currentRich .. INLINE_SEPARATOR .. richPiece

            if zo_strlen(candidatePlain) > INLINE_WRAP_AT then
                lines[#lines + 1] = {
                    rich = currentRich,
                    rowCount = currentRowCount,
                }
                currentPlain = plainPiece
                currentRich = richPiece
                currentRowCount = 1
            else
                currentPlain = candidatePlain
                currentRich = candidateRich
                currentRowCount = currentRowCount + 1
            end
        end
    end

    if currentRich ~= "" then
        lines[#lines + 1] = {
            rich = currentRich,
            rowCount = currentRowCount,
        }
    end

    return lines
end

function LB:AddTooltipInfo(tooltip, itemLink)
    if not tooltip or not itemLink or itemLink == "" then
        return
    end

    local identityKey = GetItemIdentityKey(itemLink)
    if not identityKey then
        return
    end

    if tooltip._lagerblickIdentityKey == identityKey then
        return
    end
    tooltip._lagerblickIdentityKey = identityKey

    local rows, total = self:GetLocations(itemLink)

    if ZO_Tooltip_AddDivider then
        ZO_Tooltip_AddDivider(tooltip)
    else
        tooltip:AddLine(" ")
    end

    if total > 0 then
        local inlineLines = self:BuildInlineLines(rows)
        if #inlineLines <= MAX_LOCATION_LINES then
            for _, line in ipairs(inlineLines) do
                self:AddCenteredLine(tooltip, line.rich, "ZoFontGame", COLOR_LINE)
            end
        else
            local visibleLineCount = MAX_LOCATION_LINES - 1
            local hiddenRows = 0

            for index, line in ipairs(inlineLines) do
                if index <= visibleLineCount then
                    self:AddCenteredLine(tooltip, line.rich, "ZoFontGame", COLOR_LINE)
                else
                    hiddenRows = hiddenRows + NumberOrZero(line.rowCount)
                end
            end

            if hiddenRows > 0 then
                self:AddCenteredLine(
                    tooltip,
                    zo_strformat(SI_LAGERBLICK_MORE_LOCATIONS, hiddenRows),
                    "ZoFontGame",
                    COLOR_NONE
                )
            end
        end
    else
        self:AddCenteredLine(tooltip, S(SI_LAGERBLICK_NOT_OWNED), "ZoFontGame", COLOR_NONE)
    end

    self:AddCenteredLine(
        tooltip,
        string.format("%s: |cFFF6DE%s|r", S(SI_LAGERBLICK_TOTAL), ZO_LocalizeDecimalNumber(total)),
        "ZoFontGameBold",
        COLOR_TOTAL
    )
end

function LB:PostHookTooltipMethod(tooltip, methodName, linkGetter)
    if not tooltip or type(tooltip[methodName]) ~= "function" or type(linkGetter) ~= "function" then
        return
    end

    ZO_PostHook(tooltip, methodName, function(control, ...)
        local ok, itemLink = pcall(linkGetter, ...)
        if ok and itemLink and itemLink ~= "" then
            LB:AddTooltipInfo(control, itemLink)
        end
    end)
end

function LB:InstallTooltipHooks()
    local function ResetTooltipMarker(control)
        control._lagerblickIdentityKey = nil
    end

    if ItemTooltip and type(ItemTooltip.ClearLines) == "function" then
        ZO_PostHook(ItemTooltip, "ClearLines", ResetTooltipMarker)
    end
    if PopupTooltip and type(PopupTooltip.ClearLines) == "function" then
        ZO_PostHook(PopupTooltip, "ClearLines", ResetTooltipMarker)
    end

    self:PostHookTooltipMethod(ItemTooltip, "SetBagItem", function(bagId, slotIndex)
        return GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    end)
    self:PostHookTooltipMethod(PopupTooltip, "SetBagItem", function(bagId, slotIndex)
        return GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    end)

    self:PostHookTooltipMethod(ItemTooltip, "SetWornItem", function(slotIndex)
        return GetItemLink(BAG_WORN, slotIndex, LINK_STYLE_DEFAULT)
    end)
    self:PostHookTooltipMethod(PopupTooltip, "SetWornItem", function(slotIndex)
        return GetItemLink(BAG_WORN, slotIndex, LINK_STYLE_DEFAULT)
    end)

    self:PostHookTooltipMethod(ItemTooltip, "SetAttachedMailItem", GetAttachedItemLink)
    self:PostHookTooltipMethod(ItemTooltip, "SetLootItem", GetLootItemLink)
    self:PostHookTooltipMethod(ItemTooltip, "SetStoreItem", GetStoreItemLink)
    self:PostHookTooltipMethod(ItemTooltip, "SetBuybackItem", GetBuybackItemLink)
    self:PostHookTooltipMethod(ItemTooltip, "SetTradeItem", GetTradeItemLink)
    self:PostHookTooltipMethod(ItemTooltip, "SetTradingHouseItem", GetTradingHouseSearchResultItemLink)
    self:PostHookTooltipMethod(ItemTooltip, "SetTradingHouseListing", GetTradingHouseListingItemLink)

    self:PostHookTooltipMethod(ItemTooltip, "SetLink", function(itemLink)
        return itemLink
    end)
    self:PostHookTooltipMethod(PopupTooltip, "SetLink", function(itemLink)
        return itemLink
    end)
end

function LB:RegisterBagChangeEvent(eventSuffix, bagId)
    if bagId == nil then
        return
    end

    local eventName = self.name .. "_" .. eventSuffix

    EVENT_MANAGER:RegisterForEvent(
        eventName,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function()
            LB:ScheduleSnapshot()
        end
    )

    EVENT_MANAGER:AddFilterForEvent(
        eventName,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID,
        bagId
    )
end

function LB:PrintStatus()
    local characterNames = {}
    local companionNames = {}

    for _, entry in pairs(self.sv.characters or {}) do
        if type(entry) == "table" and entry.name then
            characterNames[#characterNames + 1] = entry.name
        end
    end

    for _, entry in pairs(self.sv.companions or {}) do
        if type(entry) == "table" and entry.name then
            companionNames[#companionNames + 1] = entry.name
        end
    end

    table.sort(characterNames, function(a, b)
        return string.lower(a) < string.lower(b)
    end)
    table.sort(companionNames, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    local prefix = "|c7FC7FF[Lagerblick]|r "
    d(string.format("%sVersion %s", prefix, self.version))
    d(string.format("%s%s: %d", prefix, S(SI_LAGERBLICK_STORED_CHARACTERS), #characterNames))
    if #characterNames > 0 then
        d(prefix .. table.concat(characterNames, ", "))
    end

    d(string.format("%s%s: %d", prefix, S(SI_LAGERBLICK_STORED_COMPANIONS), #companionNames))
    if #companionNames > 0 then
        d(prefix .. table.concat(companionNames, ", "))
    end
end

function LB:HandleSlashCommand(text)
    text = string.lower(tostring(text or ""))
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")

    local prefix = "|c7FC7FF[Lagerblick]|r "

    if text == "scan" then
        self:SaveSnapshots()
        d(prefix .. S(SI_LAGERBLICK_RESCANNED))
        return
    end

    if text == "chars" or text == "characters" or text == "charaktere" or text == "status" then
        self:PrintStatus()
        return
    end

    d(prefix .. S(SI_LAGERBLICK_COMMANDS))
    d("/lagerblick scan  - " .. S(SI_LAGERBLICK_CMD_SCAN))
    d("/lagerblick chars - " .. S(SI_LAGERBLICK_CMD_CHARS))
    d("/lagerblick help  - " .. S(SI_LAGERBLICK_CMD_HELP))
    d("/lb               - " .. S(SI_LAGERBLICK_CMD_HELP))
end

function LB:OnPlayerActivated()
    zo_callLater(function()
        LB:SaveSnapshots()

        local welcomeVersion = NumberOrZero(LB.sv.welcomeVersion)
        if welcomeVersion < LB.dataVersion then
            LB.sv.welcomeVersion = LB.dataVersion
            LB.sv.welcomed = true
            local prefix = "|c7FC7FF[Lagerblick]|r "
            d(prefix .. S(SI_LAGERBLICK_READY))
            d(prefix .. S(SI_LAGERBLICK_LOGIN_ALL))
            d(prefix .. S(SI_LAGERBLICK_SUMMON_COMPANIONS))
        end
    end, 300)
end

local function CopyPlainTable(source)
    local copy = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CopyPlainTable(value)
        else
            copy[key] = value
        end
    end

    return copy
end

function LB:MigrateSnapshotData()
    self.sv.characters = type(self.sv.characters) == "table" and self.sv.characters or {}
    self.sv.companions = type(self.sv.companions) == "table" and self.sv.companions or {}

    for _, entry in pairs(self.sv.characters) do
        if type(entry) == "table" then
            if type(entry.backpackV2) ~= "table" then
                entry.backpackV2 = BuildIdentityMapFromLegacy(entry.backpack)
            end
            if type(entry.wornV2) ~= "table" then
                entry.wornV2 = BuildIdentityMapFromLegacy(entry.worn)
            end
        end
    end

    for _, entry in pairs(self.sv.companions) do
        if type(entry) == "table" and type(entry.wornV2) ~= "table" then
            entry.wornV2 = BuildIdentityMapFromLegacy(entry.worn)
        end
    end

    self.sv.dataVersion = self.dataVersion
end

function LB:InitializeSavedVariables()
    local savedVariableDefaults = defaults
    local root = _G[self.savedVariablesName]
    local oldAccountData

    -- v0.1.7 and older used the default shared namespace. Preserve that data once
    -- when moving to server/world-specific SavedVariables.
    if type(root) == "table"
        and type(root["Default"]) == "table"
        and type(root["Default"][GetDisplayName()]) == "table" then
        oldAccountData = root["Default"][GetDisplayName()]["$AccountWide"]
    end

    if type(oldAccountData) == "table" and oldAccountData.lagerblickWorldMigration ~= true then
        savedVariableDefaults = CopyPlainTable(oldAccountData)
        oldAccountData.lagerblickWorldMigration = true
    end

    self.sv = ZO_SavedVars:NewAccountWide(
        self.savedVariablesName,
        self.savedVariablesVersion,
        GetWorldName(),
        savedVariableDefaults
    )

    self:MigrateSnapshotData()
end

function LB:Initialize()
    self:InitializeSavedVariables()

    self:InstallTooltipHooks()
    self:RegisterBagChangeEvent("BackpackChanged", BAG_BACKPACK)
    self:RegisterBagChangeEvent("WornChanged", BAG_WORN)
    self:RegisterBagChangeEvent("CompanionWornChanged", BAG_COMPANION_WORN)

    EVENT_MANAGER:RegisterForEvent(
        self.name .. "_PlayerActivated",
        EVENT_PLAYER_ACTIVATED,
        function()
            LB:OnPlayerActivated()
        end
    )

    if EVENT_COMPANION_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(
            self.name .. "_CompanionActivated",
            EVENT_COMPANION_ACTIVATED,
            function()
                zo_callLater(function()
                    LB:SaveActiveCompanion()
                end, 250)
            end
        )
    end

    SLASH_COMMANDS["/lagerblick"] = function(text)
        LB:HandleSlashCommand(text)
    end

    SLASH_COMMANDS["/lb"] = function(text)
        LB:HandleSlashCommand(text)
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= LB.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(LB.name, EVENT_ADD_ON_LOADED)
    LB:Initialize()
end

EVENT_MANAGER:RegisterForEvent(LB.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
