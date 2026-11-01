local ADDON_NAME = "MyOmBuffHUD"
local UPDATE_NAME = ADDON_NAME .. "_Timer"
local PREVIEW_DURATION = 3
local DEFAULT_ICON_SIZE = 64
local ICON_GAP = 12

local function GetIconSize()
    return (MyOmBuffHUD and MyOmBuffHUD.saved and MyOmBuffHUD.saved.iconSize) or DEFAULT_ICON_SIZE
end

local function GetTotalWidth()
    return (GetIconSize() * 3) + (ICON_GAP * 2)
end

local TRACKED_BUFFS = {
    [61744] = { order = 1 }, -- Minor Berserk / 狂戦士（弱）
    [61747] = { order = 2 }, -- Major Force / 威力（強）
    [93109] = { order = 3 }, -- Major Slayer / 殺戮（強）
}

MyOmBuffHUD = MyOmBuffHUD or {}
local controlsByAbilityId = {}
local activeEndTimes = {}
local rootControl
local previewUntil = 0

local function DefaultX()
    return math.floor((GuiRoot:GetWidth() - GetTotalWidth()) / 2)
end

local function DefaultY()
    return math.floor((GuiRoot:GetHeight() - GetIconSize()) / 2)
end

local function InitSavedVars()
    MyOmBuffHUD.saved = ZO_SavedVars:NewAccountWide("MyOmBuffHUD_Saved", 1, nil, {
        posX = DefaultX(),
        posY = DefaultY(),
        iconSize = DEFAULT_ICON_SIZE,
    })
end

local function ApplyPosition()
    rootControl:ClearAnchors()
    rootControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        MyOmBuffHUD.saved.posX, MyOmBuffHUD.saved.posY)
end

local function ApplyIconSize()
    if not rootControl then return end

    local iconSize = GetIconSize()
    local totalWidth = GetTotalWidth()
    rootControl:SetDimensions(totalWidth, iconSize)

    for abilityId, data in pairs(TRACKED_BUFFS) do
        local entry = controlsByAbilityId[abilityId]
        if entry then
            entry.control:SetDimensions(iconSize, iconSize)
            entry.control:ClearAnchors()
            entry.control:SetAnchor(
                TOPLEFT, rootControl, TOPLEFT,
                (data.order - 1) * (iconSize + ICON_GAP), 0
            )
            entry.timer:SetFont(string.format(
                "$(BOLD_FONT)|%d|soft-shadow-thick",
                math.max(16, math.floor(iconSize * 0.5))
            ))
        end
    end

    MyOmBuffHUD.saved.posX = math.min(MyOmBuffHUD.saved.posX, math.max(0, GuiRoot:GetWidth() - totalWidth))
    MyOmBuffHUD.saved.posY = math.min(MyOmBuffHUD.saved.posY, math.max(0, GuiRoot:GetHeight() - iconSize))
    ApplyPosition()
end

local function IsPreviewActive()
    return GetFrameTimeSeconds() < previewUntil
end

local function StartPreview()
    previewUntil = GetFrameTimeSeconds() + PREVIEW_DURATION
    for _, entry in pairs(controlsByAbilityId) do
        entry.control:SetHidden(false)
        entry.timer:SetText("8")
    end
end

local function EndPreview()
    previewUntil = 0
    for abilityId, entry in pairs(controlsByAbilityId) do
        if not activeEndTimes[abilityId] then
            entry.control:SetHidden(true)
            entry.timer:SetText("")
        end
    end
end

local function CreateSettingsMenu()
    local settings = LibHarvensAddonSettings:AddAddon("MyOmBuffHUD", {
        allowDefaults = true,
        allowRefresh = true,
        defaultsFunction = function()
            MyOmBuffHUD.saved.posX = DefaultX()
            MyOmBuffHUD.saved.posY = DefaultY()
            MyOmBuffHUD.saved.iconSize = DEFAULT_ICON_SIZE
            ApplyIconSize()
            StartPreview()
        end,
    })

    settings:AddSettings({
        {
            type = LibHarvensAddonSettings.ST_SECTION,
            label = "表示設定",
        },
        {
            type = LibHarvensAddonSettings.ST_SLIDER,
            label = "アイコンサイズ",
            min = 32,
            max = 128,
            step = 4,
            default = DEFAULT_ICON_SIZE,
            getFunction = function() return MyOmBuffHUD.saved.iconSize end,
            setFunction = function(value)
                MyOmBuffHUD.saved.iconSize = value
                ApplyIconSize()
                StartPreview()
            end,
        },
        {
            type = LibHarvensAddonSettings.ST_SECTION,
            label = "位置調整",
        },
        {
            type = LibHarvensAddonSettings.ST_SLIDER,
            label = "横軸",
            min = 0,
            max = math.max(0, GuiRoot:GetWidth() - GetTotalWidth()),
            step = 10,
            default = DefaultX(),
            getFunction = function() return MyOmBuffHUD.saved.posX end,
            setFunction = function(value)
                MyOmBuffHUD.saved.posX = value
                ApplyPosition()
                StartPreview()
            end,
        },
        {
            type = LibHarvensAddonSettings.ST_SLIDER,
            label = "縦軸",
            min = 0,
            max = math.max(0, GuiRoot:GetHeight() - GetIconSize()),
            step = 10,
            default = DefaultY(),
            getFunction = function() return MyOmBuffHUD.saved.posY end,
            setFunction = function(value)
                MyOmBuffHUD.saved.posY = value
                ApplyPosition()
                StartPreview()
            end,
        },
    })
