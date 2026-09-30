NothingWastedTracker = NothingWastedTracker or {}
local NWT = NothingWastedTracker

NWT.name = "NothingWastedTracker"
NWT.displayName = "Nothing Wasted Tracker"
NWT.version = "2.0"

local EM = EVENT_MANAGER
local AM = ANIMATION_MANAGER

-- buff-id(s) von "Nothing Wasted". pro id wird ein eigener event-namespace
-- registriert, weil REGISTER_FILTER_ABILITY_ID nur einen wert annimmt.
local ABILITY_IDS = { 263461 }
local MAX_STACKS = 10
local CLASS_NECROMANCER = 5

-- seit U51 verfallen die stacks stueckweise (2 alle 12s) und der buff liefert
-- keine endzeit mehr. dann zaehlt das addon den verfall selbst mit.
local DECAY_FALLBACK_MS = 12000
local decayMs = DECAY_FALLBACK_MS

local FONT = "$(BOLD_FONT)"
local FONT_STYLE = "soft-shadow-thick"

-- verhaeltnisse aus den texturen (256er raster)
local FRAME_INSET = 20 / 256
local SHADOW_SIZE = 1.4
local GLOW_SIZE = 1.8

local TIMER_UPDATE = NWT.name .. "Timer"
local PREVIEW_UPDATE = NWT.name .. "Preview"

-- farben fuer die LAM-header
local CAT_COLORS = {
    display  = "1eeb21",
    stacks   = "1ee8eb",
    timer    = "f5a000",
    anim     = "ff4fa3",
    behavior = "8fa8ff",
    position = "c850ff",
}

local function CatHeader(stringId, colorKey)
    return string.format("|c%s%s|r", CAT_COLORS[colorKey], GetString(stringId))
end

-- farben fuer die chat-ausgabe
local CHAT = {
    brand = "f50000",
    ok    = "f50000",
    info  = "ff5555",
    label = "8a8a8a",
    value = "bcbcbc",
}
local PREFIX = "|c" .. CHAT.brand .. "[|r|c8a8a8aNWT|r|c" .. CHAT.brand .. "]|r "

local function Msg(text, color)
    if color then
        d(PREFIX .. "|c" .. color .. text .. "|r")
    else
        d(PREFIX .. text)
    end
end

local defaults = {
    locked = false,
    posX = 0,
    posY = 200,

    scale = 72,
    showBorder = true,
    showPips = true,
    showBar = true,

    -- rahmenfarbe nach stack-stufe (1-3 / 4-6 / 7-9 / 10)
    colorTier1 = { 0.5, 0.5, 0.5, 1 },
    colorTier2 = { 1, 0.75, 0, 1 },
    colorTier3 = { 1, 1, 0, 1 },
    colorTier4 = { 0, 1, 0, 1 },

    showStacks = true,
    stackColor = { 1, 1, 1, 1 },

    showTimer = true,
    timerPos = "below",
    timerColor = { 1, 1, 1, 1 },
    timerSize = 18,
    decimalsBelow = 5,
    warnAt = 3,
    warnColor = { 1, 0.25, 0.2, 1 },

    animations = true,
    animGlow = true,
    animShine = true,
    animImpact = true,

    hideWhenZero = true,
    combatOnly = false,
    necroOnly = true,
}

-- controls
local panel, tile, shadowTex, glowTex, plateTex, iconTex, shineTex, flashTex, frameTex, burstTex
local stacksLbl, timerInLbl, timerLbl, pipRow, barBg, barFill
local pips = {}
local fragment

-- zustand: "real" kommt aus dem spiel, "shown" ist das was gerade gezeichnet wird
-- (bei der vorschau weichen beide voneinander ab)
local real = { stacks = 0, endMs = 0, durMs = DECAY_FALLBACK_MS }
local shown = { stacks = 0, endMs = 0, durMs = DECAY_FALLBACK_MS }
local previewing = false
local inCombat = false
local isNecro = true
local isVisible = false
local lastTimerText
local barWidth = 0

-- ------------------------------------------------------------------
-- hilfsfunktionen
-- ------------------------------------------------------------------

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function OutCubic(t)
    t = 1 - t
    return 1 - t * t * t
end

local function OutBack(t)
    t = t - 1
    return 1 + 2.70158 * t * t * t + 1.70158 * t * t
end

local function AnimOn(key)
    local sv = NWT.sv
    if not sv.animations then return false end
    return key == nil or sv[key]
