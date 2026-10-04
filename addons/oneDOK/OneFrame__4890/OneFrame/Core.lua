local A = OneFrame
function A:QueueRefresh(sort)
    self.sortDirty = self.sortDirty or sort
    if self.pending then return end
    self.pending = true
    -- One-shot, coalesced refresh after the native lifecycle has finished this event burst.
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Refresh", 50, function()
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "Refresh")
        self.pending = false
        -- One configuration pass for the complete native roster event burst.
        if self.rosterDirty then
            self.rosterDirty = false
            self.CombatStats:Configure()
        end
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "StatsRefresh")
        self.statsPending = false
        self.Frames:Refresh()
    end)
end
function A:QueueStatsRefresh()
    if self.pending or self.statsPending then return end
    self.statsPending = true
    EVENT_MANAGER:RegisterForUpdate(self.name .. "StatsRefresh", 50, function()
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "StatsRefresh")
        self.statsPending = false
        if not self.pending then self.Frames:UpdateStats() end
    end)
end
function A:QueueRosterRefresh()
    if not self.rosterDirty then
        -- Invalidate immediately, but do not reinstall observers for every unit event.
        self.rosterDirty = true
        self.CombatStats:ResetShared()
    end
    self:QueueRefresh(true)
end
function A:ApplySettings()
    self:PrepareRoleStatistics()
    self.active = self.supported and self.sv.enabled
    self.CombatStats:Configure()
    self:QueueRefresh(true)
end
function A:Initialize()
    SLASH_COMMANDS["/oneframedebug"] = function() self.SharedStats:Debug() end
    self.defaults = self:MakeDefaults()
    self.sv = ZO_SavedVars:NewAccountWide("OneFrameSavedVariables", 1, nil, self.defaults)
    -- Ultimate is always shown when data exists; its old setting is no longer exposed.
    self.sv.ultimate = true
    self:PrepareRoleStatistics()
    self.Settings:Initialize()
    local apiVersion = GetAPIVersion()
    if apiVersion ~= 101050 and apiVersion ~= 101051 then
        d(GetString(ONEFRAME_UNSUPPORTED))
        return
    end
    EVENT_MANAGER:RegisterForEvent(self.name .. "Startup", EVENT_PLAYER_ACTIVATED, function()
        if self:InitializeFrames() then
            EVENT_MANAGER:UnregisterForEvent(self.name .. "Startup", EVENT_PLAYER_ACTIVATED)
        elseif not self.warned then
            self.warned = true
            d(GetString(ONEFRAME_MISSING))
        end
    end)
    if self:InitializeFrames() then
        EVENT_MANAGER:UnregisterForEvent(self.name .. "Startup", EVENT_PLAYER_ACTIVATED)
    end
end
function A:InitializeFrames()
    if self.supported then return true end
    if not UNIT_FRAMES or not UNIT_FRAMES.GetFrame or not UNIT_FRAMES.GetCompanionGroupSize
        or not ZO_UnitFrameObject or not ZO_UnitVisualizer_PowerShieldModule then return false end
    for _, method in ipairs({ "SetAnchor", "ApplyVisualStyle", "UpdateName", "UpdateLevel",
        "UpdateStatus", "UpdateAssignment", "DoAlphaUpdate" }) do
        if type(ZO_UnitFrameObject[method]) ~= "function" then return false end
    end
    for _, method in ipairs({ "OnStatusBarValueChanged", "ShowOverlay", "ApplyPlatformStyle" }) do
        if type(ZO_UnitVisualizer_PowerShieldModule[method]) ~= "function" then return false end
    end
    self.supported = true
    self.Frames:Initialize()
    self.Interaction:Initialize()
    self.ShieldOverlay:Initialize()
    EVENT_MANAGER:RegisterForEvent(self.name .. "Health", EVENT_POWER_UPDATE, function(_, tag, _, powerType)
        if powerType == COMBAT_MECHANIC_FLAGS_HEALTH and type(tag) == "string" and tag:match("^group%d+$") then
            self:QueueStatsRefresh()
        end
    end)
    for _, event in ipairs({ EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT,
        EVENT_GROUP_UPDATE, EVENT_UNIT_CREATED, EVENT_UNIT_DESTROYED, EVENT_GROUP_MEMBER_CONNECTED_STATUS }) do
        EVENT_MANAGER:RegisterForEvent(self.name .. "SharedLifecycle", event, function(_, tag)
            if (event == EVENT_UNIT_CREATED or event == EVENT_UNIT_DESTROYED)
                and (type(tag) ~= "string" or not tag:match("^group%d+$")) then return end
            self:QueueRosterRefresh()
        end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name .. "SharedLoad", EVENT_ADD_ON_LOADED, function()
        self.CombatStats:Configure()
    end)
    for _, event in ipairs({ EVENT_GROUP_UPDATE, EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT,
        EVENT_GROUP_MEMBER_ROLE_CHANGED, EVENT_UNIT_CREATED, EVENT_UNIT_DESTROYED,
        EVENT_GROUP_TYPE_CHANGED, EVENT_LEADER_UPDATE, EVENT_PLAYER_COMBAT_STATE, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED }) do
        EVENT_MANAGER:RegisterForEvent(self.name, event, function(_, tag)
            if (event == EVENT_UNIT_CREATED or event == EVENT_UNIT_DESTROYED)
                and (type(tag) ~= "string" or not tag:match("^group%d+$")) then return end
            self:QueueRefresh(true)
        end)
    end
    for _, event in ipairs({ EVENT_LEVEL_UPDATE, EVENT_CHAMPION_POINT_UPDATE,
        EVENT_GROUP_MEMBER_CONNECTED_STATUS, EVENT_UNIT_DEATH_STATE_CHANGED,
        EVENT_GROUP_MEMBER_ACCOUNT_NAME_UPDATED }) do
        EVENT_MANAGER:RegisterForEvent(self.name, event, function() self:QueueRefresh(false) end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        self.CombatStats:Reset()
        self.CombatStats:ResetShared()
        self:ApplySettings()
        if self.CombatStats.listening then self.CombatStats:State(IsUnitInCombat("player")) end
    end)
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function() self:QueueRefresh(true) end)
    self:ApplySettings()
    return true
end
EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
