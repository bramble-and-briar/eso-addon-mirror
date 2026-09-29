
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = {}
BGMeter.UI._win = U

local C = BGMeter.zenimax.constants
local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Bar = BGMeter.Plot.bar
local Prefs = BGMeter.Prefs
local Anim = BGMeter.Anim

local W = {}
W.built = false
W.current_index = 1
W.on_hud = true

local ICON_STAR  = "EsoUI/Art/Collections/favorite_starOnly.dds"
local ICON_SORTUP = "EsoUI/Art/Miscellaneous/list_sortUp.dds"
local ICON_SORTDN = "EsoUI/Art/Miscellaneous/list_sortDown.dds"

local TX = {
    close  = { n = "EsoUI/Art/Buttons/decline_up.dds",   p = "EsoUI/Art/Buttons/decline_down.dds",   o = "EsoUI/Art/Buttons/decline_over.dds" },
    gear   = { n = "EsoUI/Art/MenuBar/menuBar_mainMenu_over.dds", p = "EsoUI/Art/MenuBar/menuBar_mainMenu_down.dds", o = "EsoUI/Art/MenuBar/menuBar_mainMenu_over.dds" },
    prev   = { n = "EsoUI/Art/Buttons/large_leftArrow_up.dds",  p = "EsoUI/Art/Buttons/large_leftArrow_down.dds",  o = "EsoUI/Art/Buttons/large_leftArrow_over.dds" },
    nextb  = { n = "EsoUI/Art/Buttons/large_rightArrow_up.dds", p = "EsoUI/Art/Buttons/large_rightArrow_down.dds", o = "EsoUI/Art/Buttons/large_rightArrow_over.dds" },
    satchel = { n = "EsoUI/Art/Help/help_tabIcon_itemAssistance_up.dds", p = "EsoUI/Art/Help/help_tabIcon_itemAssistance_down.dds", o = "EsoUI/Art/Help/help_tabIcon_itemAssistance_over.dds" },
    vet    = { n = "EsoUI/Art/Campaign/campaign_tabIcon_veterancy_up.dds", p = "EsoUI/Art/Campaign/campaign_tabIcon_veterancy_down.dds", o = "EsoUI/Art/Campaign/campaign_tabIcon_veterancy_over.dds" },
    board  = { n = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_up.dds", p = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_down.dds", o = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_over.dds" },
    about  = { n = "EsoUI/Art/Help/help_tabIcon_overview_up.dds", p = "EsoUI/Art/Help/help_tabIcon_overview_down.dds", o = "EsoUI/Art/Help/help_tabIcon_overview_over.dds" },
    saved  = { n = "EsoUI/Art/Inventory/inventory_tabIcon_container_up.dds", p = "EsoUI/Art/Inventory/inventory_tabIcon_container_down.dds", o = "EsoUI/Art/Inventory/inventory_tabIcon_container_over.dds" },
    lock   = { n = "EsoUI/Art/Miscellaneous/locked_up.dds", p = "EsoUI/Art/Miscellaneous/locked_down.dds", o = "EsoUI/Art/Miscellaneous/locked_over.dds" },
    unlock = { n = "EsoUI/Art/Miscellaneous/unlocked_up.dds", p = "EsoUI/Art/Miscellaneous/unlocked_down.dds", o = "EsoUI/Art/Miscellaneous/unlocked_over.dds" },
    map    = { n = "EsoUI/Art/MainMenu/menuBar_map_up.dds", p = "EsoUI/Art/MainMenu/menuBar_map_down.dds", o = "EsoUI/Art/MainMenu/menuBar_map_over.dds" },
}

local MODE_SHORT = {
    deathmatch = "DM", domination = "DOM", crazy_king = "CK",
    king_of_the_hill = "KOTH", capture_the_flag = "CTF", murderball = "BALL",
}

local function mode_tag(m)
    local gt = C.GAME_TYPE_LABEL[m.gameType]
    local tag = MODE_SHORT[gt] or "?"
    if m.teamSize then
        local k = m.numTeams or (type(m.teams) == "table" and #m.teams) or 2
        if k < 2 then k = 2 end
        tag = tag .. "  " .. string.rep(m.teamSize .. "v", k - 1) .. m.teamSize
    end
    return tag
end
U.mode_tag = mode_tag

local function result_color(res)
    if res == "WIN" then return K.COLOR.heal end
    if res == "LOSS" then return K.COLOR.accent end
    if res == "TIE" then return K.COLOR.gold end
    return K.COLOR.text_dim
end

function U.balance_color(score)
    if score >= 60 then return K.COLOR.heal end
    if score >= 35 then return K.COLOR.gold end
    return K.COLOR.accent
end

function U.balance_scale_color(t)
    local red, gold, green = K.COLOR.accent, K.COLOR.gold, K.COLOR.heal
    local a, b, u
    if t < 0.35 then a, b, u = red, gold, t / 0.35
    elseif t < 0.60 then a, b, u = gold, green, (t - 0.35) / 0.25
    else a, b, u = green, green, 0 end
    return { a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u }
end

local MAP_ART = {
    ["temple"]            = "esoui/art/loadingscreens/loadscreen_battleground_temple_01.dds",
    ["castle courtyard"]  = "esoui/art/loadingscreens/loadscreen_battleground_castle_courtyard_01.dds",
    ["castle"]            = "esoui/art/loadingscreens/loadscreen_battleground_castle_courtyard_01.dds",
    ["city street"]       = "esoui/art/loadingscreens/loadscreen_battleground_city_streets_01.dds",
    ["city"]              = "esoui/art/loadingscreens/loadscreen_battleground_city_streets_01.dds",
    ["sewer"]             = "esoui/art/loadingscreens/loadscreen_battleground_sewer_01.dds",
    ["desert"]            = "esoui/art/loadingscreens/loadscreen_battleground_alikr_desert_01.dds",
    ["alik"]              = "esoui/art/loadingscreens/loadscreen_battleground_alikr_desert_01.dds",
    ["coliseum"]          = "esoui/art/loadingscreens/loadscreen_battleground_arena_coliseum_01.dds",
    ["colosseum"]         = "esoui/art/loadingscreens/loadscreen_battleground_arena_coliseum_01.dds",
    ["forest"]            = "esoui/art/loadingscreens/loadscreen_battleground_bosmer_forest_01.dds",
    ["grove"]             = "esoui/art/loadingscreens/loadscreen_battleground_bosmer_forest_01.dds",
    ["wood elf"]          = "esoui/art/loadingscreens/loadscreen_battleground_bosmer_forest_01.dds",
    ["ald carac"]         = "esoui/art/loadingscreens/loadscreen_battleground_ald_carac_01.dds",
    ["arcane university"] = "esoui/art/loadingscreens/loadscreen_battleground_arcaneuniversity_01.dds",
    ["deeping drome"]     = "esoui/art/loadingscreens/loadscreen_battleground_deepingdrome_01.dds",
    ["eld angavar"]       = "esoui/art/loadingscreens/loadscreen_battleground_eld_angavar_01.dds",
    ["foyada quarry"]     = "esoui/art/loadingscreens/loadscreen_battleground_foyadaquarry_01.dds",
    ["istirus outpost"]   = "esoui/art/loadingscreens/loadscreen_battleground_istirusoutpost_01.dds",
    ["mor khazgur"]       = "esoui/art/loadingscreens/loadscreen_battleground_morkhazgur_01.dds",
    ["ularra"]            = "esoui/art/loadingscreens/loadscreen_battleground_ularra_01.dds",
}
local MAP_ART_FALLBACK = "esoui/art/battlegrounds/gamepad/gp_battlegrounds_scoretracker.dds"

local function set_text(label, text) if label then label:SetText(text or "") end end

local function make_clickable(control, fn)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then fn() end end)
end

local card = nil

local function card_build()
    if card then return card end
    local wm = BGMeter.zenimax.ui.wm
    local root = wm:CreateTopLevelWindow("BGMeterHoverCard")
    root:SetDrawTier(DT_HIGH)
    if DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
    root:SetDrawLevel(5000)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    local bg = P.rect(root, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.96 })
    bg:SetAnchorFill(root)
    P.frame(root):SetAnchorFill(root)
    local strip = P.rect(root, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, root, TOPLEFT, 4, 4)
    strip:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 4, -4)
    strip:SetWidth(2)
    local text = P.label(root, S.FONT.small, K.COLOR.text)
    text:SetAnchor(TOPLEFT, root, TOPLEFT, 14, 8)
    text:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    text:SetVerticalAlignment(TEXT_ALIGN_TOP)
    if text.SetMaxLineCount then text:SetMaxLineCount(8) end
    card = { root = root, text = text }
    return card
