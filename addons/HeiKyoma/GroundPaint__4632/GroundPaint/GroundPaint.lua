local ADDON_NAME = "GroundPaint"

GroundPaint = GroundPaint or {}
local GP = GroundPaint

local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local PI = math.pi
local WORLD_UNITS_PER_METER = 100

local DEFAULT_ZONE_LINE_COLOR = { r = 1, g = 0, b = 0, a = 0.9 }
local DEFAULT_ZONE_FILL_COLOR = { r = 1, g = 0, b = 0, a = 0.18 }

local PROFILE_DEFAULTS = {
    enabled = true,
    silent = true,
    height = 0.5,

    customized = {
        enabled = true,
        fillEnabled = true,
        trigger = "always", -- "always"; "synergy" (doesn't work, Ima stupid)
        shape = "square", -- "square", "cone", "cone2", "ellipse"
        alignment = "forward", -- "forward", "center"
        width = 10.0,
        length = 15.0,
        fillStep = 0.35,
        lineColor = { r = 1, g = 0, b = 0, a = 0.9 },
        fillColor = { r = 1, g = 0, b = 0, a = 0.18 },
    },

    grid = {
        enabled = true,
        mode = "cartesian", -- "cartesian", "radial"
        length = 15.0,
        width = 10.0,
        step = 1.0,
        majorStep = 5.0,
        radialSegments = 64,
        radialSpokes = 16,
        color = { r = 0.1, g = 0.8, b = 1, a = 0.3 },
        majorColor = { r = 0.1, g = 0.8, b = 1, a = 0.8 },
    },

    labels = {
        enabled = true,
        color = { r = 1, g = 1, b = 1, a = 1 },
        size = 1,
    },

    presetStates = {
        builtin = {},
        custom = {},
    },

    updateMs = 0,
}

local META_DEFAULTS = {
    accountWide = false,
}

local USER_ZONES_DEFAULTS = {
    nextId = 1,
    zones = {},
    order = {},
}

local function DeepCopy(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return out
end

local function MergeDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(saved[k]) ~= "table" then
                saved[k] = DeepCopy(v)
            else
                MergeDefaults(saved[k], v)
            end
        elseif saved[k] == nil then
            saved[k] = v
        end
    end
end

local function ColorCopy(c)
    return {
        r = c and c.r or 1,
        g = c and c.g or 1,
        b = c and c.b or 1,
        a = c and c.a or 1,
    }
end

local function ChatMessage(text)
    if GP.saved and GP.saved.silent then return end
    d(text)
end

local function HideList(list)
    if not list then return end
    for _, c in ipairs(list) do
        c:SetHidden(true)
    end
end

local function HideAll()
    HideList(GP.areaLines)
    HideList(GP.areaFills)
    HideList(GP.gridLines)
    HideList(GP.labels)
end

function GP.Toggle()
    if not GP.saved then return end

    GP.saved.enabled = not GP.saved.enabled

    if not GP.saved.enabled then
        HideAll()
    end

    ChatMessage("GroundPaint: " .. (GP.saved.enabled and "ON" or "OFF"))
end

ZO_CreateStringId("SI_BINDING_NAME_GROUNDPAINT_TOGGLE", "Toggle GroundPaint")

local function ShouldShow()
    return GP.saved and GP.saved.enabled
end

local function ShouldShowCustomized()
    if not GP.saved or not GP.saved.enabled then return false end
    if not GP.saved.customized.enabled then return false end

    if GP.saved.customized.trigger == "always" then
        return true
    elseif GP.saved.customized.trigger == "synergy" then
        return GP.synergyAvailable == true
    end

    return false
end

local function RebuildNow()
    if GP.RebuildGeometry then
        GP.RebuildGeometry()
    end
end


local function CreateWorldWindow()
    if GP.worldWindow then return GP.worldWindow end

    GP.worldWindowGeneration = (GP.worldWindowGeneration or 0) + 1

    local win = WM:CreateTopLevelWindow("GroundPaintWorldWindow" .. tostring(GP.worldWindowGeneration))
    GP.worldWindow = win

    win:SetHidden(false)
    win:SetDimensions(1, 1)
    win:SetMovable(false)
    win:SetMouseEnabled(false)
    win:SetClampedToScreen(false)
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, -10, -10)
    win:Create3DRenderSpace()
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_HIGH)

    return win
end

local UpdateTransform

local function RecreateAfterTeleport()
    if not GP.saved then return end

    HideAll()

    GP.areaLines = {}
    GP.areaFills = {}
    GP.gridLines = {}
    GP.labels = {}

    -- Do not reuse the old 3D window after teleport.
    -- It can stay alive but detached from the new world render space.
    -- A new unique name avoids control-name/render-space conflicts.
    GP.worldWindow = nil

    -- Do not reset these to 0:
    -- old controls may still exist, and reusing names can break rendering.
    GP.nextLineIndex = (GP.nextLineIndex or 0) + 1000
    GP.nextLabelIndex = (GP.nextLabelIndex or 0) + 1000

    CreateWorldWindow()

    if GP.RebuildGeometry then
        GP.RebuildGeometry()
    end

    zo_callLater(UpdateTransform, 100)
