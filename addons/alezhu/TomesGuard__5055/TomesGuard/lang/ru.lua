-- TomesGuard Localization: Russian

local strings = {
    SI_TOMESGUARD_WARNING              = "Сначала закройте <<1>> перед открытием «Фолиантов Тамриэля»!",
    SI_TOMESGUARD_SCENE_MAILINBOX      = "почту",
    SI_TOMESGUARD_SCENE_MAILSEND       = "почту",
    SI_TOMESGUARD_SCENE_INVENTORY      = "инвентарь",
    SI_TOMESGUARD_SCENE_NOTIFICATIONS  = "уведомления",
    SI_TOMESGUARD_SCENE_STATS          = "окно персонажа",
    SI_TOMESGUARD_SCENE_SKILLS         = "окно навыков",
    SI_TOMESGUARD_SCENE_JOURNAL        = "журнал заданий",
    SI_TOMESGUARD_SCENE_LORELIBRARY    = "библиотеку",
    SI_TOMESGUARD_SCENE_GROUPMENUKEYBOARD = "меню группы",
    SI_TOMESGUARD_SCENE_FRIENDSLIST    = "список друзей",
    SI_TOMESGUARD_SCENE_GUILDHOME      = "меню гильдии",
    SI_TOMESGUARD_SCENE_HELPROOT       = "окно помощи",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 2)
end
