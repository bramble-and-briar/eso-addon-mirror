BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local Prof = BGMeter.Prof
local U = BGMeter.UI._win
local K = BGMeter.Constants
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Sound = BGMeter.Sound
local set_text = U.set_text

local Drawer = {}
Drawer.__index = Drawer

local DRAWER_W = 236
local MEDAL = 48
local MEDAL_Y0 = 46 + 34
local MEDAL_STEP = 56
local HEAD_H = 46
local BAR_H = 28
local ROW_H = 26
local FOOT_H = 26
local PAD = 12
local ART = "esoui/art/loadingscreens/loadscreen_battleground_ularra_01.dds"
local ART_ALPHA = 0.30
local SCROLL_W = 8
local ARROW = 16

local all = {}

local function sv_menu()
    local data = BGMeter.zenimax.savedvars.get()
    data.menu = data.menu or {}
    return data.menu
end

Drawer.hexc = BGMeter.Format.hexc

function Drawer.row_h() return ROW_H end

function Drawer.new(spec)
    local self = setmetatable({}, Drawer)
    self.spec = spec
    self.key = spec.key
    self.rows = {}
    self.offset = 0
    self.drag = { on = false, y0 = 0, off0 = 0 }
    self.drag_name = spec.drag_name or ("BGMeter" .. spec.key .. "Drag")
    self.list_cache, self.cache_key = {}, nil
    self.last_count, self.last_vis = 0, 0
    all[#all + 1] = self
    return self
end

function Drawer:invalidate() self.cache_key = nil end

function Drawer:query()
    if not self.drawer or not self.drawer.edit then return "" end
    return self.drawer.edit:GetText() or ""
end

function Drawer:fetch()
    local key = self.spec.cache_key and self.spec.cache_key(self) or (self:query() .. "|" .. tostring(self.mode or ""))
    if key ~= self.cache_key then
        self.list_cache = self.spec.fetch(self) or {}
        self.cache_key = key
    end
    return self.list_cache
end

local function make_row(self, i)
    local r = {}
    r.container = BGMeter.zenimax.ui.create_control(nil, self.drawer.list, CT_CONTROL)
    local rh = self.spec.row_h or ROW_H
    r.container:SetHeight(rh)
    r.container:SetMouseEnabled(true)
    r.base, r.highlight = U.row_chrome(r.container)
    r.name = P.label(r.container, S.FONT.row, K.COLOR.text)
    r.name:SetAnchor(LEFT, r.container, LEFT, 12, 0)
    r.name:SetAnchor(RIGHT, r.container, RIGHT, -54, 0)
    r.name:SetHeight(rh)
    r.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    U.clamp_line(r.name)
    r.count = P.label(r.container, S.FONT.row, K.COLOR.text)
    r.count:SetAnchor(RIGHT, r.container, RIGHT, -6, 0)
    r.count:SetDimensions(46, rh)
    r.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    if self.spec.row_make then self.spec.row_make(self, r) end
    r.container:SetHandler("OnMouseEnter", function()
        r.highlight:SetHidden(false)
        local text = r.entry and self.spec.describe and self.spec.describe(self, r.entry)
        if text and U.card_show then U.card_show(r.container, LEFT, text) end
    end)
    r.container:SetHandler("OnMouseExit", function()
        r.highlight:SetHidden(true)
        if U.card_hide then U.card_hide() end
    end)
    r.container:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and r.entry and self.spec.on_click then self.spec.on_click(self, r.entry) end
    end)
    self.rows[i] = r
    return r
end

function Drawer:visible_rows()
    if not self.drawer then return 0 end
    return math.max(0, math.floor(self.drawer.list:GetHeight() / ((self.spec.row_h or ROW_H) + 2)))
end

function Drawer:max_offset()
    return math.max(0, self.last_count - self.last_vis)
end

