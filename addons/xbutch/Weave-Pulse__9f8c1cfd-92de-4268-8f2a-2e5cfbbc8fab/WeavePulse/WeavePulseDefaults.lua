-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: CMMiscellaneous.lua. See third-party/UPSTREAM.md for modifications.

WeavePulse.StackTracker = WeavePulse.StackTracker or {}
WeavePulse.Resources = WeavePulse.Resources or {}
WeavePulse.menu = WeavePulse.menu or {}
local Util = WeavePulse.Util

WeavePulse.DEFAULT_SAVED_VARS = {
    ["version"] = 2,
    ["lastAddOnVersion"] = 0,
    ["showBetaMessage"] = true,
    ["automaticSVCleanup"] = {
        ["enabled"] = false,
        ["lastCleanup"] = {
            ["year"] = 0,
            ["month"] = 0,
            ["day"] = 0,
        },
    },
    ["global"] = true,
    ["Progressbar"] = {
        ["hideProgressbar"] = false,
        ["hideCMInPVP"] = false,
        ["xOffset"] = (GuiRoot:GetWidth() - 303) / 2,
        ["yOffset"] = (GuiRoot:GetHeight() - 30) / 2,
        ["width"] = 303,
        ["height"] = 30,
        ["dontHide"] = false,
        ["dontShowPing"] = false,
        ["lastBackgroundColor"] = { 0, 0, 0, 0.5 },
        ["backgroundColor"] = { 0, 0, 0, 0.5 },
        ["progressColor"] = { 1, 0.84, 0.24, 0.63 },
        ["pingColor"] = { 1, 0, 0, 0.63 },
        ["channelColor"] = { 1, 0, 1, 0.63},
        ["colorCache"] = { 1, 0.84, 0.24, 0.63},
        ["changeOnChanneled"] = false,
        ["gcdAdjust"] = 0,
        ["barAlign"] = "Center",
        ["labelFont"] = "CHAT_FONT",
        ["fontStyle"] = "outline",
        ["trackGCD"] = false,
        ["displayPingOnHeavy"] = true,
        ["showHeavyLabels"] = false,
        ["spellSize"] = 25,
        ["globalHeavyAdjust"] = 25,
        ["globalAbilityAdjust"] = 25,
        ["abilityAdjusts"] = { },
        ["showSpell"] = true,
        ["showTimeRemaining"] = true,
        ["soundTickEnabled"] = false,
        ["tickVolume"] = 100,
        ["soundTickEffect"] = "Justice_PickpocketFailed",
        ["soundTickOffset"] = 200,
        ["soundTockEnabled"] = false,
        ["soundTockEffect"] = "Dialog_Decline",
        ["soundTockOffset"] = 300,
        ["playSoundsOOC"] = false,
        ["forceSoundTock"] = true,
        ["stopHATracking"] = false,
        ["makeItFancy"] = false,
        ["maxLatency"] = 150,
        ["showPingOnGCD"] = true,
        ["expandDynamically"] = false,
        ["moveIconDynamically"] = true,
        ["dynamicExpansionMultiplyer"] = 1,
        ["forceTickMSBeforeEnd"] = false,
        ["forceTickTime"] = 500,
        ["noSoundOnLongAbilities"] = false,

    },
    ["Resources"] = {
        ["anchorResourcesToProgressbar"] = true,
        ["hideResourcesInPVP"] = false,
        ["xOffset"] = (GuiRoot:GetWidth() - 303) / 2,
        ["yOffset"] = (GuiRoot:GetHeight() - 80) / 2,
        ["width"] = 303,
        ["height"] = 50,
        ["showResources"] = false,
        ["coralBahsei"] = false,
        ["showUltimate"] = true,
        ["showStamina"] = true,
        ["showMagicka"] = true,
        ["showHealth"] = true,
        ["highlightMag"] = false,
        ["highlightStam"] = false,
        ["magHighlightThreshold"] = 0,
        ["stamHighlightThreshold"] = 0,
        ["ultColor"] = {1, 1, 1, 1},
        ["magColor"] = {0, 0.5, 1, 1},
        ["stamColor"] = {0, 0.8, 0.3, 1},
        ["healthColor"] = {0.8, 0, 0, 1},
        ["healthHighligtColor"] = {1, 1, 1, 1},
        ["magHighligtColor"] = {1, 1, 1, 1},
        ["stamHighligtColor"] = {1, 1, 1, 1},
        ["stamSize"] = 21,
        ["magSize"] = 21,
        ["ultSize"] = 40,
        ["healthSize"] = 35,
        ["showResourcesForGuard"] = false,
        ["hpHighlightThreshold"] = 25,
        ["reticleHp"] = false,
        ["unlockExecuteReminder"] = false,
        ["showExecuteReminder"] = false,
        ["executeDifficulty"] = 1,
        ["executeColor"] = {0.8, 0, 0, 1},
        ["executeX"] = (GuiRoot:GetWidth() - 250) / 2,
        ["executeY"] = (GuiRoot:GetHeight() - 50) / 2,
        ["executeWidth"] = 303,
        ["executeHeight"] = 50,
    },
    ["StackTracker"] = {
        ["isUnlocked"] = false,
    },
    ["LATracker"] = {
        ["xOffset"] = GuiRoot:GetWidth()/2,
        ["yOffset"] = GuiRoot:GetHeight()/2,
        ["width"] = 200,
        ["height"] = 50,
        ["choice"] = "Nothing",
        ["timeTilHiding"] = 15,
    },
    ["debug"] = {
        ["enabled"] = false,
        ["printTimestamps"] = false,
        ["triggers"] = false,
        ["triggerTimer"] = 170,
        ["currentEvent"] = false,
        ["eventCancel"] = false,
        ["abilityUsed"] = false,
        ["abilityWhitelist"] = {
            ["list"] = {},
            ["ids"] = {},
        },
        ["tickTock"] = false,
    },
}

