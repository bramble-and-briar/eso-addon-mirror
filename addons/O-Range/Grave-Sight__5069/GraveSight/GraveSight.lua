--[[
    GraveSight
    Spectral reticle with combat-aware coloring, danger warnings,
    execute state, and compact insight text.
    Version 0.8.1 (strict event filters)
]]

local ADDON_NAME = "GraveSight"
local LAM2 = LibAddonMenu2

local GraveSight = {}

----------------------------------------------------------------
-- Defaults
----------------------------------------------------------------
GraveSight.defaults = {
    enabled               = true,
    size                  = 70,
    enemyColoring         = true,
    lockRotation          = true,
    enemySoulFlare        = true,

    idleOpacity           = 55,
    stealthOpacity        = 75,
    enemyOpacity          = 75,

    stealthScale          = 0.85,
    pulseStrength         = 0.06,
    soulFlareIntensity    = 100,

    idleRed               = 0.78,
    idleGreen             = 0.72,
    idleBlue              = 0.92,

    stealthRed            = 0.55,
    stealthGreen          = 0.25,
    stealthBlue           = 0.85,

    enemyRed              = 1.00,
    enemyGreen            = 0.18,
    enemyBlue             = 0.18,

    dangerWarningsEnabled = true,
    warnCorrosiveArmor    = true,
    warnFossilize         = true,
    dangerOpacity         = 100,
    dangerPulse           = 0.20,
    dangerRed             = 0.12,
    dangerGreen           = 0.95,
    dangerBlue            = 0.22,

    executeEnabled        = true,
    executeRange          = 0.40,
    executeOpacity        = 100,
    executePulse          = 0.11,
    executeRed            = 0.75,
    executeGreen          = 0.08,
    executeBlue           = 0.18,
    showExecuteText       = true,
    executeMessage        = "REAP",
    showHPInfo            = false,
    hpInfoOnlyInCombat    = false,
    insightFontSize       = 42,
}

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local ROTATION_SPEED        = 0.12
local OPACITY_LERP_SPEED    = 0.14
local STEALTH_LERP_SPEED    = 0.08
local LOCK_ROTATION         = math.rad(60)

local SOUL_FLARE_LERP       = 0.28
local SOUL_FLARE_MIN_MS     = 2200
local SOUL_FLARE_MAX_MS     = 5800
local DANGER_EXPIRE_MS      = 2200

local PULSE_DANGER_DIV      = 65
local PULSE_EXECUTE_DIV     = 80
local PULSE_ENEMY_DIV       = 90

local INSIGHT_FONT_PATH     = "GraveSight/fonts/Friday13v12.slug"
local RETICLE_TEXTURE       = "GraveSight/textures/gravesight.dds"

local HIDDEN_SCENES = {
    inventory   = true,
    skills      = true,
    stats       = true,
    mailInbox   = true,
    mailSend    = true,
    bank        = true,
    store       = true,
    guildRoster = true,
}

----------------------------------------------------------------
-- Danger definitions
----------------------------------------------------------------
local DANGER_DEFS = {
    CorrosiveArmor = {
        enabledKey = "warnCorrosiveArmor",
        ids = {
            17878, 17874, 15957, 33844, 61083, 100982, 54083,
        },
        patterns = {
            "corrosive armor", "magma armor", "magma shell",
        },
    },
    Fossilize = {
        enabledKey = "warnFossilize",
        ids = {
            31816, 31820, 31825,
        },
        patterns = {
            "fossilize", "petrify",
        },
    },
}

local DANGER_ABILITY_IDS = {}
local DANGER_NAME_PATTERNS = {}

for key, def in pairs(DANGER_DEFS) do
    for _, id in ipairs(def.ids) do
        DANGER_ABILITY_IDS[id] = key
    end
    DANGER_NAME_PATTERNS[key] = def.patterns
end

----------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------
local reticle
local texture
local insightLabel

local currentRotation     = 0
local targetRotation      = 0
local currentOpacity      = 0.55
local targetOpacity       = 0.55
local stealthScale        = 1.0
local targetStealthScale  = 1.0
local lockPulseScale      = 1.0

local soulFlareIntensity  = 0
local soulFlareTarget     = 0
local nextSoulFlareTime   = 0

local dangerActive        = false
local dangerType          = nil
local dangerExpireTime    = 0

