local WritPrice = {}
WritPrice.name = "WritPrice"
local LHAS = LibHarvensAddonSettings
local LCK = LibCharacterKnowledge
local LLC = LibLazyCrafting
local LALC = LibAlchemy

local DefaultVars = {
	ExtraInToolTip = true,
	ColorBelowNumber = true,
	ColorNumber = 700,
	ColorGood = "08f51e",
	ColorBad = "eb1a1a",
}

local function itemIdToLink(itemId)
	return "|H1:item:"..itemId..":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

local function SplitMasterWritLink(item_link,indexToGet)
	if indexToGet then -- can't put select in tonuber as it breaks
		local index = select(indexToGet,ZO_LinkHandler_ParseLink(item_link))
		return tonumber(index)
	end
  local ParsedLink = { ZO_LinkHandler_ParseLink(item_link) } 
  return {
	writ1 = tonumber(ParsedLink[10]), -- glyphId, writId, ProvisioningItemId, AlchemySolvent
	writ2 = tonumber(ParsedLink[11]), -- glyphLvl, AlchemyEffect1
	writ3 = tonumber(ParsedLink[12]), -- itemQuality, AlchemyEffect2
	--writ4 = tonumber(ParsedLink[13]), -- AlchemyEffect3
	writ5 = tonumber(ParsedLink[14]), -- traitItemIndex - smithing
	writ6 = tonumber(ParsedLink[15]), -- itemStyleId - smithing
  }
end


local function GetMatPriceFromLink(mat_link, ct)
	local mat={} 
	mat.price = TSCPriceDataAPI:GetPrice(mat_link) --LibPrice.ItemLinkToPriceGold(mat_link, "ttc") -- console libPrice is broken right now. this is for pc tests
	if not mat.price then
		mat.price = 0
		mat.link = mat_link
		mat.unknownPrice = true
	end
	if ct then
		mat.count = tonumber(ct)
	else
		mat.count = 1
	end
	mat.total = mat.price * mat.count
  return mat
end


local function GetTotalOfMatList(matList)
	local total, missing = 0, ""
	for _, mat in pairs(matList) do
		if mat.unknownPrice then
			if missing == "" then
				missing = mat.link
			else
				missing = missing..", "..mat.link
			end
		else
			total = total + mat.total
		end
	end
  return total, missing
end

local baseMatId={hvy=64489,mid=64504,lgt=64506,wood=64502,jwy=135146}

