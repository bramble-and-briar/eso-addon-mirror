BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local SEC = U.SEC
local TX = U.TX
local set_text, mk_button, team_icon, apply_map_art = U.set_text, U.mk_button, U.team_icon, U.apply_map_art

local C = BGMeter.zenimax.constants
local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style

local PIP_ART    = "EsoUI/Art/Battlegrounds/battleground_round_%s.dds"
local PIP_EMPTY  = "EsoUI/Art/Battlegrounds/battleground_round_empty.dds"

local TEAM_KEY

local function team_art_key(team)
    if not TEAM_KEY then
        TEAM_KEY = {}
        if C.BATTLEGROUND_TEAM_FIRE_DRAKES then TEAM_KEY[C.BATTLEGROUND_TEAM_FIRE_DRAKES] = "fire" end
        if C.BATTLEGROUND_TEAM_PIT_DAEMONS then TEAM_KEY[C.BATTLEGROUND_TEAM_PIT_DAEMONS] = "pit" end
        if C.BATTLEGROUND_TEAM_STORM_LORDS then TEAM_KEY[C.BATTLEGROUND_TEAM_STORM_LORDS] = "storm" end
    end
    return TEAM_KEY[team]
end

local function build_header(win)
    local h = {}
    h.emblem = P.icon(win, K.LOGO)
    h.emblem:SetDimensions(78, 78)
    h.emblem:SetAnchor(TOPLEFT, win, TOPLEFT, -20, -20)
    if h.emblem.SetDrawLevel then h.emblem:SetDrawLevel(20) end

    h.title = P.label(win, S.FONT.title, K.COLOR.text)
    h.title:SetText(K.TITLE)
    h.title:SetAnchor(LEFT, h.emblem, RIGHT, 2, 5)

    h.subtitle = P.label(win, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(h.subtitle)
    h.subtitle:SetAnchor(TOPLEFT, win, TOPLEFT, L.margin + 2, 45)
    h.subtitle:SetDimensions(240, 14)

    h.bannerGlow = P.icon(win, "EsoUI/Art/Crafting/crafting_tooltip_glow_center.dds")
    h.bannerGlow:SetAnchor(TOP, win, TOP, 0, 2)
    h.bannerGlow:SetDimensions(360, 64)
    if h.bannerGlow.SetBlendMode then h.bannerGlow:SetBlendMode(TEX_BLEND_MODE_ADD) end
    h.bannerGlow:SetHidden(true)

    h.banner = P.label(win, S.FONT.banner, K.COLOR.text)
    h.banner:SetAnchor(TOP, win, TOP, 0, 8)
    h.banner:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    h.chips = {}
    for i = 1, 3 do
        local chip = {}
        chip.icon = P.icon(win)
        chip.icon:SetDimensions(18, 18)
        chip.label = P.label(win, S.FONT.small, K.COLOR.text)
        chip.label:SetAnchor(LEFT, chip.icon, RIGHT, 3, 0)
        chip.label:SetHeight(18)
        chip.icon:SetHidden(true)
        chip.label:SetHidden(true)
        h.chips[i] = chip
    end

    h.close = U.mk_plate_button(win, TX.close, 26, function() W.hide() end, "Close")
    h.close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -9, 12)

    h.gear = U.mk_text_button(win, "Settings", 72, 26, function() W.toggle_settings() end, "Open the settings", true)
    h.gear:SetAnchor(TOPRIGHT, win, TOPRIGHT, -41, 12)

    h.next = U.mk_plate_button(win, TX.nextb, 26, function() W.step(1) end, "Older match")
    h.next:SetAnchor(TOPRIGHT, win, TOPRIGHT, -121, 12)

    h.counter = P.label(win, S.FONT.small, K.COLOR.text_dim)
    h.counter:SetAnchor(TOPRIGHT, win, TOPRIGHT, -151, 17)
    h.counter:SetDimensions(48, 18)
    h.counter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    h.prev = U.mk_plate_button(win, TX.prev, 26, function() W.step(-1) end, "Newer match")
    h.prev:SetAnchor(TOPRIGHT, win, TOPRIGHT, -203, 12)

    return h
