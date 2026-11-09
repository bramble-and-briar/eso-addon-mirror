--[[
    Weyland Huntsman's Warmask Tracker
    Tracks the "Mark of Hircine" (Huntsman's Warmask, mythic) on your target.

    Design:
      * Mark tracking is active only while the mask is worn.
      * The mask is re-checked on every worn-slot change (boss gear swaps, Armory).
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
-- Language files load first and place their strings on this single add-on table.
local HMK = _G[ADDON] or {}
HMK.Strings = HMK.Strings or {}
local STRINGS = HMK.Strings
local function T(key) return STRINGS[key] or key end

HMK.name = ADDON
HMK.version = "1.0.0"
HMK.active = false   -- mask equipped right now
HMK.unlocked = false -- move mode (not saved)

local EM = EVENT_MANAGER
local MARK_OF_HIRCINE_ABILITY_ID = 252048 -- Huntsman's Warmask mark

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
-- White art on a transparent background: the icon colour is multiplied with the white,
-- so every icon takes ANY colour chosen in the settings.
local ICONS = {
    { id = "wolf", label = T("ICON_WOLF"),       path = ADDON .. "/textures/huntsman_wolf.dds" },
    { id = "stag", label = T("ICON_STAG"), path = ADDON .. "/textures/huntsman_stag.dds" },
    { id = "paw",  label = T("ICON_PAW"),   path = ADDON .. "/textures/huntsman_paw.dds" },
    { id = "boar",    label = T("ICON_BOAR"),     path = ADDON .. "/textures/huntsman_boar.dds" },
    { id = "raven",   label = T("ICON_RAVEN"),     path = ADDON .. "/textures/huntsman_raven.dds" },
    { id = "bear",    label = T("ICON_BEAR"),    path = ADDON .. "/textures/huntsman_bear.dds" },
    { id = "braid",   label = T("ICON_BRAID"), path = ADDON .. "/textures/huntsman_braid.dds" },
    { id = "arrow",   label = T("ICON_ARROW"), path = ADDON .. "/textures/huntsman_arrow.dds" },
    { id = "thorn",   label = T("ICON_THORN"),     path = ADDON .. "/textures/huntsman_thorn.dds" },
    { id = "triple",  label = T("ICON_TRIPLE"),     path = ADDON .. "/textures/huntsman_triple.dds" },
    { id = "hircine", label = T("ICON_HIRCINE"),  path = ADDON .. "/textures/huntsman_hircine.dds" },
    { id = "beast",   label = T("ICON_BEAST"),   path = ADDON .. "/textures/huntsman_beast.dds" },
}
-- Shared safe crop measured from the union of all icon alpha bounds (256x256 DDS).
-- The two-pixel safety margin keeps antialiased edges intact and preserves one aspect ratio.
local ICON_U_LEFT, ICON_U_RIGHT = 7 / 256, 249 / 256
local ICON_V_TOP, ICON_V_BOTTOM = 7 / 256, 249 / 256

local FONT_DIR     = ADDON .. "/fonts/"

local FONTS = {
    { id = "Cinzel-Regular",   label = "Cinzel Regular",   path = FONT_DIR .. "Cinzel-Regular.slug" },
    { id = "Cinzel-Medium",    label = "Cinzel Medium",    path = FONT_DIR .. "Cinzel-Medium.slug" },
    { id = "Cinzel-SemiBold",  label = "Cinzel SemiBold",  path = FONT_DIR .. "Cinzel-SemiBold.slug" },
    { id = "Cinzel-Bold",      label = "Cinzel Bold",      path = FONT_DIR .. "Cinzel-Bold.slug" },
    { id = "Cinzel-ExtraBold", label = "Cinzel ExtraBold", path = FONT_DIR .. "Cinzel-ExtraBold.slug" },
    { id = "Cinzel-Black",     label = "Cinzel Black",     path = FONT_DIR .. "Cinzel-Black.slug" },
    { id = "ESO-Bold",         label = "ESO Bold (game default)", path = "$(BOLD_FONT)" },
}

-- ESO addons cannot play their own audio files, only the game's built-in sounds.
-- Candidates that do not exist in the running client are skipped automatically.
local SOUND_CANDIDATES = {
    { id = "DUEL_START",          label = T("SOUND_DUEL_START") },
    { id = "GUILD_ROSTER_ADDED",  label = T("SOUND_GUILD_JOIN") },
}

local function AvailableSounds()
    local list = {}
    if type(SOUNDS) ~= "table" then return list end
    for _, snd in ipairs(SOUND_CANDIDATES) do
        if SOUNDS[snd.id] then list[#list + 1] = snd end
    end
    return list
end

local function PlayWarnSound(id)
    if type(SOUNDS) == "table" and SOUNDS[id] then PlaySound(SOUNDS[id]) end
end

local OUTLINES = {
    { id = "none",             label = T("OUTLINE_NONE"),         value = "" },
    { id = "soft-shadow-thin", label = T("OUTLINE_SOFT_THIN"),  value = "soft-shadow-thin" },
    { id = "soft-shadow-thick",label = T("OUTLINE_SOFT_THICK"), value = "soft-shadow-thick" },
    { id = "thick-outline",    label = T("OUTLINE_THICK"), value = "thick-outline" },
}

-- Slots that may hold the mask (it is a headpiece, but scanning armor+jewelry is cheap).
local SCAN_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_HAND, EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
}

local DEFAULTS = {
    mark = {
        size      = 64,
        icon      = "wolf",                                 -- see ICONS
        color     = { r = 1, g = 1, b = 1, a = 1 },        -- icon tint
        x         = 0,                                      -- offset of icon centre from screen centre
        y         = 0,
        positionValid = false,                              -- true only after the player saves a real window position
        timerMode = "edge",                                 -- "inside" | "edge" (half over the icon's bottom edge) | "hidden"
        timerOffsetY = 0,                                   -- fine tuning of the timer, + = down
        font      = "Cinzel-Bold",
        fontSize  = 24,
        outline   = "soft-shadow-thick",
        timerColor = { r = 1, g = 0.85, b = 0.3, a = 1 },
        tenths    = true,                                   -- show 4.2 instead of 5 under 5 s
        warnEnabled   = true,                               -- recolor when the mark is about to expire
        warnSeconds   = 15,
        warnColor     = { r = 1, g = 0.1, b = 0.1, a = 1 },
        warnIcon      = true,
        warnTimer     = false,
        soundEnabled  = true,                               -- play a sound when the warning time is reached
        soundInterval = 1,                                  -- 0 = once, otherwise repeat every N seconds until refreshed/ended
        sound         = "DUEL_START",                       -- see SOUND_CANDIDATES
    },
    markIds   = {},     -- learned / manual ability ids of the mark
    extraName = "",     -- legacy fallback name; the built-in ability ID is language-independent
    maskSetId = 0,      -- learned set id of the mask (0 = unknown)
}

local sv  -- saved variables, set in OnAddOnLoaded

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Msg(text)
    d("|c9ad0ff[WarmaskTracker]|r " .. tostring(text))
end

local function CleanName(name)
    if not name then return "" end
    return (zo_strlower((name:gsub("%^.*$", ""))))
end

local function FindById(list, id)
    for _, v in ipairs(list) do
        if v.id == id then return v end
    end
    return list[1]
end

local function HasId(list, id)
    for _, v in ipairs(list) do
        if v.id == id then return true end
    end
    return false
end

local function IconPath(cfg)
    return FindById(ICONS, cfg.icon).path
end

-- Timer placement, shared by the HUD element and the settings preview.
--   inside : centred on the icon
--   edge   : centred horizontally, its vertical middle sits on the icon's bottom edge,
--            so the digits climb onto the icon by half of their height
local function AnchorTimer(timer, icon, cfg, scale)
    timer:ClearAnchors()
    local dy = (cfg.timerOffsetY or 0) * scale
    if cfg.timerMode == "edge" then
        timer:SetAnchor(CENTER, icon, BOTTOM, 0, dy)
    else
        timer:SetAnchor(CENTER, icon, CENTER, 0, dy)
    end
end

local function BuildFont(fontId, size, outlineId)
    local f = FindById(FONTS, fontId)
    local o = FindById(OUTLINES, outlineId)
    if o.value == "" then
        return string.format("%s|%d", f.path, size)
    end
    return string.format("%s|%d|%s", f.path, size, o.value)
end

-- One lightweight view implementation is shared by the HUD and the LAM preview.
local function CreateMarkView(parent)
    local icon = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    icon:SetAnchorFill(parent)
    icon:SetTextureCoords(ICON_U_LEFT, ICON_U_RIGHT, ICON_V_TOP, ICON_V_BOTTOM)

    local timer = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return { icon = icon, timer = timer }
end

local function ApplyViewStyle(view, cfg, scale)
    scale = scale or 1
    view.icon:SetTexture(IconPath(cfg))
    view.icon:SetTextureCoords(ICON_U_LEFT, ICON_U_RIGHT, ICON_V_TOP, ICON_V_BOTTOM)
    view.timer:SetFont(BuildFont(cfg.font, math.max(8, zo_round(cfg.fontSize * scale)), cfg.outline))
    AnchorTimer(view.timer, view.icon, cfg, scale)
end

local function ApplyViewColors(view, cfg, warning)
    local iconColor = (warning and cfg.warnIcon) and cfg.warnColor or cfg.color
    local timerColor = (warning and cfg.warnTimer) and cfg.warnColor or cfg.timerColor
    view.icon:SetColor(iconColor.r, iconColor.g, iconColor.b, iconColor.a)
    view.timer:SetColor(timerColor.r, timerColor.g, timerColor.b, timerColor.a)
end

local function NowSec()
    return GetGameTimeSeconds()
end

-- true while the HUD element should be forced visible and draggable in move mode (/hmark)
local function Editing()
    return HMK.unlocked
end

---------------------------------------------------------------------------
-- UI: movable windows
---------------------------------------------------------------------------
local ui = {}

local function ApplyPosition(win, cfg)
    win:ClearAnchors()
    win:SetAnchor(CENTER, GuiRoot, CENTER, cfg.x, cfg.y)
end

local function SavePosition(win, cfg)
    local left, top = win:GetLeft(), win:GetTop()
    local width, height = win:GetWidth(), win:GetHeight()
    if type(left) ~= "number" or type(top) ~= "number"
        or type(width) ~= "number" or type(height) ~= "number" then
        return false
    end
    local cx = left + width / 2
    local cy = top + height / 2
    cfg.x = zo_round(cx - GuiRoot:GetWidth() / 2)
    cfg.y = zo_round(cy - GuiRoot:GetHeight() / 2)
    cfg.positionValid = true
    ApplyPosition(win, cfg)   -- re-anchor to CENTER so saved values match
    return true
end

-- A container window that is registered with the HUD scenes (so it hides in menus).
-- Visibility of the real content is controlled by win.content, because the scene
-- fragment owns the visibility of the window itself.
local function CreateWindow(suffix, cfgGetter)
    local win = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "_" .. suffix)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(false)
    win:SetMovable(false)

    local content = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    content:SetAnchorFill(win)
    content:SetHidden(true)
    win.content = content

    win:SetHandler("OnMoveStop", function(self)
        SavePosition(self, cfgGetter())
    end)

    local fragment = ZO_SimpleSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    win.fragment = fragment

    return win
end

local function CreateUI()
    -- Mark icon + timer
    local mark = CreateWindow("MarkWin", function() return sv.mark end)

    mark.view = CreateMarkView(mark.content)
    mark.icon = mark.view.icon
    mark.timer = mark.view.timer

    -- A gold outline is always shown in move mode, even if the icon itself is transparent.
    local frame = WINDOW_MANAGER:CreateControl(nil, mark.content, CT_CONTROL)
    frame:SetAnchorFill(mark.content)
    frame:SetMouseEnabled(false)
    frame:SetDrawLevel(20)
    frame:SetHidden(true)
    local top = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    top:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    top:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, 0)
    top:SetHeight(2)
    top:SetColor(1, 0.78, 0.22, 1)
    local bottom = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    bottom:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    bottom:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    bottom:SetHeight(2)
    bottom:SetColor(1, 0.78, 0.22, 1)
    local left = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    left:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    left:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    left:SetWidth(2)
    left:SetColor(1, 0.78, 0.22, 1)
    local right = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    right:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, 0)
    right:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    right:SetWidth(2)
    right:SetColor(1, 0.78, 0.22, 1)
    mark.frame = frame

    -- shown only in move mode, so you never have to remember the command
    local hint = WINDOW_MANAGER:CreateControl(nil, mark.content, CT_LABEL)
    hint:SetFont("ZoFontGameBold")
    hint:SetColor(1, 0.82, 0.3, 1)
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetAnchor(BOTTOM, mark.content, TOP, 0, -6)
    hint:SetText(T("MOVE_HINT"))
    hint:SetHidden(true)
    mark.hint = hint
    ui.mark = mark

end

---------------------------------------------------------------------------
-- Mark state
---------------------------------------------------------------------------
local state = {
    active    = false,
    endTime   = 0,
    unitId    = nil,
    unitName  = nil,
    beginTime = nil,     -- exact start time identifies this application when NPC names are duplicated
    appliedAt = 0,       -- last time the mark was (re)applied; used to ignore stale FADED events
}

local TICK_NAME = ADDON .. "_Tick"

local function FormatTimer(remaining)
    if remaining < 0 then remaining = 0 end
    if sv.mark.tenths and remaining <= 5 then
        return string.format("%.1f", remaining)
    end
    -- Floor to whole seconds remaining instead of rounding up. The tiny epsilon
    -- also prevents an exact 60.0-second event timestamp from flashing "60".
    return tostring(math.max(0, math.floor(remaining - 0.001)))
end

local function UpdateMarkVisibility()
    local m = ui.mark
    if not m then return end
    -- The marker is always visible while our mark is active. It is cleared only
    -- when the effect expires, is removed, or the tracked target dies.
    -- Move mode also forces visibility so the icon can be positioned.
    local show = HMK.unlocked or state.active
    m.content:SetHidden(not show)
    m.frame:SetHidden(not HMK.unlocked)
    m.hint:SetHidden(not HMK.unlocked)
end

local function UpdateTimerText()
    local m = ui.mark
    local cfg = sv.mark
    if cfg.timerMode == "hidden" then
        m.timer:SetHidden(true)
        return
    end
    m.timer:SetHidden(false)
    if state.active then
        m.timer:SetText(FormatTimer(state.endTime - NowSec()))
    elseif Editing() then
        m.timer:SetText("59")
    else
        m.timer:SetText("")
    end
end

local warnShown = false   -- warning colour currently applied
local soundDone = false   -- one-shot mode: the sound already played for this application of the mark
local lastSoundAt = nil   -- repeat mode: when the sound last played

-- Warning sound. Starts when the remaining time drops to the warning limit and
--   * repeat mode: plays every soundInterval seconds until the mark is refreshed (time goes back above the limit) or ends;
--   * one-shot mode: plays once and re-arms when the mark is refreshed.
local function CheckWarnSound(remaining)
    local cfg = sv.mark
    if remaining > cfg.warnSeconds then
        soundDone, lastSoundAt = false, nil
        return
    end
    if not cfg.soundEnabled then return end
    local now = NowSec()
    local interval = cfg.soundInterval or 0
    if interval > 0 then
        if not lastSoundAt or now - lastSoundAt >= interval then
            lastSoundAt = now
            PlayWarnSound(cfg.sound)
        end
    elseif not soundDone then
        soundDone = true
        PlayWarnSound(cfg.sound)
    end
end

local function ApplyMarkColors()
    local m, cfg = ui.mark, sv.mark
    if not m then return end
    local warn = false
    if cfg.warnEnabled and state.active then
        warn = (state.endTime - NowSec()) <= cfg.warnSeconds
    end
    warnShown = warn
    ApplyViewColors(m.view, cfg, warn)
end

local function ApplyMarkStyle()
    local m, cfg = ui.mark, sv.mark
    if not m then return end

    m:SetDimensions(cfg.size, cfg.size)
    ApplyPosition(m, cfg)

    ApplyViewStyle(m.view, cfg, 1)
    ApplyMarkColors()

    UpdateTimerText()
    UpdateMarkVisibility()
    if HMK.RefreshPanelWidgets then HMK.RefreshPanelWidgets() end
end

local TrackedTargetIsDead   -- defined below, once CurrentReticleMatches exists

local function OnTick()
    if not state.active then return end
    local remaining = state.endTime - NowSec()
    if remaining <= 0 then
        HMK.ClearMark()
        return
    end
    -- Safety net: if no death event reached the addon (e.g. someone else killed the target),
    -- a dead body under the reticle still stops the timer.
    if TrackedTargetIsDead() then
        HMK.ClearMark()
        return
    end
    UpdateTimerText()
    CheckWarnSound(remaining)
    local warn = sv.mark.warnEnabled and remaining <= sv.mark.warnSeconds
    if warn ~= warnShown then ApplyMarkColors() end
end

local function SetMark(endTime, unitId, unitName, beginTime)
    if unitId == 0 then unitId = nil end -- zero means the API supplied no usable unit ID
    -- Preserve an earlier ID only when the exact same effect application is confirmed.
    -- A matching NPC name alone is not enough: several identical mobs can be alive at once.
    if unitId == nil and state.active and state.unitName == unitName
        and type(state.beginTime) == "number" and type(beginTime) == "number"
        and math.abs(state.beginTime - beginTime) <= 0.05 then
        unitId = state.unitId
    end
    state.active   = true
    state.endTime  = endTime
    state.beginTime = beginTime
    state.appliedAt = NowSec()
    state.unitId   = unitId
    state.unitName = unitName
    EM:UnregisterForUpdate(TICK_NAME)
    EM:RegisterForUpdate(TICK_NAME, 100, OnTick)
    CheckWarnSound(endTime - NowSec())
    ApplyMarkColors()
    UpdateTimerText()
    UpdateMarkVisibility()
end

function HMK.ClearMark()
    state.active    = false
    state.unitId    = nil
    state.unitName  = nil
    state.beginTime = nil
    soundDone, lastSoundAt = false, nil
    EM:UnregisterForUpdate(TICK_NAME)
    if ui.mark then
        ApplyMarkColors()
        UpdateTimerText()
        UpdateMarkVisibility()
    end
end

---------------------------------------------------------------------------
-- Recognising the mark effect
---------------------------------------------------------------------------
local function IsMarkAbility(abilityId, name)
    -- Built-in ID is reliable across client languages and effect-name changes.
    if tonumber(abilityId) == MARK_OF_HIRCINE_ABILITY_ID then return true end
    if abilityId and sv.markIds[abilityId] then return true end
    local n = CleanName(name)
    if n == "" then return false end
    local matched = n:find("mark of hircine", 1, true) ~= nil
    if not matched and sv.extraName ~= "" then
        matched = (n == CleanName(sv.extraName))
    end
    if matched and abilityId and abilityId > 0 then
        sv.markIds[abilityId] = true -- remember the ID for next time
    end
    return matched
end

local function SameEffectStart(first, second)
    return type(first) == "number" and type(second) == "number"
        and math.abs(first - second) <= 0.05
end

local function SameTrackedUnit(unitId, unitName, beginTime)
    if not state.active then return false end

    local trackedId = tonumber(state.unitId)
    local eventId = tonumber(unitId)
    -- When both sides expose an ID, it is authoritative.
    if trackedId and trackedId ~= 0 and eventId and eventId ~= 0 then
        return trackedId == eventId
    end

    -- Some event variants omit the ID. In that case, require BOTH the same
    -- normalized NPC name and the exact start time of this effect application.
    -- Name-only matching is unsafe because several identical mobs can coexist.
    local expected = CleanName(state.unitName)
    local actual = CleanName(unitName)
    return expected ~= "" and actual ~= "" and expected == actual
        and SameEffectStart(state.beginTime, beginTime)
end

local function CurrentReticleMatches(unitName)
    if not DoesUnitExist("reticleover") then return false end
    local currentName = CleanName(GetUnitName("reticleover"))
    local effectName = CleanName(unitName)
    return currentName ~= "" and effectName ~= "" and currentName == effectName
end

-- True when the unit under the reticle is a dead body AND it is the target we are tracking.
-- GetUnitBuffInfo exposes castByPlayer as its final return value. This is the
-- authoritative fallback when EVENT_EFFECT_CHANGED reports sourceType == NONE.
-- Never treat NONE as proof that the effect belongs to this player.
local function OwnMarkExpiryOnUnit(unitTag)
    if not unitTag or unitTag == "" or not DoesUnitExist(unitTag) then return nil end
    for i = 1, GetNumBuffs(unitTag) do
        local name, timeStarted, timeEnding, _, _, _, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, i)
        if castByPlayer == true and IsMarkAbility(abilityId, name) then
            local expiry = timeEnding
            if type(expiry) ~= "number" or expiry <= NowSec() then
                expiry = NowSec() + 60
            end
            return expiry, timeStarted
        end
    end
    return nil
