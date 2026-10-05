-- =============================================================================
-- === HuntsmanWarmaskReminder Core Logic (HuntsmanWarmaskReminder.lua)     ===
-- =============================================================================
--[[
    AddOn Name:         Huntsman Warmask Reminder
    Description:        Warns when Huntsman Warmask is equipped but buff is missing in combat
    Version:            2.0.5
    Author:             VollständigerName & Orollas & brainsnorkel
--]]


-- =============================================================================
-- == GLOBAL ADDON DEFINITION & VERSION CONTROL ================================
-- =============================================================================
local WarmasktrackerByJH = {
    name = "WarmasktrackerByJH",
    version = "2.0.5-console.9",
    settings = {
        enabled = true,  -- Default: reminder enabled
        onlyWhenEquipped = true, -- Only show tracker while Huntsman Warmask is equipped
        debugMode = false,  -- Default: debug disabled
        showOutsideCombat = false,
        toggleTimer = true,
        toggleWarning = false,
        LockPosition = true,
        showTargetName = false;
        timerFontSize = 32,  -- Timer font size (default 32px)
        targetFontSize = 15,
        warningFontSize = 50, -- Warning font size (default 50px)
        iconSize = 100, -- 100% 
        timerColor = { r = 0, g = 1, b = 0, a = 1 },      -- Green timer
        bashColor = { r = 1, g = 1, b = 1, a = 1 },       -- White bash
        cooldownColor = { r = 1, g = 0.2, b = 0.2, a = 1 }, -- Red cooldown
        positionX = 128,
        positionY = 128,
        colorForFirst10sCooldown = true,
        enableCanBash = false,
        textFont = "Univers67",
        textRight = false, -- Use horizontal layout (icon left, text right)
        gamepadMoveSpeed = 420, -- pixels per second while moving with left stick
        },
}

-- =============================================================================
-- == LOCALIZED ALIASES & RUNTIME REFERENCES ===================================
-- =============================================================================
local HWR = WarmasktrackerByJH or {}
local NAME = HWR.name
local EM = EVENT_MANAGER
local HWRSV -- SavedVariables reference

-- Constants
local HUNTSMAN_WARMASK_ITEM_ID = 223189
local HUNTSMAN_WARMASK_BUFF_ID = 252050
local REMINDER_COOLDOWN = 1000 -- 1 second in milliseconds

-- =============================================================================
-- == RUNTIME VARIABLE DECLARATIONS ============================================
-- =============================================================================
local lastReminderTime = 0
local cdTimer = 0
local remainingTime = 0
local isInCombat = false
local reminderControl = nil
local reminderControlWarning = nil
local hasWarmaskEquipped = false
local lastBashedTargetName = nil

-- Gamepad tracker movement
local isGamepadMoveModeActive = false
local moveModePreviousLockState = nil
local moveLastUpdateMs = 0

local warningIcon
local warningTimer
local warningText 
local targetNameLabel

-- Forward declaration because gamepad move mode calls this before its implementation.
local CheckConditions

-- =============================================================================
-- == DEBUG UTILITY FUNCTIONS ==================================================
-- =============================================================================
--[[
    Purpose: Conditional debug output based on settings
--]]
local function Debug(message)
    if HWRSV.debugMode then
        d("[" .. NAME .. "] " .. message)
    end
end

-- =============================================================================
-- == FONT HELPER FUNCTIONS ====================================================
-- =============================================================================
--[[
    Purpose: Returns formatted font string for timer text
--]]
local fontPaths = {
    ["Univers67"] = "EsoUI/Common/Fonts/univers67.otf",
    ["ProseAntiquePSMT"] = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
    ["esocartographer-bold"] = "EsoUI/Common/Fonts/esocartographer-bold.otf",
    ["fontin_sans_b"] = "EsoUI/Common/Fonts/fontin_sans_b.otf",
    ["fontin_sans_i"] = "EsoUI/Common/Fonts/fontin_sans_i.otf",
    ["fontin_sans_r"] = "EsoUI/Common/Fonts/fontin_sans_r.otf",
    ["arialn"] = "EsoUI/Common/Fonts/arialn.ttf",
    ["consola"] = "EsoUI/Common/Fonts/consola.ttf",
    ["fontin_sans_sc"] = "EsoUI/Common/Fonts/fontin_sans_sc.otf",
    ["Handwritten_Bold"] = "EsoUI/Common/Fonts/Handwritten_Bold.otf",
    ["trajanpro-regular"] = "EsoUI/Common/Fonts/trajanpro-regular.otf",
    ["univers55"] = "EsoUI/Common/Fonts/univers55.otf",
    ["univers57"] = "EsoUI/Common/Fonts/univers57.otf",
}

