--[[
    Duel Results - window
]]

local DR = DuelResults
local UI = {}
DR.UI = UI

local EM = EVENT_MANAGER
local C = DR.COLORS

local TAB_OVERVIEW, TAB_EFFECTS, TAB_ABILITIES, TAB_HISTORY = 1, 2, 3, 4
local TAB_NAMES = { "Overview", "Effects", "Abilities", "History" }

local DATA_BAR, DATA_HISTORY = 1, 2
local STAT_ROW_HEIGHT = 34
local STAT_BAR_WIDTH = 480
local LIST_BAR_WIDTH = 424
local UPDATE_NAME = DR.name .. "UITick"

UI.tab = TAB_OVERVIEW
UI.player = 1
UI.viewFight = nil -- a history snapshot being viewed, or nil for the current duel
UI.statRows = {}

------------------------------------------------------------------------------------------
-- Overview stat definitions
------------------------------------------------------------------------------------------
local STATS = {
    { label = "Damage Done",     bar = true, value = function(p) return p.damage end },
    { label = "DPS",             bar = true, value = function(p, sec) return p.damage / sec end },
    { label = "Healing Done",    bar = true, value = function(p) return p.healing end },
    { label = "HPS",             bar = true, value = function(p, sec) return p.healing / sec end },
    { label = "Overhealing",     neutral = true, value = function(p) return p.overheal end },
    { label = "Biggest Hit",     value = function(p) return p.biggest end },
    { label = "Critical Rate",   format = DR.FormatPercent, value = function(p) return p.hits > 0 and (p.crits / p.hits * 100) or 0 end },
    { label = "Hits Landed",     format = DR.FormatInt, value = function(p) return p.hits end },
    { label = "Attacks Blocked", format = DR.FormatInt, value = function(p) return p.blocked end },
    { label = "Attacks Dodged",  format = DR.FormatInt, value = function(p) return p.dodged end },
    { label = "Damage Absorbed", value = function(p) return p.absorbed end },
}

------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------
local function SetLabelColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

local function SetBarWidth(tex, width)
    if width < 1 then
        tex:SetHidden(true)
    else
        tex:SetHidden(false)
        tex:SetWidth(width)
    end
end

function UI.GetFight()
    return UI.viewFight or DR.Tracker.current
end

------------------------------------------------------------------------------------------
-- Header
------------------------------------------------------------------------------------------
local function UpdateHeader(f)
    if not f then
        UI.p1Name:SetText("—")
        UI.p2Name:SetText("—")
        UI.p1Sub:SetText("")
        UI.p2Sub:SetText("")
        UI.status:SetText("Waiting…")
        return
    end

    for i = 1, 2 do
        local p = f.players[i]
        local nameLabel = i == 1 and UI.p1Name or UI.p2Name
        local subLabel = i == 1 and UI.p1Sub or UI.p2Sub
        nameLabel:SetText(DR.PlayerLabel(p))

        local sub = (p.displayName ~= "" and p.charName ~= p.displayName) and p.charName or ""
        if f.winner == i then
            sub = C.gold:Colorize("WINNER") .. (sub ~= "" and ("  " .. sub) or "")
        end
        subLabel:SetText(sub)
    end

    local dur = DR.FormatDuration(DR.GetFightDuration(f))
    if not f.endMs then
        UI.status:SetText(C.live:Colorize("LIVE") .. "  " .. dur)
    elseif UI.viewFight then
        UI.status:SetText(os.date("%d %b %H:%M", f.timestamp) .. "\n" .. dur)
    else
        UI.status:SetText(dur .. "\n" .. (f.reason or "Ended"))
    end
end

------------------------------------------------------------------------------------------
-- Overview tab
------------------------------------------------------------------------------------------
local function BuildStatRows()
    for i, stat in ipairs(STATS) do
        local row = CreateControlFromVirtual("$(parent)Stat", UI.overview, "DuelResults_StatRow", i)
        row:SetAnchor(TOPLEFT, UI.overview, TOPLEFT, 0, (i - 1) * STAT_ROW_HEIGHT)
        row.label = row:GetNamedChild("Label")
        row.left = row:GetNamedChild("Left")
        row.right = row:GetNamedChild("Right")
        row.barBg = row:GetNamedChild("BarBg")
        row.barLeft = row:GetNamedChild("BarLeft")
        row.barRight = row:GetNamedChild("BarRight")
        row.label:SetText(zo_strupper(stat.label))
        if not stat.bar then
            row.barBg:SetHidden(true)
            row.barLeft:SetHidden(true)
            row.barRight:SetHidden(true)
        end
        UI.statRows[i] = row
    end
end

