PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- Sharing DPS and HPS with the group (LibGroupBroadcast, optional)
--
-- Every member running this add-on sends their fight's DPS and HPS every SEND_MS while a fight goes
-- on, and once more when it ends. The HUD lists the members heard from (and the player) with each
-- one's share of the group's DPS and HPS; a fight's record keeps what the others had sent during it,
-- so the breakdown screen shows the player's share afterwards.
--
-- THE LIBRARY (read from its source, github.com/sirinsidiator/ESO-LibGroupBroadcast):
--   * protocol id 467 (9 bits; PB's block is 460-469);
--   * a numeric field is 2..32 bits; one bad field makes Finalize fail and nothing is sent or heard;
--   * a protocol is NOT sent while the player is in combat unless it is finalized with
--     isRelevantInCombat = true (BroadcastManager:RequestSendData), which is what a meter needs;
--   * replaceQueuedMessages = true: a newer reading takes the place of one still waiting in the queue;
--   * Send returns false when not grouped; delivery is best effort (a frame the game refuses is
--     dropped), which is fine for a reading that is sent again two seconds later;
--   * the sender gets its own messages back: they are dropped by display name.
--
-- The message, 13 bytes with its header:
--   version 2 | state 2 (1 in a fight, 2 the fight ended) | fight 8 (the sender's fight number, mod
--   256) | secs 16 (active seconds) | dps 24 | hps 24   (dps / hps above 16,777,215 are trimmed)
--
-- SHARE: each member's DPS over their own active time; the player's share is the player's DPS over
-- the sum of everyone's. DPS rather than totals, because members start and stop fighting at
-- different moments.
---------------------------------------------------------------------------------------------------

local group = {
    ready = false,
    why = "not set up yet",
    sent = 0, refused = 0, heard = 0, own = 0, mismatched = 0,
    members = {}, -- [display name] = { name, dps, hps, secs, live, fight, at }
    lastSend = -1000,
    sentSerial = nil, -- the fight number a live reading was sent for
}
ADDON.group = group

local ID = 467
local NAME = "PBsBattleScrollsV1"
local VERSION = 1
local STATE_LIVE, STATE_END = 1, 2
local SEND_SEC = 2
local STALE_SEC = 8 -- a member in a fight not heard from for this long is not shown
local MAX_VALUE = 16777215
local MAX_MEMBERS = 12

group.ID = ID
group.FIELDS = {
    { "version", 2 }, { "state", 2 }, { "fight", 8 }, { "secs", 16 }, { "dps", 24 }, { "hps", 24 },
}

local Plain = ADDON.Plain

local function Now()
    return GetFrameTimeSeconds()
end

local function Grouped()
    return type(GetGroupSize) == "function" and GetGroupSize() > 1
end

local function OwnAccount()
    return type(GetDisplayName) == "function" and GetDisplayName() or ""
end

function group.OwnName()
    local name = type(GetUnitName) == "function" and Plain(GetUnitName("player") or "") or ""
    return name ~= "" and name or OwnAccount()
end

---------------------------------------------------------------------------------------------------
-- Setting up
---------------------------------------------------------------------------------------------------

function group:Setup()
    if self.ready then
        return true
    end
    local Library = LibGroupBroadcast
    if not Library then
        self.why = "LibGroupBroadcast is not installed"
        return false
    end
    local stage = "registerHandler"
    local ok, err = pcall(function()
        local handler = assert(Library:RegisterHandler(ADDON.name), "RegisterHandler returned nil")
        handler:SetDisplayName(ADDON.title)
        handler:SetDescription("Shares your fight's DPS and HPS with group members who run it too.")
        stage = "declareProtocol"
        local protocol = assert(handler:DeclareProtocol(ID, NAME), "DeclareProtocol returned nil")
        protocol:SetDisplayName(ADDON.title)
        stage = "fields"
        for _, field in ipairs(self.FIELDS) do
            -- values are clamped to the field before Send (Whole), so none is refused for its size
            protocol:AddField(Library.CreateNumericField(field[1], { numBits = field[2] }))
        end
        stage = "onData"
        protocol:OnData(function(unitTag, data)
            -- a failure in here must not reach the library's own code
            local fine, why = pcall(self.Receive, self, unitTag, data)
            if not fine then
                self.mismatched = self.mismatched + 1
                self.lastError = tostring(why)
            end
        end)
        stage = "finalize"
        assert(protocol:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = true }),
            "Finalize refused the protocol (see LibGroupBroadcast's log)")
        self.protocol = protocol
    end)
    if not ok then
        self.protocol = nil
        local first = (tostring(err):match("^[^\n]*") or tostring(err)):gsub("^.*[/\\]", "")
        self.why = "[" .. stage .. "] " .. first
        return false
    end
    self.ready = true
    self.why = "ready"
    return true
