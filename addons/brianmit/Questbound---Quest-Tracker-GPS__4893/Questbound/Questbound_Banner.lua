-- Questbound_Banner.lua : short banner above the middle of the screen when the
-- followed quest moves on: what's done and where to go next ("Next: Talk to
-- Captain Rana · 140 m"). Fades in, stays 4 seconds, fades out.

local W = Questbound
local L = W.L
local C = W.COLOR
local B = {}
W.Banner = B

local NAME = "Questbound_Banner"
local FADE_IN, HOLD, FADE_OUT = 0.3, 4, 0.8
local DELAY_MS = 900      -- wait for the new objective position (distance in "Next")
local WIDTH = 460

local ui = {}
local startTime
local pendingTitle, pendingLine

local function StripCounter(text)
    text = zo_strformat("<<1>>", text or "")
    return text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text
end

-- First open objective of the quest.
local function NextObjective(qi)
    for step = 1, GetJournalQuestNumSteps(qi) do
        local _, visibility, _, overrideText, numConditions = GetJournalQuestStepInfo(qi, step)
        if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN and visibility ~= QUEST_STEP_VISIBILITY_OPTIONAL then
            if overrideText and overrideText ~= "" then return zo_strformat("<<1>>", overrideText) end
            for cond = 1, numConditions or 0 do
                local text, _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(qi, step, cond)
                if text and text ~= "" and not isFail and not isComplete and isVisible ~= false then
                    return StripCounter(text)
                end
            end
        end
    end
end

local function Tick()
    local t = GetFrameTimeSeconds() - startTime
    local a
    if t < FADE_IN then
        a = t / FADE_IN
    elseif t < FADE_IN + HOLD then
        a = 1
    elseif t < FADE_IN + HOLD + FADE_OUT then
        a = 1 - (t - FADE_IN - HOLD) / FADE_OUT
    else
        a = 0
        EVENT_MANAGER:UnregisterForUpdate(NAME)
        ui.box:SetHidden(true)
    end
    ui.box:SetAlpha(a)
end

local function Show()
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Delay")
    local title, line = pendingTitle, pendingLine
    pendingTitle, pendingLine = nil, nil
    if not title then return end

    local nextText = ""
    local nav = W.Nav.state
    local qi = nav.questIndex
    if qi and IsValidQuestIndex(qi) then
        local text = NextObjective(qi)
        if text then
            if nav.target and nav.target.kind == "quest" and nav.dist and not nav.arrived then
                text = text .. "  ·  " .. W.FormatDistance(nav.dist)
            end
            nextText = L("BANNER_NEXT", text)
        end
    end

    ui.title:SetFont(W.Font("title", 20))
    ui.line:SetFont(W.Font("quest", 17))
    ui.next:SetFont(W.Font("text", 14))
    ui.title:SetText(title)
    ui.line:SetText(line or "")
    ui.next:SetText(nextText)
    ui.next:SetColor(W.RGBA(C.theme))

    startTime = GetFrameTimeSeconds()
    ui.box:SetAlpha(0)
    ui.box:SetHidden(false)
    EVENT_MANAGER:RegisterForUpdate(NAME, 0, Tick)
end

local function Queue(title, line, keepEarlier)
    if not W.sv.banner then return end
    if keepEarlier and pendingTitle then return end   -- "objective complete" wins over "quest updated"
    pendingTitle, pendingLine = title, line
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Delay")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Delay", DELAY_MS, Show)
end

-- Preview: /wf banner
function B.Test()
    pendingTitle, pendingLine = L("BANNER_OBJECTIVE"), W.Nav.state.questName or L("TITLE")
    Show()
end

function B.Init()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Banner")
    ui.win = win
    win:SetDimensions(WIDTH, 120)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -170)
    win:SetMouseEnabled(false)

    local box = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.box = box
    box:SetAnchorFill(win)

    local function Divider(y)
        local t = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
        t:SetTexture(W.TEX .. "divider.dds")
        t:SetColor(W.RGBA(C.gold))
        t:SetDimensions(WIDTH, 12)
        t:SetAnchor(TOP, box, TOP, 0, y)
        return t
    end
    local function Label(anchorTo, y)
        local l = WINDOW_MANAGER:CreateControl(nil, box, CT_LABEL)
        l:SetWidth(WIDTH - 40)
        l:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        l:SetAnchor(TOP, anchorTo, BOTTOM, 0, y)
        return l
    end
    local top = Divider(0)
    ui.title = Label(top, 0)
    ui.title:SetColor(W.RGBA(C.done))
    ui.line = Label(ui.title, 0)
    ui.line:SetColor(1, 1, 1, 1)
    ui.next = Label(ui.line, 3)
    local bottom = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
    bottom:SetTexture(W.TEX .. "divider.dds")
    bottom:SetColor(W.RGBA(C.gold))
    bottom:SetDimensions(WIDTH, 12)
    bottom:SetAnchor(TOP, ui.next, BOTTOM, 0, 0)

    ui.fragment = W.HudFragment(win)
    box:SetHidden(true)   -- shown only while a banner plays

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_QUEST_CONDITION_COUNTER_CHANGED,
        function(_, journalIndex, _, conditionText, _, _, newValue, maxValue, isFail, _, _, _, isConditionComplete, isStepHidden)
            if journalIndex ~= W.Nav.state.questIndex or isFail or isStepHidden then return end
            local complete = isConditionComplete or (newValue and maxValue and maxValue > 0 and newValue >= maxValue)
            if not complete then return end
            Queue(L("BANNER_OBJECTIVE"), StripCounter(conditionText))
        end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_QUEST_ADVANCED,
        function(_, journalIndex, questName, _, _, mainStepChanged)
            if journalIndex ~= W.Nav.state.questIndex or not mainStepChanged then return end
            Queue(L("BANNER_STEP"), zo_strformat("<<1>>", questName), true)
        end)
end
