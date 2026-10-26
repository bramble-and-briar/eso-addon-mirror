-- AI Research Grid Addon for Elder Scrolls Online
-- Author: Stormknight/LCAmethyst
-- "All" and "Relative"  functionality by His Dad
-- Dwemer Motif by rkuhnjr
-- Dwemer Motif By garkin
-- French Translation by Motsah
-- Fixes by mpavlinsky
-- Close on Esc code by Wandamey
-- Glass, Xivkyn, Ancient Orc, and Mercenary Akaviri added in by Scinutz
-- Code clean & lot of stuff reworked by Ayantir
-- AM - 4 new motifs (Coldsnap, Meridian, Anequine, Pellitine)
-- AM - 4 new motifs (Pyandonean, Psijic, Fang Lair and Sapiarch)
-- AM - Minor code cleanup, single table now holds style buttons
-- AM - styleOrder table implemented to keep style order fixed
-- AM - added Jewelry Crafting tracking
-- AM - added Tsaesci motif (crown store purchase)
-- AM - added multiple motifs
-- AM - Added Dead-water motif
-- AM - continuing maintenance
-- Dynamic styles & auto-update refactoring

local ADDON_NAME = "AIResearchGrid"
local db

local playerName = GetUnitName("player")
local curCharacter = playerName
local currentCraft = CRAFTING_TYPE_WOODWORKING
local mergedCharacters = "#ALL"
local mergedCharactersData = {}
	  mergedCharactersData.traits = {}
	  mergedCharactersData.styles = {}
local showRelative = false
local relative = {}
local maxColumns
local AIRG_UI = {}
local apiVersion
local playerActivated = false

local TRAIT_KNOWN = -1
local TRAIT_UNKNOWN = 0

local AIRG_STYLE_BASIC = 1
local AIRG_STYLE_CHAPTERIZED = 2
local AIRG_STYLE_CROWNSTORE = 3

local BLACKSMITHING_RESEARCH_LEVEL
local CLOTHIER_RESEARCH_LEVEL
local WOODWORKING_RESEARCH_LEVEL
local JEWELRYCRAFTING_RESEARCH_LEVEL

local CRAFTING_TYPE_MOTIFS = CRAFTING_TYPE_MAX_VALUE + 1

local bHideKnownStyles = false

local LCK = LibCharacterKnowledge
local LCKInitialized = false
LCK.RegisterForCallback("AIResearchGrid", LCK.EVENT_INITIALIZED, function( ) LCKInitialized=true end)
local LCKRetryCounter = 0
local LCK_MAX_RETRY_COUNT = 30

-- Defaults options for saved variables
local defaults = {
	showMotifs = true,
	stylesCache = {},
	dynamicStyles = {},
	char = {
		[playerName] = {},
	},
}

