local ADDON_NAME = "LazyCrown"
local VERSION = "0.1.1"
local AUTHOR = "absolventR3M"
local TEXT_COLOR = "F2C65A" -- crown gold
local DIAG_COLOR = "9A9A9A" -- grey status lines

-- Two wheel entries, two different crown icons. The game is asked for its own
-- currency icons at load; these paths are the fallback.
local ICON_PICK_FALLBACK = "EsoUI/Art/currency/gamepad/gp_crown_gems.dds"  -- Private Command: just for you
local ICON_SHARE_FALLBACK = "EsoUI/Art/currency/gamepad/gp_crowns.dds"      -- Crown Command: your call-out
local ICON_SCOREBOARD = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_leaderBoards.dds" -- Scoreboard
local ICON_RESET = "EsoUI/Art/Guild/Gamepad/gp_guild_options_delete.dds"                -- Reset Scoreboard
local ICON_PERSONALITY = "EsoUI/Art/Campaign/Gamepad/gp_bonusIcon_emperor.dds"          -- Change Personality
local ICON_GROUP = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_groups.dds"             -- Group Check

local AD, EP, DC = ALLIANCE_ALDMERI_DOMINION or 1, ALLIANCE_EBONHEART_PACT or 2, ALLIANCE_DAGGERFALL_COVENANT or 3
-- Numbers rotate through the alliances in this order: 1 = AD, 2 = EP, 3 = DC, 4 = AD, ...
local ROTATION = { AD, EP, DC }
local ALLIANCE_NAMES = { [AD] = "Aldmeri Dominion", [EP] = "Ebonheart Pact", [DC] = "Daggerfall Covenant" }

-- Personalities live in Personalities.lua (loaded after this file).
local function Personalities()
    return LazyCrown and LazyCrown.Personalities
end

-- The 18 Cyrodiil keeps by keep ID, grouped by the alliance whose side of the
-- map they start on. Names are only a fallback; the game's own (localized)
-- name is shown when it can be read.
local HOME_KEEPS = {
    [AD] = {
        { id = 15, name = "Castle Alessia" }, { id = 16, name = "Castle Faregyl" },
        { id = 17, name = "Castle Roebeck" }, { id = 18, name = "Castle Brindle" },
        { id = 19, name = "Castle Black Boot" }, { id = 20, name = "Castle Bloodmayne" },
    },
    [EP] = {
        { id = 9, name = "Chalman Keep" }, { id = 10, name = "Arrius Keep" },
        { id = 11, name = "Kingscrest Keep" }, { id = 12, name = "Farragut Keep" },
        { id = 13, name = "Blue Road Keep" }, { id = 14, name = "Drakelowe Keep" },
    },
    [DC] = {
        { id = 3, name = "Fort Warden" }, { id = 4, name = "Fort Rayles" },
        { id = 5, name = "Fort Glademist" }, { id = 6, name = "Fort Ash" },
        { id = 7, name = "Fort Aleswell" }, { id = 8, name = "Fort Dragonclaw" },
    },
}

-- Each alliance's two gate keeps (by its home gates).
local GATE_KEEPS = { [AD] = { [19] = true, [20] = true }, [EP] = { [11] = true, [12] = true }, [DC] = { [3] = true, [4] = true } }

-- Each keep is followed by its three resources, in this order.
local KEEP_PARTS = {
    { label = "Keep" },
    { label = "Lumbermill", resource = RESOURCETYPE_WOOD or 1 },
    { label = "Farm", resource = RESOURCETYPE_FOOD or 2 },
    { label = "Mine", resource = RESOURCETYPE_ORE or 3 },
}

-- Towns (73-75), then outposts (76-81), continuing the AD, EP, DC rotation.
-- Each is listed under the alliance whose part of the map it sits in.
local TOWNS = {
    { id = 149, name = "Vlastarus", home = AD },
    { id = 152, name = "Cropsford", home = EP },
    { id = 151, name = "Bruma", home = DC },
}
local OUTPOSTS = {
    { id = 132, name = "Nikel Outpost", home = AD },
    { id = 133, name = "Sejanus Outpost", home = EP },
    { id = 134, name = "Bleaker's Outpost", home = DC },
    { id = 164, name = "Carmala Outpost", home = AD },
    { id = 165, name = "Harlun's Outpost", home = EP },
    { id = 163, name = "Winter's Peak Outpost", home = DC },
}

local Random = zo_random or math.random

-- Button names in help text: Xbox names in the source, PlayStation names on PlayStation.
local PS_BUTTONS = { ["Press X"] = "Press Square", ["press X"] = "press Square", ["Press A"] = "Press Cross",
    ["LT or RT"] = "L2 or R2", ["Hit start"] = "Hit Options" }
local function Buttons(text)
    local ps = false
    if ZO_IsPlaystationPlatform then
        local ok, result = pcall(ZO_IsPlaystationPlatform)
        ps = ok and result == true
    end
    if not ps then return text end
    for xbox, playstation in pairs(PS_BUTTONS) do text = text:gsub(xbox, playstation) end
    return text
end

-- "[Lazy Crown - Chris] ": who's wearing the crown goes on every line (set once
-- the personalities are known, below).
local CrownName = function() return "Lazy" end
local function Tag()
    return string.format("[Lazy Crown - %s] ", CrownName())
end

local function Say(text)
    CHAT_ROUTER:AddSystemMessage(string.format("|c%s%s%s|r", TEXT_COLOR, Tag(), text))
end

local function Diag(text)
    CHAT_ROUTER:AddSystemMessage(string.format("|c%s%s%s|r", DIAG_COLOR, Tag(), text))
end

local function Context()
    return BGQUERY_LOCAL or 1
end

local function KeepName(keepId, fallback)
    local ok, name = pcall(GetKeepName, keepId)
    if ok and type(name) == "string" and name ~= "" then
        -- Same format the game uses for keep names (it differs in German and Spanish).
        return (zo_strformat and zo_strformat(SI_TOOLTIP_KEEP_NAME or "<<1>>", name)) or name
    end
    return fallback
end

local function PinPosition(keepId)
    local ok, _, x, y = pcall(GetKeepPinInfo, keepId, Context())
    if ok and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
        return x, y
    end
end

