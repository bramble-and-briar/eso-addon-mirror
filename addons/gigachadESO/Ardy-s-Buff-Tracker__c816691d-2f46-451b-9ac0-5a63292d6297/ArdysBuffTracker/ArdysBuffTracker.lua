-- Ardy's Buff Tracker
-- Tracks selected raid buffs on hand-picked group members (by @account).
-- Designed for PC first, with Xbox/PS5 (gamepad UI, no mouse) as the real target.

ArdysBuffTracker = ArdysBuffTracker or {}
local PB = ArdysBuffTracker
PB.name = "ArdysBuffTracker"
PB.version = "1.3.0"

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

ZO_CreateStringId("SI_BINDING_NAME_ARDYSBUFFTRACKER_TOGGLE_TARGET", "Pin / Unpin Target")

---------------------------------------------------------------------------
-- Tracked buffs
-- Matching is by abilityId first, then by exact English effect name.
-- Name matching catches every source variant (each Major/Minor buff has many
-- IDs), but it is English-only. Fill `ids` with confirmed IDs from `/pb scan`
-- to make matching faster and locale-proof. The first ID also supplies the
-- icon at load time.
---------------------------------------------------------------------------
PB.BUFFS = {
    { key = "majSlayer",  name = "Major Slayer",     short = "MjSl", ids = {} },
    { key = "majForce",   name = "Major Force",      short = "MjFo", ids = {} },
    { key = "majCourage", name = "Major Courage",    short = "MjCo", ids = {} },
    { key = "majProt",    name = "Major Protection", short = "MjPr", ids = {} },
    { key = "majBers",    name = "Major Berserk",    short = "MjBe", ids = {} },
    { key = "minCourage", name = "Minor Courage",    short = "MnCo", ids = {} },
    { key = "minForce",   name = "Minor Force",      short = "MnFo", ids = {} },
    { key = "minBers",    name = "Minor Berserk",    short = "MnBe", ids = {} },
    { key = "minProt",    name = "Minor Protection", short = "MnPr", ids = {} },
    { key = "pa",         name = "Powerful Assault", short = "PA",   ids = {} },
}

local allByName = {}                  -- every defined buff (for /pb scan)
local buffByName, buffById = {}, {}   -- enabled buffs only (hot path)
PB.active = {}                        -- enabled buffs, in display order

local function IsBuffEnabled(key) return PB.sv.buffs[key] ~= false end

local function AllBuffsEnabled()
    for _, b in ipairs(PB.BUFFS) do
        if not IsBuffEnabled(b.key) then return false end
    end
    return true
end

local function RebuildBuffs()
    ZO_ClearTable(buffByName)
    ZO_ClearTable(buffById)
    ZO_ClearNumericallyIndexedTable(PB.active)
    for i, b in ipairs(PB.BUFFS) do
        b.index = i
        allByName[b.name] = b
        if IsBuffEnabled(b.key) then
            table.insert(PB.active, b)
            buffByName[b.name] = b
            for _, id in ipairs(b.ids) do buffById[id] = b end
        end
    end
end

local function MatchBuff(name, abilityId)
    return (abilityId and buffById[abilityId]) or (name and buffByName[name]) or nil
end

---------------------------------------------------------------------------
-- Icons
-- Learned from the game the first time each buff is seen, then saved.
-- Until then the box shows a short text label (MjSl, MnCo, ...).
---------------------------------------------------------------------------
local function IconFor(buff)
    local icon = PB.sv.icons[buff.key]
    if icon then return icon end
    local id = buff.ids[1]
    if id then
        icon = GetAbilityIcon(id)
        if icon and icon ~= "" then return icon end
    end
    return nil
end

local function LearnIcon(buff, icon)
    if PB.sv.icons[buff.key] then return end
    if not icon or icon == "" or icon:find("icon_missing", 1, true) then return end
    PB.sv.icons[buff.key] = icon
    PB.iconsDirty = true   -- applied on the next UI tick, not in the event handler
end

---------------------------------------------------------------------------
-- State
-- state[@account][buffKey][effectSlot] = endTime (math.huge = no expiry)
-- Keyed by @account so unit-tag reshuffles (group1 -> group3) don't matter.
-- Per-slot tracking means one Minor Courage fading doesn't clear a second
-- Minor Courage from another source.
---------------------------------------------------------------------------
local state = {}
local pinnedTags = {}   -- [unitTag] = @account, rebuilt on group changes
PB.rows = {}            -- ordered @accounts currently shown

-- Your own row and the debug target row use fixed keys so their state
-- survives label changes. Debug flags are session-only on purpose: they
-- reset on /reloadui. "Show myself" is a saved setting (on by default).
local SELF_KEY, DEBUG_TARGET = "~self", "~target"
PB.debug = { target = false, log = false, logAll = false }
PB.labels = {}

local function LabelFor(dn) return PB.labels[dn] or dn end
local function IsSelf(dn) return dn == GetDisplayName() end
local function IsPinned(dn) return PB.sv.pins[dn] == true end

