local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts


---------------------------------------------------------------------
-- Profile data
---------------------------------------------------------------------
function CAE.AddCircleToProfile(rgb, color, radius, yOffset, forwardOffset, conditionalAbilityId, conditionalSetId, conditionalEffectId, activeBarOnly, depthBuffers, pitch, solid, useCameraHeading)
    local profile = CAE.profiles[CAE.csvs.currentProfile]

    local index = CAE.FindFreeId(profile.circles)
    profile.circles[index] = {
        type = CAE.CIRCLE,
        rgb = rgb,
        color = color,
        radius = radius,
        yOffset = yOffset,
        forwardOffset = forwardOffset,
        conditionalAbilityId = ZO_DeepTableCopy(conditionalAbilityId),
        conditionalSetId = ZO_DeepTableCopy(conditionalSetId),
        conditionalEffectId = ZO_DeepTableCopy(conditionalEffectId),
        activeBarOnly = activeBarOnly,
        depthBuffers = depthBuffers,
        pitch = pitch,
        solid = solid,
        useCameraHeading = useCameraHeading,
    }

    CAE.msg(zo_strformat("Added circle of radius <<1>> to profile <<2>>", radius, profile.profileName))

    return index
end

function CAE.AddRectangleToProfile(rgb, color, fillColor, width, height, edgeSize, yOffset, forwardOffset, conditionalAbilityId, conditionalSetId, conditionalEffectId, activeBarOnly, depthBuffers, pitch, solid, useCameraHeading)
    local profile = CAE.profiles[CAE.csvs.currentProfile]

    local index = CAE.FindFreeId(profile.circles)
    profile.circles[index] = {
        type = CAE.RECTANGLE,
        rgb = rgb,
        color = color,
        fillColor = fillColor,
        radius = width, -- width is called radius, just to reuse the circle property
        height = height,
        edgeSize = edgeSize,
        yOffset = yOffset,
        forwardOffset = forwardOffset,
        conditionalAbilityId = ZO_DeepTableCopy(conditionalAbilityId),
        conditionalSetId = ZO_DeepTableCopy(conditionalSetId),
        conditionalEffectId = ZO_DeepTableCopy(conditionalEffectId),
        activeBarOnly = activeBarOnly,
        depthBuffers = depthBuffers,
        pitch = pitch,
        solid = solid,
        useCameraHeading = useCameraHeading,
    }

    CAE.msg(zo_strformat("Added rectangle <<1>> × <<2>> to profile <<3>>", height, width, profile.profileName))

    return index
end

function CAE.AddConeToProfile(rgb, color, fillColor, radius, height, yOffset, forwardOffset, conditionalAbilityId, conditionalSetId, conditionalEffectId, activeBarOnly, depthBuffers, pitch, solid, useCameraHeading, coneStyle)
    local profile = CAE.profiles[CAE.csvs.currentProfile]

    local index = CAE.FindFreeId(profile.circles)
    profile.circles[index] = {
        type = CAE.CONE,
        rgb = rgb,
        color = color,
        fillColor = fillColor,
        radius = radius, -- width is called radius, just to reuse the circle property
        height = height,
        yOffset = yOffset,
        forwardOffset = forwardOffset,
        conditionalAbilityId = ZO_DeepTableCopy(conditionalAbilityId),
        conditionalSetId = ZO_DeepTableCopy(conditionalSetId),
        conditionalEffectId = ZO_DeepTableCopy(conditionalEffectId),
        activeBarOnly = activeBarOnly,
        depthBuffers = depthBuffers,
        pitch = pitch,
        solid = solid,
        useCameraHeading = useCameraHeading,
        coneStyle = coneStyle,
    }

    CAE.msg(zo_strformat("Added cone <<1>> × <<2>>° to profile <<3>>", height, pitch / math.pi * 180, profile.profileName))

    return index
end