end

local function Font(size)
    return string.format("%s|%d|%s", FONT, size, FONT_STYLE)
end

local function SetColor(ctl, c, alphaMul)
    ctl:SetColor(c[1], c[2], c[3], (c[4] or 1) * (alphaMul or 1))
end

-- waehlt die stufenfarbe anhand des stack-stands
local function TierColor(stacks)
    local sv = NWT.sv
    if stacks >= MAX_STACKS then return sv.colorTier4 end
    if stacks >= 7 then return sv.colorTier3 end
    if stacks >= 4 then return sv.colorTier2 end
    return sv.colorTier1
end

-- endzeit in lokale spielzeit (ms) umrechnen. die einheit wird gegen die
-- aktuelle spielzeit geprueft, damit sekunden und millisekunden beide passen.
local function ToEndMs(beginTime, endTime)
    if not endTime or endTime <= 0 or endTime <= (beginTime or 0) then return 0 end
    local nowS = GetGameTimeSeconds()
    local nowMs = GetGameTimeMilliseconds()
    if math.abs(endTime - nowMs) < math.abs(endTime - nowS) then
        return endTime
    end
    return endTime * 1000
end

local TRACKED = {}
for _, id in ipairs(ABILITY_IDS) do TRACKED[id] = true end

local function ScanPlayerBuffs()
    for i = 1, GetNumBuffs("player") do
        local _, beginTime, endTime, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if TRACKED[abilityId] then
            return stackCount or 0, ToEndMs(beginTime, endTime)
        end
    end
    return 0, 0
end

-- ------------------------------------------------------------------
-- animationen: alle timelines werden einmal angelegt und wiederverwendet,
-- AM:CreateTimeline gibt nichts mehr frei
-- ------------------------------------------------------------------

local function NewTween(ctl, ms, update, loop)
    local tl = AM:CreateTimeline()
    local anim = tl:InsertAnimation(ANIMATION_CUSTOM, ctl)
    anim:SetDuration(ms)
    anim:SetUpdateFunction(function(_, p) update(p) end)
    if loop then
        tl:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
    end
    return tl, anim
end

local anims = {}
local flashPeak = 0.5

local function AnchorTile(offsetX)
    tile:ClearAnchors()
    tile:SetAnchor(TOP, panel, TOP, offsetX or 0, 0)
end

local function CreateAnimations()
    -- stack-zahl springt kurz auf
    anims.pop = NewTween(stacksLbl, 280, function(p)
        stacksLbl:SetScale(1 + 0.45 * (1 - OutCubic(p)))
    end)

    -- heller blitz ueber dem icon, farbe setzt der aufrufer
    anims.flash = NewTween(flashTex, 260, function(p)
        local k = 1 - p
        flashTex:SetAlpha(flashPeak * k * k)
    end)

    -- achteck-impuls nach aussen
    anims.burst = NewTween(burstTex, 420, function(p)
        burstTex:SetScale(0.9 + 0.5 * OutCubic(p))
        burstTex:SetAlpha(0.9 * (1 - p))
    end)

    -- kurzes zittern bei verfall
    anims.shake = NewTween(tile, 320, function(p)
        local amp = NWT.sv.scale * 0.045 * (1 - p)
        AnchorTile(math.sin(p * math.pi * 7) * amp)
        if p >= 1 then AnchorTile(0) end
    end)

    -- einblenden, wenn der tracker von 0 stacks erscheint
    anims.appear = NewTween(tile, 360, function(p)
        tile:SetScale(0.82 + 0.18 * OutBack(p))
        tile:SetAlpha(Clamp(p * 1.6, 0, 1))
    end)

    -- atmender glow bei vollen stacks
    anims.pulse = NewTween(glowTex, 1600, function(p)
        local k = 0.5 - 0.5 * math.cos(p * math.pi * 2)
        glowTex:SetAlpha(0.35 + 0.5 * k)
        glowTex:SetScale(1 + 0.07 * k)
    end, true)

    -- glanzstreifen laeuft alle 3s ueber das icon
    anims.shine = NewTween(shineTex, 3000, function(p)
        if p > 0.4 then
            shineTex:SetAlpha(0)
            return
        end
        local u = p / 0.4
        u = u * u * (3 - 2 * u)
        local off = 1 - 2 * u
        shineTex:SetTextureCoords(off, off + 1, 0, 1)
        shineTex:SetAlpha(0.55)
    end, true)
end

