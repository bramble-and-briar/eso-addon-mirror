local Randwache = _G.Randwache or {}
_G.Randwache = Randwache
Randwache.name = "Randwache"
Randwache.displayName = "|c7FC7FFRandwache|r"
Randwache.version = "2.0.0"
Randwache.savedVariableName = "RandwacheSavedVariables"

local WM = WINDOW_MANAGER

-- Localization: German client -> German, every other client -> English.
local language = "en"
local clientLanguage = GetCVar("language.2")
if clientLanguage and string.lower(string.sub(clientLanguage, 1, 2)) == "de" then
    language = "de"
end

local localization = Randwache_L10N or {}
local L = localization[language] or localization.en or localization.de or {}
local fallbackL = localization.en or localization.de or {}

local function T(key)
    return L[key] or fallbackL[key] or key
end

local defaults = {
    enabled = true,

    death = {
        enabled = true,
        darkness = 100,
        fadeMs = 1250,
        returnFadeMs = 2800,
    },

    health = {
        enabled = true,
        threshold = 35,
        color = { r = 0.90, g = 0.02, b = 0.02, a = 0.88 },
        pulse = true,
        intensity = 80,
        randomize = true,
        extraSpatters = true,
        afterBleed = true,
        afterBleedIntensity = 80,
    },

    magicka = {
        enabled = true,
        threshold = 25,
        color = { r = 0.08, g = 0.25, b = 0.95, a = 0.52 },
        intensity = 90,
        randomize = true,
        extraSurges = true,
        deepen = true,
        deepenIntensity = 85,
    },

    stamina = {
        enabled = true,
        threshold = 25,
        color = { r = 0.72, g = 0.68, b = 0.48, a = 0.58 },
        intensity = 85,
        randomize = true,
        extraClouds = true,
        deepen = true,
        deepenIntensity = 80,
    },
}

-- Expose only the pieces required by RandwacheSettings.lua.
-- The effect logic itself remains private in this file.
Randwache.defaults = defaults
Randwache.Translate = T

local resources = {
    health = POWERTYPE_HEALTH,
    magicka = POWERTYPE_MAGICKA,
    stamina = POWERTYPE_STAMINA,
}

local function Clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

-- Eigener kleiner Zufallsgenerator, damit Randwache nicht den globalen
-- Lua-Zufallsgenerator anderer AddOns beeinflusst.
function Randwache:Random(minimum, maximum)
    if not self.randomState then
        self.randomState = ((GetTimeStamp() or 1) * 1103515245 + (GetFrameTimeMilliseconds() or 1)) % 2147483647
        if self.randomState <= 0 then self.randomState = 13579 end
    end

    self.randomState = (self.randomState * 48271) % 2147483647
    local unit = self.randomState / 2147483647

    if minimum == nil then
        return unit
    end
    if maximum == nil then
        maximum = minimum
        minimum = 1
    end

    return math.floor(minimum + unit * (maximum - minimum + 1))
end

function Randwache:GetPercent(powerType)
    local current, maximum = GetUnitPower("player", powerType)
    if not maximum or maximum <= 0 then return 100 end
    return (current / maximum) * 100
end

function Randwache:GetSeverity(setting, percent)
    if percent > setting.threshold then return 0 end
    local threshold = math.max(setting.threshold, 1)
    return Clamp(1 - (percent / threshold), 0, 1)
end

local function SetupBackdrop(control)
    control:SetMouseEnabled(false)
    control:SetEdgeColor(0, 0, 0, 0)
    control:SetHidden(true)
end

function Randwache:CreateFullscreenBackdrop(name)
    local control = WM:CreateControl(name, self.root, CT_BACKDROP)
    control:SetAnchorFill(self.root)
    SetupBackdrop(control)
    return control
end

function Randwache:CreateBand(name, anchorPoint, relativePoint, offsetX, offsetY, width, height)
    local control = WM:CreateControl(name, self.root, CT_BACKDROP)
    control:SetAnchor(anchorPoint, self.root, relativePoint, offsetX, offsetY)
    control:SetDimensions(width, height)
    SetupBackdrop(control)
    return control
end

