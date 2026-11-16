-- Trackers page: the tracker list (left) and the tracker editor (right) with six tabs:
-- Trigger, Display, Text & colors, Conditions, Load, Position.

local DT = DebuffTracker
local UI = DT.UI
local W = UI.W
local U = DT.Util
local C = DT.Const
local S = DT.Schema
local P = DT.Profiles
local L = DT.L
local WM = WINDOW_MANAGER

local LIST_W = 300
local DUMMY = S.NewTracker({ name = "" })

local function T() return UI.Current() or DUMMY end
-- The trigger being edited: the main one (index 0) or one of the extra triggers.
UI.triggerIndex, UI.triggerFor = 0, nil
local function TriggerIndex()
    local t = T()
    if UI.triggerFor ~= t.id then UI.triggerFor, UI.triggerIndex = t.id, 0 end
    local i = UI.triggerIndex or 0
    if i > 0 and not (t.extraTriggers and t.extraTriggers[i]) then i = 0; UI.triggerIndex = 0 end
    return i
end
local function TR()
    local t, i = T(), TriggerIndex()
    if i > 0 then return t.extraTriggers[i] end
    return t.trigger
end
local function DS() return T().display end
local function HasTracker() return UI.Current() ~= nil end

local function TypeSummary(t)
    local tr = t.trigger
    local what
    if tr.type == "effect" then what = C.Label(C.SCOPES, tr.scope)
    elseif tr.type == "combat" then what = L("Ability timer")
    elseif tr.type == "procs" then what = L("My procs")
    elseif tr.type == "toggle" then what = L("Toggle on/off")
    elseif tr.type == "stat" then what = C.Label(C.STATS, tr.stat)
    elseif tr.type == "combatState" then what = L("Combat state")
    elseif tr.type == "tick" then what = L("Resource tick") .. ": " .. C.Label(C.TICK_POWER_TYPES, tr.powerType)
    elseif tr.type == "gcd" then what = L("Global cooldown")
    else what = C.Label(C.POWER_TYPES, tr.powerType) end
    return C.Label(C.DISPLAY_TYPES, t.display.type) .. " - " .. what
end

------------------------------------------------------------------------------
-- New tracker templates
------------------------------------------------------------------------------

local TEMPLATES = {
    { L("Debuffs on enemies (bars)"), 62787, function() return {
        name = L("Enemy debuffs"), trigger = { type = "effect", scope = "enemies", effectType = "debuff" },
        display = { type = "bars", labelFormat = "{unit}" } } end },
    { L("Buff or debuff on my target (icons)"), 81519, function() return {
        name = L("Target effects"), trigger = { type = "effect", scope = "target" },
        display = { type = "icons" } } end },
    { L("Checklist on the boss (lit / missing)"), 17906, function() return {
        name = L("Boss checklist"), trigger = { type = "effect", scope = "boss", mode = "always", perAbility = true },
        display = { type = "icons" }, load = { bossOnly = true } } end },
    { L("My buffs (icons)"), 61665, function() return {
        name = L("My buffs"), trigger = { type = "effect", scope = "player", effectType = "buff" },
        display = { type = "icons" } } end },
    { L("Group members missing a buff"), 61771, function() return {
        name = L("Missing buff"), trigger = { type = "effect", scope = "group", mode = "missing", effectType = "buff" },
        display = { type = "bars", labelFormat = "{unit}", showTimer = false } } end },
    { L("Big alert when something is missing"), 62988, function() return {
        name = L("Missing alert"), trigger = { type = "effect", scope = "boss", mode = "missing" },
        display = { type = "alert", alertFormat = L("{name} missing!") }, load = { combat = "in", bossOnly = true } } end },
    { L("Above heads: allies missing a buff"), 61771, function() return {
        name = L("Missing buff (above heads)"), trigger = { type = "effect", scope = "group", mode = "missing", effectType = "buff" },
        display = { type = "heads", iconSize = 36, showTimer = false, maxShown = 1 } } end },
    { L("Above heads: my buffs / heals on allies"), 61665, function() return {
        name = L("My buffs on allies"), trigger = { type = "effect", scope = "group", source = "me", effectType = "buff" },
        display = { type = "heads", iconSize = 32, maxShown = 3 } } end },
    { L("Ability / proc timer"), 38541, function() return {
        name = L("Ability timer"), trigger = { type = "combat", combatSource = "me", duration = 10, showReady = true },
        display = { type = "icons", iconLabelFormat = "{name}" } } end },
    { L("My procs: set / synergy / passive cooldowns (like Cooldowns)"), 61459, function() return {
        name = L("My procs"), trigger = { type = "procs" },
        display = { type = "icons", iconSize = 48, iconLabelFormat = "" }, load = { combat = "any" } } end },
    { L("Resource bar (health, ultimate...)"), nil, function() return {
        name = L("Resource"), trigger = { type = "resource", unit = "target", powerType = "health" },
        display = { type = "bars", labelFormat = "{unit}", colorMode = "solid" } } end },
}

