local info =           function(msg) CHAT_SYSTEM:AddMessage("[Tamriel Guard]: "        .. msg) end
local dbg  = false and function(msg) CHAT_SYSTEM:AddMessage("[Tamriel Guard][DEBUG]: " .. msg) end or function() end

local ALLOWED_STEALTH_STATES = {
        [STEALTH_STATE_HIDDEN                ] = "hidden",
        [STEALTH_STATE_HIDDEN_ALMOST_DETECTED] = "hidden (almost detected)"
    }

-- Shoutout to Dolgubon, no way in hell I'd find FISHING_MANAGER.StartInteraction
-- hook if I didn"t randomly look trough Lazy Writ Crafter"s code.
-- https://www.esoui.com/downloads/info1346-DolgubonsLazyWritCrafter.html
local oldInteract = FISHING_MANAGER.StartInteraction
local function hook(...)
    local _, _, isBlocked, _, _, _, _, isCriminalAction = GetGameCameraInteractableActionInfo()
    if isBlocked then
        return oldInteract(...)
    end

    if isCriminalAction then
        local allowedState = ALLOWED_STEALTH_STATES[GetUnitStealthState("player")]
        if allowedState then
            dbg("Allowed stealing; stealth state: " .. allowedState)
        else
            info("I can see you, criminal!")
            return isCriminalAction
        end
    end

    return oldInteract(...)
end

FISHING_MANAGER.StartInteraction = hook
