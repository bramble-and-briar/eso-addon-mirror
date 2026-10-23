-----------------------------------------------------
-- Grrr
-- Mobitor forced me to do this..
-- Creds to @Geldis and @Mobitor
-----------------------------------------------------
local ADDON_NAME = "AnimatedActionBarPlus"
local EM         = EVENT_MANAGER
local WM         = WINDOW_MANAGER

-- dunkles farbschema: violett/purpur als basis, giftgrün als haupt-akzent,
-- rot für warnungen. eine zentrale palette, damit chat und ui gleich aussehen
local AAB_COLORS = {
    accent   = "a970ff",  -- purpur, hauptakzent (titel, überschriften)
    accent2  = "7d4fd6",  -- dunkleres violett (rahmen, struktur)
    good     = "6fd66f",  -- giftgrün, ok/an
    bad      = "d64f4f",  -- rot, fehler/aus
    warn     = "d69a4f",  -- gedämpftes orange, hinweise
    value    = "c8a8ff",  -- helles lavendel, werte
    dim      = "8a7fa6",  -- gedämpftes grau-violett, sekundärtext
    trace    = "9a7fd6",  -- violett für /aab track
}

local ADDON_VERSION = "2.1.0"

-- werte dürfen auch negativ sein, die engine mag das aber nicht überall.
-- deshalb erst beim benutzen abfangen
local function Clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function SafeMS(v, fallback)
    v = math.abs(tonumber(v) or fallback or 1)
    if v < 1 then v = 1 end
    return math.floor(v)
end

local function SafeInterval(v, fallback)
    return math.max(16, SafeMS(v, fallback))
end

local function Alpha01(v)
    return Clamp(v, 0, 1)
end

local function SafeScale(v)
    return Clamp(v, 0.05, 5)
end

local ULT_SLOT_INDEX  = 8
local QUICKSLOT_INDEX = 9

local ULT_FRAME_CHILDREN   = { "Frame", "FillAnimationLeft", "FillAnimationRight" }
local ULT_SHIMMER_CHILDREN = { "Glow", "Burst", "ReadyLoop" }

local thinFrameApplied = false

local sv

local EDGE_TEXTURES = {
    classic = "AnimatedActionBarPlus/CustomEdge.dds",
    v2      = "AnimatedActionBarPlus/CustomEdge2.dds",
    purple  = "AnimatedActionBarPlus/CustomEdgePurple.dds",
    red     = "AnimatedActionBarPlus/CustomEdgeRed.dds",
    blue    = "AnimatedActionBarPlus/CustomEdgeBlue.dds",
    aqua    = "AnimatedActionBarPlus/CustomEdgeAqua.dds",
    darkred    = "AnimatedActionBarPlus/CustomEdgeDarkRed.dds",
    darkpurple = "AnimatedActionBarPlus/CustomEdgeDarkPurple.dds",
}

local function GetEdgeTemplate()
    -- classic nutzt das standard-template, alle anderen die v2-struktur
    if sv and sv.edgeStyle and sv.edgeStyle ~= "classic" then
        return "ALT_ActionButton_V2"
    end
    return "ALT_ActionButton"
end

local function SetSlotEdge(slot)
    if not slot then return end
    local backdrop = slot:GetNamedChild("Backdrop")
    if backdrop and backdrop.SetEdgeTexture then
        local file = EDGE_TEXTURES[sv and sv.edgeStyle] or EDGE_TEXTURES.classic
        backdrop:SetEdgeTexture(file, 128, 16)
    end
end

local SuppressVanillaUltGlow

local function ApplyThinFrameTemplate()
    if thinFrameApplied then return end

    if ZO_ActionBar1 then
        ApplyTemplateToControl(ZO_ActionBar1, "ALT_ActionBar1")
    end

    SecurePostHook(ActionButton, "ApplyStyle", function(self)
        if self and self.slot then
            ApplyTemplateToControl(self.slot, GetEdgeTemplate())
            SetSlotEdge(self.slot)

            if self.slot.slotNum == ULT_SLOT_INDEX then
                -- den dicken vanilla-ulti-rahmen plus die fill-animationen immer plattmachen.
                -- im controller-modus zeichnen wir stattdessen unsere eigene fortschritts-border.
                for _, name in ipairs(ULT_FRAME_CHILDREN) do
                    local c = self.slot:GetNamedChild(name)
                    if c then
                        c:SetAlpha(0)
                        if c.SetHidden then c:SetHidden(true) end
                    end
                end
                -- Glow/Burst/ReadyLoop sind das originale ulti-schimmern von ESO.
                -- nur ausblenden, wenn der spieler es explizit abgeschaltet hat
                -- sonst macht vanilla das schimmern wie gewohnt.
                if sv and not sv.vanillaUltShimmer then
                    for _, name in ipairs(ULT_SHIMMER_CHILDREN) do
                        local c = self.slot:GetNamedChild(name)
                        if c then
                            c:SetAlpha(0)
                            if c.SetHidden then c:SetHidden(true) end
                        end
                    end
                end
            end
        end
    end)

    for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ULT_SLOT_INDEX do
        local btn = ZO_ActionBar_GetButton(slotNum)
        if btn and btn.slot then
            ApplyTemplateToControl(btn.slot, GetEdgeTemplate())
            SetSlotEdge(btn.slot)
        end
    end
    SuppressVanillaUltGlow()

    thinFrameApplied = true
end

-- controller-modus wie am pc. werte aus KEYBOARD_CONSTANTS (actionbar.lua)
local KbLook = {}
KbLook.LAYOUT = {
    abilitySlotOffsetX                    = 2,
    ultimateSlotOffsetX                   = 62,
    quickslotOffsetXFromCompanionUltimate = 18,
    quickslotOffsetXFromFirstSlot         = 5,
    backRowSlotOffsetY                    = -17,
    backRowUltimateSlotOffsetY            = -20,
    width                                 = 483,
    weaponSwapOffsetX                     = 59,
    weaponSwapOffsetY                     = -4,
    borderUp                              = "EsoUI/Art/ActionBar/abilityFrame64_up.dds",
    borderDown                            = "EsoUI/Art/ActionBar/abilityFrame64_down.dds",
    timerFrame                            = "EsoUI/Art/ActionBar/backrow_abilityFrame.dds",
}

function KbLook.Active()
    return sv and sv.gamepadKeyboardLayout and IsInGamepadPreferredMode()
end

-- FAB+ baut die leiste selbst, dem melden wir nur tastatur-modus
function KbLook.FabLoaded()
    return type(FancyActionBar) == "table" and type(FancyActionBar.GetUIMode) == "function"
end

function KbLook.ToKeyboardTemplate(template)
    if type(template) ~= "string" then return template end
    return (template:gsub("_Gamepad_Template$", "_Keyboard_Template"))
end

function KbLook.HideUltFrames(slot)
    for _, name in ipairs(ULT_FRAME_CHILDREN) do
        local c = slot:GetNamedChild(name)
        if c then
            c:SetAlpha(0)
            if c.SetHidden then c:SetHidden(true) end
        end
    end
end

-- vor dem thin-frame-hook installieren, ALT soll zuletzt drauf
KbLook.hooked = false
function KbLook.InstallHooks()
    if KbLook.hooked then return end
    KbLook.hooked = true

    SecurePostHook(ActionButton, "ApplyStyle", function(self, template)
        if not KbLook.Active() or not self.slot then return end
        local kb = KbLook.ToKeyboardTemplate(template)
        if kb ~= template then
            ApplyTemplateToControl(self.slot, kb)
            -- FAB+ template nochmal drüber, sonst stimmt die reihenfolge nicht
            if KbLook.FabLoaded() and FancyActionBar.GetConstants then
                local style = FancyActionBar.GetConstants()
                local fabTpl = style and (self.ultimateReadyBurstTimeline and style.ultButtonTemplate or style.buttonTemplate)
                if fabTpl then ApplyTemplateToControl(self.slot, fabTpl) end
            end
        end
        -- rest von ApplyStyle der am gamepad hängt
        if self.button then
            self.button:SetNormalTexture(KbLook.LAYOUT.borderUp)
            self.button:SetPressedTexture(KbLook.LAYOUT.borderDown)
        end
        if self.countText then self.countText:SetFont("ZoFontGameShadow") end
        local deco = self.slot:GetNamedChild("Decoration")
        if deco then deco:SetHidden(false) end
        if self.cooldown and self.showingCooldown then self.cooldown:SetHidden(false) end
        if self.cooldownEdge then self.cooldownEdge:SetHidden(true) end
        if self.ApplySwapAnimationStyle then self:ApplySwapAnimationStyle() end
    end)

    -- runder cooldown statt füllkante
    SecurePostHook(ActionButton, "UpdateCooldown", function(self)
        if not KbLook.Active() then return end
        if self.cooldown and self.showingCooldown then self.cooldown:SetHidden(false) end
        if self.cooldownEdge then self.cooldownEdge:SetHidden(true) end
    end)
    SecurePostHook(ActionButton, "SetCooldownEdgeState", function(self)
        if KbLook.Active() and self.cooldownEdge then self.cooldownEdge:SetHidden(true) end
    end)

    -- ulti: pc-balken, keine LB/RB
    SecurePostHook(ActionButton, "SetUltimateMeter", function(self, ultimateCount)
        if not KbLook.Active() or not self.slot or KbLook.FabLoaded() then return end
        local bar  = self.slot:GetNamedChild("UltimateBar")
        local edge = self.slot:GetNamedChild("LeadingEdge")
        if bar and edge then
            local used = IsSlotUsed(ULT_SLOT_INDEX, self:GetHotbarCategory())
            local max  = self.currentUltimateMax or 0
            local full = max > 0 and (ultimateCount or 0) >= max
            bar:SetHidden(not used or full)
            edge:SetHidden(not used or full)
        end
        KbLook.HideUltFrames(self.slot)
        if self.HideKeys then self:HideKeys(true) end
    end)

    -- backbar-timer
    if ZO_ActionBarTimer and ZO_ActionBarTimer.ApplyStyle then
        SecurePostHook(ZO_ActionBarTimer, "ApplyStyle", function(self, template)
            if not KbLook.Active() or not self.slot then return end
            local kb = KbLook.ToKeyboardTemplate(template)
            if kb ~= template then ApplyTemplateToControl(self.slot, kb) end
            if self.frame then self.frame:SetTexture(KbLook.LAYOUT.timerFrame) end
        end)
    end
end

