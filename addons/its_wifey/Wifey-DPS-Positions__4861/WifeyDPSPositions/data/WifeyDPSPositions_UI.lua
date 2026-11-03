-- WifeyDPSPositions_UI.lua - redesigned host assignment console
WifeyDPSPositions = WifeyDPSPositions or {}
local DDP = WifeyDPSPositions
DDP.UI = DDP.UI or {}
local UI = DDP.UI

local ASSIGNMENT_FONT = "$(MEDIUM_FONT)|18"

local C = {
    panel = {0.92, 0.92, 0.92, 0.88},
    edge = {0.10, 0.10, 0.10, 0.95},
    text = {0.08, 0.08, 0.08, 1},
    muted = {0.30, 0.30, 0.30, 1},
    red = {0.70, 0.05, 0.05, 1},
    redSoft = {0.55, 0.08, 0.08, 1},
    green = {0.08, 0.45, 0.16, 1},
    white = {1, 1, 1, 1},
}

local function setColor(control, color)
    control:SetColor(color[1], color[2], color[3], color[4])
end

local function makeLabel(parent, font, text)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    c:SetFont(font)
    c:SetText(text or "")
    setColor(c, C.text)
    return c
end

local function makeButton(parent, text, width, height, callback)
    local b = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    b:SetDimensions(width, height)
    b:SetMouseEnabled(true)
    b:SetClickSound("Click")

    local bg = WINDOW_MANAGER:CreateControl(nil, b, CT_BACKDROP)
    bg:SetAnchorFill(b)
    bg:SetCenterColor(0.12, 0.12, 0.12, 0.94)
    bg:SetEdgeColor(0.04, 0.04, 0.04, 1)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local label = makeLabel(b, "ZoFontGameBold", text)
    label:SetAnchorFill(b)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    setColor(label, C.white)
    b.label, b.bg = label, bg

    b:SetHandler("OnMouseEnter", function()
        bg:SetCenterColor(C.redSoft[1], C.redSoft[2], C.redSoft[3], 0.98)
    end)
    b:SetHandler("OnMouseExit", function()
        bg:SetCenterColor(0.12, 0.12, 0.12, 0.94)
    end)
    b:SetHandler("OnClicked", callback)
    return b
end

function UI:MarkDirty()
    self.sentClean = false
    self:UpdateSentState()
end

function UI:UpdateSentState()
    if not self.sentLabel then return end
    if self.sentClean then
        self.sentLabel:SetText("Sent  ✓")
        setColor(self.sentLabel, C.green)
    else
        self.sentLabel:SetText("Not sent")
        setColor(self.sentLabel, C.red)
    end
end

function UI:GetContext()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local zoneData = DDP.positions[zoneId]
    return zoneId, zoneData
end

function UI:Create()
    if self.window then return end
    local wm = WINDOW_MANAGER

    self.window = wm:CreateTopLevelWindow("WifeyDPSPositionsPanel")
    self.window:SetDimensions(760, 315)
    self.window:SetHidden(true)
    self.window:SetMovable(true)
    self.window:SetMouseEnabled(true)
    self.window:SetClampedToScreen(true)

    local pos = (DDP.SV and DDP.SV.panelPosition) or {x = 500, y = 300}
    self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    self.window:SetHandler("OnMoveStop", function()
        if DDP.SV then
            DDP.SV.panelPosition = {x = self.window:GetLeft(), y = self.window:GetTop()}
        end
    end)

    local bg = wm:CreateControl(nil, self.window, CT_BACKDROP)
    bg:SetAnchorFill(self.window)
    bg:SetCenterColor(C.panel[1], C.panel[2], C.panel[3], C.panel[4])
    bg:SetEdgeColor(C.edge[1], C.edge[2], C.edge[3], C.edge[4])
    bg:SetEdgeTexture(nil, 2, 2, 2)

    self.title = makeLabel(self.window, "$(BOLD_FONT)|18", "WIFEY DPS POSITIONS")
    self.title:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 12)
    setColor(self.title, C.text)

    self.zoneLabel = makeLabel(self.window, "ZoFontGame", "")
    self.zoneLabel:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -18, 16)
    self.zoneLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    setColor(self.zoneLabel, C.muted)

    local line = wm:CreateControl(nil, self.window, CT_TEXTURE)
    line:SetDimensions(724, 2)
    line:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 43)
    line:SetColor(C.red[1], C.red[2], C.red[3], 1)
    line:SetTexture("EsoUI/Art/Miscellaneous/horizontalDivider.dds")

    self.tabs = wm:CreateControl(nil, self.window, CT_CONTROL)
    self.tabs:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 53)
    self.tabs:SetDimensions(724, 36)

    self.assignmentArea = wm:CreateControl(nil, self.window, CT_CONTROL)
    self.assignmentArea:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 100)
    self.assignmentArea:SetDimensions(555, 150)

    self.actionArea = wm:CreateControl(nil, self.window, CT_CONTROL)
    self.actionArea:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -18, 100)
    self.actionArea:SetDimensions(150, 190)

    self.modeLabel = makeLabel(self.window, "ZoFontGameSmall", "")
    self.modeLabel:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, 18, -15)
    setColor(self.modeLabel, C.red)

    self.dragHint = makeLabel(self.window, "ZoFontGameSmall", "Drag to move")
    self.dragHint:SetAnchor(BOTTOM, self.window, BOTTOM, 0, -15)
    self.dragHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    setColor(self.dragHint, C.muted)

    self.sentLabel = makeLabel(self.window, "ZoFontGameBold", "Not sent")
    self.sentLabel:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMRIGHT, -18, -15)
    self.sentLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self:UpdateSentState()
