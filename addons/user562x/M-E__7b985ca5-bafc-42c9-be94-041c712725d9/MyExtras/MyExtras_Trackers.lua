local ME = MyExtras
local Trackers = {}
ME.Trackers = Trackers

--------------------------------------------------
-- Config
--------------------------------------------------
local CRUX_ID          = 184220
local WARMASK_ID       = 252050
local MARK_ID          = 252048

local CRUX_DURATION    = 30
local WARMASK_DURATION = 60

local BOX_GAP          = 6
local RING_PAD         = 10
local FRAME_PAD        = 14
local UPDATE_MS        = 100
local CRUX_FONT_SCALE  = 1.5

local ORANGE_THRESHOLD = 0.50
local RED_THRESHOLD    = 0.25

local RING_R, RING_G, RING_B = 0.2, 1.0, 0.2

local SUBMENU_ICON = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_buffsAndDebuffs.dds"

Trackers.charDefaults = {
    trackersUseCharacter = false,
}

Trackers.defaults = {
    trackerPosX   = 900,
    trackerPosY   = 400,
    trackerSize   = 31,
    trackerLayout = "Vertical",
    showCrux      = true,
    showWarmask   = true,
}

Trackers.layoutChoices = {
    { name = "Vertical",   value = "Vertical"   },
    { name = "Horizontal", value = "Horizontal" },
}

Trackers.preview = false

local state = {
    crux    = { active = false, stacks = 0, beginTime = 0, endTime = 0 },
    warmask = { active = false, beginTime = 0, endTime = 0 },
}

local icons = {
    crux    = nil,
    warmask = nil,
}

local boxes       = {}
local entries     = {}
local entryPool   = {}
local numberFonts = {}
local cruxFonts   = {}
local timerTexts  = {}
local previewStart = 0

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function CharLayout()
    local cv = ME.charVariables
    if not cv then return nil end
    if type(cv.trackerCharLayout) ~= "table" then cv.trackerCharLayout = {} end
    local layout = cv.trackerCharLayout
    if not layout.seeded then
        local account = ME.savedVariables
        for key, value in pairs(Trackers.defaults) do
            local current = account and account[key]
            if current == nil then current = value end
            layout[key] = current
        end
        layout.seeded = true
    end
    return layout
end

function Trackers:UsesCharacterSettings()
    return ME.charVariables ~= nil and ME.charVariables.trackersUseCharacter == true
end

local function SV()
    if Trackers:UsesCharacterSettings() then
        return CharLayout() or ME.savedVariables
    end
    return ME.savedVariables
end

local function LayoutTip()
    if Trackers:UsesCharacterSettings() then return ME.SAVED_CHARACTER_TIP end
    return ME.SAVED_ACCOUNT_TIP
end

function Trackers:SetUseCharacterSettings(value)
    local cv = ME.charVariables
    if not cv then return end
    value = value == true
    if (cv.trackersUseCharacter == true) == value then return end
    cv.trackersUseCharacter = value
    self:ApplyPosition()
    self:RefreshDisplay()
    local panel = ME.settingsPanel
    if panel and panel.Refresh then panel:Refresh() end
end

local function GetTimerColor(remaining, totalDuration)
    if totalDuration <= 0 then
        return 0.2, 1.0, 0.2
    end

    local pct = remaining / totalDuration

    if pct <= RED_THRESHOLD then
        return 1.0, 0.2, 0.2
    elseif pct <= ORANGE_THRESHOLD then
        return 1.0, 0.55, 0.0
    end
    return 0.2, 1.0, 0.2
end

local function GetTimerText(remaining)
    local tenths = math.floor(remaining * 10)
    if tenths < 0 then tenths = 0 end

    local text = timerTexts[tenths]
    if not text then
        text = string.format("%.1f", tenths / 10)
        timerTexts[tenths] = text
    end
    return text
end

local function GetNumberFont(iconSize)
    local font = numberFonts[iconSize]
    if not font then
        font = string.format(
            "EsoUI/Common/Fonts/univers67.otf|%d|outline",
            math.max(12, math.floor(iconSize * 0.5))
        )
        numberFonts[iconSize] = font
    end
    return font
