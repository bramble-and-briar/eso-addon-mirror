-- ChimersRecall: independent per-instance furnishing state snapshots.
-- ESO id64 values must never be converted with tonumber or persisted as numbers.
local ChimersRecall = {}
local addon = ChimersRecall
local NAME, UPDATE = "ChimersRecall", "ChimersRecallRestore"

local VERSION = "1.1.0"
local HOUSE_SCHEMA = 3
local DEFAULT_PRESET = "default"
local MAX_ATTEMPTS = 3
-- The queue sends at most one request per pace interval; the pace is a saved
-- setting so a large house can be slowed down without editing the add-on.
local DEFAULT_PACE_MS, PACE_MIN, PACE_MAX = 350, 100, 5000
-- Scanning is spread over frames with a small work budget per frame, so a large
-- house never stalls a single frame. The queue then runs at the pace.
local SCAN_TICK_MS, SCAN_BUDGET_MS = 10, 3
-- An accepted request can take a moment to show up in a readback. Waiting is
-- cheaper than resending, and resending is what risks a flood kick.
local PENDING_GRACE_MS = 1400
local AUTO_TICK_MS, AUTO_RESTORE_DELAY_MS = 250, 2500
-- Conservative world-unit radius for the opt-in position fallback. A wrong
-- match changes the wrong furnishing, so close-but-not-nearest is refused.
local MATCH_RADIUS = 250
local LOG_LIMIT = 100
local SESSION_START = GetGameTimeMilliseconds()

local job        -- restore in progress
local scanJob    -- scan in progress (save, restore planning, final readback)
local autoJob    -- pending automatic restore
local activeMode = "restore"
local requestLog = {}

local function now()
    return GetGameTimeMilliseconds()
end

local function printMessage(message)
    -- System messages go through the chat router like vanilla UI messages, so they
    -- respect the player's chat settings and stay visible on console. d() is a
    -- debug utility and can be suppressed by the player or another add-on.
    CHAT_ROUTER:AddSystemMessage("|c88CCFF[ChimersRecall]|r " .. message)
end

local function integer(value, minimum)
    return type(value) == "number" and value == value and value < math.huge
        and value >= minimum and value == math.floor(value)
end

-- ===== settings =====

local function ensureSettings()
    local vars = addon.savedVars
    vars.houses = vars.houses or {}
    vars.settings = vars.settings or {}
    local settings = vars.settings
    if not integer(settings.paceMs, PACE_MIN) then settings.paceMs = DEFAULT_PACE_MS end
    if settings.paceMs > PACE_MAX then settings.paceMs = PACE_MAX end
    if type(settings.matchByPosition) ~= "boolean" then settings.matchByPosition = false end
    if type(settings.autoRestore) ~= "boolean" then settings.autoRestore = false end
    if type(settings.logRequests) ~= "boolean" then settings.logRequests = false end
    -- Where the player dragged the progress bar. Absent means the default place
    -- above the chat window; a damaged value is dropped rather than trusted.
    local position = settings.barPosition
    if position ~= nil and (type(position) ~= "table" or type(position.x) ~= "number"
        or type(position.y) ~= "number") then
        settings.barPosition = nil
    end
    return settings
end

local function settings()
    return ensureSettings()
end

local function pace()
    return settings().paceMs
end

-- Waits between rejection retries, in ticks: 2 then 4, so at the default 350 ms
-- pace that is 700 ms then 1400 ms.
local function backoffTicks(attempt)
    return math.floor(2 ^ attempt + 0.5)
end

local function graceTicks()
    return math.max(1, math.ceil(PENDING_GRACE_MS / pace()))
end

local function logRequest(entry, code)
    if not settings().logRequests then return end
    requestLog[#requestLog + 1] = { at = now(), key = entry.key, name = entry.name,
        state = entry.saved and entry.saved.state, result = tostring(code) }
    while #requestLog > LOG_LIMIT do table.remove(requestLog, 1) end
end

-- ===== house context and schema =====

local function context()
    local houseId = GetCurrentZoneHouseId()
    if not integer(houseId, 1) then return nil, "This action is only available inside a player house." end
    if type(GetCurrentHousePreviewTemplateId) == "function"
        and GetCurrentHousePreviewTemplateId() ~= 0 then
        return nil, "House previews cannot be saved or restored."
    end
    local owner = GetCurrentHouseOwner()
    if type(owner) ~= "string" then return nil, "The house owner is unavailable. Try again once the house has loaded." end
    owner = owner:match("^%s*(.-)%s*$")
    if owner == "" then return nil, "The house owner is unavailable. Try again once the house has loaded." end
    return { owner = string.lower(owner), ownerDisplayName = owner,
        houseId = houseId, houseKey = tostring(houseId), world = GetWorldName() }
end

local function sameContext(a, b)
    return b ~= nil and a.owner == b.owner and a.houseId == b.houseId and a.world == b.world
end

local function commandContext()
    local ctx, reason = context()
    if not ctx then printMessage(reason) end
    return ctx
end

local function instanceKey(id)
    local key = Id64ToString(id)
    if type(key) ~= "string" or not key:match("^%d+$") then
        return nil
    end
    return key
end

-- A restore needs only the furniture data ID and the exact state index per
-- instance, plus coordinates when position matching was on. Schema 3 dropped the
-- furniture names, state counts and instance count that older schemas stored:
-- nothing read them back, and the live house answers all three.
local function migratePreset(snapshot)
    if type(snapshot) ~= "table" then return nil end
    local items = {}
    for key, item in pairs(snapshot.items or {}) do
        if type(key) == "string" and type(item) == "table"
            and integer(item.furnitureDataId, 0) and integer(item.state, 0) then
            local kept = { furnitureDataId = item.furnitureDataId, state = item.state }
            if type(item.x) == "number" and type(item.y) == "number" and type(item.z) == "number" then
                kept.x, kept.y, kept.z = item.x, item.y, item.z
            end
            items[key] = kept
        end
    end
    return { savedAt = snapshot.savedAt, items = items, label = snapshot.label }
end

local function migrateHouse(house)
    if type(house) ~= "table" then return nil end
    if house.schemaVersion == HOUSE_SCHEMA then return house end
    if house.schemaVersion ~= 1 and house.schemaVersion ~= 2 then return nil end
    if house.schemaVersion == 1 then
        local preset = migratePreset(house)
        if not preset then return nil end
        return { schemaVersion = HOUSE_SCHEMA, defaultPreset = DEFAULT_PRESET,
            presets = { [DEFAULT_PRESET] = preset } }
    end
    local presets = {}
    for name, preset in pairs(house.presets or {}) do presets[name] = migratePreset(preset) end
    return { schemaVersion = HOUSE_SCHEMA, defaultPreset = house.defaultPreset,
        presets = presets, previous = house.previous and migratePreset(house.previous) or nil }
end

-- Returns the house table, or nil plus true when the stored format is not one
-- this version understands. Never rewrites an unsupported house.
local function houseFor(ctx, create)
    local ownerHouses = addon.savedVars.houses[ctx.owner]
    if not ownerHouses then
        if not create then return nil end
        ownerHouses = {}
        addon.savedVars.houses[ctx.owner] = ownerHouses
    end
    local house = ownerHouses[ctx.houseKey]
    if house then
        if type(house) ~= "table" then return nil, true end
        if house.schemaVersion == HOUSE_SCHEMA then return house end
        local migrated = migrateHouse(house)
        if not migrated then return nil, true end
        ownerHouses[ctx.houseKey] = migrated
        return migrated
    end
    if not create then return nil end
    -- The owner, house and world are already the keys this record is stored under,
    -- so repeating them here would only cost space.
    house = { schemaVersion = HOUSE_SCHEMA, presets = {} }
    ownerHouses[ctx.houseKey] = house
    return house
end

