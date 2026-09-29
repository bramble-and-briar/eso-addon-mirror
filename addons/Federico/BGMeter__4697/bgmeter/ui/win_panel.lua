BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local set_text, mk_button = U.set_text, U.mk_button
local TX = U.TX

local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs

local Panel = {}

local TELVAR = CURT_TELVAR_STONES
local LINK_SIZE = 32
local CLAIM_SIZE = 20
local GLINT = "EsoUI/Art/HUD/starburst.dds"

local stats = nil
local host = nil

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function clean(s)
    if not s or s == "" then return nil end
    return (tostring(s):gsub("%^.*$", ""))
end

local TIERS = {
    { max = 10,   word = "Champion!", col = { 0.97, 0.97, 1.00 }, glow = 0.90, hue = true },
    { max = 25,   word = "Mythic!",   col = { 1.00, 0.55, 0.15 }, glow = 0.60 },
    { max = 50,   word = "Legendary", col = { 1.00, 0.84, 0.30 }, glow = 0.50 },
    { max = 100,  word = "Epic",      col = { 0.72, 0.53, 0.98 }, glow = 0.42 },
    { max = 250,  word = "Superior",  col = { 0.40, 0.68, 0.98 }, glow = 0.36 },
    { max = 500,  word = "Fine",      col = { 0.45, 0.82, 0.35 }, glow = 0.30 },
}
Panel.TIERS = TIERS

local FX = { name = "BGMeterStandingFx", ms = 40, on = false, t0 = 0, tier = nil, rank = 0 }
local BREATH_MS = 2600
local HUE_MS = 1200
local GLINT_MS = 3400
local GLINT_ON = 0.16
local SWEEP_FROM, SWEEP_TO = 0.16, 0.60
local SWEEP_WIDTH = 0.14
local SWEEP_FRAMES = 24

local function fx_now()
    if GetGameTimeMilliseconds then return GetGameTimeMilliseconds() end
    return os.clock() * 1000
end

local function hue_rgb(h)
    local x = (h % 1) * 6
    local i = math.floor(x)
    local f = x - i
    if i == 0 then return 1, f, 0 end
    if i == 1 then return 1 - f, 1, 0 end
    if i == 2 then return 0, 1, f end
    if i == 3 then return 0, 1 - f, 1 end
    if i == 4 then return f, 0, 1 end
    return 1, 0, 1 - f
end

local function trophy_tier(rank)
    for _, tier in ipairs(TIERS) do
        if rank <= tier.max then return tier end
    end
    return nil
end

function Panel.tier_of(rank) return trophy_tier(rank) end

local SWEEP_REST = 0.62

local function shimmer(word, col, spot, u)
    local n = #word
    local parts = {}
    for i = 1, n do
        local d = ((i - 0.5) / n - u) / SWEEP_WIDTH
        local w = math.exp(-d * d)
        local rest = SWEEP_REST + (1 - SWEEP_REST) * w
        local c = {
            col[1] * rest + (spot[1] - col[1] * rest) * w,
            col[2] * rest + (spot[2] - col[2] * rest) * w,
            col[3] * rest + (spot[3] - col[3] * rest) * w,
        }
        parts[i] = "|c" .. F.hexc(c) .. word:sub(i, i)
    end
    return table.concat(parts) .. "|r"
end

local function word_text(st, tier, u, spot)
    if u then return st.rankText .. " · " .. shimmer(tier.word, tier.col, spot or { 1, 1, 1 }, u) end
    return st.rankText .. " · |c" .. F.hexc(tier.col) .. tier.word .. "|r"
end

local function sweep_frames(st, tier)
    local frames = {}
    for f = 1, SWEEP_FRAMES do
        local u = (f - 1) / (SWEEP_FRAMES - 1) * 1.3 - 0.15
        local spot = nil
        if tier.hue then
            local r, g, b = hue_rgb((f - 1) / SWEEP_FRAMES)
            spot = { 0.55 + 0.45 * r, 0.55 + 0.45 * g, 0.55 + 0.45 * b }
        end
        frames[f] = word_text(st, tier, u, spot)
    end
    frames.rest = word_text(st, tier, nil)
    return frames
