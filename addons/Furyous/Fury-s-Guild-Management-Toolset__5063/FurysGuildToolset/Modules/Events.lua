-- Events: sign-ups from a sesh (Discord bot) event post, checked against who is in your group.
--
-- You copy the sesh post in Discord and paste it into the Events tab (Ctrl+V). The tab reads
-- the title, time, CP requirement and every sign-up section with its count and limit, such as
-- "Tank (1 / 2)", "DPS (1 / 8)", "Standby (0)" or "Attendees (4)" for a class with no limit.
-- Each sign-up is matched to an @account (by name, or the account you pick once) and shown as
-- in group, online, or offline.
--
-- Written from the ESO API and the ZOS UI source. What the game lets an addon do here:
--   Chat: an addon can't send chat. Whispers and guild ads go into the chat box with
--   StartChatInput and you press Enter.
--   Group invites: GroupInviteByName runs only when you click Invite.
--   Mail: opens filled in for you to send (GT.Actions.Warn).
--   Group Finder: the listing is filled in the same way the game's own Create window does it
--   (SetGroupFinderUserTypeGroupListing* on the draft, then RequestCreateGroupListing), only
--   after you check the text and press Create listing. Applicants are accepted in the game's
--   Group Finder window, by you.
--   Discord: the addon can't reach Discord. "Copy for Discord" shows the text to copy.
-- Off on a new install.

local GT = FurysGuildToolset
local U = GT.Util
local A = GT.Actions

local Events = GT:RegisterModule("events", {})
GT.Events = Events

local MAX_PASTE = 12000
local MAX_CHAT = 350
local REFRESH_DELAY_MS = 500
local CHAT_EVENT_NAME = "FurysGuildToolset_EventsChat"
local DRAFT = GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT

local GUILD_CHANNELS = {
    CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_2, CHAT_CHANNEL_GUILD_3,
    CHAT_CHANNEL_GUILD_4, CHAT_CHANNEL_GUILD_5,
}

local ROLE_OF_KIND = { tank = LFG_ROLE_TANK, heal = LFG_ROLE_HEAL, dps = LFG_ROLE_DPS }
local ROLE_NAME = { [LFG_ROLE_TANK] = "Tank", [LFG_ROLE_HEAL] = "Healer", [LFG_ROLE_DPS] = "DPS" }
local NEED_WORDS = { tank = { "tank", "tanks" }, heal = { "healer", "healers" }, dps = { "DPS", "DPS" } }

-- Short names people use for trials, so "vSS" in a post finds Sunspire in the Group Finder.
local TRIAL_ALIASES = {
    hrc = "helracitadel", aa = "aetherianarchive", so = "sanctumophidia", mol = "mawoflorkhaj",
    hof = "hallsoffabrication", as = "asylumsanctorium", cr = "cloudrest", ss = "sunspire",
    ka = "kynesaegis", rg = "rockgrove", dsr = "dreadsailreef", se = "sanitysedge",
    lc = "lucentcitadel", oc = "osseincage",
}