function Randwache:CreateRoot()
    self.root = WM:CreateTopLevelWindow("RandwacheRoot")
    self.root:SetAnchorFill(GuiRoot)
    self.root:SetMouseEnabled(false)
    self.root:SetDrawTier(DT_HIGH)
    self.root:SetDrawLayer(DL_OVERLAY)
    self.root:SetHidden(false)

    self.magickaOverlay = self:CreateFullscreenBackdrop("RandwacheMagickaOverlay")

    self.magickaTexture = WM:CreateControl("RandwacheMagickaTexture", self.root, CT_TEXTURE)
    self.magickaTexture:SetAnchorFill(self.root)
    self.magickaTexture:SetTexture("Randwache/textures/magicka_slime_1.dds")
    self.magickaTexture:SetTextureCoords(0, 1, 0, 1)
    self.magickaTexture:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    self.magickaTexture:SetMouseEnabled(false)
    self.magickaTexture:SetHidden(true)

    self.magickaSurges = {}
    for i = 1, 6 do
        local t = WM:CreateControl("RandwacheMagickaSurge" .. i, self.root, CT_TEXTURE)
        t:SetTexture("Randwache/textures/magicka_blob_1.dds")
        t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        t:SetMouseEnabled(false)
        t:SetHidden(true)
        self.magickaSurges[i] = t
    end

    self.staminaTexture = WM:CreateControl("RandwacheStaminaTexture", self.root, CT_TEXTURE)
    self.staminaTexture:SetAnchorFill(self.root)
    self.staminaTexture:SetTexture("Randwache/textures/stamina_streaks_1.dds")
    self.staminaTexture:SetTextureCoords(0, 1, 0, 1)
    self.staminaTexture:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    self.staminaTexture:SetMouseEnabled(false)
    self.staminaTexture:SetHidden(true)

    self.staminaClouds = {}
    for i = 1, 6 do
        local t = WM:CreateControl("RandwacheStaminaCloud" .. i, self.root, CT_TEXTURE)
        t:SetTexture("Randwache/textures/stamina_cluster_1.dds")
        t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        t:SetMouseEnabled(false)
        t:SetHidden(true)
        self.staminaClouds[i] = t
    end

    -- Ein Haupt-Blutmuster, dessen Datei und Spiegelung bei jeder neuen
    -- Lebenswarnung neu ausgewählt werden können.
    self.healthTexture = WM:CreateControl("RandwacheHealthTexture", self.root, CT_TEXTURE)
    self.healthTexture:SetAnchorFill(self.root)
    self.healthTexture:SetTexture("Randwache/textures/blood_overlay_1.dds")
    self.healthTexture:SetTextureCoords(0, 1, 0, 1)
    self.healthTexture:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    self.healthTexture:SetMouseEnabled(false)
    self.healthTexture:SetHidden(true)

    self.healthTint = self:CreateFullscreenBackdrop("RandwacheHealthTint")

    -- Bis zu sechs zusätzliche Spritzer. Position, Größe, Spiegelung und
    -- Textur werden pro neuer Warnung neu gewürfelt.
    self.bloodSpatters = {}
    for i = 1, 6 do
        local t = WM:CreateControl("RandwacheBloodSpatter" .. i, self.root, CT_TEXTURE)
        t:SetTexture("Randwache/textures/blood_splatter_1.dds")
        t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        t:SetMouseEnabled(false)
        t:SetHidden(true)
        self.bloodSpatters[i] = t
    end

    -- Acht dunklere Nachblut-Flecken. Sie werden bei jeder neuen
    -- Lebenswarnung vorbereitet, erscheinen aber erst stufenweise,
    -- wenn das Leben weiter sinkt.
    self.afterBleedSpots = {}
    for i = 1, 8 do
        local t = WM:CreateControl("RandwacheAfterBleed" .. i, self.root, CT_TEXTURE)
        t:SetTexture("Randwache/textures/blood_splatter_1.dds")
        t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        t:SetMouseEnabled(false)
        t:SetHidden(true)
        self.afterBleedSpots[i] = t
    end

    self.staminaBands = {
        self:CreateBand("RandwacheStaminaTop", TOPLEFT, TOPLEFT, 0, 0, GuiRoot:GetWidth(), 135),
        self:CreateBand("RandwacheStaminaBottom", BOTTOMLEFT, BOTTOMLEFT, 0, 0, GuiRoot:GetWidth(), 170),
        self:CreateBand("RandwacheStaminaLeft", TOPLEFT, TOPLEFT, 0, 0, 150, GuiRoot:GetHeight()),
        self:CreateBand("RandwacheStaminaRight", TOPRIGHT, TOPRIGHT, 0, 0, 150, GuiRoot:GetHeight()),
    }

    -- TOD: eigener niedriger Zeichen-Tier. Dadurch liegen ESO-Dialoge und
    -- Wiederbelebungs-Optionen immer ueber dem Todesmantel.
    self.deathRoot = WM:CreateTopLevelWindow("RandwacheDeathRoot")
    self.deathRoot:SetAnchorFill(GuiRoot)
    self.deathRoot:SetMouseEnabled(false)
    self.deathRoot:SetDrawTier(DT_LOW)
    self.deathRoot:SetDrawLayer(DL_BACKGROUND)
    self.deathRoot:SetDrawLevel(0)
    self.deathRoot:SetHidden(false)

    self.deathOverlay = WM:CreateControl("RandwacheDeathOverlay", self.deathRoot, CT_TEXTURE)
    self.deathOverlay:SetAnchorFill(self.deathRoot)
    self.deathOverlay:SetTexture("Randwache/textures/death_cloak_stage_1.dds")
    self.deathOverlay:SetTextureCoords(0, 1, 0, 1)
    self.deathOverlay:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    self.deathOverlay:SetMouseEnabled(false)
    self.deathOverlay:SetDrawLayer(DL_BACKGROUND)
    self.deathOverlay:SetDrawLevel(0)
    self.deathOverlay:SetColor(1, 1, 1, 0)
    self.deathOverlay:SetHidden(true)

    self.root:SetHandler("OnUpdate", function(_, timeMs)
        self:OnUpdate(timeMs)
    end)
end

function Randwache:SetBackdrop(control, color, alpha)
    control:SetCenterColor(color.r, color.g, color.b, Clamp(alpha, 0, 1))
    control:SetHidden(alpha <= 0.001)
end

function Randwache:HideControls(controls)
    for _, control in ipairs(controls) do control:SetHidden(true) end
end

function Randwache:SetMirroredTextureCoords(texture, flipX, flipY)
    local left, right = 0, 1
    local top, bottom = 0, 1
    if flipX then left, right = 1, 0 end
    if flipY then top, bottom = 1, 0 end
    texture:SetTextureCoords(left, right, top, bottom)
end

