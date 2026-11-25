-- Start here (1.27.0): setup inside the report window, for someone who has just installed the
-- toolset. One page lists your guilds and every feature with a line on what it does and
-- whether it is on. Click a row to switch it; right-click it for its tab and its settings.
-- Some features only start after a reload, so the page collects those and offers one
-- "Reload to apply" button.
--
-- It changes the same saved settings as the settings pages (/gtsettings); nothing here is a
-- second copy. Everything still starts turned off on a new install.

local GT = FurysGuildToolset
local U = GT.Util

local Setup = GT:RegisterModule("setup", {})

local VIDEO_URL = "https://www.youtube.com/live/IoDgDIp34fA"
local ON, OFF, WAIT, NOTE = "|c5EE6A0", "|c8A86B0", "|cFFC857", "|cFFA45C"

local function Module(id)
    return GT:GetModule(id)
end

local function OpenPanel(panel)
    if panel then LibAddonMenu2:OpenToPanel(panel) end
end

-- Inactivity alerts are a setting of each guild. With no guild ticked yet, the switch shows what
-- a guild will start with.
local function InactiveOn()
    local members = Module("members")
    if GT:AnyAlertGuild() then return members:AnyInactiveOn() end
    return members.sv.inactiveEnabled
end

local function SetInactive(on)
    local members = Module("members")
    members.sv.inactiveEnabled = on   -- a guild you join later starts the same way
    -- Every guild, ticked or not, so a guild ticked afterwards matches what the page shows.
    for _, guildId in ipairs(U.GetGuildIds()) do
        members:G(guildId).inactiveEnabled = on
    end
end

local function SetHoppers(on)
    local hoppers = Module("hoppers")
    hoppers.sv.enabled = on
    hoppers:UpdateEventRegistration()
end

local function SetRecruit(on)
    local recruit = Module("recruit")
    recruit.sv.enabled = on
    if not on then recruit:StopTour() end
end

-- The Crier has its own settings page; it is paused while the standalone Fury's Guild Crier is on.
local function OpenCrierSettings()
    if GT.Crier.active then GT.Crier.OpenSettings() else GT.Settings:Open() end
end

-- Every feature on the page, in the order a new officer is likely to want them.
--   get / set   read and change the same saved setting the settings page does
--   reload      true when the change only takes effect after a reload
--   perGuild    true when it only works in guilds ticked in step 1
--   tab         the report tab it belongs to
--   settings    opens its settings
local FEATURES = {
    {
        id = "members", name = "Members", always = true, tab = "members",
        text = "Everyone in your guilds: rank, time in guild, time at rank, last online and note. Search, sort and export.",
        tip = "Always on. Right-click a member there to whisper, mail, set their rank or kick them (every change asks first).",
        settings = function() GT.Settings:OpenRules() end,
    },
    {
        id = "bank", name = "Bank alerts", reload = true, perGuild = true, tab = "bank",
        text = "Lists members who take more from a guild bank in one day than your limits allow.",
        tip = "You decide what happens: warn, demote, kick or dismiss, each with your click. Stacks put back whole don't count.\nLimits and who to ignore are set for each guild on the Guild rules page.",
        get = function() return Module("bank").sv.enabled end,
        set = function(on) Module("bank").sv.enabled = on end,
        settings = function() GT.Settings:OpenRules() end,
    },
    {
        id = "log", name = "History log", reload = true, tab = "log",
        text = "Keeps a searchable record of bank items, bank gold and roster changes in all your guilds, with export.",
        tip = "Bank alerts and Bank hoppers use this log when you click Rescan, so it is worth turning on with them.\nHow long events are kept is in the settings.",
        get = function() return Module("log").sv.enabled end,
        set = function(on) Module("log").sv.enabled = on end,
        settings = function() GT.Settings:Open() end,
    },
    {
        id = "inactive", name = "Inactive members", perGuild = true, tab = "inactive",
        text = "Lists members who have been offline longer than the limit for their rank, so you can free up slots.",
        tip = "Turns inactivity alerts on or off for all your guilds at once. Limits start at 30 days for officers, 21 for members and 14 for recruits.\nTo turn it on for one guild only, or to change a guild's limits, use the Guild rules page.",
        get = InactiveOn,
        set = SetInactive,
        settings = function() GT.Settings:OpenRules() end,
    },
    {
        id = "hoppers", name = "Bank hoppers", reload = true, perGuild = true, tab = "hoppers",
        text = "Lists people who join a guild and leave again soon after, often to empty the bank. Includes your watchlist.",
        tip = "Right-click a hopper to blacklist them or add them to your watchlist.\nHow soon counts as a hop (48 hours to start) is set for each guild on the Guild rules page.",
        get = function() return Module("hoppers").sv.enabled end,
        set = SetHoppers,
        settings = function() GT.Settings:OpenRules() end,
    },
    {
        id = "capacity", name = "Bank space", perGuild = true, tab = "capacity",
        text = "Alerts you when a guild bank is nearly full.",
        tip = "The game only lets an addon count a guild bank while it is open, so open each guild bank once to get its first count.\nHow full counts as nearly full (90% to start) is set for each guild on the Guild rules page.",
        get = function() return Module("capacity").sv.enabled end,
        set = function(on) Module("capacity").sv.enabled = on end,
        settings = function() GT.Settings:OpenRules() end,
    },
    {
        id = "trader", name = "Trader and sales", reload = true, tab = "trader",
        text = "Weekly totals: what the guild trader cost, every bid, sales tax earned, and what each member sold, gave or took.",
        tip = "Fills the Trader and Member sales tabs from the guild history LibHistoire has saved.",
        get = function() return Module("trader").sv.enabled end,
        set = function(on) Module("trader").sv.enabled = on end,
        settings = function() GT.Settings:Open() end,
    },
    {
        id = "recruit", name = "Recruiting", tab = "recruit",
        text = "Zone ads with cooldowns and a tour from zone to zone. The ad waits in your chat box for your Enter.",
        tip = "This switch is for zone ads and the zone tour. Welcome messages, welcome mails and whisper leads are turned on separately on the Recruiting settings page.",
        get = function() return Module("recruit").sv.enabled end,
        set = SetRecruit,
        settings = function() OpenPanel(Module("recruit").panel) end,
    },
    {
        id = "events", name = "Events", tab = "events",
        text = "Paste a Discord sign-up sheet and see who is in your group, who is missing and which slots are open.",
        tip = "Works with sesh posts or any guild's own sign-up sheet. From the tab you can invite everyone online, advertise open slots and list the group in Group Finder.",
        get = function() return Module("events").sv.enabled end,
        set = function(on) Module("events"):SetEnabled(on) end,
        settings = function() OpenPanel(Module("events").panel) end,
    },
    {
        id = "raffle", name = "Raffle", reload = true, tab = "raffle",
        text = "Runs a guild raffle: tickets bought with gold put in a guild bank or mailed to you, and a winners draw.",
        tip = "The prize, ticket price and sale times are on the Raffle settings page.",
        get = function() return Module("raffle").sv.enabled end,
        set = function(on) Module("raffle").sv.enabled = on end,
        settings = function() OpenPanel(Module("raffle").panel) end,
    },
    {
        id = "crier", name = "Guild Crier", always = true, tab = "crier",
        text = "Your saved guild, zone and whisper messages. Click one to load it into chat; you press Enter.",
        tip = "Always on. Open it from the Crier tab, with /crier or with a keybind.",
        settings = OpenCrierSettings,
    },
}