end

---------------------------------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------------------------------

local function Whole(value, top)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value < 0 then
        return 0
    end
    return math.min(value, top)
end

function group:CanSend()
    if not self.ready or not self.protocol then
        return false, self.why
    end
    if not ADDON.sv.share then
        return false, "sharing is off in the settings"
    end
    if not Grouped() then
        return false, "not in a group"
    end
    if not self.protocol:IsEnabled() then
        return false, "the protocol is switched off in LibGroupBroadcast's settings"
    end
    return true
end

function group:Send(state, serial, secs, dps, hps)
    local can, why = self:CanSend()
    if not can then
        self.lastWhy = why
        return false
    end
    local accepted = self.protocol:Send({
        version = VERSION, state = state, fight = serial % 256, secs = Whole(secs, 65535),
        dps = Whole(dps, MAX_VALUE), hps = Whole(hps, MAX_VALUE),
    })
    if accepted then
        self.sent = self.sent + 1
        self.lastWhy = nil
    else
        self.refused = self.refused + 1
        self.lastWhy = "the library refused the message"
    end
    return accepted
end

-- Every tick of a fight: a reading every SEND_SEC.
function group:OnFightTick(fight, now)
    if now - self.lastSend < SEND_SEC or now - fight.startT < SEND_SEC then
        return
    end
    self.lastSend = now
    local secs = math.max(1, fight.lastT - fight.startT)
    if self:Send(STATE_LIVE, fight.serial, secs, fight.dmg / secs, fight.heal / secs) then
        self.sentSerial = fight.serial
    end
end

-- The fight ended: the final reading, if the group heard about this fight at all.
function group:OnFightClosed(record)
    if self.sentSerial ~= record.serial then
        return
    end
    self.sentSerial = nil
    self:Send(STATE_END, record.serial, record.secs, record.dmg / record.secs, record.heal / record.secs)
end

---------------------------------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------------------------------