function Randwache:RandomizeBloodPattern()
    local pattern = self:Random(1, 6)
    local flipX = self:Random(0, 1) == 1
    local flipY = self:Random(0, 1) == 1

    self.healthTexture:SetTexture("Randwache/textures/blood_overlay_" .. pattern .. ".dds")
    self:SetMirroredTextureCoords(self.healthTexture, flipX, flipY)

    -- Kleine zusätzliche Variation der Gesamtdichte.
    self.currentPatternStrength = 0.90 + self:Random() * 0.18

    for _, t in ipairs(self.bloodSpatters) do
        t:SetHidden(true)
    end

    if not self.sv.health.extraSpatters then
        self:RandomizeAfterBleedSpots()
        return
    end

    local count = self:Random(3, 6)
    local screenW = GuiRoot:GetWidth()
    local screenH = GuiRoot:GetHeight()

    for i = 1, count do
        local t = self.bloodSpatters[i]
        local splatter = self:Random(1, 4)
        local size = self:Random(180, 470)

        -- Meist am äußeren Sichtfeld, manchmal etwas weiter innen.
        local side = self:Random(1, 4)
        local x, y
        local depthX = math.floor(screenW * 0.28)
        local depthY = math.floor(screenH * 0.32)

        if side == 1 then
            x = self:Random(0, math.floor(screenW))
            y = self:Random(0, depthY)
        elseif side == 2 then
            x = self:Random(0, math.floor(screenW))
            y = self:Random(math.floor(screenH - depthY), math.floor(screenH))
        elseif side == 3 then
            x = self:Random(0, depthX)
            y = self:Random(0, math.floor(screenH))
        else
            x = self:Random(math.floor(screenW - depthX), math.floor(screenW))
            y = self:Random(0, math.floor(screenH))
        end

        t:ClearAnchors()
        t:SetAnchor(CENTER, self.root, TOPLEFT, x, y)
        t:SetDimensions(size, size)
        t:SetTexture("Randwache/textures/blood_splatter_" .. splatter .. ".dds")
        self:SetMirroredTextureCoords(t, self:Random(0,1) == 1, self:Random(0,1) == 1)

        -- Eigene Intensität pro Spritzer.
        t.randStrength = 0.50 + self:Random() * 0.40
        t:SetHidden(false)
    end

    self:RandomizeAfterBleedSpots()
end

function Randwache:RandomizeAfterBleedSpots()
    local screenW = GuiRoot:GetWidth()
    local screenH = GuiRoot:GetHeight()

    self.afterBleedStage = 0

    for i, t in ipairs(self.afterBleedSpots) do
        local stage = math.ceil(i / 2)
        local splatter = self:Random(1, 4)

        -- Je kritischer das Leben wird, desto weiter duerfen neue Flecken
        -- vom Rand ins Sichtfeld hineinreichen.
        local depthX = math.floor(screenW * (0.18 + stage * 0.045))
        local depthY = math.floor(screenH * (0.20 + stage * 0.050))

        local side = self:Random(1, 4)
        local x, y

        if side == 1 then
            x = self:Random(math.floor(screenW * 0.06), math.floor(screenW * 0.94))
            y = self:Random(math.floor(screenH * 0.03), depthY)
        elseif side == 2 then
            x = self:Random(math.floor(screenW * 0.06), math.floor(screenW * 0.94))
            y = self:Random(math.floor(screenH - depthY), math.floor(screenH * 0.97))
        elseif side == 3 then
            x = self:Random(math.floor(screenW * 0.03), depthX)
            y = self:Random(math.floor(screenH * 0.06), math.floor(screenH * 0.94))
        else
            x = self:Random(math.floor(screenW - depthX), math.floor(screenW * 0.97))
            y = self:Random(math.floor(screenH * 0.06), math.floor(screenH * 0.94))
        end

        local baseSize = 150 + stage * 24
        local size = self:Random(baseSize, baseSize + 150)

        t:ClearAnchors()
        t:SetAnchor(CENTER, self.root, TOPLEFT, x, y)
        t:SetDimensions(size, size)
        t:SetTexture("Randwache/textures/blood_splatter_" .. splatter .. ".dds")
        self:SetMirroredTextureCoords(t, self:Random(0,1) == 1, self:Random(0,1) == 1)

        t.bleedStage = stage
        t.randStrength = 0.58 + self:Random() * 0.42
        t.fadeStart = nil
        t:SetHidden(true)
    end
end

function Randwache:GetAfterBleedStage(percent)
    local threshold = math.max(self.sv.health.threshold or 35, 1)

    -- Vier Stufen relativ zur eingestellten Warnschwelle.
    if percent <= threshold * 0.15 then return 4 end
    if percent <= threshold * 0.30 then return 3 end
    if percent <= threshold * 0.50 then return 2 end
    if percent <= threshold * 0.75 then return 1 end
    return 0
end