-- [number]		   		Id it has in master writ
-- craftingSkillType 	Golbal Crafting type used it know improvment mats
-- matId				ItemId of the matiral used to inital craft
-- matCount 			How much of that matiral is needed
-- motifPage			What Motif Chapter pasg it uses
local SmithingItemData = {
	[18] = {
		craftingSkillType = CRAFTING_TYPE_JEWELRYCRAFTING,
		matId = baseMatId.jwy,
		matCount = 15,
		motifPage = nil,
	},
	[24] = {
		craftingSkillType = CRAFTING_TYPE_JEWELRYCRAFTING,
		matId = baseMatId.jwy,
		matCount = 10,
		motifPage = nil,
	},
	[26] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_HELMETS,
	},
	[28] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 15,
		motifPage = ITEM_STYLE_CHAPTER_CHESTS,
	},
	[29] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_SHOULDERS,
	},
	[30] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_BELTS,
	},	
	[31] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 14,
		motifPage = ITEM_STYLE_CHAPTER_LEGS,
	},	
	[32] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_BOOTS,
	},
	[34] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_GLOVES,
	},
	[35] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.mid,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_HELMETS,
	},	
	[37] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.mid,
		matCount = 15,
		motifPage = ITEM_STYLE_CHAPTER_CHESTS,
	},
	[38] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.mid,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_SHOULDERS,
	},
	[39] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.mid,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_BELTS,
	},	
	[40] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.mid,
		matCount = 14,
		motifPage = ITEM_STYLE_CHAPTER_LEGS,
	},	
	[41] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.mid,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_BOOTS,
	},
	[43] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.mid,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_GLOVES,
	},
	[44] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_HELMETS,
	},
	[46] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 15,
		motifPage = ITEM_STYLE_CHAPTER_CHESTS,
	},
	[47] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_SHOULDERS,
	},
	[48] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_BELTS,
	},
	[49] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 14,
		motifPage = ITEM_STYLE_CHAPTER_LEGS,
	},
	[50] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_BOOTS,
	},
	[52] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 13,
		motifPage = ITEM_STYLE_CHAPTER_GLOVES,
	},	
	[53] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 11,
		motifPage = ITEM_STYLE_CHAPTER_AXES,
	},
	[56] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 11,
		motifPage = ITEM_STYLE_CHAPTER_MACES,
	},
	[59] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 11,
		motifPage = ITEM_STYLE_CHAPTER_SWORDS,
	},	
	[62] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 10,
		motifPage = ITEM_STYLE_CHAPTER_DAGGERS,
	},
	[65] = {
		craftingSkillType = CRAFTING_TYPE_WOODWORKING,
		matId = baseMatId.wood,
		matCount = 14,
		motifPage = ITEM_STYLE_CHAPTER_SHIELDS,
	},
	[67] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 14,
		motifPage = ITEM_STYLE_CHAPTER_SWORDS,
	},
	[68] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 14,
		motifPage = ITEM_STYLE_CHAPTER_AXES,
	},
	[69] = {
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING,
		matId = baseMatId.hvy,
		matCount = 14,
		motifPage = ITEM_STYLE_CHAPTER_MACES,
	},
	[70] = {
		craftingSkillType = CRAFTING_TYPE_WOODWORKING,
		matId = baseMatId.wood,
		matCount = 12,
		motifPage = ITEM_STYLE_CHAPTER_BOWS,
	},
	[71] = {
		craftingSkillType = CRAFTING_TYPE_WOODWORKING,
		matId = baseMatId.wood,
		matCount = 12,
		motifPage = ITEM_STYLE_CHAPTER_STAVES,
	},
	[72] = {
		craftingSkillType = CRAFTING_TYPE_WOODWORKING,
		matId = baseMatId.wood,
		matCount = 12,
		motifPage = ITEM_STYLE_CHAPTER_STAVES,
	},
	[73] = {
		craftingSkillType = CRAFTING_TYPE_WOODWORKING,
		matId = baseMatId.wood,
		matCount = 12,
		motifPage = ITEM_STYLE_CHAPTER_STAVES,
	},
	[74] = {
		craftingSkillType = CRAFTING_TYPE_WOODWORKING,
		matId = baseMatId.wood,
		matCount = 12,
		motifPage = ITEM_STYLE_CHAPTER_STAVES,
	},
	[75] = {
		craftingSkillType = CRAFTING_TYPE_CLOTHIER,
		matId = baseMatId.lgt,
		matCount = 15,
		motifPage = ITEM_STYLE_CHAPTER_CHESTS,
	},
}


local function GetSmithingMats(writLink)
	local fields = SplitMasterWritLink(writLink)
	local itemData = SmithingItemData[fields.writ1]
	local itemStyleId = fields.writ6

	-- List of materials needed to craft the writ,
	local materialList = {}
	-- Base material (Rubedite, Platinum, etc)
	table.insert(materialList, GetMatPriceFromLink(itemIdToLink(itemData.matId), itemData.matCount))
	-- Trait material (Malachite, Fortified Nirncrux, etc)
	table.insert(materialList, GetMatPriceFromLink(GetSmithingTraitItemLink(fields.writ5 + 1, LINK_STYLE_BRACKETS)))	
	
	-- Check if the Writ has a style, jewelry dosen't 		
	if 0 < itemStyleId then
		-- Using LibCharacterKnowledge to get motif data and to get the itemId for the motif, 
		local motifItemData = LCK.GetMotifItemsFromStyle(itemStyleId)
		local motifItemId = motifItemData.chapters[itemData.motifPage] or motifItemData.books[1]
		-- Style material (bone, nickel, malachite, etc)
		table.insert(materialList, GetMatPriceFromLink(GetItemStyleMaterialLink(itemStyleId, LINK_STYLE_BRACKETS)))
		-- Should it show motif cost in tooltip
		if SavedVars.ExtraInToolTip and LCK.GetMotifKnowledgeForCharacter(itemStyleId, itemData.motifPage) == LCK.KNOWLEDGE_UNKNOWN then
			local motif = GetMatPriceFromLink(LCK.GetItemLinkFromItemId(motifItemId, LINK_STYLE_BRACKETS))
			-- Only add if we know the price no need to display "Motif: 0"
			if not motif.unknownPrice then
				motif.text = "Motif"
				materialList.extra = motif
			end
		end
	end
	
	-- Add Improvement Mats to materialList
	local itemQuality = fields.writ3
	local itemSkillType=itemData.craftingSkillType
	if 2 <= itemQuality then
		table.insert(materialList, GetMatPriceFromLink(GetSmithingImprovementItemLink(itemSkillType, 1, LINK_STYLE_BRACKETS), 2))
	end
	if 3 <= itemQuality then
		table.insert(materialList, GetMatPriceFromLink(GetSmithingImprovementItemLink(itemSkillType, 2, LINK_STYLE_BRACKETS), 3))
	end
	if 4 <= itemQuality then
		table.insert(materialList, GetMatPriceFromLink(GetSmithingImprovementItemLink(itemSkillType, 3, LINK_STYLE_BRACKETS), 4))
	end
	if 5 == itemQuality then
		table.insert(materialList, GetMatPriceFromLink(GetSmithingImprovementItemLink(itemSkillType, 4, LINK_STYLE_BRACKETS), 8))
	end
	return materialList
