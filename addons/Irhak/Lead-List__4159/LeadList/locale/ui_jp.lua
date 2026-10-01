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

ILL.ZONENAME_ALLZONES = "すべてのゾーン"
ILL.ZONENAME_BGS = "バトルグランド"

ILL.KEYBINDINGTEXT = "手掛かり調査ウィンドウを切り替える"

-- UI Filter Elements (Dropdowns) 	

ILL.DropdownTooltips = {
	major = "複雑な基準でフィルタリング",
	zone = "ゾーンでフィルタリング",
	settype = "古代のセットまたはタイプでフィルタリング",
}

ILL.DropdownData = {
	ChoicesMajor  = { "手掛かり入手可能", "手掛かり入手済み", "コーデックスエントリ欠落", "古遺物全て入手済み", "実用的な手掛かり", "全ての手掛かり", "グループダンジョン", "ハイアイル",},
  
	TooltipsMajor  = {
		"見つかったが本に書かれていない手掛かり、およびすでに一度見つかった繰り返し不可能な手掛かりを除外",
		"見つかったがまだ検索されていない手掛かりのみを表示",
		"コーデックスエントリが欠落している手掛かりを表示",
		"まだ掘り出していない手掛かりを表示",
		"全て終わり採掘できなくなったものを除くすべての手掛かりを表示",
		"全て終わり採掘できなくなったものを含むすべての手掛かりを表示",
		"4人のダンジョンからの手掛かりのみを表示",
		"デッドランドからの手掛かりのみを表示",
	},
	
	ChoicesZone = {ILL.ZONENAME_ALLZONES, "現在のゾーン", "マイナーDLCを除外する", "Event Zone",},
	TooltipsZone = { 
		"すべてのゾーンからの手掛かりを表示",
		"現在のゾーンに関連する手掛かりのみを表示",
		"ベースゾーンとチャプターに関連する手掛かりのみを表示",
	},
	TooltipsZoneGenerated = "%sに関連する手掛かりのみを表示",
	ChoicesSetType  = { "全て", "明白なものを隠す", "アンティーク",},
	TooltipsSetType   = {
		"すべてのタイプとセットを表示",
		"アンティークマップ、無料のトレジャー手掛かり、およびモチーフの章を非表示\n「入手済み」メジャーモードの場合を除きます。 次に、組み込みのGreenTreasureのみを非表示",
		"アンティークの手掛かりのみを表示",
	},
	TooltipsSetTypeGenerated = "タイプ/セットの手掛かりのみを表示 %s",
}

-- Alerts Label

ILL.LABEL_ALERTS_UD_MISSING = "|c%sアラート : %d 7D; %d 1D; %d 1H|r"

ILL.LABEL_ALERTS = "|c%sアラート : %d ,7D; %d <1D; %d <1H; Codex: %d|r"

-- LOOP
ILL.TOOLTIP_ALERTS_UD_MISSING = {
	"[UndauntedDaily] アドオンがありません！ できません",
	"デイリークエストの手掛かりを持っているかどうかを計算します",
}

ILL.TOOLTIP_ALERTS_1HOUR = "1時間未満で期限切れになる手掛かり : %d"
ILL.TOOLTIP_ALERTS_1DAY = "1日未満で期限切れになる手掛かり : %d"
ILL.TOOLTIP_ALERTS_7DAYS = "1週間未満で期限切れになる手掛かり : %d"
ILL.TOOLTIP_ALERTS_TOTALCM = "Total missing codex entries: %d"
ILL.TOOLTIP_ALERTS_TOTALMAP = "---including from treasure maps: %d"
ILL.TOOLTIP_ALERTS_TOTALEA = "---including from Infinite Archive: %d"
ILL.TOOLTIP_ALERTS_UD_NONEFOUND = "アンドーンテッドデイリーの手掛かりはありません"
ILL.TOOLTIP_ALERTS_UD_SCRYFIRST = " (あなたはすでにこの手掛かりを持っています)"

ILL.LABEL_URL_INITIAL = "まだ手掛かりは発見されていません"
ILL.LABEL_URL_LEADFOUND = "|c3A92FFIDを使用して最新の手掛かりを報告する %d|r"

-- LOOP
ILL.TOOLTIP_URL = {
	"To streamline reporting new locations: ",
	"If you find a Lead this Addon will:",
	" - post Lead ID Info into this Box",
	" - post existing Location into Field to the right",
	"   (if I thought Location Info was complete it will post ",
	"    a plea instead to doublecheck your info really is new)",
	" - If you found the Lead elsewhere please:",
	"   - remove what is in EditField",
	"   - describe your Location",
	"   - Click this Field here",
	"Addon will then:",
	" - transmogrify info into an URL",
	" - open URL in browser after you consent to ZOS Popup",
}

ILL.EDITBOX_INITIAL = "If you find NEW Location: Replace what will appear here; Click Label on left to send to browser"
ILL.EDITBOX_LOCATION_DATA_COMPLETE = "Location Info considered complete. Please only Submit if your find is not already covered by existing description"
ILL.EDITBOX_NO_LEAD_FOUND_OR_SELECTED = "Find a lead first, or Click Row of Lead you would like to report"
ILL.EDITBOX_NOT_EDITED = "To submit new find: Replace what is in this Editbox with your new Location first. Then click Label to the left."
ILL.EDITBOX_LOCDATA_EMPTY = "You need to enter your new Location into this Editbox. Then click Label to the left."
ILL.EDITBOX_THANKS = "Thank you for submitting new Location data"

ILL.SORTHEADER_NAMES = { "Lead", "Zone", "Location", "Lore", "Dug", "Set", "Expiration", }
ILL.SORTHEADER_TOOLTIP = {
	"Name of the Antiquity",
	"Zone where Lead can be found/scried",
	"Short Location Description\n(D) = Delve\n(PD) = Public Dungeon\n(GD) = Group Dungeon\n(WB) = World Boss",
	"How many Lore/Codex Entries are still missing",
	"How many times has the antiquity been dug out already",
	"Name of the Set that will be rewarded if multipart Antiquity\n. Or type of Reward if single Lead Antiquity",
	"Time until Lead expires.\n For some Leads expiraton time does not go down for the first couple of days.",
}

-- LOOP
ILL.TOOLTIP_LEAD_HOWUPDATE = {
	"If you know about additional Location:",
	"Click Row to activate Location Data Update for this Lead.",
	"Replace Editbox content with your Location then click Label to the left of it"
}

-- LOOP
ILL.TOOLTIP_INKLING = {
	"Original Location Data provided by @inklings (Discord, Twitch)",
	"Thanks a lot for letting me use it",
}

ILL.TOOLTIP_MAPPINS = "Included in Hoft's MapPins Addon"

ILL.FREERUNNER_INFO = "!!! Any older lead have a chance to drop from Frerunners favor, Nowhere Vault's chests or High Seas event bosses on top of the regular drop spot listed below !!!"