function Randwache:UpdateAfterBleed(percent, timeMs, test)
    -- Beim Zuruecksetzen auf Standardwerte koennen gespeicherte
    -- Unterwerte fuer einen kurzen Moment auf nil setzen. Darum hier
    -- alle benoetigten Werte defensiv auf die Defaults zurueckfallen lassen.
    local healthDefaults = defaults.health or {}
    local s = self.sv.health or healthDefaults

    if s.afterBleedIntensity == nil then
        s.afterBleedIntensity = healthDefaults.afterBleedIntensity or 75
    end
    if s.threshold == nil then
        s.threshold = healthDefaults.threshold or 35
    end
    if s.color == nil then
        s.color = {
            r = (healthDefaults.color and healthDefaults.color.r) or 0.90,
            g = (healthDefaults.color and healthDefaults.color.g) or 0.02,
            b = (healthDefaults.color and healthDefaults.color.b) or 0.02,
            a = (healthDefaults.color and healthDefaults.color.a) or 0.88,
        }
    end
    if s.color.a == nil then
        s.color.a = (healthDefaults.color and healthDefaults.color.a) or 0.88
    end

    if not self.sv.enabled or not s.enabled or not s.afterBleed then
        self:HideControls(self.afterBleedSpots)
        self.afterBleedStage = 0
        return
    end

    local targetStage

    if test then
        -- Beim Test laufen die vier Stufen nacheinander durch.
        local elapsed = math.max(0, (timeMs or 0) - (self.testBleedStart or (timeMs or 0)))
        targetStage = Clamp(math.floor(elapsed / 650) + 1, 1, 4)
    else
        targetStage = self:GetAfterBleedStage(percent)
    end

    local oldStage = self.afterBleedStage or 0

    if targetStage > oldStage then
        for _, t in ipairs(self.afterBleedSpots) do
            if t.bleedStage and t.bleedStage > oldStage and t.bleedStage <= targetStage then
                t.fadeStart = timeMs or GetFrameTimeMilliseconds()
            end
        end
    elseif targetStage < oldStage then
        -- Bei Heilung verschwinden nur die spaeteren Flecken.
        -- Fallen die Lebenspunkte erneut, bluten sie wieder weich ein.
        for _, t in ipairs(self.afterBleedSpots) do
            if t.bleedStage and t.bleedStage > targetStage then
                t:SetHidden(true)
                t.fadeStart = nil
            end
        end
    end

    self.afterBleedStage = targetStage

    local defaultColor = defaults.health.color or { r = 0.90, g = 0.02, b = 0.02, a = 0.88 }
    local c = s.color or defaultColor
    local cr = tonumber(c.r) or tonumber(defaultColor.r) or 0.90
    local cg = tonumber(c.g) or tonumber(defaultColor.g) or 0.02
    local cb = tonumber(c.b) or tonumber(defaultColor.b) or 0.02
    local ca = tonumber(c.a) or tonumber(defaultColor.a) or 0.88
    local intensity = Clamp((tonumber(s.afterBleedIntensity) or defaults.health.afterBleedIntensity or 80) / 100, 0, 1)

    -- Deutlich dunkler als die normale Blutfarbe.
    local r = Clamp(cr * 0.52, 0, 1)
    local g = Clamp(cg * 0.38, 0, 1)
    local b = Clamp(cb * 0.38, 0, 1)

    for _, t in ipairs(self.afterBleedSpots) do
        if t.bleedStage and t.bleedStage <= targetStage then
            if not t.fadeStart then
                t.fadeStart = timeMs or GetFrameTimeMilliseconds()
            end

            local elapsed = math.max(0, (timeMs or 0) - t.fadeStart)
            local fade = Clamp(elapsed / 1100, 0, 1)

            -- Weicher "Smoothstep"-Einstieg statt ploetzlichem Aufploppen.
            fade = fade * fade * (3 - 2 * fade)

            local stageBoost = 0.72 + ((tonumber(t.bleedStage) or 1) * 0.07)
            local alpha = Clamp(
                ca * intensity * (tonumber(t.randStrength) or 0.75) * stageBoost * fade,
                0,
                0.92
            )

            t:SetColor(r, g, b, alpha)
            t:SetHidden(alpha <= 0.01)
        end
    end
end

function Randwache:CheckHealthWarningTransition(percent)
    local s = self.sv.health
    local warningNow = self.sv.enabled and s.enabled and percent <= s.threshold

    if warningNow and not self.healthWarningActive then
        self.healthWarningActive = true
        if s.randomize then
            self:RandomizeBloodPattern()
        elseif not self.currentPatternStrength then
            self.currentPatternStrength = 1
        end
    elseif not warningNow and self.healthWarningActive then
        self.healthWarningActive = false
    end
end

function Randwache:RandomizeResourcePattern(kind)
    local screenW = GuiRoot:GetWidth()
    local screenH = GuiRoot:GetHeight()

    if kind == "magicka" then
        -- Schleim-Grundmuster: sechs unterschiedliche Varianten.
        self.magickaTexture:SetTexture("Randwache/textures/magicka_slime_" .. self:Random(1,6) .. ".dds")
        self:SetMirroredTextureCoords(self.magickaTexture, self:Random(0,1)==1, self:Random(0,1)==1)
        self.magickaPatternStrength = 0.86 + self:Random() * 0.20

        -- Zusätzliche Schleimflecken nur in Randnähe.
        -- Die Bildschirmmitte bleibt dadurch als Sichtfenster frei.
        for _, t in ipairs(self.magickaSurges) do
            t:SetHidden(true)
            t.randStrength=nil
        end

        if self.sv.magicka.extraSurges then
            local count = self:Random(3,6)

            for i=1,count do
                local t=self.magickaSurges[i]
                local size=self:Random(220,520)
                local side=self:Random(1,4)
                local x,y

                if side==1 then
                    x=self:Random(math.floor(screenW*0.03),math.floor(screenW*0.97))
                    y=self:Random(0,math.floor(screenH*0.22))
                elseif side==2 then
                    x=self:Random(math.floor(screenW*0.03),math.floor(screenW*0.97))
                    y=self:Random(math.floor(screenH*0.78),math.floor(screenH))
                elseif side==3 then
                    x=self:Random(0,math.floor(screenW*0.18))
                    y=self:Random(math.floor(screenH*0.05),math.floor(screenH*0.95))
                else
                    x=self:Random(math.floor(screenW*0.82),math.floor(screenW))
                    y=self:Random(math.floor(screenH*0.05),math.floor(screenH*0.95))
                end

                t:ClearAnchors()
                t:SetAnchor(CENTER,self.root,TOPLEFT,x,y)
                t:SetDimensions(size,size)
                t:SetTexture("Randwache/textures/magicka_blob_"..self:Random(1,4)..".dds")
                self:SetMirroredTextureCoords(t,self:Random(0,1)==1,self:Random(0,1)==1)
                t.randStrength=0.42+self:Random()*0.48
                t:SetHidden(false)
            end
        end

    elseif kind == "stamina" then
        -- Ausdauer: wechselnde Belastungs-/Bewegungsstriche.
        self.staminaTexture:SetTexture("Randwache/textures/stamina_streaks_" .. self:Random(1,6) .. ".dds")
        self:SetMirroredTextureCoords(self.staminaTexture, self:Random(0,1)==1, self:Random(0,1)==1)
        self.staminaPatternStrength = 0.90 + self:Random() * 0.20

        for _, t in ipairs(self.staminaClouds) do
            t:SetHidden(true)
            t.randStrength=nil
        end

        if self.sv.stamina.extraClouds then
            local count=self:Random(3,6)

            for i=1,count do
                local t=self.staminaClouds[i]
                local size=self:Random(220,480)
                local side=self:Random(1,4)
                local x,y

                if side==1 then
                    x=self:Random(math.floor(screenW*0.06),math.floor(screenW*0.94))
                    y=self:Random(0,math.floor(screenH*0.20))
                elseif side==2 then
                    x=self:Random(math.floor(screenW*0.06),math.floor(screenW*0.94))
                    y=self:Random(math.floor(screenH*0.80),math.floor(screenH))
                elseif side==3 then
                    x=self:Random(0,math.floor(screenW*0.18))
                    y=self:Random(math.floor(screenH*0.06),math.floor(screenH*0.94))
                else
                    x=self:Random(math.floor(screenW*0.82),math.floor(screenW))
                    y=self:Random(math.floor(screenH*0.06),math.floor(screenH*0.94))
                end

                t:ClearAnchors()
                t:SetAnchor(CENTER,self.root,TOPLEFT,x,y)
                t:SetDimensions(size,size)
                t:SetTexture("Randwache/textures/stamina_cluster_"..self:Random(1,4)..".dds")
                self:SetMirroredTextureCoords(t,self:Random(0,1)==1,self:Random(0,1)==1)
                t.randStrength=0.34+self:Random()*0.46
                t:SetHidden(false)
            end
        end
    end