local function GetTimerFont()
    local fontSize = tonumber(HWRSV.timerFontSize) or 32
    local fontPath = fontPaths[HWRSV.textFont or "Univers67"]
    local outline = "soft-shadow-thin"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

local function GetTargetNameFont()
    local fontSize = tonumber(HWRSV.targetFontSize) or 15
    local fontPath = fontPaths[HWRSV.textFont or "Univers67"]
    local outline = "soft-shadow-thin"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

--[[
    Purpose: Returns formatted font string for warning text
--]]
local function GetWarningFont()
    local fontSize = tonumber(HWRSV.warningFontSize) or 50
    local fontPath = fontPaths[HWRSV.textFont or "Univers67"]
    local outline = "soft-shadow-thick"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

-- =============================================================================
-- == WARNING UI SUBSYSTEM =====================================================
-- =============================================================================
--[[
    Purpose: Creates the visual warning display
--]]

local function UpdateIconSize()
    if reminderControl and warningIcon then
        local iconSize = HWRSV.iconSize or 100
        local iconDimensions = (iconSize / 100) * 80
        
        reminderControl:SetDimensions(iconDimensions + 40, iconDimensions + 40)
        
        warningIcon:SetDimensions(iconDimensions, iconDimensions)
        
        warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
        warningTimer:ClearAnchors()
        if HWRSV.textRight then
                warningTimer:SetAnchor(LEFT, warningIcon, RIGHT, 10, 0)
            else 
                warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
            end
            
            Debug("Icon size updated to: " .. iconSize .. "% (" .. iconDimensions .. "px)")
        end
    end
HWR.UpdateIconSize = UpdateIconSize

local function CreateWarningUI()
    Debug("Creating warning UI...")
    
    local iconSize = HWRSV.iconSize or 100
    local iconDimensions = (iconSize / 100) * 80
    
    reminderControl = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Warning")
    reminderControl:SetDimensions(120, 120)
    reminderControl:SetDrawTier(DT_HIGH)
    reminderControl:SetClampedToScreen(true)
    reminderControl:SetMouseEnabled(true)
    reminderControl:SetMovable(true)
    reminderControl:SetHidden(false)
    
    reminderControl:ClearAnchors()
    reminderControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, HWRSV.positionX or 128, HWRSV.positionY or 128)

    reminderControlWarning = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "WarningMiddle")
    reminderControlWarning:SetDimensions(600, 80)
    reminderControlWarning:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reminderControlWarning:SetDrawTier(DT_HIGH)
    reminderControlWarning:SetHidden(true)

    -- Icon
    warningIcon = WINDOW_MANAGER:CreateControl("$(parent)Icon", reminderControl, CT_TEXTURE)
    warningIcon:SetAnchor(CENTER, reminderControl, CENTER, 0, 0)
    warningIcon:SetDimensions(iconDimensions, iconDimensions)
    --warningIcon:SetDimensions(80, 80)
    warningIcon:SetTexture("/esoui/art/icons/gear_hircinessnarlmask_head_a.dds")
    warningIcon:SetHidden(false)

    -- Timer text
    warningTimer = WINDOW_MANAGER:CreateControl("$(parent)Text", reminderControl, CT_LABEL)
    --warningTimer:SetFont("ZoFontWinH1")
    warningTimer:SetFont(GetTimerFont()) 
    warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
    --warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, 30)
    warningTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warningTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    warningTimer:SetColor(1, 1, 1, 1)
    warningTimer:SetText("")

    -- Warning text label
    warningText = WINDOW_MANAGER:CreateControl("$(parent)Text", reminderControlWarning, CT_LABEL)
    warningText:SetFont(GetWarningFont())
    --warningText:SetFont("ZoFontWinH1")
    warningText:SetColor(1, 0.2, 0.2, 1) -- Red color for urgency
    --warningText:SetText(">>> HUNTSMAN WARMASK MISSING! <<<")
    warningText:SetText("")
    warningText:SetDimensions(580, 60)
    warningText:SetAnchor(CENTER, reminderControlWarning, CENTER, 0, 0)
    warningText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warningText:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- Target name label
    targetNameLabel = WINDOW_MANAGER:CreateControl("$(parent)TargetName", reminderControl, CT_LABEL)
    targetNameLabel:SetFont(GetTargetNameFont())
    targetNameLabel:SetAnchor(TOP, warningTimer, BOTTOM, 0, 6)
    targetNameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    targetNameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    targetNameLabel:SetColor(1, 1, 1, 1)
    targetNameLabel:SetText("")
    targetNameLabel:SetHidden(true)

    HWR.UpdateIconSize()
    Debug("Warning UI created.")
