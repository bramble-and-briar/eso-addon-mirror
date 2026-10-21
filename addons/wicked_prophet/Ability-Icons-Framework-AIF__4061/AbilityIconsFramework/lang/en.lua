local strings = {
    -- Potion Names (Legacy & Standard)
    HP_POTION_NAME_3              = "Sip of Heroism",
    HP_POTION_NAME_10             = "Tincture of Heroism",
    HP_POTION_NAME_20             = "Dram of Heroism",
    HP_POTION_NAME_30             = "Potion of Heroism",
    HP_POTION_NAME_40             = "Solution of Heroism",
    HP_POTION_NAME_CP10           = "Elixir of Heroism",
    HP_POTION_NAME_CP50           = "Panacea of Heroism",
    HP_POTION_NAME_CP100          = "Distillate of Heroism",
    HP_POTION_NAME_CP150          = "Essence of Heroism",


    -- Settings Menu
    SI_AIF_PANEL_NAME             = "Ability Icons Framework",
    SI_AIF_PANEL_DESC             = "Framework for customizing ability icons and combat UI.",
    SI_AIF_SETTINGS_HEADER        = "Settings",
    SI_AIF_GLOBAL_SETTINGS        = "Use the same settings for all characters",
    SI_AIF_SCRIBING_ICONS         = "Use Custom Scribed Ability Icons",
    SI_AIF_BASE_GAME_ICONS        = "Replace Base Game Icons",
    SI_AIF_HEROISM_POTIONS        = "Enable Heroism Potion Icons",
    SI_AIF_RESOLUTION             = "Base game icons resolution",
    SI_AIF_RESOLUTION_TIP         = "Texture resolution to use for default game icons",
    SI_AIF_RESOLUTION_WARN        = "Requires /reloadui to apply the changes",
    SI_AIF_RELOAD_UI              = "Reload UI",
    SI_AIF_PACK_ORDER_SUBMENU     = "Icon Packs load order",
    SI_AIF_PACK_PRIORITY          = "Icon pack priority",

    -- Slash Commands & Chat
    SI_AIF_COMMANDS_HEADER        = "Available commands:",
    SI_AIF_COMMAND_DETAILS        = "  /aif details <slot 3-8> [1 for backbar]",
    SI_AIF_COMMAND_ICONS          = "  /aif icons <slot 3-8> [1 for backbar]",
    SI_AIF_COMMAND_VARS           = "  /aif vars (inspect saved variables)",
    SI_AIF_COMMAND_SETTINGS       = "  /aifgb (open settings menu)",
    SI_AIF_SLOT_EMPTY             = "Slot <<1>> (bar <<2>>) is empty.",
    SI_AIF_SLOT_REDIRECT_NONE     = "  Redirected to: (none)",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(stringId, 1)
end