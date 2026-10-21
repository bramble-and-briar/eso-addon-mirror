local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_Compass"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local CompassModule = {}
NAGA_UI.Compass = CompassModule

local STYLE_NAGA = "naga"
local STYLE_DS3 = "ds3"

local function IsModuleEnabled()
    return not NAGA_UI.Settings or NAGA_UI.Settings:IsCompassEnabled()
end

local function GetCompassStyle()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetCompassStyle then
        return NAGA_UI.Settings:GetCompassStyle() or STYLE_NAGA
    end
    return STYLE_NAGA
end

local function ShouldHideCompass()
    return NAGA_UI.Settings and NAGA_UI.Settings:ShouldHardcoreOcultarCompass() == true
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
    local art = NAGA_UI:GetAssetPath("ui/compass/")

    -- NAGA style pieces: rail, left cap, right cap, heading
    for _, name in ipairs({ "rail", "left", "right", "heading" }) do
        local texture = WINDOW_MANAGER:CreateControl(nil, ZO_Compass, CT_TEXTURE)
        texture:SetDrawTier(DT_LOW)
        texture:SetDrawLayer(DL_BACKGROUND)
        texture:SetDrawLevel(1)
        texture:SetMouseEnabled(false)
        local file = name == "rail" and "rail_v3_dxt5.dds"
            or name == "heading" and "heading_v3_dxt5.dds" or "cap_v4_dxt5.dds"
        texture:SetTexture(art .. file)
        texture:SetHidden(true)
        self.artwork[name] = texture
    end

    -- DS3 style: single full-width texture
    local ds3 = WINDOW_MANAGER:CreateControl(nil, ZO_Compass, CT_TEXTURE)
    ds3:SetDrawTier(DT_LOW)
    ds3:SetDrawLayer(DL_BACKGROUND)
    ds3:SetDrawLevel(1)
    ds3:SetMouseEnabled(false)
    ds3:SetTexture(art .. "ds3_compass.dds")
    ds3:SetHidden(true)
    self.artwork.ds3 = ds3

    -- Anchor NAGA pieces
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
    local heading = self.artwork.heading
    heading:SetDimensions(16, 12)
    heading:SetAnchor(TOP, container, BOTTOM, 0, -4)

    -- Anchor DS3 piece: full container
    ds3:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    ds3:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
end

function CompassModule:ShowStyle(style)
    if not self.artwork then return end
    local isDS3 = style == STYLE_DS3
    self.artwork.rail:SetHidden(isDS3)
    self.artwork.left:SetHidden(isDS3)
    self.artwork.right:SetHidden(isDS3)
    self.artwork.heading:SetHidden(isDS3)
    self.artwork.ds3:SetHidden(not isDS3)
end

function CompassModule:HideAllArtwork()
    if not self.artwork then return end
    for _, texture in pairs(self.artwork) do
        texture:SetHidden(true)
    end
end

function CompassModule:ApplyStockStyle()
    self:HideAllArtwork()
    if not self.nativeHidden then return end
    for control, hidden in pairs(self.nativeHidden) do control:SetHidden(hidden) end
    self.nativeHidden = nil
    if COMPASS and COMPASS.SetCardinalDirections then
        COMPASS:SetCardinalDirections(IsInGamepadPreferredMode() and "ZoFontGamepadBold34" or "ZoFontHeader4")
    end
end

function CompassModule:ApplyNagaStyle()
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
    for control in pairs(self.nativeHidden) do control:SetHidden(true) end
    self:CreateArtwork(container)
    self:ShowStyle(GetCompassStyle())
    self:ApplyCardinalStyle()
end

function CompassModule:Apply()
    if self.applying then return end
    self.applying = true
    if IsModuleEnabled() and not ShouldHideCompass() and not BossBarIsVisible() then
        self:ApplyNagaStyle()
    else
        self:ApplyStockStyle()
    end
    self.applying = false
end