end

local function CreateLine()
    local parent = CreateWorldWindow()
    local index = (GP.nextLineIndex or 0) + 1
    GP.nextLineIndex = index

    local c = WM:CreateControl("GroundPaintLine" .. tostring(index), parent, CT_TEXTURE)

    c:SetHidden(true)
    c:SetAnchor(CENTER, parent, CENTER, 0, 0)
    c:SetTexture("art/fx/texture/box_softinside.dds")
    c:SetAddressMode(TEX_MODE_WRAP)
    c:SetTextureCoords(0.2, 0.8, 0.2, 0.8)
    c:SetColor(1, 1, 1, 1)

    c:Create3DRenderSpace()
    c:Set3DRenderSpaceUsesDepthBuffer(false)
    c:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    c:Set3DLocalDimensions(1, 0.04)

    return c
end

local function CreateLabel()
    local parent = CreateWorldWindow()
    local index = (GP.nextLabelIndex or 0) + 1
    GP.nextLabelIndex = index

    local c = WM:CreateControl("GroundPaintLabel" .. tostring(index), parent, CT_LABEL)

    c:SetHidden(true)
    c:SetAnchor(CENTER, parent, CENTER, 0, 0)
    c:SetFont("$(BOLD_FONT)|" .. tostring(GP.saved.labels.size) .. "|soft-shadow-thick")
    c:SetColor(GP.saved.labels.color.r, GP.saved.labels.color.g, GP.saved.labels.color.b, GP.saved.labels.color.a)
    c:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c:SetDimensions(80, 30)

    c:Create3DRenderSpace()
    c:Set3DRenderSpaceUsesDepthBuffer(false)

    return c
end

local function ClearGeometry()
    HideAll()

    GP.areaLines = {}
    GP.areaFills = {}
    GP.gridLines = {}
    GP.labels = {}
end

local function AddAreaLine(zoneId, x1, z1, x2, z2, color)
    local line = CreateLine()
    line.gp = {
        kind = "area",
        zoneId = zoneId,
        x1 = x1,
        z1 = z1,
        x2 = x2,
        z2 = z2,
        color = color,
    }
    table.insert(GP.areaLines, line)
end

local function AddAreaFillLine(zoneId, x1, z1, x2, z2, color, fillStep)
    local line = CreateLine()
    line.gp = {
        kind = "areaFill",
        zoneId = zoneId,
        x1 = x1,
        z1 = z1,
        x2 = x2,
        z2 = z2,
        color = color,
        fillStep = fillStep,
    }
    table.insert(GP.areaFills, line)
end

local function AddGridLine(x1, z1, x2, z2, major)
    local line = CreateLine()
    line.gp = {
        kind = "grid",
        x1 = x1,
        z1 = z1,
        x2 = x2,
        z2 = z2,
        major = major,
    }
    table.insert(GP.gridLines, line)
end

local function AddLabel(text, x, z)
    if not GP.saved.labels.enabled then return end

    local label = CreateLabel()
    label:SetText(text)
    label.gp = { x = x, z = z }
    table.insert(GP.labels, label)
end

local function ZoneZRange(zone)
    local l = zone.length

    if zone.alignment == "center" then
        return -l * 0.5, l * 0.5
    end

    return 0, l
end

local function AddSquareGeometry(zoneId, zone, state)
    local w = zone.width * 0.5
    local z1, z2 = ZoneZRange(zone)

    AddAreaLine(zoneId, -w, z1,  w, z1, state.lineColor)
    AddAreaLine(zoneId,  w, z1,  w, z2, state.lineColor)
    AddAreaLine(zoneId,  w, z2, -w, z2, state.lineColor)
    AddAreaLine(zoneId, -w, z2, -w, z1, state.lineColor)

    if state.renderMode == "fill" or state.renderMode == "both" then
        local step = zone.fillStep or GP.saved.customized.fillStep or 0.35
        local z = z1
        while z <= z2 + 0.001 do
            AddAreaFillLine(zoneId, -w, z, w, z, state.fillColor, step)
            z = z + step
        end
    end
end

local function AddConeGeometry(zoneId, zone, state)
    local w = zone.width * 0.5
    local z1, z2 = ZoneZRange(zone)

    AddAreaLine(zoneId, 0, z1, -w, z2, state.lineColor)
    AddAreaLine(zoneId, 0, z1,  w, z2, state.lineColor)
    AddAreaLine(zoneId, -w, z2, w, z2, state.lineColor)

    if state.renderMode == "fill" or state.renderMode == "both" then
        local step = zone.fillStep or GP.saved.customized.fillStep or 0.35
        local total = math.abs(z2 - z1)

        if total > 0.001 then
            local z = z1
            while z <= z2 + 0.001 do
                local t = math.abs(z - z1) / total
                local halfWidth = w * t
                AddAreaFillLine(zoneId, -halfWidth, z, halfWidth, z, state.fillColor, step)
                z = z + step
            end
        end
    end
end

