local PvPUA = PvPUA
local U = PvPUA.util
local wm = U.wm
local DC_HEX = U.DC_HEX
local AD_HEX = U.AD_HEX
local EP_HEX = U.EP_HEX
local RainbowText = U.RainbowText
local ScreenBounds = U.ScreenBounds
local DetailsFont = U.DetailsFont
local EA_FONT_CHOICES = U.EA_FONT_CHOICES
local SAVED_ACCOUNT_TIP = U.SAVED_ACCOUNT_TIP

--------------------------------------------------
-- Effect Alerts
--------------------------------------------------
PvPUA.effectAlerts = {}

local EA_DAMAGE_TIMEOUT_MS = 3000
local EA_PANEL_WIDTH = 1200
local HK_KEY = "homekeeps"
local HK_TICK_MS = 250

local EA_DEFS = {
    { key = "homekeeps", label = "|cFF8800Home Keeps|r",
      defaultText = "Home Keeps",
      defaultColor = { r = 1, g = 1, b = 1, a = 1 },
      defaultPosY = -335,
      mode = "queue",
      icon = "EsoUI/Art/Campaign/Gamepad/gp_overview_keepIcon.dds" },
    { key = "negate",    label = "|c9B59D0Negate|r",
      defaultText = "ENEMY NEGATE!",
      defaultColor = { r = 0.61, g = 0.35, b = 0.82, a = 1 },
      defaultPosY = -220,
      mode = "effect",
      enabledTip = "Shows an alert when an enemy Negate affects you.",
      icon = "EsoUI/Art/Options/Gamepad/gp_options_combat.dds",
      names = { "Negate Magic", "Suppression Field", "Absorption Field" } },
    { key = "corrosive", label = "|c" .. EP_HEX .. "Corrosive|r",
      defaultText = "ENEMY CORROSIVE!",
      defaultColor = { r = 1, g = 0.2, b = 0.2, a = 1 },
      defaultPosY = -160,
      mode = "damage",
      enabledTip = "Shows an alert when an enemy Corrosive affects you.",
      icon = "EsoUI/Art/Options/Gamepad/gp_options_combat.dds",
      abilityIds = { 17879 } },
}

local EA_NAME_LOOKUP = {}
local EA_ID_LOOKUP = {}
local EA_DEF_BY_KEY = {}
for i = 1, #EA_DEFS do
    EA_DEF_BY_KEY[EA_DEFS[i].key] = EA_DEFS[i]
    if EA_DEFS[i].names then
        for _, n in ipairs(EA_DEFS[i].names) do
            EA_NAME_LOOKUP[n] = EA_DEFS[i].key
        end
    end
    if EA_DEFS[i].abilityIds then
        for _, id in ipairs(EA_DEFS[i].abilityIds) do
            EA_ID_LOOKUP[id] = EA_DEFS[i].key
        end
    end
end

function PvPUA:EAVars(key)
    local sv = self.savedVariables
    if not sv then return nil end
    sv.effectAlerts = sv.effectAlerts or {}
    if not sv.effectAlerts[key] then
        local def
        for i = 1, #EA_DEFS do
            if EA_DEFS[i].key == key then def = EA_DEFS[i] break end
        end
        local dc = def and def.defaultColor or { r = 1, g = 0.2, b = 0.2, a = 1 }
        sv.effectAlerts[key] = {
            enabled     = false,
            messageText = def and def.defaultText or "ALERT",
            posX        = 0,
            posY        = def and def.defaultPosY or -160,
            fontSize    = 45,
            font        = "EsoUI/Common/Fonts/univers67.otf",
            textColor   = { r = dc.r, g = dc.g, b = dc.b, a = 1 },
            pulsate     = false,
            pulseSpeed  = 3,
        }
    end
    return sv.effectAlerts[key]
end

function PvPUA:EAFont(key)
    local v = self:EAVars(key)
    if not v then return "EsoUI/Common/Fonts/univers67.otf|45|outline" end
    return (v.font or "EsoUI/Common/Fonts/univers67.otf") .. "|" .. tostring(v.fontSize or 45) .. "|outline"
end

function PvPUA:EAApplyPosition(key)
    local a = self.effectAlerts[key]
    local v = self:EAVars(key)
    if not a or not v then return end
    local def = EA_DEF_BY_KEY[key]
    a.panel:ClearAnchors()
    a.panel:SetAnchor(CENTER, GuiRoot, CENTER,
        v.posX or 0,
        v.posY or (def and def.defaultPosY) or -160)
end

function PvPUA:EAApplyMetrics(key)
    local a = self.effectAlerts[key]
    local v = self:EAVars(key)
    if not a or not v then return end
    local def = EA_DEF_BY_KEY[key]
    if not def or def.mode ~= "queue" then return end
    local size = v.fontSize or 45
    a.panel:SetDimensions(EA_PANEL_WIDTH, math.ceil(size * 3))
    a.label:SetWidth(EA_PANEL_WIDTH)
end

