local floor = math.floor
local class = IMP_LibSurfaceTools__class
local Quadtree = IMP_LibSurfaceTools__Quadtree
local SurfaceManager = IMP_LibSurfaceTools__SurfaceManager

-- ----------------------------------------------------------------------------

local addon = {
    name = 'LibSurfaceTools'
}

local EVENT_NAMESPACE = addon.name


local function _atlasIndexToAtlasXY(atlasIndex, atlasSizeX, atlasSizeY)
    atlasIndex = atlasIndex - 1
    return atlasIndex % atlasSizeX + 1, floor(atlasIndex / atlasSizeX) + 1
end

-- local function _atlasXYToAtlasIndex(atlasX, atlasY, atlasSizeX, atlasSizeY)
--     return atlasSizeX * (atlasY - 1) + atlasX
-- end

-- local function _getTextureInsets(atlasX, atlasY, atlasSizeX, atlasSizeY)
--     if atlasY == nil then
--         atlasX, atlasY = _atlasIndexToAtlasXY(atlasX, atlasSizeX, atlasSizeY)
--     end

--     local atlasStepX, atlasStepY = 1 / atlasSizeX, 1 / atlasSizeY
--     local tiL, tiR = (atlasX - 1) * atlasStepX, atlasX * atlasStepX
--     local tiT, tiB = (atlasY - 1) * atlasStepY, atlasY * atlasStepY

--     return tiL, tiR, tiT, tiB
-- end

function GetTextureInsets(self, atlasIndex)  -- TODO: meta
    if atlasIndex == nil then
        return 0, 1, 0, 1
    else
        -- TODO: can store as precomputed values
        local atlasStepX, atlasStepY = 1 / self.atlasSizeX, 1 / self.atlasSizeY

        local atlasX, atlasY = _atlasIndexToAtlasXY(atlasIndex, self.atlasSizeX, self.atlasSizeY)

        local tiR = atlasX * atlasStepX
        local tiL = tiR - atlasStepX
        local tiB = atlasY * atlasStepY
        local tiT = tiB - atlasStepY

        return tiL, tiR, tiT, tiB
    end
end

-- ----------------------------------------------------------------------------
----[[
local RigidGrid = class()

function RigidGrid:__init(parent, name, cellW, cellH)
    self.cellW = cellW
    self.cellH = cellH

    name = name or ('$(parent)Grid' .. parent:GetNumChildren())

    local composite = CreateControl(name, parent, CT_TEXTURECOMPOSITE)
    assert(composite, 'TextureComposite was not created!')

    -- control:SetDimensions(sizeX * cellW, sizeY * cellH)
    composite:ClearAllSurfaces()
    composite:SetAnchor(TOPLEFT, parent)

    self.composite = composite

    return self
end

function RigidGrid:SetAnchor(...)
    self.composite:ClearAnchors()  -- only 1 anchor!
    self.composite:SetAnchor(...)
    return self
end

function RigidGrid:SetOffsets(offsetX, offsetY)
    self.composite:SetAnchorOffsets(offsetX, offsetY, 1)
    return self
end

function RigidGrid:SetTexture(fileName, atlasSizeX, atlasSizeY)
    atlasSizeX = atlasSizeX or 1
    atlasSizeY = atlasSizeY or 1

    self.composite:SetTexture(fileName)

    if atlasSizeX > 1 or atlasSizeY > 1 then
        self.atlas = true
        self.atlasSizeX = atlasSizeX
        self.atlasSizeY = atlasSizeY
    end

    return self
end

function RigidGrid:Add(gridX, gridY, offsetX, offsetY, w, h, atlasIndex)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local tiL, tiR, tiT, tiB = self:GetTextureInsets(atlasIndex)

    gridX = gridX - 1
    gridY = gridY - 1

    local centerX = self.cellW * (gridX + 0.5) + offsetX
    local centerY = self.cellH * (gridY + 0.5) + offsetY

    local half_w, half_h = w/2, h/2
    local iL, iR = centerX - half_w, centerX + half_w
    local iT, iB = centerY - half_h, centerY + half_h

    local surfaceNumber = self.composite:AddSurface(tiL, tiR, tiT, tiB)
    self.composite:SetInsets(surfaceNumber, iL, iR, iT, iB)

    -- TODO: add to list
end

RigidGrid.GetTextureInsets = GetTextureInsets

function RigidGrid:Clear()
    self.composite:ClearAllSurfaces()
end

--]]
-- ----------------------------------------------------------------------------

