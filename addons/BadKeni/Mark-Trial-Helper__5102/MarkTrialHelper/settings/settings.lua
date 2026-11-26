local AH = _G.MarkTrialHelper

AH.LAM = _G.LibAddonMenu2

local panel = {
    type = "panel",
    name = "MarkTrialHelper",
    displayName = zo_iconFormat("/esoui/art/icons/poi/poi_endlessdungeon_complete.dds") .. " |cff9900Mark Trial Helper|r",
    author = "Mark Streltcov",
    version = AH.LC.GetAddonVersion(AH.Name),
    registerForRefresh = true
}
local favouriteChoices = {}
local favouriteChoiceValues = {}

local function doSort(tin, tout1, tout2)
    table.sort(
        tin,
        function(a, b)
            return a.name < b.name
        end
    )

    for _, choice in ipairs(tin) do
        table.insert(tout1, choice.name)
        table.insert(tout2, choice.id)
    end
end

do
    local tmpTable = {}

    for abilityId, _ in pairs(AH.ABILITIES) do
        local name = GetAbilityName(abilityId, "player")

        if (name and name ~= "") then
            table.insert(tmpTable, { id = abilityId, name = AH.LC.Format(name) })
        end
    end

    doSort(tmpTable, favouriteChoices, favouriteChoiceValues)
end

local removeChoices = {}
local removeChoiceValues = {}

