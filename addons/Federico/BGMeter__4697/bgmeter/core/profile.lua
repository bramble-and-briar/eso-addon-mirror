BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Profile = {}

Profile.AXES = { "killer", "brawler", "anchor", "medic", "team", "objective" }
Profile.NAMES = { killer = "Killer", brawler = "Brawler", anchor = "Anchor", medic = "Medic", team = "Assists", objective = "Objective" }
Profile.SINGLE = { killer = "Killer", brawler = "Brawler", anchor = "Anchor", medic = "Medic", team = "Supporter", objective = "Runner" }
Profile.PAIR = {
    killer    = { brawler = "Slayer", anchor = "Duelist", medic = "Paladin", team = "Finisher", objective = "Hunter" },
    brawler   = { anchor = "Bruiser", medic = "Crusader", team = "Vanguard", objective = "Raider" },
    anchor    = { medic = "Guardian", team = "Bulwark", objective = "Sentinel" },
    medic     = { team = "Healer", objective = "Escort" },
    team      = { objective = "Captain" },
}
Profile.QUIET = "Quiet"
Profile.ACE = "Ace"
Profile.BALANCED = "Balanced"
Profile.SPREAD = 0.15
Profile.NEAR = 0.10
Profile.NEAR_STEPS = 1.5
Profile.FLOOR = 0.5
Profile.ACE_MEAN = 0.75

Profile.OBJ_FIELDS = {
    flag = { "caps", "carried", "carrierKills", "carrierDmg", "carrierHeal" },
    area = { "defPts", "capKillAtt", "capKillDef", "defHeal", "caps" },
}
local OBJ_KIND = { capture_the_flag = "flag", murderball = "flag", domination = "area", crazy_king = "area", king_of_the_hill = "area" }

local function mode_key(m)
    local C = BGMeter.zenimax.constants
    if m and m.gameType ~= nil and C.GAME_TYPE_LABEL then
        return C.GAME_TYPE_LABEL[m.gameType] or "none"
    end
    return "none"
end
Profile.mode_key = mode_key

function Profile.objective_fields(key)
    return Profile.OBJ_FIELDS[OBJ_KIND[key] or ""]
end

local function rank_of(values, n, i)
    local mine, below = values[i], 0
    for j = 1, n do
        if values[j] < mine then below = below + 1 end
    end
    return below / (n - 1)
end

local function objective_raws(m, key, n, out)
    for i = 1, n do out[i] = 0 end
    local fields = Profile.objective_fields(key)
    if not fields then return false end
    local col, used = {}, false
    for _, f in ipairs(fields) do
        local any = false
        for i = 1, n do
            local x = m.battle[i][f] or 0
            col[i] = x
            if x > 0 then any = true end
        end
        if any then
            used = true
            for i = 1, n do out[i] = out[i] + rank_of(col, n, i) end
        end
    end
    return used
end

function Profile.raw(row, out)
    out = out or {}
    out[1] = row.kills or 0
    out[2] = row.damage or 0
    out[3] = row.taken or 0
    out[4] = row.healing or 0
    out[5] = row.assists or 0
    return out
end