local function SetSlot(dn, buff, slot, endTime)
    local s = state[dn]
    if not s then s = {}; state[dn] = s end
    local b = s[buff.key]
    if not b then b = {}; s[buff.key] = b end
    b[slot] = endTime
end

local function ClearSlot(dn, buff, slot)
    local s = state[dn]
    local b = s and s[buff.key]
    if b then b[slot] = nil end
end

local function RemainingFor(dn, buffKey, now)
    local s = state[dn]
    local b = s and s[buffKey]
    if not b then return nil end
    local best
    for slot, endTime in pairs(b) do
        if endTime == math.huge then return math.huge end
        local r = endTime - now
        if r > 0 then
            if not best or r > best then best = r end
        else
            b[slot] = nil
        end
    end
    return best
end

local function RescanUnit(unitTag, dn)
    state[dn] = {}
    for i = 1, GetNumBuffs(unitTag) do
        local buffName, timeStarted, timeEnding, buffSlot, _, iconFile, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, i)
        local buff = MatchBuff(buffName, abilityId)
        if buff then
            LearnIcon(buff, iconFile)
            if castByPlayer or not PB.sv.onlyMine then
                SetSlot(dn, buff, buffSlot, (timeEnding > timeStarted) and timeEnding or math.huge)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local CHANGE_TEXT = {
    [EFFECT_RESULT_GAINED]  = "|c33FF33+gained|r",
    [EFFECT_RESULT_FADED]   = "|cFF4444-faded|r",
    [EFFECT_RESULT_UPDATED] = "|cFFDD33~updated|r",
}

-- "Mine" = cast by you or your pet (the same test ZOS's own UI uses).
local function IsMine(sourceType)
    return sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
end

local function LogEffect(changeType, effectSlot, effectName, unitTag, dn, beginTime, endTime, abilityId, buff, sourceType)
    local dur = (endTime > beginTime) and string.format("%.1fs", endTime - beginTime) or "no timer"
    local by = ""
    if changeType ~= EFFECT_RESULT_FADED then by = IsMine(sourceType) and ", by you" or ", by someone else" end
    d(string.format("[PB] %s %s (id %d, slot %d, %s%s) on %s [%s]%s",
        CHANGE_TEXT[changeType] or tostring(changeType), effectName, abilityId, effectSlot, dur, by,
        LabelFor(dn), unitTag, buff and "" or " |c888888untracked|r"))
end

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime,
                               _, iconName, _, effectType, _, _, _, _, abilityId, sourceType)
    -- Cheapest check first: this event fires constantly in a trial.
    local dn = pinnedTags[unitTag]
    if not dn then return end
    local buff = MatchBuff(effectName, abilityId)
    if PB.debug.log and (buff or (PB.debug.logAll and effectType == BUFF_EFFECT_TYPE_BUFF)) then
        LogEffect(changeType, effectSlot, effectName, unitTag, dn, beginTime, endTime, abilityId, buff, sourceType)
    end
    if not buff then return end

    if changeType == EFFECT_RESULT_FADED then
        ClearSlot(dn, buff, effectSlot)
    else
        LearnIcon(buff, iconName)
        if PB.sv.onlyMine and not IsMine(sourceType) then return end
        SetSlot(dn, buff, effectSlot, (endTime > beginTime) and endTime or math.huge)
    end
end

---------------------------------------------------------------------------
-- UI
-- Everything is sized from one scale setting (50-200%), text included.
---------------------------------------------------------------------------
local BASE_CELL, BASE_NAME_W, BASE_PAD = 32, 150, 3
local COLOR_UP    = { 0.15, 0.80, 0.15, 1 }
local COLOR_LOW   = { 0.95, 0.80, 0.10, 1 }
local COLOR_DOWN  = { 0.75, 0.12, 0.12, 1 }
local LOW_SECONDS = 3

PB.rowCtls = {}

local function Dims()
    local s = PB.sv.scale / 100
    local cell = zo_round(BASE_CELL * s)
    return {
        cell      = cell,
        nameW     = zo_round(BASE_NAME_W * s),
        pad       = math.max(1, zo_round(BASE_PAD * s)),
        border    = math.max(1, zo_round(2 * s)),
        nameSize  = math.max(9, zo_round(15 * s)),
        timerSize = math.max(8, zo_round(cell * 0.5)),
        abbrSize  = math.max(7, zo_round(cell * 0.32)),
    }
end

local function Font(size)
    local face = IsInGamepadPreferredMode() and "$(GAMEPAD_BOLD_FONT)" or "$(BOLD_FONT)"
    return string.format("%s|%d|soft-shadow-thick", face, size)
end

