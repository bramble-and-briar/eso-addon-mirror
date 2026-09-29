BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local SEC = U.SEC
local hexc, team_name, neutral_color, flag_pin, hit_proxy = U.hexc, U.team_name, U.neutral_color, U.flag_pin, U.hit_proxy

local C = BGMeter.zenimax.constants
local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs

local function timeline_ok(m)
    local tl = m.timeline
    return Prefs.get("show_timeline") and tl and tl.t and #tl.t >= 3
end

local function series_max(arr, n)
    local mx = 0
    for i = 1, n do
        local v = arr and arr[i] or 0
        if v > mx then mx = v end
    end
    return mx
end

local function ribbon_letter(b, i)
    local lbl = b.ribbon_letters[i]
    if not lbl then
        lbl = P.label(b.ribbon, S.FONT.small, K.COLOR.text)
        b.ribbon_letters[i] = lbl
    end
    return lbl
end

local function lane_pin(b, i)
    local ic = b.lane_pins[i]
    if not ic then
        ic = P.icon(b.ribbon, "")
        ic:SetDimensions(28, 28)
        b.lane_pins[i] = ic
    end
    return ic
end

local function mark_label(b, i)
    local lbl = b.mark_labels[i]
    if not lbl then
        lbl = P.label(b.chart, S.FONT.small, K.COLOR.text_dim)
        lbl:SetHeight(12)
        b.mark_labels[i] = lbl
    end
    return lbl
end

local VP_LEFT  = (VERTEX_POINTS_TOPLEFT or 1) + (VERTEX_POINTS_BOTTOMLEFT or 4)
local VP_RIGHT = (VERTEX_POINTS_TOPRIGHT or 2) + (VERTEX_POINTS_BOTTOMRIGHT or 8)
local VP_T = (VERTEX_POINTS_TOPLEFT or 1) + (VERTEX_POINTS_TOPRIGHT or 2)
local VP_B = (VERTEX_POINTS_BOTTOMLEFT or 4) + (VERTEX_POINTS_BOTTOMRIGHT or 8)

local function grad_rect(pool, parent, x0, x1, y, h, c0, a0, c1, a1)
    if x1 - x0 < 1 then return nil end
    local r = pool:acquire()
    r:ClearAnchors()
    r:SetAnchor(TOPLEFT, parent, TOPLEFT, x0, y)
    r:SetDimensions(x1 - x0, h)
    r:SetVertexColors(VP_LEFT, c0[1], c0[2], c0[3], a0)
    r:SetVertexColors(VP_RIGHT, c1[1], c1[2], c1[3], a1)
    r:SetHidden(false)
    return r
end

local function vgrad_rect(pool, parent, x, y0, y1, w, c, a_top, a_bottom)
    if y1 - y0 < 1 or w < 1 then return nil end
    local r = pool:acquire()
    r:ClearAnchors()
    r:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y0)
    r:SetDimensions(w, y1 - y0)
    r:SetVertexColors(VP_T, c[1], c[2], c[3], a_top)
    r:SetVertexColors(VP_B, c[1], c[2], c[3], a_bottom)
    r:SetHidden(false)
    return r
end

local function flat_rect(pool, parent, x, y, w, h, color)
    if w < 1 or h < 1 then return nil end
    local r = pool:acquire()
    r:ClearAnchors()
    r:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    r:SetDimensions(w, h)
    P.set_rect_color(r, color)
    r:SetHidden(false)
    return r
end

local function hit_rect(b, parent, x, y, w, h, tip)
    local hit = b.hit_pool:acquire()
    hit:ClearAnchors()
    hit:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    hit:SetDimensions(math.max(1, w), math.max(1, h))
    hit:SetHidden(false)
    W.tips[hit] = tip
    return hit
end

local function polyline(b, line_pool, dot_pool, parent, px, py, n, color, thick, alpha)
    if b.lines_ok and line_pool then
        for i = 2, n do
            local ln = line_pool:acquire()
            ln:ClearAnchors()
            ln:SetAnchor(TOPLEFT, parent, TOPLEFT, px(i - 1), py(i - 1))
            ln:SetAnchor(TOPRIGHT, parent, TOPLEFT, px(i), py(i))
            ln:SetColor(color[1], color[2], color[3], alpha)
            if ln.SetThickness then ln:SetThickness(thick) end
            ln:SetHidden(false)
        end
    else
        for i = 1, n do
            local dot = dot_pool:acquire()
            dot:ClearAnchors()
            dot:SetAnchor(TOPLEFT, parent, TOPLEFT, px(i), py(i))
            dot:SetDimensions(thick + 1, thick + 1)
            P.set_rect_color(dot, { color[1], color[2], color[3], alpha })
            dot:SetHidden(false)
        end
    end
end

function SEC.occupation(b, occ, neutralPct, stats, w)
    b.occ:SetHeight(L.occ_h)
    b.occ:SetHidden(false)
    local bw = w - 6
    local x = 0
    local parts = {}
    for _, e in ipairs(occ) do
        local tc = S.team_color(e.team)
        local seg_w = math.floor(e.pct * bw + 0.5)
        if seg_w > 1 then
            flat_rect(b.occ_pool, b.occ, x, 18, seg_w, 10, { tc[1], tc[2], tc[3], 0.80 })
            x = x + seg_w
        end
        parts[#parts + 1] = string.format("|c%s%s %d%%|r",
            hexc(tc), team_name(e.team), math.floor(e.pct * 100 + 0.5))
    end
    if x < bw then
        local nc = neutral_color()
        flat_rect(b.occ_pool, b.occ, x, 18, bw - x, 10, { nc[1], nc[2], nc[3], K.ALPHA.ribbon_neutral })
        if neutralPct and neutralPct >= 0.005 then
            local nl = "neutral"
            if stats and stats.mode == "relic" then nl = "at base"
            elseif stats and stats.mode == "ball" then nl = "loose" end
            parts[#parts + 1] = string.format("|c8c8c95%s %d%%|r",
                nl, math.floor(neutralPct * 100 + 0.5))
        end
    end
    b.occLegend:SetText(table.concat(parts, "  ·  "))

    local sp = {}
    if stats then
        for _, e in ipairs(stats.per) do
            local tc = S.team_color(e.team)
            if stats.mode == "relic" then
                sp[#sp + 1] = string.format("|c%s%s  %d/%d runs scored · avg run %s|r",
                    hexc(tc), team_name(e.team), e.caps, e.holds or 0, F.duration(e.avgHoldMs))
            elseif stats.mode == "ball" then
                sp[#sp + 1] = string.format("|c%s%s  held %s · avg %s|r",
                    hexc(tc), team_name(e.team), F.duration(e.holdMs), F.duration(e.avgHoldMs))
            else
                sp[#sp + 1] = string.format("|c%s%s  %d caps · %d defs · avg hold %s|r",
                    hexc(tc), team_name(e.team), e.caps, e.defs, F.duration(e.avgHoldMs))
            end
        end
        if stats.first then
            local tc = S.team_color(stats.first.team)
            sp[#sp + 1] = string.format("|c%s%s %s @ %s|r",
                hexc(tc), (stats.mode == "relic") and "first goal" or "first",
                tostring(stats.first.name or stats.first.letter), F.duration(stats.first.t))
        end
    end
    b.occStats:SetText(table.concat(sp, "    "))