local function UpdateOverview(f)
    UI.overviewEmpty:SetHidden(f ~= nil)
    for _, row in ipairs(UI.statRows) do row:SetHidden(f == nil) end
    if not f then
        local last = DR.sv.history[1]
        local text = "Waiting for a duel…\n\n|c6A6A6AChallenge someone, or watch two group members duel."
        if last then
            text = text .. "\nYour last duel is in the History tab."
        end
        UI.overviewEmpty:SetText(text .. "|r")
        return
    end

    local sec = DR.GetFightDuration(f) / 1000
    local p1, p2 = f.players[1], f.players[2]
    for i, stat in ipairs(STATS) do
        local row = UI.statRows[i]
        local v1, v2 = stat.value(p1, sec), stat.value(p2, sec)
        local fmt = stat.format or DR.FormatNumber
        row.left:SetText(fmt(v1))
        row.right:SetText(fmt(v2))

        if stat.neutral or v1 == v2 then
            SetLabelColor(row.left, C.white)
            SetLabelColor(row.right, C.white)
        else
            local p1Better = v1 > v2
            SetLabelColor(row.left, p1Better and C.white or C.dim)
            SetLabelColor(row.right, p1Better and C.dim or C.white)
        end

        if stat.bar then
            local total = v1 + v2
            if total > 0 then
                local w1 = STAT_BAR_WIDTH * (v1 / total)
                SetBarWidth(row.barLeft, w1)
                SetBarWidth(row.barRight, STAT_BAR_WIDTH - w1)
            else
                row.barLeft:SetHidden(true)
                row.barRight:SetHidden(true)
            end
        end
    end
end

------------------------------------------------------------------------------------------
-- Effects / Abilities tabs
------------------------------------------------------------------------------------------
local function SetupBarRow(control, d)
    if not control.icon then
        control.icon = control:GetNamedChild("Icon")
        control.bar = control:GetNamedChild("Bar")
        control.nameLabel = control:GetNamedChild("Name")
        control.valueLabel = control:GetNamedChild("Value")
    end
    control.icon:SetTexture(d.icon or "")
    control.nameLabel:SetText(d.name)
    control.valueLabel:SetText(d.value)
    local r, g, b = d.color:UnpackRGB()
    control.bar:SetColor(r, g, b, 0.6)
    SetBarWidth(control.bar, LIST_BAR_WIDTH * zo_clamp(d.fraction or 0, 0, 1))
    control.tooltip = d.tooltip
end

function UI.OnBarRowEnter(control)
    if control.tooltip then
        ZO_Tooltips_ShowTextTooltip(control, RIGHT, control.tooltip)
    end
end

function UI.OnBarRowExit()
    ZO_Tooltips_HideTextTooltip()
end

local function UpdateToggles(f)
    for i, b in ipairs(UI.toggles) do
        local p = f and f.players[i]
        b:SetText(p and DR.PlayerLabel(p) or ("Player " .. i))
        local selected = UI.player == i
        local color = C["p" .. i]
        b:SetNormalFontColor((selected and color or C.dim):UnpackRGBA())
        local underline = b:GetNamedChild("Underline")
        underline:SetHidden(not selected)
        underline:SetColor(color:UnpackRGBA())
    end
end

