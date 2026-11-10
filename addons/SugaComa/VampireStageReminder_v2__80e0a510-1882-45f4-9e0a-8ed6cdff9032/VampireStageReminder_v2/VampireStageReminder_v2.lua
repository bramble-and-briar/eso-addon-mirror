--------------------------------------------------------------
-- VampireStageReminder_v2.lua — v2.1.4 "Fang Indicator"
-- Author: SugaComa (Rik Sprint)
-- Console-safe, PS5 tested
--
-- New in v2.0:
--   • Muted startup if player is not a vampire
--   • Zone change / recheck no longer trigger click sounds
--   • Cleaner block headers for readability
--   • Retains original polling and adaptive reminders
--------------------------------------------------------------

VampireStageReminder_v2 = {}
VampireStageReminder_v2.name    = "VampireStageReminder_v2"
VampireStageReminder_v2.version = "2.1.4"

--------------------------------------------------------------
-- Timing defaults
--------------------------------------------------------------
local REMINDER_WINDOW_SEC = 30 * 60
local REMINDER_PERIOD_MS  = 5 * 60 * 1000
local checkInterval       = 90 * 1000
local MESSAGE_DELAY       = 2000
-- The ultimate frame extends 12 UI units past each edge of the icon.
local MAX_FANG_SIZE       = (ZO_GAMEPAD_ULTIMATE_BUTTON_SIZE or 67) + 24
VampireStageReminder_v2.maxFangSize = MAX_FANG_SIZE

--------------------------------------------------------------
-- Colours
--------------------------------------------------------------
local COLOR_MAGENTA = "|cFF00FF"
local COLOR_YELLOW  = "|cFFFF66"
local COLOR_END     = "|r"

--------------------------------------------------------------
-- State
--------------------------------------------------------------
local reminderToken   = 0
local lastMessageTime = 0
local SV_VERSION      = 2
local SV              = nil
local currentStage    = nil
local activeReminderKey = nil
local muted           = false  -- True when not a vampire

--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------
local function CanonicalizeName(s)
    if not s or s == "" then return nil end
    s = tostring(s)
    s = s:gsub("[\226\128\153\226\128\156\226\128\157]", "'")
    s = s:gsub("[\226\128\147\226\128\148]", "-")
    s = s:gsub("%^.", "")
    s = s:gsub("[^%w%s'-]", "")
    s = s:gsub("%s+", " ")
    s = s:match("^%s*(.-)%s*$") or ""
    return zo_strlower(s)
end

local function fmt_hms(total)
    local s = math.max(0, math.floor(total or 0))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local r = s % 60
    return h, m, r
end

local function Print(msg, soundId, automatic)
    if muted then return end
    local now   = GetFrameTimeSeconds() * 1000
    local delay = math.max(0, lastMessageTime + MESSAGE_DELAY - now)
    zo_callLater(function()
        if automatic and (muted or not SV.autoReminders) then return end
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, soundId or nil,
            "[VampireStageReminder_v2] " .. tostring(msg))
        lastMessageTime = GetFrameTimeSeconds() * 1000
    end, delay)
end

--------------------------------------------------------------
-- Buff definitions
--------------------------------------------------------------
local KNOWN_VAMPIRE_BUFFS = {
    ["vampirism stage 1"] = 1,
    ["vampirism stage 2"] = 2,
    ["vampirism stage 3"] = 3,
    ["vampirism stage 4"] = 4,
    ["vampirism stage 5"] = 5,
    ["vampirism"]         = 1,
}

local BUFF_NAME_ALIASES = {
    ["vampire stage 1"] = "vampirism stage 1",
    ["vampire stage 2"] = "vampirism stage 2",
    ["vampire stage 3"] = "vampirism stage 3",
    ["vampire stage 4"] = "vampirism stage 4",
    ["vampire stage 5"] = "vampirism stage 5",
    ["vampire"]         = "vampirism",
}

