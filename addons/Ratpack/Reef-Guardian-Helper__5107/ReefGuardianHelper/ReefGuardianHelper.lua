-- Reef Guardian Helper
-- Dreadsail Reef, zweiter Boss. Zeigt alle 5 Guardians mit Leben und Status.
-- Noch nicht gespawnte Guardians stehen transparent mit "Soon" in der Liste.
-- Kopfzeile: Toetungssperre (Gross/Mittel-1 erst toeten, wenn Mittel-2 sein Riff gestartet hat).
-- Erster Boss: eigenes Fenster mit Lylanar und Turlassil (Striche bei 80 % und 20 %).

-- alles lokal: Addon aus einer Datei, keine globale Tabelle noetig
local RG = {}
RG.name = "ReefGuardianHelper"
RG.version = "1.4.4"   -- muss zu "## Version" im Manifest passen

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH

local ZONE_DSR = 1344
local MAX_BOSS_TAGS = 12

-- Erster Boss: Zwillinge (Name in allen Sprachen gleich)
local TWINS = {
    { key = "L", label = "Lylanar",   name = "lylanar" },
    { key = "T", label = "Turlassil", name = "turlassil" },
}
local TWIN_MARKS = { 0.8, 0.2 }

-- Ability-IDs (aus Encounter.log / ESO Logs)
local ID_REPLICATION = 163701  -- Cast 2,5 s
local ID_CHARGE      = 166022  -- Losrennen zum Riff
local ID_HEARTBURN   = 163692  -- Riff gesetzt (Kanal 60 s)
local ID_ACIDREFLUX  = 163702  -- Kotzen, Kanal ~12 s
local TRACKED = { ID_REPLICATION, ID_CHARGE, ID_HEARTBURN, ID_ACIDREFLUX }
-- Effekte auf dem Guardian selbst (Boss-Tag):
local ID_EFF_RIFF    = 170481  -- "Heartburn": Riff offen, max. 60 s, verschwindet wenn das Reef Heart zerstoert ist
local ID_EFF_VULN    = 166031  -- "Heartburn Vulnerability": 10 s nach Zerstoerung des Riffs
local RIFF_MAX       = 60
-- Spieler im Riff: Hoehe (Weltkoordinate y) oben 39-40k, im Riff ~36k (Werte aus "Qcell's Dreadsail Reef Helper", Credit: Qcell)
local PORTAL_Y       = 37000
-- ab wie vielen Sekunden Riff-Dauer immer "KILL" kommt: Einstellung RG.sv.reefWait (/rgh reefwait)

-- Bekannte Namen (kleingeschrieben). Unbekannte Sprache: Name wird erkannt,
-- sobald zwei Bosse gleichen Namens gleichzeitig da sind (Replication).
local KNOWN_NAMES = { ["reef guardian"] = true, ["riffwächter"] = true, ["gardien du récif"] = true }

-- Reihenfolge der Zeilen
local ORDER = { "G", "M1", "M2", "K1", "K2" }
local LABEL = { G = "Large", M1 = "Medium 1", M2 = "Medium 2", K1 = "Small 1", K2 = "Small 2" }
local CLASS = { G = "G", M1 = "M", M2 = "M", K1 = "K", K2 = "K" }

local defaults = {
    left = 500,
    top = 250,
    tleft = 500,         -- Fenster erster Boss
    ttop = 150,
    locked = true,
    showKillLock = true,
    alwaysShow = false,
    alertMode = "all",   -- Meldungen in der Bildschirmmitte: "all" | "dd" | "off"
    stopPct = 10,        -- "STOP DAMAGE", wenn Large/Medium 1 darunter und Medium 2 noch kein Riff
    reefWait = 35,       -- Spieler im Riff von Medium 2: "WAIT" bis Large + Medium 1 tot, spaetestens nach so vielen s "KILL"
}

local ALERT_TEXT = "KILL THE GUARDIANS"
local ALERT_SUB = "Medium 2 reef is up"
local ALERT_DUR = 3

local ROW_H = 26
local WIDTH = 326
local NAME_W = 74
local SQ = ROW_H - 4     -- Kantenlaenge des Riff-Quadrats
local UPDATE_NS = "ReefGuardianHelper_Update"

local recs = {}          -- [key] = Datensatz pro Guardian
local tagToKey = {}      -- [bossTag] = key
local unitIdToTag = {}   -- [unitId] = bossTag (aus Effekt-Events)
local tiers = {}         -- verschiedene Max-Leben dieses Kampfs, absteigend (Large, Medium, Small)
local guardianName = nil
local heartburnCount = 0
local m2RiffStarted = false
local killAlertShown = false
local stopActive = false
local alertUntil = 0
local alertKind = nil    -- "kill" | "stop"
local testUntil = 0
local debugMode = false
local rows = {}
local twinRows = {}
local twin = {}          -- [key] = { pct, dead, present }
local twinTestUntil = 0
local noneSince = nil    -- seit wann keine Guardians sichtbar sind
local reefCount = 0      -- Anzahl gesetzter Riffe in diesem Kampf
local reefState = nil    -- "wait" | "kill" (Meldung fuer Spieler im Riff)
local reefTestStart = nil
local updating = false
local TestTick, TestEnd   -- weiter unten definiert

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
local function Print(msg)
    d("|c55AACC[ReefGuardian]|r " .. msg)
end

local function Now()
    return GetFrameTimeSeconds()
end

local function NewRec(key)
    return {
        key = key, spawned = false, dead = false, tag = nil, unitId = nil,
        hp = 0, max = 0, pct = 100, missingSince = nil,
        runs = 0, runStart = nil, riffAt = nil, arEnd = 0, replEnd = 0,
        riffEnd = nil, vulnEnd = nil,
    }
end

local function ResetFight()
    for _, k in ipairs(ORDER) do recs[k] = NewRec(k) end
    ZO_ClearTable(tagToKey)
    ZO_ClearTable(unitIdToTag)
    tiers = {}
    guardianName = nil
    heartburnCount = 0
    m2RiffStarted = false
    killAlertShown = false
    stopActive = false
    reefCount = 0
    reefState = nil
end

-- Neues Riff eines Guardians: Nummer, Startzeit und Ort (Position des Guardians beim Setzen) merken
local function NewReef(r, now)
    if r.riffStart and now - r.riffStart < 20 then return end
    reefCount = reefCount + 1
    r.reefNo, r.riffStart, r.riffX, r.riffZ = reefCount, now, r.x, r.z
end

---------------------------------------------------------------------------
-- Meldung in der Bildschirmmitte
---------------------------------------------------------------------------
local function ShouldAlertMe()
    local mode = RG.sv.alertMode
    if mode == "all" then return true end
    if mode == "dd" then return GetSelectedLFGRole() == LFG_ROLE_DPS end
    return false
end

local ALERT_COLOR = { kill = { 1, 0.45, 0.1 }, stop = { 1, 0.1, 0.1 }, wait = { 1, 0.85, 0.1 } }