end


-- =============================================================================
-- == GAMEPAD TRACKER MOVEMENT =================================================
-- =============================================================================
--[[
    Toggle with /hwrmove.
    While active, the left stick moves the tracker. The position is saved
    immediately into SavedVariables and restored on the next login.
--]]

local function SaveReminderPosition()
    if not reminderControl or not HWRSV then return end

    local left = reminderControl:GetLeft()
    local top = reminderControl:GetTop()
    if left and top then
        HWRSV.positionX = left
        HWRSV.positionY = top
    end
end

local function RequestSavedVariablesSave()
    -- SavedVariables are written by ESO itself. This only prioritizes this
    -- add-on for the next save cycle and never reloads the UI.
    local addonManager = GetAddOnManager and GetAddOnManager()
    if addonManager and addonManager.RequestAddOnSavedVariablesPrioritySave then
        addonManager:RequestAddOnSavedVariablesPrioritySave(NAME)
    end
end

local function SetReminderPosition(x, y)
    if not reminderControl then return end

    reminderControl:ClearAnchors()
    reminderControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)

    HWRSV.positionX = x
    HWRSV.positionY = y
end


local function ApplyTrackerPosition()
    if not reminderControl or not HWRSV then return end

    reminderControl:ClearAnchors()
    reminderControl:SetAnchor(
        TOPLEFT,
        GuiRoot,
        TOPLEFT,
        HWRSV.positionX or 128,
        HWRSV.positionY or 128
    )
end

local function UpdateGamepadMove()
    if not isGamepadMoveModeActive or not reminderControl or not HWRSV then
        return
    end

    local stickX = GetGamepadLeftStickX and GetGamepadLeftStickX(true) or 0
    local stickY = GetGamepadLeftStickY and GetGamepadLeftStickY(true) or 0

    if math.abs(stickX) < 0.18 then stickX = 0 end
    if math.abs(stickY) < 0.18 then stickY = 0 end
    if stickX == 0 and stickY == 0 then return end

    local now = GetGameTimeMilliseconds()
    local dt = 0.016
    if moveLastUpdateMs > 0 then
        dt = math.min((now - moveLastUpdateMs) / 1000, 0.05)
    end
    moveLastUpdateMs = now

    local speed = tonumber(HWRSV.gamepadMoveSpeed) or 420

    -- Same principle as Meterskull: only simple X/Y values are changed.
    HWRSV.positionX = (HWRSV.positionX or 128) + (stickX * speed * dt)
    HWRSV.positionY = (HWRSV.positionY or 128) - (stickY * speed * dt)

    ApplyTrackerPosition()
end

