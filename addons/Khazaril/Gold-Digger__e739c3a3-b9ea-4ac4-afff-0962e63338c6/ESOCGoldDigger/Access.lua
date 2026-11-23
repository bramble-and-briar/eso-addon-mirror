-- Gold Digger access. The owner always has access and invites chosen accounts by in-game mail.
-- An invite lasts six calendar months. A removal mail ends it the next time that player opens their mail.
-- The token is in the mail's subject, so reading it doesn't mark the mail as read.
-- Typed codes still work if Xbox won't let an add-on send or read mail.
-- This keeps out ordinary players. The code is readable, so it can't stop a determined one.

local GP = ESOC_GoldDigger
local Access = {}
GP.Access = Access

Access.OWNER = "@DextrousDigits"
local SECRET = "64b68fb9318a6de71d79682065439147"
local ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
local ACCESS_MONTHS = 6
local MAX_GENERATIONS = 64
local INVITE_PREFIX = "Gold Digger "
local REMOVE_PREFIX = "Gold Digger off "
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

GP.LOCKED_TEXT = "Private add-on. An invite is needed."

-- For comparing names. Xbox gamertags can contain spaces, so mail uses the name as typed.
function Access.Normalize(name)
    name = string.lower((string.gsub(name or "", "%s+", "")))
    if name == "" or name == "@" then return nil end
    if string.sub(name, 1, 1) ~= "@" then name = "@" .. name end
    return name
end

local function displayName(name)
    local trimmed = string.match(name or "", "^%s*(.-)%s*$") or ""
    if trimmed == "" or trimmed == "@" then return nil end
    if string.sub(trimmed, 1, 1) ~= "@" then trimmed = "@" .. trimmed end
    return trimmed
end

function Access.IsOwner()
    return Access.Normalize(GetDisplayName()) == Access.Normalize(Access.OWNER)
end

local function floorDiv(a, b) return math.floor(a / b) end

-- Calendar year and month (UTC) from a timestamp. Add-ons can't rely on os.date on console.
local function civil(time)
    local z = floorDiv(time, 86400) + 719468
    local era = floorDiv(z, 146097)
    local doe = z - era * 146097
    local yoe = floorDiv(doe - floorDiv(doe, 1460) + floorDiv(doe, 36524) - floorDiv(doe, 146096), 365)
    local doy = doe - (365 * yoe + floorDiv(yoe, 4) - floorDiv(yoe, 100))
    local mp = floorDiv(5 * doy + 2, 153)
    local month = mp < 10 and mp + 3 or mp - 9
    local year = yoe + era * 400 + (month <= 2 and 1 or 0)
    return year, month
end

-- A number for each calendar month.
function Access.Period(time)
    local year, month = civil(time or GetTimeStamp())
    return year * 12 + month - 1
end

function Access.PeriodName(period)
    return MONTHS[period % 12 + 1] .. " " .. math.floor(period / 12)
end

function Access.LastPeriod(start)
    return start + ACCESS_MONTHS - 1
end

local function hash(text, multiplier, modulus)
    local value = 7
    for index = 1, #text do
        value = (value * multiplier + string.byte(text, index)) % modulus
    end
    return value
end

local function encode(value, length)
    local out = {}
    for index = 1, length do
        local digit = value % 32
        out[index] = string.sub(ALPHABET, digit + 1, digit + 1)
        value = math.floor(value / 32)
    end
    return table.concat(out)
end

local function token(kind, name, first, second)
    local text = table.concat({ SECRET, kind, Access.Normalize(name) or "", first, second, SECRET }, "|")
    return encode(hash(text, 131, 2147483647), 4) .. encode(hash(text, 257, 2147483629), 4)
end

-- Eight characters, with look-alikes such as 0/O and 1/I left out.
function Access.CodeFor(name, start, generation)
    return token("grant", name, start, generation or 0)
end

function Access.RemovalCodeFor(name, generation)
    return token("off", name, generation or 0, 0)
