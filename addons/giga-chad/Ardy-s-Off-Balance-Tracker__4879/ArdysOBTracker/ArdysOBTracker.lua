--[[
    Ardy's OB Tracker
    -----------------
    1) Crosshair auto-marker
       When the enemy under your crosshair is Off Balance from YOU and is within
       range (default 8 m), it gets the next free in-game target marker (up to 8).
       When you look at a marked enemy whose Off Balance has ended, the marker is
       removed. Expired markers are also recycled: when a new enemy needs a
       marker, an expired one is reassigned (which moves it off the old enemy).

    2) Off Balance tracker window
       Lists every enemy you have put Off Balance, with a countdown, up to 8 rows.

    API limits (why it works this way):
      * AssignTargetMarkerToReticleTarget() only acts on the crosshair target and
        it TOGGLES (same marker on same target = removed).
      * Nearby enemies have no unit tags, so range can only be measured for the
        crosshair target.

    Slash command: /obt   (type it alone for help)
]]

ArdysOBTracker = ArdysOBTracker or {}
local OBM = ArdysOBTracker

OBM.name    = "ArdysOBTracker"
OBM.title   = "|c9B30FFArdy's OB Tracker|r"
OBM.version = "1.5.0"

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

local DRAGONKNIGHT_CLASS_ID = 1
local UPDATE_INTERVAL_MS    = 100   -- how often the marker/tracker logic runs
local ACTION_COOLDOWN_MS    = 400   -- wait between marker changes so the server can catch up
local MAX_ROWS              = 8
local RETICLE               = "reticleover"
local MARKER_NONE           = TARGET_MARKER_TYPE_NONE
local DEFAULT_OB_SECONDS    = 7     -- used only if the game doesn't report a duration
local PVP_CHECK_MS          = 1000  -- how often to re-check whether you're in PvP
local IMMUNITY_SECONDS      = 15    -- Off Balance Immunity after Off Balance ends
local OB_IMMUNITY_ABILITY_ID = 102771
local SYNC_TIMEOUT_MS       = 1500  -- max wait for the game to confirm a marker change
local RETRY_WAIT_MS         = 1000  -- wait between removal retries if the game never confirms
local MAX_REMOVE_ATTEMPTS   = 5
local ACCIDENT_WINDOW_MS    = 3000  -- our marker seen on a groupmate this soon after placing = accident
local EXPIRING_WARN_SECONDS = 1.5   -- "Off Balance about to end" warning
local SOUND_THROTTLE_MS     = 700

