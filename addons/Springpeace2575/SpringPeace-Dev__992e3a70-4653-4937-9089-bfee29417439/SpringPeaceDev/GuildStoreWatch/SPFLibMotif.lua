-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- Motif library (SpringPeace Framework)
-----------------------------------------------------------

local LCK = LibCharacterKnowledge
SPFLibMotif = SPFLibMotif or {}

SPFLibMotif.MOTIF_PAGE = {
    STYLE      =  0     -- ITEM_STYLE_CHAPTER_ALL       =  0
,   AXES       =  1     -- ITEM_STYLE_CHAPTER_AXES      = 10
,   BELTS      =  2     -- ITEM_STYLE_CHAPTER_BELTS     =  6
,   BOOTS      =  3     -- ITEM_STYLE_CHAPTER_BOOTS     =  3
,   BOWS       =  4     -- ITEM_STYLE_CHAPTER_BOWS      = 14
,   CHESTS     =  5     -- ITEM_STYLE_CHAPTER_CHESTS    =  5
,   DAGGERS    =  6     -- ITEM_STYLE_CHAPTER_DAGGERS   = 11
,   GLOVES     =  7     -- ITEM_STYLE_CHAPTER_GLOVES    =  2
,   HELMETS    =  8     -- ITEM_STYLE_CHAPTER_HELMETS   =  1
,   LEGS       =  9     -- ITEM_STYLE_CHAPTER_LEGS      =  4
,   MACES      = 10     -- ITEM_STYLE_CHAPTER_MACES     =  9
,   SHIELDS    = 11     -- ITEM_STYLE_CHAPTER_SHIELDS   = 13
,   SHOULDERS  = 12     -- ITEM_STYLE_CHAPTER_SHOULDERS =  7
,   STAVES     = 13     -- ITEM_STYLE_CHAPTER_STAVES    = 12
,   SWORDS     = 14     -- ITEM_STYLE_CHAPTER_SWORDS    =  8
}

-- Convert from SPFLibMotif to LibCharacterKnowledge page indices.
SPFLibMotif.MOTIF_PAGE_TO_CHAPTER = {
    [SPFLibMotif.MOTIF_PAGE.AXES       ] = ITEM_STYLE_CHAPTER_AXES      -- 10
,   [SPFLibMotif.MOTIF_PAGE.BELTS      ] = ITEM_STYLE_CHAPTER_BELTS     --  6
,   [SPFLibMotif.MOTIF_PAGE.BOOTS      ] = ITEM_STYLE_CHAPTER_BOOTS     --  3
,   [SPFLibMotif.MOTIF_PAGE.BOWS       ] = ITEM_STYLE_CHAPTER_BOWS      -- 14
,   [SPFLibMotif.MOTIF_PAGE.CHESTS     ] = ITEM_STYLE_CHAPTER_CHESTS    --  5
,   [SPFLibMotif.MOTIF_PAGE.DAGGERS    ] = ITEM_STYLE_CHAPTER_DAGGERS   -- 11
,   [SPFLibMotif.MOTIF_PAGE.GLOVES     ] = ITEM_STYLE_CHAPTER_GLOVES    --  2
,   [SPFLibMotif.MOTIF_PAGE.HELMETS    ] = ITEM_STYLE_CHAPTER_HELMETS   --  1
,   [SPFLibMotif.MOTIF_PAGE.LEGS       ] = ITEM_STYLE_CHAPTER_LEGS      --  4
,   [SPFLibMotif.MOTIF_PAGE.MACES      ] = ITEM_STYLE_CHAPTER_MACES     --  9
,   [SPFLibMotif.MOTIF_PAGE.SHIELDS    ] = ITEM_STYLE_CHAPTER_SHIELDS   -- 13
,   [SPFLibMotif.MOTIF_PAGE.SHOULDERS  ] = ITEM_STYLE_CHAPTER_SHOULDERS --  7
,   [SPFLibMotif.MOTIF_PAGE.STAVES     ] = ITEM_STYLE_CHAPTER_STAVES    -- 12
,   [SPFLibMotif.MOTIF_PAGE.SWORDS     ] = ITEM_STYLE_CHAPTER_SWORDS    --  8
}

SPFLibMotif.MOTIF_PAGE_TO_CHAPTER_NAME = {
	[0] = SI_ITEMSTYLECHAPTER0,     -- Style (All Chapters, Book)
	[1] = SI_ITEMSTYLECHAPTER10,    -- Axes
	[2] = SI_ITEMSTYLECHAPTER6,     --"Belts",
	[3] = SI_ITEMSTYLECHAPTER3,     --"Boots",
    [4] = SI_ITEMSTYLECHAPTER14,    --"Bows",
	[5] = SI_ITEMSTYLECHAPTER5,     --"Chests",
	[6] = SI_ITEMSTYLECHAPTER11,    --"Daggers",
	[7] = SI_ITEMSTYLECHAPTER2,     --"Gloves",
	[8] = SI_ITEMSTYLECHAPTER1,     --"Helmets",
	[9] = SI_ITEMSTYLECHAPTER4,     --"Legs",
	[10] = SI_ITEMSTYLECHAPTER9,    --"Maces",
	[11] = SI_ITEMSTYLECHAPTER13,   --"Shields",
	[12] = SI_ITEMSTYLECHAPTER7,    --"Shoulders",
	[13] = SI_ITEMSTYLECHAPTER12,   --"Staves",
	[14] = SI_ITEMSTYLECHAPTER8,    --"Swords",
}