end

function UI:ClearControls(list)
    if not list then return end
    for _, c in ipairs(list) do if c then c:SetHidden(true) end end
    ZO_ClearNumericallyIndexedTable(list)
end

function UI:SelectMechanic(mechKey)
    local zoneId, zoneData = self:GetContext()
    if not zoneData or not zoneData.mechanics[mechKey] then return end
    self.currentMechanic = mechKey
    DDP.lastMechanicShown = mechKey
    DDP.AssignToPositions(zoneId, mechKey, zoneData.mechanics[mechKey])
    self.swapFirst = nil
    self.editMode = nil
    self:MarkDirty()
    self:Refresh()
end

function UI:BuildTabs(zoneData)
    self.tabControls = self.tabControls or {}
    self:ClearControls(self.tabControls)
    local count = #(zoneData.mechOrder or {})
    if count == 0 then return end
    local gap = 6
    local width = math.floor((724 - ((count - 1) * gap)) / count)
    width = math.min(width, 138)
    local x = 0
    for _, mech in ipairs(zoneData.mechOrder) do
        -- Capture a per-button copy. ESO's Lua closures otherwise can share the
        -- loop variable, making some mechanic tabs select the wrong/final tab.
        local mechKey = mech
        local b = makeButton(self.tabs, mechKey, width, 28, function() self:SelectMechanic(mechKey) end)
        b:SetAnchor(TOPLEFT, self.tabs, TOPLEFT, x, 0)
        if mechKey == self.currentMechanic then
            b.bg:SetCenterColor(C.red[1], C.red[2], C.red[3], 0.98)
        end
        table.insert(self.tabControls, b)
        x = x + width + gap
    end
end

function UI:OnAssignmentClicked(index)
    local zoneId, zoneData = self:GetContext()
    local mech = self.currentMechanic
    if zoneId == 1548 and mech == "HM PORTALS" then return end
    local objs = DDP.savedAssignments and DDP.savedAssignments[zoneId] and DDP.savedAssignments[zoneId][mech]
    if not objs or not objs[index] then return end


    if self.editMode == "swap" then
        if not self.swapFirst then
            self.swapFirst = index
            self.modeLabel:SetText("SWAP: choose the second assignment")
            self:RefreshAssignments()
        elseif self.swapFirst == index then
            self.swapFirst = nil
            self.modeLabel:SetText("SWAP: choose the first assignment")
            self:RefreshAssignments()
        else
            DDP.SwapAssignments(zoneId, mech, self.swapFirst, index)
            self.swapFirst = nil
            self.editMode = nil
            self.modeLabel:SetText("")
            self:MarkDirty()
            self:RefreshAssignments()
        end
    end
end

function UI:RefreshAssignments()
    self.assignmentControls = self.assignmentControls or {}
    self:ClearControls(self.assignmentControls)
    local zoneId, zoneData = self:GetContext()
    if not zoneData or not self.currentMechanic then return end
    local objs = DDP.savedAssignments and DDP.savedAssignments[zoneId] and DDP.savedAssignments[zoneId][self.currentMechanic]
    if not objs then return end

    local colW, rowH = 136, 64
    for i, obj in ipairs(objs) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local cell = WINDOW_MANAGER:CreateControl(nil, self.assignmentArea, CT_BUTTON)
        cell:SetDimensions(colW - 8, rowH - 8)
        cell:SetAnchor(TOPLEFT, self.assignmentArea, TOPLEFT, col * colW, row * rowH)
        cell:SetMouseEnabled(true)
        cell:SetHandler("OnClicked", function() self:OnAssignmentClicked(i) end)

        local pos = makeLabel(cell, "ZoFontGameBold", tostring(obj.position or "?"))
        pos:SetAnchor(TOPLEFT, cell, TOPLEFT, 0, 3)
        if obj.name == "@Missing" then
            setColor(pos, C.red)
        else
            setColor(pos, C.green)
        end

        local displayName = DDP.PrintName and DDP.PrintName(obj.name or "@Missing") or (obj.name or "@Missing")
        local name = makeLabel(cell, ASSIGNMENT_FONT, displayName)
        name:SetAnchor(TOPLEFT, pos, BOTTOMLEFT, 0, 4)
        name:SetDimensions(colW - 12, 28)
        name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        if obj.name == "@Missing" then setColor(name, C.muted) else setColor(name, C.text) end

        if self.editMode == "swap" and self.swapFirst == i then
            setColor(pos, C.green)
        end

        table.insert(self.assignmentControls, cell)
        table.insert(self.assignmentControls, pos)
        table.insert(self.assignmentControls, name)
    end
