local IMP_STATS_SHARED = IMP_STATS_SHARED

local combine = LibScrollList.combine
local Label = LibScrollList.Label
local Texture = LibScrollList.Texture

local function formatNumber(ctrl, number)
    ctrl:SetText(IMP_STATS_SHARED.FormatNumber(number))
end

local function formatTime(ctrl, seconds)
    ctrl:SetText(IMP_STATS_SHARED.SecondsToTime(seconds))
end

local function roundNumber1f(ctrl, number)
    ctrl:SetText(('%.1f'):format(number))
end

local function setClassIcon(ctrl, classId)
    ctrl:SetTexture(classId and ZO_GetClassIcon(classId) or 'EsoUI/Art/Icons/icon_missing.dds')
end

local function setRaceIcon(ctrl, raceId)
    ctrl:SetTexture(raceId and IMP_STATS_SHARED.GetRaceIcon(raceId) or 'EsoUI/Art/Icons/icon_missing.dds')
end

local function formatNames(ctrl, playerNames)
    ctrl:SetText(zo_strformat('<<1>> (<<2>>)', playerNames[1], playerNames[2]))
end

local defaultCellStyle = {
    SetFont = {'ZoFontGameLargeBold'},
    SetVerticalAlignment = {TEXT_ALIGN_CENTER},
    SetWrapMode = {TEXT_WRAP_MODE_ELLIPSIS},
    SetMaxLineCount = {1},
}

local defaultHeadersStyle = {
    SetFont = {'ZoFontGameLargeBold'},
    SetColor = {0.811, 0.862, 0.741},
}

local upperStyle = {
    SetModifyTextType = {MODIFY_TEXT_TYPE_UPPERCASE},
}

local upperHeadersStyle = combine(defaultHeadersStyle, upperStyle)

local classIconStyle = {
    SetDimensions = {32, 32},
    SetDrawLayer = {DL_CONTROLS},
}

local raceIconStyle = {
    SetDimensions = {32, 32},
    SetDrawLayer = {DL_CONTROLS},
}

local buildButtonStyle = {
    SetDimensions = {32, 32},
    SetTextureCoords = {0.10, 0.90, 0.10, 0.90},
    SetDrawTier = {DT_MEDIUM},
    SetMouseOverBlendMode = {TEX_BLEND_MODE_ADD},
    SetNormalTexture = {'esoui/art/tradinghouse/tradinghouse_apparel_chest_up.dds'},
    SetPressedTexture = {'esoui/art/tradinghouse/tradinghouse_apparel_chest_down.dds'},
    SetMouseOverTexture = {'esoui/art/tradinghouse/tradinghouse_apparel_chest_over.dds'},
    SetDisabledTexture = {'esoui/art/tradinghouse/tradinghouse_apparel_chest_disabled.dds'},
}

local alighLeft = {SetHorizontalAlignment = {TEXT_ALIGN_LEFT}}
local alighCenter = {SetHorizontalAlignment = {TEXT_ALIGN_CENTER}}
local alighRight = {SetHorizontalAlignment = {TEXT_ALIGN_RIGHT}}

local defaultStyle_center = combine(defaultCellStyle, alighCenter)
local defaultStyle_left   = combine(defaultCellStyle, alighLeft)
local defaultStyle_right  = combine(defaultCellStyle, alighRight)


IMP_STATS_TABLESTYLES = {
    Rounded1F =
    {
        Cell = {
            Center = Label(defaultStyle_center, roundNumber1f),
        }
    },
	Formatted =
    {
        Cell =
        {
            Center = Label(defaultStyle_center, formatNumber),
        }
    },
    Time =
    {
        Cell =
        {
            Right = Label(defaultStyle_right, formatTime)
        }
    },
    Text =
    {
        Cell =
        {
            Left   = Label(defaultStyle_left),
	        Right  = Label(defaultStyle_right),
	        Center = Label(defaultStyle_center),
        },
        Header =
        {
            Left   = Label(combine(defaultStyle_left,   defaultHeadersStyle)),
	        Right  = Label(combine(defaultStyle_right,  defaultHeadersStyle)),
	        Center = Label(combine(defaultStyle_center, defaultHeadersStyle)),
        },
        HeaderUpper =
        {
            Left   = Label(combine(defaultStyle_left,   upperHeadersStyle)),
            Right  = Label(combine(defaultStyle_right,  upperHeadersStyle)),
            Center = Label(combine(defaultStyle_center, upperHeadersStyle)),
        }
    },

    ClassIcon = Texture(classIconStyle, setClassIcon),
    RaceIcon = Texture(raceIconStyle, setRaceIcon),
	ClassHeader = Label(combine(defaultStyle_center, defaultHeadersStyle)),
    Names = Label(defaultStyle_left, formatNames),

    buildButtonStyle = buildButtonStyle,
}