function PvPUA:EACreatePanel(key)
    if self.effectAlerts[key] then return end
    local panel = wm:CreateTopLevelWindow("PvPUA_Alert_" .. key)
    panel:SetClampedToScreen(true)
    panel:SetDrawLayer(DL_OVERLAY)
    panel:SetDrawTier(DT_HIGH)
    panel:SetDimensions(EA_PANEL_WIDTH, 120)
    panel:SetHidden(true)

    local label = wm:CreateControl(nil, panel, CT_LABEL)
    label:SetAnchor(CENTER, panel, CENTER, 0, 0)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.effectAlerts[key] = { panel = panel, label = label, active = false, preview = false }
    self:EAApplyMetrics(key)
    self:EARefresh(key)
    self:EAApplyPosition(key)
end

function PvPUA:EAIsPlayerDead()
    if type(IsUnitDeadOrReincarnating) == "function" and IsUnitDeadOrReincarnating("player") then
        return true
    end
    if type(IsUnitDead) == "function" and IsUnitDead("player") then
        return true
    end
    return false
end

function PvPUA:EAClearAll()
    for i = 1, #EA_DEFS do
        local key = EA_DEFS[i].key
        if EA_DEFS[i].mode ~= "queue" then
            local a = self.effectAlerts[key]
            if a then a.active = false end
            self:EAStopExpiry(key)
            self:EARefresh(key)
        end
    end
end

--------------------------------------------------
-- Home Keep Queue
--------------------------------------------------
PvPUA.hkQueue = {}

function PvPUA:HKText()
    local q = self.hkQueue
    local parts = {}
    for i = 1, #q do parts[#parts + 1] = q[i].text end
    return table.concat(parts, ", ")
end

function PvPUA:HKStopTick()
    if not self.hkTicking then return end
    self.hkTicking = false
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_HKQueue")
end

function PvPUA:HKStartTick()
    if self.hkTicking then return end
    self.hkTicking = true
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_HKQueue", HK_TICK_MS, function()
        local q = PvPUA.hkQueue
        local now = GetGameTimeMilliseconds()
        local changed = false
        for i = #q, 1, -1 do
            if now >= q[i].expires then
                table.remove(q, i)
                changed = true
            end
        end
        if changed then PvPUA:EARefresh(HK_KEY) end
        if #q == 0 then PvPUA:HKStopTick() end
    end)
end

function PvPUA:HKPush(keepId, text)
    if not self.savedVariables then return end
    local q = self.hkQueue
    local expires = GetGameTimeMilliseconds() + ((self.savedVariables.alertLifespan or 10) * 1000)
    for i = 1, #q do
        if q[i].id == keepId then
            q[i].text = text
            q[i].expires = expires
            self:EARefresh(HK_KEY)
            return
        end
    end
    q[#q + 1] = { id = keepId, text = text, expires = expires }
    self:EARefresh(HK_KEY)
    self:HKStartTick()
end

function PvPUA:HKClear()
    local q = self.hkQueue
    for i = #q, 1, -1 do q[i] = nil end
    self:HKStopTick()
    self:EARefresh(HK_KEY)
end

function PvPUA:EARefresh(key)
    local a = self.effectAlerts[key]
    local v = self:EAVars(key)
    if not a or not v then return end

    local def = EA_DEF_BY_KEY[key]
    if def and def.mode == "queue" then
        local text
        if a.preview then
            text = def.defaultText
        elseif self.savedVariables.alertsEnabled and #self.hkQueue > 0 then
            text = self:HKText()
        end

        if not text or text == "" then
            a.panel:SetHidden(true)
            self:EAStopPulse(key)
            a.label:SetAlpha(1)
            return
        end

        self:EAApplyMetrics(key)
        a.label:SetFont(self:EAFont(key))
        a.label:SetText(text)
        a.label:SetColor(1, 1, 1, 1)
        a.panel:SetHidden(false)

        if v.pulsate then
            self:EAStartPulse(key)
        else
            self:EAStopPulse(key)
            a.label:SetAlpha(1)
        end
        return
    end

    local show = a.preview or (v.enabled and a.active and not self:EAIsPlayerDead())
    if not show then
        a.panel:SetHidden(true)
        self:EAStopPulse(key)
        return
    end

    a.label:SetFont(self:EAFont(key))
    a.label:SetText(v.messageText or "")

    local c = v.textColor
    local r, g, b = 1, 1, 1
    if type(c) == "table" then r, g, b = c.r or 1, c.g or 1, c.b or 1 end
    a.label:SetColor(r, g, b, 1)
    a.panel:SetHidden(false)

    if v.pulsate then self:EAStartPulse(key) else self:EAStopPulse(key) end
end

function PvPUA:EAStartPulse(key)
    local a = self.effectAlerts[key]
    if not a or a.pulsing then return end
    a.pulsing = true
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_EAPulse_" .. key, 50, function()
        local v = PvPUA:EAVars(key)
        local ac = PvPUA.effectAlerts[key]
        if not v or not ac or ac.panel:IsHidden() then return end
        local t = GetGameTimeSeconds() * (v.pulseSpeed or 3)
        local alpha = 0.45 + (0.55 * math.abs(math.sin(t * math.pi)))
        local def = EA_DEF_BY_KEY[key]
        if def and def.mode == "queue" then
            ac.label:SetAlpha(alpha)
            return
        end
        local c = v.textColor
        local r, g, b = 1, 1, 1
        if type(c) == "table" then r, g, b = c.r or 1, c.g or 1, c.b or 1 end
        ac.label:SetColor(r, g, b, alpha)
    end)
