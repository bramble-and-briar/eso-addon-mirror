local C = (ASJ and ASJ.Config) or {
	NAME_SHORT = "ASJ"
}
local addon = ASJ
local LAM = LibAddonMenu2
if not LAM then return end

local defaults = addon.defaults
local sv = addon.savedVars

local panelData = {
	type = "panel",
	name = addon.addOnDisplayName or addon.addOnName,
	author = addon.author or "",
	version = addon.version or ""
}

--[[
diffColor = '|c00FF00' -- green
elseif data.Diff == 2 then
	diffColor = '|c0080FF' -- blue
elseif data.Diff == 3 then
	diffColor = '|c8000FF' -- purple
elseif data.Diff == 4 then
	diffColor = '|cFFD700' -- gold
]]

local textOptions = {
	{
		label = "Disabled",
		value = -1
	},
	{
		label = "White",
		value = 1
	},
	{
		label = "|c00FF00Green",
		value = 2
	},
	{
		label = "|c0080FFBlue",
		value = 3
	},
	{
		label = "|c8000FFPurple",
		value = 4
	},
	{
		label = "|cFFD700Gold",
		value = 5
	},
	{
		label = "All",
		value = 99
	}
}

local textChoices, textValues = {}, {}
for _, opt in ipairs(textOptions) do
	table.insert(textChoices, opt.label)
	table.insert(textValues, opt.value)
end

-- Helper to mark that a rescan is needed when panel closes
-- Dirty flag + panel close rescan removed per simplification; immediate changes rely on manual scan button.

