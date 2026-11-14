NGear = NGear or {}

local GamepadOptions = NGear.GamepadOptions
local PanelIds = GamepadOptions.PanelIds
local ROOT_PANEL_ID = PanelIds.ROOT

local function Resolve(value)
    if type(value) == "function" then return value() end
    return value
end

local function BuildEntry(panelId, settingId, label, tooltip, callback)
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = settingId,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = label,
        gamepadTextOverride = label,
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, Resolve(tooltip))
        end,
        callback = callback or function() GamepadOptions.ShowPanel(panelId) end,
    }
end

function GamepadOptions.BuildItemLocatorEntry()
    return BuildEntry(
        PanelIds.ITEM_LOCATOR,
        11,
        NGear.L("ui.navigation.item_locator"),
        NGear.ItemLocator.GetRosterTooltip
    )
end

function GamepadOptions.BuildScanItemsOption()
    return GamepadOptions.BuildCheckboxOption(
        ROOT_PANEL_ID,
        12,
        NGear.L("ui.navigation.scan_items"),
        NGear.L("ui.navigation.scan_items_tooltip"),
        NGear.ItemLocator.IsEnabled,
        NGear.ItemLocator.SetEnabled,
        nil,
        false
    )
end

function GamepadOptions.BuildItemCategoriesEntry()
    return BuildEntry(
        PanelIds.ITEM_CATEGORIES,
        13,
        NGear.L("ui.navigation.item_categories"),
        NGear.L("ui.navigation.item_categories_tooltip"),
        GamepadOptions.ShowItemCategoriesPanel
    )
end

function GamepadOptions.BuildStickerBookEntry()
    return BuildEntry(
        PanelIds.STICKER_BOOK,
        1,
        NGear.L("ui.navigation.sticker_book"),
        NGear.L("ui.navigation.sticker_book_tooltip")
    )
end

function GamepadOptions.BuildLanguageOption()
    local lexicon = NGear.Lexicon
    local automatic = lexicon.GetLanguagePreferenceDefault()
    local optionData = GamepadOptions.BuildFiniteListOption(
        ROOT_PANEL_ID,
        15,
        NGear.L("settings.language.label"),
        NGear.L("settings.language.tooltip"),
        lexicon.GetLanguageChoices(),
        lexicon.GetLanguageChoiceNames(),
        GamepadOptions.GetSelectedLanguagePreference,
        GamepadOptions.SelectLanguagePreference,
        automatic
    )
    optionData.customResetToDefaultsFunction = function()
        GamepadOptions.SelectLanguagePreference(automatic)
        GamepadOptions.RefreshCurrentOptionsList()
    end
    return optionData
end

function GamepadOptions.BuildRootOptionsData()
    return {
        GamepadOptions.BuildScanItemsOption(),
        GamepadOptions.BuildItemLocatorEntry(),
        GamepadOptions.BuildItemCategoriesEntry(),
        GamepadOptions.BuildStickerBookEntry(),
        GamepadOptions.AddHeader(
            GamepadOptions.BuildLanguageOption(),
            NGear.L("ui.headers.global_options")
        ),
    }
end
