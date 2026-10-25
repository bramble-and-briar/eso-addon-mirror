-- Stealth Icon Only by Buhpa
-- Suppress status labels without changing the eye's texture or animation state.
local ADDON_NAME = "StealthIconOnly"

local function HideStatusText(object)
    object = object or (RETICLE and RETICLE.stealthIcon)
    local label = (object and object.stealthText) or _G.ZO_ReticleContainerStealthIconStealthText
    if label then
        label:SetHidden(true)
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    if ZO_StealthIcon then
        ZO_PostHook(ZO_StealthIcon, "AnimateInStealthText", function(object)
            HideStatusText(object)
        end)
        ZO_PostHook(ZO_StealthIcon, "RefreshStealthReticle", function(object)
            HideStatusText(object)
        end)
    end
    HideStatusText()
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