----------------------------------------------------------------
-- Utility helpers
----------------------------------------------------------------
local function SetVanillaReticleHidden(hidden)
    local alpha = hidden and 0 or 1
    if ZO_ReticleContainerReticle then ZO_ReticleContainerReticle:SetAlpha(alpha) end
    if ZO_ReticleContainerNonInteract then ZO_ReticleContainerNonInteract:SetAlpha(alpha) end
    if ZO_ReticleContainerNonInteractText then ZO_ReticleContainerNonInteractText:SetAlpha(alpha) end
    if ZO_ReticleContainerStealthIcon then ZO_ReticleContainerStealthIcon:SetHidden(hidden) end
    if ZO_ReticleContainerStealthIconStealthText then ZO_ReticleContainerStealthIconStealthText:SetHidden(hidden) end
end

local function IsUiOpen()
    local scene = SCENE_MANAGER:GetCurrentScene()
    if scene and HIDDEN_SCENES[scene.name] then return true end
    return IsGameCameraUIModeActive()
end

local function IsPlayerStealthed()
    local state = GetUnitStealthState("player")
    return state == STEALTH_STATE_HIDDEN
        or state == STEALTH_STATE_STEALTH
        or state == STEALTH_STATE_HIDDEN_ALMOST_DETECTED
        or state == STEALTH_STATE_STEALTH_ALMOST_DETECTED
end

local function IsPlayerInCombat()
    return IsUnitInCombat("player")
end

local function GetFlickerMultiplier()
    return 0.95 + (math.random() * 0.10)
end

local function UpdateSize()
    if not reticle then return end
    local finalScale = stealthScale * lockPulseScale
    local finalSize  = math.floor(GraveSight.db.size * finalScale)
    reticle:SetDimensions(finalSize, finalSize)
end

local function ShortHP(value)
    if not value or value <= 0 then return "0" end
    if value < 1000 then return tostring(math.floor(value)) end
    if value < 100000 then return string.format("%.1fk", value / 1000) end
    return string.format("%.0fk", value / 1000)
end

local function UpdateInsightFont()
    if not insightLabel then return end
    local size = GraveSight.db.insightFontSize or 42
    insightLabel:SetFont(INSIGHT_FONT_PATH .. "|" .. size .. "|soft-shadow-thick")
end

local function GetColor(prefix)
    local db = GraveSight.db
    return db[prefix .. "Red"], db[prefix .. "Green"], db[prefix .. "Blue"]
end

----------------------------------------------------------------
-- Soul Flare
----------------------------------------------------------------
local function UpdateSoulFlare(allow)
    if not allow then
        soulFlareIntensity = 0
        soulFlareTarget    = 0
        return
    end

    local now = GetFrameTimeMilliseconds()
    if now >= nextSoulFlareTime and soulFlareIntensity <= 0.01 then
        soulFlareIntensity = 1.0
        soulFlareTarget    = 0.0
        nextSoulFlareTime  = now + math.random(SOUL_FLARE_MIN_MS, SOUL_FLARE_MAX_MS)
    end

    soulFlareIntensity = soulFlareIntensity + ((soulFlareTarget - soulFlareIntensity) * SOUL_FLARE_LERP)
    if soulFlareIntensity < 0.01 then soulFlareIntensity = 0 end
end

local function ApplySoulFlare(r, g, b)
    if not GraveSight.db.enemySoulFlare then return r, g, b end

    local strength = GraveSight.db.soulFlareIntensity / 100
    local flash    = soulFlareIntensity * strength

    return r + ((0.75 - r) * flash),
           g + ((0.35 - g) * flash),
           b + ((0.95 - b) * flash)
end

----------------------------------------------------------------
-- Danger detection
----------------------------------------------------------------
local function IsDangerEnabled(key)
    local def = DANGER_DEFS[key]
    if not def or not GraveSight.db.dangerWarningsEnabled then return false end
    return GraveSight.db[def.enabledKey] == true
end

local function MatchesDangerName(name, key)
    if not name then return false end
    local lower = string.lower(name)
    local patterns = DANGER_NAME_PATTERNS[key]
    if not patterns then return false end
    for _, pattern in ipairs(patterns) do
        if string.find(lower, pattern, 1, true) then return true end
    end
    return false
end

