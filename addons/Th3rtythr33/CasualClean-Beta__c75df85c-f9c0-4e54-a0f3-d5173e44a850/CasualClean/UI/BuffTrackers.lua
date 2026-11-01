-- =============================================================================
-- CasualClean -- UI/BuffTrackers.lua
-- =============================================================================
-- Two small rows of buff icons that sit apart from the game's self buff bar
-- (Matt, 2026-10-31):
--
--   POTION ROW. The effects of the potion in your quick slot, in a row whose
--   right edge sits beside the left edge of the quick slot button, centred
--   on it vertically. Anchored to that button, never parented to the action
--   bar ("without making it formally a part of the action bar").
--
--   PROMINENT ROW. Every effect whose Buff Filtering choice is "Prominent",
--   centred above the game's own self buff bar, at a size the player picks.
--
-- Anything shown in a row is taken off the main bar by the Buff Filtering
-- hook (UI/SelfBuffs.lua asks DestinationOf for every entry), so nothing is
-- drawn twice.
--
-- WHICH EFFECTS A POTION GIVES. The game does not say: the item API returns
-- tooltip text for a potion's effects, never ability ids. So the row learns.
-- A drink shows up as the quick slot's own cooldown starting (read on
-- EVENT_ACTION_UPDATE_COOLDOWNS with GetSlotCooldownInfo); one second later
-- the player's effects whose start time lies within a second of the drink
-- are that potion's candidates. A potion is known once two drinks agree:
-- the ids common to both captures are kept and learning stops, so a skill
-- cast at the same moment on one drink drops out. If two captures share
-- nothing, the newer one becomes the candidate set and learning goes on.
-- Potions are keyed by name, because crafted potions with different traits
-- share an item id. The row shows the effects of the potion in the quick
-- slot and of the potion drunk last, so swapping the slot does not throw a
-- running potion's buffs back onto the main bar.
--
-- THE ICONS ARE THE GAME'S OWN. Each is CreateControlFromVirtual of ZOS's
-- "ZO_BuffDebuffIcon" with its platform template applied, exactly as the
-- buff bar's pool does (esoui/ingame/buffdebuff/buffdebuff.lua), and is
-- filled by ZO_BuffDebuffStyleObject.SetupIcon, the bar's own setup (it
-- reads only the control's data). Same frame, stack number, timer label and
-- font, and the font is ZOS's gamepad template's, so the gamepad-font trap
-- cannot bite. Icons are pooled and never destroyed (ESO cannot free
-- controls); a row never grows past MAX_ICONS.
--
-- COST. The rows read the player's effects themselves, so they work whatever
-- the game's Buffs & Debuffs settings filter out of the main bar. Effect
-- events only mark the rows dirty; one rebuild runs on the next frame, the
-- same rhythm as the game's bar. Timers update from an OnUpdate that exists
-- only while a row has icons, and a label's text is rewritten only when the
-- displayed time can have changed. Rows follow the self bar's own contextual
-- visibility (always / in combat / never, and hidden while the utility wheel
-- is open) by asking the player container's ShouldContextuallyShow.
-- =============================================================================

CasualClean = CasualClean or {}
local CC = CasualClean
CC.BuffTrackers = {}
local T = CC.BuffTrackers

T.DEFAULT_POTION = true
T.DEFAULT_PROMINENT = true
T.DEFAULT_PROMINENT_SCALE = 150      -- percent of the normal icon size
T.SCALE_MIN, T.SCALE_MAX, T.SCALE_STEP = 100, 250, 10
T.MAX_POTIONS = 40                   -- learned potion types kept
T.MAX_ICONS = 12                     -- per row

