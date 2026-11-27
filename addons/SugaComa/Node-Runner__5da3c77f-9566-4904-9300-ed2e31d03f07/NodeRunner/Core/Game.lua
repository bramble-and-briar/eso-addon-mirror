NODE_RUNNER = NODE_RUNNER or {}
local Project = NODE_RUNNER

Project.Game = Project.Game or {}
local Game = Project.Game

local UPDATE_NAME = Project.Config.addonName .. "_NodeRunnerTick"
local PHASE_IDLE = "idle"
local PHASE_COUNTDOWN = "countdown"
local PHASE_RUNNING = "running"
local PHASE_FINISHED = "finished"

local function NowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return GetFrameTimeMilliseconds()
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    if type(GetTimeStamp) == "function" then
        return GetTimeStamp() * 1000
    end
    return 0
end

local function SafeName(value)
    value = tostring(value or "")
    if value == "" then return "Unknown resource" end

    -- ESO item names may carry grammar metadata such as ^ns. The normal
    -- tooltip formatter consumes those markers and returns the player-facing
    -- localized name instead of exposing the raw grammar token on the HUD.
    if type(ZO_CachedStrFormat) == "function" and SI_TOOLTIP_ITEM_NAME ~= nil then
        local formatted = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, value)
        if formatted ~= nil and formatted ~= "" then
            return tostring(formatted)
        end
    end
    if type(zo_strformat) == "function" and SI_TOOLTIP_ITEM_NAME ~= nil then
        local formatted = zo_strformat(SI_TOOLTIP_ITEM_NAME, value)
        if formatted ~= nil and formatted ~= "" then
            return tostring(formatted)
        end
    end

    -- Defensive fallback for an API environment where the ESO formatter is
    -- unavailable. Item grammar tags are trailing caret codes (for example
    -- ^ns), so remove only that suffix rather than altering the item name.
    return (value:gsub("%^%a+$", ""))
end

local function IsSupportedBag(bagId)
    return bagId == BAG_BACKPACK or (BAG_VIRTUAL and bagId == BAG_VIRTUAL)
end

local function EqualsDefined(value, constantValue)
    return constantValue ~= nil and value == constantValue
end