local function ScanUnitForDanger(unitTag)
    if not DoesUnitExist(unitTag) or unitTag == "player" then return nil end

    local numBuffs = GetNumBuffs(unitTag)
    for i = 1, numBuffs do
        local buffName, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, i)

        local key = DANGER_ABILITY_IDS[abilityId]
        if key and IsDangerEnabled(key) then return key end

        for dangerKey in pairs(DANGER_DEFS) do
            if IsDangerEnabled(dangerKey) and MatchesDangerName(buffName, dangerKey) then
                return dangerKey
            end
        end
    end
    return nil
end

local function UpdateDangerState()
    local now = GetFrameTimeMilliseconds()

    if dangerExpireTime > 0 and now > dangerExpireTime then
        dangerActive     = false
        dangerType       = nil
        dangerExpireTime = 0
    end

    local key = ScanUnitForDanger("reticleover")
    if key then
        dangerActive     = true
        dangerType       = key
        dangerExpireTime = 0
        return
    end

    if dangerExpireTime > now then
        dangerActive = true
        return
    end

    dangerActive = false
    dangerType   = nil
end

----------------------------------------------------------------
-- Combat event – STRICT version (one filtered event per ability ID)
----------------------------------------------------------------
local function OnCombatEvent(_, result, isError, abilityName, _, _, _, sourceType, _, targetType, hitValue, _, _, _, _, _, abilityId)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
    if not hitValue or hitValue <= 0 then return end

    local key = DANGER_ABILITY_IDS[abilityId]
    if key and IsDangerEnabled(key) then
        dangerActive     = true
        dangerType       = key
        dangerExpireTime = GetFrameTimeMilliseconds() + DANGER_EXPIRE_MS
    end
end

----------------------------------------------------------------
-- Insight label
----------------------------------------------------------------
local function UpdateInsightLabel(hostile, inCombat, current, max, shield)
    if not insightLabel then return end

    local db   = GraveSight.db
    local show = false
    local text = ""

    if hostile and DoesUnitExist("reticleover") then
        local percent = (max > 0) and (current / max) or 1

        if db.executeEnabled and db.showExecuteText and percent <= db.executeRange then
            text = db.executeMessage or "REAP"
            show = true
        elseif db.showHPInfo and (not db.hpInfoOnlyInCombat or inCombat) then
            if shield and shield > 0 then
                text = string.format("%s  +%s", ShortHP(current), ShortHP(shield))
            else
                text = string.format("%s / %s", ShortHP(current), ShortHP(max))
            end
            show = true
        end
    end

    if show and text ~= "" then
        insightLabel:SetHidden(false)
        insightLabel:SetText(text)

        if dangerActive then
            insightLabel:SetColor(db.dangerRed, db.dangerGreen, db.dangerBlue, 0.95)
        elseif db.executeEnabled and max > 0 and (current / max) <= db.executeRange then
            insightLabel:SetColor(db.executeRed, db.executeGreen, db.executeBlue, 0.95)
        else
            insightLabel:SetColor(0.85, 0.80, 0.95, 0.85)
        end
    else
        insightLabel:SetHidden(true)
    end
end

----------------------------------------------------------------
-- Visual state
----------------------------------------------------------------
local function ApplyVisualState(state, flicker)
    local db = GraveSight.db
    local r, g, b
    local pulseDiv = 90
    local pulseAmt = 0
    local opacityKey = "idleOpacity"
    local useSoulFlare = false
    local forceLockRotation = false

    if state == "danger" then
        r, g, b = GetColor("danger")
        pulseDiv = PULSE_DANGER_DIV
        pulseAmt = db.dangerPulse
        opacityKey = "dangerOpacity"
        forceLockRotation = true
    elseif state == "execute" then
        r, g, b = GetColor("execute")
        pulseDiv = PULSE_EXECUTE_DIV
        pulseAmt = db.executePulse
        opacityKey = "executeOpacity"
        forceLockRotation = true
    elseif state == "enemy" then
        r, g, b = GetColor("enemy")
        pulseDiv = PULSE_ENEMY_DIV
        pulseAmt = db.pulseStrength
        opacityKey = "enemyOpacity"
        useSoulFlare = true
        forceLockRotation = true
    elseif state == "stealth" then
        r, g, b = GetColor("stealth")
        opacityKey = "stealthOpacity"
        useSoulFlare = true
        targetStealthScale = db.stealthScale
    else
        r, g, b = GetColor("idle")
        opacityKey = "idleOpacity"
        useSoulFlare = true
        targetStealthScale = 1.0
    end

    if state ~= "stealth" then targetStealthScale = 1.0 end

    if pulseAmt > 0 then
        lockPulseScale = 1.0 + (math.sin(GetFrameTimeMilliseconds() / pulseDiv) * pulseAmt)
    else
        lockPulseScale = 1.0
    end

    if useSoulFlare then
        r, g, b = ApplySoulFlare(r, g, b)
    end

    texture:SetColor(r, g, b, currentOpacity)
    targetOpacity = (db[opacityKey] / 100) * flicker

    if forceLockRotation and db.lockRotation then
        targetRotation = LOCK_ROTATION
    else
        targetRotation = 0
    end