end

function Access.Format(code)
    return string.sub(code, 1, 4) .. "-" .. string.sub(code, 5)
end

local function clean(text)
    return string.upper((string.gsub(text or "", "[^%w]", "")))
end

-- Accepts a code issued for this account in the last six months and not since removed.
function Access.Enter(text)
    local code = clean(text)
    local me, current = GetDisplayName(), Access.Period()
    local firstGeneration = GP.sv.minGeneration or 0
    for generation = firstGeneration, MAX_GENERATIONS - 1 do
        for start = current, current - ACCESS_MONTHS + 1, -1 do
            if code == Access.CodeFor(me, start, generation) then
                local held = GP.sv.access
                if not held or held.generation < generation or held.start <= start then
                    GP.sv.access = { start = start, generation = generation, code = code }
                end
                GP.RefreshLock()
                return GP.sv.access.start
            end
        end
    end
    return nil
end

local function applyRemoval(text)
    local code = clean(text)
    local me = GetDisplayName()
    for generation = 0, MAX_GENERATIONS - 1 do
        if code == Access.RemovalCodeFor(me, generation) then
            if generation + 1 > (GP.sv.minGeneration or 0) then GP.sv.minGeneration = generation + 1 end
            local held = GP.sv.access
            if held and held.generation < GP.sv.minGeneration then GP.sv.access = nil end
            return true
        end
    end
    return false
end

function Access.IsAllowed()
    if Access.IsOwner() then return true end
    local held = GP.sv.access
    if not held or held.generation < (GP.sv.minGeneration or 0) then return false end
    local current = Access.Period()
    if current < held.start or current > Access.LastPeriod(held.start) then return false end
    return held.code == Access.CodeFor(GetDisplayName(), held.start, held.generation)
end

function Access.StatusText()
    if Access.IsOwner() then return "Owner account. Manage players in Gold Digger Access." end
    if not Access.IsAllowed() then return GP.LOCKED_TEXT .. " Open your mail after you're invited, or enter a code." end
    return "Access through the end of " .. Access.PeriodName(Access.LastPeriod(GP.sv.access.start)) .. "."
end

