local _
-- FIXED OR ADDED LINES MARKED WITH @sinnereso for patches!
if MD == nil then
	MD = {}
end

MD.name = "MassDeconstructor"
MD.version = "7.3"

MD.settings			=	{}
-- MD.settingsAccount	= 	{}

MD.defaults = {
	useAccountWide = true,
	RefineFullStack = false,
	DeconstructPrice = 0,--<<@sinnereso
	DeconstructBanked = false,--<<@sinnereso
	DeconstructBopTradeable = false,--<<@sinnereso
	DeconstructRetraited = false,
	DeconstructReconstructed = false,
	DeconstructResearchable = false,
	DeconstructBound = false,
	DeconstructSetPiece = false,
	DeconstructCrafted = false,
	LegacyDeconstructAll = false,
	LegacyDeconstructIntricate = false,
	LegacyDeconstructOrnate = false,
	LegacyDeconstructNirn = false,
	MeticulousDisassemblyWarning = false,
	Debug = false,
	Verbose = false,
	quality = {
		[CRAFTING_TYPE_ENCHANTING] = 4,
		[CRAFTING_TYPE_BLACKSMITHING] = 4,
		[CRAFTING_TYPE_CLOTHIER] = 4,
		[CRAFTING_TYPE_WOODWORKING] = 4,
		[CRAFTING_TYPE_JEWELRYCRAFTING] = 4
	},
	deconTraits = {
		[CRAFTING_TYPE_BLACKSMITHING] = {
			Deconstruct = true,
			[ITEM_TRAIT_TYPE_CATEGORY_WEAPON] = {
				[ITEM_TRAIT_TYPE_WEAPON_CHARGED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = false,
				[ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = false,
				[ITEM_TRAIT_TYPE_WEAPON_INFUSED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_POWERED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_PRECISE] = false,
				[ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = false,
				[ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = false,
				[ITEM_TRAIT_TYPE_WEAPON_ORNATE] = false
			},
			[ITEM_TRAIT_TYPE_CATEGORY_ARMOR] = {
				[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = false,
				[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = false,
				[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = false,
				[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_STURDY] = false,
				[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = false,
				[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = false,
				[ITEM_TRAIT_TYPE_ARMOR_ORNATE] = false
			}
		},
		[CRAFTING_TYPE_CLOTHIER] = {
			Deconstruct = true,
			[ITEM_TRAIT_TYPE_CATEGORY_ARMOR] = {
				[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = false,
				[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = false,
				[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = false,
				[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_STURDY] = false,
				[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = false,
				[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = false,
				[ITEM_TRAIT_TYPE_ARMOR_ORNATE] = false
			}
		},
		[CRAFTING_TYPE_WOODWORKING] = {
			Deconstruct = true,
			[ITEM_TRAIT_TYPE_CATEGORY_WEAPON] = {
				[ITEM_TRAIT_TYPE_WEAPON_CHARGED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = false,
				[ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = false,
				[ITEM_TRAIT_TYPE_WEAPON_INFUSED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_POWERED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_PRECISE] = false,
				[ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = false,
				[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = false,
				[ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = false,
				[ITEM_TRAIT_TYPE_WEAPON_ORNATE] = false
			},
			[ITEM_TRAIT_TYPE_CATEGORY_ARMOR] = {
				[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = false,
				[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = false,
				[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = false,
				[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_STURDY] = false,
				[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = false,
				[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = false,
				[ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = false,
				[ITEM_TRAIT_TYPE_ARMOR_ORNATE] = false
			}
		},
		[CRAFTING_TYPE_JEWELRYCRAFTING] = {
			Deconstruct = true,
			[ITEM_TRAIT_TYPE_CATEGORY_JEWELRY] = {
				[ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_INTRICATE] = false,
				[ITEM_TRAIT_TYPE_JEWELRY_ORNATE] = false
			}
		},
		[CRAFTING_TYPE_ENCHANTING] = {
			Deconstruct = true
		}
	}
}

MD.Inventory = {
	items = {},
	clothier = {},
	blacksmith = {},
	enchanter = {},
	woodworker = {}
}

-- PostHook on this function to re-output display of items to deconstruct when the user toggles the checkbox
-- function ZO_SmithingExtraction:OnFilterChanged()
    -- ZO_SharedSmithingExtraction.OnFilterChanged(self)

    -- local filterType = self:GetFilterType()
    -- if filterType then
        -- self.extractionSlot:SetEmptyTexture(ZO_CraftingUtils_GetItemSlotTextureFromSmithingFilter(filterType))
    -- end
    -- local deconstructionType = self:GetDeconstructionType()
    -- if deconstructionType then
        -- self.extractionSlot:SetMultipleItemsTexture(ZO_CraftingUtils_GetMultipleItemsTextureFromSmithingDeconstructionType(deconstructionType))
    -- end

	-- if not self:IsInRefineMode() then
		-- local includeBankedItemsChecked = ZO_CheckButton_IsChecked(self.includeBankedItemsCheckbox)
		-- if self.savedVars.includeBankedItemsChecked ~= includeBankedItemsChecked then
			-- self.savedVars.includeBankedItemsChecked = includeBankedItemsChecked
			-- self.inventory:PerformFullRefresh()
		-- end
	-- end
-- end

local canDeconJewellery = false

local function GetSmithingObject()

	if IsInGamepadPreferredMode() then
		if MD.isUniversal then
			return UNIVERSAL_DECONSTRUCTION_GAMEPAD
		else
			return SMITHING_GAMEPAD
		end
	else
		if MD.isUniversal then
			return UNIVERSAL_DECONSTRUCTION
		else
			return SMITHING
		end
	end
end

local function GetIncludeBankedItems()
	-- Instead of using
	-- ``` local includeBankedItemsChecked = GetSmithingObject().deconstructionPanel.includeBankedItemsCheckbox ```
	-- to retrieve the checkbox and then
	-- ```return ZO_CheckButton_IsChecked(includeBankedItemsCheckbox)```
	-- I'll just grab the savedVars.
	--
	-- This also makes it more compatible with Gamepad since SMITHING_GAMEPAD.deconstructionPanel doesn't have a checkbox we can use
	-- and only stores it as a filter in g_filters, which is inaccessible, and then saves it in SMITHING_GAMEPAD.deconstructionPanel.savedVars.

	MD.isBankIncluded = GetSmithingObject().deconstructionPanel.savedVars.includeBankedItemsChecked
	return MD.isBankIncluded
end

function MD.GetUseAccountWide()
	return MD.settings.useAccountWide
end

function MD.SetUseAccountWide(value)
	if MD.settings.useAccountWide == value then return end

	if value then
		MD.settings.useAccountWide = true
		MD.settings = ZO_SavedVars:NewAccountWide("MassDeconstructorSavedVars", 1.1, nil, MD.defaults, GetWorldName())
		MD.settings.useAccountWide = true
	else
		MD.settings.useAccountWide = false
		MD.settings = ZO_SavedVars:NewCharacterIdSettings("MassDeconstructorSavedVars", 1.1, nil, MD.defaults)
		MD.settings.useAccountWide = false
	end

	MD.settings.useAccountWide = value
end

local function DebugMessage(message)
	if MD.settings.Debug then
		d(message)
	end
end

ZO_Dialogs_RegisterCustomDialog("CONFIRM_MASS_DECON_CP_SLOTTED",
{
    canQueue = true,
    gamepadInfo =
    {
        dialogType = GAMEPAD_DIALOGS.BASIC,
    },
    title =
    {
        text = SI_MASSDECON_CP_SLOTTED_WARNING,
    },
    mainText =
    {
        text = SI_MASSDECON_CP_SLOTTED_CONFIRM,
    },
    buttons =
    {
        -- Confirm Button
        {
            keybind = "DIALOG_PRIMARY",
            text = GetString(SI_DIALOG_CONFIRM),
            callback = function(value)
				if value.data.option == 1 then
					MD.StartDeconstruction()
				elseif value.data.option == 2 then
					MD.StartRefining()
				end
            end,
        },

        -- Cancel Button
        {
            keybind = "DIALOG_NEGATIVE",
            text = GetString(SI_DIALOG_CANCEL),
        },
    },
})


local function isDisassemblyCPSlotted()
	return GetNumPointsSpentOnChampionSkill(83) == 50--<<@sinnereso
end

function MD.toggleTraits(CraftSkillLine)
	local isTrue = 0
	local isFalse = 0
	for Category, Categories in pairs(MD.settings.deconTraits[CraftSkillLine]) do
		if type(Categories) == "table" then
			for i, t in pairs(MD.settings.deconTraits[CraftSkillLine][Category]) do 
				if not (i == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or i == ITEM_TRAIT_TYPE_WEAPON_ORNATE or
						i == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or i == ITEM_TRAIT_TYPE_ARMOR_ORNATE or 
						i == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or i == ITEM_TRAIT_TYPE_JEWELRY_ORNATE) then
					if t then
						isTrue = isTrue + 1
					else
						isFalse = isFalse + 1
					end
				end
			end
		end
	end
	
	local result = false
	if isTrue>isFalse then result = false else result = true end
	
	for Category, Categories in pairs(MD.settings.deconTraits[CraftSkillLine]) do
		if type(Categories) == "table" then	-- disregard anything else in the deconTraits settings table
			for i, t in pairs(MD.settings.deconTraits[CraftSkillLine][Category]) do 
				if not (i == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or i == ITEM_TRAIT_TYPE_WEAPON_ORNATE or
						i == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or i == ITEM_TRAIT_TYPE_ARMOR_ORNATE or 
						i == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or i == ITEM_TRAIT_TYPE_JEWELRY_ORNATE) then
					MD.settings.deconTraits[CraftSkillLine][Category][i] = result
				end
			end
		end
	end
end
							
local function IsItemProtected(bagId, slotId)
	if FCOIS and FCOIS.IsDeconstructionLocked(bagId, slotId, false) then
		return true
	end

	if IsItemPlayerLocked(bagId, slotId) then
		DebugMessage(" - Item is player locked")
		return true
	else
		DebugMessage(" - Item is not player locked")
	end

	if not MD.settings.DeconstructBanked and bagId ~= BAG_BACKPACK then--<<@sinnereso
		return true
	end
	
	if IsItemBoPAndTradeable(bagId, slotId) and not MD.settings.DeconstructBopTradeable then--<<@sinnereso
		return true
	end
	
	if TamrielTradeCentre and MD.settings.DeconstructPrice > 0 and not (IsItemBound(bagId, slotId) and IsItemBoPAndTradeable(bagId, slotId)) then--<<@sinnereso
		local itemLink = GetItemLink(bagId, slotId, LINK_STYLE_DEFAULT)
		local ItemPriceData = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
		if ItemPriceData and GetItemLinkSetInfo(itemLink, false) then
			local TTCPrice = ItemPriceData.Avg
			if TTCPrice > MD.settings.DeconstructPrice then
				return true
			end
		end
	end
	
	return false
end

local function IsMarkedForBreaking(bagId, slotId)
	if FCOIS and FCOIS.IsMarked then
		local isMarked, markedArray = FCOIS.IsMarked(bagId, slotId, {9}, nil)
		return isMarked
	end
	return false
end

local function IsItemBindable(bagId, slotIndex)
	local itemLink = GetItemLink(bagId, slotIndex)
	if itemLink then
		--Bound
		if (IsItemLinkBound(itemLink)) then
			--Item is already bound
			return 1
		else
			local bindType = GetItemLinkBindType(itemLink)
			if (bindType ~= BIND_TYPE_NONE and bindType ~= BIND_TYPE_UNSET) then
				--Item can still be bound
				return 2
			else
				--Item is already bound or got no bind type
				return 3
			end
		end
	else
		return 0
	end
end

local function IsSetPiece(itemLink)
	local hasSet, _, numBonuses, _, _ = GetItemLinkSetInfo(itemLink)
	return hasSet
end

local function GetCraftingTypeFromItemLink(itemLink)
	local itemType, specialisedItemType = GetItemLinkItemType(itemLink)	
	if itemType == ITEMTYPE_ARMOR then
		local armorType = GetItemLinkArmorType(itemLink)
		if armorType == ARMORTYPE_HEAVY then
			DebugMessage(" - Item is armour: heavy armour")
			return CRAFTING_TYPE_BLACKSMITHING, itemType, specialisedItemType
		elseif armorType == ARMORTYPE_LIGHT or armorType == ARMORTYPE_MEDIUM then
			DebugMessage(" - Item is armour: medium or light armour")
			return CRAFTING_TYPE_CLOTHIER, itemType, specialisedItemType
		elseif armorType == ARMORTYPE_NONE then
			DebugMessage(" - Item is armour: jewellery")
			return CRAFTING_TYPE_JEWELRYCRAFTING, itemType, specialisedItemType
		else
			DebugMessage(" - Item is armour: Unknown armour type " .. armorType)
		end
	elseif (itemType == ITEMTYPE_WEAPON) then
		local weaponType = GetItemLinkWeaponType(itemLink)
		if
			(weaponType == WEAPONTYPE_AXE) or (weaponType == WEAPONTYPE_DAGGER) or (weaponType == WEAPONTYPE_HAMMER) or
				(weaponType == WEAPONTYPE_SWORD) or
				(weaponType == WEAPONTYPE_TWO_HANDED_AXE) or
				(weaponType == WEAPONTYPE_TWO_HANDED_HAMMER) or
				(weaponType == WEAPONTYPE_TWO_HANDED_SWORD)
		 then
			DebugMessage(" - Item is a weapon: blacksmithing")
			return CRAFTING_TYPE_BLACKSMITHING, itemType, specialisedItemType
		elseif
			weaponType == WEAPONTYPE_BOW or weaponType == WEAPONTYPE_FIRE_STAFF or weaponType == WEAPONTYPE_FROST_STAFF or
				weaponType == WEAPONTYPE_LIGHTNING_STAFF or
				weaponType == WEAPONTYPE_HEALING_STAFF or
				weaponType == WEAPONTYPE_SHIELD
		 then
			DebugMessage(" - Item is a weapon: woodworking")
			return CRAFTING_TYPE_WOODWORKING, itemType, specialisedItemType
		end
	elseif itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
		DebugMessage(" - Item is a glyph")
		return CRAFTING_TYPE_ENCHANTING, itemType, specialisedItemType
	end
	DebugMessage(" - Item type " .. itemType .. " is unknown")
	return CRAFTING_TYPE_INVALID, itemType, specialisedItemType
end

local function isProtectedTrait(bagId, slotIndex, itemLink, CraftingSkillType)
	local traitInformation = GetItemTraitInformationFromItemLink(itemLink)
	local trait = GetItemLinkTraitType(itemLink)
	local traitCatagory = GetItemLinkTraitCategory(itemLink)

	-- DebugMessage(" - Crafting skill type: " .. CraftingSkillType .. ", Trait info: " .. traitInformation .. ", Trait: " .. trait .. ", Trait category: " .. traitCatagory)
	if trait == ITEM_TRAIT_TYPE_NONE and (MD.settings.DeconstructTraitless) then
		DebugMessage(" - Item has no trait")
		return false
	end
		
	if (traitInformation == ITEM_TRAIT_INFORMATION_INTRICATE) then
		if MD.settings.LegacyDeconstructAll and MD.settings.LegacyDeconstructIntricate then
			return false
		elseif MD.settings.LegacyDeconstructAll and not MD.settings.LegacyDeconstructIntricate then
			return true
		end
		if 
			CraftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_INTRICATE]) or 
			CraftingSkillType == CRAFTING_TYPE_CLOTHIER and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE]) or 
			CraftingSkillType == CRAFTING_TYPE_BLACKSMITHING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE]) or 
			CraftingSkillType == CRAFTING_TYPE_WOODWORKING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE])
		then
			DebugMessage(" - INTRICATE through GetItemTraitInformation")
			return true
		end
	elseif (traitInformation == ITEM_TRAIT_INFORMATION_ORNATE) then
		if MD.settings.LegacyDeconstructAll and MD.settings.LegacyDeconstructOrnate then
			return false
		elseif MD.settings.LegacyDeconstructAll and not MD.settings.LegacyDeconstructOrnate then
			return true
		end
		if 
			CraftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ORNATE]) or 
			CraftingSkillType == CRAFTING_TYPE_CLOTHIER and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE]) or 
			CraftingSkillType == CRAFTING_TYPE_BLACKSMITHING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE]) or 
			CraftingSkillType == CRAFTING_TYPE_WOODWORKING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE])
		then
			DebugMessage(" - ORNATE through GetItemTraitInformation")
			return true
		end
	elseif (traitInformation == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED) and (not MD.settings.DeconstructResearchable) then
		DebugMessage(" - CAN BE RESEARCHED through GetItemTraitInformation")
		return true
	elseif (traitInformation == ITEM_TRAIT_INFORMATION_RETRAITED) and (not MD.settings.DeconstructRetraited) then
		DebugMessage(" - RETRAITED through GetItemTraitInformation")
		return true
	elseif (traitInformation == ITEM_TRAIT_INFORMATION_RECONSTRUCTED) and (not MD.settings.DeconstructReconstructed) then
		DebugMessage(" - RECONSTRUCTED through GetItemTraitInformation")
		return true
	end
	
	-- I'm re-adding these, just in case
	if	(trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE) and (MD.settings.DeconstructTraitless) then
		DebugMessage(" - INTRICATE through GetItemLinkTraitType")
		if MD.settings.LegacyDeconstructAll and MD.settings.LegacyDeconstructIntricate then
			return false
		elseif MD.settings.LegacyDeconstructAll and not MD.settings.LegacyDeconstructIntricate then
			return true
		end
		if 
			CraftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_INTRICATE]) or 
			CraftingSkillType == CRAFTING_TYPE_CLOTHIER and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE]) or 
			CraftingSkillType == CRAFTING_TYPE_BLACKSMITHING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE]) or 
			CraftingSkillType == CRAFTING_TYPE_WOODWORKING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE])
		then
			return true
		end
	end
	
	if	(trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE or trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE or trait == ITEM_TRAIT_TYPE_JEWELRY_ORNATE) then
		DebugMessage(" - ORNATE through GetItemLinkTraitType")
		if MD.settings.LegacyDeconstructAll and LegacyDeconstructOrnate then
			return false
		elseif MD.settings.LegacyDeconstructAll and not LegacyDeconstructOrnate then
			return true
		end
		if 
			CraftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ORNATE]) or 
			CraftingSkillType == CRAFTING_TYPE_CLOTHIER and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE]) or 
			CraftingSkillType == CRAFTING_TYPE_BLACKSMITHING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE]) or 
			CraftingSkillType == CRAFTING_TYPE_WOODWORKING and (not MD.settings.deconTraits[CraftingSkillType][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE])
		then
			return true
		end
	end

	-- Check if the item can be researched, if it can then prevent adding to deconstruction queue
	if CanItemLinkBeTraitResearched(itemLink) and (not MD.settings.DeconstructResearchable) then
		DebugMessage(" - CAN BE RESEARCHED through CanItemLinkBeTraitResearched")
		return true
	end
		
	if IsItemReconstructed(bagId,slotIndex)	and (not MD.settings.DeconstructReconstructed) then
		DebugMessage(" - Item is reconstrcuted")
		return true
	end

	if (MD.settings.LegacyDeconstructAll) then
		if (trait ~= ITEM_TRAIT_TYPE_ARMOR_NIRNHONED or trait ~= ITEM_TRAIT_TYPE_WEAPON_NIRNHONED) then
			return false
		else
			if (trait == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED or trait == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED) and not (MD.settings.LegacyDeconstructNirn) then
				return true
			else
				return false
			end
		end
	end
	
	if not MD.settings.deconTraits[CraftingSkillType][traitCatagory][trait] then
		DebugMessage(" - Deconstcutions of trait [" .. trait .. "] disabled.")
		return true
	end

	return false