end

local CARD_MAX_W = 340

function U.card_show(anchor, side, message)
    if not message or message == "" or not anchor then return end
    local c = card_build()
    c.text:SetWidth(CARD_MAX_W)
    c.text:SetText(message)
    local tw = math.min(CARD_MAX_W, (c.text:GetTextWidth() or 0) + 2)
    c.text:SetWidth(tw)
    local th = c.text:GetTextHeight() or 14
    c.root:SetDimensions(tw + 28, th + 16)
    c.root:ClearAnchors()
    if side == TOP then c.root:SetAnchor(BOTTOM, anchor, TOP, 0, -6)
    elseif side == LEFT then c.root:SetAnchor(RIGHT, anchor, LEFT, -6, 0)
    elseif side == RIGHT then c.root:SetAnchor(LEFT, anchor, RIGHT, 6, 0)
    else c.root:SetAnchor(TOP, anchor, BOTTOM, 0, 6) end
    c.root:SetHidden(false)
    if c.root.BringWindowToTop then c.root:BringWindowToTop() end
    U.card_last = message
end

function U.card_hide()
    if card then card.root:SetHidden(true) end
    U.card_last = nil
end

function U.card_control() return card and card.root or nil end

W.tips = {}
function W.tip_dynamic(control)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function()
        local t = W.tips[control]
        BGMeter.Log.debug("tip enter: %s (text=%s)", tostring(control:GetName()), t and "yes" or "no")
        if t and t ~= "" and U.card_show then U.card_show(control, BOTTOM, t) end
    end)
    control:SetHandler("OnMouseExit", function()
        if U.card_hide then U.card_hide() end
    end)
