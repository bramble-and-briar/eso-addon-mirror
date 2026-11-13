-----------------------------------------------------
-- AnimatedActionBar+ Spezial-Titel
-- titel, symbole und chatfarbe aus AnimatedActionBarPlus_Titles.lua,
-- dazu /haze (nur @haze068)
-----------------------------------------------------
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local InstallTitleHooks, TitleCommand

local TITLE_MEDIA = "AnimatedActionBarPlus/media/"
local TITLE_OWNER = "@haze068"

local TITLE_RANKS = {
    creator = { stops = { "FF3B3B", "FF9A2E", "FFE08A" }, chat = { "FF7A5A", "FFD08A" } },
    special = { stops = { "9B7BFF", "6FD0FF" },           chat = { "C2B2FF", "9FE2FF" } },
}

local function TitleKey(name)
    if type(name) ~= "string" then return nil end
    -- "target" = wer gerade unterm fadenkreuz ist, spart tippfehler
    if name:lower() == "target" and GetUnitDisplayName then
        name = GetUnitDisplayName("reticleover")
        if type(name) ~= "string" or name == "" then return nil end
    end
    -- zo_strlower kann auch Ü/Ä, string.lower nur ascii
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    name = (zo_strlower or string.lower)(name)
    if name == "" then return nil end
    if name:sub(1, 1) ~= "@" then name = "@" .. name end
    return name
end

local function IsTitleOwner()
    local me = GetDisplayName and GetDisplayName()
    return TitleKey(me) == TITLE_OWNER
end

local function TitleTable()
    AnimatedActionBarPlus_Titles = AnimatedActionBarPlus_Titles or {}
    return AnimatedActionBarPlus_Titles
end

-- AABPlus hat vorrang: spieler aus der eigenen liste werden bei FancyTitles
-- rausgenommen, sonst färben beide addons denselben titel und chat
local function MuteFancyTitles()
    local own = AnimatedActionBarPlus_Titles
    if type(own) ~= "table" then return end
    local function strip(list)
        if type(list) ~= "table" then return end
        for name in pairs(list) do
            local k = TitleKey(name)
            if k and own[k] then list[name] = nil end
        end
    end
    strip(FancyTitles_Data)
    strip(FancyTitles_ChatData)
end

local function ResolveEntry(key)
    local e = TitleTable()[key]
    if not e or type(e.title) ~= "string" or e.title == "" then return nil end
    return e
end

-- caches: hooks laufen bei jedem unitframe-update und jeder chatzeile.
-- name -> key, key -> eintrag, key -> fertiger titel / chat-symbol.
-- geleert bei /haze-änderungen und beim zonenwechsel
local keyCache, entryCache, titleCache, badgeCache = {}, {}, {}, {}

local function ClearTitleCache()
    keyCache, entryCache, titleCache, badgeCache = {}, {}, {}, {}
end

local function CachedKey(displayName)
    local k = keyCache[displayName]
    if k == nil then
        k = TitleKey(displayName) or false
        keyCache[displayName] = k
    end
    return k or nil
end

local function CachedEntry(key)
    local e = entryCache[key]
    if e == nil then
        e = ResolveEntry(key) or false
        entryCache[key] = e
    end
    return e or nil
end

local function TitleEntry(displayName)
    if type(displayName) ~= "string" or displayName == "" then return nil end
    local key = CachedKey(displayName)
    return key and CachedEntry(key), key
end