-- Sounds offered for alerts (key in the game's SOUNDS table -> label)
local ALERT_SOUNDS = {
    { key = "DUEL_START",         label = "Duel start" },
    { key = "COUNTDOWN_TICK",     label = "Countdown tick" },
    { key = "NEW_NOTIFICATION",   label = "Notification" },
    { key = "QUEST_FOCUSED",      label = "Quest focused" },
    { key = "ABILITY_READY",      label = "Ability ready" },
}

-- Order markers are handed out in
local MARKER_ORDER = {
    TARGET_MARKER_TYPE_ONE,
    TARGET_MARKER_TYPE_TWO,
    TARGET_MARKER_TYPE_THREE,
    TARGET_MARKER_TYPE_FOUR,
    TARGET_MARKER_TYPE_FIVE,
    TARGET_MARKER_TYPE_SIX,
    TARGET_MARKER_TYPE_SEVEN,
    TARGET_MARKER_TYPE_EIGHT,
}

local defaults = {
    enabled          = true,
    dragonknightOnly = true,
    markersEnabled   = true,
    maxMarkers       = 8,
    rangeMeters      = 8,
    allowInGroup     = true,
    pvpOnly          = false,
    markIfRangeUnknown = true,
    removeFromFriendlies = true,
    holdMs           = 300,
    trackImmunity    = true,
    fontSize         = 16,
    highlightTarget  = true,
    crosshairEnabled = true,
    crosshairShowReady = true,
    crosshairSize    = 22,
    crosshairX       = 0,
    crosshairY       = 80,
    alertReady       = true,
    alertReadySound  = "DUEL_START",
    alertExpiring    = false,
    alertExpiringSound = "COUNTDOWN_TICK",
    trackerEnabled   = true,
    trackerLocked    = false,
    trackerHideEmpty = true,
    trackerX         = nil,
    trackerY         = nil,
    debug            = false,
}

-- Runtime state
OBM.slots   = {}  -- [markerType] = { expires = frameSeconds, name = string }
OBM.tracked = {}  -- [unitId]     = { name = string, endTime = frameSeconds }
local lastActionMs = 0
local inPvP, lastPvPCheckMs = false, -PVP_CHECK_MS

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    d("|c9B30FF[OB Tracker]|r " .. msg)
end

local function Debug(fmt, ...)
    if OBM.sv and OBM.sv.debug then Print(fmt, ...) end
end

local function IsDragonknight()
    return GetUnitClassId("player") == DRAGONKNIGHT_CLASS_ID
end

-- Off Balance detection. Uses the effect's ability type first, falls back to
-- the English name. "Off Balance Immunity" is always excluded.
local function IsOffBalance(effectName, abilityType)
    local lower = effectName and zo_strlower(effectName) or ""
    if lower:find("immun", 1, true) then return false end
    if abilityType == ABILITY_TYPE_OFFBALANCE then return true end
    return lower:find("off[%s%-]?balance") ~= nil
end

-- Battle Spirit is on you in Cyrodiil, Imperial City and battlegrounds.
local function HasBattleSpirit()
    for i = 1, GetNumBuffs("player") do
        local name = GetUnitBuffInfo("player", i)
        if name and zo_strlower(name):find("battle spirit", 1, true) then return true end
    end
    return false
end

local function IsInPvP()
    local nowMs = GetGameTimeMilliseconds()
    if nowMs - lastPvPCheckMs >= PVP_CHECK_MS then
        lastPvPCheckMs = nowMs
        inPvP = IsInAvAZone() or IsActiveWorldBattleground() or HasBattleSpirit()
    end
    return inPvP
end

local function IsOffBalanceImmunity(effectName, abilityId)
    if abilityId == OB_IMMUNITY_ABILITY_ID then return true end
    local lower = effectName and zo_strlower(effectName) or ""
    return lower:find("immun", 1, true) ~= nil and lower:find("balance", 1, true) ~= nil
end

local function IsActive()
    local sv = OBM.sv
    if not sv.enabled then return false end
    if sv.dragonknightOnly and not IsDragonknight() then return false end
    if sv.pvpOnly and not IsInPvP() then return false end
    return true
end

-- Reactions that are never an enemy.
local FRIENDLY_REACTIONS = {
    [UNIT_REACTION_FRIENDLY]    = true,
    [UNIT_REACTION_PLAYER_ALLY] = true,
    [UNIT_REACTION_NPC_ALLY]    = true,
    [UNIT_REACTION_COMPANION]   = true,
}

local function IsReticleGroupMember()
    if not IsUnitGrouped("player") then return false end
    for i = 1, GetGroupSize() do
        if AreUnitsEqual(RETICLE, GetGroupUnitTagByIndex(i)) then return true end
    end
    return false
end

-- Any sign at all that the crosshair target is on your side.
local function IsReticleFriendly()
    if AreUnitsEqual(RETICLE, "player") then return true end
    if FRIENDLY_REACTIONS[GetUnitReaction(RETICLE)] then return true end
    if IsReticleGroupMember() or IsUnitFriendlyFollower(RETICLE) then return true end
    -- Cyrodiil / Imperial City: a player of your own alliance is friendly.
    -- (Not used in battlegrounds, where teams ignore alliance.)
    if IsUnitPlayer(RETICLE) and IsInAvAZone() and not IsActiveWorldBattleground()
        and GetUnitAlliance(RETICLE) == GetUnitAlliance("player") then
        return true
    end
    return false
end

-- Must be attackable AND show no friendly sign. Enemy players in Cyrodiil /
-- battlegrounds are not always reported as UNIT_REACTION_HOSTILE, so the
-- game's own "can attack" test is what decides.
local function IsReticleEnemy()
    if not DoesUnitExist(RETICLE) or IsUnitDead(RETICLE) then return false end
    if not IsUnitAttackable(RETICLE) then return false end
    if GetUnitReaction(RETICLE) == UNIT_REACTION_NEUTRAL then return false end
    return not IsReticleFriendly()
end

local function MarkersAllowedNow()
    local sv = OBM.sv
    if not sv.markersEnabled then return false end
    if IsUnitGrouped("player") and not sv.allowInGroup then return false end
    return true
end

-- Returns the time (frame seconds) your Off Balance on the crosshair target
-- ends, or nil if it has none from you.
local function GetMyOffBalanceEndOnReticle(now)
    local best
    for i = 1, GetNumBuffs(RETICLE) do
        local name, _, timeEnding, _, _, _, _, _, abilityType, _, _, _, castByPlayer = GetUnitBuffInfo(RETICLE, i)
        if castByPlayer and timeEnding and timeEnding > now and IsOffBalance(name, abilityType) then
            if not best or timeEnding > best then best = timeEnding end
        end
    end
    return best
end

-- Distance in meters from you to the crosshair target (world units are cm).
local function GetReticleDistanceMeters()
    local _, px, py, pz = GetUnitRawWorldPosition("player")
    local _, tx, ty, tz = GetUnitRawWorldPosition(RETICLE)
    if not tx or (tx == 0 and ty == 0 and tz == 0) then return nil end
    local dx, dy, dz = tx - px, ty - py, tz - pz
    return math.sqrt(dx * dx + dy * dy + dz * dz) / 100
end

local function FormatName(name)
    return (name and name ~= "") and zo_strformat(SI_UNIT_NAME, name) or ""
end

-- Off Balance and immunity on the crosshair target, applied by anyone.
local function GetReticleOBState(now)
    local obEnd, immEnd
    for i = 1, GetNumBuffs(RETICLE) do
        local name, _, timeEnding, _, _, _, _, _, abilityType, _, abilityId = GetUnitBuffInfo(RETICLE, i)
        if timeEnding and timeEnding > now then
            if IsOffBalanceImmunity(name, abilityId) then
                immEnd = math.max(immEnd or 0, timeEnding)
            elseif IsOffBalance(name, abilityType) then
                obEnd = math.max(obEnd or 0, timeEnding)
            end
        end
    end
    return obEnd, immEnd
end

-- Our own record for an enemy, matched by name (only if the name is unique).
local function FindTrackedByName(name)
    if name == "" then return nil end
    local found
    for _, info in pairs(OBM.tracked) do
        if info.name == name then
            if found then return nil end
            found = info
        end
    end
    return found
end

local lastSoundMs = {}
local function PlayAlert(soundKey)
    local nowMs = GetGameTimeMilliseconds()
    if lastSoundMs[soundKey] and nowMs - lastSoundMs[soundKey] < SOUND_THROTTLE_MS then return end
    lastSoundMs[soundKey] = nowMs
    local sound = SOUNDS and SOUNDS[soundKey]
    if sound then PlaySound(sound) end
end

local function IsOurMarker(markerType)
    return markerType ~= MARKER_NONE and OBM.slots[markerType] ~= nil
end

-- Identifies "the same unit" across ticks (unit name + @account for players).
local function ReticleKey()
    return GetUnitName(RETICLE) .. "|" .. (GetUnitDisplayName(RETICLE) or "")
end

-- Markers someone else placed on a boss or group member are left alone.
local function GetForeignMarkersInUse()
    local used = {}
    local function check(tag)
        if DoesUnitExist(tag) then
            local m = GetUnitTargetMarkerType(tag)
            if m ~= MARKER_NONE and not OBM.slots[m] then used[m] = true end
        end
    end
    for i = 1, BOSS_RANK_ITERATION_END or 12 do check("boss" .. i) end
    if IsUnitGrouped("player") then
        for i = 1, GetGroupSize() do check(GetGroupUnitTagByIndex(i)) end
    end
    check("player")
    return used
end

-- Marker order of preference:
--   1) one of ours stuck on a friendly (reassigning it pulls it off them)
--   2) never used   3) expired (recycled)
local function FindFreeMarker(now)
    local foreign = GetForeignMarkersInUse()
    local limit = zo_clamp(OBM.sv.maxMarkers, 1, #MARKER_ORDER)
    local unused, recycled
    for i = 1, limit do
        local m = MARKER_ORDER[i]
        if not foreign[m] then
            local slot = OBM.slots[m]
            if slot and slot.onFriendly then return m end
            if not slot then
                unused = unused or m
            elseif slot.expires <= now then
                recycled = recycled or m
            end
        end
    end
    return unused or recycled
end

---------------------------------------------------------------------------
-- Marker state sync
-- Marker changes go through the server. In big fights the confirmation can
-- lag, and acting on stale state is what causes double toggles. After every
-- change we wait for EVENT_TARGET_MARKER_UPDATE (or a timeout) before acting.
---------------------------------------------------------------------------

local markerEventSeen  = false  -- has the game confirmed one of our changes yet?
local waitingForUpdate = false

local function NoteMarkerAction(nowMs)
    lastActionMs = nowMs
    waitingForUpdate = true
end

local function OnTargetMarkerUpdate()
    if waitingForUpdate then markerEventSeen = true end
    waitingForUpdate = false
end

local function MarkerStateReady(nowMs)
    local elapsed = nowMs - lastActionMs
    if elapsed < ACTION_COOLDOWN_MS then return false end
    if waitingForUpdate and markerEventSeen and elapsed < SYNC_TIMEOUT_MS then return false end
    return true
end

-- If our marker shows up on a groupmate right after we placed it, it was an
-- accident: flag it so it is moved to the next enemy or removed on sight.
-- If it shows up there later, someone moved it on purpose: hands off.
local function ScanGroupForOurMarkers(nowMs)
    local function check(tag)
        if not DoesUnitExist(tag) then return end
        local m = GetUnitTargetMarkerType(tag)
        local slot = OBM.slots[m]
        if slot and not slot.onFriendly then
            if nowMs - (slot.placedMs or 0) <= ACCIDENT_WINDOW_MS then
                slot.onFriendly = true
                Print("Marker %d landed on %s by mistake. It will be moved to your next target, or removed when you look at them.",
                    m, GetUnitName(tag))
            else
                OBM.slots[m] = nil
            end
        end
    end
    check("player")
    if IsUnitGrouped("player") then
        for i = 1, GetGroupSize() do check(GetGroupUnitTagByIndex(i)) end
    end
end

---------------------------------------------------------------------------
-- 1) Crosshair auto-marker
---------------------------------------------------------------------------