local FlexRect = class()

function FlexRect:__init(parent, name, onMouseEnter, onMouseExit)
    -- parent = parent or addon.control
    name = name or ('$(parent)FlexRect'..parent:GetNumChildren())
    local EN = EVENT_NAMESPACE..name
    self._eventNamespace = EN

    local control = CreateControl(name, parent, CT_TEXTURECOMPOSITE)
    assert(control, 'TextureComposite was not created!')

    control:ClearAllSurfaces()
    control:SetPixelRoundingEnabled(false)
    self.W, self.H = parent:GetDimensions()
    control:SetHandler('OnUpdate', function() self:_onParentUpdate() end)
    control:SetAnchor(TOPLEFT, parent)
    -- control:SetAnchorFill(parent)

    self.composite = control
    self.parent = parent

    self.surfaceManager = SurfaceManager(control)
    self.surfaces = setmetatable({}, {__mode='k'})

    if onMouseEnter then
        -- df('Mouse over enabled')
        self._onMouseEnter = onMouseEnter
        self._onMouseExit = onMouseExit
        self.mouseOver = {}
        self._filteredHash = {}
        self.quadtree = Quadtree()

        -- self.hash = {}  -- setmetatable({}, {__mode='k'})

        local function startMouseOverUpdateLoop()
            -- df('[%d] Update loop started for %s', GetGameTimeMilliseconds(), name)
            EVENT_MANAGER:RegisterForUpdate(EN..'UpdateLoop', 0, function()
                self:_onUpdate()
            end)
        end

        local function stopMouseOverUpdateLoop()
            -- df('[%d] Update loop stopped for %s', GetGameTimeMilliseconds(), name)
            EVENT_MANAGER:UnregisterForUpdate(EN..'UpdateLoop')
            self:_clearMouseOver()
        end

        if not self.composite:IsHidden() then
            startMouseOverUpdateLoop()
        end

        control:SetHandler('OnEffectivelyShown', startMouseOverUpdateLoop)
        control:SetHandler('OnEffectivelyHidden', stopMouseOverUpdateLoop)

        local isConsole = nil
        local function switchInputMethod(toConsole)
            -- df('toConsole: %s, isConsole: %s', tostring(toConsole), tostring(isConsole))
            if toConsole == isConsole then return end
            isConsole = toConsole

            if toConsole then
                self:_switchToConsoleInput()
            else
                self:_switchToMouseInput()
            end
        end

        switchInputMethod(IsConsoleUI() or IsInGamepadPreferredMode())

        EVENT_MANAGER:RegisterForEvent(EN, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function(_, inGamepadPreferredMode)
            switchInputMethod(inGamepadPreferredMode)
        end)
    end

    self.animations = {}

    return self
end

function FlexRect:_switchToMouseInput()
    self:_clearInputMethod()
    local control = self.composite

    self._getCursorPosition = self._getCursorPositionMouse
    control:SetMouseEnabled(true)

    --[[
    control:SetHandler('OnMouseEnter', self._registerMouseOverUpdateLoop)
    control:SetHandler('OnMouseExit', self._unregisterMouseOverUpdateLoop)

    -- if surface hidden, need to update all previously mouse over pins, TODO: make it effectively
    control:SetHandler('OnEffectivelyHidden', function()
        self:_clearMouseOver()
    end)
    --]]
end

function FlexRect:_switchToConsoleInput()
    self:_clearInputMethod()
    local control = self.composite

    self._getCursorPosition = self._getCursorPositionController
    control:SetMouseEnabled(false)

    --[[
    control:SetHandler('OnEffectivelyShown', self._registerMouseOverUpdateLoop)
    control:SetHandler('OnEffectivelyHidden', function()
        self._unregisterMouseOverUpdateLoop()
        self:_clearMouseOver()
    end)
    --]]
end

function FlexRect:_clearInputMethod()
    self:_clearMouseOver()

    local control = self.composite

    -- control:SetHandler('OnMouseEnter', nil)
    -- control:SetHandler('OnMouseExit', nil)
    -- control:SetHandler('OnEffectivelyShown', nil)
    -- control:SetHandler('OnEffectivelyHidden', nil)
