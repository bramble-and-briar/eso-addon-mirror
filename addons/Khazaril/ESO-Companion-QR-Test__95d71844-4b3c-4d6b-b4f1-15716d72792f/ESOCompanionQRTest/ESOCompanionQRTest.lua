-- ESO Companion QR Test
-- Two modes:
--   Tests:        QR codes of increasing size, to measure what a phone can scan from a TV.
--   Skill export: a looping slideshow of QR codes carrying every skill in the game, to be
--                 filmed with a phone and decoded on the computer.
--
-- Open: automatically a few seconds after each login (chat commands may not work on console).

local ADDON_NAME = "ESOCompanionQRTest"
local SCENE_NAME = "esocQRTest"
local QR = ESOC_QR
local EX = ESOC_SkillExport
local CS = ESOC_CharacterSync
local CPP = ESOC_CPPresets

local sv
local scene, window, titleLabel, infoLabel, bigLabel
local front, back -- two drawing buffers, so a code is never shown half-drawn
local tests, current = {}, 1
local ecc = "L"
local mode = "sync" -- opens on Character sync; LB = skill export, Y = QR tests
local worker -- the running coroutine
local openedThisSession = false
local testKeybinds, exportKeybinds, syncKeybinds, cpKeybinds
local showBanner, guarded -- defined in the status banner section below

-- export state
local export = { chunks = nil, index = 1, paused = false, displayMs = 900, loops = 0 }

---------------------------------------------------------------------------
-- Test payloads
---------------------------------------------------------------------------
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local function toB36(n)
    n = math.floor(n or 0)
    if n <= 0 then return "0" end
    local s = ""
    while n > 0 do
        local d = n % 36
        s = B36:sub(d + 1, d + 1) .. s
        n = math.floor(n / 36)
    end
    return s
end