local function AddCone2Geometry(zoneId, zone, state)
    local radius = zone.length
    local halfWidth = zone.width * 0.5

    if radius <= 0.001 then return end

    if halfWidth > radius then
        halfWidth = radius
    end

    local angle = math.asin(halfWidth / radius)
    local segments = 48

    AddAreaLine(
        zoneId,
        0, 0,
        -math.sin(angle) * radius,
        math.cos(angle) * radius,
        state.lineColor
    )

    AddAreaLine(
        zoneId,
        0, 0,
        math.sin(angle) * radius,
        math.cos(angle) * radius,
        state.lineColor
    )

    for i = 0, segments - 1 do
        local a1 = -angle + (2 * angle) * (i / segments)
        local a2 = -angle + (2 * angle) * ((i + 1) / segments)

        AddAreaLine(
            zoneId,
            math.sin(a1) * radius,
            math.cos(a1) * radius,
            math.sin(a2) * radius,
            math.cos(a2) * radius,
            state.lineColor
        )
    end

    if state.renderMode == "fill" or state.renderMode == "both" then
        local step = zone.fillStep or GP.saved.customized.fillStep or 0.35
        local z = 0
        local tanA = math.tan(angle)

        while z <= radius + 0.001 do
            local byAngle = z * tanA
            local byCircle = math.sqrt(math.max(0, radius * radius - z * z))
            local halfSegment = math.min(byAngle, byCircle)

            if halfSegment > 0.001 then
                AddAreaFillLine(zoneId, -halfSegment, z, halfSegment, z, state.fillColor, step)
            end

            z = z + step
        end
    end
end

local function AddEllipseGeometry(zoneId, zone, state)
    local w = zone.width * 0.5
    local z1, z2 = ZoneZRange(zone)
    local l = zone.length * 0.5
    local cx = 0
    local cz = (z1 + z2) * 0.5
    local segments = 64

    for i = 0, segments - 1 do
        local a1 = (i / segments) * 2 * PI
        local a2 = ((i + 1) / segments) * 2 * PI

        AddAreaLine(
            zoneId,
            cx + math.cos(a1) * w,
            cz + math.sin(a1) * l,
            cx + math.cos(a2) * w,
            cz + math.sin(a2) * l,
            state.lineColor
        )
    end

    if state.renderMode == "fill" or state.renderMode == "both" then
        local step = zone.fillStep or GP.saved.customized.fillStep or 0.35
        local z = z1

        while z <= z2 + 0.001 do
            local normalized = (z - cz) / l
            local inside = 1 - normalized * normalized

            if inside >= 0 then
                local halfWidth = w * math.sqrt(inside)
                AddAreaFillLine(zoneId, -halfWidth, z, halfWidth, z, state.fillColor, step)
            end

            z = z + step
        end
    end
end

local function AddZoneGeometry(zoneId, zone, state)
    if not zone or not state then return end
    if not state.enabled then return end

    if state.renderMode == "none" then return end

    if zone.shape == "cone" then
        AddConeGeometry(zoneId, zone, state)
    elseif zone.shape == "cone2" then
        AddCone2Geometry(zoneId, zone, state)
    elseif zone.shape == "ellipse" then
        AddEllipseGeometry(zoneId, zone, state)
    else
        AddSquareGeometry(zoneId, zone, state)
    end
end

local function IsMajor(v)
    local major = GP.saved.grid.majorStep or 5
    local r = v % major
    return r < 0.001 or math.abs(r - major) < 0.001
end

local function BuildCartesianGrid()
    local g = GP.saved.grid
    local halfW = g.width * 0.5

    local z = 0
    while z <= g.length + 0.001 do
        local major = IsMajor(z)
        AddGridLine(-halfW, z, halfW, z, major)

        if major and z > 0 then
            AddLabel(tostring(math.floor(z)), 0, z)
        end

        z = z + g.step
    end

    local x = -halfW
    while x <= halfW + 0.001 do
        local major = IsMajor(math.abs(x))
        AddGridLine(x, 0, x, g.length, major)
        x = x + g.step
    end
end

local function BuildRadialGrid()
    local g = GP.saved.grid
    local segments = g.radialSegments
    local maxR = g.length

    local r = g.step
    while r <= maxR + 0.001 do
        local major = IsMajor(r)

        for i = 0, segments - 1 do
            local a1 = (i / segments) * 2 * PI
            local a2 = ((i + 1) / segments) * 2 * PI

            AddGridLine(
                math.sin(a1) * r,
                math.cos(a1) * r,
                math.sin(a2) * r,
                math.cos(a2) * r,
                major
            )
        end

        if major then
            AddLabel(tostring(math.floor(r)), 0, r)
        end

        r = r + g.step
    end

    for i = 0, g.radialSpokes - 1 do
        local a = (i / g.radialSpokes) * 2 * PI
        AddGridLine(
            0,
            0,
            math.sin(a) * maxR,
            math.cos(a) * maxR,
            true
        )
    end
end

