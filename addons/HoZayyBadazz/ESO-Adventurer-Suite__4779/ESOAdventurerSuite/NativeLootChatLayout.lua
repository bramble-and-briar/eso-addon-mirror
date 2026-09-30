-- ESO Adventurer Suite
-- v0.29.739 - preserve native Chat open/minimized state across UI reloads.
-- No replacement/proxy overlays are created. ESO's own controls are moved/resized.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER then return end

local H = {
    name = (EPC.name or "ESOAdventurerSuite") .. "_NativeHUD029710",
    layoutMode = false,
    lootOriginal = nil,
    chatOriginal = nil,
    lootBindings = nil,
    chatBindings = nil,
    lastLootPreviewMs = 0,
}
EPC.NativeHUDLayout = H

local EM = EVENT_MANAGER

local CHAT_MIN_W, CHAT_MAX_W = 320, 1100
local CHAT_MIN_H, CHAT_MAX_H = 180, 760
local LOOT_MIN_SCALE, LOOT_MAX_SCALE = 0.65, 1.80
local CHAT_EDGE_SNAP = 32

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return tonumber(GetFrameTimeMilliseconds()) or 0
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return tonumber(GetGameTimeMilliseconds()) or 0
    end
    return 0
end

local function safeMethod(control, method, fallback, ...)
    if not control then return fallback end
    local fn = control[method]
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e = pcall(fn, control, ...)
    if not ok or a == nil then return fallback end
    return a, b, c, d, e
end

local function rootSize()
    local w = GuiRoot and tonumber(safeMethod(GuiRoot, "GetWidth", 1920)) or 1920
    local h = GuiRoot and tonumber(safeMethod(GuiRoot, "GetHeight", 1080)) or 1080
    return math.max(1, w), math.max(1, h)
end

local function getHandler(control, name)
    if control and type(control.GetHandler) == "function" then
        local ok, handler = pcall(control.GetHandler, control, name)
        if ok then return handler end
    end
    return nil
end

local function setHandler(control, name, handler)
    if control and type(control.SetHandler) == "function" then
        pcall(control.SetHandler, control, name, handler)
    end
end

local function captureAnchor(control)
    if not control or type(control.GetAnchor) ~= "function" then return nil end
    local ok, point, relativeTo, relativePoint, x, y = pcall(control.GetAnchor, control, 0)
    if not ok or point == nil then return nil end
    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
    }
end

local function restoreAnchor(control, anchor)
    if not control or not anchor then return end
    if type(control.ClearAnchors) == "function" then pcall(control.ClearAnchors, control) end
    if type(control.SetAnchor) == "function" then
        pcall(control.SetAnchor, control, anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y)
    end
end

-- ============================================================================
-- ESO NATIVE LOOT HISTORY
-- ============================================================================

function H:GetLootTargets()
    local object = rawget(_G, "LOOT_HISTORY_KEYBOARD")
    local control = rawget(_G, "ZO_LootHistoryControl_Keyboard")
    if type(object) ~= "table" or not control then return nil, nil, nil, nil end

    local persistent = control.GetNamedChild and control:GetNamedChild("PersistentContainer") or nil
    local normal = control.GetNamedChild and control:GetNamedChild("Container") or nil
    return object, control, persistent, normal
end

function H:CaptureLootOriginal()
    if self.lootOriginal then return end
    local _, control, persistent, normal = self:GetLootTargets()
    if not control then return end

    self.lootOriginal = {
        anchor = captureAnchor(control),
        scale = tonumber(safeMethod(control, "GetScale", 1)) or 1,
        controlMouse = safeMethod(control, "IsMouseEnabled", false) == true,
        persistentMouse = safeMethod(persistent, "IsMouseEnabled", false) == true,
        normalMouse = safeMethod(normal, "IsMouseEnabled", false) == true,
    }
end

function H:GetLootScale()
    return clamp(EPC.saved and EPC.saved.nativeLootHistoryScale029708 or 1, LOOT_MIN_SCALE, LOOT_MAX_SCALE)
end

function H:GetLootOffset()
    local x = EPC.saved and tonumber(EPC.saved.nativeLootHistoryOffsetX029708)
    local y = EPC.saved and tonumber(EPC.saved.nativeLootHistoryOffsetY029708)
    return x, y
end

function H:ApplyLootSaved()
    local _, control = self:GetLootTargets()
    if not control or not GuiRoot then return false end
    self:CaptureLootOriginal()

    if type(control.SetScale) == "function" then
        pcall(control.SetScale, control, self:GetLootScale())
    end

    if EPC.NativeHUDEditor and EPC.NativeHUDEditor.IsESOPositionOwner
        and EPC.NativeHUDEditor:IsESOPositionOwner(control) then
        return true
    end

    local x, y = self:GetLootOffset()
    if x ~= nil and y ~= nil and type(control.ClearAnchors) == "function" and type(control.SetAnchor) == "function" then
        pcall(control.ClearAnchors, control)
        pcall(control.SetAnchor, control, BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, x, y)
    end
    return true
end

function H:SaveLootPosition()
    local _, control = self:GetLootTargets()
    if not control or not EPC.saved or not GuiRoot then return end

    local right = tonumber(safeMethod(control, "GetRight", nil))
    local bottom = tonumber(safeMethod(control, "GetBottom", nil))
    local rootRight = tonumber(safeMethod(GuiRoot, "GetRight", nil))
    local rootBottom = tonumber(safeMethod(GuiRoot, "GetBottom", nil))
    if right and bottom and rootRight and rootBottom then
        EPC.saved.nativeLootHistoryOffsetX029708 = right - rootRight
        EPC.saved.nativeLootHistoryOffsetY029708 = bottom - rootBottom
    end
    EPC.saved.nativeLootHistoryScale029708 = self:GetLootScale()
end

function H:SetLootScale(scale)
    if not EPC.saved then return end
    EPC.saved.nativeLootHistoryScale029708 = clamp(scale, LOOT_MIN_SCALE, LOOT_MAX_SCALE)
    self:ApplyLootSaved()
end

function H:ResizeLootByWheel(delta)
    if not self.layoutMode or not EPC.saved then return end
    local current = self:GetLootScale()
    local step = tonumber(delta) and delta > 0 and 0.05 or -0.05
    self:SetLootScale(current + step)
end

