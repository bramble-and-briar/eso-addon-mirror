--[[
    AetherPath - Tamriel Tomes (pinned challenges) panel
    Drawn below the quest tracker with the same look (colors, fonts, header).

    DATA SOURCE: Tomes.provider() must return a list of
        { name = "...", current = 3, max = 10, complete = false, claims = "2/6" (optional) }
    Until the provider is wired to the real pinned-challenge API, run
        /aether tomesdump
    and send the chat output so the provider can be finished.
]]

AetherPath = AetherPath or {}
local AP = AetherPath
AP.Tomes = AP.Tomes or {}
local Tomes = AP.Tomes

local PADDING  = 10
local WIDTH    = 300
local HEADER_H = 26
local GAP      = 6

-------------------------------------------------
-- Default data provider (Timed Activities / Tamriel Tomes challenges)
-------------------------------------------------
-- Returns list of:
--   { name, text, current, max, complete, claims (optional) }
-- Prefers pinned challenges when IsTimedActivityPinned exists;
-- otherwise shows incomplete weekly/seasonal activities.
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if not results[1] then return nil end
    return select(2, unpack(results))
end

local function isPinned(index)
    -- Optional pin APIs (names vary by patch); any success counts as pinned.
    local candidates = {
        "IsTimedActivityPinned",
        "IsTimedActivityTracked",
        "IsTimedActivityPinnedToTracker",
    }
    for _, name in ipairs(candidates) do
        local fn = rawget(_G, name)
        if type(fn) == "function" then
            local ok, result = pcall(fn, index)
            if ok and result then return true end
        end
    end
    return false
end

local function getClaimsString(index)
    local claimsFn = rawget(_G, "GetTimedActivityNumClaims")
        or rawget(_G, "GetTimedActivityClaimCount")
        or rawget(_G, "GetTimedActivityCompletions")
    local maxClaimsFn = rawget(_G, "GetTimedActivityMaxClaims")
        or rawget(_G, "GetTimedActivityMaxCompletions")
    if type(claimsFn) ~= "function" then return nil end
    local ok, cur = pcall(claimsFn, index)
    if not ok or cur == nil then return nil end
    if type(maxClaimsFn) == "function" then
        local ok2, mx = pcall(maxClaimsFn, index)
        if ok2 and mx and mx > 0 then
            return string.format("%d/%d", cur, mx)
        end
    end
    return tostring(cur)
end

local function DefaultProvider()
    -- Official pin API: at most one Timed Activity is tracked (pinned to HUD).
    -- GetTrackedTimedActivityInfo() -> index (nilable), encodedId
    local getTracked = rawget(_G, "GetTrackedTimedActivityInfo")
    local getName = rawget(_G, "GetTimedActivityName")
    local getProg = rawget(_G, "GetTimedActivityProgress")
    local getMax  = rawget(_G, "GetTimedActivityMaxProgress")
    local getDesc = rawget(_G, "GetTimedActivityDescription")
    local getClaims = rawget(_G, "GetTimedActivityNumTimesClaimed")
    local getMaxClaims = rawget(_G, "GetTimedActivityTotalNumTimesClaimable")

    if type(getTracked) ~= "function" or type(getName) ~= "function" then
        return nil
    end

    local ok, index = pcall(getTracked)
    if not ok or index == nil then
        return {}  -- nothing pinned
    end

    local okN, name = pcall(getName, index)
    if not okN or not name or name == "" then
        return {}
    end

    local current, maximum = 0, 0
    if type(getProg) == "function" then
        local o, v = pcall(getProg, index)
        if o and v then current = v end
    end
    if type(getMax) == "function" then
        local o, v = pcall(getMax, index)
        if o and v then maximum = v end
    end

    local text = name
    if type(getDesc) == "function" then
        local o, d = pcall(getDesc, index)
        if o and d and d ~= "" then text = d end
    end

    local claims
    if type(getClaims) == "function" and type(getMaxClaims) == "function" then
        local o1, c = pcall(getClaims, index)
        local o2, m = pcall(getMaxClaims, index)
        if o1 and o2 and c ~= nil and m ~= nil and m > 0 then
            claims = string.format("%d/%d", c, m)
        end
    end

    return {
        {
            name = name,
            text = text,
            current = current,
            max = maximum,
            complete = maximum > 0 and current >= maximum,
            claims = claims,
        },
    }
end

Tomes.provider = DefaultProvider

