-- Goliath Timer
-- Shows all group DDs with Bone Goliath / Pummeling Goliath / Ravenous Goliath slotted:
--  * not transformed: bar fills with ultimate points up to the ultimate cost (green = ultimate ready)
--  * transformed:     bar counts down the remaining Goliath duration
-- Group ultimate data comes from LibGroupCombatStats (group members need the library or an addon
-- that ships it, e.g. Hodor Reflexes).
--
-- This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates.
-- The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc.
-- in the United States and/or other countries. All rights reserved.

-- everything local: single-file add-on, no global table needed
local GT = {}
GT.name = "GoliathTimer"
GT.version = "1.1.2"

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

---------------------------------------------------------------------------
-- Localization (English default, German if client language is German)
---------------------------------------------------------------------------
local STRINGS = {
    en = {
        TITLE = "Goliath",
        TITLE_UNLOCKED = "Goliath (movable)",
        READY = "READY",
        NO_LIB = "LibGroupCombatStats not found - ultimate tracking disabled, only active Goliaths are shown.",
        LIB_FAIL = "Registration with LibGroupCombatStats failed.",
        LIB_INACTIVE = "LibGroupCombatStats is not active.",
        NO_DATA = "no data",
        DEBUG = "Debug %s",
        ON = "on", OFF = "off",
        GONE = "gone", ACTIVE = "active",
        OPT_OWN = "Show own character: %s",
        OPT_ROLES = "Show all roles: %s",
        OPT_ROLES_DD = " (DDs only)",
        OPT_EMPTY = "Hide when list is empty: %s",
        NEED_NUMBER = "Please enter a number, e.g. /gol addid 118279",
        ID_ADDED = "ID %d added (%s)",
        ID_REMOVED = "ID %d removed (%s)",
        ULT_LINE = "%s | role=%d | ult=%d | front=%d (%s, %d) | back=%d (%s, %d)",
        HELP = {
            "Commands:",
            "  /gol unlock | lock  - move / lock window",
            "  /gol test           - test display (fake entries)",
            "  /gol own            - toggle own character",
            "  /gol roles          - toggle all roles instead of DDs only",
            "  /gol empty          - toggle hiding the window when empty",
            "  /gol ults           - print group ultimate data to chat",
            "  /gol debug          - log Goliath effects with ID to chat",
            "  /gol addid <id>     - track additional ability ID",
            "  /gol delid <id>     - remove additional ability ID",
            "  /gol reset          - reset window position",
        },
    },
    de = {
        TITLE = "Goliath",
        TITLE_UNLOCKED = "Goliath (verschiebbar)",
        READY = "BEREIT",
        NO_LIB = "LibGroupCombatStats nicht gefunden - Ulti-Anzeige deaktiviert, nur aktive Goliaths werden angezeigt.",
        LIB_FAIL = "Registrierung bei LibGroupCombatStats fehlgeschlagen.",
        LIB_INACTIVE = "LibGroupCombatStats ist nicht aktiv.",
        NO_DATA = "keine Daten",
        DEBUG = "Debug %s",
        ON = "an", OFF = "aus",
        GONE = "weg", ACTIVE = "aktiv",
        OPT_OWN = "Eigenen Charakter anzeigen: %s",
        OPT_ROLES = "Alle Rollen anzeigen: %s",
        OPT_ROLES_DD = " (nur DDs)",
        OPT_EMPTY = "Bei leerer Liste ausblenden: %s",
        NEED_NUMBER = "Bitte eine Zahl angeben, z.B. /gol addid 118279",
        ID_ADDED = "ID %d hinzugefügt (%s)",
        ID_REMOVED = "ID %d entfernt (%s)",
        ULT_LINE = "%s | Rolle=%d | Ulti=%d | Front=%d (%s, %d) | Back=%d (%s, %d)",
        HELP = {
            "Befehle:",
            "  /gol unlock | lock  - Fenster verschieben / fixieren",
            "  /gol test           - Testanzeige (Fake-Einträge)",
            "  /gol own            - eigenen Charakter anzeigen an/aus",
            "  /gol roles          - alle Rollen statt nur DDs anzeigen an/aus",
            "  /gol empty          - Fenster bei leerer Liste ausblenden an/aus",
            "  /gol ults           - Ulti-Daten der Gruppe im Chat ausgeben",
            "  /gol debug          - Goliath-Effekte mit ID im Chat loggen",
            "  /gol addid <id>     - zusätzliche Ability-ID tracken",
            "  /gol delid <id>     - zusätzliche Ability-ID entfernen",
            "  /gol reset          - Position zurücksetzen",
        },
    },
}
local L = STRINGS[GetCVar("language.2")] or STRINGS.en

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------
-- Known ability IDs (base + morphs). Used for the buff AND for detecting the slotted ultimate.
-- If a patch changes IDs: find the real ID via /gol debug and add it via /gol addid <id>.
local DEFAULT_IDS = {
    [115001] = true, -- Bone Goliath Transformation
    [118664] = true, -- Pummeling Goliath
    [118279] = true, -- Ravenous Goliath
}

