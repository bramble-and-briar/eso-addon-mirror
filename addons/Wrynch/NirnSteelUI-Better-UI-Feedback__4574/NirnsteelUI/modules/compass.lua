local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_Compass"

Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI
local CompassModule = {}
Nirnsteel_UI.Compass = CompassModule

local function IsModuleEnabled()
    return not Nirnsteel_UI.Settings or Nirnsteel_UI.Settings:IsCompassEnabled()
end

local function ShouldHideCompass()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:ShouldHardcoreHideCompass() == true
end

local function BossBarIsVisible()
    if not COMPASS_FRAME or not COMPASS_FRAME:GetBossBarActive() then return false end
    local reasons = COMPASS_FRAME.bossBarHiddenReasons
    return not reasons or not reasons:IsHidden()
end

function CompassModule:ApplyCardinalStyle()
    if COMPASS and COMPASS.SetCardinalDirections then
        local size = IsInGamepadPreferredMode() and 26 or 21
        COMPASS:SetCardinalDirections("$(ANTIQUE_FONT)|" .. size .. "|soft-shadow-thick")
    end
end

function CompassModule:CreateArtwork(container)
    if self.artwork then return end
    self.artwork = {}
    local art = Nirnsteel_UI:GetAssetPath("ui/compass/")
    for _, name in ipairs({ "rail", "left", "right", "heading" }) do
        -- Follow the native compass fade, including the transition to the boss bar.
        -- Pins live on the MEDIUM tier; all frame art stays behind them.
        local texture = WINDOW_MANAGER:CreateControl(nil, ZO_Compass, CT_TEXTURE)
        texture:SetDrawTier(DT_LOW)
        texture:SetDrawLayer(DL_BACKGROUND)
        texture:SetDrawLevel(1)
        texture:SetMouseEnabled(false)
        local file = name == "rail" and "rail_v3_dxt5.dds"
            or name == "heading" and "heading_v3_dxt5.dds" or "cap_v4_dxt5.dds"
        texture:SetTexture(art .. file)
        self.artwork[name] = texture
    end

    -- Anchor to the actual pin viewport, not a guessed height or another skin's
    -- backdrop. Two anchors follow native width and platform changes.
    local rail = self.artwork.rail
    rail:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    rail:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
    for _, name in ipairs({ "left", "right" }) do
        local cap = self.artwork[name]
        local edge = name == "left" and TOPLEFT or TOPRIGHT
        local bottom = name == "left" and BOTTOMLEFT or BOTTOMRIGHT
        local join = name == "left" and TOPRIGHT or TOPLEFT
        local bottomJoin = name == "left" and BOTTOMRIGHT or BOTTOMLEFT
        cap:SetWidth(20)
        cap:SetAnchor(join, container, edge, 0, 0)
        cap:SetAnchor(bottomJoin, container, bottom, 0, 0)
        cap:SetTextureCoords(name == "left" and 0 or 1, name == "left" and 1 or 0, 0, 1)
    end
    -- A fixed bearing marker below the rail leaves the native location label clear.
    local heading = self.artwork.heading
    heading:SetDimensions(16, 12)
    heading:SetAnchor(TOP, container, BOTTOM, 0, -4)
end

function CompassModule:ApplyStockStyle()
    for _, texture in pairs(self.artwork or {}) do texture:SetHidden(true) end
    if Nirnsteel_UI.Themes then Nirnsteel_UI.Themes:ApplyMinimalBorder(self.minimalContainer, false) end
    if not self.nativeHidden then return end
    for control, hidden in pairs(self.nativeHidden) do control:SetHidden(hidden) end
    self.nativeHidden = nil
    if COMPASS and COMPASS.SetCardinalDirections then
        COMPASS:SetCardinalDirections(IsInGamepadPreferredMode() and "ZoFontGamepadBold34" or "ZoFontHeader4")
    end
end