end

local function glint_set(ic, u, side)
    if not ic then return end
    if u == nil then ic:SetHidden(true) return end
    local s = math.sin(math.pi * u)
    ic:SetAlpha(s)
    ic:SetScale(0.5 + 0.7 * s)
    if ic.SetTextureRotation then ic:SetTextureRotation(u * math.pi * 0.5 * side) end
    ic:SetHidden(false)
end

function Panel.podium_stop()
    if not FX.on then return end
    FX.on = false
    FX.tier = nil
    BGMeter.zenimax.events.unregister_update(FX.name)
    local st = stats and stats.stand
    if st then glint_set(st.glint1, nil); glint_set(st.glint2, nil) end
end

local function fx_tick()
    local st = stats and stats.stand
    local tier = FX.tier
    if not (st and st.glow and tier) or host.win:IsHidden() then Panel.podium_stop() return end
    local t = fx_now() - FX.t0
    local breath = 0.82 + 0.18 * math.sin(2 * math.pi * t / BREATH_MS)
    local col = tier.col
    if tier.hue then
        local u = (t % HUE_MS) / HUE_MS
        local r, g, b = hue_rgb(u)
        st.glow:SetColor(0.45 + 0.55 * r, 0.45 + 0.55 * g, 0.45 + 0.55 * b, tier.glow * breath)
        local r2, g2, b2 = hue_rgb(u + 0.5)
        st.icon:SetColor(0.80 + 0.20 * r2, 0.80 + 0.20 * g2, 0.80 + 0.20 * b2, 1)
    else
        st.glow:SetColor(col[1], col[2], col[3], tier.glow * breath)
    end
    local g = (t % GLINT_MS) / GLINT_MS
    glint_set(st.glint1, (g < GLINT_ON) and (g / GLINT_ON) or nil, 1)
    local g2 = ((t + GLINT_MS / 2) % GLINT_MS) / GLINT_MS
    glint_set(st.glint2, (FX.rank == 1 and g2 < GLINT_ON) and (g2 / GLINT_ON) or nil, -1)
    local frames = st.sweepFrames
    if frames then
        if g >= SWEEP_FROM and g < SWEEP_TO then
            local f = math.floor((g - SWEEP_FROM) / (SWEEP_TO - SWEEP_FROM) * SWEEP_FRAMES) + 1
            if f > SWEEP_FRAMES then f = SWEEP_FRAMES end
            if st.frame ~= f then
                st.frame = f
                set_text(st.label, frames[f])
            end
        elseif st.frame ~= 0 then
            st.frame = 0
            set_text(st.label, frames.rest)
        end
    end
end

local function fx_start(tier, rank)
    FX.tier, FX.rank = tier, rank
    if FX.on then return end
    FX.on = true
    FX.t0 = fx_now()
    BGMeter.zenimax.events.register_update(FX.name, FX.ms, fx_tick)
    fx_tick()
end

function Panel.podium_on() return FX.on end

local function ensure_fx_controls(st)
    if st.glow then return end
    st.glow = P.icon(st.c, "bgmeter/assets/glow.dds")
    st.glow:SetAnchor(CENTER, st.icon, CENTER, 0, 0)
    st.glow:SetDimensions(64, 64)
    if st.glow.SetBlendMode then st.glow:SetBlendMode(TEX_BLEND_MODE_ADD) end
    if st.glow.SetDrawLevel then st.glow:SetDrawLevel(1) end
    if st.icon.SetDrawLevel then st.icon:SetDrawLevel(2) end
    st.glint1 = P.icon(st.c, GLINT)
    st.glint1:SetDimensions(14, 14)
    st.glint1:SetAnchor(CENTER, st.icon, TOPRIGHT, -8, 7)
    st.glint2 = P.icon(st.c, GLINT)
    st.glint2:SetDimensions(10, 10)
    st.glint2:SetAnchor(CENTER, st.icon, BOTTOMLEFT, 9, -9)
    for _, ic in ipairs({ st.glint1, st.glint2 }) do
        if ic.SetBlendMode then ic:SetBlendMode(TEX_BLEND_MODE_ADD) end
        if ic.SetDrawLevel then ic:SetDrawLevel(3) end
        ic:SetHidden(true)
    end
