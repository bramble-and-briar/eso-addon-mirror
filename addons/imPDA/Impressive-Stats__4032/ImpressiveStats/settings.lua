local LAM = LibAddonMenu2

local settings = {}

--#region COPY OLD DATA TO NEW ADDON
--[[
local dataMapping = {
    ['ImpPvPMeterSV'] = 'ImpressiveStatsSV',
    ['ImpPvPMeterCSV'] = 'ImpressiveStatsCSV',
    ['PvPMeterBattlegroundsData'] = 'ImpressiveStatsMatchesData',
    -- ['ImpPvPMeterMatchBackup'] = 'ImpressiveStatsMatchBackup',
    ['PvPMeterDuelsData'] = 'ImpressiveStatsDuelsData',
    ['PvPMeterTOTData'] = 'ImpressiveStatsTributeData',
}
local function IsDataFromImpPvPMeterAvailable()
    for oldName, _ in pairs(dataMapping) do
        if _G[oldName] ~= nil then return true end
    end
end

local function CopyDataFromImpPvPMeter()
    for oldSV, newSV in pairs(dataMapping) do
        _G[newSV] = _G[oldSV]
        _G[oldSV] = nil
    end
    ReloadUI()
end
--]]
--#endregion

-- TODO: remove this workaround
local function rgbToHex(r, g, b)
    return string.format('%02X%02X%02X', math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function hexToRGB(hex)
    local r = tonumber('0x'..hex:sub(1,2))
    local g = tonumber('0x'..hex:sub(3,4))
    local b = tonumber('0x'..hex:sub(5,6))
    return r / 255, g / 255, b / 255
end

function settings:Initialize(addon)
    local settingsName = addon.name .. 'Settings'
    local settingsDisplayName = addon.displayName
    local addonVersion = addon.addonVersion
    local sv = addon.sv

    local panelData = {
        type = 'panel',
        name = settingsDisplayName,
        author = '@impda',
        website = 'https://www.esoui.com/downloads/info4032-ImpressiveStats.html',
        version = addonVersion,
    }

    local panel = LAM:RegisterAddonPanel(settingsName, panelData)

    local errorsSV = sv.errors
    local err = {}  -- errors module
    err[#err+1] = {
        type = 'checkbox',
        name = 'Enable errors module',
        getFunc = function() return errorsSV.enabled end,
        setFunc = function(value) errorsSV.enabled = value end,
        requiresReload = true,
    }

    err[#err+1] = {
        type = 'checkbox',
        name = 'Allow center screen announcements',
        tooltip = 'Alert in the middle of the screen',
        getFunc = function() return errorsSV.allowCSA end,
        setFunc = function(value) errorsSV.allowCSA = value end,
    }

    err[#err+1] = {
        type = 'checkbox',
        name = 'Allow alerts',
        tooltip = 'Alert in the topright corner',
        getFunc = function() return errorsSV.allowAlerts end,
        setFunc = function(value) errorsSV.allowAlerts = value end,
    }

    local bm = {}  -- battlegroundsModule

    bm[#bm+1] = {
        type = 'checkbox',
        name = 'Enable',
        getFunc = function() return sv.battlegrounds.enabled end,
        setFunc = function(value) sv.battlegrounds.enabled = value end,
        requiresReload = true,
    }

    -- {
    --     type = 'checkbox',
    --     name = '[EXPERIMENTAL]Show only U45 matches',
    --     getFunc = function() return sv.battlegrounds.showOnlyLastUpdateMatches end,
    --     setFunc = function(value) sv.battlegrounds.showOnlyLastUpdateMatches = value end,
    --     requiresReload = true,
    --     reference = 'IMP_MATCHES_ShowOnlyLastUpdateMatchesCheckbox',
    -- }

    bm[#bm+1] = {
        type = 'checkbox',
        name = 'Save build at the end of match',
        getFunc = function() return sv.battlegrounds.saveBuilds end,
        setFunc = function(value) sv.battlegrounds.saveBuilds = value end,
    }

    bm[#bm+1] = {
        type = 'checkbox',
        name = 'Calculate stats over last 150 matches',
        getFunc = function() return sv.battlegrounds.last150 end,
        setFunc = function(value)
            sv.battlegrounds.last150 = value
            IMP_STATS_MATCHES_UI:Update()
        end,
    }

    bm[#bm+1] = {
        type = 'button',
        name = 'Delete matches data',
        func = function()
            ImpressiveStatsMatchesData = {}
            ReloadUI()
        end,
        width = 'full',
        isDangerous = true,
        warning = 'Тhis is |cee0000DESTRUCTIVE|r action and it will DELETE ALL DATA (and for both EU and NA servers) about BATTLEGROUND MATCHES recorded. There would be |cee0000NO WAY TO RECOVER|r it!\n\n|c00aa00Please consider saving it before, you can help to gather statistics by sending this file to me :)|r\n\nProceed only if you 100% sure about it!\n\nUI will be automatically reloaded.',
    }

    if sv.battlegrounds.debugging ~= nil or HashString(GetUnitDisplayName('player')) == 1558608849 then
        bm[#bm+1] = {
            type = 'checkbox',
            name = '|cFFA500Debug mode|r',
            getFunc = function() return sv.battlegrounds.debugging end,
            setFunc = function(value) sv.battlegrounds.debugging = value end,
            tooltip = 'Turns character filter off',
            requiresReload = true,
        }
    end

    bm[#bm+1] = {
        type = 'button',
        name = '|cFFA500Repack Saved Variables|r',
        func = function()
            IMP_STATS_MATCHES_MANAGER:RepackMatches()
        end,
        tooltip = function()
            local text = 'Will attempt to repack Saved Variables to make them smaller and increase performance.\n\nThere are %d saved matches total, it can take some time!'
            text = text:format(#IMP_STATS_MATCHES_MANAGER.savedMatches)

            return text
        end,
        -- disabled = function() return not IMP_STATS_MATCHES_MANAGER.unpackedSavedMatches end,
        requiresReload = true,
        reference = IMP_STATS_REPACK_BUTTON_REFERENCE
    }

    -- ImpressiveStatsPlayersSV

    local categories = ImpressiveStatsPlayersSV.categories

    bm[#bm+1] = {
        type = 'divider',
        height = 8,
        alpha = 0.5,
    }

    for ci = 1, #categories do
        bm[#bm+1] = {
            type = 'editbox',
            name = ('Category %d name'):format(ci),
            getFunc = function() return categories[ci].name end,
            setFunc = function(text) categories[ci].name = text end,
            isMultiline = false,
            width = 'half',
        }

        bm[#bm+1] = {
            type = 'colorpicker',
            name = ('Category %d color'):format(ci),
            getFunc = function() return hexToRGB(categories[ci].color) end,
            setFunc = function(r, g, b, a) categories[ci].color = rgbToHex(r, g, b) end,
            width = 'half',
        }
    end

    local duelsModule = {
        {
            type = 'checkbox',
            name = 'Enable',
            getFunc = function() return sv.duels.enabled end,
            setFunc = function(value) sv.duels.enabled = value end,
            requiresReload = true,
        },
        {
            type = 'dropdown',
            name = 'Naming options',
            tooltip = 'How to display names',
            choices = {
                'Character Name',
                '@id',
                '@id (Character Name)'
            },
            choicesValues = {
                1, 2, 3
            },
            getFunc = function() return sv.duels.namingMode end,
            setFunc = function(var) sv.duels.namingMode = var end,
            width = 'full',
            requiresReload = true,
            -- warning = 'Will need to reload the UI.',	--(optional)
        },
        {
            type = 'checkbox',
            name = 'Save build at the end of duel',
            getFunc = function() return sv.duels.saveBuilds end,
            setFunc = function(value) sv.duels.saveBuilds = value end,
        },
        {
            type = 'button',
            name = 'Delete duels data',
            func = function()
                ImpressiveStatsDuelsData = {}
                ReloadUI()
            end,
            width = 'full',
            isDangerous = true,
            warning = 'Тhis is |cee0000DESTRUCTIVE|r action and it will DELETE ALL DATA (and for both EU and NA servers) about DUELS recorded. There would be |cee0000NO WAY TO RECOVER|r it!\n\nProceed only if you 100% sure about it!\n\nUI will be automatically reloaded.',
        },
    }

    if sv.duels.debugging ~= nil or HashString(GetUnitDisplayName('player')) == 1558608849 then
        duelsModule[#duelsModule+1] = {
            type = 'checkbox',
            name = '|cFFA500Debug mode|r',
            getFunc = function() return sv.duels.debugging end,
            setFunc = function(value)
                sv.duels.debugging = value
                IMP_STATS_Duels_UI.debugging = value
                IMP_STATS_Duels_UI:UpdateUI()
            end,
            -- requiresReload = true,
        }
    end

    local tributeModule = {
        {
            type = 'checkbox',
            name = 'Enable',
            getFunc = function() return sv.tot.enabled end,
            setFunc = function(value) sv.tot.enabled = value end,
            requiresReload = true,
        },
        {
            type = 'checkbox',
            name = '[EXPERIMENTAL]Add leaderboard',
            getFunc = function() return sv.tot.leaderboard end,
            setFunc = function(value) sv.tot.leaderboard = value end,
            requiresReload = true,
        },
    }

    local optionsData = {
        {
            type = 'submenu',
            name = 'Errors module',
            tooltip = 'Everything about error notifications',
            controls = err,
        },
        {
            type = 'submenu',
            name = 'Battlegrounds module',
            tooltip = 'This is the tab for battlegrounds panel',
            controls = bm,
        },
        {
            type = 'submenu',
            name = 'Duels module',
            tooltip = 'For braviest',
            controls = duelsModule,
        },
        {
            type = 'submenu',
            name = 'Tribute module',
            tooltip = 'That is real PvP, no doubts allowed!',
            controls = tributeModule,
        },
        --[[
        {
            type = 'button',
            name = 'Copy from ImpPvPMeter',
            tooltip = 'For testers! It will make a full copy of saved data.',
            func = CopyDataFromImpPvPMeter,
            width = 'full',
            warning = 'ALL DATA WILL BE IRREVERSIBLY REPLACED\n\nUse it only ONCE and BEFORE any new bgs/duels/tribute games.\n\nUI will be automatically reloaded.',
            isDangerous	= true,
            disabled = function() return not IsDataFromImpPvPMeterAvailable() end,
        },
        --]]
    }

    LAM:RegisterOptionControls(settingsName, optionsData)
end

function IMP_STATS_InitializeSettings(...)
    settings:Initialize(...)
end