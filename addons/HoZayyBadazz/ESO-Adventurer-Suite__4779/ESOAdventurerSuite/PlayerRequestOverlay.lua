-- ESO Adventurer Suite
-- ESO native request / invite prompt layout controller
-- v0.29.331
--
-- Controls ONLY ESO's native player-to-player request prompt container:
-- group invites, trade requests, shared quests, friend/guild invites, duel/
-- Tribute prompts, ready checks and other prompts routed through PLAYER_TO_PLAYER.
-- The prompt keeps ESO's native artwork, text, buttons and behavior.

local EPC = ESOProgressionCoach
if not EPC then return end

local P = {
    name = "EASPlayerRequestOverlay029327",
    layoutMode = false,
    resizeState = nil,
    original = nil,
    styleHooked = false,
    testSerial = 0,
}
EPC.PlayerRequestOverlay = P

local wm = WINDOW_MANAGER
local BASE_WIDTH = 870
local BASE_HEIGHT = 150
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

function P:GetNamedPromptLabel(control, path)
    if not control or type(control.GetNamedChild) ~= "function" then return nil end
    local current = control
    for part in string.gmatch(path or "", "[^%.]+") do
        local ok, child = pcall(current.GetNamedChild, current, part)
        if not ok or not child then return nil end
        current = child
    end
    return current
end

function P:ApplyVisibilityStyle(control)
    control = control or self.target or self:GetTarget()
    if not control or not wm then return end

    -- v0.29.331: keep the native prompt visually clean. Earlier builds added
    -- a large dark backdrop here; the user wants the prompt text/buttons only.
    if self.visibilityBackdrop then
        self.visibilityBackdrop:SetHidden(true)
    end

    -- ESO exposes these labels directly in playertoplayer.xml. Keep ESO's
    -- actual wording and buttons, but make the request copy easier to read.
    local labels = {
        self:GetNamedPromptLabel(control, "Target"),
        self:GetNamedPromptLabel(control, "ActionArea.AdditionalInfo"),
        self:GetNamedPromptLabel(control, "ActionArea.PendingResurrectInfo"),
        self:GetNamedPromptLabel(control, "ActionArea.GamerID"),
    }
    for _, label in ipairs(labels) do
        if label then
            if type(label.SetFont) == "function" then pcall(label.SetFont, label, "ZoFontGameBold") end
            if type(label.SetColor) == "function" then pcall(label.SetColor, label, 1.0, 0.98, 0.90, 1.0) end
        end
    end
end

function P:InstallVisibilityHooks(control)
    if self.styleHooked or not control then return end
    self.styleHooked = true
    if type(ZO_PostHookHandler) == "function" then
        pcall(ZO_PostHookHandler, control, "OnShow", function() P:ApplyVisibilityStyle(control) end)
        pcall(ZO_PostHookHandler, control, "OnEffectivelyShown", function() P:ApplyVisibilityStyle(control) end)
    end
end

function P:CreateTestPreview()
    if self.testPreview or not wm or not GuiRoot then return self.testPreview end
    local preview = wm:CreateTopLevelWindow(self.name .. "TestPreview")
    preview:SetDimensions(820, 118)
    preview:SetDrawLayer(DL_OVERLAY)
    if preview.SetDrawTier and DT_HIGH then preview:SetDrawTier(DT_HIGH) end
    preview:SetDrawLevel(1950)
    preview:SetMouseEnabled(false)
    preview:SetHidden(true)

    local bg = wm:CreateControl(nil, preview, CT_BACKDROP)
    bg:SetAnchorFill(preview)
    bg:SetCenterColor(0, 0, 0, 0)
    bg:SetEdgeColor(1.0, 0.72, 0.16, 1.0)
    if bg.SetEdgeTexture then bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 16, 16, 2) end

    local tag = wm:CreateControl(nil, preview, CT_LABEL)
    tag:SetAnchor(TOP, preview, TOP, 0, 8)
    tag:SetDimensions(760, 22)
    tag:SetFont("ZoFontGameBold")
    tag:SetColor(1.0, 0.80, 0.22, 1)
    tag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tag:SetText("TEST — ESO REQUEST / INVITE PROMPT")

    local msg = wm:CreateControl(nil, preview, CT_LABEL)
    msg:SetAnchor(TOP, tag, BOTTOM, 0, 6)
    msg:SetDimensions(760, 28)
    msg:SetFont("ZoFontGameBold")
    msg:SetColor(1.0, 0.98, 0.90, 1)
    msg:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    msg:SetText("@ExamplePlayer has invited you to join a group")

    local keys = wm:CreateControl(nil, preview, CT_LABEL)
    keys:SetAnchor(TOP, msg, BOTTOM, 0, 4)
    keys:SetDimensions(760, 24)
    keys:SetFont("ZoFontGame")
    keys:SetColor(0.92, 0.95, 1.0, 1)
    keys:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    keys:SetText("ACCEPT     •     DECLINE")

    self.testPreview = preview
    return preview
