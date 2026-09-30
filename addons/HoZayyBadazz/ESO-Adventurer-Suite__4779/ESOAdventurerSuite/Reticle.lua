-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.Reticle = EPC.Reticle or {}
local R = EPC.Reticle
local wm = WINDOW_MANAGER

local STYLE_DEFAULT = "DEFAULT"
local STYLE_RUNE = "RUNE"
local STYLE_BRACKETS = "BRACKETS"
local STYLE_COMPASS = "COMPASS"
local STYLE_MINIMAL = "MINIMAL"
local STYLE_DAEDRIC = "DAEDRIC"
local STYLE_AYLEID = "AYLEID"
local STYLE_DRAGON = "DRAGON"

local COLORS = {
    GOLD = {0.93, 0.72, 0.28},
    IVORY = {0.96, 0.93, 0.84},
    CRIMSON = {0.95, 0.22, 0.18},
    BLUE = {0.38, 0.68, 0.95},
}

local function rainbowColor()
    local t = 0
    if type(GetFrameTimeSeconds) == "function" then
        t = GetFrameTimeSeconds()
    elseif type(GetGameTimeMilliseconds) == "function" then
        t = GetGameTimeMilliseconds() / 1000
    end
    -- One complete rainbow cycle about every 4 seconds.
    local h = (t / 4) % 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local q = 1 - f
    i = i % 6
    if i == 0 then return 1, f, 0 end
    if i == 1 then return q, 1, 0 end
    if i == 2 then return 0, 1, f end
    if i == 3 then return 0, q, 1 end
    if i == 4 then return f, 0, 1 end
    return 1, 0, q
end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nativeReticle()
    if RETICLE and RETICLE.reticleTexture then return RETICLE.reticleTexture end
    return _G and _G.ZO_ReticleContainerReticle or nil
end

function R:Create()
    if self.frame then return end

    local frame = wm:CreateTopLevelWindow("EAS_CustomReticle")
    frame:SetDimensions(180, 180)
    frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame:SetClampedToScreen(false)
    if frame.SetDrawTier and DT_HIGH then frame:SetDrawTier(DT_HIGH) end
    if frame.SetDrawLayer and DL_OVERLAY then frame:SetDrawLayer(DL_OVERLAY) end
    if frame.SetDrawLevel then frame:SetDrawLevel(1000) end
    frame:SetHidden(true)

    self.parts = {}
    for i = 1, 20 do
        local part = wm:CreateControl("EAS_CustomReticle_Part" .. tostring(i), frame, CT_BACKDROP)
        part:SetCenterColor(1, 1, 1, 1)
        part:SetEdgeColor(0, 0, 0, 0)
        part:SetHidden(true)
        self.parts[i] = part
    end

    self.frame = frame
end

local function place(part, w, h, x, y, r, g, b, a)
    part:ClearAnchors()
    part:SetAnchor(CENTER, R.frame, CENTER, x, y)
    part:SetDimensions(math.max(1, w), math.max(1, h))
    part:SetCenterColor(r, g, b, a)
    part:SetEdgeColor(0, 0, 0, 0)
    part:SetHidden(false)
end

function R:HideParts()
    for _, part in ipairs(self.parts or {}) do part:SetHidden(true) end
end

