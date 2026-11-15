-- This file is part of CyrHUD
--
-- (C) 2016 @Lionas
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

ZO_CreateStringId("SI_CYRHUD_LANG", "jp")
ZO_CreateStringId("SI_CYRHUD_FONT", "$(CHAT_FONT)|18|soft-shadow-thick")
ZO_CreateStringId("SI_CYRHUD_FONT_SMALL", "$(CHAT_FONT)|12|thick-outline")
ZO_CreateStringId("SI_CYRHUD_APRIL1", "エイプリルフールの修正")
ZO_CreateStringId("SI_CYRHUD_APRIL1_TOOLTIP", "通常の色に戻す")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC", "帝国地域の戦闘を隠す")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC_INFO", "CryHUDの通知から帝国地域の戦闘を隠す")
ZO_CreateStringId("SI_CYRHUD_QT", "Hide Quest Trackers options")
ZO_CreateStringId("SI_CYRHUD_QT_DEFAULT", "クエストトラッカーを自動非表示")
ZO_CreateStringId("SI_CYRHUD_QT_TOOLTIP", "CryHUDが表示されている時にクエストトラッカーを隠す")
ZO_CreateStringId("SI_CYRHUD_QT_WYKKYD", "Ravalox Quest Trackerの自動非表示")
ZO_CreateStringId("SI_CYRHUD_POPBAR", "旗／人口バーの切替")
ZO_CreateStringId("SI_CYRHUD_POPBAR_INFO", "概要欄の同盟旗の代わりに現在の人口を表示する")
ZO_CreateStringId("SI_BINDING_NAME_CYRHUD_TOGGLE", "CyrHUDの有効化/無効化")

-- 20/07/2026 translation fix: see de.lua for details. HIDE_BRIDGESANDMILEGATES
-- is a live, currently-active checkbox in menu.lua and was missing entirely.
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS", "キル/デス カウンターを隠す")
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS_INFO", "キル/デス カウンターを隠す(バックグラウンドではカウントを継続します)")

ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES", "橋とマイルゲートを隠す")
ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES_INFO", "橋とマイルゲートを隠す")

ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD", "パイアロードを隠す")
ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD_INFO", "CyrHUDからパイアロードの通知を隠す")
 
local CZ = "|cC5C29E" -- ZOS standard text color
local CR = "|cFFFFFF" -- Reset color
ZO_CreateStringId("SI_CYRHUD_KEYBIND_HEADER", "キーバインド")
ZO_CreateStringId("SI_CYRHUD_KEYBIND_DESC", CR .. " /cyrhud" .. CZ .. "コマンドでアドオンのON/OFFが可能です")