end

local function GetCruxFont(iconSize)
    local font = cruxFonts[iconSize]
    if not font then
        font = string.format(
            "EsoUI/Common/Fonts/univers67.otf|%d|outline",
            math.max(12, math.floor(iconSize * 0.5 * CRUX_FONT_SCALE))
        )
        cruxFonts[iconSize] = font
    end
    return font
end

local function GetIconSize(size)
    return math.floor(size * 1.60)
end

local function ValidIcon(path)
    return type(path) == "string" and path ~= "" and path ~= "/esoui/art/icons/icon_missing.dds"
end

local function ResolveIcons()
    if not ValidIcon(icons.crux) then
        icons.crux = GetAbilityIcon(CRUX_ID)
    end
    if not ValidIcon(icons.warmask) then
        local markIcon = GetAbilityIcon(MARK_ID)
        if ValidIcon(markIcon) then
            icons.warmask = markIcon
        else
            icons.warmask = GetAbilityIcon(WARMASK_ID)
        end
    end
end

--------------------------------------------------
-- Panel
--------------------------------------------------
function Trackers:ApplyPosition()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV().trackerPosX, SV().trackerPosY)
end

function Trackers:CreatePanel()
    self.panel = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_TrackerPanel")
    self.panel:SetClampedToScreen(true)
    self.panel:SetDrawLayer(DL_BACKGROUND)
    self.panel:SetDrawTier(DT_LOW)
    self.panel:SetHidden(true)
    self:ApplyPosition()

    for i = 1, 2 do
        local box = WINDOW_MANAGER:CreateControlFromVirtual(
            "MyExtras_TrackerBox" .. i,
            self.panel,
            "MyExtras_TrackerBox"
        )
        box.frame  = box:GetNamedChild("Frame")
        box.radial = box:GetNamedChild("Radial")
        box.inner  = box:GetNamedChild("Inner")
        box.icon   = box:GetNamedChild("Icon")
        box.number = box:GetNamedChild("Number")
        box.cdKey    = nil
        box.cdStamp  = nil
        box.cdExpire = 0
        box:SetHidden(true)
        boxes[i] = box
    end
end

local function SizeBox(box, iconSize)
    local frameSize = iconSize + FRAME_PAD

    if box.sizedFor ~= iconSize then
        local ringSize = iconSize + RING_PAD

        box:SetDimensions(frameSize, frameSize)
        box.frame:SetDimensions(frameSize, frameSize)
        box.radial:SetDimensions(ringSize, ringSize)
        box.inner:SetDimensions(iconSize, iconSize)
        box.icon:SetDimensions(iconSize, iconSize)
        box.number:SetDimensions(iconSize, iconSize)

        box.sizedFor = iconSize
        box.fontKind = nil
    end

    return frameSize
end

--------------------------------------------------
-- Entries
--------------------------------------------------
local function AcquireEntry()
    local pooled = #entryPool
    if pooled > 0 then
        local entry = entryPool[pooled]
        entryPool[pooled] = nil
        return entry
    end
    return {}
end

