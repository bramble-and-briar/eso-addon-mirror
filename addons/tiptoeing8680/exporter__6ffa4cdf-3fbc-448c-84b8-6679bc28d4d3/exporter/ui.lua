-- ui.lua: window, frame player, /export command and keybind for the exporter.
--
-- Usage (chat): /export                          only sections that changed since your last export
--               /export all                      every section, one session (scan once)
--               /export <section>                profile|research|traits|recipes|motifs|backpack|bank|craftbag|house
--               /export stop | mem | sizes | chat on|off
--               /export set ecc|chars|height|interval|mask <n>
-- QR codes are only drawn after an explicit command or keybind press, never automatically.

CompanionExport = CompanionExport or {}

local ADDON_NAME = "exporter"
local WINDOW_NAME = "CompanionExportWindow"
local PREP_UPDATE = "CompanionExport_Prep"
local CYCLE_UPDATE = "CompanionExport_Cycle"
local Collect = CompanionExport.Collect

CompanionExport.settings = {
    ecLevel = 2,        -- QR error correction: 1=L 2=M 3=Q 4=H
    maxBodyChars = 450, -- ~300 B per frame: readable at couch distance on PS5 (spike results)
    targetHeight = 600,
    intervalMs = 400,
    quietModules = 4,
    fixedMask = 0,      -- one QR mask: ~14 ms/frame on PS5 (no hitch); -1 = search all 8
}

local state = { running = false, last = "changes" }