-- utf-8 über die bytes zerlegen. muster mit byte-bereichen schluckt ingame
-- umlaute (ü, ß, ...), deshalb hier zu fuß
local function U8Chars(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        local b = text:byte(i)
        local len = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
        out[#out + 1] = text:sub(i, i + len - 1)
        i = i + len
    end
    return out
end

local function Blend(text, stops)
    local chars = U8Chars(text)
    local n = #chars
    if n == 0 or #stops == 0 then return text end
    local parts = {}
    for i, ch in ipairs(chars) do
        if ch == " " then
            parts[#parts + 1] = " "
        else
            local t = (n == 1) and 0 or (i - 1) / (n - 1)
            local seg = t * (#stops - 1)
            local k = math.min(#stops - 1, math.floor(seg))
            local f = seg - k
            local a, b = stops[k + 1], stops[math.min(#stops, k + 2)]
            local function c(o)
                local x, y = tonumber(a:sub(o, o + 1), 16), tonumber(b:sub(o, o + 1), 16)
                return math.floor(x + (y - x) * f + 0.5)
            end
            parts[#parts + 1] = string.format("|c%02X%02X%02X%s|r", c(1), c(3), c(5), ch)
        end
    end
    return table.concat(parts)
end

local function RankOf(e) return TITLE_RANKS[e.rank] or TITLE_RANKS.special end

local function HexOk(h)
    return type(h) == "string" and #h == 6 and h:match("^%x+$") ~= nil
end

-- titleColor = "FF0000", "FF0000,FFD700" oder { "FF0000", "FFD700" }.
-- eine farbe = einfarbig, mehrere = verlauf. sonst farben vom rang
local function TitleStops(e)
    local v = e.titleColor
    local list = {}
    if type(v) == "string" then
        for h in v:gmatch("[^,%s]+") do list[#list + 1] = h end
    elseif type(v) == "table" then
        for _, h in ipairs(v) do list[#list + 1] = h end
    end
    local out = {}
    for _, h in ipairs(list) do
        h = tostring(h):gsub("#", ""):upper()
        if HexOk(h) then out[#out + 1] = h end
    end
    if #out == 0 then return RankOf(e).stops end
    return out
end

-- symbole fest über felder, nie aus dem titeltext:
--   icon      = 1-10 vor dem titel, 0 = kein symbol, leer = symbol vom rang
--   iconAfter = 1-10 hinter dem titel, optional (creator: sonst wie icon)
--   color     = "RRGGBB" für die symbole, sonst erste rangfarbe
--   symbol    = textzeichen statt textur, z.b. "★"
local TITLE_ICON_COUNT = 10

local TITLE_SYMBOL_DIR = "AnimatedActionBarPlus/symbols/"

-- eigene symbole ab 11 aus AnimatedActionBarPlus_Symbols (titel-datei).
-- "datei.dds" = eigene farben, { file = "datei.dds", tint = true } = einfärben
local function CustomSymbol(n)
    local list = AnimatedActionBarPlus_Symbols
    local v = type(list) == "table" and list[n]
    if type(v) == "string" then v = { file = v } end
    if type(v) ~= "table" or type(v.file) ~= "string" or v.file == "" then return nil end
    local file = v.file
    if not file:find("/", 1, true) then file = TITLE_SYMBOL_DIR .. file end
    if not file:lower():find("%.dds$") then file = file .. ".dds" end
    return file, v.tint == true
end

local function IconNumber(v)
    local n = tonumber(v)
    if not n then return nil end
    n = math.floor(n)
    if n >= 0 and n <= TITLE_ICON_COUNT then return n end
    if CustomSymbol(n) then return n end
    return nil
end

local function CustomSymbolNumbers()
    local list = {}
    if type(AnimatedActionBarPlus_Symbols) == "table" then
        for n in pairs(AnimatedActionBarPlus_Symbols) do
            if type(n) == "number" and n > TITLE_ICON_COUNT and CustomSymbol(n) then list[#list + 1] = n end
        end
    end
    table.sort(list)
    return list
end

local function TitleColorText(e)
    local v = e.titleColor
    if type(v) == "table" then v = table.concat(v, ",") end
    if type(v) ~= "string" or v == "" then return "rank" end
    return v
end

local function IconColor(e, r)
    local c = type(e.color) == "string" and e.color:gsub("#", ""):upper() or nil
    if c and #c == 6 and c:match("^%x+$") then return c end
    return TitleStops(e)[1]
end

-- n = 1-10 textur, 0 = nichts, nil = symbol vom rang
local function SymbolMarkup(e, n, size)
    size = size or 18
    local r = RankOf(e)
    if n == 0 then return "" end
    if not n then
        -- ohne icon kein symbol, außer es ist ein textzeichen gesetzt
        if type(e.symbol) == "string" and e.symbol ~= "" then
            return "|c" .. IconColor(e, r) .. e.symbol .. "|r"
        end
        return ""
    end
    if n and n > TITLE_ICON_COUNT then
        local path, tint = CustomSymbol(n)
        if tint then
            return "|c" .. IconColor(e, r) .. string.format("|t%d:%d:%s:inheritcolor|t", size, size, path) .. "|r"
        end
        return string.format("|t%d:%d:%s|t", size, size, path)
    end
    local file = "T_Icon" .. n
    return "|c" .. IconColor(e, r) .. string.format("|t%d:%d:%s%s.dds:inheritcolor|t", size, size, TITLE_MEDIA, file) .. "|r"
end

local function TitleIcon(e, size)
    return SymbolMarkup(e, IconNumber(e.icon), size)
end

local function FormatTitle(e)
    local before = TitleIcon(e)
    local afterN = IconNumber(e.iconAfter)
    local after = afterN and SymbolMarkup(e, afterN) or ""
    local t = Blend(e.title, TitleStops(e))
    if before ~= "" then t = before .. " " .. t end
    if after ~= "" then t = t .. " " .. after end
    return t
end

-- verlauf über den text, links (|H...|h...|h) bleiben unangetastet
local function BlendKeepLinks(text, stops)
    local parts, pos = {}, 1
    local plain = {}
    while pos <= #text do
        local a = text:find("|H", pos, true)
        local b1 = a and text:find("|h", a + 2, true)
        local b2 = b1 and text:find("|h", b1 + 2, true)
        if not b2 then
            plain[#plain + 1] = { i = #parts + 1, s = text:sub(pos) }
            parts[#parts + 1] = false
            break
        end
        if a > pos then
            plain[#plain + 1] = { i = #parts + 1, s = text:sub(pos, a - 1) }
            parts[#parts + 1] = false
        end
        parts[#parts + 1] = text:sub(a, b2 + 1)
        pos = b2 + 2
    end
    -- zeichen über alle textstücke zählen, damit der verlauf durchläuft
    local total = 0
    for _, p in ipairs(plain) do
        p.chars = U8Chars(p.s)
        for _, ch in ipairs(p.chars) do if ch ~= " " then total = total + 1 end end
    end
    local idx = 0
    for _, p in ipairs(plain) do
        local out = {}
        for _, ch in ipairs(p.chars) do
            if ch == " " then
                out[#out + 1] = " "
            else
                local t = (total <= 1) and 0 or idx / (total - 1)
                local seg = t * (#stops - 1)
                local k = math.min(#stops - 1, math.floor(seg))
                local f = seg - k
                local c1, c2 = stops[k + 1], stops[math.min(#stops, k + 2)]
                local function c(o)
                    local x, y = tonumber(c1:sub(o, o + 1), 16), tonumber(c2:sub(o, o + 1), 16)
                    return math.floor(x + (y - x) * f + 0.5)
                end
                out[#out + 1] = string.format("|c%02X%02X%02X%s|r", c(1), c(3), c(5), ch)
                idx = idx + 1
            end
        end
        parts[p.i] = table.concat(out)
    end
    return table.concat(parts)
end

local WHISPER = { [CHAT_CHANNEL_WHISPER or -1] = true, [CHAT_CHANNEL_WHISPER_SENT or -2] = true }

-- symbol + farbe überall, im whisper nur die farbe
local function FormatChat(e, text, channelType, key)
    local r = RankOf(e)
    local badge = ""
    if not WHISPER[channelType] then
        badge = key and badgeCache[key]
        if not badge then
            badge = TitleIcon(e, 16)
            if badge ~= "" then badge = badge .. " " end
            if key then badgeCache[key] = badge end
        end
    end
    -- eigene farbcodes im text nicht überschreiben
    if text:find("|c", 1, true) then return badge .. text end
    if not text:find("|H", 1, true) then return badge .. Blend(text, r.chat) end
    return badge .. BlendKeepLinks(text, r.chat)
end

-- "4" = davor, "4/2" = 4 davor und 2 dahinter, "0" = ohne symbol
local function ParseSymbols(spec)
    if type(spec) ~= "string" then return nil end
    local a, b = spec:match("^(%d+)/(%d+)$")
    if a then
        a, b = IconNumber(a), IconNumber(b)
        if a and b then return a, (b > 0) and b or nil end
        return nil
    end
    local n = spec:match("^(%d+)$") and IconNumber(spec)
    return n, nil
end

-- spieltitel und eigener titel zusammen: "Godslayer - ♥ Supreme Leader"
local GameTitle = function() return "" end

local function JoinTitles(game, custom)
    if type(game) ~= "string" or game == "" then return custom end
    -- gleicher trenner wie ESO zwischen name und titel
    return game .. " - " .. custom
end

function InstallTitleHooks()
    MuteFancyTitles()
    EM:RegisterForEvent("AABPlusTitles", EVENT_PLAYER_ACTIVATED, function()
        MuteFancyTitles()
        ClearTitleCache()
    end)
    if type(GetUnitTitle) == "function" and GetUnitDisplayName then
        local original = GetUnitTitle
        GameTitle = function(unitTag) return original(unitTag) or "" end
        GetUnitTitle = function(unitTag, ...)
            local game = original(unitTag, ...)
            if not unitTag then return game end
            local e, key = TitleEntry(GetUnitDisplayName(unitTag))
            if not e then return game end
            local t = titleCache[key]
            if not t then
                t = FormatTitle(e)
                titleCache[key] = t
            end
            return JoinTitles(game, t)
        end
    end
    if CHAT_ROUTER and type(CHAT_ROUTER.FormatAndAddChatMessage) == "function" then
        local original = CHAT_ROUTER.FormatAndAddChatMessage
        CHAT_ROUTER.FormatAndAddChatMessage = function(self, eventCode, channelType, fromName, text, isCustomerService, fromDisplayName, ...)
            if eventCode == EVENT_CHAT_MESSAGE_CHANNEL and type(text) == "string" then
                local e, key = TitleEntry(fromDisplayName)
                if e then text = FormatChat(e, text, channelType, key) end
            end
            return original(self, eventCode, channelType, fromName, text, isCustomerService, fromDisplayName, ...)
        end
    end
end

-- /haze vorschau

local titlePreview

local function PvLabel(parent, font, text)
    local l = WM:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font)
    l:SetColor(0.93, 0.93, 0.96, 1)
    l:SetText(text or "")
    l:SetDrawLevel(6)
    return l
end

-- echte werte, wenn die person gerade da ist (selbst, ziel, gruppe)
local function FindUnit(key)
    if not GetUnitDisplayName then return nil end
    local tags = { "player", "reticleover" }
    for i = 1, 12 do tags[#tags + 1] = "group" .. i end
    for _, tag in ipairs(tags) do
        if (not DoesUnitExist or DoesUnitExist(tag)) and TitleKey(GetUnitDisplayName(tag)) == key then return tag end
    end
    return nil
end

local function ShortNumber(v)
    if v >= 1000000 then return string.format("%.1fm", v / 1000000) end
    if v >= 1000 then return string.format("%.1fk", v / 1000) end
    return tostring(math.floor(v))
end

local function UnitInfo(key, fallbackName)
    local info = { display = key, name = fallbackName or "Character", cp = 1800, hp = 18300, hpMax = 18300 }
    local tag = FindUnit(key)
    if tag then
        info.display = GetUnitDisplayName(tag) or key
        info.name = (GetUnitName and GetUnitName(tag)) or info.name
        info.game = GameTitle(tag)
        if GetUnitChampionPoints then info.cp = GetUnitChampionPoints(tag) or info.cp end
        local mech = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH
        if mech and GetUnitPower then
            local cur, max = GetUnitPower(tag, mech)
            if type(cur) == "number" and type(max) == "number" and max > 0 then info.hp, info.hpMax = cur, max end
        end
    end
    return info
end

-- vorschau im nebula-look vom studio
local PV_W, PV_H, PV_PAD = 640, 610, 22
local PV_INNER = PV_W - 2 * PV_PAD
local PV_COL = {
    accent  = { 0.616, 0.549, 1.0 },  -- 9d8cff
    accent2 = { 0.294, 0.373, 0.769 }, -- 4b5fc4
    dim     = { 0.502, 0.533, 0.706 }, -- 8088b4
    value   = { 0.749, 0.816, 1.0 },   -- bfd0ff
}
local PV_LAYERS = {
    { file = "N_Nebula.dds", tile = 900, vx = -4, vy = -1.5 },
    { file = "N_Wisps.dds",  tile = 700, vx = 7, vy = 2.5, add = true, alpha = 0.8 },
    { file = "N_Stars.dds",  tile = 512, vx = -1.2, add = true },
    { file = "N_Stars.dds",  tile = 389, vx = -2.6, vy = -0.6, ox = 0.37, oy = 0.61, add = true, alpha = 0.7 },
    { file = "UI_Vignette.dds", alpha = 0.9 },
}
local PV_UPDATE = "AABPlusTitlePreviewBg"

local function PvTex(parent, file, level)
    local t = WM:CreateControl(nil, parent, CT_TEXTURE)
    if file then t:SetTexture(TITLE_MEDIA .. file) end
    t:SetDrawLevel(level or 2)
    return t
end

local function PvPanel(parent, w, h)
    local b = WM:CreateControl(nil, parent, CT_BACKDROP)
    b:SetDimensions(w, h)
    b:SetEdgeTexture(TITLE_MEDIA .. "N_Glass.dds", 128, 16, 16, 0)
    b:SetInsets(3, 3, -3, -3)
    b:SetEdgeColor(PV_COL.accent2[1], PV_COL.accent2[2], PV_COL.accent2[3], 0.55)
    b:SetCenterColor(0.025, 0.03, 0.09, 0.62)
    b:SetDrawLevel(3)
    return b
end

local function PvCaption(parent, text)
    local l = PvLabel(parent, "$(MEDIUM_FONT)|17|soft-shadow-thick", zo_strformat and zo_strformat("<<Z:1>>", text) or text:upper())
    l:SetColor(PV_COL.accent[1], PV_COL.accent[2], PV_COL.accent[3], 1)
    l:SetDrawLevel(6)
    return l
end

-- aufgebaut wie das zielfenster im spiel: leben oben, darunter cp + @name,
-- dann "charakter - spieltitel - eigener titel"
local function PvFrame(parent, info, entry)
    local w = PV_INNER - 24
    local f = WM:CreateControl(nil, parent, CT_CONTROL)
    f:SetDimensions(w, 76)

    local frame = PvTex(f, nil, 5)
    frame:SetDimensions(300, 20)
    frame:SetAnchor(TOP, f, TOP, 0, 4)
    frame:SetColor(0.02, 0.02, 0.02, 0.95)
    local track = PvTex(f, nil, 6)
    track:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    track:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    track:SetColor(0.25, 0.03, 0.04, 1)
    local pct = math.max(0, math.min(1, info.hp / info.hpMax))
    local fill = PvTex(f, nil, 7)
    fill:SetAnchor(TOPLEFT, track, TOPLEFT, 0, 0)
    fill:SetDimensions(math.max(1, 296 * pct), 16)
    fill:SetColor(0.72, 0.08, 0.1, 1)
    local hpText = PvLabel(f, "$(BOLD_FONT)|15|soft-shadow-thick", ShortNumber(info.hp) .. " " .. math.floor(pct * 100 + 0.5) .. "%")
    hpText:SetAnchor(CENTER, frame, CENTER, 0, 0)
    hpText:SetDrawLevel(8)

    local cp = WM:CreateControl(nil, f, CT_TEXTURE)
    cp:SetTexture("EsoUI/Art/Champion/champion_icon_32.dds")
    cp:SetDimensions(18, 18)
    cp:SetDrawLevel(6)
    local row = PvLabel(f, "$(BOLD_FONT)|16|soft-shadow-thick", tostring(info.cp) .. "  " .. info.display)
    row:SetAnchor(TOP, frame, BOTTOM, 10, 3)
    row:SetDrawLevel(6)
    cp:SetAnchor(RIGHT, row, LEFT, -4, 0)

    local title = entry and JoinTitles(info.game, FormatTitle(entry)) or info.game
    local line = info.name
    if title and title ~= "" then line = line .. " - " .. title end
    local nm = PvLabel(f, "$(MEDIUM_FONT)|17|soft-shadow-thick", line)
    nm:SetAnchor(TOP, row, BOTTOM, -10, 1)
    nm:SetWidth(w)
    nm:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    nm:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    nm:SetColor(0.86, 0.84, 0.78, 1)
    nm:SetDrawLevel(6)
    return f
end

local function FillTitlePreview(win, focus)
    if win.content then win.content:SetHidden(true) end
    local c = WM:CreateControl(nil, win, CT_CONTROL)
    c:SetAnchor(TOPLEFT, win, TOPLEFT, PV_PAD, win.bodyTop)
    c:SetDimensions(PV_INNER, PV_H - win.bodyTop - PV_PAD)
    win.content = c

    -- unitframes
    local p1 = PvPanel(c, PV_INNER, 212)
    p1:SetAnchor(TOPLEFT, c, TOPLEFT, 0, 0)
    local cap1 = PvCaption(p1, "Unit frame")
    cap1:SetAnchor(TOPLEFT, p1, TOPLEFT, 14, 10)

    local ownInfo = UnitInfo(TITLE_OWNER, "Haze")
    local own = ownInfo.name
    local f1 = PvFrame(p1, ownInfo, TitleEntry(TITLE_OWNER))
    f1:SetAnchor(TOP, p1, TOP, 0, 38)

    -- /haze check zeigt die person, sonst ein dummy
    local sampleName, sampleEntry = "@player", { rank = "special", title = "Special", icon = 2, iconAfter = 2 }
    if focus then sampleName, sampleEntry = focus, TitleTable()[focus] end
    local f2 = PvFrame(p1, UnitInfo(sampleName), sampleEntry)
    f2:SetAnchor(TOP, f1, BOTTOM, 0, 8)

    -- bei check die werte aus der titel-datei dazu
    if focus then
        local e = sampleEntry
        local text
        if e then
            local sym = e.symbol and ("symbol " .. e.symbol)
                or ("icon " .. (e.icon ~= nil and tostring(e.icon) or "-") .. (e.iconAfter and ("/" .. e.iconAfter) or ""))
            local col = (type(e.color) == "string" and e.color ~= "") and e.color or "-"
            text = string.format("|c8088B4rank|r %s   |c8088B4%s|r   |c8088B4symbol color|r %s   |c8088B4title|r %s",
                e.rank or "special", sym, col, TitleColorText(e))
        else
            text = "|c8088B4no title|r"
        end
        local info = PvLabel(p1, "$(MEDIUM_FONT)|15|soft-shadow-thin", text)
        info:SetAnchor(TOP, f2, BOTTOM, 0, 4)
        p1:SetHeight(234)
    end

    -- chat
    local p2 = PvPanel(c, PV_INNER, 146)
    p2:SetAnchor(TOPLEFT, p1, BOTTOMLEFT, 0, 12)
    local cap2 = PvCaption(p2, "Chat")
    cap2:SetAnchor(TOPLEFT, p2, TOPLEFT, 14, 10)
    local creator = TitleEntry(TITLE_OWNER) or { rank = "creator", title = "" }
    local sampleText = "Thanks for the addon!"
    local lines = {
        "|cC8C8C8[Zone] [" .. own .. "]:|r " .. FormatChat(creator, "New update is live, have fun!"),
        "|cC8C8C8[Zone] [" .. sampleName .. "]:|r " .. (sampleEntry and FormatChat(sampleEntry, sampleText) or "|cE6E6E6" .. sampleText .. "|r"),
        "|cC8C8C8[Zone] [@someone]:|r |cE6E6E6Anyone up for a trial?|r",
    }
    local prev
    for _, line in ipairs(lines) do
        local l = PvLabel(p2, "$(CHAT_FONT)|17|soft-shadow-thin", line)
        l:SetWidth(PV_INNER - 32)
        l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        l:SetDrawLevel(6)
        if prev then l:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0, 8) else l:SetAnchor(TOPLEFT, cap2, BOTTOMLEFT, 4, 10) end
        prev = l
    end

    -- symbole 1-10 und eigene
    local p3 = PvPanel(c, PV_INNER, 96)
    p3:SetAnchor(TOPLEFT, p2, BOTTOMLEFT, 0, 12)
    local cap3 = PvCaption(p3, "Symbols")
    cap3:SetAnchor(TOPLEFT, p3, TOPLEFT, 14, 10)
    local legend = {}
    for i = 1, TITLE_ICON_COUNT do
        legend[#legend + 1] = string.format("|cFFFFFF|t24:24:%sT_Icon%d.dds:inheritcolor|t|r |cBFD0FF%d|r", TITLE_MEDIA, i, i)
    end
    local lg = PvLabel(p3, "$(BOLD_FONT)|16|soft-shadow-thin", table.concat(legend, "    "))
    lg:SetAnchor(TOPLEFT, cap3, BOTTOMLEFT, 4, 12)
    lg:SetDrawLevel(6)
    local customs = {}
    for _, n in ipairs(CustomSymbolNumbers()) do
        customs[#customs + 1] = SymbolMarkup({ rank = "special", color = "FFFFFF" }, n, 24) .. " |cBFD0FF" .. n .. "|r"
        if #customs >= 10 then break end
    end
    if #customs > 0 then
        p3:SetHeight(130)
        local lo = PvLabel(p3, "$(BOLD_FONT)|16|soft-shadow-thin", table.concat(customs, "    "))
        lo:SetAnchor(TOPLEFT, lg, BOTTOMLEFT, 0, 8)
        lo:SetDrawLevel(6)
    end
end

local function PaintPreviewBg(win, now)
    local t = now / 1000
    for _, ly in ipairs(win.layers) do
        local d = ly.def
        if d.tile then
            local su, sv_ = PV_W / d.tile, PV_H / d.tile
            local ou = ((d.ox or 0) + t * (d.vx or 0) / d.tile) % 1
            local ov = ((d.oy or 0) + t * (d.vy or 0) / d.tile) % 1
            ly.ctrl:SetTextureCoords(ou, ou + su, ov, ov + sv_)
        end
    end
end

local function BuildTitlePreview()
    local win = WM:CreateTopLevelWindow("AABPlusTitlePreview")
    win:SetDimensions(PV_W, PV_H)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)

    local shadow = PvTex(win, "UI_SoftGlow.dds", 0)
    shadow:SetDrawLayer(DL_BACKGROUND)
    shadow:SetAnchor(TOPLEFT, win, TOPLEFT, -60, -50)
    shadow:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 60, 70)
    shadow:SetColor(0, 0, 0, 0.85)

    -- ebenen wie im studio, wandern nur solange das fenster offen ist
    win.layers = {}
    for i, d in ipairs(PV_LAYERS) do
        local t = PvTex(win, d.file, i)
        t:SetDrawLayer(DL_BACKGROUND)
        t:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
        t:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -2, -2)
        if d.add then t:SetBlendMode(TEX_BLEND_MODE_ADD) end
        if d.tile and t.SetAddressMode and TEX_MODE_WRAP then t:SetAddressMode(TEX_MODE_WRAP) end
        t:SetAlpha(d.alpha or 1)
        win.layers[i] = { ctrl = t, def = d }
    end
    PaintPreviewBg(win, 0)

    local border = WM:CreateControl(nil, win, CT_BACKDROP)
    border:SetAnchorFill(win)
    border:SetEdgeTexture(TITLE_MEDIA .. "N_Frame.dds", 128, 16, 16, 0)
    border:SetEdgeColor(PV_COL.accent[1], PV_COL.accent[2], PV_COL.accent[3], 0.9)
    border:SetCenterColor(0, 0, 0, 0)
    border:SetDrawLevel(30)

    local logo = PvTex(win, "UI_Logo.dds", 5)
    logo:SetDimensions(52, 52)
    logo:SetAnchor(TOPLEFT, win, TOPLEFT, PV_PAD, 16)
    local glow = PvTex(win, "UI_SoftGlow.dds", 4)
    glow:SetDimensions(100, 100)
    glow:SetAnchor(CENTER, logo, CENTER, 0, 0)
    glow:SetColor(PV_COL.accent[1], PV_COL.accent[2], PV_COL.accent[3], 0.35)

    local head = PvLabel(win, "$(GAMEPAD_LIGHT_FONT)|30|soft-shadow-thick", "|cFFFFFFAnimated|r|cB9C8FFActionBar|r|c6FF0FF+|r")
    head:SetAnchor(BOTTOMLEFT, logo, RIGHT, 14, 4)
    head:SetDrawLevel(6)
    local sub = PvLabel(win, "$(MEDIUM_FONT)|14|soft-shadow-thin", "Title preview")
    sub:SetAnchor(TOPLEFT, logo, RIGHT, 16, 2)
    sub:SetColor(PV_COL.dim[1], PV_COL.dim[2], PV_COL.dim[3], 1)
    sub:SetDrawLevel(6)

    local line = PvTex(win, "UI_Divider.dds", 5)
    line:SetDimensions(PV_INNER, 6)
    line:SetAnchor(TOPLEFT, win, TOPLEFT, PV_PAD, 80)
    line:SetColor(PV_COL.accent[1], PV_COL.accent[2], PV_COL.accent[3], 0.8)
    win.bodyTop = 94

    local close = WM:CreateControl(nil, win, CT_CONTROL)
    close:SetDimensions(40, 40)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 10)
    close:SetDrawLayer(DL_OVERLAY)
    close:SetDrawTier(DT_HIGH)
    close:SetMouseEnabled(true)
    local x = WM:CreateControl(nil, close, CT_TEXTURE)
    x:SetTexture(TITLE_MEDIA .. "UI_Icon_Close.dds")
    x:SetDrawLayer(DL_OVERLAY)
    x:SetDrawTier(DT_HIGH)
    x:SetDimensions(22, 22)
    x:SetAnchor(CENTER, close, CENTER, 0, 0)
    x:SetColor(PV_COL.dim[1], PV_COL.dim[2], PV_COL.dim[3], 1)
    close:SetHandler("OnMouseEnter", function() x:SetColor(1, 0.42, 0.55, 1) end)
    close:SetHandler("OnMouseExit", function() x:SetColor(PV_COL.dim[1], PV_COL.dim[2], PV_COL.dim[3], 1) end)
    close:SetHandler("OnMouseUp", function(_, btn, inside)
        if inside and btn == MOUSE_BUTTON_INDEX_LEFT then SCENE_MANAGER:Hide("AABPlusTitlePreview") end
    end)

    FillTitlePreview(win)

    local scene = ZO_Scene:New("AABPlusTitlePreview", SCENE_MANAGER)
    scene:AddFragment(ZO_FadeSceneFragment:New(win, nil, 120))
    if FRAGMENT_GROUP and FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW then scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW) end
    scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            EM:RegisterForUpdate(PV_UPDATE, 33, function() PaintPreviewBg(win, GetFrameTimeMilliseconds()) end)
        elseif state == SCENE_HIDDEN then
            EM:UnregisterForUpdate(PV_UPDATE)
        end
    end)
    return win
end

-- /haze: vorschau, liste, give/take - nur für den owner

local function TitleLog(msg)
    d(Blend("[AAB+]", TITLE_RANKS.creator.stops) .. " " .. msg)
end

local function SortedTitles()
    local list = {}
    for k, e in pairs(TitleTable()) do list[#list + 1] = { key = k, e = e } end
    table.sort(list, function(a, b)
        if (a.e.rank == "creator") ~= (b.e.rank == "creator") then return a.e.rank == "creator" end
        return a.key < b.key
    end)
    return list
end

-- give/take ändern die tabelle nur im laufenden spiel, nichts wird gespeichert.
-- dauerhaft wird es erst über den eintrag in AnimatedActionBarPlus_Titles.lua
local function SetTitle(key, e)
    TitleTable()[key] = e
    ClearTitleCache()
    if titlePreview then FillTitlePreview(titlePreview, titlePreview.focused) end
end

function TitleCommand(args)
    if not IsTitleOwner() then return end
    local cmd, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "give" then
        -- /haze give @name <symbol> <titel>, symbol = 1-10, 4/2 oder 0
        local who, spec, title = rest:match("^(%S+)%s+(%S+)%s+(.+)$")
        local key = TitleKey(who)
        local icon, after = ParseSymbols(spec)
        if not key or not title or not icon then TitleLog("/haze give <@name|target> <symbol> <title>   symbol: 1-10 (or own 11+), 4/2 or 0"); return end
        if key == TITLE_OWNER then TitleLog("The creator title can only be changed in the file"); return end
        local old = TitleTable()[key] or {}
        local e = { rank = "special", title = title, icon = icon, iconAfter = after, color = old.color, titleColor = old.titleColor }
        SetTitle(key, e)
        TitleLog(key .. "  " .. FormatTitle(e))
        return
    elseif cmd == "color" then
        -- /haze color @name RRGGBB [RRGGBB ...], 0 = farben vom rang
        local who, cols = rest:match("^(%S+)%s+(.+)$")
        local key = TitleKey(who)
        local e = key and TitleTable()[key]
        if not key or not cols then TitleLog("/haze color <@name|target> <RRGGBB> [RRGGBB ...]   0 = rank colors"); return end
        if not e then TitleLog(key .. " has no title"); return end
        if cols == "0" then
            e.titleColor = nil
        else
            local list = {}
            for h in cols:gmatch("[^,%s]+") do
                h = h:gsub("#", ""):upper()
                if not HexOk(h) then TitleLog(h .. " is no RRGGBB color"); return end
                list[#list + 1] = h
            end
            e.titleColor = table.concat(list, ",")
        end
        SetTitle(key, e)
        TitleLog(key .. "  " .. FormatTitle(e))
        return
    elseif cmd == "icon" then
        -- /haze icon @name <symbol> [RRGGBB], gleiches format wie bei give
        local who, spec, col = rest:match("^(%S+)%s+(%S+)%s*(%S*)$")
        local key = TitleKey(who)
        local e = key and TitleTable()[key]
        local icon, after = ParseSymbols(spec)
        if not key or not icon then TitleLog("/haze icon <@name|target> <symbol> [RRGGBB]   symbol: 1-10 (or own 11+), 4/2 or 0"); return end
        if not e then TitleLog(key .. " has no title"); return end
        e.icon, e.iconAfter, e.symbol = icon, after, nil
        if col ~= "" then e.color = col end
        SetTitle(key, e)
        TitleLog(key .. "  " .. FormatTitle(e))
        return
    elseif cmd == "symbol" then
        -- /haze symbol @name <zeichen>, ohne zeichen wieder textur-symbol
        local who, sym = rest:match("^(%S+)%s*(.-)$")
        local key = TitleKey(who)
        local e = key and TitleTable()[key]
        if not key then TitleLog("/haze symbol @name <character>"); return end
        if not e then TitleLog(key .. " has no title"); return end
        e.symbol = (sym ~= "") and sym or nil
        if e.symbol then e.icon = nil end
        SetTitle(key, e)
        TitleLog(key .. "  " .. FormatTitle(e))
        return
    elseif cmd == "take" then
        local key = TitleKey(rest:match("^(%S+)"))
        if not key then TitleLog("/haze take @name"); return end
        if key == TITLE_OWNER then TitleLog("The creator title can only be changed in the file"); return end
        if not TitleTable()[key] then TitleLog(key .. " has no title"); return end
        SetTitle(key, nil)
        TitleLog(key .. " removed")
        return
    elseif cmd == "check" then
        local key = TitleKey(rest:match("^(%S+)"))
        if not key then TitleLog("/haze check @name"); return end
        local e = TitleTable()[key]
        if e then
            TitleLog(key .. "  |c8A8A96rank:|r " .. (e.rank or "special") .. "  |c8A8A96icon:|r " .. (e.symbol or ((e.icon or "-") .. (e.iconAfter and ("/" .. e.iconAfter) or "")))
                .. "  |c8A8A96symbol color:|r " .. (e.color or "-") .. "  |c8A8A96title color:|r " .. TitleColorText(e)
                .. "  |c8A8A96title:|r " .. FormatTitle(e))
        else
            TitleLog(key .. " has no title")
        end
        if not titlePreview then titlePreview = BuildTitlePreview() end
        FillTitlePreview(titlePreview, key)
        titlePreview.focused = key
        SCENE_MANAGER:Show("AABPlusTitlePreview")
        return
    elseif cmd == "list" then
        local list = SortedTitles()
        TitleLog(#list .. " titles")
        for _, it in ipairs(list) do d("  " .. it.key .. "  " .. FormatTitle(it.e)) end
        return
    end
    if not titlePreview then titlePreview = BuildTitlePreview() end
    if titlePreview.focused then titlePreview.focused = nil; FillTitlePreview(titlePreview) end
    if SCENE_MANAGER:IsShowing("AABPlusTitlePreview") then
        SCENE_MANAGER:Hide("AABPlusTitlePreview")
    else
        SCENE_MANAGER:Show("AABPlusTitlePreview")
    end
end

EM:RegisterForEvent("AnimatedActionBarPlusTitles", EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= "AnimatedActionBarPlus" then return end
    EM:UnregisterForEvent("AnimatedActionBarPlusTitles", EVENT_ADD_ON_LOADED)
    InstallTitleHooks()
    SLASH_COMMANDS["/haze"] = TitleCommand
end)