local function ClearEntries()
    for i = #entries, 1, -1 do
        entryPool[#entryPool + 1] = entries[i]
        entries[i] = nil
    end
end

local function AddCruxEntry(now)
    local entry
    if Trackers.preview then
        local cycle = (now - previewStart) % CRUX_DURATION
        entry = AcquireEntry()
        entry.key       = "crux"
        entry.remaining = CRUX_DURATION - cycle
        entry.total     = CRUX_DURATION
        entry.stamp     = math.floor((now - previewStart) / CRUX_DURATION)
        entry.stacks    = 3
    else
        local s = state.crux
        if not s.active or s.stacks <= 0 then return end
        local remaining = s.endTime - now
        if remaining <= 0 then return end
        entry = AcquireEntry()
        entry.key       = "crux"
        entry.remaining = remaining
        entry.total     = math.max(s.endTime - s.beginTime, remaining)
        entry.stamp     = s.endTime
        entry.stacks    = s.stacks
    end
    entries[#entries + 1] = entry
end

local function AddWarmaskEntry(now)
    local entry
    if Trackers.preview then
        local cycle = (now - previewStart + 18) % WARMASK_DURATION
        entry = AcquireEntry()
        entry.key       = "warmask"
        entry.remaining = WARMASK_DURATION - cycle
        entry.total     = WARMASK_DURATION
        entry.stamp     = math.floor((now - previewStart + 18) / WARMASK_DURATION)
        entry.stacks    = nil
    else
        local s = state.warmask
        if not s.active then return end
        local remaining = s.endTime - now
        if remaining <= 0 then return end
        entry = AcquireEntry()
        entry.key       = "warmask"
        entry.remaining = remaining
        entry.total     = math.max(s.endTime - s.beginTime, remaining)
        entry.stamp     = s.endTime
        entry.stacks    = nil
    end
    entries[#entries + 1] = entry
end

local function BuildEntries(now)
    ClearEntries()

    local sv = SV()
    if sv.showCrux then AddCruxEntry(now) end
    if sv.showWarmask then AddWarmaskEntry(now) end

    return entries
end

--------------------------------------------------
-- Refresh Display
--------------------------------------------------
function Trackers:RefreshDisplay()
    if not self.panel then return end

    if self.sceneHidden then
        self.panel:SetHidden(true)
        return
    end

    local now = GetGameTimeSeconds()
    local list = BuildEntries(now)

    local sv = SV()
    local horizontal = sv.trackerLayout == "Horizontal"
    local iconSize = GetIconSize(sv.trackerSize)

    local offset = 0
    local frameSize = iconSize + FRAME_PAD
    local visible = 0

    for i, box in ipairs(boxes) do
        local entry = list[i]
        if entry then
            frameSize = SizeBox(box, iconSize)

            box:ClearAnchors()
            if horizontal then
                box:SetAnchor(TOPLEFT, self.panel, TOPLEFT, offset, 0)
            else
                box:SetAnchor(TOPLEFT, self.panel, TOPLEFT, 0, offset)
            end

            local icon = icons[entry.key]
            if ValidIcon(icon) then
                box.icon:SetTexture(icon)
                box.icon:SetHidden(false)
            else
                box.icon:SetHidden(true)
            end

            box.radial:SetFillColor(RING_R, RING_G, RING_B, 1)

            if box.cdKey ~= entry.key or box.cdStamp ~= entry.stamp or now >= box.cdExpire then
                box.cdKey    = entry.key
                box.cdStamp  = entry.stamp
                box.cdExpire = now + math.max(entry.remaining, 0)
                box.radial:StartCooldown(
                    math.max(entry.remaining, 0) * 1000,
                    entry.total * 1000,
                    CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false
                )
            end

            local fontKind = entry.stacks and "crux" or "timer"
            if box.fontKind ~= fontKind then
                if entry.stacks then
                    box.number:SetFont(GetCruxFont(iconSize))
                    box.number:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                else
                    box.number:SetFont(GetNumberFont(iconSize))
                    box.number:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
                end
                box.fontKind = fontKind
            end

            if entry.stacks then
                box.number:SetText(tostring(entry.stacks))
                box.number:SetColor(1, 1, 1, 1)
            else
                box.number:SetText(GetTimerText(entry.remaining))
                local r, g, b = GetTimerColor(entry.remaining, entry.total)
                box.number:SetColor(r, g, b, 1)
            end

            box:SetHidden(false)
            visible = visible + 1
            offset = offset + frameSize + BOX_GAP
        else
            box.cdKey    = nil
            box.cdStamp  = nil
            box.cdExpire = 0
            box:SetHidden(true)
        end
    end

    if visible > 0 then
        local length = offset - BOX_GAP
        if horizontal then
            self.panel:SetDimensions(length, frameSize)
        else
            self.panel:SetDimensions(frameSize, length)
        end
        self.panel:SetHidden(false)
    else
        self.panel:SetHidden(true)
    end
end

function Trackers:SetPreview(value)
    self.preview = value
    if value then
        previewStart = GetGameTimeSeconds()
        ResolveIcons()
    end
    self:RefreshDisplay()
end

--------------------------------------------------
-- Effect Tracking
--------------------------------------------------
local function OnCruxChanged(eventCode, changeType, effectSlot, effectName,
    unitTag, beginTime, endTime, stackCount, iconName)

    local s = state.crux

    if changeType == EFFECT_RESULT_FADED then
        s.active = false
        s.stacks = 0
        return
    end

    s.active    = true
    s.stacks    = stackCount or 1
    s.beginTime = beginTime
    s.endTime   = (endTime and endTime > 0) and endTime or (GetGameTimeSeconds() + CRUX_DURATION)

    if ValidIcon(iconName) then icons.crux = iconName end
end

local function OnWarmaskChanged(eventCode, changeType, effectSlot, effectName,
    unitTag, beginTime, endTime, stackCount, iconName)

    local s = state.warmask

    if changeType == EFFECT_RESULT_FADED then
        s.active = false
        return
    end

    s.active    = true
    s.beginTime = beginTime
    s.endTime   = (endTime and endTime > 0) and endTime or (GetGameTimeSeconds() + WARMASK_DURATION)
end

function Trackers:ScanExistingEffects()
    state.crux.active    = false
    state.crux.stacks    = 0
    state.warmask.active = false

    local now = GetGameTimeSeconds()

    for i = 1, GetNumBuffs("player") do
        local name, startTime, endTime, buffSlot, stackCount, iconName,
              _, _, _, _, abilityId = GetUnitBuffInfo("player", i)

        if abilityId == CRUX_ID then
            state.crux.active    = true
            state.crux.stacks    = stackCount or 1
            state.crux.beginTime = startTime
            state.crux.endTime   = (endTime and endTime > 0) and endTime or (now + CRUX_DURATION)
            if ValidIcon(iconName) then icons.crux = iconName end
        elseif abilityId == WARMASK_ID then
            state.warmask.active    = true
            state.warmask.beginTime = startTime
            state.warmask.endTime   = (endTime and endTime > 0) and endTime or (now + WARMASK_DURATION)
        end
    end
end

function Trackers:RegisterEffects()
    EVENT_MANAGER:RegisterForEvent(ME.name .. "_Crux", EVENT_EFFECT_CHANGED, OnCruxChanged)
    EVENT_MANAGER:AddFilterForEvent(ME.name .. "_Crux", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, CRUX_ID,
        REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ME.name .. "_Warmask", EVENT_EFFECT_CHANGED, OnWarmaskChanged)
    EVENT_MANAGER:AddFilterForEvent(ME.name .. "_Warmask", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, WARMASK_ID,
        REGISTER_FILTER_UNIT_TAG, "player")
end

--------------------------------------------------
-- Scene Handling
--------------------------------------------------
function Trackers:InitializeSceneHiding()
    local function OnSceneStateChange(oldState, newState)
        if newState == SCENE_SHOWING then
            Trackers.sceneHidden = true
            Trackers.panel:SetHidden(true)
        elseif newState == SCENE_HIDDEN then
            Trackers.sceneHidden = false
            Trackers:RefreshDisplay()
        end
    end

    local sceneNames = { "worldMap", "gameMenuInGame" }
    for i = 1, #sceneNames do
        local scene = SCENE_MANAGER:GetScene(sceneNames[i])
        if scene then
            scene:RegisterCallback("StateChange", OnSceneStateChange)
        end
    end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function Trackers:GetPreviewControls()
    if self.panel then return { self.panel } end
    return {}
end

function Trackers:GetOptions()
    local defaults = self.defaults

    local screenW, screenH = GuiRoot:GetDimensions()
    screenW = math.floor(tonumber(screenW) or 1920)
    screenH = math.floor(tonumber(screenH) or 1080)

    return {
        {
            type    = "submenu",
            name    = "Trackers",
            icon    = SUBMENU_ICON,
            tooltip = LayoutTip,
            options = {
                {
                    type    = "toggle",
                    name    = "Character Settings",
                    tooltip = "Off uses one layout for the whole account. On gives this character its own layout, "
                           .. "copied from the account layout the first time you turn it on.",
                    details = function()
                        if Trackers:UsesCharacterSettings() then
                            return "This character has its own layout."
                        end
                        return "All your characters share one layout."
                    end,
                    getFunc = function() return Trackers:UsesCharacterSettings() end,
                    setFunc = function(val) Trackers:SetUseCharacterSettings(val) end,
                },
                {
                    type    = "toggle",
                    name    = "Preview",
                    tooltip = ME.PREVIEW_TIP,
                    getFunc = function() return Trackers.preview end,
                    setFunc = function(val) Trackers:SetPreview(val) end,
                },
                {
                    type    = "toggle",
                    name    = "Crux",
                    preset  = "YES_NO",
                    default = defaults.showCrux,
                    getFunc = function() return SV().showCrux end,
                    setFunc = function(val)
                        SV().showCrux = val
                        Trackers:RefreshDisplay()
                    end,
                },
                {
                    type    = "toggle",
                    name    = "Huntsman's Warmask",
                    preset  = "YES_NO",
                    default = defaults.showWarmask,
                    getFunc = function() return SV().showWarmask end,
                    setFunc = function(val)
                        SV().showWarmask = val
                        Trackers:RefreshDisplay()
                    end,
                },
                {
                    type    = "dropdown",
                    name    = "Layout",
                    choices = Trackers.layoutChoices,
                    default = defaults.trackerLayout,
                    getFunc = function() return SV().trackerLayout end,
                    setFunc = function(val)
                        SV().trackerLayout = val
                        Trackers:RefreshDisplay()
                    end,
                },
                {
                    type    = "slider",
                    name    = "Size",
                    min     = 18, max = 60, step = 1,
                    default = defaults.trackerSize,
                    tooltip = "Default is " .. defaults.trackerSize .. ".",
                    getFunc = function() return SV().trackerSize end,
                    setFunc = function(val)
                        SV().trackerSize = val
                        Trackers:RefreshDisplay()
                    end,
                },
                {
                    type    = "slider",
                    name    = "Horizontal Position",
                    min     = 0, max = screenW, step = 5,
                    default = defaults.trackerPosX,
                    tooltip = "Default is " .. defaults.trackerPosX .. ".",
                    getFunc = function() return SV().trackerPosX end,
                    setFunc = function(val)
                        SV().trackerPosX = val
                        Trackers:ApplyPosition()
                    end,
                },
                {
                    type    = "slider",
                    name    = "Vertical Position",
                    min     = 0, max = screenH, step = 5,
                    default = defaults.trackerPosY,
                    tooltip = "Default is " .. defaults.trackerPosY .. ".",
                    getFunc = function() return SV().trackerPosY end,
                    setFunc = function(val)
                        SV().trackerPosY = val
                        Trackers:ApplyPosition()
                    end,
                },
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function Trackers:Init()
    ResolveIcons()
    self:CreatePanel()
    self:InitializeSceneHiding()
    self:RegisterEffects()

    EVENT_MANAGER:RegisterForUpdate(ME.name .. "_Trackers", UPDATE_MS,
        function() Trackers:RefreshDisplay() end)
end

function Trackers:OnPlayerActivated()
    ResolveIcons()
    self:ScanExistingEffects()
    self:RefreshDisplay()
end

function Trackers:ResetSkipKeys()
    local keys = {}
    if self:UsesCharacterSettings() then
        for key in pairs(self.defaults) do keys[#keys + 1] = key end
    end
    return keys
end

function Trackers:OnReset()
    self.preview = false
    if self:UsesCharacterSettings() then
        local layout = CharLayout()
        if layout then
            for key, value in pairs(self.defaults) do
                layout[key] = value
            end
        end
    end
    self:ApplyPosition()
    self:RefreshDisplay()
end

ME:RegisterFeature(Trackers)