end

function P:TestPrompt()
    local preview = self:CreateTestPreview()
    if not preview or not GuiRoot then return end
    local x, y, scale = self:GetCurrentCenter()
    preview:SetScale(scale or 1)
    preview:ClearAnchors()
    preview:SetAnchor(CENTER, GuiRoot, CENTER, x or 0, y or 0)
    preview:SetHidden(false)
    if preview.BringWindowToTop then preview:BringWindowToTop() end
    self.testSerial = (tonumber(self.testSerial) or 0) + 1
    local serial = self.testSerial
    zo_callLater(function()
        if P.testPreview and P.testSerial == serial then P.testPreview:SetHidden(true) end
    end, 6500)
end

function P:GetTarget()
    local control = rawget(_G, "ZO_PlayerToPlayerAreaPromptContainer")
    if control and type(control.ClearAnchors) == "function" and type(control.SetAnchor) == "function" then
        self.target = control
        self:CaptureOriginal(control)
        self:ApplyVisibilityStyle(control)
        self:InstallVisibilityHooks(control)
        return control
    end
    local area = rawget(_G, "ZO_PlayerToPlayerArea")
    if area and type(area.GetNamedChild) == "function" then
        local ok, child = pcall(area.GetNamedChild, area, "PromptContainer")
        if ok and child and type(child.ClearAnchors) == "function" and type(child.SetAnchor) == "function" then
            self.target = child
            self:CaptureOriginal(child)
            self:ApplyVisibilityStyle(child)
            self:InstallVisibilityHooks(child)
            return child
        end
    end
    return nil
end

function P:CaptureOriginal(control)
    if self.original or not control then return end
    local original = {
        scale = tonumber(safeMethod(control, "GetScale", 1)) or 1,
        anchors = {},
    }
    local count = tonumber(safeMethod(control, "GetNumAnchors", 0)) or 0
    if count > 0 and type(control.GetAnchor) == "function" then
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
        if #original.anchors == 0 then
            for i = 1, count do
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
    end
    self.original = original
end

function P:GetSaved()
    if not EPC.saved then return nil end
    local x = tonumber(EPC.saved.playerRequestPromptX029327)
    local y = tonumber(EPC.saved.playerRequestPromptY029327)
    local scale = tonumber(EPC.saved.playerRequestPromptScale029327) or 1
    if x == nil or y == nil then return nil end
    return x, y, clamp(scale, MIN_SCALE, MAX_SCALE)
end

function P:ApplySaved()
    local target = self:GetTarget()
    if not target or not GuiRoot then return false end
    local x, y, scale = self:GetSaved()
    if x == nil or y == nil then return false end
    if type(target.SetScale) == "function" then pcall(target.SetScale, target, scale) end
    pcall(target.ClearAnchors, target)
    pcall(target.SetAnchor, target, CENTER, GuiRoot, CENTER, x, y)
    return true
end

function P:RestoreOriginal()
    local target = self:GetTarget()
    if not target then return end
    local original = self.original
    if type(target.SetScale) == "function" then
        pcall(target.SetScale, target, original and original.scale or 1)
    end
    pcall(target.ClearAnchors, target)
    local restored = false
    if original and original.anchors and #original.anchors > 0 then
        for _, a in ipairs(original.anchors) do
            pcall(target.SetAnchor, target, a.point, a.relativeTo, a.relativePoint, a.offsetX, a.offsetY)
            restored = true
        end
    end
    if not restored then
        -- ESO 12.x native XML default for ZO_PlayerToPlayerAreaPromptContainer.
        pcall(target.SetAnchor, target, BOTTOM, nil, BOTTOM, 0, -285)
    end
