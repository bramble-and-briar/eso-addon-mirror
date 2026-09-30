local A = OneFrame
local F = { cache = {}, coloring = false }
A.Frames = F
function F:Leader(frame, data)
    if self.leaderUpdating then return end
    local leader = A.active and IsUnitOnline(frame.unitTag) and IsUnitGroupLeader(frame.unitTag)
        and DoesUnitExist(frame.unitTag) and UNIT_FRAMES:GetFrame(frame.unitTag) == frame
    local showBorder = leader and frame.style == "ZO_RaidUnitFrame"
    if showBorder and not data.leaderBorder then
        data.leaderBorder = {}
        for i = 1, 4 do
            local edge = WINDOW_MANAGER:CreateControl(frame.frame:GetName() .. "OneFrameLeader" .. i, frame.frame, CT_TEXTURE)
            edge:SetMouseEnabled(false)
            edge:SetDrawLayer(DL_OVERLAY)
            edge:SetColor(1, 0.76, 0.18, 1)
            data.leaderBorder[i] = edge
        end
    end
    for _, edge in ipairs(data.leaderBorder or {}) do
        edge:SetHidden(not showBorder)
        edge:SetAlpha(A.PlayerInfo:Alpha(frame))
    end
    if showBorder then
        local bar = frame.healthBar.barControls[1]
        local raid = frame.style == "ZO_RaidUnitFrame"
        local target = raid and frame.frame or bar
        local top, bottom = raid and 0 or -28, raid and 0 or 27
        -- Include the native role icon, but not the oversized root/background texture.
        local left = raid and 0 or (IsInGamepadPreferredMode() and -58 or -38)
        local right = raid and 0 or 4
        local anchors = {
            {TOPLEFT, TOPRIGHT, left, top, right, top},
            {BOTTOMLEFT, BOTTOMRIGHT, left, bottom, right, bottom},
            {TOPLEFT, BOTTOMLEFT, left, top, left, bottom},
            {TOPRIGHT, BOTTOMRIGHT, right, top, right, bottom},
        }
        for i, edge in ipairs(data.leaderBorder) do
            local a = anchors[i]
            edge:ClearAnchors()
            edge:SetAnchor(a[1], target, a[1], a[3], a[4])
            edge:SetAnchor(a[2], target, a[2], a[5], a[6])
            if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
        end
    end
    if frame.SetTextIndented and (leader ~= (data.leaderAdjusted or false)) then
        self.leaderUpdating = true
        frame:SetTextIndented(not A.active and IsUnitGroupLeader(frame.unitTag) or false)
        self.leaderUpdating = false
        data.leaderAdjusted = leader
    end
end
function F:Crown()
    local crown = ZO_UnitFrames_Leader
    if not crown then return end
    if A.active then
        if self.crownAlpha == nil then self.crownAlpha = crown:GetAlpha() end
        crown:SetAlpha(0)
    elseif self.crownAlpha ~= nil then
        crown:SetAlpha(self.crownAlpha)
        self.crownAlpha = nil
    end
end
function F:Color(frame)
    if self.coloring or not frame.healthBar then return end
    self.coloring = true
    frame.healthBar:SetColor(COMBAT_MECHANIC_FLAGS_HEALTH, A.active and A:RoleGradient(frame.unitTag) or nil)
    self.coloring = false
end
function F:Attach(frame)
    if not A.GroupData:IsPlayerFrame(frame) or not frame.frame or not frame.nameLabel
        or not frame.healthBar or not frame.healthBar.barControls or not frame.healthBar.barControls[1] then return end
    if not self.cache[frame] then
        self.cache[frame] = A.PlayerInfo:Create(frame)
        A.Interaction:Attach(frame)
        if not A.RoleSorting.anchors[frame] then A.RoleSorting:Capture(frame) end
        ZO_PostHook(frame.healthBar, "SetColor", function() if A.active then self:Color(frame) end end)
    end
    self:Color(frame)
    self:Leader(frame, self.cache[frame])
    A.PlayerInfo:Update(frame, self.cache[frame])