end

function Randwache:GetResourceDeepenStage(setting, percent)
    setting = setting or {}
    local threshold = math.max(tonumber(setting.threshold) or 25, 1)
    if percent <= threshold * 0.15 then return 4 end
    if percent <= threshold * 0.30 then return 3 end
    if percent <= threshold * 0.50 then return 2 end
    if percent <= threshold * 0.75 then return 1 end
    return 0
end

function Randwache:CheckResourceTransitions(magickaPercent, staminaPercent)
    local m=self.sv.magicka
    local magNow=self.sv.enabled and m.enabled and magickaPercent<=m.threshold
    if magNow and not self.magickaWarningActive then
        self.magickaWarningActive=true
        if m.randomize then self:RandomizeResourcePattern("magicka") end
    elseif not magNow and self.magickaWarningActive then
        self.magickaWarningActive=false
    end

    local s=self.sv.stamina
    local staNow=self.sv.enabled and s.enabled and staminaPercent<=s.threshold
    if staNow and not self.staminaWarningActive then
        self.staminaWarningActive=true
        if s.randomize then self:RandomizeResourcePattern("stamina") end
    elseif not staNow and self.staminaWarningActive then
        self.staminaWarningActive=false
    end
end

function Randwache:UpdateMagicka(percent, timeMs)
    local s=self.sv.magicka
    local test=self.testMode=="magicka" or self.testMode=="all"
    local severity=test and 0.90 or self:GetSeverity(s,percent)

    if not self.sv.enabled or not s.enabled or severity<=0 then
        self.magickaOverlay:SetHidden(true)
        self.magickaTexture:SetHidden(true)
        self:HideControls(self.magickaSurges)
        return
    end

    local intensity=Clamp((s.intensity or 90)/100,0,1.5)
    local stage=test and Clamp(
        math.floor(math.max(0,(timeMs or 0)-(self.testMagickaStart or (timeMs or 0)))/650)+1,
        1,4
    ) or self:GetResourceDeepenStage(s,percent)

    -- Wichtig fuer den neuen Schleim-Look:
    -- kein gleichmaessiger Ganzbild-Farbfilter mehr.
    -- Dadurch bleibt die Bildschirmmitte wirklich frei.
    self.magickaOverlay:SetHidden(true)

    local boost=s.deepen and (1+stage*0.16*((s.deepenIntensity or 85)/100)) or 1

    -- Das Grundmuster sitzt vor allem am Rand.
    local alpha=Clamp(
        (s.color.a or 1)
        * (0.42+0.78*severity)
        * intensity
        * (self.magickaPatternStrength or 1)
        * boost,
        0,1.00
    )

    self.magickaTexture:SetColor(s.color.r,s.color.g,s.color.b,alpha)
    self.magickaTexture:SetHidden(false)

    -- Bei sinkender Magicka tauchen mehr Schleimflecken am Rand auf.
    -- Sie wandern bewusst nicht in die freie Bildschirmmitte.
    if s.extraSurges then
        local visibleCount=s.deepen and math.min(6,2+stage) or 4

        for i,t in ipairs(self.magickaSurges) do
            if t.randStrength then
                local a=(i<=visibleCount) and Clamp(alpha*t.randStrength*1.35,0,0.95) or 0
                t:SetColor(s.color.r,s.color.g,s.color.b,a)
                t:SetHidden(a<=0.01)
            end
        end
    end
end

