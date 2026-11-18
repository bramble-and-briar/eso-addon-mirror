local OS = OneSettings
local Windows = { elements = {} }
OS.modules.windows = Windows

-- Record only elements registered by the stock HUD before our initialization.
-- Known movers below take precedence; arbitrary external ownership is not exposed by ESO.
if HUD_MANAGER then
    for _, mode in ipairs({ "keyboardElements", "gamepadElements" }) do
        for control, element in pairs(HUD_MANAGER[mode] or {}) do
            local name = control:GetName()
            if name and name:match("^ZO_") then
                Windows.elements[mode .. ":" .. name] = element
            end
        end
    end
end

function Windows:Blocked(kind)
    local states = OS.modules.addons.loadedStates.states
    -- OneChat adjusts resize constraints but leaves stock geometry persistence intact.
    if kind == "chat" then return states.pChat or states.rChat end
    if kind == "map" then return states.OneMap or states.VotansMiniMap end
    if kind == "performance" then return states.Azurah or states.BanditsUserInterface or states.LUIE or states.AUI end
    -- These managers can move or replace multiple HUD controls.
    return states.OneFrame or states.Azurah or states.BanditsUserInterface or states.LUIE or states.AUI
end

function Windows:Capture(localOnly)
    local captureChat = not self:Blocked("chat") and KEYBOARD_CHAT_SYSTEM and self:ChatReady()
    local oneChat = captureChat and self:CaptureOneChat()
    local result = { hud = {}, chat = {} }
    -- Skip old chat tables that this capture replaces, including potentially large tab lists.
    for key, value in pairs(not localOnly and OS.account.shared.windows or {}) do
        if not (captureChat and (key == "chat" or key == "chatLayout" or (key == "oneChat" and oneChat))) then
            result[key] = OS.Copy(value)
        end
    end
    local width, height = GuiRoot:GetDimensions()
    if not self:Blocked("hud") then
        for key, element in pairs(self.elements) do
            if element:IsValid() and element.control.hudElementRef then
                local _, x, y = element:GetConvertedRefControlAnchorInfo()
                result.hud[key] = { x = x / width, y = y / height }
            end
        end
    end
    if captureChat then
        result.chatLayout = self:CaptureChatLayout()
        result.oneChat = oneChat or result.oneChat
        for _, container in ipairs(KEYBOARD_CHAT_SYSTEM.containers or {}) do
            local control = container.control
            -- Prefer persisted geometry: minimized chat can temporarily be off-screen.
            local saved = container.settings
            local valid, point, relative, relativePoint, x, y = control:GetAnchor(0)
            local w, h = control:GetDimensions()
            if saved and saved.point and saved.relPoint and saved.x and saved.y and saved.width and saved.height then
                valid, point, relative, relativePoint, x, y = true, saved.point, GuiRoot, saved.relPoint, saved.x, saved.y
                w, h = saved.width, saved.height
            end
            if valid and (relative == GuiRoot or relative == nil) then
                result.chat[container.id] = { point = point, relativePoint = relativePoint,
                    x = x / width, y = y / height, width = w / width, height = h / height }
            end
        end
    end
    if not self:Blocked("performance") and PERFORMANCE_METERS and PERFORMANCE_METERS.control then
        local control = PERFORMANCE_METERS.control
        local valid, point, relative, relativePoint, x, y = control:GetAnchor(0)
        if valid and (relative == GuiRoot or relative == nil) then
            result.performance = { point = point, relativePoint = relativePoint, x = x / width, y = y / height }
        end
    end
    if not self:Blocked("map") and WORLD_MAP_MANAGER and WORLD_MAP_MANAGER:IsInMode(MAP_MODE_SMALL_CUSTOM) then
        local data = WORLD_MAP_MANAGER:GetModeData()
        result.map = { point = data.point, relPoint = data.relPoint, x = data.x / width, y = data.y / height,
            width = data.width / width, height = data.height / height }
    end
    return result
end