-- leiste wie am pc verankern
function KbLook.ApplyBarLayout()
    if not KbLook.Active() or not ZO_ActionBar1 or KbLook.FabLoaded() then return end
    local L = KbLook.LAYOUT

    ZO_ActionBar1:ClearAnchors()
    ZO_ActionBar1:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, 0)
    ZO_ActionBar1:SetWidth(L.width)

    local swap = ZO_ActionBar1:GetNamedChild("WeaponSwap")
    if not swap then return end
    swap:ClearAnchors()
    swap:SetAnchor(TOPLEFT, nil, TOPLEFT, L.weaponSwapOffsetX, L.weaponSwapOffsetY)
    if ZO_WeaponSwap_SetPermanentlyHidden then ZO_WeaponSwap_SetPermanentlyHidden(swap, false) end
    local keybindBG = ZO_ActionBar1:GetNamedChild("KeybindBG")
    if keybindBG then keybindBG:SetHidden(false) end

    local active = GetActiveHotbarCategory()
    local back   = (active == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    local first  = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1

    local prev, firstBtn = swap, nil
    for slotNum = first, ULT_SLOT_INDEX - 1 do
        local btn = ZO_ActionBar_GetButton(slotNum, active)
        if btn and btn.slot then
            btn.slot:ClearAnchors()
            btn:ApplyAnchor(prev, L.abilitySlotOffsetX)
            local bb = ZO_ActionBar_GetButton(slotNum, back)
            if bb and bb.ApplyAnchor and bb ~= btn then bb:ApplyAnchor(btn.slot, L.backRowSlotOffsetY) end
            prev = btn.slot
            firstBtn = firstBtn or btn
        end
    end

    local ult = ZO_ActionBar_GetButton(ULT_SLOT_INDEX, active)
    if ult and ult.slot then
        ult.slot:ClearAnchors()
        ult:ApplyAnchor(prev, L.ultimateSlotOffsetX)
        if ult.SetShowBindingText then ult:SetShowBindingText(true) end
        local bb = ZO_ActionBar_GetButton(ULT_SLOT_INDEX, back)
        if bb and bb.ApplyAnchor and bb ~= ult then bb:ApplyAnchor(ult.slot, L.backRowUltimateSlotOffsetY) end
    end

    local comp = HOTBAR_CATEGORY_COMPANION and ZO_ActionBar_GetButton(ULT_SLOT_INDEX, HOTBAR_CATEGORY_COMPANION)
    if comp and comp.slot and firstBtn then
        comp.slot:ClearAnchors()
        comp:ApplyAnchor(firstBtn.slot, L.ultimateSlotOffsetX, true)
        if comp.SetShowBindingText then comp:SetShowBindingText(true) end
    end

    local qs = ZO_ActionBar_GetButton(GetCurrentQuickslot and GetCurrentQuickslot() or QUICKSLOT_INDEX, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if qs and qs.slot then
        qs.slot:ClearAnchors()
        local hasComp = comp and DoesUnitExist("companion") and HasActiveCompanion()
        if hasComp then
            qs:ApplyAnchor(comp.slot, L.quickslotOffsetXFromCompanionUltimate, true)
        else
            qs:ApplyAnchor(swap, L.quickslotOffsetXFromFirstSlot, true)
        end
    end

    local ref = ZO_ActionBar1.hudElementRef
    if ref and ZO_Anchor then
        ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, -68, -20):Set(ref)
        ZO_Anchor:New(BOTTOMRIGHT, nil, BOTTOMRIGHT, 2, 0):AddToControl(ref)
    end
end

KbLook.fabPatched = false
function KbLook.PatchFab()
    if KbLook.fabPatched or not KbLook.FabLoaded() then return end
    KbLook.fabPatched = true

    local origMode = FancyActionBar.GetUIMode
    FancyActionBar.GetUIMode = function(...)
        local mode = origMode(...)
        if mode == 2 and KbLook.Active() then return 1 end
        return mode
    end

    -- presets setzen das flag sonst zurück
    local origPreset = FancyActionBar.RefreshAfterPresetApply
    if type(origPreset) == "function" then
        FancyActionBar.RefreshAfterPresetApply = function(...)
            origPreset(...)
            if KbLook.Active() then
                FancyActionBar.useGamepadActionBar = false
                if FancyActionBar.UpdateBarSettings then FancyActionBar.UpdateBarSettings(nil, { skipSlots = true }) end
            end
        end
    end
end

-- wie FAB+ OnUIModeChanged, nur ohne das flag zu überschreiben
function KbLook.RefreshFab()
    if not KbLook.FabLoaded() then return end
    local F = FancyActionBar
    F.useGamepadActionBar = IsInGamepadPreferredMode() and not KbLook.Active()
    if F.UpdateBarSettings then F.UpdateBarSettings(nil, { skipSlots = true }) end
    if F.RefreshActiveBarSlots then F.RefreshActiveBarSlots() end
    if F.SlotEffects then F.SlotEffects() end
    if F.SyncEffectState then F.SyncEffectState("slotted") end
    if F.RefreshHotbarPresentation then F.RefreshHotbarPresentation(nil, false) end
end

-- alles neu stylen, die hooks machen den rest
function KbLook.Refresh()
    if KbLook.FabLoaded() then
        KbLook.RefreshFab()
        if not KbLook.Active() then return end
    elseif not KbLook.Active() then
        return
    end
    local active = GetActiveHotbarCategory()
    local back   = (active == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ULT_SLOT_INDEX do
        local isUlt = slotNum == ULT_SLOT_INDEX
        local btn = ZO_ActionBar_GetButton(slotNum, active)
        if btn and btn.ApplyStyle then
            btn:ApplyStyle(ZO_GetPlatformTemplate(isUlt and "ZO_UltimateActionButton" or "ZO_ActionButton"))
            if isUlt and btn.UpdateUltimateMeter then btn:UpdateUltimateMeter() end
        end
        local bb = ZO_ActionBar_GetButton(slotNum, back)
        if bb and bb.ApplyStyle then
            bb:ApplyStyle(ZO_GetPlatformTemplate(isUlt and "ZO_ActionBarTimer_BackBarSlot_Ultimate" or "ZO_ActionBarTimer_BackBarSlot"))
        end
    end
    local qs = ZO_ActionBar_GetButton(GetCurrentQuickslot and GetCurrentQuickslot() or QUICKSLOT_INDEX, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if qs and qs.ApplyStyle then qs:ApplyStyle(ZO_GetPlatformTemplate("ZO_ActionButton")) end
    if KbLook.FabLoaded() then KbLook.RefreshFab() else KbLook.ApplyBarLayout() end
end

function KbLook.Queue(delayMS)
    if not KbLook.Active() or KbLook.FabLoaded() then return end
    zo_callLater(KbLook.ApplyBarLayout, delayMS or 100)
end

SuppressVanillaUltGlow = function()
    local btn = ZO_ActionBar_GetButton(ULT_SLOT_INDEX)
    if not btn or not btn.slot then return end
    for _, name in ipairs(ULT_FRAME_CHILDREN) do
        local c = btn.slot:GetNamedChild(name)
        if c then
            -- nur ausblenden, nicht die textur löschen (SetTexture("") wäre irreversibel).
            c:SetAlpha(0)
            if c.SetHidden then c:SetHidden(true) end
        end
    end
    -- schimmern nur wegnehmen, wenn der spieler es will
    if sv and not sv.vanillaUltShimmer then
        for _, name in ipairs(ULT_SHIMMER_CHILDREN) do
            local c = btn.slot:GetNamedChild(name)
            if c then
                c:SetAlpha(0)
                if c.SetHidden then c:SetHidden(true) end
            end
        end
    end
end

-- holt das vanilla-ulti-schimmern zurück, falls es vorher unterdrückt wurde
local function RestoreVanillaUltShimmer()
    local btn = ZO_ActionBar_GetButton(ULT_SLOT_INDEX)
    if not btn or not btn.slot then return end
    for _, name in ipairs(ULT_SHIMMER_CHILDREN) do
        local c = btn.slot:GetNamedChild(name)
        if c and c.SetHidden then c:SetHidden(false) end
    end
    if btn.ApplyStyle then btn:ApplyStyle() end
end

local defaults = {

    bounceEnabled        = true,
    bounceOnProc         = true,
    animationStyle       = "bounce",

    -- animation wenn ein effekt/buff eines geslotteten skills ausläuft
    expireAnimEnabled    = true,
    expireAnimStyle      = "inherit",  -- "inherit" = gleiche wie beim drücken
    expireStrength       = 1.0,        -- multiplikator auf die stärke der animation
    expireGlowEnabled    = true,
    expireGlowColor      = { 1.0, 0.3, 0.15, 1.0 },  -- warnfarbe: der effekt ist abgelaufen

    -- länge der end-anim an die skill-dauer koppeln. kurze buffs blitzen knapp,
    -- lange (20s+) laufen etwas gedehnter aus
    expireScaleByDuration = true,
    expireScaleRefMS      = 10000,  -- referenzdauer, hier läuft die anim normal schnell
    expireScaleMin        = 0.6,
    expireScaleMax        = 1.8,
    -- pro-skill feuer-zeitpunkt via /aab setend <id> <ms|auto>. key = id (string),
    -- value = ms nach cast. "auto" löscht den eintrag
    expireDurationOverride = {},

    shrinkScale          = 0.9,
    growScale            = 1.1,
    frameResetTimeMS     = 167,

    glowEnabled          = true,
    glowColor            = { 1.0, 0.85, 0.2, 1.0 },
    glowDurationMS       = 600,
    glowPadding          = 12,
    glowIntensity        = 1.0,

    pulseEnabled         = true,
    pulseDurationMS      = 800,
    pulseMinAlpha        = 0.25,
    pulseMaxAlpha        = 1.0,

    ultBounceEnabled     = true,
    vanillaUltShimmer    = true,

    -- "custom" = eigener glow-rahmen (standard), "controller" = eigene fortschritts-border (füllt sich von unten)
    ultBorderStyle       = "custom",
    ultCtrlStyle         = "flat",   -- kanten-optik: "flat" | "bevel" | "sleek" | "chamfer" | "double"
    ultCtrlPadding       = 2,        -- abstand der border nach außen vom slot
    ultCtrlThickness     = 3,        -- dicke der rahmenlinie (dünn bis dick)
    ultCtrlCornerFrac    = 0.30,     -- länge der ecken-stege (anteil der slotbreite)
    ultCtrlPollMS        = 120,      -- wie oft der füllstand nachgeführt wird
    ultCtrlShowTrack     = true,     -- dunkle hintergrundschiene zeigen
    ultCtrlColorShift    = true,     -- farbverlauf lädt->bereit
    ultCtrlChargingColor = { 0.55, 0.55, 0.6, 1 },  -- farbe bei 0% (wenn farbverlauf an)
    ultCtrlGlowOnFull    = true,     -- leuchtrand + puls bei voller ulti
    ultCtrlGlowStyle     = "sharp",  -- leucht-optik: "soft" | "sharp" | "ring"
    ultCtrlGlowSpread    = 3,        -- wie weit der voll-glow über die kante hinausragt
    ultCtrlGlowIntensity = 0.7,
    ultCtrlPulseMS       = 450,
    ultCtrlRainbow       = false,    -- regenbogen-farbverlauf für die border bei voller ulti

    -- gamepad-ulti-rahmen
    ultGpFrameEnabled     = false,
    ultGpFrameColor       = { 1, 1, 1, 1 },   -- weiß = originalfarben der textur
    ultGpFillColor        = { 1, 1, 1, 1 },
    ultGpFullColorEnabled = false,
    ultGpFullColor        = { 1.0, 0.8, 0.2, 1 },
    ultGpRainbow          = false,

    -- press-glow speziell für den ulti-slot (unabhängig vom normalen glow)
    ultGlowEnabled       = true,
    ultGlowColor         = { 1.0, 0.55, 0.1, 1.0 },  -- warmes orange
    ultGlowDurationMS    = 900,                       -- länger als bei normalen skills
    ultGlowPadding       = 16,                        -- größer
    ultGlowIntensity     = 1.2,

    ultReadyEnabled      = true,
    ultReadyColor        = { 1.0, 0.2, 0.0, 1.0 },
    ultReadyPulse        = true,
    ultReadyMode         = "smooth", -- "smooth" = sanfter pulse, "blink" = hartes an/aus
    ultReadyBlinkIntMS   = 250,      -- blink-intervall (an/aus-wechsel)
    ultReadyPadding      = 8,
    ultReadyPulseDurMS   = 900,   -- pulsier-dauer (niedrig = schnell)
    ultReadyMinAlpha     = 0.35,  -- min-alpha im pulse
    ultReadyIntensity    = 1.0,   -- helligkeits-multiplikator max (1.0-2.0)

    -- sekundärfarbe für den ulti-rahmen im blink-modus
    ultColorCycleEnabled   = false,
    ultColorCycleSecondary = { 1.0, 0.85, 0.2, 1.0 },

    -- rainbow modus einstellungen
    ultRainbowSaturation   = 1.0,  -- 0.0-1.0: wie gesättigt die farben sind
    ultRainbowLightness    = 0.5,  -- 0.0-1.0: wie hell/dunkel die farben sind

    -- den engine-seitigen proc-glow von ESO abschalten,
    -- analog zum vanillaUltShimmer beim ulti.
    vanillaProcGlow      = true,

    thinFrameEnabled     = true,
    -- im controller-modus trotzdem pc-leiste
    gamepadKeyboardLayout = true,
    frameAlpha           = 1.0,
    edgeStyle            = "classic",  -- "classic" = CustomEdge.dds, "v2" = CustomEdge2.dds

    pulseMode            = "smooth",
    blinkIntervalMS      = 250,
    strobeIntervalMS     = 80,

    colorCycleEnabled    = false,
    colorCycleSecondary  = { 1.0, 0.1, 0.1, 1.0 },

    stopGlowOnPress      = true,

    -- quickslot (q)
    quickslotBounceEnabled = true,
    quickslotReadyEnabled  = true,

    -- performance-kram, alles standardmäßig aus. ändert nur wie effizient das
    -- intern läuft, nicht die optik. für große kämpfe (trials, cyro) gedacht
    perfEffectIdFilter   = false,
    perfSlotLookupMap    = false,
    perfCombatOnly       = false,
    perfSlowRainbow      = false,
    perfSingleStyleHook  = false,
    perfLimitTimelineCache = false,

    -- einmaliger hinweis-dialog nach der installation. bleibt true sobald der
    -- nutzer bestätigt hat, dann poppt er nie wieder von selbst auf
    infoDialogShown      = false,

    -- studio
    uiLastPage           = "bounce",
    uiAutoDemo           = true,
    uiProcSim            = true,
    uiTheme              = "nebula",   -- "nebula" oder "lace"
    uiBgMotion           = true,       -- hintergrund im studio bewegt sich
}

-- true = animationen erlaubt. nur bei perfCombatOnly außerhalb kampf false
local inCombat = true

local function GetActionSlotControl(slotNum, hotbarCategory)
    return ZO_ActionBar_GetButton(slotNum, hotbarCategory)
end

local function GetFlipCard(btn)
    if not btn then return nil end
    return btn.FlipCard or (btn.slot and btn.slot:GetNamedChild("FlipCard"))
end

local function IsUltSlot(slotNum) return slotNum == ULT_SLOT_INDEX end

-- ohne mechanik-flag kommt bei neueren clients 0 zurück
local function GetUltCost()
    local cost = 0
    if COMBAT_MECHANIC_FLAGS_ULTIMATE then
        cost = GetSlotAbilityCost(ULT_SLOT_INDEX, COMBAT_MECHANIC_FLAGS_ULTIMATE, GetActiveHotbarCategory()) or 0
    end
    if cost <= 0 then cost = GetSlotAbilityCost(ULT_SLOT_INDEX) or 0 end
    return cost
end

local HideUltBorder
local CheckUltimateReady
local PauseUltBorderPulse
local PlayQuickslotGlow
local PlayQuickslotBounce
local PlayPreviewAnim
local PlaySlotAnimation
local ResolveSlotButton
local InvalidateAnimTimelines
local TrackExpireOnCast
local RebuildSlotLookup
local RefreshEffectRegistration

local function BounceEnabledFor(slotNum)
    if IsUltSlot(slotNum) then return sv.ultBounceEnabled end
    return sv.bounceEnabled
end

-- außerhalb kampf keine animation wenn perfCombatOnly an ist
local function AnimAllowed()
    if sv.perfCombatOnly and not inCombat then return false end
    return true
end

local function GlowEnabledFor(slotNum)
    if IsUltSlot(slotNum) then return sv.ultGlowEnabled end
    return sv.glowEnabled
end

local function GlowColorFor(slotNum)
    if IsUltSlot(slotNum) then return sv.ultGlowColor end
    return sv.glowColor
end

local function GlowDurationFor(slotNum)
    if IsUltSlot(slotNum) then return sv.ultGlowDurationMS end
    return sv.glowDurationMS
end

local function GlowPaddingFor(slotNum)
    if IsUltSlot(slotNum) then return sv.ultGlowPadding end
    return sv.glowPadding
end

local function GlowIntensityFor(slotNum)
    if IsUltSlot(slotNum) then return sv.ultGlowIntensity or 1.0 end
    return sv.glowIntensity or 1.0
end

-- bounce

local function InstallBounceHook()
    local timelines = setmetatable({}, { __mode = "k" })

    local function GetIcon(button)

        if not button or not button.slot then return nil end
        return button.icon or button.slot:GetNamedChild("Icon")
    end

    local function GetBackdrop(button)
        if not button or not button.slot then return nil end
        return button.slot:GetNamedChild("Backdrop")
    end

    -- damit sauber von der mitte aus skaliert/gedreht wird statt aus der ecke
    local function SetCenterOrigin(c)
        if c and c.SetTransformNormalizedOriginPoint then
            c:SetTransformNormalizedOriginPoint(0.5, 0.5, 0)
        end
    end

    local function BuildBounce(flip, tl, button, p)
        SetCenterOrigin(flip)

        local s = tl:InsertAnimation(ANIMATION_SCALE, flip)
        s:SetScaleValues(1.0, p.shrink); s:SetDuration(60)
        s:SetEasingFunction(ZO_EaseOutQuadratic)

        local g = tl:InsertAnimation(ANIMATION_SCALE, flip, 60)
        g:SetScaleValues(p.shrink, p.grow); g:SetDuration(80)
        g:SetEasingFunction(ZO_EaseOutQuadratic)

        local r = tl:InsertAnimation(ANIMATION_SCALE, flip, 140)
        r:SetScaleValues(p.grow, 1.0); r:SetDuration(SafeMS(sv.frameResetTimeMS, 167))
        r:SetEasingFunction(ZO_EaseInQuadratic)

        local backdrop = GetBackdrop(button)
        if backdrop then
            SetCenterOrigin(backdrop)

            local bs = tl:InsertAnimation(ANIMATION_SCALE, backdrop)
            bs:SetScaleValues(1.0, p.shrink); bs:SetDuration(60)
            bs:SetEasingFunction(ZO_EaseOutQuadratic)

            local bg = tl:InsertAnimation(ANIMATION_SCALE, backdrop, 60)
            bg:SetScaleValues(p.shrink, p.grow); bg:SetDuration(80)
            bg:SetEasingFunction(ZO_EaseOutQuadratic)

            local br = tl:InsertAnimation(ANIMATION_SCALE, backdrop, 140)
            br:SetScaleValues(p.grow, 1.0); br:SetDuration(SafeMS(sv.frameResetTimeMS, 167))
            br:SetEasingFunction(ZO_EaseInQuadratic)
        end
    end

    local function BuildFlash(flip, tl, button, p)

        local target = GetIcon(button) or flip
        local dur = math.max(60, math.floor(SafeMS(sv.frameResetTimeMS, 167) * 0.4))
        local up = tl:InsertAnimation(ANIMATION_ALPHA, target)
        up:SetAlphaValues(1.0, p.minAlpha); up:SetDuration(dur)
        up:SetEasingFunction(ZO_EaseOutQuadratic)
        local down = tl:InsertAnimation(ANIMATION_ALPHA, target, dur)
        down:SetAlphaValues(p.minAlpha, 1.0); down:SetDuration(dur)
        down:SetEasingFunction(ZO_EaseInQuadratic)
    end

    local function BuildShake(flip, tl, button, p)
        local step = 40
        local off  = math.floor(8 * (p.grow - 1.0) * 10) + 4
        -- nur die FlipCard bewegen, der rahmen hängt dran. den rahmen selbst
        -- verschieben zerlegt seine zwei anker (kante oben/links weg)
        local _, _, _, _, bx, by = flip:GetAnchor(0)
        bx, by = bx or 0, by or 0
        local a1 = tl:InsertAnimation(ANIMATION_TRANSLATE, flip)
        a1:SetTranslateOffsets(bx, by, bx - off, by); a1:SetDuration(step)
        a1:SetEasingFunction(ZO_EaseOutQuadratic)
        local a2 = tl:InsertAnimation(ANIMATION_TRANSLATE, flip, step)
        a2:SetTranslateOffsets(bx - off, by, bx + off, by); a2:SetDuration(step * 2)
        a2:SetEasingFunction(ZO_EaseInOutQuadratic)
        local a3 = tl:InsertAnimation(ANIMATION_TRANSLATE, flip, step * 3)
        a3:SetTranslateOffsets(bx + off, by, bx - off, by); a3:SetDuration(step * 2)
        a3:SetEasingFunction(ZO_EaseInOutQuadratic)
        local a4 = tl:InsertAnimation(ANIMATION_TRANSLATE, flip, step * 5)
        a4:SetTranslateOffsets(bx - off, by, bx, by); a4:SetDuration(step)
        a4:SetEasingFunction(ZO_EaseInQuadratic)
    end

    local function BuildTilt(flip, tl, button, p)

        SetCenterOrigin(flip)
        local maxRad = 0.30 * (p.grow - 0.9) / 0.2
        local totalMs = math.max(180, SafeMS(sv.frameResetTimeMS, 167) + 100)
        local backdrop = GetBackdrop(button)
        SetCenterOrigin(backdrop)
        local custom = tl:InsertAnimation(ANIMATION_CUSTOM, flip)
        custom:SetDuration(totalMs)
        custom:SetEasingFunction(ZO_LinearEase)
        custom:SetUpdateFunction(function(_, progress)

            local angle = math.sin(progress * math.pi * 2) * maxRad
            if flip.SetTransformRotationZ then
                flip:SetTransformRotationZ(angle)
            end
            -- rahmen drehen
            if backdrop and backdrop.SetTransformRotationZ then
                backdrop:SetTransformRotationZ(angle)
            end
        end)
    end

    local STYLE_BUILDERS = {
        bounce = BuildBounce,
        flash  = BuildFlash,
        shake  = BuildShake,
        tilt   = BuildTilt,
    }

    -- eingestellten stärke, "press" nutzt die normalen slider-werte
    local function BuildParams(variant)
        local grow   = tonumber(sv.growScale) or 1.1
        local shrink = tonumber(sv.shrinkScale) or 0.9
        if variant == "expire" then
            local st = tonumber(sv.expireStrength) or 1.0
            return {
                grow     = SafeScale(1 + (grow - 1) * st),
                shrink   = SafeScale(1 - (1 - shrink) * st),
                minAlpha = Clamp(1 - 0.75 * math.abs(st), 0.05, 0.9),
            }
        end
        return { grow = SafeScale(grow), shrink = SafeScale(shrink), minAlpha = 0.25 }
    end

    -- scale streckt/staucht alle einzelanimationen der timeline im gleichen
    -- verhältnis. wird nur für die expire-variante genutzt (dauer-koppelung).
    local function BuildTimeline(button, style, variant, scale)
        local flip = GetFlipCard(button)
        if not flip then return nil end
        local builder = STYLE_BUILDERS[style] or BuildBounce
        local tl = ANIMATION_MANAGER:CreateTimeline()
        builder(flip, tl, button, BuildParams(variant))
        if scale then scale = Clamp(scale, 0.05, 10) end
        if scale and scale ~= 1.0 then
            -- offset und dauer jeder animation skalieren, sonst verrutscht das timing
            local i = 1
            local a = tl:GetAnimation(i)
            while a do
                if a.GetDuration and a.SetDuration then
                    a:SetDuration(math.max(1, math.floor(a:GetDuration() * scale)))
                end
                if a.GetAnimationOffset and a.SetAnimationOffset then
                    a:SetAnimationOffset(math.floor((a:GetAnimationOffset() or 0) * scale))
                end
                i = i + 1
                a = tl:GetAnimation(i)
            end
        end
        return tl
    end

    -- faktor in grobe stufen runden, damit nicht für jede millisekunde eine
    -- eigene timeline im cache landet (0.05er-raster reicht optisch dicke).
    local function BucketScale(scale)
        return math.floor((scale or 1.0) * 20 + 0.5) / 20
    end

    -- pro button + style + variante (+ dauer-bucket) cachen, weil press- und
    -- expire-animation unterschiedliche styles, stärken und längen haben können
    local function GetOrBuildTimeline(button, style, variant, scale)
        style   = style or sv.animationStyle or "bounce"
        variant = variant or "press"
        scale   = BucketScale(scale)
        local cacheKey = style .. "@" .. variant .. "@" .. scale
        local perButton = timelines[button]
        if not perButton then
            perButton = {}
            timelines[button] = perButton
        end
        local tl = perButton[cacheKey]
        if tl then return tl end
        tl = BuildTimeline(button, style, variant, scale)
        if not tl then return nil end
        perButton[cacheKey] = tl

        -- bei aktiver dauer-skalierung sammeln sich sonst pro button viele
        -- timelines an. älteste rauswerfen, kein echtes LRU aber reicht
        if sv.perfLimitTimelineCache then
            local order = perButton.__order
            if not order then order = {}; perButton.__order = order end
            order[#order + 1] = cacheKey
            local LIMIT = 6
            while #order > LIMIT do
                local oldest = table.remove(order, 1)
                if oldest ~= cacheKey then
                    local victim = perButton[oldest]
                    if victim and victim.Stop then victim:Stop() end
                    perButton[oldest] = nil
                end
            end
        end
        return tl
    end

    local quickslotButtonObj = nil

    ActionButton.PlayAbilityUsedBounce = function(self)
        -- q-slot objekt merken
        if self and self.slot and self.slot == _G["QuickslotButton"] then
            quickslotButtonObj = self
        end
        if not AnimAllowed() then return end
        local slotNum = self and self.slot and self.slot.slotNum
        if not BounceEnabledFor(slotNum) then return end
        local tl = GetOrBuildTimeline(self)
        if not tl then return end
        tl:PlayFromStart()
    end

    -- fancyactionbar+ werte
    local backbarAdapters = {}

    local function GetBackbarButton(slotNum)
        local ctrl = _G["ActionButton" .. (slotNum + 20)]
        if not ctrl or not ctrl.GetNamedChild then return nil end
        if not ctrl:GetNamedChild("FlipCard") then return nil end
        local adapter = backbarAdapters[slotNum]
        if not adapter or adapter.slot ~= ctrl then
            adapter = { slot = ctrl }
            backbarAdapters[slotNum] = adapter
        end
        return adapter
    end

    -- löst den button für slot + bar auf (frontbar vanilla, backbar fab+)
    ResolveSlotButton = function(slotNum, hotbarCategory)
        if hotbarCategory and hotbarCategory ~= GetActiveHotbarCategory() then
            return GetBackbarButton(slotNum)
        end
        return GetActionSlotControl(slotNum)
    end

    -- spielt eine animation auf einem slot ab, style ist frei wählbar.
    -- hotbarCategory optional: zeigt sie auf die inaktive bar, wird der
    PlaySlotAnimation = function(slotNum, style, hotbarCategory, variant, scale)
        if not slotNum then return end
        if not AnimAllowed() then return end
        local btn = ResolveSlotButton(slotNum, hotbarCategory)
        if not btn then return end
        local tl = GetOrBuildTimeline(btn, style, variant, scale)
        if tl then tl:PlayFromStart() end
    end

    -- quickslot, gleicher trick wie bei der backbar
    local quickslotAdapter = nil

    PlayQuickslotBounce = function()
        if not AnimAllowed() then return end
        if not sv.bounceEnabled or not sv.quickslotBounceEnabled then return end
        local ctrl = _G["QuickslotButton"]
        if not ctrl or not ctrl.GetNamedChild then return end

        local btn = quickslotButtonObj
        if not btn or btn.slot ~= ctrl then
            if not quickslotAdapter or quickslotAdapter.slot ~= ctrl then
                quickslotAdapter = {
                    slot     = ctrl,
                    FlipCard = _G["QuickslotButtonFlipCard"] or ctrl:GetNamedChild("FlipCard") or ctrl,
                }
            end
            btn = quickslotAdapter
        end

        local tl = GetOrBuildTimeline(btn)
        if not tl then return end
        if tl.IsPlaying and tl:IsPlaying() then tl:Stop() end
        tl:PlayFromStart()
    end

    -- vorschau im studio
    PlayPreviewAnim = function(adapter, style, variant, scale)
        if not adapter then return end
        local tl = GetOrBuildTimeline(adapter, style, variant, scale)
        if not tl then return end
        if tl.IsPlaying and tl:IsPlaying() then tl:Stop() end
        tl:PlayFromStart()
    end

    -- (scale, reset-zeit) sofort greifen statt erst nach reload
    InvalidateAnimTimelines = function()
        for _, perButton in pairs(timelines) do
            for _, tl in pairs(perButton) do
                if tl and tl.Stop then tl:Stop() end
            end
        end
        for k in pairs(timelines) do timelines[k] = nil end
    end
end

-- glow

local glowControls    = {}
local pulseTimelines  = {}
local activeProcs     = {}
local fadeTimelines   = {}

local function GetOrCreateGlow(slotNum)
    local existing = glowControls[slotNum]
    if existing then

        local btn = GetActionSlotControl(slotNum)
        local flip = GetFlipCard(btn)
        if flip and existing:GetParent() ~= flip then
            existing:SetParent(flip)
        end
        return existing
    end

    local btn = GetActionSlotControl(slotNum)
    if not btn or not btn.slot then return nil end

    local flip = GetFlipCard(btn)
    if not flip then return nil end

    local glow = WM:CreateControlFromVirtual(
        "AABPlus_Glow_" .. slotNum, flip, "AABPlus_GlowTemplate"
    )
    glowControls[slotNum] = glow
    return glow
end

local function AnchorGlow(glow, flipCard, padding)
    if not glow or not flipCard then return end
    glow:ClearAnchors()
    glow:SetAnchor(TOPLEFT,     flipCard, TOPLEFT,     -padding, -padding)
    glow:SetAnchor(BOTTOMRIGHT, flipCard, BOTTOMRIGHT,  padding,  padding)
end

local function PlayGlow(slotNum)
    if not GlowEnabledFor(slotNum) then return end
    local btn = GetActionSlotControl(slotNum)
    if not btn or not btn.slot then return end

    local flipCard = GetFlipCard(btn)
    local glow     = GetOrCreateGlow(slotNum)
    if not glow or not flipCard then return end

    local color    = GlowColorFor(slotNum)
    local duration = SafeMS(GlowDurationFor(slotNum), 600)
    local intensity = GlowIntensityFor(slotNum)
    local maxA      = Alpha01((color[4] or 1) * intensity)

    AnchorGlow(glow, flipCard, GlowPaddingFor(slotNum))
    glow:SetColor(color[1], color[2], color[3], maxA)
    glow:SetAlpha(maxA)

    local fade = fadeTimelines[slotNum]
    if not fade then
        fade = ANIMATION_MANAGER:CreateTimeline()
        fade:InsertAnimation(ANIMATION_ALPHA, glow)
        fadeTimelines[slotNum] = fade
    end
    local a = fade:GetAnimation(1)
    a:SetAnimatedControl(glow)
    a:SetAlphaValues(maxA, 0)
    a:SetDuration(duration)
    a:SetEasingFunction(ZO_EaseInQuadratic)
    fade:PlayFromStart()
end

-- quickslot

local quickslotGlow         = nil
local quickslotFadeTimeline = nil

PlayQuickslotGlow = function()
    if not sv.glowEnabled then return end

    local qsButton = _G["QuickslotButton"]
    local qsFlip   = _G["QuickslotButtonFlipCard"] or qsButton
    if not qsButton or not qsFlip then return end

    if not quickslotGlow then
        quickslotGlow = WM:CreateControlFromVirtual(
            "AABPlus_QuickslotGlow", qsFlip, "AABPlus_GlowTemplate"
        )
    elseif quickslotGlow:GetParent() ~= qsFlip then
        quickslotGlow:SetParent(qsFlip)
    end

    local color    = sv.glowColor
    local duration = SafeMS(sv.glowDurationMS, 600)
    local intensity = sv.glowIntensity or 1.0
    local maxA      = Alpha01((color[4] or 1) * intensity)

    AnchorGlow(quickslotGlow, qsFlip, sv.glowPadding)
    quickslotGlow:SetColor(color[1], color[2], color[3], maxA)
    quickslotGlow:SetAlpha(maxA)

    if not quickslotFadeTimeline then
        quickslotFadeTimeline = ANIMATION_MANAGER:CreateTimeline()
        quickslotFadeTimeline:InsertAnimation(ANIMATION_ALPHA, quickslotGlow)
    end
    local a = quickslotFadeTimeline:GetAnimation(1)
    a:SetAnimatedControl(quickslotGlow)
    a:SetAlphaValues(maxA, 0)
    a:SetDuration(duration)
    a:SetEasingFunction(ZO_EaseInQuadratic)
    quickslotFadeTimeline:PlayFromStart()
end

local function StartPulse(slotNum)
    if not GlowEnabledFor(slotNum) or not sv.pulseEnabled then return end
    if activeProcs[slotNum] then return end
    activeProcs[slotNum] = true

    local btn = GetActionSlotControl(slotNum)
    if not btn or not btn.slot then return end
    local flipCard = GetFlipCard(btn)
    local glow     = GetOrCreateGlow(slotNum)
    if not glow or not flipCard then return end

    local color = GlowColorFor(slotNum)
    local intensity = sv.glowIntensity or 1.0
    local maxA = Alpha01((sv.pulseMaxAlpha or 1.0) * intensity)
    local minA = Alpha01(sv.pulseMinAlpha)
    AnchorGlow(glow, flipCard, GlowPaddingFor(slotNum))
    glow:SetColor(color[1], color[2], color[3], maxA)

    local mode = sv.pulseMode or "smooth"

    if mode == "smooth" then
        local tl = ANIMATION_MANAGER:CreateTimeline()
        local a  = tl:InsertAnimation(ANIMATION_ALPHA, glow)
        a:SetAlphaValues(maxA, minA)
        a:SetDuration(SafeMS(sv.pulseDurationMS, 800))
        a:SetEasingFunction(ZO_EaseOutQuadratic)
        tl:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
        tl:PlayFromStart()
        pulseTimelines[slotNum] = tl
    else
        local interval  = SafeInterval((mode == "strobe") and sv.strobeIntervalMS or sv.blinkIntervalMS, 250)
        local updateId  = "AABPlusPulse_" .. slotNum
        local state     = false
        local c1        = color
        local c2        = sv.colorCycleSecondary
        local cycleColor = sv.colorCycleEnabled

        EM:RegisterForUpdate(updateId, interval, function()
            state = not state
            if state then
                glow:SetAlpha(maxA)
                if cycleColor then
                    glow:SetColor(c2[1], c2[2], c2[3], Alpha01((c2[4] or 1) * intensity))
                else
                    glow:SetColor(c1[1], c1[2], c1[3], Alpha01((c1[4] or 1) * intensity))
                end
            else
                if cycleColor then
                    glow:SetAlpha(maxA)
                    glow:SetColor(c1[1], c1[2], c1[3], Alpha01((c1[4] or 1) * intensity))
                else
                    glow:SetAlpha(minA)
                end
            end
        end)
        pulseTimelines[slotNum] = { updateId = updateId }
    end
end

local function StopPulse(slotNum)
    local entry = pulseTimelines[slotNum]
    if entry then
        if entry.Stop then
            entry:Stop()
        elseif entry.updateId then
            EM:UnregisterForUpdate(entry.updateId)
        end
        pulseTimelines[slotNum] = nil
    end
    activeProcs[slotNum] = nil
    local glow = glowControls[slotNum]
    if glow then glow:SetAlpha(0) end
end

local function StopAllPulses()
    local active = {}
    for s in pairs(activeProcs) do active[#active+1] = s end
    for _, s in ipairs(active) do StopPulse(s) end
    for _, glow in pairs(glowControls) do
        if glow then glow:SetAlpha(0) end
    end
end

local function IsSlotProcd(slotNum)
    return HasActivationHighlight(slotNum)
end


local suppressedProcGlows = {}

local function ApplyProcGlowSuppression(slotNum)
    local btn = GetActionSlotControl(slotNum)
    if not btn or not btn.slot then return end
    local engineGlow = btn.activationHighlight or btn.slot:GetNamedChild("Glow")
    if not engineGlow then return end

    if sv.vanillaProcGlow then
        -- vollständig wiederherstellen geht ohne reload nicht, weil die
        -- originaltextur weg ist. state trotzdem freigeben.
        suppressedProcGlows[slotNum] = nil
    else
        if engineGlow.SetTexture then engineGlow:SetTexture("") end
        engineGlow:SetAlpha(0)
        if engineGlow.SetHidden then engineGlow:SetHidden(true) end
        suppressedProcGlows[slotNum] = true
    end
end

local function RefreshProcGlowSuppression()
    for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX do
        ApplyProcGlowSuppression(slotNum)
    end
end

local function RefreshAllProcs()
    RefreshProcGlowSuppression()
    if not sv.pulseEnabled then return end
    for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX do
        if IsSlotProcd(slotNum) then
            StartPulse(slotNum)
            if BounceEnabledFor(slotNum) and sv.bounceOnProc then
                local btn = GetActionSlotControl(slotNum)
                if btn and btn.PlayAbilityUsedBounce then btn:PlayAbilityUsedBounce() end
            end
        else
            StopPulse(slotNum)
        end
    end
end

local function OnAbilitySlotted(_, slotNum)
    if not slotNum then return end
    local btn = GetActionSlotControl(slotNum)
    if btn and btn.PlayAbilityUsedBounce and BounceEnabledFor(slotNum) then
        btn:PlayAbilityUsedBounce()
    end

    -- expire-timer für den gecasteten skill stellen
    TrackExpireOnCast(slotNum)

    if IsUltSlot(slotNum) then
        PauseUltBorderPulse(600)
        zo_callLater(CheckUltimateReady, 150)
    end

    if sv.stopGlowOnPress and activeProcs[slotNum] then
        StopPulse(slotNum)
        return
    end

    PlayGlow(slotNum)
end

local function OnActivationHighlightChanged(_, slotNum, isShown)
    if not slotNum then return end

    -- engine-glow sofort unterdrücken bzw. wiederherstellen, sobald sich der
    -- proc-status ändert - nicht erst beim nächsten bar-wechsel.
    ApplyProcGlowSuppression(slotNum)

    -- auf das von ESO gemeldete flag nicht blind vertrauen
    local procd = isShown
    if procd == nil then procd = IsSlotProcd(slotNum) end

    if procd then
        StartPulse(slotNum)
        if BounceEnabledFor(slotNum) and sv.bounceOnProc then
            local btn = GetActionSlotControl(slotNum)
            if btn and btn.PlayAbilityUsedBounce then btn:PlayAbilityUsedBounce() end
        end
    else
        StopPulse(slotNum)
    end
end

-- direktes slot-update: update sobald ein proc aktiv/inaktiv wird,
-- ohne dass ein bar-wechsel nötig ist.
local function OnSingleSlotUpdated(_, slotNum)
    if not slotNum then return end
    if slotNum < ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1 or slotNum > ACTION_BAR_ULTIMATE_SLOT_INDEX then
        return
    end
    ApplyProcGlowSuppression(slotNum)
    if not sv.pulseEnabled then return end
    if IsSlotProcd(slotNum) then
        if not activeProcs[slotNum] then
            StartPulse(slotNum)
            if BounceEnabledFor(slotNum) and sv.bounceOnProc then
                local btn = GetActionSlotControl(slotNum)
                if btn and btn.PlayAbilityUsedBounce then btn:PlayAbilityUsedBounce() end
            end
        end
    else
        StopPulse(slotNum)
    end
end

-- der zuverlässigste punkt um auf proc-änderungen zu reagieren ist die
local activationHighlightHookInstalled = false
local function InstallActivationHighlightHook()
    if activationHighlightHookInstalled then return end
    if not ActionButton or not ActionButton.UpdateActivationHighlight then return end
    activationHighlightHookInstalled = true

    SecurePostHook(ActionButton, "UpdateActivationHighlight", function(self)
        if not self or not self.slot then return end
        local slotNum = self.slot.slotNum
        if not slotNum then return end
        if slotNum < ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1 or slotNum > ACTION_BAR_ULTIMATE_SLOT_INDEX then return end
        if slotNum == ULT_SLOT_INDEX then return end -- ulti hat eigene logik

        -- vanilla-glow killen direkt nachdem ESO ihn gesetzt hat
        if not sv.vanillaProcGlow then
            local glow = self.activationHighlight or self.slot:GetNamedChild("Glow")
            if glow then
                if glow.SetTexture then glow:SetTexture("") end
                glow:SetAlpha(0)
                if glow.SetHidden then glow:SetHidden(true) end
            end
        end

        -- proc-pulse gleich im selben frame, kein event-roundtrip nötig
        if sv.pulseEnabled then
            local procd = HasActivationHighlight(slotNum)
            if procd then
                if not activeProcs[slotNum] then
                    StartPulse(slotNum)
                    if BounceEnabledFor(slotNum) and sv.bounceOnProc and self.PlayAbilityUsedBounce then
                        self:PlayAbilityUsedBounce()
                    end
                end
            else
                if activeProcs[slotNum] then
                    StopPulse(slotNum)
                end
            end
        end
    end)
end

-- aktueller platz im rad
local QS = {}

function QS.GetSlot()
    if GetCurrentQuickslot then
        return GetCurrentQuickslot() or QUICKSLOT_INDEX
    end
    return QUICKSLOT_INDEX
end

-- alles unter 1.5s ist gcd
QS.MIN_COOLDOWN_MS = 1500

function QS.IsCooling(slot)
    local remain, duration = GetSlotCooldownInfo(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    remain   = remain or 0
    duration = duration or 0
    return remain > 0 and duration >= QS.MIN_COOLDOWN_MS
end

function QS.HasItem(slot)
    if IsSlotUsed then
        return IsSlotUsed(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) and true or false
    end
    return true
end

function QS.PlayEffects()
    PlayQuickslotBounce()
    PlayQuickslotGlow()
end

QS.UPDATE_NAME  = "AABPlus_QuickslotReady"
QS.POLL_MS = 100

QS.slot          = nil
QS.cooling       = false
QS.watching = false

function QS.StopWatch()
    if QS.watching then
        EM:UnregisterForUpdate(QS.UPDATE_NAME)
        QS.watching = false
    end
end


function QS.StartWatch()
    if QS.watching then return end
    QS.watching = true
    EM:RegisterForUpdate(QS.UPDATE_NAME, QS.POLL_MS, function() QS.Update() end)
end

QS.Update = function(silent)
    local slot    = QS.GetSlot()
    local cooling = QS.IsCooling(slot)

    if slot ~= QS.slot or silent then
        -- slotwechsel/login, nix abspielen
        QS.slot    = slot
        QS.cooling = cooling
    elseif cooling and not QS.cooling then
        QS.cooling = true
        QS.PlayEffects()
    elseif not cooling and QS.cooling then
        QS.cooling = false
        -- slot leer, kein ready
        if sv.quickslotReadyEnabled and QS.HasItem(slot) then
            QS.PlayEffects()
        end
    end

    -- cooldown-ende kommt nicht als event, also pollen
    if QS.cooling then
        QS.StartWatch()
    else
        QS.StopWatch()
    end
end

function QS.OnCooldowns()
    QS.Update()
end

function QS.Sync()
    QS.Update(true)
end

-- ultimate

local ultBorderGlow     = nil
local ultBorderTimeline = nil
local ultBorderBlinkId  = nil
local ultBorderRainbowId = nil
local ultIsReady        = false

-- eigene controller-fortschritts-border als 4-kanten-rahmen (viereckig, einstellbare dicke).
-- hintergrund-kanten (track) + fortschritts-kanten (fill, wachsen von unten) + voll-glow.
local ultCtrl        = nil   -- container-tabelle mit allen kanten-controls
local ultCtrlUpdate  = nil   -- EM-update-handle fürs live-nachführen
local ultCtrlWasFull = false -- kantenerkennung für den voll-puls
local ultCtrlGlowTL       = nil  -- wiederverwendete puls-timeline
local ultCtrlGlowPulseAnim = nil
local ultCtrlRainbowId    = nil  -- EM-update-handle für den regenbogen bei voller ulti

-- querschnitts-kacheln pro rahmen-stil (viereckig, werden zu kanten gestreckt).
local ULT_EDGE_TEX = {
    bevel   = "AnimatedActionBarPlus/UltEdgeBevel.dds",
    flat    = "AnimatedActionBarPlus/UltEdgeFlat.dds",
    sleek   = "AnimatedActionBarPlus/UltEdgeSleek.dds",
    chamfer = "AnimatedActionBarPlus/UltEdgeChamfer.dds",
    double  = "AnimatedActionBarPlus/UltEdgeDouble.dds",
}
-- leucht-kacheln für den voll-zustand.
local ULT_GLOW_TEX = {
    soft  = "AnimatedActionBarPlus/UltGlowSoft.dds",
    sharp = "AnimatedActionBarPlus/UltGlowSharp.dds",
    ring  = "AnimatedActionBarPlus/UltGlowRing.dds",
}

-- wandelt hsl in rgb um, brauchts für den rainbow modus.
-- hilfsfunktion außerhalb, sonst entsteht pro frame eine neue closure
local function Hue2RGB(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
end

local function HSLToRGB(h, s, l)
    if s == 0 then return l, l, l end
    local q = l < 0.5 and (l * (1 + s)) or (l + s - l * s)
    local p = 2 * l - q
    return Hue2RGB(p, q, h + 1/3), Hue2RGB(p, q, h), Hue2RGB(p, q, h - 1/3)
end

-- regenbogen läuft über die zeit, nicht über die anzahl der aufrufe.
-- so ist das tempo bei 30 wie bei 240 fps gleich und wir brauchen nicht
-- jeden frame ein update (früher 5ms = jeder frame)
local function RainbowHue()
    return (GetFrameTimeMilliseconds() * 0.0004) % 1
end

local function RainbowInterval()
    return sv.perfSlowRainbow and 33 or 16
end

local function CreateUltBorder()
    if ultBorderGlow then return ultBorderGlow end
    local btn = ZO_ActionBar_GetButton(ULT_SLOT_INDEX)
    if not btn or not btn.slot then return nil end
    local flip = GetFlipCard(btn) or btn.slot

    ultBorderGlow = WM:CreateControlFromVirtual(
        "AABPlus_UltReady", flip, "AABPlus_GlowTemplate"
    )
    return ultBorderGlow
end

HideUltBorder = function()
    ultIsReady = false
    if ultBorderTimeline then
        ultBorderTimeline:Stop()
        ultBorderTimeline = nil
    end
    if ultBorderBlinkId then
        EM:UnregisterForUpdate(ultBorderBlinkId)
        ultBorderBlinkId = nil
    end
    if ultBorderRainbowId then
        EM:UnregisterForUpdate(ultBorderRainbowId)
        ultBorderRainbowId = nil
    end
    if ultBorderGlow then ultBorderGlow:SetAlpha(0) end
end

-- eigene controller-fortschritts-border (4-kanten-rahmen)
local function EdgeTexFor(style)
    return ULT_EDGE_TEX[style or "flat"] or ULT_EDGE_TEX.flat
end

-- stabiler parent: der slot-container selbst, nicht die FlipCard. die FlipCard
-- wird beim bar-wechsel gedreht/skaliert - daran verankert würde die border mitwandern.
local function CtrlParent()
    local btn = ZO_ActionBar_GetButton(ULT_SLOT_INDEX)
    if not btn or not btn.slot then return nil end
    return btn.slot
end

-- legt ein kanten-control an (eine textur, wird später gestreckt/eingefärbt).
local function MakeEdge(name, parent, level)
    local t = WM:CreateControl(name, parent, CT_TEXTURE)
    t:SetDrawTier(DT_HIGH)
    t:SetDrawLevel(level)
    t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    t:SetHidden(true)
    return t
end

-- baut alle kanten einmalig auf: 4 track-kanten (hintergrund), 4 fill-kanten
-- (fortschritt), 4 glow-kanten (voll-zustand).
local function CreateCtrlBorder()
    if ultCtrl then return true end
    local parent = CtrlParent()
    if not parent then return false end

    -- segmente: L/R = senkrechte seitenbalken, corner TL/TR/BL/BR = kurze ecken-stege.
    -- zusammen ergeben sie die klammer-/bracket-form aus dem gamepad-UI.
    local SEGS = { "L", "R", "TL", "TR", "BL", "BR" }
    ultCtrl = { track = {}, fill = {}, glow = {}, segs = SEGS }
    for _, seg in ipairs(SEGS) do
        ultCtrl.track[seg] = MakeEdge("AABPlus_UltTrack" .. seg, parent, 3)
        ultCtrl.fill[seg]  = MakeEdge("AABPlus_UltFill"  .. seg, parent, 4)
        ultCtrl.glow[seg]  = MakeEdge("AABPlus_UltGlow"  .. seg, parent, 5)
        ultCtrl.glow[seg]:SetBlendMode(TEX_BLEND_MODE_ADD)
    end
    return true
end

-- setzt textur + farbe für einen segment-satz.
local function StyleEdges(set, tex, r, g, b, a)
    for _, c in pairs(set) do
        if type(c) ~= "table" then  -- segs-liste überspringen
            c:SetTexture(tex)
            c:SetColor(r, g, b, a)
        end
    end
end

-- länge der ecken-stege (horizontaler teil der klammer). auf ganze pixel gerundet,
-- damit die kanten gestochen scharf sind und nicht subpixel-verwaschen.
local function CornerLen(w)
    local frac = sv.ultCtrlCornerFrac or 0.30
    return zo_round(math.max(6, w * frac))
end

-- verankert einen kompletten klammer-satz (voll sichtbar). für track/glow genutzt.
-- ecken-stege starten nach der balkenbreite (offset th), damit sie sich nicht mit den
-- seitenbalken überlappen -> keine doppelt gedeckten, helleren ecken.
local function LayoutBracket(set, parent, pad, th, extra)
    extra = extra or 0
    local p = zo_round(pad + extra)
    local t = math.max(1, zo_round(math.abs(th) + extra * 2))
    local w = parent:GetWidth() + p * 2
    local cl = CornerLen(w)

    -- senkrechte seitenbalken (volle höhe)
    set.L:ClearAnchors()
    set.L:SetAnchor(TOPLEFT,    parent, TOPLEFT,    -p, -p)
    set.L:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, -p,  p)
    set.L:SetWidth(t)
    set.R:ClearAnchors()
    set.R:SetAnchor(TOPRIGHT,    parent, TOPRIGHT,    p, -p)
    set.R:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, p,  p)
    set.R:SetWidth(t)

    -- ecken-stege oben (starten neben dem balken, damit keine überlappung)
    set.TL:ClearAnchors()
    set.TL:SetAnchor(TOPLEFT, parent, TOPLEFT, -p + t, -p)
    set.TL:SetDimensions(cl, t)
    set.TR:ClearAnchors()
    set.TR:SetAnchor(TOPRIGHT, parent, TOPRIGHT, p - t, -p)
    set.TR:SetDimensions(cl, t)
    -- ecken-stege unten
    set.BL:ClearAnchors()
    set.BL:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, -p + t, p)
    set.BL:SetDimensions(cl, t)
    set.BR:ClearAnchors()
    set.BR:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, p - t, p)
    set.BR:SetDimensions(cl, t)
end

-- verankert track + glow als volle klammer. fill kommt separat nach fortschritt.
local function AnchorCtrlBorder()
    local parent = CtrlParent()
    if not parent or not ultCtrl then return end
    local pad = tonumber(sv.ultCtrlPadding) or 3
    local th  = math.max(1, math.abs(tonumber(sv.ultCtrlThickness) or 3))

    for _, seg in ipairs(ultCtrl.segs) do
        for _, setname in ipairs({ "track", "fill", "glow" }) do
            local c = ultCtrl[setname][seg]
            if c:GetParent() ~= parent then c:SetParent(parent) end
        end
    end
    LayoutBracket(ultCtrl.track, parent, pad, th, 0)
    LayoutBracket(ultCtrl.glow,  parent, pad, th, (sv.ultCtrlGlowSpread or 4) * 0.5)
end

-- fortschritt 0..1: klammer füllt sich von unten nach oben.
-- reihenfolge: untere ecken-stege -> seitenbalken steigen hoch -> obere ecken-stege.
local function SetCtrlBorderProgress(pct)
    if not ultCtrl then return end
    pct = pct or 0
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end

    local parent = CtrlParent()
    if not parent then return end
    local w = parent:GetWidth(); local h = parent:GetHeight()
    if w <= 0 or h <= 0 then return end

    local pad = tonumber(sv.ultCtrlPadding) or 3
    local th  = math.abs(tonumber(sv.ultCtrlThickness) or 3)
    local p   = zo_round(pad)
    local t   = math.max(1, zo_round(th))
    local fullH = h + p * 2
    local cl  = CornerLen(w + p * 2)

    -- farbe (mit optionalem ladeverlauf)
    local c         = sv.ultReadyColor or { 1, 0.2, 0, 1 }
    local intensity = sv.ultReadyIntensity or 1.0
    local a         = Alpha01((c[4] or 1) * intensity)
    local r, g, b   = c[1], c[2], c[3]
    if sv.ultCtrlColorShift then
        local cl2 = sv.ultCtrlChargingColor or { 0.55, 0.55, 0.6, 1 }
        r = cl2[1] + (c[1]-cl2[1])*pct
        g = cl2[2] + (c[2]-cl2[2])*pct
        b = cl2[3] + (c[3]-cl2[3])*pct
    end

    local tex = EdgeTexFor(sv.ultCtrlStyle)
    local F = ultCtrl.fill
    StyleEdges(F, tex, r, g, b, a)

    -- untere ecken-stege: ab pct > 0 (starten neben dem balken, keine überlappung)
    local bottomShown = pct > 0.02
    F.BL:ClearAnchors(); F.BL:SetAnchor(BOTTOMLEFT,  parent, BOTTOMLEFT,  -p + t, p)
    F.BL:SetDimensions(cl, t); F.BL:SetHidden(not bottomShown)
    F.BR:ClearAnchors(); F.BR:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT,  p - t, p)
    F.BR:SetDimensions(cl, t); F.BR:SetHidden(not bottomShown)

    -- seitenbalken: von unten hochwachsen (höhe auf ganze pixel gerundet)
    local sideFill = zo_round(math.min(fullH, fullH * pct))
    F.L:ClearAnchors(); F.L:SetAnchor(BOTTOMLEFT,  parent, BOTTOMLEFT,  -p, p)
    F.L:SetWidth(t); F.L:SetHeight(sideFill); F.L:SetHidden(sideFill <= 1)
    F.R:ClearAnchors(); F.R:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT,  p, p)
    F.R:SetWidth(t); F.R:SetHeight(sideFill); F.R:SetHidden(sideFill <= 1)

    -- obere ecken-stege: erst wenn fast voll (letzte ~10%)
    local topShown = pct >= 0.90
    F.TL:ClearAnchors(); F.TL:SetAnchor(TOPLEFT,  parent, TOPLEFT,  -p + t, -p)
    F.TL:SetDimensions(cl, t); F.TL:SetHidden(not topShown)
    F.TR:ClearAnchors(); F.TR:SetAnchor(TOPRIGHT, parent, TOPRIGHT,  p - t, -p)
    F.TR:SetDimensions(cl, t); F.TR:SetHidden(not topShown)

    -- voll-glow über die ganze klammer
    local isFull = pct >= 1.0
    local showGlow = isFull and sv.ultCtrlGlowOnFull
    local gtex = ULT_GLOW_TEX[sv.ultCtrlGlowStyle or "soft"] or ULT_GLOW_TEX.soft
    local gi   = Alpha01(sv.ultCtrlGlowIntensity or 0.8)
    for _, seg in ipairs(ultCtrl.segs) do
        local gc = ultCtrl.glow[seg]
        gc:SetTexture(gtex)
        gc:SetColor(r, g, b, gi)
        gc:SetHidden(not showGlow)
    end
    if isFull and not ultCtrlWasFull and showGlow then
        if not ultCtrlGlowTL then
            ultCtrlGlowTL = ANIMATION_MANAGER:CreateTimeline()
            for _, seg in ipairs(ultCtrl.segs) do
                local pa = ultCtrlGlowTL:InsertAnimation(ANIMATION_ALPHA, ultCtrl.glow[seg])
                pa:SetEasingFunction(ZO_EaseOutQuadratic)
                pa:SetAlphaValues(1.0, gi)
                pa:SetDuration(SafeMS(sv.ultCtrlPulseMS, 450))
            end
        end
        ultCtrlGlowTL:PlayFromStart()
    end

    -- regenbogen bei voller ulti: eigener hue-cycler übernimmt die einfärbung der
    -- fill- (und ggf. glow-)klammer. läuft nur im voll-zustand, sonst aus.
    if isFull and sv.ultCtrlRainbow then
        if not ultCtrlRainbowId and ultCtrl then
            local id  = "AABPlusUltCtrlRainbow"
            local sat = Clamp(sv.ultRainbowSaturation or 1.0, 0, 1)
            local lit = Clamp(sv.ultRainbowLightness or 0.5, 0, 1)
            EM:RegisterForUpdate(id, RainbowInterval(), function()
                if not ultCtrl then return end
                local rr, gg, bb = HSLToRGB(RainbowHue(), sat, lit)
                local ftex = EdgeTexFor(sv.ultCtrlStyle)
                StyleEdges(ultCtrl.fill, ftex, rr, gg, bb, a)
                if sv.ultCtrlGlowOnFull then
                    for _, seg in ipairs(ultCtrl.segs) do
                        ultCtrl.glow[seg]:SetColor(rr, gg, bb, gi)
                    end
                end
            end)
            ultCtrlRainbowId = id
        end
    elseif ultCtrlRainbowId then
        EM:UnregisterForUpdate(ultCtrlRainbowId)
        ultCtrlRainbowId = nil
    end

    ultCtrlWasFull = isFull
end


local function GetUltPct()
    local cost = GetUltCost()
    if cost <= 0 then return 0 end
    return GetUnitPower("player", POWERTYPE_ULTIMATE) / cost
end

-- gamepad-ulti-rahmen, eigene kopie damit er überall geht und färbbar ist
local GpUlt = {
    EDGE   = "EsoUI/Art/HUD/Gamepad/gp_UltimateFrame_edge.dds",
    FILL   = "EsoUI/Art/HUD/Gamepad/gp_UltimateFill_512.dds",
    FLIP   = 67,
    COLS   = 8,
    ROWS   = 4,
    hue    = 0,
}

function GpUlt.Create()
    if GpUlt.ctrl then return GpUlt.ctrl end
    local btn = ZO_ActionBar_GetButton(ULT_SLOT_INDEX)
    if not btn or not btn.slot then return nil end
    local parent = btn.slot

    local frame = WM:CreateControl("AABPlus_GpUltFrame", parent, CT_BACKDROP)
    frame:SetCenterColor(0, 0, 0, 0)
    frame:SetDrawLevel(1)
    frame:SetHidden(true)

    local left = WM:CreateControl("AABPlus_GpUltFillLeft", parent, CT_TEXTURE)
    local right = WM:CreateControl("AABPlus_GpUltFillRight", parent, CT_TEXTURE)
    for _, t in ipairs({ left, right }) do
        t:SetTexture(GpUlt.FILL)
        t:SetDrawLevel(3)
        t:SetHidden(true)
    end

    GpUlt.ctrl = { frame = frame, left = left, right = right }
    return GpUlt.ctrl
end

function GpUlt.Cell(tex, pct, mirror)
    local cols, rows = GpUlt.COLS, GpUlt.ROWS
    local i = zo_clamp(zo_floor(pct * (cols * rows - 1) + 0.5), 0, cols * rows - 1)
    local col = i % cols
    local row = zo_floor(i / cols)
    local l, r = col / cols, (col + 1) / cols
    if mirror then l, r = r, l end
    tex:SetTextureCoords(l, r, row / rows, (row + 1) / rows)
end

function GpUlt.Layout()
    local c = GpUlt.ctrl
    if not c then return end
    local btn = ZO_ActionBar_GetButton(ULT_SLOT_INDEX)
    if not btn or not btn.slot then return end
    local flip = GetFlipCard(btn) or btn.slot
    local w = flip:GetWidth()
    local k = (w and w > 0) and (w / GpUlt.FLIP) or (47 / GpUlt.FLIP)
    local inset, offY, fillW = zo_floor(12 * k), zo_floor(36 * k), zo_floor(70 * k)
    local edge = math.max(8, zo_round(16 * k))

    if c.frame:GetParent() ~= btn.slot then c.frame:SetParent(btn.slot) end
    c.frame:SetEdgeTexture(GpUlt.EDGE, 128, 16, edge, 0)
    c.frame:SetInsets(edge, edge, -edge, -edge)
    c.frame:ClearAnchors()
    c.frame:SetAnchor(TOPLEFT, flip, TOPLEFT, -inset, -inset)
    c.frame:SetAnchor(BOTTOMRIGHT, flip, BOTTOMRIGHT, inset, inset)

    for _, entry in ipairs({ { c.left, zo_floor(-37 * k) }, { c.right, zo_floor(33 * k) } }) do
        local fill, offX = entry[1], entry[2]
        if fill:GetParent() ~= btn.slot then fill:SetParent(btn.slot) end
        fill:ClearAnchors()
        fill:SetWidth(fillW)
        fill:SetAnchor(TOPLEFT, flip, TOPLEFT, offX, -offY)
        fill:SetAnchor(BOTTOMLEFT, flip, BOTTOMLEFT, offX, offY)
    end
end

function GpUlt.Hide()
    GpUlt.SetFast(false)
    local c = GpUlt.ctrl
    if not c then return end
    c.frame:SetHidden(true)
    c.left:SetHidden(true)
    c.right:SetHidden(true)
end

function GpUlt.Paint()
    local c = GpUlt.ctrl
    if not c then return end
    local used = IsSlotUsed(ULT_SLOT_INDEX, GetActiveHotbarCategory())
    if not sv.ultGpFrameEnabled or not used then GpUlt.Hide(); return end

    local pct  = zo_clamp(GetUltPct(), 0, 1)
    local full = pct >= 1
    local fc, lc = sv.ultGpFrameColor, sv.ultGpFillColor
    local fr, fg, fb = fc[1], fc[2], fc[3]
    local lr, lg, lb = lc[1], lc[2], lc[3]
    if full and sv.ultGpRainbow then
        local r, g, b = HSLToRGB(RainbowHue(), Clamp(sv.ultRainbowSaturation or 1, 0, 1), Clamp(sv.ultRainbowLightness or 0.5, 0, 1))
        fr, fg, fb, lr, lg, lb = r, g, b, r, g, b
    elseif full and sv.ultGpFullColorEnabled then
        local fu = sv.ultGpFullColor
        fr, fg, fb, lr, lg, lb = fu[1], fu[2], fu[3], fu[1], fu[2], fu[3]
    end

    local fa, la = Alpha01(fc[4] or 1), Alpha01(lc[4] or 1)
    c.frame:SetEdgeColor(fr, fg, fb, fa)
    c.left:SetColor(lr, lg, lb, la)
    c.right:SetColor(lr, lg, lb, la)
    GpUlt.Cell(c.left, pct, false)
    GpUlt.Cell(c.right, pct, true)

    c.frame:SetHidden(false)
    c.left:SetHidden(false)
    c.right:SetHidden(false)
    GpUlt.SetFast(full and sv.ultGpRainbow)
end

-- füllstand kommt über EVENT_POWER_UPDATE, eine schnelle schleife
-- braucht es nur solange der regenbogen bei voller ulti läuft
function GpUlt.SetFast(on)
    on = on and true or false
    if GpUlt.fast == on then return end
    GpUlt.fast = on
    if on then
        EM:RegisterForUpdate("AABPlusGpUltRainbow", RainbowInterval(), GpUlt.Paint)
    else
        EM:UnregisterForUpdate("AABPlusGpUltRainbow")
    end
end

function GpUlt.Refresh()
    if GpUlt.update then
        EM:UnregisterForUpdate(GpUlt.update)
        GpUlt.update = nil
    end
    GpUlt.fast = nil
    GpUlt.SetFast(false)
    if not sv.ultGpFrameEnabled then GpUlt.Hide(); return end
    if not GpUlt.Create() then return end
    GpUlt.Layout()
    GpUlt.Paint()
    -- langsames sicherheitsnetz, falls sich die kosten ohne event ändern
    GpUlt.update = "AABPlusGpUlt"
    EM:RegisterForUpdate(GpUlt.update, 1000, GpUlt.Paint)
end

local function HideCtrlBorder()
    if ultCtrlUpdate then
        EM:UnregisterForUpdate(ultCtrlUpdate)
        ultCtrlUpdate = nil
    end
    if ultCtrlRainbowId then
        EM:UnregisterForUpdate(ultCtrlRainbowId)
        ultCtrlRainbowId = nil
    end
    if ultCtrl then
        for _, setname in ipairs({ "track", "fill", "glow" }) do
            for _, seg in ipairs(ultCtrl.segs) do
                ultCtrl[setname][seg]:SetHidden(true)
            end
        end
    end
    ultCtrlWasFull = false
end

local function ShowCtrlBorder()
    if sv.ultBorderStyle ~= "controller" then return end
    if not sv.ultReadyEnabled then HideCtrlBorder(); return end
    if not CreateCtrlBorder() then return end

    AnchorCtrlBorder()

    -- track-segmente (hintergrund-klammer) - dunkel, optional
    local tex = EdgeTexFor(sv.ultCtrlStyle)
    StyleEdges(ultCtrl.track, tex, 0.09, 0.09, 0.11, 0.9)
    for _, seg in ipairs(ultCtrl.segs) do
        ultCtrl.track[seg]:SetHidden(not sv.ultCtrlShowTrack)
    end

    SetCtrlBorderProgress(GetUltPct())

    if not ultCtrlUpdate then
        ultCtrlUpdate = "AABPlusUltCtrlFill"
        local lastPct = -1
        EM:RegisterForUpdate(ultCtrlUpdate, SafeInterval(sv.ultCtrlPollMS, 120), function()
            if sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled then
                HideCtrlBorder(); return
            end
            -- nur neu zeichnen wenn sich was getan hat, spart anker-arbeit
            local pct = GetUltPct()
            if pct ~= lastPct then
                lastPct = pct
                SetCtrlBorderProgress(pct)
            end
        end)
    end
end

local function ShowUltBorder()
    if not sv.ultReadyEnabled then return end
    -- im controller-modus zeigt der native rahmen den fortschritt, eigener glow bleibt aus
    if sv.ultBorderStyle == "controller" then return end
    local glow = CreateUltBorder()
    if not glow then return end

    local btn = ZO_ActionBar_GetButton(ULT_SLOT_INDEX)
    if not btn or not btn.slot then return end

    local flip = GetFlipCard(btn) or btn.slot

    if glow:GetParent() ~= flip then
        glow:SetParent(flip)
    end

    local padding = sv.ultReadyPadding
    if (sv.ultReadyMode or "smooth") == "smooth-rainbow" then
        padding = padding + 2  -- rainbow braucht bissl mehr platz
    end
    AnchorGlow(glow, flip, padding)

    local c         = sv.ultReadyColor
    local intensity = sv.ultReadyIntensity or 1.0
    local maxA      = Alpha01((c[4] or 1) * intensity)
    glow:SetColor(c[1], c[2], c[3], maxA)
    glow:SetAlpha(maxA)

    if ultBorderTimeline then ultBorderTimeline:Stop(); ultBorderTimeline = nil end
    if ultBorderBlinkId then EM:UnregisterForUpdate(ultBorderBlinkId); ultBorderBlinkId = nil end
    if ultBorderRainbowId then EM:UnregisterForUpdate(ultBorderRainbowId); ultBorderRainbowId = nil end

    if sv.ultReadyPulse then
        local minA = Alpha01(sv.ultReadyMinAlpha or 0.35)
        local mode = sv.ultReadyMode or "smooth"

        if mode == "blink" then
            -- hartes an/aus statt sanftem fade.
            local interval = SafeInterval(sv.ultReadyBlinkIntMS, 250)
            local id       = "AABPlusUltBlink"
            local state    = true
            local c2       = sv.ultColorCycleSecondary
            local cycleColor = sv.ultColorCycleEnabled
            glow:SetColor(c[1], c[2], c[3], maxA)
            glow:SetAlpha(maxA)
            EM:RegisterForUpdate(id, interval, function()
                state = not state
                if cycleColor then
                    -- statt an/aus zwischen primär- und sekundärfarbe wechseln (beide voll sichtbar).
                    glow:SetAlpha(maxA)
                    if state then
                        glow:SetColor(c[1], c[2], c[3], maxA)
                    else
                        local a2 = Alpha01((c2[4] or 1) * intensity)
                        glow:SetColor(c2[1], c2[2], c2[3], a2)
                    end
                else
                    glow:SetColor(c[1], c[2], c[3], maxA)
                    glow:SetAlpha(state and maxA or minA)
                end
            end)
            ultBorderBlinkId = id
        elseif mode == "smooth-rainbow" then
            -- sanfter farbverlauf der automatisch durch den regenbogen wandert
            local id = "AABPlusUltRainbow"
            local saturation = Clamp(sv.ultRainbowSaturation or 1.0, 0, 1)
            local lightness = Clamp(sv.ultRainbowLightness or 0.5, 0, 1)
            glow:SetAlpha(maxA)
            EM:RegisterForUpdate(id, RainbowInterval(), function()
                local r, g, b = HSLToRGB(RainbowHue(), saturation, lightness)
                glow:SetColor(r, g, b, maxA)
            end)
            ultBorderRainbowId = id
        else
            local dur  = SafeMS(sv.ultReadyPulseDurMS, 900)
            local tl = ANIMATION_MANAGER:CreateTimeline()
            local a  = tl:InsertAnimation(ANIMATION_ALPHA, glow)
            a:SetAlphaValues(maxA, minA)
            a:SetDuration(dur)
            a:SetEasingFunction(ZO_EaseOutQuadratic)
            tl:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
            tl:PlayFromStart()
            ultBorderTimeline = tl
        end
    end
end

PauseUltBorderPulse = function(durationMS)
    if not ultBorderGlow or not ultIsReady then return end

    if ultBorderTimeline then
        ultBorderTimeline:Stop()
        ultBorderTimeline = nil
    end
    if ultBorderBlinkId then
        EM:UnregisterForUpdate(ultBorderBlinkId)
        ultBorderBlinkId = nil
    end
    if ultBorderRainbowId then
        EM:UnregisterForUpdate(ultBorderRainbowId)
        ultBorderRainbowId = nil
    end

    local c         = sv.ultReadyColor
    local intensity = sv.ultReadyIntensity or 1.0
    local maxA      = Alpha01((c[4] or 1) * intensity)
    ultBorderGlow:SetColor(c[1], c[2], c[3], maxA)
    ultBorderGlow:SetAlpha(maxA)

    zo_callLater(function()

        if ultIsReady and sv.ultReadyEnabled and sv.ultReadyPulse then
            ShowUltBorder()
        end
    end, durationMS or 600)
end

CheckUltimateReady = function()
    if not sv.ultReadyEnabled then HideUltBorder(); return end

    local ultAbilityId = GetSlotBoundId(ULT_SLOT_INDEX)
    if not ultAbilityId or ultAbilityId == 0 then
        HideUltBorder()
        return
    end

    local currentUlt = GetUnitPower("player", POWERTYPE_ULTIMATE)
    local cost = GetUltCost()

    local ready = currentUlt >= cost and cost > 0

    if ready and not ultIsReady then
        ultIsReady = true
        ShowUltBorder()
    elseif not ready and ultIsReady then
        HideUltBorder()
    end
end

local function OnPowerUpdate(_, unitTag, powerIndex, powerType)
    if unitTag ~= "player" or powerType ~= POWERTYPE_ULTIMATE then return end
    SuppressVanillaUltGlow()
    if sv.ultGpFrameEnabled then GpUlt.Paint() end
    if sv.ultBorderStyle == "controller" then
        -- läuft die border schon, nur den fortschritt setzen (billig, kein re-setup).
        if ultCtrl and ultCtrlUpdate then
            SetCtrlBorderProgress(GetUltPct())
        else
            ShowCtrlBorder()
        end
        return
    end
    CheckUltimateReady()
end

local function OnSlotsUpdated()
    HideUltBorder()
    SuppressVanillaUltGlow()
    if sv.ultGpFrameEnabled then
        GpUlt.Layout()
        GpUlt.Paint()
    end
    if sv.ultBorderStyle == "controller" then
        -- border nicht verstecken/neu erstellen (das zuckt beim bounce/bar-wechsel).
        -- nur neu verankern + einmal den fortschritt setzen, der poll-timer läuft weiter.
        if ultCtrl then
            AnchorCtrlBorder()
            SetCtrlBorderProgress(GetUltPct())
        else
            ShowCtrlBorder()  -- erstes mal: aufbauen
        end
        -- nachzieher, falls ZOS den slot verzögert neu vermisst (nur reanchoring, kein flackern)
        zo_callLater(function()
            if sv.ultBorderStyle == "controller" and ultCtrl then
                AnchorCtrlBorder()
                SetCtrlBorderProgress(GetUltPct())
            end
        end, 60)
        if sv.perfSlotLookupMap and RebuildSlotLookup then RebuildSlotLookup() end
        if sv.perfEffectIdFilter and RefreshEffectRegistration then RefreshEffectRegistration() end
        StopAllPulses()
        zo_callLater(function() RefreshAllProcs() end, 50)
        return
    end
    CheckUltimateReady()

    -- lookup-map und id-filter an die neuen slots anpassen (falls aktiv)
    if sv.perfSlotLookupMap and RebuildSlotLookup then RebuildSlotLookup() end
    if sv.perfEffectIdFilter and RefreshEffectRegistration then RefreshEffectRegistration() end

    StopAllPulses()
    zo_callLater(function() RefreshAllProcs() end, 50)
end

local function ApplyEdgeTexture()
    local template = GetEdgeTemplate()
    local cats = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }
    for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ULT_SLOT_INDEX do
        for _, cat in ipairs(cats) do
            local btn = ZO_ActionBar_GetButton(slotNum, cat)
            if btn and btn.slot then
                ApplyTemplateToControl(btn.slot, template)
                SetSlotEdge(btn.slot)
                if btn.ApplyStyle then btn:ApplyStyle() end
            end
        end
    end
