-- ResParse, by thepandalore. See README.txt for scope, credits and AI disclosure.
ResParse = {}
local RP = ResParse
local EM = EVENT_MANAGER
local MAX_SCORE = 65535 -- Protocol 340 uses an unsigned 16-bit total.
local ROW_HEIGHT = 23
local BASE_HEIGHT = 48
local GROUP_DELAY_MS = 250
local DRAW_DELAY_MS = 100
local SEND_INTERVAL_MS = 500

RP.name = "ResParse"
RP.version = "0.3.2"
RP.protocolId = 340
RP.protocolName = "ResParseScoresheet"
RP.rows = {}
RP.pending = {}
RP.active = false
RP.uiDirty = true
RP.syncRequested = false
RP.syncEnqueued = false

local defaults = {
    tally = {},
    scoreModelVersion = 5,
    worldInitialized = false,
    window = { hidden = false, point = CENTER, relativePoint = CENTER, x = 0, y = 0 },
    backgroundOpacity = 86,
    windowWidth = 290,
}

local anchors = {
    [CENTER] = true, [TOPLEFT] = true, [TOP] = true, [TOPRIGHT] = true,
    [LEFT] = true, [RIGHT] = true, [BOTTOMLEFT] = true, [BOTTOM] = true,
    [BOTTOMRIGHT] = true,
}

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

local function IsScore(value)
    return IsFiniteNumber(value) and value >= 0 and value <= MAX_SCORE and
        value == math.floor(value)
end

local function BoundedNumber(value, fallback, minimum, maximum)
    if not IsFiniteNumber(value) then return fallback end
    return math.max(minimum, math.min(maximum, value))
end

local function AccountKey(value)
    return zo_strlower((string.gsub(value, "^@", "")))
end

local function CharacterKey(value)
    return zo_strlower(zo_strformat("<<1>>", value))
end

function RP:LoadSavedVariables()
    self.account = GetDisplayName()
    self.world = GetWorldName()
    local oldRoot = ResParseSavedVariables
    local oldProfile = type(oldRoot) == "table" and oldRoot.Default
    local oldAccount = type(oldProfile) == "table" and oldProfile[self.account]
    local legacy = type(oldAccount) == "table" and oldAccount["$AccountWide"]

    self.saved = ZO_SavedVars:NewAccountWide(
        "ResParseSavedVariables", 1, nil, defaults, self.world)

    -- Copy only presentation settings from the old, unscoped raw table. Its
    -- scores have no known megaserver; importing them into every world is wrong.
    -- Do not pass a ZO_SavedVars proxy back to NewAccountWide as defaults.
    if not self.saved.worldInitialized then
        if type(legacy) == "table" then
            if type(legacy.window) == "table" then
                local oldWindow = legacy.window
                self.saved.window = {
                    hidden = oldWindow.hidden, point = oldWindow.point,
                    relativePoint = oldWindow.relativePoint,
                    x = oldWindow.x, y = oldWindow.y,
                }
            end
            self.saved.windowWidth = legacy.windowWidth
            self.saved.backgroundOpacity = legacy.backgroundOpacity
        end
        self.saved.tally = {}
        self.saved.worldInitialized = true
    end

    if type(self.saved.tally) ~= "table" or self.saved.scoreModelVersion ~= 5 then
        self.saved.tally = {}
    end
    self.saved.scoreModelVersion = 5
    for name, count in pairs(self.saved.tally) do
        if type(name) ~= "string" or not string.match(name, "^@.+") or not IsScore(count) then
            self.saved.tally[name] = nil
        end
    end

    if type(self.saved.window) ~= "table" then self.saved.window = {} end
    local settings = self.saved.window
    settings.hidden = settings.hidden == true
    if not anchors[settings.point] or not anchors[settings.relativePoint] or
        not IsFiniteNumber(settings.x) or not IsFiniteNumber(settings.y) then
        settings.point, settings.relativePoint = CENTER, CENTER
        settings.x, settings.y = 0, 0
    end
    self.saved.windowWidth = BoundedNumber(self.saved.windowWidth, 290, 200, 600)
    self.saved.backgroundOpacity = BoundedNumber(self.saved.backgroundOpacity, 86, 0, 100)
end

