-- ESO Adventurer Suite - Single owner for gameplay HUD visibility
ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.HudVisibility = EPC.HudVisibility or {}
local H = EPC.HudVisibility
H.consumers = H.consumers or {}
H.suppressed = H.suppressed == true
H.initialized = H.initialized == true

function H:IsSuppressed()
    if type(EPC.IsGameplayHudSuppressed) == "function" then
        local ok, value = pcall(EPC.IsGameplayHudSuppressed, EPC)
        if ok then return value == true end
    end
    return false
end

function H:Register(name, callback)
    if type(callback) ~= "function" then return false end
    self.consumers[tostring(name)] = callback
    pcall(callback, self.suppressed, "register")
    return true
end

function H:Unregister(name) self.consumers[tostring(name)] = nil end

function H:Refresh(reason, force)
    local nextState = self:IsSuppressed()
    if not force and nextState == self.suppressed then return end
    self.suppressed = nextState
    for _, callback in pairs(self.consumers) do pcall(callback, nextState, reason or "refresh") end
end

function H:Initialize()
    if self.initialized then return end
    self.initialized = true
    self.suppressed = self:IsSuppressed()
    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            H:Refresh("scene")
            if type(zo_callLater) == "function" then
                zo_callLater(function() H:Refresh("scene-settled", true) end, 100)
            end
        end)
    end
    if EPC.Runtime then
        local ev = rawget(_G, "EVENT_PLAYER_ACTIVATED")
        if ev then EPC.Runtime:RegisterEvent("HudVisibility", "PlayerActivated", ev, function() H:Refresh("player-activated", true) end) end
    end
end


-- Player-death suppression is owned here with the rest of gameplay HUD policy.
H.playerDead = H.playerDead == true
local baseHudSuppressed = EPC.IsGameplayHudSuppressed
if not EPC._architectureDeathHudPolicy then
    EPC._architectureDeathHudPolicy = true
    function EPC:IsGameplayHudSuppressed(...)
        if H.playerDead then return true end
        if type(IsUnitDead) == "function" then
            local ok, dead = pcall(IsUnitDead, "player")
            if ok and dead == true then return true end
        end
        if EPC.NativeHUDEditor and EPC.NativeHUDEditor.IsPreviewActive
            and EPC.NativeHUDEditor:IsPreviewActive() then
            return false
        end
        if type(baseHudSuppressed) == "function" then return baseHudSuppressed(self, ...) == true end
        return false
    end
end
local function syncDeathHud()
    local dead = false
    if type(IsUnitDead) == "function" then local ok, value = pcall(IsUnitDead, "player"); dead = ok and value == true end
    if H.playerDead ~= dead then H.playerDead = dead; H:Refresh(dead and "player-dead" or "player-alive", true) end
end
if EPC.Runtime then
    local deadEvent = rawget(_G, "EVENT_PLAYER_DEAD"); if deadEvent then EPC.Runtime:RegisterEvent("HudVisibility", "PlayerDead", deadEvent, function() H.playerDead = true; H:Refresh("player-dead", true) end) end
    local aliveEvent = rawget(_G, "EVENT_PLAYER_ALIVE"); if aliveEvent then EPC.Runtime:RegisterEvent("HudVisibility", "PlayerAlive", aliveEvent, function() H.playerDead = false; H:Refresh("player-alive", true) end) end
    local combatEvent = rawget(_G, "EVENT_PLAYER_COMBAT_STATE"); if combatEvent then EPC.Runtime:RegisterEvent("HudVisibility", "DeathCombatSync", combatEvent, syncDeathHud) end
end
syncDeathHud()