function Drawer:layout_scrollbar()
    local sc = self.drawer.scroll
    local maxOff = self:max_offset()
    sc.up:SetHidden(self.offset <= 0)
    sc.down:SetHidden(maxOff - self.offset <= 0)
    if maxOff <= 0 then sc.track:SetHidden(true) return end
    local th = sc.track:GetHeight()
    if th <= 0 then sc.track:SetHidden(true) return end
    local thumbH = math.floor(th * self.last_vis / self.last_count + 0.5)
    if thumbH < 16 then thumbH = 16 end
    if thumbH > th then thumbH = th end
    local y = math.floor((th - thumbH) * self.offset / maxOff + 0.5)
    sc.thumb:SetHeight(thumbH)
    sc.thumb:ClearAnchors()
    sc.thumb:SetAnchor(TOPLEFT, sc.track, TOPLEFT, 0, y)
    sc.track:SetHidden(false)
end

function Drawer:apply_art()
    local art = self.drawer.art
    local w, h = self.drawer.root:GetWidth() - 4, self.drawer.root:GetHeight() - 4
    if w <= 0 or h <= 0 then return end
    local tw, th
    pcall(function() tw, th = art:GetTextureFileDimensions() end)
    if not tw or tw <= 0 or not th or th <= 0 then art:SetTextureCoords(0, 1, 0, 1) return end
    local ca, ta = w / h, tw / th
    if ta > ca then
        local uw = ca / ta
        local host_w, host_h = self.host:GetWidth() - 4, self.host:GetHeight() - 4
        local host_uw = (host_w > 0 and host_h > 0) and math.min(1, (host_w / host_h) / ta) or 0
        local u0 = (1 - host_uw) / 2 + host_uw
        if u0 + uw > 1 then u0 = (1 - uw) / 2 end
        art:SetTextureCoords(u0, u0 + uw, 0, 1)
    else
        local vh = ta / ca
        local v0 = (1 - vh) / 2
        art:SetTextureCoords(0, 1, v0, v0 + vh)
    end
end