end

----------------------------------------------------------------
-- Main update
----------------------------------------------------------------
local function UpdateAppearance()
    local db = GraveSight.db

    if not db.enabled then
        if reticle then reticle:SetHidden(true) end
        if insightLabel then insightLabel:SetHidden(true) end
        SetVanillaReticleHidden(false)
        return
    end

    if IsUiOpen() then
        reticle:SetHidden(true)
        if insightLabel then insightLabel:SetHidden(true) end
        SetVanillaReticleHidden(false)
        return
    end

    reticle:SetHidden(false)
    SetVanillaReticleHidden(true)

    local inCombat = IsPlayerInCombat()
    local target   = "reticleover"
    local exists   = DoesUnitExist(target)
    local hostile  = exists and IsUnitAttackable(target)
    local flicker  = GetFlickerMultiplier()

    if inCombat then
        UpdateDangerState()
    else
        dangerActive = false
        dangerType   = nil
        dangerExpireTime = 0
    end

    local current, max = 0, 1
    local shield = 0
    if exists then
        current, max = GetUnitPower(target, POWERTYPE_HEALTH)
        if max <= 0 then max = 1 end

        local shieldInfo = GetUnitAttributeVisualizerEffectInfo(
            target, ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH)
        if shieldInfo and shieldInfo > 0 then shield = shieldInfo end
    end

    local percent   = current / max
    local isExecute = db.executeEnabled and percent <= db.executeRange and hostile

    UpdateSoulFlare(inCombat and hostile and not dangerActive and not isExecute)

    if dangerActive and inCombat then
        ApplyVisualState("danger", flicker)
    elseif isExecute and inCombat then
        ApplyVisualState("execute", flicker)
    elseif hostile and db.enemyColoring and inCombat then
        ApplyVisualState("enemy", flicker)
    elseif IsPlayerStealthed() then
        ApplyVisualState("stealth", flicker)
    else
        ApplyVisualState("idle", flicker)
    end

    stealthScale    = stealthScale    + ((targetStealthScale - stealthScale)    * STEALTH_LERP_SPEED)
    currentRotation = currentRotation + ((targetRotation     - currentRotation) * ROTATION_SPEED)
    currentOpacity  = currentOpacity  + ((targetOpacity      - currentOpacity)  * OPACITY_LERP_SPEED)

    texture:SetTextureRotation(currentRotation)
    texture:SetAlpha(currentOpacity)
    UpdateSize()

    UpdateInsightLabel(hostile, inCombat, current, max, shield)
end

local function RefreshSize()
    UpdateSize()
end

local function ResetColorsAndSettings()
    local d = GraveSight.defaults
    for k, v in pairs(d) do
        if type(v) ~= "table" then
            GraveSight.db[k] = v
        end
    end
    UpdateInsightFont()
end

