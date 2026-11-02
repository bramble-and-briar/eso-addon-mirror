-- Keep the keyboard dialog layout while allowing gamepad glyph generation
-- during dialog construction. The explicit isGamepad argument is preserved.

local ADDON = ESOHybridUI

function ADDON:ApplyDialogs()
    if self.runtime.dialogHooksInstalled then
        return
    end

    local original = ZO_Dialogs_ShowDialog
    self.runtime.originalShowDialog = original

    -- Keep the full original signature and return tuple intact. This wrapper
    -- temporarily supplies native gamepad context only during construction;
    -- a pre-hook that suppresses the original would discard its return values.
    local wrapper = function(...)
        local shouldUseControllerGlyphs = ADDON:ShouldShowControllerPrompts()

        -- Forward the complete current/future ESO signature unchanged.
        if shouldUseControllerGlyphs then
            return ADDON:WithNativeGamepadMode(original, ...)
        end
        return original(...)
    end

    self.runtime.showDialogWrapper = wrapper
    _G.ZO_Dialogs_ShowDialog = wrapper
    self.runtime.dialogHooksInstalled = true
end
