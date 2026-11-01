MSPAINTUI = {
    name = "MSPAINTUI",
    version = "1.6.0",
}
local MSP = MSPAINTUI

local defaultOptions = {
    enable = {
        ui = true,
        uiIcons = true,
        ["Dragonknight"] = true,
        ["Sorcerer"] = true,
        ["Nightblade"] = true,
        ["Templar"] = true,
        ["Warden"] = true,
        ["Necromancer"] = true,
        ["Arcanist"] = true,
        ["Weapon"] = true,
        ["Armor"] = true,
        ["World"] = true,
        ["Guild"] = true,
        ["Alliance War"] = true,
    },
}


---------------------------------------------------------------------
-- Optional AbilityIconsFramework if it exists
local function InitializeWithAIF()
    local icons = {}

    for groupName, group in pairs(MSP.ABILITY_ICONS) do
        if (MSP.savedOptions.enable[groupName]) then
            for _, iconPath in ipairs(group) do
                table.insert(icons, iconPath)
            end
        end
    end

    AbilityIconsFramework.AddCustomIconPack("/MSPAINTUI/art/abilities/", icons)
end


---------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------
local function Initialize()
    MSP.savedOptions = ZO_SavedVars:NewAccountWide("MSPAINTUISavedVariables", 1, "Options", defaultOptions)
    MSP.CreateSettingsMenu()

    if (AbilityIconsFramework) then
        InitializeWithAIF()
    else
        MSP.RedirectAbilityTextures()
    end

    if (MSP.savedOptions.enable.ui and not IsConsoleUI()) then
        RedirectTexture("/esoui/art/actionbar/abilityframe64_up.dds", "MSPAINTUI/art/ui/abilityframe64_up.dds")
        RedirectTexture("/esoui/art/actionbar/passiveabilityframe_round_up.dds", "MSPAINTUI/art/ui/passiveabilityframe_round_up.dds")
        RedirectTexture("/esoui/art/progression/addpoints_up.dds", "MSPAINTUI/art/ui/addpoints_up.dds")
        RedirectTexture("/esoui/art/progression/morph_up.dds", "MSPAINTUI/art/ui/morph_up.dds")
        RedirectTexture("/esoui/art/progression/skillstyling_default_up.dds", "MSPAINTUI/art/ui/skillstyling_default_up.dds")
        RedirectTexture("/esoui/art/miscellaneous/progressbar_frame.dds", "MSPAINTUI/art/ui/progressbar_frame.dds")

        RedirectTexture("/esoui/art/miscellaneous/scrollbox_elevator.dds", "MSPAINTUI/art/ui/scrollbox_elevator.dds")
        RedirectTexture("/esoui/art/buttons/scrollbox_downarrow_up.dds", "MSPAINTUI/art/ui/scrollbox_downarrow_up.dds")
        RedirectTexture("/esoui/art/buttons/scrollbox_uparrow_up.dds", "MSPAINTUI/art/ui/scrollbox_uparrow_up.dds")

        RedirectTexture("/esoui/art/characterwindow/swap_button_up.dds", "MSPAINTUI/art/ui/swap_button_up.dds")
        RedirectTexture("/esoui/art/buttons/large_rightarrow_up.dds", "MSPAINTUI/art/ui/large_rightarrow_up.dds")
    end

    if (MSP.savedOptions.enable.uiIcons) then
        local icons = {
            "lfg/gamepad/lfg_roleicon_dps.dds",
            "lfg/gamepad/lfg_roleicon_healer.dds",
            "lfg/gamepad/lfg_roleicon_tank.dds",
            "lfg/gamepad/lfg_roleicon_dps_down.dds",
            "lfg/gamepad/lfg_roleicon_healer_down.dds",
            "lfg/gamepad/lfg_roleicon_tank_down.dds",
            "icons/mapkey/mapkey_groupleader.dds",
            "icons/mapkey/mapkey_groupboss.dds",
            "champion/champion_icon.dds",
            "champion/champion_icon_32.dds",
            "ava/ava_rankicon64_tribune.dds",
            "ava/ava_rankicon64_prefect.dds",
            "ava/ava_rankicon64_grandoverlord.dds",
        }
        for _, path in ipairs(icons) do
            RedirectTexture("/esoui/art/" .. path, "MSPAINTUI/art/ui/" .. path)
        end
    end
end


---------------------------------------------------------------------
-- On load
local function OnAddOnLoaded(_, addonName)
    if (addonName == MSP.name) then
        EVENT_MANAGER:UnregisterForEvent(MSP.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end
 
EVENT_MANAGER:RegisterForEvent(MSP.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

