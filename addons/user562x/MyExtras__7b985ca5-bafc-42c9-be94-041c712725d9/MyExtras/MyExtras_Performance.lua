local ME = MyExtras
local PF = {}
ME.Performance = PF

--------------------------------------------------
-- Config
--------------------------------------------------
local EVENT_NAME  = ME.name .. "_Performance"
local TICK_MS     = 1000
local MOVE_SPEED  = 500
local SPREAD_MIN   = 1
local SPREAD_MAX   = 30
local SPREAD_SPEED = 12
local SCALE_SPEED = 10
local SIZE_MIN    = 14
local SIZE_MAX    = 48
local MOVE_SCENE  = "MyExtras_PerformanceMove"
local BOX_PAD_X   = 0.45
local BOX_PAD_Y   = 0.2
local BOX_CORNER  = 0.35
local ICON_SCALE  = 1.1

local PING_ICONS = {
    { limit = 150,       icon = "EsoUI/Art/Campaign/campaignBrowser_hiPop.dds"  },
    { limit = 300,       icon = "EsoUI/Art/Campaign/campaignBrowser_medPop.dds" },
    { limit = math.huge, icon = "EsoUI/Art/Campaign/campaignBrowser_lowPop.dds" },
}

local GOOD = "33DD33"
local OKAY = "FFEE00"
local BAD  = "FF3333"

local PREVIEW = { fps = 60, ping = 85 }

PF.defaults = {
    perfShow              = false,
    perfFps               = true,
    perfPing              = true,
    perfColorByValue      = true,
    perfFont              = "EsoUI/Common/Fonts/FTN57.otf",
    perfSize              = 24,
    perfGap               = 5,
    perfColor             = { r = 1, g = 1, b = 1, a = 1 },
    perfPosX              = 120,
    perfPosY              = 40,
    perfBackground        = true,
    perfBackgroundOpacity = 100,
}
local DEFAULTS = PF.defaults

PF.partChoices = {
    { name = "FPS",  value = "fps"  },
    { name = "Ping", value = "ping" },
}

local PART_KEYS = {
    fps  = "perfFps",
    ping = "perfPing",
}

PF.preview = false
PF.moving  = false

local hudShowing = { hud = false, hudui = false }
local ticking    = false
local lastText   = nil

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return ME.savedVariables
end

local function TextFont()
    local sv = SV()
    return string.format("%s|%d|soft-shadow-thick", sv.perfFont, sv.perfSize)
end

local function SampleFont()
    return string.format("%s|40|soft-shadow-thick", SV().perfFont)
end

local function TextColor()
    local c = SV().perfColor
    if type(c) ~= "table" then return 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1
end

local function FpsColor(fps)
    if fps >= 60 then return GOOD end
    if fps >= 30 then return OKAY end
    return BAD
end

local function PingColor(ping)
    if ping < 150 then return GOOD end
    if ping < 300 then return OKAY end
    return BAD
end