function CompassModule:InstallHooks()
    if not self.frameHooksInstalled and COMPASS_FRAME then
        ZO_PostHook(COMPASS_FRAME, "ApplyStyle", function()
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

---------------------------------------------------------------------------
-- Evento mundial no compass: mesmo EventWorld.dds do minimapa
-- (pisca + aumenta 1x + gira horário) só com evento ativo.
---------------------------------------------------------------------------
local function AddonTex(rel)
    if NAGA_UI and NAGA_UI.GetAssetPath then
        return NAGA_UI:GetAssetPath(rel)
    end
    return "AbyssUI/" .. rel
end
local WORLD_EVENT_ICON = AddonTex("assets/MiniMap/EventWorld.dds")
local DYNAMIC_EVENT_ICON = AddonTex("assets/MiniMap/EventDynamic.dds")
local function IsDynamicEventTexture(texture)
    local tex = (texture or ""):lower()
    if tex == "" then return false end
    if tex:find("dynamic_world_event", 1, true) then return true end
    if tex:find("mapkey_dynamic", 1, true) then return true end
    if tex:find("dynamicworldevent", 1, true) then return true end
    if tex:find("/dynamic_", 1, true) and tex:find("event", 1, true) then return true end
    return false
end
local weCompassPins = {}
local WE_UPDATE_NS = EVENT_NAMESPACE .. "_WorldEvent"

local function WorldDistMeters(tag)
    if not tag or not GetUnitRawWorldPosition then return nil end
    local ok1, _, pwx, _, pwz = pcall(GetUnitRawWorldPosition, "player")
    local ok2, _, ewx, _, ewz = pcall(GetUnitRawWorldPosition, tag)
    if not ok1 or not ok2 or not pwx or not ewx then return nil end
    local dx, dz = ewx - pwx, ewz - pwz
    return math.sqrt(dx * dx + dz * dz) / 100
end

local function MapDistMeters(ex, ey, px, py)
    if not ex or not ey or not px or not py then return nil end
    local dx, dy = ex - px, ey - py
    local dn = math.sqrt(dx * dx + dy * dy)
    -- Escala aproximada: se minimapa calibrar, usa; senão ~ map size médio
    local scale = nil
    if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.GetMapScaleMeters then
        scale = NagaMapUI.Minimap.GetMapScaleMeters()
    end
    if not scale or scale <= 0 then
        -- fallback: ~1.0 de mapa ≈ 1000–3000 m; usa 2000 m como estimativa
        scale = 2000
    end
    return dn * scale
end

local function CollectActiveWorldEvents()
    local found = {}
    if not GetNextWorldEventInstanceId then return found end
    local id = GetNextWorldEventInstanceId(nil)
    local guard = 0
    while id and id ~= 0 and guard < 64 do
        guard = guard + 1
        local context = GetWorldEventLocationContext(id)
        if context == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
            local sx, sy, n = 0, 0, 0
            local bestTag, bestDist = nil, nil
            for i = 1, GetNumWorldEventInstanceUnits(id) do
                local tag = GetWorldEventInstanceUnitTag(id, i)
                local ux, uy, _, inMap = GetMapPlayerPosition(tag)
                if inMap and ux and uy and not (ux == 0 and uy == 0) then
                    sx = sx + ux
                    sy = sy + uy
                    n = n + 1
                    local d = WorldDistMeters(tag)
                    if d and (not bestDist or d < bestDist) then
                        bestDist, bestTag = d, tag
                    end
                end
            end
            if n > 0 then
                found[#found + 1] = { x = sx / n, y = sy / n, meters = bestDist, tag = bestTag, kind = "worldevent" }
            end
        elseif context == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
            local zoneIndex, poiIndex = GetWorldEventPOIInfo(id)
            if not (zoneIndex == 1 and poiIndex == 1) and poiIndex then
                local nX, nY, _, _, isOnMap = GetPOIMapInfo(GetCurrentMapZoneIndex(), poiIndex)
                if isOnMap and nX and nY then
                    found[#found + 1] = { x = nX, y = nY, meters = nil, kind = "worldevent" }
                end
            end
        end
        id = GetNextWorldEventInstanceId(id)
    end
    -- Eventos dinâmicos (ícone padrão do jogo)
    if GetNumMapLocations then
        for i = 1, GetNumMapLocations() do
            if IsMapLocationVisible and IsMapLocationVisible(i) then
                local texture, x, y = GetMapLocationIcon(i)
                if IsDynamicEventTexture(texture) and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    found[#found + 1] = {
                        x = x, y = y, meters = nil,
                        icon = DYNAMIC_EVENT_ICON,
                        kind = "dynamicevent",
                    }
                end
            end
        end
    end
    return found
end

local function EnsureWePin(i)
    local parent = ZO_Compass
    if not parent then return nil end
    local pin = weCompassPins[i]
    if not pin then
        pin = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
        pin:SetTexture(WORLD_EVENT_ICON)
        pin:SetDrawLayer(DL_OVERLAY)
        pin:SetDrawLevel(200)
        pin:SetMouseEnabled(false)
        pin:SetHidden(true)
        local label = WINDOW_MANAGER:CreateControl(nil, pin, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        label:SetColor(0.85, 0.95, 1, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOP, pin, BOTTOM, 0, -2)
        label:SetText("")
        pin.distLabel = label
        weCompassPins[i] = pin
    end
    return pin
end

-- Ângulo do evento relativo à câmera → posição X no compass (±FOV).
-- Mesma base do minimapa rotativo (Put/rotateMap):
--   rx = cosH*dx - sinH*dy ; ry = sinH*dx + cosH*dy
-- Frente = -ry (cima), direita = +rx.
local function EventToCompassX(ex, ey, px, py, heading, compassW)
    local ddx = ex - px
    local ddy = ey - py
    if ddx == 0 and ddy == 0 then return 0, true end
    local cosH = math.cos(heading)
    local sinH = math.sin(heading)
    local rx = cosH * ddx - sinH * ddy
    local ry = sinH * ddx + cosH * ddy
    local diff = math.atan2(rx, -ry)
    local halfFov = math.pi * 0.5
    if math.abs(diff) > halfFov * 1.15 then
        return nil, false
    end
    local t = diff / halfFov
    if t > 1 then t = 1 elseif t < -1 then t = -1 end
    return t * (compassW * 0.5), true
end

local function FormatMeters(m)
    if not m or m < 0 then return "" end
    if m >= 1000 then
        return string.format("%.1fkm", m / 1000)
    end
    return string.format("%dm", math.floor(m + 0.5))
end

local function UpdateWorldEventCompass()
    if not ZO_Compass or ZO_Compass:IsHidden() then
        for _, pin in pairs(weCompassPins) do pin:SetHidden(true) end
        return
    end
    if ShouldHideCompass() or not IsModuleEnabled() then
        for _, pin in pairs(weCompassPins) do pin:SetHidden(true) end
        return
    end
    -- Opção: World Event no Compass (settings)
    local weOn = true
    if NAGA_UI and NAGA_UI.Settings and NAGA_UI.Settings.IsWorldEventCompassEnabled then
        weOn = NAGA_UI.Settings:IsWorldEventCompassEnabled()
    end
    if not weOn then
        for _, pin in pairs(weCompassPins) do pin:SetHidden(true) end
        return
    end
    local events = CollectActiveWorldEvents()
    local px, py, heading = GetMapPlayerPosition("player")
    if GetPlayerCameraHeading then
        heading = GetPlayerCameraHeading()
    end
    local compassW = ZO_Compass:GetWidth() or 400
    local t = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    local phase = math.floor(t / 0.5) % 2
    local baseSize = 28
    local sz = phase == 0 and baseSize * 2 or baseSize
    local alpha = phase == 0 and 1 or 0.35
    local rot = -(t * 2 * math.pi)

    local used = 0
    if px and py and heading then
        for _, ev in ipairs(events) do
            local offsetX, onCompass = EventToCompassX(ev.x, ev.y, px, py, heading, compassW)
            if onCompass and offsetX then
                used = used + 1
                local pin = EnsureWePin(used)
                if pin then
                    local icon = (ev.kind == "dynamicevent" and (ev.icon or DYNAMIC_EVENT_ICON)) or WORLD_EVENT_ICON
                    if pin.diaTexture ~= icon then
                        pin:SetTexture(icon)
                        pin.diaTexture = icon
                    end
                    pin:SetDimensions(sz, sz)
                    pin:SetAlpha(alpha)
                    pin:SetTextureRotation(rot)
                    pin:ClearAnchors()
                    pin:SetAnchor(CENTER, ZO_Compass, CENTER, offsetX, 0)
                    -- Distância até o local do evento
                    local meters = ev.meters
                    if (not meters or meters <= 0) and ev.tag then
                        meters = WorldDistMeters(ev.tag)
                    end
                    if not meters or meters <= 0 then
                        meters = MapDistMeters(ev.x, ev.y, px, py)
                    end
                    if pin.distLabel then
                        pin.distLabel:SetText(FormatMeters(meters))
                        pin.distLabel:SetHidden(false)
                    end
                    pin:SetHidden(false)
                end
            end
        end
    end
    for i = used + 1, #weCompassPins do
        weCompassPins[i]:SetHidden(true)
    end
end

function CompassModule:StartWorldEventCompass()
    if self.weCompassStarted then return end
    self.weCompassStarted = true
    EVENT_MANAGER:RegisterForUpdate(WE_UPDATE_NS, 50, UpdateWorldEventCompass)
end

NAGA_UI.OnAddonLoaded(function()
    CompassModule:RefreshSettings()
    CompassModule:StartWorldEventCompass()
    zo_callLater(function()
        CompassModule:RefreshSettings()
        CompassModule:StartWorldEventCompass()
    end, 1000)
end)
