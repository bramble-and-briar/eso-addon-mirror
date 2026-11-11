local A = AddKillCounter
local C = A.Core
A.name = "AddKillCounter"
A.version = "1.3.4"
A.sceneName = "addKillCounterGamepad"
A.defaults = {
    enabled = true, includePets = true, includeCompanion = true,
    participation = false, showHUD = true, combatOnly = false,
    hudPosition = 1, hudScale = 1, hudCustom = false, hudX = 90, hudY = 180,
    targetZoneId = 0, targetZoneName = "",
    stats = C.NewStats(),
}

function A:Now()
    local stamp = GetTimeStamp()
    local seconds = GetSecondsSinceMidnight()
    local time = string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
    -- GetDate is the client's calendar date (YYYYMMDD), paired with its local clock.
    return tostring(GetDate()), time, stamp
end

function A:CleanName(name)
    if not name or name == "" then return "" end
    return zo_strformat("<<1>>", name)
end

function A:IsOwnSource(sourceType)
    return sourceType == COMBAT_UNIT_TYPE_PLAYER
        or (self.sv.includePets and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET)
        or (self.sv.includeCompanion and sourceType == COMBAT_UNIT_TYPE_PLAYER_COMPANION)
end

function A:IsPvP()
    return IsInAvAZone() or IsActiveWorldBattleground()
end

function A:IsInTargetZone()
    local targetZoneId = self.sv and self.sv.targetZoneId or 0
    if targetZoneId <= 0 then return false end
    -- Player position is independent of the map currently being browsed.
    local zoneId = GetUnitWorldPosition("player")
    for _ = 1, 8 do
        if zoneId == targetZoneId then return true end
        if not zoneId or zoneId == 0 then return false end
        local parent = GetParentZoneId(zoneId)
        if not parent or parent == zoneId then return false end
        zoneId = parent
    end
    return false
end

function A:ActivateCurrentZone()
    local zoneId = GetUnitWorldPosition("player")
    if not zoneId or zoneId <= 0 then return false end
    self.sv.targetZoneId = zoneId
    self.sv.targetZoneName = self:CleanName(GetZoneNameById(zoneId))
    self:LocationChanged()
    return true
end

function A:DeactivateZone()
    self.sv.targetZoneId = 0
    self.sv.targetZoneName = ""
    self:LocationChanged()
end

function A:LocationChanged()
    -- Old hits/IDs must not leak across a departure and later re-entry.
    self:ResetRuntime()
    self:RefreshHUD()
end

function A:ReticleChanged()
    local name = self:CleanName(GetUnitName("reticleover"))
    if name ~= "" and IsUnitPlayer("reticleover") then self.playerNames[name] = true end
end