function Randwache:UpdateHealth(percent, timeMs)
    local s = self.sv.health or defaults.health
    local defaultColor = defaults.health.color
    local c = s.color or defaultColor
    local cr = tonumber(c.r) or defaultColor.r
    local cg = tonumber(c.g) or defaultColor.g
    local cb = tonumber(c.b) or defaultColor.b
    local ca = tonumber(c.a) or defaultColor.a
    local test = self.testMode == "health" or self.testMode == "all"
    local severity = test and 0.90 or self:GetSeverity(s, percent)

    if not self.sv.enabled or not s.enabled or severity <= 0 then
        self.healthTexture:SetHidden(true)
        self.healthTint:SetHidden(true)
        self:HideControls(self.bloodSpatters)
        self:HideControls(self.afterBleedSpots)
        self.afterBleedStage = 0
        return
    end

    local pulse = 1
    if s.pulse then pulse = 0.90 + 0.10 * math.sin((timeMs or 0) / 220) end
    local intensity = Clamp((s.intensity or 80) / 100, 0, 1)
    local patternStrength = self.currentPatternStrength or 1
    local alpha = Clamp(ca * (0.30 + 0.70 * severity) * intensity * patternStrength * pulse, 0, 1)

    self.healthTexture:SetColor(cr, cg, cb, alpha)
    self.healthTexture:SetHidden(false)

    if s.extraSpatters then
        for _, t in ipairs(self.bloodSpatters) do
            if t.randStrength then t:SetColor(cr,cg,cb,Clamp(alpha*(tonumber(t.randStrength) or 0.75),0,1)) end
        end
    end

    self:SetBackdrop(self.healthTint,{r=cr,g=cg,b=cb,a=ca},ca*(0.012+0.085*severity)*intensity*pulse)
    self:UpdateAfterBleed(percent,timeMs or GetFrameTimeMilliseconds(),test)
end

function Randwache:UpdateStamina(percent, timeMs)
    local s=self.sv.stamina
    local test=self.testMode=="stamina" or self.testMode=="all"
    local severity=test and 0.90 or self:GetSeverity(s,percent)

    if not self.sv.enabled or not s.enabled or severity<=0 then
        self.staminaTexture:SetHidden(true)
        self:HideControls(self.staminaClouds)
        self:HideControls(self.staminaBands)
        return
    end

    local intensity=Clamp((s.intensity or 85)/100,0,1.5)
    local stage=test and Clamp(
        math.floor(math.max(0,(timeMs or 0)-(self.testStaminaStart or (timeMs or 0)))/650)+1,
        1,4
    ) or self:GetResourceDeepenStage(s,percent)

    local boost=s.deepen and (1+stage*0.14*((s.deepenIntensity or 80)/100)) or 1

    -- Hauptmuster: verwaschene Bewegungs-/Belastungsstriche vom Rand nach innen.
    local alpha=Clamp(
        (s.color.a or 1)
        * (0.32+0.72*severity)
        * intensity
        * (self.staminaPatternStrength or 1)
        * boost,
        0,1.00
    )

    self.staminaTexture:SetColor(s.color.r,s.color.g,s.color.b,alpha)
    self.staminaTexture:SetHidden(false)

    -- Alte breite Tunnelbänder werden nicht mehr verwendet.
    -- Damit bleibt die Wirkung klar als "Striche" erkennbar.
    self:HideControls(self.staminaBands)

    if s.extraClouds then
        local visibleCount=s.deepen and math.min(6,2+stage) or 4

        for i,t in ipairs(self.staminaClouds) do
            if t.randStrength then
                local a=(i<=visibleCount) and Clamp(alpha*t.randStrength*1.20,0,0.92) or 0

                -- Zusatzcluster etwas heller als das Grundmuster,
                -- damit sie wie flüchtige Belastungszüge wirken.
                t:SetColor(
                    math.min(1,s.color.r*1.08),
                    math.min(1,s.color.g*1.08),
                    math.min(1,s.color.b*1.02),
                    a
                )
                t:SetHidden(a<=0.01)
            end
        end
    end
end


function Randwache:GetNowMs()
    return GetFrameTimeMilliseconds()
end

function Randwache:GetCurrentHealth()
    local current, maximum = GetUnitPower("player", POWERTYPE_HEALTH)
    return current or 0, maximum or 0
end

function Randwache:IsPlayerWithoutLife()
    local current, maximum = self:GetCurrentHealth()
    if maximum and maximum > 0 and current <= 0 then
        return true
    end

    if IsUnitDead("player") then
        return true
    end

    return false
end

function Randwache:SetDeathStage(stage, alpha)
    if not self.deathOverlay then return end

    stage = Clamp(stage or 1, 1, 4)
    alpha = Clamp(alpha or 0, 0, 1)

    if self.currentDeathStage ~= stage then
        self.currentDeathStage = stage
        self.deathOverlay:SetTexture(
            "Randwache/textures/death_cloak_stage_" .. stage .. ".dds"
        )
    end

    self.deathOverlay:SetColor(1, 1, 1, alpha)
    self.deathOverlay:SetHidden(alpha <= 0.001)
end

function Randwache:StartDeathCloak(active, immediate)
    if not self.sv or not self.sv.death or not self.sv.death.enabled then
        active = false
    end

    local duration
    if immediate then
        duration = 0
    elseif active then
        duration = math.max(0, tonumber(self.sv.death.fadeMs) or 1250)
    else
        duration = math.max(0, tonumber(self.sv.death.returnFadeMs) or 2800)
    end

    self.deathCloakStart = self:GetNowMs()
    self.deathCloakDuration = duration

    if immediate then
        self.deathCloakFrom = active and 1 or 0
        self.deathCloakTo = active and 1 or 0
        self.deathCloakProgress = active and 1 or 0
        self:SetDeathStage(active and 4 or 1, active and 1 or 0)
    else
        self.deathCloakFrom = self.deathCloakProgress or (active and 0 or 1)
        self.deathCloakTo = active and 1 or 0
        self.deathOverlay:SetHidden(false)
    end