local defaults = {
    left = 400,
    top = 300,
    locked = true,
    hideWhenEmpty = true,
    showOwn = true,
    allRoles = false,
    extraIds = {},
}

local MAX_ROWS = 12
local ROW_H = 26
local WIDTH = 240
local UPDATE_NS = "GoliathTimer_Update"
local UPDATE_MS = 100

local COLOR_ACTIVE   = { 0.60, 0.35, 0.85, 0.85 } -- transformed
local COLOR_ENDING   = { 0.85, 0.35, 0.20, 0.85 } -- transformed, < 5s left
local COLOR_CHARGING = { 0.80, 0.65, 0.20, 0.85 } -- ultimate charging
local COLOR_READY    = { 0.30, 0.80, 0.30, 0.90 } -- ultimate ready

local MODE_ACTIVE, MODE_READY, MODE_CHARGING = 1, 2, 3

local active = {}       -- [charName] = { name, beginTime, endTime, icon }
local testCharging = {} -- [charName] = { name, startTime, startValue, rate, cost, icon, expires }
local rows = {}
local registered = {}
local updating = false
local debugMode = false
local lgcs = nil        -- LibGroupCombatStats object (optional)

-- Reused per-tick buffers (avoid creating garbage every update)
local list = {}         -- array of entry tables, valid up to listCount
local listCount = 0
local entryPool = {}
local seen = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Print(msg)
    d("|c88CC55[GoliathTimer]|r " .. msg)
end

local function OnOff(v)
    return v and L.ON or L.OFF
end

local function IsTrackedId(id)
    return id and id ~= 0 and (DEFAULT_IDS[id] or GT.sv.extraIds[id])
end

local function CleanName(name)
    if not name or name == "" then return "?" end
    return zo_strformat("<<1>>", name)
end

local function SetBarColor(bar, c)
    bar:SetColor(c[1], c[2], c[3], c[4])
end

local function IsDD(tag)
    if GT.sv.allRoles then return true end
    if not IsUnitGrouped("player") then return true end -- solo: role irrelevant
    return GetGroupMemberSelectedRole(tag) == LFG_ROLE_DPS
end

-- Returns ultValue, cost, abilityId if the unit has Goliath slotted on a bar, otherwise nil.
local function GetGoliathUltInfo(tag)
    if not lgcs then return nil end
    local ult = lgcs:GetUnitULT(tag)
    if not ult then return nil end

    local cost, id
    if IsTrackedId(ult.ult1ID) and (ult.ult1Cost or 0) > 0 then
        cost, id = ult.ult1Cost, ult.ult1ID
    end
    if IsTrackedId(ult.ult2ID) and (ult.ult2Cost or 0) > 0 then
        if not cost or ult.ult2Cost < cost then
            cost, id = ult.ult2Cost, ult.ult2ID
        end
    end
    if not id then
        -- Goliath slotted but cost not yet known -> local estimate
        id = IsTrackedId(ult.ult1ID) and ult.ult1ID or (IsTrackedId(ult.ult2ID) and ult.ult2ID) or nil
        if not id then return nil end
        cost = GetAbilityCost(id, COMBAT_MECHANIC_FLAGS_ULTIMATE)
    end

    local value = ult.ultValue or 0
    if AreUnitsEqual(tag, "player") then
        value = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE) -- own value: exact and without delay
    end
    return value, math.max(cost or 0, 1), id
end

