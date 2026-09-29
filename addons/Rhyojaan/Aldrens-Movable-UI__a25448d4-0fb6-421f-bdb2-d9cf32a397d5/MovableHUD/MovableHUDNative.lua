-- Native movers alter only anchors; size, scale, parents and input stay ESO-owned.
local MH = MovableHUD
local states = {}
local function Snapshot(c)
    local anchors = {}
    local count = c:GetNumAnchors()
    if count < 1 or count > 2 then return nil end
    for i = 0, count - 1 do
        local valid, point, relative, relativePoint, x, y, constraints = c:GetAnchor(i)
        if not valid then return nil end
        anchors[#anchors + 1] = {point, relative, relativePoint, x or 0, y or 0, constraints}
    end
    return anchors
end
local function Equal(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do
        for j = 1, 6 do if a[i][j] ~= b[i][j] then return false end end
    end
    return true
end
local function Anchor(c, anchors, x, y)
    c:ClearAnchors()
    for _, a in ipairs(anchors) do
        c:SetAnchor(a[1], a[2], a[3], a[4] + x, a[5] + y, a[6])
    end
end
local function Safe(c)
    return c and c ~= GuiRoot and c.GetAnchor and c.GetNumAnchors
        and c.SetAnchor and c.ClearAnchors and c.GetWidth and c.GetHeight
end
function MH:ResolveNative(key)
    if key == "activitydialog" then return nil end -- Reserved saved key; shared dialogs are not accessed.
    for _, name in ipairs(self.nativeTargets[key].names) do
        local c = _G[name]
        if Safe(c) then return c end
    end
end
function MH:ReleaseNative(key)
    local state = states[key]
    if not state then return true end
    local ok = pcall(function()
        -- If ESO has already replaced our anchors, keep its newer layout.
        if Equal(Snapshot(state.control), state.applied) then
            Anchor(state.control, state.base, 0, 0)
        end
    end)
    if ok then states[key] = nil end
    return ok
end
local function ApplyNative(self, key)
    local settings = self:GetElementSettings(key)
    local c = settings and settings.enabled and self:ResolveNative(key) or nil
    local old = states[key]
    if old and (old.control ~= c or not c or c:IsHidden()) then
        if not self:ReleaseNative(key) then return false end
    end
    if not c or c:IsHidden() or not Safe(c) then return false end
    -- Refuse screen-filling containers; registry uses their discrete visible children.
    if c:GetWidth() >= GuiRoot:GetWidth() * .95 and c:GetHeight() >= GuiRoot:GetHeight() * .95 then return false end
    local current = Snapshot(c)
    if not current then return false end
    local state = states[key]
    if not state then
        state = {control = c, base = current}
        states[key] = state
    elseif not Equal(current, state.applied) then
        -- A scene, safe-zone, or tracker layout supplied a fresh native anchor.
        state.base = current
    end
    local desired = {}
    for i, a in ipairs(state.base) do
        desired[i] = {a[1], a[2], a[3], a[4] + settings.x, a[5] + settings.y, a[6]}
    end
    if not Equal(current, desired) then
        local ok = pcall(Anchor, c, desired, 0, 0)
        if not ok then
            -- Roll back a partial ClearAnchors/SetAnchor failure.
            pcall(Anchor, c, current, 0, 0)
            return false
        end
    end
    state.applied = desired
    return true
end
local baseNormalize = MH.NormalizeSavedVariables
function MH:NormalizeSavedVariables()
    baseNormalize(self)
    for _, key in ipairs(self.nativeOrder) do
        local s = self.saved.elements[key]
        if type(s) ~= "table" then s = {}; self.saved.elements[key] = s end
        s.enabled = s.enabled == true
        for _, field in ipairs({"x", "y"}) do
            local value = tonumber(s[field]) or 0
            if value ~= value then value = 0 end
            s[field] = math.max(-2500, math.min(3500, math.floor(value + .5)))
        end
        s.scale = 1
        s.width, s.height = 0, 0
        s.initialized = true
    end
    self.saved.schemaVersion = 5
end
local baseName = MH.GetTargetName
function MH:GetTargetName(key)
    return self.nativeTargets[key] and self.nativeTargets[key].label or baseName(self, key)
end
local baseControls = MH.GetTargetControls
function MH:GetTargetControls(key, hidden)
    if not self.nativeTargets[key] then return baseControls(self, key, hidden) end
    local ok, c = pcall(self.ResolveNative, self, key)
    if ok and c and not c:IsHidden() then return {c} end
    return {}
end
local baseApply = MH.ApplyTarget
function MH:ApplyTarget(key)
    if not self.nativeTargets[key] then return baseApply(self, key) end
    local ok, result = pcall(ApplyNative, self, key)
    self:GetRuntime(key).nativeStatus = ok and result and "active" or "waiting / unavailable"
    return ok and result or false
end
local baseValue = MH.SetElementValue
function MH:SetElementValue(key, property, value)
    if key == "activitydialog" then return false end
    if self.nativeTargets[key] and property ~= "x" and property ~= "y" and property ~= "enabled" then return false end
    return baseValue(self, key, property, value)
end
local baseReset = MH.ResetTarget
function MH:ResetTarget(key)
    if not self.nativeTargets[key] then return baseReset(self, key) end
    local s = self:GetElementSettings(key)
    s.enabled, s.x, s.y = false, 0, 0
    local ok = self:ReleaseNative(key)
    self:UpdatePreviews()
    return ok
end
local baseHooks = MH.InstallHooks
function MH:InstallHooks()
    baseHooks(self)
    EVENT_MANAGER:RegisterForUpdate(self.name .. "_NativeGuard", 250, function()
        for _, key in ipairs(MH.nativeOrder) do
            if MH:GetElementSettings(key).enabled or states[key] then MH:ApplyTarget(key) end
        end
    end)
end
local baseStatus = MH.GetTargetStatus
function MH:GetTargetStatus(key)
    if key == "activitydialog" then return "Activity Finder dialog mover: unavailable (saved settings retained)" end
    if not self.nativeTargets[key] then return baseStatus(self, key) end
    local s = self:GetElementSettings(key)
    return string.format("%s [%s]: %s, offset %d / %d", self:GetTargetName(key), key,
        s.enabled and (self:GetRuntime(key).nativeStatus or "waiting") or "OFF", s.x, s.y)
end
local baseCommand = MH.HandleCommand
function MH:HandleCommand(text)
    local cmd, key, property, value = string.match(text or "", "^(%S+)%s*(%S*)%s*(%S*)%s*(%S*)")
    if key and self.nativeTargets[key] then
        if cmd == "reset" then self:ResetTarget(key)
        elseif cmd == "set" then self:SetElementValue(key, property, value) end
        self:Print(self:GetTargetStatus(key))
        return
    end
    baseCommand(self, text)
end

