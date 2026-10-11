-- Pact Watch 0.1.0. Original implementation by @TheGreyWolf98.
-- Counts are siege weapons / reported deaths, never inferred player totals.
PactWatch = { name = "PactWatch", version = "0.1.4", keeps = {}, activity = {},
    recurrence = {}, errors = {}, campaignRows = {}, page = 1, scans = 0, killEvents = 0 }
local PW = PactWatch
local defaults = { enabled = true, chat = true, sound = true, resources = true,
    hud = false, debug = false, autoOpen = false, x = 0, y = 0, log = {} }
local EP, AD, DC = ALLIANCE_EBONHEART_PACT, ALLIANCE_ALDMERI_DOMINION, ALLIANCE_DAGGERFALL_COVENANT
local function now() return GetFrameTimeSeconds() end
local function clean(s)
    if type(s) ~= "string" or s == "" then return "Unknown location" end
    return zo_strformat("<<1>>", s)
end
local function number(v) return type(v) == "number" and v or nil end
function PW:Chat(s)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage("|cE45757[Pact Watch]|r " .. s)
    elseif d then d("[Pact Watch] " .. s) end
end
function PW:Log(s)
    if not self.sv then return end
    local line = (GetTimeString and GetTimeString() or tostring(math.floor(now()))) .. " " .. s
    table.insert(self.sv.log, line)
    if #self.sv.log > 150 then table.remove(self.sv.log, 1) end
    if self.sv.debug then self:Chat(line) end
