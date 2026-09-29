local sf = string.format
local zo_str = zo_strformat

local GAMEPAD_STYLE_1 = {
	fontSize = 32,
	fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
	fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1,
	fontStyle = "soft-shadow-thick",
	customSpacing = 15
	}
local GAMEPAD_STYLE_2 = {
	fontSize = 32,
	fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
	fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3,
	fontStyle = "soft-shadow-thick",
	customSpacing = 15
	}
local doneMessages = {}
local LCK = LibCharacterKnowledge

local function IsBlacksmithWeapon(weaponType)
	return weaponType == WEAPONTYPE_AXE
		or weaponType == WEAPONTYPE_HAMMER
		or weaponType == WEAPONTYPE_SWORD
		or weaponType == WEAPONTYPE_TWO_HANDED_AXE
		or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER
		or weaponType == WEAPONTYPE_TWO_HANDED_SWORD
		or weaponType == WEAPONTYPE_DAGGER
end

local function IsWoodworkingWeapon(weaponType)
	return weaponType == WEAPONTYPE_BOW
		or weaponType == WEAPONTYPE_FIRE_STAFF
		or weaponType == WEAPONTYPE_FROST_STAFF
		or weaponType == WEAPONTYPE_LIGHTNING_STAFF
		or weaponType == WEAPONTYPE_HEALING_STAFF
		or weaponType == WEAPONTYPE_SHIELD
end

local function GetShow_CraftingSkillType(character, craftingSkillType)
	if craftingSkillType == CRAFTING_TYPE_BLACKSMITHING then
		return character.show.bs
	elseif craftingSkillType == CRAFTING_TYPE_CLOTHIER then
		return character.show.cl
	elseif craftingSkillType == CRAFTING_TYPE_WOODWORKING then
		return character.show.ww
	elseif craftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING then
		return character.show.je
	end
	return false
end

