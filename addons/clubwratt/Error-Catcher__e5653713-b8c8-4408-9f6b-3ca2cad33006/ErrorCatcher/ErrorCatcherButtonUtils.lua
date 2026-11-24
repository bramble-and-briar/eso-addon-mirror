-- ErrorCatcherButtonUtils.lua: naming a keybind strip button (pure)
local ButtonUtils = {}

---The dialog a button belongs to, when it is one of the button objects gamepad dialogs share
---(DialogKeybindStripDescriptor: it carries its dialog).
---@param descriptor table
---@return string|nil dialogName
function ButtonUtils.DialogName(descriptor)
    local dialog = descriptor.dialog
    if dialog == nil then
        return nil
    end
    local ok, name = pcall(function() return dialog.name end)
    return ok and type(name) == "string" and name or "?"
end

---A button's text. A name given as a function is called only on a dialog's shared button, whose name is
---the game's own reader of the dialog's button text; any other is left uncalled, since this runs in a hook
---on the game's stack and what a stranger's function does is unknown.
---@param descriptor table
---@return string
function ButtonUtils.Name(descriptor)
    local name = descriptor.name
    if type(name) == "function" then
        if descriptor.dialog == nil then
            return "(a function)"
        end
        local ok, result = pcall(name, descriptor)
        name = ok and result or nil
    end
    if type(name) == "number" and type(GetString) == "function" then
        name = GetString(name)
    end
    return type(name) == "string" and name or "?"
end

---@param descriptor table
---@param index number Position in its group
---@param sceneName string
---@param dialogName string|nil
---@return string
function ButtonUtils.Label(descriptor, index, sceneName, dialogName)
    local label = string.format("button #%d keybind=%s name='%s' scene=%s",
        index, tostring(descriptor.keybind), ButtonUtils.Name(descriptor), sceneName)
    if dialogName then
        label = label .. string.format(" dialog=%s (the button object every gamepad dialog shares)", dialogName)
    end
    return label
end

ErrorCatcher.ButtonUtils = ButtonUtils
