-- This file is part of CyrHUD
--
-- (C) 2020 @mychaelo [EU]
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

ZO_CreateStringId("SI_CYRHUD_LANG", "ru")
ZO_CreateStringId("SI_CYRHUD_FONT", "$(CHAT_FONT)|18|soft-shadow-thick")
ZO_CreateStringId("SI_CYRHUD_FONT_SMALL", "$(CHAT_FONT)|12|thick-outline")

-- 20/07/2026 translation fix: see en.lua for details.
ZO_CreateStringId("SI_CYRHUD_APRIL1", "Исправление первоапрельской шутки")
ZO_CreateStringId("SI_CYRHUD_APRIL1_TOOLTIP", "Включите, чтобы восстановить обычные цвета")

ZO_CreateStringId("SI_CYRHUD_HIDE_IC", "Скрыть сражения в районах ИГ")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC_INFO", "Убирает сражения в Имперском городе из списка CyrHUD")
ZO_CreateStringId("SI_CYRHUD_QT_DEFAULT", "Скрывать стандартный трекер заданий")
ZO_CreateStringId("SI_CYRHUD_QT_TOOLTIP", "Убирает трекеры заданий с экрана при активном CyrHUD")
ZO_CreateStringId("SI_CYRHUD_QT", "Hide Quest Trackers options")
ZO_CreateStringId("SI_CYRHUD_QT_WYKKYD", "Скрывать Ravalox Quest Tracker")
ZO_CreateStringId("SI_CYRHUD_POPBAR", "Полосы населённости вместо флагов")
ZO_CreateStringId("SI_CYRHUD_POPBAR_INFO", "Показывает текущую численность войск на сервере вместо флага у альянсов в сводке")
ZO_CreateStringId("SI_BINDING_NAME_CYRHUD_TOGGLE", "Включить/отключить CyrHUD")

-- 20/07/2026 translation fix: see de.lua for details. HIDE_BRIDGESANDMILEGATES
-- is a live, currently-active checkbox in menu.lua and was missing entirely.
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS", "Скрыть счётчик убийств/смертей")
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS_INFO", "Скрывает счётчик убийств/смертей (подсчёт продолжается в фоновом режиме)")

ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES", "Скрыть мосты и мильные ворота")
ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES_INFO", "Скрыть мосты и мильные ворота")

ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD", "Скрыть Владыку Костра")
ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD_INFO", "Убирает уведомление о Владыке Костра из CyrHUD")

local CZ = "|cC5C29E" -- ZOS standard text color
local CR = "|cFFFFFF" -- Reset color
ZO_CreateStringId("SI_CYRHUD_KEYBIND_HEADER", "Назначения клавиш")
ZO_CreateStringId("SI_CYRHUD_KEYBIND_DESC",
    CZ .. "См. меню «Управление» для назначения клавиши на команду" .. CR .. " /cyrhud" .. CZ .. ".\n"
        .."Эта команда включает и выключает модификацию.")