local frameTexture = "/esoui/art/actionbar/abilityframe64_up.dds"
WeavePulse.menu.CONTROLS = {
    ["progressbar"] = {
        {
            ["Name"] = "Dodgeroll",
            ["Icon"] = "/esoui/art/icons/ability_rogue_035.dds",
            ["Dimensions"] = 35,
            ["Offset"] = -25,
            ["SavedVars"] = "trackRolldodge",
        },
        {
            ["Name"] = "Mounting/Dismounting",
            ["Dimensions"] = 45,
            ["Offset"] = -20,
            ["SavedVars"] = "trackMounting",
        },
        {
            ["Name"] = "Assistants and companions",
            ["Icon"] = "/esoui/art/icons/assistant_ezabibanker.dds",
            ["Dimensions"] = 45,
            ["Offset"] = -20,
            ["SavedVars"] = "trackCollectibles",
        },
        {
            ["Name"] = "Usage of items",
            ["Icon"] = "/esoui/art/tribute/tributeendofgamereward_overflow.dds",
            ["Dimensions"] = 35,
            ["Offset"] = -25,
            ["SavedVars"] = "trackItems",
        },
        {
            ["Name"] = "Synergies",
            ["Icon"] = "/esoui/art/icons/achievement_u23_skillmaster_darkbrotherhood.dds",
            ["Dimensions"] = 35,
            ["Offset"] = -25,
            ["SavedVars"] = "trackSynergies",
        },
        {
            ["Name"] = "Breaking free",
            ["Icon"] = "/esoui/art/icons/ability_debuff_stun.dds",
            ["Dimensions"] = 35,
            ["Offset"] = -25,
            ["SavedVars"] = "trackBreakingFree",
        },
    },
    ["stackTracker"] = {
        ["MW"] = {
            ["Name"] = "Track molten whip stacks",
            ["subName"] = "Molten whip",

            ["icon"] = "/esoui/art/icons/ability_dragonknight_001_b.dds",
        },
        ["BA"] = {
            ["Name"] = "Track bound armaments stacks",
            ["subName"] = "Bound armaments",

            ["icon"] = "/esoui/art/icons/ability_sorcerer_bound_armaments.dds",
        },
        ["GF"] = {
            ["Name"] = "Track stacks of grimm focus and its morphs",
            ["subName"] = "Grimm focus (and morphs)",

            ["icon"] = "/esoui/art/icons/ability_nightblade_005.dds",
        },
        ["Crux"] = {
            ["Name"] = "Track crux stacks",
            ["subName"] = "Crux",

            ["icon"] = "/esoui/art/icons/class_buff_arcanist_crux.dds",
        },
        ["FS"] = {
            ["Name"] = "Track stacks of flame skull and its morphs",
            ["subName"] = "Flame skull (and morphs)",

            ["icon"] = "/esoui/art/icons/ability_necromancer_001.dds",
        },
        ["FI"] = {
            ["Name"] = "Track fetcher infection stack",
            ["subName"] = "Fetcher infection",

            ["icon"] = "/esoui/art/icons/ability_warden_014.dds",
        },
    },
}