local function RandomIndex(values)
    if type(values) ~= "table" or #values == 0 then return nil end
    return math.random(1, #values)
end

local function RandomValue(values, fallback)
    local index = RandomIndex(values)
    if not index then return fallback end
    return values[index]
end

local function RollPercent()
    return math.random(1, 100)
end

-- Resource-node families used by the roulette. Use item types rather than
-- names so the detector is language independent and works for both backpack
-- and Craft Bag delivery.
local function GetNodeKindFromTypes(itemType, specializedItemType)
    if EqualsDefined(itemType, ITEMTYPE_REAGENT) then
        if EqualsDefined(specializedItemType, SPECIALIZED_ITEMTYPE_REAGENT_HERB) then
            return "flower"
        end
        if EqualsDefined(specializedItemType, SPECIALIZED_ITEMTYPE_REAGENT_FUNGUS) then
            return "fungus"
        end
        return "reagent"
    end

    if EqualsDefined(itemType, ITEMTYPE_BLACKSMITHING_RAW_MATERIAL) then
        return "ore"
    end
    if EqualsDefined(itemType, ITEMTYPE_CLOTHIER_RAW_MATERIAL) then
        return "cloth"
    end
    if EqualsDefined(itemType, ITEMTYPE_WOODWORKING_RAW_MATERIAL) then
        return "wood"
    end
    if EqualsDefined(itemType, ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL) then
        return "jewelry"
    end

    if EqualsDefined(itemType, ITEMTYPE_ENCHANTING_RUNE_ASPECT)
        or EqualsDefined(itemType, ITEMTYPE_ENCHANTING_RUNE_ESSENCE)
        or EqualsDefined(itemType, ITEMTYPE_ENCHANTING_RUNE_POTENCY) then
        return "runestone"
    end

    -- Water/poison solvents can come from water gathering points. Keep these
    -- guarded because older API builds may not expose both constants.
    if EqualsDefined(itemType, ITEMTYPE_POTION_BASE)
        or EqualsDefined(itemType, ITEMTYPE_POISON_BASE) then
        return "water"
    end

    return nil
end

local function GetNodeKind(bagId, slotIndex)
    if type(GetItemType) ~= "function" then return nil end
    local itemType, specializedItemType = GetItemType(bagId, slotIndex)
    return GetNodeKindFromTypes(itemType, specializedItemType)
end

local function FindNodeItemById(itemId)
    itemId = tonumber(itemId) or 0
    if itemId <= 0 then return nil, nil, nil end

    -- Craft Bag virtual slots use the material item id as their slot index.
    if BAG_VIRTUAL then
        local kind = GetNodeKind(BAG_VIRTUAL, itemId)
        if kind then
            local itemName = type(GetItemName) == "function" and GetItemName(BAG_VIRTUAL, itemId) or ""
            return kind, itemName, BAG_VIRTUAL
        end
    end

    -- Non-ESO Plus and full-stack paths still land in the backpack. Search by
    -- item id so EVENT_LOOT_RECEIVED can be classified even when its matching
    -- slot event has already happened.
    if type(GetBagSize) == "function" and type(GetItemId) == "function" then
        local bagSize = tonumber(GetBagSize(BAG_BACKPACK)) or 0
        for slotIndex = 0, bagSize - 1 do
            if tonumber(GetItemId(BAG_BACKPACK, slotIndex)) == itemId then
                local kind = GetNodeKind(BAG_BACKPACK, slotIndex)
                if kind then
                    local itemName = type(GetItemName) == "function" and GetItemName(BAG_BACKPACK, slotIndex) or ""
                    return kind, itemName, BAG_BACKPACK
                end
            end
        end
    end

    return nil, nil, nil
end

function Game:EnsureRecords()
    Project.sv.projectData = Project.sv.projectData or {}
    local data = Project.sv.projectData
    data.gamesPlayed = tonumber(data.gamesPlayed) or 0
    data.bestTimeMs = tonumber(data.bestTimeMs) or 0
    data.totalNodes = tonumber(data.totalNodes) or 0
    data.totalGatherPenalties = tonumber(data.totalGatherPenalties) or 0

    -- Preserve old test counters so previous SavedVariables remain readable.
    data.totalFlowers = tonumber(data.totalFlowers) or 0
    data.totalFungi = tonumber(data.totalFungi) or 0
    return data
end

function Game:Publish(methodName, ...)
    if Project.Controller and type(Project.Controller.CallModules) == "function" then
        Project.Controller:CallModules(methodName, ...)
    end
    Project:NotifyChanged()
end

function Game:ResetCorrelation()
    self.pendingItemLookups = {}
    self.recentlySeenUntil = {}
    self.lastNodeGatherAtMs = 0
    self.harvestInteractionUntilMs = 0
end

function Game:CaptureHarvestInteraction(now)
    now = tonumber(now) or NowMs()
    if type(GetInteractionType) == "function" and INTERACTION_HARVEST
        and GetInteractionType() == INTERACTION_HARVEST then
        self.harvestInteractionUntilMs = now + Project.Config.harvestInteractionGraceMs
        return true
    end
    return false
end

function Game:IsHarvestInteractionRecent(now)
    now = tonumber(now) or NowMs()
    if self:CaptureHarvestInteraction(now) then return true end
    return now <= (tonumber(self.harvestInteractionUntilMs) or 0)
end

function Game:RegisterTick()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, Project.Config.updateIntervalMs, function()
        Game:OnTick()
    end)
end

function Game:UnregisterTick()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
end

function Game:StartRun()
    local state = Project.State
    if state:IsActive() then return false end

    self:ResetCorrelation()
    state:ResetRun()
    state.phase = PHASE_COUNTDOWN
    state.countdownEndsMs = NowMs() + (Project.Config.countdownSeconds * 1000)
    state.lastEffectText = "Prepare to gather."
    state.entryIndex = 2

    self:RegisterTick()
    self:Publish("OnHarvestCountdownStarted", state.countdownEndsMs - (Project.Config.countdownSeconds * 1000))
    return true
end