-- One-shot named tasks: burst coalescing, not a recurring polling loop.
function RP:ScheduleTask(key, delay, callback)
    if self.pending[key] then return end
    self.pending[key] = true
    local name = self.name .. "_" .. key
    EM:RegisterForUpdate(name, delay, function()
        EM:UnregisterForUpdate(name)
        self.pending[key] = nil
        callback()
    end)
end

function RP:CancelTasks()
    for key in pairs(self.pending) do
        EM:UnregisterForUpdate(self.name .. "_" .. key)
        self.pending[key] = nil
    end
end

function RP:RefreshIdentity()
    self.accountKey = AccountKey(self.account)
    self.characterKey = CharacterKey(GetUnitName("player"))
    self.rawCharacterKey = CharacterKey(GetRawUnitName("player"))
end

function RP:GetOwnScore()
    return self.saved.tally[self.account] or 0
end

function RP:OnResurrectionResult(targetCharacterName, result, targetDisplayName)
    if not self.active or not IsUnitGrouped("player") then return false, "not-active-group" end
    if result ~= RESURRECT_RESULT_SUCCESS then return false, "non-success" end
    if self.grouped == false then self:ReconcileGroup() end

    local hasAccount = type(targetDisplayName) == "string" and targetDisplayName ~= ""
    local hasCharacter = type(targetCharacterName) == "string" and targetCharacterName ~= ""
    if not hasAccount and not hasCharacter then return false, "unknown-target" end
    if hasAccount and AccountKey(targetDisplayName) == self.accountKey then
        return false, "self-account"
    end
    if hasCharacter then
        local key = CharacterKey(targetCharacterName)
        if key ~= "" and (key == self.characterKey or key == self.rawCharacterKey) then
            return false, "self-character"
        end
        if key == "" and not hasAccount then return false, "unknown-target" end
    end

    -- Count successful targets, not casts or elapsed channel time. The public
    -- event has no cast ID: do not invent time-window deduplication that could
    -- discard different targets of a multi-target resurrection.
    local count = self:GetOwnScore()
    if count == MAX_SCORE then return false, "score-limit" end
    self.saved.tally[self.account] = count + 1
    self:MarkUIDirty()
    self:QueuePublish(250)
    return true, "scored"
end

function RP:InitializeGroupBroadcast()
    local LGB = LibGroupBroadcast
    local handler = LGB:RegisterHandler(self.name)
    handler:SetDisplayName("ResParse")
    handler:SetDescription("Shares successful-resurrection totals reported by ResParse participants.")
    handler:SetApi({ GetScoresheet = function() return self:GetSortedScoresheetEntries() end })
    local protocol = handler:DeclareProtocol(self.protocolId, self.protocolName)
    protocol:SetDisplayName("ResParse Scoresheet")
    protocol:SetDescription("Synchronizes each sender's own successful-resurrection total.")
    -- Preserve the 0.3.0 wire layout. Changing it needs a coordinated protocol
    -- revision; names alone do not negotiate different payload layouts.
    protocol:AddField(LGB.CreateFlagField("requestSync", { defaultValue = false }))
    protocol:AddField(LGB.CreateNumericField("resurrectionCount", {
        minValue = 0, maxValue = MAX_SCORE, defaultValue = 0,
    }))
    protocol:OnData(function(unitTag, data) self:OnScoresheetData(unitTag, data) end)
    assert(protocol:Finalize({
        isRelevantInCombat = true, -- The visible group scoresheet updates in combat.
        replaceQueuedMessages = true,
    }), "ResParse: protocol 340 could not be finalized; inspect LibGroupBroadcast's log.")
    self.protocol = protocol
    -- Reserved custom event 4 is not emitted or required by this build.
end

function RP:QueuePublish(delay)
    if not self.active or not IsUnitGrouped("player") then return end
    local sinceLast = GetFrameTimeMilliseconds() - (self.lastPublishAt or -SEND_INTERVAL_MS)
    delay = math.max(delay, SEND_INTERVAL_MS - sinceLast)
    self:ScheduleTask("Send", delay, self.publishCallback)
end

function RP:PublishScoresheet()
    if not self.active or not IsUnitGrouped("player") or not self.protocol:IsEnabled() then
        return false
    end
    local request = self.syncRequested
    local queued = self.protocol:Send({
        requestSync = request,
        resurrectionCount = self:GetOwnScore(),
    })
    if queued then
        self.lastPublishAt = GetFrameTimeMilliseconds()
        if request then self.syncEnqueued = true end
    end
    return queued
end