local function CopyShapeToProfile(shapeData)
    local profile = CAE.profiles[CAE.csvs.currentProfile]

    local index = CAE.FindFreeId(profile.circles)
    profile.circles[index] = ZO_DeepTableCopy(shapeData)

    CAE.msg(zo_strformat("Imported <<1>> |cAAAAAAto profile <<2>>", CAE.ColorShapeText(shapeData), profile.profileName))
    return index
end

function CAE.AddPresetToProfile(presetName)
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    CAE.msg(zo_strformat("Importing <<1>> to profile <<2>>", presetName, profile.profileName))

    local preset = CAE.PresetShapes[presetName]
    local index
    if (preset[1]) then
        -- multi
        for _, shapeData in ipairs(preset) do
            index = CopyShapeToProfile(shapeData)
        end
    else
        index = CopyShapeToProfile(preset)
    end

    -- So we don't have to add new fields to presets all the time
    CAE.FillMissingDefaults()

    -- Return any index
    return index
end

function CAE.RemoveShapeFromProfile(index)
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    CAE.msg(zo_strformat("Removing shape of size <<1>> from profile <<2>>", profile.circles[index].radius, profile.profileName))
    profile.circles[index] = nil
end


---------------------------------------------------------------------
-- Loading / Drawing
---------------------------------------------------------------------
local currentKeys = {} -- {[id] = {1, 2, 3}}
local function CleanShapes()
    for _, keys in pairs(currentKeys) do
        for _, key in ipairs(keys) do
            Crutch.Drawing.RemoveWorldTexture(key)
        end
    end
    ZO_ClearTable(currentKeys)
end

local function GetHeading(useCameraHeading)
    if (useCameraHeading) then
        return GetPlayerCameraHeading()
    else
        local _, _, heading = GetMapPlayerPosition("player")
        return heading
    end
end

local function CreateCircle(id, radius, rgb, color, yOffset, depthBuffers, forwardOffset, pitch, solid, useCameraHeading)
    local _, x, y, z = GetUnitRawWorldPosition("player")

    -- Places circle at player's feet
    local function CircleFunc(icon)
        if (not CAE.freeze) then
            -- Make circle follow the player
            local _, pX, y, pZ = GetUnitRawWorldPosition("player")
            local heading = GetHeading(useCameraHeading)
            local x = math.sin(heading) * -forwardOffset + pX
            local z = math.cos(heading) * -forwardOffset + pZ

            icon:SetPosition(x, y + yOffset, z)
            icon:SetOrientation(pitch - math.pi/2, heading, 0)
        end

        -- Make color change every update
        if (rgb) then
            local time = GetGameTimeMilliseconds() % 2000 / 2000
            local r, g, b = Crutch.ConvertHSLToRGB(time, 1, 0.5)
            icon:SetColor(r, g, b, color[4])
        end
    end

    local key = Crutch.Drawing.CreateWorldTexture(
        solid and "CrutchAlertsExtensions/assets/solidcircle.dds" or "CrutchAlerts/assets/floor/circle.dds",
        x,
        y + yOffset,
        z,
        radius * 2,
        radius * 2,
        color,
        depthBuffers,
        false,
        {pitch - math.pi/2, 0, 0},
        CircleFunc)

    if (not currentKeys[id]) then
        currentKeys[id] = {}
    end
    table.insert(currentKeys[id], key)
end