local function StartGamepadMoveMode()
    if isGamepadMoveModeActive or not reminderControl then return end

    isGamepadMoveModeActive = true
    moveModePreviousLockState = HWRSV.LockPosition
    HWRSV.LockPosition = false
    moveLastUpdateMs = 0

    reminderControl:SetHidden(false)
    if warningIcon then warningIcon:SetHidden(false) end
    if warningTimer then
        warningTimer:SetText("MOVE")
        warningTimer:SetColor(1, 1, 1, 1)
    end

    EM:RegisterForUpdate(NAME .. "GamepadMove", 16, UpdateGamepadMove)
    d("|cFFFFFF|cFF0000Warmasktracker by JH|r Move mode: |c00FF00ON|r - move with left stick")
end

local function StopGamepadMoveMode()
    if not isGamepadMoveModeActive then return end

    EM:UnregisterForUpdate(NAME .. "GamepadMove")
    isGamepadMoveModeActive = false
    moveLastUpdateMs = 0

    SaveReminderPosition()
    RequestSavedVariablesSave()

    if moveModePreviousLockState ~= nil then
        HWRSV.LockPosition = moveModePreviousLockState
    end
    moveModePreviousLockState = nil

    d("|cFFFFFF|cFF0000Warmasktracker by JH|r Move mode: |cFFAA00OFF|r - position saved")
    CheckConditions()
end

local function ToggleGamepadMoveMode()
    if isGamepadMoveModeActive then
        StopGamepadMoveMode()
    else
        StartGamepadMoveMode()
    end
end



-- =============================================================================
-- == UpdateTargetName =========================================================
-- =============================================================================
--[[
    Purpose: Sets the target name below the icon to true or false
--]]
local function UpdateTargetName()
    if not targetNameLabel then return end

    if HWRSV.showTargetName and isInCombat then
        targetNameLabel:SetText(lastBashedTargetName)
        targetNameLabel:SetHidden(false)
    else
        lastBashedTargetName = ""
        targetNameLabel:SetHidden(true)
    end
end

local function UpdateTargetNameVisibility()
    UpdateTargetName()
end

HWR.UpdateTargetNameVisibility = UpdateTargetNameVisibility



-- =============================================================================
-- == FONT SIZE UPDATE FUNCTION ================================================
-- =============================================================================
--[[
    Purpose: Updates font sizes for timer and warning text
--]]
local function UpdateFontSizes()
    if warningTimer then
        warningTimer:SetFont(GetTimerFont())
        warningTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        warningTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    
    if warningText then
        warningText:SetFont(GetWarningFont())
        warningText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        warningText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end

    if targetNameLabel then
        targetNameLabel:SetFont(GetTargetNameFont())
        targetNameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        targetNameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    Debug("Font sizes updated. Timer: " .. (HWRSV.timerFontSize or 32) .. "px, Warning: " .. (HWRSV.warningFontSize or 50) .. "px")
end

HWR.UpdateFontSizes = UpdateFontSizes

-- =============================================================================
-- == WARNING VISIBILITY CONTROL ===============================================
-- =============================================================================
--[[
    Purpose: Displays the warning UI
--]]
local function ShowWarning()
    if reminderControl then
        Debug("Showing warning.")
        reminderControlWarning:SetHidden(false)
        reminderControlWarning:SetAlpha(1)
    else
        Debug("ERROR: reminderControl is nil!")
    end
end

--[[
    Purpose: Hides the warning UI
--]]
local function HideWarning()
    if reminderControlWarning then
        Debug("Hiding warning.")
        reminderControlWarning:SetHidden(true)
    end
end

local function HideIconAndTimer()
    if reminderControl and warningTimer then
        reminderControl:SetHidden(true)
        warningTimer:SetText("")
        remainingTime = 0
        cdTimer = 0
    end
end
-- =============================================================================
-- == EQUIPMENT CHECK SUBSYSTEM ================================================
-- =============================================================================
--[[
    Purpose: Checks if Huntsman Warmask is currently equipped
--]]
local function CheckWarmaskEquipped()
    local currentHelmId = GetItemId(BAG_WORN, EQUIP_SLOT_HEAD)
    hasWarmaskEquipped = (currentHelmId == HUNTSMAN_WARMASK_ITEM_ID)
    Debug("Warmask equipped: " .. tostring(hasWarmaskEquipped))
    return hasWarmaskEquipped