end

local function ShouldDeconstructItem(bagId, slotIndex)
	local itemLink = GetItemLink(bagId, slotIndex)
	
	-- Sanity check: if there's no item link... there's no processing.
	if itemLink == "" or itemLink == nil then
		return false
	end
	
	DebugMessage(itemLink .. " processing in ShouldDeconstructItem")
	
	local sIcon, iStack, iSellPrice, bMeetsUsageRequirement, isLocked, iEquipType, iItemStyle, quality, qualityOverride =
		GetItemInfo(bagId, slotIndex)
	
	if (qualityOverride == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE) then
		DebugMessage(" - Cannot deconstruct mythic items")
		return false
	end
	
	--[[
	Sanity check: don't even consider items that don't belong in the queue
	
	Moving this up so we can optimise how much stuff we don't need to run through. By moving this up, we can also lower
	the amount of output for items that don't need to be considered. We don't need to process armour type or protected
	status on a master writ or poison, for example. My reason for changing this is two-fold:
	1. Optimisation, so we're not unnecessarily calling functions we don't need to (we don't really need to care)
	2. Due to there being so many items that, with extra unnecessary output, you can't see all the items in the debug output
	]]--
	local CraftingSkillType, itemType, specialisedItemType = GetCraftingTypeFromItemLink(itemLink)
	if CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, CraftingSkillType) then
		DebugMessage(" - Can be deconstructed")
	else
		DebugMessage(" - Can NOT be deconstructed")
		return false
	end
	
	DebugMessage(" - Item type is " .. itemType .. " and specialised type is " .. specialisedItemType)

	if (CraftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING and not canDeconJewellery) then
		DebugMessage("You do not own the Summerset Chapter, cannot decon jewellery")
		return false
	end

	-- for new universal decon assistant
	if	(MD.isUniversal and
		(CraftingSkillType == CRAFTING_TYPE_BLACKSMITHING or
		CraftingSkillType == CRAFTING_TYPE_CLOTHIER or
		CraftingSkillType == CRAFTING_TYPE_WOODWORKING or
		(CraftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING) or
		CraftingSkillType == CRAFTING_TYPE_ENCHANTING))
	 then
		DebugMessage(" - Valid for deconstruction station")
	elseif
		((MD.isBlacksmithing and CraftingSkillType ~= CRAFTING_TYPE_BLACKSMITHING) or
			(MD.isClothing and CraftingSkillType ~= CRAFTING_TYPE_CLOTHIER) or
			(MD.isWoodworking and CraftingSkillType ~= CRAFTING_TYPE_WOODWORKING) or
			(MD.isJewelryCrafting and CraftingSkillType ~= CRAFTING_TYPE_JEWELRYCRAFTING) or
			(MD.isEnchanting and CraftingSkillType ~= CRAFTING_TYPE_ENCHANTING))
	 then
		DebugMessage(" - Invalid type for crafting station")
		return false
	end
	
	if IsItemProtected(bagId, slotIndex) then
		DebugMessage(" - Item is protected")
		return false
	end

	-- Marking an item for deconstruction using FCOIS voids all warranties
	if IsMarkedForBreaking(bagId, slotIndex) then
		DebugMessage(" - Item is doomed")
		return true
	end

	if CraftingSkillType == CRAFTING_TYPE_INVALID then
		DebugMessage(" - Invalid crafting type")
		return false
	end

	local boundType = IsItemBindable(bagId, slotIndex)
	if boundType == 1 and not MD.settings.DeconstructBound then
		DebugMessage(" - Item is bound")
		return false
	end

	if IsItemLinkCrafted(itemLink) and not MD.settings.DeconstructCrafted then
		DebugMessage(" - Item is crafted")
		return false
	end

	local isSetPc = IsSetPiece(itemLink)
	if isSetPc and not MD.settings.DeconstructSetPiece then
		DebugMessage(" - Item is part of a set")
		return false
	end

	-- enchantments don't have traits, so check to make sure we're not sending a call to isProtectedTrait unnecessarily
	if CraftingSkillType ~= CRAFTING_TYPE_ENCHANTING then
		if isProtectedTrait(bagId, slotIndex, itemLink, CraftingSkillType) then
			DebugMessage(" - Settings forbid this trait from being deconstructed")
			return false
		end
	end
	
	if CraftingSkillType == CRAFTING_TYPE_CLOTHIER then
		if not MD.isUniversal then
			if not MD.isClothing then
				return false
			end
		end
		if quality > MD.settings.quality[CRAFTING_TYPE_CLOTHIER] then
			return false
		end
		if not MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER].Deconstruct then
			return false
		end
	elseif CraftingSkillType == CRAFTING_TYPE_BLACKSMITHING then
		if not MD.isUniversal then
			if not MD.isBlacksmithing then
				return false
			end
		end
		if quality > MD.settings.quality[CRAFTING_TYPE_BLACKSMITHING] then
			return false
		end
		if not MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER].Deconstruct then
			return false
		end
	elseif CraftingSkillType == CRAFTING_TYPE_WOODWORKING then
		if not MD.isUniversal then
			if not MD.isWoodworking then
				return false
			end
		end
		if quality > MD.settings.quality[CRAFTING_TYPE_WOODWORKING] then
			return false
		end
		if not MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING].Deconstruct then
			return false
		end
	elseif CraftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING then
		if not MD.isUniversal then
			if not MD.isJewelryCrafting then
				return false
			end
		end
		if quality > MD.settings.quality[CRAFTING_TYPE_JEWELRYCRAFTING] then
			return false
		end
		if not MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING].Deconstruct then
			return false
		end
	elseif CraftingSkillType == CRAFTING_TYPE_ENCHANTING then
		if not MD.isUniversal then
			if not MD.isEnchanting then
				return false
			end
		end
		if quality > MD.settings.quality[CRAFTING_TYPE_ENCHANTING] then
			return false
		end
		if not MD.settings.deconTraits[CRAFTING_TYPE_ENCHANTING].Deconstruct then
			return false
		end
	end
	DebugMessage("Adding " .. itemLink)
	return true
