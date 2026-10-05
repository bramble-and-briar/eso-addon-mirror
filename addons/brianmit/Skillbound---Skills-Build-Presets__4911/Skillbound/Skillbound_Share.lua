-- Skillbound_Share.lua : share codes.
-- A build as one line of text: gear by item (not your exact items, so a friend's copies are
-- found the same way as substitutes), skills, champion stars, food, mundus, prebuffs.
-- ESO gives addons no clipboard: the code is shown selected in a text box, you press
-- Ctrl+C; to import you paste a code with Ctrl+V and press Import.
--
-- Short form (0.6.0): "SB2:<name>:<data>". data packs the numbers into 64 letters
-- (0-9 A-Z a-z - _) at fixed widths, so no separators are needed: a whole build is about
-- 170 letters (the old "SB1;..." text was 500-700), and the same data rides in chat links.
-- Old SB1 codes and old chat links ("2_...") still import.

local B = Skillbound
local L = B.L
local C = B.COLOR
local Items, Capture = B.Items, B.Capture
local Share = {}
B.Share = Share

local PREFIX = "SB1"
local PREFIX2 = "SB2:"
local ui = {}

local function Clean(text)
    return (tostring(text or ""):gsub("[;=,|]", " "))
end

-- ---------------------------------------------------------------------------
-- The packed form. Numbers in base 64; ids take 3 letters (up to 253951; a bigger id is
-- "-" + 4 letters, the first letter of a 3-letter id never is "-"). Layout, in order:
--   "A" (format), class (2), parts mask (2),
--   gear: slot mask over Items.SLOTS (3), per piece: item id, trait (1), quality (1)
--   skills: mask over both bars' slots 3-8 (2), per skill its id; crafted mask (2), per
--           scribed skill its crafted id
--   champion: "0" none | "1" + star mask (2) + star ids  ("2" + two words = an old One Click
--             Champion Points setup: skipped when reading)
--   extras mask (1): 1 food (id), 2 mundus (count + ids), 4 prebuff (mask + ids), 8 eat in dungeons
local A64 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local VAL = {}
for i = 1, 64 do VAL[A64:sub(i, i)] = i - 1 end
local SHORT_MAX = 62 * 4096

local function Fixed(n, width)
    n = math.max(0, math.floor(tonumber(n) or 0))
    local s = {}
    for i = width, 1, -1 do
        local r = n % 64
        s[i] = A64:sub(r + 1, r + 1)
        n = math.floor(n / 64)
    end
    return table.concat(s)
end

local function Id(n)
    n = math.max(0, math.floor(tonumber(n) or 0))
    if n < SHORT_MAX then return Fixed(n, 3) end
    return "-" .. Fixed(n, 4)
end

