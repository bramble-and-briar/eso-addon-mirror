local ADDON_NAME = "LazyCrown"
local VERSION = "0.2.2"
local AUTHOR = "absolventR3M"
local TEXT_COLOR = "F2C65A"
local DIAG_COLOR = "9A9A9A"
local ICON_PICK_FALLBACK = "EsoUI/Art/currency/gamepad/gp_crown_gems.dds"
local ICON_SHARE_FALLBACK = "EsoUI/Art/currency/gamepad/gp_crowns.dds"
local ICON_SCOREBOARD = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_leaderBoards.dds"
local ICON_RESET = "EsoUI/Art/Guild/Gamepad/gp_guild_options_delete.dds"
local ICON_PERSONALITY = "EsoUI/Art/Campaign/Gamepad/gp_bonusIcon_emperor.dds"
local ICON_GROUP = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_groups.dds"
local AD, EP, DC = ALLIANCE_ALDMERI_DOMINION or 1, ALLIANCE_EBONHEART_PACT or 2, ALLIANCE_DAGGERFALL_COVENANT or 3
local ROTATION = { AD, EP, DC }
local ALLIANCE_NAMES = { [AD] = "Aldmeri Dominion", [EP] = "Ebonheart Pact", [DC] = "Daggerfall Covenant" }
local CROWN_ORDER = { "lazy", "bakedpotato", "bored", "chris", "confessor", "deano", "diil", "greedy", "mulliss", "november", "random", "selfish", "ultralazy" }
local function LoadTheRest()
local later = LazyCrown and LazyCrown.later
if not later then return end
LazyCrown.later = nil
local compile = zo_loadstring or loadstring
for _, file in ipairs(later) do
local fn, err = nil, "can't compile here"
if compile then fn, err = compile(file.code, file.name) end
local ok = false
if fn then ok, err = pcall(fn) end
if not ok then
pcall(function() CHAT_ROUTER:AddSystemMessage("[Lazy Crown] " .. file.name .. " didn't load: " .. tostring(err)) end)
end
end
end
local function Personalities()
LoadTheRest()
return LazyCrown and LazyCrown.Personalities
end
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
local GATE_KEEPS = { [AD] = { [19] = true, [20] = true }, [EP] = { [11] = true, [12] = true }, [DC] = { [3] = true, [4] = true } }
local KEEP_PARTS = {
{ label = "Keep" },
{ label = "Lumbermill", resource = RESOURCETYPE_WOOD or 1 },
{ label = "Farm", resource = RESOURCETYPE_FOOD or 2 },
{ label = "Mine", resource = RESOURCETYPE_ORE or 3 },
}
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
local function IsKeepType(keepId, expected)
if not (expected and GetKeepType) then return true end
local ok, keepType = pcall(GetKeepType, keepId)
return ok and keepType == expected
end
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
local NOT_IN_CYRODIIL = "Looks like you're not in Grayhost, which means I don't have to try right now. Sweet."
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
local function UseCyrodiilMap()
if not (GetCyrodiilMapIndex and SetMapToMapListIndex) then return false end
local ok, changed = pcall(function()
if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.IsMapChangingAllowed and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then
return false
end
local index = GetCyrodiilMapIndex()
if not index or (GetCurrentMapIndex and GetCurrentMapIndex() == index) then return false end
if SetMapToMapListIndex(index) == SET_MAP_RESULT_MAP_CHANGED then
pcall(MapChanged)
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
local DEFENDABLE = { Keep = true, Outpost = true }
local FLAGGED_RESOURCE_SECONDS = 32
local MIN_GROUP = { Outpost = 4, Keep = 8 }
local FIGHT_RADIUS = 0.025
local function Supported(t, mine)
local okS, siege = pcall(GetNumSieges, t.keepId, Context(), mine)
if okS and type(siege) == "number" and siege > 0 then return true end
if not (t.x and GetNumKillLocations) then return false end
local by = {}
local okN, n = pcall(GetNumKillLocations)
for i = 1, (okN and n) or 0 do
local okP, _, x, y = pcall(GetKillLocationPinInfo, i)
if okP and type(x) == "number" and type(y) == "number" then
local dx, dy = x - t.x, y - t.y
if dx * dx + dy * dy <= FIGHT_RADIUS * FIGHT_RADIUS then
for alliance in pairs(ALLIANCE_NAMES) do
local okK, k = pcall(GetNumKillLocationAllianceKills, i, alliance)
by[alliance] = (by[alliance] or 0) + (okK and type(k) == "number" and k or 0)
end
end
end
end
local ours, theirs = by[mine] or 0, 0
for alliance, k in pairs(by) do if alliance ~= mine then theirs = math.max(theirs, k) end end
return ours > 0 and ours > theirs
end
local KIND_SETTING = { Keep = "pickKeeps", Lumbermill = "pickResources", Farm = "pickResources", Mine = "pickResources",
Town = "pickTowns", Outpost = "pickOutposts" }
local function UnderAttack(keepId)
local ok, underAttack = pcall(GetKeepUnderAttack, keepId, Context())
return ok and underAttack == true
end
local lastKeepId = nil
local lastType = nil
local function TypeOf(t)
if t.parent then return "resource" end
return t.kind
end
local function OneOf(w, list)
if #list == 0 then return nil end
if w.planning then return nil end
if w.planned then
for _, t in ipairs(list) do if t.keepId == w.planned then return t end end
end
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
local VOID_SECONDS = 90
local sv = { lifetime = {} }
local Start
local function Used(fn)
return function(...)
Start()
return fn(...)
end
end
local function PersonalityKey()
local P = Personalities()
if P and P.RENAMED and P.RENAMED[sv.personality] then sv.personality = P.RENAMED[sv.personality] end
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
local DRUNK_WORDS = {
Alright = "Aaalright", going = "goin", attack = "attak", defend = "defenn", defense = "defensh",
should = "shuold", declare = "delcare", guess = "guesh", siege = "sheige", Castle = "Cashle",
Keep = "Keeeep", Outpost = "Outposht", Fort = "Forrt", front = "fronnt", door = "doooor",
take = "tayke", the = "teh", ["Let's"] = "Lesh", crown = "crowwn", doth = "dothhh", hit = "hiit",
taken = "takken", held = "helld", lost = "losht", Scoreboard = "Shcoreboard", we = "wee",
}
local COLOR_LINES = {
[EP] = {
{ text = "I think Araphel has a crush on me." },
{ text = "Evil Deeds stole my sweet roll." },
{ text = "Maybe Moonrox has Moon Sugar? Let's hit that pinata." },
{ text = "Let's blow them to Smithreen's not D." },
},
[DC] = {
{ text = "Maybe this time Ashmax will share his moon sugar." },
{ text = "TKL always hoards the best skooma." },
{ text = "Maybe Cake will finally show me the moon sugar." },
{ text = "Maybe Suzy will share." },
},
[AD] = {
{ text = "I hear the VD is sweeter than Skooma." },
{ text = "Law Dog stole my sweet roll." },
{ text = "Silachi sounds like srirachi. Wait, sriracha? I don't know. Just get there." },
},
}
local function ColorLines(owner, skooma)
local out = {}
for _, c in ipairs(COLOR_LINES[owner] or {}) do
local low = c.text:lower()
if skooma or not (low:find("skooma", 1, true) or low:find("moon sugar", 1, true)) then table.insert(out, c.text) end
end
return out
end
local DRUNK_ASIDES = {
"But the blue one.", "No wait, the other one.", "You gusy are teh best.", "You know the one.",
"Not that one. Yes that one.", "Or the one next to it.", "Pretty sure it's still there.",
"I love you guys.", "Is the floor moving?",
}
local function Drunk(line, owner)
if not sv.drunk then return line end
line = line:gsub("[%a']+", function(word)
local slurred = DRUNK_WORDS[word]
if slurred and Random(1, 3) > 1 then return slurred end
end)
local aside = DRUNK_ASIDES[Random(1, #DRUNK_ASIDES)]
local about = owner and ColorLines(owner, false) or {}
if #about > 0 and Random(1, 3) == 1 then aside = about[Random(1, #about)] end
local first, rest = line:match("^(.-[%.!%?])(.*)$")
if first then line = first .. " " .. aside .. rest else line = line .. " " .. aside end
for _ = 1, Random(1, 2) do
local spots = {}
for pos in line:gmatch("() ") do table.insert(spots, pos) end
if #spots > 0 then
local at = spots[Random(1, #spots)]
line = line:sub(1, at) .. "*hic* " .. line:sub(at + 1)
end
end
return line
end
local justSettled
local quickReroll
local QUIPS = {
{ won = true, text = "Easy.", any = true, notWho = { lazy = true, ultralazy = true, bakedpotato = true }, notSkooma = true },
{ won = true, text = "Crown's still on.", who = { mulliss = true, selfish = true } },
{ won = true, text = "Write that down.", who = { chris = true, selfish = true } },
{ won = true, text = "More AP for the crown.", who = { greedy = true, selfish = true } },
{ won = true, text = "Top 10 %s player confirmed.", who = { chris = true } },
{ won = true, text = "Worth the short walk.", who = { ultralazy = true, bored = true } },
{ won = true, text = "Don't get used to it.", who = { mulliss = true, lazy = true, ultralazy = true }, mean = true, wins = 3 },
{ won = false, text = "We'll call that a scouting run.", who = { mulliss = true, confessor = true, selfish = true } },
{ won = false, text = "Tactical donation.", who = { chris = true, november = true, deano = true } },
{ won = false, text = "Nobody saw that.", who = { november = true, lazy = true, ultralazy = true }, drunk = true },
{ won = false, text = "That AP was ours.", who = { greedy = true, confessor = true, selfish = true } },
{ won = false, text = "That's on Mulliss.", who = { chris = true } },
{ won = false, text = "This is why we don't do things.", who = { confessor = true } },
{ won = false, text = "Didn't want it anyway.", who = { selfish = true, ultralazy = true, deano = true } },
{ won = false, text = "Noted. Getting weirder.", skooma = true },
}
local SHORT = { [AD] = "AD", [EP] = "EP", [DC] = "DC" }
local function Quip(won, key, mine)
local fits = {}
for _, q in ipairs(QUIPS) do
local ok = q.won == won
if q.skooma then ok = ok and sv.skooma == true
elseif key == "random" then ok = ok
else ok = ok and ((q.who and q.who[key]) or (q.any and not q.notWho[key]) or (q.drunk and sv.drunk == true)) end
if q.notSkooma and sv.skooma == true then ok = false end
if q.mean and sv.mean ~= true then ok = false end
if q.wins and (sv.streakW or 0) < q.wins then ok = false end
if ok then table.insert(fits, q.text) end
end
if #fits == 0 or Random(1, 3) ~= 1 then return nil end
return string.format(fits[Random(1, #fits)], SHORT[mine] or "AD")
end
local function Settle(result, why, against, quiet)
local call = sv.open
if not call then return end
sv.open = nil
justSettled = result
local night = Night()
night.lossesBy = night.lossesBy or {}
sv.lastResult = result
if result ~= "void" then
sv.lastDecided, sv.lastDecidedCall = result, { keepId = call.keepId, result = result, against = against, plan = call.plan, planKey = call.planKey }
if result == "W" then
sv.streakL, sv.streakBy, sv.streakW = 0, {}, (sv.streakW or 0) + 1
else
sv.streakW = 0
sv.streakL = (sv.streakL or 0) + 1
sv.streakBy = sv.streakBy or {}
if ALLIANCE_NAMES[against] then sv.streakBy[tostring(against)] = (sv.streakBy[tostring(against)] or 0) + 1 end
end
end
quickReroll = result == "void" and not why
if quickReroll then sv.rerolls = (sv.rerolls or 0) + 1 elseif result ~= "void" then sv.rerolls = 0 end
if result == "void" then
night.void = night.void + 1
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
if not quiet then
local line = string.format("%s! %s %s. Scoreboard: %s.", won and "W" or "L", call.name, what, Tally(night))
local quip = Quip(won, call.planKey or PersonalityKey(), call.alliance)
Say(Drunk(quip and (line .. " " .. quip) or line))
end
SaveSoon()
end
local function CampaignChanged(call)
if not (GetCurrentCampaignId and call.campaignId and call.campaignId ~= 0) then return false end
local now = GetCurrentCampaignId()
return now ~= nil and now ~= 0 and now ~= call.campaignId
end
local function PlayerSpot()
local ok, x, y, _, shown = pcall(GetMapPlayerPosition, "player")
if ok and type(x) == "number" and type(y) == "number" and shown ~= false and (x ~= 0 or y ~= 0) then return { x = x, y = y } end
end
local WENT_THERE = 0.3
local function FarFrom(keepId, where)
if not where then return false end
local x, y = PinPosition(keepId)
if not (x and y) or (x == 0 and y == 0) then return false end
local dx, dy = x - where.x, y - where.y
return math.sqrt(dx * dx + dy * dy) > WENT_THERE
end
local function SettleLastCall(where)
justSettled, quickReroll = nil, false
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
local function OpenCall(pick, mine, plan, planKey)
local night = Night()
night.lastAt = Now()
sv.open = {
keepId = pick.keepId, number = pick.number, name = pick.name, defend = pick.defend or nil,
alliance = mine, at = Now(), campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or nil,
plan = plan, planKey = planKey,
}
end
local function IsLocalEvent(ctx)
return not IsLocalBattlegroundContext or IsLocalBattlegroundContext(ctx)
end
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
local function SummaryLine()
local night = Night()
local best = BestCall(night)
local lazier = LazierAlliance(night)
return string.format("Scoreboard: %s.%s%s", Tally(night),
best and string.format(" Best call: %s %d-%d.", best.name, best.w, best.l) or "",
lazier and string.format(" Alliance that made me even lazier: %s.", lazier) or "")
end
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
local FORT_ASH, BLUE_ROAD, BRUMA, NIKEL, DRAKELOWE = 6, 13, 151, 132, 14
local function Extra(pick, mine)
if pick.keepId == FORT_ASH then return "Ash till you crash." end
local P = Personalities()
local key = PersonalityKey()
local skipNikel = P and P.SKIP_NIKEL and P.SKIP_NIKEL[key]
if pick.keepId == NIKEL and not skipNikel then
return pick.defend and "We're gonna protect Nikel's pickle from tickling." or "We're gonna tickle Nikel's pickle."
end
if pick.keepId == BLUE_ROAD and P and P.SAY_SGX and P.SAY_SGX[key] then return "And don't forget sgx says the mine side is cursed." end
local drakelowe = pick.keepId == DRAKELOWE or (pick.parent == DRAKELOWE and pick.kind == "Mine")
if drakelowe and not pick.defend and P and P.SHARE_DRAKELOWE and P.SHARE_DRAKELOWE[key] then
return "Make sure you share the Drakelowe quests with everyone."
end
if pick.keepId == BRUMA then return "Bruma is the key to the whole map guys." end
if GATE_KEEPS[mine] and GATE_KEEPS[mine][pick.keepId] then return "I guess we gotta go bail out the alliance ugh." end
end
local VOICES = {
declare = { attack = "The crown doth declare an attack on %s.", defend = "The crown doth declare the defense of %s.",
directive = "The crown doth declare: %s." },
guess = { attack = "I guess we should hit %s.", defend = "I guess we should defend %s.",
directive = "I guess we should %s." },
alright = { attack = "Alright, we are going to hit %s.", defend = "Alright, we are going to defend %s.",
directive = "Alright, we are going to %s." },
letsgo = { attack = "Let's go take %s.", defend = "Let's go defend %s.",
directive = "Let's %s." },
baked = { attack = "Duuude... let's hit %s.", defend = "Duuude, we gotta defend %s.",
directive = "Duuude... let's %s." },
dice = { attack = "The dice say %s.", defend = "The dice say defend %s.",
directive = "The dice say %s." },
}
local function Voice()
local P = Personalities()
return VOICES[P and P.VOICES and P.VOICES[PersonalityKey()] or "declare"] or VOICES.declare
end
local CALL_VARIANTS = {
{ text = "By decree of the crown: %s.", who = { greedy = 2 } },
{ text = "The crown demands %s. And its AP.", who = { greedy = 2 } },
{ text = "Alright, %s next. Stay on crown.", who = { chris = 2 } },
{ text = "%s. Let's go.", who = { deano = 2, november = 2, confessor = 2, mulliss = 2 } },
{ text = "Let's go see what %s has for us.", who = { mulliss = 2, confessor = 2, lazy = 1 } },
{ text = "%s, I guess.", who = { lazy = 2, ultralazy = 2 }, losing = { november = 2, deano = 2 } },
{ text = "Eh... %s?", who = { lazy = 2, ultralazy = 2, november = 1, deano = 1 }, rerolls = { november = 2, deano = 2 } },
{ text = "Something's happening at %s. Finally.", who = { bored = 2, confessor = 1 } },
{ text = "Alright, %s. Bring your own siege.", who = { diil = 2, november = 1 } },
{ text = "%s. It's right there.", who = { selfish = 2 }, close = true },
{ text = "%s or %s, whatever. %s.", who = { lazy = 1, november = 1 }, alt = true },
}
local PAYING_US = { confessor = true, deano = true, selfish = true, greedy = true, lazy = true, ultralazy = true }
local GRENADE = "Bring out the Holy Hand Grenade of %s. We are going to leech that tick if we can. %s"
local function Wording(pick, where, opts)
local voice = Voice()
if pick.directive then return string.format(voice.directive, pick.directive) end
local key = PersonalityKey()
if key == "random" and opts and opts.variants then
local pool = {}
for _, v in pairs(VOICES) do table.insert(pool, pick.defend and v.defend or v.attack) end
if not pick.defend then
for _, v in ipairs(CALL_VARIANTS) do if not v.alt and not v.close then table.insert(pool, v.text) end end
end
return string.format(pool[Random(1, #pool)], where)
end
if opts and opts.grenade and Random(1, 2) == 1 then
local hustle = "Hustle."
if opts.seconds and LazyCrown.Travel then
hustle = string.format("Hustle, we only have maybe %s.", (LazyCrown.Travel.Eta(opts.seconds):gsub("^about ", "")))
end
return string.format(GRENADE, where, hustle)
end
if pick.defend then return string.format(voice.defend, where) end
if not (opts and opts.variants and Personalities()) then return string.format(voice.attack, where) end
local choices, total = { { text = voice.attack, weight = 4 } }, 4
local losing, rerolls = (sv.streakL or 0) > 6, (sv.rerolls or 0) >= 3
for _, v in ipairs(CALL_VARIANTS) do
local weight = v.who[key] or 0
if losing and v.losing and v.losing[key] then weight = math.max(weight, v.losing[key]) end
if rerolls and v.rerolls and v.rerolls[key] then weight = math.max(weight, v.rerolls[key]) end
if v.close and not (opts.seconds and opts.seconds <= 32) then weight = 0 end
if v.alt and not (opts.alt and where == pick.name) then weight = 0 end
if weight > 0 then
table.insert(choices, { variant = v, weight = weight })
total = total + weight
end
end
local roll = Random(1, total)
for _, c in ipairs(choices) do
roll = roll - c.weight
if roll <= 0 then
local v = c.variant
if not v then return string.format(c.text, where) end
if v.alt then
local a, b = where, opts.alt
if Random(1, 2) == 1 then a, b = b, a end
return string.format(v.text, a, b, where)
end
return string.format(v.text, where)
end
end
return string.format(voice.attack, where)
end
local function CallLine(pick, mine, chain, extras, tail, quiet, opts)
local legs = { pick.name }
for _, leg in ipairs(chain or {}) do table.insert(legs, leg.name) end
local where = table.concat(legs, ", then ")
local line
if not sv.mean then
line = Wording(pick, where, opts)
else
local what = pick.directive or string.format("%s %s", pick.defend and "defend" or "attack", where)
local body = string.format("you're going to %s and you're gonna like it.", what)
local mix = opts and opts.variants
if mix and not pick.directive then
local roll = Random(1, 4)
if roll == 1 then body = string.format("try not to die on the way to %s this time.", where)
elseif roll == 2 then body = string.format("%s. Even you can't mess this up. Probably.", where) end
end
local key = PersonalityKey()
if sv.lastResult == "W" then
if mix and (key == "confessor" or key == "november") and Random(1, 2) == 1 then
line = "Don't let it go to your head. " .. body:gsub("^%l", string.upper)
else
line = "I'd say congrats on that W but I'm too lazy. And mean. Anyways, " .. body
end
else
line = body:gsub("^%l", string.upper)
if sv.lastResult == "L" then line = ((mix and Random(1, 2) == 1) and "Incredible. Another one. " or "Wow losers... ") .. line end
end
end
for _, more in ipairs(extras or {}) do line = line .. " " .. more end
local extra = not quiet and Extra(pick, mine) or nil
for _, leg in ipairs(chain or {}) do extra = extra or Extra(leg, mine) end
if extra then line = line .. " " .. extra end
for _, more in ipairs(tail or {}) do line = line .. " " .. more end
return line
end
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
lossesBy = type(sv.night) == "table" and sv.night.lossesBy or {},
memory = sv.memory, ignoreCA = sv.continuousAttack == false,
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
local SKOOMA_CALLS = {
"Uhhh... %s? Yeah. %s.",
"The moon sugar says %s.",
"%s. Or was that a dream? Go anyway.",
"Follow the pretty colors to %s.",
}
local SKOOMA_AWAY = {
"Everyone go to... away. Just away.",
"Go away. Far away. Further than that.",
"We're going to Away. It's on the map somewhere.",
}
local SKOOMA_FAR = "We're going to %s. Yes, all the way over there. The journey is the destination."
local SKOOMA_SAYS = {
"Moon sugar makes the whole map shiny. A little goes a very long way though.",
"Did that mudcrab just wink at me?",
"I can hear the Elder Scrolls humming. They're off key.",
"If you stare at White-Gold Tower long enough, it stares back.",
"I traded my horse for a really nice rock. Worth it.",
"The siege engines are talking to each other. Don't trust them.",
"Shh. The trees are listening.",
"Everything is purple and that's fine.",
"Who keeps moving the keeps?",
"I think the guards can hear my thoughts.",
}
local function FarAway(targets, mine, where)
if not where then return nil end
local far, farthest, best = {}, nil, -1
for _, t in ipairs(targets) do
local x, y = PinPosition(t.keepId)
if x and t.owner ~= mine then
local d = math.sqrt((x - where.x) ^ 2 + (y - where.y) ^ 2)
if d >= 0.35 then table.insert(far, t) end
if d > best then farthest, best = t, d end
end
end
if #far > 0 then return far[Random(1, #far)] end
return farthest
end
local SkoomaPick
local function SkoomaCall(targets, mine, where)
local line, pick = SkoomaPick(targets, mine, where)
if Random(1, 2) == 1 then
local about = pick and ColorLines(pick.owner, true) or {}
if #about > 0 and Random(1, 2) == 1 then
line = line .. " " .. about[Random(1, #about)]
else
line = line .. " " .. SKOOMA_SAYS[Random(1, #SKOOMA_SAYS)]
end
end
return line
end
function SkoomaPick(targets, mine, where)
local roll = Random(1, 10)
if roll == 1 then
sv.open = { keepId = 0, name = "No call", alliance = mine, at = Now() }
Settle("L", nil, nil, true)
return string.format("Nope. No call. I'm in a bad mood, so that's an L. Scoreboard: %s.", Tally(Night()))
elseif roll == 2 then
return SKOOMA_AWAY[Random(1, #SKOOMA_AWAY)]
elseif roll == 3 then
local far = FarAway(targets, mine, where)
if far then
OpenCall(far, mine)
return string.format(SKOOMA_FAR, far.name), far
end
end
local pick = targets[Random(1, #targets)]
if pick.owner == mine then
sv.open = { keepId = pick.keepId, name = pick.name, alliance = mine, at = Now() }
Settle("W", nil, nil, true)
return string.format("We already have %s! That's a W. Scoreboard: %s. Taking a break for more skooma.", pick.name, Tally(Night())), pick
end
OpenCall(pick, mine)
return (string.format(SKOOMA_CALLS[Random(1, #SKOOMA_CALLS)], pick.name, pick.name)), pick
end
local POTATO_HUNGRY = {
"Hold up. I'm really hungry. Snack break.",
"Brb, I gotta find a snack.",
"Can we stop for snacks? I'm starving.",
}
local POTATO_SMOKE = {
"Gotta go smoke real quick. Hold the keep.",
"Smoke break. Don't take anything without me.",
"Be right back, gotta go smoke.",
}
local function PotatoBreak(targets, mine, where)
local kind = Random(1, 3)
if kind == 1 then return POTATO_HUNGRY[Random(1, #POTATO_HUNGRY)] end
if kind == 2 then return POTATO_SMOKE[Random(1, #POTATO_SMOKE)] end
if Random(1, 2) == 1 then
local stop, best
for _, t in ipairs(targets) do
local ok, owner = pcall(GetKeepAlliance, t.keepId, Context())
local x, y = PinPosition(t.keepId)
if ok and owner == mine and x then
local d = where and math.sqrt((x - where.x) ^ 2 + (y - where.y) ^ 2) or 0
if not best or d < best then stop, best = t, d end
end
end
if stop then
sv.open = { keepId = stop.keepId, name = stop.name, alliance = mine, at = Now() }
Settle("W", nil, nil, true)
return string.format("Wait... what was I doing? Uh, pit stop at %s. It's ours, so that's a W. Scoreboard: %s.", stop.name, Tally(Night()))
end
end
sv.open = { keepId = 0, name = "No call", alliance = mine, at = Now() }
Settle("L", nil, nil, true)
return string.format("...sorry, I was staring into space thinking about how big Tamriel is. Forgot to make a call. That's an L. Scoreboard: %s.", Tally(Night()))
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
if sv.skooma and #targets > 0 then
for _, t in ipairs(targets) do
local ok, owner = pcall(GetKeepAlliance, t.keepId, Context())
if ok then t.owner = owner end
end
local line = Drunk(SkoomaCall(targets, mine, PlayerSpot()))
Say(line)
return line
end
if personality == "bakedpotato" and #targets > 0 then
if type(sv.memory) ~= "table" then sv.memory = {} end
local callsLeft = sv.memory.potatoIn or Random(2, 5)
if callsLeft <= 0 then
sv.memory.potatoIn = Random(2, 5)
local line = Drunk(PotatoBreak(targets, mine, PlayerSpot()))
Say(line)
return line
end
sv.memory.potatoIn = callsLeft - 1
end
if sv.mean == true and (personality == "selfish" or personality == "deano") and (sv.streakL or 0) > 10 and Random(1, 3) == 1 then
local line = Drunk(SKOOMA_AWAY[Random(1, #SKOOMA_AWAY)])
Say(line)
return line
end
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
local switchedOn = {}
for _, t in ipairs(options) do
if sv[KIND_SETTING[t.kind] or ""] ~= false then table.insert(switchedOn, t) end
end
if #switchedOn == 0 then
Say("Nothing to pick with those target types switched off. Turn some back on in Options.")
return nil
end
options = switchedOn
local travel
if needMap and LazyCrown.Travel then
for _, t in ipairs(targets) do t.x, t.y = PinPosition(t.keepId) end
local okP, px, py, _, shown = pcall(GetMapPlayerPosition, "player")
if okP and type(px) == "number" and type(py) == "number" and shown ~= false and (px ~= 0 or py ~= 0) then
local okT, route = pcall(LazyCrown.Travel.New, mine, Context(), { x = px, y = py }, targets, KeepName)
if okT then travel = route end
end
end
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
local G = LazyCrown.Group
if sv.groupSize == true and G then
local ok, size = pcall(G.Size)
if ok and size then
local fits = {}
for _, t in ipairs(options) do
if size >= (MIN_GROUP[t.kind] or 0) or Supported(t, mine) then table.insert(fits, t) end
end
options = fits
end
end
local everything = { unpack(options) }
if #options > 1 and lastKeepId then
for i, t in ipairs(options) do
if t.keepId == lastKeepId then table.remove(options, i) break end
end
end
local plan, world
local choose = P and P[personality]
if choose then
world = BuildWorld(mine, options, targets, needMap)
world.everything = everything
world.lastType = lastType
local last = sv.lastDecidedCall
if justSettled == "W" and last and last.plan and last.planKey == personality then world.planned = last.plan[1] end
world.justSettled = justSettled
if travel then
world.Route = travel
world.Away = function(t)
local leg = travel(t)
return leg and leg.seconds / LazyCrown.Travel.SECONDS_PER_UNIT
end
end
local ok, result = pcall(choose, world)
if ok and type(result) == "table" and result.pick then plan = result end
if ok and type(result) == "table" and not result.pick and type(result.say) == "string" then
local line = Drunk(result.say)
Say(line)
return line
end
end
local pick = plan and plan.pick
if not pick then
if #options == 0 then
Say("Not enough of you here for what's left. Outposts need 4, keeps need 8.")
return nil
end
if world and P and P.LazyPick then
local okLazy, lazy = pcall(P.LazyPick, world)
if okLazy and type(lazy) == "table" and lazy.pick then pick = lazy.pick end
end
pick = pick or OneOf({ Random = Random, lastType = lastType }, options)
end
local chain = plan and plan.chain or nil
lastKeepId = pick.keepId
lastType = TypeOf(pick)
local extras = plan and plan.extras
local leg = travel and travel(pick)
local how = leg and (leg.line or leg.ride)
if plan and plan.how then
how = plan.how
elseif leg and sv.showEta then
local eta = LazyCrown.Travel.Eta(leg.seconds)
how = how and (how:gsub("%.$", ", " .. eta .. ".")) or ("It's right there, " .. eta .. ".")
end
if how then
extras = { how }
for _, more in ipairs(plan and plan.extras or {}) do table.insert(extras, more) end
end
local tail = plan and plan.tail
local streakLine = (sv.streakL or 0) >= 3 and P and P.StreakTail and P.StreakTail(personality, mine)
if streakLine then
tail = { streakLine }
for _, more in ipairs(plan and plan.tail or {}) do table.insert(tail, more) end
end
if personality == "diil" and not pick.unscored then
if type(sv.memory) ~= "table" then sv.memory = {} end
if not quickReroll then sv.memory.diilSnackIn = (sv.memory.diilSnackIn or Random(5, 10)) - 1 end
if (sv.memory.diilSnackIn or 1) <= 0 then
sv.memory.diilSnackIn = Random(5, 10)
local lines = Random(1, 2) == 1 and POTATO_HUNGRY or POTATO_SMOKE
tail = tail or {}
table.insert(tail, lines[Random(1, #lines)])
end
end
if sv.mean == true and (sv.streakL or 0) >= 5 and PAYING_US[personality] and Random(1, 2) == 1 then
tail = tail or {}
table.insert(tail, "At this point the enemy should be paying us.")
end
local alt
if pick.x and not pick.defend and not pick.directive and not chain then
local best, bestD, sameKind
for _, t in ipairs(options) do
local dx, dy = (t.x or 99) - pick.x, (t.y or 99) - pick.y
local d = math.sqrt(dx * dx + dy * dy)
local same = TypeOf(t) == TypeOf(pick)
if t.keepId ~= pick.keepId and not t.defend and d <= 0.2 and (not best or (same and not sameKind) or (same == sameKind and d < bestD)) then
best, bestD, sameKind = t, d, same
end
end
alt = best and best.name
end
local wording = { variants = true, grenade = plan and plan.grenade, seconds = leg and leg.seconds, alt = alt }
local line = Drunk(CallLine(pick, mine, chain, extras, tail, plan and plan.quietTarget, wording), pick.owner)
Say(line)
local steps
if world and P and P.PlanAhead then
local okPlan, ahead = pcall(P.PlanAhead, personality, world, pick)
if okPlan and type(ahead) == "table" and #ahead > 1 then steps = ahead end
end
local planIds
if steps then
local names = {}
planIds = {}
for i = 2, #steps do table.insert(planIds, steps[i].keepId); table.insert(names, steps[i].name) end
if sv.showPlan ~= false then Diag("Plan after this: " .. table.concat(names, ", then ") .. ".") end
end
if not pick.unscored then OpenCall(pick, mine, planIds, personality) end
if wantWaypoint and SetWaypoint(pick.keepId) then
Diag("Waypoint set on your map.")
end
return line
end, needMap)
end
local CHAT_MENU_SCENE = "gamepadChatMenu"
local pendingText = nil
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
local CA_TIMED = { [39249] = true, [45617] = true }
local CA_PASSIVE = { [39248] = true, [45614] = true }
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
local function WearCrown(key)
local P = Personalities()
if not (P and P.NAMES[key]) then return end
sv.personality = key
Say(string.format("%s is wearing the crown now.", P.NAMES[key]))
RefreshSettings()
end
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
Start()
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
LoadTheRest()
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
local function AddSettingsPanel()
local lib = LibHarvensAddonSettings
if not (lib and lib.AddAddon and lib.ST_LABEL and lib.ST_SECTION) then return end
local panel = lib:AddAddon("Lazy Crown")
panel.version = VERSION
panel.author = AUTHOR
local LABEL, SECTION, BUTTON, CHECKBOX = lib.ST_LABEL, lib.ST_SECTION, lib.ST_BUTTON or 6, lib.ST_CHECKBOX or 1
local rows = {
{ type = SECTION, label = "General" },
{ type = LABEL, label = "How to use", tooltip = function() return Buttons(HOW_TO_USE) end },
{ type = LABEL, label = "Wheel setup", tooltip = function() return Buttons(WHEEL_SETUP) end },
{ type = LABEL, label = "Chat commands", tooltip = CHAT_COMMANDS },
}
table.insert(rows, { type = SECTION, label = "Personalities" })
for _, key in ipairs(CROWN_ORDER) do
table.insert(rows, {
type = BUTTON, buttonText = "Wear the crown",
tooltip = function() local P = Personalities(); return P and P.TOOLTIPS[key] or "" end,
label = function()
local P = Personalities()
return ((P and P.NAMES[key]) or key) .. (PersonalityKey() == key and " (wearing the crown)" or "")
end,
clickHandler = function() WearCrown(key) end,
})
end
for _, row in ipairs({
{ type = SECTION, label = "Options" },
{ type = CHECKBOX, label = "Set a waypoint",
tooltip = "Puts a waypoint on your map for every call.",
getFunction = function() return sv.waypoint == true end,
setFunction = function(on) sv.waypoint = on == true end, default = false },
{ type = CHECKBOX, label = "Show the plan",
tooltip = "After each call, your chat window shows the next few calls the crown has in mind if this one goes our way. Only you see it.",
getFunction = function() return sv.showPlan ~= false end,
setFunction = function(on) sv.showPlan = on == true end, default = true },
{ type = CHECKBOX, label = "Show travel times",
tooltip = "Adds about how long it takes to get there to the call: 'Ride north, about 45 seconds.'",
getFunction = function() return sv.showEta == true end,
setFunction = function(on) sv.showEta = on == true end, default = false },
{ type = CHECKBOX, label = "Size up the group",
tooltip = "Every crown counts who's here with you: no outposts with fewer than 4 of you, no keeps with fewer than 8. A keep or outpost with our siege already on it, or a fight we're winning there, is still fair game: our people are there.",
getFunction = function() return sv.groupSize == true end,
setFunction = function(on) sv.groupSize = on == true end, default = false },
{ type = CHECKBOX, label = "Continuous Attack",
tooltip = "Chris, Confessor and Deano grab a resource on the way when your Continuous Attack buff is running low.",
getFunction = function() return sv.continuousAttack ~= false end,
setFunction = function(on) sv.continuousAttack = on == true end, default = true },
{ type = CHECKBOX, label = "Mean",
tooltip = "Same calls, worse attitude.",
getFunction = function() return sv.mean == true end,
setFunction = function(on) sv.mean = on == true end, default = false },
{ type = CHECKBOX, label = "Drunk",
tooltip = "Same calls, a few drinks in. *hic*",
getFunction = function() return sv.drunk == true end,
setFunction = function(on) sv.drunk = on == true end, default = false },
{ type = CHECKBOX, label = "Skooma",
tooltip = "Really out of it. Calls anything at random, even what we already have (that's a W, then a break for more skooma). Sometimes sends you across the map, tells everyone to go away, or won't call at all (that's an L). Says weird things.",
getFunction = function() return sv.skooma == true end,
setFunction = function(on) sv.skooma = on == true end, default = false },
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
for _, row in ipairs(rows) do
for _, field in ipairs({ "label", "tooltip", "getFunction", "setFunction", "clickHandler" }) do
if type(row[field]) == "function" then row[field] = Used(row[field]) end
end
end
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
local started, panelError = false, nil
Start = function()
if started then return end
started = true
if panelError then pcall(Diag, "Settings panel failed at load: " .. panelError) end
pcall(function()
sv = ZO_SavedVars:NewAccountWide("LazyCrownSV", 1, nil, { lifetime = {}, personality = "lazy", waypoint = false, mean = false,
pickKeeps = true, pickResources = true, pickTowns = true, pickOutposts = true, streakL = 0 })
sv.lifetime = sv.lifetime or {}
end)
pcall(function()
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_KEEP_ALLIANCE_OWNER_CHANGED, OnKeepOwnerChanged)
end)
LoadTheRest()
pcall(function() if LazyCrown.Group then LazyCrown.Group.Init() end end)
local ok, err = pcall(function()
local chatPage = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(CHAT_MENU_SCENE)
if chatPage then
chatPage:RegisterCallback("StateChange", OnChatPageStateChange)
end
end)
if not ok then
pcall(Diag, "Chat page hookup failed: " .. tostring(err))
end
end
SLASH_COMMANDS["/lazycrown"] = Used(SlashCommand)
local SHARE_HELP = "Too lazy to lead? Let the crown decide. Places the call in the Text Chat box. Press X to send."
local SCOREBOARD_SHARE_HELP = "Places the scoreboard in the Text Chat box. Press X to send."
pcall(function()
LibRadialMenu:RegisterAddon(ADDON_NAME, "Lazy Crown")
LibRadialMenu:RegisterEntry(ADDON_NAME, "Crown Command", "1share", ICON_SHARE_FALLBACK, Used(PickAndShare), SHARE_HELP)
LibRadialMenu:RegisterEntry(ADDON_NAME, "Change Personality", "2persona", ICON_PERSONALITY, Used(CyclePersonality),
"Puts the next personality on the crown.")
LibRadialMenu:RegisterEntry(ADDON_NAME, "Scoreboard", "3record", ICON_SCOREBOARD, Used(CyrodiilOnly(ShareScoreboard)), SCOREBOARD_SHARE_HELP)
LibRadialMenu:RegisterEntry(ADDON_NAME, "Reset Scoreboard", "4reset", ICON_RESET, Used(CyrodiilOnly(ResetScoreboard)),
"Clears the scoreboard.")
LibRadialMenu:RegisterEntry(ADDON_NAME, "Group Check", "5group", ICON_GROUP, Used(GroupCheck),
"Your group size, roles, and how many have Barrier, a necro rez or Negate. Shows in your chat window.")
LibRadialMenu:RegisterEntry(ADDON_NAME, "Private Command", "6pick", ICON_PICK_FALLBACK, Used(PickPrivately),
"Just for you, no call-outs. Tells you where to go in your chat window.")
end)
local function AskWhenShown(entryId, fields)
local mine = LibRadialMenu.registeredEntries and LibRadialMenu.registeredEntries[ADDON_NAME]
local entry = mine and mine[entryId]
if type(entry) ~= "table" or getmetatable(entry) then return end
for field in pairs(fields) do entry[field] = nil end
setmetatable(entry, { __index = function(t, field)
local ask = fields[field]
if not ask then return nil end
local value = ask()
rawset(t, field, value)
return value
end })
end
local function CurrencyIcon(currency, fallback)
if not (currency and GetCurrencyGamepadIcon) then return fallback end
local ok, path = pcall(GetCurrencyGamepadIcon, currency)
return (ok and type(path) == "string" and path ~= "") and path or fallback
end
pcall(AskWhenShown, "1share", {
icon = function() return CurrencyIcon(CURT_CROWNS, ICON_SHARE_FALLBACK) end,
description = function() return Buttons(SHARE_HELP) end,
})
pcall(AskWhenShown, "3record", { description = function() return Buttons(SCOREBOARD_SHARE_HELP) end })
pcall(AskWhenShown, "6pick", { icon = function() return CurrencyIcon(CURT_CROWN_GEMS, ICON_PICK_FALLBACK) end })
pcall(WatchSlotAssignments)
local okPanel, errPanel = pcall(AddSettingsPanel)
if not okPanel then panelError = tostring(errPanel) end
LazyCrown = LazyCrown or {}
LazyCrown.BuildTargets, LazyCrown.PickTarget, LazyCrown.PickAndShare, LazyCrown.Scan = BuildTargets, PickTarget, PickAndShare, Scan
LazyCrown.Start, LazyCrown.CROWN_ORDER = Start, CROWN_ORDER
LazyCrown.SummaryLine, LazyCrown.Record, LazyCrown.CallLine, LazyCrown.Buttons = SummaryLine, function() return sv end, CallLine, Buttons
LazyCrown.OneOf, LazyCrown.TypeOf = OneOf, TypeOf
LazyCrown.ForgetLastCall = function() lastKeepId, lastType = nil, nil end
LazyCrown.Quip = Quip