local function PingIcon(ping)
    for i = 1, #PING_ICONS do
        if ping < PING_ICONS[i].limit then return PING_ICONS[i].icon end
    end
    return PING_ICONS[#PING_ICONS].icon
end

local function Paint(text, hex)
    if not SV().perfColorByValue then return text end
    return "|c" .. hex .. text .. "|r"
end

local function BuildText(info, size)
    local sv = SV()
    local parts = {}
    if sv.perfFps then
        local fps = zo_floor((info.fps or 0) + 0.5)
        parts[#parts + 1] = Paint(fps .. " FPS", FpsColor(fps))
    end
    if sv.perfPing then
        local ping = zo_floor((info.ping or 0) + 0.5)
        local iconSize = zo_floor(size * ICON_SCALE)
        parts[#parts + 1] = zo_iconFormat(PingIcon(ping), iconSize, iconSize) .. " " .. Paint(ping .. " ms", PingColor(ping))
    end
    return table.concat(parts, string.rep(" ", tonumber(sv.perfGap) or DEFAULTS.perfGap))
end

local function CurrentInfo()
    return { fps = GetFramerate() or 0, ping = GetLatency() or 0 }
end

local function SampleText()
    return BuildText(PREVIEW, 40)
end

--------------------------------------------------
-- Panel
--------------------------------------------------
function PF:CreatePanel()
    local panel = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_PerformancePanel")
    panel:SetDrawLayer(DL_BACKGROUND)
    panel:SetDrawTier(DT_LOW)
    panel:SetMouseEnabled(false)
    panel:SetDimensions(10, 10)
    panel:SetHidden(true)
    self.panel = panel

    local box = ME:CreateRoundBox("MyExtras_PerformanceBox", panel)
    box:SetHidden(true)
    self.box = box

    local label = WINDOW_MANAGER:CreateControl("MyExtras_PerformanceLabel", panel, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(CENTER, panel, CENTER, 0, 0)
    label:SetColor(1, 1, 1, 1)
    label:SetDrawLevel(2)
    self.label = label
end

function PF:ApplyBox()
    if not self.box then return end
    local sv = SV()
    local show = sv.perfBackground == true and lastText ~= nil and lastText ~= ""
    self.box:SetHidden(not show)
    if not show then return end
    local size = sv.perfSize or DEFAULTS.perfSize
    local padX = zo_max(4, zo_floor(size * BOX_PAD_X))
    local padY = zo_max(2, zo_floor(size * BOX_PAD_Y))
    local opacity = tonumber(sv.perfBackgroundOpacity) or DEFAULTS.perfBackgroundOpacity
    self.box:SetFillColor(0, 0, 0, opacity / 100)
    self.box:SetCorner(zo_max(6, size * BOX_CORNER))
    self.box.control:ClearAnchors()
    self.box.control:SetAnchor(TOPLEFT, self.label, TOPLEFT, -padX, -padY)
    self.box.control:SetAnchor(BOTTOMRIGHT, self.label, BOTTOMRIGHT, padX, padY)
end

function PF:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.perfPosX, sv.perfPosY)
end

function PF:Render(force)
    if not self.label then return end
    local info
    if self.preview or self.moving then
        info = PREVIEW
    else
        info = CurrentInfo()
    end
    local text = BuildText(info, SV().perfSize)
    if text == lastText and not force then return end
    lastText = text
    self.label:SetFont(TextFont())
    self.label:SetColor(TextColor())
    self.label:SetText(text)
    self:ApplyBox()
end

--------------------------------------------------
-- Visibility
--------------------------------------------------
function PF:ShouldShow()
    if self.preview or self.moving then return true end
    if not SV().perfShow then return false end
    return hudShowing.hud or hudShowing.hudui or ME.placing == true
end

function PF:UpdateVisibility()
    if not self.panel then return end
    local show = self:ShouldShow()
    if show then self:Render() end
    self.panel:SetHidden(not show)
    self:UpdateTicking()
end

function PF:UpdateTicking()
    local tick = not self.panel:IsHidden() and not (self.preview or self.moving)
    if tick == ticking then return end
    ticking = tick
    if tick then
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAME .. "Tick", TICK_MS, function() PF:Render() end)
    else
        EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. "Tick")
    end
end

function PF:OnPlacing()
    self:UpdateVisibility()
end

function PF:SetPreview(value)
    self.preview = value == true
    self:Render(true)
    self:UpdateVisibility()
end

function PF:RegisterScenes()
    local names = { "hud", "hudui" }
    for i = 1, #names do
        local sceneName = names[i]
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            hudShowing[sceneName] = scene:IsShowing()
            scene:RegisterCallback("StateChange", function(oldState, newState)
                hudShowing[sceneName] = newState == SCENE_SHOWING or newState == SCENE_SHOWN
                PF:UpdateVisibility()
            end)
        end
    end
end

function PF:Refresh()
    self:ApplyPosition()
    self:Render(true)
    self:UpdateVisibility()
end

--------------------------------------------------
-- Move
--------------------------------------------------
PF.mover = {}

function PF.mover:UpdateDirectionalInput(deltaS)
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        PF:SetPosition(PF.moveX + x * MOVE_SPEED * deltaS, PF.moveY - y * MOVE_SPEED * deltaS)
    end
    local spreadX, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if math.abs(spreadX) > math.abs(scaleY) then
        PF:SetSpread(PF.moveSpread + spreadX * SPREAD_SPEED * deltaS)
    elseif scaleY ~= 0 then
        PF:SetScale(PF.moveSize + scaleY * SCALE_SPEED * deltaS)
    end
end

PF.moveKeybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() PF:EndMove(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() PF:MoveToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() PF:EndMove(false) end,
    },
}