end

local vet_dirty = true

local function same(st, a, b, c, d, e, f, g)
    if st._k1 == a and st._k2 == b and st._k3 == c and st._k4 == d and st._k5 == e and st._k6 == f and st._k7 == g and st._keyed then
        return true
    end
    st._k1, st._k2, st._k3, st._k4, st._k5, st._k6, st._k7, st._keyed = a, b, c, d, e, f, g, true
    return false
end

function Panel.mark_vet_dirty() vet_dirty = true end

function Panel.stats() return stats end

local function refresh_ava()
    local A = BGMeter.zenimax.api
    local st = stats.ava
    local rank = safe(A.get_ava_rank)
    if not (rank and rank > 0) then st.c:SetHidden(true) return end
    st.c:SetHidden(false)
    local gender = safe(A.get_gender) or 1
    local pts = safe(A.get_ava_rank_points) or 0
    local base = safe(A.get_ava_points_needed, rank) or 0
    local nextNeed = safe(A.get_ava_points_needed, rank + 1)
    if same(st, rank, gender, pts, base, nextNeed) then return end
    local rname = clean(safe(A.get_ava_rank_name, gender, rank)) or "?"
    if st.icon then st.icon:SetTexture(safe(A.get_ava_rank_icon, rank) or "") end
    set_text(st.label, string.format("%s  %d", rname, rank))
    if nextNeed and nextNeed > pts then
        st.tip = string.format("Alliance War rank %d\n%s AP to the next rank", rank, F.commas(nextNeed - pts))
    else
        st.tip = string.format("Alliance War rank %d", rank)
    end
    if st.bar then
        if nextNeed and nextNeed > base then
            local pct = math.max(0, math.min(1, (pts - base) / (nextNeed - base)))
            U.inset_bar_set(st.bar, pct, K.COLOR.gold, st.barW)
            st.bar.container:SetHidden(false)
        else
            st.bar.container:SetHidden(true)
        end
    end
end

local function refresh_vet()
    local A = BGMeter.zenimax.api
    local st = stats.vet
    if not vet_dirty and st._seen then return end
    vet_dirty, st._seen = false, true
    local snap = BGMeter.Veterancy and BGMeter.Veterancy.snapshot()
    if st.link then st.link:SetHidden(not (snap and snap.rank)) end
    if not (snap and snap.rank) then st.c:SetHidden(true) return end
    st.c:SetHidden(false)
    if st.icon then
        st.icon:SetTexture(safe(A.get_veterancy_rank_icon, snap.iconRank or snap.rank, snap.seasonId)
            or snap.rankIcon or "")
    end
    local laps = snap.laps or 0
    set_text(st.label, string.format("%s  %d%s", clean(snap.rankTitle) or "Veterancy", snap.rank,
        laps > 0 and (" ×" .. laps) or ""))
    local waiting = snap.claimable or 0
    if st.claim then
        st.claim:SetHidden(waiting <= 0)
        st.claim_tip = string.format("Claim your veterancy rewards (%d waiting)", waiting)
        st.label:ClearAnchors()
        st.label:SetAnchor(TOPLEFT, st.c, TOPLEFT, st.textX, 3)
        st.label:SetAnchor(TOPRIGHT, st.c, TOPRIGHT, waiting > 0 and -(LINK_SIZE + CLAIM_SIZE + 4) or -(LINK_SIZE + 2), 3)
    end
    local season = clean(snap.seasonName)
    local seasonLine = season and ("\n" .. season) or ""
    if snap.tierTotal and snap.tierTotal > 0 then
        st.tip = string.format("Veterancy rank %d%s\n%s / %s to the next %s%s",
            snap.rank, laps > 0 and string.format("  ·  max rank, reward ×%d", laps) or "",
            F.commas(snap.progressToNext or 0), F.commas(snap.tierTotal),
            snap.pastMax and "reward" or "rank", seasonLine)
    else
        st.tip = string.format("Veterancy rank %d%s", snap.rank, seasonLine)
    end
    if st.bar then
        if snap.percent then
            local pct = math.max(0, math.min(1, snap.percent))
            U.inset_bar_set(st.bar, pct, K.COLOR.veterancy, st.barW)
            st.bar.container:SetHidden(false)
        else
            st.bar.container:SetHidden(true)
        end
    end
