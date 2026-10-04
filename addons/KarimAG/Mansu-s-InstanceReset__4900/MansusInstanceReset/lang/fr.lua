--[[
    Mansu's InstanceReset - textes français

    Loaded after lang/en.lua on French clients; each text below replaces the
    English one of the same name.

    Template for a new language: copy this file to lang/<code>.lua (de, es, ru,
    jp, zh, ...) and translate the texts on the right. Keep the names on the
    left and the <<1>> markers as they are.
]]

local strings =
{
    -- Noms affichés dans Paramètres > Commandes > Raccourcis
    SI_BINDING_NAME_MANSUSINSTANCERESET_RESET  = "Réinitialiser l'instance (changer le mode de donjon puis revenir)",
    SI_BINDING_NAME_MANSUSINSTANCERESET_TOGGLE = "Basculer le mode de donjon (Normal / Vétéran)",
    SI_BINDING_NAME_MANSUSINSTANCERESET_LEAVE  = "Quitter l'instance (deux appuis)",

    -- Alertes. <<1>> est le nom du mode (Normal / Vétéran) tel que le jeu l'écrit.
    SI_MANSUSINSTANCERESET_CANNOT_CHANGE  = "Le mode de donjon ne peut pas être modifié pour le moment.",
    SI_MANSUSINSTANCERESET_NOT_CHANGED    = "Le mode de donjon n'a pas été modifié.",
    SI_MANSUSINSTANCERESET_NOT_RESTORED   = "Retour impossible : le mode de donjon est maintenant <<1>>.",
    SI_MANSUSINSTANCERESET_ALREADY        = "Le mode de donjon est déjà : <<1>>.",
    SI_MANSUSINSTANCERESET_LEAVE_CONFIRM  = "Appuyez de nouveau sur la touche pour quitter l'instance.",
    SI_MANSUSINSTANCERESET_LEAVE_NOT_HERE = "Impossible de quitter une instance depuis cet endroit.",

    -- Lignes affichées par /mir. <<1>> dans le titre est la version de l'add-on.
    SI_MANSUSINSTANCERESET_HELP_TITLE   = "Mansu's InstanceReset <<1>> - commandes :",
    SI_MANSUSINSTANCERESET_HELP_RESET   = "/mir reset - change le mode de donjon puis revient aussitôt (comme la touche de réinitialisation)",
    SI_MANSUSINSTANCERESET_HELP_TOGGLE  = "/mir toggle - bascule entre Normal et Vétéran et y reste (comme la touche de bascule)",
    SI_MANSUSINSTANCERESET_HELP_NORMAL  = "/mir normal - passe en Normal",
    SI_MANSUSINSTANCERESET_HELP_VETERAN = "/mir vet - passe en Vétéran",
    SI_MANSUSINSTANCERESET_HELP_LEAVE   = "/mir leave - quitte aussitôt l'instance où vous êtes (la touche Quitter demande un second appui)",
    SI_MANSUSINSTANCERESET_HELP_KEYBIND = "Les touches s'assignent dans Paramètres > Commandes > Raccourcis > Mansu's InstanceReset.",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 1)
end
