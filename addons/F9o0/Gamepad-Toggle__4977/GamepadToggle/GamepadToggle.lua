-- One global table only (needed for the keybind in Bindings.xml)
GamepadToggle = {}
local GT = GamepadToggle
GT.name = "GamepadToggle"

-- Keybind name shown in Controls > Keybindings
ZO_CreateStringId("SI_BINDING_NAME_GAMEPADTOGGLE_TOGGLE", "Toggle Gamepad Mode (Auto / On)")

local AUTO = INPUT_PREFERRED_MODE_AUTOMATIC
local ON   = INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD

function GT.Toggle()
    local current = tonumber(GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE))
    if current == ON then
        SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(AUTO))
        d("Gamepad Mode: Auto")
    else
        SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(ON))
        d("Gamepad Mode: On")
    end
end

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= GT.name then return end
    EVENT_MANAGER:UnregisterForEvent(GT.name, EVENT_ADD_ON_LOADED)

    SLASH_COMMANDS["/gptoggle"] = GT.Toggle
end

EVENT_MANAGER:RegisterForEvent(GT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