local function ForEachGroupTag(fn)
    if IsUnitGrouped("player") then
        for i = 1, GetGroupSize() do
            local tag = GetGroupUnitTagByIndex(i)
            if DoesUnitExist(tag) then fn(tag) end
        end
    else
        fn("player")
    end
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------
local function AddEntry(mode, name, icon)
    listCount = listCount + 1
    local e = entryPool[listCount]
    if not e then
        e = {}
        entryPool[listCount] = e
    end
    e.mode, e.name, e.icon = mode, name, icon
    e.beginTime, e.endTime, e.value, e.cost = 0, 0, 0, 1
    list[listCount] = e
    return e
end

local function AddActive(name, a)
    local e = AddEntry(MODE_ACTIVE, name, a.icon)
    e.beginTime, e.endTime = a.beginTime, a.endTime
end

local function AddCharging(name, icon, value, cost)
    local e = AddEntry(value >= cost and MODE_READY or MODE_CHARGING, name, icon)
    e.value, e.cost = value, cost
end

local function CollectUnit(tag)
    if not GT.sv.showOwn and AreUnitsEqual(tag, "player") then return end

    local name = CleanName(GetUnitName(tag))
    seen[name] = true
    local a = active[name]
    if a then
        AddActive(name, a)
    elseif IsDD(tag) then
        local value, cost, id = GetGoliathUltInfo(tag)
        if value then
            AddCharging(name, GetAbilityIcon(id), value, cost)
        end
    end
end

-- Sorting: active Goliaths (shortest remaining first), then ready, then by charge progress
local function CompareEntries(a, b)
    if a.mode ~= b.mode then return a.mode < b.mode end
    if a.mode == MODE_ACTIVE then return a.endTime < b.endTime end
    local pa, pb = a.value / a.cost, b.value / b.cost
    if pa ~= pb then return pa > pb end
    return a.name < b.name
end

local function BuildList(now)
    for i = listCount, 1, -1 do list[i] = nil end
    listCount = 0
    ZO_ClearTable(seen)

    for key, e in pairs(active) do
        if e.endTime <= now then active[key] = nil end
    end
    for key, t in pairs(testCharging) do
        if t.expires <= now then testCharging[key] = nil end
    end

    -- real group members
    ForEachGroupTag(CollectUnit)

    -- Goliath buffs of units not (or no longer) in the group (e.g. test entries)
    for key, a in pairs(active) do
        if not seen[key] then
            seen[key] = true
            AddActive(a.name, a)
        end
    end

    -- test entries "charging"
    for key, t in pairs(testCharging) do
        if not seen[key] then
            AddCharging(t.name, t.icon, math.min(t.startValue + (now - t.startTime) * t.rate, 500), t.cost)
        end
    end

    table.sort(list, CompareEntries)
end

local function UpdateDisplay()
    local now = GetFrameTimeSeconds()
    BuildList(now)

    local count = math.min(listCount, MAX_ROWS)
    for i = 1, MAX_ROWS do
        local r = rows[i]
        local e = list[i]
        if e then
            r.name:SetText(e.name)
            r.icon:SetTexture(e.icon)
            if e.mode == MODE_ACTIVE then
                -- remaining duration, bar runs down to the left
                local remain = e.endTime - now
                local dur = math.max(e.endTime - e.beginTime, 0.1)
                r.bar:SetValue(zo_clamp(remain / dur, 0, 1))
                r.time:SetText(string.format("%.1f", remain))
                SetBarColor(r.bar, remain < 5 and COLOR_ENDING or COLOR_ACTIVE)
            elseif e.mode == MODE_READY then
                r.bar:SetValue(1)
                r.time:SetText(L.READY)
                SetBarColor(r.bar, COLOR_READY)
            else
                -- charging: bar fills to the right up to the ultimate cost
                r.bar:SetValue(zo_clamp(e.value / e.cost, 0, 1))
                r.time:SetText(string.format("%d/%d", math.floor(e.value), math.floor(e.cost)))
                SetBarColor(r.bar, COLOR_CHARGING)
            end
            r.ctrl:SetHidden(false)
        else
            r.ctrl:SetHidden(true)
        end
    end

    GT.win:SetHeight(ROW_H * (count + 1) + 4)
    local hide = count == 0 and GT.sv.locked and GT.sv.hideWhenEmpty
    GT.content:SetHidden(hide)

    if count == 0 and updating then
        EM:UnregisterForUpdate(UPDATE_NS)
        updating = false
    end
    return count
