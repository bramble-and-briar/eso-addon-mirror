--------------------------------------------------------------------
--  AutoInteract Settings.lua  –  v1.8.6  (April 01 2026)		      --
--------------------------------------------------------------------

AutoInteract = AutoInteract or {}
local SV = AutoInteract.SavedVariables

function AutoInteract.LoadLocalization()
local lang = GetCVar("Language.2") or "en"
local strings = AutoInteractStrings[lang] or AutoInteractStrings["en"]
for stringId, text in pairs(strings) do
ZO_CreateStringId(stringId, text)
end
end

function AutoInteract.InitSettings()
local LAM = LibAddonMenu2
if not LAM then
if not AutoInteract.IsConsole() then
d("[AutoInteract] LibAddonMenu2 not found. Settings menu will not be available.")
end
return
end

local panelName = "AutoInteractSettingsPanel"
local panelData = {
    type = "panel",
    name = AutoInteract.Name,
    displayName = AutoInteract.Name,
    version = AutoInteract.Version,
    author = "@SquidMeat",
    gamepad = true,
    enableScroll = true
}

local optionsData = {
    {
        type = "checkbox",
        name = SI_AUTOINTERACT_SKIP_DIALOGUES,
        tooltip = SI_AUTOINTERACT_SKIP_DIALOGUES_TOOLTIP,
        getFunc = function() return AutoInteract.SavedVariables.SkipDialogues end,
        setFunc = function(value) AutoInteract.SavedVariables.SkipDialogues = value end
    },
    {
        type = "checkbox",
        name = SI_AUTOINTERACT_SKIP_IMPORTANT,
        tooltip = SI_AUTOINTERACT_SKIP_IMPORTANT_TOOLTIP,
        getFunc = function() return AutoInteract.SavedVariables.SkipImportantChoices end,
        setFunc = function(value) AutoInteract.SavedVariables.SkipImportantChoices = value end
    },
    {
        type = "checkbox",
        name = SI_AUTOINTERACT_SKIP_BOOKS,
        tooltip = SI_AUTOINTERACT_SKIP_BOOKS_TOOLTIP,
        getFunc = function() return AutoInteract.SavedVariables.SkipBooks end,
        setFunc = function(value) AutoInteract.SavedVariables.SkipBooks = value end
    },
    {
        type = "checkbox",
        name = SI_AUTOINTERACT_USE_WRIT_DETECTION,
        tooltip = SI_AUTOINTERACT_USE_WRIT_DETECTION_TOOLTIP,
        getFunc = function() return AutoInteract.SavedVariables.UseWritDetection end,
        setFunc = function(value) AutoInteract.SavedVariables.UseWritDetection = value end,
        default = true,
    },
    {
        type = "checkbox",
        name = SI_AUTOINTERACT_USE_HARDMODE,
        tooltip = SI_AUTOINTERACT_USE_HARDMODE_TOOLTIP,
        getFunc = function() return AutoInteract.SavedVariables.UseHardModeDetection end,
        setFunc = function(value) AutoInteract.SavedVariables.UseHardModeDetection = value end,
        default = true,
    },
    {
        type = "checkbox",
        name = SI_AUTOINTERACT_USE_COST_DETECTION,
        tooltip = SI_AUTOINTERACT_USE_COST_DETECTION_TOOLTIP,
        getFunc = function() return AutoInteract.SavedVariables.UseCostDetection end,
        setFunc = function(value) AutoInteract.SavedVariables.UseCostDetection = value end,
        default = true,
    },
	{
		type    = "checkbox",
		name    = SI_AUTOINTERACT_AUTO_BIND_SETS,
		tooltip = SI_AUTOINTERACT_AUTO_BIND_SETS_TOOLTIP,
		getFunc = function() return AutoInteract.SavedVariables.AutoBindSetItems end,
		setFunc = function(v) AutoInteract.SavedVariables.AutoBindSetItems = v end,
		default = false,
	},
	{
		type    = "checkbox",
		name    = SI_AUTOINTERACT_AUTO_LEARN_COLLECTIBLES,
		tooltip = SI_AUTOINTERACT_AUTO_LEARN_COLLECTIBLES_TOOLTIP,
		getFunc = function() return AutoInteract.SavedVariables.AutoLearnCollectibles end,
		setFunc = function(v) AutoInteract.SavedVariables.AutoLearnCollectibles = v end,
		default = false,
	},
	{
		type    = "checkbox",
		name    = SI_AUTOINTERACT_AUTO_MARK_JUNK,
		tooltip = SI_AUTOINTERACT_AUTO_MARK_JUNK_TOOLTIP,
		getFunc = function() return AutoInteract.SavedVariables.AutoMarkJunkItems end,
		setFunc = function(v) AutoInteract.SavedVariables.AutoMarkJunkItems = v end,
		default = false,
	},
	{
		type    = "checkbox",
		name    = SI_AUTOINTERACT_AUTO_SELL_JUNK,
		tooltip = SI_AUTOINTERACT_AUTO_SELL_JUNK_TOOLTIP,
		getFunc = function() return AutoInteract.SavedVariables.AutoSellJunkOnMerchant end,
		setFunc = function(v) AutoInteract.SavedVariables.AutoSellJunkOnMerchant = v end,
		default = false,
	},
	{
        type = "checkbox",
        name = SI_AUTOINTERACT_DEBUG_MODE,
        tooltip = SI_AUTOINTERACT_DEBUG_MODE_TOOLTIP,
        getFunc = function() return AutoInteract.SavedVariables.DebugMode end,
        setFunc = function(value) AutoInteract.SavedVariables.DebugMode = value end
    },
    {
        type = "editbox",
        name = SI_AUTOINTERACT_BLACKLIST,
        tooltip = SI_AUTOINTERACT_BLACKLIST_TOOLTIP,
        getFunc = function() return table.concat(AutoInteract.SavedVariables.KeywordBlacklist or {}, "\n") end,
        setFunc = function(value)
            local list = {}
            for line in string.gmatch(value, "[^\r\n]+") do
                table.insert(list, line)
            end
            AutoInteract.SavedVariables.KeywordBlacklist = list
        end,
        isMultiline = true,
        width = "full",
        default = "writ\nauftrag\ncommande",
    },
}

if MyUI_RegisterExternalSection then MyUI_RegisterExternalSection(17, "AutoInteract", "17. AutoInteract", optionsData) end

end
