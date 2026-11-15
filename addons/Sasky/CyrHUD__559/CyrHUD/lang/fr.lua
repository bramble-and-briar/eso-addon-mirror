-- This file is part of CyrHUD
--
-- (C) 2016 Llwydd
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

ZO_CreateStringId("SI_CYRHUD_LANG", "fr")
ZO_CreateStringId("SI_CYRHUD_FONT", "$(CHAT_FONT)|18|soft-shadow-thick")
ZO_CreateStringId("SI_CYRHUD_FONT_SMALL", "$(CHAT_FONT)|12|thick-outline")
ZO_CreateStringId("SI_CYRHUD_APRIL1", "Poisson d'avril Fix")
ZO_CreateStringId("SI_CYRHUD_APRIL1_TOOLTIP", "Activez pour revenir aux couleurs d'origine")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC", "Masquer les combats de la citée impériale")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC_INFO", "Masque les combats de la citée impériale depuis les notifications de CyrHUD")
ZO_CreateStringId("SI_CYRHUD_QT", "Hide Quest Trackers options")
ZO_CreateStringId("SI_CYRHUD_QT_DEFAULT", "Masquer automatiquement le suiveur de quêtes par défaut")
ZO_CreateStringId("SI_CYRHUD_QT_TOOLTIP", "Masque le suivi des quêtes quand CyrHUD est activé")
ZO_CreateStringId("SI_CYRHUD_QT_WYKKYD", "Masquer automatiquement Ravalox Quest Tracker")
ZO_CreateStringId("SI_CYRHUD_POPBAR", "Barres de population comme drapeau")
ZO_CreateStringId("SI_CYRHUD_POPBAR_INFO", "Affiche la population courante à la place du drapeau aliance dans le résumé")
ZO_CreateStringId("SI_BINDING_NAME_CYRHUD_TOGGLE", "Activer/désactiver CyrHUD")

-- 20/07/2026 translation fix: see de.lua for details. HIDE_BRIDGESANDMILEGATES
-- is a live, currently-active checkbox in menu.lua and was missing entirely.
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS", "Masquer votre compteur de kills/morts")
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS_INFO", "Masque votre compteur de kills/morts (mais continue de compter en arrière-plan)")

ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES", "Masquer les ponts et postes-frontières")
ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES_INFO", "Masquer les ponts et postes-frontières")

ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD", "Masquer le Seigneur du Bûcher")
ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD_INFO", "Masque la notification du Seigneur du Bûcher dans CyrHUD")

local CZ = "|cC5C29E" -- ZOS standard text color
local CR = "|cFFFFFF" -- Reset color
ZO_CreateStringId("SI_CYRHUD_KEYBIND_HEADER", "Raccourci")
-- 20/07/2026 bug fix:
-- "command." was left in English in this otherwise-French sentence
-- (should be "commande.").
ZO_CreateStringId("SI_CYRHUD_KEYBIND_DESC",
    CZ .. "Voir dans le menu réglages du jeu pour affecter un raccourci à " .. CR .. " /cyrhud" .. CZ .. " commande.\n"
            .."Cela permet d'activer l'extension ou non.")


--Templates for using in code (reference):
--ZO_CreateStringId("SI_CYRHUD_", )
--GetString(SI_CYRHUD_...)
--zo_strformat(GetString(SI_CYRHUD_...), param1, param2))
