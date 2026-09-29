BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local set_text, mk_button = U.set_text, U.mk_button
local TX = U.TX

local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs
local Sound = BGMeter.Sound
local Drawer = BGMeter.UI.Drawer
local Panel = BGMeter.UI.panel
local Queue = BGMeter.UI.queue

local M = {}

local LAUNCHER_ICON = "bgmeter/assets/launcher.dds"
local LAUNCHER_IDLE = 0.90

local MENU_ART = "esoui/art/loadingscreens/loadscreen_battleground_ularra_01.dds"
local MENU_ART_ALPHA = 0.30

local MENU_W = 388
local MENU_H = 530
local ROW_H = 28
local HEAD_H = 46
local PANEL_H = 128
local QUEUE_H = 36
local FOOT_H = 34
local INSET_PAD = 20
local SCROLL_W = 8
local ARROW = 16
local MIN_H, MAX_AUTO_H = 390, 764

local Scene = BGMeter.zenimax.scene

local layout_scrollbar
local built = false
local launcher = nil
local panel = nil
local rows = {}
local offset = 0
local on_hud = true
local reopen_after_report = false
local drag = { on = false, y0 = 0, off0 = 0 }
local armed_index = nil
local DISARM_MS = 3000

local function clean(s)
    if not s or s == "" then return nil end
    return (tostring(s):gsub("%^.*$", ""))
end

local function sv_launcher()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return { x = 0, y = 0 } end
    sv.launcher = sv.launcher or { x = 0, y = 0 }
    return sv.launcher
end

local function sv_menu()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return { x = 0, y = 0, w = 0, h = 0 } end
    sv.menu = sv.menu or { x = 0, y = 0, w = 0, h = 0 }
    return sv.menu
end

local function ago_label(capturedAt)
    local A = BGMeter.zenimax.api
    local now = (type(A.get_timestamp) == "function") and A.get_timestamp() or nil
    if not capturedAt or not now or now <= capturedAt then return "" end
    local s = now - capturedAt
    if s < 3600 then return math.floor(s / 60) .. "m ago" end
    if s < 86400 then return math.floor(s / 3600) .. "h ago" end
    return math.floor(s / 86400) .. "d ago"
end

local result_color, mode_tag = U.result_color, U.mode_tag
local flash, flash_until = nil, 0
local FLASH_MS = 3000

local art_tries = 0

local function apply_art_cover()
    if not built then return end
    local art = panel.art
    local w = panel.win:GetWidth() - 4
    local h = panel.win:GetHeight() - 4
    if w <= 0 or h <= 0 then return end
    local tw, th
    pcall(function() tw, th = art:GetTextureFileDimensions() end)
    if not tw or tw <= 0 or not th or th <= 0 then
        art:SetTextureCoords(0, 1, 0, 1)
        if art_tries < 3 and type(zo_callLater) == "function" then
            art_tries = art_tries + 1
            zo_callLater(apply_art_cover, 350)
        end
        return
    end
    art_tries = 0
    local ca = w / h
    local ta = tw / th
    if ta > ca then
        local uw = ca / ta
        local u0 = (1 - uw) / 2
        art:SetTextureCoords(u0, u0 + uw, 0, 1)
    else
        local vh = ta / ca
        local v0 = (1 - vh) / 2
        art:SetTextureCoords(0, 1, v0, v0 + vh)
    end
end

local function auto_height()
    local mg = sv_menu()
    if (mg.h or 0) > 0 then return end
    local count = BGMeter.History.count()
    local want = HEAD_H + PANEL_H + QUEUE_H + FOOT_H + 18 + math.max(count, 1) * (ROW_H + 2)
    panel.win:SetHeight(math.max(MIN_H, math.min(want, MAX_AUTO_H)))
end

local function each_drawer(method, ...)
    for _, d in ipairs(Drawer.all()) do d[method](d, ...) end
end