local function CreatePanel()
    local tlw = WM:CreateTopLevelWindow("ArdysBuffTrackerPanel")
    tlw:SetClampedToScreen(true)
    tlw:SetMouseEnabled(true)
    tlw:SetMovable(not PB.sv.locked)
    tlw:SetHandler("OnMoveStop", function(self)
        PB.sv.x, PB.sv.y = self:GetLeft(), self:GetTop()
    end)
    tlw:ClearAnchors()
    tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, PB.sv.x, PB.sv.y)

    -- Container we hide when there's nothing to show; the fragment owns tlw.
    local box = WM:CreateControl("$(parent)Box", tlw, CT_CONTROL)
    box:SetAnchorFill()

    local bg = WM:CreateControl("$(parent)BG", box, CT_TEXTURE)
    bg:SetAnchorFill()
    bg:SetColor(0, 0, 0, 0.45)

    PB.panel, PB.box = tlw, box

    local fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

-- Each cell: colored border (status) > buff icon > dark shade (when missing) > timer.
local function GetRow(i)
    local row = PB.rowCtls[i]
    if row then return row end

    row = { cells = {} }
    local nm = WM:CreateControl("ArdysBuffTrackerRow" .. i .. "Name", PB.box, CT_LABEL)
    nm:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nm:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.name = nm

    for j = 1, #PB.BUFFS do
        local base = "ArdysBuffTrackerRow" .. i .. "Cell" .. j
        local border = WM:CreateControl(base, PB.box, CT_TEXTURE)

        local icon = WM:CreateControl(base .. "Icon", border, CT_TEXTURE)
        icon:SetDrawLevel(1)

        local shade = WM:CreateControl(base .. "Shade", border, CT_TEXTURE)
        shade:SetColor(0, 0, 0, 0.55)
        shade:SetDrawLevel(2)

        local abbr = WM:CreateControl(base .. "Abbr", border, CT_LABEL)
        abbr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        abbr:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        abbr:SetDrawLevel(3)

        local timer = WM:CreateControl(base .. "Timer", border, CT_LABEL)
        timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        timer:SetDrawLevel(4)

        row.cells[j] = { border = border, icon = icon, shade = shade, abbr = abbr, timer = timer }
    end

    PB.rowCtls[i] = row
    return row
end

local function ApplyIcons()
    for _, row in pairs(PB.rowCtls) do
        for j, buff in ipairs(PB.BUFFS) do
            local c = row.cells[j]
            local icon = IconFor(buff)
            if icon then c.icon:SetTexture(icon) end
            c.icon:SetHidden(icon == nil)
            c.abbr:SetText(buff.short)
            c.abbr:SetHidden(icon ~= nil)
        end
    end
    PB.iconsDirty = false
end

local function Layout()
    local d = Dims()
    local n, nActive = #PB.rows, #PB.active
    for i = 1, n do GetRow(i) end

    for i, row in pairs(PB.rowCtls) do
        local shown = i <= n
        local y = d.pad + (i - 1) * (d.cell + d.pad)

        row.name:SetHidden(not shown)
        row.name:SetFont(Font(d.nameSize))
        row.name:ClearAnchors()
        row.name:SetAnchor(TOPLEFT, PB.box, TOPLEFT, d.pad, y)
        row.name:SetDimensions(d.nameW, d.cell)

        for _, c in ipairs(row.cells) do c.border:SetHidden(true) end

        if shown then
            for a, buff in ipairs(PB.active) do
                local c = row.cells[buff.index]
                local x = d.pad * 2 + d.nameW + (a - 1) * (d.cell + d.pad)
                c.border:SetHidden(false)
                c.border:ClearAnchors()
                c.border:SetAnchor(TOPLEFT, PB.box, TOPLEFT, x, y)
                c.border:SetDimensions(d.cell, d.cell)

                c.icon:ClearAnchors()
                c.icon:SetAnchor(TOPLEFT, c.border, TOPLEFT, d.border, d.border)
                c.icon:SetAnchor(BOTTOMRIGHT, c.border, BOTTOMRIGHT, -d.border, -d.border)
                c.shade:ClearAnchors()
                c.shade:SetAnchorFill(c.icon)

                c.abbr:ClearAnchors()
                c.abbr:SetAnchorFill(c.border)
                c.abbr:SetFont(Font(d.abbrSize))

                c.timer:ClearAnchors()
                c.timer:SetAnchorFill(c.border)
                c.timer:SetFont(Font(d.timerSize))
            end
        end
    end

    PB.panel:SetDimensions(d.pad * 3 + d.nameW + nActive * (d.cell + d.pad), d.pad + n * (d.cell + d.pad))
    PB.box:SetHidden(n == 0 or nActive == 0)
    ApplyIcons()
end

local function UpdatePanel()
    if PB.iconsDirty then ApplyIcons() end
    local now = GetFrameTimeSeconds()
    for i, dn in ipairs(PB.rows) do
        local row = PB.rowCtls[i]
        row.name:SetText(LabelFor(dn))
        for _, buff in ipairs(PB.active) do
            local c = row.cells[buff.index]
            local rem = RemainingFor(dn, buff.key, now)
            if rem then
                local low = rem ~= math.huge and rem < LOW_SECONDS
                c.border:SetColor(unpack(low and COLOR_LOW or COLOR_UP))
                c.icon:SetDesaturation(0)
                c.shade:SetHidden(true)
                c.timer:SetText(rem == math.huge and "" or tostring(zo_ceil(rem)))
            else
                c.border:SetColor(unpack(COLOR_DOWN))
                c.icon:SetDesaturation(1)
                c.shade:SetHidden(false)
                c.timer:SetText("")
            end
        end
    end
