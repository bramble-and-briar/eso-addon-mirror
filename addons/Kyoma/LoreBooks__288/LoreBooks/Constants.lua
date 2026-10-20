--[[
-------------------------------------------------------------------------------
-- LoreBooks
-------------------------------------------------------------------------------
-- Original author: Ales Machat (Garkin), started 2014-04-18
--
-- Maintainers:
--    Ayantir (contributions starting 2015-11-07)
--    Kyoma (contributions starting 2018-05-30)
--    Sharlikran (current maintainer, contributions starting 2022-11-12)
--
-------------------------------------------------------------------------------
-- This addon includes contributions licensed under two Creative Commons licenses
-- and the original MIT license:
--
-- MIT License (Garkin, 2014–2015):
--   Permission is hereby granted, free of charge, to any person obtaining a copy
--   of this software and associated documentation files (the "Software"), to deal
--   in the Software without restriction, including without limitation the rights
--   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--   copies of the Software, and to permit persons to whom the Software is
--   furnished to do so, subject to the conditions in the LICENSE file.
--
-- Creative Commons BY-NC-SA 4.0 (Ayantir, 2015–2020 and Sharlikran, 2022–present):
--   You are free to share and adapt the material with attribution, but not for
--   commercial purposes. Derivatives must be licensed under the same terms.
--   Full terms at: https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
--
-------------------------------------------------------------------------------
-- Maintainer Notice:
-- Redistribution of this addon outside of ESOUI.com or GitHub is discouraged
-- unless authorized by the current maintainer. While the original MIT license
-- permits wide redistribution, uncoordinated uploads may cause version
-- fragmentation or confusion. Please respect the intent of the maintainers and
-- the ESO addon ecosystem.
-- ----------------------------------------------------------------------------
-- Data Integrity and Attribution Notice:
-- While individual book positions are discoverable via the ESO API, the
-- comprehensive dataset included in LoreBooks is the result of years of
-- community effort and contributions from multiple players. Recreating this
-- dataset independently requires extensive time and dedication.
--
-- Direct reuse, extraction, or redistribution of the compiled data tables,
-- either in whole or substantial part, without permission from the current
-- maintainer, is prohibited. Claiming ownership or sole authorship over
-- derived works that include this dataset is considered a violation of the
-- contributors' efforts and the licenses under which this project is shared.
--
-- If you wish to use this data in your own addon or tool, please contact the
-- current maintainer for appropriate guidance and permission.
-- ----------------------------------------------------------------------------
]]
local LoreBooks = {}
local internal = {}
LoreBooks.db = {}
_G["LoreBooks"] = LoreBooks
_G["LoreBooks_Internal"] = internal
internal.collectionInfoCache = internal.collectionInfoCache or {}

--Local constants -------------------------------------------------------------
internal.ADDON_NAME = "LoreBooks"
internal.ADDON_AUTHOR = "Garkin, Ayantir, Kyoma, |cFF9B15Sharlikran|r"
internal.ADDON_VERSION = "108"
internal.ADDON_WEBSITE = "http://www.esoui.com/downloads/info288-LoreBooks.html"
internal.ADDON_PANEL = "LoreBooksPanel"
internal.SAVEDVARIABLES_VERSION = 3

-- Pins
internal.PINS_UNKNOWN = "LBooksMapPin_unknown"
internal.PINS_COLLECTED = "LBooksMapPin_collected"
internal.PINS_EIDETIC = "LBooksMapPin_eidetic"
internal.PINS_EIDETIC_COLLECTED = "LBooksMapPin_eideticCollected"
internal.PINS_COMPASS = "LBooksCompassPin_unknown"
internal.PINS_COMPASS_EIDETIC = "LBooksCompassPin_eidetic"
internal.PINS_BOOKSHELF = "LBooksMapPin_bookshelf"
internal.PINS_COMPASS_BOOKSHELF = "LBooksCompassPin_bookshelf"

-- callbackType
LoreBooks.callbackType = {}
LoreBooks.callbackType.MOTIF_CHECKBOX_CHANGED = "LoreBooksMotifCheckboxChanged"

local callbackObject = ZO_CallbackObject:New()
LoreBooks.callbackObject = {}
LoreBooks.callbackObject = callbackObject

function LoreBooks:RegisterCallback(...)
  return LoreBooks.callbackObject:RegisterCallback(...)
end

function LoreBooks:UnregisterCallback(...)
  return LoreBooks.callbackObject:UnregisterCallback(...)
end

function LoreBooks:FireCallbacks(...)
  return callbackObject:FireCallbacks(...)
