-- Member anniversaries (1.34.0): notices when a member of a guild you get alerts from reaches
-- 30, 90 or 365 days in the guild (your own list), and puts a congratulations in that guild's
-- chat box for you to press Enter. The addon can't send chat; nothing is posted by itself.
--
-- The join date comes from roster history (the Members tab's "Time in guild"), so it only
-- knows members whose join is in the roster history LibHistoire has saved. A milestone only
-- counts on the day it happens or up to GRACE_DAYS later, so turning this on doesn't bring up
-- every old anniversary at once. Each one is offered once.

local GT = FurysGuildToolset
local U = GT.Util

local Milestones = GT:RegisterModule("milestones", {})
GT.Milestones = Milestones

local DAY = 86400
local YEAR_DAYS = 365
local GRACE_DAYS = 3            -- a milestone missed for up to this many days still counts
local WAIT_KEEP_DAYS = 7        -- a congratulation you haven't said yet is dropped after this
local CHECK_MS = 10 * 60 * 1000 -- look again every 10 minutes
local CHAT_GAP_S = 60           -- a minute between two congratulations put in chat by themselves
local LINK_TYPE = "furygmt"     -- the same chat link type as Recruit (Recruit:OnLink passes these on)

local GUILD_CHANNELS = {
    CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_2, CHAT_CHANNEL_GUILD_3,
    CHAT_CHANNEL_GUILD_4, CHAT_CHANNEL_GUILD_5,
}

ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_CONGRATS", "Anniversaries: put the next congratulation in chat")

local TEXT = "Happy {time} in {guild}, {member}! Thanks for being part of the family."

Milestones.defaults = {
    enabled = false,        -- every feature starts turned off on a new install (Albert's rule)
    days = "30, 90, 365",   -- milestones in days
    yearly = true,          -- also every full year after the first
    onlyOnline = true,      -- offer it only while the member is online (they see guild chat then)
    autoChat = true,        -- put it in the chat box by itself when you aren't typing
    text = TEXT,
    done = {},              -- ["guildId:@name:days"] = when it was offered
    waiting = {},           -- ["guildId:@name:days"] = { guildId =, name =, days =, at = }
}

function Milestones:Initialize(sv)
    self.sv = sv
    self.lastChat = 0
    self:Prune()
    if not sv.enabled then return end
    EVENT_MANAGER:RegisterForUpdate("FurysGuildToolset_Milestones", CHECK_MS, function() self:Check() end)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Milestones", EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, function(_, guildId, name, _, newStatus)
        if newStatus ~= PLAYER_STATUS_OFFLINE then zo_callLater(function() self:Offer(guildId, name) end, 5000) end
    end)
end

function Milestones:OnPlayerActivated()
    if not self.sv.enabled then return end
    -- The roster and the Members tab's join dates are ready by then.
    zo_callLater(function() self:Check() end, 15000)
end

function Milestones:Prune()
    local now = GetTimeStamp()
    for key, at in pairs(self.sv.done) do
        if now - at > 400 * DAY then self.sv.done[key] = nil end
    end
    for key, w in pairs(self.sv.waiting) do
        if now - w.at > WAIT_KEEP_DAYS * DAY then self.sv.waiting[key] = nil end
    end
end

-- "30, 90, 365" -> { 30, 90, 365 }
function Milestones:DayList()
    local list, seen = {}, {}
    for word in tostring(self.sv.days or ""):gmatch("%d+") do
        local n = tonumber(word)
        if n and n > 0 and not seen[n] then
            seen[n] = true
            list[#list + 1] = n
        end
    end
    table.sort(list)
    return list
end

-- "30 days", "1 year", "2 years"
local function TimeText(days)
    if days % YEAR_DAYS == 0 then
        local years = days / YEAR_DAYS
        return years == 1 and "1 year" or string.format("%d years", years)
    end
    return string.format("%d days", days)
end
Milestones.TimeText = TimeText

local function GuildChannel(guildId)
    for i = 1, GetNumGuilds() do
        if GetGuildId(i) == guildId then return GUILD_CHANNELS[i] end
    end
end

local function Key(guildId, name, days)
    return string.format("%d:%s:%d", guildId, name, days)
end

function Milestones:Fill(w)
    local text = self.sv.text ~= "" and self.sv.text or TEXT
    text = text:gsub("{guild}", function() return U.GuildName(w.guildId) end)
    text = text:gsub("{member}", function() return w.name end)
    text = text:gsub("{time}", function() return TimeText(w.days) end)
    return (text:gsub("{days}", function() return tostring(w.days) end))
end

local function IsOnline(guildId, name)
    local index = GetGuildMemberIndexFromDisplayName(guildId, name)
    if not index then return false end
    local _, _, _, status = GetGuildMemberInfo(guildId, index)
    return status ~= PLAYER_STATUS_OFFLINE
end

-- Finds milestones reached in the last GRACE_DAYS days and offers them.
function Milestones:Check()
    if not self.sv.enabled then return end
    local members = GT:GetModule("members")
    local now = GetTimeStamp()
    local dayList = self:DayList()
    local me = GetDisplayName()
    for _, guildId in ipairs(U.GetGuildIds()) do
        local info = GT:IsAlertGuild(guildId) and members.sv.rankInfo[guildId]
        for name, rec in pairs(info or {}) do
            if rec.joined and name ~= me and U.IsMember(guildId, name) then
                local age = now - rec.joined
                local marks = {}
                for _, d in ipairs(dayList) do marks[#marks + 1] = d end
                if self.sv.yearly then
                    local years = math.floor(age / (YEAR_DAYS * DAY))
                    if years >= 1 then marks[#marks + 1] = years * YEAR_DAYS end
                end
                for _, d in ipairs(marks) do
                    local due = rec.joined + d * DAY
                    local key = Key(guildId, name, d)
                    if due <= now and now - due <= GRACE_DAYS * DAY and not self.sv.done[key] and not self.sv.waiting[key] then
                        self.sv.waiting[key] = { guildId = guildId, name = name, days = d, at = now }
                    end
                end
            end
        end
    end
    self:OfferAll()
    GT.Report:RefreshIfShown()
end

function Milestones:OfferAll()
    for _, w in ipairs(self:WaitingList()) do self:Offer(w.guildId, w.name) end
end

-- Waiting congratulations, oldest first.
function Milestones:WaitingList()
    local list = {}
    for key, w in pairs(self.sv.waiting) do
        w.key = key
        list[#list + 1] = w
    end
    table.sort(list, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.key < b.key
    end)
    return list
end

local function Link(label, ...)
    local data = table.concat({ LINK_TYPE, "congrats", ... }, ":")
    return string.format("|c5CC2FF|H1:%s|h[%s]|h|r", data, label)
end

-- Offers this member's waiting milestone (the biggest, when several are waiting): in the chat
-- box when you aren't typing, otherwise a chat line with a link.
function Milestones:Offer(guildId, name)
    if not self.sv.enabled then return end
    local w
    for _, entry in pairs(self.sv.waiting) do
        if entry.guildId == guildId and entry.name == name and (not w or entry.days > w.days) then w = entry end
    end
    if not w then return end
    if self.sv.onlyOnline and not IsOnline(guildId, name) then return end
    local now = GetTimeStamp()
    if self.sv.autoChat and not CHAT_SYSTEM:IsTextEntryOpen() and now - self.lastChat >= CHAT_GAP_S then
        self:Say(w)
    elseif not w.told then
        w.told = true
        U.Print("%s has been in %s for %s. %s", name, U.GuildName(guildId), TimeText(w.days), Link("Say congrats", guildId, name, w.days))
    end
end

-- Puts the congratulation in the guild's chat box. Every other milestone of theirs that was
-- waiting is marked done too, so one member gets one message.
function Milestones:Say(w)
    local channel = GuildChannel(w.guildId)
    if not channel then return end
    for key, entry in pairs(self.sv.waiting) do
        if entry.guildId == w.guildId and entry.name == w.name then
            self.sv.waiting[key] = nil
            self.sv.done[key] = GetTimeStamp()
        end
    end
    self.lastChat = GetTimeStamp()
    StartChatInput(self:Fill(w), channel)
    U.Print("Congratulations for %s (%s in %s) are in the guild chat box. Press Enter to post them.", w.name, TimeText(w.days), U.GuildName(w.guildId))
    GT.Report:RefreshIfShown()
end

-- From the [Say congrats] link (Recruit:OnLink passes it here).
function Milestones:FromLink(guildId, name, days)
    local w = self.sv.waiting[Key(guildId, name, tonumber(days) or 0)]
    if not w then
        U.Print("That congratulation was already said or dismissed.")
        return
    end
    self:Say(w)
end

function Milestones:Dismiss(w)
    for key, entry in pairs(self.sv.waiting) do
        if entry.guildId == w.guildId and entry.name == w.name then
            self.sv.waiting[key] = nil
            self.sv.done[key] = GetTimeStamp()
        end
    end
    GT.Report:RefreshIfShown()
end

-- Keybind and /gt congrats: the oldest waiting congratulation goes in the chat box.
function Milestones:SayNext()
    if not self.sv.enabled then
        U.Print("Member anniversaries are turned off. Turn them on in /gtsettings under Member anniversaries.")
        return
    end
    local list = self:WaitingList()
    if #list == 0 then
        U.Print("No anniversary congratulations are waiting.")
        return
    end
    self:Say(list[1])
end

function Milestones.KeyCongrats() Milestones:SayNext() end

-- The Members tab's footer button: a menu of the waiting congratulations.
function Milestones:FooterButton()
    if not self.sv.enabled then return nil end
    local list = self:WaitingList()
    if #list == 0 then return nil end
    return { label = string.format("Anniversaries (%d)", #list),
        tip = "Members who reached a milestone in the guild. Click to pick one: the congratulation goes in that guild's chat box for you to press Enter.",
        fn = function(button)
            ClearMenu()
            for _, w in ipairs(self:WaitingList()) do
                local online = IsOnline(w.guildId, w.name)
                AddMenuItem(string.format("%s: %s in %s%s", w.name, TimeText(w.days), U.GuildName(w.guildId), online and "" or " (offline)"), function() self:Say(w) end)
            end
            AddMenuItem("Dismiss all", function()
                for _, w in ipairs(self:WaitingList()) do self:Dismiss(w) end
            end)
            ShowMenu(button)
        end }
end

-- Settings ---------------------------------------------------------------------

function Milestones:BuildSettings(options)
    local sv, d = self.sv, self.defaults
    local controls = {
        { type = "description", text = "Starts turned off. When a member of a guild you get alerts from reaches a milestone in the guild, a congratulation goes in that guild's chat box for you to press Enter (or you get a [Say congrats] link while you're typing). The join date comes from roster history, the same as Time in guild on the Members tab, so members who joined before your oldest roster history are left out." },
        { type = "checkbox", name = "Turn on member anniversaries", requiresReload = true,
          tooltip = "Looks for milestones at login and every 10 minutes, in the guilds ticked under Guilds to get alerts from. Each milestone is offered once, on the day or up to 3 days later.",
          getFunc = function() return sv.enabled end, setFunc = function(v) sv.enabled = v end, default = d.enabled },
        { type = "editbox", name = "Milestones (days)",
          tooltip = "Days in the guild, separated by commas. 365 shows as \"1 year\" in the message.",
          getFunc = function() return sv.days end, setFunc = function(v) sv.days = v end, default = d.days,
          disabled = function() return not sv.enabled end },
        { type = "checkbox", name = "Every year after that too",
          tooltip = "Also 2 years, 3 years and so on.",
          getFunc = function() return sv.yearly end, setFunc = function(v) sv.yearly = v end, default = d.yearly,
          disabled = function() return not sv.enabled end },
        { type = "checkbox", name = "Only while they're online",
          tooltip = "Waits until the member is online, so they see the message in guild chat. A congratulation not said within 7 days is dropped.",
          getFunc = function() return sv.onlyOnline end, setFunc = function(v) sv.onlyOnline = v end, default = d.onlyOnline,
          disabled = function() return not sv.enabled end },
        { type = "checkbox", name = "Put it in the chat box by itself",
          tooltip = "On: the congratulation goes straight into the guild chat box when you aren't typing (one a minute at most). Off: you get a [Say congrats] link in chat instead. Either way you press Enter to post it.",
          getFunc = function() return sv.autoChat end, setFunc = function(v) sv.autoChat = v end, default = d.autoChat,
          disabled = function() return not sv.enabled end },
        { type = "editbox", name = "Message", isMultiline = true, isExtraWide = true,
          tooltip = "{member} = their @name, {guild} = the guild's name, {time} = \"30 days\" or \"1 year\", {days} = the number of days.",
          getFunc = function() return sv.text end, setFunc = function(v) sv.text = v end, default = d.text,
          disabled = function() return not sv.enabled end },
    }
    options[#options + 1] = { type = "submenu", name = "Member anniversaries", controls = controls }
end
