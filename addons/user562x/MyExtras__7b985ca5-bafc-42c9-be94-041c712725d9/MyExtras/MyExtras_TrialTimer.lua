local ME = MyExtras
local DT = ME.DungeonsTrials
local TT = {}
ME.TrialTimer = TT

--------------------------------------------------
-- Config
--------------------------------------------------
local EVENT_NAME    = ME.name .. "_TrialTimer"
local TICK_MS       = 500
local PART_GAP      = 5
local MOVE_SPEED    = 500
local SCALE_SPEED   = 10
local SIZE_MIN      = 18
local SIZE_MAX      = 60
local BOX_PAD_X     = 0.45
local BOX_PAD_Y     = 0.2
local BOX_CORNER    = 0.35
local ICON_SCALE    = 1.1
local ICON_TIME     = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_timer32.dds"
local ICON_VITALITY = "EsoUI/Art/Trials/VitalityDepletion.dds"
local ICON_SCORE    = "EsoUI/Art/Trials/trialPoints_normal.dds"

local PREVIEW = { duration = 754000, remaining = 32, starting = 36, score = 87420, best = 105630 }

local DEFAULTS = {
    trialTimerShow              = false,
    trialTimerTime              = true,
    trialTimerVitality          = true,
    trialTimerScore             = true,
    trialTimerBest              = true,
    trialTimerFont              = "EsoUI/Common/Fonts/FTN57.otf",
    trialTimerSize              = 30,
    trialTimerStretch           = 100,
    trialTimerColor             = { r = 1, g = 1, b = 1, a = 1 },
    trialTimerPosX              = 0,
    trialTimerPosY              = -440,
    trialTimerBackground        = true,
    trialTimerBackgroundOpacity = 100,
}
DT:AddDefaults(DEFAULTS)

TT.partChoices = {
    { name = "Time",       value = "time"     },
    { name = "Vitality",   value = "vitality" },
    { name = "Score",      value = "score"    },
    { name = "Best Score", value = "best"     },
}

local PART_KEYS = {
    time     = "trialTimerTime",
    vitality = "trialTimerVitality",
    score    = "trialTimerScore",
    best     = "trialTimerBest",
}

local RUN_EVENTS = {
    "EVENT_RAID_TRIAL_STARTED",
    "EVENT_RAID_TRIAL_COMPLETE",
    "EVENT_RAID_TRIAL_FAILED",
    "EVENT_RAID_TRIAL_SCORE_UPDATE",
    "EVENT_RAID_REVIVE_COUNTER_UPDATE",
    "EVENT_RAID_TIMER_STATE_UPDATE",
    "EVENT_RAID_LEADERBOARD_PLAYER_DATA_CHANGED",
}

TT.preview = false
TT.moving  = false

local hudShowing = { hud = false, hudui = false }
local watching   = false
local ticking    = false
local lastText   = nil
local run        = { final = false, duration = 0, score = 0, raidId = nil, best = nil }

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return DT:Settings()
end

local function TextFont()
    local sv = SV()
    return string.format("%s|%d|soft-shadow-thick", sv.trialTimerFont, sv.trialTimerSize)
end

local function SampleFont()
    return string.format("%s|40|soft-shadow-thick", SV().trialTimerFont)
end

local function TextColor()
    local c = SV().trialTimerColor
    if type(c) ~= "table" then return 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1
end

local function FormatTime(ms)
    local total = zo_floor(zo_max(0, ms or 0) / 1000)
    local hours = zo_floor(total / 3600)
    local minutes = zo_floor((total % 3600) / 60)
    local seconds = total % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    end
    return string.format("%d:%02d", minutes, seconds)
end

local function Part(icon, text, size)
    return zo_iconFormat(icon, size, size) .. " " .. text
end