local optionsData = {
	{
		type = "header",
		name = "General",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Auto sell junk to Store",
		tooltip = "If ON, automatically sells all items marked as junk when opening a store.",
		getFunc = function() return addon.savedVars.asjStore end,
		setFunc = function(v) addon.savedVars.asjStore = v end,
		default = defaults.asjStore
	},
	{
		type = "checkbox",
		name = "Auto mark trash as junk",
		tooltip = "Automatically marks all trash items as junk.",
		getFunc = function() return addon.savedVars.asjTrash end,
		setFunc = function(v) addon.savedVars.asjTrash = v end,
		default = defaults.asjTrash
	},
	{
		type = "checkbox",
		name = "Auto mark 'sell to merchant' as junk",
		tooltip = "Automatically marks all collectibles that can be sold to a merchant as junk.",
		getFunc = function() return addon.savedVars.asjMarkSellToMerchant end,
		setFunc = function(v) addon.savedVars.asjMarkSellToMerchant = v end,
		default = defaults.asjMarkSellToMerchant
	},
	{
		type = "checkbox",
		name = "Auto mark treasures as junk",
		tooltip = "Automatically marks all treasure items as junk.",
		getFunc = function() return addon.savedVars.asjTreasures end,
		setFunc = function(v) addon.savedVars.asjTreasures = v end,
		default = defaults.asjTreasures
	},
	{
		type = "checkbox",
		name = "Per item chat announcements",
		tooltip = "If ON, sends a chat message for each item marked as junk.",
		getFunc = function() return addon.savedVars.asjPerItemAnnouncements end,
		setFunc = function(v) addon.savedVars.asjPerItemAnnouncements = v end,
		default = defaults.asjPerItemAnnouncements
	},

	{
		type = "header",
		name = "Potions & Poisons",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Auto mark non-crafted potions/poisons as junk",
		tooltip = "If ON, automatically marks dropped (non player-crafted) potions and poisons as junk.",
		getFunc = function() return addon.savedVars.asjAutoMarkNonCraftedPotionsPoisons end,
		setFunc = function(v) addon.savedVars.asjAutoMarkNonCraftedPotionsPoisons = v end,
		default = defaults.asjAutoMarkNonCraftedPotionsPoisons
	},
	{
		type = "checkbox",
		name = "Exclude Bastian's Insight potions",
		tooltip = "If ON, keeps potions labeled Bastian's Insight from being auto-marked as junk (even if non-crafted).",
		getFunc = function() return addon.savedVars.asjExcludeBastiansInsight end,
		setFunc = function(v) addon.savedVars.asjExcludeBastiansInsight = v end,
		default = defaults.asjExcludeBastiansInsight
	},

	{
		type = "header",
		name = "Quality Thresholds",
		width = "full"
	},
	{
		type = "dropdown",
		name = "Automark Glyphs quality threshold",
		tooltip = "Sets the quality threshold for automatically marking glyphs as junk. All glyphs at or below the selected quality will be marked as junk.",
		choices = textChoices,
		choicesValues = textValues,
		getFunc = function() return addon.savedVars.asjGlyphQualityThreshold end,
		setFunc = function(v) addon.savedVars.asjGlyphQualityThreshold = v end,
		default = defaults.asjGlyphQualityThreshold
	},
	{
		type = "dropdown",
		name = "Automark Companion items quality threshold",
		tooltip = "Sets the quality threshold for automatically marking companion items as junk. All companion items at or below the selected quality will be marked as junk.",
		choices = textChoices,
		choicesValues = textValues,
		getFunc = function() return addon.savedVars.asjCompanionItemsQualityThreshold end,
		setFunc = function(v) addon.savedVars.asjCompanionItemsQualityThreshold = v end,
		default = defaults.asjCompanionItemsQualityThreshold
	},
	{
		type = "dropdown",
		name = "Automark apparel quality threshold",
		tooltip = "Sets the quality threshold for automatically marking apparel (armor, weapons, jewelry) as junk. All apparel at or below the selected quality will be marked as junk.",
		choices = textChoices,
		choicesValues = textValues,
		getFunc = function() return addon.savedVars.asjApparelQualityThreshold end,
		setFunc = function(v) addon.savedVars.asjApparelQualityThreshold = v end,
		default = defaults.asjApparelQualityThreshold
	},

	{
		type = "header",
		name = "Trait / Set Rules",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Include set items",
		tooltip = "If set to false, excludes set items from the automatic junk marking.",
		getFunc = function() return addon.savedVars.asjIncludingSets end,
		setFunc = function(v) addon.savedVars.asjIncludingSets = v end,
		default = defaults.asjIncludingSets
	},
	{
		type = "checkbox",
		name = "Include items with known traits",
		tooltip = "If set to false, excludes items with known traits from the automatic junk marking.",
		getFunc = function() return addon.savedVars.asjIncludingKnownTraits end,
		setFunc = function(v) addon.savedVars.asjIncludingKnownTraits = v end,
		default = defaults.asjIncludingKnownTraits
	},
	{
		type = "checkbox",
		name = "Include items with unknown traits",
		tooltip = "If set to false, excludes items with researchable traits from the automatic junk marking.",
		getFunc = function() return addon.savedVars.asjIncludingUnknownTraits end,
		setFunc = function(v) addon.savedVars.asjIncludingUnknownTraits = v end,
		default = defaults.asjIncludingUnknownTraits
	},
	{
		type = "checkbox",
		name = "Include rare/dear traits",
		tooltip = "If unchecked, protects items with valuable traits (Nirnhoned, Swift, Infused jewelry, Bloodthirsty, Harmony, Triune) from being auto-marked as junk, since they can be worth more by deconstructing.",
		getFunc = function() return addon.savedVars.asjIncludingRareTraits end,
		setFunc = function(v) addon.savedVars.asjIncludingRareTraits = v end,
		default = defaults.asjIncludingRareTraits
	},

	{
		type = "header",
		name = "Style & Deconstruction",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Include DLC style items",
		tooltip = "If unchecked, protects items in non-basic styles (any style not core racial/common) from being auto-marked as junk because of potential style material value.",
		getFunc = function() return addon.savedVars.asjIncludingDLCStyle end,
		setFunc = function(v) addon.savedVars.asjIncludingDLCStyle = v end,
		default = defaults.asjIncludingDLCStyle
	},

	{
		type = "header",
		name = "Ornate / Intricate",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Auto mark ornate as junk",
		tooltip = "Automatically marks all ornate items as junk.",
		getFunc = function() return addon.savedVars.asjOrnate end,
		setFunc = function(v) addon.savedVars.asjOrnate = v end,
		default = defaults.asjOrnate
	},
	{
		type = "checkbox",
		name = "Auto mark intricate as junk",
		tooltip = "If ON, automatically marks all intricate items as junk. If OFF, intricate items are protected and will not be marked as junk by other rules.",
		getFunc = function() return addon.savedVars.asjIntricate end,
		setFunc = function(v) addon.savedVars.asjIntricate = v end,
		default = defaults.asjIntricate
	},

	{
		type = "header",
		name = "Quest / Event Exclusions",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Include Clockwork City quest items",
		tooltip = "If set to false, excludes Clockwork City quest items from the automatic junk marking.\nThese include items for 'Nibbles and Bits', 'Morsels and Pecks', and the 'A Matter of ...' quest trio.",
		getFunc = function() return addon.savedVars.asjClockworkCity end,
		setFunc = function(v) addon.savedVars.asjClockworkCity = v end,
		default = defaults.asjClockworkCity
	},
	{
		type = "checkbox",
		name = "Include Thieves Guild quest items",
		tooltip = "If set to false, excludes Thieves Guild 'The Covetous Countess' quest items from the automatic junk marking.",
		getFunc = function() return addon.savedVars.asjThievesGuild end,
		setFunc = function(v) addon.savedVars.asjThievesGuild = v end,
		default = defaults.asjThievesGuild
	},
	{
		type = "checkbox",
		name = "Include Events quest items",
		tooltip = "If set to false, excludes Event quest items (rare fishes) from the automatic junk marking.",
		getFunc = function() return addon.savedVars.asjEvents end,
		setFunc = function(v) addon.savedVars.asjEvents = v end,
		default = defaults.asjEvents
	},

	{
		type = "header",
		name = "Scan & Apply",
		width = "full"
	},
	{
		type = "button",
		name = "Update inventory now",
		tooltip = "Apply changes to junk rules and update inventory now.",
		func = function() addon.StartDeferredScan(true) end
	}
}

function addon:CreateOptions()
	LAM:RegisterAddonPanel(addon.addOnName .. "Panel", panelData)
	LAM:RegisterOptionControls(addon.addOnName .. "Panel", optionsData)
end