end

local function refresh_standing()
    local st = stats.stand
    local sv = BGMeter.zenimax.savedvars.get()
    local standing = sv and sv.standing
    local demo = BGMeter.UI.menu and BGMeter.UI.menu._demo_rank
    if demo then standing = { rank = demo, score = 123456 } end
    st.c:SetHidden(false)
    if st.link then st.link:SetHidden(false) end
    if same(st, standing and standing.rank or 0, standing and standing.score or 0, demo or 0, Prefs.get("animate") and 1 or 0) then return end
    if standing and (standing.rank or 0) > 0 then
        local tier = trophy_tier(standing.rank)
        if st.icon then
            st.icon:SetTexture(tier and "EsoUI/Art/Inventory/inventory_tabIcon_trophy_up.dds"
                or "EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds")
            local tierTag = ""
            if tier then
                ensure_fx_controls(st)
                local col = tier.col
                st.icon:SetColor(col[1], col[2], col[3], 1)
                st.glow:SetColor(col[1], col[2], col[3], tier.glow)
                st.glow:SetHidden(false)
                st.rankText = "#" .. F.commas(standing.rank)
                st.sweepFrames = sweep_frames(st, tier)
                st.frame = 0
                if Prefs.get("animate") then fx_start(tier, standing.rank) else Panel.podium_stop() end
                tierTag = string.format(" · |c%s%s|r", F.hexc(col), tier.word)
            else
                Panel.podium_stop()
                st.icon:SetColor(1, 1, 1, 1)
                if st.glow then st.glow:SetHidden(true) end
            end
            st.tierTag = tierTag
        end
        set_text(st.label, "#" .. F.commas(standing.rank) .. (st.tierTag or ""))
        S.color(st.label, K.COLOR.gold)
        st.tip = string.format("Competitive standing\nrating %s", F.commas(standing.score or 0))
    else
        Panel.podium_stop()
        if st.icon then
            st.icon:SetTexture("EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds")
            st.icon:SetColor(1, 1, 1, 1)
            if st.glow then st.glow:SetHidden(true) end
        end
        set_text(st.label, "unranked")
        S.color(st.label, K.COLOR.text_dim)
        if standing and (standing.score or 0) > 0 then
            st.tip = string.format("Competitive standing\nrating %s", F.commas(standing.score))
        else
            st.tip = "Competitive standing\nplay a ranked battleground to appear"
        end
    end
end

local function refresh_currencies()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local st = stats.ap
    st.c:SetHidden(false)
    local ap = safe(A.get_alliance_points) or 0
    if not same(st, ap) then
        if st.icon then st.icon:SetTexture(safe(A.get_currency_icon, C.CURT_ALLIANCE_POINTS) or "") end
        set_text(st.label, F.commas(ap))
        st.tip = "Alliance Points"
    end

    st = stats.telvar
    if TELVAR then
        st.c:SetHidden(false)
        local tv = safe(A.get_currency, TELVAR, C.CURRENCY_LOCATION_CHARACTER) or 0
        if not same(st, tv) then
            if st.icon then st.icon:SetTexture(safe(A.get_currency_icon, TELVAR) or "") end
            set_text(st.label, F.commas(tv))
            st.tip = "Tel Var Stones"
        end
    else
        st.c:SetHidden(true)
    end
end