local function GetPresetState(source, id, zone)
    GP.saved.presetStates[source] = GP.saved.presetStates[source] or {}

    local states = GP.saved.presetStates[source]

    if not states[id] then
        states[id] = {
            enabled = false,
            renderMode = "both", -- "outline", "fill", "both", "none"
            lineColor = ColorCopy(zone.lineColor or DEFAULT_ZONE_LINE_COLOR),
            fillColor = ColorCopy(zone.fillColor or DEFAULT_ZONE_FILL_COLOR),
        }
    else
        MergeDefaults(states[id], {
            enabled = false,
            renderMode = "both",
            lineColor = ColorCopy(zone.lineColor or DEFAULT_ZONE_LINE_COLOR),
            fillColor = ColorCopy(zone.fillColor or DEFAULT_ZONE_FILL_COLOR),
        })
    end

    return states[id]
end

local function GetBuiltInZones()
    local db = GP.Database or {}
    return db.zones or {}
end

local function GetBuiltInOrder()
    local db = GP.Database or {}
    return db.order or {}
end

function GP.RebuildGeometry()
    ClearGeometry()
    CreateWorldWindow()

    if GP.saved.customized.enabled then
        local z = GP.saved.customized
        local state = {
            enabled = true,
            renderMode = z.fillEnabled and "both" or "outline",
            lineColor = z.lineColor,
            fillColor = z.fillColor,
        }

        AddZoneGeometry("customized", z, state)
    end

    local builtinZones = GetBuiltInZones()
    for _, id in ipairs(GetBuiltInOrder()) do
        local zone = builtinZones[id]
        local state = GetPresetState("builtin", id, zone)
        AddZoneGeometry("builtin:" .. id, zone, state)
    end

    if GP.userZones and GP.userZones.zones then
        for _, id in ipairs(GP.userZones.order or {}) do
            local zone = GP.userZones.zones[id]
            local state = GetPresetState("custom", id, zone)
            AddZoneGeometry("custom:" .. id, zone, state)
        end
    end

    if GP.saved.grid.enabled then
        if GP.saved.grid.mode == "radial" then
            BuildRadialGrid()
        else
            BuildCartesianGrid()
        end
    end
end

local function LocalOffsetToWorld(wx, wy, wz, rightX, rightZ, forwardX, forwardZ, lxMeters, lzMeters, heightMeters)
    local lx = lxMeters * WORLD_UNITS_PER_METER
    local lz = lzMeters * WORLD_UNITS_PER_METER
    local h = heightMeters * WORLD_UNITS_PER_METER

    return
        wx + rightX * lx + forwardX * lz,
        wy + h,
        wz + rightZ * lx + forwardZ * lz
end

local function SetLine3D(line, x1, y1, z1, x2, y2, z2, thickness)
    local gx1, gy1, gz1 = WorldPositionToGuiRender3DPosition(x1, y1, z1)
    local gx2, gy2, gz2 = WorldPositionToGuiRender3DPosition(x2, y2, z2)

    if not gx1 or not gy1 or not gz1 or not gx2 or not gy2 or not gz2 then
        line:SetHidden(true)
        return
    end

    local mx = (gx1 + gx2) * 0.5
    local my = (gy1 + gy2) * 0.5
    local mz = (gz1 + gz2) * 0.5

    local dx = gx2 - gx1
    local dy = gy2 - gy1
    local dz = gz2 - gz1

    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len <= 0.001 then
        line:SetHidden(true)
        return
    end

    local rx = dx / len
    local ry = dy / len
    local rz = dz / len

    line:Set3DRenderSpaceOrigin(mx, my, mz)
    line:Set3DRenderSpaceRight(rx, ry, rz)
    line:Set3DRenderSpaceUp(0, 1, 0)
    line:Set3DRenderSpaceForward(0, 0, 1)

    line:Set3DLocalDimensions(len, thickness)
    line:SetHidden(false)
end

local function UpdateLine(line, wx, wy, wz, rightX, rightZ, forwardX, forwardZ)
    local d = line.gp

    local x1, y1, z1 = LocalOffsetToWorld(
        wx, wy, wz,
        rightX, rightZ,
        forwardX, forwardZ,
        d.x1, d.z1,
        GP.saved.height
    )

    local x2, y2, z2 = LocalOffsetToWorld(
        wx, wy, wz,
        rightX, rightZ,
        forwardX, forwardZ,
        d.x2, d.z2,
        GP.saved.height
    )

    if d.kind == "area" then
        local c = d.color
        line:SetColor(c.r, c.g, c.b, c.a)
        SetLine3D(line, x1, y1, z1, x2, y2, z2, 0.07)
    elseif d.kind == "areaFill" then
        local c = d.color
        line:SetColor(c.r, c.g, c.b, c.a)
        SetLine3D(line, x1, y1, z1, x2, y2, z2, (d.fillStep or 0.35) * 0.95)
    else
        local c = d.major and GP.saved.grid.majorColor or GP.saved.grid.color
        line:SetColor(c.r, c.g, c.b, c.a)
        SetLine3D(line, x1, y1, z1, x2, y2, z2, d.major and 0.06 or 0.025)
    end
end

