-- Hybrid quickslot (utility) wheel.
--
-- ESO has separate keyboard and gamepad wheel classes. The manager caches
-- its selected platform when StartInteraction runs, so each wheel must be
-- started under the platform that should own it. The optional controller bridge
-- uses native inherited keybindings rather than mutating protected bindings.
-- Fishing, target-marker, and player-interaction wheels keep ESO's native presentation.

local ADDON = ESOHybridUI
local rt = ADDON.runtime
local BRIDGE_LAYER = "ESOHybridUI_UTILITY_WHEEL_BRIDGE"

function ADDON:ShouldBridgeUtilityWheelInput()
    return rt.utilityWheelLayerActive == true and self:IsHybrid() and self:IsNativeGamepadMode()
end

function ADDON:CycleUtilityWheel(direction)
    if not self:ShouldBridgeUtilityWheelInput() or not INTERACTIVE_WHEEL_MANAGER then
        return false
    end

    local methodName = direction < 0 and "CycleLeft" or "CycleRight"
    local manager = INTERACTIVE_WHEEL_MANAGER
    if type(manager[methodName]) ~= "function" then
        self:LogWarn("Wheel manager has no", methodName, "- cannot cycle the quickslot wheel.")
        return false
    end

    -- The manager picks its keyboard or gamepad wheel from IsInGamepadPreferredMode()
    -- on every call. The open wheel was started under the keyboard answer, so cycling
    -- must be asked under the same answer; otherwise the manager addresses the
    -- (closed) gamepad wheel and the button press does nothing.
    local ok, result = pcall(self.WithKeyboardWheelMode, self, manager[methodName], manager, ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
    if not ok then
        self:LogWarn("Quickslot wheel", methodName, "failed:", tostring(result))
        return false
    end
    self:LogDebug("Quickslot wheel", methodName, "result:", tostring(result))
    -- The press was ours either way; do not let it fall through to ESO's gated action.
    return true
end

local function PushBridgeLayer()
    if not rt.utilityWheelLayerActive then
        PushActionLayerByName(BRIDGE_LAYER)
        rt.utilityWheelLayerActive = true
        ADDON:LogDebug("Wheel bridge layer pushed.")
    end
end

local function RemoveBridgeLayer()
    if rt.utilityWheelLayerActive then
        RemoveActionLayerByName(BRIDGE_LAYER)
        rt.utilityWheelLayerActive = false
        ADDON:LogDebug("Wheel bridge layer removed.")
    end
end

local function WantsKeyboardQuickslot()
    return ADDON:GetSettings().hybridQuickslotWheel ~= false
end

-- StartInteraction returns a started flag (ESO's input binding consumes it) plus
-- anything else; hand every value back unchanged.
local function AfterUtilityStart(started, ...)
    if started then
        PushBridgeLayer()
    end
    return started, ...
end

local function InstallManagerHooks()
    local managerClass = ZO_InteractiveWheel_Manager
    if not managerClass or not INTERACTIVE_WHEEL_MANAGER or type(managerClass.StartInteraction) ~= "function" then
        return false
    end

    -- Hook the class, not the live singleton.
    local originalStart = managerClass.StartInteraction
    managerClass.StartInteraction = function(self, wheelType, ...)
        if wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY
            and ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
            if WantsKeyboardQuickslot() then
                return AfterUtilityStart(ADDON:WithKeyboardWheelMode(originalStart, self, wheelType, ...))
            end
            -- Explicitly select ESO's real Gamepad radial wheel when the option
            -- is off; the Hybrid HUD itself reports keyboard mode.
            return ADDON:WithNativeGamepadMode(originalStart, self, wheelType, ...)
        end
        if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode()
            and (wheelType == ZO_INTERACTIVE_WHEEL_TYPE_FISHING
                or wheelType == ZO_INTERACTIVE_WHEEL_TYPE_TARGET_MARKER) then
            return ADDON:WithNativeGamepadMode(originalStart, self, wheelType, ...)
        end
        return originalStart(self, wheelType, ...)
    end

    ZO_PreHook(managerClass, "StopInteraction", function(_, wheelType)
        -- Only the utility wheel owns the bridge layer.
        if wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY then
            RemoveBridgeLayer()
        end
        return false
    end)
    return true
end

function ADDON:ApplyUtilityWheel()
    self:InstallWhenReady("utilityWheelHooks", InstallManagerHooks)
    self:InstallWhenReady("wheelCleanup", function()
        -- Never leave the bridge layer behind across a zone change or logout.
        EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_WheelCleanup", EVENT_PLAYER_DEACTIVATED, RemoveBridgeLayer)
        return true
    end)
end
