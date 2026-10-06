MuchSmarterAutoLoot = MuchSmarterAutoLoot or {}
local MSAL = MuchSmarterAutoLoot
MSAL.version = "8.3.7"
MSAL.addonVersion = 80307
MSAL.author = "Lykeion"

local MSAL_NEVER_3RD_PARTY_WARNING = "msal_never_3rd_party_warning"
local MSAL_AUTOLOOT_CONFLICT = "msal_autoloot_conflict"
local MSAL_AUTOLOOT_DISABLE = "msal_autoloot_disable"
local MSAL_AUTOLOOT_DISMISS = "msal_autoloot_dismiss"
local chatboxPrefix = ZO_IsConsoleOrGameCoreUI() and
    "|c345e88[|r|c44637fA|r|c81785bL|r|cbf8c37+|r|cce912e] " or
    "|c345e88[|r|c44637fA|r|c536876u|r|c626d6dt|r|c727264o|r|c81785bL|r|c917d52o|r|ca08249o|r|caf8740t|r|cbf8c37+|r|cce912e] "
local chatboxLogColor = "|cce912e"
local WM = GetWindowManager()
local LAM2 = LibAddonMenu2
local LCK = LibCharacterKnowledge

local db
local dbAccount
local dbChar

local lastLootUpdatedTimetag = 0
local last3rdPartyMissingTimetag = 0
local lastCurtOverlimitTimetag = 0
local lastUnlockTimetag = 0
local unboxingQueue = {}
local setItemList = {}
local BLIST_TOKEN = 0
local WLIST_TOKEN = 1
local WLIST_JUNK_TOKEN = 2
local isRepetitiveGear = false
local isAllCurtLooted = true
local isUnboxing = false
local isBagContainer = false
local isJunkingBagContainerLeftovers = false
-- local isHarvesting = false
local isUsingVanillaAutoLoot = false
local isLALwaitingForUnboxingCraftReward = false
local isWritsRewardContainerLooting = false
local isProcessingLoot = false
local lootWindowClosed = false
local lootWindowSoundPlayed = false
local lootTooltipCleanupPending = false
local lootWindowUpdateOriginals = {}
local lootActivityTimestamp = 0
local chatlogSuffix = nil
local styleMatHadValidPrice = false
local disposeLogLines = {}
local currentNotLootedNameList = {}
local lastNotLootedNameList = {}
local unwantedNameList = {}
local unwantedLootIdList = {}
local autoDeconStation = nil
local autoDeconScanned = false
local isUniDecon = false
local stationTradeSkill = nil
local chatlogBuffer = {}
local chatlogFlushEpoch = 0
local nonLootDisposedBuffer = {}
local nonLootReceivedBuffer = {}
local nonLootFlushEpoch = 0
local lootWindowShortcutButton
local TSCApi = nil

-- local basezoneTreasureMapID = {
--     -- khenarthisroost
--     43695,43696,43697,43698,44939,45010,
--     -- bleakrock
--     43699,43700,44931, 
--     -- balfoyen
--     43701,43702,44928, 
--     -- strosmkai
--     43691,43692,44946, 
--     -- betnihk
--     43693,43694,44930, 
--     -- auridon
--     43625,43626,43627,43628,43629,43630,44927, 
--     -- grahtwood
--     43631,43632,43633,43634,43635,43636,44937, 
--     -- greenshade
--     43637,43638,43639,43640,43641,43642,44938, 
--     -- malabaltor
--     43643,43644,43645,43646,43647,43648,44940, 
--     -- reapersmarch
--     43649,43650,43651,43652,43653,43654,44941, 
--     -- stonefalls
--     43655,43656,43657,43658,43659,43660,44944, 
--     -- deshaan
--     43661,43662,43663,43664,43665,43666,44934, 
--     -- shadowfen
--     43667,43668,43669,43670,43671,43672,44943, 
--     -- eastmarch
--     43673,43674,43675,43676,43677,43678,44935, 
--     -- therift
--     43679,43680,43681,43682,43683,43684,44947, 
--     -- glenumbra
--     43507,43525,43527,43600,43509,43526,44936, 
--     -- stormhaven
--     43601,43602,43603,43604,43605,43606,44945, 
--     -- rivenspire
--     43607,43608,43609,43610,43611,43612,44942, 
--     -- alikr
--     43613,43614,43615,43616,43617,43618,44926, 
--     -- bangkorai
--     43619,43620,43621,43622,43623,43624,44929, 
--     -- coldharbour
--     43685,43686,43687,43688,43689,43690,44932,
--     -- cyro
--     43703,43704,43705,43706,43707,43708,43709,43710,43711,43712,43713,43714,43715,43716,43717,43718,43719,43720, 
--     -- craglorn
--     43721,43722,43723,43724,43725,43726,
-- }

-- Provided by @Masteroshi430 in the API Patch Note thread. Thank you!
local unknownWritIds = {
    217917,
    217918,
    217919,
    217920,
    217921,
    217922,
    217923
}
local unknownSurveyIds = {
    219849,
    219850,
    219851,
    219852,
    219853,
    219854
}
local unknownTreasureMapIds = {
    224681
}

local jewelryTraits = {
    [ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_INTRICATE] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_ORNATE] = true
}

local curtType = {
    CURT_ALLIANCE_POINTS,
    CURT_ENDLESS_DUNGEON,
    CURT_CROWNS,
    CURT_MONEY,
    CURT_CROWN_GEMS,
    CURT_STYLE_STONES,
    CURT_TELVAR_STONES,
    CURT_UNDAUNTED_KEYS,
    CURT_WRIT_VOUCHERS,
    CURT_IMPERIAL_FRAGMENTS,
    CURT_TRANSMUTE_CRYSTALS,
    CURT_SEALS,
    CURT_TOME_CHALLENGE_REROLLS,
    CURT_TOME_POINTS,
    CURT_TOME_POINT_CACHES,
    CURT_TOME_TOKENS,
    CURT_TRADE_BARS
}

local writRewardContainerSuffix = {
    "I",
    "II",
    "III",
    "IV",
    "V",
    "VI",
    "VII",
    "VIII",
    "IX",
    "X"
}

local iconReplacements = {
    [GetString(SI_ITEM_ACTION_LOOT_TAKE)] = "|t28:28:EsoUI/Art/help/help_tabicon_itemassistance_up.dds|t",
    [GetString(SI_ITEM_ACTION_MARK_AS_JUNK)] = "|t28:28:EsoUI/Art/inventory/inventory_tabicon_junk_up.dds|t",
    [GetString(MSAL_REGISTER_FOR_DECON_AND_JUNK)] = "|t30:30:EsoUI/Art/crafting/enchantment_tabicon_deconstruction_up.dds|t" ..
        "&" .. "|t28:28:EsoUI/Art/inventory/inventory_tabicon_junk_up.dds|t",
    [GetString(MSAL_REGISTER_FOR_DECON)] = "|t30:30:EsoUI/Art/crafting/enchantment_tabicon_deconstruction_up.dds|t",
    [GetString(SI_ITEMTRAITTYPE10)] = "|t24:24:EsoUI/Art/inventory/inventory_trait_ornate_icon.dds|t",
    [GetString(SI_ITEMTRAITTYPE9)] = "|t24:24:EsoUI/Art/inventory/inventory_trait_intricate_icon.dds|t",
    [GetString(MSAL_LOOT_EXISTING_STACKABLE_ITEM)] = "|t28:28:EsoUI/Art/inventory/inventory_currencytab_accountwide_up.dds|t",
    [GetString(SI_ITEM_ACTION_DESTROY)] = "|t28:28:EsoUI/Art/crafting/smithing_tabicon_refine_up.dds|t",
}

local cp160MaterialIds = {
    [64489] = true, -- Blacksmithing
    [64502] = true, -- Woodworking
    [64504] = true, -- Clothing Light
    [64506] = true, -- Clothing Medium
    [135146] = true -- Jewelry
}

local function IsCp160Material(link)
    return cp160MaterialIds[GetItemLinkItemId(link)]
end

local function IsIntricateSkillMaxed(link, itemType)
    local trait = GetItemLinkTraitInfo(link)
    if jewelryTraits[trait] and itemType == ITEMTYPE_ARMOR then
        return (GetSkillLineDynamicInfo(SKILL_TYPE_TRADESKILL, 6)) == 50
    elseif itemType == ITEMTYPE_ARMOR then
        local armorType = GetItemLinkArmorType(link)
        if armorType == ARMORTYPE_HEAVY then
            return (GetSkillLineDynamicInfo(SKILL_TYPE_TRADESKILL, 5)) == 50
        end
        return (GetSkillLineDynamicInfo(SKILL_TYPE_TRADESKILL, 2)) == 50
    elseif itemType == ITEMTYPE_WEAPON then
        local weaponType = GetItemLinkWeaponType(link)
        if weaponType == WEAPONTYPE_BOW or weaponType == WEAPONTYPE_HEALING_STAFF or weaponType == WEAPONTYPE_FIRE_STAFF or
            weaponType == WEAPONTYPE_FROST_STAFF or weaponType == WEAPONTYPE_LIGHTNING_STAFF then
            return (GetSkillLineDynamicInfo(SKILL_TYPE_TRADESKILL, 7)) == 50
        end
        return (GetSkillLineDynamicInfo(SKILL_TYPE_TRADESKILL, 5)) == 50
    end
    return true
end

local function OpenSettingsPanel()
    if ZO_IsConsoleOrGameCoreUI() then
        -- do nothing, since LAM2 is not supported on console
    else
        LAM2:OpenToPanel(MSAL.SettingsPanel)
    end
end

local function ApplyIcons(str)
    if not db.useIconsInLog then
        return str
    end
    for text, icon in pairs(iconReplacements) do
        str = string.gsub(str, text, icon)
    end
    return str
end

local function SendChatboxMessage(highlight, ...)
    CHAT_ROUTER:AddSystemMessage(...)
    if highlight then
        local chatSystem = ZO_GetChatSystem()
        chatSystem:Maximize()
        chatSystem.primaryContainer:FadeIn()
    end
end

local function ChatboxPrint(...)
    SendChatboxMessage(true, ...)
end

local function DebugPrint(...)
    SendChatboxMessage(false, ...)
end

local function FlushChatlogBuffer()
    if #chatlogBuffer == 0 then
        return
    end
    ChatboxPrint(chatboxPrefix .. ApplyIcons(table.concat(chatlogBuffer, GetString(SI_LIST_PERIOD_SEPARATOR))))
    chatlogBuffer = {}
end

local function addDisposeLog(action, entry)
    if not disposeLogLines[action] then
        disposeLogLines[action] = {}
    end
    table.insert(disposeLogLines[action], entry)
end

local function ChatboxLog(str)
    table.insert(chatlogBuffer, str)
    chatlogFlushEpoch = chatlogFlushEpoch + 1
    local epoch = chatlogFlushEpoch
    zo_callLater(function()
        if chatlogFlushEpoch == epoch then
            chatlogFlushEpoch = 0
            FlushChatlogBuffer()
        end
    end, GetLatency())
end

local function FlushNonLootBuffer()
    if #nonLootReceivedBuffer > 0 then
        local deduped, quantity = {}, {}
        for _, entry in ipairs(nonLootReceivedBuffer) do
            quantity[entry] = (quantity[entry] or 0) + 1
        end
        for _, entry in ipairs(nonLootReceivedBuffer) do
            if quantity[entry] then
                if quantity[entry] > 1 then
                    table.insert(deduped, entry .. " * " .. quantity[entry])
                else
                    table.insert(deduped, entry)
                end
                quantity[entry] = nil
            end
        end
        ChatboxLog(GetString(SI_ITEM_ACTION_LOOT_TAKE) .. GetString(MSAL_SPACE) ..
                       table.concat(deduped, GetString(SI_LIST_COMMA_SEPARATOR)))
        FlushChatlogBuffer()
        nonLootReceivedBuffer = {}
    end
    if next(nonLootDisposedBuffer) ~= nil then
        local parts = {}
        for action, links in pairs(nonLootDisposedBuffer) do
            local deduped, quantity = {}, {}
            for _, lnk in ipairs(links) do
                quantity[lnk] = (quantity[lnk] or 0) + 1
            end
            for _, lnk in ipairs(links) do
                if quantity[lnk] then
                    if quantity[lnk] > 1 then
                        table.insert(deduped, lnk .. " * " .. quantity[lnk])
                    else
                        table.insert(deduped, lnk)
                    end
                    quantity[lnk] = nil
                end
            end
            table.insert(parts, action .. GetString(MSAL_SPACE) .. table.concat(deduped, GetString(SI_LIST_COMMA_SEPARATOR)))
        end
        ChatboxLog(table.concat(parts, GetString(SI_LIST_PERIOD_SEPARATOR)))
        nonLootDisposedBuffer = {}
    end
end

local function scheduleNonLootFlush()
    nonLootFlushEpoch = nonLootFlushEpoch + 1
    local epoch = nonLootFlushEpoch
    zo_callLater(function()
        if nonLootFlushEpoch == epoch then
            nonLootFlushEpoch = 0
            FlushNonLootBuffer()
        end
    end, 300)
end

local function BufferItemDisposeLog(action, link)
    if not nonLootDisposedBuffer[action] then
        nonLootDisposedBuffer[action] = {}
    end
    table.insert(nonLootDisposedBuffer[action], link)
    scheduleNonLootFlush()
end

local function BufferItemReceivedLog(entry)
    table.insert(nonLootReceivedBuffer, entry)
    scheduleNonLootFlush()
end

local function DebugLog(str)
    if db.debugMode then
        DebugPrint(str)
    end
end

local function IsLootActive()
    if isProcessingLoot then
        DebugLog("IsLootActive: currently processing loot, returning true")
        return true
    end
    local gracePeriod = GetLatency() * 2 + 300
    DebugLog("IsLootActive: " .. tostring((GetGameTimeMilliseconds() - lootActivityTimestamp) < gracePeriod))
    return (GetGameTimeMilliseconds() - lootActivityTimestamp) < gracePeriod
end

local function IsItemLinkTradeable(link)
    local bindType = GetItemLinkBindType(link)
    return bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_ON_EQUIP or bindType == BIND_TYPE_UNSET
end

local function IsThirdPartyOptionValid(thirdPartyOption)
    if thirdPartyOption == "per tsc" then
        return TSCApi ~= nil
    elseif thirdPartyOption == "per ttc" then
        return TamrielTradeCentre ~= nil
    elseif thirdPartyOption == "per mm" then
        return MasterMerchant ~= nil
    elseif thirdPartyOption == "per att" then
        return ArkadiusTradeTools ~= nil and ArkadiusTradeTools.Modules ~= nil and ArkadiusTradeTools.Modules.Sales ~=
                   nil
    elseif thirdPartyOption == "per third" then
        return (TamrielTradeCentre ~= nil) or (MasterMerchant ~= nil) or
                   (ArkadiusTradeTools ~= nil and ArkadiusTradeTools.Modules ~= nil and ArkadiusTradeTools.Modules.Sales ~=
                       nil) or (TSCApi ~= nil)
    else
        return false
    end
end

