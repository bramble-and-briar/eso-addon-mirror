-- API 101051 puts attached trackers under a clipping scroll control.
-- Use the same non-scrolling HUD parent ESO uses for detached trackers.
local MH = MovableHUD
local parents = {}
local function IsScrollDescendant(c, root)
    local p = c:GetParent()
    while p and p ~= GuiRoot do
        if p == root then return c:GetParent() ~= root end
        p = p.GetParent and p:GetParent() or nil
    end
    return false
end
local function RestoreParent(self, c)
    local original = parents[c]
    if not original then return end
    if c:GetParent() == _G.ZO_HUDTrackers then c:SetParent(original) end
    parents[c] = nil
end
local baseStandard = MH.ApplyStandardTarget
function MH:ApplyStandardTarget(key)
    if key ~= "quest" then return baseStandard(self, key) end
    local settings = self:GetElementSettings(key)
    local c = self:GetQuestControls()[1]
    if not c or not settings then return false end
    local root = _G.ZO_HUDTrackers
    if not settings.enabled then
        RestoreParent(self, c)
    elseif root and c.GetParent and c.SetParent and IsScrollDescendant(c, root) then
        -- Capture the native geometry before changing a relative anchor's parent.
        -- Refresh the baseline if ESO has reattached it during a new layout.
        if parents[c] then self:GetRuntime("quest").controlStates[c] = nil end
        self:CaptureControlState("quest", c)
        self:InitializeElementFromControl("quest", c)
        parents[c] = c:GetParent()
        c:SetParent(root)
    end
    return baseStandard(self, key)
end
local baseReset = MH.ResetTarget
function MH:ResetTarget(key)
    if key ~= "quest" then return baseReset(self, key) end
    local settings = self:GetElementSettings(key)
    if not settings then return false end
    settings.enabled = false
    self:ApplyTarget(key)
    settings.initialized = false
    self:UpdatePreviews()
    return true
end
local baseHooks = MH.InstallHooks
function MH:InstallHooks()
    baseHooks(self)
    if SecurePostHook and ZO_HUDTracker_Manager and ZO_HUDTracker_Manager.RefreshLayout then
        SecurePostHook(ZO_HUDTracker_Manager, "RefreshLayout", function()
            if MH.saved and MH:GetElementSettings("quest").enabled then
                MH:ApplyTarget("quest")
            end
        end)
    end
end
