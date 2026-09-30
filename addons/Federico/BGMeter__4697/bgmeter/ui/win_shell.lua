BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local SEC = U.SEC
local TX = U.TX
local set_text, mk_button, team_name, team_icon = U.set_text, U.mk_button, U.team_name, U.team_icon
local layout_chips = U.layout_chips
local flag_col_spec, caps_count = U.flag_col_spec, U.caps_count
local build_header, build_battle, build_haul = U.build_header, U.build_battle, U.build_haul
local hide_medal_card = U.hide_medal_card

local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs
local Anim = BGMeter.Anim
local Sound = BGMeter.Sound

local Scene = BGMeter.zenimax.scene

local settings_open = false
local user_visible = false
local in_combat = false

local function in_header()
    if not W.built then return false end
    local _, y = BGMeter.zenimax.api.get_ui_mouse()
    local top = W.win:GetTop()
    local scale = W.win:GetScale() or 1
    return y ~= nil and y >= top and y <= top + L.header_h * scale
end

local SCOREBG_L  = "EsoUI/Art/Battlegrounds/battlegrounds_scoreboardBG_left.dds"
local SCOREBG_R  = "EsoUI/Art/Battlegrounds/battlegrounds_scoreboardBG_right.dds"

local AUTO_OPEN_STATES = { "exit", "instant", "off" }
local AUTO_OPEN_LABELS = { exit = "ON EXIT", instant = "INSTANT", off = "OFF" }
local HISTORY_STATES = { 25, 50, 100 }
local HISTORY_LABELS = { [25] = "25", [50] = "50", [100] = "100" }

local SETTINGS_SECTIONS = {
    { title = "GENERAL", rows = {
        { kind = "cycle",  key = "auto_open_mode", label = "Auto-open results",
          states = AUTO_OPEN_STATES, labels = AUTO_OPEN_LABELS },
        { kind = "toggle", key = "show_launcher",  label = "Launcher icon" },
        { kind = "toggle", key = "cursor_on_open", label = "Registry opens with cursor" },
        { kind = "toggle", key = "sounds",         label = "Sound cues" },
        { kind = "toggle", key = "animate",        label = "Animations" },
        { kind = "cycle",  key = "max_history",    label = "Matches kept",
          states = HISTORY_STATES, labels = HISTORY_LABELS },
    } },
    { title = "RESULT WINDOW", rows = {
        { kind = "toggle", key = "group_by_team",  label = "Group players by team" },
        { kind = "toggle", key = "show_haul",      label = "Haul panel" },
        { kind = "toggle", key = "show_veterancy", label = "Veterancy track" },
        { kind = "toggle", key = "show_standing",  label = "Standing / session panel" },
        { kind = "toggle", key = "show_awards",    label = "MVP / column leaders" },
        { kind = "toggle", key = "show_timeline",  label = "Match timeline chart" },
        { kind = "toggle", key = "show_balance",   label = "Match balance strip" },
        { kind = "toggle", key = "show_race",      label = "Damage race strip" },
        { kind = "toggle", key = "show_kills",     label = "Kill pressure strip" },
        { kind = "toggle", key = "show_faces",     label = "Familiar faces" },
        { kind = "slider", key = "opacity",        label = "Background opacity",
          min = 0.60, max = 1.0, step = 0.01 },
    } },
}

local function text_button(parent, label)
    local b = BGMeter.zenimax.ui.create_from_virtual(nil, parent, "ZO_DefaultButton")
    b:SetText(label)
    return b
end

local function on_pref_changed(key)
    if key == "show_launcher" and BGMeter.UI.menu then
        BGMeter.UI.menu.sync()
    end
    Sound.play("nav")
    W.render(false)
end