end

-- =============================================================================
-- == BUFF DETECTION SUBSYSTEM =================================================
-- =============================================================================
--[[
    Purpose: Checks if Huntsman Warmask buff is active
--]]
local function HasBuff()
    for i = 1, GetNumBuffs("player") do
        local buffName, _, timeEnding, _, _, _, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
        if abilityId == HUNTSMAN_WARMASK_BUFF_ID then
            Debug("Buff found: " .. (buffName or "Unknown") .. " (ID: " .. abilityId .. ")")
            return true, timeEnding - GetFrameTimeSeconds()
        end
    end
    return false
end

-- =============================================================================
-- == CORE LOGIC: CONDITION CHECKING ===========================================
-- =============================================================================
--[[
    Purpose: Evaluates all conditions for showing reminder
--]]
CheckConditions = function()
    if isGamepadMoveModeActive then
        return true
    end

    Debug("Checking conditions...")
    -- d(tostring(HWRSV.positionX))
    -- d(tostring(HWRSV.positionY))
    -- Check if addon is enabled
    if not HWRSV.enabled then
        HideWarning()
        HideIconAndTimer()
        return false
    end
    
    -- Check helmet equipment. Console option can make this gate mandatory.
    local warmaskEquipped = CheckWarmaskEquipped()
    if HWRSV.onlyWhenEquipped and not warmaskEquipped then
        Debug("Huntsman Warmask not equipped - tracker hidden")
        HideWarning()
        HideIconAndTimer()
        return false
    end
    
    -- Check combat state
    Debug("In combat: " .. tostring(isInCombat))
    local inMouseMode = IsGameCameraUIModeActive()
    if (HWRSV.LockPosition and inMouseMode) or not isInCombat and not HWRSV.showOutsideCombat then
        lastBashedTargetName = ""
        HideWarning()
        HideIconAndTimer()
        return false
    end
    
    -- Check buff status
    local hasBuff,remaining = HasBuff()
    Debug("Buff active: " .. tostring(hasBuff))

    if HWRSV.toggleWarning then
        reminderControl:SetHidden(true)
        if hasBuff then
            HideWarning()
            return false
        else
            reminderControl:SetHidden(true)
        end
    else
        if hasBuff then
            remainingTime = remaining
            reminderControl:SetHidden(false)

            if HWRSV.toggleTimer then
                --warningTimer:SetColor(0, 1, 0, 1) 
                if HWRSV.colorForFirst10sCooldown  and remainingTime >50 then
                    warningTimer:SetColor(
                        HWRSV.cooldownColor.r,
                        HWRSV.cooldownColor.g,
                        HWRSV.cooldownColor.b,
                        HWRSV.cooldownColor.a
                    )
                else
                    warningTimer:SetColor(
                    HWRSV.timerColor.r,
                    HWRSV.timerColor.g,
                    HWRSV.timerColor.b,
                    HWRSV.timerColor.a
                    )
                end    
                warningTimer:SetText(string.format("%d", remaining))
            else
                warningTimer:SetText("")
                remainingTime = 0
                cdTimer = 0
            end
        elseif (isInCombat or HWRSV.showOutsideCombat) and remainingTime <=49 then
            remainingTime = 0
            cdTimer = 0
            reminderControl:SetHidden(false)
            -- warningTimer:SetColor(1, 1, 1, 1) 
            warningTimer:SetColor(
                HWRSV.bashColor.r,
                HWRSV.bashColor.g,
                HWRSV.bashColor.b,
                HWRSV.bashColor.a
            )
            warningTimer:SetText("")
            
        elseif remainingTime > 50 and cdTimer <=10 then
            lastBashedTargetName = ""
            cdTimer = 10-(60-remainingTime)
            remainingTime = remainingTime-0.2
            reminderControl:SetHidden(false)
            --warningTimer:SetColor(1, 0.2, 0.2, 1) 
            warningTimer:SetColor(
                HWRSV.cooldownColor.r,
                HWRSV.cooldownColor.g,
                HWRSV.cooldownColor.b,
                HWRSV.cooldownColor.a
            )
            warningTimer:SetText(string.format("%d", cdTimer-0.2))
        else
            remainingTime = 0
            cdTimer = 0
            reminderControl:SetHidden(true)
        end
    end
    
    -- Check cooldown
    local currentTime = GetGameTimeMilliseconds()
    local timeSinceLastReminder = currentTime - lastReminderTime
    Debug("Time since last warning: " .. timeSinceLastReminder .. "ms")
    
    if timeSinceLastReminder < REMINDER_COOLDOWN then
        Debug("Cooldown active - no warning")
        return false
    end
    
    -- All conditions met - show warning
    Debug("All conditions met - showing warning")
    lastReminderTime = currentTime
    if HWRSV.toggleWarning then
        ShowWarning()
    end
    return true
