-- DevSandbox3SurveyActions.lua: a survey site - the cluster of nodes a survey report spawns
--
-- A survey report spawns a cluster of nodes for its owner while he is near the site and takes them away again once he
-- has gone far enough; coming back spawns the next set (an alchemy survey: other plants each time). This module shows
-- that cycle for a survey of any craft: it reads the compass pins only, whatever the nodes are called.
--   site    CLUSTER_MIN located nodes within CLUSTER_M of one another. Remembered per zone in SavedVars.
--   dots    one per NODE of the site, not per known spawn location (a cluster has more nodes than the data has
--           locations), all the size of any other dot: tracker colour for a node a tracker hunts, candidate colour
--           while its name is not read, grey for anything else. No node there: one white dot on the site. So the
--           dots say whether a set stands there. Slot dots within SITE_M are left out while the site is active.
--   SPAWN   the site had no node and now has.
--   RESET   every node of the site went with the player farther than HARVEST_M from it and inside compass sight.
--           Names read before are forgotten: whatever stands there next is read afresh. That covers both ways a
--           set goes - the server took it (the next one is handed over 0.3 to 1.6 s later) and the engine recycled
--           the pins (the same nodes, back 0.1 s later) - which time alone does not tell apart.
--   HUD     one line under the compass: distance to the site, its nodes by name, how many are still unread; and a
--           large line for four seconds at SPAWN, RESET and when enough tracked nodes stand there. No sound.
-- Where the nodes go is a place, not a radius, and differs per survey (field logs: 58-60 m at one site, 87-91 m at
-- another; Reset Markers' turn-around points lie 30-140 m out), so nothing is drawn for it: the dots going is the
-- signal.
-- Log (LogUtils.Survey, LibConsoleLogger's buffer): one line per SPAWN and per RESET, the latter with the set that
-- stood there.
local Survey = {}

local PinTypeUtils = DevSandbox3.PinTypeUtils
local LogUtils = DevSandbox3.LogUtils
local SlotActions = DevSandbox3.SlotActions
local Detection = DevSandbox3.Detection

Survey.CLUSTER_M = 12       -- nodes this close to one of them...
Survey.CLUSTER_MIN = 4      -- ...and this many of them, are a survey site (a report spawns six)
Survey.SITE_M = 25          -- a node this close to the site's centre is one of its nodes
Survey.SAME_SITE_M = 60     -- a cluster this close to a remembered site is that site
Survey.NEAR_M = 250         -- a remembered site this close is the active one
Survey.HARVEST_M = 25       -- the last node vanishing with the player this close was harvested, not reset
Survey.SIGHT_M = 185        -- farther than this the compass drops pins by itself (maxDistanceM 200)
local FLASH_MS = 4000
local DOT_HEIGHT_M = 1.5
local STATUS_FONT, FLASH_FONT = "ZoFontGamepad27", "ZoFontGamepadBold48"

Survey.zoneId = nil
Survey.sites = nil          -- SavedVars list of the zone's sites; nil until one is remembered here
Survey.site = nil           -- the active site (a SavedVars record)
Survey.nodes = {}           -- node -> true: the located nodes of the active site, this tick
Survey.counts = {}          -- node key (or the compass's own words for a name the table lacks) -> how many
Survey.count, Survey.unread, Survey.tracked = 0, 0, 0
Survey.tally = ""           -- the last set seen, in words: "2 Columbine, 1 Wormwood, 3 unread"
Survey.present = nil        -- true: nodes stand there; false: seen without any; nil: not seen yet on this visit
Survey.distance = 0         -- player to the site's centre, metres
Survey.statusText, Survey.flashText = nil, nil
local spare = {}
local names = {}
local alerted, judged = false, false
local tickCount = 0
local flashUntil = 0
local goneMs                -- when the last set went, frame ms
local lastCount = 0         -- how many nodes it had

local function S() return DevSandbox3.state.savedVars.settings end
local function Wipe(t) for k in pairs(t) do t[k] = nil end end
local function Dist(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return math.sqrt(dx * dx + dz * dz)
end
local function Round(v) return math.floor(v + 0.5) end

local function EnsureHud()
    if Survey.status then return end
    local tl = WINDOW_MANAGER:CreateTopLevelWindow(DevSandbox3.name .. "_SurveyTL")
    tl:SetMouseEnabled(false)
    tl:SetAnchorFill(GuiRoot)
    local function Label(suffix, font, offsetY)
        local label = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. suffix, tl, CT_LABEL)
        label:SetFont(font)
        label:SetAnchor(TOP, tl, TOP, 0, offsetY)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(1, 1, 1, 1)
        label:SetHidden(true)
        return label
    end
    Survey.status = Label("_SurveyStatus", STATUS_FONT, 130)
    Survey.flash = Label("_SurveyFlash", FLASH_FONT, 180)
    local fragment = ZO_HUDFadeSceneFragment:New(tl)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

---The large line, for FLASH_MS.
local function Flash(text, r, g, b)
    EnsureHud()
    Survey.flashText = text
    Survey.flash:SetText(text)
    Survey.flash:SetColor(r, g, b, 1)
    Survey.flash:SetHidden(false)
    flashUntil = GetFrameTimeMilliseconds() + FLASH_MS
end

---The line under the compass; nil hides it.
local function SetStatus(text, good)
    EnsureHud()
    if text == Survey.statusText then return end
    Survey.statusText = text
    Survey.status:SetHidden(text == nil)
    if text then
        Survey.status:SetText(text)
        if good then Survey.status:SetColor(0.2, 1.0, 0.3, 1) else Survey.status:SetColor(1, 1, 1, 1) end
    end
end

local function TrackedFirst(a, b)
    local byKey = SlotActions.trackerByKey
    local ta, tb = byKey[a] ~= nil, byKey[b] ~= nil
    if ta ~= tb then return ta end
    return a < b
end

---The site's nodes in words, tracked names first: "2 Columbine, 1 Wormwood, 3 unread".
---@return string
local function Tally()
    for i = #names, 1, -1 do names[i] = nil end
    for key in pairs(Survey.counts) do names[#names + 1] = key end
    table.sort(names, TrackedFirst)
    local parts = {}
    for i = 1, #names do parts[i] = Survey.counts[names[i]] .. " " .. PinTypeUtils.Display(names[i]) end
    if Survey.unread > 0 then parts[#parts + 1] = Survey.unread .. " unread" end
    return table.concat(parts, ", ")
end

---@return string
local function StatusText(d)
    local head = string.format("SURVEY %dm", Round(d))
    if Survey.count > 0 then
        return string.format("%s  |  %d %s: %s", head, Survey.count, Survey.count == 1 and "node" or "nodes", Survey.tally)
    elseif Survey.present == nil then
        return head .. "  |  no nodes seen yet"
    end
    return head .. "  |  no nodes"
end

---Does a tracker hunt the kind of node that stands here (a flower tracker at a site of flowers)? Only then does a
---set with too few of them call for another roll.
local function HuntsKindHere()
    for tracked in pairs(SlotActions.trackerByKey) do
        local kind = PinTypeUtils.TypeOfKey(tracked)
        for key in pairs(Survey.counts) do
            if PinTypeUtils.TypeOfKey(key) == kind then return true end
        end
    end
    return false
end

---The remembered site nearest to (x, z), no farther than `within`.
local function NearestSite(x, z, within)
    local sites, best, bestD = Survey.sites, nil, nil
    if not sites then return nil end
    for i = 1, #sites do
        local d = Dist(x, z, sites[i].x, sites[i].z)
        if d <= within and (not bestD or d < bestD) then best, bestD = sites[i], d end
    end
    return best
end

local function Reset()
    Wipe(Survey.nodes); Wipe(Survey.counts)
    Survey.count, Survey.unread, Survey.tracked, Survey.tally = 0, 0, 0, ""
    Survey.present, alerted, judged = nil, false, false
    goneMs, lastCount = nil, 0
end

local function Enter(site, why)
    if Survey.site == site then return end
    Survey.site = site
    Reset()
    -- 4.21 kept measured edges with the site
    site.inX, site.inZ, site.inM, site.outX, site.outZ, site.outM = nil, nil, nil, nil, nil, nil
    LogUtils.Survey("site %s at %.1f, %.1f", why, site.x, site.z)
end

local function Leave(why)
    if not Survey.site then return end
    LogUtils.Survey("site left: %s", why)
    Survey.site = nil
    Reset()
    SetStatus(nil)
end

---Every 500 ms: is there a cluster that is a site, or a remembered site near enough?
local function FindSite(px, pz)
    local site = Survey.site
    if Detection.locatedCount >= Survey.CLUSTER_MIN then
        local c2, s2 = Survey.CLUSTER_M * Survey.CLUSTER_M, Survey.SITE_M * Survey.SITE_M
        for _, a in pairs(Detection.located) do
            local own = false
            if site then
                local dx, dz = a.x - site.x, a.z - site.z
                own = dx * dx + dz * dz <= s2
            end
            if not own then
                local n, sx, sz = 0, 0, 0
                for _, b in pairs(Detection.located) do
                    local dx, dz = a.x - b.x, a.z - b.z
                    if dx * dx + dz * dz <= c2 then n, sx, sz = n + 1, sx + b.x, sz + b.z end
                end
                if n >= Survey.CLUSTER_MIN then
                    local cx, cz = sx / n, sz / n
                    local known = NearestSite(cx, cz, Survey.SAME_SITE_M)
                    if known then Enter(known, "found again"); return end
                    local all = DevSandbox3.state.savedVars.surveySites
                    all[Survey.zoneId] = all[Survey.zoneId] or {}
                    Survey.sites = all[Survey.zoneId]
                    local new = { x = cx, z = cz }
                    Survey.sites[#Survey.sites + 1] = new
                    Enter(new, string.format("NEW (cluster of %d nodes, zone %s)", n, tostring(Survey.zoneId)))
                    return
                end
            end
        end
    end
    -- no cluster: the nearest remembered site, unless the active one still has nodes
    if Survey.count == 0 then
        local near = NearestSite(px, pz, Survey.NEAR_M)
        if near and near ~= site then Enter(near, "remembered") end
    end
end

---100 ms: the active site's nodes, and what changed since the last tick.
local function Tick()
    local s = S()
    if not s.survey then Leave("switched off"); return end
    if not Survey.zoneId then return end
    local now = GetFrameTimeMilliseconds()
    if flashUntil ~= 0 and now >= flashUntil then
        Survey.flash:SetHidden(true)
        Survey.flashText, flashUntil = nil, 0
    end
    local _, rx, ry, rz = GetUnitRawWorldPosition("player")
    local px, ph, pz = rx / 100, ry / 100, rz / 100
    tickCount = tickCount + 1
    if tickCount % 5 == 0 then FindSite(px, pz) end
    local site = Survey.site
    if not site then return end
    local d = Dist(px, pz, site.x, site.z)
    Survey.distance = d
    if d > Survey.NEAR_M then Leave("out of range"); return end
    if d <= 10 then site.h = ph end

    local cur, counts, byKey = spare, Survey.counts, SlotActions.trackerByKey
    Wipe(cur); Wipe(counts)
    local n, unread, tracked, first = 0, 0, 0, nil
    local s2 = Survey.SITE_M * Survey.SITE_M
    for _, node in pairs(Detection.located) do
        local dx, dz = node.x - site.x, node.z - site.z
        if dx * dx + dz * dz <= s2 then
            cur[node] = true
            n = n + 1
            if not first or node.addMs < first.addMs then first = node end
            local key = node.name or node.label
            if key then
                counts[key] = (counts[key] or 0) + 1
                if byKey[key] then tracked = tracked + 1 end
            else
                unread = unread + 1
            end
        end
    end
    spare, Survey.nodes = Survey.nodes, cur
    local changed = n ~= Survey.count or unread ~= Survey.unread
    Survey.count, Survey.unread, Survey.tracked = n, unread, tracked
    if n > 0 and changed then Survey.tally = Tally() end

    local was = Survey.present
    if n > 0 and was ~= true then
        Survey.present, alerted, judged = true, false, false
        LogUtils.Survey("SPAWN: %d node(s), handed over with the player %dm from the site, %s", n, Round(Dist(first.addX, first.addZ, site.x, site.z)),
            goneMs and string.format("%.1fs after the last set went", (first.addMs - goneMs) / 1000) or "first sight")
        Flash(was == false and "SPAWNED" or "SURVEY SITE", 0.2, 1.0, 0.3)
    elseif n == 0 and was == true then
        goneMs = now
        -- whatever stands on these spots next is read afresh: no pin inherits a name here
        Detection.ForgetLingeringNear(site.x, site.z, Survey.SITE_M)
        if d <= Survey.HARVEST_M then
            Survey.present = false
            LogUtils.Survey("CLEARED: last node gone with the player %dm from the site (harvested)", Round(d))
            Flash("SITE CLEARED", 1, 1, 1)
        elseif d > Survey.SIGHT_M then
            Survey.present = nil
            LogUtils.Survey("out of sight: nodes gone with the player %dm from the site, beyond compass range", Round(d))
        else
            Survey.present = false
            SlotActions.ForgetNear(site.x, site.z, Survey.SITE_M)
            LogUtils.Survey("RESET: %d node(s) gone (%s), player %dm from the site", lastCount, Survey.tally, Round(d))
            Flash("RESET", 1.0, 0.85, 0.2)
        end
    end

    if n > 0 then
        lastCount = n
        if not alerted and tracked >= s.surveyAlertAt then
            alerted = true
            local name = "TRACKED"
            for key, k in pairs(counts) do
                if byKey[key] and k == tracked then name = string.upper(PinTypeUtils.Display(key)) end
            end
            Flash(string.format("%d %s", tracked, name), 0.2, 1.0, 0.3)
        elseif not alerted and not judged and unread == 0 then
            -- every name read and too few tracked: nothing more to learn from this set
            judged = true
            if HuntsKindHere() then Flash(string.format("ONLY %d: RE-ROLL", tracked), 1.0, 0.85, 0.2) end
        end
    end
    if tickCount % 5 == 0 or changed or was ~= Survey.present then SetStatus(StatusText(d), alerted) end
end

---Is this slot inside the active site? Its dot is left out: the site draws one per node.
function Survey.Covers(slot)
    local site = Survey.site
    if not site then return false end
    local dx, dz = slot.x - site.x, slot.z - site.z
    return dx * dx + dz * dz <= Survey.SITE_M * Survey.SITE_M
end

---Draw the active site with `place(x, z, h, r, g, b, a)`; `ph` = the player's height. A dot's size says nothing:
---every dot of the site is the size of any other dot.
function Survey.Draw(place, ph)
    local site = Survey.site
    if not site then return end
    local un, byKey = S().unknownColor, SlotActions.trackerByKey
    local base = site.h or ph
    for node in pairs(Survey.nodes) do
        local h = SlotActions.GroundHeight(node.x, node.z, base) + DOT_HEIGHT_M
        local key = node.name or node.label
        local tracker = key and byKey[key]
        if tracker then
            local c = tracker.color
            place(node.x, node.z, h, c.r, c.g, c.b, c.a)
        elseif key then
            place(node.x, node.z, h, 0.6, 0.6, 0.6, 0.8)
        else
            place(node.x, node.z, h, un.r, un.g, un.b, un.a)
        end
    end
    -- no node there: one white dot on the site itself
    if Survey.count == 0 then place(site.x, site.z, base + DOT_HEIGHT_M, 1, 1, 1, 0.9) end
end

---One line for /ds3 survey.
---@return string
function Survey.Describe()
    local site = Survey.site
    local remembered = Survey.sites and #Survey.sites or 0
    if not S().survey then return "survey sites are switched off" end
    if not site then return string.format("no survey site near; %d remembered in this zone", remembered) end
    return string.format("survey site %dm away: %d node(s), %d tracked, %d unread%s; %d site(s) remembered in this zone",
        Round(Survey.distance), Survey.count, Survey.tracked, Survey.unread, Survey.count > 0 and (" (" .. Survey.tally .. ")") or "", remembered)
end

---Forget every remembered site, in every zone.
function Survey.Forget()
    local all = DevSandbox3.state.savedVars.surveySites
    for zoneId in pairs(all) do all[zoneId] = nil end
    Survey.sites = nil
    Leave("sites forgotten")
    LogUtils.Log("survey sites forgotten")
end

function Survey.Initialize()
    EnsureHud()
    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_SurveyActivated", EVENT_PLAYER_ACTIVATED, function()
        Leave("area loaded")
        Survey.zoneId = GetZoneId(GetUnitZoneIndex("player"))
        Survey.sites = DevSandbox3.state.savedVars.surveySites[Survey.zoneId]
    end)
    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_SurveyDeactivated", EVENT_PLAYER_DEACTIVATED, function() Leave("area unloading") end)
    EVENT_MANAGER:RegisterForUpdate(DevSandbox3.name .. "_Survey", 100, Tick)
end

DevSandbox3.Survey = Survey
