local KD = KyzderpsDerps
KD.Quests.Writs = {}
local Writs = KD.Quests.Writs


---------------------------------------------------------------------
local function DisplayWarning(msg)
    local chatWarning = "|cFF0000W" ..
                        "|cFF7F00A" ..
                        "|cFFFF00R" ..
                        "|c00FF00N" ..
                        "|c0000FFI" ..
                        "|c2E2B5FN" ..
                        "|c8B00FFG" ..
                        "|cFF00FF: " .. msg .. "|r"
    CHAT_ROUTER:AddSystemMessage(chatWarning)
end


---------------------------------------------------------------------
-- https://en.uesp.net/wiki/Online:Item_Link#Potion_Effects -- "8th Bit of Byte 3 is 1 if it is a 3 reagent potion" doesn't seem accurate (see ww pots), but regardless we should be able to ignore the 8th bit as stated
-- |H0:item:54339:308:50:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:8454917|h|h -- tristat                       1000 0001 0000 0011 0000 0101
-- |H1:item:54339:308:50:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:65536|h|h -- 1 stat                               0001 0000 0000 0000 0000
-- |H1:item:54339:308:50:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:66843|h|h -- fortitude, endurance, health per sec 0001 0000 0101 0001 1011
-- |H1:item:54339:308:50:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:67337|h|h -- ww pots                              0001 0000 0111 0000 1001
-- |H1:item:54339:308:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:283|h|h -- uesp fortitude, health per sec                    0001 0001 1011
-- |H1:item:44814:308:50:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:461057|h|h -- PTS ww Essence of Spell Protection  0111 0000 1001 0000 0001
-- |H1:item:54339:308:50:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:66816|h|h -- PTS fortitude endurance              0001 0000 0101 0000 0000
local function GetNumEffects(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    if (itemType ~= ITEMTYPE_POTION) then return 0 end
    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, effects = ZO_LinkHandler_ParseLink(itemLink)

    local effect1 = (BitAnd(effects, 0x7F) == 0) and 0 or 1
    local effect2 = (BitAnd(BitRShift(effects, 8), 0x7F) == 0) and 0 or 1
    local effect3 = (BitAnd(BitRShift(effects, 16), 0x7F) == 0) and 0 or 1
    return effect1 + effect2 + effect3
end


---------------------------------------------------------------------
--[[
/script for i = 1, GetNumJournalQuests() do
d(i .. " " .. GetJournalQuestId(i) .. " " .. GetJournalQuestName(i))
end

casts
6101 Essence of Health + Nirnroot

lliram
6102 Drain Health Poison IX + Lorkhan's

PTS:
rykozan 6099 Essence of Stamina + mudcrab
harold another 6103 Damage Stamina Poison IX
solo 6105 Damage Health Poison IX
anothernother 6101 Essence of Health + Nirnroot
]]
local function GetEssenceOfHealthWritJournalIndex()
    for i = 1, GetNumJournalQuests() do
        if (GetJournalQuestId(i) == 6101) then
            return i
        end
    end
end


local function ScanForEssenceOfHealth(callback)
    local journalIndex = GetEssenceOfHealthWritJournalIndex()
    if (not journalIndex) then return end
    local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    for _, item in pairs(bagCache) do
        if (DoesItemFulfillJournalQuestCondition(item.bagId, item.slotIndex, journalIndex, 1, 1)) then
            local itemLink = GetItemLink(item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
            local numEffects = GetNumEffects(itemLink)
            KD:dbg(zo_strformat("<<1>> (bag <<2>> slotIndex <<3>>) fulfills quest and has <<4>> effects", itemLink, item.bagId, item.slotIndex, numEffects))
            if (numEffects >= KD.savedOptions.writs.numEssenceOfHealthEffects) then
                callback(item.bagId, item.slotIndex, numEffects)
            end
        end
    end
end

-- Since we're moving the whole stack, we don't have to mess with the annoying RequestMoveItem
-- somewhat yoinked from esoui/ingame/inventory/inventoryslot.lua
local function MoveItemAndPrint(bagId, slotIndex)
    local bankingBag = GetBankingBag()
    local canAlsoBePlacedInSubscriberBank = bankingBag == BAG_BANK
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    local numInBackpack = GetItemLinkStacks(itemLink)
    if (DoesBagHaveSpaceFor(bankingBag, bagId, slotIndex) or (canAlsoBePlacedInSubscriberBank and DoesBagHaveSpaceFor(BAG_SUBSCRIBER_BANK, bagId, slotIndex))) then
        KD:msg(zo_strformat("Depositing <<1>>x<<2>>", itemLink, numInBackpack))

        if (IsProtectedFunction("PickupInventoryItem")) then
            CallSecureProtected("PickupInventoryItem", bagId, slotIndex)
        else
            PickupInventoryItem(bagId, slotIndex)
        end
        if (IsProtectedFunction("PlaceInTransfer")) then
            CallSecureProtected("PlaceInTransfer")
        else
            PlaceInTransfer()
        end
    else
        KD:msg(zo_strformat("|r|cFF0000Not enough space|r |cAAAAAAin bank for <<1>>x<<2>>", itemLink, numInBackpack))
    end
end

local function OnBankOpened(_, bagId)
    if (bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK) then return end
    ScanForEssenceOfHealth(MoveItemAndPrint)
end

-- Only show chat warning
local function ShowPotionWarning(bagId, slotIndex, numEffects)
    if (not KD.savedOptions.writs.warnEssenceOfHealth) then return end
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    DisplayWarning(zo_strformat("<<1>> (slotIndex <<2>>) fulfills the writ but is a potion that has <<3>> effects<<4>>", itemLink, slotIndex, numEffects,
        KD.savedOptions.writs.depositEssenceOfHealth and "; open the bank to deposit them." or "."))
end


---------------------------------------------------------------------
-- Apprentice master writ
---------------------------------------------------------------------
local function CheckApprentice()
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if (abilityId == 13979) then
            return
        end
    end
    DisplayWarning("You started a master writ quest, but you do not have the Apprentice Mundus!")
end

local XP_BUFFS = {
    [64210] = true, -- Psijic Ambrosia
    [89683] = true, -- Aetherial Ambrosia
    [88445] = true, -- Mythic Aetherial Ambrosia
    [66776] = true, -- Crown Experience Scroll
    [85501] = true, -- Gold Coast Experience Scroll
    [85502] = true, -- Major Gold Coast Experience Scroll
    [85503] = true, -- Grand Gold Coast Experience Scroll
}
local function CheckXPBuff()
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if (XP_BUFFS[abilityId]) then
            return
        end
    end
    DisplayWarning("You started a master writ quest, but you do not have an experience buff active!")
end

local function OnQuestStartedApprentice(_, questJournalIndex)
    if (GetQuestConditionMasterWritInfo(questJournalIndex, 1, 1) ~= nil) then
        CheckApprentice()
        CheckXPBuff()
    end
end


---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function Writs.Initialize()
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "WritsQuestAdded", EVENT_QUEST_ADDED)
    if (KD.savedOptions.writs.warnEssenceOfHealth) then
        EVENT_MANAGER:RegisterForEvent(KD.name .. "WritsQuestAdded", EVENT_QUEST_ADDED, function(_, questJournalIndex, questName)
            local questId = GetJournalQuestId(questJournalIndex)
            if (KD.savedOptions.general.experimental) then
                KD:msg(zo_strformat("<<1>> ID: <<2>> index: <<3>>", questName, questId, questJournalIndex))
            end

            if (questId == 6101) then -- Essence of Health + Nirnroot
                ScanForEssenceOfHealth(ShowPotionWarning)
            end
        end)
    end

    EVENT_MANAGER:UnregisterForEvent(KD.name .. "WritsBankOpened", EVENT_OPEN_BANK)
    if (KD.savedOptions.writs.depositEssenceOfHealth) then
        EVENT_MANAGER:RegisterForEvent(KD.name .. "WritsBankOpened", EVENT_OPEN_BANK, OnBankOpened)
    end

    EVENT_MANAGER:UnregisterForEvent(KD.name .. "WritsApprenticeQuestAdded", EVENT_QUEST_ADDED)
    if (KD.savedOptions.writs.warnMasterWritXP) then
        EVENT_MANAGER:RegisterForEvent(KD.name .. "WritsApprenticeQuestAdded", EVENT_QUEST_ADDED, OnQuestStartedApprentice)
    end
end