end

-- =============================================================================
-- == CONTINUOUS MONITORING SUBSYSTEM ==========================================
-- =============================================================================
--[[
    Purpose: Periodically checks conditions to ensure state consistency
--]]
local function ContinuousUpdate()
    if isGamepadMoveModeActive then
        return
    end

    if HWRSV.showOutsideCombat or (HWRSV.enabled and isInCombat and hasWarmaskEquipped) then
        CheckConditions()
        if reminderControl and not reminderControl:IsHidden() then
            UpdateTargetName()
        end
    end
end

-- =============================================================================
-- == EVENT HANDLER SUBSYSTEM ==================================================
-- =============================================================================
--[[
    Purpose: Handles combat state changes
--]]
local function OnCombatState(eventCode, inCombat)
    isInCombat = inCombat
    Debug("Combat status: " .. (inCombat and "In combat" or "Not in combat"))
    local inMouseMode = IsGameCameraUIModeActive()
    if (HWRSV.LockPosition and inMouseMode) or not inCombat and not HWRSV.showOutsideCombat then
        lastBashedTargetName = ""
        HideWarning()
        HideIconAndTimer()
    else
        CheckConditions()
    end
end

--[[
    Purpose: Handles equipment changes
--]]
local function OnEquipmentChanged(_, _, slotId, _, _, _, _)
    if slotId == EQUIP_SLOT_HEAD then
        local itemId = GetItemId(BAG_WORN, EQUIP_SLOT_HEAD)
        if itemId and itemId ~= 0 then
            local itemName = GetItemName(BAG_WORN, EQUIP_SLOT_HEAD)
            Debug("Helmet changed: " .. itemName .. " (ID: " .. itemId .. ")")
            CheckWarmaskEquipped()
            CheckConditions()
        else
            Debug("No helmet equipped!")
            hasWarmaskEquipped = false
            HideWarning()
            HideIconAndTimer()
        end
    end
end

--[[
    Purpose: Handles buff/debuff changes
--]]
local function OnEffectChanged(_, changeType, _, effectName, unitTag, _, _, _, _, _, _, _, _, _, abilityId, _)
    if unitTag == "player" then
        Debug("Effect event: " .. (effectName or "Unknown") .. " (ID: " .. (abilityId or "nil") .. ") Change: " .. changeType)
        if abilityId == HUNTSMAN_WARMASK_BUFF_ID then
            if changeType == EFFECT_RESULT_GAINED then
                Debug("Huntsman Warmask buff activated - hiding warning.")
                HideWarning()
            elseif changeType == EFFECT_RESULT_FADED then
                Debug("Huntsman Warmask buff faded - checking conditions.")
                zo_callLater(CheckConditions, 100)
            end
        end
    end
end

