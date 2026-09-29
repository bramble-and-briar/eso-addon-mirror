local sf = string.format

--Chapter to motif book order, matches achievement
local chapterOrder = {
	[ITEM_STYLE_CHAPTER_AXES]=1,
	[ITEM_STYLE_CHAPTER_BELTS]=2,
	[ITEM_STYLE_CHAPTER_BOOTS]=3,
	[ITEM_STYLE_CHAPTER_BOWS]=4,
	[ITEM_STYLE_CHAPTER_CHESTS]=5,
	[ITEM_STYLE_CHAPTER_DAGGERS]=6,
	[ITEM_STYLE_CHAPTER_GLOVES]=7,
	[ITEM_STYLE_CHAPTER_HELMETS]=8,
	[ITEM_STYLE_CHAPTER_LEGS]=9,
	[ITEM_STYLE_CHAPTER_MACES]=10,
	[ITEM_STYLE_CHAPTER_SHIELDS]=11,
	[ITEM_STYLE_CHAPTER_SHOULDERS]=12,
	[ITEM_STYLE_CHAPTER_STAVES]=13,
	[ITEM_STYLE_CHAPTER_SWORDS]=14
}

--Base item id of first trait of first item
local traitLinks = {
	[CRAFTING_TYPE_BLACKSMITHING] = {
		orig={[1]=45018,[2]=45025},
		nirn={[1]=56026,[2]=56038}
	},
	[CRAFTING_TYPE_CLOTHIER] = {
		orig={[1]=45032,[2]=45041},
		nirn={[1]=56045,[2]=56053}
	},
	[CRAFTING_TYPE_WOODWORKING] = {
		orig={[1]=45040,[2]=45048},
		nirn={[1]=56033,[2]=56060}
	},
	[CRAFTING_TYPE_JEWELRYCRAFTING] = {
		neck={[1]=54511,[2]=139398},
		ring={[1]=54507,[2]=139392}
	}
}