local function build_settings()
    local s = {}
    local ROW_H, SEC_H, PADX = 28, 24, 18

    local rowsTotal = 0
    for _, sec in ipairs(SETTINGS_SECTIONS) do rowsTotal = rowsTotal + #sec.rows end
    local winH = 56 + #SETTINGS_SECTIONS * SEC_H + rowsTotal * ROW_H + 92

    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterSettingsWindow")
    win:SetDimensions(324, winH)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(5)
    s.window = win

    local bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.98 })
    bg:SetAnchorFill(win)
    P.frame(win):SetAnchorFill(win)

    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    local emblem = P.icon(win, K.LOGO)
    emblem:SetDimensions(20, 20)
    emblem:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 13)
    local title = P.label(win, S.FONT.title, K.COLOR.text)
    title:SetText(K.TITLE .. "  ·  Settings")
    title:SetAnchor(LEFT, emblem, RIGHT, 8, 0)

    s.close = mk_button(win, TX.close, 20, function() W.toggle_settings() end, "Close")
    s.close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 15)

    s.rows = {}
    local y = 48
    for _, sec in ipairs(SETTINGS_SECTIONS) do
        local head = P.label(win, S.FONT.small, K.COLOR.gold)
        head:SetText(sec.title)
        head:SetAnchor(TOPLEFT, win, TOPLEFT, PADX, y + 6)
        head:SetDimensions(200, 14)
        local rule = P.rect(win, { 1, 1, 1, 0.08 })
        rule:SetAnchor(TOPLEFT, win, TOPLEFT, PADX, y + SEC_H - 2)
        rule:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PADX, y + SEC_H - 2)
        rule:SetHeight(1)
        y = y + SEC_H

        for _, t in ipairs(sec.rows) do
            local name = P.label(win, S.FONT.row, K.COLOR.text)
            name:SetText(t.label)
            name:SetAnchor(TOPLEFT, win, TOPLEFT, PADX + 4, y)
            name:SetDimensions(190, ROW_H - 2)
            name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            local key, kind = t.key, t.kind
            local paint
            if kind == "slider" then
                local pct = P.label(win, S.FONT.small, K.COLOR.text_dim)
                pct:SetDimensions(38, ROW_H - 2)
                pct:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PADX, y)
                pct:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                pct:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                local sl = BGMeter.zenimax.ui.create_from_virtual(nil, win, "ZO_Slider")
                sl:SetDimensions(88, 14)
                sl:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(PADX + 42), y + 6)
                sl:SetMinMax(t.min or 0, t.max or 1)
                if sl.SetValueStep then sl:SetValueStep(t.step or 0.01) end
                local applying = false
                local function show(v) pct:SetText(string.format("%d%%", math.floor(v * 100 + 0.5))) end
                paint = function()
                    applying = true
                    local v = Prefs.get(key) or t.min or 0
                    sl:SetValue(v)
                    show(v)
                    applying = false
                end
                sl:SetHandler("OnValueChanged", function(_, v)
                    if applying then return end
                    v = math.floor(v * 100 + 0.5) / 100
                    Prefs.set(key, v)
                    show(v)
                    W._apply_visuals()
                end)
            else
                local btn = text_button(win, "")
                btn:SetDimensions(84, ROW_H - 4)
                btn:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PADX, y)
                if kind == "cycle" then
                    local states = t.states or AUTO_OPEN_STATES
                    local labels = t.labels or AUTO_OPEN_LABELS
                    paint = function() btn:SetText(labels[Prefs.get(key)] or "?") end
                    btn:SetHandler("OnClicked", function()
                        local cur = Prefs.get(key)
                        local idx = 1
                        for i, v in ipairs(states) do if v == cur then idx = i break end end
                        Prefs.set(key, states[(idx % #states) + 1])
                        paint(); on_pref_changed(key)
                    end)
                else
                    paint = function() btn:SetText(Prefs.get(key) and "ON" or "OFF") end
                    btn:SetHandler("OnClicked", function()
                        Prefs.toggle(key)
                        paint(); on_pref_changed(key)
                    end)
                end
            end
            s.rows[key] = paint
            y = y + ROW_H
        end
    end

    local clear = text_button(win, "Clear match history")
    clear:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PADX, -52)
    clear:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PADX, -52)
    clear:SetHeight(28)
    clear:SetHandler("OnClicked", function() W.confirm_clear() end)

    local reset = text_button(win, "Reset window size & position")
    reset:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PADX, -16)
    reset:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PADX, -16)
    reset:SetHeight(28)
    reset:SetHandler("OnClicked", function()
        local sv = BGMeter.zenimax.savedvars.get()
        if sv then
            sv.window.x, sv.window.y, sv.window.w, sv.window.h = 0, 0, 0, 0
            sv.window.scale = 1.0
        end
        W.cur_w, W.cur_h = L.window_w, L.window_h
        W.win:SetDimensions(W.cur_w, W.cur_h)
        W.win:SetScale(1)
        W.win:ClearAnchors(); W.win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        W.render(false)
    end)

    s.repaint = function() for _, paint in pairs(s.rows) do paint() end end
    return s
end

