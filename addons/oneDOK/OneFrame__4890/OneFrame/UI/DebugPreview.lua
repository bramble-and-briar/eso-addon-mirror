local A = OneFrame
local D = { pools = {} }
A.DebugPreview = D

function D:Member(index, large)
    local role = index == 1 and LFG_ROLE_TANK or index == 2 and LFG_ROLE_HEAL or LFG_ROLE_DPS
    if large and index == 5 then role = LFG_ROLE_TANK end
    if large and index == 6 then role = LFG_ROLE_HEAL end
    local names = {"Aether Guard", "Morning Light", "Ember Blade", "Silver Arrow",
        "Iron Ward", "Moon Blossom", "Storm Caller", "Frost Raven",
        "Sun Spear", "Shadow Step", "Wild Flame", "Star Weaver"}
    local maxHealth = role == LFG_ROLE_TANK and 46000 or 26000
    return { exists = true, online = true, dead = false, leader = index == 1,
        name = names[index], account = "@Preview" .. index, role = role,
        class = ({1, 6, 2, 3, 4, 5, 117})[(index - 1) % 7 + 1],
        champion = true, cp = 900 + index * 75, level = 50,
        health = math.floor(maxHealth * (1 - (index % 4) * .16)), maxHealth = maxHealth,
        dps = role == LFG_ROLE_DPS and 65000 + index * 2300 or 4200 + index * 500,
        hps = role == LFG_ROLE_HEAL and 22000 + index * 700 or 800 + index * 100,
        ultimate = (index * 73) % 501, shield = index % 3 == 0 and .25 or 0 }
end

function D:CreateRoot()
    self.root = WINDOW_MANAGER:CreateTopLevelWindow(A.name .. "DebugPreview")
    self.root:SetDimensions(520, 440)
    self.root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 70, 220)
    self.root:SetDrawTier(DT_HIGH)
    self.root:SetMovable(true)
    self.root:SetClampedToScreen(true)
    self.root:SetMouseEnabled(true)
    self.root:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then control:StartMoving() end
    end)
    self.root:SetHandler("OnMouseUp", function(control) control:StopMovingOrResizing() end)
    self.title = WINDOW_MANAGER:CreateControl(nil, self.root, CT_LABEL)
    self.title:SetFont("ZoFontGameBold")
    self.title:SetAnchor(BOTTOMLEFT, self.root, TOPLEFT, 0, -8)
    self.total = WINDOW_MANAGER:CreateControl(nil, self.root, CT_LABEL)
    self.total:SetFont("$(BOLD_FONT)|16|soft-shadow-thin")
end

function D:CreateFrame(index, large)
    local style = large and "ZO_RaidUnitFrame" or "ZO_GroupUnitFrame"
    -- Separate native objects, never registered with UNIT_FRAMES or group data.
    local tag = "oneframePreview" .. (large and "Large" or "Small") .. index
    local frame = ZO_UnitFrameObject:New(tag, ZO_Anchor:New(TOPLEFT, self.root, TOPLEFT),
        ZO_UNIT_FRAME_BAR_TEXT_MODE_HIDDEN, style)
    frame.frame:SetParent(self.root)
    frame.frame:SetMouseEnabled(false)
    frame.preview = self:Member(index, large)
    frame.previewUI = A.PlayerInfo:Create(frame)
    local bar = frame.healthBar.barControls[1]
    frame.previewUI.shield = WINDOW_MANAGER:CreateControl(nil, frame.frame, CT_TEXTURE)
    frame.previewUI.shield:SetMouseEnabled(false)
    frame.previewUI.shield:SetDrawLayer(DL_OVERLAY)
    frame.previewUI.shield:SetAnchor(TOPLEFT, bar, TOPLEFT)
    return frame
end

function D:Refresh()
    local mode = A.sv.debugMode
    local visible = A.debugToolsEnabled and A.active and (mode == "small" or mode == "large")
    if not visible then
        if self.root then self.root:SetHidden(true) end
        return
    end
    if not self.root then self:CreateRoot() end
    self.root:SetHidden(false)
    local large, sum = mode == "large", 0
    local count = large and 12 or 4
    local rows = large and (IsInGamepadPreferredMode() and 6 or 4) or count
    local pool = self.pools[mode] or {}
    self.pools[mode] = pool
    for _, frames in pairs(self.pools) do
        for _, frame in ipairs(frames) do frame.frame:SetHidden(true) end
    end
    local bottom
    for i = 1, count do
        local frame = pool[i] or self:CreateFrame(i, large)
        pool[i] = frame
        frame:ApplyVisualStyle()
        local unit, data = frame.preview, frame.previewUI
        local control, bar = frame.frame, frame.healthBar.barControls[1]
        control:ClearAnchors()
        local row, column = (i - 1) % rows, math.floor((i - 1) / rows)
        control:SetAnchor(TOPLEFT, self.root, TOPLEFT,
            large and column * (control:GetWidth() + 8) or 0,
            (large and row or i - 1) * (control:GetHeight() + 8))
        control:SetHidden(false)
        control:SetAlpha(1)
        for _, component in ipairs(frame.fadeComponents) do component:SetAlpha(1) end
        frame.nameLabel:SetText(unit.name)
        if frame.levelLabel then frame.levelLabel:SetHidden(true) end
        if frame.statusLabel then frame.statusLabel:SetHidden(true) end
        if frame.assignmentIcon then
            frame.assignmentIcon:SetTexture(ZO_GetRoleIcon(unit.role))
            frame.assignmentIcon:SetHidden(false)
        end
        frame.healthBar:Update(COMBAT_MECHANIC_FLAGS_HEALTH, unit.health, unit.maxHealth, true)
        bar:SetAlpha(1)
        local gradient = ZO_POWER_BAR_GRADIENT_COLORS[A.roleResources[unit.role]]
        if A.sv.customColors[unit.role] then
            local color = ZO_ColorDef:New(unpack(A.sv.colors[unit.role]))
            gradient = {color, color}
        end
        frame.healthBar:SetColor(COMBAT_MECHANIC_FLAGS_HEALTH, gradient)
        A.PlayerInfo:Update(frame, data)
        A.Frames:Leader(frame, data)
        data.shield:SetDimensions(bar:GetWidth() * unit.shield, bar:GetHeight())
        local color = A.sv.shieldColor
        data.shield:SetColor(color[1], color[2], color[3], A.sv.shieldOpacity)
        data.shield:SetHidden(not A.sv.shield or unit.shield == 0)
        sum = sum + unit.dps
        if i == rows then
            bottom = control
            self.root:SetDimensions((control:GetWidth() + 8) * math.ceil(count / rows),
                (control:GetHeight() + 8) * rows + 24)
        end
    end
    self.title:SetText(GetString(SI_ONEFRAME_DEBUG) .. ": " .. GetString(large and SI_ONEFRAME_DEBUG_LARGE or SI_ONEFRAME_DEBUG_SMALL))
    self.total:ClearAnchors()
    self.total:SetAnchor(TOPLEFT, bottom, BOTTOMLEFT, 0, 4)
    self.total:SetText(GetString(SI_ONEFRAME_GROUP_DPS) .. ": " .. A.PlayerInfo:Format(sum))
    self.total:SetHidden(not A.sv.groupDps)
end
