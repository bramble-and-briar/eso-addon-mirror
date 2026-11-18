-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: CMSettings.lua. See third-party/UPSTREAM.md for modifications.

local LAM = WeavePulse.Settings
local Util = WeavePulse.Util
Util.Text = Util.Text or {}
WeavePulse.LATracker = WeavePulse.LATracker or {}
local LATracker = WeavePulse.LATracker
WeavePulse.StackTracker = WeavePulse.StackTracker or {}
local StackTracker = WeavePulse.StackTracker
WeavePulse.SV = WeavePulse.SV or {}

local ABILITY_ADJUST_PLACEHOLDER = "Add ability adjust"
local MAX_ADJUST = 200

local MIN_WIDTH = 50
local MAX_WIDTH = math.floor(GuiRoot:GetWidth())
local MIN_HEIGHT = 10
local MAX_HEIGHT = 100
local MAX_ABILITY_DURATION = 5.6

local difficulty = {
    "|c00ff80EASY|r",
    "NORMAL",
    "|cec8b27HARD|r",
    "|cff3131DEADLY|r",
}

local sounds = {
    "Justice_PickpocketFailed",
    "Dialog_Decline",
    "Ability_Ultimate_Ready_Sound",
    "Quest_Shared",
    "Champion_PointsCommitted",
    "GroupElection_Requested",
    "Duel_Boundary_Warning",
}

local fullStackSounds = {
    "ABILITY_COMPANION_ULTIMATE_READY",
    "ABILITY_WEAPON_SWAP_FAIL",
    "ANTIQUITIES_DIGGING_DIG_POWER_REFUND",
    "BATTLEGROUND_CAPTURE_AREA_CAPTURED_OTHER_TEAM",
    "BATTLEGROUND_COUNTDOWN_FINISH",
}

local labelFonts = {
    "MEDIUM_FONT",
    "BOLD_FONT",
    "CHAT_FONT",
    "GAMEPAD_LIGHT_FONT" ,
    "GAMEPAD_MEDIUM_FONT",
    "GAMEPAD_BOLD_FONT",
    "ANTIQUE_FONT",
    "HANDWRITTEN_FONT",
    "STONE_TABLET_FONT",
}

local fontStyles = {
    "soft-shadow-thin",
    "soft-shadow-thick",
    "outline",
}

local LATrackerChoices = {
    "la/s",
    "Time between light attacks",
    "Nothing",
}

local SlidersToUpdate = {
    ["X Offset"] = "maxXOffset",
    ["Y Offset"] = "maxYOffset",
    ["Dynamic expansion multiplyer"] = "maxMultiplyer",
}

local function GetProgressbarMaxSliderValues()
    local remainingSpace
    local maxWidth = GuiRoot:GetWidth()
    local maxHeight = GuiRoot:GetHeight()
    if WeavePulse.SV.Progressbar.barAlign == "Left" then
        remainingSpace = maxWidth - WeavePulse.SV.Progressbar.xOffset
    elseif WeavePulse.SV.Progressbar.barAlign == "Center" then
        remainingSpace = (maxWidth-3*WeavePulse.SV.Progressbar.height)
    else
        remainingSpace = WeavePulse.SV.Progressbar.xOffset
    end
    WeavePulse.Progressbar.maxMultiplyer = math.floor(10*remainingSpace/(MAX_ABILITY_DURATION*WeavePulse.SV.Progressbar.width))
    WeavePulse.Progressbar.maxXOffset = math.floor(maxWidth - WeavePulse.SV.Progressbar.width)
    WeavePulse.Progressbar.maxYOffset = math.floor(maxHeight - WeavePulse.SV.Progressbar.height)
end

local function UpdateProgressbarSizeSliders()
    if not WeavePulse.Settings.panels.Progressbar then return end
    GetProgressbarMaxSliderValues()
    local slidersUpdated = 0
    local slidersToUpdate = NonContiguousCount(SlidersToUpdate)
    for i, entry in ipairs(WeavePulse.Settings.panels.Progressbar.controlsToRefresh) do
        if SlidersToUpdate[entry.data.name] then



            entry.data.max = WeavePulse.Progressbar[SlidersToUpdate[entry.data.name]]
            slidersUpdated = slidersUpdated + 1
            if slidersUpdated == slidersToUpdate then break end
        end
    end
end

local function UpdateDebugListChoices()
    WeavePulse.menu.panels.General:RefreshPanel()
    if WeavePulse.menu.panels and WeavePulse.menu.panels.General then
        local panelControls = WeavePulse.menu.panels.General.controlsToRefresh
        for i = 1, #panelControls do
            local control = panelControls[i]
            if (control.data and control.data.name == "Delete from ability whitelist") then

                control:UpdateChoices()
                control:UpdateValue()
                break
            end
        end
    end
end

local function IconDesaturation(icon, value)
    if not icon then return end
    if value then
        icon:SetDesaturation(0)
    else
        icon:SetDesaturation(1)
    end
end

local function DeleteShortNamesFromCache()
    for _, entry in pairs(Util.Ability.cache) do
        if entry.displayName then
            entry.displayName = nil
        end
    end
end

local function FindMenuPosition(searchTable, name)
    for i, entry in ipairs(searchTable) do
        if entry.name == name then
            return i
        end
    end
    if WeavePulse.SV.debug.enabled then WeavePulse.debug:Print(zo_strformat("Couldn't find '<<1>>' in requested searchTable, menu could not be created", name)) end
    return false
end