end

-- Resolve the effect's target tag. Some effect events omit unitTag; in that
-- case we can only verify ownership if the named target is the current reticle.
TrackedTargetIsDead = function()
    if not state.active or not DoesUnitExist("reticleover") then return false end
    if not (IsUnitDead and IsUnitDead("reticleover")) then return false end
    if not CurrentReticleMatches(state.unitName) then return false end
    local _, beginTime = OwnMarkExpiryOnUnit("reticleover")
    return SameEffectStart(state.beginTime, beginTime)
end

local function OwnMarkExpiryForEvent(unitTag, unitName, eventBeginTime)
    local expiry, startedAt = OwnMarkExpiryOnUnit(unitTag)
    if expiry then
        if eventBeginTime and startedAt and not SameEffectStart(eventBeginTime, startedAt) then return nil end
        return expiry, startedAt
    end

    if unitTag ~= "reticleover" and DoesUnitExist("reticleover")
        and CurrentReticleMatches(unitName) then
        expiry, startedAt = OwnMarkExpiryOnUnit("reticleover")
        if expiry and (not eventBeginTime or not startedAt or SameEffectStart(eventBeginTime, startedAt)) then
            return expiry, startedAt
        end
    end
    return nil
end

-- Looks for our own mark among the buffs of the current target; returns its expiry or nil.
local function ReticleMarkExpiry()
    if not DoesUnitExist("reticleover") then return nil end
    -- A corpse can still list the mark for a moment. A dead target is never "marked".
    if IsUnitDead and IsUnitDead("reticleover") then return nil end
    return OwnMarkExpiryOnUnit("reticleover")