-- ------------------------------------------------------------------
-- pips: 10 splitter in 5 paaren, passend zum verfall von 2 stacks
-- ------------------------------------------------------------------

local PIP_GAIN_MS = 260
local PIP_LOSS_MS = 320

local function CreatePips()
    for i = 1, MAX_STACKS do
        local file = (i % 2 == 1) and "pip_l.dds" or "pip_r.dds"
        local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg" .. i, pipRow, CT_TEXTURE)
        bg:SetTexture("NothingWastedTracker/media/" .. file)
        bg:SetDrawLevel(1)
        bg:SetColor(0.06, 0.06, 0.07, 0.85)

        local fill = WINDOW_MANAGER:CreateControl("$(parent)Fill" .. i, pipRow, CT_TEXTURE)
        fill:SetTexture("NothingWastedTracker/media/" .. file)
        fill:SetDrawLevel(2)
        fill:SetAlpha(0)

        local pip = { bg = bg, fill = fill, delay = 0 }

        pip.gain, pip.gainAnim = NewTween(fill, PIP_GAIN_MS, function(p)
            local total = pip.delay + PIP_GAIN_MS
            local t = Clamp((p * total - pip.delay) / PIP_GAIN_MS, 0, 1)
            fill:SetAlpha(Clamp(t * 2, 0, 1))
            fill:SetScale(1.8 - 0.8 * OutBack(t))
        end)

        pip.loss = NewTween(fill, PIP_LOSS_MS, function(p)
            fill:SetAlpha(1 - p)
            fill:SetScale(1 - 0.5 * OutCubic(p))
        end)

        pips[i] = pip
    end
end

local function SetPip(pip, on)
    pip.gain:Stop()
    pip.loss:Stop()
    pip.fill:SetAlpha(on and 1 or 0)
    pip.fill:SetScale(1)
end

local function UpdatePips(old, new, animate)
    local col = TierColor(new)
    for i = 1, MAX_STACKS do
        local pip = pips[i]
        SetColor(pip.fill, col)
        local wasOn, isOn = i <= old, i <= new
        if animate and isOn and not wasOn then
            pip.loss:Stop()
            pip.delay = (i - old - 1) * 45
            pip.gainAnim:SetDuration(pip.delay + PIP_GAIN_MS)
            pip.fill:SetAlpha(0)
            pip.gain:PlayFromStart()
        elseif animate and wasOn and not isOn then
            pip.gain:Stop()
            pip.fill:SetScale(1)
            pip.loss:PlayFromStart()
        elseif wasOn ~= isOn or not animate then
            SetPip(pip, isOn)
        end
    end
end

-- ------------------------------------------------------------------
-- layout
-- ------------------------------------------------------------------

local function ApplyLayout()
    local sv = NWT.sv
    local s = sv.scale
    local gap = math.max(3, math.floor(s * 0.07 + 0.5))

    tile:SetDimensions(s, s)
    AnchorTile(0)

    shadowTex:SetDimensions(s * SHADOW_SIZE, s * SHADOW_SIZE)
    glowTex:SetDimensions(s * GLOW_SIZE, s * GLOW_SIZE)
    burstTex:SetDimensions(s, s)

    local inset = math.floor(s * FRAME_INSET + 0.5)
    for _, tex in ipairs({ iconTex, shineTex }) do
        tex:ClearAnchors()
        tex:SetAnchor(TOPLEFT, tile, TOPLEFT, inset, inset)
        tex:SetAnchor(BOTTOMRIGHT, tile, BOTTOMRIGHT, -inset, -inset)
    end

    stacksLbl:SetFont(Font(math.max(12, math.floor(s * 0.36 + 0.5))))
    stacksLbl:ClearAnchors()
    stacksLbl:SetAnchor(BOTTOMRIGHT, iconTex, BOTTOMRIGHT, -math.floor(s * 0.03), math.floor(s * 0.04))

    timerInLbl:SetFont(Font(sv.timerSize))
    timerInLbl:ClearAnchors()
    timerInLbl:SetAnchor(CENTER, iconTex, CENTER, 0, 0)
    timerLbl:SetFont(Font(sv.timerSize))

    -- darunter gestapelt: pips, balken, timer
    local height = s
    local anchorTo, anchorPoint = tile, BOTTOM

    pipRow:SetHidden(not sv.showPips)
    if sv.showPips then
        local w = s / 13.1
        local h = w * 1.3
        pipRow:SetDimensions(s, h)
        pipRow:ClearAnchors()
        pipRow:SetAnchor(TOP, anchorTo, anchorPoint, 0, gap)
        local x = 0
        for i = 1, MAX_STACKS do
            local pip = pips[i]
            for _, tex in ipairs({ pip.bg, pip.fill }) do
                tex:SetDimensions(w, h)
                tex:ClearAnchors()
                tex:SetAnchor(TOPLEFT, pipRow, TOPLEFT, x, 0)
            end
            x = x + w + ((i % 2 == 1) and w * 0.18 or w * 0.55)
        end
        height = height + gap + h
        anchorTo = pipRow
    end

    local barH = math.max(4, math.floor(s * 0.075 + 0.5))
    barBg:SetHidden(not sv.showBar)
    barFill:SetHidden(not sv.showBar)
    if sv.showBar then
        barWidth = s
        barBg:SetDimensions(s, barH)
        barBg:ClearAnchors()
        barBg:SetAnchor(TOP, anchorTo, BOTTOM, 0, gap)
        barFill:SetHeight(barH)
        barFill:ClearAnchors()
        barFill:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
        barFill:SetWidth(0)
        height = height + gap + barH
        anchorTo = barBg
    end

    timerLbl:ClearAnchors()
    timerLbl:SetAnchor(TOP, anchorTo, BOTTOM, 0, math.floor(gap * 0.5))
    if sv.showTimer and sv.timerPos == "below" then
        height = height + gap + sv.timerSize
    end

    panel:SetDimensions(s, height)