local NAMESPACE = "CasualCleanBuffTrackers"
local REBUILD_UPDATE = NAMESPACE .. "Rebuild"
local FORGET_DIALOG = "CASUALCLEAN_FORGET_POTIONS"
local ICON_PADDING = 5               -- ZOS's BUFF_PADDING between bar icons
local QUICKSLOT_GAP = 10             -- the gamepad action bar's own slot spacing (abilitySlotOffsetX)
local PROMINENT_GAP = 6              -- above the self bar's icons
local DURATION_SPACE = 26            -- the timer label hangs below each icon
local CAPTURE_DELAY_MS = 1000        -- wait for the potion's effects to arrive
local CAPTURE_WINDOW_S = 1.0         -- effects started this close to the drink
local MIN_POTION_COOLDOWN_MS = 2000  -- below this it is a global cooldown, not a drink
local FRESH_COOLDOWN_MS = 1500       -- a cooldown older than this was not just started

local rows = {}                      -- "potion" / "prominent" -> row state
local installState = "not attempted"
local eventsOn, cooldownEventsOn = false, false
local rebuildScheduled = false
local lastUseStartS = nil            -- frame-time second the last seen quick slot cooldown began
local lastDrunk = nil                -- name of the potion drunk last
local activePotionKeys = {}          -- key -> true, recomputed by BeginPass
local captureCount = 0               -- captures run this session (report)

local function sv()
    return CC.sv
end

local function SelfBuffs()
    return CC.SelfBuffs
end

local function FrameSize()
    return tonumber(ZO_BUFF_DEBUFF_FRAME_DIMENSIONS_GAMEPAD) or 46
end

-- -----------------------------------------------------------------------------
-- Settings values
-- -----------------------------------------------------------------------------
local function Flag(field, default)
    local s = sv()
    if s and s[field] ~= nil then return s[field] end
    return default
end

function T.GetPotionEnabled() return Flag("buffTrackerPotion", T.DEFAULT_POTION) end
function T.GetProminentEnabled() return Flag("buffTrackerProminent", T.DEFAULT_PROMINENT) end

function T.GetProminentScale()
    local v = tonumber(Flag("buffTrackerProminentScale", T.DEFAULT_PROMINENT_SCALE)) or T.DEFAULT_PROMINENT_SCALE
    if v < T.SCALE_MIN then v = T.SCALE_MIN elseif v > T.SCALE_MAX then v = T.SCALE_MAX end
    return v
end

local function Potions()
    local s = sv()
    if not s then return {} end
    if type(s.buffTrackerPotions) ~= "table" then s.buffTrackerPotions = {} end
    return s.buffTrackerPotions
end

-- -----------------------------------------------------------------------------
-- Which effects go where
-- -----------------------------------------------------------------------------
local QUICKSLOT = function() return HOTBAR_CATEGORY_QUICKSLOT_WHEEL end

local function PotionName(link)
    if type(GetItemLinkName) ~= "function" or not link or link == "" then return nil end
    local name = GetItemLinkName(link)
    if type(name) ~= "string" or name == "" then return nil end
    return (name:gsub("%^.*$", ""))
end

-- The name of the potion in the active quick slot, or nil.
local function SlottedPotion()
    if type(GetCurrentQuickslot) ~= "function" or type(GetSlotItemLink) ~= "function" then return nil end
    local slot = GetCurrentQuickslot()
    if not slot then return nil end
    if type(GetSlotType) == "function" and GetSlotType(slot, QUICKSLOT()) ~= ACTION_TYPE_ITEM then return nil end
    local link = GetSlotItemLink(slot, QUICKSLOT())
    if type(GetItemLinkItemType) == "function" and GetItemLinkItemType(link) ~= ITEMTYPE_POTION then return nil end
    return PotionName(link)
end

local function AddKnown(set, name)
    local entry = name and Potions()[name]
    if entry and type(entry.k) == "table" then
        for _, key in ipairs(entry.k) do set[key] = true end
    end
end