end
function W.tip_static(control, text) W.tips[control] = text; W.tip_dynamic(control) end

local function mk_button(parent, tx, size, onclick, tipText)
    local b = P.button(parent, tx.n, tx.p, tx.o)
    b._tex_normal = tx.n
    b:SetDimensions(size, size)
    b:SetHandler("OnClicked", function() onclick() end)
    if tipText then
        b:SetHandler("OnMouseEnter", function() if U.card_show then U.card_show(b, BOTTOM, tipText) end end)
        b:SetHandler("OnMouseExit", function() if U.card_hide then U.card_hide() end end)
    end
    return b
end

local function anim_on(want) return want and Prefs.get("animate") end

local function set_count(label, value, prefix, animate)
    value = value or 0; prefix = prefix or ""
    if anim_on(animate) and value ~= 0 then
        Anim.value(0, value, K.ANIM.count_ms, function(v) set_text(label, prefix .. F.commas(math.floor(v + 0.5))) end)
    else
        set_text(label, prefix .. F.commas(value))
    end
end

local function set_bar(bar, pct, color, width, animate)
    if anim_on(animate) then Anim.value(0, pct, K.ANIM.bar_ms, function(v) Bar.set(bar, v, color, width) end)
    else Bar.set(bar, pct, color, width) end
end

