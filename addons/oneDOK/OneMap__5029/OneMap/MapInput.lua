local A = OneMap
local CLICK_MS, MOVE_SQUARED = 200, 25

-- The native mouse-up handler reads Shift globally rather than accepting an
-- argument. Mask it only during this synchronous map-handler call, restoring
-- it even if another hook raises an error. All other input remains native.
function A:CallMapWithoutShift(handler, ...)
    local readShift = IsShiftKeyDown
    IsShiftKeyDown = function() return false end
    local ok, result = pcall(handler, ...)
    IsShiftKeyDown = readShift
    if not ok then error(result) end
    return result
end

function A:TrackShiftMapMovement()
    local click = self.shiftMapClick
    if not click then return end
    local x, y = GetUIMousePosition()
    if (x - click.x)^2 + (y - click.y)^2 > MOVE_SQUARED then click.moved = true end
end

function A:InitializeMapInput()
    local mouseDown, mouseUp = ZO_WorldMap_MouseDown, ZO_WorldMap_MouseUp
    ZO_WorldMap_MouseDown = function(button, ctrl, alt, shift)
        self.shiftMapClick = nil
        if shift and not ctrl and not alt and self:CanUseMap() then
            if button == MOUSE_BUTTON_INDEX_LEFT then
                local x, y = GetUIMousePosition()
                local nx, ny = NormalizeMousePositionToControl(ZO_WorldMapContainer)
                self.shiftMapClick = { started = GetFrameTimeMilliseconds(), x = x, y = y, nx = nx, ny = ny }
            end
            mouseDown(button, ctrl, alt, false)
            if self.shiftMapClick then
                ZO_PostHookHandler(ZO_WorldMapContainer, "OnUpdate", function() self:TrackShiftMapMovement() end)
            end
            return
        end
        return mouseDown(button, ctrl, alt, shift)
    end
    ZO_WorldMap_MouseUp = function(control, button, upInside)
        self:TrackShiftMapMovement()
        local click = self.shiftMapClick
        self.shiftMapClick = nil
        if self:CanUseMap() and not IsControlKeyDown() and not IsAltKeyDown() then
            if click and button == MOUSE_BUTTON_INDEX_LEFT and upInside and not click.moved
                and GetFrameTimeMilliseconds() - click.started <= CLICK_MS then
                -- Clean up the native drag state without opening a child map.
                mouseUp(control, button, false)
                PingMap(MAP_PIN_TYPE_RALLY_POINT, MAP_TYPE_LOCATION_CENTERED, click.nx, click.ny)
                return
            end
            if click or IsShiftKeyDown() then
                return self:CallMapWithoutShift(mouseUp, control, button, upInside)
            end
        end
        return mouseUp(control, button, upInside)
    end
    ZO_PreHook("ZO_WorldMap_MouseWheel", function()
        if self.shiftMapClick then self.shiftMapClick.moved = true end
    end)
    SCENE_MANAGER:GetScene("worldMap"):RegisterCallback("StateChange", function()
        if not self:IsKeyboardMap() then self.shiftMapClick = nil end
    end)
end
