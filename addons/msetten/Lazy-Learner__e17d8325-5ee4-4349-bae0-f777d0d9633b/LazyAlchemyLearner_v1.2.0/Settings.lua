LazyLearner = LazyLearner or {}
LazyLearner.name = "LazyAlchemyLearner"
LazyLearner.version = "1.1.1"
LazyLearner.author = "Dolgubon (PC), msetten (Console), Mathinator (Contributing)"
LazyLearner.displayName = LazyLearner.L("LL_LAZY_LEARNER")
LazyLearner.selectedTraitOption = LAZY_LEARNER_ALCHEMY_BASE_GAME
LazyLearner.selectedRunesOption = LAZY_LEARNER_ENCHANTING_BASE_GAME
LazyLearner.includeKuta = false
LAZY_LEARNER_ALCHEMY_BASE_GAME = 1
LAZY_LEARNER_ALCHEMY_ALL_TRAITS = 2
LAZY_LEARNER_ENCHANTING_BASE_GAME = 1
LAZY_LEARNER_ENCHANTING_ALL_RUNES = 2
local Utils = LazyLearner.Utils
local EnchantingLearner = LazyLearner.EnchantingLearner
local AlchemyLearner = LazyLearner.AlchemyLearner

--- Creates the settings panel in the ESO interface add-on options.
function LazyLearner.setupPanel()
    local LAM = LibAddonMenu2
    local panelName = LazyLearner.name .. "OptionsPanel"

    local panelData = {
        type = "panel",
        name = LazyLearner.displayName,
        displayName = LazyLearner.displayName,
        author = LazyLearner.author,
        version = LazyLearner.version
    }

    local optionsTable = { {
        type = "button",
        name = LazyLearner.L("LL_CANCEL"),
        tooltip = LazyLearner.L("LL_CANCEL_TOOLTIP"),
        func = function()
            LazyLearner.LLC:cancelItem()
            Utils.sendChatMessage(LazyLearner.L("LL_QUEUE_CLEARED"))
        end
    }, {
        type = "divider",
        reference = "LazyLearnerQueueClearDivider"
    }, {
        type = "dropdown",
        name = LazyLearner.L("LL_TRAIT_SELECTION"),
        tooltip = LazyLearner.L("LL_CHOOSE_ALCHEMY_TRAITS"),
        choices = {LazyLearner.L("LL_BASE_GAME_TRAITS"), LazyLearner.L("LL_ALL_TRAITS")},
        choicesValues = {LAZY_LEARNER_ALCHEMY_BASE_GAME, LAZY_LEARNER_ALCHEMY_ALL_TRAITS},
        getFunc = function()
            return LazyLearner.selectedTraitOption or LAZY_LEARNER_ALCHEMY_BASE_GAME
        end,
        setFunc = function(value)
            LazyLearner.selectedTraitOption = value
        end,
        default = LAZY_LEARNER_ALCHEMY_BASE_GAME
    }, {
        type = "button",
        name = LazyLearner.L("LL_QUEUE_ALCHEMY"),
        tooltip = LazyLearner.L("LL_QUEUE_TRAITS"),
        func = function()
            LazyLearner.alchemyLearner(LazyLearner.selectedTraitOption == LAZY_LEARNER_ALCHEMY_ALL_TRAITS)
        end
    }, {
        type = "divider",
        reference = "LazyLearnerDivider2"
    }, {
        type = "dropdown",
        name = LazyLearner.L("LL_RUNES_SELECTION"),
        tooltip = string.format(LazyLearner.L("LL_CHOOSE_RUNES"), Utils.getItemLinkFromItemId(68342),
            Utils.getItemLinkFromItemId(166045)),
        choices = {LazyLearner.L("LL_BASE_GAME_RUNES"), LazyLearner.L("LL_ALL_RUNES")},
        choicesValues = {LAZY_LEARNER_ENCHANTING_BASE_GAME, LAZY_LEARNER_ENCHANTING_ALL_RUNES},
        getFunc = function()
            return LazyLearner.selectedRunesOption or LAZY_LEARNER_ENCHANTING_BASE_GAME
        end,
        setFunc = function(value)
            LazyLearner.selectedRunesOption = value
        end,
        default = LAZY_LEARNER_ENCHANTING_BASE_GAME
    }, {
        type = "checkbox",
        name = LazyLearner.L("LL_INCLUDE_KUTA"),
        tooltip = LazyLearner.L("LL_LEARN_KUTA"),
        getFunc = function()
            return LazyLearner.includeKuta
        end,
        setFunc = function(value)
            LazyLearner.includeKuta = value
        end
    }, {
        type = "button",
        name = LazyLearner.L("LL_QUEUE_ENCHANTING"),
        tooltip = LazyLearner.L("LL_QUEUE_RUNES"),
        func = function()
          LazyLearner.enchantingLearner(LazyLearner.selectedRunesOption == LAZY_LEARNER_ENCHANTING_ALL_RUNES, LazyLearner.includeKuta)
        end
    },  {
        type = "divider",
        reference = "LazyLearnerExtensiveReportingDivider"
    },{
        type = "checkbox",
        name = LazyLearner.L("LL_EXTENSIVE_REPORTING"),
        tooltip = LazyLearner.L("LL_ENABLE_DETAILED_REPORTING"),
        getFunc = function()
            return LazyLearner.savedVars and LazyLearner.savedVars.extensiveReporting or false
        end,
        setFunc = function(value)
            if LazyLearner.savedVars then
                LazyLearner.savedVars.extensiveReporting = value
            end
        end,
        default = false
    }, {
        type = "colorpicker",
        name = LazyLearner.L("LL_MESSAGE_COLOR"),
        tooltip = LazyLearner.L("LL_CHOOSE_MESSAGE_COLOR"),
        getFunc = function()
            return LazyLearner.savedVars.msgcolor.r, LazyLearner.savedVars.msgcolor.g, LazyLearner.savedVars.msgcolor.b
        end,
        setFunc = function(r, g, b, a)
            LazyLearner.savedVars.msgcolor.r = r
            LazyLearner.savedVars.msgcolor.g = g
            LazyLearner.savedVars.msgcolor.b = b
        end,
        default = LazyLearner.defaults.msgcolor,
        width = "half"
    }, {
        type = "colorpicker",
        name = LazyLearner.L("LL_WARNING_COLOR"),
        tooltip = LazyLearner.L("LL_CHOOSE_WARNING_COLOR"),
        getFunc = function()
            return LazyLearner.savedVars.warningColor.r, LazyLearner.savedVars.warningColor.g,
                LazyLearner.savedVars.warningColor.b
        end,
        setFunc = function(r, g, b, a)
            LazyLearner.savedVars.warningColor.r = r
            LazyLearner.savedVars.warningColor.g = g
            LazyLearner.savedVars.warningColor.b = b
        end,
        default = LazyLearner.defaults.warningColor,
        width = "half"
    }, }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsTable)
end