function H:EnsureNativeLootPreview()
    if not self.layoutMode then return end
    local object, control = self:GetLootTargets()
    if not object or not control then return end

    -- Keep the REAL ESO Loot History control visible while editing. The preview
    -- line is inserted into ESO's own fading loot stream; no Suite overlay/window
    -- is created.
    if type(control.SetHidden) == "function" then pcall(control.SetHidden, control, false) end
    if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 1) end

    local stamp = nowMs()
    if stamp > 0 and stamp - (tonumber(self.lastLootPreviewMs) or 0) < 4000 then return end
    self.lastLootPreviewMs = stamp

    if type(object.DisplayLootQueue) == "function" then pcall(object.DisplayLootQueue, object) end
    if object.lootStream and type(object.lootStream.Resume) == "function" then pcall(object.lootStream.Resume, object.lootStream) end
    if object.lootStreamPersistent and type(object.lootStreamPersistent.Resume) == "function" then
        pcall(object.lootStreamPersistent.Resume, object.lootStreamPersistent)
    end

    if type(object.CreateLootEntry) == "function" and type(object.AddLootEntry) == "function" then
        local color = rawget(_G, "ZO_SELECTED_TEXT")
        if not color and type(rawget(_G, "ZO_ColorDef")) == "table" and type(ZO_ColorDef.New) == "function" then
            color = ZO_ColorDef:New(1, 1, 1, 1)
        end
        if color then
            local data = {
                text = "ESO LOOT / XP HISTORY  -  drag to move  -  mouse wheel resizes",
                icon = rawget(_G, "LOOT_EXPERIENCE_ICON") or "EsoUI/Art/Icons/icon_experience.dds",
                stackCount = 1,
                color = color,
                entryType = rawget(_G, "LOOT_ENTRY_TYPE_MEDAL") or rawget(_G, "LOOT_ENTRY_TYPE_EXPERIENCE"),
                iconOverlayText = function() return "" end,
                showIconOverlayText = false,
            }
            local ok, entry = pcall(object.CreateLootEntry, object, data)
            if ok and entry then
                entry.isPersistent = true
                pcall(object.AddLootEntry, object, entry)
            end
        end
    end
end