end

local function SetTicking(on)
    EM:UnregisterForUpdate(PB.name .. "Tick")
    if on then EM:RegisterForUpdate(PB.name .. "Tick", 200, UpdatePanel) end
end

---------------------------------------------------------------------------
-- Your own row, and debug (solo testing, no group needed)
--   self:   your own buffs, shown by default ("Show myself")
--   target: a row tracking whoever is under your reticle, grouped or not
--   log:    print buff gained/faded/updated events for shown rows to chat
-- The extra effect registrations only exist while those rows are on.
---------------------------------------------------------------------------
local function TargetLabel()
    if not DoesUnitExist("reticleover") then return "[Target] none" end
    local n = IsUnitPlayer("reticleover") and GetUnitDisplayName("reticleover") or GetUnitName("reticleover")
    return "[Target] " .. zo_strformat("<<1>>", n)
end

local function ScanTarget()
    PB.labels[DEBUG_TARGET] = TargetLabel()
    if DoesUnitExist("reticleover") then
        RescanUnit("reticleover", DEBUG_TARGET)
    else
        state[DEBUG_TARGET] = {}
    end
end

local function AddSelfRow()
    if not PB.sv.showSelf then return end
    pinnedTags.player = SELF_KEY
    PB.labels[SELF_KEY] = GetDisplayName()
    table.insert(PB.rows, SELF_KEY)
    RescanUnit("player", SELF_KEY)
end

local function AddDebugRows()
    if PB.debug.target then
        pinnedTags.reticleover = DEBUG_TARGET
        table.insert(PB.rows, DEBUG_TARGET)
        ScanTarget()
    end
end

local function SetDebugEvents()
    local function reg(suffix, tag, on)
        local n = PB.name .. suffix
        EM:UnregisterForEvent(n, EVENT_EFFECT_CHANGED)
        if on then
            EM:RegisterForEvent(n, EVENT_EFFECT_CHANGED, OnEffectChanged)
            EM:AddFilterForEvent(n, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, tag)
        end
    end
    reg("Self", "player", PB.sv.showSelf)
    reg("DbgTarget", "reticleover", PB.debug.target)

    local n = PB.name .. "DbgReticle"
    EM:UnregisterForEvent(n, EVENT_RETICLE_TARGET_CHANGED)
    if PB.debug.target then
        EM:RegisterForEvent(n, EVENT_RETICLE_TARGET_CHANGED, ScanTarget)
    end
end

---------------------------------------------------------------------------
-- Group / pin bookkeeping
-- You're never in the pin lists: your own row is the "Show myself" setting.
---------------------------------------------------------------------------
PB.groupItems = {}   -- "Pin / unpin group member" dropdown
PB.pinItems = {}     -- "Saved pins" dropdown

local function SortByName(a, b) return zo_strlower(a) < zo_strlower(b) end

local function RebuildGroupItems()
    ZO_ClearNumericallyIndexedTable(PB.groupItems)
    for i = 1, GetGroupSize() do
        local dn = GetUnitDisplayName(GetGroupUnitTagByIndex(i))
        if dn and dn ~= "" and not IsSelf(dn) then
            table.insert(PB.groupItems, {
                name = (IsPinned(dn) and "[x] " or "[  ] ") .. dn,
                data = dn,
            })
        end
    end
    if #PB.groupItems == 0 then
        table.insert(PB.groupItems, { name = "No one else in your group", data = nil })
    end
end

-- Every saved pin, grouped or not, so absent players can be removed one by one.
local function RebuildPinItems()
    ZO_ClearNumericallyIndexedTable(PB.pinItems)
    local inGroup = {}
    for i = 1, GetGroupSize() do
        local dn = GetUnitDisplayName(GetGroupUnitTagByIndex(i))
        if dn then inGroup[dn] = true end
    end
    local names = {}
    for dn in pairs(PB.sv.pins) do table.insert(names, dn) end
    table.sort(names, SortByName)
    for _, dn in ipairs(names) do
        table.insert(PB.pinItems, {
            name = dn .. (inGroup[dn] and "  (in group)" or "  (not grouped)"),
            data = dn,
        })
    end
    if #PB.pinItems == 0 then
        table.insert(PB.pinItems, { name = "No saved pins", data = nil })
    end
end

-- Redraw the settings menu (checkmarks, dropdown lists). Deferred one frame
-- so it never runs inside a settings control's own set handler.
local function QueueSettingsRefresh()
    if not (PB.settings and PB.settings.UpdateControls) then return end
    local id = PB.name .. "SettingsRefresh"
    EM:UnregisterForUpdate(id)
    EM:RegisterForUpdate(id, 50, function()
        EM:UnregisterForUpdate(id)
        pcall(PB.settings.UpdateControls, PB.settings)
    end)
end

