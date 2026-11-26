-- Bank Capacity: alerts when a guild bank gets close to full.
--
-- API limit: the game only lets an addon read guild bank slots while that bank is open.
-- So the count is taken with GetNumBagUsedSlots when the bank's items are ready
-- (EVENT_GUILD_BANK_ITEMS_READY) and refreshed on every deposit/withdrawal while it is open.
-- Between visits the last count is shown with how long ago it was taken; nothing is guessed
-- from bank history.

local GT = FurysGuildToolset
local U = GT.Util

local BankCapacity = GT:RegisterModule("capacity", {})

local REARM_BELOW_POINTS = 5   -- alert again only after dropping 5 points below the threshold

BankCapacity.defaults = {
    enabled = false,   -- every feature starts turned off on a new install (Albert, 1.3.0)
    alertAtPercent = 90,
    snapshots = {},   -- [guildId] = { used, size, ts }
    alerted = {},     -- [guildId] = true while over the threshold and already alerted
}

-- Settings each guild has its own copy of (see GT:GuildSettings).
BankCapacity.guildKeys = { "alertAtPercent" }

function BankCapacity:AlertAt(guildId)
    return GT:GuildSettings(self, guildId).alertAtPercent
end

function BankCapacity:Initialize(sv)
    self.sv = sv
    sv.deltas = nil   -- 0.4.1 and older kept history-based estimates here
    self:RegisterTab()
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Capacity", EVENT_GUILD_BANK_ITEMS_READY, function() self:TakeSnapshot() end)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Capacity", EVENT_GUILD_BANK_ITEM_ADDED, function() self:TakeSnapshot() end)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Capacity", EVENT_GUILD_BANK_ITEM_REMOVED, function() self:TakeSnapshot() end)
end

-- Real count, only possible while the guild bank window is open.
function BankCapacity:TakeSnapshot()
    local guildId = GetSelectedGuildBankId()
    if not guildId or guildId == 0 then return end
    local size = GetBagSize(BAG_GUILDBANK)
    if not size or size == 0 then return end
    self.sv.snapshots[guildId] = { used = GetNumBagUsedSlots(BAG_GUILDBANK), size = size, ts = GetTimeStamp() }
    self:Check(guildId)
    GT.Report:RefreshIfShown()
end

-- Returns used, size, countedTs; nil if this bank was never opened.
function BankCapacity:GetCount(guildId)
    local snap = self.sv.snapshots[guildId]
    if not snap then return nil end
    return snap.used, snap.size, snap.ts
end

function BankCapacity:Check(guildId)
    if not self.sv.enabled or not GT:IsAlertGuild(guildId) then return end
    local used, size = self:GetCount(guildId)
    if not used then return end
    local percent = math.floor(used * 100 / size)
    local alertAt = self:AlertAt(guildId)
    if percent >= alertAt then
        if not self.sv.alerted[guildId] then
            self.sv.alerted[guildId] = true
            U.Alert(zo_strformat("<<1>> guild bank is <<2>>% full (<<3>>/<<4>> slots).", U.GuildName(guildId), percent,
                used, size))
        end
    elseif percent < alertAt - REARM_BELOW_POINTS then
        self.sv.alerted[guildId] = nil
    end
end

function BankCapacity:DescribeGuild(guildId)
    local used, size, ts = self:GetCount(guildId)
    if not used then return "unknown, open this guild bank once so it can be counted" end
    local percent = math.floor(used * 100 / size)
    local color = percent >= self:AlertAt(guildId) and "FF6666" or "FFFFFF"
    return string.format("|c%s%d%%|r  (%d/%d slots)  counted %s", color, percent, used, size, U.FormatAgo(ts))
end

function BankCapacity:TabRows()
    local rows = {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then
            rows[#rows + 1] = { text = string.format("%s (alert at %d%%):  %s", U.GuildName(guildId), self:AlertAt(guildId), self:DescribeGuild(guildId)) }
        end
    end
    return rows
end

function BankCapacity:TabExportLines()
    local lines = { "Guild\tUsed\tSize\tPercent\tLast counted" }
    for _, guildId in ipairs(U.GetGuildIds()) do
        local used, size, ts = self:GetCount(guildId)
        if used and GT:IsAlertGuild(guildId) then
            lines[#lines + 1] = table.concat({ U.GuildName(guildId), used, size, math.floor(used * 100 / size),
                U.FormatDate(ts) }, "\t")
        end
    end
    return lines
end

function BankCapacity:TabSummary()
    return "Counted each time you open a guild bank. Each guild's alert level is on the Guild rules settings page (/gtsettings > Open Guild rules settings)."
end

function BankCapacity:RegisterTab()
    GT.Report:RegisterTab({
        id = "capacity",
            GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "Bank space alerts", true) end,
        tip = "How full each guild bank is, counted when you open it.",
        title = "Bank space",
        about = {
            "Shows how full each guild bank is and alerts you when one is nearly full.",
            "The game only lets an addon count a guild bank while it is open, so open each guild bank once to get its first count.",
        },
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        GetExportLines = function() return self:TabExportLines() end,
    })
end

function BankCapacity:PrintStatus()
    U.Print("Guild bank space:")
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then
            U.Print("  %s (alert at %d%%): %s", U.GuildName(guildId), self:AlertAt(guildId), self:DescribeGuild(guildId))
        else
            U.Print("  %s: %s", U.GuildName(guildId), self:DescribeGuild(guildId))
        end
    end
end

function BankCapacity:BuildSettings(options)
    local sv, defaults = self.sv, self.defaults
    options[#options + 1] = { type = "submenu", name = "Guild bank space", controls = {
        { type = "checkbox", name = "Alert when a guild bank is nearly full", getFunc = function() return sv.enabled end,
          setFunc = function(v) sv.enabled = v end, default = defaults.enabled },
        { type = "description", text = "The game only shows guild bank slots while the bank is open, so the count is taken each time you open a guild bank. Between visits you see the last count and how long ago it was taken. How full counts as nearly full is set for each guild under Rules for (guild) on the Guild rules page." },
        GT.Settings:RulesButton("Opens the Guild rules page, where each guild's \"nearly full\" level is set."),
    } }
end

-- One guild's bank space alert level, inside that guild's Rules submenu.
function BankCapacity:BuildGuildSettings(controls, guildId)
    local sv, defaults = self.sv, self.defaults
    local g = GT:GuildSettings(self, guildId)
    controls[#controls + 1] = { type = "header", name = "Bank space" }
    controls[#controls + 1] = { type = "slider", name = "Alert when the bank is this full (%)", min = 50, max = 100, step = 1,
        getFunc = function() return g.alertAtPercent end,
        setFunc = function(v) g.alertAtPercent = v; sv.alerted[guildId] = nil end, default = defaults.alertAtPercent,
        disabled = function() return not sv.enabled end }
end