end
function PW:Read(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        if not self.errors[name] then self.errors[name] = "unavailable"; self:Log("API unavailable: " .. name) end
        return nil
    end
    local ok, a, b, c, e = pcall(fn, ...)
    if not ok then
        if not self.errors[name] then self.errors[name] = tostring(a); self:Log("API error: " .. name .. " " .. tostring(a)) end
        return nil
    end
    return a, b, c, e
end
function PW:IsPact() return self:Read("GetUnitAlliance", "player") == EP end
function PW:Inside() return self:Read("IsInCyrodiil") == true end
function PW:Running() return self.sv and self.sv.enabled and self:IsPact() and self:Inside() end
function PW:WatchType(kind)
    return kind == KEEPTYPE_KEEP or kind == KEEPTYPE_OUTPOST or
        (self.sv.resources and kind == KEEPTYPE_RESOURCE)
end
function PW:Alert(key, text)
    local t = now()
    self.alertTimes = self.alertTimes or {}
    if self.alertTimes[key] and t - self.alertTimes[key] < 20 then return end
    self.alertTimes[key] = t
    self:Log("ALERT " .. text)
    if self.sv.chat then self:Chat(text) end
    if self.sv.sound and (not self.lastSound or t - self.lastSound >= 5) then
        self.lastSound = t
        if SOUNDS and SOUNDS.DEFAULT_CLICK and PlaySound then pcall(PlaySound, SOUNDS.DEFAULT_CLICK) end
    end
end
function PW:Touch(key, name, detail, priority)
    local a = self.activity[key]
    if not a then
        -- Bound location history independently of ESO's event volume.
        local count, oldestKey, oldest = 0, nil, math.huge
        for k, v in pairs(self.activity) do count = count + 1; if v.last < oldest then oldest, oldestKey = v.last, k end end
        if count >= 120 and oldestKey then self.activity[oldestKey] = nil end
        a = { key = key, name = clean(name), deaths = {}, sides = {} }; self.activity[key] = a
    end
    a.last, a.detail, a.priority = now(), detail, priority or 0
    return a
end
function PW:ResetSession(id)
    self.campaignId = id
    self.keeps, self.activity, self.recurrence, self.alertTimes = {}, {}, {}, {}
    self.scans, self.killEvents, self.preflagSeen = 0, 0, 0
    self.lastScan, self.readCount = nil, 0
    self.emperor, self.emperorSeen, self.hammer, self.hammerHidden = nil, nil, nil, nil
    self.sessionStart = now()
    self:Log("Session started: campaign " .. tostring(id) .. "; map state " .. self:MapState())
end
function PW:MapState()
    return ZO_WorldMap and not ZO_WorldMap:IsHidden() and "open" or "closed"
end
function PW:ProcessKeep(k, initial)
    local old = self.keeps[k.id]
    local watched = self:WatchType(k.kind)
    local siegeKnown = k.ad ~= nil and k.dc ~= nil
    local enemy = siegeKnown and (k.ad + k.dc) or (old and old.lastEnemy or 0)
    local oldEnemy = old and (old.lastEnemy or ((old.ad or 0) + (old.dc or 0))) or 0
    k.lastEnemy = enemy
    local detail = string.format("Owner %s | Siege AD:%s DC:%s EP:%s | %s", self:Alliance(k.owner),
        tostring(k.ad or "?"), tostring(k.dc or "?"), tostring(k.ep or "?"),
        k.flag == true and "FLAGGED" or (k.flag == false and "not flagged" or "flag unknown"))
    if watched and ((siegeKnown and enemy > 0) or k.flag == true) then
        local a = self:Touch("keep:" .. k.id, k.name, detail, k.owner == EP and 100 or 30)
        a.active = true
    elseif siegeKnown and k.flag == false and self.activity["keep:" .. k.id] then
        local a = self.activity["keep:" .. k.id]
        if a.active then a.last, a.detail, a.active = now(), detail .. " | activity cleared", false end
    end
    if old and watched and old.owner ~= k.owner and k.owner ~= nil then
        self:Touch("keep:" .. k.id, k.name, "Ownership changed: " .. self:Alliance(old.owner) .. " > " .. self:Alliance(k.owner), 80)
        if old.owner == EP or k.owner == EP then
            self:Alert("owner:" .. k.id, k.name .. (k.owner == EP and " reclaimed by Pact." or " lost to " .. self:Alliance(k.owner) .. "."))
        end
    end
    if watched and k.owner == EP then
        if siegeKnown and enemy > 0 and (not old or oldEnemy == 0) then
            if k.flag == false then self.preflagSeen = (self.preflagSeen or 0) + 1 end
            self:Log(string.format("SIEGE %s AD=%s DC=%s flagged=%s map=%s%s", k.name,
                tostring(k.ad), tostring(k.dc), tostring(k.flag), self:MapState(), initial and " baseline" or ""))
            -- Initial scan is shown in the board/log; don't sound dozens of alarms on arrival.
            if not initial then self:Alert("siege:" .. k.id, "Enemy siege at " .. k.name .. ": AD " .. tostring(k.ad or "?") ..
                ", DC " .. tostring(k.dc or "?") .. (k.flag == false and ". Not yet flagged." or ".")) end
        elseif siegeKnown and old and enemy ~= oldEnemy and enemy > 0 then
            self:Log("SIEGE COUNT " .. k.name .. " AD=" .. tostring(k.ad) .. " DC=" .. tostring(k.dc))
        end
        if k.flag == true and old and old.flag == false then
            self:Alert("flag:" .. k.id, k.name .. " is now FLAGGED! AD siege " .. tostring(k.ad or "?") .. ", DC " .. tostring(k.dc or "?"))
        elseif k.flag == false and old and old.flag == true then self:Log("FLAG CLEARED " .. k.name) end
    end
    self.keeps[k.id] = k
end
function PW:Scan()
    if not self:Running() then return end
    local id = self:Read("GetCurrentCampaignId")
    if not id or id == 0 then return end
    if self.campaignId ~= id then self:ResetSession(id) end
    local count = number(self:Read("GetNumKeeps")) or 0
    local seen = {}
    local initial = self.scans == 0
    local readCount = 0
    for i = 1, count do
        local keepId, ctx = self:Read("GetKeepKeysByIndex", i)
        local match = ctx == BGQUERY_LOCAL or ctx == BGQUERY_ASSIGNED_AND_LOCAL
        if not match and ctx and type(DoBattlegroundContextsIntersect) == "function" then
            match = self:Read("DoBattlegroundContextsIntersect", ctx, BGQUERY_LOCAL) == true
        end
        if keepId and match and not seen[keepId] then
            seen[keepId] = true
            local name = self:Read("GetKeepName", keepId)
            local owner = self:Read("GetKeepAlliance", keepId, BGQUERY_LOCAL)
            if name and name ~= "" and owner ~= nil then
                readCount = readCount + 1
                self:ProcessKeep({ id = keepId, name = clean(name), owner = owner,
                    kind = self:Read("GetKeepType", keepId),
                    ad = number(self:Read("GetNumSieges", keepId, BGQUERY_LOCAL, AD)),
                    dc = number(self:Read("GetNumSieges", keepId, BGQUERY_LOCAL, DC)),
                    ep = number(self:Read("GetNumSieges", keepId, BGQUERY_LOCAL, EP)),
                    flag = self:Read("GetKeepUnderAttack", keepId, BGQUERY_LOCAL) }, initial)
            end
        end
    end
    self:ScanSpecials(initial)
    if readCount > 0 then self.scans, self.lastScan, self.readCount = self.scans + 1, now(), readCount end
    if initial and readCount > 0 then self:Log("Baseline: " .. readCount .. " keep records; no arrival alarm spam") end
end
function PW:Alliance(a)
    if a == EP then return "EP" elseif a == AD then return "AD" elseif a == DC then return "DC" end
    return "?"
end
function PW:ColourAlliance(a, text)
    local colours = { [EP] = "F26666", [AD] = "F5D75C", [DC] = "70B5FF" }
    return "|c" .. (colours[a] or "BBBBBB") .. tostring(text) .. "|r"
end
function PW:KeepDetail(k)
    local sides = {}
    for _, pair in ipairs({ { AD, k.ad }, { DC, k.dc }, { EP, k.ep } }) do
        if pair[2] and pair[2] > 0 then table.insert(sides, self:ColourAlliance(pair[1], self:Alliance(pair[1]) .. " " .. pair[2])) end
    end
    local state = k.flag == true and "|cFF6666FLAGGED|r" or (k.flag == false and "Not flagged" or "Flag unknown")
    return state .. " | " .. (#sides > 0 and ("Siege: " .. table.concat(sides, " / ")) or "No siege reported; attacker unknown")
end
function PW:ScanSpecials(initial)
    local id = self.campaignId
    if type(GetCampaignEmperorInfo) == "function" then
        local side, name, account = self:Read("GetCampaignEmperorInfo", id)
        local identity = tostring(side) .. ":" .. tostring(account) .. ":" .. tostring(name)
        if not self.emperor or self.emperor.identity ~= identity then self.emperorSeen = nil end
        self.emperor = { side = side, name = name, account = account, identity = identity }
    end
    if not (OBJECTIVE_DAEDRIC_WEAPON and type(GetNumObjectives) == "function") then return end
    local found
    for i = 1, self:Read("GetNumObjectives") or 0 do
        local keep, objective, ctx = self:Read("GetObjectiveIdsForIndex", i)
        if (ctx == BGQUERY_LOCAL or ctx == BGQUERY_ASSIGNED_AND_LOCAL) and
            self:Read("GetObjectiveType", keep, objective, BGQUERY_LOCAL) == OBJECTIVE_DAEDRIC_WEAPON then
            local pin, x, y = self:Read("GetObjectivePinInfo", keep, objective, BGQUERY_LOCAL)
            local state = self:Read("GetObjectiveControlState", keep, objective, BGQUERY_LOCAL)
            if self:IsRevealedHammerState(state) and pin and pin ~= MAP_PIN_TYPE_INVALID and type(x) == "number" and type(y) == "number" and x > 0 and y > 0 and x <= 1 and y <= 1 then
                found = { key = tostring(keep) .. ":" .. tostring(objective), last = now(), location = "Location not available on this map" }
                local side = self:Read("GetCarryableObjectiveHoldingAllianceInfo", keep, objective, BGQUERY_LOCAL)
                found.side = side
                found.state, found.confirmed = self:HammerState(state), true
                -- Compare only pins on the current Cyrodiil map; never change the player's map.
                if type(GetMapContentType) == "function" and self:Read("GetMapContentType") == MAP_CONTENT_AVA and
                    self:Read("DoesCurrentMapShowPlayerWorld") == true then
                    local nearest, distance = nil, math.huge
                    for _, k in pairs(self.keeps) do
                        if k.kind == KEEPTYPE_KEEP or k.kind == KEEPTYPE_OUTPOST then
                            local _, kx, ky = self:Read("GetKeepPinInfo", k.id, BGQUERY_LOCAL)
                            if type(kx) == "number" and type(ky) == "number" and kx > 0 and ky > 0 then
                                local d = (kx-x)^2 + (ky-y)^2
                                if d < distance then nearest, distance = k.name, d end
                            end
                        end
                    end
                    if nearest then found.location = "Nearest keep: " .. nearest end
                end
                if not found.location:find("Nearest keep:", 1, true) and self.hammer and self.hammer.key == found.key and self.hammer.locationTime then
                    found.location, found.locationTime = self.hammer.location, self.hammer.locationTime
                end
                if found.location:find("Nearest keep:", 1, true) and not found.locationTime then found.locationTime = now() end
                break
            end
        end
    end
    if found then
        local old = self.hammer
        if not old and not initial then self:Alert("hammer", "Volendrung spotted: " .. self:ColourAlliance(found.side, found.state) .. ". " .. found.location) end
        self.hammer, self.hammerHidden = found, nil
    elseif self.hammer then self.hammer.confirmed = false end
    -- Missing pins can mean a map change or temporarily unavailable client data.
    -- Keep the report as a dated sighting; never turn missing data into despawn.
    if self.hammer and now() - self.hammer.last > 600 then self.hammer = nil end
end
function PW:IsRevealedHammerState(state)
    return state ~= nil and ((OBJECTIVE_CONTROL_STATE_FLAG_HELD ~= nil and state == OBJECTIVE_CONTROL_STATE_FLAG_HELD) or
        (OBJECTIVE_CONTROL_STATE_FLAG_DROPPED ~= nil and state == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED) or
        (OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE ~= nil and state == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE))
end
function PW:HammerState(state)
    if state ~= nil and state == OBJECTIVE_CONTROL_STATE_FLAG_HELD then return "carried" end
    if state ~= nil and (state == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED or state == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE) then return "on ground" end
    return "state unknown"
end
function PW:OnHammerState(_, keep, objective, ctx, controlEvent, state, side)
    if not self:Running() or (ctx ~= BGQUERY_LOCAL and ctx ~= BGQUERY_ASSIGNED_AND_LOCAL) then return end
    local key = tostring(keep) .. ":" .. tostring(objective)
    if not self:IsRevealedHammerState(state) then
        if self.hammer and self.hammer.key == key then self.hammer.confirmed = false end
        self:Log("Hammer event: location not confirmed; state " .. tostring(state))
        self:Render()
        return
    end
    local h = self.hammer
    if not h or h.key ~= key then h = { key = key, location = "Location not received" }; self.hammer = h end
    local before, beforeSide = h.state, h.side
    h.state, h.side, h.last = self:HammerState(state), side, now()
    self.hammerHidden = nil
    self:ScanSpecials(true)
    h = self.hammer
    if h then h.state, h.side, h.last, h.confirmed = self:HammerState(state), side, now(), true end
    if h and (before ~= h.state or beforeSide ~= h.side) then
        self:Alert("hammer-state:" .. tostring(h.state) .. ":" .. tostring(h.side), "Volendrung: " .. self:ColourAlliance(h.side, h.state) .. ". " .. h.location)
    end
    self:Render()
end
function PW:SpecialLines()
    local h = self.hammer
    local hammer = h and ("HAMMER | " .. self:ColourAlliance(h.side, (h.confirmed and "Reported " or "Last sighting: ") .. self:Alliance(h.side) .. " " .. h.state) .. " (" .. self:Age(h.last) .. " ago) | " .. h.location ..
        (h.locationTime and (" (" .. self:Age(h.locationTime) .. " ago)") or "")) or "HAMMER | No revealed hammer reported"
    if self.hammerHidden then hammer = "HAMMER | Spawn announced; location not revealed yet" end
    local e = self.emperor
    local emperor = "EMP | No emperor data received"
    if e then
        if e.side == EP then emperor = "EMP | Pact holds the throne"
        elseif e.side == AD or e.side == DC then
            emperor = "EMP | " .. self:ColourAlliance(e.side, clean(e.name)) .. " | " ..
                (self.emperorSeen and (self.emperorSeen.location .. " — kill-feed sighting " .. self:Age(self.emperorSeen.last) .. " ago") or "Location unknown; awaiting kill-feed sighting")
        else emperor = "EMP | No emperor reported" end
    end
    return hammer, emperor
end
function PW:Population(v)
    if v == nil then return "unknown" end
    if v == CAMPAIGN_POP_LOW then return "LOW" elseif v == CAMPAIGN_POP_MEDIUM then return "MEDIUM"
    elseif v == CAMPAIGN_POP_HIGH then return "HIGH" elseif v == CAMPAIGN_POP_FULL then return "FULL" end
    return "unknown"
end
function PW:RequestBriefing()
    if not self:IsPact() then return end
    if self.lastRequest and now() - self.lastRequest < 30 then return end
    self.lastRequest = now()
    self:Read("QueryCampaignSelectionData")
    if not self.assignedRegistered then
        self:Read("RegisterForAssignedCampaignData"); self.assignedRegistered = true
    end
end
function PW:SelectionReady()
    self.selectionTime = now()
    self.campaignRows = {}
    local count = number(self:Read("GetNumSelectionCampaigns")) or 0
    for i = 1, count do
        local id = self:Read("GetSelectionCampaignId", i)
        if id and self:Read("IsImperialCityCampaign", id) ~= true then
            local r = { id = id, name = clean(self:Read("GetCampaignName", id)), pop = {}, scores = {} }
            for _, a in ipairs({ EP, AD, DC }) do
                r.pop[a] = self:Population(self:Read("GetSelectionCampaignPopulationData", i, a))
                r.scores[a] = self:Read("GetSelectionCampaignAllianceScore", i, a)
            end
            r.queue = self:Read("GetSelectionCampaignQueueWaitTime", i)
            table.insert(self.campaignRows, r)
        end
    end
    self:Log("Campaign selection received: " .. #self.campaignRows .. " Cyrodiil campaigns")
end
function PW:Holdings()
    local inside = self:Inside()
    local id = self:Read(inside and "GetCurrentCampaignId" or "GetAssignedCampaignId")
    if not id or id == 0 then return "Home campaign not assigned / data unavailable" end
    local ctx = inside and BGQUERY_LOCAL or BGQUERY_ASSIGNED_CAMPAIGN
    local counts = { [EP] = { 0, 0, 0 }, [AD] = { 0, 0, 0 }, [DC] = { 0, 0, 0 } }
    local total = 0
    local seen = {}
    for i = 1, number(self:Read("GetNumKeeps")) or 0 do
        local k, c = self:Read("GetKeepKeysByIndex", i)
        local match = c == ctx or c == BGQUERY_ASSIGNED_AND_LOCAL
        if not match and c and type(DoBattlegroundContextsIntersect) == "function" then
            match = self:Read("DoBattlegroundContextsIntersect", c, ctx) == true
        end
        if k and match and not seen[k] then
            seen[k] = true
            local a, kind = self:Read("GetKeepAlliance", k, ctx), self:Read("GetKeepType", k)
            local slot = kind == KEEPTYPE_KEEP and 1 or (kind == KEEPTYPE_OUTPOST and 2 or (kind == KEEPTYPE_RESOURCE and 3 or nil))
            if slot and counts[a] then counts[a][slot] = counts[a][slot] + 1; total = total + 1 end
        end
    end
    if total == 0 then return clean(self:Read("GetCampaignName", id)) .. ": holdings unavailable; open Alliance War and refresh" end
    local c = counts[EP]
    return string.format("%s | Pact: %d keeps, %d outposts, %d resources%s", clean(self:Read("GetCampaignName", id)),
        c[1], c[2], c[3], inside and " (client data)" or " (home campaign client data)")
end
function PW:OnKill(_, location, killerAccount, killerName, killerAlliance, killerRank, victimAccount, victimName, victimAlliance)
    if not self:Running() then return end
    local e = self.emperor
    if e and (e.side == AD or e.side == DC) and type(e.account) == "string" and e.account ~= "" and
        (killerAccount == e.account or victimAccount == e.account) then
        self.emperorSeen = { location = clean(location), last = now() }
    end
    local t = now()
    local key = tostring(location) .. ":" .. tostring(killerAccount) .. ":" .. tostring(victimAccount)
    if self.recurrence[key] and t - self.recurrence[key] < 10 then return end
    self.recurrence[key] = t
    self.killEvents = self.killEvents + 1
    local a = self:Touch("fight:" .. clean(location), location, "Reported PvP deaths", (killerAlliance == EP or victimAlliance == EP) and 70 or 40)
    table.insert(a.deaths, { t = t, killer = killerAlliance, victim = victimAlliance })
    if #a.deaths > 300 then table.remove(a.deaths, 1) end
end
function PW:OnGuild(_, channel, guards, attackers, location)
    if not self:Running() then return end
    guards, attackers = number(guards) or 0, number(attackers)
    local detail = guards > 0 and (tostring(guards) .. " guards killed; " .. tostring(attackers or "?") .. " enemies reported by ESO") or "Guard-kill report ended"
    self:Touch("guild:" .. clean(location), location, detail, guards > 0 and 90 or 20)
    if guards > 0 then self:Alert("guild:" .. clean(location), clean(location) .. ": " .. detail) end
end
function PW:GetActivities()
    local list, t = {}, now()
    for key, a in pairs(self.activity) do
        if t - a.last > 600 then self.activity[key] = nil
        else
            local kills, sides = 0, {}
            for i = #a.deaths, 1, -1 do
                local e = a.deaths[i]
                if t - e.t > 120 then table.remove(a.deaths, i)
                else kills = kills + 1; sides[e.killer or 0] = true; sides[e.victim or 0] = true end
            end
            local text = a.detail
            if a.key:sub(1, 6) == "fight:" then
                local factions = {}
                for _, side in ipairs({ EP, AD, DC }) do if sides[side] then table.insert(factions, self:Alliance(side)) end end
                text = kills .. " reported deaths / last 2m | " .. table.concat(factions, "/")
                if kills == 0 then text = "Earlier reported deaths; no new reports in last 2m" end
            end
            local keep = key:match("^keep:(%d+)$")
            keep = keep and self.keeps[tonumber(keep)]
            if keep and a.active then text = self:KeepDetail(keep) end
            if key:sub(1, 6) == "keep:" then
                text = text:gsub("Ownership changed: (%u+) > (%u+)", function(before, after)
                    local ids = { EP = EP, AD = AD, DC = DC }
                    return "Ownership: " .. self:ColourAlliance(ids[before], before) .. " > " .. self:ColourAlliance(ids[after], after)
                end)
            end
            table.insert(list, { name = a.name, owner = keep and keep.owner, detail = text, last = a.last,
                priority = (a.priority or 0) + math.min(kills, 30) - math.min(60, (t - a.last) / 5) })
        end
    end
    for key, t0 in pairs(self.recurrence) do if t - t0 > 10 then self.recurrence[key] = nil end end
    table.sort(list, function(a, b) if a.priority == b.priority then return a.last > b.last end; return a.priority > b.priority end)
    return list
end
function PW:Age(t)
    if not t then return "unknown" end
    local s = math.max(0, math.floor(now() - t))
    return s < 60 and (s .. "s") or (math.floor(s / 60) .. "m " .. s % 60 .. "s")
end
function PW:Diagnostics()
    self:Chat("v" .. self.version .. " | API " .. tostring(self:Read("GetAPIVersion")) .. " | Pact " .. tostring(self:IsPact()) ..
        " | Cyrodiil " .. tostring(self:Inside()) .. " | map " .. self:MapState())
    self:Chat("Scans " .. self.scans .. " | keep records " .. tostring(self.readCount or 0) .. " | scan age " .. self:Age(self.lastScan) ..
        " | death reports " .. self.killEvents .. " | unflagged siege observations " .. tostring(self.preflagSeen or 0))
    for _, fn in ipairs({ "GetNumSieges", "GetKeepUnderAttack", "GetKeepKeysByIndex", "QueryCampaignSelectionData" }) do
        self:Chat(fn .. ": " .. (self.errors[fn] or (type(_G[fn]) == "function" and "available" or "unavailable")))
    end
    self:Chat("Kill-feed event: " .. tostring(EVENT_PVP_KILL_FEED_DEATH ~= nil) .. " | guild-warning event: " .. tostring(EVENT_GUILD_KEEP_ATTACK_UPDATE ~= nil))
end
function PW:Command(text)
    local cmd, arg = tostring(text or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" then self:ToggleWindow()
    elseif cmd == "close" or cmd == "hide" then self:CloseWindow()
    elseif cmd == "open" or cmd == "show" then self:OpenWindow()
    elseif cmd == "hud" then self:ToggleHUD()
    elseif cmd == "refresh" then self:RequestBriefing(); self:Scan(); self:Render()
    elseif cmd == "next" then self.page = self.page + 1; self:Render()
    elseif cmd == "prev" then self.page = math.max(1, self.page - 1); self:Render()
    elseif cmd == "diag" then self:Diagnostics()
    elseif cmd == "log" then
        local n = math.min(30, math.max(1, tonumber(arg) or 12))
        for i = math.max(1, #self.sv.log - n + 1), #self.sv.log do self:Chat(self.sv.log[i]) end
    elseif cmd == "reset" then self.sv.x, self.sv.y = 0, 0; self:PositionWindow()
    elseif cmd == "test" then self:Chat("TEST ONLY: enemy siege detected at a sample Pact keep (not live data).")
        if self.sv.sound and SOUNDS and SOUNDS.DEFAULT_CLICK then pcall(PlaySound, SOUNDS.DEFAULT_CLICK) end
    elseif cmd == "alerts" or cmd == "sound" or cmd == "resources" or cmd == "debug" or cmd == "auto" or cmd == "on" or cmd == "off" then
        local k = ({ alerts = "chat", sound = "sound", resources = "resources", debug = "debug", auto = "autoOpen", on = "enabled", off = "enabled" })[cmd]
        if cmd == "on" then self.sv[k] = true elseif cmd == "off" then self.sv[k] = false
        elseif arg == "on" then self.sv[k] = true elseif arg == "off" then self.sv[k] = false else self.sv[k] = not self.sv[k] end
        self:Chat(cmd .. ": " .. (self.sv[k] and "on" or "off")); self:Render()
    else self:Chat("/pw opens briefing | hud | refresh | next/prev | alerts/sound/resources/debug/auto on/off | on/off | diag | log [12] | test | reset") end
end
function PW:Activate()
    if self:Running() then
        local id = self:Read("GetCurrentCampaignId")
        if self.campaignId ~= id then self:ResetSession(id) end
        self:Scan()
        if self.sv.autoOpen then self:OpenWindow() end
    end
    self:Render()
end
function PW:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide("PactWatchSaved", 1, nil, defaults)
    self.sv.log = self.sv.log or {}
    self:CreateUI()
    SLASH_COMMANDS["/pw"] = function(s) self:Command(s) end
    SLASH_COMMANDS["/pactwatch"] = SLASH_COMMANDS["/pw"]
    if ZO_CreateStringId then
        ZO_CreateStringId("SI_BINDING_NAME_PACTWATCH_TOGGLE", "Open Pact Watch")
        ZO_CreateStringId("SI_BINDING_NAME_PACTWATCH_HUD", "Toggle Pact Watch HUD")
    end
    local function event(name, callback)
        if _G[name] then EVENT_MANAGER:RegisterForEvent(self.name, _G[name], callback) end
    end
    event("EVENT_PLAYER_ACTIVATED", function() self:Activate() end)
    event("EVENT_PLAYER_DEACTIVATED", function()
        self.activity, self.keeps, self.recurrence = {}, {}, {}; self.campaignId = nil; self.scans = 0
        self.emperor, self.emperorSeen, self.hammer, self.hammerHidden = nil, nil, nil, nil
        self.hud:SetHidden(true)
        self:CloseWindow()
    end)
    event("EVENT_CAMPAIGN_SELECTION_DATA_CHANGED", function() self:SelectionReady(); self:Render() end)
    event("EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED", function()
        if self:Running() then self.hammer = nil; self.hammerHidden = true; self:Render(); self:Alert("hammer-spawn", "Hammer spawned! ESO has not revealed its location yet.") end
    end)
    event("EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED", function(...) self:OnHammerState(...) end)
    event("EVENT_PVP_KILL_FEED_DEATH", function(...) self:OnKill(...) end)
    event("EVENT_GUILD_KEEP_ATTACK_UPDATE", function(...) self:OnGuild(...) end)
    event("EVENT_KEEP_UNDER_ATTACK_CHANGED", function(_, id, ctx)
        if self:Running() and (ctx == BGQUERY_LOCAL or ctx == BGQUERY_ASSIGNED_AND_LOCAL) then self:Scan() end
    end)
    event("EVENT_KEEP_ALLIANCE_OWNER_CHANGED", function(_, id, ctx)
        if self:Running() and (ctx == BGQUERY_LOCAL or ctx == BGQUERY_ASSIGNED_AND_LOCAL) then self:Scan() end
    end)
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Poll", 3000, function()
        if self:Running() then self:Scan() end
        self:GetActivities()
        if not self.window:IsHidden() or self.sv.hud then self:Render() end
    end)
    self:Log("Loaded v" .. self.version)
    self:Chat("v" .. self.version .. " console test ready. /pw briefing | /pw hud | /pw help")
end
EVENT_MANAGER:RegisterForEvent(PW.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name == PW.name then EVENT_MANAGER:UnregisterForEvent(PW.name, EVENT_ADD_ON_LOADED); PW:Initialize() end
end)