local candidate  -- { key, sinceMs }  enemy the crosshair is holding on
local pending    -- { marker, key, attempts, lastMs }  removal being confirmed

local function StartRemoval(m, key, onFriendly, nowMs)
    AssignTargetMarkerToReticleTarget(m) -- same marker on same target = off
    local slot = OBM.slots[m]
    if slot and onFriendly then slot.onFriendly = true end
    pending = { marker = m, key = key, attempts = 1, lastMs = nowMs }
    NoteMarkerAction(nowMs)
end

-- Returns true if it took an action this tick.
local function HandlePendingRemoval(nowMs, key, current)
    if not pending then return false end
    if pending.key ~= key then
        -- Looked away before we could confirm. The slot stays ours (and
        -- flagged if friendly), so it is retried on sight or reassigned.
        pending = nil
        return false
    end
    if current ~= pending.marker then
        OBM.slots[pending.marker] = nil -- confirmed gone
        Debug("Removal of marker %d confirmed", pending.marker)
        pending = nil
        return false
    end
    if pending.attempts >= MAX_REMOVE_ATTEMPTS then
        Print("Couldn't remove marker %d from %s. Use your keybind or /obt clear.", current, GetUnitName(RETICLE))
        pending = nil
        return false
    end
    if not markerEventSeen and nowMs - pending.lastMs < RETRY_WAIT_MS then return true end
    AssignTargetMarkerToReticleTarget(current)
    pending.attempts, pending.lastMs = pending.attempts + 1, nowMs
    NoteMarkerAction(nowMs)
    Debug("Retrying removal of marker %d (attempt %d)", current, pending.attempts)
    return true
end

local function MarkerTick(nowMs, now)
    if not MarkersAllowedNow() then candidate = nil; return end
    ScanGroupForOurMarkers(nowMs)
    if not MarkerStateReady(nowMs) then candidate = nil; return end
    if not DoesUnitExist(RETICLE) then candidate = nil; return end

    local key = ReticleKey()
    local current = GetUnitTargetMarkerType(RETICLE)

    if HandlePendingRemoval(nowMs, key, current) then return end

    -- Safety net: one of OUR markers on a friendly comes off, with retries.
    if IsOurMarker(current) and OBM.sv.removeFromFriendlies and IsReticleFriendly() then
        candidate = nil
        StartRemoval(current, key, true, nowMs)
        Print("Removing marker %d from friendly %s.", current, GetUnitName(RETICLE))
        return
    end

    if not IsReticleEnemy() then candidate = nil; return end
    local obEnd = GetMyOffBalanceEndOnReticle(now)

    if obEnd then
        if current == MARKER_NONE then
            local dist = GetReticleDistanceMeters()
            local inRange
            if dist then
                inRange = dist <= OBM.sv.rangeMeters
            else
                -- Some targets (e.g. enemy players) may not report a position.
                inRange = OBM.sv.markIfRangeUnknown
            end
            if not inRange then candidate = nil; return end

            -- The crosshair must stay on this enemy for the hold time, so a
            -- quick sweep across a crowd can't send a marker to the wrong unit.
            if not candidate or candidate.key ~= key then
                candidate = { key = key, sinceMs = nowMs }
            end
            if nowMs - candidate.sinceMs < OBM.sv.holdMs then return end

            local m = FindFreeMarker(now)
            -- Re-check right before placing, in the same frame.
            if m and IsReticleEnemy() and ReticleKey() == key and GetUnitTargetMarkerType(RETICLE) == MARKER_NONE then
                AssignTargetMarkerToReticleTarget(m)
                OBM.slots[m] = { expires = obEnd, name = GetUnitName(RETICLE), key = key, placedMs = nowMs }
                NoteMarkerAction(nowMs)
                candidate = nil
                Debug("Marked %s with marker %d (%s)", GetUnitName(RETICLE), m,
                    dist and string.format("%.1f m", dist) or "range unknown")
            end
        else
            candidate = nil
            if IsOurMarker(current) then
                OBM.slots[current].expires = obEnd -- Off Balance refreshed
            end
        end
    else
        candidate = nil
        if IsOurMarker(current) then
            -- Off Balance is gone: take the marker off (confirmed + retried).
            StartRemoval(current, key, false, nowMs)
            Debug("Removing marker %d from %s", current, GetUnitName(RETICLE))
        end
    end