end

-- Pin Textures
internal.PIN_ICON_REAL = 1
internal.PIN_ICON_SET1 = 2
internal.PIN_ICON_SET2 = 3
internal.PIN_ICON_ESOHEAD = 4
internal.PIN_TEXTURES = {
  [internal.PIN_ICON_REAL] = { "EsoUI/Art/Icons/lore_book4_detail4_color5.dds", "EsoUI/Art/Icons/lore_book4_detail4_color5.dds" },
  [internal.PIN_ICON_SET1] = { "LoreBooks/Icons/book1.dds", "LoreBooks/Icons/book1-invert.dds" },
  [internal.PIN_ICON_SET2] = { "LoreBooks/Icons/book2.dds", "LoreBooks/Icons/book2-invert.dds" },
  [internal.PIN_ICON_ESOHEAD] = { "LoreBooks/Icons/book3.dds", "LoreBooks/Icons/book3-invert.dds" },
}
internal.MISSING_TITLE = "Untitled (Missing Translation)"
internal.MISSING_TEXTURE = "/esoui/art/icons/icon_missing.dds"
internal.PLACEHOLDER_TEXTURE = "/esoui/art/icons/lore_book4_detail1_color2.dds"

internal.LORE_LIBRARY_SHALIDOR = 1
internal.LORE_LIBRARY_CRAFTING = 2
internal.LORE_LIBRARY_EIDETIC = 3

-- Immersive Modes
internal.IMMERSIVE_DISABLED = 1
internal.IMMERSIVE_MAINQUEST = 2
internal.IMMERSIVE_WAYSHRINES = 3
internal.IMMERSIVE_EXPLORATION = 4
internal.IMMERSIVE_ZONEQUESTS = 5

internal.SHALIDOR_LOCATION_X = 1
internal.SHALIDOR_LOCATION_Y = 2
internal.SHALIDOR_COLLECTIONINDEX = 3
internal.SHALIDOR_BOOKINDEX = 4
internal.SHALIDOR_ZONEID = 5
internal.SHALIDOR_MOREINFO_BREADCRUMB = 9999

internal.LBOOKS_IMMERSIVE_DISABLED = 1
internal.LBOOKS_IMMERSIVE_ZONEMAINQUEST = 2
internal.LBOOKS_IMMERSIVE_WAYSHRINES = 3
internal.LBOOKS_IMMERSIVE_EXPLORATION = 4
internal.LBOOKS_IMMERSIVE_ZONEQUESTS = 5

