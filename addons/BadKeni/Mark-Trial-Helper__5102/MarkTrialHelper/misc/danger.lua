local AH = _G.MarkTrialHelper
local EM = EVENT_MANAGER

local heavyAttackList = {}
local dangerFrame = nil
local blinkState = false
local dangerUpdateTimer = nil
local dangerBlinkTimer = nil
local mechanicFrame = nil  -- Для уведомлений о механиках
local mechanicTimer = nil

local IA_COLOR_YELLOW = 'FFFF00'
local IA_COLOR_RED = 'FF0000'
local IA_COLOR_GREEN = '00FF00'
local IA_COLOR_BLUE = '1F51FF'
local IA_COLOR_CYAN = '00FFFF'
local IA_COLOR_PINK = 'FF00FF'
local IA_COLOR_ORANGE = 'FF6600'

local function SafeUnregisterUpdate(timerId)
    if timerId and type(timerId) == "string" then
        EM:UnregisterForUpdate(timerId)
        return true
    end
    return false
end
local function CreateDangerFrame()
    if dangerFrame then
        return dangerFrame
    end
    
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("MarkTrialHelperDangerFrame")
    frame:SetResizeToFitDescendents(true)
    frame:SetClampedToScreen(true)
    frame:SetDrawTier(DT_HIGH)
    frame:SetMouseEnabled(true)
    frame:SetMovable(true)
    frame:SetHidden(true)
    
    local label = WINDOW_MANAGER:CreateControl(nil, frame, CT_LABEL)
    label:SetAnchor(CENTER, frame, CENTER)
    label:SetFont("$(BOLD_FONT)|$(KB_40)|thick-outline")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 0, 1)
    label:SetText("")
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetWidth(400)
    label:SetHeight(60)
    
    frame.Label = label
    
    local x = 0
    local y = -50
    if AH.Vars and AH.Vars.DangerPosition then
        x = AH.Vars.DangerPosition.left or 0
        y = AH.Vars.DangerPosition.top or -50
    end
    frame:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    
    frame:SetHandler("OnMoveStop", function()
        local _, _, _, x, y = frame:GetAnchor(0)
        if AH.Vars then
            AH.Vars.DangerPosition = {left = x or 0, top = y or -50}
        end
    end)
    
    dangerFrame = frame
    return frame
end

local function CreateMechanicFrame()
    if mechanicFrame then
        return mechanicFrame
    end
    
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("MarkTrialHelperMechanicFrame")
    frame:SetResizeToFitDescendents(true)
    frame:SetClampedToScreen(true)
    frame:SetDrawTier(DT_HIGH)
    frame:SetMouseEnabled(true)
    frame:SetMovable(true)
    frame:SetHidden(true)
    
    local label = WINDOW_MANAGER:CreateControl(nil, frame, CT_LABEL)
    label:SetAnchor(CENTER, frame, CENTER)
    label:SetFont("$(BOLD_FONT)|$(KB_54)|soft-shadow-thick")  -- Как в
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 0, 0, 1)  -- Красный по умолчанию
    label:SetText("")
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetWidth(600)
    label:SetHeight(80)
    
    frame.Label = label
    
    local x = 0
    local y = -200
    if AH.Vars and AH.Vars.MechanicPosition then
        x = AH.Vars.MechanicPosition.left or 0
        y = AH.Vars.MechanicPosition.top or -200
    end
    frame:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    
    frame:SetHandler("OnMoveStop", function()
        local _, _, _, x, y = frame:GetAnchor(0)
        if AH.Vars then
            AH.Vars.MechanicPosition = {left = x or 0, top = y or -200}
        end
    end)
    
    mechanicFrame = frame
    return frame
end