local function DisplayItemLinkTooltip(control, itemLink, GamePadMode)
	local itemType = GetItemLinkItemType(itemLink)
	if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
		TraitBuddy.ui.motifs:DisplayTooltip(control, itemLink, GamePadMode)
		return
	end
	local showTooltip = TraitBuddy.settings.tooltip.show
	local traitType, traitText = GetItemLinkTraitInfo(itemLink)
	if TraitBuddy:IsResearchableTrait(traitType) then
		local craftingSkillType = TraitBuddy:LinkToCraftingSkillType(itemLink)
		local showSkillType = TraitBuddy:GetResearchShowName(craftingSkillType)
		local showSomeone = false
		for k,id in ipairs(TraitBuddy:GetCharacters(true)) do
			if TraitBuddy:GetCharacter(id).show[showSkillType] then
				showSomeone = true
				do break end
			end
		end
		if showSomeone then
			--I need 3 things, craftingSkillType, researchLineIndex and traitIndex
			local equipType = GetItemLinkEquipType(itemLink)
			local armorType = GetItemLinkArmorType(itemLink)
			local weaponType = GetItemLinkWeaponType(itemLink)
			local researchLineIndex = TraitBuddy:ItemToResearchLineIndex(itemType, armorType, weaponType, equipType)
			local traitIndex = TraitBuddy:FindTraitIndex(craftingSkillType, researchLineIndex, traitType)

			local kk, rr, dd = TraitBuddy:GetWhoKnows(craftingSkillType, researchLineIndex, traitIndex, true)
			if not GamePadMode and (showTooltip.title or showTooltip.youKnowSection or showTooltip.inventoryInsight or (#kk > 0 and TraitBuddy.settings.tooltip.show.knowSection) or (#rr > 0 and TraitBuddy.settings.tooltip.show.researchingSection) or (#dd > 0 and TraitBuddy.settings.tooltip.show.canResearchSection)) then
				control:AddVerticalPadding(5)
				ZO_Tooltip_AddDivider(control)
			end
			if showTooltip.title then
				local name, _, _, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
				TraitBuddy:BuildTooltipTitle(control, sf("%s - %s", name, GetString("SI_ITEMTRAITTYPE", traitType)), GamePadMode)
			end
			TraitBuddy:BuildTooltip(control, kk, rr, dd, GamePadMode)

			--Additional tooltip info for items
			local c = TraitBuddy:GetCharacter(TraitBuddy.characterId)
			if showTooltip.youKnowSection then
				if TraitBuddy:IsTraitKnown(c, craftingSkillType, researchLineIndex, traitIndex) then
					if GamePadMode then
						GAMEPAD_STYLE_1.fontColor = ZO_ColorDef:New(TraitBuddy.colours.you_know.r, TraitBuddy.colours.you_know.g, TraitBuddy.colours.you_know.b)
						control:AddLine(GetString(TB_YOU_KNOW), GAMEPAD_STYLE_1, control:GetStyle("bodySection"))
					else
						control:AddLine(GetString(TB_YOU_KNOW), "ZoFontHeader", TraitBuddy.colours.you_know.r, TraitBuddy.colours.you_know.g, TraitBuddy.colours.you_know.b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
					end
				elseif TraitBuddy:IsTraitBeingResearched(c, craftingSkillType, researchLineIndex, traitIndex) then
					if GamePadMode then
						GAMEPAD_STYLE_1.fontColor = ZO_ColorDef:New(TraitBuddy.colours.you_researching.r, TraitBuddy.colours.you_researching.g, TraitBuddy.colours.you_researching.b)
						control:AddLine(GetString(TB_YOU_ARE_RESEARCHING), GAMEPAD_STYLE_1, control:GetStyle("bodySection"))
					else
						control:AddLine(GetString(TB_YOU_ARE_RESEARCHING), "ZoFontHeader", TraitBuddy.colours.you_researching.r, TraitBuddy.colours.you_researching.g, TraitBuddy.colours.you_researching.b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
					end
				else
					if GamePadMode then
						GAMEPAD_STYLE_1.fontColor = ZO_ColorDef:New(TraitBuddy.colours.you_canResearch.r, TraitBuddy.colours.you_canResearch.g, TraitBuddy.colours.you_canResearch.b)
						control:AddLine(GetString(TB_YOU_COULD_RESEARCH), GAMEPAD_STYLE_1, control:GetStyle("bodySection"))
					else
						control:AddLine(GetString(TB_YOU_COULD_RESEARCH), "ZoFontHeader", TraitBuddy.colours.you_canResearch.r, TraitBuddy.colours.you_canResearch.g, TraitBuddy.colours.you_canResearch.b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
					end
				end
			end

			if showTooltip.inventoryInsight then
				TraitBuddy.ui.inventoryInsight:DisplayTooltip(control, GamePadMode, craftingSkillType, researchLineIndex, traitIndex)
			end
		end
	end
end

local function HookBagTooltip()
	--Inventory, Bank, Guild bank, Guild store sell
	if TraitBuddy.settings.tooltip.show.bag then
		--Non gamepad hook
		local BagItemTooltip = ItemTooltip.SetBagItem
		ItemTooltip.SetBagItem = function(control, bagId, slotIndex, ...)
			BagItemTooltip(control, bagId, slotIndex, ...)
			DisplayItemLinkTooltip(control, GetItemLink(bagId, slotIndex))
		end
		
		local GP_LEFT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
		local GP_LEFT_LayoutBagItem = GP_LEFT.LayoutBagItem
		GP_LEFT.LayoutBagItem = function(control, bagId, slotIndex, ...)
			local ret = GP_LEFT_LayoutBagItem(control, bagId, slotIndex, ...)
			DisplayItemLinkTooltip(control, GetItemLink(bagId, slotIndex), true)
			return ret
		end
		local GP_RIGHT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
		local GP_RIGHT_LayoutBagItem = GP_RIGHT.LayoutBagItem
		GP_RIGHT.LayoutBagItem = function(control, bagId, slotIndex, ...)
			local ret = GP_RIGHT_LayoutBagItem(control, bagId, slotIndex, ...)
			DisplayItemLinkTooltip(control, GetItemLink(bagId, slotIndex), true)
			return ret
		end
	end
end

local function HookLootTooltip()
	if TraitBuddy.settings.tooltip.show.loot then
		--Non gamepad hook
		local LootItemTooltip = ItemTooltip.SetLootItem
		ItemTooltip.SetLootItem = function(control, lootId, ...)
			LootItemTooltip(control, lootId, ...)
			DisplayItemLinkTooltip(control, GetLootItemLink(lootId))
		end
		--Gamepad hook
		local GP_RIGHT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
		local GP_LayoutItemWithStackCount = GP_RIGHT.LayoutItemWithStackCount
		GP_RIGHT.LayoutItemWithStackCount = function(control, itemLink, ...)
			local ret = GP_LayoutItemWithStackCount(control, itemLink, ...)
			if SCENE_MANAGER:IsShowing("lootGamepad") then
				DisplayItemLinkTooltip(control, itemLink, true)
			end
			return ret
		end
	end
end

local function HookMailTooltip()
	if TraitBuddy.settings.tooltip.show.mail then
		--Non gamepad hook
		local AttachedMailItemTooltip = ItemTooltip.SetAttachedMailItem
		ItemTooltip.SetAttachedMailItem = function(control, openMailId, attachmentIndex, ...)
			AttachedMailItemTooltip(control, openMailId, attachmentIndex, ...)
			DisplayItemLinkTooltip(control, GetAttachedItemLink(openMailId, attachmentIndex))
		end
		--Gamepad hook
		local GP_LEFT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
		local GP_LayoutGenericItem = GP_LEFT.LayoutGenericItem
		GP_LEFT.LayoutGenericItem = function(control, itemLink, ...)
			local ret = GP_LayoutGenericItem(control, itemLink, ...)
			if GAMEPAD_MAIL_INBOX_FRAGMENT:IsShowing() then
				DisplayItemLinkTooltip(control, itemLink, true)
			end
			return ret
		end
	end
end

local function HookBuybackTooltip()
	if TraitBuddy.settings.tooltip.show.buyback then
		--Non gamepad hook
		local BuybackItemTooltip = ItemTooltip.SetBuybackItem
		ItemTooltip.SetBuybackItem = function(control, index, ...)
			BuybackItemTooltip(control, index, ...)
			DisplayItemLinkTooltip(control, GetBuybackItemLink(index))
		end
		--Gamepad hook
		local GP_LEFT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
		local GP_LayoutBuyBackItem = GP_LEFT.LayoutBuyBackItem
		GP_LEFT.LayoutBuyBackItem = function(control, index, ...)
			GP_LayoutBuyBackItem(control, index, ...)
			DisplayItemLinkTooltip(control, GetBuybackItemLink(index), true)
		end
	end
end

local function HookTradeTooltip()
	if TraitBuddy.settings.tooltip.show.trade then
		--Non gamepad hook
		local TradeItemTooltip = ItemTooltip.SetTradeItem
		ItemTooltip.SetTradeItem = function(control, tradeWho, slotIndex, ...)
			TradeItemTooltip(control, tradeWho, slotIndex, ...)
			DisplayItemLinkTooltip(control, GetTradeItemLink(tradeWho, slotIndex))
		end
		--Gamepad hook
		local GP_LEFT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
		local GP_LEFT_LayoutTradeItem = GP_LEFT.LayoutTradeItem
		GP_LEFT.LayoutTradeItem = function(control, tradeWho, slotIndex, ...)
			local ret = GP_LEFT_LayoutTradeItem(control, tradeWho, slotIndex, ...)
			DisplayItemLinkTooltip(control, GetTradeItemLink(tradeWho, slotIndex), true)
			return ret
		end
		local GP_RIGHT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_QUAD3_TOOLTIP)
		local GP_RIGHT_LayoutTradeItem = GP_RIGHT.LayoutTradeItem
		GP_RIGHT.LayoutTradeItem = function(control, tradeWho, slotIndex, ...)
			local ret = GP_RIGHT_LayoutTradeItem(control, tradeWho, slotIndex, ...)
			DisplayItemLinkTooltip(control, GetTradeItemLink(tradeWho, slotIndex), true)
			return ret
		end
	end
end

local function HookTradingHouseTooltip()
	--Guild store search
	if TraitBuddy.settings.tooltip.show.tradingHouse then
		--Non gamepad hook
		local TradingHouseItemTooltip = ItemTooltip.SetTradingHouseItem
		ItemTooltip.SetTradingHouseItem = function(control, tradingHouseIndex, ...)
			TradingHouseItemTooltip(control, tradingHouseIndex, ...)
			DisplayItemLinkTooltip(control, GetTradingHouseSearchResultItemLink(tradingHouseIndex))
		end
	end
	--Guild store my listings
	if TraitBuddy.settings.tooltip.show.tradingHouse then
		local TradingHouseListingTooltip = ItemTooltip.SetTradingHouseListing
		ItemTooltip.SetTradingHouseListing = function(control, tradingHouseListingIndex, ...)
			TradingHouseListingTooltip(control, tradingHouseListingIndex, ...)
			DisplayItemLinkTooltip(control, GetTradingHouseListingItemLink(tradingHouseListingIndex))
		end
	end

	if TraitBuddy.settings.tooltip.show.tradingHouse or TraitBuddy.settings.tooltip.show.tradingHouse then
		--Gamepad hook
		local GP_LEFT = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
		local GP_LEFT_LayoutItemWithStackCountSimple = GP_LEFT.LayoutItemWithStackCountSimple
		GP_LEFT.LayoutItemWithStackCountSimple = function(control, itemLink, ...)
			local ret = GP_LEFT_LayoutItemWithStackCountSimple(control, itemLink, ...)
			DisplayItemLinkTooltip(control, itemLink, true)
			return ret
		end
	end
end

local function HookChatLinkTooltip()
	if TraitBuddy.settings.tooltip.show.chat then
		local ChatLinkTooltip = PopupTooltip.SetLink
		PopupTooltip.SetLink = function(control, link, ...)
			ChatLinkTooltip(control, link, ...)
			DisplayItemLinkTooltip(control, link, false)
		end
	end
end

local function HookQuestRewardTooltip()
	if TraitBuddy.settings.tooltip.show.quest then
		local QuestRewardTooltip = ItemTooltip.SetQuestReward
		ItemTooltip.SetQuestReward = function(control, rewardIndex, ...)
			QuestRewardTooltip(control, rewardIndex, ...)
			DisplayItemLinkTooltip(control, GetQuestRewardItemLink(rewardIndex))
		end
	end
end

local function HookCraftingTooltip()
	if TraitBuddy.settings.tooltip.show.crafting then
		--Non gamepad hook
		local ResultTooltip = ZO_SmithingTopLevelCreationPanelResultTooltip
		local PendingSmithingItemTooltip = ResultTooltip.SetPendingSmithingItem
		ResultTooltip.SetPendingSmithingItem = function(control, patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex, ...)
			PendingSmithingItemTooltip(control, patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex, ...)
			DisplayItemLinkTooltip(control, GetSmithingPatternResultLink(patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex))
		end
		--Gamepad hook
		local GP_ResultTooltip = ZO_GamepadSmithingTopLevelCreationResultTooltip.tip
		local GP_LayoutPendingSmithingItem = GP_ResultTooltip.LayoutPendingSmithingItem
		GP_ResultTooltip.LayoutPendingSmithingItem = function(control, patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex, ...)
			GP_LayoutPendingSmithingItem(control, patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex, ...)
			DisplayItemLinkTooltip(control, GetSmithingPatternResultLink(patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex), true)
		end
	end
end

local function HookWornItemsTooltip()
	if TraitBuddy.settings.tooltip.show.worn then
		local WornItemTooltip = ItemTooltip.SetWornItem
		ItemTooltip.SetWornItem = function(control, slotIndex, bagId)
			WornItemTooltip(control, slotIndex, bagId)
			if bagId == BAG_WORN then
				DisplayItemLinkTooltip(control, GetItemLink(bagId, slotIndex))
			end
		end
	end
end

--TraitBuddy Object code
local TB_Object = ZO_Object:Subclass()
function TB_Object:New(...)
	local object = ZO_Object.New(self)
	object:Initialize(...)
	return object
end

function TB_Object:Initialize()
	self.ADDON_NAME = "TraitBuddy"
	self.ADDON_VERSION = "9.6"
	self.settings = {}
	self.player_activated = false
	self.characterId = 0
	self.colours = {
		--Tooltip you know colours (bottom line)
		you_know = ZO_ColorDef:New(1, 0, 0),
		you_researching = ZO_ColorDef:New(0.25, 0.5, 1),
		you_canResearch = ZO_ColorDef:New(0, 1, 0)
	}
	self.soc = {}
	self.maxNumTraits = {
		[CRAFTING_TYPE_BLACKSMITHING] = 0,
		[CRAFTING_TYPE_CLOTHIER] = 0,
		[CRAFTING_TYPE_WOODWORKING] = 0,
		[CRAFTING_TYPE_JEWELRYCRAFTING] = 0
	}
end

function TB_Object:OnPlayerActivated()
	if self.player_activated then return end	--Only the first time
	self.player_activated = true
	EVENT_MANAGER:UnregisterForEvent(self.ADDON_NAME, EVENT_PLAYER_ACTIVATED)

	-- Initialize Data first, before creating the proxy
	TraitBuddy.Data = TB_Data:New()
	TraitBuddy.Data:Initialize()  -- Call Initialize immediately
	
	TraitBuddy.setData = TB_setData
	TraitBuddy.setData:Initialize()
	
	TraitBuddy.Libraries = TraitBuddy.Libraries or {}
	if TraitBuddy.Libraries.Initialize then
		TraitBuddy.Libraries:Initialize()
	end
	
	-- Create proxy AFTER Data is initialized
	local proxy = {}
	setmetatable(proxy, {
		__index = function(t, key)
			if TraitBuddy.setData[key] then
				return function(self, ...)
					return TraitBuddy.setData[key](TraitBuddy.setData, ...)
				end
			end
			if TraitBuddy.Data[key] then
				return function(self, ...)
					return TraitBuddy.Data[key](TraitBuddy.Data, ...)
				end
			end
			return nil
		end
	})
	TraitBuddy.data = proxy

	-- Create UI after data is ready
	TraitBuddy.ui = TB_UI:New(TB)
	
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_NON_COMBAT_BONUS_CHANGED, function(_, ...) self:OnNonCombatBonusChanged(...) end)

	self:StructureAndFix()
	self:CheckESOPlus()
	self:SortCharacters()
	self:CalcMaxNumTraits()
	self:UpdateResearch()
	self:UpdateResearching()
	self:UpdateMotifs()
	self.ui.research:UpdateUI()
	self.ui.updatelater:CheckCompletedEarlier()
	self.ui:SetWindowPosition(self.settings.x, self.settings.y)
	ZO_ToggleButton_SetState(TBLocked, not self.settings.locked)
	HookBagTooltip()
	HookLootTooltip()
	HookMailTooltip()
	HookBuybackTooltip()
	HookTradeTooltip()
	HookTradingHouseTooltip()
	HookChatLinkTooltip()
	HookQuestRewardTooltip()
	HookCraftingTooltip()
	HookWornItemsTooltip()
	
	self.ui:Create()
	self.ui.updatelater:Update()
	self.ui.settings:CreatePanel()

	zo_callLater(function() self.ui:Refresh() end, 10000)
	zo_callLater(function() self.ui:Refresh() end, 20000)
	zo_callLater(function() self.ui:Refresh() end, 30000)
end

function TB_Object:StructureAndFix()
	--Fix any data bugs or add new patch features on all characters. Also sets up structures for new characters
	--The research and motifs hash tables will have been created from DefaultSettings()

	--removed inventory settings v5.5
	self.settings.inventory.show.intricate = nil
	self.settings.inventory.colours.can = nil
	self.settings.inventory.size = nil
	self.settings.inventory.intricateTexture = nil
	self.settings.tooltip.show.itemStyle = nil --v5.8.1

	--added 8.4.1 removed 8.4.3
	self.settings.tooltip.show.wornCompanion = nil

	--New player or first time user
	if not self.settings.characters[self.characterId] then
		self.settings.characters[self.characterId] = {
			research = {},
			markForResearch = {},
			motifs = {},
			show = {
				bs = true,
				cl = true,
				ww = true,
				motif = true,
				je = true
			}
		}
	end
	--Any name changes
	for i = 1, GetNumCharacters() do
		local name, _, _, _, _, _, characterId = GetCharacterInfo(i)
		if self.settings.characters[characterId] then
			self.settings.characters[characterId].name = zo_str("<<1>>", name)
		end
	end

	self:TidyCharacters()

	local craftingSkillTypes = self:GetCraftingSkillTypes()
	for id,c in pairs(self.settings.characters) do
		c.markForResearch = c.markForResearch or {}
		if type(c.show) == "boolean" then --show changed v4.0
			local oldShow = c.show
			c.show = {
				bs = oldShow,
				cl = oldShow,
				ww = oldShow,
				motif = oldShow
			}
		end
		if c.show.je == nil then --added v5.9 Summerset
			c.show.je = true
		end
		for _,craftingSkillType in pairs(craftingSkillTypes) do
			c.research[craftingSkillType] = c.research[craftingSkillType] or {}
			c.research[craftingSkillType].MaxSimultaneousResearch = c.research[craftingSkillType].MaxSimultaneousResearch or 1
			c.markForResearch[craftingSkillType] = c.markForResearch[craftingSkillType] or {}
			for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
				c.research[craftingSkillType][researchLineIndex] = c.research[craftingSkillType][researchLineIndex] or {}
				c.markForResearch[craftingSkillType][researchLineIndex] = c.markForResearch[craftingSkillType][researchLineIndex] or {}
				local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
				c.research[craftingSkillType][researchLineIndex].Name = nil
				for traitIndex = 1, numTraits do
					c.research[craftingSkillType][researchLineIndex][traitIndex] = c.research[craftingSkillType][researchLineIndex][traitIndex] or false
					c.markForResearch[craftingSkillType][researchLineIndex][traitIndex] = (not c.research[craftingSkillType][researchLineIndex][traitIndex] and c.markForResearch[craftingSkillType][researchLineIndex][traitIndex]) or false
				end
			end
		end
		c.motifs = c.motifs or {}
		if c.motifs[38] == nil then --v4.2 Housing moved Draugr to 38
			c.motifs[38] = c.motifs[37]
		end
		if c.motifs[53.1] then --v7.4 Refabricated Motif correctly placed at 79
			c.motifs[79] = c.motifs[53.1]
			c.motifs[53.1] = nil
		end
		local numChapters = TraitBuddy.Data:GetNumChapters()
		for itemStyleIndex = 1, GetNumValidItemStyles() do
			local itemStyleId = GetValidItemStyleId(itemStyleIndex)
			if itemStyleId > 0 then
				local motif = TraitBuddy.data:GetMotifByItemStyleId(itemStyleId)
				if motif then
					local order = motif:Order()
					if motif:HasChapters() then
						c.motifs[order] = c.motifs[order] or {}
						for chapter = 1, numChapters do
							c.motifs[order][chapter] = c.motifs[order][chapter] or false
						end
					else
						if type(c.motifs[order]) == "table" then
							local temp = c.motifs[order][1] --changed grim harlequin v3.6
							c.motifs[order] = nil
							c.motifs[order] = temp
						end
						c.motifs[order] = c.motifs[order] or false
					end
				end
			end
		end
	end
end

function TB_Object:GetMotifKnowledgeForCharacter(characterId, itemStyleId, chapter)
	local motif = TraitBuddy.data:GetMotifByItemStyleId(itemStyleId)
	if not motif then
		return false
	end
	
	local hasChapters = motif:HasChapters()
	
	-- For the CURRENT character, we can use direct game API calls
	if characterId == self.characterId then
		if hasChapters then
			-- Chaptered motifs - use lore book tracking
			return motif:IsLoreBookChapterKnown(chapter)
		else
			-- Non-chaptered motifs (alliance motifs 1-9) - use smithing style
			-- This checks if you can CRAFT in this style, which means you learned it
			return IsSmithingStyleKnown(itemStyleId, 1)
		end
	end
	
	-- For OTHER characters, we MUST use LCK
	if not LCK then
		-- No LCK available - can't check other characters
		return false
	end
	
	local charIdStr = tostring(characterId)

	local chapterToCheck = ITEM_STYLE_CHAPTER_ALL
	if hasChapters then
		chapterToCheck = TraitBuddy.data:GetChapterConstant(chapter) or ITEM_STYLE_CHAPTER_ALL
	end

	local knowledge = LCK.GetMotifKnowledgeForCharacter(itemStyleId, chapterToCheck, nil, charIdStr)
	
	-- LCK returns one of these values:
	-- LCK.KNOWLEDGE_KNOWN = 1 (known)
	-- LCK.KNOWLEDGE_UNKNOWN = 2 (not known)
	-- LCK.KNOWLEDGE_NODATA = 0 (no data for this character)
	-- LCK.KNOWLEDGE_INVALID = -1 (invalid item/motif)
	
	if knowledge == LCK.KNOWLEDGE_KNOWN then
		return true
	elseif knowledge == LCK.KNOWLEDGE_UNKNOWN then
		return false
	else
		-- NODATA or INVALID - we don't know, so assume not known
		return false
	end
end

function TB_Object:UpdateMotifs()
	-- Motif knowledge is now queried from LCK on-demand
	-- This function is kept for compatibility but does nothing
	-- The UI queries GetMotifKnowledgeForCharacter() directly when needed
	
	-- Optional: Trigger UI refresh to update motif display
	if self.ui and self.ui.motifs then
		zo_callLater(function()
			if self.ui.motifs.Refresh then
				self.ui.motifs:Refresh()
			end
		end, 100)
	end
end

function TB_Object:UpdateAllCharacterMotifsFromLCK()
	if not LCK then
		d("TraitBuddy: LibCharacterKnowledge not available - install LCK to track other characters")
		return
	end
	
	local lckCharacters = LCK.GetCharacterList(nil)
	local numChapters = TraitBuddy.Data:GetNumChapters()
	
	d(sf("TraitBuddy: Syncing motif knowledge for %d characters from LCK...", #lckCharacters))
	
	local syncedCount = 0
	for _, lckChar in ipairs(lckCharacters) do
		-- Find matching TraitBuddy character by ID
		local tbChar = nil
		local tbCharId = nil
		for _, id in ipairs(self:GetCharacters(false)) do
			if tostring(id) == lckChar.id then
				tbChar = self:GetCharacter(id)
				tbCharId = id
				break
			end
		end
		
		if tbChar then
			-- Update all motifs for this character
			for itemStyleIndex = 1, GetNumValidItemStyles() do
				local itemStyleId = GetValidItemStyleId(itemStyleIndex)
				if itemStyleId > 0 then
					local motif = TraitBuddy.data:GetMotifByItemStyleId(itemStyleId)
					if motif then
						local order = motif:Order()
						
						if motif:HasChapters() then
							-- Chaptered motifs
							tbChar.motifs[order] = tbChar.motifs[order] or {}
							for chapter = 1, numChapters do
								local chapterConstant = TraitBuddy.data:GetChapterConstant(chapter)
								local knowledge = LCK.GetMotifKnowledgeForCharacter(itemStyleId, chapterConstant, nil, lckChar.id)
								if knowledge == LCK.KNOWLEDGE_KNOWN then
									tbChar.motifs[order][chapter] = true
								elseif knowledge == LCK.KNOWLEDGE_UNKNOWN then
									tbChar.motifs[order][chapter] = false
								end
								-- Leave existing value if NODATA or INVALID
							end
						else
							-- Non-chaptered motifs - check chapter 1
							local knowledge = LCK.GetMotifKnowledgeForCharacter(itemStyleId, ITEM_STYLE_CHAPTER_ALL, nil, lckChar.id)
							if knowledge == LCK.KNOWLEDGE_KNOWN then
								tbChar.motifs[order] = true
							elseif knowledge == LCK.KNOWLEDGE_UNKNOWN then
								tbChar.motifs[order] = false
							end
							-- Leave existing value if NODATA or INVALID
						end
					end
				end
			end
			syncedCount = syncedCount + 1
		end
	end
	
	d(sf("TraitBuddy: Synced %d characters from LCK", syncedCount))
end

function TB_Object:GetResearchShowName(craftingSkillType)
	if craftingSkillType==CRAFTING_TYPE_BLACKSMITHING then
		return "bs"
	elseif craftingSkillType==CRAFTING_TYPE_CLOTHIER then
		return "cl"
	elseif craftingSkillType==CRAFTING_TYPE_WOODWORKING then
		return "ww"
	elseif craftingSkillType==CRAFTING_TYPE_JEWELRYCRAFTING then
		return "je"
	end
	return nil
end

function TB_Object:CheckESOPlus()
	if self.settings.esoplusCheck then
		if self.settings.esoplus ~= IsESOPlusSubscriber() then
			local msg = sf("|cff8800%s|r %s", self.ADDON_NAME, GetString(TB_ESOPLUS_CHAT))
			local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT)
			messageParams:SetText(msg)
			CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
			d(msg)
		end
	end
	self.settings.esoplus = IsESOPlusSubscriber()
end

function TB_Object:GetCharacters(sorted)
	if sorted and sorted == true then
		return self.soc
	else
		return self.settings.characters
	end
end

function TB_Object:SortCharacters()
	--Sort the characters by name and return their IDs in an ordered table
	local t = {} --Numeric sorted hash table id+name
	for id,c in pairs(self:GetCharacters()) do
		t[#t+1] = {id=id, name=c.name}
	end
	table.sort(t, function(a,b) return a.name<b.name end)
	local s = {} --Numeric table of ids
	for k,v in ipairs(t) do
		s[#s+1] = v.id
	end
	self.soc = s
end

function TB_Object:GetCharacter(id)
	return self.settings.characters[id]
end

function TB_Object:GetCraftingSkillTypes()
	return {CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING}
end

function TB_Object:IsResearchableTrait(traitType)
	local category = GetItemTraitTypeCategory(traitType)
	if (category~=ITEM_TRAIT_TYPE_CATEGORY_ARMOR and category~=ITEM_TRAIT_TYPE_CATEGORY_WEAPON and category~=ITEM_TRAIT_TYPE_CATEGORY_JEWELRY) then return false end
	return self.data:IsResearchableTrait(traitType)
end

function TB_Object:LinkToCraftingSkillType(itemLink)
	local itemType = GetItemLinkItemType(itemLink)
	if itemType==ITEMTYPE_ARMOR then
		local equipType = GetItemLinkEquipType(itemLink)
		if equipType==EQUIP_TYPE_RING or equipType==EQUIP_TYPE_NECK then
			return CRAFTING_TYPE_JEWELRYCRAFTING
		else
			local armorType = GetItemLinkArmorType(itemLink)
			if armorType==ARMORTYPE_HEAVY then
				return CRAFTING_TYPE_BLACKSMITHING
			elseif armorType==ARMORTYPE_MEDIUM or armorType==ARMORTYPE_LIGHT then
				return CRAFTING_TYPE_CLOTHIER
			end
		end
	elseif itemType==ITEMTYPE_WEAPON then
		local weaponType = GetItemLinkWeaponType(itemLink)
		if IsBlacksmithWeapon(weaponType) then
			return CRAFTING_TYPE_BLACKSMITHING
		elseif IsWoodworkingWeapon(weaponType) then
			return CRAFTING_TYPE_WOODWORKING
		end
	end
	return nil
end

function TB_Object:FindTraitIndex(craftingSkillType, researchLineIndex, traitType)
	--Trying not to hard code the trait type indexes
	local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
	for traitIndex = 1, numTraits do
		local foundTraitType, _, _ = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
		if foundTraitType == traitType then
			return traitIndex
		end
	end
	return ITEM_TRAIT_TYPE_NONE
end

function TB_Object:CalcMaxNumTraits()
	--Remember how many traits are possible
	for key,craftingSkillType in pairs(self:GetCraftingSkillTypes()) do
		local total = 0
		for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
			local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
			total = total + numTraits
		end
		self.maxNumTraits[craftingSkillType] = total
	end
end

function TB_Object:GetMaxNumTraits(craftingSkillType)
	return self.maxNumTraits[craftingSkillType]
end

function TB_Object:IsTraitBeingResearched(character, craftingSkillType, researchLineIndex, traitIndex)
	if character and craftingSkillType and researchLineIndex and traitIndex then
		if craftingSkillType>0 and researchLineIndex>0 and traitIndex>0 then
			return (type(character.research[craftingSkillType][researchLineIndex][traitIndex])=="table")
		end
	end
	return false
end

function TB_Object:IsTraitKnown(character, craftingSkillType, researchLineIndex, traitIndex)
	if character and craftingSkillType and researchLineIndex and traitIndex then
		if craftingSkillType>0 and researchLineIndex>0 and traitIndex>0 then
			if self:IsTraitBeingResearched(character, craftingSkillType, researchLineIndex, traitIndex)==false then
				return character.research[craftingSkillType][researchLineIndex][traitIndex]
			end
		end
	end	
	return false
end

function TB_Object:DefaultSettings()
	local defaults = {
		tooltip = {
			show = {
				knowSection = true,
				researchingSection = true,
				canResearchSection = true,
				youKnowSection = false,
				bag = true,
				loot = true,
				mail = true,
				buyback = true,
				trade = true,
				tradingHouse = true,
				chat = true,
				quest = true,
				crafting = true,
				worn = true,
				title = false,
				inventoryInsight = false,
				motifLocation = true,
			},
			colours = {
				know_title = {
					r = 0,
					g = 1,
					b = 0,
				},
				researching_title = {
					r = 0.25,
					g = 0.5,
					b = 1,
				},
				canResearch_title = {
					r = 1,
					g = 1,
					b = 0,
				},
			},
		},
		colours = {
			know = {
				r = 0,
				g = 1,
				b = 0,
			},
			researching = {
				r = 0.25,
				g = 0.5,
				b = 1,
			},
			others_know = {
				r = 1,
				g = 1,
				b = 0,
			},
			others_researching = {
				r = 1,
				g = 0.65,
				b = 0,
			},
			not_known = {
				r = 1,
				g = 0.2,
				b = 0.2,
			},
			mark = {
				r = 0.2,
				g = 0.2,
				b = 1,
			},
		},
		inventory = {
			show = {
				bag = true,
				bank = true,
				guild = true,
				crafting = true,
			},
			colours = {
				othersCan = {
					r = 1,
					g = 1,
					b = 0,
				},
			},
			IGVOnTop = false,
			gameIcon = true,
		},
		characters = {},
		alternativeSelection = true,
		locked = true,
		x = 260,
		y = 115,
		esoplusCheck = true,
		esoplus = IsESOPlusSubscriber(),
		showLaunch1 = true,
		showLaunch2 = true,
		showLaunch3 = true,
		tidy = true,
		messageComplete = true,
	}
	return defaults
end

function TB_Object:DeleteCharacter(id)
	if not id then return end
	self.settings.characters[id] = nil
	if not self.ui:IsCreated() then
		self.ui.updatelater:DeleteCharacter(id)
		return
	end
	
	self:SortCharacters()
	self.ui.selector:Build(TraitBuddy.characterId)
	self.ui.research:UpdateUI()
	self.ui.settings:ClearCharacter(id)
end

function TB_Object:TidyCharacters()
	--Delete the old character data plus tidy the UI
	if self.settings.tidy then
		--Which characters to tidy
		local found = {}
		for i = 1, GetNumCharacters() do
			local name, gender, level, classId, raceId, alliance, id, locationId = GetCharacterInfo(i)
			found[id] = true
		end
		for id,c in pairs(self:GetCharacters()) do
			if not found[id] then
				self:DeleteCharacter(id)
			end
		end
	end
end

function TB_Object:UpdateResearch()
	--Update the saved research data for this character
	local c = self:GetCharacter(self.characterId)
	if c then
		for key,craftingSkillType in pairs(self:GetCraftingSkillTypes()) do
			c.research[craftingSkillType].MaxSimultaneousResearch = GetMaxSimultaneousSmithingResearch(craftingSkillType)
			for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
				local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
				for traitIndex = 1, numTraits do
					local _, _, known = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
					local durationSecs, timeRemainingSecs = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)	--can be nil
					local wasBeingResearched = self:IsTraitBeingResearched(c, craftingSkillType, researchLineIndex, traitIndex)
					local currentlyResearching = false
					local whenDoneTimeStamp = 0
					if durationSecs then
						currentlyResearching = true
						whenDoneTimeStamp = GetTimeStamp() + timeRemainingSecs
					end
					if wasBeingResearched then
						--Was researching at some point
						if known then
							c.research[craftingSkillType][researchLineIndex][traitIndex] = nil
							c.research[craftingSkillType][researchLineIndex][traitIndex] = true
						else
							if currentlyResearching then
								c.research[craftingSkillType][researchLineIndex][traitIndex] = { duration = durationSecs, done = whenDoneTimeStamp }
							else
								--correct some mistake
								c.research[craftingSkillType][researchLineIndex][traitIndex] = nil
								c.research[craftingSkillType][researchLineIndex][traitIndex] = false
							end
						end
					elseif currentlyResearching then
						c.research[craftingSkillType][researchLineIndex][traitIndex] = { duration = durationSecs, done = whenDoneTimeStamp }
					else
						c.research[craftingSkillType][researchLineIndex][traitIndex] = known
					end
				end
			end
		end
	end
end

function TB_Object:UpdateResearching()
	--Update any traits which were researching that have now finished
	local updateUI = false
	local nextTimeRemainingSecs = nil
	local craftingSkillTypes = self:GetCraftingSkillTypes()
	for id,c in pairs(self:GetCharacters()) do
		for _,craftingSkillType in pairs(craftingSkillTypes) do
			for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
				local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
				for traitIndex = 1, numTraits do
					if self:IsTraitBeingResearched(c, craftingSkillType, researchLineIndex, traitIndex) then
						local now = GetTimeStamp()
						local timeRemainingSecs = GetDiffBetweenTimeStamps(c.research[craftingSkillType][researchLineIndex][traitIndex].done, now)
						if timeRemainingSecs <= 0 then
							local key = sf("c%dr%dt%d", craftingSkillType, researchLineIndex, traitIndex)
							c.completed = c.completed or {}
							c.completed[key] = {
								craftingSkillType=craftingSkillType,
								researchLineIndex=researchLineIndex,
								traitIndex=traitIndex
							}
							c.research[craftingSkillType][researchLineIndex][traitIndex] = nil
							c.research[craftingSkillType][researchLineIndex][traitIndex] = true
							updateUI = true
						else
							if nextTimeRemainingSecs == nil then
								nextTimeRemainingSecs = timeRemainingSecs
							else
								if timeRemainingSecs < nextTimeRemainingSecs then
									nextTimeRemainingSecs = timeRemainingSecs
								end
							end
						end
					end
				end
			end
		end
	end
	
	if self.ui.updatelater:IsUpdating() then
		updateUI = false
	end
	if updateUI then
		if self.ui:IsCreated() then
			self.ui.research:UpdateUI()
		else
			self.ui.updatelater:UpdateResearchUI()
		end
	end
	
	--When to update research again
	if nextTimeRemainingSecs then
		local ms = nextTimeRemainingSecs*1000
		zo_callLater(function() self:UpdateResearching() end, ms)
	end
end

function TB_Object:ItemToResearchLineIndex(itemType, armorType, weaponType, equipType)
	--Figure out which research index this item is. Hope to find a function to do this
	if itemType == ITEMTYPE_ARMOR then
		if equipType==EQUIP_TYPE_RING then
				return 1
		elseif equipType==EQUIP_TYPE_NECK then
				return 2
		elseif armorType == ARMORTYPE_HEAVY then
			if equipType == EQUIP_TYPE_CHEST then --Cuirass
				return 8
			elseif equipType == EQUIP_TYPE_FEET then --Sabatons
				return 9
			elseif equipType == EQUIP_TYPE_HAND then --Gauntlets
				return 10
			elseif equipType == EQUIP_TYPE_HEAD then --Helm
				return 11
			elseif equipType == EQUIP_TYPE_LEGS then --Greaves
				return 12
			elseif equipType == EQUIP_TYPE_SHOULDERS then --Pauldron
				return 13
			elseif equipType == EQUIP_TYPE_WAIST then --Girdle
				return 14
			end
		elseif armorType == ARMORTYPE_MEDIUM then
			if equipType == EQUIP_TYPE_CHEST then --Jack
				return 8
			elseif equipType == EQUIP_TYPE_FEET then --Boots
				return 9
			elseif equipType == EQUIP_TYPE_HAND then --Bracers
				return 10
			elseif equipType == EQUIP_TYPE_HEAD then --Helmet
				return 11
			elseif equipType == EQUIP_TYPE_LEGS then --Guards
				return 12
			elseif equipType == EQUIP_TYPE_SHOULDERS then --Arm Cops
				return 13
			elseif equipType == EQUIP_TYPE_WAIST then --Belt
				return 14
			end
		elseif armorType == ARMORTYPE_LIGHT then
			if equipType == EQUIP_TYPE_CHEST then --Robe+Shirt = Robe & Jerkin
				return 1
			elseif equipType == EQUIP_TYPE_FEET then --Shoes
				return 2
			elseif equipType == EQUIP_TYPE_HAND then --Gloves
				return 3
			elseif equipType == EQUIP_TYPE_HEAD then --Hat
				return 4
			elseif equipType == EQUIP_TYPE_LEGS then --Breeches
				return 5
			elseif equipType == EQUIP_TYPE_SHOULDERS then --Epaulets
				return 6
			elseif equipType == EQUIP_TYPE_WAIST then --Sash
				return 7
			end
		end
	elseif itemType == ITEMTYPE_WEAPON then
		if weaponType == WEAPONTYPE_AXE then
			return 1
		elseif weaponType == WEAPONTYPE_HAMMER then
			return 2
		elseif weaponType == WEAPONTYPE_SWORD then
			return 3
		elseif weaponType == WEAPONTYPE_TWO_HANDED_AXE then
			return 4
		elseif weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then
			return 5
		elseif weaponType == WEAPONTYPE_TWO_HANDED_SWORD then
			return 6
		elseif weaponType == WEAPONTYPE_DAGGER then
			return 7
		elseif weaponType == WEAPONTYPE_BOW then
			return 1
		elseif weaponType == WEAPONTYPE_FIRE_STAFF then
			return 2
		elseif weaponType == WEAPONTYPE_FROST_STAFF then
			return 3
		elseif weaponType == WEAPONTYPE_LIGHTNING_STAFF then
			return 4
		elseif weaponType == WEAPONTYPE_HEALING_STAFF then
			return 5
		elseif weaponType == WEAPONTYPE_SHIELD then
			return 6
		end
	end
	return nil
end

function TB_Object:GetWhoKnows(craftingSkillType, researchLineIndex, traitIndex, forTooltip)
	--Figure out who knows the trait, Returns sorted tables of character names
	local know = {}
	local researching = {}
	local dontKnow = {}
	if craftingSkillType and researchLineIndex and traitIndex then
		if craftingSkillType>0 and researchLineIndex>0 and traitIndex>0 then
			for _,id in ipairs(self:GetCharacters(true)) do
				local c = self:GetCharacter(id)
				local show = true
				if forTooltip then
					show = GetShow_CraftingSkillType(c, craftingSkillType)
				end
				if show then
					if self:IsTraitBeingResearched(c, craftingSkillType, researchLineIndex, traitIndex) then
						researching[#researching+1] = c.name
					elseif self:IsTraitKnown(c, craftingSkillType, researchLineIndex, traitIndex) then
						know[#know+1] = c.name
					else
						dontKnow[#dontKnow+1] = c.name
					end
				end
			end
		end
	end
	return know, researching, dontKnow
end

function TB_Object:BuildTooltipTitle(control, title, GamePadMode)
	if GamePadMode then
		control:AddLine(self.ADDON_NAME, {fontSize=27, customSpacing=15}, control:GetStyle("bodyHeader"))
		control:AddLine(title, GAMEPAD_STYLE_2, control:GetStyle("bodySection"))
	else
		control:AddLine(title, "ZoFontGameBold", 1,1,1, LEFT, MODIFY_TEXT_TYPE_UPPERCASE, TEXT_ALIGN_CENTER, true)
	end
end

function TB_Object:BuildTooltip(control, know, researching, canResearch, GamePadMode)
	local r,g,b = ZO_NORMAL_TEXT:UnpackRGB()
	local tooltip = self.settings.tooltip
	--Already researched
	if #know > 0 and tooltip.show.knowSection then
		if GamePadMode then
			GAMEPAD_STYLE_1.fontColor = ZO_ColorDef:New(tooltip.colours.know_title.r,tooltip.colours.know_title.g,tooltip.colours.know_title.b)
			control:AddLine(GetString(TB_KNOWN), GAMEPAD_STYLE_1, control:GetStyle("bodySection"))
			control:AddLine(ZO_GenerateCommaSeparatedListWithoutAnd(know), GAMEPAD_STYLE_2, control:GetStyle("bodySection"))
		else
			control:AddLine(GetString(TB_KNOWN), "TBFontItemCategory", tooltip.colours.know_title.r,tooltip.colours.know_title.g,tooltip.colours.know_title.b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
			control:AddLine(ZO_GenerateCommaSeparatedListWithoutAnd(know), "TBFontGame16", r,g,b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
		end
	end
	--Being researched
	if #researching > 0 and tooltip.show.researchingSection then
		if GamePadMode then
			GAMEPAD_STYLE_1.fontColor = ZO_ColorDef:New(tooltip.colours.researching_title.r,tooltip.colours.researching_title.g,tooltip.colours.researching_title.b)
			control:AddLine(GetString(TB_BEING_RESEARCHED), GAMEPAD_STYLE_1, control:GetStyle("bodySection"))
			control:AddLine(ZO_GenerateCommaSeparatedListWithoutAnd(researching), GAMEPAD_STYLE_2, control:GetStyle("bodySection"))
		else
			control:AddLine(GetString(TB_BEING_RESEARCHED), "TBFontItemCategory", tooltip.colours.researching_title.r,tooltip.colours.researching_title.g,tooltip.colours.researching_title.b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
			control:AddLine(ZO_GenerateCommaSeparatedListWithoutAnd(researching), "TBFontGame16", r,g,b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
		end
	end
	--Could be researched
	if #canResearch > 0 and tooltip.show.canResearchSection then
		if GamePadMode then
			GAMEPAD_STYLE_1.fontColor = ZO_ColorDef:New(tooltip.colours.canResearch_title.r,tooltip.colours.canResearch_title.g,tooltip.colours.canResearch_title.b)
			control:AddLine(GetString(TB_COULD_RESEARCH), GAMEPAD_STYLE_1, control:GetStyle("bodySection"))
			control:AddLine(ZO_GenerateCommaSeparatedListWithoutAnd(canResearch), GAMEPAD_STYLE_2, control:GetStyle("bodySection"))
		else
			control:AddLine(GetString(TB_COULD_RESEARCH), "TBFontItemCategory", tooltip.colours.canResearch_title.r,tooltip.colours.canResearch_title.g,tooltip.colours.canResearch_title.b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
			local rr = TraitBuddy.settings.tooltip.colours.canResearch_title.r * 255
local gg = TraitBuddy.settings.tooltip.colours.canResearch_title.g * 255
local bb = TraitBuddy.settings.tooltip.colours.canResearch_title.b * 255
control:AddLine(sf("|c%02X%02X%02X%d|r: %s", rr, gg, bb, #canResearch, ZO_GenerateCommaSeparatedListWithoutAnd(canResearch)), "TBFontGame16", r,g,b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
		end
	end
end

function TB_Object:GetGamepadStyle(number)
	if number == 1 then
		return GAMEPAD_STYLE_1
	else
		return GAMEPAD_STYLE_2
	end
end

function TB_Object:OnResearchStarted(craftingSkillType, researchLineIndex, traitIndex)
	local durationSecs, timeRemainingSecs = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)
	--durationSecs, timeRemainingSecs: both = the same time
	self:GetCharacter(self.characterId).research[craftingSkillType][researchLineIndex][traitIndex] = { duration = durationSecs, done = GetTimeStamp() + timeRemainingSecs }
	self.ui.research:UpdateUI()
	self.ui:UpdateUI(craftingSkillType)
	self:UpdateResearching()
end

function TB_Object:OnResearchCanceled(craftingSkillType, researchLineIndex, traitIndex)
	local c = self:GetCharacter(self.characterId)
	c.research[craftingSkillType][researchLineIndex][traitIndex] = nil
	c.research[craftingSkillType][researchLineIndex][traitIndex] = false
end

function TB_Object:OnResearchCompleted(craftingSkillType, researchLineIndex, traitIndex)
	if not self.ui:IsCreated() then
		self.ui.updatelater:ResearchCompleted(craftingSkillType, researchLineIndex, traitIndex)
		return
	end
	self:ResearchCompleted(craftingSkillType, researchLineIndex, traitIndex)
	self.ui.research:UpdateUI()
	self.ui:UpdateUI(craftingSkillType)
	self:UpdateResearching()
end

function TB_Object:OnResearchTimesUpdated()
	--Research scroll, OnResearchCompleted fires off if the research finishes
	local c = self:GetCharacter(self.characterId)
	if c then
		for key,craftingSkillType in pairs(self:GetCraftingSkillTypes()) do
			for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
				local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
				for traitIndex = 1, numTraits do
					if self:IsTraitBeingResearched(c, craftingSkillType, researchLineIndex, traitIndex) then
						local durationSecs, timeRemainingSecs = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)	--can be nil
						if durationSecs then
							local whenDoneTimeStamp = GetTimeStamp() + timeRemainingSecs
							c.research[craftingSkillType][researchLineIndex][traitIndex] = { duration = durationSecs, done = whenDoneTimeStamp }
						end
					end
				end
			end
		end
	end
	self.ui.research:UpdateUI()
end

function TB_Object:ResearchCompleted(craftingSkillType, researchLineIndex, traitIndex)
	--Update the data
	local c = self:GetCharacter(self.characterId)
	if self:IsTraitBeingResearched(c, craftingSkillType, researchLineIndex, traitIndex) then
		c.research[craftingSkillType][researchLineIndex][traitIndex] = nil
	end
	c.research[craftingSkillType][researchLineIndex][traitIndex] = true
	local key = sf("c%dr%dt%d", craftingSkillType, researchLineIndex, traitIndex)
	if c.completed and c.completed[key] then
		c.completed[key].done = true
	end
	--Message
	if self.settings.messageComplete then
		if not doneMessages[key] then
			local researchLineName = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
			local traitType = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
			local msg = sf("|cff8800%s|r %s", self.ADDON_NAME, zo_str(SI_FINISHED_SMITHING_TRAIT_RESEARCH, GetString("SI_ITEMTRAITTYPE", traitType), researchLineName))
			local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.SMITHING_FINISH_RESEARCH)
			messageParams:SetText(msg)
			CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
			d(msg)
			doneMessages[key] = true
		end
	end
end

function TB_Object:OnNonCombatBonusChanged(nonCombatBonusType)
	local craftingSkillType = CRAFTING_TYPE_INVALID
	if nonCombatBonusType==NON_COMBAT_BONUS_BLACKSMITHING_RESEARCH_LEVEL then
		craftingSkillType = CRAFTING_TYPE_BLACKSMITHING
	elseif nonCombatBonusType==NON_COMBAT_BONUS_CLOTHIER_RESEARCH_LEVEL then
		craftingSkillType = CRAFTING_TYPE_CLOTHIER
	elseif nonCombatBonusType==NON_COMBAT_BONUS_WOODWORKING_RESEARCH_LEVEL then
		craftingSkillType = CRAFTING_TYPE_WOODWORKING
	elseif nonCombatBonusType==NON_COMBAT_BONUS_JEWELRYCRAFTING_RESEARCH_LEVEL then
		craftingSkillType = CRAFTING_TYPE_JEWELRYCRAFTING
	end
	-- Check the crafting skill type is valid/one of the trait ones
	if craftingSkillType~=CRAFTING_TYPE_INVALID then
		for key,validSkillType in pairs(self:GetCraftingSkillTypes()) do
			if craftingSkillType==validSkillType then
				if not self.ui:IsCreated() then
					self.ui.updatelater:NonCombatBonusChanged(craftingSkillType)
					return
				end
				local c = self:GetCharacter(self.characterId)
				self:UpdateResearch()
				self:UpdateResearching()
				self.ui:UpdateCurrentMaxSimultaneousResearch(craftingSkillType)
				self.ui.research:UpdateUI()
				self.ui:UpdateNumResearching(c)
				do break end
			end
		end
	end
end

function TB_Object:OnStyleLearned(itemStyleId, chapterIndex)
	self.ui.motifs:OnStyleLearned(itemStyleId, chapterIndex)
end

function TB_Object:OnLoaded(addonName)
	local name = self.ADDON_NAME
	if addonName ~= name then return end
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
	
	SCENE_MANAGER:RegisterTopLevel(TB, false)
	SLASH_COMMANDS["/tb"] = function(args) self.ui:Toggle() end
	SLASH_COMMANDS["/traitbuddy"] = function(args) self.ui:Toggle() end
	
	SLASH_COMMANDS["/tbchecksets"] = function()
		d("=== LibSets Integration Check ===")
		
		-- Check 1: Is LibSets loaded at all?
		if not LibSets then
			d("LibSets is NOT loaded!")
			d("Possible causes:")
			d("  1. LibSets is not installed")
			d("  2. LibSets is disabled in addon list")
			d("  3. LibSets failed to load (check for errors)")
			return
		end
		d("LibSets table exists")
		
		-- Check 2: What functions does LibSets have?
		d("\nLibSets available functions:")
		local functionCount = 0
		for k, v in pairs(LibSets) do
			if type(v) == "function" then
				d("  - " .. k)
				functionCount = functionCount + 1
				if functionCount > 20 then
					d("  ... (showing first 20)")
					break
				end
			end
		end
		
		if functionCount == 0 then
			d("No functions found in LibSets!")
			d("LibSets may not be initialized yet")
			return
		end
		
		-- Check 3: Try different possible function names
		d("\nTrying to call LibSets functions:")
		
		-- Try GetNumCraftedSets (your current version)
		if type(LibSets.GetNumCraftedSets) == "function" then
			local numSets = LibSets.GetNumCraftedSets()
			d("GetNumCraftedSets() = " .. tostring(numSets))
		else
			d("GetNumCraftedSets is not a function (type: " .. type(LibSets.GetNumCraftedSets) .. ")")
		end
		
		-- Try GetSetInfo (alternative API)
		if type(LibSets.GetSetInfo) == "function" then
			d("✓etSetInfo exists")
		else
			d("GetSetInfo does not exist")
		end
		
		-- Try GetCraftedSetInfo
		if type(LibSets.GetCraftedSetInfo) == "function" then
			local success, result = pcall(function()
				return LibSets.GetCraftedSetInfo(1)
			end)
			if success then
				d("GetCraftedSetInfo(1) succeeded")
			else
				d("GetCraftedSetInfo exists but failed: " .. tostring(result))
			end
		else
			d("GetCraftedSetInfo does not exist")
		end
		
		-- Check 4: Look for version/initialization info
		if LibSets.version then
			d("\nLibSets version: " .. tostring(LibSets.version))
		end
		
		if LibSets.name then
			d("LibSets name: " .. tostring(LibSets.name))
		end
		
		-- Check 5: Test setData
		d("\nTesting setData:")
		if TraitBuddy and TraitBuddy.data then
			local success, sets = pcall(function()
				return TraitBuddy.data:GetSets()
			end)
			
			if success then
				d("setData:GetSets() succeeded")
				d("  Returned " .. #sets .. " sets")
				if #sets > 0 then
					d("  First set: " .. tostring(sets[1].name))
				end
			else
				d("setData:GetSets() failed:")
				d("  " .. tostring(sets))
			end
		else
			d("TraitBuddy.data not available")
		end
	end

	d("Registered /tbchecksets command")
	
	SLASH_COMMANDS["/tbchecksets2"] = function()
		d("=== LibSets 0.86 API Test ===")
		
		if not LibSets or not LibSets.setInfo then
			d("LibSets.setInfo not available")
			return
		end
		
		d("✓ LibSets.setInfo exists")
		
		-- Count crafted sets
		local craftedCount = 0
		local firstCraftedSet = nil
		
		for setId, setInfo in pairs(LibSets.setInfo) do
			local traitsNeeded = LibSets.GetTraitsNeeded(setId)
			if traitsNeeded then
				craftedCount = craftedCount + 1
				if not firstCraftedSet then
					local info = LibSets.GetSetInfo(setId, true)
					firstCraftedSet = {
						id = setId,
						name = info and info.setName or "Unknown",
						traits = traitsNeeded
					}
				end
			end
		end
		
		d(string.format("Found %d crafted sets", craftedCount))
		if firstCraftedSet then
			d(string.format("Example: %s (ID:%d, Traits:%d)", 
				firstCraftedSet.name, firstCraftedSet.id, firstCraftedSet.traits))
		end
		
		-- Test setData
		local sets = TraitBuddy.data:GetSets()
		d(string.format("setData returned %d sets", #sets))
		if #sets > 0 then
			d(string.format("First set: %s (Traits:%d, Locations:%d)",
				sets[1].name, sets[1].traits, #(sets[1].locations or {})))
		end
	end
	
	SLASH_COMMANDS["/tbzonedump"] = function()
	  local sets = TraitBuddy.data:GetSets()
	  for i, set in ipairs(sets) do
		local ids = LibSets.GetWayshrineIds(set.id)
		if ids and ids[1] then
		  local zId = LibSets.GetWayshrinesZoneId(ids[1])
		  if zId then
			d(set.name..":"..zId..":"..GetZoneNameById(zId))
		  end
		end
	  end
	end

	local worldName = GetWorldName()
	local profile = nil
	local found, findStart, findEnd = zo_plainstrfind(worldName, " ")
	if found then
		if zo_strsub(worldName, 1, findStart-1)=="NA" then
			profile = "NA"
		end
	end
	
	self.characterId = GetCurrentCharacterId()
	self.settings = ZO_SavedVars:NewAccountWide("TraitBuddySettings", 1, nil, self:DefaultSettings(), profile)

	EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function() self:OnPlayerActivated() end)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, function(_, ...) self:OnResearchCompleted(...) end)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, function(_, ...) self:OnResearchStarted(...) end)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, function(_, ...) self:OnResearchCanceled(...) end)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED, function() self:OnResearchTimesUpdated() end)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_STYLE_LEARNED, function(_, ...) self:OnStyleLearned(...) end)
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
		if TraitBuddy.ui and TraitBuddy.ui.settings and TraitBuddy.ui.settings.OnSettingsControlsCreated then
			TraitBuddy.ui.settings:OnSettingsControlsCreated(panel)
		end
	end)
end

TraitBuddy = TB_Object:New()
EVENT_MANAGER:RegisterForEvent(TraitBuddy.ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName) TraitBuddy:OnLoaded(addonName) end)