local function UpdateLabel(label, wx, wy, wz, rightX, rightZ, forwardX, forwardZ, cameraHeading)
    local d = label.gp

    local x, y, z = LocalOffsetToWorld(
        wx, wy, wz,
        rightX, rightZ,
        forwardX, forwardZ,
        d.x, d.z,
        GP.saved.height + 0.35
    )

    local gx, gy, gz = WorldPositionToGuiRender3DPosition(x, y, z)
    if not gx then
        label:SetHidden(true)
        return
    end

    local c = GP.saved.labels.color
    label:SetColor(c.r, c.g, c.b, c.a)
    label:Set3DRenderSpaceOrigin(gx, gy, gz)
    label:Set3DRenderSpaceOrientation(0, cameraHeading, 0)
    label:SetHidden(false)
end

UpdateTransform = function()
    if not (GP.saved and GP.saved.enabled) then
        HideAll()
        return
    end

    local zoneId, wx, wy, wz = GetUnitRawWorldPosition("player")
    if not zoneId or not wx or not wy or not wz then
        HideAll()
        return
    end

    local heading
    if GetPlayerWorldFacing then
        heading = GetPlayerWorldFacing()
    else
        heading = GetPlayerCameraHeading()
    end

    local sinH = math.sin(heading)
    local cosH = math.cos(heading)

    local forwardX = -sinH
    local forwardZ = -cosH
    local rightX = -cosH
    local rightZ = sinH

    if GP.saved.grid.enabled then
        for _, line in ipairs(GP.gridLines) do
            UpdateLine(line, wx, wy, wz, rightX, rightZ, forwardX, forwardZ)
        end

        if GP.saved.labels.enabled then
            for _, label in ipairs(GP.labels) do
                UpdateLabel(label, wx, wy, wz, rightX, rightZ, forwardX, forwardZ, heading)
            end
        else
            HideList(GP.labels)
        end
    else
        HideList(GP.gridLines)
        HideList(GP.labels)
    end

    if ShouldShowCustomized() then
        for _, fill in ipairs(GP.areaFills) do
            UpdateLine(fill, wx, wy, wz, rightX, rightZ, forwardX, forwardZ)
        end

        for _, line in ipairs(GP.areaLines) do
            UpdateLine(line, wx, wy, wz, rightX, rightZ, forwardX, forwardZ)
        end
    else
        -- Only customized zone has trigger logic for now.
        -- Preset lines are already included in the same area tables, so do not hide here.
    end

    for _, fill in ipairs(GP.areaFills) do
        UpdateLine(fill, wx, wy, wz, rightX, rightZ, forwardX, forwardZ)
    end

    for _, line in ipairs(GP.areaLines) do
        UpdateLine(line, wx, wy, wz, rightX, rightZ, forwardX, forwardZ)
    end
end

local function OnSynergyChanged(_, synergyName)
    GP.synergyAvailable = synergyName ~= nil and synergyName ~= ""
end

local function SaveCustomizedZoneToAccountList()
    if not GP.userZones then return end

    local name = GP.newCustomZoneName or ""
    name = zo_strtrim(name)

    if name == "" then
        ChatMessage("GroundPaint: enter a custom zone name first.")
        return
    end

    local id = "custom_" .. tostring(GP.userZones.nextId or 1)
    GP.userZones.nextId = (GP.userZones.nextId or 1) + 1

    local z = GP.saved.customized

    GP.userZones.zones[id] = {
        displayName = name,
        shape = z.shape,
        alignment = z.alignment,
        width = z.width,
        length = z.length,
        fillStep = z.fillStep,
        lineColor = ColorCopy(z.lineColor),
        fillColor = ColorCopy(z.fillColor),
    }

    table.insert(GP.userZones.order, id)

    -- Default state remains disabled in all profiles.
    GP.newCustomZoneName = ""

    ChatMessage("GroundPaint: custom zone saved. /reloadui to show it in the menu.")
end

local function DeleteCustomZone(id)
    if not GP.userZones or not GP.userZones.zones then return end

    GP.userZones.zones[id] = nil

    for i = #GP.userZones.order, 1, -1 do
        if GP.userZones.order[i] == id then
            table.remove(GP.userZones.order, i)
        end
    end

    if GP.accountSaved and GP.accountSaved.presetStates and GP.accountSaved.presetStates.custom then
        GP.accountSaved.presetStates.custom[id] = nil
    end

    if GP.characterSaved and GP.characterSaved.presetStates and GP.characterSaved.presetStates.custom then
        GP.characterSaved.presetStates.custom[id] = nil
    end

    RebuildNow()
    ChatMessage("GroundPaint: custom zone deleted. /reloadui to refresh menu.")
end

