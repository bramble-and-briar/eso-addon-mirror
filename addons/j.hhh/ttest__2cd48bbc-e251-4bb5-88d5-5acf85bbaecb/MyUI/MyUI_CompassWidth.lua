-- My UI: Matching compass and boss-bar horizontal expansion (+30%).
-- ESO shares ZO_CompassFrame with the boss-health bar.
-- Keep height, anchors, positions, textures and pins unchanged.
local WIDTH_FACTOR = 1.30
local function nativeWidth()
    if not GuiRoot or not GuiRoot.GetWidth then return nil end
    local screenWidth = GuiRoot:GetWidth()
    if not screenWidth or screenWidth <= 0 then return nil end
    return math.max(400, math.min(screenWidth * 0.35, 800))
end
local function applyCompassWidth(frame)
    if not frame or not frame.control or not frame.control.SetWidth then return end
    local base = nativeWidth()
    if not base then return end
    -- Same width in compass and boss-bar modes; ESO manages anchored bar/bracket geometry.
    frame.control:SetWidth(base * WIDTH_FACTOR)
end
local function install()
    local frame = rawget(_G, 'COMPASS_FRAME')
    if not frame or not frame.control then return false end
    if not frame.MyUICompassWidthInstalled then
        if type(ZO_PostHook) ~= 'function' then return false end
        ZO_PostHook(frame, 'UpdateWidth', function(self)
            applyCompassWidth(self)
        end)
        ZO_PostHook(frame, 'SetBossBarActive', function(self)
            applyCompassWidth(self)
        end)
        -- Re-apply after gamepad template changes if ESO resets compass width.
        ZO_PostHook(frame, 'ApplyStyle', function(self)
            applyCompassWidth(self)
        end)
        frame.MyUICompassWidthInstalled = true
    end
    applyCompassWidth(frame)
    return true
end
if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED then
    EVENT_MANAGER:RegisterForEvent('MyUI_CompassWidth_Activated', EVENT_PLAYER_ACTIVATED, function()
        install()
    end)
end
-- Controls are normally initialized before addon Lua runs; also attempt immediately.
install()