-- Index of the line in our grid for a specific trait
local gridTraits = {
	[ITEM_TRAIT_TYPE_WEAPON_POWERED] = 1,
	[ITEM_TRAIT_TYPE_WEAPON_CHARGED] = 2,
	[ITEM_TRAIT_TYPE_WEAPON_PRECISE] = 3,
	[ITEM_TRAIT_TYPE_WEAPON_INFUSED] = 4,
	[ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = 5,
	[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = 6,
	[ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = 7,
	[ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = 8,
	[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = 9,
	[ITEM_TRAIT_TYPE_ARMOR_STURDY] = 10,
	[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = 11,
	[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = 12,
	[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = 13,
	[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = 14,
	[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = 15,
	[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = 16,
	[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = 17,
	[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = 18,
}
local gridTraitsJC = {
	[ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = 1,
	[ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = 2,
	[ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = 3,
	[ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = 4,
	[ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = 5,
	[ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = 6,
	[ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = 7,
	[ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = 8,
	[ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = 9,
}

-- Display Order in tooltip
local styleChaptersLookup = {
	[1] = ITEM_STYLE_CHAPTER_AXES,
	[2] = ITEM_STYLE_CHAPTER_BELTS,
	[3] = ITEM_STYLE_CHAPTER_BOOTS,
	[4] = ITEM_STYLE_CHAPTER_BOWS,
	[5] = ITEM_STYLE_CHAPTER_CHESTS,
	[6] = ITEM_STYLE_CHAPTER_DAGGERS,
	[7] = ITEM_STYLE_CHAPTER_GLOVES,
	[8] = ITEM_STYLE_CHAPTER_HELMETS,
	[9] = ITEM_STYLE_CHAPTER_LEGS,
	[10] = ITEM_STYLE_CHAPTER_MACES,
	[11] = ITEM_STYLE_CHAPTER_SHIELDS,
	[12] = ITEM_STYLE_CHAPTER_SHOULDERS,
	[13] = ITEM_STYLE_CHAPTER_STAVES,
	[14] = ITEM_STYLE_CHAPTER_SWORDS,
}

-- Die 15 Basis-Stile (ohne Kapitel) in fester Reihenfolge
local BASIC_STYLE_ORDER = {
	ITEMSTYLE_RACIAL_BRETON,
	ITEMSTYLE_RACIAL_REDGUARD,
	ITEMSTYLE_RACIAL_ORC,
	ITEMSTYLE_RACIAL_DARK_ELF,
	ITEMSTYLE_RACIAL_NORD,
	ITEMSTYLE_RACIAL_ARGONIAN,
	ITEMSTYLE_RACIAL_HIGH_ELF,
	ITEMSTYLE_RACIAL_WOOD_ELF,
	ITEMSTYLE_RACIAL_KHAJIIT,
	ITEMSTYLE_AREA_ANCIENT_ELF,
	ITEMSTYLE_AREA_REACH,
	ITEMSTYLE_ENEMY_PRIMITIVE,
	ITEMSTYLE_ENEMY_DAEDRIC,
	ITEMSTYLE_RACIAL_IMPERIAL,
	ITEMSTYLE_AREA_SOUL_SHRIVEN,
}

local BASIC_STYLES = {}
for _, sId in ipairs(BASIC_STYLE_ORDER) do
	if sId then BASIC_STYLES[sId] = true end
end

-- Bekannte Crown-Store-Gesamtstile (ohne Kapitel)
local CROWN_STORE_ORDER = {
	ITEMSTYLE_HOLIDAY_GRIM_HARLEQUIN,
	ITEMSTYLE_HOLIDAY_FROSTCASTER,
	ITEMSTYLE_AREA_TSAESCI,
}

local CROWN_STORE_STYLES = {}
for _, sId in ipairs(CROWN_STORE_ORDER) do
	if sId then CROWN_STORE_STYLES[sId] = true end
end

-- Bekannte Errungenschafts-IDs als statischer Fallback
local KNOWN_ACHIEVEMENTS = {
	[ITEMSTYLE_AREA_DWEMER or 16] = 1144,
	[ITEMSTYLE_GLASS or 17] = 1319,
	[ITEMSTYLE_AREA_XIVKYN or 18] = 1181,
	[ITEMSTYLE_AREA_ANCIENT_ORC or 19] = 1341,
	[ITEMSTYLE_AREA_AKAVIRI or 20] = 1318,
	[ITEMSTYLE_UNDAUNTED or 21] = 1348,
	[ITEMSTYLE_DEITY_MALACATH or 22] = 1412,
	[ITEMSTYLE_DEITY_TRINIMAC or 23] = 1411,
	[ITEMSTYLE_ORG_OUTLAW or 24] = 1417,
	[ITEMSTYLE_ALLIANCE_EBONHEART or 25] = 1414,
	[ITEMSTYLE_ALLIANCE_ALDMERI or 26] = 1415,
	[ITEMSTYLE_ALLIANCE_DAGGERFALL or 27] = 1416,
	[ITEMSTYLE_ORG_ABAHS_WATCH or 28] = 1422,
	[ITEMSTYLE_ORG_THIEVES_GUILD or 29] = 1423,
	[ITEMSTYLE_ORG_ASSASSINS or 30] = 1424,
	[ITEMSTYLE_ENEMY_DROMOTHRA or 31] = 1659,
	[ITEMSTYLE_DEITY_AKATOSH or 32] = 1660,
	[ITEMSTYLE_ORG_DARK_BROTHERHOOD or 33] = 1661,
	[ITEMSTYLE_ENEMY_MINOTAUR or 34] = 1662,
	[ITEMSTYLE_RAIDS_CRAGLORN or 35] = 1714,
	[ITEMSTYLE_ENEMY_DRAUGR or 37] = 1715,
	[ITEMSTYLE_AREA_YOKUDAN or 38] = 1713,
	[ITEMSTYLE_HOLIDAY_HOLLOWJACK or 39] = 1545,
	[ITEMSTYLE_HOLIDAY_SKINCHANGER or 40] = 1676,
	[ITEMSTYLE_EBONY or 41] = 1798,
	[ITEMSTYLE_AREA_RA_GADA or 42] = 1797,
	[ITEMSTYLE_ENEMY_SILKEN_RING or 43] = 1796,
	[ITEMSTYLE_ENEMY_MAZZATUN or 46] = 1795,
	[ITEMSTYLE_ORG_MORAG_TONG or 47] = 1933,
	[ITEMSTYLE_ORG_ORDINATOR or 48] = 1935,
	[ITEMSTYLE_ORG_BUOYANT_ARMIGER or 49] = 1934,
	[ITEMSTYLE_AREA_ASHLANDER or 50] = 1932,
	[ITEMSTYLE_ORG_REDORAN or 51] = 2022,
	[ITEMSTYLE_ORG_HLAALU or 52] = 2021,
	[ITEMSTYLE_ORG_TELVANNI or 53] = 2023,
	[60] = 2024,
	[ITEMSTYLE_ORG_WORM_CULT or 59] = 2120,
	[61] = 2098, [62] = 2097, [65] = 2044, [66] = 2045, [69] = 2190,
	[70] = 2189, [71] = 2186, [72] = 2187, [73] = 2319, [74] = 2188,
	[75] = 2285, [77] = 2317, [78] = 2318, [79] = 2360, [80] = 2359,
	[81] = 2361, [82] = 2503, [83] = 2504, [84] = 2505, [85] = 2506,
	[86] = 2507, [89] = 2629, [92] = 2630, [93] = 2628, [94] = 2748,
	[95] = 2750, [97] = 2747, [98] = 2749, [100] = 2757, [101] = 2761,
	[102] = 2762, [103] = 2763, [104] = 2773, [105] = 2776, [106] = 2849,
	[107] = 2850, [108] = 2903, [109] = 2904, [110] = 2905, [111] = 2926,
	[112] = 2938, [113] = 2998, [114] = 2959, [116] = 2984, [117] = 2991,
	[119] = 2999, [120] = 3000, [121] = 3001, [122] = 3002, [123] = 3094,
	[124] = 3097, [125] = 3098, [126] = 3220, [128] = 3228, [129] = 3229,
	[130] = 3258, [131] = 3259, [132] = 3260, [135] = 3422, [136] = 3423,
	[138] = 3464, [139] = 3465, [140] = 3546, [141] = 3547, [142] = 3667,
	[143] = 3668, [144] = 3669, [145] = 3921, [146] = 3922, [147] = 3923,
	[148] = 3924, [149] = 3925, [153] = 4159, [154] = 4160, [155] = 4240,
	[156] = 4241, [157] = 4242, [158] = 4289, [159] = 4290,
}

local styles = {}
local styleOrder = {}

-- Dynamische Suche nach der 14-Kapitel-Errungenschaft eines Stils
local function ScanForAchievement(styleName)
	if not styleName or styleName == "" then return nil end
	local sNameLower = styleName:lower()
	local numCats = GetNumAchievementCategories()
	for cat = 1, numCats do
		local _, numSub, numAch = GetAchievementCategoryInfo(cat)
		for i = 1, numAch do
			local aId = GetAchievementId(cat, nil, i)
			if aId and aId > 0 and GetAchievementNumCriteria(aId) == 14 then
				local aName = GetAchievementInfo(aId)
				if aName and zo_plainstrfind(aName:lower(), sNameLower) then
					return aId
				end
			end
		end
		for sub = 1, numSub do
			local _, subAch = GetAchievementSubCategoryInfo(cat, sub)
			for i = 1, subAch do
				local aId = GetAchievementId(cat, sub, i)
				if aId and aId > 0 and GetAchievementNumCriteria(aId) == 14 then
					local aName = GetAchievementInfo(aId)
					if aName and zo_plainstrfind(aName:lower(), sNameLower) then
						return aId
					end
				end
			end
		end
	end
	return nil
end

-- Dynamisches Ermitteln aller gültigen Handwerksstile über die ESO-API
local function BuildDynamicStyles()
	styles = {}
	styleOrder = {}

	local basicOrder = {}
	local crownOrder = {}
	local chapterOrder = {}

	db.stylesCache = db.stylesCache or {}

	local candidateStyleIds = {}
	if GetNumValidItemStyles and GetValidItemStyleId then
		local numValid = GetNumValidItemStyles()
		for i = 1, numValid do
			local sId = GetValidItemStyleId(i)
			if sId and sId > 0 then
				table.insert(candidateStyleIds, sId)
			end
		end
	else
		local maxStyleId = (GetHighestItemStyleId and GetHighestItemStyleId()) or 200
		for sId = 1, maxStyleId do
			table.insert(candidateStyleIds, sId)
		end
	end

	for _, styleId in ipairs(candidateStyleIds) do
		-- Stil 0 (None) und Stil 36 (Universal/Kronen-Mimenstein) überspringen
		if styleId ~= ITEMSTYLE_NONE and styleId ~= (ITEMSTYLE_UNIVERSAL or 36) then
			local styleName = GetItemStyleName(styleId)
			local stoneItemLink = GetItemStyleMaterialLink(styleId, LINK_STYLE_DEFAULT)
			local stoneTexture = (stoneItemLink and stoneItemLink ~= "") and GetItemLinkInfo(stoneItemLink) or ""

			if styleName and styleName ~= "" and not zo_plainstrfind(styleName:lower(), "reuse") and stoneTexture ~= "" then
				local stype
				local achiev = nil

				if BASIC_STYLES[styleId] then
					stype = AIRG_STYLE_BASIC
					table.insert(basicOrder, styleId)
				elseif CROWN_STORE_STYLES[styleId] then
					stype = AIRG_STYLE_CROWNSTORE
					table.insert(crownOrder, styleId)
				else
					stype = AIRG_STYLE_CHAPTERIZED
					achiev = KNOWN_ACHIEVEMENTS[styleId] or db.stylesCache[styleId]
					if not achiev then
						achiev = ScanForAchievement(styleName)
						if achiev then
							db.stylesCache[styleId] = achiev
						end
					end
					table.insert(chapterOrder, styleId)
				end

				styles[styleId] = {
					stype = stype,
					achiev = achiev,
					name = styleName,
				}
			end
		end
	end

	-- Basis- und Kronen-Stile in ihrer definierten Standard-Reihenfolge anordnen
	local sortedBasic = {}
	for _, sId in ipairs(BASIC_STYLE_ORDER) do
		if styles[sId] then table.insert(sortedBasic, sId) end
	end
	for _, sId in ipairs(basicOrder) do
		if not BASIC_STYLES[sId] then table.insert(sortedBasic, sId) end
	end

	local sortedCrown = {}
	for _, sId in ipairs(CROWN_STORE_ORDER) do
		if styles[sId] then table.insert(sortedCrown, sId) end
	end
	for _, sId in ipairs(crownOrder) do
		if not CROWN_STORE_STYLES[sId] then table.insert(sortedCrown, sId) end
	end

	table.sort(chapterOrder)

	for _, sId in ipairs(sortedBasic) do table.insert(styleOrder, sId) end
	for _, sId in ipairs(sortedCrown) do table.insert(styleOrder, sId) end
	for _, sId in ipairs(chapterOrder) do table.insert(styleOrder, sId) end

	db.dynamicStyles = {}
	for _, sId in ipairs(styleOrder) do
		table.insert(db.dynamicStyles, {
			id = sId,
			name = styles[sId].name,
			stype = styles[sId].stype,
			achiev = styles[sId].achiev,
		})
	end
end

-- Set the icon highlights for the currently selected character
local function UpdateMotifsUI()

	local styleItemId, styleStoreId, styleChapterId = 1, 1, 1

	local sourceData = {}
	if curCharacter == mergedCharacters then
		sourceData = mergedCharactersData
	else
		sourceData = db.char[curCharacter]
	end

	if sourceData and sourceData.styles then
		for styleId, styleData in pairs(sourceData.styles) do

			if styles[styleId] and (not styles[styleId].api or apiVersion >= styles[styleId].api) then

				local tooltipText = ""
				local stoneItemLink = GetItemStyleMaterialLink(styleId)
				local itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(stoneItemLink))
				local _, _, _, _, itemStyle = GetSmithingStyleItemInfo(styleId)

				if AIRG_UI.StyleButtons[styleId] then
					if styles[styleId].stype == AIRG_STYLE_BASIC then
						local isKnown = (type(styleData) == "boolean") and styleData or false
						if not isKnown then
							AIRG_UI.StyleButtons[styleId]:SetColor(1, 0, 0, 1)
						else
							AIRG_UI.StyleButtons[styleId]:SetColor(1, 1, 1, 1)
							AIRG_UI.StyleButtons[styleId]:SetHidden(bHideKnownStyles)
						end

						tooltipText = zo_strformat("<<t:1>>\n<<t:2>>", GetItemStyleName(itemStyle), itemName)
						AIRG_UI.StyleButtons[styleId]:SetHandler("OnMouseEnter", function (self)
							ZO_Tooltips_ShowTextTooltip(self, TOP, tooltipText)
						end)

					elseif styles[styleId].stype == AIRG_STYLE_CROWNSTORE then
						local isKnown = (type(styleData) == "boolean") and styleData or false
						if not isKnown then
							AIRG_UI.StyleButtons[styleId]:SetColor(1, 0, 0, 1)
						else
							AIRG_UI.StyleButtons[styleId]:SetColor(1, 1, 1, 1)
							AIRG_UI.StyleButtons[styleId]:SetHidden(bHideKnownStyles)
						end

						tooltipText = zo_strformat("<<t:1>>\n<<t:2>>", GetItemStyleName(itemStyle), itemName)
						AIRG_UI.StyleButtons[styleId]:SetHandler("OnMouseEnter", function (self)
							ZO_Tooltips_ShowTextTooltip(self, TOP, tooltipText)
						end)

					elseif styles[styleId].stype == AIRG_STYLE_CHAPTERIZED then

						local knownCount = 0
						local chapVal = 0

						-- Sichere Typbehandlung: Verhindert "attempt to index a boolean value"
						local chapters = (type(styleData) == "table") and styleData or {}

						for chapterIndex, indexValue in ipairs(styleChaptersLookup) do
							if chapters[chapterIndex] then
								tooltipText = zo_strjoin(nil, tooltipText, "\n|cFFFFFF", zo_strformat("<<1>>", GetString("SI_ITEMSTYLECHAPTER", indexValue)), "|r")
								knownCount = knownCount + 1
								chapVal = chapVal + (2 ^ (chapterIndex - 1))
							else
								tooltipText = zo_strjoin(nil, tooltipText, "\n|c806060", zo_strformat("<<1>>", GetString("SI_ITEMSTYLECHAPTER", indexValue)), "|r")
							end
						end
						AIRG_UI.StyleButtons[styleId].chapVal = chapVal
						AIRG_UI.StyleButtons[styleId].achieve = styles[styleId].achiev

						if knownCount == 14 then
							AIRG_UI.StyleButtons[styleId]:SetColor(1, 1, 1, 1)
							AIRG_UI.StyleButtons[styleId]:SetHidden(bHideKnownStyles)
						elseif knownCount > 0 then
							AIRG_UI.StyleButtons[styleId]:SetColor(1, 1, 0, 1)
						else
							AIRG_UI.StyleButtons[styleId]:SetColor(1, 0, 0, 1)
						end

						tooltipText = zo_strjoin(nil, zo_strformat("<<t:1>> (<<2>>/14)\n<<t:3>>\n", GetItemStyleName(itemStyle), knownCount, ZO_SELECTED_TEXT:Colorize(itemName)), tooltipText)
						AIRG_UI.StyleButtons[styleId]:SetHandler("OnMouseEnter", function (self)
							ZO_Tooltips_ShowTextTooltip(self, TOP, tooltipText)
						end)

						AIRG_UI.StyleButtons[styleId]:SetHandler("OnMouseUp", function (control, mButton)
							AIRG_ProcessRightClick(control, mButton)
						end)
						styleChapterId = styleChapterId + 1

					end
				end
			end
		end
	end

end

-- Lookup the style data for the current character and send it to saved vars.
local function PopulateStyleData()

	-- Test if LibCharacterKnowledge is already initialized
	if not LCKInitialized then
		LCKRetryCounter = LCKRetryCounter + 1
		if LCKRetryCounter < LCK_MAX_RETRY_COUNT then zo_callLater(function () PopulateStyleData() end, 500) end
		return
	end

	db.char[curCharacter].styles = {}

	for styleId, styleData in pairs(styles) do

		if not styleData.api or apiVersion >= styleData.api then
			if styleData.stype == AIRG_STYLE_BASIC or styleData.stype == AIRG_STYLE_CROWNSTORE then
				local isStyleKnown = IsSmithingStyleKnown(styleId, 1)
				db.char[curCharacter].styles[styleId] = isStyleKnown
			elseif styleData.stype == AIRG_STYLE_CHAPTERIZED then
				db.char[curCharacter].styles[styleId] = {}
				for chapterIndex, chapterValue in ipairs(styleChaptersLookup) do
					db.char[curCharacter].styles[styleId][chapterIndex] = LCK.GetMotifKnowledgeForCharacter(styleId, chapterValue) == LCK.KNOWLEDGE_KNOWN
				end
			end

			for charName, charData in pairs(db.char) do
				if charData.styles then
					if styleData.stype == AIRG_STYLE_BASIC or styleData.stype == AIRG_STYLE_CROWNSTORE then
						if not mergedCharactersData.styles[styleId] and charData.styles[styleId] then
							mergedCharactersData.styles[styleId] = true
						elseif mergedCharactersData.styles[styleId] == nil then
							mergedCharactersData.styles[styleId] = false
						end
					elseif styleData.stype == AIRG_STYLE_CHAPTERIZED then
						if not mergedCharactersData.styles[styleId] or type(mergedCharactersData.styles[styleId]) ~= "table" then
							mergedCharactersData.styles[styleId] = {}
						end
						for chapterIndex, chapterValue in ipairs(styleChaptersLookup) do
							local knownByChar = false
							local charStyle = charData.styles[styleId]
							if type(charStyle) == "table" then
								knownByChar = charStyle[chapterIndex] or charStyle[chapterValue] or false
							elseif type(charStyle) == "boolean" then
								knownByChar = charStyle
							end

							if not mergedCharactersData.styles[styleId][chapterIndex] and knownByChar then
								mergedCharactersData.styles[styleId][chapterIndex] = true
							elseif mergedCharactersData.styles[styleId][chapterIndex] == nil then
								mergedCharactersData.styles[styleId][chapterIndex] = false
							end
						end
					end
				end
			end

		end
	end

end

local function PopulateTraitDataForCraft(craftingType)

	db.char[playerName].traits = db.char[playerName].traits or {}
	db.char[playerName].traits[craftingType] = {}
	for researchLineIndex = 1, GetNumSmithingResearchLines(craftingType) do

		db.char[playerName].traits[craftingType][researchLineIndex] = {}

		local _, _, numTraits = GetSmithingResearchLineInfo(craftingType, researchLineIndex)

		for traitIndex = 1, numTraits do

			local traitType, _, known = GetSmithingResearchLineTraitInfo(craftingType, researchLineIndex, traitIndex)
			local rowNum

			if craftingType ~= CRAFTING_TYPE_JEWELRYCRAFTING then
				rowNum = gridTraits[traitType]
			else
				rowNum = gridTraitsJC[traitType]
			end

			if known then
				db.char[playerName].traits[craftingType][researchLineIndex][rowNum] = TRAIT_KNOWN
			else

				local _, timeRemainingSecs = GetSmithingResearchLineTraitTimes(craftingType, researchLineIndex, traitIndex)

				if timeRemainingSecs then
					local tTargetStamp = GetTimeStamp() + timeRemainingSecs
					db.char[playerName].traits[craftingType][researchLineIndex][rowNum] = tTargetStamp
				else
					db.char[playerName].traits[craftingType][researchLineIndex][rowNum] = TRAIT_UNKNOWN
				end

			end
		end

	end

	mergedCharactersData.traits[craftingType] = {}
	for researchLineIndex = 1, GetNumSmithingResearchLines(craftingType) do

		mergedCharactersData.traits[craftingType][researchLineIndex] = {}

		local _, _, numTraits = GetSmithingResearchLineInfo(craftingType, researchLineIndex)

		for traitIndex = 1, numTraits do

			for charName, charData in pairs(db.char) do

				local traitType = GetSmithingResearchLineTraitInfo(craftingType, researchLineIndex, traitIndex)
				local rowNum
				if craftingType ~= CRAFTING_TYPE_JEWELRYCRAFTING then
					rowNum = gridTraits[traitType]
				else
					rowNum = gridTraitsJC[traitType]
				end

				if not mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] then
					mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] = db.char[charName].traits[craftingType][researchLineIndex][rowNum]
				elseif mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] == TRAIT_UNKNOWN then
					if db.char[charName].traits[craftingType] then
						if db.char[charName].traits[craftingType][researchLineIndex] then
							if db.char[charName].traits[craftingType][researchLineIndex][rowNum] ~= TRAIT_UNKNOWN then
								mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] = db.char[charName].traits[craftingType][researchLineIndex][rowNum]
							end
						end
					end
				elseif mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] > TRAIT_UNKNOWN and
					db.char[charName].traits[craftingType][researchLineIndex][rowNum] > TRAIT_UNKNOWN and
					db.char[charName].traits[craftingType][researchLineIndex][rowNum] < mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] then
					mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] = db.char[charName].traits[craftingType][researchLineIndex][rowNum]
				end

			end
		end

	end

end

local function BuildRelative()

	local function BuildRelativeForCraft(charName, craftingType)

		relative[charName][craftingType] = {}

		for researchLineIndex = 1, GetNumSmithingResearchLines(craftingType) do

			relative[charName][craftingType][researchLineIndex] = {}
			local _, _, numTraits = GetSmithingResearchLineInfo(craftingType, researchLineIndex)

			for traitIndex = 1, numTraits do

				local traitType = GetSmithingResearchLineTraitInfo(craftingType, researchLineIndex, traitIndex)
				local rowNum
				if craftingType ~= CRAFTING_TYPE_JEWELRYCRAFTING then
					rowNum = gridTraits[traitType]
				else
					rowNum = gridTraitsJC[traitType]
				end

				local isKnownForLocalPlayer = db.char[playerName].traits[craftingType][researchLineIndex][rowNum] == TRAIT_KNOWN
				local isKnownForRelative = db.char[charName].traits[craftingType][researchLineIndex][rowNum] == TRAIT_KNOWN

				if (isKnownForLocalPlayer and not isKnownForRelative) or (isKnownForLocalPlayer and isKnownForRelative) then
					relative[charName][craftingType][researchLineIndex][rowNum] = TRAIT_KNOWN
				else
					relative[charName][craftingType][researchLineIndex][rowNum] = TRAIT_UNKNOWN
				end

				local isInResearchForRelative = db.char[charName].traits[craftingType][researchLineIndex][rowNum] > TRAIT_UNKNOWN
				if isInResearchForRelative and db.char[charName].traits[craftingType][researchLineIndex][rowNum] <= GetTimeStamp() then
					db.char[charName].traits[craftingType][researchLineIndex][rowNum] = TRAIT_KNOWN
					mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] = TRAIT_KNOWN
				end

			end

		end
	end

	for charName, data in pairs(db.char) do
		if charName ~= playerName then

			relative[charName] = {}

			BuildRelativeForCraft(charName, CRAFTING_TYPE_BLACKSMITHING)
			BuildRelativeForCraft(charName, CRAFTING_TYPE_CLOTHIER)
			BuildRelativeForCraft(charName, CRAFTING_TYPE_WOODWORKING)
			BuildRelativeForCraft(charName, CRAFTING_TYPE_JEWELRYCRAFTING)

		end
	end

end

local function BuildMatrix(eventCode, arg1, arg2, arg3)

	if eventCode == EVENT_PLAYER_ACTIVATED then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)

		BLACKSMITHING_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_BLACKSMITHING_RESEARCH_LEVEL)
		CLOTHIER_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_CLOTHIER_RESEARCH_LEVEL)
		WOODWORKING_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_WOODWORKING_RESEARCH_LEVEL)
		JEWELRYCRAFTING_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_JEWELRYCRAFTING_RESEARCH_LEVEL)

		db.char[playerName].traits = {}

		PopulateTraitDataForCraft(CRAFTING_TYPE_BLACKSMITHING)
		PopulateTraitDataForCraft(CRAFTING_TYPE_CLOTHIER)
		PopulateTraitDataForCraft(CRAFTING_TYPE_WOODWORKING)
		PopulateTraitDataForCraft(CRAFTING_TYPE_JEWELRYCRAFTING)

		BuildRelative()
		PopulateStyleData()
		UpdateMotifsUI()
		playerActivated = true

	elseif eventCode == EVENT_SKILLS_FULL_UPDATE and playerActivated then

		local NEW_BLACKSMITHING_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_BLACKSMITHING_RESEARCH_LEVEL)
		local NEW_CLOTHIER_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_CLOTHIER_RESEARCH_LEVEL)
		local NEW_WOODWORKING_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_WOODWORKING_RESEARCH_LEVEL)
		local NEW_JEWELRYCRAFTING_RESEARCH_LEVEL = GetNonCombatBonus(NON_COMBAT_BONUS_JEWELRYCRAFTING_RESEARCH_LEVEL)

		if NEW_BLACKSMITHING_RESEARCH_LEVEL ~= BLACKSMITHING_RESEARCH_LEVEL then
			BLACKSMITHING_RESEARCH_LEVEL = NEW_BLACKSMITHING_RESEARCH_LEVEL
			PopulateTraitDataForCraft(CRAFTING_TYPE_BLACKSMITHING)
			BuildRelative()
		elseif NEW_CLOTHIER_RESEARCH_LEVEL ~= CLOTHIER_RESEARCH_LEVEL then
			CLOTHIER_RESEARCH_LEVEL = NEW_CLOTHIER_RESEARCH_LEVEL
			PopulateTraitDataForCraft(CRAFTING_TYPE_CLOTHIER)
			BuildRelative()
		elseif NEW_WOODWORKING_RESEARCH_LEVEL ~= WOODWORKING_RESEARCH_LEVEL then
			WOODWORKING_RESEARCH_LEVEL = NEW_WOODWORKING_RESEARCH_LEVEL
			PopulateTraitDataForCraft(CRAFTING_TYPE_WOODWORKING)
			BuildRelative()
		elseif NEW_JEWELRYCRAFTING_RESEARCH_LEVEL ~= JEWELRYCRAFTING_RESEARCH_LEVEL then
			JEWELRYCRAFTING_RESEARCH_LEVEL = NEW_JEWELRYCRAFTING_RESEARCH_LEVEL
			PopulateTraitDataForCraft(CRAFTING_TYPE_JEWELRYCRAFTING)
			BuildRelative()
		end

	elseif eventCode == EVENT_SMITHING_TRAIT_RESEARCH_STARTED then

		local craftingType, researchLineIndex, traitIndex = arg1, arg2, arg3
		local traitType = GetSmithingResearchLineTraitInfo(craftingType, researchLineIndex, traitIndex)
		local rowNum
		if craftingType ~= CRAFTING_TYPE_JEWELRYCRAFTING then
			rowNum = gridTraits[traitType]
		else
			rowNum = gridTraitsJC[traitType]
		end
		local _, timeRemainingSecs = GetSmithingResearchLineTraitTimes(craftingType, researchLineIndex, traitIndex)
		local tTargetStamp = GetTimeStamp() + timeRemainingSecs

		db.char[playerName].traits[craftingType][researchLineIndex][rowNum] = tTargetStamp

		if mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] ~= TRAIT_KNOWN then
			mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] = tTargetStamp
		end

		BuildRelative()

	elseif eventCode == EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED then

		local craftingType, researchLineIndex, traitIndex = arg1, arg2, arg3
		local traitType = GetSmithingResearchLineTraitInfo(craftingType, researchLineIndex, traitIndex)
		local rowNum
		if craftingType ~= CRAFTING_TYPE_JEWELRYCRAFTING then
			rowNum = gridTraits[traitType]
		else
			rowNum = gridTraitsJC[traitType]
		end

		db.char[playerName].traits[craftingType][researchLineIndex][rowNum] = TRAIT_KNOWN
		mergedCharactersData.traits[craftingType][researchLineIndex][rowNum] = TRAIT_KNOWN

		BuildRelative()

	elseif eventCode == EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED then

		if not mergedCharactersData.traits then mergedCharactersData.traits = {} end

		PopulateTraitDataForCraft(CRAFTING_TYPE_BLACKSMITHING)
		PopulateTraitDataForCraft(CRAFTING_TYPE_CLOTHIER)
		PopulateTraitDataForCraft(CRAFTING_TYPE_WOODWORKING)
		PopulateTraitDataForCraft(CRAFTING_TYPE_JEWELRYCRAFTING)

		BuildRelative()

	elseif eventCode == EVENT_STYLE_LEARNED then

		local itemStyleId, chapterIndex = arg1, arg2

		if not styles[itemStyleId] then
			-- unknown style, do nothing
		elseif chapterIndex == ITEM_STYLE_CHAPTER_ALL then
			if styles[itemStyleId].stype == AIRG_STYLE_BASIC or styles[itemStyleId].stype == AIRG_STYLE_CROWNSTORE then
				db.char[playerName].styles[itemStyleId] = true
				mergedCharactersData.styles[itemStyleId] = true
			elseif styles[itemStyleId].stype == AIRG_STYLE_CHAPTERIZED then
				for chapterLookupIndex in ipairs(styleChaptersLookup) do
					db.char[playerName].styles[itemStyleId][chapterLookupIndex] = true
					mergedCharactersData.styles[itemStyleId][chapterLookupIndex] = true
				end
			end
		elseif styles[itemStyleId].stype == AIRG_STYLE_CHAPTERIZED then
			local newIndexKnown
			for aiIndex, zosIndex in ipairs(styleChaptersLookup) do
				if chapterIndex == zosIndex then
					newIndexKnown = aiIndex
					break
				end
			end
			if newIndexKnown then
				if type(db.char[playerName].styles[itemStyleId]) ~= "table" then
					db.char[playerName].styles[itemStyleId] = {}
				end
				if type(mergedCharactersData.styles[itemStyleId]) ~= "table" then
					mergedCharactersData.styles[itemStyleId] = {}
				end
				db.char[playerName].styles[itemStyleId][newIndexKnown] = true
				mergedCharactersData.styles[itemStyleId][newIndexKnown] = true
			end
		end

		UpdateMotifsUI()

	end

end

local function DisplayGrid(b_ShowGrid)
	local i, j
	for i = 1, maxColumns do
		AIRG_UI.columnButtons[i]:SetHidden(not b_ShowGrid)
		AIRG_UI.columnButtons[i]:SetEnabled(b_ShowGrid)
		AIRG_UI.columnFooters[i]:SetHidden(not b_ShowGrid)
		for j = 1, 18 do
			if i == 1 then
				AIRG_UI.rowLabels[j]:SetHidden(not b_ShowGrid)
				AIRG_UI.rowLabels[j]:SetMouseEnabled(b_ShowGrid)
			end
			AIRG_UI.gridButtons[i][j]:SetHidden(not b_ShowGrid)
			AIRG_UI.gridButtons[i][j]:SetMouseEnabled(b_ShowGrid)
		end
	end
	AIRG_UI.columnFooterTitle:SetHidden(not b_ShowGrid)
	AIRG_UI.motifSection:SetHidden(b_ShowGrid)
end

local function OnCraftSelected(thisCraft)

	if not thisCraft then
		if not currentCraft then
			return
		else
			thisCraft = currentCraft
		end
	end

	db.currentCraft = thisCraft

	local filterTypeFromCraftingType = {
		[CRAFTING_TYPE_BLACKSMITHING] = ITEMFILTERTYPE_BLACKSMITHING,
		[CRAFTING_TYPE_CLOTHIER] = ITEMFILTERTYPE_CLOTHING,
		[CRAFTING_TYPE_WOODWORKING] = ITEMFILTERTYPE_WOODWORKING,
		[CRAFTING_TYPE_JEWELRYCRAFTING] = ITEMFILTERTYPE_JEWELRYCRAFTING,
	}

	currentCraft = thisCraft

	if thisCraft == CRAFTING_TYPE_MOTIFS then
		DisplayGrid(false)
		AIRG_UI.WindowSubTitle:SetText(GetString(SI_GAMEPAD_DYEING_EQUIPMENT_ACTION_STYLES))
		return
	else
		DisplayGrid(true)
		AIRG_UI.WindowSubTitle:SetText(GetString("SI_ITEMFILTERTYPE", filterTypeFromCraftingType[thisCraft]))
	end

	local researching
	local traitCount, alltraits, tooltiptext
	local maxLines = GetNumSmithingResearchLines(thisCraft)

	alltraits = 0
	local sourceData
	if curCharacter == mergedCharacters then
		sourceData = mergedCharactersData
	else
		sourceData = db.char[curCharacter]
	end

	if thisCraft ~= CRAFTING_TYPE_JEWELRYCRAFTING then
		for thisTrait, j in pairs(gridTraits) do
			AIRG_UI.rowLabels[j].isJewelryCrafting = false
			AIRG_UI.rowLabels[j]:SetText(GetString("SI_ITEMTRAITTYPE", thisTrait))
		end
	else
		for thisTrait, j in pairs(gridTraitsJC) do
			AIRG_UI.rowLabels[j].isJewelryCrafting = true
			AIRG_UI.rowLabels[j]:SetText(GetString("SI_ITEMTRAITTYPE", thisTrait))
		end
		for j = 10, 18 do
			AIRG_UI.rowLabels[j].isJewelryCrafting = nil
			AIRG_UI.rowLabels[j]:SetText("")
		end
	end

	for i = 1, maxColumns do
		researching = false

		for j = 1, 18 do
			AIRG_UI.gridButtons[i][j]:SetColor(1, 1, 1, 0.4)
			AIRG_UI.gridButtons[i][j]:SetTexture("/esoui/art/buttons/swatchframe_down.dds")
			AIRG_UI.gridButtons[i][j]:SetMouseEnabled(false)
		end

		if (i > maxLines) then
			AIRG_UI.columnButtons[i]:SetHidden(true)
			AIRG_UI.columnFooters[i]:SetText("")
		else

			local name, icon, _, _ = GetSmithingResearchLineInfo(thisCraft, i)
			AIRG_UI.columnButtons[i]:SetNormalTexture(icon)
			AIRG_UI.columnButtons[i]:SetHidden(false)
			AIRG_UI.columnButtons[i].text = name
			traitCount = 0

			-- Check for research expiry
			for rowNum, tKnown in pairs(sourceData.traits[thisCraft][i]) do
				if (tKnown > 0 and tKnown < GetTimeStamp()) then
					sourceData.traits[thisCraft][i][rowNum] = TRAIT_KNOWN
				end
			end

			if showRelative then
				for rowNum, tKnown in pairs(sourceData.traits[thisCraft][i]) do
					if (tKnown > 0) then
						researching = true
					end
				end

				for rowNum, tKnown in pairs(relative[curCharacter][thisCraft][i]) do
					AIRG_UI.gridButtons[i][rowNum].Known = tKnown
					if (tKnown == TRAIT_KNOWN) then
						if researching then
							AIRG_UI.gridButtons[i][rowNum]:SetColor(0.7, 0.6, 0.6, .8)
						else
							AIRG_UI.gridButtons[i][rowNum]:SetColor(0.2, 1, 0.2, 1)
							AIRG_UI.gridButtons[i][rowNum]:SetMouseEnabled(true)
						end
						tooltiptext = zo_strjoin(" ", AIRG_UI.rowLabels[rowNum]:GetText(), AIRG_UI.columnButtons[i].text)
						AIRG_UI.gridButtons[i][rowNum].tooltipText = tooltiptext
						AIRG_UI.gridButtons[i][rowNum]:SetTexture("/esoui/art/loot/loot_finesseitem.dds")
						traitCount = traitCount + 1
					end
				end

			else
				for rowNum, tKnown in pairs(sourceData.traits[thisCraft][i]) do
					AIRG_UI.gridButtons[i][rowNum].Known = tKnown

					if (tKnown == TRAIT_KNOWN) then
						AIRG_UI.gridButtons[i][rowNum]:SetColor(0.2, 1, 0.2, 1)
						AIRG_UI.gridButtons[i][rowNum]:SetTexture("/esoui/art/loot/loot_finesseitem.dds")
						traitCount = traitCount + 1
						tooltiptext = zo_strjoin(" ", AIRG_UI.rowLabels[rowNum]:GetText(), AIRG_UI.columnButtons[i].text)
						AIRG_UI.gridButtons[i][rowNum].tooltipText = tooltiptext
						AIRG_UI.gridButtons[i][rowNum]:SetMouseEnabled(true)
					elseif (tKnown > 0) then
						AIRG_UI.gridButtons[i][rowNum]:SetTexture("/esoui/art/miscellaneous/gamepad/gp_icon_timer32.dds")
						AIRG_UI.gridButtons[i][rowNum]:SetColor(0.0, .5, .75, 1)
						AIRG_UI.gridButtons[i][rowNum]:SetMouseEnabled(true)
					else
						AIRG_UI.gridButtons[i][rowNum]:SetColor(1, 0.2, 0.2, 1)
						AIRG_UI.gridButtons[i][rowNum]:SetTexture("esoui/art/buttons/decline_up.dds")
					end
				end
			end

			AIRG_UI.columnFooters[i]:SetText(traitCount)
			alltraits = alltraits + traitCount
		end
	end

	AIRG_UI.columnFooterTitle:SetText(GetString(SI_CRAFTING_COMPONENT_TOOLTIP_TRAITS) .. "(" .. tostring(alltraits) .. ")")

end

local function ToggleMainWindow()
	if AIResearchGrid:IsHidden() then
		OnCraftSelected()
	end
	SCENE_MANAGER:ToggleTopLevel(AIResearchGrid)
end

local function OnCharacterSelect(charName)
	if charName ~= GetString(AIRG_OPTIONS_ALL) then
		curCharacter = charName
	else
		curCharacter = mergedCharacters
	end

	if curCharacter == mergedCharacters or curCharacter == playerName then
		AIRG_UI.btnUpdateOther:SetState(BSTATE_DISABLED)
		showRelative = false
	else
		AIRG_UI.btnUpdateOther:SetState(BSTATE_NORMAL)
	end

	UpdateMotifsUI()
	OnCraftSelected()
end

-- Create AIRG UI
local function InitUI()

	AIRG_UI.WindowSubTitle = GetControl(AIResearchGrid, "WindowSubTitle")
	AIRG_UI.BottomDivider = GetControl(AIResearchGrid, "BottomDivider")

	AIRG_UI.charDropdown = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)DropdownCharacter", AIResearchGrid, "ZO_StatsDropdownRow")
	AIRG_UI.charDropdown:SetWidth(205)
	AIRG_UI.charDropdown:SetAnchor(TOPRIGHT, AIResearchGrid, TOPRIGHT, -32, 0)
	AIRG_UI.charDropdown:GetNamedChild("Dropdown"):SetWidth(200)
	AIRG_UI.charDropdown.dropdown:SetSelectedItem(curCharacter)

	local function OnItemSelect(_, choiceText, choice)
		OnCharacterSelect(choiceText)
	end

	local entry = AIRG_UI.charDropdown.dropdown:CreateItemEntry(GetString(AIRG_OPTIONS_ALL), OnItemSelect)
	AIRG_UI.charDropdown.dropdown:AddItem(entry)

	for charName, _ in pairs(db.char) do
		local charEntry = AIRG_UI.charDropdown.dropdown:CreateItemEntry(charName, OnItemSelect)
		AIRG_UI.charDropdown.dropdown:AddItem(charEntry)
	end

	AIRG_UI.btnUpdateOther = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ButtonUpdateOther", AIResearchGrid, "ZO_DefaultButton")

	local textlen = 0
	if string.len(GetString(AIRG_OPTIONS_RELATIVE)) > string.len(GetString(AIRG_OPTIONS_RELATIVE_TO)) then
		textlen = string.len(GetString(AIRG_OPTIONS_RELATIVE))
	else
		textlen = string.len(GetString(AIRG_OPTIONS_RELATIVE_TO))
	end

	AIRG_UI.btnUpdateOther:SetDimensions(140 + textlen, 30)
	AIRG_UI.btnUpdateOther:SetAnchor(RIGHT, AIRG_UI.charDropdown, LEFT, 0, 0)
	AIRG_UI.btnUpdateOther:SetState(BSTATE_NORMAL)
	AIRG_UI.btnUpdateOther:SetMouseOverBlendMode(0)
	AIRG_UI.btnUpdateOther:SetMouseOverTexture("esoui/art/buttons/generic_highlight.dds")
	AIRG_UI.btnUpdateOther:SetClickSound("Click")
	AIRG_UI.btnUpdateOther:SetDisabledFontColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
	AIRG_UI.btnUpdateOther:SetFont("ZoFontGame")
	AIRG_UI.btnUpdateOther:SetText(GetString(AIRG_OPTIONS_RELATIVE_TO))
	AIRG_UI.btnUpdateOther:SetEnabled(false)
	AIRG_UI.btnUpdateOther:SetHidden(false)
	AIRG_UI.btnUpdateOther:SetHandler("OnClicked",
		function(self)
			showRelative = not showRelative
			if showRelative then
				self:SetText(GetString(AIRG_OPTIONS_RELATIVE))
			else
				self:SetText(GetString(AIRG_OPTIONS_RELATIVE_TO))
			end
			OnCraftSelected()
		end)
	AIRG_UI.btnUpdateOther:SetMouseEnabled(true)

	-- Blacksmithing button
	AIRG_UI.btnBlacksmithing = WINDOW_MANAGER:CreateControl("$(parent)ButtonBlacksmithing", AIResearchGrid, CT_BUTTON)
	AIRG_UI.btnBlacksmithing:SetDimensions(48, 48)
	AIRG_UI.btnBlacksmithing:SetAnchor(TOPLEFT, AIResearchGrid, TOPLEFT, 8, 44)
	AIRG_UI.btnBlacksmithing:SetState(BSTATE_NORMAL)
	AIRG_UI.btnBlacksmithing:SetMouseOverBlendMode(0)
	AIRG_UI.btnBlacksmithing:SetHidden(false)
	AIRG_UI.btnBlacksmithing:SetEnabled(true)
	AIRG_UI.btnBlacksmithing:SetClickSound(SOUNDS.WOODWORKER_EXTRACTED_BOOSTER)
	AIRG_UI.btnBlacksmithing:SetNormalTexture("/esoui/art/icons/ability_smith_007.dds")
	AIRG_UI.btnBlacksmithing:SetMouseOverTexture("esoui/art/buttons/generic_highlight.dds")
	AIRG_UI.btnBlacksmithing:SetHandler("OnClicked", function(self) OnCraftSelected(CRAFTING_TYPE_BLACKSMITHING) end)
	AIRG_UI.btnBlacksmithing:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, RIGHT, GetString(SI_ITEMFILTERTYPE13)) end)
	AIRG_UI.btnBlacksmithing:SetHandler("OnMouseExit", function (self) ZO_Tooltips_HideTextTooltip() end)

	-- Clothing button
	AIRG_UI.btnClothing = WINDOW_MANAGER:CreateControl("$(parent)ButtonClothing", AIResearchGrid, CT_BUTTON)
	AIRG_UI.btnClothing:SetDimensions(48, 48)
	AIRG_UI.btnClothing:SetAnchor(TOPLEFT, AIRG_UI.btnBlacksmithing, BOTTOMLEFT, 0, 12)
	AIRG_UI.btnClothing:SetState(BSTATE_NORMAL)
	AIRG_UI.btnClothing:SetMouseOverBlendMode(0)
	AIRG_UI.btnClothing:SetHidden(false)
	AIRG_UI.btnClothing:SetEnabled(true)
	AIRG_UI.btnClothing:SetClickSound(SOUNDS.CLOTHIER_EXTRACTED_BOOSTER)
	AIRG_UI.btnClothing:SetNormalTexture("/esoui/art/icons/ability_tradecraft_008.dds")
	AIRG_UI.btnClothing:SetMouseOverTexture("esoui/art/buttons/generic_highlight.dds")
	AIRG_UI.btnClothing:SetHandler("OnClicked", function(self) OnCraftSelected(CRAFTING_TYPE_CLOTHIER) end)
	AIRG_UI.btnClothing:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, RIGHT, GetString(SI_ITEMFILTERTYPE14)) end)
	AIRG_UI.btnClothing:SetHandler("OnMouseExit", function (self) ZO_Tooltips_HideTextTooltip() end)

	-- Woodworking button
	AIRG_UI.btnWoodworking = WINDOW_MANAGER:CreateControl("$(parent)ButtonWoodworking", AIResearchGrid, CT_BUTTON)
	AIRG_UI.btnWoodworking:SetDimensions(48, 48)
	AIRG_UI.btnWoodworking:SetAnchor(TOPLEFT, AIRG_UI.btnClothing, BOTTOMLEFT, 0, 12)
	AIRG_UI.btnWoodworking:SetState(BSTATE_NORMAL)
	AIRG_UI.btnWoodworking:SetMouseOverBlendMode(0)
	AIRG_UI.btnWoodworking:SetHidden(false)
	AIRG_UI.btnWoodworking:SetEnabled(true)
	AIRG_UI.btnWoodworking:SetClickSound(SOUNDS.BLACKSMITH_EXTRACTED_BOOSTER)
	AIRG_UI.btnWoodworking:SetNormalTexture("/esoui/art/icons/ability_tradecraft_009.dds")
	AIRG_UI.btnWoodworking:SetMouseOverTexture("esoui/art/buttons/generic_highlight.dds")
	AIRG_UI.btnWoodworking:SetHandler("OnClicked", function(self) OnCraftSelected(CRAFTING_TYPE_WOODWORKING) end)
	AIRG_UI.btnWoodworking:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, RIGHT, GetString(SI_ITEMFILTERTYPE15)) end)
	AIRG_UI.btnWoodworking:SetHandler("OnMouseExit", function (self) ZO_Tooltips_HideTextTooltip() end)

	-- Jewelry Crafting button
	AIRG_UI.btnJewelryCrafting = WINDOW_MANAGER:CreateControl("$(parent)ButtonJewelryCrafting", AIResearchGrid, CT_BUTTON)
	AIRG_UI.btnJewelryCrafting:SetDimensions(48, 48)
	AIRG_UI.btnJewelryCrafting:SetAnchor(TOPLEFT, AIRG_UI.btnWoodworking, BOTTOMLEFT, 0, 12)
	AIRG_UI.btnJewelryCrafting:SetState(BSTATE_NORMAL)
	AIRG_UI.btnJewelryCrafting:SetMouseOverBlendMode(0)
	AIRG_UI.btnJewelryCrafting:SetHidden(false)
	AIRG_UI.btnJewelryCrafting:SetEnabled(true)
	AIRG_UI.btnJewelryCrafting:SetClickSound(SOUNDS.JEWELRYCRAFTER_EXTRACTED_BOOSTER)
	AIRG_UI.btnJewelryCrafting:SetNormalTexture("/esoui/art/icons/passive_jewelerengraver.dds")
	AIRG_UI.btnJewelryCrafting:SetMouseOverTexture("esoui/art/buttons/generic_highlight.dds")
	AIRG_UI.btnJewelryCrafting:SetHandler("OnClicked", function(self) OnCraftSelected(CRAFTING_TYPE_JEWELRYCRAFTING) end)
	AIRG_UI.btnJewelryCrafting:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, RIGHT, GetString(SI_ITEMFILTERTYPE24)) end)
	AIRG_UI.btnJewelryCrafting:SetHandler("OnMouseExit", function (self) ZO_Tooltips_HideTextTooltip() end)

	-- Motifs page button
	AIRG_UI.btnMotifsPage = WINDOW_MANAGER:CreateControl("$(parent)ButtonMotifs", AIResearchGrid, CT_BUTTON)
	AIRG_UI.btnMotifsPage:SetDimensions(48, 48)
	AIRG_UI.btnMotifsPage:SetAnchor(TOPLEFT, AIRG_UI.btnJewelryCrafting, BOTTOMLEFT, 0, 12)
	AIRG_UI.btnMotifsPage:SetState(BSTATE_NORMAL)
	AIRG_UI.btnMotifsPage:SetMouseOverBlendMode(0)
	AIRG_UI.btnMotifsPage:SetHidden(false)
	AIRG_UI.btnMotifsPage:SetEnabled(true)
	AIRG_UI.btnMotifsPage:SetClickSound(SOUNDS.DIALOG_ACCEPT)
	AIRG_UI.btnMotifsPage:SetNormalTexture("/esoui/art/icons/quest_book_001.dds")
	AIRG_UI.btnMotifsPage:SetMouseOverTexture("esoui/art/buttons/generic_highlight.dds")
	AIRG_UI.btnMotifsPage:SetHandler("OnClicked", function(self) OnCraftSelected(CRAFTING_TYPE_MOTIFS) end)
	AIRG_UI.btnMotifsPage:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, RIGHT, GetString(SI_GAMEPAD_DYEING_EQUIPMENT_ACTION_STYLES)) end)
	AIRG_UI.btnMotifsPage:SetHandler("OnMouseExit", function (self) ZO_Tooltips_HideTextTooltip() end)

	-- Row labels
	AIRG_UI.rowLabels = {}
	for thisTrait, j in pairs(gridTraits) do
		AIRG_UI.rowLabels[j] = WINDOW_MANAGER:CreateControl("$(parent)RowLabel" .. tostring(j), AIResearchGrid, CT_LABEL)
		AIRG_UI.rowLabels[j]:SetAnchor(TOPLEFT, AIResearchGrid, TOPLEFT, 5 + 48, 28*j + 70)
		AIRG_UI.rowLabels[j]:SetText(GetString("SI_ITEMTRAITTYPE", thisTrait))
		AIRG_UI.rowLabels[j]:SetDimensions(180 - 48, 24)
		AIRG_UI.rowLabels[j]:SetFont("ZoFontGame")
		AIRG_UI.rowLabels[j]:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		AIRG_UI.rowLabels[j]:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		AIRG_UI.rowLabels[j]:SetMouseEnabled(true)
		AIRG_UI.rowLabels[j].isJewelryCrafting = false
		AIRG_UI.rowLabels[j]:SetHandler("OnMouseEnter", function (self)
			if self.isJewelryCrafting == nil then
				ZO_Tooltips_HideTextTooltip()
			elseif self.isJewelryCrafting then
				ZO_Tooltips_ShowTextTooltip(self, TOP, self.tooltipTextJC)
			else
				ZO_Tooltips_ShowTextTooltip(self, TOP, self.tooltipText)
			end
		end)
		AIRG_UI.rowLabels[j]:SetHandler("OnMouseExit", function (self)
			ZO_Tooltips_HideTextTooltip()
		end)
	end

	for j = 1, 9 do
		local tTypeW, tDescW, _ = GetSmithingResearchLineTraitInfo(CRAFTING_TYPE_BLACKSMITHING, 1, j)
		AIRG_UI.rowLabels[gridTraits[tTypeW]].tooltipText = tDescW
		local tTypeA, tDescA, _ = GetSmithingResearchLineTraitInfo(CRAFTING_TYPE_BLACKSMITHING, 9, j)
		AIRG_UI.rowLabels[gridTraits[tTypeA]].tooltipText = tDescA
		local tTypeJ, tDescJ, _ = GetSmithingResearchLineTraitInfo(CRAFTING_TYPE_JEWELRYCRAFTING, 1, j)
		AIRG_UI.rowLabels[gridTraitsJC[tTypeJ]].tooltipTextJC = tDescJ
	end

	maxColumns = math.max(GetNumSmithingResearchLines(CRAFTING_TYPE_BLACKSMITHING),
		GetNumSmithingResearchLines(CRAFTING_TYPE_CLOTHIER),
		GetNumSmithingResearchLines(CRAFTING_TYPE_WOODWORKING),
		GetNumSmithingResearchLines(CRAFTING_TYPE_JEWELRYCRAFTING))
	AIRG_UI.columnButtons = {}
	AIRG_UI.gridButtons = {}
	AIRG_UI.columnFooters = {}

	for i = 1, maxColumns do
		AIRG_UI.columnButtons[i] = WINDOW_MANAGER:CreateControl("$(parent)HeaderButton" .. tostring(i), AIResearchGrid, CT_BUTTON)
		AIRG_UI.columnButtons[i]:SetDimensions(36, 36)
		AIRG_UI.columnButtons[i]:SetState(BSTATE_NORMAL)
		AIRG_UI.columnButtons[i]:SetAnchor(TOPLEFT, AIResearchGrid, TOPLEFT, 40*i + 150, 55)
		AIRG_UI.columnButtons[i]:SetHidden(true)
		AIRG_UI.columnButtons[i]:SetEnabled(true)
		AIRG_UI.columnButtons[i]:SetMouseOverTexture("esoui/art/buttons/generic_highlight.dds")
		AIRG_UI.columnButtons[i].text = i
		AIRG_UI.columnButtons[i]:SetHandler("OnMouseEnter", function (self)
			ZO_Tooltips_ShowTextTooltip(self, TOP, self.text)
		end)
		AIRG_UI.columnButtons[i]:SetHandler("OnMouseExit", function (self)
			ZO_Tooltips_HideTextTooltip()
		end)

		AIRG_UI.gridButtons[i] = {}
		for j = 1, 18 do
			AIRG_UI.gridButtons[i][j] = WINDOW_MANAGER:CreateControl("$(parent)Button" .. tostring(i) .. "x" .. tostring(j), AIResearchGrid, CT_TEXTURE)
			AIRG_UI.gridButtons[i][j]:SetDimensions(24, 24)
			AIRG_UI.gridButtons[i][j]:SetAnchor(TOP, AIRG_UI.columnButtons[i], BOTTOM, 0, 28 * j - 20)
			AIRG_UI.gridButtons[i][j]:SetTexture("/esoui/art/buttons/swatchframe_down.dds")
			AIRG_UI.gridButtons[i][j]:SetDrawLayer(2)
			AIRG_UI.gridButtons[i][j]:SetColor(1, 1, 1, 0.4)
			AIRG_UI.gridButtons[i][j]:SetHidden(false)
			AIRG_UI.gridButtons[i][j]:SetMouseEnabled(false)
			AIRG_UI.gridButtons[i][j]:SetHandler("OnMouseEnter", function (self)
				if (self.Known > 0) then
					local tRemaining = tonumber(self.Known) - GetTimeStamp()
					local tFormatted = FormatTimeSeconds(tRemaining, TIME_FORMAT_STYLE_DESCRIPTIVE_SHORT, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)
					ZO_Tooltips_ShowTextTooltip(self, RIGHT, tFormatted)
					EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 1000, function()
						local tRemainingNow = tonumber(self.Known) - GetTimeStamp()
						local tFormattedNow = FormatTimeSeconds(tRemainingNow, TIME_FORMAT_STYLE_DESCRIPTIVE_SHORT, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)
						ZO_Tooltips_ShowTextTooltip(self, RIGHT, tFormattedNow)
					end)
				else
					ZO_Tooltips_ShowTextTooltip(self, RIGHT, self.tooltipText)
				end
			end)
			AIRG_UI.gridButtons[i][j]:SetHandler("OnMouseExit", function (self)
				EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME)
				ZO_Tooltips_HideTextTooltip()
			end)
		end

		AIRG_UI.columnFooters[i] = WINDOW_MANAGER:CreateControl("$(parent)ColumnFooterLabel" .. tostring(i), AIResearchGrid, CT_LABEL)
		AIRG_UI.columnFooters[i]:SetAnchor(TOP, AIRG_UI.columnButtons[i], BOTTOM, 0, 516)
		AIRG_UI.columnFooters[i]:SetDimensions(36, 24)
		AIRG_UI.columnFooters[i]:SetFont("ZoFontGame")
		AIRG_UI.columnFooters[i]:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		AIRG_UI.columnFooters[i]:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		AIRG_UI.columnFooters[i]:SetColor(1, 1, 0.4, 1)
	end

	AIRG_UI.columnFooterTitle = WINDOW_MANAGER:CreateControl("$(parent)ColumnFooterTitleLabel", AIResearchGrid, CT_LABEL)
	AIRG_UI.columnFooterTitle:SetAnchor(TOPLEFT, AIResearchGrid, TOPLEFT, 5, 606)
	AIRG_UI.columnFooterTitle:SetDimensions(180, 24)
	AIRG_UI.columnFooterTitle:SetFont("ZoFontGame")
	AIRG_UI.columnFooterTitle:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	AIRG_UI.columnFooterTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	AIRG_UI.columnFooterTitle:SetColor(1, 1, 0.4, 1)
	AIRG_UI.columnFooterTitle:SetText(GetString(SI_CRAFTING_COMPONENT_TOOLTIP_TRAITS))

	-- Motif Section
	AIRG_UI.motifSection = WINDOW_MANAGER:CreateControl("$(parent)MotifSection", AIResearchGrid, CT_CONTROL)
	AIRG_UI.motifSection:SetDimensions(650, 45 * 7)
	AIRG_UI.motifSection:SetAnchor(TOPLEFT, AIRG_UI.btnBlacksmithing, TOPRIGHT, 40, 20)

	AIRG_UI.btnHideKnownStyles = WINDOW_MANAGER:CreateControl("$(parent)ButtonHideKnown", AIRG_UI.motifSection, CT_BUTTON)
	AIRG_UI.btnHideKnownStyles:SetDimensions(32, 32)
	AIRG_UI.btnHideKnownStyles:SetAnchor(BOTTOMLEFT, AIRG_UI.motifSection, BOTTOMLEFT, 5, -5)
	AIRG_UI.btnHideKnownStyles:SetState(BSTATE_NORMAL)
	AIRG_UI.btnHideKnownStyles:SetMouseOverBlendMode(0)
	AIRG_UI.btnHideKnownStyles:SetHidden(false)
	AIRG_UI.btnHideKnownStyles:SetEnabled(true)
	AIRG_UI.btnHideKnownStyles:SetClickSound(SOUNDS.DIALOG_ACCEPT)
	AIRG_UI.btnHideKnownStyles:SetNormalTexture("/esoui/art/lfg/lfg_tabicon_grouptools_up.dds")
	AIRG_UI.btnHideKnownStyles:SetPressedTexture("/esoui/art/lfg/lfg_tabicon_grouptools_down.dds")
	AIRG_UI.btnHideKnownStyles:SetHandler("OnClicked", function(self) AIRG_ToggleStyles() end)
	AIRG_UI.btnHideKnownStyles:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, TOP, "Hide/Show Known Styles") end)
	AIRG_UI.btnHideKnownStyles:SetHandler("OnMouseExit", function (self) ZO_Tooltips_HideTextTooltip() end)

	local searchCtrl = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)SearchBox", AIRG_UI.motifSection, "AIRG_SearchBox")
	searchCtrl:SetAnchor(TOPLEFT, AIRG_UI.btnHideKnownStyles, BOTTOMLEFT, 5, -5)
	searchCtrl:SetHidden(false)
	AIRG_UI.searchCtrl = AIResearchGridMotifSectionSearchBoxBackdropBox

	AIRG_UI.StyleButtons = {}

	local styleColumn = 0
	local styleRow = 0
	local styleHeight = 48
	local styleWidth = 43
	local bFirstChapterizedDone = false
	local bFirstCrownDone = false

	for ctr = 1, #styleOrder do
		local styleId = styleOrder[ctr]
		local styleData = styles[styleId]

		if styleData and (not styleData.api or apiVersion >= styleData.api) then

			local stoneItemLink = GetItemStyleMaterialLink(styleId)
			local stoneTexture = GetItemLinkInfo(stoneItemLink)

			if styleData.stype == AIRG_STYLE_BASIC then
				-- Zeile 0
			elseif styleData.stype == AIRG_STYLE_CROWNSTORE then
				if not bFirstCrownDone then
					bFirstCrownDone = true
					styleRow = styleRow + 1
					styleColumn = 0
				end
			elseif styleData.stype == AIRG_STYLE_CHAPTERIZED then
				if not bFirstChapterizedDone then
					bFirstChapterizedDone = true
					styleRow = styleRow + 1
					styleColumn = 0
				end

				if (styleColumn + 1) * styleWidth > 650 then
					styleRow = styleRow + 1
					styleColumn = 0
				end
			end

			AIRG_UI.StyleButtons[styleId] = WINDOW_MANAGER:CreateControl("$(parent)StyleButton" .. tostring(styleId), AIRG_UI.motifSection, CT_TEXTURE)
			AIRG_UI.StyleButtons[styleId]:SetDimensions(40, 40)
			AIRG_UI.StyleButtons[styleId]:SetAnchor(TOPLEFT, AIRG_UI.motifSection, TOPLEFT, styleColumn * styleWidth, styleRow * styleHeight)
			AIRG_UI.StyleButtons[styleId]:SetTexture(stoneTexture)
			AIRG_UI.StyleButtons[styleId]:SetDrawLayer(2)
			AIRG_UI.StyleButtons[styleId]:SetMouseEnabled(true)
			AIRG_UI.StyleButtons[styleId]:SetHandler("OnMouseExit", function (self)
				ZO_Tooltips_HideTextTooltip()
			end)

			if stoneTexture == "" then
				AIRG_UI.StyleButtons[styleId]:SetHidden(true)
			end

			styleColumn = styleColumn + 1
		end
	end
	AIRG_UI.motifSection:SetHeight((styleRow + 2.5) * styleHeight)