end

local function ApplyFrameAlpha()
    local alpha = Alpha01(sv.frameAlpha or 1.0)
    for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ULT_SLOT_INDEX do
        local btn = ZO_ActionBar_GetButton(slotNum)
        if btn and btn.slot then
            local backdrop = btn.slot:GetNamedChild("Backdrop")
            if backdrop then backdrop:SetAlpha(alpha) end
        end
    end
end

-- expire animation

-- key = hotbar * 100 + slotNum, damit derselbe slot auf front- und backbar
-- getrennte timer haben kann
local expireTrack = {}
local expireGen   = 0

-- /aab track: zeigt im chat schedule/resync/fire. pcall damit ein
-- format-fehler nie den event-handler mitreißt
local expireTrace = false
local function ETrace(fmt, ...)
    if not expireTrace then return end
    local ok, msg = pcall(string.format, fmt, ...)
    d("|c9a7fd6[AAB+ trace]|r " .. (ok and msg or tostring(fmt)))
end
local function ToggleExpireTrace()
    expireTrace = not expireTrace
    d("|ca970ff[AAB+]|r " .. GetString(expireTrace and SI_AAB_TRACE_ON or SI_AAB_TRACE_OFF))
end

local function ExpireKey(hotbar, slotNum)
    return hotbar * 100 + slotNum
