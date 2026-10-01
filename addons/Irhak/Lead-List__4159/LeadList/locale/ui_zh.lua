-- Notes to Translators:
--   - You will have to create a copy of this file and change it's name to your language. Then translate stuff in that file.
--     List of languages and resulting file names:
--       German: ui_de.lua
--       French: ui_fr.lua
--       Russian: ui_ru.lua
--       Japanese: ui_jp.lua
--       Spanish: ui_es.lua
--       Portuguese: ui_br.lua
--       Polish: ui_pl.lua
--   - /n is newline. It might not work/diplay correctly in all entries. Tooltips should be safe.
--   - %s %d are substitution commands that Addon will replace with dynamic values. They need to stay in translation!
--   - |c ... |r is for coloring text. They need to stay in translation!
--   - Tables/Lists marked "LOOP" are displayed via for loop.  Meaning you can add/remove lines if advantageous for translation
--     If you need to add lines for one not marked loop try /n for newline inside the string
--     If you hit a wall with /n. Let me know. Some additional ones could be changed to LOOP implementation
--   - A lot of UI Elements are fixed width and rather narrow. I know might make translating hard. Please try to fit. 
--     Worst come worst. I might be able to make dimensions as part of the language files. But this would be quite some work I fear. Please try to fit.
--   - Working iterative might be time consuming (Translate some values. Save. /reloadui in game). But safer. 
--     Changing a hundred things. Then /reloadui and nothing works anymore. And trying to figure out which of the 100 changes was the culprit is not pleasant. 
ILeadList = ILeadList or {}
local ILL = ILeadList

ILL.ZONENAME_ALLZONES = "所有区域"
ILL.ZONENAME_BGS = "战场"

ILL.KEYBINDINGTEXT = "切出线索查询窗口"

-- UI Filter Elements (Dropdowns) 	

ILL.DropdownTooltips = {
	major = "复杂筛选条件",
	zone = "按区域筛选",
	settype = "按套装或古物类型筛选",
}

ILL.DropdownData = {
	ChoicesMajor  = { "可发现", "可占卜", "缺失宝典条目", "从未挖掘过", "可执行线索", "所有线索", "组队地牢", "最新DLC",},
  
	TooltipsMajor  = {
		"排除已发现但未占卜的线索，以及已发现的不可重复获得的线索",
		"只显示已发现但还未占卜的线索",
		"只显示考古宝典条目存在缺失的条目",
		"只显示从还未挖掘过的古物",
		"显示除已完成的不可重复获得的线索之外的其他所有线索",
		"显示包括已完成的不可重复获得的线索的所有线索",
		"只显示从4人地牢中获得的线索",
		"只显示最新DLC的新线索",
	},
	
	ChoicesZone = {ILL.ZONENAME_ALLZONES, "当前区域", "最新DLC", "排除次要DLC", "Event Zone"},
	TooltipsZone = { 
		"显示所有区域的线索",
		"只显示与当前区域有关的线索",
		"只显示最新DLC的新线索",
		"只显示与基础区域或章节区域有关的线索",
	},
	TooltipsZoneGenerated = "只显示与 %s 有关的线索",
	ChoicesSetType  = { "所有", "隐藏简单类", "组合古物",},
	TooltipsSetType   = {
		"显示所有类型和套装的线索",
		"隐藏古地图、免费宝物线索及样式页\n但如果在'可占卜'主模式下，则仅隐藏普通绿色宝物",
		"仅显示组合古物的线索",
	},
	TooltipsSetTypeGenerated = "仅显示 %s 类型/套装的线索",
}

-- Alerts Label

ILL.LABEL_ALERTS_UD_MISSING = "|c%s警告 : %d 7天; %d 1天; %d 1小时|r"

ILL.LABEL_ALERTS = "|c%s警告 : %d <7天; %d <1天; %d <1小时; Codex: %d|r"

-- LOOP
ILL.TOOLTIP_ALERTS_UD_MISSING = {
	"UndauntedDaily插件缺失！无法",
	"计算日常任务是否有线索给你",
}

