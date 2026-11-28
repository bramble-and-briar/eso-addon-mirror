-- Fury's Guild Toolset: core namespace, module registry, saved variables and lifecycle.
-- Each feature lives in Modules/<Name>.lua and registers itself with GT:RegisterModule.

FurysGuildToolset = {}
local GT = FurysGuildToolset

GT.name = "FurysGuildToolset"
GT.displayName = "Fury's Guild Toolset"
GT.version = "1.34.8"
GT.website = "https://www.esoui.com/downloads/info5063.html"
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
    assert(not self.modules[id], "FurysGuildToolset module registered twice: " .. tostring(id))
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
-- Installs from 1.3.0 on start with no guild ticked (alertGuildsOptIn); older installs keep
-- every guild ticked unless they unticked it (alertsDisabledGuilds).
function GT:IsAlertGuild(guildId)
    if not self.sv then return true end
    if self.sv.alertGuildsOptIn then return self.sv.alertGuilds[guildId] == true end
    return not self.sv.alertsDisabledGuilds[guildId]
end

function GT:AnyAlertGuild()
    for _, guildId in ipairs(self.Util.GetGuildIds()) do
        if self:IsAlertGuild(guildId) then return true end
    end
    return false
end

-- The line a report tab shows while its feature is off, or nil when it's on.
-- perGuild: the feature also needs a guild ticked under Guilds to get alerts from.
function GT:FeatureOffText(on, what, perGuild)
    if perGuild and not self:AnyAlertGuild() then
        return "No guild is ticked to get alerts from. Click Set up below, or tick one in /gtsettings."
    end
    if not on then return what .. " is turned off. Click Set up below, or turn it on in /gtsettings." end
    return nil
end

function GT:SetAlertGuild(guildId, on)
    if self.sv.alertGuildsOptIn then
        self.sv.alertGuilds[guildId] = on or nil
    else
        self.sv.alertsDisabledGuilds[guildId] = (not on) or nil
    end
end

-- 1.3.0: everything that can be turned off starts turned off on a new install (Albert). These
-- settings used to start on. An install from before 1.3.0 that never saved one of them gets
-- the old value (on) written in once, so nothing changes for people who already use the addon.
local OLD_ON_DEFAULTS = {
    bank = { "enabled", "goldEnabled", "openWindowOnLogin", "autoDemoteNote", "blacklistOnKick" },   -- goldEnabled: read once by BankWatch 1.32.3
    auto = { "bigNotice", "alertWindow" },
    capacity = { "enabled" },
    log = { "enabled" },
    hoppers = { "enabled", "autoWatchlist", "alertOnWatchlistJoin", "openWindowOnLogin" },
    members = { "inactiveEnabled", "alertOnLogin" },
    trader = { "enabled" },
}