function RP:RequestScoresheetSync()
    if not self.active or not IsUnitGrouped("player") then return end
    self.syncRequested = true
    self.syncEnqueued = false
    self:QueuePublish(250)
end

function RP:OnScoresheetData(unitTag, data)
    if not self.active or not IsUnitGrouped("player") or not IsUnitGrouped(unitTag) then return end
    local sender = GetUnitDisplayName(unitTag)
    if sender == "" or AccountKey(sender) == self.accountKey then return end
    if type(data) ~= "table" or not IsScore(data.resurrectionCount) or
        type(data.requestSync) ~= "boolean" then return end
    if self.grouped == false then self:ReconcileGroup() end

    -- Peer state is evidence of an active peer, NOT a transport acknowledgment.
    -- Until peer state arrives, preserve a pending sync bit when newer totals
    -- replace queued messages. Never clear it merely because Send returned true.
    if self.syncEnqueued then
        self.syncRequested, self.syncEnqueued = false, false
    end
    local count = data.resurrectionCount
    if self.saved.tally[sender] ~= count then
        self.saved.tally[sender] = count
        self:MarkUIDirty()
    end
    -- Authoritative SET supports the owner's explicit reset. Identical packets
    -- are idempotent; this legacy payload has NO epoch/sequence and cannot
    -- distinguish a late old total from a legitimate reset. See README.txt.
    if data.requestSync then self:QueuePublish(500) end
end

function RP:ReadRoster()
    local size = GetGroupSize()
    if size < 1 then return nil end
    local present = {}
    for index = 1, size do
        local unitTag = GetGroupUnitTagByIndex(index)
        if not unitTag or unitTag == "" then return nil end
        -- Offline members remain members. Do not filter them with DoesUnitExist.
        local name = GetUnitDisplayName(unitTag)
        if name == "" then return nil end
        present[name] = true
    end
    if not present[self.account] then return nil end
    return present
end

function RP:ClearSession()
    self:CancelTasks()
    self.saved.tally = {}
    self.syncRequested, self.syncEnqueued = false, false
    self.lastPublishAt = nil
    self:MarkUIDirty()
end

function RP:ReconcileGroup()
    if not self.active then return end
    local grouped = IsUnitGrouped("player")
    if not grouped then
        if self.grouped ~= false or next(self.saved.tally) then self:ClearSession() end
        self.grouped = false
        self:RefreshWindowVisibility()
        return
    end

    -- A fresh join starts a session. An initial grouped /reloadui preserves it.
    local needsSync = self.grouped ~= true
    if self.grouped == false then self:ClearSession() end
    self.grouped = true
    local present = self:ReadRoster()
    if present then
        local changed = false
        for name in pairs(self.saved.tally) do
            if not present[name] then
                self.saved.tally[name] = nil
                changed = true
            end
        end
        if changed then self:MarkUIDirty() end
    end
    -- An incomplete roster is not evidence that somebody left. A subsequent
    -- group update will retry pruning; there is no perpetual roster poll.
    if needsSync then self:RequestScoresheetSync() end
    self:RefreshWindowVisibility()
end

function RP:QueueRosterUpdate()
    if self.active then self:ScheduleTask("Roster", GROUP_DELAY_MS, self.rosterCallback) end
end

function RP:OnPlayerActivated()
    self.active = true
    self:RefreshIdentity()
    self:QueueRosterUpdate()
    -- Also refresh peer state after zoning, without resetting same-group scores.
    if self.grouped == true then self:RequestScoresheetSync() end
end

function RP:OnPlayerDeactivated()
    self.active = false
    self:CancelTasks()
    self:RefreshWindowVisibility()
end

function RP:OnGroupMemberJoined(isLocalPlayer)
    if isLocalPlayer and self.active then
        self:ClearSession()
        self.grouped = false
    elseif self.active and self.grouped then
        -- Advertise once; the newcomer initiates the request, not every peer.
        self:QueuePublish(750)
    end
    self:QueueRosterUpdate()
end

function RP:OnGroupMemberLeft(isLocalPlayer)
    if isLocalPlayer then
        -- Do not debounce away a leave immediately followed by a new join.
        self:ClearSession()
        self.grouped = false
        self:RefreshWindowVisibility()
    end
    self:QueueRosterUpdate()
end

