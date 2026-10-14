BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local SEC = U.SEC
local set_text, set_count, set_bar, pop, hide_all, hit_proxy = U.set_text, U.set_count, U.set_bar, U.pop, U.hide_all, U.hit_proxy
local ICON_STAR, ICON_SORTUP, ICON_SORTDN = U.ICON_STAR, U.ICON_SORTUP, U.ICON_SORTDN

local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Bar = BGMeter.Plot.bar
local Icons = BGMeter.Icons
local Prefs = BGMeter.Prefs

local MEDAL_PERROW, MEDAL_STEP, MEDAL_CAP = 7, 24, 14
local SHARE_SIZE = 26
local SHARE_COLS = 3
local SHARE_ROW_GAP = 4
local SHARE_MIN_FREE = 60
local EFF_BOTTOM = 335
local STAND_H = 70
local SHARE_KEYS = { "dmg", "heal", "kills", "taken", "obj", "medals" }
local RINGS_H = SHARE_ROW_GAP + 2 * (SHARE_SIZE + SHARE_ROW_GAP)
local MINI_GAP = 10
local RADAR_MIN = 110
local MINI_OUTER_MIN = 130
local function gold_line() return { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.22 } end
local flag_col_spec, caps_count = U.flag_col_spec, U.caps_count
local Donut = BGMeter.Plot.donut
local SHARE_TRACK = { 0.50, 0.50, 0.56, 0.28 }

local medal_card = nil

local function build_medal_card()
    if medal_card then return medal_card end
    local root = BGMeter.zenimax.ui.create_control(nil, W.win, CT_CONTROL)
    root:SetDimensions(280, 96)
    root:SetDrawLevel(30)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)

    local bg = P.rect(root, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.98 })
    bg:SetAnchorFill(root)
    P.frame(root):SetAnchorFill(root)

    local strip = P.rect(root, K.COLOR.gold)
    strip:SetAnchor(TOPLEFT, root, TOPLEFT, 4, 4)
    strip:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 4, -4)
    strip:SetWidth(2)

    local icon = P.icon(root)
    icon:SetDimensions(40, 40)
    icon:SetAnchor(TOPLEFT, root, TOPLEFT, 14, 12)

    local name = P.label(root, S.FONT.header, K.COLOR.text)
    U.clamp_line(name)
    name:SetAnchor(TOPLEFT, root, TOPLEFT, 64, 12)
    name:SetDimensions(202, 20)

    local count = P.label(root, S.FONT.small, K.COLOR.gold)
    count:SetAnchor(TOPLEFT, root, TOPLEFT, 64, 34)
    count:SetDimensions(202, 14)

    local cond = P.label(root, S.FONT.small, K.COLOR.text_dim)
    cond:SetAnchor(TOPLEFT, root, TOPLEFT, 14, 60)
    cond:SetWidth(252)

    local reward = P.label(root, S.FONT.small, K.COLOR.gold)
    reward:SetDimensions(252, 14)

    medal_card = { root = root, icon = icon, name = name, count = count, cond = cond, reward = reward }
    return medal_card
end

local function hide_medal_card()
    if medal_card then medal_card.root:SetHidden(true) end
end

local function show_medal_card(mi)
    local id = mi.bgmMedalId
    local n = mi.bgmMedalCount or 1
    BGMeter.Log.debug("medal hover: id=%s x%d", tostring(id), n)
    local info = id and Icons.medal_info(id) or nil
    if not info then return end
    local c = build_medal_card()

    c.icon:SetTexture(info.icon)
    set_text(c.name, info.name)
    set_text(c.count, (n > 1) and ("earned x" .. n) or "earned this match")

    local ch = 0
    if info.condition and info.condition ~= "" then
        set_text(c.cond, info.condition)
        ch = math.max(14, c.cond:GetTextHeight() or 14)
    else
        set_text(c.cond, "")
    end
    c.cond:SetHeight(ch)

    local rtext = (info.reward and info.reward > 0)
        and string.format("+%s score%s", F.commas(info.reward), n > 1 and " each" or "") or ""
    set_text(c.reward, rtext)
    c.reward:ClearAnchors()
    c.reward:SetAnchor(TOPLEFT, c.cond, BOTTOMLEFT, 0, 4)

    c.root:SetHeight(math.max(60 + ch + ((rtext ~= "") and 22 or 6), 64))
    c.root:ClearAnchors()
    c.root:SetAnchor(TOPRIGHT, mi, TOPLEFT, -10, -6)
    c.root:SetHidden(false)
