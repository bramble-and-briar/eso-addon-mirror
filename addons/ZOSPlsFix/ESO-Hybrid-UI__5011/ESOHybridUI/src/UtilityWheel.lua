-- Bridges gamepad utility-wheel cycling to ESO's keyboard utility wheel.
-- Update 51 has separate keyboard/gamepad wheel classes and gates the native
-- gamepad cycle actions on IsInGamepadPreferredMode(). We keep the keyboard
-- wheel selected, then add a short-lived gamepad-input action layer.

local ADDON = ESOHybridUI
local BRIDGE_LAYER = "ESOHybridUI_UTILITY_WHEEL_BRIDGE"

ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_LEFT", "Cycle utility wheel left (controller)")
ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_RIGHT", "Cycle utility wheel right (controller)")

function ADDON:ShouldBridgeUtilityWheelInput()
    return self.runtime.utilityWheelLayerActive == true
        and not self:GetSettings().useControllerUI
        and self:IsNativeGamepadMode()
        and INTERACTIVE_WHEEL_MANAGER ~= nil
        and INTERACTIVE_WHEEL_MANAGER.gamepad == false
end

function ADDON:CycleUtilityWheel(direction)
    if not self:ShouldBridgeUtilityWheelInput() then
        return false
    end

    if not INTERACTIVE_WHEEL_MANAGER then
        return false
    end

    if direction < 0 then
        return INTERACTIVE_WHEEL_MANAGER:CycleLeft(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
    end
    return INTERACTIVE_WHEEL_MANAGER:CycleRight(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
end

local function CopyGamepadDefaultBindings(sourceActionName, targetActionName)
    local sourceLayer, sourceCategory, sourceAction = GetActionIndicesFromName(sourceActionName)
    local targetLayer, targetCategory, targetAction = GetActionIndicesFromName(targetActionName)
    if not sourceLayer or not targetLayer then
        return false
    end

    local copiedAny = false
    for bindingIndex = 1, GetMaxBindingsPerAction() do
        local key, mod1, mod2, mod3, mod4 =
            GetActionBindingInfo(sourceLayer, sourceCategory, sourceAction, bindingIndex)

        if not key or key == KEY_INVALID then
            key, mod1, mod2, mod3, mod4 =
                GetActionDefaultBindingInfo(sourceLayer, sourceCategory, sourceAction, bindingIndex)
        end

        if key and key ~= KEY_INVALID and IsKeyCodeGamepadKey(key) then
            CreateDefaultActionBind(targetActionName, key, mod1, mod2, mod3, mod4)
            copiedAny = true
        end
    end

    return copiedAny
end

local function RemoveBridgeLayer()
    if ADDON.runtime.utilityWheelLayerActive then
        RemoveActionLayerByName(BRIDGE_LAYER)
        ADDON.runtime.utilityWheelLayerActive = false
    end
end

local function InstallManagerHooks()
    local managerClass = ZO_InteractiveWheel_Manager
    if not INTERACTIVE_WHEEL_MANAGER or ADDON.runtime.utilityWheelHooksInstalled then
        return
    end

    -- Hook the manager class rather than assigning an override to the live
    -- singleton. Preserve StartInteraction's complete return tuple because
    -- ESO's input binding consumes its boolean result.
    local originalStart = managerClass.StartInteraction

    managerClass.StartInteraction = function(self, wheelType, ...)
        local function Pack(...) return { n = select("#", ...), ... } end
        local args = { n = select("#", ...), ... }
        local function StartNativeWheel()
            return originalStart(self, wheelType, unpack(args, 1, args.n))
        end
        local settings = ADDON:GetSettings()
        local results
        -- Hybrid's keyboard-style override is intentionally limited to the
        -- utility/quickslot wheel. Fishing and target-marker wheels retain
        -- ESO's native presentation; player-to-player has its own hook below.
        if wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY
            and settings.useHybridUI
            and ADDON:IsNativeGamepadMode() then
            results = Pack(ADDON:WithKeyboardWheelMode(StartNativeWheel))
        else
            results = Pack(StartNativeWheel())
        end
        local started = results[1]
        if started
            and wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY
            and self.gamepad == false
            and ADDON:GetSettings().useControllerUI ~= true
            and ADDON:IsNativeGamepadMode() then
            PushActionLayerByName(BRIDGE_LAYER)
            ADDON.runtime.utilityWheelLayerActive = true
        end
        return unpack(results, 1, results.n)
    end

    ZO_PreHook(managerClass, "StopInteraction", function(self, wheelType)
        -- Only the utility wheel owns this temporary bridge layer. Other
        -- wheels can stop while it is still open (or during nested UI flows).
        if wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY then
            -- Remove our layer before ESO pops the utility wheel's own layer.
            RemoveBridgeLayer()
        end
        return false
    end)

    ADDON.runtime.utilityWheelHooksInstalled = true
end

local function InstallPlayerInteractionWheelHook()
    local playerToPlayerClass = ZO_PlayerToPlayer
    if not playerToPlayerClass or ADDON.runtime.playerInteractionWheelHookInstalled then
        return
    end

    local originalStart = playerToPlayerClass.StartInteraction
    if type(originalStart) ~= "function" then
        return
    end

    playerToPlayerClass.StartInteraction = function(self, ...)
        local settings = ADDON:GetSettings()
        if settings.useHybridUI and ADDON:IsNativeGamepadMode() then
            local args = { n = select("#", ...), ... }
            local function StartKeyboardWheel()
                return originalStart(self, unpack(args, 1, args.n))
            end
            return ADDON:WithKeyboardWheelMode(StartKeyboardWheel)
        end
        return originalStart(self, ...)
    end

    ADDON.runtime.playerInteractionWheelHookInstalled = true
end

function ADDON:ApplyUtilityWheel()
    InstallManagerHooks()
    InstallPlayerInteractionWheelHook()

    if not self.runtime.utilityWheelLeftCopied then
        self.runtime.utilityWheelLeftCopied = CopyGamepadDefaultBindings(
            "UTILITY_WHEEL_GAMEPAD_CYCLE_LEFT",
            "ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_LEFT"
        )
    end
    if not self.runtime.utilityWheelRightCopied then
        self.runtime.utilityWheelRightCopied = CopyGamepadDefaultBindings(
            "UTILITY_WHEEL_GAMEPAD_CYCLE_RIGHT",
            "ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_RIGHT"
        )
    end
    self.runtime.utilityWheelDefaultsCopied =
        self.runtime.utilityWheelLeftCopied and self.runtime.utilityWheelRightCopied

    if not self.runtime.utilityWheelRetryHook
        and (not self.runtime.utilityWheelHooksInstalled or not self.runtime.utilityWheelDefaultsCopied) then
        EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME .. "_UtilityWheelRetry", EVENT_PLAYER_ACTIVATED, function()
            self:ApplyUtilityWheel()
            if self.runtime.utilityWheelHooksInstalled and self.runtime.utilityWheelDefaultsCopied then
                EVENT_MANAGER:UnregisterForEvent(self.ADDON_NAME .. "_UtilityWheelRetry", EVENT_PLAYER_ACTIVATED)
                self.runtime.utilityWheelRetryHook = false
            end
        end)
        self.runtime.utilityWheelRetryHook = true
    end
end
