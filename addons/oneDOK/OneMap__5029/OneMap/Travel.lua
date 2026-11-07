local A = OneMap

function A:CancelPendingTravel()
    self.pendingQuest = nil
    EVENT_MANAGER:UnregisterForUpdate("OneMapQuestWait")
end

function A:CanTravel()
    return self:CanUseMap() and not IsUnitInCombat("player") and not IsUnitDead("player")
        and CanLeaveCurrentLocationViaTeleport()
end

function A:FindFreePlayer(zoneId, groupOnly)
    if not self.saved.freeTravel or not zoneId or zoneId <= 0 then return nil end
    local playerName = GetDisplayName()
    if self.saved.useGroup then
        for index = 1, GetGroupSize() do
            local unitTag = GetGroupUnitTagByIndex(index)
            local memberZone = unitTag and GetUnitWorldPosition(unitTag)
            if unitTag and not AreUnitsEqual(unitTag, "player") and IsUnitOnline(unitTag)
                and memberZone == zoneId and CanJumpToGroupMember(unitTag) then
                return { source = "group", name = GetUnitDisplayName(unitTag), zoneId = zoneId }
            end
        end
    end
    if groupOnly then return nil end
    if not CanJumpToPlayerInZone(zoneId) then return nil end
    if self.saved.useFriends then
        for index = 1, GetNumFriends() do
            local name, _, status = GetFriendInfo(index)
            local hasCharacter, _, _, _, _, _, _, memberZone = GetFriendCharacterInfo(index)
            if hasCharacter and status ~= PLAYER_STATUS_OFFLINE and name ~= playerName and memberZone == zoneId then
                return { source = "friend", name = name, zoneId = zoneId }
            end
        end
    end
    if self.saved.useGuilds then
        for guildIndex = 1, GetNumGuilds() do
            local guildId = GetGuildId(guildIndex)
            for memberIndex = 1, GetNumGuildMembers(guildId) do
                local name, _, _, status = GetGuildMemberInfo(guildId, memberIndex)
                local hasCharacter, _, _, _, _, _, _, memberZone = GetGuildMemberCharacterInfo(guildId, memberIndex)
                if hasCharacter and status ~= PLAYER_STATUS_OFFLINE and name ~= playerName and memberZone == zoneId then
                    return { source = "guild", name = name, zoneId = zoneId }
                end
            end
        end
    end
end

function A:PlanTravel(destination)
    if not destination or not self:CanTravel() then return { reason = "restricted" } end
    if destination.kind == "house" then
        if not CanJumpToHouseFromCurrentLocation() then return { reason = "restricted" } end
        return { kind = "house", houseId = destination.houseId, cost = 0, destination = destination }
    end
    local isInstance = destination.kind == "dungeon" or destination.kind == "trial"
    local targetZone = isInstance and self:GetInstanceZone(destination) or destination.zoneId
    local player = self:FindFreePlayer(targetZone, isInstance)
    if player then return { kind = "player", player = player, cost = 0, destination = destination } end
    local nodeIndex = destination.nodeIndex or self:SelectWayshrine(destination)
    if not nodeIndex or not self:IsUsableNode(nodeIndex) then return { reason = "noShrine" } end
    local currentNode = ZO_Map_GetFastTravelNode()
    if currentNode == nodeIndex then return { reason = "unavailable" } end
    local cost, currency = 0, GetRecallCurrency(nodeIndex)
    if not currentNode then
        if IsInCampaign() then return { reason = "restricted" } end
        local _, cooldown = GetRecallCooldown()
        if cooldown > 0 then return { reason = "cooldown" } end
        cost = GetRecallCost(nodeIndex)
        if cost > GetCurrencyAmount(currency, CURRENCY_LOCATION_CHARACTER) then return { reason = "noGold", cost = cost, currency = currency } end
    end
    return { kind = "node", nodeIndex = nodeIndex, cost = cost, currency = currency,
        fromWayshrine = currentNode ~= nil, destination = destination }
end