function R:ApplyStyle()
    if not self.frame then return end
    self:HideParts()

    local style = tostring(EPC.saved and EPC.saved.customReticleStyle or STYLE_RUNE)
    if style == STYLE_DEFAULT then return end

    local size = clamp(EPC.saved and EPC.saved.customReticleSize, 60, 180)
    local scale = size / 100
    local opacity = clamp(EPC.saved and EPC.saved.customReticleOpacity, 0.25, 1.0)
    local colorKey = tostring(EPC.saved and EPC.saved.customReticleColor or "GOLD")
    local r, g, b
    if colorKey == "RGB" then
        r, g, b = rainbowColor()
    else
        local c = COLORS[colorKey] or COLORS.GOLD
        r, g, b = c[1], c[2], c[3]
    end

    local thickness = math.max(2, math.floor(3 * scale + 0.5))
    local thin = math.max(1, math.floor(2 * scale + 0.5))
    local dot = math.max(3, math.floor(5 * scale + 0.5))
    local p = self.parts

    if style == STYLE_MINIMAL then
        local gap = 5 * scale
        local len = 9 * scale
        place(p[1], len, thickness, -(gap + len / 2), 0, r, g, b, opacity)
        place(p[2], len, thickness,  (gap + len / 2), 0, r, g, b, opacity)
        place(p[3], thickness, len, 0, -(gap + len / 2), r, g, b, opacity)
        place(p[4], thickness, len, 0,  (gap + len / 2), r, g, b, opacity)
        place(p[5], dot, dot, 0, 0, r, g, b, opacity)
        return
    end

    if style == STYLE_BRACKETS then
        local d = 17 * scale
        local len = 12 * scale
        -- Four ESO-style corner brackets around the aim point.
        place(p[1], len, thickness, -d, -d, r, g, b, opacity)
        place(p[2], thickness, len, -d, -d, r, g, b, opacity)
        place(p[3], len, thickness, d, -d, r, g, b, opacity)
        place(p[4], thickness, len, d, -d, r, g, b, opacity)
        place(p[5], len, thickness, -d, d, r, g, b, opacity)
        place(p[6], thickness, len, -d, d, r, g, b, opacity)
        place(p[7], len, thickness, d, d, r, g, b, opacity)
        place(p[8], thickness, len, d, d, r, g, b, opacity)
        place(p[9], dot, dot, 0, 0, r, g, b, opacity)
        return
    end

    if style == STYLE_COMPASS then
        local gap = 8 * scale
        local long = 20 * scale
        local short = 8 * scale
        place(p[1], long, thickness, -(gap + long / 2), 0, r, g, b, opacity)
        place(p[2], long, thickness,  (gap + long / 2), 0, r, g, b, opacity)
        place(p[3], thickness, long, 0, -(gap + long / 2), r, g, b, opacity)
        place(p[4], thickness, long, 0,  (gap + long / 2), r, g, b, opacity)
        -- Decorative compass ticks.
        place(p[5], short, thin, -22 * scale, -14 * scale, r, g, b, opacity * 0.85)
        place(p[6], short, thin,  22 * scale, -14 * scale, r, g, b, opacity * 0.85)
        place(p[7], short, thin, -22 * scale,  14 * scale, r, g, b, opacity * 0.85)
        place(p[8], short, thin,  22 * scale,  14 * scale, r, g, b, opacity * 0.85)
        place(p[9], dot, dot, 0, 0, r, g, b, opacity)
        return
    end

    if style == STYLE_DAEDRIC then
        -- Angular diamond / chevron marks inspired by ESO's Daedric UI motifs.
        local d = 18 * scale
        local arm = 10 * scale
        place(p[1], arm, thickness, -d, -d, r, g, b, opacity)
        place(p[2], thickness, arm, -d, -d, r, g, b, opacity)
        place(p[3], arm, thickness, d, -d, r, g, b, opacity)
        place(p[4], thickness, arm, d, -d, r, g, b, opacity)
        place(p[5], arm, thickness, -d, d, r, g, b, opacity)
        place(p[6], thickness, arm, -d, d, r, g, b, opacity)
        place(p[7], arm, thickness, d, d, r, g, b, opacity)
        place(p[8], thickness, arm, d, d, r, g, b, opacity)
        place(p[9], dot + 2 * scale, dot + 2 * scale, 0, 0, r, g, b, opacity)
        return
    end

    if style == STYLE_AYLEID then
        -- Ayleid-like star: long cardinal rays with shorter diagonal accents.
        local gap = 7 * scale
        local ray = 15 * scale
        local diag = 7 * scale
        place(p[1], ray, thickness, -(gap + ray / 2), 0, r, g, b, opacity)
        place(p[2], ray, thickness,  (gap + ray / 2), 0, r, g, b, opacity)
        place(p[3], thickness, ray, 0, -(gap + ray / 2), r, g, b, opacity)
        place(p[4], thickness, ray, 0,  (gap + ray / 2), r, g, b, opacity)
        local d = 17 * scale
        place(p[5], diag, thin, -d, -d, r, g, b, opacity * 0.82)
        place(p[6], diag, thin, d, -d, r, g, b, opacity * 0.82)
        place(p[7], diag, thin, -d, d, r, g, b, opacity * 0.82)
        place(p[8], diag, thin, d, d, r, g, b, opacity * 0.82)
        place(p[9], dot, dot, 0, 0, r, g, b, opacity)
        return
    end

    if style == STYLE_DRAGON then
        -- Compact dragon-eye shape: horizontal sight line with upper/lower fangs.
        local gap = 5 * scale
        local wing = 17 * scale
        place(p[1], wing, thickness, -(gap + wing / 2), 0, r, g, b, opacity)
        place(p[2], wing, thickness,  (gap + wing / 2), 0, r, g, b, opacity)
        local fang = 10 * scale
        local d = 15 * scale
        place(p[3], thin, fang, -d, -8 * scale, r, g, b, opacity * 0.9)
        place(p[4], thin, fang, d, -8 * scale, r, g, b, opacity * 0.9)
        place(p[5], thin, fang, -d, 8 * scale, r, g, b, opacity * 0.9)
        place(p[6], thin, fang, d, 8 * scale, r, g, b, opacity * 0.9)
        place(p[7], dot + 2 * scale, dot + 2 * scale, 0, 0, r, g, b, opacity)
        return
    end

    -- RUNE: compact four-point ESO-inspired rune with inner and outer marks.
    local gap = 7 * scale
    local len = 15 * scale
    place(p[1], len, thickness, -(gap + len / 2), 0, r, g, b, opacity)
    place(p[2], len, thickness,  (gap + len / 2), 0, r, g, b, opacity)
    place(p[3], thickness, len, 0, -(gap + len / 2), r, g, b, opacity)
    place(p[4], thickness, len, 0,  (gap + len / 2), r, g, b, opacity)
    place(p[5], dot, dot, 0, 0, r, g, b, opacity)
    local tick = 7 * scale
    local outer = 28 * scale
    place(p[6], tick, thin, -outer, -outer, r, g, b, opacity * 0.72)
    place(p[7], tick, thin,  outer, -outer, r, g, b, opacity * 0.72)
    place(p[8], tick, thin, -outer,  outer, r, g, b, opacity * 0.72)
    place(p[9], tick, thin,  outer,  outer, r, g, b, opacity * 0.72)
