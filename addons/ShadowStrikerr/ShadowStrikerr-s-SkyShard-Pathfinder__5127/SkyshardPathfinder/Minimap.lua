local addon = SkyshardPathfinder
local overlay, viewport
local dots = {}
local shown = 0
local nextUpdate = 0
local dotSpacing = 9

function addon.HideMinimapTrail()
    if overlay then overlay:SetHidden(true) end
    nextUpdate = 0
end

local function getMinimap()
    local minimap = AUI and AUI.Minimap
    if minimap and minimap.IsLoaded and minimap.IsLoaded() and minimap.DoesShow
        and minimap.DoesShow() and minimap.GetMapContainer and minimap.GetMapContainerSize then return minimap end
end

local function coordinateMapper(minimap, map)
    local size = minimap.GetMapContainerSize()
    if type(size) ~= "number" or size <= 0 then return end
    if minimap.DoesRotate and minimap.DoesRotate() then
        if not minimap.GetRotationData or not minimap.GetPlayerPosition then return end
        local cos, sin = minimap.GetRotationData()
        local playerX, playerY = minimap.GetPlayerPosition()
        if not (cos and sin and playerX and playerY) then return end
        return function(u, v)
            local x, y = u * size - playerX, v * size - playerY
            return x * cos - y * sin, x * sin + y * cos
        end
    end
    local centerX, centerY = viewport:GetCenter()
    local originX, originY = map:GetLeft() - centerX, map:GetTop() - centerY
    return function(u, v) return originX + u * size, originY + v * size end
end

local function createDotTexture(size, level)
    local control = WINDOW_MANAGER:CreateControl(nil, overlay, CT_TEXTURE)
    control:SetTexture("/esoui/art/dye/gamepad/dye_circle.dds")
    control:SetDimensions(size, size)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(level)
    control:SetMouseEnabled(false)
    return control
end

local function positionDotTexture(control, x, y)
    control:ClearAnchors()
    control:SetAnchor(CENTER, overlay, CENTER, x, y)
    control:SetHidden(false)
end

local function placeDot(index, x, y, color, alpha)
    local dot = dots[index]
    if not dot then
        dot = { rim = createDotTexture(8, 54), fill = createDotTexture(5, 55) }
        dots[index] = dot
    end
    dot.rim:SetColor(0, 0, 0, alpha * .85)
    dot.fill:SetColor(color[1], color[2], color[3], alpha)
    positionDotTexture(dot.rim, x, y)
    positionDotTexture(dot.fill, x, y)
end

function addon.DrawMinimapTrail(trails, player, settings, seconds)
    if not settings.minimapTrail or settings.arrowsOnly then
        addon.HideMinimapTrail()
        return
    end
    if seconds < nextUpdate then return end
    nextUpdate = seconds + .08
    local minimap = getMinimap()
    local map = minimap and minimap.GetMapContainer()
    local parent = map and map:GetParent()
    if not parent or #trails == 0 then
        if overlay then overlay:SetHidden(true) end
        return
    end
    if viewport ~= parent then
        if overlay then
            overlay:SetHidden(true)
            overlay:SetParent(parent)
        else
            overlay = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
            overlay:SetMouseEnabled(false)
            overlay:SetDrawLayer(DL_OVERLAY)
            overlay:SetDrawLevel(55)
        end
        overlay:ClearAnchors()
        overlay:SetAnchorFill(parent)
        viewport = parent
    end
    local toPixel = coordinateMapper(minimap, map)
    local u, v = GetMapPlayerPosition("player")
    if not toPixel or not u or not v then
        overlay:SetHidden(true)
        return
    end
    local width, height = viewport:GetWidth() * .5 - 4, viewport:GetHeight() * .5 - 4
    local startX, startY = toPixel(u, v)
    local projectionFits
    if GetRawNormalizedWorldPosition then
        local playerU, playerV = GetRawNormalizedWorldPosition(player.zone, player.x, player.y, player.z)
        projectionFits = playerU and playerV and math.abs(playerU - u) < .005 and math.abs(playerV - v) < .005
    end
    local count = 0
    for _, trail in ipairs(trails) do
        local previousX, previousY = startX, startY
        local nextDot = dotSpacing
        local color = addon.GetTrailColor(trail, settings.groundColors)
        local points = projectionFits and trail.waypoints
        local target = trail.target
        local walkedCount = points and #points or 0
        local pointCount = walkedCount
        if not points or not points.complete then pointCount = pointCount + 1 end
        for index = 1, pointCount do
            local x, y
            local unverified = index > walkedCount and (trail.noWalkedPath or trail.waypoints ~= nil)
            if index <= walkedCount then
                local point = points[index]
                x, y = GetRawNormalizedWorldPosition(player.zone,
                    zo_round(point.x), zo_round(point.y), zo_round(point.z))
            elseif target then
                x, y = target.mapX, target.mapY
            end
            if not x or not y then break end
            x, y = toPixel(x, y)
            local dx, dy = x - previousX, y - previousY
            local length = math.sqrt(dx * dx + dy * dy)
            while length > 0 and nextDot <= length and count < 96 do
                local dotX = previousX + dx * nextDot / length
                local dotY = previousY + dy * nextDot / length
                if math.abs(dotX) <= width and math.abs(dotY) <= height then
                    count = count + 1
                    placeDot(count, dotX, dotY, color, unverified and .72 or 1)
                elseif index > walkedCount then
                    nextDot = length + dotSpacing
                    break
                end
                nextDot = nextDot + dotSpacing
            end
            if count >= 96 then break end
            nextDot = nextDot - length
            previousX, previousY = x, y
        end
        if count >= 96 then break end
    end
    for index = count + 1, shown do
        local dot = dots[index]
        dot.rim:SetHidden(true)
        dot.fill:SetHidden(true)
    end
    shown = count
    overlay:SetHidden(count == 0)
end