local function InitSettings()
    local LAM = LibAddonMenu2
    if not LAM then
        ChatMessage("GroundPaint: LibAddonMenu-2.0 not found")
        return
    end

    local panelName = "GroundPaintOptions"

    local panelData = {
        type = "panel",
        name = "GroundPaint",
        displayName = "GroundPaint",
        author = "|c200000H|r|c400000e|r|c600000i|r|c800000K|r|c9f0000y|r|cbf0000o|r|cdf0000m|r|cff0000a|r",
        -- version = "1.2",
        slashCommand = "/groundpaint",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel(panelName, panelData)

    local function ColorPicker(name, colorTable, defaultTable, onSet)
        return {
            type = "colorpicker",
            name = name,
            getFunc = function()
                return colorTable.r, colorTable.g, colorTable.b, colorTable.a
            end,
            setFunc = function(r, g, b, a)
                colorTable.r = r
                colorTable.g = g
                colorTable.b = b
                colorTable.a = a or colorTable.a
                if onSet then onSet() end
            end,
            default = defaultTable,
        }
    end

    local function PresetControls(source, id, zone)
        local state = GetPresetState(source, id, zone)
        local name = zone.displayName or id

        return {
            type = "submenu",
            name = name,
            controls = {
                {
                    type = "description",
                    text = string.format(
                        "Shape: %s, Alignment: %s, Width: %.1f m, Length: %.1f m",
                        zone.shape or "square",
                        zone.alignment or "forward",
                        zone.width or 0,
                        zone.length or 0
                    ),
                },
                {
                    type = "checkbox",
                    name = "Enable",
                    getFunc = function() return state.enabled end,
                    setFunc = function(v)
                        state.enabled = v
                        RebuildNow()
                    end,
                    default = false,
                },
                {
                    type = "dropdown",
                    name = "Render mode",
                    choices = { "Outline only", "Fill only", "Outline + fill" },
                    choicesValues = { "outline", "fill", "both" },
                    getFunc = function() return state.renderMode end,
                    setFunc = function(v)
                        state.renderMode = v
                        RebuildNow()
                    end,
                    default = "both",
                    disabled = function() return not state.enabled end,
                },
                ColorPicker(
                    "Outline color / opacity",
                    state.lineColor,
                    zone.lineColor or DEFAULT_ZONE_LINE_COLOR,
                    RebuildNow
                ),
                ColorPicker(
                    "Fill color / opacity",
                    state.fillColor,
                    zone.fillColor or DEFAULT_ZONE_FILL_COLOR,
                    RebuildNow
                ),
            },
        }
    end

    local options = {
        {
            type = "description",
            text =
                -- "|c888888— \"How far can I go to damage with my BEAM?\"\n" ..
                -- "— \"Why did the tank get NO heal???\"\n" ..
                -- "— \"How to proc this duck-duck Alkosh???\"|r\n"..                
                -- "Sounds familiar, doesn't it?\n"..
                -- "So, sometimes it's about your positioning. And during the HOT fight it is not always easy to estimate the correct position.\n"..
                -- "That's why I have made this addon!\n\n"..
                "|c00FF00What it CAN do:|r\n" ..
                "• Draw a cartesian or radial grid\n" ..
                "• Draw your custom AoE\n" ..
                "• Draw some skill and set AoEs\n\n" ..
                "|cFF4444What it CANNOT do:|r\n"..
                "• Recognize your sets and casted skills (I am too lazy :P)\n" ..
                "• Automatically improve your damage (you still have to move by yourself)\n" ..
                -- "Created by |c200000H|r|c400000e|r|c600000i|r|c800000K|r|c9f0000y|r|cbf0000o|r|cdf0000m|r|cff0000a|r\n" ..
                "_________________________________________________________\n"
        },

        { --enable
            type = "checkbox",
            name = "Enable addon",
            getFunc = function() return GP.saved.enabled end,
            setFunc = function(v)
                GP.saved.enabled = v
                if not v then HideAll() end
            end,
            default = PROFILE_DEFAULTS.enabled,
        },
        { --AW
            type = "checkbox",
            name = "Account-wide settings",
            tooltip =
                "If ON, uses the same settings for all characters.\n" ..
                "If OFF, settings are saved separately per character.\n\n" ..
                "|cFF6666CAUTION!!! Existing character settings are not deleted.\nYou have to |cFFFFFF/reloadui|r|cFF6666 to switch between these regimes.|r",
            getFunc = function()
                return GP.meta.accountWide
            end,
            setFunc = function(v)
                GP.meta.accountWide = v
                ChatMessage("GroundPaint: /reloadui to apply account-wide setting.")
            end,
            default = META_DEFAULTS.accountWide,
        },
        { --height
            type = "slider",
            name = "Height",
            min = 0,
            max = 5,
            step = 0.1,
            getFunc = function() return GP.saved.height end,
            setFunc = function(v) GP.saved.height = v end,
            default = PROFILE_DEFAULTS.height,
        },
        { --grid
            type = "submenu",
            name = "Grid",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable grid",
                    getFunc = function() return GP.saved.grid.enabled end,
                    setFunc = function(v)
                        GP.saved.grid.enabled = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.grid.enabled,
                },
                {
                    type = "dropdown",
                    name = "Grid mode",
                    choices = { "Cartesian", "Radial" },
                    choicesValues = { "cartesian", "radial" },
                    getFunc = function() return GP.saved.grid.mode end,
                    setFunc = function(v)
                        GP.saved.grid.mode = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.grid.mode,
                    disabled = function() return not GP.saved.grid.enabled end,
                },
                {
                    type = "slider",
                    name = "Grid width",
                    min = 1,
                    max = 50,
                    step = 1,
                    getFunc = function() return GP.saved.grid.width end,
                    setFunc = function(v)
                        GP.saved.grid.width = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.grid.width,
                    disabled = function() return not GP.saved.grid.enabled end,
                },
                {
                    type = "slider",
                    name = "Grid length",
                    min = 1,
                    max = 80,
                    step = 1,
                    getFunc = function() return GP.saved.grid.length end,
                    setFunc = function(v)
                        GP.saved.grid.length = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.grid.length,
                    disabled = function() return not GP.saved.grid.enabled end,
                },
                ColorPicker("Minor grid color / opacity", GP.saved.grid.color, PROFILE_DEFAULTS.grid.color),
                ColorPicker("Major grid color / opacity", GP.saved.grid.majorColor, PROFILE_DEFAULTS.grid.majorColor),
            },
        },
        { --labels
            type = "submenu",
            name = "Distance Labels",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable labels",
                    getFunc = function() return GP.saved.labels.enabled end,
                    setFunc = function(v)
                        GP.saved.labels.enabled = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.labels.enabled,
                },
                ColorPicker("Label color / opacity", GP.saved.labels.color, PROFILE_DEFAULTS.labels.color),
                {
                    type = "slider",
                    name = "Label size",
                    min = 0.2,
                    max = 10,
                    step = 0.1,
                    getFunc = function() return GP.saved.labels.size end,
                    setFunc = function(v)
                        GP.saved.labels.size = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.labels.size,
                    disabled = function() return not GP.saved.labels.enabled end,
                },
            },
        },
        { --custom
            type = "submenu",
            name = "Customized AoE",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable customized AoE",
                    getFunc = function() return GP.saved.customized.enabled end,
                    setFunc = function(v)
                        GP.saved.customized.enabled = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.customized.enabled,
                },
                {
                    type = "checkbox",
                    name = "Enable fill",
                    getFunc = function() return GP.saved.customized.fillEnabled end,
                    setFunc = function(v)
                        GP.saved.customized.fillEnabled = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.customized.fillEnabled,
                    disabled = function() return not GP.saved.customized.enabled end,
                },
                {
                    type = "dropdown",
                    name = "Shape",
                    choices = { "Square", "Cone", "Cone 2", "Ellipse" },
                    choicesValues = { "square", "cone", "cone2", "ellipse" },
                    getFunc = function() return GP.saved.customized.shape end,
                    setFunc = function(v)
                        GP.saved.customized.shape = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.customized.shape,
                    disabled = function() return not GP.saved.customized.enabled end,
                },
                {
                    type = "dropdown",
                    name = "Alignment",
                    choices = { "In front", "Centered on player" },
                    choicesValues = { "forward", "center" },
                    getFunc = function() return GP.saved.customized.alignment end,
                    setFunc = function(v)
                        GP.saved.customized.alignment = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.customized.alignment,
                    disabled = function() return not GP.saved.customized.enabled end,
                },
                {
                    type = "slider",
                    name = "Width",
                    min = 1,
                    max = 50,
                    step = 1,
                    getFunc = function() return GP.saved.customized.width end,
                    setFunc = function(v)
                        GP.saved.customized.width = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.customized.width,
                    disabled = function() return not GP.saved.customized.enabled end,
                },
                {
                    type = "slider",
                    name = "Length",
                    min = 1,
                    max = 80,
                    step = 1,
                    getFunc = function() return GP.saved.customized.length end,
                    setFunc = function(v)
                        GP.saved.customized.length = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.customized.length,
                    disabled = function() return not GP.saved.customized.enabled end,
                },
                {
                    type = "slider",
                    name = "Fill density",
                    min = 0.1,
                    max = 1.5,
                    step = 0.05,
                    getFunc = function() return GP.saved.customized.fillStep end,
                    setFunc = function(v)
                        GP.saved.customized.fillStep = v
                        RebuildNow()
                    end,
                    default = PROFILE_DEFAULTS.customized.fillStep,
                    disabled = function()
                        return not GP.saved.customized.enabled or not GP.saved.customized.fillEnabled
                    end,
                },
                ColorPicker("Outline color / opacity", GP.saved.customized.lineColor, PROFILE_DEFAULTS.customized.lineColor, RebuildNow),
                ColorPicker("Fill color / opacity", GP.saved.customized.fillColor, PROFILE_DEFAULTS.customized.fillColor, RebuildNow),
                {
                    type = "editbox",
                    name = "Save as account-wide custom AoE",
                    tooltip = "Saved custom AoEs are available on all characters, but disabled by default in each profile.",
                    getFunc = function() return GP.newCustomZoneName or "" end,
                    setFunc = function(v)
                        GP.newCustomZoneName = v
                    end,
                    isMultiline = false,
                },
                {
                    type = "button",
                    name = "Save customized AoE",
                    func = SaveCustomizedZoneToAccountList,
                },
            },
        },
        { --silent
            type = "checkbox",
            name = "Silent mode",
            tooltip = "If ON, disables message logs in chat.",
            getFunc = function() return GP.saved.silent end,
            setFunc = function(v)
                GP.saved.silent = v
            end,
            default = PROFILE_DEFAULTS.silent,
        },
    }

    local builtinZones = GetBuiltInZones()
    local builtinControls = {}

    for _, id in ipairs(GetBuiltInOrder()) do
        if builtinZones[id] then
            table.insert(builtinControls, PresetControls("builtin", id, builtinZones[id]))
        end
    end

    if #builtinControls > 0 then
        table.insert(options, {
            type = "submenu",
            name = "Skills and Setups AoEs",
            controls = builtinControls,
        })
    end

    local customControls = {}

    if GP.userZones and GP.userZones.zones then
        for _, id in ipairs(GP.userZones.order or {}) do
            local zone = GP.userZones.zones[id]

            if zone then
                local controls = PresetControls("custom", id, zone)

                table.insert(controls.controls, {
                    type = "button",
                    name = "Delete this custom AoE",
                    warning = "This deletes the AoE definition account-wide.",
                    func = function()
                        DeleteCustomZone(id)
                    end,
                })

                table.insert(customControls, controls)
            end
        end
    end

    if #customControls > 0 then
        table.insert(options, {
            type = "submenu",
            name = "Saved custom zones",
            controls = customControls,
        })
    end

    LAM:RegisterOptionControls(panelName, options)