local function pop(control)
    if not control or not Prefs.get("animate") then return end
    Anim.start(K.ANIM.pop_ms, function(t)
        control:SetScale(1 + math.sin(t * math.pi) * 0.22)
    end, function() control:SetScale(1) end)
end

local function team_name(team)
    if team == nil then return "" end
    local A = BGMeter.zenimax.api
    if type(A.get_team_name) == "function" then
        local ok, name = pcall(A.get_team_name, team)
        if ok and name and name ~= "" then return name end
    end
    if team == C.BATTLEGROUND_TEAM_FIRE_DRAKES then return "Fire Drakes" end
    if team == C.BATTLEGROUND_TEAM_PIT_DAEMONS then return "Pit Daemons" end
    if team == C.BATTLEGROUND_TEAM_STORM_LORDS then return "Storm Lords" end
    return ""
end

local function team_icon(team)
    if team == nil then return nil end
    local A = BGMeter.zenimax.api
    if type(A.get_team_icon) == "function" then
        local ok, icon = pcall(A.get_team_icon, team)
        if ok and icon and icon ~= "" then return icon end
    end
    return nil
end

local function hide_all(list, hidden) for _, c in ipairs(list) do c:SetHidden(hidden) end end

local function row_chrome(container)
    local base = P.icon(container, "EsoUI/Art/Miscellaneous/listItem_backdrop.dds")
    base:SetAnchorFill(container)
    base:SetColor(1, 1, 1, 0.9)
    local hl = P.rect(container, { 1, 1, 1, K.ALPHA.row_hover })
    hl:SetAnchorFill(container)
    hl:SetHidden(true)
    return base, hl
end

local function clamp_line(lbl)
    if not lbl then return end
    if lbl.SetMaxLineCount then lbl:SetMaxLineCount(1) end
    if TEXT_WRAP_MODE_ELLIPSIS and lbl.SetWrapMode then
        lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
end

local function inset_bar(parent)
    local bar = {}
    bar.container = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    bar.border = P.rect(bar.container, { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.35 })
    bar.border:SetAnchorFill(bar.container)
    bar.back = P.rect(bar.container, { 0, 0, 0, 0.62 })
    bar.back:SetAnchor(TOPLEFT, bar.container, TOPLEFT, 1, 1)
    bar.back:SetAnchor(BOTTOMRIGHT, bar.container, BOTTOMRIGHT, -1, -1)
    bar.fill = P.rect(bar.container, K.COLOR.gold)
    bar.fill:SetAnchor(TOPLEFT, bar.container, TOPLEFT, 1, 1)
    bar.fill:SetAnchor(BOTTOMLEFT, bar.container, BOTTOMLEFT, 1, -1)
    bar.fill:SetWidth(0)
    return bar
end

local function inset_bar_set(bar, pct, color, width)
    if not bar then return end
    pct = math.max(0, math.min(1, pct or 0))
    P.set_rect_color(bar.fill, color or K.COLOR.gold)
    bar.fill:SetWidth(math.max(0, math.floor((width - 2) * pct + 0.5)))
end

local function lane_metrics(n)
    local L = K.LAYOUT
    if not n or n <= 6 then return L.lane_h, L.lane_gap end
    if n <= 9 then return 8, 4 end
    return 6, 2
end

local function player_ident(r)
    local d, c = r.displayName, r.charName
    if c then c = (c:gsub("%^.*$", "")) end
    if d then d = (d:gsub("%^.*$", "")) end
    if d and c and c ~= "" and c ~= d then
        return string.format("%s (%s)", d, c)
    end
    return d or c or "?"
end

local function hit_proxy(target)
    local h = BGMeter.zenimax.ui.create_control(nil, target:GetParent(), CT_CONTROL)
    h:SetAnchorFill(target)
    return h
end

local hexc = F.hexc

local function neutral_color()
    return { 0.55, 0.55, 0.60 }
end

