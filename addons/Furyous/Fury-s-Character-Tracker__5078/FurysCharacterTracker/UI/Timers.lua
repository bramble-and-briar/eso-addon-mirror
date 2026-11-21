-- Research timers (/fct timers): every research slot on the account being viewed, one line each.
-- Finished and idle slots come first (those need you), then running research, soonest first.
local CT = FuryCT
local U = CT.Util
local R = CT.Research
local Timers = {}
CT.Timers = Timers

local ROW_TYPE = 1
local UPDATE_MS = 30000
local GOLD = { 0.83, 0.69, 0.22 }
local PARCH = { 0.89, 0.83, 0.71 }
local DIM = { 0.45, 0.40, 0.33 }

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
    SCENE_MANAGER:RegisterTopLevel(FuryCTTimers, false)
    self.list = FuryCTTimersList
    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FuryCT_TimerRow", 26, SetupRow)

    local header = FuryCTTimersHeader
    for child, text in pairs({ Name = "Character", Craft = "Craft", Item = "Item", Trait = "Trait", Left = "Time left", Ends = "Finishes" }) do
        local label = header:GetNamedChild(child)
        label:SetFont("ZoFontGameBold")
        Paint(label, text, GOLD)
    end
    FuryCTTimersLegend:SetText("|cD4AF37Gold|r needs you (done or idle)  ·  light researching  ·  updates every 30 seconds  ·  /fct timers")

    local pos = CT.sv.timersWindow
    if pos then
        FuryCTTimers:ClearAnchors()
        FuryCTTimers:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Timers.SavePosition()
    CT.sv.timersWindow = { x = FuryCTTimers:GetLeft(), y = FuryCTTimers:GetTop() }
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

    FuryCTTimersSubtitle:SetText(CT.ViewLabel())
    local summary
    if #rows == 0 then
        summary = "Nothing to show: every character has every trait, or none has been read with version 1.1.0 or later yet."
    else
        summary = string.format("%d researching  ·  %d slot%s free", running, waiting, waiting == 1 and "" or "s")
        if not CT.IsHome() then summary = summary .. "  ·  as saved at that account's last logout" end
    end
    FuryCTTimersSummary:SetText(summary)
end

function Timers:Show()
    self:Build()
    self:Refresh()
    SCENE_MANAGER:ShowTopLevel(FuryCTTimers)
    CT.Raise(FuryCTTimers)
    EVENT_MANAGER:RegisterForUpdate(CT.name .. "Timers", UPDATE_MS, function()
        -- Closed some other way (Esc)? Stop counting.
        if FuryCTTimers:IsHidden() then EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Timers") else self:Refresh() end
    end)
end

function Timers:Hide()
    EVENT_MANAGER:UnregisterForUpdate(CT.name .. "Timers")
    SCENE_MANAGER:HideTopLevel(FuryCTTimers)
end

function Timers:Toggle()
    if FuryCTTimers:IsHidden() then self:Show() else self:Hide() end
end

function Timers:RefreshIfShown()
    if FuryCTTimers and not FuryCTTimers:IsHidden() then self:Refresh() end
end