internal.icon_list_zoneid = {
  [281] = "/esoui/art/icons/housing_arg_fur_mrkshelftall001.dds", -- balfoyen_base_0
  [280] = "/esoui/art/icons/housing_dun_fur_bookcaset001.dds", -- bleakrock_base_0
  [57] = "/esoui/art/icons/housing_vrd_fur_hlabookcase001.dds", -- deshaan_base_0
  [101] = "/esoui/art/icons/housing_nor_fur_bookcaselrg001.dds", -- eastmarch_base_0
  [117] = "/esoui/art/icons/housing_arg_fur_mrkshelftall001.dds", -- shadowfen_base_0
  [41] = "/esoui/art/icons/housing_vrd_fur_hlachinacabinetdoor001.dds", -- stonefalls_base_0
  [103] = "/esoui/art/icons/housing_nor_duc_shelflarge002.dds", -- therift_base_0
  [104] = " /esoui/art/icons/housing_red_fur_varbookcasecombined004.dds", -- alikr_base_0
  [92] = "/esoui/art/icons/housing_bre_fur_bookcasetall001.dds", -- bangkorai_base_0
  [535] = "/esoui/art/icons/housing_orc_fur_wtgbookcase001.dds", -- betnihk_base_0
  [3] = "/esoui/art/icons/housing_cra_fur_bookshelvescombo005.dds", -- glenumbra_base_0
  [20] = "/esoui/art/icons/housing_bre_fur_bookcasetall001.dds", -- rivenspire_base_0
  [19] = "/esoui/art/icons/housing_bre_fur_bookcasetall001.dds", -- stormhaven_base_0
  [534] = "/esoui/art/icons/housing_red_fur_varbookcasecombined004.dds", -- strosmkai_base_0
  [381] = "/esoui/art/icons/housing_ayl_duc_bookcaselarge002.dds", -- auridon_base_0
  [383] = "/esoui/art/icons/housing_bos_fur_shelf002.dds", -- grahtwood_base_0
  [108] = "/esoui/art/icons/housing_bos_fur_shelf002.dds", -- greenshade_base_0
  [537] = "/esoui/art/icons/housing_kha_fur_bookcase001.dds", -- khenarthisroost_base_0
  [58] = "/esoui/art/icons/housing_bos_fur_shelf002.dds", -- malabaltor_base_0
  [382] = "/esoui/art/icons/housing_kha_fur_bookcase001.dds", -- reapersmarch_base_0
  [1027] = "/esoui/art/icons/housing_sum_fur_highbookcase001.dds", -- artaeum_base_0
  [1208] = "/esoui/art/icons/housing_skr_fur_housingvampirebookcasefilled002.dds", -- u28_blackreach_base_0
  [1161] = "/esoui/art/icons/housing_skr_fur_housingvampirebookcasefilled001.dds", -- blackreach_base_0
  [1261] = "/esoui/art/icons/housing_bad_fur_housingleybookcasetallfilled001.dds", -- blackwood_base_0
  [980] = "/esoui/art/icons/housing_cwc_fur_informationwall001.dds", -- clockwork_base_0
  [981] = "/esoui/art/icons/housing_cwc_fur_informationwall001.dds", -- brassfortress_base_0
  [982] = "/esoui/art/icons/housing_cwc_fur_informationwall001.dds", -- clockworkoutlawsrefuge_base_0
  [347] = "/esoui/art/icons/housing_cld_duc_bookcaseprop002.dds", -- coldharbour_base_0
  [888] = "/esoui/art/icons/housing_coh_inc_housingbookcase001.dds", -- craglorn_base_0
  [2119] = " /esoui/art/icons/housing_bad_fur_dedhighbookshelf001.dds", -- Fargrave The zone - using mapId
  [1282] = " /esoui/art/icons/housing_bad_fur_dedhighbookshelf001.dds", -- Fargrave City - using zoneId
  [2082] = " /esoui/art/icons/housing_bad_fur_dedhighbookshelf001.dds", -- The Shambles - using mapId
  [823] = "/esoui/art/icons/housing_kha_fur_bookcase001.dds", -- goldcoast_base_0
  [816] = "/esoui/art/icons/housing_kha_fur_bookcase001.dds", -- hewsbane_base_0
  [1318] = "/esoui/art/icons/housing_bre_fur_bookcasetall001.dds", -- u34_systreszone_base_0
  [1383] = "/esoui/art/icons/housing_bre_fur_bookcasetall001.dds", -- u36_galenisland_base_0
  [1413] = "/esoui/art/icons/housing_vrd_fur_telshelvesorganic001.dds", -- u38_apocrypha_base_0
  [2274] = "/esoui/art/icons/housing_vrd_fur_telshelvesorganic001.dds", -- u38_telvannipeninsula_base_0, Telvanni Peninsula, 1414 - using mapId
  [2343] = "/esoui/art/icons/housing_vrd_fur_telshelvesorganic001.dds", -- u38_necrom_base_0, Necrom, 1414 - using mapId
  [726] = "/esoui/art/icons/housing_arg_duc_bookcasecombined001.dds", -- murkmire_base_0
  [1086] = "/esoui/art/icons/housing_els_fur_housingmedbookcase001.dds", -- elsweyr_base_0
  [1133] = "/esoui/art/icons/housing_els_run_housingbookshelves001.dds", -- southernelsweyr_base_0
  [1011] = "/esoui/art/icons/housing_sum_fur_highbookcase001.dds", -- summerset_base_0
  [1286] = "/esoui/art/icons/housing_bad_fur_dedhighbookshelf001.dds", -- u32deadlandszone_base_0
  [1207] = "/esoui/art/icons/housing_nor_duc_shelflarge002.dds", -- reach_base_0
  [849] = "/esoui/art/icons/housing_vrd_fur_telshelvesorganic001.dds", -- vvardenfell_base_0
  [1443] = "/esoui/art/icons/housing_vrd_fur_telshelvesorganic001.dds", -- westwealdoverland_base_0
  [1160] = "/esoui/art/icons/housing_skr_fur_housingbookshelffancyfilled003.dds", -- westernskryim_base_0
  [684] = "/esoui/art/icons/housing_orc_fur_wtgbookshelf002.dds", -- wrothgar_base_0
  [181] = "/esoui/art/icons/housing_cra_fur_bookshelvescombo005.dds", -- ava_whole_0
  [584] = "/esoui/art/icons/housing_cra_fur_bookshelvescombo005.dds", -- imperialcity_base_0
  [267] = "/esoui/art/icons/housing_alt_fur_cabinet004.dds", -- eyevea_base_0
}