local function make_row(i)
    local r = {}
    r.container = BGMeter.zenimax.ui.create_control(nil, panel.inset, CT_CONTROL)
    r.container:SetMouseEnabled(true)

    r.base, r.highlight = U.row_chrome(r.container)

    r.pip = P.rect(r.container, K.COLOR.text_dim)
    r.pip:SetDimensions(3, ROW_H - 12)
    r.pip:SetAnchor(LEFT, r.container, LEFT, 4, 0)

    r.name = P.label(r.container, S.FONT.row, K.COLOR.text)
    r.name:SetAnchor(LEFT, r.container, LEFT, 14, 0)
    r.name:SetHeight(ROW_H)
    U.clamp_line(r.name)

    r.kda = P.label(r.container, S.FONT.small, K.COLOR.text_dim)
    r.kda:SetAnchor(RIGHT, r.container, RIGHT, -172, 0)
    r.kda:SetDimensions(60, ROW_H)
    r.kda:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    U.clamp_line(r.kda)

    r.mode = P.label(r.container, S.FONT.small, K.COLOR.text_dim)
    r.mode:SetAnchor(RIGHT, r.container, RIGHT, -106, 0)
    r.mode:SetDimensions(62, ROW_H)
    r.mode:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    U.clamp_line(r.mode)

    r.ago = P.label(r.container, S.FONT.small, K.COLOR.text_dim)
    r.ago:SetAnchor(RIGHT, r.container, RIGHT, -44, 0)
    r.ago:SetDimensions(56, ROW_H)
    r.ago:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    U.clamp_line(r.ago)

    r.delArm = P.rect(r.container, { K.COLOR.accent[1], K.COLOR.accent[2], K.COLOR.accent[3], 0.55 })
    r.delArm:SetDimensions(20, 20)
    r.delArm:SetAnchor(RIGHT, r.container, RIGHT, -3, 0)
    r.delArm:SetHidden(true)

    r.del = mk_button(r.container, TX.close, 14, function()
        M.request_delete(r.index)
    end, "Delete this match\nClick twice")
    r.del:SetAnchor(RIGHT, r.container, RIGHT, -6, 0)

    r.lock = mk_button(r.container, TX.unlock, 14, function() M.toggle_pin(r.index) end)
    r.lock:SetAnchor(RIGHT, r.container, RIGHT, -24, 0)
    r.lock:SetHandler("OnMouseEnter", function(b)
        if r.lockTip and U.card_show then U.card_show(b, BOTTOM, r.lockTip) end
    end)
    r.lock:SetHandler("OnMouseExit", function()
        if U.card_hide then U.card_hide() end
    end)

    r.container:SetHandler("OnMouseEnter", function()
        r.highlight:SetHidden(false)
        if r.tip and U.card_show then
            U.card_show(r.container, BOTTOM, r.tip)
        end
    end)
    r.container:SetHandler("OnMouseExit", function()
        r.highlight:SetHidden(true)
        if U.card_hide then U.card_hide() end
    end)
    r.container:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside and r.index then
            Sound.play("match")
            reopen_after_report = true
            M.hide_menu(true)
            BGMeter.UI.window.show_match(r.index)
        end
    end)
    return r
end

