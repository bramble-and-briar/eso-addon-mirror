BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Drawer = BGMeter.UI.Drawer
local TX = U.TX
local set_text = U.set_text
local hexc = F.hexc

local AUTHOR = "Federico Vergelli"
local CREDITS = { "unit220", "TattoozNbooZ", "ruskiii" }
local BAR_H = 7
local LINE_H = 30
local CAP_ROW = 16
local COL_W = 46

local function heading(parent, text, y, w)
    local h = P.label(parent, S.FONT.small, K.COLOR.gold)
    h:SetText(text)
    h:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
    h:SetDimensions(w, 14)
    local rule = P.rect(parent, { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.22 })
    rule:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y + 17)
    rule:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, y + 17)
    rule:SetHeight(1)
    return h
end

local function cell(parent, x, y, w, color, align)
    local c = P.label(parent, S.FONT.small, color)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w, CAP_ROW)
    c:SetHorizontalAlignment(align or TEXT_ALIGN_RIGHT)
    U.clamp_line(c)
    return c
end

local function cap_row(parent, y, w, label)
    local r = {}
    r.name = cell(parent, 4, y, w - 4 - 3 * COL_W, K.COLOR.text, TEXT_ALIGN_LEFT)
    set_text(r.name, label)
    r.kept = cell(parent, w - 3 * COL_W, y, COL_W, K.COLOR.gold)
    r.cap = cell(parent, w - 2 * COL_W, y, COL_W, K.COLOR.gold)
    r.saved = cell(parent, w - COL_W, y, COL_W, K.COLOR.gold)
    return r
end

local function storage_line(parent, y, w)
    local line = {}
    line.name = P.label(parent, S.FONT.small, K.COLOR.text)
    line.name:SetAnchor(TOPLEFT, parent, TOPLEFT, 4, y)
    line.name:SetDimensions(70, 14)
    line.value = P.label(parent, S.FONT.small, K.COLOR.gold)
    line.value:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -4, y)
    line.value:SetDimensions(w - 78, 14)
    line.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    U.clamp_line(line.value)
    line.bar = U.inset_bar(parent)
    line.bar.container:SetAnchor(TOPLEFT, parent, TOPLEFT, 4, y + 17)
    line.bar.container:SetDimensions(w - 8, BAR_H + 2)
    line.barW = w - 8
    return line
end

local function fill_line(line, label, used, cap, color)
    set_text(line.name, label)
    if cap and cap > 0 then
        set_text(line.value, string.format("%s / %s", F.bytes(used), F.bytes(cap)))
        U.inset_bar_set(line.bar, used / cap, color, line.barW)
    else
        set_text(line.value, F.bytes(used))
        U.inset_bar_set(line.bar, 0, color, line.barW)
    end
end

local CAP_H = 22 + 14 + 2 * CAP_ROW + 10
local STORE_H = 22 + 4 * LINE_H
local CACHE_CAP = 4 * 1024 * 1024