local function validPreset(preset)
    return type(preset) == "table" and type(preset.items) == "table"
end

-- The instance count is the size of the item table; storing it as well would be a
-- second copy of the same fact, free to drift.
local function presetSize(preset)
    local size = 0
    if type(preset) == "table" then
        for _ in pairs(preset.items or {}) do size = size + 1 end
    end
    return size
end

-- The preset auto-restore applies is chosen per house, so it is looked up from
-- the house being entered. A house with no such preset chosen has nothing to
-- restore, and the account-wide switch is ignored there instead of falling back
-- to a default name that does not exist.
local function autoPresetName(house)
    if type(house) ~= "table" then return nil end
    local name = house.defaultPreset
    if type(name) ~= "string" then return nil end
    if not validPreset((house.presets or {})[name]) then return nil end
    return name
end

local function layoutName(text, fallback, existing)
    local name = string.lower((text or ""):match("^%s*(.-)%s*$"))
    if name == "" then return fallback end
    if existing and existing[name] then return name end
    name = name:gsub("%s+", "")
    if #name > 32 or not name:match("^[%w][%w_%-%.]*$") then return nil end
    return name
end

local INVALID_LAYOUT_NAME = "Use up to 32 letters, numbers, hyphens, underscores or periods. Spaces are removed."

-- ===== scanning =====

local function scanPosition(id)
    local getter = HousingEditorGetFurnitureWorldPosition
    if type(getter) ~= "function" then return nil end
    local x, y, z = getter(id)
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    return x, y, z
end

local function beginScan(ctx, purpose, onDone)
    activeMode = purpose
    return { ctx = ctx, purpose = purpose, onDone = onDone, previous = nil,
        result = {} }
end

-- Returns true when the enumeration finished, false when the frame budget ran out.
local function scanChunk(scan)
    local deadline = now() + SCAN_BUDGET_MS
    while true do
        local id = GetNextPlacedHousingFurnitureId(scan.previous)
        if id == nil then return true end
        local key = instanceKey(id)
        if not key then return nil, "ESO returned an invalid furniture instance ID." end
        if key == "0" then return true end
        if scan.result[key] then return nil, "The furniture iterator repeated an instance ID; scan aborted." end
        local name, _, dataId = GetPlacedHousingFurnitureInfo(id)
        local count = GetPlacedHousingFurnitureNumObjectStates(id)
        if type(name) ~= "string" or name == "" or not integer(dataId, 0)
            or not integer(count, 0) then
            return nil, "Furniture information is unavailable; scan aborted."
        end
        local state
        if count > 1 then
            state = GetPlacedHousingFurnitureCurrentObjectStateIndex(id)
            if not integer(state, 0) or state >= count then
                return nil, "Invalid interactive state for " .. name .. "; scan aborted."
            end
        end
        local x, y, z = scanPosition(id)
        scan.result[key] = { id = id, name = name, furnitureDataId = dataId,
            numStates = count, state = state, x = x, y = y, z = z }
        scan.previous = id
        if now() >= deadline then return false end
    end
end

local function presetFromLive(live, label)
    -- Coordinates are three numbers per instance and only position matching reads
    -- them, so they are recorded only while that setting is on.
    local wantPositions = settings().matchByPosition
    local preset = { savedAt = GetTimeStamp(), items = {}, label = label }
    for key, item in pairs(live) do
        if item.numStates > 1 then
            local kept = { furnitureDataId = item.furnitureDataId, state = item.state }
            if wantPositions and type(item.x) == "number" then
                kept.x, kept.y, kept.z = item.x, item.y, item.z
            end
            preset.items[key] = kept
        end
    end
    return preset
end

local function compatible(saved, liveItem)
    return type(saved) == "table" and liveItem and liveItem.numStates > 1
        and saved.furnitureDataId == liveItem.furnitureDataId
        and integer(saved.state, 0) and saved.state < liveItem.numStates
end

-- ===== saved size =====

local function estimateBytes(value)
    local total, budget = 0, 250000
    local function walk(current, depth)
        if budget <= 0 or depth > 10 then return end
        local kind = type(current)
        if kind == "string" then
            total = total + #current + 4; budget = budget - 1
        elseif kind == "number" then
            total = total + 8; budget = budget - 1
        elseif kind == "boolean" then
            total = total + 5; budget = budget - 1
        elseif kind == "table" then
            for key, item in pairs(current) do
                budget = budget - 1
                if budget <= 0 then return end
                walk(key, depth + 1)
                walk(item, depth + 1)
            end
        end
    end
    walk(value, 0)
    return total
end

local function formatBytes(bytes)
    if bytes >= 1024 * 1024 then return string.format("%.1f MB", bytes / (1024 * 1024)) end
    return string.format("%.1f KB", bytes / 1024)
end

-- ===== registration =====

-- Forward declaration: the guarded update handler is defined below, because it
-- needs the queue helpers, while the helpers need to schedule it.
local scheduleUpdate

-- ===== save =====

local refreshLayoutChoices

local function commitSave(ctx, name, live)
    if not sameContext(ctx, context()) then printMessage("The house changed during the scan. Nothing was saved."); return end
    local house, unsupported = houseFor(ctx, true)
    if unsupported then printMessage("The stored data uses an unsupported format. Nothing was saved."); return end
    local preset = presetFromLive(live, nil)
    house.presets[name] = preset
    if refreshLayoutChoices then refreshLayoutChoices() end
    printMessage(string.format("Saved layout '%s' (%d furnishings).", name, presetSize(preset)))
end

-- ===== restore planning =====

local function distance(a, b)
    if not a or not b then return nil end
    if type(a.x) ~= "number" or type(a.y) ~= "number" or type(a.z) ~= "number" then return nil end
    if type(b.x) ~= "number" or type(b.y) ~= "number" or type(b.z) ~= "number" then return nil end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Opt-in fallback for instances that were picked up and re-placed, which gives
-- them a new ID. One-to-one, same furniture data ID, nearest within the radius,
-- and refused when a second candidate is equally close.
local function positionMatches(snapshot, live, savedKeys, liveKeys)
    local claimed, matches = {}, {}
    for _, savedKey in ipairs(savedKeys) do
        local saved = snapshot.items[savedKey]
        local best, second, bestKey
        for _, liveKey in ipairs(liveKeys) do
            local item = live[liveKey]
            if item and not claimed[liveKey] and item.numStates > 1
                and item.furnitureDataId == saved.furnitureDataId then
                local gap = distance(saved, item)
                if gap then
                    if not best or gap < best then
                        second, best, bestKey = best, gap, liveKey
                    elseif not second or gap < second then
                        second = gap
                    end
                end
            end
        end
        if bestKey and best <= MATCH_RADIUS and (not second or second - best > 1) then
            claimed[bestKey] = true
            matches[savedKey] = bestKey
        end
    end
    return matches
end