function Game:BeginClock()
    local state = Project.State
    if not state:IsCountdown() then return false end

    local now = NowMs()
    state.phase = PHASE_RUNNING
    state.startedAtMs = now
    state.harvestTimeMs = Project.Config.startingSeconds * 1000
    state.lastTickMs = now
    state.harvestRate = 1.0
    state.harvestRateEndsMs = 0
    state.gatherDeadlineMs = now + (Project.Config.gatherWindowSeconds * 1000)
    state.gatherPenalties = 0
    state.nodesGathered = 0
    state.lastEffectText = "Gather a resource node before GATHER reaches zero."
    state.lastEffectAmount = 0
    state.lastItemName = ""

    self:Publish("OnHarvestRunStarted", now)
    return true
end

function Game:RestartRun()
    self:CancelRun("Restarted", true)
    return self:StartRun()
end

function Game:CancelRun(reason, silent)
    local state = Project.State
    if not state:IsActive() and state.phase ~= PHASE_FINISHED then return false end

    self:UnregisterTick()
    self:ResetCorrelation()
    state:ResetRun()
    state.phase = PHASE_IDLE
    state.finishReason = SafeName(reason or "Cancelled")

    if not silent then
        self:Publish("OnHarvestRunCancelled")
    end
    return true
end

-- Survival Clock: real elapsed time only. No game effect may change this value.
function Game:GetElapsedMs(now)
    local state = Project.State
    now = tonumber(now) or NowMs()
    if (tonumber(state.startedAtMs) or 0) <= 0 then return 0 end
    return math.max(0, now - state.startedAtMs)
end

-- Harvest Clock: mutable remaining game time.
function Game:GetRemainingMs()
    local state = Project.State
    if not state:IsRunning() then return 0 end
    return math.max(0, tonumber(state.harvestTimeMs) or 0)
end

-- Gather Clock: real-time pressure timer, completely independent of Harvest
-- Clock rate/freeze effects.
function Game:GetGatherRemainingMs(now)
    local state = Project.State
    now = tonumber(now) or NowMs()
    if not state:IsRunning() then return 0 end
    return math.max(0, (tonumber(state.gatherDeadlineMs) or now) - now)
end

function Game:GetHarvestRate()
    return tonumber(Project.State.harvestRate) or 1.0
end

-- Advance only the Harvest Clock. This already supports a temporary rate so
-- Harvest Clock rate changes are temporary; GATHER and SURVIVED are untouched.
function Game:AdvanceHarvestClock(now)
    local state = Project.State
    if not state:IsRunning() then return end

    now = tonumber(now) or NowMs()
    local previous = tonumber(state.lastTickMs) or now
    if previous <= 0 or now <= previous then
        state.lastTickMs = now
        return
    end

    local remaining = math.max(0, tonumber(state.harvestTimeMs) or 0)
    local rate = math.max(0, tonumber(state.harvestRate) or 1.0)
    local rateEnds = tonumber(state.harvestRateEndsMs) or 0
    local drainMs = 0

    if rateEnds > 0 and previous < rateEnds and now >= rateEnds then
        local effectedElapsed = math.max(0, rateEnds - previous)
        local normalElapsed = math.max(0, now - rateEnds)
        drainMs = (effectedElapsed * rate) + normalElapsed
        state.harvestRate = 1.0
        state.harvestRateEndsMs = 0
        state.lastEffectAmount = 0
        state.lastEffectText = "TIME NORMAL"
    elseif rateEnds > 0 and previous >= rateEnds then
        drainMs = now - previous
        state.harvestRate = 1.0
        state.harvestRateEndsMs = 0
        state.lastEffectAmount = 0
        state.lastEffectText = "TIME NORMAL"
    else
        drainMs = (now - previous) * rate
    end

    state.harvestTimeMs = math.max(0, remaining - drainMs)
    state.lastTickMs = now
end