--- Adler-32 of a byte array (addition/modulo only, no bit operations).
function CompanionExport.Checksum(bytes)
    local a, b = 1, 0
    for i = 1, #bytes do
        a = (a + bytes[i]) % 65521
        b = (b + a) % 65521
    end
    return string.format("%d:%d", b * 65536 + a, #bytes)
end

local function sv()
    CompanionExport_SV = CompanionExport_SV or {}
    if CompanionExport_SV.verbose == nil then CompanionExport_SV.verbose = false end
    CompanionExport_SV.sent = CompanionExport_SV.sent or {}
    CompanionExport_SV.chests = CompanionExport_SV.chests or {}
    return CompanionExport_SV
end

--- Chat output: `important` messages always show; details only with "Show details in chat".
local function say(msg, important)
    if important or sv().verbose then d("[Export] " .. msg) end
end
CompanionExport.Say = say

--- Key under which a section's last-sent checksum is stored (per character or per account).
local function sentKey(code)
    if Collect.ACCOUNT_SECTIONS[code] then return "account:" .. code end
    return GetCurrentCharacterId() .. ":" .. code
end

local function platform()
    return IsConsoleUI() and "console" or "pc"
end

local function ensureWindow()
    if state.window then return state.window end
    local win = WINDOW_MANAGER:CreateTopLevelWindow(WINDOW_NAME)
    win:SetClampedToScreen(true)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetDimensions(900, 900)
    win:SetHidden(true)
    local backdrop = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Backdrop", win, CT_BACKDROP)
    backdrop:SetAnchorFill(win)
    backdrop:SetCenterColor(0, 0, 0, 0.9)
    backdrop:SetEdgeColor(0, 0, 0, 0)
    local canvas = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Canvas", win, CT_TEXTURE)
    canvas:SetAnchor(TOP, win, TOP, 0, 20)
    local label = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Label", win, CT_LABEL)
    label:SetFont("ZoFontGamepad42")
    label:SetColor(1, 1, 1, 1)
    label:SetAnchor(TOP, canvas, BOTTOM, 0, 16)
    state.window, state.canvas, state.label = win, canvas, label
    return win
end

local function setStatus(text)
    ensureWindow()
    state.label:SetText(text)
end

function CompanionExport.Stop()
    EVENT_MANAGER:UnregisterForUpdate(PREP_UPDATE)
    EVENT_MANAGER:UnregisterForUpdate(CYCLE_UPDATE)
    state.running = false
    if state.window then state.window:SetHidden(true) end
end

--- Build frames for the given section codes (one shared session id).
--- changedOnly: skip sections whose checksum equals the last one shown. `record`: remember the
--- checksums of included sections (false for /export sizes). printSizes: always print per-section
--- sizes (/export sizes); otherwise they only show with chat details on.
--- Returns frames, labels, included codes.
function CompanionExport.BuildFrames(codes, changedOnly, record, printSizes)
    local s = CompanionExport.settings
    local store = sv()
    local session = CompanionExport.Frame.newSession()
    local frames, labels, included = {}, {}, {}
    for _, code in ipairs(codes) do
        local name, collector = Collect.SECTIONS[code][1], Collect.SECTIONS[code][2]
        local bytes, records, note = collector()
        local key, sum = sentKey(code), CompanionExport.Checksum(bytes)
        if changedOnly and store.sent[key] == sum then
            -- unchanged since last shown: skip
        else
            if record then store.sent[key] = sum end
            included[#included + 1] = code
            local sectionFrames, chars = CompanionExport.Frame.build(session, code, bytes, s.maxBodyChars)
            say(string.format("%s %-9s records=%d bytes=%d chars=%d frames=%d%s", platform(), name,
                records, #bytes, chars, #sectionFrames, note and (" (" .. note .. ")") or ""), printSizes)
            for i, f in ipairs(sectionFrames) do
                frames[#frames + 1] = f
                labels[#labels + 1] = string.format("%s %d/%d", name, i, #sectionFrames)
            end
        end
    end
    return frames, labels, included
end
local buildFrames = CompanionExport.BuildFrames

local function startCycle(labels)
    local s = CompanionExport.settings
    local index = 0
    local function showNext()
        index = index % #state.matrices + 1
        local px = CompanionExport.Render.draw(state.canvas, state.matrices[index], s.targetHeight, s.quietModules)
        state.window:SetDimensions(px + 40, px + 120)
        setStatus(string.format("%s   ·   %d of %d", labels[index], index, #state.matrices))
    end
    showNext()
    EVENT_MANAGER:RegisterForUpdate(CYCLE_UPDATE, s.intervalMs, showNext)
end

function CompanionExport.Start(which)
    CompanionExport.Stop()
    ensureWindow()
    local codes, changedOnly = nil, false
    if which == "all" then
        codes = Collect.ALL_ORDER
    elseif which == "changes" then
        codes, changedOnly = Collect.ALL_ORDER, true
    else
        for code, entry in pairs(Collect.SECTIONS) do
            if entry[1] == which then codes = { code } end
        end
        if not codes then
            say("unknown section: " .. tostring(which), true)
            return
        end
    end
    state.last = which
    local frames, labels = buildFrames(codes, changedOnly, true)
    if #frames == 0 then
        state.window:SetHidden(true)
        say("Nothing changed since your last export. Use 'Export everything' to resend.", true)
        return
    end
    local s = CompanionExport.settings
    CompanionExport_qrencode_fixed_mask = (s.fixedMask >= 0) and s.fixedMask or nil
    state.matrices, state.running = {}, true
    state.window:SetHidden(false)

    local i, slowest, started = 0, 0, GetGameTimeMilliseconds()
    EVENT_MANAGER:RegisterForUpdate(PREP_UPDATE, 0, function()
        i = i + 1
        local t0 = GetGameTimeMilliseconds()
        local ok, matrix = CompanionExport_qrencode.qrcode(frames[i], s.ecLevel)
        slowest = math.max(slowest, GetGameTimeMilliseconds() - t0)
        if not ok then
            CompanionExport.Stop()
            say("QR encode failed: " .. tostring(matrix), true)
            return
        end
        state.matrices[i] = matrix
        setStatus(string.format("preparing %d/%d", i, #frames))
        if i == #frames then
            EVENT_MANAGER:UnregisterForUpdate(PREP_UPDATE)
            say(string.format("%d frames ready in %d ms (slowest %d ms).",
                #frames, GetGameTimeMilliseconds() - started, slowest))
            startCycle(labels)
        end
    end)
end

function CompanionExport.Toggle()
    if not CompanionExport.IsAllowed() then return end
    if state.running then CompanionExport.Stop() else CompanionExport.Start(state.last) end
end

local function printMemory()
    local m = CompanionExport_MemMarks or {}
    if m.begin and m.loaded then
        d(string.format("[Export] %s load footprint ~%.0f KB (QR library ~%.0f KB)", platform(),
            m.loaded - m.begin, (m.afterVendor or m.begin) - m.begin))
    end
    if GetTotalUserAddOnMemoryPoolCapacityMB then
        local cap = GetTotalUserAddOnMemoryPoolCapacityMB()
        if cap and cap > 0 then
            d(string.format("[Export] all add-ons: %.2f MB used of %.0f MB limit", GetTotalUserAddOnMemoryPoolUsageMB() or 0, cap))
        end
    end
end

local SETTABLE = { ecc = "ecLevel", chars = "maxBodyChars", height = "targetHeight", interval = "intervalMs", mask = "fixedMask" }

local function onSlash(args)
    local words = {}
    for w in string.gmatch(args or "", "%S+") do words[#words + 1] = string.lower(w) end
    local cmd = words[1] or "changes"
    if cmd == "stop" then
        CompanionExport.Stop()
    elseif cmd == "mem" then
        printMemory()
    elseif cmd == "sizes" then
        buildFrames(Collect.ALL_ORDER, false, false, true) -- prints per-section sizes, shows no codes
    elseif cmd == "chat" then
        if words[2] == "on" or words[2] == "off" then sv().verbose = (words[2] == "on") end
        say("details in chat: " .. (sv().verbose and "on" or "off"), true)
    elseif cmd == "set" then
        local key, value = SETTABLE[words[2] or ""], tonumber(words[3] or "")
        if key and value then
            CompanionExport.settings[key] = value
            d(string.format("[Export] %s = %d", key, value))
        else
            d("[Export] usage: /export set ecc|chars|height|interval|mask <number>")
        end
    else
        CompanionExport.Start(cmd)
    end
end

-- House chests: save contents when one of YOUR house's storage chests is opened, and again on
-- close (to catch deposits/withdrawals made while it was open).
local function onOpenBank(_, bankBag)
    if Collect.snapshotChest(bankBag, sv()) then state.openChest = bankBag end
end

local function onCloseBank()
    if state.openChest then
        local index = Collect.snapshotChest(state.openChest, sv())
        if index then say(string.format("Storage chest %d saved for your next export.", index)) end
        state.openChest = nil
    end
end

--- Settings > Add-Ons > Companion Exporter: buttons, so nothing has to be typed on a controller.
local function buildSettingsPanel()
    local LHAS = LibHarvensAddonSettings
    if not LHAS then return end
    local panel = LHAS:AddAddon("Companion Exporter", { allowDefaults = false })
    if not panel then return end
    panel:AddSetting({ type = LHAS.ST_LABEL, label = "Show your data as QR codes for the Companion app." })
    panel:AddSetting({
        type = LHAS.ST_BUTTON, label = "Export changes", buttonText = "Export changes",
        tooltip = "Only sections that changed since your last export (usually 1-2 codes).",
        clickHandler = function() CompanionExport.Start("changes") end,
    })
    panel:AddSetting({
        type = LHAS.ST_BUTTON, label = "Export everything", buttonText = "Export everything",
        tooltip = "Every section, e.g. for a new phone or if you skipped a scan.",
        clickHandler = function() CompanionExport.Start("all") end,
    })
    panel:AddSetting({
        type = LHAS.ST_BUTTON, label = "Hide codes", buttonText = "Hide",
        clickHandler = function() CompanionExport.Stop() end,
    })
    panel:AddSetting({
        type = LHAS.ST_CHECKBOX, label = "Show details in chat",
        tooltip = "Off: only errors and 'nothing changed'. On: section sizes, timings, chests saved.",
        getFunction = function() return sv().verbose end,
        setFunction = function(value) sv().verbose = value end,
        default = false,
    })
end

local function onAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    sv()
    if not CompanionExport.IsAllowed() then return end
    ZO_CreateStringId("SI_BINDING_NAME_COMPANION_EXPORT_TOGGLE", "Export: show/hide QR codes")
    SLASH_COMMANDS["/export"] = onSlash
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Bank", EVENT_OPEN_BANK, onOpenBank)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "BankClose", EVENT_CLOSE_BANK, onCloseBank)
    buildSettingsPanel()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)

if CompanionExport_MemMarks then
    CompanionExport_MemMarks.loaded = collectgarbage("count")
end