local function IsCraftingWritRewardContainer(str)
    for _, suffix in ipairs(writRewardContainerSuffix) do
        if string.sub(str, -#suffix) == suffix then
            return true
        end
    end
    return false
end

-- local function IsItemKnownByAnyCharacter(item, server, includedCharIds, accountFilter)
--     if not LCK then
--         return true -- If LibCharacterKnowledge is not available, assume the item is known
--     end
--     local knowledgeList = LCK.GetItemKnowledgeList(item, server, includedCharIds, accountFilter)

--     for _, charInfo in pairs(knowledgeList) do
--         if charInfo.knowledge == LCK.KNOWLEDGE_KNOWN then
--             return true
--         end
--     end
--     return false
-- end

local function IsItemUnknownByAnyCharacter(item, server, includedCharIds, accountFilter)
    local knowledgeList = LCK.GetItemKnowledgeList(item, server, includedCharIds, accountFilter)

    for _, charInfo in pairs(knowledgeList) do
        if charInfo.knowledge ~= LCK.KNOWLEDGE_KNOWN then
            return true, charInfo.name
        end
    end
    return false
end

-- local function trimString(str)
--     local index = string.find(str, "%^")
--     if index then
--         local partBefore = string.sub(str, 1, index - 1)
--         return partBefore
--     else
--         return str
--     end
-- end


local function getStandardizeLowerName(str)
    -- str = trimString(str)
    str = LocalizeString(str)
    local result = string.gsub(str, "%s+", "")
    result = string.lower(result)
    return result
end

local function normalizeEquipSlot(slot)
    if slot == EQUIP_SLOT_RING2 then
        return EQUIP_SLOT_RING1
    end
    if slot == EQUIP_SLOT_OFF_HAND or slot == EQUIP_SLOT_BACKUP_MAIN or slot == EQUIP_SLOT_BACKUP_OFF then
        return EQUIP_SLOT_MAIN_HAND
    end
    return slot
end

local function CanGemifyItem(bagId, slotIndex)
   if IsItemFromCrownCrate(bagId, slotIndex) and not IsItemPlayerLocked(bagId, slotIndex) then
      local itemsRequired, gemsAwarded = GetNumCrownGemsFromItemManualGemification(bagId, slotIndex)
      return gemsAwarded > 0 and itemsRequired > 0
   end
   return false
end

local function IsSameSetItem(link1, link2)
    -- "|H0:item:162519:363:50:0:0:0:0:0:0:0:0:0:0:0:2048:102:0:0:0:0:0|h|h", "|H1:item:162519:364:50:5365:370:50:2:0:0:0:0:0:0:0:2049:102:0:1:0:377:0|h|h"
    local _, _, _, _, _, setId1 = GetItemLinkSetInfo(link1, false)
    local _, _, _, _, _, setId2 = GetItemLinkSetInfo(link2, false)
    if not setId1 or setId1 == 0 or not setId2 or setId2 == 0 then
        return false
    end
    if setId1 ~= setId2 then
        return false
    end

    local slot1 = GetItemLinkComparisonEquipSlots(link1)
    local slot2 = GetItemLinkComparisonEquipSlots(link2)
    if normalizeEquipSlot(slot1) ~= normalizeEquipSlot(slot2) then
        return false
    end
    -- if GetItemLinkItemType(link1) ~= GetItemLinkItemType(link2) then 
    --     return false 
    -- end
    -- end

    -- single handed and two handed weapons may return the same slot, need further check
    if GetItemLinkItemType(link1) == ITEMTYPE_WEAPON then
        return GetItemLinkWeaponType(link1) == GetItemLinkWeaponType(link2)
    end
    return true
end

local function ListEntryMatches(listEntry, link)
    if GetItemLinkItemId(listEntry) == GetItemLinkItemId(link) then
        return true
    end
    -- named item set might have different item ids but are essentially the same set piece
    if IsItemLinkSetCollectionPiece(link) then
        return IsSameSetItem(listEntry, link)
    end
    return false
end

local function itemOnList(link, token)
    local list
    if token == BLIST_TOKEN then
        list = db.blacklist
    elseif token == WLIST_TOKEN then
        list = db.whitelist
    elseif token == WLIST_JUNK_TOKEN then
        list = db.wlistJunk
    end

    if not list or #list == 0 then
        return false
    end
    for i = 1, #list, 1 do
        if ListEntryMatches(list[i], link) then
            return true
        end
    end
    return false
end

local function OverlimitWarning(curt)
    local tempLastExceedTime = lastCurtOverlimitTimetag
    lastCurtOverlimitTimetag = GetGameTimeMilliseconds()

    if GetGameTimeMilliseconds() - tempLastExceedTime > 20000 then
        ChatboxLog(zo_strformat(GetString(SI_QUEST_REWARD_MAX_CURRENCY_ERROR), GetCurrencyName(curt, false, false)))
    end
end

local function OnLockpickSuccess()
    lastUnlockTimetag = GetGameTimeMilliseconds()
end

-- local function OnInteractResult(_, ClientInteractResult, interactTargetName)
--     if ClientInteractResult ~= CLIENT_INTERACT_RESULT_SUCCESS then
--         return
--     end
--     zo_callLater(function()
--         if GetInteractionType() == INTERACTION_HARVEST then
--             isHarvesting = true
--         end
--     end, GetLatency() + 800)
-- end
-- 
-- local function OnInteractCancelled()
--     zo_callLater(function()
--         isHarvesting = false
--     end, GetLatency() + 800)
-- end

local function SellAllStolenJunk()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local totalSells, sellsUsed, _ = GetFenceSellTransactionInfo()
        if data.stolen == true and data.isJunk == true then
            if totalSells == sellsUsed then
                ChatboxLog(GetString(SI_STOREFAILURE23))
                break
            else
                SellInventoryItem(BAG_BACKPACK, data.slotIndex, data.stackCount)
            end
        end
    end
end

local function LaunderAllStolen()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local totalLaunders, laundersUsed, _ = GetFenceLaunderTransactionInfo()
        if data.stolen == true and data.isJunk == false and GetItemLaunderPrice(BAG_BACKPACK, data.slotIndex) > 0 then
            if totalLaunders == laundersUsed then
                ChatboxLog(GetString(SI_ITEMLAUNDERRESULT7))
                break
            else
                BufferItemDisposeLog(GetString(SI_FENCE_LAUNDER_TAB),
                    GetItemLink(BAG_BACKPACK, data.slotIndex))
                LaunderItem(BAG_BACKPACK, data.slotIndex,
                    math.min(math.min(data.stackCount, 100), (totalLaunders - laundersUsed)))
            end
        end
    end
end

local function scheduleWritsRewardLootEnd(timeout)
    EVENT_MANAGER:UnregisterForUpdate("MSAL_WRITS_REWARD_LOOT_END")
    EVENT_MANAGER:RegisterForUpdate("MSAL_WRITS_REWARD_LOOT_END", timeout, function()
        EVENT_MANAGER:UnregisterForUpdate("MSAL_WRITS_REWARD_LOOT_END")
        isWritsRewardContainerLooting = false
    end)
end

ZO_Dialogs_RegisterCustomDialog("MSAL_SELL_ALL_STOLEN_JUNK", {
    title = {
        text = SI_SELL_ALL_JUNK_KEYBIND_TEXT
    },
    mainText = {
        text = SI_ITEM_FORMAT_STR_PRIORITY_FENCE
    },
    buttons = {
        [1] = {
            text = SI_GROUP_FINDER_CONFIRM_EDIT_GROUP,
            callback = SellAllStolenJunk
        },
        [2] = {
            text = SI_DIALOG_DECLINE
        }
    }
})

ZO_Dialogs_RegisterCustomDialog("MSAL_LAUNDER_ALL_STOLEN", {
    title = {
        text = SI_FENCE_LAUNDER_TAB
    },
    mainText = {
        text = SI_DEFAULT_CONFIRM_INTERACTION_TITLE
    },
    buttons = {
        [1] = {
            text = SI_GROUP_FINDER_CONFIRM_EDIT_GROUP,
            callback = LaunderAllStolen
        },
        [2] = {
            text = SI_DIALOG_DECLINE
        }
    }
})

local function OnOpenStore()
    DebugLog("OnOpenStore called")
    if not db.autoSellJunk then
        return
    end

    local total = 0
    local soldItems = {}
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        if data.stolen == false and data.isJunk == true then
            total = total + data.sellPrice * data.stackCount
            if db.sellJunkLogEnabled then
                local link = GetItemLink(BAG_BACKPACK, data.slotIndex)
                soldItems[link] = (soldItems[link] or 0) + data.stackCount
            end
        end
    end
    if total > 0 then
        if db.sellJunkLogEnabled then
            local parts = {}
            for link, count in pairs(soldItems) do
                if count > 1 then
                    table.insert(parts, link .. " * " .. count)
                else
                    table.insert(parts, link)
                end
            end
            ChatboxLog((db.useIconsInLog and "|t28:28:EsoUI/Art/vendor/vendor_tabicon_sell_up.dds|t" or GetString(SI_ITEM_ACTION_SELL)) .. GetString(MSAL_SPACE) .. table.concat(parts, GetString(SI_LIST_COMMA_SEPARATOR)))
        end
        ChatboxLog(zo_strformat(GetString(MSAL_JUNK_SOLD_TOTAL), total, GetCurrencyName(CURT_MONEY, false, false)))
        if ZO_IsConsoleOrGameCoreUI() then
            SellAllJunk()
        else
            if db.skipDialog then
                SellAllJunk()
            else
                EVENT_MANAGER:RegisterForUpdate("MSAL_UPDATE_AUTO_SELL", 200, function()
                    if not ZO_Dialogs_IsShowingDialog() then
                        ZO_Dialogs_ShowDialog("SELL_ALL_JUNK")
                        EVENT_MANAGER:UnregisterForUpdate("MSAL_UPDATE_AUTO_SELL")
                    end
                end)
            end
        end
    end
end

local function OnOpenFence()
    DebugLog("OnOpenFence called")
    if not db.autoSellJunk then
        return
    end
    if AreAnyItemsStolen(BAG_BACKPACK) then
        local total = 0
        local soldItems = {}
        local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
        for _, data in pairs(filteredDataTable) do
            if data.stolen == true and data.isJunk == true then
                total = total + data.sellPrice * data.stackCount
                if db.sellJunkLogEnabled then
                    local link = GetItemLink(BAG_BACKPACK, data.slotIndex)
                    soldItems[link] = (soldItems[link] or 0) + data.stackCount
                end
            end
        end
        if total > 0 then
            if db.sellJunkLogEnabled then
                local parts = {}
                for link, count in pairs(soldItems) do
                    if count > 1 then
                        table.insert(parts, link .. " * " .. count)
                    else
                        table.insert(parts, link)
                    end
                end
                ChatboxLog((db.useIconsInLog and "|t28:28:EsoUI/Art/vendor/vendor_tabicon_sell_up.dds|t" or GetString(SI_ITEM_ACTION_SELL)) .. GetString(MSAL_SPACE) .. table.concat(parts, GetString(SI_LIST_COMMA_SEPARATOR)))
            end
            ChatboxLog(zo_strformat(GetString(MSAL_JUNK_SOLD_TOTAL), total, GetCurrencyName(CURT_MONEY, false, false)))
            if ZO_IsConsoleOrGameCoreUI() then
                SellAllStolenJunk()
            else
                if db.skipDialog then
                    SellAllStolenJunk()
                else
                    EVENT_MANAGER:RegisterForUpdate("MSAL_UPDATE_AUTO_SELL_STOLEN", 200, function()
                        if not ZO_Dialogs_IsShowingDialog() then
                            ZO_Dialogs_ShowDialog("MSAL_SELL_ALL_STOLEN_JUNK")
                            EVENT_MANAGER:UnregisterForUpdate("MSAL_UPDATE_AUTO_SELL_STOLEN")
                        end
                    end)
                end
            end
        end
    end
end

local function OnOpenLaunder()
    if not db.autoLaunder then
        return
    end
    if AreAnyItemsStolen(BAG_BACKPACK) then
        if ZO_IsConsoleOrGameCoreUI() then
            LaunderAllStolen()
        else
            if db.skipDialog then
                LaunderAllStolen()
            else
                EVENT_MANAGER:RegisterForUpdate("MSAL_UPDATE_AUTO_LAUNDER", 200, function()
                    if not ZO_Dialogs_IsShowingDialog() then
                        ZO_Dialogs_ShowDialog("MSAL_LAUNDER_ALL_STOLEN")
                        EVENT_MANAGER:UnregisterForUpdate("MSAL_UPDATE_AUTO_LAUNDER")
                    end
                end)
            end
        end
    end
end

local function OnInventoryUpdate(_, bagId, slotId, _, _, _, _)
    chatlogSuffix = nil
    local link = GetItemLink(bagId, slotId)
    local quality = GetItemLinkDisplayQuality(link)
    local isCrafted = IsItemLinkCrafted(link)
    local isBound = IsItemLinkBound(link)
    local isContainer = IsItemLinkContainer(link)
    local itemLinkType = GetItemLinkItemType(link)
    local isUnopened = itemLinkType == ITEMTYPE_CONTAINER_STACKABLE
    local isScript = itemLinkType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT
    local isTrash = itemLinkType == ITEMTYPE_TRASH
    local isFish = itemLinkType == ITEMTYPE_FISH
    local isGeode = itemLinkType == ITEMTYPE_CONTAINER_CURRENCY
    local isTreasure = itemLinkType == ITEMTYPE_TREASURE
    local isUncollected = not IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(link))
    local isSetItem = IsItemLinkSetCollectionPiece(link)
    local isCompanionGear = GetItemLinkActorCategory(link) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
    local itemid = GetItemLinkItemId(link)
    local name = LocalizeString("<<1>>", GetItemLinkName(link))
    local trait = GetItemLinkTraitInfo(link)
    local isOrnate = trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE or trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE or trait ==
                         ITEM_TRAIT_TYPE_JEWELRY_ORNATE
    local isIntricate =
        trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
    local isGear = itemLinkType == ITEMTYPE_WEAPON or itemLinkType == ITEMTYPE_ARMOR
    local isWeapon = itemLinkType == ITEMTYPE_WEAPON
    local isJewelry = jewelryTraits[trait] and itemLinkType == ITEMTYPE_ARMOR
    local isStolen = IsItemLinkStolen(link)
    local isUnresearched = isGear and CanItemLinkBeTraitResearched(link)
    local isRareWeaponTrait = trait == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
    local isRareArmorTrait = trait == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
    local isRareJewelryTrait =
        trait == ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY or trait == ITEM_TRAIT_TYPE_JEWELRY_HARMONY or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_INFUSED or trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_ORNATE or trait == ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_SWIFT or trait == ITEM_TRAIT_TYPE_JEWELRY_TRIUNE
    local isQuest = false -- unavailable
    local itemType, specializedItemType = GetItemLinkItemType(link)

    local onWhite = itemOnList(link, WLIST_TOKEN)
    local onWhiteJunk = itemOnList(link, WLIST_JUNK_TOKEN)
    local keepIntact = onWhite and not onWhiteJunk

    -- Writ reward container handoff
    if isContainer and IsCraftingWritRewardContainer(name) and (WritCreater or SimpleDailyCraft) then
        isWritsRewardContainerLooting = true
        scheduleWritsRewardLootEnd(30000)
    end
    if not IsLootActive() and isContainer and IsCraftingWritRewardContainer(name) then
        DebugLog("craft container detected")
        isLALwaitingForUnboxingCraftReward = true
        if WritCreater or SimpleDailyCraft then
            local addonName = (WritCreater and "LWC") or (SimpleDailyCraft and "SDC")
            chatlogSuffix = zo_strformat(GetString(MSAL_WRIT_REWARD_HANDOFF), addonName)
        end
    end

    if onWhiteJunk then
        if CanItemBeMarkedAsJunk(bagId, slotId) then
            SetItemIsJunk(bagId, slotId, true)
        end
        if quality >= db.printDisposeThreshold and not IsLootActive() then
            BufferItemDisposeLog(GetString(SI_ITEM_ACTION_MARK_AS_JUNK), link)
        end
    end

    local wasAutoBound = false
    local autoBindAction = nil
    if (db.autoBind and isSetItem and isUncollected and not isCompanionGear and not isCrafted and not isRepetitiveGear and
        not itemOnList(link, BLIST_TOKEN)) then
        BindItem(bagId, slotId)
        wasAutoBound = true
        if db.autoDisposeAfterBind then
            local action = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
            if db.gearDisposer == "junk" or db.gearDisposer == "decon and junk" then
                if quality < ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
                    SetItemIsJunk(bagId, slotId, true)
                    if db.gearDisposer == "decon and junk" and
                        (db.deconThreshold == 0 or quality >= db.deconThreshold) then
                        action = GetString(MSAL_REGISTER_FOR_DECON_AND_JUNK)
                    end
                    autoBindAction = action
                end
            elseif db.gearDisposer == "destroy" then
                if quality < ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
                    DestroyItem(bagId, slotId)
                    action = GetString(SI_ITEM_ACTION_DESTROY)
                    autoBindAction = action
                end
            end
        end
    end

    local scribingAutoJunked = false
    if (db.filters.scribing == "always loot" and db.filters.scribingAutoMark and isScript) then
        if not IsItemLinkTradeable(link) then
            local unknownByAnyChar = CanItemLinkBeUsedToLearn(link)
            if LCK then
                local anyUnknown = IsItemUnknownByAnyCharacter(link)
                unknownByAnyChar = unknownByAnyChar or anyUnknown
            end
            if not unknownByAnyChar then
                SetItemIsJunk(bagId, slotId, true)
                scribingAutoJunked = true
            end
        end
    end

    if isTreasure and isStolen and not itemOnList(link, WLIST_TOKEN) and not itemOnList(link, WLIST_JUNK_TOKEN) then
        if quality < db.stolenTreasureThreshold then
            DestroyItem(bagId, slotId)
            if quality >= db.printDisposeThreshold then
                BufferItemDisposeLog(GetString(SI_ITEM_ACTION_DESTROY), link)
            end
            return
        end
        if db.stolenTreasureThreshold > ITEM_DISPLAY_QUALITY_TRASH and
            quality >= db.printLootThreshold and IsLootActive() then
            BufferItemReceivedLog(link)
        end
    end

    if not itemOnList(link, WLIST_JUNK_TOKEN) and
        not itemOnList(link, WLIST_TOKEN) and
        not db.legacyMode and (isWritsRewardContainerLooting or not IsLootActive()) and
        not isCrafted
        -- and GetItemCreatorName(bagId, slotId) == GetUnitName("player")
            then
        local wouldNotLoot = isWritsRewardContainerLooting and itemOnList(link, BLIST_TOKEN)
        -- if wouldNotLoot then
        --     BufferItemReceivedLog(zo_strformat(GetString(MSAL_DELEGATED_LOOT_CONFLICT), link))
        -- end
        local filterKey, _ = MSAL.FilterItem(link, false, nil)
        if filterKey then
            DebugLog("Non-loot item matched filter: " .. filterKey)
            if quality >= db.printLootThreshold then
                local entry = link
                local postfix = ""
                if filterKey == "set" and isUncollected then
                    postfix = GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
                elseif filterKey == "unresearched" then
                    postfix = GetString(SI_ITEM_TOOLTIP_RESEARCHABLE)
                elseif filterKey == "ornate" then
                    postfix = GetString(SI_ITEMTRAITTYPE10)
                    if db.filters.ornate == "loot and junk" then
                        postfix = postfix .. GetString(SI_LIST_COMMA_SEPARATOR) ..
                                        GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                    end
                elseif filterKey == "intricate" then
                    postfix = GetString(SI_ITEMTRAITTYPE9)
                elseif (filterKey == "treasures" or filterKey == "trash") and
                    db.filters[filterKey] == "loot and junk" then
                    postfix = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                elseif filterKey == "scribing" and scribingAutoJunked then
                    postfix = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                elseif filterKey == "recipes" then
                    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or itemType == ITEMTYPE_RECIPE or
                        itemType == ITEMTYPE_COLLECTIBLE then
                        if CanItemLinkBeUsedToLearn(link) then
                            postfix = GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
                        elseif LCK then
                            local unknown, charName = IsItemUnknownByAnyCharacter(link)
                            if unknown then
                                postfix = charName .. GetString(MSAL_SPACE) ..
                                                GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
                            end
                        end
                    end
                elseif filterKey == "styleMaterials3rd" then
                    postfix = GetString(SI_ITEMTYPE44)
                end
                if wasAutoBound then
                    local abPostfix = GetString(MSAL_AUTO_BOUND)
                    if autoBindAction then
                        abPostfix = abPostfix .. " & " .. autoBindAction
                    end
                    postfix = postfix .. (postfix ~= "" and GetString(SI_LIST_COMMA_SEPARATOR) or "") .. abPostfix
                end
                if postfix ~= "" then
                    entry = entry .. GetString(MSAL_SPACE) .. zo_strformat(GetString(SI_QUEST_TYPE_FORMAT), postfix)
                end
                if chatlogSuffix then
                    entry = entry .. GetString(MSAL_SPACE) .. chatlogSuffix
                    chatlogSuffix = nil
                end
                BufferItemReceivedLog(entry)
            end
        else
            DebugLog("Non-loot item did not match any filter")
        end
        if not filterKey and not wouldNotLoot then
            local disposerApplied = isGear and db.gearDisposer or db.unwantedItemsDisposer
            if disposerApplied == "destroy" then
                if CanGemifyItem(bagId, slotId) then
                    if CanItemBeMarkedAsJunk(bagId, slotId) then
                        SetItemIsJunk(bagId, slotId, true)
                    end
                    if quality >= db.printDisposeThreshold then
                        BufferItemDisposeLog(GetString(SI_ITEM_ACTION_MARK_AS_JUNK), link)
                        ChatboxLog(zo_strformat(GetString(MSAL_DESTROY_SAFEGUARD), link))
                    end
                else
                    DestroyItem(bagId, slotId)
                    if quality >= db.printDisposeThreshold then
                        BufferItemDisposeLog(GetString(SI_ITEM_ACTION_DESTROY), link)
                    end
                end
            elseif disposerApplied == "junk" or disposerApplied == "decon and junk" then
                if CanItemBeMarkedAsJunk(bagId, slotId) then
                    SetItemIsJunk(bagId, slotId, true)
                    if quality >= db.printDisposeThreshold then
                        local action = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                        if disposerApplied == "decon and junk" and
                            (db.deconThreshold == 0 or quality >= db.deconThreshold) then
                            action = GetString(MSAL_REGISTER_FOR_DECON_AND_JUNK)
                        end
                        BufferItemDisposeLog(action, link)
                    end
                else
                    if quality >= db.printDisposeThreshold then
                        local action = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                        if disposerApplied == "decon and junk" and
                            (db.deconThreshold == 0 or quality >= db.deconThreshold) then
                            action = GetString(MSAL_REGISTER_FOR_DECON)
                        end
                        BufferItemReceivedLog(link .. GetString(MSAL_SPACE) ..
                            zo_strformat(GetString(SI_QUEST_TYPE_FORMAT),
                                zo_strformat(GetString(MSAL_CANNOT_BE_ACTION), action)))
                    end
                end
            end
        elseif filterKey == "treasures" or filterKey == "ornate" or filterKey == "trash" then
            -- "loot and junk" items - mark as junk
            if db.filters[filterKey] == "loot and junk" then
                SetItemIsJunk(bagId, slotId, true)
            end
        end
    end
    if (isContainer and not isGeode and
        (db.autoUnboxContainer == "all" or (isBound and db.autoUnboxContainer == "bound")) and
        not isWritsRewardContainerLooting) or
        (isUnopened and db.autoUnboxUnopened) or (isFish and db.autoUnboxFish) or (isGeode and db.autoUnboxGeode) then
        DebugLog("unboxing listening started")
        table.insert(unboxingQueue, slotId)
        MSAL.startInterruptionListener(slotId)
    end

    if not keepIntact and
        ((db.filters.treasures == "loot and junk" and isTreasure) or (db.filters.ornate == "loot and junk" and isOrnate) or
            (db.filters.trash == "loot and junk" and isTrash)) then
        SetItemIsJunk(bagId, slotId, true)
        -- if quality >= db.printDisposeThreshold then
        --     ChatboxLog(GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. GetString(MSAL_SPACE) .. link)
        -- end
    end

    for i = #currentNotLootedNameList, 1, -1 do
        if currentNotLootedNameList[i] == name then
            table.remove(currentNotLootedNameList, i)
            break
        end
    end
    lastNotLootedNameList = currentNotLootedNameList
end

local function OnDisposedUpdated(_, bagId, slotId, _, _, _, _)
    local itemName = string.lower(GetItemName(bagId, slotId))
    local link = GetItemLink(bagId, slotId)
    local quality = GetItemLinkFunctionalQuality(link)
    local unwanted = false
    for i = 1, #unwantedNameList do
        if unwantedNameList[i] ~= nil and unwantedNameList[i] == itemName then
            unwanted = true
        end
    end
    DebugLog(itemName .. " unwanted: " .. tostring(unwanted))

    local itemType = GetItemLinkItemType(link)
    local isGear = (itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR)
    local disposerApplied = (isJunkingBagContainerLeftovers and "junk") or
        (isGear and db.gearDisposer or db.unwantedItemsDisposer)
    if unwanted then
        if disposerApplied == "destroy" then
            if quality >= db.printDisposeThreshold then
                addDisposeLog(GetString(SI_ITEM_ACTION_DESTROY), link)
            end
            DestroyItem(bagId, slotId)
        elseif disposerApplied == "junk" or disposerApplied == "decon and junk" then
            if CanItemBeMarkedAsJunk(bagId, slotId) then
                if GetItemLinkSellInformation(link) == ITEM_SELL_INFORMATION_CANNOT_SELL and
                    not IsItemSellableOnTradingHouse(bagId, slotId) then
                    if quality >= db.printDisposeThreshold then
                        addDisposeLog(GetString(SI_ITEM_ACTION_MARK_AS_JUNK),
                            link .. " (" .. GetString(SI_ITEMSELLINFORMATION4) .. ")")
                    end
                    SetItemIsJunk(bagId, slotId, true)
                else
                    local action = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                    if disposerApplied == "decon and junk" then
                        if db.deconThreshold == 0 or quality >= db.deconThreshold then
                            action = GetString(MSAL_REGISTER_FOR_DECON_AND_JUNK)
                        end
                    end
                    if quality >= db.printDisposeThreshold then
                        addDisposeLog(action, link)
                    end
                    SetItemIsJunk(bagId, slotId, true)
                end
            else
                if quality >= db.printDisposeThreshold then
                    addDisposeLog(GetString(SI_ITEM_ACTION_LOOT_TAKE),
                        link .. " (" .. zo_strformat(GetString(MSAL_CANNOT_BE_ACTION),
                            GetString(SI_ITEM_ACTION_MARK_AS_JUNK)) .. ")")
                end
            end
        elseif disposerApplied == "decon" then
            if quality >= db.printDisposeThreshold then
                addDisposeLog(GetString(MSAL_REGISTER_FOR_DECON), link)
            end
        end
    end
end

local function OnDestroyUpdated(_, bagId, slotId, _, _, _, _)
    if bagId ~= BAG_BACKPACK then
        return
    end
    local link = GetItemLink(bagId, slotId)
    local quality = GetItemLinkFunctionalQuality(link)
    -- CHAT_ROUTER:AddSystemMessage("unwanted: "..tostring(unwanted))
    if quality >= db.printDisposeThreshold then
        ChatboxLog(GetString(SI_ITEM_ACTION_DESTROY) .. GetString(MSAL_SPACE) .. link)
    end
    DestroyItem(bagId, slotId)
end

local function OnJunkingUpdated(_, bagId, slotId, _, _, _, _)
    if bagId ~= BAG_BACKPACK then
        return
    end
    local link = GetItemLink(bagId, slotId)
    local quality = GetItemLinkFunctionalQuality(link)
    -- CHAT_ROUTER:AddSystemMessage("unwanted: "..tostring(unwanted))
    if CanItemBeMarkedAsJunk(bagId, slotId) then
        if GetItemLinkSellInformation(link) == ITEM_SELL_INFORMATION_CANNOT_SELL then
            if quality >= db.printDisposeThreshold then
                ChatboxLog(GetString(SI_ITEM_ACTION_LOOT_TAKE) .. GetString(MSAL_SPACE) .. link ..
                    " (" .. GetString(SI_ITEMSELLINFORMATION4) .. ")")
            end
        else
            if quality >= db.printDisposeThreshold then
                ChatboxLog(GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. GetString(MSAL_SPACE) .. link)
            end
            SetItemIsJunk(bagId, slotId, true)
        end
    end
end

local function ReorganizeLootWindowButtons()
    local customAnchor
    if db.addJunkingButton then
        customAnchor = ZO_Anchor:New(TOPRIGHT, ZO_LootAlphaContainerButton1, BOTTOMRIGHT, 0, 0)
        customAnchor:Set(ZO_LootAlphaContainerButtonJunking)
        if db.addDestroyButton then
            customAnchor = ZO_Anchor:New(TOPRIGHT, ZO_LootAlphaContainerButtonJunking, BOTTOMRIGHT, 0, 0)
            customAnchor:Set(ZO_LootAlphaContainerButtonDestroy)
        else
            customAnchor = ZO_Anchor:New(TOPRIGHT, ZO_LootAlphaContainerButton1, BOTTOMRIGHT, 114514, 0)
            customAnchor:Set(ZO_LootAlphaContainerButtonDestroy)
        end
    else
        customAnchor = ZO_Anchor:New(TOPRIGHT, ZO_LootAlphaContainerButton1, BOTTOMRIGHT, 114514, 0)
        customAnchor:Set(ZO_LootAlphaContainerButtonJunking)
        if db.addDestroyButton then
            customAnchor = ZO_Anchor:New(TOPRIGHT, ZO_LootAlphaContainerButton1, BOTTOMRIGHT, 0, 0)
            customAnchor:Set(ZO_LootAlphaContainerButtonDestroy)
        else
            customAnchor = ZO_Anchor:New(TOPRIGHT, ZO_LootAlphaContainerButton1, BOTTOMRIGHT, 114514, 0)
            customAnchor:Set(ZO_LootAlphaContainerButtonDestroy)
        end
    end
end

local function ArrayHasItem(arr, item)
    for i = 1, #arr do
        if arr[i] ~= nil and arr[i] == item then
            return true
        end
    end
    return false
end

local function IsSameArray(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end



local function HandleChatboxClick(link, button, text, linkStyle, linkType, dataString)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then
        return
    end
    if linkType == MSAL_NEVER_3RD_PARTY_WARNING then
        db.never3rdPartyWarning = true
        return true
    end
    if linkType == MSAL_AUTOLOOT_DISABLE then
        SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT, 0)
        SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AOE_LOOT, 1)
        SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG, 1)
        ChatboxLog(GetString(MSAL_AUTOLOOT_DISABLED_FEEDBACK))
        return true
    end
    if linkType == MSAL_AUTOLOOT_DISMISS then
        db.neverAutolootWarning = true
        ChatboxLog(GetString(MSAL_AUTOLOOT_DISMISSED_FEEDBACK))
        return true
    end
    if linkType == MSAL_AUTOLOOT_CONFLICT then
        OpenSettingsPanel()
    end
end
LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, HandleChatboxClick)
LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, HandleChatboxClick)
local function IsValidFilterType(filterType)
    if (filterType == nil) then
        return false
    end
    local dontShowAgainLink = ""
    if not ZO_IsConsoleOrGameCoreUI() then
        dontShowAgainLink = ZO_LinkHandler_CreateLinkWithoutBrackets(GetString(
            MSAL_THIRD_PARTY_DAFAULT_WARNING_NEVER_SHOW), nil, MSAL_NEVER_3RD_PARTY_WARNING)
    end
    if (not MasterMerchant and not TamrielTradeCentre and not ArkadiusTradeTools and TSCApi and filterType ==
        "per third") then
        local currentTime = GetGameTimeMilliseconds()
        if currentTime - last3rdPartyMissingTimetag > 600000 and not db.never3rdPartyWarning then
            ChatboxLog(zo_strformat(GetString(MSAL_THIRD_PARTY_DAFAULT_WARNING), GetString(MSAL_ALWAYS_LOOT)) ..
                           " | |cce912e" .. dontShowAgainLink)
            last3rdPartyMissingTimetag = currentTime
        end
        return false
    end
    return true
end

local function GetSafeDynamicOption(filterType, defaultOption)
    if not ZO_IsConsoleOrGameCoreUI() then
        return filterType
    end
    if (not MasterMerchant and not TamrielTradeCentre and not ArkadiusTradeTools and not TSCApi and filterType ==
        "per third") then
        return defaultOption
    end
    return filterType
end

local function GetStolenTreasureQualityLabel(filterType, logColor)
    local label
    if filterType == ITEM_DISPLAY_QUALITY_MAGIC then
        label = zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_MAGIC):Colorize(GetString(SI_ITEMQUALITY2)))
    elseif filterType == ITEM_DISPLAY_QUALITY_ARCANE then
        label = zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARCANE):Colorize(GetString(SI_ITEMQUALITY3)))
    elseif filterType == ITEM_DISPLAY_QUALITY_ARTIFACT then
        label = zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARTIFACT):Colorize(GetString(SI_ITEMQUALITY4)))
    else
        label = GetString(MSAL_ALWAYS_LOOT)
    end
    if logColor then
        -- keep the surrounding log color after the quality color's reset (|r)
        label = string.gsub(label, "|r", "|r" .. logColor)
    end
    return label
end

local function ShouldLootForSell(filterType)
    if (filterType == "always loot" or filterType == "loot and junk") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    return false
end

local function ShouldLootGear(filterType, quality)
    if (filterType == "always loot" or filterType == "loot and decon") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    if (filterType == "only blue" and quality >= 3) then
        return true
    end
    if (filterType == "only purple" and quality >= 4) then
        return true
    end
    if (filterType == "only gold" and quality >= 5) then
        return true
    end
    return false
