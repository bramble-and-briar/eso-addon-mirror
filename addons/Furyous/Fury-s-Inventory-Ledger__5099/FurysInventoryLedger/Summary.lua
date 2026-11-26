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
        for _, it in ipairs(FIL.Items(cont)) do
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
        local pack = ch.containers.backpack
        local entry = { id = id, name = ch.name or "?", carried = 0, equipped = 0, gold = 0, updated = ch.updated,
            size = pack and pack.size, used = pack and pack.used }
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

function FIL.ShowCutText(label)
    if not label:WasTruncated() then return end
    InitializeTooltip(InformationTooltip, label, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, label:GetText())
end

function FIL.HideCutText()
    ClearTooltip(InformationTooltip)
end

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
        -- A cell that is cut short shows its full text on hover.
        l:SetMouseEnabled(true)
        l:SetHandler("OnMouseEnter", FIL.ShowCutText)
        l:SetHandler("OnMouseExit", FIL.HideCutText)
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

local FIND_ROWS = 150
local findText = ""

-- "37 free of 210", or a hint when the place was last read by a version that did not save sizes.
local function FreeText(size, used)
    if not size or not used then return "log in to fill" end
    return zo_strformat("<<1>> free of <<2>>", Num(size - used), Num(size))
end

-- Free space colors: rose when full, amber when nearly full.
local function FreeColor(size, used)
    if not size or not used then return T.MUTED end
    local free = size - used
    if free <= 0 then return T.BAD end
    if free * 10 <= size then return T.WARN end
    return T.TEXT
end