end

local function ApplyColors()
    local sv = NWT.sv
    plateTex:SetColor(0.05, 0.05, 0.06, 0.94)
    shadowTex:SetColor(1, 1, 1, 0.9)
    barBg:SetColor(0, 0, 0, 0.6)
    SetColor(stacksLbl, sv.stackColor)
    SetColor(timerLbl, sv.timerColor)
    SetColor(timerInLbl, sv.timerColor)
end

-- ------------------------------------------------------------------
-- timer
-- ------------------------------------------------------------------

local function ActiveTimerLabel()
    local sv = NWT.sv
    if not sv.showTimer then return nil end
    return (sv.timerPos == "center") and timerInLbl or timerLbl
end

local function ClearTimer()
    EM:UnregisterForUpdate(TIMER_UPDATE)
    timerLbl:SetText("")
    timerInLbl:SetText("")
    barFill:SetWidth(0)
    lastTimerText = nil
end

local function OnTick()
    local sv = NWT.sv
    local now = GetGameTimeMilliseconds()
    local remain = shown.endMs - now
    if remain <= 0 then
        ClearTimer()
        return
    end

    local warnMs = sv.warnAt * 1000
    local warn = warnMs > 0 and remain <= warnMs
    local warnT = warn and (1 - remain / warnMs) or 0
    local tier = TierColor(shown.stacks)

    if sv.showBar then
        local pct = Clamp(remain / shown.durMs, 0, 1)
        barFill:SetWidth(barWidth * pct)
        barFill:SetTextureCoords(0, pct, 0, 1)
        local wc = sv.warnColor
        barFill:SetColor(Lerp(tier[1], wc[1], warnT), Lerp(tier[2], wc[2], warnT), Lerp(tier[3], wc[3], warnT), 1)
    end

    local lbl = ActiveTimerLabel()
    if lbl then
        local sec = remain / 1000
        local txt
        if sec < sv.decimalsBelow then
            txt = string.format("%.1f", sec)
        else
            txt = tostring(math.ceil(sec))
        end
        if txt ~= lastTimerText then
            lbl:SetText(txt)
            lastTimerText = txt
        end
        if warn then
            SetColor(lbl, sv.warnColor, AnimOn() and (0.6 + 0.4 * math.cos(now / 90)) or 1)
        else
            SetColor(lbl, sv.timerColor)
        end
    end
end

local function StartTimer()
    ClearTimer()
    if shown.stacks <= 0 or shown.endMs <= GetGameTimeMilliseconds() then return end
    EM:RegisterForUpdate(TIMER_UPDATE, 16, OnTick)
    OnTick()
end

-- ------------------------------------------------------------------
-- darstellung
-- ------------------------------------------------------------------

local function WantVisible()
    local sv = NWT.sv
    if previewing then return true end
    -- klassenpruefung vor dem entsperr-zustand, sonst bleibt der tracker
    -- auf anderen klassen sichtbar, solange er entsperrt ist
    if sv.necroOnly and not isNecro then return false end
    if not sv.locked then return true end
    if sv.combatOnly and not inCombat then return false end
    return shown.stacks > 0 or not sv.hideWhenZero
