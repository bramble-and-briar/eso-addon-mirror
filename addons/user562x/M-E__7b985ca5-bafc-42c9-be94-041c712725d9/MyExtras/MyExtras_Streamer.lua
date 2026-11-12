local ME = MyExtras
local Streamer = {}
ME.Streamer = Streamer

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON  = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_social.dds"
local DEFAULT_TEXT  = "Thanks for watching!"
local DEFAULT_FONT  = "EsoUI/Common/Fonts/univers67.otf"
local PANEL_WIDTH   = 1200
local CHECK_MS      = 250
local MOVE_SPEED    = 500
local SCALE_SPEED   = 15
local SIZE_MIN      = 25
local SIZE_MAX      = 90
local MOVE_SCENE    = "MyExtras_StreamerMove"
local BOX_PAD_X     = 0.3
local BOX_PAD_Y     = 0.12
local BOX_CORNER    = 0.35

Streamer.charDefaults = {
    streamerUseCharacter = false,
}

Streamer.defaults = {
    streamerText     = DEFAULT_TEXT,
    streamerDuration = 10,
    streamerSize     = 45,
    streamerFont     = DEFAULT_FONT,
    streamerColor    = { r = 1, g = 1, b = 1, a = 1 },
    streamerPosX     = 0,
    streamerPosY     = -400,
    streamerShowing  = false,
    streamerBackground        = false,
    streamerBackgroundOpacity = 50,
}

Streamer.durationChoices = {
    { name = "1 Second",   value = 1    },
    { name = "3 Seconds",  value = 3    },
    { name = "5 Seconds",  value = 5    },
    { name = "10 Seconds", value = 10   },
    { name = "15 Seconds", value = 15   },
    { name = "30 Seconds", value = 30   },
    { name = "1 Minute",   value = 60   },
    { name = "5 Minutes",  value = 300  },
    { name = "10 Minutes", value = 600  },
    { name = "30 Minutes", value = 1800 },
    { name = "∞",          value = 0    },
}

Streamer.preview  = false
Streamer.active   = false

local hudShowing = { hud = false, hudui = false }
local expireAt   = nil
local checking   = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local charFilled = false

local function CharSettings()
    local cv = ME.charVariables
    if not cv then return nil end
    if type(cv.streamerCharSettings) ~= "table" then cv.streamerCharSettings = {} end
    local settings = cv.streamerCharSettings
    if not settings.seeded then
        local account = ME.savedVariables
        for key, value in pairs(Streamer.defaults) do
            local current = account and account[key]
            if current == nil then current = value end
            settings[key] = current
        end
        settings.seeded = true
        charFilled = true
    elseif not charFilled then
        for key, value in pairs(Streamer.defaults) do
            if settings[key] == nil then settings[key] = value end
        end
        charFilled = true
    end
    return settings
end

function Streamer:UsesCharacterSettings()
    return ME.charVariables ~= nil and ME.charVariables.streamerUseCharacter == true
end

local function SV()
    if Streamer:UsesCharacterSettings() then
        return CharSettings() or ME.savedVariables
    end
    return ME.savedVariables
end

local function SavedTip()
    if Streamer:UsesCharacterSettings() then return ME.SAVED_CHARACTER_TIP end
    return ME.SAVED_ACCOUNT_TIP
end

local function MessageText()
    local text = SV().streamerText
    if type(text) ~= "string" or text == "" then return DEFAULT_TEXT end
    return text
end

local function MessageFont()
    local sv = SV()
    return string.format("%s|%d|outline", sv.streamerFont or DEFAULT_FONT, sv.streamerSize or 45)
end

local function MessageColor()
    local c = SV().streamerColor
    if type(c) ~= "table" then return 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1
end

local function DurationName(seconds)
    for i = 1, #Streamer.durationChoices do
        local choice = Streamer.durationChoices[i]
        if choice.value == seconds then return choice.name end
    end
    return tostring(seconds)
end

local function IsForever()
    return SV().streamerDuration == 0
end

local function RefreshPanel()
    local panel = ME.settingsPanel
    if panel and panel.Refresh then panel:Refresh() end
end