function PF:SetPosition(x, y)
    local screenW, screenH = GuiRoot:GetDimensions()
    self.moveX = zo_clamp(x, 0, screenW)
    self.moveY = zo_clamp(y, 0, screenH)
    local sv = SV()
    sv.perfPosX = zo_floor(self.moveX + 0.5)
    sv.perfPosY = zo_floor(self.moveY + 0.5)
    self:ApplyPosition()
end

function PF:SetScale(size)
    self.moveSize = zo_clamp(size, SIZE_MIN, SIZE_MAX)
    local rounded = zo_floor(self.moveSize + 0.5)
    local sv = SV()
    if sv.perfSize ~= rounded then
        sv.perfSize = rounded
        self:Render(true)
    end
end

function PF:SetSpread(value)
    self.moveSpread = zo_clamp(value, SPREAD_MIN, SPREAD_MAX)
    local rounded = zo_floor(self.moveSpread + 0.5)
    local sv = SV()
    if sv.perfGap ~= rounded then
        sv.perfGap = rounded
        self:Render(true)
    end
end

function PF:MoveToDefault()
    self:SetSpread(DEFAULTS.perfGap)
    self:SetScale(DEFAULTS.perfSize)
    self:SetPosition(DEFAULTS.perfPosX, DEFAULTS.perfPosY)
end

function PF:GetMoveScene()
    if self.moveScene then return self.moveScene end
    local scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    ME:AddPlacementFragments(scene)
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            PF:OnMoveShowing()
        elseif newState == SCENE_HIDDEN then
            PF:OnMoveHidden()
        end
    end)
    self.moveScene = scene
    return scene
end

function PF:StartMove()
    if self.moving then return end
    self.movePreview = self.preview
    self.moveSaved = false
    self.moving = true
    self:GetMoveScene()
    SCENE_MANAGER:Push(MOVE_SCENE)
end

function PF:OnMoveShowing()
    local sv = SV()
    self.moving = true
    ME:RaiseWhilePlacing({ self.panel }, true)
    self.moveStartX, self.moveStartY = sv.perfPosX, sv.perfPosY
    self.moveStartSize = sv.perfSize
    self.moveX, self.moveY = sv.perfPosX, sv.perfPosY
    self.moveSize = sv.perfSize
    self.moveStartSpread = sv.perfGap or DEFAULTS.perfGap
    self.moveSpread = sv.perfGap or DEFAULTS.perfGap
    KEYBIND_STRIP:AddKeybindButtonGroup(self.moveKeybinds)
    DIRECTIONAL_INPUT:Activate(self.mover, self.panel)
    ME:SetPlacing(true)
    self:Render(true)
    self:UpdateVisibility()
end

function PF:OnMoveHidden()
    DIRECTIONAL_INPUT:Deactivate(self.mover)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.moveKeybinds)
    if not self.moveSaved then
        self:SetScale(self.moveStartSize)
        self:SetSpread(self.moveStartSpread)
        self:SetPosition(self.moveStartX, self.moveStartY)
    end
    self.moving = false
    ME:RaiseWhilePlacing({ self.panel }, false)
    ME:SetPlacing(false)
    if self.movePreview then
        self.movePreview = false
        self:SetPreview(true)
    else
        self:Render(true)
        self:UpdateVisibility()
    end
end

function PF:EndMove(save)
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
function PF:GetPreviewControls()
    if self.panel then return { self.panel } end
    return {}
end