function H:BindLootNativeControl()
    local _, control, persistent, normal = self:GetLootTargets()
    if not control then return false end
    self:CaptureLootOriginal()

    if self.lootBindings then return true end
    self.lootBindings = {
        controls = {},
    }

    local function bind(target)
        if not target then return end
        local saved = {
            control = target,
            onMouseDown = getHandler(target, "OnMouseDown"),
            onMouseUp = getHandler(target, "OnMouseUp"),
            onMouseWheel = getHandler(target, "OnMouseWheel"),
            mouseEnabled = safeMethod(target, "IsMouseEnabled", false) == true,
        }
        self.lootBindings.controls[#self.lootBindings.controls + 1] = saved

        if type(target.SetMouseEnabled) == "function" then pcall(target.SetMouseEnabled, target, true) end
        setHandler(target, "OnMouseDown", function(_, button)
            if not H.layoutMode or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            if type(control.SetMovable) == "function" then pcall(control.SetMovable, control, true) end
            if type(control.StartMoving) == "function" then pcall(control.StartMoving, control) end
        end)
        setHandler(target, "OnMouseUp", function(_, button)
            if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            if type(control.StopMovingOrResizing) == "function" then pcall(control.StopMovingOrResizing, control) end
            if type(control.SetMovable) == "function" then pcall(control.SetMovable, control, false) end
            H:SaveLootPosition()
        end)
        setHandler(target, "OnMouseWheel", function(_, delta)
            H:ResizeLootByWheel(delta)
        end)
    end

    bind(control)
    bind(persistent)
    bind(normal)

    if type(control.SetClampedToScreen) == "function" then pcall(control.SetClampedToScreen, control, true) end
    return true
end

function H:UnbindLootNativeControl()
    local bindings = self.lootBindings
    if not bindings then return end

    for _, saved in ipairs(bindings.controls or {}) do
        local target = saved.control
        if target then
            setHandler(target, "OnMouseDown", saved.onMouseDown)
            setHandler(target, "OnMouseUp", saved.onMouseUp)
            setHandler(target, "OnMouseWheel", saved.onMouseWheel)
            if type(target.SetMouseEnabled) == "function" then
                pcall(target.SetMouseEnabled, target, saved.mouseEnabled == true)
            end
        end
    end

    local _, control = self:GetLootTargets()
    if control and type(control.SetMovable) == "function" then pcall(control.SetMovable, control, false) end
    self.lootBindings = nil
end

function H:ResetLootHistory()
    if EPC.saved then
        EPC.saved.nativeLootHistoryOffsetX029708 = nil
        EPC.saved.nativeLootHistoryOffsetY029708 = nil
        EPC.saved.nativeLootHistoryScale029708 = 1
    end

    local _, control = self:GetLootTargets()
    if control and self.lootOriginal then
        restoreAnchor(control, self.lootOriginal.anchor)
        if type(control.SetScale) == "function" then
            pcall(control.SetScale, control, self.lootOriginal.scale or 1)
        end
    end
end

-- ============================================================================
-- ESO NATIVE KEYBOARD CHAT
-- ============================================================================

function H:GetChatTargets()
    local system = rawget(_G, "KEYBOARD_CHAT_SYSTEM") or rawget(_G, "CHAT_SYSTEM")
    local container = type(system) == "table" and system.primaryContainer or nil
    local control = container and container.control or rawget(_G, "ZO_ChatWindow")
    if not control then return system, nil, nil end
    return system, container, control
end

function H:CaptureChatOriginal()
    if self.chatOriginal then return end
    local _, _, control = self:GetChatTargets()
    if not control then return end

    local system = rawget(_G, "KEYBOARD_CHAT_SYSTEM") or rawget(_G, "CHAT_SYSTEM")
    local minBar = type(system) == "table" and system.minBar or nil

    self.chatOriginal = {
        anchor = captureAnchor(control),
        width = tonumber(safeMethod(control, "GetWidth", 445)) or 445,
        height = tonumber(safeMethod(control, "GetHeight", 267)) or 267,
        resizeHandleSize = tonumber(safeMethod(control, "GetResizeHandleSize", 8)) or 8,
        minBarAnchor = captureAnchor(minBar),
    }
end

function H:GetChatDock()
    local mode = tostring(EPC.saved and EPC.saved.nativeChatDock029708 or "NATIVE")
    if mode ~= "NATIVE" and mode ~= "FREE" and mode ~= "LEFT" and mode ~= "RIGHT" and mode ~= "TOP" and mode ~= "BOTTOM" then
        mode = "NATIVE"
    end
    return mode
end

function H:GetChatMinBar()
    local system = rawget(_G, "KEYBOARD_CHAT_SYSTEM") or rawget(_G, "CHAT_SYSTEM")
    return type(system) == "table" and system.minBar or nil
end

function H:ResolveMinBarDock029711()
    local dock = self:GetChatDock()
    if dock ~= "FREE" then return dock end

    -- FREE keeps the full native chat window wherever the user placed it.
    -- When minimized, put ESO's own vertical min-bar on the nearest screen
    -- edge so it stays associated with that chat position instead of jumping
    -- back to ESO's hard-coded bottom-left anchor.
    local left, top, width, height = self:GetChatRect()
    local rootW, rootH = rootSize()
    local distances = {
        LEFT = math.abs(left),
        RIGHT = math.abs(rootW - (left + width)),
        TOP = math.abs(top),
        BOTTOM = math.abs(rootH - (top + height)),
    }
    local bestMode, bestDistance = "LEFT", math.huge
    for mode, distance in pairs(distances) do
        if distance < bestDistance then
            bestMode, bestDistance = mode, distance
        end
    end
    return bestMode
end

function H:ApplyChatMinBarDock029711()
    local minBar = self:GetChatMinBar()
    if not minBar or not GuiRoot then return false end

    -- Update 51 registers the keyboard chat min-bar directly with ESO Edit HUD.
    if EPC.NativeHUDEditor and EPC.NativeHUDEditor.IsESOPositionOwner
        and EPC.NativeHUDEditor:IsESOPositionOwner(minBar) then
        return true
    end

    self:CaptureChatOriginal()
    local dock = self:GetChatDock()
    if dock == "NATIVE" then
        if self.chatOriginal and self.chatOriginal.minBarAnchor then
            restoreAnchor(minBar, self.chatOriginal.minBarAnchor)
        end
        return true
    end

    local resolved = self:ResolveMinBarDock029711()
    local left = tonumber(EPC.saved and EPC.saved.nativeChatLeft029708) or 0
    local _, _, width = self:GetChatRect()
    local rootW = rootSize()

    if type(minBar.ClearAnchors) == "function" then pcall(minBar.ClearAnchors, minBar) end
    if type(minBar.SetAnchor) ~= "function" then return false end

    if resolved == "RIGHT" then
        -- ESO's minimized buttons are left-anchored inside a 128px-wide native
        -- control. Offset the native control so the visible icon strip sits
        -- flush to the right edge rather than 128px inward.
        pcall(minBar.SetAnchor, minBar, BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 96, -20)
    elseif resolved == "TOP" then
        local x = clamp(left, 0, math.max(0, rootW - 40))
        pcall(minBar.SetAnchor, minBar, TOPLEFT, GuiRoot, TOPLEFT, x, 0)
    elseif resolved == "BOTTOM" then
        local x = clamp(left, 0, math.max(0, rootW - 40))
        pcall(minBar.SetAnchor, minBar, BOTTOMLEFT, GuiRoot, BOTTOMLEFT, x, -20)
    else
        pcall(minBar.SetAnchor, minBar, BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, -20)
    end
    return true
end

function H:GetChatRect()
    local _, _, control = self:GetChatTargets()
    local rootW, rootH = rootSize()

    local width = tonumber(EPC.saved and EPC.saved.nativeChatWidth029708) or 0
    local height = tonumber(EPC.saved and EPC.saved.nativeChatHeight029708) or 0
    local left = EPC.saved and tonumber(EPC.saved.nativeChatLeft029708)
    local top = EPC.saved and tonumber(EPC.saved.nativeChatTop029708)

    if width <= 0 then width = tonumber(safeMethod(control, "GetWidth", 445)) or 445 end
    if height <= 0 then height = tonumber(safeMethod(control, "GetHeight", 267)) or 267 end
    if left == nil then left = tonumber(safeMethod(control, "GetLeft", 0)) or 0 end
    if top == nil then top = tonumber(safeMethod(control, "GetTop", rootH - height - 82)) or (rootH - height - 82) end

    width = clamp(width, CHAT_MIN_W, math.min(CHAT_MAX_W, rootW))
    height = clamp(height, CHAT_MIN_H, math.min(CHAT_MAX_H, rootH))

    local dock = self:GetChatDock()
    if dock == "LEFT" then
        left = 0
    elseif dock == "RIGHT" then
        left = rootW - width
    elseif dock == "TOP" then
        top = 0
    elseif dock == "BOTTOM" then
        top = rootH - height
    end

    left = clamp(left, 0, math.max(0, rootW - width))
    top = clamp(top, 0, math.max(0, rootH - height))
    return left, top, width, height, dock
end

function H:ApplyChatSaved()
    local _, container, control = self:GetChatTargets()
    if not control or not GuiRoot then return false end
    self:CaptureChatOriginal()

    local dock = self:GetChatDock()
    local customWidth = tonumber(EPC.saved and EPC.saved.nativeChatWidth029708) or 0
    local customHeight = tonumber(EPC.saved and EPC.saved.nativeChatHeight029708) or 0
    local customLeft = EPC.saved and tonumber(EPC.saved.nativeChatLeft029708)
    local customTop = EPC.saved and tonumber(EPC.saved.nativeChatTop029708)

    if dock == "NATIVE" and customWidth <= 0 and customHeight <= 0 and customLeft == nil and customTop == nil then
        return true
    end

    local left, top, width, height = self:GetChatRect()
    if type(control.SetDimensions) == "function" then pcall(control.SetDimensions, control, width, height) end
    if type(control.ClearAnchors) == "function" then pcall(control.ClearAnchors, control) end
    if type(control.SetAnchor) == "function" then pcall(control.SetAnchor, control, TOPLEFT, GuiRoot, TOPLEFT, left, top) end

    if container and type(container.PerformLayout) == "function" then pcall(container.PerformLayout, container) end
    self:ApplyChatMinBarDock029711()
    return true
end

function H:SaveChatFromNative(autoDock)
    local _, container, control = self:GetChatTargets()
    if not control or not EPC.saved then return end

    local rootW, rootH = rootSize()
    local left = tonumber(safeMethod(control, "GetLeft", 0)) or 0
    local top = tonumber(safeMethod(control, "GetTop", 0)) or 0
    local width = clamp(safeMethod(control, "GetWidth", 445), CHAT_MIN_W, math.min(CHAT_MAX_W, rootW))
    local height = clamp(safeMethod(control, "GetHeight", 267), CHAT_MIN_H, math.min(CHAT_MAX_H, rootH))

    local dock = self:GetChatDock()
    if autoDock then
        local distances = {
            LEFT = math.abs(left),
            RIGHT = math.abs(rootW - (left + width)),
            TOP = math.abs(top),
            BOTTOM = math.abs(rootH - (top + height)),
        }
        local bestMode, bestDistance = "FREE", CHAT_EDGE_SNAP + 1
        for mode, distance in pairs(distances) do
            if distance < bestDistance then
                bestMode, bestDistance = mode, distance
            end
        end
        dock = bestDistance <= CHAT_EDGE_SNAP and bestMode or "FREE"
    elseif dock == "NATIVE" then
        dock = "FREE"
    end

    EPC.saved.nativeChatDock029708 = dock
    EPC.saved.nativeChatLeft029708 = left
    EPC.saved.nativeChatTop029708 = top
    EPC.saved.nativeChatWidth029708 = width
    EPC.saved.nativeChatHeight029708 = height

    if container and type(container.PerformLayout) == "function" then pcall(container.PerformLayout, container) end
    self:ApplyChatSaved()
end

function H:SetChatDock(mode)
    if not EPC.saved then return end
    mode = tostring(mode or "NATIVE")
    if mode ~= "NATIVE" and mode ~= "FREE" and mode ~= "LEFT" and mode ~= "RIGHT" and mode ~= "TOP" and mode ~= "BOTTOM" then
        mode = "NATIVE"
    end

    if mode == "NATIVE" then
        self:ResetChat()
        return
    end

    local left, top, width, height = self:GetChatRect()
    EPC.saved.nativeChatDock029708 = mode
    EPC.saved.nativeChatLeft029708 = left
    EPC.saved.nativeChatTop029708 = top
    EPC.saved.nativeChatWidth029708 = width
    EPC.saved.nativeChatHeight029708 = height
    self:ApplyChatSaved()
end

function H:SetChatSize(width, height)
    if not EPC.saved then return end
    local left, top, currentW, currentH = self:GetChatRect()
    EPC.saved.nativeChatLeft029708 = left
    EPC.saved.nativeChatTop029708 = top
    EPC.saved.nativeChatWidth029708 = clamp(width or currentW, CHAT_MIN_W, CHAT_MAX_W)
    EPC.saved.nativeChatHeight029708 = clamp(height or currentH, CHAT_MIN_H, CHAT_MAX_H)
    if self:GetChatDock() == "NATIVE" then EPC.saved.nativeChatDock029708 = "FREE" end
    self:ApplyChatSaved()
end

function H:BindChatNativeControl()
    local system, container, control = self:GetChatTargets()
    if not control then return false end
    self:CaptureChatOriginal()
    if self.chatBindings then return true end

    if system and type(system.IsMinimized) == "function" and type(system.Maximize) == "function" then
        local ok, minimized = pcall(system.IsMinimized, system)
        if ok and minimized then pcall(system.Maximize, system) end
    end

    if container and type(container.FadeIn) == "function" then pcall(container.FadeIn, container, 0) end
    if type(control.SetHidden) == "function" then pcall(control.SetHidden, control, false) end
    if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 1) end
    if type(control.SetMouseEnabled) == "function" then pcall(control.SetMouseEnabled, control, true) end
    if type(control.SetResizeHandleSize) == "function" then pcall(control.SetResizeHandleSize, control, 14) end

    local firstTab = container and container.windows and container.windows[1] and container.windows[1].tab or nil
    self.chatBindings = {
        firstTab = firstTab,
        firstTabDrag = getHandler(firstTab, "OnDragStart"),
        firstTabUp = getHandler(firstTab, "OnMouseUp"),
        resizeStop = getHandler(control, "OnResizeStop"),
        resizeStart = getHandler(control, "OnResizeStart"),
    }

    if firstTab then
        setHandler(firstTab, "OnDragStart", function(_, button)
            if not H.layoutMode or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            if type(control.SetMovable) == "function" then pcall(control.SetMovable, control, true) end
            if type(control.StartMoving) == "function" then pcall(control.StartMoving, control) end
            H.chatDragging = true
            if container and type(container.FadeIn) == "function" then pcall(container.FadeIn, container, 0) end
        end)

        setHandler(firstTab, "OnMouseUp", function(tab, button, upInside)
            if H.chatDragging and button == MOUSE_BUTTON_INDEX_LEFT then
                if type(control.StopMovingOrResizing) == "function" then pcall(control.StopMovingOrResizing, control) end
                if type(control.SetMovable) == "function" then pcall(control.SetMovable, control, false) end
                H.chatDragging = false
                H:SaveChatFromNative(true)
                return
            end

            local original = H.chatBindings and H.chatBindings.firstTabUp
            if original then pcall(original, tab, button, upInside) end
        end)
    end

    local originalResizeStart = self.chatBindings.resizeStart
    setHandler(control, "OnResizeStart", function(c, ...)
        if originalResizeStart then pcall(originalResizeStart, c, ...) end
        if container and type(container.FadeIn) == "function" then pcall(container.FadeIn, container, 0) end
    end)

    local originalResizeStop = self.chatBindings.resizeStop
    setHandler(control, "OnResizeStop", function(c, ...)
        if originalResizeStop then pcall(originalResizeStop, c, ...) end
        H:SaveChatFromNative(false)
    end)

    return true