local function IsVampireBuff(buffName)
    local n = CanonicalizeName(buffName)
    if not n then return false, nil end
    if KNOWN_VAMPIRE_BUFFS[n] then
        return true, KNOWN_VAMPIRE_BUFFS[n], n ~= "vampirism"
    end
    local alias = BUFF_NAME_ALIASES[n]
    if alias and KNOWN_VAMPIRE_BUFFS[alias] then
        return true, KNOWN_VAMPIRE_BUFFS[alias], alias ~= "vampirism"
    end
    return false, nil
end

--------------------------------------------------------------
-- Core query
--------------------------------------------------------------
local function QueryVampireStage()
    local bestStage, bestStart, bestFinish, bestPriority
    local now = GetFrameTimeSeconds()
    for i = 1, GetNumBuffs("player") do
        local name, start, finish = GetUnitBuffInfo("player", i)
        local isVampire, stage, numbered = IsVampireBuff(name)
        if isVampire then
            start, finish = start or 0, finish or 0
            -- The generic Vampirism buff can coexist with a numbered stage.
            local priority = numbered and 2 or 1
            if finish > 0 and finish <= now then priority = 0 end
            if not bestPriority or priority > bestPriority
                or (priority == bestPriority and start > bestStart)
                or (priority == bestPriority and start == bestStart and stage > bestStage) then
                bestStage, bestStart, bestFinish, bestPriority = stage, start, finish, priority
            end
        end
    end
    if bestStage then
        return true, bestStage, math.max(0, bestFinish - now), bestFinish, bestStart
    end
    return false, nil, 0, 0
end

--------------------------------------------------------------
-- Fang HUD. Cache the buff timestamps from the normal stage scan.
--------------------------------------------------------------
local hud, background, frame, fang, fill, stageLabel
local hudStage, hudStart, hudFinish
local previewScene

function VampireStageReminder_v2:RefreshFangIndicator()
    if not hud then return end
    local preview = previewScene and SCENE_MANAGER:GetCurrentScene() == previewScene
        and previewScene:IsShowing()
    if not preview then previewScene = nil end
    local stage = preview and 3 or hudStage
    local inHud = HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()
    local show = stage ~= nil and (preview or (inHud and SV.showFangs))
    hud:SetHidden(not show)
    if not show then return end

    local fraction = 1
    if preview then
        fraction = 0.5
    elseif stage > 1 and hudFinish > hudStart and hudFinish > 0 then
        fraction = math.max(0, math.min(1,
            (hudFinish - GetFrameTimeSeconds()) / (hudFinish - hudStart)))
    end

    local size = SV.fangSize
    local width, height = GuiRoot:GetDimensions()
    hud:ClearAnchors()
    hud:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        math.max(0, width - size) * SV.fangX / 100,
        math.max(0, height - size) * SV.fangY / 100)
    hud:SetDimensions(size, size)
    frame:SetDimensions(size, size)
    background:SetCenterColor(0, 0, 0, SV.fangBackgroundOpacity / 100)
    local iconSize = size - 6
    local quadrantSize = size / 2 - 3
    stageLabel:SetDimensions(quadrantSize, quadrantSize)
    stageLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", math.floor(size * 0.34)))
    stageLabel:SetText(tostring(stage))
    fill:SetHidden(fraction == 0)
    if fraction > 0 then
        fill:SetDimensions(iconSize, iconSize * fraction)
        fill:SetTextureCoords(0, 1, 1 - fraction, 1)
    end
end

