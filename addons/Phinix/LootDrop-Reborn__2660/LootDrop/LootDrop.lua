------------------------------------------------
-- Loot Drop - "show me what I got" (Pawkette)
--
-- @author Pawkette ( pawkette.heals@gmail.com )
-- @author Phinix "Loot Drop Reborn" branch ( PC NA @IllusoryID )
-- @author @Masteroshi430 (profile texture additions & suggestions)
------------------------------------------------

--Localization-----------------------------------------------------------------
local L = LootDrop_Strings:GetLanguage()
--Local constants--------------------------------------------------------------
local ADDON_VERSION						= "4.65"
local ADDON_NAME						= "LootDrop"
local LootDrop_sDefRushmik          	= "|cD3B830Rushmik|r"
local LootDrop_sDefPawkette         	= "|cFF66CCPawkette|r"
local LootDrop_sDefESOclassic         	= "|cFFFFFFESO classic|r"
local LootDrop_sDefDefault          	= L.sDefDefault
local LootDrop_sListBoxValueNo      	= L.ValueNo
local LootDrop_sListBoxValueVendor   	= L.ValueVendor
local LootDrop_sListBoxValueTrade     	= L.ValueTrade
local LootDrop_sListBoxValueVaT     	= L.ValueVaT
local LootDrop_sListBoxGroupChar     	= L.GroupChar
local LootDrop_sListBoxGroupAcct     	= L.GroupAcct
local LootDrop_sListBoxGroupBoth     	= L.GroupBoth
local LootDrop_SoulGem = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName("|H1:item:33271:0:0:0:0:0:0:0:0:0:0:0:0:0:0:36:0:0:0:0:0|h|h"))
local LootDrop_EmptyGem = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName("|H1:item:33265:0:0:0:0:0:0:0:0:0:0:0:0:0:0:36:0:0:0:0:0|h|h"))
local LootDrop_Spacer = zo_iconTextFormatNoSpace("esoui/art/crafting/crafting_enchanting_glyphslot_empty.dds",15,15,"")
local LootDrop_Bag = zo_iconTextFormatNoSpace("esoui/art/mainmenu/menubar_inventory_up.dds",28,28,"")
local LootDrop_Account = zo_iconTextFormatNoSpace("esoui/art/inventory/inventory_currencytab_accountwide_up.dds",28,28,"")
--Libraries--------------------------------------------------------------------
local CBM = CALLBACK_MANAGER
local LAM2 = LibAddonMenu2
local LMP = LibMediaProvider
if ( not LAM2 ) then return end

--Icons------------------------------------------------------------------------
local LootDrop_sApIcon     				= "/lootdrop/textures/ap_up.dds"
local LootDrop_sVpIcon     				= "/esoui/art/campaign/gamepad/gp_campaign_menuicon_veterancy.dds"
local LootDrop_sXpIcon     				= "/lootdrop/textures/xp_up.dds"
local LootDrop_sRapportUpIcon			= "/lootdrop/textures/rapport_up.dds"
local LootDrop_sRapportDownIcon			= "/lootdrop/textures/rapport_down.dds"
local LootDrop_sSkillXpIcon				= "/lootdrop/textures/skill_up.dds"
local LootDrop_sTVIcon     				= "esoui/art/icons/icon_telvarstone.dds"
local LootDrop_sWVoucherIcon     		= "esoui/art/icons/icon_writvoucher.dds"
local LootDrop_sUndauntedIcon     		= "esoui/art/icons/undaunted_gold_key_01.dds"
local LootDrop_sTransmuteIcon     		= "esoui/art/currency/currency_seedcrystal_mipmap.dds"
local LootDrop_sETicketIcon     		= "esoui/art/currency/icon_eventticket_loot.dds"
local LootDrop_sAnvilXpIcon         	= "esoui/art/icons/servicemappins/servicepin_smithy.dds"
local LootDrop_sWoodXpIcon          	= "esoui/art/icons/servicemappins/servicepin_woodworking.dds"
local LootDrop_sAlchemyXpIcon       	= "esoui/art/icons/servicemappins/servicepin_alchemy.dds"
local LootDrop_sClothierXpIcon      	= "esoui/art/icons/servicemappins/servicepin_outfitter.dds"
local LootDrop_sEnchanterXpIcon     	= "esoui/art/icons/servicemappins/servicepin_enchanting.dds"
local LootDrop_sProvisioningXpIcon  	= "esoui/art/icons/servicemappins/servicepin_inn.dds"
local LootDrop_sJewelrycraftingXpIcon	= "esoui/art/icons/servicemappins/servicepin_jewelrycrafting.dds"
local LootDrop_sMagesGuildXpIcon    	= "esoui/art/icons/servicemappins/servicepin_magesguild.dds"
local LootDrop_sFighterGuildXpIcon  	= "esoui/art/icons/servicemappins/servicepin_fightersguild.dds"
local LootDrop_sThievesXpIcon       	= "/esoui/art/icons/servicemappins/servicepin_thievesguild.dds"
local LootDrop_sBrotherhoodXpIcon   	= "/esoui/art/icons/poi/poi_darkbrotherhood_complete.dds"
local LootDrop_sOthersGuildXpIcon   	= "esoui/art/icons/poi/poi_groupinstance_complete.dds"
local LootDrop_sBooksXpIcon         	= "esoui/art/mainmenu/menubar_journal_up.dds"
local LootDrop_sFenceXpIcon         	= "/esoui/art/icons/servicemappins/servicepin_fence.dds"
local LootDrop_sBgTexture           	= "/lootdrop/textures/default_bg.dds"
local LootDrop_sRarityTexture       	= "/lootdrop/textures/default_rarity.dds"
local LootDrop_sEndeavorIcon            = "/esoui/art/currency/currency_seals_of_endeavor_32.dds"
local LootDrop_sEndlessIcon				= "/esoui/art/currency/archivalfragments_mipmaps.dds"
local LootDrop_sFragmentsIcon			= "/esoui/art/currency/currency_imperial_trophy_key_mipmap.dds"
local LootDrop_sTomePointsIcon			= "/esoui/art/currency/u49_tt_tomepoints_mipmap.dds"
local LootDrop_sTomePointCachesIcon			= "/esoui/art/currency/u49_tt_cacheoftomepoints_mipmaps.dds"
local LootDrop_sTomeTokensIcon			= "/esoui/art/currency/u49_tt_premiumtomepoints_mipmap.dds"
local LootDrop_sTradeBarsIcon			= "/esoui/art/currency/u49_tt_tradebars_mipmap.dds"
local LootDrop_sColorScryingIcon		= "/esoui/art/icons/skilllinexp_scrying.dds"
local LootDrop_sColorExcavationIcon		= "/esoui/art/icons/skilllinexp_digging.dds"
local LootDrop_sColorAlchemyIcon		= "/esoui/art/icons/skilllinexp_alchemy.dds"
local LootDrop_sColorBlacksmithingIcon	= "/esoui/art/icons/skilllinexp_blacksmithing.dds"
local LootDrop_sColorClothingIcon		= "/esoui/art/icons/skilllinexp_clothier.dds"
local LootDrop_sColorEnchantingIcon		= "/esoui/art/icons/skilllinexp_enchanting.dds"
local LootDrop_sColorJewelcraftingIcon	= "/esoui/art/icons/skilllinexp_jewelrymaking.dds"
local LootDrop_sColorProvisioningIcon	= "/esoui/art/icons/skilllinexp_provisioner.dds"
local LootDrop_sColorWoodworkingIcon	= "/esoui/art/icons/skilllinexp_woodworking.dds"
local maxTabs = 15
local resetTab = 1

--Default Values for SavedVars-------------------------------------------------
local LootDrop_Defaults =
{
	lootdrop_lock				= true,
	lootdrop_x					= 0,
	lootdrop_y					= 0,
	lootdrop_tab				= 1,
	version						= 0,
	general = {
		hideHistory				= true,
		junkTrash				= false,
		hideMeters              = false,
		DbgHideGUI				= false,
		DbgHideChat				= false,
	},
	loot = {
		showLoot				= true,
		mailLoot				= true,
		nameLoot				= true,
		stackLoot				= true,
		traitLoot				= true,
		styleLoot				= false,
		collectLoot				= true,
		bookLoot				= true,
	},
	LWFilters = {
		LWFiltering				= false,
		FilterTools				= true,
		FilterSoulGems			= true,
		FilterTrash				= true,
		FilterTreasure			= true,
		FilterWGlyphs			= true,
		FilterAGlyphs			= true,
		FilterJGlyphs			= true,
		FilterGlyphQuality		= 0,
		FilterFurniture			= true,
		FilterRecall			= true,
		FilterSiege				= true,
		FilterAVARepair			= true,
		FilterTrophies			= true,
		FilterCollectibles		= true,
		FilterContainers		= true,
		FilterCContainers		= true,
		FilterCostumes			= true,
		FilterDisguise			= true,
		FilterCrownItems		= true,
		FilterCrownRepair		= true,
		FilterFood				= true,
		FilterDrink				= true,
		FilterPotion			= true,
		FilterPoison			= true,
		FilterPotionBase		= true,
		FilterPoisonBase		= true,
		FilterPlayerPotion		= true,
		FilterFish				= true,
		FilterBait				= true,
		FilterIngredients		= true,
		FilterIngQuality		= 0,
		FilterReagents			= true,
		FilterWTrait			= true,
		FilterATrait			= true,
		FilterFurnMats			= true,
		FilterCompMats			= true,
		FilterMotif				= true,
		FilterStyleMats			= true,
		FilterMasterWRits		= true,
		FilterRecipes			= true,
		FilterRecipeQuality		= 0,
		FilterERune				= true,
		FilterPRune				= true,
		FilterARune				= true,
		FilterARuneQ			= 1,
		FilterBSMats			= true,
		FilterBSRawMats			= true,
		FilterBSImprove			= true,
		FilterBSImproveQ		= 1,
		FilterClothMats			= true,
		FilterClothRawMats		= true,
		FilterClothImprove		= true,
		FilterClothImproveQ		= 1,
		FilterWoodMats			= true,
		FilterWoodRawMats		= true,
		FilterWoodImprove		= true,
		FilterWoodImproveQ		= 1,
		FilterJCMats			= true,
		FilterJCRawMats			= true,
		FilterJCTrait			= true,
		FilterJCRawTrait		= true,
		FilterJCImprove			= true,
		FilterJCRawImprove		= true,
		FilterJCImproveQ		= 1,
		FilterJCRImproveQ		= 1,
	},
	CLFilters = {
		CLFiltering				= false,
		FilterTools				= true,
		FilterSoulGems			= true,
		FilterTrash				= true,
		FilterTreasure			= true,
		FilterWGlyphs			= true,
		FilterAGlyphs			= true,
		FilterJGlyphs			= true,
		FilterGlyphQuality		= 0,
		FilterFurniture			= true,
		FilterRecall			= true,
		FilterSiege				= true,
		FilterAVARepair			= true,
		FilterTrophies			= true,
		FilterCollectibles		= true,
		FilterContainers		= true,
		FilterCContainers		= true,
		FilterCostumes			= true,
		FilterDisguise			= true,
		FilterCrownItems		= true,
		FilterCrownRepair		= true,
		FilterFood				= true,
		FilterDrink				= true,
		FilterPotion			= true,
		FilterPoison			= true,
		FilterPotionBase		= true,
		FilterPoisonBase		= true,
		FilterPlayerPotion		= true,
		FilterFish				= true,
		FilterBait				= true,
		FilterIngredients		= true,
		FilterIngQuality		= 0,
		FilterReagents			= true,
		FilterWTrait			= true,
		FilterATrait			= true,
		FilterFurnMats			= true,
		FilterCompMats			= true,
		FilterMotif				= true,
		FilterStyleMats			= true,
		FilterMasterWRits		= true,
		FilterRecipes			= true,
		FilterRecipeQuality		= 0,
		FilterERune				= true,
		FilterPRune				= true,
		FilterARune				= true,
		FilterARuneQ			= 1,
		FilterBSMats			= true,
		FilterBSRawMats			= true,
		FilterBSImprove			= true,
		FilterBSImproveQ		= 1,
		FilterClothMats			= true,
		FilterClothRawMats		= true,
		FilterClothImprove		= true,
		FilterClothImproveQ		= 1,
		FilterWoodMats			= true,
		FilterWoodRawMats		= true,
		FilterWoodImprove		= true,
		FilterWoodImproveQ		= 1,
		FilterJCMats			= true,
		FilterJCRawMats			= true,
		FilterJCTrait			= true,
		FilterJCRawTrait		= true,
		FilterJCImprove			= true,
		FilterJCRawImprove		= true,
		FilterJCImproveQ		= 1,
		FilterJCRImproveQ		= 1,
	},
	gold = {
		showGold				= true,
		showPrefix				= true,
		showName				= true,
		showNameFull			= true,
		showCName				= "",
		showColor				= true,
		nameColor				= {[1]=1,[2]=1,[3]=0,[4]=1},
		showBagGold				= true,
	},
	XP = {
		showXP					= true,
		showPrefix				= true,
		showName				= true,
		showNameFull			= true,
		showCName				= "",
		showColor				= true,
		nameColor				= {[1]=1,[2]=0.78,[3]=0,[4]=1},
		showProgress			= true,
		showProgFull			= false,
		showLevel				= true,
	},
	AP = {
		showAP					= true,
		showPrefix				= true,
		showName				= true,
		showNameFull			= true,
		showCName				= "",
		showColor				= true,
		nameColor				= {[1]=0,[2]=1,[3]=0,[4]=1},
		showProgress			= true,
		showProgFull			= false,
		showRPGain				= false,
		showLevel				= true,
	},
	VP = {
		showVP					= true,
		showPrefix				= true,
		showName				= true,
		showNameFull			= true,
		showCName				= "",
		showColor				= true,
		nameColor				= {[1]=0.8,[2]=0.6,[3]=0.2,[4]=1},
		showProgress			= true,
		showProgFull			= false,
		showVPGain				= false,
		showLevel				= true,
	},
	currency = {
		showTelvar				= true,
		telvarPrefix			= true,
		telvarMulti				= true,
		telvarName				= true,
		telvarBag				= true,
		telvarCName				= "",
		telvarSColor			= true,
		telvarColor				= {[1]=0,[2]=0.78,[3]=1,[4]=1},
		showVoucher				= true,
		voucherPrefix			= true,
		voucherName				= true,
		voucherBag				= true,
		voucherCName			= "",
		voucherSColor			= true,
		voucherColor			= {[1]=1,[2]=1,[3]=0.39,[4]=1},
		showUndaunted			= true,
		undauntedPrefix			= true,
		undauntedName			= true,
		undauntedAcct			= true,
		undauntedCName			= "",
		undauntedSColor			= true,
		undauntedColor			= {[1]=1,[2]=0,[3]=0.39,[4]=1},
		showTransmute			= true,
		transmutePrefix			= true,
		transmuteMax			= true,
		transmuteName			= true,
		transmuteAcct			= true,
		transmuteCName			= "",
		transmuteSColor			= true,
		transmuteColor			= {[1]=1,[2]=0.39,[3]=1,[4]=1},
		showEticket				= true,
		eticketPrefix			= true,
		eticketMax				= true,
		eticketName				= true,
		eticketAcct				= true,
		eticketCName			= "",
		eticketSColor			= true,
		eticketColor			= {[1]=1,[2]=0.78,[3]=0.39,[4]=1},
		showEndeavor			= true,
		endeavorPrefix			= true,
		endeavorName			= true,
		endeavorAcct			= true,
		endeavorCName			= "",
		endeavorSColor			= true,
		endeavorColor			= {[1]=1,[2]=0.78,[3]=0,[4]=1},
		showEndless				= true,
		endlessPrefix			= true,
		endlessName				= true,
		endlessAcct				= true,
		endlessCName			= "",
		endlessSColor			= true,
		endlessColor			= {[1]=1,[2]=0.78,[3]=0,[4]=1},
		showFragment			= true,
		fragmentPrefix			= true,
		fragmentName			= true,
		fragmentAcct			= true,
		fragmentCName			= "",
		fragmentSColor			= true,
		fragmentColor			= {[1]=0,[2]=0.5,[3]=1,[4]=1},
		showTomePoints			= true,
		TomePointsPrefix			= true,
		TomePointsName			= true,
		TomePointsAcct			= true,
		TomePointsCName			= "",
		TomePointsSColor			= true,
		TomePointsColor			= {[1]=0,[2]=0.5,[3]=1,[4]=1},
		showTomePointCaches			= true,
		TomePointCachesPrefix			= true,
		TomePointCachesName			= true,
		TomePointCachesAcct			= true,
		TomePointCachesCName			= "",
		TomePointCachesSColor			= true,
		TomePointCachesColor			= {[1]=0,[2]=0.5,[3]=1,[4]=1},
		showTomeTokens			= true,
		TomeTokensPrefix			= true,
		TomeTokensName			= true,
		TomeTokensAcct			= true,
		TomeTokensCName			= "",
		TomeTokensSColor			= true,
		TomeTokensColor			= {[1]=0,[2]=0.5,[3]=1,[4]=1},
		showTradeBars			= true,
		TradeBarsPrefix			= true,
		TradeBarsName			= true,
		TradeBarsAcct			= true,
		TradeBarsCName			= "",
		TradeBarsSColor			= true,
		TradeBarsColor			= {[1]=0,[2]=0.5,[3]=1,[4]=1},
	},
	skills = {
		showSkills				= true,
		skillNames				= true,
		oldGuildIcons			= false,
		oldSkillIcons			= false,
		skillLevel				= true,
		skillProgress			= true,
		skillProgFull			= false,
		skillPrefix				= true,
		skillSuffix				= true,
		showCraft				= true,
		showFence				= true,
		showBooks				= true,
		showGuilds				= true,
		showWeapon				= true,
		showArmor				= true,
		showWorld				= true,
		showAvA					= true,
		craftSColor				= true,
		craftColor				= {[1]=0,[2]=1,[3]=0.39,[4]=1},
		fenceSColor				= true,
		fenceColor				= {[1]=0.78,[2]=0.78,[3]=0.39,[4]=1},
		bookSColor				= true,
		bookColor				= {[1]=0,[2]=0.39,[3]=1,[4]=1},
		guildSColor				= true,
		guildColor				= {[1]=0,[2]=1,[3]=1,[4]=1},
		weaponSColor			= true,
		weaponColor				= {[1]=1,[2]=0.78,[3]=0.39,[4]=1},
		armorSColor				= true,
		armorColor				= {[1]=0.78,[2]=0.6,[3]=1,[4]=1},
		worldSColor				= true,
		worldColor				= {[1]=0,[2]=1,[3]=1,[4]=1},
		AvASColor				= true,
		AvAColor				= {[1]=1,[2]=0.39,[3]=0.39,[4]=1},
	},
	compXP = {
		showXP					= true,
		showPrefix				= true,
		showName				= true,
		showNameFull			= true,
		showCName				= "",
		showCFull				= false,
		showColor				= true,
		nameColor				= {[1]=1,[2]=0.78,[3]=0,[4]=1},
		showProgress			= true,
		showProgFull			= false,
		showLevel				= true,
	},
	rapport = {
		showRppt				= true,
		showCFull				= false,
		showPrefix				= true,
		showNameFull			= true,
		showCName				= "",
		showColor				= true,
		showProgress			= true,
		showProgFull			= false,
		showStatus				= true,
		nameColor				= {[1]=1,[2]=0.39,[3]=1,[4]=1},
	},
	achievements = {
		showAchieve				= false,
		showProgress			= true,
		showCompleted			= true,
		showPoints				= false,
		cachieveSColor			= true,
		cachieveColor			= {[1]=0,[2]=0.76,[3]=1,[4]=1},
		pachieveSColor			= true,
		pachieveColor			= {[1]=0,[2]=1,[3]=1,[4]=1},
	},
	chat = {
		DbgLogMine				= true,
		DbgLogMineQlty			= ITEM_QUALITY_MAGIC,
		DbgLogOthers			= true,
		DbgLogOthersQlty		= ITEM_QUALITY_ARCANE,
		DbgLogGname				= 2,
		DbgLogGold				= false,
		DbgLogXP				= false,
		DbgLogAP				= false,
		DbgLogVP				= false,
		DbgAWGain				= true,
		DbgAWFull				= true,
		DbgAWRank				= true,
		DbgVPGain				= true,
		DbgVPFull				= true,
		DbgVPRank				= true,
		DbgCAchievements		= true,
		DbgPAchievements		= true,
		DbgShowAchBrackets		= true,
		DbgLogTelvar			= false,
		DbgLogWritVoucher		= false,
		DbgLogUndauntedKey		= false,
		DbgLogTransmuteCrystal	= false,
		DbgLogEventTicket		= false,
		DbgLogEndeavor          = false,
		DbgLogEndless			= false,
		DbgLogFragments			= false,
		DbgLogTomePoints			= false,
    DbgLogTomePointCaches			= false,
    DbgLogTomeTokens			= false,
    DbgLogTradeBars			= false,
		DbgLogCXp				= false,
		DbgLogCRpt				= true,
		DbgLogCRptExt			= true,
		DbgLogCRptDesc			= false,
		DbgLogCraftXP			= false,
		DbgLogFenceXP			= false,
		DbgLogBookKnowledge		= false,
		DbgLogBookLoot			= true,
		DbgLogGuildRep			= false,
		DbgLogWeapon			= false,
		DbgLogArmor				= false,
		DbgLogWorld				= false,
		DbgLogAvA				= false,
		DbgLogTab = {
			DbgLogMine				= 1,
			DbgLogOthers			= 1,
			DbgLogGold				= 1,
			DbgLogXP				= 1,
			DbgLogAP				= 1,
			DbgLogVP				= 1,
			DbgCAchievements		= 1,
			DbgPAchievements		= 1,
			DbgLogTelvar			= 1,
			DbgLogWritVoucher		= 1,
			DbgLogUndauntedKey		= 1,
			DbgLogTransmuteCrystal	= 1,
			DbgLogEventTicket		= 1,
			DbgLogEndeavor          = 1,
			DbgLogEndless			= 1,
			DbgLogFragments			= 1,
			DbgLogTomePoints			= 1,
      DbgLogTomePointCaches			= 1,
      DbgLogTomeTokens			= 1,
      DbgLogTradeBars			= 1,
			DbgLogCXp				= 1,
			DbgLogCRpt				= 1,
			DbgLogCraftXP			= 1,
			DbgLogFenceXP			= 1,
			DbgLogBookKnowledge		= 1,
			DbgLogBookLoot			= 1,
			DbgLogGuildRep			= 1,
			DbgLogWeapon			= 1,
			DbgLogArmor				= 1,
			DbgLogWorld				= 1,
			DbgLogAvA				= 1,
		},
	},
	display = {
		dDuration				= 10,
		width					= 500, --220
		height					= 40, --45
		padding					= 5,
		maxstacks			    = 20,
		hOffset					= -60,
		fontSize				= 18,
		customFontE				= false,
		customFontG				= 'Univers 67',
		cFontOverride			= false,
		cFontOLoot				= false,
		cFontOGold				= false,
		cFontOXP				= false,
		cFontOAP				= false,
		cFontOVP				= false,
		cFontOTV				= false, -- Telvar Stones
		cFontOWV				= false, -- Writ Vouchers
		cFontOUK				= false, -- Undaunted Keys
		cFontOTC				= false, -- Transmute Crystals
		cFontOET				= false, -- Event Tickets
		cFontOES				= false, -- Seals of Endeavor
		cFontOAF				= false, -- Archival Fortunes
		cFontOIF				= false, -- Imperial Fragments
		cFontOTP				= false, -- Tome points
		cFontOSkill				= false,
		cFontOComp				= false,
		cFontOAchieve			= false,
		cFontLoot				= 'Univers 67',
		cFontGold				= 'Univers 67',
		cFontXP					= 'Univers 67',
		cFontAP					= 'Univers 67',
		cFontVP					= 'Univers 67',
		cFontTV					= 'Univers 67', -- Telvar Stones
		cFontWV					= 'Univers 67', -- Writ Vouchers
		cFontUK					= 'Univers 67', -- Undaunted Keys
		cFontTC					= 'Univers 67', -- Transmute Crystals
		cFontET					= 'Univers 67', -- Event Tickets
		cFontES					= 'Univers 67', -- Seals of Endeavor
		cFontAF					= 'Univers 67', -- Archival Fortunes
		cFontIF					= 'Univers 67', -- Imperial Fragments
		cFontTP					= 'Univers 67', -- Tome Points
		cFontSkill				= 'Univers 67',
		cFontComp				= 'Univers 67', -- Companion XP
		cFontAchieve			= 'Univers 67', -- Achievement Font
		showHidden				= true,
		moveUp					= true,
		rarity					= false,
		sListStyle				= LootDrop_sDefESOclassic,
		customBG				= "DEFAULT",
		DbgLogTime				= false,
		DbgLogItemStyle			= false,
		DbgLogItemTrait			= true,
		DbgLogItemValue			= true,
		DbgLogTag				= false,
	},
	value = {
		lootValue				= 3,
		stackVal				= true,
		noData					= false,
		noDataVal				= false,
		valueSep				= false,
		goldSuff				= true,
		cDelim					= true,
		cTrunc					= false,
		cDot					= false,
	},
}
--Selection table for preview mode---------------------------------------------
local opTable = {
	[1] = L.SelectPreview,
	[2] = tostring(1)..": "..L.Loot,
	[3] = tostring(2)..": "..L.Gold,
	[4] = tostring(3)..": "..L.Experience,
	[5] = tostring(4)..": "..L.AlliancePoints,
	[6] = tostring(5)..": "..L.VeterancyPoints,
	[7] = tostring(6)..": "..L.TelvarStones,
	[8] = tostring(7)..": "..L.WritVouchers,
	[9] = tostring(8)..": "..L.UndauntedKeys,
	[10] = tostring(9)..": "..L.TransmuteCrystals,
	[11] = tostring(10)..": "..L.EventTickets,
	[12] = tostring(11)..": "..L.Endeavor,
	[13] = tostring(12)..": "..L.Endless,
	[14] = tostring(13)..": "..L.Fragment,
	[15] = tostring(14)..": "..L.TomePoints,
	[16] = tostring(15)..": "..L.TomePointCaches,
	[17] = tostring(16)..": "..L.TomeTokens,
	[18] = tostring(17)..": "..L.TradeBars,
	[19] = tostring(18)..": "..L.CompanionXP,
	[20] = tostring(19)..": "..L.CompanionRapport,
	[21] = tostring(20)..": "..L.SkillDisplay,
	[22] = tostring(21)..": "..L.Achievements,
	[23] = tostring(22)..": "..L.Everything,

}
--Filter table pre-built for speed---------------------------------------------
local filterTable = {}
local specialFilters = {}
--Local Functions--------------------------------------------------------------
local tinsert           = table.insert
local tremove           = table.remove
local zo_strsplit       = zo_strsplit
local ZO_ColorDef       = ZO_ColorDef
local zo_parselink      = ZO_LinkHandler_ParseLink
local zo_min            = zo_min
local CBM               = CALLBACK_MANAGER
local WM				= GetWindowManager()
local _
--LootDrop Objects defined in other files--------------------------------------
local LootDropFade      = LootDropFade
local LootDropSlide     = LootDropSlide
local LootDropPop       = LootDropPop
local LootDropPanel
local LootDropPreview
-------------------------------------------------------------------------------
-- Local variables for tracking

-------------------------------------------------------------------------------
--- Flags for updating UI aspects
local DirtyFlags =
{
	LAYOUT = 1 -- we've added or removed a droppable
}

--Initialize main objects------------------------------------------------------
local LootDropPool					= ZO_Object:Subclass()
local LootDropConfig				= ZO_Object:Subclass()
local LootDroppable					= ZO_Object:Subclass()
local LootDrop						= LootDropPool:Subclass()
--Addon status tracking variables----------------------------------------------
local IsChecking		= false -- OnUpdate override
local IsPreviewPanel	= 0 -- avoid saving position when moving to show in addon settings
local previewMode		= 1 -- enable preview and set type of loot to show
local lastCompanion		= 0 -- track the last companion summoned to avoid stacking gains incorrectly
--LootDropPool-----------------------------------------------------------------
function LootDropPool:New()
	return ZO_Object.New( self )
end
-------------------------------------------------------------------------------
function LootDropPool:Initialize( create, reset )
	self._create    = create
	self._reset     = reset
	self._active    = {}
	self._controlId = 0

	CBM:RegisterCallback( LootDropConfig.EVENT_CHANGE_MAXSTACKS, function() self:ChangeMaxStacks() end )
end
-------------------------------------------------------------------------------
function LootDropPool:GetNextId()
	self._controlId = self._controlId + 1
	return self._controlId
end
-------------------------------------------------------------------------------
function LootDropPool:Active()
	return self._active
end
-------------------------------------------------------------------------------
function LootDropPool:ChangeMaxStacks()
	self:ReleaseAll() -- prevent animation getting out of sync by resetting active loot pool when stack size is changed (Phinix)
end
-------------------------------------------------------------------------------
function LootDropPool:Acquire()
	local result = self._create()
	tinsert( self._active, result )
	return result, #self._active
end
-------------------------------------------------------------------------------
function LootDropPool:Get(text)
	if not text or text == "" then return nil end
	if not self._active or #self._active == 0 then return nil end

	local oldEntry = nil
	local v = 1

	while( v <= #self._active ) do
		oldEntry = self._active[ v ]
		local oldText = oldEntry.name
		if oldText == text then
			return oldEntry, v, true
		end
		v = v + 1
	end
	return nil
end
-------------------------------------------------------------------------------
function LootDropPool:Release(object)
	local i = 1
	IsChecking = true
	while( i <= #self._active ) do
		if ( self._active[ i ] == object ) then
			tremove( self._active, i ) -- remove from active before reset to avoid possible processing empty loot item next OnUpdate() (Phinix)
			self._reset( object, object.name, i )
			object = nil
			break
		else
			i = i + 1 
		end
	end
	IsChecking = false
end
-------------------------------------------------------------------------------
function LootDropPool:ReleaseAll()
	IsChecking = true
	for i = 1, #self._active do
		local object = self._active[ i ]
		if object then
			self._reset( object, object.name, i )
			object = nil
			tremove( self._active, i )
		end
	end
	IsChecking = false
end
-------------------------------------------------------------------------------

--LootDropConfig Constants-----------------------------------------------------
LootDropConfig.EVENT_TOGGLE_LOOT			= 'LOOTDROP_TOGGLE_LOOT'
LootDropConfig.EVENT_TOGGLE_MAIL_LOOT		= 'LOOTDROP_TOGGLE_MAIL_LOOT'
LootDropConfig.EVENT_TOGGLE_GROUP_NAME		= 'LOOTDROP_TOGGLE_GROUP_NAME'
LootDropConfig.EVENT_TOGGLE_COIN			= 'LOOTDROP_TOGGLE_COIN'
LootDropConfig.EVENT_TOGGLE_XP				= 'LOOTDROP_TOGGLE_XP'
LootDropConfig.EVENT_TOGGLE_AP				= 'LOOTDROP_TOGGLE_AP'
LootDropConfig.EVENT_TOGGLE_VP				= 'LOOTDROP_TOGGLE_VP'
LootDropConfig.EVENT_TOGGLE_TV				= 'LOOTDROP_TOGGLE_TV'
LootDropConfig.EVENT_TOGGLE_WVOUCHER		= 'LOOTDROP_TOGGLE_WVOUCHER'
LootDropConfig.EVENT_TOGGLE_ACCOUNT			= 'LOOTDROP_TOGGLE_ACCOUNT'
LootDropConfig.EVENT_TOGGLE_JUNK			= 'LOOTDROP_TOGGLE_JUNK'
LootDropConfig.EVENT_TOGGLE_DEFAULT			= 'LOOTDROP_TOGGLE_DEFAULT'
LootDropConfig.EVENT_TOGGLE_HIDEGUI			= 'LOOTDROP_TOGGLE_HIDEGUI'
LootDropConfig.EVENT_TOGGLE_HIDECHAT		= 'LOOTDROP_TOGGLE_HIDECHAT'
LootDropConfig.EVENT_TOGGLE_COMPANION_XP	= 'LOOTDROP_TOGGLE_COMPANION_XP'
LootDropConfig.EVENT_TOGGLE_COMPANION_RP	= 'LOOTDROP_TOGGLE_COMPANION_RP'
LootDropConfig.EVENT_TOGGLE_ACHIEVEMENTS	= 'LOOTDROP_TOGGLE_ACHIEVEMENTS'
LootDropConfig.EVENT_TOGGLE_SKILL_XP		= 'LOOTDROP_TOGGLE_SKILL_XP'
LootDropConfig.EVENT_TOGGLE_BOOK_LOOT		= 'LOOTDROP_TOGGLE_BOOK_LOOT'
LootDropConfig.EVENT_TOGGLE_STYLE			= 'LOOTDROP_TOGGLE_STYLE'
LootDropConfig.EVENT_TOGGLE_LOCK			= 'LOOTDROP_TOGGLE_LOCK'
LootDropConfig.EVENT_TOGGLE_RARITY			= 'LOOTDROP_TOGGLE_RARITY'
LootDropConfig.EVENT_TOGGLE_MOVEUP			= 'LOOTDROP_TOGGLE_MOVEUP'
LootDropConfig.EVENT_CHANGE_DIMENSIONS		= 'LOOTDROP_CHANGE_DIMENSIONS'
LootDropConfig.EVENT_RESET_PREVIEW			= 'LOOTDROP_RESET_PREVIEW'
LootDropConfig.EVENT_CHANGE_MAXSTACKS		= 'LOOTDROP_CHANGE_MAXSTACKS'
LootDropConfig.EVENT_SHOW_PREVIEW			= 'LOOTDROP_SHOW_PREVIEW'
LootDropConfig.EVENT_CANCEL_PREVIEW			= 'LOOTDROP_CANCEL_PREVIEW'

-------------------------------------------------------------------------------
function LootDropConfig:New( ... )
	local result = ZO_Object.New( self )
	result:Initialize( ... )
	return result
end
-------------------------------------------------------------------------------
function LootDropConfig:Initialize( db )
	self.db = db

	local panelData = {
		type = "panel",
		name = ADDON_NAME,
		displayName = L.AddonName,
		author = "|c66ccffPhinix|r, |cFF66CCPawkette|r, |cAA0000Flagrick|r, Ayantir",
		version = ADDON_VERSION,
		slashCommand = "/lootdrop",
		registerForRefresh = true,
		registerForDefaults = true,
		website = "https://www.esoui.com/downloads/info2660-LootDropReborn.html"
	}

	LootDropPanel = LAM2:RegisterAddonPanel(ADDON_NAME, panelData)

	--local variables
	local chatTabs = {}
	local qualityChoices = {}
	local reverseQualityChoices = {}
	local qualityChoices0 = {}
	local reverseQualityChoices0 = {}
	for i = 1, maxTabs do chatTabs[i] = i end
	for i = 0, ITEM_QUALITY_LEGENDARY do
		local color = GetItemQualityColor(i)
		local qualName = color:Colorize(GetString("SI_ITEMQUALITY", i))
		qualityChoices[i] = qualName
		qualityChoices0[i+1] = qualName
		reverseQualityChoices[qualName] = i
		reverseQualityChoices0[qualName] = i+1
	end

	local optionsTable = {
		------------GENERAL OPTIONS--------------
		{
			type = 'submenu',
			name = L.DisplayOptions,
			tooltip = '',
			controls = {
				[1] = {
						type = "checkbox",
						name = L.LootHistory,
						tooltip = L.LootHistoryTip,
						getFunc = function() return self.db.general.hideHistory end,
						setFunc = function(value) self:ToggleLootHistory(value) end,
						width = "full",
						},
				[2] = {
						type = "checkbox",
						name = L.Junk,
						tooltip = L.JunkTip,
						getFunc = function() return self.db.general.junkTrash end,
						setFunc = function(value) self:ToggleJunk(value) end,
						width = "full",
						default = LootDrop_Defaults.general.junkTrash,
						},
				[3] = {
						type = "checkbox",
						name = L.HideMeters,
						tooltip = L.HideMetersTip,
						getFunc = function() return self.db.general.hideMeters end,
						setFunc = function(value) self:ToggleHideMeters(value) end,
						width = "full",
						default = LootDrop_Defaults.general.hideMeters,
						},
				[4] = {
						type = "checkbox",
						name = L.HideGUI,
						tooltip = L.HideGUITip,
						getFunc = function() return self.db.general.DbgHideGUI end,
						setFunc = function(value) self:ToggleHideGUI(value) end,
						width = "full",
						default = LootDrop_Defaults.general.DbgHideGUI,
						reference = "DbgGeneral_HideGUI",
						},
				[5] = {
						type = "checkbox",
						name = L.HideChatOutput,
						tooltip = L.HideChatOutputTip,
						getFunc = function() return self.db.general.DbgHideChat end,
						setFunc = function(value) self:ToggleHideChat(value) end,
						width = "full",
						default = LootDrop_Defaults.general.DbgHideChat,
						reference = "DbgGeneral_HideChat",
						},
				[6] = {
						type = "dropdown",
						name = L.GChatTabSelect.." \("..L.CurrentTab.."|cFFFF00"..tostring(self.db.lootdrop_tab).."|r\)",
						tooltip = L.GChatTabSelectTip,
						choices = chatTabs,
						getFunc = function() return resetTab end,
						setFunc = function(choice) resetTab = choice end,
						width = "full",
						default = chatTabs[1],
						reference = "LootDropChatTabDrop",
						},
				[7] = {
						type = "button",
						name = L.GChatTabButton,
						tooltip = L.GChatTabSelectTip,
						func = function()
							self.db.chat.DbgLogTab.DbgLogMine				= resetTab
							self.db.chat.DbgLogTab.DbgLogOthers				= resetTab
							self.db.chat.DbgLogTab.DbgLogGold				= resetTab
							self.db.chat.DbgLogTab.DbgLogXP					= resetTab
							self.db.chat.DbgLogTab.DbgLogAP					= resetTab
							self.db.chat.DbgLogTab.DbgLogVP					= resetTab
							self.db.chat.DbgLogTab.DbgCAchievements			= resetTab
							self.db.chat.DbgLogTab.DbgPAchievements			= resetTab
							self.db.chat.DbgLogTab.DbgLogTelvar				= resetTab
							self.db.chat.DbgLogTab.DbgLogWritVoucher		= resetTab
							self.db.chat.DbgLogTab.DbgLogUndauntedKey		= resetTab
							self.db.chat.DbgLogTab.DbgLogTransmuteCrystal	= resetTab
							self.db.chat.DbgLogTab.DbgLogEventTicket		= resetTab
							self.db.chat.DbgLogTab.DbgLogEndeavor			= resetTab
							self.db.chat.DbgLogTab.DbgLogEndless			= resetTab
							self.db.chat.DbgLogTab.DbgLogFragments			= resetTab
							self.db.chat.DbgLogTab.DbgLogTomePoints			= resetTab
              self.db.chat.DbgLogTab.DbgLogTomePointCaches			= resetTab
              self.db.chat.DbgLogTab.DbgLogTomeTokens			= resetTab
              self.db.chat.DbgLogTab.DbgLogTradeBars			= resetTab
							self.db.chat.DbgLogTab.DbgLogCXp				= resetTab
							self.db.chat.DbgLogTab.DbgLogCRpt				= resetTab
							self.db.chat.DbgLogTab.DbgLogCraftXP			= resetTab
							self.db.chat.DbgLogTab.DbgLogFenceXP			= resetTab
							self.db.chat.DbgLogTab.DbgLogBookKnowledge		= resetTab
							self.db.chat.DbgLogTab.DbgLogBookLoot			= resetTab
							self.db.chat.DbgLogTab.DbgLogGuildRep			= resetTab
							self.db.chat.DbgLogTab.DbgLogWeapon				= resetTab
							self.db.chat.DbgLogTab.DbgLogArmor				= resetTab
							self.db.chat.DbgLogTab.DbgLogWorld				= resetTab
							self.db.chat.DbgLogTab.DbgLogAvA				= resetTab
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogMine)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogOthers)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogGold)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogXP)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogAP)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogVP)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgCAchievements)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgPAchievements)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogTelvar)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogWritVoucher)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogUndauntedKey)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogTransmuteCrystal)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogEventTicket)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogEndeavor)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogEndless)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogFragments)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogTomePoints)
              LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogTomePointCaches)
              LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogTomeTokens)
              LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogTradeBars)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogCXp)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogCRpt)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogCraftXP)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogFenceXP)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogBookKnowledge)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogBookLoot)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogGuildRep)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogWeapon)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogArmor)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogWorld)
							LAM2.util.RequestRefreshIfNeeded(DbgLogTab_DbgLogAvA)
							self.db.lootdrop_tab = resetTab
							LootDropChatTabDrop.label:SetText(L.GChatTabSelect.." \("..L.CurrentTab.."|cFFFF00"..tostring(self.db.lootdrop_tab).."|r\)")
						end,
						width = "full",
					},
				},
			},
		------------LOOT WINDOW OPTIONS--------------
		{
			type = 'submenu',
			name = L.GeneralHeader,
			tooltip = '',
			controls = {
			[1] = { -- Header
					type = 'description',
					text = L.LootSelect,
					},
			[2] = { -- Loot Options
				type = 'submenu',
				name = L.Loot,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.Loot,
							tooltip = L.LootTip,
							getFunc = function() return self.db.loot.showLoot end,
							setFunc = function(value) self:ToggleLoot(value) end,
							width = "full",
							default = LootDrop_Defaults.loot.showLoot
							},
					[2] = {
							type = "checkbox",
							name = L.MailLoot,
							tooltip = L.MailLootTip,
							getFunc = function() return self.db.loot.mailLoot end,
							setFunc = function(value) self:ToggleMailLoot(value) end,
							width = "full",
							disabled = function() return not self.db.loot.showLoot end,
							default = LootDrop_Defaults.loot.mailLoot
							},
					[3] = {
							type = "checkbox",
							name = L.NameLoot,
							tooltip = L.NameLootTip,
							getFunc = function() return self.db.loot.nameLoot end,
							setFunc = function(value) self.db.loot.nameLoot = value self:ToggleLootOptions() end,
							width = "full",
							disabled = function() return not self.db.loot.showLoot end,
							default = LootDrop_Defaults.loot.nameLoot
							},
					[4] = {
							type = "checkbox",
							name = L.InventoryStacks,
							tooltip = L.InventoryStacksTip,
							getFunc = function() return self.db.loot.stackLoot end,
							setFunc = function(value) self.db.loot.stackLoot = value self:ToggleLootOptions() end,
							width = "full",
							disabled = function() return not self.db.loot.showLoot end,
							default = LootDrop_Defaults.loot.stackLoot
							},
					[5] = {
							type = "checkbox",
							name = L.UncollectedSet,
							tooltip = L.UncollectedSetTip,
							getFunc = function() return self.db.loot.collectLoot end,
							setFunc = function(value) self.db.loot.collectLoot = value self:ToggleLootOptions() end,
							width = "full",
							disabled = function() return not self.db.loot.showLoot end,
							default = LootDrop_Defaults.loot.collectLoot
							},
					[6] = {
							type = "checkbox",
							name = L.TraitLoot,
							tooltip = L.TraitLootTip,
							getFunc = function() return self.db.loot.traitLoot end,
							setFunc = function(value) self.db.loot.traitLoot = value self:ToggleLootOptions() end,
							width = "full",
							disabled = function() return not self.db.loot.showLoot end,
							default = LootDrop_Defaults.loot.traitLoot
							},
					[7] = {
							type = "checkbox",
							name = L.StyleLoot,
							tooltip = L.StyleLootTip,
							getFunc = function() return self.db.loot.styleLoot end,
							setFunc = function(value) self.db.loot.styleLoot = value self:ToggleLootOptions() end,
							width = "full",
							disabled = function() return not self.db.loot.showLoot end,
							default = LootDrop_Defaults.loot.styleLoot
							},
					[8] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOLoot end,
							setFunc = function(v) self.db.display.cFontOLoot = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOLoot
							},
					[9] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontLoot end,
							setFunc = function(v) self.db.display.cFontLoot = v end,
							disabled = function() return not self.db.display.cFontOLoot end,
							scrollable = 7,
							},
						},
					},
			[3] = { -- Gold Options
				type = 'submenu',
				name = L.Gold,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.Gold,
							tooltip = L.GoldTip,
							getFunc = function() return self.db.gold.showGold end,
							setFunc = function(value) self:ToggleCoin(value) end,
							width = "full",
							default = LootDrop_Defaults.gold.showGold
							},
					[2] = {
							type = "checkbox",
							name = L.ShowPrefix,
							tooltip = L.ShowPrefixTip,
							getFunc = function() return self.db.gold.showPrefix end,
							setFunc = function(value) self.db.gold.showPrefix = value end,
							width = "half",
							disabled = function() return not self.db.gold.showGold end,
							default = LootDrop_Defaults.gold.showPrefix
							},
					[3] = {
							type = "checkbox",
							name = L.ShowBagGold,
							tooltip = L.ShowBagGoldTip,
							getFunc = function() return self.db.gold.showBagGold end,
							setFunc = function(value) self.db.gold.showBagGold = value end,
							width = "half",
							disabled = function() return not self.db.gold.showGold end,
							default = LootDrop_Defaults.gold.showBagGold
							},
					[4] = {
							type = "checkbox",
							name = L.ShowSuffix,
							tooltip = L.ShowSuffixTip,
							getFunc = function() return self.db.gold.showName end,
							setFunc = function(value) self.db.gold.showName = value end,
							width = "half",
							disabled = function() return not self.db.gold.showGold end,
							default = LootDrop_Defaults.gold.showName
							},
					[5] = {
							type = "checkbox",
							name = L.ShowFullName,
							tooltip = L.ShowFullNameTip,
							getFunc = function() return self.db.gold.showNameFull end,
							setFunc = function(value) self.db.gold.showNameFull = value end,
							width = "half",
							disabled = function() return (not self.db.gold.showGold) or (not self.db.gold.showName) end,
							default = LootDrop_Defaults.gold.showNameFull
							},
					[6] = {
							type = 'editbox',
							name = L.CustomName,
							tooltip = L.CustomNameTip,
							getFunc = function() return self.db.gold.showCName end,
							setFunc = function(value) self.db.gold.showCName = value end,
							isMultiline = false,
							width = "half",
							disabled = function() return (not self.db.gold.showGold) or (not self.db.gold.showName) or (not self.db.gold.showNameFull) end,
							default = LootDrop_Defaults.gold.showCName
							},
					[7] = {
							type = "custom",
							width = "half",
							},
					[8] = {
							type = "checkbox",
							name = L.ShowColor,
							tooltip = L.ShowColorTip,
							getFunc = function() return self.db.gold.showColor end,
							setFunc = function(value) self.db.gold.showColor = value end,
							width = "half",
							disabled = function() return (not self.db.gold.showGold) or (not self.db.gold.showName) end,
							default = LootDrop_Defaults.gold.showColor
							},
					[9] = {
							type = 'colorpicker',
							name = L.NameColor,
							getFunc = function() return unpack(self.db.gold.nameColor) end,
							setFunc = function(r, g, b, a)
								self.db.gold.nameColor[1] = r
								self.db.gold.nameColor[2] = g
								self.db.gold.nameColor[3] = b
								self.db.gold.nameColor[4] = a
							end,
							width = "half",
							disabled = function() return (not self.db.gold.showGold) or (not self.db.gold.showName) or (not self.db.gold.showColor) end,
							default = LootDrop_Defaults.gold.nameColor
							},
					[10] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOGold end,
							setFunc = function(v) self.db.display.cFontOGold = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOGold
							},
					[11] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontGold end,
							setFunc = function(v) self.db.display.cFontGold = v end,
							disabled = function() return not self.db.display.cFontOGold end,
							scrollable = 7,
							},
						},
					},
			[4] = { -- XP Options
				type = 'submenu',
				name = L.Experience,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.Experience,
							tooltip = L.ExperienceTip,
							getFunc = function() return self.db.XP.showXP end,
							setFunc = function(value) self:ToggleXP(value) end,
							width = "full",
							default = LootDrop_Defaults.XP.showXP
							},
					[2] = {
							type = "checkbox",
							name = L.ShowPrefix,
							tooltip = L.ShowPrefixTip,
							getFunc = function() return self.db.XP.showPrefix end,
							setFunc = function(value) self.db.XP.showPrefix = value end,
							width = "half",
							disabled = function() return not self.db.XP.showXP end,
							default = LootDrop_Defaults.XP.showPrefix
							},
					[3] = {
							type = "checkbox",
							name = L.ShowXPLevel,
							tooltip = L.ShowXPLevelTip,
							getFunc = function() return self.db.XP.showLevel end,
							setFunc = function(value) self.db.XP.showLevel = value end,
							width = "half",
							disabled = function() return not self.db.XP.showXP end,
							default = LootDrop_Defaults.XP.showLevel
							},
					[4] = {
							type = "checkbox",
							name = L.ShowXPProgress,
							tooltip = L.ShowXPProgressTip,
							getFunc = function() return self.db.XP.showProgress end,
							setFunc = function(value) self.db.XP.showProgress = value end,
							width = "half",
							disabled = function() return not self.db.XP.showXP end,
							default = LootDrop_Defaults.XP.showProgress
							},
					[5] = {
							type = "checkbox",
							name = L.ShowXPProgFull,
							tooltip = L.ShowXPProgFullTip,
							getFunc = function() return self.db.XP.showProgFull end,
							setFunc = function(value) self.db.XP.showProgFull = value end,
							width = "half",
							disabled = function() return (not self.db.XP.showXP) or (not self.db.XP.showProgress) end,
							default = LootDrop_Defaults.XP.showProgFull
							},
					[6] = {
							type = "checkbox",
							name = L.ShowSuffix,
							tooltip = L.ShowSuffixTip,
							getFunc = function() return self.db.XP.showName end,
							setFunc = function(value) self.db.XP.showName = value end,
							width = "half",
							disabled = function() return not self.db.XP.showXP end,
							default = LootDrop_Defaults.XP.showName
							},
					[7] = {
							type = "checkbox",
							name = L.ShowFullName,
							tooltip = L.ShowFullNameTip,
							getFunc = function() return self.db.XP.showNameFull end,
							setFunc = function(value) self.db.XP.showNameFull = value end,
							width = "half",
							disabled = function() return (not self.db.XP.showXP) or (not self.db.XP.showName) end,
							default = LootDrop_Defaults.XP.showNameFull
							},
					[8] = {
							type = 'editbox',
							name = L.CustomName,
							tooltip = L.CustomNameTip,
							getFunc = function() return self.db.XP.showCName end,
							setFunc = function(value) self.db.XP.showCName = value end,
							isMultiline = false,
							width = "half",
							disabled = function() return (not self.db.XP.showXP) or (not self.db.XP.showName) or (not self.db.XP.showNameFull) end,
							default = LootDrop_Defaults.XP.showCName
							},
					[9] = {
							type = "custom",
							width = "half",
							},
					[10] = {
							type = "checkbox",
							name = L.ShowColor,
							tooltip = L.ShowColorTip,
							getFunc = function() return self.db.XP.showColor end,
							setFunc = function(value) self.db.XP.showColor = value end,
							width = "half",
							disabled = function() return (not self.db.XP.showXP) or (not self.db.XP.showName) end,
							default = LootDrop_Defaults.XP.showColor
							},
					[11] = {
							type = 'colorpicker',
							name = L.NameColor,
							getFunc = function() return unpack(self.db.XP.nameColor) end,
							setFunc = function(r, g, b, a)
								self.db.XP.nameColor[1] = r
								self.db.XP.nameColor[2] = g
								self.db.XP.nameColor[3] = b
								self.db.XP.nameColor[4] = a
							end,
							width = "half",
							disabled = function() return (not self.db.XP.showXP) or (not self.db.XP.showName) or (not self.db.XP.showColor) end,
							default = LootDrop_Defaults.XP.nameColor
							},
					[12] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOXP end,
							setFunc = function(v) self.db.display.cFontOXP = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOXP
							},
					[13] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontXP end,
							setFunc = function(v) self.db.display.cFontXP = v end,
							disabled = function() return not self.db.display.cFontOXP end,
							scrollable = 7,
							},
						},
					},
			[5] = { -- Alliance Points
				type = 'submenu',
				name = L.AlliancePoints,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.AlliancePoints,
							tooltip = L.AlliancePointsTip,
							getFunc = function() return self.db.AP.showAP end,
							setFunc = function(value) self:ToggleAP(value) end,
							width = "full",
							default = LootDrop_Defaults.AP.showAP
							},
					[2] = {
							type = "checkbox",
							name = L.ShowPrefix,
							tooltip = L.ShowPrefixTip,
							getFunc = function() return self.db.AP.showPrefix end,
							setFunc = function(value) self.db.AP.showPrefix = value end,
							width = "half",
							disabled = function() return not self.db.AP.showAP end,
							default = LootDrop_Defaults.AP.showPrefix
							},
					[3] = {
							type = "checkbox",
							name = L.ShowAPLevel,
							tooltip = L.ShowAPLevelTip,
							getFunc = function() return self.db.AP.showLevel end,
							setFunc = function(value) self.db.AP.showLevel = value end,
							width = "half",
							disabled = function() return not self.db.AP.showAP end,
							default = LootDrop_Defaults.AP.showLevel
							},
					[4] = {
							type = "checkbox",
							name = L.ShowAPProgress,
							tooltip = L.ShowAPProgressTip,
							getFunc = function() return self.db.AP.showProgress end,
							setFunc = function(value) self.db.AP.showProgress = value end,
							width = "half",
							disabled = function() return not self.db.AP.showAP end,
							default = LootDrop_Defaults.AP.showProgress
							},
					[5] = {
							type = "checkbox",
							name = L.ShowXPProgFull,
							tooltip = L.ShowAPProgFullTip,
							getFunc = function() return self.db.AP.showProgFull end,
							setFunc = function(value) self.db.AP.showProgFull = value end,
							width = "half",
							disabled = function() return (not self.db.AP.showAP) or (not self.db.AP.showProgress) end,
							default = LootDrop_Defaults.AP.showProgFull
							},
					[6] = {
							type = "checkbox",
							name = L.ShowRPGain,
							tooltip = L.ShowRPGainTip,
							getFunc = function() return self.db.AP.showRPGain end,
							setFunc = function(value) self.db.AP.showRPGain = value end,
							width = "half",
							disabled = function() return not self.db.AP.showAP end,
							default = LootDrop_Defaults.AP.showRPGain
							},
					[7] = {
							type = "checkbox",
							name = L.ShowSuffix,
							tooltip = L.ShowSuffixTip,
							getFunc = function() return self.db.AP.showName end,
							setFunc = function(value) self.db.AP.showName = value end,
							width = "half",
							disabled = function() return not self.db.AP.showAP end,
							default = LootDrop_Defaults.AP.showName
							},
					[8] = {
							type = "checkbox",
							name = L.ShowFullName,
							tooltip = L.ShowFullNameTip,
							getFunc = function() return self.db.AP.showNameFull end,
							setFunc = function(value) self.db.AP.showNameFull = value end,
							width = "half",
							disabled = function() return (not self.db.AP.showAP) or (not self.db.AP.showName) end,
							default = LootDrop_Defaults.AP.showNameFull
							},
					[9] = {
							type = 'editbox',
							name = L.CustomName,
							tooltip = L.CustomNameTip,
							getFunc = function() return self.db.AP.showCName end,
							setFunc = function(value) self.db.AP.showCName = value end,
							isMultiline = false,
							width = "half",
							disabled = function() return (not self.db.AP.showAP) or (not self.db.AP.showName) or (not self.db.AP.showNameFull) end,
							default = LootDrop_Defaults.AP.showCName
							},
					[10] = {
							type = "checkbox",
							name = L.ShowColor,
							tooltip = L.ShowColorTip,
							getFunc = function() return self.db.AP.showColor end,
							setFunc = function(value) self.db.AP.showColor = value end,
							width = "half",
							disabled = function() return (not self.db.AP.showAP) or (not self.db.AP.showName) end,
							default = LootDrop_Defaults.AP.showColor
							},
					[11] = {
							type = 'colorpicker',
							name = L.NameColor,
							getFunc = function() return unpack(self.db.AP.nameColor) end,
							setFunc = function(r, g, b, a)
								self.db.AP.nameColor[1] = r
								self.db.AP.nameColor[2] = g
								self.db.AP.nameColor[3] = b
								self.db.AP.nameColor[4] = a
							end,
							width = "half",
							disabled = function() return (not self.db.AP.showAP) or (not self.db.AP.showName) or (not self.db.AP.showColor) end,
							default = LootDrop_Defaults.AP.nameColor
							},
					[12] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOAP end,
							setFunc = function(v) self.db.display.cFontOAP = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOAP
							},
					[13] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontAP end,
							setFunc = function(v) self.db.display.cFontAP = v end,
							disabled = function() return not self.db.display.cFontOAP end,
							scrollable = 7,
							},
						},
					},
			[6] = { -- Veterancy Points
				type = 'submenu',
				name = L.VeterancyPoints,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.VeterancyPoints,
							tooltip = L.VeterancyPointsTip,
							getFunc = function() return self.db.VP.showVP end,
							setFunc = function(value) self:ToggleVP(value) end,
							width = "full",
							default = LootDrop_Defaults.VP.showVP
							},
					[2] = {
							type = "checkbox",
							name = L.ShowPrefix,
							tooltip = L.ShowPrefixTip,
							getFunc = function() return self.db.VP.showPrefix end,
							setFunc = function(value) self.db.VP.showPrefix = value end,
							width = "half",
							disabled = function() return not self.db.VP.showVP end,
							default = LootDrop_Defaults.VP.showPrefix
							},
					[3] = {
							type = "checkbox",
							name = L.ShowVPLevel,
							tooltip = L.ShowVPLevelTip,
							getFunc = function() return self.db.VP.showLevel end,
							setFunc = function(value) self.db.VP.showLevel = value end,
							width = "half",
							disabled = function() return not self.db.VP.showVP end,
							default = LootDrop_Defaults.VP.showLevel
							},
					[4] = {
							type = "checkbox",
							name = L.ShowVPProgress,
							tooltip = L.ShowVPProgressTip,
							getFunc = function() return self.db.VP.showProgress end,
							setFunc = function(value) self.db.VP.showProgress = value end,
							width = "half",
							disabled = function() return not self.db.VP.showVP end,
							default = LootDrop_Defaults.VP.showProgress
							},
					[5] = {
							type = "checkbox",
							name = L.ShowXPProgFull,
							tooltip = L.ShowVPProgFullTip,
							getFunc = function() return self.db.VP.showProgFull end,
							setFunc = function(value) self.db.VP.showProgFull = value end,
							width = "half",
							disabled = function() return (not self.db.VP.showVP) or (not self.db.VP.showProgress) end,
							default = LootDrop_Defaults.VP.showProgFull
							},
					[6] = {
							type = "checkbox",
							name = L.ShowVPGain,
							tooltip = L.ShowVPGainTip,
							getFunc = function() return self.db.VP.showVPGain end,
							setFunc = function(value) self.db.VP.showVPGain = value end,
							width = "half",
							disabled = function() return not self.db.VP.showVP end,
							default = LootDrop_Defaults.VP.showVPGain
							},
					[7] = {
							type = "checkbox",
							name = L.ShowSuffix,
							tooltip = L.ShowSuffixTip,
							getFunc = function() return self.db.VP.showName end,
							setFunc = function(value) self.db.VP.showName = value end,
							width = "half",
							disabled = function() return not self.db.VP.showVP end,
							default = LootDrop_Defaults.VP.showName
							},
					[8] = {
							type = "checkbox",
							name = L.ShowFullName,
							tooltip = L.ShowFullNameTip,
							getFunc = function() return self.db.VP.showNameFull end,
							setFunc = function(value) self.db.VP.showNameFull = value end,
							width = "half",
							disabled = function() return (not self.db.VP.showVP) or (not self.db.VP.showName) end,
							default = LootDrop_Defaults.VP.showNameFull
							},
					[9] = {
							type = 'editbox',
							name = L.CustomName,
							tooltip = L.CustomNameTip,
							getFunc = function() return self.db.VP.showCName end,
							setFunc = function(value) self.db.VP.showCName = value end,
							isMultiline = false,
							width = "half",
							disabled = function() return (not self.db.VP.showVP) or (not self.db.VP.showName) or (not self.db.VP.showNameFull) end,
							default = LootDrop_Defaults.VP.showCName
							},
					[10] = {
							type = "checkbox",
							name = L.ShowColor,
							tooltip = L.ShowColorTip,
							getFunc = function() return self.db.VP.showColor end,
							setFunc = function(value) self.db.VP.showColor = value end,
							width = "half",
							disabled = function() return (not self.db.VP.showVP) or (not self.db.VP.showName) end,
							default = LootDrop_Defaults.VP.showColor
							},
					[11] = {
							type = 'colorpicker',
							name = L.NameColor,
							getFunc = function() return unpack(self.db.VP.nameColor) end,
							setFunc = function(r, g, b, a)
								self.db.VP.nameColor[1] = r
								self.db.VP.nameColor[2] = g
								self.db.VP.nameColor[3] = b
								self.db.VP.nameColor[4] = a
							end,
							width = "half",
							disabled = function() return (not self.db.VP.showVP) or (not self.db.VP.showName) or (not self.db.VP.showColor) end,
							default = LootDrop_Defaults.VP.nameColor
							},
					[12] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOVP end,
							setFunc = function(v) self.db.display.cFontOVP = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOVP
							},
					[13] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontVP end,
							setFunc = function(v) self.db.display.cFontVP = v end,
							disabled = function() return not self.db.display.cFontOVP end,
							scrollable = 7,
							},
						},
					},
			[7] = { -- Currencies
				type = 'submenu',
				name = L.Currencies,
				tooltip = '',
				controls = {
					[1] = { -- Telvar Stones
						type = 'submenu',
						name = L.TelvarStones,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.TelvarStones,
									tooltip = L.TelvarStonesTip,
									getFunc = function() return self.db.currency.showTelvar end,
									setFunc = function(value) self:ToggleTV(value) end,
									width = "full",
									default = LootDrop_Defaults.currency.showTelvar
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.telvarPrefix end,
									setFunc = function(value) self.db.currency.telvarPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTelvar end,
									default = LootDrop_Defaults.currency.telvarPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.TelvarMult,
									tooltip = L.TelvarMultTip,
									getFunc = function() return self.db.currency.telvarMulti end,
									setFunc = function(value) self.db.currency.telvarMulti = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTelvar end,
									default = LootDrop_Defaults.currency.telvarMulti
									},
							[4] = {
									type = "checkbox",
									name = L.ShowHeld,
									tooltip = L.ShowHeldTip,
									getFunc = function() return self.db.currency.telvarBag end,
									setFunc = function(value) self.db.currency.telvarBag = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTelvar end,
									default = LootDrop_Defaults.currency.telvarBag
									},
							[5] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.telvarName end,
									setFunc = function(value) self.db.currency.telvarName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTelvar end,
									default = LootDrop_Defaults.currency.telvarName
									},
							[6] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.telvarCName end,
									setFunc = function(value) self.db.currency.telvarCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showTelvar) or (not self.db.currency.telvarName) end,
									default = LootDrop_Defaults.currency.telvarCName
									},
							[7] = {
									type = "custom",
									width = "half",
									},
							[8] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.telvarSColor end,
									setFunc = function(value) self.db.currency.telvarSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showTelvar) or (not self.db.currency.telvarName) end,
									default = LootDrop_Defaults.currency.telvarSColor
									},
							[9] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.telvarColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.telvarColor[1] = r
										self.db.currency.telvarColor[2] = g
										self.db.currency.telvarColor[3] = b
										self.db.currency.telvarColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showTelvar) or (not self.db.currency.telvarName) or (not self.db.currency.telvarSColor) end,
									default = LootDrop_Defaults.currency.telvarColor
									},
							[10] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOTV end,
									setFunc = function(v) self.db.display.cFontOTV = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOTV
									},
							[11] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontTV end,
									setFunc = function(v) self.db.display.cFontTV = v end,
									disabled = function() return not self.db.display.cFontOTV end,
									scrollable = 7,
									},
								},
							},
					[2] = { -- Writ Voucher
						type = 'submenu',
						name = L.WritVouchers,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.WritVouchers,
									tooltip = L.WritVouchersTip,
									getFunc = function() return self.db.currency.showVoucher end,
									setFunc = function(value) self:ToggleWVoucher(value) end,
									width = "full",
									default = LootDrop_Defaults.currency.showVoucher
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.voucherPrefix end,
									setFunc = function(value) self.db.currency.voucherPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showVoucher end,
									default = LootDrop_Defaults.currency.voucherPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowHeld,
									tooltip = L.ShowHeldTip,
									getFunc = function() return self.db.currency.voucherBag end,
									setFunc = function(value) self.db.currency.voucherBag = value end,
									width = "half",
									disabled = function() return not self.db.currency.showVoucher end,
									default = LootDrop_Defaults.currency.voucherBag
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.voucherName end,
									setFunc = function(value) self.db.currency.voucherName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showVoucher end,
									default = LootDrop_Defaults.currency.voucherName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.voucherCName end,
									setFunc = function(value) self.db.currency.voucherCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showVoucher) or (not self.db.currency.voucherName) end,
									default = LootDrop_Defaults.currency.voucherCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.voucherSColor end,
									setFunc = function(value) self.db.currency.voucherSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showVoucher) or (not self.db.currency.voucherName) end,
									default = LootDrop_Defaults.currency.voucherSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.voucherColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.voucherColor[1] = r
										self.db.currency.voucherColor[2] = g
										self.db.currency.voucherColor[3] = b
										self.db.currency.voucherColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showVoucher) or (not self.db.currency.voucherName) or (not self.db.currency.voucherSColor) end,
									default = LootDrop_Defaults.currency.voucherColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOWV end,
									setFunc = function(v) self.db.display.cFontOWV = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOWV
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontWV end,
									setFunc = function(v) self.db.display.cFontWV = v end,
									disabled = function() return not self.db.display.cFontOWV end,
									scrollable = 7,
									},
								},
							},
					[3] = { -- Undaunted
						type = 'submenu',
						name = L.UndauntedKeys,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.UndauntedKeys,
									tooltip = L.UndauntedKeysTip,
									getFunc = function() return self.db.currency.showUndaunted end,
									setFunc = function(value)
										self.db.currency.showUndaunted = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showUndaunted
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.undauntedPrefix end,
									setFunc = function(value) self.db.currency.undauntedPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showUndaunted end,
									default = LootDrop_Defaults.currency.undauntedPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.undauntedAcct end,
									setFunc = function(value) self.db.currency.undauntedAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showUndaunted end,
									default = LootDrop_Defaults.currency.undauntedAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.undauntedName end,
									setFunc = function(value) self.db.currency.undauntedName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showUndaunted end,
									default = LootDrop_Defaults.currency.undauntedName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.undauntedCName end,
									setFunc = function(value) self.db.currency.undauntedCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showUndaunted) or (not self.db.currency.undauntedName) end,
									default = LootDrop_Defaults.currency.undauntedCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.undauntedSColor end,
									setFunc = function(value) self.db.currency.undauntedSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showUndaunted) or (not self.db.currency.undauntedName) end,
									default = LootDrop_Defaults.currency.undauntedSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.undauntedColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.undauntedColor[1] = r
										self.db.currency.undauntedColor[2] = g
										self.db.currency.undauntedColor[3] = b
										self.db.currency.undauntedColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showUndaunted) or (not self.db.currency.undauntedName) or (not self.db.currency.undauntedSColor) end,
									default = LootDrop_Defaults.currency.undauntedColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOUK end,
									setFunc = function(v) self.db.display.cFontOUK = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOUK
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontUK end,
									setFunc = function(v) self.db.display.cFontUK = v end,
									disabled = function() return not self.db.display.cFontOUK end,
									scrollable = 7,
									},
								},
							},
					[4] = { -- Transmute Crystals
						type = 'submenu',
						name = L.TransmuteCrystals,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.TransmuteCrystals,
									tooltip = L.TransmuteCrystalsTip,
									getFunc = function() return self.db.currency.showTransmute end,
									setFunc = function(value)
										self.db.currency.showTransmute = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showTransmute
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.transmutePrefix end,
									setFunc = function(value) self.db.currency.transmutePrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTransmute end,
									default = LootDrop_Defaults.currency.transmutePrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowMax,
									tooltip = L.ShowMaxTip,
									getFunc = function() return self.db.currency.transmuteMax end,
									setFunc = function(value) self.db.currency.transmuteMax = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTransmute end,
									default = LootDrop_Defaults.currency.transmuteMax
									},
							[4] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.transmuteAcct end,
									setFunc = function(value) self.db.currency.transmuteAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTransmute end,
									default = LootDrop_Defaults.currency.transmuteAcct
									},
							[5] = {
									type = "custom",
									width = "half",
									},
							[6] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.transmuteName end,
									setFunc = function(value) self.db.currency.transmuteName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTransmute end,
									default = LootDrop_Defaults.currency.transmuteName
									},
							[7] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.transmuteCName end,
									setFunc = function(value) self.db.currency.transmuteCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showTransmute) or (not self.db.currency.transmuteName) end,
									default = LootDrop_Defaults.currency.transmuteCName
									},
							[8] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.transmuteSColor end,
									setFunc = function(value) self.db.currency.transmuteSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showTransmute) or (not self.db.currency.transmuteName) end,
									default = LootDrop_Defaults.currency.transmuteSColor
									},
							[9] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.transmuteColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.transmuteColor[1] = r
										self.db.currency.transmuteColor[2] = g
										self.db.currency.transmuteColor[3] = b
										self.db.currency.transmuteColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showTransmute) or (not self.db.currency.transmuteName) or (not self.db.currency.transmuteSColor) end,
									default = LootDrop_Defaults.currency.transmuteColor
									},
							[10] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOTC end,
									setFunc = function(v) self.db.display.cFontOTC = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOTC
									},
							[11] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontTC end,
									setFunc = function(v) self.db.display.cFontTC = v end,
									disabled = function() return not self.db.display.cFontOTC end,
									scrollable = 7,
									},
								},
							},
					[5] = { -- Event Tickets
						type = 'submenu',
						name = L.EventTickets,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.EventTickets,
									tooltip = L.EventTicketsTip,
									getFunc = function() return self.db.currency.showEticket end,
									setFunc = function(value)
										self.db.currency.showEticket = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showEticket
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.eticketPrefix end,
									setFunc = function(value) self.db.currency.eticketPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEticket end,
									default = LootDrop_Defaults.currency.eticketPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowMax,
									tooltip = L.ShowMaxTip,
									getFunc = function() return self.db.currency.eticketMax end,
									setFunc = function(value) self.db.currency.eticketMax = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEticket end,
									default = LootDrop_Defaults.currency.eticketMax
									},
							[4] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.eticketAcct end,
									setFunc = function(value) self.db.currency.eticketAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEticket end,
									default = LootDrop_Defaults.currency.eticketAcct
									},
							[5] = {
									type = "custom",
									width = "half",
									},
							[6] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.eticketName end,
									setFunc = function(value) self.db.currency.eticketName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEticket end,
									default = LootDrop_Defaults.currency.eticketName
									},
							[7] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.eticketCName end,
									setFunc = function(value) self.db.currency.eticketCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showEticket) or (not self.db.currency.eticketName) end,
									default = LootDrop_Defaults.currency.eticketCName
									},
							[8] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.eticketSColor end,
									setFunc = function(value) self.db.currency.eticketSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showEticket) or (not self.db.currency.eticketName) end,
									default = LootDrop_Defaults.currency.eticketSColor
									},
							[9] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.eticketColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.eticketColor[1] = r
										self.db.currency.eticketColor[2] = g
										self.db.currency.eticketColor[3] = b
										self.db.currency.eticketColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showEticket) or (not self.db.currency.eticketName) or (not self.db.currency.eticketSColor) end,
									default = LootDrop_Defaults.currency.eticketColor
									},
							[10] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOET end,
									setFunc = function(v) self.db.display.cFontOET = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOET
									},
							[11] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontET end,
									setFunc = function(v) self.db.display.cFontET = v end,
									disabled = function() return not self.db.display.cFontOET end,
									scrollable = 7,
									},
								},
							},
					[6] = { -- Seals of Endeavor
						type = 'submenu',
						name = L.Endeavor,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.Endeavor,
									tooltip = L.EndeavorTip,
									getFunc = function() return self.db.currency.showEndeavor end,
									setFunc = function(value)
										self.db.currency.showEndeavor = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showEndeavor
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.endeavorPrefix end,
									setFunc = function(value) self.db.currency.endeavorPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEndeavor end,
									default = LootDrop_Defaults.currency.endeavorPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.endeavorAcct end,
									setFunc = function(value) self.db.currency.endeavorAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEndeavor end,
									default = LootDrop_Defaults.currency.endeavorAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.endeavorName end,
									setFunc = function(value) self.db.currency.endeavorName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEndeavor end,
									default = LootDrop_Defaults.currency.endeavorName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.endeavorCName end,
									setFunc = function(value) self.db.currency.endeavorCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showEndeavor) or (not self.db.currency.endeavorName) end,
									default = LootDrop_Defaults.currency.endeavorCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.endeavorSColor end,
									setFunc = function(value) self.db.currency.endeavorSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showEndeavor) or (not self.db.currency.endeavorName) end,
									default = LootDrop_Defaults.currency.endeavorSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.endeavorColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.endeavorColor[1] = r
										self.db.currency.endeavorColor[2] = g
										self.db.currency.endeavorColor[3] = b
										self.db.currency.endeavorColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showEndeavor) or (not self.db.currency.endeavorName) or (not self.db.currency.endeavorSColor) end,
									default = LootDrop_Defaults.currency.endeavorColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOES end,
									setFunc = function(v) self.db.display.cFontOES = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOES
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontES end,
									setFunc = function(v) self.db.display.cFontES = v end,
									disabled = function() return not self.db.display.cFontOES end,
									scrollable = 7,
									},
								},
							},
					[7] = { -- Archives Fortunes
						type = 'submenu',
						name = L.Endless,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.Endless,
									tooltip = L.EndlessTip,
									getFunc = function() return self.db.currency.showEndless end,
									setFunc = function(value)
										self.db.currency.showEndless = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showEndless
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.endlessPrefix end,
									setFunc = function(value) self.db.currency.endlessPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEndless end,
									default = LootDrop_Defaults.currency.endlessPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.endlessAcct end,
									setFunc = function(value) self.db.currency.endlessAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEndless end,
									default = LootDrop_Defaults.currency.endlessAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.endlessName end,
									setFunc = function(value) self.db.currency.endlessName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showEndless end,
									default = LootDrop_Defaults.currency.endlessName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.endlessCName end,
									setFunc = function(value) self.db.currency.endlessCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showEndless) or (not self.db.currency.endlessName) end,
									default = LootDrop_Defaults.currency.endlessCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.endlessSColor end,
									setFunc = function(value) self.db.currency.endlessSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showEndless) or (not self.db.currency.endlessName) end,
									default = LootDrop_Defaults.currency.endlessSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.endlessColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.endlessColor[1] = r
										self.db.currency.endlessColor[2] = g
										self.db.currency.endlessColor[3] = b
										self.db.currency.endlessColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showEndless) or (not self.db.currency.endlessName) or (not self.db.currency.endlessSColor) end,
									default = LootDrop_Defaults.currency.endlessColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOAF end,
									setFunc = function(v) self.db.display.cFontOAF = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOAF
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontAF end,
									setFunc = function(v) self.db.display.cFontAF = v end,
									disabled = function() return not self.db.display.cFontOAF end,
									scrollable = 7,
									},
								},
							},
					[8] = { -- Imperial Fragments
						type = 'submenu',
						name = L.Fragment,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.Fragment,
									tooltip = L.FragmentTip,
									getFunc = function() return self.db.currency.showFragment end,
									setFunc = function(value)
										self.db.currency.showFragment = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showFragment
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.fragmentPrefix end,
									setFunc = function(value) self.db.currency.fragmentPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showFragment end,
									default = LootDrop_Defaults.currency.fragmentPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.fragmentAcct end,
									setFunc = function(value) self.db.currency.fragmentAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showFragment end,
									default = LootDrop_Defaults.currency.fragmentAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.fragmentName end,
									setFunc = function(value) self.db.currency.fragmentName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showFragment end,
									default = LootDrop_Defaults.currency.fragmentName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.fragmentCName end,
									setFunc = function(value) self.db.currency.fragmentCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showFragment) or (not self.db.currency.fragmentName) end,
									default = LootDrop_Defaults.currency.fragmentCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.fragmentSColor end,
									setFunc = function(value) self.db.currency.fragmentSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showFragment) or (not self.db.currency.fragmentName) end,
									default = LootDrop_Defaults.currency.fragmentSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.fragmentColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.fragmentColor[1] = r
										self.db.currency.fragmentColor[2] = g
										self.db.currency.fragmentColor[3] = b
										self.db.currency.fragmentColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showFragment) or (not self.db.currency.fragmentName) or (not self.db.currency.fragmentSColor) end,
									default = LootDrop_Defaults.currency.fragmentColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOIF end,
									setFunc = function(v) self.db.display.cFontOIF = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOIF
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontIF end,
									setFunc = function(v) self.db.display.cFontIF = v end,
									disabled = function() return not self.db.display.cFontOIF end,
									scrollable = 7,
									},
								},
							},
					[9] = { -- Tome Points
						type = 'submenu',
						name = L.TomePoints,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.TomePoints,
									tooltip = L.TomePointsTip,
									getFunc = function() return self.db.currency.showTomePoints end,
									setFunc = function(value)
										self.db.currency.showTomePoints = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showTomePoints
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.TomePointsPrefix end,
									setFunc = function(value) self.db.currency.TomePointsPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomePoints end,
									default = LootDrop_Defaults.currency.TomePointsPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.TomePointsAcct end,
									setFunc = function(value) self.db.currency.TomePointsAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomePoints end,
									default = LootDrop_Defaults.currency.TomePointsAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.TomePointsName end,
									setFunc = function(value) self.db.currency.TomePointsName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomePoints end,
									default = LootDrop_Defaults.currency.TomePointsName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.TomePointsCName end,
									setFunc = function(value) self.db.currency.TomePointsCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showTomePoints) or (not self.db.currency.TomePointsName) end,
									default = LootDrop_Defaults.currency.TomePointsCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.TomePointsSColor end,
									setFunc = function(value) self.db.currency.TomePointsSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showTomePoints) or (not self.db.currency.TomePointsName) end,
									default = LootDrop_Defaults.currency.TomePointsSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.TomePointsColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.TomePointsColor[1] = r
										self.db.currency.TomePointsColor[2] = g
										self.db.currency.TomePointsColor[3] = b
										self.db.currency.TomePointsColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showTomePoints) or (not self.db.currency.TomePointsName) or (not self.db.currency.TomePointsSColor) end,
									default = LootDrop_Defaults.currency.TomePointsColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOTP end,
									setFunc = function(v) self.db.display.cFontOTP = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOTP
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontTP end,
									setFunc = function(v) self.db.display.cFontTP = v end,
									disabled = function() return not self.db.display.cFontOTP end,
									scrollable = 7,
									},
								},
							},
					[10] = { -- Tome Point Caches
						type = 'submenu',
						name = L.TomePointCaches,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.TomePointCaches,
									tooltip = L.TomePointCachesTip,
									getFunc = function() return self.db.currency.showTomePointCaches end,
									setFunc = function(value)
										self.db.currency.showTomePointCaches = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showTomePointCaches
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.TomePointCachesPrefix end,
									setFunc = function(value) self.db.currency.TomePointCachesPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomePointCaches end,
									default = LootDrop_Defaults.currency.TomePointCachesPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.TomePointCachesAcct end,
									setFunc = function(value) self.db.currency.TomePointCachesAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomePointCaches end,
									default = LootDrop_Defaults.currency.TomePointCachesAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.TomePointCachesName end,
									setFunc = function(value) self.db.currency.TomePointCachesName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomePointCaches end,
									default = LootDrop_Defaults.currency.TomePointCachesName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.TomePointCachesCName end,
									setFunc = function(value) self.db.currency.TomePointCachesCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showTomePointCaches) or (not self.db.currency.TomePointCachesName) end,
									default = LootDrop_Defaults.currency.TomePointCachesCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.TomePointCachesSColor end,
									setFunc = function(value) self.db.currency.TomePointCachesSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showTomePointCaches) or (not self.db.currency.TomePointCachesName) end,
									default = LootDrop_Defaults.currency.TomePointCachesSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.TomePointCachesColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.TomePointCachesColor[1] = r
										self.db.currency.TomePointCachesColor[2] = g
										self.db.currency.TomePointCachesColor[3] = b
										self.db.currency.TomePointCachesColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showTomePointCaches) or (not self.db.currency.TomePointCachesName) or (not self.db.currency.TomePointCachesSColor) end,
									default = LootDrop_Defaults.currency.TomePointCachesColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOTPC end,
									setFunc = function(v) self.db.display.cFontOTPC = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOTPC
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontTPC end,
									setFunc = function(v) self.db.display.cFontTPC = v end,
									disabled = function() return not self.db.display.cFontOTPC end,
									scrollable = 7,
									},
								},
							},
					[11] = { -- Tome Tokens
						type = 'submenu',
						name = L.TomeTokens,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.TomeTokens,
									tooltip = L.TomeTokensTip,
									getFunc = function() return self.db.currency.showTomeTokens end,
									setFunc = function(value)
										self.db.currency.showTomeTokens = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showTomeTokens
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.TomeTokensPrefix end,
									setFunc = function(value) self.db.currency.TomeTokensPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomeTokens end,
									default = LootDrop_Defaults.currency.TomeTokensPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.TomeTokensAcct end,
									setFunc = function(value) self.db.currency.TomeTokensAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomeTokens end,
									default = LootDrop_Defaults.currency.TomeTokensAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.TomeTokensName end,
									setFunc = function(value) self.db.currency.TomeTokensName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTomeTokens end,
									default = LootDrop_Defaults.currency.TomeTokensName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.TomeTokensCName end,
									setFunc = function(value) self.db.currency.TomeTokensCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showTomeTokens) or (not self.db.currency.TomeTokensName) end,
									default = LootDrop_Defaults.currency.TomeTokensCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.TomeTokensSColor end,
									setFunc = function(value) self.db.currency.TomeTokensSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showTomeTokens) or (not self.db.currency.TomeTokensName) end,
									default = LootDrop_Defaults.currency.TomeTokensSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.TomeTokensColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.TomeTokensColor[1] = r
										self.db.currency.TomeTokensColor[2] = g
										self.db.currency.TomeTokensColor[3] = b
										self.db.currency.TomeTokensColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showTomeTokens) or (not self.db.currency.TomeTokensName) or (not self.db.currency.TomeTokensSColor) end,
									default = LootDrop_Defaults.currency.TomeTokensColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOTT end,
									setFunc = function(v) self.db.display.cFontOTT = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOTT
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontTT end,
									setFunc = function(v) self.db.display.cFontTT = v end,
									disabled = function() return not self.db.display.cFontOTT end,
									scrollable = 7,
									},
								},
							},
					[12] = { -- Trade Bars
						type = 'submenu',
						name = L.TradeBars,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.TradeBars,
									tooltip = L.TradeBarsTip,
									getFunc = function() return self.db.currency.showTradeBars end,
									setFunc = function(value)
										self.db.currency.showTradeBars = value
										self:ToggleAccount()
									end,
									width = "full",
									default = LootDrop_Defaults.currency.showTradeBars
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.currency.TradeBarsPrefix end,
									setFunc = function(value) self.db.currency.TradeBarsPrefix = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTradeBars end,
									default = LootDrop_Defaults.currency.TradeBarsPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowAccount,
									tooltip = L.ShowAccountTip,
									getFunc = function() return self.db.currency.TradeBarsAcct end,
									setFunc = function(value) self.db.currency.TradeBarsAcct = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTradeBars end,
									default = LootDrop_Defaults.currency.TradeBarsAcct
									},
							[4] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.currency.TradeBarsName end,
									setFunc = function(value) self.db.currency.TradeBarsName = value end,
									width = "half",
									disabled = function() return not self.db.currency.showTradeBars end,
									default = LootDrop_Defaults.currency.TradeBarsName
									},
							[5] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.currency.TradeBarsCName end,
									setFunc = function(value) self.db.currency.TradeBarsCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.currency.showTradeBars) or (not self.db.currency.TradeBarsName) end,
									default = LootDrop_Defaults.currency.TradeBarsCName
									},
							[6] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.currency.TradeBarsSColor end,
									setFunc = function(value) self.db.currency.TradeBarsSColor = value end,
									width = "half",
									disabled = function() return (not self.db.currency.showTradeBars) or (not self.db.currency.TradeBarsName) end,
									default = LootDrop_Defaults.currency.TradeBarsSColor
									},
							[7] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.currency.TradeBarsColor) end,
									setFunc = function(r, g, b, a)
										self.db.currency.TradeBarsColor[1] = r
										self.db.currency.TradeBarsColor[2] = g
										self.db.currency.TradeBarsColor[3] = b
										self.db.currency.TradeBarsColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.currency.showTradeBars) or (not self.db.currency.TradeBarsName) or (not self.db.currency.TradeBarsSColor) end,
									default = LootDrop_Defaults.currency.TradeBarsColor
									},
							[8] = {
									type = "checkbox",
									name = L.GFontOverride,
									tooltip = L.GFontOverrideTip,
									getFunc = function() return self.db.display.cFontOTB end,
									setFunc = function(v) self.db.display.cFontOTB = v end,
									width = "full",
									default = LootDrop_Defaults.display.cFontOTB
									},
							[9] = {
									type = 'dropdown',
									name = L.OverrideFont,
									choices = LMP:List('font'),
									getFunc = function() return self.db.display.cFontTB end,
									setFunc = function(v) self.db.display.cFontTB = v end,
									disabled = function() return not self.db.display.cFontOTB end,
									scrollable = 7,
									},
								},
							},
						},
					},
			[8] = { -- Skills
				type = 'submenu',
				name = L.SkillDisplay,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.SkillTrees,
							tooltip = L.SkillTreesTip,
							getFunc = function() return self.db.skills.showSkills end,
							setFunc = function(value)
								self.db.skills.showSkills = value
								self:ToggleSkill()
							end,
							width = "full",
							default = LootDrop_Defaults.skills.showSkills
							},
					[2] = {
							type = "checkbox",
							name = L.OldGuildIcons,
							tooltip = L.OldGuildIconsTip,
							getFunc = function() return self.db.skills.oldGuildIcons end,
							setFunc = function(value) self.db.skills.oldGuildIcons = value end,
							width = "half",
							disabled = function(value) return not self.db.skills.showSkills end,
							default = LootDrop_Defaults.skills.oldGuildIcons
							},
					[3] = {
							type = "checkbox",
							name = L.OldSkillIcons,
							tooltip = L.OldSkillIconsTip,
							getFunc = function() return self.db.skills.oldSkillIcons end,
							setFunc = function(value) self.db.skills.oldSkillIcons = value end,
							width = "half",
							disabled = function(value) return not self.db.skills.showSkills end,
							default = LootDrop_Defaults.skills.oldSkillIcons
							},
					[4] = {
							type = "checkbox",
							name = L.ShowPrefix,
							tooltip = L.ShowPrefixTip,
							getFunc = function() return self.db.skills.skillPrefix end,
							setFunc = function(value) self.db.skills.skillPrefix = value end,
							width = "half",
							disabled = function(value) return not self.db.skills.showSkills end,
							default = LootDrop_Defaults.skills.skillPrefix
							},
					[5] = {
							type = "checkbox",
							name = L.ShowSuffix,
							tooltip = L.ShowSuffixTip,
							getFunc = function() return self.db.skills.skillSuffix end,
							setFunc = function(value) self.db.skills.skillSuffix = value end,
							width = "half",
							disabled = function(value) return not self.db.skills.showSkills end,
							default = LootDrop_Defaults.skills.skillSuffix
							},
					[6] = {
							type = "checkbox",
							name = L.SkillNames,
							tooltip = L.SkillNamesTip,
							getFunc = function() return self.db.skills.skillNames end,
							setFunc = function(value) self.db.skills.skillNames = value end,
							width = "half",
							disabled = function(value) return not self.db.skills.showSkills end,
							default = LootDrop_Defaults.skills.skillNames
							},
					[7] = {
							type = "checkbox",
							name = L.ShowXPLevel,
							tooltip = L.ShowXPLevelTip,
							getFunc = function() return self.db.skills.skillLevel end,
							setFunc = function(value) self.db.skills.skillLevel = value end,
							width = "half",
							disabled = function() return not self.db.skills.showSkills end,
							default = LootDrop_Defaults.skills.skillLevel
							},
					[8] = {
							type = "checkbox",
							name = L.ShowXPProgress,
							tooltip = L.ShowXPProgressTip,
							getFunc = function() return self.db.skills.skillProgress end,
							setFunc = function(value) self.db.skills.skillProgress = value end,
							width = "half",
							disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.skillLevel) end,
							default = LootDrop_Defaults.skills.skillProgress
							},
					[9] = {
							type = "checkbox",
							name = L.ShowXPProgFull,
							tooltip = L.ShowXPProgFullTip,
							getFunc = function() return self.db.skills.skillProgFull end,
							setFunc = function(value) self.db.skills.skillProgFull = value end,
							width = "half",
							disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.skillLevel) or (not self.db.skills.skillProgress) end,
							default = LootDrop_Defaults.skills.skillProgFull
							},
					[10] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOSkill end,
							setFunc = function(v) self.db.display.cFontOSkill = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOSkill
							},
					[11] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontSkill end,
							setFunc = function(v) self.db.display.cFontSkill = v end,
							disabled = function() return not self.db.display.cFontOSkill end,
							scrollable = 7,
							},
					[12] = { -- Craft Options
						type = 'submenu',
						name = L.CraftXP,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.CraftXP,
									tooltip = L.CraftXPTip,
									getFunc = function() return self.db.skills.showCraft end,
									setFunc = function(value) 
										self.db.skills.showCraft = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showCraft
									},
							[2] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.craftSColor end,
									setFunc = function(value) self.db.skills.craftSColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showCraft) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.craftSColor
									},
							[3] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.craftColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.craftColor[1] = r
										self.db.skills.craftColor[2] = g
										self.db.skills.craftColor[3] = b
										self.db.skills.craftColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showCraft) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.craftColor
									},
								},
							},
					[13] = { -- Fence Options
						type = 'submenu',
						name = L.FenceXP,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.FenceXP,
									tooltip = L.FenceXPTip,
									getFunc = function() return self.db.skills.showFence end,
									setFunc = function(value) 
										self.db.skills.showFence = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showFence
									},
							[2] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.fenceSColor end,
									setFunc = function(value) self.db.skills.fenceSColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showFence) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.fenceSColor
									},
							[3] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.fenceColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.fenceColor[1] = r
										self.db.skills.fenceColor[2] = g
										self.db.skills.fenceColor[3] = b
										self.db.skills.fenceColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showFence) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.fenceColor
									},
								},
							},
					[14] = { -- Book Options
						type = 'submenu',
						name = L.BookKnowledge,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.BookKnowledge,
									tooltip = L.BookKnowledgeTip,
									getFunc = function() return self.db.skills.showBooks end,
									setFunc = function(value) 
										self.db.skills.showBooks = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showBooks
									},
							[2] = {
									type = "checkbox",
									name = L.BookLoot,
									tooltip = L.BookLootTip,
									getFunc = function() return self.db.loot.bookLoot end,
									setFunc = function(value) self:ToggleBookLoot(value) end,
									width = "full",
									default = LootDrop_Defaults.loot.bookLoot
									},
							[3] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.bookSColor end,
									setFunc = function(value) self.db.skills.bookSColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showBooks) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.bookSColor
									},
							[4] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.bookColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.bookColor[1] = r
										self.db.skills.bookColor[2] = g
										self.db.skills.bookColor[3] = b
										self.db.skills.bookColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showBooks) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.bookColor
									},
								},
							},
					[15] = { -- Guild Options
						type = 'submenu',
						name = L.GuildReputation,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.GuildReputation,
									tooltip = L.GuildReputationTip,
									getFunc = function() return self.db.skills.showGuilds end,
									setFunc = function(value) 
										self.db.skills.showGuilds = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showGuilds
									},
							[2] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.guildSColor end,
									setFunc = function(value) self.db.skills.guildSColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showGuilds) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.guildSColor
									},
							[3] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.guildColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.guildColor[1] = r
										self.db.skills.guildColor[2] = g
										self.db.skills.guildColor[3] = b
										self.db.skills.guildColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showGuilds) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.guildColor
									},
								},
							},
					[16] = { -- Weapon Options
						type = 'submenu',
						name = L.WeaponXP,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.WeaponXP,
									tooltip = L.WeaponXPTip,
									getFunc = function() return self.db.skills.showWeapon end,
									setFunc = function(value) 
										self.db.skills.showWeapon = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showWeapon
									},
							[2] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.weaponSColor end,
									setFunc = function(value) self.db.skills.weaponSColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showWeapon) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.weaponSColor
									},
							[3] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.weaponColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.weaponColor[1] = r
										self.db.skills.weaponColor[2] = g
										self.db.skills.weaponColor[3] = b
										self.db.skills.weaponColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showWeapon) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.weaponColor
									},
								},
							},
					[17] = { -- Armor Options
						type = 'submenu',
						name = L.ArmorXP,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.ArmorXP,
									tooltip = L.ArmorXPTip,
									getFunc = function() return self.db.skills.showArmor end,
									setFunc = function(value) 
										self.db.skills.showArmor = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showArmor
									},
							[2] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.armorSColor end,
									setFunc = function(value) self.db.skills.armorSColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showArmor) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.armorSColor
									},
							[3] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.armorColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.armorColor[1] = r
										self.db.skills.armorColor[2] = g
										self.db.skills.armorColor[3] = b
										self.db.skills.armorColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showArmor) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.armorColor
									},
								},
							},
					[18] = { -- World Options
						type = 'submenu',
						name = L.WorldXP,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.WorldXP,
									tooltip = L.WorldXPTip,
									getFunc = function() return self.db.skills.showWorld end,
									setFunc = function(value) 
										self.db.skills.showWorld = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showWorld
									},
							[2] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.worldSColor end,
									setFunc = function(value) self.db.skills.worldSColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showWorld) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.worldSColor
									},
							[3] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.worldColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.worldColor[1] = r
										self.db.skills.worldColor[2] = g
										self.db.skills.worldColor[3] = b
										self.db.skills.worldColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showWorld) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.worldColor
									},
								},
							},
					[19] = { -- AvA Options
						type = 'submenu',
						name = L.AvAXP,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.AvAXP,
									tooltip = L.AvAXPTip,
									getFunc = function() return self.db.skills.showAvA end,
									setFunc = function(value) 
										self.db.skills.showAvA = value
										self:ToggleSkill() 
									end,
									width = "full",
									disabled = function(value) return not self.db.skills.showSkills end,
									default = LootDrop_Defaults.skills.showAvA
									},
							[2] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.skills.AvASColor end,
									setFunc = function(value) self.db.skills.AvASColor = value end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showAvA) or (not self.db.skills.skillNames) end,
									default = LootDrop_Defaults.skills.AvASColor
									},
							[3] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.skills.AvAColor) end,
									setFunc = function(r, g, b, a)
										self.db.skills.AvAColor[1] = r
										self.db.skills.AvAColor[2] = g
										self.db.skills.AvAColor[3] = b
										self.db.skills.AvAColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.skills.showSkills) or (not self.db.skills.showAvA) or (not self.db.skills.skillNames) or (not self.db.skills.craftSColor) end,
									default = LootDrop_Defaults.skills.AvAColor
									},
								},
							},
						},
					},
			[9] = { -- Companions
				type = 'submenu',
				name = L.Companions,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOComp end,
							setFunc = function(v) self.db.display.cFontOComp = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOComp
							},
					[2] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontComp end,
							setFunc = function(v) self.db.display.cFontComp = v end,
							disabled = function() return not self.db.display.cFontOComp end,
							scrollable = 7,
							},
					[3] = { -- XP Options
						type = 'submenu',
						name = L.CompanionXP,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.CompanionXP,
									tooltip = L.CompanionXPTip,
									getFunc = function() return self.db.compXP.showXP end,
									setFunc = function(value) self:ToggleCompanionXP(value) end,
									width = "full",
									default = LootDrop_Defaults.compXP.showXP
									},
							[2] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.compXP.showPrefix end,
									setFunc = function(value) self.db.compXP.showPrefix = value end,
									width = "half",
									disabled = function() return not self.db.compXP.showXP end,
									default = LootDrop_Defaults.compXP.showPrefix
									},
							[3] = {
									type = "checkbox",
									name = L.ShowXPLevel,
									tooltip = L.ShowXPLevelTip,
									getFunc = function() return self.db.compXP.showLevel end,
									setFunc = function(value) self.db.compXP.showLevel = value end,
									width = "half",
									disabled = function() return not self.db.compXP.showXP end,
									default = LootDrop_Defaults.compXP.showLevel
									},
							[4] = {
									type = "checkbox",
									name = L.ShowXPProgress,
									tooltip = L.ShowXPProgressTip,
									getFunc = function() return self.db.compXP.showProgress end,
									setFunc = function(value) self.db.compXP.showProgress = value end,
									width = "half",
									disabled = function() return not self.db.compXP.showXP end,
									default = LootDrop_Defaults.compXP.showProgress
									},
							[5] = {
									type = "checkbox",
									name = L.ShowXPProgFull,
									tooltip = L.ShowXPProgFullTip,
									getFunc = function() return self.db.compXP.showProgFull end,
									setFunc = function(value) self.db.compXP.showProgFull = value end,
									width = "half",
									disabled = function() return (not self.db.compXP.showXP) or (not self.db.compXP.showProgress) end,
									default = LootDrop_Defaults.compXP.showProgFull
									},
							[6] = {
									type = "checkbox",
									name = L.ShowSuffix,
									tooltip = L.ShowSuffixTip,
									getFunc = function() return self.db.compXP.showName end,
									setFunc = function(value) self.db.compXP.showName = value end,
									width = "half",
									disabled = function() return not self.db.compXP.showXP end,
									default = LootDrop_Defaults.compXP.showName
									},
							[7] = {
									type = "checkbox",
									name = L.ShowFullName,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.compXP.showNameFull end,
									setFunc = function(value) self.db.compXP.showNameFull = value end,
									width = "half",
									disabled = function() return (not self.db.compXP.showXP) or (not self.db.compXP.showName) end,
									default = LootDrop_Defaults.compXP.showNameFull
									},
							[8] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.compXP.showCName end,
									setFunc = function(value) self.db.compXP.showCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.compXP.showXP) or (not self.db.compXP.showName) or (not self.db.compXP.showNameFull) end,
									default = LootDrop_Defaults.compXP.showCName
									},
							[9] = {
									type = "checkbox",
									name = L.CompFullName,
									tooltip = L.CompFullNameTip,
									getFunc = function() return self.db.compXP.showCFull end,
									setFunc = function(value) self.db.compXP.showCFull = value end,
									width = "half",
									disabled = function() return not self.db.compXP.showXP end,
									default = LootDrop_Defaults.compXP.showCFull
									},
							[10] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.compXP.showColor end,
									setFunc = function(value) self.db.compXP.showColor = value end,
									width = "half",
									disabled = function() return (not self.db.compXP.showXP) or (not self.db.compXP.showName) end,
									default = LootDrop_Defaults.compXP.showColor
									},
							[11] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.compXP.nameColor) end,
									setFunc = function(r, g, b, a)
										self.db.compXP.nameColor[1] = r
										self.db.compXP.nameColor[2] = g
										self.db.compXP.nameColor[3] = b
										self.db.compXP.nameColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.compXP.showXP) or (not self.db.compXP.showName) or (not self.db.compXP.showColor) end,
									default = LootDrop_Defaults.compXP.nameColor
									},
								},
							},
					[4] = { -- Rapport Options
						type = 'submenu',
						name = L.CompanionRapport,
						tooltip = '',
						controls = {
							[1] = {
									type = "checkbox",
									name = L.CompanionRapport,
									tooltip = L.CompanionRapportTip,
									getFunc = function() return self.db.rapport.showRppt end,
									setFunc = function(value) self:ToggleCompanionRapport(value) end,
									width = "full",
									default = LootDrop_Defaults.rapport.showRppt
									},
							[2] = {
									type = "checkbox",
									name = L.RapportStatus,
									tooltip = L.RapportStatusTip,
									getFunc = function() return self.db.rapport.showStatus end,
									setFunc = function(value) self.db.rapport.showStatus = value end,
									width = "half",
									disabled = function() return not self.db.rapport.showRppt end,
									default = LootDrop_Defaults.rapport.showStatus
									},
							[3] = {
									type = "checkbox",
									name = L.CompFullName,
									tooltip = L.CompFullNameTip,
									getFunc = function() return self.db.rapport.showCFull end,
									setFunc = function(value) self.db.rapport.showCFull = value end,
									width = "half",
									disabled = function() return not self.db.rapport.showRppt end,
									default = LootDrop_Defaults.rapport.showCFull
									},
							[4] = {
									type = "checkbox",
									name = L.ShowXPProgress,
									tooltip = L.ShowXPProgressTip,
									getFunc = function() return self.db.rapport.showProgress end,
									setFunc = function(value) self.db.rapport.showProgress = value end,
									width = "half",
									disabled = function() return not self.db.rapport.showRppt end,
									default = LootDrop_Defaults.rapport.showProgress
									},
							[5] = {
									type = "checkbox",
									name = L.ShowXPProgFull,
									tooltip = L.ExtendedRapportTip,
									getFunc = function() return self.db.rapport.showProgFull end,
									setFunc = function(value) self.db.rapport.showProgFull = value end,
									width = "half",
									disabled = function() return (not self.db.rapport.showRppt) or (not self.db.rapport.showProgress) end,
									default = LootDrop_Defaults.rapport.showProgFull
									},
							[6] = {
									type = "checkbox",
									name = L.ShowPrefix,
									tooltip = L.ShowPrefixTip,
									getFunc = function() return self.db.rapport.showPrefix end,
									setFunc = function(value) self.db.rapport.showPrefix = value end,
									width = "half",
									disabled = function() return not self.db.rapport.showRppt end,
									default = LootDrop_Defaults.rapport.showPrefix
									},
							[7] = {
									type = "checkbox",
									name = L.ShowSuffix,
									tooltip = L.ShowFullNameTip,
									getFunc = function() return self.db.rapport.showNameFull end,
									setFunc = function(value) self.db.rapport.showNameFull = value end,
									width = "half",
									disabled = function() return not self.db.rapport.showRppt end,
									default = LootDrop_Defaults.rapport.showNameFull
									},
							[8] = {
									type = 'editbox',
									name = L.CustomName,
									tooltip = L.CustomNameTip,
									getFunc = function() return self.db.rapport.showCName end,
									setFunc = function(value) self.db.rapport.showCName = value end,
									isMultiline = false,
									width = "half",
									disabled = function() return (not self.db.rapport.showRppt) or (not self.db.rapport.showNameFull) end,
									default = LootDrop_Defaults.rapport.showCName
									},
							[9] = {
									type = "custom",
									width = "half",
									},
							[10] = {
									type = "checkbox",
									name = L.ShowColor,
									tooltip = L.ShowColorTip,
									getFunc = function() return self.db.rapport.showColor end,
									setFunc = function(value) self.db.rapport.showColor = value end,
									width = "half",
									disabled = function() return (not self.db.rapport.showRppt) or (not self.db.rapport.showNameFull) end,
									default = LootDrop_Defaults.rapport.showColor
									},
							[11] = {
									type = 'colorpicker',
									name = L.NameColor,
									getFunc = function() return unpack(self.db.rapport.nameColor) end,
									setFunc = function(r, g, b, a)
										self.db.rapport.nameColor[1] = r
										self.db.rapport.nameColor[2] = g
										self.db.rapport.nameColor[3] = b
										self.db.rapport.nameColor[4] = a
									end,
									width = "half",
									disabled = function() return (not self.db.rapport.showRppt) or (not self.db.rapport.showNameFull) or (not self.db.rapport.showColor) end,
									default = LootDrop_Defaults.rapport.nameColor
									},
								},
							},
						},
					},
			[10] = { -- Achievement Options
				type = 'submenu',
				name = L.Achievements,
				tooltip = '',
				controls = {
					[1] = {
							type = "checkbox",
							name = L.Achievements,
							tooltip = L.AchievementsTip,
							getFunc = function() return self.db.achievements.showAchieve end,
							setFunc = function(value)
								self.db.achievements.showAchieve = value
								self:ToggleAchievements()
							end,
							width = "full",
							default = LootDrop_Defaults.achievements.showAchieve
							},
					[2] = {
							type = "checkbox",
							name = L.GFontOverride,
							tooltip = L.GFontOverrideTip,
							getFunc = function() return self.db.display.cFontOAchieve end,
							setFunc = function(v) self.db.display.cFontOAchieve = v end,
							width = "full",
							default = LootDrop_Defaults.display.cFontOAchieve
							},
					[3] = {
							type = 'dropdown',
							name = L.OverrideFont,
							choices = LMP:List('font'),
							getFunc = function() return self.db.display.cFontAchieve end,
							setFunc = function(v) self.db.display.cFontAchieve = v end,
							disabled = function() return not self.db.display.cFontOAchieve end,
							scrollable = 7,
							},
					[4] = {
							type = "checkbox",
							name = L.ShowCAchievements,
							tooltip = L.ShowCAchievementsTip,
							getFunc = function() return self.db.achievements.showCompleted end,
							setFunc = function(value)
								self.db.achievements.showCompleted = value
								self:ToggleAchievements()
							end,
							width = "full",
							disabled = function() return not self.db.achievements.showAchieve end,
							default = LootDrop_Defaults.achievements.showCompleted
							},
					[5] = {
							type = "checkbox",
							name = L.ShowColor,
							tooltip = L.ShowColorTip,
							getFunc = function() return self.db.achievements.cachieveSColor end,
							setFunc = function(value) self.db.achievements.cachieveSColor = value end,
							width = "half",
							disabled = function() return ((not self.db.achievements.showAchieve) or (not self.db.achievements.showCompleted)) end,
							default = LootDrop_Defaults.achievements.cachieveSColor
							},
					[6] = {
							type = 'colorpicker',
							name = L.NameColor,
							getFunc = function() return unpack(self.db.achievements.cachieveColor) end,
							setFunc = function(r, g, b, a)
								self.db.achievements.cachieveColor[1] = r
								self.db.achievements.cachieveColor[2] = g
								self.db.achievements.cachieveColor[3] = b
								self.db.achievements.cachieveColor[4] = a
							end,
							width = "half",
							disabled = function() return ((not self.db.achievements.showAchieve) or (not self.db.achievements.showCompleted) or (not self.db.achievements.cachieveSColor)) end,
							default = LootDrop_Defaults.achievements.cachieveColor
							},
					[7] = {
							type = "checkbox",
							name = L.ShowCPoints,
							tooltip = L.ShowCPointsTip,
							getFunc = function() return self.db.achievements.showPoints end,
							setFunc = function(value) self.db.achievements.showPoints = value end,
							width = "half",
							disabled = function() return not self.db.achievements.showAchieve end,
							default = LootDrop_Defaults.achievements.showPoints
							},
					[8] = {
							type = "custom",
							width = "half",
							},
					[9] = {
							type = "checkbox",
							name = L.ShowPAchievements,
							tooltip = L.ShowPAchievementsTip,
							getFunc = function() return self.db.achievements.showProgress end,
							setFunc = function(value)
								self.db.achievements.showProgress = value
								self:ToggleAchievements()
							end,
							width = "full",
							disabled = function() return not self.db.achievements.showAchieve end,
							default = LootDrop_Defaults.achievements.showProgress
							},
					[10] = {
							type = "checkbox",
							name = L.ShowColor,
							tooltip = L.ShowColorTip,
							getFunc = function() return self.db.achievements.pachieveSColor end,
							setFunc = function(value) self.db.achievements.pachieveSColor = value end,
							width = "half",
							disabled = function() return ((not self.db.achievements.showAchieve) or (not self.db.achievements.showProgress)) end,
							default = LootDrop_Defaults.achievements.pachieveSColor
							},
					[11] = {
							type = 'colorpicker',
							name = L.NameColor,
							getFunc = function() return unpack(self.db.achievements.pachieveColor) end,
							setFunc = function(r, g, b, a)
								self.db.achievements.pachieveColor[1] = r
								self.db.achievements.pachieveColor[2] = g
								self.db.achievements.pachieveColor[3] = b
								self.db.achievements.pachieveColor[4] = a
							end,
							width = "half",
							disabled = function() return ((not self.db.achievements.showAchieve) or (not self.db.achievements.showProgress) or (not self.db.achievements.pachieveSColor)) end,
							default = LootDrop_Defaults.achievements.pachieveColor
							},
						},
					},
				},
			},
		------------LOOT WINDOW FILTERS--------------
		{
			type = 'submenu',
			name = L.LootWindowFilters,
			tooltip = '',
			controls = {
				[1] = {
					type = "checkbox",
					name = L.LWFiltering,
					tooltip = L.LWFilteringTip,
					getFunc = function() return self.db.LWFilters.LWFiltering end,
					setFunc = function(value) self.db.LWFilters.LWFiltering = value end,
					width = "full",
					default = LootDrop_Defaults.LWFilters.LWFiltering
					},
				[2] = { -- GENERAL LOOT
					type = 'submenu',
					name = L.GeneralFilters,
					tooltip = '',
					controls = {
						[1] = {
							type = "checkbox",
							name = L.FilterTools,
							getFunc = function() return self.db.LWFilters.FilterTools end,
							setFunc = function(value) self.db.LWFilters.FilterTools = value filterTable[ITEMTYPE_TOOL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterTools
							},
						[2] = {
							type = "checkbox",
							name = L.FilterSoulGems,
							getFunc = function() return self.db.LWFilters.FilterSoulGems end,
							setFunc = function(value) self.db.LWFilters.FilterSoulGems = value filterTable[ITEMTYPE_SOUL_GEM].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterSoulGems
							},
						[3] = {
							type = "checkbox",
							name = L.FilterTrash,
							getFunc = function() return self.db.LWFilters.FilterTrash end,
							setFunc = function(value) self.db.LWFilters.FilterTrash = value filterTable[ITEMTYPE_TRASH].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterTrash
							},
						[4] = {
							type = "checkbox",
							name = L.FilterTreasure,
							getFunc = function() return self.db.LWFilters.FilterTreasure end,
							setFunc = function(value) self.db.LWFilters.FilterTreasure = value filterTable[ITEMTYPE_TREASURE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterTreasure
							},
						[5] = {
							type = "checkbox",
							name = L.FilterWGlyphs,
							getFunc = function() return self.db.LWFilters.FilterWGlyphs end,
							setFunc = function(value) self.db.LWFilters.FilterWGlyphs = value filterTable[ITEMTYPE_GLYPH_WEAPON].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterWGlyphs
							},
						[6] = {
							type = "checkbox",
							name = L.FilterAGlyphs,
							getFunc = function() return self.db.LWFilters.FilterAGlyphs end,
							setFunc = function(value) self.db.LWFilters.FilterAGlyphs = value filterTable[ITEMTYPE_GLYPH_ARMOR].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterAGlyphs
							},
						[7] = {
							type = "checkbox",
							name = L.FilterJGlyphs,
							getFunc = function() return self.db.LWFilters.FilterJGlyphs end,
							setFunc = function(value) self.db.LWFilters.FilterJGlyphs = value filterTable[ITEMTYPE_GLYPH_JEWELRY].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterJGlyphs
							},
						[8] = {
							type = "dropdown",
							name = L.FilterGlyphQ,
							tooltip = L.FilterGlyphQTip,
							choices = qualityChoices0,
							getFunc = function() return qualityChoices0[self.db.LWFilters.FilterGlyphQuality + 1] end,
							setFunc = function(choice) self.db.LWFilters.FilterGlyphQuality = reverseQualityChoices0[choice] - 1 end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or ((self.db.LWFilters.FilterWGlyphs) and (self.db.LWFilters.FilterAGlyphs) and (self.db.LWFilters.FilterJGlyphs)) end,
							default = qualityChoices0[LootDrop_Defaults.LWFilters.FilterGlyphQuality],
							},
						[9] = {
							type = "checkbox",
							name = L.FilterFurniture,
							getFunc = function() return self.db.LWFilters.FilterFurniture end,
							setFunc = function(value) self.db.LWFilters.FilterFurniture = value filterTable[ITEMTYPE_FURNISHING].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterFurniture
							},
						[10] = {
							type = "checkbox",
							name = L.FilterRecall,
							getFunc = function() return self.db.LWFilters.FilterRecall end,
							setFunc = function(value) self.db.LWFilters.FilterRecall = value filterTable[ITEMTYPE_RECALL_STONE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterRecall
							},
						[11] = {
							type = "checkbox",
							name = L.FilterSiege,
							getFunc = function() return self.db.LWFilters.FilterSiege end,
							setFunc = function(value) self.db.LWFilters.FilterSiege = value filterTable[ITEMTYPE_SIEGE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterSiege
							},
						[12] = {
							type = "checkbox",
							name = L.FilterAVARepair,
							getFunc = function() return self.db.LWFilters.FilterAVARepair end,
							setFunc = function(value) self.db.LWFilters.FilterAVARepair = value filterTable[ITEMTYPE_AVA_REPAIR].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterAVARepair
							},
						[13] = {
							type = "checkbox",
							name = L.FilterTrophies,
							getFunc = function() return self.db.LWFilters.FilterTrophies end,
							setFunc = function(value) self.db.LWFilters.FilterTrophies = value filterTable[ITEMTYPE_TROPHY].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterTrophies
							},
						[14] = {
							type = "checkbox",
							name = L.FilterCollectibles,
							getFunc = function() return self.db.LWFilters.FilterCollectibles end,
							setFunc = function(value) self.db.LWFilters.FilterCollectibles = value filterTable[ITEMTYPE_COLLECTIBLE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterCollectibles
							},
						[15] = {
							type = "checkbox",
							name = L.FilterContainers,
							getFunc = function() return self.db.LWFilters.FilterContainers end,
							setFunc = function(value) self.db.LWFilters.FilterContainers = value filterTable[ITEMTYPE_CONTAINER].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterContainers
							},
						[16] = {
							type = "checkbox",
							name = L.FilterCContainers,
							getFunc = function() return self.db.LWFilters.FilterCContainers end,
							setFunc = function(value) self.db.LWFilters.FilterCContainers = value filterTable[ITEMTYPE_CONTAINER_CURRENCY].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterCContainers
							},
						[17] = {
							type = "checkbox",
							name = L.FilterCostumes,
							getFunc = function() return self.db.LWFilters.FilterCostumes end,
							setFunc = function(value) self.db.LWFilters.FilterCostumes = value filterTable[ITEMTYPE_COSTUME].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterCostumes
							},
						[18] = {
							type = "checkbox",
							name = L.FilterDisguise,
							getFunc = function() return self.db.LWFilters.FilterDisguise end,
							setFunc = function(value) self.db.LWFilters.FilterDisguise = value filterTable[ITEMTYPE_DISGUISE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterDisguise
							},
						[19] = {
							type = "checkbox",
							name = L.FilterCrownItems,
							getFunc = function() return self.db.LWFilters.FilterCrownItems end,
							setFunc = function(value) self.db.LWFilters.FilterCrownItems = value filterTable[ITEMTYPE_CROWN_ITEM].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterCrownItems
							},
						[20] = {
							type = "checkbox",
							name = L.FilterCrownRepair,
							getFunc = function() return self.db.LWFilters.FilterCrownRepair end,
							setFunc = function(value) self.db.LWFilters.FilterCrownRepair = value filterTable[ITEMTYPE_CROWN_REPAIR].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterCrownRepair
							},
						},
					},
				[3] = { -- CONSUMABLES
					type = 'submenu',
					name = L.ConsumableFilters,
					tooltip = '',
					controls = {
						[1] = {
							type = "checkbox",
							name = L.FilterFood,
							getFunc = function() return self.db.LWFilters.FilterFood end,
							setFunc = function(value) self.db.LWFilters.FilterFood = value filterTable[ITEMTYPE_FOOD].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterFood
							},
						[2] = {
							type = "checkbox",
							name = L.FilterDrink,
							getFunc = function() return self.db.LWFilters.FilterDrink end,
							setFunc = function(value) self.db.LWFilters.FilterDrink = value filterTable[ITEMTYPE_DRINK].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterDrink
							},
						[3] = {
							type = "checkbox",
							name = L.FilterPotion,
							getFunc = function() return self.db.LWFilters.FilterPotion end,
							setFunc = function(value) self.db.LWFilters.FilterPotion = value filterTable[ITEMTYPE_POTION].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterPotion
							},
						[4] = {
							type = "checkbox",
							name = L.FilterPoison,
							getFunc = function() return self.db.LWFilters.FilterPoison end,
							setFunc = function(value) self.db.LWFilters.FilterPoison = value filterTable[ITEMTYPE_POISON].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterPoison
							},
						[5] = {
							type = "checkbox",
							name = L.FilterPlayerPotion,
							tooltip = L.FilterPlayerPotionTip,
							getFunc = function() return self.db.LWFilters.FilterPlayerPotion end,
							setFunc = function(value) self.db.LWFilters.FilterPlayerPotion = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterPlayerPotion
							},
						[6] = {
							type = "custom",
							width = "half",
							},
						[7] = {
							type = "checkbox",
							name = L.FilterPotionBase,
							getFunc = function() return self.db.LWFilters.FilterPotionBase end,
							setFunc = function(value) self.db.LWFilters.FilterPotionBase = value filterTable[ITEMTYPE_POTION_BASE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterPotionBase
							},
						[8] = {
							type = "checkbox",
							name = L.FilterPoisonBase,
							getFunc = function() return self.db.LWFilters.FilterPoisonBase end,
							setFunc = function(value) self.db.LWFilters.FilterPoisonBase = value filterTable[ITEMTYPE_POISON_BASE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterPoisonBase
							},

						[9] = {
							type = "checkbox",
							name = L.FilterFish,
							getFunc = function() return self.db.LWFilters.FilterFish end,
							setFunc = function(value) self.db.LWFilters.FilterFish = value filterTable[ITEMTYPE_FISH].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterFish
							},
						[10] = {
							type = "checkbox",
							name = L.FilterBait,
							getFunc = function() return self.db.LWFilters.FilterBait end,
							setFunc = function(value) self.db.LWFilters.FilterBait = value filterTable[ITEMTYPE_LURE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterBait
							},
						},
					},
				[4] = { -- CRAFTING
					type = 'submenu',
					name = L.CraftingFilters,
					tooltip = '',
					controls = {
						[1] = {
							type = "checkbox",
							name = L.FilterIngredients,
							getFunc = function() return self.db.LWFilters.FilterIngredients end,
							setFunc = function(value) self.db.LWFilters.FilterIngredients = value filterTable[ITEMTYPE_INGREDIENT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterIngredients
							},
						[2] = {
							type = "dropdown",
							name = L.FilterIngQ,
							tooltip = L.FilterIngQTip,
							choices = qualityChoices0,
							getFunc = function() return qualityChoices0[self.db.LWFilters.FilterIngQuality + 1] end,
							setFunc = function(choice) self.db.LWFilters.FilterIngQuality = reverseQualityChoices0[choice] - 1 end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterIngredients) end,
							default = qualityChoices0[LootDrop_Defaults.LWFilters.FilterIngQuality],
							},
						[3] = {
							type = "checkbox",
							name = L.FilterRecipes,
							getFunc = function() return self.db.LWFilters.FilterRecipes end,
							setFunc = function(value) self.db.LWFilters.FilterRecipes = value filterTable[ITEMTYPE_RECIPE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterRecipes
							},
						[4] = {
							type = "dropdown",
							name = L.FilterRecipeQ,
							tooltip = L.FilterRecipeQTip,
							choices = qualityChoices0,
							getFunc = function() return qualityChoices0[self.db.LWFilters.FilterRecipeQuality + 1] end,
							setFunc = function(choice) self.db.LWFilters.FilterRecipeQuality = reverseQualityChoices0[choice] - 1 end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterRecipes) end,
							default = qualityChoices0[LootDrop_Defaults.LWFilters.FilterRecipeQuality],
							},
						[5] = {
							type = "checkbox",
							name = L.FilterReagents,
							getFunc = function() return self.db.LWFilters.FilterReagents end,
							setFunc = function(value) self.db.LWFilters.FilterReagents = value filterTable[ITEMTYPE_REAGENT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterReagents
							},
						[6] = {
							type = "checkbox",
							name = L.FilterMasterWRits,
							getFunc = function() return self.db.LWFilters.FilterMasterWRits end,
							setFunc = function(value) self.db.LWFilters.FilterMasterWRits = value filterTable[ITEMTYPE_MASTER_WRIT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterMasterWRits
							},
						[7] = {
							type = "checkbox",
							name = L.FilterWTrait,
							getFunc = function() return self.db.LWFilters.FilterWTrait end,
							setFunc = function(value) self.db.LWFilters.FilterWTrait = value filterTable[ITEMTYPE_WEAPON_TRAIT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterWTrait
							},
						[8] = {
							type = "checkbox",
							name = L.FilterATrait,
							getFunc = function() return self.db.LWFilters.FilterATrait end,
							setFunc = function(value) self.db.LWFilters.FilterATrait = value filterTable[ITEMTYPE_ARMOR_TRAIT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterATrait
							},
						[9] = {
							type = "checkbox",
							name = L.FilterFurnMats,
							getFunc = function() return self.db.LWFilters.FilterFurnMats end,
							setFunc = function(value) self.db.LWFilters.FilterFurnMats = value filterTable[ITEMTYPE_FURNISHING_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterFurnMats
							},
						[10] = {
							type = "checkbox",
							name = L.FilterStyleMats,
							getFunc = function() return self.db.LWFilters.FilterStyleMats end,
							setFunc = function(value) self.db.LWFilters.FilterStyleMats = value filterTable[ITEMTYPE_STYLE_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterStyleMats
							},
						[11] = {
							type = "checkbox",
							name = L.FilterCompMats,
							getFunc = function() return self.db.LWFilters.FilterCompMats end,
							setFunc = function(value) self.db.LWFilters.FilterCompMats = value filterTable[ITEMTYPE_RAW_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterCompMats
							},
						[12] = {
							type = "checkbox",
							name = L.FilterMotif,
							getFunc = function() return self.db.LWFilters.FilterMotif end,
							setFunc = function(value) self.db.LWFilters.FilterMotif = value filterTable[ITEMTYPE_RACIAL_STYLE_MOTIF].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterMotif
							},
						[13] = {
							type = "header",
							name = L.FilterCraftingMats,
							},
						[14] = {
							type = "checkbox",
							name = L.FilterERune,
							getFunc = function() return self.db.LWFilters.FilterERune end,
							setFunc = function(value) self.db.LWFilters.FilterERune = value filterTable[ITEMTYPE_ENCHANTING_RUNE_ESSENCE].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterERune
							},
						[15] = {
							type = "checkbox",
							name = L.FilterPRune,
							getFunc = function() return self.db.LWFilters.FilterPRune end,
							setFunc = function(value) self.db.LWFilters.FilterPRune = value filterTable[ITEMTYPE_ENCHANTING_RUNE_POTENCY].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterPRune
							},
						[16] = {
							type = "checkbox",
							name = L.FilterARune,
							getFunc = function() return self.db.LWFilters.FilterARune end,
							setFunc = function(value) self.db.LWFilters.FilterARune = value filterTable[ITEMTYPE_ENCHANTING_RUNE_ASPECT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterARune
							},
						[17] = {
							type = "dropdown",
							name = L.FilterARuneQ,
							tooltip = L.FilterARuneQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.LWFilters.FilterARuneQ] end,
							setFunc = function(choice) self.db.LWFilters.FilterARuneQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterARune) end,
							default = qualityChoices[LootDrop_Defaults.LWFilters.FilterARuneQ],
							},
						[18] = {
							type = "checkbox",
							name = L.FilterBSMats,
							getFunc = function() return self.db.LWFilters.FilterBSMats end,
							setFunc = function(value) self.db.LWFilters.FilterBSMats = value filterTable[ITEMTYPE_BLACKSMITHING_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterBSMats
							},
						[19] = {
							type = "checkbox",
							name = L.FilterBSRawMats,
							getFunc = function() return self.db.LWFilters.FilterBSRawMats end,
							setFunc = function(value) self.db.LWFilters.FilterBSRawMats = value filterTable[ITEMTYPE_BLACKSMITHING_RAW_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterBSRawMats
							},
						[20] = {
							type = "checkbox",
							name = L.FilterBSImprove,
							getFunc = function() return self.db.LWFilters.FilterBSImprove end,
							setFunc = function(value) self.db.LWFilters.FilterBSImprove = value filterTable[ITEMTYPE_BLACKSMITHING_BOOSTER].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterBSImprove
							},
						[21] = {
							type = "dropdown",
							name = L.FilterBSImproveQ,
							tooltip = L.FilterBSImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.LWFilters.FilterBSImproveQ] end,
							setFunc = function(choice) self.db.LWFilters.FilterBSImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterBSImprove) end,
							default = qualityChoices[LootDrop_Defaults.LWFilters.FilterBSImproveQ],
							},
						[22] = {
							type = "checkbox",
							name = L.FilterClothMats,
							getFunc = function() return self.db.LWFilters.FilterClothMats end,
							setFunc = function(value) self.db.LWFilters.FilterClothMats = value filterTable[ITEMTYPE_CLOTHIER_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterClothMats
							},
						[23] = {
							type = "checkbox",
							name = L.FilterClothRawMats,
							getFunc = function() return self.db.LWFilters.FilterClothRawMats end,
							setFunc = function(value) self.db.LWFilters.FilterClothRawMats = value filterTable[ITEMTYPE_CLOTHIER_RAW_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterClothRawMats
							},
						[24] = {
							type = "checkbox",
							name = L.FilterClothImprove,
							getFunc = function() return self.db.LWFilters.FilterClothImprove end,
							setFunc = function(value) self.db.LWFilters.FilterClothImprove = value filterTable[ITEMTYPE_CLOTHIER_BOOSTER].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterClothImprove
							},
						[25] = {
							type = "dropdown",
							name = L.FilterClothImproveQ,
							tooltip = L.FilterClothImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.LWFilters.FilterClothImproveQ] end,
							setFunc = function(choice) self.db.LWFilters.FilterClothImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterClothImprove) end,
							default = qualityChoices[LootDrop_Defaults.LWFilters.FilterClothImproveQ],
							},
						[26] = {
							type = "checkbox",
							name = L.FilterWoodMats,
							getFunc = function() return self.db.LWFilters.FilterWoodMats end,
							setFunc = function(value) self.db.LWFilters.FilterWoodMats = value filterTable[ITEMTYPE_WOODWORKING_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterWoodMats
							},
						[27] = {
							type = "checkbox",
							name = L.FilterWoodRawMats,
							getFunc = function() return self.db.LWFilters.FilterWoodRawMats end,
							setFunc = function(value) self.db.LWFilters.FilterWoodRawMats = value filterTable[ITEMTYPE_WOODWORKING_RAW_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterWoodRawMats
							},
						[28] = {
							type = "checkbox",
							name = L.FilterWoodImprove,
							getFunc = function() return self.db.LWFilters.FilterWoodImprove end,
							setFunc = function(value) self.db.LWFilters.FilterWoodImprove = value filterTable[ITEMTYPE_WOODWORKING_BOOSTER].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterWoodImprove
							},
						[29] = {
							type = "dropdown",
							name = L.FilterWoodImproveQ,
							tooltip = L.FilterWoodImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.LWFilters.FilterWoodImproveQ] end,
							setFunc = function(choice) self.db.LWFilters.FilterWoodImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterWoodImprove) end,
							default = qualityChoices[LootDrop_Defaults.LWFilters.FilterWoodImproveQ],
							},
						[30] = {
							type = "checkbox",
							name = L.FilterJCMats,
							getFunc = function() return self.db.LWFilters.FilterJCMats end,
							setFunc = function(value) self.db.LWFilters.FilterJCMats = value filterTable[ITEMTYPE_JEWELRYCRAFTING_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterJCMats
							},
						[31] = {
							type = "checkbox",
							name = L.FilterJCRawMats,
							getFunc = function() return self.db.LWFilters.FilterJCRawMats end,
							setFunc = function(value) self.db.LWFilters.FilterJCRawMats = value filterTable[ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterJCRawMats
							},
						[32] = {
							type = "checkbox",
							name = L.FilterJCTrait,
							getFunc = function() return self.db.LWFilters.FilterJCTrait end,
							setFunc = function(value) self.db.LWFilters.FilterJCTrait = value filterTable[ITEMTYPE_JEWELRY_TRAIT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterJCTrait
							},
						[33] = {
							type = "checkbox",
							name = L.FilterJCRawTrait,
							getFunc = function() return self.db.LWFilters.FilterJCRawTrait end,
							setFunc = function(value) self.db.LWFilters.FilterJCRawTrait = value filterTable[ITEMTYPE_JEWELRY_RAW_TRAIT].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterJCRawTrait
							},
						[34] = {
							type = "checkbox",
							name = L.FilterJCImprove,
							getFunc = function() return self.db.LWFilters.FilterJCImprove end,
							setFunc = function(value) self.db.LWFilters.FilterJCImprove = value filterTable[ITEMTYPE_JEWELRYCRAFTING_BOOSTER].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterJCImprove
							},
						[35] = {
							type = "checkbox",
							name = L.FilterJCRawImprove,
							getFunc = function() return self.db.LWFilters.FilterJCRawImprove end,
							setFunc = function(value) self.db.LWFilters.FilterJCRawImprove = value filterTable[ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER].LW = value end,
							width = "half",
							disabled = function() return not self.db.LWFilters.LWFiltering end,
							default = LootDrop_Defaults.LWFilters.FilterJCRawImprove
							},
						[36] = {
							type = "dropdown",
							name = L.FilterJCImproveQ,
							tooltip = L.FilterJCImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.LWFilters.FilterJCImproveQ] end,
							setFunc = function(choice) self.db.LWFilters.FilterJCImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterJCImprove) end,
							default = qualityChoices[LootDrop_Defaults.LWFilters.FilterJCImproveQ],
							},
						[37] = {
							type = "dropdown",
							name = L.FilterJCRImproveQ,
							tooltip = L.FilterJCRImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.LWFilters.FilterJCRImproveQ] end,
							setFunc = function(choice) self.db.LWFilters.FilterJCRImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.LWFilters.LWFiltering) or (self.db.LWFilters.FilterJCRawImprove) end,
							default = qualityChoices[LootDrop_Defaults.LWFilters.FilterJCRImproveQ],
							},
						},
					},
				},
			},
		------------CHAT LOG--------------
		{
			type = 'submenu',
			name = L.ChatOptionHeader,
			tooltip = '',
			controls = {
			[1] = {
					type = "checkbox",
					name = L.ShowInChat,
					tooltip = L.ShowInChatTip,
					getFunc = function() return self.db.chat.DbgLogMine end,
					setFunc = function(value) self:ToggleDbgLog(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogMine
					},
			[2] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogMine end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogMine = choice end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogMine end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogMine",
					},
			[3] = {
					type = "dropdown",
					name = L.QualityCap,
					tooltip = L.MyLootQCapTip,
					choices = qualityChoices,
					getFunc = function() return qualityChoices[self.db.chat.DbgLogMineQlty] end,
					setFunc = function(choice) self.db.chat.DbgLogMineQlty = reverseQualityChoices[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogMine end,
					default = qualityChoices[LootDrop_Defaults.chat.DbgLogMineQlty],
					},
			[4] = {
					type = "custom",
					width = "half",
					},
			[5] = {
					type = "checkbox",
					name = L.ShowGroupLoot,
					tooltip = L.ShowGroupLootTip,
					getFunc = function() return self.db.chat.DbgLogOthers end,
					setFunc = function(value) self:ToggleOthersLog(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogOthers
					},
			[6] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogOthers end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogOthers = choice end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogOthers end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogOthers",
					},
			[7] = {
					type = "dropdown",
					name = L.QualityCap,
					tooltip = L.GroupLootQCapTip,
					choices = qualityChoices,
					getFunc = function() return qualityChoices[self.db.chat.DbgLogOthersQlty] end,
					setFunc = function(choice) self.db.chat.DbgLogOthersQlty = reverseQualityChoices[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogOthers end,
					default = qualityChoices[LootDrop_Defaults.chat.DbgLogOthersQlty],
					},
			[8] = {
					type = "dropdown",
					name = L.GroupNameFormat,
					tooltip = L.GroupNameFormatTip,
					choices = {LootDrop_sListBoxGroupChar, LootDrop_sListBoxGroupAcct, LootDrop_sListBoxGroupBoth},
					getFunc = function() 
						local values = {[0] = LootDrop_sListBoxGroupChar, [1] = LootDrop_sListBoxGroupAcct, [2] = LootDrop_sListBoxGroupBoth}
						local opt = self.db.chat.DbgLogGname
						if (opt ~= 0 and opt ~= 1 and opt ~=2) then opt = 0 end
						return values[opt]
					end,
					setFunc = function(valueString)
						local values = {[LootDrop_sListBoxGroupChar] = 0, [LootDrop_sListBoxGroupAcct] = 1, [LootDrop_sListBoxGroupBoth] = 2}
						self:ToggleGroupName(values[valueString])
					end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogOthers end,
					default = LootDrop_Defaults.chat.DbgLogGname
					},
			[9] = {
					type = "checkbox",
					name = L.LogGold,
					tooltip = L.LogGoldTip,
					getFunc = function() return self.db.chat.DbgLogGold end,
					setFunc = function(value) self:ToggleDbgLogGold(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogGold
					},
			[10] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogGold end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogGold = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogGold end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogGold",
					},
			[11] = {
					type = "checkbox",
					name = L.LogXP,
					tooltip = L.LogXPTip,
					getFunc = function() return self.db.chat.DbgLogXP end,
					setFunc = function(value) self:ToggleDbgLogXP(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogXP
					},
			[12] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogXP end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogXP = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogXP end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogXP",
					},
			[13] = {
					type = "checkbox",
					name = L.LogAP,
					tooltip = L.LogAPTip,
					getFunc = function() return self.db.chat.DbgLogAP end,
					setFunc = function(value) self:ToggleDbgLogAP(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogAP
					},
			[14] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogAP end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogAP = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogAP end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogAP",
					},
			[15] = {
					type = "checkbox",
					name = L.ShowRPGain,
					tooltip = L.ShowRPGainTip,
					getFunc = function() return self.db.chat.DbgAWGain end,
					setFunc = function(value) self.db.chat.DbgAWGain = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogAP end,
					default = LootDrop_Defaults.chat.DbgAWGain
					},
			[16] = {
					type = "checkbox",
					name = L.ShowXPProgFull,
					tooltip = L.ShowXPProgFullTip,
					getFunc = function() return self.db.chat.DbgAWFull end,
					setFunc = function(value) self.db.chat.DbgAWFull = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogAP end,
					default = LootDrop_Defaults.chat.DbgAWFull
					},
			[17] = {
					type = "checkbox",
					name = L.ShowAPLevel,
					tooltip = L.ShowAPLevelTip,
					getFunc = function() return self.db.chat.DbgAWRank end,
					setFunc = function(value) self.db.chat.DbgAWRank = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogAP end,
					default = LootDrop_Defaults.chat.DbgAWRank
					},
			[18] = {
					type = "checkbox",
					name = L.LogVP,
					tooltip = L.LogVPTip,
					getFunc = function() return self.db.chat.DbgLogVP end,
					setFunc = function(value) self:ToggleDbgLogVP(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogVP
					},
			[19] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogVP end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogVP = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogVP end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogVP",
					},
			[20] = {
					type = "checkbox",
					name = L.ShowVPGain,
					tooltip = L.ShowVPGainTip,
					getFunc = function() return self.db.chat.DbgVPGain end,
					setFunc = function(value) self.db.chat.DbgVPGain = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogVP end,
					default = LootDrop_Defaults.chat.DbgVPGain
					},
			[21] = {
					type = "checkbox",
					name = L.ShowXPProgFull,
					tooltip = L.ShowXPProgFullTip,
					getFunc = function() return self.db.chat.DbgVPFull end,
					setFunc = function(value) self.db.chat.DbgVPFull = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogVP end,
					default = LootDrop_Defaults.chat.DbgVPFull
					},
			[22] = {
					type = "checkbox",
					name = L.ShowVPLevel,
					tooltip = L.ShowVPLevelTip,
					getFunc = function() return self.db.chat.DbgVPRank end,
					setFunc = function(value) self.db.chat.DbgVPRank = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogVP end,
					default = LootDrop_Defaults.chat.DbgVPRank
					},
			[19] = {
					type = "checkbox",
					name = L.CAchievements,
					tooltip = L.CAchievementsTip,
					getFunc = function() return self.db.chat.DbgCAchievements end,
					setFunc = function(value) self:ToggleDbgLogCAchieve(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgCAchievements
					},
			[20] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgCAchievements end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgCAchievements = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgCAchievements end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgCAchievements",
					},
			[21] = {
					type = "checkbox",
					name = L.PAchievements,
					tooltip = L.PAchievementsTip,
					getFunc = function() return self.db.chat.DbgPAchievements end,
					setFunc = function(value) self:ToggleDbgLogPAchieve(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgPAchievements
					},
			[22] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgPAchievements end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgPAchievements = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgPAchievements end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgPAchievements",
					},
			[23] = {
					type = "checkbox",
					name = L.AchChatBrackets,
					tooltip = L.AchChatBracketsTip,
					getFunc = function() return self.db.chat.DbgShowAchBrackets end,
					setFunc = function(value) self.db.chat.DbgShowAchBrackets = value end,
					width = "half",
					disabled = function() return (not self.db.chat.DbgCAchievements) and (not self.db.chat.DbgPAchievements) end,
					default = LootDrop_Defaults.chat.DbgShowAchBrackets
					},
			[24] = {
					type = "custom",
					width = "half",
					},
			[25] = {
					type = "checkbox",
					name = L.LogTelvar,
					tooltip = L.LogTelvarTip,
					getFunc = function() return self.db.chat.DbgLogTelvar end,
					setFunc = function(value) self:ToggleDbgLogTelvar(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogTelvar
					},
			[26] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogTelvar end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogTelvar = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogTelvar end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogTelvar",
					},
			[27] = {
					type = "checkbox",
					name = L.LogWritVoucher,
					tooltip = L.LogWritVoucherTip,
					getFunc = function() return self.db.chat.DbgLogWritVoucher end,
					setFunc = function(value) self:ToggleDbgLogWritVoucher(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogWritVoucher
					},
			[28] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogWritVoucher end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogWritVoucher = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogWritVoucher end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogWritVoucher",
					},
			[29] = {
					type = "checkbox",
					name = L.LogUndauntedKey,
					tooltip = L.LogUndauntedKeyTip,
					getFunc = function() return self.db.chat.DbgLogUndauntedKey end,
					setFunc = function(value)
						self.db.chat.DbgLogUndauntedKey = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogUndauntedKey
					},
			[30] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogUndauntedKey end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogUndauntedKey = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogUndauntedKey end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogUndauntedKey",
					},
			[31] = {
					type = "checkbox",
					name = L.LogTransmuteCrystal,
					tooltip = L.LogTransmuteCrystalTip,
					getFunc = function() return self.db.chat.DbgLogTransmuteCrystal end,
					setFunc = function(value)
						self.db.chat.DbgLogTransmuteCrystal = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogTransmuteCrystal
					},
			[32] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogTransmuteCrystal end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogTransmuteCrystal = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogTransmuteCrystal end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogTransmuteCrystal",
					},
			[33] = {
					type = "checkbox",
					name = L.LogEventTicket,
					tooltip = L.LogEventTicketTip,
					getFunc = function() return self.db.chat.DbgLogEventTicket end,
					setFunc = function(value)
						self.db.chat.DbgLogEventTicket = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogEventTicket
					},
			[34] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogEventTicket end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogEventTicket = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogEventTicket end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogEventTicket",
					},
			[35] = {
					type = "checkbox",
					name = L.LogEndeavor,
					tooltip = L.LogEndeavorTip,
					getFunc = function() return self.db.chat.DbgLogEndeavor end,
					setFunc = function(value)
						self.db.chat.DbgLogEndeavor = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogEndeavor
					},
			[36] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogEndeavor end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogEndeavor = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogEndeavor end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogEndeavor",
					},
			[37] = {
					type = "checkbox",
					name = L.LogEndless,
					tooltip = L.LogEndlessTip,
					getFunc = function() return self.db.chat.DbgLogEndless end,
					setFunc = function(value)
						self.db.chat.DbgLogEndless = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogEndless
					},
			[38] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogEndless end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogEndless = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogEndless end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogEndless",
					},
					
					
			[39] = {
					type = "checkbox",
					name = L.LogFragments,
					tooltip = L.LogFragmentsTip,
					getFunc = function() return self.db.chat.DbgLogFragments end,
					setFunc = function(value)
						self.db.chat.DbgLogFragments = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogFragments
					},
			[40] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogFragments end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogFragments = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogFragments end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogFragments",
					},
					
			[41] = {
					type = "checkbox",
					name = L.LogTomePoints,
					tooltip = L.LogTomePointsTip,
					getFunc = function() return self.db.chat.DbgLogTomePoints end,
					setFunc = function(value)
						self.db.chat.DbgLogTomePoints = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogTomePoints
					},
			[42] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogTomePoints end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogTomePoints = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogTomePoints end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogTomePoints",
					},
			[43] = {
					type = "checkbox",
					name = L.LogTomePointCaches,
					tooltip = L.LogTomePointCachesTip,
					getFunc = function() return self.db.chat.DbgLogTomePointCaches end,
					setFunc = function(value)
						self.db.chat.DbgLogTomePointCaches = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogTomePointCaches
					},
			[44] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogTomePointCaches end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogTomePointCaches = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogTomePointCaches end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogTomePointCaches",
					},
			[45] = {
					type = "checkbox",
					name = L.LogTomeTokens,
					tooltip = L.LogTomeTokensTip,
					getFunc = function() return self.db.chat.DbgLogTomeTokens end,
					setFunc = function(value)
						self.db.chat.DbgLogTomeTokens = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogTomeTokens
					},
			[46] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogTomeTokens end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogTomeTokens = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogTomeTokens end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogTomeTokens",
					},
			[47] = {
					type = "checkbox",
					name = L.LogTradeBars,
					tooltip = L.LogTradeBarsTip,
					getFunc = function() return self.db.chat.DbgLogTradeBars end,
					setFunc = function(value)
						self.db.chat.DbgLogTradeBars = value
						self:ToggleDbgLogAccount()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogTradeBars
					},
			[48] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogTradeBars end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogTradeBars = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogTradeBars end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogTradeBars",
					},
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
			[49] = {
					type = "checkbox",
					name = L.LogCompanionXP,
					tooltip = L.LogCompanionXPTip,
					getFunc = function() return self.db.chat.DbgLogCXp end,
					setFunc = function(value) self:ToggleDbgLogCXp(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogCXp
					},
			[50] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogCXp end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogCXp = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogCXp end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogCXp",
					},
			[51] = {
					type = "checkbox",
					name = L.LogCompanionRapport,
					tooltip = L.LogCompanionRapportTip,
					getFunc = function() return self.db.chat.DbgLogCRpt end,
					setFunc = function(value) self:ToggleDbgLogRapport(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogCRpt
					},
			[52] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogCRpt end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogCRpt = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogCRpt end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogCRpt",
					},
			[53] = {
					type = "checkbox",
					name = L.LogRapportDesc,
					tooltip = L.LogRapportDescTip,
					getFunc = function() return self.db.chat.DbgLogCRptDesc end,
					setFunc = function(value) self.db.chat.DbgLogCRptDesc = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogCRpt end,
					default = LootDrop_Defaults.chat.DbgLogCRptDesc
					},
			[54] = {
					type = "checkbox",
					name = L.ShowXPProgFull,
					tooltip = L.ExtendedRapportTip,
					getFunc = function() return self.db.chat.DbgLogCRptExt end,
					setFunc = function(value) self.db.chat.DbgLogCRptExt = value end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogCRpt end,
					default = LootDrop_Defaults.chat.DbgLogCRptExt
					},
			[55] = {
					type = "checkbox",
					name = L.LogCraftXP,
					tooltip = L.LogCraftXPTip,
					getFunc = function() return self.db.chat.DbgLogCraftXP end,
					setFunc = function(value)
						self.db.chat.DbgLogCraftXP = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogCraftXP
					},
			[56] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogCraftXP end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogCraftXP = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogCraftXP end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogCraftXP",
					},
			[57] = {
					type = "checkbox",
					name = L.LogFenceXP,
					tooltip = L.LogFenceXPTip,
					getFunc = function() return self.db.chat.DbgLogFenceXP end,
					setFunc = function(value)
						self.db.chat.DbgLogFenceXP = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogFenceXP
					},
			[58] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogFenceXP end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogFenceXP = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogFenceXP end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogFenceXP",
					},
			[59] = {
					type = "checkbox",
					name = L.LogBookKnowledge,
					tooltip = L.LogBookKnowledgeTip,
					getFunc = function() return self.db.chat.DbgLogBookKnowledge end,
					setFunc = function(value)
						self.db.chat.DbgLogBookKnowledge = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogBookKnowledge
					},
			[60] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogBookKnowledge end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogBookKnowledge = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogBookKnowledge end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogBookKnowledge",
					},
			[61] = {
					type = "checkbox",
					name = L.LogBookLoot,
					tooltip = L.LogBookLootTip,
					getFunc = function() return self.db.chat.DbgLogBookLoot end,
					setFunc = function(value) self:ToggleDbgLogBookProgress(value) end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogBookLoot
					},
			[62] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogBookLoot end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogBookLoot = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogBookLoot end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogBookLoot",
					},
			[63] = {
					type = "checkbox",
					name = L.LogGuildRep,
					tooltip = L.LogGuildRepTip,
					getFunc = function() return self.db.chat.DbgLogGuildRep end,
					setFunc = function(value)
						self.db.chat.DbgLogGuildRep = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogGuildRep
					},
			[64] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogGuildRep end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogGuildRep = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogGuildRep end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogGuildRep",
					},
			[65] = {
					type = "checkbox",
					name = L.LogWeaponXP,
					tooltip = L.LogWeaponXPTip,
					getFunc = function() return self.db.chat.DbgLogWeapon end,
					setFunc = function(value)
						self.db.chat.DbgLogWeapon = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogWeapon
					},
			[66] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogWeapon end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogWeapon = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogWeapon end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogWeapon",
					},
			[67] = {
					type = "checkbox",
					name = L.LogArmorXP,
					tooltip = L.LogArmorXPTip,
					getFunc = function() return self.db.chat.DbgLogArmor end,
					setFunc = function(value)
						self.db.chat.DbgLogArmor = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogArmor
					},
			[68] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogArmor end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogArmor = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogArmor end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogArmor",
					},
			[69] = {
					type = "checkbox",
					name = L.LogWorldXP,
					tooltip = L.LogWorldXPTip,
					getFunc = function() return self.db.chat.DbgLogWorld end,
					setFunc = function(value)
						self.db.chat.DbgLogWorld = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogWorld
					},
			[70] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogWorld end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogWorld = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogWorld end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogWorld",
					},
			[71] = {
					type = "checkbox",
					name = L.LogAvAXP,
					tooltip = L.LogAvAXPTip,
					getFunc = function() return self.db.chat.DbgLogAvA end,
					setFunc = function(value)
						self.db.chat.DbgLogAvA = value
						self:ToggleDbgLogSkill()
					end,
					width = "half",
					default = LootDrop_Defaults.chat.DbgLogAvA
					},
			[72] = {
					type = "dropdown",
					name = L.SChatTabSelect,
					tooltip = L.SChatTabSelectTip,
					choices = chatTabs,
					getFunc = function() return self.db.chat.DbgLogTab.DbgLogAvA end,
					setFunc = function(choice) self.db.chat.DbgLogTab.DbgLogAvA = chatTabs[choice] end,
					width = "half",
					disabled = function() return not self.db.chat.DbgLogAvA end,
					default = chatTabs[1],
					reference = "DbgLogTab_DbgLogAvA",
					},
				},
			},
		------------CHAT LOG FILTERS--------------
		{
			type = 'submenu',
			name = L.ChatFilters,
			tooltip = '',
			controls = {
				[1] = {
					type = "checkbox",
					name = L.CLFiltering,
					tooltip = L.LWFilteringTip,
					getFunc = function() return self.db.CLFilters.CLFiltering end,
					setFunc = function(value) self.db.CLFilters.CLFiltering = value end,
					width = "full",
					default = LootDrop_Defaults.CLFilters.CLFiltering
					},
				[2] = { -- GENERAL LOOT
					type = 'submenu',
					name = L.GeneralFilters,
					tooltip = '',
					controls = {
						[1] = {
							type = "checkbox",
							name = L.FilterTools,
							getFunc = function() return self.db.CLFilters.FilterTools end,
							setFunc = function(value) self.db.CLFilters.FilterTools = value filterTable[ITEMTYPE_TOOL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterTools
							},
						[2] = {
							type = "checkbox",
							name = L.FilterSoulGems,
							getFunc = function() return self.db.CLFilters.FilterSoulGems end,
							setFunc = function(value) self.db.CLFilters.FilterSoulGems = value filterTable[ITEMTYPE_SOUL_GEM].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterSoulGems
							},
						[3] = {
							type = "checkbox",
							name = L.FilterTrash,
							getFunc = function() return self.db.CLFilters.FilterTrash end,
							setFunc = function(value) self.db.CLFilters.FilterTrash = value filterTable[ITEMTYPE_TRASH].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterTrash
							},
						[4] = {
							type = "checkbox",
							name = L.FilterTreasure,
							getFunc = function() return self.db.CLFilters.FilterTreasure end,
							setFunc = function(value) self.db.CLFilters.FilterTreasure = value filterTable[ITEMTYPE_TREASURE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterTreasure
							},
						[5] = {
							type = "checkbox",
							name = L.FilterWGlyphs,
							getFunc = function() return self.db.CLFilters.FilterWGlyphs end,
							setFunc = function(value) self.db.CLFilters.FilterWGlyphs = value filterTable[ITEMTYPE_GLYPH_WEAPON].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterWGlyphs
							},
						[6] = {
							type = "checkbox",
							name = L.FilterAGlyphs,
							getFunc = function() return self.db.CLFilters.FilterAGlyphs end,
							setFunc = function(value) self.db.CLFilters.FilterAGlyphs = value filterTable[ITEMTYPE_GLYPH_ARMOR].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterAGlyphs
							},
						[7] = {
							type = "checkbox",
							name = L.FilterJGlyphs,
							getFunc = function() return self.db.CLFilters.FilterJGlyphs end,
							setFunc = function(value) self.db.CLFilters.FilterJGlyphs = value filterTable[ITEMTYPE_GLYPH_JEWELRY].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterJGlyphs
							},
						[8] = {
							type = "dropdown",
							name = L.FilterGlyphQ,
							tooltip = L.FilterGlyphQTip,
							choices = qualityChoices0,
							getFunc = function() return qualityChoices0[self.db.CLFilters.FilterGlyphQuality + 1] end,
							setFunc = function(choice) self.db.CLFilters.FilterGlyphQuality = reverseQualityChoices0[choice] - 1 end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or ((self.db.CLFilters.FilterWGlyphs) and (self.db.CLFilters.FilterAGlyphs) and (self.db.CLFilters.FilterJGlyphs)) end,
							default = qualityChoices0[LootDrop_Defaults.CLFilters.FilterGlyphQuality],
							},
						[9] = {
							type = "checkbox",
							name = L.FilterFurniture,
							getFunc = function() return self.db.CLFilters.FilterFurniture end,
							setFunc = function(value) self.db.CLFilters.FilterFurniture = value filterTable[ITEMTYPE_FURNISHING].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterFurniture
							},
						[10] = {
							type = "checkbox",
							name = L.FilterRecall,
							getFunc = function() return self.db.CLFilters.FilterRecall end,
							setFunc = function(value) self.db.CLFilters.FilterRecall = value filterTable[ITEMTYPE_RECALL_STONE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterRecall
							},
						[11] = {
							type = "checkbox",
							name = L.FilterSiege,
							getFunc = function() return self.db.CLFilters.FilterSiege end,
							setFunc = function(value) self.db.CLFilters.FilterSiege = value filterTable[ITEMTYPE_SIEGE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterSiege
							},
						[12] = {
							type = "checkbox",
							name = L.FilterAVARepair,
							getFunc = function() return self.db.CLFilters.FilterAVARepair end,
							setFunc = function(value) self.db.CLFilters.FilterAVARepair = value filterTable[ITEMTYPE_AVA_REPAIR].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterAVARepair
							},
						[13] = {
							type = "checkbox",
							name = L.FilterTrophies,
							getFunc = function() return self.db.CLFilters.FilterTrophies end,
							setFunc = function(value) self.db.CLFilters.FilterTrophies = value filterTable[ITEMTYPE_TROPHY].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterTrophies
							},
						[14] = {
							type = "checkbox",
							name = L.FilterCollectibles,
							getFunc = function() return self.db.CLFilters.FilterCollectibles end,
							setFunc = function(value) self.db.CLFilters.FilterCollectibles = value filterTable[ITEMTYPE_COLLECTIBLE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterCollectibles
							},
						[15] = {
							type = "checkbox",
							name = L.FilterContainers,
							getFunc = function() return self.db.CLFilters.FilterContainers end,
							setFunc = function(value) self.db.CLFilters.FilterContainers = value filterTable[ITEMTYPE_CONTAINER].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterContainers
							},
						[16] = {
							type = "checkbox",
							name = L.FilterCContainers,
							getFunc = function() return self.db.CLFilters.FilterCContainers end,
							setFunc = function(value) self.db.CLFilters.FilterCContainers = value filterTable[ITEMTYPE_CONTAINER_CURRENCY].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterCContainers
							},
						[17] = {
							type = "checkbox",
							name = L.FilterCostumes,
							getFunc = function() return self.db.CLFilters.FilterCostumes end,
							setFunc = function(value) self.db.CLFilters.FilterCostumes = value filterTable[ITEMTYPE_COSTUME].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterCostumes
							},
						[18] = {
							type = "checkbox",
							name = L.FilterDisguise,
							getFunc = function() return self.db.CLFilters.FilterDisguise end,
							setFunc = function(value) self.db.CLFilters.FilterDisguise = value filterTable[ITEMTYPE_DISGUISE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterDisguise
							},
						[19] = {
							type = "checkbox",
							name = L.FilterCrownItems,
							getFunc = function() return self.db.CLFilters.FilterCrownItems end,
							setFunc = function(value) self.db.CLFilters.FilterCrownItems = value filterTable[ITEMTYPE_CROWN_ITEM].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterCrownItems
							},
						[20] = {
							type = "checkbox",
							name = L.FilterCrownRepair,
							getFunc = function() return self.db.CLFilters.FilterCrownRepair end,
							setFunc = function(value) self.db.CLFilters.FilterCrownRepair = value filterTable[ITEMTYPE_CROWN_REPAIR].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterCrownRepair
							},
						},
					},
				[3] = { -- CONSUMABLES
					type = 'submenu',
					name = L.ConsumableFilters,
					tooltip = '',
					controls = {
						[1] = {
							type = "checkbox",
							name = L.FilterFood,
							getFunc = function() return self.db.CLFilters.FilterFood end,
							setFunc = function(value) self.db.CLFilters.FilterFood = value filterTable[ITEMTYPE_FOOD].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterFood
							},
						[2] = {
							type = "checkbox",
							name = L.FilterDrink,
							getFunc = function() return self.db.CLFilters.FilterDrink end,
							setFunc = function(value) self.db.CLFilters.FilterDrink = value filterTable[ITEMTYPE_DRINK].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterDrink
							},
						[3] = {
							type = "checkbox",
							name = L.FilterPotion,
							getFunc = function() return self.db.CLFilters.FilterPotion end,
							setFunc = function(value) self.db.CLFilters.FilterPotion = value filterTable[ITEMTYPE_POTION].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterPotion
							},
						[4] = {
							type = "checkbox",
							name = L.FilterPoison,
							getFunc = function() return self.db.CLFilters.FilterPoison end,
							setFunc = function(value) self.db.CLFilters.FilterPoison = value filterTable[ITEMTYPE_POISON].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterPoison
							},
						[5] = {
							type = "checkbox",
							name = L.FilterPlayerPotion,
							tooltip = L.FilterPlayerPotionTip,
							getFunc = function() return self.db.CLFilters.FilterPlayerPotion end,
							setFunc = function(value) self.db.CLFilters.FilterPlayerPotion = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterPlayerPotion
							},
						[6] = {
							type = "custom",
							width = "half",
							},
						[7] = {
							type = "checkbox",
							name = L.FilterPotionBase,
							getFunc = function() return self.db.CLFilters.FilterPotionBase end,
							setFunc = function(value) self.db.CLFilters.FilterPotionBase = value filterTable[ITEMTYPE_POTION_BASE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterPotionBase
							},
						[8] = {
							type = "checkbox",
							name = L.FilterPoisonBase,
							getFunc = function() return self.db.CLFilters.FilterPoisonBase end,
							setFunc = function(value) self.db.CLFilters.FilterPoisonBase = value filterTable[ITEMTYPE_POISON_BASE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterPoisonBase
							},

						[9] = {
							type = "checkbox",
							name = L.FilterFish,
							getFunc = function() return self.db.CLFilters.FilterFish end,
							setFunc = function(value) self.db.CLFilters.FilterFish = value filterTable[ITEMTYPE_FISH].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterFish
							},
						[10] = {
							type = "checkbox",
							name = L.FilterBait,
							getFunc = function() return self.db.CLFilters.FilterBait end,
							setFunc = function(value) self.db.CLFilters.FilterBait = value filterTable[ITEMTYPE_LURE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterBait
							},
						},
					},
				[4] = { -- CRAFTING
					type = 'submenu',
					name = L.CraftingFilters,
					tooltip = '',
					controls = {
						[1] = {
							type = "checkbox",
							name = L.FilterIngredients,
							getFunc = function() return self.db.CLFilters.FilterIngredients end,
							setFunc = function(value) self.db.CLFilters.FilterIngredients = value filterTable[ITEMTYPE_INGREDIENT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterIngredients
							},
						[2] = {
							type = "dropdown",
							name = L.FilterIngQ,
							tooltip = L.FilterIngQTip,
							choices = qualityChoices0,
							getFunc = function() return qualityChoices0[self.db.CLFilters.FilterIngQuality + 1] end,
							setFunc = function(choice) self.db.CLFilters.FilterIngQuality = reverseQualityChoices0[choice] - 1 end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterIngredients) end,
							default = qualityChoices0[LootDrop_Defaults.CLFilters.FilterIngQuality],
							},
						[3] = {
							type = "checkbox",
							name = L.FilterRecipes,
							getFunc = function() return self.db.CLFilters.FilterRecipes end,
							setFunc = function(value) self.db.CLFilters.FilterRecipes = value filterTable[ITEMTYPE_RECIPE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterRecipes
							},
						[4] = {
							type = "dropdown",
							name = L.FilterRecipeQ,
							tooltip = L.FilterRecipeQTip,
							choices = qualityChoices0,
							getFunc = function() return qualityChoices0[self.db.CLFilters.FilterRecipeQuality + 1] end,
							setFunc = function(choice) self.db.CLFilters.FilterRecipeQuality = reverseQualityChoices0[choice] - 1 end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterRecipes) end,
							default = qualityChoices0[LootDrop_Defaults.CLFilters.FilterRecipeQuality],
							},
						[5] = {
							type = "checkbox",
							name = L.FilterReagents,
							getFunc = function() return self.db.CLFilters.FilterReagents end,
							setFunc = function(value) self.db.CLFilters.FilterReagents = value filterTable[ITEMTYPE_REAGENT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterReagents
							},
						[6] = {
							type = "checkbox",
							name = L.FilterMasterWRits,
							getFunc = function() return self.db.CLFilters.FilterMasterWRits end,
							setFunc = function(value) self.db.CLFilters.FilterMasterWRits = value filterTable[ITEMTYPE_MASTER_WRIT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterMasterWRits
							},
						[7] = {
							type = "checkbox",
							name = L.FilterWTrait,
							getFunc = function() return self.db.CLFilters.FilterWTrait end,
							setFunc = function(value) self.db.CLFilters.FilterWTrait = value filterTable[ITEMTYPE_WEAPON_TRAIT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterWTrait
							},
						[8] = {
							type = "checkbox",
							name = L.FilterATrait,
							getFunc = function() return self.db.CLFilters.FilterATrait end,
							setFunc = function(value) self.db.CLFilters.FilterATrait = value filterTable[ITEMTYPE_ARMOR_TRAIT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterATrait
							},
						[9] = {
							type = "checkbox",
							name = L.FilterFurnMats,
							getFunc = function() return self.db.CLFilters.FilterFurnMats end,
							setFunc = function(value) self.db.CLFilters.FilterFurnMats = value filterTable[ITEMTYPE_FURNISHING_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterFurnMats
							},
						[10] = {
							type = "checkbox",
							name = L.FilterStyleMats,
							getFunc = function() return self.db.CLFilters.FilterStyleMats end,
							setFunc = function(value) self.db.CLFilters.FilterStyleMats = value filterTable[ITEMTYPE_STYLE_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterStyleMats
							},
						[11] = {
							type = "checkbox",
							name = L.FilterCompMats,
							getFunc = function() return self.db.CLFilters.FilterCompMats end,
							setFunc = function(value) self.db.CLFilters.FilterCompMats = value filterTable[ITEMTYPE_RAW_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterCompMats
							},
						[12] = {
							type = "checkbox",
							name = L.FilterMotif,
							getFunc = function() return self.db.CLFilters.FilterMotif end,
							setFunc = function(value) self.db.CLFilters.FilterMotif = value filterTable[ITEMTYPE_RACIAL_STYLE_MOTIF].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterMotif
							},
						[13] = {
							type = "header",
							name = L.FilterCraftingMats,
							},
						[14] = {
							type = "checkbox",
							name = L.FilterERune,
							getFunc = function() return self.db.CLFilters.FilterERune end,
							setFunc = function(value) self.db.CLFilters.FilterERune = value filterTable[ITEMTYPE_ENCHANTING_RUNE_ESSENCE].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterERune
							},
						[15] = {
							type = "checkbox",
							name = L.FilterPRune,
							getFunc = function() return self.db.CLFilters.FilterPRune end,
							setFunc = function(value) self.db.CLFilters.FilterPRune = value filterTable[ITEMTYPE_ENCHANTING_RUNE_POTENCY].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterPRune
							},
						[16] = {
							type = "checkbox",
							name = L.FilterARune,
							getFunc = function() return self.db.CLFilters.FilterARune end,
							setFunc = function(value) self.db.CLFilters.FilterARune = value filterTable[ITEMTYPE_ENCHANTING_RUNE_ASPECT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterARune
							},
						[17] = {
							type = "dropdown",
							name = L.FilterARuneQ,
							tooltip = L.FilterARuneQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.CLFilters.FilterARuneQ] end,
							setFunc = function(choice) self.db.CLFilters.FilterARuneQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterARune) end,
							default = qualityChoices[LootDrop_Defaults.CLFilters.FilterARuneQ],
							},
						[18] = {
							type = "checkbox",
							name = L.FilterBSMats,
							getFunc = function() return self.db.CLFilters.FilterBSMats end,
							setFunc = function(value) self.db.CLFilters.FilterBSMats = value filterTable[ITEMTYPE_BLACKSMITHING_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterBSMats
							},
						[19] = {
							type = "checkbox",
							name = L.FilterBSRawMats,
							getFunc = function() return self.db.CLFilters.FilterBSRawMats end,
							setFunc = function(value) self.db.CLFilters.FilterBSRawMats = value filterTable[ITEMTYPE_BLACKSMITHING_RAW_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterBSRawMats
							},
						[20] = {
							type = "checkbox",
							name = L.FilterBSImprove,
							getFunc = function() return self.db.CLFilters.FilterBSImprove end,
							setFunc = function(value) self.db.CLFilters.FilterBSImprove = value filterTable[ITEMTYPE_BLACKSMITHING_BOOSTER].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterBSImprove
							},
						[21] = {
							type = "dropdown",
							name = L.FilterBSImproveQ,
							tooltip = L.FilterBSImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.CLFilters.FilterBSImproveQ] end,
							setFunc = function(choice) self.db.CLFilters.FilterBSImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterBSImprove) end,
							default = qualityChoices[LootDrop_Defaults.CLFilters.FilterBSImproveQ],
							},
						[22] = {
							type = "checkbox",
							name = L.FilterClothMats,
							getFunc = function() return self.db.CLFilters.FilterClothMats end,
							setFunc = function(value) self.db.CLFilters.FilterClothMats = value filterTable[ITEMTYPE_CLOTHIER_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterClothMats
							},
						[23] = {
							type = "checkbox",
							name = L.FilterClothRawMats,
							getFunc = function() return self.db.CLFilters.FilterClothRawMats end,
							setFunc = function(value) self.db.CLFilters.FilterClothRawMats = value filterTable[ITEMTYPE_CLOTHIER_RAW_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterClothRawMats
							},
						[24] = {
							type = "checkbox",
							name = L.FilterClothImprove,
							getFunc = function() return self.db.CLFilters.FilterClothImprove end,
							setFunc = function(value) self.db.CLFilters.FilterClothImprove = value filterTable[ITEMTYPE_CLOTHIER_BOOSTER].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterClothImprove
							},
						[25] = {
							type = "dropdown",
							name = L.FilterClothImproveQ,
							tooltip = L.FilterClothImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.CLFilters.FilterClothImproveQ] end,
							setFunc = function(choice) self.db.CLFilters.FilterClothImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterClothImprove) end,
							default = qualityChoices[LootDrop_Defaults.CLFilters.FilterClothImproveQ],
							},
						[26] = {
							type = "checkbox",
							name = L.FilterWoodMats,
							getFunc = function() return self.db.CLFilters.FilterWoodMats end,
							setFunc = function(value) self.db.CLFilters.FilterWoodMats = value filterTable[ITEMTYPE_WOODWORKING_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterWoodMats
							},
						[27] = {
							type = "checkbox",
							name = L.FilterWoodRawMats,
							getFunc = function() return self.db.CLFilters.FilterWoodRawMats end,
							setFunc = function(value) self.db.CLFilters.FilterWoodRawMats = value filterTable[ITEMTYPE_WOODWORKING_RAW_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterWoodRawMats
							},
						[28] = {
							type = "checkbox",
							name = L.FilterWoodImprove,
							getFunc = function() return self.db.CLFilters.FilterWoodImprove end,
							setFunc = function(value) self.db.CLFilters.FilterWoodImprove = value filterTable[ITEMTYPE_WOODWORKING_BOOSTER].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterWoodImprove
							},
						[29] = {
							type = "dropdown",
							name = L.FilterWoodImproveQ,
							tooltip = L.FilterWoodImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.CLFilters.FilterWoodImproveQ] end,
							setFunc = function(choice) self.db.CLFilters.FilterWoodImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterWoodImprove) end,
							default = qualityChoices[LootDrop_Defaults.CLFilters.FilterWoodImproveQ],
							},
						[30] = {
							type = "checkbox",
							name = L.FilterJCMats,
							getFunc = function() return self.db.CLFilters.FilterJCMats end,
							setFunc = function(value) self.db.CLFilters.FilterJCMats = value filterTable[ITEMTYPE_JEWELRYCRAFTING_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterJCMats
							},
						[31] = {
							type = "checkbox",
							name = L.FilterJCRawMats,
							getFunc = function() return self.db.CLFilters.FilterJCRawMats end,
							setFunc = function(value) self.db.CLFilters.FilterJCRawMats = value filterTable[ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterJCRawMats
							},
						[32] = {
							type = "checkbox",
							name = L.FilterJCTrait,
							getFunc = function() return self.db.CLFilters.FilterJCTrait end,
							setFunc = function(value) self.db.CLFilters.FilterJCTrait = value filterTable[ITEMTYPE_JEWELRY_TRAIT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterJCTrait
							},
						[33] = {
							type = "checkbox",
							name = L.FilterJCRawTrait,
							getFunc = function() return self.db.CLFilters.FilterJCRawTrait end,
							setFunc = function(value) self.db.CLFilters.FilterJCRawTrait = value filterTable[ITEMTYPE_JEWELRY_RAW_TRAIT].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterJCRawTrait
							},
						[34] = {
							type = "checkbox",
							name = L.FilterJCImprove,
							getFunc = function() return self.db.CLFilters.FilterJCImprove end,
							setFunc = function(value) self.db.CLFilters.FilterJCImprove = value filterTable[ITEMTYPE_JEWELRYCRAFTING_BOOSTER].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterJCImprove
							},
						[35] = {
							type = "checkbox",
							name = L.FilterJCRawImprove,
							getFunc = function() return self.db.CLFilters.FilterJCRawImprove end,
							setFunc = function(value) self.db.CLFilters.FilterJCRawImprove = value filterTable[ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER].CL = value end,
							width = "half",
							disabled = function() return not self.db.CLFilters.CLFiltering end,
							default = LootDrop_Defaults.CLFilters.FilterJCRawImprove
							},
						[36] = {
							type = "dropdown",
							name = L.FilterJCImproveQ,
							tooltip = L.FilterJCImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.CLFilters.FilterJCImproveQ] end,
							setFunc = function(choice) self.db.CLFilters.FilterJCImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterJCImprove) end,
							default = qualityChoices[LootDrop_Defaults.CLFilters.FilterJCImproveQ],
							},
						[37] = {
							type = "dropdown",
							name = L.FilterJCRImproveQ,
							tooltip = L.FilterJCRImproveQTip,
							choices = qualityChoices,
							getFunc = function() return qualityChoices[self.db.CLFilters.FilterJCRImproveQ] end,
							setFunc = function(choice) self.db.CLFilters.FilterJCRImproveQ = reverseQualityChoices[choice] end,
							width = "half",
							disabled = function() return (not self.db.CLFilters.CLFiltering) or (self.db.CLFilters.FilterJCRawImprove) end,
							default = qualityChoices[LootDrop_Defaults.CLFilters.FilterJCRImproveQ],
							},
						},
					},
				},
			},
		------------DIM & STYLE--------------
		{
			type = 'submenu',
			name = L.DimStyleHeader,
			tooltip = '',
			controls = {
			[1] = {
					type = "header",
					name = L.LootAppearance,
					},
			[2] = {
					type = "slider",
					name = L.DisplayDuration,
					tooltip = L.DisplayDurationTip,
					min = 1,
					max = 30,
					step = 1,
					getFunc = function() return self.db.display.dDuration end,
					setFunc = function(value) self.db.display.dDuration = value end,
					width = "half",
					default = LootDrop_Defaults.display.dDuration
					},
			[3] = {
					type = "slider",
					name = L.Width,
					tooltip = L.WidthTip,
					min = 100,
					max = 500,
					step = 1,
					getFunc = function() return self.db.display.width end,
					setFunc = function(value) self:ChangeWidth(value) end,
					width = "half",
					default = LootDrop_Defaults.display.width
					},
			[4] = {
					type = "slider",
					name = L.Height,
					tooltip = L.HeightTip,
					min = 25,
					max = 100,
					step = 1,
					getFunc = function() return self.db.display.height end,
					setFunc = function(value) self:ChangeHeight(value) end,
					width = "half",
					default = LootDrop_Defaults.display.height
					},
			[5] = {
					type = "slider",
					name = L.Padding,
					tooltip = L.PaddingTip,
					min = 0,
					max = 25,
					step = 1,
					getFunc = function() return self.db.display.padding end,
					setFunc = function(value) self:ChangePadding(value) end,
					width = "half",
					default = LootDrop_Defaults.display.padding
					},
			[6] = {
					type = "slider",
					name = L.MaxStacks,
					tooltip = L.MaxStacksTip,
					min = 1,
					max = 50,
					step = 1,
					getFunc = function() return self.db.display.maxstacks end,
					setFunc = function(value) self:ChangeMaxStacks(value) end,
					width = "half",
					default = LootDrop_Defaults.display.maxstacks
					},
			[7] = {
					type = "slider",
					name = L.RemainingOffset,
					tooltip = L.RemainingOffsetTip,
					min = -500,
					max = 0,
					step = 1,
					getFunc = function() return self.db.display.hOffset end,
					setFunc = function(value) self.db.display.hOffset = value end,
					width = "half",
					default = LootDrop_Defaults.display.hOffset,
					disabled = function() return not self.db.display.showHidden end
					},
			[8] = {
					type = "checkbox",
					name = L.LootRemaining,
					tooltip = L.LootRemainingTip,
					getFunc = function() return self.db.display.showHidden end,
					setFunc = function(value) self.db.display.showHidden = value end,
					width = "full",
					default = LootDrop_Defaults.display.showHidden
					},
			[9] = {
					type = "checkbox",
					name = L.StackUp,
					tooltip = L.StackUpTip,
					getFunc = function() return self.db.display.moveUp end,
					setFunc = function(value) self:ToggleMoveUp(value) end,
					width = "full",
					default = LootDrop_Defaults.display.moveUp
					},
			[10] = {
					type = "checkbox",
					name = L.RarityBorder,
					tooltip = L.RarityBorderTip,
					getFunc = function() return self.db.display.rarity end,
					setFunc = function(value) self:ToggleRarity(value) end,
					width = "full",
					default = LootDrop_Defaults.display.rarity
					},
			[11] = {
					type = "dropdown",
					name = L.Style,
					tooltip = L.StyleTip,
					choices = {LootDrop_sDefDefault, LootDrop_sDefPawkette, LootDrop_sDefRushmik, LootDrop_sDefESOclassic},
					getFunc = function() return self.db.display.sListStyle end,
					setFunc = function(valueString) self:PickStyle(valueString) end,
					width = "full",
					default = LootDrop_Defaults.display.sListStyle
					},
			[12] = {
					type = "dropdown",
					name = L.BackgroundOverride,
					tooltip = L.BackgroundOverrideTip,
					choices = {"DEFAULT","/lootdrop/textures/flippedloothistorybg.dds", "/esoui/art/ava/ava_hud_bgframe.dds", "/esoui/art/progression/headerbg.dds", "/esoui/art/progression/list_header_bg.dds", "/esoui/art/contacts/social_list_bgstrip.dds", "/esoui/art/contacts/social_list_bgstrip_highlight.dds", "/esoui/art/voip/gamepad/gp_voip_namebg.dds", "/esoui/art/tradewindow/trade_itembg_left.dds", "/esoui/art/unitframes/unitframe_player.dds", "/lootdrop/textures/rushmik_bg.dds", "/lootdrop/textures/default_bg.dds", "/lootdrop/textures/ava_hud_bgframe_black.dds", "/lootdrop/textures/ava_hud_bgframe_grey.dds", "/lootdrop/textures/ava_hud_bgframe_white.dds",},
					getFunc = function() return self.db.display.customBG end,
					setFunc = function(valueString) self:SetCustomBgTexture(valueString) end, 
					width = "full",
					default = LootDrop_Defaults.display.customBG
					},
			[13] = {
					type = "slider",
					name = L.FontSize,
					tooltip = L.FontSizeTip,
					min = 10,
					max = 28,
					step = 1,
					getFunc = function() return self.db.display.fontSize end,
					setFunc = function(value) self:ChangeFontSize(value) end,
					width = "full",
					default = LootDrop_Defaults.display.fontSize
					},
			[14] = {
					type = "checkbox",
					name = L.EnableGlobalFont,
					tooltip = L.EnableGlobalFontTip,
					getFunc = function() return self.db.display.customFontE end,
					setFunc = function(v) self.db.display.customFontE = v end,
					width = "full",
					default = LootDrop_Defaults.display.customFontE
					},
			[15] = {
					type = 'dropdown',
					name = L.GlobalFont,
					choices = LMP:List('font'),
					getFunc = function() return self.db.display.customFontG end,
					setFunc = function(v) self.db.display.customFontG = v end,
					disabled = function() return not self.db.display.customFontE end,
					scrollable = 7,
			},
			[16] = {
					type = "header",
					name = L.ChatAppearance,
					},
			[17] = {
					type = "checkbox",
					name = L.LogTimeStamp,
					tooltip = L.LogTimeStampTip,
					getFunc = function() return self.db.display.DbgLogTime end,
					setFunc = function(value) self.db.display.DbgLogTime = value end,
					width = "full",
					disabled = function() return (not self.db.chat.DbgLogMine and not self.db.chat.DbgLogOthers) end,
					default = LootDrop_Defaults.display.DbgLogTime
					},
			[18] = {
					type = "checkbox",
					name = L.LogItemStyle,
					tooltip = L.LogItemStyleTip,
					getFunc = function() return self.db.display.DbgLogItemStyle end,
					setFunc = function(value) self.db.display.DbgLogItemStyle = value end,
					width = "full",
					disabled = function() return (not self.db.chat.DbgLogMine and not self.db.chat.DbgLogOthers) end,
					default = LootDrop_Defaults.display.DbgLogItemStyle
					},
			[19] = {
					type = "checkbox",
					name = L.LogItemTrait,
					tooltip = L.LogItemTraitTip,
					getFunc = function() return self.db.display.DbgLogItemTrait end,
					setFunc = function(value) self.db.display.DbgLogItemTrait = value end,
					width = "full",
					disabled = function() return (not self.db.chat.DbgLogMine and not self.db.chat.DbgLogOthers) end,
					default = LootDrop_Defaults.display.DbgLogItemTrait
					},
			[20] = {
					type = "checkbox",
					name = L.LogItemValue,
					tooltip = L.LogItemValueTip,
					getFunc = function() return self.db.display.DbgLogItemValue end,
					setFunc = function(value) self.db.display.DbgLogItemValue = value end,
					width = "full",
					disabled = function() return (not self.db.chat.DbgLogMine and not self.db.chat.DbgLogOthers) end,
					default = LootDrop_Defaults.display.DbgLogItemValue
					},
			[21] = {
					type = "checkbox",
					name = L.LogTag,
					tooltip = L.LogTagTip,
					getFunc = function() return self.db.display.DbgLogTag end,
					setFunc = function(value) self.db.display.DbgLogTag = value end,
					width = "full",
					disabled = function() return (not self.db.chat.DbgLogMine and not self.db.chat.DbgLogOthers) end,
					default = LootDrop_Defaults.display.DbgLogTag
					},
				},
			},
		------------VALUE OPTIONS--------------
		{
			type = 'submenu',
			name = L.ValueHeader,
			tooltip = '',
			controls = {
			[1] = {
					type = "dropdown",
					name = L.ValueLoot,
					tooltip = L.ValueLootTip,
					choices = {LootDrop_sListBoxValueNo, LootDrop_sListBoxValueVendor, LootDrop_sListBoxValueTrade, LootDrop_sListBoxValueVaT},
					getFunc = function() 
						local values = {[0] = LootDrop_sListBoxValueNo, [1] = LootDrop_sListBoxValueVendor, [2] = LootDrop_sListBoxValueTrade, [3] = LootDrop_sListBoxValueVaT}
						local opt = self.db.value.lootValue
						if opt ~= 0 and opt ~= 1 and opt ~=2 and opt ~= 3 then opt = 0 end
						return values[opt]
					end,
					setFunc = function(valueString)
						local values = {[LootDrop_sListBoxValueNo] = 0, [LootDrop_sListBoxValueVendor] = 1, [LootDrop_sListBoxValueTrade] = 2, [LootDrop_sListBoxValueVaT] = 3}
						self.db.value.lootValue = values[valueString] 
					end,
					width = "full",
					default = LootDrop_Defaults.value.lootValue
					},
			[2] = {
					type = "checkbox",
					name = L.StackVal,
					tooltip = L.StackValTip,
					getFunc = function() return self.db.value.stackVal end,
					setFunc = function(value) self.db.value.stackVal = value end,
					width = "full",
					disabled = function() return self.db.value.lootValue == 0 end,
					default = LootDrop_Defaults.value.stackVal
					},
			[3] = {
					type = "checkbox",
					name = L.NoData,
					tooltip = L.NoDataTip,
					getFunc = function() return self.db.value.noData end,
					setFunc = function(value) self.db.value.noData = value end,
					width = "full",
					disabled = function() return self.db.value.lootValue == 0 end,
					default = LootDrop_Defaults.value.noData
					},
			[4] = {
					type = "checkbox",
					name = L.NoDataVendor,
					tooltip = L.NoDataVendorTip,
					getFunc = function() return self.db.value.noDataVal end,
					setFunc = function(value) self.db.value.noDataVal = value end,
					width = "full",
					disabled = function() return self.db.value.lootValue ~= 2 end,
					default = LootDrop_Defaults.value.noDataVal
					},
			[5] = {
					type = "checkbox",
					name = L.ShowSeparator,
					tooltip = L.ShowSeparatorTip,
					getFunc = function() return self.db.value.valueSep end,
					setFunc = function(value) self.db.value.valueSep = value end,
					width = "full",
					disabled = function() return self.db.value.lootValue == 0 end,
					default = LootDrop_Defaults.value.valueSep
					},
			[6] = {
					type = "checkbox",
					name = L.ShowGGold,
					tooltip = L.ShowGGoldTip,
					getFunc = function() return self.db.value.goldSuff end,
					setFunc = function(value) self.db.value.goldSuff = value end,
					width = "full",
					disabled = function() return self.db.value.lootValue == 0 end,
					default = LootDrop_Defaults.value.goldSuff
					},
			[7] = {
					type = "header",
					name = L.ValueOptions,
					},
			[8] = {
					type = "checkbox",
					name = L.CurrencyDelim,
					tooltip = L.CurrencyDelimTip,
					getFunc = function() return self.db.value.cDelim end,
					setFunc = function(value) self.db.value.cDelim = value end,
					width = "full",
					disabled = function() return self.db.value.cTrunc end,
					default = LootDrop_Defaults.value.cDelim
					},
			[9] = {
					type = "checkbox",
					name = L.CurrencyTrunc,
					tooltip = L.CurrencyTruncTip,
					getFunc = function() return self.db.value.cTrunc end,
					setFunc = function(value) self.db.value.cTrunc = value end,
					width = "full",
					disabled = function() return self.db.value.cDelim end,
					default = LootDrop_Defaults.value.cTrunc
					},
			[10] = {
					type = "checkbox",
					name = L.CurrencyDot,
					tooltip = L.CurrencyDotTip,
					getFunc = function() return self.db.value.cDot end,
					setFunc = function(value) self.db.value.cDot = value end,
					width = "full",
					default = LootDrop_Defaults.value.cDot
					},
				},
			},
		------------LOCK/UNLOCK--------------
		{
			type = "header",
			name = L.LockUnlockHeader,
			width = "full",
		},
		{
			type = "button",
			name = L.LockUnlockButton,
			tooltip = L.LockUnlockButtonTip,
			func = function()
				if (IsPreviewPanel == 1) then IsPreviewPanel = 3 elseif (IsPreviewPanel == 3) then IsPreviewPanel = 1 end
				CBM:FireCallbacks( self.EVENT_TOGGLE_LOCK )
			end,
			width = "half",
		},
		{
			type = "button",
			name = L.PreviewMode,
			tooltip = L.PreviewModeTip,
			func = function()
				previewMode = (previewMode ~= 1) and 1 or 2
				self:TogglePreview()
			end,
			width = "half",
		},
	}

	LAM2:RegisterOptionControls(ADDON_NAME, optionsTable)

	CBM:RegisterCallback('LAM-PanelOpened', function(panel)
		if (panel ~= LootDropPanel) then return end
		IsPreviewPanel = 1
		previewMode = 1
		self.db.lootdrop_lock = false
		CBM:FireCallbacks( LootDropConfig.EVENT_SHOW_PREVIEW )
		LootDrop_LockUnlock()

		if LootDropPreview == nil then 
			LootDropPreview = WM:CreateControlFromVirtual('PreviewList', panel, 'ZO_StatsDropdownRow')
			LootDropPreview:SetWidth(300)
			LootDropPreview:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -42, -40)
			LootDropPreview:GetNamedChild('Dropdown'):SetWidth(295)
			for k, v in ipairs(opTable) do
				local entry = LootDropPreview.dropdown:CreateItemEntry(v, function(_, name)
					for i, n in pairs(opTable) do
						if n == name then
							if (previewMode == 1) then
								previewMode = i
								CBM:FireCallbacks( LootDropConfig.EVENT_SHOW_PREVIEW )
							else
								previewMode = i
							end
							break
						end
					end
				end)
				LootDropPreview.dropdown:AddItem(entry)
			end
		end
		LootDropPreview.dropdown:SetSelectedItem(L.SelectPreview) -- set the dropdown selected item to the current character
	end)

	CBM:RegisterCallback('LAM-PanelClosed', function(panel)
		if (panel ~= LootDropPanel) then return end
		self.db.lootdrop_lock = true
		previewMode = 1
		IsPreviewPanel = 2
		CBM:FireCallbacks( self.EVENT_TOGGLE_LOCK )
		CBM:FireCallbacks( self.EVENT_RESET_PREVIEW )
	end)

	CBM:RegisterCallback("LAM-PanelControlsCreated", function(panel) -- re-dock LAM widget tooltips to the right of addon settings (Phinix)
		if panel ~= LootDropPanel then return end
		local xOffset = 2
		local yOffset = -4
		local function PosthookTooltip(control)
			ZO_PostHookHandler(control, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, panel, TOPRIGHT, xOffset, yOffset)
			end)
		end
		local function SetWidgetTooltipHandler(control)
			if control.label ~= nil then PosthookTooltip(control.label) end
			if control.combobox ~= nil then PosthookTooltip(control.combobox) end
			if control.editbox ~= nil then PosthookTooltip(control.editbox) end
			if control.slider ~= nil then PosthookTooltip(control.slider) end
			if control.warning ~= nil then PosthookTooltip(control.warning) end
			if control.texture ~= nil then PosthookTooltip(control.texture) end
			if control.button ~= nil then PosthookTooltip(control.button) end
		end
		for _, widget in pairs(panel.controlsToRefresh) do
			PosthookTooltip(widget)
			SetWidgetTooltipHandler(widget)
		end
	end)
end
------------GENERAL--------------
function LootDropConfig:ToggleLoot(value)
    self.db.loot.showLoot = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_LOOT )
end
----------------------------------
function LootDropConfig:ToggleLootHistory(value)
    self.db.general.hideHistory = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_DEFAULT )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleMailLoot(value)
    self.db.loot.mailLoot = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_MAIL_LOOT )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleCoin(value)
    self.db.gold.showGold = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_COIN )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleXP(value)
    self.db.XP.showXP = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_XP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleAP(value)
    self.db.AP.showAP = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_AP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleVP(value)
    self.db.VP.showVP = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_VP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleTV(value)
    self.db.currency.showTelvar = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_TV )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleWVoucher(value)
    self.db.currency.showVoucher = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_WVOUCHER )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleAccount()
    CBM:FireCallbacks( self.EVENT_TOGGLE_ACCOUNT )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleCompanionXP(value)
    self.db.compXP.showXP = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_COMPANION_XP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleCompanionRapport(value)
    self.db.rapport.showRppt = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_COMPANION_RP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleAchievements()
    CBM:FireCallbacks( self.EVENT_TOGGLE_ACHIEVEMENTS )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleLootOptions()
    CBM:FireCallbacks( self.EVENT_TOGGLE_LOOT )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleJunk(value)
	self.db.general.junkTrash = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_JUNK )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleHideGUI(value)
	self.db.general.DbgHideGUI = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_HIDEGUI )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleHideChat(value)
	self.db.general.DbgHideChat = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_HIDECHAT )
end
--------------------------------------------------------------------------------
function LootDropConfig:ToggleHideMeters(value)
	self.db.general.hideMeters = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_HIDEMETERS )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleSkill()
	CBM:FireCallbacks( self.EVENT_TOGGLE_SKILL_XP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleBookLoot(value)
	self.db.loot.bookLoot = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_BOOK_LOOT )
end
-------------------------------------------------------------------------------
------------CHAT LOG--------------
function LootDropConfig:ToggleGroupName(value)
    self.db.chat.DbgLogGname = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_GROUP_NAME )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLog(value)
	self.db.chat.DbgLogMine = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_LOOT )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleOthersLog(value)
	self.db.chat.DbgLogOthers = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_LOOT )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogGold(value)
	self.db.chat.DbgLogGold = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_COIN )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogXP(value)
	self.db.chat.DbgLogXP = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_XP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogAP(value)
	self.db.chat.DbgLogAP = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_AP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogVP(value)
	self.db.chat.DbgLogVP = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_VP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogCAchieve(value)
	self.db.chat.DbgCAchievements = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_ACHIEVEMENTS )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogPAchieve(value)
	self.db.chat.DbgPAchievements = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_ACHIEVEMENTS )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogTelvar(value)
	self.db.chat.DbgLogTelvar = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_TV )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogWritVoucher(value)
	self.db.chat.DbgLogWritVoucher = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_WVOUCHER )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogAccount()
	CBM:FireCallbacks( self.EVENT_TOGGLE_ACCOUNT )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogCXp(value)
	self.db.chat.DbgLogCXp = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_COMPANION_XP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogRapport(value)
	self.db.chat.DbgLogCRpt = value
    CBM:FireCallbacks( self.EVENT_TOGGLE_COMPANION_RP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogSkill()
	CBM:FireCallbacks( self.EVENT_TOGGLE_SKILL_XP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleDbgLogBookProgress(value)
	self.db.chat.DbgLogBookLoot = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_BOOK_LOOT )
end
-------------------------------------------------------------------------------
------------DIM & STYLE--------------
function LootDropConfig:ChangeWidth(width)
	self.db.display.width = width
	CBM:FireCallbacks( self.EVENT_CHANGE_DIMENSIONS )
end
-------------------------------------------------------------------------------
function LootDropConfig:ChangeHeight(height)
	self.db.display.height = height
	CBM:FireCallbacks( self.EVENT_CHANGE_DIMENSIONS )
end
-------------------------------------------------------------------------------
function LootDropConfig:ChangeMaxStacks(maxstacks)
	self.db.display.maxstacks = maxstacks
	CBM:FireCallbacks( self.EVENT_CHANGE_MAXSTACKS )
end
-------------------------------------------------------------------------------
function LootDropConfig:TogglePreview()
	CBM:FireCallbacks( self.EVENT_SHOW_PREVIEW )
end
-------------------------------------------------------------------------------
function LootDropConfig:ChangePadding(padding)
	self.db.display.padding = padding
	CBM:FireCallbacks( self.EVENT_CHANGE_DIMENSIONS )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleMoveUp(value) 
	self.db.display.moveUp = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_MOVEUP )
end
-------------------------------------------------------------------------------
function LootDropConfig:ToggleRarity(value) 
	self.db.display.rarity = value
	CBM:FireCallbacks( self.EVENT_TOGGLE_RARITY )
end
-------------------------------------------------------------------------------
function LootDropConfig:PickStyle(sValue)
   self.db.display.sListStyle = sValue
   CBM:FireCallbacks( self.EVENT_TOGGLE_STYLE )
end
-------------------------------------------------------------------------------
function LootDropConfig:SetCustomBgTexture(sValue)
   self.db.display.customBG = sValue
end
-------------------------------------------------------------------------------
function LootDropConfig:ChangeFontSize(sValue)
   self.db.display.fontSize = sValue
   CBM:FireCallbacks( self.EVENT_TOGGLE_STYLE )
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called by bindings
function LootDrop_LockUnlock() -- objects & config cannot be called because of protection by the local vars, so using the global ref to access them.
	if (IsPreviewPanel == 0) then
		LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].lootdrop_lock = not LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].lootdrop_lock
	end
	CBM:FireCallbacks( LootDropConfig.EVENT_TOGGLE_LOCK )
end
-------------------------------------------------------------------------------
function LootDrop_ToggleAutoloot()

	local Setting = GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT)
	local Autolootinfo = ""

	if LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].DbgLogTime then
		Autolootinfo = "[" .. GetTimeString() .. "]:"
	end
	
	if (Setting == "1") then
		Setting = "0"
		CHAT_SYSTEM:AddMessage(Autolootinfo .. L.AutoLootOff)
	else
		Setting = "1"
		CHAT_SYSTEM:AddMessage(Autolootinfo .. L.AutoLootOn)
	end

	SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT, Setting, 1)
	
end
-------------------------------------------------------------------------------
function LootDrop_ToggleLootWindow()
	LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].general.DbgHideGUI = not LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].general.DbgHideGUI
	CBM:FireCallbacks( LootDropConfig.EVENT_TOGGLE_HIDEGUI )
end
-------------------------------------------------------------------------------
function LootDrop_ToggleChat()
	LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].general.DbgHideChat = not LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].general.DbgHideChat
	CBM:FireCallbacks( LootDropConfig.EVENT_TOGGLE_HIDECHAT )
end
-------------------------------------------------------------------------------
function LootDrop_TogglePreview()
	previewMode = (previewMode ~= 1) and 1 or 2
	CBM:FireCallbacks( LootDropConfig.EVENT_SHOW_PREVIEW )
end
-------------------------------------------------------------------------------
function LootDrop_LWFilter()
	LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].LWFilters.LWFiltering = not LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].LWFilters.LWFiltering
	if (LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].LWFilters.LWFiltering) then
		d(L.LWFilterOn)
	else
		d(L.LWFilterOff)
	end
end
-------------------------------------------------------------------------------
function LootDrop_CLFilter()
	LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].CLFilters.CLFiltering = not LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].CLFilters.CLFiltering
	if (LOOTDROP_DB.Default[GetDisplayName()]["$AccountWide"].CLFilters.CLFiltering) then
		d(L.CLFilterOn)
	else
		d(L.CLFilterOff)
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--- Create a new instance of a LootDroppable
-- @treturn LootDroppable
function LootDroppable:New( ... )
	local result = ZO_Object.New( self )
	result:Initialize( ... )
	return result
end
-------------------------------------------------------------------------------
--- Constructor
--
function LootDroppable:Initialize( objectPool )
	self.pool    = objectPool
	self.db      = objectPool.db
	self.control = CreateControlFromVirtual( 'LootDroppable', objectPool:GetControl(), 'LootDroppable', objectPool:GetNextId() )
	self.label   = self.control:GetNamedChild( '_Name' )
	self.icon    = self.control:GetNamedChild( '_Icon' )
	self.border  = self.control:GetNamedChild( '_Rarity' )
	self.bg      = self.control:GetNamedChild( '_BG' )
end
-------------------------------------------------------------------------------
--- Visibility Getter
-- @treturn boolean
function LootDroppable:IsVisible()
	return self.control:GetAlpha() > 0
end
-------------------------------------------------------------------------------
--- Show this droppable
-- @tparam number y
function LootDroppable:Show( x, y )
	self.enter_animation:Play()
	local current_x, current_y = self:GetOffsets()
	self.move_animation = self.pool._slide:Apply( self.control, current_x, current_y, x, y )
	self.move_animation:Play()
end
-------------------------------------------------------------------------------
function LootDroppable:Hide(name)
	if ( self.exit_animation ) then
		self.exit_animation:InsertCallback( function( ... ) self:Reset() end, 200 )
	--	self.exit_animation:InsertCallback( function( name ) local checkState = LootDropPool:Get(name) if not checkState or checkState == self then self:Reset() end end, 200 )
	--	self.exit_animation:InsertCallback( function( name ) local checkState = LootDropPool:Get(name) if checkState == self then self:Reset() end end, 200 )
		self.exit_animation:Play()
	else
		self.control:SetAlpha( 0.0 )
		self:Reset()
	end
end
-------------------------------------------------------------------------------
--- Ready this droppable to show
function LootDroppable:Prepare(StackUp)
	if (StackUp==nil) then StackUp=true end
	local xdim, ydim = self.pool:GetControl():GetDimensions()
	local StartHeight =( #self.pool._active + 1 ) * ( self.db.display.height + self.db.display.padding )

	--self:SetAnchor( BOTTOMRIGHT, self.pool:GetControl(), BOTTOMRIGHT, self.db.display.width, ( #self.pool._active - 1 ) * ( ( self.db.display.height + self.db.display.padding ) * -1 ) )
	if (StackUp) then
		self:SetAnchor( BOTTOMRIGHT, self.pool:GetControl(), BOTTOMRIGHT, 0, - StartHeight )
	else
		self:SetAnchor( BOTTOMRIGHT, self.pool:GetControl(), BOTTOMRIGHT, 0, StartHeight - ydim )
	end

	self.control:SetWidth( self.db.display.width )
	self.control:SetHeight( self.db.display.height )
	self.icon:SetWidth( self.db.display.height )
	self.icon:SetHeight( self.db.display.height )

	self.enter_animation = self.pool._fadeIn:Apply( self.control )
	self.exit_animation  = self.pool._fadeOut:Apply( self.control )
	self.move_animation  = nil

	self.control:SetAlpha( 0 )
	self.label:SetText( '' )
	self.icon:SetTexture( '' )
	self.bg:SetTexture( '' )
	self.border:SetTexture( '' )
	self.timestamp = 0
	self.quantity = 0
	self.sval = 0
	self.tval = 0
	self.name = ""
end
-------------------------------------------------------------------------------
--- Reset this droppable
function LootDroppable:Reset()
	self.enter_animation = nil
	self.exit_animation  = nil
	self.move_animation  = nil
	self.control         = nil
	self.label:SetText( '' )
	self.icon:SetHidden( true )
	self.bg:SetHidden( true )
	self.border:SetHidden( true )
	self.timestamp = 0
	self.quantity = 0
	self.sval = 0
	self.tval = 0
	self.name = ""
end
-------------------------------------------------------------------------------
--- Control getter
-- @treturn table
function LootDroppable:GetControl()
	return self.control
end
-------------------------------------------------------------------------------
--- Set show timestamp
-- @tparam number stamp
function LootDroppable:SetTimestamp( stamp )
	self.timestamp = stamp
end
-------------------------------------------------------------------------------
--- Get show timestamp
-- @treturn number
function LootDroppable:GetTimestamp()
	return self.timestamp
end
-------------------------------------------------------------------------------
--- Set label
-- @tparam string label
function LootDroppable:SetLabel( label )
	self.label:SetText( label )
end
-------------------------------------------------------------------------------
--- Set name
-- @tparam string name
function LootDroppable:SetName( name )
	self.name = name
end
-------------------------------------------------------------------------------
--- Set quantity
-- @tparam number quantity
function LootDroppable:SetQuantity( quantity )
	self.quantity = quantity
end
-------------------------------------------------------------------------------
--- Set value
-- @tparam number sell value, trade value
function LootDroppable:SetValue( sval, tval )
	self.sval = sval
	self.tval = tval
end
-------------------------------------------------------------------------------
--- Set label Size
-- @tparam number size
function LootDroppable:SetLabelSize( size, mode )
	local lDB = self.db.display
	local function GetCustomFont(mode) -- (Phinix)
		local mVals = {
			[1] = {enabled = lDB.cFontOLoot, font = lDB.cFontLoot},			-- Loot
			[2] = {enabled = lDB.cFontOGold, font = lDB.cFontGold},			-- Gold
			[3] = {enabled = lDB.cFontOXP, font = lDB.cFontXP},				-- XP
			[4] = {enabled = lDB.cFontOAP, font = lDB.cFontAP},				-- AP
			[5] = {enabled = lDB.cFontOTV, font = lDB.cFontTV},				-- Telvar Stones
			[6] = {enabled = lDB.cFontOWV, font = lDB.cFontWV},				-- Writ Vouchers
			[7] = {enabled = lDB.cFontOUK, font = lDB.cFontUK},				-- Undaunted Keys
			[8] = {enabled = lDB.cFontOTC, font = lDB.cFontTC},				-- Transmute Crystals
			[9] = {enabled = lDB.cFontOET, font = lDB.cFontET},				-- Event Tickets
			[10] = {enabled = lDB.cFontOES, font = lDB.cFontES},			-- Seals of Endeavor
			[11] = {enabled = lDB.cFontOSkill, font = lDB.cFontSkill},		-- Skills
			[12] = {enabled = lDB.cFontOComp, font = lDB.cFontComp},		-- Companions
			[13] = {enabled = lDB.cFontOAchieve, font = lDB.cFontAchieve},	-- Achievements
			[14] = {enabled = lDB.cFontOAF, font = lDB.cFontAF},			-- Archival Fortunes
			[15] = {enabled = lDB.cFontOIF, font = lDB.cFontIF},			-- Imperial Fragments
			[16] = {enabled = lDB.cFontOTP, font = lDB.cFontTP},			-- Tome points
			[17] = {enabled = lDB.cFontOVP, font = lDB.cFontVP},			-- VP
		}
		local cType = ((mVals[mode] ~= nil) and (mVals[mode].enabled))
		if not lDB.customFontE and not cType then return '$(BOLD_FONT)|' end -- use default font if custom not set (Phinix)
	
		if not cType then
			return LMP:Fetch('font', lDB.customFontG)..'|'
		else
			return LMP:Fetch('font',  mVals[mode].font)..'|'
		end
	end

	local size = size or 14
	local tfont = GetCustomFont(mode) -- (Phinix)
	local font = tfont .. size .. '|soft-shadow-thin'
	self.label:SetFont( font )
end
-------------------------------------------------------------------------------
function LootDroppable:SetBackground()
    if  self.db.display.customBG ~= nil and self.db.display.customBG ~= "DEFAULT" then
	    self.bg:SetTexture(self.db.display.customBG)
	else
	    self.bg:SetTexture(LootDrop_sBgTexture)
	end
	self.bg:SetHidden( false )
end
-------------------------------------------------------------------------------
--- Set rarity border
-- @tparam ZO_ColorDef color
function LootDroppable:SetRarity( color , b_rarity )

	if (b_rarity==nil) then 
		b_rarity=true
	end

	if (( not color ) and (b_rarity)) then
		color = ZO_ColorDef:New( 1, 1, 1, 1 )
	end

	if (not b_rarity) then
		color = ZO_ColorDef:New( 0, 0, 0, 0)
	end

	self.border:SetTexture(LootDrop_sRarityTexture)
	self.border:SetColor( color:UnpackRGBA() )
	self.border:SetHidden( false )
end
-------------------------------------------------------------------------------
function LootDroppable:GetLabel()
	return tonumber( self.label:GetText() or 0 )
end
-------------------------------------------------------------------------------
--- Set Icon
-- @tparam string icon
function LootDroppable:SetIcon( icon, coords )
	--local texture = self.icon:GetTextureInfo()
	local texture = self.icon:GetTextureFileName()

	if ( texture ~= icon ) then
		self.icon:SetTexture( icon )
	end

	if ( coords ) then
		self.icon:SetTextureCoords( unpack( coords ) )
	else
		self.icon:SetTextureCoords( 0, 1, 0, 1 )
	end

	self.icon:SetHidden( false )
end
-------------------------------------------------------------------------------
--- Pass anchor information to control
function LootDroppable:SetAnchor( ... )
	self.control:SetAnchor( ... )
end
-------------------------------------------------------------------------------
--- Pass translate information to animation
function LootDroppable:Move( x, y )
	local current_x, current_y = self:GetOffsets()
	self.move_animation = self.pool._slide:Apply( self.control, current_x, current_y, x, y )
	self.move_animation:Play()
end
-------------------------------------------------------------------------------
--- Get current y offset
-- @treturn number
function LootDroppable:GetOffsets()
	local _, _, _, _, offsX, offsY = self.control:GetAnchor( 0 )
	return offsX, offsY
end
-------------------------------------------------------------------------------


--LootDrop Object--------------------------------------------------------------
LootDrop.dirty_flags					= setmetatable( {}, { __mode = 'kv'} )
LootDrop.config							= nil
LootDrop.db								= nil
LootDrop.ScreenMaxWidth					= 800
LootDrop.ScreenMaxHeight				= 600
LootDrop.NextUpdate						= 0
LootDrop.CurrentItemBag_ItemStyle		= nil
LootDrop.CurrentItemBag_ItemType		= nil
LootDrop.CurrentItemBag_ItemLink		= nil
LootDrop.CurrentItemBag_ItemQuality		= nil
LootDrop.CurrentItemBag_ItemNb			= nil
LootDrop.ItemToPrint					= {iconFileName  = "/esoui/art/icons/icon_missing.dds", color='FFFFFF', quantity=0, nb=0, text='', tag='', itemstyle=nil}
LootDrop.MailStacks						= {}
LootDrop.loaded							= false
LootDrop.hasHidden						= false
-------------------------------------------------------------------------------
--- Create our ObjectPool
-- @param ...
function LootDrop:New( ... )
	local result = LootDropPool.New( self )
	result:Initialize( ... )
	return result
end


-------------------------------------------------------------------------------
--- I swear I'm going to use this for something
-- @param ...
function LootDrop:Initialize( control )
	self.control = control
	self.control:RegisterForEvent( EVENT_ADD_ON_LOADED, function( ... ) self:OnLoaded( ... ) end )

	LootDropPool.Initialize( self, function() return self:CreateDroppable() end, function( ... ) self:ResetDroppable( ... ) end  )

	self.control:SetHandler( 'OnUpdate',			function( _, ft )		self:OnUpdate( ft )		end )
	self.control:SetHandler( 'OnMoveStop',			function( )				self:OnMoveStop( )		end )

	self._fadeIn  = LootDropFade:New( 0.0, 1.0, 200 )
	self._fadeOut = LootDropFade:New( 1.0, 0.0, 200 )
	self._slide   = LootDropSlide:New( 200 )
	self._pop     = LootDropPop:New()

	self._coinId						= nil
	self._coinLastVal					= 0

	self._xpId							= nil
	self._xpLastVal						= 0

	self._xpCompanionId					= nil
	self._xpCompanionLastVal			= 0

	self._rapportId						= nil
	self._rapportLastVal				= 0

	self._apId							= nil
	self._apLastVal						= 0
	self._apLastRPVal					= 0
	self._apLastRP						= GetUnitAvARankPoints("player")

	self._vpId							= nil
	self._vpLastVal						= 0
	self._vpLastVPVal					= 0
  local _, _, progress = GetInfoForRewardTrack(REWARD_TRACK_TYPE_AVA_VETERANCY, GetReferenceTrackIndex(REWARD_TRACK_TYPE_AVA_VETERANCY, GetActiveReferenceTrackIdsForRewardTrackType(REWARD_TRACK_TYPE_AVA_VETERANCY)))
	self._vpLastVP = progress


	self._rpId							= nil

	self._tvId							= nil
	self._tvLastVal						= 0

	self._wVoucherId					= nil
	self._wVoucherLastVal				= 0

	self._undauntedId					= nil
	self._undauntedLastVal				= 0

	self._transmuteId					= nil
	self._transmuteLastVal				= 0

	self._eticketId						= nil
	self._eticketLastVal				= 0

	self._EndeavorId					= nil
	self._EndeavorLastVal				= 0

	self._EndlessId						= nil
	self._EndlessLastVal				= 0

	self._FragmentsId					= nil
	self._FragmentsLastVal				= 0
  
	self._TomePointsId					= nil
	self._TomePointsLastVal				= 0
  
	self._TomePointCachesId					= nil
	self._TomePointCachesLastVal				= 0
  
	self._TomeTokensId					= nil
	self._TomeTokensLastVal				= 0
  
	self._TradeBarsId					= nil
	self._TradeBarsLastVal				= 0

	self._skillMageXpId					= nil
	self._skillMageXpLastVal			= 0

	self._skillFighterXpId				= nil
	self._skillFighterXpLastVal			= 0

	self._skillUndauntedXpId			= nil
	self._skillUndauntedXpLastVal		= 0

	self._skillOtherGuildXpId			= nil
	self._skillOtherGuildXpLastVal		= 0

	self._skillPsijicXpId				= nil
	self._skillPsijicXpLastVal			= 0

	self._skillBookXpId					= nil
	self._skillBookXpLastVal			= 0

	self._skillFenceXpId				= nil
	self._skillFenceXpLastVal			= 0

	self._skillThievesXpId				= nil
	self._skillThievesXpLastVal			= 0

	self._skillBrotherhoodXpId			= nil
	self._skillBrotherhoodXpLastVal		= 0

	self._skillBlacksmithingXpId		= nil
	self._skillBlacksmithingXpLastVal	= 0
	
	self._skillClothierXpId				= nil
	self._skillClothierXpLastVal		= 0
	
	self._skillEnchantingXpId			= nil
	self._skillEnchantingXpLastVal		= 0
	
	self._skillAlchemyXpId				= nil
	self._skillAlchemyXpLastVal			= 0
	
	self._skillProvisioningXpId			= nil
	self._skillProvisioningXpLastVal	= 0
	
	self._skillWoodworkingXpId			= nil
	self._skillWoodworkingXpLastVal		= 0
	
	self._skillJewelcraftingXpId		= nil
	self._skillJewelcraftingXpLastVal	= 0

	self._achieveTable					= {}

---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Skill Line Progress
---------------------------------------------------------------------------------------------------------------------------------------------------------------
	self._skillTableArmor = {
		[1] = {key = nil, val = 0, tag = "LIGHTARMOR",	pName = "skill_lightarmor",		icon = "esoui/art/icons/progression_tabicon_armorlight_up.dds"},			-- Light Armor
		[2] = {key = nil, val = 0, tag = "MEDIUMARMOR",	pName = "skill_mediumarmor",	icon = "esoui/art/icons/progression_tabicon_armormedium_up.dds"},			-- Medium Armor
		[3] = {key = nil, val = 0, tag = "HEAVYARMOR",	pName = "skill_heavyarmor",		icon = "esoui/art/icons/progression_tabicon_armorheavy_up.dds"},			-- Heavy Armor
	}
	self._skillTableAvA = {
		[1] = {key = nil, val = 0, tag = "ASSAULT",		pName = "skill_assault",		icon = "esoui/art/compass/ava_largekeep_neutral.dds"},						-- Assault
		[2] = {key = nil, val = 0, tag = "EMPEROR",		pName = "skill_emperor",		icon = "esoui/art/campaign/gamepad/gp_overview_menuicon_emperor.dds"},		-- Emperor
		[3] = {key = nil, val = 0, tag = "SUPPORT",		pName = "skill_support",		icon = "esoui/art/compass/ava_outpost_neutral.dds"},						-- Support
	}
	self._skillTableWeapon = {
		[1] = {key = nil, val = 0, tag = "TWOHANDED",	pName = "skill_twohanded",		icon = "esoui/art/icons/icon_2handed.dds"},									-- Two-Handed
		[2] = {key = nil, val = 0, tag = "1HSHIELD",	pName = "skill_1hshield",		icon = "esoui/art/icons/icon_1handed.dds"},									-- 1-Hand & Shield
		[3] = {key = nil, val = 0, tag = "DUALWIELD",	pName = "skill_dualwield",		icon = "esoui/art/icons/icon_dualwield.dds"},								-- Dual Wield
		[4] = {key = nil, val = 0, tag = "BOW",			pName = "skill_bow",			icon = "esoui/art/icons/icon_bows.dds"},									-- Bow
		[5] = {key = nil, val = 0, tag = "DESTRUCTION",	pName = "skill_destruction",	icon = "esoui/art/icons/icon_firestaff.dds"},								-- Destruction Staff
		[6] = {key = nil, val = 0, tag = "RESTORATION",	pName = "skill_restoration",	icon = "esoui/art/icons/progression_tabicon_healstaff_up.dds"},				-- Restoration Staff
	}
	self._skillTableWorld = {
		[1] = {key = nil, val = 0, tag = "EXCAVATION",	pName = "skill_excavation",		icon = "esoui/art/icons/servicemappins/servicepin_antiquities.dds"},		-- Excavation
		[2] = {key = nil, val = 0, tag = "LEGERDEMAIN",	pName = "skill_legerdemain",	icon = "esoui/art/icons/skilllinexp_ledgermain.dds"},						-- Legerdemain
		[3] = {key = nil, val = 0, tag = "SCRYING",		pName = "skill_scrying",		icon = "esoui/art/icons/collectible_memento_psijicscryingtalisman.dds"},	-- Scrying
		[4] = {key = nil, val = 0, tag = "SOUL",		pName = "skill_soul",			icon = "esoui/art/icons/soulgem_006_filled.dds"},							-- Soul Magic
		[5] = {key = nil, val = 0, tag = "VAMPIRE",		pName = "skill_vampire",		icon = "esoui/art/icons/ability_vampire_007.dds"},							-- Vampire
		[6] = {key = nil, val = 0, tag = "WEREWOLF",	pName = "skill_werewolf",		icon = "esoui/art/icons/ability_werewolf_010.dds"},							-- Werewolf
	}

	self.lastRankXP, self.nextRankXP, self.currentXP = GetSkillLineXPInfo(skillType, skillLineIndex)
---------------------------------------------------------------------------------------------------------------------------------------------------------------
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_LOOT,			function() self:ToggleLoot()    			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_MAIL_LOOT,	function() self:ToggleMailLoot()    		end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_GROUP_NAME,	function() self:ToggleGroupName()   		end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_COIN,			function() self:ToggleCoin()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_XP,			function() self:ToggleXP()      			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_AP,			function() self:ToggleAP()					end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_VP,			function() self:ToggleVP()					end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_TV,			function() self:ToggleTV()					end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_WVOUCHER,		function() self:ToggleWVoucher()			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_ACCOUNT,		function() self:AccountCurrencies()			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_COMPANION_XP,	function() self:ToggleCompanionXP()     	end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_COMPANION_RP,	function() self:ToggleCompanionRapport()	end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_ACHIEVEMENTS,	function() self:ToggleAchievements()		end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_SKILL_XP,		function() self:ToggleSkillXP()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_BOOK_LOOT,	function() self:ToggleBookProgress()		end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_JUNK,			function() self:ToggleJunk()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_DEFAULT,		function() self:DisableDefault()			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_HIDEGUI,		function() self:ToggleHideGUI()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_HIDECHAT,		function() self:ToggleHideChat()			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_HIDEMETERS,	function() self:ToggleHideMeters()			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_STYLE,		function() self:ToggleStyle()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_LOCK,			function() self:ToggleLock()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_RARITY,		function() self:ToggleRarity()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_TOGGLE_MOVEUP,		function() self:ToggleMoveUp()				end )
	CBM:RegisterCallback( LootDropConfig.EVENT_CHANGE_DIMENSIONS,	function() self:ChangeDimensions()			end )
	CBM:RegisterCallback( LootDropConfig.EVENT_RESET_PREVIEW,		function() self:ResetPreview()				end )
---------------------------------------------------------------------------------------------------------------------------------------------------------------
	self.recentLoot = {} -- initialize table of recently acquired loot (Phinix)

-- preview value init
	self._preview_gold = 100
	self._preview_level = 0
	self._preview_XP = 1
	self._preview_telvar = 0
	self._preview_voucher = 0
	self._preview_undaunted = 0
	self._preview_transmute = 0
	self._preview_eticket = 0
	self._preview_endeavor = 0
	self._preview_endless = 0
	self._preview_fragments = 0
	self._preview_TomePoints = 0
	self._preview_TomePointCaches = 0 
	self._preview_TomeTokens = 0 
	self._preview_TradeBars = 0 
	self._preview_clevel = 0
	self._preview_cXP = 0
	self._preview_rapport = 0
---------------------------------------------------------------------------------------------------------------------------------------------------------------
	local pChars = {
		["Dar'jazad"] = "Rajhin's Echo",
		["Quantus Gravitus"] = "Maker of Things",
		["Nina Romari"] = "Sanguine Coalescence",
		["Valyria Morvayn"] = "Dragon's Teeth",
		["Sanya Lightspear"] = "Thunderbird",
		["Divad Arbolas"] = "Gravity of Words",
		["Dro'samir"] = "Dark Matter",
		["Irae Aundae"] = "Prismatic Inversion",
		["Quixoti'coatl"] = "Time Toad",
		["Cythirea"] = "Mazken Stormclaw",
		["Fear-No-Pain"] = "Soul Sap",
		["Wax-in-Winter"] = "Cold Blooded",
		["Nateo Mythweaver"] = "In Strange Lands",
		["Cindari Atropa"] = "Dragon's Breath",
		["Kailyn Duskwhisper"] = "Nowhere's End",
		["Draven Blightborn"] = "From Outside",
		["Lorein Tarot"] = "Entanglement",
		["Koh-Ping"] = "Global Cooling",
	}
	
	local modifyGetUnitTitle = GetUnitTitle
	GetUnitTitle = function(unitTag)
		local oTitle = modifyGetUnitTitle(unitTag)
		local uName = GetUnitName(unitTag)
		return (pChars[uName] ~= nil) and pChars[uName] or oTitle
	end
end
-------------------------------------------------------------------------------
function LootDrop:RunUpdates()
--	if self.db.version < 4.30 then -- updates settings using obsolete values to avoid errors (Phinix)

	--	d("LootDrop: Update complete.")
--		self.db.version = 4.30
--	end
end
-------------------------------------------------------------------------------
function LootDrop:BuildFiltered(db)
	filterTable = {
		[ITEMTYPE_TOOL]								= {LW = db.LWFilters.FilterTools, CL = db.CLFilters.FilterTools},					-- "Lockpicks & Tools"
		[ITEMTYPE_SOUL_GEM]							= {LW = db.LWFilters.FilterSoulGems, CL = db.CLFilters.FilterSoulGems}, 			-- "Soul Gems"
		[ITEMTYPE_TRASH]							= {LW = db.LWFilters.FilterTrash, CL = db.CLFilters.FilterTrash},					-- "Trash Items"	
		[ITEMTYPE_TREASURE]							= {LW = db.LWFilters.FilterTreasure, CL = db.CLFilters.FilterTreasure},				-- "Treasure"
		[ITEMTYPE_GLYPH_WEAPON]						= {LW = db.LWFilters.FilterWGlyphs, CL = db.CLFilters.FilterWGlyphs}, 				-- "Weapon Glyphs"
		[ITEMTYPE_GLYPH_ARMOR]						= {LW = db.LWFilters.FilterAGlyphs, CL = db.CLFilters.FilterAGlyphs},				-- "Armor Glyphs"
		[ITEMTYPE_GLYPH_JEWELRY]					= {LW = db.LWFilters.FilterJGlyphs, CL = db.CLFilters.FilterJGlyphs},				-- "Jewelry Glyphs"
		[ITEMTYPE_FURNISHING]						= {LW = db.LWFilters.FilterFurniture, CL = db.CLFilters.FilterFurniture},			-- "Furniture Items"
		[ITEMTYPE_RECALL_STONE]						= {LW = db.LWFilters.FilterRecall, CL = db.CLFilters.FilterRecall}, 				-- "Keep Recall Stone"
		[ITEMTYPE_SIEGE]							= {LW = db.LWFilters.FilterSiege, CL = db.CLFilters.FilterSiege},					-- "AvA Siege"
		[ITEMTYPE_AVA_REPAIR]						= {LW = db.LWFilters.FilterAVARepair, CL = db.CLFilters.FilterAVARepair},			-- "AvA Repair"
		[ITEMTYPE_TROPHY]							= {LW = db.LWFilters.FilterTrophies, CL = db.CLFilters.FilterTrophies},				-- "Trophies"
		[ITEMTYPE_COLLECTIBLE]						= {LW = db.LWFilters.FilterCollectibles, CL = db.CLFilters.FilterCollectibles},		-- "Collectibles"
		[ITEMTYPE_CONTAINER]						= {LW = db.LWFilters.FilterContainers, CL = db.CLFilters.FilterContainers},			-- "Containers"
		[ITEMTYPE_CONTAINER_CURRENCY]				= {LW = db.LWFilters.FilterCContainers, CL = db.CLFilters.FilterCContainers},		-- "Currency Containers"
		[ITEMTYPE_COSTUME]							= {LW = db.LWFilters.FilterCostumes, CL = db.CLFilters.FilterCostumes},				-- "Costumes"
		[ITEMTYPE_DISGUISE]							= {LW = db.LWFilters.FilterDisguise, CL = db.CLFilters.FilterDisguise},				-- "Disguises"
		[ITEMTYPE_CROWN_ITEM]						= {LW = db.LWFilters.FilterCrownItems, CL = db.CLFilters.FilterCrownItems},			-- "Crown Items"
		[ITEMTYPE_CROWN_REPAIR]						= {LW = db.LWFilters.FilterCrownRepair, CL = db.CLFilters.FilterCrownRepair}, 		-- "Crown Repair Kits"
	-- CONSUMABLES
		[ITEMTYPE_FOOD]								= {LW = db.LWFilters.FilterFood, CL = db.CLFilters.FilterFood}, 					-- "Food"
		[ITEMTYPE_DRINK]							= {LW = db.LWFilters.FilterDrink, CL = db.CLFilters.FilterDrink},					-- "Drink"
		[ITEMTYPE_POTION]							= {LW = db.LWFilters.FilterPotion, CL = db.CLFilters.FilterPotion},					-- "Potion"
		[ITEMTYPE_POISON]							= {LW = db.LWFilters.FilterPoison, CL = db.CLFilters.FilterPoison},					-- "Poison"
		[ITEMTYPE_POTION_BASE]						= {LW = db.LWFilters.FilterPotionBase, CL = db.CLFilters.FilterPotionBase}, 		-- "Potion Base"
		[ITEMTYPE_POISON_BASE]						= {LW = db.LWFilters.FilterPoisonBase, CL = db.CLFilters.FilterPoisonBase},			-- "Poison Base"
		[ITEMTYPE_FISH]								= {LW = db.LWFilters.FilterFish, CL = db.CLFilters.FilterFish},						-- "Fish"
		[ITEMTYPE_LURE]								= {LW = db.LWFilters.FilterBait, CL = db.CLFilters.FilterBait},						-- "Fish Bait"
	-- CRAFTING
		[ITEMTYPE_INGREDIENT]						= {LW = db.LWFilters.FilterIngredients, CL = db.CLFilters.FilterIngredients},		-- "Ingredients"
		[ITEMTYPE_FLAVORING]						= {LW = db.LWFilters.FilterIngredients, CL = db.CLFilters.FilterIngredients},		-- "Ingredients" (flavoring)
		[ITEMTYPE_SPICE]							= {LW = db.LWFilters.FilterIngredients, CL = db.CLFilters.FilterIngredients},		-- "Ingredients" (spice)
		[ITEMTYPE_ADDITIVE]							= {LW = db.LWFilters.FilterIngredients, CL = db.CLFilters.FilterIngredients},		-- "Ingredients" (addative)
		[ITEMTYPE_REAGENT]							= {LW = db.LWFilters.FilterReagents, CL = db.CLFilters.FilterReagents},				-- "Alchemy Reagents"
		[ITEMTYPE_WEAPON_TRAIT]						= {LW = db.LWFilters.FilterWTrait, CL = db.CLFilters.FilterWTrait},					-- "Weapon Trait Items"
		[ITEMTYPE_ARMOR_TRAIT]						= {LW = db.LWFilters.FilterATrait, CL = db.CLFilters.FilterATrait},					-- "Armor Trait Items"
		[ITEMTYPE_FURNISHING_MATERIAL]				= {LW = db.LWFilters.FilterFurnMats, CL = db.CLFilters.FilterFurnMats}, 			-- "Furniture Materials"
		[ITEMTYPE_RAW_MATERIAL]						= {LW = db.LWFilters.FilterCompMats, CL = db.CLFilters.FilterCompMats},				-- "Component Materials"
		[ITEMTYPE_RACIAL_STYLE_MOTIF]				= {LW = db.LWFilters.FilterMotif, CL = db.CLFilters.FilterMotif},					-- "Style Motifs"
		[ITEMTYPE_STYLE_MATERIAL]					= {LW = db.LWFilters.FilterStyleMats, CL = db.CLFilters.FilterStyleMats},			-- "Style Materials"
		[ITEMTYPE_MASTER_WRIT]						= {LW = db.LWFilters.FilterMasterWRits, CL = db.CLFilters.FilterMasterWRits},		-- "Master Writs"
		[ITEMTYPE_RECIPE]							= {LW = db.LWFilters.FilterRecipes, CL = db.CLFilters.FilterRecipes},				-- "Recipes"
		[ITEMTYPE_ENCHANTING_RUNE_ESSENCE]			= {LW = db.LWFilters.FilterERune, CL = db.CLFilters.FilterERune},					-- "Essence Rune"
		[ITEMTYPE_ENCHANTING_RUNE_POTENCY]			= {LW = db.LWFilters.FilterPRune, CL = db.CLFilters.FilterPRune},					-- "Potency Rune"
		[ITEMTYPE_ENCHANTING_RUNE_ASPECT]			= {LW = db.LWFilters.FilterARune, CL = db.CLFilters.FilterARune},					-- "Aspect Rune"
		[ITEMTYPE_BLACKSMITHING_MATERIAL]			= {LW = db.LWFilters.FilterBSMats, CL = db.CLFilters.FilterBSMats},					-- "Blacksmithing Material"
		[ITEMTYPE_BLACKSMITHING_RAW_MATERIAL]		= {LW = db.LWFilters.FilterBSRawMats, CL = db.CLFilters.FilterBSRawMats}, 			-- "Blacksmithing Raw Material"
		[ITEMTYPE_BLACKSMITHING_BOOSTER]			= {LW = db.LWFilters.FilterBSImprove, CL = db.CLFilters.FilterBSImprove},			-- "Blacksmithing Improve Item"
		[ITEMTYPE_CLOTHIER_MATERIAL]				= {LW = db.LWFilters.FilterClothMats, CL = db.CLFilters.FilterClothMats},			-- "Clothing Material"
		[ITEMTYPE_CLOTHIER_RAW_MATERIAL]			= {LW = db.LWFilters.FilterClothRawMats, CL = db.CLFilters.FilterClothRawMats}, 	-- "Clothing Raw Material"
		[ITEMTYPE_CLOTHIER_BOOSTER]					= {LW = db.LWFilters.FilterClothImprove, CL = db.CLFilters.FilterClothImprove},		-- "Clothing Improve Item"
		[ITEMTYPE_WOODWORKING_MATERIAL]				= {LW = db.LWFilters.FilterWoodMats, CL = db.CLFilters.FilterWoodMats},				-- "Woodworking Material"
		[ITEMTYPE_WOODWORKING_RAW_MATERIAL]			= {LW = db.LWFilters.FilterWoodRawMats, CL = db.CLFilters.FilterWoodRawMats}, 		-- "Woodworking Raw Material"
		[ITEMTYPE_WOODWORKING_BOOSTER]				= {LW = db.LWFilters.FilterWoodImprove, CL = db.CLFilters.FilterWoodImprove},		-- "Woodworking Improve Item"
		[ITEMTYPE_JEWELRYCRAFTING_MATERIAL]			= {LW = db.LWFilters.FilterJCMats, CL = db.CLFilters.FilterJCMats},					-- "Jewelcrafting Material"
		[ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL]		= {LW = db.LWFilters.FilterJCRawMats, CL = db.CLFilters.FilterJCRawMats},			-- "Jewelcrafting Raw Material"
		[ITEMTYPE_JEWELRY_TRAIT]					= {LW = db.LWFilters.FilterJCTrait, CL = db.CLFilters.FilterJCTrait},				-- "Jewelcrafting Trait"
		[ITEMTYPE_JEWELRY_RAW_TRAIT]				= {LW = db.LWFilters.FilterJCRawTrait, CL = db.CLFilters.FilterJCRawTrait},			-- "Jewelcrafting Raw Trait"
		[ITEMTYPE_JEWELRYCRAFTING_BOOSTER]			= {LW = db.LWFilters.FilterJCImprove, CL = db.CLFilters.FilterJCImprove},			-- "Jewelcrafting Improve Item"
		[ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER]		= {LW = db.LWFilters.FilterJCRawImprove, CL = db.CLFilters.FilterJCRawImprove},		-- "Jewelcrafting Raw Improve Item"
	}

	specialFilters = {
		[ITEMTYPE_INGREDIENT] = true,
		[ITEMTYPE_FLAVORING] = true,
		[ITEMTYPE_SPICE] = true,
		[ITEMTYPE_ADDITIVE] = true,
		[ITEMTYPE_GLYPH_WEAPON] = true,
		[ITEMTYPE_GLYPH_ARMOR] = true,
		[ITEMTYPE_GLYPH_JEWELRY] = true,
		[ITEMTYPE_RECIPE] = true,
		[ITEMTYPE_ENCHANTING_RUNE_ASPECT] = true,
		[ITEMTYPE_BLACKSMITHING_BOOSTER] = true,
		[ITEMTYPE_CLOTHIER_BOOSTER] = true,
		[ITEMTYPE_WOODWORKING_BOOSTER] = true,
		[ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = true,
		[ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER] = true,
	}
end
-------------------------------------------------------------------------------
function LootDrop:OnLoaded( event, addon )
	if ( addon ~= ADDON_NAME ) then
		return
	end
	
    self.control:UnregisterForEvent( EVENT_ADD_ON_LOADED )
	
	self.db = ZO_SavedVars:NewAccountWide( 'LOOTDROP_DB', 4.30, nil, LootDrop_Defaults )

	LootDrop:BuildFiltered( self.db )

	self.config = LootDropConfig:New( self.db )

	SLASH_COMMANDS['/ldrlock'] = function() LootDrop_LockUnlock() end

--	self:RunUpdates() -- run necessary updates (Phinix)

	self:ToggleLoot()
	self:ToggleMailLoot()
	self:ToggleGroupName()
	self:ToggleCoin()
	self:ToggleXP()
	self:ToggleAP()
	self:ToggleVP()
	self:ToggleTV()
	self:ToggleWVoucher()
	self:ToggleBookProgress()
	self:AccountCurrencies()
	self:ToggleCompanionXP()
	self:ToggleCompanionRapport()
	self:ToggleAchievements()
	self:ToggleSkillXP()
	self:ToggleStyle()
	self:DisableDefault()

	-- update addon when companion is activated/dismissed
	self.control:RegisterForEvent( EVENT_COMPANION_ACTIVATED, function() self:ToggleCompanionXP() self:ToggleCompanionRapport() end )
	self.control:RegisterForEvent( EVENT_COMPANION_DEACTIVATED, function() self:ToggleCompanionXP() self:ToggleCompanionRapport() end )

	local leftScreen, topScreen, rightScreen, bottomScreen  = GuiRoot:GetScreenRect()
	self.ScreenMaxWidth = rightScreen
	self.ScreenMaxHeight = bottomScreen

	self.control:ClearAnchors()
	self.control:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, self.db.lootdrop_x, self.db.lootdrop_y)
	local x = zo_min((self.ScreenMaxWidth-50),(self.db.display.width+1))
	local y = zo_min((self.ScreenMaxHeight-50),11*(self.db.display.height + self.db.display.padding))
	self.control:SetDimensions(x, y)
	self.control:SetDrawLayer(0)
	self.control:SetMovable(not self.db.lootdrop_lock)
	self.control:SetMouseEnabled(not self.db.lootdrop_lock)

	local MoveBG = WINDOW_MANAGER:CreateControl( "LootDropMoveMeBg",  self.control, CT_BACKDROP)  
	LootDropMoveMeBg:SetHidden(self.db.lootdrop_lock)
	LootDropMoveMeBg:SetAnchor(BOTTOMRIGHT, self.control, BOTTOMRIGHT, 0, 0)
	LootDropMoveMeBg:SetAnchorFill(self.control)
	LootDropMoveMeBg:SetCenterColor( 0,0,0,0.4 )
	LootDropMoveMeBg:SetCenterTexture("",8,1,2)
	LootDropMoveMeBg:SetEdgeColor( 0,0,0,0 )
	LootDropMoveMeBg:SetEdgeTexture("",8,1,2)

	self.db.lootdrop_lock = true -- reset lock state on startup if reloaded from settings panel (Phinix)
	CBM:FireCallbacks( LootDropConfig.EVENT_TOGGLE_LOCK )

	-- maintain the hidden state of the LootDrop GUI
	if (self.db.general.DbgHideGUI) then LootDropGui:SetHidden(true) else LootDropGui:SetHidden(false) end

	self.loaded = true
end
-------------------------------------------------------------------------------
function LootDrop:ChangeDimensions()
	self.control:SetDimensions(zo_min((self.ScreenMaxWidth-50),(self.db.display.width+1)), zo_min((self.ScreenMaxHeight-50),11*(self.db.display.height + self.db.display.padding)))
end
-------------------------------------------------------------------------------
function LootDrop:ToggleMoveUp()
	--nothing to do, function just in case ... ;-)
	self.db.display.moveUp = self.db.display.moveUp	
end
-------------------------------------------------------------------------------
function LootDrop:ToggleRarity()
	--nothing to do, function just in case ... ;-)
	self.db.display.rarity = self.db.display.rarity
end
-------------------------------------------------------------------------------
function LootDrop:ToggleJunk()
	--nothing to do, function just in case ... ;-)
	self.db.general.junkTrash = self.db.general.junkTrash
end
-------------------------------------------------------------------------------
function LootDrop:ToggleHideGUI()
	if (self.db.general.DbgHideGUI) then
		LootDropGui:SetHidden(true)
		d(L.HiddenGUI..L.StatusOn)
	else
		LootDropGui:SetHidden(false)
		d(L.HiddenGUI..L.StatusOff)
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleHideChat()
	if (self.db.general.DbgHideChat) then
		d(L.HiddenChat..L.StatusOn)
	else
		d(L.HiddenChat..L.StatusOff)
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleStyle()
	if (self.db.display.sListStyle == LootDrop_sDefRushmik) then						--Rushmik
		LootDrop_sApIcon        	= "/lootdrop/textures/ap_rushmik_up.dds"
		LootDrop_sXpIcon        	= "/lootdrop/textures/xp_rushmik_up.dds"
		LootDrop_sRapportUpIcon		= "/lootdrop/textures/rapport_rushmik_up.dds"
		LootDrop_sRapportDownIcon	= "/lootdrop/textures/rapport_rushmik_down.dds"
		LootDrop_sSkillXpIcon   	= "/lootdrop/textures/skill_rushmik_up.dds"
		LootDrop_sBgTexture     	= "/lootdrop/textures/rushmik_bg.dds"
		LootDrop_sRarityTexture 	= "/lootdrop/textures/rushmik_rarity.dds"
	elseif (self.db.display.sListStyle == LootDrop_sDefPawkette) then					--Pawkette
		LootDrop_sApIcon        	= "/lootdrop/textures/ap_pawkette_up.dds"
		LootDrop_sXpIcon        	= "/lootdrop/textures/xp_pawkette_up.dds"
		LootDrop_sRapportUpIcon		= "/lootdrop/textures/rapport_up.dds"
		LootDrop_sRapportDownIcon	= "/lootdrop/textures/rapport_down.dds"
		LootDrop_sSkillXpIcon   	= "/lootdrop/textures/skill_pawkette_up.dds"
		LootDrop_sBgTexture     	= "/lootdrop/textures/default_bg.dds"
		LootDrop_sRarityTexture 	= "/lootdrop/textures/default_rarity.dds"
	elseif (self.db.display.sListStyle == LootDrop_sDefESOclassic) then					--ESOclassic by @Masteroshi430
		LootDrop_sApIcon        	= "/esoui/art/icons/icon_alliancepoints.dds"
		LootDrop_sXpIcon        	= "/EsoUI/Art/Icons/Icon_Experience.dds"
		LootDrop_sRapportUpIcon		= "/EsoUI/Art/HUD/lootHistory_icon_rapportIncrease_generic.dds"
		LootDrop_sRapportDownIcon	= "/EsoUI/Art/HUD/lootHistory_icon_rapportDecrease_generic.dds"
		LootDrop_sSkillXpIcon   	= "/esoui/art/skillsadvisor/indicator_abilitymorph.dds" -- /esoui/art/progression/progression_tabicon_combatskills_up.dds
		LootDrop_sBgTexture     	= "/lootdrop/textures/ava_hud_bgframe_black.dds"
		LootDrop_sRarityTexture 	= "/lootdrop/textures/default_rarity.dds"
	else																		--Default
		LootDrop_sApIcon        	= "/lootdrop/textures/ap_up.dds"
		LootDrop_sXpIcon        	= "/lootdrop/textures/xp_up.dds"
		LootDrop_sRapportUpIcon		= "/lootdrop/textures/rapport_up.dds"
		LootDrop_sRapportDownIcon	= "/lootdrop/textures/rapport_down.dds"
		LootDrop_sSkillXpIcon   	= "/lootdrop/textures/skill_up.dds"
		LootDrop_sBgTexture     	= "/lootdrop/textures/default_bg.dds"
		LootDrop_sRarityTexture 	= "/lootdrop/textures/default_rarity.dds"
	end
end
-------------------------------------------------------------------------------
function LootDrop:DisableDefault()
	if self.db.general.hideHistory == true then 
	    SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_LOOT_HISTORY, 0)
	else
--	    SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_LOOT_HISTORY, 1)
    end 
end
-------------------------------------------------------------------------------
function LootDrop:ToggleLock()
	if (IsPreviewPanel == 1) then
		LootDropMoveMeBg:SetHidden(true)
		self.control:ClearAnchors()
		self.control:SetAnchor(LEFT, LootDropPanel, RIGHT, 380, 140)
		self.control:SetMovable(true)
		self.control:SetMouseEnabled(true)
	elseif (IsPreviewPanel == 2) then
		self.control:ClearAnchors()
		self.control:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, self.db.lootdrop_x, self.db.lootdrop_y)
		local x = zo_min((self.ScreenMaxWidth-50),(self.db.display.width+1))
		local y = zo_min((self.ScreenMaxHeight-50),11*(self.db.display.height + self.db.display.padding))
		self.control:SetDimensions(x, y)
		self.control:SetDrawLayer(0)
		self.control:SetMovable(false)
		self.control:SetMouseEnabled(false)
		LootDropMoveMeBg:SetHidden(true)
		IsPreviewPanel = 0
	elseif (IsPreviewPanel == 3) then
		LootDropMoveMeBg:SetHidden(false)
		self.control:ClearAnchors()
		self.control:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, self.db.lootdrop_x, self.db.lootdrop_y)
		self.control:SetMovable(true)
		self.control:SetMouseEnabled(true)
	else
		self.control:SetMovable(not self.db.lootdrop_lock)
		self.control:SetMouseEnabled(not self.db.lootdrop_lock)
		LootDropMoveMeBg:SetHidden(self.db.lootdrop_lock)

		if (self.db.lootdrop_lock) then
			local leftScreen, topScreen, rightScreen, bottomScreen  = GuiRoot:GetScreenRect()
			local left, top, right, bottom = self.control:GetScreenRect()
	
			self.db.lootdrop_x = math.floor(right - rightScreen)
			self.db.lootdrop_y = math.floor(bottom - bottomScreen)
		end
	end
end
-------------------------------------------------------------------------------
function LootDrop:AccountCurrencies()
	local undaunted = ((self.db.currency.showUndaunted) or (self.db.chat.DbgLogUndauntedKey))
	local transmute = ((self.db.currency.showTransmute) or (self.db.chat.DbgLogTransmuteCrystal))
	local eticket = ((self.db.currency.showEticket) or (self.db.chat.DbgLogEventTicket))
	local endeavor = ((self.db.currency.showEndeavor) or (self.db.chat.DbgLogEndeavor))
	local endless = ((self.db.currency.showEndless) or (self.db.chat.DbgLogEndless))

-- register EVENT_CURRENCY_UPDATE if any currency that needs it is enabled
	if ( undaunted ) or ( transmute ) or ( eticket ) or ( endeavor ) or ( endless ) then
		self.control:RegisterForEvent( EVENT_CURRENCY_UPDATE, function( _, ... ) self:OnCurrencyUpdate( ... ) end )
	else
		self.control:UnregisterForEvent( EVENT_CURRENCY_UPDATE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleLoot()
	if ((self.db.loot.showLoot) or (self.db.chat.DbgLogMine) or (self.db.chat.DbgLogOthers)) then
		self.control:RegisterForEvent( EVENT_LOOT_RECEIVED,function( _, ... )  self:OnLootReceived( ... )    end )
	-- Pre-filter heavy events where possible to improve performance: https://wiki.esoui.com/AddFilterForEvent (Phinix)
		EVENT_MANAGER:RegisterForEvent('LootDrop_Filter_Bag1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function( ... ) self:OnSingleSlotUpdate( ... ) end)
		EVENT_MANAGER:AddFilterForEvent('LootDrop_Filter_Bag1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		EVENT_MANAGER:RegisterForEvent('LootDrop_Filter_Bag2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function( ... ) self:OnSingleSlotUpdate( ... ) end)
		EVENT_MANAGER:AddFilterForEvent('LootDrop_Filter_Bag2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_VIRTUAL)
		EVENT_MANAGER:RegisterForEvent('LootDrop_Filter_Reason', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function( ... ) self:OnSingleSlotUpdate( ... ) end)
		EVENT_MANAGER:AddFilterForEvent('LootDrop_Filter_Reason', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
	else
		self.control:UnregisterForEvent( EVENT_LOOT_RECEIVED )
		EVENT_MANAGER:UnregisterForEvent('LootDrop_Filter_Bag1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent('LootDrop_Filter_Bag2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent('LootDrop_Filter_Reason', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
	end
	CBM:RegisterCallback( LootDropConfig.EVENT_SHOW_PREVIEW, function() self:LootPreview() end )
end
-------------------------------------------------------------------------------
function LootDrop:ToggleMailLoot()
	if ( self.db.loot.mailLoot ) and ( self.db.loot.showLoot )then
		self.control:RegisterForEvent( EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function( _, ... ) self:OnMailItemLooted( ... )    end )
		self.control:RegisterForEvent( EVENT_MAIL_READABLE, function( _, ... ) self:OnMailReadable( ... )    end )
	else
		self.control:UnregisterForEvent( EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS )
		self.control:UnregisterForEvent( EVENT_MAIL_READABLE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleGroupName()
	LootDrop.GroupNames = {}
	if (self.db.chat.DbgLogOthers) and self.db.chat.DbgLogGname ~= 0 then
		self.control:RegisterForEvent( EVENT_GROUP_TYPE_CHANGED, function( _, ... ) self:OnGroupChanged( ... ) end )
		self.control:RegisterForEvent( EVENT_GROUP_MEMBER_JOINED, function( _, ... ) self:OnGroupChanged( ... ) end )
		self.control:RegisterForEvent( EVENT_GROUP_MEMBER_LEFT, function( _, ... ) self:OnGroupChanged( ... ) end )
		self.control:RegisterForEvent( EVENT_GROUP_UPDATE, function( _, ... ) self:OnGroupChanged( ... ) end )
		self:OnGroupChanged()
	else
		self.control:UnregisterForEvent( EVENT_GROUP_TYPE_CHANGED )
		self.control:UnregisterForEvent( EVENT_GROUP_MEMBER_JOINED )
		self.control:UnregisterForEvent( EVENT_GROUP_MEMBER_LEFT )
		self.control:UnregisterForEvent( EVENT_GROUP_UPDATE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleCoin()
	if ((self.db.gold.showGold) or (self.db.chat.DbgLogGold)) then
		self.control:RegisterForEvent( EVENT_MONEY_UPDATE, function( _, ... ) self:OnMoneyUpdated( ... )  end )
	else
		self.control:UnregisterForEvent( EVENT_MONEY_UPDATE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleXP()
	if ((self.db.XP.showXP) or (self.db.chat.DbgLogXP)) then
		self.control:RegisterForEvent( EVENT_EXPERIENCE_GAIN, function( _, ... ) self:OnXPUpdated( ... )     end )
	else
		self.control:UnregisterForEvent( EVENT_EXPERIENCE_GAIN )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleAP()
	if ((self.db.AP.showAP) or (self.db.chat.DbgLogAP)) then
		self.control:RegisterForEvent( EVENT_ALLIANCE_POINT_UPDATE, function( _, ... ) self:OnAPUpdate( ... ) end )
	else
        self.control:UnregisterForEvent( EVENT_ALLIANCE_POINT_UPDATE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleVP()
	if ((self.db.VP.showVP) or (self.db.chat.DbgLogVP)) then
		self.control:RegisterForEvent( EVENT_REWARD_TRACK_PROGRESS_GAINED, function( _, ... ) self:OnVPUpdate( ... ) end )
	else
        self.control:UnregisterForEvent( EVENT_REWARD_TRACK_PROGRESS_GAINED )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleTV()
	if ((self.db.currency.showTelvar) or (self.db.chat.DbgLogTelvar)) then
		self.control:RegisterForEvent( EVENT_TELVAR_STONE_UPDATE, function( _, ... ) self:OnTVUpdate( ... ) end )
	else
		self.control:UnregisterForEvent( EVENT_TELVAR_STONE_UPDATE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleWVoucher()
	if ((self.db.currency.showVoucher) or (self.db.chat.DbgLogWritVoucher)) then
		self.control:RegisterForEvent( EVENT_WRIT_VOUCHER_UPDATE, function( _, ... ) self:OnWVoucherUpdate( ... ) end )
	else
		self.control:UnregisterForEvent( EVENT_WRIT_VOUCHER_UPDATE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleBookProgress()
	if ((self.db.loot.bookLoot) or (self.db.chat.DbgLogBookLoot)) then
		self.control:RegisterForEvent( EVENT_LORE_BOOK_LEARNED, function( _, ... ) self:OnLoreBookLearned( ... ) end )
	else
		self.control:UnregisterForEvent( EVENT_LORE_BOOK_LEARNED )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleCompanionXP()
	if ((self.db.compXP.showXP) or (self.db.chat.DbgLogCXp)) and (HasActiveCompanion()) then
		self.control:RegisterForEvent(EVENT_COMPANION_EXPERIENCE_GAIN, function(_, ... ) self:CompanionXPUpdate(...) end )
	else
		self.control:UnregisterForEvent( EVENT_COMPANION_EXPERIENCE_GAIN )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleCompanionRapport()
	if ((self.db.rapport.showRppt) or (self.db.chat.DbgLogCRpt)) and (HasActiveCompanion()) then
		self.control:RegisterForEvent(EVENT_COMPANION_RAPPORT_UPDATE, function(_, ... ) self:CompanionRapportUpdate(...) end )
	else
		self.control:UnregisterForEvent( EVENT_COMPANION_RAPPORT_UPDATE )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleAchievements()
	if ((self.db.achievements.showAchieve) and (self.db.achievements.showCompleted)) or (self.db.chat.DbgCAchievements) then
		self.control:RegisterForEvent(EVENT_ACHIEVEMENT_AWARDED, function(_, ... ) self:AchievementComplete(...) end )
	else
		self.control:UnregisterForEvent( EVENT_ACHIEVEMENT_AWARDED )
	end

	if ((self.db.achievements.showAchieve) and (self.db.achievements.showProgress)) or (self.db.chat.DbgPAchievements) then
		self.control:RegisterForEvent(EVENT_ACHIEVEMENT_UPDATED, function(_, ... ) self:AchievementUpdated(...) end )
	else
		self.control:UnregisterForEvent( EVENT_ACHIEVEMENT_UPDATED )
	end
end
-------------------------------------------------------------------------------
function LootDrop:ToggleSkillXP()
	local lootSkills = ((self.db.skills.showCraft) or (self.db.skills.showFence) or (self.db.skills.showBooks) or (self.db.skills.showGuilds) or (self.db.skills.showWeapon) or (self.db.skills.showArmor) or (self.db.skills.showWorld) or (self.db.skills.showAvA))
	local chatSkills = ((self.db.chat.DbgLogCraftXP) or (self.db.chat.DbgLogFenceXP) or (self.db.chat.DbgLogBookKnowledge) or (self.db.chat.DbgLogGuildRep) or (self.db.chat.DbgLogWeapon) or (self.db.chat.DbgLogArmor) or (self.db.chat.DbgLogWorld) or (self.db.chat.DbgLogAvA))

	if ((self.db.skills.showSkills) and (lootSkills) or (chatSkills)) then
		self.control:RegisterForEvent( EVENT_SKILL_XP_UPDATE, function( ... ) self:OnSkillXPUpdated( ... )     end )
	else
		self.control:UnregisterForEvent( EVENT_SKILL_XP_UPDATE )
	end
end
-------------------------------------------------------------------------------
--- Check if any flags are set
-- if no flag is passed will check if any flag is set.
-- @tparam DirtyFlags flag
-- @treturn boolean
function LootDrop:IsDirty( flag )
	if ( not flag ) then return #self.dirty_flags ~= 0 end

	for _,v in pairs( self.dirty_flags ) do
		if ( v == flag ) then
			return true
		end
	end

	return false
end
-------------------------------------------------------------------------------
function LootDrop:OnMoveStop()
	if (not self.loaded) or ((IsPreviewPanel ~= 0) and (IsPreviewPanel ~= 3)) then
		return
	end

	local _, _, rightScreen, bottomScreen  = GuiRoot:GetScreenRect()
	local _, _, right, bottom = self.control:GetScreenRect()

	self.db.lootdrop_x = math.floor(right-rightScreen)
	self.db.lootdrop_y = math.floor(bottom-bottomScreen)
end
-------------------------------------------------------------------------------
--- On every consecutive frame
function LootDrop:OnUpdate( frameTime )
	if frameTime < LootDrop.NextUpdate then
		return
	else
		LootDrop.NextUpdate = frameTime + 0.1 -- set delay between updates to improve performance (Phinix)
		if (not self.loaded) then return end

		local function showMeters()
			if IsInImperialCity() then ZO_HUDTelvarMeter:SetHidden(false) end
			if GetBounty() > 0 then ZO_HUDInfamyMeter:SetHidden(false) end
		end

		if (not #self._active) then if self.db.general.hideMeters then showMeters() return else return end end

		if self.db.general.hideMeters then -- hide/show telvarUI & infamy meter
			if #self._active > 0 then
				ZO_HUDTelvarMeter:SetHidden(true)
				ZO_HUDInfamyMeter:SetHidden(true)
			else
				showMeters()
			end
		end

		local i = 1
		local entry = nil
		local ft = frameTime * 1000
		local mStacks = self.db.display.maxstacks
		local releaseQ = {}

		if (not IsChecking) then -- possibly avoid race-condition-related clearing of still valid loot display (Phinix)
			IsChecking = true
			self.hasHidden = false

			while( i <= #self._active ) do
				entry = self._active[ i ]

				if ( ft - entry:GetTimestamp() > self.db.display.dDuration * 1000 ) then
					if ( not entry:IsVisible() ) then
						entry:SetTimestamp( GetFrameTimeMilliseconds() ) -- avoid dropping items that are past your visible limit and haven't shown yet (Phinix)
						self.hasHidden = true
					else
						self:Release( entry )
						tinsert( self.dirty_flags, DirtyFlags.LAYOUT )
					end
				else
					if i > mStacks then
						self.hasHidden = true
						tinsert( self.dirty_flags, DirtyFlags.LAYOUT )
					end
				end
				i = i + 1
			end

			if ( self:IsDirty( DirtyFlags.LAYOUT ) ) then
				local last_y = 0
				local last_x = 0
				local entry = nil
				local increment = false

				if (not self.db.display.moveUp) then
					local xdim, ydim = self.control:GetDimensions()
					--y is count from the bottom right, so the top is negative number
					last_y = ( self.db.display.height + self.db.display.padding ) - ydim
					last_x = ( self.db.display.width) - xdim
				end

				for i = 1, #self._active do
					entry = self._active[ i ]
					increment = false

					if ( not entry:IsVisible() ) then
						entry:SetTimestamp( GetFrameTimeMilliseconds() ) -- avoid dropping items that are past your visible limit and haven't shown yet (Phinix)
						if i <= mStacks then  -- if entry number is less than mStacks we show the entry
							if entry.enter_animation then
								entry:Show( last_x, last_y )
								increment = true
							end
						end
					else
						if i > mStacks then -- if entry number is more than mStacks we hide the entry
							entry:SetTimestamp( GetFrameTimeMilliseconds() ) -- avoid dropping items that are past your visible limit and haven't shown yet (Phinix)
							entry.control:SetAlpha( 0.0 )
						else
							entry:Move( last_x, last_y )
							increment = true
						end
					end

					if (increment) then
						if (self.db.display.moveUp) then
							last_y = last_y - ( self.db.display.height + self.db.display.padding )
						else
							--y is count from the bottom right and last y is negative number
							last_y = last_y + ( self.db.display.height + self.db.display.padding )
						end
					end
				end
			end

			if self.db.display.showHidden and self.hasHidden then -- show indicator for how many loot items remain to be shown (Phinix)
				local hNumber = #self._active - mStacks
				if hNumber > 0 then
					local StartHeight = ( mStacks ) * ( self.db.display.height + self.db.display.padding )
	
					LootDropGui_Total:ClearAnchors()
					if (self.db.display.moveUp) then
						LootDropGui_Total:SetAnchor( BOTTOMRIGHT, LootDropGui, BOTTOMRIGHT, self.db.display.hOffset, - StartHeight )
					else
						LootDropGui_Total:SetAnchor( TOPRIGHT, LootDropGui, TOPRIGHT, self.db.display.hOffset, StartHeight )
					end

					LootDropGui_Total:SetText("+ "..tostring(hNumber))
					LootDropGui_Total:SetHidden(false)
				else
					LootDropGui_Total:SetHidden(true)
				end
			else
				LootDropGui_Total:SetHidden(true)
			end

			self.dirty_flags = {}
			IsChecking = false
		end
	end
end
-------------------------------------------------------------------------------
--- Create a new loot droppable
-- @tparam ZO_ObjectPool _ unused
function LootDrop:CreateDroppable()
	return LootDroppable:New( self )
end
-------------------------------------------------------------------------------
--- Reset a loot droppable
-- @tparam LootDroppable droppable 
function LootDrop:ResetDroppable( droppable, name, key )
	if ( key == self._coinId ) then
		self._coinId = nil
		self._coinLastVal = 0
	elseif( key == self._apId ) then
		self._apId = nil
		self._apLastVal = 0
		self._apLastRPVal = 0
		self._apLastRP = GetUnitAvARankPoints("player")
	elseif( key == self._vpId ) then
		self._vpId = nil
		self._vpLastVal = 0
		self._vpLastVPVal = 0
    local _, _, progress = GetInfoForRewardTrack(REWARD_TRACK_TYPE_AVA_VETERANCY, GetReferenceTrackIndex(REWARD_TRACK_TYPE_AVA_VETERANCY, GetActiveReferenceTrackIdsForRewardTrackType(REWARD_TRACK_TYPE_AVA_VETERANCY)))
		self._vpLastVP = progress
	elseif( key == self._rpId ) then
		self._rpId = nil
	elseif( key == self._tvId ) then
		self._tvId   = nil
		self._tvLastVal = 0
	elseif( key == self._wVoucherId ) then
		self._wVoucherId   = nil
		self._wVoucherLastVal = 0
	elseif( key == self._undauntedId ) then
		self._undauntedId   = nil
		self._undauntedLastVal = 0
	elseif( key == self._transmuteId ) then
		self._transmuteId   = nil
		self._transmuteLastVal = 0
	elseif( key == self._eticketId ) then
		self._eticketId   = nil
		self._eticketLastVal = 0
	elseif( key == self._EndeavorId ) then
		self._EndeavorId   = nil
		self._EndeavorLastVal = 0
	elseif( key == self._EndlessId ) then
		self._EndlessId   = nil
		self._EndlessLastVal = 0
	elseif( key == self._FragmentsId ) then
		self._FragmentsId   = nil
		self._FragmentsLastVal = 0
	elseif( key == self._TomePointsId ) then
		self._TomePointsId   = nil
		self._TomePointsLastVal = 0
	elseif( key == self._TomePointCachesId ) then
		self._TomePointCachesId   = nil
		self._TomePointCachesLastVal = 0
	elseif( key == self._TomeTokensId ) then
		self._TomeTokensId   = nil
		self._TomeTokensLastVal = 0
	elseif( key == self._TradeBarsId ) then
		self._TradeBarsId   = nil
		self._TradeBarsLastVal = 0
	elseif( key == self._xpId ) then
		self._xpId = nil
		self._xpLastVal = 0
	elseif( key == self._xpCompanionId ) then
		self._xpCompanionId = nil
		self._xpCompanionLastVal = 0
	elseif( key == self._rapportId ) then
		self._rapportId = nil
		self._rapportLastVal = 0
	elseif ( key == self._skillMageXpId ) then
		self._skillMageXpId = nil
		self._skillMageXpLastVal = 0
	elseif ( key == self._skillFighterXpId ) then
		self._skillFighterXpId = nil
		self._skillFighterXpLastVal = 0
	elseif ( key == self._skillThievesXpId ) then
		self._skillThievesXpId = nil
		self._skillThievesXpLastVal = 0
	elseif ( key == self._skillUndauntedXpId ) then
		self._skillUndauntedXpId = nil
		self._skillUndauntedXpLastVal = 0
	elseif ( key == self._skillOtherGuildXpId ) then
		self._skillOtherGuildXpId = nil
		self._skillOtherGuildXpLastVal = 0
	elseif ( key == self._skillPsijicXpId ) then
		self._skillPsijicXpId = nil
		self._skillPsijicXpLastVal = 0
	elseif ( key == self._skillBookXpId ) then
		self._skillBookXpId = nil
		self._skillBookXpLastVal = 0
	elseif ( key == self._skillFenceXpId ) then
		self._skillFenceXpId = nil
		self._skillFenceXpLastVal = 0
	elseif ( key == self._skillBrotherhoodXpId ) then
		self._skillBrotherhoodXpId = nil
		self._skillBrotherhoodXpLastVal = 0
	elseif ( key == self._skillBlacksmithingXpId ) then
		self._skillBlacksmithingXpId = nil
		self._skillBlacksmithingXpLastVal = 0
	elseif ( key == self._skillClothierXpId ) then
		self._skillClothierXpId = nil
		self._skillClothierXpLastVal = 0
	elseif ( key == self._skillEnchantingXpId ) then
		self._skillEnchantingXpId = nil
		self._skillEnchantingXpLastVal = 0
	elseif ( key == self._skillAlchemyXpId ) then
		self._skillAlchemyXpId = nil
		self._skillAlchemyXpLastVal = 0
	elseif ( key == self._skillProvisioningXpId ) then
		self._skillProvisioningXpId = nil
		self._skillProvisioningXpLastVal = 0
	elseif ( key == self._skillWoodworkingXpId ) then
		self._skillWoodworkingXpId = nil
		self._skillWoodworkingXpLastVal = 0
	elseif ( key == self._skillJewelcraftingXpId ) then
		self._skillJewelcraftingXpId = nil
		self._skillJewelcraftingXpLastVal = 0
	else 
		-- achievement reset
		for k, v in pairs(self._achieveTable) do
			if v == key then self._achieveTable[k] = nil end
		end

		-- skill line reset
		for k, v in pairs(self._skillTableArmor) do 
			if key == v.key then v.key = nil v.val = 0 end
		end
		for k, v in pairs(self._skillTableAvA) do
			if key == v.key then v.key = nil v.val = 0 end
		end
		for k, v in pairs(self._skillTableWeapon) do
			if key == v.key then v.key = nil v.val = 0 end
		end
		for k, v in pairs(self._skillTableWorld) do
			if key == v.key then v.key = nil v.val = 0 end
		end
	end

	droppable:Hide(name)
end

-------------------------------------------------------------------------------
--- Reset preview values
-- @tparam LootDroppable droppable 
function LootDrop:ResetPreview()
	self._preview_gold = 100
	self._preview_level = 0
	self._preview_XP = 1
	self._preview_telvar = 0
	self._preview_voucher = 0
	self._preview_undaunted = 0
	self._preview_transmute = 0
	self._preview_eticket = 0
	self._preview_endeavor = 0
	self._preview_endless = 0
	self._preview_fragments = 0
	self._preview_TomePoints = 0
	self._preview_TomePointCaches = 0
	self._preview_TomeTokens = 0
	self._preview_TradeBars = 0
	self._preview_clevel = 0
	self._preview_cXP = 0
	self._preview_rapport = 0

	self._coinLastVal					= 0
	self._xpLastVal						= 0
	self._xpCompanionLastVal			= 0
	self._rapportLastVal				= 0
	self._apLastVal						= 0
	self._apLastRPVal					= 0
	self._apLastRP						= GetUnitAvARankPoints("player")
	self._vpLastVal						= 0
	self._vpLastVPVal					= 0
  local _, _, progress = GetInfoForRewardTrack(REWARD_TRACK_TYPE_AVA_VETERANCY, GetReferenceTrackIndex(REWARD_TRACK_TYPE_AVA_VETERANCY, GetActiveReferenceTrackIdsForRewardTrackType(REWARD_TRACK_TYPE_AVA_VETERANCY)))
	self._vpLastVP = progress
	self._tvLastVal						= 0
	self._wVoucherLastVal				= 0
	self._undauntedLastVal				= 0
	self._transmuteLastVal				= 0
	self._eticketLastVal				= 0
	self._EndeavorLastVal				= 0
	self._EndlessLastVal				= 0
	self._FragmentsLastVal				= 0
	self._TomePointsLastVal				= 0
  self._TomePointCachesLastVal		= 0
  self._TomeTokensLastVal				= 0
  self._TradeBarsLastVal				= 0  
	self._skillXpLastVal				= 0
	self._skillMageXpLastVal			= 0
	self._skillFighterXpLastVal			= 0
	self._skillUndauntedXpLastVal		= 0
	self._skillOtherGuildXpLastVal		= 0
	self._skillPsijicXpLastVal			= 0
	self._skillFenceXpLastVal			= 0
	self._skillThievesXpLastVal			= 0
	self._skillBrotherhoodXpLastVal		= 0
	self._skillBlacksmithingXpLastVal	= 0
	self._skillClothierXpLastVal		= 0
	self._skillEnchantingXpLastVal		= 0
	self._skillAlchemyXpLastVal			= 0
	self._skillProvisioningXpLastVal	= 0
	self._skillWoodworkingXpLastVal		= 0
	self._skillJewelcraftingXpLastVal	= 0

	for k, v in pairs(self._skillTableArmor) do v.val = 0 end
	for k, v in pairs(self._skillTableAvA) do v.val = 0 end
	for k, v in pairs(self._skillTableWeapon) do v.val = 0 end
	for k, v in pairs(self._skillTableWorld) do v.val = 0 end
end
-------------------------------------------------------------------------------
 -- Convert decimal r,g,b,a table to hex string (Phinix)
function LootDrop:num2hex(ntable)
	local cstring = ""
	for i = 1, 3, 1 do
		local colornum = ntable[i] * 255
		local hexstr = "0123456789abcdef"
		local s = ""
		while colornum > 0 do
			local mod = math.fmod(colornum, 16)
			s = string.sub(hexstr, mod+1, mod+1) .. s
			colornum = math.floor(colornum / 16)
		end
		if #s == 1 then s = "0" .. s end
		if s == "" then s = "00" end
		cstring = cstring .. s
	end
	return cstring
end
-------------------------------------------------------------------------------
function LootDrop:Acquire()
	local result, key = LootDropPool.Acquire( self )
	result:Prepare(self.db.display.moveUp)

	tinsert( self.dirty_flags, DirtyFlags.LAYOUT )

	return result, key
end
-------------------------------------------------------------------------------
function LootDrop:FormatAmount( amount, prefix )
	local tVal = ""
	local flipVal = (amount < 0) and amount * -1 or amount -- ZOS function does not add delimiter to negative number so do it manually (Phinix)

	if (self.db.value.cDelim) then
		if (self.db.value.cDot) then
			tVal = ZO_CommaDelimitNumber( flipVal ):gsub("%,","%.")
		else
			tVal = ZO_CommaDelimitNumber( flipVal )
		end
	elseif (self.db.value.cTrunc) then
		if (self.db.value.cDot) then
			tVal = tostring(ZO_CurrencyControl_FormatCurrency(flipVal, true)):gsub("%,","%.")
		else
			tVal = tostring(ZO_CurrencyControl_FormatCurrency(flipVal, true))
		end
	else
		tVal = tostring(flipVal)
	end

	if (prefix) then
		tVal = (amount < 0) and "-"..tVal or "+"..tVal -- replace the negative value indicator after passing as positive to delimiter function (Phinix)
	end

	return tVal
end
-------------------------------------------------------------------------------
function LootDrop:ParseLink( link )
	if ( type( link ) ~= 'string' ) then
		return nil, nil
	end

	local text, color = zo_parselink( link )

	if (text=="") then
		text = link 
	end

	if color == "" or color == "0" or color == "1" then
		color = 'FFFFFF'
	end

	return text, color
end
-------------------------------------------------------------------------------
function LootDrop:NewParseLink( NewLink )
	if ( type( NewLink ) ~= 'string' ) then
		return nil, nil
	end

	local Text, LinkStyle = zo_parselink( NewLink )
	Text=zo_strformat("<<x:1>>", Text)

	if (Text=="") then
		Text = NewLink 
	end

	return Text, LinkStyle
end
-------------------------------------------------------------------------------
function LootDrop:ResetCurrentItemBag( )
	self.recentLoot = {}
end
-------------------------------------------------------------------------------
function LootDrop:ResetItemToPrint( )
	self.ItemToPrint.iconFileName = "/esoui/art/icons/icon_missing.dds"
	self.ItemToPrint.color        = 'FFFFFF'
	self.ItemToPrint.quantity     = 0
	self.ItemToPrint.nb           = 0
	self.ItemToPrint.text         = ''
	self.ItemToPrint.tag          = ''
	self.ItemToPrint.itemStyle    = nil
end
-------------------------------------------------------------------------------
function LootDrop:ResetCompanionId(companionId)
	if lastCompanion ~= 0 then
		if lastCompanion ~= companionId then
			self._xpCompanionId = nil
			self._xpCompanionLastVal = 0
			self._rapportId = nil
			self._rapportLastVal = 0
		end
	end
	lastCompanion = companionId
end
-------------------------------------------------------------------------------
function LootDrop:GetOutputTab(target)
	if CHAT_SYSTEM and CHAT_SYSTEM.containers and CHAT_SYSTEM.containers[1] and CHAT_SYSTEM.containers[1].windows and CHAT_SYSTEM.containers[1].windows[target] then
		return target
	else
		return self.db.lootdrop_tab
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnSkillXPUpdated( eventCode,  skillType,  skillIndex,  reason,  rank,  previousXP,  currentXP, v1, preview, cType) 

	local isPreview = (preview ~= nil and preview == "preview") and true or false

-- for reference...

--[[ SkillType
    -- SKILL_TYPE_NONE			= 0
    -- SKILL_TYPE_CLASS			= 1                -- not done
		skillIndex: 1				- Ardent Flame
		skillIndex: 2				- Draconic Power
		skillIndex: 3				- Earthen Heart
		skillIndex: 4				- Aedric Spear
		skillIndex: 5				- Dawn's Wrath
		skillIndex: 6				- Restoring Light
		skillIndex: 7				- Assassination
		skillIndex: 8				- Shadow
		skillIndex: 9				- Siphoning
		skillIndex: 10				- Dark Magic
		skillIndex: 11				- Daedric Summoning
		skillIndex: 12				- Storm Calling
		skillIndex: 13				- Animal Companions
		skillIndex: 14				- Green Balance
		skillIndex: 15				- Winter's Embrace
		skillIndex: 16				- Grave Lord
		skillIndex: 17				- Bone Tyrant
		skillIndex: 18				- Living Death
    -- SKILL_TYPE_WEAPON		= 2
		skillIndex: 1				- Two Handed
		skillIndex: 2				- One Hand and Shield
		skillIndex: 3				- Dual Wield
		skillIndex: 4				- Bow
		skillIndex: 5				- Destruction Staff
		skillIndex: 6				- Restoration Staff
    -- SKILL_TYPE_ARMOR			= 3
		skillIndex: 1				- Light Armor
		skillIndex: 2				- Medium Armor
		skillIndex: 3				- Heavy Armor
    -- SKILL_TYPE_WORLD			= 4
		skillIndex: 1				- Excavation
		skillIndex: 2				- Legerdemain
		skillIndex: 3				- Scrying
		skillIndex: 4				- Soul Magic
		skillIndex: 5				- Vampire
		skillIndex: 6				- Werewolf
    -- SKILL_TYPE_GUILD			= 5
		skillIndex: 1				- Dark Brotherhood
		skillIndex: 2				- Fighters Guild
		skillIndex: 3				- Mages Guild
		skillIndex: 4				- Psijic Order
		skillIndex: 5				- Thieves Guild
		skillIndex: 6				- Undaunted
    -- SKILL_TYPE_AVA			= 6
		skillIndex: 1				- Assault
		skillIndex: 2				- Emperor
		skillIndex: 3				- Support
    -- SKILL_TYPE_RACIAL		= 7               -- not done
		skillIndex: 1				- Dark Elf Skills
		skillIndex: 2				- Orc Skills
		skillIndex: 3				- High Elf Skills
		skillIndex: 4				- Wood Elf Skills
		skillIndex: 5				- Khajiit Skills
		skillIndex: 6				- Imperial Skills
		skillIndex: 7				- Breton Skills
		skillIndex: 8				- Redguard Skills
		skillIndex: 9				- Argonian Skills
		skillIndex: 10				- Nord Skills
    -- SKILL_TYPE_TRADESKILL	= 8
		skillIndex: 1				- Alchemy
		skillIndex: 2				- Blacksmithing
		skillIndex: 3				- Clothing
		skillIndex: 4				- Enchanting
		skillIndex: 5				- Jewelry Crafting
		skillIndex: 6				- Provisioning
		skillIndex: 7				- Woodworking
    -- SKILL_TYPE_CHAMPION		= 9
	]]
--[[ reason
	-- PROGRESS_REASON_ACHIEVEMENT = 25
	-- PROGRESS_REASON_ACTION = 13
	-- PROGRESS_REASON_ALLIANCE_POINTS = 33
	-- PROGRESS_REASON_ANTIQUITY_COMPLETED_DIGGING = 42 -- new
	-- PROGRESS_REASON_ANTIQUITY_COMPLETED_SCRYING = 41 -- new
	-- PROGRESS_REASON_AVA = 15
	-- PROGRESS_REASON_BATTLEGROUND = 6
	-- PROGRESS_REASON_BOOK_COLLECTION_COMPLETE = 12
	-- PROGRESS_REASON_BOSS_KILL = 26
	-- PROGRESS_REASON_COLLECT_BOOK = 11
	-- PROGRESS_REASON_COMMAND = 4
	-- PROGRESS_REASON_COMPLETE_POI = 2
	-- PROGRESS_REASON_DARK_ANCHOR_CLOSED = 28
	-- PROGRESS_REASON_DARK_FISSURE_CLOSED = 29
	-- PROGRESS_REASON_DISCOVER_POI = 3
	-- PROGRESS_REASON_DRAGON_KILL = 39
	-- PROGRESS_REASON_DUNGEON_CHALLENGE = 35
	-- PROGRESS_REASON_EVENT = 27
	-- PROGRESS_REASON_FINESSE = 9
	-- PROGRESS_REASON_GRANT_REPUTATION = 32
	-- PROGRESS_REASON_GUILD_REP = 14
	-- PROGRESS_REASON_HARROWSTORM_COMPLETED = 40 -- new
	-- PROGRESS_REASON_JUSTICE_SKILL_EVENT = 36
	-- PROGRESS_REASON_KEEP_REWARD = 5
	-- PROGRESS_REASON_KILL = 0
	-- PROGRESS_REASON_LFG_REWARD = 37
	-- PROGRESS_REASON_LOCK_PICK = 10
	-- PROGRESS_REASON_MEDAL = 8
	-- PROGRESS_REASON_NONE = -1
	-- PROGRESS_REASON_OTHER = 31
	-- PROGRESS_REASON_OVERLAND_BOSS_KILL = 24
	-- PROGRESS_REASON_PVP_EMPEROR = 34
	-- PROGRESS_REASON_QUEST = 1
	-- PROGRESS_REASON_REWARD = 17
	-- PROGRESS_REASON_SCRIPTED_EVENT = 7
	-- PROGRESS_REASON_SKILL_BOOK = 30
	-- PROGRESS_REASON_TRADESKILL = 16
	-- PROGRESS_REASON_TRADESKILL_ACHIEVEMENT = 18
	-- PROGRESS_REASON_TRADESKILL_CONSUME = 20
	-- PROGRESS_REASON_TRADESKILL_HARVEST = 21
	-- PROGRESS_REASON_TRADESKILL_QUEST = 19
	-- PROGRESS_REASON_TRADESKILL_RECIPE = 22
	-- PROGRESS_REASON_TRADESKILL_TRAIT = 23
	-- PROGRESS_REASON_WORLD_EVENT_COMPLETED = 38
	]]

	local bprint=false
	local cprint=false
	local tag=''
	local tab = self.db.lootdrop_tab
	local color='6BB5FF'
	local icon = LootDrop_sSkillXpIcon
	local dropid
	local lastval
	local skillLineData = SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(skillType, skillIndex)

	local lastSkillXP, nextSkillXP, currentSkillXP
	local skillName, skillRank
	local CraftType
	local pName = ""

	if (isPreview) then
		lastSkillXP, nextSkillXP, currentSkillXP = 0, 8, 0 -- just fake some values so preview is easier (Phinix)
		skillName, skillRank = GetSkillLineInfo(skillType, skillIndex)
		skillRank = math.random(1,50)
		isActive = true
	else
		lastSkillXP, nextSkillXP, currentSkillXP = GetSkillLineXPInfo(skillType, skillIndex)
		skillName, skillRank = GetSkillLineInfo(skillType, skillIndex)
		isActive = (skillLineData:IsActive()) and true or false
	end

	local maxedSkill = (nextSkillXP == 0)
	local cSkillName = ""

	--Skill Xp from craft
	if (( skillType == SKILL_TYPE_TRADESKILL ) and (reason == PROGRESS_REASON_TRADESKILL)) then
		bprint=((self.db.skills.showCraft) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogCraftXP)
		tag='CRAFT'
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogCraftXP)

		--[[ TradeskillType (CraftType)
			-- CRAFTING_TYPE_ALCHEMY			4
			-- CRAFTING_TYPE_BLACKSMITHING		1
			-- CRAFTING_TYPE_CLOTHIER			2
			-- CRAFTING_TYPE_ENCHANTING			3
			-- CRAFTING_TYPE_INVALID			0
			-- CRAFTING_TYPE_JEWELRYCRAFTING	7 -- new
			-- CRAFTING_TYPE_PROVISIONING		5
			-- CRAFTING_TYPE_WOODWORKING		6
			]]

		if (isPreview) then
			CraftType = cType
		else
			CraftType = GetCraftingInteractionType()
		end
		cSkillName = (self.db.skills.craftSColor) and '|c'..LootDrop:num2hex(self.db.skills.craftColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'

		if (CraftType == CRAFTING_TYPE_BLACKSMITHING) then
			pName = "skill_blacksmithing"
			icon = (self.db.skills.oldSkillIcons) and LootDrop_sAnvilXpIcon or LootDrop_sColorBlacksmithingIcon
			dropid = self._skillBlacksmithingXpId
			lastval = self._skillBlacksmithingXpLastVal
		elseif (CraftType == CRAFTING_TYPE_CLOTHIER) then
			pName = "skill_clothier"
			icon = (self.db.skills.oldSkillIcons) and LootDrop_sClothierXpIcon or LootDrop_sColorClothingIcon
			dropid = self._skillClothierXpId
			lastval = self._skillClothierXpLastVal
		elseif (CraftType == CRAFTING_TYPE_ENCHANTING) then
			pName = "skill_enchanting"
			icon = (self.db.skills.oldSkillIcons) and LootDrop_sEnchanterXpIcon or LootDrop_sColorEnchantingIcon
			dropid = self._skillEnchantingXpId
			lastval = self._skillEnchantingXpLastVal
		elseif (CraftType == CRAFTING_TYPE_ALCHEMY) then
			pName = "skill_alchemy"
			icon = (self.db.skills.oldSkillIcons) and LootDrop_sAlchemyXpIcon or LootDrop_sColorAlchemyIcon
			dropid = self._skillAlchemyXpId
			lastval = self._skillAlchemyXpLastVal
		elseif (CraftType == CRAFTING_TYPE_PROVISIONING) then
			pName = "skill_provisioning"
			icon = (self.db.skills.oldSkillIcons) and LootDrop_sProvisioningXpIcon or LootDrop_sColorProvisioningIcon
			dropid = self._skillProvisioningXpId
			lastval = self._skillProvisioningXpLastVal
		elseif (CraftType == CRAFTING_TYPE_WOODWORKING) then
			pName = "skill_woodworking"
			icon = (self.db.skills.oldSkillIcons) and LootDrop_sWoodXpIcon or LootDrop_sColorWoodworkingIcon
			dropid = self._skillWoodworkingXpId
			lastval = self._skillWoodworkingXpLastVal
		elseif (CraftType == CRAFTING_TYPE_JEWELRYCRAFTING) then
			pName = "skill_jewelcrafting"
			icon = (self.db.skills.oldSkillIcons) and LootDrop_sJewelrycraftingXpIcon or LootDrop_sColorJewelcraftingIcon
			dropid = self._skillJewelcraftingXpId
			lastval = self._skillJewelcraftingXpLastVal
		else -- craft book
			local craftTable = {
				[1] = {pName = "skill_alchemy", icon = (self.db.skills.oldSkillIcons) and LootDrop_sAlchemyXpIcon or LootDrop_sColorAlchemyIcon},						-- Alchemy
				[2] = {pName = "skill_blacksmithing", icon = (self.db.skills.oldSkillIcons) and LootDrop_sAnvilXpIcon or LootDrop_sColorBlacksmithingIcon},				-- Blacksmithing
				[3] = {pName = "skill_clothier", icon = (self.db.skills.oldSkillIcons) and LootDrop_sClothierXpIcon or LootDrop_sColorClothingIcon},					-- Clothing
				[4] = {pName = "skill_enchanting", icon = (self.db.skills.oldSkillIcons) and LootDrop_sEnchanterXpIcon or LootDrop_sColorEnchantingIcon},				-- Enchanting
				[5] = {pName = "skill_jewelcrafting", icon = (self.db.skills.oldSkillIcons) and LootDrop_sJewelrycraftingXpIcon or LootDrop_sColorJewelcraftingIcon},	-- Jewelry Crafting
				[6] = {pName = "skill_provisioning", icon = (self.db.skills.oldSkillIcons) and LootDrop_sProvisioningXpIcon or LootDrop_sColorProvisioningIcon},		-- Provisioning
				[7] = {pName = "skill_woodworking", icon = (self.db.skills.oldSkillIcons) and LootDrop_sWoodXpIcon or LootDrop_sColorWoodworkingIcon},					-- Woodworking
			}
			pName = (craftTable[skillIndex] ~= nil) and craftTable[skillIndex].pName or "skill_book"
			icon = (craftTable[skillIndex] ~= nil) and craftTable[skillIndex].icon or LootDrop_sBooksXpIcon
			bprint=((self.db.skills.showBooks) and (self.db.skills.showSkills))
			cprint=(self.db.chat.DbgLogBookKnowledge)
			tag='BOOK'
			dropid = self._skillBookXpId
			lastval = self._skillBookXpLastVal
		end

	--Skill Xp GUILD REPUTATION
	elseif ( skillType == SKILL_TYPE_GUILD ) then
		cSkillName = (self.db.skills.guildSColor) and '|c'..LootDrop:num2hex(self.db.skills.guildColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'
		bprint=((self.db.skills.showGuilds) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogGuildRep)
		tag='GUILD'
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogGuildRep)

		if ( skillIndex == 1 ) then -- Dark Brotherhood
			pName = "skill_brotherhood"
			icon = (self.db.skills.oldGuildIcons) and LootDrop_sBrotherhoodXpIcon or skillLineData:GetAnnounceIcon()
			dropid = self._skillBrotherhoodXpId
			lastval = self._skillBrotherhoodXpLastVal
		elseif ( skillIndex == 2 ) then -- Fighters Guild
			pName = "skill_fighters"
			icon = (self.db.skills.oldGuildIcons) and LootDrop_sFighterGuildXpIcon or skillLineData:GetAnnounceIcon()
			dropid = self._skillFighterXpId
			lastval = self._skillFighterXpLastVal
		elseif ( skillIndex == 3 ) then -- Mages Guild
			pName = "skill_mages"
			icon = (self.db.skills.oldGuildIcons) and LootDrop_sMagesGuildXpIcon or skillLineData:GetAnnounceIcon()
			dropid = self._skillMageXpId
			lastval = self._skillMageXpLastVal
		elseif ( skillIndex == 4 ) then -- Psijic Order
			pName = "skill_psijic"
			icon = skillLineData:GetAnnounceIcon()
			dropid = self._skillPsijicXpId
			lastval = self._skillPsijicXpLastVal
		elseif ( skillIndex == 5 ) then -- Thieves Guild
			pName = "skill_thieves"
			icon = (self.db.skills.oldGuildIcons) and LootDrop_sThievesXpIcon or skillLineData:GetAnnounceIcon()
			dropid = self._skillThievesXpId
			lastval = self._skillThievesXpLastVal
		elseif ( skillIndex == 6 ) then -- Undaunted
			pName = "skill_undaunted"
			icon = skillLineData:GetAnnounceIcon()
			dropid = self._skillUndauntedXpId
			lastval = self._skillUndauntedXpLastVal
		else
			pName = "skill_otherguild"
			icon = LootDrop_sOthersGuildXpIcon
			dropid = self._skillOtherGuildXpId
			lastval = self._skillOtherGuildXpLastVal
		end
	-- Fence skill line
	elseif (reason == PROGRESS_REASON_JUSTICE_SKILL_EVENT) then
		cSkillName = (self.db.skills.fenceSColor) and '|c'..LootDrop:num2hex(self.db.skills.fenceColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'
		bprint=((self.db.skills.showFence) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogFenceXP)
		tag='FENCE'
		pName = "skill_justice"
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogFenceXP)
		icon = (self.db.skills.oldSkillIcons) and LootDrop_sFenceXpIcon or "esoui/art/icons/skilllinexp_ledgermain.dds"
		dropid = self._skillFenceXpId
		lastval = self._skillFenceXpLastVal
	--Skill Xp WORLD REPUTATION
	elseif ( skillType == SKILL_TYPE_WORLD ) then
		if maxedSkill or not isActive then return end -- for some reason the game shows you gaining vampire experience even when you don't have it
		if not self._skillTableWorld[skillIndex] then return end
		cSkillName = (self.db.skills.worldSColor) and '|c'..LootDrop:num2hex(self.db.skills.worldColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'
		bprint=((self.db.skills.showWorld) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogWorld)
		tag = self._skillTableWorld[skillIndex].tag
		pName = self._skillTableWorld[skillIndex].pName
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogWorld)
		icon = self._skillTableWorld[skillIndex].icon
		if skillIndex == 1 then -- Excavation
			icon = (self.db.skills.oldSkillIcons) and icon or LootDrop_sColorExcavationIcon
	--	elseif skillIndex == 3 then -- Scrying
	--		icon = (self.db.skills.oldSkillIcons) and icon or LootDrop_sColorScryingIcon
		end
		dropid = self._skillTableWorld[skillIndex].key
		lastval = self._skillTableWorld[skillIndex].val
	--Skill Xp WEAPON PROGRESS
	elseif ( skillType == SKILL_TYPE_WEAPON ) then
		if maxedSkill or not isActive then return end
		if not self._skillTableWeapon[skillIndex] then return end
		cSkillName = (self.db.skills.weaponSColor) and '|c'..LootDrop:num2hex(self.db.skills.weaponColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'
		bprint=((self.db.skills.showWeapon) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogWeapon)
		tag = self._skillTableWeapon[skillIndex].tag
		pName = self._skillTableWeapon[skillIndex].pName
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogWeapon)
		icon = self._skillTableWeapon[skillIndex].icon
		dropid = self._skillTableWeapon[skillIndex].key
		lastval = self._skillTableWeapon[skillIndex].val
	--Skill Xp ARMOR PROGRESS
	elseif ( skillType == SKILL_TYPE_ARMOR ) then
		if maxedSkill or not isActive then return end
		if not self._skillTableArmor[skillIndex] then return end
		cSkillName = (self.db.skills.armorSColor) and '|c'..LootDrop:num2hex(self.db.skills.armorColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'
		bprint=((self.db.skills.showArmor) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogArmor)
		tag = self._skillTableArmor[skillIndex].tag
		pName = self._skillTableArmor[skillIndex].pName
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogArmor)
		icon = self._skillTableArmor[skillIndex].icon
		dropid = self._skillTableArmor[skillIndex].key
		lastval = self._skillTableArmor[skillIndex].val
	--Skill Xp AvA PROGRESS
	elseif ( skillType == SKILL_TYPE_AVA ) then
		if maxedSkill or not isActive then return end
		if not self._skillTableAvA[skillIndex] then return end
		cSkillName = (self.db.skills.AvASColor) and '|c'..LootDrop:num2hex(self.db.skills.AvAColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'
		bprint=((self.db.skills.showAvA) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogAvA)
		tag = self._skillTableAvA[skillIndex].tag
		pName = self._skillTableAvA[skillIndex].pName
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogAvA)
		icon = self._skillTableAvA[skillIndex].icon
		dropid = self._skillTableAvA[skillIndex].key
		lastval = self._skillTableAvA[skillIndex].val
	--Skill XP from books in library
	elseif (reason == PROGRESS_REASON_SKILL_BOOK or reason == PROGRESS_REASON_BOOK_COLLECTION_COMPLETE) then
		cSkillName = (self.db.skills.bookSColor) and '|c'..LootDrop:num2hex(self.db.skills.bookColor)..skillName..'|r' or '|c6BB5FF'..skillName..'|r'
		bprint=((self.db.skills.showBooks) and (self.db.skills.showSkills))
		cprint=(self.db.chat.DbgLogBookKnowledge)
		tag='BOOK'
		pName = "skill_book"
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogBookKnowledge)
		icon = LootDrop_sBooksXpIcon
		dropid = self._skillBookXpId
		lastval = self._skillBookXpLastVal
	else
		return
	end

--	d(skillType)
--	d(skillIndex)
--	d(reason)

	local RealGain
	local SkillXp
	local SkillXpTotal

	if (isPreview) then -- just fake some values so preview is easier (Phinix)
		SkillXp = math.random(5,9999)
		SkillXpTotal = 10000
		RealGain = SkillXpTotal - SkillXp
	else
		SkillXp = (currentSkillXP - lastSkillXP) -- levelCurrent
		SkillXpTotal = SkillXp
		if (not maxedSkill) then
			SkillXpTotal = nextSkillXP - lastSkillXP -- levelCap
		end
		RealGain = currentXP-previousXP
	end

	--DROP LABEL (RealGain value could be stacked in SetSkillNewDrop)
	local pccurrent=0
	if (SkillXpTotal > 0) then
		pccurrent = self:FormatAmount(math.floor(100*(SkillXp/SkillXpTotal)))
	end

	local skillLevel = self.db.skills.skillLevel
	local skillProgress = self.db.skills.skillProgress
	local skillProgFull = self.db.skills.skillProgFull

	local sLevel = (skillLevel) and LootDrop_Spacer..'|c6BB5FF'..L.LevelPsijic.." ".. tostring(skillRank)..'|r' or ""
	local progressMin = zo_strformat( '|c808080(<<1>>%)|r', pccurrent )
	local progressFull = zo_strformat( '|c808080<<1>>/<<2>> (<<3>>%)|r', SkillXp, SkillXpTotal, pccurrent )
	local lProg = ((skillLevel) and (skillProgress) and (skillProgFull)) and progressFull or ((skillLevel) and (skillProgress)) and progressMin or ""

	local pctexts = ""
--	local pctexts = zo_strformat( LootDrop_Spacer..'|c6BB5FF<<1>>|r |c808080(<<2>>%)|r', sLevel, pccurrent )
	if (( skillType == SKILL_TYPE_GUILD ) and ( skillIndex == 4 )) then -- special case for Psijic Order progress always jumps by whole level
		pctexts = zo_strformat( '<<1>>', sLevel )
	else
		pctexts = zo_strformat( '<<1>> <<2>>', sLevel, lProg )
	end

	local sName = (self.db.skills.skillNames) and cSkillName or ""
	local finaltext = zo_strformat( '<<1>> <<2>>', sName, pctexts)
	local finaldbgtext = zo_strformat( '|c6BB5FF<<1>>|r  <<2>>  |c736F6E<<3>>/<<4>>|r  |cFFFFFF[<<t:5>>]|r', self:FormatAmount(RealGain), pctexts, self:FormatAmount(SkillXp), self:FormatAmount(SkillXpTotal), skillName )

	self:SetNewDrop(pName, dropid, color, icon, lastval, RealGain, finaltext, finaldbgtext, tag, skillType, skillIndex, skillRank, CraftType, reason, bprint, cprint, tab)
end
-------------------------------------------------------------------------------
function LootDrop:SetNewDrop(pName, dropid, color, icon, lastval, RealGain, finaltext, finaldbgtext, tag, skillType, skillIndex, skillRank, CraftType, reason, bprint, cprint, tab)
	if ((pName ~= "") and (lastval ~= nil) and (RealGain ~= nil)) then
		local lootEntry, aIndex, isUpdate
		local difference=RealGain
		local RealDiff=difference
	
		if (bprint) then -- allowing to enable chat output when loot display disabled (Phinix)
			if ( dropid ) then
				lootEntry, aIndex, isUpdate = self:Get(pName)
				if isUpdate then
					difference = difference + lastval
				end
			end
	
			if ( not lootEntry ) then
				lootEntry, aIndex = self:Acquire()
				isUpdate = false
			end
		end

		if (bprint) then
			--CRAFT
			if (( skillType == SKILL_TYPE_TRADESKILL ) and (reason == PROGRESS_REASON_TRADESKILL)) then
				if (CraftType == CRAFTING_TYPE_BLACKSMITHING) then
					self._skillBlacksmithingXpId = aIndex
					self._skillBlacksmithingXpLastVal = difference
				elseif (CraftType == CRAFTING_TYPE_CLOTHIER) then
					self._skillClothierXpId = aIndex
					self._skillClothierXpLastVal = difference
				elseif (CraftType == CRAFTING_TYPE_ENCHANTING) then
					self._skillEnchantingXpId = aIndex
					self._skillEnchantingXpLastVal = difference
				elseif (CraftType == CRAFTING_TYPE_ALCHEMY) then
					self._skillAlchemyXpId = aIndex
					self._skillAlchemyXpLastVal = difference
				elseif (CraftType == CRAFTING_TYPE_PROVISIONING) then
					self._skillProvisioningXpId = aIndex
					self._skillProvisioningXpLastVal = difference
				elseif (CraftType == CRAFTING_TYPE_WOODWORKING) then
					self._skillWoodworkingXpId = aIndex
					self._skillWoodworkingXpLastVal = difference
				elseif (CraftType == CRAFTING_TYPE_JEWELRYCRAFTING) then
					self._skillJewelcraftingXpId = aIndex
					self._skillJewelcraftingXpLastVal = difference
				else -- craft book
					self._skillBookXpId = aIndex
					self._skillBookXpLastVal = difference
				end
			--GUILD REPUTATION
			elseif ( skillType == SKILL_TYPE_GUILD ) then
				if ( skillIndex == 1 ) then
					self._skillBrotherhoodXpId = aIndex
					self._skillBrotherhoodXpLastVal = difference
				elseif ( skillIndex == 2 ) then
					self._skillFighterXpId = aIndex
					self._skillFighterXpLastVal = difference
				elseif ( skillIndex == 3 ) then
					self._skillMageXpId = aIndex
					self._skillMageXpLastVal = difference
				elseif ( skillIndex == 4 ) then
					self._skillThievesXpId = aIndex
					self._skillThievesXpLastVal = difference
				elseif ( skillIndex == 5 ) then
					self._skillUndauntedXpId = aIndex
					self._skillUndauntedXpLastVal = difference
				elseif ( skillIndex == 6 ) then
					self._skillPsijicXpId = aIndex
					self._skillPsijicXpLastVal = difference
				else
					self._skillUndauntedXpId = aIndex
					self._skillUndauntedXpLastVal = difference
				end
			--BOOKS
			elseif (reason == PROGRESS_REASON_SKILL_BOOK or reason == PROGRESS_REASON_BOOK_COLLECTION_COMPLETE) then
				self._skillBookXpId = aIndex
				self._skillBookXpLastVal = difference
			-- FENCE
			elseif (reason == PROGRESS_REASON_JUSTICE_SKILL_EVENT) then
				self._skillFenceXpId = aIndex
				self._skillFenceXpLastVal = difference
			-- WORLD SKILL
			elseif ( skillType == SKILL_TYPE_WORLD ) then
				self._skillTableWorld[skillIndex].key = aIndex
				self._skillTableWorld[skillIndex].val = difference
			-- AvA SKILL
			elseif ( skillType == SKILL_TYPE_AVA ) then
				self._skillTableAvA[skillIndex].key = aIndex
				self._skillTableAvA[skillIndex].val = difference
			-- WEAPON SKILL
			elseif ( skillType == SKILL_TYPE_WEAPON ) then
				self._skillTableWeapon[skillIndex].key = aIndex
				self._skillTableWeapon[skillIndex].val = difference
			-- ARMOR SKILL
			elseif ( skillType == SKILL_TYPE_ARMOR ) then
				self._skillTableArmor[skillIndex].key = aIndex
				self._skillTableArmor[skillIndex].val = difference
			end
		end

		if (bprint) then
			local zo_color = ZO_ColorDef:New( color )
			lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
			lootEntry:SetBackground()
			lootEntry:SetLabelSize( self.db.display.fontSize, 11 )
			lootEntry:SetRarity( zo_color, self.db.display.rarity )
			lootEntry:SetIcon( icon )
			lootEntry:SetName(pName)

			local gainForm = (self.db.skills.skillPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
			gainForm = (self.db.skills.skillSuffix) and gainForm..'xp' or gainForm
			local slabel = zo_strformat( '|c6BB5FF<<1>>|r <<2>>', gainForm, finaltext)

			lootEntry:SetLabel(slabel)
		end

		if (cprint) then
			if finaldbgtext == nil then finaldbgtext = slabel end
			self:ChatOutput(icon, 1, finaldbgtext, tag, true, nil, nil, nil, tab)
		end

		if aIndex and aIndex <= self.db.display.maxstacks then
			local anim = self._pop:Apply( lootEntry.control )
			anim:Forward()
		end
	end
end
-------------------------------------------------------------------------------
function LootDrop:GetStyleColoredString( itemStyle )
	local StyleColoredString = nil
	--style info
	if (itemStyle and (not (itemStyle == ITEMSTYLE_NONE or itemStyle == ITEMSTYLE_UNIVERSAL))) then
		
		local stylestring = GetItemStyleName(itemStyle)

	-- it doesn't really make sense to try and individually color by item style anymore... may revisit
	--	local color = "FFFFFF"
	--	if itemStyle >= ITEMSTYLE_RACIAL_BRETON and itemStyle <= ITEMSTYLE_RACIAL_KHAJIIT then
	--		color = GetItemQualityColor(ITEM_QUALITY_ARCANE)
	--	elseif itemStyle == ITEMSTYLE_RACIAL_IMPERIAL or itemStyle == ITEMSTYLE_AREA_DWEMER or itemStyle == ITEMSTYLE_GLASS or itemStyle == ITEMSTYLE_AREA_XIVKYN then
	--		color = GetItemQualityColor(ITEM_QUALITY_LEGENDARY)
	--	else
	--		color = GetItemQualityColor(ITEM_QUALITY_ARTIFACT)
	--	end

		local color = ZO_ColorDef:New({["r"]=0,["g"]=0.847,["b"]=1,["a"]=0.6}) -- set a custom color instead, ZO_ColorDef gives us ToHex()

		StyleColoredString = zo_strformat("|c<<1>> [<<2>>]|r", color:ToHex(), stylestring)

	end

	return StyleColoredString
	
end
-------------------------------------------------------------------------------
-- Check if this item is filtered (Phinix)
function LootDrop:GetIsFiltered(type, itemLink, quality, mode)
--[[
-- this section is for debugging future loot types (Phinix)
------------------------------------------------------------------------------------------------------------------------------
	local debugTypes = {
		[ITEMTYPE_ADDITIVE] = "ADDITIVE",
	--	[ITEMTYPE_ARMOR] = "ARMOR",
		[ITEMTYPE_ARMOR_BOOSTER] = "ARMOR_BOOSTER",
		[ITEMTYPE_ARMOR_TRAIT] = "ARMOR_TRAIT",
		[ITEMTYPE_AVA_REPAIR] = "AVA_REPAIR",
		[ITEMTYPE_BLACKSMITHING_BOOSTER] = "BLACKSMITHING_BOOSTER",
		[ITEMTYPE_BLACKSMITHING_MATERIAL] = "BLACKSMITHING_MATERIAL",
		[ITEMTYPE_BLACKSMITHING_RAW_MATERIAL] = "BLACKSMITHING_RAW_MATERIAL",
		[ITEMTYPE_CLOTHIER_BOOSTER] = "CLOTHIER_BOOSTER",
		[ITEMTYPE_CLOTHIER_MATERIAL] = "CLOTHIER_MATERIAL",
		[ITEMTYPE_CLOTHIER_RAW_MATERIAL] = "CLOTHIER_RAW_MATERIAL",
		[ITEMTYPE_COLLECTIBLE] = "COLLECTIBLE",
		[ITEMTYPE_CONTAINER] = "CONTAINER",
		[ITEMTYPE_CONTAINER_CURRENCY] = "CONTAINER_CURRENCY",
		[ITEMTYPE_COSTUME] = "COSTUME",
		[ITEMTYPE_CROWN_ITEM] = "CROWN_ITEM",
		[ITEMTYPE_CROWN_REPAIR] = "CROWN_REPAIR",
		[ITEMTYPE_DEPRECATED] = "DEPRECATED",
		[ITEMTYPE_DISGUISE] = "DISGUISE",
		[ITEMTYPE_DRINK] = "DRINK",
		[ITEMTYPE_DYE_STAMP] = "DYE_STAMP",
		[ITEMTYPE_ENCHANTING_RUNE_ASPECT] = "ENCHANTING_RUNE_ASPECT",
		[ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = "ENCHANTING_RUNE_ESSENCE",
		[ITEMTYPE_ENCHANTING_RUNE_POTENCY] = "ENCHANTING_RUNE_POTENCY",
		[ITEMTYPE_ENCHANTMENT_BOOSTER] = "ENCHANTMENT_BOOSTER",
		[ITEMTYPE_FISH] = "FISH",
		[ITEMTYPE_FLAVORING] = "FLAVORING",
		[ITEMTYPE_FOOD] = "FOOD",
		[ITEMTYPE_FURNISHING] = "FURNISHING",
		[ITEMTYPE_FURNISHING_MATERIAL] = "FURNISHING_MATERIAL",
		[ITEMTYPE_GLYPH_ARMOR] = "GLYPH_ARMOR",
		[ITEMTYPE_GLYPH_JEWELRY] = "GLYPH_JEWELRY",
		[ITEMTYPE_GLYPH_WEAPON] = "GLYPH_WEAPON",
		[ITEMTYPE_GROUP_REPAIR] = "GROUP_REPAIR",
		[ITEMTYPE_INGREDIENT] = "INGREDIENT",
		[ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = "JEWELRYCRAFTING_BOOSTER",
		[ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = "JEWELRYCRAFTING_MATERIAL",
		[ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER] = "JEWELRYCRAFTING_RAW_BOOSTER",
		[ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL] = "JEWELRYCRAFTING_RAW_MATERIAL",
		[ITEMTYPE_JEWELRY_RAW_TRAIT] = "JEWELRY_RAW_TRAIT",
		[ITEMTYPE_JEWELRY_TRAIT] = "JEWELRY_TRAIT",
		[ITEMTYPE_LOCKPICK] = "LOCKPICK",
		[ITEMTYPE_LURE] = "LURE",
		[ITEMTYPE_MASTER_WRIT] = "MASTER_WRIT",
		[ITEMTYPE_MOUNT] = "MOUNT",
		[ITEMTYPE_NONE] = "NONE",
		[ITEMTYPE_PLUG] = "PLUG",
		[ITEMTYPE_POISON] = "POISON",
		[ITEMTYPE_POISON_BASE] = "POISON_BASE",
		[ITEMTYPE_POTION] = "POTION",
		[ITEMTYPE_POTION_BASE] = "POTION_BASE",
		[ITEMTYPE_RACIAL_STYLE_MOTIF] = "RACIAL_STYLE_MOTIF",
		[ITEMTYPE_RAW_MATERIAL] = "RAW_MATERIAL",
		[ITEMTYPE_REAGENT] = "REAGENT",
		[ITEMTYPE_RECALL_STONE] = "RECALL_STONE",
		[ITEMTYPE_RECIPE] = "RECIPE",
		[ITEMTYPE_SIEGE] = "SIEGE",
		[ITEMTYPE_SOUL_GEM] = "SOUL_GEM",
		[ITEMTYPE_SPICE] = "SPICE",
		[ITEMTYPE_STYLE_MATERIAL] = "STYLE_MATERIAL",
		[ITEMTYPE_TABARD] = "TABARD",
		[ITEMTYPE_TOOL] = "TOOL",
		[ITEMTYPE_TRASH] = "TRASH",
		[ITEMTYPE_TREASURE] = "TREASURE",
		[ITEMTYPE_TROPHY] = "TROPHY",
	--	[ITEMTYPE_WEAPON] = "WEAPON",
		[ITEMTYPE_WEAPON_BOOSTER] = "WEAPON_BOOSTER",
		[ITEMTYPE_WEAPON_TRAIT] = "WEAPON_TRAIT",
		[ITEMTYPE_WOODWORKING_BOOSTER] = "WOODWORKING_BOOSTER",
		[ITEMTYPE_WOODWORKING_MATERIAL] = "WOODWORKING_MATERIAL",
		[ITEMTYPE_WOODWORKING_RAW_MATERIAL] = "WOODWORKING_RAW_MATERIAL",
	}
	local tString = (filterTable[type] ~= nil) and tostring(filterTable[type].LW) or "NOT CONFIGURED"
	if tString == "NOT CONFIGURED" then
		if (mode == 1) and (debugTypes[type] ~= nil) then d("LootDrop: "..itemLink.." - "..debugTypes[type].." - "..tString) end
	end
------------------------------------------------------------------------------------------------------------------------------
--]]
	if filterTable[type] ~= nil then
		if specialFilters[type] then
			local FilterWGlyphs
			local FilterAGlyphs
			local FilterJGlyphs
			local FilterGlyphQuality
			local FilterIngredients
			local FilterIngQuality
			local FilterRecipes
			local FilterRecipeQuality
			local FilterARune
			local FilterARuneQ
			local FilterBSImprove
			local FilterBSImproveQ
			local FilterClothImprove
			local FilterClothImproveQ
			local FilterWoodImprove
			local FilterWoodImproveQ
			local FilterJCImprove
			local FilterJCRawImprove
			local FilterJCImproveQ
			local FilterJCRImproveQ
		
			if mode == 1 then
				FilterWGlyphs = self.db.LWFilters.FilterWGlyphs
				FilterAGlyphs = self.db.LWFilters.FilterAGlyphs
				FilterJGlyphs = self.db.LWFilters.FilterJGlyphs
				FilterGlyphQuality = self.db.LWFilters.FilterGlyphQuality
				FilterIngredients = self.db.LWFilters.FilterIngredients
				FilterIngQuality = self.db.LWFilters.FilterIngQuality
				FilterRecipes = self.db.LWFilters.FilterRecipes
				FilterRecipeQuality = self.db.LWFilters.FilterRecipeQuality
				FilterARune = self.db.LWFilters.FilterARune
				FilterARuneQ = self.db.LWFilters.FilterARuneQ
				FilterBSImprove = self.db.LWFilters.FilterBSImprove
				FilterBSImproveQ = self.db.LWFilters.FilterBSImproveQ
				FilterClothImprove = self.db.LWFilters.FilterClothImprove
				FilterClothImproveQ = self.db.LWFilters.FilterClothImproveQ
				FilterWoodImprove = self.db.LWFilters.FilterWoodImprove
				FilterWoodImproveQ = self.db.LWFilters.FilterWoodImproveQ
				FilterJCImprove = self.db.LWFilters.FilterJCImprove
				FilterJCRawImprove = self.db.LWFilters.FilterJCRawImprove
				FilterJCImproveQ = self.db.LWFilters.FilterJCImproveQ
				FilterJCRImproveQ = self.db.LWFilters.FilterJCRImproveQ
			else
				FilterWGlyphs = self.db.CLFilters.FilterWGlyphs
				FilterAGlyphs = self.db.CLFilters.FilterAGlyphs
				FilterJGlyphs = self.db.CLFilters.FilterJGlyphs
				FilterGlyphQuality = self.db.CLFilters.FilterGlyphQuality
				FilterIngredients = self.db.CLFilters.FilterIngredients
				FilterIngQuality = self.db.CLFilters.FilterIngQuality
				FilterRecipes = self.db.CLFilters.FilterRecipes
				FilterRecipeQuality = self.db.CLFilters.FilterRecipeQuality
				FilterARune = self.db.CLFilters.FilterARune
				FilterARuneQ = self.db.CLFilters.FilterARuneQ
				FilterBSImprove = self.db.CLFilters.FilterBSImprove
				FilterBSImproveQ = self.db.CLFilters.FilterBSImproveQ
				FilterClothImprove = self.db.CLFilters.FilterClothImprove
				FilterClothImproveQ = self.db.CLFilters.FilterClothImproveQ
				FilterWoodImprove = self.db.CLFilters.FilterWoodImprove
				FilterWoodImproveQ = self.db.CLFilters.FilterWoodImproveQ
				FilterJCImprove = self.db.CLFilters.FilterJCImprove
				FilterJCRawImprove = self.db.CLFilters.FilterJCRawImprove
				FilterJCImproveQ = self.db.CLFilters.FilterJCImproveQ
				FilterJCRImproveQ = self.db.CLFilters.FilterJCRImproveQ
			end
		
			if (type == ITEMTYPE_INGREDIENT) or (type == ITEMTYPE_FLAVORING) or (type == ITEMTYPE_SPICE) or (type == ITEMTYPE_ADDITIVE) then
				if ((FilterIngredients) or (quality > FilterIngQuality)) then return false else return true end
			end
			if (type == ITEMTYPE_GLYPH_WEAPON) then if ((FilterWGlyphs) or (quality > FilterGlyphQuality)) then return false else return true end end
			if (type == ITEMTYPE_GLYPH_ARMOR) then if ((FilterAGlyphs) or (quality > FilterGlyphQuality)) then return false else return true end end
			if (type == ITEMTYPE_GLYPH_JEWELRY) then if ((FilterJGlyphs) or (quality > FilterGlyphQuality)) then return false else return true end end
			if (type == ITEMTYPE_RECIPE) then if ((FilterRecipes) or (quality > FilterRecipeQuality)) then return false else return true end end
			if (type == ITEMTYPE_ENCHANTING_RUNE_ASPECT) then if ((FilterARune) or (quality > FilterARuneQ)) then return false else return true end end
			if (type == ITEMTYPE_BLACKSMITHING_BOOSTER) then if ((FilterBSImprove) or (quality > FilterBSImproveQ)) then return false else return true end end
			if (type == ITEMTYPE_CLOTHIER_BOOSTER) then if ((FilterClothImprove) or (quality > FilterClothImproveQ)) then return false else return true end end
			if (type == ITEMTYPE_WOODWORKING_BOOSTER) then if ((FilterWoodImprove) or (quality > FilterWoodImproveQ)) then return false else return true end end
			if (type == ITEMTYPE_JEWELRYCRAFTING_BOOSTER) then if ((FilterJCImprove) or (quality > FilterJCImproveQ)) then return false else return true end end
			if (type == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER) then if ((FilterJCRawImprove) or (quality > FilterJCRImproveQ)) then return false else return true end end
		else
			if filterTable[type] ~= nil then
				if mode == 1 then
					return not filterTable[type].LW
				else
					return not filterTable[type].CL
				end
			end
		end
	end
	return false
end
-------------------------------------------------------------------------------
-- Called when one of your bag (inventory, bank, gbank, buyback ..) is updated -- Huge source of lua consumption
function LootDrop:OnSingleSlotUpdate(_, bagId, slotId, isNew, soundCategory, updateReason, stackChange)
	if IsUnderArrest() == false then
		local itemLink = GetItemLink(bagId, slotId, LINK_STYLE_DEFAULT)
		local pName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))

		self.recentLoot[pName] = {bagId = bagId, slotId = slotId} -- pass the bagId & slotId to the main LootDrop event (Phinix)

		-- special case for soul gems gained by Soul Trap, Soul Lock passive, or other such means. (Phinix)
		if stackChange > 0 and isNew then
			if (pName == LootDrop_SoulGem or pName == LootDrop_EmptyGem) and not self.lootBuffer then
				self.lootBuffer = true

				local LWFiltering = self.db.LWFilters.LWFiltering -- check if soul gems are filtered (Phinix)
				local CLFiltering = self.db.CLFilters.CLFiltering
				local LWFiltered = (LWFiltering) and not self.db.LWFilters.FilterSoulGems or false
				local CLFiltered = (CLFiltering) and not self.db.CLFilters.FilterSoulGems or false
				if ((LWFiltered) and (LWFiltering)) and ((CLFiltered) and (CLFiltering)) then return end -- if both loot window and chat display are filtered save time and end here (Phinix)

				local itemId = GetItemId(bagId, slotId)
				local icon, _, _, _, itemStyle   = GetItemLinkInfo(itemLink)
				local quality = GetItemLinkQuality(itemLink)
				local quantity = stackChange
				local color = GetItemQualityColor(quality)
				local unitName = GetRawUnitName("player")
				local lootType = LOOT_TYPE_ITEM
				local isStolen = IsItemLinkStolen(itemLink) 

				self.ItemToPrint.tag = 'INV'
				self.ItemToPrint.itemStyle = self:GetStyleColoredString( itemStyle )

				local inventoryCount, bankCount, craftBagCount = GetItemLinkStacks(itemLink)
				self.ItemToPrint.nb = (bagId == BAG_VIRTUAL) and craftBagCount or inventoryCount
			--	self.ItemToPrint.nb = GetSlotStackSize(bagId, slotId)

				self:ResetCurrentItemBag()

				zo_callLater(function() self.lootBuffer = nil end, 100) -- the game fires soul gem gains twice for some weird reason so buffer (Phinix)

				local lootEntry, aIndex, isUpdate
				if not LWFiltered then
					lootEntry, aIndex, isUpdate = self:Get(pName)
					if ( not lootEntry ) then
						lootEntry, aIndex = self:Acquire()
						isUpdate = false
					end
				end

				local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogMine)

				self:LootPrint(lootEntry, aIndex, pName, icon, color, quality, quantity, itemLink, true, unitName, lootType, itemId, bagId, isStolen, nil, isUpdate, LWFiltered, CLFiltered, tab)
			end
		end

		-- for mail loot
		if ( self.db.loot.mailLoot ) then
			for mailitemindex, item in pairs(self.MailStacks) do
				local itemLink = GetItemLink(bagId, slotId, LINK_STYLE_DEFAULT)
				-- itemLink can't be used as comparator because on hirelings mails (only thoses?), itemLink is incorrect
				local itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
				if (itemLink == item.itemLink) or (itemName == item.itemName) then
					item.bagId = bagId
					item.slotId = slotId
					break
				end
			end
		end
	end
end
-------------------------------------------------------------------------------
--- Called when you loot an Item
-- @tparam string itemLink
-- @tparam number quantity
-- @tparam boolean mine
-- @tparam number itemId
function LootDrop:OnLootReceived(unitName, itemLink, quantity, _, lootType, mine, isPickpocketLoot, questIcon, itemId, _, preview)
	-- EVENT_LOOT_RECEIVED (receivedBy, itemName, quantity, soundCategory, lootType, self, isPickpocketLoot, questItemIcon, itemId, isStolen)
	-- NOTE: The 'isStolen' field appears to be broken and currently returns 'false' even for stolen loot (Phinix)

	-- itemId returns the antiquity ID if lootType = LOOT_TYPE_ANTIQUITY_LEAD (12) (Phinix)
	-- itemLink can be an itemName if lootType == LOOT_TYPE_QUEST_ITEM. itemId param #9 can't be used for this lootType, questItemIcon returns nil

	if not mine and not ((self.db.chat.DbgLogOthers) or (lootType == LOOT_TYPE_QUEST_ITEM)) then return end

	local quality = GetItemLinkQuality(itemLink)

	local LWFiltering -- check if item is normal non-preview loot item and is filtered (Phinix)
	local CLFiltering
	local LWFiltered
    local CLFiltered
	if preview == nil and lootType ~= LOOT_TYPE_QUEST_ITEM and lootType ~= LOOT_TYPE_ANTIQUITY_LEAD and lootType ~= LOOT_TYPE_COLLECTIBLE then
		local tType = GetItemLinkItemType(itemLink)
		LWFiltering = self.db.LWFilters.LWFiltering
		CLFiltering = self.db.CLFilters.CLFiltering
		LWFiltered = (LWFiltering) and self:GetIsFiltered(tType, itemLink, quality, 1) or false
		CLFiltered = (CLFiltering) and self:GetIsFiltered(tType, itemLink, quality, 2) or false
		if ((LWFiltered) and (LWFiltering)) and ((CLFiltered) and (CLFiltering)) then return end -- if both loot window and chat display are filtered save time and end here (Phinix)
	end

	local pName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))

	if (pName == LootDrop_SoulGem or pName == LootDrop_EmptyGem) then return end -- ignore actual looted soul gems to avoid duplicates from OnSingleSlotUpdate fix (Phinix)

	local isPreview = ((preview ~= nil) and (preview == "preview"))

	local bagId, slotId
	local isStolen = false
	local isTradeable = false
	local tab = self.db.lootdrop_tab
	local icon
	local color
	local itemStyle
	icon, _, _, _, itemStyle	= GetItemLinkInfo(itemLink)
	self.ItemToPrint.itemStyle	= self:GetStyleColoredString( itemStyle )
	color						= GetItemQualityColor(quality)
	self.ItemToPrint.tag		= 'INV'
	self.ItemToPrint.nb			= 1

	if mine then
		if self.recentLoot[pName] ~= nil then bagId, slotId = self.recentLoot[pName].bagId, self.recentLoot[pName].slotId end

		if lootType == LOOT_TYPE_QUEST_ITEM then
			self.ItemToPrint.tag = 'QUEST'
			icon = questIcon
			self.ItemToPrint.nb = (bagId ~= nil) and GetSlotStackSize(bagId, slotId) or 1

			if ( (not icon) or (icon == '') or (icon == "/esoui/art/icons/icon_missing.dds")) then
				icon = "/esoui/art/inventory/inventory_tabicon_quest_down.dds"
			end
			color = GetItemQualityColor(0)
			quantity = (not quantity or quantity < 1) and 1 or quantity
			if bagId ~= nil then self:ResetCurrentItemBag() end
	
		elseif lootType == LOOT_TYPE_ANTIQUITY_LEAD then -- itemId returns the antiquity ID in this context
			self.ItemToPrint.tag = 'ANTIQUITY'

			itemLink = GetAntiquityName(itemId)
			pName = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink)
			icon = GetAntiquityIcon(itemId)
			color = GetAntiquityQualityColor(GetAntiquityQuality(itemId))
			quantity = (not quantity or quantity < 1) and 1 or quantity
	
		elseif lootType == LOOT_TYPE_COLLECTIBLE then -- itemId returns the collectible ID in this context
			self.ItemToPrint.tag = 'COLLECTIBLE'

			itemLink = GetCollectibleLink(itemId, LINK_STYLE_DEFAULT)
			icon = GetCollectibleIcon(itemId)
			color = GetItemQualityColor(quality)
			quantity = (not quantity or quantity < 1) and 1 or quantity
	
		else
			if bagId ~= nil then

				isStolen = IsItemStolen(bagId, slotId)
				isTradeable = IsItemBoPAndTradeable(bagId, slotId)

				local inventoryCount, bankCount, craftBagCount = GetItemLinkStacks(itemLink)
				self.ItemToPrint.nb = (bagId == BAG_VIRTUAL) and craftBagCount or inventoryCount
			--	self.ItemToPrint.nb = GetSlotStackSize(bagId, slotId)

				if self.db.general.junkTrash and GetItemLinkItemType(itemLink) == ITEMTYPE_TRASH and IsItemJunk(bagId, slotId) == false then
					SetItemIsJunk(bagId, slotId, true)
					self.ItemToPrint.tag = 'JUNK'
				end
				
				self:ResetCurrentItemBag()
			end
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogMine)
		end
	elseif not isPreview then
		isStolen = false
		isTradeable = (not IsItemLinkBound(itemLink)) and true or false
		tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogOthers)
	end

	local lootEntry, aIndex, isUpdate
	if mine and not LWFiltered then
		lootEntry, aIndex, isUpdate = self:Get(pName)
		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self:LootPrint(lootEntry, aIndex, pName, icon, color, quality, quantity, itemLink, mine, unitName, lootType, itemId, bagId, isStolen, isTradeable, isUpdate, LWFiltered, CLFiltered, tab)
end
-------------------------------------------------------------------------------
-- Calledn when you read a mail
function LootDrop:OnMailReadable(mailId)
	local numAttachments = GetMailAttachmentInfo(mailId)

	self.MailStacks = {}

	for attachIndex = 1, numAttachments do
		self.MailStacks[attachIndex] = {}
		local icon, stack, _, _, _, _, itemStyle, quality = GetAttachedItemInfo( mailId, attachIndex)
		local mailitemlink                                = GetAttachedItemLink( mailId, attachIndex, LINK_STYLE_DEFAULT)
		local mailitemName                                = GetItemLinkName(mailitemlink)
		self.MailStacks[attachIndex].icon                 = icon
		self.MailStacks[attachIndex].stack                = stack
		self.MailStacks[attachIndex].itemLink             = mailitemlink
		self.MailStacks[attachIndex].itemName             = zo_strformat(SI_TOOLTIP_ITEM_NAME, mailitemName)
		self.MailStacks[attachIndex].itemStyle            = self:GetStyleColoredString( itemStyle )
		self.MailStacks[attachIndex].tType          	  = GetItemLinkItemType(mailitemlink)
		self.MailStacks[attachIndex].quality              = quality
	end
end
-------------------------------------------------------------------------------
-- Called (a single time) when you take mail attachments
function LootDrop:OnMailItemLooted(mailId)
	-- Buggy if bag is full, it will consider all items as looted, even if only some are not.

	for mailitemindex, item in pairs(self.MailStacks) do
		local LWFiltering = self.db.LWFilters.LWFiltering
		local CLFiltering = self.db.CLFilters.CLFiltering
		local LWFiltered = (LWFiltering) and self:GetIsFiltered(item.tType, item.itemLink, item.quality, 1) or false
		local CLFiltered = (CLFiltering) and self:GetIsFiltered(item.tType, item.itemLink, item.quality, 2) or false
		local skipFiltered = ((LWFiltered) and (LWFiltering)) and ((CLFiltered) and (CLFiltering)) and true or false

		if not skipFiltered and item.itemName ~= LootDrop_SoulGem then
			local color = GetItemQualityColor(item.quality)
			local inventoryCount, bankCount, craftBagCount = GetItemLinkStacks(item.itemLink)
			self.ItemToPrint.nb = (item.bagId == BAG_VIRTUAL) and craftBagCount or inventoryCount
		--	self.ItemToPrint.nb        = GetSlotStackSize(item.bagId, item.slotId)

			self.ItemToPrint.tag       = 'MAIL'
			self.ItemToPrint.itemStyle = item.itemStyle
	
			local lootEntry, aIndex, isUpdate
			if not LWFiltered then
				lootEntry, aIndex, isUpdate = self:Get(item.itemName)
				if ( not lootEntry ) then
					lootEntry, aIndex = self:Acquire()
					isUpdate = false
				end
			end

			local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogMine)

			self:LootPrint(lootEntry, aIndex, item.itemName, item.icon, color, item.quality, item.stack, item.itemLink, true, nil, nil, nil, item.bagId, nil, nil, isUpdate, LWFiltered, CLFiltered, tab)
		end
	end

	self.MailStacks = {}
	self:ResetCurrentItemBag()
end
-------------------------------------------------------------------------------
-- Return value string based on passed in variables (Phinix)
function LootDrop:GetValueString(itemLink,quantity,cquantity)
	function Round(number, decimals) -- Round number to decimals number of places.
		local tDec = math.floor(decimals)
		if tDec >= 0 then
			return tonumber(string.format("%." .. (tDec or 0) .. "f", number))
		else
			return 0
		end
	end

	-- set the value display based on selected option (Phinix)
	local option = self.db.value.lootValue
	local val = tostring(GetItemLinkValue(itemLink))
	local mult = tostring(tonumber(val) * quantity)
	local goldg = (self.db.value.goldSuff) and "g" or ""
	local tMult = 0
	local tVal = 0
	local value = ""
	local cValue = ""

	local multForm = self:FormatAmount(tonumber(val) * quantity)
	local multFormC = self:FormatAmount(tonumber(val) * cquantity)
	local valForm = self:FormatAmount(tonumber(val))

	if option == 1 then
		if self.db.value.stackVal then
			value = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. multForm .. goldg
			cValue = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. multFormC .. goldg
		else
			value = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. valForm .. goldg
			cValue = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. valForm .. goldg
		end
	elseif option > 1 then
		local MM = 0
		local ATT = 0
		local TTC = 0
		local isLink = (string.find(itemLink, "|H(.-):item:(.-)|h(.-)|h") ~= nil) and true or false

		if TamrielTradeCentre ~= nil then
			local priceInfo = (isLink) and TamrielTradeCentrePrice:GetPriceInfo(itemLink) or nil
			if not priceInfo or priceInfo == nil then
				TTC = 0
			else
				if priceInfo.SuggestedPrice then
					TTC = priceInfo.SuggestedPrice
				else 
					TTC = priceInfo.Avg
				end
			end
		end
		if MasterMerchant ~= nil then 
			local mmData = (isLink) and MasterMerchant:itemStats(itemLink, false) or nil
			if not mmData or (mmData.avgPrice == nil or mmData.avgPrice == 0) then
				MM = 0
			else
				MM = mmData.avgPrice
			end
		end
		if ArkadiusTradeTools ~= nil then 
			local avgPrice = (isLink) and ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(itemLink, nil, nil) or nil
			if not avgPrice or avgPrice == nil or avgPrice == 0 then
				ATT = 0
			else
				ATT = avgPrice
			end
		end

		local tVals = {[1] = MM, [2] = ATT, [3] = TTC}
		local valueSep = (self.db.value.valueSep) and ", " or " "
		local nData = (self.db.value.noData) and valueSep .. L.ValueNone or ""
		local tCount = 0
		for k, v in pairs(tVals) do
			if v > 0 then
				tCount = tCount + 1
				tVal = tVal + v
			end
		end
		if tCount > 0 then tVal = tVal / tCount end
		tMult = tostring(Round(tVal * quantity, 0))
		tMultC = tostring(Round(tVal * cquantity, 0))
		tVal = Round(tVal, 0)

		local tMultFormC = self:FormatAmount(tonumber(tMultC))
		local tMultForm = self:FormatAmount(tonumber(tMult))
		local tValForm = self:FormatAmount(tVal)

		if option == 2 then
			nData = (self.db.value.noDataVal) and " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. multForm .. goldg or nData

			if tVal == 0 then
				value = nData
			else
				if self.db.value.stackVal then
					value = " |t18:18:/lootdrop/textures/trade_house.dds|t " .. tMultForm .. goldg
					cValue = " |t16:16:/lootdrop/textures/trade_house.dds|t " .. tMultFormC .. goldg
				else
					value = " |t18:18:/lootdrop/textures/trade_house.dds|t " .. tValForm .. goldg
					cValue = " |t16:16:/lootdrop/textures/trade_house.dds|t " .. tValForm .. goldg
				end
			end
		elseif option == 3 then
			if tVal == 0 then
				if self.db.value.stackVal then
					value = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. multForm .. goldg .. nData
					cValue = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. multFormC .. goldg .. nData
				else
					value = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. valForm .. goldg .. nData
					cValue = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. valForm .. goldg .. nData
				end
			else
				if self.db.value.stackVal then
					value = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. multForm .. goldg .. valueSep .. "|t18:18:/lootdrop/textures/trade_house.dds|t " .. tMultForm .. goldg
					cValue = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. multFormC .. goldg .. valueSep .. "|t16:16:/lootdrop/textures/trade_house.dds|t " .. tMultFormC .. goldg
				else
					value = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. valForm .. goldg .. valueSep .. "|t18:18:/lootdrop/textures/trade_house.dds|t " .. tValForm .. goldg
					cValue = " |t16:16:/esoui/art/currency/currency_gold.dds|t " .. valForm .. goldg .. valueSep .. "|t16:16:/lootdrop/textures/trade_house.dds|t " .. tValForm .. goldg
				end
			end
		end
	end
	return value, tMult, tVal, mult, val, cValue
end
-------------------------------------------------------------------------------
-- Print a loot in LootDrop Gui and send it to chat if enabled
function LootDrop:LootPrint(lootEntry, aIndex, pName, icon, c, quality, quantity, itemLink, mine, unitName, lootType, itemId, bagId, isStolen, isTradeable, isUpdate, LWFiltered, CLFiltered, tab)

-- currently only Antiquity Leads are passing 'lootType' and 'itemId' so checking for these effectively checks if drop is antiquity
-- however we still test if lootType == LOOT_TYPE_ANTIQUITY_LEAD so it is clear if future item types are added that need support.

	local tag = self.ItemToPrint.tag

	if ( not icon or icon == '' ) then icon = "/esoui/art/icons/icon_missing.dds" end
	local color = c:ToHex()
	local guiName = itemLink
	unitName = (unitName ~= nil) and unitName or ""

	-- Remove ItemLink for LootDropGui, because of some rare items with wrong itemLink in FR/DE. (ex few set items - |H1:item:55383:283:50:0:0:0:0:0:0:0:0:0:0:0:0:33:0:0:0:0:0|h|h)
	if string.find(itemLink, "|H(.-):item:(.-)|h(.-)|h") then
		guiName = zo_strformat("|c<<1>><<2>>|r", color, pName)
	elseif lootType and lootType == LOOT_TYPE_ANTIQUITY_LEAD then -- treat antiquity leads separate from quest items and colorize
		guiName = zo_strformat("|c<<1>><<2>>|r", color, itemLink)
		quality = (itemId ~= nil) and GetAntiquityQuality(itemId) or quality
	else
		-- Quest items
		guiName = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink)
	end

	local text = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink)

	local cQuantity = quantity
	if isUpdate then quantity = quantity + self._active[aIndex].quantity end

	local label = (quantity > 1) and " "..tostring(quantity).."x "..guiName or " "..guiName

	if not self.db.loot.nameLoot and (tag == "INV" or tag == "JUNK" or tag == "MAIL") then
		label = (quantity > 1) and " "..tostring(quantity).."x " or " "
	end

	local stolen = ""
	local invstack = ""
	local traitstyle = ""
	local collected = ""
	local notCollected
	local value, tMult, tVal, mult, val, cValue = self:GetValueString(itemLink,quantity,cQuantity)

	if isStolen then stolen = zo_iconTextFormatNoSpace("esoui/art/inventory/gamepad/gp_inventory_icon_stolenitem.dds",28,28,"") end

    if isStolen then
		stolen = zo_iconTextFormatNoSpace("esoui/art/inventory/gamepad/gp_inventory_icon_stolenitem.dds",28,28,"") 
    elseif isTradeable then
		stolen = zo_iconTextFormatNoSpace("esoui/art/inventory/inventory_tradable_icon.dds",28,28,"")
    end

	if tag == "INV" or tag == "JUNK" or tag == "MAIL" then
		if self.db.loot.stackLoot and self.ItemToPrint.nb ~= quantity then
			local bag = "esoui/art/mainmenu/menubar_inventory_up.dds"
			local nbForm = self:FormatAmount(self.ItemToPrint.nb)
			if bagId == BAG_VIRTUAL then bag = "esoui/art/inventory/inventory_tabicon_craftbag_up.dds" end 
			invstack = LootDrop_Spacer..zo_strformat(zo_iconTextFormatNoSpace(bag,28,28,"").."|cFFFFFF<<1>>|r", nbForm) 
		end
		if self.db.loot.styleLoot and self.ItemToPrint.itemStyle then
			traitstyle = self.ItemToPrint.itemStyle
		end

		if self.db.loot.collectLoot and IsItemLinkSetCollectionPiece(itemLink) then -- show icons for uncollected set items (Phinix)
			local setId = select(6, GetItemLinkSetInfo(itemLink, false))
			local slot = GetItemLinkItemSetCollectionSlot(itemLink)
			if not IsItemSetCollectionSlotUnlocked(setId, slot) then
				notCollected = true
				collected = ' '..zo_iconTextFormatNoSpace("esoui/art/treeicons/gamepad/achievement_categoryicon_collections.dds",20,20,"")
			end
		end

		if (self.db.loot.traitLoot) then -- show item trait if set in options
			local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
			if traitType ~= ITEM_TRAIT_TYPE_NONE and traitDescription ~= "" then
				local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
				if traitName ~= "" then
					local traitInformation = GetItemTraitInformationFromItemLink(itemLink)
					local formattedTraitName = zo_strformat(SI_ITEM_FORMAT_STR_ITEM_TRAIT_HEADER, traitName)
					traitstyle = traitstyle.." |c6BB5FF["..formattedTraitName.."]|r"
				end
			end
		end

	elseif tag == "QUEST" then -- an icon for looted quest items
		local bag = "esoui/art/tutorial/inventory_tabicon_quest_up.dds" 
		local stackNbForm = self.ItemToPrint.nb
		if not self.db.loot.stackLoot or self.ItemToPrint.nb < 2 or self.ItemToPrint.nb == nil then stackNbForm = "" end
		if stackNbForm ~= "" then stackNbForm = self:FormatAmount(self.ItemToPrint.nb) end
		invstack = LootDrop_Spacer..zo_strformat(zo_iconTextFormatNoSpace(bag,28,28,"").."|cFFFFFF<<1>>|r", stackNbForm)	
	end

	if mine and not LWFiltered then -- only self loot in loot window and check if filtered (Phinix)
		label = stolen..label..collected..invstack..traitstyle..value
		local stackval = self.db.value.stackVal
		local uSval = (stackval) and mult or val
		local uTval = (stackval) and tMult or tVal

		if isUpdate then -- increment the item stack value totals when updating existing loot items (Phinix)
			local oldEntry = self._active[aIndex]
			uSval = uSval + oldEntry.sval
			uTval = uTval + oldEntry.tval
		end

		if (lootEntry ~= nil) then
			lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
			lootEntry:SetBackground()
			lootEntry:SetLabelSize( self.db.display.fontSize, 1 )
			lootEntry:SetRarity( c , self.db.display.rarity)
			lootEntry:SetIcon( icon )
			lootEntry:SetLabel( label )
	
			-- these two values are used to lookup the loot index when it changes and for tracking values for incrementing stacks (Phinix)
			lootEntry:SetName( pName )
			lootEntry:SetQuantity( quantity )
			lootEntry:SetValue( uSval, uTval )
	
			if aIndex <= self.db.display.maxstacks then
				local anim = self._pop:Apply( lootEntry.control )
				anim:Forward()
			end
		end
	end

	if CLFiltered then return end -- this loot is filtered in chat (Phinix)

	local chatText = ""
    if isStolen then -- show stolen/tradeable status in chat log as well (Phinix)
		chatText = zo_iconTextFormatNoSpace("esoui/art/inventory/gamepad/gp_inventory_icon_stolenitem.dds",20,20,"").." "..text
    elseif isTradeable then
		chatText = zo_iconTextFormatNoSpace("esoui/art/inventory/inventory_tradable_icon.dds",20,20,"").." "..text
	else
		chatText = text
    end

	if notCollected then -- show icons for uncollected set items (Phinix)
		chatText = chatText..' '..zo_iconTextFormatNoSpace("esoui/art/treeicons/gamepad/achievement_categoryicon_collections.dds",16,16,"")
	end

	self:ChatOutput(icon, cQuantity, chatText, tag, mine, unitName, quality, cValue, tab)
	self:ResetItemToPrint()
end
-------------------------------------------------------------------------------
--- Called when the amount of money you have changes
-- @tparam number money 
function LootDrop:OnMoneyUpdated( newMoney, oldMoney, reason )
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local difference = newMoney - oldMoney
	local RealDiff=difference
	local displayMode = self.db.gold.showGold
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._coinId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_gold")
			if isUpdate then
				difference = difference + self._coinLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._coinId = aIndex
	self._coinLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.gold.showPrefix
		local showName			= self.db.gold.showName
		local showNameFull		= self.db.gold.showNameFull
		local showCName			= self.db.gold.showCName
		local showColor			= self.db.gold.showColor
		local nameColor			= self.db.gold.nameColor
		local showBagGold		= self.db.gold.showBagGold
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 2 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( "/esoui/art/icons/item_generic_coinbag.dds" )
		lootEntry:SetName("loot_gold")

		local gainForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newMoneyForm = self:FormatAmount(newMoney)
		local bagGold = (showBagGold) and LootDrop_Spacer..zo_strformat(LootDrop_Bag..'|cFFFFFF<<1>>|r', newMoneyForm) or ""
		local nameText = ((showName) and (showNameFull) and (showCName ~= "")) and showCName or ((showName) and (showNameFull)) and " "..L.Gold or (showName) and "g" or ""
		if (showColor) then nameText = '|c'..LootDrop:num2hex(nameColor)..nameText..'|r' end

		lootEntry:SetLabel( zo_strformat('<<1>><<2>><<3>>', gainForm, nameText, bagGold) )
	end

	if (self.db.chat.DbgLogGold) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.Gold, self:FormatAmount(newMoney))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogGold)
		self:ChatOutput("/esoui/art/icons/item_generic_coinbag.dds", 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnXPUpdated( _, level, previousExperience, currentExperience, championPoints )
	local gain = currentExperience - previousExperience
	if (gain <= 0) then return end -- no gain so nothing to display

	local maxLevel = GetMaxLevel()
	local displayMode = self.db.XP.showXP
	local realLevel = L.LevelPsijic.." "..tostring(level)
    if level == 50 then realLevel = zo_iconTextFormatNoSpace("esoui/art/champion/champion_icon_32.dds",28,28,"")..championPoints end	

	local RealDiff=gain
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._xpId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_xp")
			if isUpdate then
				gain = gain + self._xpLastVal
			end
		end

		if not lootEntry then
			lootEntry, aIndex, isUpdate = self:Acquire()
			isUpdate = false
		end
	end

	self._xpId = aIndex
	self._xpLastVal = gain

	local xpForLevelUp
	if level < maxLevel then
		xpForLevelUp = GetNumExperiencePointsInLevel(level)
	else
		local cPoints = GetNumChampionXPInChampionPoint(championPoints)
		xpForLevelUp = (cPoints ~= nil) and cPoints or 0
	end
	local levelProgress = tostring(math.floor(100*(currentExperience/xpForLevelUp))).."%"

	if (displayMode) then
		local showPrefix		= self.db.XP.showPrefix
		local showName			= self.db.XP.showName
		local showNameFull		= self.db.XP.showNameFull
		local showProgress		= self.db.XP.showProgress
		local showProgFull		= self.db.XP.showProgFull
		local showLevel			= self.db.XP.showLevel
		local showCName			= self.db.XP.showCName
		local showColor			= self.db.XP.showColor
		local nameColor			= self.db.XP.nameColor
		local c = (self.db.display.sListStyle==LootDrop_sDefPawkette) and '00FF00' or 'FFFFFF'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 3 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sXpIcon )
		lootEntry:SetName("loot_xp")

		local normalProgress = zo_strformat('|c736F6E(<<1>>)|r', levelProgress)
		local extendedProgress = zo_strformat('|c736F6E-> <<1>>/<<2>> (<<3>>)|r',self:FormatAmount(currentExperience), self:FormatAmount(xpForLevelUp), levelProgress)

		local gainForm = (showPrefix) and self:FormatAmount(gain, true) or self:FormatAmount(gain)
		local levelText = (showLevel) and LootDrop_Spacer..realLevel or ""
		local progText = ((showProgress) and (showProgFull)) and extendedProgress or (showProgress) and normalProgress or ""
		local nameText = ((showName) and (showNameFull) and (showCName ~= "")) and showCName or ((showName) and (showNameFull)) and " "..L.Experience or (showName) and "xp" or ""
		if (showColor) then nameText = '|c'..LootDrop:num2hex(nameColor)..nameText..'|r' end

		lootEntry:SetLabel( zo_strformat('<<1>><<2>><<3>> <<4>>', gainForm, nameText, levelText, progText) )
	end

	if (self.db.chat.DbgLogXP) then
		local text = ""
		if level == maxLevel and GetPlayerChampionPointsEarned() == 3600 then
			text = zo_strformat('<<1>> <<2>>', self:FormatAmount(RealDiff), L.Experience)
		else
			text = zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>/<<4>> (<<5>>)|r', self:FormatAmount(RealDiff), L.Experience, self:FormatAmount(currentExperience), self:FormatAmount(xpForLevelUp), levelProgress)
		end
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogXP)
		self:ChatOutput(LootDrop_sXpIcon, 1, text, 'XP', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnAPUpdate( alliancePoints, playSound, difference, reason, v1, v2, preview)
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local maxLevel = GetMaxLevel()
	local displayMode = self.db.AP.showAP
	local currentAvARank
	local rankProgAvA, rankMaxAvA
	local currentRP
	local levelProgress
	local rankIcon
	local isPreview = (preview ~= nil and preview == "preview") and true or false

	if isPreview then
		currentAvARank = 25
		rankProgAvA, rankMaxAvA = 7941000, 8840000
		currentRP = rankProgAvA
		rankIcon = GetAvARankIcon(25)
	else
		currentAvARank = GetUnitAvARank("player")
		local function GetCurrentRankProgress()
			local rankPoints = GetUnitAvARankPoints("player")
			local _, _, rankStartsAt, nextRankAt = GetAvARankProgress(rankPoints)
			if rankPoints >= nextRankAt then
				local lastRankPoints = GetNumPointsNeededForAvARank(currentAvARank - 1)
				local maxRankPoints = GetNumPointsNeededForAvARank(currentAvARank)
				local fullRankPoints = maxRankPoints - lastRankPoints

				return fullRankPoints, fullRankPoints
			else
				return rankPoints - rankStartsAt, nextRankAt - rankStartsAt
			end
		end
		rankProgAvA, rankMaxAvA = GetCurrentRankProgress()
		rankIcon = GetAvARankIcon(GetUnitAvARank("player"))
		currentRP = self._apLastRP
	end
	local levelProgress = tostring(math.floor(100*(rankProgAvA/rankMaxAvA))).."%"
	local actualRP = GetUnitAvARankPoints("player")

	local RealDiff=difference
	local realForm = self:FormatAmount(RealDiff, true)
	local rDiff = (isPreview) and realForm or self:FormatAmount(actualRP - currentRP, true)
	if isPreview then levelProgress = tostring(math.floor(100*((rankProgAvA+RealDiff)/rankMaxAvA))).."%" end
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._apId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_ap")
			if isUpdate then
				difference = difference + self._apLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._apId = aIndex
	self._apLastVal = difference
	self._apLastRPVal = self._apLastRPVal + (actualRP - currentRP)
	self._apLastRP = actualRP

	if (displayMode) then
		local showPrefix		= self.db.AP.showPrefix
		local showName			= self.db.AP.showName
		local showNameFull		= self.db.AP.showNameFull
		local showProgress		= self.db.AP.showProgress
		local showProgFull		= self.db.AP.showProgFull
		local showRPGain		= self.db.AP.showRPGain
		local showLevel			= self.db.AP.showLevel
		local showCName			= self.db.AP.showCName
		local showColor			= self.db.AP.showColor
		local nameColor			= self.db.AP.nameColor
		local c = (self.db.display.sListStyle==LootDrop_sDefPawkette) and '0000FF' or 'C5FFC0'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() ) 
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 4 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ) , self.db.display.rarity)
		lootEntry:SetIcon( LootDrop_sApIcon )
		lootEntry:SetName("loot_ap")

		local lastRP = (showPrefix) and self:FormatAmount(self._apLastRPVal, true) or self:FormatAmount(self._apLastRPVal)
		local rpWForm = (showRPGain) and "|c00FF00RP:|r |cFFFFFF"..lastRP.."|r " or ""
		local rpWRank = zo_iconTextFormatNoSpace(rankIcon,28,28,"")..currentAvARank
		local normWForm = zo_strformat('|c736F6E(<<1>>)|r', levelProgress)
		local extWForm = zo_strformat('|c736F6E-> <<1>>/<<2>> (<<3>>)|r',self:FormatAmount(rankProgAvA), self:FormatAmount(rankMaxAvA), levelProgress)
		local gainForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local levelText = ((showLevel) and (showRPGain)) and LootDrop_Spacer..rpWForm.." "..rpWRank or (showLevel) and LootDrop_Spacer..rpWRank or (showRPGain) and LootDrop_Spacer..rpWForm or ""
		local progText = ((showProgress) and (showProgFull)) and extWForm or (showProgress) and normWForm or ""
		local nameText = ((showName) and (showNameFull) and (showCName ~= "")) and showCName or ((showName) and (showNameFull)) and " "..L.AlliancePoints or (showName) and "ap" or ""
		if (showColor) then nameText = '|c'..LootDrop:num2hex(nameColor)..nameText..'|r' end

		lootEntry:SetLabel( zo_strformat('<<1>><<2>><<3>> <<4>>', gainForm, nameText, levelText, progText) )
	end

	if (self.db.chat.DbgLogAP) then
		local text = ""

		local rpForm = (self.db.chat.DbgAWGain) and "|c00FF00RP:|r |cFFFFFF"..rDiff.."|r " or ""
		local rpRank = (self.db.chat.DbgAWRank) and zo_strformat("<<1>>|cFFFFFF<<2>>|r", zo_iconTextFormatNoSpace(rankIcon,24,24,""), currentAvARank) or ""
		local baseForm = zo_strformat("<<1>> |c736F6E->|r <<2>><<3>>", realForm, rpForm, rpRank)
		local normForm = zo_strformat(' |c736F6E (<<1>>%)|r', self:FormatAmount(math.floor(100*(rankProgAvA/rankMaxAvA))))
		local extForm = zo_strformat(' |c736F6E (<<1>>/<<2>> = <<3>>%)|r', self:FormatAmount(rankProgAvA), self:FormatAmount(rankMaxAvA), self:FormatAmount(math.floor(100*(rankProgAvA/rankMaxAvA))))
		local progForm = ((RealDiff > 0) and (self.db.chat.DbgAWFull)) and extForm or (RealDiff > 0) and normForm or ""

		text = baseForm..progForm
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogAP)
		self:ChatOutput(LootDrop_sApIcon, 1, text, 'AP', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnVPUpdate( rewardTrackType, rewardTrackId, previousRank, currentRank, currentExperience, preview )
  if rewardTrackType ~= REWARD_TRACK_TYPE_AVA_VETERANCY then
     return
  end  

	local displayMode = self.db.VP.showVP
	local isPreview = (preview ~= nil and preview == "preview") and true or false

  local seasonId = GetCurrentVeterancySeasonId()
	local currentVPRank =  GetUnitVeterancyRank("player")
	local rankProgVP, rankMaxVP
	local currentVP
	local levelProgress
	local rankIcon = GetVeterancyRankIcon(math.min(currentVPRank,100), seasonId)

	if isPreview then
		rankProgVP, rankMaxVP = currentExperience , GetTotalProgressAtRewardTrackTier(GetRewardTrackIdFromReferenceTrackId(rewardTrackType, GetActiveReferenceTrackIdsForRewardTrackType(rewardTrackType)), currentVPRank)
		currentVP = currentExperience - math.random(1,2000)
	else
    local curr, max = currentExperience, GetTotalProgressAtRewardTrackTier(GetRewardTrackIdFromReferenceTrackId(rewardTrackType, rewardTrackId), currentVPRank)
    if curr and max and max > 0 then
      rankProgVP, rankMaxVP = curr, max
    end
    if not rankProgVP then
      rankProgVP = currentExperience or 0
      rankMaxVP = (currentExperience and currentExperience > 0) and currentExperience or 10000
    end
    currentVP = self._vpLastVP
	end

	if not rankIcon or rankIcon == "" then
		rankIcon = LootDrop_sVpIcon
	end

	levelProgress = tostring(math.floor(100*(rankProgVP/rankMaxVP))).."%"
	local actualVP = currentExperience or 0
	local difference = (currentVP and  actualVP - currentVP) or 0

  if difference < 0 then difference = 0  end -- test 

	local RealDiff = difference 
	local realForm = self:FormatAmount(RealDiff, true)
	local rDiff = (isPreview) and realForm or self:FormatAmount(actualVP - currentVP, true)
	if isPreview then levelProgress = tostring(math.floor(100*((rankProgVP+RealDiff)/rankMaxVP))).."%" end

	local lootEntry, aIndex, isUpdate

	if (displayMode) then
		if ( self._vpId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_vp")
			if isUpdate then
				difference = difference + self._vpLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._vpId = aIndex
	self._vpLastVal = difference
	self._vpLastVPVal = self._vpLastVPVal + (actualVP - currentVP)
	self._vpLastVP = actualVP

	if (displayMode) then
		local showPrefix		= self.db.VP.showPrefix
		local showName			= self.db.VP.showName
		local showNameFull		= self.db.VP.showNameFull
		local showProgress		= self.db.VP.showProgress
		local showProgFull		= self.db.VP.showProgFull
		local showVPGain		= self.db.VP.showVPGain
		local showLevel			= self.db.VP.showLevel
		local showCName			= self.db.VP.showCName
		local showColor			= self.db.VP.showColor
		local nameColor			= self.db.VP.nameColor
		local c = (self.db.display.sListStyle==LootDrop_sDefPawkette) and '0000FF' or 'C5FFC0'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() ) 
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 17 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ) , self.db.display.rarity)
		lootEntry:SetIcon( LootDrop_sVpIcon )
		lootEntry:SetName("loot_vp")

		local lastVP = (showPrefix) and self:FormatAmount(self._vpLastVPVal, true) or self:FormatAmount(self._vpLastVPVal)
		local vpWForm = (showVPGain) and "|c00FF00VP:|r |cFFFFFF"..lastVP.."|r " or ""
		local vpWRank = (currentVPRank and currentVPRank > 0) and (zo_iconTextFormatNoSpace(rankIcon,28,28,"")..currentVPRank) or zo_iconTextFormatNoSpace(rankIcon,28,28,"")
		local normWForm = zo_strformat('|c736F6E(<<1>>)|r', levelProgress)
		local extWForm = zo_strformat('|c736F6E-> <<1>>/<<2>> (<<3>>)|r',self:FormatAmount(rankProgVP), self:FormatAmount(rankMaxVP), levelProgress)
		local gainForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local levelText = ((showLevel) and (showVPGain)) and LootDrop_Spacer..vpWForm.." "..vpWRank or (showLevel) and LootDrop_Spacer..vpWRank or (showVPGain) and LootDrop_Spacer..vpWForm or ""
		local progText = ((showProgress) and (showProgFull)) and extWForm or (showProgress) and normWForm or ""
		local nameText = ((showName) and (showNameFull) and (showCName ~= "")) and showCName or ((showName) and (showNameFull)) and " "..L.VeterancyPoints or (showName) and "vp" or ""
		if (showColor) then nameText = '|c'..LootDrop:num2hex(nameColor)..nameText..'|r' end

		lootEntry:SetLabel( zo_strformat('<<1>><<2>><<3>> <<4>>', gainForm, nameText, levelText, progText) )
	end

	if (self.db.chat.DbgLogVP) then
		local text = ""

		local vpForm = (self.db.chat.DbgVPGain) and "|c00FF00VP:|r |cFFFFFF"..rDiff.."|r " or ""
		local vpRank = (self.db.chat.DbgVPRank) and zo_strformat("<<1>>|cFFFFFF<<2>>|r", zo_iconTextFormatNoSpace(rankIcon,24,24,""), currentVPRank or "") or ""
		local baseForm = zo_strformat("<<1>> |c736F6E->|r <<2>><<3>>", realForm, vpForm, vpRank)
		local normForm = zo_strformat(' |c736F6E (<<1>>%)|r', self:FormatAmount(math.floor(100*(rankProgVP/rankMaxVP))))
		local extForm = zo_strformat(' |c736F6E (<<1>>/<<2>> = <<3>>%)|r', self:FormatAmount(rankProgVP), self:FormatAmount(rankMaxVP), self:FormatAmount(math.floor(100*(rankProgVP/rankMaxVP))))
		local progForm = ((RealDiff > 0) and (self.db.chat.DbgVPFull)) and extForm or (RealDiff > 0) and normForm or ""

		text = baseForm..progForm
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogVP)
		self:ChatOutput(LootDrop_sVpIcon, 1, text, 'VP', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end

-------------------------------------------------------------------------------
function LootDrop:OnTVUpdate( newTelvarStones, oldTelvarStones, reason )
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local difference = newTelvarStones - oldTelvarStones
	local displayMode = self.db.currency.showTelvar

	if (difference == 0) then return end

	local RealDiff=difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._tvId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_tv")
			if isUpdate then
				difference = difference + self._tvLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._tvId = aIndex
	self._tvLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.telvarPrefix
		local showName			= self.db.currency.telvarName
		local showMulti			= self.db.currency.telvarMulti
		local showCName			= self.db.currency.telvarCName
		local showColor			= self.db.currency.telvarSColor
		local nameColor			= self.db.currency.telvarColor
		local showBag			= self.db.currency.telvarBag
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 5 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sTVIcon )
		lootEntry:SetName("loot_tv")

		local TVmulti = (showMulti) and LootDrop_Spacer..GetTelvarStoneMultiplier(GetTelvarStoneMultiplierThresholdIndex()).."x" or ""
		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newTelvarForm = self:FormatAmount(newTelvarStones)
		local bagTelvar = (showBag) and LootDrop_Spacer..LootDrop_Bag..newTelvarForm or ""
		local TVname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.TelvarStones or ""
		if (showColor) then TVname = '|c'..LootDrop:num2hex(nameColor)..TVname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>> <<4>>', differenceForm, TVname, bagTelvar, TVmulti))
	end

	if (self.db.chat.DbgLogTelvar) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.TelvarStones, self:FormatAmount(newTelvarStones))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogTelvar)
		self:ChatOutput(LootDrop_sTVIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnWVoucherUpdate( newWVouchers, oldWVouchers, reason )
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local difference = newWVouchers - oldWVouchers
	local displayMode = self.db.currency.showVoucher

	if (difference == 0) then return end

	local RealDiff=difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._wVoucherId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_wvoucher")
			if isUpdate then
				difference = difference + self._wVoucherLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._wVoucherId = aIndex
	self._wVoucherLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.voucherPrefix
		local showName			= self.db.currency.voucherName
		local showCName			= self.db.currency.voucherCName
		local showColor			= self.db.currency.voucherSColor
		local nameColor			= self.db.currency.voucherColor
		local showBag			= self.db.currency.voucherBag
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 6 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sWVoucherIcon )
		lootEntry:SetName("loot_wvoucher")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newWVForm = self:FormatAmount(newWVouchers)
		local bagWV = (showBag) and LootDrop_Spacer..LootDrop_Bag..newWVForm or ""
		local WVname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.WritVouchers or ""
		if (showColor) then WVname = '|c'..LootDrop:num2hex(nameColor)..WVname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, WVname, bagWV))
	end

	if (self.db.chat.DbgLogWritVoucher) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.WritVouchers, self:FormatAmount(newWVouchers))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogWritVoucher)
		self:ChatOutput(LootDrop_sWVoucherIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnLoreBookLearned(categoryIndex, collectionIndex, bookIndex, guildIndex, isMaxRank)
	local displayMode = self.db.loot.bookLoot
	local lootEntry, aIndex = self:Acquire()

	local collectionName, collectionDescription, numKnownBooks, totalBooks, hidden, gamepadIcon, collectionId = GetLoreCollectionInfo(categoryIndex, collectionIndex)
	local bookTitle, bookIcon, bookKnown, bookId = GetLoreBookInfo(categoryIndex, collectionIndex, bookIndex)
	local smIconBookText = zo_strformat("<<1>>", bookTitle)
	local quantitiesTxt = ""
	if totalBooks ~= nil and totalBooks > 0 then
		quantitiesTxt = zo_strformat("|c7FD47F(<<1>>/<<2>>)|r", numKnownBooks, totalBooks)
	end
	local collectionIcon = "esoui/art/journal/journal_tabicon_lorelibrary_down.dds"
	local windowCText = zo_strformat("<<1>> <<2>> <<3>>", zo_iconTextFormat(collectionIcon, 24, 24, " "), collectionName, quantitiesTxt)
	local chatCText = zo_strformat("<<1>> <<2>> <<3>>", zo_iconTextFormat(collectionIcon, 18, 18, " "), collectionName, quantitiesTxt)
	local windowText = zo_strformat("<<1>> <<2>>", smIconBookText, windowCText)
	local chatText = zo_strformat("<<1>> <<2>>", smIconBookText, chatCText)

	if (displayMode) then
		local c = 'FFFF66'
		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 11 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( bookIcon )
		lootEntry:SetName("loot_book_knowledge")
		lootEntry:SetLabel(zo_strformat('<<1>>', windowText))
	end

	if (self.db.chat.DbgLogBookLoot) then
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogBookLoot)
		self:ChatOutput(bookIcon, 1, chatText, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnUndauntedUpdate( newUndaunted, oldUndaunted )
	local difference = newUndaunted - oldUndaunted
	local displayMode = self.db.currency.showUndaunted

	if (difference == 0) then return end

	local RealDiff=difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._undauntedId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_undaunted")
			if isUpdate then
				difference = difference + self._undauntedLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._undauntedId = aIndex
	self._undauntedLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.undauntedPrefix
		local showName			= self.db.currency.undauntedName
		local showCName			= self.db.currency.undauntedCName
		local showColor			= self.db.currency.undauntedSColor
		local nameColor			= self.db.currency.undauntedColor
		local showAccount		= self.db.currency.undauntedAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 7 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sUndauntedIcon )
		lootEntry:SetName("loot_undaunted")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newUForm = self:FormatAmount(newUndaunted)
		local uAcct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newUForm or ""
		local Uname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.UndauntedKeys or ""
		if (showColor) then Uname = '|c'..LootDrop:num2hex(nameColor)..Uname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, Uname, uAcct))
	end

	if (self.db.chat.DbgLogUndauntedKey) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.UndauntedKeys, self:FormatAmount(newUndaunted))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogUndauntedKey)
		self:ChatOutput(LootDrop_sUndauntedIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnTransmuteUpdate( newTransmute, oldTransmute )
	local difference = newTransmute - oldTransmute
	local displayMode = self.db.currency.showTransmute
	local max = tostring(GetMaxPossibleCurrency(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT))

	if (difference == 0) then return end

	local RealDiff=difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._transmuteId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_xmute")
			if isUpdate then
				difference = difference + self._transmuteLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._transmuteId = aIndex
	self._transmuteLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.transmutePrefix
		local showName			= self.db.currency.transmuteName
		local showMax			= self.db.currency.transmuteMax
		local showCName			= self.db.currency.transmuteCName
		local showColor			= self.db.currency.transmuteSColor
		local nameColor			= self.db.currency.transmuteColor
		local showAccount		= self.db.currency.transmuteAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 8 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sTransmuteIcon )
		lootEntry:SetName("loot_xmute")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local TCmax = ((showMax) and (showAccount)) and "/"..max or ""
		local newTCForm = self:FormatAmount(newTransmute)
		local tAcct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newTCForm or ""
		local TCname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.TransmuteCrystals or ""
		if (showColor) then TCname = '|c'..LootDrop:num2hex(nameColor)..TCname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>><<4>>', differenceForm, TCname, tAcct, TCmax))
	end

	if (self.db.chat.DbgLogTransmuteCrystal) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.TransmuteCrystals, self:FormatAmount(newTransmute))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogTransmuteCrystal)
		self:ChatOutput(LootDrop_sTransmuteIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnETicketUpdate( newETicket, oldETicket )
	local difference = newETicket - oldETicket
	local displayMode = self.db.currency.showEticket
	
	local max = GetMaxPossibleCurrency(CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT)

	if (difference == 0) then return end

	local RealDiff=difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._eticketId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_eticket")
			if isUpdate then
				difference = difference + self._eticketLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._eticketId = aIndex
	self._eticketLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.eticketPrefix
		local showName			= self.db.currency.eticketName
		local showMax			= self.db.currency.eticketMax
		local showCName			= self.db.currency.eticketCName
		local showColor			= self.db.currency.eticketSColor
		local nameColor			= self.db.currency.eticketColor
		local showAccount		= self.db.currency.eticketAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 9 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sETicketIcon )
		lootEntry:SetName("loot_eticket")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local ETmax = ((showMax) and (showAccount)) and "/"..max or ""
		local newETForm = self:FormatAmount(newETicket)
		local ETacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newETForm or ""
		local ETname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.EventTickets or ""
		if (showColor) then ETname = '|c'..LootDrop:num2hex(nameColor)..ETname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>><<4>>', differenceForm, ETname, ETacct, ETmax))
	end

	if (self.db.chat.DbgLogEventTicket) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.EventTickets, self:FormatAmount(newETicket))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogEventTicket)
		self:ChatOutput(LootDrop_sETicketIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnEndeavorUpdate( newEndeavor, oldEndeavor )
	local difference = newEndeavor - oldEndeavor
	local displayMode = self.db.currency.showEndeavor

	if (difference == 0) then return end

	local RealDiff = difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._EndeavorId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_endeavor")
			if isUpdate then
				difference = difference + self._EndeavorLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._EndeavorId = aIndex
	self._EndeavorLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.endeavorPrefix
		local showName			= self.db.currency.endeavorName
		local showCName			= self.db.currency.endeavorCName
		local showColor			= self.db.currency.endeavorSColor
		local nameColor			= self.db.currency.endeavorColor
		local showAccount		= self.db.currency.endeavorAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 10 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sEndeavorIcon )
		lootEntry:SetName("loot_endeavor")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newSEForm = self:FormatAmount(newEndeavor)
		local SEacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newSEForm or ""
		local SEname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.Endeavor or ""
		if (showColor) then SEname = '|c'..LootDrop:num2hex(nameColor)..SEname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, SEname, SEacct))
	end

	if (self.db.chat.DbgLogEndeavor) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.Endeavor, self:FormatAmount(newEndeavor))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogEndeavor)
		self:ChatOutput(LootDrop_sEndeavorIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnEndlessUpdate( newEndless, oldEndless )
	local difference = newEndless - oldEndless
	local displayMode = self.db.currency.showEndless

	if (difference == 0) then return end

	local RealDiff = difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._EndlessId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_endless")
			if isUpdate then
				difference = difference + self._EndlessLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._EndlessId = aIndex
	self._EndlessLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.endlessPrefix
		local showName			= self.db.currency.endlessName
		local showCName			= self.db.currency.endlessCName
		local showColor			= self.db.currency.endlessSColor
		local nameColor			= self.db.currency.endlessColor
		local showAccount		= self.db.currency.endlessAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 14 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sEndlessIcon )
		lootEntry:SetName("loot_endless")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newAFForm = self:FormatAmount(newEndless)
		local FAacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newAFForm or ""
		local FAname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.Endless or ""
		if (showColor) then FAname = '|c'..LootDrop:num2hex(nameColor)..FAname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, FAname, FAacct))
	end

	if (self.db.chat.DbgLogEndless) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.Endless, self:FormatAmount(newEndless))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogEndless)
		self:ChatOutput(LootDrop_sEndlessIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnFragmentUpdate( newFragment, oldFragment )
	local difference = newFragment - oldFragment
	local displayMode = self.db.currency.showFragment

	if (difference == 0) then return end

	local RealDiff = difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._FragmentsId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_fragments")
			if isUpdate then
				difference = difference + self._FragmentsLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._FragmentsId = aIndex
	self._FragmentsLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.fragmentPrefix
		local showName			= self.db.currency.fragmentName
		local showCName			= self.db.currency.fragmentCName
		local showColor			= self.db.currency.fragmentSColor
		local nameColor			= self.db.currency.fragmentColor
		local showAccount		= self.db.currency.fragmentAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 15 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sFragmentsIcon )
		lootEntry:SetName("loot_fragments")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newIFForm = self:FormatAmount(newFragment)
		local IFacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newIFForm or ""
		local IFname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.Fragment or ""
		if (showColor) then IFname = '|c'..LootDrop:num2hex(nameColor)..IFname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, IFname, IFacct))
	end

	if (self.db.chat.DbgLogFragments) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.Fragment, self:FormatAmount(newFragment))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogFragments)
		self:ChatOutput(LootDrop_sFragmentsIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnTomePointsUpdate( newTomePoints, oldTomePoints )
	local difference = newTomePoints - oldTomePoints
	local displayMode = self.db.currency.showTomePoints

	if (difference == 0) then return end

	local RealDiff = difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._TomePointsId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_TomePoints")
			if isUpdate then
				difference = difference + self._TomePointsLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._TomePointsId = aIndex
	self._TomePointsLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.TomePointsPrefix
		local showName			= self.db.currency.TomePointsName
		local showCName			= self.db.currency.TomePointsCName
		local showColor			= self.db.currency.TomePointsSColor
		local nameColor			= self.db.currency.TomePointsColor
		local showAccount		= self.db.currency.TomePointsAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 15 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sTomePointsIcon )
		lootEntry:SetName("loot_TomePoints")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newTPForm = self:FormatAmount(newTomePoints)
		local TPacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newTPForm or ""
		local TPname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.TomePoints or ""
		if (showColor) then TPname = '|c'..LootDrop:num2hex(nameColor)..TPname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, TPname, TPacct))
	end

	if (self.db.chat.DbgLogTomePoints) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.TomePoints, self:FormatAmount(newTomePoints))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogTomePoints)
		self:ChatOutput(LootDrop_sTomePointsIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnTomePointCachesUpdate( newTomePointCaches, oldTomePointCaches )
	local difference = newTomePointCaches - oldTomePointCaches
	local displayMode = self.db.currency.showTomePointCaches

	if (difference == 0) then return end

	local RealDiff = difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._TomePointCachesId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_TomePointCaches")
			if isUpdate then
				difference = difference + self._TomePointCachesLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._TomePointCachesId = aIndex
	self._TomePointCachesLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.TomePointCachesPrefix
		local showName			= self.db.currency.TomePointCachesName
		local showCName			= self.db.currency.TomePointCachesCName
		local showColor			= self.db.currency.TomePointCachesSColor
		local nameColor			= self.db.currency.TomePointCachesColor
		local showAccount		= self.db.currency.TomePointCachesAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 15 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sTomePointCachesIcon )
		lootEntry:SetName("loot_TomePointCaches")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newTPCForm = self:FormatAmount(newTomePointCaches)
		local TPCacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newTPCForm or ""
		local TPCname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.TomePointCaches or ""
		if (showColor) then TPCname = '|c'..LootDrop:num2hex(nameColor)..TPCname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, TPCname, TPCacct))
	end

	if (self.db.chat.DbgLogTomePointCaches) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.TomePointCaches, self:FormatAmount(newTomePointCaches))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogTomePointCaches)
		self:ChatOutput(LootDrop_sTomePointCachesIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnTomeTokensUpdate( newTomeTokens, oldTomeTokens )
	local difference = newTomeTokens - oldTomeTokens
	local displayMode = self.db.currency.showTomeTokens

	if (difference == 0) then return end

	local RealDiff = difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._TomeTokensId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_TomeTokens")
			if isUpdate then
				difference = difference + self._TomeTokensLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._TomeTokensId = aIndex
	self._TomeTokensLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.TomeTokensPrefix
		local showName			= self.db.currency.TomeTokensName
		local showCName			= self.db.currency.TomeTokensCName
		local showColor			= self.db.currency.TomeTokensSColor
		local nameColor			= self.db.currency.TomeTokensColor
		local showAccount		= self.db.currency.TomeTokensAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 15 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sTomeTokensIcon )
		lootEntry:SetName("loot_TomeTokens")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newTTForm = self:FormatAmount(newTomeTokens)
		local TTCacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newTTForm or ""
		local TTname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.TomeTokens or ""
		if (showColor) then TTname = '|c'..LootDrop:num2hex(nameColor)..TTname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, TTname, TTacct))
	end

	if (self.db.chat.DbgLogTomeTokens) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.TomeTokens, self:FormatAmount(newTomeTokens))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogTomePointCaches)
		self:ChatOutput(LootDrop_sTomeTokensIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:OnTradeBarsUpdate( newTradeBars, oldTradeBars )
	local difference = newTradeBars - oldTradeBars
	local displayMode = self.db.currency.showTradeBars

	if (difference == 0) then return end

	local RealDiff = difference
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._TradeBarsId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_TradeBars")
			if isUpdate then
				difference = difference + self._TradeBarsLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._TradeBarsId = aIndex
	self._TradeBarsLastVal = difference

	if (displayMode) then
		local showPrefix		= self.db.currency.TradeBarsPrefix
		local showName			= self.db.currency.TradeBarsName
		local showCName			= self.db.currency.TradeBarsCName
		local showColor			= self.db.currency.TradeBarsSColor
		local nameColor			= self.db.currency.TradeBarsColor
		local showAccount		= self.db.currency.TradeBarsAcct
		local c = 'FFFF66'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 15 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( LootDrop_sTradeBarsIcon )
		lootEntry:SetName("loot_TradeBars")

		local differenceForm = (showPrefix) and self:FormatAmount(difference, true) or self:FormatAmount(difference)
		local newTBForm = self:FormatAmount(newTradeBars)
		local TBacct = (showAccount) and LootDrop_Spacer..LootDrop_Account..newTBForm or ""
		local TBname = ((showName) and (showCName ~= "")) and showCName or (showName) and " "..L.TradeBars or ""
		if (showColor) then TBname = '|c'..LootDrop:num2hex(nameColor)..TBname..'|r' end

		lootEntry:SetLabel(zo_strformat('<<1>><<2>><<3>>', differenceForm, TBname, TBacct))
	end

	if (self.db.chat.DbgLogTradeBars) then
		local text=zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>|r', self:FormatAmount(RealDiff, true), L.TradeBars, self:FormatAmount(newTradeBars))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogTradeBars)
		self:ChatOutput(LootDrop_sTradeBarsIcon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:CompanionXPUpdate(companionId, previousLevel, previousExperience, currentExperience, v1, preview)
	local gain = currentExperience - previousExperience
	local showCFull = self.db.compXP.showCFull
	local companionIcon
	local companionName
	local level, currentXpInLevel, totalXpInLevel, isMaxLevel

	if (preview ~= nil) and (preview == "preview") then
	--	self:CompanionXPUpdate(xpForLevelUp, tLevel, previous, current, nil, "preview") -- data from preview for reference
		companionIcon = "/esoui/art/icons/comp_bastian.dds"
		companionName = "Bastian Hallix"
		level, currentXpInLevel, totalXpInLevel, isMaxLevel = previousLevel, currentExperience, companionId, false
	else
		if ( gain <= 0 ) then return end -- no gain so nothing to display
		self:ResetCompanionId(companionId) -- avoid stacking gains from different companions (Phinix)
		companionIcon = GetCollectibleIcon(GetCompanionCollectibleId(companionId))
		companionName = zo_strformat('<<1>>', GetCompanionName(companionId))
		level, currentXpInLevel, totalXpInLevel, isMaxLevel = ZO_COMPANION_MANAGER:GetLevelInfo()
	end

	local companionLevel = L.LevelPsijic.." "..tostring(level)
	local displayMode = self.db.compXP.showXP
	local iSize = tostring(self.db.display.fontSize)
	local fullName = (companionName:match(" ")) and companionName:match(".+ ")..companionName:match(" .+"):gsub(' ','') or companionName
	local firstName = (companionName:match(" ")) and companionName:match(".+ "):gsub(' ','') or companionName
	local cNameFormat = zo_strformat('<<1>><<2>><<3>>', "|c9DFE00", (showCFull) and fullName or firstName, "|r ".."|t"..iSize..":"..iSize..":"..LootDrop_sXpIcon.."|t".." ")
	local RealDiff = gain
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._xpCompanionId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_cxp")
			if isUpdate then
				gain = gain + self._xpCompanionLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._xpCompanionId = aIndex
	self._xpCompanionLastVal = gain

	local xpForLevelUp
	if not isMaxLevel then
		xpForLevelUp = totalXpInLevel
	else
		xpForLevelUp = 0
	end
	local levelProgress = tostring(math.floor(100*(currentExperience/xpForLevelUp))).."%"

	if (displayMode) then
		local showPrefix		= self.db.compXP.showPrefix
		local showName			= self.db.compXP.showName
		local showNameFull		= self.db.compXP.showNameFull
		local showProgress		= self.db.compXP.showProgress
		local showProgFull		= self.db.compXP.showProgFull
		local showLevel			= self.db.compXP.showLevel
		local showCName			= self.db.compXP.showCName
		local showColor			= self.db.compXP.showColor
		local nameColor			= self.db.compXP.nameColor
		local c = (self.db.display.sListStyle==LootDrop_sDefPawkette) and '00FF00' or 'FFFFFF'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 12 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( companionIcon )
		lootEntry:SetName("loot_cxp")

		local normalProgress = zo_strformat('|c736F6E(<<1>>)|r', levelProgress)
		local extendedProgress = zo_strformat('|c736F6E-> <<1>>/<<2>> (<<3>>)|r',self:FormatAmount(currentExperience), self:FormatAmount(xpForLevelUp), levelProgress)
		local gainForm = (showPrefix) and self:FormatAmount(gain, true) or self:FormatAmount(gain)
		local levelText = (showLevel) and LootDrop_Spacer..companionLevel or ""
		local progText = ((showProgress) and (showProgFull) and (not isMaxLevel)) and extendedProgress or ((showProgress) and (not isMaxLevel)) and normalProgress or ""
		local nameText = ((showName) and (showNameFull) and (showCName ~= "")) and showCName or ((showName) and (showNameFull)) and " "..L.CompanionXP or (showName) and "xp" or ""
		if (showColor) then nameText = '|c'..LootDrop:num2hex(nameColor)..nameText..'|r' end

		lootEntry:SetLabel( cNameFormat..zo_strformat('<<1>><<2>><<3>> <<4>>', gainForm, nameText, levelText, progText) )
	end

	if (self.db.chat.DbgLogCXp) then
		local text = ""
		if isMaxLevel then
			text = zo_strformat('<<1>> <<2>>', self:FormatAmount(RealDiff), L.CompanionXP)
		else
			text = zo_strformat('<<1>> <<2>> |c736F6E-> <<3>>/<<4>> (<<5>>%)|r', self:FormatAmount(RealDiff), L.CompanionXP, self:FormatAmount(currentExperience), self:FormatAmount(xpForLevelUp), tostring(math.floor(100*(currentExperience/xpForLevelUp))))
		end
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogCXp)
		self:ChatOutput(companionIcon, 1, cNameFormat.." "..text, 'XP', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:CompanionRapportUpdate(companionId, previousRapport, currentRapport, v1, preview)
	local gain = currentRapport - previousRapport
	local showCFull = self.db.rapport.showCFull
	local companionIcon
	local companionName
	local rapportLevel
	local rapportValue

	local rLevels = { -- values are based on wiki and may be inaccurate: https://en.uesp.net/wiki/Online:Companions#XP_Table
		[1] = {min = -3999,	max = -2500,	color = "ff9600"},	-- Irritated
		[2] = {min = -2499,	max = 749,		color = "ffc000"},	-- Wary
		[3] = {min = 750,	max = 999,		color = "fff600"},	-- Cordial
		[4] = {min = 1000,	max = 1999,		color = "96ff00"},	-- Friendly
		[5] = {min = 2000,	max = 2999,		color = "8aff00"},	-- Close
		[6] = {min = 3000,	max = 3999,		color = "00ff00"},	-- Allied
		[7] = {min = 4000,	max = 5500,		color = "00ff00"},	-- Companion
	}

	if (preview ~= nil) and (preview == "preview") then
	--	self:CompanionXPUpdate(xpForLevelUp, tLevel, previous, current, nil, "preview") -- data from preview for reference
		companionIcon = "/esoui/art/icons/comp_bastian.dds"
		companionName = "Bastian Hallix"
		rapportLevel = math.random(3,7)
		rapportValue = math.random(rLevels[rapportLevel].min,rLevels[rapportLevel].max)
	else
		self:ResetCompanionId(companionId) -- avoid stacking gains from different companions (Phinix)
		companionIcon = GetCollectibleIcon(GetCompanionCollectibleId(companionId))
		companionName = zo_strformat('<<1>>', GetCompanionName(companionId))
		rapportLevel = GetActiveCompanionRapportLevel()
		rapportValue = GetActiveCompanionRapport()
	--	d("rapportLevel: "..tostring(rapportLevel))
	--	d("rapportValue: "..tostring(rapportValue))
	--	d("rapport: "..GetActiveCompanionRapportLevelDescription(rapportLevel))
	end

	local sColor = "f22e00"
	sColor = (rLevels[rapportLevel] ~= nil) and rLevels[rapportLevel].color or sColor

	local iSize = tostring(self.db.display.fontSize)
	local displayMode = self.db.rapport.showRppt

	local RealDiff = gain
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._rapportId ) then
			lootEntry, aIndex, isUpdate = self:Get("loot_rapport")
			if isUpdate then
				gain = gain + self._rapportLastVal
			end
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._rapportId = aIndex
	self._rapportLastVal = gain

	local rdIcon = (gain > 0) and LootDrop_sRapportUpIcon or LootDrop_sRapportDownIcon
	local fullName = (companionName:match(" ")) and companionName:match(".+ ")..companionName:match(" .+"):gsub(' ','') or companionName
	local firstName = (companionName:match(" ")) and companionName:match(".+ "):gsub(' ','') or companionName
	local cNameFormat = zo_strformat('<<1>><<2>><<3>>', "|c9DFE00", (showCFull) and fullName or firstName, "|r ".."|t"..iSize..":"..iSize..":"..rdIcon.."|t".." ")
	local vProgress = (rapportLevel < 7)

	-- calculate the absolute value range and progress for the current companion rapport level (Phinix)
	local pMin = rLevels[rapportLevel].min
	local pMax = rLevels[rapportLevel].max
	local pRange = (rapportLevel ~= 2) and math.abs(pMax - pMin) or math.abs(pMin - pMax)
	local pValue = (rapportLevel ~= 2) and math.abs(pMin - rapportValue) or (pMin - rapportValue < 0) and math.abs(pMin - rapportValue) or math.abs(pMin) + pMin - rapportValue
	local levelProgress = tostring(math.floor(100*(pValue/pRange))).."%"
	local normalProgress = zo_strformat('|c736F6E(<<1>>)|r', levelProgress)
	local extendedProgress = zo_strformat('|c736F6E-> <<1>>/<<2>> (<<3>>)|r',pValue, pRange, levelProgress)
--	d("pMin: "..tostring(pMin))
--	d("pMax: "..tostring(pMax))
--	d("pRange: "..tostring(pRange))
--	d("pValue: "..tostring(pValue))

	if (displayMode) then
		local showPrefix		= self.db.rapport.showPrefix
		local showNameFull		= self.db.rapport.showNameFull
		local showCName			= self.db.rapport.showCName
		local showColor			= self.db.rapport.showColor
		local nameColor			= self.db.rapport.nameColor
		local showProgress		= self.db.rapport.showProgress
		local showProgFull		= self.db.rapport.showProgFull
		local showStatus		= self.db.rapport.showStatus

		local c = (self.db.display.sListStyle==LootDrop_sDefPawkette) and '00FF00' or 'FFFFFF'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 12 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( companionIcon )
		lootEntry:SetName("loot_rapport")

		local gainForm = (showPrefix) and self:FormatAmount(gain, true) or self:FormatAmount(gain)
		local rText = ((showNameFull) and (showCName ~= "")) and showCName or (showNameFull) and " "..L.Rapport or ""
		if (showColor) then rText = '|c'..LootDrop:num2hex(nameColor)..rText..'|r' end
		local rapportStatus = (showStatus) and " |c"..sColor..GetString("SI_COMPANIONRAPPORTLEVEL", rapportLevel).."|r" or ""
		local progText = ((vProgress) and (showProgress) and (showProgFull)) and " "..extendedProgress or ((vProgress) and (showProgress)) and " "..normalProgress or ""

		lootEntry:SetLabel( cNameFormat..zo_strformat('<<1>><<2>><<3>><<4>>', gainForm, rText, progText, rapportStatus) )
	end

	if (self.db.chat.DbgLogCRpt) then
		local cProg = ((vProgress) and (self.db.chat.DbgLogCRptExt)) and " "..extendedProgress or (vProgress) and " "..normalProgress or ""
		local rapportDescription = (self.db.chat.DbgLogCRptDesc) and " |c"..sColor..GetActiveCompanionRapportLevelDescription(rapportLevel).."|r" or ""
		local text = cNameFormat .. zo_strformat('<<1>> <<2>> <<3>><<4>>', self:FormatAmount(RealDiff, true), L.Rapport, cProg, rapportDescription)
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgLogCRpt)
		self:ChatOutput(companionIcon, 1, text, 'RP', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:AchievementComplete(name, points, id, link)
	local _, _, _, icon = GetAchievementInfo(id)
	local cName = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
	local displayMode = ((self.db.achievements.showAchieve) and (self.db.achievements.showCompleted))
	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		lootEntry, aIndex = self:Acquire()
		isUpdate = false
	end

	if (displayMode) then
		local showPoints		= self.db.achievements.showPoints
		local showColor			= self.db.achievements.cachieveSColor
		local nameColor			= self.db.achievements.cachieveColor
		local c = '66FFFF'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 13 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( icon )
		lootEntry:SetName("loot_cachieve")

		local aPoints = (showPoints) and ' ('.. self:FormatAmount(points, true) .. ')' or ""
		local CAname = (showColor) and '|c'..LootDrop:num2hex(nameColor)..cName..'|r' .. ' ' .. L.CAchievement .. aPoints or cName .. ' ' .. L.CAchievement .. aPoints
		lootEntry:SetLabel(zo_strformat('<<1>>', CAname))
	end

	if (self.db.chat.DbgCAchievements) then
		local aLink = (self.db.chat.DbgShowAchBrackets) and GetAchievementLink(id, 1) or GetAchievementLink(id)
		local text=zo_strformat('<<1>> <<2>> (<<3>>)', aLink, L.CAchievement, self:FormatAmount(points, true))
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgCAchievements)
		self:ChatOutput(icon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
function LootDrop:AchievementUpdated(id, preview)
	local isPreview = ((preview ~= nil) and (preview == "preview"))
	local name, _, _, icon, completed = GetAchievementInfo(id)

--	if (completed) then return end -- may not be necessary to prevent duplicating achievement completion from other event (Phinix)

	local cName = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
	local displayMode = ((self.db.achievements.showAchieve) and (self.db.achievements.showProgress))
	local nCrit = GetAchievementNumCriteria(id)
	local cText = ""
	if (isPreview) then
		if nCrit > 1 then
			local cTotal = 0
			for i = 1, nCrit do
				local cCom = math.random(0,1)
				cTotal = cTotal + cCom
			end
			cText = ' (' .. tostring(cTotal) .. '\/' .. tostring(nCrit) .. ')'
		else
			local cDesc, xCom, cReq = GetAchievementCriterion(id, 1)
			local cCom = math.random(0,cReq)
			cText = ' (' .. tostring(cCom) .. '\/' .. tostring(cReq) .. ')'
		end
	else
		if nCrit > 1 then
			local cTotal = 0
			for i = 1, nCrit do
				local cDesc, cCom, cReq = GetAchievementCriterion(id, i)
				if cCom >= cReq then cTotal = cTotal + 1 end
			end
			cText = ' (' .. tostring(cTotal) .. '\/' .. tostring(nCrit) .. ')'
		else
			local cDesc, cCom, cReq = GetAchievementCriterion(id, 1)
			cText = ' (' .. tostring(cCom) .. '\/' .. tostring(cReq) .. ')'
		end
	end

	local lootEntry, aIndex, isUpdate

	if (displayMode) then -- allowing to enable chat output when loot display disabled (Phinix)
		if ( self._achieveTable[id] ~= nil ) then
			lootEntry, aIndex, isUpdate = self:Get("achievement_"..tostring(id))
		end

		if ( not lootEntry ) then
			lootEntry, aIndex = self:Acquire()
			isUpdate = false
		end
	end

	self._achieveTable[id] = aIndex

	if (displayMode) then
		local showColor			= self.db.achievements.pachieveSColor
		local nameColor			= self.db.achievements.pachieveColor
		local c = '66FFFF'

		lootEntry:SetTimestamp( GetFrameTimeMilliseconds() )
		lootEntry:SetBackground()
		lootEntry:SetLabelSize( self.db.display.fontSize, 13 )
		lootEntry:SetRarity( ZO_ColorDef:New( c ), self.db.display.rarity )
		lootEntry:SetIcon( icon )
		lootEntry:SetName("achievement_"..tostring(id))

		local PAname = (showColor) and '|c'..LootDrop:num2hex(nameColor)..cName..'|r' .. ' ' .. L.AProgress .. cText or cName .. ' ' .. L.AProgress .. cText
		lootEntry:SetLabel(zo_strformat('<<1>>', PAname))
	end

	if (self.db.chat.DbgPAchievements) then
		local aLink = (self.db.chat.DbgShowAchBrackets) and GetAchievementLink(id, 1) or GetAchievementLink(id)
		local text=zo_strformat('<<1>> <<2>><<3>>', aLink, L.AProgress, cText)
		local tab = self:GetOutputTab(self.db.chat.DbgLogTab.DbgPAchievements)
		self:ChatOutput(icon, 1, text, '', true, nil, nil, nil, tab)
	end

	if aIndex and aIndex <= self.db.display.maxstacks then
		local anim = self._pop:Apply( lootEntry.control )
		anim:Forward()
	end
end
-------------------------------------------------------------------------------
--- Called when the amount of a special currency you have changes
-- Sends to individual update functions
function LootDrop:OnCurrencyUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	if currencyType == CURT_UNDAUNTED_KEYS then
		self:OnUndauntedUpdate( newAmount, oldAmount )
	elseif currencyType == CURT_CHAOTIC_CREATIA then
		self:OnTransmuteUpdate( newAmount, oldAmount )
	elseif currencyType == CURT_EVENT_TICKETS then
		self:OnETicketUpdate( newAmount, oldAmount )
	elseif currencyType == CURT_SEALS then
		self:OnEndeavorUpdate( newAmount, oldAmount )
	elseif currencyType == CURT_ARCHIVAL_FORTUNES then
		self:OnEndlessUpdate( newAmount, oldAmount )
	elseif currencyType == CURT_IMPERIAL_FRAGMENTS then
		self:OnFragmentUpdate( newAmount, oldAmount )
	elseif currencyType == CURT_TOME_POINTS then
		self:OnTomePointsUpdate( newAmount, oldAmount )
 	elseif currencyType == CURT_TOME_POINT_CACHES then
		self:OnTomePointCachesUpdate( newAmount, oldAmount )
 	elseif currencyType == CURT_TOME_TOKENS then
		self:OnTomeTokensUpdate( newAmount, oldAmount )
 	elseif currencyType == CURT_TRADE_BARS then
		self:OnTradeBarsUpdate( newAmount, oldAmount ) 
	end
end
-------------------------------------------------------------------------------
--- Called when group is joined/left/changes.
-- Maintains table of account name indexed by character name strings so loot functions can access account name (Phinix)
function LootDrop:OnGroupChanged()
	LootDrop.GroupNames = {}
	if IsUnitGrouped("player") then
		if (self.db.chat.DbgLogOthers) and self.db.chat.DbgLogGname ~= 0 then
			local groupSize = GetGroupSize()
			for s = 1, groupSize do
				local unitTag = GetGroupUnitTagByIndex(s)
				if (DoesUnitExist(unitTag)) then
					local displayName = zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag))
					local unitName = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag))
					LootDrop.GroupNames[unitName] = displayName
				end
			end
		end
	end
end
-------------------------------------------------------------------------------
--- Getter for the control xml element
-- @treturn table 
function LootDrop:GetControl()
	return self.control
end
-------------------------------------------------------------------------------
function LootDrop_Initialized( self )
    LootDrop:New( self )
end
-------------------------------------------------------------------------------
function LootDrop:ChatOutput(iconFilename, quantity, text, tag, mine, unitName, quality, value, tab)
	local DbgLogMine = self.db.chat.DbgLogMine
	local DbgLogMineQlty = self.db.chat.DbgLogMineQlty
	local DbgLogOthers = self.db.chat.DbgLogOthers
	local DbgLogOthersQlty = self.db.chat.DbgLogOthersQlty
	local DbgLogGname = self.db.chat.DbgLogGname
	local DbgHideChat = self.db.general.DbgHideChat
	local dotEnd = "."
	local output = ""

	local function CreateIcon(filename, width, height)
		return zo_iconFormat(filename, width or 16, height or 16)
	end

	if (DbgHideChat) then return end
	if (mine and not DbgLogMine) then return end
	if (not mine and not DbgLogOthers) then return end

	if tag == 'INV' or tag == 'JUNK' or tag == 'MAIL' then
		local qCheck = (quality ~= nil) and quality or 0
		if (mine) and (qCheck < DbgLogMineQlty) then return end
		if (not mine) and (qCheck < DbgLogOthersQlty) then return end
	end

	if not iconFilename or iconFilename == '' then
		iconFilename = "/esoui/art/icons/icon_missing.dds"
	end

	local dbgLogTime = ""
	if self.db.display.DbgLogTime then
		dbgLogTime = string.format("[%s]:", GetTimeString())
	end

	local icon = CreateIcon(iconFilename)
	local tUN = zo_strformat(SI_UNIT_NAME, unitName)

	if not mine then -- set the custom display of group name if selected (Phinix)
		if DbgLogGname ~= 0 then
			if DbgLogGname == 1 then
				if LootDrop.GroupNames[tUN] ~= nil then
					tUN = LootDrop.GroupNames[tUN]
				end
			elseif DbgLogGname == 2 then
				if LootDrop.GroupNames[tUN] ~= nil then
					tUN = tUN.."("..LootDrop.GroupNames[tUN]..")"
				end
			end
		end
	end

	local dbgText2 = (quantity > 1) and tostring(quantity).."x "..text or text

	if tag == 'INV' or tag == 'JUNK' or tag == 'MAIL' then
		if mine then
			dbgText2 = (quantity > 1) and tostring(quantity).."x "..text.." |c736F6E("..self.ItemToPrint.nb..")|r" or text.." |c736F6E("..self.ItemToPrint.nb..")|r"
		else
			dbgText2 = (quantity > 1) and tostring(quantity).."x "..text or text
		end

		if ((self.db.display.DbgLogItemStyle) and (self.ItemToPrint.itemStyle ~= nil)) then -- show item style if set in options
			dbgText2 = dbgText2 .. self.ItemToPrint.itemStyle
		end

		if (self.db.display.DbgLogItemTrait) then -- show item trait if set in options
			local traitType, traitDescription = GetItemLinkTraitInfo(text)
			if traitType ~= ITEM_TRAIT_TYPE_NONE and traitDescription ~= "" then
				local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
				if traitName ~= "" then
					local traitInformation = GetItemTraitInformationFromItemLink(text)
					local formattedTraitName = zo_strformat(SI_ITEM_FORMAT_STR_ITEM_TRAIT_HEADER, traitName)
					dbgText2 = dbgText2 .. " |cFFFFFF["..formattedTraitName.."]|r"
				end
			end
		end

		if (self.db.display.DbgLogItemValue) then
			dbgText2 = dbgText2 .. value
		end
	elseif tag == "RP" then
		if (self.db.chat.DbgLogCRptDesc) then dotEnd = "" end
	end

	local dbgText3=''
	if ((tag ~= '') and (self.db.display.DbgLogTag)) then dbgText3='('..tag..')' end

	if mine then
		output = zo_strformat( '<<1>> <<2>> <<3>> <<4>><<5>>', dbgLogTime, icon, dbgText2, dbgText3, dotEnd)
	else
		output = zo_strformat( "<<1>> <<2>>: <<3>> <<4>>", dbgLogTime, tUN, icon, dbgText2)
	end

	if tab and CHAT_SYSTEM and CHAT_SYSTEM.containers and CHAT_SYSTEM.containers[1] and CHAT_SYSTEM.containers[1].windows and CHAT_SYSTEM.containers[1].windows[tab] then
		CHAT_SYSTEM.containers[1].windows[tab].buffer:AddMessage(output)
	else
		CHAT_SYSTEM:AddMessage(output)
	end
end
-------------------------------------------------------
function LootDrop:LootPreview() -- Generate fake loots in real-time to make it easier setting up your visual settings (Phinix)
	if LootDropPreview ~= nil then LootDropPreview.dropdown:SetSelectedItem(opTable[previewMode]) end

	local previewTable = { -- table of items used to generate loot preview
		[1]	= {link = "|H1:item:71198:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Rubedite Ore
		[2]	= {link = "|H1:item:64489:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Rubedite Ingot
		[3]	= {link = "|H1:item:54170:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Honing Stone
		[4]	= {link = "|H1:item:54171:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Dwarven Oil
		[5]	= {link = "|H1:item:54172:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Grain Solvent
		[6]	= {link = "|H1:item:54173:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Tempering Alloy
		[7]	= {link = "|H1:item:71200:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Raw Ancestor Silk
		[8]	= {link = "|H1:item:71239:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Rubedo Leather Scraps
		[9]	= {link = "|H1:item:64504:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Ancestor Silk
		[10] = {link = "|H1:item:64506:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Rubedo Leather
		[11] = {link = "|H1:item:54174:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Hemming
		[12] = {link = "|H1:item:54175:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Embroidery
		[13] = {link = "|H1:item:54176:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Elegant Lining
		[14] = {link = "|H1:item:54177:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Dreugh Wax
		[15] = {link = "|H1:item:71199:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Rough Ruby Ash
		[16] = {link = "|H1:item:64502:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Sanded Ruby Ash
		[17] = {link = "|H1:item:54178:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Pitch
		[18] = {link = "|H1:item:54179:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Turpin
		[19] = {link = "|H1:item:54180:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Mastic
		[20] = {link = "|H1:item:54181:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Rosin
		[21] = {link = "|H1:item:135145:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Platinum Dust
		[22] = {link = "|H1:item:135146:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Platinum Ounce
		[23] = {link = "|H1:item:135147:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Terne Plating
		[24] = {link = "|H1:item:135148:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Iridium Plating
		[25] = {link = "|H1:item:135149:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Zircon Plating
		[26] = {link = "|H1:item:135150:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"},		-- Chromium Plating
-- gear
		[27] = {link = "|H1:item:2559:358:50:0:0:0:0:0:0:0:0:0:0:0:0:4:0:0:0:10000:0|h|h"},
		[28] = {link = "|H1:item:86067:359:50:0:0:0:0:0:0:0:0:0:0:0:0:19:0:0:0:10000:0|h|h"},
		[29] = {link = "|H1:item:86336:362:50:0:0:0:0:0:0:0:0:0:0:0:0:55:0:0:0:10000:0|h|h"},
		[30] = {link = "|H1:item:101472:363:50:0:0:0:0:0:0:0:0:0:0:0:0:5:0:0:0:10000:0|h|h"},
		[31] = {link = "|H1:item:45340:111:50:0:0:0:0:0:0:0:0:0:0:0:0:2:0:0:0:10000:0|h|h"},
		[32] = {link = "|H1:item:155060:363:50:0:0:0:0:0:0:0:0:0:0:0:0:85:0:0:0:10000:0|h|h"},
		[33] = {link = "|H1:item:101493:362:50:0:0:0:0:0:0:0:0:0:0:0:0:5:0:0:0:10000:0|h|h"},
		[34] = {link = "|H1:item:154914:362:50:0:0:0:0:0:0:0:0:0:0:0:0:95:0:0:0:10000:0|h|h"},
		[35] = {link = "|H1:item:133080:363:50:0:0:0:0:0:0:0:0:0:0:0:0:66:0:0:0:10000:0|h|h"},
		[36] = {link = "|H1:item:100564:363:50:0:0:0:0:0:0:0:0:0:0:0:0:7:0:0:0:10000:0|h|h"},
		[37] = {link = "|H1:item:86869:362:50:0:0:0:0:0:0:0:0:0:0:0:0:6:0:0:0:10000:0|h|h"},
		[38] = {link = "|H1:item:133232:363:50:0:0:0:0:0:0:0:0:0:0:0:0:65:0:0:0:10000:0|h|h"},
		[39] = {link = "|H1:item:98282:359:50:0:0:0:0:0:0:0:0:0:0:0:0:8:0:0:0:10000:0|h|h"},
		[40] = {link = "|H1:item:52547:312:50:0:0:0:0:0:0:0:0:0:0:0:0:113:1:0:0:10000:0|h|h"},
		[41] = {link = "|H1:item:69907:370:50:26582:370:50:0:0:0:0:0:0:0:0:1:29:1:1:0:1155:0|h|h"},
		[42] = {link = "|H1:item:106702:363:50:45884:370:50:33:0:0:0:0:0:0:0:2049:6:0:1:0:0:0|h|h"},
		[43] = {link = "|H1:item:106703:363:50:45884:370:50:31:0:0:0:0:0:0:0:2049:6:0:1:0:0:0|h|h"},
		[44] = {link = "|H1:item:106712:364:50:26848:370:50:3:0:0:0:0:0:0:0:2049:6:0:1:0:159:0|h|h"},
		[45] = {link = "|H1:item:71152:364:50:54484:370:50:4:0:0:0:0:0:0:0:2049:14:0:1:0:159:0|h|h"},
		[46] = {link = "|H1:item:71152:364:50:54484:370:50:4:0:0:0:0:0:0:0:2049:14:0:1:0:153:0|h|h"},
		[47] = {link = "|H1:item:59673:364:50:26582:370:50:0:0:0:0:0:0:0:0:1:67:0:1:0:6180:0|h|h"},
		[48] = {link = "|H1:item:59698:364:50:0:0:0:18:0:0:0:0:0:0:0:2049:67:0:1:0:7260:0|h|h"},
		[49] = {link = "|H1:item:69911:370:50:26582:370:50:0:0:0:0:0:0:0:0:1:29:1:1:0:6490:0|h|h"},
		[50] = {link = "|H1:item:69910:370:50:26582:370:50:0:0:0:0:0:0:0:0:1:29:1:1:0:8350:0|h|h"},
		[51] = {link = "|H1:item:69912:370:50:26582:370:50:0:0:0:0:0:0:0:0:1:1:1:1:0:2870:0|h|h"},
		[52] = {link = "|H1:item:69913:370:50:26582:370:50:0:0:0:0:0:0:0:0:1:29:1:1:0:7340:0|h|h"},
	}

	if (previewMode ~= 1) then
		math.randomseed(GetFrameTimeMilliseconds()) -- seed the random generator
	-- preview loot items --------------------------------------------------------------------------------------------------------------------------
		local function Pop_Loot()
			local pItemPer = math.random(1,4)
			for i = 1, pItemPer do
				local pQuantity = math.random(1,10)
				local pIndex = math.random(1,#previewTable)
				if pIndex >= 27 then pQuantity = 1 end
				self:OnLootReceived('player', previewTable[pIndex].link, pQuantity, nil, LOOT_TYPE_ITEM, true, nil, nil,  GetItemLinkItemId(previewTable[pIndex].link), nil, "preview")
			end
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview gold --------------------------------------------------------------------------------------------------------------------------------
		local function Pop_Gold()
			local aGold = math.random(-10000,10000)
			local previous = self._preview_gold
			local current = self._preview_gold + aGold
			self._preview_gold = current
			self:OnMoneyUpdated( current, previous )
			self._preview_gold = self._preview_gold + aGold
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview xp ----------------------------------------------------------------------------------------------------------------------------------
		local function Pop_XP()
			local tLevel = 0
			local tChamp = 0
			local xpForLevelUp = 0
			if (not IsUnitChampion('player')) then
				tChamp = 0
				if (self._preview_level == 0) then
					tLevel = math.random(10,40)
					self._preview_level = tLevel
				else
					tLevel = self._preview_level
				end
				xpForLevelUp = GetNumExperiencePointsInLevel(tLevel)
			else
				tLevel = 50
				if (self._preview_level == 0) then
					tChamp = math.random(10,3000)
					self._preview_level = tChamp
				else
					tChamp = self._preview_level
				end
				xpForLevelUp = GetNumChampionXPInChampionPoint(tChamp)
			end
			local previous = self._preview_XP
			local current = self._preview_XP + math.random(150,2000)
			if current > xpForLevelUp then
				current = 1
				self._preview_level = self._preview_level + 1
			end
			self._preview_XP = current
			self:OnXPUpdated( _, tLevel, previous, current, tChamp )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview AP ----------------------------------------------------------------------------------------------------------------------------------
		local function Pop_AP()
			local apGain = math.random(100,2000)
			self:OnAPUpdate( nil, nil, apGain, nil, nil, nil, "preview")
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview VP ----------------------------------------------------------------------------------------------------------------------------------
		local function Pop_VP()
      local _, _, progress = GetInfoForRewardTrack(REWARD_TRACK_TYPE_AVA_VETERANCY, GetReferenceTrackIndex(REWARD_TRACK_TYPE_AVA_VETERANCY, GetActiveReferenceTrackIdsForRewardTrackType(REWARD_TRACK_TYPE_AVA_VETERANCY)))
			local vpGain =  progress + math.random(1,2000)
			self:OnVPUpdate( REWARD_TRACK_TYPE_AVA_VETERANCY, nil, nil, nil, vpGain, "preview")
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview telvar ------------------------------------------------------------------------------------------------------------------------------
		local function Pop_Telvar()
			local oldTV = self._preview_telvar
			local newTV = self._preview_telvar + math.random(100,200)
			self._preview_telvar = newTV
			self:OnTVUpdate( newTV, oldTV )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview writ vouchers -----------------------------------------------------------------------------------------------------------------------
		local function Pop_WritVouch()
			local oldWV = self._preview_voucher
			local newWV = self._preview_voucher + math.random(5,150)
			self._preview_voucher = newWV
			self:OnWVoucherUpdate( newWV, oldWV )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview writ undaunted ----------------------------------------------------------------------------------------------------------------------
		local function Pop_Undaunted()
			local oldU = self._preview_undaunted
			local newU = self._preview_undaunted + math.random(1,3)
			self._preview_undaunted = newU
			self:OnUndauntedUpdate( newU, oldU )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview transmute ---------------------------------------------------------------------------------------------------------------------------
		local function Pop_Transmute()
			local oldTC = self._preview_transmute
			local newTC = self._preview_transmute + math.random(1,50)
			self._preview_transmute = newTC
			self:OnTransmuteUpdate( newTC, oldTC )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview event tickets -----------------------------------------------------------------------------------------------------------------------
		local function Pop_ETickets()
			local oldET = self._preview_eticket
			local newET = self._preview_eticket + math.random(1,3)
			self._preview_eticket = newET
			self:OnETicketUpdate( newET, oldET )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview endeavor ----------------------------------------------------------------------------------------------------------------------------
		local function Pop_Endeavors()
			local oldSE = self._preview_endeavor
			local newSE = self._preview_endeavor + math.random(10,200)
			self._preview_endeavor = newSE
			self:OnEndeavorUpdate( newSE, oldSE )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview archival ----------------------------------------------------------------------------------------------------------------------------
		local function Pop_Endless()
			local oldFA = self._preview_endless
			local newFA = self._preview_endless + math.random(10,200)
			self._preview_endless = newFA
			self:OnEndlessUpdate( newFA, oldFA )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview fragments ----------------------------------------------------------------------------------------------------------------------------
		local function Pop_Fragments()
			local oldFA = self._preview_fragments
			local newFA = self._preview_fragments + math.random(10,200)
			self._preview_fragments = newFA
			self:OnFragmentUpdate( newFA, oldFA )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview tome points ----------------------------------------------------------------------------------------------------------------------------
		local function Pop_TomePoints()
			local oldFA = self._preview_TomePoints
			local newFA = self._preview_TomePoints + math.random(10,200)
			self._preview_TomePoints = newFA
			self:OnTomePointsUpdate( newFA, oldFA )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview tome points caches----------------------------------------------------------------------------------------------------------------------------
		local function Pop_TomePointCaches()
			local oldFA = self._preview_TomePointCaches
			local newFA = self._preview_TomePointCaches + math.random(10,200)
			self._preview_TomePointCaches = newFA
			self:OnTomePointCachesUpdate( newFA, oldFA )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview tome tokens----------------------------------------------------------------------------------------------------------------------------
		local function Pop_TomeTokens()
			local oldFA = self._preview_TomeTokens
			local newFA = self._preview_TomeTokens + math.random(10,200)
			self._preview_TomeTokens = newFA
			self:OnTomeTokensUpdate( newFA, oldFA )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview trade bars----------------------------------------------------------------------------------------------------------------------------
		local function Pop_TradeBars()
			local oldFA = self._preview_TradeBars
			local newFA = self._preview_TradeBars + math.random(10,200)
			self._preview_TradeBars = newFA
			self:OnTradeBarsUpdate( newFA, oldFA )
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview companion xp ------------------------------------------------------------------------------------------------------------------------
		local function Pop_CompXP()
			local tLevel = 0
			local xpForLevelUp = 500000 -- fake values just to make things easier

			if (self._preview_clevel == 0) then
				tLevel = math.random(1,20)
				self._preview_clevel = tLevel
			else
				tLevel = self._preview_clevel
			end

			local previous = self._preview_cXP
			local current = self._preview_cXP + math.random(100,400)
			if current > xpForLevelUp then
				current = 1
				self._preview_clevel = self._preview_clevel + 1
			end
			self._preview_cXP = current

			self:CompanionXPUpdate(xpForLevelUp, tLevel, previous, current, nil, "preview")
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview rapport -----------------------------------------------------------------------------------------------------------------------------
		local function Pop_Rapport()
			local pRppt = self._preview_rapport
			local cRppt = pRppt + math.random(-100,100)
			self._preview_rapport = cRppt
			self:CompanionRapportUpdate(companionId, pRppt, cRppt, nil, "preview")
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview skills ------------------------------------------------------------------------------------------------------------------------------
		local function Pop_Skills()
			local craftTable = {
				[1] = {sT = CRAFTING_TYPE_ALCHEMY},			-- Alchemy
				[2] = {sT = CRAFTING_TYPE_BLACKSMITHING},	-- Blacksmithing
				[3] = {sT = CRAFTING_TYPE_CLOTHIER},		-- Clothing
				[4] = {sT = CRAFTING_TYPE_ENCHANTING},		-- Enchanting
				[5] = {sT = CRAFTING_TYPE_JEWELRYCRAFTING},	-- Jewelry Crafting
				[6] = {sT = CRAFTING_TYPE_PROVISIONING},	-- Provisioning
				[7] = {sT = CRAFTING_TYPE_WOODWORKING},		-- Woodworking
			}
			local tIndex = math.random(1,6)

			local skillType
			local skillIndex
			local subType = 0
			local reason

			if tIndex == 1 then
				local sType = math.random(1,7)
				subType = craftTable[sType].sT
				skillIndex = sType
				skillType = SKILL_TYPE_TRADESKILL
				reason = PROGRESS_REASON_TRADESKILL
			elseif tIndex == 2 then
				local sType = math.random(1,6)
				skillIndex = sType
				skillType = SKILL_TYPE_GUILD
				reason = PROGRESS_REASON_GUILD_REP
				if sType == 3 then reason = PROGRESS_REASON_SKILL_BOOK end
			elseif tIndex == 3 then
				local sType = math.random(1,6)
				skillIndex = sType
				skillType = SKILL_TYPE_WEAPON
				reason = PROGRESS_REASON_OTHER
			elseif tIndex == 4 then
				local sType = math.random(1,3)
				skillIndex = sType
				skillType = SKILL_TYPE_ARMOR
				reason = PROGRESS_REASON_OTHER
			elseif tIndex == 5 then
				local sType = math.random(1,6)
				skillIndex = sType
				skillType = SKILL_TYPE_WORLD
				reason = PROGRESS_REASON_OTHER
				if sType == 2 then reason = PROGRESS_REASON_JUSTICE_SKILL_EVENT end
			elseif tIndex == 6 then
				local sType = math.random(1,3)
				skillIndex = sType
				skillType = SKILL_TYPE_AVA
				reason = PROGRESS_REASON_OTHER
			end

			self:OnSkillXPUpdated( nil,  skillType,  skillIndex,  reason,  nil,  nil,  nil, nil, "preview", subType)
			zo_callLater(function() self:LootPreview() end, 1000)
		end
	-- preview achievements ------------------------------------------------------------------------------------------------------------------------
		local function Pop_Achievements()
			local aTable = {
				[1] = 1604,
				[2] = 1523,
				[3] = 2153,
				[4] = 1653,
				[5] = 1120,
				[6] = 2833,
				[7] = 1965,
				[8] = 2164,
				[9] = 3028,
				[10] = 1640,
				[11] = 1688,
				[12] = 3847,
				[13] = 3722,
				[14] = 3637,
				[15] = 621,
				[16] = 1801,
			}
			local aType = math.random(0,1)
			local index = math.random(1,16)
			local id = aTable[index]
			local name = GetAchievementName(id)

			if aType == 0 then
				local points = GetAchievementRewardPoints(id)
				self:AchievementComplete(name, points, id, '')
			else
				self:AchievementUpdated(id, "preview")
			end
			zo_callLater(function() self:LootPreview() end, 1000)
		end

	-- [1] = L.SelectPreview,
	-- [2] = tostring(1)..": "..L.Loot,
	-- [3] = tostring(2)..": "..L.Gold,
	-- [4] = tostring(3)..": "..L.Experience,
	-- [5] = tostring(4)..": "..L.AlliancePoints,
	-- [6] = tostring(5)..": "..L.VeterancyPoints,
	-- [7] = tostring(6)..": "..L.TelvarStones,
	-- [8] = tostring(7)..": "..L.WritVouchers,
	-- [9] = tostring(8)..": "..L.UndauntedKeys,
	-- [10] = tostring(9)..": "..L.TransmuteCrystals,
	-- [11] = tostring(10)..": "..L.EventTickets,
	-- [12] = tostring(11)..": "..L.Endeavor,
	-- [13] = tostring(12)..": "..L.Endless,
	-- [14] = tostring(13)..": "..L.Fragment,
	-- [15] = tostring(14)..": "..L.TomePoints,
	-- [16] = tostring(15)..": "..L.TomePointCaches,
	-- [17] = tostring(16)..": "..L.TomeTokens,
	-- [18] = tostring(17)..": "..L.TradeBars,
	-- [19] = tostring(18)..": "..L.CompanionXP,
	-- [20] = tostring(19)..": "..L.CompanionRapport,
	-- [21] = tostring(20)..": "..L.SkillDisplay,
	-- [22] = tostring(21)..": "..L.Achievements,
	-- [23] = tostring(22)..": "..L.Everything,

	-- initialize different preview modes per-update and separate functions so multiple can be fired each pass
		if (previewMode == 2) then -- preview loot items
			Pop_Loot()
		elseif (previewMode == 3) then -- preview gold
			Pop_Gold()
		elseif (previewMode == 4) then -- preview xp
			Pop_XP()
		elseif (previewMode == 5) then -- preview AP
			Pop_AP()
		elseif (previewMode == 6) then -- preview VP
			Pop_VP()
		elseif (previewMode == 7) then -- preview telvar
			Pop_Telvar()
		elseif (previewMode == 8) then -- preview writ vouchers
			Pop_WritVouch()
		elseif (previewMode == 9) then -- preview undaunted
			Pop_Undaunted()
		elseif (previewMode == 10) then -- preview transmute
			Pop_Transmute()
		elseif (previewMode == 11) then -- preview event tickets
			Pop_ETickets()
		elseif (previewMode == 12) then -- preview endeavors
			Pop_Endeavors()
		elseif (previewMode == 13) then -- preview endless
			Pop_Endless()
		elseif (previewMode == 14) then -- preview fragments
			Pop_Fragments()
		elseif (previewMode == 15) then -- preview tome points
			Pop_TomePoints()
		elseif (previewMode == 16) then -- preview tome point caches
			Pop_TomePointCaches()
		elseif (previewMode == 17) then -- preview tome tokens
			Pop_TomeTokens()
		elseif (previewMode == 18) then -- preview trade bars
			Pop_TradeBars()
		elseif (previewMode == 19) then -- preview companion xp
			Pop_CompXP()
		elseif (previewMode == 20) then -- preview rapport
			Pop_Rapport()
		elseif (previewMode == 21) then -- preview skills
			Pop_Skills()
		elseif (previewMode == 22) then -- preview achievements
			Pop_Achievements()
		elseif (previewMode == 23) then -- preview everything

			local popType = math.random(3,17) -- skipping normal loot here for clarity, set 3 to 2 to re-enable

			if (popType == 2) then -- preview loot items
				Pop_Loot()
			elseif (popType == 3) then -- preview gold
				Pop_Gold()
			elseif (popType == 4) then -- preview xp
				Pop_XP()
			elseif (popType == 5) then -- preview AP
				Pop_AP()
			elseif (popType == 6) then -- preview VP
				Pop_VP()
			elseif (popType == 7) then -- preview telvar
				Pop_Telvar()
			elseif (popType == 8) then -- preview writ vouchers
				Pop_WritVouch()
			elseif (popType == 9) then -- preview undaunted
				Pop_Undaunted()
			elseif (popType == 10) then -- preview transmute
				Pop_Transmute()
			elseif (popType == 11) then -- preview event tickets
				Pop_ETickets()
			elseif (popType == 12) then -- preview endeavors
				Pop_Endeavors()
			elseif (popType == 13) then -- preview endless
				Pop_Endless()
			elseif (popType == 14) then -- preview fragments
				Pop_Fragments()
			elseif (popType == 15) then -- preview tome points
				Pop_TomePoints()
			elseif (popType == 16) then -- preview tome point caches
				Pop_TomePointCaches()
			elseif (popType == 17) then -- preview tome tokens
				Pop_TomeTokens()
			elseif (popType == 18) then -- preview trade bars
				Pop_TradeBars()
			elseif (popType == 19) then -- preview companion xp
				Pop_CompXP()
			elseif (popType == 20) then -- preview rapport
				Pop_Rapport()
			elseif (popType == 21) then -- preview skills
				Pop_Skills()
			elseif (popType == 22) then -- preview achievements
				Pop_Achievements()
			end
		else
			previewMode = 1
			self:ResetPreview()
		end
	else
		self:ResetPreview()
	end
end