local function build()
    if W.built then return end

    local sv = BGMeter.zenimax.savedvars.get()
    W.cur_w = (sv and sv.window and sv.window.w and sv.window.w > 0) and sv.window.w or L.window_w
    W.cur_h = (sv and sv.window and sv.window.h and sv.window.h > 0) and sv.window.h or L.window_h

    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterWindow")
    win:SetDrawTier(DT_HIGH)
    win:SetDimensions(W.cur_w, W.cur_h)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetResizeHandleSize(L.resize_h)
    win:SetDimensionConstraints(L.min_w, L.min_h, L.max_w, L.max_h)
    win:SetHandler("OnMoveStop", function() W.on_move_stop() end)
    win:SetHandler("OnResizeStop", function() W.on_resize_stop() end)
    win:SetHandler("OnMouseWheel", function(_, delta) W.on_wheel(delta) end)
    win:SetHandler("OnMouseDoubleClick", function() W.on_double_click() end)
    Scene.register_top_level(win, function() W.on_escape() end)

    W.bg = P.rect(win, K.COLOR.bg)
    W.bg:SetAnchorFill(win)

    W.bgMap = P.icon(win)
    W.bgMap:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
    W.bgMap:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -2, -2)
    W.bgMap:SetColor(1, 1, 1, K.ALPHA.map_art)
    W.bgMap:SetHidden(true)

    W.bgArtL = P.icon(win, SCOREBG_L)
    W.bgArtL:SetAnchor(TOPLEFT, win, TOPLEFT, L.margin - 6, L.header_h - 4)
    W.bgArtL:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.haul_w + L.gap + L.margin - 6), -10)
    W.bgArtL:SetColor(1, 1, 1, K.ALPHA.score_art)

    W.bgArtR = P.icon(win, SCOREBG_R)
    W.bgArtR:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin - 6), L.header_h - 4)
    W.bgArtR:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.margin - 6), -10)
    W.bgArtR:SetWidth(L.haul_w + 12)
    W.bgArtR:SetColor(1, 1, 1, K.ALPHA.score_art)

    W.footerBd = P.rect(win, { K.COLOR.panel[1], K.COLOR.panel[2], K.COLOR.panel[3], K.ALPHA.footer_band })
    W.footerBd:SetAnchor(TOPLEFT, win, BOTTOMLEFT, 8, -(L.footer_h - 4))
    W.footerBd:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -8, -8)

    P.frame(win):SetAnchorFill(win)

    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    W.detail = P.label(win, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(W.detail)
    W.detail:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, L.margin, -10)
    W.detail:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -L.margin, -10)
    W.detail:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    W.win      = win
    W.header   = build_header(win)
    W.battle   = build_battle(win)
    W.haul     = build_haul(win)
    W.settings = build_settings()

    W.measure = P.label(win, S.FONT.row, K.COLOR.text)
    W.measure:SetHidden(true)

    W.emptyIcon = P.icon(win, "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds")
    W.emptyIcon:SetDimensions(72, 72)
    W.emptyIcon:SetAnchor(CENTER, win, CENTER, -(L.haul_w + L.gap) / 2, -30)
    W.emptyIcon:SetColor(1, 1, 1, 0.18)
    W.emptyIcon:SetHidden(true)

    if sv and sv.window then
        if not (sv.window.x == 0 and sv.window.y == 0) then
            win:ClearAnchors()
            win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.window.x, sv.window.y)
        end
        if sv.window.scale and sv.window.scale > 0 then win:SetScale(sv.window.scale) end
    end

    W.built = true
end

local function apply_visual_prefs()
    local op = Prefs.get("opacity") or 0.97
    P.set_rect_color(W.bg, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], op })
    W.haul.container:SetHidden(not Prefs.get("show_haul"))
end

function W._apply_visuals()
    if W.built then apply_visual_prefs() end
end

local function do_clear()
    BGMeter.History.clear()
    W.current_index = 1
    if settings_open then W.toggle_settings() end
    if W.built and not W.win:IsHidden() then W.render(false) end
    if BGMeter.UI.menu then BGMeter.UI.menu.refresh_if_visible() end
    BGMeter.Log.debug("match history cleared")
end

if ESO_Dialogs then
    ESO_Dialogs["BGMETER_CLEAR_HISTORY"] = {
        canQueue = true,
        title = { text = "Clear match history" },
        mainText = { text = "This permanently deletes EVERY recorded battleground.\n\nThere is no undo." },
        buttons = {
            { text = SI_DIALOG_CONFIRM, callback = do_clear },
            { text = SI_DIALOG_CANCEL },
        },
    }