function PB.Refresh()
    if PB.preview then
        Layout()
        UpdatePanel()
        return
    end

    ZO_ClearTable(pinnedTags)
    ZO_ClearNumericallyIndexedTable(PB.rows)

    AddSelfRow()
    if IsUnitGrouped("player") then
        local seen = {}
        for i = 1, GetGroupSize() do
            local tag = GetGroupUnitTagByIndex(i)
            local dn = GetUnitDisplayName(tag)
            if dn and not IsSelf(dn) and IsPinned(dn) and not seen[dn] then
                seen[dn] = true
                pinnedTags[tag] = dn
                table.insert(PB.rows, dn)
                RescanUnit(tag, dn)
            end
        end
    end

    AddDebugRows()
    RebuildGroupItems()
    RebuildPinItems()
    Layout()
    UpdatePanel()
    SetTicking(#PB.rows > 0)
    QueueSettingsRefresh()
end

local function QueueRefresh()
    local id = PB.name .. "Refresh"
    EM:UnregisterForUpdate(id)
    EM:RegisterForUpdate(id, 250, function()
        EM:UnregisterForUpdate(id)
        PB.Refresh()
    end)
end

local function Notify(msg)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, msg)
end

function PB.SetPinned(dn, pinned)
    if not dn or dn == "" then return end
    if IsSelf(dn) then
        Notify("Ardy’s Buff Tracker: your own row is the 'Show myself' setting")
        return
    end
    PB.sv.pins[dn] = pinned or nil
    state[dn] = nil
    PB.Refresh()
    Notify((pinned and "Pinned " or "Unpinned ") .. dn)
end

function PB.SetBuffEnabled(key, enabled)
    PB.sv.buffs[key] = enabled and true or false
    RebuildBuffs()
    PB.Refresh()   -- rescans so a newly enabled buff shows correctly at once
end

-- "Enable all": on turns every buff on, off turns every buff off.
-- Individual buffs can then be switched on again one by one.
function PB.SetAllBuffs(enabled)
    for _, b in ipairs(PB.BUFFS) do PB.sv.buffs[b.key] = enabled and true or false end
    RebuildBuffs()
    PB.Refresh()
end

function PB.ClearPins()
    ZO_ClearTable(PB.sv.pins)
    for dn in pairs(state) do
        if dn ~= SELF_KEY and dn ~= DEBUG_TARGET then state[dn] = nil end
    end
    PB.Refresh()
end

-- "Only Buffs I Apply": rescans everyone so the panel matches at once.
function PB.SetOnlyMine(on)
    PB.sv.onlyMine = on and true or false
    PB.Refresh()
end

function PB.SetShowSelf(on)
    PB.sv.showSelf = on and true or false
    if not on then state[SELF_KEY] = nil end
    SetDebugEvents()
    PB.Refresh()
end

function PB.SetDebug(flag, on)
    PB.debug[flag] = on and true or false
    if flag == "target" and not on then state[DEBUG_TARGET] = nil end
    SetDebugEvents()
    PB.Refresh()
end

---------------------------------------------------------------------------
-- Group checklist: one checkbox per group slot (up to 11 others), labelled
-- with whoever is in that slot right now, ticked when they're pinned.
-- Labels are functions, so the menu re-reads them every time it redraws.
---------------------------------------------------------------------------
PB.MAX_SLOTS = 11

local function GroupOthers()
    local list = {}
    for i = 1, GetGroupSize() do
        local dn = GetUnitDisplayName(GetGroupUnitTagByIndex(i))
        if dn and dn ~= "" and not IsSelf(dn) then table.insert(list, dn) end
    end
    return list
end

function PB.SlotName(i) return GroupOthers()[i] end

---------------------------------------------------------------------------
-- Saved-pin buttons (controller-friendly, no dropdowns, no typing)
-- "Next / Previous player" steps through group members, then saved pins
-- who aren't grouped. "Pin / unpin selected" flips whoever is selected.
-- Every press pops an on-screen alert saying who and what happened.
---------------------------------------------------------------------------
PB.selected = nil

local function SelectableNames()
    local list, seen = {}, {}
    for i = 1, GetGroupSize() do
        local dn = GetUnitDisplayName(GetGroupUnitTagByIndex(i))
        if dn and dn ~= "" and not IsSelf(dn) and not seen[dn] then
            seen[dn] = true
            table.insert(list, dn)
        end
    end
    local saved = {}
    for dn in pairs(PB.sv.pins) do
        if not seen[dn] then table.insert(saved, dn) end
    end
    table.sort(saved, SortByName)
    for _, dn in ipairs(saved) do table.insert(list, dn) end
    return list, seen
end

local function Describe(dn, grouped)
    return string.format("%s: %s%s", dn, IsPinned(dn) and "PINNED" or "not pinned",
        grouped and "" or " (not grouped)")
end