local researchableTraits = {
	[ITEM_TRAIT_TYPE_WEAPON_POWERED] = 23203, --Chysolite
	[ITEM_TRAIT_TYPE_WEAPON_CHARGED] = 23204, --Amethyst
	[ITEM_TRAIT_TYPE_WEAPON_PRECISE] = 4486, --Ruby
	[ITEM_TRAIT_TYPE_WEAPON_INFUSED] = 810, --Jade
	[ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = 813, --Turquoise
	[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = 23165, --Carnelian
	[ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = 23149, --Fire Opal
	[ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = 16291, --Citrine
	[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = 56863, --Potent Nirncrux
	[ITEM_TRAIT_TYPE_ARMOR_STURDY] = 4456, --Quartz
	[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = 23219, --Diamond
	[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = 30221, --Sardonyx
	[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = 23221, --Almandine
	[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = 4442, --Emerald
	[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = 30219, --Bloodstone
	[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = 23171, --Garnet
	[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = 23173, --Sapphire
	[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = 56862, --Fortified Nirncrux
	[ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = 135155, --Cobalt
	[ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = 135156, --Antimony
	[ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = 135157, --Zinc
	[ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = 139409, --Dawn-Prism
	[ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = 139411, --Aurbic Amber
	[ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = 139410, --Titanium
	[ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = 139412, --Gilding Wax
	[ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = 139413, --Dibellium
	[ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = 139414 --Slaughterstone
}

-- M:New("test name", itemStyleId, achievementId, collectibleId, id, quality, hasChapters) To get the itemStyleId you need the link of an item in that style, to get the collectibleId you need the heavy head, to get the id you need the motif book (or axes motif minus 1)
-- If adding motifs before they're active in game, instead of commenting them out individually, update the function at the end of the file.
local ARC = ITEM_FUNCTIONAL_QUALITY_ARCANE
local LEG = ITEM_FUNCTIONAL_QUALITY_LEGENDARY
local M = TB_Data_Motif
local motifs = {
	[1] = M:New("High Elf", 7, 1030, 2872, 16424, ARC, false),
	[2] = M:New("Dark Elf", 4, 1030, 2094, 27245, ARC, false),
	[3] = M:New("Wood Elf", 8, 1030, 1734, 16428, ARC, false),
	[4] = M:New("Nord", 5, 1030, 2340, 27244, ARC, false),
	[5] = M:New("Breton", 1, 1030, 1598, 16425, ARC, false),
	[6] = M:New("Redguard", 2, 1030, 2006, 16427, ARC, false),
	[7] = M:New("Khajiit", 9, 1030, 3093, 44698, ARC, false),
	[8] = M:New("Orc", 3, 1030, 1791, 16426, ARC, false),
	[9] = M:New("Argonian", 6, 1030, 2562, 27246, ARC, false),
	[10] = M:New("Imperial", 34, 1043, 3187, 54868, LEG, false),
	[11] = M:New("Ancient Elf", 15, 1043, 2684, 51638, nil, false),
	[12] = M:New("Barbaric", 17, 1043, 2399, 51565, nil, false),
	[13] = M:New("Primal", 19, 1043, 1614, 51345, nil, false),
	[14] = M:New("Daedric", 20, 1043, 2527, 51688, nil, false),
	[15] = M:New("Dwemer", 14, 1144, 3008, 57572),
	[16] = M:New("Glass", 28, 1319, 3556, 64669),
	[17] = M:New("Xivkyn", 29, 1181, 3429, 57834),
	[18] = M:New("Akaviri", 33, 1318, 2956, 57590),
	[19] = M:New("Mercenary", 26, 1348, 3681, 64715),
	[20] = M:New("Yokudan", 35, 1713, 3335, 57605),
	[21] = M:New("Ancient Orc", 22, 1341, 3467, 69527),
	[22] = M:New("Trinimac", 21, 1411, 3781, 71550),
	[23] = M:New("Malacath", 13, 1412, 3788, 71566),
	[24] = M:New("Outlaw", 47, 1417, 3288, 71522),
	[25] = M:New("Aldmeri Dominion", 25, 1415, 3609, 71688),
	[26] = M:New("Daggerfall Covenant", 23, 1416, 3665, 71704),
	[27] = M:New("Ebonheart Pact", 24, 1414, 3570, 71720),
	[28] = M:New("Ra Gada", 44, 1797, 3928, 71672),
	[29] = M:New("Soul Shriven", 30, 1418, 3505, 71765, LEG, false),
	[30] = M:New("Morag Tong", 43, 1933, 3924, 73838),
	[31] = M:New("Skinchanger", 42, 1676, 4087, 73854),
	[32] = M:New("Abah's Watch", 41, 1422, 3940, 74539),
	[33] = M:New("Thieves Guild", 11, 1423, 3838, 74555),
	[34] = M:New("Assassins League", 46, 1424, 3415, 76878),
	[35] = M:New("Dro-M'Athra", 45, 1659, 3865, 74652),
	[36] = M:New("Dark Brotherhood", 12, 1661, 3746, 82054),
	[37] = M:New("Ebony", 40, 1798, 4135, 75228),
	[38] = M:New("Draugr", 31, 1715, 2784, 76894),
	[39] = M:New("Minotaur", 39, 1662, 4011, 82071),
	[40] = M:New("Order Hour", 16, 1660, 4059, 82087),
	[41] = M:New("Celestial", 27, 1714, 3342, 82006),
	[42] = M:New("Hollowjack", 59, 1545, 4258, 82022),
	[43] = M:New("Grim Harlequin", 58, nil, 4106, 82053, LEG, false),
	[44] = M:New("Silken Ring", 56, 1796, 3761, 114967),
	[45] = M:New("Mazzatun", 57, 1795, 4162, 114951),
	[46] = M:New("Frostcaster", 53, nil, 4315, 96954, LEG, false),
	[47] = M:New("Buoyant Armiger", 52, 1934, 4482, 121316),
	[48] = M:New("Ashlander", 54, 1932, 4528, 124679),
	[49] = M:New("Militant Ordinator", 50, 1935, 4491, 121348),
	[50] = M:New("Telvanni", 51, 2023, 4442, 121332),
	[51] = M:New("Hlaalu", 49, 2021, 4402, 129994),
	[52] = M:New("Redoran", 48, 2022, 4421, 130010),
	[53] = M:New("Tsaesci", 38, nil, 4361, 132532, LEG, false),
	[54] = M:New("Bloodforge", 61, 2098, 4581, 132533),
	[55] = M:New("Dreadhorn", 62, 2097, 4622, 132565),
	[56] = M:New("Apostle", 65, 2044, 4948, 132549),
	[57] = M:New("Ebonshadow", 66, 2045, 4962, 132581),
	[58] = M:New("Fang Lair", 69, 2190, 5339, 134755),
	[59] = M:New("Scalecaller", 70, 2189, 5404, 134771),
	[60] = M:New("Worm Cult", 55, 2120, 4215, 134739),
	[61] = M:New("Psijic", 71, 2186, 5318, 137851),
	[62] = M:New("Sapiarch", 72, 2187, 5533, 137920),
	[63] = M:New("Dremora", 74, 2188, 4653, 140444),
	[64] = M:New("Pyandonean", 75, 2285, 5486, 140428),
	[65] = M:New("Huntsman", 77, 2317, 5782, 140462),
	[66] = M:New("Silver Dawn", 78, 2318, 5814, 140478),
	[67] = M:New("Welkynar", 73, 2319, 5666, 140496),
	[68] = M:New("Honor Guard", 80, 2359, 6125, 142186),
	[69] = M:New("Dead-Water", 79, 2360, 5940, 142202),
	[70] = M:New("Elder Argonian", 81, 2361, 5972, 142218),
	[71] = M:New("Coldsnap", 82, 2503, 6332, 147666),
	[72] = M:New("Meridian", 83, 2504, 6300, 147682),
	[73] = M:New("Anequina", 84, 2505, 6542, 147698),
	[74] = M:New("Pellitine", 85, 2506, 6510, 147714),
	[75] = M:New("Sunspire", 86, 2507, 6875, 147730),
	[76] = M:New("Dragonguard", 92, 2630, 7026, 156555),
	[77] = M:New("Stags of Z'en", 89, 2629, 6853, 156573),
	[78] = M:New("Moongrave Fane", 93, 2628, 7145, 156590),
	[79] = M:New("Refabricated", 60, 2024, 4557, 130026),
	[80] = M:New("Shield of Senchal", 95, 2750, 7245, 156627),
	[81] = M:New("New Moon Priest", 94, 2748, 7184, 156608),
	[82] = M:New("Icereach Coven", 97, 2747, 7470, 157517),
	[83] = M:New("Pyre Watch", 98, 2749, 7540, 158291),
	[84] = M:New("Blackreach Vanguard", 100, 2757, 7701, 160493),
	[85] = M:New("Greymoor", 101, 2761, 7831, 160542),
	[86] = M:New("Sea Giant", 102, 2762, 7866, 160559),
	[87] = M:New("Ancestral Nord", 103, 2763, 7899, 160576),
	[88] = M:New("Ancestral Orc", 105, 2776, 7966, 160610),
	[89] = M:New("Ancestral High Elf", 104, 2773, 7934, 160593),
	[90] = M:New("Thorn Legion", 106, 2849, 8231, 166972),
	[91] = M:New("Hazardous Alchemy", 107, 2850, 8263, 166989),
	[92] = M:New("Ancestral Akaviri", 108, 2903, 8390, 167174),
	[93] = M:New("Ancestral Breton", 109, 2904, 8422, 167190),
	[94] = M:New("Ancestral Reach", 110, 2905, 8476, 167270),
	[95] = M:New("Nighthollow", 111, 2926, 8553, 167943),
	[96] = M:New("Arkthzand Armory", 112, 2938, 8589, 167960),
	[97] = M:New("Wayward Guardian", 113, 2998, 8621, 167977),
	[98] = M:New("House Hexos", 114, 2959, 8699, 170131),
	[99] = M:New("Waking Flame", 117, 2991, 8963, 171580),
	[100] = M:New("True-Sworn", 116, 2984, 8922, 171551),
	[101] = M:New("Ivory Brigade", 121, 3001, 9166, 171895),
	[102] = M:New("Sul-Xan", 122, 3002, 9198, 171912),
	[103] = M:New("Black Fin Legion", 120, 3000, 9131, 171878),
	[104] = M:New("Ancient Daedric", 119, 2999, 9092, 171858),
	[105] = M:New("Crimson Oath", 123, 3094, 9473, 176057),
	[106] = M:New("Silver Rose", 124, 3097, 9534, 178504),
	[107] = M:New("Annihilarch's Chosen", 125, 3098, 9593, 178528),
	[108] = M:New("Fargrave Guardian", 126, 3220, 9687, 178706),
--	[109] = M:New("Flame Awoken", , ),
	[110] = M:New("Dreadsails", 128, 3228, 9914, 181661),
	[111] = M:New("Ascendant Order", 129, 3229, 9946, 181678),
	[112] = M:New("Syrabanic Marine", 130, 3258, 10074, 182520),
	[113] = M:New("Steadfast Society", 131, 3259, 10106, 182537),
	[114] = M:New("Systres Guardian", 132, 3260, 10138, 182554),
	[115] = M:New("Y'ffre's Will", 135, 3422, 10443, 187728),
	[116] = M:New("Drowned Mariner", 136, 3423, 10478, 187762),
	[117] = M:New("Firesong", 138, 3464, 10774, 188307),
	[118] = M:New("House Mornard", 139, 3465, 10806, 188324),
	[119] = M:New("Blessed Inheritor", 141, 3547, 10967, 190906),
	[120] = M:New("Scribes of Mora", 140, 3546, 10935, 190889),
	[121] = M:New("Clan Dreamcarver", 142, 3667, 11262, 194492),
	[122] = M:New("Dead Keeper", 143, 3668, 11295, 194513),
	[123] = M:New("Kindred's Concord", 144, 3669, 11329, 194540),
	[124] = M:New("The Recollection", 145, 3921, 11928, 203182),
	[125] = M:New("Blind Path Cultist", 146, 3922, 11964, 203214),
	[126] = M:New("Shardborn", 147, 3923, 12074, 203360),
	[127] = M:New("West Weald Legion", 148, 3924, 12106, 203473),
	[128] = M:New("Lucent Sentinel", 149, 3925, 12138, 203492),
	[129] = M:New("Hircine Bloodhunter", 151, nil, 12275, 203834, LEG, false),
	[130] = M:New("Exile's Revenge", 153, 4159, 12879, 211054),
	[131] = M:New("Militant Monk", 154, 4160, 12911, 211071),
	[132] = M:New("Stirk Fellowship", 155, 4240, 13119, 212084),
	[133] = M:New("Coldharbour Dominator", 156, 4241, 13151, 212101),
	[134] = M:New("Tide-Born", 157, 4242, 13183, 212118),
	[135] = M:New("Black Soul Gem", 158, 4289, 13310, 212424),
	[136] = M:New("Voskrona Guardian", 159, 4290, 13342, 212441),
	[137] = M:New("Koldane Cartel", 162, 4491, 14228,223947),
}

TB_Data = ZO_Object:Subclass()

local chapterConstant = nil
local function GetChapterConstantTable()
	if not chapterConstant then
		chapterConstant = {}
		for constant, order in pairs(chapterOrder) do
			chapterConstant[order] = constant
		end
	end
	return chapterConstant
end

function TB_Data:GetChapterConstant(order)
	return GetChapterConstantTable()[order]
end

function TB_Data:New(...)
	local object = ZO_Object.New(self)
	object:Initialize(...)
	return object
end

function TB_Data:GetTraitLinkID(craftingSkillType, researchLineIndex, traitIndex)
	--Rather than storing 306 unique ids
	local researchLineSplit = TraitBuddy.ui:GetResearchSplit()
	local split = researchLineSplit[craftingSkillType]
	local part = 1
	local start = 1
	local id = 0
	if researchLineIndex >= split then
		--Second section, normally armour
		start = split
		part = 2
	end
	if traitIndex==9 then
		id = traitLinks[craftingSkillType].nirn[part]+researchLineIndex-start
		--All nirns are sequential except the last 2 in light armour
		if craftingSkillType==CRAFTING_TYPE_CLOTHIER and part==1 and researchLineIndex>=split-2 then
			id=id+1
		end
	else
		local base = traitLinks[craftingSkillType].orig[part]
		--All are sequential except the last 2 in light armour and the first one in wood is odd
		if craftingSkillType==CRAFTING_TYPE_CLOTHIER and part==1 and researchLineIndex>=split-2 then
			base=base+1
		elseif craftingSkillType==CRAFTING_TYPE_WOODWORKING and part==1 and researchLineIndex>1 then
			base=base+8
		end
		id = 35*traitIndex-35+base+researchLineIndex-start
	end
	return id
end

function TB_Data:GetJewelryTraitLinkID(researchLineIndex, traitIndex)
	--Rather than storing 18 unique ids
	local id = 0
	local part = 1
	if traitIndex >= 4 then
		part = 2
	end
	if researchLineIndex==1 then
		-- Pewter Ring (54512 to 54514, 139402 to 139407)
		id = traitLinks[CRAFTING_TYPE_JEWELRYCRAFTING].ring[part]+traitIndex
	else
		-- Pewter Necklace (54508 to 54510, 139396 to 139401)
		id = traitLinks[CRAFTING_TYPE_JEWELRYCRAFTING].neck[part]+traitIndex
	end
	if traitIndex==1 or traitIndex==5 then
		id = id+1
	elseif traitIndex==2 or traitIndex==6 then
		id = id-1
	end
	return id
end

function TB_Data:GetResearchableTraitMaterials()
	return researchableTraits
end

function TB_Data:IsResearchableTrait(traitType)
	if not traitType then return false end
	return (researchableTraits[traitType] ~= nil)
end

function TB_Data:GetMotif(index)
	return motifs[index]
end

function TB_Data:GetMotifs()
	return motifs
end

function TB_Data:GetNumMotifs()
	local numMotifs = NonContiguousCount(motifs)
	local numChapters = self:GetNumChapters()
	local numChaptersTotal = 0
	for order,motif in pairs(motifs) do
		if motif:HasChapters() then
			numChaptersTotal = numChaptersTotal + numChapters
		end
	end
	return numMotifs, numChaptersTotal
end

function TB_Data:GetNumChapters()
	return NonContiguousCount(chapterOrder)
end

function TB_Data:GetMotifByItemStyleId(itemStyleId)
	for order,motif in pairs(motifs) do
		if motif:ItemStyleId()==itemStyleId then
			return motif
		end
	end
	return nil
end

function TB_Data:GetChapterOrder(chapterIndex)
	return chapterOrder[chapterIndex] or ITEM_STYLE_CHAPTER_ALL
end

function TB_Data:GetMotifStyle(itemLink)
	--Returns: itemStyleId, chapter, motifOrder, chapterOrder
	local itemId = select(4, ZO_LinkHandler_ParseLink(itemLink))
	itemId = tonumber(itemId)
	for order,motif in pairs(motifs) do
		if motif:HasChapters() then
			for chapterStyle,chapterOrder in pairs(chapterOrder) do
				if itemId==motif:ChapterId(chapterOrder) then
					return motif:ItemStyleId(), chapterStyle, order, chapterOrder
				end
			end
		else
			if itemId==motif:Id() then
				return motif:ItemStyleId(), ITEM_STYLE_CHAPTER_ALL, order, nil
			end
		end
	end
	return 0, ITEM_STYLE_CHAPTER_ALL, nil, nil
end

function TB_Data:TestMotifs()
	-- /script d(TraitBuddy.data:TestMotifs())
	local issues = 0
	for order,motif in pairs(motifs) do
		motif:Check()
		if motif:HasIssues() then
			issues = issues + 1
			for k,issue in ipairs(motif:Issues()) do
				d(sf("Check %s %s", motif:Order(), issue))
			end
		end
	end
	d(sf("Motif Test: Issues with %s motif(s).", issues))
end

function TB_Data:TestMotifsDump()
	for itemStyleIndex = 1, GetNumValidItemStyles() do
		local itemStyleId = GetValidItemStyleId(itemStyleIndex)
		if itemStyleId > 0 then
			local styleItemLink = GetItemStyleMaterialLink(itemStyleId, LINK_STYLE_DEFAULT) or ""
			local itemId = select(4, ZO_LinkHandler_ParseLink(styleItemLink))
			itemId = tonumber(itemId) or 0
			d(sf("Id %s %s %s itemId %d", itemStyleId, GetItemStyleName(itemStyleId), styleItemLink, itemId))
		end
	end
end

function TB_Data:TestMotifsMissing()
	d("Checking for missing motifs...")
	local lookat = 0
	local universal = 36
	for itemStyleIndex = 1, GetNumValidItemStyles() do
		local itemStyleId = GetValidItemStyleId(itemStyleIndex)
		if itemStyleId > 0 then
			local motif = self:GetMotifByItemStyleId(itemStyleId)
			if not motif then
				local styleItemLink = GetItemStyleMaterialLink(itemStyleId, LINK_STYLE_DEFAULT)
				local materialItemId = select(4, ZO_LinkHandler_ParseLink(styleItemLink))
				materialItemId = tonumber(materialItemId)
				if materialItemId ~= nil and itemStyleId ~= universal then lookat = lookat + 1 end
				d(sf("Id %s %s %s", itemStyleId, GetItemStyleName(itemStyleId), styleItemLink))
			end
		end
	end
	d(sf("Done! %s to look at", lookat))
end

function TB_Data:TestLoreBooks()
	-- /script d(TraitBuddy.data:TestLoreBooks())
	local order = self:GetChapterOrder(ITEM_STYLE_CHAPTER_AXES)
	local motif = self:GetMotif(15) -- [15] = M:New("Dwemer", 14, 1144, 3008, 57572),
	d(motif:ChapterLink(order))
	d(motif:AchievementLink())
	-- local collectionId = GetAchievementLinkedBookCollectionId(1144)
	local categoryIndex, collectionIndex = GetLoreBookCollectionIndicesFromCollectionId(GetAchievementLinkedBookCollectionId(motif:AchievementId()))
	local title, icon, known, bookId = GetLoreBookInfo(categoryIndex, collectionIndex, order) -- Dwemer axe |H1:book:2857|h|h
	d(sf("title:%s known:%s bookId:%s", title, tostring(known), bookId))
end

function TB_Data:TestPatterns()
	d("TraitBuddy DEBUG: TestPatterns()")
	--[[
	* GetSmithingPatternInfo(*luaindex* patternIndex, *luaindex:nilable* materialIndexOverride, *integer:nilable* materialQuanityOverride, *integer:nilable* styleOverride, *[ItemTraitType|#ItemTraitType]:nilable* traitTypeOverride)
	** Returns: *string* patternName, *string* baseName, *textureName* icon, *integer* numMaterials, *integer* numTraitsRequired, *integer* numTraitsKnown, *[ItemFilterType|#ItemFilterType]* resultItemFilterType

	* GetSmithingPatternInfoForItemId(*integer* itemId, *integer* materialItemId, *[TradeskillType|#TradeskillType]* craftingSkillType)
	** Returns: *luaindex:nilable* patternIndex, *luaindex:nilable* materialIndex

	* GetSmithingPatternInfoForItemSet(*integer* itemTemplateId, *integer* itemSetId, *integer* materialItemId, *[ItemTraitType|#ItemTraitType]* traitType)
	** Returns: *luaindex:nilable* patternIndex, *luaindex:nilable* materialIndex, *integer:nilable* resultingItemId

	* GetSmithingPatternMaterialItemInfo(*luaindex* patternIndex, *luaindex* materialIndex)
	** Returns: *string* itemName, *textureName* icon, *integer* stack, *integer* sellPrice, *bool* meetsUsageRequirement, *[EquipType|#EquipType]* equipType, *integer* itemStyleId, *[ItemDisplayQuality|#ItemDisplayQuality]* displayQuality, *integer* itemInstanceId, *integer* skillRequirement, *integer* createsItemOfLevel, *bool* isChampionPoint

	]]--
	-- local patternIndex, materialIndex = GetSmithingPatternInfoForItemId(itemId, materialItemId, craftingSkillType)

	-- local patternIndex, materialIndex, resultingItemId = GetSmithingPatternInfoForItemSet(itemTemplateId, itemSetId, materialItemId, traitType)

	local numSmithingPatterns = GetNumSmithingPatterns()
	if numSmithingPatterns == 0 then
		d("Only works at a crafting station")
		return
	end
	local materialIndex = 1
	for patternIndex = 1, numSmithingPatterns do
		local patternName, _, _, numMaterials = GetSmithingPatternInfo(patternIndex)
		local _, _, stack = GetSmithingPatternMaterialItemInfo(patternIndex, materialIndex)
		d(sf("Pattern %s - %s - stack %s", patternIndex, patternName, stack))
	end
end

function TB_Data:Initialize_Motifs()
	for itemStyleIndex = 1, GetNumValidItemStyles() do
		local itemStyleId = GetValidItemStyleId(itemStyleIndex)
		if itemStyleId > 0 then
			local motif = self:GetMotifByItemStyleId(itemStyleId)
			if motif then
				local styleItemLink = GetItemStyleMaterialLink(itemStyleId, LINK_STYLE_DEFAULT)
				local icon = GetItemLinkInfo(styleItemLink)
				local itemId = select(4, ZO_LinkHandler_ParseLink(styleItemLink))
				motif:SetMaterial(itemId, icon)
			else
				--d(sf("TraitBuddy DEBUG: Could not Initialize motif itemStyleId:%s", itemStyleId))
			end
		end
	end
	for order,motif in pairs(motifs) do
		motif:SetOrder(order)
	end
end

function TB_Data:Initialize()
	self:Initialize_Motifs()
	if GetAPIVersion() < 101050 then
		--Remove content until it is active
		motifs[137] = nil
		motifs[138] = nil
--		sets[60] = nil

	end
	-- check if these motifs exist
	if not motifs[130]:MaterialId() then
		motifs[130] = nil
	end
	if not motifs[129]:MaterialId() then
		motifs[129] = nil
	end

--	self:Initialize_Sets()
end