-- ESO Adventurer Suite
-- Controller / Hybrid UI Support
-- Keeps ESO gameplay input native while allowing keyboard UI + controller prompts.
-- Event-driven only: no analog-stick polling and no per-frame controller checks.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.ControllerSupport = EPC.ControllerSupport or {}
local C = EPC.ControllerSupport

local function saved()
    return EPC.saved or EPC.defaults or {}
end

local function safeCall(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a, b, c, d, e
end

function C:GetUIBehavior029761()
    -- Architecture hardening: never force ESO between keyboard/gamepad modes.
    -- The Suite follows ESO's native preferred-mode setting.
    return "AUTOMATIC"
end

function C:GetPromptMode029761()
    local value = tostring(saved().controllerPromptMode029761 or "AUTO")
    if value ~= "CONTROLLER" and value ~= "KEYBOARD" then return "AUTO" end
    return value
end

function C:ShouldUseControllerPrompts029761()
    local mode = self:GetPromptMode029761()
    if mode == "CONTROLLER" then return true end
    if mode == "KEYBOARD" then return false end

    -- Hybrid mode deliberately keeps ESO's preferred UI mode on keyboard, so
    -- IsInGamepadPreferredMode() will be false even though the user is playing
    -- with a controller. In that mode Auto therefore means controller prompts.
    if self:GetUIBehavior029761() == "KEYBOARD_CONTROLLER" then return true end

    if type(IsInGamepadPreferredMode) == "function" then
        return safeCall(IsInGamepadPreferredMode, false) == true
    end
    return false
end

function C:GetExplicitInputDeviceType029761(useController)
    if useController then
        return rawget(_G, "PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD")
            or rawget(_G, "INPUT_DEVICE_TYPE_GAMEPAD")
    end
    return rawget(_G, "PREFERRED_INPUT_DEVICE_TYPE_KEYBOARD")
        or rawget(_G, "INPUT_DEVICE_TYPE_KEYBOARD")
end

function C:GetActionBindingMarkup029761(actionName, size, forceController)
    actionName = tostring(actionName or "")
    if actionName == "" then return "" end
    local useController = forceController
    if useController == nil then useController = self:ShouldUseControllerPrompts029761() end

    local scale = math.max(70, math.min(220, tonumber(size) or 125))
    local textOptions = rawget(_G, "KEYBIND_TEXT_OPTIONS_FULL_NAME") or 2
    local textureOptions = rawget(_G, "KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP") or 2
    local keyInvalid = rawget(_G, "KEY_INVALID")

    -- Best path: ask ESO for the binding belonging to the exact input device.
    local inputDeviceType = self:GetExplicitInputDeviceType029761(useController)
    local getByDevice = rawget(_G, "GetHighestPriorityActionBindingInfoFromNameAndInputDevice")
    local fromKeys = rawget(_G, "ZO_Keybindings_GetBindingStringFromKeys")
    if inputDeviceType ~= nil and type(getByDevice) == "function" and type(fromKeys) == "function" then
        local ok, key, mod1, mod2, mod3, mod4 = pcall(getByDevice, actionName, inputDeviceType)
        if ok and key ~= nil and (keyInvalid == nil or key ~= keyInvalid) then
            local okMarkup, markup = pcall(fromKeys,
                key, mod1, mod2, mod3, mod4,
                textOptions, textureOptions, scale, scale)
            if okMarkup and markup and markup ~= "" then return tostring(markup) end
        end
    end

    -- ESO's shared helper can explicitly prefer gamepad glyphs independent of
    -- the active UI mode. This is ideal for Keyboard UI + Controller mode.
    local highestString = rawget(_G, "ZO_Keybindings_GetHighestPriorityBindingStringFromAction")
    if useController and type(highestString) == "function" then
        local ok, markup = pcall(highestString,
            actionName, textOptions, textureOptions,
            true, false, scale, false)
        if ok and markup and markup ~= "" then return tostring(markup) end
    end

    -- Some action-bar gamepad binds are exposed through hidden GAMEPAD_ actions.
    if useController and actionName:find("^ACTION_BUTTON_") then
        local gamepadAction = "GAMEPAD_" .. actionName
        if inputDeviceType ~= nil and type(getByDevice) == "function" and type(fromKeys) == "function" then
            local ok, key, mod1, mod2, mod3, mod4 = pcall(getByDevice, gamepadAction, inputDeviceType)
            if ok and key ~= nil and (keyInvalid == nil or key ~= keyInvalid) then
                local okMarkup, markup = pcall(fromKeys,
                    key, mod1, mod2, mod3, mod4,
                    textOptions, textureOptions, scale, scale)
                if okMarkup and markup and markup ~= "" then return tostring(markup) end
            end
        end
    end

    -- Final fallback preserves the user's existing keyboard binding display.
    if EPC.GetActionBindingMarkup029199 then
        return tostring(EPC:GetActionBindingMarkup029199(actionName, size) or "")
    end
    return ""
end

function C:RefreshPromptConsumers029761()
    if EPC.AbilityOverlays then
        if type(EPC.AbilityOverlays.InvalidateBindingText) == "function" then
            EPC.AbilityOverlays:InvalidateBindingText()
        end
        if type(EPC.AbilityOverlays.Refresh) == "function" then
            pcall(EPC.AbilityOverlays.Refresh, EPC.AbilityOverlays)
        end
    end
    if EPC.DualActionBar and type(EPC.DualActionBar.Refresh) == "function" then
        pcall(EPC.DualActionBar.Refresh, EPC.DualActionBar)
    end
    if EPC.QuickslotOverlay then
        if type(EPC.QuickslotOverlay.InvalidateBinding029199) == "function" then
            EPC.QuickslotOverlay:InvalidateBinding029199()
        end
        if type(EPC.QuickslotOverlay.Refresh) == "function" then
            pcall(EPC.QuickslotOverlay.Refresh, EPC.QuickslotOverlay)
        end
    end
    if EPC.RotationAssistant and type(EPC.RotationAssistant.Refresh) == "function" then
        pcall(EPC.RotationAssistant.Refresh, EPC.RotationAssistant)
    end
end

function C:ApplyPreferredUIMode029761()
    -- Intentionally inert. Changing ESO's preferred input mode from addon code
    -- previously caused controller/keyboard mode fighting and severe FPS loss.
    return true
end

function C:ForceKeyboardUI029761()
    return false
end

function C:SetUIBehavior029761(value)
    saved().controllerUIBehavior029761 = "AUTOMATIC"
    self:RefreshPromptConsumers029761()
end

function C:SetPromptMode029761(value)
    value = tostring(value or "AUTO")
    if value ~= "CONTROLLER" and value ~= "KEYBOARD" then value = "AUTO" end
    saved().controllerPromptMode029761 = value
    self:RefreshPromptConsumers029761()
end

function C:Initialize029761()
    if self._initialized029761 then return end
    self._initialized029761 = true

    local prefix = (EPC.name or "EAS") .. "_Controller029761"

    if EVENT_MANAGER and rawget(_G, "EVENT_GAMEPAD_PREFERRED_MODE_CHANGED") then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_PreferredMode", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
            function(_, isGamepadPreferred)
                if C._forcingKeyboard029761 then return end
                if isGamepadPreferred and C:GetUIBehavior029761() == "KEYBOARD_CONTROLLER" then
                    -- Hybrid mode rejects only the visual gamepad UI switch.
                    -- Do this once on the mode-change event. Never poll the pad.
                    if type(zo_callLater) == "function" then
                        zo_callLater(function()
                            C:ForceKeyboardUI029761()
                            C:RefreshPromptConsumers029761()
                        end, 0)
                    else
                        C:ForceKeyboardUI029761()
                        C:RefreshPromptConsumers029761()
                    end
                else
                    C:RefreshPromptConsumers029761()
                end
            end)
    end

    for _, eventName in ipairs({ "EVENT_KEYBINDING_SET", "EVENT_KEYBINDING_CLEARED" }) do
        local eventId = rawget(_G, eventName)
        if EVENT_MANAGER and eventId then
            EVENT_MANAGER:RegisterForEvent(prefix .. "_" .. eventName, eventId, function()
                C:RefreshPromptConsumers029761()
            end)
        end
    end

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            C:ApplyPreferredUIMode029761()
            C:RefreshPromptConsumers029761()
        end, 100)
    else
        C:ApplyPreferredUIMode029761()
        C:RefreshPromptConsumers029761()
    end
end

if EVENT_MANAGER and rawget(_G, "EVENT_ADD_ON_LOADED") then
    EVENT_MANAGER:RegisterForEvent((EPC.name or "EAS") .. "_ControllerBootstrap029761", EVENT_ADD_ON_LOADED,
        function(_, addonName)
            if addonName ~= EPC.name then return end
            EVENT_MANAGER:UnregisterForEvent((EPC.name or "EAS") .. "_ControllerBootstrap029761", EVENT_ADD_ON_LOADED)
            C:Initialize029761()
        end)
end
