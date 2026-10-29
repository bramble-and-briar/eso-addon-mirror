local MPBS = {
    name = "MrPancakesBiteSites",
    version = "1.2",
    author = "@TheMrPancake"
}

local LAM = LibAddonMenu2
local LMP = LibMapPins

local addonName = MPBS.name
local PIN = "MrPancakesBiteSitesPIN"

local pinTextures = {
    [1] = "MrPancakesBiteSites/Icons/fangs_white.dds", -- made by me
    [2] = "MrPancakesBiteSites/Icons/fangs_black.dds", -- made by me
    [3] = "esoui/art/armory/buildicons/buildicon_44.dds",
    [4] = "esoui/art/icons/poi/poi_camp_complete.dds",
    [5] = "esoui/art/icons/poi/poi_camp_incomplete.dds"
}

local VAMPIRE_STAGE_ABILITY_IDS = {
    [1] = 135397, -- Stage 1
    [2] = 135399, -- Stage 2
    [3] = 135400, -- Stage 3
    [4] = 135402, -- Stage 4
    [5] = 135412, -- Stage 5 (vamp ult)
}

local pinColor
local savedVariables
local x,y
local defaults = {
    pin = {
        enabled = true,
        type = "MrPancakesBiteSites/Icons/fangs_white.dds",
        size = 25,
        level = 60,
        hex = "ffffff",
        range = 10,
        hide_at_stage_1 = false,
        hide_at_stage_2 = false,
        hide_at_stage_3 = false,
        hide_at_stage_4 = true,
        hide_at_stage_5 = true,
    }
}