end

function GT.Refresh()
    local count = UpdateDisplay()
    if count > 0 and not updating then
        EM:RegisterForUpdate(UPDATE_NS, UPDATE_MS, UpdateDisplay)
        updating = true
    end
end

local function CreateUI()
    local win = WM:CreateTopLevelWindow("GoliathTimerWindow")
    win:SetDimensions(WIDTH, ROW_H * (MAX_ROWS + 1))
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(not GT.sv.locked)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GT.sv.left, GT.sv.top)
    win:SetHandler("OnMoveStop", function(self)
        GT.sv.left = self:GetLeft()
        GT.sv.top = self:GetTop()
    end)

    local content = WM:CreateControl("$(parent)Content", win, CT_CONTROL)
    content:SetAnchorFill(win)

    local bg = WM:CreateControl("$(parent)BG", content, CT_BACKDROP)
    bg:SetAnchorFill(content)
    bg:SetCenterColor(0, 0, 0, 0.5)
    bg:SetEdgeColor(0, 0, 0, 0)

    local title = WM:CreateControl("$(parent)Title", content, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.8, 0.9, 0.6, 1)
    title:SetAnchor(TOPLEFT, content, TOPLEFT, 6, 2)
    title:SetText(L.TITLE)
    GT.title = title

    for i = 1, MAX_ROWS do
        local row = WM:CreateControl("$(parent)Row" .. i, content, CT_CONTROL)
        row:SetDimensions(WIDTH - 8, ROW_H - 4)
        row:SetAnchor(TOPLEFT, content, TOPLEFT, 4, ROW_H * i)

        local icon = WM:CreateControl("$(parent)Icon", row, CT_TEXTURE)
        icon:SetDimensions(ROW_H - 4, ROW_H - 4)
        icon:SetAnchor(LEFT, row, LEFT, 0, 0)

        local barBg = WM:CreateControl("$(parent)BarBG", row, CT_BACKDROP)
        barBg:SetAnchor(TOPLEFT, icon, TOPRIGHT, 4, 0)
        barBg:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
        barBg:SetCenterColor(0.15, 0.15, 0.15, 0.8)
        barBg:SetEdgeColor(0, 0, 0, 1)

        local bar = WM:CreateControl("$(parent)Bar", row, CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT, barBg, TOPLEFT, 1, 1)
        bar:SetAnchor(BOTTOMRIGHT, barBg, BOTTOMRIGHT, -1, -1)
        bar:SetMinMax(0, 1)
        bar:SetDrawLevel(2)

        local name = WM:CreateControl("$(parent)Name", row, CT_LABEL)
        name:SetFont("ZoFontGameSmall")
        name:SetAnchor(LEFT, bar, LEFT, 4, 0)
        name:SetDrawLevel(3)

        local time = WM:CreateControl("$(parent)Time", row, CT_LABEL)
        time:SetFont("ZoFontGameBold")
        time:SetAnchor(RIGHT, bar, RIGHT, -4, 0)
        time:SetDrawLevel(3)

        row:SetHidden(true)
        rows[i] = { ctrl = row, icon = icon, bar = bar, name = name, time = time }
    end

    GT.win = win
    GT.content = content

    -- only show in HUD, not in menus
    local fragment = ZO_HUDFadeSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function ApplyLock()
    GT.win:SetMovable(not GT.sv.locked)
    GT.title:SetText(GT.sv.locked and L.TITLE or L.TITLE_UNLOCKED)
    GT.Refresh()
end

---------------------------------------------------------------------------
-- Effect tracking (Goliath form active)
---------------------------------------------------------------------------
local function OnEffectChanged(_, changeType, _, _, unitTag, beginTime, endTime, _, iconName, _, _, _, _, unitName, _, abilityId)
    if not IsTrackedId(abilityId) then return end
    if not GT.sv.showOwn and AreUnitsEqual(unitTag, "player") then return end

    local key = CleanName(unitName ~= "" and unitName or GetUnitName(unitTag))
    if changeType == EFFECT_RESULT_FADED then
        active[key] = nil
    else
        active[key] = { name = key, beginTime = beginTime, endTime = endTime, icon = iconName }
    end
    GT.Refresh()
