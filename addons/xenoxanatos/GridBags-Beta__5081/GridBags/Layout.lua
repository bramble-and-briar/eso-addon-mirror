GridBagsLayout = {}
local L = GridBagsLayout

function L:Get(mode)
    local saved = self.owner.saved
    saved.layouts = saved.layouts or {}
    saved.layouts[mode] = saved.layouts[mode] or { locked = true }
    return saved.layouts[mode]
end

function L:Mode()
    return self.owner:IsBankScene() and "bank" or "inventory"
end

function L:Record(mode)
    local root = self.owner.root
    local data = self:Get(mode)
    data.x = zo_clamp((root:GetLeft() - GuiRoot:GetLeft()) / GuiRoot:GetWidth(), 0, 1)
    data.y = zo_clamp((root:GetTop() - GuiRoot:GetTop()) / GuiRoot:GetHeight(), 0, 1)
end

function L:Stop()
    if not self.moving then return end
    self:Record(self.movingMode)
    self.moving = false
    self.owner.root:StopMovingOrResizing()
    self.owner.root:SetMovable(false)
end

function L:SetLocked(mode, locked)
    if self.moving and self.movingMode == mode then self:Stop() end
    self:Get(mode).locked = locked == true
    self:Apply()
end

function L:Reset(mode)
    if self.moving then self:Stop() end
    local data = self:Get(mode); data.x, data.y = nil, nil
    self:Apply()
end

function L:Apply()
    local owner, mode = self.owner, self:Mode()
    if self.moving and self.movingMode ~= mode then self:Stop() end
    local data = self:Get(mode)
    owner.root:SetMovable(self.moving == true and not data.locked)
    self.header:SetMouseEnabled(not data.locked)
    self.header:SetDimensions(owner.root:GetWidth(), 40)
    if owner.lockButton then owner.lockButton:SetText(data.locked and "Locked" or "Unlocked") end
    if self.moving then return end -- Inventory updates must not reset an ongoing drag.
    owner.root:ClearAnchors()
    if data.x ~= nil and data.y ~= nil then
        local scale = owner.root:GetScale()
        local x = zo_clamp(data.x * GuiRoot:GetWidth(), 0, math.max(0, GuiRoot:GetWidth() - owner.root:GetWidth() * scale))
        local y = zo_clamp(data.y * GuiRoot:GetHeight(), 0, math.max(0, GuiRoot:GetHeight() - owner.root:GetHeight() * scale))
        owner.root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    elseif mode == "bank" then owner.root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    else owner.root:SetAnchor(RIGHT, GuiRoot, RIGHT, -35, 0) end
end

function L:Initialize(owner)
    self.owner = owner
    owner.root:SetClampedToScreen(true)
    self.header = WINDOW_MANAGER:CreateControl("GridBagsDragHeader", owner.root, CT_CONTROL)
    self.header:SetAnchor(TOPLEFT, owner.root, TOPLEFT, 0, 0)
    self.header:SetHandler("OnMouseDown", function(_, button)
        local mode = self:Mode()
        if button == MOUSE_BUTTON_INDEX_LEFT and not self:Get(mode).locked then
            owner:ReleaseSearchFocus()
            self.moving, self.movingMode = true, mode
            owner.root:SetMovable(true)
            owner.root:StartMoving()
        end
    end)
    self.header:SetHandler("OnMouseUp", function() self:Stop() end)
    owner.root:SetHandler("OnMoveStop", function()
        if self.moving then self:Record(self.movingMode); self.moving = false end
        owner.root:SetMovable(false)
    end)
end