-- Reads subjects only. The game supplies the sender, so another player can't fake the owner.
function Access.CheckMail()
    if Access.IsOwner() then return end
    local wasAllowed = Access.IsAllowed()
    local owner, invites, removed = Access.Normalize(Access.OWNER), {}, false
    local mailId = GetNextMailId(nil)
    while mailId do
        local sender, _, subject, _, _, fromSystem, fromCS, returned = GetMailItemInfo(mailId)
        if Access.Normalize(sender) == owner and not fromSystem and not fromCS and not returned and subject then
            if string.sub(subject, 1, #REMOVE_PREFIX) == REMOVE_PREFIX then
                if applyRemoval(string.sub(subject, #REMOVE_PREFIX + 1)) then removed = true end
            elseif string.sub(subject, 1, #INVITE_PREFIX) == INVITE_PREFIX then
                invites[#invites + 1] = string.sub(subject, #INVITE_PREFIX + 1)
            end
        end
        mailId = GetNextMailId(mailId)
    end
    -- Removals first, so an old invite still in the inbox can't undo one
    for _, code in ipairs(invites) do Access.Enter(code) end
    GP.RefreshLock()
    local allowed = Access.IsAllowed()
    if allowed and not wasAllowed then
        GP.Alert("invite accepted, access through " .. Access.PeriodName(Access.LastPeriod(GP.sv.access.start)))
    elseif removed and wasAllowed and not allowed then
        GP.Alert("your access has ended")
    end
    if allowed ~= wasAllowed then GP.Interface.Refresh() end
end

function Access.Install()
    EVENT_MANAGER:RegisterForEvent(GP.NAME .. "Access", EVENT_MAIL_INBOX_UPDATE, function()
        pcall(Access.CheckMail)
    end)
end

-- Owner's list of players.

local function infoFor(name)
    local key = Access.Normalize(name)
    local info = GP.sv.memberInfo[key]
    if not info then
        info = { generation = 0 }
        GP.sv.memberInfo[key] = info
    end
    return info
end

function Access.AddPlayer(name)
    local shown = displayName(name)
    local key = Access.Normalize(shown)
    if not key or key == Access.Normalize(Access.OWNER) then return false end
    for _, existing in ipairs(GP.sv.members) do
        if Access.Normalize(existing) == key then return false end
    end
    table.insert(GP.sv.members, shown)
    table.sort(GP.sv.members, function(a, b) return string.lower(a) < string.lower(b) end)
    infoFor(shown)
    GP.Interface.Refresh()
    return true
end

-- Takes them off the list. Old invites and codes for them can't be used by a later re-invite.
function Access.ForgetPlayer(name)
    local key = Access.Normalize(name)
    for index, existing in ipairs(GP.sv.members) do
        if Access.Normalize(existing) == key then
            table.remove(GP.sv.members, index)
            local info = infoFor(name)
            info.generation = info.generation + 1
            info.sentStart, info.removalFailed, info.inviteFailed = nil, nil, nil
            GP.Interface.Refresh()
            return true
        end
    end
    return false
end

function Access.SendInvite(name)
    local info = infoFor(name)
    local start = Access.Period()
    local code = Access.CodeFor(name, start, info.generation)
    local body = "You've been invited to use Gold Digger. Keep Gold Digger installed and open your mail to unlock it. "
        .. "Access lasts through the end of " .. Access.PeriodName(Access.LastPeriod(start)) .. "."
    local started = GP.Mail.Send(name, INVITE_PREFIX .. Access.Format(code), body, function(ok)
        info.inviteFailed = not ok or nil
        if ok then
            info.sentStart = start
            GP.Alert("invite sent to " .. name)
        else
            GP.Alert("mail didn't send. Give " .. name .. " the code instead")
        end
        GP.Interface.Refresh()
    end)
    if not started then GP.Alert("still sending the last mail") end
    return started
end

function Access.RequestRemoval(name)
    local info = infoFor(name)
    if not info.sentStart then return Access.ForgetPlayer(name) end
    local subject = REMOVE_PREFIX .. Access.Format(Access.RemovalCodeFor(name, info.generation))
    local body = "Your Gold Digger access has ended."
    local started = GP.Mail.Send(name, subject, body, function(ok)
        if ok then
            Access.ForgetPlayer(name)
            GP.Alert("removal sent to " .. name)
        else
            info.removalFailed = true
            GP.Alert("removal mail didn't send. See the Access page")
            GP.Interface.Refresh()
        end
    end)
    if not started then GP.Alert("still sending the last mail") end
    return started
end

function Access.RemovalFailed(name)
    return name ~= nil and infoFor(name).removalFailed == true
end

function Access.PlayersText()
    local members = GP.sv.members
    if #members == 0 then return "No players added yet." end
    local current = Access.Period()
    local lines = {}
    for _, name in ipairs(members) do
        local info = infoFor(name)
        local status = "Not invited yet"
        if info.sentStart then
            local last = Access.LastPeriod(info.sentStart)
            if current > last then
                status = "Expired, send a new invite"
            elseif current == last then
                status = "Ends this month, renew it"
            else
                status = "Invited through " .. Access.PeriodName(last)
            end
        end
        lines[#lines + 1] = name .. ": " .. status
        lines[#lines + 1] = "   Code: " .. Access.Format(Access.CodeFor(name, current, info.generation))
        if info.inviteFailed then lines[#lines + 1] = "   Mail failed. Send them this code yourself." end
        if info.removalFailed then
            lines[#lines + 1] = "   Removal failed. Mail them this exact subject: "
                .. REMOVE_PREFIX .. Access.Format(Access.RemovalCodeFor(name, info.generation))
        end
    end
    return table.concat(lines, "\n")
end