end

local function MigrateOldSavedVars()
    if GP.saved.area and not GP.saved.customized then
        GP.saved.customized = GP.saved.area
        GP.saved.area = nil
    end

    if GP.saved.width ~= nil then
        GP.saved.customized.width = GP.saved.width
        GP.saved.width = nil
    end

    if GP.saved.length ~= nil then
        GP.saved.customized.length = GP.saved.length
        GP.saved.length = nil
    end

    if GP.saved.shape ~= nil then
        GP.saved.customized.shape = GP.saved.shape
        GP.saved.shape = nil
    end

    if GP.saved.color ~= nil then
        GP.saved.customized.lineColor = GP.saved.color
        GP.saved.color = nil
    end

    if GP.saved.trigger ~= nil then
        GP.saved.customized.trigger = GP.saved.trigger
        GP.saved.trigger = nil
    end

    if GP.saved.grid.alpha ~= nil then
        GP.saved.grid.color.a = GP.saved.grid.alpha
        GP.saved.grid.alpha = nil
    end

    if GP.saved.grid.majorAlpha ~= nil then
        GP.saved.grid.majorColor.a = GP.saved.grid.majorAlpha
        GP.saved.grid.majorAlpha = nil
    end
end

local function LoadSavedVars()
    GP.meta = ZO_SavedVars:NewAccountWide(
        "GroundPaintMetaSavedVars",
        1,
        nil,
        DeepCopy(META_DEFAULTS)
    )

    GP.accountSaved = ZO_SavedVars:NewAccountWide(
        "GroundPaintAccountSavedVars",
        1,
        nil,
        DeepCopy(PROFILE_DEFAULTS)
    )

    GP.characterSaved = ZO_SavedVars:NewCharacterIdSettings(
        "GroundPaintCharacterSavedVars",
        1,
        nil,
        DeepCopy(PROFILE_DEFAULTS)
    )

    GP.userZones = ZO_SavedVars:NewAccountWide(
        "GroundPaintUserZonesSavedVars",
        1,
        nil,
        DeepCopy(USER_ZONES_DEFAULTS)
    )

    MergeDefaults(GP.meta, META_DEFAULTS)
    MergeDefaults(GP.accountSaved, PROFILE_DEFAULTS)
    MergeDefaults(GP.characterSaved, PROFILE_DEFAULTS)
    MergeDefaults(GP.userZones, USER_ZONES_DEFAULTS)

    if GP.meta.accountWide then
        GP.saved = GP.accountSaved
    else
        GP.saved = GP.characterSaved
    end

    MergeDefaults(GP.saved, PROFILE_DEFAULTS)
    MigrateOldSavedVars()
    MergeDefaults(GP.saved, PROFILE_DEFAULTS)