-- The page while the Find box holds words: one row per matching item, every account.
local function DrawFind()
    local list = FIL.Find(findText)
    local rows, total = {}, 0
    for _, e in ipairs(list) do total = total + e.qty end
    for i, e in ipairs(list) do
        if i > FIND_ROWS then break end
        rows[#rows + 1] = { cells = { e.name, e.kind, Num(e.qty), FIL.PlacesText(e, 8) }, colors = { [2] = T.SUB } }
    end
    local note = (#list > FIND_ROWS) and zo_strformat("Showing the first <<1>>. Add a word to narrow it.", FIND_ROWS)
        or "Clear the box to go back to the summary"
    Section(zo_strformat("<<1>> matches, <<2>> items for \"<<3>>\"", Num(#list), Num(total), findText), note)
    if #rows == 0 then
        y = y + 10
        NewLabel(0, y, CONTENT_WIDTH, 24, "Nothing you own matches. It searches item names and set names on every character and account read so far.", T.FONT_BODY, T.SUB)
        y = y + 30
        NewLabel(0, y, CONTENT_WIDTH, 24, "Clear the box to see what is still to read.", T.FONT_BODY, T.MUTED)
        y = y + 24
    else
        Table({
            { "Item", 280, LEFT }, { "Type or set", 190, LEFT }, { "Count", 80, RIGHT }, { "Where", 370, LEFT },
        }, rows)
    end
    y = y + 24
    NewRect(0, y, CONTENT_WIDTH, 1, ZO_ColorDef:New(0, 0, 0, 0))
end

-- Gold over the saved days as a row of bars, oldest on the left.
local function GoldChart(history, goldName)
    local days = {}
    for day, snap in pairs(history) do
        if snap.cur and snap.cur[goldName] then days[#days + 1] = day end
    end
    table.sort(days)
    Section("Gold over time", (#days > 1) and zo_strformat("<<1>> saved days, <<2>> to <<3>>", #days, days[1], days[#days]) or nil)
    if #days < 2 then
        NewLabel(0, y, CONTENT_WIDTH, ROW_H, "The chart starts on your second day with the addon. One total is saved per day you play.", T.FONT_BODY, T.SUB)
        y = y + ROW_H
        return
    end
    local low, high = math.huge, 0
    for _, day in ipairs(days) do
        local g = history[day].cur[goldName]
        if g < low then low = g end
        if g > high then high = g end
    end
    local CHART_H, LABEL_W = 90, 150
    local plotW = CONTENT_WIDTH - LABEL_W
    local barW = math.min(40, math.floor(plotW / #days))
    local span = high - low
    NewLabel(0, y, LABEL_W - 10, 20, Gold(high), "ZoFontGameSmall", T.GOLD, RIGHT)
    NewLabel(0, y + CHART_H - 20, LABEL_W - 10, 20, Gold(low), "ZoFontGameSmall", T.GOLD, RIGHT)
    NewRect(LABEL_W, y + CHART_H, plotW, 1, T.EDGE)
    for i, day in ipairs(days) do
        local g = history[day].cur[goldName]
        -- the lowest day still gets a short bar, so every saved day is visible
        local h = 8 + ((span > 0) and math.floor((g - low) * (CHART_H - 8) / span) or 0)
        NewRect(LABEL_W + (i - 1) * barW, y + CHART_H - h, math.max(barW - 2, 1), h, (i == #days) and T.GOLD or T.VIOLET)
    end
    y = y + CHART_H + 6
    NewLabel(LABEL_W, y, plotW, 18, "Each bar is one saved day, oldest on the left; today is gold. Bars run from your lowest to your highest total.", "ZoFontGameSmall", T.MUTED)
    y = y + 18
end

local function Draw()
    FIL.FlushPending()
    local acct = FIL.GetAccount()
    local r = FIL.SummaryAggregate()
    FIL.RecordSnapshot(r)

    local history = acct.history or {}
    local yesterday, yDay = Baseline(history, Day(1))
    local lastWeek, wDay  = Baseline(history, Day(7))

    -- Characters on this account right now, to tell scanned, missing and deleted ones apart.
    local onAccount, numOnAccount = {}, GetNumCharacters()
    for i = 1, numOnAccount do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        onAccount[id] = zo_strformat("<<1>>", name)
    end
    local scanned, seen = 0, {}
    for _, c in ipairs(r.chars) do
        seen[c.id] = true
        c.gone = (onAccount[c.id] == nil)
        if not c.gone then scanned = scanned + 1 end
    end
    local missingChars = {}
    for i = 1, numOnAccount do
        local _, _, _, _, _, _, id = GetCharacterInfo(i)
        if not seen[id] then missingChars[#missingChars + 1] = onAccount[id] end
    end

    local win = FurysInventoryLedgerSummary
    win:GetNamedChild("Sub"):SetText(zo_strformat("<<1>>  -  <<2>> of <<3>> characters read",
        FIL.accountKey, scanned, numOnAccount))

    ResetCanvas()

    if findText ~= "" then
        DrawFind()
        return
    end

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
    Tile(3, Num(r.stacks), "Stacks",          "")
    Tile(4, Gold(r.gold),  r.goldName,        goldText, goldDelta, T.GOLD)
    Tile(5, Num(r.value),  "Vendor value",    valueText, valueDelta)
    Tile(6, zo_strformat("<<1>>/<<2>>", scanned, numOnAccount), "Characters read",
        (scanned < numOnAccount) and "log in on the rest" or "all read")
    y = y + 86

    -- Still to read: only drawn while something is missing, so a new player sees what to do next.
    local todo = {}
    if #missingChars > 0 then
        todo[#todo + 1] = { cells = { zo_strformat("<<1>> characters", #missingChars),
            "Log in once on each: " .. table.concat(missingChars, ", ") } }
    end
    local coffers = {}
    for _, bag in ipairs(FIL.HouseBankBags()) do
        local collectibleId = GetCollectibleForBag(bag)
        if not acct.shared["housebank_" .. bag] and collectibleId ~= 0 and IsCollectibleUnlocked(collectibleId) then
            coffers[#coffers + 1] = FIL.CollectibleLabel(collectibleId)
        end
    end
    if #coffers > 0 then
        todo[#todo + 1] = { cells = { zo_strformat("<<1>> storage coffers", #coffers),
            "Open each one once in your house: " .. table.concat(coffers, ", ") } }
    end
    if not acct.shared.vault and GetBagSize(BAG_FURNITURE_VAULT) > 0 then
        todo[#todo + 1] = { cells = { "Furniture Vault", "Open it once in any house you own." } }
    end
    local housesRead = 0
    for key in pairs(acct.shared) do
        if key:sub(1, 6) == "house_" then housesRead = housesRead + 1 end
    end
    local housesOwned = GetTotalUnlockedCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_HOUSE)
    if housesRead < housesOwned then
        todo[#todo + 1] = { cells = { "Placed furniture",
            zo_strformat("<<1>> of your <<2>> houses read. Visit the others once to count their furniture.", housesRead, housesOwned) } }
    end
    if #todo > 0 then
        Section("Still to read", "This list gets shorter as you go")
        Table({ { "What", 220, LEFT }, { "How to add it", 700, LEFT } }, todo)
    end

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

    GoldChart(history, r.goldName)

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

    -- Space left: the bank and storage here, each character's bag in the Characters table.
    local spaceRows = {}
    local function addSpace(name, cont)
        if cont and (cont.size or 0) > 0 then
            spaceRows[#spaceRows + 1] = {
                cells = { name, Num(cont.used), Num(cont.size), Num(cont.size - cont.used) },
                colors = { [4] = FreeColor(cont.size, cont.used) },
            }
        end
    end
    addSpace("Bank", acct.shared.bank)
    local coffers = {}
    for key, cont in pairs(acct.shared) do
        if key:sub(1, 10) == "housebank_" then coffers[#coffers + 1] = cont end
    end
    table.sort(coffers, function(a, b) return a.container < b.container end)
    for _, cont in ipairs(coffers) do addSpace(cont.container, cont) end
    addSpace("Furniture Vault", acct.shared.vault)
    Section("Space left", "Coffers and the Furniture Vault update when opened")
    if #spaceRows == 0 then
        NewLabel(0, y, CONTENT_WIDTH, ROW_H, "Fills in the next time each place is read: log in, and open each coffer once.", T.FONT_BODY, T.SUB)
        y = y + ROW_H
    else
        Table({
            { "Place", 400, LEFT }, { "Used", 170, RIGHT }, { "Slots", 170, RIGHT }, { "Free", 180, RIGHT },
        }, spaceRows)
    end

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

    -- Split stacks
    local SPLIT_ROWS = 25
    local split = FIL.SplitStacks()
    local splitRows = {}
    for i, e in ipairs(split) do
        if i > SPLIT_ROWS then break end
        splitRows[#splitRows + 1] = { cells = { e.name, Num(#e.places), Num(e.qty), FIL.PlacesText(e, 8) } }
    end
    Section("Split stacks", (#split > SPLIT_ROWS) and zo_strformat("<<1>> of <<2>>, most places first", SPLIT_ROWS, #split)
        or "The same stackable item kept in more than one place")
    if #splitRows == 0 then
        NewLabel(0, y, CONTENT_WIDTH, ROW_H, "Nothing is split across places. Every stackable item sits in one spot.", T.FONT_BODY, T.SUB)
        y = y + ROW_H
    else
        Table({
            { "Item", 280, LEFT }, { "Places", 80, RIGHT }, { "Total", 90, RIGHT }, { "Where", 470, LEFT },
        }, splitRows)
    end

    -- Gear by set
    local SET_ROWS = 25
    local sets = FIL.Sets()
    local setRows = {}
    for i, e in ipairs(sets) do
        if i > SET_ROWS then break end
        setRows[#setRows + 1] = { cells = { e.name, Num(e.qty), FIL.PlacesText(e, 8) } }
    end
    Section("Gear by set", (#sets > SET_ROWS) and zo_strformat("<<1>> of <<2>> sets. Type a set name in Find for the rest.", SET_ROWS, #sets)
        or "Type a set name in Find to see each piece")
    if #setRows == 0 then
        NewLabel(0, y, CONTENT_WIDTH, ROW_H, "No set pieces read yet.", T.FONT_BODY, T.SUB)
        y = y + ROW_H
    else
        Table({
            { "Set", 300, LEFT }, { "Pieces", 90, RIGHT }, { "Who holds them", 530, LEFT },
        }, setRows)
    end

    -- Characters
    table.sort(r.chars, function(a, b) return a.name < b.name end)
    local charRows = {}
    for _, c in ipairs(r.chars) do
        if c.gone then
            -- Still counted in the totals until the player drops it.
            charRows[#charRows + 1] = { dim = true,
                cells = { c.name, Num(c.carried), "", Num(c.equipped), Gold(c.gold), "Deleted? /ledger forget " .. c.name } }
        else
            charRows[#charRows + 1] = {
                cells  = { c.name, Num(c.carried), FreeText(c.size, c.used), Num(c.equipped), Gold(c.gold), FIL.FormatTime(c.updated) },
                colors = { [3] = FreeColor(c.size, c.used), [5] = T.GOLD, [6] = T.SUB },
            }
        end
    end
    for _, name in ipairs(missingChars) do
        charRows[#charRows + 1] = { dim = true, cells = { name, "", "", "", "", "Not read yet - log in once" } }
    end
    Section("Characters")
    Table({
        { "Character", 230, LEFT }, { "Carried", 90, RIGHT }, { "Bag space", 150, RIGHT }, { "Equipped", 90, RIGHT },
        { r.goldName, 140, RIGHT }, { "Last read", 220, RIGHT },
    }, charRows)

    y = y + 20
    NewLabel(0, y, CONTENT_WIDTH, 20,
        "Other characters show what they held at their last logout. Coffers and the Furniture Vault update when opened, placed furniture when you visit the house.",
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

-- The Find box: redraw a moment after the last key, so typing stays smooth.
function FIL.OnFindChanged(edit)
    local text = zo_strtrim(edit:GetText() or "")
    if text == findText then return end
    findText = text
    EVENT_MANAGER:UnregisterForUpdate("FurysInventoryLedgerFind")
    EVENT_MANAGER:RegisterForUpdate("FurysInventoryLedgerFind", 300, function()
        EVENT_MANAGER:UnregisterForUpdate("FurysInventoryLedgerFind")
        if not SCENE_MANAGER:IsShowing(FIL.SUMMARY_SCENE) then return end
        Draw()
        ZO_Scroll_ResetToTop(FurysInventoryLedgerSummary:GetNamedChild("Body"))
    end)
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
