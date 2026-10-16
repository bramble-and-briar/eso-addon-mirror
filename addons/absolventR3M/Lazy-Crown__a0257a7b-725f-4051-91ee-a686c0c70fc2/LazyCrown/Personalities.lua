-- Lazy Crown personalities. Each one looks at a snapshot of Cyrodiil (built
-- by LazyCrown.lua at pick time, see BuildWorld there) and returns what to call:
--   { pick = option, chain = { option, ... },  -- optional legs after the first
--     extras = { "line", ... },               -- said right after the call
--     tail = { "line", ... } }                -- said at the very end
-- or nil to let the plain Lazy pick decide. Options are the same list the
-- Lazy pick uses: targets we don't hold, plus our keeps and outposts under
-- attack (option.defend = true).

LazyCrown = LazyCrown or {}
local P = {}
LazyCrown.Personalities = P

local AD, EP, DC = ALLIANCE_ALDMERI_DOMINION or 1, ALLIANCE_EBONHEART_PACT or 2, ALLIANCE_DAGGERFALL_COVENANT or 3

-- Map facts the game doesn't expose -------------------------------------------

-- Each alliance's two scroll gates. A gate opens only when the owner has lost
-- both its hub keep and its side keep. The hub (Faregyl, Arrius, Glademist)
-- locks both gates, so it matters more than either side keep.
local SCROLLS = {
    [AD] = { { temple = 118, hub = 16, side = 19 }, { temple = 119, hub = 16, side = 20 } }, -- Altadoon (Black Boot), Mnem (Bloodmayne)
    [EP] = { { temple = 120, hub = 10, side = 12 }, { temple = 121, hub = 10, side = 11 } }, -- Ghartok (Farragut), Chim (Kingscrest)
    [DC] = { { temple = 122, hub = 5, side = 3 }, { temple = 123, hub = 5, side = 4 } },    -- Ni-Mohk (Warden), Alma Ruma (Rayles)
}
local HUBS = { [16] = true, [10] = true, [5] = true }

-- Scroll colors. Taking an enemy scroll off its temple needs our own scroll of
-- the same color at home; one that's sitting in a keep is ours by taking the keep.
local COLOR = {
    [118] = "orange", [120] = "orange", [122] = "orange", -- Altadoon, Ghartok, Ni-Mohk
    [119] = "purple", [121] = "purple", [123] = "purple", -- Mnem, Chim, Alma Ruma
}