end

local function OnPlayerActivated()
    -- After teleport/loading screen ESO can need a moment before 3D world
    -- render space starts accepting fresh coordinates again.
    zo_callLater(RecreateAfterTeleport, 500)
    zo_callLater(RecreateAfterTeleport, 1500)
    zo_callLater(RecreateAfterTeleport, 3000)
end

local function OnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end

    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    LoadSavedVars()

    GP.areaLines = {}
    GP.areaFills = {}
    GP.gridLines = {}
    GP.labels = {}

    GP.nextLineIndex = 0
    GP.nextLabelIndex = 0
    GP.worldWindowGeneration = 0
    GP.synergyAvailable = false
    GP.newCustomZoneName = ""

    CreateWorldWindow()
    GP.RebuildGeometry()
    InitSettings()

    EM:RegisterForUpdate(
        ADDON_NAME .. "_Update",
        GP.saved.updateMs,
        UpdateTransform
    )

    EM:RegisterForEvent(
        ADDON_NAME .. "_Activated",
        EVENT_PLAYER_ACTIVATED,
        OnPlayerActivated
    )

    if EVENT_SYNERGY_ABILITY_CHANGED then
        EM:RegisterForEvent(
            ADDON_NAME .. "_Synergy",
            EVENT_SYNERGY_ABILITY_CHANGED,
            OnSynergyChanged
        )
    end

    ChatMessage("GroundPaint loaded")
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoaded)
