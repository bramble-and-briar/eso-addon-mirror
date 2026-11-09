-- CaracTracker : textes français (chargé uniquement si le client est en français)
-- Chaque texte remplace la version anglaise (version 1) par la version 2.

local function Add(id, text)
    SafeAddString(_G[id], text, 2)
end

---------------------------------------------------------------
-- Interface
---------------------------------------------------------------
Add("CARACTRACKER_UI_YES",       "Oui")
Add("CARACTRACKER_UI_NO",        "Non")
Add("CARACTRACKER_UI_NA",        "N/D")
Add("CARACTRACKER_UI_COLON",     " :")
Add("CARACTRACKER_UI_TIMEFMT",   "[%Hh%M]")
Add("CARACTRACKER_UI_GEAR",      "Choisir les caractéristiques à afficher")
Add("CARACTRACKER_UI_OPAC_UP",   "Augmenter l'opacité")
Add("CARACTRACKER_UI_OPAC_DOWN", "Diminuer l'opacité")

---------------------------------------------------------------
-- Libellés
---------------------------------------------------------------
Add("CARACTRACKER_L_INCOMBAT",   "En combat")
Add("CARACTRACKER_L_DPS",        "DPS")
Add("CARACTRACKER_L_HPS",        "HPS")
Add("CARACTRACKER_L_HPSRAW",     "HPS brut")

Add("CARACTRACKER_L_POWERP",     "Dégâts phys.")
Add("CARACTRACKER_L_POWERM",     "Dégâts magi.")

Add("CARACTRACKER_L_PENP",       "Pénétration P.")
Add("CARACTRACKER_L_PENM",       "Pénétration M.")

Add("CARACTRACKER_L_CRITP",      "% Critique P.")
Add("CARACTRACKER_L_CRITM",      "% Critique M.")
Add("CARACTRACKER_L_CRITDMG",    "+ Crit. dégâts")

Add("CARACTRACKER_L_MAGREGEN",   "Récup. Magie")
Add("CARACTRACKER_L_HEALTHREGEN","Récup. Santé")
Add("CARACTRACKER_L_STAMREGEN",  "Récup. Vigueur")

Add("CARACTRACKER_L_CRITHEAL",   "+ Crit. soins")
Add("CARACTRACKER_L_HEALDONE",   "+ Soins créés")
Add("CARACTRACKER_L_HEALTAKEN",  "+ Soins reçus")

Add("CARACTRACKER_L_BLOCK",      "Blocage")
Add("CARACTRACKER_L_BLOCKCOST",  "Coût Blocage")
Add("CARACTRACKER_L_BASHDMG",    "Dégâts percu.")
Add("CARACTRACKER_L_BASHCOST",   "Coût percu.")

Add("CARACTRACKER_L_SPELLRES",   "Résis. sorts")
Add("CARACTRACKER_L_SPELLABS",   "Absor. sorts")
Add("CARACTRACKER_L_PHYSRES",    "Résis. physiq.")
Add("CARACTRACKER_L_PHYSABS",    "Absor. physiq.")
Add("CARACTRACKER_L_CRITRES",    "Résis. critique")
Add("CARACTRACKER_L_CRITABS",    "Absor. de crit.")

Add("CARACTRACKER_L_SHIELD",     "Bouclier")

Add("CARACTRACKER_L_SPRINT",     "Vit. sprint")
Add("CARACTRACKER_L_SNEAK",      "Vit. discrétion")

---------------------------------------------------------------
-- Infobulles
---------------------------------------------------------------
Add("CARACTRACKER_T_INCOMBAT",    "Indique si le joueur est ou pas en combat. En combat, il ne peut pas utiliser sa monture, ouvrir un coffre, etc.")

Add("CARACTRACKER_T_DPS",         "Dégâts par seconde du dernier combat (joueur & familiers).")
Add("CARACTRACKER_T_HPS",         "Soins par seconde du dernier combat (joueur & familiers) sans overheal : si la cible a 100% de vie, les soins ne sont pas comptabilisés.")
Add("CARACTRACKER_T_HPSRAW",      "Soins par seconde du dernier combat (joueur & familiers) avec overheal : les soins excédentaires sont comptabilisés, aussi la valeur sera gonflée en présence de plusieurs cibles en pleine vie.")

Add("CARACTRACKER_T_POWERP",      "Dégâts des armes.")
Add("CARACTRACKER_T_POWERM",      "Dégâts des sorts.")
Add("CARACTRACKER_T_PENP",        "Pénétration physique.")
Add("CARACTRACKER_T_PENM",        "Pénétration des sorts.")

Add("CARACTRACKER_T_CRITP",       "Critique physique.")
Add("CARACTRACKER_T_CRITM",       "Critique magique.")
Add("CARACTRACKER_T_CRITDMG",     "Bonus de dégâts critiques supplémentaires.")

Add("CARACTRACKER_T_MAGREGEN",    "Récupération de Magie.")
Add("CARACTRACKER_T_HEALTHREGEN", "Récupération de Santé.")
Add("CARACTRACKER_T_STAMREGEN",   "Récupération de Vigueur.")

Add("CARACTRACKER_T_CRITHEAL",    "Bonus de soins critiques supplémentaires.")
Add("CARACTRACKER_T_HEALDONE",    "Bonus de soins produits.")
Add("CARACTRACKER_T_HEALTAKEN",   "Bonus de soins reçus.")

Add("CARACTRACKER_T_BLOCK",       "Pourcentage de dégâts bloqués.")
Add("CARACTRACKER_T_BLOCKCOST",   "Coût du blocage.")
Add("CARACTRACKER_T_BASHDMG",     "Dégâts de percussion.")
Add("CARACTRACKER_T_BASHCOST",    "Coût de la percussion.")

Add("CARACTRACKER_T_SPELLRES",    "Résistance aux sorts, à 33 000 le cap de résistance est atteint.")
Add("CARACTRACKER_T_PHYSRES",     "Résistance physique, à 33 000 le cap de résistance est atteint.")
Add("CARACTRACKER_T_CRITRES",     "Résistance aux coups critiques des joueurs adverses, à 3300 le cap de résistance est atteint.")

Add("CARACTRACKER_T_SPELLABS",    "Réduction des dégâts des sorts (mitigation), calculée à partir de la résistance aux sorts, valeur plafonnée à 50 %.")
Add("CARACTRACKER_T_PHYSABS",     "Réduction des dégâts physiques (mitigation), calculée à partir de la résistance physique, valeur plafonnée à 50 %.")
Add("CARACTRACKER_T_CRITABS",     "Réduction des dégâts critiques subis (mitigation), calculée à partir de la résistance critique, valeur plafonnée à 50 %.")

Add("CARACTRACKER_T_SHIELD",      "Somme totale des boucliers absorbants, fonctionne comme une seconde barre de vie.")

Add("CARACTRACKER_T_SPRINT",      "Bonus de vitesse de sprint.")
Add("CARACTRACKER_T_SNEAK",       "Vitesse de déplacement en mode discret.")