end

local function UpdateVisibility(animate)
    if not fragment then return end
    local want = WantVisible()
    if want and not isVisible and animate and AnimOn() then
        anims.appear:PlayFromStart()
    elseif not AnimOn() then
        tile:SetScale(1)
        tile:SetAlpha(1)
    end
    isVisible = want
    fragment:SetHiddenForReason("nwtContent", not want)
end

local function UpdateMaxEffects()
    local sv = NWT.sv
    local stacks = shown.stacks
    SetColor(glowTex, TierColor(stacks))

    local atMax = stacks >= MAX_STACKS

    -- loops nur starten, wenn sie noch nicht laufen, sonst springt die phase
    -- bei jedem refresh auf 10 stacks
    if atMax and AnimOn("animGlow") then
        if not anims.pulse:IsPlaying() then anims.pulse:PlayFromStart() end
    else
        anims.pulse:Stop()
        glowTex:SetScale(1)
        if not sv.animGlow then
            glowTex:SetAlpha(0)
        elseif atMax then
            glowTex:SetAlpha(0.6)
        else
            -- leichter schein, der mit den stacks waechst
            glowTex:SetAlpha(0.25 * stacks / MAX_STACKS)
        end
    end

    if atMax and AnimOn("animShine") then
        if not anims.shine:IsPlaying() then anims.shine:PlayFromStart() end
    else
        anims.shine:Stop()
        shineTex:SetAlpha(0)
    end
end

local function Impact(old, new)
    if not AnimOn("animImpact") then return end
    if new > old then
        flashPeak = 0.5
        flashTex:SetColor(1, 1, 1, 1)
        anims.flash:PlayFromStart()
        anims.pop:PlayFromStart()
        SetColor(burstTex, TierColor(new))
        anims.burst:PlayFromStart()
    elseif new < old then
        flashPeak = 0.45
        SetColor(flashTex, NWT.sv.warnColor)
        anims.flash:PlayFromStart()
        if new > 0 then
            anims.shake:PlayFromStart()
        end
    elseif new > 0 then
        -- refresh ohne aenderung (z. b. neuer stack bei 10): nur ein kleiner impuls
        SetColor(burstTex, TierColor(new))
        anims.burst:PlayFromStart()
    end
end

-- zeichnet einen zustand; animate = false bei settings, laden und reload
local function Show(stacks, endMs, durMs, animate)
    local sv = NWT.sv
    local old = shown.stacks
    shown.stacks = stacks or 0
    shown.endMs = endMs or 0
    shown.durMs = math.max(durMs or decayMs, 1)
    stacks = shown.stacks

    local col = TierColor(stacks)
    frameTex:SetHidden(not sv.showBorder)
    SetColor(frameTex, col)

    iconTex:SetDesaturation(stacks > 0 and 0 or 1)
    iconTex:SetAlpha(stacks > 0 and 1 or 0.55)

    stacksLbl:SetHidden(not sv.showStacks)
    stacksLbl:SetText(tostring(stacks))
    stacksLbl:SetScale(1)

    local doAnim = animate and AnimOn()
    UpdatePips(old, stacks, doAnim)
    if doAnim then Impact(old, stacks) end

    UpdateMaxEffects()
    StartTimer()
    UpdateVisibility(animate)
end

local function Render()
    Show(shown.stacks, shown.endMs, shown.durMs, false)
end

local function ShowReal(animate)
    local endMs = real.endMs
    if endMs <= GetGameTimeMilliseconds() then endMs = 0 end
    Show(real.stacks, endMs, real.durMs, animate)
end

-- ------------------------------------------------------------------
-- vorschau: spielt einen kompletten zyklus ab, ohne buff im spiel
-- ------------------------------------------------------------------

local PREVIEW_STEPS = {
    { 0, 2 }, { 600, 4 }, { 1200, 6 }, { 1800, 8 }, { 2400, 10 },
    { 7400, 8 }, { 9400, 6 }, { 11400, 4 }, { 13400, 2 }, { 15400, 0 },
}
local previewStart, previewIndex = 0, 0

local function StopPreview()
    if not previewing then return end
    previewing = false
    EM:UnregisterForUpdate(PREVIEW_UPDATE)
    ShowReal(false)
end

