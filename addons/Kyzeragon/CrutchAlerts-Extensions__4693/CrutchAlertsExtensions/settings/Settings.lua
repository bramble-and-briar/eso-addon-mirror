local CAE = CrutchAlertsExtensions


---------------------------------------------------------------------
local currentRgb = false
local currentColor = {1, 1, 1, 1}
local currentFillColor = {1, 1, 1, 0}
local currentSize = 8
local currentHeight = 8
local currentEdgeSize = 8
local currentYOffset = 5
local currentForwardOffset = 5
local currentPitch = 0
local currentConditionalAbility = {}
local currentConditionalSetId = {}
local currentConditionalEffectId = {}
local currentActiveBarOnly = false
local currentDepthBuffers = false
local currentSolid = false
local currentUseCameraHeading = true
local currentConeStyle = 3

local currentShape, currentLine

local profileNames = {}
local profileIds = {}
local function RefreshProfiles()
    ZO_ClearTable(profileNames)
    ZO_ClearTable(profileIds)
    for id, data in pairs(CAE.profiles) do
        table.insert(profileNames, data.profileName)
        table.insert(profileIds, id)
    end

    CAE_ProfilesDropdown:UpdateChoices(profileNames, profileIds)
end

local function ColorToHexString(color)
    return string.format("%02x%02x%02x",
        math.floor(color[1] * 255),
        math.floor(color[2] * 255),
        math.floor(color[3] * 255))
end

local function ColorShapeName(name, rgb, color)
    if (rgb) then
        return CAE.Utils.Rainbowify(name)
    else
        return "|c" .. ColorToHexString(color) .. name
    end
end