local function InitializeFangIndicator()
    local addon = VampireStageReminder_v2
    hud = WINDOW_MANAGER:CreateTopLevelWindow(addon.name .. "FangHUD")
    hud:SetHidden(true)
    hud:SetDrawTier(DT_HIGH)
    hud:SetDrawLayer(DL_OVERLAY)
    hud:SetDrawLevel(50)
    local function CreateHudControl(suffix, kind, level)
        local control = WINDOW_MANAGER:CreateControl(addon.name .. "Fang" .. suffix, hud, kind)
        control:SetDrawLayer(DL_OVERLAY)
        control:SetDrawLevel(50 + level)
        return control
    end

    frame = CreateHudControl("Frame", CT_BACKDROP, 3)
    frame:SetAnchor(TOPLEFT, hud, TOPLEFT)
    frame:SetEdgeTexture("EsoUI/Art/HUD/Gamepad/gp_UltimateFrame_edge.dds", 128, 16, 8)
    frame:SetCenterColor(0, 0, 0, 0)

    background = CreateHudControl("Background", CT_BACKDROP, 0)
    background:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    background:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    background:SetEdgeColor(0, 0, 0, 0)

    local texture = "EsoUI/Art/Armory/BuildIcons/buildIcon_44.dds" -- H2 on the six-column icon guide.
    fang = CreateHudControl("Base", CT_TEXTURE, 1)
    fang:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 3)
    fang:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -3)
    fang:SetTexture(texture)
    fang:SetColor(0.28, 0.28, 0.28, 1)

    fill = CreateHudControl("Fill", CT_TEXTURE, 2)
    fill:SetAnchor(BOTTOMLEFT, fang, BOTTOMLEFT)
    fill:SetTexture(texture)
    fill:SetColor(1, 0.12, 0.12, 1)

    stageLabel = CreateHudControl("Stage", CT_LABEL, 4)
    stageLabel:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -3)
    stageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    addon:RefreshFangIndicator()
    local function Refresh()
        addon:RefreshFangIndicator()
    end
    HUD_SCENE:RegisterCallback("StateChange", Refresh)
    HUD_UI_SCENE:RegisterCallback("StateChange", Refresh)
    EVENT_MANAGER:RegisterForUpdate(addon.name .. "_FangHUD", 1000, Refresh)
end

function VampireStageReminder_v2:IsFangPreviewEnabled()
    return previewScene ~= nil
end

function VampireStageReminder_v2:SetFangPreview(enabled)
    -- Use the scene that actually hosts the controller setting on this client.
    previewScene = enabled and SCENE_MANAGER:GetCurrentScene() or nil
    self:RefreshFangIndicator()
end

local function MakeReminderKey(stage, finish)
    return string.format("%d:%d", tonumber(stage) or 0, math.floor(tonumber(finish) or 0))
end

--------------------------------------------------------------
-- Reminder loop
--------------------------------------------------------------
-- Forward declaration: StartReminders is defined before the scanner below.
-- Without this, a delayed reference resolves to a nil global in Lua.
local CheckVampireStage

local function StopReminders()
    reminderToken = reminderToken + 1
    activeReminderKey = nil
end

local function StartReminders(stage, finish)
    local key = MakeReminderKey(stage, finish)
    if activeReminderKey == key then return end

    local myToken = reminderToken + 1
    reminderToken = myToken
    activeReminderKey = key

    local function tick()
        if myToken ~= reminderToken or activeReminderKey ~= key or not SV.autoReminders then return end

        local isVampire, currentStageValue, remaining, currentFinish = QueryVampireStage()
        if not isVampire then
            muted = true
            StopReminders()
            currentStage = nil
            return
        end
        muted = false

        local currentKey = MakeReminderKey(currentStageValue, currentFinish)
        if currentKey ~= key then
            StopReminders()
            CheckVampireStage()
            return
        end

        -- Stage 1 is the minimum vampire stage and has no decay timer.
        -- A zero/expired timer should never start a rapid recheck loop;
        -- EVENT_EFFECT_CHANGED and the normal 90-second poll catch transitions.
        if (currentStageValue or 1) <= 1 or remaining <= 0 then
            StopReminders()
            return
        end

        ----------------------------------------------------------
        -- Adaptive cadence (center screen on final stage)
        ----------------------------------------------------------
        local h, m, s = fmt_hms(remaining)
        local timerColor = COLOR_YELLOW
        local nextMs = REMINDER_PERIOD_MS
        local soundToPlay = nil

        local finalStageSec = (SV and (SV.finalStageMin or 3) or 3) * 60
        local intervalSec   = math.max(1, (SV and (SV.finalStageInterval or 15) or 15))

        if remaining <= finalStageSec then
            -- Keep the urgent colour inside three minutes, but never override
            -- the reminder interval selected by the player.
            timerColor = (remaining <= 180) and "|cFF0000" or "|cFFA500"
            nextMs = intervalSec * 1000
            if VampireStageReminder_v2.soundEnabled then
                soundToPlay = (remaining <= 180) and SOUNDS.DUEL_START or SOUNDS.ABILITY_ULTIMATE_READY
            end

            local msg = string.format(
                "%sStage %d%s — %s%02dh %02dm %02ds%s to next stage",
                COLOR_MAGENTA, currentStageValue or 1, COLOR_END,
                timerColor, h, m, s, COLOR_END
            )
            local CSA = CENTER_SCREEN_ANNOUNCE
            if CSA and CSA.CreateMessageParams then
                local p = CSA:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, soundToPlay)
                p:SetText(msg)
                CSA:DisplayMessage(p)
            else
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, soundToPlay, msg)
            end

        elseif remaining <= REMINDER_WINDOW_SEC then
            local secondsToFinalStage = math.max(1, remaining - finalStageSec)
            nextMs = math.min(5 * 60, secondsToFinalStage) * 1000
            local msg = string.format(
                "%sStage %d%s — %s%02dh %02dm %02ds%s to next stage",
                COLOR_MAGENTA, currentStageValue or 1, COLOR_END,
                COLOR_YELLOW, h, m, s, COLOR_END
            )
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, msg)
        end

        zo_callLater(tick, math.floor(nextMs))
    end

    tick()
