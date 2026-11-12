local ADDON = "ESOCombatWatch"
local LARGE_HIT = 20000
local REPEAT_COUNT = 5
local REPEAT_WINDOW_MS = 750
local MIN_SPREAD_MS = 150
local ALERT_COOLDOWN_MS = 5000
local ALERT_VISIBLE_MS = 9000
local HISTORY_LIMIT = 10
local TRACK_LIMIT = 128

local tracks, history = {}, {}
local trackCount, lastSweep, alertUntil = 0, 0, 0
local panel, label

local function CleanText(value, fallback)
    if not value or value == "" then return fallback end
    local cleaned = value:gsub("%^.*$", ""):gsub("|", ""):gsub("%c", " ")
    if cleaned == "" then return fallback end
    return cleaned
end

local function Alert(now, details)
    local line = GetTimeString() .. "  " .. details
    history[#history + 1] = line
    if #history > HISTORY_LIMIT then table.remove(history, 1) end

    label:SetText("ESO Combat Watch  |  Review only\n" .. line)
    panel:SetHidden(false)
    alertUntil = now + ALERT_VISIBLE_MS
end

local function FindTrack(sourceId, abilityId, now)
    if now - lastSweep >= 1000 then
        for key, track in pairs(tracks) do
            if now - track.lastSeen >= ALERT_COOLDOWN_MS then
                tracks[key] = nil
                trackCount = trackCount - 1
            end
        end
        lastSweep = now
    end

    local key = sourceId .. ":" .. abilityId
    local track = tracks[key]
    if not track and trackCount < TRACK_LIMIT then
        track = { times = {}, nextAlert = 0 }
        tracks[key] = track
        trackCount = trackCount + 1
    end
    if track then track.lastSeen = now end
    return track
end

local function OnCombatEvent(_, result, isError, abilityName, _, _, sourceName,
    sourceType, _, targetType, hitValue, _, _, _, sourceId, _, abilityId)
    if isError or sourceType ~= COMBAT_UNIT_TYPE_OTHER
        or targetType ~= COMBAT_UNIT_TYPE_PLAYER
        or (result ~= ACTION_RESULT_DAMAGE and result ~= ACTION_RESULT_CRITICAL_DAMAGE)
        or not hitValue or hitValue <= 0
        or not sourceId or sourceId <= 0 or not abilityId or abilityId <= 0 then
        return
    end

    local now = GetFrameTimeMilliseconds()
    local track = FindTrack(sourceId, abilityId, now)
    if not track then return end

    local times = track.times
    while times[1] and now - times[1] > REPEAT_WINDOW_MS do
        table.remove(times, 1)
    end
    times[#times + 1] = now
    if #times > REPEAT_COUNT then table.remove(times, 1) end

    if now < track.nextAlert then return end

    local span = now - times[1]
    local details
    if #times == REPEAT_COUNT and span >= MIN_SPREAD_MS then
        details = string.format("%d same-ability hits in %d ms (latest %d damage)",
            REPEAT_COUNT, span, hitValue)
    elseif hitValue >= LARGE_HIT then
        details = string.format("Large hit: %d damage", hitValue)
    end
    if not details then return end

    track.nextAlert = now + ALERT_COOLDOWN_MS
    Alert(now, string.format("%s\n%s / %s (#%d)", details,
        CleanText(sourceName, "Unknown player"), CleanText(abilityName, "Unknown ability"),
        abilityId))
end

local function ShowHistory()
    if #history == 0 then
        d("ESO Combat Watch: No review flags this session.")
        return
    end
    for _, line in ipairs(history) do
        d("ESO Combat Watch: " .. line:gsub("\n", " | "))
    end
end

local function OnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    panel = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "Alert")
    panel:SetDimensions(640, 84)
    panel:SetAnchor(TOP, GuiRoot, TOP, 0, 120)
    panel:SetHidden(true)

    label = WINDOW_MANAGER:CreateControl(ADDON .. "AlertText", panel, CT_LABEL)
    label:SetAnchorFill(panel)
    label:SetFont("ZoFontWinH4")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 0.86, 0.55, 1)

    panel:SetHandler("OnUpdate", function()
        if GetFrameTimeMilliseconds() >= alertUntil then panel:SetHidden(true) end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_COMBAT_EVENT, OnCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, function()
        tracks, trackCount, lastSweep = {}, 0, 0
        panel:SetHidden(true)
    end)

    if SLASH_COMMANDS and d then SLASH_COMMANDS["/combatwatch"] = ShowHistory end
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)