-------------------------------------------------
-- Safe global iteration (pairs(_G) can hit private C APIs)
-------------------------------------------------
-- ESO marks many globals as private; merely retrieving them from insecure
-- code throws "Attempt to access a private function 'X' from insecure code".
-- Walk _G with pcall(next, ...) so a single private key cannot crash the addon.
local function forEachGlobal(fn)
    local ok, k, v = pcall(next, _G, nil)
    while ok and k ~= nil do
        pcall(fn, k, v)
        ok, k, v = pcall(next, _G, k)
    end
end

-------------------------------------------------
-- Discovery helpers (used by /aether tomesdump and native hide)
-------------------------------------------------
local function matchAny(name, patterns)
    local up = string.upper(name)
    for _, p in ipairs(patterns) do
        if not string.find(up, p, 1, true) then return false end
    end
    return true
end

local function collectGlobals(patterns)
    local out = {}
    forEachGlobal(function(k, v)
        if type(k) == "string" and matchAny(k, patterns) then
            out[#out + 1] = string.format("%s (%s)", k, type(v))
        end
    end)
    table.sort(out)
    return out
end

function Tomes:Dump()
    local function say(s) d("|c88AAFFAetherPath/Tomes|r " .. s) end
    local groups = {
        { "TOME (globals)",               { "TOME" } },
        { "PIN/TRACK + CHALLENGE",        { "CHALLENGE" } },
    }
    for _, g in ipairs(groups) do
        local list = collectGlobals(g[2])
        say(string.format("%s: %d", g[1], #list))
        for i = 1, math.min(#list, 120) do say("  " .. list[i]) end
    end
    local mgr = rawget(_G, "TAMRIEL_TOMES_MANAGER")
    if type(mgr) == "table" then
        local names = {}
        for k, v in pairs(mgr) do
            if type(v) == "function" then names[#names + 1] = k end
        end
        table.sort(names)
        say("TAMRIEL_TOMES_MANAGER methods: " .. table.concat(names, ", "))
    end
end

-- Native pinned-challenge tracker fragment(s): any global *FRAGMENT with TOME + TRACK/PIN
function Tomes:FindNativeFragments()
    if self.nativeFragments then return self.nativeFragments end
    local found = {}
    forEachGlobal(function(k, v)
        if type(k) == "string" and type(v) == "table" and string.find(k, "FRAGMENT", 1, true) then
            local up = string.upper(k)
            if string.find(up, "TOME", 1, true)
               and (string.find(up, "TRACK", 1, true) or string.find(up, "PIN", 1, true)
                    or string.find(up, "CHALLENGE", 1, true)) then
                found[#found + 1] = v
            end
        end
    end)
    self.nativeFragments = found
    return found
end

function Tomes:HideNative(hide)
    for _, frag in ipairs(self:FindNativeFragments()) do
        if frag.SetHiddenForReason then
            frag:SetHiddenForReason("AetherPath", hide and true or false, 0, 0)
        end
    end
end

-------------------------------------------------
-- UI (child of the tracker frame: inherits scale, alpha, scene visibility)
-------------------------------------------------
function Tomes:CreateFrame(parent)
    local f = WINDOW_MANAGER:CreateControl("AetherPathTomes", parent, CT_CONTROL)
    f:SetDimensions(WIDTH, 60)
    f:SetAnchor(TOPLEFT, parent, BOTTOMLEFT, 0, GAP)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", f, CT_BACKDROP)
    bg:SetAnchorFill(f)
    bg:SetEdgeTexture("", 1, 1, 1)
    bg:SetInsets(1, 1, 1, 1)
    self.bg = bg

    local header = WINDOW_MANAGER:CreateControl("$(parent)Header", f, CT_CONTROL)
    header:SetDimensions(WIDTH, HEADER_H)
    header:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0)

    local hbg = WINDOW_MANAGER:CreateControl("$(parent)HBg", header, CT_BACKDROP)
    hbg:SetAnchorFill(header)
    hbg:SetEdgeColor(0, 0, 0, 0)
    self.headerBg = hbg

    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", header, CT_LABEL)
    title:SetFont("ZoFontGameSmall")
    title:SetAnchor(LEFT, header, LEFT, PADDING, 0)
    self.titleLabel = title

    local counter = WINDOW_MANAGER:CreateControl("$(parent)Counter", header, CT_LABEL)
    counter:SetFont("ZoFontGameSmall")
    counter:SetAnchor(RIGHT, header, RIGHT, -PADDING, 0)
    self.counterLabel = counter

    local body = WINDOW_MANAGER:CreateControl("$(parent)Body", f, CT_LABEL)
    body:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    body:SetAnchor(TOPLEFT, header, BOTTOMLEFT, PADDING, 6)
    body:SetDimensions(WIDTH - PADDING * 2, 0)
    self.body = body

    self.frame = f
    f:SetHidden(true)
end

function Tomes:Initialize()
    self.nativeFragments = nil
    local ui = AP.UI
    if not ui or not ui.trackerFrame then return end
    self:CreateFrame(ui.trackerFrame)
    self:ApplyTheme()

    if not self.provider then
        self.provider = DefaultProvider
    end

    -- Refresh on Tome / Timed Activity events (safe scan of _G)
    forEachGlobal(function(k, v)
        if type(k) == "string" and type(v) == "number" and string.sub(k, 1, 6) == "EVENT_" then
            local up = string.upper(k)
            if string.find(up, "TOME", 1, true)
               or string.find(up, "TIMED_ACTIVITY", 1, true) then
                EVENT_MANAGER:RegisterForEvent("AetherPath_Tomes_" .. k, v, function() self:Refresh() end)
            end
        end
    end)
    -- Known manager callbacks when present
    local mgr = rawget(_G, "TIMED_ACTIVITIES_MANAGER")
    if type(mgr) == "table" and type(mgr.RegisterCallback) == "function" then
        pcall(function()
            mgr:RegisterCallback("OnActivitiesUpdated", function() self:Refresh() end)
            mgr:RegisterCallback("OnActivityUpdated", function() self:Refresh() end)
        end)
    end
    EVENT_MANAGER:RegisterForEvent("AetherPath_Tomes_Active", EVENT_PLAYER_ACTIVATED, function()
        self:HideNative(AP.sv.showTomes ~= false)
        self:Refresh()
    end)
end

function Tomes:ApplyTheme()
    if not self.frame then return end
    local c = AP.Colors
    local a = (AP.sv and AP.sv.trackerAlpha) or 0.94
    self.bg:SetCenterColor(c.bg[1], c.bg[2], c.bg[3], a)
    self.bg:SetEdgeColor(unpack(c.border))
    self.headerBg:SetCenterColor(unpack(c.bgHeader))
    self.titleLabel:SetColor(unpack(c.textDim))
    self.counterLabel:SetColor(unpack(c.textDim))
end

-------------------------------------------------
-- Rendering
-------------------------------------------------
function Tomes:GetData()
    if type(self.provider) ~= "function" then return nil end
    return self.provider()
end

function Tomes:Refresh()
    if not self.frame then return end
    self:ApplyTheme()

    local enabled = AP.sv and AP.sv.showTomes ~= false
    self:HideNative(enabled)
    local list = enabled and self:GetData() or nil
    if not enabled or (list and #list == 0) then
        self.frame:SetHidden(true)
        return
    end

    local titleFont = AP.SafeFont(AP.sv.titleFont)
    local stepFont  = AP.SafeFont(AP.sv.stepFont)
    local stepCol   = AP.sv.stepColor or AP.Colors.incomplete
    local titleCol  = AP.sv.titleColor or AP.Colors.accent

    self.titleLabel:SetText(AP.L("TOMES_TITLE"))
    self.body:SetFont(stepFont)

    if not list then
        self.counterLabel:SetText("")
        self.body:SetColor(unpack(AP.Colors.textDim))
        self.body:SetText(AP.L("TOMES_NO_API"))
    else
        self.counterLabel:SetText(tostring(#list))
        local hex = function(c) return string.format("|c%02X%02X%02X", c[1]*255, c[2]*255, c[3]*255) end
        local lines = {}
        for _, ch in ipairs(list) do
            lines[#lines + 1] = hex(titleCol) .. (ch.name or "?") .. "|r"
            local mark = ch.complete and "✓ " or "• "
            local prog = (ch.max and ch.max > 0) and string.format(" (%d/%d)", ch.current or 0, ch.max) or ""
            local claims = ch.claims and ("  [" .. ch.claims .. "]") or ""
            local col = ch.complete and AP.Colors.complete or stepCol
            lines[#lines + 1] = hex(col) .. mark .. (ch.text or "") .. prog .. claims .. "|r"
        end
        self.body:SetColor(1, 1, 1, 1)
        self.body:SetText(table.concat(lines, "\n"))
    end

    self.body:SetDimensions(WIDTH - PADDING * 2, 0)
    local h = self.body:GetTextHeight() or 30
    if h > 200 then h = 200 end
    self.body:SetHeight(h)
    self.frame:SetHeight(HEADER_H + 6 + h + 10)
    self.frame:SetHidden(false)
end
