local AH = _G.EASArchiveHelper

local positions = { [1] = {}, [2] = {}, [3] = {} }

local function getNextPosition(buffIndex)
    if (ZO_IsElementInNumericallyIndexedTable(positions[buffIndex], 1)) then
        table.insert(positions[buffIndex], 2)
        return 2
    end

    if (ZO_IsElementInNumericallyIndexedTable(positions[buffIndex], 2)) then
        table.insert(positions[buffIndex], 3)
        return 3
    end

    table.insert(positions[buffIndex], 1)
    return 1
end

local function clearPositions()
    for index = 1, 3 do
        ZO_ClearNumericallyIndexedTable(positions[index])
    end
end

function AH.OnBuffSelectorShowing()
    if (AH.Vars.PreventSelection) then
        _G[AH.SELECTOR_OBJECT].keybindStripDescriptor.enabled = false
    end

    local numChoices = 0
    local buffChoices = {}
    local container = AH.SELECTOR_SHORT .. "Container"
    local positionOffsets = {
        [1] = { x = 84, y = -36 },
        [2] = { x = 0, y = -36 },
        [3] = { x = 164, y = -36 }
    }

    clearPositions()

    -- reset the object pool
    AH.EnsureIconPoolExists()
    AH.IconObjectPool:ReleaseAllObjects()

    for bucketType = ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_BEGIN, ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_END do
        local abilityId = GetEndlessDungeonBuffSelectorBucketTypeChoice(bucketType)

        if abilityId > 0 then
            numChoices = numChoices + 1

            local buffType, isAvatarVision = GetAbilityEndlessDungeonBuffType(abilityId)
            buffChoices[numChoices] = {
                abilityId = abilityId,
                buffType = buffType,
                isAvatarVision = isAvatarVision,
                index = numChoices,
                name = AH.LC.Format(GetAbilityName(abilityId, "player"))
            }
        end
    end

    -- show achievement icons
    if (AH.Vars.MarkAchievements) then
        for _, buffInfo in pairs(buffChoices) do
            local generalIds = AH.GetAbilityNeededForGeneralAchievement(buffInfo.abilityId)
            local record = AH.GetRecord(buffInfo.abilityId, AH.MissingAbilities)

            if (record or (#generalIds > 0)) then
                local position = positionOffsets[getNextPosition(buffInfo.index)]
                local buff = _G[string.format("%sBuff%d", container, buffInfo.index)]
                local icon = AH.CreateIcon("ACH", buff, position.x, position.y)

                local ttt = " "

                if (record) then
                    local achName = GetAchievementName(record.achievementId)

                    ttt = ttt .. achName .. AH.LF
                end

                if (#generalIds > 0) then
                    for _, achievementId in ipairs(generalIds) do
                        local name = GetAchievementName(achievementId)

                        ttt = ttt .. name .. AH.LF
                    end
                end

                -- remove the trailing line feed
                ttt = ttt:sub(1, #ttt - 1)

                icon:SetTooltip(ttt)
                icon:SetHidden(false)
            end
        end
    end

    -- show favourite/ignore icons
    if (AH.Vars.MarkFavourites and #AH.Vars.Favourites > 0) then
        for _, buffInfo in pairs(buffChoices) do
            local iconName

            -- favourites
            if (ZO_IsElementInNumericallyIndexedTable(AH.Vars.Favourites, buffInfo.abilityId)) then
                iconName = "FAV"
            end

            -- ignore
            if (ZO_IsElementInNumericallyIndexedTable(AH.Vars.Ignore, buffInfo.abilityId)) then
                iconName = "AVOID"
            end

            -- auto ignore
            if (not AH.HasSkills(buffInfo.abilityId)) then
                iconName = "AVOID"
            end

            if (iconName) then
                local position = positionOffsets[getNextPosition(buffInfo.index)]
                local buff = _G[string.format("%sBuff%d", container, buffInfo.index)]
                local icon = AH.CreateIcon(iconName, buff, position.x, position.y)

                icon:SetHidden(false)
            end
        end
    end

    -- show avatar icons
    if (AH.Vars.MarkAvatar) then
        for _, buffInfo in pairs(buffChoices) do
            local position = positionOffsets[getNextPosition(buffInfo.index)]
            local buff = _G[string.format("%sBuff%d", container, buffInfo.index)]
            local icon, achievementId
            local avatar = AH.IsAvatar(buffInfo.abilityId)

            if (avatar) then
                icon = AH.CreateIcon(avatar, buff, position.x, position.y)
                achievementId = AH.AVATAR[avatar].id
            end

            if (icon) then
                local ttt = ""
                local name = GetAchievementName(achievementId)

                ttt = ttt .. name

                icon:SetHidden(false)
                icon:SetTooltip(ttt)
            end
        end
    end

    -- show stack counts
    if (AH.Vars.ShowStacks) then
        if (buffChoices[1].buffType == ENDLESS_DUNGEON_BUFF_TYPE_VISION) then
            local counts = ENDLESS_DUNGEON_MANAGER:GetAbilityStackCountTable(buffChoices[1].buffType)

            for _, buffInfo in pairs(buffChoices) do
                local buff = _G[string.format("%sBuff%dName", container, buffInfo.index)]
                if buff then
                    -- Re-roll/stack refreshes can rebuild this decoration more
                    -- than once while the selector remains open. Reset the native
                    -- name first so stack text never duplicates itself.
                    buff:SetText(buffInfo.name or "")
                end
                local count = counts[buffInfo.abilityId] or 0
                local avatar = AH.IsAvatar(buffInfo.abilityId)
                local countText = ""

                if (avatar) then
                    count = AH.Vars.AvatarVisionCount[avatar] or 0
                    countText = ZO_CachedStrFormat(_G.ARCHIVEHELPER_COUNT, count, 3)
                end

                if (count > 0) then
                    if (countText == "") then
                        countText = tostring(count)
                    end

                    countText = AH.LC.Yellow:Colorize(countText)

                    if buff then buff:SetText(buff:GetText() .. AH.LF .. " (" .. countText .. ")") end
                end
            end
        end
    end

    if (AH.Vars.PreventSelection) then
        zo_callLater(
            function()
                _G[AH.SELECTOR_OBJECT].keybindStripDescriptor.enabled = true
            end,
            AH.SELECTION_DELAY
        )
    end
end