end

local function ResolveExpireStyle()
    local s = sv.expireAnimStyle or "inherit"
    if s == "inherit" then
        return sv.animationStyle or "bounce"
    end
    return s
end

-- gender-suffixe (^f etc.) rauswerfen, sonst matcht der name nie
local function CleanAbilityName(n)
    if not n or n == "" then return "" end
    return zo_strformat("<<1>>", n)
end

local function OtherHotbar(cat)
    return (cat == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
end

-- sucht auf einer bar den slot dessen skill zum effekt passt.
-- erst per ability-id, dann per name als fallback
-- (buff-id und skill-id sind bei eso oft nicht identisch)

-- lookup-map, damit wir nicht bei jedem effekt-event alle slots durchlaufen.
-- id -> {slot, hotbar}, name -> {slot, hotbar}
local slotById   = {}
local slotByName = {}

RebuildSlotLookup = function()
    slotById   = {}
    slotByName = {}
    for _, hotbar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX do
            local slotId = GetSlotBoundId(slotNum, hotbar)
            if slotId and slotId > 0 then
                -- aktive bar zuerst -> gewinnt bei doppelt geslotteten skills
                if not slotById[slotId] then
                    slotById[slotId] = { slot = slotNum, hotbar = hotbar }
                end
                local nm = CleanAbilityName(GetAbilityName(slotId))
                if nm ~= "" and not slotByName[nm] then
                    slotByName[nm] = { slot = slotNum, hotbar = hotbar }
                end
            end
        end
    end
end

local function FindSlotOnBar(abilityId, effectName, hotbar)
    local wantName = CleanAbilityName(effectName)
    local nameMatch = nil
    for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX do
        local slotId = GetSlotBoundId(slotNum, hotbar)
        if slotId and slotId > 0 then
            if slotId == abilityId then return slotNum end
            if not nameMatch and wantName ~= ""
                and CleanAbilityName(GetAbilityName(slotId)) == wantName then
                nameMatch = slotNum
            end
        end
    end
    return nameMatch
end

-- sucht über beide bars, aktive zuerst. gibt slotNum + hotbar zurück
local function FindSlotForAbility(abilityId, effectName)
    if sv.perfSlotLookupMap then
        local hit = slotById[abilityId]
        if hit then return hit.slot, hit.hotbar end
        local nm = CleanAbilityName(effectName)
        hit = nm ~= "" and slotByName[nm] or nil
        if hit then return hit.slot, hit.hotbar end
        return nil, nil
    end

    local active = GetActiveHotbarCategory()
    local slot = FindSlotOnBar(abilityId, effectName, active)
    if slot then return slot, active end
    local other = OtherHotbar(active)
    slot = FindSlotOnBar(abilityId, effectName, other)
    if slot then return slot, other end
    return nil, nil
end

-- kurzer glow in eigener farbe wenn der effekt ausläuft. eigene controls pro
-- bar+slot, damit front- und backbar parallel leuchten können
local expireGlows     = {}
local expireGlowFades = {}

local function PlayExpireGlow(slotNum, hotbar)
    if not sv.expireGlowEnabled then return end
    local btn = ResolveSlotButton(slotNum, hotbar)
    if not btn then return end
    local flip = GetFlipCard(btn)
    if not flip then return end

    local key  = ExpireKey(hotbar, slotNum)
    local glow = expireGlows[key]
    if not glow then
        glow = WM:CreateControlFromVirtual("AABPlus_ExpireGlow" .. key, flip, "AABPlus_GlowTemplate")
        expireGlows[key] = glow
    elseif glow:GetParent() ~= flip then
        glow:SetParent(flip)
    end

    AnchorGlow(glow, flip, sv.glowPadding or 12)
    local c    = sv.expireGlowColor
    local maxA = Alpha01(c[4] or 1)
    glow:SetColor(c[1], c[2], c[3], maxA)
    glow:SetAlpha(maxA)

    local fade = expireGlowFades[key]
    if not fade then
        fade = ANIMATION_MANAGER:CreateTimeline()
        fade:InsertAnimation(ANIMATION_ALPHA, glow)
        expireGlowFades[key] = fade
    end
    local a = fade:GetAnimation(1)
    a:SetAnimatedControl(glow)
    a:SetAlphaValues(maxA, 0)
    a:SetDuration(SafeMS(sv.glowDurationMS, 600))
    a:SetEasingFunction(ZO_EaseInQuadratic)
    fade:PlayFromStart()
end

-- faktor für die länge der end-anim (nicht den zeitpunkt). kurze buffs blitzen
-- knapp, lange laufen gedehnter. nur aktiv bei globaler dauer-koppelung
local function ResolveExpireScale(abilityId, durMS)
    if not sv.expireScaleByDuration then return 1.0 end
    if not durMS or durMS <= 0 then return 1.0 end

    local ref   = math.abs(tonumber(sv.expireScaleRefMS) or 10000)
    if ref < 1 then ref = 1 end
    local scale = durMS / ref
    local lo    = tonumber(sv.expireScaleMin) or 0.6
    local hi    = tonumber(sv.expireScaleMax) or 1.8
    if lo > hi then lo, hi = hi, lo end
    return Clamp(math.max(lo, math.min(hi, scale)), 0.05, 10)
end

local function FireExpireAnim(key, gen)
    local rec = expireTrack[key]
    -- inzwischen neu gecastet/resynct? dann ist der alte timer wertlos
    if not rec or rec.gen ~= gen then
        ETrace("fire ignored (stale) key=%d", key)
        return
    end
    expireTrack[key] = nil

    if not sv.expireAnimEnabled then return end
    -- slot neu auflösen, nach bar-swap sitzt der skill evtl woanders
    local target, cat = rec.slotNum, rec.hotbar
    if GetSlotBoundId(rec.slotNum, rec.hotbar) ~= rec.abilityId then
        target, cat = FindSlotForAbility(rec.abilityId, rec.name)
    end
    if not target then return end
    ETrace("FEUER %s (id %d) slot=%d", zo_strformat("<<1>>", rec.name), rec.abilityId, target)
    local scale = ResolveExpireScale(rec.abilityId, rec.durMS)
    PlaySlotAnimation(target, ResolveExpireStyle(), cat, "expire", scale)
    PlayExpireGlow(target, cat or GetActiveHotbarCategory())
end

-- dauer robust auflösen: ohne "player" als caster-tag liefern scribing-skills
-- (grimoires wie donnernde rune) und manche morphs schlicht 0
local function ResolveAbilityDurationMS(abilityId)
    local dur = GetAbilityDuration(abilityId, nil, "player") or 0
    if dur <= 0 then
        dur = GetAbilityDuration(abilityId) or 0
    end
    return dur
end

-- isOverride = manuell gesetzt (/aab setend), buff-resync fasst das nicht an
local function ScheduleExpire(slotNum, hotbar, abilityId, durMS, isOverride)
    expireGen = expireGen + 1
    local gen = expireGen
    local key = ExpireKey(hotbar, slotNum)
    expireTrack[key] = {
        gen        = gen,
        abilityId  = abilityId,
        name       = GetAbilityName(abilityId),
        slotNum    = slotNum,
        hotbar     = hotbar,
        durMS      = durMS,
        fireAt     = GetGameTimeMilliseconds() + durMS,
        isOverride = isOverride or false,
    }
    zo_callLater(function() FireExpireAnim(key, gen) end, durMS)
    ETrace("schedule id=%d slot=%d in %dms", abilityId, slotNum, durMS)
end

-- aus OnAbilitySlotted (EVENT_ACTION_SLOT_ABILITY_USED)
TrackExpireOnCast = function(slotNum)
    if not sv.expireAnimEnabled then return end
    if slotNum < ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
        or slotNum > ACTION_BAR_ULTIMATE_SLOT_INDEX then return end

    local hotbar    = GetActiveHotbarCategory()
    local abilityId = GetSlotBoundId(slotNum, hotbar)
    if not abilityId or abilityId == 0 then return end

    -- override hat vorrang und schedulet immer, auch wenn die engine 0 meldet
    local ov = sv.expireDurationOverride[tostring(abilityId)]
    if ov and ov > 0 then
        ScheduleExpire(slotNum, hotbar, abilityId, ov, true)
        return
    end

    -- nur basisschätzung, der echte endzeitpunkt kommt gleich per effect_changed
    local durMS = ResolveAbilityDurationMS(abilityId)
    if durMS <= 0 then return end

    -- cast-zeit drauf, der effekt startet ja erst nach dem cast
    local _, castTimeMS = GetAbilityCastInfo(abilityId, nil, "player")
    if castTimeMS and castTimeMS > 0 then
        durMS = durMS + castTimeMS
    end

    ScheduleExpire(slotNum, hotbar, abilityId, durMS)
end

-- EVENT_EFFECT_CHANGED args: eventCode, changeType, effectSlot, effectName,
-- unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType,
-- abilityType, statusEffectType, unitName, unitId, abilityId, sourceType
local function OnEffectChanged(_, changeType, _, effectName, unitTag, beginTime, endTime,
                               _, _, _, _, _, _, _, _, abilityId)
    if not sv.expireAnimEnabled then return end
    if unitTag ~= "player" or not abilityId then return end

    local slotNum, hotbar = FindSlotForAbility(abilityId, effectName)
    if not slotNum then return end
    local key = ExpireKey(hotbar, slotNum)
    local rec = expireTrack[key]

    -- bei manuellem override macht der buff am timing nichts, nur FADED unten
    local hasOverride = (sv.expireDurationOverride[tostring(abilityId)] or 0) > 0
                        or (rec and rec.isOverride) or false

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        if hasOverride then return end
        -- manche skills haben mehrere gleichnamige effekte (blue betty z.b. einen
        -- ~5s tick). wir nehmen nur den längsten und feuern einmal - alles was
        -- den geplanten zeitpunkt verkürzen würde, ignorieren
        if beginTime and endTime and endTime > beginTime then
            local nowMS     = GetGameTimeMilliseconds()
            local remainMS  = (endTime * 1000) - nowMS
            if remainMS > 0 then
                local newFireAt = nowMS + remainMS

                -- kürzere ticks raus (250ms toleranz gegen refresh-jitter)
                if rec and rec.fireAt then
                    if newFireAt <= rec.fireAt + 250 then
                        return
                    end
                end

                expireGen = expireGen + 1
                local gen = expireGen
                if not rec then
                    rec = {
                        abilityId = abilityId,
                        name      = GetAbilityName(abilityId),
                        slotNum   = slotNum,
                        hotbar    = hotbar,
                    }
                    expireTrack[key] = rec
                end
                rec.gen    = gen
                rec.durMS  = remainMS
                rec.fireAt = newFireAt
                zo_callLater(function() FireExpireAnim(key, gen) end, remainMS)
                ETrace("resync id=%d slot=%d -> remaining %dms", abilityId, slotNum, math.floor(remainMS))
            end
        end
    elseif changeType == EFFECT_RESULT_FADED then
        -- purge/frühes ende: nur feuern wenn's der verfolgte effekt ist,
        -- ein endender tick soll die anim nicht auslösen
        if rec and (not rec.fireAt or GetGameTimeMilliseconds() >= rec.fireAt - 250) then
            FireExpireAnim(key, rec.gen)
        end
    end
end

local function ClearTrackedEffects()
    for k in pairs(expireTrack) do expireTrack[k] = nil end
end

-- events

-- default: eine breite registrierung auf unitTag "player", feuert also bei
-- jedem effekt auf dir. mit perfEffectIdFilter stattdessen pro geslotteter id
-- eine eigene registrierung, feuert dann nur noch für unsere skills.
local effectFilterIds = {}

local function UnregisterEffectFilters()
    EM:UnregisterForEvent(ADDON_NAME .. "Expire", EVENT_EFFECT_CHANGED)
    for _, id in ipairs(effectFilterIds) do
        EM:UnregisterForEvent(ADDON_NAME .. "ExpireId" .. id, EVENT_EFFECT_CHANGED)
    end
    effectFilterIds = {}
end

local function RegisterEffectBroad()
    EM:RegisterForEvent(ADDON_NAME .. "Expire", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(ADDON_NAME .. "Expire", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")
end

local function RegisterEffectByIds()
    local seen = {}
    for _, hotbar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX do
            local id = GetSlotBoundId(slotNum, hotbar)
            if id and id > 0 and not seen[id] then
                seen[id] = true
                local ns = ADDON_NAME .. "ExpireId" .. id
                EM:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnEffectChanged)
                EM:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED,
                    REGISTER_FILTER_UNIT_TAG,   "player",
                    REGISTER_FILTER_ABILITY_ID, id)
                effectFilterIds[#effectFilterIds + 1] = id
            end
        end
    end
end

RefreshEffectRegistration = function()
    UnregisterEffectFilters()
    if sv.perfEffectIdFilter then
        RegisterEffectByIds()
    else
        RegisterEffectBroad()
    end
end

local function OnCombatState(_, inCombatNow)
    inCombat = inCombatNow and true or false
end

local function RegisterEvents()
    EM:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOT_ABILITY_USED, OnAbilitySlotted)

    EM:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOT_EFFECT_UPDATE, OnActivationHighlightChanged)
    EM:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOT_UPDATED,        OnSingleSlotUpdated)
    EM:RegisterForEvent(ADDON_NAME, EVENT_ABILITY_LIST_CHANGED,      RefreshAllProcs)
    EM:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED,          RefreshAllProcs)

    EM:RegisterForEvent(ADDON_NAME, EVENT_ACTION_UPDATE_COOLDOWNS,   QS.OnCooldowns)
    if EVENT_ACTIVE_QUICKSLOT_CHANGED then
        EM:RegisterForEvent(ADDON_NAME .. "Quickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED, QS.Sync)
    end
    EM:RegisterForEvent(ADDON_NAME .. "Quickslot", EVENT_PLAYER_ACTIVATED, QS.Sync)

    EM:RegisterForEvent(ADDON_NAME, EVENT_POWER_UPDATE,              OnPowerUpdate)
    EM:AddFilterForEvent(ADDON_NAME, EVENT_POWER_UPDATE,
        REGISTER_FILTER_UNIT_TAG,    "player",
        REGISTER_FILTER_POWER_TYPE,  POWERTYPE_ULTIMATE)
    EM:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOTS_FULL_UPDATE,  OnSlotsUpdated)
    EM:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_HOTBAR_UPDATED,     OnSlotsUpdated)

    -- nach jedem laden/zonenwechsel baut ZOS die bar neu, dann die eigene border neu aufsetzen
    EM:RegisterForEvent(ADDON_NAME .. "UltFrame", EVENT_PLAYER_ACTIVATED, function()
        if sv.ultBorderStyle == "controller" then
            zo_callLater(ShowCtrlBorder, 200)
        end
    end)

    EM:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE,       OnCombatState)

    -- pc-leiste im controller-modus
    EM:RegisterForEvent(ADDON_NAME .. "KbLook", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        zo_callLater(KbLook.Refresh, 150)
        zo_callLater(GpUlt.Refresh, 300)
    end)
    EM:RegisterForEvent(ADDON_NAME .. "KbLook", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(KbLook.Refresh, 200)
        zo_callLater(GpUlt.Refresh, 350)
    end)
    EM:RegisterForEvent(ADDON_NAME .. "KbLook", EVENT_ACTIVE_HOTBAR_UPDATED, function() KbLook.Queue(650) end)
    EM:RegisterForEvent(ADDON_NAME .. "KbLook", EVENT_ACTION_SLOTS_FULL_UPDATE, function() KbLook.Queue(100) end)
    if EVENT_ACTIVE_COMPANION_STATE_CHANGED then
        EM:RegisterForEvent(ADDON_NAME .. "KbLook", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function() KbLook.Queue(100) end)
    end

    RefreshEffectRegistration()
    -- nach zonenwechsel alte einträge wegwerfen, sonst matcht irgendwann
    -- ein längst toter effekt
    EM:RegisterForEvent(ADDON_NAME .. "Expire", EVENT_PLAYER_ACTIVATED, ClearTrackedEffects)