function A:Travel(destination)
    self:CancelPendingTravel()
    local plan = self:PlanTravel(destination)
    if plan.reason then self:Alert(plan.reason); return false end
    if plan.kind == "player" then
        if plan.player.source == "group" then JumpToGroupMember(plan.player.name)
        elseif plan.player.source == "friend" then JumpToFriend(plan.player.name)
        else JumpToGuildMember(plan.player.name) end
    elseif plan.kind == "house" then
        if self.saved.skipPaidConfirmation then
            RequestJumpToHouse(plan.houseId, false)
            SCENE_MANAGER:ShowBaseScene()
        else
            ZO_Dialogs_ShowPlatformDialog("TRAVEL_TO_HOUSE_CONFIRM",
                { houseId = plan.houseId, travelOutside = false }, { mainTextParams = { destination.name } })
        end
    elseif self.saved.skipPaidConfirmation then
        FastTravelToNode(plan.nodeIndex)
        SCENE_MANAGER:ShowBaseScene()
    else
        -- Let the stock dialogs handle confirmation, last-moment affordability,
        -- cooldowns and restrictions. Never silently charge after a failed jump.
        ZO_Dialogs_ShowPlatformDialog(plan.fromWayshrine and "FAST_TRAVEL_CONFIRM" or "RECALL_CONFIRM",
            { nodeIndex = plan.nodeIndex }, { mainTextParams = { select(2, GetFastTravelNodeInfo(plan.nodeIndex)) } })
    end
    return true
end

function A:InitializeTravel()
    -- Also cover the stock map's travel dialogs; unrelated confirmations remain
    -- entirely native. Use the same requests as each dialog's Confirm button.
    ZO_PreHook("ZO_Dialogs_ShowPlatformDialog", function(name, data)
        if not self.saved.skipPaidConfirmation or not data then return end
        if (name == "RECALL_CONFIRM" or name == "FAST_TRAVEL_CONFIRM") and data.nodeIndex then
            FastTravelToNode(data.nodeIndex)
        elseif name == "TRAVEL_TO_HOUSE_CONFIRM" and data.houseId then
            RequestJumpToHouse(data.houseId, data.travelOutside == true)
        else return end
        SCENE_MANAGER:ShowBaseScene()
        return true
    end)
end

function A:PriceText(destination)
    -- Short-lived, destination-specific quotes avoid scanning every guild roster
    -- every rendered frame. Clicking always creates a fresh plan.
    local key = destination and table.concat({ destination.kind, destination.zoneId or 0,
        destination.nodeIndex or 0, destination.questIndex or 0, destination.antiquityId or 0 }, ":")
    local now = GetFrameTimeMilliseconds()
    if self.quote and self.quote.key == key and now - self.quote.time < 1000 then return self.quote.text end
    local quoteDestination = {}
    for field, value in pairs(destination or {}) do quoteDestination[field] = value end
    quoteDestination.antiquityId = nil -- Quoting must never change the native map/filter context.
    local plan = self:PlanTravel(quoteDestination)
    local label
    if plan.cost and plan.cost > 0 then
        label = ZO_Currency_FormatKeyboard(plan.currency, plan.cost, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
    elseif not plan.reason then label = self:Text("free")
    else label = self:Text("unavailable") end
    local result = plan.reason and self:Text("unavailable") or string.format(self:Text("price"), label)
    self.quote = { key = key, time = now, text = result }
    return result
end

function A:CacheQuestPoints(questIndex)
    local destination = self:QuestDestination(questIndex)
    if not destination or GetZoneId(GetCurrentMapZoneIndex()) ~= destination.zoneId then return end
    self.questPointCache = self.questPointCache or {}
    self.questPointCache[questIndex] = { mapId = GetCurrentMapId(), points = self:QuestPoints(questIndex) }
    self.quote = nil
    local pending = self.pendingQuest
    if pending and pending.questIndex == questIndex and pending.mapId == GetCurrentMapId()
        and pending.questId == GetJournalQuestId(questIndex) then
        self.pendingQuest = nil
        EVENT_MANAGER:UnregisterForUpdate("OneMapQuestWait")
        self:Travel(destination)
    end
end

function A:TravelToQuest(questIndex)
    self:CancelPendingTravel()
    local destination = self:QuestDestination(questIndex)
    if not destination then self:Alert("noLocation"); return end
    if not self:CanTravel() then self:Alert("restricted"); return end
    -- A free jump does not need quest coordinates and always has priority.
    if self:FindFreePlayer(destination.zoneId, false) then self:Travel(destination); return end
    self.pendingQuest = { questIndex = questIndex, questId = GetJournalQuestId(questIndex),
        mapId = GetMapIdByZoneId(destination.zoneId) }
    if not self:ShowZone(destination.zoneId) then self.pendingQuest = nil; self:Alert("noLocation"); return end
    if self.pendingQuest then
        if not WORLD_MAP_QUEST_BREADCRUMBS:DoesQuestHavePendingTasks(questIndex) then
            self:CacheQuestPoints(questIndex)
        else
            EVENT_MANAGER:RegisterForUpdate("OneMapQuestWait", 3000, function()
                EVENT_MANAGER:UnregisterForUpdate("OneMapQuestWait")
                self.pendingQuest = nil
                self:Alert("waiting")
            end)
        end
    end
end
