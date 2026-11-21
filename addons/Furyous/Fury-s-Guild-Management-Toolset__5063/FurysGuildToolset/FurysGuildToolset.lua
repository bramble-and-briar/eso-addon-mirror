-- Fury's Guild Management Toolset: core namespace, module registry, saved variables and lifecycle.
-- Each feature lives in Modules/<Name>.lua and registers itself with GT:RegisterModule.

FuryGMT = FuryGMT or {}
local GT = FuryGMT

GT.name = "FurysGuildToolset"
GT.displayName = "Fury's Guild Management Toolset"
GT.version = "1.2.5"
GT.savedVarsVersion = 1

GT.modules = {}
GT.moduleOrder = {}

-- A module is a table that may implement any of:
--   module.defaults                 table merged into saved variables under sv.modules[id]
--   module:Initialize(sv)           called on EVENT_ADD_ON_LOADED with the module's own saved table
--   module:OnPlayerActivated()      called once, the first time the player enters the world
--   module:GetHistoryCategories()   list of GUILD_HISTORY_EVENT_CATEGORY_* this module wants streamed
--   module:OnHistoryEvent(guildId, category, info, isLive)
--   module:OnHistoryCaughtUp(category)   every guild has delivered its backlog for this category
--   module:BuildSettings(options)   append LibAddonMenu controls to the options table
function GT:RegisterModule(id, module)
    assert(not self.modules[id], "FuryGMT module registered twice: " .. tostring(id))
    module.id = id
    self.modules[id] = module
    table.insert(self.moduleOrder, id)
    return module
end

function GT:GetModule(id)
    return self.modules[id]
end

function GT:ForEachModule(methodName, ...)
    for _, id in ipairs(self.moduleOrder) do
        local module = self.modules[id]
        local fn = module[methodName]
        if fn then fn(module, ...) end
    end
end

-- The "Guilds to get alerts from" setting. History is still logged for every guild.
function GT:IsAlertGuild(guildId)
    return not (self.sv and self.sv.alertsDisabledGuilds[guildId])
end

-- Per-guild settings. A module lists the settings that can differ between guilds in
-- module.guildKeys; each guild keeps its own copy in module.sv.guilds[guildId]. A guild
-- starts from the module's own values (the settings everyone had before 0.4.25), and a
-- setting added in a later version is filled in the same way.
function GT:GuildSettings(module, guildId)
    local sv = module.sv
    local g = sv.guilds[guildId]
    if not g then
        g = {}
        sv.guilds[guildId] = g
    end
    module.guildFilled = module.guildFilled or {}
    if not module.guildFilled[guildId] then
        for _, key in ipairs(module.guildKeys) do
            if g[key] == nil then g[key] = sv[key] end
        end
        module.guildFilled[guildId] = true
    end
    return g
end

-- The largest value of a per-guild setting over every guild that has its own settings (for
-- pruning, which runs at load before the guild list is ready).
function GT:MaxGuildSetting(module, key)
    local best = module.sv[key]
    for _, g in pairs(module.sv.guilds) do
        if g[key] then best = math.max(best, g[key]) end
    end
    return best
end

-- Copies every per-guild setting (all modules) from one guild to another. Per-rank rules
-- stay as they are, since two guilds rarely have the same ranks.
function GT:CopyGuildSettings(fromGuildId, toGuildId)
    for _, id in ipairs(self.moduleOrder) do
        local module = self.modules[id]
        if module.guildKeys then
            local from, to = self:GuildSettings(module, fromGuildId), self:GuildSettings(module, toGuildId)
            for _, key in ipairs(module.guildKeys) do to[key] = from[key] end
        end
    end
end

local function BuildDefaults()
    local defaults = {
        historyCursor = {},
        mailQueue = {},      -- [processorKey] = last processed eventId
        firstRunLookbackDays = 30,
        alertsDisabledGuilds = {},   -- [guildId] = true: no alerts, cases or auto actions for that guild
        modules = {},
    }
    for _, id in ipairs(GT.moduleOrder) do
        local module = GT.modules[id]
        defaults.modules[id] = module.defaults or {}
        if module.guildKeys then defaults.modules[id].guilds = {} end   -- [guildId] = that guild's settings
    end
    return defaults
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= GT.name then return end
    EVENT_MANAGER:UnregisterForEvent(GT.name, EVENT_ADD_ON_LOADED)

    -- Account-wide, but split per megaserver because guild ids differ between NA and EU.
    GT.sv = ZO_SavedVars:NewAccountWide("FuryGMT_SV", GT.savedVarsVersion, nil, BuildDefaults(), GetWorldName())

    for _, id in ipairs(GT.moduleOrder) do
        local module = GT.modules[id]
        if module.Initialize then module:Initialize(GT.sv.modules[id]) end
    end

    GT.sv.mailQueue = nil -- v0.2.3: automatic mail removed; drop anything left queued
    GT.Report:Initialize()
    GT.RegisterSlashCommands()