local function OnBashEvent(_, result, _, abilityName, _, _, _, sourceType, targetName, _, _, _, _, _, _, _, abilityId)
    if remainingTime > 51 then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if abilityId == 0 or abilityId == nil then return end
    local formattedTarget = GetUnitName('reticleover') or ((targetName ~= "" and zo_strformat("<<1>>", targetName))) and not (GetUnitName('player'))
    -- d(GetUnitName('reticleover'))
    -- d(((targetName ~= "" and zo_strformat("<<1>>", targetName))))
    local formattedAbility = abilityName ~= "" and zo_strformat("<<1>>", abilityName) or ""
    lastBashedTargetName = formattedTarget
    Debug(string.format(
        "|cAAAAFF[HWR COMBAT]|r result=%d | abilityId=%d | ability=%s | target=%s",
        result,
        abilityId,
        formattedAbility,
        formattedTarget
    ))
end



-- =============================================================================
-- == SLASH COMMAND IMPLEMENTATION =============================================
-- =============================================================================
--[[
    Purpose: Provides user interaction via chat commands
--]]
SLASH_COMMANDS["/huntsmanwarmaskreminder"] = function()
    HWRSV.enabled = not HWRSV.enabled
    d("Huntsman Warmask Reminder: " .. (HWRSV.enabled and "|c00FF00enabled|r" or "|cFF0000disabled|r"))
    
    if not HWRSV.enabled then
        HideWarning()
        HideIconAndTimer()
    else
        CheckConditions()
    end
end

-- =======================================================================
-- == Slash Commands =====================================================
-- =======================================================================
local function ResetTimerColor()
    HWRSV.timerColor = {r=0, g=1, b=0, a=1}
    d("|cFFFFFF |cFF0000HWR|r Timer Color:|r |c00FF00RESET to green|r")
    if HWRSV.enabled then
        CheckConditions()
    end
end

local function ResetBashColor()
    HWRSV.bashColor = {r=1, g=1, b=1, a=1}
    d("|cFFFFFF |cFF0000HWR|r Bash Color:|r |cFFFFFFRESET to white|r")
    if HWRSV.enabled then
        CheckConditions()
    end
end

local function ResetCooldownColor()
    HWRSV.cooldownColor = {r=1, g=0.2, b=0.2, a=1}
    d("|cFFFFFF |cFF0000HWR|r Cooldown Color:|r |cFF5555RESET to red|r")
    if HWRSV.enabled then
        CheckConditions()
    end
end

local function ToggleAddon()
    HWRSV.enabled = not HWRSV.enabled
    d("|cFFFFFF |cFF0000HWR|r:|r " .. (HWRSV.enabled and "|c00FF00enabled|r" or "|cFF0000disabled|r"))
end