local biteSiteLoaders = { -- /script d(GetMapPlayerPosition("player"))
    ["cyrodiil"] = function()
        return {
            ["ava_whole"] = {
                [1] = { -- imperial camp
                    [1] = 0.239,
                    [2] = 0.237,
                    [3] = 1
                },
                [2] = { -- house
                    [1] = 0.242,
                    [2] = 0.396,
                    [3] = 2
                },
                [3] = { -- imperial camp
                    [1] = .270,
                    [2] = .135,
                    [3] = 1
                },
                [4] = { -- imperial camp
                    [1] = .316,
                    [2] = .199,
                    [3] = 1
                },
                [5] = { -- imperial camp
                    [1] = .424,
                    [2] = .156,
                    [3] = 1
                },
                [6] = { -- imperial camp
                    [1] = .411,
                    [2] = .104,
                    [3] = 1
                },
                [7] = { -- imperial camp
                    [1] = .582,
                    [2] = .198,
                    [3] = 1
                },
                [8] = { -- house
                    [1] = .789,
                    [2] = .273,
                    [3] = 2
                },
                [9] = { -- imperial camp
                    [1] = .786,
                    [2] = .290,
                    [3] = 1
                },
                [10] = { -- imperial camp
                    [1] = .682,
                    [2] = .287,
                    [3] = 1
                },
                [11] = { -- imperial camp
                    [1] = .649,
                    [2] = .374,
                    [3] = 1
                },
                [12] = { -- imperial camp
                    [1] = .619,
                    [2] = .408,
                    [3] = 1
                },
                [13] = { -- imperial camp
                    [1] = .573,
                    [2] = .441,
                    [3] = 1
                },
                [14] = { -- imperial camp
                    [1] = .599,
                    [2] = .356,
                    [3] = 1
                },
                [15] = { -- imperial camp
                    [1] = .610,
                    [2] = .480,
                    [3] = 1
                },
                [16] = { -- black dagger camp
                    [1] = .639,
                    [2] = .535,
                    [3] = 1
                },
                [17] = { -- imperial camp
                    [1] = .721,
                    [2] = .456,
                    [3] = 1
                },
                [18] = { -- imperial camp
                    [1] = .716,
                    [2] = .417,
                    [3] = 1
                },
                [19] = { -- imperial camp
                    [1] = .786,
                    [2] = .396,
                    [3] = 1
                },
                [20] = { -- imperial camp
                    [1] = .814,
                    [2] = .500,
                    [3] = 1
                },
                [21] = { -- imperial camp
                    [1] = .852,
                    [2] = .446,
                    [3] = 1
                },
                [22] = { -- imperial camp
                    [1] = .768,
                    [2] = .64,
                    [3] = 1
                },
                [23] = { -- house
                    [1] = .715,
                    [2] = .668,
                    [3] = 2
                },
                [24] = { -- imperial camp
                    [1] = .703,
                    [2] = .708,
                    [3] = 1
                },
                [25] = { -- clearwater dock
                    [1] = .515,
                    [2] = .822,
                    [3] = 3
                },
                [26] = { -- imperial camp
                    [1] = .495,
                    [2] = .801,
                    [3] = 1
                },
                [27] = { -- lowland camp
                    [1] = .481,
                    [2] = .797,
                    [3] = 1
                },
                [28] = { -- imperial camp
                    [1] = .380,
                    [2] = .740,
                    [3] = 1
                },
                [29] = { -- imperial camp
                    [1] = .328,
                    [2] = .799,
                    [3] = 1
                },
                [30] = { -- nornalhorst ruins
                    [1] = .317,
                    [2] = .799,
                    [3] = 0
                },
                [31] = { -- imperial camp
                    [1] = .277,
                    [2] = .667,
                    [3] = 1
                },
                [32] = { -- gray viper camp
                    [1] = .461,
                    [2] = .614,
                    [3] = 1
                },
                [33] = { -- imperial camp
                    [1] = .255,
                    [2] = .602,
                    [3] = 1
                },
                [34] = { -- imperial camp
                    [1] = .263,
                    [2] = .527,
                    [3] = 1
                },
                [35] = { -- imperial camp
                    [1] = .290,
                    [2] = .443,
                    [3] = 1
                },
                [36] = { -- imperial camp
                    [1] = .236,
                    [2] = .308,
                    [3] = 1
                },
                [37] = { -- imperial camp
                    [1] = .320,
                    [2] = .345,
                    [3] = 1
                },
                [38] = { -- black dagger camp
                    [1] = .463,
                    [2] = .318,
                    [3] = 1
                },
                [39] = { -- imperial camp
                    [1] = .527,
                    [2] = .255,
                    [3] = 1
                },
                [40] = { -- tundra ravagers
                    [1] = .54,
                    [2] = .174,
                    [3] = 1
                },
                [41] = { -- imperial camp
                    [1] = .489,
                    [2] = .317,
                    [3] = 1
                },
                [42] = { -- imperial camp
                    [1] = .434,
                    [2] = .341,
                    [3] = 1
                },
                [43] = { -- imperial camp
                    [1] = .389,
                    [2] = .404,
                    [3] = 1
                },
                [44] = { -- imperial camp
                    [1] = .403,
                    [2] = .485,
                    [3] = 1
                },
                [45] = { -- imperial camp
                    [1] = .442,
                    [2] = .526,
                    [3] = 1
                },
                [46] = { -- homestead camp
                    [1] = .479,
                    [2] = .537,
                    [3] = 1
                },
                [47] = { -- imperial camp
                    [1] = .506,
                    [2] = .581,
                    [3] = 1
                },
                [48] = { -- sardavar ruins
                    [1] = .529,
                    [2] = .577,
                    [3] = 0
                },
                [49] = { -- imperial camp
                    [1] = .612,
                    [2] = .564,
                    [3] = 1
                },
                [50] = { -- river watch lighthouse
                    [1] = .582,
                    [2] = .661,
                    [3] = 1
                },
                [51] = { -- imperial camp
                    [1] = .407,
                    [2] = .612,
                    [3] = 1
                },
                [52] = { -- imperial camp/shadowed path camp
                    [1] = .363,
                    [2] = .695,
                    [3] = 1
                },
                [53] = { -- imperial camp
                    [1] = .365,
                    [2] = .639,
                    [3] = 1
                },
                [54] = { -- imperial camp
                    [1] = .344,
                    [2] = .573,
                    [3] = 1
                },
                [55] = { -- shadowed path camp
                    [1] = .317,
                    [2] = .562,
                    [3] = 1
                },
                [56] = { -- black dagger village
                    [1] = .172,
                    [2] = .476,
                    [3] = 1
                },
                [57] = { -- imperial camp
                    [1] = .195,
                    [2] = .447,
                    [3] = 1
                },
                [58] = { -- imperial camp within a mountain
                    [1] = .206,
                    [2] = .432,
                    [3] = 1
                },
                [59] = { -- black dagger camp
                    [1] = .145,
                    [2] = .401,
                    [3] = 1
                },
                [60] = { -- black dagger house
                    [1] = .128,
                    [2] = .385,
                    [3] = 2
                },
                [61] = { -- imperial camp
                    [1] = .116,
                    [2] = .342,
                    [3] = 1
                },
                [62] = { -- bloodborne camp
                    [1] = .159,
                    [2] = .244,
                    [3] = 1
                },
                [63] = { -- imperial camp
                    [1] = .174,
                    [2] = .234,
                    [3] = 1
                },
                [64] = { -- imperial camp
                    [1] = .720,
                    [2] = .582,
                    [3] = 1
                },
                [65] = { -- bloodborn camp
                    [1] = .358,
                    [2] = .225,
                    [3] = 1
                },
                [66] = { -- hearteater camp
                    [1] = .388,
                    [2] = .205,
                    [3] = 1
                },
                [67] = { -- imperial camp
                    [1] = .589,
                    [2] = .226,
                    [3] = 1
                },
                [68] = { -- black dagger camp
                    [1] = .288,
                    [2] = .494,
                    [3] = 1
                },
                [69] = { -- imperial camp
                    [1] = .445,
                    [2] = .233,
                    [3] = 1
                },
                [70] = { -- tower
                    [1] = .195,
                    [2] = .309,
                    [3] = 2
                },
                [71] = { -- imperial camp
                    [1] = .432,
                    [2] = .167,
                    [3] = 1
                },
                [72] = { -- imperial camp
                    [1] = .427,
                    [2] = .665,
                    [3] = 1
                },
                [73] = { -- clearwater npcs
                    [1] = .308,
                    [2] = .618,
                    [3] = 1
                },
                [74] = { -- imperial camp
                    [1] = .541,
                    [2] = .243,
                    [3] = 1
                },
                [75] = { -- imperial camp
                    [1] = .709,
                    [2] = .123,
                    [3] = 1
                },
                [76] = { -- imperial camp
                    [1] = .147,
                    [2] = .367,
                    [3] = 1
                },
                [77] = { -- imperial camp
                    [1] = .569,
                    [2] = .69,
                    [3] = 1
                },
                [78] = { -- imperial camp
                    [1] = .668,
                    [2] = .496,
                    [3] = 1
                },
                [79] = { -- imperial camp
                    [1] = .476,
                    [2] = .743,
                    [3] = 1
                },
                [80] = { -- imperial camp
                    [1] = .846,
                    [2] = .244,
                    [3] = 1
                },
                [81] = { -- imperial camp
                    [1] = .584,
                    [2] = .621,
                    [3] = 1
                },
                [82] = { -- imperial camp
                    [1] = .442,
                    [2] = .673,
                    [3] = 1
                },
                [83] = { -- black dagger camp
                    [1] = .758,
                    [2] = .347,
                    [3] = 1
                }
            },
            ["u51_jerallpass_base"] = {
                [1] = {
                    [1] = 0.305,
                    [2] = 0.633,
                    [3] = 0,
                },
                [2] = {
                    [1] = 0.435,
                    [2] = 0.815,
                    [3] = 0,
                },
                [3] = { -- imperial camp
                    [1] = 0.52,
                    [2] = 0.841,
                    [3] = 1,
                },
                [4] = {
                    [1] = 0.859,
                    [2] = 0.62,
                    [3] = 1,
                },
                [5] = {
                    [1] = 0.832,
                    [2] = 0.473,
                    [3] = 1,
                },
                [6] = {
                    [1] = 0.836,
                    [2] = 0.417,
                    [3] = 1,
                },
                [7] = { -- imperial camp
                    [1] = 0.81,
                    [2] = 0.312,
                    [3] = 1,
                },
                [8] = {
                    [1] = 0.256,
                    [2] = 0.31,
                    [3] = 1,
                },
                [9] = {
                    [1] = 0.795,
                    [2] = 0.497,
                    [3] = 1,
                },
                [10] = {
                    [1] = 0.405,
                    [2] = 0.646,
                    [3] = 1,
                },
            },
        }
    end,
}