-- Recompute which keys belong to the potion row. Called at the start of
-- every pass that routes effects (the main-bar hook and the rows' rebuild),
-- so both agree within a frame.
function T.BeginPass()
    activePotionKeys = {}
    if not T.GetPotionEnabled() then return end
    AddKnown(activePotionKeys, SlottedPotion())
    AddKnown(activePotionKeys, lastDrunk)
end

-- "prominent", "potion" or nil (stays on the main bar). Hide wins over both
-- rows, and Prominent wins over the potion row. Prominent with that row
-- switched off behaves as Show.
function T.DestinationOf(key)
    if key == nil then return nil end
    local B = SelfBuffs()
    local c = B and B.GetChoice and B.GetChoice(key) or nil
    if B and c == B.CHOICE_HIDE then return nil end
    if B and c == B.CHOICE_PROMINENT and T.GetProminentEnabled() then return "prominent" end
    if activePotionKeys[key] then return "potion" end
    return nil
end

-- -----------------------------------------------------------------------------
-- Controls
-- -----------------------------------------------------------------------------
local function PlayerContainer()
    local bd = _G["BUFF_DEBUFF"]
    local byTag = bd and bd.containerObjectsByUnitTag
    return byTag and byTag["player"] or nil
end

local function ContextuallyShown()
    local c = PlayerContainer()
    if c and c.ShouldContextuallyShow then
        local ok, show = pcall(c.ShouldContextuallyShow, c)
        if ok then return show and true or false end
    end
    return true
end

local function QuickslotControl()
    if type(ZO_ActionBar_GetButton) ~= "function" or HOTBAR_CATEGORY_QUICKSLOT_WHEEL == nil then return nil end
    local button = ZO_ActionBar_GetButton(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    return button and button.slot or nil
end

local function SelfBarControl()
    return _G["ZO_BuffDebuffTopLevelSelfContainer"]
end

-- kind is "potion" or "prominent"; label is the same capitalised, for
-- control names.
local function NewRow(kind, label)
    local top = WINDOW_MANAGER:CreateTopLevelWindow(NAMESPACE .. label)
    top:SetMouseEnabled(false)
    local strip = WINDOW_MANAGER:CreateControl(NAMESPACE .. label .. "Strip", top, CT_CONTROL)
    strip:SetHidden(true)
    local row = { kind = kind, label = label, top = top, strip = strip, icons = {}, shown = 0, contextShown = nil }
    if type(ZO_SimpleSceneFragment) == "table" and HUD_SCENE and HUD_UI_SCENE then
        local fragment = ZO_SimpleSceneFragment:New(top)
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
    end
    return row
end

local function Anchor(row)
    local top = row.top
    top:ClearAnchors()
    if row.kind == "potion" then
        -- Middle of the row's right side to the vertical middle of the quick
        -- slot's left side, one action-bar slot gap away.
        local target = QuickslotControl()
        if not target then return false end
        top:SetAnchor(RIGHT, target, LEFT, -QUICKSLOT_GAP, 0)
    else
        -- Bottom of the row (timer labels included) above the top of the
        -- self bar, centred on it; follows the bar if the HUD editor moved it.
        local target = SelfBarControl()
        if not target then return false end
        top:SetAnchor(BOTTOM, target, TOP, 0, -PROMINENT_GAP)
    end
    return true
end

local function NewIcon(row, index)
    if type(CreateControlFromVirtual) ~= "function" then return nil end
    local ok, icon = pcall(CreateControlFromVirtual, NAMESPACE .. row.label .. "Icon" .. index, row.strip, "ZO_BuffDebuffIcon")
    if not ok or not icon then return nil end
    if type(ApplyTemplateToControl) == "function" and type(ZO_GetPlatformTemplate) == "function" then
        pcall(ApplyTemplateToControl, icon, ZO_GetPlatformTemplate("ZO_BuffDebuffIcon"))
    end
    icon:SetMouseEnabled(false)
    icon:SetHidden(true)
    return icon
end

local function ResetIcon(icon)
    if icon.blinkAnimation then icon.blinkAnimation:Stop() end
    icon.ccTimeKey, icon.ccShowDuration = nil, nil
end

-- -----------------------------------------------------------------------------
-- Timers
-- -----------------------------------------------------------------------------
local function UpdateIconTime(icon, nowS)
    local data = icon.data
    local label = icon.duration
    if not data or not label then return end
    local show = (data.duration or 0) > 0 and not data.permanent
    if show ~= icon.ccShowDuration then
        label:SetHidden(not show)
        icon.ccShowDuration = show
        icon.ccTimeKey = nil
    end
    if not show then return end
    local remain = (data.timeEnding or 0) - nowS
    if remain < 0 then remain = 0 end
    local threshold = tonumber(ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S) or 2
    if icon.blinkAnimation and remain <= threshold and not icon.blinkAnimation:IsPlaying() then
        icon.blinkAnimation:PlayFromStart()
    end
    -- Whole seconds are all the label shows, so half-second buckets catch
    -- every change whether the formatter floors, ceils or rounds.
    local timeKey = math.floor(remain * 2)
    if timeKey == icon.ccTimeKey then return end
    icon.ccTimeKey = timeKey
    local text
    if type(ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold) == "function" then
        text = ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(remain,
            ZO_ONE_MINUTE_IN_SECONDS or 60, 0, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT)
    else
        text = string.format("%.0f", remain)
    end
    label:SetText(text)
end

local function OnRowUpdate(row)
    local show = ContextuallyShown()
    if show ~= row.contextShown then
        row.strip:SetHidden(not show)
        row.contextShown = show
    end
    if not show then return end
    local nowS = GetFrameTimeSeconds()
    for i = 1, row.shown do
        UpdateIconTime(row.icons[i], nowS)
    end
end

-- -----------------------------------------------------------------------------
-- Reading the player's effects (same data shape as ZOS's base style)
-- -----------------------------------------------------------------------------
local function ReadEffects()
    local list, uid = {}, 1
    if type(ZO_GetNextActiveArtificialEffectIdIter) == "function" and type(GetArtificialEffectInfo) == "function" then
        for effectId in ZO_GetNextActiveArtificialEffectIdIter do
            local name, icon, effectType, sortOrder, timeStarted, timeEnding = GetArtificialEffectInfo(effectId)
            local duration = (timeEnding or 0) - (timeStarted or 0)
            list[#list + 1] = {
                buffName = name, timeStarted = timeStarted, timeEnding = timeEnding, iconFilename = icon,
                stackCount = 0, effectType = effectType, uid = uid, duration = duration,
                permanent = duration == 0, sortOrder = sortOrder, effectId = effectId, isArtificial = true,
            }
            uid = uid + 1
        end
    end
    if type(GetNumBuffs) == "function" and type(GetUnitBuffInfo) == "function" then
        for i = 1, GetNumBuffs("player") or 0 do
            local name, timeStarted, timeEnding, buffSlot, stackCount, icon, _, effectType, abilityType,
                statusEffectType, abilityId, _, castByPlayer = GetUnitBuffInfo("player", i)
            local duration = (timeEnding or 0) - (timeStarted or 0)
            list[#list + 1] = {
                buffName = name, timeStarted = timeStarted, timeEnding = timeEnding, buffSlot = buffSlot,
                stackCount = stackCount or 0, iconFilename = icon, effectType = effectType,
                abilityType = abilityType, statusEffectType = statusEffectType, abilityId = abilityId,
                uid = uid, duration = duration, castByPlayer = castByPlayer, permanent = duration == 0,
                isArtificial = false,
            }
            uid = uid + 1
        end
    end
    return list
end

-- ZOS's base order: buffs before debuffs, then oldest first, then by name.
local function SortEffects(a, b)
    if a.effectType ~= b.effectType then return a.effectType == BUFF_EFFECT_TYPE_BUFF end
    if a.timeStarted ~= b.timeStarted then return (a.timeStarted or 0) < (b.timeStarted or 0) end
    if a.buffName ~= b.buffName then return tostring(a.buffName) < tostring(b.buffName) end
    return a.uid < b.uid
end

-- -----------------------------------------------------------------------------
-- Layout
-- -----------------------------------------------------------------------------
local function Fill(row, list, scale)
    local frame = FrameSize()
    local n = math.min(#list, T.MAX_ICONS)
    for i = 1, n do
        local icon = row.icons[i]
        if not icon then
            icon = NewIcon(row, i)
            if not icon then n = i - 1; break end
            row.icons[i] = icon
        end
        if icon.data ~= list[i] then ResetIcon(icon) end
        icon.data = list[i]
        if ZO_BuffDebuffStyleObject and ZO_BuffDebuffStyleObject.SetupIcon then
            pcall(ZO_BuffDebuffStyleObject.SetupIcon, ZO_BuffDebuffStyleObject, icon)
        end
        icon:ClearAnchors()
        if row.kind == "potion" then
            -- Grows leftwards from the quick slot.
            if i == 1 then icon:SetAnchor(RIGHT, row.strip, RIGHT, 0, 0)
            else icon:SetAnchor(RIGHT, row.icons[i - 1], LEFT, -ICON_PADDING, 0) end
        else
            if i == 1 then icon:SetAnchor(LEFT, row.strip, LEFT, 0, 0)
            else icon:SetAnchor(LEFT, row.icons[i - 1], RIGHT, ICON_PADDING, 0) end
        end
        icon:SetHidden(false)
    end
    for i = n + 1, #row.icons do
        local icon = row.icons[i]
        if not icon:IsHidden() then
            icon:SetHidden(true)
            ResetIcon(icon)
            icon.data = nil
        end
    end
    row.shown = n

    local width = n > 0 and (n * frame + (n - 1) * ICON_PADDING) or frame
    row.strip:SetDimensions(width, frame)
    row.strip:SetScale(scale)
    row.strip:ClearAnchors()
    if row.kind == "potion" then
        -- The row's own height is the icon frame, so its RIGHT anchor is the
        -- icons' vertical middle.
        row.top:SetDimensions(width, frame)
        row.strip:SetAnchor(CENTER, row.top, CENTER, 0, 0)
    else
        row.top:SetDimensions(width * scale, (frame + DURATION_SPACE) * scale)
        row.strip:SetAnchor(TOP, row.top, TOP, 0, 0)
    end

    if n > 0 then
        row.contextShown = nil
        row.onUpdate = row.onUpdate or function() OnRowUpdate(row) end
        row.top:SetHandler("OnUpdate", row.onUpdate)
        OnRowUpdate(row)
    else
        row.top:SetHandler("OnUpdate", nil)
        row.strip:SetHidden(true)
        row.contextShown = nil
    end
end

function T.Rebuild()
    if not rows.potion then return end
    local lists = { potion = {}, prominent = {} }
    if eventsOn then
        T.BeginPass()
        for _, data in ipairs(ReadEffects()) do
            local B = SelfBuffs()
            local key = B and B.KeyOf and B.KeyOf(data) or nil
            local dest = T.DestinationOf(key)
            if dest then table.insert(lists[dest], data) end
        end
        local B = SelfBuffs()
        for _, list in pairs(lists) do
            table.sort(list, SortEffects)
            if B and B.GetMergeRepeats and B.GetMergeRepeats() and B.MergeRepeats then B.MergeRepeats(list) end
        end
    end
    Fill(rows.potion, T.GetPotionEnabled() and lists.potion or {}, 1)
    Fill(rows.prominent, T.GetProminentEnabled() and lists.prominent or {}, T.GetProminentScale() / 100)
end

local function MarkDirty()
    if rebuildScheduled then return end
    rebuildScheduled = true
    EVENT_MANAGER:RegisterForUpdate(REBUILD_UPDATE, 0, function()
        EVENT_MANAGER:UnregisterForUpdate(REBUILD_UPDATE)
        rebuildScheduled = false
        T.Rebuild()
    end)
end
T.MarkDirty = MarkDirty

-- Both the rows and the main bar change when routing changes.
local function RefreshAll()
    MarkDirty()
    local B = SelfBuffs()
    if B and B.RefreshBar then B.RefreshBar() end
end

-- -----------------------------------------------------------------------------
-- Learning a potion's effects
-- -----------------------------------------------------------------------------
local function CountPotions()
    local n = 0
    for _ in pairs(Potions()) do n = n + 1 end
    return n
end

local function Capture(name, useS)
    captureCount = captureCount + 1
    local potions = Potions()
    local entry = potions[name]
    if entry and entry.k then return end
    if not entry then
        if CountPotions() >= T.MAX_POTIONS then return end
        entry = {}
        potions[name] = entry
    end
    local B = SelfBuffs()
    local found, list = {}, {}
    for _, data in ipairs(ReadEffects()) do
        local key = B and B.KeyOf and B.KeyOf(data) or nil
        if key and not data.isArtificial and not data.permanent
            and math.abs((data.timeStarted or 0) - useS) <= CAPTURE_WINDOW_S and not found[key] then
            found[key] = true
            list[#list + 1] = key
        end
    end
    table.sort(list)
    if #list == 0 then return end
    if type(entry.p) == "table" then
        local common = {}
        for _, key in ipairs(entry.p) do
            if found[key] then common[#common + 1] = key end
        end
        if #common > 0 then
            entry.k, entry.p = common, nil
            RefreshAll()
            return
        end
    end
    entry.p = list
end

local function OnCooldowns()
    if type(GetCurrentQuickslot) ~= "function" or type(GetSlotCooldownInfo) ~= "function" then return end
    local slot = GetCurrentQuickslot()
    if not slot then return end
    if type(GetSlotType) == "function" and GetSlotType(slot, QUICKSLOT()) ~= ACTION_TYPE_ITEM then return end
    local remain, duration, isGlobal = GetSlotCooldownInfo(slot, QUICKSLOT())
    remain, duration = tonumber(remain) or 0, tonumber(duration) or 0
    if isGlobal or duration < MIN_POTION_COOLDOWN_MS or remain <= 0 then return end
    local nowS = GetFrameTimeSeconds()
    local elapsedMs = duration - remain
    local startS = nowS - elapsedMs / 1000
    if lastUseStartS and math.abs(startS - lastUseStartS) < FRESH_COOLDOWN_MS / 1000 then return end
    lastUseStartS = startS
    -- A cooldown already well under way (after a reload, or a shared potion
    -- cooldown seen on a newly slotted potion) is not a drink.
    if elapsedMs > FRESH_COOLDOWN_MS then return end
    local name = SlottedPotion()
    if not name then return end
    lastDrunk = name
    local entry = Potions()[name]
    if entry and entry.k then
        RefreshAll()
        return
    end
    zo_callLater(function() Capture(name, startS) end, CAPTURE_DELAY_MS)
end

-- -----------------------------------------------------------------------------
-- Events
-- -----------------------------------------------------------------------------
local function OnEffectChanged() MarkDirty() end
local function OnSlotChanged() RefreshAll() end

local function SetEvents(effects, cooldowns)
    local em = EVENT_MANAGER
    if effects ~= eventsOn then
        if effects then
            em:RegisterForEvent(NAMESPACE, EVENT_EFFECT_CHANGED, OnEffectChanged)
            em:AddFilterForEvent(NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
            em:RegisterForEvent(NAMESPACE, EVENT_EFFECTS_FULL_UPDATE, OnEffectChanged)
            em:RegisterForEvent(NAMESPACE, EVENT_ARTIFICIAL_EFFECT_ADDED, OnEffectChanged)
            em:RegisterForEvent(NAMESPACE, EVENT_ARTIFICIAL_EFFECT_REMOVED, OnEffectChanged)
        else
            em:UnregisterForEvent(NAMESPACE, EVENT_EFFECT_CHANGED)
            em:UnregisterForEvent(NAMESPACE, EVENT_EFFECTS_FULL_UPDATE)
            em:UnregisterForEvent(NAMESPACE, EVENT_ARTIFICIAL_EFFECT_ADDED)
            em:UnregisterForEvent(NAMESPACE, EVENT_ARTIFICIAL_EFFECT_REMOVED)
        end
        eventsOn = effects
    end
    if cooldowns ~= cooldownEventsOn then
        if cooldowns then
            em:RegisterForEvent(NAMESPACE, EVENT_ACTION_UPDATE_COOLDOWNS, OnCooldowns)
            em:RegisterForEvent(NAMESPACE, EVENT_ACTIVE_QUICKSLOT_CHANGED, OnSlotChanged)
            em:RegisterForEvent(NAMESPACE .. "Slot", EVENT_ACTION_SLOT_UPDATED, OnSlotChanged)
        else
            em:UnregisterForEvent(NAMESPACE, EVENT_ACTION_UPDATE_COOLDOWNS)
            em:UnregisterForEvent(NAMESPACE, EVENT_ACTIVE_QUICKSLOT_CHANGED)
            em:UnregisterForEvent(NAMESPACE .. "Slot", EVENT_ACTION_SLOT_UPDATED)
        end
        cooldownEventsOn = cooldowns
    end
end

-- Registers exactly what the switches need and nothing else: no row on, no
-- events at all.
function T.Apply()
    if not rows.potion then return end
    local potion, prominent = T.GetPotionEnabled(), T.GetProminentEnabled()
    SetEvents(potion or prominent, potion)
    if not potion then activePotionKeys = {} end
    RefreshAll()
end

-- True when a row might take effects off the main bar.
function T.IsActive()
    return rows.potion ~= nil and eventsOn
end

-- -----------------------------------------------------------------------------
-- Public surface
-- -----------------------------------------------------------------------------
local function SetFlag(field, value)
    local s = sv()
    if s then s[field] = value end
end

function T.SetPotionEnabled(value) SetFlag("buffTrackerPotion", value and true or false); T.Apply() end
function T.SetProminentEnabled(value) SetFlag("buffTrackerProminent", value and true or false); T.Apply() end

function T.SetProminentScale(value)
    local v = tonumber(value) or T.DEFAULT_PROMINENT_SCALE
    v = math.floor(v + 0.5)
    if v < T.SCALE_MIN then v = T.SCALE_MIN elseif v > T.SCALE_MAX then v = T.SCALE_MAX end
    SetFlag("buffTrackerProminentScale", v)
    MarkDirty()
end

function T.ClearPotions()
    local s = sv()
    if s then s.buffTrackerPotions = {} end
    lastDrunk = nil
    activePotionKeys = {}
    RefreshAll()
end

local function RegisterForgetDialog()
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return end
    ZO_Dialogs_RegisterCustomDialog(FORGET_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = type(GAMEPAD_DIALOGS) == "table" and GAMEPAD_DIALOGS.BASIC or nil },
        title = { text = "Casual Clean: Buff Trackers" },
        mainText = {
            text = function()
                return string.format("Forget the effects of all %d potions learned so far?\n\n" ..
                    "Each potion is learned again over its next two drinks.", CountPotions())
            end,
        },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Forget", callback = function() T.ClearPotions() end },
            { keybind = "DIALOG_NEGATIVE", text = "Cancel" },
        },
    })
end

function T.ForgetPotions()
    if type(ZO_Dialogs_ShowPlatformDialog) == "function" then
        ZO_Dialogs_ShowPlatformDialog(FORGET_DIALOG)
    elseif type(ZO_Dialogs_ShowGamepadDialog) == "function" then
        ZO_Dialogs_ShowGamepadDialog(FORGET_DIALOG)
    end
end

function T.Init()
    if rows.potion then return end
    if not (WINDOW_MANAGER and EVENT_MANAGER and type(GetFrameTimeSeconds) == "function") then
        installState = "WINDOW_MANAGER, EVENT_MANAGER or GetFrameTimeSeconds missing"
        return
    end
    rows.potion = NewRow("potion", "Potion")
    rows.prominent = NewRow("prominent", "Prominent")
    local missing = {}
    if not Anchor(rows.potion) then missing[#missing + 1] = "quick slot button" end
    if not Anchor(rows.prominent) then missing[#missing + 1] = "self buff bar" end
    if type(CreateControlFromVirtual) ~= "function" then missing[#missing + 1] = "CreateControlFromVirtual" end
    installState = #missing == 0 and "ready" or ("missing " .. table.concat(missing, ", "))
    RegisterForgetDialog()
    -- Events only, no forced bar rebuild at load: the game rebuilds its own
    -- bar when the player's effects arrive, and the hook routes then.
    local potion, prominent = T.GetPotionEnabled(), T.GetProminentEnabled()
    SetEvents(potion or prominent, potion)
    MarkDirty()
end

-- Settings rows for Settings.lua, a section of its own.
function T.SettingsRows()
    local LHAS = LibHarvensAddonSettings
    return {
        {
            type = LHAS.ST_SECTION,
            label = "Buff Trackers",
            tooltip = "Extra rows of buff icons apart from your self buff bar: your potion's effects beside the quick slot, and the effects you mark Prominent above the bar.",
        },
        {
            type = LHAS.ST_CHECKBOX,
            label = "Show potion effects beside the quick slot",
            tooltip = "Shows the effects of the potion in your quick slot in a row to the left of it, and takes them off your self buff bar. " ..
                      "The game does not say which effects a potion gives, so each potion is learned over its first two drinks.",
            getFunction = function() return T.GetPotionEnabled() end,
            setFunction = function(value) T.SetPotionEnabled(value) end,
            default = T.DEFAULT_POTION,
        },
        {
            type = LHAS.ST_CHECKBOX,
            label = "Show the Prominent row",
            tooltip = "Shows every effect you set to Prominent in the Buff Filtering lists in a row above your self buff bar, and takes it off the bar. " ..
                      "Off puts those effects back on the bar.",
            getFunction = function() return T.GetProminentEnabled() end,
            setFunction = function(value) T.SetProminentEnabled(value) end,
            default = T.DEFAULT_PROMINENT,
        },
        {
            type = LHAS.ST_SLIDER,
            label = "Prominent icon size",
            tooltip = ("How large the Prominent row's icons are, as a percentage of the normal buff icons. Default: %d%%."):format(T.DEFAULT_PROMINENT_SCALE),
            min = T.SCALE_MIN,
            max = T.SCALE_MAX,
            step = T.SCALE_STEP,
            unit = "%",
            format = "%.0f",
            getFunction = function() return T.GetProminentScale() end,
            setFunction = function(value) T.SetProminentScale(value) end,
            default = T.DEFAULT_PROMINENT_SCALE,
        },
        {
            type = LHAS.ST_BUTTON,
            label = "Forget learned potions",
            tooltip = "Asks for confirmation, then forgets which effects each potion gives. Each potion is learned again over its next two drinks.",
            buttonText = "Forget",
            clickHandler = function() T.ForgetPotions() end,
        },
    }
end

-- For `/casualclean buffs`.
function T.GetReport()
    local out = {}
    local known, learning = 0, 0
    for _, entry in pairs(Potions()) do
        if entry.k then known = known + 1 elseif entry.p then learning = learning + 1 end
    end
    out[#out + 1] = string.format("trackers: %s potion=%s prominent=%s scale=%d%% events=%s/%s captures=%d",
        installState, tostring(T.GetPotionEnabled()), tostring(T.GetProminentEnabled()), T.GetProminentScale(),
        tostring(eventsOn), tostring(cooldownEventsOn), captureCount)
    out[#out + 1] = string.format("  rows: potion %d shown / %d pooled, prominent %d shown / %d pooled",
        rows.potion and rows.potion.shown or 0, rows.potion and #rows.potion.icons or 0,
        rows.prominent and rows.prominent.shown or 0, rows.prominent and #rows.prominent.icons or 0)
    out[#out + 1] = string.format("  potions: %d known, %d learning, slotted=%s, last drunk=%s",
        known, learning, tostring(SlottedPotion()), tostring(lastDrunk))
    local names = {}
    for name in pairs(Potions()) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local entry = Potions()[name]
        if entry.k then
            out[#out + 1] = string.format("    %s: ids %s", name, table.concat(entry.k, " "))
        elseif entry.p then
            out[#out + 1] = string.format("    %s: learning, candidates %s", name, table.concat(entry.p, " "))
        end
    end
    return out
end