end

local function SetBuffHidden(abilityId)
    activeEndTimes[abilityId] = nil
    local entry = controlsByAbilityId[abilityId]
    if entry and not IsPreviewActive() then
        entry.control:SetHidden(true)
        entry.timer:SetText("")
    end
end

local function SetBuffVisible(abilityId, endTime, iconName)
    local entry = controlsByAbilityId[abilityId]
    if not entry then return end
    activeEndTimes[abilityId] = endTime
    entry.icon:SetTexture((iconName and iconName ~= "") and iconName or GetAbilityIcon(abilityId))
    entry.control:SetHidden(false)
end

local function UpdateTimers()
    local now = GetFrameTimeSeconds()
    if previewUntil > 0 and now >= previewUntil then EndPreview() end
    if IsPreviewActive() then return end

    for abilityId, endTime in pairs(activeEndTimes) do
        local entry = controlsByAbilityId[abilityId]
        local remaining = endTime - now
        if remaining <= 0 then
            SetBuffHidden(abilityId)
        elseif entry then
            entry.timer:SetText(tostring(math.ceil(remaining)))
        end
    end
end

local function RefreshCurrentBuffs()
    for abilityId in pairs(TRACKED_BUFFS) do SetBuffHidden(abilityId) end
    local now = GetFrameTimeSeconds()
    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, timeEnding, _, _, iconFilename, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        if TRACKED_BUFFS[abilityId] and timeEnding and timeEnding > now then
            SetBuffVisible(abilityId, timeEnding, iconFilename)
        end
    end
    UpdateTimers()
end

local function OnEffectChanged(_, changeType, _, _, unitTag, _, endTime, _, iconName,
                               _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or not TRACKED_BUFFS[abilityId] then return end
    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        SetBuffVisible(abilityId, endTime, iconName)
        UpdateTimers()
    elseif changeType == EFFECT_RESULT_FADED then
        SetBuffHidden(abilityId)
    end
end

local function CreateBuffControl(abilityId, order)
    local control = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "_Buff_" .. abilityId, rootControl, CT_CONTROL)
    control:SetDimensions(GetIconSize(), GetIconSize())
    control:SetAnchor(TOPLEFT, rootControl, TOPLEFT, (order - 1) * (GetIconSize() + ICON_GAP), 0)
    control:SetHidden(true)

    local icon = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "_Icon_" .. abilityId, control, CT_TEXTURE)
    icon:SetAnchorFill(control)
    icon:SetTexture(GetAbilityIcon(abilityId))
    icon:SetTextureCoords(0, 1, 0, 1)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetCenterColor(0, 0, 0, 0)
    backdrop:SetEdgeColor(0, 0, 0, 1)
    backdrop:SetEdgeTexture(nil, 2, 2, 2)

    local timer = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "_Timer_" .. abilityId, control, CT_LABEL)
    timer:SetAnchor(CENTER, control, CENTER, 0, 0)
    timer:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", math.max(16, math.floor(GetIconSize() * 0.5))))
    timer:SetColor(1, 1, 1, 1)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    controlsByAbilityId[abilityId] = { control = control, icon = icon, timer = timer }
end

local function CreateUI()
    rootControl = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "_Root")
    rootControl:SetDimensions(GetTotalWidth(), GetIconSize())
    rootControl:SetDrawLayer(DL_OVERLAY)
    rootControl:SetMouseEnabled(false)
    rootControl:SetMovable(false)
    rootControl:SetClampedToScreen(true)
    ApplyPosition()
    for abilityId, data in pairs(TRACKED_BUFFS) do CreateBuffControl(abilityId, data.order) end
end

local function Initialize()
    InitSavedVars()
    CreateUI()
    CreateSettingsMenu()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED, RefreshCurrentBuffs)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 100, UpdateTimers)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