end

function H:UnbindChatNativeControl()
    local bindings = self.chatBindings
    if not bindings then return end
    local _, container, control = self:GetChatTargets()

    if bindings.firstTab then
        setHandler(bindings.firstTab, "OnDragStart", bindings.firstTabDrag)
        setHandler(bindings.firstTab, "OnMouseUp", bindings.firstTabUp)
    end
    if control then
        setHandler(control, "OnResizeStart", bindings.resizeStart)
        setHandler(control, "OnResizeStop", bindings.resizeStop)
        if type(control.SetMovable) == "function" then pcall(control.SetMovable, control, false) end
        if type(control.SetResizeHandleSize) == "function" then
            pcall(control.SetResizeHandleSize, control, self.chatOriginal and self.chatOriginal.resizeHandleSize or 8)
        end
    end
    if container and type(container.PerformLayout) == "function" then pcall(container.PerformLayout, container) end

    self.chatBindings = nil
    self.chatDragging = false
end

function H:GetAnimationDock029712()
    local dock = self:GetChatDock()
    if dock ~= "FREE" then return dock end

    local left, top, width, height = self:GetChatRect()
    local rootW, rootH = rootSize()
    local distances = {
        LEFT = math.abs(left),
        RIGHT = math.abs(rootW - (left + width)),
        TOP = math.abs(top),
        BOTTOM = math.abs(rootH - (top + height)),
    }
    local bestMode, bestDistance = "LEFT", math.huge
    for mode, distance in pairs(distances) do
        if distance < bestDistance then
            bestMode, bestDistance = mode, distance
        end
    end
    return bestMode