----------------------------------------------------------------
-- Settings
----------------------------------------------------------------
local function CreateSettings()
    if not LAM2 then return end

    local panelData = {
        type = "panel",
        name = "GraveSight",
        displayName = "GraveSight",
        author = "O-Range",
        version = "0.8.1",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM2:RegisterAddonPanel("GraveSightSettings", panelData)

    local optionsData = {
        { type = "checkbox", name = "Enable GraveSight",
          getFunc = function() return GraveSight.db.enabled end,
          setFunc = function(v) GraveSight.db.enabled = v end },

        { type = "slider", name = "Reticle Size", min = 24, max = 128, step = 1,
          getFunc = function() return GraveSight.db.size end,
          setFunc = function(v) GraveSight.db.size = v; RefreshSize() end },

        { type = "checkbox", name = "Enable Enemy Coloring (in combat only)",
          getFunc = function() return GraveSight.db.enemyColoring end,
          setFunc = function(v) GraveSight.db.enemyColoring = v end },

        { type = "checkbox", name = "Enable Lock Rotation",
          getFunc = function() return GraveSight.db.lockRotation end,
          setFunc = function(v) GraveSight.db.lockRotation = v end },

        { type = "checkbox", name = "Soul Flare on Enemies",
          getFunc = function() return GraveSight.db.enemySoulFlare end,
          setFunc = function(v) GraveSight.db.enemySoulFlare = v end },

        { type = "header", name = "Effects" },

        { type = "slider", name = "Soul Flare Intensity", min = 0, max = 200, step = 1,
          getFunc = function() return GraveSight.db.soulFlareIntensity end,
          setFunc = function(v) GraveSight.db.soulFlareIntensity = v end },

        { type = "slider", name = "Stealth Scale", min = 50, max = 100, step = 1,
          getFunc = function() return math.floor(GraveSight.db.stealthScale * 100) end,
          setFunc = function(v) GraveSight.db.stealthScale = v / 100 end },

        { type = "slider", name = "Enemy Pulse Strength", min = 0, max = 60, step = 1,
          getFunc = function() return math.floor(GraveSight.db.pulseStrength * 100) end,
          setFunc = function(v) GraveSight.db.pulseStrength = v / 100 end },

        { type = "header", name = "Opacity" },

        { type = "slider", name = "Idle Opacity", min = 10, max = 100, step = 1,
          getFunc = function() return GraveSight.db.idleOpacity end,
          setFunc = function(v) GraveSight.db.idleOpacity = v end },

        { type = "slider", name = "Stealth Opacity", min = 10, max = 100, step = 1,
          getFunc = function() return GraveSight.db.stealthOpacity end,
          setFunc = function(v) GraveSight.db.stealthOpacity = v end },

        { type = "slider", name = "Enemy Opacity", min = 10, max = 100, step = 1,
          getFunc = function() return GraveSight.db.enemyOpacity end,
          setFunc = function(v) GraveSight.db.enemyOpacity = v end },

        { type = "header", name = "Colors" },

        { type = "colorpicker", name = "Idle Color",
          getFunc = function() return GraveSight.db.idleRed, GraveSight.db.idleGreen, GraveSight.db.idleBlue end,
          setFunc = function(r, g, b) GraveSight.db.idleRed, GraveSight.db.idleGreen, GraveSight.db.idleBlue = r, g, b end,
          default = { r = 0.78, g = 0.72, b = 0.92 } },

        { type = "colorpicker", name = "Stealth Color",
          getFunc = function() return GraveSight.db.stealthRed, GraveSight.db.stealthGreen, GraveSight.db.stealthBlue end,
          setFunc = function(r, g, b) GraveSight.db.stealthRed, GraveSight.db.stealthGreen, GraveSight.db.stealthBlue = r, g, b end,
          default = { r = 0.55, g = 0.25, b = 0.85 } },

        { type = "colorpicker", name = "Enemy Color",
          getFunc = function() return GraveSight.db.enemyRed, GraveSight.db.enemyGreen, GraveSight.db.enemyBlue end,
          setFunc = function(r, g, b) GraveSight.db.enemyRed, GraveSight.db.enemyGreen, GraveSight.db.enemyBlue = r, g, b end,
          default = { r = 1.00, g = 0.18, b = 0.18 } },

        { type = "header", name = "PvP Danger Warnings" },

        { type = "checkbox", name = "Enable Danger Warnings",
          getFunc = function() return GraveSight.db.dangerWarningsEnabled end,
          setFunc = function(v) GraveSight.db.dangerWarningsEnabled = v end },

        { type = "checkbox", name = "Warn on Corrosive Armor",
          getFunc = function() return GraveSight.db.warnCorrosiveArmor end,
          setFunc = function(v) GraveSight.db.warnCorrosiveArmor = v end },

        { type = "checkbox", name = "Warn on Fossilize",
          getFunc = function() return GraveSight.db.warnFossilize end,
          setFunc = function(v) GraveSight.db.warnFossilize = v end },

        { type = "slider", name = "Danger Opacity", min = 50, max = 100, step = 1,
          getFunc = function() return GraveSight.db.dangerOpacity end,
          setFunc = function(v) GraveSight.db.dangerOpacity = v end },

        { type = "slider", name = "Danger Pulse", min = 0, max = 80, step = 1,
          getFunc = function() return math.floor(GraveSight.db.dangerPulse * 100) end,
          setFunc = function(v) GraveSight.db.dangerPulse = v / 100 end },

        { type = "colorpicker", name = "Danger Color",
          getFunc = function() return GraveSight.db.dangerRed, GraveSight.db.dangerGreen, GraveSight.db.dangerBlue end,
          setFunc = function(r, g, b) GraveSight.db.dangerRed, GraveSight.db.dangerGreen, GraveSight.db.dangerBlue = r, g, b end,
          default = { r = 0.12, g = 0.95, b = 0.22 } },

        { type = "header", name = "Execute & Insight" },

        { type = "checkbox", name = "Enable Execute State",
          getFunc = function() return GraveSight.db.executeEnabled end,
          setFunc = function(v) GraveSight.db.executeEnabled = v end },

        { type = "slider", name = "Execute Range %", min = 5, max = 40, step = 1,
          getFunc = function() return math.floor(GraveSight.db.executeRange * 100) end,
          setFunc = function(v) GraveSight.db.executeRange = v / 100 end },

        { type = "checkbox", name = "Show Execute Text",
          getFunc = function() return GraveSight.db.showExecuteText end,
          setFunc = function(v) GraveSight.db.showExecuteText = v end },

        { type = "editbox", name = "Execute Message",
          getFunc = function() return GraveSight.db.executeMessage end,
          setFunc = function(t) GraveSight.db.executeMessage = t end },

        { type = "slider", name = "Insight Text Size", min = 16, max = 42, step = 1,
          getFunc = function() return GraveSight.db.insightFontSize end,
          setFunc = function(v) GraveSight.db.insightFontSize = v; UpdateInsightFont() end },

        { type = "colorpicker", name = "Execute Color",
          getFunc = function() return GraveSight.db.executeRed, GraveSight.db.executeGreen, GraveSight.db.executeBlue end,
          setFunc = function(r, g, b) GraveSight.db.executeRed, GraveSight.db.executeGreen, GraveSight.db.executeBlue = r, g, b end,
          default = { r = 0.75, g = 0.08, b = 0.18 } },

        { type = "checkbox", name = "Show Compact HP Info",
          getFunc = function() return GraveSight.db.showHPInfo end,
          setFunc = function(v) GraveSight.db.showHPInfo = v end },

        { type = "checkbox", name = "HP Info only while in combat",
          getFunc = function() return GraveSight.db.hpInfoOnlyInCombat end,
          setFunc = function(v) GraveSight.db.hpInfoOnlyInCombat = v end },

        { type = "button", name = "Reset Colors & Settings",
          func = ResetColorsAndSettings, width = "full" },
    }

    LAM2:RegisterOptionControls("GraveSightSettings", optionsData)
end

----------------------------------------------------------------
-- Creation
----------------------------------------------------------------
local function CreateReticle()
    reticle = WINDOW_MANAGER:CreateTopLevelWindow("GraveSightReticle")
    reticle:SetDimensions(GraveSight.db.size, GraveSight.db.size)
    reticle:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reticle:SetMouseEnabled(false)
    reticle:SetDrawLayer(DL_OVERLAY)
    reticle:SetDrawTier(DT_HIGH)

    texture = WINDOW_MANAGER:CreateControl("GraveSightReticleTexture", reticle, CT_TEXTURE)
    texture:SetAnchorFill()
    texture:SetTexture(RETICLE_TEXTURE)

    insightLabel = WINDOW_MANAGER:CreateControl("GraveSightInsight", reticle, CT_LABEL)
    insightLabel:SetFont(INSIGHT_FONT_PATH .. "|42|soft-shadow-thick")
    insightLabel:SetAnchor(BOTTOM, reticle, TOP, 0, -8)
    insightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    insightLabel:SetColor(0.85, 0.80, 0.95, 0.85)
    insightLabel:SetHidden(true)

    currentOpacity = GraveSight.db.idleOpacity / 100
    local r, g, b = GetColor("idle")
    texture:SetColor(r, g, b, currentOpacity)
    reticle:SetHidden(false)

    UpdateInsightFont()
end

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------
local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    GraveSight.db = ZO_SavedVars:NewAccountWide("GraveSightVars", 10, nil, GraveSight.defaults)

    math.randomseed(GetTimeStamp())
    CreateReticle()
    CreateSettings()

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Update", 16, UpdateAppearance)

    -- Strict performance version: one filtered event per danger ability ID
    for abilityId in pairs(DANGER_ABILITY_IDS) do
        local eventName = ADDON_NAME .. "_Combat_" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, OnCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)