function Windows:ApplyMap(shared)
    if not shared.map or self:Blocked("map") or not WORLD_MAP_MANAGER:IsInMode(MAP_MODE_SMALL_CUSTOM) then return end
    local width, height = GuiRoot:GetDimensions()
    local data, saved = WORLD_MAP_MANAGER:GetModeData(), shared.map
    data.point, data.relPoint = saved.point, saved.relPoint
    data.x, data.y = saved.x * width, saved.y * height
    data.width, data.height = math.min(saved.width * width, width), math.min(saved.height * height, height)
    -- ResizeAndReanchorMap derives size from the live control and would overwrite
    -- the requested dimensions. SetToMode consumes modeData and restores its anchor.
    WORLD_MAP_MANAGER:SetToMode(MAP_MODE_SMALL_CUSTOM)
end

function Windows:Apply(shared)
    if not self:Blocked("chat") and KEYBOARD_CHAT_SYSTEM and self:ChatReady() then
        -- Older snapshots contain geometry only. Adopt tabs once, without discarding it.
        if not shared.chatLayout then
            local captured = self:Capture(true)
            shared.chatLayout = captured.chatLayout
            for id, geometry in pairs(captured.chat) do
                if not shared.chat[id] then shared.chat[id] = geometry end
            end
        end
        self:ApplyChatLayout(shared.chatLayout)
        self:ApplyOneChat(shared)
    end
    local width, height = GuiRoot:GetDimensions()
    if shared.performance and not self:Blocked("performance") and PERFORMANCE_METERS then
        local saved, control = shared.performance, PERFORMANCE_METERS.control
        control:ClearAnchors()
        control:SetAnchor(saved.point, GuiRoot, saved.relativePoint, saved.x * width, saved.y * height)
        PERFORMANCE_METERS:OnMoveStop()
    end
    if not self:Blocked("hud") then
        for key, saved in pairs(shared.hud) do
            local element = self.elements[key]
            if element and element:IsValid() and element.control.hudElementRef then
                element:ApplyOffset(saved.x * width, saved.y * height)
            end
        end
    end
    if not self:Blocked("chat") and KEYBOARD_CHAT_SYSTEM and self:ChatReady() then
        for _, container in ipairs(KEYBOARD_CHAT_SYSTEM.containers or {}) do
            local saved = shared.chat[container.id]
            if saved then
                local control = container.control
                control:ClearAnchors()
                control:SetAnchor(saved.point, GuiRoot, saved.relativePoint, saved.x * width, saved.y * height)
                control:SetDimensions(saved.width * width, saved.height * height)
                container:SaveSettings()
            end
        end
    end
    if WORLD_MAP_MANAGER then self:ApplyMap(shared) end
end

function Windows:Changed()
    if not OS.ready or OS.applying or not OS:Enabled("windows") or not self:ChatReady() then return end
    self.dirty = true
    OS:Later("Windows", function() self:FlushChanges() end)
end

function Windows:FlushChanges()
    if not self.dirty then return end
    self.dirty = false
    OS:CancelLater("Windows")
    OS:Publish("windows", self:Capture())
end

function Windows:Initialize()
    self:InitializeOneChat()
    local function changed() self:Changed() end
    if HUD_MANAGER then SecurePostHook(HUD_MANAGER, "SaveAnchorOffsets", changed) end
    if KEYBOARD_CHAT_SYSTEM then
        SecurePostHook(KEYBOARD_CHAT_SYSTEM, "SaveLocalContainerSettings", changed)
        -- Native persistence calls also cover tab dragging, renaming, filters and resets.
        for _, name in ipairs({ "AddChatContainer", "RemoveChatContainer", "AddChatContainerTab",
            "RemoveChatContainerTab", "TransferChatContainerTab", "SetChatContainerTabInfo",
            "SetChatContainerTabCategoryEnabled", "ResetChatContainerTabToDefault",
            "SetChatContainerColors", "ResetChatContainerColorsToDefault" }) do
            SecurePostHook(_G, name, changed)
        end
    end
    if PERFORMANCE_METERS then SecurePostHook(PERFORMANCE_METERS, "OnMoveStop", changed) end
    for _, name in ipairs({ "ZO_WorldMap_OnResizeStop", "ZO_WorldMapTitleBar_OnMouseUp" }) do
        if _G[name] then SecurePostHook(_G, name, changed) end
    end
    if WORLD_MAP_MANAGER then
        SecurePostHook(WORLD_MAP_MANAGER, "SetToMode", function()
            if OS.ready and OS:Enabled("windows") and not OS.applying then
                OS.applying = true
                self:ApplyMap(OS.account.shared.windows)
                OS.applying = false
            end
        end)
    end
end