end

local function lane_label(lane)
    return lane.name or ("flag " .. tostring(lane.letter))
end

function SEC.ribbon(b, lanes, ribbon_h, tspan, w, y_off, gt, mine)
    b.ribbon:ClearAnchors()
    b.ribbon:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -y_off)
    b.ribbon:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -y_off)
    b.ribbon:SetHeight(ribbon_h)
    b.ribbon:SetHidden(false)
    local lh, lg = U.lane_metrics(#lanes)
    local pinS = math.max(16, math.floor(L.pin_size * lh / L.lane_h))
    local function rx(t) return math.floor((t / tspan) * (w - 6) + 0.5) end
    local TIP = 10
    local edge = K.COLOR.text_dim
    for li, lane in ipairs(lanes) do
        local y = L.ribbon_top + (li - 1) * (lh + lg)
        for _, seg in ipairs(lane.segs) do
            local x0, x1 = rx(seg.t0), rx(seg.t1)
            if x1 > x0 then
                if seg.own and seg.own ~= 0 then
                    local tc = (mine and seg.who == mine) and K.COLOR.you or S.team_color(seg.own)
                    local fa = K.ALPHA.ribbon_fill
                    if x1 - x0 > TIP * 2 then
                        flat_rect(b.ribbon_pool, b.ribbon, x0, y, x1 - x0 - TIP, lh, { tc[1], tc[2], tc[3], fa })
                        grad_rect(b.ribbon_pool, b.ribbon, x1 - TIP, x1, y, lh, tc, fa, tc, fa * 0.12)
                    else
                        grad_rect(b.ribbon_pool, b.ribbon, x0, x1, y, lh, tc, fa, tc, fa * 0.35)
                    end
                else
                    local nc = neutral_color()
                    flat_rect(b.ribbon_pool, b.ribbon, x0, y, x1 - x0, lh, { nc[1], nc[2], nc[3], K.ALPHA.ribbon_neutral })
                end
            end
        end
        for _, ly in ipairs({ y - 1, y + lh }) do
            flat_rect(b.ribbon_pool, b.ribbon, 0, ly, w - 6, 1, { edge[1], edge[2], edge[3], 0.16 })
        end
        for _, tick in ipairs(lane.ticks) do
            local ic = b.pin_pool:acquire()
            local tip
            local ctf = (gt == "capture_the_flag")
            local tlabel = tick.name or lane_label(lane)
            if tick.kind == "take" then
                ic:SetTexture(string.format("EsoUI/Art/MapPins/battlegrounds_murderball_%s.dds",
                    S.team_art_key(tick.own)))
                ic:SetDimensions(pinS - 12, pinS - 12)
                ic:SetColor(1, 1, 1, 1)
                tip = string.format("%s took %s @ %s",
                    tick.who or team_name(tick.own), tlabel, F.duration(tick.t))
            elseif tick.kind == "def" then
                local tc = S.team_color(tick.own)
                if ctf then
                    ic:SetTexture("EsoUI/Art/Buttons/closeButton_up.dds")
                    ic:SetDimensions(pinS - 10, pinS - 10)
                else
                    ic:SetTexture("EsoUI/Art/WorldMap/map_AVA_tabIcon_resourceDefense_up.dds")
                    ic:SetDimensions(pinS - 6, pinS - 6)
                end
                ic:SetColor(tc[1], tc[2], tc[3], 1)
                tip = string.format("%s %s %s @ %s",
                    team_name(tick.own), ctf and "returned" or "defended",
                    tlabel, F.duration(tick.t))
            elseif ctf then
                ic:SetTexture("EsoUI/Art/Collections/Favorite_StarOnly.dds")
                ic:SetDimensions(pinS, pinS)
                local tc = S.team_color(tick.own)
                ic:SetColor(tc[1], tc[2], tc[3], 1)
                tip = string.format("%s scored %s @ %s",
                    tick.who or team_name(tick.own), tlabel, F.duration(tick.t))
            else
                ic:SetTexture(flag_pin(gt, tick.letter or lane.letter, tick.own))
                ic:SetDimensions(pinS, pinS)
                ic:SetColor(1, 1, 1, 1)
                tip = string.format("%s captured %s @ %s",
                    team_name(tick.own), tlabel, F.duration(tick.t))
            end
            local half = math.floor(pinS / 2)
            local tx = math.max(half, math.min(rx(tick.t), w - 6 - half))
            ic:SetAnchor(CENTER, b.ribbon, TOPLEFT, tx, y + math.floor(lh / 2))
            ic:SetHidden(false)
            local hit = b.hit_pool:acquire()
            hit:ClearAnchors()
            hit:SetAnchorFill(ic)
            hit:SetHidden(false)
            W.tips[hit] = tip
        end
        local is_letter = lane.letter and lane.letter:match("^[ABCD]$") ~= nil
        local river = lane.letter == "~"
        local lbl = ribbon_letter(b, li)
        local pin = lane_pin(b, li)
        if is_letter or river then
            pin:SetTexture(flag_pin(gt, river and nil or lane.letter, 0))
            pin:ClearAnchors()
            pin:SetAnchor(LEFT, b.ribbon, TOPLEFT, 2, y + math.floor(lh / 2))
            pin:SetHidden(false)
            lbl:SetHidden(true)
        else
            lbl:SetText(lane.letter)
            lbl:ClearAnchors()
            lbl:SetAnchor(TOPRIGHT, b.ribbon, TOPLEFT, -4, y - 2)
            lbl:SetHidden(false)
            pin:SetHidden(true)
        end
    end
    for i = #lanes + 1, #b.ribbon_letters do
        b.ribbon_letters[i]:SetHidden(true)
    end
    for i = #lanes + 1, #b.lane_pins do
        b.lane_pins[i]:SetHidden(true)
    end
end

function SEC.momentum(b, m, tl, n, tspan, w, mom_h, mom_off, lead, tdm_line, cmom, cmomMax)
    b.mom:ClearAnchors()
    b.mom:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -mom_off)
    b.mom:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -mom_off)
    b.mom:SetHeight(mom_h)
    b.mom:SetHidden(false)

    local function mx(t) return math.floor((t / tspan) * (w - 6) + 0.5) end
    if cmom then
        b.momTitle:SetText("COMBAT MOMENTUM")
        W.tips[b.momTitle] = "Who was winning the FIGHT, minute by minute.\nColor = team ahead on kills in the last 60s  ·  brighter = more dominant\nWhen this disagrees with the score chart above, kills were not buying points."
        local peak = math.max(3, math.ceil(math.max(cmomMax or 1, 1) * 0.75))
        local top, bar_h = 18, 10
        local nc = neutral_color()
        flat_rect(b.mom_pool, b.mom, 0, top, w - 6, bar_h, { nc[1], nc[2], nc[3], 0.10 })
        local edge = K.COLOR.text_dim
        for _, ly in ipairs({ top - 1, top + bar_h }) do
            flat_rect(b.mom_pool, b.mom, 0, ly, w - 6, 1, { edge[1], edge[2], edge[3], 0.16 })
        end
        local samples = W._derived and W._derived.cmomS
        local denom = math.max(cmomMax or 1, 1)
        local function alpha_of(s)
            if not s.team or (s.mag or 0) <= 0 then return 0 end
            return 0.18 + 0.72 * math.min(1, s.mag / denom)
        end
        if samples then
            for i = 1, #samples - 1 do
                local s0, s1 = samples[i], samples[i + 1]
                local x0, x1 = mx(s0.t), mx(math.min(s1.t, tspan))
                local a0, a1 = alpha_of(s0), alpha_of(s1)
                if a0 > 0 or a1 > 0 then
                    if a0 == 0 or a1 == 0 or s0.team == s1.team then
                        local c = S.team_color((a0 > 0) and s0.team or s1.team)
                        grad_rect(b.mom_pool, b.mom, x0, x1, top, bar_h, c, a0, c, a1)
                    else
                        local xm = math.floor((x0 + x1) / 2)
                        local c0, c1 = S.team_color(s0.team), S.team_color(s1.team)
                        grad_rect(b.mom_pool, b.mom, x0, xm, top, bar_h, c0, a0, c0, 0)
                        grad_rect(b.mom_pool, b.mom, xm, x1, top, bar_h, c1, 0, c1, a1)
                    end
                end
            end
        end
        for _, sg in ipairs(cmom) do
            local x0, x1 = mx(sg.t0), mx(sg.t1)
            if x1 > x0 and sg.team then
                local tc = S.team_color(sg.team)
                hit_rect(b, b.mom, x0, top, x1 - x0, bar_h, string.format("%s +%d kills", team_name(sg.team), sg.mag))
                if sg.mag >= peak and (x1 - x0) >= 26 then
                    local ic = b.pin_pool:acquire()
                    ic:SetTexture("EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds")
                    ic:SetDimensions(18, 18)
                    ic:SetColor(tc[1], tc[2], tc[3], 1)
                    ic:SetAnchor(CENTER, b.mom, TOPLEFT, math.floor((x0 + x1) / 2), top + 5)
                    ic:SetHidden(false)
                end
            end
        end
    elseif lead then
        b.momTitle:SetText("MOMENTUM")
        W.tips[b.momTitle] = "Who was leading, and by how much.\nColor = leading team  ·  brighter = bigger lead"
        local series = { tl.s1, tl.s2, tl.s3 }
        local teams = tl.teams or {}
        local maxLead = math.max(1, (lead and lead.maxLead) or 1)
        for i = 2, n do
            local best, second, bestTeam = 0, 0, nil
            for s = 1, 3 do
                local team = teams[s]
                local v = (series[s] and series[s][i]) or 0
                if team and v > best then
                    second = best
                    best, bestTeam = v, team
                elseif team and v > second then
                    second = v
                end
            end
            local margin = best - second
            local x0, x1 = mx(tl.t[i - 1] or 0), mx(tl.t[i] or 0)
            if x1 > x0 then
                if bestTeam and margin > 0 then
                    local tc = S.team_color(bestTeam)
                    local a = 0.15 + 0.60 * math.min(1, margin / maxLead)
                    flat_rect(b.mom_pool, b.mom, x0, 18, x1 - x0, 10, { tc[1], tc[2], tc[3], a })
                else
                    local nc = neutral_color()
                    flat_rect(b.mom_pool, b.mom, x0, 18, x1 - x0, 10, { nc[1], nc[2], nc[3], 0.10 })
                end
            end
        end
    end

    if not tdm_line then
        b.momStats:SetText("")
        return
    end
    local Match = BGMeter.Match
    local sp = {}
    if lead then
        local tc = S.team_color(lead.maxTeam)
        sp[#sp + 1] = string.format("|c%smax lead %s +%d|r", hexc(tc), team_name(lead.maxTeam), lead.maxLead)
        sp[#sp + 1] = string.format("lead changes %d", lead.changes)
    end
    local bm = Match.bloodiest_minute(m.killfeed)
    if bm then
        sp[#sp + 1] = string.format("|c%sbloodiest %s-%s (%d kills)|r",
            hexc(K.COLOR.gold), F.duration(bm.t0), F.duration(bm.t1), bm.count)
    end
    local fb = Match.first_blood(m.killfeed)
    if fb then
        local tc = S.team_color(fb.kt)
        sp[#sp + 1] = string.format("|c%sfirst blood %s|r @ %s", hexc(tc), tostring(fb.kn), F.duration(fb.t))
    end
    local runs = Match.kill_streaks(m.killfeed)
    if runs then
        local best = runs[1]
        for _, r in ipairs(runs) do
            if r.n > best.n then best = r end
        end
        local tc = S.team_color(best.team)
        sp[#sp + 1] = string.format("best streak |c%s%s x%d|r", hexc(tc), tostring(best.name), best.n)
    end
    b.momStats:SetText(table.concat(sp, "    "))
end

function SEC.race(b, race, smooth, tl, n, tspan, w, race_h, race_off)
    b.race:ClearAnchors()
    b.race:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -race_off)
    b.race:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -race_off)
    b.race:SetHeight(race_h)
    b.race:SetHidden(false)
    W.tips[b.raceTitle] = "Damage dealt over the match, one line per team.\nYour own damage runs in gold.\nLines are lightly smoothed; the floor fill follows each team."
    local plot_h = race_h - 20
    local floor_y = 16 + plot_h
    local count = math.min(n, race.n)
    local function px(i) return math.floor((math.min(tl.t[i] or 0, tspan) / tspan) * (w - 6) + 0.5) end
    local function py_of(arr)
        return function(i) return 16 + math.floor((1 - (arr[i] or 0) / race.max) * plot_h + 0.5) end
    end
    for _, team in ipairs(race.teams) do
        local tc = S.team_color(team)
        local py = py_of(smooth[team])
        for i = 2, count do
            local x0, x1 = px(i - 1), px(i)
            local top = math.min(py(i - 1), py(i))
            vgrad_rect(b.race_pool, b.race, x0, top, floor_y, x1 - x0, tc, K.ALPHA.race_fill, 0)
        end
    end
    for _, team in ipairs(race.teams) do
        polyline(b, b.race_line_pool, b.race_pool, b.race, px, py_of(smooth[team]), count, S.team_color(team), 2, 0.9)
    end
    if race.mine and smooth.mine then
        polyline(b, b.race_line_pool, b.race_pool, b.race, px, py_of(smooth.mine), count, K.COLOR.you, 1, 0.95)
    end
end

function SEC.kills(b, kp, tspan, w, kills_h, kills_off)
    b.kills:ClearAnchors()
    b.kills:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -kills_off)
    b.kills:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -kills_off)
    b.kills:SetHeight(kills_h)
    b.kills:SetHidden(false)
    local top, bottom = 16, kills_h - 3
    local plot_h = bottom - top
    local bw = w - 6
    local bin_w = bw / kp.bins
    local gap = (bin_w >= 8) and 2 or 1
    local nteams = #kp.teams
    local mirrored = (nteams == 2)
    local mid = top + math.floor(plot_h / 2)
    local edge = K.COLOR.text_dim
    local legend = {}
    for _, team in ipairs(kp.teams) do
        local tot = 0
        for _, c in pairs(kp.counts[team]) do tot = tot + c end
        legend[#legend + 1] = string.format("|c%s%s %d|r", hexc(S.team_color(team)), team_name(team), tot)
    end
    b.killsLegend:SetText(table.concat(legend, "  ·  "))
    if mirrored then
        flat_rect(b.kills_pool, b.kills, 0, mid, bw, 1, { edge[1], edge[2], edge[3], 0.22 })
    else
        flat_rect(b.kills_pool, b.kills, 0, bottom, bw, 1, { edge[1], edge[2], edge[3], 0.22 })
    end
    local half = math.max(1, math.floor(plot_h / 2) - 1)
    for bin = 1, kp.bins do
        local x0 = math.floor((bin - 1) * bin_w + 0.5)
        local x1 = math.floor(bin * bin_w + 0.5)
        local inner = math.max(1, x1 - x0 - gap)
        local parts = {}
        for ti, team in ipairs(kp.teams) do
            local c = kp.counts[team][bin] or 0
            local tc = S.team_color(team)
            if c > 0 then
                if mirrored then
                    local hgt = math.max(1, math.floor(half * c / kp.max + 0.5))
                    if ti == 1 then
                        flat_rect(b.kills_pool, b.kills, x0, mid - hgt, inner, hgt, { tc[1], tc[2], tc[3], 0.75 })
                    else
                        flat_rect(b.kills_pool, b.kills, x0, mid + 1, inner, hgt, { tc[1], tc[2], tc[3], 0.75 })
                    end
                else
                    local slot = math.max(1, math.floor(inner / nteams))
                    local hgt = math.max(1, math.floor(plot_h * c / kp.max + 0.5))
                    flat_rect(b.kills_pool, b.kills, x0 + (ti - 1) * slot, bottom - hgt, math.max(1, slot - 1), hgt, { tc[1], tc[2], tc[3], 0.75 })
                end
            end
            parts[#parts + 1] = string.format("|c%s%s %d|r", hexc(tc), team_name(team), c)
        end
        local t0 = (bin - 1) * kp.binMs
        local t1 = math.min(bin * kp.binMs, tspan)
        hit_rect(b, b.kills, x0, top, x1 - x0, plot_h + 2,
            string.format("%s - %s\n%s", F.duration(t0), F.duration(t1), table.concat(parts, "  ·  ")))
    end
end

function SEC.clear_chart(b)
    b.dot_pool:release_all()
    if b.line_pool then b.line_pool:release_all() end
    if b.race_line_pool then b.race_line_pool:release_all() end
    b.race_pool:release_all()
    b.skull_pool:release_all()
    b.ribbon_pool:release_all()
    b.pin_pool:release_all()
    b.hit_pool:release_all()
    b.occ_pool:release_all()
    b.mom_pool:release_all()
    b.kills_pool:release_all()
    for _, lbl in ipairs(b.ribbon_letters) do lbl:SetHidden(true) end
    for _, ic in ipairs(b.lane_pins) do ic:SetHidden(true) end
    for _, lbl in ipairs(b.mark_labels) do lbl:SetHidden(true) end
    b.chart:SetHidden(true)
    b.ribbon:SetHidden(true)
    b.race:SetHidden(true)
    b.occ:SetHidden(true)
    b.mom:SetHidden(true)
    b.kills:SetHidden(true)
    b.bal:SetHidden(true)
    b.bloodiest:SetHidden(true)
    W.chart_state = nil
end

local balance_color = U.balance_color

local function soft(c)
    local t = K.COLOR.text
    return { c[1] * 0.55 + t[1] * 0.45, c[2] * 0.55 + t[2] * 0.45, c[3] * 0.55 + t[3] * 0.45 }
end

local function tint_glyph(icon, color, hidden)
    icon:SetHidden(hidden)
    if hidden then return end
    local c = soft(color)
    icon:SetColor(c[1], c[2], c[3], 1)
end

local function base_color(pct)
    if pct <= 0.10 then return K.COLOR.text_dim end
    if pct <= 0.25 then return K.COLOR.gold end
    return K.COLOR.accent
end

local function stop_color(st)
    if st.n == 0 then return K.COLOR.text_dim end
    if st.n * 2 < st.of then return K.COLOR.gold end
    return K.COLOR.accent
end

local function exp_layout(blk, three)
    if blk._three == three then return end
    blk._three = three
    local right = blk.right
    local function put(ctl, x, y, h)
        ctl:ClearAnchors()
        ctl:SetAnchor(TOPRIGHT, blk.parent, TOPRIGHT, x, y)
        if h then ctl:SetHeight(h) end
    end
    if three then
        put(blk.barM, -(right + 50), 16, 4); blk.fillM:SetHeight(4); put(blk.valM, -right, 12, 11)
        put(blk.barO, -(right + 50), 27, 4); blk.fillO:SetHeight(4); put(blk.valO, -right, 23, 11)
    else
        put(blk.barM, -(right + 50), 22, 5); blk.fillM:SetHeight(5); put(blk.valM, -right, 18, 12)
        put(blk.barO, -(right + 50), 36, 5); blk.fillO:SetHeight(5); put(blk.valO, -right, 32, 12)
    end
end

local function exp_paint(blk, icon, mineE, otherE, thirdE, key, avgKey, room)
    local mv = mineE and mineE[key] or 0
    local ov = otherE and otherE[key] or 0
    local tv = thirdE and thirdE[key] or 0
    local top = math.max(mv, ov, tv)
    if top <= 0 or not room then
        for _, c in ipairs(blk.all) do c:SetHidden(true) end
        for _, c in ipairs(blk.three) do c:SetHidden(true) end
        return nil
    end
    local three = thirdE ~= nil
    exp_layout(blk, three)
    for _, c in ipairs(blk.all) do c:SetHidden(false) end
    for _, c in ipairs(blk.three) do c:SetHidden(not three) end
    if icon then blk.icon:SetTexture(icon) else blk.icon:SetHidden(true) end
    local mc = mineE and S.team_color(mineE.team) or K.COLOR.text_dim
    local oc = otherE and S.team_color(otherE.team) or K.COLOR.text_dim
    blk.fillM:SetWidth(math.floor(44 * mv / top + 0.5))
    blk.fillO:SetWidth(math.floor(44 * ov / top + 0.5))
    P.set_rect_color(blk.fillM, { mc[1], mc[2], mc[3], 0.8 })
    P.set_rect_color(blk.fillO, { oc[1], oc[2], oc[3], 0.8 })
    local function txt(e, v)
        if not e then return "" end
        local cov = (e.seen < e.n) and string.format("  %d/%d", e.seen, e.n) or ""
        return F.commas(v) .. cov
    end
    blk.valM:SetText(txt(mineE, mv))
    blk.valO:SetText(txt(otherE, ov))
    local function cov_of(e) return (e and e.seen < e.n) and string.format(" (%d/%d)", e.seen, e.n) or "" end
    local line = string.format("|c%s%s|r vs |c%s%s|r%s", hexc(mc), F.commas(mv), hexc(oc), F.commas(ov), cov_of(otherE))
    if three then
        local tc = S.team_color(thirdE.team)
        blk.fillT:SetWidth(math.floor(44 * tv / top + 0.5))
        P.set_rect_color(blk.fillT, { tc[1], tc[2], tc[3], 0.8 })
        blk.valT:SetText(txt(thirdE, tv))
        line = line .. string.format(" vs |c%s%s|r%s", hexc(tc), F.commas(tv), cov_of(thirdE))
    end
    return line
end

function SEC.balance(b, bal, sur, bal_h, bal_off, ex)
    b.bal:ClearAnchors()
    b.bal:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -bal_off)
    b.bal:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -bal_off)
    b.bal:SetHeight(bal_h)
    b.bal:SetHidden(false)
    local bc = balance_color(bal.score)
    b.balScore:SetText(tostring(bal.score))
    S.color(b.balScore, bc)
    tint_glyph(b.balIcon, bc, false)
    local decided = bal.leaderChanged and ("decided at " .. F.duration(bal.decidedMs)) or "lead never changed"
    local mx = math.floor(b.balScaleW * bal.score / 100 + 0.5)
    b.balMarkX = mx
    b.balMark:ClearAnchors()
    b.balMark:SetAnchor(CENTER, b.balScale, LEFT, mx, 0)
    b.balMark:SetHidden(false)
    local base = sur and sur.base
    tint_glyph(b.balBaseIcon, base and base_color(base.pct) or K.COLOR.text_dim, base == nil)
    b.balBase:SetHidden(base == nil)
    if base then b.balBase:SetText(string.format("%d%%", math.floor(base.pct * 100 + 0.5))) end
    local st = sur and sur.stopped
    local hasStop = st ~= nil and st.of > 0
    tint_glyph(b.balStopIcon, hasStop and stop_color(st) or K.COLOR.text_dim, not hasStop)
    b.balStop:SetHidden(not hasStop)
    if hasStop then b.balStop:SetText(string.format("%d of %d", st.n, st.of)) end
    local A = BGMeter.zenimax.api
    local vetIcon = U.TX.vet.n
    local avaIcon = ex and ex.mine and ex.mine.avaAvg and A.get_ava_rank_icon and A.get_ava_rank_icon(math.max(1, math.floor(ex.mine.avaAvg + 0.5))) or nil
    local free = (b.bal:GetWidth() or 0) - b.balLeftW - 8
    local roomOne = free >= b.balAva.width + 6
    local roomTwo = free >= 2 * b.balAva.width + 14
    local vetLine = exp_paint(b.balVet, vetIcon, ex and ex.mine, ex and ex.other, ex and ex.third, "vet", "vetAvg", roomTwo)
    local avaLine = exp_paint(b.balAva, avaIcon, ex and ex.mine, ex and ex.other, ex and ex.third, "ava", "avaAvg", roomOne)
    local dim = hexc(K.COLOR.text_dim)
    local lines = {
        string.format("|c%sBALANCE %d|r", hexc(bc), bal.score),
        string.format("kill ratio |c%s%.2f|r  ·  contested |c%s%d%%|r  ·  margin |c%s%d%%|r",
            hexc(K.COLOR.gold), bal.killRatio, hexc(K.COLOR.gold), math.floor(bal.contested * 100 + 0.5), hexc(K.COLOR.gold), math.floor(bal.margin * 100 + 0.5)),
        bal.leaderChanged and string.format("decided |c%s%s|r%s", hexc(K.COLOR.gold), F.duration(bal.decidedMs),
            bal.leanTeam and string.format("  ·  |c%s%s|r ahead", hexc(S.team_color(bal.leanTeam)), team_name(bal.leanTeam)) or "")
            or string.format("|c%slead never changed|r%s", dim,
            bal.leanTeam and string.format("  ·  |c%s%s|r ahead", hexc(S.team_color(bal.leanTeam)), team_name(bal.leanTeam)) or ""),
    }
    local team = {}
    if base then
        team[#team + 1] = string.format("at base |c%s%d%%|r |c%s(you %d%%)|r", hexc(base_color(base.pct)), math.floor(base.pct * 100 + 0.5), dim, math.floor(base.mine * 100 + 0.5))
    end
    if hasStop then
        team[#team + 1] = string.format("stopped |c%s%d of %d|r", hexc(stop_color(st)), st.n, st.of)
    end
    if #team > 0 then lines[#lines + 1] = table.concat(team, "  ·  ") end
    local exp = {}
    if vetLine then exp[#exp + 1] = "veterancy " .. vetLine end
    if avaLine then exp[#exp + 1] = "rank " .. avaLine end
    if #exp > 0 then lines[#lines + 1] = table.concat(exp, "  ·  ") end
    W.tips[b.bal] = table.concat(lines, "\n")
end

function W.repaint_chart()
    if not W.built or not W.win or W.win:IsHidden() then return end
    local m = BGMeter.History.get(W.current_index)
    if m then SEC.timeline(m) end
end

local function derive(m, tl, tspan, gt)
    local Match = BGMeter.Match
    local dc = { m = m, tspan = tspan }
    dc.lanes = Match.flag_lanes(m, tspan)
    dc.relicMode = false
    if not dc.lanes and Match.relic_lanes then
        dc.lanes = Match.relic_lanes(m, tspan)
        dc.relicMode = dc.lanes ~= nil
    end
    if dc.lanes then
        dc.occ, dc.neutralPct = Match.flag_occupation(dc.lanes, tspan)
        dc.fstats = Match.flag_stats(dc.lanes)
        if dc.fstats then dc.fstats.mode = dc.relicMode and (gt == "murderball" and "ball" or "relic") or nil end
        if dc.relicMode and dc.occ then
            local held = 0
            for _, e in ipairs(dc.occ) do held = held + e.pct end
            dc.neutralPct = math.max(0, 1 - held)
        end
        if dc.occ and #dc.occ == 0 then dc.occ = nil end
    end
    dc.lead = Match.lead_stats(tl)
    dc.bm = Match.bloodiest_minute(m.killfeed)
    dc.cmom, dc.cmomMax, dc.cmomS = Match.combat_momentum(m.killfeed, tspan)
    dc.race = Match.damage_race(m)
    if dc.race then
        dc.raceSmooth = {}
        for _, team in ipairs(dc.race.teams) do
            dc.raceSmooth[team] = Match.smooth3(dc.race.series[team], dc.race.n)
        end
        if dc.race.mine then dc.raceSmooth.mine = Match.smooth3(dc.race.mine, dc.race.n) end
    end
    dc.kp = Match.kill_pressure(m.killfeed, tspan)
    dc.rounds = Match.round_marks(tl)
    dc.mine = Match.local_name(m)
    dc.bal = Match.balance(m)
    dc.sur = dc.bal and Match.surrender(m, Match.geo_cached(m)) or nil
    dc.exp = dc.bal and Match.experience(m) or nil
    return dc
end

local function minute_step(tspan)
    if tspan <= 8 * 60000 then return 60000 end
    if tspan <= 20 * 60000 then return 120000 end
    return 300000
end

function SEC.timeline(m)
    local b = W.battle
    SEC.clear_chart(b)
    if not timeline_ok(m) then return end

    local tl = m.timeline
    local n = #tl.t
    local tspan = math.max(1, tl.t[n] or 1)
    local gt = C.GAME_TYPE_LABEL and C.GAME_TYPE_LABEL[m.gameType] or nil

    local dc = W._derived
    if not dc or dc.m ~= m or dc.tspan ~= tspan then
        dc = derive(m, tl, tspan, gt)
        W._derived = dc
    end
    local lanes, relicMode = dc.lanes, dc.relicMode
    local occ, neutralPct, fstats = dc.occ, dc.neutralPct, dc.fstats
    local lead = dc.lead
    if lanes then
        b.ribbonTitle:SetText(relicMode and (gt == "murderball" and "BALL POSSESSION" or "RELIC RUNS") or "FLAG CONTROL")
        b.occTitle:SetText(relicMode and "POSSESSION" or "FLAG OCCUPATION")
    end
    local ribbon_h = 0
    if lanes then
        local lh, lg = U.lane_metrics(#lanes)
        ribbon_h = L.ribbon_top + #lanes * (lh + lg) + 3
    end
    local occ_h = occ and L.occ_h or 0
    local tdm_line = (not lanes) and lead ~= nil
    local mom_h = (dc.cmom or lead) and (tdm_line and 46 or 28) or 0

    local race_h = (dc.race and Prefs.get("show_race")) and L.race_h or 0
    local kills_h = (dc.kp and Prefs.get("show_kills")) and L.kills_h or 0
    local bal_h = (dc.bal and Prefs.get("show_balance")) and L.balance_h or 0
    local rows_h = 24 + #m.battle * L.row_h
    local cont_h = b.container:GetHeight()
    local function fits(extra) return cont_h - rows_h >= L.chart_h + extra + 8 end
    if kills_h > 0 and not fits(race_h + mom_h + ribbon_h + occ_h + kills_h + bal_h) then kills_h = 0 end
    if race_h > 0 and not fits(race_h + mom_h + ribbon_h + occ_h + bal_h) then race_h = 0 end
    if bal_h > 0 and not fits(mom_h + ribbon_h + occ_h + bal_h) then bal_h = 0 end
    if lanes and mom_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        mom_h, tdm_line = 0, false
    end
    if occ_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        occ, occ_h = nil, 0
    end
    if ribbon_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        lanes, ribbon_h = nil, 0
    end
    if mom_h > 0 and tdm_line and not fits(mom_h + ribbon_h + occ_h) then
        mom_h, tdm_line = 28, false
    end
    if mom_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        mom_h, tdm_line = 0, false
    end
    if not fits(0) then return end
    local rib_off = (occ_h > 0) and (occ_h + 2) or 0
    local mom_off = rib_off + ((ribbon_h > 0) and (ribbon_h + 2) or 0)
    local kills_off = mom_off + ((mom_h > 0) and (mom_h + 2) or 0)
    local race_off = kills_off + ((kills_h > 0) and (kills_h + 2) or 0)
    local bal_off = race_off + ((race_h > 0) and (race_h + 2) or 0)
    local chart_off = bal_off + ((bal_h > 0) and (bal_h + 2) or 0)
    if bal_h > 0 then SEC.balance(b, dc.bal, dc.sur, bal_h, bal_off, dc.exp) end
    b.chart:SetHidden(false)
    b.chart:ClearAnchors()
    b.chart:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -chart_off)
    b.chart:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -chart_off)
    b.chart:SetHeight(L.chart_h)

    local w = b.chart:GetWidth()
    local h = L.chart_h
    if w <= 8 then return end

    local series = { tl.s1, tl.s2, tl.s3 }
    local smax = {}
    local maxScore = 1
    for s = 1, 3 do
        smax[s] = series_max(series[s], n)
        if smax[s] > maxScore then maxScore = smax[s] end
    end

    local plot_h = h - 18
    local function px(i) return math.floor((tl.t[i] / tspan) * (w - 6) + 0.5) end
    local function py(arr, i) return 14 + math.floor((1 - (arr[i] or 0) / maxScore) * plot_h + 0.5) end

    local grid = K.COLOR.text_dim
    flat_rect(b.dot_pool, b.chart, 0, 14, w - 6, 1, { grid[1], grid[2], grid[3], K.ALPHA.chart_grid })
    flat_rect(b.dot_pool, b.chart, 0, 14 + math.floor(plot_h / 2), w - 6, 1, { grid[1], grid[2], grid[3], K.ALPHA.chart_grid })
    local step = minute_step(tspan)
    local tmark = step
    while tmark < tspan do
        local x = math.floor((tmark / tspan) * (w - 6) + 0.5)
        local big = (tmark % (step * 5) == 0)
        flat_rect(b.dot_pool, b.chart, x, h - (big and 5 or 3), 1, big and 5 or 3, { grid[1], grid[2], grid[3], 0.30 })
        tmark = tmark + step
    end
    b.chartMax:SetText(F.abbrev(maxScore))

    local legend = {}
    for s = 1, 3 do
        local team = tl.teams and tl.teams[s]
        if team and smax[s] > 0 then
            legend[#legend + 1] = string.format("|c%s%s|r", hexc(S.team_color(team)), team_name(team))
        end
    end
    b.chartLegend:SetText(table.concat(legend, "  ·  "))

    for i = 2, n do
        local best, second, bestS = 0, 0, nil
        for s = 1, 3 do
            local v = (series[s] and tl.teams and tl.teams[s]) and (series[s][i] or 0) or 0
            if v > best then second = best; best, bestS = v, s
            elseif v > second then second = v end
        end
        if bestS and best > second then
            local secS = nil
            for s = 1, 3 do
                if s ~= bestS and series[s] and tl.teams and tl.teams[s] and (series[s][i] or 0) == second then secS = s end
            end
            local top = math.min(py(series[bestS], i - 1), py(series[bestS], i))
            local bottom = secS and math.max(py(series[secS], i - 1), py(series[secS], i)) or (14 + plot_h)
            if bottom > top then
                vgrad_rect(b.dot_pool, b.chart, px(i - 1), top, bottom, math.max(1, px(i) - px(i - 1)), S.team_color(tl.teams[bestS]), 0.30, 0.03)
            end
        end
    end

    for s = 1, 3 do
        local arr = series[s]
        local team = tl.teams and tl.teams[s]
        if arr and smax[s] > 0 and team then
            polyline(b, b.line_pool, b.dot_pool, b.chart, px, function(i) return py(arr, i) end, n, S.team_color(team), 2, 0.95)
        end
    end

    if dc.rounds then
        for ri, mk in ipairs(dc.rounds) do
            local x = px(mk.i)
            local y = 4
            while y < h - 6 do
                flat_rect(b.dot_pool, b.chart, x, y, 1, 3, { grid[1], grid[2], grid[3], 0.45 })
                y = y + 6
            end
            local lbl = mark_label(b, ri)
            lbl:SetText("R" .. tostring(mk.r))
            lbl:ClearAnchors()
            lbl:SetAnchor(TOPLEFT, b.chart, TOPLEFT, x + 3, 2)
            lbl:SetHidden(false)
        end
    end

    local bm = dc.bm
    if bm then
        local x0 = math.floor((math.min(bm.t0, tspan) / tspan) * (w - 6) + 0.5)
        local x1 = math.floor((math.min(bm.t1, tspan) / tspan) * (w - 6) + 0.5)
        b.bloodiest:ClearAnchors()
        b.bloodiest:SetAnchor(TOPLEFT, b.chart, TOPLEFT, x0, 2)
        b.bloodiest:SetDimensions(math.max(2, x1 - x0), h - 4)
        b.bloodiest:SetHidden(false)
    end

    if m.killfeed then
        for _, k in ipairs(m.killfeed) do
            local x = math.floor((math.min(k.t or 0, tspan) / tspan) * (w - 6) + 0.5)
            if k.kind == "kill" or k.kind == "death" then
                local ic = b.skull_pool:acquire()
                local c = (k.kind == "kill") and K.COLOR.gold or K.COLOR.accent
                ic:SetColor(c[1], c[2], c[3], 1)
                ic:SetAnchor(BOTTOM, b.chart, BOTTOMLEFT, x, 5)
                ic:SetHidden(false)
            elseif k.kt then
                local tc = S.team_color(k.kt)
                local mark = b.dot_pool:acquire()
                mark:ClearAnchors()
                mark:SetAnchor(BOTTOMLEFT, b.chart, BOTTOMLEFT, x, -2)
                mark:SetDimensions(2, 5)
                P.set_rect_color(mark, { tc[1], tc[2], tc[3], 0.65 })
                mark:SetHidden(false)
            end
        end
    end

    if race_h > 0 then
        SEC.race(b, dc.race, dc.raceSmooth, tl, n, tspan, w, race_h, race_off)
    end
    if kills_h > 0 then
        SEC.kills(b, dc.kp, tspan, w, kills_h, kills_off)
    end
    if lanes then
        SEC.ribbon(b, lanes, ribbon_h, tspan, w, rib_off, gt, dc.mine)
    end
    if occ then
        SEC.occupation(b, occ, neutralPct, fstats, w)
    end
    if mom_h > 0 then
        SEC.momentum(b, m, tl, n, tspan, w, mom_h, mom_off, lead, tdm_line, dc.cmom, dc.cmomMax)
    end

    W.chart_state = { tl = tl, n = n, w = w, smax = smax, lanes = lanes, kf = m.killfeed, mine = dc.mine }
end

local function chart_hover_poll()
    local b = W.battle
    local st = W.chart_state
    if not st or b.chart:IsHidden() then W._chart_hover_stop(); return end
    local A = BGMeter.zenimax.api
    if type(A.get_ui_mouse) ~= "function" then return end
    local mx = A.get_ui_mouse()
    local rel = mx - b.chart:GetLeft()
    local w = b.chart:GetWidth()
    if rel < 0 then rel = 0 elseif rel > w then rel = w end

    local tl, n = st.tl, st.n
    local tspan = math.max(1, tl.t[n] or 1)
    local want_t = (rel / math.max(1, w - 6)) * tspan
    local idx = 1
    for i = 1, n do
        if tl.t[i] <= want_t then idx = i else break end
    end

    local x = math.floor((tl.t[idx] / tspan) * (w - 6) + 0.5)
    b.cursor:ClearAnchors()
    b.cursor:SetAnchor(TOPLEFT, b.chart, TOPLEFT, x, 2)
    b.cursor:SetHidden(false)

    local parts = { "team score  ·  t " .. F.duration(tl.t[idx]) .. ((tl.r and tl.r[idx] and (W._derived and W._derived.rounds)) and ("  ·  round " .. tostring(tl.r[idx])) or "") }
    local series = { tl.s1, tl.s2, tl.s3 }
    for s = 1, 3 do
        local team = tl.teams and tl.teams[s]
        if team and st.smax[s] > 0 then
            local tc = S.team_color(team)
            parts[#parts + 1] = string.format("|c%s%s  %s|r",
                hexc(tc), team_name(team), F.commas((series[s] and series[s][idx]) or 0))
        end
    end
    if st.lanes then
        for _, lane in ipairs(st.lanes) do
            local own, hit = 0, nil
            for _, seg in ipairs(lane.segs) do
                if want_t >= seg.t0 and want_t < seg.t1 then
                    own, hit = seg.own, seg
                    break
                end
            end
            local label = (hit and hit.name) or lane_label(lane)
            if own ~= 0 then
                local tc = S.team_color(own)
                local holder = team_name(own)
                if hit and hit.who then
                    if hit.who == st.mine then tc, holder = K.COLOR.you, "you" else holder = hit.who end
                end
                parts[#parts + 1] = string.format("|c%s%s  %s|r",
                    hexc(tc), label, holder)
            elseif hit or not lane.covered then
                parts[#parts + 1] = string.format("|c8c8c95%s  neutral|r", label)
            end
        end
    end

    if st.kf then
        local shown, extra = 0, 0
        for _, k in ipairs(st.kf) do
            if k.t and math.abs(k.t - want_t) <= 8000 then
                if shown >= 4 then
                    extra = extra + 1
                elseif k.kn and k.dn then
                    local tc = S.team_color(k.kt)
                    parts[#parts + 1] = string.format("|c%s%s|r killed %s  @ %s",
                        hexc(tc), k.kn, k.dn, F.duration(k.t))
                    shown = shown + 1
                elseif k.kind then
                    parts[#parts + 1] = string.format("%s @ %s",
                        k.kind == "kill" and "your kill" or "your death", F.duration(k.t))
                    shown = shown + 1
                end
            end
        end
        if extra > 0 then
            parts[#parts + 1] = string.format("+%d more kills here", extra)
        end
    end

    if U.card_show then
        U.card_show(b.chart, TOP, table.concat(parts, "\n"))
    end
    if BGMeter.UI.map and BGMeter.UI.map.is_open() then BGMeter.UI.map.set_time(want_t, true) end
end

function W._chart_hover_start()
    if not W.chart_state then return end
    BGMeter.zenimax.events.register_update("BGMeterChartHover", 100, chart_hover_poll)
end

function W._chart_hover_stop()
    BGMeter.zenimax.events.unregister_update("BGMeterChartHover")
    if W.battle and W.battle.cursor then W.battle.cursor:SetHidden(true) end
    if U.card_hide then U.card_hide() end
end

local function ensure_duel_icons(b)
    if b.nemesisIcon then return end
    b.nemesisIcon = P.icon(b.container, "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds")
    b.nemesisIcon:SetDimensions(18, 18)
    b.nemesisIcon:SetAnchor(LEFT, b.headers.name, RIGHT, 12, -1)
    S.color(b.nemesisIcon, K.COLOR.accent)
    b.nemesisIcon:SetHidden(true)
    b.nemesisHit = hit_proxy(b.nemesisIcon)
    W.tip_static(b.nemesisHit, "")

    b.preyIcon = P.icon(b.container, "EsoUI/Art/HUD/HUD_Countdown_Badge_Dueling.dds")
    b.preyIcon:SetDimensions(18, 18)
    b.preyIcon:SetAnchor(LEFT, b.nemesisIcon, RIGHT, 8, 0)
    S.color(b.preyIcon, K.COLOR.gold)
    b.preyIcon:SetHidden(true)
    b.preyHit = hit_proxy(b.preyIcon)
    W.tip_static(b.preyHit, "")
end

function SEC.duels(m)
    local b = W.battle
    ensure_duel_icons(b)
    local d = m and BGMeter.Match.duels(m)
    if d and d.nemesis then
        b.nemesisIcon:SetHidden(false)
        b.nemesisHit:SetHidden(false)
        W.tips[b.nemesisHit] = string.format("Nemesis: %s\nKilled you %d time%s this match",
            d.nemesis.name, d.nemesis.count, d.nemesis.count == 1 and "" or "s")
    else
        b.nemesisIcon:SetHidden(true)
        b.nemesisHit:SetHidden(true)
        W.tips[b.nemesisHit] = nil
    end
    if d and d.prey then
        b.preyIcon:SetHidden(false)
        b.preyHit:SetHidden(false)
        W.tips[b.preyHit] = string.format("Prey: %s\nYou killed them %d time%s this match",
            d.prey.name, d.prey.count, d.prey.count == 1 and "" or "s")
    else
        b.preyIcon:SetHidden(true)
        b.preyHit:SetHidden(true)
        W.tips[b.preyHit] = nil
    end
end