function Game:ApplyGatherPenalties(now)
    local state = Project.State
    if not state:IsRunning() then return 0 end

    now = tonumber(now) or NowMs()
    local windowMs = Project.Config.gatherWindowSeconds * 1000
    local penaltyMs = Project.Config.missedGatherPenaltySeconds * 1000
    local deadline = tonumber(state.gatherDeadlineMs) or 0

    if deadline <= 0 then
        state.gatherDeadlineMs = now + windowMs
        return 0
    end

    local applied = 0
    while now >= deadline and (tonumber(state.harvestTimeMs) or 0) > 0 do
        state.harvestTimeMs = math.max(0, (tonumber(state.harvestTimeMs) or 0) - penaltyMs)
        state.gatherPenalties = (tonumber(state.gatherPenalties) or 0) + 1
        applied = applied + 1
        deadline = deadline + windowMs
    end
    state.gatherDeadlineMs = deadline

    if applied > 0 then
        local totalPenaltySeconds = Project.Config.missedGatherPenaltySeconds * applied
        state.lastEffectAmount = -(totalPenaltySeconds * 1000)
        state.lastItemName = ""
        if applied == 1 then
            state.lastEffectText = string.format("-%ds — GATHER CLOCK EXPIRED", totalPenaltySeconds)
        else
            state.lastEffectText = string.format("-%ds — GATHER CLOCK EXPIRED x%d", totalPenaltySeconds, applied)
        end
        self:Publish("OnHarvestGatherPenalty", applied, totalPenaltySeconds, now)
    end

    return applied
end

function Game:UpdateTimers(now)
    local state = Project.State
    if not state:IsRunning() then return false end

    now = tonumber(now) or NowMs()
    self:AdvanceHarvestClock(now)
    self:ApplyGatherPenalties(now)

    if (tonumber(state.harvestTimeMs) or 0) <= 0 then
        self:FinishRun("The Harvest Clock ran out.", now)
        return false
    end
    return true
end

function Game:ResetGatherClock(now)
    local state = Project.State
    now = tonumber(now) or NowMs()
    state.gatherDeadlineMs = now + (Project.Config.gatherWindowSeconds * 1000)
end

-- Roulette time helper. Positive adjustments are capped at
-- 20:00; partial rewards are accepted (19:55 + 30s becomes exactly 20:00).
function Game:AdjustHarvestTime(deltaMs, effectText, nowMs, finishReason)
    local state = Project.State
    if not state:IsRunning() then return 0 end

    local now = tonumber(nowMs) or NowMs()
    if not self:UpdateTimers(now) then return 0 end

    deltaMs = tonumber(deltaMs) or 0
    local oldValue = math.max(0, tonumber(state.harvestTimeMs) or 0)
    local maxValue = Project.Config.maxHarvestSeconds * 1000
    local newValue = math.max(0, math.min(maxValue, oldValue + deltaMs))
    local applied = newValue - oldValue

    state.harvestTimeMs = newValue
    state.lastEffectAmount = applied
    if effectText ~= nil then
        state.lastEffectText = tostring(effectText)
    end

    if newValue <= 0 then
        self:FinishRun(finishReason or "The Harvest Clock ran out.", now)
    end
    return applied
end

-- Roulette helper for freeze/slow/speed effects. The Gather
-- Clock and Survival Clock remain untouched.
function Game:SetHarvestRate(rate, durationMs, effectText, nowMs)
    local state = Project.State
    if not state:IsRunning() then return false end

    local now = tonumber(nowMs) or NowMs()
    if not self:UpdateTimers(now) then return false end

    state.harvestRate = math.max(0, tonumber(rate) or 1.0)
    state.harvestRateEndsMs = now + math.max(0, tonumber(durationMs) or 0)
    state.lastEffectAmount = 0
    if effectText ~= nil then
        state.lastEffectText = tostring(effectText)
    end
    return true
end

