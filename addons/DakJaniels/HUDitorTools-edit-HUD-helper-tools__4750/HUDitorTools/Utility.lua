-- -----------------------------------------------------------------------------
-- HUDitorTools - shared helpers used by more than one file
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

HT.EDITOR_SCENE_NAME = "hud_editor_keyboard"
HT.INFO_BOX_INTERACTABLE_LEVEL = ZO_HUD_EDITOR_KEYBOARD_INFO_BOX_INTERACTABLE_ELEMENT_LEVEL

function HT.FormatUiLayoutMeasurement(layoutValue)
    return string.format("%dui", zo_round(layoutValue))
end

function HT.GetHudElementForControl(control)
    if IsInGamepadPreferredMode() then
        return HUD_MANAGER:GetGamepadElementForControl(control)
    end
    return HUD_MANAGER:GetKeyboardElementForControl(control)
end

function HT.ClampInteger(value, minimum, maximum, fallback)
    value = zo_floor(tonumber(value) or fallback)
    if minimum ~= nil and value < minimum then
        return minimum
    end
    if maximum ~= nil and value > maximum then
        return maximum
    end
    return value
end

function HT.RebuildHudEditorIfShowing()
    if HUD_EDITOR_KEYBOARD:IsShowing() then
        HUD_EDITOR_KEYBOARD:RebuildAllElements()
    end
end

function HT.SetEditorDrawTierAndLevel(control, drawLevel)
    control:SetDrawTier(DT_HIGH)
    control:SetDrawLevel(drawLevel)
end