end

-- Reconcile what is on the current target. Effect events below are the primary source;
-- this scan is a fallback for an effect that was already active before targeting it.
local function ScanReticle()
    if not HMK.active then return end
    if TrackedTargetIsDead() then
        HMK.ClearMark()
        return
    end
    local targetExists = DoesUnitExist("reticleover")
    local targetName = targetExists and GetUnitName("reticleover") or ""
    local expiry, beginTime = ReticleMarkExpiry()
    if expiry then
        SetMark(expiry, nil, targetName, beginTime)
    end

    if not expiry then
        -- Looking away from the marked target does not hide or clear its marker.
        UpdateMarkVisibility()
    end
end

local function OnEffectChanged(_, changeType, _, effectName, unitTag, beginTime, endTime, _, _, _, _, _, _, unitName, unitId, abilityId, sourceType)
    if unitId == 0 then unitId = nil end
    if not IsMarkAbility(abilityId, effectName) then return end

    local isOwnSource = sourceType == COMBAT_UNIT_TYPE_PLAYER
    local sourceIsUnknown = sourceType == COMBAT_UNIT_TYPE_NONE

    -- Group members, other players, pets and NPCs are never accepted. NONE is
    -- ambiguous, so it is accepted only when GetUnitBuffInfo confirms castByPlayer.
    if not isOwnSource and not sourceIsUnknown then return end

    local effectTargetName = unitName
    if (not effectTargetName or effectTargetName == "") and unitTag == "reticleover"
        and DoesUnitExist("reticleover") then
        effectTargetName = GetUnitName("reticleover")
    end

    if changeType == EFFECT_RESULT_FADED then
        if not SameTrackedUnit(unitId, effectTargetName, beginTime) then return end

        -- NONE cannot identify the source of a faded event. Re-check the live
        -- target buff list after the event: keep/refresh our mark if castByPlayer
        -- is still true; otherwise remove the mark we were tracking.
        if sourceIsUnknown then
            local fadedAt = NowSec()
            local fadedUnitId, fadedName, fadedTag, fadedBeginTime = unitId, effectTargetName, unitTag, beginTime
            zo_callLater(function()
                if not SameTrackedUnit(fadedUnitId, fadedName, fadedBeginTime) then return end
                if state.appliedAt >= fadedAt - 0.3 then return end
                local remainingExpiry, remainingBeginTime = OwnMarkExpiryForEvent(fadedTag, fadedName, fadedBeginTime)
                if remainingExpiry then
                    SetMark(remainingExpiry, fadedUnitId, fadedName, remainingBeginTime or fadedBeginTime)
                else
                    HMK.ClearMark()
                end
            end, 150)
            return
        end

        -- Re-applying the mark makes ESO send FADED (old) and GAINED (new)
        -- together, in either order. A FADED describing the older application is stale.
        if type(endTime) == "number" and endTime > 0 and state.endTime > endTime + 1 then return end

        local fadedAt = NowSec()
        if unitTag == "reticleover" then
            -- Reticle reuse can produce a FADED event without the debuff actually
            -- expiring. Wait briefly and clear only if the same mark is still gone.
            local fadedUnitId, fadedName, fadedBeginTime = unitId, effectTargetName, beginTime
            zo_callLater(function()
                if not (SameTrackedUnit(fadedUnitId, fadedName, fadedBeginTime) and CurrentReticleMatches(fadedName)) then return end
                if state.appliedAt >= fadedAt - 0.3 then return end
                if ReticleMarkExpiry() then ScanReticle() return end
                HMK.ClearMark()
            end, 150)
        else
            -- A non-reticle fade is the tracked effect ending, unless refreshed.
            if state.appliedAt >= fadedAt - 0.3 then return end
            HMK.ClearMark()
        end
        return
    end

    local expiry = endTime
    if sourceIsUnknown then
        -- The event's end time is not enough to establish ownership when its
        -- source is NONE. Use the actual active effect and its castByPlayer flag.
        local scannedBeginTime
        expiry, scannedBeginTime = OwnMarkExpiryForEvent(unitTag, effectTargetName, beginTime)
        if not expiry then return end
        beginTime = scannedBeginTime or beginTime
    elseif type(expiry) ~= "number" or expiry <= NowSec() then
        expiry = NowSec() + 60
    end

    if not effectTargetName or effectTargetName == "" then
        if unitTag ~= "reticleover" or not DoesUnitExist("reticleover") then return end
        effectTargetName = GetUnitName("reticleover") or ""
    end

    SetMark(expiry, unitId, effectTargetName, beginTime)