function Game:RollNodeEffect(now)
    local state = Project.State
    if not state:IsRunning() then return nil end

    now = tonumber(now) or NowMs()
    local cfg = Project.Config.roulette or {}
    local roll = RollPercent()
    local cursor = 0
    local effect = "nothing"

    cursor = cursor + (tonumber(cfg.addTimeWeight) or 0)
    if roll <= cursor then
        effect = "add"
    else
        cursor = cursor + (tonumber(cfg.removeTimeWeight) or 0)
        if roll <= cursor then
            effect = "remove"
        else
            cursor = cursor + (tonumber(cfg.freezeWeight) or 0)
            if roll <= cursor then
                effect = "freeze"
            else
                cursor = cursor + (tonumber(cfg.slowWeight) or 0)
                if roll <= cursor then
                    effect = "slow"
                else
                    cursor = cursor + (tonumber(cfg.speedWeight) or 0)
                    if roll <= cursor then
                        effect = "speed"
                    else
                        effect = "nothing"
                    end
                end
            end
        end
    end

    state.rouletteRolls = (tonumber(state.rouletteRolls) or 0) + 1

    if effect == "add" then
        local seconds = tonumber(RandomValue(cfg.addTimeSeconds, 30)) or 30
        local applied = self:AdjustHarvestTime(seconds * 1000, nil, now)
        local appliedSeconds = math.max(0, math.floor((applied + 500) / 1000))
        if appliedSeconds <= 0 then
            state.lastEffectText = "TIME FULL — 20:00 CAP"
        elseif appliedSeconds < seconds then
            state.lastEffectText = string.format("TIME +%ds — 20:00 CAP", appliedSeconds)
        else
            state.lastEffectText = string.format("TIME +%ds", appliedSeconds)
        end
        state.lastEffectAmount = applied
        return effect
    end

    if effect == "remove" then
        local seconds = tonumber(RandomValue(cfg.removeTimeSeconds, 20)) or 20
        local applied = self:AdjustHarvestTime(-(seconds * 1000), nil, now,
            state.lastItemName ~= "" and (state.lastItemName .. " ended the harvest.") or "A bad roll ended the harvest.")
        local lostSeconds = math.max(0, math.floor((math.abs(applied) + 500) / 1000))
        if Project.State:IsRunning() then
            state.lastEffectText = string.format("TIME -%ds", lostSeconds)
            state.lastEffectAmount = applied
        end
        return effect
    end

    if effect == "freeze" then
        local seconds = tonumber(RandomValue(cfg.freezeSeconds, 15)) or 15
        self:SetHarvestRate(0, seconds * 1000, string.format("TIME FROZEN — %ds", seconds), now)
        return effect
    end

    if effect == "slow" then
        local seconds = tonumber(RandomValue(cfg.slowSeconds, 20)) or 20
        self:SetHarvestRate(tonumber(cfg.slowRate) or 0.5, seconds * 1000,
            string.format("TIME SLOWED — %ds", seconds), now)
        return effect
    end

    if effect == "speed" then
        local seconds = tonumber(RandomValue(cfg.speedSeconds, 15)) or 15
        self:SetHarvestRate(tonumber(cfg.speedRate) or 2.0, seconds * 1000,
            string.format("TIME ACCELERATED — %ds", seconds), now)
        return effect
    end

    state.lastEffectAmount = 0
    state.lastEffectText = "NO EFFECT"
    return "nothing"
end

function Game:RegisterNodeGather(kind, itemName)
    local state = Project.State
    if not state:IsRunning() then return false end

    local now = NowMs()
    if not self:UpdateTimers(now) then return false end

    -- One harvested node may produce several resource items. Only the first
    -- qualifying delivery inside this short window counts as the node event.
    local lastNodeAt = tonumber(self.lastNodeGatherAtMs) or 0
    if lastNodeAt > 0 and (now - lastNodeAt) <= Project.Config.nodeDedupWindowMs then
        return true
    end
    self.lastNodeGatherAtMs = now

    state.nodesGathered = (tonumber(state.nodesGathered) or 0) + 1
    state.lastNodeKind = tostring(kind or "resource")
    state.lastItemName = SafeName(itemName)
    state.lastEffectAmount = 0
    self:ResetGatherClock(now)

    -- One node, one spin. Immediate effects leave any active speed/freeze state
    -- alone; a new timed rate effect replaces the previous timed rate effect.
    self:RollNodeEffect(now)

    if state:IsRunning() then
        self:Publish("OnHarvestNodeGathered", kind, state.lastItemName, now)
    end
    return true
end

function Game:EnsureRunHistory(data)
    if type(data.runHistory) ~= "table" then
        -- Preserve the only historical result available from older builds.
        data.runHistory = type(data.lastRun) == "table" and {data.lastRun} or {}
    end
    return data.runHistory