function PB.SelectStep(step)
    local list, grouped = SelectableNames()
    if #list == 0 then
        PB.selected = nil
        Notify("No group members or saved pins to select")
        return
    end
    local idx = (step > 0) and 0 or 1
    for i, dn in ipairs(list) do
        if dn == PB.selected then idx = i end
    end
    idx = ((idx - 1 + step) % #list) + 1
    PB.selected = list[idx]
    Notify(string.format("%d/%d  %s", idx, #list, Describe(PB.selected, grouped[PB.selected])))
end

function PB.ToggleSelected()
    if not PB.selected then
        Notify("Press 'Next player' first")
        return
    end
    PB.SetPinned(PB.selected, not IsPinned(PB.selected))
end

-- One-shot report of why rows are or aren't showing.
function PB.PrintStatus()
    d("[PB] ---- status ----")
    d(string.format("[PB] grouped: %s (%d members)", IsUnitGrouped("player") and "yes" or "no", GetGroupSize()))
    d("[PB] settings library: " .. ((LibHarvensAddonSettings or LibVotans) and "found" or "|cFF4444missing|r")
        .. ", settings menu: " .. (PB.settings and "built" or "|cFF4444not built|r"))
    d("[PB] show myself: " .. (PB.sv.showSelf and "on" or "off")
        .. ", Only Buffs I Apply: " .. (PB.sv.onlyMine and "on" or "off"))
    d("[PB] selected: " .. (PB.selected or "none"))
    d(string.format("[PB] buffs on: %d of %d", #PB.active, #PB.BUFFS))

    local tagOf = {}
    for tag, dn in pairs(pinnedTags) do tagOf[dn] = tag end
    local any = false
    for dn in pairs(PB.sv.pins) do
        any = true
        local tag = tagOf[dn]
        if tag then
            d(string.format("[PB]   %s: in group as %s, %s, %s", dn, tag,
                IsUnitOnline(tag) and "online" or "|cFF4444offline|r",
                IsUnitInGroupSupportRange(tag) and "in range" or "|cFFDD33out of range|r"))
        else
            d(string.format("[PB]   %s: |cFFDD33not in your group|r", dn))
        end
    end
    if not any then d("[PB]   no players pinned") end

    d(string.format("[PB] debug: target %s, log %s%s",
        PB.debug.target and "on" or "off",
        PB.debug.log and "on" or "off", PB.debug.logAll and " (all buffs)" or ""))
end

function PB.SetScale(pct)
    PB.sv.scale = zo_clamp(pct, 50, 200)
    Layout()
    UpdatePanel()
end

-- Keybind. Handy on PC; on console, use the settings dropdown instead.
function PB.TogglePinTarget()
    if not (DoesUnitExist("reticleover") and IsUnitPlayer("reticleover")) then
        Notify("Ardy’s Buff Tracker: look at a player first")
        return
    end
    local dn = GetUnitDisplayName("reticleover")
    PB.SetPinned(dn, not IsPinned(dn))
end

---------------------------------------------------------------------------
-- Preview (fake rows so you can size and position the panel solo)
---------------------------------------------------------------------------
function PB.TogglePreview()
    PB.preview = not PB.preview
    if not PB.preview then
        for i = 1, 4 do state["@Preview" .. i] = nil end
        PB.Refresh()
        return
    end
    ZO_ClearNumericallyIndexedTable(PB.rows)
    local now = GetFrameTimeSeconds()
    for i = 1, 4 do
        local dn = "@Preview" .. i
        state[dn] = {}
        for _, buff in ipairs(PB.BUFFS) do
            if math.random() > 0.3 then SetSlot(dn, buff, 1, now + math.random(2, 30)) end
        end
        table.insert(PB.rows, dn)
    end
    Layout()
    UpdatePanel()
    SetTicking(true)
end

---------------------------------------------------------------------------
-- Settings (LibHarvensAddonSettings: works in the console add-on menu)
---------------------------------------------------------------------------
-- On console the library is published as LibVotans; in game it is the same
-- library, so either name works here.
local function CreateSettings()
    if PB.settings then return end
    local LHAS = LibHarvensAddonSettings or LibVotans
    if not (LHAS and LHAS.AddAddon) then return end
    local settings = LHAS:AddAddon("Ardy’s Buff Tracker", { allowDefaults = false, allowRefresh = true })
    if not settings then return end
    PB.settings = settings

    -- Labels, ticks and dropdown lists are functions so the menu rebuilds
    -- them each time it refreshes, instead of keeping what it had at login.
    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Players" })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show myself",
        tooltip = "Adds a row for your own buffs. On by default.",
        getFunction = function() return PB.sv.showSelf end,
        setFunction = function(v) PB.SetShowSelf(v) end,
    })
    for i = 1, PB.MAX_SLOTS do
        settings:AddSetting({
            type = LHAS.ST_CHECKBOX,
            label = function() return PB.SlotName(i) or "(empty slot)" end,
            tooltip = "Tick to pin this group member, untick to unpin.",
            getFunction = function()
                local dn = PB.SlotName(i)
                return dn ~= nil and IsPinned(dn)
            end,
            setFunction = function(v)
                local dn = PB.SlotName(i)
                if dn then PB.SetPinned(dn, v) end
            end,
            disable = function() return PB.SlotName(i) == nil end,
        })
    end

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Saved pins" })
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Next player",
        tooltip = "Steps through your group, then saved pins who aren't grouped. Shows who's selected.",
        buttonText = "Next",
        clickHandler = function() PB.SelectStep(1) end,
    })
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Previous player",
        buttonText = "Previous",
        clickHandler = function() PB.SelectStep(-1) end,
    })
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Pin / unpin selected player",
        buttonText = "Pin / Unpin",
        clickHandler = PB.ToggleSelected,
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Unpin a saved player",
        tooltip = "Everyone you've pinned, grouped or not. Pick one to unpin them.",
        items = function() RebuildPinItems(); return PB.pinItems end,
        getFunction = function() return "Select to unpin" end,
        setFunction = function(_, _, item)
            if item and item.data then PB.SetPinned(item.data, false) end
        end,
    })
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Clear all pins",
        buttonText = "Clear",
        clickHandler = PB.ClearPins,
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Buffs to track" })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Only Buffs I Apply",
        tooltip = "Only show buffs you cast. Buffs other group members give your pinned players are ignored.",
        getFunction = function() return PB.sv.onlyMine end,
        setFunction = function(v) PB.SetOnlyMine(v) end,
    })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable all buffs",
        tooltip = "On: track every buff. Off: turn every buff off, then switch on only the ones you want.",
        getFunction = AllBuffsEnabled,
        setFunction = function(v) PB.SetAllBuffs(v) end,
    })
    for _, buff in ipairs(PB.BUFFS) do
        settings:AddSetting({
            type = LHAS.ST_CHECKBOX,
            label = buff.name,
            getFunction = function() return IsBuffEnabled(buff.key) end,
            setFunction = function(v) PB.SetBuffEnabled(buff.key, v) end,
        })
    end

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Panel" })
    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Size (%)",
        min = 50, max = 200, step = 5,
        getFunction = function() return PB.sv.scale end,
        setFunction = function(v) PB.SetScale(v) end,
    })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Lock panel (PC drag)",
        getFunction = function() return PB.sv.locked end,
        setFunction = function(v) PB.sv.locked = v; PB.panel:SetMovable(not v) end,
    })
    local function posSlider(label, key, maxFn)
        settings:AddSetting({
            type = LHAS.ST_SLIDER,
            label = label,
            min = 0, max = maxFn(), step = 5,
            getFunction = function() return PB.sv[key] end,
            setFunction = function(v)
                PB.sv[key] = v
                PB.panel:ClearAnchors()
                PB.panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, PB.sv.x, PB.sv.y)
            end,
        })
    end
    posSlider("Panel X", "x", function() return GuiRoot:GetWidth() end)
    posSlider("Panel Y", "y", function() return GuiRoot:GetHeight() end)
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Preview panel",
        buttonText = "Toggle",
        clickHandler = PB.TogglePreview,
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Debug (resets on reload)" })
    local function debugBox(label, flag, tooltip)
        settings:AddSetting({
            type = LHAS.ST_CHECKBOX,
            label = label,
            tooltip = tooltip,
            getFunction = function() return PB.debug[flag] end,
            setFunction = function(v) PB.SetDebug(flag, v) end,
        })
    end
    debugBox("Track my target", "target", "Adds a row for whoever is under your crosshair, grouped or not.")
    debugBox("Log buff events to chat", "log", "Prints gained / faded / updated events for shown rows.")
    debugBox("Log untracked buffs too", "logAll", "Also prints buffs this add-on isn't tracking, with their IDs.")
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Print status to chat",
        buttonText = "Print",
        clickHandler = PB.PrintStatus,
    })
