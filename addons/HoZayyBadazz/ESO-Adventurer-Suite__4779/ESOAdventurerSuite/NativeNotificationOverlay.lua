-- ESO Adventurer Suite
-- ESO native alert-text notification layout controller
-- v0.29.335
--
-- Controls ESO's native alert-text notification stack used for short
-- system/player status notifications such as group invite results and
-- wayshrine/location alerts.  The visible fading entries are owned by the
-- single ALERT_MESSAGES fading buffer. Suite changes that buffer's structured
-- ZO_Anchor (the same type ESO uses natively), never duplicates the alert host,
-- and centers the native ZO_AlertLine text so wrapped lines remain centered.

local EPC = ESOProgressionCoach
if not EPC then return end

local N = {
    name = "EASNativeNotificationOverlay029328",
    layoutMode = false,
    resizeState = nil,
    original = nil,
    hookInstalled = false,
}
EPC.NativeNotificationOverlay = N

local wm = WINDOW_MANAGER
local BASE_WIDTH = 600
local BASE_HEIGHT = 140
local MIN_SCALE = 0.65
local MAX_SCALE = 2.00

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
    local ok, a, b, c, d = pcall(fn, control, ...)
    if not ok or a == nil then return default end
    return a, b, c, d
end

local function getBuffer(control)
    if not control then return nil end
    local ok, buffer = pcall(function() return control.fadingControlBuffer end)
    if ok and type(buffer) == "table" then return buffer end
    return nil
end

local function findFadingHost(control, depth)
    if not control then return nil end
    if getBuffer(control) then return control end
    depth = tonumber(depth) or 0
    if depth <= 0 or type(control.GetNumChildren) ~= "function" or type(control.GetChild) ~= "function" then return nil end
    local ok, count = pcall(control.GetNumChildren, control)
    count = ok and tonumber(count) or 0
    for i = 1, count do
        local childOk, child = pcall(control.GetChild, control, i)
        if childOk and child then
            if getBuffer(child) then return child end
            local nested = findFadingHost(child, depth - 1)
            if nested then return nested end
        end
    end
    return nil
end

function N:GetNativeBuffer()
    local alertsObject = rawget(_G, "ALERT_MESSAGES")
    if type(alertsObject) == "table" and type(alertsObject.alerts) == "table" then
        return alertsObject.alerts
    end
    local shell = rawget(_G, "ZO_AlertTextNotification") or rawget(_G, "ZO_AlertText")
    if shell then
        local direct = getBuffer(shell)
        if direct then return direct end
        local host = findFadingHost(shell, 3)
        if host then return getBuffer(host) end
    end
    return nil
end

function N:InstallCenteredText(buffer)
    if type(buffer) ~= "table" then return end
    local templates = buffer.templates
    local template = type(templates) == "table" and templates["ZO_AlertLine"] or nil
    if type(template) == "table" and type(template.setup) == "function" and not template.easSuiteCentered029335 then
        local originalSetup = template.setup
        template.setup = function(control, data)
            originalSetup(control, data)
            if control then
                if type(control.SetWidth) == "function" then pcall(control.SetWidth, control, BASE_WIDTH) end
                if type(control.SetHorizontalAlignment) == "function" then pcall(control.SetHorizontalAlignment, control, TEXT_ALIGN_CENTER) end
            end
        end
        template.easSuiteCentered029335 = true
    end

    -- Existing/fading rows may have been created before our setup wrapper ran.
    for _, entryControl in ipairs(buffer.activeEntries or {}) do
        for _, lineControl in ipairs(entryControl.activeLines or {}) do
            if lineControl then
                if type(lineControl.SetWidth) == "function" then pcall(lineControl.SetWidth, lineControl, BASE_WIDTH) end
                if type(lineControl.SetHorizontalAlignment) == "function" then pcall(lineControl.SetHorizontalAlignment, lineControl, TEXT_ALIGN_CENTER) end
            end
        end
    end
end

