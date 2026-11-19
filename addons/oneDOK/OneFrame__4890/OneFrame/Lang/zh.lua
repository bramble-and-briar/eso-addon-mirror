local strings = {
    [SI_ONEFRAME_DEBUG] = "Debug",
    [SI_ONEFRAME_DEBUG_OFF] = "关闭",
    [SI_ONEFRAME_DEBUG_SMALL] = "小队",
    [SI_ONEFRAME_DEBUG_LARGE] = "大型团队",
    [SI_ONEFRAME_DISPLAY] = "显示",
    [SI_ONEFRAME_TANK_ROLE] = "坦克",
    [SI_ONEFRAME_HEALER_ROLE] = "治疗者",
    [SI_ONEFRAME_DAMAGE_ROLE] = "伤害输出",
    [SI_ONEFRAME_SHOW_STATISTIC] = "显示统计",
    [SI_ONEFRAME_NOTHING] = "无",
    [SI_ONEFRAME_LEVEL_CP] = "等级 / 勇士点数",
    [SI_ONEFRAME_GROUP_DPS] = "队伍DPS",
    [SI_ONEFRAME_HEALTH_THOUSANDS] = "%.1fk",
    [SI_ONEFRAME_GENERAL] = "常规",
    [SI_ONEFRAME_SORT] = "按职责排序队伍",
    [SI_ONEFRAME_CLASS] = "显示职业图标",
    [SI_ONEFRAME_DPS_LABEL] = "DPS",
    [SI_ONEFRAME_HPS_LABEL] = "HPS",
    [SI_ONEFRAME_UNAVAILABLE] = "—",
    [SI_ONEFRAME_KILO] = "%.1fk",
    [SI_ONEFRAME_MILLION] = "%.2fm",
    [SI_ONEFRAME_SHIELD_COLOR] = "护盾颜色",
    [SI_ONEFRAME_CONTEXT_MENU] = "右键菜单",
    [SI_ONEFRAME_WHISPER] = "密语",
    [SI_ONEFRAME_TRAVEL] = "传送至玩家",
    [SI_ONEFRAME_REMOVE] = "移出队伍",
    [SI_ONEFRAME_UNSUPPORTED] = "OneFrame：尚未验证此ESO界面版本，已禁用框架增强功能。",
    [SI_ONEFRAME_MISSING] = "OneFrame：无法支持默认框架，未能应用增强功能。",
}

for id, text in pairs(strings) do
    SafeAddString(id, text, 1)
end