end

local function build_haul(win)
    local p = {}
    local PAD = 16
    local INNER = L.haul_w - 2 * PAD

    p.container = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    p.container:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.margin, L.header_h)
    p.container:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -L.margin, -L.footer_h)
    p.container:SetWidth(L.haul_w)

    p.bd = P.backdrop(p.container)
    p.bd:SetAnchorFill(p.container)
    P.frame(p.container):SetAnchorFill(p.container)

    p.heading = P.label(p.container, S.FONT.header, K.COLOR.gold)
    p.heading:SetText("YOUR HAUL")
    p.heading:SetAnchor(TOP, p.container, TOP, 0, 14)

    p.vetIcon = P.icon(p.container)
    p.vetIcon:SetDimensions(46, 46)
    p.vetIcon:SetAnchor(TOPLEFT, p.container, TOPLEFT, PAD, 44)

    p.vetTitle = P.label(p.container, S.FONT.row, K.COLOR.veterancy)
    U.clamp_line(p.vetTitle)
    p.vetTitle:SetAnchor(TOPLEFT, p.vetIcon, TOPRIGHT, 12, 6)
    p.vetTitle:SetDimensions(INNER - 64, 22)
    p.vetTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    p.vetTier = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(p.vetTier)
    p.vetTier:SetAnchor(TOPLEFT, p.vetTitle, BOTTOMLEFT, 0, 8)
    p.vetTier:SetDimensions(INNER - 64, 18)

    p.track = Bar.create(p.container)
    p.track.container:SetAnchor(TOPLEFT, p.vetIcon, BOTTOMLEFT, 0, 10)
    p.track.container:SetDimensions(INNER, 12)

    p.vetDelta = P.label(p.container, S.FONT.small, K.COLOR.veterancy)
    U.clamp_line(p.vetDelta)
    p.vetDelta:SetAnchor(TOPLEFT, p.track.container, BOTTOMLEFT, 0, 8)
    p.vetDelta:SetDimensions(INNER, 16)

    p.div1 = P.rect(p.container, gold_line())
    p.div1:SetAnchor(TOPLEFT, p.vetDelta, BOTTOMLEFT, 0, 8)
    p.div1:SetDimensions(INNER, 1)

    local VAL_W = 74
    local NAME_W = INNER - 22 - 8 - VAL_W - 4
    local function receipt_line(anchorTo, dy, iconTex)
        local icon = P.icon(p.container, iconTex)
        icon:SetDimensions(22, 22)
        icon:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, dy)
        local name = P.label(p.container, S.FONT.row, K.COLOR.text_dim)
        name:SetAnchor(LEFT, icon, RIGHT, 8, 0)
        name:SetDimensions(NAME_W, 22)
        name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local val = P.label(p.container, S.FONT.row, K.COLOR.gold)
        val:SetAnchor(LEFT, name, RIGHT, 4, 0)
        val:SetDimensions(VAL_W, 22)
        val:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        val:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return { icon = icon, name = name, val = val }
    end
    p.ap = receipt_line(p.div1, 8, Icons.ap()); p.ap.name:SetText("Alliance Pts")
    p.xp = receipt_line(p.ap.icon, 8, Icons.XP); p.xp.name:SetText("Experience")
    p.cp = receipt_line(p.xp.icon, 8, Icons.CP); p.cp.name:SetText("Champion Pts")

    p.medalLabel = P.label(p.container, S.FONT.row, K.COLOR.text_dim)
    U.clamp_line(p.medalLabel)
    p.medalLabel:SetText("Medals")
    p.div2 = P.rect(p.container, gold_line())
    p.div2:SetAnchor(TOPLEFT, p.cp.icon, BOTTOMLEFT, 0, 8)
    p.div2:SetDimensions(INNER, 1)
    p.medalLabel:SetAnchor(TOPLEFT, p.div2, BOTTOMLEFT, 0, 8)
    p.medalLabel:SetDimensions(INNER, 18)
    p.medalIcons = {}
    p.medalBadges = {}
    for i = 1, MEDAL_CAP do
        local col = (i - 1) % MEDAL_PERROW
        local rowN = math.floor((i - 1) / MEDAL_PERROW)
        local mi = P.icon(p.container)
        mi:SetDimensions(22, 22)
        mi:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, col * MEDAL_STEP, 6 + rowN * MEDAL_STEP)
        mi:SetHidden(true)
        p.medalIcons[i] = mi

        local badge = P.label(p.container, S.FONT.small, K.COLOR.gold)
        badge:SetAnchor(BOTTOMRIGHT, mi, BOTTOMRIGHT, 3, 3)
        badge:SetDimensions(20, 12)
        badge:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        badge:SetDrawLevel(5)
        badge:SetHidden(true)
        p.medalBadges[i] = badge
    end
    p.medalMore = P.label(p.container, S.FONT.small, K.COLOR.medal)
    p.medalMore:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, 0, 6 + 2 * MEDAL_STEP)

    p.div3 = P.rect(p.container, gold_line())
    p.div3:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, 0, 14 + 2 * MEDAL_STEP)
    p.div3:SetDimensions(INNER, 1)

    p.share = {}
    local cellW = math.floor(INNER / SHARE_COLS)
    for i, key in ipairs(SHARE_KEYS) do
        local s = {}
        local col = (i - 1) % SHARE_COLS
        local row = math.floor((i - 1) / SHARE_COLS)
        s.donut = Donut.new("BGMeterShare" .. key, p.container, SHARE_SIZE, { track = SHARE_TRACK })
        s.donut:control():SetAnchor(TOPLEFT, p.div3, BOTTOMLEFT, col * cellW, SHARE_ROW_GAP + row * (SHARE_SIZE + SHARE_ROW_GAP))
        s.pct = P.label(p.container, S.FONT.small, K.COLOR.text)
        U.clamp_line(s.pct)
        s.pct:SetAnchor(TOPLEFT, s.donut:control(), TOPRIGHT, 4, 0)
        s.pct:SetDimensions(cellW - SHARE_SIZE - 6, 13)
        s.name = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
        U.clamp_line(s.name)
        s.name:SetAnchor(TOPLEFT, s.donut:control(), TOPRIGHT, 4, 13)
        s.name:SetDimensions(cellW - SHARE_SIZE - 6, 12)
        s.hit = hit_proxy(s.donut:control())
        W.tip_dynamic(s.hit)
        p.share[key] = s
    end

    p.div4 = P.rect(p.container, gold_line())
    p.div4:SetAnchor(TOPLEFT, p.div3, BOTTOMLEFT, 0, RINGS_H + 6)
    p.div4:SetDimensions(INNER, 1)
    p.div4:SetHidden(true)

    p.radar = BGMeter.UI.radar.new(p.container, "haul.profile")
    p.radar:layout(INNER, RADAR_MIN)
    p.radar.root:SetHidden(true)
    p.radarSide = RADAR_MIN
    p.archetype = P.label(p.container, S.FONT.row, K.COLOR.gold)
    U.clamp_line(p.archetype)
    p.archetype:SetDimensions(INNER, 18)
    p.archetype:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.archetype:SetHidden(true)
    W.tip_dynamic(p.archetype)
    p.profileFor, p.profile, p.profileHover = nil, nil, nil

    p.sep = P.rect(p.container, gold_line())
    p.sep:SetAnchor(BOTTOMLEFT, p.container, BOTTOMLEFT, PAD, -STAND_H)
    p.sep:SetDimensions(INNER, 1)

    p.standHeading = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    p.standHeading:SetText("COMPETITIVE STANDING")
    p.standHeading:SetAnchor(TOPLEFT, p.sep, BOTTOMLEFT, 0, 8)
    p.standHeading:SetDimensions(INNER, 16)
    p.standHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    p.standRank = P.label(p.container, S.FONT.big, K.COLOR.text)
    p.standRank:SetAnchor(TOPLEFT, p.standHeading, BOTTOMLEFT, 0, 2)
    p.standRank:SetDimensions(math.floor(INNER * 0.5) - 5, 30)
    p.standRank:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    p.standRank:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    p.standSub = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(p.standSub)
    p.standSub:SetAnchor(TOPLEFT, p.standRank, TOPRIGHT, 10, 0)
    p.standSub:SetDimensions(INNER - math.floor(INNER * 0.5) - 5, 30)
    p.standSub:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    p.standSub:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    W.tip_static(hit_proxy(p.ap.icon), "Alliance Points earned this match")
    W.tip_static(hit_proxy(p.xp.icon), "Experience earned this match")
    W.tip_static(hit_proxy(p.cp.icon), "Champion Points earned this match")
    p.vetIconHit = hit_proxy(p.vetIcon)
    W.tip_dynamic(p.vetIconHit)
    W.tip_dynamic(p.standRank)
    p.medalHits = {}
    for i = 1, #p.medalIcons do
        local mi = p.medalIcons[i]
        local hit = hit_proxy(mi)
        hit:SetMouseEnabled(true)
        hit:SetHidden(true)
        hit:SetHandler("OnMouseEnter", function() show_medal_card(mi) end)
        hit:SetHandler("OnMouseExit", hide_medal_card)
        p.medalHits[i] = hit
    end
    return p