local function CreateRectangle(id, width, height, edgeSize, rgb, color, fillColor, yOffset, depthBuffers, forwardOffset, pitch, solid, useCameraHeading)
    local _, pX, y, pZ = GetUnitRawWorldPosition("player")
    local heading = GetHeading(useCameraHeading)
    local x = math.sin(heading) * -forwardOffset + pX
    local z = math.cos(heading) * -forwardOffset + pZ

    local function RectangleFunc(icon)
        if (not CAE.freeze) then
            -- Make it follow the player
            local _, pX, y, pZ = GetUnitRawWorldPosition("player")
            local heading = GetHeading(useCameraHeading)
            local x = math.sin(heading) * -forwardOffset + pX
            local z = math.cos(heading) * -forwardOffset + pZ

            icon:SetPosition(x, y + yOffset, z)
            icon:SetOrientation(pitch - math.pi/2, heading, 0)
        end

        -- Make color change every update
        if (rgb) then
            local time = GetGameTimeMilliseconds() % 2000 / 2000
            local r, g, b = Crutch.ConvertHSLToRGB(time, 1, 0.5)
            if (solid) then
                icon:SetColor(r, g, b, color[4])
            else
                icon:SetBackdropColors(nil, nil, nil, nil, r, g, b, color[4])
            end
        end
    end

    local key
    if (solid) then
        key = Crutch.Drawing.CreateWorldTexture(
            "CrutchAlerts/assets/floor/square.dds",
            x,
            y + yOffset,
            z,
            width,
            height,
            color,
            depthBuffers,
            false,
            {pitch - math.pi/2, heading, 0},
            RectangleFunc)
    else
        key = Crutch.Drawing.CreateSpaceControl(
            x,
            y + yOffset,
            z,
            false,
            {pitch - math.pi/2, heading, 0},
            {
                backdrop = {
                    width = width * 100,
                    height = height * 100,
                    centerColor = fillColor,
                    edgeColor = color,
                    edgeSize = edgeSize,
                },
            },
            RectangleFunc)
    end

    if (not currentKeys[id]) then
        currentKeys[id] = {}
    end
    table.insert(currentKeys[id], key)
end

local function CreateCone(id, radius, height, rgb, color, yOffset, depthBuffers, forwardOffset, angle, useCameraHeading, coneStyle)
    local _, pX, y, pZ = GetUnitRawWorldPosition("player")
    local heading = GetHeading(useCameraHeading)
    local x = math.sin(heading) * -forwardOffset + pX
    local z = math.cos(heading) * -forwardOffset + pZ

    -- 1 = lines only, 2 = arc only, 3 = lines+arc
    local showLines = (coneStyle == 1 or coneStyle == 3) -- maybe eventually bitwise if more options in future (solid fill?)
    local showArc = (coneStyle == 2 or coneStyle == 3)

    if (not currentKeys[id]) then
        currentKeys[id] = {}
    end

    if (showLines) then
        local function EndpointsFunc(offsetAngle)
            if (not CAE.freeze) then
                -- Make it follow the player
                local _, pX, y, pZ = GetUnitRawWorldPosition("player")
                local heading = GetHeading(useCameraHeading)
                local x = math.sin(heading) * -forwardOffset + pX
                local z = math.cos(heading) * -forwardOffset + pZ

                local x1 = math.sin(heading + offsetAngle) * -radius * 100 + x
                local z1 = math.cos(heading + offsetAngle) * -radius * 100 + z

                -- Crutch.dbgSpam(zo_strformat("<<1>> <<2>> ; <<3>> <<4>>", x, z, x1, z1))
                return x, y + yOffset, z, x1, y + yOffset, z1
            end
        end

        local function LineFunc(icon)
            -- Make color change every update
            if (rgb) then
                local time = GetGameTimeMilliseconds() % 2000 / 2000
                local r, g, b = Crutch.ConvertHSLToRGB(time, 1, 0.5)
                icon:SetColor(r, g, b, color[4])
            end
        end

        local key1 = Crutch.Drawing.CreateLine(
            x,
            y + yOffset,
            z,
            x,
            y + yOffset,
            z,
            height / 100,
            color,
            depthBuffers,
            LineFunc,
            function() return EndpointsFunc(angle / 2) end)

        local key2 = Crutch.Drawing.CreateLine(
            x,
            y + yOffset,
            z,
            x,
            y + yOffset,
            z,
            height / 100,
            color,
            depthBuffers,
            LineFunc,
            function() return EndpointsFunc(-angle / 2) end)

        table.insert(currentKeys[id], key1)
        table.insert(currentKeys[id], key2)
    end

    if (showArc) then
        local function ArcFunc(icon)
            if (not CAE.freeze) then
                -- Make it follow the player
                local _, pX, y, pZ = GetUnitRawWorldPosition("player")
                local heading = GetHeading(useCameraHeading)
                local x = math.sin(heading) * -forwardOffset + pX
                local z = math.cos(heading) * -forwardOffset + pZ

                icon:SetPosition(x, y + yOffset, z)
                icon:SetOrientation(-math.pi/2, heading + angle / 2, 0)
            end

            -- Make color change every update
            if (rgb) then
                local time = GetGameTimeMilliseconds() % 2000 / 2000
                local r, g, b = Crutch.ConvertHSLToRGB(time, 1, 0.5)
                icon:SetCooldownColor(r, g, b, color[4])
            end
        end

        local key3 = Crutch.Drawing.CreateSpaceControl(
            x,
            y + yOffset,
            z,
            false,
            {-math.pi/2, heading, 0},
            {
                cooldown = {
                    progress = angle / math.pi / 2,
                    color = color,
                    size = radius * 2,
                },
            },
            ArcFunc)
    
        table.insert(currentKeys[id], key3)
    end