local function build_launcher()
    local g = sv_launcher()
    local LSZ = 56
    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterLauncher")
    win:SetDimensions(LSZ, LSZ)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    if g.x == 0 and g.y == 0 then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 24, 240)
    else
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, g.x, g.y)
    end
    win:SetHandler("OnMoveStop", function()
        g = sv_launcher()
        g.x, g.y = win:GetLeft(), win:GetTop()
    end)
    win:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then M.toggle() end
    end)
    launcher = { win = win }

    launcher.pip = P.icon(win, "EsoUI/Art/Inventory/newItem_icon.dds")
    launcher.pip:SetDimensions(18, 18)
    launcher.pip:SetAnchor(TOPRIGHT, win, TOPRIGHT, 5, -5)
    launcher.pip:SetHidden(true)

    launcher.glowFx = P.icon(win, "bgmeter/assets/glow.dds")
    launcher.glowFx:SetAnchor(CENTER, win, CENTER, 0, 0)
    launcher.glowFx:SetDimensions(LSZ * 2.2, LSZ * 2.2)
    if launcher.glowFx.SetBlendMode then launcher.glowFx:SetBlendMode(TEX_BLEND_MODE_ADD) end
    launcher.glowFx:SetHidden(true)

    launcher.glow = P.icon(win, LAUNCHER_ICON)
    launcher.glow:SetAnchor(CENTER, win, CENTER, 0, 0)
    launcher.glow:SetDimensions(LSZ + 12, LSZ + 12)
    launcher.glow:SetHidden(true)

    launcher.icon = P.icon(win, LAUNCHER_ICON)
    launcher.icon:SetAnchorFill(win)
    launcher.icon:SetColor(1, 1, 1, LAUNCHER_IDLE)

    local GLOW_COLORS = { K.COLOR.team.fire, K.COLOR.team.storm, K.COLOR.team.pit }
    local GLOW_CYCLE_MS = 2100
    local Anim = BGMeter.Anim

    local function glow_tick(t)
        if not launcher.hovered then return end
        local phase = t * #GLOW_COLORS
        local i = math.min(math.floor(phase) + 1, #GLOW_COLORS)
        local j = (i % #GLOW_COLORS) + 1
        local f = phase - (i - 1)
        local a, b2 = GLOW_COLORS[i], GLOW_COLORS[j]
        local r = a[1] + (b2[1] - a[1]) * f
        local g2 = a[2] + (b2[2] - a[2]) * f
        local bch = a[3] + (b2[3] - a[3]) * f
        launcher.glow:SetColor(r, g2, bch, 0.65)
        local pulse = 0.55 + 0.35 * (0.5 + 0.5 * math.sin(t * math.pi * 4))
        launcher.glowFx:SetColor(r, g2, bch, pulse)
    end

    local function glow_loop()
        if not launcher.hovered then return end
        Anim.start(GLOW_CYCLE_MS, glow_tick, glow_loop, function(t) return t end)
    end

    win:SetHandler("OnMouseEnter", function()
        launcher.hovered = true
        launcher.icon:SetColor(1, 1, 1, 1)
        launcher.glow:SetHidden(false)
        launcher.glowFx:SetHidden(false)
        glow_loop()
    end)
    win:SetHandler("OnMouseExit", function()
        launcher.hovered = false
        launcher.glow:SetHidden(true)
        launcher.glowFx:SetHidden(true)
        launcher.icon:SetColor(1, 1, 1, LAUNCHER_IDLE)
    end)
end

local function build()
    if built then return end
    build_launcher()

    local mg = sv_menu()
    local pw = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterMenu")
    pw:SetDimensions((mg.w and mg.w > 0) and mg.w or MENU_W, (mg.h and mg.h > 0) and mg.h or MENU_H)
    pw:SetMouseEnabled(true)
    pw:SetMovable(true)
    pw:SetClampedToScreen(true)
    pw:SetHidden(true)
    pw:SetDrawTier(DT_HIGH)
    pw:SetResizeHandleSize(L.resize_h)
    pw:SetDimensionConstraints(384, 280, 560, 780)
    pw:SetHandler("OnMoveStop", function()
        mg = sv_menu()
        mg.x, mg.y = pw:GetLeft(), pw:GetTop()
    end)
    pw:SetHandler("OnResizeStop", function()
        mg = sv_menu()
        mg.w, mg.h = pw:GetWidth(), pw:GetHeight()
        apply_art_cover()
        each_drawer("on_host_resized")
        M.refresh()
    end)
    pw:SetHandler("OnMouseWheel", function(_, delta) M.scroll_to(offset - delta) end)
    pw:SetHandler("OnMouseUp", function() M.on_thumb_up() end)
    pw:SetHandler("OnMouseDoubleClick", function() M.on_double_click() end)
    Scene.register_top_level(pw, function() M.hide_menu() end)
    panel = { win = pw }

    local bg = P.rect(pw, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.97 })
    bg:SetAnchorFill(pw)

    panel.art = P.icon(pw, MENU_ART)
    panel.art:SetAnchor(TOPLEFT, pw, TOPLEFT, 2, 2)
    panel.art:SetAnchor(BOTTOMRIGHT, pw, BOTTOMRIGHT, -2, -2)
    panel.art:SetColor(1, 1, 1, MENU_ART_ALPHA)

    P.frame(pw):SetAnchorFill(pw)

    local strip = P.rect(pw, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, pw, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, pw, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    panel.logo = P.icon(pw, K.LOGO)
    panel.logo:SetDimensions(60, 60)
    panel.logo:SetAnchor(TOPLEFT, pw, TOPLEFT, -15, -15)
    if panel.logo.SetDrawLevel then panel.logo:SetDrawLevel(20) end

    panel.title = P.label(pw, S.FONT.title, K.COLOR.text)
    panel.title:SetText(K.TITLE .. "  ·  Registry")
    panel.title:SetAnchor(LEFT, panel.logo, RIGHT, 2, 8)

    panel.close = mk_button(pw, TX.close, 20, function() M.hide_menu() end, "Close")
    panel.close:SetAnchor(TOPRIGHT, pw, TOPRIGHT, -14, 15)

    panel.gear = mk_button(pw, TX.gear, 28, function() W.toggle_settings() end, "Settings")
    panel.gear:SetAnchor(RIGHT, panel.close, LEFT, -8, 0)

    panel.stats = Panel.build(pw, {
        head_h = HEAD_H, inset_pad = INSET_PAD,
        open_veterancy = function() M.open_veterancy() end,
        claim_veterancy = function() M.claim_veterancy() end,
        open_leaderboard = function() M.open_leaderboard() end,
    })

    panel.inset = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL)
    panel.inset:SetAnchor(TOPLEFT, pw, TOPLEFT, INSET_PAD, HEAD_H + PANEL_H)
    panel.inset:SetAnchor(BOTTOMRIGHT, pw, BOTTOMRIGHT, -INSET_PAD, -(FOOT_H + QUEUE_H))
    panel.inset:SetMouseEnabled(false)

    panel.queue = Queue.build(pw, {
        x = INSET_PAD, y = -(FOOT_H + 3),
        visible = function() return built and not panel.win:IsHidden() end,
        on_update = function() M.update_footer() end,
    })

    panel.insetBg = P.rect(panel.inset, { 0, 0, 0, 0.45 })
    panel.insetBg:SetAnchorFill(panel.inset)
    P.frame(panel.inset):SetAnchorFill(panel.inset)

    panel.scroll = {}
    local ac = K.COLOR.accent
    local up = P.button(panel.inset, "EsoUI/Art/Buttons/scrollbox_upArrow_up.dds", "EsoUI/Art/Buttons/scrollbox_upArrow_down.dds", "EsoUI/Art/Buttons/scrollbox_upArrow_over.dds")
    up:SetDimensions(ARROW, ARROW)
    up:SetAnchor(TOPRIGHT, panel.inset, TOPRIGHT, 0, 4)
    up:SetHandler("OnClicked", function() M.scroll_to(offset - 1) end)
    up:SetHidden(true)
    panel.scroll.up = up
    local down = P.button(panel.inset, "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds", "EsoUI/Art/Buttons/scrollbox_downArrow_down.dds", "EsoUI/Art/Buttons/scrollbox_downArrow_over.dds")
    down:SetDimensions(ARROW, ARROW)
    down:SetAnchor(BOTTOMRIGHT, panel.inset, BOTTOMRIGHT, 0, -4)
    down:SetHandler("OnClicked", function() M.scroll_to(offset + 1) end)
    down:SetHidden(true)
    panel.scroll.down = down
    local track = BGMeter.zenimax.ui.create_control(nil, panel.inset, CT_CONTROL)
    track:SetAnchor(TOPRIGHT, panel.inset, TOPRIGHT, -4, ARROW + 6)
    track:SetAnchor(BOTTOMRIGHT, panel.inset, BOTTOMRIGHT, -4, -(ARROW + 6))
    track:SetWidth(SCROLL_W)
    track:SetMouseEnabled(true)
    track:SetHidden(true)
    track:SetHandler("OnMouseUp", function(_, _, upInside)
        if drag.on then M.on_thumb_up() return end
        if upInside then M.on_track_click() end
    end)
    panel.scroll.track = track
    panel.scroll.trackBg = P.rect(track, { ac[1], ac[2], ac[3], 0.12 })
    panel.scroll.trackBg:SetAnchorFill(track)
    local thumb = BGMeter.zenimax.ui.create_control(nil, track, CT_CONTROL)
    thumb:SetAnchor(TOPLEFT, track, TOPLEFT, 0, 0)
    thumb:SetWidth(SCROLL_W)
    thumb:SetMouseEnabled(true)
    local thumbTex = P.rect(thumb, { ac[1], ac[2], ac[3], 0.55 })
    thumbTex:SetAnchorFill(thumb)
    thumb:SetHandler("OnMouseDown", function() M.on_thumb_down() end)
    thumb:SetHandler("OnMouseUp", function() M.on_thumb_up() end)
    thumb:SetHandler("OnMouseEnter", function() if not drag.on then P.set_rect_color(thumbTex, { ac[1], ac[2], ac[3], 0.85 }) end end)
    thumb:SetHandler("OnMouseExit", function() if not drag.on then P.set_rect_color(thumbTex, { ac[1], ac[2], ac[3], 0.55 }) end end)
    panel.scroll.thumb = thumb
    panel.scroll.thumbTex = thumbTex

    panel.empty = P.label(panel.inset, S.FONT.small, K.COLOR.text_dim)
    panel.empty:SetText("no battlegrounds recorded yet\nqueue up below to record your first battle")
    panel.empty:SetAnchor(CENTER, panel.inset, CENTER, 0, 0)
    panel.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    panel.empty:SetHidden(true)

    panel.footer = P.label(pw, S.FONT.small, K.COLOR.text_dim)
    panel.footer:SetAnchor(BOTTOMLEFT, pw, BOTTOMLEFT, 12, -9)
    panel.footer:SetAnchor(BOTTOMRIGHT, pw, BOTTOMRIGHT, -12, -9)
    panel.footer:SetHeight(14)
    panel.footer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    U.clamp_line(panel.footer)
    each_drawer("init", pw)

    built = true
end

function M.update_footer(count, vis)
    if not built then return end
    local Cap = BGMeter.Capture
    if Cap and Cap.is_active and Cap.is_active() then
        local nm, el = Cap.live()
        set_text(panel.footer, string.format("|cf2cc55recording %s  ·  %s|r",
            clean(nm) or "battleground", F.duration(el or 0)))
        return
    end
    if flash then
        local now = BGMeter.zenimax.api.now_ms and BGMeter.zenimax.api.now_ms() or 0
        if now < flash_until then
            set_text(panel.footer, flash)
            return
        end
        flash = nil
    end
    count = count or BGMeter.History.count()
    vis = vis or math.min(count, panel.vis or count)
    if panel.vis and count > panel.vis then
        set_text(panel.footer, string.format("%d-%d of %d  ·  scroll for more", offset + 1, offset + vis, count))
    else
        set_text(panel.footer, count > 0 and (count .. (count == 1 and " battleground" or " battlegrounds")) or "")
    end
end

function M.update_queue() Queue.update() end
function M.queue_click() Queue.click() end

local function max_offset()
    return math.max(0, BGMeter.History.count() - (panel.vis or 1))
end

function layout_scrollbar(count, maxOff)
    local sc = panel.scroll
    sc.up:SetHidden(maxOff <= 0 or offset <= 0)
    sc.down:SetHidden(maxOff <= 0 or offset >= maxOff)
    if maxOff <= 0 then sc.track:SetHidden(true) return end
    local th = sc.track:GetHeight()
    if th <= 0 then sc.track:SetHidden(true) return end
    local thumbH = math.floor(th * panel.vis / count + 0.5)
    if thumbH < 16 then thumbH = 16 end
    if thumbH > th then thumbH = th end
    local y = math.floor((th - thumbH) * offset / maxOff + 0.5)
    sc.thumb:SetHeight(thumbH)
    sc.thumb:ClearAnchors()
    sc.thumb:SetAnchor(TOPLEFT, sc.track, TOPLEFT, 0, y)
    sc.track:SetHidden(false)
end

function M.scroll_to(want)
    if not built then return end
    want = math.max(0, math.min(want, max_offset()))
    if want == offset then return end
    offset = want
    M.disarm_delete()
    M.refresh()
end

function M.on_track_click()
    if drag.on then return end
    local track = panel.scroll.track
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    local th = track:GetHeight()
    if not my or th <= 0 then return end
    local rel = (my - track:GetTop()) / th
    M.scroll_to(math.floor(rel * (max_offset() + 1)))
end

local function drag_update()
    if not drag.on then return end
    local track, thumb = panel.scroll.track, panel.scroll.thumb
    local free = track:GetHeight() - thumb:GetHeight()
    local maxOff = max_offset()
    if free <= 0 or maxOff <= 0 then return end
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    if not my then return end
    M.scroll_to(drag.off0 + math.floor((my - drag.y0) * maxOff / free + 0.5))
end

function M.on_thumb_down()
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    drag.on, drag.y0, drag.off0 = true, my or 0, offset
    local ac = K.COLOR.accent
    P.set_rect_color(panel.scroll.thumbTex, { ac[1], ac[2], ac[3], 0.95 })
    panel.win:SetHandler("OnUpdate", drag_update)
end

function M.on_thumb_up()
    if not drag.on then return end
    drag.on = false
    panel.win:SetHandler("OnUpdate", nil)
    local ac = K.COLOR.accent
    P.set_rect_color(panel.scroll.thumbTex, { ac[1], ac[2], ac[3], 0.55 })
end

function M.scroll_controls() return panel and panel.scroll end

function M.window() return panel and panel.win end

function M.scroll_state()
    return offset, panel and panel.scroll and not panel.scroll.track:IsHidden(), panel and panel.scroll and panel.scroll.thumb:GetHeight() or 0
end

function M.refresh()
    if not built or panel.win:IsHidden() then return end
    local H = BGMeter.History
    local count = H.count()

    Panel.refresh()
    each_drawer("refresh")

    local w = panel.win:GetWidth()
    local h = panel.win:GetHeight()

    Queue.layout(math.max(36, w - 2 * INSET_PAD - 168 - 4 - 92 - 8 - 20))
    local insetH = h - HEAD_H - PANEL_H - QUEUE_H - FOOT_H - 10
    panel.vis = math.max(1, math.floor(insetH / (ROW_H + 2)))

    local maxOff = math.max(0, count - panel.vis)
    if offset > maxOff then offset = maxOff end
    local vis = math.min(count - offset, panel.vis)

    local scrolling = maxOff > 0
    local roww = w - 2 * INSET_PAD - 10 - (scrolling and (SCROLL_W + 6) or 0)
    panel.empty:SetHidden(count > 0)
    layout_scrollbar(count, maxOff)

    for i = 1, vis do
        local r = rows[i]
        if not r then
            r = make_row(i)
            rows[i] = r
        end
        local idx = offset + i
        local m = H.get(idx)
        r.index = idx
        r.container:ClearAnchors()
        r.container:SetAnchor(TOPLEFT, panel.inset, TOPLEFT, 5, 4 + (i - 1) * (ROW_H + 2))
        r.container:SetDimensions(roww, ROW_H)
        r.container:SetHidden(false)
        r.highlight:SetHidden(true)
        r.delArm:SetHidden(armed_index ~= idx)
        r.name:SetWidth(math.max(72, roww - 250))
        local pinned = m.pinned and true or false
        if r.m ~= m or r._pinned ~= pinned then
            local tx = pinned and TX.lock or TX.unlock
            r.lock:SetNormalTexture(tx.n)
            r.lock:SetPressedTexture(tx.p)
            r.lock:SetMouseOverTexture(tx.o)
            r.lock._tex_normal = tx.n
            r.lock:SetAlpha(pinned and 1 or 0.55)
            r.lockTip = pinned and "Saved: never pruned\nClick to release it"
                or string.format("Save this match\nKept outside the %d cap, charts and all", BGMeter.History.PIN_CAP)
            P.set_rect_color(r.pip, result_color(m.result))
            set_text(r.name, m.name or "Battleground")
            set_text(r.mode, mode_tag(m))
            local lr = BGMeter.Match.local_row(m)
            set_text(r.kda, lr and string.format("|c%s%d|r/%d/%d", U.hexc(K.COLOR.you), lr.kills or 0, lr.deaths or 0, lr.assists or 0) or "")
            local score = m.result or ""
            if m.teams and #m.teams >= 2 then
                score = string.format("%s  %d - %d", m.result or "", m.teams[1].score or 0, m.teams[2].score or 0)
            end
            r.tip = string.format("%s\n%s%s", clean(m.name) or "Battleground", score,
                lr and string.format("\nyou  %d/%d/%d  ·  %s dmg  ·  %s heal",
                    lr.kills or 0, lr.deaths or 0, lr.assists or 0,
                    F.abbrev(lr.damage or 0), F.abbrev(lr.healing or 0)) or "")
            r.m, r._pinned = m, pinned
        end
        S.color(r.name, (BGMeter.UI.window.current() == idx and not BGMeter.UI.window.is_hidden()) and K.COLOR.you or K.COLOR.text)
        local ago = ago_label(m.capturedAt)
        if r._ago ~= ago then
            set_text(r.ago, ago)
            r._ago = ago
        end
    end
    for i = vis + 1, #rows do
        rows[i].container:SetHidden(true)
        rows[i].index = nil
    end

    M.update_footer(count, vis)
end

function M.delete(index)
    M.disarm_delete()
    if not BGMeter.History.delete(index) then return end
    Sound.play("nav")
    W.on_history_changed(index)
    auto_height()
    apply_art_cover()
    M.refresh()
end

function M.disarm_delete()
    if not armed_index then return end
    armed_index = nil
    BGMeter.zenimax.events.unregister_update("BGMeterDisarm")
    for _, r in ipairs(rows) do r.delArm:SetHidden(true) end
end

function M.request_delete(index)
    if not index or not BGMeter.History.get(index) then return false end
    if BGMeter.History.is_pinned(index) then
        M.disarm_delete()
        Sound.play("deny")
        flash = string.format("|c%ssaved match  ·  release the lock to delete it|r", U.hexc(K.COLOR.accent))
        flash_until = (BGMeter.zenimax.api.now_ms and BGMeter.zenimax.api.now_ms() or 0) + FLASH_MS
        M.update_footer()
        return false
    end
    if armed_index == index then
        M.delete(index)
        return true
    end
    M.disarm_delete()
    armed_index = index
    for _, r in ipairs(rows) do r.delArm:SetHidden(r.index ~= index) end
    Sound.play("nav")
    BGMeter.zenimax.events.register_update("BGMeterDisarm", DISARM_MS, M.disarm_delete)
    return false
end

function M.armed_index() return armed_index end

function M.toggle_pin(index)
    local H = BGMeter.History
    if not index or not H.get(index) then return false end
    local ok
    if H.is_pinned(index) then
        ok = H.unpin(index)
        if ok then Sound.play("close") end
    else
        local why
        ok, why = H.pin(index)
        if ok then Sound.play("pb")
        elseif why == "full" then
            Sound.play("deny")
            flash = string.format("|c%ssaved matches are full (%d)  ·  release one first|r", U.hexc(K.COLOR.accent), H.PIN_CAP)
            flash_until = (BGMeter.zenimax.api.now_ms and BGMeter.zenimax.api.now_ms() or 0) + FLASH_MS
        end
    end
    if BGMeter.Storage then BGMeter.Storage.invalidate() end
    each_drawer("invalidate")
    M.refresh()
    return ok
end

function M.stat_text(key) return Panel.stat_text(key) end
function M.stat_link_hidden(key) return Panel.stat_link_hidden(key) end
function M.stat_claim_hidden(key) return Panel.stat_claim_hidden(key) end
function M.stat_claim_tip(key) return Panel.stat_claim_tip(key) end
function M.podium_on() return Panel.podium_on() end
function M.row_kda(i) return rows[i] and rows[i].kda:GetText() or nil end
function M.rows() return rows end
function M.footer_text() return panel and panel.footer:GetText() or nil end

function M.on_double_click()
    if not built then return end
    local _, y = BGMeter.zenimax.api.get_ui_mouse()
    local top = panel.win:GetTop()
    if y == nil or y < top or y > top + HEAD_H then return end
    local mg = sv_menu()
    mg.w, mg.h = 0, 0
    panel.win:SetDimensions(MENU_W, MENU_H)
    auto_height()
    apply_art_cover()
    Sound.play("nav")
    M.refresh()
end

function M.claim_veterancy()
    if BGMeter.Veterancy.claim() then Sound.play("nav") end
    M.refresh_if_visible()
end

function M.open_veterancy()
    if Scene.push("VeterancySceneKeyboard") then Sound.play("nav") end
end

function M.open_leaderboard()
    local C = BGMeter.zenimax.constants
    if Scene.push_bg_leaderboard(C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE) then Sound.play("nav") end
end

local DEMO_RANKS = { 480, 200, 80, 40, 20, 7, 1 }
function M.demo_trophy()
    if not built then build() end
    local idx = M._demo_idx or 0
    idx = idx + 1
    if idx > #DEMO_RANKS then
        M._demo_idx, M._demo_rank = nil, nil
        BGMeter.Log.say("trophy demo OFF (real standing restored)")
    else
        M._demo_idx, M._demo_rank = idx, DEMO_RANKS[idx]
        BGMeter.Log.say("trophy demo: rank #%d", M._demo_rank)
    end
    if panel.win:IsHidden() then M.show_menu() else M.refresh() end
end

function M.show_menu()
    if not built then return end
    M.clear_unread()
    local mg = sv_menu()
    panel.win:ClearAnchors()
    if (mg.x or 0) ~= 0 or (mg.y or 0) ~= 0 then
        panel.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, mg.x, mg.y)
    else
        panel.win:SetAnchor(TOPLEFT, launcher.win, BOTTOMRIGHT, 2, 2)
    end
    panel.win:SetHidden(false)
    if Prefs.get("cursor_on_open") then Scene.enter_ui_mode() end
    offset = 0
    auto_height()
    apply_art_cover()
    Queue.populate()
    Queue.update()
    M.refresh()
    each_drawer("on_menu_shown")
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    if type(A.query_bg_leaderboard) == "function" then
        pcall(A.query_bg_leaderboard, C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE)
    end
    Sound.play("menu")