end

function Randwache:UpdateDeathState()
    if self.deathTestActive then return end

    local noLife = self:IsPlayerWithoutLife()

    if self.playerWithoutLife == nil then
        self.playerWithoutLife = noLife
        self:StartDeathCloak(noLife, true)
        return
    end

    if noLife ~= self.playerWithoutLife then
        self.playerWithoutLife = noLife
        self:StartDeathCloak(noLife, false)
    end
end

function Randwache:UpdateDeathOverlay()
    if not self.deathOverlay then return end

    local from = tonumber(self.deathCloakFrom)
    local target = tonumber(self.deathCloakTo)
    local duration = tonumber(self.deathCloakDuration) or 0

    if from == nil or target == nil then
        return
    end

    local progress
    if duration <= 0 then
        progress = 1
    else
        progress = Clamp(
            (self:GetNowMs() - (self.deathCloakStart or self:GetNowMs())) / duration,
            0,
            1
        )
    end

    local eased = progress * progress * (3 - 2 * progress)
    local cloak = from + (target - from) * eased
    self.deathCloakProgress = cloak

    local stage
    if cloak < 0.22 then
        stage = 1
    elseif cloak < 0.48 then
        stage = 2
    elseif cloak < 0.74 then
        stage = 3
    else
        stage = 4
    end

    local strength = Clamp((tonumber(self.sv.death.darkness) or 100) / 100, 0, 1)
    local alpha
    if stage == 1 then
        alpha = (0.70 + 0.18 * cloak) * strength
    elseif stage == 2 then
        alpha = (0.80 + 0.16 * cloak) * strength
    elseif stage == 3 then
        alpha = (0.90 + 0.08 * cloak) * strength
    else
        alpha = strength
    end

    if cloak <= 0.001 then
        alpha = 0
    end

    self:SetDeathStage(stage, Clamp(alpha, 0, 1))

    if progress >= 1 then
        self.deathCloakProgress = target
        self.deathCloakDuration = 0

        if target >= 1 then
            self:SetDeathStage(4, strength)
        else
            self:SetDeathStage(1, 0)
        end
    end
end

function Randwache:HideResourceEffectsForDeath()
    if self.magickaOverlay then self.magickaOverlay:SetHidden(true) end
    if self.magickaTexture then self.magickaTexture:SetHidden(true) end
    if self.magickaSurges then self:HideControls(self.magickaSurges) end

    if self.healthTexture then self.healthTexture:SetHidden(true) end
    if self.healthTint then self.healthTint:SetHidden(true) end
    if self.bloodSpatters then self:HideControls(self.bloodSpatters) end
    if self.afterBleedSpots then self:HideControls(self.afterBleedSpots) end

    if self.staminaTexture then self.staminaTexture:SetHidden(true) end
    if self.staminaClouds then self:HideControls(self.staminaClouds) end
    if self.staminaBands then self:HideControls(self.staminaBands) end
end

function Randwache:UpdateAll(timeMs)
    if not self.sv or not self.root then return end

    self.lastHealth = self:GetPercent(resources.health)
    self.lastMagicka = self:GetPercent(resources.magicka)
    self.lastStamina = self:GetPercent(resources.stamina)

    self:CheckHealthWarningTransition(self.lastHealth)
    self:CheckResourceTransitions(self.lastMagicka, self.lastStamina)
    local now = timeMs or GetFrameTimeMilliseconds()
    self:UpdateMagicka(self.lastMagicka, now)
    self:UpdateHealth(self.lastHealth, now)
    self:UpdateStamina(self.lastStamina, now)
end

function Randwache:OnUpdate(timeMs)
    if not self.sv then return end

    self:UpdateDeathState()
    self:UpdateDeathOverlay()

    -- Solange der Todesmantel noch sichtbar ist (auch waehrend der langsamen
    -- Geister-Rueckkehr), keine Blut-/Magicka-/Ausdauer-Effekte darueberlegen.
    if (tonumber(self.deathCloakProgress) or 0) > 0.001 then
        self:HideResourceEffectsForDeath()
        return
    end

    if not self.sv.enabled then return end

    if self.sv.health.enabled then
        local test = self.testMode == "health" or self.testMode == "all"
        local severity = test and 0.90 or self:GetSeverity(self.sv.health, self.lastHealth or 100)
        if severity > 0 then self:UpdateHealth(self.lastHealth or 100, timeMs) end
    end
    if self.sv.magicka.enabled then
        local test = self.testMode == "magicka" or self.testMode == "all"
        local severity = test and 0.90 or self:GetSeverity(self.sv.magicka, self.lastMagicka or 100)
        if severity > 0 then self:UpdateMagicka(self.lastMagicka or 100, timeMs) end
    end
    if self.sv.stamina.enabled then
        local test = self.testMode == "stamina" or self.testMode == "all"
        local severity = test and 0.90 or self:GetSeverity(self.sv.stamina, self.lastStamina or 100)
        if severity > 0 then self:UpdateStamina(self.lastStamina or 100, timeMs) end
    end
end

