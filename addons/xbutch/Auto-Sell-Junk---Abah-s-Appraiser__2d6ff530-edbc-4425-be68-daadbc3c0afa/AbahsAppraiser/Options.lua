local C = (ASJ and ASJ.Config) or {
	NAME_SHORT = "ASJ"
}
local addon = ASJ
local LAM = LibAddonMenu2
if not LAM then return end

local defaults = addon.defaults

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
		name = "Auto sell junk at stores",
		tooltip = "When enabled, automatically sells items currently marked as junk when a merchant opens.",
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
		name = "Per-item chat announcements",
		tooltip = "When enabled, sends a chat message for each item marked as junk outside bulk scans.",
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
		name = "Auto mark non-crafted potions and poisons as junk",
		tooltip = "When enabled, marks dropped non-player-crafted potions and poisons as junk.",
		getFunc = function() return addon.savedVars.asjAutoMarkNonCraftedPotionsPoisons end,
		setFunc = function(v) addon.savedVars.asjAutoMarkNonCraftedPotionsPoisons = v end,
		default = defaults.asjAutoMarkNonCraftedPotionsPoisons
	},
	{
		type = "checkbox",
		name = "Protect Bastian's Insight potions",
		tooltip = "When enabled, Bastian's Insight potions are never auto-marked as junk.",
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
		name = "Glyph auto-junk quality threshold",
		tooltip = "Sets the quality threshold for automatically marking glyphs as junk. All glyphs at or below the selected quality will be marked as junk.",
		choices = textChoices,
		choicesValues = textValues,
		getFunc = function() return addon.savedVars.asjGlyphQualityThreshold end,
		setFunc = function(v) addon.savedVars.asjGlyphQualityThreshold = v end,
		default = defaults.asjGlyphQualityThreshold
	},
	{
		type = "dropdown",
		name = "Companion gear auto-junk quality threshold",
		tooltip = "Sets the quality threshold for automatically marking companion items as junk. All companion items at or below the selected quality will be marked as junk.",
		choices = textChoices,
		choicesValues = textValues,
		getFunc = function() return addon.savedVars.asjCompanionItemsQualityThreshold end,
		setFunc = function(v) addon.savedVars.asjCompanionItemsQualityThreshold = v end,
		default = defaults.asjCompanionItemsQualityThreshold
	},
	{
		type = "dropdown",
		name = "Regular gear auto-junk quality threshold",
		tooltip = "Controls the generic armor/weapon/jewelry rule. Eligible regular gear at or below this quality may be marked as junk. Disabled turns off only this generic rule.",
		choices = textChoices,
		choicesValues = textValues,
		getFunc = function() return addon.savedVars.asjApparelQualityThreshold end,
		setFunc = function(v) addon.savedVars.asjApparelQualityThreshold = v end,
		default = defaults.asjApparelQualityThreshold
	},

	{
		type = "header",
		name = "Gear eligibility / protection",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Allow auto-junk for set items",
		tooltip = "When enabled, set gear may be auto-junked by applicable rules. When disabled, set gear is protected and no later auto-junk rule can override it.",
		getFunc = function() return addon.savedVars.asjIncludingSets end,
		setFunc = function(v) addon.savedVars.asjIncludingSets = v end,
		default = defaults.asjIncludingSets
	},
	{
		type = "checkbox",
		name = "Allow auto-junk for already-known traits",
		tooltip = "When enabled, regular gear with a trait this character no longer needs to research may be auto-junked if it also meets the regular gear quality threshold.",
		getFunc = function() return addon.savedVars.asjIncludingKnownTraits end,
		setFunc = function(v) addon.savedVars.asjIncludingKnownTraits = v end,
		default = defaults.asjIncludingKnownTraits
	},
	{
		type = "checkbox",
		name = "Allow auto-junk for researchable traits",
		tooltip = "When enabled, regular gear whose trait can still be researched may be auto-junked if it also meets the regular gear quality threshold.",
		getFunc = function() return addon.savedVars.asjIncludingUnknownTraits end,
		setFunc = function(v) addon.savedVars.asjIncludingUnknownTraits = v end,
		default = defaults.asjIncludingUnknownTraits
	},
	{
		type = "checkbox",
		name = "Allow auto-junk for valuable traits",
		tooltip = "When disabled, gear with Nirnhoned or valuable jewelry traits (Swift, Infused, Bloodthirsty, Harmony, Triune) is protected and no later auto-junk rule can override it.",
		getFunc = function() return addon.savedVars.asjIncludingRareTraits end,
		setFunc = function(v) addon.savedVars.asjIncludingRareTraits = v end,
		default = defaults.asjIncludingRareTraits
	},

	{
		type = "header",
		name = "Style protection",
		width = "full"
	},
	{
		type = "checkbox",
		name = "Allow auto-junk for non-basic styles",
		tooltip = "When disabled, gear in non-basic styles (for example Primal) is protected for its style material value. Core racial styles and Imperial are treated as basic.",
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
		tooltip = "When enabled, marks ornate gear as junk unless an active protection rule (such as set or non-basic style protection) vetoes it.",
		getFunc = function() return addon.savedVars.asjOrnate end,
		setFunc = function(v) addon.savedVars.asjOrnate = v end,
		default = defaults.asjOrnate
	},
	{
		type = "checkbox",
		name = "Auto mark intricate as junk",
		tooltip = "When enabled, marks intricate gear as junk unless an active protection rule vetoes it. When disabled, intricate gear is protected.",
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
		name = "Allow auto-junk for Clockwork City quest items",
		tooltip = "When enabled, items used by Clockwork City quests may be auto-junked. This includes 'Nibbles and Bits', 'Morsels and Pecks', and the 'A Matter of ...' quest trio.",
		getFunc = function() return addon.savedVars.asjClockworkCity end,
		setFunc = function(v) addon.savedVars.asjClockworkCity = v end,
		default = defaults.asjClockworkCity
	},
	{
		type = "checkbox",
		name = "Allow auto-junk for The Covetous Countess items",
		tooltip = "When enabled, treasures useful for The Covetous Countess may be auto-junked.",
		getFunc = function() return addon.savedVars.asjThievesGuild end,
		setFunc = function(v) addon.savedVars.asjThievesGuild = v end,
		default = defaults.asjThievesGuild
	},
	{
		type = "checkbox",
		name = "Allow auto-junk for protected event items",
		tooltip = "When enabled, the protected event rare-fish items may be auto-junked.",
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
