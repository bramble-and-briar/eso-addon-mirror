-- 1vX Helper - Nearest spot tracker
-- Shows distance + clock direction (relative to your camera) to the nearest kite spot,
-- safe place and choke point in your zone, and warns when you're close to a choke point.
--
-- CPU notes:
--  * Pins for the current zone are cached as flat number arrays; the cache is only
--    rebuilt when pins change or you change zone (not every tick).
--  * Squared distances in the loop; sqrt / atan2 only for the 3 winners.
--  * Skips the whole update when you haven't moved or turned since the last one.
--  * Skips while the tracker isn't on screen (menus, map, etc.) and stops entirely
--    when the zone has no tracked pins (re-checked slowly).
--  * Labels are only re-written when their text changes.
local addon = OneVXHelper
local T = {}
addon.Tracker = T

local NS = "OneVXHelper_Tracker"
local TWO_PI = 2 * math.pi
local EMPTY_ZONE_RATE_MS = 2000
local MOVE_EPS_CM = 50        -- 0.5m
local TURN_EPS_RAD = 0.05     -- ~3 degrees

local win, label, warnLabel
local tickRate = nil
local lastText, lastWarn

-- zone cache (parallel arrays)
local cacheZone, cacheRev = nil, -1
local cX, cZ, cType = {}, {}, {}
local cCount = 0

-- last evaluated position
local lastPX, lastPZ, lastHeading, lastEvalRev

local function C() return addon.sv.tracker end

local Update -- forward

local function SetTickRate(ms)
    if tickRate == ms then return end
    if tickRate then EVENT_MANAGER:UnregisterForUpdate(NS) end
    tickRate = ms
    if ms then EVENT_MANAGER:RegisterForUpdate(NS, ms, function() Update(false) end) end
end

local function RebuildCache(zoneId)
    local c = C()
    cCount = 0
    addon.Pins.ForEach(function(entry)
        if entry.zoneId == zoneId and entry.wx and c[entry.type] then
            cCount = cCount + 1
            cX[cCount], cZ[cCount], cType[cCount] = entry.wx, entry.wz, entry.type
        end
    end)
    cacheZone, cacheRev = zoneId, addon.Pins.revision
end

-- dx = east offset, dz = south offset (world units). Returns 1..12 "o'clock".
local function ClockDirection(dx, dz, heading)
    local targetBearing = math.atan2(dx, -dz)   -- clockwise from north
    local facing = TWO_PI - heading              -- heading is counter-clockwise from north
    local rel = targetBearing - facing
    if C().flipDirection then rel = -rel end
    rel = rel % TWO_PI
    local clock = zo_round(rel / TWO_PI * 12) % 12
    if clock == 0 then clock = 12 end
    return clock
end

local function SetText(text)
    if text ~= lastText then
        lastText = text
        label:SetText(text)
    end
end

local function SetWarn(text)
    if text ~= lastWarn then
        lastWarn = text
        if text then
            warnLabel:SetText(text)
            warnLabel:SetHidden(false)
        else
            warnLabel:SetHidden(true)
        end
    end
end

local bestD2, bestDX, bestDZ = {}, {}, {}

Update = function(force)
    if not force and win.tlw:IsHidden() then return end
    local c = C()
    local zoneId, px, _, pz = addon.Pins.GetPlayerWorldPos()

    if zoneId ~= cacheZone or cacheRev ~= addon.Pins.revision then
        RebuildCache(zoneId)
        lastPX = nil
    end

    if cCount == 0 then
        SetText(addon.unlocked and "|c999999Nearest 1vX spots (none in this zone)|r" or "")
        SetWarn(nil)
        SetTickRate(EMPTY_ZONE_RATE_MS)
        return
    end
    SetTickRate(c.updateRate)

    local heading = GetPlayerCameraHeading()
    if not force and c.skipWhenStill and lastPX
        and math.abs(px - lastPX) < MOVE_EPS_CM and math.abs(pz - lastPZ) < MOVE_EPS_CM
        and math.abs(heading - lastHeading) < TURN_EPS_RAD then
        return
    end
    lastPX, lastPZ, lastHeading = px, pz, heading

    local maxD2 = (c.maxRange * 100) ^ 2
    bestD2.kite, bestD2.safe, bestD2.choke = maxD2, maxD2, maxD2
    for i = 1, cCount do
        local dx, dz = cX[i] - px, cZ[i] - pz
        local d2 = dx * dx + dz * dz
        local t = cType[i]
        if d2 <= bestD2[t] then
            bestD2[t], bestDX[t], bestDZ[t] = d2, dx, dz
        end
    end

    local lines = {}
    local chokeDist
    do
        for _, key in ipairs(addon.Pins.ORDER) do
            if bestDX[key] then
                local dist = math.sqrt(bestD2[key]) / 100
                local def = addon.Pins.TYPES[key]
                lines[#lines + 1] = string.format("|c%s%s|r  %dm  |cCCCCCC@ %d o'clock|r",
                    def.hex, def.label, zo_round(dist), ClockDirection(bestDX[key], bestDZ[key], heading))
                if key == "choke" then chokeDist = dist end
            end
        end
    end
    bestDX.kite, bestDX.safe, bestDX.choke = nil, nil, nil

    if #lines == 0 then
        SetText(addon.unlocked and "|c999999Nearest 1vX spots (none in range)|r" or "")
    else
        SetText(table.concat(lines, "\n"))
    end

    if c.chokeWarn and c.choke and chokeDist and chokeDist <= c.chokeWarnRange then
        SetWarn(string.format("CHOKE POINT  %dm", zo_round(chokeDist)))
    else
        SetWarn(nil)
    end
end

function T.Apply()
    local enabled = C().enabled
    addon.UI.SetEnabled(win, enabled)
    cacheRev = -1          -- settings may have changed which types are tracked
    lastText, lastWarn = nil, nil
    if enabled then
        SetTickRate(C().updateRate)
        Update(true)
    else
        SetTickRate(nil)
    end
end

function T.Init()
    win = addon.UI.CreateWindow("Tracker", 280, 80, -560, 120, { title = "Spot Tracker" })
    label = addon.UI.Label("OneVXHelper_TrackerLabel", win.content, addon.UI.Font("MEDIUM_FONT", 16, "soft-shadow-thick"))
    label:SetAnchor(TOPLEFT, win.content, TOPLEFT, 4, 2)
    label:SetWidth(272)

    warnLabel = addon.UI.Label("OneVXHelper_TrackerWarn", win.content, addon.UI.Font("BOLD_FONT", 20, "thick-outline"), 1, 0.55, 0.1, 1)
    warnLabel:SetAnchor(TOPLEFT, win.content, BOTTOMLEFT, 4, 2)
    warnLabel:SetHidden(true)

    win.onPreview = function() if tickRate then lastText = nil; Update(true) end end
    T.Apply()
end
