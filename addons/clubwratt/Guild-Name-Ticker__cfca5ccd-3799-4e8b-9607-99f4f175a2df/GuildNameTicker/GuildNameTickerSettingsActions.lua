-- GuildNameTickerSettingsActions.lua: Gamepad-friendly settings page via
-- LibHarvensAddonSettings (register with AddAddon + AddSetting; never call
-- CreateAddonSettingsPanel from an addon). Two sections: quick set (the /gt
-- feature) and the ticker.

local GuildNameTickerSettingsActions = {}

---@return GuildNameTickerSavedVars
local function GetSettings()
    return GuildNameTicker.state.savedVars
end

function GuildNameTickerSettingsActions.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not LAS or not LAS.AddAddon then
        GuildNameTicker.Log("LibHarvensAddonSettings not available; settings page disabled")
        return
    end

    local panel = LAS:AddAddon("Guild Name Ticker")
    panel.author = "clubwratt"
    panel.version = "v" .. tostring(GuildNameTicker.version)

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Set Guild Name",
    })

    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "Tip: /gt Some Name in chat does the same thing; /gt alone disbands the guild.",
    })

    panel:AddSetting({
        type = LAS.ST_EDIT,
        label = "Guild name",
        tooltip = "Name to show as your represented guild. A throwaway guild is created with this name; any previous ticker guild is disbanded first (you can only lead one guild).",
        maxChars = 50,
        getFunction = function()
            return GetSettings().quickName
        end,
        setFunction = function(value)
            GetSettings().quickName = value or ""
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Set name now",
        tooltip = "Create the guild above and represent it in the Character menu. It stays until you set another name, clear it, or start the ticker.",
        buttonText = "Set",
        clickHandler = function()
            GuildNameTicker.CycleActions.SetName(GetSettings().quickName)
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Clear",
        tooltip = "Disband the current ticker guild and clear your represented guild.",
        buttonText = "Clear",
        clickHandler = function()
            GuildNameTicker.CycleActions.Clear()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Prefix & Suffix",
    })

    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "Added to every created name exactly as typed, to dodge taken names. No space is inserted for you: use e.g. prefix \"xX \" and suffix \" Xx\".",
    })

    panel:AddSetting({
        type = LAS.ST_EDIT,
        label = "Prefix",
        tooltip = "Prepended verbatim to every created guild name (quick set and ticker). Include a trailing space yourself if you want one.",
        maxChars = 15,
        getFunction = function()
            return GetSettings().prefix
        end,
        setFunction = function(value)
            GetSettings().prefix = value or ""
        end,
    })

    panel:AddSetting({
        type = LAS.ST_EDIT,
        label = "Suffix",
        tooltip = "Appended verbatim to every created guild name (quick set and ticker). Include a leading space yourself if you want one.",
        maxChars = 15,
        getFunction = function()
            return GetSettings().suffix
        end,
        setFunction = function(value)
            GetSettings().suffix = value or ""
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Ticker",
    })

    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "Cycles through the names below on a timer, one throwaway guild per name.",
    })

    for i = 1, GuildNameTicker.State.TICKER_LINE_COUNT do
        panel:AddSetting({
            type = LAS.ST_EDIT,
            label = "Name " .. i,
            tooltip = "One guild name per line; empty lines are skipped. Lines longer than the max guild name length are split.",
            maxChars = 50,
            getFunction = function()
                return GetSettings().lines[i] or ""
            end,
            setFunction = function(value)
                GetSettings().lines[i] = value or ""
            end,
        })
    end

    panel:AddSetting({
        type = LAS.ST_SLIDER,
        label = "Seconds per name",
        tooltip = "How long each name stays represented before cycling to the next one.",
        min = 3,
        max = 60,
        step = 1,
        format = "%.0f",
        getFunction = function()
            return math.floor(GetSettings().intervalMs / 1000)
        end,
        setFunction = function(value)
            local seconds = tonumber(value)
            if seconds then
                GetSettings().intervalMs = seconds * 1000
            end
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Start ticker",
        tooltip = "Begin the create/represent/disband cycle with the names above. Requires a free guild slot and that you are not already a guildmaster.",
        buttonText = "Start",
        clickHandler = function()
            GuildNameTicker.CycleActions.Start()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Stop ticker",
        tooltip = "Stop cycling, disband the current throwaway guild, and restore your previous represented guild.",
        buttonText = "Stop",
        clickHandler = function()
            GuildNameTicker.CycleActions.Stop("stopped from settings")
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Advanced",
    })

    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "Extra attributes for created guilds. Description, MOTD, and playtime apply to the current guild immediately; alliance only takes effect on the next created guild.",
    })

    local allianceItems = {
        { name = "Your alliance", data = 0 },
        { name = "Aldmeri Dominion", data = _G["ALLIANCE_ALDMERI_DOMINION"] or 1 },
        { name = "Ebonheart Pact", data = _G["ALLIANCE_EBONHEART_PACT"] or 2 },
        { name = "Daggerfall Covenant", data = _G["ALLIANCE_DAGGERFALL_COVENANT"] or 3 },
    }
    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "Alliance",
        tooltip = "Alliance the created guilds belong to. Can only be chosen at creation, so a change applies from the next guild onward.",
        items = allianceItems,
        default = allianceItems[1].name,
        getFunction = function()
            for _, item in ipairs(allianceItems) do
                if item.data == (GetSettings().alliance or 0) then
                    return item.name
                end
            end
            return allianceItems[1].name
        end,
        setFunction = function(_, _, item)
            GetSettings().alliance = item.data
        end,
    })

    panel:AddSetting({
        type = LAS.ST_EDIT,
        label = "Description",
        tooltip = "Guild description for every created guild. Leave empty to keep the default.",
        maxChars = 250,
        getFunction = function()
            return GetSettings().description
        end,
        setFunction = function(value)
            GetSettings().description = value or ""
            GuildNameTicker.CycleActions.ApplyGuildAttributes()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_EDIT,
        label = "Message of the day",
        tooltip = "MOTD for every created guild. Leave empty to keep the default.",
        maxChars = 250,
        getFunction = function()
            return GetSettings().motd
        end,
        setFunction = function(value)
            GetSettings().motd = value or ""
            GuildNameTicker.CycleActions.ApplyGuildAttributes()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SLIDER,
        label = "Playtime start hour",
        tooltip = "Guild finder playtime window start (local time, 0-23). Leave start and end equal to skip setting a playtime.",
        min = 0,
        max = 23,
        step = 1,
        format = "%.0f",
        getFunction = function()
            return GetSettings().playtimeStartHour
        end,
        setFunction = function(value)
            GetSettings().playtimeStartHour = math.floor(tonumber(value) or 0)
            GuildNameTicker.CycleActions.ApplyGuildAttributes()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SLIDER,
        label = "Playtime end hour",
        tooltip = "Guild finder playtime window end (local time, 0-23). Leave start and end equal to skip setting a playtime.",
        min = 0,
        max = 23,
        step = 1,
        format = "%.0f",
        getFunction = function()
            return GetSettings().playtimeEndHour
        end,
        setFunction = function(value)
            GetSettings().playtimeEndHour = math.floor(tonumber(value) or 0)
            GuildNameTicker.CycleActions.ApplyGuildAttributes()
        end,
    })
end

GuildNameTicker.SettingsActions = GuildNameTickerSettingsActions
