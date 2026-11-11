-- Dialogs built while Hybrid is active get ESO's native gamepad presentation and
-- controller glyphs. The policy also keeps that answer while the dialog remains
-- visible, because ESO updateFn callbacks may query it on every frame.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function InstallDialogWrapper()
    local original = _G.ZO_Dialogs_ShowDialog
    if type(original) ~= "function" then
        return false
    end

    _G.ZO_Dialogs_ShowDialog = function(name, data, textParams, isGamepad, ...)
        if ADDON:ShouldShowControllerPrompts() and isGamepad == nil then
            local dialogInfo = ESO_Dialogs and ESO_Dialogs[name]
            if type(dialogInfo) == "table" and dialogInfo.gamepadInfo then
                isGamepad = true
            end
        end

        local dialog
        if ADDON:ShouldShowControllerPrompts() and isGamepad == true then
            dialog = ADDON:WithNativeGamepadMode(original, name, data, textParams, isGamepad, ...)
        else
            dialog = original(name, data, textParams, isGamepad, ...)
        end

        -- Only mark a dialog that ESO actually created. A queued dialog is nil
        -- here and becomes tracked when ESO later calls this wrapper to show it.
        if dialog and isGamepad == true then
            rt.gamepadDialogName = name
        end
        return dialog
    end
    return true
end

function ADDON:ApplyDialogs()
    self:InstallWhenReady("dialogWrapper", InstallDialogWrapper)
end