end

local function GetAlchemyMats(writLink)
	-- use libAlchemy to get the itemId's for the writ
	local materialList = LALC:getBestCombinationMasterWrit(writLink)
	for i, mat in pairs(materialList) do
		materialList[i]=GetMatPriceFromLink(itemIdToLink(mat))
	end
	return materialList
end

local function GetProvisioningMats(writLink)
	local materialList = {}
	local itemLink = itemIdToLink(LCK.GetSourceItemIdFromResultItem(SplitMasterWritLink(writLink,10)))
	if SavedVars.ExtraInToolTip and LCK.GetItemKnowledgeForCharacter(itemLink) == LCK.KNOWLEDGE_UNKNOWN then 
		local recipe = GetMatPriceFromLink(itemLink)
		-- Only add if we know the price no need to display "Recipe: 0"
		if not recipe.unknownPrice then
			recipe.text = "Recipe"
			materialList.extra = recipe
		end
	end
	for ingredientIndex = 1, GetItemLinkRecipeNumIngredients(itemLink) do
		local _, _, ingredientAmount = GetItemLinkRecipeIngredientInfo(itemLink, ingredientIndex)
		local ingredientItemLink = GetItemLinkRecipeIngredientItemLink(itemLink, ingredientIndex, LINK_STYLE_BRACKETS)
		table.insert(materialList, GetMatPriceFromLink(ingredientItemLink, ingredientAmount * 2))
	end
	return materialList
end

local function GetEnchantingMats(writLink)
	local fields = SplitMasterWritLink(writLink)
	local glyphId = fields.writ1
	local glyphLvl = fields.writ2
	local itemQuality = fields.writ3
	local convert={-- takes level and quality to return the correct id for link
		[207]={[4]=305,[5]=306},
		[225]={[4]=369,[5]=364}
	}
	local link = "|H1:item:"..glyphId..":"..convert[glyphLvl][itemQuality]..":50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
	local materialList = LLC.getComponentRunesForGlyphItemLink(link)
	for i,rune in pairs(materialList) do
		materialList[i] = GetMatPriceFromLink(itemIdToLink(rune))
	end
	return materialList
end

local TEXTURE_TO_FUNCTION = {
	["/esoui/art/icons/master_writ_blacksmithing.dds"] = GetSmithingMats,
	["/esoui/art/icons/master_writ_clothier.dds"] = GetSmithingMats,
	["/esoui/art/icons/master_writ_woodworking.dds"] = GetSmithingMats,
	["/esoui/art/icons/master_writ_jewelry.dds"] = GetSmithingMats,
	["/esoui/art/icons/master_writ_alchemy.dds"] = GetAlchemyMats,
	["/esoui/art/icons/master_writ_enchanting.dds"] = GetEnchantingMats,
	["/esoui/art/icons/master_writ_provisioning.dds"] = GetProvisioningMats,
}

