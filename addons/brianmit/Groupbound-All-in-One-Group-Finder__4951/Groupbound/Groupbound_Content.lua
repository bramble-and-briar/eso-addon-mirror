-- Groupbound_Content.lua : every trial, arena and dungeon with the nicknames players use in chat
-- (vSS, vDSR, hmAS, fg1, bc2...). Names on screen come from the game (GetZoneNameById), so they
-- are in the player's language; the English names are kept too because English posts show up on
-- every server. Dungeon zone ids are the ones LibUndauntedPledges uses (code65536); dungeons the
-- table doesn't know yet are added from the game's Activity Finder at start-up.
--
-- alias: a nickname. A "strict" alias is short or also a normal word (as, so, se, sg...): it
-- only counts with a difficulty in front (vAS, nSO, hmSE), or written in capitals in a post
-- that isn't all capitals ("LFM SG need heal"), or next to a difficulty word.

local G = Groupbound
local Content = {}
G.Content = Content

-- kind: "trial" | "arena" | "dungeon"; cat: which Group Finder category lists it
local TRIALS = {
    { key = "aa",  zone = 638,  en = "Aetherian Archive",    alias = { "aa" } },
    { key = "hrc", zone = 636,  en = "Hel Ra Citadel",       alias = { "hrc" } },
    { key = "so",  zone = 639,  en = "Sanctum Ophidia",      alias = {}, strict = { "so" } },
    { key = "mol", zone = 725,  en = "Maw of Lorkhaj",       alias = { "mol", "maw" } },
    { key = "hof", zone = 975,  en = "Halls of Fabrication", alias = { "hof" } },
    { key = "as",  zone = 1000, en = "Asylum Sanctorium",    alias = { "asylum" }, strict = { "as" } },
    { key = "cr",  zone = 1051, en = "Cloudrest",            alias = { "cr" } },
    { key = "ss",  zone = 1121, en = "Sunspire",             alias = { "ss" } },
    { key = "ka",  zone = 1196, en = "Kyne's Aegis",         alias = { "ka" } },
    { key = "rg",  zone = 1263, en = "Rockgrove",            alias = { "rg" } },
    { key = "dsr", zone = 1344, en = "Dreadsail Reef",       alias = { "dsr" } },
    { key = "se",  zone = 1427, en = "Sanity's Edge",        alias = {}, strict = { "se" } },
    { key = "lc",  zone = 1478, en = "Lucent Citadel",       alias = { "lc" } },
    -- zone id not known for sure: found by its English name on English clients
    { key = "oc",  en = "Ossein Cage",                       alias = { "oc" } },
}

local ARENAS = {
    { key = "ma",  zone = 677,  en = "Maelstrom Arena",      alias = { "msa" }, strict = { "ma" } },
    { key = "dsa", zone = 635,  en = "Dragonstar Arena",     alias = { "dsa" } },
    { key = "brp", zone = 1082, en = "Blackrose Prison",     alias = { "brp" } },
    { key = "vh",  zone = 1227, en = "Vateshran Hollows",    alias = { "vateshran" }, strict = { "vh" } },
    { key = "ia",  zone = 1436, en = "Infinite Archive",     alias = {}, strict = { "ia" }, endless = true },
}