-- Native keeps of each alliance (home keeps).
local HOME = {
    [AD] = { [15] = true, [16] = true, [17] = true, [18] = true, [19] = true, [20] = true },
    [EP] = { [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true },
    [DC] = { [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
}

-- Emperor keeps if the game can't list them.
local EMPEROR_KEEPS = { 6, 7, 9, 13, 15, 17 }

-- The wings: edge keep, town and outpost on each flank.
local WINGS = {
    north = { keep = 8, town = 151, outpost = 163 },  -- Dragonclaw, Bruma, Winter's Peak
    west = { keep = 18, town = 149, outpost = 164 },  -- Brindle, Vlastarus, Carmala
    east = { keep = 14, town = 152, outpost = 165 },  -- Drakelowe, Cropsford, Harlun's
}
local DRAKELOWE = 14

-- One grudge keep per alliance: Deano's when an enemy has the emperor, and
-- November's when that alliance is behind a long losing streak.
local GRUDGE_KEEPS = { [DC] = 3, [EP] = 11, [AD] = 19 } -- Warden, Kingscrest, Black Boot

local ALLIANCE_SHORT = { [AD] = "Dominion", [EP] = "Pact", [DC] = "Covenant" }

-- Troll calls: a keep and how to hit it (November, Deano and Diil). Each one
-- only comes up while that keep belongs to an enemy. The siege spots (spot) are
-- Chris's too.
local TROLL_CALLS = {
    { keepId = 6, directive = "troll Ash by sieging from the lumbermill tower" },
    { keepId = 11, directive = "troll Kingscrest by sieging from the lumbermill" },
    { keepId = 3, directive = "troll Warden by sieging from the mine and mine tower" },
    { keepId = 8, directive = "be annoying and take Dragonclaw from the lumbermill tower" },
    { keepId = 16, directive = "troll Faregyl by sieging from the back wall", spot = true },
    { keepId = 16, directive = "troll Faregyl by sieging from the lumbermill", spot = true },
    { keepId = 15, directive = "be annoying and take Alessia from the farm", spot = true },
    { keepId = 17, directive = "troll Roebeck by sieging from the lumbermill", spot = true },
    { keepId = 18, directive = "be annoying and take Brindle from the lumbermill", spot = true },
    { keepId = 7, directive = "troll Aleswell by sieging from the back hill", spot = true },
    { keepId = 5, directive = "troll Glademist by sieging from the mine", spot = true },
    { keepId = 9, directive = "be annoying and take Chalman from the back hill", spot = true },
    { keepId = 13, directive = "be annoying and take Blue Road Keep from the mine side", spot = true },
    { keepId = 13, directive = "troll Blue Road Keep by sieging from the back wall", spot = true },
    { keepId = 10, directive = "troll Arrius by sieging from the mine", spot = true },
}

-- Each keep's back flag (the Apse), by objective ID, for clients where the flag
-- names aren't in English.
local BACK_FLAG = { [3] = 56, [4] = 75, [5] = 70, [6] = 177, [7] = 173, [8] = 169, [9] = 179, [10] = 65, [11] = 77,
    [12] = 51, [13] = 176, [14] = 171, [15] = 167, [16] = 60, [17] = 165, [18] = 163, [19] = 49, [20] = 40 }

-- Continuous Attack: the timed buff after capturing a resource or keep, and the passive itself.
local CA_BUFFS = { [39249] = true, [45617] = true }
local CA_PASSIVE = 39248

-- Tuning ---------------------------------------------------------------------
-- Distances are fractions of the Cyrodiil map. 0.01 is about 100 m and about
-- 5.4 seconds at full sprint (Vlastarus to Brindle, 0.122, took 66 s in game).
local CLOSE = 0.06          -- about 600 m, 32 seconds
local NEAR = 0.12           -- about 1.2 km, 65 seconds
local AREA = 0.2            -- the part of the map you're in: about 110 seconds away, transitus included
local SIEGE_SPOT_STREAK = 10 -- L's in a row before Chris tries the siege spots
local OTHER_SIDE = 0.35     -- "the other side of the map"
local FIGHT_RADIUS = 0.025  -- battle markers this close count for a target
local LOST_CAUSE = 20       -- enemy battle victories that make a fight a lost cause
local CA_LOW = 180          -- seconds of Continuous Attack left that count as "needs a refresh"
local RECENT_FLIP = 15 * 60 -- a keep that changed hands this recently still has weak walls

-- Helpers ----------------------------------------------------------------------

local function Dist(a, b)
    if not (a and b and a.x and b.x) then return nil end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Calls a game function; nothing (instead of an error) if it fails or is missing.
local function Results(ok, ...)
    if ok then return ... end
end

local function Safe(fn, ...)
    if not fn then return nil end
    return Results(pcall(fn, ...))
end

-- How far a target is from you, as travel time in map units (counting transitus
-- and recall stones when LazyCrown.lua knows them), or nil.
local function Away(w, t)
    if w.Away then return w.Away(t) end
    return w.player and Dist(w.player, t)
end

-- Picks one of the best few, the best ones more often.
local function TopPick(w, list, scoreOf, n)
    local scored = {}
    for _, item in ipairs(list) do
        local score = scoreOf(item)
        if score and score > -1e8 then table.insert(scored, { item = item, score = score }) end
    end
    if #scored == 0 then return nil end
    table.sort(scored, function(a, b) return a.score > b.score end)
    n = math.min(n or 3, #scored)
    local total = n * (n + 1) / 2
    local roll = w.Random(1, total)
    for i = 1, n do
        roll = roll - (n - i + 1)
        if roll <= 0 then return scored[i].item end
    end
    return scored[1].item
end

local function Filter(list, keep)
    local out = {}
    for _, item in ipairs(list) do if keep(item) then table.insert(out, item) end end
    return out
end

local function Nearest(from, list, maxDist)
    local best, bestD
    for _, item in ipairs(list) do
        local d = Dist(from, item)
        if d and (not maxDist or d <= maxDist) and (not bestD or d < bestD) then best, bestD = item, d end
    end
    return best, bestD
end

-- Snapshot pieces, computed on first use and cached on the world table.

local function Fights(w)
    if w._fights then return w._fights end
    local fights = {}
    local n = Safe(GetNumKillLocations) or 0
    for i = 1, n do
        local pinType, x, y = Safe(GetKillLocationPinInfo, i)
        if x and y and (x ~= 0 or y ~= 0) and pinType ~= MAP_PIN_TYPE_INVALID then
            local f = { x = x, y = y, kills = {} }
            for _, a in ipairs({ AD, EP, DC }) do f.kills[a] = Safe(GetNumKillLocationAllianceKills, i, a) or 0 end
            table.insert(fights, f)
        end
    end
    w._fights = fights
    return fights
end

-- Battle victories near a target, added up over every marker in range: ours,
-- and the most any one enemy alliance has.
local function FightAt(w, t)
    local by = {}
    for _, f in ipairs(Fights(w)) do
        local d = Dist(t, f)
        if d and d <= FIGHT_RADIUS then
            for a, k in pairs(f.kills) do by[a] = (by[a] or 0) + k end
        end
    end
    local theirs = 0
    for a, k in pairs(by) do if a ~= w.mine then theirs = math.max(theirs, k) end end
    return by[w.mine] or 0, theirs
end

-- "Getting farmed": lots of enemy victories and few of ours.
local function LostCause(w, t)
    local ours, theirs = FightAt(w, t)
    return theirs >= LOST_CAUSE and theirs > ours * 2, ours, theirs
end

-- Flags of each keep/outpost/town: total, how many are off full control, how
-- many an enemy (not the owner) holds.
local function Flags(w)
    if w._flags then return w._flags end
    local flags = {}
    local n = Safe(GetNumObjectives) or 0
    for i = 1, n do
        local keepId, objectiveId, ctx = Safe(GetObjectiveIdsForIndex, i)
        local isLocal = keepId and (not IsLocalBattlegroundContext or IsLocalBattlegroundContext(ctx))
        if isLocal and OBJECTIVE_CAPTURE_AREA and Safe(GetObjectiveType, keepId, objectiveId, ctx) == OBJECTIVE_CAPTURE_AREA then
            local f = flags[keepId] or { total = 0, moving = 0, lost = 0 }
            flags[keepId] = f
            f.total = f.total + 1
            local state = Safe(GetObjectiveControlState, keepId, objectiveId, ctx)
            local holder = Safe(GetCaptureAreaObjectiveOwner, keepId, objectiveId, ctx)
            local owner = w.byId[keepId] and w.byId[keepId].owner
            local neutral = state ~= nil and state == OBJECTIVE_CONTROL_STATE_AREA_NO_CONTROL
            local stepping = state ~= nil and (state == OBJECTIVE_CONTROL_STATE_AREA_ABOVE_CONTROL_THRESHOLD
                or state == OBJECTIVE_CONTROL_STATE_AREA_BELOW_CONTROL_THRESHOLD)
            if neutral or stepping then
                f.moving = f.moving + 1
                -- The back flag (the Apse, deepest in the keep) going is the one to rush.
                local name = tostring(Safe(GetObjectiveInfo, keepId, objectiveId, ctx) or ""):lower()
                if name:find("apse", 1, true) or (not name:find("nave", 1, true) and BACK_FLAG[keepId] == objectiveId) then f.back = true end
            end
            -- A neutral flag is lost. Otherwise no holder means the owner still has it.
            if neutral or (holder and holder ~= 0 and owner and holder ~= owner) then f.lost = f.lost + 1 end
        end
    end
    w._flags = flags
    return flags
end

local function Sieges(w, t, alliance)
    return Safe(GetNumSieges, t.keepId, w.ctx, alliance) or 0
end

-- Seconds of Continuous Attack left (0 if none), and whether the player has the passive.
local function ContinuousAttack()
    local left = 0
    local now = Safe(GetFrameTimeSeconds) or 0
    for i = 1, Safe(GetNumBuffs, "player") or 0 do
        local _, _, ending, _, _, _, _, _, _, _, abilityId = Safe(GetUnitBuffInfo, "player", i)
        if CA_BUFFS[abilityId] and ending and ending > now then left = math.max(left, ending - now) end
    end
    local owned = true
    if GetSpecificSkillAbilityKeysByAbilityId and IsSkillAbilityPurchased then
        local ok, a, b, c = pcall(GetSpecificSkillAbilityKeysByAbilityId, CA_PASSIVE)
        if ok and a then
            local okP, purchased = pcall(IsSkillAbilityPurchased, a, b, c)
            if okP then owned = purchased == true end
        end
    end
    return left, owned
end

-- Where an alliance's scrolls are: { gate, home, heldAt (keep holding it), x, y }.
local function Scrolls(w, alliance)
    w._scrollSpots = w._scrollSpots or {}
    if w._scrollSpots[alliance] then return w._scrollSpots[alliance] end
    local out = {}
    for _, gate in ipairs(SCROLLS[alliance] or {}) do
        local objectiveId = Safe(GetKeepArtifactObjectiveId, gate.temple)
        local state = objectiveId and Safe(GetObjectiveControlState, gate.temple, objectiveId, w.ctx)
        local spot = { gate = gate }
        -- Unknown state counts as home.
        spot.home = state == nil or OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE == nil or state == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE
        if not spot.home then
            if OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE and state == OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
                spot.heldAt = Safe(GetKeepThatHasCapturedThisArtifactScrollObjective, gate.temple, objectiveId, w.ctx)
            end
            local _, x, y = Safe(GetObjectivePinInfo, gate.temple, objectiveId, w.ctx)
            if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then spot.x, spot.y = x, y end
        end
        table.insert(out, spot)
    end
    w._scrollSpots[alliance] = out
    return out
end

-- The alliance holding the emperorship, if any.
local function EmperorAlliance(w)
    if not Safe(DoesCampaignHaveEmperor, w.campaignId) then return nil end
    local alliance = Safe(GetCampaignEmperorInfo, w.campaignId)
    if alliance and alliance ~= 0 then return alliance end
end

-- Our scrolls that are at home, by temple.
local function ScrollsHome(w)
    if w._scrolls then return w._scrolls end
    local home = {}
    for _, gate in ipairs(SCROLLS[w.mine] or {}) do
        local objectiveId = Safe(GetKeepArtifactObjectiveId, gate.temple)
        local state = objectiveId and Safe(GetObjectiveControlState, gate.temple, objectiveId, w.ctx)
        -- Unknown state counts as home, so gate keeps are never ignored by mistake.
        home[gate.temple] = state == nil or state == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE or OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE == nil
    end
    w._scrolls = home
    return home
end

local function OwnerOf(w, keepId)
    local t = w.byId[keepId]
    if t and t.owner then return t.owner end
    return Safe(GetKeepAlliance, keepId, w.ctx)
end

-- How many of our home scrolls this keep protects (0, 1 or 2), and whether it
-- is the last lock standing on one of them.
local function ScrollGuard(w, keepId)
    local guards, lastLock = 0, false
    local home = ScrollsHome(w)
    for _, gate in ipairs(SCROLLS[w.mine] or {}) do
        if (gate.hub == keepId or gate.side == keepId) and home[gate.temple] then
            guards = guards + 1
            local other = gate.hub == keepId and gate.side or gate.hub
            if OwnerOf(w, other) ~= w.mine then lastLock = true end
        end
    end
    return guards, lastLock
end

-- Is our own scroll of this color at home?
local function HaveColor(w, color)
    local home = ScrollsHome(w)
    for _, gate in ipairs(SCROLLS[w.mine] or {}) do
        if COLOR[gate.temple] == color and home[gate.temple] then return true end
    end
    return false
end

-- Scroll moves, by keep: our own scroll held in a keep we don't own (20), an
-- enemy scroll held in a keep we don't own (16, any color), and the locks on an
-- enemy gate whose scroll is home and whose color we have (12 if taking it
-- opens the gate, 6 for a first lock, +2 for a hub).
local function RaidValues(w)
    if w._raids then return w._raids end
    local value = {}
    local function add(keepId, v) if not value[keepId] or v > value[keepId] then value[keepId] = v end end
    for _, alliance in ipairs({ AD, EP, DC }) do
        for i, gate in ipairs(SCROLLS[alliance]) do
            local spot = Scrolls(w, alliance)[i]
            if spot.heldAt and spot.heldAt ~= 0 then
                if OwnerOf(w, spot.heldAt) ~= w.mine then add(spot.heldAt, alliance == w.mine and 20 or 16) end
            elseif alliance ~= w.mine and spot.home and HaveColor(w, COLOR[gate.temple]) then
                for _, keepId in ipairs({ gate.hub, gate.side }) do
                    local other = keepId == gate.hub and gate.side or gate.hub
                    if OwnerOf(w, keepId) == alliance then
                        add(keepId, (OwnerOf(w, other) ~= alliance and 12 or 6) + (HUBS[keepId] and 2 or 0))
                    end
                end
            end
        end
    end
    w._raids = value
    return value
end

-- Emperor keeps for an alliance, from the campaign ruleset if possible.
local function EmperorKeeps(w, alliance)
    local rulesetId = Safe(GetCampaignRulesetId, w.campaignId)
    local n = rulesetId and Safe(GetCampaignRulesetNumImperialKeeps, rulesetId, alliance)
    if n and n > 0 then
        local keeps = {}
        for i = 1, n do
            local keepId = Safe(GetCampaignRulesetImperialKeepId, rulesetId, alliance, i)
            if keepId then table.insert(keeps, keepId) end
        end
        if #keeps > 0 then return keeps end
    end
    return EMPEROR_KEEPS
end

-- The one emperor keep an alliance is still missing, if it is one away.
local function LastEmperorKeep(w, alliance)
    local missing
    for _, keepId in ipairs(EmperorKeeps(w, alliance)) do
        if OwnerOf(w, keepId) ~= alliance then
            if missing then return nil end
            missing = keepId
        end
    end
    return missing
end

-- Does an enemy alliance hold all of its home keeps (so taking one breaks its bonuses)?
local function HoldsAllHome(w, alliance)
    for keepId in pairs(HOME[alliance] or {}) do
        if OwnerOf(w, keepId) ~= alliance then return false end
    end
    return true
end

-- Smoothed win rate for a target from the scoreboard's lifetime record (0..1).
local function WinRate(w, t)
    local life = w.lifetime and w.lifetime[tostring(t.keepId)]
    local wins, losses = life and life.w or 0, life and life.l or 0
    return (wins + 1) / (wins + losses + 2)
end

-- The parent keep of a resource, and a keep's resources.
local function ParentOf(w, t)
    return t.parent and w.byId[t.parent]
end

local function ResourcesOf(w, keepId)
    local out = {}
    for _, t in ipairs(w.targets) do if t.parent == keepId then table.insert(out, t) end end
    return out
end

-- Things worth running far for: our last emperor keep, our home keeps taken
-- by an enemy, and gate keeps guarding a scroll that is at home.
local function Important(w, t)
    if not t.defend and t.keepId == LastEmperorKeep(w, w.mine) then return true end
    if HOME[w.mine][t.keepId] and (t.defend or t.owner ~= w.mine) and ScrollGuard(w, t.keepId) > 0 then return true end
    if not t.defend and HOME[w.mine][t.keepId] then return true end
    return false
end

-- Strategy score shared by Chris and Confessor.
local KIND_VALUE = { Keep = 10, Outpost = 7, Town = 6, Lumbermill = 4, Farm = 4, Mine = 4 }

local function StrategyScore(w, t)
    local lost = LostCause(w, t)
    if lost then return nil end
    local score = KIND_VALUE[t.kind] or 4
    local guards, lastLock = 0, false
    if HOME[w.mine][t.keepId] then guards, lastLock = ScrollGuard(w, t.keepId) end
    if t.defend then
        score = score + 4 + guards * 8 + (lastLock and 6 or 0) + ((guards > 0 and HUBS[t.keepId]) and 3 or 0)
        local enemyLast
        for _, a in ipairs({ AD, EP, DC }) do
            if a ~= w.mine and LastEmperorKeep(w, a) == t.keepId then enemyLast = true end
        end
        if enemyLast then score = score + 12 end
    else
        if HOME[w.mine][t.keepId] then score = score + 10 + guards * 6 end
        if t.keepId == LastEmperorKeep(w, w.mine) then score = score + 15 end
        if t.kind == "Keep" and t.owner and HOME[t.owner] and HOME[t.owner][t.keepId] and HoldsAllHome(w, t.owner) then
            score = score + 6
        end
        if Sieges(w, t, w.mine) > 0 then score = score + 3 end
        score = score + (RaidValues(w)[t.keepId] or 0)
        -- Taking a keep's last resource its owner holds cuts that keep off.
        local parent = ParentOf(w, t)
        if parent and parent.owner == t.owner then
            local held = 0
            for _, r in ipairs(ResourcesOf(w, parent.keepId)) do if r.owner == t.owner then held = held + 1 end end
            if held == 1 then score = score + 4 end
        end
    end
    local ours, theirs = FightAt(w, t)
    if ours > theirs then score = score + 3 end
    score = score + 4 * (WinRate(w, t) - 0.5)
    return score
end

local function IsResource(t) return t.parent ~= nil end

-- Every random pick goes through this: each target type (keep, resource, town,
-- outpost) as likely as the next, never the last call's type when there's another.
local OneOf = LazyCrown.OneOf

-- A defense that protects one of our home scrolls beats everything else (only
-- within reach, if given; list defaults to the options).
local function ScrollDefense(w, reach, list)
    local best, bestScore
    for _, t in ipairs(list or w.options) do
        local d = reach and Away(w, t)
        if t.defend and HOME[w.mine][t.keepId] and ScrollGuard(w, t.keepId) > 0 and not (d and d > reach) then
            local score = StrategyScore(w, t)
            if score and (not bestScore or score > bestScore) then best, bestScore = t, score end
        end
    end
    return best
end

-- Is this account (an @name) you or someone in your group?
local function WithUs(displayName)
    if not displayName or displayName == "" then return false end
    if displayName == Safe(GetUnitDisplayName, "player") then return true end
    for i = 1, Safe(GetGroupSize) or 0 do
        local tag = Safe(GetGroupUnitTagByIndex, i)
        if tag and Safe(GetUnitDisplayName, tag) == displayName then return true end
    end
    return false
end

-- Volendrung: where it is and who has it ({ holder, withUs, x, y }; holder is
-- nil while it's on the ground; withUs when you or your group carry it), or nil
-- if it isn't out.
local function Hammer(w)
    if w._hammer ~= nil then return w._hammer or nil end
    w._hammer = false
    if not OBJECTIVE_DAEDRIC_WEAPON then return nil end
    for i = 1, Safe(GetNumObjectives) or 0 do
        local keepId, objectiveId, ctx = Safe(GetObjectiveIdsForIndex, i)
        local isLocal = keepId and (not IsLocalBattlegroundContext or IsLocalBattlegroundContext(ctx))
        if isLocal and Safe(GetObjectiveType, keepId, objectiveId, ctx) == OBJECTIVE_DAEDRIC_WEAPON then
            local state = Safe(GetObjectiveControlState, keepId, objectiveId, ctx)
            local enabled = not IsObjectiveEnabled or Safe(IsObjectiveEnabled, keepId, objectiveId, ctx) ~= false
            if state and state ~= OBJECTIVE_CONTROL_STATE_UNKNOWN and enabled then
                local holder = Safe(GetCarryableObjectiveHoldingAllianceInfo, keepId, objectiveId, ctx)
                local pinType, x, y = Safe(GetObjectivePinInfo, keepId, objectiveId, ctx)
                local hammer = { holder = (holder and holder ~= 0) and holder or nil, state = state }
                local _, carrier = Safe(GetCarryableObjectiveHoldingCharacterInfo, keepId, objectiveId, ctx)
                hammer.withUs = Safe(IsCarryableObjectiveCarriedByLocalPlayer, keepId, objectiveId, ctx) == true or WithUs(carrier)
                if pinType ~= MAP_PIN_TYPE_INVALID and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
                    hammer.x, hammer.y = x, y
                end
                w._hammer = hammer
                return hammer
            end
        end
    end
    return nil
end

-- Is one of our home keeps that guards a home scroll under attack? Looks at the
-- whole map, not just what's left to pick this time.
local function ScrollKeepUnderAttack(w)
    for keepId in pairs(HOME[w.mine] or {}) do
        if OwnerOf(w, keepId) == w.mine and w.UnderAttack(keepId) and ScrollGuard(w, keepId) > 0 then return true end
    end
    return false
end

-- For /lazycrown scan.
P.HammerNow = function() return Hammer({}) end
P.ScrollStates = function(ctx)
    local w, out = { ctx = ctx }, {}
    for _, alliance in ipairs({ AD, EP, DC }) do
        for _, spot in ipairs(Scrolls(w, alliance)) do
            table.insert(out, { temple = spot.gate.temple, home = spot.home, heldAt = spot.heldAt ~= 0 and spot.heldAt or nil, x = spot.x, y = spot.y })
        end
    end
    return out
end

-- Follow the hammer: "follow the hammer to X", X being whatever target is closest
-- to it (anyone's). It isn't a capture, so it doesn't go on the scoreboard.
-- "ours": only when our alliance has it. "safe": ours, and no scroll keep is
-- under attack. "always": whoever has it. Nobody follows it when you or your
-- group are the ones carrying it: every crown carries on as usual.
local function FollowHammer(w, rule)
    local hammer = Hammer(w)
    if not (hammer and hammer.x) or hammer.withUs then return nil end
    if rule ~= "always" and hammer.holder ~= w.mine then return nil end
    if rule == "safe" and ScrollKeepUnderAttack(w) then return nil end
    local near = Nearest(hammer, Filter(w.targets, function(t) return w.Allied(t.owner) and (not w.KindOn or w.KindOn(t.kind)) end))
    if not near then return nil end
    local pick = {}
    for k, v in pairs(near) do pick[k] = v end
    pick.directive = "follow the hammer to " .. near.name
    pick.unscored = true
    return { pick = pick }
end

-- While we hold the emperorship: our emperor keeps under attack come first, and
-- (if stayClose) with only one or two of them left, stay close to them: the
-- targets closest to the emperor keeps we still hold.
local function GuardThrone(w, stayClose)
    if EmperorAlliance(w) ~= w.mine then return nil end
    local isEmp, held, lost = {}, {}, {}
    for _, keepId in ipairs(EmperorKeeps(w, w.mine)) do
        isEmp[keepId] = true
        if OwnerOf(w, keepId) == w.mine then table.insert(held, w.byId[keepId] or { keepId = keepId }) else lost[keepId] = true end
    end
    local few = #held <= 2
    local flags = Flags(w)
    local defenses = Filter(w.options, function(t) return t.defend and isEmp[t.keepId] end)
    if #defenses > 0 then
        return TopPick(w, defenses, function(t)
            local f = flags[t.keepId]
            local d = Away(w, t)
            return 10 + (f and (f.lost * 4 + f.moving * 2) or 0) - (d and 10 * d or 0)
        end, few and 1 or 2)
    end
    if not (stayClose and few) or #held == 0 then return nil end
    return TopPick(w, w.options, function(t)
        if t.defend then return nil end
        local closest
        for _, k in ipairs(held) do
            local d = Dist(k, t)
            if d and (not closest or d < closest) then closest = d end
        end
        return closest and -closest
    end, 3)
end

-- Lazy: anything, equally likely (the plain pick in LazyCrown.lua does it).
P.lazy = function(w)
    return nil
end

-- Ultra Lazy: whatever's closest.
P.ultralazy = function(w)
    if not w.player then return nil end
    local pick = TopPick(w, w.options, function(t)
        local d = Away(w, t)
        return d and -d
    end, 3)
    return pick and { pick = pick }
end

local function Legs(plan)
    local legs = { plan.pick }
    for _, leg in ipairs(plan.chain or {}) do table.insert(legs, leg) end
    return legs
end

-- A fight we're losing: they have more battle victories near it than we do.
local function LosingFight(w, t)
    local ours, theirs = FightAt(w, t)
    return theirs >= 5 and theirs > ours
end

-- What's within reach: the part of the map you're in, else twice that, else
-- anything. Travel time, so a transit hop counts as close.
local function Nearby(w, list)
    for _, reach in ipairs({ AREA, 2 * AREA }) do
        local near = Filter(list, function(t)
            local d = Away(w, t)
            return d == nil or d <= reach
        end)
        if #near > 0 then return near end
    end
    return list
end

-- The resource to take for Continuous Attack on the way to a target: the
-- smallest detour from where you are (the target's own resources win a tie),
-- else the closest one if it's close. Nil when there's none nearby.
local function OnTheWay(w, target)
    local resources = Filter(w.options, function(t)
        local d = Away(w, t)
        return IsResource(t) and not t.defend and not LostCause(w, t) and (d == nil or d <= AREA)
    end)
    local toTarget = Away(w, target) or 0
    local best, bestDetour
    for _, r in ipairs(resources) do
        local detour = (Away(w, r) or 0) + (Dist(r, target) or 0) - toTarget - (r.parent == target.keepId and 0.02 or 0)
        if not bestDetour or detour < bestDetour then best, bestDetour = r, detour end
    end
    if best and bestDetour <= NEAR then return best end
    local closest = TopPick(w, resources, function(t)
        local d = Away(w, t)
        return d and d <= AREA / 2 and -d or nil
    end, 1)
    return closest
end

-- Heat for Confessor's greedy side: flags moving or taken, a fight going on.
local function Heat(w, t, flags)
    local f = flags[t.keepId]
    local heat = f and (f.moving * 3 + f.lost * 2) or 0
    if w.UnderAttack(t.keepId) then heat = heat + 2 end
    return heat
end

-- Chris's brain (Confessor's too): work the part of the map you're in, a keep,
-- its resources, the outpost and town next to it, then on to the next one. Go
-- farther only when transitus gets you there or nothing is left nearby. One
-- call at a time. style: n (top n), dist (distance weight), greedy (Confessor
-- likes heat), careful (Confessor skips losing fights and far resources).
local function Strategist(w, style)
    local options = w.options
    if style.careful then options = Filter(options, function(t) return not LosingFight(w, t) end) end
    local guard = ScrollDefense(w, AREA, options)
    if guard then return { pick = guard } end
    -- Took the resource on the way: now the keep, town or outpost it was for.
    local memory = w.memory or {}
    local planned = memory.chrisNext
    if planned and w.lastCall and w.lastCall.keepId == planned.after then
        memory.chrisNext = nil
        if w.lastCall.result == "W" then
            for _, t in ipairs(options) do
                if t.keepId == planned.keepId and not t.defend and StrategyScore(w, t) then return { pick = t } end
            end
        end
    end
    local candidates = Filter(options, function(t)
        if not StrategyScore(w, t) then return false end -- lost causes
        local d = Away(w, t)
        return not (style.careful and IsResource(t) and d and d > NEAR) -- no squirrels
    end)
    local flags = style.greedy and Flags(w)
    local pick = TopPick(w, Nearby(w, candidates), function(t)
        local score = StrategyScore(w, t)
        if flags then score = score + Heat(w, t, flags) end
        local d = Away(w, t)
        return score - (d and style.dist * d or 0)
    end, style.n)
    if not pick then return nil end
    -- Continuous Attack low and going for a keep, town or outpost: the resource
    -- on the way is the call; the target is the next call.
    local left, owned = ContinuousAttack()
    if not pick.defend and not IsResource(pick) and owned and left < CA_LOW then
        local leg = OnTheWay(w, pick)
        if leg then
            memory.chrisNext = { keepId = pick.keepId, after = leg.keepId }
            return { pick = leg }
        end
    end
    return { pick = pick }
end

-- 20/20 siege for the first keep attack in a plan: a weak wall if it just
-- changed hands (Chris sometimes wants Trebs), otherwise the front door. A
-- troll call already says where to siege from.
local function SiegeLine(w, plan, trebs)
    for _, leg in ipairs(Legs(plan)) do
        if leg.kind == "Keep" and not leg.defend then
            if leg.directive then return "20/20 siege." end
            local ago = w.FlippedAgo and w.FlippedAgo(leg.keepId)
            if ago and ago <= RECENT_FLIP then
                local line = "20/20 siege, look for a weak wall"
                if trebs and w.Random(1, 2) == 1 then line = line .. " and I wanna see a few Trebs" end
                return line .. "."
            end
            return "20/20 siege, front door."
        end
    end
end

-- Troll versions of the keeps in a list of options (only the siege spots if asked).
local function Trolls(w, options, spotsOnly)
    local list = {}
    for _, call in ipairs(TROLL_CALLS) do
        for _, t in ipairs(options or w.options) do
            if t.keepId == call.keepId and not t.defend and not t.directive and (call.spot or not spotsOnly) then
                local directed = {}
                for k, v in pairs(t) do directed[k] = v end
                directed.directive = call.directive
                table.insert(list, directed)
            end
        end
    end
    return list
end

-- Chris's way of saying a siege spot: no "troll", no "be annoying".
local function PlainSpot(directive)
    local keep, from = directive:match("^troll (.+) by sieging from (.+)$")
    if keep then return string.format("hit %s and siege from %s", keep, from) end
    return directive:match("^be annoying and (take .+)$") or directive
end

-- Chris: lazy but with a brain, with 20/20 siege on keeps.
P.chris = function(w)
    local plan = Strategist(w, { n = 3, dist = 25 })
    if not plan then return nil end
    -- Only when it's going really badly (10 L's in a row): half the time, one of
    -- the siege spots on a keep that didn't just change hands.
    local pick = plan.pick
    local ago = w.FlippedAgo and w.FlippedAgo(pick.keepId)
    if (w.streakL or 0) >= SIEGE_SPOT_STREAK and pick.kind == "Keep" and not pick.defend and not (ago and ago <= RECENT_FLIP) then
        local ways = Trolls(w, { pick }, true)
        if #ways > 0 and w.Random(1, 2) == 1 then
            plan.pick = ways[w.Random(1, #ways)]
            plan.pick.directive = PlainSpot(plan.pick.directive)
        end
    end
    plan.extras = { SiegeLine(w, plan, true) }
    return plan
end

-- Confessor: Chris's way of playing, a little greedier (flags moving, fights
-- going on), and no losing fights, lost causes or squirrels.
P.confessor = function(w)
    local plan = Strategist(w, { n = 2, dist = 40, greedy = true, careful = true })
    if plan then return plan end
    local pick
    -- Nothing passes: the closest thing that isn't a lost cause; if everything is
    -- one, the least bad fight. Never a random ride.
    pick = pick or TopPick(w, w.options, function(t)
        if LostCause(w, t) then return nil end
        local d = Away(w, t)
        return d and -d or 0
    end, 1) or TopPick(w, w.options, function(t)
        local ours, theirs = FightAt(w, t)
        return ours - theirs
    end, 1)
    return pick and { pick = pick }
end

-- Greedy: our emperor keeps first while we have the emperor, then the hammer
-- whoever has it, then rush the flips we can get to in time, and defend when
-- the fight is winnable and reachable.
local QuestTargets -- further down, with the quest data

P.greedy = function(w)
    local throne = GuardThrone(w, true)
    if throne then return { pick = throne } end
    local hammer = FollowHammer(w, "always")
    if hammer then return hammer end
    local flags = Flags(w)
    local haveFlags = next(flags) ~= nil
    local ruledOut = {}
    local pick = TopPick(w, w.options, function(t)
        local f = flags[t.keepId]
        local ours, theirs = FightAt(w, t)
        local d = Away(w, t)
        if t.defend then
            -- Only when an enemy is actually flipping it (if the game reports flags at all).
            local flipping = f and (f.moving > 0 or f.lost > 0)
            local skip = (haveFlags and not flipping)
                or theirs >= LOST_CAUSE or theirs > ours
                or (f and f.total > 1 and f.lost >= f.total - 1 and not (d and d <= CLOSE)) -- one flag left, too far
                or (f and f.lost == 0 and f.moving >= 1 and not (d and d <= NEAR))          -- barely started, too far
            if skip then ruledOut[t] = true return nil end
            return 6 + (f and f.moving or 0) * 6 + (f and f.lost or 0) * 4 + (f and f.back and 15 or 0) + ours - (d and 20 * d or 0)
        end
        local hot = (f and f.moving or 0) * 6 + (f and f.lost or 0) * 4 + (f and f.back and 15 or 0)
        if w.UnderAttack(t.keepId) then hot = hot + 4 end
        if Sieges(w, t, w.mine) > 0 then hot = hot + 5 end
        if hot == 0 then return nil end
        -- Travel time: a resource flips in no time, and once flags are moving a
        -- keep, outpost or town doesn't wait either. Too far and it's over before we arrive.
        local capturing = f and (f.moving > 0 or f.lost > 0)
        if (IsResource(t) or capturing) and d and d > (IsResource(t) and CLOSE or NEAR) then
            ruledOut[t] = true
            return nil
        end
        return hot + ours - (d and 20 * d or 0)
    end, 3)
    if not pick then
        -- Nothing hot: anything except what it just ruled out. A resource only
        -- if it's close or you have a quest for it: no riding across the map for one.
        local onQuest = {}
        for _, t in ipairs((QuestTargets(w))) do onQuest[t] = true end
        local rest = Filter(w.options, function(t)
            if ruledOut[t] or LostCause(w, t) then return false end
            if not IsResource(t) or onQuest[t] then return true end
            local d = Away(w, t)
            return d ~= nil and d <= CLOSE
        end)
        if #rest == 0 then return nil end
        pick = OneOf(w, rest)
    end
    return { pick = pick }
end

-- Your scout and capture quests (Selfish and Deano use these).
local QUEST_PARTS = { [1] = RESOURCETYPE_WOOD or 1, [2] = RESOURCETYPE_FOOD or 2, [3] = RESOURCETYPE_ORE or 3 }

function QuestTargets(w)
    local quests = LazyCrown.QUESTS
    if not (quests and IsValidQuestIndex and GetJournalQuestId) then return {}, {}, nil end
    local byKeep, capture, daily = {}, {}, nil
    for i = 1, MAX_JOURNAL_QUESTS or 25 do
        if Safe(IsValidQuestIndex, i) and not Safe(GetJournalQuestIsComplete, i) then
            local questId = Safe(GetJournalQuestId, i)
            local code = quests.capture[questId] or quests.scout[questId]
            if code then
                local keepId, part = math.floor(code / 10), code % 10
                local targetId = keepId
                if part > 0 then targetId = Safe(GetResourceKeepForKeep, keepId, QUEST_PARTS[part]) end
                if targetId then
                    byKeep[targetId] = true
                    if quests.capture[questId] then capture[targetId] = true end
                end
            elseif quests.daily[questId] then
                daily = quests.daily[questId]
            end
        end
    end
    return Filter(w.options, function(t) return byKeep[t.keepId] and not t.defend end), capture, daily
end

-- Selfish: Greedy, plus your own quests when they're close by.
P.selfish = function(w)
    local function finish(plan)
        if not plan then return nil end
        plan.extras = plan.extras or {}
        for _, spot in ipairs(Scrolls(w, w.mine)) do
            if not spot.home and spot.heldAt == plan.pick.keepId then table.insert(plan.extras, "Make sure you get the scroll quest.") end
        end
        for _, leg in ipairs(Legs(plan)) do
            if leg.keepId == DRAKELOWE or (leg.parent == DRAKELOWE and leg.kind == "Mine") then
                table.insert(plan.extras, "And give me those Drakelowe shares.")
                break
            end
        end
        return plan
    end
    -- Your quests first when they're close by (the whole group does them for you).
    local questTargets, capture = QuestTargets(w)
    local quest = TopPick(w, questTargets, function(t)
        local d = Away(w, t)
        if LostCause(w, t) or (d and d > NEAR) then return nil end
        return (capture[t.keepId] and 10 or 0) - (d and 10 * d or 0)
    end, 1)
    if quest then return finish({ pick = quest }) end
    -- Otherwise Greedy.
    return finish(P.greedy(w))
end

-- Deano: scrappy small scale. Towns and outposts, a resource now and then for
-- Continuous Attack or your quests, the keep once the nearest town and outpost
-- are ours, and a grudge against Warden, Kingscrest or Black Boot while an
-- enemy has the emperor. The troll calls are in the mix, and a keep that has
-- one gets trolled half the time.
P.deano = function(w)
    local function troll(t)
        local ways = Trolls(w, { t })
        if #ways > 0 and w.Random(1, 2) == 1 then return ways[w.Random(1, #ways)] end
        return t
    end
    local emperor = EmperorAlliance(w)
    if emperor and emperor ~= w.mine then
        local grudges = {}
        for alliance, keepId in pairs(GRUDGE_KEEPS) do
            if alliance ~= w.mine then
                for _, t in ipairs(w.options) do if t.keepId == keepId and not t.defend then table.insert(grudges, t) end end
            end
        end
        if #grudges > 0 then return { pick = troll(OneOf(w, grudges)) } end
    end
    if w.player then
        local town = Nearest(w.player, Filter(w.targets, function(t) return t.kind == "Town" end))
        local outpost = Nearest(w.player, Filter(w.targets, function(t) return t.kind == "Outpost" end))
        if town and outpost and town.owner == w.mine and outpost.owner == w.mine then
            local keep = Nearest(w.player, Filter(w.options, function(t) return t.kind == "Keep" and not t.defend and not LostCause(w, t) end))
            if keep then return { pick = troll(keep) } end
        end
    end
    local pool = Filter(w.options, function(t) return (t.kind == "Town" or t.kind == "Outpost") and not LostCause(w, t) end)
    for _, t in ipairs(Trolls(w)) do if not LostCause(w, t) then table.insert(pool, t) end end
    local onQuest = {}
    for _, t in ipairs((QuestTargets(w))) do
        if IsResource(t) then table.insert(pool, t); onQuest[t.keepId] = true end
    end
    local left, owned = ContinuousAttack()
    if owned and left < CA_LOW then
        local resource = Nearest(w.player or {}, Filter(w.options, function(t) return IsResource(t) and not t.defend and not LostCause(w, t) end))
        if resource then table.insert(pool, resource) end
    end
    local pick = TopPick(w, pool, function(t)
        local d = Away(w, t)
        local life = w.lifetime and w.lifetime[tostring(t.keepId)]
        local grudge = life and life.l or 0 -- a penchant for grudges
        return 5 + math.min(grudge, 3) * 2 + (onQuest[t.keepId] and 15 or 0) - (d and 15 * d or 0)
    end, 3)
    return pick and { pick = pick }
end

-- Mulliss: the other side of the map, or a defense that's already going badly.
P.mulliss = function(w)
    local from = w.player or (w.lastCall and w.byId[w.lastCall.keepId])
    local pick = TopPick(w, w.options, function(t)
        if t.defend then
            local ours, theirs = FightAt(w, t)
            if theirs > ours then return 10 + theirs - ours end
            return nil
        end
        local d = Dist(from, t)
        if d and d >= OTHER_SIDE then return 20 * d end
        return nil
    end, 3)
    -- Nothing far or doomed: the farthest thing there is.
    pick = pick or TopPick(w, w.options, function(t) return Dist(from, t) or 0 end, 1)
    return pick and { pick = pick }
end

-- Diil: big, bold and far away. Keeps only. While we have the emperor, our
-- emperor keeps under attack come first (no staying close: Diil wanders). Then the
-- hammer if it's ours, then scrolls and the moves that shake up the map:
-- knocking an enemy emperor off, our last emperor keep, breaking an alliance
-- that holds all its home keeps. Distance breaks ties, the farther the better.
-- Troll calls wherever they exist, 20/20 siege on everything.
P.diil = function(w)
    local function finish(pick)
        local ways = Trolls(w, { pick })
        if #ways > 0 then pick = ways[w.Random(1, #ways)] end
        local plan = { pick = pick }
        plan.extras = { SiegeLine(w, plan) }
        return plan
    end
    local throne = GuardThrone(w)
    if throne then return finish(throne) end
    local hammer = FollowHammer(w, "safe")
    if hammer then return hammer end
    local from = w.player or (w.lastCall and w.byId[w.lastCall.keepId])
    local raids = RaidValues(w)
    local emperor = EmperorAlliance(w)
    local throne = {}
    if emperor and emperor ~= w.mine then
        for _, keepId in ipairs(EmperorKeeps(w, emperor)) do throne[keepId] = true end
    end
    local ourLast = LastEmperorKeep(w, w.mine)
    local keeps = Filter(w.options, function(t) return t.kind == "Keep" and not t.defend end)
    local pick = TopPick(w, keeps, function(t)
        local bold = (raids[t.keepId] or 0) * 2
        if throne[t.keepId] and t.owner == emperor then bold = bold + 20 end
        if t.keepId == ourLast then bold = bold + 20 end
        if HOME[t.owner] and HOME[t.owner][t.keepId] and HoldsAllHome(w, t.owner) then bold = bold + 10 end
        local d = Dist(from, t)
        return bold + (d and 30 * d or 0)
    end, 3)
    if not pick then return nil end
    return finish(pick)
end

-- November: gets trollier the more we lose (L's in a row; a W starts over).
--   0 to 2: the flanks.
--   3 to 5: any troll call, all equally likely.
--   6: the north (Bruma, Winter's Peak, Dragonclaw).
--   7 and up: the grudge keep of whoever is beating us (most L's this streak):
--   Kingscrest, Warden or Black Boot, or its troll calls, every time.
-- When that's not possible (the north is all ours, the last loss was up there,
-- or that keep is ours): only troll calls on the other side of the map from
-- the last loss (the farthest ones if none are that far).
local NORTH_SET = { [WINGS.north.town] = true, [WINGS.north.outpost] = true, [WINGS.north.keep] = true }

-- The alliance behind this losing streak: the most L's against it, the latest on a tie.
local function Culprit(w)
    local best, most = nil, 0
    local latest = w.lastCall and w.lastCall.against
    for key, n in pairs(w.streakBy or {}) do
        local alliance = tonumber(key)
        if n > most or (n == most and alliance == latest) then best, most = alliance, n end
    end
    return best or latest
end

local function WingTargets(w, wing)
    local set = { [wing.keep] = true, [wing.town] = true, [wing.outpost] = true }
    return Filter(w.options, function(t) return set[t.keepId] or (t.parent == wing.keep) end)
end

-- Troll calls close by: within reach (about 110 seconds, transitus counts),
-- else the three closest. November doesn't cross the map on a whim.
local function NearTroll(w, trolls)
    -- No position: measure from the last call's target instead.
    local from = not w.player and w.lastCall and w.byId[w.lastCall.keepId]
    local function away(t) return Away(w, t) or (from and Dist(from, t)) end
    if not (w.player or from) then return OneOf(w, trolls) end
    local near = Filter(trolls, function(t)
        local d = away(t)
        return d and d <= AREA
    end)
    if #near > 0 then return OneOf(w, near) end
    return TopPick(w, trolls, function(t)
        local d = away(t)
        return d and -d or nil
    end, 3)
end

P.november = function(w)
    local losses = w.streakL or 0
    if losses >= 6 then
        local lastLoss = w.lastCall and w.lastCall.result == "L" and w.lastCall.keepId
        local culprit = losses >= 7 and Culprit(w)
        if culprit and GRUDGE_KEEPS[culprit] then
            -- Every time, even right after the last call went there.
            local list = Filter(w.everything or w.options, function(t) return t.keepId == GRUDGE_KEEPS[culprit] end)
            for _, t in ipairs(Trolls(w, list)) do table.insert(list, t) end
            if #list > 0 then return { pick = OneOf(w, list) } end
        elseif not (lastLoss and NORTH_SET[lastLoss]) then
            local north = Filter(w.options, function(t) return NORTH_SET[t.keepId] end)
            if #north > 0 then return { pick = OneOf(w, north) } end
        end
        -- Can't do that: troll calls on the other side of the map from the last
        -- loss, on whoever beat us there (across the map only for a grudge).
        local from = (lastLoss and w.byId[lastLoss]) or w.player
        local against = lastLoss and w.lastCall.against
        local theirs = Filter(Trolls(w), function(t) return against and t.owner == against end)
        local far = Filter(theirs, function(t)
            local d = Dist(from, t)
            return not d or d >= OTHER_SIDE
        end)
        if #far > 0 then return { pick = OneOf(w, far) } end
        local farthest = TopPick(w, theirs, function(t) return Dist(from, t) or 0 end, 2)
        if farthest then return { pick = farthest } end
        -- Nobody to blame: a troll call close by.
        local close = NearTroll(w, Trolls(w))
        if close then return { pick = close } end
    elseif losses >= 3 then
        -- A troll call, but close by.
        local close = NearTroll(w, Trolls(w))
        if close then return { pick = close } end
    end
    -- The flanks: the edge keeps, their resources, and the wing towns and outposts
    -- (ours under attack count too).
    local list = {}
    for _, wing in pairs(WINGS) do for _, t in ipairs(WingTargets(w, wing)) do table.insert(list, t) end end
    local pick = TopPick(w, list, function(t)
        if LostCause(w, t) then return nil end
        local d = Away(w, t)
        local value = t.kind == "Keep" and 6 or (t.kind == "Town" or t.kind == "Outpost") and 5 or 3
        return value - (d and 15 * d or 0)
    end, 3)
    return pick and { pick = pick }
end

-- Bored: wherever the fighting is. Anyone's battle victories nearby, flags
-- moving or taken, under attack, siege up. Distance hardly matters; with
-- nothing going on anywhere, anything.
P.bored = function(w)
    local flags = Flags(w)
    local pick = TopPick(w, w.options, function(t)
        local action = 0
        for _, f in ipairs(Fights(w)) do
            local d = Dist(t, f)
            if d and d <= FIGHT_RADIUS then for _, k in pairs(f.kills) do action = action + k end end
        end
        local f = flags[t.keepId]
        if f then action = action + f.moving * 6 + f.lost * 4 end
        if w.UnderAttack(t.keepId) then action = action + 8 end
        for _, a in ipairs({ AD, EP, DC }) do action = action + 2 * Sieges(w, t, a) end
        if action == 0 then return nil end
        local d = Away(w, t)
        return action - (d and 10 * d or 0)
    end, 3)
    return { pick = pick or OneOf(w, w.options) }
end

-- Display order and names for the menu and the wheel.
P.ORDER = { "lazy", "bored", "chris", "confessor", "deano", "diil", "greedy", "mulliss", "november", "selfish", "ultralazy" } -- Lazy, then A to Z
P.NAMES = {
    lazy = "Lazy", bored = "Bored", selfish = "Selfish", ultralazy = "Ultra Lazy", chris = "Chris", greedy = "Greedy",
    november = "November", confessor = "Confessor", deano = "Deano", mulliss = "Mulliss", diil = "Diil",
}
P.TOOLTIPS = {
    lazy = "A lazy crown isn't always a lousy one.",
    bored = "Bored. Chases fights and action.",
    selfish = "Looking out for number one. When you're crown you can make a whole group do your quests for you. Haha suckers.",
    ultralazy = "Laziest crown ever.",
    chris = "Lazy but with a brain. Top 10 AD player according to one of the worst players of all time. Hey now.",
    greedy = "Give me all that AP. All we do is win, win, win. (If we get there on time, ha... HURRY UP)",
    november = "Unconventional and favors flanks. Will do progressively trollier and unhinged things with accumulating losses.",
    confessor = "Lazy as in not taking us all to our certain deaths.",
    deano = "Scrappy small scale with a hint of troll and a penchant for grudges.",
    mulliss = "Sometimes you just want to be a bad crown so you don't have to do this anymore. Use this if you want to randomly pass the crown to someone else in the middle of a run and go back to harvesting your runestones in peace.",
    diil = "The real Diil, but I'm too lazy to siege for you. Do it yourself.",
}
-- Old saved names.
P.RENAMED = { elves = "selfish", clever = "chris" }
-- Which personalities need map positions (the plain Lazy pick doesn't).
P.NEEDS_MAP = { lazy = true, bored = true, selfish = true, ultralazy = true, chris = true, greedy = true, november = true, confessor = true, deano = true, mulliss = true, diil = true }
-- Who follows the hammer, and when (see FollowHammer). Diil and Greedy check it
-- themselves, after their emperor keeps (Selfish after its quests, then as
-- Greedy); everyone else checks it first.
P.HAMMER = {
    lazy = "ours", ultralazy = "ours", november = "ours", deano = "ours", greedy = "always", selfish = "always", bored = "always",
    chris = "safe", confessor = "safe", mulliss = "safe", diil = "safe",
}
for key, rule in pairs(P.HAMMER) do
    local choose = P[key]
    if key ~= "diil" and key ~= "greedy" and key ~= "selfish" then
        P[key] = function(w) return FollowHammer(w, rule) or choose(w) end
    end
end

-- The end line on every call while we're on a losing streak (3 or more L's in a
-- row): the crown's own picks, the hammer, and the plain pick alike.
P.StreakTail = function(key, mine)
    if key == "chris" then
        return string.format("%s we are on a losing streak. It's not Chris AI's fault. It's Mulliss' fault.", ALLIANCE_SHORT[mine] or "Dominion")
    elseif key == "confessor" then
        return "My train is pulling into the station think I need to go to bed with this many L's."
    end
end

-- Crowns that size up the group first: no outposts under 4 players, no keeps under 6.
P.GROUP_SIZED = { selfish = true, chris = true, greedy = true, confessor = true, mulliss = true }
P.MIN_GROUP = { Outpost = 4, Keep = 6 }
-- Crowns that skip the Nikel lines and sgx's Blue Road line.
P.SKIP_NIKEL_SGX = { deano = true, november = true, diil = true }
-- How each crown words its call (see VOICES in LazyCrown.lua). Anyone not
-- listed (Greedy) doth declare.
P.VOICES = {
    lazy = "guess", ultralazy = "guess", bored = "guess",
    chris = "alright", selfish = "alright", november = "alright", diil = "alright",
    deano = "letsgo", mulliss = "letsgo", confessor = "letsgo",
}

-- For tests.
P._internal = { OnTheWay = OnTheWay, Dist = Dist, FightAt = FightAt, ScrollGuard = ScrollGuard, LastEmperorKeep = LastEmperorKeep,
    ContinuousAttack = ContinuousAttack, QuestTargets = QuestTargets, StrategyScore = StrategyScore, SCROLLS = SCROLLS, WINGS = WINGS,
    TROLL_CALLS = TROLL_CALLS, Flags = Flags, GuardThrone = GuardThrone, FollowHammer = FollowHammer, Scrolls = Scrolls, EmperorAlliance = EmperorAlliance, RaidValues = RaidValues, HaveColor = HaveColor }