end

function PvPUA:EAStopPulse(key)
    local a = self.effectAlerts[key]
    if not a or not a.pulsing then return end
    a.pulsing = false
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_EAPulse_" .. key)
    a.label:SetAlpha(1)
end

local function EAOnEffectChanged(_, changeType, _, effectName, unitTag)
    if unitTag ~= "player" then return end
    local key = EA_NAME_LOOKUP[effectName]
    if not key then return end
    local a = PvPUA.effectAlerts[key]
    if not a then return end
    if changeType == EFFECT_RESULT_FADED then
        a.active = false
    else
        a.active = true
    end
    PvPUA:EARefresh(key)
end

function PvPUA:EAStartExpiry(key)
    local a = self.effectAlerts[key]
    if not a or a.expiring then return end
    a.expiring = true
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_EAExpire_" .. key, 250, function()
        local ac = PvPUA.effectAlerts[key]
        if not ac then return end
        if not ac.active or GetGameTimeMilliseconds() - (ac.lastHit or 0) > EA_DAMAGE_TIMEOUT_MS then
            ac.active = false
            PvPUA:EAStopExpiry(key)
            PvPUA:EARefresh(key)
        end
    end)
end

function PvPUA:EAStopExpiry(key)
    local a = self.effectAlerts[key]
    if not a or not a.expiring then return end
    a.expiring = false
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_EAExpire_" .. key)
end

local function EAOnCombatEvent(_, _, isError, _, _, _, _, _, _, targetType, hitValue,
                               _, _, _, _, _, abilityId)
    if isError then return end
    if targetType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if not hitValue or hitValue <= 0 then return end
    local key = EA_ID_LOOKUP[abilityId]
    if not key then return end
    local a = PvPUA.effectAlerts[key]
    if not a then return end
    a.lastHit = GetGameTimeMilliseconds()
    if not a.active then
        a.active = true
        PvPUA:EARefresh(key)
        PvPUA:EAStartExpiry(key)
    end
end

function PvPUA:EAApplyCombatListener()
    local wanted = false
    for i = 1, #EA_DEFS do
        if EA_DEFS[i].mode == "damage" and self:EAVars(EA_DEFS[i].key).enabled then
            wanted = true
            break
        end
    end

    if wanted == self.eaCombatRegistered then return end
    self.eaCombatRegistered = wanted

    for id in pairs(EA_ID_LOOKUP) do
        local name = PvPUA.name .. "_DamageAlert_" .. tostring(id)
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
        if wanted then
            EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, EAOnCombatEvent)
            if EVENT_MANAGER.AddFilterForEvent then
                pcall(function()
                    EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
                        REGISTER_FILTER_ABILITY_ID, id,
                        REGISTER_FILTER_IS_ERROR, false)
                end)
            end
        end
    end

    if not wanted then
        for i = 1, #EA_DEFS do
            if EA_DEFS[i].mode == "damage" then
                local a = self.effectAlerts[EA_DEFS[i].key]
                if a then a.active = false end
                self:EAStopExpiry(EA_DEFS[i].key)
                self:EARefresh(EA_DEFS[i].key)
            end
        end
    end
end

function PvPUA:EAInit()
    for i = 1, #EA_DEFS do
        self:EACreatePanel(EA_DEFS[i].key)
    end
    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_EffectAlert", EVENT_EFFECT_CHANGED, EAOnEffectChanged)
    if EVENT_MANAGER.AddFilterForEvent then
        pcall(function()
            EVENT_MANAGER:AddFilterForEvent(PvPUA.name .. "_EffectAlert", EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_UNIT_TAG, "player")
        end)
    end
    self.eaCombatRegistered = false
    self:EAApplyCombatListener()
end

--------------------------------------------------
-- Settings Details
--------------------------------------------------
local PREVIEW_TIP     = "Shows it on screen so you can place it. Stays on until you turn it off."
local PULSATE_TIP     = "Makes the alert fade in and out."
local PULSE_SPEED_TIP = "How fast the alert pulses. 1 is the slowest, 10 is the fastest. Default is 3."

local function DefaultTextTip(text)
    return "Leave it empty to use the default: " .. tostring(text or "")
end