end

local function CleanSV()

	-- Alte und migrierte SavedVariables gegen Typkonflikte absichern
	for charName, charData in pairs(db.char) do
		if charData and charData.styles then
			for styleId, styleDef in pairs(styles) do
				if styleDef.stype == AIRG_STYLE_CHAPTERIZED then
					if type(charData.styles[styleId]) ~= "table" then
						charData.styles[styleId] = {false, false, false, false, false, false, false, false, false, false, false, false, false, false}
					end
				elseif styleDef.stype == AIRG_STYLE_BASIC or styleDef.stype == AIRG_STYLE_CROWNSTORE then
					if type(charData.styles[styleId]) ~= "boolean" then
						charData.styles[styleId] = false
					end
				end
			end
		end
	end

	if not db.styleId then

		for charName, charData in pairs(db.char) do
			if charData.id then
				charData.styles = {}
				for styleId, styleData in pairs(styles) do
					if styleData.stype == AIRG_STYLE_CHAPTERIZED then
						charData.styles[styleId] = {false, false, false, false, false, false, false, false, false, false, false, false, false, false}
					else
						charData.styles[styleId] = false
					end
				end
				charData.StyleSingle = nil
				charData.StyleChapter = nil
				charData.StyleStore = nil
			end
		end

		db.char[mergedCharacters] = nil
		db.styleId = true

	end

