-- ESO Adventurer Suite
-- Native compass focused-pin information layout controller
-- v0.29.336
--
-- Controls ONLY ESO's native ZO_CompassCenterOverPinLabel: the text that
-- appears above the compass when the player faces a quest, wayshrine, POI,
-- group member, etc. The compass itself is not moved or reskinned.

local EPC = ESOProgressionCoach
if not EPC then return end

local C = {
    name = "EASCompassFocusedInfo029336",
    layoutMode = false,
    original = nil,
    resizeState = nil,
    dragState = nil,
}
EPC.CompassFocusedInfoOverlay = C

local wm = WINDOW_MANAGER
local BASE_WIDTH = 620
local BASE_HEIGHT = 96
local MIN_SCALE = 0.60
local MAX_SCALE = 1.80

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function safeMethod(control, method, default, ...)
    if not control then return default end
    local fn = control[method]
    if type(fn) ~= "function" then return default end
    local ok, a, b, c, d, e = pcall(fn, control, ...)
    if not ok or a == nil then return default end
    return a, b, c, d, e
end

function C:GetTarget()
    local label = rawget(_G, "ZO_CompassCenterOverPinLabel")
    if not label then
        local compass = rawget(_G, "ZO_Compass")
        if compass and type(compass.GetNamedChild) == "function" then
            local ok, child = pcall(compass.GetNamedChild, compass, "CenterOverPinLabel")
            if ok then label = child end
        end
    end
    if label and type(label.ClearAnchors) == "function" and type(label.SetAnchor) == "function" then
        self.target = label
        self:CaptureOriginal(label)
        return label
    end
    return nil
end

function C:CaptureOriginal(control)
    if self.original or not control then return end
    local original = {
        scale = tonumber(safeMethod(control, "GetScale", 1)) or 1,
        anchors = {},
    }
    local count = tonumber(safeMethod(control, "GetNumAnchors", 0)) or 0
    if count > 0 and type(control.GetAnchor) == "function" then
        -- ESO controls normally expose zero-based anchor indexes.
        for i = 0, count - 1 do
            local ok, point, relativeTo, relativePoint, offsetX, offsetY = pcall(control.GetAnchor, control, i)
            if ok and point ~= nil then
                original.anchors[#original.anchors + 1] = {
                    point = point,
                    relativeTo = relativeTo,
                    relativePoint = relativePoint,
                    offsetX = tonumber(offsetX) or 0,
                    offsetY = tonumber(offsetY) or 0,
                }
            end
        end
    end
    self.original = original
end

function C:GetSaved()
    if not EPC.saved then return nil end
    local x = tonumber(EPC.saved.compassFocusedInfoX029336)
    local y = tonumber(EPC.saved.compassFocusedInfoY029336)
    local scale = tonumber(EPC.saved.compassFocusedInfoScale029336) or 1
    if x == nil or y == nil then return nil end
    return x, y, clamp(scale, MIN_SCALE, MAX_SCALE)
end

function C:GetCurrentCenter()
    local target = self:GetTarget()
    local x, y, scale = self:GetSaved()
    if x ~= nil and y ~= nil then return x, y, scale end

    scale = tonumber(safeMethod(target, "GetScale", 1)) or 1
    local rootW = GuiRoot and tonumber(safeMethod(GuiRoot, "GetWidth", 1920)) or 1920
    local rootH = GuiRoot and tonumber(safeMethod(GuiRoot, "GetHeight", 1080)) or 1080
    if target and type(target.GetCenter) == "function" then
        local ok, cx, cy = pcall(target.GetCenter, target)
        if ok and tonumber(cx) and tonumber(cy) then
            return tonumber(cx) - rootW / 2, tonumber(cy) - rootH / 2, clamp(scale, MIN_SCALE, MAX_SCALE)
        end
    end

    -- Fallback roughly matches ESO's normal above-compass position.
    return 0, -(rootH / 2) + 88, clamp(scale, MIN_SCALE, MAX_SCALE)
end

function C:ApplySaved()
    local target = self:GetTarget()
    if not target or not GuiRoot then return false end
    local x, y, scale = self:GetSaved()
    if x == nil or y == nil then return false end

    if type(target.SetScale) == "function" then pcall(target.SetScale, target, scale) end
    pcall(target.ClearAnchors, target)
    pcall(target.SetAnchor, target, CENTER, GuiRoot, CENTER, x, y)
    return true
end

