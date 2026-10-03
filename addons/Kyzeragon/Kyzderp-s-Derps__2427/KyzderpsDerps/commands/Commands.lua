local KD = KyzderpsDerps


---------------------------------------------------------------------
local function StartsWith(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end


---------------------------------------------------------------------
-- Commands
local function HandleKDDCommand(argString)
    local args = {}
    local length = 0
    for word in argString:gmatch("%S+") do
        table.insert(args, word)
        length = length + 1
    end

    local usage = "Usage: /kdd <settings || grievous || bosstimer || played || playedall || points || totalpoints || armory || junkstyle || hidelogout || normlogout || questtracker || openall || writhing || resetcraft || pocket || multi || flex>"

    if (length == 0) then
        CHAT_ROUTER:AddSystemMessage(usage)
        return
    end

    KD:dbg(args)

    -- Toggle grievous retaliation overlay
    if (args[1] == "grievous") then
        GrievousRetaliation:SetHidden(not GrievousRetaliation:IsHidden())

    elseif (args[1] == "settings") then
        LibAddonMenu2:OpenToPanel(KyzderpsDerpsOptions)

    -- toggle bosstimer
    elseif (args[1] == "bosstimer") then
        KD.savedOptions.spawnTimer.enable = not KD.savedOptions.spawnTimer.enable
        SpawnTimerContainer:SetHidden(not SpawnTimerContainer:IsHidden())
        if (WINDOW_MANAGER:GetControlByName("KyzderpsDerps#SpawnTimerEnable")) then
            WINDOW_MANAGER:GetControlByName("KyzderpsDerps#SpawnTimerEnable"):UpdateValue()
        end

    -- played
    elseif (args[1] == "played") then
        local played = KD.Altoholic.BuildPlayed()
        CHAT_ROUTER:AddSystemMessage(played)

    -- playedall
    elseif (args[1] == "playedall") then
        CHAT_ROUTER:AddSystemMessage(KD.Altoholic.BuildPlayedAll())

    -- points
    elseif (args[1] == "points") then
        CHAT_ROUTER:AddSystemMessage(KD.Altoholic.BuildPoints())

    -- totalpoints
    elseif (args[1] == "totalpoints") then
        CHAT_ROUTER:AddSystemMessage(KD.Altoholic.BuildTotalPoints())

    -- armory
    elseif (args[1] == "armory") then
        CHAT_ROUTER:AddSystemMessage(KD.Altoholic.BuildArmory())

    -- junk style pages
    elseif (args[1] == "junkstyle" or args[1] == "junkstyles") then
        local junkedItems = {}
        local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
        for _, item in pairs(bagCache) do
            -- Skip items that are already junk, obviously
            if (not IsItemJunk(item.bagId, item.slotIndex)) then
                local itemLink = GetItemLink(item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
                local itemType, specializedType = GetItemLinkItemType(itemLink)
                if (itemType == ITEMTYPE_CONTAINER and specializedType == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE) then
                    SetItemIsJunk(item.bagId, item.slotIndex, true)
                    if (not junkedItems[itemLink]) then
                        junkedItems[itemLink] = 0
                    end
                    junkedItems[itemLink] = junkedItems[itemLink] + 1
                end
            end
        end

        local displayMessage = "Marked the following items as junk:"
        for itemLink, num in pairs(junkedItems) do
            displayMessage = string.format("%s\n|cDDDDDD%s x%d", displayMessage, itemLink, num)
        end
        KD:msg(displayMessage)

    -- resetchests
    elseif (args[1] == "resetchests") then
        KD.ChatSpam.ResetCounter()

    -- List furnishings in a home with a filter, undocumented because could be... controversial
    elseif (args[1] == "furn") then
        if (length ~= 2) then
            CHAT_ROUTER:AddSystemMessage("Usage: /kdd furn <itemnamefilter>")
            return
        end

        KD:msg("Furnishings in this house matching \"" .. args[2] .. "\":")
        local furnitureId = nil
        local itemId = nil
        repeat
            furnitureId = GetNextPlacedHousingFurnitureId(furnitureId)
            if furnitureId ~= nil then
                local link = GetPlacedFurnitureLink(furnitureId, LINK_STYLE_BRACKETS)
                if (string.find(string.lower(GetItemLinkName(link)), string.lower(args[2]))) then
                    CHAT_ROUTER:AddSystemMessage(link)
                end
            end
        until furnitureId == nil

    -- toggles hiding on logout
    elseif (args[1] == "hide") then
        KD.savedOptions.misc.hideOnLogout = not KD.savedOptions.misc.hideOnLogout
        KD:msg(string.format("Hiding upon logout is now set to %s", tostring(KD.savedOptions.misc.hideOnLogout)))

    -- logs out without loading few addons
    elseif (args[1] == "normlogout") then
        KD.PreLogout.doNotLoadOverride = true
        KD:msg("Logging out without loading few addons...")
        Logout()

    -- toggles the quest tracker panel
    elseif (args[1] == "questtracker") then
        ZO_FocusedQuestTrackerPanel:SetHidden(not ZO_FocusedQuestTrackerPanel:IsHidden())

    -- re-scans and opens containers
    elseif (args[1] == "openall") then
        KD.Opener.OpenAllInBackpack()

    -- opens writhing wall event crafting boxes
    elseif (args[1] == "writhing") then
        KD.Opener.OpenAllWrithingCrafting()

    -- janky manual reset for priority craft reroll
    elseif (args[1] == "resetcraft") then
        KD.Quests.Chatter.ResetPriority()

    -- i am forgerful
    elseif (args[1] == "kyzerg") then
        KD.Sync.Kyzerg.PrintCommands()

    -- attach jogroup frame to the unit (for pocket healing!)
    elseif (args[1] == "pocket") then
        if (length ~= 2) then
            KD:msg("Usage: /kdd pocket <@name> | /kdd pocket clear ")
            return
        end
        if (args[2] == "clear") then
            KD.JoGroup.ClearPockets()
        else
            KD.JoGroup.Pocket(args[2])
        end

    -- Equip multi rider mount
    elseif (args[1] == "multi") then
        local multiMounts = {
            13808, -- Warparty Timber Mammoth
            13897, -- Duo-Dynamo Dungeon Delver Spider
            6972, -- Duo-Dynamo Dwarven Spider
            13552, -- Duo-Dynamo Hollowsteel Spider
            11887, -- Nightmare Pillion Courser
            10254, -- Wayrest Vanner Pillion Steed
            12662, -- Black Fredas Pillion Walker
            11959, -- Dark Brotherhood Crew Steed
            8512, -- Duo-Dynamo Argent Spider
            8379, -- Duo-Dynamo Burnished Spider
            9576, -- Grand Pillion Draft Horse
            13504, -- Grimshadow Pillion Moose
            10708, -- Hew's Bane Pillion Palfrey
            10586, -- Mara's Pledge Mare
            11643, -- Seaghost Pillion Moose
            10384, -- Skingrad Pillion Courser
            12661, -- Spiritwalker Pillion Elk
        }

        for _, id in ipairs(multiMounts) do
            if (IsCollectibleUnlocked(id) and not IsCollectibleActive(id, GAMEPLAY_ACTOR_CATEGORY_PLAYER)) then
                KD:msg(string.format("Equipping %s (%d)", GetCollectibleName(id), id))
                UseCollectible(id)
                return
            end
        end
        KD:msg("No multi-rider mounts available (or data hasn't been added, yell at Kyzer?)")

    -- Equip trifecta mount
    elseif(args[1] == "flex") then
        local triMounts = {
            6466, -- Sunspire Champion Senche-Lion
            9062, -- Sul-Xan Fleshripper
            10242, -- Stormsurge Howler
            10919, -- Ram of Dark Dreams
            12257, -- Refulgent Mirrormoor Steed
            12979, -- Heart's Grief Welwa
        }

        local available = {}
        for _, id in ipairs(triMounts) do
            if (IsCollectibleUnlocked(id) and not IsCollectibleActive(id, GAMEPLAY_ACTOR_CATEGORY_PLAYER)) then
                table.insert(available, id)
            end
        end

        if (#available == 0) then
            KD:msg("No trifecta mounts available to flex, or it is already equipped.")
            return
        end

        local chosen = available[math.random(1, #available)]
        UseCollectible(chosen)
        KD:msg(string.format("Flexing |H1:collectible:%d|h|h...", chosen))

    -- Unknown
    else
        CHAT_ROUTER:AddSystemMessage(usage)
    end
end

local function FixUI()
    if (MajorCourageTracker) then
        MajorCourageTracker.Reset()
    end
    if (PurgeTracker) then
        PurgeTracker.Reset()
    end
    if (HealerBFF) then
        HealerBFF.Reset()
    end
    if (JoGroup) then
        JoGroup.ReAnchor()
    end
    if (btg) then
        btg.CheckActivation()
    end
end

local function ToggleLuiIds()
    if (not LUIE or not LUIE.SpellCastBuffs) then
        KD:msg("LUI SpellCastBuffs is not enabled")
        return
    end
    LUIE.SpellCastBuffs.SV.ShowDebugAbilityId = not LUIE.SpellCastBuffs.SV.ShowDebugAbilityId
    LUIE.SpellCastBuffs.Reset()
    KD:msg("Toggled showing IDs on LUI buffs/debuffs")
end


---------------------------------------------------------------------
local function StartsWith(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

---------------------------------------------------------------------
function KD.InitializeCommands()
    SLASH_COMMANDS["/kdd"] = HandleKDDCommand
    SLASH_COMMANDS["/fixui"] = FixUI
    SLASH_COMMANDS["/ids"] = ToggleLuiIds

    -- Porting to player
    SLASH_COMMANDS["/wayshrine"] = KD.PortWayshrine
    SLASH_COMMANDS["/currentshrine"] = KD.PortCurrentShrine
    SLASH_COMMANDS["/guessshrine"] = KD.GuessPortZoneFromQuest
    SLASH_COMMANDS["/ktp"] = KD.PortToAny
    SLASH_COMMANDS["/ktpp"] = function(argString)
        if (argString == "") then
            KD:msg("Usage: /ktpp <@name>")
            KD:msg("Note: You can now use /ktp to port to both players in zones and specific players, but /ktpp will only search for specific player.")
            return
        end
        if (not StartsWith(argString, "@")) then
            argString = "@" .. argString
        end
        KD.PortToAny(argString)
    end

    SLASH_COMMANDS["/refreshsurvey"] = KD.Loot.RefreshSurvey
end