end

function Game:FinishRun(reason, finishedAtMs)
    local state = Project.State
    if not state:IsRunning() then return false end

    local now = tonumber(finishedAtMs) or NowMs()
    local durationMs = self:GetElapsedMs(now)
    self:UnregisterTick()
    self:ResetCorrelation()

    local data = self:EnsureRecords()
    data.gamesPlayed = data.gamesPlayed + 1
    data.totalNodes = data.totalNodes + (tonumber(state.nodesGathered) or 0)
    data.totalGatherPenalties = data.totalGatherPenalties + (tonumber(state.gatherPenalties) or 0)

    local isBest = durationMs > data.bestTimeMs
    if isBest then data.bestTimeMs = durationMs end

    local result = {
        durationMs = durationMs,
        nodes = tonumber(state.nodesGathered) or 0,
        gatherPenalties = tonumber(state.gatherPenalties) or 0,
        zone = type(GetUnitZone) == "function" and GetUnitZone("player") or "Unknown Zone",
        character = type(GetUnitName) == "function" and GetUnitName("player") or "Unknown Character",
        timestamp = type(GetTimeStamp) == "function" and GetTimeStamp() or 0,
        reason = SafeName(reason or "Time expired."),
        newBest = isBest,
    }

    local history = self:EnsureRunHistory(data)
    table.insert(history, 1, result)
    if #history > 25 then table.remove(history) end
    data.lastRun = result
    state.phase = PHASE_FINISHED
    state.lastResult = result
    state.finishReason = result.reason
    state.lastEffectText = isBest and "NEW PERSONAL BEST" or "RUN COMPLETE"
    state.lastEffectAmount = 0

    self:Publish("OnHarvestRunFinished", result, now)
    return true
end

function Game:OnTick()
    local state = Project.State
    local now = NowMs()

    if state:IsCountdown() then
        if now >= state.countdownEndsMs then
            self:BeginClock()
        else
            self:Publish("OnHarvestTick", now)
        end
        return
    end

    if state:IsRunning() then
        self:CaptureHarvestInteraction(now)
        if self:UpdateTimers(now) then
            self:Publish("OnHarvestTick", now)
        end
        return
    end

    self:UnregisterTick()
end

function Game:WasRecentlySeen(itemId, now)
    now = tonumber(now) or NowMs()
    local untilMs = tonumber(self.recentlySeenUntil[itemId]) or 0
    if now <= untilMs then
        return true
    end
    self.recentlySeenUntil[itemId] = nil
    return false
end

function Game:MarkRecentlySeen(itemId, now)
    self.recentlySeenUntil[itemId] = (tonumber(now) or NowMs())
        + Project.Config.duplicateInventoryWindowMs
    self.pendingItemLookups[itemId] = nil
end

function Game:TryRegisterItemId(itemId, fallbackName, source)
    if not Project.State:IsRunning() then return false end

    itemId = tonumber(itemId) or 0
    if itemId <= 0 then return false end

    local now = NowMs()
    if self:WasRecentlySeen(itemId, now) then
        self.pendingItemLookups[itemId] = nil
        return true
    end

    local kind, resolvedName, resolvedBag = FindNodeItemById(itemId)
    if not kind then return false end

    local itemName = SafeName((resolvedName and resolvedName ~= "") and resolvedName or fallbackName)
    self:MarkRecentlySeen(itemId, now)
    Project.Diagnostics:Log(string.format(
        "Resource node candidate from %s in bag %s: %s (%d) [%s]",
        tostring(source or "unknown"), tostring(resolvedBag), tostring(itemName), itemId, tostring(kind)
    ))
    return self:RegisterNodeGather(kind, itemName)
end

function Game:RetryPendingItem(itemId)
    if not Project.State:IsRunning() then return end

    local pending = self.pendingItemLookups[itemId]
    if not pending then return end

    local now = NowMs()
    if now > (tonumber(pending.expiresMs) or 0) then
        self.pendingItemLookups[itemId] = nil
        return
    end

    self:TryRegisterItemId(itemId, pending.itemName, "delayed Craft Bag lookup")
end

