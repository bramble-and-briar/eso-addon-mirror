-- TomesGuard Localization: German

local strings = {
    SI_TOMESGUARD_WARNING              = "Bitte schließe zuerst <<1>>, bevor du die Folianten von Tamriel öffnest!",
    SI_TOMESGUARD_SCENE_MAILINBOX      = "die Post",
    SI_TOMESGUARD_SCENE_MAILSEND       = "die Post",
    SI_TOMESGUARD_SCENE_INVENTORY      = "das Inventar",
    SI_TOMESGUARD_SCENE_NOTIFICATIONS  = "die Benachrichtigungen",
    SI_TOMESGUARD_SCENE_STATS          = "die Charakterübersicht",
    SI_TOMESGUARD_SCENE_SKILLS         = "das Fertigkeitenfenster",
    SI_TOMESGUARD_SCENE_JOURNAL        = "das Tagebuch",
    SI_TOMESGUARD_SCENE_LORELIBRARY    = "die Bibliothek",
    SI_TOMESGUARD_SCENE_GROUPMENUKEYBOARD = "das Gruppenmenü",
    SI_TOMESGUARD_SCENE_FRIENDSLIST    = "die Freundesliste",
    SI_TOMESGUARD_SCENE_GUILDHOME      = "das Gildenmenü",
    SI_TOMESGUARD_SCENE_HELPROOT       = "das Hilfemenü",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 2)
end