local function ShowCenterAlert(text, sub, kind, ping)
    kind = kind or "kill"
    local c = ALERT_COLOR[kind]
    RG.alertText:SetText(text)
    RG.alertText:SetColor(c[1], c[2], c[3], 1)
    RG.alertSub:SetText(sub or "")
    RG.alertWin:SetHidden(false)
    alertUntil = Now() + ALERT_DUR
    alertKind = kind
    if ping ~= false then PlaySound(SOUNDS.DUEL_START or SOUNDS.NEW_NOTIFICATION) end
end

local function InZone()
    return GetZoneId(GetUnitZoneIndex("player")) == ZONE_DSR
end


-- Klasse ueber Leben-Stufen statt fester Verhaeltnisse.
-- Hard Mode: Medium ~67 %, Small ~50 % von Large. Normal: Medium ~48 %, Small ~20 %.
-- Gleiche Typen haben exakt gleiches Max-Leben -> Stufen: groesste = Large, zweite = Medium, dritte = Small.
local function TierIndex(maxHp)
    for i, v in ipairs(tiers) do
        if math.abs(v - maxHp) <= v * 0.02 then return i end
    end
end

local function AddTier(maxHp)
    if TierIndex(maxHp) then return false end
    tiers[#tiers + 1] = maxHp
    table.sort(tiers, function(a, b) return a > b end)
    if debugMode then
        local t = {}
        for i, v in ipairs(tiers) do t[i] = string.format("%.2fM", v / 1e6) end
        Print("Leben-Stufen: " .. table.concat(t, " / "))
    end
    return true
end

local function ClassOf(maxHp)
    local i = TierIndex(maxHp) or 1
    if i == 1 then return "G" end
    if i == 2 then return "M" end
    return "K"
end

-- Stufen haben sich verschoben (z.B. Small vor Medium gesehen): Datensaetze in die richtige Klasse umziehen
local function Reclassify()
    for _, k in ipairs(ORDER) do
        local r = recs[k]
        if r.spawned and r.max > 0 then
            local cls = ClassOf(r.max)
            if CLASS[k] ~= cls then
                for _, nk in ipairs(ORDER) do
                    if CLASS[nk] == cls and not recs[nk].spawned then
                        r.key = nk
                        recs[nk] = r
                        recs[k] = NewRec(k)
                        if r.tag then tagToKey[r.tag] = nk end
                        if debugMode then Print(string.format("Umsortiert: %s -> %s", LABEL[k], LABEL[nk])) end
                        break
                    end
                end
            end
        end
    end
end

-- unitId ist pro Einheit fest, Boss-Tags nicht: erst ueber die gespeicherte unitId suchen
local function RecByUnitId(unitId)
    for _, k in ipairs(ORDER) do
        if recs[k].unitId == unitId then return recs[k] end
    end
    local tag = unitIdToTag[unitId]
    if tag and tagToKey[tag] then return recs[tagToKey[tag]] end
end

local function SetUnitId(k, unitId)
    for _, o in ipairs(ORDER) do
        if o ~= k and recs[o].unitId == unitId then recs[o].unitId = nil end
    end
    recs[k].unitId = unitId
end

---------------------------------------------------------------------------
-- Boss-Tags auslesen und den 5 Guardians zuordnen
---------------------------------------------------------------------------
local function ScanBosses()
    local now = Now()
    local present = {}

    -- erst alle Tags einsammeln
    local all, nameCount = {}, {}
    for i = 1, MAX_BOSS_TAGS do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            local name = zo_strformat("<<1>>", GetUnitName(tag))
            local cur, max = GetUnitPower(tag, HEALTH)
            if max and max > 0 then
                local _, x, _, z = GetUnitRawWorldPosition(tag)
                all[#all + 1] = { tag = tag, cur = cur, max = max, name = name, x = x, z = z }
                nameCount[name] = (nameCount[name] or 0) + 1
            end
        end
    end
    -- Guardian-Name: bekannter Name, oder ein Bossname, der mehrfach gleichzeitig vorkommt
    if not guardianName then
        for name, c in pairs(nameCount) do
            if KNOWN_NAMES[zo_strlower(name)] or c >= 2 then guardianName = name end
        end
    end
    local list = {}
    local newTier = false
    for _, b in ipairs(all) do
        if b.name == guardianName then
            list[#list + 1] = b
            if AddTier(b.max) then newTier = true end
        end
    end
    if newTier then Reclassify() end

    -- Guardians den Datensaetzen zuordnen.
    -- ESO sortiert die Boss-Tags um, wenn Guardians erscheinen oder sterben. Deshalb wird pro Klasse
    -- ueber den Lebensverlauf zugeordnet (Leben sinkt nur), der Tag zaehlt nur als Gleichstand-Entscheider.
    -- Neue Klone erscheinen mit vollem Leben.
    ZO_ClearTable(tagToKey)
    local byClass = { G = {}, M = {}, K = {} }
    for _, b in ipairs(list) do
        b.pct = 100 * b.cur / b.max
        local c = byClass[ClassOf(b.max)]
        c[#c + 1] = b
    end
    for cls, units in pairs(byClass) do
        if #units > 0 then
            local keys = {}
            for _, k in ipairs(ORDER) do
                local r = recs[k]
                if CLASS[k] == cls and r.spawned and (not r.dead or r.lost) then keys[#keys + 1] = k end
            end
            local function cost(u, k)
                local r = recs[k]
                local c
                if r.missingSince or r.lost then
                    -- eine Weile nicht gesehen: darf deutlich weniger Leben haben, aber nicht mehr
                    if u.pct > r.pct + 3 then return nil end
                    c = 4 + (r.pct - u.pct) * 0.1
                else
                    c = math.abs(r.pct - u.pct)
                    if c > 15 then return nil end
                end
                if r.tag ~= u.tag then c = c + 2 end
                -- Position als zusaetzliches Merkmal (Weltkoordinaten in cm, gedeckelt bei 10 m)
                if r.x and u.x then
                    local dx, dz = r.x - u.x, r.z - u.z
                    c = c + math.min(math.sqrt(dx * dx + dz * dz) / 100, 10) * 0.3
                end
                return c
            end
            -- kleinste Gesamtabweichung (pro Klasse hoechstens 2-3 Einheiten, also Ausprobieren aller Varianten)
            local best, bestCost, assign, usedK = nil, nil, {}, {}
            local function try(i, acc)
                if bestCost and acc >= bestCost then return end
                if i > #units then
                    best = {}
                    for j = 1, #units do best[j] = assign[j] end
                    bestCost = acc
                    return
                end
                local u = units[i]
                for _, k in ipairs(keys) do
                    if not usedK[k] then
                        local c = cost(u, k)
                        if c then
                            usedK[k], assign[i] = true, k
                            try(i + 1, acc + c)
                            usedK[k] = nil
                        end
                    end
                end
                assign[i] = false     -- neu gespawnt
                try(i + 1, acc + (u.pct >= 95 and 20 or 60))
            end
            try(1, 0)
            for i, u in ipairs(units) do
                local key = best and best[i]
                if key == false then
                    key = nil
                    for _, k in ipairs(ORDER) do
                        if CLASS[k] == cls and not recs[k].spawned then key = k break end
                    end
                end
                if key then
                    tagToKey[u.tag] = key
                    local r = recs[key]
                    if not r.spawned then
                        r.spawned = true
                        if debugMode then Print(string.format("%s erscheint (%s, %.1fM)", LABEL[key], u.tag, u.max / 1e6)) end
                    elseif debugMode and r.tag ~= u.tag then
                        Print(string.format("%s: Tag %s -> %s (%.0f%%)", LABEL[key], tostring(r.tag), u.tag, u.pct))
                    end
                    if r.lost and debugMode then Print(LABEL[key] .. " wieder da") end
                    r.tag, r.hp, r.max, r.pct, r.x, r.z = u.tag, u.cur, u.max, u.pct, u.x, u.z
                    r.missingSince, r.lost = nil, nil
                    r.dead = u.cur <= 0
                    present[key] = true
                end
            end
        end
    end

    -- nicht mehr sichtbare Guardians als tot markieren (nur wenn ueberhaupt Guardians sichtbar sind,
    -- sonst ist man nur ausser Reichweite). Kommt er wieder, wird er wiedererkannt (r.lost).
    if #list > 0 then
        for _, k in ipairs(ORDER) do
            local r = recs[k]
            if r.spawned and not r.dead and not present[k] then
                r.missingSince = r.missingSince or now
                if now - r.missingSince > 1.5 then
                    r.dead, r.lost = true, true
                    if debugMode then Print(LABEL[k] .. " tot / weg") end
                end
            end
        end
    end

    return #list
end

-- Erster Boss: Lylanar und Turlassil ueber die Boss-Tags suchen
local function ScanTwins()
    local n = 0
    for _, t in ipairs(TWINS) do twin[t.key] = nil end
    for i = 1, MAX_BOSS_TAGS do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            local name = zo_strlower(zo_strformat("<<1>>", GetUnitName(tag)))
            for _, t in ipairs(TWINS) do
                if name == t.name then
                    local cur, max = GetUnitPower(tag, HEALTH)
                    if max and max > 0 then
                        twin[t.key] = { pct = 100 * cur / max, dead = cur <= 0 or IsUnitDead(tag) }
                        n = n + 1
                    end
                end
            end
        end
    end
    return n
end

local function UpdateTwinRows()
    for i, t in ipairs(TWINS) do
        local s, row = twin[t.key], twinRows[i]
        if not s then
            row.ctrl:SetAlpha(0.35)
            row.bar:SetValue(1)
            row.bar:SetColor(0.5, 0.5, 0.5, 0.6)
            row.pct:SetText("")
        elseif s.dead then
            row.ctrl:SetAlpha(0.35)
            row.bar:SetValue(0)
            row.pct:SetText("dead")
        else
            row.ctrl:SetAlpha(1)
            row.bar:SetValue(zo_clamp(s.pct / 100, 0, 1))
            row.bar:SetColor(0.7, 0.15, 0.15, 0.9)
            row.pct:SetText(string.format("%.0f%%", s.pct))
        end
    end
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
local function StatusOf(r, now)
    if not r.spawned then return "Soon", 0.8, 0.8, 0.8 end
    if r.dead then return "dead", 0.6, 0.6, 0.6 end
    if r.replEnd > now then return "Replication", 0.6, 0.85, 1 end
    if r.runStart and not r.riffAt and now - r.runStart < 14 then
        return string.format("CHARGE! Reef in ~%ds", math.max(0, math.ceil(r.runStart + 7.2 - now))), 1, 0.5, 0.2
    end
    if r.arEnd > now then return string.format("Acid Reflux %.0fs", r.arEnd - now), 0.6, 1, 0.4 end
    if r.riffAt and now - r.riffAt < 4 then return "Reef placed", 0.6, 0.85, 1 end
    return "", 1, 1, 1
end

local function UpdateRows()
    local now = Now()
    for i, k in ipairs(ORDER) do
        local r, row = recs[k], rows[i]
        local status, sr, sg, sb = StatusOf(r, now)
        row.status:SetText(status)
        row.status:SetColor(sr, sg, sb, 1)
        row.name:SetText(LABEL[k] .. (r.runs > 0 and "|c88AACC*|r" or ""))

        if not r.spawned then
            row.ctrl:SetAlpha(0.35)
            row.bar:SetValue(1)
            row.bar:SetColor(0.5, 0.5, 0.5, 0.6)
            row.pct:SetText("")
        elseif r.dead then
            row.ctrl:SetAlpha(0.35)
            row.bar:SetValue(0)
            row.pct:SetText("")
        else
            row.ctrl:SetAlpha(1)
            row.bar:SetValue(zo_clamp(r.pct / 100, 0, 1))
            row.pct:SetText(string.format("%.0f%%", r.pct))
            if r.runs == 0 and k ~= "G" and r.pct <= 85 then
                row.bar:SetColor(0.9, 0.55, 0.15, 0.9)   -- kurz vor / unter 80 %, noch nicht gerannt
            else
                row.bar:SetColor(0.7, 0.15, 0.15, 0.9)
            end
        end

        -- Riff-Quadrat: Restzeit des offenen Riffs (max. 60 s), danach 10 s Vulnerability
        local riffLeft = r.riffEnd and (r.riffEnd - now) or 0
        local vulnLeft = r.vulnEnd and (r.vulnEnd - now) or 0
        if riffLeft > 0 then
            row.sqFill:SetValue(zo_clamp(riffLeft / RIFF_MAX, 0, 1))
            if riffLeft <= 10 then row.sqFill:SetColor(0.95, 0.15, 0.15, 0.95)
            elseif riffLeft <= 25 then row.sqFill:SetColor(0.95, 0.75, 0.15, 0.95)
            else row.sqFill:SetColor(0.25, 0.55, 0.95, 0.95) end
            row.sqText:SetText(string.format("%d", math.ceil(riffLeft)))
            row.sqText:SetColor(1, 1, 1, 1)
            row.sq:SetHidden(false)
        elseif vulnLeft > 0 then
            row.sqFill:SetValue(zo_clamp(vulnLeft / 10, 0, 1))
            row.sqFill:SetColor(0.25, 0.8, 0.3, 0.95)
            row.sqText:SetText(string.format("%d", math.ceil(vulnLeft)))
            row.sqText:SetColor(1, 1, 1, 1)
            row.sq:SetHidden(false)
        else
            row.sqFill:SetValue(0)
            row.sqText:SetText("")
            row.sq:SetHidden(false)
        end
        if r.riffEnd and riffLeft <= 0 then r.riffEnd = nil end
        if r.vulnEnd and vulnLeft <= 0 then r.vulnEnd = nil end
    end

    -- Toetungssperre
    if RG.sv.showKillLock then
        local anyAlive = recs.G.spawned and (not recs.G.dead or not recs.M1.dead)
        if m2RiffStarted then
            RG.lock:SetText("KILL OK")
            RG.lock:SetColor(0.4, 1, 0.4, 1)
        elseif anyAlive then
            RG.lock:SetText("DON'T KILL")
            RG.lock:SetColor(1, 0.25, 0.25, 1)
        else
            RG.lock:SetText("")
        end
        RG.lock:SetHidden(false)
    else
        RG.lock:SetHidden(true)
    end

    RG.caption:SetText(RG.testCaption or "")
    RG.caption:SetHidden(RG.testCaption == nil)
end

local function OnUpdate()
    local now = Now()
    local n = 0
    if now >= testUntil then
        if InZone() then n = ScanBosses() end
        if n > 0 then noneSince = nil else noneSince = noneSince or now end
        -- Reset nach Kill/Wipe: nicht im Kampf und seit 10 s keine Guardians mehr sichtbar
        -- (kurz ausser Reichweite oder selbst tot reicht nicht) oder alle wieder auf vollem Leben
        if recs.G.spawned and not IsUnitInCombat("player") then
            local allFull, happened = true, heartburnCount > 0
            for _, k in ipairs(ORDER) do
                local r = recs[k]
                if r.spawned and not r.dead and r.pct < 99.5 then allFull = false end
                if r.dead or r.runs > 0 then happened = true end
            end
            if (noneSince and now - noneSince > 10) or (n > 0 and allFull and happened) then ResetFight() end
        end
        if RG.testCaption then TestEnd() end
    else
        TestTick(now)
        n = 1
    end
    UpdateRows()

    -- Bin ich gerade im Riff? Dann kein STOP DAMAGE / KILL THE GUARDIANS (die gelten nur oben)
    local inReef = false
    if now >= testUntil and InZone() then
        local _, _, py = GetUnitRawWorldPosition("player")
        inReef = py ~= nil and py < PORTAL_Y
    end

    -- Meldung "Kill the Guardians", einmal pro Kampf, sobald Medium 2 sein Riff gesetzt hat.
    -- Ist man in dem Moment im Riff, kommt sie beim Zurueckkommen nach oben,
    -- aber nur, wenn Large oder Medium 1 dann noch lebt.
    if m2RiffStarted and not killAlertShown and not inReef then
        killAlertShown = true
        local relevant = now < testUntil or (recs.G.spawned and not recs.G.dead) or (recs.M1.spawned and not recs.M1.dead)
        if relevant and (now < testUntil or ShouldAlertMe()) then ShowCenterAlert(ALERT_TEXT, ALERT_SUB, "kill") end
    end

    -- "STOP DAMAGE": Large oder Medium 1 unter stopPct, Medium 2 hat noch kein Riff.
    -- Ping beim ersten Mal, die Meldung bleibt stehen, solange die Bedingung gilt.
    local low
    if not m2RiffStarted and not inReef then
        for _, k in ipairs({ "G", "M1" }) do
            local r = recs[k]
            if r.spawned and not r.dead and r.pct < RG.sv.stopPct and (not low or r.pct < low.pct) then low = r end
        end
    end
    if low then
        local sub = string.format("%s %.0f%% - Medium 2 reef not up yet", LABEL[low.key], low.pct)
        if now < testUntil or ShouldAlertMe() then
            if not stopActive then
                ShowCenterAlert("STOP DAMAGE", sub, "stop", true)
            elseif alertKind == "stop" then
                RG.alertSub:SetText(sub)
                alertUntil = now + 0.5
            end
        end
        stopActive = true
    else
        stopActive = false
    end

    -- Meldung fuer Spieler im Riff (jedes Riff; Warten nur beim Riff von Medium 2):
    -- Large oder Medium 1 lebt -> "WAIT", beide tot oder Riff schon reefWait s offen -> "KILL"
    local reef, lAlive, mAlive
    if reefTestStart and now < reefTestStart + 12 then
        reef = { key = "M2", reefNo = 3, riffStart = reefTestStart + 6 - RG.sv.reefWait }
        lAlive, mAlive = true, true
    else
        reefTestStart = nil
        if now >= testUntil and InZone() then
            local _, px, py, pz = GetUnitRawWorldPosition("player")
            if py and py < PORTAL_Y then
                local bestD
                for _, k in ipairs(ORDER) do
                    local r = recs[k]
                    if r.riffEnd and r.riffEnd > now and r.riffStart then
                        local dd = (r.riffX and px) and ((r.riffX - px) ^ 2 + (r.riffZ - pz) ^ 2) or 0
                        if not bestD or dd < bestD then reef, bestD = r, dd end
                    end
                end
            end
        end
        lAlive = recs.G.spawned and not recs.G.dead
        mAlive = recs.M1.spawned and not recs.M1.dead
    end
    if reef and RG.sv.alertMode ~= "off" then
        local age = now - reef.riffStart
        -- Warten nur beim Riff von Medium 2 (Riff 3); das Riff von Medium 1 kann sofort gespielt werden
        local state = (reef.key ~= "M2" or (not lAlive and not mAlive) or age >= RG.sv.reefWait) and "kill" or "wait"
        local text, sub
        if state == "wait" then
            text = string.format("REEF %d: WAIT", reef.reefNo or 0)
            sub = string.format("Large / Medium 1 alive - kill in %ds", math.max(0, math.ceil(RG.sv.reefWait - age)))
        else
            text = string.format("REEF %d: KILL THE HEART", reef.reefNo or 0)
            if reef.key ~= "M2" then sub = ""
            elseif not lAlive and not mAlive then sub = "Large + Medium 1 dead"
            else sub = string.format("Reef open %ds", math.floor(age)) end
        end
        if state ~= reefState then
            ShowCenterAlert(text, sub, state, true)
        else
            local c = ALERT_COLOR[state]
            RG.alertText:SetText(text)
            RG.alertText:SetColor(c[1], c[2], c[3], 1)
            RG.alertSub:SetText(sub)
            RG.alertWin:SetHidden(false)
        end
        alertKind = "reef"
        alertUntil = now + 0.5
        reefState = state
    else
        reefState = nil
    end

    if alertUntil > 0 and now >= alertUntil then
        alertUntil = 0
        RG.alertWin:SetHidden(true)
    end

    -- Guardian-Fenster erst, wenn die Guardians als Boss da sind (nicht schon beim Betreten des Gebiets)
    local show = n > 0 or recs.G.spawned or now < testUntil or not RG.sv.locked or RG.sv.alwaysShow
    RG.content:SetHidden(not show)

    -- Fenster erster Boss
    local nt = 0
    if now < twinTestUntil then
        nt = 2
        twin.L = { pct = 83, dead = false }
        twin.T = { pct = 77, dead = false }
    elseif InZone() then
        nt = ScanTwins()
    else
        for _, t in ipairs(TWINS) do twin[t.key] = nil end
    end
    UpdateTwinRows()
    local showTwins = nt > 0 or not RG.sv.locked or RG.sv.alwaysShow
    RG.twinContent:SetHidden(not showTwins)
end

local function StartUpdates()
    if updating then return end
    EM:RegisterForUpdate(UPDATE_NS, 100, OnUpdate)
    updating = true
end

local function StopUpdates()
    if not updating then return end
    EM:UnregisterForUpdate(UPDATE_NS)
    updating = false
    RG.content:SetHidden(true)
    RG.twinContent:SetHidden(true)
end

-- Fenster erster Boss: zwei Zeilen, Striche bei 80 % und 20 %
local function CreateTwinUI()
    local win = WM:CreateTopLevelWindow("ReefGuardianHelperTwins")
    win:SetDimensions(WIDTH, ROW_H * (#TWINS + 1) + 6)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(not RG.sv.locked)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, RG.sv.tleft, RG.sv.ttop)
    win:SetHandler("OnMoveStop", function(self)
        RG.sv.tleft = self:GetLeft()
        RG.sv.ttop = self:GetTop()
    end)

    local content = WM:CreateControl("$(parent)Content", win, CT_CONTROL)
    content:SetAnchorFill(win)

    local bg = WM:CreateControl("$(parent)BG", content, CT_BACKDROP)
    bg:SetAnchorFill(content)
    bg:SetCenterColor(0, 0, 0, 0.5)
    bg:SetEdgeColor(0, 0, 0, 0)

    local title = WM:CreateControl("$(parent)Title", content, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.6, 0.85, 1, 1)
    title:SetAnchor(TOPLEFT, content, TOPLEFT, 6, 2)
    RG.twinTitle = title

    local barW = WIDTH - 8 - NAME_W
    for i, t in ipairs(TWINS) do
        local row = WM:CreateControl("$(parent)Row" .. i, content, CT_CONTROL)
        row:SetDimensions(WIDTH - 8, ROW_H - 4)
        row:SetAnchor(TOPLEFT, content, TOPLEFT, 4, ROW_H * i)

        local name = WM:CreateControl("$(parent)Name", row, CT_LABEL)
        name:SetFont("ZoFontGameSmall")
        name:SetDimensions(NAME_W, ROW_H - 4)
        name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        name:SetAnchor(LEFT, row, LEFT, 2, 0)
        name:SetText(t.label)

        local barBg = WM:CreateControl("$(parent)BarBG", row, CT_BACKDROP)
        barBg:SetAnchor(TOPLEFT, row, TOPLEFT, NAME_W, 0)
        barBg:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
        barBg:SetCenterColor(0.15, 0.15, 0.15, 0.8)
        barBg:SetEdgeColor(0, 0, 0, 1)

        local bar = WM:CreateControl("$(parent)Bar", row, CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT, barBg, TOPLEFT, 1, 1)
        bar:SetAnchor(BOTTOMRIGHT, barBg, BOTTOMRIGHT, -1, -1)
        bar:SetMinMax(0, 1)
        bar:SetDrawLevel(2)

        for m, f in ipairs(TWIN_MARKS) do
            local mark = WM:CreateControl("$(parent)Mark" .. m, row, CT_TEXTURE)
            mark:SetColor(1, 1, 1, 0.7)
            mark:SetDimensions(2, ROW_H - 6)
            mark:SetAnchor(LEFT, barBg, LEFT, math.floor(barW * f), 0)
            mark:SetDrawLevel(3)
        end

        local pct = WM:CreateControl("$(parent)Pct", row, CT_LABEL)
        pct:SetFont("ZoFontGameBold")
        pct:SetAnchor(RIGHT, bar, RIGHT, -4, 0)
        pct:SetDrawLevel(4)

        twinRows[i] = { ctrl = row, bar = bar, pct = pct }
    end

    RG.twinWin = win
    RG.twinContent = content
    content:SetHidden(true)

    local fragment = ZO_HUDFadeSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function CreateUI()
    local win = WM:CreateTopLevelWindow("ReefGuardianHelperWindow")
    win:SetDimensions(WIDTH, ROW_H * (#ORDER + 1) + 6)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(not RG.sv.locked)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, RG.sv.left, RG.sv.top)
    win:SetHandler("OnMoveStop", function(self)
        RG.sv.left = self:GetLeft()
        RG.sv.top = self:GetTop()
    end)

    local content = WM:CreateControl("$(parent)Content", win, CT_CONTROL)
    content:SetAnchorFill(win)

    local bg = WM:CreateControl("$(parent)BG", content, CT_BACKDROP)
    bg:SetAnchorFill(content)
    bg:SetCenterColor(0, 0, 0, 0.5)
    bg:SetEdgeColor(0, 0, 0, 0)

    local title = WM:CreateControl("$(parent)Title", content, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.6, 0.85, 1, 1)
    title:SetAnchor(TOPLEFT, content, TOPLEFT, 6, 2)
    RG.title = title

    local lock = WM:CreateControl("$(parent)Lock", content, CT_LABEL)
    lock:SetFont("ZoFontGameBold")
    lock:SetAnchor(TOPRIGHT, content, TOPRIGHT, -6, 2)
    RG.lock = lock

    -- Szenentext im Testmodus (unter dem Fenster)
    local caption = WM:CreateControl("$(parent)Caption", content, CT_LABEL)
    caption:SetFont("ZoFontGameBold")
    caption:SetColor(1, 0.85, 0.3, 1)
    caption:SetAnchor(TOPLEFT, content, BOTTOMLEFT, 4, 4)
    caption:SetHidden(true)
    RG.caption = caption

    local barW = WIDTH - 8 - NAME_W - 2 - (SQ + 4)
    for i = 1, #ORDER do
        local row = WM:CreateControl("$(parent)Row" .. i, content, CT_CONTROL)
        row:SetDimensions(WIDTH - 8, ROW_H - 4)
        row:SetAnchor(TOPLEFT, content, TOPLEFT, 4, ROW_H * i)

        local name = WM:CreateControl("$(parent)Name", row, CT_LABEL)
        name:SetFont("ZoFontGameSmall")
        name:SetDimensions(NAME_W, ROW_H - 4)
        name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        name:SetAnchor(LEFT, row, LEFT, 2, 0)

        local barBg = WM:CreateControl("$(parent)BarBG", row, CT_BACKDROP)
        barBg:SetAnchor(TOPLEFT, row, TOPLEFT, NAME_W, 0)
        barBg:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -(SQ + 4), 0)
        barBg:SetCenterColor(0.15, 0.15, 0.15, 0.8)
        barBg:SetEdgeColor(0, 0, 0, 1)

        -- Riff-Quadrat rechts neben dem Balken (leert sich von oben nach unten)
        local sq = WM:CreateControl("$(parent)Sq", row, CT_BACKDROP)
        sq:SetDimensions(SQ, SQ)
        sq:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        sq:SetCenterColor(0.15, 0.15, 0.15, 0.8)
        sq:SetEdgeColor(0, 0, 0, 1)

        local sqFill = WM:CreateControl("$(parent)SqFill", sq, CT_STATUSBAR)
        sqFill:SetAnchor(TOPLEFT, sq, TOPLEFT, 1, 1)
        sqFill:SetAnchor(BOTTOMRIGHT, sq, BOTTOMRIGHT, -1, -1)
        sqFill:SetOrientation(ORIENTATION_VERTICAL)
        sqFill:SetMinMax(0, 1)
        sqFill:SetValue(0)
        sqFill:SetDrawLevel(2)

        local sqText = WM:CreateControl("$(parent)SqText", sq, CT_LABEL)
        sqText:SetFont("ZoFontGameSmall")
        sqText:SetAnchor(CENTER, sq, CENTER, 0, 0)
        sqText:SetDrawLevel(4)

        local bar = WM:CreateControl("$(parent)Bar", row, CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT, barBg, TOPLEFT, 1, 1)
        bar:SetAnchor(BOTTOMRIGHT, barBg, BOTTOMRIGHT, -1, -1)
        bar:SetMinMax(0, 1)
        bar:SetDrawLevel(2)

        -- Markierung bei 80 %
        local mark = WM:CreateControl("$(parent)Mark80", row, CT_TEXTURE)
        mark:SetColor(1, 1, 1, 0.7)
        mark:SetDimensions(2, ROW_H - 6)
        mark:SetAnchor(LEFT, barBg, LEFT, math.floor(barW * 0.8), 0)
        mark:SetDrawLevel(3)

        local status = WM:CreateControl("$(parent)Status", row, CT_LABEL)
        status:SetFont("ZoFontGameSmall")
        status:SetAnchor(LEFT, bar, LEFT, 4, 0)
        status:SetDrawLevel(4)

        local pct = WM:CreateControl("$(parent)Pct", row, CT_LABEL)
        pct:SetFont("ZoFontGameBold")
        pct:SetAnchor(RIGHT, bar, RIGHT, -4, 0)
        pct:SetDrawLevel(4)

        rows[i] = { ctrl = row, name = name, bar = bar, status = status, pct = pct,
                    sq = sq, sqFill = sqFill, sqText = sqText }
    end

    RG.win = win
    RG.content = content
    content:SetHidden(true)

    -- Grosse Meldung in der Bildschirmmitte
    local aw = WM:CreateTopLevelWindow("ReefGuardianHelperAlert")
    aw:SetDimensions(900, 120)
    aw:SetAnchor(CENTER, GuiRoot, CENTER, 0, -180)
    aw:SetMouseEnabled(false)
    aw:SetHidden(true)
    local at = WM:CreateControl("$(parent)Text", aw, CT_LABEL)
    at:SetFont("$(BOLD_FONT)|52|soft-shadow-thick")
    at:SetColor(1, 0.45, 0.1, 1)
    at:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    at:SetAnchor(TOP, aw, TOP, 0, 0)
    local as = WM:CreateControl("$(parent)Sub", aw, CT_LABEL)
    as:SetFont("$(BOLD_FONT)|26|soft-shadow-thick")
    as:SetColor(1, 0.85, 0.5, 1)
    as:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    as:SetAnchor(TOP, at, BOTTOM, 0, 4)
    RG.alertWin, RG.alertText, RG.alertSub = aw, at, as

    local fragment = ZO_HUDFadeSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function ApplyLock()
    RG.win:SetMovable(not RG.sv.locked)
    RG.title:SetText(RG.sv.locked and "Reef Guardian" or "Reef Guardian (verschiebbar)")
    RG.twinWin:SetMovable(not RG.sv.locked)
    RG.twinTitle:SetText(RG.sv.locked and "Lylanar & Turlassil" or "Lylanar & Turlassil (verschiebbar)")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Effekte auf Boss-Tags liefern unitTag + unitId -> Zuordnung fuer Combat-Events
-- und die Riff-Effekte direkt am Guardian (Heartburn / Vulnerability)
local function OnBossEffect(_, changeType, _, _, unitTag, _, endTime, _, _, _, _, _, _, _, unitId, abilityId)
    if not unitTag or unitTag == "" then return end
    if unitId and unitId ~= 0 then
        unitIdToTag[unitId] = unitTag
        local k = tagToKey[unitTag]
        if k then SetUnitId(k, unitId) end
    end
    if abilityId ~= ID_EFF_RIFF and abilityId ~= ID_EFF_VULN then return end
    local k = tagToKey[unitTag]
    if not k then return end
    local r = recs[k]
    local gone = changeType == EFFECT_RESULT_FADED
    if abilityId == ID_EFF_RIFF then
        if gone then
            r.riffEnd = nil
        else
            if not r.riffEnd then NewReef(r, Now()) end
            r.riffEnd = (endTime and endTime > Now()) and endTime or (Now() + RIFF_MAX)
            r.riffAt = r.riffAt or Now()
            r.runs = math.max(r.runs, 1)
            if k == "M2" then m2RiffStarted = true end
        end
    else
        r.vulnEnd = (not gone and endTime and endTime > Now()) and endTime or nil
    end
    if debugMode then
        Print(string.format("%s: %s %s", LABEL[k], abilityId == ID_EFF_RIFF and "Riff" or "Vulnerability",
            gone and "weg" or string.format("%.0fs", (endTime or 0) - Now())))
    end
end

local lastEvent = {}
-- Ergebnis und isError filtert ESO bereits ueber die Event-Filter (RegisterFightEvents)
local function OnCombat(_, result, _, _, _, _, sourceName, _, _, _, hitValue, _, _, _, sourceUnitId, _, abilityId)
    local now = Now()
    -- Doppelte Events (BEGIN + GAINED) zusammenfassen
    local dk = abilityId .. ":" .. tostring(sourceUnitId)
    if lastEvent[dk] and now - lastEvent[dk] < 1.0 then return end
    lastEvent[dk] = now

    local r = RecByUnitId(sourceUnitId)
    if debugMode then
        Print(string.format("%s (%d) res=%d hit=%d src=%s id=%d -> %s",
            GetAbilityName(abilityId), abilityId, result, hitValue or 0,
            zo_strformat("<<1>>", sourceName), sourceUnitId, r and LABEL[r.key] or "?"))
    end

    if abilityId == ID_HEARTBURN then
        heartburnCount = heartburnCount + 1
        if r then
            r.riffAt = now
            r.runs = math.max(r.runs, 1)
            -- Rueckfall, falls der Riff-Effekt am Guardian nicht ankommt
            if not r.riffEnd then
                NewReef(r, now)
                r.riffEnd = now + RIFF_MAX
            end
            if r.key == "M2" then m2RiffStarted = true end
        elseif heartburnCount >= 3 then
            -- Rueckfall ohne Zuordnung: 3. Riff ist in der Praxis Mittel-2
            m2RiffStarted = true
        end
        return
    end
    if not r then return end

    if abilityId == ID_CHARGE then
        -- neuer Lauf, wenn der letzte Charge laenger her ist (2. Charge = Ankunft)
        if not r.runStart or now - r.runStart > 13 then
            r.runStart = now
            r.riffAt = nil
            r.runs = r.runs + 1
        end
    elseif abilityId == ID_ACIDREFLUX then
        local dur = (hitValue and hitValue > 1000 and hitValue < 20000) and hitValue / 1000 or 12
        r.arEnd = now + dur
    elseif abilityId == ID_REPLICATION then
        r.replEnd = now + 2.5
    end
end

-- Pro Faehigkeit und Ergebnis eine Registrierung, damit ESO Faehigkeit, Ergebnis und Fehler filtert
local TRACKED_RESULTS = { ACTION_RESULT_BEGIN, ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_EFFECT_GAINED_DURATION }

local function RegisterFightEvents(on)
    for _, id in ipairs(TRACKED) do
        for _, res in ipairs(TRACKED_RESULTS) do
            local ns = RG.name .. "_ce_" .. id .. "_" .. res
            if on then
                EM:RegisterForEvent(ns, EVENT_COMBAT_EVENT, OnCombat)
                EM:AddFilterForEvent(ns, EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_ABILITY_ID, id,
                    REGISTER_FILTER_COMBAT_RESULT, res,
                    REGISTER_FILTER_IS_ERROR, false)
            else
                EM:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
            end
        end
    end
    local ns = RG.name .. "_bosseff"
    if on then
        EM:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnBossEffect)
        EM:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
    else
        EM:UnregisterForEvent(ns, EVENT_EFFECT_CHANGED)
    end
end

local function OnPlayerActivated()
    if InZone() or RG.sv.alwaysShow then
        RegisterFightEvents(true)
        StartUpdates()
    else
        RegisterFightEvents(false)
        StopUpdates()
    end
end

---------------------------------------------------------------------------
-- Testanzeige
---------------------------------------------------------------------------
-- Szenen nach eurer Taktik. Fehlender Guardian = noch nicht gespawnt ("Soon").
-- st: run = rennt, riff = Riff gerade gesetzt, ar = kotzt, repl = repliziert, dead = tot
-- runs = Anzahl bisheriger Laeufe (Stern hinter dem Namen), free = Toetungssperre aufgehoben
-- rf = Riff noch offen (s), vu = Vulnerability nach Zerstoerung (s)
local SCENES = {
    { cap = "Large charges to Reef 1",
      G = { 99, st = "run", t = 0.5 } },
    { cap = "Reef 1 placed, Medium 1 Acid Reflux",
      G = { 96, runs = 1, st = "riff", rf = 57 }, M1 = { 93, st = "ar", t = 9 } },
    { cap = "Large + Medium 1 < 80 %: Replication",
      G = { 78, runs = 1, st = "repl" }, M1 = { 76, st = "repl" } },
    { cap = "Medium 1 charges to Reef 2, Medium 2 + Small 1 spawn",
      G = { 70, runs = 1 }, M1 = { 60, st = "run", t = 1 }, M2 = { 100 }, K1 = { 100 } },
    { cap = "Move to Reef 2",
      G = { 58, runs = 1 }, M1 = { 57, runs = 1, st = "riff", rf = 59 }, M2 = { 97, st = "ar", t = 10 }, K1 = { 95, st = "ar", t = 7 } },
    { cap = "Medium 2 close to 80 % (orange)",
      G = { 36, runs = 1 }, M1 = { 54, runs = 1, rf = 50 }, M2 = { 82 }, K1 = { 93 } },
    { cap = "Medium 2 charges to Reef 3 - DON'T KILL",
      G = { 20, runs = 1 }, M1 = { 50, runs = 1, rf = 46 }, M2 = { 72, st = "run", t = 2 }, K1 = { 92 } },
    { cap = "Large < 10 %, Medium 2 still charging -> STOP DAMAGE",
      G = { 8, runs = 1 }, M1 = { 44, runs = 1, rf = 42 }, M2 = { 71, st = "run", t = 5 }, K1 = { 92 } },
    { cap = "Reef 3 placed -> KILL THE GUARDIANS (Ping)",
      G = { 5, runs = 1 }, M1 = { 38, runs = 1, rf = 39 }, M2 = { 70, runs = 1, st = "riff", rf = 59 }, K1 = { 91 }, free = true },
    { cap = "Large + Medium 1 dead -> move to Reef 3 + ults",
      G = { 0, runs = 1, st = "dead" }, M1 = { 0, runs = 1, st = "dead" }, M2 = { 64, runs = 1, rf = 48 }, K1 = { 88, st = "ar", t = 8 }, free = true },
    { cap = "Reef 3 < 25 s (yellow) - Medium 2 can't replicate while his reef is up",
      G = { 0, runs = 1, st = "dead" }, M1 = { 0, runs = 1, st = "dead" }, M2 = { 55, runs = 1, rf = 24 }, K1 = { 84 }, free = true },
    { cap = "Reef 3 down -> Medium 2 vulnerable 10 s (green)",
      G = { 0, runs = 1, st = "dead" }, M1 = { 0, runs = 1, st = "dead" }, M2 = { 30, runs = 1, vu = 8 }, K1 = { 82 }, free = true },
    { cap = "Vulnerability over -> Medium 2 replicates Small 2",
      G = { 0, runs = 1, st = "dead" }, M1 = { 0, runs = 1, st = "dead" }, M2 = { 22, runs = 1, st = "repl" }, K1 = { 81 }, free = true },
    { cap = "Small 1 < 80 % -> charges to Reef 4",
      G = { 0, runs = 1, st = "dead" }, M1 = { 0, runs = 1, st = "dead" }, M2 = { 0, runs = 1, st = "dead" }, K1 = { 77, st = "run", t = 1 }, K2 = { 84 }, free = true },
    { cap = "Small 2 < 80 % -> charges to Reef 5",
      G = { 0, runs = 1, st = "dead" }, M1 = { 0, runs = 1, st = "dead" }, M2 = { 0, runs = 1, st = "dead" }, K1 = { 40, runs = 1, rf = 56 }, K2 = { 76, st = "run", t = 3 }, free = true },
}
local SCENE_DUR = 4
local testStart, testScene, testFixed = 0, 0, nil

local function ApplyScene(i)
    local s = SCENES[i]
    ResetFight()
    local now = Now()
    for _, k in ipairs(ORDER) do
        local spec = s[k]
        if spec then
            local r = recs[k]
            r.spawned, r.pct, r.runs = true, spec[1], spec.runs or 0
            if spec.st == "run" then r.runStart = now - (spec.t or 0); r.runs = r.runs + 1
            elseif spec.st == "riff" then r.riffAt = now
            elseif spec.st == "ar" then r.arEnd = now + (spec.t or 8)
            elseif spec.st == "repl" then r.replEnd = now + SCENE_DUR
            elseif spec.st == "dead" then r.dead = true end
            if spec.rf then r.riffEnd = now + spec.rf end
            if spec.vu then r.vulnEnd = now + spec.vu end
        end
    end
    m2RiffStarted = s.free or false
    -- Meldung nur beim Wechsel von "gesperrt" zu "frei" (Szene 8), nicht in jeder freien Szene
    killAlertShown = (s.free and i > 1 and SCENES[i - 1].free) and true or false
    testScene = i
    RG.testCaption = string.format("Test %d/%d: %s", i, #SCENES, s.cap)
end

local function Test(arg)
    local n = tonumber(arg)
    local now = Now()
    if arg == "reef" then
        reefTestStart = now
        Print(string.format("Riff-Meldung: 6 s WAIT, dann KILL (Wartezeit jetzt %d s)", RG.sv.reefWait))
        StartUpdates()
        return
    end
    if arg == "twins" then
        twinTestUntil = now + 20
        Print("Fenster erster Boss fuer 20 s (Beispielwerte)")
        StartUpdates()
        return
    end
    if n and SCENES[n] then
        testFixed = n
        testUntil = now + 20
        ApplyScene(n)
        Print(string.format("Szene %d fuer 20 s: %s", n, SCENES[n].cap))
    else
        testFixed = nil
        testStart = now
        testUntil = now + #SCENES * SCENE_DUR
        ApplyScene(1)
        Print(string.format("Testablauf: %d Szenen a %d s (/rgh test <1-%d> fuer eine einzelne)", #SCENES, SCENE_DUR, #SCENES))
    end
    StartUpdates()
end

TestTick = function(now)
    if testFixed then return end
    local i = math.min(#SCENES, math.floor((now - testStart) / SCENE_DUR) + 1)
    if i ~= testScene then ApplyScene(i) end
end

TestEnd = function()
    RG.testCaption = nil
    testScene, testFixed = 0, nil
    ResetFight()
    ApplyLock()
    RG.caption:SetHidden(true)
end

---------------------------------------------------------------------------
-- Slash-Commands
---------------------------------------------------------------------------
local function Help()
    Print("Version " .. RG.version .. " - Befehle:")
    d("  /rgh unlock | lock  - Fenster verschieben / fixieren")
    d("  /rgh test           - Testablauf: alle Szenen nach unserer Taktik (je 4 s)")
    d("  /rgh test <nr>      - eine Szene 20 s stehen lassen (1-" .. #SCENES .. ")")
    d("  /rgh test twins     - Fenster erster Boss (Lylanar / Turlassil) 20 s anzeigen")
    d("  /rgh test reef      - Meldung fuer Spieler im Riff (WAIT, dann KILL) anzeigen")
    d("  /rgh reefwait <s>   - im Riff von Medium 2 spaetestens nach so vielen s 'KILL' (jetzt: " .. RG.sv.reefWait .. " s)")
    d("  /rgh killlock       - Toetungssperre-Anzeige an/aus")
    d("  /rgh alert all|dd|off - Meldungen STOP DAMAGE / KILL fuer alle / nur DDs / aus (jetzt: " .. RG.sv.alertMode .. ")")
    d("  /rgh alert test     - beide Meldungen nacheinander anzeigen")
    d("  /rgh stop <pct>     - Schwelle fuer 'STOP DAMAGE' (jetzt: " .. RG.sv.stopPct .. " %)")
    d("  /rgh always         - Fenster ueberall anzeigen an/aus (sonst nur in Dreadsail Reef)")
    d("  /rgh debug          - erkannte Casts und Zuordnungen im Chat loggen")
    d("  /rgh reset          - Position zuruecksetzen")
end

local function OnSlash(args)
    local cmd, arg = zo_strsplit(" ", zo_strlower(args or ""))
    if cmd == "unlock" then
        RG.sv.locked = false
        ApplyLock()
        StartUpdates()
    elseif cmd == "lock" then
        RG.sv.locked = true
        ApplyLock()
        OnPlayerActivated()
    elseif cmd == "test" then
        Test(arg)
    elseif cmd == "killlock" then
        RG.sv.showKillLock = not RG.sv.showKillLock
        Print("Toetungssperre anzeigen: " .. tostring(RG.sv.showKillLock))
    elseif cmd == "stop" then
        local v = tonumber(arg)
        if v and v > 0 and v < 100 then
            RG.sv.stopPct = v
            Print(string.format("'STOP DAMAGE' unter %d %% (Large / Medium 1, solange Medium 2 kein Riff hat)", v))
        else
            Print("Schwelle jetzt: " .. RG.sv.stopPct .. " %  (z.B. /rgh stop 10)")
        end
    elseif cmd == "reefwait" then
        local v = tonumber(arg)
        if v and v >= 0 and v <= 60 then
            RG.sv.reefWait = v
            Print(string.format("Im Riff von Medium 2: 'WAIT' solange Large oder Medium 1 lebt, spaetestens nach %d s 'KILL'", v))
        else
            Print("Wartezeit jetzt: " .. RG.sv.reefWait .. " s  (0-60, z.B. /rgh reefwait 35)")
        end
    elseif cmd == "alert" then
        if arg == "dd" or arg == "all" or arg == "off" then
            RG.sv.alertMode = arg
            Print("Meldung 'Kill the Guardians': " .. ({ dd = "nur DDs", all = "alle", off = "aus" })[arg])
        elseif arg == "test" then
            ShowCenterAlert("STOP DAMAGE", "Large 8% - Medium 2 reef not up yet", "stop")
            zo_callLater(function() ShowCenterAlert(ALERT_TEXT, ALERT_SUB, "kill") end, 3500)
            StartUpdates()
        else
            Print("Meldung 'Kill the Guardians' jetzt: " .. RG.sv.alertMode .. "  (/rgh alert dd | all | off | test)")
        end
    elseif cmd == "always" then
        RG.sv.alwaysShow = not RG.sv.alwaysShow
        Print("Ueberall anzeigen: " .. tostring(RG.sv.alwaysShow))
        OnPlayerActivated()
    elseif cmd == "debug" then
        debugMode = not debugMode
        Print("Debug " .. (debugMode and "an" or "aus"))
    elseif cmd == "reset" then
        RG.sv.left, RG.sv.top = defaults.left, defaults.top
        RG.win:ClearAnchors()
        RG.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, RG.sv.left, RG.sv.top)
        RG.sv.tleft, RG.sv.ttop = defaults.tleft, defaults.ttop
        RG.twinWin:ClearAnchors()
        RG.twinWin:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, RG.sv.tleft, RG.sv.ttop)
    else
        Help()
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= RG.name then return end
    EM:UnregisterForEvent(RG.name, EVENT_ADD_ON_LOADED)

    RG.sv = ZO_SavedVars:NewAccountWide("ReefGuardianHelper_SV", 1, nil, defaults)
    -- 1.0.1: Standard fuer Meldungen von "dd" auf "all" geaendert; alte gespeicherte Werte einmalig umstellen
    if not RG.sv.alertDefaultV2 then
        if RG.sv.alertMode == "dd" then RG.sv.alertMode = "all" end
        RG.sv.alertDefaultV2 = true
    end
    -- 1.2.0: Gruppenfenster entfernt, alte Einstellungen aufraeumen
    for _, k in ipairs({ "gleft", "gtop", "showGroup", "staticWarn", "staticDanger", "acidWarn", "acidDanger", "selfWarn", "maskWearers" }) do
        RG.sv[k] = nil
    end
    ResetFight()
    CreateUI()
    CreateTwinUI()

    ApplyLock()

    EM:RegisterForEvent(RG.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    SLASH_COMMANDS["/rgh"] = OnSlash
end

EM:RegisterForEvent(RG.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
