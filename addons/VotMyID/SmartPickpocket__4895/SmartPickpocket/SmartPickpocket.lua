local ADDON_NAME = "SmartPickpocket"

local oldStartInteraction
local seated = false

local function IsPickpocketInteraction()
    if not GetGameCameraInteractableActionInfo then
        return false
    end

    local _, _, interactionBlocked, _, additionalInteractInfo = GetGameCameraInteractableActionInfo()

    return not interactionBlocked
        and additionalInteractInfo == ADDITIONAL_INTERACT_INFO_PICKPOCKET_CHANCE
end

local function IsPickpocketAllowed()
    if not GetGameCameraPickpocketingBonusInfo then
        return true
    end

    local inBonus, _, percentChance = GetGameCameraPickpocketingBonusInfo()

    if percentChance == nil then
        return true
    end

    return inBonus or percentChance >= 100
end

-- Crouching/sneaking is exposed directly by the ESO API.
local function IsCrouching()
    if not GetUnitStealthState then
        return false
    end

    return GetUnitStealthState("player") ~= STEALTH_STATE_NONE
end

-- ESO does not expose a simple IsUnitSitting() API.  For chairs/benches we
-- remember that the player sat down when the interaction was started, and
-- clear it when the corresponding "Stand" interaction is started.
-- This is deliberately additive: it does not change the existing
-- pickpocket logic above.
local function UpdateSeatedState()
    if not GetGameCameraInteractableActionInfo then
        return
    end

    local action = select(1, GetGameCameraInteractableActionInfo())
    if not action then
        return
    end

    -- The action string is localized by the client.  We use the same
    -- localized strings as the interaction UI when they are available.
    local sitAction = _G.SI_INTERACTION_ACTION_SIT
    local standAction = _G.SI_INTERACTION_ACTION_STAND

    if sitAction then
        local text = GetString(sitAction)
        if text ~= "" and action == text then
            seated = true
            return
        end
    end

    if standAction then
        local text = GetString(standAction)
        if text ~= "" and action == text then
            seated = false
        end
    end
end

local function IsPlayerAllowedToSteal()
    return IsCrouching() or seated
end

local function IsStealingInteraction()
    if not GetGameCameraInteractableActionInfo then
        return false
    end

    local action, _, interactionBlocked, _, additionalInteractInfo, _, _, isCriminalInteract =
        GetGameCameraInteractableActionInfo()

    if interactionBlocked then
        return false
    end

    -- Pickpocket has its own, more precise rule and must remain untouched.
    if additionalInteractInfo == ADDITIONAL_INTERACT_INFO_PICKPOCKET_CHANCE then
        return false
    end

    -- World-object theft is marked by the game as a criminal interaction.
    -- The action itself is intentionally not matched by text, so localization
    -- does not matter.
    return isCriminalInteract == true
end

local function StartInteractionHook(...)
    UpdateSeatedState()

    -- Existing pickpocket protection: unchanged.
    if IsPickpocketInteraction() and not IsPickpocketAllowed() then
        return true
    end

    -- New protection: while standing, prevent criminal world-object theft.
    -- Crouching/sneaking and seated state leave the interaction untouched.
    if IsStealingInteraction() and not IsPlayerAllowedToSteal() then
        return true
    end

    return oldStartInteraction(...)
end

local function Initialize()
    local interactionManager = INTERACTIVE_WHEEL_MANAGER

    if not interactionManager or not interactionManager.StartInteraction then
        d("|cFF5555[" .. ADDON_NAME .. "] INTERACTIVE_WHEEL_MANAGER.StartInteraction not found.|r")
        return
    end

    oldStartInteraction = interactionManager.StartInteraction
    interactionManager.StartInteraction = StartInteractionHook

    d("|c55FF55[" .. ADDON_NAME .. "] loaded.|r")
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end)