end

-- Manual removal (keybind and /obt clear). Works on any marker.
function OBM.ClearReticleMarker()
    if not DoesUnitExist(RETICLE) then return end
    local m = GetUnitTargetMarkerType(RETICLE)
    if m == MARKER_NONE then
        Print("Crosshair target has no marker.")
        return
    end
    local nowMs = GetGameTimeMilliseconds()
    if OBM.slots[m] then
        StartRemoval(m, ReticleKey(), false, nowMs)
    else
        AssignTargetMarkerToReticleTarget(m)
        NoteMarkerAction(nowMs)
    end
    Print("Removed marker %d.", m)
end

function OBM.ToggleMarkers()
    OBM.sv.markersEnabled = not OBM.sv.markersEnabled
    Print("Auto-marking %s.", OBM.sv.markersEnabled and "ON" or "OFF")
end

---------------------------------------------------------------------------
-- 2) Tracker window
---------------------------------------------------------------------------

local tracker = {}
local ApplyReticleLayout -- defined with the crosshair readout below

local function SaveTrackerPosition(control)
    OBM.sv.trackerX, OBM.sv.trackerY = control:GetLeft(), control:GetTop()
end

local function ApplyTrackerLock()
    if tracker.tlw then
        tracker.tlw:SetMovable(not OBM.sv.trackerLocked)
        tracker.tlw:SetMouseEnabled(not OBM.sv.trackerLocked)
    end
    if ApplyReticleLayout then ApplyReticleLayout() end
end

local MIN_FONT, MAX_FONT = 12, 36

-- Sizes everything in the window from the chosen text size.
local function ApplyTrackerLayout()
    if not tracker.tlw then return end
    local size   = zo_clamp(OBM.sv.fontSize or 16, MIN_FONT, MAX_FONT)
    local rowH   = size + 6
    local titleH = size + 10
    local pad    = math.floor(size / 2)
    local timeW  = size * 4
    local width  = math.max(200, size * 16)

    local rowFont   = string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", size)
    local titleFont = string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size + 2)

    tracker.tlw:SetDimensions(width, titleH + rowH * MAX_ROWS + pad)

    tracker.title:SetFont(titleFont)
    tracker.title:ClearAnchors()
    tracker.title:SetAnchor(TOPLEFT, tracker.root, TOPLEFT, pad, 4)

    for i, row in ipairs(tracker.rows) do
        local y = titleH + (i - 1) * rowH
        row.name:SetFont(rowFont)
        row.name:ClearAnchors()
        row.name:SetAnchor(TOPLEFT, tracker.root, TOPLEFT, pad, y)
        row.name:SetDimensions(width - timeW - pad * 3, rowH)

        row.time:SetFont(rowFont)
        row.time:ClearAnchors()
        row.time:SetAnchor(TOPRIGHT, tracker.root, TOPRIGHT, -pad, y)
        row.time:SetDimensions(timeW, rowH)
    end
end

local function SetFontSize(size)
    OBM.sv.fontSize = zo_clamp(math.floor(size), MIN_FONT, MAX_FONT)
    ApplyTrackerLayout()
end