--------------------------------------------------
-- Panel
--------------------------------------------------
function Streamer:CreatePanel()
    local panel = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_StreamerPanel")
    panel:SetDrawLayer(DL_OVERLAY)
    panel:SetDrawTier(DT_LOW)
    panel:SetDimensions(PANEL_WIDTH, 10)
    panel:SetHidden(true)
    self.panel = panel

    local box = ME:CreateRoundBox("MyExtras_StreamerBox", panel)
    box:SetHidden(true)
    self.box = box

    local label = WINDOW_MANAGER:CreateControl("MyExtras_StreamerLabel", panel, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDimensionConstraints(0, 0, PANEL_WIDTH, 0)
    label:SetAnchor(CENTER, panel, CENTER, 0, 0)
    label:SetDrawLevel(2)
    self.label = label
end

function Streamer:ApplyBox()
    if not self.box then return end
    local sv = SV()
    local show = sv.streamerBackground == true
    self.box:SetHidden(not show)
    if not show then return end
    local size = sv.streamerSize or self.defaults.streamerSize
    local padX = math.max(4, zo_floor(size * BOX_PAD_X))
    local padY = math.max(2, zo_floor(size * BOX_PAD_Y))
    local opacity = tonumber(sv.streamerBackgroundOpacity) or self.defaults.streamerBackgroundOpacity
    self.box:SetFillColor(0, 0, 0, opacity / 100)
    self.box:SetCorner(math.max(6, size * BOX_CORNER))
    self.box.control:ClearAnchors()
    self.box.control:SetAnchor(TOPLEFT, self.label, TOPLEFT, -padX, -padY)
    self.box.control:SetAnchor(BOTTOMRIGHT, self.label, BOTTOMRIGHT, padX, padY)
end

function Streamer:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(CENTER, GuiRoot, CENTER, sv.streamerPosX, sv.streamerPosY)
end

function Streamer:ApplyStyle()
    if not self.label then return end
    self.label:SetFont(MessageFont())
    self.label:SetText(MessageText())
    self.label:SetColor(MessageColor())
    self:ApplyBox()
end

--------------------------------------------------
-- Timer
--------------------------------------------------
local function StopChecking()
    if checking then
        checking = false
        EVENT_MANAGER:UnregisterForUpdate(ME.name .. "_Streamer")
    end
end

local function CheckExpired()
    if expireAt and GetFrameTimeMilliseconds() >= expireAt then
        Streamer:SetActive(false)
        RefreshPanel()
    end
end

function Streamer:StartTimer()
    if expireAt or IsForever() then return end
    expireAt = GetFrameTimeMilliseconds() + SV().streamerDuration * 1000
    if not checking then
        checking = true
        EVENT_MANAGER:RegisterForUpdate(ME.name .. "_Streamer", CHECK_MS, CheckExpired)
    end
end

--------------------------------------------------
-- Visibility
--------------------------------------------------
function Streamer:UpdateVisibility()
    if not self.panel then return end
    local onHud = hudShowing.hud or hudShowing.hudui
    local show = self.preview or self.moving or (self.active and (onHud or ME.placing))
    self.panel:SetHidden(not show)
    if self.active and onHud then self:StartTimer() end
end

function Streamer:SetActive(value)
    value = value == true
    self.active = value
    expireAt = nil
    StopChecking()
    SV().streamerShowing = value and IsForever()
    self:ApplyStyle()
    self:UpdateVisibility()
end

function Streamer:OnPlacing()
    self:UpdateVisibility()
end

function Streamer:SetPreview(value)
    self.preview = value == true
    self:ApplyStyle()
    self:UpdateVisibility()
end

function Streamer:RegisterScenes()
    local names = { "hud", "hudui" }
    for i = 1, #names do
        local sceneName = names[i]
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            hudShowing[sceneName] = scene:IsShowing()
            scene:RegisterCallback("StateChange", function(oldState, newState)
                hudShowing[sceneName] = newState == SCENE_SHOWING or newState == SCENE_SHOWN
                Streamer:UpdateVisibility()
            end)
        end
    end
end

--------------------------------------------------
-- Move
--------------------------------------------------
Streamer.mover = {}

function Streamer.mover:UpdateDirectionalInput(deltaS)
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        Streamer:SetPosition(Streamer.moveX + x * MOVE_SPEED * deltaS, Streamer.moveY - y * MOVE_SPEED * deltaS)
    end
    local _, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if scaleY ~= 0 then
        Streamer:SetScale(Streamer.moveSize + scaleY * SCALE_SPEED * deltaS)
    end
end

Streamer.moveKeybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() Streamer:EndMove(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() Streamer:MoveToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() Streamer:EndMove(false) end,
    },
}

function Streamer:SetPosition(x, y)
    local screenW, screenH = GuiRoot:GetDimensions()
    local halfW, halfH = screenW / 2, screenH / 2
    self.moveX = zo_clamp(x, -halfW, halfW)
    self.moveY = zo_clamp(y, -halfH, halfH)
    local sv = SV()
    sv.streamerPosX = zo_floor(self.moveX + 0.5)
    sv.streamerPosY = zo_floor(self.moveY + 0.5)
    self:ApplyPosition()
