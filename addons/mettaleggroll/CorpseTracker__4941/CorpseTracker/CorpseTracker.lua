local CT = CorpseTracker
local EM = EVENT_MANAGER
local MAX_LOG_ROWS = 2500
local defaults = {
    x = 480, y = 340, locked = false,
    radius = 12, bbTTL = 5, archerTTL = 10, bannerTTL = 5, skullTTL = 5,
    capture = false, physicalOnly = false, bannerUnits = false,
    sourceMode = "primary", debugMode = false, displayMode = "compact", countMode = "light", squareSize = 64,
    rangeMode = "siphon", manualRange = 28, includeUnknown = true, language = "auto",
    rules = {}, log = {},
}
local watch = {
    [117715] = true, [117691] = true, [117692] = true,
    [118681] = true, [122377] = true, [118764] = true, [124003] = true,
    [227068] = true, [227072] = true, [227110] = true, [227111] = true,
    [227112] = true, [227113] = true, [227114] = true,
    [263461] = true, [263462] = true, [120612] = true,
    [220102] = true,
    [117850] = true, [117852] = true, [117853] = true, [117854] = true,
    [117860] = true, [115567] = true, [115548] = true,
}
local phaseNames = { [EFFECT_RESULT_GAINED] = "gained",
    [EFFECT_RESULT_UPDATED] = "updated", [EFFECT_RESULT_FADED] = "faded" }
local inCombat = false
local rawBanner, direct, frame, label, timer, question, sourceButton, background, icon
local timerShown, questionShown, lastQuestionCount
local renderedText = {}
local lastLabelUncertain, lastTimerTenth
local unitBindings, cachedFilter, nextRangeRead = {}, nil, 0
local summons = {}
local summonSerial = 0
local knownUnits, unitStates = {}, {}
local rowSerial = 0
local pendingYard, wasteState, consumeWitness
local lastSkullBody, lastSkullMarker
local pendingSiphon, lastSiphonAt = nil, -math.huge
local yardSerial, yardCasts, yardConsumed, yardUnconfirmed = 0, 0, 0, 0
local combatBaseline = { created = 0, consumed = 0, expired = 0, unmatched = 0,
    untrackedConsumed = 0, remaining = 0, yardConsumed = 0, yardUnconfirmed = 0 }
local nextCleanup = 0

local function Finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

local function NormalizeSaved()
    local saved = CT.saved
    local limits = { x = {-100000,100000}, y = {-100000,100000},
        squareSize = {40,140}, radius = {1,100}, manualRange = {1,60},
        bbTTL = {1,60}, skullTTL = {1,60}, archerTTL = {1,60}, bannerTTL = {1,60} }
    for key, bounds in pairs(limits) do
        local value = saved[key]
        saved[key] = Finite(value) and math.max(bounds[1], math.min(bounds[2], value)) or defaults[key]
    end
    for _, key in ipairs({"locked","capture","debugMode","physicalOnly","includeUnknown"}) do
        if type(saved[key]) ~= "boolean" then saved[key] = defaults[key] or false end
    end
    if saved.rangeMode ~= "siphon" and saved.rangeMode ~= "yard" and
            saved.rangeMode ~= "manual" and saved.rangeMode ~= "none" then saved.rangeMode = "siphon" end
    if saved.language ~= "auto" and not CT.locales[saved.language] then saved.language = "auto" end
    if type(saved.rules) ~= "table" then saved.rules = {} end
    for id, rule in pairs(saved.rules) do
        local number = tonumber(id)
        if not Finite(number) or number <= 0 or number ~= math.floor(number) or
                type(id) ~= "string" or type(rule) ~= "table" or
                (rule.kind ~= "create" and rule.kind ~= "consume") or
                (rule.phase ~= "gained" and rule.phase ~= "updated" and rule.phase ~= "faded") or
                (rule.kind == "create" and (not Finite(rule.ttl) or rule.ttl < 1 or rule.ttl > 60)) or
                (rule.kind == "consume" and (not Finite(rule.amount) or rule.amount < 1 or
                    rule.amount > 10 or rule.amount ~= math.floor(rule.amount))) or
                watch[number] or CT.AbilityFamily(number) then
            saved.rules[id] = nil
        end
    end
    if type(saved.log) ~= "table" then saved.log = {} end
    -- Keep the log table's identity and its newest valid rows, including a
    -- stopped recording loaded from an older or damaged SavedVariables file.
    local log, length, write = saved.log, #saved.log, 0
    for read = math.max(1, length - MAX_LOG_ROWS + 1), length do
        if type(log[read]) == "table" then write = write + 1; log[write] = log[read] end
    end
    for index = write + 1, length do log[index] = nil end
end

local function Now() return GetFrameTimeSeconds() end
local function Say(s) d("|c88ddccCorpse Tracker|r " .. s) end