function WeavePulse:BuildMenu()
    GetProgressbarMaxSliderValues()
    self.menu = self.menu or { }
    self.menu.icons = {
        ["progressbar"] = {},

    }
    local LATrackerSettings = LATracker:BuildUI()
    local function CreateStacksSettings()
        local position = FindMenuPosition(self.menu.options.StackTracker, "Stacks to track")

        local sortedControls = {}
        for skill, entry in pairs(self.menu.CONTROLS.stackTracker) do
            table.insert(sortedControls, skill)
        end
        table.sort(sortedControls)

        for i = 1, #sortedControls do
            local skill = sortedControls[i]
            local entry = self.menu.CONTROLS.stackTracker[skill]
            local sv = WeavePulse.SV.StackTracker[skill]
            local submenu = {
                {
                    type = "submenu",
                    name = "|t20:20:"..entry.icon.."|t "..entry.subName,
                    disabled = function() return not StackTracker.availableSkills[skill] end,
                    controls = {
                        {
                            type = "checkbox",
                            name = entry.Name,
                            disabled = function()
                                return not StackTracker.availableSkills[skill]
                            end,
                            getFunc = function() return sv.tracked end,
                            setFunc = function(value)
                                sv.tracked = value

                                if value then
                                    StackTracker:Register(skill)
                                else
                                    StackTracker:Unregister(skill)
                                end
                            end,
                        },
                        {
                            type = "checkbox",
                            name = "Hide in PVP Zones",
                            tooltip = "Hides stack tracker in PVPZones to keep UI clean",
                            disabled = function () return not StackTracker:TrackerIsActive() end,
                            getFunc = function() return sv.hideInPVP end,
                            setFunc = function(value)
                                sv.hideInPVP = value
                                StackTracker:PVPSwitch(skill)
                            end,
                        },
                        {
                            type = "slider",
                            name = "Stack indicator size",
                            min = 10,
                            max = 60,
                            step = 1,
                            decimals = 0,
                            default = sv.indicatorSize,
                            getFunc = function() return sv.indicatorSize end,
                            setFunc = function(value)
                                sv.indicatorSize = value
                                StackTracker.UI[skill].indicator.ApplySize(value)

                            end,
                        },
                        {
                            type = "checkbox",
                            name = "Play sound cue at max stacks",
                            tooltip = "Plays a sound when you are at max stacks, so you don't miss to cast your ability",
                            getFunc = function() return sv.playSound end,
                            setFunc = function(value)
                                sv.playSound = value

                            end,
                        },
                        {
                            type = "slider",
                            name = "Sound cue volume",
                            tooltip = "Adjust volume of the sound cue effect",

                            disabled = function() return not sv.playSound end,
                            min = 1,
                            max = 30,
                            step = 1,
                            decimals = 0,
                            getFunc = function() return sv.volume end,
                            setFunc = function(value)
                                sv.volume = value
                                for i = 1, math.min(value, 30) do
                                    PlaySound(SOUNDS[sv.sound])
                                end
                            end,
                        },
                        {
                            type = "dropdown",
                            name = "Select Sound",
                            choices = fullStackSounds,
                            default = sv.sound,
                            disabled = function() return not sv.playSound end,
                            getFunc = function() return sv.sound end,
                            setFunc = function(value)
                                sv.sound = value
                                for i = 1, math.min(sv.volume, 30) do
                                    PlaySound(SOUNDS[value])
                                end
                            end
                        },
                        {
                            type = "checkbox",
                            name = "Animation cue to fire stacks",
                            tooltip = "Gives you a more intense visual cue, if you reach an amount of stacks needed to fire an ability, or at max stacks",
                            getFunc = function() return sv.hightlightOnFullStacks end,
                            setFunc = function(value)
                                sv.hightlightOnFullStacks = value
                                if value and StackTracker.stacks[skill] and StackTracker.stacks[skill] >= StackTracker.SKILL_ATTRIBUTES[skill].iMax and StackTracker.UI[skill].indicator[StackTracker.SKILL_ATTRIBUTES[skill].iMax].controls.highlightAnimation:IsControlHidden() then
                                    for i=1,#StackTracker.UI[skill].indicator do
                                        StackTracker.UI[skill].indicator[i].Animate()
                                        StackTracker.UI[skill].indicator[i].controls.highlightAnimation:SetHidden(true)
                                    end
                                    for i=1,StackTracker.stacks[skill] do
                                        StackTracker.UI[skill].indicator[i].controls.highlightAnimation:SetHidden(false)
                                    end
                                elseif not value and not StackTracker.UI[skill].indicator[StackTracker.SKILL_ATTRIBUTES[skill].iMax].controls.highlightAnimation:IsControlHidden() then
                                    for i=1,#StackTracker.UI[skill].indicator do
                                        StackTracker.UI[skill].indicator[i].StopAnimation()
                                        StackTracker.UI[skill].indicator[i].controls.highlightAnimation:SetHidden(true)
                                    end
                                end
                            end,
                        },
                    },
                },
            }
            if WeavePulse.StackTracker.SKILL_ATTRIBUTES[skill].duration then
                local position = FindMenuPosition(submenu[1].controls, "Stack indicator size")
                if not position then return end
                local controls = {
                    {
                        type = "header",
                        name = "Timer indicators"
                    },
                    {
                        type = "checkbox",
                        name = "Show buff timer",
                        tooltip = "Shows a timer right next to your stack indicators",
                        disabled = function () return not sv.tracked end,
                        getFunc = function() return sv.showTimer end,
                        setFunc = function(value)
                            sv.showTimer = value
                            StackTracker.UI[skill].indicator.timer:SetHidden(not (value and WeavePulse.SV.StackTracker.isUnlocked))
                            StackTracker.UI[skill].indicator.timerBarTimer:SetHidden(value and WeavePulse.SV.StackTracker.isUnlocked)
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Show timer bar",
                        tooltip = "Shows a timer bar right under to your stack indicators",
                        disabled = function () return not sv.tracked end,
                        getFunc = function() return sv.showTimerBar end,
                        setFunc = function(value)
                            sv.showTimerBar = value
                            StackTracker.UI[skill].indicator.timerBar:SetHidden(not (value and WeavePulse.SV.StackTracker.isUnlocked))
                            StackTracker.UI[skill].indicator.timerBarGloss:SetHidden(not (value and WeavePulse.SV.StackTracker.isUnlocked))
                            StackTracker.UI[skill].indicator.timerBarBackdrop:SetHidden(not (value and WeavePulse.SV.StackTracker.isUnlocked))
                            StackTracker.UI[skill].indicator.timerBarTimer:SetHidden(not (value and WeavePulse.SV.StackTracker.isUnlocked) or sv.showTimer)
                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Bar orientation",

                        choices = {"LEFT", "RIGHT"},
                        disabled = function() return not (sv.tracked and sv.showTimerBar) end,
                        getFunc = function() return sv.timerBarOrientation end,
                        setFunc = function(value)
                            sv.timerBarOrientation = value
                            StackTracker.UI[skill].indicator.TimerBarOrientation(value)
                        end
                    },
                    {
                        type = "header",
                        name = "Audio and visual cues",
                        tooltip = "Settings regarding audio and visual cues when reaching full stacks or buff expiration",
                    },
                }
                for i = 1, #controls do
                    table.insert(submenu[1].controls, position + i, controls[i])
                end
                controls = {
                    {
                        type = "divider",
                    },
                    {
                        type = "checkbox",
                        name = "Animate timer when about to run out",
                        tooltip = "Animates the timer when buff is about to run out",
                        width = "half",
                        disabled = function () return not (sv.tracked and sv.showTimer) end,
                        getFunc = function() return sv.animateTimer end,
                        setFunc = function(value)
                            sv.animateTimer = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Play sound when about to run out",
                        tooltip = "Plays a sound when buff is about to run out",
                        width = "half",
                        disabled = function () return not sv.tracked end,
                        getFunc = function() return sv.soundReminder end,
                        setFunc = function(value)
                            sv.soundReminder = value
                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Select Sound",
                        width = "half",
                        choices = sounds,
                        default = sv.soundReminder,
                        disabled = function() return not (sv.tracked and sv.soundReminder) end,
                        getFunc = function() return sv.expirationSound end,
                        setFunc = function(value)
                            sv.expirationSound = value
                            for i = 1, math.min(sv.reminderVolume, 30) do
                                PlaySound(value)
                            end
                        end
                    },
                    {
                        type = "slider",
                        name = "Reminder volume",
                        tooltip = "Adjust volume of the reminder sound",

                        width = "half",
                        disabled = function() return not (sv.tracked and sv.soundReminder) end,
                        min = 1,
                        max = 30,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return sv.reminderVolume end,
                        setFunc = function(value)
                            sv.reminderVolume = value
                            for i = 1, math.min(value, 30) do
                                PlaySound(sv.expirationSound)
                            end
                        end,
                    },
                    {
                        type = "slider",
                        name = "Time remaining (ms)",
                        tooltip = "Adjust the time remaining to show/play reminders",
                        disabled = function() return not (sv.tracked and (sv.animateTimer or sv.soundReminder)) end,
                        min = 500,
                        max = 5000,
                        step = 100,
                        decimals = 0,
                        getFunc = function() return sv.expirationTimer*1000 end,
                        setFunc = function(value) sv.expirationTimer = value/1000 end,
                    },
                    {
                        type = "checkbox",
                        name = "Only during combat",
                        tooltip = "Only shows/plays buff expiration reminders when in combat",
                        disabled = function () return not (sv.tracked and (sv.animateTimer or sv.soundReminder)) end,
                        getFunc = function() return sv.remindersOnlyInCombat end,
                        setFunc = function(value)
                            sv.remindersOnlyInCombat = value
                        end,
                    },
                }
                for i = 1, #controls do
                    table.insert(submenu[1].controls, controls[i])
                end
            else
                local position = FindMenuPosition(submenu[1].controls, "Play sound cue at max stacks")
                if not position then return end
                local queueHeader = {
                    type = "header",
                    name = "Audio and visual cues",
                    tooltip = "Settings regarding audio and visual cues when reaching full stacks",
                }
                table.insert(submenu[1].controls, position, queueHeader)
            end
            table.insert(self.menu.options.StackTracker, position+i, submenu[1])

        end
    end
    self.menu.abilityAdjustChoices = self:CreateAdjustList()
    self.menu.curSkillName = ABILITY_ADJUST_PLACEHOLDER
    self.menu.curSkillId = -1

    local websiteString
    if WeavePulse.beta then
        websiteString = "https://www.esoui.com/downloads/info3987-WeavePulseGCDTracker-beta.html"
    else
        websiteString = "https://www.esoui.com/downloads/info2373-WeavePulseGCDTracker.html"
    end

    self.menu.metadata = {
        ["General"] = {
            type = "panel",
            name = "WeavePulse - General",
            displayName = "|ce11212C|rombat |ce11212M|retronome - General",
            author = "Darianopolis, |c2a52beb|rarny",
            version = self.versionString,
            website = websiteString,
            feedback = "https://www.esoui.com/portal.php?&id=386",
            donation = "https://buymeacoffee.com/barnyteso",
            slashCommand = "/wp",
            registerForRefresh = true,
            registerForDefaults = true,
        },
        ["Progressbar"] = {
            type = "panel",
            name = "WeavePulse - Progressbar",
            displayName = "|ce11212C|rombat |ce11212M|retronome - Progressbar",
            author = "Darianopolis, |c2a52beb|rarny",
            version = self.versionString,
            website = websiteString,
            feedback = "https://www.esoui.com/portal.php?&id=386",
            donation = "https://buymeacoffee.com/barnyteso",
            slashCommand = "/wpp",
            registerForRefresh = true,
            registerForDefaults = true,
        },
        ["Resources"] = {
            type = "panel",
            name = "WeavePulse - Resources",
            displayName = "|ce11212C|rombat |ce11212M|retronome - Resources",
            author = "Darianopolis, |c2a52beb|rarny",
            version = self.versionString,
            website = websiteString,
            feedback = "https://www.esoui.com/portal.php?&id=386",
            donation = "https://buymeacoffee.com/barnyteso",
            slashCommand = "/wpr",
            registerForRefresh = true,
            registerForDefaults = true,
        },
        ["StackTracker"] = {
            type = "panel",
            name = "WeavePulse - StackTracker",
            displayName = "|ce11212C|rombat |ce11212M|retronome - StackTracker",
            author = "|c2a52beb|rarny",
            version = self.versionString,
            website = websiteString,
            feedback = "https://www.esoui.com/portal.php?&id=386",
            donation = "https://buymeacoffee.com/barnyteso",
            slashCommand = "/wpstacks",
            registerForRefresh = true,
            registerForDefaults = true,
        },
        ["LATracker"] = {
            type = "panel",
            name = "WeavePulse - LA Tracker",
            displayName = "|ce11212C|rombat |ce11212M|retronome - LA Tracker",
            author = "|c2a52beb|rarny",
            version = self.versionString,
            website = websiteString,
            feedback = "https://www.esoui.com/portal.php?&id=386",
            donation = "https://buymeacoffee.com/barnyteso",
            slashCommand = "/wpla",
            registerForRefresh = true,
            registerForDefaults = true,
        },
    }
    self.menu.options = {
        ["General"] = {
            {
                type = "header",
                name = "General settings"
            },
            {
                type = "checkbox",
                name = "Account Wide",
                tooltip = "Check for account wide addon settings",
                getFunc = function() return WeavePulse.SV.global end,
                setFunc = function(value)
                    if WeavePulse.SV.global == value then return end

                    if value then
                        WeavePulse.SV.global = true
                        WeavePulse.SV = ZO_SavedVars:NewAccountWide(
                            "WeavePulseSavedVars", 2, nil, WeavePulse.DEFAULT_SAVED_VARS
                        )
                        if not WeavePulse.SV.migrated then
                            self:CheckSavedVariables()
                            if WeavePulse.SV.debug.enabled then WeavePulse.debug:Print("Migrating saved variables") end
                        end
                        WeavePulse.SV.global = true
                    else
                        WeavePulse.SV = ZO_SavedVars:NewCharacterIdSettings(
                            "WeavePulseSavedVars", 2, nil, WeavePulse.DEFAULT_SAVED_VARS
                        )
                        if not WeavePulse.SV.migrated then
                            self:CheckSavedVariables()
                            if WeavePulse.SV.debug.enabled then WeavePulse.debug:Print("Migrating saved variables") end
                        end
                        WeavePulse.SV.global = false
                    end

                    WeavePulse.SV.global = value
                    self:UpdateAdjustChoices()
                    self:BuildUI()
                end,
            },
            {
                type = "checkbox",
                name = "Automatic SV cleanup",
                getFunc = function() return WeavePulse.SV.automaticSVCleanup.enabled end,
                setFunc = function(value)
                    WeavePulse.SV.automaticSVCleanup.enabled = value
                    if value then
                        WeavePulse:AutomaticSVCleanup()
                    end
                end
            },

            {	type = "divider"},
            {
                type = "checkbox",
                name = "Enable debugging",
                disabled = function() if WeavePulse.debug then return false else return true end end,
                getFunc = function() return WeavePulse.SV.debug.enabled end,
                setFunc = function(value)
                    WeavePulse.SV.debug.enabled = value

                    if not value then
                        WeavePulse:SetAllDebugFalse()
                    end

                end
            },
            {
                type = "checkbox",
                name = "Print timestamps",
                tooltip = "Include timestamps in debug messages",
                disabled = function() return not WeavePulse.SV.debug.enabled end,
                getFunc = function() return WeavePulse.SV.debug.printTimestamps end,
                setFunc = function(value) WeavePulse.SV.debug.printTimestamps = value end,
            },
            {
                type = "submenu",
                name = "Debug Options",
                disabled = function() return not WeavePulse.SV.debug.enabled end,
                controls = {
                    {
                        type = "header",
                        name = "Ability.lua",
                    },
                    {	type = "checkbox",
                        name = "Debug ability.lua triggers",
                        getFunc = function() return WeavePulse.SV.debug.triggers end,
                        setFunc = function(value)
                            WeavePulse.SV.debug.triggers = value

                        end,
                        width = "half",
                    },
                    {
                        type = "slider",
                        name = "Ability trigger timer",
                        tooltip = "The goal is to set it as low as possible and still have all the spells triggered",
                        min = 50,
                        max = 400,
                        step = 10,
                        decimals = 0,
                        width = "half",
                        disabled = function() return not WeavePulse.SV.debug.triggers end,
                        getFunc = function() return WeavePulse.SV.debug.triggerTimer end,
                        setFunc = function(value)
                            WeavePulse.SV.debug.triggerTimer = value
                        end,
                    },
                    {	type = "checkbox",
                        name = "Debug ability.lua currentEvent",
                        getFunc = function() return WeavePulse.SV.debug.currentEvent end,
                        setFunc = function(value)
                            WeavePulse.SV.debug.currentEvent = value

                        end,
                        width = "half",
                    },
                    {	type = "checkbox",
                        name = "Debug ability.lua queuedEvent",
                        getFunc = function() return WeavePulse.SV.debug.eventCancel end,
                        setFunc = function(value)
                            WeavePulse.SV.debug.eventCancel = value

                        end,
                        width = "half",
                    },
                    {	type = "checkbox",
                        name = "Debug ability.lua AbilityUsed()",
                        getFunc = function() return WeavePulse.SV.debug.abilityUsed end,
                        setFunc = function(value)
                            WeavePulse.SV.debug.abilityUsed = value

                        end,
                        width = "half",
                    },

                    {
                        type = "dropdown",
                        name = "Add ability ID to debug whitelist",
                        choices = self.currentlyEquippedAbilities.list,
                        getFunc = function() end,
                        setFunc = function(selectedSkill)
                            local skillData = self:GetEquippedSkillData(selectedSkill)
                            if not WeavePulse.SV.debug.abilityWhitelist.ids[skillData.id] then
                                table.insert(WeavePulse.SV.debug.abilityWhitelist.list, selectedSkill)
                                WeavePulse.SV.debug.abilityWhitelist.ids[skillData.id] = true
                                UpdateDebugListChoices()
                            end
                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Delete from ability whitelist",
                        choices = WeavePulse.SV.debug.abilityWhitelist.list or {},
                        getFunc = function() end,
                        setFunc = function(selectedSkill)
                            for i, name in ipairs(WeavePulse.SV.debug.abilityWhitelist.list) do
                                if name == selectedSkill then
                                    local skillData = self:GetEquippedSkillData(selectedSkill)
                                    if not skillData then
                                        for id in pairs(WeavePulse.SV.debug.abilityWhitelist.ids) do
                                            local aName = Util.Text.CropZOSString(GetAbilityName(id), "ability")
                                            if string.find(name, aName) then
                                                WeavePulse.SV.debug.abilityWhitelist.ids[id] = nil
                                                break
                                            end
                                        end
                                    else
                                        WeavePulse.SV.debug.abilityWhitelist.ids[skillData.id] = nil
                                    end
                                    table.remove(WeavePulse.SV.debug.abilityWhitelist.list, i)
                                    UpdateDebugListChoices()
                                    break
                                end
                            end
                        end,
                    },
                    {
                        type = "header",
                        name = "Sound",
                    },
                    {	type = "checkbox",
                        name = "'Tick' & 'Tock' triggers",
                        getFunc = function() return WeavePulse.SV.debug.tickTock end,
                        setFunc = function(value)
                            WeavePulse.SV.debug.tickTock = value

                        end,
                        width = "half",
                    },
                },
            },

        },
        ["Progressbar"] = {
            {
                type = "header",
                name = "Progressbar aka. GCD Tracker",
                tooltip = "Lets you track your GCD and helps you queuing your light attacks and spells more efficiently.",
            },
            {
                type = "checkbox",
                name = "Hide GCD Tracker",
                tooltip = "Hides progress bar, in case you just need the stack tracker",
                warning = "Activating this disables all other settings regarding the GCD Tracker",
                getFunc = function() return WeavePulse.SV.Progressbar.hide end,
                setFunc = function(value)
                    WeavePulse.SV.Progressbar.hide  = value
                    if value then
                        self:UnregisterCM()
                        self.Progressbar.bar:SetHidden(true)
                        self.Progressbar.UI.FadeScenes("NoUI")
                        self.Progressbar.showSample = false
                    else
                        self:RegisterCM()
                        self.Progressbar.UI.FadeScenes("UI")
                    end
                    self.Progressbar.UI.HiddenStates()
                end,
            },
            {
                type = "checkbox",
                name = "Hide progress bar in PVP Zones",
                tooltip = "Hides progress bar in PVPZones to keep UI clean",
                disabled = function() return WeavePulse.SV.Progressbar.hide end,
                getFunc = function() return WeavePulse.SV.Progressbar.hideInPVP end,
                setFunc = function(value)
                    WeavePulse.SV.Progressbar.hideInPVP = value
                    self:CMPVPSwitch()

                end,
            },
            {
                type = "checkbox",
                name = "How does it look?",
                tooltip = "Shows bar at the right of the screen to check your settings. This bar is not resizable nor movable! This resets if you leave the menu.",
                warning = "This temporarily disables the Unlock function and is disabled if progressbar is unlocked! Deactivate again to be able to unlock the bar.",
                disabled = function() return WeavePulse.SV.Progressbar.hide or WeavePulse.Progressbar.frame.IsUnlocked() end,
                default = false,
                getFunc = function() return self.Progressbar.showSample end,
                setFunc = function(value)
                    self.Progressbar.showSample = value
                    if value then
                        self.Progressbar.UI.Position("Sample")
                        self.Progressbar.UI.FadeScenes("Sample")
                    else
                        self.Progressbar.UI.Position("UI")
                        self.Progressbar.UI.FadeScenes("NoSample")
                    end
                    self.Progressbar.UI.HiddenStates()
                end,
            },

            {
                type = "submenu",
                name = "Position / Size",
                disabled = function() return WeavePulse.SV.Progressbar.hide end,
                controls = {
                    {
                        type = "checkbox",
                        name = "Unlock progressbar",
                        tooltip = "Reposition / resize bar by dragging center / edges.",

                        disabled = function() return self.Progressbar.showSample end,
                        getFunc = function() return self.Progressbar.frame.IsUnlocked() end,
                        setFunc = function(value)
                            self.Progressbar.frame:SetUnlocked(value)
                            if value then
                                self.Progressbar.frame:SetDrawTier(DT_HIGH)
                                self.Progressbar.frame:SetHidden(false)
                            else
                                self.Progressbar.frame:SetDrawTier(DT_LOW)
                                self.Progressbar.frame:SetHidden(true)
                            end
                        end,
                    },
                    {
                        type = "slider",
                        name = "X Offset",
                        min = 0,

                        max = MAX_WIDTH - WeavePulse.SV.Progressbar.width,
                        step = 1,
                        decimals = 0,
                        disabled = function() return self.Progressbar.showSample end,
                        getFunc = function() return math.floor(WeavePulse.SV.Progressbar.xOffset) end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.xOffset = value
                            self.Progressbar.UI.Position("UI")

                        end,
                    },
                    {
                        type = "button",
                        name = "Center Horizontally",
                        disabled = function() return self.Progressbar.showSample end,
                        func = function()
                            WeavePulse.SV.Progressbar.xOffset = math.floor((GuiRoot:GetWidth() - WeavePulse.SV.Progressbar.width) / 2)
                            self.Progressbar.UI.Position("UI")

                        end
                    },
                    {
                        type = "slider",
                        name = "Y Offset",
                        min = 0,

                        max = math.floor(GuiRoot:GetHeight() - WeavePulse.SV.Progressbar.height),
                        step = 1,
                        decimals = 0,
                        disabled = function() return self.Progressbar.showSample end,
                        getFunc = function() return math.floor(WeavePulse.SV.Progressbar.yOffset) end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.yOffset = value
                            self.Progressbar.UI.Position("UI")

                        end,
                    },
                    {
                        type = "button",
                        name = "Center Vertically",
                        disabled = function() return self.Progressbar.showSample end,
                        func = function()
                            WeavePulse.SV.Progressbar.yOffset = math.floor((GuiRoot:GetHeight() - WeavePulse.SV.Progressbar.height) / 2)
                            self.Progressbar.UI.Position("UI")

                        end
                    },
                    {
                        type = "slider",
                        name = "Width",
                        min = MIN_WIDTH,
                        max = MAX_WIDTH,
                        step = 1,
                        decimals = 0,

                        getFunc = function() return WeavePulse.SV.Progressbar.width end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.width = value
                            self.Progressbar.UI.Size()
                            DeleteShortNamesFromCache()
                            UpdateProgressbarSizeSliders()
                            if WeavePulse.SV.Progressbar.xOffset > WeavePulse.Progressbar.maxXOffset then WeavePulse.SV.Progressbar.xOffset = WeavePulse.Progressbar.maxXOffset end
                            if WeavePulse.SV.Progressbar.dynamicExpansionMultiplyer > WeavePulse.Progressbar.maxMultiplyer then WeavePulse.SV.Progressbar.dynamicExpansionMultiplyer = WeavePulse.Progressbar.maxMultiplyer end

                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Expand width with abilities > 1s",
                        tooltip = "Will expand castbar width by multiplying width x time",
                        getFunc = function() return WeavePulse.SV.Progressbar.expandDynamically end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.expandDynamically = value
                        end,
                        width = "half",
                    },
                    {
                        type = "checkbox",
                        name = "Move spellicon dynamically",
                        disabled = function() return not (WeavePulse.SV.Progressbar.showSpell and WeavePulse.SV.Progressbar.expandDynamically and WeavePulse.SV.Progressbar.barAlign == "Center") end,
                        getFunc = function() return WeavePulse.SV.Progressbar.moveIconDynamically end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.moveIconDynamically = value
                        end,
                        width = "half",
                    },
                    {
                        type = "slider",
                        name = "Dynamic expansion multiplyer",
                        tooltip = "You may chose a custom multiplyer for dynamic castbar expansion",
                        disabled = function() return not WeavePulse.SV.Progressbar.expandDynamically end,
                        min = 1,
                        max = WeavePulse.Progressbar.maxMultiplyer or 10,
                        step = 1,
                        decimals = 0,
                        default = 5,
                        getFunc = function() return WeavePulse.SV.Progressbar.dynamicExpansionMultiplyer end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.dynamicExpansionMultiplyer = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Height",
                        min = MIN_HEIGHT,
                        max = MAX_HEIGHT,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.height end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.height = value
                            self.Progressbar.UI.Size()
                            UpdateProgressbarSizeSliders()
                            if WeavePulse.SV.Progressbar.yOffset > WeavePulse.Progressbar.maxYOffset then WeavePulse.SV.Progressbar.yOffset = WeavePulse.Progressbar.maxYOffset end

                        end,
                    },
                },
            },

            {
                type = "submenu",
                name = "Visuals / Color / Layout",
                disabled = function() return WeavePulse.SV.Progressbar.hide end,
                controls = {
                    {
                        type = "checkbox",
                        name = "Make it fancy",
                        tooltip = "Have fancy effects and stuff",
                        getFunc = function() return WeavePulse.SV.Progressbar.makeItFancy, WeavePulse.SV.Progressbar.lastBackgroundColor, WeavePulse.SV.Progressbar.backgroundColor end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.makeItFancy = value
                            if value then
                                WeavePulse.SV.Progressbar.lastBackgroundColor = WeavePulse.SV.Progressbar.backgroundColor
                                WeavePulse.SV.Progressbar.backgroundColor = {0, 0, 0, 0}
                            else
                                WeavePulse.SV.Progressbar.backgroundColor = WeavePulse.SV.Progressbar.lastBackgroundColor
                            end

                            self.Progressbar.UI.HiddenStates()
                            self.Progressbar.UI.BarColors()

                        end,
                    },
                    {
                        type = "divider"
                    },
                    {
                        type = "colorpicker",
                        name = "Background Color",
                        tooltip = "Color of the bar background",
                        disabled = function()
                            return (WeavePulse.SV.Progressbar.makeItFancy)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Progressbar.backgroundColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Progressbar.backgroundColor = {r, g, b, a}
                            self.Progressbar.UI.BarColors()

                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Progress Color",
                        tooltip = "Color of the progress bar",
                        getFunc = function() return unpack(WeavePulse.SV.Progressbar.progressColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Progressbar.progressColor = {r, g, b, a}
                            self.Progressbar.UI.BarColors()

                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Ping Color",
                        tooltip = "Color of the ping zone",
                        getFunc = function() return unpack(WeavePulse.SV.Progressbar.pingColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Progressbar.pingColor = {r, g, b, a}
                            self.Progressbar.UI.BarColors()

                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Alignment",
                        tooltip = "Alignment of the progress bar",
                        choices = {"Left", "Center", "Right"},
                        getFunc = function() return WeavePulse.SV.Progressbar.barAlign end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.barAlign = value
                            self.Progressbar.UI.Anchors()

                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Switch Progress Color while channeling/casting",
                        tooltip = "Change bar color on channeling/casting abilities to indicate possibility to barswap, when channel/cast is finished",
                        warning = "This is experimental and might feel a little wonky",
                        getFunc = function() return WeavePulse.SV.Progressbar.changeOnChanneled end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.changeOnChanneled = value

                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Channel Color",
                        tooltip = "Color while channelling",
                        disabled = function()
                            return (not WeavePulse.SV.Progressbar.changeOnChanneled)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Progressbar.channelColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Progressbar.channelColor = {r, g, b, a}
                            self.Progressbar.UI.BarColors()

                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Label font",
                        tooltip = "Font that is used for labels",
                        choices = labelFonts,
                        width = "half",
                        getFunc = function() return WeavePulse.SV.Progressbar.labelFont end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.labelFont = value
                            self.Progressbar.UI.Fonts()
                            LATrackerSettings.LabelSettings()
                            self.Resources.executeLabel:SetFont(Util.Text.getFontString(tostring("$("..WeavePulse.SV.Progressbar.labelFont..")"), WeavePulse.SV.Resources.executeHeight, WeavePulse.SV.Progressbar.fontStyle))

                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Font Style",
                        tooltip = "Font style that is used for labels",
                        choices = fontStyles,
                        width = "half",
                        getFunc = function() return WeavePulse.SV.Progressbar.fontStyle end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.fontStyle = value
                            self.Progressbar.UI.Fonts()
                            LATrackerSettings.LabelSettings()
                            self.Resources.executeLabel:SetFont(Util.Text.getFontString(tostring("$("..WeavePulse.SV.Progressbar.labelFont..")"), WeavePulse.SV.Resources.executeHeight, WeavePulse.SV.Progressbar.fontStyle))

                        end,
                    },
                    {
                        type = "slider",
                        name = "Font size",
                        warning = "Font size only applies to time remaining and spell name!",
                        min = 5,
                        max = math.floor(WeavePulse.SV.Progressbar.height),
                        step = 1,
                        decimals = 0,
                        disabled = function() return not (WeavePulse.SV.Progressbar.showTimeRemaining or WeavePulse.SV.Progressbar.showSpell) end,
                        getFunc = function() return WeavePulse.SV.Progressbar.spellSize end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.spellSize = value
                            self.Progressbar.UI.Fonts()
                            DeleteShortNamesFromCache()
                        end,
                    },
                },
            },

            {
                type = "submenu",
                name = "Behavior",
                disabled = function() return WeavePulse.SV.Progressbar.hide end,
                controls = {
                    {
                        type = "checkbox",
                        name = "Show permanently",
                        tooltip = "If you don't want to hide the cast bar when it's unused, it will display the background color.",
                        disabled = function() return WeavePulse.Progressbar.showSample end,
                        getFunc = function() return WeavePulse.SV.Progressbar.dontHide end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.dontHide = value
                            self.Progressbar.UI.HiddenStates()

                        end,
                    },
                    {
                        type = "divider"
                    },
                    {
                        type = "slider",
                        name = "Max latency",
                        tooltip = "Set the maximum display latency",
                        min = 0,
                        max = 1000,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.maxLatency end,
                        setFunc = function(value) WeavePulse.SV.Progressbar.maxLatency = value end,
                    },
                    {
                        type = "slider",
                        name = "GCD Adjust",
                        tooltip = "Increase/decrease the displayed GCD length",
                        min = -MAX_ADJUST,
                        max = MAX_ADJUST,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.gcdAdjust end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.gcdAdjust = value

                        end,
                    },
                    {
                        type = "slider",
                        name = "Global Heavy Attack Adjust",
                        tooltip = "Increase/decrease the baseline heavy attack cast time. Additional adjustments to specific heavy types are made in addition to this",
                        min = -MAX_ADJUST,
                        max = MAX_ADJUST,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.globalHeavyAdjust end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.globalHeavyAdjust = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Global Ability Cast Adjust",
                        tooltip = "Increase/decrease the baseline ability cast time. Additional adjustments to specific abilities are made in addition to this",
                        min = -MAX_ADJUST,
                        max = MAX_ADJUST,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.globalAbilityAdjust end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.globalAbilityAdjust = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Show OOC",
                        tooltip = "Track GCDs whilst out of combat",
                        getFunc = function() return WeavePulse.SV.Progressbar.showOOC end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.showOOC = value
                            if not value and WeavePulse.SV.Progressbar.trackGCD then
                                WeavePulse.SV.Progressbar.trackGCD = false
                            end
                        end
                    },
                    {
                        type = "divider"
                    },
                    {
                        type = "checkbox",
                        name = "Track all GCDs",
                        tooltip = "In addition to ability GCDs also track itmes, synergies, etc.",
                        disabled = function() return not WeavePulse.SV.Progressbar.showOOC end,
                        getFunc = function() return WeavePulse.SV.Progressbar.trackGCD end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.trackGCD = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Show ping zone for non ability GCD",
                        tooltip = "If turned on this shows a ping zone for GCD caused by using items or synergies, etc.",
                        disabled = function() return (not WeavePulse.SV.Progressbar.trackGCD or WeavePulse.SV.Progressbar.dontShowPing) end,
                        getFunc = function() return WeavePulse.SV.Progressbar.showPingOnGCD end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.showPingOnGCD = value
                        end,
                    },
                    {
                        type = "submenu",
                        name = "Show further gcd information",
                        disabled = function() return not WeavePulse.SV.Progressbar.trackGCD end,
                        controls = {
                            {
                                type = "checkbox",
                                name = self.menu.CONTROLS.progressbar[1].Name,
                                disabled = function() return not WeavePulse.SV.Progressbar.trackGCD end,
                                default = false,
                                getFunc = function() return WeavePulse.SV.Progressbar.trackRolldodge end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.trackRolldodge = value
                                    IconDesaturation(self.menu.icons.progressbar[1], value)
                                end,
                            },
                            {
                                type = "checkbox",
                                name = self.menu.CONTROLS.progressbar[2].Name,
                                disabled = function() return not WeavePulse.SV.Progressbar.trackGCD end,
                                default = false,
                                getFunc = function() return WeavePulse.SV.Progressbar.trackMounting end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.trackMounting = value
                                    IconDesaturation(self.menu.icons.progressbar[2], value)
                                    if value then
                                        if not self.combatEventsRegistered then
                                            WeavePulse:RegisterCombatEvents()
                                        end
                                        if WeavePulse.SV.Progressbar.showMountNick and not self.collectiblesTrackerRegistered then
                                            WeavePulse:RegisterCollectiblesTracker()
                                        end
                                    else
                                        if self.mountingTrackerRegistered and not WeavePulse:CheckForCombatEventsRegister() then
                                            WeavePulse:UnregisterCombatEvents()
                                        end
                                        if not WeavePulse.SV.Progressbar.trackCollectibles and self.collectiblesTrackerRegistered then
                                            WeavePulse:UnregisterCollectiblesTracker()
                                        end
                                    end
                                end,
                            },
                            {
                                type = "checkbox",
                                name = "Show mount nickname",
                                disabled = function() return not WeavePulse.SV.Progressbar.trackMounting end,
                                default = false,
                                getFunc = function() return WeavePulse.SV.Progressbar.showMountNick end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.showMountNick = value
                                    if value then
                                        if not self.collectiblesTrackerRegistered then
                                            WeavePulse:RegisterCollectiblesTracker()
                                        end
                                    else
                                        if not WeavePulse.SV.Progressbar.trackCollectibles and self.collectiblesTrackerRegistered then
                                            WeavePulse:UnregisterCollectiblesTracker()
                                        end
                                    end
                                end,
                            },
                            {
                                type = "checkbox",
                                name = self.menu.CONTROLS.progressbar[3].Name,
                                disabled = function() return not WeavePulse.SV.Progressbar.trackGCD end,
                                default = false,
                                getFunc = function() return WeavePulse.SV.Progressbar.trackCollectibles end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.trackCollectibles = value
                                    IconDesaturation(self.menu.icons.progressbar[3], value)
                                    if value then
                                        if not self.CollectiblesTrackerRegistered then
                                            WeavePulse:RegisterCollectiblesTracker()
                                        end
                                    else
                                        if self.collectiblesTrackerRegistered and not WeavePulse.SV.Progressbar.showMountNick then
                                            WeavePulse:UnregisterCollectiblesTracker()
                                        end
                                    end
                                end,
                            },
                            {
                                type = "checkbox",
                                name = self.menu.CONTROLS.progressbar[4].Name,
                                disabled = function() return not WeavePulse.SV.Progressbar.trackGCD end,
                                default = false,
                                getFunc = function() return WeavePulse.SV.Progressbar.trackItems end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.trackItems = value
                                    IconDesaturation(self.menu.icons.progressbar[4], value)
                                    if value and not self.itemsTrackerRegistered then
                                        WeavePulse:RegisterItemsTracker()
                                    elseif not value and self.itemsTrackerRegistered then
                                        WeavePulse:UnregisterItemsTracker()
                                    end
                                end,
                            },
                            {
                                type = "checkbox",
                                name = self.menu.CONTROLS.progressbar[5].Name,
                                tooltip = "Toggle displaying synergies like vampire feed and blade of woe",
                                disabled = function() return not WeavePulse.SV.Progressbar.trackGCD end,
                                default = false,
                                getFunc = function() return WeavePulse.SV.Progressbar.trackSynergies end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.trackSynergies = value
                                    IconDesaturation(self.menu.icons.progressbar[5], value)
                                    if value then
                                        if not self.combatEventsRegistered then
                                            WeavePulse:RegisterCombatEvents()
                                        elseif not self.synergyChangedRegistered then
                                            WeavePulse:RegisterSynergyChanged()
                                        end
                                    elseif not value then
                                        if self.combatEventsRegistered and not WeavePulse:CheckForCombatEventsRegister() then
                                            WeavePulse:UnregisterCombatEvents()
                                        elseif self.synergyChangedRegistered then
                                            WeavePulse:UnregisterSynergyChanged()
                                        end
                                    end
                                end,
                            },
                            {
                                type = "checkbox",
                                name = self.menu.CONTROLS.progressbar[6].Name,
                                disabled = function() return not WeavePulse.SV.Progressbar.trackGCD end,
                                default = false,
                                getFunc = function() return WeavePulse.SV.Progressbar.trackBreakingFree end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.trackBreakingFree = value
                                    IconDesaturation(self.menu.icons.progressbar[6], value)
                                    if value and not self.combatEventsRegistered then
                                        WeavePulse:RegisterCombatEvents()
                                    elseif not value and self.combatEventsRegistered and not WeavePulse:CheckForCombatEventsRegister() then
                                        WeavePulse:UnregisterCombatEvents()
                                    end
                                end,
                            },
                        },
                    },
                    {
                        type = "divider"
                    },
                    {
                        type = "checkbox",
                        name = "Don't show ping zone",
                        tooltip = "Don't show Ping Zone on cast bar at all",
                        getFunc = function() return WeavePulse.SV.Progressbar.dontShowPing end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.dontShowPing = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Display spell name in cast bar",
                        tooltip = "Displays the spell name in the cast bar, when the ability is not an instant cast",
                        getFunc = function() return WeavePulse.SV.Progressbar.showSpell end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.showSpell = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Display spell name for any ability",
                        tooltip = "Always displays the spell name in the cast bar, not only when the ability is not an instant cast",
                        disabled = function() return not WeavePulse.SV.Progressbar.showSpell end,
                        getFunc = function() return WeavePulse.SV.Progressbar.alwaysShowSpell end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.alwaysShowSpell = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Display time remaining in cast bar",
                        tooltip = "Displays the remaining time on channel or cast in the cast bar, when the ability is not an instant cast",
                        getFunc = function() return WeavePulse.SV.Progressbar.showTimeRemaining end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.showTimeRemaining = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Display time remaining for all abilities",
                        tooltip = "Always displays the remaining time on channel or cast in the cast bar, not only when the ability is not an instant cast",
                        disabled = function() return not WeavePulse.SV.Progressbar.showTimeRemaining end,
                        getFunc = function() return WeavePulse.SV.Progressbar.alwaysShowTimeRemaining end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.alwaysShowTimeRemaining = value
                        end,
                    },
                    {
                        type = "submenu",
                        name = "Heavy Attack options",
                        controls = {
                            {
                                type = "checkbox",
                                name = "Don't show heavy attacks",
                                tooltip = "Stops displaying heavy attacks on the progress bar",
                                getFunc = function() return WeavePulse.SV.Progressbar.stopHATracking end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.stopHATracking = value
                                end,
                            },
                            {
                                type = "checkbox",
                                name = "Display ping zone on heavy attacks",
                                tooltip = "Displays heavy attacks with ping zone",
                                disabled = function()
                                    return WeavePulse.SV.Progressbar.dontShowPing or WeavePulse.SV.Progressbar.stopHATracking
                                end,
                                getFunc = function() return WeavePulse.SV.Progressbar.displayPingOnHeavy end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.displayPingOnHeavy = value
                                end,
                            },
                            {
                                type = "checkbox",
                                name = "Show labels and icon",
                                default = false,
                                disabled = function() return not (WeavePulse.SV.Progressbar.showSpell and WeavePulse.SV.Progressbar.showTimeRemaining) or WeavePulse.SV.Progressbar.stopHATracking end,
                                getFunc = function() return WeavePulse.SV.Progressbar.showHeavyDetails end,
                                setFunc = function(value)
                                    WeavePulse.SV.Progressbar.showHeavyDetails = value
                                end,
                            },
                        },
                    },
                },
            },

            {
                type = "submenu",
                name = "Sound",
                disabled = function() return WeavePulse.SV.Progressbar.hide end,
                controls = {
                    {
                        type = "slider",
                        name = "Volume of 'tick' and 'tock'",
                        tooltip = "Adjust volume of tick and tock effects",

                        disabled = function() return not (WeavePulse.SV.Progressbar.soundTickEnabled or WeavePulse.SV.Progressbar.soundTockEnabled) end,
                        min = 0,
                        max = 30,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.tickVolume end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.tickVolume = value
                            for i = 1, math.min(value, 30) do
                                PlaySound(WeavePulse.SV.Progressbar.soundTickEffect)
                            end
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Sound 'tick'",
                        tooltip = "Enable sound 'tick', which marks the middle/beginning of your ability",
                        width = "half",
                        getFunc = function() return WeavePulse.SV.Progressbar.soundTickEnabled end,
                        setFunc = function(state)
                            WeavePulse.SV.Progressbar.soundTickEnabled = state
                            WeavePulse.Progressbar.soundTickPlayed = true
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Sound 'tock'",
                        tooltip = "This sound cue marks the end of an ability",

                        width = "half",
                        getFunc = function() return WeavePulse.SV.Progressbar.soundTockEnabled end,
                        setFunc = function(state)
                            WeavePulse.SV.Progressbar.soundTockEnabled = state
                            WeavePulse.Progressbar.soundTockPlayed = true
                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Sound 'tick' effect",
                        disabled = function()
                            return (not WeavePulse.SV.Progressbar.soundTickEnabled)
                        end,
                        width = "half",
                        choices = sounds,
                        getFunc = function() return WeavePulse.SV.Progressbar.soundTickEffect end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.soundTickEffect = value
                            for i = 1, math.min(WeavePulse.SV.Progressbar.tickVolume, 30) do
                                PlaySound(value)
                            end
                        end,
                    },
                    {
                        type = "dropdown",
                        name = "Sound 'tock' effect",
                        disabled = function()
                            return (not WeavePulse.SV.Progressbar.soundTockEnabled)
                        end,
                        width = "half",
                        choices = sounds,
                        getFunc = function() return WeavePulse.SV.Progressbar.soundTockEffect end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.soundTockEffect = value
                            for i = 1, math.min(WeavePulse.SV.Progressbar.tickVolume, 30) do
                                PlaySound(value)
                            end
                        end,
                    },

                    {
                        type = "slider",
                        name = "Sound 'tick' offset",
                        disabled = function()
                            return not (WeavePulse.SV.Progressbar.soundTickEnabled)
                        end,
                        width = "half",
                        min = -500,
                        max = 500,
                        step =  1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.soundTickOffset end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.soundTickOffset = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Sound 'tock' offset",
                        disabled = function()
                            return not (WeavePulse.SV.Progressbar.soundTockEnabled)
                        end,
                        width = "half",
                        min = -500,
                        max = 500,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.soundTockOffset end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.soundTockOffset = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Play 'tick' at the start of an ability",
                        tooltip = "Toggle having the 'tick' sound at the start or mid ability",
                        disabled = function() return not WeavePulse.SV.Progressbar.soundTickEnabled or WeavePulse.SV.Progressbar.forceTickMSBeforeEnd end,
                        getFunc = function() return not WeavePulse.SV.Progressbar.soundTickMidAbility end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.soundTickMidAbility = not value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Force 'tick' at a certain point",
                        tooltip = "Forces the 'tick' sound a set amount of ms before the ability ends. This is especially useful for abilities with a longer cast/channel time than 1000ms",
                        width = "half",
                        disabled = function() return not WeavePulse.SV.Progressbar.soundTickEnabled end,
                        getFunc = function() return WeavePulse.SV.Progressbar.forceTickMSBeforeEnd end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.forceTickMSBeforeEnd = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Sound 'tick' force offset",
                        disabled = function()
                            return not WeavePulse.SV.Progressbar.forceTickMSBeforeEnd
                        end,
                        default = 500,
                        width = "half",
                        min = 0,
                        max = 1000,
                        step =  1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Progressbar.forceTickTime end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.forceTickTime = value
                        end,
                    },
                    {
                        type = "divider",
                    },
                    {
                        type = "checkbox",
                        name = "Force 'tock' (and 'tick' if allowed)",
                        tooltip = "Forces the 'tock' sound even when you missed a light attack and already have another ability queued, to keep the rythm"
                                    .."\nAlso plays a 'tick' sound if an ability was ended early and GCD went off"
                                    .."and the options enabled allow a 'tick'",
                        disabled = function() return not WeavePulse.SV.Progressbar.soundTockEnabled end,
                        getFunc = function() return WeavePulse.SV.Progressbar.forceSoundTock end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.forceSoundTock = value
                        end,
                    },

                    {
                        type = "checkbox",
                        name = "No sounds on abilities > 1 sec",
                        tooltip = "Prevents 'tick' & 'tock' being queued for easily interruptable abilities i.e. via block cancel",
                        disabled = function() return not (WeavePulse.SV.Progressbar.soundTockEnabled or WeavePulse.SV.Progressbar.soundTickEnabled) end,
                        getFunc = function() return WeavePulse.SV.Progressbar.noSoundOnLongAbilities end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.noSoundOnLongAbilities = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Don't play 'tick' and 'tock' on heavy attacks",
                        tooltip = "Since heavys are easily canceled, this is recommended to avoid annoying sound clutter",
                        disabled = function() return not (WeavePulse.SV.Progressbar.soundTickMidAbility and WeavePulse.SV.Progressbar.soundTickEnabled) end,
                        getFunc = function() return WeavePulse.SV.Progressbar.noTickOnHeavy end,
                        setFunc = function(value)
                            WeavePulse.SV.Progressbar.noTickOnHeavy = value
                        end,
                    },
                    {
                        type = "checkbox",
                        name = "Play sounds ooc",
                        tooltip = "When enabled, will play 'tick' and 'tock' sounds even while out of combat",
                        disabled = function() return not (WeavePulse.SV.Progressbar.showOOC and (WeavePulse.SV.Progressbar.soundTockEnabled or WeavePulse.SV.Progressbar.soundTickEnabled)) end,
                        getFunc = function() return WeavePulse.SV.Progressbar.playSoundsOOC end,
                        setFunc = function(value)
                            WeavePulse.Progressbar.soundTickPlayed = true
                            WeavePulse.Progressbar.soundTockPlayed = true
                            WeavePulse.SV.Progressbar.playSoundsOOC = value
                        end,
                    },
                },
            },

            {
                type = "submenu",
                name = "Ability timer adjusts",
                description = "Adjusts timers on specific skills - This is applied ON TOP of relevant global adjust",
                disabled = function() return WeavePulse.SV.Progressbar.hide end,
                controls = {
                    {
                        type = "dropdown",
                        name = "Currently equipped abilities:",
                        width = "half",
                        choices = self.currentlyEquippedAbilities.list,
                        getFunc = function()
                            if self.menu.curSkillId then
                                local i = self:IsSkillCurrentlyEquipped(self.menu.curSkillId)
                                if self:IsSkillCurrentlyEquipped(self.menu.curSkillId) then

                                    return self.currentlyEquippedAbilities.list[i]
                                end
                                return
                            end
                        end,
                        setFunc = function(selectedSkill)
                            local skillData = self:GetEquippedSkillData(selectedSkill)
                            self.menu.curSkillName = skillData.name
                            self.menu.curSkillId = skillData.id
                            WeavePulse.SV.Progressbar.abilityAdjusts[self.menu.curSkillId] = WeavePulse.SV.Progressbar.abilityAdjusts[self.menu.curSkillId] or 0
                            WeavePulse.debug:Print("Selected skill '"..skillData.name.."'. ID: "..skillData.id)
                            self:UpdateAdjustChoices()
                        end,
                    },
                    {
                        type = "button",
                        name = "Refresh ability list",
                        width = "half",
                        func = function()
                            WeavePulse:BuildListOfCurrentlyEquippedAbilities()
                        end
                    },
                    {
                        type = "editbox",
                        name = "Add skill to adjust",
                        isMultiline = false,
                        warning = "This is case sensitive, so if you don't find your ability it might be because of that",

                        getFunc = function() return self:CropIconFromSkill(Util.Text.CropZOSString(self.menu.curSkillName, "ability")) end,
                        setFunc = function(name) self:FindAbilityAdjust(name) end,
                    },
                    {
                        type = "dropdown",
                        name = "Select skill adjust",
                        choices = self.menu.abilityAdjustChoices,
                        scrollable = true,
                        getFunc = function() return self.menu.abilityAdjustChoices[self:FindSkillInAdjustList(self.menu.curSkillName)] end,
                        setFunc = function(value)
                            self.menu.curSkillName = self:CropIconFromSkill(value)
                            if WeavePulse.SV.debug.enabled then WeavePulse.debug:Print("Current skill is: "..self.menu.curSkillName) end
                            for id, adj in pairs(WeavePulse.SV.Progressbar.abilityAdjusts) do
                                local name = Util.Text.CropZOSString(GetAbilityName(id), "ability")
                                if name == self:CropIconFromSkill(value) then
                                    self.menu.curSkillId = id
                                    WeavePulse.debug:Print("Selected skill '"..name.."'. ID: "..id)
                                end
                            end
                        end
                    },
                    {
                        type = "slider",
                        name = "Modify skill adjust (in ms)",
                        min = -MAX_ADJUST,
                        max = MAX_ADJUST,
                        step = 1,
                        decimals = 0,
                        getFunc = function()

                            return WeavePulse.SV.Progressbar.abilityAdjusts[self.menu.curSkillId] or 0
                        end,
                        setFunc = function(value)

                                WeavePulse.SV.Progressbar.abilityAdjusts[self.menu.curSkillId] = value

                        end
                    },
                    {
                        type = "button",
                        name = "Remove skill adjust",
                        func = function()
                              WeavePulse.debug:Print("Removing skill '"..self.menu.curSkillName.."'. ID: "..self.menu.curSkillId)
                            WeavePulse.SV.Progressbar.abilityAdjusts[self.menu.curSkillId] = nil
                            self:UpdateAdjustChoices()
                            self.menu.curSkillName = self:CropIconFromSkill(self.menu.abilityAdjustChoices[1])
                            for id, adj in pairs(WeavePulse.SV.Progressbar.abilityAdjusts) do
                                if Util.Text.CropZOSString(GetAbilityName(id), "ability") == self.curSkillName then
                                    self.menu.curSkillId = id
                                end
                            end
                        end
                    },
                },
            },
        },
        ["Resources"] = {

            {
                type = "header",
                name = "Resources",
                tooltip = "To keep track of your resources on a different bar",
            },
            {
                type = "checkbox",
                name = "Unlock resource bar",
                tooltip = "Reposition / resize resourcebar by dragging center / edges.",
                disabled = function () return WeavePulse.SV.Resources.anchorResourcesToProgressbar or self.Resources.showSample end,
                getFunc = function() return self.Resources.frame.IsUnlocked() end,
                setFunc = function(value)
                    self.Resources.frame:SetUnlocked(value)
                    if value then
                        self.Resources.frame:SetDrawTier(DT_HIGH)
                        self.Resources.frame:SetHidden(false)
                    else
                        self.Resources.frame:SetDrawTier(DT_LOW)
                        self.Resources.frame:SetHidden(true)
                    end
                end,
            },
            {
                type = "checkbox",
                name = "Anchor resource tracker atop the progressbar",
                tooltip = "If turned off, resourcebar can be dragged or resized independently",
                warning = "Turning this off will automatically resize resourcebar to fit your GCD bar!",
                disabled = function()
                    return not (WeavePulse.SV.Resources.showUltimate or WeavePulse.SV.Resources.showStamina or WeavePulse.SV.Resources.showMagicka or WeavePulse.SV.Resources.showHealth) or self.Resources.frame.IsUnlocked()
                end,
                getFunc = function() return WeavePulse.SV.Resources.anchorResourcesToProgressbar end,
                setFunc = function(value)
                    WeavePulse.SV.Resources.anchorResourcesToProgressbar = value
                    self.Progressbar.UI.Size()
                    if self.Resources.showSample then
                        self.Progressbar.UI.ResourcesPosition("Sample")
                    end
                end,
            },
            {
                type = "checkbox",
                name = "Hide resource tracker in PVP Zones",
                tooltip = "Hides resource tracker in PVPZones to keep UI clean",
                disabled = function()
                    return not (WeavePulse.SV.Resources.showUltimate or WeavePulse.SV.Resources.showStamina or WeavePulse.SV.Resources.showMagicka or WeavePulse.SV.Resources.showHealth)
                end,
                getFunc = function() return WeavePulse.SV.Resources.hideInPVP end,
                setFunc = function(value)
                    WeavePulse.SV.Resources.hideInPVP = value
                end,
            },
            {
                type = "checkbox",
                name = "How does it look?",
                tooltip = "Shows resourcebar at the right of the screen to check your settings. This resourcebar is not movable!",
                warning = "This temporarily disables the Unlock function! Deactivate again to be able to unlock the tracker. This resets, if you leave the menu.",
                default = false,
                disabled = function()
                    return not (WeavePulse.SV.Resources.showUltimate or WeavePulse.SV.Resources.showStamina or WeavePulse.SV.Resources.showMagicka or WeavePulse.SV.Resources.showHealth)
                end,
                getFunc = function() return self.Resources.showSample end,
                setFunc = function(value)
                    self.Resources.showSample = value
                    if value then
                        self.Progressbar.UI.ResourcesPosition("Sample")
                        self.Resources.frame:SetHidden(false)
                    else
                        self.Progressbar.UI.ResourcesPosition("UI")
                        self.Progressbar.UI.HiddenStates()
                    end
                end,
            },
            {
                type = "checkbox",
                name = "Unlock execute reminder",
                tooltip = "Sets the execute reminder movable and resizeable",
                default = false,
                disabled = function()
                    return not WeavePulse.SV.Resources.showExecuteReminder
                end,
                getFunc = function() return WeavePulse.SV.Resources.unlockExecuteReminder end,
                setFunc = function(value)
                    WeavePulse.SV.Resources.unlockExecuteReminder = value
                    self.Resources.executeFrame:SetUnlocked(value)
                    self.Resources.executeFrame:SetHidden(not value)
                    self.Resources.executeLabel:SetHidden(not value)
                end,
            },
            {
                type = "header",
                name = "Configuration",
            },
            {
                type = "checkbox",
                name = "Always show own resources",
                tooltip = "Toggle show own resources. If this is off, your resources will only be shown, when targeting units or being in combat",
                disabled = function()
                    return not (WeavePulse.SV.Resources.showUltimate or WeavePulse.SV.Resources.showStamina or WeavePulse.SV.Resources.showMagicka or WeavePulse.SV.Resources.showHealth)
                end,
                getFunc = function() return WeavePulse.SV.Resources.showResources end,
                setFunc = function(value) WeavePulse.SV.Resources.showResources = value end,
            },
            {
                type = "checkbox",
                name = "Automatically show execute reminder",
                tooltip = "Shows a little reminder on screen, when using health highlighting or equipping an execute ability and hitting the targets corresponding execute threshold",
                getFunc = function() return WeavePulse.SV.Resources.showExecuteReminder end,
                setFunc = function(value)
                    WeavePulse.SV.Resources.showExecuteReminder = value
                    if value then WeavePulse:CalculateExecuteThreshold() end
                end,
            },
            {
                type = "dropdown",
                name = "Execute reminder min target difficulty",
                tooltip = "Only shows reminder if target difficulty is higher than selected",
                choices = difficulty,
                default = difficulty[2],
                disabled = function() return not WeavePulse.SV.Resources.showExecuteReminder end,
                getFunc = function() return difficulty[WeavePulse.SV.Resources.executeDifficulty] end,
                setFunc = function(value)
                    for i, str in ipairs(difficulty) do
                        if str == value then
                            WeavePulse.SV.Resources.executeDifficulty = i
                            break
                        end
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Exectute reminder Color",
                tooltip = "Color of your ultimate label",
                disabled = function()
                    return (not WeavePulse.SV.Resources.showExecuteReminder)
                end,
                getFunc = function() return unpack(WeavePulse.SV.Resources.executeColor) end,
                setFunc = function(r, g, b, a)
                    WeavePulse.SV.Resources.executeColor = {r, g, b, a}
                    WeavePulse.Resources.executeLabel:SetColor(r,g,b,a)
                end,
            },
            {
                type = "checkbox",
                name = "Show stam/mag when using Coral/MK/Bahsei",
                tooltip = "Will autmatically show you stam/mag when at least one of the sets is active",

                disabled = function() return not WeavePulse.LSD end,
                getFunc = function() return WeavePulse.SV.Resources.coralBahsei end,
                setFunc = function(value)
                    WeavePulse.SV.Resources.coralBahsei = value
                    if value and not WeavePulse.coralBahseiRegistered then
                        self:RegisterCoralBahsei()
                    elseif not value and WeavePulse.coralBahseiRegistered then
                        self:UnregisterCoralBahsei()
                    end
                end,
            },
            {
                type = "submenu",
                name = "Ultimate",
                controls = {
                    {
                        type = "checkbox",
                        name = "Show Ultimate",
                        tooltip = "Toggle show ultimate above cast bar",
                        getFunc = function() return WeavePulse.SV.Resources.showUltimate end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.showUltimate = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Ultimate Label Size",
                        tooltip = "Set the size of the Ultimate label",
                        disabled = function()
                            return (not WeavePulse.SV.Resources.showUltimate)
                        end,
                        min = 0,
                        max = WeavePulse.SV.Resources.height,
                        step = 1,
                        decimals = 0,
                        default = WeavePulse.SV.Resources.ultSize,
                        getFunc = function() return WeavePulse.SV.Resources.ultSize end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.ultSize = value
                            self.Progressbar.UI.Fonts()

                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Ultimate Label Color",
                        tooltip = "Color of your ultimate label",
                        disabled = function()
                            return (not WeavePulse.SV.Resources.showUltimate)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Resources.ultColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Resources.ultColor = {r, g, b, a}
                            self.Progressbar.UI.LabelColors()

                        end,
                    },
                },
            },
            {
                type = "submenu",
                name = "|c00cc4eStamina|r",
                controls = {
                    {
                        type = "checkbox",
                        name = "Show Stamina",
                        tooltip = "Toggle show stamina above cast bar",
                        getFunc = function() return WeavePulse.SV.Resources.showStamina end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.showStamina = value
                            self.Progressbar.UI.Anchors()
                        end,
                    },
                    {
                        type = "slider",
                        name = "Stamina Label Size",
                        tooltip = "Set the size of the Stamina label",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.showStamina or WeavePulse.SV.Resources.coralBahsei)
                        end,
                        min = 0,
                        max = WeavePulse.SV.Resources.height/2,
                        step = 1,
                        decimals = 0,
                        default = WeavePulse.SV.Resources.stamSize,
                        getFunc = function() return WeavePulse.SV.Resources.stamSize end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.stamSize = value
                            self.Progressbar.UI.Fonts()

                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Stamina Label Color",
                        tooltip = "Color of your stamina label",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.showStamina or WeavePulse.SV.Resources.coralBahsei)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Resources.stamColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Resources.stamColor = {r, g, b, a}
                            self.Progressbar.UI.LabelColors()

                        end,
                    },
                    {	type = "divider"},
                    {
                        type = "checkbox",
                        name = "Highlight stamina percentage",
                        tooltip = "Highlights stamina percentage when in hits a certain threshold",
                        getFunc = function() return WeavePulse.SV.Resources.highlightStam end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.highlightStam = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Highlight threshold",
                        tooltip = "Set the threshold for stamina highlighting (Set 0% for no highlight)",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.highlightStam and WeavePulse.SV.Resources.coralBahsei)
                        end,
                        min = 0,
                        max = 100,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Resources.stamHighlightThreshold end,
                        setFunc = function(value) WeavePulse.SV.Resources.stamHighlightThreshold = value end,
                    },
                    {
                        type = "colorpicker",
                        name = "Stamina Highlight Color",
                        tooltip = "Highlighting color of stamina label",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.stamHighlightThreshold ~= 0 and WeavePulse.SV.Resources.highlightStam)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Resources.stamHighligtColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Resources.stamHighligtColor = {r, g, b, a}

                        end,
                    },
                },
            },
            {
                type = "submenu",
                name = "|c0055ffMagicka|r",
                controls = {
                    {
                        type = "checkbox",
                        name = "Show Magicka",
                        tooltip = "Toggle show magicka above cast bar",
                        getFunc = function() return WeavePulse.SV.Resources.showMagicka end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.showMagicka = value
                            self.Progressbar.UI.Anchors()

                        end,
                    },
                    {
                        type = "slider",
                        name = "Magicka Label Size",
                        tooltip = "Set the size of the Magicka label",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.showMagicka or WeavePulse.SV.Resources.coralBahsei)
                        end,
                        min = 0,
                        max = WeavePulse.SV.Resources.height/2,
                        step = 1,
                        decimals = 0,
                        default = WeavePulse.SV.Resources.magSize,
                        getFunc = function() return WeavePulse.SV.Resources.magSize end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.magSize = value
                            self.Progressbar.UI.Fonts()

                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Magicka Label Color",
                        tooltip = "Color of your magicka label",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.showMagicka or WeavePulse.SV.Resources.coralBahsei)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Resources.magColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Resources.magColor = {r, g, b, a}
                            self.Progressbar.UI.LabelColors()

                        end,
                    },
                    {	type = "divider"},
                    {
                        type = "checkbox",
                        name = "Highlight magicka percentage",
                        tooltip = "Highlights magicka percentage when in hits a certain threshold",
                        getFunc = function() return WeavePulse.SV.Resources.highlightMag end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.highlightMag = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Highlight threshold",
                        tooltip = "Set the threshold for magicka highlighting (Set 0% for no highlight)",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.highlightMag and WeavePulse.SV.Resources.coralBahsei)
                        end,
                        min = 0,
                        max = 100,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Resources.magHighlightThreshold end,
                        setFunc = function(value) WeavePulse.SV.Resources.magHighlightThreshold = value end,
                    },
                    {
                        type = "colorpicker",
                        name = "Magicka Highlight Color",
                        tooltip = "Highlighting color of magicka label",
                        disabled = function()
                            return not (WeavePulse.SV.Resources.magHighlightThreshold ~= 0 and WeavePulse.SV.Resources.highlightMag)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Resources.magHighligtColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Resources.magHighligtColor = {r, g, b, a}

                        end,
                    },
                },
            },
            {
                type = "submenu",
                name = "|cc40000Health|r",
                controls = {
                    {
                        type = "checkbox",
                        name = "Show Target Health",
                        tooltip = "Toggle show target health above cast bar",
                        getFunc = function() return WeavePulse.SV.Resources.showHealth end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.showHealth = value
                        end,
                    },
                    {
                        type = "slider",
                        name = "Health Label Size",
                        tooltip = "Set the size of the Health label",
                        disabled = function()
                            return (not WeavePulse.SV.Resources.showHealth)
                        end,
                        min = 0,
                        max = WeavePulse.SV.Resources.height,
                        step = 1,
                        decimals = 0,
                        default = WeavePulse.SV.Resources.healthSize,
                        getFunc = function() return WeavePulse.SV.Resources.healthSize end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.healthSize = value
                            self.Progressbar.UI.Fonts()

                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Health Label Color",
                        tooltip = "Color of target health label",
                        disabled = function()
                            return (not WeavePulse.SV.Resources.showHealth)
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Resources.healthColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Resources.healthColor = {r, g, b, a}
                            self.Progressbar.UI.LabelColors()

                        end,
                    },
                    {	type = "divider"},
                    {
                        type = "slider",
                        name = "Target Health execute highlight threshold",
                        tooltip = "Set the threshold for target health highlighting (Set 0% for no highlight)",
                        disabled = function()
                            return (not WeavePulse.SV.Resources.showHealth)
                        end,
                        min = 0,
                        max = 100,
                        step = 1,
                        decimals = 0,
                        getFunc = function() return WeavePulse.SV.Resources.hpHighlightThreshold end,
                        setFunc = function(value)
                            WeavePulse.SV.Resources.hpHighlightThreshold = value
                            if WeavePulse.SV.Resources.showExecuteReminder then
                                WeavePulse:CalculateExecuteThreshold()
                            end
                        end,
                    },
                    {
                        type = "colorpicker",
                        name = "Health Highlight Color",
                        tooltip = "Highlighting color of target health label",
                        disabled = function()
                            return (not (WeavePulse.SV.Resources.hpHighlightThreshold ~= 0 and WeavePulse.SV.Resources.showHealth))
                        end,
                        getFunc = function() return unpack(WeavePulse.SV.Resources.healthHighligtColor) end,
                        setFunc = function(r, g, b, a)
                            WeavePulse.SV.Resources.healthHighligtColor = {r, g, b, a}
                            self.Progressbar.UI.LabelColors()

                        end,
                    },
                },
            },
            {
                type = "checkbox",
                name = "Attach Target Health to reticle",
                tooltip = "Attach Target Health to side of reticle",
                disabled = function()
                    return (not WeavePulse.SV.Resources.showHealth)
                end,
                getFunc = function() return WeavePulse.SV.Resources.reticleHp end,
                setFunc = function(value)
                    WeavePulse.SV.Resources.reticleHp = value
                    self.Progressbar.UI.Anchors()

                end,
            },
            {
                type = "checkbox",
                name = "Attach Player Mag and Stam to reticle",
                tooltip = "Attach Player Mag and Stam to side of reticle",
                disabled = function()
                    return not (WeavePulse.SV.Resources.showMagicka or WeavePulse.SV.Resources.showStamina or WeavePulse.SV.Resources.coralBahsei)
                end,
                getFunc = function() return WeavePulse.SV.Resources.reticleMagStam end,
                setFunc = function(value)
                    WeavePulse.SV.Resources.reticleMagStam = value
                    self.Progressbar.UI.Anchors()

                end,
            },
            {
                type = "checkbox",
                name = "Show resources when targeting guard",
                tooltip = "Show resources when targeting guard",
                getFunc = function() return WeavePulse.SV.Resources.showResourcesForGuard end,
                setFunc = function(value) WeavePulse.SV.Resources.showResourcesForGuard = value end,
            },
        },
        ["StackTracker"] = {

            {
                type = "header",
                name = "Position",
            },
            {	type = "checkbox",
                name = "Unlock Trackers",
                tooltip = "Move stack trackers",

                disabled = function() return not StackTracker:TrackerIsActive() end,
                getFunc = function() return WeavePulse.SV.StackTracker.isUnlocked end,
                setFunc = function(value)
                    WeavePulse.SV.StackTracker.isUnlocked = value
                    for skill, _ in pairs(StackTracker.SKILL_ATTRIBUTES) do
                        if StackTracker.UI[skill] then
                            StackTracker.UI[skill].stacksWindow:SetMovable(value)
                            StackTracker.UI[skill].stacksWindow:SetHidden(not value)
                            StackTracker.UI[skill].Hide(not value)
                            if value then
                                StackTracker.UI[skill].FadeScenes("Sample")
                                if StackTracker.UI[skill].indicator.timer then
                                    StackTracker.UI[skill].indicator.timer:SetHidden(not WeavePulse.SV.StackTracker[skill].showTimer)
                                    StackTracker.UI[skill].indicator.timer:SetText("2.5")
                                end
                                if StackTracker.UI[skill].indicator.timerBarBackdrop then
                                    StackTracker.UI[skill].indicator.timerBar:SetHidden(not WeavePulse.SV.StackTracker[skill].showTimerBar)
                                    StackTracker.UI[skill].indicator.timerBarBackdrop:SetHidden(not WeavePulse.SV.StackTracker[skill].showTimerBar)
                                    StackTracker.UI[skill].indicator.timerBarGloss:SetHidden(not WeavePulse.SV.StackTracker[skill].showTimerBar)
                                    StackTracker.UI[skill].indicator.timerBar:SetValue(0.5)
                                    StackTracker.UI[skill].indicator.timerBarTimer:SetHidden(not WeavePulse.SV.StackTracker[skill].showTimerBar or WeavePulse.SV.StackTracker[skill].showTimer)
                                    StackTracker.UI[skill].indicator.timerBarTimer:SetText("2.5")
                                end
                            else
                                StackTracker.UI[skill].FadeScenes("NoSample")
                                if StackTracker.UI[skill].indicator.timer then StackTracker.UI[skill].indicator.timer:SetHidden(true) end
                                if StackTracker.UI[skill].indicator.timerBarBackdrop then
                                    StackTracker.UI[skill].indicator.timerBar:SetHidden(true)
                                    StackTracker.UI[skill].indicator.timerBarBackdrop:SetHidden(true)
                                    StackTracker.UI[skill].indicator.timerBarGloss:SetHidden(true)
                                    StackTracker.UI[skill].indicator.timerBarTimer:SetHidden(true)
                                end
                            end
                        end
                    end
                end,
            },
            {
                type = "checkbox",
                name = "Show only in combat",
                default = false,
                getFunc = function() return WeavePulse.SV.StackTracker.onlyInCombat end,
                setFunc = function(value)
                    WeavePulse.SV.StackTracker.onlyInCombat = value
                    for skill, stacks in pairs(WeavePulse.StackTracker.stacks) do

                        WeavePulse.StackTracker:ChangeStackCount(skill, stacks)
                    end
                end,
            },

            {
                type = "header",
                name = "Stacks to track",
            },
        },
        ["LATracker"] = {

            {
                type = "header",
                name = "General Settings",
                tooltip = "Lets you track your light attacks, to better analyze your parses",
            },
            {
                type = "checkbox",
                name = "Hide la tracker in PVP Zones",
                tooltip = "Hides la tracker in PVPZones to keep UI clean",
                default = true,
                disabled = function()
                    return WeavePulse.SV.LATracker.choice == "Nothing"
                end,
                getFunc = function() return WeavePulse.SV.LATracker.hideInPVP end,
                setFunc = function(value)
                    WeavePulse.SV.LATracker.hideInPVP = value
                    LATracker:DisplayText()
                end,
            },
            {	type = "checkbox",
                name = "Unlock light attack tracker",
                tooltip = "Enable moving the tracker label",
                default = false,
                getFunc = function() return WeavePulse.SV.LATracker.isUnlocked end,
                setFunc = function(value)
                    WeavePulse.SV.LATracker.isUnlocked = value
                    LATracker.frame:SetUnlocked(value)
                    if value then
                        LATracker.frame:SetDrawTier(DT_HIGH)
                        LATracker.frame:SetHidden(false)
                        LATracker:DisplayText()
                    else
                        LATracker.frame:SetDrawTier(DT_LOW)
                        LATracker.frame:SetHidden(true)
                        LATracker.label:SetHidden(true)
                    end
                end,
            },
            {	type = "dropdown",
                name = "What to track",
                tooltip = "Define whether tracker should be displaying light attacks per second, time between light attacks, or nothing at all",
                choices = LATrackerChoices,
                default = "Nothing",
                getFunc = function() return WeavePulse.SV.LATracker.choice end,
                setFunc = function(value)
                    WeavePulse.SV.LATracker.choice = value
                    LATracker:DisplayText()
                end,
            },
            {	type = "slider",
                name = "Time until tracker hides after a fight",
                tooltip = "This is the amount of seconds the tracker will keep displaying your values after a fight is finished. If set to '0' tracker will always be visible.",
                default = 15,
                min = 0,
                max = 30,
                step = 1,
                decimals = 0,
                getFunc = function() return WeavePulse.SV.LATracker.timeTilHiding end,
                setFunc = function(value)
                    WeavePulse.SV.LATracker.timeTilHiding = value
                    LATracker:DisplayText()
                end,
            },
            {	type = "checkbox",
                name = "Show LA record after fight",
                tooltip = "Gives you a small record of duration of the fight, la/s and the total amount of light attacks",
                default = false,
                getFunc = function() return WeavePulse.SV.LATracker.showLALogAfterFight end,
                setFunc = function(value)
                    WeavePulse.SV.LATracker.showLALogAfterFight = value
                end,
            },
        },
    }

    CreateStacksSettings()
    self.menu.panels = {}
    for panelName, panelOptions in pairs(self.menu.metadata) do
        self.menu.panels[panelName] = LAM:RegisterAddonPanel(self.name..panelName.."Options", self.menu.metadata[panelName])
        LAM:RegisterOptionControls(self.name..panelName.."Options", self.menu.options[panelName])
    end

end