-- [zoneId] = { en, aliases, strict aliases }
local DUNGEONS = {
    [283]  = { "Fungal Grotto I", { "fg1" } },
    [934]  = { "Fungal Grotto II", { "fg2" } },
    [144]  = { "Spindleclutch I", { "sc1", "spindle1" } },
    [936]  = { "Spindleclutch II", { "sc2", "spindle2" } },
    [380]  = { "The Banished Cells I", { "bc1" } },
    [935]  = { "The Banished Cells II", { "bc2" } },
    [63]   = { "Darkshade Caverns I", { "dc1", "dsc1" } },
    [930]  = { "Darkshade Caverns II", { "dc2", "dsc2" } },
    [126]  = { "Elden Hollow I", { "eh1" } },
    [931]  = { "Elden Hollow II", { "eh2" } },
    [146]  = { "Wayrest Sewers I", { "ws1", "wrs1" } },
    [933]  = { "Wayrest Sewers II", { "ws2", "wrs2" } },
    [176]  = { "City of Ash I", { "coa1" } },
    [681]  = { "City of Ash II", { "coa2" } },
    [130]  = { "Crypt of Hearts I", { "coh1" } },
    [932]  = { "Crypt of Hearts II", { "coh2" } },
    [131]  = { "Tempest Island", {}, { "toi", "ti" } },
    [38]   = { "Blackheart Haven", { "bhh" }, { "bh" } },
    [148]  = { "Arx Corinium", { "arx" } },
    [31]   = { "Selene's Web", { "selene", "selenes" }, { "sw" } },
    [22]   = { "Volenfell", { "vf" } },
    [64]   = { "Blessed Crucible", { "bcr", "crucible" } },
    [449]  = { "Direfrost Keep", { "dfk" }, { "dk" } },
    [11]   = { "Vaults of Madness", {}, { "vom" } },
    [678]  = { "Imperial City Prison", { "icp" } },
    [843]  = { "Ruins of Mazzatun", { "mazza" }, { "rom" } },
    [688]  = { "White-Gold Tower", { "wgt" } },
    [848]  = { "Cradle of Shadows", {}, { "cos" } },
    [973]  = { "Bloodroot Forge", { "brf" } },
    [974]  = { "Falkreath Hold", { "fkh" }, { "fh" } },
    [1009] = { "Fang Lair", {}, { "fl" } },
    [1010] = { "Scalecaller Peak", { "scp" }, { "sp" } },
    [1052] = { "Moon Hunter Keep", { "mhk" } },
    [1055] = { "March of Sacrifices", { "mos" } },
    [1081] = { "Depths of Malatar", {}, { "dom" } },
    [1080] = { "Frostvault", { "fv" } },
    [1122] = { "Moongrave Fane", { "mgf" } },
    [1123] = { "Lair of Maarselok", { "lom" } },
    [1152] = { "Icereach", {}, { "ir" } },
    [1153] = { "Unhallowed Grave", {}, { "ug" } },
    [1197] = { "Stone Garden", {}, { "sg" } },
    [1201] = { "Castle Thorn", {}, { "ct" } },
    [1228] = { "Black Drake Villa", { "bdv" } },
    [1229] = { "The Cauldron", { "cauldron" }, { "tc" } },
    [1267] = { "Red Petal Bastion", { "rpb" } },
    [1268] = { "The Dread Cellar", { "tdc" } },
    [1301] = { "Coral Aerie", {}, { "ca" } },
    [1302] = { "Shipwright's Regret", {}, { "sr" } },
    [1360] = { "Earthen Root Enclave", { "ere" } },
    [1361] = { "Graven Deep", {}, { "gd" } },
    [1389] = { "Bal Sunnar", {}, { "bs" } },
    [1390] = { "Scrivener's Hall", {}, { "sh" } },
    [1470] = { "Oathsworn Pit", {}, { "op" } },
    [1471] = { "Bedlam Veil", {}, { "bv" } },
    [1496] = { "Exiled Redoubt", {}, { "er" } },
    [1497] = { "Lep Seclusa", {}, { "ls" } },
    [1551] = { "Naj-Caldeesh", {}, { "nc" } },
    [1552] = { "Black Gem Foundry", { "bgf" } },
}

Content.byKey = {}       -- key -> entry
Content.alias = {}       -- alias -> { key, strict }
Content.names = {}       -- { { squashed name, key } } longest first
local byZone = {}

-- lowercase letters and digits only ("Kyne's Aegis" -> "kynesaegis"); bytes >= 128 (accents)
-- count as letters
function Content.Squash(text)
    if not text or text == "" then return "" end
    return (zo_strlower(text):gsub("[^%w\128-\255]", ""))
end
local Squash = Content.Squash

local function ZoneName(zoneId)
    if not zoneId then return nil end
    local ok, name = pcall(GetZoneNameById, zoneId)
    if not ok or not name or name == "" then return nil end
    return zo_strformat(SI_ZONE_NAME, name)
end

