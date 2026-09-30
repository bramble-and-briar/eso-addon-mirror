local A = OneFrame
local R = { anchors = {}, applying = false, revision = 0 }
A.RoleSorting = R
local priorities = { [LFG_ROLE_TANK] = 1, [LFG_ROLE_HEAL] = 2, [LFG_ROLE_DPS] = 3 }
function R:Capture(frame)
    if self.applying or not A.GroupData:IsPlayerFrame(frame) then return end
    local anchors = {}
    for i = 0, frame.frame:GetNumAnchors() - 1 do
        local valid, point, relative, relativePoint, x, y, constraints = frame.frame:GetAnchor(i)
        if valid then anchors[#anchors + 1] = { point, relative, relativePoint, x, y, constraints } end
    end
    local previous = self.anchors[frame]
    local changed = not previous or #previous ~= #anchors
    if not changed then
        for i, anchor in ipairs(anchors) do
            for j = 1, 6 do if anchor[j] ~= previous[i][j] then changed = true end end
        end
    end
    self.anchors[frame] = anchors
    -- A native anchor write may replace our sorted position even when its native
    -- target is unchanged. Invalidate only on actual native calls, never our writes.
    self.revision = self.revision + 1
    local saved = self.positions and self.positions[frame]
    if self.sorted and A.active and A.sv.sort and saved and not changed
        and saved.tag == frame.unitTag and saved.identity == GetUnitDisplayName(frame.unitTag)
        and saved.style == frame.style and saved.size == GetGroupSize()
        and (UNIT_FRAMES:GetCompanionGroupSize() == 0 or frame.style == "ZO_RaidUnitFrame")
        and (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")) then
        self.applying = true
        frame.frame:ClearAnchors()
        for _, anchor in ipairs(saved.anchors) do frame.frame:SetAnchor(unpack(anchor, 1, 6)) end
        self.applying = false
    end
    return changed
end
function R:Restore()
    if not self.sorted then return end
    self.applying = true
    for frame, anchors in pairs(self.anchors) do
        if #anchors > 0 then
            frame.frame:ClearAnchors()
            for _, anchor in ipairs(anchors) do frame.frame:SetAnchor(unpack(anchor, 1, 6)) end
        end
    end
    self.applying = false
    self.positions = nil
    self.sorted = false
    self.signature = nil
end
function R:Apply(members)
    -- Raid companions occupy separate slots after players. Small-group companions
    -- are interleaved and retain vanilla positioning.
    if not A.active or not A.sv.sort
        then self:Restore(); return end
    if UNIT_FRAMES:GetCompanionGroupSize() > 0 then
        for _, member in ipairs(members) do
            local frame = UNIT_FRAMES:GetFrame(member.tag)
            if not frame then return end
            if frame.style ~= "ZO_RaidUnitFrame" then self:Restore(); return end
        end
    end
    -- Scene transitions are not roster changes. Defer layout without flashing native order.
    if not (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")) then return end
    local keys = {tostring(self.revision), tostring(UNIT_FRAMES:GetCompanionGroupSize())}
    if #members < GetGroupSize() then return end
    for _, member in ipairs(members) do
        local frame = UNIT_FRAMES:GetFrame(member.tag)
        -- Zone transitions can temporarily remove/hide one native frame. Keep the
        -- last complete layout until all frame objects exist; hidden frames retain slots.
        if not frame or not self.anchors[frame] then return end
        keys[#keys + 1] = table.concat({member.tag, member.identity, tostring(member.role),
            tostring(UNIT_FRAMES:GetFrame(member.tag))}, ":")
    end
    local signature = table.concat(keys, "|")
    if self.sorted and self.signature == signature then return end
    -- Native group/raid anchors target independent anchor containers. Reuse those
    -- directly: screen-coordinate measurements can be stale during ESO relayout.
    local controls, direct = {}, true
    for _, member in ipairs(members) do controls[UNIT_FRAMES:GetFrame(member.tag).frame] = true end
    for _, member in ipairs(members) do
        for _, anchor in ipairs(self.anchors[UNIT_FRAMES:GetFrame(member.tag)]) do
            if controls[anchor[2]] then direct = false end
        end
    end
    if not direct then self:Restore() end
    local slots, sorted = {}, {}
    for _, member in ipairs(members) do
        local frame = UNIT_FRAMES:GetFrame(member.tag)
        local control, parent = frame.frame, frame.frame:GetParent()
        slots[#slots + 1] = direct and self.anchors[frame]
            or { parent, control:GetLeft() - parent:GetLeft(), control:GetTop() - parent:GetTop() }
        sorted[#sorted + 1] = { member = member, frame = frame }
    end
    table.sort(sorted, function(a, b)
        local ar, br = priorities[a.member.role] or 4, priorities[b.member.role] or 4
        if ar ~= br then return ar < br end
        -- Account identity is stable across unitTag reassignment and composition changes.
        if a.member.identity ~= b.member.identity then return a.member.identity < b.member.identity end
        return a.member.index < b.member.index
    end)
    self.positions = {}
    self.applying = true
    for i, entry in ipairs(sorted) do
        local slot = slots[i]
        entry.frame.frame:ClearAnchors()
        if direct then
            for _, anchor in ipairs(slot) do entry.frame.frame:SetAnchor(unpack(anchor, 1, 6)) end
        else entry.frame.frame:SetAnchor(TOPLEFT, slot[1], TOPLEFT, slot[2], slot[3]) end
        if direct then
            self.positions[entry.frame] = {anchors=slot, tag=entry.member.tag,
                identity=entry.member.identity, style=entry.frame.style, size=GetGroupSize()}
        end
    end
    self.applying = false
    self.sorted, self.signature = true, signature
end