function AH.ShowDanger(text, color)
    if not text or text == "" then
        return
    end
    
    local frame = CreateDangerFrame()
    if not frame or not frame.Label then
        return
    end
    
    if color == "FF0000" then
        frame.Label:SetColor(1, 0, 0, 1)
    elseif color == "FFFF00" then
        frame.Label:SetColor(1, 1, 0, 1)
    elseif color == "FF00FF" then
        frame.Label:SetColor(1, 0, 1, 1)
    elseif color == "1F51FF" then
        frame.Label:SetColor(0.12, 0.32, 1, 1)
    elseif color == "00FF00" then
        frame.Label:SetColor(0, 1, 0, 1)
    elseif color == "00FFFF" then
        frame.Label:SetColor(0, 1, 1, 1)
    else
        frame.Label:SetColor(1, 1, 0, 1)
    end
    
    frame.Label:SetText(text)
    frame:SetHidden(false)
    
    SafeUnregisterUpdate(dangerBlinkTimer)
    dangerBlinkTimer = nil
    
    if color == "FF0000" then
        blinkState = false
        dangerBlinkTimer = EM:RegisterForUpdate("MarkTrialHelperDangerBlink", 200, function()
            blinkState = not blinkState
            if frame and frame.Label then
                if blinkState then
                    frame.Label:SetColor(1, 0, 0, 1)
                else
                    frame.Label:SetColor(1, 1, 1, 1)
                end
            end
        end)
    end
end

function AH.ShowMechanic(text, color, duration)
    if not text or text == "" then
        return
    end
    
    local frame = CreateMechanicFrame()
    if not frame or not frame.Label then
        return
    end
    
    if color == "FF0000" then
        frame.Label:SetColor(1, 0, 0, 1)
    elseif color == "00FF00" then
        frame.Label:SetColor(0, 1, 0, 1)
    elseif color == "FFFF00" then
        frame.Label:SetColor(1, 1, 0, 1)
    else
        frame.Label:SetColor(1, 0, 0, 1)
    end
    
    frame.Label:SetText(text)
    frame:SetHidden(false)
    
    if duration and duration > 0 then
        SafeUnregisterUpdate(mechanicTimer)
        mechanicTimer = nil
        
        mechanicTimer = EM:RegisterForUpdate("MarkTrialHelperMechanicTimer", duration * 1000, function()
            AH.HideMechanic()
        end)
    end
end

function AH.HideMechanic()
    if mechanicFrame then
        mechanicFrame:SetHidden(true)
    end
    SafeUnregisterUpdate(mechanicTimer)
    mechanicTimer = nil
end

function AH.ShowPillarsOfNirn()
    AH.PlayAlarm(AH.Sounds.Terrain)
    AH.ShowMechanic("|cFF0000Pillars of Nirn|r", "FF0000", 4)
end

function AH.ShowSoulCage()
    AH.PlayAlarm(AH.Sounds.Terrain)
    AH.ShowMechanic("|cFF0000Soul Cage|r", "FF0000", 4)
end

function AH.ShowMeteor()
    AH.PlayAlarm(AH.Sounds.Terrain)
    AH.ShowMechanic("|cFF0000Meteor|r", "FF0000", 4)
end

function AH.ShowAbyss()
    AH.PlayAlarm(AH.Sounds.Terrain)
    AH.ShowMechanic("|cFF0000Abyss|r", "FF0000", 4)
end

function AH.ShowTotem()
    AH.ShowMechanic("|cFF0000Totem|r", "FF0000", 3)
end

function AH.ShowScamp()
    AH.PlayAlarm(AH.Sounds.Tomeshell)
    AH.ShowMechanic("|c00FF00Scamp!|r", "00FF00", 3)
end

function AH.ShowScampEscape()
    AH.ShowMechanic("|cFF0000Scamp!|r", "FF0000", 3)
end

function AH.ShowNegate()
    AH.PlayAlarm(AH.Sounds.Terrain)
    AH.ShowMechanic("|cFF0000Negate!|r", "FF0000", 2)
end

function AH.ShowInferno()
    AH.PlayAlarm(AH.Sounds.Terrain)
    AH.ShowMechanic("|cFF0000Inferno|r", "FF0000", 3)
end

