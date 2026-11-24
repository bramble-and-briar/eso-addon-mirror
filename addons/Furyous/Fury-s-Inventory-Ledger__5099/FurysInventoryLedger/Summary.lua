-- Fury's Inventory Ledger - summary page
-- Totals by location, item type and quality, currency running totals with day-over-day and
-- week-over-week changes, most-owned items and a line per character.

local FIL = FurysInventoryLedger

local T = FIL.Theme   -- Fury Night colors and fonts (Theme.lua)

local CONTENT_WIDTH = 920
local ROW_H         = 24
local TOP_ITEMS     = 25
local HISTORY_DAYS  = 120

local LOCATION_ORDER = {
    "Character", "Companion", "Bank", "Craft Bag", "House Storage", "Furniture Vault", "Placed in House",
}

------------------------------------------------------------------------------
-- Numbers and dates
------------------------------------------------------------------------------
local function Num(n)
    return ZO_CommaDelimitNumber(n or 0)
end

local function Signed(n)
    if n == nil then return "" end
    if n > 0 then return "+" .. Num(n) end
    if n < 0 then return "-" .. Num(-n) end
    return "0"
end

local function Day(daysAgo)
    return os.date("%Y-%m-%d", GetTimeStamp() - (daysAgo or 0) * 86400)
end

-- "yesterday" / "7 days" when the saved total is from exactly then, otherwise the month-day it is from.
local function SinceLabel(day, exactDay, exactText)
    if not day then return exactText end
    if day == exactDay then return exactText end
    return day:sub(6)
end