end

local SHARE_COLORS = { K.COLOR.you }

function SEC.haul_share_free()
    return (W.cur_h or L.window_h) - L.header_h - L.footer_h - STAND_H - EFF_BOTTOM
end

local function share_hide(s)
    s.donut:set_hidden(true); s.pct:SetHidden(true); s.name:SetHidden(true); s.hit:SetHidden(true)
end

local function share_set(s, mine, team, name, what, fmt)
    if not team or team <= 0 then share_hide(s) return end
    mine = math.min(mine, team)
    s.donut:set({ mine }, SHARE_COLORS, team)
    set_text(s.pct, string.format("%d%%", math.floor(mine / team * 100 + 0.5)))
    set_text(s.name, name)
    W.tips[s.hit] = what .. "\n" .. fmt(mine) .. " of " .. fmt(team)
    s.donut:set_hidden(false); s.pct:SetHidden(false); s.name:SetHidden(false); s.hit:SetHidden(false)
end

local function count_fmt(v) return F.commas(math.floor(v + 0.5)) end
local function time_fmt(v) return F.duration(v * 1000) end

function SEC.haul_share(m, lr)
    local p = W.haul
    local show = lr ~= nil and SEC.haul_share_free() >= SHARE_MIN_FREE
    if not show then
        for _, s in pairs(p.share) do share_hide(s) end
        return false
    end
    local t = { dmg = 0, heal = 0, kills = 0, taken = 0, caps = 0, carried = 0, medals = 0 }
    for _, row in ipairs(m.battle) do
        if row.team == lr.team then
            t.dmg = t.dmg + (row.damage or 0)
            t.heal = t.heal + (row.healing or 0)
            t.kills = t.kills + (row.kills or 0)
            t.taken = t.taken + (row.taken or 0)
            t.caps = t.caps + (row.caps or 0)
            t.carried = t.carried + (row.carried or 0)
            t.medals = t.medals + (row.medals or 0)
        end
    end
    share_set(p.share.dmg, lr.damage or 0, t.dmg, "dmg", "Your share of your team's damage", F.abbrev)
    share_set(p.share.heal, lr.healing or 0, t.heal, "heal", "Your share of your team's healing", F.abbrev)
    share_set(p.share.kills, (lr.kills or 0) + (lr.assists or 0), t.kills, "kills",
        "Your part in your team's kills\nkills + assists over team kills", count_fmt)
    share_set(p.share.taken, lr.taken or 0, t.taken, "taken", "Your share of the damage your team took", F.abbrev)
    if flag_col_spec(m) == "carried" then
        share_set(p.share.obj, lr.carried or 0, t.carried, "held", "Your share of your team's ball time", time_fmt)
    else
        share_set(p.share.obj, caps_count(m, lr.caps or 0), caps_count(m, t.caps), "caps", "Your share of your team's captures", count_fmt)
    end
    share_set(p.share.medals, lr.medals or 0, t.medals, "medals", "Your share of your team's medals", count_fmt)
    return true
