KyzderpsDerps = KyzderpsDerps or {}
KyzderpsDerps.Loot = KyzderpsDerps.Loot or {}
local Loot = KyzderpsDerps.Loot
Loot.name = KyzderpsDerps.name .. "Loot"

---------------------------------------------------------------------
-- Port to a group member in a dungeon or trial, then PTE
-- As a fallback, port to an unowned house
---------------------------------------------------------------------
local looted = 0
local usedSurvey = false
local hasMoreSurveys = true

local function ExitInstanceAfterActivated()
    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "RefreshSurvey", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(ExitInstanceImmediately, 500) -- Small delay so it doesn't seem like a freeze? Have experienced a bit of weirdness
    end, true) -- do once
end

local function RefreshSurvey()
    looted = 0
    usedSurvey = false
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        local name = GetUnitDisplayName(unitTag)
        if (IsUnitOnline(unitTag) and name ~= playerName) then
            local zoneId = GetZoneId(GetUnitZoneIndex(unitTag))
            if (KyzderpsDerps.TRIAL_ZONEIDS[tostring(zoneId)] or KyzderpsDerps.DUNGEON_ZONEIDS[tostring(zoneId)]) then
                KyzderpsDerps:msg(zo_strformat("Porting to <<1>> in <<2>> (<<3>>) and then exiting instance immediately...",
                    name, GetZoneNameById(zoneId), zoneId))
                JumpToGroupMember(name)

                ExitInstanceAfterActivated()
                return
            end
        end
    end


    for i = 1, 200 do
        local collectibleId = GetCollectibleIdForHouse(i)
        if (collectibleId ~= 0) then
            if (GetAPIVersion() >= 101052) then -- U52 exit instance works for both owned and unowned
                RequestJumpToHouse(i)
                ExitInstanceAfterActivated()
                KyzderpsDerps:msg("Porting to house " .. GetCollectibleLink(collectibleId, LINK_STYLE_BRACKETS) .. " and then exiting instance immediately...")
                return
            elseif (not IsCollectibleUnlocked(collectibleId)) then -- prior to U52 manual exit needs unowned house
                RequestJumpToHouse(i)
                KyzderpsDerps:msg("Couldn't find a group member in a dungeon or trial; porting to unowned house " .. GetCollectibleLink(collectibleId, LINK_STYLE_BRACKETS))
                return
            end
        end
    end

    KyzderpsDerps:msg("You own all the houses?? Or something's broken, yell at Kyzer.")
end
Loot.RefreshSurvey = RefreshSurvey


---------------------------------------------------------------------
-- Listen for inventory changes in order to hopefully refresh survey
-- when the last node is looted
---------------------------------------------------------------------
local function SurveyTimeout()
    EVENT_MANAGER:UnregisterForUpdate(Loot.name .. "SurveyTimeout")

    KyzderpsDerps:dbg("Cancelling usedSurvey because too much time passed")
    looted = 0
    usedSurvey = false
end

local function LootTimeout()
    EVENT_MANAGER:UnregisterForUpdate(Loot.name .. "LootTimeout")
    looted = looted + 1
    KyzderpsDerps:dbg("Incrementing looted: " .. tostring(looted))

    if (looted == 6) then
        looted = 0
        usedSurvey = false
        EVENT_MANAGER:UnregisterForUpdate(Loot.name .. "SurveyTimeout")
        RefreshSurvey()
    end
end

local function OnInventorySlotUpdate(_, bagId, slotIndex, isNewItem, _, inventoryUpdateReason, stackCountChange)
    if (stackCountChange < 0 and bagId == BAG_BACKPACK) then
        local _, specializedItemType = GetItemType(bagId, slotIndex)
        if (specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT) then
            KyzderpsDerps:dbg("Consumed a survey")
            usedSurvey = true
            KyzderpsDerps:dbg("Remaining " .. tostring(GetSlotStackSize(bagId, slotIndex)))
            EVENT_MANAGER:RegisterForUpdate(Loot.name .. "SurveyTimeout", 2000, SurveyTimeout) -- The initial one should be fast
        end
    -- Yoinked from esoui/ingame/zo_loot/loothistory_manager.lua
    -- This includes any inventory item update, only display if the item was new
    elseif (isNewItem and stackCountChange > 0 and usedSurvey) then
        local itemLink = GetItemLink(bagId, slotIndex)
        local mainFilter, secondaryFilter = GetItemLinkFilterTypeInfo(itemLink)
        if (mainFilter == ITEMFILTERTYPE_CRAFTING or secondaryFilter == ITEMFILTERTYPE_CRAFTING) then
            EVENT_MANAGER:RegisterForUpdate(Loot.name .. "LootTimeout", 200, LootTimeout)
            EVENT_MANAGER:RegisterForUpdate(Loot.name .. "SurveyTimeout", 10000, SurveyTimeout)
        end
    end
end


---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function Loot.InitializeSurvey()
    if (KyzderpsDerps.savedOptions.misc.autoRefreshSurvey) then
        EVENT_MANAGER:RegisterForEvent(Loot.name .. "InventoryUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    end
end

local function UninitializeSurvey()
    EVENT_MANAGER:UnregisterForEvent(Loot.name .. "InventoryUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end


---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
function Loot.GetSettings()
    return {
        type = "checkbox",
        name = "Automatically |c99FF99/refreshsurvey|r",
        tooltip = "When you loot materials for the 6th time after consuming a survey report, automatically run |c99FF99/refreshsurvey|r. This command can also be used manually. If you are in a group with someone who is in a dungeon or trial, you will port to the player and then immediately leave the instance, which will refresh the survey nodes. If there is no port available, you will preview a house you do not own, and then you need to manually leave the home.\n\nDisclaimer: it may try to leave early if you happen to loot materials other than the 6 survey nodes. In that case, you will have to cancel the port and run it manually later. It will also stop counting nodes if you take more than 2 seconds after consuming the survey, or more than 10 seconds between nodes. So put on Master Gatherer!",
        default = false,
        getFunc = function() return KyzderpsDerps.savedOptions.misc.autoRefreshSurvey end,
        setFunc = function(value)
            KyzderpsDerps.savedOptions.misc.autoRefreshSurvey = value
            UninitializeSurvey()
            Loot.InitializeSurvey()
        end,
        width = "full",
    }
end