end

function H:GetOrCreateDockTimeline029712(container)
    if not container or not container.control or not ANIMATION_MANAGER then return nil end
    if container.easDockTimeline029712 then return container.easDockTimeline029712 end

    local timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ChatMinMaxAnim", container.control)
    if not timeline then return nil end

    timeline:SetHandler("OnPlay", function()
        if type(container.SetMinimizingOrMaximizing) == "function" then
            pcall(container.SetMinimizingOrMaximizing, container, true)
        end
        if type(container.control.SetClampedToScreen) == "function" then
            pcall(container.control.SetClampedToScreen, container.control, false)
        end
    end)

    timeline:SetHandler("OnStop", function()
        if type(container.SetMinimizingOrMaximizing) == "function" then
            pcall(container.SetMinimizingOrMaximizing, container, false)
        end
        if container.easAnimatingToMinimized029712 ~= true and type(container.control.SetClampedToScreen) == "function" then
            pcall(container.control.SetClampedToScreen, container.control, true)
        end
    end)

    container.easDockTimeline029712 = timeline
    return timeline
end

function H:NativeDockMinimize029712(system)
    if not system or system.isMinimized then return end
    local dock = self:GetAnimationDock029712()
    local rootW, rootH = rootSize()

    for _, container in pairs(system.containers or {}) do
        local control = container and container.control
        if control then
            local timeline = self:GetOrCreateDockTimeline029712(container)
            if timeline then
                if timeline.IsPlaying and timeline:IsPlaying() and timeline.Stop then
                    pcall(timeline.Stop, timeline)
                end

                container.easOriginalLeft029712 = tonumber(safeMethod(control, "GetLeft", 0)) or 0
                container.easOriginalTop029712 = tonumber(safeMethod(control, "GetTop", 0)) or 0
                container.easAnimatingToMinimized029712 = true

                local left = tonumber(safeMethod(control, "GetLeft", 0)) or 0
                local right = tonumber(safeMethod(control, "GetRight", left)) or left
                local top = tonumber(safeMethod(control, "GetTop", 0)) or 0
                local bottom = tonumber(safeMethod(control, "GetBottom", top)) or top
                local dx, dy = 0, 0

                if dock == "RIGHT" then
                    dx = (rootW - left) + 40
                elseif dock == "TOP" then
                    dy = -(bottom + 40)
                elseif dock == "BOTTOM" then
                    dy = (rootH - top) + 40
                else
                    dx = -(right + 40)
                end

                local animation = timeline.GetAnimation and timeline:GetAnimation(1) or nil
                if animation and type(animation.SetTranslateDeltas) == "function" then
                    pcall(animation.SetTranslateDeltas, animation, dx, dy)
                    pcall(timeline.PlayFromStart, timeline)
                end
            end

            local group = container.tabGroup and container.tabGroup.m_Buttons
            if type(group) == "table" then
                for _, tab in pairs(group) do
                    if tab and type(tab.SetHidden) == "function" then pcall(tab.SetHidden, tab, true) end
                end
            end
            if container.overflowTab and type(container.overflowTab.SetHidden) == "function" then
                pcall(container.overflowTab.SetHidden, container.overflowTab, true)
            end
            if container.newWindowTab and type(container.newWindowTab.SetHidden) == "function" then
                pcall(container.newWindowTab.SetHidden, container.newWindowTab, true)
            end
        end
    end

    if SOUNDS and SOUNDS.CHAT_MINIMIZED and type(PlaySound) == "function" then
        pcall(PlaySound, SOUNDS.CHAT_MINIMIZED)
    end
    if type(system.ShowMinBar) == "function" then
        pcall(system.ShowMinBar, system)
    end
    self:ApplyChatMinBarDock029711()
end

function H:NativeDockMaximize029712(system)
    if not system or not system.isMinimized then return end

    for _, container in pairs(system.containers or {}) do
        local control = container and container.control
        if control then
            local originalLeft = tonumber(container.easOriginalLeft029712)
            local originalTop = tonumber(container.easOriginalTop029712)
            if originalLeft ~= nil and originalTop ~= nil then
                local timeline = self:GetOrCreateDockTimeline029712(container)
                if timeline then
                    if timeline.IsPlaying and timeline:IsPlaying() and timeline.Stop then
                        pcall(timeline.Stop, timeline)
                    end

                    local currentLeft = tonumber(safeMethod(control, "GetLeft", originalLeft)) or originalLeft
                    local currentTop = tonumber(safeMethod(control, "GetTop", originalTop)) or originalTop
                    local animation = timeline.GetAnimation and timeline:GetAnimation(1) or nil
                    if animation and type(animation.SetTranslateDeltas) == "function" then
                        container.easAnimatingToMinimized029712 = false
                        pcall(animation.SetTranslateDeltas, animation, originalLeft - currentLeft, originalTop - currentTop)
                        pcall(timeline.PlayFromStart, timeline)
                    end
                end
            end

            local group = container.tabGroup and container.tabGroup.m_Buttons
            if type(group) == "table" then
                for _, tab in pairs(group) do
                    if tab and type(tab.SetHidden) == "function" then
                        local show = tab.index == nil or container.hiddenTabStartIndex == nil or tab.index < container.hiddenTabStartIndex
                        pcall(tab.SetHidden, tab, not show)
                    end
                end
            end
            if container.overflowTab and type(container.overflowTab.SetHidden) == "function" then
                pcall(container.overflowTab.SetHidden, container.overflowTab, false)
            end
            if container.newWindowTab and type(container.newWindowTab.SetHidden) == "function" then
                pcall(container.newWindowTab.SetHidden, container.newWindowTab, false)
            end
            if type(container.FadeIn) == "function" then pcall(container.FadeIn, container, 0) end
        end
    end

    if SOUNDS and SOUNDS.CHAT_MAXIMIZED and type(PlaySound) == "function" then
        pcall(PlaySound, SOUNDS.CHAT_MAXIMIZED)
    end
    if type(system.HideMinBar) == "function" then
        pcall(system.HideMinBar, system)
    end

    if system.newChatFadeAnim and type(system.newChatFadeAnim.IsPlaying) == "function"
        and system.newChatFadeAnim:IsPlaying() then
        pcall(system.newChatFadeAnim.Stop, system.newChatFadeAnim)
        if system.minBar and system.minBar.bgHighlight and type(system.minBar.bgHighlight.SetAlpha) == "function" then
            pcall(system.minBar.bgHighlight.SetAlpha, system.minBar.bgHighlight, 0)
        end
    end