local function syntheticPayload(n)
    local head = "ESOC|T" .. n .. "|"
    local parts = { head }
    local seed = n * 7919 + 13
    for _ = 1, n - #head do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local d = math.floor(seed / 65536) % 36
        parts[#parts + 1] = B36:sub(d + 1, d + 1)
    end
    return table.concat(parts):sub(1, n)
end

local function characterPayload(maxBytes)
    local out = { "ESOC1" }
    local stats = {}
    pcall(function()
        out[#out + 1] = string.format("c=%s,%s,%s,%s,%s",
            GetUnitName("player"), GetUnitClassId("player"), GetUnitRaceId("player"),
            GetUnitLevel("player"), GetPlayerChampionPointsEarned())
    end)
    pcall(function()
        local worn = {}
        for slot = 0, GetBagSize(BAG_WORN) - 1 do
            local id = GetItemId(BAG_WORN, slot)
            if id and id ~= 0 then
                local link = GetItemLink(BAG_WORN, slot)
                local _, _, _, _, _, setId = GetItemLinkSetInfo(link)
                worn[#worn + 1] = string.format("%s:%s:%s:%s", toB36(slot), toB36(id), toB36(setId or 0), toB36(GetItemTrait(BAG_WORN, slot) or 0))
            end
        end
        out[#out + 1] = "w=" .. table.concat(worn, ".")
        stats.worn = #worn
    end)
    pcall(function()
        local bars = {}
        for _, cat in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
            for slot = 3, 8 do bars[#bars + 1] = toB36(GetSlotBoundId(slot, cat) or 0) end
        end
        out[#out + 1] = "s=" .. table.concat(bars, ".")
    end)
    local head = table.concat(out, ";")
    local items, included, total = {}, 0, 0
    pcall(function()
        for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
            local id = GetItemId(BAG_BACKPACK, slot)
            if id and id ~= 0 then
                total = total + 1
                local count = GetSlotStackSize(BAG_BACKPACK, slot) or 1
                local entry = (count > 1) and (toB36(id) .. "*" .. toB36(count)) or toB36(id)
                if #head + 3 + #table.concat(items, ".") + #entry + 1 > maxBytes then break end
                items[#items + 1] = entry
                included = included + 1
            end
        end
    end)
    local payload = head .. ";i=" .. table.concat(items, ".")
    local note = string.format("Your character: %d worn items, backpack %d of %d stacks included", stats.worn or 0, included, total)
    return payload, note
end

local function buildTests()
    tests = {}
    local maxB = QR.MaxBytes(40, ecc)
    for _, n in ipairs({ 20, 100, 300, 600, 1000, 1500, 2000, 2500 }) do
        if n < maxB then tests[#tests + 1] = { name = n .. " bytes (test data)", data = syntheticPayload(n) } end
    end
    tests[#tests + 1] = { name = maxB .. " bytes (largest possible)", data = syntheticPayload(maxB) }
    local payload, note = characterPayload(maxB)
    tests[#tests + 1] = { name = note, data = payload }
    if current > #tests then current = #tests end
end

---------------------------------------------------------------------------
-- Drawing buffers
---------------------------------------------------------------------------
local QUIET = 4

local function newBuffer(name)
    local panel = WINDOW_MANAGER:CreateControl(name, window, CT_TEXTURE)
    panel:SetColor(1, 1, 1, 1)
    panel:SetAnchor(CENTER, window, CENTER, 120, -30)
    panel:SetDrawLevel(1)
    panel:SetHidden(true)
    return { panel = panel, pool = {}, used = 0 }
end

local function acquireRect(buf)
    buf.used = buf.used + 1
    local c = buf.pool[buf.used]
    if not c then
        c = WINDOW_MANAGER:CreateControl(nil, buf.panel, CT_TEXTURE)
        c:SetColor(0, 0, 0, 1)
        c:SetDrawLevel(2)
        buf.pool[buf.used] = c
    end
    c:SetHidden(false)
    return c
end

-- Merge dark modules into rectangles: horizontal runs, stacked when identical on consecutive rows.
-- Results go into reusable flat arrays (no per-rectangle tables) to keep memory flat on console.
local RX, RY, RW, RH = {}, {}, {}, {}
local activeA, activeB = {}, {}
local function toRects(qr)
    local size, m = qr.size, qr.modules
    local n = 0
    local active, nextActive = activeA, activeB
    for k in pairs(active) do active[k] = nil end
    for y = 0, size - 1 do
        for k in pairs(nextActive) do nextActive[k] = nil end
        local x = 0
        local row = y * size + 1
        while x < size do
            if m[row + x] == 1 then
                local x0 = x
                while x < size and m[row + x] == 1 do x = x + 1 end
                local key = x0 * 1000 + x
                local r = active[key]
                if r then
                    RH[r] = RH[r] + 1
                else
                    n = n + 1
                    RX[n], RY[n], RW[n], RH[n] = x0, y, x - x0, 1
                    r = n
                end
                nextActive[key] = r
            else
                x = x + 1
            end
        end
        active, nextActive = nextActive, active
    end
    return n
end

-- Free memory left over from the last QR code (the console add-on memory budget is small).
local function tidyMemory()
    pcall(collectgarbage, "collect")
end

-- Draw a QR code (yields every 1000 rectangles). The panel stays hidden while drawing, so a
-- half-drawn code is never on screen. Returns module pixel size and rect count.
local function drawInto(buf, qr)
    local n = toRects(qr)
    coroutine.yield()
    buf.panel:SetHidden(true)
    buf.used = 0
    local scale = GetUIGlobalScale()
    local availPx = math.floor(GuiRoot:GetHeight() * 0.72 * scale)
    local modulePx = math.max(1, math.floor(availPx / (qr.size + QUIET * 2)))
    local unit = modulePx / scale
    buf.panel:SetDimensions((qr.size + QUIET * 2) * unit, (qr.size + QUIET * 2) * unit)
    for i = 1, n do
        local c = acquireRect(buf)
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT, buf.panel, TOPLEFT, (RX[i] + QUIET) * unit, (RY[i] + QUIET) * unit)
        c:SetDimensions(RW[i] * unit, RH[i] * unit)
        if i % 1000 == 0 then coroutine.yield() end
    end
    for i = n + 1, #buf.pool do buf.pool[i]:SetHidden(true) end -- leftovers from a bigger code
    tidyMemory()
    return modulePx, n
end

local function showBuffer(buf)
    buf.panel:SetHidden(false)
end

local function setInfo(lines)
    infoLabel:SetText(table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- Worker coroutine, resumed once per frame
---------------------------------------------------------------------------
local frames, longestFrame = 0, 0

local function stopWorker()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "Work")
    worker = nil
end

local function startWorker(fn)
    stopWorker()
    frames, longestFrame = 0, 0
    worker = coroutine.create(fn)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Work", 0, function()
        if not worker then return end
        local t0 = GetGameTimeMilliseconds()
        local ok, err = coroutine.resume(worker)
        local dt = GetGameTimeMilliseconds() - t0
        frames = frames + 1
        if dt > longestFrame then longestFrame = dt end
        if not ok then
            setInfo({ "Error: " .. tostring(err) })
            stopWorker()
        elseif worker and coroutine.status(worker) == "dead" then
            stopWorker()
        end
    end)
end

local function waitUntil(ms)
    while GetGameTimeMilliseconds() < ms do coroutine.yield() end
end

---------------------------------------------------------------------------
-- Tests mode
---------------------------------------------------------------------------
local function showTest(index)
    current = index
    local test = tests[index]
    titleLabel:SetText(string.format("ESO Companion · QR test %d of %d", index, #tests))
    bigLabel:SetText("")
    setInfo({ test.name, "", "Generating..." })
    startWorker(function()
        local startMs = GetGameTimeMilliseconds()
        local qr = QR.Encode(test.data, ecc, { yield = coroutine.yield })
        local modulePx, nRects = drawInto(back, qr)
        showBuffer(back)
        setInfo({
            test.name,
            "",
            string.format("Data: %d bytes", qr.bytes),
            string.format("QR version %d: %d × %d squares", qr.version, qr.size, qr.size),
            string.format("Error correction: %s   Mask: %d", qr.ecc, qr.mask),
            string.format("Square size: %d pixels%s", modulePx, modulePx < 3 and "  (very small!)" or ""),
            string.format("Drawn with %d rectangles", nRects),
            string.format("Took %d ms over %d frames (longest frame %d ms)", GetGameTimeMilliseconds() - startMs, frames, longestFrame),
            "",
            "Point your iPhone camera at the code.",
            "Note: does it scan, and from how far away?",
        })
    end)
end

---------------------------------------------------------------------------
-- Skill export mode
---------------------------------------------------------------------------
local function exportStatus(extra)
    local n = export.chunks and #export.chunks or 0
    bigLabel:SetText(n > 0 and string.format("%d / %d", export.index, n) or "")
    local lines = {
        "Skill data export",
        "",
        "Film this screen with your iPhone (normal video) until the",
        "counter has gone all the way round at least twice.",
        "",
        string.format("Codes: %d   Loop: %d", n, export.loops + 1),
        string.format("Showing each code for %.1f s%s", export.displayMs / 1000, export.paused and "   (PAUSED)" or ""),
        string.format("Longest frame: %d ms", longestFrame),
    }
    if extra then lines[#lines + 1] = "" lines[#lines + 1] = extra end
    setInfo(lines)
end

local function runExport()
    startWorker(function()
        if not export.chunks then
            setInfo({ "Skill data export", "", "Reading every skill in the game..." })
            local linesRead = 0
            local text = EX.Collect(function()
                linesRead = linesRead + 1
                if linesRead % 4 == 0 then
                    setInfo({ "Skill data export", "", string.format("Reading skills... %d skill lines so far", linesRead) })
                    tidyMemory()
                    coroutine.yield()
                end
            end)
            local runId = toB36(GetTimeStamp())
            export.chunks = EX.Chunk(text, 2800, runId)
            export.bytes = #text
            text = nil
            tidyMemory()
            export.index = 1
            export.loops = 0
        end
        while true do
            local chunk = export.chunks[export.index]
            local qr = QR.Encode(chunk, "L", { yield = coroutine.yield })
            drawInto(back, qr)
            while export.paused do coroutine.yield() end
            if export.shownAt then waitUntil(export.shownAt + export.displayMs) end
            showBuffer(back)
            export.shownAt = GetGameTimeMilliseconds()
            exportStatus(string.format("Total data: %d KB", math.floor((export.bytes or 0) / 1024)))
            -- advance
            local nextIndex = export.index % #export.chunks + 1
            if nextIndex == 1 then export.loops = export.loops + 1 end
            export.nextIndex = nextIndex
            coroutine.yield()
            export.index = nextIndex
        end
    end)
end

---------------------------------------------------------------------------
-- Character sync mode: this character as QR codes for the phone app
---------------------------------------------------------------------------
local sync = { chunks = nil, index = 1, paused = false, displayMs = 1500, who = "" }

local function syncStatus()
    local n = sync.chunks and #sync.chunks or 0
    bigLabel:SetText(n > 1 and string.format("%d / %d", sync.index, n) or "")
    setInfo({
        sync.who,
        "",
        "On your phone: ESO Companion > Characters > Scan.",
        n > 1 and "Point the camera at the codes. They change by themselves;" or "Point the camera at the code.",
        n > 1 and "keep pointing until the app says it has them all." or "",
        "",
        string.format("Codes: %d%s", n, sync.paused and "   (PAUSED)" or ""),
        "To sync another character, log in to it.",
    })
end

local function runSync(refresh)
    startWorker(function()
        if refresh or not sync.chunks then
            setInfo({ "Reading your character..." })
            local text, charId = CS.Collect()
            sync.chunks = EX.Chunk(text, 1800, charId, "ESOCC1")
            sync.index = 1
            local name, lvl, cp = "", 0, 0
            pcall(function() name = zo_strformat("<<1>>", GetUnitName("player")) lvl = GetUnitLevel("player") cp = GetUnitChampionPoints("player") end)
            sync.who = string.format("%s (level %d, %d CP)", name, lvl or 0, cp or 0)
            text = nil
            tidyMemory()
        end
        sync.shownAt = nil
        while true do
            local qr = QR.Encode(sync.chunks[sync.index], "L", { yield = coroutine.yield })
            drawInto(back, qr)
            if sync.shownAt then waitUntil(sync.shownAt + sync.displayMs) end
            while sync.paused do coroutine.yield() end
            showBuffer(back)
            sync.shownAt = GetGameTimeMilliseconds()
            syncStatus()
            if #sync.chunks == 1 then return end -- one code: just leave it on screen
            coroutine.yield()
            sync.index = sync.index % #sync.chunks + 1
        end
    end)
end

---------------------------------------------------------------------------
-- CP presets mode: one tap spends all points and slots the main stars
---------------------------------------------------------------------------
local cpState = { index = 1, confirm = false, message = nil, success = false }

-- The CP screen is a proper menu: preset list on the left, one card per Champion tree on the
-- right, and a status box. Every control is anchored to the top-left of cpUI.root, in the
-- 1920 x 1080 gamepad UI space. Built once, on first use.
local cpUI
local TREE_COLOURS = {
    warfare = { 0.27, 0.50, 0.92 },
    fitness = { 0.85, 0.32, 0.27 },
    craft = { 0.36, 0.72, 0.36 },
}
local GOLD = { 0.93, 0.78, 0.42 }

local function buildCPUI()
    local root = WINDOW_MANAGER:CreateControl("ESOCQRTestCP", window, CT_CONTROL)
    root:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    root:SetDimensions(1920, 1080)
    local ui = { root = root, rows = {}, cards = {} }

    local function tex(x, y, w, h, c, a, level)
        local t = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
        t:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
        t:SetDimensions(w, h)
        t:SetColor(c[1], c[2], c[3], a or 1)
        t:SetDrawLevel(level or 1)
        return t
    end
    local function lbl(x, y, font, w, c)
        local l = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
        l:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
        l:SetFont(font)
        if w then l:SetWidth(w) end
        l:SetColor(c[1], c[2], c[3], 1)
        l:SetDrawLevel(5)
        return l
    end
    local WHITE, GREY, DIM = { 1, 1, 1 }, { 0.72, 0.72, 0.72 }, { 0.5, 0.5, 0.5 }

    tex(0, 0, 1920, 1080, { 0.03, 0.03, 0.05 }, 0.93, 0)
    ui.title = lbl(80, 46, "ZoFontGamepad42", nil, WHITE)
    ui.title:SetText("Champion Point presets")
    ui.subtitle = lbl(80, 104, "ZoFontGamepad27", 1760, GREY)
    ui.points = lbl(80, 142, "ZoFontGamepad27", 1760, WHITE)

    -- left: preset list
    local listX, listY, rowH = 80, 230, 70
    lbl(listX, listY - 40, "ZoFontGamepad27", nil, DIM):SetText("PRESETS")
    tex(listX, listY - 6, 440, 2, DIM, 0.6)
    for i = 1, #CPP.presets do
        local y = listY + (i - 1) * rowH
        local row = {
            bg = tex(listX, y, 440, rowH - 8, GOLD, 0.18, 1),
            bar = tex(listX, y, 6, rowH - 8, GOLD, 1, 2),
            label = lbl(listX + 26, y + 14, "ZoFontGamepad34", 400, GREY),
        }
        row.label:SetText(CPP.presets[i].name)
        ui.rows[i] = row
    end

    -- right: chosen preset and three tree cards
    local rightX = 580
    ui.name = lbl(rightX, 182, "ZoFontGamepad42", 1260, GOLD)
    ui.desc = lbl(rightX, 236, "ZoFontGamepad27", 1260, GREY)
    local cardY, cardW, cardH, gap = 296, 400, 524, 30
    for i, key in ipairs({ "warfare", "fitness", "craft" }) do
        local x, colour = rightX + (i - 1) * (cardW + gap), TREE_COLOURS[key]
        tex(x, cardY, cardW, cardH, { 1, 1, 1 }, 0.06, 1)
        tex(x, cardY, cardW, 58, colour, 0.9, 2)
        local card = {
            header = lbl(x + 20, cardY + 10, "ZoFontGamepad34", cardW - 40, WHITE),
            spent = lbl(x + 20, cardY + 72, "ZoFontGamepad27", cardW - 40, GREY),
            slots = {},
            passive = lbl(x + 20, cardY + 362, "ZoFontGamepad27", cardW - 40, GREY),
            warn = lbl(x + 20, cardY + 400, "ZoFontGamepad27", cardW - 40, { 1, 0.62, 0.3 }),
        }
        lbl(x + 20, cardY + 116, "ZoFontGamepad27", nil, DIM):SetText("SLOTTED STARS")
        for s = 1, 4 do
            local y = cardY + 156 + (s - 1) * 52
            card.slots[s] = {
                dot = tex(x + 22, y + 10, 14, 14, colour, 1, 3),
                label = lbl(x + 50, y, "ZoFontGamepad27", cardW - 70, WHITE),
            }
        end
        pcall(function() card.warn:SetMaxLineCount(4) end) -- never spill out of the card
        ui.cards[key] = card
    end

    -- status box above the button strip
    ui.statusBg = tex(rightX, 840, 1260, 120, { 1, 1, 1 }, 0.06, 1)
    ui.statusBar = tex(rightX, 840, 6, 120, GOLD, 1, 2)
    ui.status = lbl(rightX + 26, 856, "ZoFontGamepad27", 1210, WHITE)
    return ui
end

local function colourText(c, text)
    return string.format("|c%02x%02x%02x%s|r", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), text)
end

local function setCPVisible(visible)
    if cpUI then cpUI.root:SetHidden(not visible) end
    titleLabel:SetHidden(visible)
    infoLabel:SetHidden(visible)
    bigLabel:SetHidden(visible)
end

local function showCP()
    stopWorker()
    front.panel:SetHidden(true) -- no QR code on this screen
    if not cpUI then cpUI = buildCPUI() end
    setCPVisible(true)
    local ui, preset = cpUI, CPP.presets[cpState.index]

    for i, row in ipairs(ui.rows) do
        local on = (i == cpState.index)
        row.bg:SetHidden(not on)
        row.bar:SetHidden(not on)
        if on then row.label:SetColor(1, 1, 1, 1) else row.label:SetColor(0.62, 0.62, 0.62, 1) end
    end
    ui.name:SetText(preset.name)
    ui.desc:SetText(preset.desc)
    local who = "this character"
    pcall(function() who = zo_strformat("<<1>>", GetUnitName("player")) end)
    ui.subtitle:SetText("Fills every Champion point and slots the 4 key stars in each tree, for " .. who ..
        ". Made for new characters: points already spent are kept.")

    local summary
    local ok, err = pcall(function()
        cpState.plans, cpState.trees = CPP.Plan(preset)
        summary = CPP.Summary(cpState.plans, cpState.trees)
    end)
    local totalUnspent = 0
    if ok then
        local parts = {}
        for _, s in ipairs(summary) do
            totalUnspent = totalUnspent + s.unspent
            parts[#parts + 1] = colourText(TREE_COLOURS[s.key], s.name) .. "  " .. s.unspent
        end
        ui.points:SetText("Unspent points:   " .. table.concat(parts, "      "))
        for _, s in ipairs(summary) do
            local card = ui.cards[s.key]
            card.header:SetText(s.name)
            card.spent:SetText(s.spent > 0 and ("Spends " .. s.spent .. " of " .. s.unspent .. " points") or "No points to spend")
            for i = 1, 4 do
                local slot = card.slots[i]
                local star = s.slots[i]
                if star then
                    slot.label:SetText(star.name .. "  " .. colourText({ 0.55, 0.55, 0.55 }, star.points))
                    slot.label:SetColor(1, 1, 1, 1)
                    slot.dot:SetHidden(false)
                else
                    slot.label:SetText("empty")
                    slot.label:SetColor(0.45, 0.45, 0.45, 1)
                    slot.dot:SetHidden(true)
                end
            end
            card.passive:SetText(s.passivePoints > 0
                and string.format("+ %d points in %d passive star%s", s.passivePoints, s.passiveStars, s.passiveStars == 1 and "" or "s")
                or "")
            local warn = {}
            if #s.skipped > 0 then warn[#warn + 1] = "Unlocks with more CP: " .. table.concat(s.skipped, ", ") end
            if #s.missing > 0 then warn[#warn + 1] = "Not found in game: " .. table.concat(s.missing, ", ") end
            card.warn:SetText(table.concat(warn, "\n"))
        end
    else
        ui.points:SetText("Could not read your Champion points: " .. tostring(err))
    end

    local text, colour = nil, GOLD
    if cpState.message then
        text = cpState.message
        colour = cpState.success and { 0.45, 0.85, 0.45 } or { 1, 0.62, 0.3 }
    elseif cpState.confirm then
        text = "Press A again to spend the points and slot the stars.\nChanging them later costs gold, like any Champion respec."
    elseif ok and totalUnspent == 0 then
        text, colour = "This character has no unspent Champion points. A will still slot the stars.", { 0.72, 0.72, 0.72 }
    else
        text, colour = "Press A to use the " .. preset.name .. " preset.   X / Y: move up and down the list.", { 0.72, 0.72, 0.72 }
    end
    ui.status:SetText(text)
    ui.status:SetColor(colour[1], colour[2], colour[3], 1)
    ui.statusBar:SetColor(colour[1], colour[2], colour[3], 1)
end

-- New characters must spend their attribute points before the game accepts Champion purchases.
local function attributeHint()
    local ok, n = pcall(GetAttributeUnspentPoints)
    if ok and type(n) == "number" and n > 0 then
        return "\nYou have " .. n .. " unspent attribute point" .. (n == 1 and "" or "s") ..
            ". Spend " .. (n == 1 and "it" or "them") .. " first (Character menu), then try the preset again."
    end
    return ""
end

local function applyCP()
    if not cpState.confirm then
        cpState.confirm, cpState.message = true, nil
        showCP()
        return
    end
    cpState.confirm, cpState.success = false, false
    local ok, sent, reason = pcall(CPP.Apply, cpState.plans, cpState.trees)
    if not ok then
        cpState.message = "Something went wrong: " .. tostring(sent)
    elseif not sent then
        local why = tostring(reason)
        pcall(function() why = GetString("SI_CHAMPIONPURCHASERESULT", reason) end)
        cpState.message = "The game won't allow it right now: " .. why .. attributeHint()
    else
        cpState.message = "Sent to the game... "
    end
    showCP()
end

local function onChampionResult(_, result)
    if mode ~= "cp" then return end
    if result == CHAMPION_PURCHASE_SUCCESS then
        cpState.message, cpState.success = "Done! Points spent and stars slotted.", true
    else
        local why = tostring(result)
        pcall(function() why = GetString("SI_CHAMPIONPURCHASERESULT", result) end)
        cpState.message, cpState.success = "The game refused: " .. why .. attributeHint(), false
    end
    showCP()
end

---------------------------------------------------------------------------
-- Window, scene, keybinds
---------------------------------------------------------------------------
local function createWindow()
    window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCQRTestWindow")
    window:SetAnchorFill(GuiRoot)
    window:SetHidden(true)

    front = newBuffer("ESOCQRTestPanelA")
    back = front -- one buffer: drawing twice doubled memory use on console

    titleLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    titleLabel:SetFont("ZoFontGamepad42")
    titleLabel:SetColor(1, 1, 1, 1)
    titleLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 60, 50)

    infoLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    infoLabel:SetFont("ZoFontGamepad27")
    infoLabel:SetColor(0.9, 0.9, 0.9, 1)
    infoLabel:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 30)
    infoLabel:SetWidth(560)

    bigLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    bigLabel:SetFont("ZoFontGamepad61")
    bigLabel:SetColor(1, 0.85, 0.4, 1)
    bigLabel:SetAnchor(TOPLEFT, infoLabel, BOTTOMLEFT, 0, 40)
end

local function keybindsFor(m)
    if m == "tests" then return testKeybinds elseif m == "export" then return exportKeybinds elseif m == "cp" then return cpKeybinds end
    return syncKeybinds
end

local function startMode()
    infoLabel:SetWidth(560)
    setCPVisible(mode == "cp")
    if mode == "cp" then
        cpState.confirm, cpState.message = false, nil
        showCP()
        return
    end
    front.panel:SetHidden(false)
    if mode == "tests" then
        buildTests()
        showTest(current)
    elseif mode == "export" then
        titleLabel:SetText("ESO Companion · Skill export")
        export.shownAt = nil
        runExport()
    else
        titleLabel:SetText("ESO Companion · Character sync")
        runSync(false)
    end
end

local function setMode(newMode)
    stopWorker()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindsFor(mode))
    mode = newMode
    KEYBIND_STRIP:AddKeybindButtonGroup(keybindsFor(mode))
    startMode()
end

local function refreshKeybinds()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindsFor(mode))
end

local function createScene()
    scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    if IsInGamepadPreferredMode() then
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    else
        scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    end
    scene:AddFragment(ZO_SimpleSceneFragment:New(window))

    local backButton = KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor()
    testKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        backButton,
        { name = "Next test", keybind = "UI_SHORTCUT_PRIMARY", callback = function() showTest(current % #tests + 1) end },
        { name = "Previous test", keybind = "UI_SHORTCUT_SECONDARY", callback = function() showTest((current - 2) % #tests + 1) end },
        {
            name = function() return "Error correction: " .. ecc end,
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function()
                ecc = (ecc == "L") and "M" or "L"
                buildTests()
                refreshKeybinds()
                showTest(current)
            end,
        },
        { name = "Skill export", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() setMode("export") end },
        { name = "Character sync", keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = function() setMode("sync") end },
    }
    syncKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        backButton,
        {
            name = function() return sync.paused and "Resume" or "Pause" end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() sync.paused = not sync.paused refreshKeybinds() syncStatus() end,
        },
        { name = "Refresh", keybind = "UI_SHORTCUT_SECONDARY", callback = function() runSync(true) end },
        { name = "QR tests", keybind = "UI_SHORTCUT_TERTIARY", callback = function() setMode("tests") end },
        { name = "Skill export", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() setMode("export") end },
        { name = "CP presets", keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = function() setMode("cp") end },
    }
    cpKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        backButton,
        {
            name = function() return cpState.confirm and "Confirm" or "Use preset" end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() applyCP() refreshKeybinds() end,
        },
        {
            name = "Up",
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                cpState.index = (cpState.index - 2) % #CPP.presets + 1
                cpState.confirm, cpState.message = false, nil
                refreshKeybinds()
                showCP()
            end,
        },
        {
            name = "Down",
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function()
                cpState.index = cpState.index % #CPP.presets + 1
                cpState.confirm, cpState.message = false, nil
                refreshKeybinds()
                showCP()
            end,
        },
        { name = "Character sync", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() setMode("sync") end },
    }
    exportKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        backButton,
        {
            name = function() return export.paused and "Resume" or "Pause" end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() export.paused = not export.paused refreshKeybinds() exportStatus() end,
        },
        {
            name = "Slower",
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function() export.displayMs = math.min(5000, export.displayMs + 300) exportStatus() end,
        },
        {
            name = "Faster",
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function() export.displayMs = math.max(300, export.displayMs - 300) exportStatus() end,
        },
        { name = "Character sync", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() setMode("sync") end },
    }

    scene:RegisterCallback("StateChange", function(_, newState)
        guarded("showing the screen", function()
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(keybindsFor(mode))
            startMode()
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindsFor(mode))
            stopWorker()
        end
        end)
    end)
end

---------------------------------------------------------------------------
-- Status banner: a plain text line at the top of the screen that does not depend on the
-- scene system. Shows that the addon loaded, and any error, so failures are never silent.
---------------------------------------------------------------------------
local VERSION = "0.6.2"
local banner, bannerLines = nil, {}

showBanner = function(text, isError)
    bannerLines[#bannerLines + 1] = text
    if #bannerLines > 6 then table.remove(bannerLines, 1) end
    pcall(function()
        if not banner then
            local tlw = WINDOW_MANAGER:CreateTopLevelWindow("ESOCQRTestBanner")
            tlw:SetAnchor(TOP, GuiRoot, TOP, 0, 90)
            tlw:SetDimensions(1400, 300)
            tlw:SetDrawLayer(DL_OVERLAY)
            local bg = WINDOW_MANAGER:CreateControl(nil, tlw, CT_TEXTURE)
            bg:SetAnchorFill(tlw)
            bg:SetColor(0, 0, 0, 0.75)
            local label = WINDOW_MANAGER:CreateControl(nil, tlw, CT_LABEL)
            label:SetFont("ZoFontGamepad27")
            label:SetAnchor(TOPLEFT, tlw, TOPLEFT, 20, 12)
            label:SetWidth(1360)
            banner = { tlw = tlw, label = label }
        end
        banner.label:SetText(table.concat(bannerLines, "\n"))
        banner.label:SetColor(isError and 1 or 1, isError and 0.45 or 0.85, isError and 0.4 or 0.4, 1)
        banner.tlw:SetHeight((banner.label:GetTextHeight() or 200) + 24)
        banner.tlw:SetHidden(false)
    end)
    pcall(function() d("[ESO Companion] " .. text) end)
end

local hadError = false
guarded = function(step, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        hadError = true
        showBanner(string.format("ERROR in %s: %s", step, tostring(err)), true)
    end
    return ok
end

local function open()
    guarded("opening the screen", function()
        if not scene then createScene() end
        SCENE_MANAGER:Show(SCENE_NAME)
    end)
    -- check it actually appeared
    zo_callLater(function()
        local showing = false
        pcall(function() showing = SCENE_MANAGER:IsShowing(SCENE_NAME) end)
        if showing then
            showBanner("ESO Companion is open. Press B to close it.")
            if not hadError then
                zo_callLater(function() pcall(function() banner.tlw:SetHidden(true) end) end, 8000)
            end
        else
            showBanner("The test screen did not open.", true)
        end
    end, 1500)
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
-- Always opens once per session after login: chat commands don't work for addons on
-- Xbox, so this is the only reliable way in. Close it with B.
local function onPlayerActivated()
    if not openedThisSession then
        openedThisSession = true
        showBanner("ESO Companion QR Test " .. VERSION .. " loaded. Opening the test screen in 3 seconds...")
        zo_callLater(open, 3000)
    end
end

local function onLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    -- Register for login first, so even if a later step fails the banner still reports it.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
    guarded("checking files", function()
        if not ESOC_QR then error("QREncode.lua did not load") end
        if not ESOC_SkillExport then error("SkillExport.lua did not load") end
        if not ESOC_CharacterSync then error("CharacterSync.lua did not load") end
        if not ESOC_CPPresets then error("CPPresets.lua did not load") end
        if not ESOC_WritStock then error("WritStock.lua did not load") end
    end)
    guarded("loading settings", function()
        -- Version 2 discards the old saved "auto-open off" setting from 0.2.0 and earlier.
        sv = ZO_SavedVars:NewAccountWide("ESOCompanionQRTest_SV", 2, nil, {})
    end)
    guarded("hiding writ stock", function()
        local hooked = ESOC_WritStock.Init(sv)
        if #hooked < 3 then
            showBanner("Writ stock filter only partly active (" .. table.concat(hooked, ", ") .. ")", true)
        end
    end)
    guarded("creating the window", createWindow)
    pcall(function() EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHAMPION_PURCHASE_RESULT, onChampionResult) end)
    pcall(function()
        SLASH_COMMANDS["/esocqr"] = open
        SLASH_COMMANDS["/esocskills"] = function()
            open()
            if mode ~= "export" then setMode("export") end
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onLoaded)