end

function UI:SetMode(mode)
    self.swapFirst = nil
    if self.editMode == mode then
        self.editMode = nil
        self.modeLabel:SetText("")
    else
        self.editMode = mode
        if mode == "swap" then self.modeLabel:SetText("SWAP: choose the first assignment") end
    end
    self:RefreshAssignments()
end

function UI:BuildActions()
    self.actionControls = self.actionControls or {}
    self:ClearControls(self.actionControls)
    local zoneId, zoneData = self:GetContext()
    local mech = self.currentMechanic
    if not zoneData or not mech then return end
    local positions = zoneData.mechanics[mech]

    local actions
    if zoneId == 1548 and mech == "HM PORTALS" then
        actions = {
            {"SEND", function() if DDP.SendAssignments(zoneId, mech) then self.sentClean = true; self:UpdateSentState() end end},
            {"RESEND", function() DDP.SendAssignments(zoneId, mech) end},
        }
    else
        actions = {
            {"REROLL", function() DDP.ShuffleAllAssignments(zoneId, mech, positions, false); self:MarkDirty(); self:RefreshAssignments() end},
            {"SWAP", function() self:SetMode("swap") end},
            {"FILL EMPTY", function() DDP.FillEmptyAssignments(zoneId, mech, positions); self:MarkDirty(); self:RefreshAssignments() end},
            {"RESET", function() DDP.ResetMechanic(zoneId, mech, positions); self:MarkDirty(); self:RefreshAssignments() end},
            {"SEND", function() if DDP.SendAssignments(zoneId, mech) then self.sentClean = true; self:UpdateSentState() end end},
            {"RESEND", function() DDP.SendAssignments(zoneId, mech) end},
        }
    end
    local y = 0
    for _, a in ipairs(actions) do
        local action = a
        local b = makeButton(self.actionArea, action[1], 150, 23, action[2])
        b:SetAnchor(TOPLEFT, self.actionArea, TOPLEFT, 0, y)
        if action[1] == "SEND" then b.bg:SetCenterColor(C.red[1], C.red[2], C.red[3], 0.98) end
        table.insert(self.actionControls, b)
        y = y + 26
    end
end

function UI:Refresh()
    if not self.window then self:Create() end
    local zoneId, zoneData = self:GetContext()
    if not zoneData then return end
    self.zoneLabel:SetText(zo_strformat("<<C:1>>", GetZoneNameById(zoneId)))

    local valid = self.currentMechanic and zoneData.mechanics[self.currentMechanic]
    if not valid then
        self.currentMechanic = DDP.lastMechanicShown
        if not self.currentMechanic or not zoneData.mechanics[self.currentMechanic] then
            self.currentMechanic = zoneData.mechOrder and zoneData.mechOrder[1]
        end
    end
    if self.currentMechanic then
        DDP.AssignToPositions(zoneId, self.currentMechanic, zoneData.mechanics[self.currentMechanic])
    end
    self:BuildTabs(zoneData)
    self:RefreshAssignments()
    self:BuildActions()
end

-- Compatibility hooks used by existing core/group-change code.
function UI:PopulateMechanicList() self:Refresh() end
function UI:ClearButtons()
    self:ClearControls(self.tabControls)
    self:ClearControls(self.assignmentControls)
    self:ClearControls(self.actionControls)
end
function UI:PopulateFreeAssignments() end

function UI:Toggle()
    if self.panelOpen then
        self.panelOpen = false
        if self.hudFragment then
            if HUD_SCENE then HUD_SCENE:RemoveFragment(self.hudFragment) end
            if HUD_UI_SCENE then HUD_UI_SCENE:RemoveFragment(self.hudFragment) end
        end
        if self.window then self.window:SetHidden(true) end
        SCENE_MANAGER:SetInUIMode(false)
        return
    end

    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if not DDP.positions[zoneId] then
        DDP.msg("Panel is only available inside a supported trial.")
        return
    end
    if not self.window then self:Create() end
    self.panelOpen = true
    self:Refresh()
    SCENE_MANAGER:SetInUIMode(true)
    if self.hudFragment then
        if HUD_SCENE then HUD_SCENE:AddFragment(self.hudFragment) end
        if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(self.hudFragment) end
    else
        self.window:SetHidden(false)
    end
end

SLASH_COMMANDS["/wdp"] = function() UI:Toggle() end
SLASH_COMMANDS["/wifeydpspositions"] = SLASH_COMMANDS["/wdp"]
_G.WifeyDPSPanel = UI