function C:RestoreOriginal()
    local target = self:GetTarget()
    if not target then return end
    local original = self.original
    if type(target.SetScale) == "function" then pcall(target.SetScale, target, original and original.scale or 1) end
    pcall(target.ClearAnchors, target)

    local restored = false
    if original and original.anchors then
        for _, anchor in ipairs(original.anchors) do
            pcall(target.SetAnchor, target, anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX, anchor.offsetY)
            restored = true
        end
    end
    if not restored then
        -- ESO keyboard default: centered 5px above the compass.
        local compass = rawget(_G, "ZO_Compass")
        pcall(target.SetAnchor, target, BOTTOM, compass, TOP, 0, -5)
    end
end

function C:SaveFromProxy()
    if not self.proxy or not EPC.saved or not GuiRoot then return end
    local rootW = tonumber(safeMethod(GuiRoot, "GetWidth", 1920)) or 1920
    local rootH = tonumber(safeMethod(GuiRoot, "GetHeight", 1080)) or 1080
    local left = tonumber(safeMethod(self.proxy, "GetLeft", 0)) or 0
    local top = tonumber(safeMethod(self.proxy, "GetTop", 0)) or 0
    local width = tonumber(safeMethod(self.proxy, "GetWidth", BASE_WIDTH)) or BASE_WIDTH
    local height = tonumber(safeMethod(self.proxy, "GetHeight", BASE_HEIGHT)) or BASE_HEIGHT
    EPC.saved.compassFocusedInfoX029336 = left + width / 2 - rootW / 2
    EPC.saved.compassFocusedInfoY029336 = top + height / 2 - rootH / 2
    EPC.saved.compassFocusedInfoScale029336 = clamp(self.proxy.easScale or 1, MIN_SCALE, MAX_SCALE)
    self:ApplySaved()
end

function C:CreateProxy()
    if self.proxy or not wm or not GuiRoot then return self.proxy end

    local proxy = wm:CreateTopLevelWindow(self.name .. "Proxy")
    proxy:SetDrawLayer(DL_OVERLAY)
    if proxy.SetDrawTier and DT_HIGH then proxy:SetDrawTier(DT_HIGH) end
    proxy:SetDrawLevel(1685)
    proxy:SetMouseEnabled(true)
    proxy:SetMovable(false)
    proxy:SetClampedToScreen(true)
    proxy:SetHidden(true)

    local border = wm:CreateControl(nil, proxy, CT_BACKDROP)
    border:SetAnchorFill(proxy)
    border:SetCenterColor(0, 0, 0, 0)
    border:SetEdgeColor(1.0, 0.76, 0.18, 0.98)
    if border.SetEdgeTexture then border:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 16, 16, 1) end
    border:SetMouseEnabled(false)

    local title = wm:CreateControl(nil, proxy, CT_LABEL)
    title:SetAnchor(TOPLEFT, proxy, TOPLEFT, 10, 8)
    title:SetAnchor(TOPRIGHT, proxy, TOPRIGHT, -40, 8)
    title:SetHeight(26)
    title:SetFont("ZoFontGameBold")
    title:SetColor(1.0, 0.86, 0.32, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("ESO COMPASS FOCUSED INFO")
    title:SetMouseEnabled(false)

    local desc = wm:CreateControl(nil, proxy, CT_LABEL)
    desc:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 4)
    desc:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 4)
    desc:SetHeight(34)
    desc:SetFont("ZoFontGame")
    desc:SetColor(0.92, 0.92, 0.92, 1)
    desc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    desc:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    desc:SetText("Quest • Wayshrine • POI focused-name text\nDrag to move • Drag corner to resize")
    desc:SetMouseEnabled(false)

    local scaleLabel = wm:CreateControl(nil, proxy, CT_LABEL)
    scaleLabel:SetAnchor(BOTTOMLEFT, proxy, BOTTOMLEFT, 10, -5)
    scaleLabel:SetDimensions(130, 20)
    scaleLabel:SetFont("ZoFontGameSmall")
    scaleLabel:SetColor(0.78, 0.82, 0.88, 1)
    scaleLabel:SetMouseEnabled(false)
    proxy.scaleLabel = scaleLabel

    local grip = wm:CreateControl(nil, proxy, CT_BUTTON)
    grip:SetDimensions(34, 34)
    grip:SetAnchor(BOTTOMRIGHT, proxy, BOTTOMRIGHT, -2, -2)
    grip:SetText("↘")
    grip:SetFont("ZoFontGameBold")
    grip:SetNormalFontColor(1.0, 0.82, 0.26, 1)
    grip:SetMouseOverFontColor(1, 1, 1, 1)

    -- Single-click-and-hold drag, matching the communication overlays.
    proxy:SetHandler("OnMouseDown", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or C.resizeState or type(GetUIMousePosition) ~= "function" then return end
        local mx, my = GetUIMousePosition()
        C.dragState = {
            startMouseX = mx,
            startMouseY = my,
            startLeft = tonumber(safeMethod(control, "GetLeft", 0)) or 0,
            startTop = tonumber(safeMethod(control, "GetTop", 0)) or 0,
        }
        if control.BringWindowToTop then control:BringWindowToTop() end
        EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Drag")
        EPC.Runtime:RegisterUpdate("CompassFocusedInfoOverlay", "Drag", 16, function()
            local state = C.dragState
            if not state then EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Drag") return end
            local x, y = GetUIMousePosition()
            control:ClearAnchors()
            control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
                state.startLeft + (x - state.startMouseX),
                state.startTop + (y - state.startMouseY))
        end)
    end)
    proxy:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not C.dragState then return end
        EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Drag")
        C.dragState = nil
        C:SaveFromProxy()
    end)

    grip:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or type(GetUIMousePosition) ~= "function" then return end
        local mx, my = GetUIMousePosition()
        C.resizeState = { startX = mx, startY = my, startScale = proxy.easScale or 1 }
        EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Resize")
        EPC.Runtime:RegisterUpdate("CompassFocusedInfoOverlay", "Resize", 16, function()
            local state = C.resizeState
            if not state then EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Resize") return end
            local x, y = GetUIMousePosition()
            local dx, dy = x - state.startX, y - state.startY
            local factorX = (BASE_WIDTH * state.startScale + dx) / math.max(1, BASE_WIDTH * state.startScale)
            local factorY = (BASE_HEIGHT * state.startScale + dy) / math.max(1, BASE_HEIGHT * state.startScale)
            local factor = math.abs(dx / BASE_WIDTH) >= math.abs(dy / BASE_HEIGHT) and factorX or factorY
            local newScale = clamp(state.startScale * factor, MIN_SCALE, MAX_SCALE)
            proxy.easScale = newScale
            proxy:SetDimensions(BASE_WIDTH * newScale, BASE_HEIGHT * newScale)
            if proxy.scaleLabel then proxy.scaleLabel:SetText(string.format("Size: %d%%", math.floor(newScale * 100 + 0.5))) end
        end)
    end)
    grip:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Resize")
        C.resizeState = nil
        C:SaveFromProxy()
    end)

    self.proxy = proxy
    return proxy
