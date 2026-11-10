-- ESO Companion (add-on folder and saved data keep the old ESOCompanionQRTest name)
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
local ST = ESOC_Storage

local sv
local scene, window, titleLabel, infoLabel, bigLabel
local front, back -- two drawing buffers, so a code is never shown half-drawn
local tests, current = {}, 1
local ecc = "L"
local mode = "sync" -- opens on Character sync; LB = skill export, Y = storage sync
local worker -- the running coroutine
local openedThisSession = false
local testKeybinds, exportKeybinds, syncKeybinds, storeKeybinds
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
-- Storage sync mode: bank, craft bag and recorded house chests, for item search on the phone
---------------------------------------------------------------------------
local store = { chunks = nil, index = 1, paused = false, displayMs = 1200 }

local function storeStatus()
    local n = store.chunks and #store.chunks or 0
    local chests = ST.ChestCount()
    bigLabel:SetText(n > 1 and string.format("%d / %d", store.index, n) or "")
    setInfo({
        "Bank" .. (HasCraftBagAccess and HasCraftBagAccess() and ", craft bag" or "") .. string.format(" and %d house chest%s", chests, chests == 1 and "" or "s"),
        "",
        "On your phone: ESO Companion > Items > Scan.",
        "Point the camera at the codes until the app says it has them all.",
        "",
        "House chests are recorded when you open them in your house.",
        "Open each one once, then sync again.",
        "",
        string.format("Codes: %d%s", n, store.paused and "   (PAUSED)" or ""),
    })
end

local function runStore(refresh)
    startWorker(function()
        if refresh or not store.chunks then
            setInfo({ "Reading your bank and storage..." })
            local text, account = ST.Collect()
            store.chunks = EX.Chunk(text, 1800, ((account or ""):gsub("[^%w_]", "")), "ESOCB1")
            store.index = 1
            text = nil
            tidyMemory()
        end
        store.shownAt = nil
        while true do
            local qr = QR.Encode(store.chunks[store.index], "L", { yield = coroutine.yield })
            drawInto(back, qr)
            if store.shownAt then waitUntil(store.shownAt + store.displayMs) end
            while store.paused do coroutine.yield() end
            showBuffer(back)
            store.shownAt = GetGameTimeMilliseconds()
            storeStatus()
            if #store.chunks == 1 then return end
            coroutine.yield()
            store.index = store.index % #store.chunks + 1
        end
    end)
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
    if m == "tests" then return testKeybinds elseif m == "export" then return exportKeybinds elseif m == "store" then return storeKeybinds end
    return syncKeybinds
end

local function startMode()
    infoLabel:SetWidth(560)
    front.panel:SetHidden(false)
    if mode == "tests" then
        buildTests()
        showTest(current)
    elseif mode == "store" then
        titleLabel:SetText("ESO Companion · Storage sync")
        runStore(true)
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
        { name = "Storage sync", keybind = "UI_SHORTCUT_TERTIARY", callback = function() setMode("store") end },
        { name = "Skill export", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() setMode("export") end },
    }
    storeKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        backButton,
        {
            name = function() return store.paused and "Resume" or "Pause" end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() store.paused = not store.paused refreshKeybinds() storeStatus() end,
        },
        { name = "Refresh", keybind = "UI_SHORTCUT_SECONDARY", callback = function() runStore(true) end },
        { name = "QR tests", keybind = "UI_SHORTCUT_TERTIARY", callback = function() setMode("tests") end },
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
local VERSION = "0.9.0"
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
            showBanner("The ESO Companion screen did not open.", true)
        end
    end, 1500)
end

-- Open straight onto one screen ("sync", "store", "export" or "tests").
local function openMode(m)
    guarded("opening " .. tostring(m), function()
        local showing = false
        pcall(function() showing = scene and SCENE_MANAGER:IsShowing(SCENE_NAME) end)
        if showing then
            if mode ~= m then setMode(m) end
        else
            mode = m
            open()
        end
    end)
end

---------------------------------------------------------------------------
-- Settings > Add-Ons > ESO Companion (needs LibHarvensAddonSettings): a button for each screen,
-- and whether to open at login. Chat commands don't work for add-ons on Xbox, so this is the way in.
---------------------------------------------------------------------------
local settingsMade = false
local function createSettings()
    if settingsMade or not sv then return false end
    local LHAS = LibHarvensAddonSettings
    if not LHAS or not LHAS.AddAddon then return false end
    settingsMade = true
    local panel = LHAS:AddAddon("ESO Companion", { allowDefaults = false })
    -- Leave the Settings menu first, then open the screen once that has finished.
    local function go(m)
        return function()
            pcall(function() SCENE_MANAGER:ShowBaseScene() end)
            zo_callLater(function() openMode(m) end, 300)
        end
    end
    panel:AddSettings({
        { type = LHAS.ST_SECTION, label = "Open" },
        { type = LHAS.ST_BUTTON, label = "Character sync", buttonText = "Open",
          tooltip = "Codes for this character: gear with stats, skill bars, Champion stars and backpack.", clickHandler = go("sync") },
        { type = LHAS.ST_BUTTON, label = "Storage sync", buttonText = "Open",
          tooltip = "Codes for your bank, craft bag and the house chests you have opened.", clickHandler = go("store") },
        { type = LHAS.ST_BUTTON, label = "Skill export", buttonText = "Open",
          tooltip = "Every skill in the game as a slideshow of codes, for the app's skill list.", clickHandler = go("export") },
        { type = LHAS.ST_BUTTON, label = "QR size tests", buttonText = "Open",
          tooltip = "Codes of increasing size, to see what your phone can read from the TV.", clickHandler = go("tests") },
        { type = LHAS.ST_SECTION, label = "Start-up" },
        { type = LHAS.ST_CHECKBOX, label = "Open at login", default = false,
          tooltip = "Open Character sync automatically each time you log in.",
          getFunction = function() return sv.openAtLogin == true end,
          setFunction = function(v) sv.openAtLogin = v and true or nil end },
    })
    return true
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
-- Opens from Settings > Add-Ons > ESO Companion. It only opens by itself at login if you turn
-- "Open at login" on, or if LibHarvensAddonSettings isn't installed (then there's no other way in).
local function onPlayerActivated()
    if openedThisSession then return end
    openedThisSession = true
    local hasSettings = settingsMade or guarded("adding the settings page", createSettings) and settingsMade
    if not hasSettings then
        showBanner("ESO Companion " .. VERSION .. ": install LibHarvensAddonSettings to open it from Settings > Add-Ons. Opening now...")
        zo_callLater(open, 3000)
    elseif sv and sv.openAtLogin then
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
        if not ESOC_Storage then error("Storage.lua did not load") end
    end)
    guarded("loading settings", function()
        -- Version 2 discards the old saved "auto-open off" setting from 0.2.0 and earlier.
        sv = ZO_SavedVars:NewAccountWide("ESOCompanionQRTest_SV", 2, nil, {})
    end)
    guarded("recording house chests", function() ESOC_Storage.Init(sv) end)
    guarded("creating the window", createWindow)
    guarded("adding the settings page", createSettings)
    pcall(function()
        SLASH_COMMANDS["/esocqr"] = open
        SLASH_COMMANDS["/esocskills"] = function()
            open()
            if mode ~= "export" then setMode("export") end
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onLoaded)