end

local function OnAddonLoaded(_, addonName)

	if ADDON_NAME == addonName then

		SLASH_COMMANDS["/airg"] = ToggleMainWindow

		db = ZO_SavedVars:NewAccountWide("AIRG_SavedVariables", 4, nil, defaults)

		if db.currentCraft then
			currentCraft = db.currentCraft
		end

		ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_AIRG", GetString(AIRG_KEYBIND_TOGGLE))
		apiVersion = GetAPIVersion()

		if NAME_CHANGE:DidNameChange() then
			db.char[GetUnitName("player")] = db.char[NAME_CHANGE:GetOldCharacterName()]
			db.char[NAME_CHANGE:GetOldCharacterName()] = nil
		end

		for i = 1, GetNumCharacters() do
			local name, _, _, _, _, _, characterId = GetCharacterInfo(i)
			name = zo_strformat(SI_UNIT_NAME, name)
			if db.char[name] and not db.char[name].id then
				db.char[name].id = characterId
			end
		end

		for charName, charData in pairs(db.char) do
			if charName ~= mergedCharacters and charName ~= GetUnitName("player") and not charData.id then
				db.char[charName] = nil
			end
		end

		BuildDynamicStyles()
		CleanSV()
		InitUI()

		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED, BuildMatrix)
		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, BuildMatrix)
		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, BuildMatrix)

		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SKILLS_FULL_UPDATE, BuildMatrix)

		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, BuildMatrix)
		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_STYLE_LEARNED, BuildMatrix)

		SCENE_MANAGER:RegisterTopLevel(AIResearchGrid, false)
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	end

