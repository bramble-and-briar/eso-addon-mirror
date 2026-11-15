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

-- 20/07/2026: new file. Spanish was added as an officially-supported ESO
-- client language in 2022, but CyrHUD had no lang/es.lua, so a Spanish
-- client would silently fall back to English (or raw string IDs) for every
-- string in the addon. Strings below mirror en.lua 1:1; translations are a
-- best-effort pass and would benefit from a native-speaker review before
-- release, same as any other machine-assisted translation.

ZO_CreateStringId("SI_CYRHUD_LANG", "es")
ZO_CreateStringId("SI_CYRHUD_FONT", "$(CHAT_FONT)|18|soft-shadow-thick")
ZO_CreateStringId("SI_CYRHUD_FONT_SMALL", "$(CHAT_FONT)|12|thick-outline")

ZO_CreateStringId("SI_CYRHUD_APRIL1", "Corrección del Día de los Inocentes")
ZO_CreateStringId("SI_CYRHUD_APRIL1_TOOLTIP", "Activa esta opción para restaurar los colores normales")

ZO_CreateStringId("SI_CYRHUD_HIDE_IC", "Ocultar batallas del Distrito Imperial")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC_INFO", "Oculta las batallas del Distrito Imperial de las notificaciones de CyrHUD")

ZO_CreateStringId("SI_CYRHUD_QT", "Ocultar opciones de seguimiento de misiones")
ZO_CreateStringId("SI_CYRHUD_QT_DEFAULT", "Auto-ocultar el seguimiento de misiones predeterminado")
ZO_CreateStringId("SI_CYRHUD_QT_TOOLTIP", "Oculta el seguimiento de misiones cuando se muestra CyrHUD")
ZO_CreateStringId("SI_CYRHUD_QT_WYKKYD", "Auto-ocultar el seguimiento de misiones Ravalox")
ZO_CreateStringId("SI_CYRHUD_POPBAR", "Barras de población en lugar de banderas")
ZO_CreateStringId("SI_CYRHUD_POPBAR_INFO", "Muestra la población actual en lugar de la bandera de la alianza en el resumen")
ZO_CreateStringId("SI_BINDING_NAME_CYRHUD_TOGGLE", "Activar/desactivar CyrHUD")

ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS", "Ocultar tu contador de eliminaciones/muertes")
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS_INFO", "Oculta tu contador de eliminaciones/muertes (pero se sigue contando en segundo plano)")

ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES", "Ocultar puentes y puertas de camino")
ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES_INFO", "Ocultar puentes y puertas de camino")

ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD", "Ocultar al Señor de la Pira")
ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD_INFO", "Oculta la notificación del Señor de la Pira en CyrHUD")


local CZ = "|cC5C29E" -- ZOS standard text color
local CR = "|cFFFFFF" -- Reset color
ZO_CreateStringId("SI_CYRHUD_KEYBIND_HEADER", "Atajo de teclado")
ZO_CreateStringId("SI_CYRHUD_KEYBIND_DESC",
    CZ .. "Consulta el menú de controles del juego para configurar un atajo de teclado para el comando" .. CR .. " /cyrhud" .. CZ .. ".\n"
        .."Esto activa o desactiva el addon.")


--Templates for using in code (reference):
--ZO_CreateStringId("SI_CYRHUD_", )
--GetString(SI_CYRHUD_...)
--zo_strformat(GetString(SI_CYRHUD_...), param1, param2))