function PF:GetOptions()
    local function IsOff() return not SV().perfShow end

    local function Sample()
        local r, g, b = TextColor()
        return SampleText(), SampleFont(), r, g, b
    end

    return {
        {
            type    = "submenu",
            name    = "FPS / Ping",
            tooltip = "Shows your frame rate and ping on screen.\n\n" .. ME.SAVED_ACCOUNT_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Enabled",
                    preset  = "YES_NO",
                    default = DEFAULTS.perfShow,
                    tooltip = "Shows your frame rate and ping on screen. They update once a second.",
                    getFunc = function() return SV().perfShow end,
                    setFunc = function(val)
                        SV().perfShow = val
                        PF:Refresh()
                    end,
                },
                {
                    type    = "toggle",
                    name    = "Preview",
                    tooltip = "Shows your frame rate and ping here so you can see your changes. "
                           .. "Stays on until you turn it off or leave the settings.",
                    getFunc = function() return PF.preview end,
                    setFunc = function(val) PF:SetPreview(val) end,
                },
                {
                    type       = "button",
                    name       = "Move / Scale",
                    buttonText = "Move / Scale",
                    tooltip    = "Move it with the left stick. Right stick up and down scales it, left and right makes it longer or shorter.",
                    func       = function() PF:StartMove() end,
                },
                {
                    type     = "checklist",
                    name     = "Show",
                    choices  = self.partChoices,
                    default  = { "fps", "ping" },
                    tooltip  = "What it shows.\n\n"
                            .. "FPS: your frame rate, how many frames a second the game is drawing.\n"
                            .. "Ping: how long it takes the server to answer you, in milliseconds.",
                    disabled = IsOff,
                    getFunc  = function()
                        local sv = SV()
                        local values = {}
                        for i = 1, #PF.partChoices do
                            local value = PF.partChoices[i].value
                            if sv[PART_KEYS[value]] then values[#values + 1] = value end
                        end
                        return values
                    end,
                    setFunc  = function(values)
                        local sv = SV()
                        local set = {}
                        if type(values) == "table" then
                            for i = 1, #values do set[values[i]] = true end
                        end
                        for value, key in pairs(PART_KEYS) do
                            sv[key] = set[value] == true
                        end
                        PF:Render(true)
                    end,
                },
                {
                    type    = "submenu",
                    name    = "Appearance",
                    tooltip = "Colors, font and background for your frame rate and ping.",
                    options = {
                        {
                            type    = "dropdown",
                            name    = "Font",
                            choices = ME.FONT_CHOICES,
                            default = DEFAULTS.perfFont,
                            sample  = Sample,
                            getFunc = function() return SV().perfFont end,
                            setFunc = function(val)
                                SV().perfFont = val
                                PF:Render(true)
                            end,
                        },
                        {
                            type    = "toggle",
                            name    = "Color by Value",
                            preset  = "YES_NO",
                            default = DEFAULTS.perfColorByValue,
                            tooltip = "Colors each number by how good it is.",
                            details = function()
                                if SV().perfColorByValue then
                                    return "|c" .. GOOD .. "Green|r: FPS 60 and up, ping under 150.\n"
                                        .. "|c" .. OKAY .. "Yellow|r: FPS 30 to 59, ping 150 to 299.\n"
                                        .. "|c" .. BAD .. "Red|r: FPS under 30, ping 300 and up."
                                end
                                return "Both numbers use your Text Color."
                            end,
                            getFunc = function() return SV().perfColorByValue end,
                            setFunc = function(val)
                                SV().perfColorByValue = val
                                PF:Render(true)
                            end,
                        },
                        {
                            type     = "colorpicker",
                            name     = ME.RainbowText("Text Color"),
                            default  = DEFAULTS.perfColor,
                            disabled = function() return SV().perfColorByValue end,
                            sample   = Sample,
                            getFunc  = function()
                                local r, g, b = TextColor()
                                return r, g, b, 1
                            end,
                            setFunc  = function(r, g, b)
                                SV().perfColor = { r = r, g = g, b = b, a = 1 }
                                PF:Render(true)
                            end,
                        },
                        {
                            type    = "toggle",
                            name    = "Background",
                            preset  = "YES_NO",
                            default = DEFAULTS.perfBackground,
                            tooltip = "Puts a black box behind your frame rate and ping so they're easier to read.",
                            getFunc = function() return SV().perfBackground end,
                            setFunc = function(val)
                                SV().perfBackground = val
                                PF:ApplyBox()
                            end,
                        },
                        {
                            type     = "slider",
                            name     = "Background Opacity",
                            min      = 0, max = 100, step = 5,
                            default  = DEFAULTS.perfBackgroundOpacity,
                            tooltip  = "Default is " .. DEFAULTS.perfBackgroundOpacity .. ".",
                            disabled = function() return not SV().perfBackground end,
                            getFunc  = function() return SV().perfBackgroundOpacity end,
                            setFunc  = function(val)
                                SV().perfBackgroundOpacity = val
                                PF:ApplyBox()
                            end,
                        },
                    },
                },
            },
        },
    }
end

function PF:OnSettingsState(newState)
    if newState == SCENE_HIDDEN and self.preview then
        self:SetPreview(false)
    end
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function PF:Init()
    self:CreatePanel()
    self:RegisterScenes()
    self:Refresh()
end

function PF:OnPlayerActivated()
    self:Refresh()
end

function PF:OnReset()
    self.preview = false
    self:Refresh()
end

ME:RegisterFeature(PF)