end

local function OnReticleTargetChanged()
    ScanReticle()
end

-- Safety net: if the addon lost the mark but the target still shows it (a missed or
-- reordered event), pick it up again without having to look away and back.
local RECONCILE_NAME = ADDON .. "_Reconcile"
local function Reconcile()
    if not state.active and HMK.active and DoesUnitExist("reticleover") then
        ScanReticle()
    end
end

local function OnUnitDeathStateChanged(_, unitTag, isDead)
    if isDead and state.active and unitTag == "reticleover" and TrackedTargetIsDead() then
        HMK.ClearMark()
    end
end

local function OnCombatDeath(_, _, _, _, _, _, _, _, targetName, _, _, _, _, _, _, targetUnitId)
    if not state.active then return end

    local deathId = tonumber(targetUnitId)
    local trackedId = tonumber(state.unitId)
    -- A name-only match can point at a different NPC with the same display name.
    -- Clear from combat death events only when both unit IDs identify the same entity.
    if not deathId or deathId == 0 or not trackedId or trackedId == 0 then return end
    if deathId == trackedId then HMK.ClearMark() end
end

local function OnPlayerDead()
    HMK.ClearMark()
end

---------------------------------------------------------------------------
-- Mask detection and ACTIVE / STANDBY switching
---------------------------------------------------------------------------
local function IsMaskSet(setName, setId)
    if sv.maskSetId ~= 0 and setId == sv.maskSetId then return true end
    local n = CleanName(setName)
    if n:find("huntsman", 1, true) and n:find("warmask", 1, true) then
        if setId and setId > 0 then sv.maskSetId = setId end   -- learn the id
        return true
    end
    return false