end

function M.hide_menu(silent)
    Panel.podium_stop()
    if not built then return end
    local was_visible = not panel.win:IsHidden()
    M.disarm_delete()
    Drawer.blur_all()
    panel.win:SetHidden(true)
    if not silent and was_visible then Sound.play("close") end
    Queue.stop_ticker()
end

function M.toggle()
    if not built then return end
    if panel.win:IsHidden() then M.show_menu() else M.hide_menu() end
end

function M.is_hidden()
    return not built or panel.win:IsHidden()
end

function M.forget_reopen() reopen_after_report = false end

function M.on_report_closed()
    if not reopen_after_report then return end
    reopen_after_report = false
    if built and Prefs.get("show_launcher") and on_hud then
        M.show_menu()
    end
end

function M.mark_unread()
    if built then launcher.pip:SetHidden(false) end
end

function M.clear_unread()
    if built then launcher.pip:SetHidden(true) end
end

function M.on_game_menu()
    reopen_after_report = false
    M.hide_menu(true)
end

function M.refresh_if_visible()
    if built and not panel.win:IsHidden() then
        auto_height()
        M.refresh()
    end
end

function M.sync()
    if not built then return end
    launcher.win:SetHidden(not (Prefs.get("show_launcher") and on_hud))
    if not on_hud then M.hide_menu(true) end