end

local function ShouldLootRareTraitGear(filterType, isRareTraitWeapon, isRareTraitArmor, isRareTraitJewelry)
    if (filterType == "always loot" or filterType == "loot and decon") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    return false
end

local function ShouldLootSet(filterType, isUncollected, isJewelry, isWeapon)
    if (filterType == "always loot") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    if (filterType == "only uncollected" and isUncollected) then
        return true
    end
    if (filterType == "uncollected and jewelry" and (isUncollected or isJewelry)) then
        return true
    end
    if (filterType == "uncollected and non-jewelry" and isUncollected and not isJewelry) then
        return true
    end
    if (filterType == "weapon and jewelry" and (isJewelry or isWeapon)) then
        return true
    end
    if (filterType == "only collected" and not isUncollected) then
        return true
    end
    return false
end

local function ShouldLootNormal(filterType, itemType)
    if (filterType == "always loot") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    return false
end

local function ShouldLootPotion(filterType, link)
    if (filterType == "always loot") then
        return true
    end
    local itemId = GetItemLinkItemId(link)
    if (filterType == "only bastian" and (itemId == 176040 or itemId == 176041 or itemId == 176042)) then
        return true
    end
    if (filterType == "only non-bastian" and itemId ~= 176040 and itemId ~= 176041 and itemId ~= 176042) then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    return false
end

local function ShouldLootThirdPartyWorthyItem(filterType, link, threshold)
    local saleAvg = nil
    local fetchedPrice = 0
    local thirdPartyAddonName = ""

    if not IsThirdPartyOptionValid(filterType) then
        return true
    end

    if filterType == "per ttc" then
        thirdPartyAddonName = "TTC"
    elseif filterType == "per mm" then
        thirdPartyAddonName = "MM"
    elseif filterType == "per att" then
        thirdPartyAddonName = "ATT"
    elseif filterType == "per tsc" then
        thirdPartyAddonName = "TSC"
    end

    if filterType == "per ttc" then
        local itemInfo = TamrielTradeCentre_ItemInfo:New(link)
        local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemInfo)
        if priceInfo and priceInfo.SaleAvg then
            saleAvg = priceInfo.SaleAvg
        end
    end

    if filterType == "per mm" then
        local itemStats = MasterMerchant:itemStats(link)
        if itemStats and itemStats.avgPrice then
            saleAvg = itemStats.SaleAvg
        end
    end

    if filterType == "per att" then
        local days = GetTimeStamp() - (24 * 60 * 60 * 3)
        local avgPrice = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(link, days)
        if avgPrice then
            saleAvg = avgPrice
        end
    end

    if filterType == "per tsc" then
        local price = TSCApi:GetPrice(link)
        if type(price) == "number" then
            saleAvg = price
        end
    end

    DebugLog("Got 3rd party pricing request! FilterType: " .. filterType .. ", Item Name: " .. LocalizeString("<<1>>", GetItemLinkName(link)) ..
                 ", saleAvg: " .. tostring(saleAvg) .. ", threshold: " .. threshold)
    if saleAvg then
        if saleAvg >= threshold then
            local itemType = GetItemLinkItemType(link)
            if itemType == ITEMTYPE_RAW_MATERIAL or itemType == ITEMTYPE_STYLE_MATERIAL then
                styleMatHadValidPrice = true
            else
                chatlogSuffix = zo_strformat(GetString(MSAL_HIGH_VALUE_ITEM_DETECTED), thirdPartyAddonName, saleAvg)
            end

            return true
        end
    else
        return true
    end
    return false
end

local function ShouldLootMisc(filterType, link)
    if not IsValidFilterType(filterType) then
        return true
    end

    if (filterType == "always loot" or filterType == "loot and decon") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end

    if (filterType == "per third") then
        return ShouldLootThirdPartyWorthyItem(db.filters.thirdParty, link, db.filters.thirdPartyMinValue)
    end
    return false
end

local function ShouldLootGlyph(filterType, link)
    if IsItemLinkCrafted(link) then
        return true
    end
    return ShouldLootMisc(filterType, link)
end

local function ShouldLootIntricate(filterType, link, quality, isJewelry)
    if (filterType == "always loot" or filterType == "loot and decon") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    if (filterType == "type based") then
        local itemType = GetItemLinkItemType(link)
        -- if jewelry
        if (isJewelry) then
            return ShouldLootGear(db.filters.jewelryIntricate, quality)
        end
        if (not isJewelry and itemType == ITEMTYPE_ARMOR) then
            local weight = GetItemLinkArmorType(link)
            -- if clothing
            if (weight == ARMORTYPE_LIGHT or weight == ARMORTYPE_MEDIUM) then
                return ShouldLootGear(db.filters.clothingIntricate, quality)
            end
            -- if blacksmithing
            if (weight == ARMORTYPE_HEAVY) then
                return ShouldLootGear(db.filters.blacksmithingIntricate, quality)
            end
        end
        if (not isJewelry and itemType == ITEMTYPE_WEAPON) then
            local weaponType = GetItemLinkWeaponType(link)
            -- if woodworking
            if (weaponType == WEAPONTYPE_BOW or weaponType == WEAPONTYPE_FIRE_STAFF or weaponType ==
                WEAPONTYPE_FROST_STAFF or weaponType == WEAPONTYPE_LIGHTNING_STAFF or weaponType ==
                WEAPONTYPE_HEALING_STAFF or weaponType == WEAPONTYPE_SHIELD) then
                return ShouldLootGear(db.filters.woodworkingIntricate, quality)
            end
            -- if blacksmithing
            if (weaponType == WEAPONTYPE_AXE or weaponType == WEAPONTYPE_DAGGER or weaponType == WEAPONTYPE_HAMMER or
                weaponType == WEAPONTYPE_SWORD or weaponType == WEAPONTYPE_TWO_HANDED_AXE or weaponType ==
                WEAPONTYPE_TWO_HANDED_HAMMER or weaponType == WEAPONTYPE_TWO_HANDED_SWORD) then
                return ShouldLootGear(db.filters.blacksmithingIntricate, quality)
            end
        end
    end
    return false
end

local function ShouldLootUnopened(filterType, link)
    if (filterType == "always loot") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    if (filterType == "type based") then
        local itemType = GetItemLinkItemType(link)
        local itemId = GetItemLinkItemId(link)

        if (ArrayHasItem(unknownSurveyIds, itemId) and db.filters.survey == "always loot") then
            return true
        end
        if (ArrayHasItem(unknownWritIds, itemId) and db.filters.writs == "always loot") then
            return true
        end
        if (ArrayHasItem(unknownTreasureMapIds, itemId) and db.filters.treasureMaps == "always loot") then
            return true
        end
    end
    return false
end

local function ShouldLootUnopenedContent(filterType, itemType, specializedItemType)
    if filterType == "always loot" then
        return true
    end
    if filterType == "type based" then
        if itemType == ITEMTYPE_MASTER_WRIT and db.filters.writs == "always loot" then
            return true
        end
        if itemType == ITEMTYPE_TROPHY and specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP and
            db.filters.treasureMaps == "always loot" then
            return true
        end
        if itemType == ITEMTYPE_TROPHY and specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT and
            db.filters.survey == "always loot" then
            return true
        end
    end
    return false
end

local function ShouldLootFoodAndDrink(filterType, link)
    if (filterType == "always loot") then
        return true
    end
    local itemId = GetItemLinkItemId(link)
    if (filterType == "only exp booster" and (itemId == 64221 or itemId == 120076 or itemId == 115027)) then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    return false
end

local function IsPlayerHiddenOrStealthed()
    local stealthState = GetUnitStealthState("player")
    return stealthState == STEALTH_STATE_HIDDEN or stealthState == STEALTH_STATE_HIDDEN_ALMOST_DETECTED or
        stealthState == STEALTH_STATE_STEALTH or stealthState == STEALTH_STATE_STEALTH_ALMOST_DETECTED
end

local function CanLootWithoutBounty(link)
    if IsItemLinkStolen(link) then
        return IsPlayerHiddenOrStealthed()
    else
        return true
    end
end

local function ShouldLootMaterial(filterType, link, isRawMaterial)
    if (IsESOPlusSubscriber()) then
        return true
    end
    if filterType == "only cp160 and raw" then
        return isRawMaterial or (link and IsCp160Material(link))
    end
    if (filterType == "always loot") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    return false
end

local function ShouldLootEnchanting(filterType, link)
    if (IsESOPlusSubscriber()) then
        return true
    end

    if (filterType == "always loot") then
        return true
    end
    local itemId = GetItemLinkItemId(link)
    if (filterType == "only kuta hakeijo" and (itemId == 45854 or itemId == 68342 or itemId == 166045)) then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    return false
end

local function ShouldLootIngredient(filterType, link)
    local quality = GetItemLinkFunctionalQuality(link)
    if (filterType == "only purple and gold ingredients" and (quality >= 4)) then
        return true
    elseif (filterType == "only gold ingredients" and (quality == 5)) then
        return true
    else
        return ShouldLootMaterial(filterType)
    end
end

local function ShouldLootStyleMat(filterType, filterType3rd, link)
    if link == "" then
        return false
    end

    if filterType3rd == "per third" and IsThirdPartyOptionValid(db.filters.thirdParty) then
        return ShouldLootThirdPartyWorthyItem(db.filters.thirdParty, link, db.filters.styleMaterials3rdPriceThreshold)
    elseif (filterType == "only non-racial") then
        local itemType = GetItemLinkItemType(link)
        DebugLog("style item link: " .. link)
        DebugLog("itemType: " .. tostring(itemType))
        if (itemType == ITEMTYPE_RAW_MATERIAL) then
            return true
        else
            local styleId = GetItemLinkItemStyle(link)
            DebugLog("styleId: " .. tostring(styleId))
            local isRacial = ((styleId >= 1 and styleId <= 35) or styleId == GetImperialStyleId()) and styleId ~= 10
            return not isRacial
        end
    else
        return ShouldLootMaterial(filterType)
    end
end

local function ShouldLootTrait(filterType, link, isRareWeaponTrait, isRareArmorTrait, isRareJewelryTrait)
    local itemId = GetItemLinkItemId(link)
    if (filterType == "only nirnhoned" and
        (isRareWeaponTrait or isRareArmorTrait or isRareJewelryTrait or (itemId > 139415 and itemId < 139420))) then
        return true
    else
        return ShouldLootMaterial(filterType)
    end
end

local function ShouldLootGem(filterType, link)
    local itemId = GetItemLinkItemId(link)
    if (filterType == "always loot") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    if (filterType == "only filled" and (itemId == 33271 or itemId == 61080)) then
        return true
    end
    return false
end

local function ShouldLootRecipe(filterType, link)
    -- Unknown collectibles always override filter settings
    if LCK and db.filters.recipesAlwaysLootAnyCharUnknown then
        local unknown, charName = IsItemUnknownByAnyCharacter(link)
        if unknown then
            return true, charName .. GetString(MSAL_SPACE) .. GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
        end
    end
    if db.filters.recipesAlwaysLootUnknown then
        if CanItemLinkBeUsedToLearn(link) then
            return true, GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
        end
    end

    if not IsItemLinkTradeable(link) then
        return true
    end

    if not IsValidFilterType(filterType) then
        return true
    end

    if (filterType == "always loot") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end

    local tempResult = false
    if (filterType == "per third") then
        tempResult = tempResult or
                         ShouldLootThirdPartyWorthyItem(db.filters.thirdParty, link, db.filters.thirdPartyMinValue)
    end

    return tempResult
end

local function ShouldLootFurniture(filterType, link)
    local tempResult = false
    if filterType == "only unbound" and IsItemLinkTradeable(link) then
        return true
    end

    if not IsValidFilterType(filterType) then
        return true
    end

    if (filterType == "always loot") then
        return true
    end
    if (filterType == "never loot") then
        return false
    end
    -- local itemType = GetItemLinkItemType(link)

    if (filterType == "per third") then
        tempResult = tempResult or
                         ShouldLootThirdPartyWorthyItem(db.filters.thirdParty, link, db.filters.thirdPartyMinValue)
    end

    return tempResult
end

-- function MuchSmarterAutoLoot:OnLootUpdatedAF()
--     local randomItemSentence = {
--         SI_ARMORYBUILDOPERATIONTYPE_DIALOGMESSAGE2, -- Equipping <<1>> ...
--         SI_QUEST_REWARD_MAX_CURRENCY_ERROR, -- You cannot carry any more <<1>>
--         SI_LOOTITEMRESULT8, -- You are unable to loot the Unique <<1>> because you already have one.
--         SI_TRADEACTIONRESULT45, -- You are unable to trade for <<1>> because it is unique and you already have one
--         SI_INTERACT_OPTION_KEEP_GUILD_CLAIM, -- Claim ownership of <<1>>
--         SI_MARKET_PURCHASE_ALREADY_HAVE_GIFT_TEXT, -- You have <<1>> in your Gift Inventory. Claim it for yourself before purchasing it again.
--         SI_ANTIQUITY_LEAD_ACQUIRED_TEXT, -- <<1>> is now available to Scry.
--         -- SI_COMPANIONSUMMONRESULT8, -- <<1>> is not responding to your summon. Try again later when they're less angry with you.
--         -- SI_COMPANIONSUMMONRESULT6, -- <<1>> tried to join you but forgot to bring their gear.
--         -- SI_PLAYER_TO_PLAYER_INCOMING_RITUAL_OF_MARA, -- <<1>> wants to join with you in the Ritual of Mara
--     }

--     local randomItem = {
--         "|H0:item:62283:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Fusozay Cushion
--         "|H0:item:62140:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Khajiit Windowsill Sun Reflector
--         "|H0:item:198163:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Scrap of Skooma-Inspired Poetry
--         "|H0:item:62240:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Sheet Music Folio
--         "|H0:item:71369:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Stainless Dueling Jock
--         "|H0:item:150535:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Sweetwater Mouthwash
--         "|H0:item:61213:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Book of Erotic Stories
--         "|H0:item:187968:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- "Erotica for Werewolves"
--         "|H0:item:61211:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Guide to Approved Methods of Procreation
--         "|H0:item:150486:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Khajiiti Gravity Verification Gadget
--         "|H0:item:138857:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- "Barbas" Dog Collar
--         "|H0:item:138940:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Visual Guide to Skooma
--         "|H0:item:63095:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Eyes of the Queen Disguise Kit
--         "|H0:item:183100:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Ogrim Nipple Caps
--         "|H0:item:198162:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Skooma Cat Medallion
--         "|H0:item:63009:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- "Amorous Giantess" Royal Ensemble
--         "|H0:item:61256:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Pamphlet of Erotic Engravings
--         "|H0:item:166501:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Conquest of the Falmer
--         "|H0:item:73820:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Pacrooti's Mole Asses
--         "|H0:item:62039:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Invitation: Drinks with the Neighbors
--         "|H0:item:126291:4:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h"
--     }

