-- TomesGuard Localization: English (Default Fallback)

local strings = {
    SI_TOMESGUARD_WARNING              = "Please close <<1>> before opening Tamriel Tomes!",
    SI_TOMESGUARD_SCENE_MAILINBOX      = "Mail",
    SI_TOMESGUARD_SCENE_MAILSEND       = "Mail",
    SI_TOMESGUARD_SCENE_INVENTORY      = "Inventory",
    SI_TOMESGUARD_SCENE_NOTIFICATIONS  = "Notifications",
    SI_TOMESGUARD_SCENE_STATS          = "Character sheet",
    SI_TOMESGUARD_SCENE_SKILLS         = "Skills window",
    SI_TOMESGUARD_SCENE_JOURNAL        = "Journal",
    SI_TOMESGUARD_SCENE_LORELIBRARY    = "Lore Library",
    SI_TOMESGUARD_SCENE_GROUPMENUKEYBOARD = "Group menu",
    SI_TOMESGUARD_SCENE_FRIENDSLIST    = "Friends list",
    SI_TOMESGUARD_SCENE_GUILDHOME      = "Guild menu",
    SI_TOMESGUARD_SCENE_HELPROOT       = "Help menu",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddString(_G[stringId], stringValue, 1)
end