local function GetAnyConditionalName(shapeData)
    if (shapeData.conditionalAbilityId and #(shapeData.conditionalAbilityId) > 0) then
        return GetAbilityName(shapeData.conditionalAbilityId[1])
    elseif (shapeData.conditionalSetId and #(shapeData.conditionalSetId) > 0) then
        local _, setName = GetItemSetInfo(shapeData.conditionalSetId[1])
        return setName
    elseif (shapeData.conditionalEffectId and #(shapeData.conditionalEffectId) > 0) then
        return GetAbilityName(shapeData.conditionalEffectId[1])
    end
end

local function ColorShapeText(shapeData)
    local text = ""
    if (shapeData.type == CAE.CIRCLE) then
        text = zo_strformat("<<1>>|r <<2>>m", ColorShapeName("Circle", shapeData.rgb, shapeData.color), shapeData.radius)
    elseif (shapeData.type == CAE.RECTANGLE) then
        text = zo_strformat("<<1>>|r: <<2>>m × <<3>>m", ColorShapeName("Rectangle", shapeData.rgb, shapeData.color), shapeData.radius, shapeData.height)
    elseif (shapeData.type == CAE.CONE) then
        text = zo_strformat("<<1>>|r: <<2>>m × <<3>>°", ColorShapeName("Cone", shapeData.rgb, shapeData.color), shapeData.radius, zo_round(shapeData.pitch / math.pi * 180))
    end

    local conditionalName = GetAnyConditionalName(shapeData)
    if (conditionalName) then
        text = string.format("%s |c888888- %s|r", text, conditionalName)
    end

    return text
end
CAE.ColorShapeText = ColorShapeText

local shapeNames = {}
local shapeIds = {}
local function RefreshShapes()
    ZO_ClearTable(shapeNames)
    ZO_ClearTable(shapeIds)
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    for id, data in pairs(profile.circles) do
        table.insert(shapeNames, ColorShapeText(data))
        table.insert(shapeIds, id)
    end

    CAE_ShapesDropdown:UpdateChoices(shapeNames, shapeIds)
end

---------------------------------------------------------------------
local currentPlayer1, currentPlayer2
local currentLineColor = {1, 1, 1, 1}
local currentSecondLineColor = {1, 1, 1, 1}
local currentShowDistance = false
local currentUseGradient = false

local lineNames = {}
local lineIds = {}
local function RefreshLines()
    ZO_ClearTable(lineNames)
    ZO_ClearTable(lineIds)

    local profile = CAE.profiles[CAE.csvs.currentProfile]
    for id, data in pairs(profile.lines) do
        table.insert(lineNames, zo_strformat("|c<<1>><<2>> - <<3>>", ColorToHexString(data.color), data.player1 or "self", data.player2 or "self"))
        table.insert(lineIds, id)
    end

    CAE_LinesDropdown:UpdateChoices(lineNames, lineIds)
end

---------------------------------------------------------------------
local function LoadShapeValues()
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    currentRgb = profile.circles[currentShape].rgb
    currentColor = profile.circles[currentShape].color
    currentFillColor = profile.circles[currentShape].fillColor or {1, 1, 1, 0}
    currentSize = profile.circles[currentShape].radius
    currentHeight = profile.circles[currentShape].height
    currentEdgeSize = profile.circles[currentShape].edgeSize
    currentYOffset = profile.circles[currentShape].yOffset
    currentForwardOffset = profile.circles[currentShape].forwardOffset
    currentPitch = profile.circles[currentShape].pitch
    currentConditionalAbility = ZO_DeepTableCopy(profile.circles[currentShape].conditionalAbilityId)
    currentConditionalSetId = ZO_DeepTableCopy(profile.circles[currentShape].conditionalSetId)
    currentConditionalEffectId = ZO_DeepTableCopy(profile.circles[currentShape].conditionalEffectId)
    currentActiveBarOnly = profile.circles[currentShape].activeBarOnly
    currentDepthBuffers = profile.circles[currentShape].depthBuffers
    currentSolid = profile.circles[currentShape].solid
    currentUseCameraHeading = profile.circles[currentShape].useCameraHeading
    currentConeStyle = profile.circles[currentShape].coneStyle
end

local function ResetCurrentValues()
    currentRgb = false
    currentColor = {1, 1, 1, 1}
    currentFillColor = {1, 1, 1, 0}
    currentSize = 8
    currentHeight = 8
    currentEdgeSize = 8
    currentYOffset = 5
    currentForwardOffset = 0
    currentPitch = 0
    ZO_ClearTable(currentConditionalAbility)
    ZO_ClearTable(currentConditionalSetId)
    ZO_ClearTable(currentConditionalEffectId)
    currentActiveBarOnly = false
    currentDepthBuffers = false
    currentSolid = false
    currentUseCameraHeading = true
    currentConeStyle = 3
end

local function ResetCurrentLineValues()
    currentPlayer1 = nil
    currentPlayer2 = nil
    currentLineColor = {1, 1, 1, 1}
    currentSecondLineColor = {1, 1, 1, 1}
    currentShowDistance = false
    currentUseGradient = false
end

local function ConcatTables(tab1, tab2)
    for _, v in ipairs(tab2) do
        table.insert(tab1, v)
    end
end


---------------------------------------------------------------------
local selectedPreset
local function BuildPresetShapes()
    local tab = {}
    for name, _ in pairs(CAE.PresetShapes) do
        table.insert(tab, name)
    end
    table.sort(tab)
    return tab
end

local function ClearProfileControls()
    currentShape = nil
    currentLine = nil
    ResetCurrentValues()
    ResetCurrentLineValues()
end


---------------------------------------------------------------------
function CAE.CreateSettingsMenu()
    local LAM = LibAddonMenu2
    local panelData = {
        type = "panel",
        name = "|c08BD1DCrutchAlerts Extensions|r",
        author = "Kyzeragon",
        version = CAE.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = "These are persistent settings that are saved in installation-wide profiles, which can be chosen on a per-character basis. The default <Empty> profile is provided for convenience, so you can turn off all shapes and lines by loading the empty profile. |c99FF99In order to add shapes, you must create a new profile.|r",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Current profile for " .. GetUnitName("player"),
            tooltip = "Choose a profile to edit, duplicate, or delete",
            choices = {},
            choicesValues = {},
            getFunc = function()
                RefreshProfiles()
                return CAE.csvs.currentProfile
            end,
            setFunc = function(value)
                CAE.csvs.currentProfile = value
                ClearProfileControls()
                CAE.LoadCurrentProfile()
                CAE.LoadCurrentLines()
            end,
            width = "full",
            reference = "CAE_ProfilesDropdown",
        },
        {
            type = "editbox",
            name = "Rename current profile",
            tooltip = "Rename the profile by changing this text",
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].profileName end,
            setFunc = function(name)
                if (not name or name == "") then return end

                CAE.profiles[CAE.csvs.currentProfile].profileName = name

                RefreshProfiles()
            end,
            isMultiline = false,
            isExtraWide = false,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow renaming default
        },
        {
            type = "button",
            name = "Create new profile",
            tooltip = "Create a new profile",
            func = function()
                ClearProfileControls()
                CAE.CreateProfile()
                RefreshProfiles()
                CAE.LoadCurrentProfile()
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Duplicate profile",
            tooltip = "Duplicate the current profile",
            func = function()
                ClearProfileControls()
                CAE.DuplicateProfile()
                RefreshProfiles()
                CAE.LoadCurrentProfile()
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Delete current profile",
            tooltip = "Delete the currently selected profile. This cannot be undone!",
            func = function()
                ClearProfileControls()
                CAE.DeleteProfile(CAE.csvs.currentProfile)
                RefreshProfiles()
                CAE.LoadCurrentProfile()
            end,
            warning = "Delete the currently selected profile. This cannot be undone!",
            isDangerous = true,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow deleting default
        },
    }
---------------------------------------------------------------------
    ConcatTables(optionsData, CAE.GetSynergySettings())
    ConcatTables(optionsData, CAE.GetUnitIconsSettings())
    ConcatTables(optionsData, CAE.GetDamagedEnemiesSettings())
    ConcatTables(optionsData, CAE.GetBossTriggersSettings())
---------------------------------------------------------------------
    ConcatTables(optionsData, {
        {
            type = "description",
            title = "|c08BD1DShapes|r",
            text = "Add or edit a shape here by clicking the Add button or selecting from the dropdown, then editing the properties.",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Current shape",
            choices = {},
            choicesValues = {},
            getFunc = function()
                RefreshShapes()
                return currentShape
            end,
            setFunc = function(value)
                currentShape = value
                local profile = CAE.profiles[CAE.csvs.currentProfile]
                if (value and profile.circles[value]) then
                    LoadShapeValues()
                end
            end,
            width = "full",
            reference = "CAE_ShapesDropdown",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow editing default
        },
        {
            type = "button",
            name = "Remove shape",
            tooltip = "Remove the currently selected shape",
            func = function()
                CAE.RemoveShapeFromProfile(currentShape)
                currentShape = nil
                CAE.LoadCurrentProfile()
                RefreshShapes()
                ResetCurrentValues()
            end,
            warning = "Remove the selected shape from the profile?",
            isDangerous = true,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil end, -- Don't allow editing default
        },
        {
            type = "button",
            name = "Add circle",
            tooltip = "Add a new circle to the current profile. The properties can be edited later",
            func = function()
                ResetCurrentValues()
                local id = CAE.AddCircleToProfile(currentRgb, currentColor, currentSize, currentYOffset, currentForwardOffset, currentConditionalAbility, currentConditionalSetId, currentConditionalEffectId, currentActiveBarOnly, currentDepthBuffers, currentPitch, currentSolid, currentUseCameraHeading)
                CAE.LoadCurrentProfile()
                currentShape = id
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow editing default
        },
        {
            type = "button",
            name = "Add rectangle",
            tooltip = "Add a new rectangle to the current profile. The properties can be edited later",
            func = function()
                ResetCurrentValues()
                local id = CAE.AddRectangleToProfile(currentRgb, currentColor, currentFillColor, currentSize, currentHeight, currentEdgeSize, currentYOffset, currentForwardOffset, currentConditionalAbility, currentConditionalSetId, currentConditionalEffectId, currentActiveBarOnly, currentDepthBuffers, currentPitch, currentSolid, currentUseCameraHeading)
                CAE.LoadCurrentProfile()
                currentShape = id
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow editing default
        },
        {
            type = "button",
            name = "Add cone",
            tooltip = "Add a new cone to the current profile. The properties can be edited later",
            func = function()
                ResetCurrentValues()
                currentPitch = math.pi / 2
                local id = CAE.AddConeToProfile(currentRgb, currentColor, currentFillColor, currentSize, currentHeight, currentYOffset, currentForwardOffset, currentConditionalAbility, currentConditionalSetId, currentConditionalEffectId, currentActiveBarOnly, currentDepthBuffers, currentPitch, currentSolid, currentUseCameraHeading, currentConeStyle)
                CAE.LoadCurrentProfile()
                currentShape = id
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow editing default
        },
        {
            type = "slider",
            name = "Size (cm)",
            tooltip = "The size in centimeters of the shape. For circles and cones, this is the radius. For rectangles, this is the width",
            min = 0,
            max = 4800,
            step = 50,
            default = 800,
            width = "half",
            getFunc = function() return currentSize * 100 end,
            setFunc = function(value)
                currentSize = value / 100
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].radius = currentSize
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil end, -- Don't allow editing default
        },
        {
            type = "slider",
            name = "Length (cm) / Thickness",
            tooltip = "The size in centimeters of the shape. For rectangles, this is the length. For cones, this is the thickness of the side lines",
            min = 0,
            max = 4800,
            step = 50,
            default = 800,
            width = "half",
            getFunc = function() return currentHeight and currentHeight * 100 or nil end,
            setFunc = function(value)
                currentHeight = value / 100
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].height = currentHeight
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].type == CAE.CIRCLE end, -- Don't allow editing default, not valid for circles
        },
        {
            type = "checkbox",
            name = "Solid color",
            tooltip = "Whether to use a solid circle or rectangle instead of an outline or rectangle with border. Non-solid rectangles do not support hiding behind objects. Does not apply to cones",
            default = false,
            getFunc = function() return currentSolid end,
            setFunc = function(value)
                currentSolid = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].solid = currentSolid
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].type == CAE.CONE end, -- Don't allow editing default, not valid for cones
        },
        {
            type = "dropdown",
            name = "Cone style",
            tooltip = "Style for cones only",
            choices = {"Arc + lines", "Curved arc only", "Straight lines only"},
            choicesValues = {3, 2, 1},
            getFunc = function() return currentConeStyle end,
            setFunc = function(value)
                currentConeStyle = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].coneStyle = currentConeStyle
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].type ~= CAE.CONE end, -- only valid for cones
        },
        {
            type = "checkbox",
            name = "Use RGB",
            tooltip = "Whether to cycle through all hues instead of being a static color. The alpha (opacity) of the \"Outline color\" below will be inherited",
            default = false,
            getFunc = function() return currentRgb end,
            setFunc = function(value)
                currentRgb = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].rgb = currentRgb
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil end, -- Don't allow editing default
        },
        {
            type = "colorpicker",
            name = "Outline / main color",
            tooltip = "The color of the shape. Note that this color includes opacity, so it may appear darker in the settings menu than it actually is",
            default = ZO_ColorDef:New(1, 1, 1, 1),
            getFunc = function() return unpack(currentColor) end,
            setFunc = function(r, g, b, a)
                currentColor = {r, g, b, a}
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].color = currentColor
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil end, -- Don't allow editing default
        },
        {
            type = "colorpicker",
            name = "Fill color",
            tooltip = "The center fill color of the rectangle (does not work for circles or cones). Note that this color includes opacity, so it may appear darker in the settings menu than it actually is",
            default = ZO_ColorDef:New(1, 1, 1, 0),
            getFunc = function() return unpack(currentFillColor) end,
            setFunc = function(r, g, b, a)
                currentFillColor = {r, g, b, a}
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].fillColor = currentFillColor
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].type ~= CAE.RECTANGLE or currentSolid end, -- Don't allow editing default, only valid for Space rectangles
        },
        {
            type = "checkbox",
            name = "Hide behind objects",
            tooltip = "Whether to use depth buffers to have shapes be hidden by objects. For example, if this is ON, parts of the shape can be covered by hills. This does not work for rectangles with outlines or the arc portion of cones. In order for this setting to work while ON, you must have \"SubSampling Quality\" set to \"High\" in your Video settings",
            default = false,
            getFunc = function() return currentDepthBuffers end,
            setFunc = function(value)
                currentDepthBuffers = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].depthBuffers = currentDepthBuffers
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or 
                (CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].type == CAE.RECTANGLE and not currentSolid) end, -- Rectangle outline is Space
        },
        {
            type = "slider",
            name = "Y offset (cm)",
            tooltip = "The elevation offset from your feet",
            min = -100,
            max = 100,
            step = 5,
            default = 5,
            width = "half",
            getFunc = function() return currentYOffset end,
            setFunc = function(value)
                currentYOffset = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].yOffset = currentYOffset
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil end, -- Don't allow editing default
        },
        {
            type = "slider",
            name = "Forward offset (cm)",
            tooltip = "The offset of the center of the shape from your feet, for where your character or camera is facing",
            min = -3500,
            max = 3500,
            step = 50,
            default = 0,
            width = "half",
            getFunc = function() return currentForwardOffset end,
            setFunc = function(value)
                currentForwardOffset = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].forwardOffset = currentForwardOffset
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil end, -- Don't allow editing default
        },
        {
            type = "slider",
            name = "Pitch / Angle",
            tooltip = "For circles or rectangles, the forward rotation of the shape, in degrees. For cones, the angle of the cone",
            min = 0,
            max = 360,
            step = 5,
            default = 0,
            width = "half",
            getFunc = function() return zo_round(currentPitch / math.pi * 180) end,
            setFunc = function(value)
                currentPitch = value / 180 * math.pi
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].pitch = currentPitch
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil end, -- Don't allow editing default
        },
        {
            type = "checkbox",
            name = "Use camera heading",
            tooltip = "Whether to follow the direction your camera is pointing, or the direction your character is pointing",
            default = true,
            getFunc = function() return currentUseCameraHeading end,
            setFunc = function(value)
                currentUseCameraHeading = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].useCameraHeading = currentUseCameraHeading
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "half",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil  end,
        },
        {
            type = "description",
            text = function()
                if (#currentConditionalAbility > 0) then
                    local abilities = ""
                    for _, id in ipairs(currentConditionalAbility) do
                        abilities = zo_strformat("<<1>> <<2>> (<<3>>),", abilities, GetAbilityName(id), id)
                    end
                    return zo_strformat("\nCurrent: shown when you slot <<1>> <<2>>", abilities,
                        currentActiveBarOnly and "on the active bar" or "on either bar")

                elseif (#currentConditionalSetId > 0) then
                    local sets = ""
                    for _, id in ipairs(currentConditionalSetId) do
                        local _, setName = GetItemSetInfo(id)
                        sets = zo_strformat("<<1>> <<2>> (<<3>>),", sets, setName, id)
                    end
                    return  zo_strformat("\nCurrent: shown when you equip <<1>> <<2>>", sets,
                        currentActiveBarOnly and "on the active bar" or "on either bar")

                elseif (#currentConditionalEffectId > 0) then
                    local abilities = ""
                    for _, id in ipairs(currentConditionalEffectId) do
                        abilities = zo_strformat("<<1>> <<2>> (<<3>>),", abilities, GetAbilityName(id), id)
                    end
                    return zo_strformat("\nCurrent: shown when you have <<1>> on you", abilities)
                end
                return ""
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Conditional active bar only",
            tooltip = "Whether to check for active bar on the conditional ID. If set to ON, this shape will only appear when the skill or set is slotted on the active weapon bar. If OFF, the shape will show when the skill or set is slotted on either bar",
            default = false,
            getFunc = function() return currentActiveBarOnly end,
            setFunc = function(value)
                currentActiveBarOnly = value
                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].activeBarOnly = currentActiveBarOnly
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or (#currentConditionalAbility == 0 and #currentConditionalSetId == 0) end, -- Don't allow editing default
        },
        {
            type = "editbox",
            name = "Conditional skill ID",
            tooltip = "If specified, this shape will only show when these abilities are slotted. Separate multiple IDs using commas (,)\nUse |c99FF99/cae printskills|r to see currently slotted IDs",
            getFunc = function()
                return table.concat(currentConditionalAbility, ",")
            end,
            setFunc = function(value)
                ZO_ClearTable(currentConditionalAbility)
                for _, id in ipairs({zo_strsplit(",", value)}) do
                    id = tonumber(id)
                    if (id) then
                        table.insert(currentConditionalAbility, id)
                    end
                end

                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].conditionalAbilityId = ZO_DeepTableCopy(currentConditionalAbility)
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            isMultiline = false,
            isExtraWide = false,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or #currentConditionalSetId ~= 0 or #currentConditionalEffectId ~= 0 end, -- Exclude when others are set
        },
        {
            type = "editbox",
            name = "Conditional set ID",
            tooltip = "If specified, this shape will only show when these sets are equipped with the max bonus. Separate multiple IDs using commas (,)\nUse |c99FF99/cae printsets|r to see currently equipped set IDs",
            getFunc = function()
                return table.concat(currentConditionalSetId, ",")
            end,
            setFunc = function(value)
                ZO_ClearTable(currentConditionalSetId)
                for _, id in ipairs({zo_strsplit(",", value)}) do
                    id = tonumber(id)
                    if (id) then
                        table.insert(currentConditionalSetId, id)
                    end
                end

                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].conditionalSetId = ZO_DeepTableCopy(currentConditionalSetId)
                CAE.LoadCurrentProfile()
                RefreshShapes()
            end,
            isMultiline = false,
            isExtraWide = false,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or #currentConditionalAbility ~= 0 or #currentConditionalEffectId ~= 0 end, -- Exclude when others are set
        },
        {
            type = "editbox",
            name = "Conditional effect ID",
            tooltip = "If specified, this shape will only show when these buff / debuff effects are on you. Separate multiple IDs using commas (,)\nUse |c99FF99/cae printeffects|r to see current effect IDs",
            getFunc = function()
                return table.concat(currentConditionalEffectId, ",")
            end,
            setFunc = function(value)
                ZO_ClearTable(currentConditionalEffectId)
                for _, id in ipairs({zo_strsplit(",", value)}) do
                    id = tonumber(id)
                    if (id) then
                        table.insert(currentConditionalEffectId, id)
                    end
                end

                CAE.profiles[CAE.csvs.currentProfile].circles[currentShape].conditionalEffectId = ZO_DeepTableCopy(currentConditionalEffectId)
                CAE.LoadCurrentProfile(true)
                RefreshShapes()
            end,
            isMultiline = false,
            isExtraWide = false,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentShape == nil or #currentConditionalSetId ~= 0 or #currentConditionalAbility ~= 0 end, -- Exclude when others are set
        },
        {
            type = "submenu",
            name = "Import",
            controls = {
                {
                    type = "description",
                    text = "Select from example presets here to add shapes that are already set up for use. There may be slight inaccuracies because these were the results of testing; yell at Kyzer if any seem wrong. Note: some skills may actually be pill-shaped or rounded, but the display for that is not supported.",
                    width = "full",
                },
                {
                    type = "dropdown",
                    name = "Preset shape",
                    choices = BuildPresetShapes(),
                    getFunc = function()
                        return selectedPreset
                    end,
                    setFunc = function(value)
                        selectedPreset = value
                    end,
                    width = "full",
                    disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow editing default
                },
                {
                    type = "button",
                    name = "Add to profile",
                    tooltip = "Add the selected preset to the current profile. The properties can be edited later",
                    func = function()
                        local id = CAE.AddPresetToProfile(selectedPreset)
                        CAE.LoadCurrentProfile()
                        currentShape = id
                        RefreshShapes()
                        LoadShapeValues()
                    end,
                    width = "full",
                    disabled = function() return CAE.csvs.currentProfile == -1 or selectedPreset == nil end, -- Don't allow editing default
                },
            },
        },
---------------------------------------------------------------------
        {
            type = "description",
            title = "|c08BD1DLines|r",
            text = "Add or edit a line between players here by clicking the Add button or selecting from the dropdown, then editing the properties.",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Current line",
            choices = {},
            choicesValues = {},
            getFunc = function()
                RefreshLines()
                return currentLine
            end,
            setFunc = function(value)
                currentLine = value
                local profile = CAE.profiles[CAE.csvs.currentProfile]
                if (value and profile.lines[value]) then
                    currentPlayer1 = profile.lines[value].player1
                    currentPlayer2 = profile.lines[value].player2
                    currentLineColor = profile.lines[value].color
                    currentSecondLineColor = profile.lines[value].secondColor
                    currentShowDistance = profile.lines[value].showDistance
                    currentUseGradient = profile.lines[value].useGradient
                end
            end,
            width = "full",
            reference = "CAE_LinesDropdown",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow editing default
        },
        {
            type = "button",
            name = "Remove line",
            tooltip = "Remove the currently selected line",
            func = function()
                CAE.RemoveLineFromProfile(currentLine)
                currentLine = nil
                CAE.LoadCurrentLines()
                RefreshLines()
                ResetCurrentLineValues()
            end,
            warning = "Remove the selected line from the profile?",
            isDangerous = true,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentLine == nil end, -- Don't allow editing default
        },
        {
            type = "button",
            name = "Add line",
            tooltip = "Add a new line to the current profile. The properties can be edited later",
            func = function()
                ResetCurrentLineValues()
                local id = CAE.AddLineToProfile(currentPlayer1, currentPlayer2, currentLineColor, currentShowDistance, currentUseGradient, currentSecondLineColor)
                CAE.LoadCurrentLines()
                currentLine = id
                RefreshLines()
            end,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 end, -- Don't allow editing default
        },
        {
            type = "editbox",
            name = "Line player 1",
            tooltip = "One of the two account names to draw a line between, when they are in your group. Case sensitive! Leave blank to set it as yourself",
            getFunc = function() return currentPlayer1 end,
            setFunc = function(value)
                if (value == "") then value = nil end
                currentPlayer1 = value
                CAE.profiles[CAE.csvs.currentProfile].lines[currentLine].player1 = currentPlayer1
                CAE.LoadCurrentLines()
                RefreshLines()
            end,
            isMultiline = false,
            isExtraWide = false,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentLine == nil end, -- Don't allow editing default
        },
        {
            type = "editbox",
            name = "Line player 2",
            tooltip = "One of the two account names to draw a line between, when they are in your group. Case sensitive! Leave blank to set it as yourself",
            getFunc = function() return currentPlayer2 end,
            setFunc = function(value)
                if (value == "") then value = nil end
                currentPlayer2 = value
                CAE.profiles[CAE.csvs.currentProfile].lines[currentLine].player2 = currentPlayer2
                CAE.LoadCurrentLines()
                RefreshLines()
            end,
            isMultiline = false,
            isExtraWide = false,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentLine == nil end, -- Don't allow editing default
        },
        {
            type = "checkbox",
            name = "Use gradient",
            tooltip = "Interpolates the color of the line based on distance between the two players, from 0 up to 28 meters",
            default = false,
            getFunc = function() return currentUseGradient end,
            setFunc = function(value)
                currentUseGradient = value
                CAE.profiles[CAE.csvs.currentProfile].lines[currentLine].useGradient = currentUseGradient
                CAE.LoadCurrentLines()
                RefreshLines()
            end,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentLine == nil end, -- Don't allow editing default
        },
        {
            type = "colorpicker",
            name = "Line color",
            tooltip = "The color of the line to add. Note that this color includes opacity, so it may appear darker in the settings menu than it actually is",
            default = ZO_ColorDef:New(1, 1, 1, 1),
            getFunc = function() return unpack(currentLineColor) end,
            setFunc = function(r, g, b, a)
                currentLineColor = {r, g, b, a}
                CAE.profiles[CAE.csvs.currentProfile].lines[currentLine].color = currentLineColor
                CAE.LoadCurrentLines()
                RefreshLines()
            end,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentLine == nil end, -- Don't allow editing default
        },
        {
            type = "colorpicker",
            name = "Second line color (gradient)",
            tooltip = "The ending color of the line if gradient is enabled. Note that this color includes opacity, so it may appear darker in the settings menu than it actually is",
            default = ZO_ColorDef:New(1, 1, 1, 1),
            getFunc = function() return unpack(currentSecondLineColor) end,
            setFunc = function(r, g, b, a)
                currentSecondLineColor = {r, g, b, a}
                CAE.profiles[CAE.csvs.currentProfile].lines[currentLine].secondColor = currentSecondLineColor
                CAE.LoadCurrentLines()
                RefreshLines()
            end,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentLine == nil or not currentUseGradient end, -- Don't allow editing default
        },
        {
            type = "checkbox",
            name = "Show distance",
            tooltip = "Show the distance in meters attached to the line",
            default = false,
            getFunc = function() return currentShowDistance end,
            setFunc = function(value)
                currentShowDistance = value
                CAE.profiles[CAE.csvs.currentProfile].lines[currentLine].showDistance = currentShowDistance
                CAE.LoadCurrentLines()
                RefreshLines()
            end,
            width = "full",
            disabled = function() return CAE.csvs.currentProfile == -1 or currentLine == nil end, -- Don't allow editing default
        },
    })

    LAM:RegisterAddonPanel("CrutchAlertsExtensionsOptions", panelData)
    LAM:RegisterOptionControls("CrutchAlertsExtensionsOptions", optionsData)
end