local function PreviewTick()
    local elapsed = GetGameTimeMilliseconds() - previewStart
    local nextStep = PREVIEW_STEPS[previewIndex + 1]
    if not nextStep then
        StopPreview()
        return
    end
    if elapsed < nextStep[1] then return end

    previewIndex = previewIndex + 1
    local after = PREVIEW_STEPS[previewIndex + 1]
    local stepMs = after and (after[1] - nextStep[1]) or 0
    local now = GetGameTimeMilliseconds()
    Show(nextStep[2], stepMs > 0 and (now + stepMs) or 0, stepMs, true)
end

local function StartPreview()
    previewing = true
    previewStart = GetGameTimeMilliseconds()
    previewIndex = 0
    Show(0, 0, decayMs, false)
    EM:RegisterForUpdate(PREVIEW_UPDATE, 50, PreviewTick)
    Msg(GetString(SI_NWT_PREVIEW_RUNNING), CHAT.info)
end

-- ------------------------------------------------------------------
-- events
-- ------------------------------------------------------------------

-- unitTag und abilityId sind bereits per event-filter in C vorgefiltert
local function OnEffectChanged(_, changeType, _, _, _, beginTime, endTime, stackCount)
    local now = GetGameTimeMilliseconds()
    if changeType == EFFECT_RESULT_FADED then
        real.stacks, real.endMs, real.durMs = 0, 0, decayMs
    else
        -- jeder stack-gewinn, refresh oder verfall startet den naechsten verfall neu.
        -- liefert das spiel eine gueltige endzeit, hat die vorrang.
        local endMs = ToEndMs(beginTime, endTime)
        if endMs <= now then
            endMs = now + decayMs
        end
        real.stacks = stackCount or 0
        real.endMs = endMs
        real.durMs = math.max(endMs - now, decayMs)
    end

    if not previewing then
        ShowReal(true)
    end
end

-- nach ladebildschirmen: restzeit ist unbekannt, wenn das spiel keine liefert.
-- der timer erscheint dann mit dem naechsten event.
local function ForceRefresh()
    local s, e = ScanPlayerBuffs()
    real.stacks, real.endMs, real.durMs = s, e, decayMs
    if not previewing then
        ShowReal(false)
    end
end

local function OnCombatState(_, state)
    inCombat = state
    UpdateVisibility(true)
end

local function UpdateClass()
    isNecro = GetUnitClassId("player") == CLASS_NECROMANCER
end

local function OnPlayerActivated()
    -- klasse hier nochmal lesen, beim addon-laden ist der wert nicht immer gesetzt
    UpdateClass()
    inCombat = IsUnitInCombat("player")
    ForceRefresh()
end

local function InitDecay()
    local dur = GetAbilityDuration(ABILITY_IDS[1])
    if dur and dur >= 1000 and dur <= 60000 then
        decayMs = dur
    end
end

-- ------------------------------------------------------------------
-- position / sperre
-- ------------------------------------------------------------------

function NWT.OnMoveStop()
    NWT.sv.posX = panel:GetLeft()
    NWT.sv.posY = panel:GetTop()
end

local function RestorePosition()
    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NWT.sv.posX, NWT.sv.posY)
end

local function ApplyLock()
    panel:SetMovable(not NWT.sv.locked)
    panel:SetMouseEnabled(not NWT.sv.locked)
    UpdateVisibility(false)
end

local function Relayout()
    ApplyLayout()
    ApplyColors()
    Render()
end

-- ------------------------------------------------------------------
-- einstellungen
-- ------------------------------------------------------------------

local function ColorDefault(key)
    local c = defaults[key]
    return { r = c[1], g = c[2], b = c[3], a = c[4] }
end

local function ColorOption(nameId, key, onChange)
    return {
        type = "colorpicker", name = GetString(nameId),
        getFunc = function() local c = NWT.sv[key]; return c[1], c[2], c[3], c[4] end,
        setFunc = function(r, g, b, a) NWT.sv[key] = { r, g, b, a }; onChange() end,
        default = ColorDefault(key),
    }
end

local function CheckOption(nameId, key, onChange, extra)
    local opt = {
        type = "checkbox", name = GetString(nameId),
        getFunc = function() return NWT.sv[key] end,
        setFunc = function(v) NWT.sv[key] = v; onChange() end,
        default = defaults[key],
    }
    if extra then
        for k, v in pairs(extra) do opt[k] = v end
    end
    return opt
end

