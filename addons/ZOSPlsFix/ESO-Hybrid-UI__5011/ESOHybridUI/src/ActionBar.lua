-- Keep the compact keyboard-layout action bar while showing controller glyphs.

local ADDON = ESOHybridUI

local function UseControllerGlyphs()
    return ADDON:ShouldShowControllerPrompts() and ADDON:GetSettings().hybridActionBarGlyphs ~= false
end

local function SetNativeUltimateKeysHidden(button, hidden)
    if not button or not button.slot then
        return
    end
    local leftKey = button.slot:GetNamedChild("LeftKeybind")
    local rightKey = button.slot:GetNamedChild("RightKeybind")
    if leftKey then leftKey:SetHidden(hidden) end
    if rightKey then rightKey:SetHidden(hidden) end
end

local function CreateHybridUltimateKey(button, side, keyCode)
    local field = "hybrid" .. side .. "Key"
    if button[field] then
        return button[field]
    end

    -- ESO's native key-texture control follows the active controller type. The
    -- keyboard ultimate template has no LeftKeybind/RightKeybind children, so
    -- these compact controls are created independently of the action template.
    -- Control names are global: reuse an existing one rather than collide.
    local controlName = button.slot:GetName() .. "ESOHybrid" .. side .. "Keybind"
    local control = _G[controlName] or CreateControlFromVirtual(controlName, button.slot, "ZO_KeyTexture")
    control:SetKeyCode(keyCode)
    control:SetDimensions(24, 24)
    control:SetDrawLayer(DL_OVERLAY)
    control:ClearAnchors()
    if side == "Left" then
        control:SetAnchor(TOPRIGHT, button.slot, BOTTOMLEFT, 8, -8)
    else
        control:SetAnchor(TOPLEFT, button.slot, BOTTOMRIGHT, -8, -8)
    end

    button[field] = control
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
        if button.hybridLeftKey then button.hybridLeftKey:SetHidden(true) end
        if button.hybridRightKey then button.hybridRightKey:SetHidden(true) end
    end
end

local function RegisterControllerActionGlyph(button)
    if not button or not button.buttonText then
        return
    end

    local slotNum = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()
    local keyboardActionName, gamepadActionName

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
        if UseControllerGlyphs() then
            -- The hidden GAMEPAD_ACTION_BUTTON_8 binding is not a substitute for
            -- ESO's two-part ultimate prompt; use native glyph textures instead.
            label:SetHidden(true)
            SetHybridUltimateGlyphs(button, true)
            return
        end

        SetHybridUltimateGlyphs(button, false)
        local showDedicatedGamepadKeys = IsInGamepadPreferredMode() and ZO_Keybindings_ShouldShowGamepadKeybind()

        -- Restore ESO's native controls when leaving the custom glyphs.
        SetNativeUltimateKeysHidden(button, not showDedicatedGamepadKeys)
        label:SetHidden(showDedicatedGamepadKeys)
        if button.leftKey and button.rightKey then
            button:HideKeys(not showDedicatedGamepadKeys)
        end
    end or nil

    ZO_Keybindings_UnregisterLabelForBindingUpdate(button.buttonText)
    local HIDE_UNBOUND = false
    ZO_Keybindings_RegisterLabelForBindingUpdate(
        button.buttonText, keyboardActionName, HIDE_UNBOUND, gamepadActionName,
        onUltimateChanged, UseControllerGlyphs())
end

-- One bad button must never abort the rest.
local function SafeRegister(button)
    local ok, err = pcall(RegisterControllerActionGlyph, button)
    if not ok then
        ADDON:LogDebug("Action glyph registration failed:", tostring(err))
    end
end

local function RefreshExistingActionGlyphs()
    for _, hotbarCategory in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1,
            ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
            SafeRegister(ZO_ActionBar_GetButton(slotNum, hotbarCategory))
        end
        SafeRegister(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, hotbarCategory))
    end

    SafeRegister(ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
    SafeRegister(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION))
end

local function InstallActionButtonHook()
    if not ActionButton or not ActionButton.Initialize then
        return false
    end
    -- Pure after-initialize work: ESO's hook system, not a method replacement.
    ZO_PostHook(ActionButton, "Initialize", function(button)
        SafeRegister(button)
    end)
    return true
end

function ADDON:ApplyActionBar()
    self:InstallWhenReady("actionButtonHook", InstallActionButtonHook)
    local ok, err = pcall(RefreshExistingActionGlyphs)
    if not ok then
        self:LogDebug("Action bar refresh failed:", tostring(err))
    end
end
