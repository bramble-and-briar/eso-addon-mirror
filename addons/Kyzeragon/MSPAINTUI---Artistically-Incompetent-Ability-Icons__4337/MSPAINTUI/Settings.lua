local MSP = MSPAINTUI

local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    local panelData = {
        type = "panel",
        name = "|c08BD1DMSPAINTUI|r",
        author = "Kyzeragon, BirdSalad, Eashi, Thepinja",
        version = MSP.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = function()
                if (AbilityIconsFramework) then
                    return "Note: Since you are using Ability Icons Framework, changes to these settings will only take effect after you reload/restart your game."
                end
                return "Note: When you turn off any options, you will need to fully restart your game (not just reload!) in order to see the changes reflected. Reloading should work if you are only turning them on."
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "UI icons",
            tooltip = "Use Paint textures for some UI icons, typically buttons, such as the (gamepad) LFG role icons. This may also affect other addons that use the icons, including CrutchAlerts group icons",
            default = true,
            getFunc = function()
                return MSP.savedOptions.enable.uiIcons
            end,
            setFunc = function(value)
                MSP.savedOptions.enable.uiIcons = value
            end,
            width = "full",
        },
        {
            type = "divider",
            width = "half",
        },
    }

    if (not IsConsoleUI()) then
        table.insert(optionsData, 2, {
            type = "button",
            name = "Preview icons",
            tooltip = "Shows a window with all of the available icons",
            func = function()
                MSP.PreviewIcons()
            end,
            width = "full",
        })

        table.insert(optionsData, 3, {
            type = "checkbox",
            name = "UI textures",
            tooltip = "Use Paint textures for some UI elements, such as ability frames and progress bars",
            default = true,
            getFunc = function()
                return MSP.savedOptions.enable.ui
            end,
            setFunc = function(value)
                MSP.savedOptions.enable.ui = value
            end,
            width = "full",
        })
    end

    local optionsOrder = {
        "Dragonknight",
        "Sorcerer",
        "Nightblade",
        "Templar",
        "Warden",
        "Necromancer",
        "Arcanist",
        "Weapon",
        "Armor",
        "World",
        "Guild",
        "Alliance War",
    }

    for _, category in ipairs(optionsOrder) do
        table.insert(optionsData, {
            type = "checkbox",
            name = category,
            tooltip = "Use Paint textures for " .. category .. " icons",
            default = true,
            getFunc = function()
                return MSP.savedOptions.enable[category]
            end,
            setFunc = function(value)
                MSP.savedOptions.enable[category] = value
            end,
            width = "full",
        })
    end

    table.insert(optionsData, {
        type = "description",
        text = [[Credits:
@Kyzeragon - Coding + Compilation, UI, Herald of the Tome, Assassination, Shadow, Soldier of Apocrypha
@BirdSalad - Grave Lord, Dawn's Wrath, Dual Wield, Ardent Flame (pre-U49), Support, Restoring Light, Bone Tyrant, Animal Companions, Living Death, Resolving Vigor, Dragon Leap & morphs
@Thepinja - Daedric Summoning, Storm Calling, Dark Magic, Armor, Soul Magic, Mages Guild
@Eashi - Destruction Staff, Trample, Psijic Order, Expert Hunter
@BortSmithson - Bow, Draconic Power (pre-U49)
@M0R_Gaming - Winter's Embrace, Alliance War Ranks
@Plonkerr - Werewolf
@Lykeion - Siphoning
@t.ea - Two Handed
@SpookaSpooka - Vampire
@camrenis - Aedric Spear
@QueuesAsTanks - Fighters Guild
@cfblack - Restoration
@SuddenGhost24 - War Horn & morphs
]],
        width = "full",
    })

    LAM:RegisterAddonPanel("MSPAINTUIOptions", panelData)
    LAM:RegisterOptionControls("MSPAINTUIOptions", optionsData)
end
MSP.CreateSettingsMenu = CreateSettingsMenu
