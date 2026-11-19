local MCH = MonsterCofferHelper

local Settings = {}
MCH.Settings = Settings

Settings.PANEL_ID = "MonsterCofferHelper_Options"

-- Anything that changes the odds invalidates the cached pools, then redraws the
-- panel if it happens to be open, so the numbers never lag behind the setting.
local function Recalculate()
    MCH.Model.Invalidate()
    MCH.UI.Refresh()
end

function Settings.Initialize()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local db, defaults = MCH.db, MCH.defaults

    Settings.panel = LAM:RegisterAddonPanel(Settings.PANEL_ID, {
        type        = "panel",
        name        = GetString(SI_MCH_TITLE),
        displayName = GetString(SI_MCH_TITLE),
        author      = "mounir",
        version     = MCH.version,
        slashCommand = "/cofferconfig",
        registerForRefresh  = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls(Settings.PANEL_ID, {
        { type = "header", name = GetString(SI_MCH_SET_DISPLAY) },
        {
            type = "checkbox",
            name = GetString(SI_MCH_SET_PANEL),
            tooltip = GetString(SI_MCH_SET_PANEL_TT),
            getFunc = function() return db.showPanel end,
            setFunc = function(value) db.showPanel = value end,
            default = defaults.showPanel,
        },
        {
            type = "checkbox",
            name = GetString(SI_MCH_SET_CHAT),
            tooltip = GetString(SI_MCH_SET_CHAT_TT),
            getFunc = function() return db.chatMessage end,
            setFunc = function(value) db.chatMessage = value end,
            default = defaults.chatMessage,
        },
        {
            type = "checkbox",
            name = GetString(SI_MCH_SET_TOOLTIPS),
            tooltip = GetString(SI_MCH_SET_TOOLTIPS_TT),
            getFunc = function() return db.tooltips end,
            setFunc = function(value) db.tooltips = value end,
            default = defaults.tooltips,
        },
        {
            type = "checkbox",
            name = GetString(SI_MCH_SET_LOCK),
            getFunc = function() return db.lockPanel end,
            setFunc = function(value)
                db.lockPanel = value
                MCH.UI.SetLocked(value)
            end,
            default = defaults.lockPanel,
        },
        {
            type = "button",
            name = GetString(SI_MCH_SET_RESET_POS),
            func = function() MCH.UI.ResetPosition() end,
        },
        {
            type = "slider",
            name = GetString(SI_MCH_SET_MAXSETS),
            tooltip = GetString(SI_MCH_SET_MAXSETS_TT),
            min = 1, max = 15, step = 1,
            getFunc = function() return db.maxSetsListed end,
            setFunc = function(value)
                db.maxSetsListed = value
                MCH.UI.Refresh()
            end,
            default = defaults.maxSetsListed,
        },

        { type = "header", name = GetString(SI_MCH_SET_PRICES) },
        {
            type = "checkbox",
            name = GetString(SI_MCH_SET_LEARN),
            tooltip = GetString(SI_MCH_SET_LEARN_TT),
            getFunc = function() return db.useLearnedPrices end,
            setFunc = function(value)
                db.useLearnedPrices = value
                Recalculate()
            end,
            default = defaults.useLearnedPrices,
        },
        {
            type = "slider",
            name = GetString(SI_MCH_SET_MCOST),
            tooltip = GetString(SI_MCH_SET_COST_TT),
            min = 1, max = 25, step = 1,
            getFunc = function() return db.mysteryCost end,
            setFunc = function(value)
                db.mysteryCost = value
                Recalculate()
            end,
            default = defaults.mysteryCost,
        },
        {
            type = "slider",
            name = GetString(SI_MCH_SET_CCOST),
            tooltip = GetString(SI_MCH_SET_COST_TT),
            min = 1, max = 50, step = 1,
            getFunc = function() return db.curatedCost end,
            setFunc = function(value)
                db.curatedCost = value
                Recalculate()
            end,
            default = defaults.curatedCost,
        },

        { type = "header", name = GetString(SI_MCH_SET_POOL) },
        {
            type = "checkbox",
            name = GetString(SI_MCH_SET_LEARNPOOL),
            tooltip = GetString(SI_MCH_SET_LEARNPOOL_TT),
            getFunc = function() return db.useLearnedPools end,
            setFunc = function(value)
                db.useLearnedPools = value
                Recalculate()
            end,
            default = defaults.useLearnedPools,
        },
        {
            type = "button",
            name = GetString(SI_MCH_SET_FORGET),
            warning = GetString(SI_MCH_SET_LEARNPOOL_TT),
            func = function()
                MCH.ForgetLearned()
                Recalculate()
            end,
        },
    })
end

function Settings.Open()
    if LibAddonMenu2 and Settings.panel then
        LibAddonMenu2:OpenToPanel(Settings.panel)
    end
end