local function refresh_session()
    local st = stats.session
    local sess = BGMeter.Session
    local lrev = BGMeter.Ledger and BGMeter.Ledger.rev and BGMeter.Ledger.rev() or 0
    local hrev = BGMeter.History.rev and BGMeter.History.rev() or 0
    if same(st, sess and sess.matches or 0, sess and sess.wins or 0, sess and sess.losses or 0, sess and sess.streak or 0, sess and sess.ap or 0, sess and sess.xp or 0, lrev * 100003 + hrev) then
        st.c:SetHidden(false)
        return
    end
    if sess and sess.matches > 0 then
        if (sess.streak or 0) >= 2 then
            set_text(st.label, string.format("%dW-%dL  ·  %dx streak", sess.wins, sess.losses, sess.streak))
        else
            set_text(st.label, string.format("%dW-%dL tonight", sess.wins, sess.losses))
        end
        local col = K.COLOR.text_dim
        if sess.wins > sess.losses then col = K.COLOR.heal
        elseif sess.losses > sess.wins then col = K.COLOR.accent end
        S.color(st.label, col)
        st.tip = string.format("This play session\n%d battlegrounds%s\n%s AP  ·  %s XP earned",
            sess.matches,
            (sess.streak or 0) >= 2 and string.format("\n%d wins in a row", sess.streak) or "",
            F.commas(sess.ap), F.commas(sess.xp))
    else
        local tot = BGMeter.Ledger and BGMeter.Ledger.totals() or { n = 0, w = 0, l = 0, t = 0 }
        local n, aw, al = tot.n, tot.w, tot.l
        if n == 0 then
            local Hist = BGMeter.History
            n = Hist.count()
            for i = 1, n do
                local m = Hist.get(i)
                if m.result == "WIN" then aw = aw + 1 elseif m.result == "LOSS" then al = al + 1 end
            end
        end
        if n > 0 then
            set_text(st.label, string.format("%dW-%dL all time", aw, al))
            local col = K.COLOR.text_dim
            if aw > al then col = K.COLOR.heal elseif al > aw then col = K.COLOR.accent end
            S.color(st.label, col)
            st.tip = string.format("Every battleground recorded since the ledger began\n%d battles%s\nNo battles yet this session", n,
                (tot.t > 0) and string.format("  ·  %d tied", tot.t) or "")
        else
            set_text(st.label, "no battles yet")
            S.color(st.label, K.COLOR.text_dim)
            st.tip = "This play session (since login)"
        end
    end
    st.c:SetHidden(false)
end

local function refresh_balance()
    local st = stats.balance
    local Ledger = BGMeter.Ledger
    if not (st and Ledger and Ledger.recent_balance) then return end
    if same(st, Ledger.rev and Ledger.rev() or 0, BGMeter.History.rev and BGMeter.History.rev() or 0) then return end
    local recent, rn = Ledger.recent_balance(20)
    if not recent then
        st.c:SetHidden(true)
        return
    end
    st.c:SetHidden(false)
    if st.icon then
        st.icon:SetTexture(BGMeter.Icons.BALANCE)
        st.icon:SetColor(K.COLOR.text[1], K.COLOR.text[2], K.COLOR.text[3], 1)
    end
    local score = math.floor(recent + 0.5)
    set_text(st.label, string.format("balance %d", score))
    S.color(st.label, U.balance_color(score))
    local all = Ledger.balance()
    local lines = {
        string.format("Match balance, your last %d %s: %d / 100", rn, (rn == 1) and "match" or "matches", score),
    }
    if all.n > 0 then
        lines[#lines + 1] = string.format("all time %d over %d matches%s%s", math.floor(all.avg + 0.5), all.n,
            all.wavg and string.format("  ·  wins %d", math.floor(all.wavg + 0.5)) or "",
            all.lavg and string.format("  ·  losses %d", math.floor(all.lavg + 0.5)) or "")
    end
    st.tip = table.concat(lines, "\n")
end

function Panel.refresh()
    if not stats then return end
    refresh_ava()
    refresh_vet()
    refresh_standing()
    refresh_currencies()
    refresh_session()
    refresh_balance()
end