SPFLibMotif.MAX_MOTIF_PAGE_NUMBERS = 14

-- Does the current character know this crafting motif for
-- axes, chests, whatever?
--
-- motifId is a motif number, range [1..117].
--
-- pageNumber is a purple motif page index, [1..14].
--
function SPFLibMotif.IsKnown(motifId, pageNumber)
    -- Convert from UI-visible chapter indices to
    -- the ones LibCharacterKnowledge expects.
    local lck_index = SPFLibMotif.MOTIF_PAGE_TO_CHAPTER[pageNumber or ITEM_STYLE_CHAPTER_ALL]
    local r = LCK.GetMotifKnowledgeForCharacter(motifId, lck_index)
    local isKnown = r == LCK.KNOWLEDGE_KNOWN
    -- d("GSW SPFLibMotif: "..tostring(motifId).."; "..tostring(pageNumber).."; isKnown: "..tostring(isKnown))
    return isKnown
end

function SPFLibMotif.GetStyleAndChapterFromMotif(itemLink)
    return LCK.GetStyleAndChapterFromMotif(itemLink)
end

function SPFLibMotif.IsMotifChapter(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    return itemType == ITEMTYPE_RACIAL_STYLE_MOTIF
end

function SPFLibMotif.GetMotifNumberAndPageNumberFromItemName(name)
    -- this is not useful so much, motifNumber != motifId and pageNumber != chapterId
    if not name or name == "" then return nil, nil end
    local motifNumberStr, pageName = name:match("^Crafting Motif (%d+):.+ (%w+)$")
    local motifNumber = motifNumberStr and tonumber(motifNumberStr) or nil
    local pageNumber = SPFLibMotif.MOTIF_PAGE[zo_strupper(pageName)] or nil
    return motifNumber, pageNumber
end

function SPFLibMotif.GetMotifSetKnowledge(motifId)
  local knownPagesInMotif = 0
  local totalMotifs = 0
  local knownMotifs = 0
  local motifName = GetItemStyleName(motifId)

  if motifName and motifName ~= "" then
    for pageNumber = 1, SPFLibMotif.MAX_MOTIF_PAGE_NUMBERS do
      totalMotifs = totalMotifs + 1
      if SPFLibMotif.IsKnown(motifId, pageNumber) then
        knownPagesInMotif = knownPagesInMotif + 1
        knownMotifs = knownMotifs + 1
      end
    end
  end

  return totalMotifs, knownMotifs
end



-- Cached motifs knowledge feature

SPFLibMotif.motifChapterCache = SPFLibMotif.motifChapterCache or {}
SPFLibMotif.REBUILD_CACHE_ITEM_DELAY = 20

function SPFLibMotif.GetMotifChapterCacheEntry(motifNumber)
    local totalPages, knownPages = SPFLibMotif.GetMotifSetKnowledge(motifNumber)
    local entry = {
        motifNumber = motifNumber,
        unlocked = knownPages,
        total = totalPages,
    }
    return entry
end

function SPFLibMotif.RebuildMotifChapterInCache(motifNumber, maxMotifId)
    SPFLibMotif.motifChapterCache[motifNumber] = SPFLibMotif.GetMotifChapterCacheEntry(motifNumber)

    if motifNumber < maxMotifId then
        zo_callLater(function() SPFLibMotif.RebuildMotifChapterInCache(motifNumber + 1, maxMotifId) end, SPFLibMotif.REBUILD_CACHE_ITEM_DELAY)
    end
end

function SPFLibMotif.RebuildMotifChapterCache()
    SPFLibMotif.motifChapterCache = {}

    local maxMotifId  = GetHighestItemStyleId()
    -- d("GSW GetHighestItemStyleId: "..tostring(maxMotifId))
    zo_callLater(function() SPFLibMotif.RebuildMotifChapterInCache(1, maxMotifId) end, SPFLibMotif.REBUILD_CACHE_ITEM_DELAY)
end

function SPFLibMotif.RebuildMotifChapterCacheEntry(motifNumber)
    local entry = SPFLibMotif.GetMotifChapterCacheEntry(motifNumber)
    SPFLibMotif.motifChapterCache[motifNumber] = entry
end

function SPFLibMotif.GetCachedMotifChapterInfo(itemLink)
    if not SPFLibMotif.IsMotifChapter(itemLink) then
        return nil
    end

    local motifNumber = LCK.GetStyleAndChapterFromMotif(itemLink)

    local entry = SPFLibMotif.motifChapterCache and SPFLibMotif.motifChapterCache[motifNumber]
    if not entry then
        entry = SPFLibMotif.GetMotifChapterCacheEntry(motifNumber)
        SPFLibMotif.motifChapterCache[motifNumber] = entry
    end

    return entry
end