ILL.TOOLTIP_ALERTS_1HOUR = "线索过期<1小时: %d"
ILL.TOOLTIP_ALERTS_1DAY = "线索过期<1天: %d"
ILL.TOOLTIP_ALERTS_7DAYS = "线索过期<7天: %d"
ILL.TOOLTIP_ALERTS_TOTALCM = "Total missing codex entries: %d"
ILL.TOOLTIP_ALERTS_TOTALMAP = "---including from treasure maps: %d"
ILL.TOOLTIP_ALERTS_TOTALEA = "---including from Infinite Archive: %d"
ILL.TOOLTIP_ALERTS_UD_NONEFOUND = "闯世者日常无线索给你"
ILL.TOOLTIP_ALERTS_UD_SCRYFIRST = " (您已拥有此线索，请先占卜/挖掘)"

ILL.LABEL_URL_INITIAL = "目前为止没有发现线索"
ILL.LABEL_URL_LEADFOUND = "|c3A92FF报告最新的线索，使用ID %d|r"

-- LOOP
ILL.TOOLTIP_URL = {
	"为了顺畅地报告新地点: ",
	"如您找到一个线索，本插件将:",
	" - 将线索ID信息贴出到此框内",
	" - 将当前地点贴出到右边的栏中",
	"   (如果我认为位置信息是完整的，它将发布一个请求",
	"    以确认你的信息确实是最新的)",
	" - 如果你是在别处发现此线索的，请您:",
	"   - 删除编辑框中的内容",
	"   - 描述你的位置",
	"   - 点击这里的栏",
	"插件将:",
	" - 将信息转化为URL",
	" - 同意ZOS的弹出框后用浏览器打开URL",
}

ILL.EDITBOX_INITIAL = "如果你找到新位置: 替换将出现在这里的内容; 单击左侧的标签发送到浏览器"
ILL.EDITBOX_LOCATION_DATA_COMPLETE = "位置信息被认为是完整的。请仅在确认您的发现未被现有描述涵盖后提交"
ILL.EDITBOX_NO_LEAD_FOUND_OR_SELECTED = "首先找到一个线索，或单击要报告的线索行"
ILL.EDITBOX_NOT_EDITED = "提交新发现: 首先用新位置替换此编辑框中的内容。然后单击左侧的标签。"
ILL.EDITBOX_LOCDATA_EMPTY = "您需要在此编辑框中输入您的新位置。然后单击左侧的标签。"
ILL.EDITBOX_THANKS = "感谢您提交新的位置数据"

ILL.SORTHEADER_NAMES = { "线索", "区域", "地点", "知识", "挖掘", "套装", "过期", }
ILL.SORTHEADER_TOOLTIP = {
	"古物的名称",
	"可找到/占卜线索的区域",
	"简短的位置描述\n(D) = 洞穴\n(PD) = 公共地牢\n(GD) = 组队地牢\n(WB) = 世界Boss",
	"还有多少知识/宝典条目缺失",
	"该古物已被挖出多少次",
	"组合古物组装完成后的物品名。\n或单线索古物的类型",
	"线索过期剩余时间。\n某些线索在获得后的前几天过期时间不会减少。",
}

-- LOOP
ILL.TOOLTIP_LEAD_HOWUPDATE = {
	"如果你知道其他的获取位置:",
	"单击行以激活该线索的位置数据更新。",
	"将编辑框内容替换为您的位置，然后单击左侧的标签"
}

-- LOOP
ILL.TOOLTIP_INKLING = {
	"原始位置数据由@inklings提供 (Discord, Twitch)",
	"非常感谢你让我使用这些数据",
}

ILL.TOOLTIP_MAPPINS = "已包含在Hoft的MapPins插件中"

ILL.FREERUNNER_INFO = "!!! Any older lead have a chance to drop from Frerunners favor, Nowhere Vault's chests or High Seas event bosses on top of the regular drop spot listed below !!!"