end

-- dunkles farbschema (palette oben definiert): violett-basis, giftgrün-akzent
local C_TITLE   = "|c" .. AAB_COLORS.accent
local C_BOUNCE  = "|c" .. AAB_COLORS.accent
local C_GLOW    = "|c" .. AAB_COLORS.good
local C_PULSE   = "|c" .. AAB_COLORS.accent2
local C_ULT     = "|c" .. AAB_COLORS.bad
local C_FRAME   = "|c" .. AAB_COLORS.accent2
local C_DONATE  = "|c" .. AAB_COLORS.good
local C_RESET   = "|r"

-- empfänger + betreff für die spenden-mail
local DONATE_RECIPIENT = "@haze068"
local DONATE_SUBJECT   = "AnimatedActionBar+ Addon Donation"

-- macht das mail-fenster auf und packt empfänger + betreff direkt rein
local function OpenDonationMail()
    -- notnagel falls ComposeMail mal nicht da ist: felder von hand setzen
    local function FillFields()
        if ZO_MailSendToField then ZO_MailSendToField:SetText(DONATE_RECIPIENT) end
        if ZO_MailSendSubjectField then ZO_MailSendSubjectField:SetText(DONATE_SUBJECT) end
    end

    -- ComposeMail ist das was eso selbst beim "an spieler senden" nutzt,
    -- öffnet das sende-fenster und füllt empfänger + betreff sauber. body bleibt leer
    if ComposeMail then
        ComposeMail(DONATE_RECIPIENT, DONATE_SUBJECT, "")
    else
        -- uralt-clients ohne ComposeMail: szene aufmachen und felder selbst setzen
        if SCENE_MANAGER then
            if IsInGamepadPreferredMode() then
                SCENE_MANAGER:Show("mailManagerGamepad")
                if MAIL_MANAGER_GAMEPAD and MAIL_MANAGER_GAMEPAD.ShowSend then
                    MAIL_MANAGER_GAMEPAD:ShowSend()
                end
            else
                SCENE_MANAGER:Show("mailSend")
            end
        end
        -- eso leert die felder beim öffnen, also zweimal kurz danach nachsetzen
        zo_callLater(FillFields, 50)
        zo_callLater(FillFields, 200)
    end
end

-- einmaliger hinweis-dialog nach der installation. verweist auf den info-tab.
-- bewusst ein eigenes WM-fenster statt ZO_Dialogs: so können wir die
-- addon-farben und das logo genauso setzen wie im rest des addons
local INFO_DIALOG_NAME = ADDON_NAME .. "_InfoDialog"
local infoDialog

-- hex aus der palette in 0-1 rgb, damit die farben im dialog zu chat/ui passen
local function HexToRGB(hex)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b
end

-- baut das fenster genau einmal und hebt es in infoDialog auf
local function BuildInfoDialog()
    if infoDialog then return infoDialog end

    local ar, ag, ab = HexToRGB(AAB_COLORS.accent)   -- purpur, titel/rahmen
    local vr, vg, vb = HexToRGB(AAB_COLORS.value)     -- lavendel, fließtext

    -- feste breite, höhe rechnen wir unten aus der tatsächlichen texthöhe.
    -- so passt der dialog für jede sprache ohne dass text hinter den button läuft
    local W = 460
    local PAD        = 20   -- rand links/rechts
    local BODY_TOP   = 96   -- start des haupttexts unter der trennlinie
    local BTN_GAP    = 20   -- luft zwischen text und button
    local BTN_H      = 32
    local BTN_BOTTOM = 18   -- luft zwischen button und unterkante

    -- oberste ebene, damit der dialog über der restlichen UI liegt
    local win = WM:CreateTopLevelWindow(INFO_DIALOG_NAME)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)

    -- dunkler rahmen im addon-look statt des grauen vanilla-dialogs
    local bg = WM:CreateControlFromVirtual(INFO_DIALOG_NAME .. "_BG", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0.05, 0.04, 0.09, 0.96)
    bg:SetEdgeColor(ar, ag, ab, 0.9)

    -- titelzeile in akzentfarbe
    local title = WM:CreateControl(INFO_DIALOG_NAME .. "_Title", win, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetColor(ar, ag, ab, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 18)
    title:SetText(GetString(SI_AAB_DLG_TITLE))

    -- logo oben rechts, wie im installations-check
    local logo = WM:CreateControl(INFO_DIALOG_NAME .. "_Logo", win, CT_TEXTURE)
    logo:SetDimensions(56, 56)
    logo:SetAnchor(TOPRIGHT, win, TOPRIGHT, -18, 14)
    logo:SetTexture("AnimatedActionBarPlus/media/UI_Logo.dds")

    -- trennlinie unter titel/logo
    local sep = WM:CreateControl(INFO_DIALOG_NAME .. "_Sep", win, CT_TEXTURE)
    sep:SetDimensions(W - 2 * PAD, 2)
    sep:SetColor(ar, ag, ab, 0.5)
    sep:SetTexture("EsoUI/Art/Miscellaneous/textbox_divider.dds")
    sep:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 78)

    -- haupttext, links unter der trennlinie. feste breite, damit der umbruch
    -- und die gemessene höhe stimmen, nach der wir das fenster dimensionieren
    local body = WM:CreateControl(INFO_DIALOG_NAME .. "_Body", win, CT_LABEL)
    body:SetFont("ZoFontWinH4")
    body:SetColor(vr, vg, vb, 1)
    body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)
    body:SetDimensionConstraints(W - 2 * PAD, 0, W - 2 * PAD, 0)
    body:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, BODY_TOP)
    body:SetWrapMode(TEXT_WRAP_MODE_WORD_WRAP)
    body:SetText(GetString(SI_AAB_DLG_BODY))

    -- jetzt steht der umbrochene text fest -> fenster + button danach ausrichten.
    -- manche clients liefern die texthöhe erst nach einem layout-frame, daher
    -- ein sinnvoller mindestwert als notnagel
    local textH = body:GetTextHeight()
    if not textH or textH < 40 then textH = 220 end
    local H = BODY_TOP + textH + BTN_GAP + BTN_H + BTN_BOTTOM
    win:SetDimensions(W, H)

    -- bestätigen-button unter dem text (nicht am fensterrand), schließt
    -- den dialog und merkt sich das flag
    local btn = WM:CreateControlFromVirtual(INFO_DIALOG_NAME .. "_OK", win, "ZO_DefaultButton")
    btn:SetDimensions(160, BTN_H)
    btn:SetAnchor(TOP, body, BOTTOM, 0, BTN_GAP)
    btn:SetText(GetString(SI_AAB_DLG_OK))
    btn:SetHandler("OnClicked", function()
        win:SetHidden(true)
        if sv then sv.infoDialogShown = true end
    end)

    infoDialog = win
    return win
end

-- macht den dialog auf. force=true umgeht das gesehen-flag (für /aab dialog),
-- ohne force poppt er nur beim allerersten mal
local function ShowInfoDialog(force)
    if not force and sv.infoDialogShown then return end
    local win = BuildInfoDialog()
    win:SetHidden(false)
    win:BringWindowToTop()
end

-- listet die aktuell geslotteten ability-ids beider bars im chat auf,
-- inklusive erkannter dauer und gesetztem end-anim-override.
local function PrintSlottedIds()
    d("|ca970ff=== " .. ADDON_NAME .. " " .. GetString(SI_AAB_DBG_EXPIRE_HEAD) .. " ===|r")
    local active = GetActiveHotbarCategory()
    for _, hotbar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        local mark = (hotbar == active) and " |c6fd66f*|r" or ""
        d("|c8a7fa6" .. ((hotbar == HOTBAR_CATEGORY_PRIMARY) and "Bar 1" or "Bar 2") .. mark .. "|r")
        for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX do
            local id = GetSlotBoundId(slotNum, hotbar)
            if id and id > 0 then
                local durMS = ResolveAbilityDurationMS(id)
                local name  = zo_strformat("<<1>>", GetAbilityName(id))
                local track = expireTrack[ExpireKey(hotbar, slotNum)]
                local col   = durMS > 0 and "|c6fd66f" or "|cd64f4f"
                local ov    = sv.expireDurationOverride[tostring(id)]
                local ovTxt = ov and ("  |cd69a4f» " .. tostring(ov) .. "ms|r") or ""
                d(string.format("  |c8a7fa6[%d]|r %s  |c8a7fa6%s:|r %s%dms|r  |c8a7fa6id:|r %d%s%s",
                    slotNum, name, GetString(SI_AAB_DBG_DURATION), col, math.floor(durMS), id,
                    track and ("  |c6fd66f" .. GetString(SI_AAB_DBG_TRACKING) .. "|r") or "",
                    ovTxt))
            end
        end
    end
    d("|c8a7fa6" .. GetString(SI_AAB_ID_HINT) .. "|r")