end

---------------------------------------------------------------------------
-- Slash commands (PC testing)
---------------------------------------------------------------------------
local function ScanUnit(unitTag)
    if not DoesUnitExist(unitTag) then d("[PB] no unit: " .. unitTag) return end
    d(string.format("[PB] buffs on %s (%s):", GetUnitDisplayName(unitTag) or "?", unitTag))
    for i = 1, GetNumBuffs(unitTag) do
        local name, _, _, _, _, iconFile, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, i)
        local buff = allByName[name]
        if buff then LearnIcon(buff, iconFile) end
        d(string.format("  %s  id=%d%s", name, abilityId, buff and " <== tracked" or ""))
    end
    if PB.iconsDirty then ApplyIcons() end
end

local function FindBuff(text)
    text = zo_strlower(text or "")
    if text == "" then return nil end
    for _, b in ipairs(PB.BUFFS) do
        if zo_strlower(b.short) == text or zo_strlower(b.key) == text then return b end
    end
    for _, b in ipairs(PB.BUFFS) do
        if zo_strlower(b.name):find(text, 1, true) then return b end
    end
end

local function HandleSlash(args)
    local cmd, rest = (args or ""):match("^(%S*)%s*(.-)%s*$")
    cmd = zo_strlower(cmd or "")
    if cmd == "pin" and rest ~= "" then
        PB.SetPinned(rest, true)
    elseif cmd == "unpin" and rest ~= "" then
        PB.SetPinned(rest, false)
    elseif cmd == "target" then
        PB.TogglePinTarget()
    elseif cmd == "mine" then
        PB.SetOnlyMine(not PB.sv.onlyMine)
        d("[PB] Only Buffs I Apply " .. (PB.sv.onlyMine and "on" or "off"))
    elseif cmd == "self" then
        PB.SetShowSelf(not PB.sv.showSelf)
        d("[PB] show myself " .. (PB.sv.showSelf and "on" or "off"))
    elseif cmd == "list" then
        RebuildPinItems()
        d("[PB] saved pins:")
        for _, item in ipairs(PB.pinItems) do d("  " .. item.name) end
    elseif cmd == "clear" then
        PB.ClearPins()
    elseif cmd == "all" then
        local arg = zo_strlower(rest)
        local on = (arg == "on") or (arg ~= "off" and not AllBuffsEnabled())
        PB.SetAllBuffs(on)
        d("[PB] all buffs " .. (on and "on" or "off"))
    elseif cmd == "only" then
        local b = FindBuff(rest)
        if not b then d("[PB] no buff matches '" .. rest .. "'") return end
        PB.SetAllBuffs(false)
        PB.SetBuffEnabled(b.key, true)
        d("[PB] tracking only " .. b.name)
    elseif cmd == "buffs" then
        d("[PB] buffs:")
        for _, b in ipairs(PB.BUFFS) do
            d(string.format("  [%s] %s (%s)", IsBuffEnabled(b.key) and "x" or " ", b.name, b.short))
        end
    elseif cmd == "buff" then
        local b = FindBuff(rest)
        if not b then d("[PB] no buff matches '" .. rest .. "'") return end
        PB.SetBuffEnabled(b.key, not IsBuffEnabled(b.key))
        d(string.format("[PB] %s %s", b.name, IsBuffEnabled(b.key) and "on" or "off"))
    elseif cmd == "scale" then
        local pct = tonumber(rest)
        if pct then PB.SetScale(pct) end
        d("[PB] size " .. PB.sv.scale .. "%")
    elseif cmd == "scan" then
        ScanUnit(DoesUnitExist("reticleover") and "reticleover" or "player")
    elseif cmd == "preview" then
        PB.TogglePreview()
    elseif cmd == "debug" then
        local flag = ({ target = "target", log = "log", logall = "logAll" })[zo_strlower(rest)]
        if flag then
            PB.SetDebug(flag, not PB.debug[flag])
            d(string.format("[PB] debug %s %s", rest, PB.debug[flag] and "on" or "off"))
        else
            PB.PrintStatus()
        end
    else
        d("[PB] /pb pin @name | unpin @name | target | self | mine | list | clear")
        d("[PB] /pb buffs | buff <name> | only <name> | all [on|off] | scale <50-200> | scan | preview")
        d("[PB] /pb debug | debug target | debug log | debug logall")
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local DEFAULTS = {
    pins = {},     -- [@account] = true
    buffs = {},    -- [buffKey] = false when turned off (on by default)
    icons = {},    -- [buffKey] = learned icon path
    scale = 75,    -- percent; small by default
    x = 400, y = 300,
    locked = false,
    showSelf = true,
    onlyMine = false,  -- true: only show buffs you (or your pet) applied
}

