local ME = MyExtras
local PF = {}
ME.Performance = PF

--------------------------------------------------
-- Config
--------------------------------------------------
local EVENT_NAME  = ME.name .. "_Performance"
local TICK_MS     = 1000
local PART_GAP    = 5
local MOVE_SPEED  = 500
local SCALE_SPEED = 10
local SIZE_MIN    = 14
local SIZE_MAX    = 48
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
    perfStretch           = 100,
    perfColor             = { r = 1, g = 1, b = 1, a = 1 },
    perfPosX              = 120,
    perfPosY              = 40,
    perfBackground        = true,
    perfBackgroundOpacity = 100,
}
local DEFAULTS = PF.defaults
local scope = ME:NewScope("perfCharSettings")
scope:AddDefaults(DEFAULTS, "perf")

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
    return scope:Settings()
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
    return table.concat(parts, string.rep(" ", PART_GAP))
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
    ME:ApplyStretch(self.panel, SV().perfStretch)
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
function PF:StartMove()
    if self.moving then return end
    self.movePreview = self.preview
    self.moving = true
    local started = LibUser562:StartMove({
        controls    = { self.panel },
        moveSpeed   = MOVE_SPEED,
        scaleSpeed  = SCALE_SPEED,
        sizeMin     = SIZE_MIN,
        sizeMax     = SIZE_MAX,
        defaults    = {
            x    = DEFAULTS.perfPosX,
            y    = DEFAULTS.perfPosY,
            size = DEFAULTS.perfSize,
        },
        getPosition = function() return SV().perfPosX, SV().perfPosY end,
        setPosition = function(x, y)
            local sv = SV()
            sv.perfPosX, sv.perfPosY = x, y
            PF:ApplyPosition()
        end,
        getSize    = function() return SV().perfSize end,
        setSize    = function(size)
            SV().perfSize = size
            PF:Render(true)
        end,
        getStretch = function() return SV().perfStretch or 100 end,
        setStretch = function(percent)
            SV().perfStretch = percent
            ME:ApplyStretch(PF.panel, percent)
        end,
        onShow = function()
            ME:SetPlacing(true)
            PF:Render(true)
            PF:UpdateVisibility()
        end,
        onHide = function()
            PF.moving = false
            ME:SetPlacing(false)
            if PF.movePreview then
                PF.movePreview = false
                PF:SetPreview(true)
            else
                PF:Render(true)
                PF:UpdateVisibility()
            end
        end,
    })
    if not started then self.moving = false end
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
            tooltip = function()
                return "Shows your frame rate and ping on screen.\n\n" .. ME:SavedTip(scope, "perf")
            end,
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
                ME:CharacterOption(scope, "perf", function() PF:Refresh() end),
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
                    tooltip    = "Move it with the left stick. Right stick up and down scales it, left and right stretches it wider or narrower.",
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
                    tooltip = "Font, colors and background for your frame rate and ping.",
                    options = {
                        {
                            type    = "dropdown",
                            name    = "Font",
                            tooltip = "Some fonts look bigger or smaller than others. Default is Gamepad Medium.",
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
                            name    = "Color By Value",
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

function PF:ResetSkipKeys()
    return scope:ResetSkipKeys()
end

function PF:OnReset()
    scope:ResetCharacter()
    self.preview = false
    self:Refresh()
end

ME:RegisterFeature(PF)