local function UpdateList(f)
    UpdateToggles(f)
    local list = UI.list
    ZO_ScrollList_Clear(list)
    local data = ZO_ScrollList_GetDataList(list)

    if f then
        local p = f.players[UI.player]
        if UI.tab == TAB_EFFECTS then
            for _, e in ipairs(DR.GetSortedEffects(f, p)) do
                data[#data + 1] = ZO_ScrollList_CreateDataEntry(DATA_BAR, {
                    name = e.name,
                    icon = e.icon,
                    value = string.format("%.1f%%", e.pct),
                    fraction = e.pct / 100,
                    color = e.debuff and C.debuff or C.buff,
                    tooltip = string.format("%s\n%s · up %s (%.1f%%)", e.name, e.debuff and "Debuff" or "Buff",
                        DR.FormatDuration(e.upMs), e.pct),
                })
            end
        else
            local abilities = DR.GetSortedAbilities(p)
            local grand = p.damage + p.healing
            local top = abilities[1] and abilities[1].total or 0
            for _, a in ipairs(abilities) do
                if a.total > 0 then
                    local isHeal = a.healing > a.damage
                    local share = grand > 0 and (a.total / grand * 100) or 0
                    local critRate = a.hits > 0 and (a.crits / a.hits * 100) or 0
                    data[#data + 1] = ZO_ScrollList_CreateDataEntry(DATA_BAR, {
                        name = a.name,
                        icon = a.icon,
                        value = string.format("%s  |c9A9A9A%.1f%%|r", DR.FormatNumber(a.total), share),
                        fraction = top > 0 and (a.total / top) or 0,
                        color = isHeal and C.heal or C["p" .. UI.player],
                        tooltip = string.format("%s\nDamage: %s · Healing: %s\nHits: %d · Crit: %.0f%%",
                            a.name, DR.FormatNumber(a.damage), DR.FormatNumber(a.healing), a.hits, critRate),
                    })
                end
            end
        end
    end

    ZO_ScrollList_Commit(list)
    UI.listEmpty:SetHidden(#data > 0)
    if UI.tab == TAB_EFFECTS then
        UI.listEmpty:SetText(f and "No effects recorded." or "No duel to show.")
    else
        UI.listEmpty:SetText(f and "No abilities recorded." or "No duel to show.")
    end
end

------------------------------------------------------------------------------------------
-- History tab
------------------------------------------------------------------------------------------
local function SetupHistoryRow(control, d)
    local f = d.fight
    local p1, p2 = f.players[1], f.players[2]
    control.fight = f
    control.index = d.index
    control:GetNamedChild("Title"):SetText(C.p1:Colorize(DR.PlayerLabel(p1)) .. "  |c6A6A6Avs|r  " .. C.p2:Colorize(DR.PlayerLabel(p2)))
    control:GetNamedChild("Sub"):SetText(string.format("%s · %s · %s",
        os.date("%d %b %H:%M", f.timestamp), DR.FormatDuration(f.endMs - f.startMs), f.zone or ""))
    local result = control:GetNamedChild("Result")
    if f.winner then
        result:SetText(DR.PlayerLabel(f.players[f.winner]))
        SetLabelColor(result, C["p" .. f.winner])
    else
        result:SetText(f.reason or "No result")
        SetLabelColor(result, C.dim)
    end
end

local function UpdateHistory()
    local list = UI.historyList
    ZO_ScrollList_Clear(list)
    local data = ZO_ScrollList_GetDataList(list)
    for i, f in ipairs(DR.sv.history) do
        data[#data + 1] = ZO_ScrollList_CreateDataEntry(DATA_HISTORY, { fight = f, index = i })
    end
    ZO_ScrollList_Commit(list)
    UI.historyEmpty:SetHidden(#data > 0)
end

local function ViewFight(f)
    UI.viewFight = f
    UI.SelectTab(TAB_OVERVIEW)
end

function UI.OnHistoryRowClicked(control, button)
    local f = control.fight
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearMenu()
        AddMenuItem("View", function() ViewFight(f) end)
        AddMenuItem("Print to chat", function() DR.PrintSummary(f) end)
        AddMenuItem("Delete", function()
            for i, h in ipairs(DR.sv.history) do
                if h == f then table.remove(DR.sv.history, i) break end
            end
            if UI.viewFight == f then UI.viewFight = nil end
            UI.Refresh()
        end)
        ShowMenu(control)
    else
        ViewFight(f)
    end
end

------------------------------------------------------------------------------------------
-- Refresh / tabs
------------------------------------------------------------------------------------------
function UI.Refresh()
    if not UI.window or UI.window:IsHidden() then return end
    local f = UI.GetFight()
    UpdateHeader(f)
    if UI.tab == TAB_OVERVIEW then
        UpdateOverview(f)
    elseif UI.tab == TAB_HISTORY then
        UpdateHistory()
    else
        UpdateList(f)
    end
    UI.currentButton:SetHidden(UI.viewFight == nil)
    UI.resetButton:SetEnabled(UI.viewFight == nil and DR.Tracker.current ~= nil)
end

function UI.SelectTab(index)
    UI.tab = index
    for i, b in ipairs(UI.tabs) do
        local selected = i == index
        b:GetNamedChild("Underline"):SetHidden(not selected)
        b:SetNormalFontColor((selected and C.white or C.dim):UnpackRGBA())
    end
    UI.overview:SetHidden(index ~= TAB_OVERVIEW)
    UI.listPanel:SetHidden(index ~= TAB_EFFECTS and index ~= TAB_ABILITIES)
    UI.historyPanel:SetHidden(index ~= TAB_HISTORY)
    UI.Refresh()
end

local function OnTick()
    local f = UI.GetFight()
    if f and not f.endMs then UI.Refresh() end
end

------------------------------------------------------------------------------------------
-- Show / hide / position
------------------------------------------------------------------------------------------
function UI.Show(takeFocus)
    UI.window:SetHidden(false)
    if takeFocus and not IsGameCameraUIModeActive() then
        SetGameCameraUIMode(true)
    end
    EM:RegisterForUpdate(UPDATE_NAME, 500, OnTick)
    UI.Refresh()
end

function UI.Hide()
    UI.window:SetHidden(true)
    EM:UnregisterForUpdate(UPDATE_NAME)
    ZO_Tooltips_HideTextTooltip()
end

function UI.Toggle()
    if UI.window:IsHidden() then UI.Show(true) else UI.Hide() end
end

function UI.SavePosition()
    DR.sv.window = { left = UI.window:GetLeft(), top = UI.window:GetTop() }
end

function UI.ApplySettings()
    local w = UI.window
    w:SetScale(DR.sv.scale or 1)
    w:SetMovable(not DR.sv.locked)
    w:ClearAnchors()
    local pos = DR.sv.window
    if pos and pos.left and pos.top then
        w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.left, pos.top)
    else
        w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
end

function UI.ResetPosition()
    DR.sv.window = nil
    UI.ApplySettings()
end

------------------------------------------------------------------------------------------
-- Tracker callbacks
------------------------------------------------------------------------------------------
function UI.OnFightStarted()
    UI.viewFight = nil
    if DR.sv.autoShowOnStart and UI.window:IsHidden() then
        UI.Show(false)
    end
    UI.Refresh()
end

function UI.OnFightFinished(f)
    if DR.sv.printOnEnd then DR.PrintSummary(f) end
    if DR.sv.autoShowOnEnd and UI.window:IsHidden() then
        UI.Show(false)
    end
    UI.Refresh()
end

function UI.OnFightReset()
    UI.viewFight = nil
    UI.Refresh()
end

------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------
function UI.Init()
    local w = DuelResultsWindow
    UI.window = w
    w:GetNamedChild("Version"):SetText("v" .. DR.version)

    local header = w:GetNamedChild("Header")
    UI.p1Name = header:GetNamedChild("P1Name")
    UI.p1Sub = header:GetNamedChild("P1Sub")
    UI.p2Name = header:GetNamedChild("P2Name")
    UI.p2Sub = header:GetNamedChild("P2Sub")
    UI.status = header:GetNamedChild("Status")

    local tabs = w:GetNamedChild("Tabs")
    UI.tabs = {}
    for i, name in ipairs(TAB_NAMES) do
        local b = tabs:GetNamedChild("Tab" .. i)
        b:SetText(name)
        b:SetHandler("OnClicked", function() UI.SelectTab(i) end)
        UI.tabs[i] = b
    end

    local content = w:GetNamedChild("Content")
    UI.overview = content:GetNamedChild("Overview")
    UI.overviewEmpty = UI.overview:GetNamedChild("Empty")
    UI.listPanel = content:GetNamedChild("ListPanel")
    UI.list = UI.listPanel:GetNamedChild("List")
    UI.listEmpty = UI.listPanel:GetNamedChild("Empty")
    UI.historyPanel = content:GetNamedChild("HistoryPanel")
    UI.historyList = UI.historyPanel:GetNamedChild("List")
    UI.historyEmpty = UI.historyPanel:GetNamedChild("Empty")
    UI.historyEmpty:SetText("No duels recorded yet.")
    UI.historyPanel:GetNamedChild("Hint"):SetText("Click a duel to view it · right-click for more")

    UI.toggles = { UI.listPanel:GetNamedChild("P1Toggle"), UI.listPanel:GetNamedChild("P2Toggle") }
    for i, b in ipairs(UI.toggles) do
        b:SetHandler("OnClicked", function()
            UI.player = i
            UI.Refresh()
        end)
    end

    ZO_ScrollList_AddDataType(UI.list, DATA_BAR, "DuelResults_BarRow", 30, SetupBarRow)
    ZO_ScrollList_AddDataType(UI.historyList, DATA_HISTORY, "DuelResults_HistoryRow", 46, SetupHistoryRow)

    BuildStatRows()

    UI.resetButton = w:GetNamedChild("Reset")
    UI.resetButton:SetText("Reset")
    UI.resetButton:SetHandler("OnClicked", function() DR.Tracker:Reset() end)

    local printButton = w:GetNamedChild("Print")
    printButton:SetText("Print to Chat")
    printButton:SetHandler("OnClicked", function() DR.PrintSummary(UI.GetFight()) end)

    UI.currentButton = w:GetNamedChild("Current")
    UI.currentButton:SetText("Current")
    UI.currentButton:SetHandler("OnClicked", function()
        UI.viewFight = nil
        UI.Refresh()
    end)

    local settingsButton = w:GetNamedChild("Settings")
    settingsButton:SetText("Settings")
    settingsButton:SetHandler("OnClicked", function()
        if DR.Settings.panel and LibAddonMenu2 then
            UI.Hide()
            LibAddonMenu2:OpenToPanel(DR.Settings.panel)
        end
    end)
    UI.settingsButton = settingsButton

    UI.ApplySettings()
    UI.SelectTab(TAB_OVERVIEW)
end
