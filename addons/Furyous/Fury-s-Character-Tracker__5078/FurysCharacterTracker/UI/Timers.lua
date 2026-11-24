-- Research timers (/fct timers): every research slot on the account being viewed, one line each.
-- Finished and idle slots come first (those need you), then running research, soonest first.
local CT = FurysCharacterTracker
local U = CT.Util
local R = CT.Research
local Timers = {}
CT.Timers = Timers

local ROW_TYPE = 1
local UPDATE_MS = 30000
local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local GOLD = T.RGB.WARN               -- needs you: done or idle
local PARCH = T.RGB.TEXT
local DIM = T.RGB.MUTED

local function Paint(label, text, rgb)
    label:SetText(text or "")
    label:SetColor(rgb[1], rgb[2], rgb[3], 1)
end

-- "Sat Nov 21, 03:15 PM"
local function When(timestamp)
    return os.date("%a %b %d, %I:%M %p", timestamp)
end

local function SetupRow(control, row)
    local name, craft, item, trait = control:GetNamedChild("Name"), control:GetNamedChild("Craft"),
                                     control:GetNamedChild("Item"), control:GetNamedChild("Trait")
    local left, ends = control:GetNamedChild("Left"), control:GetNamedChild("Ends")
    control:GetNamedChild("Stripe"):SetHidden(not row.stripe)
    Paint(name, row.name, PARCH)
    Paint(craft, row.craftName, PARCH)
    if row.kind == "timer" then
        Paint(item, row.item, PARCH)
        Paint(trait, row.trait, PARCH)
        Paint(left, R.Duration(row.endsAt - GetTimeStamp()), PARCH)
        Paint(ends, When(row.endsAt), DIM)
    elseif row.kind == "done" then
        Paint(item, row.item, GOLD)
        Paint(trait, row.trait, GOLD)
        Paint(left, "Done", GOLD)
        Paint(ends, "slot free: start more", GOLD)
    else -- idle
        Paint(item, row.count == 1 and "1 slot free" or (row.count .. " slots free"), GOLD)
        Paint(trait, "", GOLD)
        Paint(left, "Idle", GOLD)
        Paint(ends, "nothing researching", GOLD)
    end
end

function Timers:Build()
    if self.list then return end
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Timers, false)
    self.list = FurysCharacterTracker_TimersList
    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FurysCharacterTracker_TimerRow", 26, SetupRow)

    local header = FurysCharacterTracker_TimersHeader
    for child, text in pairs({ Name = "Character", Craft = "Craft", Item = "Item", Trait = "Trait", Left = "Time left", Ends = "Finishes" }) do
        local label = header:GetNamedChild(child)
        label:SetFont(T.FONT_HEADER)
        Paint(label, text, T.RGB.BLUE)
    end
    FurysCharacterTracker_TimersLegend:SetText("|cFFC857Amber|r needs you (done or idle)  ·  white researching  ·  updates every 30 seconds  ·  /fct timers")

    local pos = CT.sv.timersWindow
    if pos then
        FurysCharacterTracker_Timers:ClearAnchors()
        FurysCharacterTracker_Timers:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Timers.SavePosition()
    CT.sv.timersWindow = { x = FurysCharacterTracker_Timers:GetLeft(), y = FurysCharacterTracker_Timers:GetTop() }
end

function Timers:Refresh()
    if not self.list then return end
    local rows = R.Rows(CT.Data(), GetTimeStamp())
    ZO_ScrollList_Clear(self.list)
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    local running, waiting = 0, 0
    for i, row in ipairs(rows) do
        row.stripe = (i % 2 == 0)
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, row)
        if row.kind == "timer" then running = running + 1 else waiting = waiting + (row.count or 1) end
    end
    ZO_ScrollList_Commit(self.list)

    FurysCharacterTracker_TimersSubtitle:SetText(CT.ViewLabel())
    local summary
    if #rows == 0 then
        summary = "Nothing to show: every character has every trait, or none has been read with version 1.1.0 or later yet."
    else
        summary = string.format("%d researching  ·  %d slot%s free", running, waiting, waiting == 1 and "" or "s")
        if not CT.IsHome() then summary = summary .. "  ·  as saved at that account's last logout" end
    end
    FurysCharacterTracker_TimersSummary:SetText(summary)
end

function Timers:Show()
    self:Build()
    self:Refresh()
    SCENE_MANAGER:ShowTopLevel(FurysCharacterTracker_Timers)
    CT.Raise(FurysCharacterTracker_Timers)
    EVENT_MANAGER:RegisterForUpdate(CT.name .. "Timers", UPDATE_MS, function()
        -- Closed some other way (Esc)? Stop counting.
        if FurysCharacterTracker_Timers:IsHidden() then EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Timers") else self:Refresh() end
    end)
end

function Timers:Hide()
    EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Timers")
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Timers)
end

function Timers:Toggle()
    if FurysCharacterTracker_Timers:IsHidden() then self:Show() else self:Hide() end
end

function Timers:RefreshIfShown()
    if FurysCharacterTracker_Timers and not FurysCharacterTracker_Timers:IsHidden() then self:Refresh() end
end