local function flag_pin(gt, letter, team)
    local key = S.team_art_key(team)
    local mobile = (gt == "crazy_king" or gt == "king_of_the_hill")
    if letter and letter:match("^[ABCD]$") then
        if mobile then
            return string.format("EsoUI/Art/MapPins/battlegrounds_mobileCapturePoint_pin_%s_%s.dds", key, letter)
        end
        return string.format("EsoUI/Art/MapPins/battlegrounds_multiCapturePoint_%s_pin_%s.dds", letter, key)
    end
    if mobile then
        return string.format("EsoUI/Art/MapPins/battlegrounds_mobileCapturePoint_pin_%s.dds", key)
    end
    return string.format("EsoUI/Art/MapPins/battlegrounds_capturePoint_pin_%s.dds", key)
end

local function map_art_candidates(m, name)
    local out, seen = {}, {}
    local function add(path)
        if path and path ~= "" and not seen[path] then seen[path] = true; out[#out + 1] = path end
    end
    local lower = name:lower():gsub("%^.*$", "")
    for key, path in pairs(MAP_ART) do
        if lower:find(key, 1, true) then add(path) end
    end
    local words = {}
    for w in lower:gmatch("[a-z]+") do words[#words + 1] = w end
    local function guess(slug)
        add(string.format("esoui/art/loadingscreens/loadscreen_battleground_%s_01.dds", slug))
    end
    for k = #words, 1, -1 do
        guess(table.concat(words, "_", 1, k))
        guess(table.concat(words, "", 1, k))
        guess(table.concat(words, "_", 1, k) .. "s")
    end
    add(MAP_ART_FALLBACK)
    return out
end

local MAP_ART_CHECKS = 3
local MAP_ART_CHECK_MS = 350

local function apply_map_art(m)
    local art = W.bgMap
    if not art then return end
    local name = (m and m.name) or ""
    if name == "" then art:SetHidden(true); return end
    local cands = map_art_candidates(m, name)
    if #cands == 0 then art:SetHidden(true); return end

    W.map_token = (W.map_token or 0) + 1
    local token = W.map_token
    local idx, tries = 0, 0
    local check
    local function try_next()
        if token ~= W.map_token then return end
        idx = idx + 1
        tries = 0
        if idx > #cands then
            art:SetHidden(true)
            BGMeter.Log.debug("map art: no candidate loaded for '%s' (%d tried)", name, #cands)
            return
        end
        art:SetTexture(cands[idx])
        art:SetHidden(false)
        if type(zo_callLater) ~= "function" then return end
        zo_callLater(check, MAP_ART_CHECK_MS)
    end
    check = function()
        if token ~= W.map_token then return end
        local ok, loaded = pcall(function() return art:IsTextureLoaded() end)
        if ok and loaded == false then
            tries = tries + 1
            if tries < MAP_ART_CHECKS then
                zo_callLater(check, MAP_ART_CHECK_MS)
            else
                try_next()
            end
        else
            W.map_art_path = cands[idx]
            BGMeter.Log.debug("map art resolved: %s", cands[idx])
        end
    end
    W.map_art_path = nil
    try_next()
end

local SEC = {}

U.W = W
U.SEC = SEC
U.TX = TX
U.ICON_STAR = ICON_STAR
U.ICON_SORTUP = ICON_SORTUP
U.ICON_SORTDN = ICON_SORTDN
U.set_text = set_text
U.make_clickable = make_clickable
U.mk_button = mk_button
U.set_count = set_count
U.set_bar = set_bar
U.pop = pop
U.team_name = team_name
U.team_icon = team_icon
U.hide_all = hide_all
U.player_ident = player_ident
U.row_chrome = row_chrome
U.lane_metrics = lane_metrics
U.inset_bar = inset_bar
U.inset_bar_set = inset_bar_set
U.clamp_line = clamp_line
U.hit_proxy = hit_proxy
U.hexc = hexc
U.neutral_color = neutral_color
U.flag_pin = flag_pin
U.apply_map_art = apply_map_art
U.mode_tag = mode_tag
U.result_color = result_color

W._sections = SEC
BGMeter.UI.window = W