-- Before ZO_SavedVars fills in the defaults: is there saved data for this account and
-- megaserver, and which of the old "on" settings did it never save?
local function ReadOldInstall()
    local byWorld = FuryGMT_SV and FuryGMT_SV[GetWorldName()]
    local byAccount = byWorld and byWorld[GetDisplayName()]
    local saved = byAccount and byAccount["$AccountWide"]
    if not saved then return nil end
    if saved.defaultsOff ~= nil then return nil end   -- already set up by 1.3.0 or later
    local missing = {}
    local modules = saved.modules or {}
    for id, keys in pairs(OLD_ON_DEFAULTS) do
        for _, key in ipairs(keys) do
            if not modules[id] or modules[id][key] == nil then missing[#missing + 1] = { id, key } end
        end
    end
    return missing
end

local function SetUpDefaults(oldMissing)
    local sv = GT.sv
    if sv.defaultsOff ~= nil then return end
    if oldMissing then
        sv.defaultsOff = false   -- installed before 1.3.0: keep what they had
        for _, entry in ipairs(oldMissing) do sv.modules[entry[1]][entry[2]] = true end
    else
        sv.defaultsOff = true    -- new install: every feature starts turned off
        sv.alertGuildsOptIn = true
    end
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
        holeFill = false,            -- 1.34.7: fill holes LibHistoire leaves (Core/HoleFill.lua); starts turned off
        holeLog = {},                -- 1.34.7: every hole found, for /gt holes
        holeFillStartMinutes = 2,    -- 1.34.7: hole filler numbers (limits and tips in Core/HoleFill.lua SETTINGS)
        holeFillMinGapHours = 12,
        holeFillLookBackDays = 30,
        holeFillPauseMinutes = 4,
        holeFillMaxPerSession = 6,
        holeFillStuckMinutes = 15,
        alertsDisabledGuilds = {},   -- [guildId] = true: no alerts, cases or auto actions for that guild (installs before 1.3.0)
        alertGuilds = {},            -- [guildId] = true: alerts on for that guild (installs from 1.3.0, see alertGuildsOptIn)
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
    local oldMissing = ReadOldInstall()
    GT.sv = ZO_SavedVars:NewAccountWide("FuryGMT_SV", GT.savedVarsVersion, nil, BuildDefaults(), GetWorldName())
    SetUpDefaults(oldMissing)

    for _, id in ipairs(GT.moduleOrder) do
        local module = GT.modules[id]
        if module.Initialize then module:Initialize(GT.sv.modules[id]) end
    end

    GT.HoleFill:Initialize()
    GT.sv.mailQueue = nil -- v0.2.3: automatic mail removed; drop anything left queued
    GT.Report:Initialize()
    GT.RegisterSlashCommands()
end

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(GT.name, EVENT_PLAYER_ACTIVATED)
    GT.Settings:Build()
    if GT.sv.defaultsOff then
        GT.Theme.Welcome(GT.sv, "welcomeShown", "Everything starts turned off. Type /gt to get started: the Start here page lets you pick your guilds and turn on the features you want.")
    end
    GT:ForEachModule("OnPlayerActivated")
    GT.History:Start()
end

-- Rebuilds bank alerts and the hopper report from the History log using the current
-- settings. Instant, no reload. Handled alerts are cleared too, so you see exactly what
-- the current settings flag.
function GT:Rescan()
    local log = self:GetModule("log")
    local entries = log and log.entries or {}
    local bank, hoppers = self:GetModule("bank"), self:GetModule("hoppers")
    local bankCount = bank and bank.sv and bank:RebuildFromLog(entries) or 0
    local hopperCount = hoppers and hoppers.sv and hoppers:RebuildFromLog(entries) or 0
    GT.Util.Print("Rescanned %d logged events: %d new bank %s (actions you already took are kept), %d %s.", #entries, bankCount,
        bankCount == 1 and "alert" or "alerts", hopperCount, hopperCount == 1 and "hopper" or "hoppers")
    if bankCount > 0 then GT.Report:Show("bank") elseif hopperCount > 0 then GT.Report:Show("hoppers") end
    GT.Report:RefreshIfShown()
end

-- Full reset: forgets the History log too and downloads/replays the look-back period.
-- Asks with a Confirm / Cancel pop-up first (1.31.0, Albert: nothing reloads without asking).
function GT:FullReset()
    GT.Actions.Confirm("Full reset",
        "Forget the History log, bank alerts, hoppers and trader weeks, and read the look-back period again from LibHistoire?\n\nThis reloads the UI (a few seconds). Your settings are kept.",
        function() GT:DoFullReset() end)
end

function GT:DoFullReset()
    GT.sv.historyCursor = {}
    local modules = GT.sv.modules
    if modules.bank then modules.bank.cases = {}; modules.bank.ledger = {} end
    if modules.hoppers then modules.hoppers.records = {}; modules.hoppers.joins = {} end
    if modules.log then modules.log.packed = {}; modules.log.entries = nil; modules.log.oldLogSince = nil end
    if modules.trader then modules.trader.weeks = {} end
    ReloadUI("ingame")
end

function GT.RegisterSlashCommands()
    SLASH_COMMANDS["/gt"] = function(arg)
        -- /gt raffle add @Name 3: names keep their capitals, so this goes first.
        local raffleArgs = zo_strtrim(arg or ""):match("^[Rr][Aa][Ff][Ff][Ll][Ee]%s*(.*)$")
        if raffleArgs then
            GT.Raffle:Slash(raffleArgs)
            return
        end
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "" or arg == "show" then
            GT.Report:Toggle()
        elseif arg == "start" or arg == "setup" then
            GT.Report:Show("start")
        elseif arg == "crier" then
            if GT.Crier and GT.Crier.active then GT.Crier.ToggleMenu() else GT.Util.Print("The Guild Crier is paused while the standalone Fury's Guild Crier addon is enabled.") end
        elseif arg == "space" then
            GT.Report:Show("capacity")
        elseif arg == "bank" or arg == "hoppers" or arg == "watchlist" or arg == "members" or arg == "inactive" then
            GT.Report:Show(arg)
        elseif arg == "trader" or arg == "week" or arg == "weekly" then
            GT.Report:Show("trader")
        elseif arg == "recruit" then
            GT.Report:Show("recruit")
        elseif arg == "events" or arg == "event" then
            GT.Report:Show("events")
        elseif arg == "tour" then
            GT.Recruit:ToggleTour()
        elseif arg == "congrats" then
            GT.Milestones:SayNext()
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
        elseif arg == "holes" then
            GT.HoleFill:ShowLog()
        elseif arg == "reset" or arg == "rescan" then
            GT:Rescan()
        elseif arg == "reset full" then
            GT:FullReset()
        elseif arg == "guilds" then
            for _, guildId in ipairs(GT.Util.GetGuildIds()) do
                GT.Util.Print("%s: alerts %s", GT.Util.GuildName(guildId), GT:IsAlertGuild(guildId) and "|c5EE6A0on|r" or "|cFF6B86off|r")
            end
            GT.Util.Print("Change this in /gtsettings under Guilds to get alerts from.")
        elseif arg == "settings" then
            GT.Settings:Open()
        else
            GT.Util.Print("Fury's Guild Toolset v%s commands:", GT.version)
            GT.Util.Print("/gt  open the report window")
            GT.Util.Print("/gt start  open the Start here page: pick your guilds and turn features on or off")
            -- No "|" here: ESO treats it as a text-formatting character and hides it.
            GT.Util.Print("/gt bank, /gt hoppers, /gt watchlist, /gt history, /gt space, /gt members, /gt inactive, /gt trader, /gt sales, /gt auto, /gt recruit, /gt events  open a specific tab")
            GT.Util.Print("/gt tour  start or stop the recruiting zone tour")
            GT.Util.Print("/gt congrats  put the next member anniversary congratulation in chat")
            GT.Util.Print("/gt raffle  open the Raffle tab;  /gt raffle add @name 3 (reason), /gt raffle remove @name 3 (reason)  change someone's tickets by hand")
            GT.Util.Print("/gt crier (or /crier)  open the Guild Crier message menu")
            GT.Util.Print("/gt guilds  show which guilds send alerts")
            GT.Util.Print("/gt reset  rebuild bank alerts and hoppers from the History log with your current settings")
            GT.Util.Print("/gt reset full  also wipe the History log, reload and download it again")
            GT.Util.Print("/gt status  show what history has loaded and the biggest withdrawers")
            GT.Util.Print("/gt holes  list the holes LibHistoire left in the bank history and what the Toolset filled")
            GT.Util.Print("/gt settings  open the settings panel")
        end
    end
end

EVENT_MANAGER:RegisterForEvent(GT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(GT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