function PvPUA:HKBuildSettings(def)
    local key = def.key
    local screenW, screenH = ScreenBounds()
    local halfW, halfH = math.ceil(screenW / 10) * 5, math.ceil(screenH / 10) * 5
    local function Sample()
        local v = self:EAVars(key)
        return def.defaultText, DetailsFont(v.font, v.fontSize), 1, 1, 1
    end
    return { type = "submenu", name = def.label, icon = def.icon, options = {
        { type = "toggle", name = "Preview",
          tooltip = PREVIEW_TIP,
          getFunc = function() return self.effectAlerts[key] and self.effectAlerts[key].preview or false end,
          setFunc = function(v)
              if self.effectAlerts[key] then self.effectAlerts[key].preview = v end
              self:EARefresh(key)
          end },
        { type = "slider", name = "Horizontal Position", min = -halfW, max = halfW, step = 5,
          default = 0,
          tooltip = "Default is 0.",
          getFunc = function() return self:EAVars(key).posX end,
          setFunc = function(v) self:EAVars(key).posX = v; self:EAApplyPosition(key) end },
        { type = "slider", name = "Vertical Position", min = -halfH, max = halfH, step = 5,
          default = def.defaultPosY or -160,
          tooltip = "Default is " .. (def.defaultPosY or -160) .. ".",
          getFunc = function() return self:EAVars(key).posY end,
          setFunc = function(v) self:EAVars(key).posY = v; self:EAApplyPosition(key) end },


        { type = "toggle", name = "Enabled", preset = "YES_NO",
          tooltip = "Shows an alert when a home keep comes under attack.",
          default = PvPUA.defaults.alertsEnabled,
          getFunc = function() return self.savedVariables.alertsEnabled end,
          setFunc = function(v)
              self.savedVariables.alertsEnabled = v
              if not v then self:HKClear() end
              self:EARefresh(key)
          end },
        { type = "slider", name = "Duration", min = 5, max = 30, step = 1,
          tooltip = "How long each keep stays on screen (seconds). Default is " .. PvPUA.defaults.alertLifespan .. ".",
          default = PvPUA.defaults.alertLifespan,
          getFunc = function() return self.savedVariables.alertLifespan end,
          setFunc = function(v) self.savedVariables.alertLifespan = v end },


        { type = "slider", name = "Size", min = 25, max = 90, step = 1,
          tooltip = "Default is 45.",
          default = 45,
          getFunc = function() return self:EAVars(key).fontSize end,
          setFunc = function(v) self:EAVars(key).fontSize = v; self:EARefresh(key) end },
        { type = "dropdown", name = "Font",
          choices = EA_FONT_CHOICES,
          default = "EsoUI/Common/Fonts/univers67.otf",
          sample = Sample,
          getFunc = function() return self:EAVars(key).font end,
          setFunc = function(v) self:EAVars(key).font = v; self:EARefresh(key) end },
        { type = "toggle", name = "Pulsate", preset = "YES_NO",
          tooltip = PULSATE_TIP,
          default = false,
          getFunc = function() return self:EAVars(key).pulsate end,
          setFunc = function(v) self:EAVars(key).pulsate = v; self:EARefresh(key) end },
        { type = "slider", name = "Pulse Speed", min = 1, max = 10, step = 1,
          tooltip = PULSE_SPEED_TIP,
          default = 3,
          disabled = function() return not self:EAVars(key).pulsate end,
          getFunc = function() return self:EAVars(key).pulseSpeed end,
          setFunc = function(v) self:EAVars(key).pulseSpeed = v; self:EARefresh(key) end },
    } }
end

function PvPUA:EABuildSettings(def)
    local key = def.key
    local screenW, screenH = ScreenBounds()
    local halfW, halfH = math.ceil(screenW / 10) * 5, math.ceil(screenH / 10) * 5
    local function Sample()
        local v = self:EAVars(key)
        local text = v.messageText
        if text == nil or text == "" then text = def.defaultText end
        local c = v.textColor or def.defaultColor
        return text, DetailsFont(v.font, v.fontSize), c.r or 1, c.g or 1, c.b or 1
    end
    return { type = "submenu", name = def.label, icon = def.icon, options = {
        { type = "toggle", name = "Preview",
          tooltip = PREVIEW_TIP,
          getFunc = function() return self.effectAlerts[key] and self.effectAlerts[key].preview or false end,
          setFunc = function(v)
              if self.effectAlerts[key] then self.effectAlerts[key].preview = v end
              self:EARefresh(key)
          end },
        { type = "slider", name = "Horizontal Position", min = -halfW, max = halfW, step = 5,
          default = 0,
          tooltip = "Default is 0.",
          getFunc = function() return self:EAVars(key).posX end,
          setFunc = function(v) self:EAVars(key).posX = v; self:EAApplyPosition(key) end },
        { type = "slider", name = "Vertical Position", min = -halfH, max = halfH, step = 5,
          default = def.defaultPosY or -160,
          tooltip = "Default is " .. (def.defaultPosY or -160) .. ".",
          getFunc = function() return self:EAVars(key).posY end,
          setFunc = function(v) self:EAVars(key).posY = v; self:EAApplyPosition(key) end },


        { type = "toggle", name = "Enabled", preset = "YES_NO",
          tooltip = def.enabledTip,
          default = false,
          getFunc = function() return self:EAVars(key).enabled end,
          setFunc = function(v)
              self:EAVars(key).enabled = v
              self:EAApplyCombatListener()
              self:EARefresh(key)
          end },


        { type = "editbox", name = "Text",
          tooltip = DefaultTextTip(def.defaultText),
          default = def.defaultText,
          getFunc = function() return self:EAVars(key).messageText end,
          setFunc = function(v)
              if v == nil or v == "" then v = def.defaultText end
              self:EAVars(key).messageText = v
              self:EARefresh(key)
          end },
        { type = "slider", name = "Size", min = 25, max = 90, step = 1,
          tooltip = "Default is 45.",
          default = 45,
          getFunc = function() return self:EAVars(key).fontSize end,
          setFunc = function(v) self:EAVars(key).fontSize = v; self:EARefresh(key) end },
        { type = "dropdown", name = "Font",
          choices = EA_FONT_CHOICES,
          default = "EsoUI/Common/Fonts/univers67.otf",
          sample = Sample,
          getFunc = function() return self:EAVars(key).font end,
          setFunc = function(v) self:EAVars(key).font = v; self:EARefresh(key) end },
        { type = "colorpicker", name = RainbowText("Color"),
          default = def.defaultColor,
          sample = Sample,
          getFunc = function()
              local c = self:EAVars(key).textColor or def.defaultColor
              return c.r, c.g, c.b, 1
          end,
          setFunc = function(r, g, b)
              self:EAVars(key).textColor = { r = r, g = g, b = b, a = 1 }
              self:EARefresh(key)
          end },
        { type = "toggle", name = "Pulsate", preset = "YES_NO",
          tooltip = PULSATE_TIP,
          default = false,
          getFunc = function() return self:EAVars(key).pulsate end,
          setFunc = function(v) self:EAVars(key).pulsate = v; self:EARefresh(key) end },
        { type = "slider", name = "Pulse Speed", min = 1, max = 10, step = 1,
          tooltip = PULSE_SPEED_TIP,
          default = 3,
          disabled = function() return not self:EAVars(key).pulsate end,
          getFunc = function() return self:EAVars(key).pulseSpeed end,
          setFunc = function(v) self:EAVars(key).pulseSpeed = v; self:EARefresh(key) end },
    } }