--     local random_number = math.random()
--     local currentTime = GetGameTimeMilliseconds()
--     if random_number < 0.2 and currentTime - lastFoolUpdated > 300 then
--         local randomSentenceIndex = math.random(1, #randomItemSentence)
--         local randomItemIndex = math.random(1, #randomItem)
--        CHAT_ROUTER:AddSystemMessage(zo_strformat(GetString(randomItemSentence[randomSentenceIndex]), randomItem[randomItemIndex]))
--         lastFoolUpdated = currentTime
--     end
-- end

local function isPlayerIdle(slotIndex)
    return CanInteractWithItem(BAG_BACKPACK, slotIndex) and not IsUnitInCombat("player") and
               (SCENE_MANAGER:GetCurrentScene().name == "hudui" or SCENE_MANAGER:GetCurrentScene().name == "hud")
end

local function unboxQueuedContainer()
    local cachedUnboxingQueue = unboxingQueue
    unboxingQueue = {}
    isUnboxing = true
    zo_callLater(function()
        isUnboxing = false
        -- if new containers were obtained during unboxing
        if #unboxingQueue > 0 then
            unboxQueuedContainer()
        end
    end, #cachedUnboxingQueue * (1000 + GetLatency()))
    for i, slotIndex in ipairs(cachedUnboxingQueue) do
        if GetItemName(BAG_BACKPACK, slotIndex) == "" then
            ChatboxLog((GetString(MSAL_UNBOX_CONTAINER_MISSING)))
        else
            zo_callLater(function()
                CallSecureProtected("UseItem", BAG_BACKPACK, slotIndex)
                -- if ZO_IsConsoleOrGameCoreUI() then
                --     SCENE_MANAGER:Hide("lootGamepad")
                --     SCENE_MANAGER:Show("hud")
                -- else
                --     SCENE_MANAGER:Hide("loot")
                --     SCENE_MANAGER:Show("hudui")
                -- end
                -- SCENE_MANAGER:ShowBaseScene()
            end, (i - 1) * (1000 + GetLatency()))
        end
    end
end

-- monitor item interaction status
local unboxingInterrupted = false
function MSAL.listenInterruption(slotIndex)
    -- DebugLog("start listen")
    EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_LISTEN")
    EVENT_MANAGER:RegisterForUpdate("MSAL_UNBOXING_LISTEN", 100, function()
        if isPlayerIdle(slotIndex) then
            -- Item is interactive, continue monitoring
        else
            -- DebugLog("interrupt detected")
            unboxingInterrupted = true
            EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_LISTEN")
        end
    end)
end

function MSAL.checkInterruption(slotIndex)
    -- DebugLog("check")
    EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_CHECK")
    local timeout
    if isLALwaitingForUnboxingCraftReward then
        timeout = 2000
    else
        timeout = 0
    end
    EVENT_MANAGER:RegisterForUpdate("MSAL_UNBOXING_CHECK", GetLatency() + timeout, function()
        EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_CHECK")
        if unboxingInterrupted == false then
            EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_LISTEN")
            unboxQueuedContainer()
        else
            MSAL.startInterruptionListener(slotIndex)
        end
    end)
end

-- wait for item to be interactable and start listening
function MSAL.startInterruptionListener(slotIndex)
    -- DebugLog("start listener")
    EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_LISTENER")
    EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_LISTEN")
    EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_CHECK")

    EVENT_MANAGER:RegisterForUpdate("MSAL_UNBOXING_LISTENER", 100, function()
        if isUnboxing == true then
            EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_LISTENER")
        else
            if isPlayerIdle(slotIndex) then
                EVENT_MANAGER:UnregisterForUpdate("MSAL_UNBOXING_LISTENER")
                unboxingInterrupted = false
                MSAL.listenInterruption(slotIndex)
                MSAL.checkInterruption(slotIndex)
            end
        end
    end)
end

function MSAL.FilterItem(link, isQuest, lootType)
    local name = LocalizeString("<<1>>", GetItemLinkName(link))
    local itemType, specializedItemType = GetItemLinkItemType(link)
    local quality = GetItemLinkDisplayQuality(link)
    local trait = GetItemLinkTraitInfo(link)
    local isStolen = IsItemLinkStolen(link)
    local isGear = itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR
    local isSetItem = IsItemLinkSetCollectionPiece(link)
    local itemId = GetItemLinkItemId(link)
    local isUncollected = not IsItemSetCollectionPieceUnlocked(itemId)
    local isUnresearched = isGear and CanItemLinkBeTraitResearched(link)
    local isOrnate = trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE or trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE or trait ==
                         ITEM_TRAIT_TYPE_JEWELRY_ORNATE
    local isIntricate =
        trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
    local isWeapon = itemType == ITEMTYPE_WEAPON
    local isJewelry = jewelryTraits[trait] and itemType == ITEMTYPE_ARMOR
    local isCompanionGear = GetItemLinkActorCategory(link) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
    local isCrafted = IsItemLinkCrafted(link)
    local isRareWeaponTrait = trait == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
    local isRareArmorTrait = trait == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
    local isRareJewelryTrait =
        trait == ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY or trait == ITEM_TRAIT_TYPE_JEWELRY_HARMONY or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_INFUSED or trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_ORNATE or trait == ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE or trait ==
            ITEM_TRAIT_TYPE_JEWELRY_SWIFT or trait == ITEM_TRAIT_TYPE_JEWELRY_TRIUNE
    if isQuest or itemType == ITEMTYPE_NONE or specializedItemType ==
        SPECIALIZED_ITEMTYPE_TROPHY_DUNGEON_BUFF_INGREDIENT or specializedItemType ==
        SPECIALIZED_ITEMTYPE_TROPHY_TRIBUTE_CLUE or specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_UPGRADE_FRAGMENT or
        specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_MUSEUM_PIECE then
        if ShouldLootMisc(db.filters.questItems, link) then
            return "questItems", "quest item"
        end
    end

    if isGear then
        if isCompanionGear then
            if ShouldLootGear(db.filters.companionGears, quality) then
                return "companionGears", "companion gear"
            end
        end
        if isCrafted then
            if ShouldLootNormal(db.filters.craftedGears, itemType) then
                return "craftedGears", "player crafted gear"
            end
        end
        if not isJewelry and db.filters.styleMaterials3rd == "per third" and 
        db.filters.styleMaterials3rdGearLooting == true then
            if GetItemLinkItemStyle(link) > 0 then
                if ShouldLootStyleMat(db.filters.styleMaterials, db.filters.styleMaterials3rd,
                    GetItemStyleMaterialLink(GetItemLinkItemStyle(link))) then
                    return "styleMaterials3rd", "style material gear"
                end
            end
        end
        if isSetItem then
            if ShouldLootSet(db.filters.set, isUncollected, isJewelry, isWeapon) then
                return "set", "set item"
            end
            if not isUncollected then
                if isRareWeaponTrait or isRareArmorTrait or isRareJewelryTrait then
                    if ShouldLootRareTraitGear(db.filters.rareTrait, isRareWeaponTrait, isRareArmorTrait,
                        isRareJewelryTrait) then
                        return "rareTrait", "set rare trait gear"
                    end
                end
                if isUnresearched then
                    if ShouldLootGear(db.filters.unresearched, quality) then
                        return "unresearched", "set unresearched gear"
                    end
                end
                if isOrnate then
                    if ShouldLootForSell(db.filters.ornate) then
                        return "ornate", "set ornate gear"
                    end
                end
                if isIntricate then
                    if ShouldLootIntricate(db.filters.intricate, link, quality, isJewelry) then
                        return "intricate", "set intricate gear"
                    end
                end
                if isJewelry then
                    if ShouldLootGear(db.filters.jewelry, quality) then
                        return "jewelry", "set jewelry gear"
                    end
                end
                if itemType == ITEMTYPE_ARMOR and not isJewelry then
                    if ShouldLootGear(db.filters.armors, quality) then
                        return "armors", "set armor gear"
                    end
                end
                if itemType == ITEMTYPE_WEAPON then
                    if ShouldLootGear(db.filters.weapons, quality) then
                        return "weapons", "set weapon gear"
                    end
                end
            end
        else
            if isRareWeaponTrait or isRareArmorTrait or isRareJewelryTrait then
                if ShouldLootRareTraitGear(db.filters.rareTrait, isRareWeaponTrait, isRareArmorTrait, isRareJewelryTrait) then
                    return "rareTrait", "rare trait gear"
                end
            end
            if isUnresearched then
                if ShouldLootGear(db.filters.unresearched, quality) then
                    return "unresearched", "unresearched gear"
                end
            end
            if isOrnate then
                if ShouldLootForSell(db.filters.ornate) then
                    return "ornate", "ornate gear"
                end
            end
            if isIntricate then
                if ShouldLootIntricate(db.filters.intricate, link, quality, isJewelry) then
                    return "intricate", "intricate gear"
                end
            end
            if isJewelry then
                if ShouldLootGear(db.filters.jewelry, quality) then
                    return "jewelry", "jewelry gear"
                end
            end
            if itemType == ITEMTYPE_ARMOR and not isJewelry then
                if ShouldLootGear(db.filters.armors, quality) then
                    return "armors", "armor gear"
                end
            end
            if itemType == ITEMTYPE_WEAPON then
                if ShouldLootGear(db.filters.weapons, quality) then
                    return "weapons", "weapon gear"
                end
            end
        end
    elseif itemType == ITEMTYPE_BLACKSMITHING_BOOSTER or itemType == ITEMTYPE_CLOTHIER_BOOSTER or itemType ==
        ITEMTYPE_WOODWORKING_BOOSTER or itemType == ITEMTYPE_JEWELRYCRAFTING_BOOSTER then
        if ShouldLootGear(db.filters.refineMaterials, quality) then
            return "refineMaterials", "refine material"
        end
    elseif itemType == ITEMTYPE_BLACKSMITHING_MATERIAL or itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL then
        if ShouldLootMaterial(db.filters.blacksmithingMaterials, link, itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL) then
            return "blacksmithingMaterials", "blacksmithing material"
        end
    elseif itemType == ITEMTYPE_CLOTHIER_MATERIAL or itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL then
        if ShouldLootMaterial(db.filters.clothingMaterials, link, itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL) then
            return "clothingMaterials", "clothier material"
        end
    elseif itemType == ITEMTYPE_WOODWORKING_MATERIAL or itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL then
        if ShouldLootMaterial(db.filters.woodworkingMaterials, link, itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL) then
            return "woodworkingMaterials", "woodworking material"
        end
    elseif itemType == ITEMTYPE_JEWELRYCRAFTING_MATERIAL or itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER or itemType ==
        ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL then
        if ShouldLootMaterial(db.filters.jewelryCraftingMaterials, link,
            itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL) then
            return "jewelryCraftingMaterials", "jewelry crafting material"
        end
    elseif itemType == ITEMTYPE_RAW_MATERIAL or itemType == ITEMTYPE_STYLE_MATERIAL then
        if ShouldLootStyleMat(db.filters.styleMaterials, db.filters.styleMaterials3rd, link) then
            return "styleMaterials", "style material"
        end
    elseif itemType == ITEMTYPE_WEAPON_TRAIT or itemType == ITEMTYPE_ARMOR_TRAIT or itemType ==
        ITEMTYPE_JEWELRY_RAW_TRAIT or itemType == ITEMTYPE_JEWELRY_TRAIT then
        if ShouldLootTrait(db.filters.traitMaterials, link, isRareWeaponTrait, isRareArmorTrait, isRareJewelryTrait) then
            return "traitMaterials", "trait material"
        end
    elseif itemType == ITEMTYPE_INGREDIENT then
        if ShouldLootIngredient(db.filters.ingredients, link) then
            return "ingredients", "ingredient"
        end
    elseif itemType == ITEMTYPE_POTION_BASE or itemType == ITEMTYPE_POISON_BASE or itemType == ITEMTYPE_REAGENT then
        if ShouldLootMaterial(db.filters.alchemy) then
            return "alchemy", "alchemy material"
        end
    elseif itemType == ITEMTYPE_ENCHANTING_RUNE_ASPECT or itemType == ITEMTYPE_ENCHANTING_RUNE_ESSENCE or itemType ==
        ITEMTYPE_ENCHANTING_RUNE_POTENCY or itemType == ITEMTYPE_ENCHANTMENT_BOOSTER then
        if ShouldLootEnchanting(db.filters.runes, link) then
            return "runes", "enchanting material"
        end
    elseif itemType == ITEMTYPE_FURNISHING_MATERIAL then
        if ShouldLootMaterial(db.filters.furnishingMaterials) then
            return "furnishingMaterials", "furnishing material"
        end
    elseif itemType == ITEMTYPE_SCRIBING_INK then
        if ShouldLootMaterial(db.filters.ink) then
            return "ink", "scribing material"
        end
    elseif itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
        if ShouldLootGlyph(db.filters.glyphs, link) then
            return "glyphs", "glyph"
        end
    elseif itemType == ITEMTYPE_CONTAINER or itemType == ITEMTYPE_CONTAINER_CURRENCY or itemType == ITEMTYPE_FISH then
        if ShouldLootMisc(db.filters.containers, link) then
            return "containers", "container"
        end
    elseif itemType == ITEMTYPE_FURNISHING then
        if ShouldLootFurniture(db.filters.furniture, link) then
            return "furniture", "furniture"
        end
    elseif itemType == ITEMTYPE_CROWN_ITEM then
        if ShouldLootMisc(db.filters.crownItems, link) then
            return "crownItems", "crown item"
        end
    elseif itemType == ITEMTYPE_CONTAINER_STACKABLE then
        if ShouldLootUnopened(db.filters.unopened, link) then
            return "unopened", "unopened container"
        end
    elseif itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT then
        if ShouldLootNormal(db.filters.scribing, itemType) then
            return "scribing", "crafted ability script"
        end
    elseif itemType == ITEMTYPE_SOUL_GEM then
        if ShouldLootGem(db.filters.soulGems, link) then
            return "soulGems", "soul gem"
        end
    elseif itemType == ITEMTYPE_CONSUMABLE_ABILITY then
        if ShouldLootGem(db.filters.skillScrolls, link) then
            return "skillScrolls", "skill scroll"
        end
    elseif itemType == ITEMTYPE_AVA_REPAIR or itemType == ITEMTYPE_SIEGE or itemType == ITEMTYPE_RECALL_STONE then
        if ShouldLootMisc(db.filters.allianceWarConsumables, link) then
            return "allianceWarConsumables", "alliance war consumable"
        end
    elseif itemType == ITEMTYPE_LOCKPICK then
        if ShouldLootMisc(db.filters.lockpicks, link) then
            return "lockpicks", "lockpick"
        end
    elseif (itemType == ITEMTYPE_TOOL and itemId == 44879) or itemType == ITEMTYPE_GROUP_REPAIR or itemType ==
        ITEMTYPE_CROWN_REPAIR then
        if ShouldLootMisc(db.filters.repairKits, link) then
            return "repairKits", "repair kit"
        end
    elseif itemType == ITEMTYPE_TOOL and itemId ~= 44879 then
        if ShouldLootMisc(db.filters.tools, link) then
            return "tools", "tool"
        end
    elseif lootType == LOOT_TYPE_ANTIQUITY_LEAD then
        if ShouldLootMisc(db.filters.leads, link) then
            return "leads", "antiquity lead"
        end
    elseif itemType == ITEMTYPE_MASTER_WRIT or
        (itemType == ITEMTYPE_TROPHY and (specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP or
        specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT)) then
        if ShouldLootUnopenedContent(db.filters.unopened, itemType, specializedItemType) then
            return "unopened", "unopened content"
        end
    elseif itemType == ITEMTYPE_TROPHY and specializedItemType ~=
        SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT and specializedItemType ~=
        SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT and specializedItemType ~=
        SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP and specializedItemType ~=
        SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
        if ShouldLootMisc(db.filters.trophy, link) then
            return "trophy", "trophy"
        end
    elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or itemType == ITEMTYPE_RECIPE or itemType == ITEMTYPE_COLLECTIBLE or
        (itemType == ITEMTYPE_TROPHY and specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT) or
        (itemType == ITEMTYPE_TROPHY and specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT) then
        local recipeResult, unknownPostfix = ShouldLootRecipe(db.filters.recipes, link)
        if recipeResult then
            if unknownPostfix then
                return "recipes", "recipe or motif" .. " (" .. unknownPostfix .. ")"
            end
            return "recipes", "recipe or motif"
        end
    elseif itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK then
        if ShouldLootFoodAndDrink(db.filters.foodAndDrink, link) then
            return "foodAndDrink", "food or drink"
        end
    elseif itemType == ITEMTYPE_POTION then
        if ShouldLootPotion(db.filters.potions, link) then
            return "potions", "potion"
        end
    elseif itemType == ITEMTYPE_POISON then
        if ShouldLootMisc(db.filters.poisons, link) then
            return "poisons", "poison"
        end
    elseif itemType == ITEMTYPE_TREASURE then
        if ShouldLootForSell(db.filters.treasures) then
            return "treasures", "treasure"
        end
    elseif itemType == ITEMTYPE_COSTUME or itemType == ITEMTYPE_DISGUISE then
        if ShouldLootMisc(db.filters.costumes, link) then
            return "costumes", "costume or disguise"
        end
    elseif itemType == ITEMTYPE_LURE then
        if ShouldLootMaterial(db.filters.fishingBaits) then
            return "fishingBaits", "fishing bait"
        end
    elseif itemType == ITEMTYPE_TRASH then
        if ShouldLootForSell(db.filters.trash, link) then
            return "trash", "trash"
        end
    end

    return nil, nil
end

local function LootCurrenciesByRules(showOverlimitWarning)
    local currencyInfo = LOOT_SHARED:GetLootCurrencyInformation()
    local allCurrenciesLooted = true
    for curt, info in pairs(currencyInfo) do
        if curt == CURT_MONEY then
            if info.currencyAmount > 0 then
                if db.filters.lootCurrencies == true then
                    LootMoney()
                else
                    allCurrenciesLooted = false
                    isAllCurtLooted = false
                end
            elseif info.stolenCurrencyAmount > 0 then
                if db.filters.lootCurrencies == true and IsPlayerHiddenOrStealthed() then
                    LootMoney()
                else
                    allCurrenciesLooted = false
                    isAllCurtLooted = false
                end
            end
        elseif curt == CURT_TRANSMUTE_CRYSTALS then
            local curtAmount = GetCurrencyAmount(CURT_TRANSMUTE_CRYSTALS, CURRENCY_LOCATION_ACCOUNT)
            local maxCurt = GetMaxPossibleCurrency(CURT_TRANSMUTE_CRYSTALS, CURRENCY_LOCATION_ACCOUNT)
            if info.currencyAmount > 0 then
                if db.filters.lootCurrencies == true then
                    if (curtAmount + info.currencyAmount <= maxCurt) then
                        LootCurrency(curt)
                    else
                        if showOverlimitWarning then
                            OverlimitWarning(curt)
                        end
                        allCurrenciesLooted = false
                        isAllCurtLooted = false
                    end
                else
                    allCurrenciesLooted = false
                    isAllCurtLooted = false
                end
            end
        else
            if info.currencyAmount > 0 then
                if db.filters.lootCurrencies == true then
                    LootCurrency(curt)
                else
                    allCurrenciesLooted = false
                    isAllCurtLooted = false
                end
            end
        end
    end
    return allCurrenciesLooted
end

local function IsLootingBackpackItem()
    local targetName = GetLootTargetInfo()
    if targetName == nil or targetName == "" then
        return false
    end
    for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
        if GetItemName(BAG_BACKPACK, bagSlot) == targetName then
            return true
        end
    end
    return false
end

local function OnLootUpdated()
    chatlogSuffix = nil
    disposeLogLines = {}
    if (db.enabled == false) then
        return
    end
    isProcessingLoot = true
    lootWindowClosed = false
    DebugLog("[AL+ Debug Log]")

    -- if the loot start within 3 sec after lockpick successfully, then regard it's a locked chest loot
    local isLockedChest = false
    if GetGameTimeMilliseconds() - lastUnlockTimetag < 3000 then
        isLockedChest = true
    end

    -- local isResourceNode = false
    -- if isHarvesting then
    --     isResourceNode = true
    -- end
    -- isHarvesting = false

    local currentScene = SCENE_MANAGER:GetCurrentScene().name
    if ((IsInGamepadPreferredMode() and tostring(currentScene) == "lootInventoryGamepad") or
        (not IsInGamepadPreferredMode() and tostring(currentScene) == "inventory") or false) then
        isBagContainer = true
    end
    -- wipe at loot beginning other than ending, to avoid server-end latency
    currentNotLootedNameList = {}
    unwantedLootIdList = {}
    unwantedNameList = {}
    setItemList = {}
    isRepetitiveGear = false

    LootCurrenciesByRules(true)

    local willCommitCrime = false

    -- CHAT_ROUTER:AddSystemMessage("Loot items number : "..num)
    local stackableLootedParts = {}
    local stackableJunkParts = {}
    for i = 1, GetNumLootItems(), 1 do
        chatlogSuffix = nil
        styleMatHadValidPrice = false
        local lootId, name, _, quantity, _, _, isQuest, isStolen, lootType = GetLootItemInfo(i)
        local link = GetLootItemLink(lootId)
        local trait = GetItemLinkTraitInfo(link)
        local quality = GetItemLinkDisplayQuality(link)
        -- local value = GetItemLinkValue(link)
        local isRareWeaponTrait = trait == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
        local isRareArmorTrait = trait == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
        local isRareJewelryTrait = trait == ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY or trait ==
                                       ITEM_TRAIT_TYPE_JEWELRY_HARMONY or trait == ITEM_TRAIT_TYPE_JEWELRY_INFUSED or
                                       trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or trait ==
                                       ITEM_TRAIT_TYPE_JEWELRY_ORNATE or trait == ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE or
                                       trait == ITEM_TRAIT_TYPE_JEWELRY_SWIFT or trait == ITEM_TRAIT_TYPE_JEWELRY_TRIUNE
        local itemType, specializedItemType = GetItemLinkItemType(link)
        local isCompanionGear = GetItemLinkActorCategory(link) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
        local isGear = itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR
        local isSetItem = IsItemLinkSetCollectionPiece(link)
        local isUnresearched = isGear and CanItemLinkBeTraitResearched(link)
        local itemId = GetItemLinkItemId(link)
        local isUncollected = not IsItemSetCollectionPieceUnlocked(itemId)
        local isOrnate = trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE or trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE or trait ==
                             ITEM_TRAIT_TYPE_JEWELRY_ORNATE
        local isIntricate = trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or
                                trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
        local isWeapon = itemType == ITEMTYPE_WEAPON
        local isJewelry = jewelryTraits[trait] and itemType == ITEMTYPE_ARMOR
        local chatlogPostfix = ""

        local lootedAs = nil
        local deferTreasureLog = itemType == ITEMTYPE_TREASURE and isStolen and
            db.stolenTreasureThreshold > ITEM_DISPLAY_QUALITY_TRASH and
            not itemOnList(link, WLIST_TOKEN) and not itemOnList(link, WLIST_JUNK_TOKEN)
        -- once a thief, forever a thief
        if not willCommitCrime and isStolen and not CanLootWithoutBounty(link) then
            willCommitCrime = true
        end

        if (isStolen and (db.stolenRule == "never loot" or db.stolenRule == "never loot strict")) or
            (db.stolenRule == "follow" and not CanLootWithoutBounty(link)) or itemOnList(link, BLIST_TOKEN) then
            if isStolen and db.stolenRule == "never loot strict" then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_RESPECRESULT10)
            end
            -- do nothing
        elseif itemOnList(link, WLIST_JUNK_TOKEN) then
            LootItemById(lootId)
            lootedAs = "on whitelist junk"
        elseif itemOnList(link, WLIST_TOKEN) then
            LootItemById(lootId)
            lootedAs = "on whitelist"
        else
            local filterKey, filterCategory = MSAL.FilterItem(link, isQuest, lootType)
            if isSetItem then
                isRepetitiveGear = ArrayHasItem(setItemList, name)
                table.insert(setItemList, name)
            end
            if filterKey then
                LootItemById(lootId)
                lootedAs = filterCategory
                if filterKey == "set" and isUncollected then
                    chatlogPostfix = chatlogPostfix .. GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
                elseif filterKey == "unresearched" then
                    chatlogPostfix = chatlogPostfix .. GetString(SI_ITEM_TOOLTIP_RESEARCHABLE)
                elseif filterKey == "ornate" then
                    chatlogPostfix = chatlogPostfix .. GetString(SI_ITEMTRAITTYPE10)
                    if db.filters.ornate == "loot and junk" then
                        chatlogPostfix = chatlogPostfix .. GetString(SI_LIST_COMMA_SEPARATOR) ..
                                             GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                    end
                elseif filterKey == "intricate" then
                    chatlogPostfix = chatlogPostfix .. GetString(SI_ITEMTRAITTYPE9)
                elseif (filterKey == "treasures" or filterKey == "trash") and
                    db.filters[filterKey] == "loot and junk" then
                    chatlogPostfix = chatlogPostfix .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                elseif filterKey == "scribing" then
                    if not IsItemLinkTradeable(link) then
                        local unknownByAnyChar = CanItemLinkBeUsedToLearn(link)
                        if LCK then
                            local anyUnknown = IsItemUnknownByAnyCharacter(link)
                            unknownByAnyChar = unknownByAnyChar or anyUnknown
                        end
                        if not unknownByAnyChar then
                            chatlogPostfix = chatlogPostfix .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                        end
                    end
                elseif filterKey == "recipes" then
                    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or itemType == ITEMTYPE_RECIPE or
                        itemType == ITEMTYPE_COLLECTIBLE then
                        local unknownChar = CanItemLinkBeUsedToLearn(link)
                        if unknownChar then
                            chatlogPostfix = chatlogPostfix .. GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
                        elseif LCK then
                            local unknownAny, charName = IsItemUnknownByAnyCharacter(link)
                            if unknownAny then
                                chatlogPostfix = chatlogPostfix .. charName .. GetString(MSAL_SPACE) ..
                                                      GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)
                            end
                        end
                    end
                elseif filterKey == "leads" then
                    local antiquityId = GetLootAntiquityLeadId(lootId)
                    if GetNumAntiquitiesRecovered(antiquityId) == 0 then
                        table.insert(stackableLootedParts,
                            GetString(SI_ITEM_ACTION_LOOT_TAKE) .. GetString(MSAL_SPACE) .. name ..
                                GetString(MSAL_SPACE) ..
                                zo_strformat(GetString(SI_QUEST_TYPE_FORMAT),
                                    GetString(SI_GAMEPAD_GUILD_LIST_NEW_HEADER)))
                    end
                elseif filterKey == "styleMaterials3rd" then
                    chatlogPostfix = chatlogPostfix .. GetString(SI_ITEMTYPE44)
                end
            end
        end

        if not lootedAs and db.alwaysLootStackable and IsItemLinkStackable(link) then
            local inventoryCount, _, _ = GetItemLinkStacks(link)
            if inventoryCount > 0 then
                for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
                    local itemLink = GetItemLink(BAG_BACKPACK, bagSlot)
                    if itemLink == link then
                        local _, maxStack = GetSlotStackSize(BAG_BACKPACK, bagSlot)
                        if math.ceil((inventoryCount + quantity) / maxStack) - math.ceil(inventoryCount / maxStack) == 0 then
                            LootItemById(lootId)
                            if IsItemJunk(BAG_BACKPACK, bagSlot) then
                                lootedAs = "stackable junk"
                            else
                                lootedAs = "stackable item"
                            end
                        end
                        break
                    end
                end
            end
        end

        if lootedAs then
            if quality >= db.printLootThreshold and not deferTreasureLog then
                if lootedAs == "stackable junk" or lootedAs == "on whitelist junk" then
                    local part = GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. GetString(MSAL_SPACE) .. link
                    if lootedAs == "stackable junk" then
                        part = part .. GetString(MSAL_SPACE) ..
                                   zo_strformat(GetString(SI_QUEST_TYPE_FORMAT),
                            GetString(MSAL_LOOT_EXISTING_STACKABLE_ITEM))
                    end
                    table.insert(stackableJunkParts, part)
                else
                    local part = link
                    if lootedAs == "stackable item" then
                        chatlogPostfix = GetString(MSAL_LOOT_EXISTING_STACKABLE_ITEM)
                    end
                    if chatlogPostfix ~= "" then
                        part = part .. GetString(MSAL_SPACE) ..
                                   zo_strformat(GetString(SI_QUEST_TYPE_FORMAT), chatlogPostfix)
                    end
                    if chatlogSuffix then
                        part = part .. GetString(MSAL_SPACE) .. chatlogSuffix
                    end
                    table.insert(stackableLootedParts, part)
                end
            end
        else
            table.insert(currentNotLootedNameList, string.lower(name))
            table.insert(unwantedLootIdList, lootId)
            table.insert(unwantedNameList, string.lower(name))
        end

        DebugLog("item: " .. link .. ", looted as: " .. tostring(lootedAs))
    end

    if #stackableLootedParts > 0 then
        local logPart, lootedQuantity = {}, {}
        for _, part in ipairs(stackableLootedParts) do
            lootedQuantity[part] = (lootedQuantity[part] or 0) + 1
        end
        for _, part in ipairs(stackableLootedParts) do
            if lootedQuantity[part] then
                if lootedQuantity[part] > 1 then
                    table.insert(logPart, part .. " * " .. lootedQuantity[part])
                else
                    table.insert(logPart, part)
                end
                lootedQuantity[part] = nil
            end
        end
        local msg = GetString(SI_ITEM_ACTION_LOOT_TAKE) .. GetString(MSAL_SPACE) .. logPart[1]
        for i = 2, #logPart do
            msg = msg .. GetString(SI_LIST_COMMA_SEPARATOR) .. logPart[i]
        end
        ChatboxLog(msg)
    end

    if #stackableJunkParts > 0 then
        local logPart, lootedQuantity = {}, {}
        for _, part in ipairs(stackableJunkParts) do
            lootedQuantity[part] = (lootedQuantity[part] or 0) + 1
        end
        for _, part in ipairs(stackableJunkParts) do
            if lootedQuantity[part] then
                if lootedQuantity[part] > 1 then
                    table.insert(logPart, part .. " * " .. lootedQuantity[part])
                else
                    table.insert(logPart, part)
                end
                lootedQuantity[part] = nil
            end
        end
        local msg = logPart[1]
        for i = 2, #logPart do
            msg = msg .. GetString(SI_LIST_COMMA_SEPARATOR) .. logPart[i]
        end
        ChatboxLog(msg)
    end

    -- DebugLog("currentNotLootedNameList length: " .. tostring(#currentNotLootedNameList))
    -- ChatboxDebugLog("unwantedLootIdList: " .. tostring(#unwantedLootIdList))
    -- ChatboxDebugLog("length of id list: " .. #unwantedLootIdList)
    -- for i = 1, #unwantedLootIdList, 1 do
    --     ChatboxDebugLog("unwantedLootIdList" .. i .. ": " .. unwantedLootIdList[i])
    -- end
    -- ChatboxDebugLog("length of name list: " .. #unwantedNameList)
    -- for i = 1, #unwantedNameList, 1 do
    --     ChatboxDebugLog("unwantedNameList" .. i .. ": " .. unwantedNameList[i])
    -- end

    -- Performed after looting has been completed for the wanted items
    -- DebugLog("currentScene :"..currentScene)
    -- DebugLog("noCurtLeft :"..tostring(isAllCurtLooted))

    -- disposer will be triggered when there is unwanted loot and no crime will be committed. The transmute crystal will be naturally skipped cuz it's not a item and #unwantedLootIdList will be 0
    -- auto unboxed containers are looted outside the inventory scene, so match the target in the backpack too
    local fromBackpack = isBagContainer or (isUnboxing and IsLootingBackpackItem())
    local cleanBagContainerLeftovers = fromBackpack and db.cleanBagContainerLeftovers and
        db.unwantedItemsDisposer == "none"
    isJunkingBagContainerLeftovers = cleanBagContainerLeftovers and #unwantedLootIdList > 0
    if #unwantedLootIdList > 0 and not willCommitCrime and
        (db.unwantedItemsDisposer ~= "none" or cleanBagContainerLeftovers) then
        DebugLog("trigger disposer")
        EVENT_MANAGER:RegisterForEvent("MSAL_DISPOSED_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnDisposedUpdated)
        EVENT_MANAGER:AddFilterForEvent("MSAL_DISPOSED_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_IS_NEW_ITEM, true)
        EVENT_MANAGER:AddFilterForEvent("MSAL_DISPOSED_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        EVENT_MANAGER:AddFilterForEvent("MSAL_DISPOSED_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
        zo_callLater(function()
            EVENT_MANAGER:UnregisterForEvent("MSAL_DISPOSED_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
            -- can't use # here since it's a dictionary D:
            if next(disposeLogLines) ~= nil then
                local parts = {}
                for action, lines in pairs(disposeLogLines) do
                    local logParts, quantity = {}, {}
                    for _, line in ipairs(lines) do
                        quantity[line] = (quantity[line] or 0) + 1
                    end
                    for _, line in ipairs(lines) do
                        if quantity[line] then
                            if quantity[line] > 1 then
                                table.insert(logParts, line .. " * " .. quantity[line])
                            else
                                table.insert(logParts, line)
                            end
                            quantity[line] = nil
                        end
                    end
                    if action ~= "" then
                        table.insert(parts, action .. GetString(MSAL_SPACE) ..
                            table.concat(logParts, GetString(SI_LIST_COMMA_SEPARATOR)))
                    else
                        table.insert(parts, table.concat(logParts, GetString(SI_LIST_COMMA_SEPARATOR)))
                    end
                end
                ChatboxLog(table.concat(parts, GetString(SI_LIST_PERIOD_SEPARATOR)))
                disposeLogLines = {}
            end
        end, GetLatency() + 200)

        EVENT_MANAGER:UnregisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED)
        zo_callLater(function()
            EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED, MSAL.OnLootUpdatedThrottled)
        end, GetLatency() + 200)

        -- make sure it will be only triggered once
        if not isAllCurtLooted and isUnboxing == false then
            isAllCurtLooted = LootCurrenciesByRules(false)
        end

        local bListedSetGearList = {}
        local leftInWindow = false
        for i = 1, #unwantedLootIdList, 1 do
            local lootId = unwantedLootIdList[i]
            local link = GetLootItemLink(lootId)
            local isSetItem = IsItemLinkSetCollectionPiece(link)
            local name = LocalizeString("<<1>>", GetItemLinkName(link))
            if itemOnList(link, BLIST_TOKEN) and isSetItem then
                table.insert(bListedSetGearList, link)
                leftInWindow = true
            elseif IsItemLinkStolen(link) and (db.stolenRule == "never loot" or db.stolenRule == "never loot strict") then
                leftInWindow = true
            else
                LootItemById(lootId)
            end
        end
        if #bListedSetGearList > 0 then
            ChatboxLog(zo_strformat(GetString(MSAL_LIST_LOOTING_CONFLICT), bListedSetGearList[1]))
        end
        -- the disposer took everything it was handed, so the window has nothing left to show
        if not leftInWindow and isAllCurtLooted then
            DebugLog("closing loot window after disposer")
            lootWindowClosed = true
            EndLooting()
            SCENE_MANAGER:Hide("loot")
        end
    else
        if db.closeLootWindow then
            if (IsSameArray(currentNotLootedNameList, lastNotLootedNameList) and #currentNotLootedNameList ~= 0) then
                DebugLog("is Succession loot")
            end
            -- If it is not a succession loot then it need to be closed, unless its a bag container
            if not IsSameArray(currentNotLootedNameList, lastNotLootedNameList) then
                -- if the case is a bag container
                if isBagContainer then
                    if #currentNotLootedNameList == 0 and isAllCurtLooted then -- if it is a bag container and everything is looted then close it, otherwise do nothing
                        DebugLog("closing bag container loot window")
                        lootWindowClosed = true
                        EndLooting()
                        SCENE_MANAGER:Show(currentScene)
                    end
                else
                    if isAllCurtLooted then
                        DebugLog("closing loot window")
                        lootWindowClosed = true
                        EndLooting()
                        SCENE_MANAGER:HideCurrentScene()
                        -- SCENE_MANAGER:ShowBaseScene()
                    end
                end
            end
            lastNotLootedNameList = currentNotLootedNameList
        end
    end

    if #currentNotLootedNameList == 0 and isAllCurtLooted then
        DebugLog("secured closing loot window, showing: " .. currentScene)
        lootWindowClosed = true
        if not IsInGamepadPreferredMode() then
            EndLooting()
            SCENE_MANAGER:Show(currentScene)
            -- else
            --     EndLooting()
            --     SCENE_MANAGER:HideCurrentScene()
        end
    end
    isProcessingLoot = false
    lootActivityTimestamp = GetGameTimeMilliseconds()
end

function MSAL.OnLootUpdatedThrottled()
    -- EVENT_MANAGER:UnregisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED)
    lootActivityTimestamp = GetGameTimeMilliseconds()
    local currentTime = GetGameTimeMilliseconds()
    if currentTime - lastLootUpdatedTimetag > GetLatency() + 200 then
        OnLootUpdated()
        lastLootUpdatedTimetag = currentTime
    end
end

local function HasLootableContent()
    if GetNumLootItems() > 0 then
        return true
    end
    for _, info in pairs(LOOT_SHARED:GetLootCurrencyInformation()) do
        if info.currencyAmount > 0 or info.stolenCurrencyAmount > 0 then
            return true
        end
    end
    return false
end

local function PlaySkippedLootSound()
    if lootWindowSoundPlayed or SCENE_MANAGER:IsShowing("loot") then
        return
    end
    lootWindowSoundPlayed = true
    ZO_PlayLootWindowSound(false)
end

local function ScheduleLootWindowRecheck(lootSystem, ...)
    local args = { ... }
    local targetName = GetLootTargetInfo()
    zo_callLater(function()
        if not (db.enabled and db.closeLootWindow) or not IsLooting() then
            return
        end
        if GetLootTargetInfo() ~= targetName then
            return
        end
        MSAL.OnLootUpdatedThrottled()
        if lootWindowClosed then
            PlaySkippedLootSound()
            return
        end
        local original = lootWindowUpdateOriginals[lootSystem]
        if original then
            original(lootSystem, unpack(args))
        end
    end, GetLatency() * 2 + 300)
end

-- PC: loot inside the window refresh so the window is never drawn
local function OnLootWindowUpdate(lootSystem, ...)
    if not (db.enabled and db.closeLootWindow) or IsInGamepadPreferredMode() then
        return false
    end
    if isProcessingLoot then
        return true
    end
    if not HasLootableContent() then
        return false
    end
    local lastProcessed = lastLootUpdatedTimetag
    MSAL.OnLootUpdatedThrottled()
    DebugLog("loot window hook: target=" .. GetLootTargetInfo() .. ", items=" .. GetNumLootItems() ..
                 ", throttled=" .. tostring(lastLootUpdatedTimetag == lastProcessed) .. ", closed=" ..
                 tostring(lootWindowClosed))
    if lastLootUpdatedTimetag == lastProcessed then
        ScheduleLootWindowRecheck(lootSystem, ...)
        return true
    end
    if lootWindowClosed then
        PlaySkippedLootSound()
    end
    return lootWindowClosed
end

-- Console: the loot scene is already on its way in, hide it instead
local function OnLootSceneShow(sceneName, newState)
    if newState ~= SCENE_SHOWING or not (db.enabled and db.closeLootWindow) then
        return
    end
    MSAL.OnLootUpdatedThrottled()
    if not lootWindowClosed then
        return
    end
    -- hiding the scene at SHOWING skips the loot screen's own HideTooltip, so clean the tooltip up
    EndLooting()
    SCENE_MANAGER:Hide(sceneName)
    if sceneName == "lootInventoryGamepad" then
        LOOT_INVENTORY_WINDOW_GAMEPAD:HideTooltip()
    else
        LOOT_WINDOW_GAMEPAD:HideTooltip()
    end
    lootTooltipCleanupPending = true
end

local function RegisterLootWindowHooks()
    local keyboardLoot = SYSTEMS:GetKeyboardObject("loot")
    if keyboardLoot then
        lootWindowUpdateOriginals[keyboardLoot] = ZO_PreHook(keyboardLoot, "UpdateLootWindow", OnLootWindowUpdate)
    end
    local gamepadLoot = SYSTEMS:GetGamepadObject("loot")
    if gamepadLoot then
        lootWindowUpdateOriginals[gamepadLoot] = ZO_PreHook(gamepadLoot, "UpdateLootWindow", OnLootWindowUpdate)
    end
    for _, sceneName in ipairs({ "lootGamepad", "lootInventoryGamepad" }) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(_, newState)
                OnLootSceneShow(sceneName, newState)
            end)
        end
    end
end

local function OnLootClosed()
    isAllCurtLooted = true
    isBagContainer = false
    lootWindowSoundPlayed = false
    -- the loot screen recreates its tooltip out while the loot updates keep coming, so sweep again now
    if lootTooltipCleanupPending then
        lootTooltipCleanupPending = false
        LOOT_WINDOW_GAMEPAD:HideTooltip()
        LOOT_INVENTORY_WINDOW_GAMEPAD:HideTooltip()
    end
    isLALwaitingForUnboxingCraftReward = false
    if isWritsRewardContainerLooting then
        scheduleWritsRewardLootEnd(GetLatency() * 2 + 1000)
    end
    lootActivityTimestamp = GetGameTimeMilliseconds()
end

local function ListAutoDeconItems()
    DebugLog("ListAutoDeconItems called, " .. "autoDeconStation: " .. tostring(autoDeconStation) ..
                 ", autoDeconScanned: " .. tostring(autoDeconScanned))
    if not autoDeconStation then
        return
    end
    if autoDeconStation == ENCHANTING and ENCHANTING:GetEnchantingMode() ~= ENCHANTING_MODE_EXTRACTION or
        autoDeconStation == GAMEPAD_ENCHANTING and GAMEPAD_ENCHANTING:GetEnchantingMode() ~= ENCHANTING_MODE_EXTRACTION or
        autoDeconScanned then
        return
    end
    local deconMode = db.gearDisposer
    local scanGear = (deconMode == "decon" or deconMode == "decon and junk")
    local scanStyle = db.filters.styleMaterials3rdGearAutoDecon and db.filters.styleMaterials3rd == "per third"
    local scanRareTrait = db.filters.rareTrait == "loot and decon"
    local scanGlyphs = db.filters.glyphs == "loot and decon"
    local scanIntricate = db.filters.intricate == "loot and decon"
    if not scanGear and not scanStyle and not scanRareTrait and not scanGlyphs and not scanIntricate then
        return
    end
    local deconLinks = {}
    for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
        if not IsItemPlayerLocked(BAG_BACKPACK, bagSlot) then
            local link = GetItemLink(BAG_BACKPACK, bagSlot)
            local isCrafted = IsItemLinkCrafted(link)
            if isCrafted
            --  and GetItemCreatorName(BAG_BACKPACK, bagSlot) == GetUnitName("player") 
            then
                -- skip player-crafted items
            elseif link and link ~= "" then
                local itemType = GetItemLinkItemType(link)
                if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_GLYPH_ARMOR or
                    itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
                    if GetItemLinkDisplayQuality(link) >= ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
                        -- skip mythic items
                    else
                        -- items made via reconstruction are excluded from the auto-decon list
                        local isReconstructed = IsItemReconstructed(BAG_BACKPACK, bagSlot)
                        local trait = GetItemLinkTraitInfo(link)
                        local isJewelry = jewelryTraits[trait] and itemType == ITEMTYPE_ARMOR
                        local isGlyph = itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or
                                            itemType == ITEMTYPE_GLYPH_WEAPON

                        local stationTypeMatched = isUniDecon
                        if not stationTypeMatched then
                            if stationTradeSkill == CRAFTING_TYPE_WOODWORKING then
                                if itemType == ITEMTYPE_WEAPON then
                                    local gearType = GetItemLinkWeaponType(link)
                                    stationTypeMatched = (gearType == WEAPONTYPE_BOW or 
                                    gearType ==WEAPONTYPE_HEALING_STAFF or gearType ==
                                                             WEAPONTYPE_FIRE_STAFF or gearType == WEAPONTYPE_FROST_STAFF or
                                                             gearType == WEAPONTYPE_LIGHTNING_STAFF or gearType ==
                                                             WEAPONTYPE_SHIELD)
                                end
                            elseif stationTradeSkill == CRAFTING_TYPE_BLACKSMITHING then
                                if itemType == ITEMTYPE_WEAPON then
                                    local gearType = GetItemLinkWeaponType(link)
                                    stationTypeMatched = (gearType ~= WEAPONTYPE_BOW and gearType ~=
                                                             WEAPONTYPE_HEALING_STAFF and gearType ~=
                                                             WEAPONTYPE_FIRE_STAFF and gearType ~=
                                                             WEAPONTYPE_FROST_STAFF and gearType ~=
                                                             WEAPONTYPE_LIGHTNING_STAFF)
                                elseif itemType == ITEMTYPE_ARMOR then
                                    stationTypeMatched = (GetItemLinkArmorType(link) == ARMORTYPE_HEAVY)
                                end
                            elseif stationTradeSkill == CRAFTING_TYPE_JEWELRYCRAFTING then
                                stationTypeMatched = isJewelry
                            elseif stationTradeSkill == CRAFTING_TYPE_CLOTHIER then
                                if itemType == ITEMTYPE_ARMOR then
                                    local gearType = GetItemLinkArmorType(link)
                                    stationTypeMatched = (gearType == ARMORTYPE_LIGHT or gearType == ARMORTYPE_MEDIUM)
                                end
                            elseif stationTradeSkill == CRAFTING_TYPE_ENCHANTING then
                                stationTypeMatched = isGlyph
                            end
                        end
                        DebugLog("stationTypeMatched: " .. tostring(stationTypeMatched))
                        if stationTypeMatched then
                            if scanGear and GetItemLinkActorCategory(link) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                                local filterKey, _ = MSAL.FilterItem(link, false, nil)
                                if not filterKey then
                                    local shouldDecon = true
                                    if deconMode == "decon and junk" and db.deconThreshold > 0 then
                                        shouldDecon = GetItemLinkDisplayQuality(link) >= db.deconThreshold
                                    end
                                    if shouldDecon and not isReconstructed then
                                        autoDeconStation:RemoveItemFromCraft(BAG_BACKPACK, bagSlot)
                                        autoDeconStation:AddItemToCraft(BAG_BACKPACK, bagSlot)
                                        table.insert(deconLinks, link)
                                    end
                                    if deconMode == "decon and junk" then
                                        SetItemIsJunk(BAG_BACKPACK, bagSlot, true)
                                    end
                                end
                            end
                            if scanStyle and not isJewelry then
                                local styleId = GetItemLinkItemStyle(link)
                                if styleId > 0 then
                                    local styleMatLink = GetItemStyleMaterialLink(styleId)
                                    if styleMatLink ~= "" and IsThirdPartyOptionValid(db.filters.thirdParty) then
                                        if ShouldLootThirdPartyWorthyItem(db.filters.thirdParty, styleMatLink,
                                            db.filters.styleMaterials3rdPriceThreshold) then
                                            if not isReconstructed then
                                                autoDeconStation:RemoveItemFromCraft(BAG_BACKPACK, bagSlot)
                                                autoDeconStation:AddItemToCraft(BAG_BACKPACK, bagSlot)
                                                table.insert(deconLinks, link)
                                            end
                                        end
                                    end
                                end
                            end
                            if scanRareTrait then
                                local isRareWeaponTrait = trait == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
                                local isRareArmorTrait = trait == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
                                local isRareJewelryTrait = trait == ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY or trait ==
                                                               ITEM_TRAIT_TYPE_JEWELRY_HARMONY or trait ==
                                                               ITEM_TRAIT_TYPE_JEWELRY_INFUSED or trait ==
                                                               ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE or trait ==
                                                               ITEM_TRAIT_TYPE_JEWELRY_SWIFT or trait ==
                                                               ITEM_TRAIT_TYPE_JEWELRY_TRIUNE
                                if isRareWeaponTrait or isRareArmorTrait or isRareJewelryTrait then
                                    if not isReconstructed then
                                        autoDeconStation:RemoveItemFromCraft(BAG_BACKPACK, bagSlot)
                                        autoDeconStation:AddItemToCraft(BAG_BACKPACK, bagSlot)
                                        table.insert(deconLinks, link)
                                    end
                                end
                            end
                            if scanIntricate then
                                local isIntricate = trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or trait ==
                                                        ITEM_TRAIT_TYPE_WEAPON_INTRICATE or trait ==
                                                        ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
                                DebugLog("isIntricate: " .. tostring(isIntricate) .. ", not maxed: " .. tostring(not IsIntricateSkillMaxed(link, itemType)))
                                if isIntricate and not IsIntricateSkillMaxed(link, itemType) then
                                    if not isReconstructed then
                                        autoDeconStation:RemoveItemFromCraft(BAG_BACKPACK, bagSlot)
                                        autoDeconStation:AddItemToCraft(BAG_BACKPACK, bagSlot)
                                        table.insert(deconLinks, link)
                                    end
                                end
                            end
                            if scanGlyphs then
                                local filterKey, _ = MSAL.FilterItem(link, false, nil)
                                DebugLog("filterKey for glyphs: " .. tostring(filterKey))
                                if filterKey == "glyphs" then
                                    autoDeconStation:RemoveItemFromCraft(BAG_BACKPACK, bagSlot)
                                    autoDeconStation:AddItemToCraft(BAG_BACKPACK, bagSlot)
                                    table.insert(deconLinks, link)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if #deconLinks > 0 and db.deconLogEnabled then
        local logParts, quantity = {}, {}
        for _, lnk in ipairs(deconLinks) do
            quantity[lnk] = (quantity[lnk] or 0) + 1
        end
        for _, link in ipairs(deconLinks) do
            if quantity[link] then
                if quantity[link] > 1 then
                    table.insert(logParts, link .. "*" .. quantity[link])
                else
                    table.insert(logParts, link)
                end
                quantity[link] = nil
            end
        end
        local msg = GetString(MSAL_REGISTER_FOR_DECON) .. GetString(MSAL_SPACE) .. logParts[1]
        for i = 2, #logParts do
            msg = msg .. GetString(SI_LIST_COMMA_SEPARATOR) .. logParts[i]
        end
        ChatboxLog(msg)
    end
    autoDeconScanned = true
end

-- local function OnCraftingStationInteract(_, _ , _, craftingMode)
--     autoDeconScanned = false
--     if ZO_IsConsoleOrGameCoreUI() then
--         if ZO_Smithing_IsUniversalDeconstructionCraftingMode(craftingMode) then
--             autoDeconStation = UNIVERSAL_DECONSTRUCTION_GAMEPAD
--         else
--             autoDeconStation = SMITHING_GAMEPAD
--         end
--     else
--         if ZO_Smithing_IsUniversalDeconstructionCraftingMode(craftingMode) then
--             autoDeconStation = UNIVERSAL_DECONSTRUCTION
--         else
--             autoDeconStation = SMITHING
--         end
--     end
--     zo_callLater(StyleMatAutoDeconSelectItem, GetLatency() + 200)
-- end

local function GearDeconRegisterHooks()
    local function OnStationEnter(_, craftSkill)
        DebugLog("OnStationEnter called, craftSkill: " .. tostring(craftSkill))
        autoDeconStation = nil
        autoDeconScanned = false
        stationTradeSkill = craftSkill
        isUniDecon = craftSkill == 0
        if ZO_IsConsoleOrGameCoreUI() then
            if isUniDecon then
                autoDeconStation = UNIVERSAL_DECONSTRUCTION_GAMEPAD
            elseif stationTradeSkill == CRAFTING_TYPE_ENCHANTING then
                autoDeconStation = GAMEPAD_ENCHANTING
            else
                autoDeconStation = SMITHING_GAMEPAD
            end
        else
            if isUniDecon then
                autoDeconStation = UNIVERSAL_DECONSTRUCTION
            elseif stationTradeSkill == CRAFTING_TYPE_ENCHANTING then
                autoDeconStation = ENCHANTING
            else
                autoDeconStation = SMITHING
            end
        end
    end
    EVENT_MANAGER:RegisterForEvent("MSAL_STATION_ENTER", EVENT_CRAFTING_STATION_INTERACT, OnStationEnter)
    EVENT_MANAGER:RegisterForEvent("MSAL_STATION_EXIT", EVENT_END_CRAFTING_STATION_INTERACT, function()
        DebugLog("OnStationExit called")
        autoDeconScanned = false
    end)
    if ZO_IsConsoleOrGameCoreUI() then
        ZO_PostHook(UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel, "RefreshFilter", function()
            zo_callLater(ListAutoDeconItems, GetLatency() + 100)
        end)
        ZO_PostHook(SMITHING_GAMEPAD.deconstructionPanel, "RefreshTooltip", function()
            zo_callLater(ListAutoDeconItems, GetLatency() + 100)
        end)
        ZO_PostHook(GAMEPAD_ENCHANTING.inventory, "PerformFullRefresh", function()
            zo_callLater(ListAutoDeconItems, GetLatency() + 100)
        end)
    else
        ZO_PostHook(UNIVERSAL_DECONSTRUCTION.deconstructionPanel, "RefreshAccessibleCraftingTypeFilters", function()
            zo_callLater(ListAutoDeconItems, GetLatency() + 100)
        end)
        ZO_PostHook(SMITHING.deconstructionPanel.inventory, "PerformFullRefresh", function()
            zo_callLater(ListAutoDeconItems, GetLatency() + 100)
        end)
        ZO_PostHook(ENCHANTING.inventory, "AddItemData", function()
            zo_callLater(ListAutoDeconItems, GetLatency() + 100)
        end)
    end
end


if not ZO_IsConsoleOrGameCoreUI() then
    if LibCustomMenu then
        LibCustomMenu:RegisterContextMenu(function(inventorySlot, slotActions)
            if not db.contextMenuEnabled then
                return
            end
            local slotType = ZO_InventorySlot_GetType(inventorySlot)
            local link = nil
            if slotType == SLOT_TYPE_ITEM or slotType == SLOT_TYPE_EQUIPMENT or
                slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM or
                slotType == SLOT_TYPE_TRADING_HOUSE_POST_ITEM or slotType == SLOT_TYPE_REPAIR or
                slotType == SLOT_TYPE_CRAFTING_COMPONENT or slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT or
                slotType == SLOT_TYPE_CRAFT_BAG_ITEM then
                local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
                link = GetItemLink(bagId, slotIndex)
            end
            if link and link ~= "" then
                AddCustomMenuItem(GetString(MSAL_CONTEXT_ADD_WHITELIST), function()
                    MSAL.ContextAddToList(link, WLIST_TOKEN)
                end)
                AddCustomMenuItem(GetString(MSAL_CONTEXT_ADD_WHITELIST) .. " (" ..
                                      "|t28:28:EsoUI/Art/inventory/inventory_tabicon_junk_up.dds|t" .. ")", function()
                    MSAL.ContextAddToList(link, WLIST_JUNK_TOKEN)
                end)
            end
        end)
    end

    ZO_PostHook(ZO_ItemSetCollectionPieceTile_Keyboard, "ShowMenu", function(self)
        if not db.contextMenuEnabled then
            return
        end
        local link = self.itemSetCollectionPieceData:GetItemLink()
        if itemOnList(link, BLIST_TOKEN) then
            return
        end
        if LibCustomMenu then
            AddCustomMenuItem(GetString(MSAL_CONTEXT_ADD_BLACKLIST), function()
                MSAL.ContextAddToList(link, BLIST_TOKEN)
            end)
        -- else
        --     AddMenuItem("AL+: " .. GetString(MSAL_BLIST), function()
        --         MSAL.ContextAddToList(link, BLIST_TOKEN)
        --     end)
        end
        ShowMenu(self.control)
    end)
end

-- Use SecurePostHook. ZO_PostHook would taint UseItem's protected call path.
if ZO_IsConsoleOrGameCoreUI() then
    local consoleListActionsRegistered = false

    local function ToggleBackpackJunk(bag, index)
        if not CanItemBeMarkedAsJunk(bag, index) then
            return
        end
        local markJunk = not IsItemJunk(bag, index)
        SetItemIsJunk(bag, index, markJunk)
        PlaySound(markJunk and SOUNDS.INVENTORY_ITEM_JUNKED or SOUNDS.INVENTORY_ITEM_UNJUNKED)

        if SCENE_MANAGER:IsShowing("gamepad_inventory_root") or SCENE_MANAGER:IsSceneOnStack("gamepad_inventory_root") then
            local currentList = GAMEPAD_INVENTORY:GetCurrentList()
            if currentList and currentList:GetNumEntries() == 1 then
                GAMEPAD_INVENTORY:SwitchActiveList("categoryList", true)
            end
        end

        CALLBACK_MANAGER:FireCallbacks("InventorySlotUpdate", SHARED_INVENTORY:GenerateSingleSlotData(bag, index))
        GAMEPAD_INVENTORY:MarkDirty()
    end

    local function RegisterConsoleListActions()
        if consoleListActionsRegistered then
            return
        end
        consoleListActionsRegistered = true
        SecurePostHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", function(inventorySlot, slotActions)
            local valid = ZO_Inventory_GetBagAndIndex(inventorySlot)
            if not valid then
                return
            end
            local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)

            if db.contextJunkingEnabled and bag == BAG_BACKPACK then
                local actorCategory = GetItemActorCategory(bag, index)
                if actorCategory ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION and CanItemBeMarkedAsJunk(bag, index) then
                    local isJunk = IsItemJunk(bag, index)
                    if isJunk or not IsItemPlayerLocked(bag, index) then
                        slotActions:AddSlotAction(isJunk and MSAL_CONTEXT_UNMARK_JUNK or MSAL_CONTEXT_MARK_JUNK,
                            function()
                                ToggleBackpackJunk(bag, index)
                            end, "secondary")
                    end
                end
            end

            if not db.contextMenuEnabled then
                return
            end
            local slotType = ZO_InventorySlot_GetType(inventorySlot)
            if not (slotType == SLOT_TYPE_ITEM or slotType == SLOT_TYPE_EQUIPMENT or
                slotType == SLOT_TYPE_GAMEPAD_INVENTORY_ITEM or
                -- slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM or
                -- slotType == SLOT_TYPE_TRADING_HOUSE_POST_ITEM or slotType == SLOT_TYPE_REPAIR or
                -- slotType == SLOT_TYPE_CRAFTING_COMPONENT or slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT or
                slotType == SLOT_TYPE_CRAFT_BAG_ITEM) then
                return
            end
            local link = GetItemLink(bag, index)
            if link == nil or link == "" then
                return
            end
            slotActions:AddSlotAction(MSAL_CONTEXT_ADD_WHITELIST, function()
                MSAL.ContextAddToList(link, WLIST_TOKEN)
            end, "secondary")
            slotActions:AddSlotAction(MSAL_CONTEXT_ADD_WHITELIST_JUNK, function()
                MSAL.ContextAddToList(link, WLIST_JUNK_TOKEN)
            end, "secondary")
        end)
    end

    EVENT_MANAGER:RegisterForEvent("MSAL_CONSOLE_LIST_ACTIONS", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent("MSAL_CONSOLE_LIST_ACTIONS", EVENT_PLAYER_ACTIVATED)
        -- zo_callLater(RegisterConsoleListActions, 1000)
        local scene = SCENE_MANAGER:GetScene("gamepad_inventory_root")
        scene:RegisterCallback("StateChange", function(_, newState)
            if (newState == SCENE_SHOWING or newState == SCENE_SHOWN) and
                (db.contextMenuEnabled or db.contextJunkingEnabled) then
                RegisterConsoleListActions()
            end
        end)
    end)

    local JUNK_CATEGORY_ICON = "EsoUI/Art/Inventory/inventory_tabicon_junk_down.dds"
    local injectedCategoryLists = {}

    local function RegisterCategoryInjection(gamepadInventory)
        if not gamepadInventory then
            return
        end
        local categoryList = gamepadInventory.categoryList
        if not categoryList or injectedCategoryLists[categoryList] then
            return
        end
        injectedCategoryLists[categoryList] = true

        local categoryInjected = false

        ZO_PreHook(categoryList, "Clear", function()
            categoryInjected = false
        end)

        ZO_PreHook(categoryList, "AddEntry", function(list, _, data)
            if not categoryInjected and data and data.equipSlot then
                categoryInjected = true
                if db and db.contextJunkingEnabled then
                    gamepadInventory:AddFilteredBackpackCategoryIfPopulated(ITEMFILTERTYPE_JUNK, JUNK_CATEGORY_ICON)
                end
            end
        end)

        ZO_PreHook(categoryList, "Commit", function()
            if not categoryInjected then
                categoryInjected = true
                if db and db.contextJunkingEnabled then
                    gamepadInventory:AddFilteredBackpackCategoryIfPopulated(ITEMFILTERTYPE_JUNK, JUNK_CATEGORY_ICON)
                end
            end
        end)
    end

    local originalGetItemDataFilterComparator = ZO_GamepadInventory.GetItemDataFilterComparator
    function ZO_GamepadInventory:GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)
        return function(itemData)
            if db and db.contextJunkingEnabled and itemData.bagId == BAG_BACKPACK and itemData.slotIndex
                and IsItemJunk(itemData.bagId, itemData.slotIndex) then
                if itemData.actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                    return false
                end
                if nonEquipableFilterType ~= ITEMFILTERTYPE_JUNK then
                    return false
                end
                return self:IsDataInSearchTextResults(itemData.bagId, itemData.slotIndex)
            end
            return originalGetItemDataFilterComparator(self, filteredEquipSlot, nonEquipableFilterType)(itemData)
        end
    end

    local originalDoesNewItemMatchSupplies = ZO_InventoryUtils_DoesNewItemMatchSupplies
    function ZO_InventoryUtils_DoesNewItemMatchSupplies(itemData)
        if db and db.contextJunkingEnabled and itemData.bagId == BAG_BACKPACK then
            local isJunk = itemData.isJunk
            if itemData.slotIndex then
                isJunk = IsItemJunk(itemData.bagId, itemData.slotIndex)
            end
            if isJunk then
                return false
            end
        end
        return originalDoesNewItemMatchSupplies(itemData)
    end

    SecurePostHook(ZO_GamepadInventory, "InitializeCategoryList", function(gamepadInventory)
        RegisterCategoryInjection(gamepadInventory)
    end)

    RegisterCategoryInjection(GAMEPAD_INVENTORY)

    local gamepadSetPieceActionsRegistered = false
    local function RegisterGamepadSetPieceActions()
        if gamepadSetPieceActionsRegistered then
            return true
        end
        local dialog = ESO_Dialogs and ESO_Dialogs["GAMEPAD_ITEM_SETS_BOOK_OPTIONS_DIALOG"]
        if not dialog or not dialog.parametricList then
            return false
        end
        gamepadSetPieceActionsRegistered = true
        table.insert(dialog.parametricList, {
            template = "ZO_GamepadFullWidthLeftLabelEntryTemplate",
            templateData = {
                -- Already blacklisted pieces keep the entry, shown greyed out as "Blacklisted Already"
                text = GetString(MSAL_CONTEXT_ADD_BLACKLIST),
                setup = function(control, data, selected, reselected, ...)
                    -- the runtime dialog carries .data; the registered info table captured above does not
                    local pieceData = data.dialog and data.dialog.data and
                        data.dialog.data.selectedItemSetCollectionPieceData
                    local link = pieceData and pieceData:GetItemLink()
                    local blacklisted = link ~= nil and link ~= "" and itemOnList(link, BLIST_TOKEN)
                    data.text = blacklisted and GetString(MSAL_CONTEXT_ALREADY_BLACKLISTED) or
                        GetString(MSAL_CONTEXT_ADD_BLACKLIST)
                    data.enabled = not blacklisted
                    ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselected, ...)
                end,
                callback = function(dialog)
                    local pieceData = dialog.data and dialog.data.selectedItemSetCollectionPieceData
                    if pieceData then
                        local link = pieceData:GetItemLink()
                        if link and link ~= "" and not itemOnList(link, BLIST_TOKEN) then
                            MSAL.ContextAddToList(link, BLIST_TOKEN)
                        end
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress("GAMEPAD_ITEM_SETS_BOOK_OPTIONS_DIALOG")
                end,
                visible = function(dialog)
                    if not db.contextMenuEnabled then
                        return false
                    end
                    local pieceData = dialog.data and dialog.data.selectedItemSetCollectionPieceData
                    if not pieceData then
                        return false
                    end
                    local link = pieceData:GetItemLink()
                    return link ~= nil and link ~= ""
                end,
            },
        })
        return true
    end
    if not RegisterGamepadSetPieceActions() then
        EVENT_MANAGER:RegisterForEvent("MSAL_GAMEPAD_SET_PIECE_ACTIONS", EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent("MSAL_GAMEPAD_SET_PIECE_ACTIONS", EVENT_PLAYER_ACTIVATED)
            RegisterGamepadSetPieceActions()
        end)
    end
end

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent("MSAL_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED)
    if db.enabled then
        isUsingVanillaAutoLoot = tonumber(GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT)) == 1
        if isUsingVanillaAutoLoot then
            if not ZO_IsConsoleOrGameCoreUI() then
                if not db.neverAutolootWarning then
                    local closeLink = ZO_LinkHandler_CreateLinkWithoutBrackets(GetString(MSAL_AUTOLOOT_DISABLE_TEXT),
                        nil, MSAL_AUTOLOOT_DISABLE)
                    local dismissLink = ZO_LinkHandler_CreateLinkWithoutBrackets(GetString(MSAL_AUTOLOOT_DISMISS_TEXT),
                        nil, MSAL_AUTOLOOT_DISMISS)
                    zo_callLater(function()
                        ChatboxPrint(chatboxPrefix .. zo_strformat(GetString(MSAL_AUTOLOOT_CONFLICT_WARNING), closeLink, dismissLink))
                    end, GetLatency() + 100)
                end
                EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED, MSAL.OnLootUpdatedThrottled)
            else
                zo_callLater(function()
                    ChatboxPrint(chatboxPrefix .. zo_strformat(GetString(MSAL_CONSOLE_ENABLED_REMINDER), GetString(SI_GAMEPAD_OPTIONS_MENU),
                        GetString(SI_SETTINGSYSTEMPANEL4), GetString(SI_GAMEPLAY_OPTIONS_ITEMS)))
                end, GetLatency() + 100)
            end
        else
            if dbAccount.latestMajorUpdateVersion ~= "8.3.0" then
                dbAccount.latestMajorUpdateVersion = "8.3.0"
                if ZO_IsConsoleOrGameCoreUI() then
                    zo_callLater(function()
                        ChatboxPrint(chatboxPrefix .. GetString(MSAL_UPDATE_IMFORM_CONSOLE))
                    end, GetLatency() + 100)
                end
                -- if not ZO_IsConsoleOrGameCoreUI() then
                --     ZO_Dialogs_RegisterCustomDialog("MSAL_MAJOR_UPDATE", {
                --         title = {
                --             text = "|c2e5c8cL|r|c385f86y|r|c416281k|r|c4b657be|r|c546976i|r|c5d6c70o|r|c676f6bn|r|c707265'|r|c7a7560s|r |c83785aA|r|c8c7b55u|r|c967e4ft|r|c9f814ao|r|ca88544L|r|cb2883fo|r|cbb8b39o|r|cc58e34t|r|cce912e+|r"
                --         },
                --         mainText = {
                --             text = GetString(MSAL_UPDATE_IMFORM) .. GetString(MSAL_UPDATE_IMFORM_PC)
                --         },
                --         buttons = {
                --             {
                --                 text = GetString(SI_GUILD_HISTORY_SHOW_MORE),
                --                 callback = function()
                --                     OpenSettingsPanel()
                --                 end
                --             },
                --             {
                --                 text = SI_DIALOG_CANCEL
                --             }
                --         }
                --     })
                --     EVENT_MANAGER:RegisterForUpdate("MSAL_UPDATE_DIALOG", 1000, function()
                --         if not ZO_Dialogs_IsShowingDialog() then
                --             ZO_Dialogs_ShowDialog("MSAL_MAJOR_UPDATE")
                --             EVENT_MANAGER:UnregisterForUpdate("MSAL_UPDATE_DIALOG")
                --         end
                --     end)
                
            else
                if db.loginReminder == true
                and db.lastStartup ~= os.date("%Y%m%d")
                then
                    db.lastStartup = os.date("%Y%m%d")
                    zo_callLater(function()
                        ChatboxPrint(chatboxPrefix .. GetString(MSAL_PANEL_DISPLAYNAME) .. " |ccc922f" .. MSAL.version ..
                                    GetString(MSAL_SPACE) ..
                                    GetString(SI_GAMEPAD_MARKET_FREE_TRIAL_TILE_ACTIVE_TEXT))
                    end, GetLatency() + 100)

                    if db.closeLootWindow then
                        zo_callLater(function()
                            ChatboxPrint(chatboxPrefix .. GetString(MSAL_CLOSE_LOOT_WINDOW_WARNING))
                        end, GetLatency() + 200)
                    end
                    -- if db.autoUnboxUnopened then
                    --     ChatboxPrint(chatboxPrefix ..
                    --         zo_strformat(GetString(MSAL_LOGIN_ENABLED_REMINDER),
                    --             zo_strformat(GetString(MSAL_AUTO_UNBOX), GetString(SI_ITEMTYPE75))))
                    -- end
                    if db.stolenRule == "never loot strict" then
                        zo_callLater(function()
                            ChatboxPrint(chatboxPrefix .. GetString(MSAL_STRICT_STEAL_WARNING))
                        end, GetLatency() + 200)
                    end
                    if db.stolenTreasureThreshold > ITEM_DISPLAY_QUALITY_TRASH then
                        zo_callLater(function()
                            ChatboxPrint(chatboxPrefix ..
                                zo_strformat(GetString(MSAL_STOLEN_TREASURE_FILTER_LOGIN_REMINDER),
                                    GetStolenTreasureQualityLabel(db.stolenTreasureThreshold, chatboxLogColor)))
                        end, GetLatency() + 200)
                    end
                end
            end
            EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED, MSAL.OnLootUpdatedThrottled)
        end
    end

    GearDeconRegisterHooks()
    RegisterLootWindowHooks()

    EVENT_MANAGER:UnregisterForEvent("MSAL_DISPOSED_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent("MSAL_DESTROY_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent("MSAL_JUNKING_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

local function ToggleAddon()
        if db.enabled == false then
        if not ZO_IsConsoleOrGameCoreUI() then
            SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT, 0)
        end
        db.enabled = true
        EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED, MSAL.OnLootUpdatedThrottled)
        EVENT_MANAGER:RegisterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdate)
        EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_IS_NEW_ITEM, true)
        EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
        EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_CLOSED", EVENT_LOOT_CLOSED, OnLootClosed)
        EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_STORE", EVENT_OPEN_STORE, OnOpenStore)
        EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_FENCE", EVENT_OPEN_FENCE, OnOpenFence)
        EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_LAUNDER", EVENT_OPEN_FENCE, OnOpenLaunder)
        EVENT_MANAGER:RegisterForEvent("MSAL_LOCKPICK_SUCCESS", EVENT_LOCKPICK_SUCCESS, OnLockpickSuccess)
        -- EVENT_MANAGER:RegisterForEvent("MSAL_INTERACT_CHECK", EVENT_CLIENT_INTERACT_RESULT, OnInteractResult)
        -- EVENT_MANAGER:RegisterForEvent("MSAL_INTERACT_CANCEL", EVENT_PENDING_INTERACTION_CANCELLED,
        --     OnInteractCancelled)
        ChatboxPrint(GetString(MSAL_PANEL_DISPLAYNAME) .. " |cce912e" ..
                                            GetString(SI_SCREEN_NARRATION_TOGGLE_ON) .. "|r")
    else
        db.enabled = false
        EVENT_MANAGER:UnregisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED)
        EVENT_MANAGER:UnregisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED)
        EVENT_MANAGER:UnregisterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        EVENT_MANAGER:UnregisterForEvent("MSAL_LOOT_CLOSED", EVENT_LOOT_CLOSED)
        EVENT_MANAGER:UnregisterForEvent("MSAL_OPEN_STORE", EVENT_OPEN_STORE)
        EVENT_MANAGER:UnregisterForEvent("MSAL_OPEN_FENCE", EVENT_OPEN_FENCE)
        EVENT_MANAGER:UnregisterForEvent("MSAL_OPEN_LAUNDER", EVENT_OPEN_FENCE)
        EVENT_MANAGER:UnregisterForEvent("MSAL_LOCKPICK_SUCCESS", EVENT_LOCKPICK_SUCCESS)
        -- EVENT_MANAGER:UnregisterForEvent("MSAL_INTERACT_CHECK", EVENT_CLIENT_INTERACT_RESULT)
        -- EVENT_MANAGER:UnregisterForEvent("MSAL_INTERACT_CANCEL", EVENT_PENDING_INTERACTION_CANCELLED)
        ChatboxPrint(GetString(MSAL_PANEL_DISPLAYNAME) .. " |c2e5c8c" ..
                                            GetString(SI_SCREEN_NARRATION_TOGGLE_OFF) .. "|r")
    end
    local enableControl = WM:GetControlByName("MSAL_Enable")
    if enableControl then
        enableControl:UpdateValue(false, db.enabled)
    end
