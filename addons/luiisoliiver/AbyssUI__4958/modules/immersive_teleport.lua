local ADDON_NAME = "AbyssUI"
local NAMESPACE = ADDON_NAME .. "_ImmersiveTeleport"
local RECALL_ABILITY_ID = 6811

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local Teleport = {}
NAGA_UI.ImmersiveTeleport = Teleport

local function IsEnabled()
    return NAGA_UI.Settings and NAGA_UI.Settings:IsImmersiveTeleportEnabled()
end

function Teleport:Restore()
    EVENT_MANAGER:UnregisterForUpdate(NAMESPACE)
    local state = self.state
    self.state = nil
    if not state then return end

    if state.framed then
        -- Match VestigeMirror's defaults and release the character-panel camera.
        SetFrameLocalPlayerTarget(0.50, 0.55)
        SetFrameLocalPlayerLookAtDistanceFactor(nil)
        SetFramingScreenType(FRAMING_SCREEN_DEFAULT)
        SetFrameLocalPlayerInGameCamera(FRAME_PLAYER_FRAGMENT:IsShowing())
    end
    SetGuiHidden("ingame", state.uiHidden)
end

function Teleport:Start(durationMS)
    if not IsEnabled() or self.state then return end

    local _, castTimeMS = GetAbilityCastInfo(RECALL_ABILITY_ID, nil, "player")
    durationMS = tonumber(durationMS) or 0
    if durationMS <= 0 then durationMS = tonumber(castTimeMS) or 8000 end
    local state = {
        uiHidden = GetGuiHidden("ingame"),
        deadline = GetFrameTimeMilliseconds() + durationMS + 2000,
    }
    self.state = state

    -- Let the map/roster scene finish releasing its camera before taking over.
    SCENE_MANAGER:ShowBaseScene()
    EVENT_MANAGER:RegisterForUpdate(NAMESPACE, 50, function()
        if self.state ~= state then return end
        if not IsEnabled() or IsPlayerMoving() or IsBlockActive() or IsUnitDead("player")
            or IsUnitInCombat("player")
            or GetFrameTimeMilliseconds() >= state.deadline then
            self:Restore()
            return
        end

        local atBaseScene = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
        if not atBaseScene then
            -- A newly opened menu must remain usable and own its own camera.
            if state.framed then self:Restore() end
            return
        end
        if not state.framed then
            state.framed = true
            SetFramingScreenType(FRAMING_SCREEN_DEFAULT)
            SetFrameLocalPlayerTarget(0.35, 0.55)
            SetFrameLocalPlayerLookAtDistanceFactor(0.85)
            SetFrameLocalPlayerInGameCamera(true)
            RequestReframeLocalPlayerInGameCamera()
            SetGuiHidden("ingame", true)
        end
    end)
end

function Teleport:OnRecallResult(result, isError, durationMS)
    if isError or result == ACTION_RESULT_INTERRUPT or result == ACTION_RESULT_FAILED
        or (ACTION_RESULT_EFFECT_FADED and result == ACTION_RESULT_EFFECT_FADED) then
        self:Restore()
    elseif result == ACTION_RESULT_BEGIN then
        self:Start(durationMS)
    end
end

function Teleport:RefreshSettings()
    self:Restore()
    EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_COMBAT_EVENT)
    if not IsEnabled() then return end

    EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_COMBAT_EVENT,
        function(_, result, isError, _, _, _, _, sourceType, _, _, hitValue, _, _, _, _, _, abilityId)
            if sourceType == COMBAT_UNIT_TYPE_PLAYER and abilityId == RECALL_ABILITY_ID then
                self:OnRecallResult(result, isError, hitValue)
            end
        end)
    EVENT_MANAGER:AddFilterForEvent(NAMESPACE, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, RECALL_ABILITY_ID)
    EVENT_MANAGER:AddFilterForEvent(NAMESPACE, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end

function Teleport:InstallTravelHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true
    -- Recall combat events are not emitted by every travel/customized animation.
    -- Observe the actual requests as well. Arm before the request so a synchronous
    -- failure can restore immediately; never suppress or replace the game's call.
    for _, name in ipairs({ "FastTravelToNode", "TravelToKeep", "JumpToGroupLeader", "JumpToGroupMember",
        "JumpToGuildMember", "JumpToFriend", "JumpToHouse", "JumpToSpecificHouse",
        "RequestJumpToHouse", "RequestJumpToHousePreviewWithTemplate" }) do
        if type(_G[name]) == "function" then
            ZO_PreHook(name, function()
                self:Start()
                return false
            end)
        end
    end
    ZO_PreHook("CancelCast", function()
        self:Restore()
        return false
    end)
end

NAGA_UI.OnAddonLoaded(function()
    for _, event in ipairs({ EVENT_PLAYER_DEACTIVATED, EVENT_PLAYER_ACTIVATED,
        EVENT_PLAYER_TELEPORTED_LOCALLY, EVENT_JUMP_FAILED, EVENT_PLAYER_DEAD,
        EVENT_SOCIAL_ERROR }) do
        EVENT_MANAGER:RegisterForEvent(NAMESPACE, event, function() Teleport:Restore() end)
    end
    Teleport:InstallTravelHooks()
    Teleport:RefreshSettings()
end)
