--[[
    Mansu's InstanceReset - English texts (default language)

    This file is loaded on every client. The file of the client's language
    (lang/fr.lua, lang/de.lua, ...) is loaded after it, if it exists, and
    replaces the texts it translates. Anything it leaves out stays in English.

    To add a language: copy lang/fr.lua to lang/<code>.lua, where <code> is the
    client's language code (de, es, ru, jp, zh, ...), and translate the texts on
    the right. Keep the names on the left and the <<1>> markers as they are.
    No other file has to change.
]]

local strings =
{
    -- Names shown in Settings > Controls > Keybindings
    SI_BINDING_NAME_MANSUSINSTANCERESET_RESET  = "Reset instance (switch dungeon mode and back)",
    SI_BINDING_NAME_MANSUSINSTANCERESET_TOGGLE = "Toggle dungeon mode (Normal / Veteran)",
    SI_BINDING_NAME_MANSUSINSTANCERESET_LEAVE  = "Leave instance (press twice)",

    -- Alerts. <<1>> is the mode name (Normal / Veteran) as the game writes it.
    SI_MANSUSINSTANCERESET_CANNOT_CHANGE  = "The dungeon mode cannot be changed right now.",
    SI_MANSUSINSTANCERESET_NOT_CHANGED    = "The dungeon mode was not changed.",
    SI_MANSUSINSTANCERESET_NOT_RESTORED   = "Could not switch back: the dungeon mode is now <<1>>.",
    SI_MANSUSINSTANCERESET_ALREADY        = "The dungeon mode is already <<1>>.",
    SI_MANSUSINSTANCERESET_LEAVE_CONFIRM  = "Press the key again to leave the instance.",
    SI_MANSUSINSTANCERESET_LEAVE_NOT_HERE = "You cannot leave an instance from here.",

    -- Lines printed by /mir. <<1>> in the title is the add-on version.
    SI_MANSUSINSTANCERESET_HELP_TITLE   = "Mansu's InstanceReset <<1>> - commands:",
    SI_MANSUSINSTANCERESET_HELP_RESET   = "/mir reset - switch the dungeon mode and straight back (same as the Reset key)",
    SI_MANSUSINSTANCERESET_HELP_TOGGLE  = "/mir toggle - switch between Normal and Veteran and stay there (same as the Toggle key)",
    SI_MANSUSINSTANCERESET_HELP_NORMAL  = "/mir normal - set Normal",
    SI_MANSUSINSTANCERESET_HELP_VETERAN = "/mir vet - set Veteran",
    SI_MANSUSINSTANCERESET_HELP_LEAVE   = "/mir leave - leave the instance you are in, at once (the Leave key asks for a second press)",
    SI_MANSUSINSTANCERESET_HELP_KEYBIND = "Keys can be bound under Settings > Controls > Keybindings > Mansu's InstanceReset.",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
end