local function BuildText(info, size)
    local sv = SV()
    local iconSize = zo_floor(size * ICON_SCALE)
    local parts = {}
    if sv.trialTimerTime then
        parts[#parts + 1] = Part(ICON_TIME, FormatTime(info.duration), iconSize)
    end
    if sv.trialTimerVitality and info.remaining and info.starting then
        parts[#parts + 1] = Part(ICON_VITALITY, info.remaining .. "/" .. info.starting, iconSize)
    end
    local scoreText
    if sv.trialTimerScore then scoreText = ZO_CommaDelimitNumber(info.score or 0) end
    if sv.trialTimerBest and (info.best or 0) > 0 then
        local bestText = "Best " .. ZO_CommaDelimitNumber(info.best)
        scoreText = scoreText and (scoreText .. " (" .. bestText .. ")") or bestText
    end
    if scoreText then parts[#parts + 1] = Part(ICON_SCORE, scoreText, iconSize) end
    return table.concat(parts, string.rep(" ", PART_GAP))
end

local function SampleText()
    return BuildText(PREVIEW, 40)
end

--------------------------------------------------
-- Trial
--------------------------------------------------
local function InTrial()
    return IsPlayerInRaid() == true and (IsRaidInProgress() or HasRaidEnded())
end

local function ReadBest()
    local raidId = GetCurrentParticipatingRaidId and GetCurrentParticipatingRaidId() or 0
    if not raidId or raidId == 0 then return end
    if run.raidId ~= raidId then
        run.raidId = raidId
        run.best = nil
        if QueryRaidLeaderboardData and RAID_CATEGORY_TRIAL then
            pcall(QueryRaidLeaderboardData, RAID_CATEGORY_TRIAL, raidId)
        end
    end
    if GetRaidLeaderboardLocalPlayerInfo then
        local _, best = GetRaidLeaderboardLocalPlayerInfo(raidId)
        if (best or 0) > (run.best or 0) then run.best = best end
    end
end

local function CurrentInfo()
    local info = { best = run.best }
    if run.final then
        info.duration = run.duration
        info.score = run.score
    else
        info.duration = GetRaidDuration() or 0
        info.score = GetCurrentRaidScore() or 0
    end
    if IsPlayerInReviveCounterRaid() then
        info.remaining = GetRaidReviveCountersRemaining() or 0
        info.starting = GetCurrentRaidStartingReviveCounters() or 0
    end
    return info
end

local function Finish(duration, score, completed)
    run.final = true
    run.duration = duration or GetRaidDuration() or 0
    run.score = score or GetCurrentRaidScore() or 0
    if completed and run.score > (run.best or 0) then run.best = run.score end
end

--------------------------------------------------
-- Panel
--------------------------------------------------
function TT:CreatePanel()
    local panel = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_TrialTimerPanel")
    panel:SetDrawLayer(DL_BACKGROUND)
    panel:SetDrawTier(DT_LOW)
    panel:SetMouseEnabled(false)
    panel:SetDimensions(10, 10)
    panel:SetHidden(true)
    self.panel = panel

    local box = ME:CreateRoundBox("MyExtras_TrialTimerBox", panel)
    box:SetHidden(true)
    self.box = box

    local label = WINDOW_MANAGER:CreateControl("MyExtras_TrialTimerLabel", panel, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(CENTER, panel, CENTER, 0, 0)
    label:SetColor(1, 1, 1, 1)
    label:SetDrawLevel(2)
    self.label = label
end

function TT:ApplyBox()
    if not self.box then return end
    local sv = SV()
    local show = sv.trialTimerBackground == true
    self.box:SetHidden(not show)
    if not show then return end
    local size = sv.trialTimerSize or DEFAULTS.trialTimerSize
    local padX = zo_max(4, zo_floor(size * BOX_PAD_X))
    local padY = zo_max(2, zo_floor(size * BOX_PAD_Y))
    local opacity = tonumber(sv.trialTimerBackgroundOpacity) or DEFAULTS.trialTimerBackgroundOpacity
    self.box:SetFillColor(0, 0, 0, opacity / 100)
    self.box:SetCorner(zo_max(6, size * BOX_CORNER))
    self.box.control:ClearAnchors()
    self.box.control:SetAnchor(TOPLEFT, self.label, TOPLEFT, -padX, -padY)
    self.box.control:SetAnchor(BOTTOMRIGHT, self.label, BOTTOMRIGHT, padX, padY)
end

function TT:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(CENTER, GuiRoot, CENTER, sv.trialTimerPosX, sv.trialTimerPosY)
    ME:ApplyStretch(self.panel, SV().trialTimerStretch)
end

function TT:Render(force)
    if not self.label then return end
    local info
    if self.preview or self.moving then
        info = PREVIEW
    elseif InTrial() then
        info = CurrentInfo()
    else
        lastText = nil
        return
    end
    local text = BuildText(info, SV().trialTimerSize)
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
function TT:ShouldShow()
    if self.preview or self.moving then return true end
    if not SV().trialTimerShow or not InTrial() then return false end
    return hudShowing.hud or hudShowing.hudui or ME.placing == true
end

function TT:UpdateVisibility()
    if not self.panel then return end
    local show = self:ShouldShow()
    if show then self:Render() end
    self.panel:SetHidden(not show)
    self:UpdateTicking()
end

function TT:UpdateTicking()
    local tick = watching and not run.final and InTrial() and IsRaidInProgress() and not self.panel:IsHidden()
    if tick == ticking then return end
    ticking = tick
    if tick then
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAME .. "Tick", TICK_MS, function() TT:Render() end)
    else
        EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. "Tick")
    end
end

function TT:OnPlacing()
    self:UpdateVisibility()
end

function TT:SetPreview(value)
    self.preview = value == true
    self:Render(true)
    self:UpdateVisibility()
end

function TT:RegisterScenes()
    local names = { "hud", "hudui" }
    for i = 1, #names do
        local sceneName = names[i]
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            hudShowing[sceneName] = scene:IsShowing()
            scene:RegisterCallback("StateChange", function(oldState, newState)
                hudShowing[sceneName] = newState == SCENE_SHOWING or newState == SCENE_SHOWN
                TT:UpdateVisibility()
            end)
        end
    end
end

--------------------------------------------------
-- Events
--------------------------------------------------
local function OnRunEvent(eventCode, ...)
    if eventCode == EVENT_RAID_TRIAL_STARTED then
        run.final = false
    elseif eventCode == EVENT_RAID_TRIAL_COMPLETE then
        local _, score, totalTime = ...
        Finish(totalTime, score, true)
    elseif eventCode == EVENT_RAID_TRIAL_FAILED then
        local _, score = ...
        Finish(nil, score, false)
    end
    ReadBest()
    TT:Render()
    TT:UpdateVisibility()
end

function TT:Watch(on)
    if on == watching then return end
    watching = on
    for i = 1, #RUN_EVENTS do
        local event = rawget(_G, RUN_EVENTS[i])
        if event then
            if on then
                EVENT_MANAGER:RegisterForEvent(EVENT_NAME .. i, event, OnRunEvent)
            else
                EVENT_MANAGER:UnregisterForEvent(EVENT_NAME .. i, event)
            end
        end
    end
end

function TT:Refresh()
    self:Watch(SV().trialTimerShow == true)
    if watching and InTrial() then ReadBest() end
    self:ApplyPosition()
    self:Render(true)
    self:UpdateVisibility()
end

--------------------------------------------------
-- Move
--------------------------------------------------
function TT:StartMove()
    if self.moving then return end
    self.movePreview = self.preview
    self.moving = true
    local started = LibUser562:StartMove({
        controls    = { self.panel },
        moveSpeed   = MOVE_SPEED,
        scaleSpeed  = SCALE_SPEED,
        sizeMin     = SIZE_MIN,
        sizeMax     = SIZE_MAX,
        bounds      = function()
            local screenW, screenH = GuiRoot:GetDimensions()
            return -screenW / 2, screenW / 2, -screenH / 2, screenH / 2
        end,
        defaults    = {
            x    = DEFAULTS.trialTimerPosX,
            y    = DEFAULTS.trialTimerPosY,
            size = DEFAULTS.trialTimerSize,
        },
        getPosition = function() return SV().trialTimerPosX, SV().trialTimerPosY end,
        setPosition = function(x, y)
            local sv = SV()
            sv.trialTimerPosX, sv.trialTimerPosY = x, y
            TT:ApplyPosition()
        end,
        getSize    = function() return SV().trialTimerSize end,
        setSize    = function(size)
            SV().trialTimerSize = size
            TT:Render(true)
        end,
        getStretch = function() return SV().trialTimerStretch or 100 end,
        setStretch = function(percent)
            SV().trialTimerStretch = percent
            ME:ApplyStretch(TT.panel, percent)
        end,
        onShow = function()
            ME:SetPlacing(true)
            TT:Render(true)
            TT:UpdateVisibility()
        end,
        onHide = function()
            TT.moving = false
            ME:SetPlacing(false)
            if TT.movePreview then
                TT.movePreview = false
                TT:SetPreview(true)
            else
                TT:Render(true)
                TT:UpdateVisibility()
            end
        end,
    })
    if not started then self.moving = false end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function TT:GetPreviewControls()
    if self.panel then return { self.panel } end
    return {}
end

function TT:SubmenuOption()
    local function IsOff() return not SV().trialTimerShow end

    return {
        type    = "submenu",
        name    = "Trial Timer",
        tooltip = "Shows your trial's time, vitality and score on screen.",
        options = {
            {
                type    = "toggle",
                name    = "Enabled",
                preset  = "YES_NO",
                default = DEFAULTS.trialTimerShow,
                tooltip = "Shows your trial's time, vitality and score on screen while you're in a trial. "
                       .. "It also works in arenas, and stays up after the trial ends until you leave.",
                getFunc = function() return SV().trialTimerShow end,
                setFunc = function(val)
                    SV().trialTimerShow = val
                    TT:Refresh()
                end,
            },
            {
                type    = "toggle",
                name    = "Preview",
                tooltip = "Shows your timer here so you can see your changes. "
                       .. "Stays on until you turn it off or leave the settings.",
                getFunc = function() return TT.preview end,
                setFunc = function(val) TT:SetPreview(val) end,
            },
            {
                type       = "button",
                name       = "Move / Scale",
                buttonText = "Move / Scale",
                tooltip    = "Move it with the left stick. Right stick up and down scales it, left and right stretches it wider or narrower.",
                func       = function() TT:StartMove() end,
            },
            {
                type     = "checklist",
                name     = "Show",
                choices  = self.partChoices,
                default  = { "time", "vitality", "score", "best" },
                tooltip  = "What your timer shows.\n\n"
                        .. "Time: how long the trial has been running.\n"
                        .. "Vitality: how many revives your group has left.\n"
                        .. "Score: your group's score so far.\n"
                        .. "Best Score: your best score for this trial.",
                disabled = IsOff,
                getFunc  = function()
                    local sv = SV()
                    local values = {}
                    for i = 1, #TT.partChoices do
                        local value = TT.partChoices[i].value
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
                    TT:Render(true)
                end,
            },
            {
                type    = "submenu",
                name    = "Appearance",
                tooltip = "Font, color and background for your timer.",
                options = {
                    {
                        type    = "dropdown",
                        name    = "Font",
                        tooltip = "Some fonts look bigger or smaller than others. Default is Gamepad Medium.",
                        choices = ME.FONT_CHOICES,
                        default = DEFAULTS.trialTimerFont,
                        sample  = function()
                            local r, g, b = TextColor()
                            return SampleText(), SampleFont(), r, g, b
                        end,
                        getFunc = function() return SV().trialTimerFont end,
                        setFunc = function(val)
                            SV().trialTimerFont = val
                            TT:Render(true)
                        end,
                    },
                    {
                        type    = "colorpicker",
                        name    = ME.RainbowText("Text Color"),
                        default = DEFAULTS.trialTimerColor,
                        sample  = function()
                            local r, g, b = TextColor()
                            return SampleText(), SampleFont(), r, g, b
                        end,
                        getFunc = function()
                            local r, g, b = TextColor()
                            return r, g, b, 1
                        end,
                        setFunc = function(r, g, b)
                            SV().trialTimerColor = { r = r, g = g, b = b, a = 1 }
                            TT:Render(true)
                        end,
                    },
                    {
                        type    = "toggle",
                        name    = "Background",
                        preset  = "YES_NO",
                        default = DEFAULTS.trialTimerBackground,
                        tooltip = "Puts a black box behind your timer so it's easier to read.",
                        getFunc = function() return SV().trialTimerBackground end,
                        setFunc = function(val)
                            SV().trialTimerBackground = val
                            TT:ApplyBox()
                        end,
                    },
                    {
                        type     = "slider",
                        name     = "Background Opacity",
                        min      = 0, max = 100, step = 5,
                        default  = DEFAULTS.trialTimerBackgroundOpacity,
                        tooltip  = "Default is " .. DEFAULTS.trialTimerBackgroundOpacity .. ".",
                        disabled = function() return not SV().trialTimerBackground end,
                        getFunc  = function() return SV().trialTimerBackgroundOpacity end,
                        setFunc  = function(val)
                            SV().trialTimerBackgroundOpacity = val
                            TT:ApplyBox()
                        end,
                    },
                },
            },
        },
    }
end

function TT:OnSettingsState(newState)
    if newState == SCENE_HIDDEN and self.preview then
        self:SetPreview(false)
    end
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function TT:Init()
    self:CreatePanel()
    self:RegisterScenes()
    self:Refresh()
end

function TT:OnPlayerActivated()
    run.final = false
    run.raidId = nil
    run.best = nil
    if InTrial() and HasRaidEnded() then Finish() end
    self:Refresh()
end

function TT:OnReset()
    self.preview = false
    self:Refresh()
end

ME:RegisterFeature(TT)