end

function R:ShouldShow()
    if not (EPC.saved and EPC.saved.enabled ~= false and EPC.saved.customReticleEnabled == true) then return false end
    if tostring(EPC.saved.customReticleStyle or STYLE_RUNE) == STYLE_DEFAULT then return false end
    if EPC.saved.hudHideInMenus ~= false and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then return false end
    -- The replacement reticle owns gameplay visibility. ESO temporarily hides
    -- or swaps its native reticle during combat/interactions; mirroring that
    -- hidden state made the Suite reticle disappear and allowed vanilla to flash
    -- back in. Menu suppression above is the only visibility gate we need.
    return true
end

function R:ApplyNativeState()
    local native = nativeReticle()
    if not native or type(native.SetAlpha) ~= "function" then return end
    local replace = EPC.saved and EPC.saved.enabled ~= false and EPC.saved.customReticleEnabled == true and tostring(EPC.saved.customReticleStyle or STYLE_RUNE) ~= STYLE_DEFAULT
    native:SetAlpha(replace and 0 or 1)
end

function R:Refresh(force)
    if not self.frame then self:Create() end

    local enabled = EPC.saved and EPC.saved.enabled ~= false and EPC.saved.customReticleEnabled == true
    local style = tostring(EPC.saved and EPC.saved.customReticleStyle or STYLE_RUNE)
    local color = tostring(EPC.saved and EPC.saved.customReticleColor or "GOLD")
    local size = tonumber(EPC.saved and EPC.saved.customReticleSize) or 100
    local opacity = tonumber(EPC.saved and EPC.saved.customReticleOpacity) or 0.95
    local signature = table.concat({tostring(enabled), style, color, tostring(size), string.format("%.3f", opacity)}, "|")

    -- Rebuild geometry only when a setting changes. The old 50ms loop rebuilt
    -- every backdrop even for a static reticle, which made Codex button clicks
    -- noticeably heavier than they needed to be. RGB still refreshes its color.
    if force == true or self.lastVisualSignature ~= signature or color == "RGB" then
        self:ApplyStyle()
        self.lastVisualSignature = signature
    end

    -- ESO can restore native reticle alpha when combat/interaction state changes.
    -- Reassert ownership on every inexpensive refresh without rebuilding geometry.
    self:ApplyNativeState()
    self.frame:SetHidden(not self:ShouldShow())
end

function R:Initialize()
    self:Create()

    if not self.hooked and type(ZO_PostHook) == "function" and RETICLE and type(RETICLE.UpdateHiddenState) == "function" then
        ZO_PostHook(RETICLE, "UpdateHiddenState", function()
            if EPC.Reticle then EPC.Reticle:Refresh() end
        end)
        self.hooked = true
    end

    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_CustomReticle"
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("Reticle","Activated",EVENT_PLAYER_ACTIVATED, function() self:Refresh() end)
    end
    if EVENT_PLAYER_COMBAT_STATE then
        EPC.Runtime:RegisterEvent("Reticle","Combat",EVENT_PLAYER_COMBAT_STATE, function() self:Refresh() end)
    end
    EPC.Runtime:RegisterUpdate("Reticle","Tick",650, function()
        if not EPC.saved or EPC.saved.customReticleEnabled ~= true then return end
        self:Refresh()
    end)
    self:Refresh()
end