local function CreateTracker()
    local tlw = WM:CreateTopLevelWindow("ArdysOBTrackerWindow")
    tlw:SetClampedToScreen(true)
    tlw:ClearAnchors()
    if OBM.sv.trackerX and OBM.sv.trackerY then
        tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, OBM.sv.trackerX, OBM.sv.trackerY)
    else
        tlw:SetAnchor(CENTER, GuiRoot, CENTER, 300, -150)
    end
    tlw:SetHandler("OnMoveStop", SaveTrackerPosition)

    local root = WM:CreateControl("$(parent)Root", tlw, CT_CONTROL)
    root:SetAnchorFill(tlw)

    local bg = WM:CreateControlFromVirtual("$(parent)BG", root, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(root)
    bg:SetAlpha(0.7)

    local title = WM:CreateControl("$(parent)Title", root, CT_LABEL)
    title:SetColor(0.61, 0.19, 1, 1)
    title:SetText("Ardy's OB Tracker")

    tracker.rows = {}
    for i = 1, MAX_ROWS do
        local nameLabel = WM:CreateControl("$(parent)Name" .. i, root, CT_LABEL)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        local timeLabel = WM:CreateControl("$(parent)Time" .. i, root, CT_LABEL)
        timeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        tracker.rows[i] = { name = nameLabel, time = timeLabel }
    end

    -- Show only on the HUD (hidden in menus, map, etc.)
    local fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    tracker.tlw, tracker.root, tracker.title = tlw, root, title
    ApplyTrackerLayout()
    ApplyTrackerLock()
end

local function TrackerTick(now)
    local sv = OBM.sv
    local list = {}
    local playReady, playExpiring = false, false
    for unitId, info in pairs(OBM.tracked) do
        -- Off Balance ended: switch to immunity (or drop the row).
        if not info.immune and info.endTime <= now then
            if sv.trackImmunity then
                info.immune, info.endTime = true, info.endTime + IMMUNITY_SECONDS
            else
                info.endTime = 0
            end
        end
        local remaining = info.endTime - now
        if remaining <= 0 then
            -- Immunity ran out (not a death - deaths are removed elsewhere).
            if info.immune then playReady = true end
            OBM.tracked[unitId] = nil
        else
            if not info.immune and not info.warned and remaining <= EXPIRING_WARN_SECONDS then
                info.warned = true
                playExpiring = true
            end
            list[#list + 1] = { name = info.name, remaining = remaining, immune = info.immune }
        end
    end
    if playReady and sv.alertReady and sv.trackImmunity then PlayAlert(sv.alertReadySound) end
    if playExpiring and sv.alertExpiring then PlayAlert(sv.alertExpiringSound) end
    -- Off Balance rows first, then immunity rows; soonest to expire on top.
    table.sort(list, function(a, b)
        if a.immune ~= b.immune then return not a.immune end
        return a.remaining < b.remaining
    end)

    if not tracker.root then return end
    local show = IsActive() and sv.trackerEnabled
        and (#list > 0 or not sv.trackerHideEmpty or not sv.trackerLocked)
    tracker.root:SetHidden(not show)
    if not show then return end

    -- Enemy under the crosshair gets its row highlighted.
    local targetName
    if sv.highlightTarget and DoesUnitExist(RETICLE) and IsReticleEnemy() then
        targetName = FormatName(GetUnitName(RETICLE))
    end

    for i = 1, MAX_ROWS do
        local row, entry = tracker.rows[i], list[i]
        local isTarget = entry and targetName and entry.name == targetName
        if entry and entry.immune then
            if isTarget then
                row.name:SetText("|cB8A050» " .. entry.name .. "|r")
            else
                row.name:SetText("|c888888" .. entry.name .. "|r")
            end
            row.time:SetText(string.format("imm %ds", math.ceil(entry.remaining)))
            row.time:SetColor(0.6, 0.6, 0.6, 1)
        elseif entry then
            if isTarget then
                row.name:SetText("|cFFD700» " .. entry.name .. "|r")
            else
                row.name:SetText(entry.name)
            end
            row.time:SetText(string.format("%.1fs", entry.remaining))
            if entry.remaining < 2 then
                row.time:SetColor(1, 0.35, 0.2, 1)
            else
                row.time:SetColor(1, 1, 1, 1)
            end
        elseif i == 1 and #list == 0 and not sv.trackerLocked then
            row.name:SetText("|c888888(unlocked - drag to move)|r")
            row.time:SetText("")
        else
            row.name:SetText("")
            row.time:SetText("")
        end
    end
end

---------------------------------------------------------------------------
-- 3) Crosshair readout: OB / IMMUNE / READY for the enemy you're aiming at
---------------------------------------------------------------------------

local reticleUI = {}

local function SaveReticlePosition(control)
    local cx, cy = control:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    OBM.sv.crosshairX, OBM.sv.crosshairY = math.floor(cx - gx), math.floor(cy - gy)
end

ApplyReticleLayout = function()
    if not reticleUI.tlw then return end
    local sv = OBM.sv
    local size = zo_clamp(sv.crosshairSize or 22, 12, 48)
    reticleUI.label:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size))
    reticleUI.tlw:SetDimensions(size * 8, size + 10)
    reticleUI.tlw:ClearAnchors()
    reticleUI.tlw:SetAnchor(CENTER, GuiRoot, CENTER, sv.crosshairX or 0, sv.crosshairY or 80)
    reticleUI.tlw:SetMovable(not sv.trackerLocked)
    reticleUI.tlw:SetMouseEnabled(not sv.trackerLocked)
end

local function CreateReticleReadout()
    local tlw = WM:CreateTopLevelWindow("ArdysOBTrackerReticle")
    tlw:SetClampedToScreen(true)
    tlw:SetHandler("OnMoveStop", SaveReticlePosition)

    local label = WM:CreateControl("$(parent)Label", tlw, CT_LABEL)
    label:SetAnchorFill(tlw)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    reticleUI.tlw, reticleUI.label = tlw, label
    ApplyReticleLayout()
end

local function ReticleTick(now)
    if not reticleUI.label then return end
    local sv = OBM.sv
    local text = ""
    if sv.crosshairEnabled then
        if not sv.trackerLocked then
            text = "|c9B30FFOB 4.2s (drag me)|r" -- placeholder so it can be positioned
        elseif DoesUnitExist(RETICLE) and IsReticleEnemy() then
            local obEnd, immEnd = GetReticleOBState(now)
            if not obEnd and not immEnd then
                -- The game may not show these effects on every target; use our own records.
                local info = FindTrackedByName(FormatName(GetUnitName(RETICLE)))
                if info then
                    if info.immune then immEnd = info.endTime else obEnd = info.endTime end
                end
            end
            if obEnd then
                text = string.format("|cFFA040OB %.1fs|r", obEnd - now)
            elseif immEnd then
                text = string.format("|c999999IMMUNE %ds|r", math.ceil(immEnd - now))
            elseif sv.crosshairShowReady then
                text = "|c40FF40READY|r"
            end
        end
    end
    reticleUI.label:SetText(text)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function OnUpdate()
    if not IsActive() then
        if tracker.root then tracker.root:SetHidden(true) end
        if reticleUI.label then reticleUI.label:SetText("") end
        return
    end
    local nowMs, now = GetGameTimeMilliseconds(), GetFrameTimeSeconds()
    MarkerTick(nowMs, now)
    TrackerTick(now)
    ReticleTick(now)
end