end

function Streamer:SetScale(size)
    self.moveSize = zo_clamp(size, SIZE_MIN, SIZE_MAX)
    local rounded = zo_floor(self.moveSize + 0.5)
    local sv = SV()
    if sv.streamerSize ~= rounded then
        sv.streamerSize = rounded
        self:ApplyStyle()
    end
end

function Streamer:MoveToDefault()
    self:SetScale(self.defaults.streamerSize)
    self:SetPosition(self.defaults.streamerPosX, self.defaults.streamerPosY)
end

function Streamer:GetMoveScene()
    if self.moveScene then return self.moveScene end
    local scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    ME:AddPlacementFragments(scene)
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            Streamer:OnMoveShowing()
        elseif newState == SCENE_HIDDEN then
            Streamer:OnMoveHidden()
        end
    end)
    self.moveScene = scene
    return scene
end

function Streamer:StartMove()
    if self.moving then return end
    self.movePreview = self.preview
    self.moveSaved = false
    self.moving = true
    self:GetMoveScene()
    SCENE_MANAGER:Push(MOVE_SCENE)
end

function Streamer:OnMoveShowing()
    local sv = SV()
    self.moving = true
    ME:RaiseWhilePlacing({ self.panel }, true)
    self.moveStartX, self.moveStartY = sv.streamerPosX, sv.streamerPosY
    self.moveStartSize = sv.streamerSize
    self.moveX, self.moveY = sv.streamerPosX, sv.streamerPosY
    self.moveSize = sv.streamerSize
    KEYBIND_STRIP:AddKeybindButtonGroup(self.moveKeybinds)
    DIRECTIONAL_INPUT:Activate(self.mover, self.panel)
    ME:SetPlacing(true)
    self:ApplyStyle()
    self:UpdateVisibility()
end

function Streamer:OnMoveHidden()
    DIRECTIONAL_INPUT:Deactivate(self.mover)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.moveKeybinds)
    if not self.moveSaved then
        self:SetScale(self.moveStartSize)
        self:SetPosition(self.moveStartX, self.moveStartY)
    end
    self.moving = false
    ME:RaiseWhilePlacing({ self.panel }, false)
    ME:SetPlacing(false)
    if self.movePreview then
        self.movePreview = false
        self:SetPreview(true)
    else
        self:UpdateVisibility()
    end
end

function Streamer:EndMove(save)
    if not self.moving then return end
    self.moveSaved = save == true
    if save then
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end
    SCENE_MANAGER:HideCurrentScene()
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function Streamer:GetPreviewControls()
    if self.panel then return { self.panel } end
    return {}
end