end

local function standing_visible(m)
    if not Prefs.get("show_standing") then return false end
    local casual = (m.competitive == false)
        or (m.competitive == nil and m.teamSize == nil and #m.battle > 10)
    if casual then
        local sess = BGMeter.Session
        return sess ~= nil and sess.matches > 0
    end
    return true
end

local function haul_profile_body(p, top)
    local Profile = BGMeter.Profile
    local data = p.profile
    local idx = data and ((p.profileHover and Profile.index_of(data, p.profileHover)) or data.me) or nil
    if not idx then
        p.radar:clear()
        p.radar.root:SetHidden(true)
        p.archetype:SetHidden(true)
        return false
    end
    local pl = data.players[idx]
    local tm = data.teams[pl.team]
    local names = p.axisNames or {}
    p.axisNames = names
    for a = 1, #data.axes do names[a] = Profile.NAMES[data.axes[a]] end
    for a = #data.axes + 1, #names do names[a] = nil end
    local col = S.team_color(pl.team)
    p.radar.root:ClearAnchors()
    p.radar.root:SetAnchor(TOPLEFT, p.container, TOPLEFT, 16, top)
    p.radar.root:SetHidden(false)
    p.radar:set_axes(names)
    p.radar:clear_series()
    if tm then p.radar:set_series(1, tm.v, K.COLOR.gold, { width = 1, alpha = 0.75 }) end
    p.radar:set_series(2, pl.v, col, { fan = true, width = 2 })
    local c = Profile.classify(pl.v, data.axes, data.n)
    if c.kind == "pair" then p.radar:set_emphasis(c.top, c.with)
    elseif c.kind == "single" then p.radar:set_emphasis(c.top, nil)
    else p.radar:set_emphasis(nil, nil) end
    p.radar:render()
    local label = c.name:upper()
    W.tips[p.archetype] = Profile.meaning(c.name)
    p.archetype:ClearAnchors()
    p.archetype:SetAnchor(TOPLEFT, p.container, TOPLEFT, 16, top + (p.radarSide or RADAR_MIN) + 2)
    set_text(p.archetype, label)
    S.color(p.archetype, pl.row.isLocal and K.COLOR.gold or col)
    p.archetype:SetHidden(false)
    return true
end

local function haul_profile(p, top)
    return BGMeter.Prof.span("haul:profile", haul_profile_body, p, top)
end

function U.profile_hover(prow)
    local p = W.haul
    if not (p and p.profile) or p.container:IsHidden() then return end
    if p.profileHover == prow then return end
    p.profileHover = prow
    if not p.radarTop then return end
    haul_profile(p, p.radarTop)
end

function U.profile_state()
    local p = W.haul
    if not p then return nil end
    return { shown = not p.radar.root:IsHidden(), label = p.archetype:GetText(), axes = p.radar:axis_count(),
             lines = p.radar:count(), hover = p.profileHover ~= nil, top = p.radarTop, side = p.radarSide, mini = p.miniAvail,
             tip = W.tips[p.archetype] }
end

function SEC.haul(m, animate)
    local p, h = W.haul, m.haul
    local rec = m.records or {}
    local vet = h.vetEnd or h.vetStart
    local vetControls = { p.vetIcon, p.vetIconHit, p.vetTitle, p.vetTier, p.track.container, p.vetDelta }

    if not Prefs.get("show_veterancy") then
        hide_all(vetControls, true)
    elseif vet and vet.rank then
        hide_all(vetControls, false)
        if vet.rankIcon then p.vetIcon:SetTexture(vet.rankIcon); p.vetIcon:SetHidden(false) else p.vetIcon:SetHidden(true) end
        set_text(p.vetTitle, vet.rankTitle or ("Veteran Rank " .. tostring(vet.rank)))
        local laps = vet.laps or 0
        local tierTxt = vet.tier and string.format("Tier %d", vet.tier) or ""
        if vet.pastMax then
            tierTxt = laps > 0 and string.format("Max rank  ·  reward ×%d", laps) or "Max rank"
        end
        set_text(p.vetTier, tierTxt)
        local hasPct = vet.percent ~= nil
        Bar.set_hidden(p.track, not hasPct)
        if hasPct then set_bar(p.track, math.max(0, math.min(1, vet.percent)), K.COLOR.veterancy, L.haul_w - 32, animate) end
        if h.vetRankUp then
            set_text(p.vetDelta, vet.pastMax and "REWARD this match!" or "RANK UP this match!"); S.color(p.vetDelta, K.COLOR.gold)
        elseif hasPct then
            local txt
            if vet.tierTotal and vet.tierTotal > 0 then
                txt = string.format("%s / %s to next %s", F.commas(vet.progressToNext or 0), F.commas(vet.tierTotal),
                    vet.pastMax and "reward" or "rank")
            else
                txt = "max rank reached"
            end
            set_text(p.vetDelta, txt); S.color(p.vetDelta, K.COLOR.veterancy)
        else
            set_text(p.vetDelta, "")
        end
        local endsTxt = (vet.secondsLeft and vet.secondsLeft > 0)
            and ("\nseason ends in " .. F.countdown(vet.secondsLeft)) or ""
        W.tips[p.vetIconHit] = string.format("%s%s\n%s%s",
            vet.rankTitle or ("Veteran Rank " .. tostring(vet.rank)),
            vet.pastMax and (laps > 0 and ("  ·  max rank, reward ×" .. laps) or "  ·  max rank")
                or (vet.tier and ("  ·  Tier " .. vet.tier) or ""),
            vet.seasonName or "Veterancy season", endsTxt)
    else
        hide_all(vetControls, false)
        p.vetIcon:SetHidden(true)
        set_text(p.vetTitle, "Veterancy"); set_text(p.vetTier, "(no season data)")
        Bar.set_hidden(p.track, true); set_text(p.vetDelta, "")
        W.tips[p.vetIconHit] = nil
    end

    set_count(p.ap.val, h.apGained, "+", animate)
    set_count(p.xp.val, h.xpGained, "+", animate)
    set_text(p.cp.val, h.cpGained > 0 and F.signed(h.cpGained) or "+0")
    S.color(p.ap.val, rec.ap and K.COLOR.you or K.COLOR.gold)
    if rec.ap and animate then pop(p.ap.val) end

    local lr = BGMeter.Match.local_row(m)
    local ids = lr and lr.medalIds or {}
    local counts = lr and lr.medalCounts or {}
    hide_medal_card()
    for i = 1, #p.medalIcons do
        local mi, badge, id = p.medalIcons[i], p.medalBadges[i], ids[i]
        local hit = p.medalHits[i]
        local info = id and Icons.medal_info(id) or nil
        if info and info.icon then
            mi:SetTexture(info.icon); mi:SetHidden(false)
            if hit then hit:SetHidden(false) end
            local n = counts[id] or 1
            mi.bgmMedalId = id
            mi.bgmMedalCount = n
            if n > 1 then
                set_text(badge, "x" .. n)
                badge:SetHidden(false)
            else
                badge:SetHidden(true)
            end
        else
            mi:SetHidden(true); badge:SetHidden(true)
            if hit then hit:SetHidden(true) end
            mi.bgmMedalId = nil
            mi.bgmMedalCount = nil
        end
    end
    set_text(p.medalMore, (#ids > #p.medalIcons) and ("+" .. (#ids - #p.medalIcons)) or "")

    local rings = SEC.haul_share(m, lr)
    p.div4:SetHidden(not rings)
    local contH = (W.cur_h or L.window_h) - L.header_h - L.footer_h
    local inner = L.haul_w - 32
    local top = EFF_BOTTOM + (rings and (RINGS_H + 7) or 0) + MINI_GAP
    local bottom = standing_visible(m) and STAND_H or 0
    if p.profileFor ~= m then
        p.profileFor, p.profileHover = m, nil
        p.profile = BGMeter.Profile.compute(m)
    end
    local room = contH - bottom - top - MINI_GAP
    local side = room - 18 - MINI_GAP - MINI_OUTER_MIN
    if side > inner then side = inner end
    if side < RADAR_MIN then side = RADAR_MIN end
    p.radarSide = side
    p.radar:layout(inner, side)
    p.radarTop = top
    if haul_profile(p, top) then top = top + side + 18 + MINI_GAP end
    p.miniAvail = contH - bottom - top - MINI_GAP
    if BGMeter.UI.map then
        local outer = math.min(p.miniAvail, inner)
        local x = 16 + math.floor((inner - outer) / 2)
        BGMeter.UI.map.mini_update(m, p.container, x, top, p.miniAvail)
    end

    local standControls = { p.sep, p.standHeading, p.standRank, p.standSub }
    local casual = (m.competitive == false)
        or (m.competitive == nil and m.teamSize == nil and #m.battle > 10)
    if not Prefs.get("show_standing") then hide_all(standControls, true); return end

    if casual then
        local sess = BGMeter.Session
        if not sess or sess.matches == 0 then hide_all(standControls, true); return end
        hide_all(standControls, false)
        p.standHeading:SetText("SESSION")
        set_text(p.standRank, string.format("%dW - %dL", sess.wins, sess.losses))
        local col = K.COLOR.text
        if sess.wins > sess.losses then col = K.COLOR.heal
        elseif sess.losses > sess.wins then col = K.COLOR.accent end
        S.color(p.standRank, col)
        set_text(p.standSub, string.format("%s AP", F.commas(sess.ap)))
        S.color(p.standSub, K.COLOR.text_dim)
        W.tips[p.standRank] = string.format(
            "This play session (since login)\n%d wins, %d losses\n%s AP  ·  %s XP earned",
            sess.wins, sess.losses, F.commas(sess.ap), F.commas(sess.xp))
        return
    end
    hide_all(standControls, false)
    p.standHeading:SetText("COMPETITIVE STANDING")

    local st = m.standing
    if not st then
        set_text(p.standRank, "..."); S.color(p.standRank, K.COLOR.text_dim)
        set_text(p.standSub, "loading"); S.color(p.standSub, K.COLOR.text_dim)
        W.tips[p.standRank] = "Competitive leaderboard standing"
    elseif st.rank and st.rank > 0 then
        set_text(p.standRank, "#" .. F.commas(st.rank))
        local rankCol, move = K.COLOR.text, ""
        if st.rankDelta > 0 then rankCol = K.COLOR.heal; move = F.icon(ICON_SORTUP, 16) .. string.format(" |c5cc85f%d up|r   ", st.rankDelta)
        elseif st.rankDelta < 0 then rankCol = K.COLOR.accent; move = F.icon(ICON_SORTDN, 16) .. string.format(" |ce34234%d down|r   ", -st.rankDelta)
        elseif st.prevRank == 0 then rankCol = K.COLOR.gold; move = "|cf2cc55NEW|r   "
        else move = "|c8a8a8ano change|r   " end
        if rec.rank then move = F.icon(ICON_STAR, 16) .. " |cf2cc55best!|r   " .. move end
        S.color(p.standRank, rec.rank and K.COLOR.gold or rankCol)
        if rec.rank and animate then pop(p.standRank) end
        local sub = F.commas(st.score)
        local subCol = K.COLOR.text_dim
        if st.scoreDelta and st.scoreDelta ~= 0 then
            sub = sub .. string.format("  %s%s", st.scoreDelta > 0 and "+" or "", F.commas(st.scoreDelta))
            subCol = st.scoreDelta > 0 and K.COLOR.heal or K.COLOR.accent
        end
        set_text(p.standSub, sub)
        S.color(p.standSub, subCol)
        local tip = "Competitive leaderboard standing\n"
        if rec.rank then tip = tip .. "personal best rank\n" end
        if st.rankDelta > 0 then tip = tip .. string.format("up %d since your last match", st.rankDelta)
        elseif st.rankDelta < 0 then tip = tip .. string.format("down %d since your last match", -st.rankDelta)
        elseif st.prevRank == 0 then tip = tip .. "your first ranked match"
        else tip = tip .. "no change since your last match" end
        if st.mmr then tip = tip .. "\nhidden MMR: " .. F.commas(st.mmr) end
        if not st.impacts then tip = tip .. "\n(this match did not affect rank)" end
        W.tips[p.standRank] = tip
    else
        set_text(p.standRank, "unranked"); S.color(p.standRank, K.COLOR.text_dim)
        set_text(p.standSub, st.impacts and "no entry yet" or "not ranked"); S.color(p.standSub, K.COLOR.text_dim)
        W.tips[p.standRank] = "Competitive leaderboard standing\nplay a ranked battleground to appear"
    end
end

U.build_haul = build_haul
U.hide_medal_card = hide_medal_card
