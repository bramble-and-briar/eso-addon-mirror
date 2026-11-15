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

ZO_CreateStringId("SI_CYRHUD_LANG", "zh")
ZO_CreateStringId("SI_CYRHUD_FONT", "$(CHAT_FONT)|16|soft-shadow-thick")
ZO_CreateStringId("SI_CYRHUD_FONT_SMALL", "$(CHAT_FONT)|12|thick-outline")

-- 20/07/2026 translation fix: see en.lua for details.
ZO_CreateStringId("SI_CYRHUD_APRIL1", "愚人节修复")
ZO_CreateStringId("SI_CYRHUD_APRIL1_TOOLTIP", "启用以恢复正常颜色")

ZO_CreateStringId("SI_CYRHUD_HIDE_IC", "隐藏帝都区域战斗")
ZO_CreateStringId("SI_CYRHUD_HIDE_IC_INFO", "隐藏 CyrHUD 的帝都区域战斗通知")

ZO_CreateStringId("SI_CYRHUD_QT", "隐藏任务追踪器选项")
ZO_CreateStringId("SI_CYRHUD_QT_DEFAULT", "自动隐藏默认任务追踪器")
ZO_CreateStringId("SI_CYRHUD_QT_TOOLTIP", "在显示 CyrHUD 时隐藏任务追踪器")
ZO_CreateStringId("SI_CYRHUD_QT_WYKKYD", "自动隐藏 Ravalox 任务追踪器")
ZO_CreateStringId("SI_CYRHUD_POPBAR", "显示阵营人数拥挤度")
ZO_CreateStringId("SI_CYRHUD_POPBAR_INFO", "在摘要中显示当前阵营人数拥挤度而不是联盟旗帜")
ZO_CreateStringId("SI_BINDING_NAME_CYRHUD_TOGGLE", "启用/禁用 CyrHUD")

ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS", "隐藏您的击杀/死亡计数器")
ZO_CreateStringId("SI_CYRHUD_HIDE_KILLSDEATHS_INFO", "隐藏您的击杀/死亡计数器（但仍在后台计数）")

ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES", "隐藏桥梁和里程门")
ZO_CreateStringId("SI_CYRHUD_HIDE_BRIDGESANDMILEGATES_INFO", "隐藏桥梁和里程门")

ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD", "隐藏火葬之主")
ZO_CreateStringId("SI_CYRHUD_HIDE_PYRELORD_INFO", "隐藏 CyrHUD 中的火葬之主通知")


local CZ = "|cC5C29E" -- ZOS standard text color
local CR = "|cFFFFFF" -- Reset color
ZO_CreateStringId("SI_CYRHUD_KEYBIND_HEADER", "按键绑定")
ZO_CreateStringId("SI_CYRHUD_KEYBIND_DESC",
    CZ .. "请参阅游戏的控制菜单，设置键位绑定给" .. CR .. " /cyrhud" .. CZ .. " 命令。\n"
        .."这将打开或关闭插件。")