end

function M.on_scene(hud)
    on_hud = hud
    M.sync()
end

function M.on_scene_state(newState)
    if newState == SCENE_SHOWN then M.on_scene(true)
    elseif newState == SCENE_HIDDEN and not BGMeter.zenimax.scene.next_is_hud() then M.on_scene(false) end
end

function M.init()
    build()
    local C = BGMeter.zenimax.constants
    if C.EVENT_ACTIVITY_FINDER_STATUS_UPDATE then
        BGMeter.zenimax.events.register("BGMeterQueue", C.EVENT_ACTIVITY_FINDER_STATUS_UPDATE,
            function() Queue.update() end)
    end
    if SCENE_MANAGER then
        local function handler(_, newState) M.on_scene_state(newState) end
        for _, name in ipairs({ "hud", "hudui" }) do
            local ok, sc = pcall(function() return SCENE_MANAGER:GetScene(name) end)
            if ok and sc and type(sc.RegisterCallback) == "function" then
                pcall(function() sc:RegisterCallback("StateChange", handler) end)
            end
        end
    end
    on_hud = (BGMeter.zenimax.scene and BGMeter.zenimax.scene.is_hud_scene()) and true or false
    M.sync()
    BGMeter.Log.debug("menu ready (launcher %s)", Prefs.get("show_launcher") and "shown" or "hidden")
end

BGMeter.UI.menu = M