end

function H:GetChatMinimizedState029739()
    local system = rawget(_G, "KEYBOARD_CHAT_SYSTEM") or rawget(_G, "CHAT_SYSTEM")
    if type(system) ~= "table" then return nil end
    if type(system.IsMinimized) == "function" then
        local ok,value = pcall(system.IsMinimized,system)
        if ok then return value == true end
    end
    if system.isMinimized ~= nil then return system.isMinimized == true end
    return nil
end

function H:SaveChatOpenState029739()
    if not EPC.saved then return end
    local minimized = self:GetChatMinimizedState029739()
    if minimized ~= nil then
        EPC.saved.nativeChatMinimized029739 = minimized
    end
end

function H:RestoreChatOpenState029739(serial)
    if not EPC.saved then return end
    local wanted = EPC.saved.nativeChatMinimized029739
    if type(wanted) ~= "boolean" then return end
    if serial ~= nil and serial ~= self.chatStateSerial029739 then return end

    local system = rawget(_G, "KEYBOARD_CHAT_SYSTEM") or rawget(_G, "CHAT_SYSTEM")
    if type(system) ~= "table" then return end
    local current = self:GetChatMinimizedState029739()
    if current == nil or current == wanted then return end

    self.restoringChatState029739 = true
    if wanted and type(system.Minimize) == "function" then
        pcall(system.Minimize,system)
    elseif not wanted and type(system.Maximize) == "function" then
        pcall(system.Maximize,system)
    end
    self.restoringChatState029739 = false
end

function H:InstallNativeChatDockAnimation029712()
    local system = rawget(_G, "KEYBOARD_CHAT_SYSTEM") or rawget(_G, "CHAT_SYSTEM")
    if type(system) ~= "table" or system._easDockAnimationInstalled029712 then return false end
    if type(system.Minimize) ~= "function" or type(system.Maximize) ~= "function" then return false end

    system._easDockAnimationInstalled029712 = true
    system._easOriginalMinimize029712 = system.Minimize
    system._easOriginalMaximize029712 = system.Maximize

    system.Minimize = function(chatSystem, ...)
        if not H.restoringChatState029739 then
            H.chatStateSerial029739 = (tonumber(H.chatStateSerial029739) or 0) + 1
            if EPC.saved then EPC.saved.nativeChatMinimized029739 = true end
        end
        if H:GetChatDock() == "NATIVE" then
            return chatSystem._easOriginalMinimize029712(chatSystem, ...)
        end
        return H:NativeDockMinimize029712(chatSystem)
    end

    system.Maximize = function(chatSystem, ...)
        if not H.restoringChatState029739 then
            H.chatStateSerial029739 = (tonumber(H.chatStateSerial029739) or 0) + 1
            if EPC.saved then EPC.saved.nativeChatMinimized029739 = false end
        end
        if H:GetChatDock() == "NATIVE" then
            return chatSystem._easOriginalMaximize029712(chatSystem, ...)
        end
        return H:NativeDockMaximize029712(chatSystem)
    end
    return true
end

function H:ResetChat()
    if EPC.saved then
        EPC.saved.nativeChatDock029708 = "NATIVE"
        EPC.saved.nativeChatLeft029708 = nil
        EPC.saved.nativeChatTop029708 = nil
        EPC.saved.nativeChatWidth029708 = 0
        EPC.saved.nativeChatHeight029708 = 0
    end

    local _, container, control = self:GetChatTargets()
    if control and self.chatOriginal then
        if type(control.SetDimensions) == "function" then
            pcall(control.SetDimensions, control, self.chatOriginal.width or 445, self.chatOriginal.height or 267)
        end
        restoreAnchor(control, self.chatOriginal.anchor)
    end
    local minBar = self:GetChatMinBar()
    if minBar and self.chatOriginal and self.chatOriginal.minBarAnchor then
        restoreAnchor(minBar, self.chatOriginal.minBarAnchor)
    end
    if container and type(container.PerformLayout) == "function" then pcall(container.PerformLayout, container) end
end

-- ============================================================================
-- SHARED HUD LAYOUT INTEGRATION
-- ============================================================================

function H:ApplyAll()
    self:ApplyLootSaved()
    self:ApplyChatSaved()
end

function H:SetLayoutMode(active)
    active = active == true
    self.layoutMode = active

    if active then
        self:ApplyAll()
        self:BindLootNativeControl()
        self:BindChatNativeControl()
        self.lastLootPreviewMs = 0
        self:EnsureNativeLootPreview()
    else
        self:UnbindLootNativeControl()
        self:UnbindChatNativeControl()
        -- Drag/resize handlers save immediately when the user changes a native
        -- control. Exiting layout without edits must not convert ESO Default
        -- chat placement into a custom Suite placement.
        self:ApplyAll()
    end
end

function H:RaiseForLayout()
    if not self.layoutMode then return end

    -- Keep the REAL ESO controls exposed while the Suite's global HUD layout
    -- mode is active. No proxy/edit overlay is involved.
    local _, lootControl = self:GetLootTargets()
    if lootControl then
        if type(lootControl.SetHidden) == "function" then pcall(lootControl.SetHidden, lootControl, false) end
        if type(lootControl.SetAlpha) == "function" then pcall(lootControl.SetAlpha, lootControl, 1) end
        self:EnsureNativeLootPreview()
    end

    local _, chatContainer, chatControl = self:GetChatTargets()
    if chatControl then
        if type(chatControl.SetHidden) == "function" then pcall(chatControl.SetHidden, chatControl, false) end
        if type(chatControl.SetAlpha) == "function" then pcall(chatControl.SetAlpha, chatControl, 1) end
        if chatContainer and type(chatContainer.FadeIn) == "function" then pcall(chatContainer.FadeIn, chatContainer, 0) end
    end
end

function H:FocusNativeLayout029710(which)
    if EPC and EPC.SetUnitFramesMoveMode then
        EPC:SetUnitFramesMoveMode(true)
    else
        self:SetLayoutMode(true)
    end

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if not H.layoutMode then H:SetLayoutMode(true) end
            if which == "LOOT" then
                H:EnsureNativeLootPreview()
            else
                local _, container, control = H:GetChatTargets()
                if container and type(container.FadeIn) == "function" then pcall(container.FadeIn, container, 0) end
                if control and type(control.SetHidden) == "function" then pcall(control.SetHidden, control, false) end
            end
        end, 180)
    end