function Streamer:GetOptions()
    local defaults = self.defaults

    local function Sample()
        local r, g, b = MessageColor()
        return MessageText(), MessageFont(), r, g, b
    end

    return {
        {
            type    = "submenu",
            name    = "Streamer",
            icon    = SUBMENU_ICON,
            tooltip = function()
                return "Puts your own message on screen for your viewers.\n\n" .. SavedTip()
            end,
            options = {
                {
                    type    = "toggle",
                    name    = "Show Message",
                    preset  = "YES_NO",
                    tooltip = "Puts your message on screen.",
                    getFunc = function() return Streamer.active end,
                    setFunc = function(val) Streamer:SetActive(val) end,
                },
                {
                    type    = "toggle",
                    name    = "Character Settings",
                    tooltip = "Off uses the same settings for the whole account. On gives this character its own settings, "
                           .. "copied from the account settings the first time you turn it on.",
                    details = function()
                        if Streamer:UsesCharacterSettings() then
                            return "This character has its own settings."
                        end
                        return "All your characters share the same settings."
                    end,
                    getFunc = function() return Streamer:UsesCharacterSettings() end,
                    setFunc = function(val) Streamer:SetUseCharacterSettings(val) end,
                },
                {
                    type    = "toggle",
                    name    = "Preview",
                    tooltip = "Shows your message here so you can see your changes. "
                           .. "Stays on until you turn it off or leave the settings.",
                    getFunc = function() return Streamer.preview end,
                    setFunc = function(val) Streamer:SetPreview(val) end,
                },
                {
                    type       = "button",
                    name       = "Move / Scale",
                    buttonText = "Move / Scale",
                    tooltip    = "Move it with the left stick and scale it with the right stick.",
                    func       = function() Streamer:StartMove() end,
                },
                {
                    type    = "editbox",
                    name    = "Text",
                    default = defaults.streamerText,
                    tooltip = "Leave it empty to use the default: " .. DEFAULT_TEXT,
                    getFunc = function() return SV().streamerText end,
                    setFunc = function(val)
                        if val == nil or val == "" then val = DEFAULT_TEXT end
                        SV().streamerText = val
                        Streamer:ApplyStyle()
                    end,
                },
                {
                    type    = "selector",
                    name    = "Duration",
                    choices = Streamer.durationChoices,
                    default = defaults.streamerDuration,
                    details = function()
                        if IsForever() then
                            return "Stays on screen until you turn it off."
                        end
                        return "Stays on screen for " .. DurationName(SV().streamerDuration):lower() .. "."
                    end,
                    getFunc = function() return SV().streamerDuration end,
                    setFunc = function(val)
                        SV().streamerDuration = val
                        if Streamer.active then Streamer:SetActive(true) end
                    end,
                },
                {
                    type     = "submenu",
                    name     = "Appearance",
                    tooltip  = "Font, color and background for your message.",
                    options  = {
                        {
                            type    = "dropdown",
                            name    = "Font",
                            choices = ME.FONT_CHOICES,
                            default = defaults.streamerFont,
                            sample  = Sample,
                            getFunc = function() return SV().streamerFont end,
                            setFunc = function(val)
                                SV().streamerFont = val
                                Streamer:ApplyStyle()
                            end,
                        },
                        {
                            type    = "colorpicker",
                            name    = ME.RainbowText("Color"),
                            default = defaults.streamerColor,
                            sample  = Sample,
                            getFunc = function()
                                local r, g, b = MessageColor()
                                return r, g, b, 1
                            end,
                            setFunc = function(r, g, b)
                                SV().streamerColor = { r = r, g = g, b = b, a = 1 }
                                Streamer:ApplyStyle()
                            end,
                        },
                        {
                            type    = "toggle",
                            name    = "Background",
                            preset  = "YES_NO",
                            default = defaults.streamerBackground,
                            tooltip = "Puts a black box behind your message so it's easier to read.",
                            getFunc = function() return SV().streamerBackground end,
                            setFunc = function(val)
                                SV().streamerBackground = val
                                Streamer:ApplyBox()
                            end,
                        },
                        {
                            type     = "slider",
                            name     = "Background Opacity",
                            min      = 0, max = 100, step = 5,
                            default  = defaults.streamerBackgroundOpacity,
                            tooltip  = "Default is " .. defaults.streamerBackgroundOpacity .. ".",
                            disabled = function() return not SV().streamerBackground end,
                            getFunc  = function() return SV().streamerBackgroundOpacity end,
                            setFunc  = function(val)
                                SV().streamerBackgroundOpacity = val
                                Streamer:ApplyBox()
                            end,
                        },
                    },
                },
            },
        },
    }
end

function Streamer:OnSettingsState(newState)
    if newState == SCENE_HIDDEN and self.preview then
        self:SetPreview(false)
    end
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function Streamer:Init()
    self:CreatePanel()
    self:RegisterScenes()
    self:ApplyPosition()
    self.active = SV().streamerShowing == true and IsForever()
    self:ApplyStyle()
    self:UpdateVisibility()
end

function Streamer:OnPlayerActivated()
    self:ApplyStyle()
    self:UpdateVisibility()
end

function Streamer:SetUseCharacterSettings(value)
    local cv = ME.charVariables
    if not cv then return end
    value = value == true
    if (cv.streamerUseCharacter == true) == value then return end
    cv.streamerUseCharacter = value
    self:ApplyPosition()
    self:ApplyStyle()
    self:UpdateVisibility()
    RefreshPanel()
end

function Streamer:ResetSkipKeys()
    local keys = {}
    if self:UsesCharacterSettings() then
        for key in pairs(self.defaults) do keys[#keys + 1] = key end
    end
    return keys
end

function Streamer:OnReset()
    self.preview = false
    if self:UsesCharacterSettings() then
        local settings = CharSettings()
        if settings then
            for key, value in pairs(self.defaults) do
                if type(value) == "table" then
                    local copy = {}
                    for k, v in pairs(value) do copy[k] = v end
                    settings[key] = copy
                else
                    settings[key] = value
                end
            end
            settings.seeded = true
        end
    end
    self:SetActive(false)
    self:ApplyPosition()
end

ME:RegisterFeature(Streamer)