function RP:RegisterEvents()
    EM:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function() self:OnPlayerActivated() end)
    EM:RegisterForEvent(self.name, EVENT_PLAYER_DEACTIVATED, function() self:OnPlayerDeactivated() end)
    EM:RegisterForEvent(self.name, EVENT_RESURRECT_RESULT, function(_, name, result, displayName)
        self:OnResurrectionResult(name, result, displayName)
    end)
    EM:RegisterForEvent(self.name, EVENT_GROUP_UPDATE, function() self:QueueRosterUpdate() end)
    EM:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_JOINED, function(_, _, _, isLocalPlayer)
        self:OnGroupMemberJoined(isLocalPlayer)
    end)
    EM:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_LEFT, function(_, _, _, isLocalPlayer)
        self:OnGroupMemberLeft(isLocalPlayer)
    end)
end

function RP:GetSortedScoresheetEntries()
    local entries = {}
    for name, count in pairs(self.saved.tally) do
        if count > 0 then entries[#entries + 1] = { displayName = name, count = count } end
    end
    table.sort(entries, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        local lowerA, lowerB = zo_strlower(a.displayName), zo_strlower(b.displayName)
        if lowerA == lowerB then return a.displayName < b.displayName end
        return lowerA < lowerB
    end)
    return entries
end

function RP:Chat(message)
    CHAT_SYSTEM:AddMessage("|c7FD7FFResParse|r: " .. message)
end

function RP:PrintScoresheet()
    local entries = self:GetSortedScoresheetEntries()
    if #entries == 0 then self:Chat("scoresheet: no successful resurrections"); return end
    self:Chat("scoresheet")
    for _, entry in ipairs(entries) do
        self:Chat(string.format("%s: %d", entry.displayName, entry.count))
    end
end

function RP:RegisterCommands()
    SLASH_COMMANDS["/resparsers"] = function() self:PrintScoresheet() end
    SLASH_COMMANDS["/resparse"] = function(text)
        if zo_strlower(zo_strtrim(text)) == "sync" then self:RequestScoresheetSync() end
    end
end

function RP:MarkUIDirty()
    self.uiDirty = true
    if self.fragment and self.fragment:IsShowing() then
        self:ScheduleTask("Draw", DRAW_DELAY_MS, self.drawCallback)
    end
end

function RP:RefreshWindowVisibility()
    if self.fragment then self.fragment:Refresh() end
end

function RP:SetWindowHidden(hidden)
    self.saved.window.hidden = hidden
    self:RefreshWindowVisibility()
end

function RP:SaveWindowPosition()
    local settings = self.saved.window
    settings.point, settings.relativePoint = TOPLEFT, TOPLEFT
    settings.x, settings.y = self.window:GetLeft(), self.window:GetTop()
end

function RP:RestoreWindowPosition()
    local settings = self.saved.window
    self.window:ClearAnchors()
    self.window:SetAnchor(settings.point, GuiRoot, settings.relativePoint, settings.x, settings.y)
end

function RP:CreateUI()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("ResParseWindow")
    self.window = window
    window:SetDimensions(self.saved.windowWidth, BASE_HEIGHT)
    window:SetHidden(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    self:RestoreWindowPosition()

    self.background = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    self.background:SetAnchorFill(window)
    self.background:SetCenterColor(0.03, 0.03, 0.03, self.saved.backgroundOpacity / 100)
    self.background:SetEdgeColor(0, 0, 0, 0)
    self.background:SetMouseEnabled(false)

    self.dragSurface = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
    self.dragSurface:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    self.dragSurface:SetDimensions(self.saved.windowWidth, 32)
    self.dragSurface:SetMouseEnabled(true)
    local title = WINDOW_MANAGER:CreateControl(nil, self.dragSurface, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetText("ResParse")
    title:SetAnchor(LEFT, self.dragSurface, LEFT, 10, 0)
    title:SetMouseEnabled(false)
    self.dragSurface:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then window:StartMoving() end
    end)
    self.dragSurface:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StopMovingOrResizing()
            self:SaveWindowPosition()
        end
    end)
    window:SetHandler("OnMoveStop", function() self:SaveWindowPosition() end)

    self.rowsControl = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
    self.rowsControl:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 34)
    self.rowsControl:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -10, -10)
    self.rowsControl:SetMouseEnabled(false)

    self.fragment = ZO_SimpleSceneFragment:New(window)
    self.fragment:SetConditional(function()
        return self.active and self.grouped == true and not self.saved.window.hidden
    end)
    self.fragment:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_FRAGMENT_SHOWN and self.uiDirty then self:UpdateUI() end
    end)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)