end

--------------------------------------------------
-- Potions
--------------------------------------------------
local P = {}
PvPUA.Potion = P

P.previewMode = false

local POTION_DEFAULTS = {
    potionEnabled     = false,
    potionText        = "USE POTION NOW!",
    potionPosX        = 0,
    potionPosY        = -220,
    potionFontSize    = 45,
    potionFont        = "EsoUI/Common/Fonts/univers67.otf",
    potionColor       = { r = 1, g = 0.2, b = 0.2, a = 1 },
    potionPulsate     = false,
    potionPulseSpeed  = 3,
    potionAlwaysOn    = false,
    potionHealthGate  = false,
    potionHealthPct   = 60,
    potionMagickaGate = false,
    potionMagickaPct  = 60,
    potionStaminaGate = false,
    potionStaminaPct  = 60,
}

for key, value in pairs(POTION_DEFAULTS) do
    if PvPUA.defaults[key] == nil then
        PvPUA.defaults[key] = value
    end
end

local potionInCombat       = false
local potionVisible      = false
local potionIsReady    = true
local potionCooldownEnds = 0

local POTION_GATES = {
    { label = "health",  enable = "potionHealthGate",  threshold = "potionHealthPct",
      consts = { "COMBAT_MECHANIC_FLAGS_HEALTH",  "POWERTYPE_HEALTH"  } },
    { label = "magicka", enable = "potionMagickaGate", threshold = "potionMagickaPct",
      consts = { "COMBAT_MECHANIC_FLAGS_MAGICKA", "POWERTYPE_MAGICKA" } },
    { label = "stamina", enable = "potionStaminaGate", threshold = "potionStaminaPct",
      consts = { "COMBAT_MECHANIC_FLAGS_STAMINA", "POWERTYPE_STAMINA" } },
}

local potionPowerPct = {}

local POTION_FONT_CHOICES = {
    { name = "Gamepad Medium",  value = "EsoUI/Common/Fonts/FTN57.otf" },
    { name = "Gamepad Bold",    value = "EsoUI/Common/Fonts/FTN87.otf" },
    { name = "Gamepad Light",   value = "EsoUI/Common/Fonts/FTN47.otf" },
    { name = "Univers Regular", value = "EsoUI/Common/Fonts/Univers57.otf" },
    { name = "Univers Bold",    value = "EsoUI/Common/Fonts/univers67.otf" },
    { name = "Prose Antique",   value = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf" },
    { name = "Trajan Pro",      value = "EsoUI/Common/Fonts/TrajanPro-Regular.otf" },
    { name = "Handwritten",     value = "EsoUI/Common/Fonts/Handwritten_Bold.otf" },
}

function P:SV()
    return PvPUA.savedVariables
end

function P:GetFont()
    local sv = self:SV()
    return string.format("%s|%d|%s", sv.potionFont, sv.potionFontSize, "outline")
end

function P:InvalidateFont()
    if self.label then
        self.label:SetFont(self:GetFont())
    end
    self:RefreshDisplay()
end

function P:ApplyPosition()
    if not self.panel then return end
    local sv = self:SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(CENTER, GuiRoot, CENTER, sv.potionPosX, sv.potionPosY)
end

function P:CreatePanel()
    if self.panel then return end

    self.panel = WINDOW_MANAGER:CreateTopLevelWindow("PvPUA_PotionPanel")
    self.panel:SetClampedToScreen(true)
    self.panel:SetDrawLayer(DL_OVERLAY)
    self.panel:SetDrawTier(DT_HIGH)
    self.panel:SetDimensions(1200, 120)
    self.panel:SetHidden(true)
    self:ApplyPosition()

    local label = WINDOW_MANAGER:CreateControl("PvPUA_PotionLabel", self.panel, CT_LABEL)
    label:SetAnchor(CENTER, self.panel, CENTER, 0, 0)
    label:SetFont(self:GetFont())
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.label = label
end

function P:OnPotionUsed(_, sound)
    if sound ~= ITEM_SOUND_CATEGORY_POTION then return end

    potionIsReady = false
    self:RefreshDisplay()

    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_PotionDrink", 10, function()
        local slotIndex = GetCurrentQuickslot()
        local remain, duration, global = GetSlotCooldownInfo(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)

        if not global then
            EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_PotionDrink")

            remain = remain or 0
            potionCooldownEnds = GetGameTimeMilliseconds() + remain
        end
    end)
