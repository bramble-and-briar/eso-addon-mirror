-- Lethal PVP Insights - gear & skill bars imported from the ESO encounter log
-- Addons can't read files, so LPI_Import.py turns Logs/Encounter.log into
-- LPI_Imported.lua, which the game loads with the addon on /reloadui.
local PDI = PVPDataInsight
local Import = {}
PDI.Import = Import

Import.builds = {}
Import.anon = {}

---------------------------------------------------------------------------
-- Formatting helpers
---------------------------------------------------------------------------
local function titleCase(s)
    s = string.lower(s or ""):gsub("_", " ")
    return (s:gsub("(%a)([%w']*)", function(a, b) return string.upper(a) .. b end))
end

local function traitText(t)
    if not t or t == "" or t == "NONE" or t == "INVALID" then return "" end
    t = t:gsub("^ARMOR_", ""):gsub("^WEAPON_", ""):gsub("^JEWELRY_", "")
    return titleCase(t)
end

local ENCHANT_SHORT = {
    INCREASE_SPELL_DAMAGE = "Spell Damage", INCREASE_PHYSICAL_DAMAGE = "Weapon Damage", PRISMATIC_DEFENSE = "Prismatic",
    PRISMATIC_ONSLAUGHT = "Prismatic", ABSORB_HEALTH = "Absorb Health", ABSORB_STAMINA = "Absorb Stamina",
    ABSORB_MAGICKA = "Absorb Magicka", MAGICKA_REGEN = "Magicka Regen", STAMINA_REGEN = "Stamina Regen",
    HEALTH_REGEN = "Health Regen", INCREASE_BASH_DAMAGE = "Bash Damage", REDUCE_SPELL_COST = "Spell Cost",
    REDUCE_FEAT_COST = "Stamina Cost", REDUCE_POTION_COOLDOWN = "Potion Speed",
}
local function enchantText(e)
    if not e or e == "" or e == "INVALID" or e == "NONE" then return "" end
    return ENCHANT_SHORT[e] or titleCase((e:gsub("_WEAPON$", "")))
end

local SLOT_LABEL = {
    HEAD = "Head", NECK = "Neck", CHEST = "Chest", SHOULDERS = "Shoulders", MAIN_HAND = "Main hand",
    OFF_HAND = "Off hand", WAIST = "Waist", LEGS = "Legs", FEET = "Feet", RING1 = "Ring 1", RING2 = "Ring 2",
    HAND = "Hands", BACKUP_MAIN = "Back main hand", BACKUP_OFF = "Back off hand", COSTUME = "Costume",
}
local SLOT_ORDER = { "MAIN_HAND", "OFF_HAND", "BACKUP_MAIN", "BACKUP_OFF", "HEAD", "SHOULDERS", "CHEST",
                     "HAND", "WAIST", "LEGS", "FEET", "NECK", "RING1", "RING2", "COSTUME" }
local SLOT_RANK = {}
for i, s in ipairs(SLOT_ORDER) do SLOT_RANK[s] = i end

