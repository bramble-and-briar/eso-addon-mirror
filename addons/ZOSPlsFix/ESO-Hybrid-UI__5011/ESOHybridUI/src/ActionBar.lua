-- Keep the compact keyboard-style action bar while displaying controller glyphs.

local ADDON = ESOHybridUI

local function ShouldUseControllerActionGlyphs()
    return ADDON:ShouldShowControllerPrompts()
end

local function RegisterControllerActionGlyph(button)
    if not button or not button.buttonText then
        return
    end

    local slotNum = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()
    local keyboardActionName
    local gamepadActionName

    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        keyboardActionName = "COMMAND_PET"
        gamepadActionName = "COMMAND_PET"
    elseif hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        keyboardActionName = "ACTION_BUTTON_9"
        gamepadActionName = "GAMEPAD_ACTION_BUTTON_9"
    else
        keyboardActionName = "ACTION_BUTTON_" .. tostring(slotNum)
        gamepadActionName = "GAMEPAD_ACTION_BUTTON_" .. tostring(slotNum)
    end

    -- ESO's ActionButton registers an OnUltimateChanged callback for both
    -- player and companion ultimate slots. It swaps the keyboard-style text
    -- label for the two native controller-key indicators in Gamepad mode.
    -- Preserve that behavior when replacing the binding registration.
    local isUltimateSlot = ZO_ActionBar_IsUltimateSlot(slotNum, hotbarCategory)
    local onUltimateChanged = isUltimateSlot and function(label)
        local showGamepadKeys = IsInGamepadPreferredMode()
            and ZO_Keybindings_ShouldShowGamepadKeybind()

        label:SetHidden(showGamepadKeys)
        if button.leftKey and button.rightKey then
            button:HideKeys(not showGamepadKeys)
        end
    end or nil

    ZO_Keybindings_UnregisterLabelForBindingUpdate(button.buttonText)
    local HIDE_UNBOUND = false
    -- Force only the action label to resolve its gamepad binding; the button
    -- control and all action-bar dimensions retain their keyboard style.
    ZO_Keybindings_RegisterLabelForBindingUpdate(
        button.buttonText,
        keyboardActionName,
        HIDE_UNBOUND,
        gamepadActionName,
        onUltimateChanged,
        ShouldUseControllerActionGlyphs()
    )

    -- Registration can happen after ESO has already applied the current
    -- platform style. Synchronize the ultimate label immediately as well.
    if onUltimateChanged then
        onUltimateChanged(button.buttonText)
    end
end
local function RefreshExistingActionGlyphs()
    for _, hotbarCategory in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1,
            ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
            RegisterControllerActionGlyph(ZO_ActionBar_GetButton(slotNum, hotbarCategory))
        end
        RegisterControllerActionGlyph(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, hotbarCategory))
    end

    RegisterControllerActionGlyph(ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
    RegisterControllerActionGlyph(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION))
end

local function InstallActionButtonHooks()
    if ADDON.runtime.actionButtonHooksInstalled then
        return
    end

    -- This is a pure after-initialize task; use ESO's hook system
    -- rather than replacing the shared ActionButton method.
    ZO_PostHook(ActionButton, "Initialize", RegisterControllerActionGlyph)
    ADDON.runtime.actionButtonHooksInstalled = true
end

function ADDON:ApplyActionBar()
    InstallActionButtonHooks()
    RefreshExistingActionGlyphs()
end