end

local function IsMaskEquipped()
    for _, slot in ipairs(SCAN_SLOTS) do
        local link = GetItemLink(BAG_WORN, slot)
        if link and link ~= "" then
            local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, true)
            if hasSet and IsMaskSet(setName, setId) then
                return true
            end
        end
    end
    return false
end

local function SetActive(on)
    if on == HMK.active then return end
    HMK.active = on

    if on then
        -- Keep unit/source filters open for ESO's inconsistent event tags, but filter
        -- by the single Mark of Hircine ability to avoid processing unrelated effects.
        EM:RegisterForEvent(ADDON .. "_Effect", EVENT_EFFECT_CHANGED, OnEffectChanged)
        EM:AddFilterForEvent(ADDON .. "_Effect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, MARK_OF_HIRCINE_ABILITY_ID)

        EM:RegisterForEvent(ADDON .. "_Reticle", EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)

        EM:RegisterForEvent(ADDON .. "_UnitDeath", EVENT_UNIT_DEATH_STATE_CHANGED, OnUnitDeathStateChanged)
        EM:AddFilterForEvent(ADDON .. "_UnitDeath", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")

        EM:RegisterForEvent(ADDON .. "_Died", EVENT_COMBAT_EVENT, OnCombatDeath)
        EM:AddFilterForEvent(ADDON .. "_Died", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED)
        EM:RegisterForEvent(ADDON .. "_DiedXP", EVENT_COMBAT_EVENT, OnCombatDeath)
        EM:AddFilterForEvent(ADDON .. "_DiedXP", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED_XP)

        EM:RegisterForEvent(ADDON .. "_PlayerDead", EVENT_PLAYER_DEAD, OnPlayerDead)
        EM:RegisterForUpdate(RECONCILE_NAME, 500, Reconcile)

        ScanReticle()
    else
        EM:UnregisterForEvent(ADDON .. "_Effect", EVENT_EFFECT_CHANGED)
        EM:UnregisterForEvent(ADDON .. "_Reticle", EVENT_RETICLE_TARGET_CHANGED)
        EM:UnregisterForEvent(ADDON .. "_UnitDeath", EVENT_UNIT_DEATH_STATE_CHANGED)
        EM:UnregisterForEvent(ADDON .. "_Died", EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent(ADDON .. "_DiedXP", EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent(ADDON .. "_PlayerDead", EVENT_PLAYER_DEAD)
        EM:UnregisterForUpdate(RECONCILE_NAME)
        HMK.ClearMark()
    end
end

local function RefreshMask()
    SetActive(IsMaskEquipped())
end

---------------------------------------------------------------------------
-- Move mode
---------------------------------------------------------------------------
local function ApplyLockState()
    local win = ui.mark
    win:SetMouseEnabled(HMK.unlocked == true)   -- dragging only in move mode
    win:SetMovable(HMK.unlocked == true)
    ApplyMarkStyle()
end

function HMK.SetMoveMode(on)
    on = on == true
    if HMK.unlocked == on then return end

    -- Invalidate any pending camera-UI callback from a previous toggle.
    HMK.moveModeGeneration = (HMK.moveModeGeneration or 0) + 1
    local generation = HMK.moveModeGeneration
    HMK.unlocked = on
    ApplyLockState()

    if on then
        SCENE_MANAGER:ShowBaseScene()
        zo_callLater(function()
            -- A quick second /hmark must not re-enable camera UI mode after turning it off.
            if HMK.unlocked and HMK.moveModeGeneration == generation then
                SetGameCameraUIMode(true)
            end
        end, 200)
        Msg(T("MOVE_ENABLED"))
    else
        SetGameCameraUIMode(false)
        SavePosition(ui.mark, sv.mark)
        Msg(T("MOVE_DISABLED"))
    end
end

---------------------------------------------------------------------------
-- Settings menu (LibAddonMenu-2.0)
---------------------------------------------------------------------------
local function FontChoices()
    local names, values = {}, {}
    for _, f in ipairs(FONTS) do names[#names + 1] = f.label; values[#values + 1] = f.id end
    return names, values
end

local function OutlineChoices()
    local names, values = {}, {}
    for _, o in ipairs(OUTLINES) do names[#names + 1] = o.label; values[#values + 1] = o.id end
    return names, values
end

---------------------------------------------------------------------------
-- Settings widgets: icon gallery + live preview (custom LAM controls)
---------------------------------------------------------------------------
local panelUI = {}   -- filled when LAM creates the controls (first time the panel is opened)

local GALLERY_THUMB, GALLERY_GAP, GALLERY_COLS = 92, 24, 4
local GALLERY_ROW_H = GALLERY_THUMB + 32
local GALLERY_ROWS = math.ceil(#ICONS / GALLERY_COLS)
local GALLERY_HEIGHT = 6 + GALLERY_ROWS * GALLERY_ROW_H
local PREVIEW_HEIGHT = 200
local PREVIEW_ICON_MAX = 100   -- the preview shrinks big icons so they fit the panel

local function HexColor(c)
    return string.format("%02X%02X%02X", zo_round(c.r * 255), zo_round(c.g * 255), zo_round(c.b * 255))
end

local function RefreshPanelWidgets()
    local cfg = sv and sv.mark
    if not cfg then return end
    local c = cfg.color

    local g = panelUI.gallery
    if g then
        for _, cell in ipairs(g.cells) do
            local selected = (cell.iconId == cfg.icon)
            if selected then
                cell.border:SetColor(1, 0.82, 0.3, 1)
                cell.label:SetColor(1, 0.82, 0.3, 1)
            elseif cell.hover then
                cell.border:SetColor(0.7, 0.7, 0.75, 1)
                cell.label:SetColor(0.9, 0.9, 0.9, 1)
            else
                cell.border:SetColor(0.3, 0.3, 0.35, 1)
                cell.label:SetColor(0.65, 0.65, 0.65, 1)
            end
            cell.art:SetColor(c.r, c.g, c.b, c.a)   -- every thumbnail shows the colour you picked
        end
    end

    local p = panelUI.preview
    if p then
        local scale = math.min(1, PREVIEW_ICON_MAX / cfg.size)
        local px = zo_round(cfg.size * scale)
        p.host:SetDimensions(px, px)
        ApplyViewStyle(p.view, cfg, scale)
        ApplyViewColors(p.view, cfg, false)
        p.timer:SetText("59")
        p.timer:SetHidden(cfg.timerMode == "hidden")

        local scaled = scale < 1 and string.format(T("PREVIEW_SCALE"), zo_round(scale * 100)) or ""
        p.info:SetText(string.format(T("PREVIEW_INFO"),
            FindById(ICONS, cfg.icon).label, cfg.size, scaled, HexColor(c), HexColor(c)))
    end
end
HMK.RefreshPanelWidgets = RefreshPanelWidgets

local function SelectIcon(id)
    sv.mark.icon = id
    ApplyMarkStyle()   -- also refreshes the widgets
end

local function CreateGallery(ctl)
    local wm = WINDOW_MANAGER
    local totalW = GALLERY_COLS * GALLERY_THUMB + (GALLERY_COLS - 1) * GALLERY_GAP
    local g = { cells = {} }

    for i, ic in ipairs(ICONS) do
        local cell = wm:CreateControl(nil, ctl, CT_CONTROL)
        cell:SetDimensions(GALLERY_THUMB, GALLERY_THUMB + 26)
        local col, row = (i - 1) % GALLERY_COLS, math.floor((i - 1) / GALLERY_COLS)
        cell:SetAnchor(TOPLEFT, ctl, TOP, -totalW / 2 + col * (GALLERY_THUMB + GALLERY_GAP), 6 + row * GALLERY_ROW_H)
        cell:SetMouseEnabled(true)
        cell.iconId = ic.id
        cell.hover = false

        -- no texture file = solid colour: a border square with a darker square inside it
        local border = wm:CreateControl(nil, cell, CT_TEXTURE)
        border:SetDimensions(GALLERY_THUMB, GALLERY_THUMB)
        border:SetAnchor(TOPLEFT, cell, TOPLEFT, 0, 0)
        local inner = wm:CreateControl(nil, cell, CT_TEXTURE)
        inner:SetAnchor(TOPLEFT, border, TOPLEFT, 2, 2)
        inner:SetAnchor(BOTTOMRIGHT, border, BOTTOMRIGHT, -2, -2)
        inner:SetColor(0.04, 0.04, 0.06, 1)

        local art = wm:CreateControl(nil, cell, CT_TEXTURE)
        art:SetDimensions(GALLERY_THUMB - 10, GALLERY_THUMB - 10)
        art:SetAnchor(CENTER, border, CENTER, 0, 0)
        art:SetTexture(ic.path)
        art:SetTextureCoords(ICON_U_LEFT, ICON_U_RIGHT, ICON_V_TOP, ICON_V_BOTTOM)

        local label = wm:CreateControl(nil, cell, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOP, border, BOTTOM, 0, 4)
        label:SetText(ic.label)

        cell.border, cell.art, cell.label = border, art, label

        cell:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then SelectIcon(ic.id) end
        end)
        cell:SetHandler("OnMouseEnter", function() cell.hover = true; RefreshPanelWidgets() end)
        cell:SetHandler("OnMouseExit", function() cell.hover = false; RefreshPanelWidgets() end)

        g.cells[i] = cell
    end

    panelUI.gallery = g
    RefreshPanelWidgets()
end

-- The settings preview uses the same icon/timer view and render helpers as the HUD.
local function CreatePreview(ctl)
    local wm = WINDOW_MANAGER
    local p = {}

    local bg = wm:CreateControl(nil, ctl, CT_TEXTURE)
    bg:SetAnchorFill(ctl)
    bg:SetColor(0.34, 0.35, 0.40, 1)

    p.info = wm:CreateControl(nil, ctl, CT_LABEL)
    p.info:SetFont("ZoFontGame")
    p.info:SetColor(0.8, 0.8, 0.8, 1)
    p.info:SetAnchor(TOP, ctl, TOP, 0, 8)

    p.host = wm:CreateControl(nil, ctl, CT_CONTROL)
    p.host:SetAnchor(CENTER, ctl, TOP, 0, 112)
    p.view = CreateMarkView(p.host)
    p.icon = p.view.icon
    p.timer = p.view.timer

    panelUI.preview = p
    RefreshPanelWidgets()
end

local function BuildMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "Panel"
    HMK.panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Weyland Huntsman's Warmask Tracker",
        displayName = "Weyland Huntsman's Warmask Tracker",
        author = "Weyland",
        version = HMK.version,
        slashCommand = "/hmarkmenu",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if panel == HMK.panel then RefreshPanelWidgets() end
    end)
    local m = sv.mark
    local dm = DEFAULTS.mark
    local fontNames, fontValues = FontChoices()
    local outNames, outValues = OutlineChoices()

    local function color(name, tbl, key, def, apply, disabled, tooltip)
        return {
            type = "colorpicker", name = name, tooltip = tooltip, width = "full",
            getFunc = function() local c = tbl[key]; return c.r, c.g, c.b, c.a end,
            setFunc = function(rr, gg, bb, aa) tbl[key] = { r = rr, g = gg, b = bb, a = aa }; apply() end,
            default = def, disabled = disabled,
        }
    end
    local function slider(name, tbl, key, def, mn, mx, step, apply, disabled)
        return {
            type = "slider", name = name, min = mn, max = mx, step = step, width = "full",
            getFunc = function() return tbl[key] end,
            setFunc = function(v) tbl[key] = v; apply() end,
            default = def, disabled = disabled,
        }
    end
    local function check(name, tbl, key, def, apply, tooltip, disabled)
        return {
            type = "checkbox", name = name, tooltip = tooltip, width = "full",
            getFunc = function() return tbl[key] end,
            setFunc = function(v) tbl[key] = v; apply() end,
            default = def, disabled = disabled,
        }
    end
    local function dropdown(name, tbl, key, def, names, values, apply, tooltip, disabled)
        return {
            type = "dropdown", name = name, tooltip = tooltip, width = "full",
            choices = names, choicesValues = values,
            getFunc = function() return tbl[key] end,
            setFunc = function(v) tbl[key] = v; apply() end,
            default = def, disabled = disabled,
        }
    end

    local function applyMark() ApplyMarkStyle() end

    local timerHidden = function() return m.timerMode == "hidden" end
    local warnOff = function() return not m.warnEnabled end
    local warnColorOff = function() return not m.warnEnabled or (not m.warnIcon and not m.warnTimer) end
    local availableSounds = AvailableSounds()
    local noSounds = #availableSounds == 0
    local soundOff = function() return not m.soundEnabled or noSounds end
    local soundNames, soundValues = {}, {}
    for _, snd in ipairs(availableSounds) do soundNames[#soundNames + 1] = snd.label; soundValues[#soundValues + 1] = snd.id end
    if noSounds then soundNames, soundValues = { T("NO_SOUNDS_AVAILABLE") }, { m.sound } end

    LAM:RegisterOptionControls(panelName, {
        { type = "description", title = nil, width = "full",
          text = T("MENU_DESCRIPTION") },
        { type = "description", title = T("REPOSITION_HEADER"), width = "full",
          text = T("REPOSITION_DESCRIPTION") },
        {
            type = "button", name = T("BUTTON_MOVE"), width = "full",
            tooltip = T("TOOLTIP_MOVE"),
            func = function() HMK.SetMoveMode(not HMK.unlocked) end,
        },

        { type = "header", name = T("HEADER_MARK_ICON") },
        {   -- click a picture to choose it; every thumbnail is drawn in the colour you picked
            type = "custom", reference = ADDON .. "_Gallery", width = "full",
            minHeight = function() return GALLERY_HEIGHT end,
            maxHeight = function() return GALLERY_HEIGHT end,
            createFunc = CreateGallery,
            refreshFunc = RefreshPanelWidgets,
        },
        {   -- live preview: icon, size, colour and timer exactly as they look on screen
            type = "custom", reference = ADDON .. "_Preview", width = "full",
            minHeight = function() return PREVIEW_HEIGHT end,
            maxHeight = function() return PREVIEW_HEIGHT end,
            createFunc = CreatePreview,
            refreshFunc = RefreshPanelWidgets,
        },
        slider(T("LABEL_ICON_SIZE"), m, "size", dm.size, 32, 120, 1, applyMark),
        color(T("LABEL_ICON_COLOR"), m, "color", dm.color, applyMark, nil,
            T("TIP_ICON_COLOR")),

        { type = "header", name = T("HEADER_TIMER") },
        dropdown(T("LABEL_TIMER_POSITION"), m, "timerMode", dm.timerMode,
            { T("CHOICE_TIMER_CENTRE"), T("CHOICE_TIMER_EDGE"), T("CHOICE_HIDDEN") },
            { "inside", "edge", "hidden" }, applyMark,
            T("TIP_TIMER_EDGE")),
        slider(T("LABEL_TIMER_OFFSET"), m, "timerOffsetY", dm.timerOffsetY, -60, 60, 1, applyMark, timerHidden),
        slider(T("LABEL_TIMER_FONT_SIZE"), m, "fontSize", dm.fontSize, 10, 80, 1, applyMark, timerHidden),
        color(T("LABEL_TIMER_COLOR"), m, "timerColor", dm.timerColor, applyMark, timerHidden),
        dropdown(T("LABEL_TIMER_FONT"), m, "font", dm.font, fontNames, fontValues, applyMark, nil, timerHidden),
        dropdown(T("LABEL_TIMER_OUTLINE"), m, "outline", dm.outline, outNames, outValues, applyMark, nil, timerHidden),
        check(T("LABEL_TIMER_TENTHS"), m, "tenths", dm.tenths, applyMark, nil, timerHidden),

        { type = "header", name = T("HEADER_WARNING") },
        check(T("LABEL_WARN_ENABLED"), m, "warnEnabled", dm.warnEnabled, applyMark),
        slider(T("LABEL_WARN_SECONDS"), m, "warnSeconds", dm.warnSeconds, 1, 60, 1, applyMark, warnOff),
        color(T("LABEL_WARN_COLOR"), m, "warnColor", dm.warnColor, applyMark, warnColorOff,
            T("TIP_WARN_COLOR")),
        check(T("LABEL_WARN_ICON"), m, "warnIcon", dm.warnIcon, applyMark, nil, warnOff),
        check(T("LABEL_WARN_TIMER"), m, "warnTimer", dm.warnTimer, applyMark, nil, warnOff),

        { type = "header", name = T("HEADER_SOUND") },
        check(T("LABEL_SOUND_ENABLED"), m, "soundEnabled", dm.soundEnabled, applyMark,
            T("TIP_SOUND_ENABLED")),
        {
            type = "dropdown", name = T("LABEL_SOUND_REPEAT"), width = "full",
            choices = { T("CHOICE_ONCE"), T("CHOICE_EVERY_1"), T("CHOICE_EVERY_2") },
            choicesValues = { 0, 1, 2 },
            getFunc = function() return m.soundInterval end,
            setFunc = function(v) m.soundInterval = v; applyMark() end,
            default = dm.soundInterval, disabled = soundOff,
            tooltip = T("TIP_SOUND_REPEAT"),
        },
        {
            type = "dropdown", name = T("LABEL_SOUND"), width = "full",
            choices = soundNames, choicesValues = soundValues,
            getFunc = function() return m.sound end,
            setFunc = function(v) m.sound = v; PlayWarnSound(v) end,   -- plays a sample when you pick it
            default = dm.sound, disabled = soundOff,
            tooltip = T("TIP_SOUND_ONLY_GAME"),
        },
        {
            type = "button", name = T("BUTTON_TEST_SOUND"), width = "full",
            func = function() PlayWarnSound(m.sound) end, disabled = soundOff,
        },

        { type = "header", name = T("HEADER_SUPPORT") },
        { type = "description", text = T("TEXT_SUPPORT") },

    })
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function ShowCommandHelp()
    Msg(T("COMMANDS_HEADER"))
    Msg(T("COMMAND_MOVE"))
    Msg(T("COMMAND_SETTINGS"))
end

local function OnSlash(arg)
    local command = zo_strlower((arg or ""):match("^%s*(.-)%s*$"))

    if command == "" then
        HMK.SetMoveMode(not HMK.unlocked)
    elseif command == "help" then
        ShowCommandHelp()
    else
        Msg(T("UNKNOWN_OPTION"))
    end
end

-- Init
---------------------------------------------------------------------------
local function OnSlotUpdate()
    RefreshMask()
end

local function OnPlayerDeactivated()
    -- Do not turn the fresh-install centre default into a saved position.
    if sv and sv.mark and sv.mark.positionValid == true then
        SavePosition(ui.mark, sv.mark)
    end
end

local function OnPlayerActivated()
    HMK.ClearMark()
    ApplyMarkStyle()
    RefreshMask()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EM:UnregisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("WeylandHuntsmansWarmaskTrackerSavedVars", 1, nil, DEFAULTS)
    if type(rawget(sv, "markIds")) ~= "table" then sv.markIds = {} end   -- never write into the shared defaults

    -- Discard the unused range preferences saved by previous versions.
    sv.range = nil

    -- v0.3.2: the old pictures are gone and the timer sits on the icon's bottom edge.
    local mk = sv.mark
    mk.size = math.max(32, math.min(120, tonumber(mk.size) or DEFAULTS.mark.size))
    mk.recolor = nil
    mk.enabled = nil
    mk.ownOnly = nil -- mark tracking is always restricted to effects cast by this player
    mk.scope = nil -- visibility is fixed: keep the marker shown until the mark ends or its target dies
    if rawget(mk, "soundRepeat") ~= nil then          -- v0.3.8 checkbox -> v0.3.9 interval
        mk.soundInterval = mk.soundRepeat and 1 or 0
        mk.soundRepeat = nil
    end
    if mk.soundInterval ~= 0 and mk.soundInterval ~= 1 and mk.soundInterval ~= 2 then mk.soundInterval = DEFAULTS.mark.soundInterval end
    if not HasId(SOUND_CANDIDATES, mk.sound) then mk.sound = DEFAULTS.mark.sound end   -- old sounds were removed
    if not HasId(ICONS, mk.icon) then mk.icon = DEFAULTS.mark.icon end
    if (rawget(sv, "layoutVersion") or 0) < 2 then
        mk.timerMode = "edge"     -- applied once; it can be changed back in the settings
        sv.layoutVersion = 2
    elseif mk.timerMode == "below" then
        mk.timerMode = "edge"
    end

    CreateUI()
    ApplyMarkStyle()
    BuildMenu()

    SLASH_COMMANDS["/hmark"] = OnSlash
    if not LibAddonMenu2 then
        SLASH_COMMANDS["/hmarkmenu"] = function()
            Msg(T("MISSING_LAM"))
        end
    end

    -- Standby listeners: the only things alive while the mask is NOT worn.
    EM:RegisterForEvent(ADDON .. "_Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
    EM:AddFilterForEvent(ADDON .. "_Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EM:RegisterForEvent(ADDON .. "_Full", EVENT_INVENTORY_FULL_UPDATE, OnSlotUpdate)
    EM:RegisterForEvent(ADDON .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(ADDON .. "_Deactivated", EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
end

EM:RegisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
