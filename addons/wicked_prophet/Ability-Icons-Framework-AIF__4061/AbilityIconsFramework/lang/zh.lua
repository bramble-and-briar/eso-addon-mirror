local strings = {
    -- Potion Names (Legacy & Standard)
    HP_POTION_NAME_3              = "英雄小口药水",
    HP_POTION_NAME_10             = "英雄酊剂",
    HP_POTION_NAME_20             = "英雄浸剂",
    HP_POTION_NAME_30             = "英雄药水",
    HP_POTION_NAME_40             = "英雄溶液",
    HP_POTION_NAME_CP10           = "英雄灵药",
    HP_POTION_NAME_CP50           = "英雄万能药",
    HP_POTION_NAME_CP100          = "英雄馏剂",
    HP_POTION_NAME_CP150          = "英雄精华",


    -- Settings Menu
    SI_AIF_PANEL_NAME             = "Ability Icons Framework",
    SI_AIF_PANEL_DESC             = "用于自定义技能图标与战斗界面的框架。",
    SI_AIF_SETTINGS_HEADER        = "设置",
    SI_AIF_GLOBAL_SETTINGS        = "所有角色使用相同设置",
    SI_AIF_SCRIBING_ICONS         = "使用自定义刻印技能图标",
    SI_AIF_BASE_GAME_ICONS        = "替换基础游戏图标",
    SI_AIF_HEROISM_POTIONS        = "启用英雄药水图标",
    SI_AIF_RESOLUTION             = "基础游戏图标分辨率",
    SI_AIF_RESOLUTION_TIP         = "默认游戏图标使用的贴图分辨率",
    SI_AIF_RESOLUTION_WARN        = "需要执行 /reloadui 以应用更改",
    SI_AIF_RELOAD_UI              = "重载界面",
    SI_AIF_PACK_ORDER_SUBMENU     = "图标包加载顺序",
    SI_AIF_PACK_PRIORITY          = "图标包优先级",

    -- Slash Commands & Chat
    SI_AIF_COMMANDS_HEADER        = "可用命令：",
    SI_AIF_COMMAND_DETAILS        = "  /aif details <技能槽 3-8> [副手栏输入 1]",
    SI_AIF_COMMAND_ICONS          = "  /aif icons <技能槽 3-8> [副手栏输入 1]",
    SI_AIF_COMMAND_VARS           = "  /aif vars (检查保存的变量)",
    SI_AIF_COMMAND_SETTINGS       = "  /aifgb (打开设置菜单)",
    SI_AIF_SLOT_EMPTY             = "槽位 <<1>> (技能栏 <<2>>) 为空。",
    SI_AIF_SLOT_REDIRECT_NONE     = "  重定向至：(无)",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 1)
end