local function CombineAndFormatForGold(text, amount)
	return text..": "..ZO_CurrencyControl_FormatCurrency(math.floor(0.5 + amount), false).."g "
end

local function MaterialsTooltipText(materialList, buyCost, vouchers)
	
	local tableOfTextForTooltip ={}
	local totalCost = 0	
	-- gets and the material cost to the table for tooltip
	local materialCost, materialsUnknown = GetTotalOfMatList(materialList)	
	totalCost = totalCost + materialCost
	tableOfTextForTooltip.materialCost = CombineAndFormatForGold("Mats", materialCost)
	
	if materialList.extra then -- for missing Motif and recipes ( can do extra.link if needed )
		tableOfTextForTooltip.extraCost = CombineAndFormatForGold(materialList.extra.text, materialList.extra.total)
	end
	
	if buyCost then -- only show when its a master writ we have to buy
		totalCost = totalCost + buyCost
		tableOfTextForTooltip.buyCost = CombineAndFormatForGold("Buy", buyCost)
	end
	local goldToVoucher = totalCost / vouchers
	if SavedVars.ColorBelowNumber then
		if goldToVoucher < SavedVars.ColorNumber then
			goldToVoucher = "|c"..SavedVars.ColorGood..CombineAndFormatForGold("G : V", goldToVoucher).."|r"
		else
			goldToVoucher = "|c"..SavedVars.ColorBad..CombineAndFormatForGold("G : V", goldToVoucher).."|r"
		end
	end
	tableOfTextForTooltip.goldToVoucher = goldToVoucher
	
	if materialsUnknown ~= "" then -- show if there was a material with it's price missing
		tableOfTextForTooltip.materialsUnknown = "Price Missing: "..materialsUnknown
	end
	local output = ""
	local fieldsToAdd = {"goldToVoucher","materialCost","extraCost","buyCost","materialsUnknown"}
	for _,text in pairs(fieldsToAdd) do
		if tableOfTextForTooltip[text] then
			output = output..tableOfTextForTooltip[text].."\n"
		end
	end
	return output --table.concat(tableOfTextForTooltip, "\n")
	-- just incase this dosn't work
	-- table.insert(tableOfTextForTooltip, CombineAndFormatForGold("Mats", materialCost))
end

-- Pulls function based on icon on the master writ
-- check if a writ was hit, then call the funtion to retrieve the mats
local function GetMatsForWrit(item_link)
	local GetMats = TEXTURE_TO_FUNCTION[GetItemLinkInfo(item_link)]
	if not GetMats then return end
	return GetMats(item_link)
end

local function MakeTextForToolTip(control, item_link, cost, style)
	-- Ensure that we only try to run on master writs
	if ITEMTYPE_MASTER_WRIT ~= GetItemLinkItemType(item_link) then return end
	
	-- Get Info from writ and put matirals into table contains {price, count, link, unknownPrice, total}
	local matTable = TEXTURE_TO_FUNCTION[GetItemLinkInfo(item_link)]
	if matTable then matTable = matTable(item_link) end
	if matTable == nil then return nil end
	-- Workout how many Vouchers the Wreit Gives
	local VoucherNumber = SplitMasterWritLink(item_link,24)
	VoucherNumber = VoucherNumber / 10000 -- drop it to from 826400 to 82.64
	local minVoucher = math.floor(VoucherNumber) -- floor it down to 82
	local extraVoucher = VoucherNumber - minVoucher -- get the part that was cut off so .64
	local totalVoucher = minVoucher + math.floor(0.5 + extraVoucher) -- round the extra up if above .5 and add to total so 82 is now 83
	if totalVoucher == nil or totalVoucher <= 0 then return end -- ensure that there are vouchers and not negitive
	-- Create tooltip Text for the Writ
	local matText = MaterialsTooltipText(matTable, cost, totalVoucher)
	if not matText then return end
	--[[
	--making text smaller so it fits easyer'
	style.fontsize = 16 -- wrong atm but you get the idea
	]]
	control:AddLine(matText, style)
end