-- True when the game agrees the ID is the expected kind of target (or can't say).
local function IsKeepType(keepId, expected)
    if not (expected and GetKeepType) then return true end
    local ok, keepType = pcall(GetKeepType, keepId)
    return ok and keepType == expected
end

-- Builds the numbered list: keep 1 of each alliance (AD, EP, DC), then each
-- of their lumbermills, farms and mines, then keep 2, and so on; then the
-- three towns, then the six outposts. Every number moves to the next alliance.
-- Numbers are fixed: a target the game doesn't report is skipped, never renumbered.
local function BuildTargets()
    local targets = {}
    local number = 0
    local function add(keepId, name, kind, home, expectedType, parent)
        number = number + 1
        if keepId and IsKeepType(keepId, expectedType) then
            table.insert(targets, { number = number, keepId = keepId, name = KeepName(keepId, name), kind = kind, home = home, parent = parent })
        end
    end

    for i = 1, 6 do
        for _, part in ipairs(KEEP_PARTS) do
            for _, alliance in ipairs(ROTATION) do
                local keep = HOME_KEEPS[alliance][i]
                if part.resource then
                    local ok, resId = pcall(GetResourceKeepForKeep, keep.id, part.resource)
                    if not (ok and type(resId) == "number" and resId > 0) then resId = nil end
                    add(resId, keep.name .. " " .. part.label, part.label, alliance, KEEPTYPE_RESOURCE, keep.id)
                else
                    add(keep.id, keep.name, part.label, alliance, KEEPTYPE_KEEP)
                end
            end
        end
    end
    for _, town in ipairs(TOWNS) do add(town.id, town.name, "Town", town.home, KEEPTYPE_TOWN) end
    for _, outpost in ipairs(OUTPOSTS) do add(outpost.id, outpost.name, "Outpost", outpost.home, KEEPTYPE_OUTPOST) end
    return targets, number
end

-- Cyrodiil only: not Imperial City, battlegrounds or Jerall Pass (its keeps differ).
local function InCyrodiil()
    if IsInCyrodiil then
        if not IsInCyrodiil() then return false end
    elseif IsPlayerInAvAWorld and not IsPlayerInAvAWorld() then
        return false
    end
    if IsInImperialCity and IsInImperialCity() then return false end
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then return false end
    return true
end

-- Every command and wheel entry says this outside Cyrodiil and does nothing else.
local NOT_IN_CYRODIIL = "Looks like you're not in Grayhost, which means I don't have to try right now. Sweet."

-- Wraps a command so it only runs in Cyrodiil.
local function CyrodiilOnly(fn)
    return function(...)
        if not InCyrodiil() then
            Say(NOT_IN_CYRODIIL)
            return nil
        end
        return fn(...)
    end
end

local function MapChanged()
    if CALLBACK_MANAGER then CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") end
end

-- Keep pins and the waypoint must be read on the whole Cyrodiil map, not on
-- whatever smaller map the player is standing in (the alliance gates have
-- their own). This is how the game's own "show keep on map" does it.
-- Returns true when it switched maps, so the caller can switch back.
local function UseCyrodiilMap()
    if not (GetCyrodiilMapIndex and SetMapToMapListIndex) then return false end
    local ok, changed = pcall(function()
        if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then
            return false
        end
        local index = GetCyrodiilMapIndex()
        if not index or (GetCurrentMapIndex and GetCurrentMapIndex() == index) then return false end
        if SetMapToMapListIndex(index) == SET_MAP_RESULT_MAP_CHANGED then
            pcall(MapChanged) -- a listener failing must not stop us switching back
            return true
        end
        return false
    end)
    return ok and changed
end

local function RestorePlayerMap()
    pcall(function()
        if SetMapToPlayerLocation and SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then MapChanged() end
    end)
end

-- Runs fn on the Cyrodiil map (when it needs map positions), then puts the
-- player's map back.
local function OnCyrodiilMap(fn, needMap)
    local switched = needMap ~= false and UseCyrodiilMap()
    local ok, result = pcall(fn)
    if switched then RestorePlayerMap() end
    if not ok then
        Diag("Something went wrong: " .. tostring(result))
        return nil
    end
    return result
end

local function SetWaypoint(keepId)
    local x, y = PinPosition(keepId)
    if not (x and PingMap and MAP_PIN_TYPE_PLAYER_WAYPOINT) then return false end
    return (pcall(PingMap, MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, y))
end

-- Only keeps and outposts we hold can be called for defense.
local DEFENDABLE = { Keep = true, Outpost = true }
-- Riding speed, measured in game: Vlastarus to Castle Brindle (0.122 of the map,
-- about 1.2 km) took 66 seconds at full sprint, no Continuous Attack. So 0.01 of
-- the map is about 5.4 seconds.
local FLAGGED_RESOURCE_SECONDS = 32 -- about 600 m of riding

-- Target types any crown may pick (Options, all on by default). Each crown
-- picks the way it does from whatever is switched on.
local KIND_SETTING = { Keep = "pickKeeps", Lumbermill = "pickResources", Farm = "pickResources", Mine = "pickResources",
    Town = "pickTowns", Outpost = "pickOutposts" }

local function UnderAttack(keepId)
    local ok, underAttack = pcall(GetKeepUnderAttack, keepId, Context())
    return ok and underAttack == true
end

local lastKeepId = nil
local lastType = nil -- the last call's target type, so a random pick moves on to another

-- A target's type for random picks: keep, resource, town or outpost.
local function TypeOf(t)
    if t.parent then return "resource" end
    return t.kind
end

-- Every random pick (the plain Lazy pick and every crown's): each type is as
-- likely as the next, however many targets it has (54 resources, 3 towns).
-- First a type, never the last call's when there's another, then one target
-- of that type. w needs Random and lastType.
local function OneOf(w, list)
    if #list == 0 then return nil end
    local byType, types = {}, {}
    for _, t in ipairs(list) do
        local kind = TypeOf(t)
        if not byType[kind] then byType[kind] = {}; table.insert(types, kind) end
        table.insert(byType[kind], t)
    end
    if #types > 1 and w.lastType and byType[w.lastType] then
        for i, kind in ipairs(types) do if kind == w.lastType then table.remove(types, i) break end end
    end
    local group = byType[types[w.Random(1, #types)]]
    return group[w.Random(1, #group)]
end


-- Scoreboard (W/L record) ------------------------------------------------------
-- The last call is checked when the next one is made, never on a timer:
--   take:   W if it's ours by then, otherwise L.
--   defend: W if it's still ours and the attack is over, L if it fell.
-- It doesn't count if the next call comes within 90 seconds ("nah, roll
-- again"), while a defense is still going, or in a different campaign.
-- The scoreboard keeps going (across personalities and sessions) until the
-- player resets it.
local VOID_SECONDS = 90
local sv = { lifetime = {} } -- replaced by saved variables at load

local function PersonalityKey()
    local P = Personalities()
    if P and P.NAMES[sv.personality] then return sv.personality end
    return "lazy"
end

local function PersonalityName()
    local P = Personalities()
    return (P and P.NAMES[PersonalityKey()]) or "Lazy"
end
CrownName = PersonalityName

local function Now()
    return (GetTimeStamp and GetTimeStamp()) or os.time()
end

local function Since(stamp)
    if GetDiffBetweenTimeStamps then return GetDiffBetweenTimeStamps(Now(), stamp) end
    return Now() - stamp
end

local function Night()
    local night = sv.night
    if not night then
        night = { startedAt = Now(), lastAt = Now(), w = 0, l = 0, void = 0, targets = {}, lossesBy = {} }
        sv.night = night
    end
    return night
end

local function Tally(night)
    return string.format("%dW %dL", night.w, night.l)
end

local function SaveSoon()
    pcall(function() GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(ADDON_NAME) end)
end

-- against: the alliance behind an L (held what we couldn't take, or took
-- what we were defending).
local function Settle(result, why, against)
    local call = sv.open
    if not call then return end
    sv.open = nil
    local night = Night()
    night.lossesBy = night.lossesBy or {}
    sv.lastResult = result -- any result, for Mean mode's "last call"
    if result ~= "void" then
        -- The last decided call, and the losing streak (who it's against): what November remembers.
        sv.lastDecided, sv.lastDecidedCall = result, { keepId = call.keepId, result = result, against = against }
        if result == "W" then
            sv.streakL, sv.streakBy = 0, {}
        else
            sv.streakL = (sv.streakL or 0) + 1
            sv.streakBy = sv.streakBy or {}
            if ALLIANCE_NAMES[against] then sv.streakBy[tostring(against)] = (sv.streakBy[tostring(against)] or 0) + 1 end
        end
    end
    if result == "void" then
        night.void = night.void + 1
        -- A quick reroll needs no note; the other reasons do.
        if why then Diag(string.format("Last call (%s) doesn't count: %s.", call.name, why)) end
        return
    end
    local won = result == "W"
    local key = tostring(call.keepId)
    local t = night.targets[key] or { name = call.name, w = 0, l = 0 }
    night.targets[key] = t
    local life = sv.lifetime[key] or { w = 0, l = 0 }
    sv.lifetime[key] = life
    if won then
        night.w, t.w, life.w = night.w + 1, t.w + 1, life.w + 1
    else
        night.l, t.l, life.l = night.l + 1, t.l + 1, life.l + 1
        if ALLIANCE_NAMES[against] then
            local key = tostring(against)
            night.lossesBy[key] = (night.lossesBy[key] or 0) + 1
        end
    end
    local what = call.defend and (won and "held" or "lost") or (won and "taken" or "not taken")
    Say(string.format("%s! %s %s. Scoreboard: %s.", won and "W" or "L", call.name, what, Tally(night)))
    SaveSoon()
end

-- A campaign ID of 0 means "not known yet", never a different campaign.
local function CampaignChanged(call)
    if not (GetCurrentCampaignId and call.campaignId and call.campaignId ~= 0) then return false end
    local now = GetCurrentCampaignId()
    return now ~= nil and now ~= 0 and now ~= call.campaignId
end

-- Checks the last call when the next one is made.
-- Where you are on the current map, or nil.
local function PlayerSpot()
    local ok, x, y, _, shown = pcall(GetMapPlayerPosition, "player")
    if ok and type(x) == "number" and type(y) == "number" and shown ~= false and (x ~= 0 or y ~= 0) then return { x = x, y = y } end
end

-- Farther than this from the last call's target at the next call (about 160
-- seconds of riding) and you didn't go: it doesn't count, W or L. Otherwise
-- skipped calls pile up as L's and push November up its ladder.
local WENT_THERE = 0.3

local function FarFrom(keepId, where)
    if not where then return false end
    local x, y = PinPosition(keepId)
    if not (x and y) or (x == 0 and y == 0) then return false end
    local dx, dy = x - where.x, y - where.y
    return math.sqrt(dx * dx + dy * dy) > WENT_THERE
end

local function SettleLastCall(where)
    local call = sv.open
    if not call then return end
    if CampaignChanged(call) then
        Settle("void", "different campaign")
        return
    end
    local ok, owner = pcall(GetKeepAlliance, call.keepId, Context())
    if not (ok and ALLIANCE_NAMES[owner]) then
        Settle("void", "the map was still loading")
        return
    end
    local ours = owner == call.alliance
    local quick = Since(call.at) < VOID_SECONDS
    if FarFrom(call.keepId, where) then
        if quick then Settle("void") else Settle("void", "you weren't anywhere near it") end
        return
    end
    if call.defend then
        if not ours then Settle("L", nil, owner)
        elseif UnderAttack(call.keepId) then Settle("void", "still under attack")
        elseif quick then Settle("void")
        else Settle("W") end
    else
        if ours then Settle("W")
        elseif quick then Settle("void")
        else Settle("L", nil, owner) end
    end
end

local function OpenCall(pick, mine)
    local night = Night()
    night.lastAt = Now()
    sv.open = {
        keepId = pick.keepId, number = pick.number, name = pick.name, defend = pick.defend or nil,
        alliance = mine, at = Now(), campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or nil,
    }
end

local function IsLocalEvent(ctx)
    return not IsLocalBattlegroundContext or IsLocalBattlegroundContext(ctx)
end

-- When each keep last changed hands this session (Chris looks for weak walls).
local flippedAt = {}

local function OnKeepOwnerChanged(_, keepId, ctx, owningAlliance, oldOwningAlliance)
    if IsLocalEvent(ctx) and owningAlliance ~= oldOwningAlliance and ALLIANCE_NAMES[owningAlliance] then
        flippedAt[keepId] = Now()
    end
end

local function BestCall(night)
    local best
    for _, t in pairs(night.targets) do
        if t.w > 0 and (not best or t.w > best.w or (t.w == best.w and t.l < best.l)) then best = t end
    end
    return best
end

-- The alliance (or alliances, on a tie) behind the most L's.
local function LazierAlliance(night)
    local most, names = 0, {}
    for _, alliance in ipairs(ROTATION) do
        local n = (night.lossesBy or {})[tostring(alliance)] or 0
        if n > most then most, names = n, { ALLIANCE_NAMES[alliance] }
        elseif n == most and n > 0 then table.insert(names, ALLIANCE_NAMES[alliance]) end
    end
    if #names == 0 then return nil end
    return table.concat(names, " and ")
end

-- One line for chat:
-- "Scoreboard: 7W 3L. Best call: Fort Ash 3-0. Alliance that made me even lazier: Ebonheart Pact."
-- (The tag in front already names the crown.)
local function SummaryLine()
    local night = Night()
    local best = BestCall(night)
    local lazier = LazierAlliance(night)
    return string.format("Scoreboard: %s.%s%s", Tally(night),
        best and string.format(" Best call: %s %d-%d.", best.name, best.w, best.l) or "",
        lazier and string.format(" Alliance that made me even lazier: %s.", lazier) or "")
end

-- Redraws the settings rows if the Lazy Crown panel is open (chat is hidden there).
local function RefreshSettings()
    pcall(function()
        local lib = LibHarvensAddonSettings
        if lib and lib.list and lib.list.RefreshVisible then lib.list:RefreshVisible() end
    end)
end

local function ResetScoreboard()
    sv.night, sv.open, sv.lastResult, sv.lastDecided, sv.lastDecidedCall, sv.streakL, sv.streakBy = nil, nil, nil, nil, nil, 0, {}
    SaveSoon()
    Say("Scoreboard reset.")
    RefreshSettings()
end

-- Rolls a target and prints it to the player's own chat window. Returns the
-- shareable line (without the prefix) or nil when there is nothing to share.
-- A few targets get an extra line after the call.
local FORT_ASH, BLUE_ROAD, BRUMA, NIKEL = 6, 13, 151, 132

local function Extra(pick, mine)
    if pick.keepId == FORT_ASH then return "Ash till you crash." end
    -- Some crowns skip the Nikel lines and sgx's Blue Road line.
    local P = Personalities()
    local skip = P and P.SKIP_NIKEL_SGX and P.SKIP_NIKEL_SGX[PersonalityKey()]
    if pick.keepId == NIKEL and not skip then
        return pick.defend and "We're gonna protect Nikel's pickle from tickling." or "We're gonna tickle Nikel's pickle."
    end
    if pick.keepId == BLUE_ROAD and not skip then return "And don't forget sgx says the mine side is cursed." end
    if pick.keepId == BRUMA then return "Bruma is the key to the whole map guys." end
    -- Our own gate keeps, whether we're defending one or taking it back.
    if GATE_KEEPS[mine] and GATE_KEEPS[mine][pick.keepId] then return "I guess we gotta go bail out the alliance ugh." end
end

-- How each crown talks (Personalities.lua says who uses which). %s is the
-- target, or "A, then B" for a chain; a directed call fills in what to do.
local VOICES = {
    declare = { attack = "The crown doth declare an attack on %s.", defend = "The crown doth declare the defense of %s.",
        directive = "The crown doth declare: %s." },
    guess = { attack = "I guess we should hit %s.", defend = "I guess we should defend %s.",
        directive = "I guess we should %s." },
    alright = { attack = "Alright, we are going to hit %s.", defend = "Alright, we are going to defend %s.",
        directive = "Alright, we are going to %s." },
    letsgo = { attack = "Let's go take %s.", defend = "Let's go defend %s.",
        directive = "Let's %s." },
}

local function Voice()
    local P = Personalities()
    return VOICES[P and P.VOICES and P.VOICES[PersonalityKey()] or "declare"] or VOICES.declare
end

-- The call itself, as shown in chat and pasted by Crown Command. A chain
-- lists more legs after the first ("an attack on A, then B"); a directed call
-- says exactly what to do ("troll Ash by sieging from the lumbermill tower").
-- Mean replaces every crown's wording with its own.
local function CallLine(pick, mine, chain, extras, tail)
    local legs = { pick.name }
    for _, leg in ipairs(chain or {}) do table.insert(legs, leg.name) end
    local where = table.concat(legs, ", then ")
    local line
    if not sv.mean then
        local voice = Voice()
        if pick.directive then line = string.format(voice.directive, pick.directive)
        elseif pick.defend then line = string.format(voice.defend, where)
        else line = string.format(voice.attack, where) end
    else
        local what = pick.directive or string.format("%s %s", pick.defend and "defend" or "attack", where)
        line = string.format("you're going to %s and you're gonna like it.", what)
        if sv.lastResult == "W" then
            line = "I'd say congrats on that W but I'm too lazy. And mean. Anyways, " .. line
        else
            line = line:gsub("^y", "Y")
            if sv.lastResult == "L" then line = "Wow losers... " .. line end
        end
    end
    -- The personality's own lines, then the target's, then anything for the very end.
    for _, more in ipairs(extras or {}) do line = line .. " " .. more end
    local extra = Extra(pick, mine)
    for _, leg in ipairs(chain or {}) do extra = extra or Extra(leg, mine) end
    if extra then line = line .. " " .. extra end
    for _, more in ipairs(tail or {}) do line = line .. " " .. more end
    return line
end

-- What the personalities get to look at (see Personalities.lua).
local function BuildWorld(mine, options, targets, withPositions)
    local world = {
        mine = mine, options = options, targets = targets, byId = {}, ctx = Context(),
        campaignId = (GetCurrentCampaignId and GetCurrentCampaignId()) or 0,
        Random = Random, UnderAttack = UnderAttack,
        FlippedAgo = function(keepId) return flippedAt[keepId] and Since(flippedAt[keepId]) end,
        Allied = function(alliance) return ALLIANCE_NAMES[alliance] ~= nil end,
        KindOn = function(kind) return sv[KIND_SETTING[kind] or ""] ~= false end,
        lifetime = sv.lifetime or {}, lastResult = sv.lastDecided, lastCall = sv.lastDecidedCall,
        streakL = sv.streakL or 0, streakBy = sv.streakBy or {},
        memory = sv.memory,
    }
    if type(world.memory) ~= "table" then
        sv.memory = {}
        world.memory = sv.memory
    end
    for _, t in ipairs(targets) do world.byId[t.keepId] = t end
    if withPositions then
        for _, t in ipairs(targets) do t.x, t.y = PinPosition(t.keepId) end
        local ok, x, y, _, shown = pcall(GetMapPlayerPosition, "player")
        if ok and type(x) == "number" and type(y) == "number" and shown ~= false and (x ~= 0 or y ~= 0) then
            world.player = { x = x, y = y }
        end
    end
    return world
end

local function PickTarget()
    if not InCyrodiil() then
        Say(NOT_IN_CYRODIIL)
        return nil
    end
    local wantWaypoint = sv.waypoint == true
    local personality = PersonalityKey()
    local P = Personalities()
    local needMap = wantWaypoint or (P and P.NEEDS_MAP[personality]) or false
    return OnCyrodiilMap(function()
        SettleLastCall(PlayerSpot())
        local mine = GetUnitAlliance("player")
        local targets = BuildTargets()

        -- Everything we don't hold, plus our keeps and outposts under attack.
        -- A random pick gives each target type the same chance (OneOf).
        -- Every target always belongs to an alliance; no owner means the map is still loading.
        local options, loading = {}, 0
        for _, t in ipairs(targets) do
            local ok, owner = pcall(GetKeepAlliance, t.keepId, Context())
            if ok then t.owner = owner end
            if ok and not ALLIANCE_NAMES[owner] then
                loading = loading + 1
            elseif ok and owner ~= mine then
                t.owner, t.defend = owner, false
                table.insert(options, t)
            elseif ok and DEFENDABLE[t.kind] and UnderAttack(t.keepId) then
                t.owner, t.defend = owner, true
                table.insert(options, t)
            end
        end

        if #options == 0 then
            if loading > 0 then
                Diag("The map is still loading. Try again in a moment.")
            else
                Say("We already own everything and nothing is under attack. Go touch grass.")
            end
            return nil
        end

        -- The target types switched off in Options are out for every crown.
        local switchedOn = {}
        for _, t in ipairs(options) do
            if sv[KIND_SETTING[t.kind] or ""] ~= false then table.insert(switchedOn, t) end
        end
        if #switchedOn == 0 then
            Say("Nothing to pick with those target types switched off. Turn some back on in Options.")
            return nil
        end
        options = switchedOn

        -- How long it takes to get anywhere: riding, by transitus or with a
        -- recall stone (Travel.lua).
        local travel
        if needMap and LazyCrown.Travel then
            for _, t in ipairs(targets) do t.x, t.y = PinPosition(t.keepId) end
            local okP, px, py, _, shown = pcall(GetMapPlayerPosition, "player")
            if okP and type(px) == "number" and type(py) == "number" and shown ~= false and (px ~= 0 or py ~= 0) then
                local okT, route = pcall(LazyCrown.Travel.New, mine, Context(), { x = px, y = py }, targets, KeepName)
                if okT then travel = route end
            end
        end

        -- A resource that's already flagged flips before a group can get there:
        -- only call one you can reach in time (unless that leaves nothing).
        if travel then
            local reachable = {}
            for _, t in ipairs(options) do
                local tooLate = false
                if (t.kind == "Lumbermill" or t.kind == "Farm" or t.kind == "Mine") and UnderAttack(t.keepId) then
                    local leg = travel(t)
                    tooLate = leg ~= nil and leg.seconds > FLAGGED_RESOURCE_SECONDS
                end
                if not tooLate then table.insert(reachable, t) end
            end
            if #reachable > 0 then options = reachable end
        end

        -- Some crowns size up the group: no outposts or keeps for a group too
        -- small to take them, ever.
        local G = LazyCrown.Group
        if P and P.GROUP_SIZED and P.GROUP_SIZED[personality] and G then
            local ok, size = pcall(G.Size)
            if ok and size then
                local fits = {}
                for _, t in ipairs(options) do
                    if size >= (P.MIN_GROUP[t.kind] or 0) then table.insert(fits, t) end
                end
                options = fits
            end
        end

        -- Don't hand out the same target twice in a row if there is any choice.
        -- (A crown can still see everything; November's grudge does.)
        local everything = { unpack(options) }
        if #options > 1 and lastKeepId then
            for i, t in ipairs(options) do
                if t.keepId == lastKeepId then table.remove(options, i) break end
            end
        end

        -- The personality decides; if it has nothing to say, the plain Lazy pick does.
        local plan
        local choose = P and P[personality]
        if choose then
            local world = BuildWorld(mine, options, targets, needMap)
            world.everything = everything
            world.lastType = lastType
            -- Distance as travel time (map units), counting transitus and recall stones.
            if travel then
                world.Away = function(t)
                    local leg = travel(t)
                    return leg and leg.seconds / LazyCrown.Travel.SECONDS_PER_UNIT
                end
            end
            local ok, result = pcall(choose, world)
            if ok and type(result) == "table" and result.pick then plan = result end
        end
        local pick = plan and plan.pick
        if not pick then
            if #options == 0 then
                Say("Not enough of you here for what's left. Outposts need 4, keeps need 6.")
                return nil
            end
            -- The plain Lazy pick: each target type as likely as the next.
            pick = OneOf({ Random = Random, lastType = lastType }, options)
        end
        local chain = plan and plan.chain or nil
        lastKeepId = pick.keepId
        lastType = TypeOf(pick)
        -- How to get there goes right after the call: a shortcut worth taking,
        -- or which way to ride.
        local extras = plan and plan.extras
        local leg = travel and travel(pick)
        local how = leg and (leg.line or leg.ride)
        if how then
            extras = { how }
            for _, more in ipairs(plan and plan.extras or {}) do table.insert(extras, more) end
        end
        -- On a losing streak, some crowns end every call with a line of their own.
        local tail = plan and plan.tail
        local streakLine = (sv.streakL or 0) >= 3 and P and P.StreakTail and P.StreakTail(personality, mine)
        if streakLine then
            tail = { streakLine }
            for _, more in ipairs(plan and plan.tail or {}) do table.insert(tail, more) end
        end
        local line = CallLine(pick, mine, chain, extras, tail)
        Say(line)
        if not pick.unscored then OpenCall(pick, mine) end
        if wantWaypoint and SetWaypoint(pick.keepId) then
            Diag("Waypoint set on your map.")
        end
        return line
    end, needMap)
end

-- Sharing works like H8 Ball: add-ons can't send chat, so the line goes into
-- the full-screen Chat page's text box (scene "gamepadChatMenu") and the
-- player presses its own Send button. See the README for why each rule here
-- exists.
local CHAT_MENU_SCENE = "gamepadChatMenu"
local pendingText = nil

-- Never build the full message here: the prefix and the line go in as two
-- pieces and the game joins them. Never focus the box from add-on code.
local function FillChatPageBox(line)
    local edit = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.textEdit
    if not edit then return false, "Chat page text box not found" end
    local ok, err = pcall(function()
        edit:SetText("")
        edit:InsertText(Tag())
        edit:InsertText(line)
    end)
    if not ok then return false, tostring(err) end
    return true
end

-- If an add-on was the first thing to open the Chat page this session, its
-- Send button is untrusted and refuses everything until Reload UI.
local function IsSendBlocked()
    local page = CHAT_MENU_GAMEPAD
    local desc = page and page.textInputAreaKeybindDescriptor
    if not (desc and IsTrustedFunction) then return false end
    for _, button in ipairs(desc) do
        if type(button) == "table" and type(button.callback) == "function" then
            local ok, trusted = pcall(IsTrustedFunction, button.callback)
            if ok and trusted == false then return true end
        end
    end
    return false
end

local function ReportFill(ok, err)
    if not ok then
        Diag("Could not paste: " .. tostring(err))
    elseif IsSendBlocked() then
        Diag(Buttons("Send is blocked this session. Reload UI, open Text Chat once, then pick again."))
    end
end

local function OnChatPageStateChange(oldState, newState)
    if newState == SCENE_SHOWN and pendingText then
        local text = pendingText
        pendingText = nil
        ReportFill(FillChatPageBox(text))
    end
end

local function PasteIntoChat(line)
    if not (SCENE_MANAGER and SCENE_MANAGER.IsShowing and zo_callLater) then
        Diag("Could not paste: chat page API missing")
        return
    end

    if SCENE_MANAGER:IsShowing(CHAT_MENU_SCENE) then
        -- Typed in Text Chat: Send empties the box right after us, so wait a frame.
        zo_callLater(function() ReportFill(FillChatPageBox(line)) end, 1)
        return
    end

    if not (CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.initialized) then
        Diag("Open Text Chat once (Main Menu > Text Chat), then pick again.")
        return
    end
    pendingText = line
    FillChatPageBox(line)
    local ok, err = pcall(SCENE_MANAGER.Show, SCENE_MANAGER, CHAT_MENU_SCENE)
    if not ok then
        pendingText = nil
        Diag("Could not open the Chat page: " .. tostring(err))
        return
    end
    zo_callLater(function()
        if pendingText ~= nil then
            pendingText = nil
            Diag("Chat page did not open within 3 seconds.")
        end
    end, 3000)
end

local function PickPrivately()
    PickTarget()
end

-- Checked before rolling, so a blocked Send never costs a call.
local function ChatReady()
    if not (SCENE_MANAGER and SCENE_MANAGER.IsShowing and zo_callLater) then
        Diag("Could not paste: chat page API missing")
        return false
    end
    if SCENE_MANAGER:IsShowing(CHAT_MENU_SCENE) or (CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.initialized) then
        if IsSendBlocked() then
            Diag(Buttons("Send is blocked this session. Reload UI, open Text Chat once, then pick again."))
            return false
        end
        return true
    end
    Diag("Open Text Chat once (Main Menu > Text Chat), then pick again.")
    return false
end

local function PickAndShare()
    if not (InCyrodiil() and ChatReady()) then
        if not InCyrodiil() then Say(NOT_IN_CYRODIIL) end
        return
    end
    local line = PickTarget()
    if line then PasteIntoChat(line) end
end

local function ShowScoreboard()
    Say(SummaryLine())
    if sv.open then Diag(string.format("Still calling: %s.", sv.open.name)) end
end

local function ShareScoreboard()
    local line = SummaryLine()
    Say(line)
    if ChatReady() then PasteIntoChat(line) end
end

local function ListTargets()
    local targets, total = BuildTargets()
    for _, t in ipairs(targets) do
        Diag(string.format("#%d %s (%s side)", t.number, t.name, ALLIANCE_NAMES[t.home] or "middle"))
    end
    if #targets < total then Diag(string.format("%d of %d targets found.", #targets, total)) end
end

-- /lazycrown scan: prints what the game reports, for in-game testing.
local CA_TIMED = { [39249] = true, [45617] = true }   -- Continuous Attack buff (add-on data)
local CA_PASSIVE = { [39248] = true, [45614] = true } -- the passive itself
local FLAG_STEPS = {}

local function Fmt(text)
    return (zo_strformat and zo_strformat("<<1>>", text)) or text
end

local function ScanTargets()
    local targets, total = BuildTargets()
    local found = {}
    for _, t in ipairs(targets) do found[t.number] = true end
    local missing = {}
    for n = 1, total do if not found[n] then table.insert(missing, n) end end
    Diag(string.format("Targets: %d of %d found.%s", #targets, total,
        #missing > 0 and (" Missing #" .. table.concat(missing, ", #")) or ""))
end

local function ScanFlags()
    if not (GetNumObjectives and GetObjectiveIdsForIndex and GetObjectiveType and OBJECTIVE_CAPTURE_AREA) then
        Diag("Flags: objective API missing.")
        return
    end
    if not next(FLAG_STEPS) then
        FLAG_STEPS[OBJECTIVE_CONTROL_STATE_AREA_MAX_CONTROL or -1] = "full"
        FLAG_STEPS[OBJECTIVE_CONTROL_STATE_AREA_ABOVE_CONTROL_THRESHOLD or -2] = "above half"
        FLAG_STEPS[OBJECTIVE_CONTROL_STATE_AREA_BELOW_CONTROL_THRESHOLD or -3] = "below half"
        FLAG_STEPS[OBJECTIVE_CONTROL_STATE_AREA_NO_CONTROL or -4] = "neutral"
    end
    local flags, moving, names, seen = 0, {}, {}, {}
    for i = 1, GetNumObjectives() do
        local keepId, objectiveId, ctx = GetObjectiveIdsForIndex(i)
        local isLocal = not IsLocalBattlegroundContext or IsLocalBattlegroundContext(ctx)
        if isLocal and GetObjectiveType(keepId, objectiveId, ctx) == OBJECTIVE_CAPTURE_AREA then
            flags = flags + 1
            local name = Fmt(GetObjectiveInfo(keepId, objectiveId, ctx) or "?")
            if not seen[name] then seen[name] = true; table.insert(names, name) end
            local state = GetObjectiveControlState and GetObjectiveControlState(keepId, objectiveId, ctx)
            if state ~= OBJECTIVE_CONTROL_STATE_AREA_MAX_CONTROL then
                local holder = GetCaptureAreaObjectiveOwner and GetCaptureAreaObjectiveOwner(keepId, objectiveId, ctx)
                table.insert(moving, string.format("%s %s: %s, held by %s", KeepName(keepId, "keep " .. keepId), name,
                    FLAG_STEPS[state] or ("state " .. tostring(state)), ALLIANCE_NAMES[holder] or "no one yet"))
            end
        end
    end
    Diag(string.format("Flags: %d found, %d not full. Names: %s", flags, #moving, table.concat(names, ", ", 1, math.min(#names, 10))))
    for i = 1, math.min(#moving, 4) do Diag("  " .. moving[i]) end
end

-- The same hammer the crowns see (Personalities.lua).
local function ScanHammer()
    local P = Personalities()
    local hammer = P and P.HammerNow and P.HammerNow()
    if not hammer then Diag("Hammer: not out.") return end
    Diag(string.format("Hammer: state %s, held by %s%s, pin %s", tostring(hammer.state), ALLIANCE_NAMES[hammer.holder] or "no one",
        hammer.withUs and " (your group)" or "", hammer.x and string.format("%.3f, %.3f", hammer.x, hammer.y) or "unknown"))
end

local SCROLL_NAMES = { [118] = "Altadoon", [119] = "Mnem", [120] = "Ghartok", [121] = "Chim", [122] = "Ni-Mohk", [123] = "Alma Ruma" }

local function ScanScrolls()
    local P = Personalities()
    if not (P and P.ScrollStates) then return end
    local parts = {}
    for _, s in ipairs(P.ScrollStates(Context())) do
        local where = s.home and "home" or (s.heldAt and ("in " .. KeepName(s.heldAt, "keep " .. s.heldAt)))
            or (s.x and string.format("out at %.3f, %.3f", s.x, s.y)) or "out"
        table.insert(parts, string.format("%s %s", SCROLL_NAMES[s.temple] or s.temple, where))
    end
    Diag("Scrolls: " .. table.concat(parts, "; "))
end

local function ScanBuffs()
    local found = {}
    local caName = GetAbilityName and Fmt(GetAbilityName(39249) or "")
    for i = 1, GetNumBuffs("player") do
        local name, _, ending, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if CA_TIMED[abilityId] or CA_PASSIVE[abilityId] or (caName ~= "" and Fmt(name or "") == caName) then
            local left = (ending or 0) - (GetFrameTimeSeconds and GetFrameTimeSeconds() or 0)
            table.insert(found, string.format("%s (id %s%s)", Fmt(name or "?"), tostring(abilityId),
                left > 0 and string.format(", %d:%02d left", math.floor(left / 60), math.floor(left % 60)) or ", no timer"))
        end
    end
    Diag("Continuous Attack: " .. (#found > 0 and table.concat(found, "; ") or "not on you"))
end

local function ScanQuests()
    local lines = {}
    local ava = { [QUEST_TYPE_AVA or -1] = true, [QUEST_TYPE_AVA_GROUP or -2] = true, [QUEST_TYPE_AVA_GRAND or -3] = true }
    for i = 1, MAX_JOURNAL_QUESTS or 25 do
        if IsValidQuestIndex(i) and ava[GetJournalQuestType(i)] then
            table.insert(lines, string.format("%d %s", GetJournalQuestId(i), Fmt(GetJournalQuestName(i) or "?")))
        end
    end
    Diag("AvA quests: " .. (#lines > 0 and table.concat(lines, "; ") or "none"))
end

local function ScanChat()
    local edit = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.textEdit
    local ok, limit = pcall(function() return edit:GetMaxInputChars() end)
    Diag("Chat box limit: " .. (ok and tostring(limit) or "unknown"))
end

local function Scan()
    Diag(string.format("Scan: v%s, campaign %s, Cyrodiil %s, map %s (Cyrodiil is %s)", VERSION,
        tostring(GetCurrentCampaignId and GetCurrentCampaignId()), tostring(InCyrodiil()),
        tostring(GetCurrentMapIndex and GetCurrentMapIndex()), tostring(GetCyrodiilMapIndex and GetCyrodiilMapIndex())))
    for _, step in ipairs({ ScanTargets, ScanFlags, ScanHammer, ScanScrolls, ScanBuffs, ScanQuests, ScanChat }) do
        local ok, err = pcall(step)
        if not ok then Diag("Scan step failed: " .. tostring(err)) end
    end
end

local HOW_TO_USE = "In Cyrodiil, pick from the addon quickslot wheel, or type /lazycrown in Text Chat. Lazy Crown randomly picks a keep, lumbermill, farm, mine, town or outpost your alliance doesn't hold, or one of your keeps or outposts that is under attack. Pick who's wearing the crown under Personalities. Functions: Private Command (crown gems): just for you, where to go shows in your chat window only. Crown Command (gold crown): your call-out, it also goes in the Text Chat box on the channel you last used. Note: If you have not opened chat yet, Lazy Crown will remind you to do this instead to prevent a UI error. Make sure you choose the right chat channel! Press X to send. Press A to edit or delete."
local WHEEL_SETUP = 'Hit start and go to the addons menu. Open LibRadialMenu settings. Ensure the wheel location is set to a value between 1 and 6. Pick a slot, choose Private Command. Pick more slots for Crown Command, Scoreboard, Reset Scoreboard, Change Personality and Group Check if you want them. Hit start to close the menu. Open your quickslot wheel by pressing up on the d-pad. Browse to Addon Entries using LT or RT, then pick! See "How to use" if this is your first time.'
local SCOREBOARD_HELP = "Every call is a W or an L, checked when you make your next call. Taking: W if it's yours by then, otherwise L. Defending: W if it's still yours and the attack is over, L if it fell. Picking again within 90 seconds, or while a defense is still going, doesn't count against the last call, unless it was a defense that already fell. A call you're nowhere near by your next call doesn't count either, W or L. Following the hammer doesn't count. The scoreboard keeps this run's record until you reset it, even if you change personalities. Scoreboard on the wheel places it in the Text Chat box."
local CHAT_COMMANDS = "Where typing in chat is available: /lazycrown picks a target for your chat window only. /lazycrown share is Crown Command: it also places the call in the Text Chat box. /lazycrown scoreboard shows the scoreboard, /lazycrown scoreboard share places it in the Text Chat box, and /lazycrown scoreboard reset resets it. /lazycrown personality puts the next personality on the crown, or /lazycrown personality chris (or any name) picks one. /lazycrown group shows your group size, roles and big ultimates. /lazycrown list shows every numbered target. /lazycrown scan prints what the game reports, for testing."

-- Puts a personality on, says so, and redraws the settings rows.
local function WearCrown(key)
    local P = Personalities()
    if not (P and P.NAMES[key]) then return end
    sv.personality = key
    Say(string.format("%s is wearing the crown now.", P.NAMES[key]))
    RefreshSettings()
end

-- Group Check: size, roles and the big ultimates, in your chat window.
-- Setting a wheel slot opens LibRadialMenu's dialog from add-on code, and after
-- that the campaign queue's Enter Now can throw a UI error until Reload UI. So
-- the first time you set one outside Cyrodiil, say so (in chat and on screen,
-- since chat is hidden in the menus).
local SLOT_WARNING = "Reload UI before you queue for Cyrodiil, or Enter Now can throw a UI error."

local function WatchSlotAssignments()
    local dialog = ESO_Dialogs and ESO_Dialogs["LibProfileAssignDialogue"]
    local assign = dialog and dialog.buttons and dialog.buttons[1]
    if not (assign and type(assign.callback) == "function") then return end
    local original, warned = assign.callback, false
    assign.callback = function(...)
        local result = original(...)
        if not warned and not InCyrodiil() then
            warned = true
            Diag(SLOT_WARNING)
            pcall(function()
                local alert = ZO_AlertNoSuppression or ZO_Alert
                if alert then alert(UI_ALERT_CATEGORY_ALERT, nil, Tag() .. SLOT_WARNING) end
            end)
        end
        return result
    end
end

local function GroupCheck()
    local G = LazyCrown.Group
    if not G then return end
    local t = G.Tally()
    Say(G.Line(t))
    if t.away > 0 then
        Diag(string.format("%d more in the group %s here.", t.away, t.away == 1 and "isn't" or "aren't"))
    end
    if t.size > 1 and not G.Sharing() then
        Diag("Only your own ultimates are counted. Install LibGroupCombatStats to see everyone's.")
    elseif t.sharing < t.size then
        Diag(string.format("Ultimates counted for %d of %d. The rest need LibGroupCombatStats with Lazy Crown, Hodor Reflexes or Artaeum Group Tool.",
            t.sharing, t.size))
    end
end

local function CyclePersonality()
    local P = Personalities()
    if not P then return end
    local current, order = PersonalityKey(), P.ORDER
    for i, key in ipairs(order) do
        if key == current then return WearCrown(order[i % #order + 1]) end
    end
    WearCrown(order[1])
end

-- Instructions panel under Main Menu > Add-Ons. Labels are one line on
-- console; the instructions go in the tooltip shown when a row is selected.
local function AddSettingsPanel()
    local lib = LibHarvensAddonSettings
    if not (lib and lib.AddAddon and lib.ST_LABEL and lib.ST_SECTION) then return end
    local panel = lib:AddAddon("Lazy Crown")
    panel.version = VERSION
    panel.author = AUTHOR
    local LABEL, SECTION, BUTTON, CHECKBOX = lib.ST_LABEL, lib.ST_SECTION, lib.ST_BUTTON or 6, lib.ST_CHECKBOX or 1
    local rows = {
        { type = SECTION, label = "General" },
        { type = LABEL, label = "How to use", tooltip = Buttons(HOW_TO_USE) },
        { type = LABEL, label = "Wheel setup", tooltip = Buttons(WHEEL_SETUP) },
        { type = LABEL, label = "Chat commands", tooltip = CHAT_COMMANDS },
    }
    -- One row per personality: its description, and press it to wear the crown.
    local P = Personalities()
    if P then
        table.insert(rows, { type = SECTION, label = "Personalities" })
        for _, key in ipairs(P.ORDER) do
            table.insert(rows, {
                type = BUTTON, buttonText = "Wear the crown", tooltip = P.TOOLTIPS[key],
                label = function() return P.NAMES[key] .. (PersonalityKey() == key and " (wearing the crown)" or "") end,
                clickHandler = function() WearCrown(key) end,
            })
        end
    end
    for _, row in ipairs({
        { type = SECTION, label = "Options" },
        { type = CHECKBOX, label = "Set a waypoint",
          tooltip = "Puts a waypoint on your map for every call.",
          getFunction = function() return sv.waypoint == true end,
          setFunction = function(on) sv.waypoint = on == true end, default = false },
        { type = CHECKBOX, label = "Mean",
          tooltip = "Same calls, worse attitude.",
          getFunction = function() return sv.mean == true end,
          setFunction = function(on) sv.mean = on == true end, default = false },
    }) do table.insert(rows, row) end
    for _, kind in ipairs({
        { "Keeps", "pickKeeps", "keeps" }, { "Resources", "pickResources", "lumbermills, farms and mines" },
        { "Towns", "pickTowns", "towns" }, { "Outposts", "pickOutposts", "outposts" },
    }) do
        local key = kind[2]
        table.insert(rows, { type = CHECKBOX, label = kind[1],
            tooltip = string.format("Lets the crown pick %s.", kind[3]),
            getFunction = function() return sv[key] ~= false end,
            setFunction = function(on) sv[key] = on == true end, default = true })
    end
    for _, row in ipairs({
        { type = SECTION, label = "Scoreboard" },
        { type = LABEL, label = function() return string.format("Scoreboard (%s): %s", PersonalityName(), Tally(Night())) end,
          tooltip = SCOREBOARD_HELP },
        { type = BUTTON, label = "Reset scoreboard",
          buttonText = "Reset",
          tooltip = "Clears the scoreboard.", clickHandler = ResetScoreboard },
    }) do table.insert(rows, row) end
    panel:AddSettings(rows)
end

local InCyrodiilCommand = CyrodiilOnly(function(word, args)
    if word == "scoreboard" then
        local action = (args or ""):lower():match("^%s*%a+%s+(%a+)")
        if action == "share" then ShareScoreboard()
        elseif action == "reset" then ResetScoreboard()
        else ShowScoreboard() end
    elseif word == "list" then ListTargets()
    elseif word == "scan" then Scan()
    elseif word == "share" then PickAndShare()
    else PickPrivately() end
end)

-- Changing personality and Group Check work anywhere; everything else is Cyrodiil only.
local function SlashCommand(args)
    local word = (args or ""):lower():match("^%s*(%a*)")
    if word == "personality" then
        local which = (args or ""):lower():match("^%s*%a+%s+(.+)$")
        local P = Personalities()
        local found
        if which and P then
            which = which:gsub("%s", "")
            for key, name in pairs(P.NAMES) do if name:lower():gsub("%s", "") == which then found = key end end
        end
        if found then WearCrown(found) else CyclePersonality() end
    elseif word == "group" then GroupCheck()
    else InCyrodiilCommand(word, args) end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    SLASH_COMMANDS["/lazycrown"] = SlashCommand

    -- Account-wide record. If saved variables can't load, it still works for this session.
    pcall(function()
        sv = ZO_SavedVars:NewAccountWide("LazyCrownSV", 1, nil, { lifetime = {}, personality = "lazy", waypoint = false, mean = false,
            pickKeeps = true, pickResources = true, pickTowns = true, pickOutposts = true, streakL = 0 })
        sv.lifetime = sv.lifetime or {}
    end)
    -- Elves is Selfish again, Clever is now Chris.
    local P = Personalities()
    if P and P.RENAMED and P.RENAMED[sv.personality] then sv.personality = P.RENAMED[sv.personality] end

    -- Wheel entries first: nothing below may stop them from registering.
    local function CurrencyIcon(currency, fallback)
        if not (currency and GetCurrencyGamepadIcon) then return fallback end
        local ok, path = pcall(GetCurrencyGamepadIcon, currency)
        return (ok and type(path) == "string" and path ~= "") and path or fallback
    end
    local ICON_PICK = CurrencyIcon(CURT_CROWN_GEMS, ICON_PICK_FALLBACK)
    local ICON_SHARE = CurrencyIcon(CURT_CROWNS, ICON_SHARE_FALLBACK)
    LibRadialMenu:RegisterAddon(ADDON_NAME, "Lazy Crown")
    -- The add-on settings list entries sorted by ID, so the IDs set the order.
    LibRadialMenu:RegisterEntry(ADDON_NAME, "Crown Command", "1share", ICON_SHARE, PickAndShare,
        Buttons("Too lazy to lead? Let the crown decide. Places the call in the Text Chat box. Press X to send."))
    LibRadialMenu:RegisterEntry(ADDON_NAME, "Change Personality", "2persona", ICON_PERSONALITY, CyclePersonality,
        "Puts the next personality on the crown.")
    LibRadialMenu:RegisterEntry(ADDON_NAME, "Scoreboard", "3record", ICON_SCOREBOARD, CyrodiilOnly(ShareScoreboard),
        Buttons("Places the scoreboard in the Text Chat box. Press X to send."))
    LibRadialMenu:RegisterEntry(ADDON_NAME, "Reset Scoreboard", "4reset", ICON_RESET, CyrodiilOnly(ResetScoreboard),
        "Clears the scoreboard.")
    LibRadialMenu:RegisterEntry(ADDON_NAME, "Group Check", "5group", ICON_GROUP, GroupCheck,
        "Your group size, roles, and how many have Barrier, a necro rez or Negate. Shows in your chat window.")
    LibRadialMenu:RegisterEntry(ADDON_NAME, "Private Command", "6pick", ICON_PICK, PickPrivately,
        "Just for you, no call-outs. Tells you where to go in your chat window.")

    -- Remember when keeps change hands (for weak walls).
    pcall(function()
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_KEEP_ALLIANCE_OWNER_CHANGED, OnKeepOwnerChanged)

    end)

    pcall(WatchSlotAssignments)

    -- Share ultimates with the group, and read theirs (LibGroupCombatStats, if installed).
    pcall(function() if LazyCrown.Group then LazyCrown.Group.Init() end end)

    local okPanel, errPanel = pcall(AddSettingsPanel)
    if not okPanel then
        pcall(Diag, "Settings panel failed at load: " .. tostring(errPanel))
    end

    local ok, err = pcall(function()
        local chatPage = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(CHAT_MENU_SCENE)
        if chatPage then
            chatPage:RegisterCallback("StateChange", OnChatPageStateChange)
        end
    end)
    if not ok then
        pcall(Diag, "Chat page hookup failed at load: " .. tostring(err))
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- Exposed for the test harness (Personalities.lua and QuestData.lua add to this table too).
LazyCrown = LazyCrown or {}
LazyCrown.BuildTargets, LazyCrown.PickTarget, LazyCrown.PickAndShare, LazyCrown.Scan = BuildTargets, PickTarget, PickAndShare, Scan
LazyCrown.SummaryLine, LazyCrown.Record, LazyCrown.CallLine, LazyCrown.Buttons = SummaryLine, function() return sv end, CallLine, Buttons
LazyCrown.OneOf, LazyCrown.TypeOf = OneOf, TypeOf