-- Fires for effects YOU apply (filtered by source), including on enemies
-- that have no unit tag.
local function OnEffectChanged(_, changeType, _, effectName, unitTag, _, endTime, _, _, _, _,
                               abilityType, _, unitName, unitId, abilityId)
    if OBM.sv.debug and unitTag ~= "player" then
        Debug("effect %s: %s (id %d, type %d) on %s [unitId %d]",
            changeType == EFFECT_RESULT_FADED and "faded" or "gained",
            tostring(effectName), abilityId or 0, abilityType or -1, tostring(unitName), unitId or 0)
    end
    if unitTag == "player" or not unitId or unitId == 0 then return end
    local name = (unitName and unitName ~= "") and zo_strformat(SI_UNIT_NAME, unitName) or "Enemy"
    local info = OBM.tracked[unitId]

    -- If the game reports the immunity effect itself, use its real timing.
    if IsOffBalanceImmunity(effectName, abilityId) then
        if not OBM.sv.trackImmunity then return end
        if changeType == EFFECT_RESULT_FADED then
            if info and info.immune then OBM.tracked[unitId] = nil end
        else
            OBM.tracked[unitId] = { name = info and info.name or name, endTime = endTime, immune = true }
        end
        return
    end

    if not IsOffBalance(effectName, abilityType) then return end
    if changeType == EFFECT_RESULT_FADED then
        -- Off Balance ended (possibly early): immunity starts now.
        if info and not info.immune then
            if OBM.sv.trackImmunity then
                info.immune, info.endTime = true, GetFrameTimeSeconds() + IMMUNITY_SECONDS
            else
                OBM.tracked[unitId] = nil
            end
        end
    else
        OBM.tracked[unitId] = { name = name, endTime = endTime }
    end
end

-- Backup for the tracker: the combat log's Off Balance result. It carries no
-- duration, so a standard duration is assumed until the effect event (if any)
-- supplies the real end time.
local function OnOffBalanceResult(_, _, _, abilityName, _, _, _, _, targetName, _, _, _, _, _, _, targetUnitId)
    if not targetUnitId or targetUnitId == 0 then return end
    Debug("combat result: Off Balance on %s [unitId %d]", tostring(targetName), targetUnitId)
    local existing = OBM.tracked[targetUnitId]
    if existing and not existing.immune then return end
    local name = (targetName and targetName ~= "") and zo_strformat(SI_UNIT_NAME, targetName) or "Enemy"
    OBM.tracked[targetUnitId] = { name = name, endTime = GetFrameTimeSeconds() + DEFAULT_OB_SECONDS }
end

local function OnUnitDied(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, targetUnitId)
    if targetUnitId then OBM.tracked[targetUnitId] = nil end
end

