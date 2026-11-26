local GT = FurysGuildToolset
local U = GT.Util
local Settings = {}
GT.Settings = Settings

-- 1.10.0: big sections have settings pages of their own ("Fury's Guild Toolset - <title>"),
-- like the Crier, so the main page stays short. The main page keeps a small section with a
-- button that opens each one. Only where the controls are shown changes; the saved settings
-- stay the same.
function Settings:AddPage(id, title, controls, withDefaults)
    local LAM = LibAddonMenu2
    local name = "FurysGuildToolset_" .. id .. "Panel"
    local panel = LAM:RegisterAddonPanel(name, {
        type = "panel",
        name = "Fury's Guild Toolset - " .. title,
        displayName = "|cA08CFFFury's Guild Toolset: " .. title .. "|r",
        author = "Furyous",
        version = GT.version,
        website = GT.website,
        registerForRefresh = true,
        registerForDefaults = withDefaults,
    })
    LAM:RegisterOptionControls(name, controls)
    return panel
end

-- A section on the main page that points to a page of its own.
function Settings:AddPointer(options, title, text, open)
    options[#options + 1] = { type = "submenu", name = title, controls = {
        { type = "description", text = text },
        { type = "button", name = "Open " .. title .. " settings", width = "half",
          tooltip = "Opens the " .. title .. " settings page.", func = open },
    } }
end

-- 1.10.1: an "Open Guild rules settings" button for main-page sections whose settings for
-- each guild are on the Guild rules page.
function Settings:RulesButton(tip)
    return { type = "button", name = "Open Guild rules settings", width = "half", tooltip = tip,
        func = function() self:OpenRules() end }
end

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
                GT:SetAlertGuild(gid, v)
                GT.Report:RefreshIfShown()
            end,
            tooltip = "Ticking or unticking a guild adds or removes its Rules section after a reload.",
            requiresReload = true,
            default = not GT.sv.alertGuildsOptIn,
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
    if #monitored == 0 then
        options[#options + 1] = { type = "description", text = "Tick at least one guild under Guilds to get alerts from (on the main Fury's Guild Toolset settings page), then reload, to set its rules here." }
        return
    end
    options[#options + 1] = { type = "description",
        text = "Each guild you get alerts from has its own limits, ignored ranks, mail texts, auto-demote, inactivity limits, hopper and bank space settings. After changing bank limits, click Rescan alerts." }
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
                warning = "Replaces this guild's settings with the other guild's. Click Rescan alerts afterwards.",
                func = function()
                    local from = copyFrom
                    GT.Actions.Confirm("Copy rules",
                        string.format("Replace the rules of %s with the rules of %s?\n\nThe limit for each rank is not copied. This can't be undone.", U.GuildName(gid), U.GuildName(from)),
                        function()
                            GT:CopyGuildSettings(from, gid)
                            CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", self.rulesPanel)
                            GT.Report:RefreshIfShown()
                            U.Print("Copied the rules from %s to %s.", U.GuildName(from), U.GuildName(gid))
                        end)
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
    local panelData = {
        type = "panel",
        name = "Fury's Guild Toolset",
        displayName = "|cA08CFFFury's Guild Toolset|r",
        author = "Furyous",
        version = GT.version,
        website = GT.website,
        slashCommand = "/gtsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    self.panel = LAM:RegisterAddonPanel("FurysGuildToolset_Settings", panelData)

    local options = {
        { type = "description", text = "Type /gt to open the report window. Its Start here button (next to the window title) sets up your guilds and features in one place; the pages here have the details. Alerts appear in chat and on screen while you play, and a summary appears at login." },
        { type = "slider", name = "First run: look back (days)", min = 1, max = 365, step = 1,
          tooltip = "How far back to scan the first time a guild is checked (up to what LibHistoire has saved). Later logins pick up where the last session stopped, so changing it only affects guilds the toolset has not read yet. The Members tab always reads all saved roster history.",
          getFunc = function() return GT.sv.firstRunLookbackDays end, setFunc = function(v) GT.sv.firstRunLookbackDays = v end, default = 30 },
        { type = "button", name = "Rescan alerts", width = "half",
          tooltip = "Rebuilds bank alerts and the hopper report from the History log using the settings below. No reload needed. Use it after changing thresholds or ignored ranks.",
          func = function() GT:Rescan() end },
    }
    self:AppendAlertGuildToggles(options)
    GT:ForEachModule("BuildSettings", options)
    -- 1.10.0: each guild's rules (limits, mails, auto-demote, inactivity, hoppers, bank space)
    -- moved to their own page.
    local rules = {}
    self:AppendGuildRules(rules)
    self.rulesPanel = self:AddPage("Rules", "Guild rules", rules, true)
    options[#options + 1] = { type = "header", name = "Rules for each guild" }
    options[#options + 1] = { type = "description", text = "Each guild's bank limits, ignored ranks, mail texts, auto-demote, inactivity limits, hopper and bank space settings are on their own page: \"Fury's Guild Toolset - Guild rules\" in the Add-Ons list." }
    options[#options + 1] = { type = "button", name = "Open Guild rules settings", width = "half",
        tooltip = "Opens the Guild rules settings page.", func = function() self:OpenRules() end }
    GT.Theme.MoreOptions(options)   -- 1.31.2: the other Fury addons, at the very end
    LAM:RegisterOptionControls("FurysGuildToolset_Settings", options)
end

function Settings:OpenRules()
    LibAddonMenu2:OpenToPanel(self.rulesPanel)
end

function Settings:Open()
    if self.panel then LibAddonMenu2:OpenToPanel(self.panel) end
end
