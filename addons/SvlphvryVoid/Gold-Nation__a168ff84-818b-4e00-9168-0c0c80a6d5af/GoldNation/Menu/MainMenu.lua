GoldNation.Menu = GoldNation.Menu or {}

local LAM = LibAddonMenu2

local function loadAddonMenu()
    local panelName = "GoldNationMenu"
    
    local panelData = {
        type = "panel",
        name = GoldNation.name,
        author = GoldNation.author,
    }

    local optionsData = {
        [1] = {
            type = "submenu",
            name = "AutoLoot Menu",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Enable AutoLoot",
                    tooltip = "Enable AutoLoot functionality. Automatically loot items from loot menus",
                    getFunc = function() return savedVariables.GN_AutoLoot end,
                    setFunc = function(value) savedVariables.GN_AutoLoot = value end,
                },
                [2] = {
                    type = "checkbox",
                    name = "Loot Gold",
                    tooltip = "Automatically loot gold from corpses.",
                    getFunc = function() return savedVariables.AL_Gold end,
                    setFunc = function(value) savedVariables.AL_Gold = value end,
                },
                [3] = {
                    type = "checkbox",
                    name = "Loot Weapons",
                    tooltip = "Automatically loot weapons from corpses.",
                    getFunc = function() return savedVariables.AL_Weapons end,
                    setFunc = function(value) savedVariables.AL_Weapons = value end,
                },
                [4] = {
                    type = "dropdown",
                    name = "Weapons Handling",
                    choices = {"Sell", "Keep", "Discard"},
                    getFunc = function() return savedVariables.AL_Weapons_Handle end,
                    setFunc = function(value) savedVariables.AL_Weapons_Handle = value end,
                },
                [5] = {
                    type = "checkbox",
                    name = "Loot Armour",
                    tooltip = "Automatically loot armour from corpses.",
                    getFunc = function() return savedVariables.AL_Armour end,
                    setFunc = function(value) savedVariables.AL_Armour = value end,
                },
                [6] = {
                    type = "dropdown",
                    name = "Armour Handling",
                    choices = {"Sell", "Keep", "Discard"},
                    getFunc = function() return savedVariables.AL_Armour_Handle end,
                    setFunc = function(value) savedVariables.AL_Armour_Handle = value end,
                },
                [7] = {
                    type = "checkbox",
                    name = "Loot Jewellery",
                    tooltip = "Automatically loot jewellery from corpses.",
                    getFunc = function() return savedVariables.AL_Jewellery end,
                    setFunc = function(value) savedVariables.AL_Jewellery = value end,
                },
                [8] = {
                    type = "dropdown",
                    name = "Jewellery Handling",
                    choices = {"Sell", "Keep", "Discard"},
                    getFunc = function() return savedVariables.AL_Jewellery_Handle end,
                    setFunc = function(value) savedVariables.AL_Jewellery_Handle = value end,
                },
                [9] = {
                    type = "checkbox",
                    name = "Loot Consumables",
                    tooltip = "Automatically loot consumables from corpses.",
                    getFunc = function() return savedVariables.AL_Consumables end,
                    setFunc = function(value) savedVariables.AL_Consumables = value end,
                },
                [10] = {
                    type = "dropdown",
                    name = "Consumables Handling",
                    choices = {"Sell", "Keep", "Discard"},
                    getFunc = function() return savedVariables.AL_Consumables_Handle end,
                    setFunc = function(value) savedVariables.AL_Consumables_Handle = value end,
                },
                [11] = {
                    type = "checkbox",
                    name = "Loot Collectables",
                    tooltip = "Automatically loot collectables from corpses.",
                    getFunc = function() return savedVariables.AL_Collectables end,
                    setFunc = function(value) savedVariables.AL_Collectables = value end,
                },
                [12] = {
                    type = "dropdown",
                    name = "Collectables Handling",
                    choices = {"Sell", "Keep", "Discard"},
                    getFunc = function() return savedVariables.AL_Collectables_Handle end,
                    setFunc = function(value) savedVariables.AL_Collectables_Handle = value end,
                },
                [13] = {
                    type = "checkbox",
                    name = "Bind Collectables to Account",
                    tooltip = "Bind collectables to your account.",
                    getFunc = function() return savedVariables.AL_Collectables_Bind end,
                    setFunc = function(value) savedVariables.AL_Collectables_Bind = value end,
                },
                [14] = {
                    type = "checkbox",
                    name = "Loot Stackables",
                    tooltip = "Automatically loot stackable items from corpses.",
                    getFunc = function() return savedVariables.AL_Stackables end,
                    setFunc = function(value) savedVariables.AL_Stackables = value end,
                },
            }
        },
        [2] = {
            type = "submenu",
            name = "Money Making Menu",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Enable AutoSell",
                    tooltip = "Automatically sell items to vendors.",
                    getFunc = function() return savedVariables.GN_AutoSell end,
                    setFunc = function(value) savedVariables.GN_AutoSell = value end,
                },
                [2] = {
                    type = "checkbox",
                    name = "Enable AutoRepair",
                    tooltip = "Automatically repair your equipment when visiting a vendor.",
                    getFunc = function() return savedVariables.GN_AutoRepair end,
                    setFunc = function(value) savedVariables.GN_AutoRepair = value end,
                },
            }
        },
        [3] = {
            type = "submenu",
            name = "Guild Menu",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Spare Some Change",
                    tooltip = "Automatically donate small amounts of gold to round your carried gold balance off to the nearest 1000. This will not take any more than 1000 gold at any one time.",
                    getFunc = function() return savedVariables.GN_AutoCollect end,
                    setFunc = function(value) savedVariables.GN_AutoCollect = value end,
                },
                [2] = {
                    type = "divider",
                    width = "half",
                },
                [3] = {
                    type = "description",
                    text = "https://discord.gg/NKqEwWXD5K",
                }
            }
        },
        [4] = {
            type = "submenu",
            name = "Misc Menu",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Spare Some Change",
                    tooltip = "Automatically donate small amounts of gold to round your carried gold balance off to the nearest 1000. This will not take any more than 1000 gold at any one time.",
                    getFunc = function() return savedVariables.GN_AutoCollect end,
                    setFunc = function(value) savedVariables.GN_AutoCollect = value end,
                },
                [2] = {
                    type = "divider",
                    width = "half",
                },
                [3] = {
                    type = "description",
                    text = "https://discord.gg/NKqEwWXD5K",
                }
            }
        },
        [5] = {
            type = "submenu",
            name = "Settings",
            controls = {
                [1] = {
                    type = "checkbox",
                    name = "Spare Some Change",
                    tooltip = "Automatically donate small amounts of gold to round your carried gold balance off to the nearest 1000. This will not take any more than 1000 gold at any one time.",
                    getFunc = function() return savedVariables.GN_AutoCollect end,
                    setFunc = function(value) savedVariables.GN_AutoCollect = value end,
                },
                [2] = {
                    type = "divider",
                    width = "half",
                },
                [3] = {
                    type = "description",
                    text = "https://discord.gg/NKqEwWXD5K",
                }
            }
        }
    }

    local panel = LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsData)
end


function GoldNation.Menu.Initialize()
    loadAddonMenu()
end


SLASH_COMMANDS["/goldnation"] = function()
 -- leave this here for example of slash menu
    d("gold nation menu slash command!")
end