local function RegisterEvents()
    local n = OBM.name
    EM:RegisterForEvent(n .. "Effect", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(n .. "Effect", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(n .. "OBResult", EVENT_COMBAT_EVENT, OnOffBalanceResult)
    EM:AddFilterForEvent(n .. "OBResult", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_OFFBALANCE,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    local deathResults = { ACTION_RESULT_DIED, ACTION_RESULT_DIED_XP, ACTION_RESULT_KILLING_BLOW }
    for i, result in ipairs(deathResults) do
        local key = n .. "Died" .. i
        EM:RegisterForEvent(key, EVENT_COMBAT_EVENT, OnUnitDied)
        EM:AddFilterForEvent(key, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result)
    end

    EM:RegisterForEvent(n .. "Markers", EVENT_TARGET_MARKER_UPDATE, OnTargetMarkerUpdate)
    EM:RegisterForUpdate(n .. "Update", UPDATE_INTERVAL_MS, OnUpdate)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function PrintStatus()
    local sv = OBM.sv
    Print("v%s  enabled=%s  class=%s (DK: %s)", OBM.version, tostring(sv.enabled),
        zo_strformat(SI_CLASS_NAME, GetUnitClass("player")), tostring(IsDragonknight()))
    Print("markers=%s  max=%d  range=%d m  allowInGroup=%s", tostring(sv.markersEnabled),
        sv.maxMarkers, sv.rangeMeters, tostring(sv.allowInGroup))
    Print("hold=%d ms  immunity=%s  markerSync=%s", sv.holdMs, tostring(sv.trackImmunity),
        markerEventSeen and "confirmed" or "timer")
    for m, slot in pairs(OBM.slots) do
        if slot.onFriendly then Print("  marker %d is flagged as on a friendly", m) end
    end
    lastPvPCheckMs = -PVP_CHECK_MS
    Print("pvpOnly=%s  inPvP=%s  (AvA=%s  BG=%s  BattleSpirit=%s)  active=%s", tostring(sv.pvpOnly),
        tostring(IsInPvP()), tostring(IsInAvAZone()), tostring(IsActiveWorldBattleground()),
        tostring(HasBattleSpirit()), tostring(IsActive()))
    if DoesUnitExist(RETICLE) then
        local dist = GetReticleDistanceMeters()
        local ob = GetMyOffBalanceEndOnReticle(GetFrameTimeSeconds())
        Print("Target: %s  dist=%s  marker=%d  yourOffBalance=%s", GetUnitName(RETICLE),
            dist and string.format("%.1f m", dist) or "unknown",
            GetUnitTargetMarkerType(RETICLE),
            ob and string.format("%.1fs left", ob - GetFrameTimeSeconds()) or "no")
        Print("  reaction=%d  attackable=%s  player=%s  friendly=%s  enemy=%s", GetUnitReaction(RETICLE),
            tostring(IsUnitAttackable(RETICLE)), tostring(IsUnitPlayer(RETICLE)),
            tostring(IsReticleFriendly()), tostring(IsReticleEnemy()))
        local now = GetFrameTimeSeconds()
        for i = 1, GetNumBuffs(RETICLE) do
            local name, _, timeEnding, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(RETICLE, i)
            if IsOffBalanceImmunity(name, abilityId) and timeEnding > now then
                Print("  Off Balance Immunity: %.1fs left (id %d)", timeEnding - now, abilityId or 0)
            end
        end
    else
        Print("No crosshair target.")
    end
end

local function PrintHelp()
    Print("/obt on | off            - enable/disable everything")
    Print("/obt pvp on | off        - only run in PvP (Battle Spirit)")
    Print("/obt markers on | off    - crosshair auto-marker")
    Print("/obt tracker on | off    - timer window")
    Print("/obt lock | unlock       - lock/move the timer window")
    Print("/obt size <12-36>        - timer window text size (default 16)")
    Print("/obt range <meters>      - marking range (default 8)")
    Print("/obt max <1-8>           - how many markers to use")
    Print("/obt hold <ms>           - crosshair hold time before marking (default 300)")
    Print("/obt immunity on | off   - show Off Balance Immunity in the tracker")
    Print("/obt crosshair on | off  - OB / IMMUNE / READY readout by your crosshair")
    Print("/obt clear               - remove the marker on your crosshair target")
    Print("/obt reset               - forget all marker records")
    Print("/obt status | debug")
end

local function OnSlash(text)
    local args = {}
    for word in zo_strlower(text or ""):gmatch("%S+") do args[#args + 1] = word end
    local cmd, arg = args[1], args[2]
    local sv = OBM.sv

    if cmd == "on" or cmd == "off" then
        sv.enabled = (cmd == "on"); Print("Add-on %s.", cmd)
    elseif cmd == "pvp" and (arg == "on" or arg == "off") then
        sv.pvpOnly = (arg == "on"); lastPvPCheckMs = -PVP_CHECK_MS
        Print("PvP only %s.", arg)
    elseif cmd == "markers" and (arg == "on" or arg == "off") then
        sv.markersEnabled = (arg == "on"); Print("Markers %s.", arg)
    elseif cmd == "tracker" and (arg == "on" or arg == "off") then
        sv.trackerEnabled = (arg == "on"); Print("Tracker %s.", arg)
    elseif cmd == "lock" or cmd == "unlock" then
        sv.trackerLocked = (cmd == "lock"); ApplyTrackerLock(); Print("Tracker %sed.", cmd)
    elseif cmd == "size" and tonumber(arg) then
        SetFontSize(tonumber(arg)); Print("Text size set to %d.", sv.fontSize)
    elseif cmd == "range" and tonumber(arg) then
        sv.rangeMeters = zo_clamp(tonumber(arg), 1, 50); Print("Range set to %d m.", sv.rangeMeters)
    elseif cmd == "max" and tonumber(arg) then
        sv.maxMarkers = zo_clamp(math.floor(tonumber(arg)), 1, 8); Print("Using up to %d markers.", sv.maxMarkers)
    elseif cmd == "hold" and tonumber(arg) then
        sv.holdMs = zo_clamp(math.floor(tonumber(arg)), 0, 2000); Print("Hold time set to %d ms.", sv.holdMs)
    elseif cmd == "crosshair" and (arg == "on" or arg == "off") then
        sv.crosshairEnabled = (arg == "on"); Print("Crosshair readout %s.", arg)
    elseif cmd == "immunity" and (arg == "on" or arg == "off") then
        sv.trackImmunity = (arg == "on"); Print("Immunity tracking %s.", arg)
    elseif cmd == "clear" then
        OBM.ClearReticleMarker()
    elseif cmd == "reset" then
        ZO_ClearTable(OBM.slots); ZO_ClearTable(OBM.tracked); pending = nil; candidate = nil
        Print("Records cleared.")
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "debug" then
        sv.debug = not sv.debug; Print("Debug %s.", sv.debug and "on" or "off")
    else
        PrintHelp()
    end
end

---------------------------------------------------------------------------
-- Settings panel (only if LibAddonMenu-2.0 is installed)
---------------------------------------------------------------------------

local function BuildSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local sv = OBM.sv
    local soundLabels, soundKeys = {}, {}
    for i, entry in ipairs(ALERT_SOUNDS) do soundLabels[i], soundKeys[i] = entry.label, entry.key end

    LAM:RegisterAddonPanel(OBM.name .. "Panel", {
        type = "panel", name = OBM.title, author = "|cFF0800@giga'chad|r", version = OBM.version,
        slashCommand = "/obtsettings", registerForDefaults = true,
    })
    LAM:RegisterOptionControls(OBM.name .. "Panel", {
        { type = "checkbox", name = "Enabled",
          getFunc = function() return sv.enabled end, setFunc = function(v) sv.enabled = v end, default = defaults.enabled },
        { type = "checkbox", name = "Dragonknight only",
          getFunc = function() return sv.dragonknightOnly end, setFunc = function(v) sv.dragonknightOnly = v end, default = defaults.dragonknightOnly },
        { type = "checkbox", name = "PvP only",
          tooltip = "Only run in Cyrodiil, Imperial City and battlegrounds (anywhere you have Battle Spirit).",
          getFunc = function() return sv.pvpOnly end, setFunc = function(v) sv.pvpOnly = v; lastPvPCheckMs = -PVP_CHECK_MS end, default = defaults.pvpOnly },
        { type = "header", name = "Target markers" },
        { type = "checkbox", name = "Auto-mark Off Balance targets",
          tooltip = "Marks the enemy under your crosshair when it is Off Balance from you and in range.",
          getFunc = function() return sv.markersEnabled end, setFunc = function(v) sv.markersEnabled = v end, default = defaults.markersEnabled },
        { type = "slider", name = "Range (meters)", min = 1, max = 30, step = 1,
          getFunc = function() return sv.rangeMeters end, setFunc = function(v) sv.rangeMeters = v end, default = defaults.rangeMeters },
        { type = "slider", name = "Markers to use", min = 1, max = 8, step = 1,
          tooltip = "Markers 1 to N are used, in order.",
          getFunc = function() return sv.maxMarkers end, setFunc = function(v) sv.maxMarkers = v end, default = defaults.maxMarkers },
        { type = "checkbox", name = "Mark if range can't be read",
          tooltip = "Some targets (for example enemy players) may not report their position. When on, they are marked anyway.",
          getFunc = function() return sv.markIfRangeUnknown end, setFunc = function(v) sv.markIfRangeUnknown = v end, default = defaults.markIfRangeUnknown },
        { type = "slider", name = "Crosshair hold time (ms)", min = 0, max = 1000, step = 50,
          tooltip = "How long your crosshair must stay on an Off Balance enemy before it is marked. Higher = fewer mistakes in crowded fights, slower marking.",
          getFunc = function() return sv.holdMs end, setFunc = function(v) sv.holdMs = v end, default = defaults.holdMs },
        { type = "checkbox", name = "Remove markers from friendlies",
          tooltip = "If one of this add-on's markers is ever on a friendly, it is removed as soon as your crosshair is on them.",
          getFunc = function() return sv.removeFromFriendlies end, setFunc = function(v) sv.removeFromFriendlies = v end, default = defaults.removeFromFriendlies },
        { type = "checkbox", name = "Mark while grouped",
          tooltip = "Target markers are visible to your whole group.",
          getFunc = function() return sv.allowInGroup end, setFunc = function(v) sv.allowInGroup = v end, default = defaults.allowInGroup },
        { type = "header", name = "Tracker window" },
        { type = "checkbox", name = "Show tracker",
          getFunc = function() return sv.trackerEnabled end, setFunc = function(v) sv.trackerEnabled = v end, default = defaults.trackerEnabled },
        { type = "checkbox", name = "Lock position",
          getFunc = function() return sv.trackerLocked end, setFunc = function(v) sv.trackerLocked = v; ApplyTrackerLock() end, default = defaults.trackerLocked },
        { type = "slider", name = "Text size", min = MIN_FONT, max = MAX_FONT, step = 1,
          tooltip = "Size of the text in the tracker window. The window grows or shrinks to fit.",
          getFunc = function() return sv.fontSize end, setFunc = function(v) SetFontSize(v) end, default = defaults.fontSize },
        { type = "checkbox", name = "Highlight crosshair target",
          tooltip = "The row for the enemy under your crosshair is shown in gold.",
          getFunc = function() return sv.highlightTarget end, setFunc = function(v) sv.highlightTarget = v end, default = defaults.highlightTarget },
        { type = "checkbox", name = "Show Off Balance Immunity",
          tooltip = "After Off Balance ends, the row stays (grey) for the 15 s the target can't be set Off Balance again.",
          getFunc = function() return sv.trackImmunity end, setFunc = function(v) sv.trackImmunity = v end, default = defaults.trackImmunity },
        { type = "checkbox", name = "Hide when empty (while locked)",
          getFunc = function() return sv.trackerHideEmpty end, setFunc = function(v) sv.trackerHideEmpty = v end, default = defaults.trackerHideEmpty },
        { type = "header", name = "Crosshair readout" },
        { type = "description", text = "Shows OB, IMMUNE or READY next to your crosshair for the enemy you're aiming at. Turn off \"Lock position\" above to drag it where you want." },
        { type = "checkbox", name = "Show crosshair readout",
          getFunc = function() return sv.crosshairEnabled end, setFunc = function(v) sv.crosshairEnabled = v end, default = defaults.crosshairEnabled },
        { type = "checkbox", name = "Show READY",
          tooltip = "Show READY when the target has neither Off Balance nor immunity.",
          getFunc = function() return sv.crosshairShowReady end, setFunc = function(v) sv.crosshairShowReady = v end, default = defaults.crosshairShowReady },
        { type = "slider", name = "Readout text size", min = 12, max = 48, step = 1,
          getFunc = function() return sv.crosshairSize end, setFunc = function(v) sv.crosshairSize = v; ApplyReticleLayout() end, default = defaults.crosshairSize },
        { type = "button", name = "Reset position",
          func = function() sv.crosshairX, sv.crosshairY = defaults.crosshairX, defaults.crosshairY; ApplyReticleLayout() end },
        { type = "header", name = "Sound alerts" },
        { type = "checkbox", name = "Ready again",
          tooltip = "Play a sound when an enemy you put Off Balance comes out of immunity and can be set up again. Needs \"Show Off Balance Immunity\".",
          getFunc = function() return sv.alertReady end, setFunc = function(v) sv.alertReady = v end, default = defaults.alertReady },
        { type = "dropdown", name = "Ready sound", choices = soundLabels, choicesValues = soundKeys,
          getFunc = function() return sv.alertReadySound end,
          setFunc = function(v) sv.alertReadySound = v; PlayAlert(v) end, default = defaults.alertReadySound },
        { type = "checkbox", name = "Off Balance ending",
          tooltip = "Play a sound 1.5 s before your Off Balance on an enemy ends - last call to land your burst.",
          getFunc = function() return sv.alertExpiring end, setFunc = function(v) sv.alertExpiring = v end, default = defaults.alertExpiring },
        { type = "dropdown", name = "Ending sound", choices = soundLabels, choicesValues = soundKeys,
          getFunc = function() return sv.alertExpiringSound end,
          setFunc = function(v) sv.alertExpiringSound = v; PlayAlert(v) end, default = defaults.alertExpiringSound },
        { type = "header", name = "Other" },
        { type = "checkbox", name = "Debug messages",
          getFunc = function() return sv.debug end, setFunc = function(v) sv.debug = v end, default = defaults.debug },
    })
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

ZO_CreateStringId("SI_BINDING_NAME_ARDYSOBT_CLEAR_MARKER", "Remove marker from target")
ZO_CreateStringId("SI_BINDING_NAME_ARDYSOBT_TOGGLE_MARKERS", "Toggle auto-marking")

local function OnAddOnLoaded(_, addonName)
    if addonName ~= OBM.name then return end
    EM:UnregisterForEvent(OBM.name, EVENT_ADD_ON_LOADED)

    OBM.sv = ZO_SavedVars:NewAccountWide("ArdysOBTrackerSV", 1, nil, defaults)

    CreateTracker()
    CreateReticleReadout()
    RegisterEvents()
    BuildSettingsMenu()

    SLASH_COMMANDS["/obt"] = OnSlash
    EM:RegisterForEvent(OBM.name .. "Zone", EVENT_PLAYER_ACTIVATED, function() lastPvPCheckMs = -PVP_CHECK_MS end)
end

EM:RegisterForEvent(OBM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