function group:Receive(unitTag, data)
    if not ADDON.sv or not ADDON.sv.share then
        return
    end
    if data.version ~= VERSION then
        self.mismatched = self.mismatched + 1
        return
    end
    local account = type(GetUnitDisplayName) == "function" and GetUnitDisplayName(unitTag) or ""
    if account ~= "" and account == OwnAccount() then
        self.own = self.own + 1
        return
    end
    local key = account ~= "" and account or tostring(unitTag)
    local name = type(GetUnitName) == "function" and Plain(GetUnitName(unitTag) or "") or ""
    if name == "" then
        name = account
    end
    self.heard = self.heard + 1
    local now = Now()
    local live = data.state == STATE_LIVE
    local member = self.members[key]
    if not member then
        member = {}
        self.members[key] = member
    end
    member.name, member.dps, member.hps, member.secs = name, data.dps, data.hps, data.secs
    member.live, member.fight, member.at = live, data.fight, now

    -- Into the player's fight: readings sent during it, and the final one of a fight already seen
    -- in it (a final reading of an older fight is not this fight's).
    local fight = ADDON.fights.live
    if fight then
        local seen = fight.group[key]
        if live or (seen and seen.fight == data.fight) then
            fight.group[key] = { name = name, dps = data.dps, hps = data.hps, secs = data.secs, fight = data.fight }
        end
    end
    if ADDON.hud then
        ADDON.hud:Poke()
    end
end

-- A member left, or the group changed: forget who is no longer in it.
function group:Prune()
    if not Grouped() then
        self.members = {}
        return
    end
    local inGroup = {}
    for index = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(index)
        if tag then
            inGroup[GetUnitDisplayName(tag) or ""] = true
        end
    end
    for key in pairs(self.members) do
        if not inGroup[key] then
            self.members[key] = nil
        end
    end
end

---------------------------------------------------------------------------------------------------
-- What is shown
---------------------------------------------------------------------------------------------------

local function ByDps(a, b)
    if a.dps ~= b.dps then
        return a.dps > b.dps
    end
    return a.name < b.name
end

-- Fills each row's shares of the rows' sums.
local function Shares(rows)
    local sumD, sumH = 0, 0
    for _, row in ipairs(rows) do
        sumD = sumD + row.dps
        sumH = sumH + row.hps
    end
    for _, row in ipairs(rows) do
        row.dpsShare = sumD > 0 and row.dps / sumD or 0
        row.hpsShare = sumH > 0 and row.hps / sumH or 0
    end
    return sumD, sumH
end

-- The HUD's rows: the members whose reading is current (in a fight and heard from lately, or ended
-- within the hold time) and the player when the player has numbers. Empty when no other member is
-- current: the list is only worth its room with somebody to compare with.
function group:HudRows(now, holdSec, mine)
    local rows = {}
    if not ADDON.sv.share then
        return rows
    end
    for _, m in pairs(self.members) do
        local age = now - m.at
        if (m.live and age <= STALE_SEC) or (not m.live and age <= holdSec) then
            rows[#rows + 1] = { name = m.name, dps = m.dps, hps = m.hps, ended = not m.live }
        end
    end
    if #rows == 0 then
        return rows
    end
    if mine then
        rows[#rows + 1] = { name = group.OwnName(), dps = mine.dps, hps = mine.hps, ended = mine.ended, self = true }
    end
    table.sort(rows, ByDps)
    Shares(rows)
    return rows
end

-- Called while a fight is folded into its record: the members' readings, the player's own and the
-- player's shares. Nothing when no member sent anything during the fight.
function group.FoldInto(fight, record)
    local rows = {}
    for _, g in pairs(fight.group or {}) do
        rows[#rows + 1] = { name = g.name, dps = g.dps, hps = g.hps, secs = g.secs }
    end
    if #rows == 0 then
        return
    end
    local me = { name = group.OwnName(), dps = math.floor(record.dmg / record.secs + 0.5),
        hps = math.floor(record.heal / record.secs + 0.5), secs = math.floor(record.secs + 0.5), self = true }
    rows[#rows + 1] = me
    table.sort(rows, ByDps)
    local sumD, sumH = Shares(rows)
    while #rows > MAX_MEMBERS do
        -- the player is never the one cut
        table.remove(rows, rows[#rows].self and #rows - 1 or #rows)
    end
    local healRank = 1
    for _, row in ipairs(rows) do
        if not row.self and row.hps > me.hps then
            healRank = healRank + 1
        end
    end
    local dpsRank = 1
    for index, row in ipairs(rows) do
        if row.self then
            dpsRank = index
        end
    end
    record.group = rows
    record.dmgShare = sumD > 0 and me.dps / sumD or nil
    record.healShare = sumH > 0 and me.hps / sumH or nil
    record.dpsRank, record.healRank = dpsRank, healRank
end

function group:CurrentCount(now)
    local count = 0
    for _, m in pairs(self.members) do
        if now - m.at <= STALE_SEC then
            count = count + 1
        end
    end
    return count
end