end

-- setzt/löscht den feuer-zeitpunkt-override für eine ability.
-- <id> auto   -> zurück auf die vom spiel erkannte dauer
-- <id> 25000  -> end-animation feuert 25000ms (25s) nach dem cast
local function SetExpireOverride(idStr, valStr)
    local id = tonumber(idStr)
    if not id or id <= 0 then
        d("|cd64f4f[AAB+]|r " .. GetString(SI_AAB_SETEND_BADID))
        return
    end
    id = math.floor(id)
    local key = tostring(id)

    if valStr == "auto" or valStr == "reset" or valStr == "off" then
        sv.expireDurationOverride[key] = nil
        d(string.format("|c6fd66f[AAB+]|r " .. GetString(SI_AAB_SETEND_CLEARED), id))
        return
    end

    local ms = tonumber(valStr)
    if not ms or ms <= 0 then
        d("|cd64f4f[AAB+]|r " .. GetString(SI_AAB_SETEND_BADVAL))
        return
    end
    ms = math.floor(ms)
    sv.expireDurationOverride[key] = ms
    local name = zo_strformat("<<1>>", GetAbilityName(id))
    d(string.format("|c6fd66f[AAB+]|r " .. GetString(SI_AAB_SETEND_SET), name, id, ms))
end

-- kurzer befehls-überblick im chat
local function PrintCommandHelp()
    local h = "|ca970ff"; local k = "|ca970ff"; local e = "|r"
    d(h .. "=== AnimatedActionBar+ " .. GetString(SI_AAB_CMD_HEAD) .. " ===" .. e)
    d(k .. "/aab" .. e .. " - " .. GetString(SI_AAB_CMD_PANEL))
    d(k .. "/aab info" .. e .. " - " .. GetString(SI_AAB_CMD_INFO))
    d(k .. "/aab ui" .. e .. " - " .. GetString(SI_AAB_CMD_UI))
    d(k .. "/aab id" .. e .. " |c8a7fa6(/aabids)|r - " .. GetString(SI_AAB_CMD_ID))
    d(k .. "/aab setend <id> <ms|auto>" .. e .. " - " .. GetString(SI_AAB_CMD_SETEND))
    d(k .. "/aab debug" .. e .. " - " .. GetString(SI_AAB_CMD_DEBUG))
    d(k .. "/aab cmd" .. e .. " |c8a7fa6(/aabcmds)|r - " .. GetString(SI_AAB_CMD_LIST))
end

-- versteckte konflikt-prüfung. schaut ob andere geladene addons dieselben
-- action-bar-hooks/slots anfassen wie wir, was zu doppelten rahmen/glows oder
-- überschriebenen styles führen kann. rein lokal, liest nur den eigenen client.
local function PrintConflicts()
    local head = "|ca970ff"
    local key  = "|c8a7fa6"
    local warn = "|cd69a4f"
    local good = "|c6fd66f"
    local val  = "|cc8a8ff"
    local e    = "|r"

    d(head .. "=== AnimatedActionBar+ " .. GetString(SI_AAB_CONF_HEAD) .. " ===" .. e)

    -- 1) bekannte action-bar/ulti-addons die geladen sind auflisten. namen sind
    --    die ordner-namen wie sie im AddOnManager stehen (tolerant, teilstring)
    local known = {
        { id = "FancyActionBar",    label = "FancyActionbar+" },
        { id = "BanditsUserInterface", label = "Bandit's UI" },
        { id = "LuiExtended",       label = "LUI Extended" },
        { id = "AbilityFramework",  label = "Ability Framework" },
        { id = "ActionDurationReminder", label = "Action Duration Reminder" },
        { id = "Srendarr",          label = "Srendarr" },
        { id = "UltimateSkillTracker", label = "Ultimate Skill Tracker" },
        { id = "ActionBarSaver",    label = "ActionBar Saver" },
        { id = "QuickHudToggle",    label = "Quick HUD" },
    }

    local mgr = GetAddOnManager and GetAddOnManager() or nil
    local found = {}
    if mgr then
        local count = mgr:GetNumAddOns()
        for i = 1, count do
            local name, _, _, _, enabled = mgr:GetAddOnInfo(i)
            if name and enabled then
                local lname = name:lower()
                for _, k in ipairs(known) do
                    if lname:find(k.id:lower(), 1, true) then
                        found[#found + 1] = k.label
                    end
                end
            end
        end
    end

    if #found > 0 then
        d(warn .. GetString(SI_AAB_CONF_FOUND) .. e)
        for _, label in ipairs(found) do
            d("  " .. val .. label .. e)
        end
        d(key .. GetString(SI_AAB_CONF_HINT) .. e)
    else
        d(good .. GetString(SI_AAB_CONF_NONE) .. e)
    end

    -- 2) prüfen ob unsere eigenen hooks/methoden noch da sind. wenn ein anderes
    --    addon ActionButton komplett ersetzt, fehlt unsere bounce-methode
    d(key .. GetString(SI_AAB_CONF_HOOKS) .. ":" .. e)
    local haveBounce = (ActionButton and ActionButton.PlayAbilityUsedBounce) ~= nil
    d("  " .. key .. "PlayAbilityUsedBounce: " .. e
        .. (haveBounce and (good .. GetString(SI_AAB_CONF_OK) .. e) or (warn .. GetString(SI_AAB_CONF_OVERRIDDEN) .. e)))

    local haveGlowTpl = _G["AABPlus_GlowTemplate"] ~= nil
    d("  " .. key .. "Glow-Template: " .. e
        .. (haveGlowTpl and (good .. GetString(SI_AAB_CONF_OK) .. e) or (warn .. GetString(SI_AAB_CONF_MISSING) .. e)))

    -- 3) ulti-slot: hat jemand anderes den ulti-frame wiederhergestellt?
    local ultBtn = ZO_ActionBar_GetButton and ZO_ActionBar_GetButton(ULT_SLOT_INDEX, GetActiveHotbarCategory())
    if ultBtn and ultBtn.slot then
        local frame = ultBtn.slot:GetNamedChild("Frame")
        local frameVisible = frame and frame.GetAlpha and frame:GetAlpha() > 0
        d("  " .. key .. GetString(SI_AAB_CONF_ULTFRAME) .. ": " .. e
            .. (frameVisible and (warn .. GetString(SI_AAB_CONF_VISIBLE) .. e) or (good .. GetString(SI_AAB_CONF_SUPPRESSED) .. e)))
    end

    d(head .. "=============================" .. e)
end