end

local function ScanUnit(tag)
    if not DoesUnitExist(tag) then return end
    if not GT.sv.showOwn and AreUnitsEqual(tag, "player") then return end
    for i = 1, GetNumBuffs(tag) do
        local _, timeStarted, timeEnding, _, _, iconFile, _, _, _, _, abilityId = GetUnitBuffInfo(tag, i)
        if IsTrackedId(abilityId) then
            local key = CleanName(GetUnitName(tag))
            active[key] = { name = key, beginTime = timeStarted, endTime = timeEnding, icon = iconFile }
        end
    end
end

function GT.FullScan()
    ZO_ClearTable(active)
    ForEachGroupTag(ScanUnit)
    GT.Refresh()
end

local function RegisterEffectEvents()
    for ns in pairs(registered) do
        EM:UnregisterForEvent(ns, EVENT_EFFECT_CHANGED)
    end
    ZO_ClearTable(registered)

    local ids = {}
    for id in pairs(DEFAULT_IDS) do ids[id] = true end
    for id in pairs(GT.sv.extraIds) do ids[id] = true end

    local specs = {
        { "grp", REGISTER_FILTER_UNIT_TAG_PREFIX, "group" },
        { "ply", REGISTER_FILTER_UNIT_TAG, "player" },
    }
    for id in pairs(ids) do
        for _, s in ipairs(specs) do
            local ns = GT.name .. "_" .. s[1] .. "_" .. id
            EM:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnEffectChanged)
            EM:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_ABILITY_ID, id,
                s[2], s[3])
            registered[ns] = true
        end
    end
end

---------------------------------------------------------------------------
-- Ultimate data (LibGroupCombatStats)
---------------------------------------------------------------------------
local function OnUltUpdate()
    if not updating then GT.Refresh() end
end

local function InitCombatStats()
    if not LibGroupCombatStats then
        Print(L.NO_LIB)
        return
    end
    lgcs = LibGroupCombatStats.RegisterAddon(GT.name, { "ULT" })
    if not lgcs then
        Print(L.LIB_FAIL)
        return
    end
    lgcs:RegisterForEvent(LibGroupCombatStats.EVENT_GROUP_ULT_UPDATE, OnUltUpdate)
    lgcs:RegisterForEvent(LibGroupCombatStats.EVENT_PLAYER_ULT_UPDATE, OnUltUpdate)
end

---------------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------------
local function OnDebugEffect(_, changeType, _, effectName, _, beginTime, endTime, _, _, _, _, _, _, unitName, _, abilityId)
    if string.find(zo_strlower(effectName), "goliath", 1, true) then
        Print(string.format("%s | %s | id=%d | %s | %.1fs",
            CleanName(unitName), effectName, abilityId,
            changeType == EFFECT_RESULT_FADED and L.GONE or L.ACTIVE,
            endTime - beginTime))
    end
end

local function SetDebug(on)
    debugMode = on
    for _, s in ipairs({ { "grp", REGISTER_FILTER_UNIT_TAG_PREFIX, "group" }, { "ply", REGISTER_FILTER_UNIT_TAG, "player" } }) do
        local ns = GT.name .. "_debug_" .. s[1]
        if on then
            EM:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnDebugEffect)
            EM:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, s[2], s[3])
        else
            EM:UnregisterForEvent(ns, EVENT_EFFECT_CHANGED)
        end
    end
    Print(string.format(L.DEBUG, OnOff(on)))
end

local function DumpUlts()
    if not lgcs then
        Print(L.LIB_INACTIVE)
        return
    end
    ForEachGroupTag(function(tag)
        local ult = lgcs:GetUnitULT(tag)
        local name = CleanName(GetUnitName(tag))
        if ult then
            Print(string.format(L.ULT_LINE,
                name, GetGroupMemberSelectedRole(tag), ult.ultValue or 0,
                ult.ult1ID or 0, GetAbilityName(ult.ult1ID or 0), ult.ult1Cost or 0,
                ult.ult2ID or 0, GetAbilityName(ult.ult2ID or 0), ult.ult2Cost or 0))
        else
            Print(name .. " | " .. L.NO_DATA)
        end
    end)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Help()
    for i, line in ipairs(L.HELP) do
        if i == 1 then Print(line) else d(line) end
    end