local function planRestore(snapshot, live)
    local keys = {}
    for key in pairs(snapshot.items) do
        if type(key) ~= "string" then return nil, "The layout contains an invalid instance key." end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local liveKeys = {}
    for key in pairs(live) do liveKeys[#liveKeys + 1] = key end
    table.sort(liveKeys)

    local keyMap, unmatched = {}, {}
    for _, key in ipairs(keys) do
        if live[key] then keyMap[key] = key else unmatched[#unmatched + 1] = key end
    end
    local byPosition = {}
    if settings().matchByPosition and #unmatched > 0 then
        byPosition = positionMatches(snapshot, live, unmatched, liveKeys)
        for savedKey, liveKey in pairs(byPosition) do keyMap[savedKey] = liveKey end
    end

    local entries, stats = {}, { missing = 0, incompatible = 0, matched = 0 }
    local nameMap = {}
    for _, key in ipairs(keys) do
        local saved = snapshot.items[key]
        local liveItem = live[keyMap[key]]
        if not liveItem then
            stats.missing = stats.missing + 1
        elseif not compatible(saved, liveItem) then
            stats.incompatible = stats.incompatible + 1
        else
            nameMap[key] = liveItem.name
            if byPosition[key] then stats.matched = stats.matched + 1 end
            if saved.state ~= liveItem.state then
                entries[#entries + 1] = { key = key, id = liveItem.id, name = liveItem.name,
                    saved = saved, attempts = 0, wait = 0 }
            end
        end
    end
    return entries, keyMap, nameMap, stats
end

-- ===== restore queue =====

-- ===== progress panel =====

-- A restore can run without the progress bar if its XML controls are missing.
local progressUi
-- Forward declaration: the bar's Cancel button calls the queue's cancel.
local cancel

local BAR_WIDTH, BAR_HEIGHT = 430, 66
-- Clearance between the chat frame and the bottom of the bar. It used to be 8.
local BAR_CHAT_GAP = 23

-- A saved place must still be usable after a resolution change, so it is clamped
-- to the screen the bar is built for.
local function clampBarPosition(x, y)
    local screenWidth, screenHeight = 1920, 1080
    if GuiRoot and type(GuiRoot.GetDimensions) == "function" then
        local width, height = GuiRoot:GetDimensions()
        if type(width) == "number" and type(height) == "number"
            and width > 0 and height > 0 then
            screenWidth, screenHeight = width, height
        end
    end
    x = math.max(0, math.min(screenWidth - BAR_WIDTH, x))
    y = math.max(0, math.min(screenHeight - BAR_HEIGHT, y))
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Where the player dragged the bar, or nil while the default place applies.
local function savedBarPosition()
    local position = settings().barPosition
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        return position
    end
end

-- The default place: just above the chat frame, in screen coordinates. The chat
-- frame is only read for its position; the bar itself is anchored to GuiRoot, the
-- way ESO's own draggable windows are, so a drag has screen coordinates to work in
-- and the saved place replays exactly.
local function barPositionAboveChat(chatWindow)
    if type(chatWindow) ~= "table" and type(chatWindow) ~= "userdata" then return nil end
    if type(chatWindow.GetLeft) ~= "function" or type(chatWindow.GetTop) ~= "function" then return nil end
    local left, top = chatWindow:GetLeft(), chatWindow:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then return nil end
    return clampBarPosition(left, top - BAR_CHAT_GAP - BAR_HEIGHT)
end

-- Called when a drag ends. Saved variables are written by the client at logout
-- and /reloadui, so the bar comes back where it was left.
local function saveBarPosition(panel)
    if type(panel.GetLeft) ~= "function" or type(panel.GetTop) ~= "function" then return end
    local left, top = panel:GetLeft(), panel:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then return end
    local x, y = clampBarPosition(left, top)
    settings().barPosition = { x = x, y = y }
end

local function buildProgressUi()
    if progressUi ~= nil then return progressUi or nil end
    local wm = WINDOW_MANAGER
    local panel = wm:GetControlByName("ChimersRecallProgressPanel", "")
    local label = wm:GetControlByName("ChimersRecallProgressLabel", "")
    local cancelPlate = wm:GetControlByName("ChimersRecallProgressCancelPlate", "")
    local cancelButton = wm:GetControlByName("ChimersRecallProgressCancel", "")
    local track = wm:GetControlByName("ChimersRecallProgressTrack", "")
    local fill = wm:GetControlByName("ChimersRecallProgressFill", "")
    local background = wm:GetControlByName("ChimersRecallProgressBackdrop", "")
    if not (panel and label and cancelPlate and cancelButton and track and fill and background) then
        progressUi = false
        printMessage("The restore bar is unavailable. Restores still run.")
        return nil
    end

    local savedPosition = savedBarPosition()
    local x, y
    if savedPosition then
        x, y = clampBarPosition(savedPosition.x, savedPosition.y)
    else
        x, y = barPositionAboveChat(wm:GetControlByName("ZO_ChatWindow", ""))
    end
    if x then
        panel:ClearAnchors()
        panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    end
    -- The XML window lets ESO handle mouse movement. Save only when a move ends.
    panel:SetHandler("OnMoveStop", saveBarPosition)

    background:SetCenterColor(0, 0, 0, 0.7)
    background:SetEdgeColor(0.62, 0.54, 0.32, 0.9)
    label:SetColor(1, 0.92, 0.72, 1)
    cancelPlate:SetCenterColor(0.42, 0.07, 0.07, 0.95)
    cancelPlate:SetEdgeColor(0.88, 0.3, 0.26, 1)
    cancelButton:SetHandler("OnMouseEnter", function()
        cancelPlate:SetCenterColor(0.62, 0.13, 0.12, 1)
    end)
    cancelButton:SetHandler("OnMouseExit", function()
        cancelPlate:SetCenterColor(0.42, 0.07, 0.07, 0.95)
    end)
    cancelButton:SetHandler("OnClicked", function()
        cancel("you pressed CANCEL")
    end)
    track:SetCenterColor(0.1, 0.1, 0.1, 0.9)
    track:SetEdgeColor(0.4, 0.36, 0.26, 0.9)
    fill:SetCenterColor(0.45, 0.72, 0.4, 0.95)
    fill:SetEdgeColor(0.45, 0.72, 0.4, 0.95)

    progressUi = { panel = panel, label = label, fill = fill, width = 404 }
    return progressUi
end

-- Reads the running job, so callers only say when to redraw. Nothing here may
-- decide not to show the bar: a bar that is merely under a dialog is fine, since
-- ESO raises dialogs above ordinary windows itself.
local function showProgress()
    local ui = buildProgressUi()
    if not ui then return end
    local percent = math.floor(job.done * 100 / job.total)
    -- Undo is a restore of the pre-restore states, so the bar says what it is
    -- doing instead of pretending the preset is called "undo". A retry repeats
    -- whichever of the two the last restore was.
    local action
    if job.mode == "undo" then
        action = "Undoing last restore"
    elseif job.mode == "retry" then
        action = job.presetName == "undo" and "Retrying the undo"
            or string.format("Retrying '%s'", job.presetName)
    else
        action = string.format("Loading '%s'", job.presetName)
    end
    ui.label:SetText(string.format("%s - %d%% (%d of %d), %d failed",
        action, percent, job.done, job.total, job.failed))
    ui.fill:SetWidth(math.max(1, math.floor(ui.width * percent / 100)))
    ui.panel:SetHidden(false)
    -- ESO raises whichever window the player last clicked in, and a restore started
    -- from the settings panel leaves that panel in front of the chat window. Raising
    -- the bar again on every redraw keeps it in front of the panel the ordinary way,
    -- so it needs no topmost flag or draw tier to be seen.
    if type(ui.panel.BringWindowToTop) == "function" then
        ui.panel:BringWindowToTop()
    end
end

local function hideProgress()
    local ui = progressUi
    if ui then ui.panel:SetHidden(true) end
end

local function advance(entry, failed)
    job.index = job.index + 1
    job.done = job.done + 1
    if failed then
        job.failed = job.failed + 1
        job.failedKeys[#job.failedKeys + 1] = entry.key
    end
    showProgress()
end

local function issue(entry, stateValue)
    entry.attempts = entry.attempts + 1
    local result = HousingEditorRequestChangeState(entry.id, stateValue)
    local success = result == HOUSING_REQUEST_RESULT_SUCCESS
    if not success then job.errors[entry.key] = tostring(result) end
    entry.lastSuccess = success
    logRequest(entry, result)
    if success then
        -- Accepted. Give the server time to apply it before sending again.
        entry.wait = graceTicks()
    else
        -- Rejected or throttled: back off at 2x then 4x the pace.
        entry.wait = backoffTicks(math.min(entry.attempts, 2))
    end
    return success
end

function cancel(reason)
    local mode = job and job.mode or (scanJob and scanJob.purpose) or activeMode
    local hadWork = job ~= nil or scanJob ~= nil or autoJob ~= nil
    job, scanJob, autoJob = nil, nil, nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE)
    hideProgress()
    if not hadWork then return end
    if mode == "save" then
        printMessage("Save cancelled: " .. reason .. " Saved layouts are unchanged.")
    elseif mode == "check" then
        printMessage("Check cancelled: " .. reason)
    elseif mode == "list" then
        printMessage("List cancelled: " .. reason)
    elseif mode == "undo" then
        printMessage("Undo cancelled: " .. reason .. " Changes already made remain applied; the undo slot is unchanged.")
    else
        printMessage("Restore cancelled: " .. reason .. " Changes already made remain applied; the layout is unchanged.")
    end
end

-- Optional display name for a state index, for the reports only. ESO exposes the
-- state variations of a placed furnishing as 1-based preview variations; the name
-- is only used when the client reports the same count as the state count, so a
-- different set of variations is never mislabelled. Names are never persisted,
-- because they are localized text and the index is what restore needs.
local function stateLabel(furnitureId, index, count)
    local nameGetter = GetPlacedFurniturePreviewVariationDisplayName
    local countGetter = GetNumPlacedFurniturePreviewVariations
    if type(nameGetter) ~= "function" or type(countGetter) ~= "function" then return nil end
    if not integer(index, 0) or not integer(count, 2) or index >= count then return nil end
    local variations = countGetter(furnitureId)
    if variations ~= count then return nil end
    local name = nameGetter(furnitureId, index + 1)
    if type(name) ~= "string" or name == "" then return nil end
    return name
end

local function describeState(furnitureId, index, count)
    if not integer(index, 0) or not integer(count, 2) then return "unknown" end
    local label = stateLabel(furnitureId, index, count)
    -- States are zero-based in the data and in the API, but a player counts them
    -- from one: index 0 is "1 of 4". The saved value always stays zero-based.
    if label then return string.format("%d of %d (%s)", index + 1, count, label) end
    return string.format("%d of %d", index + 1, count)
end

local function reportRestore(current, live)
    local missing, incompatible, failed = 0, 0, 0
    local details = {}
    for key, saved in pairs(current.snapshot.items) do
        local liveKey = current.keyMap[key]
        local item = liveKey and live[liveKey]
        if not item then
            missing = missing + 1
        elseif not compatible(saved, item) then
            incompatible = incompatible + 1
        elseif item.state ~= saved.state then
            failed = failed + 1
            if #details < 5 then
                details[#details + 1] = string.format("%s [instance %s]: wanted state %s, found %s%s",
                    current.nameMap[key] or item.name, key,
                    describeState(item.id, saved.state, item.numStates),
                    describeState(item.id, item.state, item.numStates),
                    current.errors[key] and ("; request result " .. current.errors[key]) or "")
            end
        end
    end
    EVENT_MANAGER:UnregisterForUpdate(UPDATE)
    hideProgress()
    job = nil
    addon.lastFailures = current.failedKeys
    addon.lastPreset = current.presetName
    addon.lastMode = current.mode
    -- Kept by value: a retry has to resend these exact target states, and an undo
    -- rewrites the undo slot it restored from before this line runs.
    addon.lastSnapshot = current.snapshot
    -- The bar carried the progress and the failure count while this ran, so chat
    -- only speaks up when something needs attention.
    local problems = failed + missing + incompatible
    if problems == 0 then return end
    local attention
    if current.mode == "undo" then
        attention = "Undo of the last restore needs attention"
    else
        attention = string.format("Restore of '%s' needs attention", current.presetName)
    end
    printMessage(string.format("%s: %d failed, %d missing, %d incompatible%s%s.",
        attention, failed, missing, incompatible,
        current.matchedByPosition > 0 and (string.format(", %d matched by position", current.matchedByPosition)) or "",
        current.stepped > 0 and (string.format(", %d advanced one state at a time", current.stepped)) or ""))
    for _, detail in ipairs(details) do printMessage(detail) end
    if failed > 0 then
        printMessage("Use /chimersrecall retry to resend only those, or check housing permissions, linked items, and other add-ons that change states.")
    end
end

local function finishRestore()
    local current = job
    current.phase = "finish"
    -- Re-enumeration also detects removed items, moved instances, and linked-item conflicts.
    scanJob = beginScan(current.ctx, "finish", function(live)
        reportRestore(current, live)
    end)
    scheduleUpdate(SCAN_TICK_MS)
end

local function stepJob()
    if not sameContext(job.ctx, context()) then cancel("the house or owner changed"); return end
    local entry = job.entries[job.index]
    if not entry then finishRestore(); return end

    -- Read back the actual state; a successful request alone is not confirmation.
    local name, _, dataId = GetPlacedHousingFurnitureInfo(entry.id)
    local count = GetPlacedHousingFurnitureNumObjectStates(entry.id)
    if name == "" or dataId ~= entry.saved.furnitureDataId
        or not integer(count, 2) or entry.saved.state >= count then
        advance(entry)
        return
    end
    local state = GetPlacedHousingFurnitureCurrentObjectStateIndex(entry.id)
    if state == entry.saved.state then
        advance(entry)
        return
    end

    if entry.wait > 0 then entry.wait = entry.wait - 1; return end

    -- Phase 1: ask for the exact saved state directly. Most furnishings accept a
    -- jump to any state index, and this is one request instead of several.
    if not entry.stepping then
        if entry.attempts < MAX_ATTEMPTS then issue(entry, entry.saved.state); return end
        -- Rejected requests mean the item cannot be changed at all here (usually
        -- permissions), so advancing would only add pointless traffic.
        if not entry.lastSuccess then advance(entry, true); return end
        -- Accepted, yet the readback never reached the target: some furnishings
        -- accept only "the next state". Circle forward one state at a time until
        -- the readback matches, visiting each state at most once.
        entry.stepping = true
        entry.steps = 0
        job.stepped = job.stepped + 1
    end
    local current = tonumber(state)
    if not integer(current, 0) or current >= count then advance(entry, true); return end
    if entry.steps >= count + 1 then advance(entry, true); return end
    entry.steps = entry.steps + 1
    issue(entry, (current + 1) % count)
end

local function startRestore(ctx, house, presetNameText, preset, live, mode, onlyKeys)
    local entries, keyMap, nameMap, stats = planRestore(preset, live)
    if not entries then printMessage(keyMap); return end
    if onlyKeys then
        local filtered = {}
        for _, entry in ipairs(entries) do
            if onlyKeys[entry.key] then filtered[#filtered + 1] = entry end
        end
        entries = filtered
    end
    activeMode = mode
    if not sameContext(ctx, context()) then cancel("the house or owner changed"); return end
    if #entries > 0 and mode ~= "retry" then
        -- Undo slot: the live states this restore is about to replace.
        house.previous = presetFromLive(live, "before restore of '" .. presetNameText .. "'")
    end
    job = { ctx = ctx, snapshot = preset, keyMap = keyMap, nameMap = nameMap,
        matchedByPosition = stats.matched, entries = entries, index = 1, done = 0, failed = 0,
        stepped = 0, failedKeys = {}, errors = {}, total = #entries, presetName = presetNameText,
        mode = mode }
    if #entries == 0 then
        -- Nothing to do is worth one line: there is no bar to watch.
        if mode == "undo" then
            printMessage(string.format("Nothing to undo: all %d instance(s) already match the states captured before the last restore.",
                presetSize(preset)))
        else
            printMessage(string.format("Nothing to load: all %d saved instance(s) already match layout '%s'.",
                presetSize(preset), presetNameText))
        end
        finishRestore()
        return
    end
    if stats.matched > 0 then
        -- Heuristic matching can act on a furnishing you did not place, so it is
        -- worth one line even though progress itself lives on the bar.
        printMessage(string.format("Matched %d instance(s) by furniture type and position.", stats.matched))
    end
    showProgress()
    scheduleUpdate(pace())
end

local function beginRestoreScan(ctx, house, name, mode, onlyKeys)
    local preset
    if name == "previous" or name == "undo" then
        preset = house.previous
        if not validPreset(preset) then
            printMessage("Nothing to undo: no pre-restore state has been recorded for this house yet.")
            return
        end
        name = "undo"
    else
        preset = house.presets[name]
        if not validPreset(preset) then
            printMessage(string.format("No layout named '%s' in this house. /cr layouts lists them.", name))
            return
        end
    end
    scanJob = beginScan(ctx, mode, function(live)
        startRestore(ctx, house, name, preset, live, mode, onlyKeys)
    end)
    scheduleUpdate(SCAN_TICK_MS)
end

local function busyReason()
    if job or scanJob or autoJob then
        printMessage("Busy: finish the current scan or restore, or use /chimersrecall cancel.")
        return true
    end
    return false
end

-- Forward declaration: saving over an existing preset asks first, and the
-- confirmation lives with the dialog code further down.
local askConfirmation

local function confirmInHouse(action, message, ctx, mutation)
    local shown = askConfirmation(action, message, function()
        local current = context()
        if not sameContext(ctx, current) then
            printMessage("The house changed. No layout was modified.")
            return
        end
        if not busyReason() then mutation() end
    end)
    if not shown then printMessage("The confirmation could not be shown. No layout was modified.") end
end

local function save(text)
    if busyReason() then return end
    local ctx = commandContext()
    if not ctx then return end
    local name = layoutName(text, DEFAULT_PRESET)
    if not name then printMessage(INVALID_LAYOUT_NAME); return end
    if name == "previous" or name == "undo" then
        printMessage("Choose a different layout name. That name is reserved for undo.")
        return
    end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format."); return end
    local original = house and house.presets[name]
    local function startSave()
        local current = houseFor(ctx, false)
        if (current and current.presets[name]) ~= original then
            printMessage("That layout changed. Run Save Layout again.")
            return
        end
        scanJob = beginScan(ctx, "save", function(live) commitSave(ctx, name, live) end)
        scheduleUpdate(SCAN_TICK_MS)
    end
    if original then
        confirmInHouse("Overwrite", string.format("Replace layout '%s' with the current furnishing states?", name), ctx, startSave)
    else
        startSave()
    end
end

local function restore(text, mode, onlyKeys)
    if busyReason() then return end
    local ctx = commandContext()
    if not ctx then return end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format. Save a new layout before restoring."); return end
    if not house then printMessage("No layouts for this owner and house. Use /chimersrecall save first."); return end
    local name = layoutName(text, DEFAULT_PRESET, house.presets)
    if not name then printMessage(INVALID_LAYOUT_NAME); return end
    beginRestoreScan(ctx, house, name, mode, onlyKeys)
end

-- ===== commands =====

local function listPresets()
    local ctx = commandContext()
    if not ctx then return end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format."); return end
    local names = {}
    for name in pairs(house and house.presets or {}) do names[#names + 1] = name end
    table.sort(names)
    printMessage(#names > 0 and ("Layouts in this house: " .. table.concat(names, ", ")) or "No layouts saved in this house.")
end

local function status()
    local ctx = commandContext()
    if not ctx then return end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format."); return end
    local count = 0
    for _ in pairs(house and house.presets or {}) do count = count + 1 end
    printMessage(string.format("Saved layouts: %d. Load on entry: %s. Undo: %s. Saved size: %s.",
        count, autoPresetName(house) or "None",
        house and validPreset(house.previous) and "available" or "unavailable",
        house and formatBytes(estimateBytes(house)) or "0 B"))
    local current = settings()
    printMessage(string.format("Account settings: pace %d ms, position matching %s, automatic loading %s, request log %s.",
        current.paceMs, current.matchByPosition and "on" or "off",
        current.autoRestore and "on" or "off", current.logRequests and "on" or "off"))
end

local function deletePreset(text)
    if busyReason() then return end
    local ctx = commandContext()
    if not ctx then return end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format."); return end
    local name = layoutName(text, DEFAULT_PRESET, house and house.presets)
    if not name then printMessage(INVALID_LAYOUT_NAME); return end
    local undo = name == "previous" or name == "undo"
    local entries, key
    if house then
        if undo then entries, key = house, "previous"
        else entries, key = house.presets, name end
    end
    local original = entries and entries[key]
    if not original then
        printMessage(undo and "No undo snapshot is available." or string.format("No layout named '%s' in this house.", name))
        return
    end
    local label = undo and "the undo snapshot" or string.format("layout '%s'", name)
    confirmInHouse("Delete", "Permanently delete " .. label .. "?", ctx, function()
        if houseFor(ctx, false) ~= house or entries[key] ~= original then
            printMessage("That saved entry changed. Run Delete Layout again.")
            return
        end
        entries[key] = nil
        if not undo and house.defaultPreset == name then house.defaultPreset = nil end
        if refreshLayoutChoices then refreshLayoutChoices() end
        printMessage("Deleted " .. label .. ".")
    end)
end

local function setPace(text)
    local value = tonumber((text or ""):match("^%s*(.-)%s*$"))
    local current = settings()
    if value == nil then
        printMessage(string.format("Pacing is %d ms per request (range %d-%d). Use /chimersrecall pace 500 to change it.",
            current.paceMs, PACE_MIN, PACE_MAX))
        return
    end
    value = math.floor(value)
    if value < PACE_MIN or value > PACE_MAX then
        value = math.max(PACE_MIN, math.min(PACE_MAX, value))
        printMessage(string.format("Pacing must be between %d and %d ms; using %d.", PACE_MIN, PACE_MAX, value))
    end
    current.paceMs = value
    printMessage(string.format("Pacing set to %d ms per request (about %.1f requests/second). It applies to the next restore.",
        value, 1000 / value))
end

local function toggleLog(text)
    local value = (text or ""):match("^%s*(%S*)%s*$")
    local current = settings()
    if value == "on" or value == "off" then
        current.logRequests = value == "on"
        if not current.logRequests then requestLog = {} end
        printMessage("Request log " .. value .. ".")
        return
    end
    printMessage(string.format("Request log is %s. Use /chimersrecall log on|off, or /chimersrecall log to print the last results.",
        current.logRequests and "on" or "off"))
    if #requestLog == 0 then return end
    local first = math.max(1, #requestLog - 19)
    for index = first, #requestLog do
        local entry = requestLog[index]
        printMessage(string.format("  %7.1fs  %s [instance %s] -> state %s: result %s",
            (entry.at - SESSION_START) / 1000, entry.name or "furnishing", entry.key,
            tostring(entry.state), entry.result))
    end
end

local function toggle(text, field, label)
    local value = (text or ""):match("^%s*(%S*)%s*$")
    local current = settings()
    if value == "on" or value == "off" then
        current[field] = value == "on"
        printMessage(label .. " " .. value .. ".")
        return
    end
    printMessage(string.format("%s is %s. Use /chimersrecall %s on|off.", label,
        current[field] and "on" or "off", field == "matchByPosition" and "match" or "auto"))
end

-- Which preset auto-restore uses is a per-house choice, and saving used to be
-- the only way to make it: that forced a re-save of the live house just to pick
-- an existing preset. This sets the pointer without touching saved states.
local function setDefaultPreset(text, quiet)
    local ctx = commandContext()
    if not ctx then return end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format."); return end
    if not house then printMessage("Save a layout in this house first."); return end
    if text == "" or text == nil then
        printMessage("Load on entry: " .. (autoPresetName(house) or "None") .. ".")
        return
    end
    local name = layoutName(text, nil, house.presets)
    if not quiet and (text == "--off" or (text == "off" and not house.presets.off)) then
        house.defaultPreset = nil
    elseif name and validPreset(house.presets[name]) then
        house.defaultPreset = name
    else
        printMessage("Choose a saved layout with /cr entry <name>, or clear the choice with /cr entry --off.")
        return
    end
    if not quiet then
        if refreshLayoutChoices then refreshLayoutChoices() end
        printMessage("Load on entry: " .. (autoPresetName(house) or "None") .. ".")
    end
end

local function help()
    printMessage("/cr opens settings. /chimersrecall is the full command.")
    printMessage("Layouts: /cr save [name], load [name], delete [name], layouts. Blank names use 'default'.")
    printMessage("Recovery: /cr undo, retry, cancel.")
    printMessage("Automatic loading: /cr auto on|off, entry [name|--off].")
    printMessage("Diagnostics: /cr status, check [name], furnishings [filter], log [on|off], /cr bartest.")
    printMessage("Advanced: /cr pace [ms], match on|off.")
end

-- The bare command is the settings panel: that is where the presets and the
-- switches live. Without LibAddonMenu there is no panel to open, so the command
-- list is the only useful answer.
local function openSettings()
    local LAM = LibAddonMenu2
    if type(LAM) == "table" and addon.settingsPanel and type(LAM.OpenToPanel) == "function" then
        LAM:OpenToPanel(addon.settingsPanel)
        return
    end
    help()
end

local function retryLast()
    if busyReason() then return end
    local failures = addon.lastFailures
    if not failures or #failures == 0 then
        printMessage("Nothing to retry: the last restore had no failed instances.")
        return
    end
    local ctx = commandContext()
    if not ctx then return end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format."); return end
    if not house then printMessage("No layouts for this owner and house."); return end
    -- The states that restore was aiming at, kept by value rather than looked up
    -- by name: an undo restores the undo slot and rewrites it while doing so, so
    -- resolving "previous" again would resend the failures against the states the
    -- undo was leaving behind instead of the ones it was restoring.
    local name = addon.lastPreset or DEFAULT_PRESET
    local snapshot = addon.lastSnapshot
    if not validPreset(snapshot) then snapshot = house.presets[name] end
    if not validPreset(snapshot) then
        printMessage("Nothing to retry: the layout from the last restore is no longer available.")
        return
    end
    local only = {}
    for _, key in ipairs(failures) do only[key] = true end
    local count = 0
    for _ in pairs(only) do count = count + 1 end
    printMessage(string.format("Retrying %d failed instance(s) from the last restore.", count))
    scanJob = beginScan(ctx, "retry", function(live)
        startRestore(ctx, house, name, snapshot, live, "retry", only)
    end)
    scheduleUpdate(SCAN_TICK_MS)
end

-- Diagnostic: compare a saved preset with the states the client reports right now.
-- This is how "did the add-on record the exact state?" is answered in-game, with
-- the range (of how many states) shown next to each value.
local function reportCheck(preset, name, live)
    local match, differ, missing, incompatible = 0, 0, 0, 0
    local details, liveStates = {}, {}
    for key, saved in pairs(preset.items) do
        local item = live[key]
        if not item then
            missing = missing + 1
        elseif not compatible(saved, item) then
            incompatible = incompatible + 1
        else
            if integer(item.state, 0) then
                liveStates[item.state] = (liveStates[item.state] or 0) + 1
            end
            if item.state == saved.state then
                match = match + 1
            else
                differ = differ + 1
                if #details < 8 then
                    details[#details + 1] = string.format("%s [instance %s]: saved state %s, live state %s",
                        item.name, key, describeState(item.id, saved.state, item.numStates),
                        describeState(item.id, item.state, item.numStates))
                end
            end
        end
    end
    printMessage(string.format("Check of '%s': %d match, %d differ, %d missing, %d incompatible. States are shown 1-based; the saved value stays 0-based.",
        name, match, differ, missing, incompatible))
    -- Which live states the saved instances are actually in. A four-state lamp
    -- that only ever reports 0 or 1 shows up here immediately.
    local states = {}
    for state in pairs(liveStates) do states[#states + 1] = state end
    table.sort(states)
    local pieces = {}
    for _, state in ipairs(states) do
        pieces[#pieces + 1] = string.format("%d:%d", state + 1, liveStates[state])
    end
    if #pieces > 0 then
        printMessage("Live states of saved instances (state:how many): " .. table.concat(pieces, ", "))
    end
    for _, detail in ipairs(details) do printMessage(detail) end
end

local function checkPreset(text)
    if busyReason() then return end
    local ctx = commandContext()
    if not ctx then return end
    local house, unsupported = houseFor(ctx, false)
    if unsupported then printMessage("The stored data uses an unsupported format."); return end
    if not house then printMessage("No layouts for this owner and house."); return end
    local name = layoutName(text, DEFAULT_PRESET, house.presets)
    if not name then printMessage(INVALID_LAYOUT_NAME); return end
    local preset
    if name == "previous" or name == "undo" then
        preset, name = house.previous, "undo"
    else
        preset = house.presets[name]
    end
    if not validPreset(preset) then
        printMessage(string.format("No layout named '%s' in this house.", name))
        return
    end
    scanJob = beginScan(ctx, "check", function(live)
        reportCheck(preset, name, live)
    end)
    scheduleUpdate(SCAN_TICK_MS)
end

-- Read-only listing so the reported states can be checked against the house by
-- eye: one line per interactive item with its state count and current state.
local function reportList(live, filter)
    local rows, scanned, interactive = {}, 0, 0
    for key, item in pairs(live) do
        scanned = scanned + 1
        if item.numStates > 1 then
            interactive = interactive + 1
            if filter == "" or string.find(string.lower(item.name), filter, 1, true) then
                rows[#rows + 1] = { key = key, item = item }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.item.name == b.item.name then return a.key < b.key end
        return a.item.name < b.item.name
    end)
    if filter ~= "" then
        printMessage(string.format("Scanned %d placed item(s), %d interactive; %d match '%s'.",
            scanned, interactive, #rows, filter))
    else
        printMessage(string.format("Scanned %d placed item(s), %d interactive.", scanned, interactive))
    end
    if #rows == 0 then
        printMessage("No interactive item matched.")
        return
    end
    for _, row in ipairs(rows) do
        printMessage(string.format("%s - state %s [instance %s]", row.item.name,
            describeState(row.item.id, row.item.state, row.item.numStates), row.key))
    end
end

local function listItems(text)
    if busyReason() then return end
    local ctx = commandContext()
    if not ctx then return end
    local filter = string.lower((text or ""):match("^%s*(.-)%s*$"))
    scanJob = beginScan(ctx, "list", function(live)
        reportList(live, filter)
    end)
    scheduleUpdate(SCAN_TICK_MS)
end

local function runAutoRestore()
    local ctx = autoJob.ctx
    local house = autoJob.house
    autoJob = nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE)
    if not settings().autoRestore or not sameContext(ctx, context()) then return end
    local name = autoPresetName(house)
    if not name then return end
    local preset = house.presets[name]
    scanJob = beginScan(ctx, "auto", function(live)
        startRestore(ctx, house, name, preset, live, "auto", nil)
    end)
    scheduleUpdate(SCAN_TICK_MS)
end

local function maybeAutoRestore()
    if not settings().autoRestore then return end
    if job or scanJob or autoJob then return end
    local ctx = context()
    if not ctx then return end
    local house = houseFor(ctx, false)
    -- Ignored here when this house has no auto-restore preset: entering a house
    -- never restores a preset chosen for another one.
    local name = autoPresetName(house)
    if not name then return end
    autoJob = { ctx = ctx, house = house, ticks = math.max(1, math.ceil(AUTO_RESTORE_DELAY_MS / AUTO_TICK_MS)) }
    scheduleUpdate(AUTO_TICK_MS)

end

-- ===== update loop =====

local function abort(reason)
    local mode = activeMode
    scanJob, job, autoJob = nil, nil, nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE)
    hideProgress()
    if mode == "save" then
        printMessage("Save stopped: " .. tostring(reason) .. " Saved layouts are unchanged.")
    elseif mode == "check" then
        printMessage("Check stopped: " .. tostring(reason))
    elseif mode == "list" then
        printMessage("List stopped: " .. tostring(reason))
    elseif mode == "finish" then
        printMessage("Restore cancelled: " .. tostring(reason) .. " Changes already made remain applied; the layout is unchanged.")
    elseif mode == "undo" then
        printMessage("Undo stopped: " .. tostring(reason) .. " No further requests were made.")
    else
        printMessage("Restore stopped: " .. tostring(reason) .. " No further requests were made.")
    end
end

local function update()
    if autoJob then
        autoJob.ticks = autoJob.ticks - 1
        if autoJob.ticks <= 0 then runAutoRestore() end
        return
    end
    if scanJob then
        local scan = scanJob
        if not sameContext(scan.ctx, context()) then
            cancel("the house or owner changed")
            return
        end
        local done, reason = scanChunk(scan)
        if reason then abort(reason); return end
        if not done then return end
        EVENT_MANAGER:UnregisterForUpdate(UPDATE)
        -- Keep scanJob set while the continuation runs so a cancellation inside it
        -- can still identify the phase; only clear it if nothing replaced it.
        scan.onDone(scan.result, scan)
        if scanJob == scan then scanJob = nil end
        return
    end
    if job then
        if job.phase == "finish" then return end
        -- Redrawn every tick, not only when an instance advances, so the bar is
        -- raised again in front of whatever window was clicked since the last one.
        showProgress()
        stepJob()
    end
end

-- Schedule one tick at a time so an exception reaches ESO without repeating
-- on every timer tick. A phase can replace the timer with a new interval.
local scheduledInterval
local function runUpdate()
    local interval = scheduledInterval
    scheduledInterval = nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE)
    update()
    if not scheduledInterval and (job or scanJob or autoJob) then
        scheduleUpdate(interval)
    end
end

function scheduleUpdate(intervalMs)
    scheduledInterval = intervalMs
    EVENT_MANAGER:RegisterForUpdate(UPDATE, intervalMs, runUpdate)
end

-- ===== settings UI =====

-- Presets belong to a house, so the settings that choose between them only mean
-- something while standing inside one of your own houses. These helpers answer
-- that question safely from inside the UI callbacks.
function addon.CurrentHouse()
    local ctx = context()
    if not ctx then return nil end
    return (houseFor(ctx, false))
end

function addon.InPlayerHouse()
    return context() ~= nil
end

function addon.HousePresetNames()
    local house = addon.CurrentHouse()
    local names = {}
    if house and house.presets then
        for name in pairs(house.presets) do names[#names + 1] = name end
        table.sort(names)
    end
    return names
end

function addon.CurrentDefaultPreset()
    local house = addon.CurrentHouse()
    if not house then return nil end
    return autoPresetName(house)
end

-- ===== settings panel actions =====

-- What was typed into the panel's save box. Deliberately not persisted, so a name
-- typed once does not come back as a preset the next time settings open.
addon.saveNameDraft = addon.saveNameDraft or ""

-- LAM's editbox only calls setFunc on focus lost or Escape, so the live text is
-- read here when the control exists: clicking Save must not depend on the click
-- having taken focus away from the box first. The draft is used when LAM is
-- absent or the box was never built.
local function draftPresetName()
    local box = addon.saveNameControl
    local editbox = box and box.editbox
    if editbox and type(editbox.GetText) == "function" then
        local text = editbox:GetText()
        if type(text) == "string" then return text end
    end
    return addon.saveNameDraft
end

-- The preset the restore dropdown acts on. The stored choice wins while it still
-- exists in this house; otherwise the house's own default preset is a better
-- answer than a blank box.
function addon.RestoreChoice()
    local names = addon.HousePresetNames()
    local choice = addon.restorePresetChoice
    if choice then
        for _, name in ipairs(names) do if name == choice then return choice end end
    end
    for _, name in ipairs(names) do if name == DEFAULT_PRESET then return name end end
    return nil
end

local confirmationDialogs = {}

local function registerConfirmation(action)
    if confirmationDialogs[action] then return confirmationDialogs[action] end
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return nil end
    local name = "ChimersRecallConfirm" .. action
    ZO_Dialogs_RegisterCustomDialog(name, {
        title = { text = action .. " saved layout?" },
        mainText = { text = function(dialog) return dialog.data.message end },
        buttons = {
            { text = action, callback = function(dialog) dialog.data.onConfirm() end },
            { text = "Cancel" },
        },
    })
    confirmationDialogs[action] = name
    return name
end

askConfirmation = function(action, message, callback)
    local dialog = registerConfirmation(action)
    if not dialog or type(ZO_Dialogs_ShowDialog) ~= "function" then return false end
    ZO_Dialogs_ShowDialog(dialog, { message = message, onConfirm = callback })
    return true
end

function addon.SavePresetFromPanel()
    addon.HandleSlashCommand("save " .. draftPresetName())
end

function addon.RestorePresetFromPanel()
    local name = addon.RestoreChoice()
    if not name then
        printMessage("No layouts for this owner and house. Use the save box first.")
        return
    end
    addon.HandleSlashCommand("load " .. name)
end

function addon.CheckPresetFromPanel()
    addon.HandleSlashCommand("check " .. (addon.RestoreChoice() or ""))
end

local function registerSettingsUI()
    local LAM = LibAddonMenu2
    if not LAM or type(LAM.RegisterAddonPanel) ~= "function" then return false end
    local panel = LAM:RegisterAddonPanel("ChimersRecallOptions", {
        type = "panel",
        name = "Chimer's Recall",
        displayName = "Chimer's Recall",
        author = "skperdue68",
        version = VERSION,
        registerForRefresh = true,
        registerForDefaults = false,
    })
    addon.settingsPanel = panel
    local function outsideHouse() return not addon.InPlayerHouse() end
    local function noSelection() return outsideHouse() or not addon.RestoreChoice() end
    local function entryChoices()
        local values = addon.HousePresetNames()
        local labels = { "None" }
        for _, name in ipairs(values) do labels[#labels + 1] = name end
        table.insert(values, 1, "")
        return labels, values
    end
    local entryLabels, entryValues = entryChoices()
    local options = {
        { type = "header", name = "This House" },
        { type = "description", text = function()
            return outsideHouse() and "Enter a player house to manage its layouts."
                or "Layouts save the states of interactive furnishings in this house."
          end },
        { type = "editbox", name = "New Layout Name",
          tooltip = "Leave blank to save as default. Spaces are removed. Replacing a layout requires confirmation.",
          controlKey = "saveNameControl",
          getFunc = function() return addon.saveNameDraft end,
          setFunc = function(value) addon.saveNameDraft = value or "" end,
          disabled = outsideHouse },
        { type = "button", name = "Save Layout", func = addon.SavePresetFromPanel, disabled = outsideHouse },
        { type = "dropdown", name = "Saved Layout",
          tooltip = "Choose the layout to load, delete or compare.",
          choices = addon.HousePresetNames(), scrollable = true,
          controlKey = "layoutDropdown",
          getFunc = addon.RestoreChoice,
          setFunc = function(value) addon.restorePresetChoice = value end,
          disabled = function() return outsideHouse() or #addon.HousePresetNames() == 0 end },
        { type = "button", name = "Load Layout", width = "half", func = addon.RestorePresetFromPanel, disabled = noSelection },
        { type = "button", name = "Delete Layout", width = "half", disabled = noSelection,
          func = function() local name = addon.RestoreChoice(); if name then addon.HandleSlashCommand("delete " .. name) end end },
        { type = "dropdown", name = "Load on Entry",
          tooltip = "Choose which layout loads in this house when automatic loading is enabled.",
          choices = entryLabels, choicesValues = entryValues, scrollable = true,
          controlKey = "entryDropdown",
          getFunc = function() return addon.CurrentDefaultPreset() or "" end,
          setFunc = function(value)
              if value == "" then
                  local house = addon.CurrentHouse()
                  if house then house.defaultPreset = nil end
              elseif value then
                  setDefaultPreset(value, true)
              end
          end,
          disabled = function() return outsideHouse() or #addon.HousePresetNames() == 0 end },
        { type = "submenu", name = "Recovery", controls = {
            { type = "button", name = "Undo Last Load", width = "half",
              func = function() addon.HandleSlashCommand("undo") end,
              disabled = function()
                  local house = addon.CurrentHouse()
                  return not house or not validPreset(house.previous)
              end },
            { type = "button", name = "Retry Failed Changes", width = "half",
              func = function() addon.HandleSlashCommand("retry") end, disabled = outsideHouse },
            { type = "button", name = "Cancel Load",
              func = function() addon.HandleSlashCommand("cancel") end },
        } },
        { type = "header", name = "Account Settings" },
        { type = "checkbox", name = "Automatically Load Layouts",
          tooltip = "Load the layout selected under Load on Entry when you enter that house.",
          default = false,
          getFunc = function() return settings().autoRestore end,
          setFunc = function(value) settings().autoRestore = value end },
        { type = "submenu", name = "Advanced Settings", controls = {
            { type = "slider", name = "Request Interval",
              tooltip = "Milliseconds between furnishing state changes.",
              min = PACE_MIN, max = PACE_MAX, step = 50, default = DEFAULT_PACE_MS,
              getFunc = function() return settings().paceMs end,
              setFunc = function(value) settings().paceMs = math.floor(value) end },
            { type = "checkbox", name = "Match by Position",
              tooltip = "Enable before saving to match replacements of the same type at the same position.",
              default = false,
              getFunc = function() return settings().matchByPosition end,
              setFunc = function(value) settings().matchByPosition = value end },
        } },
        { type = "submenu", name = "Diagnostics", controls = {
            { type = "button", name = "Compare Layout", width = "half", func = addon.CheckPresetFromPanel, disabled = noSelection },
            { type = "button", name = "List Furnishings", width = "half",
              func = function() addon.HandleSlashCommand("furnishings") end, disabled = outsideHouse },
            { type = "button", name = "Show House Status", width = "half",
              func = function() addon.HandleSlashCommand("status") end, disabled = outsideHouse },
            { type = "button", name = "Preview Progress Bar", width = "half",
              func = function() addon.HandleSlashCommand("bartest") end },
            { type = "checkbox", name = "Record Request Log",
              tooltip = "Record request results for troubleshooting. Use /cr log to read them.",
              default = false,
              getFunc = function() return settings().logRequests end,
              setFunc = function(value) settings().logRequests = value end },
            { type = "button", name = "Show Request Log",
              func = function() addon.HandleSlashCommand("log") end },
        } },
    }
    LAM:RegisterOptionControls("ChimersRecallOptions", options)
    refreshLayoutChoices = function()
        local selected = addon.layoutDropdown
        if selected and type(selected.UpdateChoices) == "function" then
            selected:UpdateChoices(addon.HousePresetNames())
        end
        local entry = addon.entryDropdown
        if entry and type(entry.UpdateChoices) == "function" then
            entry:UpdateChoices(entryChoices())
        end
        if CALLBACK_MANAGER and type(CALLBACK_MANAGER.FireCallbacks) == "function" then
            CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
        end
    end
    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.RegisterCallback) == "function" then
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(created)
            if created ~= panel then return end
            for _, control in ipairs(panel.controlsToRefresh or {}) do
                local key = control.data and control.data.controlKey
                if key then addon[key] = control end
            end
            refreshLayoutChoices()
        end)
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(opened)
            if opened == panel then refreshLayoutChoices() end
        end)
    end
    return true
end

-- ===== commands and events =====

local commands = {}

-- A look at the bar on its own: no scan, no requests, no furnishing touched. That
-- separates "this client does not draw the panel" from "the restore never reached
-- its queue" in six seconds instead of a whole restore.
local function barTest()
    if busyReason() then return end
    local ui = buildProgressUi()
    if not ui then
        printMessage("The restore bar could not be created in this client, so no restore can show one; restores still run. Try /reloadui first.")
        return
    end
    ui.label:SetText("Bar test - if you can read this, the bar draws")
    ui.fill:SetWidth(math.floor(ui.width * 0.5))
    ui.panel:SetHidden(false)
    if type(ui.panel.BringWindowToTop) == "function" then
        ui.panel:BringWindowToTop()
    end
    printMessage("Bar test: the panel is showing for 6 seconds. Nothing is being restored and CANCEL does nothing here.")
    if type(zo_callLater) == "function" then
        zo_callLater(function() ui.panel:SetHidden(true) end, 6000)
    end
end

commands.save = function(rest) save(rest) end
commands.load = function(rest) restore(rest, "restore") end
commands.restore = commands.load
commands.undo = function() restore("previous", "undo") end
commands.retry = function() retryLast() end
commands.layouts = function() listPresets() end
commands.presets = commands.layouts
commands.delete = function(rest) deletePreset(rest) end
commands.status = function() status() end
commands.check = function(rest) checkPreset(rest) end
commands.furnishings = function(rest) listItems(rest) end
commands.list = commands.furnishings
commands.pace = function(rest) setPace(rest) end
commands.log = function(rest) toggleLog(rest) end
commands.match = function(rest) toggle(rest, "matchByPosition", "Position matching") end
commands.entry = function(rest) setDefaultPreset(rest) end
commands.default = commands.entry
commands.auto = function(rest) toggle(rest, "autoRestore", "Auto-restore") end
commands.cancel = function()
    if job or scanJob or autoJob then cancel("requested by you")
    else printMessage("Nothing is running.") end
end
commands.bartest = function() barTest() end
commands.help = help
commands[""] = openSettings

function addon.HandleSlashCommand(args)
    local text = (args or ""):match("^%s*(.-)%s*$")
    local command, rest = text:match("^(%S*)%s*(.*)$")
    local action = commands[string.lower(command or "")]
    if not action then printMessage("Unknown command. Use /cr help for the command list."); return end
    action(rest)
end

local function onLoaded(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    addon.savedVars = ZO_SavedVars:NewAccountWide("ChimersRecallSavedVariables", 1, GetWorldName(),
        { houses = {}, settings = { paceMs = DEFAULT_PACE_MS, matchByPosition = false,
            autoRestore = false, logRequests = false } })
    ensureSettings()
    SLASH_COMMANDS["/chimersrecall"] = addon.HandleSlashCommand
    SLASH_COMMANDS["/cr"] = addon.HandleSlashCommand
    -- Registered once at load rather than on first use, which is when the dialog
    -- system expects add-on dialogs to appear.
    registerConfirmation("Overwrite")
    registerConfirmation("Delete")
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function() cancel("you left the zone") end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        addon.restorePresetChoice = nil
        if refreshLayoutChoices then refreshLayoutChoices() end
        maybeAutoRestore()
    end)
    addon.settingsAvailable = registerSettingsUI()
end

addon.VERSION = VERSION
addon.DEFAULT_PRESET = DEFAULT_PRESET

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, onLoaded)