end

function P:IsPotionReady()
    if potionIsReady then return true end

    if potionCooldownEnds > 0 and GetGameTimeMilliseconds() >= potionCooldownEnds then
        potionIsReady    = true
        potionCooldownEnds = 0
        return true
    end

    return false
end

function P:ResolvePowerTypes()
    for _, gate in ipairs(POTION_GATES) do
        gate.power = nil

        for _, name in ipairs(gate.consts) do
            local value = _G[name]
            if type(value) == "number" then
                gate.power = value
                break
            end
        end

        if gate.power then
            potionPowerPct[gate.power] = 100
        end
    end
end

function P:RefreshPowerPercents()
    for _, gate in ipairs(POTION_GATES) do
        if gate.power then
            local current, maxVal, effectiveMax = GetUnitPower("player", gate.power)
            local capacity = effectiveMax or maxVal

            if current and capacity and capacity > 0 then
                potionPowerPct[gate.power] = (current / capacity) * 100
            end
        end
    end
end

function P.OnPowerUpdate(_, unitTag, _, powerType, powerValue, powerMax)
    if unitTag ~= "player" then return end
    if powerType == nil or potionPowerPct[powerType] == nil then return end
    if not powerMax or powerMax <= 0 then return end

    potionPowerPct[powerType] = (powerValue / powerMax) * 100

    P:RefreshDisplay()
end

function P:ResourceGatesPassed()
    local sv = self:SV()

    if sv.potionAlwaysOn then return true end

    for _, gate in ipairs(POTION_GATES) do
        if sv[gate.enable] then
            local pct = potionPowerPct[gate.power] or 100
            if pct <= sv[gate.threshold] then
                return true
            end
        end
    end

    return false
end

function P:IsPlayerDead()
    if type(IsUnitDead) == "function" and IsUnitDead("player") then
        return true
    end

    if type(IsUnitReincarnating) == "function" and IsUnitReincarnating("player") then
        return true
    end

    return false
end

function P:OnPlayerDead()
    potionInCombat  = false
    potionVisible = false
    if self.panel then self.panel:SetHidden(true) end
    self:RefreshDisplay()
end

function P:OnPlayerAlive()
    potionInCombat = IsUnitInCombat("player")
    self:RefreshPowerPercents()
    self:RefreshDisplay()
end

function P:ShouldShow()
    if self.previewMode then return true end
    if not self:SV().potionEnabled then return false end
    if self:IsPlayerDead() then return false end
    if not potionInCombat then return false end
    if not self:IsPotionReady() then return false end
    if not self:ResourceGatesPassed() then return false end

    return true
end

function P:RefreshDisplay()
    if not self.panel then return end

    local sv = self:SV()
    local show = self:ShouldShow()

    if not show then
        if potionVisible then
            potionVisible = false
        end
        self.panel:SetHidden(true)
        return
    end

    if not potionVisible then
        potionVisible = true
    end

    self.label:SetText(sv.potionText)

    local c = sv.potionColor
    local r, g, b = 1, 1, 1
    if type(c) == "table" then
        r, g, b = c.r or 1, c.g or 1, c.b or 1
    end

    local alpha = 1
    if sv.potionPulsate then
        local t = GetGameTimeSeconds() * sv.potionPulseSpeed
        alpha = 0.45 + (0.55 * math.abs(math.sin(t * math.pi)))
    end

    self.label:SetColor(r, g, b, alpha)
    self.panel:SetHidden(false)
end

function P:OnCombatState(eventCode, combatState)
    potionInCombat = combatState

    if not potionInCombat then
        potionVisible = false
        if self.panel then self.panel:SetHidden(true) end
    else
        self:IsPotionReady()
    end

    self:RefreshDisplay()
end

function P:InitializeSceneHiding()
    local function OnSceneStateChange(oldState, newState)
        if newState == SCENE_SHOWING then
            if P.panel then P.panel:SetHidden(true) end
        elseif newState == SCENE_HIDDEN then
            P:RefreshDisplay()
        end
    end

    local scenes = { "worldMap", "gameMenuInGame", "inventory", "gamepad_inventory_root" }
    for _, sceneName in ipairs(scenes) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", OnSceneStateChange)
        end
    end