function Drawer:refresh()
    if not self.drawer or self.drawer.root:IsHidden() then return end
    local list = self:fetch()
    local vis = self:visible_rows()
    Prof.enter("drawer:rows")
    local max_off = math.max(0, #list - vis)
    if self.offset > max_off then self.offset = max_off end
    if self.offset < 0 then self.offset = 0 end
    for i = 1, math.max(#self.rows, vis) do
        local r = self.rows[i] or make_row(self, i)
        local e = list[i + self.offset]
        if i <= vis and e then
            local fresh = r.entry ~= e or r._list ~= list
            r.entry = e
            r.face = e
            r._list = list
            r.container:SetHidden(false)
            r.container:ClearAnchors()
            local rh = self.spec.row_h or ROW_H
            r.container:SetAnchor(TOPLEFT, self.drawer.list, TOPLEFT, 0, (i - 1) * (rh + 2))
            r.container:SetAnchor(TOPRIGHT, self.drawer.list, TOPRIGHT, 0, (i - 1) * (rh + 2))
            if fresh or self.spec.row_always then self.spec.row_fill(self, r, e) end
        else
            r.entry, r.face = nil, nil
            r.container:SetHidden(true)
        end
    end
    self.last_count, self.last_vis = #list, vis
    Prof.exit("drawer:rows")
    Prof.enter("drawer:scrollbar")
    self:layout_scrollbar()
    Prof.exit("drawer:scrollbar")
    if self.spec.panel_refresh then
        Prof.enter("drawer:panel")
        self.spec.panel_refresh(self)
        Prof.exit("drawer:panel")
    end
    Prof.enter("drawer:foot")
    local foot
    if #list > vis then
        foot = string.format("%d-%d of %d  ·  scroll for more", self.offset + 1, math.min(#list, self.offset + vis), #list)
    else
        foot = self.spec.foot and self.spec.foot(self, list) or ""
    end
    set_text(self.drawer.foot, foot)
    Prof.exit("drawer:foot")
end

function Drawer:scroll(delta)
    self.offset = self.offset - delta
    self:refresh()
end

function Drawer:scroll_to(want)
    self.offset = want
    self:refresh()
end

function Drawer:on_track_click()
    if self.drag.on then return end
    local track = self.drawer.scroll.track
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    local th = track:GetHeight()
    if not my or th <= 0 then return end
    local rel = (my - track:GetTop()) / th
    self:scroll_to(math.floor(rel * (self:max_offset() + 1)))
end

function Drawer:drag_update()
    if not self.drag.on then return end
    local track, thumb = self.drawer.scroll.track, self.drawer.scroll.thumb
    local free = track:GetHeight() - thumb:GetHeight()
    local maxOff = self:max_offset()
    if free <= 0 or maxOff <= 0 then return end
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    if not my then return end
    self:scroll_to(self.drag.off0 + math.floor((my - self.drag.y0) * maxOff / free + 0.5))
end

function Drawer:on_thumb_down()
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    self.drag.on, self.drag.y0, self.drag.off0 = true, my or 0, self.offset
    local ac = K.COLOR.accent
    P.set_rect_color(self.drawer.scroll.thumbTex, { ac[1], ac[2], ac[3], 0.95 })
    BGMeter.zenimax.events.register_update(self.drag_name, 16, function() self:drag_update() end)
end

function Drawer:on_thumb_up()
    if not self.drag.on then return end
    self.drag.on = false
    BGMeter.zenimax.events.unregister_update(self.drag_name)
    local ac = K.COLOR.accent
    P.set_rect_color(self.drawer.scroll.thumbTex, { ac[1], ac[2], ac[3], 0.55 })
end

function Drawer:drag_active() return self.drag.on end

function Drawer:on_host_resized()
    if self.drawer then self:apply_art() end
end

function Drawer:is_open()
    return self.drawer ~= nil and not self.drawer.root:IsHidden()
end

function Drawer:apply_open(open, silent)
    if not self.drawer then return end
    if open then
        for _, other in ipairs(all) do
            if other ~= self and other:is_open() then other:apply_open(false, true) end
        end
    end
    self.drawer.root:SetHidden(not open)
    local tex = open and (self.spec.icon_down or self.spec.icon) or self.spec.icon
    self.tab.icon:SetNormalTexture(tex)
    self.tab.icon._tex_normal = tex
    sv_menu()[self.key .. "_open"] = open and true or false
    if open then
        self.offset = 0
        self:apply_art()
        self:invalidate()
        self:refresh()
    elseif self.drawer.edit and self.drawer.edit.LoseFocus then
        self.drawer.edit:LoseFocus()
    end
    if not silent then Sound.play(open and "menu" or "close") end
end

function Drawer:blur()
    if self.drawer and self.drawer.edit and self.drawer.edit.LoseFocus then self.drawer.edit:LoseFocus() end
end

function Drawer.blur_all()
    for _, d in ipairs(all) do d:blur() end
end

function Drawer:toggle()
    self:apply_open(not self:is_open())
end

function Drawer:set_query(text)
    if not self.drawer or not self.drawer.edit then return end
    self.drawer.edit:SetText(text or "")
    self.offset = 0
    self:invalidate()
    self:refresh()
end

function Drawer:set_mode(mode)
    self.mode = mode
    if self.drawer and self.drawer.switch then
        for _, b in ipairs(self.drawer.switch) do
            local on = (b.mode == mode)
            S.color(b.label, on and K.COLOR.accent or K.COLOR.text_dim)
            b.mark:SetHidden(not on)
        end
    end
    self.offset = 0
    self:invalidate()
    self:refresh()
end

function Drawer:on_menu_shown()
    if not self.drawer then return end
    self:apply_open(sv_menu()[self.key .. "_open"] == true, true)
end

function Drawer:init(pw)
    if self.drawer then return end
    self.host = pw
    local spec = self.spec
    local tab = { root = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL) }
    tab.root:SetDimensions(MEDAL, MEDAL)
    if spec.bottom then
        tab.root:SetAnchor(CENTER, pw, BOTTOMRIGHT, 0, -(MEDAL_Y0 - 16) - ((spec.index or 1) - 1) * MEDAL_STEP)
    else
        tab.root:SetAnchor(CENTER, pw, TOPRIGHT, 0, MEDAL_Y0 + ((spec.index or 1) - 1) * MEDAL_STEP)
    end
    tab.root:SetMouseEnabled(true)
    if tab.root.SetDrawLevel then tab.root:SetDrawLevel(10) end
    tab.icon = P.button(tab.root, spec.icon, spec.icon_down, spec.icon_over)
    tab.icon:SetDimensions(MEDAL, MEDAL)
    tab.icon:SetAnchor(CENTER, tab.root, CENTER, 0, 0)
    tab.icon._tex_normal = spec.icon
    tab.icon:SetHandler("OnClicked", function() self:toggle() end)
    tab.icon:SetHandler("OnMouseEnter", function()
        if U.card_show then U.card_show(tab.root, RIGHT, spec.title) end
    end)
    tab.icon:SetHandler("OnMouseExit", function()
        if U.card_hide then U.card_hide() end
    end)
    tab.root:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == (MOUSE_BUTTON_INDEX_LEFT or 1) then self:toggle() end
    end)
    self.tab = tab

    local drawer = { root = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL) }
    self.drawer = drawer
    local d = drawer.root
    d:SetWidth(DRAWER_W)
    d:SetAnchor(TOPLEFT, pw, TOPRIGHT, MEDAL / 2 - 6, 0)
    d:SetAnchor(BOTTOMLEFT, pw, BOTTOMRIGHT, MEDAL / 2 - 6, 0)
    d:SetMouseEnabled(true)
    d:SetHidden(true)
    d:SetHandler("OnMouseWheel", function(_, delta) self:scroll(delta) end)
    d:SetHandler("OnMouseUp", function() self:on_thumb_up() end)

    drawer.bg = P.rect(d, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.97 })
    drawer.bg:SetAnchorFill(d)
    drawer.art = P.icon(d, ART)
    drawer.art:SetAnchor(TOPLEFT, d, TOPLEFT, 2, 2)
    drawer.art:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -2, -2)
    drawer.art:SetColor(1, 1, 1, ART_ALPHA)
    local VP_TOP = (VERTEX_POINTS_TOPLEFT or 1) + (VERTEX_POINTS_TOPRIGHT or 2)
    local VP_BOTTOM = (VERTEX_POINTS_BOTTOMLEFT or 4) + (VERTEX_POINTS_BOTTOMRIGHT or 8)
    local bgc = K.COLOR.bg
    local vtop = P.rect(d, { bgc[1], bgc[2], bgc[3], 1 })
    vtop:SetAnchor(TOPLEFT, d, TOPLEFT, 2, 2)
    vtop:SetAnchor(TOPRIGHT, d, TOPRIGHT, -2, 2)
    vtop:SetHeight(90)
    vtop:SetVertexColors(VP_TOP, bgc[1], bgc[2], bgc[3], 0.85)
    vtop:SetVertexColors(VP_BOTTOM, bgc[1], bgc[2], bgc[3], 0)
    local vbot = P.rect(d, { bgc[1], bgc[2], bgc[3], 1 })
    vbot:SetAnchor(BOTTOMLEFT, d, BOTTOMLEFT, 2, -2)
    vbot:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -2, -2)
    vbot:SetHeight(120)
    vbot:SetVertexColors(VP_TOP, bgc[1], bgc[2], bgc[3], 0)
    vbot:SetVertexColors(VP_BOTTOM, bgc[1], bgc[2], bgc[3], 0.85)
    drawer.vignette = { vtop, vbot }
    drawer.frame = P.frame(d)
    drawer.frame:SetAnchorFill(d)
    drawer.strip = P.rect(d, K.COLOR.accent)
    drawer.strip:SetAnchor(TOPLEFT, d, TOPLEFT, 6, 6)
    drawer.strip:SetAnchor(TOPRIGHT, d, TOPRIGHT, -6, 6)
    drawer.strip:SetHeight(3)

    drawer.icon = P.icon(d, spec.icon)
    drawer.icon:SetDimensions(28, 28)
    drawer.icon:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, 10)
    drawer.title = P.label(d, S.FONT.title, K.COLOR.text)
    drawer.title:SetAnchor(LEFT, drawer.icon, RIGHT, 8, 0)
    set_text(drawer.title, spec.title)

    local bar_h = 0
    if spec.search then
        drawer.search = BGMeter.zenimax.ui.create_from_virtual(nil, d, "ZO_EditBackdrop")
        drawer.search:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, HEAD_H)
        drawer.search:SetAnchor(TOPRIGHT, d, TOPRIGHT, -PAD, HEAD_H)
        drawer.search:SetHeight(BAR_H)
        drawer.edit = BGMeter.zenimax.ui.create_from_virtual(nil, drawer.search, "ZO_DefaultEditForBackdrop")
        if drawer.edit.SetDefaultText then drawer.edit:SetDefaultText(spec.search_hint or "search") end
        if drawer.edit.SetMaxInputChars then drawer.edit:SetMaxInputChars(40) end
        drawer.edit:SetHandler("OnTextChanged", function()
            self.offset = 0
            self:invalidate()
            self:refresh()
        end)
        drawer.edit:SetHandler("OnEnter", function() drawer.edit:LoseFocus() end)
        drawer.edit:SetHandler("OnEscape", function() drawer.edit:LoseFocus() end)
        bar_h = BAR_H
    elseif spec.modes then
        drawer.switch = {}
        local n = #spec.modes
        local slot = (DRAWER_W - 2 * PAD) / n
        for i, m in ipairs(spec.modes) do
            local b = { mode = m.key }
            b.hit = BGMeter.zenimax.ui.create_control(nil, d, CT_CONTROL)
            b.hit:SetAnchor(TOPLEFT, d, TOPLEFT, PAD + math.floor((i - 1) * slot), HEAD_H)
            b.hit:SetDimensions(math.floor(slot), BAR_H - 6)
            b.hit:SetMouseEnabled(true)
            b.label = P.label(b.hit, S.FONT.small, K.COLOR.text_dim)
            b.label:SetAnchorFill(b.hit)
            b.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            set_text(b.label, m.label)
            b.mark = P.rect(b.hit, K.COLOR.accent)
            b.mark:SetAnchor(BOTTOMLEFT, b.hit, BOTTOMLEFT, 6, 0)
            b.mark:SetAnchor(BOTTOMRIGHT, b.hit, BOTTOMRIGHT, -6, 0)
            b.mark:SetHeight(2)
            b.mark:SetHidden(true)
            b.hit:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then self:set_mode(m.key) end end)
            drawer.switch[i] = b
        end
        bar_h = BAR_H - 4
    end
    local list_top = HEAD_H + bar_h + 8
    if spec.list_heading then
        drawer.heading = P.label(d, S.FONT.small, K.COLOR.gold)
        drawer.heading:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, list_top)
        drawer.heading:SetAnchor(TOPRIGHT, d, TOPRIGHT, -PAD, list_top)
        drawer.heading:SetHeight(14)
        set_text(drawer.heading, spec.list_heading)
        local rule = P.rect(d, { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.22 })
        rule:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, list_top + 17)
        rule:SetAnchor(TOPRIGHT, d, TOPRIGHT, -PAD, list_top + 17)
        rule:SetHeight(1)
        list_top = list_top + 24
    end
    local panel_h = spec.panel_h or 0
    local foot_h = FOOT_H + (spec.credit and 12 or 0) + panel_h

    if panel_h > 0 then
        drawer.panel = BGMeter.zenimax.ui.create_control(nil, d, CT_CONTROL)
        drawer.panel:SetAnchor(BOTTOMLEFT, d, BOTTOMLEFT, PAD, -(foot_h - panel_h))
        drawer.panel:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, -(foot_h - panel_h))
        drawer.panel:SetHeight(panel_h)
        drawer.panel:SetMouseEnabled(true)
        if spec.panel_build then spec.panel_build(self, drawer.panel, DRAWER_W - 2 * PAD) end
    end

    drawer.list = BGMeter.zenimax.ui.create_control(nil, d, CT_CONTROL)
    drawer.list:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, list_top)
    drawer.list:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -(PAD + SCROLL_W + 6), -foot_h)
    drawer.list:SetMouseEnabled(false)

    drawer.scroll = {}
    local ac = K.COLOR.accent
    local up = P.button(d, "EsoUI/Art/Buttons/scrollbox_upArrow_up.dds", "EsoUI/Art/Buttons/scrollbox_upArrow_down.dds", "EsoUI/Art/Buttons/scrollbox_upArrow_over.dds")
    up:SetDimensions(ARROW, ARROW)
    up:SetAnchor(TOPRIGHT, d, TOPRIGHT, -(PAD - 4), list_top - 2)
    up:SetHandler("OnClicked", function() self:scroll(1) end)
    up:SetHidden(true)
    drawer.scroll.up = up
    local down = P.button(d, "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds", "EsoUI/Art/Buttons/scrollbox_downArrow_down.dds", "EsoUI/Art/Buttons/scrollbox_downArrow_over.dds")
    down:SetDimensions(ARROW, ARROW)
    down:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -(PAD - 4), -(foot_h - 2))
    down:SetHandler("OnClicked", function() self:scroll(-1) end)
    down:SetHidden(true)
    drawer.scroll.down = down
    local track = BGMeter.zenimax.ui.create_control(nil, d, CT_CONTROL)
    track:SetAnchor(TOPRIGHT, d, TOPRIGHT, -PAD, list_top + ARROW + 4)
    track:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, -(foot_h + ARROW + 2))
    track:SetWidth(SCROLL_W)
    track:SetMouseEnabled(true)
    track:SetHidden(true)
    track:SetHandler("OnMouseUp", function(_, _, upInside)
        if self.drag.on then self:on_thumb_up() return end
        if upInside then self:on_track_click() end
    end)
    drawer.scroll.track = track
    drawer.scroll.trackBg = P.rect(track, { ac[1], ac[2], ac[3], 0.12 })
    drawer.scroll.trackBg:SetAnchorFill(track)
    local thumb = BGMeter.zenimax.ui.create_control(nil, track, CT_CONTROL)
    thumb:SetAnchor(TOPLEFT, track, TOPLEFT, 0, 0)
    thumb:SetWidth(SCROLL_W)
    thumb:SetMouseEnabled(true)
    local thumbTex = P.rect(thumb, { ac[1], ac[2], ac[3], 0.55 })
    thumbTex:SetAnchorFill(thumb)
    thumb:SetHandler("OnMouseDown", function() self:on_thumb_down() end)
    thumb:SetHandler("OnMouseUp", function() self:on_thumb_up() end)
    thumb:SetHandler("OnMouseEnter", function() if not self.drag.on then P.set_rect_color(thumbTex, { ac[1], ac[2], ac[3], 0.85 }) end end)
    thumb:SetHandler("OnMouseExit", function() if not self.drag.on then P.set_rect_color(thumbTex, { ac[1], ac[2], ac[3], 0.55 }) end end)
    drawer.scroll.thumb = thumb
    drawer.scroll.thumbTex = thumbTex

    local foot_y = -8
    if spec.credit then
        drawer.credit = P.label(d, S.FONT.small, K.COLOR.text_dim)
        drawer.credit:SetAnchor(BOTTOMLEFT, d, BOTTOMLEFT, PAD, -6)
        drawer.credit:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, -6)
        drawer.credit:SetHeight(12)
        drawer.credit:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        drawer.credit:SetAlpha(0.7)
        U.clamp_line(drawer.credit)
        set_text(drawer.credit, spec.credit)
        foot_y = -20
    end
    drawer.foot = P.label(d, S.FONT.small, K.COLOR.text_dim)
    drawer.foot:SetAnchor(BOTTOMLEFT, d, BOTTOMLEFT, PAD, foot_y)
    drawer.foot:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, foot_y)
    drawer.foot:SetHeight(14)
    drawer.foot:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    U.clamp_line(drawer.foot)

    if spec.modes then self:set_mode(spec.modes[1].key) end
end

function Drawer:controls() return self.drawer, self.tab, self.rows end

function Drawer.all() return all end

BGMeter.UI.Drawer = Drawer