local function FormatHeavyAttackList()
    local countdownList = {}
    local countdownListFormatted = {}
    local t = GetGameTimeMilliseconds()
    
    for _, value in ipairs(heavyAttackList) do
        if value[1] > t then
            table.insert(countdownList, {value[1] - t, value[2]})
        end
    end
    
    if #countdownList > 0 then
        table.sort(countdownList, function(a, b) return a[1] < b[1] end)
        for i = 1, zo_min(#countdownList, 3) do
            local value = countdownList[i]
            local remaining = value[1] / 1000
            local color = value[2]
            if remaining < 1.5 then
                color = IA_COLOR_RED
                table.insert(countdownListFormatted, string.format("|c%s%0.1f|r", color, remaining))
            else
                table.insert(countdownListFormatted, string.format("|c%s%0.1f|r", color, remaining))
            end
        end
        return table.concat(countdownListFormatted, " / ")
    else
        return nil
    end
end

function AH.UpdateHeavyAttackList()
    local text = FormatHeavyAttackList()
    
    if not text or text == "" then
        heavyAttackList = {}
        SafeUnregisterUpdate(dangerUpdateTimer)
        dangerUpdateTimer = nil
        SafeUnregisterUpdate(dangerBlinkTimer)
        dangerBlinkTimer = nil
        if dangerFrame then
            dangerFrame:SetHidden(true)
        end
    else
        AH.ShowDanger(string.format("> %s <", text))
    end
    
    if not dangerUpdateTimer and #heavyAttackList > 0 then
        dangerUpdateTimer = EM:RegisterForUpdate("MarkTrialHelperDangerUpdate", 100, AH.UpdateHeavyAttackList)
    end
end

function AH.RegisterHeavyAttack(duration, color, text, sound)
    if not AH.Vars.TrackDanger then return end
    if duration <= 0 then return end
    
    table.insert(heavyAttackList, {GetGameTimeMilliseconds() + duration, color or IA_COLOR_YELLOW})

    if duration < 1100 then
        if AH.Vars.EnableSounds then
            PlaySound(SOUNDS.DUEL_START)
        end
    else
        zo_callLater(function()
            if AH.Vars.EnableSounds then
                PlaySound(SOUNDS.DUEL_START)
            end
        end, duration - 900)
    end

    SafeUnregisterUpdate(dangerUpdateTimer)
    dangerUpdateTimer = nil
    AH.UpdateHeavyAttackList()
end

function AH.ResetDangerTimers()
    heavyAttackList = {}
    SafeUnregisterUpdate(dangerUpdateTimer)
    dangerUpdateTimer = nil
    SafeUnregisterUpdate(dangerBlinkTimer)
    dangerBlinkTimer = nil
    if dangerFrame then
        dangerFrame:SetHidden(true)
    end
    AH.HideMechanic()
end

function AH.OnDangerousAttack(abilityId, hitValue)
    if not AH.Vars.TrackDanger then return end
    if not AH.DANGER_IDS then return end
    
    local info = AH.DANGER_IDS[abilityId]
    if not info then return end
    
    local duration = info.duration or hitValue or 1500
    local color = info.color or IA_COLOR_YELLOW
    
    AH.RegisterHeavyAttack(duration, color)
end

function AH.DangerCombatEventHandler(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if not AH.Vars.TrackDanger then return end
    if not AH.DANGER_IDS then return end
    if not AH.DANGER_IDS[abilityId] then return end
    
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
    if targetType ~= COMBAT_UNIT_TYPE_PLAYER then
        if targetType ~= COMBAT_UNIT_TYPE_PET then return end
    end
    
    if result == ACTION_RESULT_BEGIN or result == ACTION_RESULT_EFFECT_GAINED_DURATION then
        local info = AH.DANGER_IDS[abilityId]
        local duration = info.duration or hitValue or 1500
        local color = info.color or IA_COLOR_YELLOW
        AH.RegisterHeavyAttack(duration, color)
    end
end

function AH.SetDangerPosition(x, y)
    if dangerFrame then
        dangerFrame:ClearAnchors()
        dangerFrame:SetAnchor(CENTER, GuiRoot, CENTER, x or 0, y or -50)
        if AH.Vars then
            AH.Vars.DangerPosition = {left = x or 0, top = y or -50}
        end
    end
end

function AH.HideDanger()
    if dangerFrame then
        dangerFrame:SetHidden(true)
    end
    SafeUnregisterUpdate(dangerUpdateTimer)
    dangerUpdateTimer = nil
    SafeUnregisterUpdate(dangerBlinkTimer)
    dangerBlinkTimer = nil
end

function AH.TestDanger()
    AH.RegisterHeavyAttack(3000, IA_COLOR_RED)
    AH.RegisterHeavyAttack(2000, IA_COLOR_YELLOW)
    AH.RegisterHeavyAttack(1500, IA_COLOR_BLUE)
    AH.ShowPillarsOfNirn()
end