end

function P:GetOptions()
    local function Sample()
        local sv = P:SV()
        local text = sv.potionText
        if text == nil or text == "" then text = POTION_DEFAULTS.potionText end
        local c = sv.potionColor
        local r, g, b = 1, 1, 1
        if type(c) == "table" then r, g, b = c.r or 1, c.g or 1, c.b or 1 end
        return text, DetailsFont(sv.potionFont, sv.potionFontSize), r, g, b
    end
    local function ThresholdText(label, field)
        return function()
            return string.format("Alerts when your %s is at %d%% or lower.", label, tonumber(P:SV()[field]) or 0)
        end
    end
    return {
        {
            type    = "toggle",
            name    = "Preview",
            tooltip = PREVIEW_TIP,
            getFunc = function() return P.previewMode end,
            setFunc = function(val)
                P.previewMode = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "slider",
            name    = "Horizontal Position",
            min     = -1200, max = 1200, step = 5,
            default = POTION_DEFAULTS.potionPosX,
            tooltip = "Default is " .. POTION_DEFAULTS.potionPosX .. ".",
            getFunc = function() return P:SV().potionPosX end,
            setFunc = function(val)
                P:SV().potionPosX = val
                P:ApplyPosition()
            end,
        },
        {
            type    = "slider",
            name    = "Vertical Position",
            min     = -800, max = 800, step = 5,
            default = POTION_DEFAULTS.potionPosY,
            tooltip = "Default is " .. POTION_DEFAULTS.potionPosY .. ".",
            getFunc = function() return P:SV().potionPosY end,
            setFunc = function(val)
                P:SV().potionPosY = val
                P:ApplyPosition()
            end,
        },
        {
            type    = "toggle",
            name    = "Enabled",
            preset = "YES_NO",
            tooltip = "Shows an alert telling you to drink a potion when one is ready during combat. Choose when with the options below.",
            default = POTION_DEFAULTS.potionEnabled,
            getFunc = function() return P:SV().potionEnabled end,
            setFunc = function(val)
                P:SV().potionEnabled = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "toggle",
            name    = "Always On",
            preset = "YES_NO",
            tooltip = "Show the alert whenever you are in combat with a potion ready, ignoring the resource options below.",
            default = POTION_DEFAULTS.potionAlwaysOn,
            getFunc = function() return P:SV().potionAlwaysOn end,
            setFunc = function(val)
                P:SV().potionAlwaysOn = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "toggle",
            name     = "|c" .. EP_HEX .. "Health|r",
            tooltip  = "Show the alert when you are in combat with a potion ready and your health has dropped to or below the threshold.",
            default  = POTION_DEFAULTS.potionHealthGate,
            disabled = function() return P:SV().potionAlwaysOn end,
            getFunc  = function() return P:SV().potionHealthGate end,
            setFunc  = function(val)
                P:SV().potionHealthGate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Threshold",
            min      = 10, max = 100, step = 5,
            default  = POTION_DEFAULTS.potionHealthPct,
            tooltip  = "Default is " .. POTION_DEFAULTS.potionHealthPct .. ".",
            details  = ThresholdText("|c" .. EP_HEX .. "Health|r", "potionHealthPct"),
            disabled = function()
                return P:SV().potionAlwaysOn or not P:SV().potionHealthGate
            end,
            getFunc  = function() return P:SV().potionHealthPct end,
            setFunc  = function(val)
                P:SV().potionHealthPct = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "toggle",
            name     = "|c" .. DC_HEX .. "Magicka|r",
            tooltip  = "Show the alert when you are in combat with a potion ready and your magicka has dropped to or below the threshold.",
            default  = POTION_DEFAULTS.potionMagickaGate,
            disabled = function() return P:SV().potionAlwaysOn end,
            getFunc  = function() return P:SV().potionMagickaGate end,
            setFunc  = function(val)
                P:SV().potionMagickaGate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Threshold",
            min      = 10, max = 100, step = 5,
            default  = POTION_DEFAULTS.potionMagickaPct,
            tooltip  = "Default is " .. POTION_DEFAULTS.potionMagickaPct .. ".",
            details  = ThresholdText("|c" .. DC_HEX .. "Magicka|r", "potionMagickaPct"),
            disabled = function()
                return P:SV().potionAlwaysOn or not P:SV().potionMagickaGate
            end,
            getFunc  = function() return P:SV().potionMagickaPct end,
            setFunc  = function(val)
                P:SV().potionMagickaPct = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "toggle",
            name     = "|c00CC44Stamina|r",
            tooltip  = "Show the alert when you are in combat with a potion ready and your stamina has dropped to or below the threshold.",
            default  = POTION_DEFAULTS.potionStaminaGate,
            disabled = function() return P:SV().potionAlwaysOn end,
            getFunc  = function() return P:SV().potionStaminaGate end,
            setFunc  = function(val)
                P:SV().potionStaminaGate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Threshold",
            min      = 10, max = 100, step = 5,
            default  = POTION_DEFAULTS.potionStaminaPct,
            tooltip  = "Default is " .. POTION_DEFAULTS.potionStaminaPct .. ".",
            details  = ThresholdText("|c00CC44Stamina|r", "potionStaminaPct"),
            disabled = function()
                return P:SV().potionAlwaysOn or not P:SV().potionStaminaGate
            end,
            getFunc  = function() return P:SV().potionStaminaPct end,
            setFunc  = function(val)
                P:SV().potionStaminaPct = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "editbox",
            name    = "Text",
            tooltip = DefaultTextTip(POTION_DEFAULTS.potionText),
            default = POTION_DEFAULTS.potionText,
            getFunc = function() return P:SV().potionText end,
            setFunc = function(val)
                if val == nil or val == "" then val = "USE POTION NOW!" end
                P:SV().potionText = val
                P:RefreshDisplay()
            end,
        },
        {
            type    = "slider",
            name    = "Size",
            min     = 25, max = 90, step = 1,
            default = POTION_DEFAULTS.potionFontSize,
            tooltip = "Default is 45.",
            getFunc = function() return P:SV().potionFontSize end,
            setFunc = function(val)
                P:SV().potionFontSize = val
                P:InvalidateFont()
            end,
        },
        {
            type    = "dropdown",
            name    = "Font",
            choices = POTION_FONT_CHOICES,
            default = POTION_DEFAULTS.potionFont,
            sample  = Sample,
            getFunc = function() return P:SV().potionFont end,
            setFunc = function(val)
                P:SV().potionFont = val
                P:InvalidateFont()
            end,
        },
        {
            type    = "colorpicker",
            name    = RainbowText("Color"),
            default = POTION_DEFAULTS.potionColor,
            sample  = Sample,
            getFunc = function()
                local c = P:SV().potionColor
                if type(c) == "table" then
                    return c.r or 1, c.g or 1, c.b or 1, 1
                end
                return 1, 1, 1, 1
            end,
            setFunc = function(r, g, b, a)
                P:SV().potionColor = { r = r, g = g, b = b, a = a }
                P:RefreshDisplay()
            end,
        },
        {
            type    = "toggle",
            name    = "Pulsate",
            preset = "YES_NO",
            default = POTION_DEFAULTS.potionPulsate,
            tooltip = PULSATE_TIP,
            getFunc = function() return P:SV().potionPulsate end,
            setFunc = function(val)
                P:SV().potionPulsate = val
                P:RefreshDisplay()
            end,
        },
        {
            type     = "slider",
            name     = "Pulse Speed",
            min      = 1, max = 10, step = 1,
            default  = POTION_DEFAULTS.potionPulseSpeed,
            tooltip  = PULSE_SPEED_TIP,
            disabled = function() return not P:SV().potionPulsate end,
            getFunc  = function() return P:SV().potionPulseSpeed end,
            setFunc  = function(val) P:SV().potionPulseSpeed = val end,
        },
    }