end

local function OnLoaded(_, addon)
    if addon ~= "MuchSmarterAutoLoot" then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("MuchSmarterAutoLoot", EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent("MSAL_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdate)
    EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM,
        true)
    EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID,
        BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_CLOSED", EVENT_LOOT_CLOSED, OnLootClosed)
    EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_STORE", EVENT_OPEN_STORE, OnOpenStore)
    EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_FENCE", EVENT_OPEN_FENCE, OnOpenFence)
    EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_LAUNDER", EVENT_OPEN_FENCE, OnOpenLaunder)
    EVENT_MANAGER:RegisterForEvent("MSAL_LOCKPICK_SUCCESS", EVENT_LOCKPICK_SUCCESS, OnLockpickSuccess)
    -- EVENT_MANAGER:RegisterForEvent("MSAL_INTERACT_CHECK", EVENT_CLIENT_INTERACT_RESULT, OnInteractResult)
    -- EVENT_MANAGER:RegisterForEvent("MSAL_INTERACT_CANCEL", EVENT_PENDING_INTERACTION_CANCELLED, OnInteractCancelled)

    dbAccount, dbChar, db = MSAL.Settings.InitializeSavedVariables()

    if not ZO_IsConsoleOrGameCoreUI() then
        ReorganizeLootWindowButtons()
        lootWindowShortcutButton = CreateControlFromVirtual("MSAL_ShortcutButton", ZO_Loot, "ZO_LootMSALShortcut")
        local customAnchor = ZO_Anchor:New(TOPRIGHT, ZO_Loot, TOPRIGHT, 0, -6)
        customAnchor:Set(lootWindowShortcutButton)

        lootWindowShortcutButton:SetHandler("OnMouseEnter", function(self)
            ZO_Tooltips_ShowTextTooltip(self, TOP, "AutoLoot+ " .. GetString(SI_GAME_MENU_SETTINGS))
        end)
        lootWindowShortcutButton:SetHandler("OnMouseExit", function(self)
            ZO_Tooltips_HideTextTooltip()
        end)

        -- perfectpixel adaption
        if PP then
            ZO_LootAlphaContainerButtonJunkingKeyLabel:SetFont("$(PP_MEDIUM_FONT)|" ..
                                                                   ZO_LootAlphaContainerButton1KeyLabel:GetFontSize() ..
                                                                   "|outline")
            ZO_LootAlphaContainerButtonJunkingNameLabel:SetFont("$(PP_BOLD_FONT)|" ..
                                                                    ZO_LootAlphaContainerButton1NameLabel:GetFontSize() ..
                                                                    "|outline")

            ZO_LootAlphaContainerButtonDestroyKeyLabel:SetFont("$(PP_MEDIUM_FONT)|" ..
                                                                   ZO_LootAlphaContainerButton1KeyLabel:GetFontSize() ..
                                                                   "|outline")
            ZO_LootAlphaContainerButtonDestroyNameLabel:SetFont("$(PP_BOLD_FONT)|" ..
                                                                    ZO_LootAlphaContainerButton1NameLabel:GetFontSize() ..
                                                                    "|outline")
        end
    else
        -- dev on PCNA
        TSCApi = TSCPriceDataAPI

        if LibRadialMenu then
            LibRadialMenu:RegisterAddon("MSAL", "AutoLoot+")
            LibRadialMenu:RegisterEntry("MSAL", zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE18)), 4,
                "/esoui/art/treeicons/menubar_goldcoastbazaar_up.dds", MSAL.UnboxInventoryContainer,
                GetString(MSAL_LRM_UNBOX_CONTAINER_TOOLTIP))
            LibRadialMenu:RegisterEntry("MSAL", zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE75)), 5,
                "/esoui/art/treeicons/menubar_tamrieltomes_up.dds", MSAL.UnboxInventoryUnopened,
                zo_strformat(GetString(MSAL_LRM_UNBOX_TOOLTIP), GetString(SI_ITEMTYPE75)))
            LibRadialMenu:RegisterEntry("MSAL", zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE54)), 6,
                "/esoui/art/tutorial/tutorial_idexicon_fishing_up.dds", MSAL.UnboxInventoryFish,
                zo_strformat(GetString(MSAL_LRM_UNBOX_TOOLTIP), GetString(SI_ITEMTYPE54)))
            LibRadialMenu:RegisterEntry("MSAL", zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE70)), 7,
                "/esoui/art/tutorial/tutorial_idexicon_fishing_up.dds", MSAL.UnboxInventoryGeode,
                zo_strformat(GetString(MSAL_LRM_UNBOX_TOOLTIP), GetString(SI_ITEMTYPE70)))
        end
    end
    
    -- handle legacy sv
    if db.latestMinorUpdateVersion ~= MSAL.addonVersion then
        local oldVersion = nil
        if db.latestMinorUpdateVersion then
            oldVersion = tonumber(db.latestMinorUpdateVersion)
        end

        if not oldVersion or oldVersion < 80000 then
            -- migrate pre-8.0.0 numeric item IDs to item links
            local templateItemlink = "|H1:item:%s:307:50:0:0:0:0:0:0:0:0:0:0:0:0:36:0:0:0:0:0|h|h"
            local function migrateList(list)
                for i = #list, 1, -1 do
                    if type(list[i]) == "number" then
                        list[i] = string.format(templateItemlink, list[i])
                    end
                end
            end
            migrateList(dbAccount.blacklist)
            migrateList(dbAccount.whitelist)
            migrateList(dbAccount.wlistJunk)
            migrateList(dbChar.blacklist)
            migrateList(dbChar.whitelist)
            migrateList(dbChar.wlistJunk)
        end

        if not oldVersion or oldVersion < 80100 then
            -- remove empty strings from all lists
            local function cleanList(list)
                for i = #list, 1, -1 do
                    if not list[i] or list[i] == "" or GetItemLinkItemId(list[i]) == 0 then
                        table.remove(list, i)
                    end
                end
            end
            cleanList(dbAccount.blacklist)
            cleanList(dbAccount.whitelist)
            cleanList(dbAccount.wlistJunk)
            cleanList(dbChar.blacklist)
            cleanList(dbChar.whitelist)
            cleanList(dbChar.wlistJunk)
        end

        -- deal with legacy options
        if db.filters.uncapped ~= nil then
            db.filters.lootCurrencies = db.filters.uncapped
            db.filters.uncapped = nil
        end
        if db.filters.lootCappedCurrencies ~= nil then
            db.filters.lootCurrencies = db.filters.lootCappedCurrencies
            db.filters.lootCappedCurrencies = nil
        end
        if db.greedyMode ~= nil then
            db.alwaysLootStackable = db.greedyMode
            db.greedyMode = nil
        end
        if db.autoBindDispose ~= nil then
            db.autoDisposeAfterBind = db.autoBindDispose
            db.autoBindDispose = nil
        end
        if db.printLootThresholdNumber ~= nil then
            db.printLootThreshold = db.printLootThresholdNumber
            db.printLootThresholdNumber = nil
        end
        if db.considerateModePrint then
            if db.printItemThreshold and type(db.printItemThreshold) == "boolean" then
                db.printDisposeThresholdNumber = 4
                db.printItemThreshold = nil
            end
            db.considerateModePrint = nil
        end
        if db.printItemThreshold ~= nil then
            db.printItemThreshold = nil
        end
        if db.printDisposeThresholdNumber ~= nil then
            if type(db.printDisposeThresholdNumber) == "boolean" then
                db.printDisposeThreshold = 4
            else
                db.printDisposeThreshold = db.printDisposeThresholdNumber
            end
            db.printDisposeThresholdNumber = nil
        end
        if db.hostLootAll ~= nil then
            db.hostNativeLootAll = db.hostLootAll
            db.hostLootAll = nil
        end
        if db.filters.alwaysLootUnknown ~= nil then
            db.filters.recipesAlwaysLootUnknown = db.filters.alwaysLootUnknown
            db.filters.alwaysLootUnknown = nil
        end
        if (db.filters.recipes == "only unknown") then
            db.filters.recipes = "never loot"
            db.filters.recipesAlwaysLootUnknown = true
        end
        if db.stolenRule == "follow without mats" then
            db.stolenRule = "follow"
        end
        if db.filters.ornate == "per value threshold" then
            db.filters.ornate = "always loot"
        end
        if db.filters.weapons == "per value threshold" then
            db.filters.weapons = "never loot"
        end
        if db.filters.armors == "per value threshold" then
            db.filters.armors = "never loot"
        end
        if db.filters.jewelry == "per value threshold" then
            db.filters.jewelry = "never loot"
        end
        if db.considerateMode and db.considerateMode == true then
            db.overlandHandler = "destroy"
            db.considerateMode = nil
        end
        if db.applyHandlerToAll then
            if db.applyHandlerToAll == true then
                if db.overlandHandler and db.overlandHandler == "destroy" then
                    db.unwantedItemsDisposer = "destroy"
                elseif db.overlandHandler and db.overlandHandler == "junk" then
                    db.unwantedItemsDisposer = "junk"
                else
                    db.unwantedItemsDisposer = "none"
                end
                db.overlandHandler = nil
                db.disposerOnOverlandNodesOnly = false
            else
                if db.overlandHandler and db.overlandHandler == "destroy" then
                    db.unwantedItemsDisposer = "destroy"
                elseif db.overlandHandler and db.overlandHandler == "junk" then
                    db.unwantedItemsDisposer = "junk"
                else
                    db.unwantedItemsDisposer = "none"
                end
                db.overlandHandler = nil
                db.disposerOnOverlandNodesOnly = true
            end
            db.applyHandlerToAll = nil
        end
        if db.disposerOnOverlandNodesOnly then
            db.disposerOnOverlandNodes = db.disposerOnOverlandNodesOnly
            db.disposerOnOverlandNodesOnly = nil
        end
        if db.minimumQuality then
            if db.minimumQuality == 3 then
                if db.filters.companionGears == "per quality threshold" then
                    db.filters.companionGears = "only blue"
                end
                if db.filters.weapons == "per quality threshold" then
                    db.filters.weapons = "only blue"
                end
                if db.filters.armors == "per quality threshold" then
                    db.filters.armors = "only blue"
                end
                if db.filters.jewelry == "per quality threshold" then
                    db.filters.jewelry = "only blue"
                end
                if db.filters.treasures == "per quality threshold" then
                    db.filters.treasures = "only blue"
                end
            elseif db.minimumQuality == 4 then
                if db.filters.companionGears == "per quality threshold" then
                    db.filters.companionGears = "only purple"
                end
                if db.filters.weapons == "per quality threshold" then
                    db.filters.weapons = "only purple"
                end
                if db.filters.armors == "per quality threshold" then
                    db.filters.armors = "only purple"
                end
                if db.filters.jewelry == "per quality threshold" then
                    db.filters.jewelry = "only purple"
                end
                if db.filters.treasures == "per quality threshold" then
                    db.filters.treasures = "only purple"
                end
            elseif db.minimumQuality == 5 then
                if db.filters.companionGears == "per quality threshold" then
                    db.filters.companionGears = "only purple"
                end
                if db.filters.weapons == "per quality threshold" then
                    db.filters.weapons = "only purple"
                end
                if db.filters.armors == "per quality threshold" then
                    db.filters.armors = "only purple"
                end
                if db.filters.jewelry == "per quality threshold" then
                    db.filters.jewelry = "only gold"
                end
                if db.filters.treasures == "per quality threshold" then
                    db.filters.treasures = "only purple"
                end
            else
                if db.filters.companionGears == "per quality threshold" then
                    db.filters.companionGears = "always loot"
                end
                if db.filters.weapons == "per quality threshold" then
                    db.filters.weapons = "always loot"
                end
                if db.filters.armors == "per quality threshold" then
                    db.filters.armors = "always loot"
                end
                if db.filters.jewelry == "per quality threshold" then
                    db.filters.jewelry = "always loot"
                end
                if db.filters.treasures == "per quality threshold" then
                    db.filters.treasures = "always loot"
                end
            end
            db.minimumQuality = nil
        end
        if db.filters.treasures == "only blue" or db.filters.treasures == "only purple" then
            db.filters.treasures = "always loot and mark"
        end
        if db.filters.treasures == "always loot and mark" then
            db.filters.treasures = "loot and junk"
        end
        if db.never3rdPartyWaining then
            if db.never3rdPartyWaining == true then
                db.never3rdPartyWarning = true
            end
            db.never3rdPartyWaining = nil
        end
        if db.disposerOnOverlandNodes then
            db.disposerOnOverlandNodes = nil
        end
        if db.disposerOnBagContainer then
            db.disposerOnBagContainer = nil
        end
        if db.filters.set and db.filters.set == "uncollected and non-jewelry" then
            db.filters.set = "only uncollected"
        end
        if db.filters.uncollected then
            db.filters.uncollected = nil
        end
        if db.autoUnboxTimeout then
            db.autoUnboxTimeout = nil
        end
        if db.unboxingDisposer then
            db.unboxingDisposer = nil
        end
        if db.printItems then
            db.printItems = nil
        end
        if db.filters.lootThirdPartyNoPrice then
            db.filters.lootThirdPartyNoPrice = nil
        end
        if db.overlandNodeDisposer ~= nil then
            db.overlandNodeDisposer = nil
        end
        if db.bagContainerDisposer ~= nil then
            db.bagContainerDisposer = nil
        end
        if db.filters.craftingMaterials then
            db.filters.blacksmithingMaterials = db.filters.craftingMaterials
            db.filters.clothingMaterials = db.filters.craftingMaterials
            db.filters.woodworkingMaterials = db.filters.craftingMaterials
            db.filters.jewelryCraftingMaterials = db.filters.craftingMaterials
            db.filters.refineMaterials = db.filters.craftingMaterials
            db.filters.craftingMaterials = nil
        end
        if db.filters.treasuresAutoMark then
            db.filters.treasuresAutoMark = nil
        end
        if db.initPlusCheck then
            db.initPlusCheck = nil
        end
        if db.autoUnboxContainer and type(db.autoUnboxContainer) == "boolean" then
            db.autoUnboxContainer = "none"
        end
        if db.filters.treasureMaps == "only non-base-zone" then
            db.filters.treasureMaps = "always loot"
        end
        if db.filters.trophy == "per ttc" or db.filters.trophy == "per mm" or db.filters.trophy == "per arkadius" or
            db.filters.trophy == "per tsc" then
            db.filters.thirdParty = db.filters.trophy
            db.filters.trophy = "per third"
        end
        if db.filters.recipes == "per ttc" or db.filters.recipes == "per mm" or db.filters.recipes == "per arkadius" or
            db.filters.recipes == "per tsc" then
            db.filters.thirdParty = db.filters.recipes
            db.filters.recipes = "per third"
        end
        if db.filters.furniture == "per ttc" or db.filters.furniture == "per mm" or db.filters.furniture ==
            "per arkadius" or db.filters.furniture == "per tsc" then
            db.filters.thirdParty = db.filters.furniture
            db.filters.furniture = "per third"
        end
        -- if ZO_IsConsoleOrGameCoreUI() and db.unwantedItemsDisposer == "junk" then
        --     db.unwantedItemsDisposer = "none"
        -- end
        -- if (db.filters.treasureMaps == "per mm" and not MasterMerchant) or (db.filters.treasureMaps == "per ttc" and not TamrielTradeCentre) or
        --     (db.filters.treasureMaps == "per arkadius" and not ArkadiusTradeTools) then
        --     db.filters.treasureMaps = "only non-base-zone"
        -- end
        -- if (db.filters.furniture == "per mm" and not MasterMerchant) or (db.filters.furniture == "per ttc" and not TamrielTradeCentre) or
        --     (db.filters.furniture == "per arkadius" and not ArkadiusTradeTools) then
        --     db.filters.furniture = "never loot"
        -- end
        -- if (db.filters.recipes == "per mm" and not MasterMerchant) or (db.filters.recipes == "per ttc" and not TamrielTradeCentre) or
        --     (db.filters.recipes == "per arkadius" and not ArkadiusTradeTools) then
        --     db.filters.recipes = "never loot"
        -- end


        -- migrate removed rare trait options to "always loot"
        if db.filters.rareTrait == "only weapons" or db.filters.rareTrait == "only armors" or db.filters.rareTrait == "only jewelry" then
            db.filters.rareTrait = "always loot"
        end
        if db.destroySafeguard then
            db.destroySafeguard = nil
        end
        if db.destroyUnsaleableJunk ~= nil then
            db.destroyUnsaleableJunk = nil
        end
        if type(db.stolenTreasureThreshold) == "string" then
            db.stolenTreasureThreshold = tonumber(db.stolenTreasureThreshold) or 0
        end
        if type(db.stolenTreasureThreshold) ~= "number" then
            db.stolenTreasureThreshold = 0
        end
        -- Clamp to the qualities offered by the dropdown.
        if db.stolenTreasureThreshold ~= ITEM_DISPLAY_QUALITY_TRASH and
            db.stolenTreasureThreshold ~= ITEM_DISPLAY_QUALITY_MAGIC and
            db.stolenTreasureThreshold ~= ITEM_DISPLAY_QUALITY_ARCANE and
            db.stolenTreasureThreshold ~= ITEM_DISPLAY_QUALITY_ARTIFACT then
            db.stolenTreasureThreshold = 0
        end

        db.latestMinorUpdateVersion = MSAL.addonVersion
    end -- latestMinorUpdateVersion

    -- LAM is okay when an option is not in option arr but LHAS would throw exception, so we need to sanitize these options here.
    -- db.filters.treasureMaps = GetSafeDynamicOption(db.filters.treasureMaps)
    db.filters.furniture = GetSafeDynamicOption(db.filters.furniture, "always loot")
    db.filters.recipes = GetSafeDynamicOption(db.filters.recipes, "always loot")
    db.filters.trophy = GetSafeDynamicOption(db.filters.trophy, "always loot")
    db.filters.styleMaterials3rd = GetSafeDynamicOption(db.filters.styleMaterials3rd, "use default")


    MSAL.Settings.Initialize({
        getDB = function() return db end,
        setDB = function(value) db = value end,
        dbAccount = dbAccount,
        dbChar = dbChar,
        getIsUsingVanillaAutoLoot = function() return isUsingVanillaAutoLoot end,
        setIsUsingVanillaAutoLoot = function(value) isUsingVanillaAutoLoot = value end,
        ChatboxLog = ChatboxLog,
        DebugPrint = DebugPrint,
        ListEntryMatches = ListEntryMatches,
        ReorganizeLootWindowButtons = ReorganizeLootWindowButtons,
        OnInventoryUpdate = OnInventoryUpdate,
        OnLockpickSuccess = OnLockpickSuccess,
        OnLootClosed = OnLootClosed,
        OnOpenFence = OnOpenFence,
        OnOpenLaunder = OnOpenLaunder,
        OnOpenStore = OnOpenStore,
        TSCApi = TSCApi,
        LCK = LCK,
        BLIST_TOKEN = BLIST_TOKEN,
        WLIST_TOKEN = WLIST_TOKEN,
        WLIST_JUNK_TOKEN = WLIST_JUNK_TOKEN,
        MSAL_AUTOLOOT_DISABLE = MSAL_AUTOLOOT_DISABLE,
    })

    if db.hostNativeLootAll == true then
        ZO_KeybindButtonTemplate_Setup(ZO_LootAlphaContainerButton1, "LOOT_ALL", function()
            MSAL.LootAllPlus(self)
        end, GetString(SI_LOOT_TAKE_ALL) .. "+")
    end

    local StartInteraction_orininal = INTERACTIVE_WHEEL_MANAGER.StartInteraction
    INTERACTIVE_WHEEL_MANAGER.StartInteraction = function(self, interactionType, ...)
        if db.stolenRule == "never loot strict" then
            local _, _, _, isOwned = GetGameCameraInteractableActionInfo()
            local stealthState = GetUnitStealthState("player")
            local isHidden = stealthState == STEALTH_STATE_HIDDEN or stealthState == STEALTH_STATE_HIDDEN_ALMOST_DETECTED or
                stealthState == STEALTH_STATE_STEALTH or stealthState == STEALTH_STATE_STEALTH_ALMOST_DETECTED
            if isOwned and not isHidden then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_RESPECRESULT10)
                return true
            end
        end
        return StartInteraction_orininal(self, interactionType, ...)
    end

    SLASH_COMMANDS["/lal"] = function(argString)
        local args = {}
        for word in string.gmatch(argString, "%S+") do
            table.insert(args, word)
        end
        local cmd = #args > 0 and string.lower(args[1])

        if cmd == "toggle" then
            ToggleAddon()
        elseif cmd == "dismiss" then
            db.neverAutolootWarning = true
            ChatboxLog(GetString(MSAL_AUTOLOOT_DISMISSED_FEEDBACK))
        else
            OpenSettingsPanel()
        end
    end

    if GetUnitDisplayName("player") == DecorateDisplayName(MSAL.author) then
        SLASH_COMMANDS['/console'] = function()
            local newVal = ZO_IsConsoleOrGameCoreUI() and "0" or "1"
            SetCVar("ForceConsoleFlow.2", newVal)
        end
        SLASH_COMMANDS["/re"] = function()
            ReloadUI("ingame")
        end
        SLASH_COMMANDS["/test"] = function()
            MSAL.test()
        end
        SLASH_COMMANDS["/lall"] = function()
            if GetCVar("language.2") == "en" then
                SetCVar("language.2", "zh")
            else
                SetCVar("language.2", "en")
            end
        end
    end

