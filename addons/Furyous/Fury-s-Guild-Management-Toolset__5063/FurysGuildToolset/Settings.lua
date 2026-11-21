local GT = FuryGMT
local U = GT.Util
local Settings = {}
GT.Settings = Settings

-- One checkbox per guild for the global "Guilds to get alerts from" setting.
function Settings:AppendAlertGuildToggles(controls)
    controls[#controls + 1] = { type = "header", name = "Guilds to get alerts from" }
    controls[#controls + 1] = { type = "description",
        text = "Bank alerts, hopper alerts, watchlist alerts, inactivity, bank space and auto-demote only happen in the guilds ticked here. The History tab still logs every guild. Each ticked guild gets its own Rules section further down (after a reload)." }
    for _, guildId in ipairs(U.GetGuildIds()) do
        local gid = guildId
        controls[#controls + 1] = {
            type = "checkbox",
            name = U.GuildName(gid),
            getFunc = function() return GT:IsAlertGuild(gid) end,
            setFunc = function(v)
                GT.sv.alertsDisabledGuilds[gid] = (not v) or nil
                GT.Report:RefreshIfShown()
            end,
            tooltip = "Ticking or unticking a guild adds or removes its Rules section after a reload.",
            requiresReload = true,
            default = true,
        }
    end
end

-- "Ranks: 1 Guild Master, 2 Officer, 3 Member", so rank numbers are easy to pick.
function Settings:DescribeGuildRanks(guildId)
    local ranks = {}
    for rankIndex = 1, GetNumGuildRanks(guildId) do
        ranks[#ranks + 1] = string.format("%d %s", rankIndex, GetFinalGuildRankName(guildId, rankIndex))
    end
    return "Ranks: " .. table.concat(ranks, ", ")
end

-- Per-guild modules, in the order their settings appear in a guild's Rules section.
local GUILD_SETTINGS_ORDER = { "bank", "log", "capacity", "hoppers", "members" }

-- One "Rules for <guild>" submenu for each guild you get alerts from. Guilds with alerts
-- off get none, since nothing in them uses these settings.
function Settings:AppendGuildRules(options)
    local monitored = {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then monitored[#monitored + 1] = guildId end
    end
    options[#options + 1] = { type = "header", name = "Rules for each guild" }
    if #monitored == 0 then
        options[#options + 1] = { type = "description", text = "Tick at least one guild under Guilds to get alerts from, then reload, to set its rules here." }
        return
    end
    options[#options + 1] = { type = "description",
        text = "Each guild you get alerts from has its own limits, ignored ranks, mail texts, auto-demote, inactivity limits, hopper and bank space settings. After changing bank limits, click Rescan with current settings." }
    for _, guildId in ipairs(monitored) do
        local gid = guildId
        local controls = {}
        local others, otherIds = {}, {}
        for _, otherId in ipairs(monitored) do
            if otherId ~= gid then
                others[#others + 1] = U.GuildName(otherId)
                otherIds[#otherIds + 1] = otherId
            end
        end
        if #others > 0 then
            local copyFrom = otherIds[1]
            controls[#controls + 1] = { type = "dropdown", name = "Copy rules from", choices = others, choicesValues = otherIds,
                tooltip = "Pick a guild, then click Copy to give this guild the same settings.",
                getFunc = function() return copyFrom end, setFunc = function(v) copyFrom = v end, width = "half" }
            controls[#controls + 1] = { type = "button", name = "Copy", width = "half", isDangerous = true,
                tooltip = "Copies every setting in this section from the guild picked on the left, except the limit for each rank (ranks differ between guilds). Asks first.",
                warning = "Replaces this guild's settings with the other guild's. Click Rescan with current settings afterwards.",
                func = function()
                    GT:CopyGuildSettings(copyFrom, gid)
                    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", self.panel)
                    GT.Report:RefreshIfShown()
                    U.Print("Copied the rules from %s to %s.", U.GuildName(copyFrom), U.GuildName(gid))
                end }
        end
        for _, id in ipairs(GUILD_SETTINGS_ORDER) do
            local module = GT:GetModule(id)
            module:BuildGuildSettings(controls, gid)
        end
        options[#options + 1] = { type = "submenu", name = "Rules for " .. U.GuildName(gid), controls = controls }
    end
end

function Settings:Build()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local panelData = {
        type = "panel",
        name = "Fury's Guild Management",
        displayName = "Fury's Guild Management Toolset",
        author = "Furyous",
        version = GT.version,
        slashCommand = "/gtsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    self.panel = LAM:RegisterAddonPanel("FuryGMTSettings", panelData)

    local options = {
        { type = "description", text = "Type /gt to open the report window. Alerts appear in chat and on screen while you play, and a summary appears at login." },
        { type = "slider", name = "First run: look back (days)", min = 1, max = 30, step = 1,
          tooltip = "How far back to scan the first time a guild is checked. Later logins pick up where the last session stopped.",
          getFunc = function() return GT.sv.firstRunLookbackDays end, setFunc = function(v) GT.sv.firstRunLookbackDays = v end, default = 30 },
        { type = "button", name = "Rescan with current settings", width = "half",
          tooltip = "Rebuilds bank alerts and the hopper report from the History log using the settings below. No reload needed. Use it after changing thresholds or ignored ranks.",
          func = function() GT:Rescan() end },
    }
    self:AppendAlertGuildToggles(options)
    GT:ForEachModule("BuildSettings", options)
    self:AppendGuildRules(options)
    LAM:RegisterOptionControls("FuryGMTSettings", options)
end

function Settings:Open()
    if self.panel and LibAddonMenu2 then LibAddonMenu2:OpenToPanel(self.panel) end
end
