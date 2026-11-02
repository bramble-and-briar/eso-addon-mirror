
BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Standing = {}

local pending = nil

Standing.TIERS = {
    { max = 10,   word = "Champion!", col = { 0.97, 0.97, 1.00 }, glow = 0.90, hue = true, sheen = true, fx = "glitter", fxcol = { 1, 1, 1 },
      metal_tex = "bgmeter/assets/trophies/trophy_champion_metal.dds", glass_tex = "bgmeter/assets/trophies/trophy_champion_glass.dds" },
    { max = 25,   word = "Mythic!",   col = { 1.00, 0.55, 0.15 }, glow = 0.60, glass = { 1.00, 0.22, 0.12 }, sheen = true, fx = "embers", fxcol = { 1.00, 0.45, 0.10 },
      metal_tex = "bgmeter/assets/trophies/trophy_mythic_metal.dds", glass_tex = "bgmeter/assets/trophies/trophy_mythic_glass.dds" },
    { max = 50,   word = "Legendary", col = { 1.00, 0.84, 0.30 }, glow = 0.50, sheen = true, fx = "glitter" },
    { max = 100,  word = "Epic",      col = { 0.72, 0.53, 0.98 }, glow = 0.42, sheen = true },
    { max = 250,  word = "Superior",  col = { 0.40, 0.68, 0.98 }, glow = 0.36, sheen = true },
    { max = 500,  word = "Fine",      col = { 0.45, 0.82, 0.35 }, glow = 0.30 },
}

function Standing.tier_of(rank)
    if not rank or rank <= 0 then return nil end
    for _, tier in ipairs(Standing.TIERS) do
        if rank <= tier.max then return tier end
    end
    return nil
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function read_mmr()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    for _, act in ipairs({ C.LFG_ACTIVITY_BG_CHAMPION, C.LFG_ACTIVITY_BG_NON_CHAMPION, C.LFG_ACTIVITY_BG_LOW_LEVEL }) do
        if act ~= nil then
            local mmr = safe(A.get_player_mmr, act)
            if mmr and mmr > 0 then return mmr end
        end
    end
    return nil
end

function Standing.read()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local rank, score = safe(A.get_bg_leaderboard_local, C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE)
    return {
        rank    = rank or 0,
        score   = score or 0,
        mmr     = read_mmr(),
        impacts = safe(A.does_bg_impact_mmr) and true or false,
    }
end

local function diff_and_store(cur)
    local sv = BGMeter.zenimax.savedvars.get()
    local prev = (sv and sv.standing) or { rank = 0, score = 0 }

    cur.prevRank   = prev.rank or 0
    cur.prevScore  = prev.score or 0
    cur.rankDelta  = (cur.prevRank > 0 and cur.rank > 0) and (cur.prevRank - cur.rank) or 0
    cur.scoreDelta = (cur.prevScore > 0) and (cur.score - cur.prevScore) or 0
    cur.improved   = cur.rankDelta > 0 or (cur.rankDelta == 0 and cur.scoreDelta > 0)

    if sv then
        sv.standing = { rank = cur.rank, score = cur.score }
    end
    return cur
end

function Standing.celebrate(rank)
    if not (CENTER_SCREEN_ANNOUNCE and CSA_CATEGORY_LARGE_TEXT) then return end
    local sound = BGMeter.Prefs and BGMeter.Prefs.get("sounds") and SOUNDS and SOUNDS.ACHIEVEMENT_AWARDED or nil
    local ok, mp = pcall(function()
        return CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
    end)
    if not ok or not mp then return end
    if CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST and mp.SetCSAType then
        mp:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST)
    end
    mp:SetText("|cF2CC59TOP 100|r", string.format("competitive leaderboard  ·  rank #%d", rank))
    pcall(function() CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(mp) end)
end

function Standing.apply()
    local cur = diff_and_store(Standing.read())
    local match = pending or BGMeter.History.most_recent()
    if match then
        match.standing = cur
        BGMeter.Records.note_rank(match, cur.rank)
        if match.records and match.records.rank then BGMeter.Sound.play("pb") end
    end
    pending = nil

    if cur.rank > 0 and cur.rank <= 100 and (cur.prevRank == 0 or cur.prevRank > 100) then
        Standing.celebrate(cur.rank)
    end
    local banner = BGMeter.UI and BGMeter.UI.tierup
    if banner and cur.rank > 0 then
        local newTier, prevTier = Standing.tier_of(cur.rank), Standing.tier_of(cur.prevRank)
        if newTier and (not prevTier or newTier.max < prevTier.max) then banner.show(newTier, cur.rank) end
    end

    BGMeter.Log.debug("standing: rank=%d (Δ%d) score=%d (Δ%d)",
        cur.rank, cur.rankDelta, cur.score, cur.scoreDelta)

    if BGMeter.UI and BGMeter.UI.window and BGMeter.UI.window.refresh_if_visible then
        BGMeter.UI.window.refresh_if_visible()
    end
    if BGMeter.UI and BGMeter.UI.menu and BGMeter.UI.menu.refresh_if_visible then
        BGMeter.UI.menu.refresh_if_visible()
    end
    return cur
end

function Standing.request(match)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    pending = match
    local ready = safe(A.query_bg_leaderboard, C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE)
    if ready == C.LEADERBOARD_DATA_READY then
        Standing.apply()
    end
end

function Standing.on_data(_, leaderboardType)
    local C = BGMeter.zenimax.constants
    if leaderboardType ~= nil and leaderboardType ~= C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE then
        return
    end
    Standing.apply()
end

BGMeter.Standing = Standing