end

--[[
function FlexRect:_hookMapContainer()
    local control = self.composite

    ZO_PostHook(_G, 'ZO_WorldMap_MouseEnter', function(_, ...) control:GetHandler('OnMouseEnter')(control) end)
	ZO_PostHook(_G, 'ZO_WorldMap_MouseExit', function(_, ...) control:GetHandler('OnMouseExit')(control) end)
end
--]]

function FlexRect:_clearMouseOver()
    if not self._onMouseEnter then return end

    for surface in pairs(self.mouseOver) do
        local surfaces = self.surfaces
        local surfaceData = surfaces[surface]
        local tag = surfaceData.tag
        self._onMouseExit(tag, surface, self)
        self.mouseOver[surface] = nil
    end
end

function FlexRect:SetAnchor(...)
    self.composite:SetAnchor(...)
    return self
end

function FlexRect:SetTexture(fileName, atlasSizeX, atlasSizeY)
    atlasSizeX = atlasSizeX or 1
    atlasSizeY = atlasSizeY or 1

    self.composite:SetTexture(fileName)

    if atlasSizeX > 1 or atlasSizeY > 1 then
        self.atlas = true
        self.atlasSizeX = atlasSizeX
        self.atlasSizeY = atlasSizeY
    end

    return self
end

function FlexRect:SetColor(surfaceIndex, r, g, b, a)
    self.composite:SetColor(surfaceIndex, r, g, b, a)
    return self
end

function FlexRect:SetAlpha(surfaceIndex, alpha)
    self.composite:SetSurfaceAlpha(surfaceIndex, alpha)
    return self
end

function FlexRect:Add(n_x, n_y, offsetX, offsetY, w, h, atlasIndex, tag, zoom)
    local iL, iR, iT, iB
    if self.atlas then
        iL, iR, iT, iB = self:GetTextureInsets(atlasIndex)
    else
        iL, iR, iT, iB = 0, 1, 0, 1
    end

    if zoom and zoom ~= 1 then
        local dX, dY = iR - iL, iB - iT
        dX = dX / zoom / 2
        dY = dY / zoom / 2

        iL, iR, iT, iB = iL + dX, iR - dX, iT + dY, iB - dY
    end

    local surface = self.surfaceManager:AddSurface(iL, iR, iT, iB)

    offsetX = offsetX or 0
    offsetY = offsetY or 0

    self:_place(surface, n_x, n_y, offsetX, offsetY, w, h)

    -- not very safe, but it should work OK until someone used it inproperly
    local surfaceData = {n_x, n_y, offsetX, offsetY, w, h, atlasIndex, 1, tag = tag}  -- added current scale
    self.surfaces[surface] = surfaceData

    if self.quadtree then
        self.quadtree:Insert(n_x, n_y, surface)
        -- self.hash[surfaceData] = surface
    end

    return surface
end

FlexRect.GetTextureInsets = GetTextureInsets

function FlexRect:_place(surface, n_x, n_y, offsetX, offsetY, w, h, scale)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    scale = scale or 1
    w, h = w * scale, h * scale

    local W, H = self.W, self.H

    local centerX = W * n_x + offsetX
    local centerY = H * n_y + offsetY

    local half_w, half_h = w/2, h/2
    local iL, iR = centerX - half_w, centerX + half_w
    local iT, iB = centerY - half_h, centerY + half_h
    -- local iL, iR = centerX - half_w, centerX + half_w - W
    -- local iT, iB = centerY - half_h, centerY + half_h - H

    surface:SetInsets(iL, iR, iT, iB)
end

function FlexRect:_onParentUpdate()
    if not self:_isParentSizeChanged() then return end

    for surface, s in pairs(self.surfaces) do
        -- TODO: (..., unpack(s)) vs (..., s[1], s[2], ...)
        self:_place(surface, s[1], s[2], s[3], s[4], s[5], s[6], s[8])
    end
end