end

function P:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:ResolvePowerTypes()
    self:RefreshPowerPercents()
    self:CreatePanel()
    self:InitializeSceneHiding()

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_PotionUsed",
        EVENT_INVENTORY_ITEM_USED,
        function(...) P:OnPotionUsed(...) end
    )

    if EVENT_POWER_UPDATE ~= nil then
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_PotionPower",
            EVENT_POWER_UPDATE,
            P.OnPowerUpdate
        )

        EVENT_MANAGER:AddFilterForEvent(
            PvPUA.name .. "_PotionPower",
            EVENT_POWER_UPDATE,
            REGISTER_FILTER_UNIT_TAG, "player"
        )
    end

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_PotionCombat",
        EVENT_PLAYER_COMBAT_STATE,
        function(...) P:OnCombatState(...) end
    )

    if EVENT_PLAYER_DEAD ~= nil then
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_PotionDead",
            EVENT_PLAYER_DEAD,
            function() P:OnPlayerDead() end
        )
    end

    if EVENT_PLAYER_ALIVE ~= nil then
        EVENT_MANAGER:RegisterForEvent(
            PvPUA.name .. "_PotionAlive",
            EVENT_PLAYER_ALIVE,
            function() P:OnPlayerAlive() end
        )
    end

    EVENT_MANAGER:RegisterForUpdate(
        PvPUA.name .. "_PotionTick",
        100,
        function() P:RefreshDisplay() end
    )

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_PotionActivated",
        EVENT_PLAYER_ACTIVATED,
        function()
            potionInCombat = IsUnitInCombat("player")
            P:RefreshDisplay()
        end
    )
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:AlertsMenu()
    return { type = "submenu",
          name = "|c" .. AD_HEX .. "Alerts|r",
          tooltip = SAVED_ACCOUNT_TIP,
          childrenAlign = "center",
          icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_communications.dds",
          options = {
        self:HKBuildSettings(EA_DEFS[1]),
        self:EABuildSettings(EA_DEFS[2]),
        self:EABuildSettings(EA_DEFS[3]),
        { type = "submenu", name = "Potions", icon = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_buffsAndDebuffs.dds",
          options = PvPUA.Potion and PvPUA.Potion:GetOptions() or {} },
          } }
end

PvPUA.effectAlertDefs = EA_DEFS