local function SliderOption(nameId, key, min, max, step, onChange, extra)
    local opt = {
        type = "slider", name = GetString(nameId), min = min, max = max, step = step,
        getFunc = function() return NWT.sv[key] end,
        setFunc = function(v) NWT.sv[key] = v; onChange() end,
        default = defaults[key],
    }
    if extra then
        for k, v in pairs(extra) do opt[k] = v end
    end
    return opt
end

local function BuildMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    -- farbiger addon-name im panel-titel
    local titleColored = "|c0d0d0dNothingWasted|r |ce90101Tracker|r"

    LAM:RegisterAddonPanel("NWT_Options", {
        type = "panel", name = titleColored, displayName = titleColored,
        author = "|cf50000haze068|r", version = NWT.version,
        registerForRefresh = true, registerForDefaults = true,
    })

    local function animOff() return not NWT.sv.animations end
    local function timerOff() return not NWT.sv.showTimer end

    local options = {
        {
            type = "button", name = GetString(SI_NWT_PREVIEW), width = "half",
            func = StartPreview,
        },
        {
            type = "button", name = GetString(SI_NWT_UNLOCK_MOVE), width = "half",
            func = function()
                NWT.sv.locked = false
                ApplyLock()
                Msg(GetString(SI_NWT_UNLOCK_HINT), CHAT.info)
            end,
        },
        {
            type = "submenu", name = CatHeader(SI_NWT_CAT_DISPLAY, "display"),
            controls = {
                SliderOption(SI_NWT_SIZE, "scale", 40, 200, 2, Relayout),
                CheckOption(SI_NWT_BORDER, "showBorder", Render),
                CheckOption(SI_NWT_SHOW_PIPS, "showPips", Relayout),
                CheckOption(SI_NWT_SHOW_BAR, "showBar", Relayout),
                ColorOption(SI_NWT_COLOR_T1, "colorTier1", Render),
                ColorOption(SI_NWT_COLOR_T2, "colorTier2", Render),
                ColorOption(SI_NWT_COLOR_T3, "colorTier3", Render),
                ColorOption(SI_NWT_COLOR_T4, "colorTier4", Render),
            },
        },
        {
            type = "submenu", name = CatHeader(SI_NWT_CAT_STACKS, "stacks"),
            controls = {
                CheckOption(SI_NWT_SHOW_STACKS, "showStacks", Render),
                ColorOption(SI_NWT_STACK_COLOR, "stackColor", ApplyColors),
            },
        },
        {
            type = "submenu", name = CatHeader(SI_NWT_CAT_TIMER, "timer"),
            controls = {
                CheckOption(SI_NWT_SHOW_TIMER, "showTimer", Relayout),
                {
                    type = "dropdown", name = GetString(SI_NWT_TIMER_POS),
                    choices = { GetString(SI_NWT_TIMER_POS_BELOW), GetString(SI_NWT_TIMER_POS_CENTER) },
                    choicesValues = { "below", "center" },
                    getFunc = function() return NWT.sv.timerPos end,
                    setFunc = function(v) NWT.sv.timerPos = v; Relayout() end,
                    default = defaults.timerPos,
                    disabled = timerOff,
                },
                SliderOption(SI_NWT_TIMER_SIZE, "timerSize", 10, 48, 1, Relayout, { disabled = timerOff }),
                SliderOption(SI_NWT_DECIMALS_BELOW, "decimalsBelow", 0, 15, 1, Render,
                    { tooltip = GetString(SI_NWT_DECIMALS_TT), disabled = timerOff }),
                ColorOption(SI_NWT_TIMER_COLOR, "timerColor", ApplyColors),
                SliderOption(SI_NWT_WARN_AT, "warnAt", 0, 10, 0.5, Render,
                    { tooltip = GetString(SI_NWT_WARN_TT), decimals = 1 }),
                ColorOption(SI_NWT_WARN_COLOR, "warnColor", Render),
            },
        },
        {
            type = "submenu", name = CatHeader(SI_NWT_CAT_ANIM, "anim"),
            controls = {
                CheckOption(SI_NWT_ANIM_ENABLE, "animations", Render),
                CheckOption(SI_NWT_ANIM_GLOW, "animGlow", Render),
                CheckOption(SI_NWT_ANIM_SHINE, "animShine", Render, { disabled = animOff }),
                CheckOption(SI_NWT_ANIM_IMPACT, "animImpact", Render, { disabled = animOff }),
            },
        },
        {
            type = "submenu", name = CatHeader(SI_NWT_CAT_BEHAVIOR, "behavior"),
            controls = {
                CheckOption(SI_NWT_HIDE_ZERO, "hideWhenZero", Render),
                CheckOption(SI_NWT_COMBAT_ONLY, "combatOnly", Render),
                CheckOption(SI_NWT_NECRO_ONLY, "necroOnly", Render),
                CheckOption(SI_NWT_LOCK, "locked", ApplyLock),
            },
        },
    }
    LAM:RegisterOptionControls("NWT_Options", options)