local function OnLoaded(_, addonName)
    if addonName ~= PB.name then return end
    EM:UnregisterForEvent(PB.name, EVENT_ADD_ON_LOADED)

    PB.sv = ZO_SavedVars:NewAccountWide("ArdysBuffTracker_SV", 1, nil, DEFAULTS)
    PB.sv.pins[GetDisplayName()] = nil   -- never track yourself

    RebuildBuffs()
    CreatePanel()
    CreateSettings()
    -- If the settings library loaded after us, try again once everything is in.
    EM:RegisterForEvent(PB.name .. "Settings", EVENT_PLAYER_ACTIVATED, function()
        EM:UnregisterForEvent(PB.name .. "Settings", EVENT_PLAYER_ACTIVATED)
        CreateSettings()
    end)

    EM:RegisterForEvent(PB.name .. "Grp", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(PB.name .. "Grp", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    SetDebugEvents()   -- registers your own row ("Show myself")

    for _, ev in ipairs({
        EVENT_PLAYER_ACTIVATED,
        EVENT_GROUP_UPDATE,
        EVENT_GROUP_MEMBER_JOINED,
        EVENT_GROUP_MEMBER_LEFT,
        EVENT_GROUP_MEMBER_CONNECTED_STATUS,
    }) do
        EM:RegisterForEvent(PB.name .. "Group" .. ev, ev, QueueRefresh)
    end

    EM:RegisterForEvent(PB.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        Layout()
        UpdatePanel()
    end)

    SLASH_COMMANDS["/pb"] = HandleSlash
end

EM:RegisterForEvent(PB.name, EVENT_ADD_ON_LOADED, OnLoaded)