local function ToggleShowOutside()
    HWRSV.showOutsideCombat = not HWRSV.showOutsideCombat
    d("|cFFFFFF|cFF0000HWR|r Show Outside Combat:|r " ..
        (HWRSV.showOutsideCombat and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end

local function ToggleShowTimer()
    HWRSV.toggleTimer = not HWRSV.toggleTimer
    d("|cFFFFFF|cFF0000HWR|r Toggle Timer on Icon:|r " ..
        (HWRSV.toggleTimer and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end

local function ToggleWarning()
    HWRSV.toggleWarning = not HWRSV.toggleWarning
    d("|cFFFFFF|cFF0000HWR|r Toggle Warning in the middle on the screen:|r " ..
        (HWRSV.toggleWarning and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end
SLASH_COMMANDS["/hwr"] = ToggleAddon
SLASH_COMMANDS["/hwrshow"] = ToggleShowOutside
SLASH_COMMANDS["/hwrstoggletimer"] = ToggleShowTimer
SLASH_COMMANDS["/hwrstogglewarning"] = ToggleWarning
SLASH_COMMANDS["/hwrresettimercolor"] = ResetTimerColor
SLASH_COMMANDS["/hwrresetbashcolor"] = ResetBashColor
SLASH_COMMANDS["/hwrresetcooldowncolor"] = ResetCooldownColor
SLASH_COMMANDS["/hwrmove"] = ToggleGamepadMoveMode


-- =============================================================================
-- == OPTIONAL LIBADDONMENU SETTINGS ============================================
-- =============================================================================
local function BuildOptionalLAMMenu()
    local LAM = LibAddonMenu2
    if not LAM or not HWRSV then
        return
    end

    local options = {
        {
            type = "checkbox",
            name = "Enable tracker",
            getFunc = function() return HWRSV.enabled end,
            setFunc = function(value)
                HWRSV.enabled = value
                if value then CheckConditions() else HideWarning(); HideIconAndTimer() end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Only show when Warmask is equipped",
            tooltip = "When enabled, icon, timer and warning are hidden unless Huntsman Warmask is equipped.",
            getFunc = function() return HWRSV.onlyWhenEquipped ~= false end,
            setFunc = function(value)
                HWRSV.onlyWhenEquipped = value
                CheckWarmaskEquipped()
                CheckConditions()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show icon outside combat",
            getFunc = function() return HWRSV.showOutsideCombat end,
            setFunc = function(value) HWRSV.showOutsideCombat = value; CheckConditions() end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show timer",
            getFunc = function() return HWRSV.toggleTimer end,
            setFunc = function(value) HWRSV.toggleTimer = value; CheckConditions() end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show warning text instead of icon",
            getFunc = function() return HWRSV.toggleWarning end,
            setFunc = function(value) HWRSV.toggleWarning = value; CheckConditions() end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show target name",
            getFunc = function() return HWRSV.showTargetName end,
            setFunc = function(value)
                HWRSV.showTargetName = value
                UpdateTargetNameVisibility()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Icon size",
            min = 50,
            max = 200,
            step = 5,
            getFunc = function() return HWRSV.iconSize or 100 end,
            setFunc = function(value) HWRSV.iconSize = value; UpdateIconSize() end,
            width = "full",
        },
        {
            type = "slider",
            name = "Gamepad move speed",
            min = 100,
            max = 1000,
            step = 25,
            getFunc = function() return HWRSV.gamepadMoveSpeed or 420 end,
            setFunc = function(value) HWRSV.gamepadMoveSpeed = value end,
            width = "full",
        },
        {
            type = "button",
            name = "Toggle move mode",
            func = function() ToggleGamepadMoveMode() end,
            width = "full",
        },
    }
    if TrackersByJH_RegisterMenu then TrackersByJH_RegisterMenu("Warmask Tracker", options) end
end

local function sceneChange(_, scene) -- Thank you Duesentrieb <3
    if reminderControl then
        reminderControl:SetHidden(true)
    end
end
-- =============================================================================
-- == ADDON INITIALIZATION =====================================================
-- =============================================================================
--[[
    Purpose: Performs addon initialization routines
--]]
local function Initialize()
    -- SavedVariables initialization
    HWRSV = ZO_SavedVars:NewAccountWide("WarmasktrackerByJHData", 1, nil, HWR.settings, GetWorldName())
    --HWR.setting = HWRSV
    
    -- Create warning UI
    CreateWarningUI()
    SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", ContinuousUpdate)
    SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", sceneChange)
    EM:RegisterForEvent(NAME, EVENT_COMBAT_EVENT, OnBashEvent)
    EM:AddFilterForEvent(NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 21970)

    -- Register event handlers with appropriate filters
    EM:RegisterForEvent(NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    
    EM:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    
    EM:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEquipmentChanged)
    EM:AddFilterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_BAG_ID, BAG_WORN)
    
    -- Set up continuous monitoring for state consistency
    EM:RegisterForUpdate(NAME .. "ContinuousUpdate", 250, ContinuousUpdate)
    
    -- Initial condition check
    CheckWarmaskEquipped()
    CheckConditions()

    BuildOptionalLAMMenu()
    
    Debug("Addon initialized.")
end

-- =============================================================================
-- == EVENT HANDLER: ADDON LOADED ==============================================
-- =============================================================================
--[[
    Purpose: Handles the EVENT_ADD_ON_LOADED event to initialize the addon
--]]
local function OnAddOnLoaded(event, addonName)
    if addonName == NAME or addonName == "TrackersByJH" then
        EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end



-- =============================================================================
-- == EVENT REGISTRATION =======================================================
-- =============================================================================
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
-- SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", ContinuousUpdate) 
-- SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", sceneChange)-- Thank you Duesentrieb <3