end

--------------------------------------------------------------
-- Periodic scan
--------------------------------------------------------------
CheckVampireStage = function()
    local isVampire, stage, remaining, finish, start = QueryVampireStage()
    hudStage, hudStart, hudFinish = stage, start, finish
    VampireStageReminder_v2:RefreshFangIndicator()
    if not isVampire then
        muted = true
        StopReminders()
        currentStage = nil
        return
    end

    muted = false
    local stageChanged = stage ~= currentStage
    currentStage = stage
    if stageChanged and SV.autoReminders then
        if stage <= 1 or remaining <= 0 then
            Print(string.format(
                "Stage changed to %sStage 1%s — minimum vampire stage; no decay countdown.",
                COLOR_MAGENTA, COLOR_END), nil, true)
        else
            local h, m, s = fmt_hms(remaining)
            local msg = string.format(
                "Stage changed to %sStage %d%s — %s%02dh %02dm %02ds%s to next stage",
                COLOR_MAGENTA, stage, COLOR_END,
                COLOR_YELLOW, h, m, s, COLOR_END)
            Print(msg, nil, true)
        end
    end

    if SV.autoReminders and stage and stage > 1 and remaining > 0 and remaining <= REMINDER_WINDOW_SEC then
        StartReminders(stage, finish)
    else
        StopReminders()
    end
end

--------------------------------------------------------------
-- Timer helpers
--------------------------------------------------------------
local function PausePolling()
    EVENT_MANAGER:UnregisterForUpdate("VampireStageReminder_v2_CheckBuff")
end

function VampireStageReminder_v2:ApplyReminderSetting()
    CheckVampireStage()
end

local function ResumePolling()
    EVENT_MANAGER:UnregisterForUpdate("VampireStageReminder_v2_CheckBuff")
    EVENT_MANAGER:RegisterForUpdate("VampireStageReminder_v2_CheckBuff", checkInterval, CheckVampireStage)
end

--------------------------------------------------------------
-- Events + Slash Commands
--------------------------------------------------------------
local function SenseCheckVampire()
    local isVampire, stage, remaining, finish = QueryVampireStage()
    if not isVampire then
        muted = true
        StopReminders()
        currentStage = nil
        return
    end
    muted = false
    currentStage = stage

    if (stage or 1) <= 1 or remaining <= 0 then
        Print(string.format(
            "%sStage 1%s — minimum vampire stage; no decay countdown.",
            COLOR_MAGENTA, COLOR_END))
        StopReminders()
        return
    end

    local h, m, s = fmt_hms(remaining)
    local msg = string.format("%sStage %d%s — %s%02dh %02dm %02ds%s to next stage",
        COLOR_MAGENTA, stage, COLOR_END,
        COLOR_YELLOW, h, m, s, COLOR_END)
    Print(msg)
    if SV.autoReminders and remaining <= REMINDER_WINDOW_SEC then StartReminders(stage, finish) else StopReminders() end
end