local function Record(kind, data)
    if not CT.saved.capture then return end
    local log = CT.saved.log
    rowSerial = rowSerial + 1
    data.kind, data.t, data.sequence = kind, Now(), rowSerial
    data.addonVersion = CT.version
    log[#log + 1] = data
    if #log > MAX_LOG_ROWS then table.remove(log, 1) end
end

local function FinishYard()
    if not pendingYard or pendingYard.counted or not pendingYard.markerAt or
        not consumeWitness or Now() - pendingYard.at > 0.8 or
        math.abs(pendingYard.markerAt - consumeWitness.at) > 0.15 then return end
    pendingYard.counted = true
    if CT.ledger:Consume(1, Now(), "yard:" .. pendingYard.serial, not CT.saved.physicalOnly,
            nil, { allowUntracked = true }) then
        yardConsumed = yardConsumed + 1
        Record("yard_consumed", { serial = pendingYard.serial,
            evidence = consumeWitness.evidence, physicalAssumption = CT.saved.physicalOnly,
            untrackedPossible = true })
    end
end

local function ExpireYard()
    if pendingYard and Now() - pendingYard.at > 0.8 then
        if not pendingYard.counted then
            yardUnconfirmed = yardUnconfirmed + 1
            Record("yard_unconfirmed", { serial = pendingYard.serial })
        end
        pendingYard = nil
    end
end

local function ArmYard()
    ExpireYard()
    if pendingYard then return end -- skill event and self effect are one cast
    yardSerial, yardCasts = yardSerial + 1, yardCasts + 1
    pendingYard = { at = Now(), serial = yardSerial }
    Record("yard_cast", { serial = yardSerial })
end

local function WasteChanged(change, stacks, endTime, combatStack)
    local previous = wasteState
    if change == EFFECT_RESULT_FADED then wasteState = nil; return end
    if change ~= EFFECT_RESULT_GAINED and change ~= EFFECT_RESULT_UPDATED then return end
    endTime = endTime or 0
    local consumed = (change == EFFECT_RESULT_GAINED and stacks > 0 and not previous) or
        (previous and (stacks > previous.stacks or
            (stacks == 10 and previous.stacks == 10 and
                (endTime > previous.endTime + 0.01 or
                 (combatStack and Now() - (previous.stackAt or Now()) > 0.25)))))
    wasteState = { stacks = stacks, endTime = math.max(endTime, previous and previous.endTime or 0),
        stackAt = combatStack and Now() or (previous and previous.stackAt or Now()) }
    if consumed then
        consumeWitness = { at = Now(), evidence = "Nothing Wasted refresh" }
        FinishYard()
    end
end

local function SeedWaste()
    wasteState = nil
    for index = 1, GetNumBuffs("player") do
        local _, _, ending, _, stacks, _, _, _, _, _, id = GetUnitBuffInfo("player", index)
        if id == 263461 or id == 263462 then
            wasteState = { stacks = stacks, endTime = ending, stackAt = Now() }; break
        end
    end
end

local function Position(tag)
    if CT.saved.countMode == "light" and not (CT.saved.debugMode and CT.saved.capture) then return nil end
    if not tag or not DoesUnitExist(tag) then return nil end
    local zone, x, y, z = GetUnitWorldPosition(tag)
    -- Zero coordinates commonly mean unavailable world position.
    if not Finite(zone) or zone == 0 or not Finite(x) or not Finite(y) or not Finite(z) or
            (x == 0 and y == 0 and z == 0) then return nil end
    return { zone = zone, x = x, y = y, z = z }
end

local function IsOwn(sourceType)
    return sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
end

local function SampleBanner(count, channel)
    if not Finite(count) or count < 0 or count > 2147483647 or count ~= math.floor(count) then return end
    rawBanner = { count = count, at = Now(), channel = channel }
end

local function UpdateBodyPosition(tag, unitId)
    if CT.saved.countMode == "light" then return end
    local body = unitId and CT.ledger.units[unitId]
    if body and body.expires > Now() and IsUnitDead(tag) then
        local p = Position(tag)
        if p then body.position = p end
    end
end

local function SkullIdentity(unitId)
    lastSkullMarker = { at = Now(), unitId = unitId }
    if lastSkullBody and math.abs(lastSkullBody.created - Now()) <= 0.25 then
        CT.ledger:BindIdentity(lastSkullBody, unitId)
    end
end

local function ConsumeSiphon(targetUnitId, targetType, maxBodyId)
    local accepted, identity, source = CT.ledger:Consume(1, Now(), "siphon-application",
        not CT.saved.physicalOnly, targetUnitId, { strictTarget = true, maxBodyId = maxBodyId })
    if accepted then
        lastSiphonAt = Now()
        Record("siphon_consumed", { target = targetUnitId or 0,
            identity = identity, source = source or "unknown", targetType = targetType })
    end
    consumeWitness = nil
end

local function FlushSiphon(force)
    if pendingSiphon and (force or Now() - pendingSiphon.at >= 0.25) then
        local pending = pendingSiphon
        pendingSiphon = nil
        -- Without a target ID, only bodies present when the self effect arrived
        -- can be candidates. A later BB explosion cannot be spent retroactively.
        ConsumeSiphon(nil, nil, pending.maxBodyId)
    end
end

local function QueueSiphon()
    if Now() - lastSiphonAt >= 0.25 and not pendingSiphon then
        pendingSiphon = { at = Now(), maxBodyId = CT.ledger.serial }
        Record("siphon_pending", { maxBodyId = pendingSiphon.maxBodyId })
    end
    consumeWitness = nil
end

local function YardMarker()
    if pendingYard and Now() - pendingYard.at <= 0.8 then
        pendingYard.markerAt = Now()
        FinishYard()
    end
end

local function SummonChanged(abilityId, tag, unitId, change, beginTime, endTime)
    if change == EFFECT_RESULT_GAINED and
            (not Finite(beginTime) or not Finite(endTime) or endTime - beginTime > 60) then return end
    local key = tostring(abilityId) .. ":" .. (tag == "player" and "player" or tostring(unitId))
    local previous = summons[key]
    if change == EFFECT_RESULT_GAINED and endTime - beginTime >= 19 then
        -- Owner and pet effects begin a few milliseconds apart. Merge them.
        for _, instance in pairs(summons) do
            if math.abs(instance.beginTime - beginTime) <= 0.25 then previous = instance; break end
        end
        if not previous or math.abs(previous.beginTime - beginTime) > 0.25 then
            summonSerial = summonSerial + 1
            previous = { beginTime = beginTime, endTime = endTime, serial = summonSerial }
        end
        summons[key] = previous
        if tag:match("^playerpet%d+$") then
            previous.unitId = unitId
            if previous.body then CT.ledger:BindIdentity(previous.body, unitId) end
        end
    elseif change == EFFECT_RESULT_FADED and previous then
        -- Real FADED callbacks have beginTime=endTime=0. Use cached GAINED data.
        summons[key] = nil
        local p = tag:match("^playerpet%d+$") and Position(tag) or nil
        if previous.body and p then previous.body.position = p end
        if not previous.counted and Now() - previous.beginTime >= 10 then
            previous.counted = true
            if CT.ledger:Add("skeletal?", Now(), CT.saved.archerTTL, p,
                    "skeletal:" .. previous.serial, CT.saved.archerTTL) then
                previous.body = CT.ledger.bodies[#CT.ledger.bodies]
                CT.ledger:BindIdentity(previous.body, previous.unitId)
                Record("skeletal_created", { ability = abilityId, tag = tag, serial = previous.serial })
            end
        end
    end
end

local function Cleanup(now)
    if now < nextCleanup then return end
    nextCleanup = now + 1
    -- FADED/UNIT_DESTROYED may be missed during transitions. Retain a grace
    -- window for late callbacks; discarding a stale summon never creates a corpse.
    for key, instance in pairs(summons) do
        if now > instance.endTime + 60 then summons[key] = nil end
    end
    for tag in pairs(knownUnits) do
        if not DoesUnitExist(tag) then
            knownUnits[tag], unitStates[tag], unitBindings[tag] = nil, nil, nil
        end
    end
    for tag in pairs(unitBindings) do
        if not DoesUnitExist(tag) then unitBindings[tag], unitStates[tag] = nil, nil end
    end
end

local function RangeFilter()
    if cachedFilter and Now() < nextRangeRead then return cachedFilter end
    local mode, range, id = CT.saved.rangeMode
    if mode == "manual" then range = CT.saved.manualRange
    elseif mode ~= "none" then range, id = CT.ReadSkillRange(mode) end
    cachedFilter = { enabled = mode ~= "none" and range ~= nil, range = range,
        includeUnknown = CT.saved.includeUnknown, mode = mode, ability = id }
    nextRangeRead = Now() + 2
    return cachedFilter
end

local function CurrentCount()
    if CT.saved.countMode == "light" then
        local filter = { enabled = false, mode = "none", light = true }
        return CT.ledger:Count(Now(), nil, nil, CT.saved.sourceMode), filter
    end
    local filter = RangeFilter()
    return CT.ledger:Count(Now(), Position("player"), CT.saved.radius, CT.saved.sourceMode, filter), filter
end

local function SetTextIfChanged(control, text)
    if renderedText[control] ~= text then
        control:SetText(text)
        renderedText[control] = text
    end
end

local function Refresh()
    local now = Now()
    Cleanup(now)
    FlushSiphon(false)
    ExpireYard()
    local c, filter = CurrentCount()
    CT.displayCount, CT.displayFilter = c, filter
    -- Keep consumption and expiry current while menus hide the HUD. Rendering
    -- resumes on OnShow; hidden controls need no text, colour or layout writes.
    if frame:IsHidden() then return end
    local unknownIncluded = c.unknown > 0 and (not filter.enabled or filter.includeUnknown)
    local ambiguousCount = c.uncertain or (not c.light and
        (c.minimum ~= c.maximum or unknownIncluded or c.boundsBroad or
         filter.mode == "yard" or (filter.mode ~= "none" and not filter.enabled)))
    local uncertain = CT.saved.debugMode and not c.light and ambiguousCount
    local zeroRisk = c.light and c.uncertain or
        (not c.light and c.minimum == 0 and c.maximum > 0)
    if lastLabelUncertain ~= uncertain then
        label:SetColor(1, uncertain and 0.78 or 1, uncertain and 0.35 or 1, 1)
        lastLabelUncertain = uncertain
    end
    if CT.saved.displayMode ~= "detailed" then
        SetTextIfChanged(label, tostring(c.total))
        local showTimer = c.total > 0 and c.nextExpiry ~= nil and c.nextExpiry > 0
        local showQuestion = zeroRisk == true
        if timerShown ~= showTimer or questionShown ~= showQuestion then
            timerShown, questionShown = showTimer, showQuestion
            local size = CT.saved.squareSize
            local questionWidth = math.max(14, math.floor(size * 0.25))
            label:SetDimensions(showQuestion and size - questionWidth - 2 or size,
                showTimer and size - math.max(16, math.floor(size * 0.25)) or size)
            timer:SetHidden(not showTimer)
            question:SetHidden(not showQuestion)
        end
        if showQuestion and lastQuestionCount ~= c.total then
            lastQuestionCount = c.total
            question:ClearAnchors()
            question:SetAnchor(LEFT, label, CENTER, label:GetTextWidth() / 2 + 2, 0)
        end
        -- TTL and an unidentified Yard choice are estimates. Round upwards
        -- so a living entry never displays 0.0 before its expiry.
        local tenth = showTimer and math.max(1, math.ceil(c.nextExpiry * 10 - 0.000001)) or 0
        if lastTimerTenth ~= tenth then
            SetTextIfChanged(timer, showTimer and string.format("~%.1f", tenth / 10) or "")
            lastTimerTenth = tenth
        end
        return
    end
    local mode = CT.T(CT.saved.sourceMode == "primary" and "PRIMARY" or "ALL")
    local range = c.minimum ~= c.maximum and " " .. CT.T("POSSIBLE", c.minimum, c.maximum) or ""
    SetTextIfChanged(sourceButton, CT.T("SOURCE_BUTTON", mode))
    local probe = CT.T("API_MISSING")
    if direct then
        local age = now - direct.at
        probe = CT.T("API_SAMPLE", direct.verified and "API" or CT.T("CANDIDATE"),
            direct.count, direct.radius, age, age > 6 and CT.T("STALE") or "")
    end
    local raw = rawBanner and CT.T("BANNER_SAMPLE", rawBanner.count, now - rawBanner.at) or CT.T("BANNER_MISSING")
    local expiry = c.nextExpiry and CT.T("TTL_EXPIRES", c.nextExpiry) or CT.T("TTL_EMPTY")
    if c.light then
        SetTextIfChanged(label, table.concat({
            CT.T("CORPSES") .. " ~" .. c.total .. (zeroRisk and " ?" or "") .. " | " .. mode,
            CT.T("LIGHT_INFO"), CT.T("BREAKDOWN", c.breakdown.bb, c.breakdown.skull, c.breakdown.other),
            CT.T("SESSION", CT.ledger.created, CT.ledger.consumed, CT.ledger.expired),
            CT.T("YARD_STATS", yardConsumed, yardUnconfirmed, CT.ledger.untrackedConsumed, CT.ledger.unmatched),
            CT.T("TTL_ESTIMATE", expiry, CT.saved.capture and CT.T("RECORDING") or ""),
        }, "\n"))
        return
    end
    local filterText = filter.mode == "none" and CT.T("RANGE_OFF") or
        (filter.enabled and CT.T("RANGE_AVAILABLE", CT.T("RANGE_" .. filter.mode:upper()),
            filter.range, c.outside, CT.T(filter.includeUnknown and "INCLUDED" or "EXCLUDED")) or
            CT.T("RANGE_UNAVAILABLE"))
    SetTextIfChanged(label, table.concat({
        CT.T("CORPSES") .. " ~" .. c.total .. (zeroRisk and " ?" or "") .. range .. " | " .. mode,
        CT.T("BREAKDOWN", c.breakdown.bb, c.breakdown.skull, c.breakdown.other),
        CT.T("LOCATED", filter.enabled and filter.range or CT.saved.radius, c.inside, c.unknown),
        probe, raw, CT.T("SESSION", CT.ledger.created, CT.ledger.consumed, CT.ledger.expired),
        CT.T("YARD_STATS", yardConsumed, yardUnconfirmed, CT.ledger.untrackedConsumed, CT.ledger.unmatched),
        CT.T("TTL_ESTIMATE", expiry, CT.saved.capture and CT.T("RECORDING") or ""),
        CT.T(c.boundsBroad and "BOUNDS_BROAD" or "CHOICE_UNKNOWN"), filterText,
    }, "\n"))
end

function CT.SubmitRadiusSnapshot(count, radius, verified, sampledAt)
    local s = CT.ValidateSnapshot(count, radius, verified, Now(), sampledAt)
    if not s then return false end
    direct = s
    Record("radius_snapshot", { count = s.count, radius = radius, verified = s.verified })
    return true
end

function CT.ApplySettings()
    if CT.saved.countMode == "light" then CT.saved.displayMode = "compact" end
    cachedFilter, nextRangeRead = nil, 0
    unitStates = {}
    CT.ledger:Expire(Now())
    CT.ledger:SetMode(CT.saved.countMode)
    -- Font, size, language and layout changes invalidate the rendered cache.
    renderedText, lastLabelUncertain, lastTimerTenth = {}, nil, 0
    local debug = CT.saved.displayMode == "detailed"
    local size = CT.saved.squareSize
    frame:SetDimensions(debug and 660 or size, debug and 360 or size)
    frame:SetMouseEnabled(true)
    frame:SetMovable(not CT.saved.locked)
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    label:SetDimensions(debug and 660 or size, debug and 326 or size)
    label:SetFont(debug and "ZoFontGame" or ("$(BOLD_FONT)|" .. math.floor(size * 0.55) .. "|soft-shadow-thick"))
    label:SetHorizontalAlignment(debug and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(debug and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
    timerShown, questionShown, lastQuestionCount = nil, nil, nil
    local timerHeight = math.max(16, math.floor(size * 0.25))
    timer:ClearAnchors()
    timer:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, size - timerHeight)
    timer:SetDimensions(size, timerHeight)
    timer:SetFont("$(BOLD_FONT)|" .. math.max(12, math.floor(size * 0.2)) .. "|soft-shadow-thick")
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1, 1, 1, 0.9)
    SetTextIfChanged(timer, "")
    timer:SetHidden(true)
    local questionSize = math.max(14, math.floor(size * 0.25))
    question:SetDimensions(questionSize, questionSize + 6)
    question:SetFont("$(BOLD_FONT)|" .. questionSize .. "|soft-shadow-thick")
    question:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    question:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    question:SetColor(1, 1, 1, 1)
    question:SetText("?")
    question:SetHidden(true)
    sourceButton:ClearAnchors()
    sourceButton:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 326)
    sourceButton:SetDimensions(660, 26)
    sourceButton:SetHidden(not debug)
    background:SetHidden(debug)
    icon:SetDimensions(size - 6, size - 6)
    icon:SetHidden(debug)
    -- The scene fragment owns visibility. Never unhide the control from the
    -- update loop: that would put it back over inventory/settings scenes.
    if CT.hudFragment then CT.hudFragment:Refresh() end
    Refresh()
end

local function InspectUnit(tag)
    if not CT.saved.capture or not CT.saved.debugMode then return end
    if not DoesUnitExist(tag) then unitStates[tag] = nil; return end
    local name, dead = GetUnitName(tag), IsUnitDead(tag)
    local position, player = Position(tag), Position("player")
    local distance
    if position and player and position.zone == player.zone then
        local dx, dy, dz = position.x - player.x, position.y - player.y, position.z - player.z
        distance = math.sqrt(dx * dx + dy * dy + dz * dz) / 100
    end
    local stamp = tostring(unitBindings[tag] or "") .. ":" .. tostring(dead) .. ":" ..
        tostring(distance and math.floor(distance * 2)) .. ":" ..
        tostring(distance and distance <= CT.saved.radius)
    if unitStates[tag] ~= stamp then
        unitStates[tag] = stamp
        Record("unit_observed", { tag = tag, name = name, dead = dead, position = position,
            distance = distance, inRadius = distance and distance <= CT.saved.radius })

    end
end

local function CombatEvent(_, result, isError, abilityName, _, _, sourceName,
        sourceType, targetName, targetType, hitValue, _, _, _, sourceId, targetId, abilityId)
    -- Independent evidence for the enemy-corpse investigation. Death is not
    -- proof of a reusable corpse or its lifetime, so it never adds a body.
    if CT.saved.capture and not isError and
            (result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP) then
        Record("death", { result = result, target = targetId, targetType = targetType,
            targetName = targetName, source = sourceId, sourceType = sourceType,
            ability = abilityId, positionEstimate = nil })
    end
    local family = CT.AbilityFamily(abilityId)
    -- 117860 shares Yard's name but occurs without a new cast in live logs.
    local yardEffect = CT.IsYardActivation(abilityId)
    if not watch[abilityId] and not family and not CT.saved.rules[tostring(abilityId)] then return end
    if CT.saved.capture then
        Record("combat", { ability = abilityId, name = abilityName, result = result,
            error = isError, source = sourceId, target = targetId, sourceType = sourceType,
            targetType = targetType, amount = hitValue })
    end
    if isError then return end
    local selfEvent = sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER
    -- Here hitValue is a stack count for GAINED, milliseconds for DURATION.
    -- Never interpret duration/fade values as corpse counts.
    if selfEvent and result == ACTION_RESULT_EFFECT_GAINED then
        if abilityId == 263461 or abilityId == 263462 then
            WasteChanged(EFFECT_RESULT_GAINED, hitValue, 0, true)
        elseif abilityId == 227113 then
            SampleBanner(hitValue, "combat")
        elseif abilityId == 117852 or yardEffect then
            ArmYard(); YardMarker()
        elseif abilityId == 117853 then
            YardMarker()
        elseif abilityId == 227068 then
            consumeWitness = { at = Now(), evidence = "Corpseburster proc combat effect" }
            FinishYard()
        end
    end
    -- First hits can precede COMBAT_STATE(true); corpses can remain usable
    -- after COMBAT_STATE(false). The combat flag is not a corpse lifetime.
    if not IsOwn(sourceType) then return end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER_PET and
            result == ACTION_RESULT_EFFECT_GAINED then
        if abilityId == 220102 then SkullIdentity(targetId) end
    end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType ~= COMBAT_UNIT_TYPE_PLAYER and
            result == ACTION_RESULT_EFFECT_GAINED and CT.IsSiphonApplication(abilityId) then
        if type(targetId) == "number" and targetId > 0 then
            pendingSiphon = nil
            ConsumeSiphon(targetId, targetType)
        else
            QueueSiphon()
        end
    end
    if CT.IsThirdSkull(abilityId) and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            (result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE) then
        -- Shared 3 s guard: AoE/bounces cannot create additional bodies, and
        -- Venom's extra Necromancer casts can advance the chain unusually fast.
        if CT.ledger:Add("skull?", Now(), CT.saved.skullTTL, nil,
                "skull-generation", 3) then
            lastSkullBody = CT.ledger.bodies[#CT.ledger.bodies]
            if lastSkullMarker and math.abs(lastSkullMarker.at - Now()) <= 0.25 then
                CT.ledger:BindIdentity(lastSkullBody, lastSkullMarker.unitId)
            end
            Record("skull_created", { ability = abilityId, target = targetId })
        end
    end
    if (abilityId == 117715 or (family == "bones" and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET)) and
            (result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE) then
        local key = sourceId and sourceId ~= 0 and "bb:" .. tostring(sourceId) or "bb-fallback"
        CT.ledger:Add("blastbones", Now(), CT.saved.bbTTL, nil,
            key, sourceId and sourceId ~= 0 and CT.saved.bbTTL or 0.25, sourceId)
        for tag, unitId in pairs(unitBindings) do
            if unitId == sourceId then UpdateBodyPosition(tag, unitId) end
        end
    end
end

local function EffectChanged(_, change, _, name, tag, beginTime, endTime, stacks,
        _, _, _, _, _, unitName, unitId, abilityId, sourceType)
    local rule = CT.saved.rules[tostring(abilityId)]
    local family = CT.AbilityFamily(abilityId)
    local yardEffect = CT.IsYardActivation(abilityId)
    if not watch[abilityId] and not family and not rule then return end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and tag:match("^playerpet%d+$") and
            type(unitId) == "number" and unitId > 0 then
        if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
            unitBindings[tag] = unitId
        end
        UpdateBodyPosition(tag, unitId)
    end
    if CT.saved.capture then
        Record("effect", { ability = abilityId, name = name, phase = phaseNames[change],
            tag = tag, beginTime = beginTime, endTime = endTime, stacks = stacks,
            unitName = unitName, unit = unitId, sourceType = sourceType })
    end
    if (family == "skeletal" or abilityId == 118681) and
            (tag == "player" or tag:match("^playerpet%d+$")) and
            sourceType == COMBAT_UNIT_TYPE_PLAYER then
        SummonChanged(abilityId, tag, unitId, change, beginTime, endTime)
    end
    if abilityId == 220102 and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            tag:match("^playerpet%d+$") and change == EFFECT_RESULT_GAINED then
        SkullIdentity(unitId)
        UpdateBodyPosition(tag, unitId)
    end
    if tag ~= "player" then return end
    if (abilityId == 263461 or abilityId == 263462) and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        WasteChanged(change, stacks, endTime)
    end
    if abilityId == 227113 then
        -- One pulse can GAIN(1), UPDATE(2), then FADE(2) in ~0.1 seconds.
        -- Record the latest raw value; FADE means pulse ended, NOT zero corpses.
        SampleBanner(stacks, "effect")
    end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then
        -- 117852 starts the Avid Yard self effect; it is not consumption proof.
        if (abilityId == 117852 or yardEffect) and change == EFFECT_RESULT_GAINED then ArmYard() end
        -- 117853 is an observed Yard marker. Its meaning needs a no-corpse test;
        -- require an independent consumption witness, never count it alone.
        if (abilityId == 117853 or yardEffect) and (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED) and
            pendingYard and Now() - pendingYard.at <= 0.8 then
            YardMarker()
        end
        if abilityId == 227068 and change == EFFECT_RESULT_GAINED then
            consumeWitness = { at = Now(), evidence = "Corpseburster proc effect" }
            FinishYard()
        end
    end
    if inCombat and (abilityId == 118764 or abilityId == 124003 or CT.IsSiphonApplication(abilityId)) and change == EFFECT_RESULT_GAINED and
            sourceType == COMBAT_UNIT_TYPE_PLAYER then
        -- A new self Siphon effect, not a tick and not a keypress. The physical
        -- corpse decrement is still an assumption if living-corpse effects exist.
        QueueSiphon()
        -- A Siphon application is another consumer, not proof for a prior Yard.
        consumeWitness = nil
    end
    if rule and phaseNames[change] == rule.phase and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        local key = "rule:" .. tostring(abilityId) .. ":" .. tostring(beginTime)
        if rule.kind == "create" then
            CT.ledger:Add("rule:" .. abilityId, Now(), rule.ttl, nil, key, rule.ttl)
        elseif rule.kind == "consume" then
            CT.ledger:Consume(rule.amount or 1, Now(), key, not CT.saved.physicalOnly)
        end
    end
end

local function SaveCombatSummary(reason)
    FlushSiphon(true)
    ExpireYard()
    CT.ledger:Expire(Now())
    local summary = { at = Now(), created = CT.ledger.created - combatBaseline.created,
        consumed = CT.ledger.consumed - combatBaseline.consumed,
        expired = CT.ledger.expired - combatBaseline.expired,
        unmatched = CT.ledger.unmatched - combatBaseline.unmatched,
        untrackedConsumed = CT.ledger.untrackedConsumed - combatBaseline.untrackedConsumed,
        remaining = #CT.ledger.bodies, carried = combatBaseline.remaining,
        yardConsumed = yardConsumed - combatBaseline.yardConsumed,
        yardUnconfirmed = yardUnconfirmed - combatBaseline.yardUnconfirmed,
        banner = rawBanner, sourceMode = CT.saved.sourceMode, addonVersion = CT.version,
        countMode = CT.saved.countMode, displayMode = CT.saved.displayMode, debugMode = CT.saved.debugMode,
        endedBy = reason }
    if CT.saved.capture and (summary.created > 0 or summary.consumed > 0 or not CT.saved.lastCombat) then
        CT.saved.lastCombat = summary
    end
    Record("combat_summary", summary)
    -- Include leading hits and out-of-combat events since the preceding summary.
    combatBaseline = { created = CT.ledger.created, consumed = CT.ledger.consumed,
        expired = CT.ledger.expired, unmatched = CT.ledger.unmatched,
        untrackedConsumed = CT.ledger.untrackedConsumed, remaining = #CT.ledger.bodies,
        yardConsumed = yardConsumed, yardUnconfirmed = yardUnconfirmed }
    return summary
end

local function Reset(reason)
    reason = reason or "manual"
    -- Activation can arrive before COMBAT_STATE(false). Archive the current
    -- segment before clearing it, so the following empty end cannot hide it.
    if inCombat then SaveCombatSummary("reset:" .. reason) end
    CT.ledger = CT.NewLedger(CT.saved.countMode)
    rawBanner, direct = nil, nil
    summons = {}
    pendingYard, consumeWitness = nil, nil
    lastSkullBody, lastSkullMarker = nil, nil
    pendingSiphon, lastSiphonAt = nil, -math.huge
    yardCasts, yardConsumed, yardUnconfirmed = 0, 0, 0
    combatBaseline = { created = 0, consumed = 0, expired = 0, unmatched = 0,
        untrackedConsumed = 0, remaining = 0, yardConsumed = 0, yardUnconfirmed = 0 }
    SeedWaste()
    unitStates, unitBindings = {}, {}
    -- Keep seen tags until UNIT_DESTROYED; resetting the ledger must not make
    -- an already observed corpse look newly created.
    Record("reset", { reason = reason })
end

local function DumpAPI(silent)
    -- ESO can reject even reading private function values while iterating _G.
    -- Use only the documented public version API; never inspect globals.
    local probe = { version = GetAPIVersion(), discovery = "disabled_private_api" }
    if CT.saved.capture then CT.saved.apiProbe = probe end
    if not silent then Say(CT.T("CHAT_API", probe.version)) end
    Record("api_probe", probe)
end

local function Slots(silent)
    for slot = 3, 8 do
        local id = GetSlotBoundId(slot)
        local row = { slot = slot, ability = id, name = GetSlotName(slot),
            usable = IsSlotUsable(slot), targetFailure = ActionSlotHasTargetFailure(slot),
            rangeFailure = ActionSlotHasRangeFailure(slot), costFailure = ActionSlotHasCostFailure(slot) }
        Record("slot", row)
        if not silent then Say(CT.T("CHAT_SLOT",
            slot, row.name, id, tostring(row.usable), tostring(row.targetFailure),
            tostring(row.rangeFailure), tostring(row.costFailure))) end
    end
end

function CT.ClearDiagnostics()
    CT.saved.capture = false
    CT.saved.log, rowSerial = {}, 0
    CT.saved.variants, CT.saved.apiProbe, CT.saved.lastCombat = nil, nil, nil
    CT.saved.diagnosticStartedAt = nil
    unitStates = {}
end

function CT.StartDiagnostics(reason, append)
    -- Begin a fresh recording without throwing away corpses already in play.
    -- Capture resumes append a new state snapshot; only a new test clears it.
    if not append then CT.ClearDiagnostics() end
    CT.saved.capture = true
    CT.saved.diagnosticStartedAt = Now()
    unitStates = {}
    CT.ledger:Expire(Now())
    combatBaseline = { created = CT.ledger.created, consumed = CT.ledger.consumed,
        expired = CT.ledger.expired, unmatched = CT.ledger.unmatched,
        untrackedConsumed = CT.ledger.untrackedConsumed, remaining = #CT.ledger.bodies,
        yardConsumed = yardConsumed, yardUnconfirmed = yardUnconfirmed }
    local bodies = {}
    for _, body in ipairs(CT.ledger.bodies) do
        bodies[#bodies + 1] = { id = body.id, unitId = body.unitId,
            source = body.source, created = body.created, expires = body.expires,
            position = body.position }
    end
    Record("diagnostic_start", { reason = reason or "manual", bodies = bodies,
        created = CT.ledger.created, consumed = CT.ledger.consumed,
        expired = CT.ledger.expired, untrackedConsumed = CT.ledger.untrackedConsumed,
        sourceMode = CT.saved.sourceMode, rangeMode = CT.saved.rangeMode,
        debugMode = CT.saved.debugMode, displayMode = CT.saved.displayMode, countMode = CT.saved.countMode })
    CT.DiscoverAbilities()
    CT.saved.variants = CT.variants
    Record("variants", { abilities = CT.variants })
    DumpAPI(true)
    Slots(true)
end

function CT.SetDebugMode(enabled)
    local previous = CT.saved.debugMode
    CT.saved.debugMode = enabled == true
    if CT.saved.debugMode ~= previous then
        Record("diagnostic_mode", { debugMode = CT.saved.debugMode })
    end
    CT.ApplySettings()
end

function CT.SetDisplayMode(mode)
    if mode ~= "compact" and mode ~= "detailed" then return end
    if mode == "detailed" and CT.saved.countMode == "light" then return end
    if CT.saved.displayMode ~= mode then Record("display_mode", { mode = mode }) end
    CT.saved.displayMode = mode
    CT.ApplySettings()
end

function CT.SetCountMode(mode)
    if mode ~= "light" and mode ~= "extended" then return end
    if CT.saved.countMode ~= mode then Record("count_mode", { mode = mode }) end
    CT.saved.countMode = mode
    CT.ApplySettings()
end

function CT.SetCapture(enabled)
    if enabled and not CT.saved.capture then
        CT.StartDiagnostics("capture_enabled", true)
    elseif not enabled then
        CT.saved.capture = false
        unitStates = {}
    end
    Refresh()
end

local function Command(text)
    if type(text) ~= "string" then return end
    local args = {}
    for a in text:gmatch("%S+") do args[#args + 1] = a end
    local cmd = args[1] or "help"
    if cmd == "settings" then
        if LibAddonMenu2 and CT.settingsPanel then LibAddonMenu2:OpenToPanel(CT.settingsPanel)
        else Say(CT.T("CHAT_DEPENDENCY")) end
    elseif cmd == "debug" then
        CT.SetDebugMode(args[2] == "on")
    elseif cmd == "view" then CT.SetDisplayMode(args[2])
    elseif cmd == "mode" then CT.SetCountMode(args[2])
    elseif cmd == "test" then
        CT.StartDiagnostics("new_test")
        CT.ApplySettings()
    elseif cmd == "capture" then
        CT.SetCapture(args[2] == "on")
        Say(CT.T("CHAT_CAPTURE", CT.T(CT.saved.capture and "ENABLED" or "DISABLED")))
    elseif cmd == "clearlog" then CT.saved.log = {}; Say(CT.T("CHAT_CLEARED"))
    elseif cmd == "reset" then Reset(); Say(CT.T("CHAT_RESET"))
    elseif cmd == "lock" or cmd == "unlock" then
        CT.saved.locked = cmd == "lock"
        CT.ApplySettings()
    elseif cmd == "radius" and tonumber(args[2]) and tonumber(args[2]) > 0 then
        CT.saved.radius = math.min(100, tonumber(args[2])); Say(CT.T("CHAT_RADIUS", CT.saved.radius))
    elseif cmd == "sources" then
        if args[2] and args[2] ~= "primary" and args[2] ~= "all" then
            Say("/crpst sources primary|all; /crpst sources"); return
        end
        CT.saved.sourceMode = args[2] or (CT.saved.sourceMode == "primary" and "all" or "primary")
        Record("source_mode", { mode = CT.saved.sourceMode })
        Say(CT.T("CHAT_SOURCES", CT.T(CT.saved.sourceMode == "primary" and "PRIMARY" or "ALL")))
        Refresh()
    elseif cmd == "ttl" and (args[2] == "bb" or args[2] == "archer" or args[2] == "banner" or args[2] == "skull") and
            tonumber(args[3]) and tonumber(args[3]) > 0 then
        CT.saved[args[2] .. "TTL"] = math.min(60, tonumber(args[3]))
        Say(CT.T("CHAT_TTL"))
    elseif cmd == "physical" then
        CT.saved.physicalOnly = args[2] == "on"
        Say(CT.T("CHAT_PHYSICAL", CT.T(CT.saved.physicalOnly and "ENABLED" or "AMBIGUOUS")))
    elseif cmd == "bannerunits" then
        CT.saved.bannerUnits = false
        Say(CT.T("BANNER_TIP"))
    elseif cmd == "probe" then DumpAPI()
    elseif cmd == "slots" then Slots()
    elseif cmd == "variants" then
        CT.DiscoverAbilities()
        if CT.saved.capture then CT.saved.variants = CT.variants end
        Record("variants", { abilities = CT.variants })
        Say(CT.T("CHAT_VARIANTS", #CT.variants))
    elseif cmd == "rule" and (args[2] == "create" or args[2] == "consume") and
            Finite(tonumber(args[3])) and tonumber(args[3]) > 0 and
            tonumber(args[3]) == math.floor(tonumber(args[3])) and
            (args[4] == "gained" or args[4] == "updated" or args[4] == "faded") and
            tonumber(args[5]) and tonumber(args[5]) > 0 and
            not watch[tonumber(args[3])] and not CT.AbilityFamily(tonumber(args[3])) then
        local id = tostring(math.floor(tonumber(args[3])))
        CT.saved.rules[id] = { kind = args[2], phase = args[4],
            ttl = math.max(1, math.min(60, tonumber(args[5]))),
            amount = math.max(1, math.min(10, math.floor(tonumber(args[5])))) }
        Say(CT.T("CHAT_RULE", id))
    elseif cmd == "unrule" and args[2] then CT.saved.rules[args[2]] = nil
    elseif cmd == "status" then
        local c = CurrentCount()
        Say("v" .. CT.version .. " | " .. CT.T("CHAT_STATUS1",
            CT.T(CT.saved.sourceMode == "primary" and "PRIMARY" or "ALL"), c.total, c.minimum, c.maximum,
            c.breakdown.bb, c.breakdown.skull, c.breakdown.other))
        Say(CT.T("CHAT_STATUS2",
            CT.ledger.created, CT.ledger.consumed, CT.ledger.untrackedConsumed,
            CT.ledger.expired, CT.ledger.unmatched,
            CT.ledger.guessed, #CT.saved.log))
        Say(CT.T("CHAT_STATUS3", yardCasts, yardConsumed, yardUnconfirmed))
    else
        Say(CT.T("COMMANDS"))
        Say("/crpst settings; view compact|detailed; mode light|extended; debug on|off; test; capture on|off; probe; slots; variants; reset; status; clearlog; lock|unlock")
        Say("/crpst sources primary|all; radius N; ttl bb|archer|banner|skull N; physical on|off")
        Say("/crpst rule create|consume ID gained|updated|faded TTL_OR_AMOUNT; unrule ID")
    end
end

local function Initialize(_, addonName)
    if addonName ~= CT.name then return end
    EM:UnregisterForEvent(CT.name, EVENT_ADD_ON_LOADED)
    CT.saved = ZO_SavedVars:NewAccountWide("CorpseTrackerSaved", 1, nil, defaults, GetWorldName())
    CT.DiscoverAbilities()
    NormalizeSaved()
    CT.saved.visible = nil -- Retire the old Show counter setting, including hidden profiles.
    if not CT.saved.ttlRevision then
        for name, ttl in pairs({ bbTTL = 5, skullTTL = 5, archerTTL = 10, bannerTTL = 5 }) do
            if CT.saved[name] == 6 then CT.saved[name] = ttl end
        end
        CT.saved.ttlRevision = 1
    end
    if CT.saved.sourceMode ~= "all" then CT.saved.sourceMode = "primary" end
    CT.saved.bannerUnits = false -- Name-based experimental adapter retired.
    -- Old compact profiles never supported explicit recording. Migrate them
    -- once, then preserve recordings independently of the display mode.
    if not CT.saved.captureRevision then
        if not CT.saved.debugMode then CT.ClearDiagnostics() end
        CT.saved.captureRevision = 1
    end
    if not CT.saved.displayRevision then
        CT.saved.displayMode = CT.saved.debugMode and "detailed" or "compact"
        CT.saved.debugMode, CT.saved.displayRevision = false, 1
    end
    if CT.saved.displayMode ~= "detailed" then CT.saved.displayMode = "compact" end
    if CT.saved.countMode ~= "extended" then CT.saved.countMode = "light" end
    if CT.saved.countMode == "light" then CT.saved.displayMode = "compact" end
    for _, row in ipairs(CT.saved.log) do
        local sequence = tonumber(row.sequence)
        if Finite(sequence) and sequence >= 0 and sequence <= 1e12 then
            rowSerial = math.max(rowSerial, math.floor(sequence))
        end
    end
    local resumeCapture = CT.saved.capture
    CT.saved.capture = false
    CT.SelectLanguage(CT.saved.language)
    CT.saved.addonVersion = CT.version
    CT.ledger = CT.NewLedger(CT.saved.countMode)
    SeedWaste()
    inCombat = IsUnitInCombat("player")
    frame = WINDOW_MANAGER:CreateControl("CorpseTrackerWindow", GuiRoot, CT_TOPLEVELCONTROL)
    frame:SetHidden(true)
    CT.hudFragment = ZO_SimpleSceneFragment:New(frame)
    CT.hudFragment:SetConditional(function() return true end)
    HUD_SCENE:AddFragment(CT.hudFragment)
    HUD_UI_SCENE:AddFragment(CT.hudFragment)
    frame:SetDimensions(660, 360)
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CT.saved.x, CT.saved.y)
    frame:SetMouseEnabled(not CT.saved.locked)
    frame:SetMovable(not CT.saved.locked)
    frame:SetClampedToScreen(true)
    frame:SetHandler("OnMoveStop", function(self)
        CT.saved.x, CT.saved.y = self:GetLeft(), self:GetTop()
    end)
    frame:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then Command("sources") end
    end)
    frame:SetHandler("OnMouseEnter", function(self)
        if not InformationTooltip or not InitializeTooltip then return end
        InitializeTooltip(InformationTooltip, self, RIGHT, 8, 0)
        InformationTooltip:AddLine("Corpse Tracker — " .. CT.T(CT.saved.countMode == "light" and "LIGHT" or "EXTENDED"))
        InformationTooltip:AddLine(CT.T(CT.saved.sourceMode == "primary" and "PRIMARY" or "ALL"))
        InformationTooltip:AddLine(CT.T("TOOLTIP_HINT"))
    end)
    frame:SetHandler("OnMouseExit", function()
        if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end
    end)
    background = WINDOW_MANAGER:CreateControl("CorpseTrackerBackground", frame, CT_BACKDROP)
    background:SetAnchorFill(frame)
    background:SetCenterColor(0.02, 0.02, 0.02, 0.8)
    background:SetEdgeColor(0.65, 0.75, 0.7, 1)
    background:SetEdgeTexture("", 1, 1, 0, 0)
    background:SetMouseEnabled(false)
    background:SetDrawLayer(DL_BACKGROUND)
    icon = WINDOW_MANAGER:CreateControl("CorpseTrackerIcon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 3)
    -- Custom corpse artwork; this texture is cosmetic only.
    icon:SetTexture("CorpseTracker/Textures/corpse.dds")
    icon:SetAlpha(0.55)
    icon:SetDrawLayer(DL_CONTROLS)
    icon:SetMouseEnabled(false)
    label = WINDOW_MANAGER:CreateControl("CorpseTrackerText", frame, CT_LABEL)
    label:SetDrawLayer(DL_TEXT)
    label:SetMouseEnabled(false)
    label:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    label:SetDimensions(660, 326)
    label:SetFont("ZoFontGame")
    label:SetColor(0.8, 1, 0.9, 1)
    timer = WINDOW_MANAGER:CreateControl("CorpseTrackerTimer", frame, CT_LABEL)
    timer:SetDrawLayer(DL_TEXT)
    timer:SetMouseEnabled(false)
    timer:SetHidden(true)
    question = WINDOW_MANAGER:CreateControl("CorpseTrackerQuestion", frame, CT_LABEL)
    question:SetDrawLayer(DL_TEXT)
    question:SetMouseEnabled(false)
    question:SetHidden(true)
    sourceButton = WINDOW_MANAGER:CreateControl("CorpseTrackerSources", frame, CT_BUTTON)
    sourceButton:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 326)
    sourceButton:SetDimensions(660, 26)
    sourceButton:SetFont("ZoFontGame")
    sourceButton:SetMouseEnabled(true)
    sourceButton:SetNormalFontColor(0.8, 1, 0.9, 1)
    sourceButton:SetMouseOverFontColor(1, 1, 1, 1)
    sourceButton:SetPressedFontColor(0.8, 1, 0.9, 1)
    sourceButton:SetEnabled(true)
    sourceButton:SetHandler("OnClicked", function() Command("sources") end)
    frame:SetHandler("OnShow", function() Refresh() end)
    EM:RegisterForEvent(CT.name, EVENT_COMBAT_EVENT, CombatEvent)
    EM:RegisterForEvent(CT.name, EVENT_EFFECT_CHANGED, EffectChanged)
    EM:RegisterForEvent(CT.name, EVENT_PLAYER_COMBAT_STATE, function(_, active)
        if active == inCombat then return end
        inCombat = active
        Record("combat_state", { active = active })
        if not active then
            SaveCombatSummary("combat_end")
        end
    end)
    EM:RegisterForEvent(CT.name, EVENT_PLAYER_ACTIVATED, function()
        Reset("player_activated"); CT.DiscoverAbilities(); knownUnits = {}; inCombat = IsUnitInCombat("player")
    end)
    EM:RegisterForEvent(CT.name, EVENT_UNIT_CREATED, function(_, tag)
        knownUnits[tag] = true; unitStates[tag] = nil; unitBindings[tag] = nil; InspectUnit(tag)
    end)
    EM:RegisterForEvent(CT.name, EVENT_UNIT_DESTROYED, function(_, tag)
        Record("unit_destroyed", { tag = tag })
        knownUnits[tag], unitStates[tag], unitBindings[tag] = nil, nil, nil
    end)
    EM:RegisterForEvent(CT.name, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, tag)
        knownUnits[tag] = true; InspectUnit(tag)
    end)
    EM:RegisterForEvent(CT.name, EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
        local id = GetSlotBoundId(slot)
        Record("skill_used", { slot = slot, ability = id })
        if id == 117850 or CT.AbilityFamily(id) == "yard" then ArmYard() end
    end)
    EM:RegisterForUpdate(CT.name, 200, function()
        if CT.saved.countMode == "extended" and CT.saved.rangeMode ~= "none" then
            for tag, unitId in pairs(unitBindings) do
                if DoesUnitExist(tag) then UpdateBodyPosition(tag, unitId)
                else unitBindings[tag] = nil end
            end
        end
        if CT.saved.capture and CT.saved.debugMode then
            InspectUnit("reticleover")
            for tag in pairs(knownUnits) do InspectUnit(tag) end
        end
        Refresh()
    end)
    SLASH_COMMANDS["/crpst"] = Command
    CT.ApplySettings()
    CT.RegisterSettings()
    if resumeCapture then CT.StartDiagnostics("reload", true); Refresh() end
end

EM:RegisterForEvent(CT.name, EVENT_ADD_ON_LOADED, Initialize)