end

local function StartTest()
    local now = GetFrameTimeSeconds()
    local icon = GetAbilityIcon(118279)
    active["Test DD 1"] = { name = "Test DD 1", beginTime = now, endTime = now + 20, icon = icon }
    active["Test DD 2"] = { name = "Test DD 2", beginTime = now - 17, endTime = now + 3, icon = icon }
    testCharging["Test DD 3"] = { name = "Test DD 3", startTime = now, startValue = 40, rate = 15, cost = 225, icon = icon, expires = now + 25 }
    testCharging["Test DD 4"] = { name = "Test DD 4", startTime = now, startValue = 160, rate = 10, cost = 225, icon = icon, expires = now + 25 }
    testCharging["Test DD 5"] = { name = "Test DD 5", startTime = now, startValue = 250, rate = 0, cost = 225, icon = icon, expires = now + 25 }
    GT.Refresh()
end

local function OnSlash(args)
    local cmd, arg = zo_strsplit(" ", zo_strlower(args or ""))
    if cmd == "unlock" then
        GT.sv.locked = false
        ApplyLock()
    elseif cmd == "lock" then
        GT.sv.locked = true
        ApplyLock()
    elseif cmd == "test" then
        StartTest()
    elseif cmd == "own" then
        GT.sv.showOwn = not GT.sv.showOwn
        Print(string.format(L.OPT_OWN, OnOff(GT.sv.showOwn)))
        GT.FullScan()
    elseif cmd == "roles" then
        GT.sv.allRoles = not GT.sv.allRoles
        Print(string.format(L.OPT_ROLES, OnOff(GT.sv.allRoles)) .. (GT.sv.allRoles and "" or L.OPT_ROLES_DD))
        GT.Refresh()
    elseif cmd == "empty" then
        GT.sv.hideWhenEmpty = not GT.sv.hideWhenEmpty
        Print(string.format(L.OPT_EMPTY, OnOff(GT.sv.hideWhenEmpty)))
        GT.Refresh()
    elseif cmd == "ults" then
        DumpUlts()
    elseif cmd == "debug" then
        SetDebug(not debugMode)
    elseif cmd == "addid" or cmd == "delid" then
        local id = tonumber(arg)
        if not id then
            Print(L.NEED_NUMBER)
            return
        end
        GT.sv.extraIds[id] = (cmd == "addid") or nil
        RegisterEffectEvents()
        GT.FullScan()
        Print(string.format(cmd == "addid" and L.ID_ADDED or L.ID_REMOVED, id, GetAbilityName(id)))
    elseif cmd == "reset" then
        GT.sv.left, GT.sv.top = defaults.left, defaults.top
        GT.win:ClearAnchors()
        GT.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GT.sv.left, GT.sv.top)
    else
        Help()
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function OnGroupChanged()
    zo_callLater(GT.FullScan, 500)
end

local function OnHotbarsUpdated()
    zo_callLater(GT.Refresh, 500)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= GT.name then return end
    EM:UnregisterForEvent(GT.name, EVENT_ADD_ON_LOADED)

    GT.sv = ZO_SavedVars:NewAccountWide("GoliathTimer_SV", 1, nil, defaults)

    CreateUI()
    InitCombatStats()
    ApplyLock()
    RegisterEffectEvents()

    EM:RegisterForEvent(GT.name, EVENT_PLAYER_ACTIVATED, GT.FullScan)
    EM:RegisterForEvent(GT.name .. "_join", EVENT_GROUP_MEMBER_JOINED, OnGroupChanged)
    EM:RegisterForEvent(GT.name .. "_left", EVENT_GROUP_MEMBER_LEFT, OnGroupChanged)
    EM:RegisterForEvent(GT.name .. "_upd", EVENT_GROUP_UPDATE, OnGroupChanged)
    EM:RegisterForEvent(GT.name .. "_role", EVENT_GROUP_MEMBER_ROLE_CHANGED, OnGroupChanged)
    EM:RegisterForEvent(GT.name .. "_slot", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnHotbarsUpdated)

    SLASH_COMMANDS["/gol"] = OnSlash
end

EM:RegisterForEvent(GT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