end
function F:UpdateTotal()
    local sum = A.CombatStats:GroupDPS()
    local bottomControl, bottom, left
    for _, member in ipairs(A.GroupData:Members()) do
        local frame = UNIT_FRAMES:GetFrame(member.tag)
        local data = frame and self.cache[frame]
        if data and frame.frame and not frame.frame:IsHidden() then
            local control = frame.frame
            local y, x = control:GetBottom(), control:GetLeft()
            if not bottom or y > bottom then bottom, bottomControl = y, control end
            left = left and math.min(left, x) or x
        end

    end
    if not self.total and bottomControl then
        self.total = WINDOW_MANAGER:CreateControl(A.name .. "GroupDPS", ZO_UnitFramesGroups, CT_LABEL)
        self.total:SetMouseEnabled(false)
        self.total:SetFont("$(BOLD_FONT)|16|soft-shadow-thin")
        self.total:SetColor(1, 1, 1, 1)
        self.total:SetDrawLayer(DL_TEXT)
    end
    if not self.total then return end
    self.total:SetHidden(not A.active or not bottomControl or sum == nil)
    if bottomControl and sum ~= nil then
        self.total:ClearAnchors()
        self.total:SetAnchor(TOPLEFT, bottomControl, BOTTOMLEFT, left - bottomControl:GetLeft(), 4)
        self.total:SetText(GetString(ONEFRAME_GROUP_DPS) .. ": " .. A.PlayerInfo:Format(sum))
    end
end
function F:Refresh()
    if not A.supported then return end
    self:Crown()
    local members = A.GroupData:Members()
    for _, member in ipairs(members) do self:Attach(UNIT_FRAMES:GetFrame(member.tag)) end
    for frame, data in pairs(self.cache) do
        if not A.active or UNIT_FRAMES:GetFrame(frame.unitTag) ~= frame or not DoesUnitExist(frame.unitTag) then
            self:Leader(frame, data)
            data.info:SetHidden(true)
            data.stats:SetHidden(true)
            if data.health then data.health:SetHidden(true) end
            if data.statsCaption then data.statsCaption:SetHidden(true) end
            A.UltimateUI:Hide(data.ultimate)
            if not A.active then self:Color(frame); A.PlayerInfo:Name(frame, data) end
        end
    end
    A.ShieldOverlay:Refresh()
    if A.sortDirty then
        A.sortDirty = false
        A.RoleSorting:Apply(members)
    end
    self:UpdateTotal()
end
function F:UpdateStats()
    for frame, data in pairs(self.cache) do
        if UNIT_FRAMES and UNIT_FRAMES:GetFrame(frame.unitTag) == frame then A.PlayerInfo:Stats(frame, data) end
    end
    self:UpdateTotal()
end
function F:Initialize()
    local function refresh(frame)
        if A.GroupData:IsPlayerFrame(frame) then
            -- Clear/replace a reused frame's statistics in the native refresh itself,
            -- before waiting for the coalesced layout pass.
            local data = self.cache[frame]
            if data then self:Leader(frame, data); A.PlayerInfo:Name(frame, data); A.PlayerInfo:Stats(frame, data) end
            A:QueueRefresh(false)
        end
    end
    ZO_PostHook(ZO_UnitFrameObject, "SetAnchor", function(frame)
        if not A.RoleSorting.applying and A.GroupData:IsPlayerFrame(frame) then
            A.RoleSorting:Capture(frame)
            A:QueueRefresh(true)
        end
    end)
    for _, method in ipairs({ "ApplyVisualStyle", "UpdateName", "UpdateLevel", "UpdateStatus", "UpdateAssignment", "DoAlphaUpdate" }) do
        ZO_PostHook(ZO_UnitFrameObject, method, refresh)
    end
    ZO_PostHook("ZO_UnitFrames_UpdateWindow", function(tag)
        if tag and tag:match("^group%d+$") then refresh(UNIT_FRAMES:GetFrame(tag)) end
    end)
    if ZO_UnitFrames_Leader then
        ZO_PostHook(ZO_UnitFrames_Leader, "SetHidden", function() self:Crown() end)
    end
    if ZO_UnitFrameObject.SetTextIndented then
        ZO_PostHook(ZO_UnitFrameObject, "SetTextIndented", function(frame, indented)
            if A.active and indented and not self.leaderUpdating and A.GroupData:IsPlayerFrame(frame) then
                self.leaderUpdating = true
                frame:SetTextIndented(false)
                self.leaderUpdating = false
            end
        end)
    end
end
