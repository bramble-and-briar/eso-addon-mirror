GamepadToggle = {}

ZO_CreateStringId("SI_BINDING_NAME_GAMEPADTOGGLE_TOGGLE", "Toggle Gamepad Mode (Auto / On)")

function GamepadToggle.Toggle()
    local current = tonumber(GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE))

    if current == INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD then
        SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(INPUT_PREFERRED_MODE_AUTOMATIC))
        d("Gamepad Mode: Auto")
    else
        SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD))
        d("Gamepad Mode: On")
    end
end

SLASH_COMMANDS["/gptoggle"] = GamepadToggle.Toggle
