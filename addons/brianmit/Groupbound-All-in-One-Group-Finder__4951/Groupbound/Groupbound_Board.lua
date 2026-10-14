-- Groupbound_Board.lua : one list from the Group Finder and chat.
--   merge   a leader with a Group Finder listing AND a chat post is one entry (chat text kept)
--   fit     "yes"   room for your role and your CP is enough
--           "maybe" the post doesn't say which roles it needs
--           "no"    full for your role, CP too low, DLC missing, delisted, couldn't join it ("gone")...
--   hide    players you hid, words from the "hide groups with these words" setting
--           "player" someone looking for a group (only shown with "Players looking")
--   sort    fits first, watched content and players you marked "good run" higher, older lower
--   alerts  a NEW group for content you watch (or any group that fits, setting "alertAll")
-- Contacts: who you applied to / whispered this session (status in the list, the "You're in"
-- card after joining knows which group it was).

local G = Groupbound
local L = G.L
local Content = G.Content
local Board = {}
G.Board = Board

Board.contacts = {}      -- [account lowercase] = { t, how, content, vet, title, replied }
Board.query = ""         -- the window's search text (lowercase)

local all, visible = {}, {}
local seen, knownTasks = {}, {}
local firstBuild = true
local lastAlert = 0

-- ---------------------------------------------------------------------------
-- Labels

-- "vSS HM", "LFM", "LFG"
function Board.Tag(e)
    if e.content then
        local s = Content.Short(e.content, e.vet)
        if e.hm then s = s .. " HM" end
        return s
    end
    if e.kind == "player" then return "LFG" end
    return e.finder and "GF" or "LFM"
end

-- the short tag in the difficulty's colors: "nSS" green, "vSS" gold, " HM" red-orange
function Board.ColoredTag(e)
    local C = G.COLOR
    if not e.content then return G.Colorize(C.selected, Board.Tag(e)) end
    local color = e.vet == true and C.diffVet or (e.vet == false and C.diffNormal or C.selected)
    local s = G.Colorize(color, Content.Short(e.content, e.vet))
    if e.hm then s = s .. " " .. G.Colorize(C.diffHM, "HM") end
    return s
end