WeavePulse.StackTracker.SKILL_ATTRIBUTES = {
    ["Crux"] = {
        ["iMax"] = 3,
        ["activation"] = 3,
        ["duration"] = true,
        ["graphic"] = "/esoui/art/icons/class_buff_arcanist_crux.dds",
        ["highlight"] = {0,1,0,0.2},
        ["highlightAnimation"] = {0.8,1,0.8,0.8},
        ["id"] = 184220,
        ["skillLineId"] = {218,219,220,315,316,317},

    },
    ["MW"] = {
        ["iMax"] = 3,
        ["activation"] = 3,
        ["duration"] = true,
        ["graphic"] = "/esoui/art/icons/ability_dragonknight_001_b.dds",
        ["highlight"] = {1,0,0,0.2},
        ["highlightAnimation"] = {1,0.8,0.8,0.8},
        ["id"] = { ["buff"] = 122658, ["ability"] = 20805,},
        ["skillLineId"] = {35,297},

    },
    ["BA"] = {
        ["iMax"] = 4,
        ["multiplier"] = 2,
        ["activation"] = 4,
        ["duration"] = true,
        ["graphic"] = "/esoui/art/icons/ability_sorcerer_bound_armaments.dds",
        ["highlight"] = {0,0,1,0.2},
        ["highlightAnimation"] = {0.8,0.8,1,0.8},
        ["id"] = { ["buff"] = 203447, ["ability"] = 24165,},
        ["skillLineId"] = {42,306},

    },
    ["GF"] = {
        ["iMax"] = 5,
        ["multiplier"] = 2,
        ["activation"] = 5,
        ["icon"] = {
            ["GF"] = "/esoui/art/icons/ability_nightblade_005.dds",
            ["RF"] = "/esoui/art/icons/ability_nightblade_005_a.dds",
            ["MR"] = "/esoui/art/icons/ability_nightblade_005_b.dds",
        },
        ["graphic"] = "",
        ["highlight"] = {1,0,0,0.2},
        ["highlightAnimation"] = {1,0.8,0.8,0.8},
        ["id"] = {
            ["GF"] = { ["buff"] = 122585, ["ability"] = 61902,},
            ["MR"] = { ["buff"] = 122586, ["ability"] = 61919,},
            ["RF"] = { ["buff"] = 122587, ["ability"] = 61927,},
        },
        ["skillLineId"] = {38,300},

    },
    ["FS"] = {
        ["iMax"] = 2,
        ["activation"] = 2,
        ["icon"] = {
            ["FS"] = "/esoui/art/icons/ability_necromancer_001.dds",
            ["RS"] = "/esoui/art/icons/ability_necromancer_001_b.dds",
            ["VS"] = "/esoui/art/icons/ability_necromancer_001_a.dds",
        },
        ["graphic"] = "",
        ["highlight"] = {0.3,0,1,0.2},
        ["highlightAnimation"] = {0.9,0.8,1,0.8},
        ["id"] = {
            ["FS"] = { ["buff"] = 114131, ["ability"] = {
            [1] = 114108, [2] = 123683, [3] = 123685
            }},
            ["RS"] = { ["buff"] = 117638, ["ability"] = {
            [1] = 117637, [2] = 123718, [3] = 123719
            }},
            ["VS"] = { ["buff"] = 117625, ["ability"] = {
            [1] = 117624, [2] = 123699, [3] = 123704
            }},
        },
        ["skillLineId"] = {131,312},

    },
    ["FI"] = {
        ["iMax"] = 1,
        ["activation"] = 1,
        ["graphic"] = "/esoui/art/icons/ability_warden_014_a.dds",
        ["highlight"] = {0,1,0,0.2},
        ["highlightAnimation"] = {0.8,1,0.8,0.8},
        ["id"] = { ["buff"] = 91416, ["ability"] = 86027,},
        ["skillLineId"] = {127,309},

    },
}

WeavePulse.StackTracker.ALL_IDS = {}
do
    for skill, entry in pairs(WeavePulse.StackTracker.SKILL_ATTRIBUTES) do
        if skill ~= "Crux" then
            if entry.id.ability then
                WeavePulse.StackTracker.ALL_IDS[entry.id.ability] = skill
            else
                for morph, ids in pairs(entry.id) do
                    if type(ids.ability) == "table" then
                        for i in ipairs(ids.ability) do
                            WeavePulse.StackTracker.ALL_IDS[ids.ability[i]] = skill
                        end
                    else
                        WeavePulse.StackTracker.ALL_IDS[ids.ability] = skill
                    end
                end
            end
        end
    end