local biteSiteDataCache = {}

local function CreateSettingsMenu()
    local panelData = {
        type = "panel",
        name = "MrPancake's Bite Sites", -- sidebar name
        displayName = "|cFE3F3FMRPANCAKE'S BITE SITES|r", -- top name
        author = MPBS.author,
        version = MPBS.version,
        registerForRefresh = true,
        registerForDefaults = true
    }

    LAM:RegisterAddonPanel(MPBS.name, panelData)
    local optionsTable = {
        { type = "checkbox", name = "Enable Addon", tooltip = "Visibility toggle.", getFunc = function() return savedVariables.pin.enabled end, setFunc = function(value) savedVariables.pin.enabled = value LMP:SetEnabled(PIN, value) end, default = defaults.pin.enabled },
        { type = "divider"},
        { type = "iconpicker", name = "Pin Icon", tooltip = "Map pin icon selector.", maxColumns = 7, choices = pinTextures, visibleRows = 2, getFunc = function() return savedVariables.pin.type end, setFunc = function(value) savedVariables.pin.type = value LMP:SetLayoutKey(PIN, "texture", value) LMP:RefreshPins(PIN) end, default = defaults.pin.type },
        { type = "colorpicker", name = "Pin Colour", tooltip = "Map pin tint colour. Affects the white parts of the icon.", getFunc = function() return pinColor:UnpackRGBA() end, setFunc = function(...) pinColor:SetRGBA(...) savedVariables.pin.hex = pinColor:ToHex() LMP:RefreshPins() end, default = ZO_SELECTED_TEXT},
        { type = "divider"},
        { type = "slider", name = "Pin Size", tooltip = "Map pin display size.", min = 20, max = 70, step = 1, getFunc = function() return savedVariables.pin.size end, setFunc = function(value) savedVariables.pin.size = value LMP:SetLayoutKey(PIN, "size", value) LMP:RefreshPins(PIN) end, default = defaults.pin.size },
        { type = "slider", name = "Pin Level", tooltip = "Map pin display level.", min = 10, max = 150, step = 5, getFunc = function() return savedVariables.pin.level end, setFunc = function(value) savedVariables.pin.level = value LMP:SetLayoutKey(PIN, "level", value) LMP:RefreshPins(PIN) end, default = defaults.pin.level },
        { type = "slider", name = "Pin Display Range", tooltip = "Display range of map pins. Higher values show more pins exponentially.", min = 5, max = 100, step = 1, getFunc = function() return savedVariables.pin.range end, setFunc = function(value) savedVariables.pin.range = value LMP:SetLayoutKey(PIN, "range", value) LMP:RefreshPins(PIN) end, default = defaults.pin.range },
        { type = "divider"},
        { type = "checkbox", name = "Hide Pins at Stage 1", tooltip = "Hides pins when you are at stage 1 vampirism.", getFunc = function() return savedVariables.pin.hide_at_stage_1 end, setFunc = function(value) savedVariables.pin.hide_at_stage_1 = value LMP:RefreshPins(PIN) end, default = defaults.pin.hide_at_stage_1 },
        { type = "checkbox", name = "Hide Pins at Stage 2", tooltip = "Hides pins when you are at stage 2 vampirism.", getFunc = function() return savedVariables.pin.hide_at_stage_2 end, setFunc = function(value) savedVariables.pin.hide_at_stage_2 = value LMP:RefreshPins(PIN) end, default = defaults.pin.hide_at_stage_2 },
        { type = "checkbox", name = "Hide Pins at Stage 3", tooltip = "Hides pins when you are at stage 3 vampirism.", getFunc = function() return savedVariables.pin.hide_at_stage_3 end, setFunc = function(value) savedVariables.pin.hide_at_stage_3 = value LMP:RefreshPins(PIN) end, default = defaults.pin.hide_at_stage_3 },
        { type = "checkbox", name = "Hide Pins at Stage 4", tooltip = "Hides pins when you are at stage 4 vampirism.", getFunc = function() return savedVariables.pin.hide_at_stage_4 end, setFunc = function(value) savedVariables.pin.hide_at_stage_4 = value LMP:RefreshPins(PIN) end, default = defaults.pin.hide_at_stage_4 },
    }
    LAM:RegisterOptionControls(MPBS.name, optionsTable)