function Import.ItemLink(itemId)
    return string.format("|H1:item:%d:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId or 0)
end

-- What the item is: the weapon type ("Inferno Staff", "Dagger") or the armour weight and piece ("Heavy Chest")
function Import.ItemType(itemId)
    if not itemId or itemId == 0 then return nil end
    local link = Import.ItemLink(itemId)
    local wt = GetItemLinkWeaponType and GetItemLinkWeaponType(link) or 0
    if wt and wt ~= 0 and wt ~= WEAPONTYPE_NONE then
        local n = GetString("SI_WEAPONTYPE", wt)
        if n and n ~= "" then return zo_strformat("<<1>>", n) end
    end
    local et = GetItemLinkEquipType and GetItemLinkEquipType(link) or 0
    local piece = (et and et ~= 0) and GetString("SI_EQUIPTYPE", et) or ""
    piece = piece ~= "" and zo_strformat("<<1>>", piece) or ""
    local at = GetItemLinkArmorType and GetItemLinkArmorType(link) or 0
    if at and at ~= 0 and at ~= ARMORTYPE_NONE then
        local w = GetString("SI_ARMORTYPE", at)
        if w and w ~= "" then return zo_strformat("<<1>>", w) .. (piece ~= "" and (" " .. piece) or "") end
    end
    return piece ~= "" and piece or nil
end

local function setName(setId, link)
    if not setId or setId == 0 then return nil end
    if GetItemSetName then
        local n = GetItemSetName(setId)
        if n and n ~= "" then return zo_strformat("<<1>>", n) end
    end
    if GetItemLinkSetInfo then
        local hasSet, n = GetItemLinkSetInfo(link, false)
        if hasSet and n and n ~= "" then return zo_strformat("<<1>>", n) end
    end
    return "Set #" .. setId
end

local function abilityName(id, names)
    if not id or id == 0 then return "-" end
    local n = GetAbilityName(id)
    if (not n or n == "") and names then n = names[id] end
    return (n and n ~= "") and zo_strformat("<<1>>", n) or ("Ability #" .. id)
end

local function isTwoHanded(link)
    return GetItemLinkEquipType and EQUIP_TYPE_TWO_HAND and GetItemLinkEquipType(link) == EQUIP_TYPE_TWO_HAND
end

function Import.RaceText(raceId)
    if not raceId or raceId == 0 then return nil end
    local n = GetRaceName and GetRaceName(GENDER_MALE, raceId)
    return (n and n ~= "") and zo_strformat("<<1>>", n) or nil
end

---------------------------------------------------------------------------
-- Data access
---------------------------------------------------------------------------
-- Snapshot = { char, cls, race, cp, level, reaction, names, v = variant, idx, count }
function Import:Snapshot(acct, idx)
    local b = acct and self.builds[acct]
    if not b or not b.variants or #b.variants == 0 then return nil end
    idx = zo_clamp(idx or 1, 1, #b.variants)
    return {
        char = b.char, cls = b.cls, race = b.race, cp = b.cp, level = b.level, reaction = b.reaction,
        names = b.names, v = b.variants[idx], idx = idx, count = #b.variants,
    }
end

function Import:Has(acct) return acct ~= nil and self.builds[acct] ~= nil end

function Import:Mundus(snap)
    local list = {}
    for _, id in ipairs(snap and snap.v and snap.v.effects or {}) do
        if PDI.MUNDUS_IDS[id] then list[#list + 1] = PDI.MUNDUS_IDS[id] end
    end
    return #list > 0 and table.concat(list, ", ") or nil
end

-- Rows for the "Gear & Bars" page: sets summary, front bar, back bar, each gear slot
local QUALITY_COLOR = {
    LEGENDARY = "FFD700", ARTIFACT = "A02EF7", ARCANE = "3A92FF", MAGIC = "2DC50E", NORMAL = "FFFFFF", TRASH = "C3C3C3",
}

-- Skill bars: front (slots 1-5 + ultimate) then back
function Import:BarRows(snap)
    local rows = {}
    if not snap or not snap.v then return rows end
    local function bar(list, label)
        for i, id in ipairs(list or {}) do
            rows[#rows + 1] = { sec = label, n = abilityName(id, snap.names),
                                info = (i == 6 and #list == 6) and "Ultimate" or ("Slot " .. i),
                                tooltipId = (id and id > 0) and id or nil }
        end
    end
    bar(snap.v.bar1, "|c66CCFFFront|r")
    bar(snap.v.bar2, "|cCC99FFBack|r")
    return rows
end

-- Sets summary, then each item (name coloured by quality)
function Import:GearRows(snap)
    local rows = {}
    if not snap or not snap.v then return rows end
    local v = snap.v
    local sets, order = {}, {}
    for _, g in ipairs(v.gear or {}) do
        if g.set and g.set > 0 and g.slot ~= "COSTUME" then
            local s = sets[g.set]
            if not s then
                s = { id = g.set, front = 0, back = 0, link = Import.ItemLink(g.item), traits = {} }
                sets[g.set] = s
                order[#order + 1] = s
            end
            local pieces = isTwoHanded(Import.ItemLink(g.item)) and 2 or 1
            if g.slot:find("^BACKUP") then s.back = s.back + pieces else s.front = s.front + pieces end
            local t = traitText(g.trait)
            if t ~= "" then s.traits[t] = (s.traits[t] or 0) + 1 end
        end
    end
    table.sort(order, function(a, b) return (a.front + a.back) > (b.front + b.back) end)
    for _, s in ipairs(order) do
        -- the traits on the set's pieces, most used first: "Divines 4, Infused 1"
        local tl = {}
        for t, n in pairs(s.traits) do tl[#tl + 1] = { t = t, n = n } end
        table.sort(tl, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.t < b.t end)
        local parts = {}
        for _, x in ipairs(tl) do parts[#parts + 1] = string.format("%s %d", x.t, x.n) end
        rows[#rows + 1] = { sec = "|cC5C29ESet|r", n = setName(s.id, s.link),
                            trait = "|cC5C29E" .. table.concat(parts, ", ") .. "|r",
                            ench = string.format("%d pc", s.front) .. (s.back > 0 and string.format(" +%d back", s.back) or ""),
                            lvl = "", item = "", tooltipLink = s.link }
    end

    local gear = {}
    for _, g in ipairs(v.gear or {}) do gear[#gear + 1] = g end
    table.sort(gear, function(a, b) return (SLOT_RANK[a.slot] or 99) < (SLOT_RANK[b.slot] or 99) end)
    for _, g in ipairs(gear) do
        local link = Import.ItemLink(g.item)
        local name = setName(g.set, link)
        if not name then
            local itemName = GetItemLinkName and GetItemLinkName(link)
            name = (itemName and itemName ~= "") and zo_strformat("<<t:1>>", itemName) or ("Item #" .. g.item)
        end
        local color = QUALITY_COLOR[g.q] or "FFFFFF"
        rows[#rows + 1] = {
            sec = SLOT_LABEL[g.slot] or titleCase(g.slot), n = "|c" .. color .. name .. "|r",
            item = g.it or Import.ItemType(g.item) or "",
            trait = traitText(g.trait), ench = enchantText(g.ench),
            lvl = g.cp and ("CP" .. (g.lvl or 0) * 10) or ("Lv" .. (g.lvl or 0)),
            tooltipLink = link,
        }
    end
    return rows
end

function Import:Capture(arg) PDI.LogAssist:Capture(arg) end

---------------------------------------------------------------------------
-- Anonymous log entries ("#anon:class:race:cp") belong to group members who chose to appear anonymous
-- in encounter logs. Match them by class + race + champion points, first against your current group,
-- then against group history.
local function norm(x) return x and string.lower(zo_strformat("<<1>>", x)) or nil end

-- 0 = same race, 1 = unknown, 2 = different
local function raceScore(raceIdOrName, raceId)
    if raceIdOrName == nil then return 1 end
    if type(raceIdOrName) == "number" then return raceIdOrName == raceId and 0 or 2 end
    local want = norm(Import.RaceText(raceId))
    if not want or want == "" then return 1 end
    return norm(raceIdOrName) == want and 0 or 2
end

local CP_TOLERANCE = 60

-- Candidates must have the same class; then closest CP wins, race breaks ties / penalises.
function Import:MatchAnon(b)
    local function score(cls, race, cp)
        if cls ~= b.cls then return nil end
        local diff = math.abs((cp or 0) - (b.cp or 0))
        if (cp or 0) > 0 and diff > CP_TOLERANCE then return nil end
        return raceScore(race, b.race) * 100 + diff
    end
    -- 1) live group roster
    if IsUnitGrouped and IsUnitGrouped("player") then
        local best, bestScore
        for i = 1, GetGroupSize() do
            local tag = GetGroupUnitTagByIndex(i)
            if tag and DoesUnitExist(tag) and not AreUnitsEqual(tag, "player") then
                local race = (GetUnitRaceId and GetUnitRaceId(tag)) or GetUnitRace(tag)
                local sc = score(GetUnitClassId(tag), race, GetUnitChampionPoints(tag))
                local acct = PDI.NormalizeAccount(GetUnitDisplayName(tag))
                if sc and acct and not self.claimed[acct] and (not bestScore or sc < bestScore) then
                    best, bestScore = { acct = acct, char = PDI.CleanName(GetUnitName(tag)) }, sc
                end
            end
        end
        if best and bestScore < 200 then return best.acct, best.char end
    end
    -- 2) group history
    local best, bestScore, bestLast
    for acct, e in pairs(PDI.sv.group) do
        if not self.claimed[acct] then
            local sc = score(e.cls, e.raceId or e.race, e.cp)
            if sc and sc < 200 and (not bestScore or sc < bestScore or (sc == bestScore and (e.last or 0) > (bestLast or 0))) then
                best, bestScore, bestLast = acct, sc, e.last
            end
        end
    end
    if best then return best, PDI.sv.group[best].char end
    return nil
end

-- Try to give unmatched anonymous builds an owner. Safe to call repeatedly (e.g. on group changes).
function Import:ResolveAnon()
    local resolved = 0
    for i = #self.anon, 1, -1 do
        local b = self.anon[i]
        local acct, char = self:MatchAnon(b)
        if acct then
            local cur = self.builds[acct]
            if not cur or (cur.last or 0) <= (b.last or 0) then
                b.char = char or b.char
                b.matchedAnon = true
                self.builds[acct] = b
                local e = PDI.Group:EnsureEntry(acct, b.char, b.last)
                if (e.cls or 0) == 0 then e.cls = b.cls end
                if not e.race then e.race = Import.RaceText(b.race) end
                if (e.cp or 0) == 0 then e.cp = b.cp end
            end
            self.claimed[acct] = true
            table.remove(self.anon, i)
            self:Persist(acct)
            resolved = resolved + 1
        end
    end
    return resolved
end

-- /pvpdi importcheck: what was imported and how anonymous players were matched
function Import:PrintDiagnostics()
    local n = 0
    for acct, b in pairs(self.builds) do
        n = n + 1
        PDI.Msg(string.format("  %s%s  class %s, CP %s, %d build(s)", acct, b.matchedAnon and " |c66CCFF(matched anonymous)|r" or "",
            tostring(b.cls), tostring(b.cp), #(b.variants or {})))
    end
    for _, b in ipairs(self.anon) do
        PDI.Msg(string.format("  |cFF8866unmatched anonymous|r class %s, race %s (%s), CP %s", tostring(b.cls),
            tostring(b.race), tostring(Import.RaceText(b.race)), tostring(b.cp)))
    end
    PDI.Msg(string.format("Import file from %s: %d player(s), %d unmatched anonymous.",
        self.generated > 0 and PDI.FormatTime(self.generated) or "never", n, #self.anon))
end

---------------------------------------------------------------------------
-- Keeping imported builds in SavedVariables
---------------------------------------------------------------------------
-- The import file only holds what the Companion currently has. A copy of every imported build is kept
-- in the addon's saved data for at least STORE_DAYS after it was captured, so Skills and Gear & Sets
-- stay in the Group tab even when Encounter.log is deleted, the Companion's cache is reset, or the
-- import file is replaced. An anonymous player's build is stored under the @account it was matched to.
local STORE_DAYS = 7

local function mergeVariants(a, b)
    local out, seen = {}, {}
    for _, list in ipairs({ a or {}, b or {} }) do
        for _, v in ipairs(list) do
            local key = v.hash or tostring(v.seen)
            if not seen[key] then seen[key] = true; out[#out + 1] = v end
        end
    end
    table.sort(out, function(x, y) return (x.seen or 0) > (y.seen or 0) end)
    while #out > 5 do table.remove(out) end
    return out
end

function Import:Persist(acct)
    local b = acct and self.builds[acct]
    if not b then return end
    PDI.sv.importedBuilds = PDI.sv.importedBuilds or {}
    local store = PDI.sv.importedBuilds
    local old = store[acct]
    if old and old.build ~= b then b.variants = mergeVariants(b.variants, old.build.variants) end
    store[acct] = { build = b, storedAt = old and old.storedAt or PDI.Now() }
end

-- Bring stored builds back (when missing from the file, or adding variants the file no longer has)
-- and drop stored copies older than STORE_DAYS.
function Import:RestoreStored()
    local store = PDI.sv.importedBuilds or {}
    PDI.sv.importedBuilds = store
    local cutoff = PDI.Now() - STORE_DAYS * 86400
    local restored = 0
    for acct, e in pairs(store) do
        local b = e.build
        if not b or ((b.last and b.last > 0) and b.last or (e.storedAt or 0)) < cutoff then
            store[acct] = nil
        else
            local cur = self.builds[acct]
            if not cur then
                self.builds[acct] = b
                restored = restored + 1
            elseif cur ~= b then
                cur.variants = mergeVariants(cur.variants, b.variants)
                if (b.last or 0) > (cur.last or 0) then cur.last = b.last end
            end
        end
    end
    return restored
end

-- Drop imported builds captured before a "Clear Group History"
-- Forget one player's imported gear (Remove in the Group tab)
function Import:Forget(acct)
    self.builds[acct] = nil
    if PDI.sv.importedBuilds then PDI.sv.importedBuilds[acct] = nil end
end

function Import:ForgetBefore(ts)
    for acct, b in pairs(self.builds) do
        if (b.last or 0) <= ts then self.builds[acct] = nil end
    end
    for acct, e in pairs(PDI.sv.importedBuilds or {}) do
        if not e.build or (e.build.last or 0) <= ts then PDI.sv.importedBuilds[acct] = nil end
    end
    local anon = self.anon or {}     -- can run before Import:Init (data reset at UI load)
    for i = #anon, 1, -1 do
        if (anon[i].last or 0) <= ts then table.remove(anon, i) end
    end
end

function Import:Init()
    local data = PVPDataInsight_Imported
    self.builds = (data and data.builds) or {}
    self.generated = (data and data.generated) or 0
    self.anon = {}
    self.claimed = {}
    local clearedAt = PDI.sv.settings.groupClearedAt
    if clearedAt then self:ForgetBefore(clearedAt) end

    local n, added = 0, 0
    for key, b in pairs(self.builds) do
        if b.anon or key:sub(1, 6) == "#anon:" then
            self.builds[key] = nil
            self.anon[#self.anon + 1] = b
        end
    end
    self.restored = self:RestoreStored()
    -- an anonymous build already matched (and stored) earlier must not be matched to someone else
    local known = {}
    for _, b in pairs(self.builds) do
        for _, v in ipairs(b.variants or {}) do if v.hash then known[v.hash] = true end end
    end
    for i = #self.anon, 1, -1 do
        local all = #(self.anon[i].variants or {}) > 0
        for _, v in ipairs(self.anon[i].variants or {}) do if not (v.hash and known[v.hash]) then all = false end end
        if all then table.remove(self.anon, i) end
    end
    if clearedAt then self:ForgetBefore(clearedAt) end
    -- players removed from the Group tab: drop gear captured before the removal
    for acct, ts in pairs(PDI.sv.groupRemoved or {}) do
        local b = self.builds[acct]
        if b and (b.last or 0) <= ts then
            self.builds[acct] = nil
            self.claimed[acct] = true      -- don't hand their anonymous build to someone else either
        end
    end
    for acct, b in pairs(self.builds) do
        n = n + 1
        self.claimed[acct] = true
        b.char = PDI.CleanName(b.char)
        if b.char then PDI.Data:LearnName(b.char, acct, nil) end
        if b.grouped then
            local e, isNew = PDI.Group:EnsureEntry(acct, b.char, b.last)
            if isNew then added = added + 1 end
            if (e.cls or 0) == 0 and b.cls then e.cls = b.cls end
            if not e.race then e.race = Import.RaceText(b.race) end
            if (e.cp or 0) == 0 and b.cp then e.cp = b.cp end
            if not e.level and b.level then e.level = b.level end
        end
    end
    for acct in pairs(self.builds) do self:Persist(acct) end
    n = n + self:ResolveAnon()
    -- the group roster isn't always known yet at load time: retry once the player is in the world
    local function retry()
        if #Import.anon == 0 then return end
        local r = Import:ResolveAnon()
        if r > 0 then
            PDI.Msg(string.format("Matched gear for %d anonymous group member(s).", r))
            if PDI.UI then PDI.UI:RefreshIfVisible() end
        end
    end
    EVENT_MANAGER:RegisterForEvent(PDI.name .. "_ImportAnon", EVENT_PLAYER_ACTIVATED, function() zo_callLater(retry, 2000) end)
    EVENT_MANAGER:RegisterForEvent(PDI.name .. "_ImportAnonGroup", EVENT_GROUP_UPDATE, function() zo_callLater(retry, 1500) end)
    EVENT_MANAGER:RegisterForEvent(PDI.name .. "_ImportAnonJoin", EVENT_GROUP_MEMBER_JOINED, function() zo_callLater(retry, 1500) end)

    PDI.Group:EnforceCap()

    -- did an in-game Upload actually reach the Companion?
    local asked = PDI.sv.settings.uploadRequestedAt
    if asked then
        PDI.sv.settings.uploadRequestedAt = nil
        if self.generated < asked - 5 then
            zo_callLater(function()
                PDI.Msg("|cFF8866Upload didn't reach the LPI Companion|r - it isn't running. Double-click " ..
                    "|cFFFFFFLPI COMPANION.bat|r (or the LPI Companion desktop shortcut) once (it then starts with Windows), " ..
                    "then click Upload again.")
            end, 3000)
        end
    end

    if n > 0 and PDI.sv.settings.lastImport ~= self.generated then
        PDI.sv.settings.lastImport = self.generated
        PDI.Msg(string.format("Loaded gear & skill bars for %d players from the encounter log (%s)%s.",
            n, PDI.FormatTime(self.generated), added > 0 and string.format(", %d added to group history", added) or ""))
        if #self.anon > 0 then
            PDI.Msg(string.format("%d captured player(s) appear anonymous in the encounter log - they'll be matched " ..
                "by class, race and CP when you're grouped with them.", #self.anon))
        end
    end
end