local function populateRemovableOptions(doNotFill)
    local choices = AH.Vars.Favourites

    if (#choices == 0) then
        return {}
    end

    local tmpTable = {}

    for _, choice in ipairs(choices) do
        local name = GetAbilityName(choice, "player")
        local icon = GetAbilityIcon(choice)

        table.insert(tmpTable, { id = choice, name = AH.LC.Format(name), icon = icon })
    end

    if (not doNotFill) then
        doSort(tmpTable, removeChoices, removeChoiceValues)
    end

    return tmpTable
end

local function getFavourites()
    local removed = populateRemovableOptions(true)
    local text = ""

    if (#removed > 0) then
        table.sort(
            removed,
            function(a, b)
                return a.name < b.name
            end
        )

        for _, ability in ipairs(removed) do
            text = text .. zo_iconFormat(ability.icon, 24, 24)
            text = text .. " " .. ability.name .. AH.LF
        end
    end

    return text
end

local function updateFavourites()
    _G.MARKTRIALHELPER_FAVOURITES_LIST.data.text = getFavourites()
    _G.MARKTRIALHELPER_FAVOURITES_LIST:UpdateValue()
end

local removeIgnoreChoices = {}
local removeIgnoreChoiceValues = {}

local function populateRemovableIgnoreOptions(doNotFill)
    local choices = AH.Vars.Ignore

    if (#choices == 0) then
        return {}
    end

    local tmpTable = {}

    for _, choice in ipairs(choices) do
        local name = GetAbilityName(choice, "player")
        local icon = GetAbilityIcon(choice)

        table.insert(tmpTable, { id = choice, name = AH.LC.Format(name), icon = icon })
    end

    if (not doNotFill) then
        doSort(tmpTable, removeIgnoreChoices, removeIgnoreChoiceValues)
    end

    return tmpTable
end

local function getIgnore()
    local removed = populateRemovableIgnoreOptions()
    local text = ""

    if (#removed > 0) then
        table.sort(
            removed,
            function(a, b)
                return a.name < b.name
            end
        )

        for _, ability in ipairs(removed) do
            text = text .. zo_iconFormat(ability.icon, 24, 24)
            text = text .. " " .. ability.name .. AH.LF
        end
    end

    return text
end

local function updateIgnore()
    _G.MARKTRIALHELPER_IGNORE_LIST.data.text = getIgnore()
    _G.MARKTRIALHELPER_IGNORE_LIST:UpdateValue()
end

local function getSecondsOptions()
    local seconds = {}

    for sec = 20, 60, 5 do
        table.insert(seconds, sec)
    end

    return seconds
end

local function buildOptions()
    populateRemovableOptions()

    local optional = ""
    local yellow = AH.LC.Yellow

    if (not AH.Chat) then
        optional = yellow:Colorize(GetString(_G.MARKTRIALHELPER_OPTIONAL_LIBS_CHAT))
    end

    if false and (not _G.LibDataShare) then
        if (optional ~= "") then
            optional = optional .. AH.LF
        end

        optional = optional .. yellow:Colorize(GetString(_G.MARKTRIALHELPER_OPTIONAL_LIBS_SHARE))
    end

    local options = {
        [1] = {
            type = "description",
            text = optional,
            width = "full"
        },
        [2] = {
            type = "header",
            name = AH.LC.Format(SI_BINDING_NAME_TOGGLE_NOTIFICATIONS),
            width = "full"
        },
        [3] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_PROGRESS_ACHIEVEMENT),
            getFunc = function()
                return AH.Vars.Notify
            end,
            setFunc = function(value)
                AH.Vars.Notify = value
            end,
            width = "full"
        },
        [4] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_PROGRESS_CHAT),
            tooltip = AH.LC.Format(_G.MARKTRIALHELPER_REQUIRES),
            getFunc = function()
                return AH.Vars.NotifyChat
            end,
            setFunc = function(value)
                AH.Vars.NotifyChat = value
            end,
            disabled = function()
                return (not AH.Vars.Notify) or (not AH.Chat)
            end,
            width = "full"
        },
        [5] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_PROGRESS_SCREEN),
            getFunc = function()
                return AH.Vars.NotifyScreen
            end,
            setFunc = function(value)
                AH.Vars.NotifyScreen = value
            end,
            disabled = function()
                return not AH.Vars.Notify
            end,
            width = "full"
        },
        [6] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_SELECTION),
            tooltip = AH.LC.Format(_G.MARKTRIALHELPER_REQUIRES) ..
                ". " .. AH.LC.Format(_G.MARKTRIALHELPER_SHOW_COUNT_TOOLTIP),
            getFunc = function()
                return AH.Vars.ShowSelection
            end,
            setFunc = function(value)
                AH.Vars.ShowSelection = value
            end,
            disabled = function()
                return not AH.Chat
            end,
            width = "full"
        },
        [7] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_SELECTION_DISPLAY_NAME),
            tooltip = function()
                if (_G.MARKTRIALHELPER_SHOW_SELECTION_DISPLAY_NAME_TOOLTIP) then
                    return string.format(
                        "%s. %s",
                        AH.LC.Format(_G.MARKTRIALHELPER_SHOW_SELECTION_DISPLAY_NAME_TOOLTIP),
                        AH.LC.Format(_G.MARKTRIALHELPER_REQUIRES)
                    )
                else
                    return AH.LC.Format(_G.MARKTRIALHELPER_REQUIRES)
                end
            end,
            getFunc = function()
                return AH.Vars.UseDisplayName
            end,
            setFunc = function(value)
                AH.Vars.UseDisplayName = value
            end,
            disabled = function()
                return not AH.Chat or (not AH.Vars.ShowSelection)
            end,
            width = "full"
        },
        [8] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_TERRAIN_WARNING),
            tooltip = function()
                if (_G.MARKTRIALHELPER_SHOW_TERRAIN_WARNING_TOOLTIP) then
                    return AH.LC.Format(_G.MARKTRIALHELPER_SHOW_TERRAIN_WARNING_TOOLTIP)
                end
            end,
            getFunc = function()
                return AH.Vars.TerrainWarnings
            end,
            setFunc = function(value)
                AH.Vars.TerrainWarnings = value
                AH.SetTerrainWarnings(value)
            end
        },
        [9] = {
            type = "header",
            name = AH.LC.Format(SI_ITEMFILTERTYPE5),
            width = "full"
        },
        [10] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_REMINDER),
            tooltip = AH.LC.Format(_G.MARKTRIALHELPER_REMINDER_TOOLTIP),
            getFunc = function()
                return AH.Vars.ShowNotice
            end,
            setFunc = function(value)
                AH.Vars.ShowNotice = value
            end,
            width = "full"
        },
        [11] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_REMINDER_QUEST),
            getFunc = function()
                return AH.Vars.CheckQuestItems
            end,
            setFunc = function(value)
                AH.Vars.CheckQuestItems = value
            end,
            width = "full"
        },
        [12] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_PREVENT),
            tooltip = AH.LC.Format(_G.MARKTRIALHELPER_PREVENT_TOOLTIP),
            getFunc = function()
                return AH.Vars.PreventSelection
            end,
            setFunc = function(value)
                AH.Vars.PreventSelection = value
            end,
            width = "full"
        },
        [13] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_AUDITOR),
            getFunc = function()
                return AH.Vars.Auditor
            end,
            setFunc = function(value)
                AH.Vars.Auditor = value
            end,
            width = "full",
            disabled = function()
                return not IsCollectibleUnlocked(AH.AUDITOR)
            end
        },
        [14] = {
            type = "header",
            name = AH.LC.Format(_G.MARKTRIALHELPER_BONUS),
            width = "full"
        },
        [15] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_ECHO),
            getFunc = function()
                return AH.Vars.ShowTimer
            end,
            setFunc = function(value)
                AH.Vars.ShowTimer = value
            end,
            width = "full"
        },
        [16] = {
            type = "dropdown",
            name = string.format(
                "%s (%s)",
                AH.LC.Format(SI_ABILITY_TOOLTIP_DURATION_LABEL),
                AH.LC.Format(_G.MARKTRIALHELPER_SECONDS):lower()
            ),
            choices = getSecondsOptions(),
            getFunc = function()
                return AH.Vars.EchoingDenTimer
            end,
            setFunc = function(value)
                AH.Vars.EchoingDenTimer = value
            end,
            disabled = function()
                return not AH.Vars.ShowTimer
            end,
            width = "full"
        },
        [17] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_COUNT),
            tooltip = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_COUNT_TOOLTIP),
            getFunc = function()
                return AH.Vars.CountTomes
            end,
            setFunc = function(value)
                AH.Vars.CountTomes = value
            end,
            width = "full"
        },
        [18] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_CROSSING_HELPER),
            getFunc = function()
                return AH.Vars.ShowHelper
            end,
            setFunc = function(value)
                AH.Vars.ShowHelper = value
            end,
            width = "full"
        },
        [19] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHOW_THEATRE_WARNING),
            getFunc = function()
                return AH.Vars.Theatre
            end,
            setFunc = function(value)
                AH.Vars.Theatre = value
            end,
            width = "full"
        },
        [20] = {
            type = "header",
            name = AH.LC.Format(SI_INTERFACE_OPTIONS_NAMEPLATES_TARGET_MARKERS),
            width = "full"
        },
        [21] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_FABLED_MARKER),
            tooltip = function()
                if (not AH.CompatibilityCheck()) then
                    return AH.LC.Format(_G.MARKTRIALHELPER_FABLED_TOOLTIP)
                end
            end,
            getFunc = function()
                return AH.Vars.FabledCheck
            end,
            setFunc = function(value)
                AH.Vars.FabledCheck = value
            end,
            disabled = function()
                return not AH.CompatibilityCheck()
            end,
            width = "full"
        },
        [22] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHARD_MARKER),
            tooltip = function()
                if (not AH.CompatibilityCheck()) then
                    return AH.LC.Format(_G.MARKTRIALHELPER_FABLED_TOOLTIP)
                end
            end,
            getFunc = function()
                return AH.Vars.ShardCheck
            end,
            setFunc = function(value)
                AH.Vars.ShardCheck = value
            end,
            width = "full"
        },
        [23] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_SHARD_IGNORE),
            tooltip = function()
                if (not AH.CompatibilityCheck()) then
                    return AH.LC.Format(_G.MARKTRIALHELPER_FABLED_TOOLTIP)
                end
            end,
            getFunc = function()
                return AH.Vars.ShardIgnore or false
            end,
            setFunc = function(value)
                AH.Vars.ShardIgnore = value
            end,
            disabled = function()
                return not AH.Vars.ShardCheck
            end,
            width = "full"
        },
        [24] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_GW_MARKER),
            getFunc = function()
                return AH.Vars.GwCheck
            end,
            setFunc = function(value)
                AH.Vars.GwCheck = value
            end,
            width = "full"
        },
        [25] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_GW_PLAY),
            getFunc = function()
                return AH.Vars.GwPlay or false
            end,
            setFunc = function(value)
                AH.Vars.GwPlay = value
            end,
            disabled = function()
                return not AH.Vars.GwCheck
            end,
            width = "full"
        },
        [26] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_MARAUDER_MARKER) ..
                " " .. zo_iconFormat("/esoui/art/targetmarkers/target_white_skull_64.dds", 24, 24),
            getFunc = function()
                return AH.Vars.MarauderCheck
            end,
            setFunc = function(value)
                AH.Vars.MarauderCheck = value
            end,
            width = "full"
        },
        [27] = {
            type = "checkbox",
            name = AH.LC.Format(_G.MARKTRIALHELPER_MARAUDER_INCOMING_PLAY),
            getFunc = function()
                return AH.Vars.MarauderPlay or false
            end,
            setFunc = function(value)
                AH.Vars.MarauderPlay = value
            end,
            width = "full"
        }
    }

    options[#options + 1] = {
        type = "header",
        name = AH.LC.Format(SI_INTERFACE_OPTIONS_INDICATORS),
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = AH.LC.GetIconTexture(string.format("/esoui/art/%s.dds", AH.ICONS.ACH.name), AH.LC.Red, 24, 24) ..
            " " .. AH.LC.Format(SI_ZONECOMPLETIONTYPE3),
        getFunc = function()
            return AH.Vars.MarkAchievements
        end,
        setFunc = function(value)
            AH.Vars.MarkAchievements = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = zo_iconFormat(string.format("/esoui/art/%s.dds", AH.ICONS.WOLF.name), 24, 24) ..
            " " .. AH.LC.Format(SI_ENDLESS_DUNGEON_SUMMARY_AVATAR_VISIONS_HEADER),
        getFunc = function()
            return AH.Vars.MarkAvatar
        end,
        setFunc = function(value)
            AH.Vars.MarkAvatar = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = yellow:Colorize("(1)   ") .. AH.LC.Format(_G.MARKTRIALHELPER_STACKS),
        getFunc = function()
            return AH.Vars.ShowStacks
        end,
        setFunc = function(value)
            AH.Vars.ShowStacks = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = AH.LC.GetIconTexture(string.format("/esoui/art/%s.dds", AH.ICONS.FAV.name), AH.LC.Green, 24, 24) ..
            " " .. AH.LC.Format(SI_COLLECTIONS_FAVORITES_CATEGORY_HEADER),
        getFunc = function()
            return AH.Vars.MarkFavourites
        end,
        setFunc = function(value)
            AH.Vars.MarkFavourites = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = zo_iconFormat(string.format("/esoui/art/%s.dds", AH.ICONS.AVOID.name), 24, 24) ..
            "|r " .. AH.LC.Format(_G.MARKTRIALHELPER_AVOID),
        getFunc = function()
            return AH.Vars.MarkIgnore
        end,
        setFunc = function(value)
            AH.Vars.MarkIgnore = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "header",
        name = AH.LC.Format(SI_COLLECTIONS_FAVORITES_CATEGORY_HEADER),
        width = "full"
    }

    options[#options + 1] = {
        type = "dropdown",
        name = AH.LC.Format(SI_COLLECTIBLE_ACTION_ADD_FAVORITE),
        choices = favouriteChoices,
        choicesValues = favouriteChoiceValues,
        scrollable = true,
        getFunc = function()
        end,
        setFunc = function(value)
            if (ZO_IsElementInNumericallyIndexedTable(AH.Vars.Favourites, value)) then
                return
            end

            table.insert(AH.Vars.Favourites, value)
            updateFavourites()
        end,
        disabled = function()
            return not AH.Vars.MarkFavourites
        end
    }

    options[#options + 1] = {
        type = "dropdown",
        name = AH.LC.Format(SI_COLLECTIBLE_ACTION_REMOVE_FAVORITE),
        choices = removeChoices,
        choicesValues = removeChoiceValues,
        scrollable = true,
        getFunc = function()
        end,
        setFunc = function(value)
            if (ZO_IsElementInNumericallyIndexedTable(AH.Vars.Favourites, value)) then
                AH.Vars.Favourites =
                    AH.LC.Filter(
                        AH.Vars.Favourites,
                        function(v)
                            return v ~= value
                        end
                    )

                updateFavourites()
            end
        end,
        disabled = function()
            return #AH.Vars.Favourites == 0 or (not AH.Vars.MarkFavourites)
        end
    }

    options[#options + 1] = {
        type = "description",
        text = AH.LC.Red:Colorize(AH.LC.Format(_G.MARKTRIALHELPER_WARNING)),
        width = "full"
    }

    options[#options + 1] = {
        type = "description",
        text = getFavourites(),
        width = "full",
        reference = "MARKTRIALHELPER_FAVOURITES_LIST",
        disabled = function()
            return not AH.Vars.MarkFavourites
        end
    }

    options[#options + 1] = {
        type = "header",
        name = AH.LC.Format(_G.MARKTRIALHELPER_AVOID),
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = AH.LC.Format(_G.MARKTRIALHELPER_USE_AUTO_AVOID),
        tooltip = AH.LC.Format(_G.MARKTRIALHELPER_USE_AUTO_AVOID_TOOLTIP),
        getFunc = function()
            return AH.Vars.AutoCheck
        end,
        setFunc = function(value)
            if (value) then
                AH.EnableAutoCheck()
            else
                AH.DisableAutoCheck()
            end
        end,
        disabled = function()
            return not AH.Vars.MarkIgnore
        end
    }

    options[#options + 1] = {
        type = "dropdown",
        name = AH.LC.Format(_G.MARKTRIALHELPER_ADD_AVOID),
        choices = favouriteChoices,
        choicesValues = favouriteChoiceValues,
        scrollable = true,
        getFunc = function()
        end,
        setFunc = function(value)
            if (ZO_IsElementInNumericallyIndexedTable(AH.Vars.Ignore, value)) then
                return
            end

            table.insert(AH.Vars.Ignore, value)
            updateIgnore()
        end,
        disabled = function()
            return not AH.Vars.MarkIgnore
        end
    }

    options[#options + 1] = {
        type = "dropdown",
        name = AH.LC.Format(_G.MARKTRIALHELPER_REMOVE_AVOID),
        choices = removeIgnoreChoices,
        choicesValues = removeIgnoreChoiceValues,
        scrollable = true,
        getFunc = function()
        end,
        setFunc = function(value)
            if (ZO_IsElementInNumericallyIndexedTable(AH.Vars.Ignore, value)) then
                AH.Vars.Ignore =
                    AH.LC.Filter(
                        AH.Vars.Ignore,
                        function(v)
                            return v ~= value
                        end
                    )

                updateIgnore()
            end
        end,
        disabled = function()
            return #AH.Vars.Ignore == 0 or (not AH.Vars.MarkIgnore)
        end
    }

    options[#options + 1] = {
        type = "description",
        text = AH.LC.Red:Colorize(AH.LC.Format(_G.MARKTRIALHELPER_WARNING)),
        width = "full"
    }

    options[#options + 1] = {
        type = "description",
        text = getIgnore(),
        width = "full",
        reference = "MARKTRIALHELPER_IGNORE_LIST",
        disabled = function()
            return not AH.Vars.MarkIgnore
        end
    }
    options[#options + 1] = {
        type = "header",
        name = "|cFFFACDОпасные атаки|r",
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = "Отслеживать опасные атаки",
        tooltip = "Показывать таймеры до опасных атак врагов (цветные уведомления).",
        getFunc = function()
            return AH.Vars.TrackDanger
        end,
        setFunc = function(value)
            AH.Vars.TrackDanger = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = "Отслеживать Ослабление",
        tooltip = "Показывать таймер ослабления (Weakening) на боссах.",
        getFunc = function()
            return AH.Vars.TrackWeakening
        end,
        setFunc = function(value)
            AH.Vars.TrackWeakening = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "header",
        name = "|cFFFACDСпавн врагов|r",
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = "Оповещать о спавне опасных врагов",
        tooltip = "Показывать уведомление при появлении Инфьюзеров, Импов и других опасных мобов.",
        getFunc = function()
            return AH.Vars.TrackSpawns
        end,
        setFunc = function(value)
            AH.Vars.TrackSpawns = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = "Включить звуки уведомлений",
        tooltip = "Воспроизводить звуки при появлении опасных атак и спавне врагов.",
        getFunc = function()
            return AH.Vars.EnableSounds
        end,
        setFunc = function(value)
            AH.Vars.EnableSounds = value
        end,
        width = "full"
    }
    options[#options + 1] = {
        type = "header",
        name = "|cff9900Автометки опасных мобов (Триалы / Данжи)|r",
        width = "full"
    }

    options[#options + 1] = {
        type = "checkbox",
        name = "Включить автометки при наведении прицела",
        tooltip = "Автоматически ставит метку на приоритетных мобов из вашего списка в триалах, данжах и мире.",
        getFunc = function()
            return AH.Vars.EnableTrialMarkers ~= false
        end,
        setFunc = function(value)
            AH.Vars.EnableTrialMarkers = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "dropdown",
        name = "Метка по умолчанию при добавлении",
        tooltip = "Какую иконку ставить при добавлении моба горячей клавишей или командой /madd",
        choices = { "8 - Череп", "2 - Крест", "3 - Звезда", "4 - Полумесяц", "5 - Треугольник", "6 - Круг", "1 - Квадрат", "7 - Спираль" },
        choicesValues = { 8, 2, 3, 4, 5, 6, 1, 7 },
        getFunc = function()
            return AH.Vars.DefaultTrialMarker or 8
        end,
        setFunc = function(value)
            AH.Vars.DefaultTrialMarker = value
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "editbox",
        name = "Добавить моба по имени (нажмите Enter)",
        tooltip = "Введите точное имя или часть имени моба на русском языке и нажмите Enter. Либо наведите прицел в игре и введите /madd",
        getFunc = function() return "" end,
        setFunc = function(text)
            if text and text ~= "" then
                AH.AddPriorityMob(AH.Vars.DefaultTrialMarker or 8, text)
            end
        end,
        isMultiline = false,
        width = "full"
    }

    options[#options + 1] = {
        type = "description",
        title = "Сохранённые мобы (команды: /madd, /mdel, /mlist):",
        text = function()
            return AH.GetPriorityMobsText()
        end,
        width = "full"
    }

    options[#options + 1] = {
        type = "button",
        name = "Очистить весь список автометок",
        warning = "Удалить всех сохранённых мобов из базы автометок?",
        func = function()
            AH.Vars.CustomMarkers = {}
            d("|cff9900[MarkTrialHelper]|r Список автометок очищен.")
        end,
        width = "full"
    }

    options[#options + 1] = { type = "button", name = "Загрузить стандартную базу триалов (RU + EN)", func = function() local c = AH.LoadDefaultTrialMobs(false) d("|cff9900[Mark Trial Helper]|r Загружено мобов: " .. c) end, width = "full" }
        options[#options + 1] = { type = "header", name = "|cff9900Навигатор по скайшардам (Маршруты)|r", width = "full" }
    options[#options + 1] = { type = "description", title = "Команды в чате и привязки клавиш:", text = "• |c00ff00/skyroute|r — маршрут по несобранным скайшардам зоны\n• |c00ff00/skynext|r — пропустить текущий камень\n• |c00ff00/skystop|r — остановить маршрут и убрать линии\n• |c00ff00/madd|r, |c00ff00/mdel|r, |c00ff00/mlist|r — автометки опасных мобов", width = "full" }
    options[#options + 1] = { type = "checkbox", name = "Учитывать открытые дорожные святилища", getFunc = function() return AH.Vars.SkyshardUseWayshrines ~= false end, setFunc = function(v) AH.Vars.SkyshardUseWayshrines = v end, width = "full" }
    options[#options + 1] = {
        type = "header",
        name = "|cffd700Поддержка автора / Support|r",
        width = "full"
    }

    options[#options + 1] = {
        type = "description",
        text = "Если аддон помогает вам в рейдах и сборе осколков, вы можете поддержать разработку золотом на |c00ff00PC EU (@BadKeni)|r или командой |c00ff00/mtip|r.\nIf this add-on helps you in trials, feel free to send gold tips to |c00ff00@BadKeni (PC EU)|r.",
        width = "full"
    }

    options[#options + 1] = {
        type = "button",
        name = zo_iconFormat("/esoui/art/currency/currency_gold.dds", 20, 20) .. " Чаевые / Send Tips",
        tooltip = "Открыть почту для отправки благодарности автору (@BadKeni, PC EU)",
        func = function() AH.SendTip() end,
        width = "half"
    }
    return options
end

function AH.RegisterSettings()
    local options = buildOptions()

    AH.OptionsPanel = AH.LAM:RegisterAddonPanel("MarkTrialHelperOptionsPanel", panel)
    do
        local isRu = (GetCVar("language.2") == "ru")
        table.insert(options, {
            type = "checkbox",
            name = isRu and "Оповещать о смерти Танка / Хила" or "Tank / Healer Death Alerts",
            tooltip = isRu and "Показывать уведомление по центру экрана и звук при гибели танка или хилера в группе/рейде." or "Show a center-screen alert and sound when a Tank or Healer dies in your group/raid.",
            getFunc = function() return AH.Vars.RoleDeathAlert ~= false end,
            setFunc = function(val) AH.Vars.RoleDeathAlert = val end,
            default = true,
        })
        table.insert(options, {
            type = "button",
            name = isRu and "Тест оповещения Танка/Хила" or "Test Role Death Alert",
            func = function() if AH.TestRoleDeathAlert then AH.TestRoleDeathAlert() end end,
        })
    end

    AH.LAM:RegisterOptionControls("MarkTrialHelperOptionsPanel", options)
end