function Profile.compute(m)
    if not (m and m.battle and #m.battle >= 2) then return nil end
    local key = mode_key(m)
    local n = #m.battle
    local raws, obj = {}, {}
    for i = 1, n do raws[i] = Profile.raw(m.battle[i]) end
    local has_obj = key ~= "deathmatch" and objective_raws(m, key, n, obj)
    local na = has_obj and 6 or 5
    if has_obj then
        for i = 1, n do raws[i][6] = obj[i] end
    end
    local axes = {}
    for a = 1, na do axes[a] = Profile.AXES[a] end
    local players = {}
    for i = 1, n do
        players[i] = { row = m.battle[i], team = m.battle[i].team or 0, v = {} }
    end
    for a = 1, na do
        for i = 1, n do
            local mine, below = raws[i][a], 0
            for j = 1, n do
                if raws[j][a] < mine then below = below + 1 end
            end
            players[i].v[a] = below / (n - 1)
        end
    end
    local teams = {}
    for i = 1, n do
        local t = players[i].team
        local tm = teams[t]
        if not tm then
            tm = { v = {}, n = 0 }
            for a = 1, na do tm.v[a] = 0 end
            teams[t] = tm
        end
        tm.n = tm.n + 1
        for a = 1, na do tm.v[a] = tm.v[a] + players[i].v[a] end
    end
    for _, tm in pairs(teams) do
        for a = 1, na do tm.v[a] = tm.v[a] / tm.n end
    end
    local me = nil
    for i = 1, n do
        if players[i].row.isLocal then me = i end
    end
    return { mode = key, axes = axes, players = players, teams = teams, me = me, n = n }
end

function Profile.index_of(data, row)
    if not (data and row) then return nil end
    for i = 1, data.n do
        local r = data.players[i].row
        if r == row then return i end
    end
    local dn, cn = row.displayName, row.charName
    for i = 1, data.n do
        local r = data.players[i].row
        if (dn and dn ~= "" and r.displayName == dn) or (cn and cn ~= "" and r.charName == cn) then return i end
    end
    return nil
end

local scratch = {}

function Profile.classify(v, axes, n, out)
    local c = out or scratch
    local na = axes and #axes or 0
    c.name, c.kind, c.top, c.with, c.second, c.near = Profile.BALANCED, "balanced", nil, nil, nil, Profile.NEAR
    if na == 0 then return c end
    local top, ti, min, sum = -1, 1, 2, 0
    for a = 1, na do
        local x = v[a] or 0
        sum = sum + x
        if x > top then top, ti = x, a end
        if x < min then min = x end
    end
    local mean = sum / na
    c.mean = mean
    local near = Profile.NEAR
    if n and n > 1 then near = math.max(near, Profile.NEAR_STEPS / (n - 1)) end
    local second, si = -1, nil
    for a = 1, na do
        local x = v[a] or 0
        if a ~= ti and x > second then second, si = x, a end
    end
    c.top, c.second, c.near = ti, si, near
    if top < Profile.FLOOR then
        c.name, c.kind = Profile.QUIET, "quiet"
        return c
    end
    if min >= Profile.FLOOR and mean >= Profile.ACE_MEAN then
        c.name, c.kind = Profile.ACE, "ace"
        return c
    end
    if top - mean < Profile.SPREAD then return c end
    if si and second >= top - near then
        local a, b = axes[ti], axes[si]
        local pair = (Profile.PAIR[a] and Profile.PAIR[a][b]) or (Profile.PAIR[b] and Profile.PAIR[b][a])
        if pair then
            c.name, c.kind, c.with = pair, "pair", si
            return c
        end
    end
    c.name, c.kind = Profile.SINGLE[axes[ti]], "single"
    return c
end

function Profile.label(v, axes, n)
    return Profile.classify(v, axes, n).name
end

Profile.MEANING = {
    Killer = "Most kills on the board",
    Brawler = "Raw damage",
    Anchor = "Soaks the damage",
    Medic = "The heals",
    Supporter = "In every kill the team lands",
    Runner = "Lives on the objective",
    Slayer = "Kills and the damage behind them",
    Duelist = "Kills while soaking damage",
    Paladin = "Kills and heals",
    Finisher = "Lands the last hit in the team's fights",
    Hunter = "Kills around the objective",
    Bruiser = "Deals and takes the damage",
    Crusader = "Damage and heals",
    Vanguard = "Damage at the front of every fight",
    Raider = "Damage on the objective",
    Guardian = "Soaks and heals",
    Bulwark = "Soaks damage in every fight of the team",
    Sentinel = "Holds the objective and soaks for it",
    Healer = "Heals in every fight",
    Escort = "Heals the objective push",
    Captain = "In every fight, on the objective",
    Quiet = "Nothing above the match median",
    Ace = "Above the median on every axis",
    Balanced = "No dominant axis",
}

function Profile.meaning(name)
    return Profile.MEANING[name] or ""
end

function Profile.career(matches, limit)
    local sum, cnt = {}, {}
    for a = 1, 6 do sum[a], cnt[a] = 0, 0 end
    local used = 0
    for i = 1, #matches do
        if limit and used >= limit then break end
        local data = Profile.compute(matches[i])
        if data and data.me then
            used = used + 1
            local v = data.players[data.me].v
            for a = 1, #data.axes do
                sum[a] = sum[a] + v[a]
                cnt[a] = cnt[a] + 1
            end
        end
    end
    if used == 0 then return nil end
    local v, axes = {}, {}
    local na = 0
    for a = 1, 6 do
        if cnt[a] > 0 then
            na = na + 1
            axes[na] = Profile.AXES[a]
            v[na] = sum[a] / cnt[a]
        end
    end
    return { v = v, axes = axes, n = used }
end

BGMeter.Profile = Profile