local function make_stat(pw, rowi, right, withIcon, withBar, link)
    local c = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL)
    local rowH = right and 28 or 38
    local iconS = right and 26 or 38
    local pad = right and 6 or 9
    c:SetHeight(rowH)
    c:SetMouseEnabled(true)
    local y = host.head_h + (rowi - 1) * (right and 30 or 40)
    if right then
        c:SetAnchor(TOPRIGHT, pw, TOPRIGHT, -(host.inset_pad + 2), y)
        c:SetWidth(126)
    else
        c:SetAnchor(TOPLEFT, pw, TOPLEFT, host.inset_pad + 2, y)
        c:SetWidth(216)
    end
    local st = { c = c }
    if withIcon then
        st.icon = P.icon(c)
        st.icon:SetDimensions(iconS, iconS)
        st.icon:SetAnchor(LEFT, c, LEFT, 0, 0)
    end
    local textX = withIcon and (iconS + pad) or 2
    st.label = P.label(c, right and S.FONT.small or S.FONT.row, K.COLOR.text)
    U.clamp_line(st.label)
    local linkInset = link and -(LINK_SIZE + 2) or 0
    if withBar then
        st.label:SetAnchor(TOPLEFT, c, TOPLEFT, textX, 3)
        st.label:SetAnchor(TOPRIGHT, c, TOPRIGHT, linkInset, 3)
        st.label:SetHeight(20)
        if link then
            st.link = mk_button(c, link.tx, LINK_SIZE, link.fn, link.tip)
            st.link:SetAnchor(RIGHT, c, RIGHT, 4, 0)
            st.link:SetHidden(true)
            if link.claim then
                st.textX = textX
                st.claim = mk_button(c, TX.satchel, CLAIM_SIZE, link.claim, nil)
                st.claim:SetAnchor(TOPRIGHT, c, TOPRIGHT, -(LINK_SIZE + 2), 1)
                st.claim:SetHidden(true)
                st.claim:SetHandler("OnMouseEnter", function(b)
                    if U.card_show then U.card_show(b, BOTTOM, st.claim_tip or "") end
                end)
                st.claim:SetHandler("OnMouseExit", function()
                    if U.card_hide then U.card_hide() end
                end)
            end
        end
        st.bar = U.inset_bar(c)
        st.bar.container:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, textX, -3)
        st.bar.container:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, linkInset, -3)
        st.bar.container:SetHeight(9)
        st.barW = 216 - textX + linkInset
    else
        st.label:SetAnchor(LEFT, c, LEFT, textX, 0)
        st.label:SetAnchor(RIGHT, c, RIGHT, linkInset, 0)
        st.label:SetHeight(rowH)
        if link then
            st.link = mk_button(c, link.tx, LINK_SIZE, link.fn, link.tip)
            st.link:SetAnchor(RIGHT, c, RIGHT, 4, 0)
            st.link:SetHidden(true)
        end
    end
    c:SetHandler("OnMouseEnter", function()
        if st.tip and U.card_show then U.card_show(c, BOTTOM, st.tip) end
    end)
    c:SetHandler("OnMouseExit", function()
        if U.card_hide then U.card_hide() end
    end)
    return st
end

function Panel.build(pw, opts)
    host = { win = pw, head_h = opts.head_h, inset_pad = opts.inset_pad }
    stats = {
        ava     = make_stat(pw, 1, false, true, true),
        vet     = make_stat(pw, 2, false, true, true, { tx = TX.vet, fn = opts.open_veterancy, tip = "View veterancy",
                                                      claim = opts.claim_veterancy }),
        stand   = make_stat(pw, 3, false, true, false, { tx = TX.board, fn = opts.open_leaderboard, tip = "View competitive leaderboard" }),
        ap      = make_stat(pw, 1, true, true),
        telvar  = make_stat(pw, 2, true, true),
        session = make_stat(pw, 3, true, false),
        balance = make_stat(pw, 4, true, true),
    }
    for _, key in ipairs({ "ap", "telvar" }) do
        local lbl = stats[key].label
        if lbl.SetFont then lbl:SetFont(S.FONT.row) end
    end
    return stats
end

function Panel.stats() return stats end

function Panel.stat_text(key) return stats and stats[key] and stats[key].label:GetText() or nil end

function Panel.stat_link_hidden(key)
    local st = stats and stats[key]
    return not (st and st.link) or st.link:IsHidden()
end

function Panel.stat_link_texture(key)
    local st = stats and stats[key]
    return st and st.link and st.link._tex_normal or nil
end

function Panel.stat_claim_hidden(key)
    local st = stats and stats[key]
    return not (st and st.claim) or st.claim:IsHidden()
end

function Panel.stat_claim_tip(key)
    local st = stats and stats[key]
    return st and st.claim_tip or nil
end

BGMeter.UI.panel = Panel