local function RestartActivePulses()
    local active = {}
    for s in pairs(activeProcs) do active[#active+1] = s end
    for _, s in ipairs(active) do StopPulse(s); StartPulse(s) end
end

local function RefreshUltDisplay()
    GpUlt.Refresh()
    if not sv.ultReadyEnabled then
        HideUltBorder(); HideCtrlBorder()
        return
    end
    if sv.ultBorderStyle == "controller" then
        HideUltBorder()
        SuppressVanillaUltGlow()
        ShowCtrlBorder()
    else
        HideCtrlBorder()
        SuppressVanillaUltGlow()
        if ultIsReady then ShowUltBorder() else CheckUltimateReady() end
    end
end

-- presets setzen mehrere sichtbare effekt-schalter auf einmal. sie fassen
-- nur an, was den look ausmacht - perf-toggles und farben bleiben unberührt.
local function ApplyPreset(name)
    if name == "minimal" then
        sv.bounceEnabled     = true
        sv.bounceOnProc      = false
        sv.glowEnabled       = false
        sv.pulseEnabled      = false
        sv.expireAnimEnabled = false
        sv.ultReadyPulse     = false
        sv.colorCycleEnabled = false
    elseif name == "standard" then
        sv.bounceEnabled     = true
        sv.bounceOnProc      = true
        sv.glowEnabled       = true
        sv.pulseEnabled      = true
        sv.expireAnimEnabled = true
        sv.ultReadyPulse     = true
        sv.colorCycleEnabled = false
    elseif name == "flashy" then
        sv.bounceEnabled     = true
        sv.bounceOnProc      = true
        sv.glowEnabled       = true
        sv.pulseEnabled      = true
        sv.expireAnimEnabled = true
        sv.ultReadyPulse     = true
        sv.colorCycleEnabled = true
    end
    if not sv.pulseEnabled then StopAllPulses() end
    if InvalidateAnimTimelines then InvalidateAnimTimelines() end
    RestartActivePulses()
    RefreshUltDisplay()
end

local function OpenStudio(page)
    local studio = AnimatedActionBarPlus and AnimatedActionBarPlus.Studio
    if studio and studio.Open then studio.Open(page) end
end

local function BuildMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    LAM:RegisterAddonPanel(ADDON_NAME .. "Panel", {
        type                = "panel",
        name                = "AnimatedActionBar+",
        displayName         = C_TITLE .. "Animated" .. C_RESET .. "ActionBar" .. C_TITLE .. "+" .. C_RESET,
        author              = "haze068",
        version             = ADDON_VERSION,
        slashCommand        = "/aabplus",
        registerForRefresh  = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls(ADDON_NAME .. "Panel", {

        { type = "description", text = GetString(SI_AAB_PANEL_DESCRIPTION) },
        {
            type    = "button",
            name    = GetString(SI_AAB_UI_LAM_OPEN),
            tooltip = GetString(SI_AAB_UI_LAM_DESC),
            func    = function() OpenStudio() end,
            width   = "full",
        },
        {
            type    = "dropdown",
            name    = GetString(SI_AAB_UI_THEME),
            tooltip = GetString(SI_AAB_UI_THEME_TT),
            choices = { GetString(SI_AAB_UI_THEME_NEBULA), GetString(SI_AAB_UI_THEME_LACE) },
            choicesValues = { "nebula", "lace" },
            getFunc = function() return sv.uiTheme end,
            setFunc = function(v) sv.uiTheme = v end,
            default = defaults.uiTheme,
            width   = "half",
        },
        {
            type    = "checkbox",
            name    = GetString(SI_AAB_UI_BGMOTION),
            tooltip = GetString(SI_AAB_UI_BGMOTION_TT),
            getFunc = function() return sv.uiBgMotion end,
            setFunc = function(v) sv.uiBgMotion = v end,
            default = defaults.uiBgMotion,
            width   = "half",
        },

        {
            type     = "submenu",
            name     = C_TITLE .. GetString(SI_AAB_SUB_PRESETS) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_PRESETS_TT),
            controls = {
                { type = "description", text = GetString(SI_AAB_PRESETS_DESC) },
                {
                    type    = "button",
                    name    = GetString(SI_AAB_PRESET_MINIMAL),
                    tooltip = GetString(SI_AAB_PRESET_MINIMAL_TT),
                    func    = function() ApplyPreset("minimal") end,
                    width   = "half",
                },
                {
                    type    = "button",
                    name    = GetString(SI_AAB_PRESET_STANDARD),
                    tooltip = GetString(SI_AAB_PRESET_STANDARD_TT),
                    func    = function() ApplyPreset("standard") end,
                    width   = "half",
                },
                {
                    type    = "button",
                    name    = GetString(SI_AAB_PRESET_FLASHY),
                    tooltip = GetString(SI_AAB_PRESET_FLASHY_TT),
                    func    = function() ApplyPreset("flashy") end,
                    width   = "half",
                },
                { type = "description", text = GetString(SI_AAB_PRESETS_NOTE) },
            },
        },

        {
            type     = "submenu",
            name     = C_BOUNCE .. GetString(SI_AAB_SUB_BOUNCE) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_BOUNCE_TT),
            controls = {
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_ANIM_STYLE),
                    tooltip = GetString(SI_AAB_ANIM_STYLE_TT),
                    choices       = {
                        GetString(SI_AAB_ANIM_BOUNCE),
                        GetString(SI_AAB_ANIM_FLASH),
                        GetString(SI_AAB_ANIM_SHAKE),
                        GetString(SI_AAB_ANIM_TILT),
                    },
                    choicesValues = { "bounce", "flash", "shake", "tilt" },
                    getFunc = function() return sv.animationStyle end,
                    setFunc = function(v) sv.animationStyle = v end,
                    default = defaults.animationStyle,
                    disabled = function() return not sv.bounceEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_BOUNCE_ENABLE),
                    tooltip = GetString(SI_AAB_BOUNCE_ENABLE_TT),
                    getFunc = function() return sv.bounceEnabled end,
                    setFunc = function(v) sv.bounceEnabled = v end,
                    default = defaults.bounceEnabled,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_BOUNCE_ON_PROC),
                    tooltip = GetString(SI_AAB_BOUNCE_ON_PROC_TT),
                    getFunc = function() return sv.bounceOnProc end,
                    setFunc = function(v) sv.bounceOnProc = v end,
                    default = defaults.bounceOnProc,
                    disabled = function() return not sv.bounceEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_QS_BOUNCE),
                    tooltip = GetString(SI_AAB_QS_BOUNCE_TT),
                    getFunc = function() return sv.quickslotBounceEnabled end,
                    setFunc = function(v) sv.quickslotBounceEnabled = v end,
                    default = defaults.quickslotBounceEnabled,
                    disabled = function() return not sv.bounceEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_QS_READY),
                    tooltip = GetString(SI_AAB_QS_READY_TT),
                    getFunc = function() return sv.quickslotReadyEnabled end,
                    setFunc = function(v) sv.quickslotReadyEnabled = v end,
                    default = defaults.quickslotReadyEnabled,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_BOUNCE_GROW),
                    tooltip = GetString(SI_AAB_BOUNCE_GROW_TT),
                    min = 1.0, max = 1.5, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.growScale end,
                    setFunc = function(v) sv.growScale = v; InvalidateAnimTimelines() end,
                    default = defaults.growScale,
                    disabled = function() return not sv.bounceEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_BOUNCE_SHRINK),
                    tooltip = GetString(SI_AAB_BOUNCE_SHRINK_TT),
                    min = 0.5, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.shrinkScale end,
                    setFunc = function(v) sv.shrinkScale = v; InvalidateAnimTimelines() end,
                    default = defaults.shrinkScale,
                    disabled = function() return not sv.bounceEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_BOUNCE_RESET),
                    tooltip = GetString(SI_AAB_BOUNCE_RESET_TT),
                    min = 50, max = 500, step = 10,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.frameResetTimeMS end,
                    setFunc = function(v) sv.frameResetTimeMS = v; InvalidateAnimTimelines() end,
                    default = defaults.frameResetTimeMS,
                    disabled = function() return not sv.bounceEnabled end,
                },
                { type = "divider" },
                { type = "description", text = GetString(SI_AAB_EXPIRE_DESC) },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_EXPIRE_ENABLE),
                    tooltip = GetString(SI_AAB_EXPIRE_ENABLE_TT),
                    getFunc = function() return sv.expireAnimEnabled end,
                    setFunc = function(v) sv.expireAnimEnabled = v end,
                    default = defaults.expireAnimEnabled,
                },
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_EXPIRE_STYLE),
                    tooltip = GetString(SI_AAB_EXPIRE_STYLE_TT),
                    choices = {
                        GetString(SI_AAB_EXPIRE_STYLE_INHERIT),
                        GetString(SI_AAB_ANIM_BOUNCE),
                        GetString(SI_AAB_ANIM_FLASH),
                        GetString(SI_AAB_ANIM_SHAKE),
                        GetString(SI_AAB_ANIM_TILT),
                    },
                    choicesValues = { "inherit", "bounce", "flash", "shake", "tilt" },
                    getFunc = function() return sv.expireAnimStyle end,
                    setFunc = function(v) sv.expireAnimStyle = v end,
                    default = defaults.expireAnimStyle,
                    disabled = function() return not sv.expireAnimEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_EXPIRE_STRENGTH),
                    tooltip = GetString(SI_AAB_EXPIRE_STRENGTH_TT),
                    min = 0.5, max = 2.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.expireStrength end,
                    setFunc = function(v) sv.expireStrength = v; InvalidateAnimTimelines() end,
                    default = defaults.expireStrength,
                    disabled = function() return not sv.expireAnimEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_EXPIRE_GLOW_ENABLE),
                    tooltip = GetString(SI_AAB_EXPIRE_GLOW_ENABLE_TT),
                    getFunc = function() return sv.expireGlowEnabled end,
                    setFunc = function(v) sv.expireGlowEnabled = v end,
                    default = defaults.expireGlowEnabled,
                    disabled = function() return not sv.expireAnimEnabled end,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_EXPIRE_GLOW_COLOR),
                    tooltip = GetString(SI_AAB_EXPIRE_GLOW_COLOR_TT),
                    getFunc = function() local c = sv.expireGlowColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a) sv.expireGlowColor = { r, g, b, a or 1 } end,
                    default = {
                        r = defaults.expireGlowColor[1], g = defaults.expireGlowColor[2],
                        b = defaults.expireGlowColor[3], a = defaults.expireGlowColor[4],
                    },
                    disabled = function() return not sv.expireAnimEnabled or not sv.expireGlowEnabled end,
                },
                { type = "divider" },
                { type = "description", text = GetString(SI_AAB_EXPIRE_SCALE_DESC) },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_EXPIRE_SCALE_ENABLE),
                    tooltip = GetString(SI_AAB_EXPIRE_SCALE_ENABLE_TT),
                    getFunc = function() return sv.expireScaleByDuration end,
                    setFunc = function(v) sv.expireScaleByDuration = v; InvalidateAnimTimelines() end,
                    default = defaults.expireScaleByDuration,
                    disabled = function() return not sv.expireAnimEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_EXPIRE_SCALE_REF),
                    tooltip = GetString(SI_AAB_EXPIRE_SCALE_REF_TT),
                    min = 2000, max = 30000, step = 500,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.expireScaleRefMS end,
                    setFunc = function(v) sv.expireScaleRefMS = v; InvalidateAnimTimelines() end,
                    default = defaults.expireScaleRefMS,
                    disabled = function() return not sv.expireAnimEnabled or not sv.expireScaleByDuration end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_EXPIRE_SCALE_MIN),
                    tooltip = GetString(SI_AAB_EXPIRE_SCALE_MIN_TT),
                    min = 0.3, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.expireScaleMin end,
                    setFunc = function(v) sv.expireScaleMin = v; InvalidateAnimTimelines() end,
                    default = defaults.expireScaleMin,
                    disabled = function() return not sv.expireAnimEnabled or not sv.expireScaleByDuration end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_EXPIRE_SCALE_MAX),
                    tooltip = GetString(SI_AAB_EXPIRE_SCALE_MAX_TT),
                    min = 1.0, max = 3.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.expireScaleMax end,
                    setFunc = function(v) sv.expireScaleMax = v; InvalidateAnimTimelines() end,
                    default = defaults.expireScaleMax,
                    disabled = function() return not sv.expireAnimEnabled or not sv.expireScaleByDuration end,
                },
                {
                    type    = "button",
                    name    = GetString(SI_AAB_EXPIRE_OVERRIDE_CLEAR),
                    tooltip = GetString(SI_AAB_EXPIRE_OVERRIDE_CLEAR_TT),
                    func    = function() sv.expireDurationOverride = {} end,
                    width   = "half",
                    disabled = function() return not sv.expireAnimEnabled end,
                },
                { type = "description", text = GetString(SI_AAB_EXPIRE_OVERRIDE_NOTE) },
            },
        },

        {
            type     = "submenu",
            name     = C_GLOW .. GetString(SI_AAB_SUB_GLOW) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_GLOW_TT),
            controls = {
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_GLOW_ENABLE),
                    tooltip = GetString(SI_AAB_GLOW_ENABLE_TT),
                    getFunc = function() return sv.glowEnabled end,
                    setFunc = function(v) sv.glowEnabled = v end,
                    default = defaults.glowEnabled,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_GLOW_COLOR),
                    tooltip = GetString(SI_AAB_GLOW_COLOR_TT),
                    getFunc = function() local c = sv.glowColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a) sv.glowColor = { r, g, b, a or 1 } end,
                    default = {
                        r = defaults.glowColor[1], g = defaults.glowColor[2],
                        b = defaults.glowColor[3], a = defaults.glowColor[4],
                    },
                    disabled = function() return not sv.glowEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_GLOW_DURATION),
                    tooltip = GetString(SI_AAB_GLOW_DURATION_TT),
                    min = 100, max = 2000, step = 50,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.glowDurationMS end,
                    setFunc = function(v) sv.glowDurationMS = v end,
                    default = defaults.glowDurationMS,
                    disabled = function() return not sv.glowEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_GLOW_PADDING),
                    tooltip = GetString(SI_AAB_GLOW_PADDING_TT),
                    min = 0, max = 24, step = 1,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.glowPadding end,
                    setFunc = function(v) sv.glowPadding = v end,
                    default = defaults.glowPadding,
                    disabled = function() return not sv.glowEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_GLOW_INTENSITY),
                    tooltip = GetString(SI_AAB_GLOW_INTENSITY_TT),
                    min = 1.0, max = 2.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.glowIntensity end,
                    setFunc = function(v) sv.glowIntensity = v end,
                    default = defaults.glowIntensity,
                    disabled = function() return not sv.glowEnabled end,
                },
            },
        },

        {
            type     = "submenu",
            name     = C_PULSE .. GetString(SI_AAB_SUB_PULSE) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_PULSE_TT),
            controls = {
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PULSE_ENABLE),
                    tooltip = GetString(SI_AAB_PULSE_ENABLE_TT),
                    getFunc = function() return sv.pulseEnabled end,
                    setFunc = function(v)
                        sv.pulseEnabled = v
                        if not v then
                            for s in pairs(activeProcs) do StopPulse(s) end
                        end
                    end,
                    default = defaults.pulseEnabled,
                    disabled = function() return not sv.glowEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PROC_VANILLA_GLOW),
                    tooltip = GetString(SI_AAB_PROC_VANILLA_GLOW_TT),
                    getFunc = function() return sv.vanillaProcGlow end,
                    setFunc = function(v)
                        sv.vanillaProcGlow = v
                        RefreshProcGlowSuppression()
                    end,
                    default = defaults.vanillaProcGlow,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PULSE_STOP_ON_PRESS),
                    tooltip = GetString(SI_AAB_PULSE_STOP_ON_PRESS_TT),
                    getFunc = function() return sv.stopGlowOnPress end,
                    setFunc = function(v) sv.stopGlowOnPress = v end,
                    default = defaults.stopGlowOnPress,
                    disabled = function() return not sv.pulseEnabled end,
                },
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_PULSE_STYLE),
                    tooltip = GetString(SI_AAB_PULSE_STYLE_TT),
                    choices       = { GetString(SI_AAB_PULSE_STYLE_SMOOTH), GetString(SI_AAB_PULSE_STYLE_BLINK), GetString(SI_AAB_PULSE_STYLE_STROBE) },
                    choicesValues = { "smooth", "blink", "strobe" },
                    getFunc = function() return sv.pulseMode end,
                    setFunc = function(v) sv.pulseMode = v; RestartActivePulses() end,
                    default = defaults.pulseMode,
                    disabled = function() return not sv.pulseEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_PULSE_SMOOTH_DUR),
                    tooltip = GetString(SI_AAB_PULSE_SMOOTH_DUR_TT),
                    min = 200, max = 2000, step = 50,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.pulseDurationMS end,
                    setFunc = function(v) sv.pulseDurationMS = v end,
                    default = defaults.pulseDurationMS,
                    disabled = function() return not sv.pulseEnabled or sv.pulseMode ~= "smooth" end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_PULSE_BLINK_INT),
                    tooltip = GetString(SI_AAB_PULSE_BLINK_INT_TT),
                    min = 80, max = 800, step = 10,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.blinkIntervalMS end,
                    setFunc = function(v) sv.blinkIntervalMS = v end,
                    default = defaults.blinkIntervalMS,
                    disabled = function() return not sv.pulseEnabled or sv.pulseMode ~= "blink" end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_PULSE_STROBE_INT),
                    tooltip = GetString(SI_AAB_PULSE_STROBE_INT_TT),
                    min = 30, max = 200, step = 5,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.strobeIntervalMS end,
                    setFunc = function(v) sv.strobeIntervalMS = v end,
                    default = defaults.strobeIntervalMS,
                    disabled = function() return not sv.pulseEnabled or sv.pulseMode ~= "strobe" end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_PULSE_MIN_ALPHA),
                    tooltip = GetString(SI_AAB_PULSE_MIN_ALPHA_TT),
                    min = 0.0, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.pulseMinAlpha end,
                    setFunc = function(v) sv.pulseMinAlpha = v end,
                    default = defaults.pulseMinAlpha,
                    disabled = function() return not sv.pulseEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_PULSE_MAX_ALPHA),
                    tooltip = GetString(SI_AAB_PULSE_MAX_ALPHA_TT),
                    min = 0.0, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.pulseMaxAlpha end,
                    setFunc = function(v) sv.pulseMaxAlpha = v end,
                    default = defaults.pulseMaxAlpha,
                    disabled = function() return not sv.pulseEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PULSE_COLOR_CYCLE),
                    tooltip = GetString(SI_AAB_PULSE_COLOR_CYCLE_TT),
                    getFunc = function() return sv.colorCycleEnabled end,
                    setFunc = function(v) sv.colorCycleEnabled = v; RestartActivePulses() end,
                    default = defaults.colorCycleEnabled,
                    disabled = function() return not sv.pulseEnabled end,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_PULSE_COLOR_SECOND),
                    tooltip = GetString(SI_AAB_PULSE_COLOR_SECOND_TT),
                    getFunc = function() local c = sv.colorCycleSecondary; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a) sv.colorCycleSecondary = { r, g, b, a or 1 } end,
                    default = {
                        r = defaults.colorCycleSecondary[1], g = defaults.colorCycleSecondary[2],
                        b = defaults.colorCycleSecondary[3], a = defaults.colorCycleSecondary[4],
                    },
                    disabled = function() return not sv.pulseEnabled or not sv.colorCycleEnabled end,
                },
            },
        },

        {
            type     = "submenu",
            name     = C_ULT .. GetString(SI_AAB_SUB_ULT) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_ULT_TT),
            controls = {
                { type = "header", name = GetString(SI_AAB_ULT_HEADER_EFFECTS) },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULT_BOUNCE_ENABLE),
                    tooltip = GetString(SI_AAB_ULT_BOUNCE_ENABLE_TT),
                    getFunc = function() return sv.ultBounceEnabled end,
                    setFunc = function(v) sv.ultBounceEnabled = v end,
                    default = defaults.ultBounceEnabled,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULT_GLOW_ENABLE),
                    tooltip = GetString(SI_AAB_ULT_GLOW_ENABLE_TT),
                    getFunc = function() return sv.ultGlowEnabled end,
                    setFunc = function(v) sv.ultGlowEnabled = v end,
                    default = defaults.ultGlowEnabled,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_ULT_GLOW_COLOR),
                    tooltip = GetString(SI_AAB_ULT_GLOW_COLOR_TT),
                    getFunc = function() local c = sv.ultGlowColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a) sv.ultGlowColor = { r, g, b, a or 1 } end,
                    default = {
                        r = defaults.ultGlowColor[1], g = defaults.ultGlowColor[2],
                        b = defaults.ultGlowColor[3], a = defaults.ultGlowColor[4],
                    },
                    disabled = function() return not sv.ultGlowEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_GLOW_DURATION),
                    tooltip = GetString(SI_AAB_ULT_GLOW_DURATION_TT),
                    min = 100, max = 3000, step = 50,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.ultGlowDurationMS end,
                    setFunc = function(v) sv.ultGlowDurationMS = v end,
                    default = defaults.ultGlowDurationMS,
                    disabled = function() return not sv.ultGlowEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_GLOW_PADDING),
                    tooltip = GetString(SI_AAB_ULT_GLOW_PADDING_TT),
                    min = 0, max = 40, step = 1,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.ultGlowPadding end,
                    setFunc = function(v) sv.ultGlowPadding = v end,
                    default = defaults.ultGlowPadding,
                    disabled = function() return not sv.ultGlowEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_GLOW_INTENSITY),
                    tooltip = GetString(SI_AAB_ULT_GLOW_INTENSITY_TT),
                    min = 1.0, max = 2.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.ultGlowIntensity end,
                    setFunc = function(v) sv.ultGlowIntensity = v end,
                    default = defaults.ultGlowIntensity,
                    disabled = function() return not sv.ultGlowEnabled end,
                },

                { type = "header", name = GetString(SI_AAB_UI_HDR_ULTGP) },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULTGP_ENABLE),
                    tooltip = GetString(SI_AAB_ULTGP_ENABLE_TT),
                    getFunc = function() return sv.ultGpFrameEnabled end,
                    setFunc = function(v) sv.ultGpFrameEnabled = v; GpUlt.Refresh() end,
                    default = defaults.ultGpFrameEnabled,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_ULTGP_FRAMECOLOR),
                    tooltip = GetString(SI_AAB_ULTGP_FRAMECOLOR_TT),
                    getFunc = function() local c = sv.ultGpFrameColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a) sv.ultGpFrameColor = { r, g, b, a or 1 }; GpUlt.Paint() end,
                    default = {
                        r = defaults.ultGpFrameColor[1], g = defaults.ultGpFrameColor[2],
                        b = defaults.ultGpFrameColor[3], a = defaults.ultGpFrameColor[4],
                    },
                    disabled = function() return not sv.ultGpFrameEnabled end,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_ULTGP_FILLCOLOR),
                    tooltip = GetString(SI_AAB_ULTGP_FILLCOLOR_TT),
                    getFunc = function() local c = sv.ultGpFillColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a) sv.ultGpFillColor = { r, g, b, a or 1 }; GpUlt.Paint() end,
                    default = {
                        r = defaults.ultGpFillColor[1], g = defaults.ultGpFillColor[2],
                        b = defaults.ultGpFillColor[3], a = defaults.ultGpFillColor[4],
                    },
                    disabled = function() return not sv.ultGpFrameEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULTGP_FULL_ENABLE),
                    tooltip = GetString(SI_AAB_ULTGP_FULL_ENABLE_TT),
                    getFunc = function() return sv.ultGpFullColorEnabled end,
                    setFunc = function(v) sv.ultGpFullColorEnabled = v; GpUlt.Paint() end,
                    default = defaults.ultGpFullColorEnabled,
                    disabled = function() return not sv.ultGpFrameEnabled end,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_ULTGP_FULLCOLOR),
                    tooltip = GetString(SI_AAB_ULTGP_FULLCOLOR_TT),
                    getFunc = function() local c = sv.ultGpFullColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a) sv.ultGpFullColor = { r, g, b, a or 1 }; GpUlt.Paint() end,
                    default = {
                        r = defaults.ultGpFullColor[1], g = defaults.ultGpFullColor[2],
                        b = defaults.ultGpFullColor[3], a = defaults.ultGpFullColor[4],
                    },
                    disabled = function() return not sv.ultGpFrameEnabled or not sv.ultGpFullColorEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULTGP_RAINBOW),
                    tooltip = GetString(SI_AAB_ULTGP_RAINBOW_TT),
                    getFunc = function() return sv.ultGpRainbow end,
                    setFunc = function(v) sv.ultGpRainbow = v; GpUlt.Refresh() end,
                    default = defaults.ultGpRainbow,
                    disabled = function() return not sv.ultGpFrameEnabled end,
                },

                { type = "header", name = GetString(SI_AAB_ULT_HEADER_READY) },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULT_VANILLA_SHIMMER),
                    tooltip = GetString(SI_AAB_ULT_VANILLA_SHIMMER_TT),
                    getFunc = function() return sv.vanillaUltShimmer end,
                    setFunc = function(v)
                        sv.vanillaUltShimmer = v
                        if v then
                            RestoreVanillaUltShimmer()
                        else
                            SuppressVanillaUltGlow()
                        end
                    end,
                    default = defaults.vanillaUltShimmer,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                },
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_ULT_BORDER_STYLE),
                    tooltip = GetString(SI_AAB_ULT_BORDER_STYLE_TT),
                    choices = {
                        GetString(SI_AAB_ULT_BORDER_CUSTOM),
                        GetString(SI_AAB_ULT_BORDER_CONTROLLER),
                    },
                    choicesValues = { "custom", "controller" },
                    getFunc = function() return sv.ultBorderStyle end,
                    setFunc = function(v)
                        sv.ultBorderStyle = v
                        if v == "controller" then
                            HideUltBorder()   -- eigenen glow-rahmen abräumen
                            SuppressVanillaUltGlow()
                            ShowCtrlBorder()  -- eigene fortschritts-border zeigen
                        else
                            HideCtrlBorder()  -- controller-border abräumen
                            SuppressVanillaUltGlow()
                            CheckUltimateReady()  -- eigenen glow-rahmen ggf. neu aufbauen
                        end
                    end,
                    default = defaults.ultBorderStyle,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                },
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_ULTCTRL_STYLE),
                    tooltip = GetString(SI_AAB_ULTCTRL_STYLE_TT),
                    choices = {
                        GetString(SI_AAB_ULTCTRL_STYLE_FLAT),
                        GetString(SI_AAB_ULTCTRL_STYLE_BEVEL),
                        GetString(SI_AAB_ULTCTRL_STYLE_SLEEK),
                        GetString(SI_AAB_ULTCTRL_STYLE_CHAMFER),
                        GetString(SI_AAB_ULTCTRL_STYLE_DOUBLE),
                    },
                    choicesValues = { "flat", "bevel", "sleek", "chamfer", "double" },
                    getFunc = function() return sv.ultCtrlStyle end,
                    setFunc = function(v) sv.ultCtrlStyle = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlStyle,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULTCTRL_THICKNESS),
                    tooltip = GetString(SI_AAB_ULTCTRL_THICKNESS_TT),
                    min     = 1, max = 10, step = 1,
                    getFunc = function() return sv.ultCtrlThickness end,
                    setFunc = function(v) sv.ultCtrlThickness = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlThickness,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULTCTRL_CORNER),
                    tooltip = GetString(SI_AAB_ULTCTRL_CORNER_TT),
                    min     = 10, max = 50, step = 5,
                    getFunc = function() return math.floor((sv.ultCtrlCornerFrac or 0.30) * 100 + 0.5) end,
                    setFunc = function(v) sv.ultCtrlCornerFrac = v / 100; ShowCtrlBorder() end,
                    default = 30,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULTCTRL_PADDING),
                    tooltip = GetString(SI_AAB_ULTCTRL_PADDING_TT),
                    min     = 0, max = 12, step = 1,
                    getFunc = function() return sv.ultCtrlPadding end,
                    setFunc = function(v) sv.ultCtrlPadding = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlPadding,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULTCTRL_TRACK),
                    tooltip = GetString(SI_AAB_ULTCTRL_TRACK_TT),
                    getFunc = function() return sv.ultCtrlShowTrack end,
                    setFunc = function(v) sv.ultCtrlShowTrack = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlShowTrack,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULTCTRL_COLORSHIFT),
                    tooltip = GetString(SI_AAB_ULTCTRL_COLORSHIFT_TT),
                    getFunc = function() return sv.ultCtrlColorShift end,
                    setFunc = function(v) sv.ultCtrlColorShift = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlColorShift,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_ULTCTRL_CHARGECOLOR),
                    tooltip = GetString(SI_AAB_ULTCTRL_CHARGECOLOR_TT),
                    getFunc = function() local c = sv.ultCtrlChargingColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a)
                        sv.ultCtrlChargingColor = { r, g, b, a or 1 }
                        ShowCtrlBorder()
                    end,
                    default = {
                        r = defaults.ultCtrlChargingColor[1], g = defaults.ultCtrlChargingColor[2],
                        b = defaults.ultCtrlChargingColor[3], a = defaults.ultCtrlChargingColor[4],
                    },
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled or not sv.ultCtrlColorShift end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULTCTRL_GLOWFULL),
                    tooltip = GetString(SI_AAB_ULTCTRL_GLOWFULL_TT),
                    getFunc = function() return sv.ultCtrlGlowOnFull end,
                    setFunc = function(v) sv.ultCtrlGlowOnFull = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlGlowOnFull,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_ULTCTRL_GLOWSTYLE),
                    tooltip = GetString(SI_AAB_ULTCTRL_GLOWSTYLE_TT),
                    choices = {
                        GetString(SI_AAB_ULTCTRL_GLOWSTYLE_SOFT),
                        GetString(SI_AAB_ULTCTRL_GLOWSTYLE_SHARP),
                        GetString(SI_AAB_ULTCTRL_GLOWSTYLE_RING),
                    },
                    choicesValues = { "soft", "sharp", "ring" },
                    getFunc = function() return sv.ultCtrlGlowStyle end,
                    setFunc = function(v) sv.ultCtrlGlowStyle = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlGlowStyle,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled or not sv.ultCtrlGlowOnFull end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULTCTRL_GLOWINT),
                    tooltip = GetString(SI_AAB_ULTCTRL_GLOWINT_TT),
                    min     = 0.1, max = 1.0, step = 0.05,
                    getFunc = function() return sv.ultCtrlGlowIntensity end,
                    setFunc = function(v) sv.ultCtrlGlowIntensity = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlGlowIntensity,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled or not sv.ultCtrlGlowOnFull end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_UI_ULTCTRL_SPREAD),
                    tooltip = GetString(SI_AAB_UI_ULTCTRL_SPREAD_TT),
                    min     = 0, max = 10, step = 1,
                    getFunc = function() return sv.ultCtrlGlowSpread end,
                    setFunc = function(v) sv.ultCtrlGlowSpread = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlGlowSpread,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled or not sv.ultCtrlGlowOnFull end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_UI_ULTCTRL_PULSEMS),
                    tooltip = GetString(SI_AAB_UI_ULTCTRL_PULSEMS_TT),
                    min     = 100, max = 2000, step = 10,
                    getFunc = function() return sv.ultCtrlPulseMS end,
                    setFunc = function(v) sv.ultCtrlPulseMS = v end,
                    default = defaults.ultCtrlPulseMS,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled or not sv.ultCtrlGlowOnFull end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_UI_ULTCTRL_POLL),
                    tooltip = GetString(SI_AAB_UI_ULTCTRL_POLL_TT),
                    min     = 30, max = 1000, step = 10,
                    getFunc = function() return sv.ultCtrlPollMS end,
                    setFunc = function(v) sv.ultCtrlPollMS = v end,
                    default = defaults.ultCtrlPollMS,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULTCTRL_RAINBOW),
                    tooltip = GetString(SI_AAB_ULTCTRL_RAINBOW_TT),
                    getFunc = function() return sv.ultCtrlRainbow end,
                    setFunc = function(v) sv.ultCtrlRainbow = v; ShowCtrlBorder() end,
                    default = defaults.ultCtrlRainbow,
                    disabled = function() return sv.ultBorderStyle ~= "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULT_ENABLE),
                    tooltip = GetString(SI_AAB_ULT_ENABLE_TT),
                    getFunc = function() return sv.ultReadyEnabled end,
                    setFunc = function(v)
                        sv.ultReadyEnabled = v
                        if not v then
                            HideUltBorder(); HideCtrlBorder()
                        elseif sv.ultBorderStyle == "controller" then
                            ShowCtrlBorder()
                        else
                            CheckUltimateReady()
                        end
                    end,
                    default = defaults.ultReadyEnabled,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_ULT_COLOR),
                    tooltip = GetString(SI_AAB_ULT_COLOR_TT),
                    getFunc = function() local c = sv.ultReadyColor; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a)
                        sv.ultReadyColor = { r, g, b, a or 1 }
                        if sv.ultBorderStyle == "controller" then
                            ShowCtrlBorder()       -- klammer neu einfärben
                        elseif ultIsReady then
                            ShowUltBorder()
                        end
                    end,
                    default = {
                        r = defaults.ultReadyColor[1], g = defaults.ultReadyColor[2],
                        b = defaults.ultReadyColor[3], a = defaults.ultReadyColor[4],
                    },
                    disabled = function() return not sv.ultReadyEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULT_PULSE),
                    tooltip = GetString(SI_AAB_ULT_PULSE_TT),
                    getFunc = function() return sv.ultReadyPulse end,
                    setFunc = function(v)
                        sv.ultReadyPulse = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultReadyPulse,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_ULT_PULSE_MODE),
                    tooltip = GetString(SI_AAB_ULT_PULSE_MODE_TT),
                    choices       = { GetString(SI_AAB_PULSE_STYLE_SMOOTH), GetString(SI_AAB_PULSE_STYLE_BLINK), GetString(SI_AAB_PULSE_STYLE_RAINBOW) },
                    choicesValues = { "smooth", "blink", "smooth-rainbow" },
                    getFunc = function() return sv.ultReadyMode end,
                    setFunc = function(v)
                        sv.ultReadyMode = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultReadyMode,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_BLINK_INT),
                    tooltip = GetString(SI_AAB_ULT_BLINK_INT_TT),
                    min = 80, max = 800, step = 10,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.ultReadyBlinkIntMS end,
                    setFunc = function(v)
                        sv.ultReadyBlinkIntMS = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultReadyBlinkIntMS,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "blink" end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_ULT_COLOR_CYCLE),
                    tooltip = GetString(SI_AAB_ULT_COLOR_CYCLE_TT),
                    getFunc = function() return sv.ultColorCycleEnabled end,
                    setFunc = function(v)
                        sv.ultColorCycleEnabled = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultColorCycleEnabled,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "blink" end,
                },
                {
                    type    = "colorpicker",
                    name    = GetString(SI_AAB_ULT_COLOR_SECOND),
                    tooltip = GetString(SI_AAB_ULT_COLOR_SECOND_TT),
                    getFunc = function() local c = sv.ultColorCycleSecondary; return c[1], c[2], c[3], c[4] end,
                    setFunc = function(r, g, b, a)
                        sv.ultColorCycleSecondary = { r, g, b, a or 1 }
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = {
                        r = defaults.ultColorCycleSecondary[1], g = defaults.ultColorCycleSecondary[2],
                        b = defaults.ultColorCycleSecondary[3], a = defaults.ultColorCycleSecondary[4],
                    },
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "blink" or not sv.ultColorCycleEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_RAINBOW_SAT),
                    tooltip = GetString(SI_AAB_ULT_RAINBOW_SAT_TT),
                    min = 0.0, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.ultRainbowSaturation end,
                    setFunc = function(v)
                        sv.ultRainbowSaturation = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultRainbowSaturation,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "smooth-rainbow" end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_RAINBOW_LIGHT),
                    tooltip = GetString(SI_AAB_ULT_RAINBOW_LIGHT_TT),
                    min = 0.0, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.ultRainbowLightness end,
                    setFunc = function(v)
                        sv.ultRainbowLightness = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultRainbowLightness,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "smooth-rainbow" end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_PULSE_DUR),
                    tooltip = GetString(SI_AAB_ULT_PULSE_DUR_TT),
                    min = 80, max = 2000, step = 20,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.ultReadyPulseDurMS end,
                    setFunc = function(v)
                        sv.ultReadyPulseDurMS = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultReadyPulseDurMS,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "smooth" end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_PULSE_MIN),
                    tooltip = GetString(SI_AAB_ULT_PULSE_MIN_TT),
                    min = 0.0, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.ultReadyMinAlpha end,
                    setFunc = function(v)
                        sv.ultReadyMinAlpha = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultReadyMinAlpha,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled or not sv.ultReadyPulse end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_INTENSITY),
                    tooltip = GetString(SI_AAB_ULT_INTENSITY_TT),
                    min = 1.0, max = 2.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.ultReadyIntensity end,
                    setFunc = function(v)
                        sv.ultReadyIntensity = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultReadyIntensity,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled end,
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_ULT_PADDING),
                    tooltip = GetString(SI_AAB_ULT_PADDING_TT),
                    min = 0, max = 24, step = 1,
                    decimals = 0, clampInput = true,
                    getFunc = function() return sv.ultReadyPadding end,
                    setFunc = function(v)
                        sv.ultReadyPadding = v
                        if ultIsReady then ShowUltBorder() end
                    end,
                    default = defaults.ultReadyPadding,
                    disabled = function() return sv.ultBorderStyle == "controller" or not sv.ultReadyEnabled end,
                },
            },
        },

        {
            type     = "submenu",
            name     = C_FRAME .. GetString(SI_AAB_SUB_FRAME) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_FRAME_TT),
            controls = {
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_THIN_FRAME),
                    tooltip = GetString(SI_AAB_THIN_FRAME_TT),
                    getFunc = function() return sv.thinFrameEnabled end,
                    setFunc = function(v) sv.thinFrameEnabled = v end,
                    default = defaults.thinFrameEnabled,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                },
                {
                    type    = "slider",
                    name    = GetString(SI_AAB_FRAME_ALPHA),
                    tooltip = GetString(SI_AAB_FRAME_ALPHA_TT),
                    min = 0.0, max = 1.0, step = 0.05,
                    decimals = 2, clampInput = true,
                    getFunc = function() return sv.frameAlpha end,
                    setFunc = function(v) sv.frameAlpha = v; ApplyFrameAlpha() end,
                    default = defaults.frameAlpha,
                    disabled = function() return not sv.thinFrameEnabled end,
                },
                {
                    type    = "dropdown",
                    name    = GetString(SI_AAB_EDGE_STYLE),
                    tooltip = GetString(SI_AAB_EDGE_STYLE_TT),
                    choices = {
                        GetString(SI_AAB_EDGE_CLASSIC),
                        GetString(SI_AAB_EDGE_V2),
                        GetString(SI_AAB_EDGE_PURPLE),
                        GetString(SI_AAB_EDGE_RED),
                        GetString(SI_AAB_EDGE_BLUE),
                        GetString(SI_AAB_EDGE_AQUA),
                        GetString(SI_AAB_EDGE_DARKRED),
                        GetString(SI_AAB_EDGE_DARKPURPLE),
                    },
                    choicesValues = { "classic", "v2", "purple", "red", "blue", "aqua", "darkred", "darkpurple" },
                    getFunc = function() return sv.edgeStyle end,
                    setFunc = function(v) sv.edgeStyle = v; ApplyEdgeTexture() end,
                    default = defaults.edgeStyle,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                    requiresReload = true,
                    disabled = function() return not sv.thinFrameEnabled end,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_UI_GP_KBLAYOUT),
                    tooltip = GetString(SI_AAB_UI_GP_KBLAYOUT_TT),
                    getFunc = function() return sv.gamepadKeyboardLayout end,
                    setFunc = function(v) sv.gamepadKeyboardLayout = v; KbLook.Refresh() end,
                    default = defaults.gamepadKeyboardLayout,
                },
                {
                    type    = "button",
                    name    = GetString(SI_AAB_RELOAD_UI),
                    tooltip = GetString(SI_AAB_RELOAD_UI_TT),
                    func    = function() ReloadUI("ingame") end,
                    width   = "half",
                },
                { type = "divider" },
                { type = "description", text = GetString(SI_AAB_FRAME_THEME_NOTE) },
            },
        },
        {
            type     = "submenu",
            name     = C_FRAME .. GetString(SI_AAB_SUB_PERF) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_PERF_TT),
            controls = {
                { type = "description", text = GetString(SI_AAB_PERF_DESC) },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PERF_EFFECTID),
                    tooltip = GetString(SI_AAB_PERF_EFFECTID_TT),
                    getFunc = function() return sv.perfEffectIdFilter end,
                    setFunc = function(v)
                        sv.perfEffectIdFilter = v
                        if RefreshEffectRegistration then RefreshEffectRegistration() end
                    end,
                    default = defaults.perfEffectIdFilter,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PERF_SLOTMAP),
                    tooltip = GetString(SI_AAB_PERF_SLOTMAP_TT),
                    getFunc = function() return sv.perfSlotLookupMap end,
                    setFunc = function(v)
                        sv.perfSlotLookupMap = v
                        if v and RebuildSlotLookup then RebuildSlotLookup() end
                    end,
                    default = defaults.perfSlotLookupMap,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PERF_COMBAT),
                    tooltip = GetString(SI_AAB_PERF_COMBAT_TT),
                    getFunc = function() return sv.perfCombatOnly end,
                    setFunc = function(v) sv.perfCombatOnly = v end,
                    default = defaults.perfCombatOnly,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PERF_RAINBOW),
                    tooltip = GetString(SI_AAB_PERF_RAINBOW_TT),
                    getFunc = function() return sv.perfSlowRainbow end,
                    setFunc = function(v)
                        sv.perfSlowRainbow = v
                        -- rainbow neu starten, damit das neue intervall greift
                        if CheckUltimateReady then CheckUltimateReady() end
                    end,
                    default = defaults.perfSlowRainbow,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PERF_STYLEHOOK),
                    tooltip = GetString(SI_AAB_PERF_STYLEHOOK_TT),
                    getFunc = function() return sv.perfSingleStyleHook end,
                    setFunc = function(v) sv.perfSingleStyleHook = v end,
                    default = defaults.perfSingleStyleHook,
                    warning = GetString(SI_AAB_RELOAD_NOTE),
                    requiresReload = true,
                },
                {
                    type    = "checkbox",
                    name    = GetString(SI_AAB_PERF_TLCACHE),
                    tooltip = GetString(SI_AAB_PERF_TLCACHE_TT),
                    getFunc = function() return sv.perfLimitTimelineCache end,
                    setFunc = function(v)
                        sv.perfLimitTimelineCache = v
                        if InvalidateAnimTimelines then InvalidateAnimTimelines() end
                    end,
                    default = defaults.perfLimitTimelineCache,
                },
                { type = "divider" },
                { type = "description", text = GetString(SI_AAB_PERF_NOTE) },
            },
        },
        {
            type      = "submenu",
            reference = ADDON_NAME .. "InfoSubmenu",
            name      = C_FRAME .. GetString(SI_AAB_SUB_INFO) .. C_RESET,
            tooltip   = GetString(SI_AAB_SUB_INFO_TT),
            controls  = {
                { type = "description", text = GetString(SI_AAB_INFO_THINFRAMES) },
                { type = "divider" },
                { type = "description", text = GetString(SI_AAB_INFO_GAMEPAD) },
            },
        },
        {
            type     = "submenu",
            name     = C_DONATE .. GetString(SI_AAB_SUB_CONTACT) .. C_RESET,
            tooltip  = GetString(SI_AAB_SUB_CONTACT_TT),
            controls = {
                { type = "description", text = GetString(SI_AAB_CONTACT_DESC) },
                {
                    type    = "button",
                    name    = GetString(SI_AAB_CONTACT_DONATE_BTN),
                    tooltip = GetString(SI_AAB_CONTACT_DONATE_BTN_TT),
                    func    = function() OpenDonationMail() end,
                    width   = "full",
                },
            },
        },
    })