Events.defaults = {
    enabled = false,          -- off on a new install (Albert's rule)
    event = nil,              -- the last pasted sign-up post, parsed (see Events.Parse)
    map = {},                 -- [name key] = "@account": the account you picked for a Discord name
    adGuilds = {},            -- [guildId] = true: Advertise puts the ad in that guild's chat box
    whisperText = "Hi {name}, {event} is forming up now. Are you still coming? I can send you an invite.",
    mailSubject = "{event} is starting",
    mailText = "Hi {name},\n\nYou signed up for {event} ({time}) and we're forming up now. If you can still make it, log in and whisper {me} for an invite.\n\nThanks!",
    -- Once the group forms: the ad for replacements, join now (1.12.1 wording from Albert).
    adText = "Sign up for {event}, {time}{cp}! Still open: {need}. Type {code} into guild chat or whisper {me}.",
    -- 1.12.0: before the group forms, ads ask people to sign up for the slots nobody has taken.
    signupAdText = "Sign up for {event}, {time}{cp}! Still open: {need}. Sign up in our Discord",
    formUpMinutes = 15,       -- the group forms this many minutes before the start time
    -- 1.12.1: once the group forms, someone who types the invite code in a ticked guild's chat
    -- (or whispers it) gets a group invite. Off on a new install.
    autoInvite = false,
    inviteCode = "X",        -- 1.13.2: was "+trial"
}

-- Ad texts that were the default in an earlier version. A saved text still equal to one of
-- them was never changed, so it moves to the new default.
local OLD_DEFAULTS = {
    adText = { "LFM {need} for {event}{cp}. Whisper {me} for an invite!" },
    signupAdText = { "Sign up for {event}, {time}{cp}! Still open: {need}. Sign up in our Discord or whisper {me}." },
    inviteCode = { "+trial" },
}

local CODE_EVENT_NAME = "FurysGuildToolset_EventsCode"
local CODE_HOURS_AFTER_START = 2   -- the invite code works until this long after the start time
local MAX_GROUP = 12

Events.columns = {
    { title = "Signed up as", width = 130, tip = "The sign-up section in the sesh post (Tank, Healer, DPS, Standby, Attendees...)." },
    { title = "Discord name", width = 220, tip = "The name in the sesh post." },
    { title = "Account", width = 200, tip = "Their ESO @account. Matched by name, or the one you picked with right-click > Set account." },
    { title = "Status", width = 300, tip = "In group, online (in one of your guilds or on your friends list), or offline and for how long." },
    { title = "Group role", width = 100, tip = "The role they picked in the group (from the group window)." },
    { title = "CP", width = 70, tip = "Their champion points, while they are in your group. Red when under the post's CP requirement." },
}

-- Text helpers ---------------------------------------------------------------------

local function Trim(text)
    return zo_strtrim(tostring(text or ""))
end

-- One Unicode code point as plain a-z / 0-9, or nil. Covers ASCII, the "fancy" math letters
-- Discord names often use (𝖩𝖮𝖤 is U+1D5A9...) and full-width letters.
local function AsciiFor(cp)
    if (cp >= 48 and cp <= 57) or (cp >= 97 and cp <= 122) then return string.char(cp) end
    if cp >= 65 and cp <= 90 then return string.char(cp + 32) end
    if cp >= 0x1D400 and cp <= 0x1D6A3 then return string.char(97 + ((cp - 0x1D400) % 52) % 26) end
    if cp >= 0x1D7CE and cp <= 0x1D7FF then return string.char(48 + (cp - 0x1D7CE) % 10) end
    if cp >= 0xFF21 and cp <= 0xFF3A then return string.char(97 + cp - 0xFF21) end
    if cp >= 0xFF41 and cp <= 0xFF5A then return string.char(97 + cp - 0xFF41) end
    if cp >= 0xFF10 and cp <= 0xFF19 then return string.char(48 + cp - 0xFF10) end
    return nil
end

-- "Marth Wolf" -> "marthwolf", "@Bmguyen18458" -> "bmguyen18458", "𝖩𝖮𝖤𝖲𝖲𝖠𝖭" -> "joessan".
-- Used to compare Discord names with account names.
local function Norm(text)
    local s = tostring(text or "")
    local out, i, n = {}, 1, #s
    while i <= n do
        local c = s:byte(i)
        local cp, len
        if c < 0x80 then
            cp, len = c, 1
        elseif c >= 0xF0 then
            cp = (c % 8) * 262144 + ((s:byte(i + 1) or 128) % 64) * 4096 + ((s:byte(i + 2) or 128) % 64) * 64 + ((s:byte(i + 3) or 128) % 64)
            len = 4
        elseif c >= 0xE0 then
            cp = (c % 16) * 4096 + ((s:byte(i + 1) or 128) % 64) * 64 + ((s:byte(i + 2) or 128) % 64)
            len = 3
        elseif c >= 0xC0 then
            cp = (c % 32) * 64 + ((s:byte(i + 1) or 128) % 64)
            len = 2
        else
            cp, len = 0, 1
        end
        local ch = AsciiFor(cp)
        if ch then out[#out + 1] = ch end
        i = i + len
    end
    return table.concat(out)
end
Events.Norm = Norm

-- Drops characters the game font can't show (emoji and other 4-byte characters).
local function Printable(text)
    return (tostring(text or ""):gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", ""))
end

-- A line with leading symbols (emoji, bullets) removed, for spotting headers like "Tank (1 / 2)".
local function Bare(line)
    line = Printable(line):gsub("%[%+%]", "")
    line = line:gsub("^[^%w@%(]+", "")
    return Trim(line)
end

local function Fill(template, values)
    return (tostring(template or ""):gsub("{(%w+)}", function(key)
        local value = values[key]
        if value == nil then return "{" .. key .. "}" end
        return tostring(value)
    end))
end

-- The CP requirement in a text: "600 CP", "600cp", "CP 600", "CP: 1800+". 0 when none.
function Events.FindCP(text)
    local plain = " " .. tostring(text or ""):gsub("[\128-\255]+", " ") .. " "
    for number, after in plain:gmatch("(%d+)%s*[Cc][Pp](.)") do
        if not after:find("%a") then return tonumber(number) end
    end
    for before, number in plain:gmatch("(.)[Cc][Pp]%s*:?%s*(%d+)") do
        if not before:find("%a") then return tonumber(number) end
    end
    return 0
end

-- The event's start time as a timestamp, from the Time line Discord shows in your own time
-- zone: "Wednesday, November 25, 2026 20:00", "November 25, 2026 8:00 PM" or
-- "25 November 2026 20:00". nil when it can't be read.
local MONTHS = { jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12 }
function Events.StartTime(text)
    if not text then return nil end
    local lower = zo_strlower(text)
    local monthName, day, year = lower:match("(%a+)%s+(%d%d?),?%s+(%d%d%d%d)")
    local month = monthName and MONTHS[monthName:sub(1, 3)]
    if not month then
        day, monthName, year = lower:match("(%d%d?)%.?%s+(%a+)%s+(%d%d%d%d)")
        month = monthName and MONTHS[monthName:sub(1, 3)]
    end
    local hour, minute = lower:match("(%d%d?):(%d%d)")
    if not month or not hour then return nil end
    hour = tonumber(hour)
    local half = lower:match("%d:%d%d%s*([ap])%.?m")
    if half == "p" and hour < 12 then hour = hour + 12 elseif half == "a" and hour == 12 then hour = 0 end
    return os.time({ year = tonumber(year), month = month, day = tonumber(day), hour = hour, min = tonumber(minute), sec = 0 })
end

-- Parsing a sesh post ----------------------------------------------------------------

local LABELS = { time = true, duration = true, ["repeat"] = true, ["repeats"] = true, ["when"] = true }

local function KindOf(name)
    local low = zo_strlower(name)
    if low:find("tank") then return "tank" end
    if low:find("heal") then return "heal" end
    if low:find("dps") or low:find("damage") or low:find("^dd") then return "dps" end
    if low:find("standby") or low:find("bench") or low:find("reserve") or low:find("tentative") or low:find("maybe")
        or low:find("late") or low:find("backup") or low:find("sub") then return "standby" end
    if low:find("absent") or low:find("declin") or low:find("can'?t") or low:find("cannot") or low:find("not ")
        or low == "no" then return "out" end
    return "any"
end

local BARE_HEADERS = {
    standby = true, bench = true, reserve = true, reserves = true, tentative = true, maybe = true,
    late = true, backup = true, backups = true, absent = true, declined = true,
}

-- "Tank (1 / 2)" -> "Tank", 1, 2. "Attendees (4)" -> "Attendees", 4, nil. Otherwise nil.
local function Header(line)
    local bare = Bare(line)
    local name, count, max = bare:match("^(.-)%s*%(%s*(%d+)%s*/%s*(%d+)%s*%)$")
    if not name then
        name, count = bare:match("^(.-)%s*%(%s*(%d+)%s*%)$")
    end
    if not name then
        -- 1.16.11: sesh leaves the count off an empty section at the end ("Standby").
        if BARE_HEADERS[zo_strlower(bare)] then return bare, nil, nil end
        return nil
    end
    if name == "" or #name > 40 or not name:find("%a") then return nil end
    return name, tonumber(count), max and tonumber(max) or nil
end

-- "Furyous (Albert)" -> { raw =, base = "Furyous", nick = "Albert", key = "furyous" }
local function Person(raw)
    raw = Trim(raw)
    raw = raw:gsub("^%d+[%.%)]%s+", "")
    raw = raw:gsub("^[%-%*]%s+", "")
    raw = Trim((raw:gsub("^\226\128\162%s*", "")))
    local base, nick = raw:match("^(.-)%s*%((.-)%)$")
    base = Trim(base or raw)
    -- "sshogrin, barcabeagle, (sho)": one sign-up whose Discord name lists several names
    -- (1.16.11). The first is the name, the others are tried for the account too.
    local alts = {}
    if base:find(",", 1, true) then
        local parts = {}
        for part in (base .. ","):gmatch("([^,]*),") do
            part = Trim(part)
            if part ~= "" then parts[#parts + 1] = part end
        end
        base = parts[1] or ""
        for i = 2, #parts do alts[#alts + 1] = Norm(parts[i]) end
    end
    local key = Norm(base)
    if key == "" then key = zo_strlower(base) end
    return { raw = raw, base = base, nick = nick and Trim(nick) or nil, key = key, alts = alts }
end

-- Reads a pasted sesh post. Returns the event table, or nil and a reason.
function Events.Parse(text)
    local lines = {}
    for line in (tostring(text or ""):gsub("\r", "") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = Trim(line) end

    local ev = { sections = {}, desc = {}, requirements = {}, pastedAt = GetTimeStamp() }
    local first
    for i, line in ipairs(lines) do
        if Bare(line) ~= "" then first = i; break end
    end
    if not first then return nil, "The text is empty." end
    ev.title = Bare(lines[first])

    -- Time, Duration and Repeat are a label line followed by the value.
    local infoStart
    for i = first + 1, #lines do
        local label = zo_strlower(Bare(lines[i]))
        if LABELS[label] then
            infoStart = infoStart or i
            local value
            for j = i + 1, #lines do
                if lines[j] ~= "" then value = lines[j]; break end
            end
            if value then
                value = Trim(Printable(value):gsub("%[%+%]", ""):gsub("%s*%(in [^%)]*%)", ""))
                if label == "time" or label == "when" then ev.time = value
                elseif label == "duration" then ev.duration = value
                else ev.repeatText = value end
            end
        end
    end

    -- Sign-up sections: a header with a count, then one name per line ("-" = nobody).
    local section
    local valueLine = {}
    for i = 1, #lines do
        if LABELS[zo_strlower(Bare(lines[i]))] then
            for j = i + 1, #lines do
                if lines[j] ~= "" then valueLine[j] = true; break end
            end
        end
    end
    for i = (infoStart or first + 1), #lines do
        local line = lines[i]
        local name, count, max = Header(line)
        if name and not valueLine[i] then
            section = { name = name, kind = KindOf(name), count = count, max = max, people = {}, lines = {} }
            ev.sections[#ev.sections + 1] = section
        elseif section and line ~= "" and line ~= "-" and not LABELS[zo_strlower(Bare(line))] and not valueLine[i] then
            section.lines[#section.lines + 1] = line
        end
    end
    -- One sign-up per line. A line is split at commas into several people only when the
    -- section's count says there are more people than lines (1.16.11: "sshogrin, barcabeagle,
    -- (sho)" is one tank in "Tank (2 / 2)").
    for _, sec in ipairs(ev.sections) do
        local split = not sec.count or #sec.lines < sec.count
        for _, line in ipairs(sec.lines) do
            local parts = {}
            if split then
                for part in (line .. ","):gmatch("([^,]+),") do parts[#parts + 1] = part end
            else
                parts[1] = line
            end
            for _, part in ipairs(parts) do
                local person = Person(part)
                if person.base ~= "" and person.base ~= "-" then sec.people[#sec.people + 1] = person end
            end
        end
        sec.lines = nil
    end
    if #ev.sections == 0 then
        return nil, "No sign-up sections found. Copy the whole sesh post, down to the last name under the last role."
    end

    -- Description: everything between the title and the Time line (or the first section).
    local descEnd = (infoStart or #lines + 1) - 1
    for i = first + 1, descEnd do ev.desc[#ev.desc + 1] = Printable(lines[i]) end

    -- CP: "160 CP", "CP 160", "CP: 1800+".
    local whole = table.concat(ev.desc, "\n")
    -- 1.16.3: no %f patterns (the game read "600 CP" as no CP), and odd spaces or symbols
    -- (Discord's non-breaking spaces, emoji) count as spaces.
    ev.minCP = Events.FindCP(whole)

    -- Requirements: the short lines under a line that says "required" or "requirements".
    local inList = false
    for _, line in ipairs(ev.desc) do
        local low = zo_strlower(line)
        if low:find("requir") then
            inList = true
        elseif inList then
            local bare = Bare(line)
            if bare == "" or #bare > 40 then
                if #ev.requirements > 0 then inList = false end
            elseif not bare:find("%d+%s*[Cc][Pp]") then
                ev.requirements[#ev.requirements + 1] = bare
            end
        end
    end
    return ev
end

-- Settings and lifecycle ---------------------------------------------------------------

function Events:Initialize(sv)
    self.sv = sv
    -- Invite by code starts turned off at every login and /reloadui (1.24.1, Albert): it's only on
    -- from a click until the group fills or breaks up.
    sv.autoInvite = false
    sv.codeSize = nil
    for key, olds in pairs(OLD_DEFAULTS) do
        for _, old in ipairs(olds) do
            if sv[key] == old then sv[key] = Events.defaults[key] end
        end
    end
    self:RegisterTab()
    SCENE_MANAGER:RegisterTopLevel(FurysGuildToolset_EventsInput, false)
    FurysGuildToolset_EventsInputTextBox:SetMaxInputChars(MAX_PASTE)
    FurysGuildToolset_EventsInputTextBox:SetMultiLine(true)
    FurysGuildToolset_EventsInputTextBox:SetNewLineEnabled(true)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_EventsListing", EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT,
        function(_, result) self:OnListingResult(result) end)
    self:RegisterWatch()
    self:RegisterCode()
end

-- Group and online changes refresh the tab while it's showing. Only while the feature is on.
local WATCH_EVENTS = {
    EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT, EVENT_GROUP_MEMBER_ROLE_CHANGED, EVENT_GROUP_UPDATE,
    EVENT_GROUP_MEMBER_CONNECTED_STATUS, EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, EVENT_FRIEND_PLAYER_STATUS_CHANGED,
}

function Events:RegisterWatch()
    for i, event in ipairs(WATCH_EVENTS) do
        local name = "FurysGuildToolset_EventsWatch" .. i
        EVENT_MANAGER:UnregisterForEvent(name, event)
        if self.sv.enabled then
            EVENT_MANAGER:RegisterForEvent(name, event, function() self:QueueRefresh() end)
        end
    end
end

function Events:QueueRefresh()
    if self.refreshQueued then return end
    self.refreshQueued = true
    zo_callLater(function()
        self.refreshQueued = false
        if GT.Report.currentTab == "events" then GT.Report:RefreshIfShown() end
    end, REFRESH_DELAY_MS)
end

function Events:SetEnabled(on)
    self.sv.enabled = on
    self:RegisterWatch()
    self:RegisterCode()
    GT.Report:RefreshIfShown()
end

-- Who is who -----------------------------------------------------------------------------

-- Everyone in your guilds and on your friends list, by Norm(account): { name, status, secs }.
-- Online beats offline when someone is in several guilds.
function Events:BuildIndex()
    local index = {}
    local function Add(name, status, secs, note)
        local key = Norm(name)
        local known = index[key]
        if not known then
            index[key] = { name = name, status = status, secs = secs or 0, notes = note and { note } or {} }
        else
            if known.status == PLAYER_STATUS_OFFLINE and status ~= PLAYER_STATUS_OFFLINE then
                known.status = status
                known.secs = 0
            elseif status == PLAYER_STATUS_OFFLINE and known.status == PLAYER_STATUS_OFFLINE then
                known.secs = math.min(known.secs, secs or known.secs)
            end
            if note then known.notes[#known.notes + 1] = note end
        end
    end
    for _, guildId in ipairs(U.GetGuildIds()) do
        for i = 1, GetNumGuildMembers(guildId) do
            local name, note, _, status, secs = GetGuildMemberInfo(guildId, i)
            Add(name, status, secs, note ~= "" and note or nil)
        end
    end
    for i = 1, GetNumFriends() do
        local name, _, status, secs = GetFriendInfo(i)
        Add(name, status, secs)
    end
    return index
end

-- Who is in your group, by Norm(account): { name, role, cp, online }. You count even when solo.
function Events:BuildGroup()
    local group, count = {}, 0
    local size = GetGroupSize()
    for i = 1, size do
        local tag = GetGroupUnitTagByIndex(i)
        if tag then
            local name = GetUnitDisplayName(tag)
            group[Norm(name)] = { name = name, role = GetGroupMemberSelectedRole(tag), cp = GetUnitChampionPoints(tag), online = IsUnitOnline(tag) }
            count = count + 1
        end
    end
    local me = GetDisplayName()
    if not group[Norm(me)] then
        group[Norm(me)] = { name = me, role = GetSelectedLFGRole(), cp = GetUnitChampionPoints("player"), online = true }
        count = count + 1
    end
    return group, count
end

-- The @account for a sign-up: the one you picked, the one typed in the post, or a match by name.
-- Returns account, how ("picked", "post", "name") or nil.
function Events:AccountFor(person, index, group)
    local picked = self.sv.map[person.key]
    if picked and picked ~= "" then return picked, "picked" end
    if person.base:sub(1, 1) == "@" then return person.base, "post" end
    local keys = { person.key }
    for _, alt in ipairs(person.alts or {}) do keys[#keys + 1] = alt end
    if person.nick then keys[#keys + 1] = Norm(person.nick) end
    -- Someone already in the group wins over a guild member with a matching name.
    for _, key in ipairs(keys) do
        if key ~= "" and group[key] then return group[key].name, "name" end
    end
    for _, key in ipairs(keys) do
        if key ~= "" and index[key] then return index[key].name, "name" end
    end
    return nil
end

-- Up to four accounts that look like this Discord name, for the right-click menu.
function Events:Suggestions(person, index)
    local found, seen = {}, {}
    local keys = { person.key }
    if person.nick then keys[#keys + 1] = Norm(person.nick) end
    local function Try(name)
        if #found < 4 and not seen[name] then
            seen[name] = true
            found[#found + 1] = name
        end
    end
    for _, key in ipairs(keys) do
        if #key >= 4 then
            for accountKey, entry in pairs(index) do
                if accountKey:find(key, 1, true) or (#accountKey >= 4 and key:find(accountKey, 1, true)) then Try(entry.name) end
            end
            for _, entry in pairs(index) do
                for _, note in ipairs(entry.notes) do
                    if Norm(note):find(key, 1, true) then Try(entry.name) end
                end
            end
        end
    end
    table.sort(found)
    return found
end

-- note: added to the chat line, like " (checked: in nUber, online)".
function Events:SetAccount(person, account, note)
    self.cache = nil
    account = U.NormalizeName(account)
    -- "" too: NormalizeName leaves an empty name empty (1.21.0; Forget used to save "").
    if account == "" or account == "@" then
        self.sv.map[person.key] = nil
        U.Print("Forgot the account for %s.", person.base)
    else
        self.sv.map[person.key] = account
        U.Print("%s is now matched to %s%s.", person.base, account, note or "")
    end
    GT.Report:RefreshIfShown()
end

-- The state of the event right now ------------------------------------------------------

local function StatusText(info, entry)
    if info.inGroup then
        local text = "|c5EE6A0In group|r"
        if entry.role and info.groupRole ~= LFG_ROLE_INVALID and info.groupRole ~= entry.role then
            text = string.format("|cFFA45CIn group as %s|r", ROLE_NAME[info.groupRole] or "?")
        end
        if not info.online then text = text .. " |cB4B0D8(disconnected)|r" end
        return text
    end
    if not info.account then return "|cB4B0D8No account matched. Right-click to set it.|r" end
    if not info.status then return "|cB4B0D8Not in your guilds or friends|r" end
    if info.status == PLAYER_STATUS_OFFLINE then
        return "|cB4B0D8Offline " .. U.FormatDuration(info.secs) .. "|r"
    end
    if info.status == PLAYER_STATUS_AWAY then return "|cFFC857Online (away), not in group|r" end
    if info.status == PLAYER_STATUS_DO_NOT_DISTURB then return "|cFFC857Online (busy), not in group|r" end
    return "|cFFC857Online, not in group|r"
end

-- Everything the tab and the buttons need: one entry per sign-up, the walk-ins, counts and
-- open slots. Built fresh each time (group and online status change all the time).
function Events:State()
    local ev = self.sv.event
    if not ev then return nil end
    -- The tab title, summary and rows all ask in the same refresh: build it once per frame.
    local frame = GetFrameTimeMilliseconds()
    if self.cache and self.cacheFrame == frame and self.cache.ev == ev then return self.cache end
    local state = self:BuildState(ev)
    self.cache, self.cacheFrame = state, frame
    return state
end

function Events:BuildState(ev)
    -- 1.16.4: read the CP again every time, so a post pasted with an older version gets it too.
    ev.minCP = Events.FindCP(table.concat(ev.desc, "\n"))
    local index = self:BuildIndex()
    local group, groupCount = self:BuildGroup()
    local state = { ev = ev, entries = {}, walkIns = {}, missing = {}, open = {}, here = {}, groupCount = groupCount, index = index }
    local matched = {}
    local roleCount = {}
    for _, member in pairs(group) do roleCount[member.role] = (roleCount[member.role] or 0) + 1 end

    for _, section in ipairs(ev.sections) do
        state.here[section] = 0
        for _, person in ipairs(section.people) do
            local account, how = self:AccountFor(person, index, group)
            local key = account and Norm(account) or nil
            local member = key and group[key] or nil
            local known = key and index[key] or nil
            local info = {
                person = person, section = section, account = account, how = how,
                inGroup = member ~= nil, groupRole = member and member.role or nil, cp = member and member.cp or nil,
                online = member and member.online or nil,
                status = known and known.status or nil, secs = known and known.secs or 0,
            }
            info.statusText = StatusText(info, { role = ROLE_OF_KIND[section.kind] })
            if key then matched[key] = true end
            if member then state.here[section] = state.here[section] + 1 end
            state.entries[#state.entries + 1] = info
            if not member and section.kind ~= "standby" and section.kind ~= "out" then state.missing[#state.missing + 1] = info end
        end
    end

    for key, member in pairs(group) do
        if not matched[key] then
            state.walkIns[#state.walkIns + 1] = { account = member.name, inGroup = true, groupRole = member.role, cp = member.cp, online = member.online }
        end
    end
    table.sort(state.walkIns, function(a, b) return a.account < b.account end)

    -- Two counts of open slots (1.12.0):
    -- openSignup: the sign-up slots nobody has taken. A role's limit minus the people signed up
    --   for it, minus anyone in your group who didn't sign up but plays that role. Sign-ups who
    --   aren't here yet keep their slot. For ads before the group forms ("sign up").
    -- openNow: the slots nobody in your group fills now. A role's limit minus the people in your
    --   group playing that role, so no-shows count as open. For ads once the group forms
    --   ("replacements, join now").
    -- A section with no role (Attendees) and a limit counts everyone.
    local walkInRole = {}
    for _, info in ipairs(state.walkIns) do walkInRole[info.groupRole] = (walkInRole[info.groupRole] or 0) + 1 end
    local maxOf, signedOf = {}, {}
    local anyMax, anySigned = 0, 0
    for _, section in ipairs(ev.sections) do
        if section.max then
            if ROLE_OF_KIND[section.kind] then
                maxOf[section.kind] = (maxOf[section.kind] or 0) + section.max
                signedOf[section.kind] = (signedOf[section.kind] or 0) + #section.people
            elseif section.kind == "any" then
                anyMax = anyMax + section.max
                anySigned = anySigned + #section.people
            end
        end
    end
    state.openSignup, state.openNow = {}, {}
    for kind, max in pairs(maxOf) do
        local role = ROLE_OF_KIND[kind]
        state.openSignup[kind] = math.max(0, max - signedOf[kind] - (walkInRole[role] or 0))
        state.openNow[kind] = math.max(0, max - (roleCount[role] or 0))
    end
    if anyMax > 0 then
        state.openSignup.any = math.max(0, anyMax - anySigned - #state.walkIns)
        state.openNow.any = math.max(0, anyMax - groupCount)
    end
    -- Which one fits now: replacements from the time the group forms (start time minus the
    -- "forms up" minutes in the settings), sign-ups before that or when the time can't be read.
    state.startTs = Events.StartTime(ev.time)
    state.formUpTs = state.startTs and (state.startTs - (self.sv.formUpMinutes or 15) * 60)
    state.mode = (state.formUpTs and GetTimeStamp() >= state.formUpTs) and "now" or "signup"
    state.open = state.mode == "now" and state.openNow or state.openSignup
    state.roleCount = roleCount
    return state
end

-- "1 tank, 2 healers, 7 DPS", or "" when no section has a limit. open: state.openSignup or
-- state.openNow (default: the one that fits now).
function Events:NeedText(state, open)
    open = open or state.open
    local parts = {}
    for _, kind in ipairs({ "tank", "heal", "dps" }) do
        local n = open[kind]
        if n and n > 0 then parts[#parts + 1] = string.format("%d %s", n, NEED_WORDS[kind][n == 1 and 1 or 2]) end
    end
    if open.any and open.any > 0 then parts[#parts + 1] = string.format("%d more", open.any) end
    return table.concat(parts, ", ")
end

-- "3d 4h 30m from now", "starting now" or "started 10m ago": the same for everyone, whatever
-- their time zone (1.13.1). Counted when the text is made.
local function Relative(ts)
    local diff = ts - GetTimeStamp()
    local secs = math.abs(diff)
    if secs < 60 then return "starting now" end
    local days, hours, minutes = math.floor(secs / 86400), math.floor(secs % 86400 / 3600), math.floor(secs % 3600 / 60)
    local parts = {}
    if days > 0 then parts[#parts + 1] = days .. "d" end
    if hours > 0 then parts[#parts + 1] = hours .. "h" end
    if minutes > 0 then parts[#parts + 1] = minutes .. "m" end
    local text = table.concat(parts, " ")
    return diff > 0 and (text .. " from now") or ("started " .. text .. " ago")
end

function Events:Values(state, name, open)
    local ev = state.ev
    local need = self:NeedText(state, open)
    return {
        event = ev.title, time = state.startTs and Relative(state.startTs) or ev.time or "now", date = ev.time or "", me = GetDisplayName(), name = name or "",
        need = need ~= "" and need or "more people",
        cp = (ev.minCP or 0) > 0 and string.format(" (CP %d+)", ev.minCP) or "",
        code = self.sv.inviteCode or Events.defaults.inviteCode,
    }
end

-- The tab ------------------------------------------------------------------------------------

function Events:RegisterTab()
    GT.Report:RegisterTab({
        id = "events",
        title = function() return self:TabTitle() end,
        tip = "Sign-ups from a sesh event post in Discord, checked against who is in your group: who is missing, open slots, invites, guild ads and a Group Finder listing.",
        GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "Events") end,
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        columns = Events.columns,
        footer = function() return self:TabFooter() end,
        GetExportLines = function() return self:TabExportLines() end,
        topBar = function() return self:CodeBar() end,
        UpdateTopBar = function() self:UpdateCodeBar() end,
    })
end

function Events:TabTitle()
    if not self.sv.enabled or not self.sv.event then return "Events" end
    local state = self:State()
    return #state.missing > 0 and string.format("Events (%d)", #state.missing) or "Events"
end

-- "8:45 PM", or "Wed 8:45 PM" when it isn't today.
local function Clock(ts)
    local text = os.date("%I:%M %p", ts):gsub("^0", "")
    if os.date("%Y%m%d", ts) ~= os.date("%Y%m%d", GetTimeStamp()) then text = os.date("%a ", ts) .. text end
    return text
end

function Events:TabSummary()
    if not self.sv.enabled then return "" end
    local state = self:State()
    if not state then
        return "Copy a sesh sign-up post in Discord (select it from the title down to the last name), click Paste sign-ups and press Ctrl+V."
    end
    local ev = state.ev
    local parts = {}
    for _, section in ipairs(ev.sections) do
        if section.kind ~= "out" then
            local here = section.kind ~= "standby" and string.format(", %d here", state.here[section]) or ""
            parts[#parts + 1] = string.format("%s %d%s%s", section.name, #section.people,
                section.max and ("/" .. section.max) or "", here)
        end
    end
    local line = string.format("|cECEAF8%s|r%s.  %s.", ev.title, ev.time and (", " .. ev.time) or "", table.concat(parts, "; "))
    if (ev.minCP or 0) > 0 then line = line .. string.format("  CP %d+.", ev.minCP) end
    local signup, now = self:NeedText(state, state.openSignup), self:NeedText(state, state.openNow)
    if next(state.openNow) == nil then
        -- No section has a limit (a class with Attendees only): no open slots to show.
    elseif state.mode == "now" then
        line = line .. "  |cECEAF8Need now:|r " .. (now ~= "" and now or "nobody") .. "."
        if signup ~= "" then line = line .. "  Sign-up slots nobody took: " .. signup .. "." end
    else
        line = line .. "  |cECEAF8Open sign-up slots:|r " .. (signup ~= "" and signup or "none") .. "."
        if state.formUpTs then
            line = line .. string.format("  Ads ask for replacements from %s.", Clock(state.formUpTs))
        end
    end
    return line
end

local function CpText(info, minCP)
    if not info.cp then return "" end
    if minCP and minCP > 0 and info.cp < minCP then return "|cFF6B86" .. info.cp .. "|r" end
    return tostring(info.cp)
end

function Events:TabRows()
    if not self.sv.enabled then return {} end
    local state = self:State()
    if not state then return {} end
    local rows = {}
    local minCP = state.ev.minCP
    for _, info in ipairs(state.entries) do
        local person = info.person
        local accountText = info.account or "|cB4B0D8?|r"
        local tip
        if info.how == "name" then
            tip = string.format("%s was matched to %s by name. Right-click > Set account if that's the wrong person.", person.raw, info.account)
        elseif info.how == "picked" then
            tip = string.format("You matched %s to %s.", person.raw, info.account)
        end
        if (minCP or 0) > 0 and info.cp and info.cp < minCP then
            tip = (tip and (tip .. "\n") or "") .. string.format("Under the CP requirement (%d).", minCP)
        end
        local row = {
            cells = { info.section.name, person.raw, accountText, info.statusText, info.groupRole and (ROLE_NAME[info.groupRole] or "-") or "", CpText(info, minCP) },
            tooltip = tip,
        }
        rows[#rows + 1] = GT.Report.AddMenu(row, self:MenuItems(info, state))
    end
    for _, info in ipairs(state.walkIns) do
        local row = {
            cells = { "|cB4B0D8Not signed up|r", "", info.account, "|c5EE6A0In group|r", ROLE_NAME[info.groupRole] or "-", CpText(info, minCP) },
            tooltip = "In your group but not in the sesh post, or not matched to a sign-up yet.",
        }
        rows[#rows + 1] = GT.Report.AddMenu(row, GT.Report.ContactItems(info.account))
    end
    return rows
end

function Events:MenuItems(info, state)
    local items = {}
    local account = info.account
    local values = self:Values(state, info.person.base)
    if account and account ~= GetDisplayName() then
        items[#items + 1] = { label = "Whisper " .. account, fn = function() A.Warn(account, "", Fill(self.sv.whisperText, values), "whisper") end }
        if not info.inGroup then
            items[#items + 1] = { label = "Invite " .. account .. " to the group", fn = function() self:Invite(account) end }
        end
        items[#items + 1] = { label = "Mail " .. account, fn = function() A.Warn(account, Fill(self.sv.mailSubject, values), Fill(self.sv.mailText, values), "mail") end }
    end
    if account then items[#items + 1] = GT.Report.CopyItem(account) end
    if info.person.base ~= "" and info.person.base ~= account then items[#items + 1] = GT.Report.CopyItem(info.person.base) end
    if info.how ~= "picked" and info.how ~= "post" then
        for _, name in ipairs(self:Suggestions(info.person, state.index)) do
            if name ~= account then
                items[#items + 1] = { label = "Set account: " .. name, fn = function() self:SetAccount(info.person, name) end }
            end
        end
    end
    items[#items + 1] = { label = "Set account (type it)...", tip = "Type their @account. It's checked against your guilds, friends and group before it's saved.", fn = function() self:AskAccount(info.person, account) end }
    if info.how == "picked" then
        items[#items + 1] = { label = "Forget the account for " .. info.person.base, fn = function() self:SetAccount(info.person, "") end }
    end
    return items
end

function Events:TabFooter()
    if not self.sv.enabled then return {} end
    return {
        { label = "Paste sign-ups", width = 150, tip = "Opens a box to paste a sesh event post into (Ctrl+V). Replaces the event shown now.", fn = function() self:AskPaste() end },
        { label = "Clear", width = 90, tip = "Clears the event shown now, for when it's over. The accounts you matched to Discord names are kept for the next event.", fn = function() self:ClearEvent() end },
        { label = "Invite online", width = 140, tip = "Sends a group invite to every sign-up who is online and not in your group (not Standby). One click, one invite each.", fn = function() self:InviteOnline() end },
        { label = "Advertise in guilds", width = 170, tip = "Puts an ad in the chat box of each guild ticked in the Events settings, one guild after another. You press Enter for each. Pick the kind: sign-ups (before the group forms) or replacements (once it forms). The one that fits now is first.",
          fn = function(control) self:AdMenu(control, function(mode) self:Advertise(mode) end) end },
        { label = "Group Finder", width = 140, tip = "Shows a Group Finder listing for the open slots (title, description, CP and roles from the post) to check. Nothing is listed until you press Create listing.", fn = function() self:AskListing() end },
        { label = "Copy for Discord", width = 170, tip = "Shows a message to copy into Discord: the open sign-up slots (before the group forms), or the missing names and the slots to fill now (once it forms). The one that fits now is first.",
          fn = function(control) self:AdMenu(control, function(mode) self:CopyForDiscord(mode) end) end },
    }
end

function Events:TabExportLines()
    local lines = { "Signed up as\tDiscord name\tAccount\tStatus\tGroup role\tCP" }
    local state = self.sv.enabled and self:State()
    if not state then return lines end
    local function Plain(text) return (tostring(text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")) end
    for _, info in ipairs(state.entries) do
        lines[#lines + 1] = table.concat({ info.section.name, info.person.raw, info.account or "", Plain(info.statusText),
            info.groupRole and (ROLE_NAME[info.groupRole] or "") or "", info.cp and tostring(info.cp) or "" }, "\t")
    end
    for _, info in ipairs(state.walkIns) do
        lines[#lines + 1] = table.concat({ "Not signed up", "", info.account, "In group", ROLE_NAME[info.groupRole] or "", info.cp and tostring(info.cp) or "" }, "\t")
    end
    return lines
end

-- The text window --------------------------------------------------------------------------
-- One window for pasting the post, typing an account and checking the Group Finder listing.

-- def.singleLine: a one-line box (Set account) in a short window instead of the big text box.
-- def.onShown runs a moment after the window opens (after the right-click menu has closed).
local INPUT_HEIGHT, INPUT_HEIGHT_LINE = 520, 230

local function InputBox(def)
    if def and def.singleLine then return FurysGuildToolset_EventsInputLineBox end
    return FurysGuildToolset_EventsInputTextBox
end

function Events:OpenInput(def)
    self.input = def
    FurysGuildToolset_EventsInputTitle:SetText(def.title)
    FurysGuildToolset_EventsInputHint:SetText(def.hint or "")
    FurysGuildToolset_EventsInputOK:SetText(def.okLabel or "OK")
    FurysGuildToolset_EventsInputText:SetHidden(def.singleLine == true)
    FurysGuildToolset_EventsInputLine:SetHidden(def.singleLine ~= true)
    FurysGuildToolset_EventsInput:SetHeight(def.singleLine and INPUT_HEIGHT_LINE or INPUT_HEIGHT)
    local box = InputBox(def)
    box:SetText(def.text or "")
    U.ShowOnTop(FurysGuildToolset_EventsInput)
    box:TakeFocus()
    if def.onShown then
        zo_callLater(function() if self.input == def and not FurysGuildToolset_EventsInput:IsHidden() then def.onShown() end end, 100)
    end
end

function Events:CloseInput()
    FurysGuildToolset_EventsInputTextBox:LoseFocus()
    FurysGuildToolset_EventsInputLineBox:LoseFocus()
    SCENE_MANAGER:HideTopLevel(FurysGuildToolset_EventsInput)
end

-- onOk returning false keeps the window open (Set account shows why the name wasn't found).
function Events:SubmitInput()
    local def = self.input
    local text = InputBox(def):GetText() or ""
    if def and def.onOk(text) == false then return end
    if self.input == def then self:CloseInput() end
end

function Events:InputTip()
    return self.input and self.input.okTip or ""
end

function Events:AskPaste()
    self:OpenInput({
        title = "Paste sign-ups",
        hint = "In Discord, select the sesh event post from its title down to the last name under the last role, press Ctrl+C, then click in the box below and press Ctrl+V.",
        okLabel = "Read sign-ups",
        okTip = "Reads the post and shows each sign-up in the Events tab. Replaces the event shown now.",
        onOk = function(text) self:ReadPaste(text) end,
    })
end

function Events:ReadPaste(text)
    local ev, reason = Events.Parse(text)
    if not ev then
        U.Print("Couldn't read that post: %s", reason)
        return
    end
    self.sv.event = ev
    self.cache = nil
    local people = 0
    for _, section in ipairs(ev.sections) do people = people + #section.people end
    U.Print("Read %s: %d %s in %d %s%s.", ev.title, people, people == 1 and "sign-up" or "sign-ups", #ev.sections,
        #ev.sections == 1 and "section" or "sections", (ev.minCP or 0) > 0 and string.format(", CP %d+", ev.minCP) or "")
    GT.Report:Show("events")
end

-- Clears the pasted event (1.15.0). The Discord name to @account matches stay.
function Events:ClearEvent()
    local ev = self.sv.event
    if not ev then U.Print("There's no event to clear."); return end
    self.sv.event = nil
    self.cache = nil
    self.adQueue = nil
    EVENT_MANAGER:UnregisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL)
    U.Print("Cleared %s. Your matched accounts are kept. Paste sign-ups to read the next event.", ev.title)
    GT.Report:RefreshIfShown()
end

-- Looks a typed @account up in everything the game lets an addon see: the members of all your
-- guilds, your friend list, your group and the game's recent contacts (1.21.0, recent 1.22.0).
-- There's no call that asks the server whether any account exists, so other names can't be
-- checked. Returns the entry from AccountCandidates, or nil and up to four close names.
function Events:LookupAccount(account)
    local list = self.accountList or self:AccountCandidates()
    local found = list[zo_strlower(account)]
    if found then return found end
    local close = {}
    for _, entry in ipairs(self:AccountMatches(account)) do
        if #close < 4 then close[#close + 1] = entry.name end
    end
    return nil, close
end

-- Suggestions as you type (1.22.0) -----------------------------------------------------------
-- The game's own autocomplete (ZO_AutoComplete, the one under the mail "To" box), fed with
-- @accounts only: members of all your guilds, your friends, your group, and the game's list
-- of people you recently mailed, whispered or met (AUTO_COMPLETE_FLAG_RECENT). Each line shows
-- where the name comes from. Up, Down and Tab or a click pick one; Enter saves.

local MAX_SUGGESTIONS = 8

-- [lower @name] = { name, places = { "nUber", ... }, online }
function Events:AccountCandidates()
    local list = {}
    local function Add(name, place, online)
        if not name or name == "" or name:sub(1, 1) ~= "@" then return end
        local key = zo_strlower(name)
        local entry = list[key]
        if not entry then
            entry = { name = name, norm = Norm(name), places = {}, online = false }
            list[key] = entry
        end
        if place and not entry.places[place] then
            entry.places[place] = true
            entry.places[#entry.places + 1] = place
        end
        if online then entry.online = true end
    end
    for _, guildId in ipairs(U.GetGuildIds()) do
        local guildName = U.GuildName(guildId)
        for i = 1, GetNumGuildMembers(guildId) do
            local name, _, _, status = GetGuildMemberInfo(guildId, i)
            Add(name, guildName, status ~= PLAYER_STATUS_OFFLINE)
        end
    end
    for i = 1, GetNumFriends() do
        local name, _, status = GetFriendInfo(i)
        Add(name, "friend", status ~= PLAYER_STATUS_OFFLINE)
    end
    for _, member in pairs(self:BuildGroup()) do
        Add(member.name, "group", member.online)
    end
    local recent = {}
    ZO_AutoComplete.FlagHandlers[AUTO_COMPLETE_FLAG_RECENT](recent, "", false, true)
    for _, name in pairs(recent) do Add(name, nil, false) end
    list[zo_strlower(GetDisplayName())] = nil
    return list
end

local function SuggestionLabel(entry)
    local where = #entry.places > 0 and table.concat(entry.places, ", ") or "recent contact"
    local label = string.format("%s  |c8A86B0%s|r", entry.name, where)
    if entry.online then label = label .. "  |c5EE6A0online|r" end
    return label
end

-- The best names for what's typed: names starting with it, then containing it, then the same
-- letters ignoring dots, dashes and fancy letters, then the game's fuzzy match. With nothing
-- typed yet: names that look like the Discord name.
function Events:AccountMatches(text, person)
    local list = self.accountList or {}
    local typed = zo_strlower(Trim(text or "")):gsub("^@", "")
    local found, seen = {}, {}
    local function Take(entry)
        if entry and #found < MAX_SUGGESTIONS and not seen[entry.name] then
            seen[entry.name] = true
            found[#found + 1] = entry
        end
    end
    local function Pass(test)
        local hits = {}
        for key, entry in pairs(list) do
            if not seen[entry.name] and test(key:sub(2), entry) then hits[#hits + 1] = entry end
        end
        table.sort(hits, function(a, b)
            if a.online ~= b.online then return a.online end
            return zo_strlower(a.name) < zo_strlower(b.name)
        end)
        for _, entry in ipairs(hits) do Take(entry) end
    end
    if typed == "" then
        if not person then return found end
        local keys = { person.key }
        if person.nick then keys[#keys + 1] = Norm(person.nick) end
        for _, alt in ipairs(person.alts or {}) do keys[#keys + 1] = alt end
        for _, key in ipairs(keys) do
            if #key >= 3 then
                Pass(function(_, entry) local n = entry.norm return n:find(key, 1, true) ~= nil or (#n >= 4 and key:find(n, 1, true) ~= nil) end)
            end
        end
    else
        local plain = Norm(typed)
        Pass(function(name) return name:sub(1, #typed) == typed end)
        Pass(function(name) return name:find(typed, 1, true) ~= nil end)
        if #plain >= 2 then Pass(function(_, entry) return entry.norm:find(plain, 1, true) ~= nil end) end
        if #found < MAX_SUGGESTIONS and #typed >= 3 then
            local byLower = {}
            for key, entry in pairs(list) do byLower[key] = key end
            for _, key in ipairs(GetTopMatchesByLevenshteinSubStringScore(byLower, "@" .. typed, 1, MAX_SUGGESTIONS) or {}) do Take(list[key]) end
        end
    end
    return found
end

-- Puts the matches in the drop-down under the box (the game's own list under a text box).
function Events:ShowAccountSuggestions(text)
    local complete = self.accountComplete
    local def = self.input
    if not complete or not def or not def.person then return end
    local labels = {}
    self.accountLabels = {}
    for _, entry in ipairs(self:AccountMatches(text, def.person)) do
        local label = SuggestionLabel(entry)
        self.accountLabels[label] = entry.name
        labels[#labels + 1] = label
    end
    if not complete:ApplyAutoCompletionResults(unpack(labels)) then complete:Hide() end
end

function Events:SetUpAccountComplete()
    if self.accountComplete then return end
    local box = FurysGuildToolset_EventsInputLineBox
    local complete = ZO_AutoComplete:New(box, nil, nil, AUTO_COMPLETION_ONLINE_OR_OFFLINE, MAX_SUGGESTIONS, AUTO_COMPLETION_MANUAL_MODE)
    complete:SetUseCallbacks(true)
    complete:RegisterCallback(ZO_AutoComplete.ON_ENTRY_SELECTED, function(label)
        local name = self.accountLabels and self.accountLabels[label]
        if name then
            -- Setting the text would show the list again; this pick is done.
            self.accountPicking = true
            box:SetText(name)
            box:SetCursorPosition(#name)
            self.accountPicking = false
        end
    end)
    ZO_PreHookHandler(box, "OnTextChanged", function()
        if not self.accountPicking and self.input and self.input.person and box:HasFocus() then self:ShowAccountSuggestions(box:GetText()) end
    end)
    self.accountComplete = complete
end

function Events:AskAccount(person, current)
    self:SetUpAccountComplete()
    self.accountList = self:AccountCandidates()
    local def
    def = {
        title = "Account for " .. person.base,
        hint = string.format("Type the ESO @account of %s. Names from your guilds, friends, group and recent contacts drop down as you type: click one or pick it with the arrow keys and Tab. It's checked when you save and remembered for every event. Leave it empty to forget it.", person.raw),
        okLabel = "Save account",
        okTip = "Checks the account and remembers it for this Discord name.",
        text = current or "@",
        singleLine = true,
        person = person,
        onOk = function(text) return self:CheckAccount(person, text, def) end,
        onShown = function() self:ShowAccountSuggestions(FurysGuildToolset_EventsInputLineBox:GetText()) end,
    }
    self:OpenInput(def)
end

-- Saves a typed account once it's found in your guilds, friends or group, with the game's
-- spelling. Not found: the window stays open and says so, with close names; pressing
-- "Save anyway" on the same name keeps it.
function Events:CheckAccount(person, text, def)
    local account = U.NormalizeName(Trim((text:gsub("[\r\n].*", ""))))
    if account == "" or account == "@" then
        self:SetAccount(person, "")
        return true
    end
    local found, close = self:LookupAccount(account)
    if found then
        local note = " (checked: a recent contact)"
        if #found.places > 0 then
            note = string.format(" (checked: in %s, %s)", table.concat(found.places, ", "), found.online and "online" or "offline")
        end
        self:SetAccount(person, found.name, note)
        return true
    end
    if def.unchecked == zo_strlower(account) then
        self:SetAccount(person, account, " (not checked: not in your guilds, friends, group or recent contacts)")
        return true
    end
    def.unchecked = zo_strlower(account)
    local hint = string.format("|cFFA45C%s isn't in any of your guilds, your friend list, your group or your recent contacts,|r so the addon can't check it (the game has no lookup for other accounts).", account)
    if #close > 0 then hint = hint .. " Did you mean " .. table.concat(close, ", ") .. "?" end
    hint = hint .. " Fix the name, or press Save anyway to keep it as typed."
    FurysGuildToolset_EventsInputHint:SetText(hint)
    FurysGuildToolset_EventsInputOK:SetText("Save anyway")
    def.okTip = "Keeps this account as typed, without a check."
    return false
end

-- Actions ---------------------------------------------------------------------------------

local function CanInvite()
    if IsUnitSoloOrGroupLeader("player") then return true end
    U.Print("Only the group leader can invite.")
    return false
end

function Events:Invite(account)
    if not CanInvite() then return end
    GroupInviteByName(account)
    U.Print("Group invite sent to %s.", account)
end

function Events:InviteOnline()
    local state = self:State()
    if not state then U.Print("Paste a sesh sign-up post first."); return end
    if not CanInvite() then return end
    local sent = {}
    for _, info in ipairs(state.missing) do
        if info.account and info.status and info.status ~= PLAYER_STATUS_OFFLINE and info.account ~= GetDisplayName() then
            GroupInviteByName(info.account)
            sent[#sent + 1] = info.account
        end
    end
    if #sent == 0 then
        U.Print("Nobody who signed up is online and out of the group.")
    else
        U.Print("Group invites sent to %s.", table.concat(sent, ", "))
    end
end

-- Invite code ------------------------------------------------------------------------------

-- On/off button and code box in the window's title row, on the Events tab only (1.23.0, Albert:
-- the settings page is too far away for this). The same saved settings as the settings page.
local CODE_MAX_CHARS = 30
local CODE_SIZES = {
    { name = "IA", count = 2, width = 70 },
    { name = "Group", count = 4, width = 100 },
    { name = "Trial", count = 12, width = 100 },
}

function Events:CodeBar()
    if self.codeBar then return self.codeBar end
    local T = GT.Theme
    local bar = WINDOW_MANAGER:CreateControl("FurysGuildToolset_EventsCodeBar", FurysGuildToolset_Report, CT_CONTROL)
    bar:SetDimensions(640, 30)
    bar:SetAnchor(RIGHT, FurysGuildToolset_ReportSettings, LEFT, -12, 0)
    bar:SetDrawLayer(DL_CONTROLS)
    bar:SetHidden(true)

    local toggle = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Toggle", bar, "ZO_DefaultButton")
    toggle:SetDimensions(180, 28)
    toggle:SetAnchor(LEFT, bar, LEFT, 0, 0)
    toggle:SetHandler("OnClicked", function() self:SetCodeOn(not self.sv.autoInvite) end)
    GT.Report.SetTip(toggle, function()
        local now = self.sv.autoInvite and ("\n\n" .. self:CodeStatus()) or ""
        return string.format("Turns Invite by code on or off. While it's on, anyone who types %s (upper or lower case) in the chat of a guild ticked for ads, or whispers it to you, gets a group invite. With no event pasted: anyone, up to a full group. With an event pasted: once its group forms (until 2 hours after the start), up to its group size, and not when their CP is under the post's requirement. Only while you lead the group or are solo. Starts turned off at every login, and turns itself off when your group fills up or breaks up.%s", self:CodeText(), now)
    end)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", bar, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetText("Code")
    label:SetAnchor(LEFT, toggle, RIGHT, 12, 0)
    T.Paint(label, T.TEXT)

    local back = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Code", bar, "ZO_SingleLineEditBackdrop_Keyboard")
    back:SetDimensions(110, 28)
    back:SetAnchor(LEFT, label, RIGHT, 8, 0)
    local box = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Box", back, "ZO_DefaultEditForBackdrop")
    box:SetMaxInputChars(CODE_MAX_CHARS)
    box:SetHandler("OnEnter", function(control) control:LoseFocus() end)
    box:SetHandler("OnEscape", function(control)
        control:SetText(self:CodeText())
        control:LoseFocus()
    end)
    box:SetHandler("OnFocusLost", function(control) self:SetCode(control:GetText()) end)
    GT.Report.SetTip(back, "The invite code: the whole chat message has to be this (upper or lower case). Type a new one and press Enter. {code} in the ads.")
    GT.Report.SetTip(box, "The invite code: the whole chat message has to be this (upper or lower case). Type a new one and press Enter. {code} in the ads.")

    -- Size buttons (1.24.0, Albert): with no event pasted, pick how big the group should get.
    -- Invite by code turns on and turns itself off at that size, or when you leave the group.
    local sizeButtons, previous = {}, back
    for _, size in ipairs(CODE_SIZES) do
        local button = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Size" .. size.count, bar, "ZO_DefaultButton")
        button:SetDimensions(size.width, 28)
        button:SetAnchor(LEFT, previous, RIGHT, previous == back and 10 or 2, 0)
        button:SetHandler("OnClicked", function() self:PickCodeSize(size.count) end)
        GT.Report.SetTip(button, function()
            if self.sv.codeSize == size.count then
                return string.format("Inviting by code until your group has %d. Click to stop.", size.count)
            end
            return string.format("%s: turns Invite by code on until your group has %d (you included), whether you're solo or already grouped. It turns off by itself at %d, or when you leave or disband the group. For when no event is pasted; a pasted event uses its own group size.", size.name, size.count, size.count)
        end)
        button.furySize = size
        sizeButtons[#sizeButtons + 1] = button
        previous = button
    end

    -- Above the title-bar glow, like the search box (1.18.3).
    local layered = { toggle, label, back, box }
    for _, button in ipairs(sizeButtons) do layered[#layered + 1] = button end
    for level, control in ipairs(layered) do
        control:SetDrawLayer(DL_CONTROLS)
        control:SetDrawLevel(level)
    end
    back:SetCenterColor(0, 0, 0, 1)
    back:SetEdgeColor(T.VIOLET:UnpackRGBA())
    T.Paint(box, T.TEXT)

    self.codeBar, self.codeToggle, self.codeBox, self.codeSizeButtons = bar, toggle, box, sizeButtons
    return bar
end

function Events:CodeText()
    return self.sv.inviteCode or Events.defaults.inviteCode
end

function Events:UpdateCodeBar()
    local bar = self:CodeBar()
    -- Nothing to switch while the Events tab itself is off.
    if not self.sv.enabled then bar:SetHidden(true); return end
    if self.sv.autoInvite then
        self.codeToggle:SetText("Invite by code: |c5EE6A0ON|r")
    else
        self.codeToggle:SetText("Invite by code: |cFFA45COFF|r")
    end
    if not self.codeBox:HasFocus() then self.codeBox:SetText(self:CodeText()) end
    -- The size buttons only matter with no (current) event pasted.
    local open = self:CodeWindow() == "open"
    for _, button in ipairs(self.codeSizeButtons) do
        local size = button.furySize
        button:SetHidden(not open)
        if self.sv.autoInvite and self.sv.codeSize == size.count then
            button:SetText(string.format("|c5EE6A0%s (%d)|r", size.name, size.count))
        else
            button:SetText(string.format("%s (%d)", size.name, size.count))
        end
    end
end

-- Your group's size, you included (1 when solo).
local function GroupCount()
    local count = GetGroupSize()
    if count < 1 then count = 1 end
    return count
end

-- Turns Invite by code on until the group has `count` people, or off when that size is
-- already the one running.
function Events:PickCodeSize(count)
    if self.sv.autoInvite and self.sv.codeSize == count then
        self:SetCodeOn(false)
        return
    end
    local have = GroupCount()
    if have >= count then
        U.Print("Your group already has %d, so there's nobody to invite for a group of %d.", have, count)
        return
    end
    self.sv.codeSize = count
    self.codePending = {}
    self.sv.autoInvite = true
    self:RegisterCode()
    U.Print("Invite by code is on until your group has %d (it has %d now). Code: %s, in whispers and the chat of the guilds ticked for ads. It turns off by itself at %d, or when you leave or disband the group.",
        count, have, self:CodeText(), count)
    GT.Report:RefreshIfShown()
end

-- With a size picked: off once the group has that many, or when you leave or disband it.
-- Off once the group is full: the picked size, else the pasted event's group size, else a full
-- group (1.24.1: every mode turns itself off, Albert).
function Events:CheckCodeSize()
    if not self.sv.autoInvite then return end
    local have, limit = GroupCount(), self:CodeLimit()
    if have >= limit then
        self:SetCodeOn(false, string.format("Your group has %d now, so it's full. Invite by code is off.", have))
    end
end

function Events:SetCodeOn(on, message)
    if on then
        local have, limit = GroupCount(), self:CodeLimit(true)
        if have >= limit then
            U.Print("Your group already has %d, so it's full. Invite by code stays off.", have)
            GT.Report:RefreshIfShown()
            return
        end
    end
    self.sv.autoInvite = on
    -- The button turns on the plain mode (no size); off ends a picked size too.
    self.sv.codeSize = nil
    if not on then self.codePending = nil end
    self:RegisterCode()
    if on then
        U.Print("Invite by code is on. Code: %s, in whispers and the chat of the guilds ticked for ads. %s", self:CodeText(), self:CodeStatus())
    else
        U.Print(message or "Invite by code is off.")
    end
    GT.Report:RefreshIfShown()
end

-- Saves a code typed in the box. An empty box puts the old code back.
function Events:SetCode(text)
    local code = zo_strtrim(text or "")
    if code == "" then
        self.codeBox:SetText(self:CodeText())
        return
    end
    if code == self:CodeText() then return end
    self.sv.inviteCode = code
    U.Print("The invite code is now %s.", code)
    GT.Report:RefreshIfShown()
end

-- Listens to guild chat and whispers while inviting by code is on. The handler only acts when
-- a whole message is the code.
function Events:RegisterCode()
    EVENT_MANAGER:UnregisterForEvent(CODE_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL)
    EVENT_MANAGER:UnregisterForEvent(CODE_EVENT_NAME, EVENT_GROUP_MEMBER_JOINED)
    EVENT_MANAGER:UnregisterForEvent(CODE_EVENT_NAME, EVENT_GROUP_MEMBER_LEFT)
    if self.sv.enabled and self.sv.autoInvite then
        EVENT_MANAGER:RegisterForEvent(CODE_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL, function(_, channelType, _, text, _, fromDisplayName)
            self:OnCodeMessage(channelType, text, fromDisplayName)
        end)
        -- The group's size can lag the event a moment, so check a bit later.
        EVENT_MANAGER:RegisterForEvent(CODE_EVENT_NAME, EVENT_GROUP_MEMBER_JOINED, function(_, _, displayName)
            if self.codePending and displayName then self.codePending[displayName] = nil end
            zo_callLater(function() self:CheckCodeSize() end, 500)
        end)
        EVENT_MANAGER:RegisterForEvent(CODE_EVENT_NAME, EVENT_GROUP_MEMBER_LEFT, function(_, _, _, isLocalPlayer)
            -- You left, or the group broke up or was disbanded: done.
            if isLocalPlayer and self.sv.autoInvite then
                self:SetCodeOn(false, "You left the group, or it broke up. Invite by code is off.")
            end
        end)
    end
end

-- The guild (guildId) a guild chat channel belongs to, or nil.
local function GuildOfChannel(channelType)
    for i, channel in ipairs(GUILD_CHANNELS) do
        if channel == channelType and i <= GetNumGuilds() then return GetGuildId(i) end
    end
    return nil
end

-- The CP someone shows in a guild you share, or nil when unknown.
local function GuildCP(name, guildId)
    local ids = guildId and { guildId } or U.GetGuildIds()
    for _, id in ipairs(ids) do
        local index = GetGuildMemberIndexFromDisplayName(id, name)
        if index then
            local _, _, _, _, _, _, championRank = GetGuildMemberCharacterInfo(id, index)
            return championRank
        end
    end
    return nil
end

-- When the code invites (1.23.1; it used to need a pasted event, so with none it silently did
-- nothing):
--   No event pasted, or the pasted one started more than CODE_HOURS_AFTER_START ago: anyone who
--   types the code, up to a full group. Returns "open".
--   An event pasted and its group has formed (start time minus the forming minutes): the
--   event's group size and CP. Returns "event", state.
--   An event pasted that hasn't formed yet: nobody. Returns nil, why.
function Events:CodeWindow()
    local state = self:State()
    if not state then return "open" end
    if state.startTs and GetTimeStamp() > state.startTs + CODE_HOURS_AFTER_START * 3600 then return "open" end
    if state.mode ~= "now" then
        local why = string.format("%s hasn't formed yet", state.ev.title)
        if state.formUpTs then why = why .. string.format(" (it forms at %s)", Clock(state.formUpTs)) end
        return nil, why
    end
    return "event", state
end

-- One line for the button's tip and the "on" message: what the code does right now.
function Events:CodeStatus()
    local kind, info = self:CodeWindow()
    if kind == "open" and self.sv.codeSize then
        return string.format("It invites anyone who types it until your group has %d, then turns off.", self.sv.codeSize)
    end
    if kind == "open" then return "It invites anyone who types it now, up to a full group (no current event pasted)." end
    if kind == "event" then return string.format("It invites for %s now: up to the event's group size and CP.", info.ev.title) end
    return string.format("Nobody is invited yet: %s.", info)
end

-- The group size the event needs: its role limits (Standby left out), or a full group.
local function GroupLimit(ev)
    local total = 0
    for _, section in ipairs(ev.sections) do
        if section.max and (ROLE_OF_KIND[section.kind] or section.kind == "any") then total = total + section.max end
    end
    return (total > 0 and total < MAX_GROUP) and total or MAX_GROUP
end

-- How big the group may get while inviting by code: the picked size, the pasted event's group
-- size, or a full group. plainOn: for the ON button, which drops a picked size.
function Events:CodeLimit(plainOn)
    if self.sv.codeSize and not plainOn then return self.sv.codeSize end
    local state = self:State()
    if state and self:CodeWindow() ~= "open" then return GroupLimit(state.ev) end
    return MAX_GROUP
end

-- Chat text without the game's markup (icons |t..|t, colors |c..|r, links), for comparing.
local function PlainChat(text)
    text = tostring(text or "")
    text = text:gsub("|t[^|]*|t", ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H[^|]*|h(.-)|h", "%1")
    return zo_strtrim(text)
end

function Events:OnCodeMessage(channelType, text, fromDisplayName)
    local code = zo_strlower(zo_strtrim(self.sv.inviteCode or ""))
    if code == "" or zo_strlower(PlainChat(text)) ~= code then return end
    if not fromDisplayName or fromDisplayName == "" or fromDisplayName == GetDisplayName() then return end
    local guildId = GuildOfChannel(channelType)
    if not guildId and channelType ~= CHAT_CHANNEL_WHISPER then return end
    local group = self:BuildGroup()
    if group[Norm(fromDisplayName)] then return end
    -- One answer per person a minute, whatever it is.
    self.codeSeen = self.codeSeen or {}
    local now = GetTimeStamp()
    if self.codeSeen[fromDisplayName] and now - self.codeSeen[fromDisplayName] < 60 then return end
    self.codeSeen[fromDisplayName] = now
    local link = ZO_LinkHandler_CreateDisplayNameLink(fromDisplayName)
    if guildId and not self.sv.adGuilds[guildId] then
        U.Print("%s typed the invite code in %s, but that guild isn't ticked under Guilds to advertise in (Events settings). Not invited.", link, U.GuildName(guildId))
        return
    end
    local kind, info = self:CodeWindow()
    if not kind then
        U.Print("%s typed the invite code, but %s. Not invited.", link, info)
        return
    end
    if not IsUnitSoloOrGroupLeader("player") then
        U.Print("%s typed the invite code, but only the group leader can invite.", link)
        return
    end
    local limit = kind == "event" and GroupLimit(info.ev) or (self.sv.codeSize or MAX_GROUP)
    -- Invites still waiting for an answer (up to a minute) count too, so a group of 4 doesn't
    -- get 5 people when several type the code at once.
    local pending = 0
    self.codePending = self.codePending or {}
    for name, at in pairs(self.codePending) do
        if now - at > 60 then self.codePending[name] = nil else pending = pending + 1 end
    end
    if GroupCount() + pending >= limit then
        U.Print("%s typed the invite code, but the group is full%s. Not invited.", link, pending > 0 and " (counting invites not answered yet)" or "")
        return
    end
    local minCP = kind == "event" and (info.ev.minCP or 0) or 0
    local cp = GuildCP(fromDisplayName, guildId)
    if minCP > 0 and cp and cp < minCP then
        U.Print("%s typed the invite code, but has CP %d (the event needs %d). Not invited.", link, cp, minCP)
        return
    end
    GroupInviteByName(fromDisplayName)
    self.codePending[fromDisplayName] = now
    U.Print("Invited %s (typed the invite code%s).", link, cp and string.format(", CP %d", cp) or "")
end

-- The ad without the invite code, for when Invite by code is off (1.13.2). The words from the
-- one before {code} up to "or" go: "Type {code} into guild chat or whisper {me}." becomes
-- "Whisper {me}.", "Need {need}, type {code} or whisper {me}!" becomes "Need {need}, whisper
-- {me}!". With no "or" after it, the sentence (or its part after the last comma) goes.
local function WithoutCode(template)
    if not template:find("{code}", 1, true) then return template end
    local out = {}
    for sentence, stop in template:gmatch("([^%.!%?]+)([%.!%?]*)") do
        local at = sentence:find("{code}", 1, true)
        if not at then
            out[#out + 1] = sentence .. stop
        else
            local before = sentence:sub(1, at - 1)
            local wordStart = before:match("()%S+%s*$") or at
            local _, orEnd = sentence:find("%sor%s+", at)
            if orEnd then
                local head, tail = sentence:sub(1, wordStart - 1), sentence:sub(orEnd + 1)
                if not head:find("%S") then tail = zo_strupper(tail:sub(1, 1)) .. tail:sub(2) end
                out[#out + 1] = head .. tail .. stop
            else
                local comma = before:match(".*(),")
                if comma then out[#out + 1] = sentence:sub(1, comma - 1) .. stop end
            end
        end
    end
    return table.concat(out)
end

-- Asks which kind of ad: sign-ups for the slots nobody has taken (before the group forms) or
-- replacements for what the group is missing now. The one that fits the time comes first.
function Events:AdMenu(control, fn)
    local state = self:State()
    if not state then U.Print("Paste a sesh sign-up post first."); return end
    local signup, now = self:NeedText(state, state.openSignup), self:NeedText(state, state.openNow)
    local items
    if next(state.openNow) == nil then
        -- No section has a limit (a class with Attendees only): no counts to show.
        items = { { mode = "signup", label = "Ask for sign-ups" }, { mode = "now", label = "Ask people to join now" } }
    else
        items = {
            { mode = "signup", label = string.format("Ask for sign-ups (%s)", signup ~= "" and signup or "no open sign-up slots") },
            { mode = "now", label = string.format("Ask for replacements, join now (%s)", now ~= "" and now or "group is full") },
        }
    end
    if state.mode == "now" then items[1], items[2] = items[2], items[1] end
    ClearMenu()
    for _, item in ipairs(items) do
        local mode = item.mode
        AddMenuItem(item.label, function() fn(mode) end)
    end
    ShowMenu(control)
end

-- Guild ads: one guild at a time. The next guild's ad goes in the chat box after you send
-- the one before it.
function Events:Advertise(mode)
    local state = self:State()
    if not state then U.Print("Paste a sesh sign-up post first."); return end
    if CHAT_SYSTEM:IsTextEntryOpen() then
        U.Print("You're typing in chat. Send or close that first, then try again.")
        return
    end
    local posts = {}
    mode = mode or state.mode
    local open = mode == "now" and state.openNow or state.openSignup
    if next(open) ~= nil and self:NeedText(state, open) == "" then
        U.Print(mode == "now" and "Your group has every slot filled. Nothing to advertise." or "Every sign-up slot is taken. Nothing to advertise.")
        return
    end
    local template = mode == "now" and self.sv.adText or (self.sv.signupAdText or Events.defaults.signupAdText)
    if not self.sv.autoInvite then template = WithoutCode(template) end
    local text = Fill(template, self:Values(state, nil, open))
    if #text > MAX_CHAT then text = text:sub(1, MAX_CHAT) end
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if self.sv.adGuilds[guildId] then posts[#posts + 1] = { channel = GUILD_CHANNELS[i], guildId = guildId, text = text } end
    end
    if #posts == 0 then
        U.Print("Tick the guilds to advertise in under Events settings (Guilds to advertise in).")
        return
    end
    self.adQueue = { posts = posts, total = #posts }
    EVENT_MANAGER:UnregisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL)
    if #posts > 1 then
        local me = GetDisplayName()
        EVENT_MANAGER:RegisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL, function(_, channelType, _, _, _, fromDisplayName)
            local queue = self.adQueue
            if queue and queue.current and channelType == queue.current.channel and fromDisplayName == me then
                zo_callLater(function() if self.adQueue == queue and not CHAT_SYSTEM:IsTextEntryOpen() then self:NextAd() end end, 300)
            end
        end)
    end
    self:NextAd()
end

function Events:NextAd()
    local queue = self.adQueue
    local post = table.remove(queue.posts, 1)
    if not post then
        self.adQueue = nil
        EVENT_MANAGER:UnregisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL)
        return
    end
    queue.current = post
    if #queue.posts == 0 then
        self.adQueue = nil
        EVENT_MANAGER:UnregisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL)
    end
    StartChatInput(post.text, post.channel)
    U.Print("Ad for %s is in the chat box (%d of %d). Press Enter to post it%s.", U.GuildName(post.guildId),
        queue.total - #queue.posts, queue.total, #queue.posts > 0 and "; the next guild's follows" or "")
end

-- Discord (1.20.2) ---------------------------------------------------------------------------
-- Discord takes far more than game chat: headers, bold, block quotes, :emoji: shortcodes (Discord
-- turns them into emoji when you send), <t:...> timestamps that show in each reader's own time
-- zone, and up to 2000 characters. The text stays plain ASCII so the game's text box keeps it.

local DISCORD_MAX = 2000
local DISCORD_EMOJI = { tank = ":shield:", heal = ":green_heart:", dps = ":crossed_swords:", any = ":busts_in_silhouette:", standby = ":hourglass:" }
local DISCORD_ROLE = { tank = { "Tank", "Tanks" }, heal = { "Healer", "Healers" }, dps = { "DPS", "DPS" } }

-- Names and titles can hold * _ ~ ` | > that Discord would read as formatting.
local function DiscordEscape(text)
    return (tostring(text or ""):gsub("([%*_~`|>\\])", "\\%1"))
end

-- "<t:1795470000:F> (<t:1795470000:R>)": Discord shows the date and "in 2 hours" in each
-- reader's own time zone. The post's own text when the time can't be read.
local function DiscordWhen(state, style)
    if state.startTs then return string.format("<t:%d:%s> (<t:%d:R>)", state.startTs, style or "F", state.startTs) end
    return state.ev.time and DiscordEscape(state.ev.time) or nil
end

-- One line per role with a limit: ":shield: **Tanks:** 1 open (1/2 signed up)" or
-- ":green_heart: **Healers:** full :white_check_mark:". Nothing when no section has a limit.
local function DiscordOpenLines(state, open, now)
    local maxOf = {}
    for _, section in ipairs(state.ev.sections) do
        if section.max and (ROLE_OF_KIND[section.kind] or section.kind == "any") then
            maxOf[section.kind] = (maxOf[section.kind] or 0) + section.max
        end
    end
    local lines = {}
    for _, kind in ipairs({ "tank", "heal", "dps", "any" }) do
        local n = open[kind]
        if n and maxOf[kind] then
            local label = kind == "any" and "Spots" or DISCORD_ROLE[kind][2]
            -- Taken = the limit minus the open slots, so walk-ins in your group count too.
            local count = string.format("(%d/%d %s)", math.max(0, maxOf[kind] - n), maxOf[kind], now and "here" or "taken")
            if n > 0 then
                lines[#lines + 1] = string.format("> %s **%s:** %d open %s", DISCORD_EMOJI[kind], label, n, count)
            else
                lines[#lines + 1] = string.format("> %s **%s:** full :white_check_mark: %s", DISCORD_EMOJI[kind], label, count)
            end
        end
    end
    return lines
end

-- ":shield: **Tank (1/2):** Furyous, Marth Wolf", one line per section that isn't "out" (or
-- an empty standby).
-- withNames false gives counts only (for a long roster that would pass Discord's limit).
local function DiscordRoster(state, withNames)
    local lines = {}
    for _, section in ipairs(state.ev.sections) do
        if section.kind ~= "out" and not (section.kind == "standby" and #section.people == 0) then
            local count = section.max and string.format("%d/%d", #section.people, section.max) or tostring(#section.people)
            local line = string.format("%s **%s (%s)**", DISCORD_EMOJI[section.kind] or ":small_blue_diamond:", DiscordEscape(section.name), count)
            if withNames and #section.people > 0 then
                local names = {}
                for _, person in ipairs(section.people) do names[#names + 1] = DiscordEscape(person.base) end
                line = line .. ": " .. table.concat(names, ", ")
            end
            lines[#lines + 1] = line
        end
    end
    return lines
end

function Events:DiscordText(state, mode, withNames)
    local ev = state.ev
    local title = DiscordEscape(ev.title)
    local when = DiscordWhen(state, mode == "now" and "t" or "F")
    local lines = {}
    if mode == "signup" then
        local open = state.openSignup
        lines[#lines + 1] = "## :crossed_swords: " .. title
        if when then lines[#lines + 1] = ":calendar: " .. when end
        if (ev.minCP or 0) > 0 then lines[#lines + 1] = string.format(":star: **CP %d+**", ev.minCP) end
        lines[#lines + 1] = ""
        if next(open) == nil then
            -- No section has a limit (Attendees only): there's always room (1.20.2; it used to
            -- say every slot was taken).
            local signed = 0
            for _, section in ipairs(ev.sections) do
                if section.kind ~= "standby" and section.kind ~= "out" then signed = signed + #section.people end
            end
            lines[#lines + 1] = string.format("### :sparkles: Room for more! %d signed up so far.", signed)
        elseif self:NeedText(state, open) == "" then
            lines[#lines + 1] = "### :white_check_mark: Every slot is taken!"
            lines[#lines + 1] = "Sign up as **Standby** if you'd like to come."
        else
            lines[#lines + 1] = "### :mega: Still open"
            for _, line in ipairs(DiscordOpenLines(state, open, false)) do lines[#lines + 1] = line end
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "**:clipboard: Signed up**"
        for _, line in ipairs(DiscordRoster(state, withNames)) do lines[#lines + 1] = line end
        lines[#lines + 1] = ""
        lines[#lines + 1] = ":point_right: **Sign up on the event post!**"
    else
        local open = state.openNow
        lines[#lines + 1] = string.format("## :rotating_light: %s is forming up now!", title)
        if when then lines[#lines + 1] = ":alarm_clock: " .. when end
        if (ev.minCP or 0) > 0 then lines[#lines + 1] = string.format(":star: **CP %d+**", ev.minCP) end
        lines[#lines + 1] = ""
        if #state.missing > 0 then
            lines[#lines + 1] = "### :mag: Still missing"
            -- One line per section: "> :shield: **Tank:** sshogrin".
            local order, namesOf = {}, {}
            for _, info in ipairs(state.missing) do
                local section = info.section
                if not namesOf[section] then order[#order + 1] = section; namesOf[section] = {} end
                local names = namesOf[section]
                names[#names + 1] = DiscordEscape(info.person.base)
            end
            for _, section in ipairs(order) do
                local names = namesOf[section]
                lines[#lines + 1] = string.format("> %s **%s:** %s", DISCORD_EMOJI[section.kind] or ":small_blue_diamond:", DiscordEscape(section.name),
                    withNames and table.concat(names, ", ") or (#names .. (#names == 1 and " person" or " people")))
            end
            lines[#lines + 1] = "Are you coming? Log in and we'll send an invite!"
        else
            lines[#lines + 1] = ":white_check_mark: **Everyone who signed up is here.**"
        end
        lines[#lines + 1] = ""
        if next(open) == nil then
            lines[#lines + 1] = "### :sos: Room for more!"
        elseif self:NeedText(state, open) ~= "" then
            lines[#lines + 1] = "### :sos: Need now"
            for _, line in ipairs(DiscordOpenLines(state, open, true)) do lines[#lines + 1] = line end
        else
            lines[#lines + 1] = ":white_check_mark: **The group is full.**"
        end
        if next(open) == nil or self:NeedText(state, open) ~= "" then
            lines[#lines + 1] = ""
            lines[#lines + 1] = string.format(":point_right: Whisper **%s** in game for an invite.", DiscordEscape(GetDisplayName()))
        end
    end
    lines[#lines + 1] = string.format("-# Updated <t:%d:R>", GetTimeStamp())
    return table.concat(lines, "\n")
end

function Events:CopyForDiscord(mode)
    local state = self:State()
    if not state then U.Print("Paste a sesh sign-up post first."); return end
    mode = mode or state.mode
    local text = self:DiscordText(state, mode, true)
    -- A long roster: counts instead of names, so the message fits one Discord post.
    if #text > DISCORD_MAX then text = self:DiscordText(state, mode, false) end
    local Report = GT.Report
    Report.exportParts = { text }
    Report.exportTitle = "Copy for Discord"
    Report.exportHint = "Select all, Ctrl+C, paste into Discord. The :emoji: and <t:...> times turn fancy when you send."
    Report.exportIndex = 1
    U.ShowOnTop(FurysGuildToolset_Export)
    Report:ShowExportPart(0)
    U.Print("The Discord message is in the copy window. Click Select all, press Ctrl+C, and paste it into Discord.")
end

-- Group Finder ---------------------------------------------------------------------------

-- Picks the trial in the Group Finder that the post names (full name, or vSS / nSS style
-- short names), Veteran unless the post says normal. Sets the draft's category and options. Returns
-- "Sunspire (Normal)" or nil when no trial is named.
-- Veteran unless the post says normal (Albert, 1.16.10): "normal" anywhere, or an nSS-style
-- short name, makes it Normal. Also returns the trial short names it saw ("ss" -> "sunspire").
function Events.WantsVeteran(ev)
    local text = zo_strlower(ev.title .. "\n" .. table.concat(ev.desc, "\n"))
    -- Plain ifs (1.16.9): in game "(find(...) or ...) and true or false" gave a number.
    local veteran = true
    if text:find("normal", 1, true) then veteran = false end
    local aliases = {}
    for word in text:gmatch("%a+") do
        local prefix, rest = word:sub(1, 1), word:sub(2)
        if (prefix == "v" or prefix == "n") and TRIAL_ALIASES[rest] then
            aliases[#aliases + 1] = TRIAL_ALIASES[rest]
            if prefix == "n" then veteran = false end
        elseif #word >= 3 and TRIAL_ALIASES[word] then
            aliases[#aliases + 1] = TRIAL_ALIASES[word]
        end
    end
    return veteran, aliases
end

function Events:PickTrial(ev)
    local text = zo_strlower(ev.title .. "\n" .. table.concat(ev.desc, "\n"))
    local flat = Norm(text)
    local veteran, aliases = Events.WantsVeteran(ev)

    SetGroupFinderUserTypeGroupListingCategory(DRAFT, GROUP_FINDER_CATEGORY_TRIAL)
    UpdateGroupFinderUserTypeGroupListingOptions(DRAFT)
    -- Trials list the difficulty as the first choice (Normal, Veteran) and the trial second.
    local numDifficulties = GetGroupFinderUserTypeGroupListingNumPrimaryOptions(DRAFT)
    local difficulty = (veteran and numDifficulties >= 2) and 2 or 1
    for i = 1, numDifficulties do
        local name = zo_strlower(GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex(DRAFT, i) or "")
        if (veteran and name:find("veteran")) or (not veteran and name:find("normal")) then difficulty = i end
    end
    -- The trial list needs an options update after the difficulty (1.16.7 without it found no
    -- trial). The difficulty is set again after the trial in case the update changed it (1.16.8).
    SetGroupFinderUserTypeGroupListingPrimaryOption(DRAFT, difficulty)
    UpdateGroupFinderUserTypeGroupListingOptions(DRAFT)
    self.listingDifficulty = difficulty

    local options = {}
    for i = 1, GetGroupFinderUserTypeGroupListingNumSecondaryOptions(DRAFT) do
        local name = GetGroupFinderUserTypeGroupListingSecondaryOptionByIndex(DRAFT, i) or ""
        options[i] = { name = name, key = Norm((name:gsub("%b()", ""))) }
    end
    local pick
    for i, option in ipairs(options) do
        if not pick and #option.key >= 4 and flat:find(option.key, 1, true) then pick = i end
    end
    for _, alias in ipairs(aliases) do
        for i, option in ipairs(options) do
            if not pick and option.key:find(alias, 1, true) then pick = i end
        end
    end
    if not pick then return nil end
    SetGroupFinderUserTypeGroupListingSecondaryOption(DRAFT, pick)
    local _, difficultySet = GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex(DRAFT, difficulty)
    if not difficultySet then
        SetGroupFinderUserTypeGroupListingPrimaryOption(DRAFT, difficulty)
        SetGroupFinderUserTypeGroupListingSecondaryOption(DRAFT, pick)
    end
    local primary = GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex(DRAFT, difficulty)
    return string.format("%s (%s)", options[pick].name, primary ~= "" and primary or (veteran and "Veteran" or "Normal"))
end

-- Players per role for the listing (1.15.3, Albert): the whole group, not the open slots. The
-- Group Finder shows itself who is there and what's still needed. Each role is the limit of its
-- sign-up section; a trial with no limit for a role gets 2 tanks, 2 healers, 8 DPS. Never fewer
-- than already play that role in the group, never more than the listing's size (DPS trimmed
-- first). nil when nothing gives a number (a custom event with no limits).
local TRIAL_ROLES = { tank = 2, heal = 2, dps = 8 }
function Events:ListingRoles(state, isTrial)
    local numRoles = GetGroupFinderUserTypeGroupListingNumRoles(DRAFT)
    local limit = {}
    for _, section in ipairs(state.ev.sections) do
        if ROLE_OF_KIND[section.kind] and section.max then limit[section.kind] = (limit[section.kind] or 0) + section.max end
    end
    if not isTrial and next(limit) == nil then return nil, numRoles end
    local desired, total = {}, 0
    for kind, role in pairs(ROLE_OF_KIND) do
        local want = limit[kind] or (isTrial and TRIAL_ROLES[kind]) or 0
        desired[role] = math.max(want, GetGroupFinderUserTypeGroupListingAttainedRoleCount(DRAFT, role))
        total = total + desired[role]
    end
    for _, role in ipairs({ LFG_ROLE_DPS, LFG_ROLE_HEAL, LFG_ROLE_TANK }) do
        local floor = GetGroupFinderUserTypeGroupListingAttainedRoleCount(DRAFT, role)
        while total > numRoles and desired[role] > floor do
            desired[role] = desired[role] - 1
            total = total - 1
        end
    end
    return desired, numRoles
end

-- The trial's playstyle from the post (1.16.0, Albert): "trainer" or "training" is
-- Educational, "zerg" or "loot run" is Speed Run, anything else Standard. Picked by the game's
-- own names for the playstyles. Returns the playstyle value and its name.
function Events:PickPlaystyle(ev)
    local text = zo_strlower(ev.title .. "\n" .. table.concat(ev.desc, "\n"))
    local want = "standard"
    if text:find("trainer") or text:find("training") then
        want = "educat"
    elseif text:find("zerg") or text:find("loot%s*run") then
        want = "speed"
    end
    for flag in ZO_FlagHelpers.FlagIterator(GROUP_FINDER_PLAYSTYLE_ITERATION_BEGIN, GROUP_FINDER_PLAYSTYLE_ITERATION_END) do
        local name = GetString("SI_GROUPFINDERPLAYSTYLE", flag)
        if zo_strlower(name):find(want, 1, true) then return flag, name end
    end
    return nil
end

-- "2 tanks, 2 healers, 8 DPS" for the listing's roles.
local function RolesText(desired)
    local parts = {}
    for _, kind in ipairs({ "tank", "heal", "dps" }) do
        local n = desired[ROLE_OF_KIND[kind]]
        parts[#parts + 1] = string.format("%d %s", n, NEED_WORDS[kind][n == 1 and 1 or 2])
    end
    return table.concat(parts, ", ")
end

-- Voice (1.16.1, Albert): a post with "learn" in it needs voice chat. The listing ticks Voice
-- Chat Required and says VOICE REQUIRED in the title and the description.
local VOICE = "VOICE REQUIRED"
local function NeedsVoice(ev)
    return zo_strlower(ev.title .. "\n" .. table.concat(ev.desc, "\n")):find("learn") ~= nil
end

-- The listing's description: the description from the sesh post (1.15.2, Albert). The Group
-- Finder shows the roles filled and needed itself. Paragraphs are joined; a list of short lines
-- becomes "a, b, c"; a line like "THERE ARE REQUIREMENTS" takes the list under it ("...: a, b").
-- The first line is left out when it's the title again in capitals. Cut at a word to the limit.
function Events:ListingDescription(state)
    local ev = state.ev
    local paragraphs, current = {}, {}
    for _, line in ipairs(ev.desc) do
        line = Trim(Printable(line))
        if line == "" then
            if #current > 0 then paragraphs[#paragraphs + 1] = current; current = {} end
        else
            current[#current + 1] = line
        end
    end
    if #current > 0 then paragraphs[#paragraphs + 1] = current end
    local first = paragraphs[1]
    if first and #first == 1 and first[1] == first[1]:upper() and first[1]:find("%a") then table.remove(paragraphs, 1) end

    local parts = {}
    local i = 1
    while i <= #paragraphs do
        local text = table.concat(paragraphs[i], ", ")
        local nextOne = paragraphs[i + 1]
        if #paragraphs[i] == 1 and nextOne and text:find(":$") then
            text = text .. " " .. table.concat(nextOne, ", ")
            i = i + 1
        elseif #paragraphs[i] == 1 and nextOne and zo_strlower(text):find("requir") and not text:find("[%.!%?]$") then
            text = text .. ": " .. table.concat(nextOne, ", ")
            i = i + 1
        end
        if not text:find("[%.!%?]$") then text = text .. "." end
        parts[#parts + 1] = text
        i = i + 1
    end
    local description = table.concat(parts, " ")
    local max = GROUP_FINDER_GROUP_LISTING_DESCRIPTION_MAX_LENGTH
    local voice = NeedsVoice(ev) and (VOICE .. ". ") or ""
    max = max - #voice
    if #description > max then
        -- Cut after the last sentence or list item that fits; at a word if that leaves too little.
        local head = description:sub(1, max)
        local cut = head:match("^(.*[%.!%?,])%s") or ((#description == max + 1 or description:sub(max + 1, max + 1) == " ") and head:match("^(.*[%.!%?,])$"))
        if not cut or #cut < max / 2 then cut = description:sub(1, max + 1):match("^(.*)%s") or head end
        description = Trim(cut):gsub("[,:;]$", "")
    end
    return voice .. description
end

-- A title the Group Finder takes (1.13.3): letters and spaces only (digits, emoji and symbols
-- become spaces), single spaces, cut at a word to the length limit, ending with a letter.
-- The game allows "four hyphens, apostrophes, or spaces at most" in a title (Albert's test,
-- 1.16.5), so five words. Too many words: day names go first, then words from the end.
local MAX_TITLE_WORDS = 5
local DAY_NAMES = { monday = true, tuesday = true, wednesday = true, thursday = true, friday = true, saturday = true, sunday = true }
local function FitWords(title, maxWords)
    local words = {}
    for word in title:gmatch("%S+") do words[#words + 1] = word end
    for i = #words, 1, -1 do
        if #words > maxWords and DAY_NAMES[zo_strlower(words[i])] then table.remove(words, i) end
    end
    while #words > maxWords do table.remove(words) end
    return table.concat(words, " ")
end

local function CleanTitle(text, max, maxWords)
    local title = Printable(text):gsub("[^%a%s]", " "):gsub("%s+", " ")
    title = FitWords(Trim(title), maxWords or MAX_TITLE_WORDS)
    max = max or GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH
    if #title > max then
        local cut = title:sub(1, max + 1):match("^(.*)%s") or title:sub(1, max)
        title = Trim(cut)
    end
    return (title:gsub("[^%a]+$", ""))
end

local function WithVoiceTitle(title)
    if title:find(VOICE, 1, true) then return title end
    local base = CleanTitle(title, GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH - #VOICE - 1, MAX_TITLE_WORDS - 2)
    return base ~= "" and (base .. " " .. VOICE) or VOICE
end

-- Text cut at a word to max characters.
local function CutAtWord(text, max)
    if #text <= max then return text end
    return Trim(text:sub(1, max + 1):match("^(.*)%s") or text:sub(1, max))
end

local function TitleOK(title)
    return title ~= "" and #title <= GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH
        and #{ IsValidGroupFinderListingTitle(title) } == 0   -- 1.15.1: count violations like ZOS does (select("#") counted a nil return as one)
end

function Events:AskListing()
    local state = self:State()
    if not state then U.Print("Paste a sesh sign-up post first."); return end
    if HasGroupListingForUserType(GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING) then
        U.Print("You already have a Group Finder listing. Change or remove it in the game's Group Finder window.")
        return
    end
    if not IsUnitSoloOrGroupLeader("player") then
        U.Print("Only the group leader can create a Group Finder listing.")
        return
    end
    local ev = state.ev
    local trial = self:PickTrial(ev)
    if not trial then SetGroupFinderUserTypeGroupListingCategory(DRAFT, GROUP_FINDER_CATEGORY_CUSTOM) end
    local description = self:ListingDescription(state)
    local maxDesc = GROUP_FINDER_GROUP_LISTING_DESCRIPTION_MAX_LENGTH
    if #description > maxDesc then description = description:sub(1, maxDesc) end
    local roles = self:ListingRoles(state, trial ~= nil)
    local _, playstyle = self:PickPlaystyle(ev)
    if trial and playstyle then trial = trial .. ", " .. playstyle end
    self:OpenInput({
        title = "Group Finder listing",
        hint = string.format("First line: the listing's title (letters and spaces, at most 5 words and %d characters; numbers and symbols are taken out). The rest: its description (up to %d characters). %s%s%s Edit it, then press Create listing.",
            GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH, maxDesc,
            trial and ("Activity: " .. trial .. ". ") or "Activity: Custom (no trial named in the post). ",
            (ev.minCP or 0) > 0 and string.format("Requires CP %d. ", ev.minCP) or "",
            roles and ("Group: " .. RolesText(roles) .. " (the Group Finder shows who's there and who's still needed).") or ""),
        okLabel = "Create listing",
        okTip = "Creates the Group Finder listing. Accept applicants in the game's Group Finder window.",
        text = (NeedsVoice(ev) and WithVoiceTitle(ev.title) or CleanTitle(ev.title)) .. "\n" .. description,
        onOk = function(text) self:CreateListing(text) end,
    })
end

-- 1.16.6: the Group Finder lists a trial at your own difficulty (the game's window switches
-- it with SetVeteranDifficulty when you pick Normal or Veteran), so switch it the same way and
-- create the listing once the game says it changed (or after 3 seconds).
function Events:SwitchDifficultyThen(veteran, fn)
    U.Print("Switching your difficulty to %s for the listing, like the game's Group Finder does...", veteran and "Veteran" or "Normal")
    local done = false
    local function Go()
        if done then return end
        done = true
        EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_EventsDifficulty", EVENT_VETERAN_DIFFICULTY_CHANGED)
        EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_EventsDifficulty", EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED)
        fn()
    end
    local function Later() zo_callLater(Go, 300) end
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_EventsDifficulty", EVENT_VETERAN_DIFFICULTY_CHANGED, Later)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_EventsDifficulty", EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, Later)
    zo_callLater(Go, 3000)
    SetVeteranDifficulty(veteran)
end

-- "Veteran" or "Normal": the group's difficulty, or yours when you are solo.
function Events.YourDifficulty()
    local veteran
    if IsUnitGrouped("player") then veteran = IsGroupUsingVeteranDifficulty() else veteran = IsUnitUsingVeteranDifficulty("player") end
    return veteran and "Veteran" or "Normal"
end

function Events:CreateListing(text, switched)
    local state = self:State()
    if not state then return end
    local ev = state.ev
    if not switched and self:PickTrial(ev) then
        local veteran = Events.WantsVeteran(ev)
        if (Events.YourDifficulty() == "Veteran") ~= veteran then
            self:SwitchDifficultyThen(veteran, function() self:CreateListing(text, true) end)
            return
        end
    end
    local title, description = text:match("^([^\n]*)\n?(.*)$")
    title = Trim(title)
    description = Trim(description):sub(1, GROUP_FINDER_GROUP_LISTING_DESCRIPTION_MAX_LENGTH)
    -- Tidy the title instead of refusing it: digits and symbols out, cut to the limit. If the
    -- game still won't take it, fall back to the event's name, tidied the same way.
    -- Order (1.16.3): the event's name with VOICE REQUIRED, the event's name, then the trial's
    -- name. The first title the game refuses is kept so chat can say why.
    local typed = title
    local voice = NeedsVoice(ev)
    local names = { title, CleanTitle(title), CleanTitle(ev.title) }
    local pickedTrial = self:PickTrial(ev)
    local refused
    title = nil
    local function Try(candidate)
        if title or candidate == "" then return end
        if TitleOK(candidate) then title = candidate elseif not refused then refused = candidate end
    end
    if voice then for _, name in ipairs(names) do Try(WithVoiceTitle(name)) end end
    for _, name in ipairs(names) do Try(name) end
    if pickedTrial then
        if voice then Try(WithVoiceTitle(CleanTitle(pickedTrial))) end
        Try(CleanTitle(pickedTrial))
    end
    if voice and not description:find(VOICE, 1, true) then
        description = VOICE .. ". " .. CutAtWord(description, GROUP_FINDER_GROUP_LISTING_DESCRIPTION_MAX_LENGTH - #VOICE - 2)
    end
    if not title then
        U.Print("The Group Finder won't take \"%s\" as a title: %s", typed, ZO_GroupFinder_GetGroupTitleViolationString(typed))
        return
    end
    if title ~= typed then
        local why = string.format("the Group Finder takes letters and spaces only, at most %d words and %d characters", MAX_TITLE_WORDS, GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH)
        if refused and #refused <= GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH then
            why = string.format("the game refused \"%s\": %s", refused, ZO_GroupFinder_GetGroupTitleViolationString(refused))
        end
        U.Print("Title changed to \"%s\" (%s).", title, why)
    elseif voice and not title:find(VOICE, 1, true) and refused then
        U.Print("%s didn't fit in the title (the game refused \"%s\": %s). It's at the start of the description, and Voice Chat Required is ticked.",
            VOICE, refused, #refused > GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH and "too long" or ZO_GroupFinder_GetGroupTitleViolationString(refused))
    end
    local trial = self:PickTrial(ev)
    if not trial then
        SetGroupFinderUserTypeGroupListingCategory(DRAFT, GROUP_FINDER_CATEGORY_CUSTOM)
        UpdateGroupFinderUserTypeGroupListingOptions(DRAFT)
        -- Custom listings pick a size: the smallest that fits everyone the post asks for.
        local wanted = 0
        for _, section in ipairs(ev.sections) do
            if section.kind ~= "standby" and section.kind ~= "out" then wanted = wanted + (section.max or #section.people) end
        end
        wanted = math.max(wanted, state.groupCount + 1)
        for size = GetGroupFinderUserTypeGroupSizeIterationBegin(DRAFT), GetGroupFinderUserTypeGroupSizeIterationEnd(DRAFT) do
            SetGroupFinderUserTypeGroupListingGroupSize(DRAFT, size)
            if GetGroupFinderUserTypeGroupListingNumRoles(DRAFT) >= wanted then break end
        end
    end
    if trial then
        local playstyle = self:PickPlaystyle(ev)
        if playstyle then SetGroupFinderUserTypeGroupListingPlaystyle(DRAFT, playstyle) end
    end
    SetGroupFinderUserTypeGroupListingRequiresVOIP(DRAFT, voice)
    SetGroupFinderUserTypeGroupListingTitle(DRAFT, title)
    SetGroupFinderUserTypeGroupListingDescription(DRAFT, description)
    local desired, numRoles = self:ListingRoles(state, trial ~= nil)
    SetGroupFinderUserTypeGroupListingEnforceRoles(DRAFT, desired ~= nil)
    if desired then
        local total = 0
        for _, role in ipairs({ LFG_ROLE_TANK, LFG_ROLE_HEAL, LFG_ROLE_DPS }) do
            SetGroupFinderUserTypeGroupListingRoleCount(DRAFT, role, desired[role])
            total = total + desired[role]
        end
        SetGroupFinderUserTypeGroupListingRoleCount(DRAFT, LFG_ROLE_INVALID, math.max(0, numRoles - total))
    end
    -- CP last. Tick the box first, then the points, the same order as the game's own window
    -- (points set before the box didn't stick in game). Capped like the game's window caps it.
    local minCP = ev.minCP or 0
    SetGroupFinderUserTypeGroupListingRequiresChampion(DRAFT, minCP > 0)
    if minCP > 0 then
        local maxCP = GetMaxSpendableChampionPointsInAttribute() * GetNumChampionDisciplines()
        if minCP > maxCP then minCP = maxCP end
        SetGroupFinderUserTypeGroupListingChampionPoints(DRAFT, minCP)
        local ticked = DoesGroupFinderUserTypeGroupListingRequireChampion(DRAFT)
        local points = GetGroupFinderCreateGroupListingChampionPoints(DRAFT)
        if not ticked or points ~= minCP then
            U.Print("The game didn't take the CP requirement (asked for CP %d, it has %s). Check Champion Points Required in the Group Finder window.",
                minCP, ticked and tostring(points) or "none")
        end
    end
    self.listingPending = true
    self.listingCP = minCP
    self.listingTrial = trial ~= nil
    RequestCreateGroupListing()
    local details = { minCP > 0 and string.format("CP %d+", minCP) or "no CP requirement in the post" }
    if trial then
        local primaryText, secondaryText = GetGroupFinderUserTypeGroupListingOptionsSelectionText(DRAFT)
        table.insert(details, 1, string.format("post: %s; listing: %s %s; your difficulty: %s", trial, primaryText, secondaryText, Events.YourDifficulty()))
        self.listingDifficultyName = (GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex(DRAFT, self.listingDifficulty))
    else
        table.insert(details, 1, "no trial found in the post, so a Custom listing")
    end
    U.Print("Asking the game to create the Group Finder listing \"%s\" (%s)...", title, table.concat(details, "; "))
end

function Events:OnListingResult(result)
    if not self.listingPending then return end
    self.listingPending = false
    if result == GROUP_FINDER_ACTION_RESULT_SUCCESS then
        U.Print("Your Group Finder listing is up. Accept applicants in the game's Group Finder window.")
        local created = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
        if (self.listingCP or 0) > 0 and not DoesGroupFinderUserTypeGroupListingRequireChampion(created) then
            U.Print("The game dropped the CP requirement (CP %d) from the listing. Tick Champion Points Required in the Group Finder window and save.", self.listingCP)
        end
        if self.listingTrial then
            local _, isSet = GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex(created, self.listingDifficulty)
            if not isSet then
                local primaryText, secondaryText = GetGroupFinderUserTypeGroupListingOptionsSelectionText(created)
                U.Print("The game listed it as %s %s, not %s. Your difficulty is %s.", primaryText, secondaryText, self.listingDifficultyName or "the post's", Events.YourDifficulty())
            end
        end
    else
        U.Print("The Group Finder listing wasn't created: %s", GetString("SI_GROUPFINDERACTIONRESULT", result))
    end
end

-- Settings ----------------------------------------------------------------------------------

function Events:BuildSettings(options)
    self.panel = GT.Settings:AddPage("Events", "Events", self:SettingsControls(), true)
    GT.Settings:AddPointer(options, "Events", "Sign-ups from sesh event posts, missing people, guild ads and Group Finder listings are on their own page: \"Fury's Guild Management - Events\" in the Add-Ons list.",
        function() self:OpenSettings() end)
end

function Events:OpenSettings()
    LibAddonMenu2:OpenToPanel(self.panel)
end

function Events:SettingsControls()
    local sv = self.sv
    local controls = {
        { type = "description", text = "Copy a sesh event post in Discord and paste it into the Events tab (/gt events > Paste sign-ups). The tab shows each sign-up next to who is in your group, and lets you whisper, invite or mail the missing people, advertise the open slots in your guilds, and create a Group Finder listing. Nothing is sent without a click or Enter from you." },
        { type = "checkbox", name = "Turn on Events", tooltip = "Shows the Events tab and keeps it up to date while people join your group or log in.",
          getFunc = function() return sv.enabled end, setFunc = function(v) self:SetEnabled(v) end, default = false },
        { type = "description", title = "Texts", text = "You can use {name} (their Discord name), {event} (the event title), {time} (how long until it starts, like \"3d 4h 30m from now\", so it's right in every time zone), {date} (the time as the post shows it), {need} (open slots, like \"1 tank, 2 DPS\": sign-up slots nobody took before the group forms, what the group is missing after), {cp} (\" (CP 160+)\" when the post has a CP requirement), {code} (your invite code) and {me} (your @account)." },
        { type = "editbox", name = "Whisper", tooltip = "Goes in the chat box when you right-click a sign-up > Whisper. You press Enter.",
          getFunc = function() return sv.whisperText end, setFunc = function(v) sv.whisperText = v end, default = Events.defaults.whisperText },
        { type = "editbox", name = "Mail subject", tooltip = "For right-click > Mail. The mail opens filled in; you press Send.",
          getFunc = function() return sv.mailSubject end, setFunc = function(v) sv.mailSubject = v end, default = Events.defaults.mailSubject },
        { type = "editbox", name = "Mail text", isMultiline = true, tooltip = "For right-click > Mail.",
          getFunc = function() return sv.mailText end, setFunc = function(v) sv.mailText = v end, default = Events.defaults.mailText },
        { type = "slider", name = "Group forms (minutes before start)", min = 0, max = 60, step = 5,
          tooltip = "Before this, ads ask people to sign up for the slots nobody has taken. From this time on, ads ask for replacements to join now, and no-shows count as open slots. Read from the Time in the sesh post.",
          getFunc = function() return sv.formUpMinutes or 15 end, setFunc = function(v) sv.formUpMinutes = v; self.cache = nil end, default = Events.defaults.formUpMinutes },
        { type = "editbox", name = "Guild ad for sign-ups", tooltip = "Before the group forms: Advertise in guilds puts this in each ticked guild's chat box. {need} is the sign-up slots nobody has taken. Up to 350 characters.",
          getFunc = function() return sv.signupAdText or Events.defaults.signupAdText end, setFunc = function(v) sv.signupAdText = v end, default = Events.defaults.signupAdText },
        { type = "checkbox", name = "Invite by code",
          tooltip = "Anyone who types the invite code (upper or lower case) in the chat of a guild ticked below, or whispers it to you, gets a group invite. With no event pasted: anyone, up to a full group. With an event pasted: once its group forms (until 2 hours after the start time), up to its group size, and not when their CP is under the post's requirement. Only while you lead the group or are solo. Put {code} in the replacement ad so people know it. Also on the Events tab: the Invite by code button and Code box. Starts turned off at every login and /reloadui, and turns itself off when your group fills up or breaks up.",
          getFunc = function() return sv.autoInvite end, setFunc = function(v) if v ~= sv.autoInvite then self:SetCodeOn(v) end end, default = false },
        { type = "editbox", name = "Invite code", tooltip = "The whole message has to be this (upper or lower case). {code} in the ads.",
          getFunc = function() return sv.inviteCode or Events.defaults.inviteCode end, setFunc = function(v) sv.inviteCode = zo_strtrim(v) end, default = Events.defaults.inviteCode },
        { type = "editbox", name = "Guild ad for replacements", tooltip = "Once the group forms: Advertise in guilds puts this in each ticked guild's chat box. {need} is what your group is missing now, no-shows included. While Invite by code is off, the part with {code} is left out (\"Type {code} into guild chat or whisper {me}.\" becomes \"Whisper {me}.\"). Up to 350 characters.",
          getFunc = function() return sv.adText end, setFunc = function(v) sv.adText = v end, default = Events.defaults.adText },
        { type = "header", name = "Guilds to advertise in" },
    }
    for _, guildId in ipairs(U.GetGuildIds()) do
        local gid = guildId
        controls[#controls + 1] = { type = "checkbox", name = U.GuildName(gid), tooltip = "Advertise in guilds puts the ad in this guild's chat box.",
            getFunc = function() return sv.adGuilds[gid] == true end, setFunc = function(v) sv.adGuilds[gid] = v or nil end, default = false }
    end
    controls[#controls + 1] = { type = "header", name = "Discord names" }
    controls[#controls + 1] = { type = "button", name = "Forget all matched accounts", width = "half", isDangerous = true,
        tooltip = "Forgets every account you picked for a Discord name with right-click > Set account. Matches by name still work.",
        warning = "Forgets every Discord name to account match you set.",
        func = function() sv.map = {}; self.cache = nil; GT.Report:RefreshIfShown(); U.Print("Forgot every matched account.") end }
    return controls
end
