-- Extra TTC Tooltips
--
-- TamrielTradeCentre already hooks price info onto most tooltips (bag items,
-- bank, trade, stores, crafting stations, etc.) but misses two furniture
-- tooltip paths that don't go through the controls/functions it hooks:
--
--   1) The Housing Editor's furniture "Retrieve" list (pulling placed
--      furniture back into your bag). Its row tooltip calls
--      ItemTooltip:SetPlacedFurniture(id), which TTC's Init() never hooks -
--      it only hooks ItemTooltip:SetBagItem (used by the "Place" tab).
--
--   2) CharacterKnowledge's furniture/recipe/motif browser. It renders
--      tooltips through LibExtendedJournal's own tooltip control
--      (ExtendedJournalItemTooltip), a separate control instance from the
--      base game's ItemTooltip/PopupTooltip that TTC (and CK's own generic
--      tooltip hook) target - so neither of them ever sees these tooltips.
--
-- Both hooks below fire once per tooltip shown (same as TTC's own hooks),
-- not precomputed across a whole list - so this is just as cheap against
-- CK's 3000+-entry browser as it is against a normal bag.
--
-- Designed to be easy to extend: add more hooks that call AppendTTCPrice
-- below as more gaps turn up, each gated by its own savedVars toggle.

local savedVars
local DEFAULT_SETTINGS = {
	housingRetrieval = true,
	characterKnowledge = true,
}

local function AppendTTCPrice(control, itemLink)
	if not itemLink or itemLink == "" then
		return
	end
	if not TamrielTradeCentre or not TamrielTradeCentre.Settings or not TamrielTradeCentre.Settings.EnableItemToolTipPricing then
		return
	end
	if not TamrielTradeCentrePrice or not TamrielTradeCentrePrice.AppendPriceInfo then
		return
	end
	TamrielTradeCentrePrice:AppendPriceInfo(control, itemLink)
end

-- 1) Housing Editor furniture retrieval list ("Retrieve" tab).
ZO_PostHook(ItemTooltip, "SetPlacedFurniture", function(self, placedFurnitureId)
	if savedVars and savedVars.housingRetrieval == false then
		return
	end
	local itemLink = GetPlacedFurnitureLink(placedFurnitureId)
	AppendTTCPrice(self, itemLink)
end)

-- 2) CharacterKnowledge's furniture/recipe/motif browser (LibExtendedJournal's
-- tooltip control). Both CharacterKnowledge and LibExtendedJournal are
-- optional dependencies, so guard on the control actually existing - the
-- OptionalDependsOn below guarantees we load after them when present, so
-- this check only ever fails when CK/LEJ genuinely aren't installed.
if ExtendedJournalItemTooltip then
	ZO_PostHook(ExtendedJournalItemTooltip, "SetLink", function(self, itemLink)
		if savedVars and savedVars.characterKnowledge == false then
			return
		end
		AppendTTCPrice(self, itemLink)
	end)
end

EVENT_MANAGER:RegisterForEvent("ExtraTTCTooltips", EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
	if addOnName ~= "ExtraTTCTooltips" then return end
	EVENT_MANAGER:UnregisterForEvent("ExtraTTCTooltips", EVENT_ADD_ON_LOADED)

	savedVars = ZO_SavedVars:NewAccountWide("ExtraTTCTooltipsSavedVars", 1, nil, DEFAULT_SETTINGS)

	if LibAddonMenu2 then
		local panelData = {
			type = "panel",
			name = "Extra TTC Tooltips",
			displayName = "Extra TTC Tooltips",
			author = "Schrodi",
			version = "1.1",
			registerForRefresh = true,
			registerForDefaults = true,
		}
		LibAddonMenu2:RegisterAddonPanel("ExtraTTCTooltipsOptions", panelData)

		local optionsData = {
			{
				type = "checkbox",
				name = "Housing Editor retrieval list",
				tooltip = "Show TTC prices on the Housing Editor's furniture retrieval (\"Retrieve\") list.",
				default = true,
				getFunc = function() return savedVars.housingRetrieval end,
				setFunc = function(value) savedVars.housingRetrieval = value end,
			},
			{
				type = "checkbox",
				name = "CharacterKnowledge browser",
				tooltip = "Show TTC prices in CharacterKnowledge's furniture/recipe/motif browser.",
				default = true,
				getFunc = function() return savedVars.characterKnowledge end,
				setFunc = function(value) savedVars.characterKnowledge = value end,
			},
		}
		LibAddonMenu2:RegisterOptionControls("ExtraTTCTooltipsOptions", optionsData)
	end
end)
