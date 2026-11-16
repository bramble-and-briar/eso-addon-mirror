-- TomesGuard Localization: French

local strings = {
    SI_TOMESGUARD_WARNING              = "Veuillez d'abord fermer <<1>> avant d'ouvrir les Tomes de Tamriel !",
    SI_TOMESGUARD_SCENE_MAILINBOX      = "le courrier",
    SI_TOMESGUARD_SCENE_MAILSEND       = "le courrier",
    SI_TOMESGUARD_SCENE_INVENTORY      = "l'inventaire",
    SI_TOMESGUARD_SCENE_NOTIFICATIONS  = "les notifications",
    SI_TOMESGUARD_SCENE_STATS          = "la fiche de personnage",
    SI_TOMESGUARD_SCENE_SKILLS         = "la fenêtre de compétences",
    SI_TOMESGUARD_SCENE_JOURNAL        = "le journal de quêtes",
    SI_TOMESGUARD_SCENE_LORELIBRARY    = "la bibliothèque",
    SI_TOMESGUARD_SCENE_GROUPMENUKEYBOARD = "le menu de groupe",
    SI_TOMESGUARD_SCENE_FRIENDSLIST    = "la liste d'amis",
    SI_TOMESGUARD_SCENE_GUILDHOME      = "le menu de guilde",
    SI_TOMESGUARD_SCENE_HELPROOT       = "le menu d'aide",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 2)
end