function N:GetTarget()
    -- The visible alert rows are owned by ALERT_MESSAGES.alerts.  Do not move
    -- both the outer shell and an inner host: that can leave ESO's stock anchor
    -- active at the same time and make the same notification appear twice.
    local shell = rawget(_G, "ZO_AlertTextNotification") or rawget(_G, "ZO_AlertText")
    local buffer = self:GetNativeBuffer()
    if not shell or type(buffer) ~= "table" then return nil end

    if self.target ~= shell or self.buffer ~= buffer then
        self.target = shell
        self.shell = shell
        self.buffer = buffer
        self.original = nil
        self.hookInstalled = false
    end
    self:CaptureOriginal(shell)
    self:InstallCenteredText(buffer)
    self:InstallReapplyHook(shell)
    return shell
end

function N:CaptureOriginal(control)
    if self.original or not control then return end
    local original = {
        scale = tonumber(safeMethod(control, "GetScale", 1)) or 1,
        anchors = {},
        bufferAnchor = self.buffer and self.buffer.anchor or nil,
    }
    local count = tonumber(safeMethod(control, "GetNumAnchors", 0)) or 0
    if count > 0 and type(control.GetAnchor) == "function" then
        for i = 0, count - 1 do
            local ok, point, relativeTo, relativePoint, offsetX, offsetY = pcall(control.GetAnchor, control, i)
            if ok and point ~= nil then
                original.anchors[#original.anchors + 1] = { point=point, relativeTo=relativeTo, relativePoint=relativePoint, offsetX=tonumber(offsetX) or 0, offsetY=tonumber(offsetY) or 0 }
            end
        end
        if #original.anchors == 0 then
            for i = 1, count do
                local ok, point, relativeTo, relativePoint, offsetX, offsetY = pcall(control.GetAnchor, control, i)
                if ok and point ~= nil then
                    original.anchors[#original.anchors + 1] = { point=point, relativeTo=relativeTo, relativePoint=relativePoint, offsetX=tonumber(offsetX) or 0, offsetY=tonumber(offsetY) or 0 }
                end
            end
        end
    end
    self.original = original
end

function N:InstallReapplyHook(control)
    if self.hookInstalled or not control or type(ZO_PostHookHandler) ~= "function" then return end
    self.hookInstalled = true
    pcall(ZO_PostHookHandler, control, "OnShow", function() if not N.layoutMode then N:ApplySaved() end end)
    pcall(ZO_PostHookHandler, control, "OnEffectivelyShown", function() if not N.layoutMode then N:ApplySaved() end end)
end

function N:UpdateNativeAlertAnchorMode(target)
    -- v0.29.335: no numeric/manual anchor constants are written here.
    -- ApplySaved() replaces ESO's buffer anchor only with a real ZO_Anchor
    -- object, which preserves the structure DisplayEntry() expects.
    return
end

function N:QueueNativeAlertReapply()
    if self.layoutMode then return end
    self.reapplySerial = (tonumber(self.reapplySerial) or 0) + 1
    local serial = self.reapplySerial
    -- Native alert rows can be created/anchored one frame after ZO_Alert is
    -- called. Reapply immediately and once after the row construction settles.
    zo_callLater(function()
        if serial ~= N.reapplySerial then return end
        N:ApplySaved()
    end, 1)
    zo_callLater(function()
        if serial ~= N.reapplySerial then return end
        N:ApplySaved()
    end, 70)
end

function N:InstallNativeAlertHooks()
    if self.nativeAlertHooksInstalled or type(SecurePostHook) ~= "function" then return end
    self.nativeAlertHooksInstalled = true

    if type(rawget(_G, "ZO_Alert")) == "function" then
        pcall(SecurePostHook, "ZO_Alert", function()
            N:QueueNativeAlertReapply()
        end)
    end
    if type(rawget(_G, "ZO_SoundAlert")) == "function" then
        pcall(SecurePostHook, "ZO_SoundAlert", function()
            N:QueueNativeAlertReapply()
        end)
    end

    -- Some native notifications are queued through systems that do not call
    -- ZO_Alert directly.  Hook the generic fading-buffer display method and
    -- react only when the buffer belongs to ESO's alert-text host.  This is
    -- event-driven and does not poll during gameplay.
    local fadingClass = rawget(_G, "ZO_FadingControlBuffer")
    if type(fadingClass) == "table" and type(fadingClass.DisplayEntry) == "function" then
        pcall(SecurePostHook, fadingClass, "DisplayEntry", function(buffer)
            N:GetTarget()
            local nativeBuffer = N.buffer or N:GetNativeBuffer()
            if nativeBuffer == buffer then
                N:InstallCenteredText(buffer)
                N:QueueNativeAlertReapply()
            end
        end)
    end
end

function N:GetSaved()
    if not EPC.saved then return nil end
    local x = tonumber(EPC.saved.nativeAlertTextX029328)
    local y = tonumber(EPC.saved.nativeAlertTextY029328)
    local scale = tonumber(EPC.saved.nativeAlertTextScale029328) or 1
    if x == nil or y == nil then return nil end
    return x, y, clamp(scale, MIN_SCALE, MAX_SCALE)
end

function N:GetCurrentCenter()
    local target = self:GetTarget()
    local x, y, scale = self:GetSaved()
    if x ~= nil and y ~= nil then return x, y, scale end
    scale = tonumber(safeMethod(target, "GetScale", 1)) or 1
    local rootW = GuiRoot and tonumber(safeMethod(GuiRoot, "GetWidth", 1920)) or 1920
    local rootH = GuiRoot and tonumber(safeMethod(GuiRoot, "GetHeight", 1080)) or 1080
    if target and type(target.GetCenter) == "function" then
        local ok, cx, cy = pcall(target.GetCenter, target)
        if ok and tonumber(cx) and tonumber(cy) then
            return tonumber(cx) - rootW/2, tonumber(cy) - rootH/2, clamp(scale, MIN_SCALE, MAX_SCALE)
        end
    end
    -- Native alert text lives near the upper-right by default.
    return (rootW/2) - 330, -(rootH/2) + 150, clamp(scale, MIN_SCALE, MAX_SCALE)
end

function N:ApplySaved()
    local target = self:GetTarget()
    local buffer = self.buffer or self:GetNativeBuffer()
    if not target or type(buffer) ~= "table" or not GuiRoot then return false end
    local x, y, scale = self:GetSaved()

    -- Update 51: ESO's native Edit HUD owns the Alert Text position. Keep the
    -- Suite's centered-text/scale presentation without writing a competing anchor.
    if EPC.NativeHUDEditor and EPC.NativeHUDEditor.IsESOPositionOwner
        and EPC.NativeHUDEditor:IsESOPositionOwner(target) then
        if type(target.SetScale) == "function" then pcall(target.SetScale, target, scale or 1) end
        self:InstallCenteredText(buffer)
        return true
    end

    if x == nil or y == nil then return false end

    -- Keep ESO's outer top-level control at its native anchor.  Move the one
    -- true fading buffer anchor instead. ZO_Anchor is the exact structured
    -- object ESO itself passes to ZO_FadingControlBuffer, so DisplayEntry keeps
    -- one native row stack instead of a moved copy plus the stock top-right one.
    if type(target.SetScale) == "function" then pcall(target.SetScale, target, scale) end
    if type(rawget(_G, "ZO_Anchor")) == "table" and type(ZO_Anchor.New) == "function" then
        buffer.anchor = ZO_Anchor:New(CENTER, GuiRoot, CENTER, x, y)
    else
        return false
    end

    self:InstallCenteredText(buffer)
    if buffer.anchor and type(buffer.anchor.Set) == "function" then
        for _, entryControl in ipairs(buffer.activeEntries or {}) do
            pcall(buffer.anchor.Set, buffer.anchor, entryControl)
        end
    end
    return true
end

function N:RestoreOriginal()
    local target = self:GetTarget()
    if not target then return end
    local original = self.original
    if type(target.SetScale) == "function" then pcall(target.SetScale, target, original and original.scale or 1) end
    local buffer = self.buffer or self:GetNativeBuffer()
    if type(buffer) == "table" and original and original.bufferAnchor then
        buffer.anchor = original.bufferAnchor
        if type(buffer.anchor.Set) == "function" then
            for _, entryControl in ipairs(buffer.activeEntries or {}) do
                pcall(buffer.anchor.Set, buffer.anchor, entryControl)
            end
        end
    end
end

function N:SaveFromProxy()
    if not self.proxy or not EPC.saved or not GuiRoot then return end
    local rootW = tonumber(safeMethod(GuiRoot, "GetWidth", 1920)) or 1920
    local rootH = tonumber(safeMethod(GuiRoot, "GetHeight", 1080)) or 1080
    local left = tonumber(safeMethod(self.proxy, "GetLeft", 0)) or 0
    local top = tonumber(safeMethod(self.proxy, "GetTop", 0)) or 0
    local width = tonumber(safeMethod(self.proxy, "GetWidth", BASE_WIDTH)) or BASE_WIDTH
    local height = tonumber(safeMethod(self.proxy, "GetHeight", BASE_HEIGHT)) or BASE_HEIGHT
    EPC.saved.nativeAlertTextX029328 = left + width/2 - rootW/2
    EPC.saved.nativeAlertTextY029328 = top + height/2 - rootH/2
    EPC.saved.nativeAlertTextScale029328 = clamp(self.proxy.easScale or 1, MIN_SCALE, MAX_SCALE)
    self:ApplySaved()
end

function N:CreateProxy()
    if self.proxy or not wm or not GuiRoot then return self.proxy end
    local proxy = wm:CreateTopLevelWindow(self.name .. "Proxy")
    proxy:SetDrawLayer(DL_OVERLAY)
    if proxy.SetDrawTier and DT_HIGH then proxy:SetDrawTier(DT_HIGH) end
    proxy:SetDrawLevel(1690)
    proxy:SetMouseEnabled(true)
    proxy:SetMovable(false)
    proxy:SetClampedToScreen(true)
    proxy:SetHidden(true)

    local bg = wm:CreateControl(nil, proxy, CT_BACKDROP)
    bg:SetAnchorFill(proxy)
    bg:SetCenterColor(0, 0, 0, 0)
    bg:SetEdgeColor(1.0, 0.76, 0.18, 0.98)
    if bg.SetEdgeTexture then bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 16, 16, 1) end
    bg:SetMouseEnabled(false)

    local title = wm:CreateControl(nil, proxy, CT_LABEL)
    title:SetAnchor(TOPLEFT, proxy, TOPLEFT, 10, 8)
    title:SetAnchor(TOPRIGHT, proxy, TOPRIGHT, -40, 8)
    title:SetHeight(26)
    title:SetFont("ZoFontGameBold")
    title:SetColor(1.0, 0.86, 0.32, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("ESO NATIVE ALERT NOTIFICATIONS")
    title:SetMouseEnabled(false)

    local desc = wm:CreateControl(nil, proxy, CT_LABEL)
    desc:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 6)
    desc:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 6)
    desc:SetHeight(56)
    desc:SetFont("ZoFontGame")
    desc:SetColor(0.92, 0.92, 0.92, 1)
    desc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    desc:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    desc:SetText("Group invite results • wayshrine/location alerts • duel/system notices\nDrag to move • Drag corner to resize")
    desc:SetMouseEnabled(false)

    local scaleLabel = wm:CreateControl(nil, proxy, CT_LABEL)
    scaleLabel:SetAnchor(BOTTOMLEFT, proxy, BOTTOMLEFT, 10, -8)
    scaleLabel:SetDimensions(130, 22)
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

    -- v0.29.329: explicit single-click drag. Do not rely on StartMoving(),
    -- which can require a focus/selection click first on these HUD proxies.
    proxy:SetHandler("OnMouseDown", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or N.resizeState or type(GetUIMousePosition) ~= "function" then return end
        local mx, my = GetUIMousePosition()
        N.dragState = {
            startMouseX = mx, startMouseY = my,
            startLeft = tonumber(safeMethod(control, "GetLeft", 0)) or 0,
            startTop = tonumber(safeMethod(control, "GetTop", 0)) or 0,
        }
        if control.BringWindowToTop then control:BringWindowToTop() end
        EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Drag")
        EPC.Runtime:RegisterUpdate("NativeNotificationOverlay", "Drag", 16, function()
            local state = N.dragState
            if not state then EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Drag") return end
            local x, y = GetUIMousePosition()
            control:ClearAnchors()
            control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, state.startLeft + (x-state.startMouseX), state.startTop + (y-state.startMouseY))
        end)
    end)
    proxy:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not N.dragState then return end
        EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Drag")
        N.dragState = nil
        N:SaveFromProxy()
    end)

    grip:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or type(GetUIMousePosition) ~= "function" then return end
        local mx, my = GetUIMousePosition()
        N.resizeState = { startX=mx, startY=my, startScale=proxy.easScale or 1 }
        EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Resize")
        EPC.Runtime:RegisterUpdate("NativeNotificationOverlay", "Resize", 16, function()
            local state = N.resizeState
            if not state then EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Resize") return end
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
        EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Resize")
        N.resizeState = nil
        N:SaveFromProxy()
    end)

    self.proxy = proxy
    return proxy