end

-- ------------------------------------------------------------------
-- slash
-- ------------------------------------------------------------------

local function PrintHelp()
    Msg("|c" .. CHAT.brand .. GetString(SI_NWT_CMD_HELP_TITLE) .. "|r")
    local function cmd(usage, desc)
        d(string.format("   |c%s%s|r  |c%s-|r  |c%s%s|r",
            CHAT.ok, usage, CHAT.label, CHAT.value, desc))
    end
    cmd("/nwt lock",   GetString(SI_NWT_CMD_HELP_LOCK))
    cmd("/nwt unlock", GetString(SI_NWT_CMD_HELP_UNLOCK))
    cmd("/nwt test",   GetString(SI_NWT_CMD_HELP_TEST))
end

SLASH_COMMANDS["/nwt"] = function(arg)
    arg = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "lock" then
        NWT.sv.locked = true
        ApplyLock()
        Msg(GetString(SI_NWT_CMD_LOCKED), CHAT.ok)
    elseif arg == "unlock" then
        NWT.sv.locked = false
        ApplyLock()
        Msg(GetString(SI_NWT_CMD_UNLOCKED), CHAT.info)
    elseif arg == "test" then
        StartPreview()
    else
        PrintHelp()
    end
end

-- ------------------------------------------------------------------
-- start
-- ------------------------------------------------------------------

local function GrabControls()
    panel      = NWT_Panel
    tile       = panel:GetNamedChild("Tile")
    shadowTex  = tile:GetNamedChild("Shadow")
    glowTex    = tile:GetNamedChild("Glow")
    plateTex   = tile:GetNamedChild("Plate")
    iconTex    = tile:GetNamedChild("Icon")
    shineTex   = tile:GetNamedChild("Shine")
    flashTex   = tile:GetNamedChild("Flash")
    frameTex   = tile:GetNamedChild("Frame")
    burstTex   = tile:GetNamedChild("Burst")
    stacksLbl  = tile:GetNamedChild("Stacks")
    timerInLbl = tile:GetNamedChild("TimerIn")
    pipRow     = panel:GetNamedChild("Pips")
    barBg      = panel:GetNamedChild("BarBg")
    barFill    = panel:GetNamedChild("BarFill")
    timerLbl   = panel:GetNamedChild("Timer")

    for _, tex in ipairs({ glowTex, shineTex, flashTex, burstTex }) do
        tex:SetBlendMode(TEX_BLEND_MODE_ADD)
    end
    if TEX_MODE_CLAMP then
        shineTex:SetAddressMode(TEX_MODE_CLAMP)
    end

    local icon = GetAbilityIcon(ABILITY_IDS[1])
    if icon and icon ~= "" then
        iconTex:SetTexture(icon)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= NWT.name then return end
    EM:UnregisterForEvent(NWT.name, EVENT_ADD_ON_LOADED)

    -- pro server getrennt speichern (EU / NA / PTS)
    NWT.sv = ZO_SavedVars:NewAccountWide("NothingWastedTrackerSV", 1, GetWorldName(), defaults)
    -- aus 4.x nicht mehr genutzt
    NWT.sv.borderThickness = nil

    UpdateClass()
    inCombat = IsUnitInCombat("player")

    GrabControls()
    CreatePips()
    CreateAnimations()
    InitDecay()

    fragment = ZO_HUDFadeSceneFragment:New(panel)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    RestorePosition()
    ApplyLayout()
    ApplyColors()
    ApplyLock()
    BuildMenu()

    -- filter komplett in C: ability-id + unit-tag, pro id ein namespace
    for _, id in ipairs(ABILITY_IDS) do
        local ns = NWT.name .. "Effect" .. id
        EM:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EM:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_UNIT_TAG, "player")
    end

    EM:RegisterForEvent(NWT.name, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EM:RegisterForEvent(NWT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    ForceRefresh()
end

EM:RegisterForEvent(NWT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