end

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(GT.name, EVENT_PLAYER_ACTIVATED)
    GT.Settings:Build()
    GT:ForEachModule("OnPlayerActivated")
    GT.History:Start()
end

-- Rebuilds bank alerts and the hopper report from the History log using the current
-- settings. Instant, no reload. Handled alerts are cleared too, so you see exactly what
-- the current settings flag.
function GT:Rescan()
    local log = self:GetModule("log")
    local entries = log and log.sv and log.sv.entries or {}
    local bank, hoppers = self:GetModule("bank"), self:GetModule("hoppers")
    local bankCount = bank and bank.sv and bank:RebuildFromLog(entries) or 0
    local hopperCount = hoppers and hoppers.sv and hoppers:RebuildFromLog(entries) or 0
    GT.Util.Print("Rescanned %d logged events: %d new bank %s (actions you already took are kept), %d %s.", #entries, bankCount,
        bankCount == 1 and "alert" or "alerts", hopperCount, hopperCount == 1 and "hopper" or "hoppers")
    if bankCount > 0 then GT.Report:Show("bank") elseif hopperCount > 0 then GT.Report:Show("hoppers") end
    GT.Report:RefreshIfShown()
end

-- Full reset: forgets the History log too and downloads/replays the look-back period.
-- Typed confirmation instead of a dialog so it works from chat in one step.
function GT:FullReset()
    GT.sv.historyCursor = {}
    local modules = GT.sv.modules
    if modules.bank then modules.bank.cases = {}; modules.bank.ledger = {} end
    if modules.hoppers then modules.hoppers.records = {}; modules.hoppers.joins = {} end
    if modules.log then modules.log.entries = {} end
    if modules.trader then modules.trader.weeks = {} end
    ReloadUI("ingame")
end

function GT.RegisterSlashCommands()
    SLASH_COMMANDS["/gt"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "" or arg == "show" then
            GT.Report:Toggle()
        elseif arg == "crier" then
            if GT.Crier and GT.Crier.active then GT.Crier.ToggleMenu() else GT.Util.Print("The Guild Crier is paused while the standalone Fury's Guild Crier addon is enabled.") end
        elseif arg == "space" then
            GT.Report:Show("capacity")
        elseif arg == "bank" or arg == "hoppers" or arg == "watchlist" or arg == "members" or arg == "inactive" then
            GT.Report:Show(arg)
        elseif arg == "trader" or arg == "week" or arg == "weekly" then
            GT.Report:Show("trader")
        elseif arg == "sales" then
            GT.Report:Show("sales")
        elseif arg == "auto" or arg == "actions" then
            GT.Report:Show("auto")
        elseif arg == "history" or arg == "log" then
            GT.Report:Show("log")
        elseif arg == "status" then
            GT.History:PrintStatus()
            local bank = GT:GetModule("bank")
            if bank and bank.sv then bank:PrintStatus() end
            local capacity = GT:GetModule("capacity")
            if capacity and capacity.sv then capacity:PrintStatus() end
        elseif arg == "reset" or arg == "rescan" then
            GT:Rescan()
        elseif arg == "reset full" then
            GT:FullReset()
        elseif arg == "guilds" then
            for _, guildId in ipairs(GT.Util.GetGuildIds()) do
                GT.Util.Print("%s: alerts %s", GT.Util.GuildName(guildId), GT:IsAlertGuild(guildId) and "|c9FD49Fon|r" or "|cFF6666off|r")
            end
            GT.Util.Print("Change this in /gtsettings under Guilds to get alerts from.")
        elseif arg == "settings" then
            GT.Settings:Open()
        else
            GT.Util.Print("Fury's Guild Management Toolset v%s", GT.version)
            GT.Util.Print("/gt  open the report window")
            -- No "|" here: ESO treats it as a text-formatting character and hides it.
            GT.Util.Print("/gt bank, /gt hoppers, /gt watchlist, /gt history, /gt space, /gt members, /gt inactive, /gt trader, /gt sales, /gt auto  open a specific tab")
            GT.Util.Print("/gt crier (or /crier)  open the Guild Crier message menu")
            GT.Util.Print("/gt guilds  show which guilds send alerts")
            GT.Util.Print("/gt reset  rebuild bank alerts and hoppers from the History log with your current settings")
            GT.Util.Print("/gt reset full  also wipe the History log, reload and download it again")
            GT.Util.Print("/gt status  show what history has loaded and the biggest withdrawers")
            GT.Util.Print("/gt settings  open the settings panel")
        end
    end
end

EVENT_MANAGER:RegisterForEvent(GT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(GT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