end

-- Compatibility with the 0.29.709 settings callback name.
function H:FocusLayoutPreview029709(which)
    return self:FocusNativeLayout029710(which)
end

function H:ResetPositions()
    self:ResetLootHistory()
    self:ResetChat()
end

if EVENT_PLAYER_ACTIVATED ~= nil then
    EM:RegisterForEvent(H.name .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        H:CaptureLootOriginal()
        H:CaptureChatOriginal()
        H:InstallNativeChatDockAnimation029712()
        H:ApplyAll()

        local serial = tonumber(H.chatStateSerial029739) or 0
        if type(zo_callLater) == "function" then
            zo_callLater(function()
                H:ApplyAll()
                H:RestoreChatOpenState029739(serial)
            end, 120)
            zo_callLater(function()
                H:ApplyAll()
                H:RestoreChatOpenState029739(serial)
            end, 500)
        else
            H:RestoreChatOpenState029739(serial)
        end
    end)
end

if rawget(_G,"EVENT_PLAYER_DEACTIVATED") ~= nil then
    EM:RegisterForEvent(H.name .. "_Deactivated029739", EVENT_PLAYER_DEACTIVATED, function()
        H:SaveChatOpenState029739()
    end)
end

if EVENT_SCREEN_RESIZED ~= nil then
    EM:RegisterForEvent(H.name .. "_ScreenResized", EVENT_SCREEN_RESIZED, function()
        H:ApplyAll()
    end)
end

local function installChatShowHook()
    local system, _, control = H:GetChatTargets()
    if not control or control._easNativeOnlyLayout029710 then return end
    control._easNativeOnlyLayout029710 = true
    if type(ZO_PostHookHandler) == "function" then
        pcall(ZO_PostHookHandler, control, "OnShow", function()
            if H.layoutMode then
                local _, container = H:GetChatTargets()
                if container and type(container.FadeIn) == "function" then pcall(container.FadeIn, container, 0) end
            else
                if type(zo_callLater) == "function" then
                    zo_callLater(function() H:ApplyChatSaved() end, 1)
                else
                    H:ApplyChatSaved()
                end
            end
        end)
    end

    -- ESO's ShowMinBar() itself always uses the XML's bottom-left native anchor.
    -- Post-hook only the anchor so mail/friends/notifications/maximize remain
    -- 100% ESO-native while following the user's chosen chat dock.
    if system and not system._easMinBarDockHook029711 and type(ZO_PostHook) == "function" then
        system._easMinBarDockHook029711 = true
        pcall(ZO_PostHook, system, "ShowMinBar", function()
            H:ApplyChatMinBarDock029711()
        end)
    end

    H:InstallNativeChatDockAnimation029712()
end

if type(SLASH_COMMANDS) == "table" then
    SLASH_COMMANDS["/easnativehud"] = function()
        H:FocusNativeLayout029710("LOOT")
    end
end

H:CaptureLootOriginal()
H:CaptureChatOriginal()
H:ApplyAll()
installChatShowHook()

if type(zo_callLater) == "function" then
    zo_callLater(function()
        installChatShowHook()
        H:ApplyAll()
        H:RestoreChatOpenState029739(tonumber(H.chatStateSerial029739) or 0)
    end, 350)
    zo_callLater(function()
        installChatShowHook()
        H:ApplyAll()
        H:RestoreChatOpenState029739(tonumber(H.chatStateSerial029739) or 0)
    end, 1200)
end


-- BEGIN ABSORBED: ChatPriorityFix.lua
-- ESO Adventurer Suite
-- v0.29.720 - native chat keeps mouse cursor access while text entry is open.
-- Uses a background child inside ESO's chat window instead of a competing
-- top-level blocker. Chat stays above HUD overlays while ESO menus stay native.

local EPC = ESOProgressionCoach
if not EPC then return end

local CHAT_ROOT_NAME = "ZO_ChatWindow"
local CHAT_EDIT_NAME = "ZO_ChatWindowTextEntryEditBox"
local BACKDROP_NAME = "EAS_ChatOpaqueBackdrop029496"
local CHAT_LEVEL = 139 -- ESO native keyboard dropdown menus use HIGH tier level 140.

local state = {
    raised = false,
    originalTier = nil,
    originalLayer = nil,
    originalLevel = nil,
    backdrop = nil,
}

local function GetControl(name)
    return rawget(_G, name)
end

local function CaptureDrawState(control)
    if not control then return end
    if state.originalTier == nil and control.GetDrawTier then
        local ok, value = pcall(control.GetDrawTier, control)
        if ok then state.originalTier = value end
    end
    if state.originalLayer == nil and control.GetDrawLayer then
        local ok, value = pcall(control.GetDrawLayer, control)
        if ok then state.originalLayer = value end
    end
    if state.originalLevel == nil and control.GetDrawLevel then
        local ok, value = pcall(control.GetDrawLevel, control)
        if ok then state.originalLevel = value end
    end
end