end

function N:SyncProxy()
    local proxy = self:CreateProxy()
    if not proxy or not GuiRoot then return end
    local x, y, scale = self:GetCurrentCenter()
    proxy.easScale = scale
    proxy:SetDimensions(BASE_WIDTH * scale, BASE_HEIGHT * scale)
    proxy:ClearAnchors()
    proxy:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    if proxy.scaleLabel then proxy.scaleLabel:SetText(string.format("Size: %d%%", math.floor(scale * 100 + 0.5))) end
end

function N:SetLayoutMode(active)
    active = active == true
    self.layoutMode = active
    EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Resize")
    EPC.Runtime:UnregisterUpdate("NativeNotificationOverlay", "Drag")
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

function N:RaiseForLayout()
    if not self.layoutMode or not self.proxy then return end
    if self.proxy.SetDrawTier and DT_HIGH then self.proxy:SetDrawTier(DT_HIGH) end
    self.proxy:SetDrawLevel(1690)
    if self.proxy.BringWindowToTop then self.proxy:BringWindowToTop() end
end

function N:ResetPosition()
    if EPC.saved then
        EPC.saved.nativeAlertTextX029328 = nil
        EPC.saved.nativeAlertTextY029328 = nil
        EPC.saved.nativeAlertTextScale029328 = 1.0
    end
    self:RestoreOriginal()
    if self.layoutMode then self:SyncProxy() end