LoreBooks.defaults = {      --default settings for saved variables
  compassMaxDistance = 0.04,
  pinTexture = {
    type = internal.PIN_ICON_REAL,
    size = 26,
    level = 40,
  },
  pinGrayscale = true,
  pinTextureEidetic = internal.PIN_ICON_REAL,
  pinGrayscaleEidetic = true,
  filters = {
    [internal.PINS_COMPASS_EIDETIC] = false,
    [internal.PINS_COMPASS] = true,
    [internal.PINS_UNKNOWN] = true,
    [internal.PINS_COLLECTED] = false,
    [internal.PINS_EIDETIC] = false,
    [internal.PINS_EIDETIC_COLLECTED] = false,
    [internal.PINS_BOOKSHELF] = true,
    [internal.PINS_COMPASS_BOOKSHELF] = false,

  },
  unlockEidetic = false,
  immersiveMode = 1,
  showClickMenu = true,
  showDungeonTag = true,
  showQuestName = true,
}

-- /esoui/art/icons/housing_arg_fur_mrkshelftall001.dds Argonian
-- /esoui/art/icons/housing_arg_duc_bookcasecombined001.dds Murkmire Bookshelf, Full
-- /esoui/art/icons/housing_bre_fur_bookcasetall001.dds Brenton
-- /esoui/art/icons/housing_dun_fur_bookcaset001.dds Dark Elf
-- /esoui/art/icons/housing_vrd_fur_telshelvesorganic001.dds Telvanni
-- /esoui/art/icons/housing_vrd_fur_hlabookcase001.dds Hlaalu
-- /esoui/art/icons/housing_bad_fur_dedhighbookshelf001.dds Deadlands Etched
-- /esoui/art/icons/housing_alt_fur_cabinet004.dds High Elf
-- /esoui/art/icons/housing_vrd_fur_hlachinacabinetdoor001.dds Hlaalu Orderly *
-- /esoui/art/icons/housing_kha_fur_bookcase001.dds Khajiit
-- /esoui/art/icons/housing_bad_fur_housingleybookcasetallfilled001.dds Leyawiin
-- /esoui/art/icons/housing_nor_fur_bookcaselrg001.dds Nord Bookcase, Alcove
-- /esoui/art/icons/housing_nor_duc_shelflarge002.dds Ancient Nord Bookshelf, Narrow
-- /esoui/art/icons/housing_cwc_fur_informationwall001.dds Clockwork Sequence Spool, Triple
-- /esoui/art/icons/housing_orc_fur_wtgbookcase001.dds Orcish
-- /esoui/art/icons/housing_orc_fur_wtgbookshelf002.dds Orcish Bookshelf, Engraved
-- /esoui/art/icons/housing_red_fur_varbookcasecombined004.dds Redguard
-- /esoui/art/icons/housing_skr_fur_housingbookshelffancyfilled003.dds Solitude Backless
-- /esoui/art/icons/housing_skr_fur_housingarmoirfancyfilled002.dds Solitude Noble Filled
-- /esoui/art/icons/housing_skr_fur_housingbookshelffilled001.dds Solitude Rustic Filled
-- /esoui/art/icons/housing_skr_fur_housingvampirebookcasefilled001.dds Vampire Arched Filled
-- /esoui/art/icons/housing_skr_fur_housingvampirebookcasefilled002.dds Vampire Tall Filled
-- /esoui/art/icons/housing_bos_fur_shelf002.dds Wood Elf Leather
-- /esoui/art/icons/housing_ayl_duc_bookcaselarge002.dds Ayleid
-- /esoui/art/icons/housing_dwe_fur_bookshelfa001.dds Dwarven Full
-- /esoui/art/icons/housing_nib_fur_bookcasetall001.dds Imperial
-- /esoui/art/icons/housing_coh_inc_housingbookcase001.dds Mausoleum
-- /esoui/art/icons/housing_cra_fur_bookshelvescombo005.dds Nedic Bookcase, Filled
-- /esoui/art/icons/housing_sum_fur_highbookcase001.dds  Alinor Bookshelf, Polished
-- /esoui/art/icons/housing_els_fur_housingmedbookcase001.dds Elsweyr Bookshelf, Elegant Wooden Full
-- /esoui/art/icons/housing_els_run_housingbookshelves001.dds Elsweyr Bookshelf, Ancient Stone Full
-- /esoui/art/icons/housing_cld_duc_bookcaseprop002.dds Coldharbour Bookshelf, Black Laboratory
