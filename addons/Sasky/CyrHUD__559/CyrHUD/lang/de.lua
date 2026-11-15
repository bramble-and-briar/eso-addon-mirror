-- This file is part of CyrHUD
--
-- (C) 2016 Scott Yeskie (Sasky)
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

ZO_CreateStringId("SI_CYRHUD_LANG", "de")
ZO_CreateStringId("SI_CYRHUD_FONT", "$(CHAT_FONT)|18|soft-shadow-thick")
ZO_CreateStringId("SI_CYRHUD_FONT_SMALL", "$(CHAT_FONT)|12|thick-outline")
ZO_CreateStringId("SI_CYRHUD_APRIL1", "Aprilscherz AUS")
ZO_CreateStringId("SI_CYRHUD_APRIL1_TOOLTIP", "Schalte diese Option ein, um die normalen Farben wieder herzustellen")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC", "Verstecke Kaiserstadt Kämpfe")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC_INFO", "Zeigt Kaiserstadt Kämpfe nicht in den CyrHUD Benachrichtigungen an")
ZO_CreateStringId("SI_CYRHUD_QT", "Hide Quest Trackers options")
ZO_CreateStringId("SI_CYRHUD_QT_DEFAULT", "Auto-Verstecke Standard Quest Tracker")
ZO_CreateStringId("SI_CYRHUD_QT_TOOLTIP", "Versteckt den Quest Tracker vom Spiel, wenn CyrHUD angezeigt wird")
ZO_CreateStringId("SI_CYRHUD_QT_WYKKYD", "Auto-Verstecke Ravalox Quest Tracker")
ZO_CreateStringId("SI_CYRHUD_POPBAR", "Population anstelle von Flaggen")
ZO_CreateStringId("SI_CYRHUD_POPBAR_INFO", "Zeigt die aktuelle Population anstelle der Allianz Flaggen in der Zusammenfassung an")
ZO_CreateStringId("SI_BINDING_NAME_CYRHUD_TOGGLE", "Aktiviere/Deaktiviere CyrHUD")

-- 20/07/2026 translation fix:
-- These two pairs exist in en.lua/zh.lua but were missing here.
-- SI_CYRHUD_HIDE_BRIDGESANDMILEGATES(_INFO) backs a live, currently-active
-- checkbox in menu.lua ("Hide Bridges and Milegates"), so a German client
-- was seeing a blank/fallback label and tooltip for that option.
-- SI_CYRHUD_HIDE_KILLSDEATHS(_INFO) currently only backs a commented-out
-- checkbox, but is added for parity in case that option is re-enabled.
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS", "Verstecke deinen Kills/Tode-Zähler")
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS_INFO", "Versteckt deinen Kills/Tode-Zähler (zählt aber weiterhin im Hintergrund)")

ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES", "Verstecke Brücken und Meilentore")
ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES_INFO", "Verstecke Brücken und Meilentore")

ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD", "Verstecke Feuerlord")
ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD_INFO", "Zeigt die Feuerlord-Benachrichtigung nicht in CyrHUD an")

local CZ = "|cC5C29E" -- ZOS standard text color
local CR = "|cFFFFFF" -- Reset color
ZO_CreateStringId("SI_CYRHUD_KEYBIND_HEADER", "Tastenkombination")
-- 20/07/2026 bug fix:
-- The original text read "Diese aktiviert(deaktiviert dieses Addon!" -- a
-- missing "/" between aktiviert/deaktiviert (it read as if "aktiviert" were
-- being parenthetically followed by "deaktiviert" with no closing paren),
-- and "Diese" (referring to a feminine/plural noun that isn't actually
-- present in this sentence) should be "Dies" (this/it). Corrected to
-- "Dies aktiviert/deaktiviert dieses Addon."
ZO_CreateStringId("SI_CYRHUD_KEYBIND_DESC",
    CZ .. "Gehe in die Steuerung Spiel Optionen um eine Tastenkombination für den " .. CR .. " /cyrhud" .. CZ .. " Befehl einzustellen.\n"
        .."Dies aktiviert/deaktiviert dieses Addon.")


--Templates for using in code (reference):
--ZO_CreateStringId("SI_CYRHUD_", )
--GetString(SI_CYRHUD_...)
--zo_strformat(GetString(SI_CYRHUD_...), param1, param2))