function Randwache:StartTest(key)
    self.testToken = (self.testToken or 0) + 1
    local token = self.testToken

    local now = GetFrameTimeMilliseconds()
    if key == "health" or key == "all" then
        self:RandomizeBloodPattern()
        self.testBleedStart = now
    end
    if key == "magicka" or key == "all" then
        self:RandomizeResourcePattern("magicka")
        self.testMagickaStart = now
    end
    if key == "stamina" or key == "all" then
        self:RandomizeResourcePattern("stamina")
        self.testStaminaStart = now
    end

    self.testMode = key
    self:UpdateAll()

    zo_callLater(function()
        if self.testToken ~= token then return end
        self.testMode = nil
        self.testBleedStart = nil
        self.testMagickaStart = nil
        self.testStaminaStart = nil
        self:UpdateAll()
    end, 4000)
end

function Randwache:Initialize()
    -- SavedVariables are scoped by megaserver so EU, NA and PTS do not
    -- overwrite each other. Existing pre-1.0.2 account-wide settings are
    -- copied once into each server profile as a migration convenience.
    local legacySv = ZO_SavedVars:NewAccountWide(self.savedVariableName, 1, nil, defaults)
    self.sv = ZO_SavedVars:NewAccountWide(self.savedVariableName, 1, GetWorldName(), defaults)

    if not self.sv.serverScopeMigrated then
        local function CopyTable(value)
            if type(value) ~= "table" then return value end
            local copy = {}
            for key, child in pairs(value) do
                copy[key] = CopyTable(child)
            end
            return copy
        end

        for _, key in ipairs({ "enabled", "death", "health", "magicka", "stamina" }) do
            if legacySv[key] ~= nil then
                self.sv[key] = CopyTable(legacySv[key])
            end
        end
        self.sv.serverScopeMigrated = true
    end

    -- Migration von Version 0.1 bis 0.3
    if self.sv.health.pulse == nil then self.sv.health.pulse = defaults.health.pulse end
    if self.sv.health.intensity == nil then self.sv.health.intensity = defaults.health.intensity end
    if self.sv.health.randomize == nil then self.sv.health.randomize = defaults.health.randomize end
    if self.sv.health.extraSpatters == nil then self.sv.health.extraSpatters = defaults.health.extraSpatters end
    if self.sv.health.afterBleed == nil then self.sv.health.afterBleed = defaults.health.afterBleed end
    if self.sv.health.afterBleedIntensity == nil then self.sv.health.afterBleedIntensity = defaults.health.afterBleedIntensity end
    if self.sv.magicka.intensity == nil then self.sv.magicka.intensity = defaults.magicka.intensity end
    if self.sv.magicka.randomize == nil then self.sv.magicka.randomize = defaults.magicka.randomize end
    if self.sv.magicka.extraSurges == nil then self.sv.magicka.extraSurges = defaults.magicka.extraSurges end
    if self.sv.magicka.deepen == nil then self.sv.magicka.deepen = defaults.magicka.deepen end
    if self.sv.magicka.deepenIntensity == nil then self.sv.magicka.deepenIntensity = defaults.magicka.deepenIntensity end
    if self.sv.stamina.intensity == nil then self.sv.stamina.intensity = defaults.stamina.intensity end
    if self.sv.stamina.randomize == nil then self.sv.stamina.randomize = defaults.stamina.randomize end
    if self.sv.stamina.extraClouds == nil then self.sv.stamina.extraClouds = defaults.stamina.extraClouds end
    if self.sv.stamina.deepen == nil then self.sv.stamina.deepen = defaults.stamina.deepen end
    if self.sv.stamina.deepenIntensity == nil then self.sv.stamina.deepenIntensity = defaults.stamina.deepenIntensity end
    if self.sv.death == nil then self.sv.death = {} end
    if self.sv.death.enabled == nil then self.sv.death.enabled = defaults.death.enabled end
    if self.sv.death.darkness == nil then self.sv.death.darkness = defaults.death.darkness end
    if self.sv.death.fadeMs == nil then self.sv.death.fadeMs = defaults.death.fadeMs end
    if self.sv.death.returnFadeMs == nil then self.sv.death.returnFadeMs = defaults.death.returnFadeMs end

    self:CreateRoot()
    self:BuildSettings()
    self:RandomizeBloodPattern()
    self:RandomizeResourcePattern("magicka")
    self:RandomizeResourcePattern("stamina")
    self.playerWithoutLife = nil
    self.deathCloakProgress = 0
    self.deathCloakFrom = 0
    self.deathCloakTo = 0
    self.currentDeathStage = 1
    self.deathTestActive = false
    self.deathTestToken = 0

    local function RegisterPlayerPowerEvent(suffix, powerType)
        local eventName = self.name .. "_Power_" .. suffix
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_POWER_UPDATE, function()
            self:UpdateAll()
        end)
        EVENT_MANAGER:AddFilterForEvent(
            eventName,
            EVENT_POWER_UPDATE,
            REGISTER_FILTER_UNIT_TAG,
            "player"
        )
        EVENT_MANAGER:AddFilterForEvent(
            eventName,
            EVENT_POWER_UPDATE,
            REGISTER_FILTER_POWER_TYPE,
            powerType
        )
    end

    RegisterPlayerPowerEvent("Health", POWERTYPE_HEALTH)
    RegisterPlayerPowerEvent("Magicka", POWERTYPE_MAGICKA)
    RegisterPlayerPowerEvent("Stamina", POWERTYPE_STAMINA)

    EVENT_MANAGER:RegisterForEvent(
        self.name .. "_PlayerActivated",
        EVENT_PLAYER_ACTIVATED,
        function() self:UpdateAll() end
    )

    self:UpdateAll()
    d("|c7FC7FF" .. string.format(T("LOADED"), self.version) .. "|r")
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= Randwache.name then return end
    EVENT_MANAGER:UnregisterForEvent(Randwache.name, EVENT_ADD_ON_LOADED)
    Randwache:Initialize()
end

EVENT_MANAGER:RegisterForEvent(Randwache.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