local function Word(text)
    text = tostring(text or ""):gsub("[^%w%-_]", ""):sub(1, 63)
    return Fixed(#text, 1) .. text
end

local function Bit(mask, i) return math.floor(mask / 2 ^ i) % 2 == 1 end

local function Reader(s)
    local r = { s = s, i = 1, bad = false }
    function r:Fixed(width)
        local n = 0
        for _ = 1, width do
            local v = VAL[self.s:sub(self.i, self.i)]
            if not v then
                self.bad = true
                return 0
            end
            n = n * 64 + v
            self.i = self.i + 1
        end
        return n
    end
    function r:Id()
        if self.s:sub(self.i, self.i) == "-" then
            self.i = self.i + 1
            return self:Fixed(4)
        end
        return self:Fixed(3)
    end
    function r:Word()
        local n = self:Fixed(1)
        local w = self.s:sub(self.i, self.i + n - 1)
        if #w < n then self.bad = true end
        self.i = self.i + n
        return w
    end
    return r
end

-- the prebuff slots (Skillbound_Prebuff.lua): skills 3..7
local PRE_FIRST, PRE_LAST = 3, 7

function Share.Pack(b)
    local out = { "A", Fixed(b.classId or 0, 2) }
    local mask = 0
    for i, part in ipairs(Capture.PARTS) do
        if b.parts and b.parts[part] then mask = mask + 2 ^ (i - 1) end
    end
    out[#out + 1] = Fixed(mask, 2)
    local gmask, g = 0, {}
    for i, s in ipairs(Items.SLOTS) do
        local p = b.gear and b.gear[s]
        if p and p.id then
            gmask = gmask + 2 ^ (i - 1)
            g[#g + 1] = Id(p.id) .. Fixed(math.min(p.trait or 0, 63), 1) .. Fixed(math.min(p.q or 0, 63), 1)
        end
    end
    out[#out + 1] = Fixed(gmask, 3) .. table.concat(g)
    local smask, cmask, sk, cr, k = 0, 0, {}, {}, 0
    for _, cat in ipairs(Capture.BARS) do
        for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            local e = b.skills and b.skills[cat] and b.skills[cat][slot]
            if e and e.id then
                smask = smask + 2 ^ k
                sk[#sk + 1] = Id(e.id)
                if e.crafted then
                    cmask = cmask + 2 ^ k
                    cr[#cr + 1] = Id(e.crafted)
                end
            end
            k = k + 1
        end
    end
    out[#out + 1] = Fixed(smask, 2) .. table.concat(sk) .. Fixed(cmask, 2) .. table.concat(cr)
    if b.cp and b.cp.slots and next(b.cp.slots) then
        local cmask2, stars = 0, {}
        for i = 1, 12 do
            if b.cp.slots[i] then
                cmask2 = cmask2 + 2 ^ (i - 1)
                stars[#stars + 1] = Id(b.cp.slots[i])
            end
        end
        out[#out + 1] = "1" .. Fixed(cmask2, 2) .. table.concat(stars)
    else
        out[#out + 1] = "0"
    end
    local extras, tail = 0, {}
    if b.food and b.food.id then
        extras = extras + 1
        tail[#tail + 1] = Id(b.food.id)
    end
    if b.mundus and #b.mundus > 0 then
        extras = extras + 2
        local m = { Fixed(math.min(#b.mundus, 63), 1) }
        for _, id in ipairs(b.mundus) do m[#m + 1] = Id(id) end
        tail[#tail + 1] = table.concat(m)
    end
    local pre = b.prebuff and b.prebuff.skills
    if pre and next(pre) then
        extras = extras + 4
        local pmask, ids = b.prebuff.auto and 32 or 0, {}
        for slot = PRE_FIRST, PRE_LAST do
            if pre[slot] and pre[slot].id then
                pmask = pmask + 2 ^ (slot - PRE_FIRST)
                ids[#ids + 1] = Id(pre[slot].id)
            end
        end
        tail[#tail + 1] = Fixed(pmask, 1) .. table.concat(ids)
    end
    if b.foodAuto then extras = extras + 8 end   -- "Eat in dungeons" (a flag, no data)
    out[#out + 1] = Fixed(extras, 1) .. table.concat(tail)
    return table.concat(out)
end

-- a stand-in link for a shared piece (see LinkFor below; defined first for Unpack)
local LinkFor

-- a new build from packed data (nil when it isn't valid)
function Share.Unpack(data, name)
    local r = Reader(data or "")
    if r:Fixed(1) ~= VAL["A"] then return nil end
    local b = { id = B.NewId(), name = zo_strtrim(name or "") ~= "" and zo_strtrim(name) or L("SHARE_LINKED"),
        owner = L("SHARE_IMPORTED"), created = GetTimeStamp(), parts = {}, gear = {}, skills = {} }
    b.classId = r:Fixed(2)
    if b.classId == 0 then b.classId = nil end
    local mask = r:Fixed(2)
    for i, part in ipairs(Capture.PARTS) do b.parts[part] = Bit(mask, i - 1) or nil end
    local gmask = r:Fixed(3)
    for i, s in ipairs(Items.SLOTS) do
        if Bit(gmask, i - 1) then
            local id = r:Id()
            local p = Items.Info(LinkFor(id))
            p.trait, p.q = r:Fixed(1), r:Fixed(1)
            b.gear[s] = p
        end
    end
    local smask, order, k = r:Fixed(2), {}, 0
    for _, cat in ipairs(Capture.BARS) do
        for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            if Bit(smask, k) then
                local id = r:Id()
                b.skills[cat] = b.skills[cat] or {}
                b.skills[cat][slot] = { id = id, name = B.Name(GetAbilityName(id)), line = Capture.LineOf(id) }
            end
            order[k] = { cat, slot }
            k = k + 1
        end
    end
    local cmask = r:Fixed(2)
    for i = 0, k - 1 do
        if Bit(cmask, i) then
            local e = b.skills[order[i][1]] and b.skills[order[i][1]][order[i][2]]
            local crafted = r:Id()
            if e then e.crafted = crafted end
        end
    end
    local cpKind = r.s:sub(r.i, r.i)
    r.i = r.i + 1
    if cpKind == "2" then
        r:Word()   -- (a One Click Champion Points setup, 0.6.0-0.6.4: no longer part of builds)
        r:Word()
        b.parts.cp = nil
    elseif cpKind == "1" then
        local cpm = r:Fixed(2)
        b.cp = { slots = {} }
        for i = 1, 12 do
            if Bit(cpm, i - 1) then b.cp.slots[i] = r:Id() end
        end
    elseif cpKind ~= "0" then
        return nil
    end
    local extras = r:Fixed(1)
    if Bit(extras, 0) then b.food = { id = r:Id() } end
    if Bit(extras, 3) then b.foodAuto = true end
    if Bit(extras, 1) then
        b.mundus = {}
        for _ = 1, r:Fixed(1) do b.mundus[#b.mundus + 1] = r:Id() end
    end
    if Bit(extras, 2) then
        local pmask = r:Fixed(1)
        b.prebuff = { skills = {}, auto = Bit(pmask, 5) or nil }
        for slot = PRE_FIRST, PRE_LAST do
            if Bit(pmask, slot - PRE_FIRST) then
                local id = r:Id()
                b.prebuff.skills[slot] = { id = id, name = B.Name(GetAbilityName(id)), line = Capture.LineOf(id) }
            end
        end
    end
    if r.bad then return nil end
    -- parts that came without data (quickslots, outfit, title, mount, companion, empty ones) go off
    if next(b.gear) == nil then b.gear = nil end
    if next(b.skills) == nil then b.skills = nil end
    for _, part in ipairs(Capture.PARTS) do
        if b.parts[part] and b[part] == nil then b.parts[part] = false end
    end
    return b
end

-- the code you copy: "SB2:<name>:<data>"
function Share.Encode(b)
    local name = tostring(b.name or ""):gsub("[:|]", " ")
    return PREFIX2 .. name .. ":" .. Share.Pack(b)
end

-- a stand-in link for a shared piece: level 50 / CP160; field 20 (of 21) is the condition
-- (armor) / charges (weapons): 10000 = full (0 showed as broken / empty in tooltips)
LinkFor = function(itemId)
    return string.format("|H0:item:%d:363:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h", itemId)
end

-- a new build from a code (nil + reason when the code isn't valid)
function Share.Decode(code)
    code = zo_strtrim(code or ""):gsub("%s+", " ")
    -- the short form: "SB2:<name>:<data>" (the data has no spaces; a pasted code may have
    -- picked up some at the line ends)
    if code:sub(1, #PREFIX2) == PREFIX2 then
        local name, data = code:sub(#PREFIX2 + 1):match("^(.-):([^:]+)$")
        local b = data and Share.Unpack(data:gsub("%s", ""), name)
        if not b then return nil, L("SHARE_BAD") end
        return b
    end
    if code:sub(1, #PREFIX + 1) ~= PREFIX .. ";" then return nil, L("SHARE_BAD") end
    local f = {}
    for key, value in code:gmatch("(%a)=([^;]*)") do f[key] = value end
    if not f.n then return nil, L("SHARE_BAD") end
    local b = { id = B.NewId(), name = zo_strtrim(f.n), classId = tonumber(f.c), owner = L("SHARE_IMPORTED"),
        created = GetTimeStamp(), parts = {}, gear = {}, skills = {} }
    for p in (f.p or ""):gmatch("[^%.]+") do b.parts[p] = true end
    for s, id, trait, q in (f.g or ""):gmatch("(%d+)%.(%d+)%.(%d+)%.(%d+)") do
        local link = LinkFor(tonumber(id))
        local p = Items.Info(link)
        p.trait, p.q = tonumber(trait), tonumber(q)
        b.gear[tonumber(s)] = p
    end
    for entry in (f.s or ""):gmatch("[^,]+") do
        local cat, slot, id, crafted = entry:match("^(%d+)%.(%d+)%.(%d+)%.?(%d*)$")
        if cat then
            cat, slot, id = tonumber(cat), tonumber(slot), tonumber(id)
            b.skills[cat] = b.skills[cat] or {}
            b.skills[cat][slot] = {
                id = id, crafted = crafted ~= "" and tonumber(crafted) or nil,
                name = B.Name(GetAbilityName(id)), line = Capture.LineOf(id),
            }
        end
    end
    -- ("o=" was a One Click Champion Points setup: no longer part of builds, skipped)
    if f.x then
        b.cp = { slots = {} }
        for i, id in f.x:gmatch("(%d+)%.(%d+)") do b.cp.slots[tonumber(i)] = tonumber(id) end
    end
    if f.f then b.food = { id = tonumber(f.f) } end
    if f.m then
        b.mundus = {}
        for id in f.m:gmatch("%d+") do b.mundus[#b.mundus + 1] = tonumber(id) end
        if #b.mundus == 0 then b.mundus = nil end
    end
    -- a code carries gear, skills, champion, food and mundus only: parts the sender had on
    -- but that came without data (quickslots, outfit, title, mount, companion, or empty ones)
    -- are turned off, else "Wearing it changes" showed them lit with nothing behind them
    if next(b.gear) == nil then b.gear = nil end
    if next(b.skills) == nil then b.skills = nil end
    for _, part in ipairs(Capture.PARTS) do
        if b.parts[part] and b[part] == nil then b.parts[part] = false end
    end
    return b
end

-- ---------------------------------------------------------------------------
-- Chat links: "[Skillbound: name]" in chat, clickable for anyone with Skillbound (opens the
-- import window with the build filled in). Link type "skillbound" (|H1:skillbound:<data>|h[...]|h).
-- Since 0.6.0 data = Share.Pack (starts with "A"). Links from 0.5.0 carried an older short
-- form, still read here:
-- "2_<class>_<parts mask>_<gear: slot.id.trait>_<skills: cat*16+slot.id[.crafted]>_<cp: i.id>_<food>_<mundus ids>"
-- (base 36; the mundus section was added later: links without it still import)

local LINK_TYPE = "skillbound"
local MAX_LINE = 340   -- a chat line holds ~350 characters

local function N36(s) return tonumber(s or "", 36) or 0 end

-- the old link form back to a normal "SB1;..." code (then Decode does the rest)
function Share.FromCompact(data, name)
    local f = {}
    for part in (data .. "_"):gmatch("([^_]*)_") do f[#f + 1] = part end
    if f[1] ~= "2" then return nil end
    local out = { PREFIX, "n=" .. Clean(name ~= "" and name or L("SHARE_LINKED")), "c=" .. N36(f[2]) }
    local mask, parts = N36(f[3]), {}
    for i, p in ipairs(Capture.PARTS) do
        if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then parts[#parts + 1] = p end
    end
    out[#out + 1] = "p=" .. table.concat(parts, ".")
    local g = {}
    for s, id, t in (f[4] or ""):gmatch("(%w+)%.(%w+)%.(%w+)") do g[#g + 1] = N36(s) .. "." .. N36(id) .. "." .. N36(t) .. ".0" end
    if #g > 0 then out[#out + 1] = "g=" .. table.concat(g, ",") end
    local sk = {}
    for entry in (f[5] or ""):gmatch("[^%-]+") do
        local k, id, crafted = entry:match("^(%w+)%.(%w+)%.?(%w*)$")
        if k then
            local n = N36(k)
            sk[#sk + 1] = math.floor(n / 16) .. "." .. (n % 16) .. "." .. N36(id) .. (crafted ~= "" and ("." .. N36(crafted)) or "")
        end
    end
    if #sk > 0 then out[#out + 1] = "s=" .. table.concat(sk, ",") end
    local cp = {}
    for i, id in (f[6] or ""):gmatch("(%w+)%.(%w+)") do cp[#cp + 1] = N36(i) .. "." .. N36(id) end
    if #cp > 0 then out[#out + 1] = "x=" .. table.concat(cp, ",") end
    if f[7] and f[7] ~= "" then out[#out + 1] = "f=" .. N36(f[7]) end
    if f[8] and f[8] ~= "" then
        local m = {}
        for id in f[8]:gmatch("%w+") do m[#m + 1] = N36(id) end
        out[#out + 1] = "m=" .. table.concat(m, ".")
    end
    return table.concat(out, ";")
end

-- the link carries the packed data (Share.Pack, ~170 letters for a whole build): it fits a chat
-- line with everything in it (the old "2_..." links had to leave out champion stars and food)
local function MakeLink(b, nameLen)
    local name = Clean(b.name):gsub("[%[%]:]", "")
    if nameLen then name = name:sub(1, nameLen) end
    return string.format("|H1:%s:%s|h[%s]|h", LINK_TYPE, Share.Pack(b), L("SHARE_LINK_TEXT", name))
end

-- puts the link into the chat box (you press Enter to send it)
function Share.LinkInChat(b)
    if not b then return end
    local link = MakeLink(b)
    if #link > MAX_LINE then link = MakeLink(b, 24) end   -- a very long name gets shortened in the link
    if #link > MAX_LINE then
        B.Print(L("SHARE_LINK_LONG"))
        Share.ShowCode(b)
        return
    end
    if StartChatInput then
        StartChatInput(link)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.StartTextEntry then
        CHAT_SYSTEM:StartTextEntry(link)
    else
        B.Print(link)
    end
end

local function OnLink(link, button, text, color, linkType, data)
    if linkType ~= LINK_TYPE then return end
    -- the name sits in the link text: "[Skillbound: <name>]"
    local name = (text or ""):gsub("^%[", ""):gsub("%]$", "")
    local prefix = L("SHARE_LINK_TEXT", "")
    if name:sub(1, #prefix) == prefix then name = name:sub(#prefix + 1) end
    name = zo_strtrim(name)
    data = data or ""
    local code
    if data:sub(1, 1) == "A" then
        -- the packed form (0.6.0): shown as the short code in the import window
        code = Share.Unpack(data, name) and (PREFIX2 .. name:gsub("[:|]", " ") .. ":" .. data) or nil
    else
        code = Share.FromCompact(data, name)   -- an older "2_..." link
    end
    if not code then
        B.Print(L("SHARE_BAD"))
        return true
    end
    Share.ShowImport(code)
    return true
end

function Share.Init()
    if LINK_HANDLER and LINK_HANDLER.RegisterCallback then
        -- left click opens the import; other buttons on our link: swallowed (no game menu for it)
        LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, OnLink)
        LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, function(link, button, text, color, linkType)
            if linkType == LINK_TYPE and button ~= MOUSE_BUTTON_INDEX_LEFT then return true end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Window: shows a code to copy, or takes one to import

local function Create()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_Share")
    ui.win = win
    win:SetDimensions(460, 230)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    -- where you left it last time (also after a restart), else the middle of the screen
    if not B.W.RememberPlace(win, "share") then win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60) end
    B.callbacks:RegisterCallback("PositionsReset", function() B.Anim.Anchor(win, CENTER, GuiRoot, CENTER, 0, -60) end)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    local bg = B.W.Panel(win, 0.96, 0.7)
    bg:SetAnchorFill(win)
    B.W.Brackets(win, 2, 7)

    ui.title = B.W.Label(win, B.Font("title", 18), C.text, "")
    ui.title:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 12)
    ui.hint = B.W.Label(win, B.Font("text", 13), C.dim, "")
    ui.hint:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 4)
    ui.hint:SetWidth(428)

    local box, edit = B.W.Edit(win, 428, nil, true)
    box:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 76)
    edit:SetMaxInputChars(4000)
    ui.edit = edit

    ui.ok = B.W.Button(win, L("SHARE_IMPORT"), function()
        local b, why = Share.Decode(ui.edit:GetText())
        if not b then
            ui.hint:SetText(B.Colorize(C.bad, why))
            return
        end
        B.sv.builds[b.id] = b
        B.callbacks:FireCallbacks("BuildsChanged")
        B.Print(L("SHARE_IMPORTED_AS", b.name))
        win:SetHidden(true)
        if B.UI.Select then B.UI.Select(b.id) end
    end, "plate", 150, 40)
    ui.ok:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, -12)
    -- sharing: the same spot holds "Link in chat" (puts a clickable link in your chat box)
    ui.link = B.W.Button(win, L("MENU_LINK"), function()
        if ui.build then
            win:SetHidden(true)
            Share.LinkInChat(ui.build)
        end
    end, "plate", 200, 40)   -- (wide enough that the logo doesn't touch the text)
    ui.link:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, -12)
    ui.link.tooltip = L("SHARE_LINK_TT")
    local close = B.W.Button(win, L("CLOSE"), function() win:SetHidden(true) end, "normal", 90)
    close:SetAnchor(RIGHT, ui.ok, LEFT, -8, 0)
    ui.close = close
end

function Share.ShowCode(build)
    if not ui.win then Create() end
    ui.title:SetText(L("SHARE_TITLE", build.name))
    ui.hint:SetText(L("SHARE_COPY_HINT"))
    ui.ok:SetHidden(true)
    ui.link:SetHidden(false)
    ui.close:ClearAnchors()
    ui.close:SetAnchor(RIGHT, ui.link, LEFT, -10, 0)
    ui.build = build
    ui.edit:SetText(Share.Encode(build))
    ui.win:SetHidden(false)
    B.Anim.Alpha(ui.win, 0, 1, B.Anim.STD, B.Anim.Out, "Skillbound_Share")
    ui.edit:TakeFocus()
    ui.edit:SelectAll()
end

-- code: filled in already (a clicked chat link), else empty to paste into
function Share.ShowImport(code)
    if not ui.win then Create() end
    ui.title:SetText(L("SHARE_IMPORT_TITLE"))
    ui.hint:SetText(L(code and "SHARE_LINK_HINT" or "SHARE_PASTE_HINT"))
    ui.ok:SetHidden(false)
    ui.link:SetHidden(true)
    ui.close:ClearAnchors()
    ui.close:SetAnchor(RIGHT, ui.ok, LEFT, -10, 0)
    ui.edit:SetText(code or "")
    ui.win:SetHidden(false)
    B.Anim.Alpha(ui.win, 0, 1, B.Anim.STD, B.Anim.Out, "Skillbound_Share")
    ui.edit:TakeFocus()
end