end

function RP:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end
    row = WINDOW_MANAGER:CreateControl(nil, self.rowsControl, CT_CONTROL)
    row:SetHeight(ROW_HEIGHT)
    row:SetMouseEnabled(false)
    row:SetAnchor(TOPLEFT, self.rowsControl, TOPLEFT, 0, (index - 1) * ROW_HEIGHT)
    row:SetAnchor(TOPRIGHT, self.rowsControl, TOPRIGHT, 0, (index - 1) * ROW_HEIGHT)
    row.nameLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.nameLabel:SetFont("ZoFontGame")
    row.nameLabel:SetAnchor(LEFT, row, LEFT, 0, 0)
    row.nameLabel:SetMaxLineCount(1)
    row.nameLabel:SetMouseEnabled(false)
    row.scoreLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.scoreLabel:SetFont("ZoFontGameBold")
    row.scoreLabel:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    row.scoreLabel:SetWidth(55)
    row.scoreLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.scoreLabel:SetMouseEnabled(false)
    self.rows[index] = row
    return row
end

function RP:UpdateUI()
    if not self.fragment or not self.fragment:IsShowing() or not self.uiDirty then return end
    self.uiDirty = false
    local entries = self:GetSortedScoresheetEntries()
    local width = self.saved.windowWidth
    for index, entry in ipairs(entries) do
        local row = self:AcquireRow(index)
        row.nameLabel:SetWidth(width - 85)
        row.nameLabel:SetText(entry.displayName)
        row.scoreLabel:SetText(tostring(entry.count))
        row:SetHidden(false)
    end
    for index = #entries + 1, #self.rows do self.rows[index]:SetHidden(true) end
    self.window:SetDimensions(width, BASE_HEIGHT + #entries * ROW_HEIGHT)
    self.dragSurface:SetDimensions(width, 32)
    self.background:SetCenterColor(0.03, 0.03, 0.03, self.saved.backgroundOpacity / 100)
end

function RP:RegisterSettings()
    LibAddonMenu2:RegisterAddonPanel("ResParseSettingsPanel", {
        type = "panel", name = "ResParse", displayName = "ResParse",
        author = "thepandalore", version = self.version, registerForRefresh = true, registerForDefaults = true,
    })
    LibAddonMenu2:RegisterOptionControls("ResParseSettingsPanel", {
        { type = "checkbox", name = "Show scoresheet",
          tooltip = "Hide the window without stopping scoring, sharing or /resparsers.",
          getFunc = function() return not self.saved.window.hidden end,
          setFunc = function(value) self:SetWindowHidden(not value) end,
          default = true },
        { type = "slider", name = "Window width", min = 200, max = 600, step = 10,
          getFunc = function() return self.saved.windowWidth end,
          setFunc = function(value)
              self.saved.windowWidth = BoundedNumber(value, 290, 200, 600)
              self:MarkUIDirty()
          end, default = 290 },
        { type = "slider", name = "Background opacity", min = 0, max = 100, step = 1,
          getFunc = function() return self.saved.backgroundOpacity end,
          setFunc = function(value)
              self.saved.backgroundOpacity = BoundedNumber(value, 86, 0, 100)
              self:MarkUIDirty()
          end, default = 86 },
        { type = "button", name = "Reset window position", func = function()
              local settings = self.saved.window
              settings.point, settings.relativePoint = CENTER, CENTER
              settings.x, settings.y = 0, 0
              self:RestoreWindowPosition()
          end },
    })
end

function RP:Initialize()
    self:LoadSavedVariables()
    self:RefreshIdentity()
    self.rosterCallback = function() self:ReconcileGroup() end
    self.publishCallback = function() self:PublishScoresheet() end
    self.drawCallback = function() self:UpdateUI() end
    self:InitializeGroupBroadcast()
    self:RegisterEvents()
    self:RegisterCommands()
    self.initialized = true
    -- Core callbacks are registered before UI construction. Programming errors
    -- surface through ESO normally; no blanket wrapper silently suppresses them.
    self:CreateUI()
    self:RegisterSettings()
end

EM:RegisterForEvent(RP.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= RP.name then return end
    EM:UnregisterForEvent(RP.name, EVENT_ADD_ON_LOADED)
    RP:Initialize()
end)