local function SetupToolTipHooks()
	-- Hook for trade house
	local rightGamepadTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
	ZO_PostHook(
	GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS ,
	"UpdateItemSelectedTooltip",
	function(self, itemData)
		if itemData then
			local section = rightGamepadTooltip:AcquireSection(rightGamepadTooltip:GetStyle("bodySection"))
			MakeTextForToolTip(section, itemData.itemLink, itemData.purchasePrice, rightGamepadTooltip:GetStyle("bodyDescription"))
			rightGamepadTooltip:AddSection(section)
		end
	end )
	-- hook for inventory
	local leftGamepadTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
	ZO_PostHook(
	leftGamepadTooltip,
	"LayoutMasterWritItem",
	function(self, itemLink)
		local section = self:AcquireSection(self:GetStyle("bodySection"))
		MakeTextForToolTip(section, itemLink, nil, self:GetStyle("bodyDescription"))
		self:AddSection(section)
	end )
end

local function SetupSettings()
 	local options = {
        allowDefaults = true, 
        allowRefresh = false, 
    }
    local settings = LHAS:AddAddon(WritPrice.name,options)
    if not settings then return end
	
	settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Extra in ToolTip", 
		tooltip = "Shows the price of missing Motif / Recipe in tooltip",
		default = DefaultVars.ExtraInToolTip, 
        setFunction = function(value)
           SavedVars.ExtraInToolTip = value
        end,
        getFunction = function()
            return SavedVars.ExtraInToolTip
        end,
    })
	settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Color G to V?", 
		tooltip = "Applys color to G to V so you know if good at a glance",
		default = DefaultVars.ColorBelowNumber, 
        setFunction = function(value)
           SavedVars.ColorBelowNumber = value
        end,
        getFunction = function()
            return SavedVars.ColorBelowNumber
        end,
    })
	 settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Below This is Good",
		tooltip = "Default: "..DefaultVars.ColorNumber,
		default = DefaultVars.ColorNumber, 
        setFunction = function(value)
           SavedVars.ColorNumber = value
        end,
        getFunction = function()
            return SavedVars.ColorNumber
        end,
        min = 100,
        max = 2000,
        step = 100
    })	
	settings:AddSetting({
		type = LHAS.ST_COLOR,
		label = "Good Color",
		tooltip = "Color that will show when below the amount above",
		setFunction = function(r, g, b, a)
			SavedVars.ColorGood = ZO_ColorDef:New(r, g, b, a):ToHex()
		end,
		default = {ZO_ColorDef.HexToFloats(DefaultVars.ColorGood)},
		getFunction = function()
			return ZO_ColorDef.HexToFloats(SavedVars.ColorGood or DefaultVars.ColorGood)
		end
	})
	settings:AddSetting({
		type = LHAS.ST_COLOR,
		label = "Bad Color",
		tooltip = "Color that will show when above the amount above",
		setFunction = function(r, g, b, a)
			SavedVars.ColorBad = ZO_ColorDef:New(r, g, b, a):ToHex()
		end,
		default = {ZO_ColorDef.HexToFloats(DefaultVars.ColorBad)},
		getFunction = function()
			return ZO_ColorDef.HexToFloats(SavedVars.ColorBad or DefaultVars.ColorBad)
		end
	})
	settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Submit Feedback / Request",
		tooltip = "link to a form where you can leave feedback or even leave a request",
		buttonText = "Open URL",
		clickHandler = function(control, button)
			RequestOpenUnsafeURL("https://docs.google.com/forms/d/e/1FAIpQLScYWtcIJmjn0ZUrjsvpB5rwA5AlsLvasHUIcKqzIYcogo9vjQ/viewform?usp=pp_url&entry.550722213="..WritPrice.name)
		end,
	})
end

local function OnAddOnLoaded(event, addonName)
	if addonName == WritPrice.name then
		EVENT_MANAGER:UnregisterForEvent(WritPrice.name, EVENT_ADD_ON_LOADED)
		local serverName = GetWorldName()
		SavedVars = ZO_SavedVars:NewAccountWide("WritPriceVars", 1, serverName, DefaultVars)
		-- for some reason it fails to set the color?
		if not SavedVars.ColorGood then SavedVars.ColorGood = DefaultVars.ColorGood end
		if not SavedVars.ColorBad then SavedVars.ColorBad = DefaultVars.ColorBad end
		SetupSettings()
		SetupToolTipHooks()
		
	end
end

EVENT_MANAGER:RegisterForEvent(WritPrice.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)