end

function W.confirm_clear()
    if ESO_Dialogs and type(ZO_Dialogs_ShowDialog) == "function" then
        ZO_Dialogs_ShowDialog("BGMETER_CLEAR_HISTORY")
    else
        do_clear()
    end
end

function W.render(animate)
    if not W.built then return end
    if Anim then Anim.clear() end
    apply_visual_prefs()
    if W.settings then W.settings.repaint() end

    local m = BGMeter.History.get(W.current_index)
    if W.emptyIcon then W.emptyIcon:SetHidden(m ~= nil) end
    if not m then
        set_text(W.header.banner, "NO MATCHES YET"); S.color(W.header.banner, K.COLOR.text_dim)
        if W.header.bannerGlow then W.header.bannerGlow:SetHidden(true) end
        if W.bgMap then W.bgMap:SetHidden(true) end
        layout_chips(nil)
        set_text(W.header.subtitle, "finish a battleground, or try  /bgmeter demo")
        set_text(W.header.counter, "0 / 0")
        W.battle.row_pool:release_all()
        SEC.clear_chart(W.battle)
        SEC.duels(nil)
        set_text(W.detail, "")
        return
    end
    SEC.header(m)
    SEC.battle(m, animate)
    SEC.timeline(m)
    SEC.duels(m)
    SEC.haul(m, animate)
    W.render_detail(m)
    if BGMeter.UI.map then BGMeter.UI.map.on_report_render() end
end

function W.render_detail(m)
    if W.selected_row then
        local r = W.selected_row
        local ic = team_icon(r.team)
        local prefix = ic and (F.icon(ic, 16) .. " ") or ""
        local taken = (r.taken and r.taken > 0) and string.format("  ·  %s taken", F.abbrev(r.taken)) or ""
        local eff = ""
        local played = m and BGMeter.Match.played_ms(m) or 0
        if played > 0 then
            local dpm = math.floor((r.damage or 0) / math.max(1, played / 60000))
            eff = string.format("  ·  %s dpm", F.abbrev(dpm))
            if r.kills and r.kills > 0 then
                eff = eff .. string.format("  ·  %s per kill", F.abbrev(math.floor((r.damage or 0) / r.kills)))
            end
            local teamDmg = 0
            for _, row in ipairs(m.battle) do
                if row.team == r.team then teamDmg = teamDmg + (row.damage or 0) end
            end
            if teamDmg > 0 then
                eff = eff .. string.format("  ·  %d%% of team dmg",
                    math.floor((r.damage or 0) / teamDmg * 100 + 0.5))
            end
        end
        local capsTxt = ""
        if m and flag_col_spec(m) == "carried" then
            if (r.carried or 0) > 0 then capsTxt = string.format("  ·  held %s", F.duration(r.carried * 1000)) end
        elseif m then
            local n = caps_count(m, (r.caps or 0) + 0)
            if n > 0 then capsTxt = string.format("  ·  %d caps", n) end
            if (r.carried or 0) > 0 then
                capsTxt = capsTxt .. string.format("  ·  held %s", F.duration(r.carried * 1000))
            end
        end
        if (r.defPts or 0) > 0 then
            capsTxt = capsTxt .. string.format("  ·  %d def", r.defPts)
        end
        local ident = U.player_ident(r)
        set_text(W.detail, string.format("%s%s  ·  %s  --  %s dmg  ·  %s heal%s  ·  %d/%d/%d%s  ·  %d medals%s",
            prefix, ident, team_name(r.team),
            F.abbrev(r.damage), F.abbrev(r.healing), taken, r.kills, r.deaths, r.assists, capsTxt, r.medals or 0, eff))
        S.color(W.detail, K.COLOR.text_dim)
    else
        local session = BGMeter.Session and BGMeter.Session.summary()
        set_text(W.detail, session or "click a row for detail  ·  click a column header to sort  ·  drag an edge to resize")
        S.color(W.detail, session and K.COLOR.gold or K.COLOR.text_dim)
    end
end

local layers_debug = false