end

function P:GetCurrentCenter()
    local target = self:GetTarget()
    local x, y, scale = self:GetSaved()
    if x ~= nil and y ~= nil then return x, y, scale end

    scale = tonumber(safeMethod(target, "GetScale", 1)) or 1
    local rootW = GuiRoot and tonumber(safeMethod(GuiRoot, "GetWidth", 1920)) or 1920
    local rootH = GuiRoot and tonumber(safeMethod(GuiRoot, "GetHeight", 1080)) or 1080
    local cx, cy = nil, nil
    -- Ask GetCenter directly so both coordinates are retained.
    if target and type(target.GetCenter) == "function" then
        local ok, tx, ty = pcall(target.GetCenter, target)
        if ok then cx, cy = tonumber(tx), tonumber(ty) end
    end
    if cx and cy then
        return cx - (rootW / 2), cy - (rootH / 2), clamp(scale, MIN_SCALE, MAX_SCALE)
    end

    -- Native prompt is bottom anchored 285 px above the bottom edge.
    local defaultCenterY = (rootH / 2) - 285 - (BASE_HEIGHT / 2)
    return 0, defaultCenterY, clamp(scale, MIN_SCALE, MAX_SCALE)
end

function P:SaveFromProxy()
    if not self.proxy or not EPC.saved or not GuiRoot then return end
    local rootW = tonumber(safeMethod(GuiRoot, "GetWidth", 1920)) or 1920
    local rootH = tonumber(safeMethod(GuiRoot, "GetHeight", 1080)) or 1080
    local left = tonumber(safeMethod(self.proxy, "GetLeft", 0)) or 0
    local top = tonumber(safeMethod(self.proxy, "GetTop", 0)) or 0
    local width = tonumber(safeMethod(self.proxy, "GetWidth", BASE_WIDTH)) or BASE_WIDTH
    local height = tonumber(safeMethod(self.proxy, "GetHeight", BASE_HEIGHT)) or BASE_HEIGHT
    EPC.saved.playerRequestPromptX029327 = left + width / 2 - rootW / 2
    EPC.saved.playerRequestPromptY029327 = top + height / 2 - rootH / 2
    EPC.saved.playerRequestPromptScale029327 = clamp(self.proxy.easScale or 1, MIN_SCALE, MAX_SCALE)
    self:ApplySaved()
end

