
LeoAltholic = LeoAltholic or {}
local LeoAltholic = LeoAltholic
LeoAltholic.UI = LeoAltholic.UI or {}
LeoAltholic.ChecklistUI = LeoAltholic.ChecklistUI or {}
LeoAltholic.ToolbarUI = LeoAltholic.ToolbarUI or {}

LeoAltholic.name = "LeoAltholic"
LeoAltholic.displayName = "Leo's Altholic"
LeoAltholic.version = "1.9.10"
LeoAltholic.chatPrefix = "|c39B027" .. LeoAltholic.name .. "|r: "

LeoAltholic.TAB_BIO = "Bio"
LeoAltholic.TAB_STATS = "Stats"
LeoAltholic.TAB_SKILLS = "Skills"
LeoAltholic.TAB_SKILLS2 = "Skills2"
LeoAltholic.TAB_CHAMPION = "Champion"
LeoAltholic.TAB_TRACKED = "Tracked"
LeoAltholic.TAB_WRITS = "Writs"
LeoAltholic.TAB_INVENTORY = "Inventory"
LeoAltholic.TAB_RESEARCH = "Research"

LeoAltholic.CHAMPION_WARFARE = 1
LeoAltholic.CHAMPION_FITNESS = 2
LeoAltholic.CHAMPION_CRAFT = 3

LeoAltholic.panelList = {
    LeoAltholic.TAB_BIO,
    LeoAltholic.TAB_STATS,
    LeoAltholic.TAB_SKILLS,
    LeoAltholic.TAB_SKILLS2,
    LeoAltholic.TAB_CHAMPION,
    LeoAltholic.TAB_TRACKED,
    LeoAltholic.TAB_WRITS,
    LeoAltholic.TAB_INVENTORY,
    LeoAltholic.TAB_RESEARCH
}
LeoAltholic.allCrafts = {
    CRAFTING_TYPE_ALCHEMY,
    CRAFTING_TYPE_BLACKSMITHING,
    CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_ENCHANTING,
    CRAFTING_TYPE_JEWELRYCRAFTING,
    CRAFTING_TYPE_PROVISIONING,
    CRAFTING_TYPE_WOODWORKING
}
LeoAltholic.craftResearch = {
    CRAFTING_TYPE_BLACKSMITHING,
    CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING
}
LeoAltholic.craftIcons = {
    [CRAFTING_TYPE_BLACKSMITHING] = "esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_up.dds",
    [CRAFTING_TYPE_CLOTHIER] = "esoui/art/inventory/inventory_tabicon_craftbag_clothing_up.dds",
    [CRAFTING_TYPE_WOODWORKING] = "esoui/art/inventory/inventory_tabicon_craftbag_woodworking_up.dds",
    [CRAFTING_TYPE_ALCHEMY] = "esoui/art/inventory/inventory_tabicon_craftbag_alchemy_up.dds",
    [CRAFTING_TYPE_ENCHANTING] = "esoui/art/inventory/inventory_tabicon_craftbag_enchanting_up.dds",
    [CRAFTING_TYPE_PROVISIONING] = "esoui/art/inventory/inventory_tabicon_craftbag_provisioning_up.dds",
    [CRAFTING_TYPE_JEWELRYCRAFTING] = "esoui/art/inventory/inventory_tabicon_craftbag_jewelrycrafting_up.dds",
}
LeoAltholic.color = {
    hex = {
        green = '10FF10',
        darkGreen = '21A121',
        white = 'FFFFFF',
        red = 'FF1010',
        darkRed = 'CB110E',
        yellow = 'FFFF00',
        orange = 'FFCC00',
        eso = 'E8DFAF',
    },
    rgba = {
        green = {0,1,0,1},
        white = {1,1,1,1},
        red = {1,0.25,0.12},
        yellow = {1,1,0,1},
        orange = {1,0.8,0,1},
    }
}
