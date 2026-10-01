local LCCC = LibCodesCommonCode
local LEJ = LibExtendedJournal
local LootLog = LootLog


--------------------------------------------------------------------------------
-- LootLog.AddAntiquityTooltipExtension
--------------------------------------------------------------------------------

function LootLog.AddAntiquityTooltipExtension( tooltip, antiquityId )
	if (type(antiquityId) ~= "number" or antiquityId == 0) then return end

	local extension = LEJ.TooltipExtensionInitialize(
		true,
		zo_strformat(SI_ANTIQUITY_TIMES_ACQUIRED, GetNumAntiquitiesRecovered(antiquityId)),
		zo_strformat(SI_ANTIQUITY_CODEX_ENTRIES_FOUND, GetNumAntiquityLoreEntriesAcquired(antiquityId), GetNumAntiquityLoreEntries(antiquityId)):gsub("|c%w%w%w%w%w%w", ""):gsub("|r", ""),
		"Antiquity"
	)

	extension:AddSection(nil, LootLog.GetAntiquityRewardLink(antiquityId))

	local setId = GetAntiquitySetId(antiquityId)
	if (setId and setId ~= 0) then
		local results = { }
		local leads = 0

		for i = 1, GetNumAntiquitySetAntiquities(setId) do
			local fragmentId = GetAntiquitySetAntiquityId(setId, i)
			local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetAntiquityName(fragmentId))

			local color
			if (DoesAntiquityNeedCombination(fragmentId)) then
				color = LEJ.GetTooltipColor(1, 1)
				leads = leads + 1
			elseif (DoesAntiquityHaveLead(fragmentId)) then
				color = LEJ.GetTooltipColor(1, 3)
				leads = leads + 1
			else
				color = LEJ.GetTooltipColor(1, 2)
			end

			if (antiquityId == fragmentId) then
				table.insert(results, string.format("|c%06X|l0:1:1:1:1:%06X|l%s|l|r", color, color, name))
			else
				table.insert(results, string.format("|c%06X%s|r", color, name))
			end
		end

		extension:AddSection(string.format("%s (%d/%d)", GetString(SI_ANTIQUITY_FRAGMENTS), leads, #results), table.concat(results, ", "))
	end

	extension:Finalize(tooltip, true)

	return true
end


--------------------------------------------------------------------------------
-- LootLog.AddTreasureMapTooltipExtension
--------------------------------------------------------------------------------

function LootLog.AddTreasureMapTooltipExtension( tooltip, itemLink )
	-- Punt this over to AddAntiquityTooltipExtension for tradeable leads
	if (LootLog.AddAntiquityTooltipExtension(tooltip, LootLog.GetAntiquityIdFromItem(itemLink))) then return end

	local antiquityIds = LootLog.GetAntiquityIdsForTreasureMap(itemLink)
	if (#antiquityIds == 0) then return end

	local results = { }
	local foundAtLeastOnce = 0
	local totalRecovered = 0
	local totalLoreAcquired = 0
	local totalLore = 0

	for _, antiquityId in ipairs(antiquityIds) do
		local recovered = GetNumAntiquitiesRecovered(antiquityId)
		local loreAcquired = GetNumAntiquityLoreEntriesAcquired(antiquityId)
		local lore = GetNumAntiquityLoreEntries(antiquityId)

		local inProgressText = ""
		local loreAcquiredEffective = loreAcquired
		if (DoesAntiquityHaveLead(antiquityId)) then
			inProgressText = "+1"
			if (loreAcquiredEffective < lore) then
				-- If the player has an unexcavated lead, let it count towards the codex
				loreAcquiredEffective = loreAcquiredEffective + 1
			end
		end

		totalRecovered = totalRecovered + recovered
		totalLoreAcquired = totalLoreAcquired + loreAcquired
		totalLore = totalLore + lore

		local color
		if (loreAcquiredEffective >= lore) then
			color = "fullCodex"
			foundAtLeastOnce = foundAtLeastOnce + 1
		elseif (loreAcquiredEffective > 0) then
			color = "incompleteCodex"
			foundAtLeastOnce = foundAtLeastOnce + 1
		else
			color = "neverFound"
		end

		table.insert(results, string.format("|c%06X%d / %d|r   •   %s |c%s(%d%s)|r", LootLog.vars.antiquityMapColors[color], loreAcquired, lore, LootLog.FormatAntiquityLead(antiquityId, false), ZO_DISABLED_TEXT:ToHex(), recovered, inProgressText))
	end

	local extension = LEJ.TooltipExtensionInitialize(
		true,
		zo_strformat(SI_ANTIQUITY_TIMES_ACQUIRED, totalRecovered),
		zo_strformat(SI_ANTIQUITY_CODEX_ENTRIES_FOUND, totalLoreAcquired, totalLore):gsub("|c%w%w%w%w%w%w", ""):gsub("|r", ""),
		"Antiquity"
	)
	extension:AddSection(string.format("%s (%d/%d)", GetString(SI_MAP_INFO_MODE_ANTIQUITIES), foundAtLeastOnce, #results), table.concat(results, "\n"), TEXT_ALIGN_LEFT)
	extension:Finalize(tooltip, true)
end


--------------------------------------------------------------------------------
-- LootLog.HookAntiquityTooltips
--------------------------------------------------------------------------------

local AreAntiquityTooltipsHooked = false

function LootLog.HookAntiquityTooltips( )
	if (AreAntiquityTooltipsHooked or not LootLog.vars.antiquityEnabled) then return end
	AreAntiquityTooltipsHooked = true

	do -- Antiquity Leads
		local TooltipHook = function( control, functionName, leadFunction )
			ZO_PostHook(control, functionName, function( self, ... )
				if (LootLog.vars.antiquityEnabled) then
					LootLog.AddAntiquityTooltipExtension(control, leadFunction(...))
				end
			end)
		end

		local LeadPassthrough = function( antiquityId )
			return antiquityId
		end

		TooltipHook(AntiquityTooltip, "SetAntiquityLead", LeadPassthrough)
		TooltipHook(AntiquityTooltip, "SetAntiquitySetFragment", LeadPassthrough)
		TooltipHook(ItemTooltip, "SetStoreItem", GetStoreEntryAntiquityId)
		TooltipHook(ItemTooltip, "SetLootItem", GetLootAntiquityLeadId)
	end

	do -- Treasure Maps
		local TooltipHook = function( control, functionName, linkFunction )
			ZO_PostHook(control, functionName, function( self, ... )
				if (LootLog.vars.antiquityEnabled) then
					LootLog.AddTreasureMapTooltipExtension(control, linkFunction(...))
				end
			end)
		end

		local ItemLinkPassthrough = function( itemLink )
			return itemLink
		end

		TooltipHook(PopupTooltip, "SetLink", ItemLinkPassthrough)
		TooltipHook(ItemTooltip, "SetLink", ItemLinkPassthrough)
		TooltipHook(ItemTooltip, "SetBagItem", GetItemLink)
		TooltipHook(ItemTooltip, "SetTradeItem", GetTradeItemLink)
		TooltipHook(ItemTooltip, "SetBuybackItem", GetBuybackItemLink)
		TooltipHook(ItemTooltip, "SetStoreItem", GetStoreItemLink)
		TooltipHook(ItemTooltip, "SetAttachedMailItem", GetAttachedItemLink)
		TooltipHook(ItemTooltip, "SetLootItem", GetLootItemLink)
		TooltipHook(ItemTooltip, "SetReward", GetItemRewardItemLink)
		TooltipHook(ItemTooltip, "SetQuestReward", GetQuestRewardItemLink)
		TooltipHook(ItemTooltip, "SetTradingHouseItem", GetTradingHouseSearchResultItemLink)
		TooltipHook(ItemTooltip, "SetTradingHouseListing", GetTradingHouseListingItemLink)
	end
end

LCCC.RunAfterInitialLoadscreen(LootLog.HookAntiquityTooltips)