end

local function layout_chips(m)
    local h = W.header
    local teams = m and m.teams
    local n = (teams and #teams) or 0
    if n == 0 then
        for i = 1, 3 do h.chips[i].icon:SetHidden(true); h.chips[i].label:SetHidden(true) end
        return
    end
    local multi = (m.numRounds or 1) > 1
    local widths, total = {}, 0
    for i = 1, 3 do
        local chip, t = h.chips[i], teams[i]
        if t then
            local txt
            if multi then
                local pips = {}
                local key = team_art_key(t.team)
                local colorName = key and K.TEAM_ART[key] or nil
                for r = 1, math.min(m.numRounds, 5) do
                    pips[#pips + 1] = F.icon((r <= (t.roundsWon or 0)) and (colorName and PIP_ART:format(colorName) or PIP_EMPTY) or PIP_EMPTY, 12)
                end
                txt = table.concat(pips, "")
            else
                txt = F.abbrev(t.score or 0)
            end
            chip.label:SetText(txt)
            local tc = S.team_color(t.team)
            chip.label:SetColor(tc[1], tc[2], tc[3], 1)
            local ic = team_icon(t.team)
            if ic then chip.icon:SetTexture(ic); chip.icon:SetColor(1, 1, 1, 1)
            else chip.icon:SetTexture("EsoUI/Art/Collections/favorite_starOnly.dds"); chip.icon:SetColor(tc[1], tc[2], tc[3], 1) end
            local wpx = 21 + chip.label:GetTextWidth()
            widths[i] = wpx
            total = total + wpx
        end
    end
    local GAPX = 18
    total = total + GAPX * (n - 1)
    local x = -total / 2
    for i = 1, 3 do
        local chip, t = h.chips[i], teams[i]
        if t and widths[i] then
            chip.icon:ClearAnchors()
            chip.icon:SetAnchor(TOP, W.win, TOP, x + 9, 46)
            chip.icon:SetHidden(false)
            chip.label:SetHidden(false)
            x = x + widths[i] + GAPX
        else
            chip.icon:SetHidden(true)
            chip.label:SetHidden(true)
        end
    end
end

function SEC.header(m)
    local total = BGMeter.History.count()
    local dur = (m.durationMs and m.durationMs > 0) and ("  ·  " .. F.duration(m.durationMs)) or ""
    local when = ""
    local A = BGMeter.zenimax.api
    if m.capturedAt and type(A.get_timestamp) == "function" then
        local ago = A.get_timestamp() - m.capturedAt
        if ago >= 0 then when = "  ·  " .. (ago < 60 and "just now" or (F.countdown(ago) .. " ago")) end
    end
    set_text(W.header.subtitle, (m.name or "Battleground") .. dur .. when)
    set_text(W.header.counter, string.format("%d / %d", W.current_index, math.max(total, 1)))
    local glow = W.header.bannerGlow
    local function set_banner(text, col, glowCol)
        set_text(W.header.banner, text); S.color(W.header.banner, col)
        if glow then
            if glowCol then glow:SetColor(glowCol[1], glowCol[2], glowCol[3], K.ALPHA.banner_glow); glow:SetHidden(false)
            else glow:SetHidden(true) end
        end
    end
    if m.result == "WIN" then set_banner("VICTORY", K.COLOR.heal, K.COLOR.heal)
    elseif m.result == "LOSS" then set_banner("DEFEAT", K.COLOR.accent, K.COLOR.accent)
    elseif m.result == "TIE" then set_banner("DRAW", K.COLOR.gold, K.COLOR.gold)
    else set_banner("MATCH RESULTS", K.COLOR.text_dim, nil) end
    apply_map_art(m)
    layout_chips(m)
end

U.build_header = build_header
U.layout_chips = layout_chips