function W.toggle_layers_debug()
    build()
    layers_debug = not layers_debug
    local Log = BGMeter.Log
    if layers_debug then
        P.set_rect_color(W.bg, { 1, 0, 1, 0.85 })
        W.bgMap:SetColor(0, 1, 0, 0.50)
        W.bgArtL:SetColor(1, 0, 0, 0.70)
        W.bgArtR:SetColor(1, 0.55, 0, 0.70)
        P.set_rect_color(W.haul.bd, { 0, 0.4, 1, 0.70 })
        P.set_rect_color(W.battle.chartBg, { 1, 1, 0, 0.50 })
        P.set_rect_color(W.footerBd, { 0, 1, 1, 0.70 })
        Log.say("layer debug ON:")
        Log.say("  |cff00ffMAGENTA|r = base window rect (W.bg)")
        Log.say("  |c00ff00GREEN|r = map loading screen (bgMap)")
        Log.say("  |cff0000RED|r = scoreboardBG left art")
        Log.say("  |cff8c00ORANGE|r = scoreboardBG right art")
        Log.say("  |c0066ffBLUE|r = haul panel backdrop")
        Log.say("  |cffff00YELLOW|r = timeline chart strip")
        Log.say("  |c00ffffCYAN|r = footer band (new)")
        Log.say("run |cFFFFFF/bgmeter layers|r again to restore")
    else
        apply_visual_prefs()
        W.bgMap:SetColor(1, 1, 1, K.ALPHA.map_art)
        W.bgArtL:SetColor(1, 1, 1, K.ALPHA.score_art)
        W.bgArtR:SetColor(1, 1, 1, K.ALPHA.score_art)
        P.set_rect_color(W.haul.bd, K.COLOR.panel)
        P.set_rect_color(W.battle.chartBg, { 1, 1, 1, K.ALPHA.chart_bg })
        P.set_rect_color(W.footerBd, { K.COLOR.panel[1], K.COLOR.panel[2], K.COLOR.panel[3], K.ALPHA.footer_band })
        Log.say("layer debug OFF")
    end
end

function W.sort_by(key)
    if Prefs.get("sort_key") == key then Prefs.set("sort_desc", not Prefs.get("sort_desc"))
    else Prefs.set("sort_key", key); Prefs.set("sort_desc", true) end
    Sound.play("nav"); W.render(false)
end

function W.select(prow)
    W.selected_row = (W.selected_row == prow) and nil or prow
    W.render(false)
end

function W.step(dir)
    local total = BGMeter.History.count()
    if total == 0 then return end
    local want = math.max(1, math.min(total, W.current_index + dir))
    if want == W.current_index then return end
    W.current_index = want
    W.selected_row = nil
    Sound.play("match"); W.render(true)
end

function W.on_wheel(delta)
    if not in_header() then return end
    W.step(delta > 0 and -1 or 1)

end

function W.on_double_click()
    if not in_header() then return end
    W.win:SetDimensions(L.window_w, L.window_h)
    Sound.play("nav")
    W.on_resize_stop()
end

function W.toggle_settings()
    build()
    settings_open = not settings_open
    W.settings.window:SetHidden(not settings_open)
    if settings_open then
        W.settings.repaint()
        Sound.play("settings")
    else
        Sound.play("close")
    end
end

local function apply_visibility()
    if not W.built then return end
    local want = user_visible and W.on_hud and not in_combat
    local was_hidden = W.win:IsHidden()
    W.win:SetHidden(not want)
    if want and was_hidden then
        W.win:SetAlpha(1)
        W.render(false)
    end
    if not want and settings_open then
        settings_open = false
        W.settings.window:SetHidden(true)
    end
    if not want then
        W._chart_hover_stop()
        hide_medal_card()
        if BGMeter.UI.map then BGMeter.UI.map.on_report_hidden() end
    elseif was_hidden and BGMeter.UI.map then
        BGMeter.UI.map.on_report_shown()
    end
end

function W.on_scene(onHud)
    W.on_hud = onHud and true or false
    apply_visibility()
end

function W.on_scene_state(newState)
    if newState == SCENE_SHOWN then W.on_scene(true)
    elseif newState == SCENE_HIDDEN and not BGMeter.zenimax.scene.next_is_hud() then W.on_scene(false) end
end

function W.on_combat(_, inCombat)
    in_combat = inCombat and true or false
    apply_visibility()
end

function W.in_combat() return in_combat end

function W.ensure_built() build() end

function W.show_match(index)
    build()
    if BGMeter.UI.menu and BGMeter.UI.menu.clear_unread then BGMeter.UI.menu.clear_unread() end
    W.current_index = index or 1
    W.selected_row = nil
    settings_open = false
    W.settings.window:SetHidden(true)
    user_visible = true
    apply_visibility()
    if W.win:IsHidden() then return end
    W.render(true)
    if Prefs.get("animate") then
        W.win:SetAlpha(0)
        Anim.value(0, 1, K.ANIM.window_fade_ms, function(v) W.win:SetAlpha(v) end, function()
            W.win:SetAlpha(1)
            if W.repaint_chart then W.repaint_chart() end
        end)
    else W.win:SetAlpha(1) end
    W._persist_hidden(false)