end

local function GetLocalData(zone, subzone)
    if type(zone) ~= "string" or type(subzone) ~= "string" then return end

    local zoneData = biteSiteDataCache[zone]
    if zoneData == nil then
        local loader = biteSiteLoaders[zone]
        if not loader then
            return
        end
        zoneData = loader()
        biteSiteDataCache[zone] = zoneData
    end

    return zoneData[subzone]
end

local function GetVampireStage()
    local numBuffs = GetNumBuffs("player")
    if numBuffs == 0 then return 0 end

    for i = 1, numBuffs do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        for stage, id in pairs(VAMPIRE_STAGE_ABILITY_IDS) do
            if abilityId == id then
                return stage
            end
        end
    end

    return 0
end

local function PinCallback()
    if not LMP:IsEnabled(PIN) or (GetMapType() > MAPTYPE_ZONE) then return end
    if not IsPlayerActivated() then return end
    if not savedVariables.pin.enabled then return end

    local zone, subzone = LMP:GetZoneAndSubzone()
    local data = GetLocalData(zone, subzone)
    if not data then return end

    local vampireStage = GetVampireStage()
    if vampireStage == 0 then return end

    if vampireStage > 0 and savedVariables.pin["hide_at_stage_" .. vampireStage] then
        return
    end

    x,y = GetMapPlayerPosition("player")
    local biteSiteRange = savedVariables.pin.range / 100.0

    for _, pinData in ipairs(data) do
        if ((pinData[1] - x)^2  +  (pinData[2] - y)^2)  <  (biteSiteRange^2) then -- circular shape
            LMP:CreatePin(PIN, pinData, pinData[1], pinData[2])
        end
    end
end

local function RefreshPins()
    LMP:RefreshPins(PIN)
end

local function RegisterEvents()
    WORLD_MAP_SCENE:UnregisterCallback("StateChange")
    WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then -- successfully runs whenever opening map
            RefreshPins()
        end
    end)
    EVENT_MANAGER:UnregisterForUpdate(addonName)
    EVENT_MANAGER:RegisterForUpdate(addonName, 5000, RefreshPins)
end

local function Init(event, name)
    if name ~= addonName then return end
    savedVariables = ZO_SavedVars:NewCharacterNameSettings("MrPancakesBiteSites_SavedVariables", 1, nil, defaults)

    pinColor = ZO_ColorDef:New(savedVariables.pin.hex)
    local layout = {
        level = savedVariables.pin.level,
        texture = savedVariables.pin.type,
        size = savedVariables.pin.size,
        tint = pinColor
    }
    LMP:AddPinType(PIN, PinCallback, nil, layout, nil)
    CreateSettingsMenu()
    RegisterEvents()

    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, Init)