--------------------------------------------------------------
-- SavedVars + Sound Toggle
--------------------------------------------------------------
VampireStageReminder_v2.soundEnabled = true

local function InitializeSavedVars()
    local defaults = {
        soundEnabled = true,
        autoReminders = true,
        showFangs = true,
        fangSize = math.min(64, MAX_FANG_SIZE),
        fangBackgroundOpacity = 70,
        fangX = 82,
        fangY = 20,
        finalStageMin = 3,
        finalStageInterval = 15,
    }
    local ok, sv = pcall(function()
        return VampireStageReminder_Framework:NewAccountWide("VampireStageReminder_v2_SV", SV_VERSION, nil, defaults)
    end)
    if not ok or type(sv) ~= "table" then
        sv = ZO_DeepTableCopy(defaults)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,
            "[VampireStageReminder_v2] Failed to initialize SavedVariables; using defaults.")
    end
    sv.fangSize = math.max(32, math.min(MAX_FANG_SIZE, sv.fangSize))
    SV = sv
    VampireStageReminder_v2.SV = SV
    VampireStageReminder_v2.soundEnabled       = SV.soundEnabled
    VampireStageReminder_v2.finalStageMin      = SV.finalStageMin
    VampireStageReminder_v2.finalStageInterval = SV.finalStageInterval
end

local function SaveState()
    if SV then
        SV.soundEnabled       = VampireStageReminder_v2.soundEnabled
        SV.finalStageMin      = VampireStageReminder_v2.finalStageMin or SV.finalStageMin
        SV.finalStageInterval = VampireStageReminder_v2.finalStageInterval or SV.finalStageInterval
    end
end

local function ToggleSound()
    VampireStageReminder_v2.soundEnabled = not VampireStageReminder_v2.soundEnabled
    if SV then SV.soundEnabled = VampireStageReminder_v2.soundEnabled end
    local status = VampireStageReminder_v2.soundEnabled and "|c00FF00ENABLED|r" or "|cFF0000DISABLED|r"
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "[VampireStageReminder_v2] Sound alerts " .. status)
end

--------------------------------------------------------------
-- Activation + Menu Hook
--------------------------------------------------------------
local function OnPlayerActivated()
    ResumePolling()
    EVENT_MANAGER:UnregisterForEvent(VampireStageReminder_v2.name, EVENT_EFFECT_CHANGED)
    local scanPending = false
    EVENT_MANAGER:RegisterForEvent(VampireStageReminder_v2.name, EVENT_EFFECT_CHANGED,
        function(_, _, _, _, unitTag)
            if unitTag ~= "player" or scanPending then return end
            scanPending = true
            -- Let the buff list settle after gain/fade events from the same drink.
            zo_callLater(function()
                scanPending = false
                CheckVampireStage()
            end, 100)
        end)
    CheckVampireStage()
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= VampireStageReminder_v2.name then return end
    EVENT_MANAGER:UnregisterForEvent(VampireStageReminder_v2.name, EVENT_ADD_ON_LOADED)
    InitializeSavedVars()
    InitializeFangIndicator()

    EVENT_MANAGER:RegisterForEvent(VampireStageReminder_v2.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(VampireStageReminder_v2.name, EVENT_PLAYER_DEACTIVATED, SaveState)
    EVENT_MANAGER:RegisterForEvent(VampireStageReminder_v2.name, EVENT_PLAYER_LOGOUT, SaveState)

    SLASH_COMMANDS["/vampcheck"]     = SenseCheckVampire
    SLASH_COMMANDS["/vampmute"] = ToggleSound

    local function TryAttachVSRMenu_v2()
        if VSRMenu_v2 and VSRMenu_v2.Setup then
            zo_callLater(function() VSRMenu_v2.Setup(VampireStageReminder_v2) end, 6000)
        else
            zo_callLater(TryAttachVSRMenu_v2, 4000)
        end
    end
    if LibHarvensAddonSettings then zo_callLater(TryAttachVSRMenu_v2, 5000) end

    Print("VampireStageReminder_v2 v" .. VampireStageReminder_v2.version .. " loaded.")
end

EVENT_MANAGER:RegisterForEvent(VampireStageReminder_v2.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)