end

WeavePulse.StackTracker.CRUX_SKILL_LINE_IDS = {}
do
    for _, skillLineId in ipairs(WeavePulse.StackTracker.SKILL_ATTRIBUTES.Crux.skillLineId) do
        WeavePulse.StackTracker.CRUX_SKILL_LINE_IDS[skillLineId] = true
    end
end

WeavePulse.StackTracker.ABILITIES_USING_OR_GENERATING_CRUX = {[182977] = true, [183006] = true, [183047] = true, [183122] = true, [183165] = true, [183241] = true, [183261] = true, [183430] = true, [183537] = true, [183542] = true, [185794] = true, [185803] = true, [185805] = true, [185823] = true, [185842] = true, [185894] = true, [185901] = true, [185908] = true, [186189] = true, [186191] = true, [186193] = true, [186200] = true, [186207] = true, [186209] = true, [186211] = true, [186220] = true, [186366] = true, [186452] = true, [186477] = true, [186531] = true, [188658] = true, [188780] = true, [188787] = true, [193331] = true, [193397] = true, [193398] = true, [194873] = true, [194875] = true, [198282] = true, [198288] = true, [198292] = true, [198309] = true, [198330] = true, [198537] = true, [198564] = true, [198567] = true, [238169] = true, [238174] = true, [238191] = true, [238238] = true, [238249] = true, [238429] = true, [238447] = true, [238482] = true, [238545] = true, [247126] = true}

WeavePulse.StackTracker.CLASS = {
    [1] = "DK",
    [2] = "SORC",
    [3] = "NB",
    [4] = "DEN",
    [5] = "CRO",
    [6] = "PLAR",
    [117] = "ARC",
}

WeavePulse.Resources.EXECUTE_ABILITIES = {
    [85990] = 25,
    [238043] = 25,
    [85982] = 25,
    [85986] = 25,
    [34851] = 25,
    [34843] = 50,
    [33386] = 25,
    [237603] = 25,
    [63029] = 33,
    [237974] = 33,
    [63046] = 40,
    [63044] = 33,
    [19123] = 20,
    [18718] = 20,
    [237948] = 20,
    [19109] = 20,
}

local function InsertSkillOptionsForStackTracker()
    for skill, _ in pairs(WeavePulse.StackTracker.SKILL_ATTRIBUTES) do
        local skillOptions = {}
        skillOptions[skill] = {
            ["tracked"] = false,
            ["xOffset"] = 0,
            ["yOffset"] = 0,
            ["indicatorSize"] = 25,
            ["hideInPVP"] = false,
            ["playSound"] = false,
            ["sound"] = "ABILITY_COMPANION_ULTIMATE_READY",
            ["hightlightOnFullStacks"] = false,
            ["volume"] = 100,
        }
        if WeavePulse.StackTracker.SKILL_ATTRIBUTES[skill].duration then
            skillOptions[skill].showTimerBar = false
            skillOptions[skill].timerBarOrientation = "LEFT"
            skillOptions[skill].showTimer = false
            skillOptions[skill].animateTimer = false
            skillOptions[skill].soundReminder = false
            skillOptions[skill].reminderVolume = 100
            skillOptions[skill].expirationSound = "GroupElection_Requested"
            skillOptions[skill].expirationTimer = 1.5
            skillOptions[skill].remindersOnlyInCombat = false
        end
        WeavePulse.DEFAULT_SAVED_VARS.StackTracker[skill] = skillOptions[skill]
    end
end
InsertSkillOptionsForStackTracker()

WeavePulse.FESTIVAL_IDS = {
    [242982] = {
        ["name"] = Util.Text.CropZOSString(GetAbilityName(242982), "ability"),
        ["icon"] = "/art/fx/texture/snowball.dds",
    },
    [84330] = {
        ["name"] = Util.Text.CropZOSString(GetAbilityName(84330), "ability"),
        ["icon"] = "/esoui/art/icons/quest_mudball.dds",
    },
    [87474] = {
        ["name"] = Util.Text.CropZOSString(GetAbilityName(87474), "ability"),
        ["icon"] = "/esoui/art/icons/event_jestersfestival_2016_cherry_blossom_branch.dds",
    },
}
