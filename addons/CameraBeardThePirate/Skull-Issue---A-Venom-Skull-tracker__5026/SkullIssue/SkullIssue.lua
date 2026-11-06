-------------------------------------------------------------------------------
-- Skull Issue - Elder Scrolls Online Addon
-- Author: CameraBeardThePirate
-- Ability Tracked: Venom Skull Passive (AbilityId: 117625)
-------------------------------------------------------------------------------

SkullIssue = SkullIssue or {}
local SkullIssue = SkullIssue

SkullIssue.name = "SkullIssue"
SkullIssue.version = "1.0.0"
SkullIssue.abilityId = 117625
SkullIssue.currentStacks = 0
SkullIssue.isUnlocked = false

-- Default account-wide settings
local defaults = {
    offsetX = 0,
    offsetY = 150,
    scale = 1.00,
    locked = true,
    showNumber = false,
    soundOnReady = true,
    showText = true,
}

-------------------------------------------------------------------------------
-- Stack Visual Updates
-------------------------------------------------------------------------------
function SkullIssue.UpdateDisplay(stacks)
    SkullIssue.currentStacks = stacks or 0

    local frame = SkullIssueFrame
    local flame = SkullIssueFrameFlame
    local skull = SkullIssueFrameSkull
    local text  = SkullIssueFrameStackCount
    local empText = SkullIssueFrameEmpoweredText

    if not frame or not flame or not skull then return end

    -- When unlocked for repositioning, keep elements visible so the user can see them
    if SkullIssue.isUnlocked then
        frame:SetHidden(false)
        skull:SetHidden(false)
        flame:SetHidden(false)
        if empText then
            empText:SetHidden(not SkullIssue.savedVars.showText)
            empText:SetText("Spooky")
        end
        if text then
            text:SetHidden(not SkullIssue.savedVars.showNumber)
            text:SetText(tostring(SkullIssue.currentStacks > 0 and SkullIssue.currentStacks or "1"))
        end
        return
    end

    if SkullIssue.currentStacks <= 0 then
        -- 0 Stacks: Hide counter completely
        flame:SetHidden(true)
        skull:SetHidden(true)
        if text then text:SetHidden(true) end
        if empText then empText:SetHidden(true) end
    elseif SkullIssue.currentStacks == 1 then
        -- 1 Stack: Display Skull Image (96x96), Green Flame hidden, text hidden
        flame:SetHidden(true)
        skull:SetHidden(false)
        if empText then empText:SetHidden(true) end
        if text then
            text:SetHidden(not SkullIssue.savedVars.showNumber)
            text:SetText("1")
        end
    elseif SkullIssue.currentStacks >= 2 then
        -- 2 or 3 Stacks: EXACTLY IDENTICAL DISPLAY
        -- Both 2 and 3 stacks display the Skull face with the Green Flame behind it,
        -- and display "Spooky" (if enabled via /skullissue text).
        flame:SetHidden(false)
        skull:SetHidden(false)
        if empText then
            empText:SetHidden(not SkullIssue.savedVars.showText)
            empText:SetText("Spooky")
        end
        if text then
            text:SetHidden(not SkullIssue.savedVars.showNumber)
            text:SetText(tostring(SkullIssue.currentStacks))
        end

        -- Play sound cue if enabled
        if SkullIssue.savedVars.soundOnReady and PlaySound then
            PlaySound(SOUNDS.ABILITY_ULTIMATE_READY)
        end
    end
end

-------------------------------------------------------------------------------
-- Buff & Effect Scanning
-------------------------------------------------------------------------------
local function CheckPlayerBuffs()
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)
        if abilityId == SkullIssue.abilityId then
            local stacks = (stackCount and stackCount > 0) and stackCount or 1
            SkullIssue.UpdateDisplay(stacks)
            return
        end
    end
    SkullIssue.UpdateDisplay(0)
end

local function OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    if abilityId == SkullIssue.abilityId then
        if changeType == EFFECT_RESULT_FADED then
            SkullIssue.UpdateDisplay(0)
        else
            local stacks = (stackCount and stackCount > 0) and stackCount or 1
            SkullIssue.UpdateDisplay(stacks)
        end
    end
end

-------------------------------------------------------------------------------
-- Frame Positioning & Lock/Unlock
-------------------------------------------------------------------------------
function SkullIssue.SetLocked(locked)
    SkullIssue.isUnlocked = not locked
    SkullIssue.savedVars.locked = locked

    local frame = SkullIssueFrame
    local mover = SkullIssueFrameMoverBackdrop
    if not frame then return end

    frame:SetMovable(not locked)
    if mover then mover:SetHidden(locked) end

    if not locked then
        d("|c00FF66Skull Issue:|r Frame unlocked. Drag the box to reposition, then type |cFFFFFF/skullissue lock|r.")
    else
        d("|c00FF66Skull Issue:|r Frame locked at current position.")
    end

    SkullIssue.UpdateDisplay(SkullIssue.currentStacks)
end

function SkullIssue.OnMoveStop()
    local frame = SkullIssueFrame
    if not frame then return end

    local centerX, centerY = frame:GetCenter()
    local rootX, rootY = GuiRoot:GetCenter()

    if centerX and centerY and rootX and rootY then
        SkullIssue.savedVars.offsetX = centerX - rootX
        SkullIssue.savedVars.offsetY = centerY - rootY
    end
end