end

function C:SyncProxy()
    local proxy = self:CreateProxy()
    if not proxy or not GuiRoot then return end
    local x, y, scale = self:GetCurrentCenter()
    proxy.easScale = scale
    proxy:SetDimensions(BASE_WIDTH * scale, BASE_HEIGHT * scale)
    proxy:ClearAnchors()
    proxy:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    if proxy.scaleLabel then proxy.scaleLabel:SetText(string.format("Size: %d%%", math.floor(scale * 100 + 0.5))) end
end

function C:SetLayoutMode(active)
    active = active == true
    self.layoutMode = active
    EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Resize")
    EPC.Runtime:UnregisterUpdate("CompassFocusedInfoOverlay", "Drag")
    self.resizeState = nil
    self.dragState = nil
    if active then
        self:GetTarget()
        self:SyncProxy()
        if self.proxy then self.proxy:SetHidden(false) end
    else
        if self.proxy then self.proxy:SetHidden(true) end
        self:ApplySaved()
    end
end

function C:RaiseForLayout()
    if not self.layoutMode or not self.proxy then return end
    if self.proxy.SetDrawTier and DT_HIGH then self.proxy:SetDrawTier(DT_HIGH) end
    self.proxy:SetDrawLevel(1685)
    if self.proxy.BringWindowToTop then self.proxy:BringWindowToTop() end
end

function C:ResetPosition()
    if EPC.saved then
        EPC.saved.compassFocusedInfoX029336 = nil
        EPC.saved.compassFocusedInfoY029336 = nil
        EPC.saved.compassFocusedInfoScale029336 = 1.0
    end
    self:RestoreOriginal()
    if self.layoutMode then self:SyncProxy() end
end

function C:Initialize()

    EPC.Runtime:RegisterEvent("CompassFocusedInfoOverlay", "Activated", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function() C:GetTarget() C:ApplySaved() end, 150)
    end)

    if rawget(_G, "EVENT_SCREEN_RESIZED") then
        EPC.Runtime:RegisterEvent("CompassFocusedInfoOverlay", "Screen", EVENT_SCREEN_RESIZED, function()
            zo_callLater(function()
                C:ApplySaved()
                if C.layoutMode then C:SyncProxy() end
            end, 80)
        end)
    end

    zo_callLater(function() C:GetTarget() C:ApplySaved() end, 350)
    zo_callLater(function() C:GetTarget() C:ApplySaved() end, 1200)
end


-- Loaded after Core.lua; Core owns EVENT_ADD_ON_LOADED and EPC.saved is already established.
C:Initialize()