local function AddName(name, key)
    local s = Squash(name)
    if #s < 6 then return end
    Content.names[#Content.names + 1] = { s, key }
    -- "Fungal Grotto II" is often written "fungal grotto 2"
    local base, roman = s:match("^(.-)(i+)$")
    if base and #base >= 6 and (roman == "i" or roman == "ii") then
        Content.names[#Content.names + 1] = { base .. (roman == "i" and "1" or "2"), key }
    end
end

local function Add(e, kind)
    e.kind = kind
    Content.byKey[e.key] = e
    if e.zone then byZone[e.zone] = e end
    for _, a in ipairs(e.alias or {}) do
        if not Content.alias[a] then Content.alias[a] = { key = e.key } end
    end
    for _, a in ipairs(e.strict or {}) do
        if not Content.alias[a] then Content.alias[a] = { key = e.key, strict = true } end
    end
    AddName(e.en, e.key)
end

-- the zone id of a trial whose id isn't in the table (English clients only)
local function FindZoneByEnglishName(en)
    if GetCVar("Language.2") ~= "en" then return nil end
    local want = Squash(en)
    for zoneId = 1, 2000 do
        local ok, name = pcall(GetZoneNameById, zoneId)
        if ok and name and name ~= "" and Squash(zo_strformat(SI_ZONE_NAME, name)) == want then return zoneId end
    end
end

function Content.Init()
    for _, e in ipairs(TRIALS) do Add(e, "trial") end
    for _, e in ipairs(ARENAS) do Add(e, "arena") end
    for zoneId, d in pairs(DUNGEONS) do
        Add({ key = "d" .. zoneId, zone = zoneId, en = d[1], alias = d[2] or {}, strict = d[3] }, "dungeon")
    end
    -- dungeons the table doesn't know yet (new DLC), straight from the Activity Finder
    if LFG_ACTIVITY_DUNGEON and GetNumActivitiesByType and GetActivityIdByTypeAndIndex and GetActivityZoneId then
        local ok = pcall(function()
            for i = 1, GetNumActivitiesByType(LFG_ACTIVITY_DUNGEON) do
                local activityId = GetActivityIdByTypeAndIndex(LFG_ACTIVITY_DUNGEON, i)
                local zoneId = activityId and GetActivityZoneId(activityId)
                if zoneId and zoneId ~= 0 and not byZone[zoneId] then
                    Add({ key = "d" .. zoneId, zone = zoneId, en = ZoneName(zoneId) or "", alias = {} }, "dungeon")
                end
            end
        end)
        if not ok then G.ReportError("Content", "activity list", true) end
    end
    -- names in the player's language
    for key, e in pairs(Content.byKey) do
        local localName = ZoneName(e.zone)
        if localName then AddName(localName, key) end
    end
    table.sort(Content.names, function(a, b) return #a[1] > #b[1] end)
end

function Content.Get(key)
    return key and Content.byKey[key]
end

function Content.ZoneId(key)
    local e = Content.byKey[key]
    if not e then return nil end
    if not e.zone and not e.zoneTried then
        e.zoneTried = true
        e.zone = FindZoneByEnglishName(e.en)
    end
    return e.zone
end

-- the name on screen (the player's language when the game knows the zone)
function Content.Name(key)
    local e = Content.byKey[key]
    if not e then return "" end
    return ZoneName(e.zone) or e.en
end

function Content.Kind(key)
    local e = Content.byKey[key]
    return e and e.kind or "other"
end

-- first letters of the words ("Bal Sunnar" -> "bs"), for content without a short nickname
local function Initials(name)
    local out = ""
    for word in (name or ""):gmatch("[%w\128-\255]+") do
        local lower = zo_strlower(word)
        if lower ~= "the" and lower ~= "of" then out = out .. lower:sub(1, 1) end
    end
    return out ~= "" and out or "?"
end

-- the short tag shown in the list: "vSS", "nFG1", "BRP"
function Content.Short(key, vet)
    local e = Content.byKey[key]
    if not e then return "" end
    -- trials and arenas: the key is the nickname everyone uses (ss, dsr, ma, brp)
    local nick = e.kind ~= "dungeon" and #e.key <= 4 and e.key or nil
    for _, a in ipairs(nick and {} or e.alias or {}) do
        if #a <= 4 then nick = a break end
    end
    if not nick then
        for _, a in ipairs(e.strict or {}) do
            if #a <= 4 then nick = a break end
        end
    end
    nick = nick or Initials(e.en ~= "" and e.en or Content.Name(key))
    if #nick > 4 then nick = nick:sub(1, 4) end
    local prefix = ""
    if vet == true then prefix = "v" elseif vet == false then prefix = "n" end
    return prefix .. zo_strupper(nick)
end

-- which Group Finder category lists this content
function Content.Category(key)
    local e = Content.byKey[key]
    if not e then return nil end
    if e.endless then return GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON end
    if e.kind == "trial" then return GROUP_FINDER_CATEGORY_TRIAL end
    if e.kind == "arena" then return GROUP_FINDER_CATEGORY_ARENA end
    if e.kind == "dungeon" then return GROUP_FINDER_CATEGORY_DUNGEON end
end

-- content named somewhere inside a text (a Group Finder option name or a post); longest name wins
function Content.FromName(text)
    local s = Squash(text)
    if s == "" then return nil end
    for _, n in ipairs(Content.names) do
        if n[1] == s then return n[2] end
    end
    for _, n in ipairs(Content.names) do
        if s:find(n[1], 1, true) then return n[2] end
    end
end

-- every content of one kind, sorted by name (for the post form's quick picks)
function Content.List(kind)
    local list = {}
    for key, e in pairs(Content.byKey) do
        if e.kind == kind then list[#list + 1] = key end
    end
    table.sort(list, function(a, b) return Content.Name(a) < Content.Name(b) end)
    return list
end