end

-- intern fürs studio
local function ExposeStudioApi()
    AnimatedActionBarPlus = AnimatedActionBarPlus or {}
    AnimatedActionBarPlus._studioApi = {
        version         = ADDON_VERSION,
        colors          = AAB_COLORS,
        edgeTextures    = EDGE_TEXTURES,
        ultEdgeTextures = ULT_EDGE_TEX,
        ultGlowTextures = ULT_GLOW_TEX,

        GetSV       = function() return sv end,
        GetDefaults = function() return defaults end,

        Clamp        = Clamp,
        SafeMS       = SafeMS,
        SafeInterval = SafeInterval,
        Alpha01      = Alpha01,
        SafeScale    = SafeScale,
        HSLToRGB     = HSLToRGB,

        PlayPreviewAnim     = function(...) if PlayPreviewAnim then PlayPreviewAnim(...) end end,
        ResolveExpireStyle  = ResolveExpireStyle,
        ResolveExpireScale  = ResolveExpireScale,

        InvalidateAnimTimelines = function() if InvalidateAnimTimelines then InvalidateAnimTimelines() end end,
        RestartActivePulses     = RestartActivePulses,
        StopAllPulses           = StopAllPulses,
        RefreshAllProcs         = RefreshAllProcs,
        RefreshUltDisplay       = RefreshUltDisplay,
        RestoreVanillaUltShimmer = RestoreVanillaUltShimmer,
        SuppressVanillaUltGlow  = SuppressVanillaUltGlow,
        RefreshProcGlowSuppression = RefreshProcGlowSuppression,
        ApplyFrameAlpha         = ApplyFrameAlpha,
        ApplyEdgeTexture        = ApplyEdgeTexture,
        RefreshEffectRegistration = function() if RefreshEffectRegistration then RefreshEffectRegistration() end end,
        RebuildSlotLookup       = function() if RebuildSlotLookup then RebuildSlotLookup() end end,
        ApplyPreset             = ApplyPreset,
        OpenDonationMail        = OpenDonationMail,
        SyncQuickslotState      = QS.Sync,
        RefreshKeyboardLook     = KbLook.Refresh,
        RefreshGpUlt            = function() GpUlt.Refresh() end,
        gpUltTextures           = { edge = GpUlt.EDGE, fill = GpUlt.FILL },
    }
end

-- init

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- server-abhängiger scope (EU/NA/PTS getrennt) via GetWorldName()
    local worldName = GetWorldName()
    sv = ZO_SavedVars:NewAccountWide("AnimatedActionBarPlusSV", 1, worldName, defaults)

    -- one-time-migration der alten, server-unabhängigen einstellungen in den neuen scope
    if not sv.__serverMigrated then
        local old = ZO_SavedVars:NewAccountWide("AnimatedActionBarPlusSV", 1, nil, {})
        if old then
            for k, v in pairs(old) do
                -- interne ZO_SavedVars-felder und schon vorhandene werte nicht überschreiben
                if k ~= "version" and k ~= "_internal" and k ~= "__serverMigrated" and sv[k] == nil then
                    sv[k] = v
                end
            end
        end
        sv.__serverMigrated = true

        -- alte strukturen leeren, damit die SV-datei nicht unnötig wächst
        if old then
            for k in pairs(old) do
                if k ~= "version" and k ~= "_internal" then
                    old[k] = nil
                end
            end
        end
    end

    KbLook.InstallHooks()
    KbLook.PatchFab()

    if sv.thinFrameEnabled then
        ApplyThinFrameTemplate()
    end

    -- bei aktivem schlankem rahmen deckt der hook oben den ulti-slot schon ab,
    -- dann können wir diesen zweiten sparen. ohne rahmen ist er der einzige
    local skipSecondHook = sv.perfSingleStyleHook and sv.thinFrameEnabled
    if not skipSecondHook then
        SecurePostHook(ActionButton, "ApplyStyle", function(self)
            if self and self.slot and self.slot.slotNum == ULT_SLOT_INDEX then
                -- vanilla-rahmen und fill-anims immer weg; im controller-modus zeichnen
                -- wir stattdessen unsere eigene fortschritts-border.
                for _, name in ipairs(ULT_FRAME_CHILDREN) do
                    local c = self.slot:GetNamedChild(name)
                    if c then
                        c:SetAlpha(0)
                        if c.SetHidden then c:SetHidden(true) end
                    end
                end
                -- schimmern nur weg wenn der nutzer das will
                if not sv.vanillaUltShimmer then
                    for _, name in ipairs(ULT_SHIMMER_CHILDREN) do
                        local c = self.slot:GetNamedChild(name)
                        if c then
                            c:SetAlpha(0)
                            if c.SetHidden then c:SetHidden(true) end
                        end
                    end
                end
            end
        end)
    end

    InstallBounceHook()
    InstallActivationHighlightHook()
    ExposeStudioApi()
    BuildMenu()
    RegisterEvents()

    -- kompletter status-dump im chat
    local function PrintDebugDump()
        local head = "|ca970ff"
        local key  = "|c8a7fa6"
        local on   = "|c6fd66f"
        local off  = "|cd64f4f"
        local val  = "|cc8a8ff"
        local e    = "|r"

        local function yn(b)
            local txt = b and GetString(SI_AAB_DBG_ON) or GetString(SI_AAB_DBG_OFF)
            return (b and on or off) .. txt .. e
        end
        local function v(x) return val .. tostring(x) .. e end
        local function lbl(id) return key .. GetString(id) .. ": " .. e end

        d(head .. "=== " .. ADDON_NAME .. " ===" .. e)

        d(key .. GetString(SI_AAB_DBG_FRAME) .. e)
        d("  " .. lbl(SI_AAB_DBG_THINFRAME) .. yn(sv.thinFrameEnabled))
        d("  " .. lbl(SI_AAB_DBG_STYLE) .. v(sv.edgeStyle) .. "  " .. lbl(SI_AAB_DBG_TEMPLATE) .. v(GetEdgeTemplate()))
        d("  " .. lbl(SI_AAB_DBG_ALPHA) .. v(sv.frameAlpha))

        d(key .. GetString(SI_AAB_DBG_BOUNCE) .. e)
        d("  " .. lbl(SI_AAB_DBG_ACTIVE) .. yn(sv.bounceEnabled) .. "  " .. lbl(SI_AAB_DBG_STYLE) .. v(sv.animationStyle))
        d("  " .. lbl(SI_AAB_DBG_ONPROC) .. yn(sv.bounceOnProc) .. "  " .. lbl(SI_AAB_DBG_ULTI) .. yn(sv.ultBounceEnabled))
        d("  " .. lbl(SI_AAB_DBG_QUICKSLOT) .. yn(sv.quickslotBounceEnabled) .. "  " .. lbl(SI_AAB_DBG_QS_READY) .. yn(sv.quickslotReadyEnabled))
        d("  " .. lbl(SI_AAB_DBG_EXPIRE) .. yn(sv.expireAnimEnabled) .. "  " .. lbl(SI_AAB_DBG_STYLE) .. v(ResolveExpireStyle()))

        d(key .. GetString(SI_AAB_DBG_GLOWPULSE) .. e)
        d("  " .. lbl(SI_AAB_DBG_GLOW) .. yn(sv.glowEnabled) .. "  " .. lbl(SI_AAB_DBG_PULSE) .. yn(sv.pulseEnabled))
        d("  " .. lbl(SI_AAB_DBG_PULSEMODE) .. v(sv.pulseMode) .. "  " .. lbl(SI_AAB_DBG_COLORCYCLE) .. yn(sv.colorCycleEnabled))
        d("  " .. lbl(SI_AAB_DBG_VANILLAPROC) .. yn(sv.vanillaProcGlow))

        d(key .. GetString(SI_AAB_DBG_ULTFRAME) .. e)
        d("  " .. lbl(SI_AAB_DBG_STYLE) .. v(sv.ultBorderStyle))
        if sv.ultBorderStyle == "controller" then
            local pct = 0
            local cost = GetUltCost()
            if cost > 0 then pct = (GetUnitPower("player", POWERTYPE_ULTIMATE) / cost) end
            local shown = (ultCtrl and ultCtrl.fill.BL and not ultCtrl.fill.BL:IsHidden()) and true or false
            d("  " .. lbl(SI_AAB_DBG_PROGRESS) .. v(string.format("%.0f%%", pct * 100))
                .. "  " .. lbl(SI_AAB_DBG_BORDER) .. (shown and (on .. GetString(SI_AAB_DBG_VISIBLE) .. e) or (off .. GetString(SI_AAB_DBG_OFF) .. e)))
            d("  " .. lbl(SI_AAB_DBG_TEXTURE) .. v(sv.ultCtrlStyle)
                .. "  " .. lbl(SI_AAB_DBG_THICKNESS) .. v(tostring(sv.ultCtrlThickness))
                .. "  " .. lbl(SI_AAB_DBG_PADDING) .. v(tostring(sv.ultCtrlPadding)))
            d("  " .. lbl(SI_AAB_DBG_COLORSHIFT) .. yn(sv.ultCtrlColorShift)
                .. "  " .. lbl(SI_AAB_DBG_FULLGLOW) .. yn(sv.ultCtrlGlowOnFull)
                .. "  " .. lbl(SI_AAB_DBG_GLOWSTYLE) .. v(sv.ultCtrlGlowStyle))
            d("  " .. lbl(SI_AAB_DBG_RAINBOW) .. yn(sv.ultCtrlRainbow))
        end
        d("  " .. lbl(SI_AAB_DBG_READY) .. yn(sv.ultReadyEnabled) .. "  " .. lbl(SI_AAB_DBG_PULSE) .. yn(sv.ultReadyPulse))
        d("  " .. lbl(SI_AAB_DBG_MODE) .. v(sv.ultReadyMode) .. "  " .. lbl(SI_AAB_DBG_COLORCYCLE) .. yn(sv.ultColorCycleEnabled))
        if sv.ultReadyMode == "smooth-rainbow" then
            d("  " .. lbl(SI_AAB_DBG_RAINBOW_SAT) .. v(sv.ultRainbowSaturation) .. "  " .. lbl(SI_AAB_DBG_RAINBOW_LIGHT) .. v(sv.ultRainbowLightness))
        end
        d("  " .. lbl(SI_AAB_DBG_VANILLASHIMMER) .. yn(sv.vanillaUltShimmer))
        d("  " .. lbl(SI_AAB_UI_HDR_ULTGP) .. yn(sv.ultGpFrameEnabled))

        d(lbl(SI_AAB_DBG_SERVER) .. v(GetWorldName()))

        d(key .. GetString(SI_AAB_SUB_PERF) .. e)
        d("  " .. lbl(SI_AAB_PERF_EFFECTID) .. yn(sv.perfEffectIdFilter)
            .. "  " .. lbl(SI_AAB_PERF_SLOTMAP) .. yn(sv.perfSlotLookupMap))
        d("  " .. lbl(SI_AAB_PERF_COMBAT) .. yn(sv.perfCombatOnly)
            .. "  " .. lbl(SI_AAB_PERF_RAINBOW) .. yn(sv.perfSlowRainbow))
        d("  " .. lbl(SI_AAB_PERF_STYLEHOOK) .. yn(sv.perfSingleStyleHook)
            .. "  " .. lbl(SI_AAB_PERF_TLCACHE) .. yn(sv.perfLimitTimelineCache))
        d(head .. "=============================" .. e)
    end

    local function OpenPanel()
        if LibAddonMenu2 and LibAddonMenu2.OpenToPanel then
            LibAddonMenu2:OpenToPanel(_G[ADDON_NAME .. "Panel"])
        else
            OpenStudio()
        end
    end

    -- öffnet das panel und klappt direkt das info-submenu auf. LAM baut die
    -- controls erst beim ersten öffnen, daher kurz warten und dann aufklappen
    local function OpenInfo()
        OpenPanel()
        zo_callLater(function()
            local sub = _G[ADDON_NAME .. "InfoSubmenu"]
            -- .open ist der aufklapp-status des submenus. nur öffnen wenn zu,
            -- ein zweiter aufruf würde es sonst wieder zuklappen
            if sub and sub.open == false and sub.OnClicked then
                sub:OnClicked()
            end
        end, 100)
    end

    -- ein einziger einstieg mit sub-befehlen. args wird an leerzeichen getrennt.
    local function Dispatch(args)
        args = args or ""
        local cmd, a1, a2 = args:match("^%s*(%S*)%s*(%S*)%s*(%S*)")
        cmd = (cmd or ""):lower()

        if cmd == "" then
            OpenPanel()
        elseif cmd == "info" then
            OpenInfo()
        elseif cmd == "ui" or cmd == "studio" then
            OpenStudio(a1 ~= "" and a1 or nil)
        elseif cmd == "id" or cmd == "ids" then
            PrintSlottedIds()
        elseif cmd == "setend" then
            SetExpireOverride(a1, a2)
        elseif cmd == "debug" then
            PrintDebugDump()
        elseif cmd == "track" or cmd == "trace" then
            ToggleExpireTrace()
        elseif cmd == "conflicts" then
            PrintConflicts()
        elseif cmd == "xyz" then
            local studio = AnimatedActionBarPlus and AnimatedActionBarPlus.Studio
            if studio and studio.ToggleForcedGamepad then studio.ToggleForcedGamepad() end
        elseif cmd == "dialog" then
            -- versteckter test-befehl: hinweis-dialog erzwingen, auch wenn
            -- er schon bestätigt wurde. bewusst nicht in der hilfe gelistet
            ShowInfoDialog(true)
        elseif cmd == "cmd" or cmd == "commands" or cmd == "?" then
            PrintCommandHelp()
        else
            PrintCommandHelp()
        end
    end

    SLASH_COMMANDS["/animatedactionbarplus"] = OpenPanel
    SLASH_COMMANDS["/aab"] = Dispatch

    -- öffentliche api, damit andere addons (oder /script) die befehle direkt
    -- aufrufen können statt über den chat-parser
    AnimatedActionBarPlus = AnimatedActionBarPlus or {}
    AnimatedActionBarPlus.OpenPanel        = OpenPanel
    AnimatedActionBarPlus.OpenInfo         = OpenInfo
    AnimatedActionBarPlus.OpenStudio       = OpenStudio
    AnimatedActionBarPlus.PrintSlottedIds  = PrintSlottedIds
    AnimatedActionBarPlus.SetExpireLength  = SetExpireOverride  -- (idStr, "ms"|"auto")
    AnimatedActionBarPlus.PrintDebug       = PrintDebugDump
    AnimatedActionBarPlus.PrintCommands    = PrintCommandHelp
    AnimatedActionBarPlus.RunCommand       = Dispatch           -- roher "id", "setend", ...
    AnimatedActionBarPlus.version          = ADDON_VERSION

    -- kurze aliase fürs chat-tab-complete
    SLASH_COMMANDS["/aabids"]   = function() PrintSlottedIds() end
    SLASH_COMMANDS["/aabcmds"]  = function() PrintCommandHelp() end

    zo_callLater(function()
        RefreshAllProcs()
        RefreshProcGlowSuppression()
        ApplyFrameAlpha()
        ApplyEdgeTexture()
        CheckUltimateReady()
        SuppressVanillaUltGlow()
        if sv.ultBorderStyle == "controller" then
            ShowCtrlBorder()  -- beim login die eigene fortschritts-border aufsetzen
        end
        GpUlt.Refresh()
        -- lookup-map einmal bauen falls schon beim laden aktiv
        if sv.perfSlotLookupMap and RebuildSlotLookup then RebuildSlotLookup() end
        QS.Sync()

        -- einmaliger hinweis-dialog. etwas später, damit er nicht in den
        -- lade-screen platzt sondern erst wenn der spieler wirklich im spiel ist
        zo_callLater(function() ShowInfoDialog(false) end, 2000)
    end, 500)
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