end

function N:TestNotification()
    self:GetTarget()
    self:ApplySaved()
    if type(ZO_Alert) == "function" then
        local category = rawget(_G, "UI_ALERT_CATEGORY_ALERT") or rawget(_G, "ALERT") or 1
        pcall(ZO_Alert, category, nil, "ESO Adventurer Suite — test notification")
        self:QueueNativeAlertReapply()
    elseif EPC and EPC.Print then
        EPC:Print("Test notification: native ESO alert host is not available yet.")
    end
end

function N:Initialize()
    self:InstallNativeAlertHooks()
    zo_callLater(function() N:GetTarget() N:ApplySaved() end, 350)
    zo_callLater(function() N:GetTarget() N:ApplySaved() end, 1300)
    EPC.Runtime:RegisterEvent("NativeNotificationOverlay", "Activated", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function() N:GetTarget() N:ApplySaved() end, 200)
    end)
    if rawget(_G, "EVENT_SCREEN_RESIZED") then
        EPC.Runtime:RegisterEvent("NativeNotificationOverlay", "Screen", EVENT_SCREEN_RESIZED, function()
            zo_callLater(function()
                N:ApplySaved()
                if N.layoutMode then N:SyncProxy() end
            end, 80)
        end)
    end
end


-- Loaded after Core.lua; Core owns EVENT_ADD_ON_LOADED and EPC.saved is already established.
N:Initialize()