--     local currentDate = os.date("*t")
--     if currentDate.month == 4 and currentDate.day == 1 then
--         local impressiveTitle = {}
--         local postFix = GetString(SI_KEYCODE107) .. GetString(SI_KEYCODE107) .. GetString(SI_KEYCODE107) ..
--                             GetString(SI_CRAFTING_COMPONENT_TOOLTIP_UNKNOWN_TRAIT)
--         local impressiveAchievement = {
--             705,
--             1838,
--             2075,
--             2139,
--             2467,
--             2746,
--             3003,
--             3249,
--             3564,
--             4019,
--             4273,
--             2368
--         }
--         table.insert(impressiveTitle, GetString(SI_CAMPAIGN_UNKNOWN_EMPEROR) .. postFix)
--         for i = 1, #impressiveAchievement do
--             local _, titl = GetAchievementRewardTitle(impressiveAchievement[i])
--             table.insert(impressiveTitle, titl .. postFix)
--         end
--         GetUnitTitle = function(unitTag)
--             return impressiveTitle[math.random(1, #impressiveTitle)]
--         end
--     else
        if not ZO_IsConsoleOrGameCoreUI() then
            local GetUnitTitle_original = GetUnitTitle
            GetUnitTitle = function(unitTag)
                if (GetUnitDisplayName(unitTag) == DecorateDisplayName(MSAL.author)) then
                    if GetUnitName(unitTag) == "This One Adores Inigo" then
                        if GetCVar("language.2") == "zh" then
                            return "|c9d1112鲜|r|c8b1011血|r|c790e0f铸|r|c670d0e就|r"
                        else
                            return
                                "|cab1213A|r|ca61112g|r|ca21112e|r|c9d1112d|r |c991011T|r|c941011h|r|c901011r|r|c8b1011o|r|c870f10u|r|c820f10g|r|c7e0f10h|r |c790e0fB|r|c750e0fl|r|c700e0fo|r|c6c0d0eo|r|c670d0ed|r"
                        end
                    elseif GetUnitName(unitTag) == "This One Might Have Wares" then
                        if GetCVar("language.2") == "zh" then
                            return
                                "|c365f88黎|r|c4b677c明|r|c616e6f纪|r|c767562元|r|c8c7c55的|r|ca18449风|r|cb78b3c笛|r|ccc922f手|r"
                        else
                            return
                                "|c275a91P|r|c2e5d8di|r|c365f88p|r|c3d6284e|r|c446480r|r |c4b677ca|r|c526977t|r |c596b73t|r|c616e6fh|r|c68706be|r |c6f7366G|r|c767562a|r|c7d775et|r|c847a5ae|r|c8c7c55s|r |c937f51o|r|c9a814df|r |ca18449D|r|ca88644a|r|caf8840w|r|cb78b3cn|r |cbe8d38E|r|cc59033r|r|ccc922fa|r"
                        end
                    elseif GetUnitName(unitTag) == "This One Smuggles Skooma" then
                        if GetCVar("language.2") == "zh" then
                            return "|c5b33b4与|r|c4d309a死|r|c402e81者|r|c322b67共|r|c25284d舞|r"
                        else
                            return
                                "|c6435c7D|r|c6134c0a|r|c5d34b9n|r|c5933b1c|r|c5532aai|r|c5231a3n|r|c4e319cg|r |c4a3095w|r|c472f8ei|r|c432e86t|r|c3f2d7fh|r |c3b2d78t|r|c382c71h|r|c342b6ae|r |c302a63D|r|c2c2a5be|r|c292954a|r|c25284dd|r"
                        end
                    elseif GetUnitName(unitTag) == "This One Bears With You" then
                        if GetCVar("language.2") == "zh" then
                            return "|cbed768生|r|cd4cb61吞|r|ce9be5b活|r|cffb254剥|r"
                        else
                            return
                                "|cb1de6bE|r|cb9d969a|r|cc2d466t|r|ccbcf64e|r|cd4cb61n|r |cdcc65eA|r|ce5c15cl|r|ceebc59i|r|cf6b757v|r|cffb254e|r"
                        end
                    elseif GetUnitName(unitTag) == "This One Needs Moonsugar" then
                        if GetCVar("language.2") == "zh" then
                            return "|cf3a300吾|r|ce77600心|r|cda4a00之|r|cce1d00形|r"
                        else
                            return
                                "|cfcc200S|r|cf8b600h|r|cf5a900a|r|cf19c00p|r|cee8f00e|r |cea8300o|r|ce77600f|r |ce36900M|r|ce05d00y|r |cdc5000H|r|cd94300e|r|cd53600a|r|cd22a00r|r|cce1d00t|r"
                        end
                    elseif GetUnitName(unitTag) == "This One Steals Nothing" then
                        if GetCVar("language.2") == "zh" then
                            return "|c7ee1ca晶|r|c5ec9b0体|r|c3db196管|r"
                        else
                            return
                                "|c95f2dcT|r|c8bebd4r|r|c82e3cda|r|c78dcc5n|r|c6ed5bds|r|c64ceb5i|r|c5ac7ads|r|c51bfa6t|r|c47b89eo|r|c3db196r|r"
                        end
                    elseif GetUnitName(unitTag) == "This One Tells No Lie" then
                        if GetCVar("language.2") == "zh" then
                            return "|cd7d4a7恶|r|caeab87业|r|c868367长|r|c5d5a47存|r"
                        else
                            return
                                "|cf5f2bfT|r|cebe8b7h|r|ce1deafe|r |cd7d4a7E|r|cccc99fv|r|cc2bf97i|r|cb8b58fl|r |caeab87T|r|ca4a17fh|r|c9a9777a|r|c908d6ft|r |c868367M|r|c7b785fe|r|c716e57n|r |c67644fD|r|c5d5a47o|r"
                        end
                    else
                        if GetCVar("language.2") == "zh" then
                            return "|c3c6646沥|r|c3c6258青|r|c3d5e69世|r|c3d5a7b界|r"
                        else
                            return
                                "|c3b693aA|r|c3b6740s|r|c3c6646p|r|c3c654ch|r|c3c6352a|r|c3c6258l|r|c3c615dt|r |c3c5f63W|r|c3d5e69o|r|c3d5d6fr|r|c3d5b75l|r|c3d5a7bd|r"
                        end
                    end
                elseif (GetUnitDisplayName(unitTag) == "@lsxun" or GetUnitDisplayName(unitTag) == "@Isxun") then
                    if GetCVar("language.2") == "zh" then
                        return "|cdcc9bc喵|cc48241喵|c8b5030喵|c3a3231喵|r"
                    else
                        return "|cdcc9bcMeow |cc48241Meow |c8b5030Meow |c3a3231Meow|r"
                    end
                else
                    return GetUnitTitle_original(unitTag)
                end
            end
        end
--     end
end

function MSAL.ToggleAddon()
    ToggleAddon()
end

function MSAL.OpenSettingPanel()
    OpenSettingsPanel()
end

function MSAL.LootAllPlus(self)
    LootMoney()
    for _, curt in ipairs(curtType) do
        LootCurrency(curt)
    end

    local num = GetNumLootItems()
    local bListSetGearList = {}
    for i = 1, num, 1 do
        local lootId, name, _, _, _, _, _, _, _ = GetLootItemInfo(i)
        local link = GetLootItemLink(lootId)
        -- local isSetItem = IsItemLinkSetCollectionPiece(link)
        if itemOnList(link, BLIST_TOKEN) then
            ChatboxLog(zo_strformat(GetString(MSAL_LOOTING_BLACKLISTED), link))
        else
            LootItemById(lootId)
        end
    end
    EndLooting()
    SCENE_MANAGER:HideCurrentScene()
end

function MSAL.Destroy(self)
    local num = GetNumLootItems()
    EVENT_MANAGER:RegisterForEvent("MSAL_DESTROY_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnDestroyUpdated)
    EVENT_MANAGER:AddFilterForEvent("MSAL_DESTROY_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_IS_NEW_ITEM, true)
    EVENT_MANAGER:AddFilterForEvent("MSAL_DESTROY_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID,
        BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent("MSAL_DESTROY_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    zo_callLater(function()
        EVENT_MANAGER:UnregisterForEvent("MSAL_DESTROY_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end, GetLatency() + 100)

    LootMoney()
    for _, curt in ipairs(curtType) do
        LootCurrency(curt)
    end
    local bListSetGearList = {}
    for i = 1, num, 1 do
        local lootId, name, icon, quantity, quality, value, isQuest, isStolen, lootType = GetLootItemInfo(i)
        local link = GetLootItemLink(lootId)
        local isSetItem = IsItemLinkSetCollectionPiece(link)
        if itemOnList(link, BLIST_TOKEN) and isSetItem then
            table.insert(bListSetGearList, link)
        else
            LootItemById(lootId)
        end
    end
    if #bListSetGearList > 0 then
        EndLooting()
        SCENE_MANAGER:HideCurrentScene()
        ChatboxLog(zo_strformat(GetString(MSAL_LIST_LOOTING_CONFLICT), bListSetGearList[1]))
    end
end

function MSAL.Junking(self)
    local num = GetNumLootItems()
    EVENT_MANAGER:RegisterForEvent("MSAL_JUNKING_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnJunkingUpdated)
    EVENT_MANAGER:AddFilterForEvent("MSAL_JUNKING_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_IS_NEW_ITEM, true)
    EVENT_MANAGER:AddFilterForEvent("MSAL_JUNKING_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID,
        BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent("MSAL_JUNKING_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    zo_callLater(function()
        EVENT_MANAGER:UnregisterForEvent("MSAL_JUNKING_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end, GetLatency() + 100)

    LootMoney()
    for _, curt in ipairs(curtType) do
        LootCurrency(curt)
    end
    local bListSetGearList = {}
    for i = 1, num, 1 do
        local lootId, name, icon, quantity, quality, value, isQuest, isStolen, lootType = GetLootItemInfo(i)
        local link = GetLootItemLink(lootId)
        local isSetItem = IsItemLinkSetCollectionPiece(link)
        if itemOnList(link, BLIST_TOKEN) and isSetItem then
            table.insert(bListSetGearList, link)
        else
            LootItemById(lootId)
        end
    end
    if #bListSetGearList > 0 then
        EndLooting()
        SCENE_MANAGER:HideCurrentScene()
        ChatboxLog(zo_strformat(GetString(MSAL_LIST_LOOTING_CONFLICT), bListSetGearList[1]))
    end
end

function MSAL.UnboxInventoryContainer()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local itemLink = GetItemLink(BAG_BACKPACK, data.slotIndex)
        local isContainer = IsItemLinkContainer(itemLink) and GetItemLinkItemType(itemLink) ~=
                                ITEMTYPE_CONTAINER_CURRENCY
        if isContainer then
            for i = 1, data.stackCount do
                table.insert(unboxingQueue, data.slotIndex)
            end
            MSAL.startInterruptionListener(data.slotIndex)
        end
    end
    SCENE_MANAGER:ShowBaseScene()
    unboxQueuedContainer()
end

function MSAL.UnboxInventoryUnopened()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local itemLink = GetItemLink(BAG_BACKPACK, data.slotIndex)
        local itemLinkType = GetItemLinkItemType(itemLink)
        local isUnopened = itemLinkType == ITEMTYPE_CONTAINER_STACKABLE
        if isUnopened then
            for i = 1, data.stackCount do
                table.insert(unboxingQueue, data.slotIndex)
            end
            MSAL.startInterruptionListener(data.slotIndex)
        end
    end
    SCENE_MANAGER:ShowBaseScene()
    unboxQueuedContainer()
end

function MSAL.UnboxInventoryFish()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local itemLink = GetItemLink(BAG_BACKPACK, data.slotIndex)
        local itemLinkType = GetItemLinkItemType(itemLink)
        local isFish = itemLinkType == ITEMTYPE_FISH
        if isFish then
            for i = 1, data.stackCount do
                table.insert(unboxingQueue, data.slotIndex)
            end
            MSAL.startInterruptionListener(data.slotIndex)
        end
    end
    SCENE_MANAGER:ShowBaseScene()
    unboxQueuedContainer()
end

function MSAL.UnboxInventoryGeode()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local itemLinkType = GetItemLinkItemType(GetItemLink(BAG_BACKPACK, data.slotIndex))
        if itemLinkType == ITEMTYPE_CONTAINER_CURRENCY then
            for i = 1, data.stackCount do
                table.insert(unboxingQueue, data.slotIndex)
            end
            MSAL.startInterruptionListener(data.slotIndex)
        end
    end
    SCENE_MANAGER:ShowBaseScene()
    unboxQueuedContainer()
end

function MSAL.MenuShortcut()
    OpenSettingsPanel()
end

-- Initialize
EVENT_MANAGER:RegisterForEvent("MuchSmarterAutoLoot", EVENT_ADD_ON_LOADED, OnLoaded)

---------------------- My Toolbox ----------------------

-- print all Style Items
-- for i = 1, GetNumValidItemStyles() do
--	local styleItemIndex = GetValidItemStyleId(i)
--	local  itemName = GetItemStyleName(styleItemIndex)
--	local styleItem = GetSmithingStyleItemInfo(styleItemIndex)
--	d("styleItemIndex"..styleItemIndex)
--	d("itemName"..itemName)
--	d("styleItem"..styleItem)
-- end

-- print all Skills
-- 遍历并打印所有技能线及其ID
-- skillType 大分类的技能, 比如职业, 武器, 世界等
-- skillLineIndex 大分类下的各个技能线索引, 比如世界线下的狼人, 吸血鬼
-- skillLineID skillLineIndex的ID (仅用于名称查找, 不要与skillLineIndex的ID相混淆)
-- skillIndex 技能线中某个技能的索引
function MSAL.ListAllSkillLineIDs()

    DebugPrint("Start Listing")
    -- 遍历所有技能类型
    for skillType = 1, GetNumSkillTypes() do
        -- 获取技能线数量
        local numSkillLines = GetNumSkillLines(skillType)

        -- 要看哪个就先查skillLineIndex, 然后在Step 2中手动指定skillType和skillLineIndex
        -- local skillLineIndex = 11
        for skillLineIndex = 1, numSkillLines do
            -- 获取技能线信息
            local skillLineName, _, _, _, _, _, _, _ = GetSkillLineInfo(skillType, skillLineIndex)
            DebugPrint(string.format(
                "SkillType:%s SkillLine index:%s SkillLine id:%s SkillLine name:%s", skillType, skillLineIndex,
                GetSkillLineId(skillType, skillLineIndex),
                GetSkillLineNameById(GetSkillLineId(skillType, skillLineIndex))))
        end
    end
end

-- print all class Skill Lines
function MSAL.ListAllClassSkillLines()
    DebugPrint("Start Listing")
    -- 遍历所有职业技能线
    for classIndex = 1, GetNumClasses() do
        local classId = GetClassInfo(classIndex)
        local className = GetClassName(GetUnitGender("player"), classId)
        DebugPrint(string.format("Class id:%s Class name:%s", classId, className))
        for skillLineIndex = 1, GetNumSkillLinesForClass(classId) do
            local skillLineId = GetSkillLineIdForClass(classId, skillLineIndex)
            local skillLineName = GetSkillLineNameById(skillLineId)
            DebugPrint(string.format("SkillLine index:%s SkillLine id:%s SkillLine name:%s",
                skillLineIndex, skillLineId, skillLineName))
        end
    end
end

function MSAL.ListSkillLinesInType(skillType)
    DebugPrint("Start Listing")
    local numSkillLines = GetNumSkillLines(skillType)

    -- 要看哪个就先查skillLineIndex, 然后在Step 2中手动指定skillType和skillLineIndex
    -- local skillLineIndex = 11
    for skillLineIndex = 1, numSkillLines do
        -- 获取技能线信息
        local skillLineName, _, _, skillLineId, _, _, _, _ = GetSkillLineInfo(skillType, skillLineIndex)
        DebugPrint(string.format("SkillLine index skillLine:%s SkillLine name:%s SkillLine id:%s",
            skillLineIndex, skillLineName, skillLineId))
    end
end

-- 选择并查看具体某个技能线中技能的ID
-- 要看哪个就先查skillLineIndex, 然后手动指定skillType和skillLineIndex
function MSAL.ListSkillsInfoBySkillLineIndex(skillType, skillLineIndex)
    -- local skillType = 1
    -- local skillLineIndex = 7
    local numSkills = GetNumSkillAbilities(skillType, skillLineIndex)
    local skillLineName, _, _, skillLineId, _, _, _, _ = GetSkillLineInfo(skillType, skillLineIndex)
    local outputStr = ""
    outputStr = outputStr ..
                    string.format("\n[%s] = {\n -- %s\n[\"skillLineId\"] = %s,\n", skillLineIndex, skillLineName,
            skillLineId)

    local abilityId, abilityName, CAbilityId

    for skillIndex = 1, numSkills do
        CAbilityId = nil
        if (IsCraftedAbilitySkill(skillType, skillLineIndex, skillIndex)) then
            CAbilityId = GetCraftedAbilitySkillCraftedAbilityId(skillType, skillLineIndex, skillIndex)
            abilityId = GetCraftedAbilityRepresentativeAbilityId(CAbilityId)
            abilityName = GetCraftedAbilityDisplayName(CAbilityId)
        else
            abilityId = GetSkillAbilityId(skillType, skillLineIndex, skillIndex)
            abilityName, _, _, _, _, _, _, _ = GetSkillAbilityInfo(skillType, skillLineIndex, skillIndex)
        end
        local skillMorph1Id, _ = GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, 1, 2)
        local skillMorph2Id, _ = GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, 2, 2)
        local skillLineName = GetSkillLineNameById(skillLineIndex)
        -- GetSlotBoundId(3, HOTBAR_CATEGORY_PRIMARY)遇到篆刻技能时返回的是_craftedAbilityId_而不是_abilityId_. 可能他们都属于actionId?
        if (CAbilityId ~= nil) then
            outputStr = outputStr .. "Crafted Skill ID: " .. CAbilityId
        else
            if skillMorph1Id ~= 0 and skillMorph2Id ~= 0 then
                outputStr = outputStr .. string.format(
                    "[%s] = {[\"skillPool\"] = {\n[0] = {[\"id\"] = %s,},\n[1] = {[\"id\"] = %s,},\n[2] = {[\"id\"] = %s,},\n",
                    skillIndex, abilityId, skillMorph1Id, skillMorph2Id)
            else
                outputStr = outputStr ..
                                string.format("[%s] = {[\"skillPool\"] = {\n[0] = {[\"id\"] = %s,},\n", skillIndex,
                        abilityId)
            end
        end
    end
    DebugPrint(outputStr)
end

function MSAL.GetSkillAbilityInfoSafe(skillType, skillLineIndex, abilityIndex)
    if IsCraftedAbilitySkill(skillType, skillLineIndex, abilityIndex) then
        local craftedAbilityId = GetCraftedAbilitySkillCraftedAbilityId(skillType, skillLineIndex, abilityIndex)
        -- local name = GetCraftedAbilityDisplayName(craftedAbilityId)
        local abilityId = GetAbilityIdForCraftedAbilityId(craftedAbilityId)
        local abilityName = GetAbilityName(abilityId)
        local icon = GetAbilityIcon(abilityId)
        return abilityName, icon, 0, false, false, false, nil, 0, true
    else
        return GetSkillAbilityInfo(skillType, skillLineIndex, abilityIndex), false
    end
end

function MSAL.ListAllCraftedSkillInfo()
    -- 遍历所有技能类型
    for skillType = 1, GetNumSkillTypes() do
        -- 获取技能线数量
        for skillLineIndex = 1, GetNumSkillLines(skillType) do
            -- 获取技能线信息
            local skillLineName, _, _, _, _, _, _, _ = GetSkillLineInfo(skillType, skillLineIndex)
            for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                if (IsCraftedAbilitySkill(skillType, skillLineIndex, skillIndex)) then
                    local CAbilityId = GetCraftedAbilitySkillCraftedAbilityId(skillType, skillLineIndex, skillIndex)
                    local abilityId = GetCraftedAbilityRepresentativeAbilityId(CAbilityId)
                    local abilityName = GetCraftedAbilityDisplayName(CAbilityId)
                    local pri, sec, tri = GetCraftedAbilityActiveScriptIds(CAbilityId)
                    --    DebugPrint("Crafted Ability Id: " .. CAbilityId .. " Ability Id: " .. abilityId .. "\nAbility Name: " .. abilityName .. " Skill Line Name: " .. skillLineName)
                    -- DebugPrint("Crafted Ability Id: " .. CAbilityId .. "Ability Name: " .. abilityName)
                    -- DebugPrint("Icon: " .. GetCraftedAbilityIcon(CAbilityId))
                    DebugPrint(
                        "skillLineName: " .. skillLineName .. "Ability Name: " .. abilityName .. " Ability Id: " ..
                            abilityId)
                    DebugPrint("pri: " .. pri .. " sec: " .. sec .. " pri: " .. tri)

                    -- local _, _, _, isPassive, isUltimate, isPurchased, progressionIndex, _, _ = self:GetSkillAbilityInfoSafe(skillType, skillLineIndex, skillIndex)
                    -- DebugPrint("Ability Name: " .. abilityName .. " isPurchased: " .. tostring(isPurchased) .. " progressionIndex: " .. tostring(progressionIndex))
                end
            end
        end
    end
end

function MSAL.ListAllScripts2()
    local result = {}
    local slotArr = {
        SCRIBING_SLOT_PRIMARY,
        SCRIBING_SLOT_SECONDARY,
        SCRIBING_SLOT_TERTIARY
    }
    local charArr = {
        [SCRIBING_SLOT_PRIMARY] = {},
        [SCRIBING_SLOT_SECONDARY] = {},
        [SCRIBING_SLOT_TERTIARY] = {}
    }
    -- 遍历所有技能类型
    for i, slotType in ipairs(slotArr) do
        for caIndex = 1, GetNumCraftedAbilities() do
            local CAbilityId = GetCraftedAbilityIdAtIndex(caIndex)
            for index = 1, GetNumScriptsInSlotForCraftedAbility(CAbilityId, slotType) do
                local temp = {}
                local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(CAbilityId, slotType, index)
                temp.id = scriptId
                temp.slotType = slotType
                temp.unlocked = IsCraftedAbilityScriptUnlocked(scriptId)
                if not result[scriptId] then
                    result[scriptId] = temp
                end
            end
        end
    end

    --    DebugPrint("slot 1")
    for i, res in ipairs(result) do
        -- if res.slotType == SCRIBING_SLOT_PRIMARY then
        DebugPrint("script id: " .. res.id .. ", script Name: " ..
                                         GetCraftedAbilityScriptDisplayName(res.id) .. ", unlocked: " ..
                                         tostring(res.unlocked))
        -- end
    end

    -- DebugPrint("slot 2")
    -- for i, res in ipairs(result) do
    --     if res.slotType == SCRIBING_SLOT_SECONDARY then
    --        DebugPrint("script id: " .. res.id .. ", script Name: " .. GetCraftedAbilityScriptDisplayName(res.id) .. ", unlocked: " ..
    --               tostring(res.unlocked))
    --     end
    -- end

    -- DebugPrint("slot 3")
    -- for i, res in ipairs(result) do
    --     if res.slotType == SCRIBING_SLOT_TERTIARY then
    --        DebugPrint("script id: " .. res.id .. ", script Name: " .. GetCraftedAbilityScriptDisplayName(res.id) .. ", unlocked: " ..
    --               tostring(res.unlocked))
    --     end
    -- end

    -- for i, slotType in pairs(slotArr) do
    --    DebugPrint("No." .. i .. " slot available scripts info:")
    --     for j, v in result do
    --         for index = 1, GetNumScriptsInSlotForCraftedAbility( craftedAbilityId, slotType) do
    --             local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(craftedAbilityId, slotType, index)
    --            DebugPrint("scriptName: ".. GetCraftedAbilityScriptDisplayName(scriptId)..", scriptId: "..scriptId)
    --            DebugPrint("scriptIcon: "..GetCraftedAbilityScriptIcon(scriptId))
    --         end
    --     end
    -- end

    -- local craftedAbilityId = 1
    -- DebugPrint("Listing "..GetCraftedAbilityDisplayName(craftedAbilityId).." scripts info: ")
    -- local slotArr = {SCRIBING_SLOT_PRIMARY, SCRIBING_SLOT_SECONDARY, SCRIBING_SLOT_TERTIARY}
    -- for i, slotType in pairs(slotArr) do
    --    DebugPrint("No." ..i.. " slot available scripts info:")
    --     for index = 1, GetNumScriptsInSlotForCraftedAbility( craftedAbilityId, slotType) do
    --         local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(craftedAbilityId, slotType, index)
    --        DebugPrint("scriptName: ".. GetCraftedAbilityScriptDisplayName(scriptId)..", scriptId: "..scriptId)
    --        DebugPrint("scriptIcon: "..GetCraftedAbilityScriptIcon(scriptId))
    --     end
    -- end
end

function MSAL.ListAllScripts()
    local result = {} -- This will store all scripts by their ID
    local slotArr = {
        SCRIBING_SLOT_PRIMARY,
        SCRIBING_SLOT_SECONDARY,
        SCRIBING_SLOT_TERTIARY
    }

    -- 遍历所有技能类型
    for i, slotType in ipairs(slotArr) do
        for caIndex = 1, GetNumCraftedAbilities() do
            local CAbilityId = GetCraftedAbilityIdAtIndex(caIndex)
            for index = 1, GetNumScriptsInSlotForCraftedAbility(CAbilityId, slotType) do
                local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(CAbilityId, slotType, index)
                if not result[scriptId] then -- Only add if not already present
                    result[scriptId] = {
                        id = scriptId,
                        slotType = slotType,
                        unlocked = IsCraftedAbilityScriptUnlocked(scriptId)
                    }
                end
            end
        end
    end

    -- To iterate through all results, use pairs instead of ipairs
    for scriptId, scriptData in pairs(result) do
        DebugPrint("script id: " .. scriptId .. ", script Name: " ..
                                         GetCraftedAbilityScriptDisplayName(scriptId) .. ", unlocked: " ..
                                         tostring(scriptData.unlocked))
    end
end

-- print all bag items
function MSAL.ListAllBagItems()
    DebugPrint("Start Listing")
    for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
        local itemLink = GetItemLink(BAG_BACKPACK, bagSlot)
        local itemName = GetItemName(BAG_BACKPACK, bagSlot)
        if string.len(itemName) ~= 0 then
            -- DebugPrint("item Type: " .. GetItemType(BAG_BACKPACK, bagSlot) .. ", slotId: " .. bagSlot .. ", itemLink: " .. itemLink)
            -- let's do some hacking here to get the item type string
            DebugPrint("item Type: " .. GetItemType(BAG_BACKPACK, bagSlot) .. " " ..
                                             GetString(_G["SI_ITEMTYPE" .. GetItemType(BAG_BACKPACK, bagSlot)]) ..
                                             ", slotId: " .. bagSlot .. ", itemLink: " .. itemLink)
        end
    end
end

local function PrintControlNames(control, indent)
    indent = indent or 0
    local controlName = control:GetName()
    local w, h = control:GetDimensions()
    DebugPrint(string.rep("--", indent) .. controlName .. " /  w:" .. math.floor(w) .. " h: " ..
                                     math.floor(h)) -- 打印控件名称

    -- 递归处理子控件
    for i = 1, control:GetNumChildren() do
        local childControl = control:GetChild(i)
        if childControl then
            PrintControlNames(childControl, indent + 1)
        end
    end
end

local base52 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

local function decToBase52WithLeadingZeros(decStr)
    if string.len(decStr) > 16 then
        DebugPrint("decStr longer than 16")
        return nil
    end
    local num = tonumber(decStr)
    if not num then
        return nil
    end
    local result = ""
    while num > 0 do
        local remainder = (num - 1) % 52
        result = base52:sub(remainder + 1, remainder + 1) .. result
        num = math.floor((num - 1) / 52)
    end
    local base52Str = result
    local leadingZeros = decStr:match("^0+")
    if leadingZeros then
        base52Str = leadingZeros .. base52Str
    end
    return base52Str
end

local function base52ToDecWithLeadingZeros(base52Str)
    local leadingZeros = base52Str:match("^0+")
    local base52Part = base52Str:match("^[0]*(.*)")
    local num = 0
    for i = 1, #base52Part do
        local char = base52Part:sub(i, i)
        local value = base52:find(char)
        if not value then
            return nil
        end
        num = num * 52 + value
    end
    local decStr = tostring(num)
    if leadingZeros then
        decStr = leadingZeros .. decStr
    end
    return decStr
end

function MSAL.testBase52()
    local decNumber = "004567891230"
    local base52Number = decToBase52WithLeadingZeros(decNumber)
    DebugPrint("十进制:", decNumber, " 转换为52进制:", base52Number)
    DebugPrint("52进制:", base52Number, " 转换回十进制:",
        base52ToDecWithLeadingZeros(base52Number))
end

local function doZip(former)
    local arr = {}
    local len = 0
    for i = 1, #former - 1, 2 do
        local tmp = string.char(tonumber(former:sub(i, i + 1)))
        len = len + 1
        arr[len] = tmp
    end
    if #former % 2 == 1 then
        len = len + 1
        arr[len] = "-" .. former:sub(#former)
    end
    return table.concat(arr)
end

-- 解压算法，将ASCII码转换成数字，如果字符个数为奇数时，返回最后一位的负数值
local function doUnZip(arr)
    local brr = {}
    local len = 0
    for i = 1, #arr do
        local tmp = string.byte(arr:sub(i, i))
        if tmp < 10 then
            tmp = "0" .. tmp
        end
        len = len + 1
        brr[len] = tostring(tmp)
    end
    local theLast = arr:sub(#arr)
    if #theLast > 1 then
        local tmp = tonumber(theLast)
        tmp = math.abs(tmp)
        len = len + 1
        brr[len] = tostring(tmp)
    else
        local tmp = string.byte(theLast)
        if tmp < 10 then
            tmp = "0" .. tmp
        end
        len = len + 1
        brr[len] = tostring(tmp)
    end
    return table.concat(brr)
end

local function GetAllMapIdsByZoneId(targetZoneIndex)
    local results = {}
    -- assuming there is no more than 10000 mapId I guess ... ?
    local mapIdMax = 10000
    for mapId = 1, mapIdMax do
        local _, _, _, zoneIndex = GetMapInfoById(mapId)
        if zoneIndex == targetZoneIndex then
            table.insert(results, mapId)
        end
    end
    d(results)
    return results
end

function MSAL.IsItemLinkLootedByCurrentRule(itemLink)
    MSAL.ListAllBagItems()
end

local function GetAllMapIdsByZoneId(targetZoneIndex)
    local results = {}
    -- assuming there is no more than 10000 mapId I guess ... ?
    local mapIdMax = 10000
    for mapId = 1, mapIdMax do
        local _, _, _, zoneIndex = GetMapInfoById(mapId)
        if zoneIndex == targetZoneIndex then
            table.insert(results, mapId)
        end
    end
    return results
end

local function printAllZoneId(targetZoneIndex)
    local results = {}
    -- assuming there is no more than 10000 mapId I guess ... ?
    local zoneIndexMax = 100
    for zoneId = 1, zoneIndexMax do
        -- if GetZoneNameById(zoneId) ~= nil then
        --     d("zone name: " .. GetZoneNameById(zoneId) .. ", zoneId: " .. zoneId)
        -- end
        d("zone name: " .. GetZoneNameByIndex(zoneId) .. ", zoneIndex: " .. zoneId .. ", zoneId: " .. GetZoneId(zoneId))
    end
    return results
end

function MSAL.testProcess(itemlinks)
    for _, itemlink in ipairs(itemlinks) do
        local name = LocalizeString("<<1>>", GetItemLinkName(itemlink))

        local itemType, specializedItemType = GetItemLinkItemType(itemlink)
        local quality = GetItemLinkDisplayQuality(itemlink)
        local isStolen = IsItemLinkStolen(itemlink)
        local isQuest = false
        local lootType = 0
        local verdict = nil

        if isStolen and (db.stolenRule == "never loot" or db.stolenRule == "never loot strict") then
            verdict = "blocked by stolen rule (" .. db.stolenRule .. ")"
        elseif isStolen and db.stolenRule == "follow" and not CanLootWithoutBounty(itemlink) then
            verdict = "blocked by stolen rule (follow, would commit crime)"
        elseif itemOnList(itemlink, BLIST_TOKEN) then
            verdict = "blocked by blacklist"
        elseif itemOnList(itemlink, WLIST_JUNK_TOKEN) then
            verdict = "whitelist junk"
        elseif itemOnList(itemlink, WLIST_TOKEN) then
            verdict = "whitelist"
        else
            local filterKey, filterCategory = MSAL.FilterItem(itemlink, isQuest, lootType)
            if filterKey then
                verdict = "filter: " .. filterKey .. " (" .. filterCategory .. ")"
            else
                verdict = "未命中"
            end
        end

        -- d(string.format("[AL+] %s - Type:%d SpecType:%d Quality:%d Stolen:%s -> %s",
        --     name, itemType, specializedItemType, quality, tostring(isStolen), verdict))
        d(string.format("[AL+] %s -> %s",
            name, verdict))
    end
end

function MSAL.test()
    -- local arr = {
    --     "|H1:item:4439:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- low cp raw mat
    --     "|H1:item:46140:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- low cp mat
    --     "|H1:item:64502:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- 160cp mat
    --     "|H0:item:166051:363:50:0:0:0:0:0:0:0:0:0:0:0:2048:5:0:0:0:0:0|h|h", -- master sword
    --     "|H1:item:190905:0:0:0:0:0:0:0:0:0:0:0:0:0:0:140:0:0:0:0:0|h|h", --mora eye
    --     "|H0:item:207093:363:50:0:0:0:0:0:0:0:0:0:0:0:2048:149:0:0:0:0:0|h|h", --perf xoryn axe
    --     "|H0:item:206810:362:50:0:0:0:0:0:0:0:0:0:0:0:2048:0:0:0:0:0:0|h|h", --lucent echo ring
    --     "|H1:item:171503:0:0:0:0:0:0:0:0:0:0:0:0:0:512:0:0:0:0:0:0|h|h", -- nb unknown motif
    --     "|H1:item:157529:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- other char unknown motif
    --     "|H0:item:211583:363:50:0:0:0:0:0:0:0:0:0:0:0:2048:50:0:0:0:0:0|h|h", -- uncollected item set
    -- }
    -- MSAL.testProcess(arr)

    -- d("db.loginReminder: " .. tostring(db.loginReminder) .. ", db.lastStartup: " .. tostring(db.lastStartup) .. ", os.date: " .. os.date("%Y%m%d"))
    --         db.lastStartup = os.date("%Y%m%d")
    --     DebugPrint(GetString(MSAL_PANEL_DISPLAYNAME) .. " |ccc922f" .. MSAL.version ..
    --                                         GetString(MSAL_SPACE) ..
    --                                         GetString(SI_GAMEPAD_MARKET_FREE_TRIAL_TILE_ACTIVE_TEXT) .. "|r")
    --     if db.closeLootWindow then
    --         DebugPrint(chatboxPrefix ..
    --                 GetString(MSAL_CLOSE_LOOT_WINDOW_WARNING))
    --     end
    --     -- if db.autoUnboxUnopened then
    --     --     DebugPrint(chatboxPrefix ..
    --     --         zo_strformat(GetString(MSAL_LOGIN_ENABLED_REMINDER),
    --     --             zo_strformat(GetString(MSAL_AUTO_UNBOX), GetString(SI_ITEMTYPE75))))
    --     -- end
    --     if db.stolenRule == "never loot strict" then
    --         DebugPrint(chatboxPrefix ..
    --             GetString(MSAL_STRICT_STEAL_WARNING))
    --     end
    if db.loginReminder == true then
        db.lastStartup = os.date("%Y%m%d")
        DebugPrint(GetString(MSAL_PANEL_DISPLAYNAME) .. " |ccc922f" .. MSAL.version ..
                                            GetString(MSAL_SPACE) ..
                                            GetString(SI_GAMEPAD_MARKET_FREE_TRIAL_TILE_ACTIVE_TEXT) .. "|r")
        if db.closeLootWindow then
            DebugPrint(chatboxPrefix ..
                    GetString(MSAL_CLOSE_LOOT_WINDOW_WARNING))
        end
        -- if db.autoUnboxUnopened then
        --     DebugPrint(chatboxPrefix ..
        --         zo_strformat(GetString(MSAL_LOGIN_ENABLED_REMINDER),
        --             zo_strformat(GetString(MSAL_AUTO_UNBOX), GetString(SI_ITEMTYPE75))))
        -- end
        if db.stolenRule == "never loot strict" then
            DebugPrint(chatboxPrefix ..
                GetString(MSAL_STRICT_STEAL_WARNING))
        end
    end
end

function MSAL.ListChatWindowChildren()
    PrintControlNames(ZO_IMECandidates_TopLevelPane:GetParent())
end

