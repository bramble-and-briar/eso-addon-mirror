local DIAhelp = DIAhelp
DIAhelp.Companion = {}
-- DIAhelp, alabuzya, 2026-09-24. GPL-3.0-or-later.
-- Use the native companion AI. No ability is cast by this module.
local hookedSlots = setmetatable({}, { __mode = "k" })
function DIAhelp.Companion.ApplyPolicy()
    if GetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_ALLOW_COMPANION_AUTO_ULTIMATE) ~= "1" then
        SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_ALLOW_COMPANION_AUTO_ULTIMATE, "1")
    end
    local button = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
    local slot = button and button.slot
    if not slot then return end
    if not hookedSlots[slot] then
        hookedSlots[slot] = true
        ZO_PreHookHandler(slot, "OnEffectivelyShown", function(control)
            control:SetHidden(true)
        end)
    end
    slot:SetHidden(true)
end