function Setup:Initialize(sv)
    self.sv = sv
    -- What each reload-only switch was when the game loaded: a switch that differs now is waiting
    -- for a reload.
    self.loaded = {}
    for _, feature in ipairs(FEATURES) do
        if feature.reload then self.loaded[feature.id] = feature.get() == true end
    end
    self:RegisterTab()
end

function Setup:OnPlayerActivated()
    -- The guild list is ready by now. A guild ticked or unticked since then gets (or loses) its
    -- Rules section on the Guild rules page after a reload.
    self.loadedGuilds = {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        self.loadedGuilds[guildId] = GT:IsAlertGuild(guildId)
    end
end

function Setup:FeatureWaits(feature)
    return feature.reload == true and (feature.get() == true) ~= self.loaded[feature.id]
end

function Setup:GuildWaits(guildId)
    return self.loadedGuilds ~= nil and self.loadedGuilds[guildId] ~= nil
        and self.loadedGuilds[guildId] ~= GT:IsAlertGuild(guildId)
end

function Setup:NeedsReload()
    for _, feature in ipairs(FEATURES) do
        if self:FeatureWaits(feature) then return true end
    end
    for _, guildId in ipairs(U.GetGuildIds()) do
        if self:GuildWaits(guildId) then return true end
    end
    return false
end

function Setup:ToggleGuild(guildId)
    GT:SetAlertGuild(guildId, not GT:IsAlertGuild(guildId))
    GT.Report:Refresh()
end

function Setup:ToggleFeature(feature)
    if feature.always then return end
    feature.set(not (feature.get() == true))
    GT.Report:Refresh()
end

local function Heading(title, text)
    return { cells = { "", "|c5CC2FF" .. title .. "|r", "|c5CC2FF" .. text .. "|r" } }
end

function Setup:GuildRow(guildId)
    local on = GT:IsAlertGuild(guildId)
    local state = on and (ON .. "ON|r") or (OFF .. "OFF|r")
    local row = {
        cells = {
            state,
            U.GuildName(guildId),
            "|cB4B0D8" .. (on and "You get alerts from this guild." or "No alerts from this guild. Its members and history still show.") .. "|r",
        },
        tooltip = U.GuildName(guildId) .. "\nClick to turn alerts from this guild " .. (on and "off" or "on") .. "."
            .. (self:GuildWaits(guildId) and ("\n" .. WAIT .. "Its Rules section on the Guild rules settings page " .. (on and "appears" or "goes away") .. " after a reload.|r") or ""),
        OnClick = function() self:ToggleGuild(guildId) end,
    }
    return GT.Report.AddMenu(row, {
        { label = on and "Stop alerts from this guild" or "Get alerts from this guild", fn = function() self:ToggleGuild(guildId) end },
        { label = "Open Guild rules settings", fn = function() GT.Settings:OpenRules() end },
    })
end

function Setup:FeatureRow(feature)
    local on = feature.always or feature.get() == true
    local state
    if feature.always then
        state = "|cB4B0D8always on|r"
    elseif self:FeatureWaits(feature) then
        state = WAIT .. (on and "ON after reload" or "OFF after reload") .. "|r"
    elseif on and feature.perGuild and not GT:AnyAlertGuild() then
        state = NOTE .. "ON, no guild|r"
    else
        state = on and (ON .. "ON|r") or (OFF .. "OFF|r")
    end
    local tooltip = feature.name .. "\n" .. feature.tip
    if feature.perGuild then tooltip = tooltip .. "\nOnly works in the guilds turned on in step 1." end
    if feature.reload then tooltip = tooltip .. "\nStarts or stops after a reload." end
    if not feature.always then tooltip = tooltip .. "\nClick to turn it " .. (on and "off" or "on") .. "." end
    local row = {
        cells = { state, feature.name, "|cB4B0D8" .. feature.text .. "|r" },
        tooltip = tooltip,
    }
    local items = {}
    if not feature.always then
        row.OnClick = function() self:ToggleFeature(feature) end
        items[#items + 1] = { label = on and "Turn off" or "Turn on", fn = function() self:ToggleFeature(feature) end }
    end
    items[#items + 1] = { label = "Open its tab", fn = function() GT.Report:SelectTab(feature.tab) end }
    items[#items + 1] = { label = "Open its settings", fn = feature.settings }
    return GT.Report.AddMenu(row, items)
end

function Setup:TabRows()
    local rows = {}
    local guildIds = U.GetGuildIds()
    rows[#rows + 1] = Heading("Step 1: your guilds", "Click the guilds you look after. Bank, hopper, inactivity and bank space alerts only happen in these.")
    if #guildIds == 0 then
        rows[#rows + 1] = { cells = { "", "No guild", "|cB4B0D8You aren't in a guild on this account.|r" } }
    end
    for _, guildId in ipairs(guildIds) do rows[#rows + 1] = self:GuildRow(guildId) end
    rows[#rows + 1] = Heading("Step 2: features", "Click the ones you want. Hover a row for more, right-click it for its tab and its settings.")
    for _, feature in ipairs(FEATURES) do rows[#rows + 1] = self:FeatureRow(feature) end
    rows[#rows + 1] = Heading("Step 3: reload", "If anything says \"after reload\", click Reload to apply below. Then each guild's limits are on the Guild rules page.")
    return rows
end

function Setup:TabSummary()
    if self:NeedsReload() then
        return WAIT .. "Click Reload to apply (bottom left) to start what you changed.|r  Your choices are already saved."
    end
    local on, total, guilds = 0, 0, 0
    for _, feature in ipairs(FEATURES) do
        if not feature.always then
            total = total + 1
            if feature.get() == true then on = on + 1 end
        end
    end
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then guilds = guilds + 1 end
    end
    if on == 0 and guilds == 0 then
        return "Everything starts turned off. Click your guilds, then the features you want. Nothing is done to a member without your click."
    end
    return string.format("%d of %d features are on, with alerts from %d %s. Click a row to turn it on or off; right-click it for its tab and its settings.",
        on, total, guilds, guilds == 1 and "guild" or "guilds")
end

function Setup:TabFooter()
    local footer = {}
    if self:NeedsReload() then
        footer[#footer + 1] = { label = "Reload to apply", tip = "Reloads the interface (a few seconds) so the features and guilds you changed start. Your choices are already saved.",
            fn = function() ReloadUI("ingame") end }
    end
    footer[#footer + 1] = { label = "Settings", tip = "Opens the main settings page (also /gtsettings).", fn = function() GT.Settings:Open() end }
    footer[#footer + 1] = { label = "Guild rules", tip = "Opens the Guild rules settings page: each ticked guild's bank limits, who to ignore, inactivity limits, mail texts and more.",
        fn = function() GT.Settings:OpenRules() end }
    footer[#footer + 1] = { label = "Video tutorial", tip = "Opens the video tutorial in your web browser. The game asks first.",
        fn = function() RequestOpenUnsafeURL(VIDEO_URL) end }
    return footer
end

function Setup:RegisterTab()
    GT.Report:RegisterTab({
        id = "start",
        hidden = true,       -- its button is in the title row (UI/ReportWindow.lua)
        noExport = true,
        noMenuHint = true,   -- the top line says it in its own words
        title = "Start here",
        tip = "Setup in one place: pick your guilds and turn features on or off. Everything starts turned off.",
        columns = {
            { title = "On / off", width = 130, tip = "Click a row to switch it. \"After reload\" means it starts or stops once you click Reload to apply." },
            { title = "What", width = 230 },
            { title = "What it does", width = 760 },
        },
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        footer = function() return self:TabFooter() end,
    })
end