local damageResults = {
    [ACTION_RESULT_DAMAGE] = true, [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true, [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_DAMAGE_SHIELDED] = true,
}
-- NPCs report DIED_XP (or DIED when there is no XP), rather than requiring
-- the player-oriented KILLING_BLOW result. These are OWN kills by default;
-- participation is only needed when the final source is somebody else.
local deathResults = {
    [ACTION_RESULT_DIED] = true,
    [ACTION_RESULT_DIED_XP] = true,
    [ACTION_RESULT_DIED_COMPANION_XP] = true,
    [ACTION_RESULT_KILLING_BLOW] = true,
}

function A:OnCombat(_, result, isError, abilityName, abilityGraphic, slot,
        sourceName, sourceType, targetName, targetType, hitValue, powerType,
        damageType, log, sourceId, targetId)
    if not self.sv.enabled or isError then return end
    if not self:IsInTargetZone() then return end
    if not damageResults[result] and not deathResults[result] then return end
    if self:IsPvP() then return end
    if deathResults[result] then
        self.eventStats.deaths = self.eventStats.deaths + 1
        self.lastDeathEvent = string.format("result=%s source=%s target=%s id=%s name=%s", tostring(result), tostring(sourceType), tostring(targetType), tostring(targetId), tostring(targetName))
    end
    if targetType == COMBAT_UNIT_TYPE_PLAYER or targetType == COMBAT_UNIT_TYPE_GROUP
        or targetType == COMBAT_UNIT_TYPE_PLAYER_PET or targetType == COMBAT_UNIT_TYPE_PLAYER_COMPANION
        or targetType == COMBAT_UNIT_TYPE_TARGET_DUMMY then return end
    local name = self:CleanName(targetName)
    if self.playerNames[name] then return end
    local now = GetFrameTimeSeconds()
    C.Sweep(self.tracker, now)
    local own = self:IsOwnSource(sourceType)
    if damageResults[result] and own and hitValue > 0 then
        self.eventStats.hits = self.eventStats.hits + 1
        C.Observe(self.tracker, targetId, name, now)
        return
    end
    local killingBlow = deathResults[result] and own
    local participation = self.sv.participation and result == ACTION_RESULT_DIED_XP
    if not killingBlow and not participation then return end
    -- Participation requires our prior hit; unrelated nearby XP does not count.
    if not killingBlow and not self.tracker.seen[targetId] then return end
    name = C.ResolveDeath(self.tracker, targetId, name, now)
    if not name or self.playerNames[name] then return end
    local day, time = self:Now()
    C.Record(self.sv.stats, day, time)
    self.session = self.session + 1
    self:RefreshHUD()
    if self.screen then self.screen:Update() end
end

function A:RefreshHUD()
    if not self.sv or not self.hud then return end
    local day = self:Now()
    local daily = self.sv.stats.days[day]
    local paused = self.sv.enabled and "" or " |cFFAA55PAUSE|r"
    local text = string.format("|cD5B66FADD KILL COUNTER|r%s\nHeute: %d   Gesamt: %d",
        paused, daily and daily.total or 0, self.sv.stats.total)
    self.hud.label:SetText(text)
    -- Measure at font scale 1: the old fixed 500px box left a large invisible
    -- area to the right, and ClampHUDPosition stopped at that area's edge.
    local textWidth = ZO_LabelUtils_GetTextDimensions(text, "ZoFontGamepadCondensed27")
    local availableWidth = GuiRoot:GetWidth() / self.sv.hudScale
    self.hud:SetWidth(math.min(availableWidth, math.max(210, math.ceil(textWidth) + 32)))
    local anchors = {TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT}
    local anchor = anchors[self.sv.hudPosition] or TOPLEFT
    local right = self.sv.hudPosition == 2 or self.sv.hudPosition == 4
    local bottom = self.sv.hudPosition >= 3
    self.hud:SetScale(self.sv.hudScale)
    self.hud:ClearAnchors()
    if self.sv.hudCustom then
        local x, y = self:ClampHUDPosition(self.sv.hudX, self.sv.hudY)
        self.sv.hudX, self.sv.hudY = x, y
        self.hud:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else
        self.hud:SetAnchor(anchor, GuiRoot, anchor, right and -90 or 90, bottom and -180 or 180)
    end
    local visible = self.moving or (self:IsInTargetZone() and self.sv.showHUD and (not self.sv.combatOnly or IsUnitInCombat("player")))
    self.hudFragment:SetHiddenForReason("settings", not visible)
end

function A:ResetRuntime()
    self.tracker = C.NewTracker()
    self.playerNames = {}
    self.eventStats = {hits = 0, deaths = 0}
    self.lastDeathEvent = nil
end

function A:PrintStatus()
    d(string.format("Add Kill Counter %s · Erfassung: %s · Gesamt: %d · Sitzung: %d · Eigene Treffer: %d · Todesmeldungen: %d · Ohne auflösbare ID/Name: %d",
        self.version, self.sv.enabled and "Ein" or "Aus", self.sv.stats.total, self.session,
        self.eventStats.hits, self.eventStats.deaths, self.tracker.unknown))
    if self.lastDeathEvent then d("Letzte Todesmeldung: " .. self.lastDeathEvent) end
end

function A:Open(view)
    self.screen.view = view or {kind = "home", page = 1}
    self.screen.history = {}
    self.screen.dirty = true
    SCENE_MANAGER:Push(self.sceneName)
end

function A:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide("AddKillCounterSavedVariables", 1, nil, self.defaults, GetWorldName())
    C.RemoveDetails(self.sv.stats)
    self.sv.logCapacity = nil
    self.sv.alphabetical = nil
    self.session = 0
    self:ResetRuntime()
    self:CreateUI()
    self:CreateSettings()
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_COMBAT_EVENT, function(...) self:OnCombat(...) end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_RETICLE_TARGET_CHANGED, function() self:ReticleChanged() end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        self:LocationChanged()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ZONE_CHANGED, function() self:LocationChanged() end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function() self:RefreshHUD() end)
    -- Also detects midnight and an OS clock change while idle.
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Clock", 1000, function() self:RefreshHUD() end)
    SLASH_COMMANDS["/addkills"] = function() self:Open() end
    SLASH_COMMANDS["/akc"] = SLASH_COMMANDS["/addkills"]
    SLASH_COMMANDS["/akcstatus"] = function() self:PrintStatus() end
end

EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