local function EnsureOpaqueBackdrop029496(chat)
    if state.backdrop then return state.backdrop end
    if not chat or not WINDOW_MANAGER then return nil end

    -- Make the opaque surface a CHILD of the native chat window. This keeps it
    -- inside chat's draw hierarchy, so it can never cover ESO's separate
    -- HIGH-tier ZO_Menus slash-command dropdown.
    local backdrop = WINDOW_MANAGER:CreateControl(BACKDROP_NAME, chat, CT_BACKDROP)
    backdrop:SetMouseEnabled(false)
    backdrop:ClearAnchors()
    backdrop:SetAnchor(TOPLEFT, chat, TOPLEFT, -8, -6)
    backdrop:SetAnchor(BOTTOMRIGHT, chat, BOTTOMRIGHT, 4, 4)

    if backdrop.SetDrawLayer and rawget(_G, "DL_BACKGROUND") then
        pcall(backdrop.SetDrawLayer, backdrop, DL_BACKGROUND)
    end
    if backdrop.SetDrawLevel then
        pcall(backdrop.SetDrawLevel, backdrop, 1)
    end

    backdrop:SetCenterColor(0, 0, 0, 1)
    backdrop:SetEdgeColor(0.018, 0.018, 0.024, 1)
    if backdrop.SetEdgeTexture then
        pcall(backdrop.SetEdgeTexture, backdrop, "EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 1)
    end
    backdrop:SetHidden(true)

    state.backdrop = backdrop
    return backdrop
end

local function RaiseChat029496()
    local chat = GetControl(CHAT_ROOT_NAME)
    if not chat then return end

    CaptureDrawState(chat)

    -- Raise only the native chat top-level. Do not touch ZO_Menus, ZO_Menu,
    -- autocomplete objects, or any chat text handlers.
    if chat.SetDrawTier and rawget(_G, "DT_HIGH") then
        pcall(chat.SetDrawTier, chat, DT_HIGH)
    end
    if chat.SetDrawLevel then
        pcall(chat.SetDrawLevel, chat, CHAT_LEVEL)
    end

    local backdrop = EnsureOpaqueBackdrop029496(chat)
    if backdrop then
        backdrop:ClearAnchors()
        backdrop:SetAnchor(TOPLEFT, chat, TOPLEFT, -8, -6)
        backdrop:SetAnchor(BOTTOMRIGHT, chat, BOTTOMRIGHT, 4, 4)
        backdrop:SetHidden(false)
    end

    state.raised = true
end

local function RestoreChat029496()
    if state.backdrop then
        state.backdrop:SetHidden(true)
    end

    local chat = GetControl(CHAT_ROOT_NAME)
    if not state.raised or not chat then
        state.raised = false
        return
    end

    if state.originalTier ~= nil and chat.SetDrawTier then
        pcall(chat.SetDrawTier, chat, state.originalTier)
    end
    if state.originalLayer ~= nil and chat.SetDrawLayer then
        pcall(chat.SetDrawLayer, chat, state.originalLayer)
    end
    if state.originalLevel ~= nil and chat.SetDrawLevel then
        pcall(chat.SetDrawLevel, chat, state.originalLevel)
    end

    state.raised = false
end

local function HookChatEditBox029496()
    local edit = GetControl(CHAT_EDIT_NAME)
    if not edit or edit._easChatOpaque029496 then return false end
    edit._easChatOpaque029496 = true

    -- Additive hooks only. ESO keeps its native OnTextChanged, autocomplete,
    -- slash-command, focus, tab, arrow, enter and escape handlers untouched.
    if type(ZO_PreHookHandler) == "function" then
        ZO_PreHookHandler(edit, "OnFocusGained", function()
            RaiseChat029496()
            return false
        end)
        ZO_PreHookHandler(edit, "OnFocusLost", function()
            RestoreChat029496()
            return false
        end)
    else
        local oldFocusGained = edit.GetHandler and edit:GetHandler("OnFocusGained") or nil
        local oldFocusLost = edit.GetHandler and edit:GetHandler("OnFocusLost") or nil
        if edit.SetHandler then
            edit:SetHandler("OnFocusGained", function(control, ...)
                if oldFocusGained then oldFocusGained(control, ...) end
                RaiseChat029496()
            end)
            edit:SetHandler("OnFocusLost", function(control, ...)
                if oldFocusLost then oldFocusLost(control, ...) end
                RestoreChat029496()
            end)
        end
    end

    if edit.HasFocus then
        local ok, focused = pcall(edit.HasFocus, edit)
        if ok and focused then RaiseChat029496() end
    end

    return true
end

local function Install029496()
    if HookChatEditBox029496() then return end
    if type(zo_callLater) == "function" then
        zo_callLater(HookChatEditBox029496, 250)
        zo_callLater(HookChatEditBox029496, 1000)
    end
end

-- v0.29.720
-- ESO normally decides whether chat should enter cursor/UI mode from the
-- UI_SETTING_RETURN_CURSOR_ON_CHAT_FOCUS setting. The Suite user requested a
-- simpler rule: while keyboard chat text entry is open, keep normal mouse cursor
-- access available. Replace only the two chat lifecycle callbacks and preserve
-- ESO's own chat edit box, channels, slash autocomplete, and message handling.
local function InstallChatCursorAccess029720()
    local manager = rawget(_G, "SCENE_MANAGER")
    if type(manager) ~= "table" or manager._easChatCursorAccess029720 then return false end
    if type(manager.OnChatInputStart) ~= "function" or type(manager.OnChatInputEnd) ~= "function" then return false end
    if type(ZO_PreHook) ~= "function" then return false end

    manager._easChatCursorAccess029720 = true

    pcall(ZO_PreHook, manager, "OnChatInputStart", function(self)
        -- Match ESO's lifecycle, except do not call HideMouse(). Entering HUD UI
        -- mode exposes the native cursor and leaves it usable while typing.
        self.exitUIModeOnChatFocusLost = false
        self._easEnteredUIModeForChat029720 = false

        local cameraActive = type(IsGameCameraActive) ~= "function" or IsGameCameraActive()
        local isInUIMode = type(self.IsInUIMode) == "function" and self:IsInUIMode() or false
        local showingBase = type(self.IsShowingBaseScene) ~= "function" or self:IsShowingBaseScene()

        if cameraActive and not isInUIMode and showingBase and type(self.SetInUIMode) == "function" then
            local ok, changed = pcall(self.SetInUIMode, self, true)
            if ok and changed ~= false then
                if type(self.ShowBaseScene) == "function" then pcall(self.ShowBaseScene, self) end
                self.exitUIModeOnChatFocusLost = true
                self._easEnteredUIModeForChat029720 = true
            end
        end

        -- Returning true suppresses ESO's stock handler, whose chat-focus path
        -- calls HideMouse(ONLY_CONSIDER_MOUSE_VISIBILITY_WHILE_MOVING).
        return true
    end)

    pcall(ZO_PreHook, manager, "OnChatInputEnd", function(self)
        local shouldExit = self._easEnteredUIModeForChat029720 == true
            or self.exitUIModeOnChatFocusLost == true

        self._easEnteredUIModeForChat029720 = false
        self.exitUIModeOnChatFocusLost = false

        if shouldExit and type(self.SafelyAttemptToExitUIMode) == "function" then
            pcall(self.SafelyAttemptToExitUIMode, self)
        end

        -- Suppress ESO's stock end handler too so it does not call ShowMouse()
        -- without a matching HideMouse() from the Suite-managed start path.
        return true
    end)

    return true
end

Install029496()
InstallChatCursorAccess029720()

if type(zo_callLater) == "function" then
    zo_callLater(InstallChatCursorAccess029720, 250)
    zo_callLater(InstallChatCursorAccess029720, 1000)
end

-- END ABSORBED: ChatPriorityFix.lua
