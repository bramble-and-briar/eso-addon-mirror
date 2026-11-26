-- Research timers (/fct timers): every research slot on the account being viewed, one line each.
-- Finished and idle slots come first (those need you), then running research, soonest first.
local CT = FurysCharacterTracker
local Timers = {}
CT.Timers = Timers

local ROW_TYPE = 1
local UPDATE_MS = 30000
local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local AMBER = T.RGB.WARN              -- needs you: done or idle
local TEXT = T.RGB.TEXT
local DIM = T.RGB.MUTED

local function Paint(label, text, rgb)
    label:SetText(text or "")
    label:SetColor(rgb[1], rgb[2], rgb[3], 1)
end

local function SetupRow(control, row)
    local text = CT.Pages.TimerRow(row, GetTimeStamp())
    local rgb = text.waiting and AMBER or TEXT
    control:GetNamedChild("Stripe"):SetHidden(not row.stripe)
    Paint(control:GetNamedChild("Name"), text.name, TEXT)
    Paint(control:GetNamedChild("Craft"), text.craft, TEXT)
    Paint(control:GetNamedChild("Item"), text.item, rgb)
    Paint(control:GetNamedChild("Trait"), text.trait, rgb)
    Paint(control:GetNamedChild("Left"), text.left, rgb)
    Paint(control:GetNamedChild("Ends"), text.ends, text.waiting and AMBER or DIM)
end

function Timers:Build()
    if self.list then return end
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Timers, false)
    self.list = FurysCharacterTracker_TimersList
    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FurysCharacterTracker_TimerRow", 26, SetupRow)

    local header = FurysCharacterTracker_TimersHeader
    local titles = { { "Name", "Character" }, { "Craft", "Craft" }, { "Item", "Item" }, { "Trait", "Trait" }, { "Left", "Time left" }, { "Ends", "Finishes" } }
    for _, title in ipairs(titles) do
        local label = header:GetNamedChild(title[1])
        label:SetFont(T.FONT_HEADER)
        Paint(label, title[2], T.RGB.BLUE)
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
    local rows = CT.Research.Rows(CT.Data(), GetTimeStamp())
    ZO_ScrollList_Clear(self.list)
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    for i, row in ipairs(rows) do
        row.stripe = (i % 2 == 0)
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, row)
    end
    ZO_ScrollList_Commit(self.list)
    FurysCharacterTracker_TimersSubtitle:SetText(CT.ViewLabel())
    FurysCharacterTracker_TimersSummary:SetText(CT.Pages.TimersSummary(rows))
    FurysCharacterTracker_TimersHeader:SetHidden(#rows == 0)
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
    if not FurysCharacterTracker_Timers:IsHidden() then self:Refresh() end
end