function P:CreateProxy()
    if self.proxy or not wm or not GuiRoot then return self.proxy end

    local proxy = wm:CreateTopLevelWindow(self.name .. "Proxy")
    proxy:SetDrawLayer(DL_OVERLAY)
    if proxy.SetDrawTier and DT_HIGH then proxy:SetDrawTier(DT_HIGH) end
    proxy:SetDrawLevel(1700)
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
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("ESO REQUEST / INVITE PROMPT")
    title:SetMouseEnabled(false)

    local desc = wm:CreateControl(nil, proxy, CT_LABEL)
    desc:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 6)
    desc:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 6)
    desc:SetHeight(54)
    desc:SetFont("ZoFontGame")
    desc:SetColor(0.92, 0.92, 0.92, 1)
    desc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    desc:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    desc:SetText("Group invites • Trade requests • Shared quests\nHigh-visibility native prompt • Drag to move/resize")
    desc:SetMouseEnabled(false)

    local scaleLabel = wm:CreateControl(nil, proxy, CT_LABEL)
    scaleLabel:SetAnchor(BOTTOMLEFT, proxy, BOTTOMLEFT, 10, -8)
    scaleLabel:SetDimensions(130, 22)
    scaleLabel:SetFont("ZoFontGameSmall")
    scaleLabel:SetColor(0.78, 0.82, 0.88, 1)
    scaleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    scaleLabel:SetMouseEnabled(false)
    proxy.scaleLabel = scaleLabel

    local grip = wm:CreateControl(nil, proxy, CT_BUTTON)
    grip:SetDimensions(34, 34)
    grip:SetAnchor(BOTTOMRIGHT, proxy, BOTTOMRIGHT, -2, -2)
    grip:SetText("↘")
    grip:SetFont("ZoFontGameBold")
    grip:SetNormalFontColor(1.0, 0.82, 0.26, 1)
    grip:SetMouseOverFontColor(1, 1, 1, 1)
    grip:SetMouseEnabled(true)
    proxy.grip = grip

    -- v0.29.329: explicit single-click drag. Do not rely on StartMoving(),
    -- which can require a focus/selection click first on these HUD proxies.
    proxy:SetHandler("OnMouseDown", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or P.resizeState or type(GetUIMousePosition) ~= "function" then return end
        local mx, my = GetUIMousePosition()
        P.dragState = {
            startMouseX = mx, startMouseY = my,
            startLeft = tonumber(safeMethod(control, "GetLeft", 0)) or 0,
            startTop = tonumber(safeMethod(control, "GetTop", 0)) or 0,
        }
        if control.BringWindowToTop then control:BringWindowToTop() end
        EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Drag")
        EPC.Runtime:RegisterUpdate("PlayerRequestOverlay", "Drag", 16, function()
            local state = P.dragState
            if not state then EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Drag") return end
            local x, y = GetUIMousePosition()
            control:ClearAnchors()
            control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, state.startLeft + (x-state.startMouseX), state.startTop + (y-state.startMouseY))
        end)
    end)
    proxy:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not P.dragState then return end
        EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Drag")
        P.dragState = nil
        P:SaveFromProxy()
    end)

    grip:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or type(GetUIMousePosition) ~= "function" then return end
        local mx, my = GetUIMousePosition()
        P.resizeState = {
            startX = mx,
            startY = my,
            startScale = proxy.easScale or 1,
        }
        EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Resize")
        EPC.Runtime:RegisterUpdate("PlayerRequestOverlay", "Resize", 16, function()
            local state = P.resizeState
            if not state then
                EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Resize")
                return
            end
            local x, y = GetUIMousePosition()
            local dx = x - state.startX
            local dy = y - state.startY
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
        EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Resize")
        P.resizeState = nil
        P:SaveFromProxy()
    end)

    self.proxy = proxy
    return proxy
end

function P:SyncProxy()
    local proxy = self:CreateProxy()
    if not proxy or not GuiRoot then return end
    local x, y, scale = self:GetCurrentCenter()
    proxy.easScale = scale
    proxy:SetDimensions(BASE_WIDTH * scale, BASE_HEIGHT * scale)
    proxy:ClearAnchors()
    proxy:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    if proxy.scaleLabel then proxy.scaleLabel:SetText(string.format("Size: %d%%", math.floor(scale * 100 + 0.5))) end
end

function P:SetLayoutMode(active)
    active = active == true
    self.layoutMode = active
    EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Resize")
    EPC.Runtime:UnregisterUpdate("PlayerRequestOverlay", "Drag")
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

function P:RaiseForLayout()
    if not self.layoutMode or not self.proxy then return end
    if self.proxy.SetDrawTier and DT_HIGH then self.proxy:SetDrawTier(DT_HIGH) end
    self.proxy:SetDrawLevel(1700)
    if self.proxy.BringWindowToTop then self.proxy:BringWindowToTop() end
end

function P:ResetPosition()
    if EPC.saved then
        EPC.saved.playerRequestPromptX029327 = nil
        EPC.saved.playerRequestPromptY029327 = nil
        EPC.saved.playerRequestPromptScale029327 = 1.0
    end
    self:RestoreOriginal()
    if self.layoutMode then self:SyncProxy() end
end

function P:Initialize()
    -- No gameplay polling. The saved anchor is applied at UI lifecycle points.
    zo_callLater(function() P:GetTarget() P:ApplySaved() end, 300)
    zo_callLater(function() P:GetTarget() P:ApplySaved() end, 1200)
    EPC.Runtime:RegisterEvent("PlayerRequestOverlay", "Activated", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function() P:GetTarget() P:ApplySaved() end, 200)
    end)
    if rawget(_G, "EVENT_SCREEN_RESIZED") then
        EPC.Runtime:RegisterEvent("PlayerRequestOverlay", "Screen", EVENT_SCREEN_RESIZED, function()
            zo_callLater(function()
                P:ApplySaved()
                if P.layoutMode then P:SyncProxy() end
            end, 80)
        end)
    end
end


-- Loaded after Core.lua; Core owns EVENT_ADD_ON_LOADED and EPC.saved is already established.
P:Initialize()