end

local function CreateShapeById(id)
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    local shapeData = profile.circles[id]
    -- TODO: prob just pass in the shapeData at this point
    if (shapeData.type == CAE.CIRCLE) then
        CreateCircle(id, shapeData.radius, shapeData.rgb, shapeData.color, shapeData.yOffset, shapeData.depthBuffers, shapeData.forwardOffset, shapeData.pitch, shapeData.solid, shapeData.useCameraHeading)
    elseif (shapeData.type == CAE.RECTANGLE) then
        CreateRectangle(id, shapeData.radius, shapeData.height, shapeData.edgeSize, shapeData.rgb, shapeData.color, shapeData.fillColor, shapeData.yOffset, shapeData.depthBuffers, shapeData.forwardOffset, shapeData.pitch, shapeData.solid, shapeData.useCameraHeading)
    elseif (shapeData.type == CAE.CONE) then
        CreateCone(id, shapeData.radius, shapeData.height, shapeData.rgb, shapeData.color, shapeData.yOffset, shapeData.depthBuffers, shapeData.forwardOffset, shapeData.pitch, shapeData.useCameraHeading, shapeData.coneStyle)
    end
end

local function ShowShape(id)
    if (currentKeys[id] and #currentKeys[id] > 0) then return end -- already showing
    CreateShapeById(id)
end

local function HideShape(id)
    if (not currentKeys[id]) then return end -- already hidden
    for _, key in ipairs(currentKeys[id]) do
        Crutch.Drawing.RemoveWorldTexture(key)
    end
    ZO_ClearTable(currentKeys[id])
end

local function UpdateShapes()
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    for id, shapeData in pairs(profile.circles) do
        if (CAE.ShouldShapeBeShown(shapeData)) then
            ShowShape(id)
        else
            HideShape(id)
        end
    end
end
CAE.UpdateShapes = UpdateShapes


---------------------------------------------------------------------
-- Listeners for profile change
-- TODO: move to profiles.lua?
---------------------------------------------------------------------
local profileListeners = {}

function CAE.RegisterProfileChangedListener(name, func)
    profileListeners[name] = func
end

function CAE.UnregisterProfileChangedListener(name)
    profileListeners[name] = nil
end

local function FireProfileChanged(isSame)
    for _, listener in pairs(profileListeners) do
        listener(isSame)
    end
end


---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
local prevProfile = -2
local function LoadCurrentProfile(forceChange)
    CleanShapes()
    UpdateShapes()

    local profile = CAE.profiles[CAE.csvs.currentProfile]

    local isSame = prevProfile == CAE.csvs.currentProfile
    prevProfile = CAE.csvs.currentProfile

    if (not isSame) then
        Crutch.dbgOther("Loaded profile " .. profile.profileName)
    end

    if (forceChange) then
        isSame = false
    end
    FireProfileChanged(isSame)
end
CAE.LoadCurrentProfile = LoadCurrentProfile

function CAE.InitializeShapes()
    LoadCurrentProfile()
end
