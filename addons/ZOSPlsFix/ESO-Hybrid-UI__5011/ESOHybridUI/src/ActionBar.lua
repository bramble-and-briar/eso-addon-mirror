-- Keep the compact keyboard-style action bar while displaying controller glyphs.

local ADDON = ESOHybridUI

local function ShouldUseControllerActionGlyphs()
    return ADDON:ShouldShowControllerPrompts()
end

local function SetNativeUltimateKeysHidden(button, hidden)
    if not button or not button.slot then
        return
    end

    local leftKey = button.slot:GetNamedChild("LeftKeybind")
    local rightKey = button.slot:GetNamedChild("RightKeybind")
    if leftKey then
        leftKey:SetHidden(hidden)
    end
    if rightKey then
        rightKey:SetHidden(hidden)
    end
end

local function CreateHybridUltimateKey(button, side, keyCode)
    local control = button["hybrid" .. side .. "Key"]
    if control then
        return control
    end

    -- Use ESO's native key-texture control so glyph artwork follows the
    -- active controller type. The keyboard ultimate template has no
    -- LeftKeybind/RightKeybind children, so these compact controls are
    -- created independently of the platform action-button template.
    local controlName = button.slot:GetName() .. "ESOHybrid" .. side .. "Keybind"
    control = CreateControlFromVirtual(controlName, button.slot, "ZO_KeyTexture")
    control:SetKeyCode(keyCode)
    control:SetDimensions(24, 24)
    control:SetDrawLayer(DL_OVERLAY)

    if side == "Left" then
        control:SetAnchor(TOPRIGHT, button.slot, BOTTOMLEFT, 8, -8)
    else
        control:SetAnchor(TOPLEFT, button.slot, BOTTOMRIGHT, -8, -8)
    end

    button["hybrid" .. side .. "Key"] = control
    return control
end

local function SetHybridUltimateGlyphs(button, visible)
    if not button or not button.slot then
        return
    end

    if visible then
        local isCompanion = button:GetHotbarCategory() == HOTBAR_CATEGORY_COMPANION
        local leftCode = isCompanion and KEY_GAMEPAD_LEFT_STICK or KEY_GAMEPAD_LEFT_SHOULDER
        local rightCode = isCompanion and KEY_GAMEPAD_RIGHT_STICK or KEY_GAMEPAD_RIGHT_SHOULDER

        CreateHybridUltimateKey(button, "Left", leftCode):SetHidden(false)
        CreateHybridUltimateKey(button, "Right", rightCode):SetHidden(false)
        SetNativeUltimateKeysHidden(button, true)
    else
        if button.hybridLeftKey then
            button.hybridLeftKey:SetHidden(true)
        end
        if button.hybridRightKey then
            button.hybridRightKey:SetHidden(true)
        end
    end
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

    local isUltimateSlot = ZO_ActionBar_IsUltimateSlot(slotNum, hotbarCategory)
    local onUltimateChanged = isUltimateSlot and function(label)
        if ADDON:GetSettings().useHybridUI and ShouldUseControllerActionGlyphs() then
            -- The hidden GAMEPAD_ACTION_BUTTON_8 binding is not a substitute
            -- for ESO's two-part ultimate prompt. Use native ZO_KeyTexture
            -- glyphs at compact keyboard-HUD dimensions instead.
            label:SetHidden(true)
            SetHybridUltimateGlyphs(button, true)
            return
        end

        SetHybridUltimateGlyphs(button, false)
        local showDedicatedGamepadKeys = IsInGamepadPreferredMode()
            and ZO_Keybindings_ShouldShowGamepadKeybind()

        -- Restore ESO's native controls when leaving Hybrid's custom glyph
        -- presentation; the next line then applies ESO's normal visibility.
        SetNativeUltimateKeysHidden(button, not showDedicatedGamepadKeys)
        label:SetHidden(showDedicatedGamepadKeys)
        if button.leftKey and button.rightKey then
            button:HideKeys(not showDedicatedGamepadKeys)
        end
    end or nil

    ZO_Keybindings_UnregisterLabelForBindingUpdate(button.buttonText)
    local HIDE_UNBOUND = false
    ZO_Keybindings_RegisterLabelForBindingUpdate(
        button.buttonText,
        keyboardActionName,
        HIDE_UNBOUND,
        gamepadActionName,
        onUltimateChanged,
        ShouldUseControllerActionGlyphs()
    )
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