local function NewTrackerFlow()
    local choices = {}
    for _, tmpl in ipairs(TEMPLATES) do
        choices[#choices + 1] = { tmpl[1], tmpl[2] and GetAbilityIcon(tmpl[2]) or nil, function()
            local t = P.AddTracker(tmpl[3]())
            UI.selectedId = t.id
            UI.SelectTab(1)
            UI.Refresh()
        end }
    end
    choices[#choices + 1] = { L("Browse the preset library..."), nil, function() UI.SelectPage(2) end }
    UI.ShowChoices(L("New tracker"), L("Pick a starting point. Everything can be changed afterwards."), choices)
end
UI.NewTrackerFlow = NewTrackerFlow

------------------------------------------------------------------------------
-- Import / export
------------------------------------------------------------------------------

-- a copy without internal bookkeeping (JSON is for people / AI assistants to read and edit). A single
-- tracker drops its id; a bundle keeps them, since "Attach to" (position.anchorTo) refers to them.
local function ForJSON(t, keepId)
    local c = S.Compact(t)                 -- only what differs from the defaults
    c.id = keepId and t.id or nil
    c.fromCooldowns, c.fromUntaunted, c.fromBTG, c.fromStagger, c.fromExoY, c.fromMeterskull, c.fromMiat, c.fromGcd, c.headsRestore = nil, nil, nil, nil, nil, nil, nil, nil, nil
    return c
end

function UI.ExportTracker(t)
    UI.ShowExport(L("Export: <<1>>", t.name), DT.Serializer.Export("T", t), DT.Serializer.ToJSON(ForJSON(t)))
end

function UI.ExportAll()
    local list = {}
    for _, t in ipairs(P.ActiveTrackers()) do list[#list + 1] = ForJSON(t, true) end
    UI.ShowExport(L("Export all trackers"), DT.Serializer.Export("B", P.ActiveTrackers()), DT.Serializer.ToJSON({ trackers = list }))
end

local function ImportHyperTools(text)
    local trackers, notesOrErr = DT.HyperTools.Import(text)
    if not trackers then UI.Message(L("Import failed"), notesOrErr) return end
    UI.CloseOverlay()
    local added = P.AddTrackers(trackers)
    UI.selectedId = added[1] and added[1].id
    local body = L("Added <<1>> tracker(s) from HyperTools.", #added)
    if #notesOrErr > 0 then body = body .. "\n" .. table.concat(notesOrErr, "\n") end
    UI.Message(L("Imported from HyperTools"), body)
    UI.Refresh()
end

function UI.ImportFlow()
    UI.ShowImport(L("Import"), L("Paste a DebuffTracker or HyperTools export string (Ctrl+V): a tracker, a bundle, or a profile -- or tracker JSON (for example written by an AI assistant)."), function(text)
        if DT.HyperTools.LooksLike(text) then return ImportHyperTools(text) end
        local kind, value
        if DT.Serializer.LooksLikeJSON(text) then
            kind, value = DT.Serializer.ImportJSON(text)       -- written by hand or by an AI assistant
        else
            kind, value = DT.Serializer.Import(text)
        end
        if not kind then UI.Message(L("Import failed"), value) return end
        -- someone else's Cooldowns-import marker must not make YOUR next Cooldowns import delete these
        local function Unmark(list) for _, t in ipairs(list) do if type(t) == "table" then t.fromCooldowns, t.fromUntaunted, t.fromBTG, t.fromStagger, t.fromExoY, t.fromMeterskull, t.fromMiat, t.fromGcd = nil, nil, nil, nil, nil, nil, nil, nil end end end
        if kind == "T" then Unmark({ value }) elseif kind == "B" then Unmark(value)
        elseif kind == "P" and type(value.profile) == "table" and type(value.profile.trackers) == "table" then
            for _, t in pairs(value.profile.trackers) do if type(t) == "table" then t.fromCooldowns, t.fromUntaunted, t.fromBTG, t.fromStagger, t.fromExoY, t.fromMeterskull, t.fromMiat, t.fromGcd = nil, nil, nil, nil, nil, nil, nil, nil end end
        end
        UI.CloseOverlay()
        if kind == "T" then
            local t = P.AddTrackers({ value })[1]
            UI.selectedId = t and t.id
            UI.Message(L("Imported"), L("Added tracker \"<<1>>\".", t and t.name or "?"))
        elseif kind == "B" then
            local added = P.AddTrackers(value)
            UI.Message(L("Imported"), L("Added <<1>> trackers.", #added))
        elseif kind == "P" then
            local name = P.Create(value.name or L("Imported profile"))
            P.SV().profiles[name] = P.Repair(value.profile or {})
            UI.Message(L("Imported"), L("Created profile \"<<1>>\". Activate it on the Profiles page.", name))
        end
        UI.Refresh()
    end)
end

------------------------------------------------------------------------------
-- Tracker list (left column)
------------------------------------------------------------------------------

local listFilter = ""

-- Multi-select: "Select" mode (plain clicks tick rows) or Ctrl+click (add / remove) and Shift+click
-- (a range) at any time. Bulk actions: delete, on / off, export, duplicate.
UI.multi = {}               -- [trackerId] = true
UI.selectMode = false
local lastClicked
local shownIds = {}         -- ids in list order (after the filter), for Shift ranges

local function MultiCount() return U.Count(UI.multi) end
function UI.ClearSelection() UI.multi = {}; UI.selectMode = false end

local function KeyDown(fn) return type(fn) == "function" and fn() == true end

local function SelectedTrackers()
    local out = {}
    for _, t in ipairs(P.ActiveTrackers()) do
        if UI.multi[t.id] then out[#out + 1] = t end
    end
    return out
end
UI.SelectedTrackers = SelectedTrackers

local function OnRowClicked(id)
    local ctrl = KeyDown(IsControlKeyDown) or KeyDown(IsCommandKeyDown)
    local shift = KeyDown(IsShiftKeyDown)
    if shift and lastClicked then
        local a, b = U.IndexOf(shownIds, lastClicked), U.IndexOf(shownIds, id)
        if a and b then
            if a > b then a, b = b, a end
            for i = a, b do UI.multi[shownIds[i]] = true end
            UI.selectMode = true
        end
    elseif ctrl or UI.selectMode then
        -- the row being edited joins the selection when you start Ctrl-picking
        if not UI.selectMode and UI.selectedId and UI.selectedId ~= id then UI.multi[UI.selectedId] = true end
        UI.multi[id] = (not UI.multi[id]) or nil
        UI.selectMode = true
    else
        UI.multi = {}
    end
    lastClicked = id
    UI.selectedId = id
    UI.Refresh()
end

local function BulkDelete()
    local list = SelectedTrackers()
    if #list == 0 then return end
    UI.Confirm(L("Delete trackers"), L("Delete <<1>> selected tracker(s)? This can't be undone (export them first if unsure).", #list), function()
        for _, t in ipairs(list) do P.RemoveTracker(t.id) end
        UI.ClearSelection()
        UI.selectedId = nil
        UI.Refresh()
    end)
end
UI.BulkDelete = BulkDelete

local function BulkEnable(on)
    for _, t in ipairs(SelectedTrackers()) do t.enabled = on end
    DT.Engine.Rebuild()
    UI.Refresh()
end

local function BuildList(page, parent, height)
    local col = WM:CreateControl(nil, parent, CT_CONTROL)
    col:SetWidth(LIST_W)
    col:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    col:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0)

    local header = W.Label(col, L("Trackers"), "ZoFontWinH4", { 0.85, 0.75, 0.45, 1 })
    header:SetAnchor(TOPLEFT, col, TOPLEFT, 0, 0)
    local selectBtn = W.FlatButton(col, 70, 22, L("Select"), function()
        UI.selectMode = not UI.selectMode
        if not UI.selectMode then UI.multi = {} end
        UI.Refresh()
    end, L("Pick several trackers for bulk actions (or Ctrl+click / Shift+click rows any time)"))
    selectBtn:SetAnchor(TOPRIGHT, col, TOPRIGHT, 0, 0)
    local count = W.Label(col, "", "ZoFontGameSmall", { 0.6, 0.6, 0.6, 1 }, TEXT_ALIGN_RIGHT)
    count:SetAnchor(RIGHT, selectBtn, LEFT, -8, 0)

    local search = W.Edit(col, LIST_W, nil, function() return listFilter end, nil, nil,
        { noRefresh = true, placeholder = L("Filter by name..."), onChange = function(text) listFilter = text; page.RefreshList() end })
    search:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 6)

    local scroll = W.ScrollContainer("DebuffTracker5_TrackerListScroll", col)
    scroll:SetAnchor(TOPLEFT, search, BOTTOMLEFT, 0, 6)
    scroll:SetAnchor(BOTTOMRIGHT, col, BOTTOMRIGHT, 0, -124)   -- room for the selection line + 2 button rows
    local content = scroll:GetNamedChild("ScrollChild")

    local list = W.NewList(content, LIST_W - 16, 44, function(p)
        local r = {}
        local row = WM:CreateControl(nil, p, CT_BUTTON)
        row:SetDimensions(LIST_W - 16, 40)
        row:SetMouseEnabled(true)
        r.control = row
        r.bg = W.Backdrop(row, { 0.1, 0.11, 0.13, 0.9 }, { 0.25, 0.27, 0.3, 1 }, 1)
        r.bg:SetAnchorFill()
        r.dot = W.Backdrop(row, { 0.3, 0.3, 0.3, 1 }, { 0, 0, 0, 0 }, 1)
        r.dot:SetDimensions(4, 40)
        r.dot:SetAnchor(LEFT, row, LEFT, 0, 0)
        r.icon = W.Texture(row, nil, 30, 30)
        r.icon:SetAnchor(LEFT, row, LEFT, 10, 0)
        -- tick shown in select mode
        r.box = W.Backdrop(row, { 0.08, 0.08, 0.08, 0.95 }, { 0.5, 0.5, 0.5, 1 }, 1)
        r.box:SetDimensions(16, 16)
        r.box:SetAnchor(BOTTOMRIGHT, r.icon, BOTTOMRIGHT, 4, 4)
        r.tick = W.Backdrop(r.box, C.GOLD, { 0, 0, 0, 0 }, 1)
        r.tick:SetAnchor(TOPLEFT, r.box, TOPLEFT, 3, 3)
        r.tick:SetAnchor(BOTTOMRIGHT, r.box, BOTTOMRIGHT, -3, -3)
        r.name = W.Label(row, "", "ZoFontGame")
        r.name:SetAnchor(TOPLEFT, r.icon, TOPRIGHT, 8, -2)
        r.name:SetDimensions(LIST_W - 110, 20)
        r.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        r.sub = W.Label(row, "", "ZoFontGameSmall", { 0.6, 0.6, 0.6, 1 })
        r.sub:SetAnchor(TOPLEFT, r.name, BOTTOMLEFT, 0, 0)
        r.sub:SetDimensions(LIST_W - 110, 16)
        r.sub:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        r.toggle = W.FlatButton(row, 40, 22, "", function()
            local t = P.Get(r.id)
            if t then t.enabled = not t.enabled; P.TrackerChanged(t); UI.Refresh() end
        end, L("Enable / disable"))
        r.toggle:SetAnchor(RIGHT, row, RIGHT, -6, 0)
        row:SetHandler("OnClicked", function()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            OnRowClicked(r.id)
        end)
        row:SetHandler("OnMouseEnter", function() if UI.selectedId ~= r.id then r.bg:SetEdgeColor(0.6, 0.6, 0.6, 1) end end)
        row:SetHandler("OnMouseExit", function() if UI.selectedId ~= r.id then r.bg:SetEdgeColor(0.25, 0.27, 0.3, 1) end end)
        return r
    end)
    list.control:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)

    local emptyList = W.Label(col, "", "ZoFontGameSmall", { 0.55, 0.55, 0.55, 1 }, TEXT_ALIGN_CENTER)
    emptyList:SetAnchor(TOP, scroll, TOP, 0, 20)
    emptyList:SetDimensions(LIST_W - 20, 40)

    local function Buttons(y, defs)
        local prev
        local made = {}
        local w = (LIST_W - (#defs - 1) * 6) / #defs
        for _, d in ipairs(defs) do
            local b = d.icon and W.IconButton(col, w, 28, d.icon, d[2], d[3], 18) or W.FlatButton(col, w, 28, d[1], d[2], d[3], d.color)
            if prev then b:SetAnchor(LEFT, prev, RIGHT, 6, 0)
            else b:SetAnchor(BOTTOMLEFT, col, BOTTOMLEFT, 0, y) end
            prev = b
            made[#made + 1] = b
        end
        return made
    end
    local normal = {}
    local function Keep(list) for _, b in ipairs(list) do normal[#normal + 1] = b end end
    Keep(Buttons(-68, {
        { L("+ New"), NewTrackerFlow, L("Create a tracker from a template") },
        { L("Duplicate"), function() local t = UI.Current(); if t then local c = P.AddTracker(S.Clone(t)); UI.selectedId = c.id; UI.Refresh() end end },
        { L("Delete"), function()
            local t = UI.Current()
            if t then UI.Confirm(L("Delete tracker"), L("Delete \"<<1>>\"? This can't be undone (export it first if unsure).", t.name),
                function() P.RemoveTracker(t.id); UI.selectedId = nil; UI.Refresh() end) end
        end },
    }))
    Keep(Buttons(-34, {
        { "", function() if UI.selectedId then P.MoveTracker(UI.selectedId, -1); UI.Refresh() end end, L("Move up (draw order and list order)"), icon = W.ARROW_UP },
        { "", function() if UI.selectedId then P.MoveTracker(UI.selectedId, 1); UI.Refresh() end end, L("Move down"), icon = W.ARROW_DOWN },
        { L("Import"), UI.ImportFlow, L("Paste an export string or tracker JSON") },
        { L("Export"), function() local t = UI.Current(); if t then UI.ExportTracker(t) end end, L("Share the selected tracker") },
        { L("All"), UI.ExportAll, L("Export every tracker in this profile as one string") },
    }))

    -- bulk actions (select mode / several picked)
    local bulk = {}
    local function KeepBulk(list) for _, b in ipairs(list) do bulk[#bulk + 1] = b end end
    local row1 = Buttons(-68, {
        { L("All shown"), function()
            for _, id in ipairs(shownIds) do UI.multi[id] = true end
            UI.selectMode = true
            UI.Refresh()
        end, L("Select every tracker in the list (after the filter)") },
        { L("None"), function() UI.multi = {}; UI.Refresh() end, L("Clear the selection") },
        { L("Copy from"), function()
            local from = UI.Current()
            local targets = {}
            for _, t in ipairs(SelectedTrackers()) do if not from or t.id ~= from.id then targets[#targets + 1] = t end end
            if not from or #targets == 0 then
                UI.Message(L("Copy from"), L("Open the tracker to copy from (click it last), and tick the trackers to copy it to."))
                return
            end
            UI.AskCopyLook(from, targets)
        end, L("Give the ticked trackers the look, the rules, or when it's active (combat, boss / trash fights, group, zones) of the tracker open in the editor") },
        { L("Delete"), BulkDelete, L("Delete the selected trackers"), color = { 1, 0.45, 0.45, 1 } },
    })
    KeepBulk(row1)
    local deleteBtn = row1[4]
    KeepBulk(Buttons(-34, {
        { L("On"), function() BulkEnable(true) end, L("Enable the selected trackers") },
        { L("Off"), function() BulkEnable(false) end, L("Disable the selected trackers") },
        { L("Export"), function()
            local list = SelectedTrackers()
            if #list > 0 then UI.ShowExport(L("Export <<1>> trackers", #list), DT.Serializer.Export("B", list)) end
        end, L("Share the selected trackers as one string") },
        { L("Copy"), function()
            local list = SelectedTrackers()
            for _, t in ipairs(list) do P.AddTracker(S.Clone(t)) end
            UI.ClearSelection()
            UI.Refresh()
        end, L("Duplicate the selected trackers") },
        { L("Done"), function() UI.ClearSelection(); UI.Refresh() end, L("Leave select mode") },
    }))
    local selLabel = W.Label(col, "", "ZoFontGameSmall", C.GOLD, TEXT_ALIGN_LEFT)
    selLabel:SetAnchor(BOTTOMLEFT, col, BOTTOMLEFT, 0, -102)
    selLabel:SetDimensions(LIST_W, 18)

    local function RefreshBulk()
        local n = MultiCount()
        local on = UI.selectMode or n > 1
        for _, b in ipairs(normal) do b:SetHidden(on) end
        for _, b in ipairs(bulk) do b:SetHidden(not on) end
        selLabel:SetHidden(not on)
        selLabel:SetText(L("<<1>> selected  -  click rows to tick them, Shift+click for a range", n))
        deleteBtn.label:SetText(L("Delete"))   -- the count is on the line above (four buttons share the row)
        selectBtn.label:SetText(on and L("Cancel") or L("Select"))
    end


    function page.RefreshList()
        local trackers = P.ActiveTrackers()
        local needle = U.Lower(U.Trim(listFilter))
        local shown = {}
        for _, t in ipairs(trackers) do
            if needle == "" or U.Lower(t.name):find(needle, 1, true) then shown[#shown + 1] = t end
        end
        shownIds = {}
        for i, t in ipairs(shown) do shownIds[i] = t.id end
        for id in pairs(UI.multi) do
            if not P.Get(id) then UI.multi[id] = nil end    -- deleted / other profile
        end
        local picking = UI.selectMode or MultiCount() > 1
        count:SetText(L("<<1>> in profile", #trackers))
        if #trackers == 0 then emptyList:SetText(L("No trackers yet."))
        elseif #shown == 0 then emptyList:SetText(L("Nothing matches the filter."))
        else emptyList:SetText("") end
        list:Set(shown, function(r, t)
            r.id = t.id
            r.icon:SetTexture(DT.Triggers.TrackerIcon(t))
            r.icon:SetDesaturation(t.enabled and 0 or 1)
            r.name:SetText(t.name)
            r.name:SetColor(t.enabled and 1 or 0.55, t.enabled and 1 or 0.55, t.enabled and 1 or 0.55, 1)
            local rt = DT.Engine.runtime[t.id]
            local live = rt and rt.realLoaded
            if rt and t.enabled and not rt.realLoaded and rt.realReason then
                r.sub:SetText("|cE0A060" .. L("Not active: <<1>>", rt.realReason) .. "|r")
            else
                r.sub:SetText(TypeSummary(t))
            end
            r.dot:SetCenterColor(live and 0.114 or 0.3, live and 0.62 or 0.3, live and 0.459 or 0.3, 1)
            r.toggle.label:SetText(t.enabled and L("On") or L("Off"))
            local sel = UI.selectedId == t.id
            local ticked = UI.multi[t.id] == true
            r.box:SetHidden(not picking)
            r.tick:SetHidden(not ticked)
            local lit = sel or ticked
            r.bg:SetEdgeColor(lit and C.GOLD[1] or 0.25, lit and C.GOLD[2] or 0.27, lit and C.GOLD[3] or 0.3, 1)
            r.bg:SetCenterColor(lit and 0.2 or 0.1, lit and 0.18 or 0.11, lit and 0.12 or 0.13, 0.95)
        end)
        content:SetHeight(list:Height() + 10)
        RefreshBulk()
    end
    return col
end

------------------------------------------------------------------------------
-- Ability list editor (used by effect and combat triggers)
------------------------------------------------------------------------------

local function AbilityListEditor(panel, width)
    local items
    local container = WM:CreateControl(nil, panel.content, CT_CONTROL)
    container:SetDimensions(width, 10)
    local list = W.NewList(container, width, 34, function(p)
        local r = {}
        r.control = WM:CreateControl(nil, p, CT_CONTROL)
        r.control:SetDimensions(width, 32)
        r.bg = W.Backdrop(r.control, { 0.09, 0.1, 0.11, 0.9 }, { 0.22, 0.24, 0.27, 1 }, 1)
        r.bg:SetAnchorFill()
        r.icon = W.Texture(r.control, nil, 26, 26)
        r.icon:SetAnchor(LEFT, r.control, LEFT, 4, 0)
        r.label = W.Label(r.control, "", "ZoFontGame")
        r.label:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
        r.label:SetDimensions(width - 226, 26)
        r.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        r.remove = W.FlatButton(r.control, 26, 24, "x", function()
            local tr = TR()
            if r.kind == "id" then U.RemoveValue(tr.abilityIds, r.value) else U.RemoveValue(tr.names, r.value) end
            tr.abilityIcons[U.Lower(tostring(r.value))] = nil
            tr.variants[U.Lower(tostring(r.value))] = nil
            tr.noCopies[U.Lower(tostring(r.value))] = nil
            UI.Changed()
        end, L("Remove"), { 1, 0.45, 0.45, 1 })
        r.remove:SetAnchor(RIGHT, r.control, RIGHT, -4, 0)
        -- the player's own icon for this ability (tutsuraki): an ability ID or a texture path
        r.iconBtn = W.FlatButton(r.control, 50, 24, L("Icon"), function()
            local tr = TR()
            local key = U.Lower(tostring(r.value))
            UI.Prompt(L("Icon for <<1>>", tostring(r.value)),
                L("The icon to show for this one, active or missing: an ability ID (its icon is used, e.g. 61687) or a texture path (e.g. /esoui/art/icons/ability_buff_major_sorcery.dds). Empty = automatic."),
                tr.abilityIcons[key] or "", function(v)
                    v = U.Trim(v or "")
                    tr.abilityIcons[key] = v ~= "" and v or nil
                    UI.Changed()
                end)
        end, L("Choose the icon shown for this ability"))
        r.iconBtn:SetAnchor(RIGHT, r.remove, LEFT, -4, 0)
        -- variants: other IDs that count as this one -- the built-in ones (an ID's other ranks / sources) and the
        -- player's own (Sazane). All of them are in the box, so a built-in one can be taken out too (Casual player
        -- Geldis: "when i do 75753 tracker for alkosh it puts all variants to it automatically and i dont see how to
        -- remove variants").
        r.variantBtn = W.FlatButton(r.control, 70, 24, L("Variants"), function()
            local tr = TR()
            local key = U.Lower(tostring(r.value))
            local builtIn = r.kind == "id" and DT.Effects.Copies(r.value) or {}
            local cur = {}
            if not tr.noCopies[key] then for _, id in ipairs(builtIn) do cur[#cur + 1] = tostring(id) end end
            for _, id in ipairs(tr.variants[key] or {}) do
                if not U.Contains(cur, tostring(id)) then cur[#cur + 1] = tostring(id) end
            end
            UI.Prompt(L("Variants of <<1>>", tostring(r.value)),
                L("Other ability IDs that count as this one -- the same effect from another rank, skill or set -- separated by commas. They show as this one entry. The ones DebuffTracker knows are already listed: delete any you don't want, or add your own (Search... or Record... finds IDs). Empty = only this ID."),
                table.concat(cur, ", "), function(v)
                    local ids = {}
                    for _, id in ipairs(U.ParseIds(v or "")) do
                        if tostring(id) ~= key and not U.Contains(ids, id) then ids[#ids + 1] = id end
                    end
                    -- every built-in one still there: they stay built-in (and follow DebuffTracker's list); one taken
                    -- out: the box is the whole list from now on
                    local allKept = true
                    for _, id in ipairs(builtIn) do if not U.Contains(ids, id) then allKept = false end end
                    if allKept then
                        local own = {}
                        for _, id in ipairs(ids) do if not U.Contains(builtIn, id) then own[#own + 1] = id end end
                        tr.variants[key] = #own > 0 and own or nil
                        tr.noCopies[key] = nil
                    else
                        tr.variants[key] = #ids > 0 and ids or nil
                        tr.noCopies[key] = true
                    end
                    UI.Changed()
                end)
        end, L("Other ability IDs that count as this one: remove the built-in ones or add your own"))
        r.variantBtn:SetAnchor(RIGHT, r.iconBtn, LEFT, -4, 0)
        return r
    end)
    list.control:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)

    local addRow = WM:CreateControl(nil, container, CT_CONTROL)
    addRow:SetDimensions(width, 30)
    local pending = ""
    local add = W.Edit(addRow, width - 250, nil, function() return pending end, function(v) pending = v end,
        L("Ability ID(s) like 62787, or effect name(s) like Major Breach (matched by name)."), { noRefresh = true })
    add:SetAnchor(TOPLEFT, addRow, TOPLEFT, 0, 0)
    local function DoAdd()
        local text = add.edit:GetText()
        local tr = TR()
        for _, id in ipairs(U.ParseIds(text)) do
            if not U.Contains(tr.abilityIds, id) then tr.abilityIds[#tr.abilityIds + 1] = id end
        end
        if tr.type == "effect" or tr.type == "toggle" then
            for _, n in ipairs(U.ParseNames(text)) do
                if not U.Contains(tr.names, n) then tr.names[#tr.names + 1] = n end
            end
        else
            -- the other trigger types listen for IDs only: a name typed here becomes every ID with that name, as
            -- one entry (the first ID, the rest its variants) -- like Srendarr's "add by name" (zFinrod: "Do I really
            -- need to add all the id variants manually ... like in srendarr?"). Before, the name was dropped silently.
            for _, n in ipairs(U.ParseNames(text)) do
                local ids = DT.AbilitySearch.IdsForName(n)
                if ids == nil then
                    UI.Message(L("One moment"), L("DebuffTracker is still building its list of abilities (a few seconds, once per session). Add \"<<1>>\" again in a moment.", n))
                elseif #ids == 0 then
                    UI.Message(L("Not found"), L("No ability is called \"<<1>>\". Check the spelling (the name in your game's language), or use Search...", n))
                else
                    local first = ids[1]
                    if not U.Contains(tr.abilityIds, first) then tr.abilityIds[#tr.abilityIds + 1] = first end
                    local rest = {}
                    for i = 2, #ids do rest[#rest + 1] = ids[i] end
                    if #rest > 0 then tr.variants[tostring(first)] = rest end
                end
            end
        end
        pending = ""
        add.edit:SetText("")
        UI.Changed()
    end
    add.edit:SetHandler("OnEnter", function() add.edit:LoseFocus(); DoAdd() end)
    local addBtn = W.FlatButton(addRow, 70, 28, L("Add"), DoAdd)
    addBtn:SetAnchor(LEFT, add, RIGHT, 6, 0)
    local searchBtn = W.FlatButton(addRow, 80, 28, L("Search..."), function() UI.SelectPage(4) end, L("Find ability IDs by name"))
    searchBtn:SetAnchor(LEFT, addBtn, RIGHT, 6, 0)
    local recBtn = W.FlatButton(addRow, 80, 28, L("Record..."), function() UI.SelectPage(3) end, L("Log effects as they happen and pick one"))
    recBtn:SetAnchor(LEFT, searchBtn, RIGHT, 6, 0)

    local function Refresh()
        local tr = TR()
        items = {}
        for _, id in ipairs(tr.abilityIds) do items[#items + 1] = { kind = "id", value = id } end
        if tr.type == "effect" or tr.type == "toggle" then
            for _, n in ipairs(tr.names) do items[#items + 1] = { kind = "name", value = n } end
        end
        list:Set(items, function(r, it)
            r.kind, r.value = it.kind, it.value
            if it.kind == "id" then
                local name = U.CleanName(GetAbilityName(it.value))
                local copies = (TR().noCopies[tostring(it.value)] and 0 or #DT.Effects.Copies(it.value)) + #DT.Triggers.Variants(TR(), it.value)
                r.icon:SetTexture(DT.Triggers.CustomIcon(TR(), it.value) or GetAbilityIcon(it.value))
                r.label:SetText(string.format("%s  |c888888%d%s|r", name ~= "" and name or L("Unknown ability"), it.value,
                    copies > 0 and L(" (+<<1>> variants)", copies) or ""))
            else
                r.icon:SetTexture(DT.Triggers.CustomIcon(TR(), it.value) or DT.Triggers.NameIcon(it.value) or C.DEFAULT_ICON)
                -- by name every ID with that name counts (zFinrod wondered whether it "recognized all the IDs"): say how many
                local own = #DT.Triggers.Variants(TR(), it.value)
                local all = DT.AbilitySearch.IdsForName(it.value)
                local count = all and #all > 0 and L(" - matches all <<1>> IDs with this name", #all) or ""
                r.label:SetText(string.format("\"%s\"  |c888888%s%s%s|r", it.value, L("by name"), count,
                    own > 0 and L(" (+<<1>> variants)", own) or ""))
            end
        end)
        addRow:ClearAnchors()
        addRow:SetAnchor(TOPLEFT, container, TOPLEFT, 0, list:Height() + (#items > 0 and 4 or 0))
        container:SetHeight(list:Height() + 36)
    end
    W.Register(Refresh, "ability list")
    Refresh()
    UI.AddAbilityToCurrent = function(id)
        local t = UI.Current()
        if not t then return false end
        local tr = TR()
        if not U.Contains(tr.abilityIds, id) then tr.abilityIds[#tr.abilityIds + 1] = id end
        UI.Changed()
        return true
    end
    return container, function() return list:Height() + 36 end
end

------------------------------------------------------------------------------
-- Conditions editor
------------------------------------------------------------------------------

local function SoundOptions()
    local opts = { { "", L("(none)") } }
    local seen = {}
    for _, n in ipairs(C.FAVORITE_SOUNDS) do
        if SOUNDS and SOUNDS[n] then opts[#opts + 1] = { n, "* " .. n }; seen[n] = true end
    end
    for _, n in ipairs(C.SoundNames()) do
        if not seen[n] then opts[#opts + 1] = { n, n } end
    end
    return opts
end
local soundOptionsCache
local function Sounds()
    soundOptionsCache = soundOptionsCache or SoundOptions()
    return soundOptionsCache
end

local function ActionKind(action)
    local a = C.Find(C.CONDITION_ACTIONS, action)
    return a and a[3] or "none"
end

local function PropKind(prop)
    local p = C.Find(C.CONDITION_PROPS, prop)
    return p and p[3] or "number"
end

local function ConditionsEditor(panel, width)
    local container = WM:CreateControl(nil, panel.content, CT_CONTROL)
    container:SetDimensions(width, 10)
    local ROW_H, AND_H = 74, 34
    local function RowH(rule) return ROW_H + (type(rule) == "table" and rule.also and AND_H or 0) end
    local PROP_OPTIONS = {}
    for _, pr in ipairs(C.CONDITION_PROPS) do PROP_OPTIONS[#PROP_OPTIONS + 1] = { pr[1], pr[2] } end
    local list = W.NewList(container, width, RowH, function(p, i)
        local function Rule() return T().conditions[i] end
        local r = {}
        r.control = WM:CreateControl(nil, p, CT_CONTROL)
        r.control:SetDimensions(width, ROW_H - 6)
        local bg = W.Backdrop(r.control, { 0.09, 0.1, 0.11, 0.9 }, { 0.22, 0.24, 0.27, 1 }, 1)
        bg:SetAnchorFill()
        -- "If" / "then" share one fixed-width column so both dropdown rows line up and never overlap
        local LABEL_W = 44
        local num = W.Label(r.control, L("If"), "ZoFontGameBold", C.GOLD)
        num:SetAnchor(TOPLEFT, r.control, TOPLEFT, 8, 6)
        num:SetDimensions(LABEL_W, 26)
        local function get(key, default) local rl = Rule(); if rl and rl[key] ~= nil then return rl[key] end return default end
        local function set(key) return function(v) local rl = Rule(); if rl then rl[key] = v end end end

        local prop = W.Dropdown(r.control, 220, nil, (function()
            local o = {}
            for _, pr in ipairs(C.CONDITION_PROPS) do o[#o + 1] = { pr[1], pr[2] } end
            return o
        end)(), function() return get("prop", "remaining") end, function(v)
            local rl = Rule()
            if not rl then return end
            rl.prop = v
            if PropKind(v) ~= "number" and rl.op ~= "~=" then rl.op = "==" end
        end)
        prop:SetAnchor(LEFT, num, RIGHT, 0, 0)
        -- yes/no and text properties only compare "=" / "not =" (a "<=" there meant "=", which confused: Tony)
        local op = W.Dropdown(r.control, 70, nil, function()
            local rl = Rule()
            return (rl and PropKind(rl.prop) ~= "number") and C.EQUALITY_OPERATORS or C.OPERATORS
        end, function() return get("op", "<=") end, set("op"))
        op:SetAnchor(LEFT, prop, RIGHT, 6, 0)
        local value = W.Edit(r.control, 100, nil, function() return tostring(get("value", "")) end, function(v)
            local rl = Rule()
            if rl then rl.value = tonumber(v) or v end
        end, L("A number, true/false, or text depending on the property"))
        value:SetAnchor(LEFT, op, RIGHT, 6, 0)
        -- "and": a second test that must hold too (one per rule)
        local addAnd = W.FlatButton(r.control, 46, 24, L("+ and"), function()
            local rl = Rule()
            if rl and not rl.also then rl.also = { prop = "inCombat", op = "==", value = "true" }; UI.Changed() end
        end, L("Add a second test: the rule then needs both (e.g. \"Progress to the next tick > 75\" and \"Regen per tick = 0\")."))
        addAnd:SetAnchor(LEFT, value, RIGHT, 6, 0)

        local andL = W.Label(r.control, L("and"), "ZoFontGameBold", C.GOLD)
        andL:SetAnchor(TOPLEFT, num, BOTTOMLEFT, 0, 8)
        andL:SetDimensions(LABEL_W, 26)
        local function getA(key, default) local rl = Rule(); local a = rl and rl.also; if a and a[key] ~= nil then return a[key] end return default end
        local prop2 = W.Dropdown(r.control, 220, nil, PROP_OPTIONS, function() return getA("prop", "inCombat") end, function(v)
            local rl = Rule()
            if not (rl and rl.also) then return end
            rl.also.prop = v
            if PropKind(v) ~= "number" and rl.also.op ~= "~=" then rl.also.op = "==" end
        end)
        prop2:SetAnchor(LEFT, andL, RIGHT, 0, 0)
        local op2 = W.Dropdown(r.control, 70, nil, function()
            local rl = Rule()
            return (rl and rl.also and PropKind(rl.also.prop) ~= "number") and C.EQUALITY_OPERATORS or C.OPERATORS
        end, function() return getA("op", "==") end, function(v) local rl = Rule(); if rl and rl.also then rl.also.op = v end end)
        op2:SetAnchor(LEFT, prop2, RIGHT, 6, 0)
        local value2 = W.Edit(r.control, 100, nil, function() return tostring(getA("value", "")) end, function(v)
            local rl = Rule()
            if rl and rl.also then rl.also.value = tonumber(v) or v end
        end, L("A number, true/false, or text depending on the property"))
        value2:SetAnchor(LEFT, op2, RIGHT, 6, 0)
        local delAnd = W.FlatButton(r.control, 26, 24, "x", function()
            local rl = Rule(); if rl then rl.also = nil; UI.Changed() end
        end, L("Remove the second test"), { 1, 0.45, 0.45, 1 })
        delAnd:SetAnchor(LEFT, value2, RIGHT, 6, 0)

        local thenL = W.Label(r.control, L("then"), "ZoFontGameBold", C.GOLD)
        thenL:SetAnchor(TOPLEFT, num, BOTTOMLEFT, 0, 8)
        thenL:SetDimensions(LABEL_W, 26)
        local action = W.Dropdown(r.control, 220, nil, (function()
            local o = {}
            for _, a in ipairs(C.CONDITION_ACTIONS) do o[#o + 1] = { a[1], a[2] } end
            return o
        end)(), function() return get("action", "color") end, function(v)
            local rl = Rule()
            if not rl then return end
            rl.action = v
            local kind = ActionKind(v)
            if kind == "color" and type(rl.arg) ~= "table" then rl.arg = U.Copy(C.RED)
            elseif kind == "sound" and type(rl.arg) ~= "string" then rl.arg = "DUEL_START"
            elseif kind == "text" and type(rl.arg) ~= "string" then rl.arg = "{name}!"
            elseif kind == "number" and (type(rl.arg) ~= "number" or (v == "quickslot" and (rl.arg < 1 or rl.arg > 8))) then
                rl.arg = v == "quickslot" and 4 or 130
            end
        end)
        action:SetAnchor(LEFT, thenL, RIGHT, 0, 0)

        local color = W.Color(r.control, 300, "", function()
            local a = get("arg"); return type(a) == "table" and a or C.RED end, set("arg"))
        color:SetAnchor(LEFT, action, RIGHT, -110, 0)
        local sound = W.Dropdown(r.control, 260, nil, Sounds, function() local a = get("arg"); return type(a) == "string" and a or "" end, set("arg"))
        sound:SetAnchor(LEFT, action, RIGHT, 6, 0)
        local play = W.FlatButton(r.control, 44, 26, L("Play"), function()
            local a = get("arg"); if type(a) == "string" and SOUNDS[a] then PlaySound(SOUNDS[a]) end
        end, L("Preview sound"))
        play:SetAnchor(LEFT, sound, RIGHT, 4, 0)
        local text = W.Edit(r.control, 260, nil, function() local a = get("arg"); return type(a) == "string" and a or "" end,
            set("arg"), L("Alert text. Tokens: {name} {unit} {time} {stacks} {pct}"))
        text:SetAnchor(LEFT, action, RIGHT, 6, 0)
        local number = W.Edit(r.control, 90, nil, function() return tostring(get("arg", 130)) end,
            function(v) local rl = Rule(); if rl then rl.arg = tonumber(v) or 100 end end,
            L("Scale / transparency: percent (130 = 30% bigger). Quickslot: 1-8 around the wheel (1 bottom right, 2 right, 3 top right, 4 top, then on counter-clockwise)."))
        number:SetAnchor(LEFT, action, RIGHT, 6, 0)

        local up = W.IconButton(r.control, 26, 24, W.ARROW_UP, function()
            local list2 = T().conditions
            if i > 1 then list2[i], list2[i - 1] = list2[i - 1], list2[i]; UI.Changed() end
        end, L("Move up (later rules win)"))
        local down = W.IconButton(r.control, 26, 24, W.ARROW_DOWN, function()
            local list2 = T().conditions
            if i < #list2 then list2[i], list2[i + 1] = list2[i + 1], list2[i]; UI.Changed() end
        end, L("Move down"))
        local del = W.FlatButton(r.control, 26, 24, "x", function()
            table.remove(T().conditions, i); UI.Changed()
        end, L("Delete rule"), { 1, 0.45, 0.45, 1 })
        del:SetAnchor(TOPRIGHT, r.control, TOPRIGHT, -6, 6)
        down:SetAnchor(RIGHT, del, LEFT, -4, 0)
        up:SetAnchor(RIGHT, down, LEFT, -4, 0)
        -- on / off without deleting it (Tony: "try some things but didn't wanna remove the whole thing")
        local onOff = W.Checkbox(r.control, 22, "", function() local rl = Rule(); return rl ~= nil and not rl.disabled end,
            function(v) local rl = Rule(); if rl then rl.disabled = not v or nil end end,
            L("Rule on / off. Off: kept here but ignored, so you can try things without deleting it."))
        onOff:SetAnchor(RIGHT, up, LEFT, -6, 0)
        r.bg = bg

        function r.Update()
            local rl = Rule()
            if not rl then return end
            local hasAnd = rl.also ~= nil
            r.control:SetHeight(RowH(rl) - 6)
            addAnd:SetHidden(hasAnd)
            for _, c in ipairs({ andL, prop2, op2, value2, delAnd }) do c:SetHidden(not hasAnd) end
            if hasAnd then op2:SetAlpha(PropKind(rl.also.prop) == "number" and 1 or 0.6) end
            thenL:ClearAnchors()
            thenL:SetAnchor(TOPLEFT, hasAnd and andL or num, BOTTOMLEFT, 0, 8)
            local kind = ActionKind(rl.action)
            color:SetHidden(kind ~= "color")
            sound:SetHidden(kind ~= "sound"); play:SetHidden(kind ~= "sound")
            text:SetHidden(kind ~= "text")
            number:SetHidden(kind ~= "number")
            value:SetHidden(false)
            op:SetAlpha(PropKind(rl.prop) == "number" and 1 or 0.6)
            -- a rule that's off is dimmed (its on/off box stays bright)
            local a = rl.disabled and 0.45 or 1
            for _, c in ipairs({ num, prop, op, value, thenL, action, color, sound, play, text, number, addAnd, andL, prop2, value2, delAnd }) do c:SetAlpha(a) end
        end
        return r
    end)
    list.control:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)

    local quick = WM:CreateControl(nil, container, CT_CONTROL)
    quick:SetDimensions(width, 128)
    local addBtn = W.FlatButton(quick, 120, 28, L("+ Add rule"), function()
        local list2 = T().conditions
        list2[#list2 + 1] = S.NewCondition()
        UI.Changed()
    end)
    addBtn:SetAnchor(TOPLEFT, quick, TOPLEFT, 0, 0)
    local QUICK = {
        { L("Red under 3s"), { prop = "remaining", op = "<=", value = 3, action = "color", arg = U.Copy(C.RED) } },
        { L("Pulse under 3s"), { prop = "remaining", op = "<=", value = 3, action = "pulse" } },
        { L("Sound on apply"), { prop = "active", op = "==", value = "true", action = "sound", arg = "DUEL_START" } },
        { L("Alert when missing"), { prop = "active", op = "==", value = "false", action = "alert", arg = "{name} missing!" } },
        { L("Glow on my target"), { prop = "isTarget", op = "==", value = "true", action = "glow", arg = { 1, 0.88, 0.5, 1 } } },
        { L("Hide others' casts"), { prop = "mine", op = "==", value = "false", action = "hide" } },
        -- Tony: "the 'buff is up' condition is prolly one of the best things from this addon" -- one click, the two
        -- rules in the right order (green while the buff / first phase is up, red on the cooldown / second phase)
        { L("Green up, red on cooldown"), {
            { prop = "phase", op = "==", value = 2, action = "color", arg = { 0.886, 0.294, 0.290, 1 } },
            { prop = "buffUp", op = "==", value = "true", action = "color", arg = { 0.251, 0.749, 0.451, 1 } },
        }, L("Two rules: green while the buff (or a cycle's first phase) is up, red during the cooldown (or the second phase). \"Ready\" keeps its own look.") },
    }
    local PER_ROW = 3
    local qW = (width - (PER_ROW - 1) * 6) / PER_ROW
    for qi, q in ipairs(QUICK) do
        local b = W.FlatButton(quick, qW, 26, q[1], function()
            local list2 = T().conditions
            -- one rule, or several (a list of rules)
            local rules = q[2][1] and q[2] or { q[2] }
            for _, rule in ipairs(rules) do list2[#list2 + 1] = S.NewCondition(U.Copy(rule)) end
            UI.Changed()
        end, q[3] or L("Add this rule"))
        local col, row = (qi - 1) % PER_ROW, math.floor((qi - 1) / PER_ROW)
        b:SetAnchor(TOPLEFT, quick, TOPLEFT, col * (qW + 6), 34 + row * 32)
    end

    local function Refresh()
        local rules = T().conditions
        list:Set(rules, function(r) r.Update() end)
        quick:ClearAnchors()
        quick:SetAnchor(TOPLEFT, container, TOPLEFT, 0, list:Height() + 4)
        container:SetHeight(list:Height() + 134)
    end
    W.Register(Refresh, "condition rules")
    Refresh()
    return container, function() return list:Height() + 134 end
end

------------------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------------------

-- Warning shown when an "above heads" tracker looks at units the game has no position for.
local function HeadsGuard(panel, w)
    local box = WM:CreateControl(nil, panel.content, CT_CONTROL)
    box:SetDimensions(w, 60)
    local bg = W.Backdrop(box, { 0.32, 0.18, 0.07, 0.6 }, { 0.92, 0.58, 0.26, 1 }, 1)
    bg:SetAnchorFill()
    local text = W.Label(box, L("Above heads only works on allies: group members, you, or your companion. The game gives addons no position for enemies."),
        "ZoFontGameSmall", { 1, 0.82, 0.62, 1 })
    text:SetAnchor(LEFT, box, LEFT, 10, 0)
    text:SetDimensions(w - 210, 52)
    local fix = W.FlatButton(box, 180, 28, L("Use group members"), function()
        local t = UI.Current()
        if t then t.trigger.type = "effect"; t.trigger.scope = "group"; UI.Changed() end
    end, L("Switch this tracker to look on your group members"))
    fix:SetAnchor(RIGHT, box, RIGHT, -10, 0)
    return box, 60, function() return DT.Load.HeadsProblem(T()) ~= nil end
end

-- Plain-language summary of a tracker's load conditions ("in combat, boss fights only").
local function LoadSummary(t)
    local ld, parts = t.load, {}
    if ld.combat == "in" then parts[#parts + 1] = L("in combat") elseif ld.combat == "out" then parts[#parts + 1] = L("out of combat") end
    if ld.bossOnly then parts[#parts + 1] = L("during boss fights") end
    if ld.trashOnly then parts[#parts + 1] = L("outside boss fights") end
    if next(ld.zoneTypes) then
        local z = {}
        for _, o in ipairs(C.ZONE_TYPES) do if ld.zoneTypes[o[1]] then z[#z + 1] = o[2] end end
        parts[#parts + 1] = table.concat(z, "/")
    end
    if #ld.zoneIds > 0 or #ld.zoneNames > 0 then parts[#parts + 1] = L("in chosen zones") end
    if ld.group ~= "any" then parts[#parts + 1] = C.Label(C.GROUP_LOAD, ld.group) end
    if next(ld.roles) then parts[#parts + 1] = L("for some roles") end
    if next(ld.classes) then parts[#parts + 1] = L("for some classes") end
    if ld.setId > 0 then parts[#parts + 1] = L("with a set equipped") end
    if #ld.characters > 0 then parts[#parts + 1] = L("on some characters") end
    return parts
end
UI.LoadSummary = LoadSummary

-- "Only during boss fights" left on while the tracker looks at something other than bosses: the
-- classic reason a tracker "works in dungeons but not in the overworld".
local function BossOnlyMismatch(t)
    local tr = t.trigger
    return t.load.bossOnly and not (tr.type == "effect" and tr.scope == "boss")
end

local function LoadBanner(panel, w)
    local box = WM:CreateControl(nil, panel.content, CT_CONTROL)
    box:SetDimensions(w, 36)
    local bg = W.Backdrop(box, { 0.10, 0.14, 0.16, 0.9 }, { 0.30, 0.42, 0.46, 1 }, 1)
    bg:SetAnchorFill()
    local text = W.Label(box, "", "ZoFontGameSmall", { 0.75, 0.88, 0.92, 1 })
    text:SetAnchor(LEFT, box, LEFT, 10, 0)
    text:SetDimensions(w - 330, 32)
    local change = W.FlatButton(box, 120, 26, L("Load tab..."), function() UI.SelectTab(5) end, L("Change when this tracker runs"))
    change:SetAnchor(RIGHT, box, RIGHT, -6, 0)
    local fix = W.FlatButton(box, 180, 26, L("Not just boss fights"), function()
        local t = UI.Current()
        if t then t.load.bossOnly = false; UI.Changed() end
    end, L("Turn off \"Only during boss fights\""))
    fix:SetAnchor(RIGHT, change, LEFT, -6, 0)
    W.Register(function()
        local t = UI.Current()
        if not t then return end
        local mismatch = BossOnlyMismatch(t)
        fix:SetHidden(not mismatch)
        if mismatch then
            text:SetText(L("|cFFB070Only during boss fights is on|r, so this won't run on trash or in the overworld."))
            text:SetColor(1, 0.85, 0.7, 1)
            bg:SetEdgeColor(0.92, 0.58, 0.26, 1)
        else
            text:SetText(L("Runs only: <<1>>", table.concat(LoadSummary(t), ", ")))
            text:SetColor(0.75, 0.88, 0.92, 1)
            bg:SetEdgeColor(0.30, 0.42, 0.46, 1)
        end
    end, "load banner")
    return box, 36, function()
        local t = UI.Current()
        return t ~= nil and (#LoadSummary(t) > 0)
    end
end

-- "My procs" lists: what this tracker shows right now (with "Own tracker" / "Hide") and what's hidden.
local function ProcRowsEditor(panel, width, hiddenList)
    local container = WM:CreateControl(nil, panel.content, CT_CONTROL)
    container:SetDimensions(width, 10)
    local empty = W.Label(container, "", "ZoFontGameSmall", { 0.6, 0.6, 0.6, 1 })
    empty:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    empty:SetDimensions(width, 22)
    local list = W.NewList(container, width, 34, function(p)
        local r = {}
        r.control = WM:CreateControl(nil, p, CT_CONTROL)
        r.control:SetDimensions(width, 32)
        r.bg = W.Backdrop(r.control, { 0.09, 0.1, 0.11, 0.9 }, { 0.22, 0.24, 0.27, 1 }, 1)
        r.bg:SetAnchorFill()
        r.icon = W.Texture(r.control, nil, 26, 26)
        r.icon:SetAnchor(LEFT, r.control, LEFT, 4, 0)
        r.label = W.Label(r.control, "", "ZoFontGame")
        r.label:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
        r.label:SetDimensions(width - 250, 26)
        r.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        r.right = W.FlatButton(r.control, 80, 24, hiddenList and L("Show") or L("Hide"), function()
            local tr = TR()
            if hiddenList then U.RemoveValue(tr.procHidden, r.key)
            elseif not U.Contains(tr.procHidden, r.key) then tr.procHidden[#tr.procHidden + 1] = r.key end
            UI.Changed()
        end, hiddenList and L("Show it in this tracker again") or L("Don't show it in this tracker"))
        r.right:SetAnchor(RIGHT, r.control, RIGHT, -4, 0)
        r.own = W.FlatButton(r.control, 110, 24, L("Own tracker"), function()
            local e = DT.Procs.Get(r.key)
            local t = UI.Current()
            if not e or not t then return end
            local tr = TR()
            if not U.Contains(tr.procHidden, r.key) then tr.procHidden[#tr.procHidden + 1] = r.key end
            local nt = P.AddTracker(DT.Procs.TrackerFor(e, t.display))
            UI.selectedId = nt.id
            UI.Refresh()
            UI.Message(L("Own tracker"), L("\"<<1>>\" now has its own tracker (and is hidden in \"<<2>>\"). Place it with \"Move windows\".", nt.name, t.name))
        end, L("Give it its own tracker so you can place and style it separately"))
        r.own:SetAnchor(RIGHT, r.right, LEFT, -6, 0)
        return r
    end)
    list.control:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    local function Refresh()
        local tr = TR()
        local items = {}
        if tr.type == "procs" then
            if hiddenList then
                for _, k in ipairs(tr.procHidden) do
                    local e = DT.Procs.Get(k)
                    if e then items[#items + 1] = { entry = e } end
                end
            else
                for _, c in ipairs(DT.Procs.Candidates(tr)) do items[#items + 1] = c end
            end
        end
        list:Set(items, function(r, it)
            local e = it.entry
            r.key = e.k
            r.icon:SetTexture(DT.Procs.Icon(e))
            local timing = {}
            if (e.d or 0) > 0 then timing[#timing + 1] = L("<<1>>s active", e.d) end
            if (e.cd or 0) > 0 then timing[#timing + 1] = L("<<1>>s cooldown", e.cd) end
            if e.on == "power" then timing[#timing + 1] = L("calculated value") end
            if e.count then timing[#timing + 1] = L("counts procs") end
            r.label:SetText(string.format("%s  |c888888%s|r", DT.Procs.DisplayName(e), table.concat(timing, ", ")))
            r.own:SetHidden(hiddenList == true)
        end)
        local n = list.count
        empty:SetHidden(n > 0)
        empty:SetText(hiddenList and L("Nothing hidden.") or (DT.Procs.HasLibSets()
            and L("Nothing right now: equip a full set with a known proc, or pick synergies / passives below.")
            or L("Nothing right now: equip a full set with a known proc, or pick synergies / passives below (without LibSets only the sets whose set ID the catalogue knows are recognised).")))
        container:SetHeight(n > 0 and list:Height() or 22)
    end
    W.Register(Refresh, hiddenList and "hidden procs" or "current procs")
    Refresh()
    return container, function()
        local tr = TR()
        if tr.type ~= "procs" then return 22 end
        local n = hiddenList and #tr.procHidden or #DT.Procs.Candidates(tr)
        return n > 0 and n * 34 or 22
    end
end

-- "Fill from the proc catalogue": search by name, pick one, copy its timing into this timer.
local function CatalogueFill()
    UI.Prompt(L("Proc catalogue"), L("Type part of a set, synergy, passive or champion skill name (e.g. spellweave)."), "", function(q)
        local found = DT.Procs.Search(q, 13)
        if #found == 0 then UI.Message(L("Proc catalogue"), L("Nothing matches \"<<1>>\".", q)) return end
        local choices = {}
        for i = 1, math.min(12, #found) do
            local e = found[i]
            choices[#choices + 1] = { DT.Procs.DisplayName(e) .. "  |c888888" .. C.Label(C.PROC_KINDS, e.t) .. "|r", DT.Procs.Icon(e), function()
                local t = UI.Current()
                if not t then return end
                if e.on == "power" then
                    UI.Message(L("Proc catalogue"), L("\"<<1>>\" is a calculated value, not a timer: use the \"My procs\" tracker or \"Own tracker\" from it.", e.k))
                    return
                end
                DT.Procs.FillTrigger(TR(), e)
                if t.name == L("Ability timer") or t.name == S.TRACKER_DEFAULTS.name then t.name = DT.Procs.DisplayName(e) end
                if t.iconOverride == "" then t.iconOverride = DT.Procs.Icon(e) end
                local _, setId = DT.Procs.HasFull(e)
                if setId and DT.Procs.IsGear(e) and t.load.setId == 0 then t.load.setId, t.load.setFull = setId, true end
                UI.Changed()
            end }
        end
        UI.ShowChoices(L("Proc catalogue"), #found > 12 and L("More than 12 match: type more to narrow it down.") or L("Pick one:"), choices)
    end)
end

-- "Trigger 1 | Trigger 2 | ... | + Add trigger | Remove": several triggers feed one tracker.
local function TriggerPicker(panel, w)
    local row = WM:CreateControl(nil, panel.content, CT_CONTROL)
    row:SetDimensions(w, 30)
    local buttons = {}
    local bw = 92
    for i = 0, 4 do
        local b = W.FlatButton(row, bw, 28, i == 0 and L("Main") or L("Trigger <<1>>", i + 1), function()
            UI.triggerFor, UI.triggerIndex = T().id, i
            UI.Refresh()
        end, i == 0 and L("The tracker's main trigger") or L("An extra trigger: its entries show in this tracker too"))
        b:SetAnchor(LEFT, row, LEFT, i * (bw + 4), 0)
        buttons[i] = b
    end
    local add = W.FlatButton(row, 110, 28, L("+ Add trigger"), function()
        local t = UI.Current()
        if not t or #t.extraTriggers >= 4 then return end
        local copy = U.Copy(t.trigger)
        copy.abilityIds, copy.names = {}, {}
        t.extraTriggers[#t.extraTriggers + 1] = S.NormalizeTrigger(copy)
        UI.triggerFor, UI.triggerIndex = t.id, #t.extraTriggers
        UI.Changed()
    end, L("Add another trigger to this tracker, e.g. a buff's duration plus a cooldown timer from another ability"))
    add:SetAnchor(LEFT, row, LEFT, 5 * (bw + 4), 0)
    local remove = W.FlatButton(row, 80, 28, L("Remove"), function()
        local t, i = UI.Current(), TriggerIndex()
        if t and i > 0 then
            table.remove(t.extraTriggers, i)
            UI.triggerIndex = 0
            UI.Changed()
        end
    end, L("Remove the selected extra trigger"), { 1, 0.45, 0.45, 1 })
    remove:SetAnchor(LEFT, add, RIGHT, 6, 0)
    W.Register(function()
        local t = T()
        local n, sel = #(t.extraTriggers or {}), TriggerIndex()
        for i = 0, 4 do
            local b = buttons[i]
            b:SetHidden(i > n or n == 0)
            local on = i == sel
            b.bg:SetCenterColor(on and C.GOLD_BG[1] or 0.12, on and C.GOLD_BG[2] or 0.13, on and C.GOLD_BG[3] or 0.15, 1)
            b.bg:SetEdgeColor(on and C.GOLD[1] or 0.32, on and C.GOLD[2] or 0.34, on and C.GOLD[3] or 0.38, 1)
        end
        add:ClearAnchors()
        add:SetAnchor(LEFT, row, LEFT, n == 0 and 0 or (n + 1) * (bw + 4), 0)
        add:SetHidden(n >= 4)
        remove:SetHidden(sel == 0)
    end, "trigger picker")
    return row, 30
end

local function BuildTriggerTab(panel, w)
    local function isEffect() return TR().type == "effect" end
    local function isCombat() return TR().type == "combat" end
    local function isResource() return TR().type == "resource" end
    local function isProcs() return TR().type == "procs" end
    local function isToggle() return TR().type == "toggle" end
    local function hasAbilities() return TR().type == "effect" or TR().type == "combat" or TR().type == "toggle" end

    local banner, bannerH, bannerVisible = LoadBanner(panel, w)
    panel:Add(banner, bannerH, bannerVisible)
    panel:Add(W.Section(panel.content, w, L("What to track")))
    panel:Add(TriggerPicker(panel, w))
    panel:Add(W.Segmented(panel.content, w, nil, C.TRIGGER_TYPES, function() return TR().type end, function(v)
        -- a toggle shows on AND off unless told otherwise
        if v == "toggle" and TR().type ~= "toggle" then TR().mode = "always" end
        -- ticks: stamina (Miat's default) unless a Resource tracker already picked magicka / health
        if v == "tick" and TR().type ~= "tick" and not (TR().type == "resource" and C.Find(C.TICK_POWER_TYPES, TR().powerType)) then
            TR().powerType = "stamina"
        end
        TR().type = v
    end))
    panel:Add(W.Note(panel.content, w, L("Abilities: add by ID, or type an effect name to match it by name. Morphs and ranks of common debuffs are matched automatically."), 34), 34, hasAbilities)
    local abl, ablH = AbilityListEditor(panel, w)
    panel:Add(abl, ablH, hasAbilities)
    -- toggles (tutsuraki): Power Overload, toggle skills, werewolf form
    panel:Add(W.Section(panel.content, w, L("Toggle")), 30, isToggle)
    panel:Add(W.Note(panel.content, w, L("Skills you switch on and off (Power Overload, other toggles): on or off, read from your action bars -- the skill must be slotted. Add it by name (part of the name is enough: \"overload\") or by ID. Type \"werewolf\" for werewolf form. Rules: \"Is active\" = yes when on."), 48), 48, isToggle)
    panel:Add(W.Dropdown(panel.content, w, L("Show"), C.TOGGLE_MODES, function() return TR().mode end, function(v) TR().mode = v end,
        L("On and off: the icon is always there (greyed / your colour while off). Only while on / off: it appears only then.")), 30, isToggle)

    local guard, guardH, guardVisible = HeadsGuard(panel, w)
    panel:Add(guard, guardH, guardVisible)
    panel:Add(W.Section(panel.content, w, L("Where")), 30, isEffect)
    panel:Add(W.Dropdown(panel.content, w, L("Look on"), C.SCOPES, function() return TR().scope end, function(v) TR().scope = v end,
        L("All enemies: every enemy you've seen get the effect (great for raid debuffs). Bosses/target/me/group: read directly from those units.")), 30, isEffect)
    panel:Add(W.Dropdown(panel.content, w, L("Which one"), function()
        local boss = TR().scope == "boss"
        local opts = { { 0, boss and L("All bosses") or L("All group members") } }
        for i = 1, boss and 6 or 12 do
            opts[#opts + 1] = { i, boss and L("Boss <<1>>", i) or L("Group member <<1>>", i) }
        end
        return opts
    end, function() return TR().unitIndex end, function(v) TR().unitIndex = v end,
        L("Follow one specific boss or group slot instead of all of them.")), 30,
        function() return isEffect() and (TR().scope == "boss" or TR().scope == "group") end)
    panel:Add(W.Slider(panel.content, w, L("Minimum enemy difficulty (trials)"), 0, 4, 1, function() return TR().minDifficulty end,
        function(v) TR().minDifficulty = v end,
        function(v) return ({ [0] = L("Any"), L("1+ (normal)"), "2+", "3+", L("4 (deadly)") })[v] or tostring(v) end,
        L("In trials only: hide enemies below this difficulty. An enemy's difficulty is learned the first time it's your target or a boss.")), 44,
        function() return isEffect() and TR().scope == "enemies" end)
    panel:Add(W.Dropdown(panel.content, w, L("Cast by"), C.SOURCES, function() return TR().source end, function(v) TR().source = v end), 30, isEffect)
    panel:Add(W.Dropdown(panel.content, w, L("Effect type"), C.EFFECT_TYPES, function() return TR().effectType end, function(v) TR().effectType = v end), 30, isEffect)
    panel:Add(W.Dropdown(panel.content, w, L("Show"), C.MODES, function() return TR().mode end, function(v) TR().mode = v end,
        L("While active: only present effects. While missing: only units/abilities without it. Always: both (lit vs grey). Cycle: one entry per unit showing the first listed ability that's active, else 'ready'.")), 30, isEffect)
    panel:Add(W.Note(panel.content, w, L("Cycle: one entry per unit. It shows the first ability in your list that's active on that unit (e.g. Off Balance, then Off Balance Immunity) and \"ready\" when none is. Use the \"Cycle step\" rule to colour each step."), 34), 34,
        function() return isEffect() and TR().mode == "cycle" end)
    -- BuffTheGroup: the cycle's cooldown step, "only DPS", the % of the group
    panel:Add(W.Slider(panel.content, w, L("Then a cooldown before \"ready\""), 0, 120, 0.5, function() return TR().cooldownAfter end,
        function(v) TR().cooldownAfter = v end, function(v) return v == 0 and L("Off") or string.format("%.1fs", v) end,
        L("For buffs that can't be applied again right away (e.g. Pillager's Profit): after the effect, the entry counts down this cooldown (counted from when the effect started), then shows \"ready\". Cycle step = one after your listed abilities.")), 44,
        function() return isEffect() and TR().mode == "cycle" end)
    panel:Add(W.Edit(panel.content, w, L("...or as long as this ability lasts (ID)"), function() return TR().cooldownAfterId > 0 and tostring(TR().cooldownAfterId) or "" end,
        function(v) TR().cooldownAfterId = math.floor(tonumber(v) or 0) end,
        L("The cooldown is read from the game: how long this ability lasts (Pillager's Profit Cooldown: 172056). Used when the slider above is Off.")), 48,
        function() return isEffect() and TR().mode == "cycle" and TR().cooldownAfter == 0 end)
    panel:Add(W.Section(panel.content, w, L("Only these roles (none checked = everyone)")), 30,
        function() return isEffect() and TR().scope == "group" end)
    for _, r in ipairs(C.ROLES) do
        local key = r[1]
        panel:Add(W.Checkbox(panel.content, w, r[2], function() return TR().unitRoles[key] == true end,
            function(v) TR().unitRoles[key] = v or nil end, L("Group members with this role in the group finder (e.g. only DPS).")), 26,
            function() return isEffect() and TR().scope == "group" end)
    end
    panel:Add(W.Checkbox(panel.content, w, L("Nothing to show: keep one entry"), function() return TR().idleEntry end,
        function(v) TR().idleEntry = v end,
        L("When there is nothing to show (no target, a dead target, no enemy being fought, nobody has it), the first listed ability stays on screen instead of disappearing. On All enemies a cycle shows it as \"ready\"; on your target it's the plain icon while you have no target (your colour rules still apply). For a single icon, e.g. Off Balance. It still follows the Load tab (\"Only in combat\" hides it out of combat).")), 26, isEffect)
    panel:Add(W.Checkbox(panel.content, w, L("One entry: how many have it (%)"), function() return TR().summary end,
        function(v) TR().summary = v end,
        L("Instead of an entry per unit: one entry with the % (and number) of the listed units that have it, timed by the one running out first. Use it with Show = Cycle or Always so the units without it count too. {pct} and {value}/{max} in the label.")), 26, isEffect)
    panel:Add(W.Note(panel.content, w, L("All enemies + missing: one entry for every enemy you or your group hit in the last 10 seconds (or that hit you) that doesn't have it. For bosses only, pick Bosses."), 34), 34,
        function() return isEffect() and TR().scope == "enemies" and (TR().mode == "missing" or TR().mode == "always") end)
    panel:Add(W.Checkbox(panel.content, w, L("One entry per listed ability (checklist)"), function() return TR().perAbility end,
        function(v) TR().perAbility = v end, L("Each ability gets its own entry, so you can see exactly which ones are missing.")), 26, isEffect)
    panel:Add(W.Dropdown(panel.content, w, L("Stacks show"), { { "effect", L("The effect's own stacks") }, { "mydots", L("How many of my DoTs are on the unit") } },
        function() return TR().stacksFrom end, function(v) TR().stacksFrom = v end,
        L("\"My DoTs\": for effects whose strength depends on your damage-over-time effects on the enemy, like Touch of Z'en (the game reports no stacks for it).")), 30, isEffect)
    panel:Add(W.Slider(panel.content, w, L("Show at most"), 0, 20, 1, function() return TR().stacksMax end, function(v) TR().stacksMax = v end,
        function(v) return v == 0 and L("No limit") or tostring(v) end, L("E.g. 5 for Touch of Z'en (it counts up to 5 DoTs).")), 44, isEffect)
    panel:Add(W.Slider(panel.content, w, L("Minimum stacks"), 0, 20, 1, function() return TR().minStacks end, function(v) TR().minStacks = v end,
        function(v) return v == 0 and L("Any") or tostring(v) end), 44, isEffect)

    -- "keep it shown after it ends": effects shown while active, and ability timers
    local function canLinger() return (isEffect() and TR().mode == "present") or isCombat() end
    panel:Add(W.Slider(panel.content, w, L("Keep it shown after it ends"), 0, 30, 0.5, function() return TR().linger end,
        function(v) TR().linger = v end, function(v) return v == 0 and L("Off") or string.format("%.1fs", v) end,
        L("When it runs out, the entry stays (red, counting up: +1.2s) so you see it just ended -- e.g. YOUR taunt fell off this enemy. Different from \"missing\": it only follows what this tracker showed.")), 44, canLinger)
    panel:Add(W.Checkbox(panel.content, w, L("Also when it ends early (removed, overwritten)"), function() return TR().lingerEarly end,
        function(v) TR().lingerEarly = v end, L("Off: only when it ran out on its own. An enemy that dies is always removed at once.")), 26,
        function() return canLinger() and TR().linger > 0 end)
    panel:Add(W.Checkbox(panel.content, w, L("...counted from when it would have ended"), function() return TR().lingerToDue end,
        function(v) TR().lingerToDue = v end,
        L("Like Untaunted: when another tank takes your enemy, your ended taunt stays until your taunt would have run out, plus the time above.")), 26,
        function() return canLinger() and TR().linger > 0 and TR().lingerEarly end)
    panel:Add(W.Checkbox(panel.content, w, L("Keep it while that enemy still shows another entry here"), function() return TR().lingerUnit end,
        function(v) TR().lingerUnit = v end,
        L("Like Untaunted: an enemy's ended entries stay while another entry of this tracker is still running on it (Taunt ended, Taunt Immunity still on), and all go together.")), 26,
        function() return canLinger() and TR().linger > 0 end)

    panel:Add(W.Section(panel.content, w, L("Timer")), 30, isCombat)
    panel:Add(W.Note(panel.content, w, L("Ability timers start from an action (a cast, hit or proc) and run for the duration you set. To follow a buff or debuff that's actually on a unit (like Off Balance and its immunity), use Buff / debuff instead."), 34), 34, isCombat)
    panel:Add(W.Button(panel.content, 260, L("Fill from the proc catalogue..."), CatalogueFill,
        L("Over 200 set procs, monster sets, mythics, synergies, passives and champion skills with their timings")), 28, isCombat)
    panel:Add(W.Dropdown(panel.content, w, L("Started by"), C.START_ON, function() return TR().startOn end, function(v) TR().startOn = v end,
        L("An action / proc: a combat event of the abilities above. A buff on me: the buff's own duration and stacks are used, and it ends when the buff fades.")), 30, isCombat)
    local function onAction() return isCombat() and TR().startOn ~= "effect" end
    panel:Add(W.Dropdown(panel.content, w, L("Triggered by"), C.COMBAT_SOURCES, function() return TR().combatSource end, function(v) TR().combatSource = v end), 30, onAction)
    panel:Add(W.Dropdown(panel.content, w, L("Event"), C.COMBAT_RESULTS, function() return TR().combatResult end, function(v) TR().combatResult = v end), 30, onAction)
    panel:Add(W.Checkbox(panel.content, w, L("Count procs instead of timing them"), function() return TR().count end, function(v) TR().count = v end,
        L("Shows how many times it happened this fight (as stacks), e.g. Pearls of Ehlnofey.")), 26, onAction)
    local function timed() return isCombat() and not TR().count end
    panel:Add(W.Slider(panel.content, w, L("Active part"), 0, 120, 0.5, function() return TR().duration end, function(v) TR().duration = v end,
        function(v) if v == 0 then return L("None") end return string.format("%.1fs", v) end,
        L("How long the effect lasts after it starts (e.g. a set's 10 second buff). With \"A buff on me\" the buff's own time is used when it has one.")), 44, timed)
    panel:Add(W.Checkbox(panel.content, w, L("Take the time from the event (hit value)"), function() return TR().durationFromHit end,
        function(v) TR().durationFromHit = v end,
        L("Some events carry their own length in milliseconds (e.g. how long a Sul-Xan soul stays). When there is one it's used instead of the active part above.")), 26, onAction)
    panel:Add(W.Slider(panel.content, w, L("Cooldown in seconds (counted from the start)"), 0, 300, 0.5, function() return TR().cooldown end, function(v) TR().cooldown = v end,
        function(v) if v == 0 then return L("None") end return string.format("%.1fs", v) end,
        L("Seconds until it can happen again, counted from the moment it fired (the slider and the typed number are the same thing: 45 = 45 seconds). E.g. a 10 s buff with a 45 s cooldown: 10 s active, then 35 s greyed out, then \"ready\".")), 44, timed)
    panel:Add(W.Note(panel.content, w, L("Only for Conditions rules: the timer goes active (Step 1) -> cooldown (Step 2) -> ready (Step 0). E.g. a rule \"Step = 0 -> Play sound\" plays a sound when it's ready again."), 34), 34,
        function() return timed() and TR().cooldown > 0 end)
    panel:Add(W.Slider(panel.content, w, L("Ignore repeats within"), 0, 5, 0.1, function() return TR().minInterval end, function(v) TR().minInterval = v end,
        function(v) return string.format("%.1fs", v) end, L("One action can fire several events; repeats inside this window are ignored.")), 44, onAction)
    panel:Add(W.Checkbox(panel.content, w, L("Separate timer per target"), function() return TR().perTarget end, function(v) TR().perTarget = v end), 26,
        function() return onAction() and not TR().count end)
    panel:Add(W.Checkbox(panel.content, w, L("Restart when it fires again"), function() return TR().restartOnRefresh end, function(v) TR().restartOnRefresh = v end,
        L("Off: it's a cooldown -- ignored until the timer (and its cooldown) runs out.")), 26, timed)
    panel:Add(W.Checkbox(panel.content, w, L("Show \"Ready\" when not running"), function() return TR().showReady end, function(v) TR().showReady = v end), 26, isCombat)
    panel:Add(W.Edit(panel.content, w, L("Cooldown length from these abilities' events (IDs, optional)"),
        function() local p = {}; for _, id in ipairs(TR().cooldownIds) do p[#p + 1] = tostring(id) end; return table.concat(p, ", ") end,
        function(v) TR().cooldownIds = U.ParseIds(v) end,
        L("Some stacking sets announce their cooldown as a separate effect; its length (hit value) is used as the cooldown.")), 48, timed)
    panel:Add(W.Edit(panel.content, w, L("End the active part early on these abilities (IDs, optional)"),
        function() local p = {}; for _, id in ipairs(TR().endIds) do p[#p + 1] = tostring(id) end; return table.concat(p, ", ") end,
        function(v) TR().endIds = U.ParseIds(v) end, L("E.g. a set whose buff is consumed by a hit (Turning Tide).")), 48, timed)
    panel:Add(W.Button(panel.content, 160, L("Test fire"), function()
        local t = UI.Current()
        local i, tr = TriggerIndex(), TR()
        if t and tr.abilityIds[1] then DT.Combat.Fire(i > 0 and (t.id .. "#x" .. i) or t.id, tr.abilityIds[1]) end
    end, L("Start the timer now (needs at least one ability)")), 28, onAction)

    -- My procs
    panel:Add(W.Section(panel.content, w, L("My procs")), 30, isProcs)
    local function procsOnly() return isProcs() and #TR().procOnly > 0 end
    local function procsAll() return isProcs() and #TR().procOnly == 0 end
    panel:Add(W.Note(panel.content, w, function() return L("This tracker shows one proc only: <<1>>. It appears with the full set (or while the skill is picked / slotted).", table.concat(TR().procOnly, ", ")) end, 34), 34, procsOnly)
    panel:Add(W.Button(panel.content, 220, L("Show all my procs instead"), function() TR().procOnly = {}; UI.Changed() end), 28, procsOnly)
    panel:Add(W.Note(panel.content, w, L("Every proc you have, from the built-in catalogue: gear procs when the FULL set is worn (both bars count, a two-hander counts twice), plus the synergies, passives and champion skills you pick below. Each shows its active time, its cooldown (greyed) and \"ready\"."), 50), 50, procsAll)
    local function noLibSets() return isProcs() and not DT.Procs.HasLibSets() end
    panel:Add(W.Note(panel.content, w, L("|cFF9060LibSets isn't installed.|r The sets whose set ID the catalogue knows (about 100, from ExoY's ProcSet Timer) work without it; install LibSets for every other set proc. Synergies, class passives and champion skills always work."), 34), 34, noLibSets)
    for _, kind in ipairs(C.PROC_KINDS) do
        if C.GEAR_PROC_KINDS[kind[1]] then
            panel:Add(W.Checkbox(panel.content, w, kind[2], function() return not U.Contains(TR().procKindsOff, kind[1]) end, function(v)
                local tr = TR()
                if v then U.RemoveValue(tr.procKindsOff, kind[1])
                elseif not U.Contains(tr.procKindsOff, kind[1]) then tr.procKindsOff[#tr.procKindsOff + 1] = kind[1] end
            end), 26, procsAll)
        end
    end
    panel:Add(W.Dropdown(panel.content, w, L("Icon of gear procs"), { { "set", L("The set's icon") }, { "proc", L("The proc's effect icon") } },
        function() return TR().procIcon end, function(v) TR().procIcon = v end,
        L("The set's icon: its own helmet / weapon. Crafted and overland sets have no look of their own, so they show the piece you're wearing.")), 30, isProcs)
    panel:Add(W.Checkbox(panel.content, w, L("Show procs that are ready"), function() return TR().procReady end, function(v) TR().procReady = v end,
        L("Off: only active procs and cooldowns are shown.")), 26, isProcs)
    panel:Add(W.Checkbox(panel.content, w, L("Buff times from the game (like ExoY's)"), function() return TR().procGameDurations end,
        function(v) TR().procGameDurations = v end,
        L("The active part of each proc is how long its buff lasts in the game (read from the game, so it follows patches), then the cooldown. Off: the catalogue's times (from Cooldowns).")), 26, isProcs)
    panel:Add(W.Checkbox(panel.content, w, L("Touch of Z'en: count on the boss"), function() return TR().procZenBoss end,
        function(v) TR().procZenBoss = v end,
        L("With exactly one boss, your DoTs are counted on that boss even when you look at an add (like ExoY's \"focus on boss\"). Otherwise on your target.")), 26, isProcs)
    panel:Add(W.Section(panel.content, w, L("Shown now")), 30, isProcs)
    local cur, curH = ProcRowsEditor(panel, w, false)
    panel:Add(cur, curH, isProcs)
    panel:Add(W.Section(panel.content, w, L("Hidden here")), 30, function() return procsAll() and #TR().procHidden > 0 end)
    local hid, hidH = ProcRowsEditor(panel, w, true)
    panel:Add(hid, hidH, function() return procsAll() and #TR().procHidden > 0 end)
    for _, kind in ipairs(C.PROC_KINDS) do
        if not C.GEAR_PROC_KINDS[kind[1]] then
            panel:Add(W.Section(panel.content, w, kind[2]), 30, procsAll)
            if kind[1] == "champion" then
                panel:Add(W.Note(panel.content, w, L("Champion skills show only while slotted."), 20), 20, procsAll)
            end
            for _, e in ipairs(DT.Procs.All()) do
                if e.t == kind[1] then
                    panel:Add(W.Checkbox(panel.content, w, DT.Procs.DisplayName(e), function() return U.Contains(TR().procPicked, e.k) end, function(v)
                        local tr = TR()
                        if v then
                            if not U.Contains(tr.procPicked, e.k) then tr.procPicked[#tr.procPicked + 1] = e.k end
                        else
                            U.RemoveValue(tr.procPicked, e.k)
                        end
                    end, e.note), 26, procsAll)
                end
            end
        end
    end

    -- stats (Core/Stats.lua)
    local function isStat() return TR().type == "stat" end
    panel:Add(W.Section(panel.content, w, L("Stat")), 30, isStat)
    panel:Add(W.Dropdown(panel.content, w, L("Stat"), C.STATS, function() return TR().stat end, function(v) TR().stat = v end,
        L("\"vs. my target\": your character sheet value plus what the debuffs on your target add (Major / Minor Breach, Crusher, Alkosh, Crimson Oath, Runic Sunder, Tremorscale, Crystal Weapon, poisons, Force of Nature...). The cap it's compared with is set in Settings.")), 30, isStat)
    do
        local statOps = { { "none", L("Always show") } }
        for _, o in ipairs(C.OPERATORS) do statOps[#statOps + 1] = { o[1], L("Only when <<1>>", o[2]) } end
        panel:Add(W.Dropdown(panel.content, w, L("Show"), statOps, function() return TR().statOp end, function(v) TR().statOp = v end), 30, isStat)
    end
    panel:Add(W.Edit(panel.content, w, L("Value"), function() return tostring(TR().statValue) end,
        function(v) TR().statValue = tonumber(v) or TR().statValue end, L("E.g. 18200 for the penetration cap.")), 48,
        function() return isStat() and TR().statOp ~= "none" end)
    panel:Add(W.Edit(panel.content, w, L("Label (Meter display; empty = the stat's name)"), function() return TR().label end,
        function(v) TR().label = U.Trim(v) end, L("The small caption above the number, e.g. PEN or Spell resist.")), 48, isStat)
    panel:Add(W.Slider(panel.content, w, L("Decimals"), -1, 2, 1, function() return TR().statDecimals end, function(v) TR().statDecimals = v end,
        function(v) return v < 0 and L("Auto") or tostring(v) end), 44, isStat)
    panel:Add(W.Note(panel.content, w, L("Texts: {value} the value, {max} the cap, {pct} % of the cap, {detail} what your target's debuffs add. Rules: Conditions tab \"My penetration vs. the enemy\" / \"Penetration missing to the cap\" work on any tracker."), 48), 48, isStat)

    local function isCombatState() return TR().type == "combatState" end
    panel:Add(W.Section(panel.content, w, L("Combat state")), 30, isCombatState)
    panel:Add(W.Note(panel.content, w, L("One entry: this text while you're in combat, the other out of it. Rules: \"I'm in combat\" = yes / no for the colours (and a sound when a fight starts). {elapsed} in the text = time in this fight."), 48), 48, isCombatState)
    panel:Add(W.Edit(panel.content, w, L("In combat"), function() return TR().combatOnText end, function(v) TR().combatOnText = v end), 48, isCombatState)
    panel:Add(W.Edit(panel.content, w, L("Out of combat"), function() return TR().combatOffText end, function(v) TR().combatOffText = v end), 48, isCombatState)

    local function isGcd() return TR().type == "gcd" end
    local function gcdTick() return isGcd() and TR().gcdTick end
    local function gcdTock() return isGcd() and TR().gcdTock end
    local function ms(v) return string.format("%d ms", v) end
    panel:Add(W.Section(panel.content, w, L("Global cooldown")), 30, isGcd)
    panel:Add(W.Note(panel.content, w, L("One bar for each global cooldown: the skill you used (its name and icon), a cast or channel for its whole length, a heavy attack, a roll dodge, a synergy or item. The bright end of the bar is your ping -- press your next skill or light attack when the bar reaches it and it lands the moment the cooldown ends. Rules: \"Global cooldown: what\" (skill / cast / channel / heavy / dodge / other) and \"still casting\" for colours; \"Time remaining\" < 0.1 for a light-attack cue."), 80), 80, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Heavy attacks too"), function() return TR().gcdHeavy end, function(v) TR().gcdHeavy = v end), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Casts for their whole cast time"), function() return TR().gcdCasts end, function(v) TR().gcdCasts = v end,
        L("Off: a cast shows just the 1 s cooldown (Global Cooldown Monitor, GCD Bar).")), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Channels for their whole length"), function() return TR().gcdChannels end, function(v) TR().gcdChannels = v end,
        L("Off: a channel shows just the 1 s cooldown (GCD Bar).")), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Cooldowns without a skill too"), function() return TR().gcdOther end, function(v) TR().gcdOther = v end,
        L("Roll dodge, breaking free, synergies, items, companions, mounting -- and what's left of the cooldown when a cast is blocked or fails (\"Blocked\", \"Target dead\"...). Combat Metronome: \"Track all GCDs\".")), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Mounting: with the mount's name"), function() return TR().gcdMountName end, function(v) TR().gcdMountName = v end,
        nil, function() return not TR().gcdOther end), 30, isGcd)
    panel:Add(W.Dropdown(panel.content, w, L("Name, icon and time on"), { { "all", L("every bar") }, { "timed", L("casts and channels only") } },
        function() return TR().gcdNames end, function(v) TR().gcdNames = v end,
        L("\"casts and channels only\" is Combat Metronome's default: an instant skill's bar is just the bar.")), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("...and on heavy attacks"), function() return TR().gcdHeavyNames end, function(v) TR().gcdHeavyNames = v end,
        nil, function() return not TR().gcdHeavy end), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Show my ping at the end of the bar"), function() return TR().gcdPing end, function(v) TR().gcdPing = v end,
        L("The window to queue your next input: anything pressed in it lands as the cooldown ends.")), 30, isGcd)
    panel:Add(W.Slider(panel.content, w, L("Most ping shown (ms)"), 0, 500, 10, function() return TR().gcdMaxPing end, function(v) TR().gcdMaxPing = v end,
        nil, nil, function() return not TR().gcdPing end), 44, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Ping on heavy attacks too"), function() return TR().gcdHeavyPing end, function(v) TR().gcdHeavyPing = v end,
        nil, function() return not TR().gcdPing end), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Ping on cooldowns without a skill too"), function() return TR().gcdOtherPing end, function(v) TR().gcdOtherPing = v end,
        nil, function() return not TR().gcdPing end), 30, isGcd)
    panel:Add(W.Color(panel.content, w, L("Ping window colour"), function() return DS().zoneColor end, function(v) DS().zoneColor = v end,
        function() return not TR().gcdPing end), 30, isGcd)
    panel:Add(W.Slider(panel.content, w, L("Instant skills: add"), -500, 500, 5, function() return TR().gcdAdjust end, function(v) TR().gcdAdjust = v end,
        ms, L("Make bars longer or shorter if they end before / after you can act again (Combat Metronome: GCD adjust).")), 44, isGcd)
    panel:Add(W.Slider(panel.content, w, L("Casts and channels: add"), -500, 500, 5, function() return TR().gcdCastAdjust end, function(v) TR().gcdCastAdjust = v end,
        ms, L("Combat Metronome: global ability cast adjust (its default is 25).")), 44, isGcd)
    panel:Add(W.Slider(panel.content, w, L("Heavy attacks: add"), -500, 500, 5, function() return TR().gcdHeavyAdjust end, function(v) TR().gcdHeavyAdjust = v end,
        ms, nil, function() return not TR().gcdHeavy end), 44, isGcd)
    panel:Add(W.Slider(panel.content, w, L("After a channel over 1 s: add"), 0, 500, 10, function() return TR().gcdChannelExtra end, function(v) TR().gcdChannelExtra = v end,
        ms, L("Time for the light attack after a channel (Global Cooldown Monitor uses 100).")), 44, isGcd)
    panel:Add(W.Edit(panel.content, w, L("Per skill: add (ID=ms, ID=ms...)"), function()
        local parts = {}
        for _, a in ipairs(TR().gcdAbilityAdjust or {}) do parts[#parts + 1] = string.format("%d=%d", a.id, a.ms) end
        return table.concat(parts, ", ")
    end, function(v)
        local list = {}
        for id, n in tostring(v or ""):gmatch("(%d+)%s*=%s*(%-?%d+)") do list[#list + 1] = { id = tonumber(id), ms = tonumber(n) } end
        TR().gcdAbilityAdjust = list
    end, L("A skill's ID (Search / Recorder) and the ms to add to its bar, e.g. 63046=40. Added to the general adjustment, like Combat Metronome's ability adjusts.")), 48, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("Keep the empty bar between cooldowns"), function() return TR().gcdIdle end, function(v) TR().gcdIdle = v end), 30, isGcd)
    -- the metronome
    panel:Add(W.Section(panel.content, w, L("Metronome sounds")), 30, isGcd)
    panel:Add(W.Checkbox(panel.content, w, L("\"Tick\""), function() return TR().gcdTick end, function(v) TR().gcdTick = v end,
        L("A sound at the start (or the middle, or just before the end) of each skill's bar.")), 30, isGcd)
    panel:Add(W.Dropdown(panel.content, w, L("Tick sound"), Sounds, function() return TR().gcdTickSound end, function(v) TR().gcdTickSound = v end), 30, gcdTick)
    panel:Add(W.Dropdown(panel.content, w, L("Tick at"), { { "start", L("the start") }, { "mid", L("the middle") }, { "end", L("before the end") } },
        function() return TR().gcdTickAt end, function(v) TR().gcdTickAt = v end), 30, gcdTick)
    panel:Add(W.Slider(panel.content, w, L("Tick: offset"), -1000, 2000, 10, function() return TR().gcdTickOffset end, function(v) TR().gcdTickOffset = v end,
        ms, nil, function() return TR().gcdTickAt == "end" end), 44, gcdTick)
    panel:Add(W.Slider(panel.content, w, L("Tick: before the end"), 0, 2000, 10, function() return TR().gcdTickBeforeEnd end, function(v) TR().gcdTickBeforeEnd = v end,
        ms, nil, function() return TR().gcdTickAt ~= "end" end), 44, gcdTick)
    panel:Add(W.Checkbox(panel.content, w, L("\"Tock\""), function() return TR().gcdTock end, function(v) TR().gcdTock = v end,
        L("A sound when each skill ends (+ offset; a negative offset plays it before the end).")), 30, isGcd)
    panel:Add(W.Dropdown(panel.content, w, L("Tock sound"), Sounds, function() return TR().gcdTockSound end, function(v) TR().gcdTockSound = v end), 30, gcdTock)
    panel:Add(W.Slider(panel.content, w, L("Tock: offset"), -1000, 2000, 10, function() return TR().gcdTockOffset end, function(v) TR().gcdTockOffset = v end, ms), 44, gcdTock)
    local function anySound() return isGcd() and (TR().gcdTick or TR().gcdTock) end
    panel:Add(W.Checkbox(panel.content, w, L("Play it even when the next skill already started"), function() return TR().gcdTockForce end, function(v) TR().gcdTockForce = v end,
        L("Combat Metronome: force 'tock'.")), 30, anySound)
    panel:Add(W.Checkbox(panel.content, w, L("On heavy attacks too"), function() return TR().gcdSoundHeavy end, function(v) TR().gcdSoundHeavy = v end), 30, anySound)
    panel:Add(W.Checkbox(panel.content, w, L("On skills over 1 s too"), function() return TR().gcdSoundLong end, function(v) TR().gcdSoundLong = v end), 30, anySound)
    panel:Add(W.Checkbox(panel.content, w, L("Out of combat too"), function() return TR().gcdSoundOOC end, function(v) TR().gcdSoundOOC = v end), 30, anySound)
    panel:Add(W.Slider(panel.content, w, L("Loudness (times played)"), 1, 30, 1, function() return TR().gcdVolume end, function(v) TR().gcdVolume = v end), 44, anySound)

    local function isTick() return TR().type == "tick" end
    panel:Add(W.Section(panel.content, w, L("Resource tick")), 30, isTick)
    panel:Add(W.Note(panel.content, w, L("Your resources come back in steps every 2 seconds. One entry fills up toward the next step of this resource (a bar is full when it lands); it starts after the first step is seen. Texts: {fill} how far (73%), {gain} \"+amount\" for a moment after a step, {value} the resource now, {time} time to the next step. Rules: \"Progress to the next tick\", \"Seconds since the last tick\" (a sound or a pulse on every step), \"Regen per tick\" (0 = none, e.g. while blocking), \"Dodge fatigue stacks on me\"."), 64), 64, isTick)
    panel:Add(W.Dropdown(panel.content, w, L("Resource"), C.TICK_POWER_TYPES, function() return TR().powerType end, function(v) TR().powerType = v end), 30, isTick)
    panel:Add(W.Checkbox(panel.content, w, L("Also while it's full"), function() return TR().tickShowFull end, function(v) TR().tickShowFull = v end,
        L("Off: hidden while the resource is full (nothing to wait for).")), 30, isTick)

    panel:Add(W.Section(panel.content, w, L("Resource")), 30, isResource)
    panel:Add(W.Dropdown(panel.content, w, L("Unit"), C.RESOURCE_UNITS, function() return TR().unit end, function(v) TR().unit = v end), 30, isResource)
    panel:Add(W.Dropdown(panel.content, w, L("Resource"), C.POWER_TYPES, function() return TR().powerType end, function(v) TR().powerType = v end), 30, isResource)
    local opsWithNone = { { "none", L("Always show") } }
    for _, o in ipairs(C.OPERATORS) do opsWithNone[#opsWithNone + 1] = { o[1], L("Only when % <<1>>", o[2]) } end
    panel:Add(W.Dropdown(panel.content, w, L("Show"), opsWithNone, function() return TR().thresholdOp end, function(v) TR().thresholdOp = v end), 30, isResource)
    panel:Add(W.Slider(panel.content, w, L("Threshold"), 0, 100, 1, function() return TR().threshold end, function(v) TR().threshold = v end,
        function(v) return v .. "%" end, nil, function() return TR().thresholdOp == "none" end), 44, isResource)
    panel:Add(W.Dropdown(panel.content, w, L("Timer text shows"), C.CALC_MODES, function() return TR().calc end, function(v) TR().calc = v end,
        L("A value calculated from the %, e.g. a set's bonus from missing stamina, or seconds of a buff from your ultimate. Also available as {calc} in texts.")), 30, isResource)
    local function calcMissing() return isResource() and TR().calc == "missing" end
    local function calcDivide() return isResource() and TR().calc == "divide" end
    panel:Add(W.Edit(panel.content, w, L("Full value (at the most missing)"), function() return tostring(TR().calcScalar) end,
        function(v) TR().calcScalar = tonumber(v) or TR().calcScalar end, L("E.g. Coral Riptide: 1200 (x missing stamina), Bahsei's Mania: 30.")), 48, calcMissing)
    panel:Add(W.Slider(panel.content, w, L("Counted from"), 1, 100, 1, function() return TR().calcStart end, function(v) TR().calcStart = v end,
        function(v) return v .. "%" end), 44, calcMissing)
    panel:Add(W.Slider(panel.content, w, L("No more below"), 0, 100, 1, function() return TR().calcCap end, function(v) TR().calcCap = v end,
        function(v) return v .. "%" end, L("Below this % the value stops growing (e.g. 50%).")), 44, calcMissing)
    panel:Add(W.Edit(panel.content, w, L("Divide the % by"), function() return tostring(TR().calcDiv) end,
        function(v) TR().calcDiv = tonumber(v) or TR().calcDiv end, L("E.g. 2.8 for War Machine: seconds of Major Slayer from your ultimate %.")), 48, calcDivide)
    panel:Add(W.Slider(panel.content, w, L("Decimals"), 0, 2, 1, function() return TR().calcDecimals end, function(v) TR().calcDecimals = v end), 44,
        function() return isResource() and TR().calc ~= "none" end)
end

-- "Copy the look of <tracker>" (Display tab) and "Copy look" on several selected trackers.
local function AskCopyLook(from, targets, done)
    local names = {}
    for _, t in ipairs(targets) do names[#names + 1] = t.name end
    local what = #targets == 1 and targets[1].name or L("<<1>> trackers", #targets)
    UI.ShowChoices(L("Copy from a tracker"), L("Copy from \"<<1>>\" to <<2>>:", from.name, what), {
        { L("Look (display, text & colors)"), nil, function() P.CopyLook(from, targets, false); if done then done() end; UI.Refresh() end },
        { L("Look and condition rules"), nil, function() P.CopyLook(from, targets, true); if done then done() end; UI.Refresh() end },
        { L("When it's active (combat, fights, group, zones)"), nil, function() P.CopySituation(from, targets); if done then done() end; UI.Refresh() end },
    })
end
UI.AskCopyLook = AskCopyLook

local function BuildDisplayTab(panel, w)
    panel:Add(W.Dropdown(panel.content, w, L("Copy the look of"), function()
        local opts = { { "", L("(pick a tracker)") } }
        local me = UI.Current()
        for _, t in ipairs(P.ActiveTrackers()) do
            if not me or t.id ~= me.id then opts[#opts + 1] = { t.id, t.name } end
        end
        return opts
    end, function() return "" end, function(id)
        local src, me = P.Get(id), UI.Current()
        if src and me then AskCopyLook(src, { me }) end
    end, L("Takes size, style, colours, fonts and texts from another tracker (this tracker keeps its title). Several at once: select them in the list, then \"Copy look\".")))
    local function is(kind) return function() return DS().type == kind end end
    local function notAlert() return DS().type ~= "alert" end
    local function barsOrText() return DS().type == "bars" or DS().type == "text" end
    local function heads() return DS().type == "heads" end
    local function notHeads() return DS().type ~= "heads" end
    local function windowed() return DS().type ~= "alert" and DS().type ~= "heads" end

    panel:Add(W.Section(panel.content, w, L("Display")))
    panel:Add(W.Segmented(panel.content, w, nil, C.DISPLAY_TYPES, function() return DS().type end, function(v)
        local tr = TR()
        local was = DS().type
        DS().type = v
        -- above heads can't work on enemies: pick the obvious ally scope instead of leaving it broken,
        -- and remember what it was -- trying "Above heads" and going back must not leave a tracker that
        -- watches group members instead of enemies (it then stays empty: player report)
        if v == "heads" and (tr.type ~= "effect" or not C.HEAD_SCOPES[tr.scope]) then
            tr.headsRestore = { type = tr.type, scope = tr.scope }
            tr.type, tr.scope = "effect", "group"
        elseif was == "heads" and v ~= "heads" and type(tr.headsRestore) == "table" then
            if tr.type == "effect" and tr.scope == "group" then
                tr.type, tr.scope = tr.headsRestore.type or tr.type, tr.headsRestore.scope or tr.scope
            end
            tr.headsRestore = nil
        end
    end))
    panel:Add(W.Note(panel.content, w, function()
        local r = TR().headsRestore
        local scope = r and C.Label(C.SCOPES, r.scope or "enemies") or ""
        return L("|cE0A060\"Look on\" was switched from <<1>> to Group members: above heads only works on allies. Pick another display to switch it back.|r", scope)
    end, 34), 34, function() return heads() and type(TR().headsRestore) == "table" end)
    local guard, guardH, guardVisible = HeadsGuard(panel, w)
    panel:Add(guard, guardH, guardVisible)
    panel:Add(W.Note(panel.content, w, L("Each entry floats above the ally it belongs to (group members, you, or your companion). Height, distance and fading are in Settings > Above heads."), 34), 34,
        function() return heads() and not guardVisible() end)
    panel:Add(W.Segmented(panel.content, w, L("Style"), C.BAR_STYLES, function() return DS().style end, function(v) DS().style = v end), 50, windowed)

    panel:Add(W.Section(panel.content, w, L("Size")))
    panel:Add(W.Slider(panel.content, w, L("Width"), 80, 700, 5, function() return DS().width end, function(v) DS().width = v end), 44, barsOrText)
    panel:Add(W.Slider(panel.content, w, L("Row height"), 10, 60, 1, function() return DS().height end, function(v) DS().height = v end), 44, barsOrText)
    panel:Add(W.Slider(panel.content, w, L("Icon size"), 16, 128, 1, function() return DS().iconSize end, function(v) DS().iconSize = v end), 44,
        function() return DS().type == "icons" or DS().type == "alert" or DS().type == "heads" end)
    -- icons (Casual player Geldis: "i cant change stacks size and positions", "empty space between icon and border")
    local function icons() return DS().type == "icons" end
    panel:Add(W.Slider(panel.content, w, L("Icon padding"), 0, 12, 1, function() return DS().iconPadding end, function(v) DS().iconPadding = v end,
        function(v) return v == 0 and L("None") or string.format("%d px", v) end,
        L("Space between the picture and its square (Icon background, Text & colors). 0 = the picture fills it.")), 44, icons)
    panel:Add(W.Slider(panel.content, w, L("Trim the icon's own edge"), 0, 15, 1, function() return DS().iconTrim end, function(v) DS().iconTrim = v end,
        function(v) return v == 0 and L("None") or string.format("%d%%", v) end,
        L("Cuts this much off each side of the picture -- for icons with a dark rim drawn in. A gap between the icon and its border is Icon padding (above); set that to 0.")), 44, icons)
    panel:Add(W.Dropdown(panel.content, w, L("Stack count position"), C.ICON_STACK_POS, function() return DS().iconStackPos end,
        function(v) DS().iconStackPos = v end), 30, icons)
    panel:Add(W.Dropdown(panel.content, w, L("Icon timer"), C.ICON_TIMERS, function() return DS().iconTimer end, function(v) DS().iconTimer = v end,
        L("How an icon shows time running out: a dark sweep over it, or the icon itself emptying.")), 30, is("icons"))
    panel:Add(W.Dropdown(panel.content, w, L("Timer counts down to"), C.TIMER_TO, function() return DS().timerTo end, function(v) DS().timerTo = v end,
        L("Ability timers and procs with a buff and a cooldown. Each part: the buff's time (e.g. 6 s), then the rest of the cooldown (4 s, red). Ready: the time until it can happen again (10 s), green while the buff is up, red after. A rule \"Buff is up = yes\" can colour the buff part any way you like. Cycles (Off Balance, then its immunity): each part = every phase on its own time (7, then 15); ready = one run to ready (22), the lengths taken from the game.")),
        30, function() return DS().type == "icons" or DS().type == "bars" or DS().type == "alert" end)
    panel:Add(W.Slider(panel.content, w, L("Icons per line"), 1, 20, 1, function() return DS().columns end, function(v) DS().columns = v end), 44, is("icons"))
    panel:Add(W.Slider(panel.content, w, L("Timer text: move right / left"), -50, 50, 1, function() return DS().timerOffsetX end,
        function(v) DS().timerOffsetX = v end, nil, L("Moves the time on each icon (pixels).")), 44, is("icons"))
    panel:Add(W.Slider(panel.content, w, L("Timer text: move down / up"), -50, 50, 1, function() return DS().timerOffsetY end,
        function(v) DS().timerOffsetY = v end, nil, L("Positive = down.")), 44, is("icons"))
    panel:Add(W.Slider(panel.content, w, L("Bars per column"), 0, 24, 1, function() return DS().barRows end, function(v) DS().barRows = v end,
        function(v) return v == 0 and L("One column") or tostring(v) end, L("A new column after this many bars (e.g. 6: a group of 12 in 6 x 2, like BuffTheGroup).")), 44,
        function() return DS().type == "bars" and not DS().vertical end)
    panel:Add(W.Slider(panel.content, w, L("Spacing"), 0, 30, 1, function() return DS().spacing end, function(v) DS().spacing = v end), 44,
        function() return DS().type == "bars" or DS().type == "icons" or DS().type == "heads" end)
    panel:Add(W.Slider(panel.content, w, L("Scale"), 0.5, 3, 0.05, function() return DS().scale end, function(v) DS().scale = v end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end), 44, notHeads)

    -- Meter: number tiles
    local meter = is("meter")
    panel:Add(W.Slider(panel.content, w, L("Tile width"), 40, 400, 2, function() return DS().meterWidth end, function(v) DS().meterWidth = v end), 44, meter)
    panel:Add(W.Slider(panel.content, w, L("Tile height"), 20, 120, 1, function() return DS().meterHeight end, function(v) DS().meterHeight = v end), 44, meter)
    panel:Add(W.Slider(panel.content, w, L("Tiles per line"), 1, 12, 1, function() return DS().columns end, function(v) DS().columns = v end,
        nil, L("Several values side by side (e.g. spell and physical resist), or set Grow to Down to stack them.")), 44, meter)
    panel:Add(W.Slider(panel.content, w, L("Space between tiles"), 0, 30, 1, function() return DS().spacing end, function(v) DS().spacing = v end), 44, meter)
    panel:Add(W.Dropdown(panel.content, w, L("Number roll"), C.METER_ANIMS, function() return DS().meterAnim end, function(v) DS().meterAnim = v end,
        L("When a value changes the number rolls to it.")), 30, meter)
    panel:Add(W.Checkbox(panel.content, w, L("Caption (PEN, POWER...)"), function() return DS().meterCaption end, function(v) DS().meterCaption = v end), 26, meter)
    panel:Add(W.Slider(panel.content, w, L("Caption size"), 0, 30, 1, function() return DS().meterCaptionSize end, function(v) DS().meterCaptionSize = v end,
        function(v) return v == 0 and L("Auto (a third of the tile height)") or (v .. " px") end, nil, function() return not DS().meterCaption end), 44, meter)
    panel:Add(W.Checkbox(panel.content, w, L("Coloured line on the left"), function() return DS().meterAccent end, function(v) DS().meterAccent = v end,
        L("Gold; recoveries in their resource colour; a rule's Color changes it.")), 26, meter)
    panel:Add(W.Checkbox(panel.content, w, L("The line fills up toward the cap"), function() return DS().meterGauge end, function(v) DS().meterGauge = v end,
        L("Values with a cap (penetration vs. the enemy's armour, crit damage vs. 125 %): the line on the left fills up as you get closer, full at the cap.")), 26, meter)
    panel:Add(W.Checkbox(panel.content, w, L("Colour by the cap (vs. my target)"), function() return DS().meterCapColors end, function(v) DS().meterCapColors = v end,
        L("Penetration and crit damage against your target: red below the cap, green at it, blue more than 10 % over it (wasted). With no target it stays white. A rule's colour wins.")), 26, meter)

    panel:Add(W.Section(panel.content, w, L("Layout")), 30, notAlert)
    panel:Add(W.Dropdown(panel.content, w, L("Grow"), C.GROW, function() return DS().grow end, function(v) DS().grow = v end), 30, windowed)
    panel:Add(W.Dropdown(panel.content, w, L("Sort by"), C.SORTS, function() return DS().sort end, function(v) DS().sort = v; DS().sortChosen = true end), 30, notAlert)
    panel:Add(W.Checkbox(panel.content, w, L("Lock each entry's spot (leave a gap when missing)"), function() return DS().keepSlots end,
        function(v)
            local t = UI.Current()
            DS().keepSlots = v
            if v and t then
                -- a spot per listed ability, in list order, also while it's missing
                DS().sort, DS().sortChosen = "fixed", true
                local tr = t.trigger
                if tr.type == "effect" and tr.mode == "present" then tr.mode, tr.perAbility = "always", true end
            end
        end,
        L("Every listed ability keeps its own place (in the order of the list on the Trigger tab): when it's not up, its spot stays empty instead of the other entries moving. Turning it on also sets Sort by to Fixed and, for buffs / debuffs, Show to \"Always\" with one entry per ability.")), 26, windowed)
    panel:Add(W.Slider(panel.content, w, L("Max entries"), 1, 40, 1, function() return DS().maxShown end, function(v) DS().maxShown = v; DS().maxChosen = true end), 44, windowed)
    panel:Add(W.Slider(panel.content, w, L("Max icons per person"), 1, 10, 1, function() return math.min(DS().maxShown, 10) end, function(v) DS().maxShown = v end), 44, heads)
    panel:Add(W.Checkbox(panel.content, w, L("Also above my own head"), function() return DS().headSelf end, function(v) DS().headSelf = v end,
        L("Off: only other group members get icons.")), 26, heads)

    panel:Add(W.Section(panel.content, w, L("Content")))
    panel:Add(W.Checkbox(panel.content, w, L("Header (icon, title, uptime)"), function() return DS().showHeader end, function(v) DS().showHeader = v end), 26, windowed)
    panel:Add(W.Slider(panel.content, w, L("Header text size"), 0, 48, 1, function() return DS().headerFontSize end,
        function(v) DS().headerFontSize = v end, function(v) return v == 0 and L("Style's") or tostring(v) end,
        L("The window's title. 0 = the style's own; any other size uses this tracker's font and outline (Text & colors), and the header grows to fit.")),
        44, function() return windowed() and DS().showHeader end)
    panel:Add(W.Edit(panel.content, w, L("Title (empty = tracker name)"), function() return DS().title end, function(v) DS().title = U.Trim(v) end), 48,
        function() return windowed() and DS().showHeader end)
    panel:Add(W.Checkbox(panel.content, w, L("Show combat uptime % in the header"), function() return DS().showUptime end, function(v) DS().showUptime = v end), 26,
        function() return windowed() and DS().showHeader end)
    panel:Add(W.Checkbox(panel.content, w, L("Ability icon on each bar"), function() return DS().showRowIcon end, function(v) DS().showRowIcon = v end), 26, is("bars"))
    panel:Add(W.Checkbox(panel.content, w, L("Name text"), function() return DS().showName end, function(v) DS().showName = v end), 26, is("bars"))
    panel:Add(W.Checkbox(panel.content, w, L("Timer text"), function() return DS().showTimer end, function(v) DS().showTimer = v end), 26,
        function() return DS().type ~= "text" end)
    panel:Add(W.Checkbox(panel.content, w, L("Stack count"), function() return DS().showStacks end, function(v) DS().showStacks = v end), 26,
        function() return DS().type == "bars" or DS().type == "icons" or DS().type == "heads" end)
    panel:Add(W.Checkbox(panel.content, w, L("Highlight my current target"), function() return DS().highlightTarget end, function(v) DS().highlightTarget = v end), 26, notHeads)
    panel:Add(W.Checkbox(panel.content, w, L("Grey out missing / ready entries"), function() return DS().desaturateInactive end, function(v) DS().desaturateInactive = v end), 26)
    panel:Add(W.Slider(panel.content, w, L("Border thickness"), 0, 12, 1, function() return DS().borderSize end, function(v) DS().borderSize = v end,
        function(v) return v == 0 and L("None") or string.format("%d px", v) end,
        L("The coloured border: target highlight, glow rules and a proc's state. 0 = no plain outline (a highlight, glow or rule colour still shows 1 px).")), 44, function() return DS().type ~= "text" and DS().type ~= "alert" end)
    panel:Add(W.Checkbox(panel.content, w, L("Game ability frame on proc icons"), function() return DS().gameFrame end, function(v) DS().gameFrame = v end,
        L("The action bar's own frame around proc icons (My procs), tinted by state.")), 26, function() return DS().type == "icons" end)
    panel:Add(W.Checkbox(panel.content, w, L("Proc details on icons"), function() return DS().procCards end, function(v) DS().procCards = v end,
        L("Resource sets (Bahsei's Mania, Coral Riptide...): your resource as a gauge inside the icon (green at or below the line, red above it), a line where the bonus is full, the bonus as the big number and the resource % along the bottom -- green when the bonus is full, gold when partial. Roaring Opportunist: the Major Slayer the game would give right now (top right, blue; green at the maximum) and how many players have your Slayer, you included (bottom left, gold when fewer than half the group). Running procs get a green frame.")),
        26, function() return DS().type == "icons" end)
    panel:Add(W.Checkbox(panel.content, w, L("Keep the window visible when empty"), function() return DS().showEmpty end, function(v) DS().showEmpty = v end,
        L("Keeps the window's header on screen when nothing is shown, so it doesn't pop in and out with every fight. Needs the header: without one there's nothing to keep, and the empty window hides.")), 26, windowed)
    panel:Add(W.Checkbox(panel.content, w, L("Pulse when about to expire"), function() return DS().blink end, function(v) DS().blink = v end), 26)
    panel:Add(W.Slider(panel.content, w, L("Pulse in the last"), 0.5, 15, 0.5, function() return DS().blinkThreshold end, function(v) DS().blinkThreshold = v end,
        function(v) return string.format("%.1fs", v) end, nil, function() return not DS().blink end))

    panel:Add(W.Section(panel.content, w, L("Transparency")))
    panel:Add(W.Slider(panel.content, w, L("Draw level (higher = on top of other trackers)"), 0, 10, 1, function() return DS().drawLevel end,
        function(v) DS().drawLevel = v end), 44, function() return DS().type ~= "heads" end)
    panel:Add(W.Slider(panel.content, w, L("Window"), 0, 1, 0.05, function() return DS().alpha end, function(v) DS().alpha = v end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end))
    panel:Add(W.Checkbox(panel.content, w, L("Vertical bars (columns)"), function() return DS().vertical end, function(v) DS().vertical = v end,
        L("Each entry becomes a column: icon at the bottom, bar filling upward, timer on top. Width = column length, row height = column thickness.")), 26, is("bars"))
    panel:Add(W.Checkbox(panel.content, w, L("Bars empty toward the right"), function() return DS().fillReverse end, function(v) DS().fillReverse = v end,
        L("Off: bars empty toward the left (default). On: they're anchored left and empty toward the right edge.")), 26, is("bars"))
    panel:Add(W.Checkbox(panel.content, w, L("Bars empty toward the middle"), function() return DS().fillCenter end, function(v) DS().fillCenter = v end,
        L("Both ends run in toward the centre (Combat Metronome's centred bar).")), 26, function() return is("bars")() and not DS().vertical end)
    panel:Add(W.Slider(panel.content, w, L("Bars"), 0, 1, 0.05, function() return DS().barAlpha end, function(v) DS().barAlpha = v end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end), 44, is("bars"))
    panel:Add(W.TextureSwatches(panel.content, w, L("Bar texture"), function() return DS().texture end, function(v) DS().texture = v end), 48, is("bars"))
end

local function BuildTextTab(panel, w)
    local tokenHelp = L("Tokens: {name} {unit} {account} {roleicon} {time} {stacks} {pct} {value} {max} {calc} {phase} {source} {elapsed} {duration} {id}")
    panel:Add(W.Section(panel.content, w, L("Text")))
    panel:Add(W.Note(panel.content, w, tokenHelp, 20), 20)
    panel:Add(W.Edit(panel.content, w, L("Bar label"), function() return DS().labelFormat end, function(v) DS().labelFormat = v end), 48,
        function() return DS().type == "bars" end)
    -- HangryGinger: "able to have the Text Centered as well, even potentially above the actual bar"
    panel:Add(W.Dropdown(panel.content, w, L("Label position"), { { "left", L("in the bar, left") }, { "center", L("in the bar, centred") },
        { "above", L("above the bar, left") }, { "aboveCenter", L("above the bar, centred") } },
        function() return DS().labelPos end, function(v) DS().labelPos = v end), 30, function() return DS().type == "bars" and not DS().vertical end)
    -- the second colour inside a bar: the end window (Global cooldown: your ping) -- here too, with the other colours
    panel:Add(W.Color(panel.content, w, L("End window colour (global cooldown: ping)"), function() return DS().zoneColor end, function(v) DS().zoneColor = v end), 30,
        function() return DS().type == "bars" and T().trigger.type == "gcd" end)
    panel:Add(W.Edit(panel.content, w, L("Label under each icon (empty = none)"), function() return DS().iconLabelFormat end, function(v) DS().iconLabelFormat = v end), 48,
        function() return DS().type == "icons" end)
    panel:Add(W.Edit(panel.content, w, L("Line format"), function() return DS().textFormat end, function(v) DS().textFormat = v end), 48,
        function() return DS().type == "text" end)
    panel:Add(W.Checkbox(panel.content, w, L("Centre the line"), function() return DS().textCenter end, function(v) DS().textCenter = v end), 26,
        function() return DS().type == "text" end)
    -- HangryGinger: "is there a way to remove the black box so it's just floating text?" (= Window background, fully transparent)
    panel:Add(W.Checkbox(panel.content, w, L("Just the text (no box behind it)"), function() return (DS().background[4] or 1) <= 0.01 end, function(v)
        local b = DS().background
        DS().background = { b[1], b[2], b[3], v and 0 or 0.82 }
    end, L("The same as making the window background fully transparent (Text & colors).")), 26,
        function() return DS().type == "text" end)
    panel:Add(W.Edit(panel.content, w, L("Alert text"), function() return DS().alertFormat end, function(v) DS().alertFormat = v end), 48,
        function() return DS().type == "alert" end)
    panel:Add(W.Dropdown(panel.content, w, L("Time format"), C.TIME_FORMATS, function() return DS().timeFormat end, function(v) DS().timeFormat = v end))
    panel:Add(W.Dropdown(panel.content, w, L("Font"), C.FONT_FACES, function() return DS().fontFace end, function(v) DS().fontFace = v end))
    panel:Add(W.Slider(panel.content, w, L("Font size"), 0, 48, 1, function() return DS().fontSize end, function(v) DS().fontSize = v end,
        function(v) return v == 0 and L("Auto") or tostring(v) end))
    panel:Add(W.Dropdown(panel.content, w, L("Font outline"), C.FONT_EFFECTS, function() return DS().fontEffect end, function(v) DS().fontEffect = v end))
    -- with the other text settings (Geldis: "it would be logical to move stacks text size into text & colors tab")
    panel:Add(W.Slider(panel.content, w, L("Stack count size"), 0, 48, 1, function() return DS().iconStackSize end, function(v) DS().iconStackSize = v end,
        function(v) return v == 0 and L("Auto") or tostring(v) end, L("The stack number in the icon's corner (its place: Display tab).")), 44,
        function() return DS().type == "icons" end)

    panel:Add(W.Section(panel.content, w, L("Colors")))
    panel:Add(W.Segmented(panel.content, w, nil, C.COLOR_MODES, function() return DS().colorMode end, function(v) DS().colorMode = v end))
    local function timed() return DS().colorMode ~= "solid" end
    panel:Add(W.Color(panel.content, w, L("Just applied"), function() return DS().colorFull end, function(v) DS().colorFull = v end), 30, timed)
    panel:Add(W.Color(panel.content, w, L("Half way"), function() return DS().colorMid end, function(v) DS().colorMid = v end), 30, timed)
    panel:Add(W.Color(panel.content, w, L("About to expire"), function() return DS().colorEnd end, function(v) DS().colorEnd = v end), 30, timed)
    panel:Add(W.Color(panel.content, w, L("Color"), function() return DS().colorSolid end, function(v) DS().colorSolid = v end), 30,
        function() return DS().colorMode == "solid" end)
    panel:Add(W.Color(panel.content, w, L("Text"), function() return DS().textColor end, function(v) DS().textColor = v end))
    panel:Add(W.Checkbox(panel.content, w, L("Separate timer and stack colors"), function() return DS().separateTextColors end,
        function(v) DS().separateTextColors = v end))
    local function sep() return DS().separateTextColors end
    panel:Add(W.Color(panel.content, w, L("Timer text"), function() return DS().timerColor end, function(v) DS().timerColor = v end), 30, sep)
    panel:Add(W.Color(panel.content, w, L("Stack text"), function() return DS().stackColor end, function(v) DS().stackColor = v end), 30, sep)
    local function hasCooldown()
        local tr = T().trigger
        return tr.type == "procs" or (tr.type == "combat" and tr.cooldown > 0)
    end
    panel:Add(W.Color(panel.content, w, L("Cooldown (ability timers)"), function() return DS().cooldownColor end, function(v) DS().cooldownColor = v end), 30, hasCooldown)
    panel:Add(W.Checkbox(panel.content, w, L("Grey icon while on cooldown"), function() return DS().cooldownDesaturate end,
        function(v) DS().cooldownDesaturate = v end), 26, hasCooldown)
    panel:Add(W.Color(panel.content, w, L("Window background (the box around them all)"), function() return DS().background end, function(v) DS().background = v end))
    -- the square behind each icon (Geldis: "2 backgrounds (window background and icon background) but they both called
    -- just background" -- this one could only be changed with a rule)
    panel:Add(W.Color(panel.content, w, L("Icon background (behind each icon)"), function() return DS().iconBg end,
        function(v) DS().iconBg = v end), 30, function() return DS().type == "icons" end)
    -- the dark strip behind each bar (Clean / Compact; Classic has none)
    panel:Add(W.Color(panel.content, w, L("Bar background (behind each bar)"), function() return DS().trackColor end,
        function(v) DS().trackColor = v end), 30, function() return DS().type == "bars" and DT.Style.Look(DS()).track end)
    panel:Add(W.Checkbox(panel.content, w, L("Border around every entry"), function() return DS().rowBorder end, function(v) DS().rowBorder = v end,
        L("One clean border around each bar / icon, as thick as \"Border thickness\" (Display tab). The target highlight and rules still colour it.")),
        26, function() return DS().type == "bars" or DS().type == "icons" or DS().type == "meter" end)
    panel:Add(W.Color(panel.content, w, L("Border color"), function() return DS().borderColor end, function(v) DS().borderColor = v end), 30,
        function() return DS().rowBorder and (DS().type == "bars" or DS().type == "icons" or DS().type == "meter") end)
    panel:Add(W.Color(panel.content, w, L("Caption"), function() return DS().meterCaptionColor end, function(v) DS().meterCaptionColor = v end), 30,
        function() return DS().type == "meter" end)

    -- proc cards (My procs): the four colours of the card, and the resource % strip
    local function procIcons() return T().trigger.type == "procs" and DS().type == "icons" end
    panel:Add(W.Section(panel.content, w, L("Proc colors")), 30, procIcons)
    panel:Add(W.Color(panel.content, w, L("Full bonus / running / can proc"), function() return DS().procColorOk end, function(v) DS().procColorOk = v end), 30, procIcons)
    panel:Add(W.Color(panel.content, w, L("Partial bonus / Ultimate ready / few players"), function() return DS().procColorPart end, function(v) DS().procColorPart = v end), 30, procIcons)
    panel:Add(W.Color(panel.content, w, L("Can't proc / wasted"), function() return DS().procColorBad end, function(v) DS().procColorBad = v end), 30, procIcons)
    panel:Add(W.Color(panel.content, w, L("Buff time number (top right)"), function() return DS().procColorInfo end, function(v) DS().procColorInfo = v end), 30, procIcons)
    panel:Add(W.Checkbox(panel.content, w, L("Resource % along the bottom"), function() return DS().procPercent end, function(v) DS().procPercent = v end,
        L("The strip with your resource % on resource sets (Bahsei, Coral, MK, Pearls, Master Architect...). The gauge's colour already tells you the same.")), 26, procIcons)

    panel:Add(W.Section(panel.content, w, L("Icon")))
    -- multiplies the icon's colours: grey darkens a too-bright icon, a colour tints it; white = as it is
    panel:Add(W.Color(panel.content, w, L("Icon tint (grey = darker; transparency = see-through)"), function() return DS().iconTint end, function(v) DS().iconTint = v end))
    panel:Add(W.Checkbox(panel.content, w, L("Use this icon for every entry"), function() return DS().forceIcon end, function(v) DS().forceIcon = v end,
        L("Shows the icon below (an ability ID or any texture path) instead of each effect's own icon.")))
    panel:Add(W.Edit(panel.content, w, L("Header / missing icon: ability ID or texture path (empty = automatic)"),
        function() return T().iconOverride end, function(v) T().iconOverride = U.Trim(v) end), 48)
end

local function BuildConditionsTab(panel, w)
    panel:Add(W.Section(panel.content, w, L("Conditions")))
    panel:Add(W.Note(panel.content, w, L("Rules run on every entry, top to bottom; later rules win. Sounds and alerts play once when a rule starts matching."), 34), 34)
    local cont, h = ConditionsEditor(panel, w)
    panel:Add(cont, h)
end

local function BuildLoadTab(panel, w)
    local function LD() return T().load end
    local function SetFlag(setName, key) return function() return LD()[setName][key] == true end, function(v) LD()[setName][key] = v or nil end end
    -- "Only when / Never when" for a list (Tony: HyperTools' "!" prefix, as a plain switch). Shown once the
    -- list has something in it.
    local function Polarity(group, label, used)
        panel:Add(W.Segmented(panel.content, w, label, C.LOAD_POLARITY,
            function() return LD().never[group] and "never" or "only" end,
            function(v) LD().never[group] = (v == "never") or nil end), 50, used)
    end

    panel:Add(W.Section(panel.content, w, L("When this tracker is active")))
    UI.loadStatus = W.Label(panel.content, "", "ZoFontGame", { 0.62, 0.88, 0.80, 1 })
    UI.loadStatus:SetDimensions(w, 24)
    UI.loadStatus:SetVerticalAlignment(TEXT_ALIGN_TOP)
    -- long reasons wrap onto a second line instead of being cut
    UI.loadStatus.autoHeight = function()
        local h = math.max(24, W.TextHeight(UI.loadStatus:GetText(), w, "game", UI.loadStatus))
        UI.loadStatus:SetDimensions(w, h)
        return h
    end
    panel:Add(UI.loadStatus, 24)
    -- re-checked every second while the editor is open (combat, zone, boss can change any time)
    function UI.RefreshLoadStatus()
        local t = UI.Current()
        if not t then UI.loadStatus:SetText(""); return end
        local ok, reason = DT.Load.Check(t, DT.Load.Context())
        if ok then
            UI.loadStatus:SetText(L("Active right now"))
            UI.loadStatus:SetColor(0.62, 0.88, 0.80, 1)
        else
            local text = L("Not active right now: <<1>>", reason or "?")
            if DT.editorPreview or DT.testMode then text = text .. L(" (sample data still shows it)") end
            UI.loadStatus:SetText(text)
            UI.loadStatus:SetColor(0.9, 0.6, 0.4, 1)
        end
        -- re-flow the tab if the status needs more (or fewer) lines than before
        local h = UI.loadStatus.autoHeight()
        if h ~= UI.loadStatus.lastHeight then
            UI.loadStatus.lastHeight = h
            if not panel.scroll:IsHidden() then panel:Layout() end
        end
    end
    W.Register(UI.RefreshLoadStatus, "load status")
    panel:Add(W.Segmented(panel.content, w, L("Combat"), C.COMBAT_LOAD, function() return LD().combat end, function(v) LD().combat = v end))
    panel:Add(W.Slider(panel.content, w, L("Stay shown after combat"), 0, 30, 1, function() return LD().combatLinger end,
        function(v) LD().combatLinger = v end, function(v) return v <= 3 and L("3 s (usual)") or string.format("%d s", v) end,
        L("How long it stays after the fight ends. Up to 3 s it's the usual grace (the game's combat state flickers mid-fight).")), 44,
        function() return LD().combat == "in" end)
    panel:Add(W.Segmented(panel.content, w, L("Group"), C.GROUP_LOAD, function() return LD().group end, function(v) LD().group = v end))
    -- boss fights / trash: per tracker rather than a profile swap mid-instance (nothing rebuilds, a boss frame
    -- blinking out doesn't throw every window around)
    panel:Add(W.Segmented(panel.content, w, L("Fights"), C.FIGHT_LOAD,
        function() return LD().bossOnly and "boss" or (LD().trashOnly and "trash" or "any") end,
        function(v) LD().bossOnly, LD().trashOnly = v == "boss", v == "trash" end), 50)
    panel:Add(W.Checkbox(panel.content, w, L("Hide while I'm dead"), function() return LD().hideDead end, function(v) LD().hideDead = v end))
    panel:Add(W.Segmented(panel.content, w, L("Werewolf form"), C.WEREWOLF_LOAD, function() return LD().werewolf end, function(v) LD().werewolf = v end), 50)

    panel:Add(W.Section(panel.content, w, L("Zones (none checked = everywhere)")))
    Polarity("zones", L("The zones below:"), function() return next(LD().zoneTypes) ~= nil or #LD().zoneIds > 0 or #LD().zoneNames > 0 end)
    for _, z in ipairs(C.ZONE_TYPES) do
        local g, s = SetFlag("zoneTypes", z[1])
        panel:Add(W.Checkbox(panel.content, w / 2, z[2], g, s), 26, nil, 0)
    end
    panel:Add(W.Edit(panel.content, w, L("Zone IDs (comma separated)"), function() return U.JoinList(LD().zoneIds) end,
        function(v) LD().zoneIds = U.ParseIds(v) end), 48)
    panel:Add(W.Button(panel.content, 220, L("Add the zone I'm in"), function()
        local id = DT.Load.zone.id
        if id and id > 0 and not U.Contains(LD().zoneIds, id) then LD().zoneIds[#LD().zoneIds + 1] = id end
        UI.Changed()
    end), 28)

    panel:Add(W.Section(panel.content, w, L("Role and class (none checked = any)")))
    Polarity("roles", L("The roles below:"), function() return next(LD().roles) ~= nil end)
    for _, r in ipairs(C.ROLES) do
        local g, s = SetFlag("roles", r[1])
        panel:Add(W.Checkbox(panel.content, w, r[2], g, s))
    end
    Polarity("classes", L("The classes below:"), function() return next(LD().classes) ~= nil end)
    for _, c in ipairs(C.CLASSES) do
        local g, s = SetFlag("classes", c[1])
        local name = c[2]
        if type(GetClassName) == "function" then
            local ok, n = pcall(GetClassName, GENDER_MALE or 1, c[1])
            if ok and n and n ~= "" then name = U.CleanName(n) end
        end
        panel:Add(W.Checkbox(panel.content, w, name, g, s))
    end

    panel:Add(W.Section(panel.content, w, L("Gear and characters")))
    Polarity("sets", L("The sets below:"), function() return LD().setId > 0 or #LD().setNames > 0 end)
    panel:Add(W.Edit(panel.content, w, L("Set equipped (set ID, 0 = off)"), function() return tostring(LD().setId) end,
        function(v) LD().setId = tonumber(v) or 0 end), 48)
    panel:Add(W.Checkbox(panel.content, w, L("Needs the full set (its full bonus)"), function() return LD().setFull end, function(v) LD().setFull = v end,
        L("Uses the set's own piece count: 5 for most sets, 2 for monster sets, 1 for mythics.")), 26, function() return LD().setId > 0 end)
    panel:Add(W.Slider(panel.content, w, L("Pieces needed"), 1, 12, 1, function() return LD().setPieces end, function(v) LD().setPieces = v end,
        nil, nil, function() return LD().setId == 0 or LD().setFull end))
    panel:Add(W.Checkbox(panel.content, w, L("Count the other weapon bar too"), function() return LD().setBackbar end, function(v) LD().setBackbar = v end,
        L("On: set pieces on your other bar count (a two-hander counts twice).")), 26, function() return LD().setId > 0 end)
    Polarity("skills", L("The skills below:"), function() return #LD().skills > 0 or #LD().skillNames > 0 end)
    panel:Add(W.Edit(panel.content, w, L("One of these skills slotted (IDs or names, either bar)"),
        function()
            local parts = {}
            for _, id in ipairs(LD().skills) do parts[#parts + 1] = tostring(id) end
            for _, n in ipairs(LD().skillNames) do parts[#parts + 1] = n end
            return table.concat(parts, ", ")
        end,
        function(v) LD().skills = U.ParseIds(v); LD().skillNames = U.ParseNames(v) end), 48)
    panel:Add(W.Edit(panel.content, w, L("One of these full sets worn (set names in English, comma separated)"),
        function() return table.concat(LD().setNames, ", ") end,
        function(v)
            local list = {}
            for part in tostring(v):gmatch("[^,]+") do
                local n = U.Trim(part)
                if n ~= "" then list[#list + 1] = n end
            end
            LD().setNames = list
        end, L("E.g. Roar of Alkosh. Matched in any game language when LibSets is installed (on English clients without it too). Perfected versions count.")), 48)
    Polarity("cp", L("The champion skills below:"), function() return #LD().cpSkills > 0 end)
    panel:Add(W.Edit(panel.content, w, L("One of these champion skills slotted (champion skill IDs)"),
        function() local p = {}; for _, id in ipairs(LD().cpSkills) do p[#p + 1] = tostring(id) end; return table.concat(p, ", ") end,
        function(v) LD().cpSkills = U.ParseIds(v) end, L("E.g. 51 = Expert Evasion, 52 = Slippery.")), 48)
    panel:Add(W.Edit(panel.content, w, L("Zones whose name contains (comma separated; see \"The zones below\" above)"),
        function() return U.JoinList(LD().zoneNames) end,
        function(v) LD().zoneNames = U.ParseNames(v) end), 48)
    Polarity("bosses", L("The bosses below:"), function() return #LD().bossNames > 0 end)
    panel:Add(W.Edit(panel.content, w, L("A boss whose name contains (comma separated)"),
        function() return U.JoinList(LD().bossNames) end,
        function(v) LD().bossNames = U.ParseNames(v) end), 48)
    Polarity("characters", L("The characters below:"), function() return #LD().characters > 0 end)
    panel:Add(W.Edit(panel.content, w, L("These characters (comma separated, empty = all)"),
        function() return U.JoinList(LD().characters) end,
        function(v)
            local list = {}
            for part in tostring(v):gmatch("[^,]+") do
                local n = U.Trim(part)
                if n ~= "" then list[#list + 1] = n end
            end
            LD().characters = list
        end), 48)
end

local function BuildPositionTab(panel, w)
    local function PS() return T().position end
    local function heads() return DS().type == "heads" end
    local function notHeads() return DS().type ~= "heads" end
    panel:Add(W.Section(panel.content, w, L("Position")))
    panel:Add(W.Note(panel.content, w, L("Above-heads trackers follow your allies on screen, so there is nothing to place. Height above the head is in Settings > Above heads."), 34), 34, heads)
    panel:Add(W.Note(panel.content, w, L("Drag windows directly with \"Move windows\" (top right), or attach this tracker to another one so they move together."), 34), 34, notHeads)
    panel:Add(W.Dropdown(panel.content, w, L("Attach to"), function()
        local opts = { { "", L("Nothing (free position)") } }
        local me = UI.Current()
        for _, t in ipairs(P.ActiveTrackers()) do
            if (not me or t.id ~= me.id) and t.display.type ~= "heads" then opts[#opts + 1] = { t.id, t.name } end
        end
        return opts
    end, function() return PS().anchorTo end, function(v) PS().anchorTo = v end), 30, notHeads)
    local function attached() return notHeads() and PS().anchorTo ~= "" end
    panel:Add(W.Dropdown(panel.content, w, L("Side"), C.ANCHOR_SIDES, function() return PS().anchorSide end, function(v) PS().anchorSide = v end), 30, attached)
    panel:Add(W.Slider(panel.content, w, L("Gap"), -50, 100, 1, function() return PS().gap end, function(v) PS().gap = v end), 44, attached)
    -- HangryGinger: "couldn't really get it to be centered while using below or above - maybe an offset slider or center option"
    panel:Add(W.Dropdown(panel.content, w, L("Line up"), function()
        local across = PS().anchorSide == "above" or PS().anchorSide == "below"
        return { { "start", across and L("Left edges") or L("Top edges") }, { "center", L("Centred") },
            { "end", across and L("Right edges") or L("Bottom edges") } }
    end, function() return PS().anchorAlign end, function(v) PS().anchorAlign = v end), 30, attached)
    panel:Add(W.Slider(panel.content, w, L("Then shift it by"), -200, 200, 1, function() return PS().anchorShift end,
        function(v) PS().anchorShift = v end, nil,
        L("Along the edge it's attached to: right is positive (Above / Below), down is positive (Left of / Right of).")), 44, attached)
    local function free() return notHeads() and PS().anchorTo == "" end
    local halfW, halfH = math.floor(GuiRoot:GetWidth() / 2), math.floor(GuiRoot:GetHeight() / 2)
    panel:Add(W.Slider(panel.content, w, L("Horizontal (from screen center)"), -halfW, halfW, 1, function() return PS().x end, function(v) PS().x = v end), 44, free)
    panel:Add(W.Slider(panel.content, w, L("Vertical (from screen center)"), -halfH, halfH, 1, function() return PS().y end, function(v) PS().y = v end), 44, free)
    panel:Add(W.Button(panel.content, 200, L("Center on screen"), function() PS().x, PS().y = -math.floor(DS().width / 2), 0; UI.Changed() end), 28, free)
end

------------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------------

local TAB_NAMES = { L("Trigger"), L("Display"), L("Text & colors"), L("Conditions"), L("Load"), L("Position") }
local TAB_BUILDERS = { BuildTriggerTab, BuildDisplayTab, BuildTextTab, BuildConditionsTab, BuildLoadTab, BuildPositionTab }

function UI.BuildTrackersPage(page, control, width)
    local listCol = BuildList(page, control, 0)
    local edW = width - LIST_W - 14

    local editor = WM:CreateControl(nil, control, CT_CONTROL)
    editor:SetAnchor(TOPLEFT, listCol, TOPRIGHT, 14, 0)
    editor:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)

    local nameRow = W.Edit(editor, edW - 150, nil, function() return T().name end,
        function(v) local t = UI.Current(); if t and U.Trim(v) ~= "" then t.name = U.Trim(v) end end, L("Tracker name"))
    nameRow:SetAnchor(TOPLEFT, editor, TOPLEFT, 0, 0)
    local enabled = W.Checkbox(editor, 140, L("Enabled"), function() return T().enabled end, function(v) T().enabled = v end)
    enabled:SetAnchor(LEFT, nameRow, RIGHT, 12, 0)

    local tabs = {}
    local tabBar = WM:CreateControl(nil, editor, CT_CONTROL)
    tabBar:SetDimensions(edW, 32)
    tabBar:SetAnchor(TOPLEFT, nameRow, BOTTOMLEFT, 0, 8)
    local tabW = (edW - 5 * 4) / 6
    local panels = {}
    page.tab = 1
    local function SelectTab(i)
        page.tab = i
        for j, tb in ipairs(tabs) do
            local sel = j == i
            tb.bg:SetCenterColor(sel and C.GOLD_BG[1] or 0.1, sel and C.GOLD_BG[2] or 0.1, sel and C.GOLD_BG[3] or 0.11, 1)
            tb.bg:SetEdgeColor(sel and C.GOLD[1] or 0.3, sel and C.GOLD[2] or 0.3, sel and C.GOLD[3] or 0.3, 1)
            panels[j].scroll:SetHidden(not sel)
        end
        panels[i]:Layout()
    end
    UI.SelectTab = SelectTab
    for i, name in ipairs(TAB_NAMES) do
        local b = W.FlatButton(tabBar, tabW, 30, name, function() SelectTab(i) end)
        b:SetAnchor(TOPLEFT, tabBar, TOPLEFT, (i - 1) * (tabW + 4), 0)
        tabs[i] = b
    end

    local body = WM:CreateControl(nil, editor, CT_CONTROL)
    body:SetAnchor(TOPLEFT, tabBar, BOTTOMLEFT, 0, 10)
    body:SetAnchor(BOTTOMRIGHT, editor, BOTTOMRIGHT, 0, 0)
    for i, builder in ipairs(TAB_BUILDERS) do
        local panel = W.NewPanel(body, edW - 20)
        panel.scroll:SetAnchorFill()
        panel.scroll:SetHidden(true)
        builder(panel, edW - 30)
        panels[i] = panel
    end

    -- Empty state
    local empty = WM:CreateControl(nil, control, CT_CONTROL)
    empty:SetAnchor(TOPLEFT, listCol, TOPRIGHT, 14, 0)
    empty:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
    local emptyTitle = W.Label(empty, L("Build anything you want to track"), "$(BOLD_FONT)|24|soft-shadow-thick", C.GOLD, TEXT_ALIGN_CENTER)
    emptyTitle:SetAnchor(TOP, empty, TOP, 0, 120)
    local emptyText = W.Label(empty, L("Buffs, debuffs, missing effects, procs, cooldowns, health and ultimate --\nas bars, icons, text or big alerts, with rules, sounds and load conditions."),
        "ZoFontGame", { 0.75, 0.75, 0.75, 1 }, TEXT_ALIGN_CENTER)
    emptyText:SetAnchor(TOP, emptyTitle, BOTTOM, 0, 12)
    emptyText:SetDimensions(edW, 50)
    local b1 = W.Button(empty, 200, L("Create a tracker"), NewTrackerFlow)
    b1:SetAnchor(TOPRIGHT, emptyText, BOTTOM, -8, 20)
    local b2 = W.Button(empty, 200, L("Open the library"), function() UI.SelectPage(2) end)
    b2:SetAnchor(TOPLEFT, emptyText, BOTTOM, 8, 20)
    local b3 = W.Button(empty, 200, L("Import"), UI.ImportFlow)
    b3:SetAnchor(TOP, emptyText, BOTTOM, 0, 60)

    -- exactly one of editor / empty state is visible, decided before anything else can fail
    local function ShowEditorOrEmpty()
        local has = HasTracker()
        editor:SetHidden(not has)
        empty:SetHidden(has)
        return has
    end
    editor:SetHidden(true)
    function page.OnRefresh()
        local has = ShowEditorOrEmpty()
        U.SafeCall("editor: tracker list", page.RefreshList)
        if has then U.SafeCall("editor: tab layout", panels[page.tab].Layout, panels[page.tab]) end
    end
    function page.OnShow()
        if not UI.selectedId then
            local first = P.ActiveTrackers()[1]
            UI.selectedId = first and first.id
        end
        ShowEditorOrEmpty()
        SelectTab(page.tab or 1)
    end
end
