local AE = AtlasAddon

AE.Translations.zh = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "适用于《上古卷轴OL》的 Torfason × Atlas 插件。随着角色探索泰姆瑞尔，逐步揭开世界地图。",
    PREFIX = "|cD8B36A[Atlas]|r ",
    LOADED = "已加载。输入 /atlas help 查看命令。",
    HELP = [[
|cD8B36AAtlas – 命令|r
/atlas – 打开 Atlas 设置
/atlas help – 显示帮助
/atlas on – 启用 Atlas
/atlas off – 禁用 Atlas
/atlas reveal – 完全揭开当前地图
/atlas forget – 清除当前地图的探索记录
/atlas import – 导入当前角色的 TrueExploration 数据
/atlas importall – 合并找到的全部 TrueExploration 档案
/atlas status – 显示当前地图信息
/atlas archive – 打开地图档案
/atlas settings – 打开设置
/atlas style <1-6> – 选择未探索地图的样式
/atlas radius <1-8> – 设置探索半径（格）
/atlas opacity <10-100> – 设置未探索地图的不透明度（%）
也可使用简写 /ae。

德语命令仍然可用，例如 /atlas hilfe、/atlas an、/atlas aufdecken。
]],
    ENABLED = "Atlas 已启用。",
    DISABLED = "Atlas 已禁用。",
    CURRENT_MAP_REVEALED = "当前地图已完全揭开。",
    CURRENT_MAP_CLEARED = "当前地图的探索记录已清除。",
    NO_MAP = "目前无法识别可用的地图区域。",
    STATUS = "地图：%s | 已探索：%d / %d 格（%.1f%%）| 样式：%s",
    STYLE_SET = "未探索地图样式：%s",
    RADIUS_SET = "探索半径：%d 格。",
    OPACITY_SET = "不透明度：%d%%。",
    BAD_VALUE = "输入值无效。请使用 /atlas help。",
    ARCHIVE_TITLE = "地图档案",
    ARCHIVE_SUBTITLE = "Atlas 曾经记录过探索区域的所有地图。",
    ARCHIVE_COUNT = "已保存 %d 张地图",
    ARCHIVE_EMPTY = "尚未保存探索过的地图。",
    ARCHIVE_PAGE = "第 %d / %d 页",
    ARCHIVE_PREV = "上一页",
    ARCHIVE_NEXT = "下一页",
    ARCHIVE_VARIANT_LABEL = "地图 %d · ID %s",
    ARCHIVE_GROUP_EXPAND_HINT = "点击展开各张地图或楼层。",
    ARCHIVE_GROUP_COLLAPSE_HINT = "点击收起此地图分组。",
    ARCHIVE_FORGET = "忘记地图",
    ARCHIVE_FORGET_HINT = "仅清除此地图的 Atlas 探索记录，操作前需要确认。",
    ARCHIVE_MAP_CLEARED = "已清除“%s”的探索进度。",
    ARCHIVE_OPEN_HINT = "左键：打开地图。右键：完全揭示或忘记地图。",
    ARCHIVE_REVEAL = "完全揭示地图",
    ARCHIVE_MAP_REVEALED = "已完全揭示地图“%s”。",
    ARCHIVE_MENU_UNAVAILABLE = "地图菜单不可用，数据未更改。",
    ARCHIVE_OPEN_FAILED = "ESO 不允许从这里直接打开此地图。Atlas 会继续将其保存在档案中。",
    ARCHIVE_UNRESOLVED = "Atlas 已记录此地图，但尚未匹配 ESO 地图 ID。再次访问时会自动关联。",
    ARCHIVE_RESOLVING = "Atlas 正在后台将旧地图记录与 ESO 地图 ID 匹配…",
    ARCHIVE_PATH = "保存位置：%s",
    ARCHIVE_UNKNOWN_MAP = "未知地图",
    IMPORT_NO_TE = "未加载 TrueExploration 数据。请同时启用 TrueExploration 和 Atlas，重新加载界面后再导入。",
    IMPORT_START = "正在检查 TrueExploration 导入…",
    IMPORT_DONE = "导入完成：找到 %d 张地图，合并 %d 张，新增 %d 格，无法识别 %d 项。",
    IMPORT_NONE = "未找到当前角色的 TrueExploration 档案。请同时启用 TrueExploration 和 Atlas 并重新加载界面。",
    IMPORT_NONE_ALL = "TE_SavedVars 中没有找到 TrueExploration 地图数据表。",
    IMPORT_ALL_WARNING = "将找到的所有 TrueExploration 档案合并到当前角色。",
    STYLE_NAMES = { "羊皮纸", "浅色纸张", "深色羊皮纸", "灰色迷雾", "炭笔", "深黑" },
    STYLE_VALUES = AE.LanguageStyleValues,
    STYLE_TOOLTIPS = {
        "羊皮纸——带有褪色罗盘和导航图案的古老探险地图",
        "浅色纸张——带有精细测绘线和刻度的制图纸",
        "深色羊皮纸——海岸线与折痕褪色的古旧航海图",
        "灰色迷雾——带有细微等高线和柔和雾气的冷灰色地图",
        "炭笔——手绘路径与旧路标点缀的粗糙炭笔纸",
        "深黑——带有低调星光与导航纹理的神秘夜色地图",
    },
    OPTION_LANGUAGE = "语言",
    OPTION_LANGUAGE_TT = "仅选择 Atlas 的显示语言。自动模式跟随 ESO，不会改变游戏或其他插件的语言。",
    LANGUAGE_AUTO = "自动（跟随 ESO）",
    SETTINGS_VERSION = "版本 %s",
    SETTINGS_TITLE = "Atlas - 设置",
    SETTINGS_GENERAL_HEADER = "常规",
    SETTINGS_APPEARANCE_HEADER = "外观",
    SETTINGS_EXPLORATION_HEADER = "探索",
    SETTINGS_DEFAULTS = "恢复默认",
    SETTINGS_DEFAULTS_TT = "恢复 Atlas 的默认设置，不会删除已保存的探索进度。",
    SETTINGS_CLOSE = "关闭",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "打开 Atlas 设置",
    SETTINGS_SELECTED_STYLE = "%s：%s",
    OPTION_DESCRIPTION = "世界地图最初处于未探索状态，仅在角色到过的位置逐渐显示。探索进度按角色保存；外观设置在账号内共用。",
    OPTION_ENABLED = "启用 Atlas",
    OPTION_ENABLED_TT = "遮盖未探索的地图区域，并在旅行过程中逐步揭开。",
    OPTION_STYLE = "未探索地图样式——预览",
    OPTION_STYLE_TT = "点击预览图，查看全部地图样式缩略图并选择。",
    OPTION_SELECTED = "已选择",
    OPTION_OPACITY = "未探索地图不透明度",
    OPTION_OPACITY_TT = "100% 会完全遮盖原地图。调低后可隐约看到原图。",
    OPTION_RADIUS = "探索半径——大地图",
    OPTION_RADIUS_TT = "角色周围在 48×48 网格上被揭开的格数。",
    OPTION_SUBZONES = "探索城市、地下城与子地图",
    OPTION_SUBZONES_TT = "启用后，子地图也会从未探索状态开始。",
    OPTION_SUBRADIUS = "探索半径——子地图",
    OPTION_SUBRADIUS_TT = "子地图通常较小，可以单独设置更大的探索半径。",
    OPTION_CURRENT_HEADER = "当前地图",
    OPTION_REVEAL = "完全揭开当前地图",
    OPTION_REVEAL_TT = "将当前显示的地图标记为完全探索。",
    OPTION_CLEAR = "忘记当前地图",
    OPTION_CLEAR_TT = "仅清除当前显示地图的 Atlas 探索记录。",
    CONFIRM_CLEAR_TITLE = "忘记地图探索记录？",
    CONFIRM_CLEAR_TEXT = "确定要清除地图“<<1>>”的全部 Atlas 探索进度吗？此操作无法撤销。",
    CONFIRM_CLEAR_ACCEPT = "忘记地图",
    CONFIRM_CLEAR_CANCEL = "取消",
    CONFIRM_CLEAR_UNAVAILABLE = "无法显示确认窗口。未删除任何探索数据。",

    OPTION_IMPORT_HEADER = "TrueExploration 导入",
    OPTION_IMPORT_DESC = "导入功能只读取 TrueExploration 数据，不会修改原始数据。导入当前角色前，请同时启用 TrueExploration 与 Atlas 并重新加载界面。Atlas 支持 48×48 网格的 31 位存储格式，并自动合并只有大小写差异的地图路径。",
    OPTION_IMPORT_CURRENT = "导入当前角色",
    OPTION_IMPORT_CURRENT_TT = "推荐：仅导入当前登录角色的 TrueExploration 数据。",
    OPTION_IMPORT_ALL = "合并所有旧档案",
    OPTION_IMPORT_ALL_TT = "将找到的所有 TrueExploration 地图合并到当前角色，绝不删除已有的 Atlas 格子。",
    OPTION_COMMANDS_HEADER = "聊天命令",
    OPTION_COMMANDS = "/atlas   /atlas help   /atlas reveal   /atlas forget   /atlas import   /atlas status\n/atlas style 1-6   /atlas radius 1-8   /atlas opacity 10-100",
}