--[[
local measurements = {}
local s, f
local N = 100
local original = FlexRect._onParentUpdate
function FlexRect:_onParentUpdate()
    -- size was not changed = do notmeter
    if self.W == self.parent:GetWidth() then return end

    s = GetGameTimeSeconds()
    original(self)
    f = GetGameTimeSeconds()

    measurements[#measurements+1] = f - s
    if #measurements >= N then
        local total = 0
        local max = 0
        for i = 1, #measurements do
            local m = measurements[i]  -- single measurement
            total = total + m
            if m > max then
                max = m
            end
        end
        df('Update time: %.3fms, max: %.3fms', total / #measurements * 1000, max * 1000)
        ZO_ClearNumericallyIndexedTable(measurements)
    end
end
--]]

function FlexRect:_isParentSizeChanged()
    local parent = self.parent

    local W, H = parent:GetDimensions()
    if self.W == W and self.H == H then return end

    self.W, self.H = W, H
    return true
end

function FlexRect:_updateSurface(surface)
    local s = self.surfaces[surface]
    self:_place(surface, s[1], s[2], s[3], s[4], s[5], s[6], s[8])
end

function FlexRect:RemoveSurface(surface)
    if self.quadtree then
        self._onMouseExit(self.surfaces[surface].tag, surface, self)
        self.mouseOver[surface] = nil
        self.quadtree:Remove(surface)
    end

    self.surfaces[surface] = nil
    self.animations[surface] = nil
    surface:RemoveSurface()
end

function FlexRect:AnimateScale(surface, startScale, endScale, duration)
    self.animations[surface] = {startScale, endScale, duration/1000, GetGameTimeSeconds()}
    self:_startAnimations()
end

function FlexRect:_startAnimations()
    if self._animationInProgress then return end
    self._animationInProgress = true

    EVENT_MANAGER:RegisterForUpdate(self._eventNamespace..'Animations', 0, function()
        self:_doAnimationStep()
    end)
end

function FlexRect:_stopAnimations()
    EVENT_MANAGER:UnregisterForUpdate(self._eventNamespace..'Animations')
    self._animationInProgress = false
end

function FlexRect:_doAnimationStep()
    for surface, animationParams in pairs(self.animations) do
        local duration = animationParams[3]

        local start = animationParams[4]
        local now = GetGameTimeSeconds()
        local progress = (now - start) / duration

        if progress >= 1 then  -- TODO: something better, reuse, etc.
            progress = 1
            self.animations[surface] = nil
        end

        -- df('progress %.6f', progress)

        -- local scale = zo_deltaNormalizedLerp(animationParams[1], animationParams[2], progress)
        local scale = zo_lerp(animationParams[1], animationParams[2], progress)

        local s = self.surfaces[surface]
        s[8] = scale

        self:_place(surface, s[1], s[2], s[3], s[4], s[5], s[6], s[8])
    end

    if not next(self.animations) then
        self:_stopAnimations()
    end
end

function FlexRect:RemoveSurfacesOfKind(atlasIndex)
    -- TODO: kinda slow, make bulk delete

    if not self.atlas then return end

    local surfaces = self.surfaces
    for surface, surfaceData in pairs(surfaces) do
        if surfaceData[7] == atlasIndex then
            self:RemoveSurface(surface)
        end
    end
end

function FlexRect:Clear()
    self.composite:ClearAllSurfaces()

    self:_clearMouseOver()

    ZO_ClearTable(self.surfaces)
    ZO_ClearTable(self.animations)

    if self.quadtree then
        self.quadtree:Clear()
    end
end

function FlexRect:_getCursorPositionMouse()
    return GetUIMousePosition()
end

function FlexRect:_getCursorPositionController()
    return ZO_WorldMapScroll:GetCenter()
end

function FlexRect:_onUpdate()
    local x, y = self.composite:GetLeft(), self.composite:GetTop()
    local m_x, m_y = self:_getCursorPosition()

    local W, H = self.W, self.H
    local mn_x, mn_y = (m_x - x) / W, (m_y - y) / H

    -- TODO: need some arbitrary width and height...
    -- 100 px, normalize for w and h
    local n_size = 64 / W
    local results = self.quadtree:Query(mn_x, mn_y, n_size)

    -- TODO: check if result is different

    -- df('%d', #results)

    local filtered = self._filteredHash
    ZO_ClearNumericallyIndexedTable(filtered)

    local mr_x, mr_y = m_x - x, m_y - y
    for _, result in ipairs(results) do
        local surface = result.data
        local surfaceData = self.surfaces[surface]

        local r_x, r_y = surfaceData[1] * W + surfaceData[3], surfaceData[2] * H + surfaceData[4]
        local halfSurfaceWidth, halfSurfaceHeight = surfaceData[5] / 1.75, surfaceData[6] / 1.75  -- arbitrary selected 1.75

        if r_x + halfSurfaceWidth > mr_x and
        r_x - halfSurfaceWidth < mr_x and
        r_y - halfSurfaceHeight < mr_y and
        r_y + halfSurfaceHeight > mr_y then
            filtered[#filtered+1] = surface
        end
    end

    -- df('%d', #filtered)

    local previousMouseOver = self.mouseOver
    local mouseOver = {}  -- TODO: avoid table creation
    self.mouseOver = mouseOver

    local added = {}
    local surfaces = self.surfaces

    for i = 1, #filtered do
        local surface = filtered[i]

        mouseOver[surface] = true

        if not previousMouseOver[surface] then
            added[surface] = true
        end
    end

    for surface in pairs(previousMouseOver) do
        if not mouseOver[surface] then
            local surfaceData = surfaces[surface]
            local tag = surfaceData.tag
            self._onMouseExit(tag, surface, self)
            self:_updateSurface(surface)
        end
    end

    for surface in pairs(added) do
        self._onMouseEnter(surfaces[surface].tag, surface, self)
        self:_updateSurface(surface)
    end
end

-- TODO: should they be part of class or instance?
local ownInformationTooltip = false
-- local shouldLayout = false

function FlexRect:_layoutTooltip()
    if SCENE_MANAGER:IsCurrentSceneGamepad() then return end  -- TODO: gamepad support

    local informationTooltip = ZO_WorldMap_GetTooltipForMode(ZO_MAP_TOOLTIP_MODE.INFORMATION)

    local claimedBefore = {}

    for _, mode in ipairs(ZO_WORLD_MAP_TOOLTIP_ORDER) do
        local tt = ZO_WorldMap_GetTooltipForMode(mode)
        claimedBefore[mode] = tt and not tt:IsHidden()
    end

    local surfacesByMode = {}
    for surface in pairs(self.mouseOver) do
        local info = self.pinTooltipInfo
        if info and info.tooltip and info.creator then
            local layout = true

            -- TODO: vanilla esoui\ingame\map\worldmap.lua has more complex logic here, probably useful

            if layout and info.hasTooltip then
                layout = info.hasTooltip(self.surfaces[surface].tag)
            end

            if layout then
                surfacesByMode[info.tooltip] = surfacesByMode[info.tooltip] or {}
                table.insert(surfacesByMode[info.tooltip], surface)
            end
        end
    end
    if next(surfacesByMode) == nil then return end

    for mode, surfaces in pairs(surfacesByMode) do
        if not claimedBefore[mode] then
            if mode == ZO_MAP_TOOLTIP_MODE.KEEP then
                ZO_WorldMap_GetTooltipForMode(mode):SetHidden(false)
            else
                InitializeTooltip(ZO_WorldMap_GetTooltipForMode(mode), self.composite)

                -- local control = surfaces[1]:GetControl()
                -- if control then
                --     InitializeTooltip(ZO_WorldMap_GetTooltipForMode(mode), control)
                -- end
            end
            if mode == ZO_MAP_TOOLTIP_MODE.INFORMATION then
                ownInformationTooltip = true
            end
        end
        -- claimedBefore[mode] == true means vanilla owns it this pass;
        -- our flag must NOT be set (vanilla's anchoring loop will set g_owns)
    end

    if surfacesByMode[ZO_MAP_TOOLTIP_MODE.INFORMATION] then
        if claimedBefore[ZO_MAP_TOOLTIP_MODE.INFORMATION] then
            informationTooltip:AddVerticalPadding(5)
        end
        for _, surface in ipairs(surfacesByMode[ZO_MAP_TOOLTIP_MODE.INFORMATION]) do
            self.pinTooltipInfo.creator(self.surfaces[surface].tag)
            informationTooltip:AddVerticalPadding(5)
        end
        informationTooltip:AddVerticalPadding(-5)
    end

    for mode, surfaces in pairs(surfacesByMode) do
        if mode ~= ZO_MAP_TOOLTIP_MODE.INFORMATION then
            for _, surface in ipairs(surfaces) do
                self.pinTooltipInfo.creator(self.surfaces[surface].tag)
            end
        end
    end

    -- reanchor everything
    local prevControl = nil
    local placeAbove = GuiMouse:GetTop() > (GuiRoot:GetHeight() / 2)
    local placeLeft  = GuiMouse:GetLeft() > (GuiRoot:GetWidth() / 2)
    for _, mode in ipairs(ZO_WORLD_MAP_TOOLTIP_ORDER) do
        local tooltipControl = ZO_WorldMap_GetTooltipForMode(mode)
        if tooltipControl and not tooltipControl:IsHidden() then
            tooltipControl:ClearAnchors()
            if prevControl then
                if placeLeft then
                    if placeAbove then
                        tooltipControl:SetAnchor(BOTTOMRIGHT, prevControl, TOPRIGHT, 0, -5)
                    else
                        tooltipControl:SetAnchor(TOPRIGHT, prevControl, BOTTOMRIGHT, 0, 5)
                    end
                else
                    if placeAbove then
                        tooltipControl:SetAnchor(BOTTOMLEFT, prevControl, TOPLEFT, 0, -5)
                    else
                        tooltipControl:SetAnchor(TOPLEFT, prevControl, BOTTOMLEFT, 0, 5)
                    end
                end
            else
                if placeLeft then
                    tooltipControl:SetAnchor(RIGHT, GuiMouse, LEFT, -32, 0)
                else
                    tooltipControl:SetAnchor(LEFT, GuiMouse, RIGHT, 32, 0)
                end
            end
            prevControl = tooltipControl
        end
    end
end

local TOOLTIP_HOOKED = false
function FlexRect:InitializeTooltipHook()
    -- TODO: implement something better
    -- if self.tooltipHooked then return end
    -- self.tooltipHooked = true

    if TOOLTIP_HOOKED then return end
    TOOLTIP_HOOKED = true

    local function GetInformationTooltip(isGamepadMode)
        if isGamepadMode then
            return ZO_MapLocationTooltip_Gamepad
        else
            return InformationTooltip
        end
    end

    ZO_PostHook(_G, 'ZO_WorldMap_HideAllTooltipsLater', function()
        if not ownInformationTooltip then return end

        local NOT_GAMEPAD_MODE = false
        local tt = GetInformationTooltip(NOT_GAMEPAD_MODE)
        if not tt:IsHidden() then
            ClearTooltip(tt)
        else
            ownInformationTooltip = false
        end
    end)
end

function FlexRect:AddTooltip(pinTooltipInfo)
    self.pinTooltipInfo = pinTooltipInfo

    self:InitializeTooltipHook()

    -- TODO: check to not add hook twice
    ZO_PostHook(self, '_onMouseEnter', function()
        -- df('Update triggered by LibSurfaceTools')
        -- WORLD_MAP_MANAGER:UpdatePinTooltips()
        WORLD_MAP_MANAGER.pinTooltipIsDirty = true
        WORLD_MAP_MANAGER:UpdateMouseoverTooltips()
    end)

    ZO_PostHook(self, '_onMouseExit', function()
        -- TODO: be sure to remove surface from self.mouseOver first
        WORLD_MAP_MANAGER.pinTooltipIsDirty = true
        WORLD_MAP_MANAGER:UpdateMouseoverTooltips()
    end)

    ZO_PostHook(WORLD_MAP_MANAGER, 'UpdatePinTooltips', function()
        self.shouldLayout = true
    end)

    ZO_PostHook(WORLD_MAP_MANAGER, 'UpdateMouseoverTooltips', function(self_, resetScroll)
        -- df('Update mouseover tooltips called')

        if not self.shouldLayout then return end
        self.shouldLayout = false

        self:_layoutTooltip()
    end)
end

addon.Tools = {
    FlexRect = FlexRect,
    RigidGrid = RigidGrid,
}

-- ----------------------------------------------------------------------------

function addon:Initialize()
    self.control = LibSurfaceTools_TLC
end

-- ----------------------------------------------------------------------------

local function OnAddonLoaded(_, addonName)
    if addonName ~= addon.name then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)

    addon:Initialize()
end


EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)

LibSurfaceTools = addon

IMP_LibSurfaceTools__Quadtree = nil
IMP_LibSurfaceTools__class = nil
IMP_LibSurfaceTools__SurfaceManager = nil