function Game:QueueItemLookup(itemId, itemName)
    local now = NowMs()
    self.pendingItemLookups[itemId] = {
        itemName = itemName,
        expiresMs = now + Project.Config.lootCorrelationWindowMs,
    }

    if type(zo_callLater) == "function" then
        zo_callLater(function() Game:RetryPendingItem(itemId) end, 100)
        zo_callLater(function() Game:RetryPendingItem(itemId) end, 400)
    end
end

function Game:OnLootReceived(_, receivedBy, itemName, quantity, soundCategory, lootType,
        isSelf, isPickpocketLoot, questItemIcon, itemId, isStolen)
    if not Project.State:IsRunning() then return end
    if isSelf == false or isPickpocketLoot == true or isStolen == true then return end
    if LOOT_TYPE_ITEM and lootType ~= LOOT_TYPE_ITEM then return end

    itemId = tonumber(itemId) or 0
    if itemId <= 0 then return end
    if not self:IsHarvestInteractionRecent(NowMs()) then return end

    -- EVENT_LOOT_RECEIVED is the reliable acquisition signal for both ordinary
    -- backpack loot and materials auto-routed into the ESO Plus Craft Bag.
    if self:TryRegisterItemId(itemId, itemName, "loot received") then
        return
    end

    -- If the loot event beats the Craft Bag transfer by a frame, retry after the
    -- virtual slot exists. The inventory event remains a second immediate path.
    self:QueueItemLookup(itemId, itemName)
end

function Game:OnInventorySlotUpdated(_, bagId, slotIndex, isNewItem, itemSoundCategory,
        inventoryUpdateReason, stackCountChange)
    if not Project.State:IsRunning() then return end
    if not IsSupportedBag(bagId) then return end
    if (tonumber(stackCountChange) or 0) <= 0 then return end
    if INVENTORY_UPDATE_REASON_DEFAULT and inventoryUpdateReason ~= INVENTORY_UPDATE_REASON_DEFAULT then return end
    if not self:IsHarvestInteractionRecent(NowMs()) then return end

    local kind = GetNodeKind(bagId, slotIndex)
    if not kind then return end

    local itemId = type(GetItemId) == "function" and GetItemId(bagId, slotIndex) or 0
    itemId = tonumber(itemId) or 0
    if itemId <= 0 then return end

    local now = NowMs()
    if self:WasRecentlySeen(itemId, now) then
        self.pendingItemLookups[itemId] = nil
        return
    end

    local itemName = type(GetItemName) == "function" and GetItemName(bagId, slotIndex) or ""
    self:MarkRecentlySeen(itemId, now)
    Project.Diagnostics:Log(string.format(
        "Resource node candidate from inventory in bag %s: %s (%d) [%s]",
        tostring(bagId), tostring(itemName), itemId, tostring(kind)
    ))
    self:RegisterNodeGather(kind, itemName)
end

function Game:OnPlayerActivated()
    if Project.State:IsActive() then
        self:CancelRun("Travel interrupted the run.")
    end
end

function Game:OnPlayerDeactivated()
    if Project.State:IsActive() then
        self:CancelRun("Travel interrupted the run.")
    end
end

function Game:Initialize()
    if self.initialized then return end
    self:EnsureRecords()
    self:ResetCorrelation()

    if EVENT_LOOT_RECEIVED then
        Project.Events:Register("NodeRunnerLootReceived", EVENT_LOOT_RECEIVED, function(...)
            Game:OnLootReceived(...)
        end)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        Project.Events:Register("NodeRunnerInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(...)
            Game:OnInventorySlotUpdated(...)
        end)
    end
    if EVENT_PLAYER_DEACTIVATED then
        Project.Events:Register("NodeRunnerPlayerDeactivated", EVENT_PLAYER_DEACTIVATED, function(...)
            Game:OnPlayerDeactivated(...)
        end)
    end

    self.initialized = true
    Project.Diagnostics:Log("Node Runner foundation gameplay initialized", true)
end

function Game:Shutdown()
    self:UnregisterTick()
    self:ResetCorrelation()
    self.initialized = false
end

Project.Controller:RegisterModule("NodeRunner", Game)