-- Gold amount with the game's own coin icon.
local function Gold(n)
    return ZO_Currency_FormatKeyboard(CURT_MONEY, n or 0, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
end

-- Color for a change: green up, rose down, muted when flat or unknown.
local function ChangeColor(n)
    if n and n > 0 then return T.GOOD end
    if n and n < 0 then return T.BAD end
    return T.MUTED
end

local function Pct(part, whole)
    if whole <= 0 then return "" end
    return string.format("%.1f%%", part * 100 / whole)
end

------------------------------------------------------------------------------
-- Aggregation
------------------------------------------------------------------------------
local function Bump(tbl, key, qty, value)
    local e = tbl[key]
    if not e then
        e = { name = key, qty = 0, stacks = 0, value = 0 }
        tbl[key] = e
    end
    e.qty    = e.qty + qty
    e.stacks = e.stacks + 1
    e.value  = e.value + value
    return e
end

local function SortedValues(tbl, less)
    local list = {}
    for _, v in pairs(tbl) do list[#list + 1] = v end
    table.sort(list, less)
    return list
end

local function ByQtyDesc(a, b)
    if a.qty ~= b.qty then return a.qty > b.qty end
    return a.name < b.name
end

function FIL.SummaryAggregate()
    local acct     = FIL.GetAccount()
    local OWN      = FIL.ACCOUNT_OWNER
    local goldName = zo_strformat("<<1>>", GetCurrencyName(CURT_MONEY, false, false))
    local furnType = GetString("SI_ITEMTYPE", ITEMTYPE_FURNISHING)

    local r = {
        qty = 0, stacks = 0, value = 0, unique = 0,
        byLoc = {}, byType = {}, byQuality = {}, byItem = {}, cur = {}, chars = {},
        goldName = goldName,
    }

    local function addCurrency(name, where, qty)
        local c = r.cur[name]
        if not c then
            c = { name = name, chars = 0, bank = 0, account = 0 }
            r.cur[name] = c
        end
        c[where] = c[where] + qty
    end

    local function addContainer(cont, charEntry)
        for _, it in ipairs(cont.items) do
            if it.cur then
                local where = "chars"
                if cont.owner == OWN then where = (cont.location == "Bank") and "bank" or "account" end
                addCurrency(it.n, where, it.q)
                if charEntry and it.n == goldName then charEntry.gold = charEntry.gold + it.q end
            else
                local info  = it.l and FIL.LinkInfo(it.l)
                local itype = info and info.itype or furnType
                if itype == "" then itype = "Other" end
                local value = (info and info.value or 0) * it.q

                r.qty, r.stacks, r.value = r.qty + it.q, r.stacks + 1, r.value + value
                Bump(r.byLoc, cont.location, it.q, value)
                Bump(r.byType, itype, it.q, value)
                if info and info.qnum then
                    Bump(r.byQuality, info.quality, it.q, value).order = info.qnum
                end

                local key = info and (itype .. ":" .. tostring(info.id)) or ("name:" .. tostring(it.n))
                local item = r.byItem[key]
                if not item then
                    item = { name = info and info.name or it.n or "?", itype = itype, qty = 0, stacks = 0, value = 0, places = {} }
                    r.byItem[key] = item
                    r.unique = r.unique + 1
                end
                item.qty, item.stacks, item.value = item.qty + it.q, item.stacks + 1, item.value + value
                item.places[cont.location] = true

                if charEntry then
                    if cont.container == "Backpack" then
                        charEntry.carried = charEntry.carried + it.q
                    else
                        charEntry.equipped = charEntry.equipped + it.q
                    end
                end
            end
        end
    end

    for id, ch in pairs(acct.chars) do
        local entry = { id = id, name = ch.name or "?", carried = 0, equipped = 0, gold = 0, updated = ch.updated }
        r.chars[#r.chars + 1] = entry
        for _, cont in pairs(ch.containers) do addContainer(cont, entry) end
    end
    for _, cont in pairs(acct.shared) do addContainer(cont, nil) end

    for _, c in pairs(r.cur) do c.total = c.chars + c.bank + c.account end
    r.gold = r.cur[goldName] and r.cur[goldName].total or 0
    return r
end

------------------------------------------------------------------------------
-- Daily snapshots for the change columns
------------------------------------------------------------------------------
function FIL.RecordSnapshot(r)
    local acct = FIL.GetAccount()
    if not acct then return end
    r = r or FIL.SummaryAggregate()
    acct.history = acct.history or {}
    local snap = { items = r.qty, value = r.value, cur = {} }
    for name, c in pairs(r.cur) do snap.cur[name] = c.total end
    acct.history[Day(0)] = snap
    local cutoff = Day(HISTORY_DAYS)
    for day in pairs(acct.history) do
        if day < cutoff then acct.history[day] = nil end
    end
end

-- Latest snapshot dated on or before the given day.
local function Baseline(history, onOrBefore)
    local best
    for day in pairs(history) do
        if day <= onOrBefore and (not best or day > best) then best = day end
    end
    return best and history[best], best
end

------------------------------------------------------------------------------
-- Drawing: a pool of labels and textures inside the scroll child
------------------------------------------------------------------------------
local child
local labels, textures = {}, {}
local usedLabels, usedTextures = 0, 0
local y = 0

local function ResetCanvas()
    for i = 1, usedLabels do labels[i]:SetHidden(true) end
    for i = 1, usedTextures do textures[i]:SetHidden(true) end
    usedLabels, usedTextures, y = 0, 0, 0
end

local function NewLabel(x, top, width, height, text, font, color, align)
    usedLabels = usedLabels + 1
    local l = labels[usedLabels]
    if not l then
        l = WINDOW_MANAGER:CreateControl("FurysInventoryLedgerSummaryLabel" .. usedLabels, child, CT_LABEL)
        l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        labels[usedLabels] = l
    end
    l:ClearAnchors()
    l:SetAnchor(TOPLEFT, child, TOPLEFT, x, top)
    l:SetDimensions(width, height)
    l:SetFont(font or "ZoFontGame")
    l:SetColor((color or T.TEXT):UnpackRGBA())
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetText(text or "")
    l:SetHidden(false)
    return l
end

local function NewRect(x, top, width, height, color)
    usedTextures = usedTextures + 1
    local t = textures[usedTextures]
    if not t then
        t = WINDOW_MANAGER:CreateControl("FurysInventoryLedgerSummaryRect" .. usedTextures, child, CT_TEXTURE)
        t:SetDrawLayer(DL_BACKGROUND)
        textures[usedTextures] = t
    end
    t:ClearAnchors()
    t:SetAnchor(TOPLEFT, child, TOPLEFT, x, top)
    t:SetDimensions(width, height)
    t:SetColor(color:UnpackRGBA())
    t:SetHidden(false)
    return t
end

local function Section(title, note)
    y = y + 18
    NewLabel(0, y, CONTENT_WIDTH, 30, title, T.FONT_SECTION, T.TEXT)
    if note then
        NewLabel(0, y, CONTENT_WIDTH, 30, note, "ZoFontGameSmall", T.MUTED, TEXT_ALIGN_RIGHT)
    end
    y = y + 30
    NewRect(0, y, CONTENT_WIDTH, 2, T.VIOLET)
    y = y + 6
end

-- cols: { { title, width, align }, ... }
-- rows: list of { cells = {...}, dim = bool, colors = { [column] = color } }
local function Table(cols, rows)
    local x = 0
    for _, c in ipairs(cols) do
        NewLabel(x + 6, y, c[2] - 12, ROW_H, c[1], T.FONT_HEADER, T.BLUE, c[3])
        x = x + c[2]
    end
    y = y + ROW_H
    NewRect(0, y - 1, CONTENT_WIDTH, 1, T.EDGE)
    for i, row in ipairs(rows) do
        if i % 2 == 0 then NewRect(0, y, CONTENT_WIDTH, ROW_H, T.STRIPE) end
        x = 0
        for ci, c in ipairs(cols) do
            local color = row.dim and T.MUTED or (row.colors and row.colors[ci]) or T.TEXT
            NewLabel(x + 6, y, c[2] - 12, ROW_H, row.cells[ci], T.FONT_BODY, color, c[3])
            x = x + c[2]
        end
        y = y + ROW_H
    end
end

local function Tile(index, value, caption, change, delta, valueColor)
    local width, gap = 145, 10
    local x = (index - 1) * (width + gap)
    NewRect(x, y, width, 86, T.STRIPE)
    NewRect(x, y, width, 2, T.VIOLET)
    NewLabel(x + 8, y + 8, width - 16, 34, value, T.FONT_NUMBER, valueColor or T.TEXT, TEXT_ALIGN_CENTER)
    NewLabel(x + 8, y + 42, width - 16, 20, caption, "ZoFontGameSmall", T.SUB, TEXT_ALIGN_CENTER)
    NewLabel(x + 8, y + 60, width - 16, 20, change or "", "ZoFontGameSmall", ChangeColor(delta), TEXT_ALIGN_CENTER)
end

------------------------------------------------------------------------------
-- The page
------------------------------------------------------------------------------
local RIGHT, LEFT = TEXT_ALIGN_RIGHT, TEXT_ALIGN_LEFT

local function Draw()
    FIL.FlushPending()
    local acct = FIL.GetAccount()
    local r = FIL.SummaryAggregate()
    FIL.RecordSnapshot(r)

    local history = acct.history or {}
    local yesterday, yDay = Baseline(history, Day(1))
    local lastWeek, wDay  = Baseline(history, Day(7))

    local win = FurysInventoryLedgerSummary
    win:GetNamedChild("Sub"):SetText(zo_strformat("<<1>>  -  <<2>> of <<3>> characters scanned",
        FIL.accountKey, #r.chars, GetNumCharacters()))

    ResetCanvas()

    -- Tiles
    -- Returns the "+12 since yesterday" text and the change itself (for its color).
    local function vsYesterday(now, field, curName)
        if not yesterday then return "" end
        local before = curName and yesterday.cur and yesterday.cur[curName] or (not curName and yesterday[field])
        if not before then return "" end
        return Signed(now - before) .. " since " .. SinceLabel(yDay, Day(1), "yesterday"), now - before
    end
    local itemsText, itemsDelta = vsYesterday(r.qty, "items")
    local goldText,  goldDelta  = vsYesterday(r.gold, nil, r.goldName)
    local valueText, valueDelta = vsYesterday(r.value, "value")
    Tile(1, Num(r.qty),    "Items",           itemsText, itemsDelta)
    Tile(2, Num(r.unique), "Different items", "")
    Tile(3, Num(r.stacks), "Stacks / rows",   "")
    Tile(4, Gold(r.gold),  r.goldName,        goldText, goldDelta, T.GOLD)
    Tile(5, Num(r.value),  "Vendor value",    valueText, valueDelta)
    Tile(6, zo_strformat("<<1>>/<<2>>", #r.chars, GetNumCharacters()), "Characters", "/ledger chars")
    y = y + 86

    -- Currencies
    local curRows = {}
    local curList = SortedValues(r.cur, function(a, b)
        if (a.name == r.goldName) ~= (b.name == r.goldName) then return a.name == r.goldName end
        return a.name < b.name
    end)
    for _, c in ipairs(curList) do
        local dY = yesterday and yesterday.cur and yesterday.cur[c.name]
        local dW = lastWeek and lastWeek.cur and lastWeek.cur[c.name]
        local isGold = (c.name == r.goldName)
        local amount = isGold and T.GOLD or T.TEXT
        local changeY = dY and (c.total - dY)
        local changeW = dW and (c.total - dW)
        curRows[#curRows + 1] = {
            cells = {
                c.name,
                c.chars > 0 and Num(c.chars) or "",
                (c.bank + c.account) > 0 and Num(c.bank + c.account) or "",
                isGold and Gold(c.total) or Num(c.total),
                changeY and Signed(changeY) or "",
                changeW and Signed(changeW) or "",
            },
            colors = { [2] = amount, [3] = amount, [4] = amount, [5] = ChangeColor(changeY), [6] = ChangeColor(changeW) },
        }
    end
    local note = (yDay or wDay) and "Change = now minus your saved total from that day"
        or "Change columns fill in from tomorrow"
    Section("Currencies", note)
    Table({
        { "Currency", 260, LEFT }, { "On characters", 140, RIGHT }, { "Bank", 160, RIGHT },
        { "Total", 140, RIGHT },
        { "vs " .. SinceLabel(yDay, Day(1), "yesterday"), 110, RIGHT }, { "vs " .. SinceLabel(wDay, Day(7), "7 days"), 110, RIGHT },
    }, curRows)

    -- Where it is
    local locRows = {}
    for _, name in ipairs(LOCATION_ORDER) do
        local e = r.byLoc[name]
        if e then
            locRows[#locRows + 1] = { cells = { name, Num(e.qty), Num(e.stacks), Num(e.value), Pct(e.qty, r.qty) } }
        end
    end
    Section("Where it is")
    Table({
        { "Location", 300, LEFT }, { "Items", 150, RIGHT }, { "Stacks", 150, RIGHT },
        { "Vendor value", 170, RIGHT }, { "Share of items", 150, RIGHT },
    }, locRows)

    -- By item type
    local typeRows = {}
    for _, e in ipairs(SortedValues(r.byType, ByQtyDesc)) do
        typeRows[#typeRows + 1] = { cells = { e.name, Num(e.qty), Num(e.stacks), Num(e.value), Pct(e.qty, r.qty) } }
    end
    Section("By item type", zo_strformat("<<1>> types", #typeRows))
    Table({
        { "Item type", 300, LEFT }, { "Items", 150, RIGHT }, { "Stacks", 150, RIGHT },
        { "Vendor value", 170, RIGHT }, { "Share of items", 150, RIGHT },
    }, typeRows)

    -- By quality
    local qualRows = {}
    for _, e in ipairs(SortedValues(r.byQuality, function(a, b) return a.order < b.order end)) do
        qualRows[#qualRows + 1] = { cells = { e.name, Num(e.qty), Num(e.stacks), Num(e.value), Pct(e.qty, r.qty) } }
    end
    Section("By quality")
    Table({
        { "Quality", 300, LEFT }, { "Items", 150, RIGHT }, { "Stacks", 150, RIGHT },
        { "Vendor value", 170, RIGHT }, { "Share of items", 150, RIGHT },
    }, qualRows)

    -- Most owned
    local itemRows = {}
    for i, e in ipairs(SortedValues(r.byItem, ByQtyDesc)) do
        if i > TOP_ITEMS then break end
        local places = {}
        for _, name in ipairs(LOCATION_ORDER) do
            if e.places[name] then places[#places + 1] = name end
        end
        itemRows[#itemRows + 1] = { cells = { e.name, e.itype, Num(e.qty), table.concat(places, ", ") } }
    end
    Section(zo_strformat("Most owned (top <<1>>)", TOP_ITEMS))
    Table({
        { "Item", 300, LEFT }, { "Type", 190, LEFT }, { "Count", 110, RIGHT }, { "Kept in", 320, LEFT },
    }, itemRows)

    -- Characters
    table.sort(r.chars, function(a, b) return a.name < b.name end)
    local charRows = {}
    for _, c in ipairs(r.chars) do
        charRows[#charRows + 1] = {
            cells  = { c.name, Num(c.carried), Num(c.equipped), Gold(c.gold), FIL.FormatTime(c.updated) },
            colors = { [4] = T.GOLD, [5] = T.SUB },
        }
    end
    local seen = {}
    for _, c in ipairs(r.chars) do seen[c.id] = true end
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        if not seen[id] then
            charRows[#charRows + 1] = { dim = true, cells = { zo_strformat("<<1>>", name), "", "", "", "Not scanned yet - log in once" } }
        end
    end
    Section("Characters")
    Table({
        { "Character", 300, LEFT }, { "Carried", 140, RIGHT }, { "Equipped", 140, RIGHT },
        { r.goldName, 150, RIGHT }, { "Last scanned", 190, RIGHT },
    }, charRows)

    y = y + 20
    NewLabel(0, y, CONTENT_WIDTH, 20,
        "Other characters show what they held at their last logout. Coffers and the Furniture Vault update when opened.",
        "ZoFontGameSmall", T.MUTED)
    y = y + 24
    NewRect(0, y, CONTENT_WIDTH, 1, ZO_ColorDef:New(0, 0, 0, 0))   -- sets the scroll extent
end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------
function FIL.OpenSummary()
    local win = FurysInventoryLedgerSummary
    local scroll = win:GetNamedChild("Body")
    child = scroll:GetNamedChild("ScrollChild")
    Draw()
    ZO_Scroll_ResetToTop(scroll)
    SCENE_MANAGER:Show(FIL.SUMMARY_SCENE)
end

function FIL.ToggleSummary()
    if SCENE_MANAGER:IsShowing(FIL.SUMMARY_SCENE) then
        SCENE_MANAGER:Hide(FIL.SUMMARY_SCENE)
    else
        FIL.OpenSummary()
    end
end

function FIL.RefreshSummary()
    Draw()
end

function FIL.CloseSummary()
    if SCENE_MANAGER:IsShowing(FIL.SUMMARY_SCENE) then SCENE_MANAGER:Hide(FIL.SUMMARY_SCENE) end
end

function FIL.SummaryToCopy()
    FIL.OpenWindow()
end