function CompassModule:ApplyNirnsteelStyle()
    local frame = ZO_CompassFrame
    local container = ZO_Compass and ZO_Compass:GetNamedChild("Container")
    local center = frame and frame:GetNamedChild("Center")
    local left = frame and frame:GetNamedChild("Left")
    local right = frame and frame:GetNamedChild("Right")
    if not container or not center or not left or not right then
        self:ApplyStockStyle()
        return
    end

    if not self.nativeHidden then
        self.nativeHidden = {}
        local function Remember(control)
            if control then self.nativeHidden[control] = control:IsHidden() end
        end
        Remember(center)
        Remember(left)
        Remember(right)
        Remember(center:GetNamedChild("TopMungeOverlay"))
        Remember(center:GetNamedChild("BottomMungeOverlay"))
    end
    -- The boss bar reuses these textures. Leave native atlas UVs, color, alpha,
    -- anchors and dimensions untouched; restore only the visibility we own.
    for control in pairs(self.nativeHidden) do control:SetHidden(true) end
    self.minimalContainer = container
    local themes = Nirnsteel_UI.Themes
    if themes then themes:ApplyMinimalBorder(container, true, DL_BACKGROUND, DT_LOW) end
    if themes and themes:IsMinimal() then
        for _, texture in pairs(self.artwork or {}) do texture:SetHidden(true) end
        self:ApplyCardinalStyle()
        return
    end
    self:CreateArtwork(container)
    for name, texture in pairs(self.artwork) do
        local path = "ui/compass/" .. (name == "rail" and "rail_v3_dxt5.dds"
            or name == "heading" and "heading_v3_dxt5.dds" or "cap_v4_dxt5.dds")
        texture:SetTexture(Nirnsteel_UI.Themes and Nirnsteel_UI.Themes:GetAssetPath(path) or Nirnsteel_UI:GetAssetPath(path))
        texture:SetHidden(false)
    end
    self:ApplyCardinalStyle()
end

function CompassModule:Apply()
    if self.applying then return end
    self.applying = true
    if IsModuleEnabled() and (not Nirnsteel_UI.Themes or Nirnsteel_UI.Themes:HasBorders())
        and not ShouldHideCompass() and not BossBarIsVisible() then
        self:ApplyNirnsteelStyle()
    else
        self:ApplyStockStyle()
    end
    self.applying = false
end

function CompassModule:InstallHooks()
    if not self.frameHooksInstalled and COMPASS_FRAME then
        ZO_PostHook(COMPASS_FRAME, "ApplyStyle", function()
            -- Platform templates update the munge visibility. Remember that new
            -- state instead of the state hidden by the previous skin pass.
            local center = ZO_CompassFrame and ZO_CompassFrame:GetNamedChild("Center")
            if self.nativeHidden and center then
                for _, name in ipairs({ "TopMungeOverlay", "BottomMungeOverlay" }) do
                    local overlay = center:GetNamedChild(name)
                    if overlay then self.nativeHidden[overlay] = overlay:IsHidden() end
                end
            end
            self:Apply()
        end)
        ZO_PostHook(COMPASS_FRAME, "RefreshVisible", function() self:Apply() end)
        self.frameHooksInstalled = true
    end
    if not self.compassHooksInstalled and COMPASS then
        ZO_PostHook(COMPASS, "ApplyKeyboardStyle", function() self:Apply() end)
        ZO_PostHook(COMPASS, "ApplyGamepadStyle", function() self:Apply() end)
        self.compassHooksInstalled = true
    end
end

function CompassModule:RegisterEvents()
    if self.eventsRegistered then return end
    for _, event in ipairs({ EVENT_PLAYER_ACTIVATED, EVENT_SCREEN_RESIZED, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED }) do
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, event, function()
            zo_callLater(function() self:RefreshSettings() end, 50)
        end)
    end
    self.eventsRegistered = true
end

function CompassModule:RefreshSettings()
    self:RegisterEvents()
    self:InstallHooks()
    if COMPASS_FRAME then
        local hidden = ShouldHideCompass() == true
        if COMPASS_FRAME.compassHidden ~= hidden then COMPASS_FRAME:SetCompassHidden(hidden) end
    end
    self:Apply()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    CompassModule:RefreshSettings()
    zo_callLater(function() CompassModule:RefreshSettings() end, 1000)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