local D = Drawer.new({
    key = "about",
    index = 1,
    bottom = true,
    title = "About",
    icon = TX.about.n,
    icon_down = TX.about.p,
    icon_over = TX.about.o,
    drag_name = "BGMeterAboutDrag",
    row_h = 40,
    list_heading = "ADDON",
    panel_h = CAP_H + STORE_H,
    cache_key = function(self)
        local Storage = BGMeter.Storage
        local r = Storage and Storage.report()
        return tostring(BGMeter.History.count()) .. "|" .. tostring(BGMeter.History.pinned_count()) .. "|"
            .. tostring(r and r.faces.count or 0) .. "|" .. tostring(BGMeter.Prefs.get("max_history"))
    end,
    fetch = function(self)
        return {
            { k = "VERSION", v = K.VERSION, tip = "BGmeter " .. K.VERSION },
            { k = "AUTHOR", v = AUTHOR, tip = "@vergelli" },
            { k = "CREDITS", v = "", tip = table.concat(CREDITS, "\n") },
        }
    end,
    row_make = function(self, r)
        r.base:SetHidden(true)
        r.highlight:ClearAnchors()
        r.highlight:SetAnchor(TOPLEFT, r.container, TOPLEFT, 0, 2)
        r.highlight:SetAnchor(BOTTOMRIGHT, r.container, BOTTOMRIGHT, 0, -2)
        r.name:ClearAnchors()
        r.name:SetAnchor(TOPLEFT, r.container, TOPLEFT, 4, 5)
        r.name:SetAnchor(TOPRIGHT, r.container, TOPRIGHT, -4, 5)
        r.name:SetHeight(13)
        if r.name.SetFont then r.name:SetFont(S.FONT.small) end
        S.color(r.name, K.COLOR.text)
        r.count:ClearAnchors()
        r.count:SetAnchor(BOTTOMLEFT, r.container, BOTTOMLEFT, 4, -5)
        r.count:SetAnchor(BOTTOMRIGHT, r.container, BOTTOMRIGHT, -4, -5)
        r.count:SetHeight(17)
        r.count:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        U.clamp_line(r.count)
        r.rule = P.rect(r.container, { 1, 1, 1, 0.08 })
        r.rule:SetAnchor(BOTTOMLEFT, r.container, BOTTOMLEFT, 0, 0)
        r.rule:SetAnchor(BOTTOMRIGHT, r.container, BOTTOMRIGHT, 0, 0)
        r.rule:SetHeight(1)
    end,
    row_fill = function(self, r, e)
        set_text(r.name, e.k)
        r.name:ClearAnchors()
        if e.v == "" then
            r.name:SetAnchor(LEFT, r.container, LEFT, 4, 0)
            r.name:SetAnchor(RIGHT, r.container, RIGHT, -4, 0)
            set_text(r.count, "")
        else
            r.name:SetAnchor(TOPLEFT, r.container, TOPLEFT, 4, 5)
            r.name:SetAnchor(TOPRIGHT, r.container, TOPRIGHT, -4, 5)
            set_text(r.count, string.format("|c%s%s|r", hexc(K.COLOR.gold), e.v))
        end
    end,
    describe = function(self, e) return e.tip end,
    panel_build = function(self, panel, w)
        local p = {}
        p.capHeading = heading(panel, "CAPACITY", 0, w)
        local hy = 22
        p.hdr = {
            kept = cell(panel, w - 3 * COL_W, hy, COL_W, K.COLOR.text_dim),
            cap = cell(panel, w - 2 * COL_W, hy, COL_W, K.COLOR.text_dim),
            saved = cell(panel, w - COL_W, hy, COL_W, K.COLOR.text_dim),
        }
        set_text(p.hdr.kept, "KEPT"); set_text(p.hdr.cap, "CAP"); set_text(p.hdr.saved, "SAVED")
        p.matchesRow = cap_row(panel, hy + 14, w, "matches")
        p.facesRow = cap_row(panel, hy + 14 + CAP_ROW, w, "faces")
        p.storeHeading = heading(panel, "STORAGE", CAP_H, w)
        p.matches = storage_line(panel, CAP_H + 22, w)
        p.faces = storage_line(panel, CAP_H + 22 + LINE_H, w)
        p.map = storage_line(panel, CAP_H + 22 + 2 * LINE_H, w)
        p.cache = storage_line(panel, CAP_H + 22 + 3 * LINE_H, w)
        panel:SetHandler("OnMouseEnter", function()
            if p.tip and U.card_show then U.card_show(panel, LEFT, p.tip) end
        end)
        panel:SetHandler("OnMouseExit", function()
            if U.card_hide then U.card_hide() end
        end)
        self.storage = p
    end,
    panel_refresh = function(self)
        local p = self.storage
        local r = BGMeter.Storage and BGMeter.Storage.report()
        if not (p and r) then return end
        local H, Faces = BGMeter.History, BGMeter.Faces
        local pinned = H.pinned_count()
        set_text(p.matchesRow.kept, tostring(H.count() - pinned))
        set_text(p.matchesRow.cap, tostring(BGMeter.Prefs.get("max_history") or 50))
        set_text(p.matchesRow.saved, string.format("%d / %d", pinned, H.PIN_CAP))
        set_text(p.facesRow.kept, tostring(Faces.count()))
        set_text(p.facesRow.cap, tostring(Faces.CAP or 1500))
        set_text(p.facesRow.saved, "")
        fill_line(p.matches, "matches", r.matches.used, r.matches.cap, K.COLOR.gold)
        fill_line(p.faces, "faces", r.faces.used, r.faces.cap, K.COLOR.veterancy)
        fill_line(p.map, "map", r.map.used, r.map.cap, K.COLOR.accent)
        local gc = BGMeter.Match.geo_cache_report()
        fill_line(p.cache, "cache", gc.held and gc.bytes or 0, CACHE_CAP, K.COLOR.you)
        p.tip = string.format(
            "Kept is what the Registry holds today, cap is Settings, Matches kept;\n"
            .. "the ten most recent keep their charts, saved matches sit outside the cap (up to %d).\n"
            .. "Bytes are what the addon keeps in your saved variables; available is not a game limit,\n"
            .. "it is the store at the addon's own caps.  Map = positions and pins (%d matches).  Whole store %s.\n"
            .. "Cache = the open match decoded in memory for the map, %s; it is replaced when another match opens.",
            H.PIN_CAP, r.map.count, F.bytes(r.total), gc.held and F.bytes(gc.bytes) or "nothing held")
    end,
    foot = function(self, list)
        local r = BGMeter.Storage and BGMeter.Storage.report()
        if not r then return "" end
        return string.format("%s in saved variables", F.bytes(r.total))
    end,
})

local M = {}
function M.invalidate() D:invalidate() end
function M.refresh() D:refresh() end
function M.is_open() return D:is_open() end
function M.toggle() D:toggle() end
function M.on_host_resized() D:on_host_resized() end
function M.on_menu_shown() D:on_menu_shown() end
function M.init(pw) D:init(pw) end
function M.controls() return D:controls() end
function M.storage() return D.storage end
M.drawer = D

BGMeter.UI.about = M