end

function AIRG_ToggleMainWindow()
	ToggleMainWindow()
end

function AIRG_ProcessRightClick(control, mButton)
	if control == nil or mButton ~= MOUSE_BUTTON_INDEX_RIGHT then
		return
	end

	if control.achieve == nil then
		return
	end

	if control.chapVal == nil then
		d("This Motif has no chapters")
		return
	end

	zo_callLater(function()
		ClearMenu()
		AddCustomMenuItem("Paste Achieve", function()
			local motifStr = "|H1:achievement:" .. control.achieve .. ":" .. control.chapVal .. ":0|h|h"
			ZO_ChatWindowTextEntryEditBox:SetText(ZO_ChatWindowTextEntryEditBox:GetText() .. " " .. motifStr)
		end, MENU_ADD_OPTION_LABEL)
		ShowMenu(control)
	end, 50)
end

function AIRG_ToggleStyles()
	local iconId, icon
	local r, g, b, a

	if AIRG_UI.searchCtrl:GetText() ~= "" then
		AIRG_UI.searchCtrl:SetText("")
	end
	bHideKnownStyles = not bHideKnownStyles

	if bHideKnownStyles then
		AIRG_UI.btnHideKnownStyles:SetState(BSTATE_PRESSED)
	else
		AIRG_UI.btnHideKnownStyles:SetState(BSTATE_NORMAL)
	end

	for iconId, icon in pairs(AIRG_UI.StyleButtons) do
		if icon:GetTextureFileName() ~= "" then
			if bHideKnownStyles then
				r, g, b, a = icon:GetColor()
				if b == 1 then
					icon:SetHidden(true)
				end
			else
				icon:SetHidden(false)
			end
		end
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

function AIRG_onSearchBoxClear()
	if AIRG_UI.searchCtrl:GetText() > "" then
		AIRG_UI.searchCtrl:SetText("")
	end
	bHideKnownStyles = true
	AIRG_ToggleStyles()
end

function AIRG_onSearchBoxText(ctrl)
	bHideKnownStyles = false
	AIRG_UI.btnHideKnownStyles:SetState(BSTATE_NORMAL)
	local SrchText = ctrl:GetText()

	if SrchText == nil or SrchText == "" then
		AIRG_onSearchBoxClear()
	end

	for styleId, icon in pairs(AIRG_UI.StyleButtons) do
		if icon:GetTextureFileName() ~= "" then
			if zo_plainstrfind(GetItemStyleName(styleId):lower(), SrchText:lower()) then
				icon:SetHidden(false)
			else
				icon:SetHidden(true)
			end
		end
	end
end