end

local function AddItemsToDeconstructionQueue(bagId)
	DebugMessage("AddItemsToDeconstructionQueue " .. bagId)
	local bagSlots = GetBagSize(bagId)
	for slotIndex = 0, bagSlots do
		local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
		if ShouldDeconstructItem(bagId, slotIndex) then
			local x = {}
			x.bagId = bagId
			x.slotIndex = slotIndex
			x.itemLink = itemLink
			table.insert(MD.deconstructQueue, x)
		end
	end
	DebugMessage(GetString(SI_MASSDECON_CHAT_QUEUE_LEN) .. #MD.deconstructQueue)
end

local function ListItemsInQueue()
	local itemString = #MD.deconstructQueue == 1 and GetString(SI_MASSDECON_CHAT_LIST_ITEM) or GetString(SI_MASSDECON_CHAT_LIST_ITEMS)
	
	if #MD.deconstructQueue < 1 then
		d(GetString(SI_MASSDECON_CHAT_NO_ITEMS))
		return
	end
	
	d(string.format(itemString, #MD.deconstructQueue))
	for index, thing in ipairs(MD.deconstructQueue) do
		d(" - " .. thing.itemLink)
	end
end

local function BuildDeconstructionQueue()
	MD.deconstructQueue = {}

	AddItemsToDeconstructionQueue(BAG_BACKPACK)
	
	if GetIncludeBankedItems() then
		-- subscribers get extra bank space
		if IsESOPlusSubscriber() then
			AddItemsToDeconstructionQueue(BAG_SUBSCRIBER_BANK)
		end
		-- regular bank
		AddItemsToDeconstructionQueue(BAG_BANK)
	end
end

function MD.ContinueWork()
	DebugMessage(GetString(SI_MASSDECON_CHAT_QUEUE_LEN) .. #MD.deconstructQueue)

	local deconstructionPanel = GetDeconstructionPanel().deconstructionPanel
	
	if deconstructionPanel.extractionSlot:HasItems() then
		DebugMessage(GetString(SI_MASSDECON_CHAT_ITEM_IN_SLOT_ERR))
		EVENT_MANAGER:RegisterForEvent(MD.name, EVENT_CRAFT_COMPLETED, MD.ContinueWork)
		if not MD.settings.Debug then
			deconstructionPanel:ExtractSingle()
		end
	elseif #MD.deconstructQueue > 0 then
		local itemToDeconstruct = table.remove(MD.deconstructQueue)
		DebugMessage(GetString(SI_MASSDECON_CHAT_DECONSTRUCTING) .. itemToDeconstruct.itemLink)
		EVENT_MANAGER:RegisterForEvent(MD.name, EVENT_CRAFT_COMPLETED, MD.ContinueWork)
		if MD.isEnchanting then
			ENCHANTING:AddItemToCraft(itemToDeconstruct.bagId, itemToDeconstruct.slotIndex)
			if not MD.settings.Debug then
				ENCHANTING:ExtractAll()
			end
		else
			GetSmithingObject():AddItemToCraft(itemToDeconstruct.bagId, itemToDeconstruct.slotIndex)
			if not MD.settings.Debug then
				deconstructionPanel:ExtractSingle()
			end
		end
	else
		DebugMessage(GetString(SI_MASSDECON_CHAT_DECON_FINISHED))
		EVENT_MANAGER:UnregisterForEvent(MD.name, EVENT_CRAFT_COMPLETED)
		KEYBIND_STRIP:AddKeybindButtonGroup(MD.KeybindStripDescriptor)
	end
end

function MD.StartDeconstruction()
	if MD.isEnchanting then
		if ENCHANTING.enchantingMode ~= ENCHANTING_MODE_EXTRACTION then
			DebugMessage(GetString(SI_MASSDECON_CHAT_EXTRACT_MODE))
			ZO_MenuBar_SelectDescriptor(ENCHANTING.modeBar, ENCHANTING_MODE_EXTRACTION)
		end
	else
		if GetSmithingObject().mode ~= SMITHING_MODE_DECONSTRUCTION then
			DebugMessage(GetString(SI_MASSDECON_CHAT_DECON_MODE))
			ZO_MenuBar_SelectDescriptor(GetSmithingObject().modeBar, SMITHING_MODE_DECONSTRUCTION)
		end
	end

	BuildDeconstructionQueue()

	-- : reset counter
	if #MD.deconstructQueue > 0 then
		PrepareDeconstructMessage()
		for index, itemToDeconstruct in ipairs(MD.deconstructQueue) do
			DebugMessage("AddItemToDeconstructMessage: " .. itemToDeconstruct.itemLink)
			AddItemToDeconstructMessage(
				itemToDeconstruct.bagId,
				itemToDeconstruct.slotIndex,
				itemToDeconstruct.quantity
			)
		end
		SendDeconstructMessage()
	end
end

function MD.DeconstructionKeypress()
	if MD.SceneCheck() then
		if MD.settings.MeticulousDisassemblyWarning and not isDisassemblyCPSlotted() then
			ZO_Dialogs_ShowDialog("CONFIRM_MASS_DECON_CP_SLOTTED", { option = 1 })
		else
			MD.StartDeconstruction()
		end
	end
end

function MD.DeconstructionButton()
	MD.DeconstructionKeypress()
end

local function ShouldRefineItem(bagId, slotIndex, itemLink)
	local itemType = GetItemLinkItemType(itemLink)
	local name = GetItemName(bagId, slotIndex)
	local backpackCount, bankCount, craftBagCount = GetItemLinkStacks(itemLink)
	local totalCount = backpackCount + bankCount + craftBagCount
	if
		(itemType == ITEMTYPE_RAW_MATERIAL or (MD.isBlacksmithing and itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL) or
			(MD.isClothing and itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL) or
			(MD.isWoodworking and itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL) or
			(MD.isJewelryCrafting and itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL) or
			(MD.isJewelryCrafting and itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER) or
			(MD.isJewelryCrafting and itemType == ITEMTYPE_JEWELRY_RAW_TRAIT) or
			(MD.isUniversal))
	 then
		if totalCount >= GetRequiredSmithingRefinementStackSize() then
			DebugMessage(
				zo_strformat("Refining <<2>> <<1>>? <<4>> is itemType <<3>>.", itemLink, totalCount, itemType, name)
			)
			return true
		end
	end
	return false
end

local function AddCraftingBagItemsToRefineQueue()
	local bagId = BAG_VIRTUAL
	DebugMessage(GetString(SI_MASSDECON_CHAT_CHECKING_CRAFT_BAG))
	local slotIndex = GetNextVirtualBagSlotId(nil)
	while slotIndex ~= nil do
		local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
		if ShouldRefineItem(bagId, slotIndex, itemLink) then
			local x = {}
			x.bagId = bagId
			x.slotIndex = slotIndex
			x.itemLink = itemLink
			table.insert(MD.refineQueue, x)
		end
		slotIndex = GetNextVirtualBagSlotId(slotIndex)
	end
	DebugMessage(GetString(SI_MASSDECON_CHAT_QUEUE_LEN) .. #MD.refineQueue)
end

local function AddItemsToRefineQueue(bagId)
	DebugMessage("AddItemsToRefineQueue " .. bagId)
	local bagSlots = GetBagSize(bagId)
	for slotIndex = 0, bagSlots do
		local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
		if ShouldRefineItem(bagId, slotIndex, itemLink) then
			local x = {}
			x.bagId = bagId
			x.slotIndex = slotIndex
			x.itemLink = itemLink
			table.insert(MD.refineQueue, x)
		end
	end
	DebugMessage(GetString(SI_MASSDECON_CHAT_QUEUE_LEN) .. #MD.refineQueue)
end

local function BuildRefiningQueue()
	MD.refineQueue = {}

	if HasCraftBagAccess() then
		AddCraftingBagItemsToRefineQueue()
	else
		DebugMessage(GetString(SI_MASSDECON_CHAT_NO_CRAFT_BAG))
	end
	AddItemsToRefineQueue(BAG_BACKPACK)
	
	if GetIncludeBankedItems() then
		-- subscribers get extra bank space
		if IsESOPlusSubscriber() then
			AddItemsToRefineQueue(BAG_SUBSCRIBER_BANK)
		end
		-- regular bank
		AddItemsToRefineQueue(BAG_BANK)
	end
end

local function StackBigEnoughToRefine()
	local stackSize = GetSmithingObject().refinementPanel.extractionSlot:GetStackCount()
	local refiningQuantity = GetRequiredSmithingRefinementStackSize()
	DebugMessage("Stack size: " .. stackSize .. ", Qty reqd: " .. refiningQuantity)
	return (stackSize >= refiningQuantity)
end

local function NeedsNewStack()
	if GetSmithingObject().refinementPanel:IsExtractable() then
		if StackBigEnoughToRefine() then
			-- Current stack is fine
			return false
		end
	end
	-- Need a new stack
	return true
end

local function CleanupAfterRefining()
	GetSmithingObject().refinementPanel:ClearSelections()
	KEYBIND_STRIP:AddKeybindButtonGroup(MD.KeybindStripDescriptor)
end

local function ProcessRefiningQueue()
	EVENT_MANAGER:UnregisterForEvent(MD.name, EVENT_CRAFT_COMPLETED)
	if NeedsNewStack() and #MD.refineQueue > 0 then
		DebugMessage(GetString(SI_MASSDECON_CHAT_ITEM_TO_EXTRACT))
		local itemToRefine = table.remove(MD.refineQueue)
		GetSmithingObject():AddItemToCraft(itemToRefine.bagId, itemToRefine.slotIndex)
	end
	if StackBigEnoughToRefine() then
		EVENT_MANAGER:RegisterForEvent(MD.name, EVENT_CRAFT_COMPLETED, ProcessRefiningQueue)
		if not MD.isDebug then
			if MD.settings.RefineFullStack then
				GetSmithingObject().refinementPanel:ExtractAll()
			else
				GetSmithingObject().refinementPanel:ExtractSingle()
			end
		end
	else
		DebugMessage(GetString(SI_MASSDECON_CHAT_NOTHING_LEFT_REFINE))
		CleanupAfterRefining()
	end
end

function MD.StartRefining()
	if MD.isEnchanting then
		return
	end
	if GetSmithingObject().mode ~= SMITHING_MODE_REFINMENT then
		DebugMessage(GetString(SI_MASSDECON_CHAT_REFINE_MODE))
		ZO_MenuBar_SelectDescriptor(GetSmithingObject().modeBar, SMITHING_MODE_REFINMENT)
		EVENT_MANAGER:RegisterForEvent(MD.name, EVENT_CRAFT_COMPLETED, ProcessRefiningQueue)
	end
	
	BuildRefiningQueue()
	if #MD.refineQueue > 0 then
		ProcessRefiningQueue()
	end
end

function MD.RefiningKeypress()
	if MD.SceneCheck() then
		if MD.settings.MeticulousDisassemblyWarning and not isDisassemblyCPSlotted() then
			ZO_Dialogs_ShowDialog("CONFIRM_MASS_DECON_CP_SLOTTED", { option = 2 })
		else
			MD.StartRefining()
		end
	end
end

function MD.RefiningButton()
	MD.RefiningKeypress()
end

local function processSlashCommands(option)
	local options = {}
	local searchResult = {string.match(option, "^(%S*)%s*(.-)$")}
	for i, v in pairs(searchResult) do
		if (v ~= nil and v ~= "") then
			options[i] = string.lower(v)
		end
	end

	if options[1] == "test" then
		MD.test()
	end
	
	if options[1] == "list" then
		ListItemsInQueue()
	end
	
	if options[1] == "debug" then
		if options[2] ~= "" then
			local args = {}
			local argResults = {string.match(options[2], "^(%S*)%s*(.-)$")}
			for i, v in pairs(argResults) do
				if (v ~= nil and v ~= "") then
					args[i] = tonumber(v)
				end
			end

			if args[1] ~= "" and args[2] ~= "" then
			
				local isDebug = MD.settings.Debug
				MD.settings.Debug = true
				ShouldDeconstructItem(args[1], args[2])
				MD.settings.Debug = isDebug
			end
		end
	end
end

function MD.test()
end

function MD.OnCrafting(craftSkill, sameStation, craftMode)
	if GetCraftingInteractionMode() == CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION then
		MD.isUniversal = true
	elseif sameStation == CRAFTING_TYPE_CLOTHIER then
		MD.isClothing = true
	elseif sameStation == CRAFTING_TYPE_BLACKSMITHING then
		MD.isBlacksmithing = true
	elseif sameStation == CRAFTING_TYPE_WOODWORKING then
		MD.isWoodworking = true
	elseif sameStation == CRAFTING_TYPE_ENCHANTING then
		MD.isEnchanting = true
	elseif sameStation == CRAFTING_TYPE_JEWELRYCRAFTING then
		MD.isJewelryCrafting = true
	end

	if MD.settings.Debug then
		d(GetString(SI_MASSDECON_CHAT_STATION_TYPE))
		if MD.isUniversal then
			d("MD: " .. GetString(SI_MASSDECON_TYPE_UNIVERSAL))
		elseif MD.isClothing then
			d("MD: " .. GetString(SI_MASSDECON_TYPE_CLOTHING))
		elseif MD.isBlacksmithing then
			d("MD: " .. GetString(SI_MASSDECON_TYPE_BLACKSMITHING))
		elseif MD.isWoodworking then
			d("MD: " .. GetString(SI_MASSDECON_TYPE_WOODWORKING))
		elseif MD.isEnchanting then
			d("MD: " .. GetString(SI_MASSDECON_TYPE_ENCHANTING))
		elseif MD.isJewelryCrafting then
			d("MD: " .. GetString(SI_MASSDECON_TYPE_JEWELLERY))
		else
			d("MD unknown: " .. craftSkill .. ", " .. sameStation)
			return
		end
	end

	if 	MD.isUniversal or 
		MD.isBlacksmithing or 
		MD.isClothing or 
		MD.isWoodworking or 
		MD.isEnchanting or
		MD.isJewelryCrafting
	then
		BuildDeconstructionQueue()
		
		if MD.settings.Verbose then
			ListItemsInQueue()
		end
	end

	KEYBIND_STRIP:AddKeybindButtonGroup(MD.KeybindStripDescriptor)
	KEYBIND_STRIP:UpdateKeybindButtonGroup(MD.KeybindStripDescriptor)
end

function MD.OnCraftEnd()
	MD.isBlacksmithing = false
	MD.isClothing = false
	MD.isWoodworking = false
	MD.isEnchanting = false
	MD.isJewelryCrafting = false
	MD.isUniversal = false
	if MD.settings.Debug then
		d("MD.OnCraftEnd")
	end
	KEYBIND_STRIP:RemoveKeybindButtonGroup(MD.KeybindStripDescriptor)
	EVENT_MANAGER:UnregisterForEvent(MD.name, EVENT_CRAFT_COMPLETED)
end

function MD.SceneCheck()	
	local sceneName = SCENE_MANAGER.currentScene.name
	DebugMessage("Scene name: " .. sceneName)
  if sceneName == 'enchanting' or sceneName == 'smithing' then--<<@sinnereso
	return true
  end
  if sceneName == 'universalDeconstructionSceneKeyboard' or sceneName == 'universalDeconstructionSceneGamepad' then
    return true
  end
  return false
end

function MD:RegisterEvents()
	EVENT_MANAGER:RegisterForEvent(MD.name, EVENT_CRAFTING_STATION_INTERACT, MD.OnCrafting)
	EVENT_MANAGER:RegisterForEvent(MD.name, EVENT_END_CRAFTING_STATION_INTERACT, MD.OnCraftEnd)
end

function MD.GetCanDeconJewellery()
	return canDeconJewellery
end
--
-- This function that will initialize our addon with ESO
--
function MD.Initialize(event, addon)
	if addon ~= MD.name then
		return
	end
	SLASH_COMMANDS["/md"] = processSlashCommands

	EVENT_MANAGER:UnregisterForEvent("MassDeconstructorInitialize", EVENT_ADD_ON_LOADED)
	MD:RegisterEvents()
	-- load our saved variables
	

	MD.settings = ZO_SavedVars:NewCharacterIdSettings("MassDeconstructorSavedVars", 1.1, nil, MD.defaults)
    if MD.settings.useAccountWide then
		MD.settings = ZO_SavedVars:NewAccountWide("MassDeconstructorSavedVars", 1.1, nil, MD.defaults, GetWorldName())
        MD.settings.useAccountWide = true
    end

	-- make a label for our keybinding
	ZO_CreateStringId("SI_BINDING_NAME_MD_DECONSTRUCTOR_DECON_ALL", GetString(SI_MASSDECON_DECON_ALL))
	ZO_CreateStringId("SI_BINDING_NAME_MD_DECONSTRUCTOR_REFINE_ALL", GetString(SI_MASSDECON_REFINE_ALL))

	canDeconJewellery = (IsCollectibleUnlocked(GetJewelrycraftingCollectibleId()) or IsESOPlusSubscriber())--<<@sinnereso
	
	local function QueueList()
		local isBankIncluded = MD.isBankIncluded
		
		if isBankIncluded ~= GetIncludeBankedItems() then
			BuildDeconstructionQueue()
			if MD.settings.Verbose then
				ListItemsInQueue()
			end
		end
	end
	
	SecurePostHook(UNIVERSAL_DECONSTRUCTION.deconstructionPanel, "OnFilterChanged", QueueList)
	SecurePostHook(UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel, "RefreshFilter", QueueList)
	SecurePostHook(SMITHING.deconstructionPanel, "OnFilterChanged", QueueList)
	SecurePostHook(SMITHING_GAMEPAD.deconstructionPanel, "SaveFilters", QueueList)


	-- make our options menu
	MD.MakeMenu()
	MD.KeybindStripDescriptor = {
		{
			name = GetString(SI_MASSDECON_DECON_ALL),
			keybind = "MD_DECONSTRUCTOR_DECON_ALL",
			callback = function()
				MD.DeconstructionButton()
			end,
			visible = function()
				return MD.isUniversal or MD.isClothing or MD.isBlacksmithing or MD.isWoodworking or MD.isEnchanting or
					MD.isJewelryCrafting
			end
		},
		{
			name = GetString(SI_MASSDECON_REFINE_ALL),
			keybind = "MD_DECONSTRUCTOR_REFINE_ALL",
			callback = function()
				MD.RefiningButton()
			end,
			visible = function()
				return (MD.isClothing or MD.isBlacksmithing or MD.isWoodworking or MD.isJewelryCrafting) and
					not MD.isUniversal
			end
		},
		alignment = KEYBIND_STRIP_ALIGN_CENTER
	}

	MD.totalDeconstruct = 0
	MD.currentList = {}
	MD.deconstructQueue = {}
	MD.refineQueue = {}
	MD.itemToDeconstruct = nil
	MD.isUniversal = false
	MD.isBlacksmithing = false
	MD.isClothing = false
	MD.isWoodworking = false
	MD.isEnchanting = false
	MD.isJewelryCrafting = false
	MD.isBankChecked = false
end

-- register our event handler function to be called to do initialization
EVENT_MANAGER:RegisterForEvent(
	MD.name,
	EVENT_ADD_ON_LOADED,
	function(...)
		MD.Initialize(...)
	end
)