end

function W.current() return W.current_index end

function W.is_hidden()
    return not W.built or W.win:IsHidden()
end

function W.show() W.show_match(W.current_index); Sound.play("open") end

function W.refresh_if_visible()
    if not W.built or W.win:IsHidden() then return end
    if W.current_index == 1 then W.render(false) end
end

function W.on_history_changed(removedIndex)
    if removedIndex and removedIndex < W.current_index then
        W.current_index = W.current_index - 1
    end
    local count = BGMeter.History.count()
    if W.current_index > count then W.current_index = math.max(count, 1) end
    W.selected_row = nil
    if W.built and not W.win:IsHidden() then W.render(false) end
end

local function after_hide(was_visible)
    settings_open = false
    W.settings.window:SetHidden(true)
    user_visible = false
    W._persist_hidden(true)
    W._chart_hover_stop()
    hide_medal_card()
    if BGMeter.UI.map then BGMeter.UI.map.on_report_hidden() end
    if was_visible then
        Sound.play("close")
        if BGMeter.UI.menu and BGMeter.UI.menu.on_report_closed then
            BGMeter.UI.menu.on_report_closed()
        end
    end
end

function W.hide()
    if not W.built then return end
    local was_visible = not W.win:IsHidden()
    user_visible = false
    W.win:SetHidden(true)
    after_hide(was_visible)
end

function W.on_escape()
    if not W.built or W.win:IsHidden() then return end
    if BGMeter.UI.menu and BGMeter.UI.menu.forget_reopen then BGMeter.UI.menu.forget_reopen() end
    W.hide()
end

function W.toggle()
    build()
    if user_visible then W.hide() else W.show() end
end

function W.on_move_stop()
    if not W.built then return end
    local sv = BGMeter.zenimax.savedvars.get()
    if sv then sv.window = sv.window or {}; sv.window.x = W.win:GetLeft(); sv.window.y = W.win:GetTop() end
end

function W.on_resize_stop()
    if not W.built then return end
    W.cur_w, W.cur_h = W.win:GetWidth(), W.win:GetHeight()
    local sv = BGMeter.zenimax.savedvars.get()
    if sv then sv.window = sv.window or {}; sv.window.w = W.cur_w; sv.window.h = W.cur_h end
    W.render(false)
end

function W._persist_hidden(hidden)
    local sv = BGMeter.zenimax.savedvars.get()
    if sv then sv.window = sv.window or {}; sv.window.hidden = hidden end
end

local function safe_m(obj, method, ...)
    if not obj or type(obj[method]) ~= "function" then return nil end
    local ok, a = pcall(obj[method], obj, ...)
    if not ok then return nil end
    return a
end

function W.init()
    local zc = BGMeter.zenimax.constants
    if zc.EVENT_PLAYER_COMBAT_STATE then
        BGMeter.zenimax.events.register("BGMeterWinCombat", zc.EVENT_PLAYER_COMBAT_STATE, W.on_combat)
    end
    if SCENE_MANAGER then
        local function handler(_, newState) W.on_scene_state(newState) end
        for _, name in ipairs({ "hud", "hudui" }) do
            local sc = safe_m(SCENE_MANAGER, "GetScene", name)
            if sc and type(sc.RegisterCallback) == "function" then
                pcall(function() sc:RegisterCallback("StateChange", handler) end)
            end
        end
        local gm = safe_m(SCENE_MANAGER, "GetScene", "gameMenuInGame")
        if gm and type(gm.RegisterCallback) == "function" then
            pcall(function()
                gm:RegisterCallback("StateChange", function(_, newState)
                    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                        if BGMeter.UI.menu and BGMeter.UI.menu.on_game_menu then
                            BGMeter.UI.menu.on_game_menu()
                        end
                        if settings_open then W.toggle_settings() end
                        if W.built and not W.win:IsHidden() then W.hide() end
                    end
                end)
            end)
        end
    end
    W.on_hud = (BGMeter.zenimax.scene and BGMeter.zenimax.scene.is_hud_scene()) and true or false
    BGMeter.Log.debug("window ready")
end