-- "Normal" / "Veteran" / "Veteran · HM", colored (or plain for dimmed rows)
function Board.DifficultyText(e, plain)
    local C = G.COLOR
    local parts = {}
    local function Add(text, color) parts[#parts + 1] = plain and text or G.Colorize(color, text) end
    if e.vet == true then Add(G.L("VETERAN"), C.diffVet) elseif e.vet == false and (e.content or e.finder) then Add(G.L("NORMAL"), C.diffNormal) end
    if e.hm then Add("HM", C.diffHM) end
    local sep = plain and "  ·  " or G.Colorize(C.dim, "  ·  ")
    return table.concat(parts, sep)
end

function Board.ContentName(e)
    if e.content then return Content.Name(e.content) end
    if e.place and e.place ~= "" then return e.place end
    return L("CONTENT_UNKNOWN")
end

function Board.Title(e)
    if e.finder then return e.title ~= "" and e.title or e.text or "" end
    return e.text or ""
end

-- for showing only: "vKA_HM_NoDeath_Attempt" -> "vKA HM NoDeath Attempt" (a word without spaces
-- wrapped in the middle, user 2026-10-13); search and sorting keep the original text
function Board.Readable(text)
    return ((text or ""):gsub("_+", " "))
end

function Board.SourceColor(e)
    local C = G.COLOR
    if e.finder then return C.finder end
    return e.src == "guild" and C.guild or C.zone
end

function Board.SourceText(e)
    if e.finder then return L("SRC_FINDER") end
    if e.src == "guild" then return L("SRC_GUILD", e.where or "") end
    return e.where and e.where ~= "" and L("SRC_ZONE_IN", e.where) or L("SRC_ZONE")
end

-- ---------------------------------------------------------------------------
-- Fit for you

-- a guild ad or a sale ("WTS", carries), from chat or a custom Finder listing: "recruit" / "sale"
function Board.AdKind(e)
    if e.ad then return e.ad end
    if e.kind == "recruit" or e.kind == "sale" then return e.kind end
end

local function Fit(e)
    if Board.AdKind(e) then return "ad" end
    if e.kind == "player" then return "player" end
    if e.full then return "no", "full" end
    if e.finder then
        if G.Finder.IsDead(e.account) then return "no", "gone" end
        local join = e.join
        if join == GROUP_FINDER_ACTION_RESULT_FAILED_ENTITLEMENT_REQUIREMENT then return "no", "dlc" end
        if join == GROUP_FINDER_ACTION_RESULT_FAILED_CP_REQUIREMENT then return "no", "cp" end
        if join == GROUP_FINDER_ACTION_RESULT_FAILED_ROLE_REQUIREMENT then return "no", "role" end
        if join ~= nil and join ~= GROUP_FINDER_ACTION_RESULT_SUCCESS and not e.applied then return "no", "closed" end
    end
    if e.cp and G.MyCP() < e.cp then return "no", "cp" end
    if e.need then
        local role = G.MyRole()
        local open = (e.need[role] or 0) + (e.need.any or 0)
        if e.finder and e.free then open = math.min(open, e.free) end
        if open <= 0 then return "no", "role" end
        return "yes", nil, open
    end
    return "maybe"
end

local FIT_SCORE = { yes = 100, maybe = 60, player = 30, ad = 5, no = 0 }
local STALE_AFTER = 2700
Board.STALE_AFTER = STALE_AFTER

local function Score(e)
    local s = FIT_SCORE[e.fit] or 0
    if e.content and G.sv.watches[e.content] then s = s + 40 end
    local note = G.Note(e.account)
    if note and note.good then s = s + 15 end
    if e.finder then s = s + 5 end
    if e.chat and not e.finder then
        local minutes = (G.Now() - (e.lastSeen or G.Now())) / 60
        s = s - math.min(40, minutes * 2)
    end
    -- a listing nobody joined or left for 45 min is likely stuck (or forgotten by its leader)
    if e.changedAt and G.Now() - e.changedAt > STALE_AFTER then s = s - 15 end
    if e.startNow then s = s + 5 end
    if e.startAt then
        local inMin = (e.startAt - G.Now()) / 60
        if inMin <= 60 then s = s + 5 elseif inMin > 180 then s = s - 10 end
    end
    return s
end

-- ---------------------------------------------------------------------------
-- Filters (the window's chips)

local function KindOf(e)
    local k = e.kind
    if k == "trial" or k == "dungeon" or k == "arena" then return k end
    local ck = Content.Kind(e.content)
    if ck ~= "other" then return ck end
    return "other"
end
Board.KindOf = KindOf

local function Matches(e, q)
    if q == "" then return true end
    local function Has(s) return s and s ~= "" and zo_strlower(s):find(q, 1, true) ~= nil end
    return Has(Board.Title(e)) or Has(e.text) or Has(e.chatText) or Has(e.account) or Has(e.char)
        or Has(e.where) or Has(Board.Tag(e)) or (e.content and Has(Content.Name(e.content)))
end

-- a word from the "hide groups with these words" setting is in the group's texts
local function Blocked(e)
    return G.BlockedWord(Board.Title(e)) or G.BlockedWord(e.desc) or G.BlockedWord(e.text)
        or G.BlockedWord(e.chatText) or G.BlockedWord(e.playstyle)
end
Board.Blocked = Blocked

-- shown with the current filters (ignoreForMe: for the button's count; ignoreView: for the tree's
-- counts, every kind)
local function Passes(e, ignoreForMe, ignoreView)
    local sv = G.sv
    local note = G.Note(e.account)
    if note and note.hidden then return false end
    if e.blocked then return false end
    -- "only languages I read" (posts too short to tell always stay)
    if sv.langFilter and e.lang and not sv.langs[e.lang] then return false end
    if not ignoreView and sv.view ~= "all" and KindOf(e) ~= sv.view then return false end
    local srcOk = (e.finder and sv.sources.finder) or (e.chat and ((e.src == "zone" and sv.sources.zone) or (e.src == "guild" and sv.sources.guild)))
        or (e.chatSrc and ((e.chatSrc == "zone" and sv.sources.zone) or (e.chatSrc == "guild" and sv.sources.guild)))
    if not srcOk then return false end
    -- guild ads and sales: only with "Hide selling posts and guild ads" off (then labeled in the list)
    if Board.AdKind(e) then return not sv.hideSales end
    if e.kind == "player" and not sv.players then return false end
    if sv.teach and not (e.tags and e.tags.teach) then return false end
    if not ignoreForMe and sv.forMe and e.fit == "no" then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- Building the list

-- (only the sources you show are merged: with "Group Finder" unticked, a leader who also posted in
-- zone chat shows as that chat post, not as a Finder listing; user 2026-10-13)
local function Merge()
    local out, byAccount = {}, {}
    local sources = G.sv.sources
    if sources.finder then
        for _, e in ipairs(G.Finder.Entries()) do
            local copy = ZO_ShallowTableCopy(e)
            copy.tags = ZO_ShallowTableCopy(e.tags or {})
            out[#out + 1] = copy
            byAccount[G.AccountKey(e.account)] = copy
        end
    end
    for key, p in pairs(G.Chat.Posts()) do
        local shown = (p.src == "guild" and sources.guild) or (p.src ~= "guild" and sources.zone)
        local f = shown and byAccount[key]
        if not shown then
            -- this source is unticked: the post isn't used at all
        elseif f then
            -- the same leader in the Group Finder: keep one entry, add what chat says
            f.chatText, f.chatSrc, f.chatWhere, f.chatSeen = p.text, p.src, p.where, p.lastSeen
            f.chatRaw = p.raw
            f.lang = f.lang or p.lang
            f.content = f.content or p.content
            if f.vet == nil then f.vet = p.vet end
            f.hm = f.hm or p.hm
            f.startAt, f.startNow = f.startAt or p.startAt, f.startNow or p.startNow
            for tag in pairs(p.tags or {}) do f.tags[tag] = true end
        else
            local copy = ZO_ShallowTableCopy(p)
            copy.chat = true
            if copy.kind ~= "player" and copy.kind ~= "sale" and copy.kind ~= "recruit" then
                copy.kind = Content.Kind(copy.content)
            end
            out[#out + 1] = copy
        end
    end
    return out
end

local function AlertFor(e)
    if e.kind == "player" or e.fit == "no" or e.fit == "ad" or e.blocked then return false end
    if G.Quiet() then return false end
    local note = G.Note(e.account)
    if note and note.hidden then return false end
    if e.content and G.sv.watches[e.content] then return true end
    return G.sv.alertAll and e.fit == "yes" and Passes(e, true, true)
end

function Board.Rebuild()
    all = Merge()
    local now = G.Now()
    local alert
    -- "Applied" follows the game's live application (user 2026-10-14: it stuck after the leader
    -- declined / the application ran out). 10 s grace right after applying (the server answers late).
    local live = G.Finder.LiveApplication()
    for _, e in ipairs(all) do
        local key = G.AccountKey(e.account)
        local c = key and Board.contacts[key]
        local fresh = c and c.how == "applied" and now - c.t < 10
        if live ~= nil and not fresh then
            if e.finder then e.applied = (live ~= false and key == live) end
            if c and c.how == "applied" and key ~= live then Board.contacts[key] = nil end
        end
    end
    for _, e in ipairs(all) do
        e.blocked = Blocked(e) and true or false
        e.achs = G.Achieve.Find(e)
        e.fit, e.why, e.open = Fit(e)
        e.contact = Board.contacts[G.AccountKey(e.account)]
        e.score = Score(e)
        local seenKey = e.id .. ":" .. (e.content or "")
        if not seen[seenKey] then
            seen[seenKey] = true
            local fresh
            if e.finder then
                fresh = knownTasks[e.taskKey]
            else
                fresh = now - (e.firstSeen or now) <= 60
            end
            if fresh and not firstBuild and AlertFor(e) and (not alert or e.score > alert.score) then alert = e end
        end
    end
    for _, e in ipairs(all) do
        if e.finder then knownTasks[e.taskKey] = true end
    end
    firstBuild = false

    visible = {}
    local q = Board.query or ""
    for _, e in ipairs(all) do
        if Passes(e) and Matches(e, q) then visible[#visible + 1] = e end
    end
    table.sort(visible, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local ta, tb = a.lastSeen or 0, b.lastSeen or 0
        if ta ~= tb then return ta > tb end
        return a.id < b.id
    end)
    G.callbacks:FireCallbacks("BoardChanged")
    if alert and now - lastAlert >= 10 then
        lastAlert = now
        G.callbacks:FireCallbacks("Alert", alert)
    end
end

local pending = false
function Board.Changed()
    if pending then return end
    pending = true
    G.Later(function()
        pending = false
        Board.Rebuild()
    end, 150, "Board")
end

function Board.Visible()
    return visible
end

-- groups that fit you, any kind (the button's number)
function Board.ForMeCount()
    local n = 0
    for _, e in ipairs(all) do
        if e.fit == "yes" and Passes(e, true, true) then n = n + 1 end
    end
    return n
end

-- the best groups for you, any kind (the small board): up to n, best first
function Board.ForMeList(n)
    local list = {}
    for _, e in ipairs(all) do
        if (e.fit == "yes" or e.fit == "maybe") and Passes(e, true, true) then list[#list + 1] = e end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    while #list > n do table.remove(list) end
    return list
end

-- how many groups the list would show for one tree entry ("all", "trial"...)
function Board.Count(kind)
    local n = 0
    for _, e in ipairs(all) do
        if Passes(e, false, true) and (kind == "all" or KindOf(e) == kind) then n = n + 1 end
    end
    return n
end

-- a set of keyOf(e) for every entry (the "new" dot remembers which ones you saw)
function Board.Keys(keyOf)
    local keys = {}
    for _, e in ipairs(all) do keys[keyOf(e)] = true end
    return keys
end

-- the entry with this id (it may have been rebuilt since)
function Board.Find(id)
    if not id then return nil end
    for _, e in ipairs(all) do
        if e.id == id then return e end
    end
end

-- ---------------------------------------------------------------------------
-- Contacts

function Board.MarkContacted(e, how)
    if not e then return end
    local key = G.AccountKey(e.account)
    if not key then return end
    Board.contacts[key] = { t = G.Now(), how = how, content = e.content, vet = e.vet, hm = e.hm,
        title = Board.Title(e), account = e.account, finder = e.finder }
    Board.Changed()
end

-- the newest contact (applied / whispered) within maxAge seconds
function Board.LastContact(maxAge)
    local best
    for _, c in pairs(Board.contacts) do
        if G.Now() - c.t <= (maxAge or 1800) and (not best or c.t > best.t) then best = c end
    end
    return best
end

function Board.ContactCount()
    local n = 0
    for _ in pairs(Board.contacts) do n = n + 1 end
    return n
end

-- the message the leader sees when you apply / the whisper text: "+heal 1850 CP"
function Board.WhisperText(e)
    local role = G.MyRole()
    local word = role == "dps" and "dd" or role
    local text = "+" .. word
    local cp = G.MyCP()
    if cp > 0 then text = text .. " " .. cp .. " CP" end
    return text
end

function Board.ApplyMessage()
    return L("APPLY_MESSAGE", G.RoleName(G.MyRole()), G.MyCP())
end

function Board.Init()
    G.callbacks:RegisterCallback("PostsChanged", Board.Changed)
    G.callbacks:RegisterCallback("FinderChanged", Board.Changed)
    G.callbacks:RegisterCallback("SettingsChanged", Board.Changed)
    if EVENT_CHAMPION_POINT_GAINED then
        G.EM:RegisterForEvent("Groupbound_BoardCP", EVENT_CHAMPION_POINT_GAINED, Board.Changed)
    end
    -- ages and start times move on
    G.EM:RegisterForUpdate("Groupbound_BoardTick", 20000, Board.Rebuild)
    -- the role picked in the game's group menu (esoui groupfinder_searchresults_keyboard.lua)
    if PREFERRED_ROLES and PREFERRED_ROLES.RegisterCallback then
        PREFERRED_ROLES:RegisterCallback("LFGRoleChanged", G.Safe(function()
            Board.Changed()
            G.callbacks:FireCallbacks("RoleChanged")
        end, "Board"))
    end
end