function SkullIssue.RestorePosition()
    local frame = SkullIssueFrame
    if not frame then return end

    frame:ClearAnchors()
    frame:SetAnchor(CENTER, GuiRoot, CENTER, SkullIssue.savedVars.offsetX, SkullIssue.savedVars.offsetY)
    frame:SetScale(SkullIssue.savedVars.scale or 1.0)
    SkullIssue.SetLocked(SkullIssue.savedVars.locked)
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
local function SlashCommandHandler(str)
    local args = {}
    for word in string.gmatch(string.lower(str), "%S+") do
        table.insert(args, word)
    end

    local command = args[1]

    if command == "unlock" then
        SkullIssue.SetLocked(false)
    elseif command == "lock" then
        SkullIssue.SetLocked(true)
    elseif command == "test" then
        local stack = tonumber(args[2]) or 1
        d("|c00FF66Skull Issue:|r Testing " .. stack .. " stacks preview.")
        SkullIssue.UpdateDisplay(stack)
    elseif command == "scale" then
        local newScale = tonumber(args[2])
        if newScale and newScale >= 0.5 and newScale <= 2.5 then
            SkullIssue.savedVars.scale = newScale
            SkullIssueFrame:SetScale(newScale)
            d("|c00FF66Skull Issue:|r Frame scale set to " .. string.format("%.2f", newScale))
        else
            d("|c00FF66Skull Issue:|r Usage: /skullissue scale [0.5 - 2.5]")
        end
    elseif command == "number" then
        SkullIssue.savedVars.showNumber = not SkullIssue.savedVars.showNumber
        d("|c00FF66Skull Issue:|r Stack number display: " .. (SkullIssue.savedVars.showNumber and "|c00FF00ON|r" or "|cFF0000OFF|r"))
        SkullIssue.UpdateDisplay(SkullIssue.currentStacks)
    elseif command == "text" or command == "spooky" then
        SkullIssue.savedVars.showText = not SkullIssue.savedVars.showText
        d("|c00FF66Skull Issue:|r 'Spooky' text display: " .. (SkullIssue.savedVars.showText and "|c00FF00ON|r" or "|cFF0000OFF|r"))
        SkullIssue.UpdateDisplay(SkullIssue.currentStacks)
    elseif command == "sound" then
        SkullIssue.savedVars.soundOnReady = not SkullIssue.savedVars.soundOnReady
        d("|c00FF66Skull Issue:|r Sound alert on 3 stacks: " .. (SkullIssue.savedVars.soundOnReady and "|c00FF00ON|r" or "|cFF0000OFF|r"))
    elseif command == "reset" then
        SkullIssue.savedVars.offsetX = defaults.offsetX
        SkullIssue.savedVars.offsetY = defaults.offsetY
        SkullIssue.savedVars.scale = defaults.scale
        SkullIssue.RestorePosition()
        d("|c00FF66Skull Issue:|r Position and scale reset to default.")
    else
        d("|c00FF66Skull Issue Commands:|r")
        d("  |cFFFF00/skullissue unlock|r - Unlock and drag frame")
        d("  |cFFFF00/skullissue lock|r - Lock frame in place")
        d("  |cFFFF00/skullissue test [0-3]|r - Preview stack visual")
        d("  |cFFFF00/skullissue scale [0.5-2.5]|r - Change size")
        d("  |cFFFF00/skullissue number|r - Toggle numeric stack counter")
        d("  |cFFFF00/skullissue text|r - Toggle 'Spooky' text on/off")
        d("  |cFFFF00/skullissue sound|r - Toggle sound alert on 3 stacks")
        d("  |cFFFF00/skullissue reset|r - Reset position to center")
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= SkullIssue.name then return end
    EVENT_MANAGER:UnregisterForEvent(SkullIssue.name, EVENT_ADD_ON_LOADED)

    -- Initialize Saved Variables (Account-Wide)
    SkullIssue.savedVars = ZO_SavedVars:NewAccountWide("SkullIssue_SavedVariables", 1, nil, defaults)

    -- Hook move handler
    SkullIssueFrame:SetHandler("OnMoveStop", SkullIssue.OnMoveStop)

    -- Restore saved frame anchor and scale
    SkullIssue.RestorePosition()

    -- Register with ESO Scene Manager so the frame automatically hides when
    -- full-screen UI menus such as the World Map, Inventory, Character sheet,
    -- Skills, Bank, or Crafting stations are open.
    if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
        local sceneFragment = ZO_HUDFadeSceneFragment:New(SkullIssueFrame)
        HUD_SCENE:AddFragment(sceneFragment)
        HUD_UI_SCENE:AddFragment(sceneFragment)
    end

    -- Register Slash Commands
    SLASH_COMMANDS["/skullissue"] = SlashCommandHandler
    SLASH_COMMANDS["/si"] = SlashCommandHandler

    -- Register Combat Buff / Effect Tracking Event
    EVENT_MANAGER:RegisterForEvent(SkullIssue.name, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(SkullIssue.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_TARGET_ATTRIBUTE_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    -- Check player buffs on zone in / load
    EVENT_MANAGER:RegisterForEvent(SkullIssue.name, EVENT_PLAYER_ACTIVATED, function()
        CheckPlayerBuffs()
    end)

    d("|c00FF66Skull Issue v" .. SkullIssue.version .. " Loaded.|r Type |cFFFFFF/skullissue|r for options.")
end

EVENT_MANAGER:RegisterForEvent(SkullIssue.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
