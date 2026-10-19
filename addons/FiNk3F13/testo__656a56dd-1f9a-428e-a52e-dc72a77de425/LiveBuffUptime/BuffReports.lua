local L = LiveBuffUptimeLocalization and LiveBuffUptimeLocalization.Text or function(text) return text end
local Reports = {}
LiveBuffUptimeReports = Reports
local saved, window, scene, previousScene, previousUI, previousCamera
local controls, selected, page, selectedFight = {}, 1, 1, 1
local capturedFight
local consoleLayout, nativeList, nativeScreen, rebuildingList, detailWindow
local historyFirst, historyCount
local listMode, listReport, lastListMode = "zones", nil, nil
local category, listCategory = "buffs", nil
local effectSelections = setmetatable({}, { __mode = "k" })
local enemyEffects, activeEnemyEffects = {}, {}
local selectedZone, listZone, selectionIndices = nil, nil, {}
local encounterTargets, encounterLocation, encounterBoss = {}, nil, nil
local encounterBossNames, bossCandidates, bossCheckedAt = {}, {}, nil
local encounterDeaths, encounterRunning, encounterPlayerKey = {}, false, nil
local encounterReceipts = {}
local activeReceipts = {}
local receiptFades = {}
local selectionChosen, deleteDialogRegistered = false, false
local deletePending
local deleteDialogName = "LiveBuffUptimeDeleteFight"
local sceneName = "LiveBuffUptimeReportScene"
local keybinds, opened = nil, false
local ROWS = 12
local HISTORY_LIMIT = 300
local function trimHistory(history)
    for index = #history, 1, -1 do
        if #history <= HISTORY_LIMIT then break end
        if not history[index].locked then table.remove(history, index) end
    end
end
local DEFAULT_PLACE_ICON = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_zoneStories.dds"
local LOCK_MARKER = " |t28:28:EsoUI/Art/Miscellaneous/locked_up.dds|t"
local placeIcons = {}
local function decimal(value, format)
    if LiveBuffUptimeLocalization then return LiveBuffUptimeLocalization.Decimal(value, format) end
    return (string.format(format or "%.2f", value):gsub("%.", ","))
end

local function displayTitle(report)
    local name = report and (report.encounterLabel or report.enemyName or report.title or report.zone) or L("Kampf")
    return zo_strformat("<<C:1>>", name or L("Kampf"))
end

local function reportDate(report)
    local date = tostring(report.date or "")
    local year, month, day = date:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if year then
        if LiveBuffUptimeLocalization and LiveBuffUptimeLocalization.language ~= "de" then return year .. "-" .. month .. "-" .. day end
        return day .. "." .. month .. "." .. year
    end
    return L("Datum unbekannt")
end

local function zoneKey(report)
    local key = type(report.zoneId) == "number" and report.zoneId > 0 and ("id:" .. report.zoneId)
        or ("name:" .. zo_strformat("<<1>>", report.zone or L("Unbekanntes Gebiet")))
    return report.date and (key .. ":date:" .. tostring(report.date)) or key
end

local function zoneTitle(report)
    return zo_strformat("<<C:1>>", report.zone or L("Unbekanntes Gebiet"))
end

local function enemyTitle(report)
    return zo_strformat("<<C:1>>", report.encounterLabel or report.enemyName or report.title or L("Gegner unbekannt"))
end

local function refreshBossCandidates()
    local now = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    if bossCheckedAt and now - bossCheckedAt < 0.5 then return end
    bossCheckedAt = now
    if not DoesUnitExist or not GetUnitName then return end
    for index = 1, 6 do
        local tag = "boss" .. index
        if DoesUnitExist(tag) and (not IsUnitDead or not IsUnitDead(tag)) then
            local name = GetUnitName(tag)
            if name and name ~= "" then bossCandidates[zo_strformat("<<C:1>>", name)] = true end
        end
    end
end

function Reports.ObserveBoss(tag, id, name)
    if not encounterRunning or not tag or not tag:match("^boss%d+$") then return end
    if not name or name == "" then name = GetUnitName and GetUnitName(tag) end
    if not name or name == "" then return end
    name = zo_strformat("<<C:1>>", name)
    encounterBossNames[name] = true
end

local function encounterLabel(report)
    if #report.bossNames > 0 then return table.concat(report.bossNames, ", ") end
    local byName, names = {}, {}
    for _, target in ipairs(report.enemies) do
        local group = byName[target.name]
        if not group then
            group = { name = target.name, count = 0, damage = 0 }
            byName[target.name] = group
            names[#names + 1] = group
        end
        group.count, group.damage = group.count + 1, group.damage + target.damage
    end
    table.sort(names, function(a, b) if a.damage == b.damage then return a.name < b.name end; return a.damage > b.damage end)
    local labels = {}
    for index = 1, math.min(2, #names) do
        local group = names[index]
        if index == 1 or group.damage >= names[1].damage / 2 then
            local name = group.count > 1 and string.format("%d x %s", group.count, group.name) or group.name
            if #labels == 0 or #(table.concat(labels, ", ") .. ", " .. name) <= 60 then labels[#labels + 1] = name end
        end
    end
    return #labels > 0 and (L("Gegnergruppe: ") .. table.concat(labels, ", ")) or L("Gegner unbekannt")
end

function Reports.BeginEncounter(now, running, playerKey)
    encounterTargets, encounterBoss = {}, nil
    encounterBossNames, bossCandidates, bossCheckedAt = {}, {}, nil
    refreshBossCandidates()
    encounterDeaths, encounterRunning = {}, running ~= false
    encounterReceipts = {}
    for id, buff in pairs(activeReceipts) do
        for key, slots in pairs(buff) do
            for slot, effect in pairs(slots) do if effect.expires <= now then slots[slot] = nil end end
            if not next(slots) then buff[key] = nil end
        end
        if not next(buff) then activeReceipts[id] = nil end
    end
    for id, fades in pairs(receiptFades) do
        for key, fade in pairs(fades) do if now - fade.time > 0.05 then fades[key] = nil end end
        if not next(fades) then receiptFades[id] = nil end
    end
    encounterPlayerKey = playerKey
    enemyEffects = {}
    for key, effect in pairs(activeEnemyEffects) do
        if effect.ends and effect.ends > now then
            Reports.RecordDebuff(effect.id, effect.targetId, effect.name, effect.slot, now, effect.ends, true)
        else activeEnemyEffects[key] = nil end
    end
    encounterLocation = { zone = GetUnitZone and GetUnitZone("player"), zoneIndex = GetUnitZoneIndex and GetUnitZoneIndex("player") }
    if DoesUnitExist and GetUnitName then
        for index = 1, 6 do
            if DoesUnitExist("boss" .. index) then
                local name = GetUnitName("boss" .. index)
                if name and name ~= "" then encounterBoss = zo_strformat("<<C:1>>", name); break end
            end
        end
    end
end

function Reports.RecordBuffReceipt(id, key, slot, change, starts, time, ends)
    if not id or not key or not slot then return end
    if change ~= EFFECT_RESULT_GAINED and change ~= EFFECT_RESULT_UPDATED and change ~= EFFECT_RESULT_FADED then
        return
    end
    local activeBuff = activeReceipts[id]
    if not activeBuff then activeBuff = {}; activeReceipts[id] = activeBuff end
    local activeMember = activeBuff[key]
    if not activeMember then activeMember = {}; activeBuff[key] = activeMember end
    local previous = activeMember[slot]
    local wasActive, activeExpiry = false, 0
    for _, effect in pairs(activeMember) do
        if effect.expires > time then
            wasActive = true
            activeExpiry = math.max(activeExpiry, effect.expires)
        end
    end
    -- Missing/stale expiry data must not erase a known active application in the counters.
    if change == EFFECT_RESULT_UPDATED and (not ends or ends <= time) then
        return
    end
    local fades = receiptFades[id]
    if not fades then fades = {}; receiptFades[id] = fades end
    local faded = fades[key]
    -- Some replacements arrive as FADED + GAINED in the same event burst.
    local replaced = faded and time >= faded.time and time - faded.time <= 0.05 and faded.expires > time
    local duplicate = change == EFFECT_RESULT_GAINED and previous and previous.starts == starts and previous.expires == ends
    local previousExpiry = previous and previous.expires > time and previous.expires or activeExpiry
    local renewed = change == EFFECT_RESULT_UPDATED and wasActive and ends and ends > previousExpiry
    if change == EFFECT_RESULT_GAINED and not duplicate then renewed = wasActive or replaced end
    if change == EFFECT_RESULT_FADED then
        if previous and previous.expires > time then fades[key] = {time = time, expires = previous.expires} end
        activeMember[slot] = nil
    elseif ends and ends > time then
        activeMember[slot] = {expires = ends, starts = starts}
        if change == EFFECT_RESULT_GAINED then fades[key] = nil end
    else activeMember[slot] = nil end
    if not encounterRunning then return end
    local buff = encounterReceipts[id]
    if not buff then buff = {}; encounterReceipts[id] = buff end
    local member = buff[key]
    if not member then member = { slots = {}, times = {}, renewals = {} }; buff[key] = member end
    if renewed then
        if #member.renewals < 2048 then member.renewals[#member.renewals + 1] = time
        else member.renewalsTruncated = true end
    end
    if change == EFFECT_RESULT_FADED then member.slots[slot] = nil
    elseif change == EFFECT_RESULT_GAINED then
        local signature = starts and starts > 0 and starts or true
        if not duplicate and member.slots[slot] ~= signature then
            member.slots[slot] = signature
            if not renewed then
                if #member.times < 2048 then member.times[#member.times + 1] = time
                else member.truncated = true end
            end
        end
    end
end

-- Shared native enemy intervals; player and group scopes are not modified.
function Reports.RecordDebuff(id, targetId, name, slot, time, ends, active)
    if not id or not targetId or targetId <= 0 or not slot then return end
    if active and ends and ends > 0 and ends <= time then return end
    local key = tostring(targetId) .. ":" .. tostring(id) .. ":" .. tostring(slot)
    if active and (ends == nil or ends == 0) and activeEnemyEffects[key]
        and activeEnemyEffects[key].ends and activeEnemyEffects[key].ends > time then
        ends = activeEnemyEffects[key].ends
    end
    if active then
        local count = 0
        for _ in pairs(activeEnemyEffects) do count = count + 1 end
        if count >= 512 and not activeEnemyEffects[key] then return end
        activeEnemyEffects[key] = { id = id, targetId = targetId, name = name, slot = slot, ends = ends }
    else activeEnemyEffects[key] = nil end
    if not encounterRunning then return end
    local effect = enemyEffects[id]
    if not effect then
        local count = 0
        for _ in pairs(enemyEffects) do count = count + 1 end
        if count >= 64 then return end
        effect = { targets = {} }
        enemyEffects[id] = effect
    end
    local target = effect.targets[targetId]
    if not target then
        local count = 0
        for _ in pairs(effect.targets) do count = count + 1 end
        if count >= 48 then return end
        target = { scope = LiveBuffUptimeMeter.NewScope(), expires = {}, name = name }
        effect.targets[targetId] = target
    end
    for oldSlot, expiry in pairs(target.expires) do
        if expiry <= time then
            LiveBuffUptimeMeter.ScopeEvent(target.scope, oldSlot, expiry, false)
            target.expires[oldSlot] = nil
        end
    end
    if name and name ~= "" then target.name = name end
    LiveBuffUptimeMeter.ScopeEvent(target.scope, slot, time, active)
    target.expires[slot] = active and ends and ends > time and ends or nil
end

function Reports.IsEnemy(id)
    return encounterTargets[id] ~= nil
end

function Reports.DebuffResult(id, targetId, starts, ends)
    local effect = enemyEffects[id]
    local target = effect and effect.targets[targetId]
    if not target or not starts or not ends or ends < starts then return end
    local meter = LiveBuffUptimeMeter
    for slot, expiry in pairs(target.expires) do
        if expiry <= ends then
            meter.ScopeEvent(target.scope, slot, expiry, false)
            target.expires[slot] = nil
        end
    end
    local covered = meter.IntervalTotal(target.scope.intervals, starts, ends)
    if target.scope.starts then covered = covered + math.max(0, ends - math.max(starts, target.scope.starts)) end
    local duration = math.max(0, ends - starts)
    return {covered = covered, duration = duration, percent = duration > 0 and covered / duration * 100 or 0,
        starts = starts, ends = ends, members = {}}
end

function Reports.ObserveDeath(key, time, dead)
    if not encounterRunning or not key or type(time) ~= "number" or type(dead) ~= "boolean" then return end
    local member = encounterDeaths[key]
    if not member then
        member = { dead = dead, intervals = {}, transitions = {} }
        encounterDeaths[key] = member
        if dead then member.deadSince = time end
        return
    end
    if member.paused then
        member.paused, member.dead = false, dead
        member.deadSince = dead and time or nil
        return
    end
    if member.dead == dead then return end
    member.dead = dead
    if dead then
        member.deadSince = time
        member.transitions[#member.transitions + 1] = time
    elseif member.deadSince then
        member.intervals[#member.intervals + 1] = { member.deadSince, time }
        member.deadSince = nil
    end
end

function Reports.ObserveDeathRoster(roster, time, playerKey, playerDead)
    if not encounterRunning then return end
    local seen = { [playerKey] = true }
    Reports.ObserveDeath(playerKey, time, playerDead)
    for _, member in ipairs(roster or {}) do
        if member.available and member.key ~= playerKey then
            seen[member.key] = true
            Reports.ObserveDeath(member.key, time, member.dead)
        end
    end
    for key, member in pairs(encounterDeaths) do
        if not seen[key] and not member.paused then
            if member.deadSince then member.intervals[#member.intervals + 1] = { member.deadSince, time } end
            member.deadSince, member.paused = nil, true
        end
    end
end

function Reports.RecordDamage(sourceType, targetType, targetId, targetName, damage)
    if sourceType == nil or COMBAT_UNIT_TYPE_PLAYER == nil then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and (COMBAT_UNIT_TYPE_PLAYER_PET == nil or sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then return end
    if targetType == COMBAT_UNIT_TYPE_PLAYER or (COMBAT_UNIT_TYPE_GROUP ~= nil and targetType == COMBAT_UNIT_TYPE_GROUP)
        or (COMBAT_UNIT_TYPE_PLAYER_PET ~= nil and targetType == COMBAT_UNIT_TYPE_PLAYER_PET)
        or (COMBAT_UNIT_TYPE_GROUP_PET ~= nil and targetType == COMBAT_UNIT_TYPE_GROUP_PET) then return end
    if not damage or damage <= 0 then return end
    local key = type(targetId) == "number" and targetId > 0 and targetId
        or (targetName and targetName ~= "" and ("name:" .. zo_strformat("<<1>>", targetName)))
    if not key then return end
    local entry = encounterTargets[key]
    if not entry then
        local count = 0
        for _ in pairs(encounterTargets) do count = count + 1 end
        if count >= 48 then return end
        entry = { id = targetId, damage = 0 }
        encounterTargets[key] = entry
    end
    if targetName and targetName ~= "" then entry.name = zo_strformat("<<C:1>>", targetName) end
    entry.damage = entry.damage + damage
    refreshBossCandidates()
    if entry.name and bossCandidates[entry.name] then encounterBossNames[entry.name] = true end
end

local function attachEncounter(report, trackers, receiptWindow)
    -- Applications belong to the combat, even when damage-based uptime ends earlier.
    local receiptStart = receiptWindow and receiptWindow.started or report.started
    local receiptEnd = receiptWindow and receiptWindow.ended or report.ended
    local reportIds = {}
    for _, tracker in ipairs(trackers) do
        if tracker.config.enabled ~= false and tracker.config.showInReports ~= false then
            reportIds[tracker.config.id] = true
        end
    end
    if encounterLocation then report.zone, report.zoneIndex = encounterLocation.zone, encounterLocation.zoneIndex end
    report.enemies = {}
    for _, target in pairs(encounterTargets) do
        report.enemies[#report.enemies + 1] = { id = target.id, name = target.name or (L("Gegner ") .. target.id), damage = target.damage }
    end
    table.sort(report.enemies, function(a, b) if a.damage == b.damage then return a.name < b.name end; return a.damage > b.damage end)
    report.enemyName = report.enemies[1] and report.enemies[1].name or encounterBoss or report.title
    report.bossNames = {}
    for name in pairs(encounterBossNames) do report.bossNames[#report.bossNames + 1] = name end
    table.sort(report.bossNames)
    report.encounterLabel = encounterLabel(report)
    report.debuffs = {}
    local duration = math.max(0, report.ended - report.started)
    for id, effect in pairs(enemyEffects) do
        local debuff = { id = id, name = GetAbilityName and zo_strformat("<<1>>", GetAbilityName(id)) or tostring(id),
            unit = "reticleover", basis = "combat", covered = 0, duration = 0, members = {} }
        for targetId, target in pairs(effect.targets) do
            if encounterTargets[targetId] then
                local result = Reports.DebuffResult(id, targetId, report.started, report.ended)
                local covered = result.covered
                debuff.members[#debuff.members + 1] = { id = targetId,
                    name = zo_strformat("<<C:1>>", target.name or encounterTargets[targetId].name or L("Gegner")),
                    covered = covered, duration = duration }
                debuff.covered, debuff.duration = debuff.covered + covered, debuff.duration + duration
            end
        end
        if #debuff.members > 0 and reportIds[id] then
            table.sort(debuff.members, function(a, b) return a.name < b.name end)
            debuff.percent = debuff.duration > 0 and debuff.covered / debuff.duration * 100 or 0
            report.debuffs[#report.debuffs + 1] = debuff
        end
    end
    table.sort(report.debuffs, function(a, b) return a.name < b.name end)
    for _, buff in ipairs(report.buffs) do
        for _, row in ipairs(buff.members) do
            local key = row.deathKey or (buff.unit == "player" and encounterPlayerKey) or row.account
            local data = encounterDeaths[key]
            local receipts = encounterReceipts[buff.id] and encounterReceipts[buff.id][key]
            row.received, row.renewed = 0, 0
            if receipts then
                for _, time in ipairs(receipts.times) do
                    if time >= receiptStart and time <= receiptEnd then row.received = row.received + 1 end
                end
                if receipts.truncated then row.received = nil end
                for _, time in ipairs(receipts.renewals) do
                    if time >= receiptStart and time <= receiptEnd then row.renewed = row.renewed + 1 end
                end
                if receipts.renewalsTruncated then row.renewed = nil end
            end
            if data then
                row.deaths, row.deadTime = 0, 0
                for _, time in ipairs(data.transitions) do
                    if time >= report.started and time <= report.ended then row.deaths = row.deaths + 1 end
                end
                for _, interval in ipairs(data.intervals) do
                    row.deadTime = row.deadTime + math.max(0, math.min(report.ended, interval[2]) - math.max(report.started, interval[1]))
                end
                if data.deadSince then row.deadTime = row.deadTime + math.max(0, report.ended - math.max(report.started, data.deadSince)) end
            end
            row.deathKey = nil
        end
    end
    encounterRunning = false
end

local function placeIcon(zone, zoneIndex)
    if not zoneIndex or not zone or zone == "" then return DEFAULT_PLACE_ICON end
    local key = tostring(zoneIndex) .. ":" .. zone
    if placeIcons[key] then return placeIcons[key] end
    local indices = { zoneIndex }
    if GetZoneId and GetParentZoneId and GetZoneIndex then
        local parent = GetZoneIndex(GetParentZoneId(GetZoneId(zoneIndex)))
        if parent and parent > 0 and parent ~= zoneIndex then indices[#indices + 1] = parent end
    end
    local name = zo_strformat("<<1>>", zone):lower()
    if GetNumPOIs and GetPOIInfo and GetPOIMapInfo then
        for _, index in ipairs(indices) do
            for poi = 1, GetNumPOIs(index) do
                local poiName = GetPOIInfo(index, poi)
                if poiName and zo_strformat("<<1>>", poiName):lower() == name then
                    local _, _, _, icon = GetPOIMapInfo(index, poi)
                    if icon and icon ~= "" then placeIcons[key] = icon; return icon end
                end
            end
        end
    end
    placeIcons[key] = DEFAULT_PLACE_ICON
    return DEFAULT_PLACE_ICON
end

local function roleName(role)
    if role ~= nil and role == LFG_ROLE_DPS then return L("DD") end
    if role ~= nil and role == LFG_ROLE_TANK then return "Tank" end
    if role ~= nil and role == LFG_ROLE_HEAL then return L("Heiler") end
    return "-"
end

local function roleIcon(role)
    if role ~= nil and role == LFG_ROLE_DPS then return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_dps.dds" end
    if role ~= nil and role == LFG_ROLE_TANK then return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_tank.dds" end
    if role ~= nil and role == LFG_ROLE_HEAL then return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_healer.dds" end
end

function Reports.Init(settings)
    saved = settings
    saved.uptimeHistory = saved.uptimeHistory or {}
    if #saved.uptimeHistory == 0 and saved.lastUptimeReport then saved.uptimeHistory[1] = saved.lastUptimeReport end
    trimHistory(saved.uptimeHistory)
    saved.lastUptimeReport = saved.uptimeHistory[1]
    selectedFight = 1
    category, listCategory = "buffs", nil
    selectionChosen = false
    selectedZone, listZone, lastListMode = nil, nil, nil
end

local function currentReport()
    local history = saved and saved.uptimeHistory or {}
    selectedFight = math.max(1, math.min(selectedFight, #history))
    return history[selectedFight]
end

local function selectionLocked()
    if listMode == "zones" then
        local count, locked = 0, 0
        for _, report in ipairs(saved and saved.uptimeHistory or {}) do
            if zoneKey(report) == selectedZone then
                count = count + 1
                if report.locked then locked = locked + 1 end
            end
        end
        return count > 0 and count == locked
    end
    local report = currentReport()
    return report and report.locked == true or false
end

local function currentEffects(report)
    return report and report[category] or {}
end

local function rememberEffectSelection()
    local report = currentReport()
    if not report then return end
    local selections = effectSelections[report] or {}
    selections[category] = { selected = selected, page = page }
    effectSelections[report] = selections
end

local function restoreEffectSelection()
    local report = currentReport()
    local selection = report and effectSelections[report] and effectSelections[report][category]
    selected, page = selection and selection.selected or 1, selection and selection.page or 1
end

function Reports.Capture(fight, trackers, playerId, targetId, nameOf)
    if not saved or not fight or fight.running or capturedFight == fight then return end
    local report = { version = 1, started = fight.combatstart, ended = fight.encounterEnds,
        timestamp = GetTimeStamp and GetTimeStamp() or nil, buffs = {},
        clock = GetTimeString and GetTimeString() or nil,
        date = GetDate and tostring(GetDate()) or nil,
        zone = GetUnitZone and GetUnitZone("player") or nil }
    if DoesUnitExist and GetUnitName then
        for index = 1, 6 do
            local tag = "boss" .. index
            if DoesUnitExist(tag) then
                local name = GetUnitName(tag)
                if name and name ~= "" then report.title = zo_strformat("<<1>>", name); break end
            end
        end
    end
    for _, tracker in ipairs(trackers) do
        if tracker.config.enabled ~= false and tracker.config.showInReports ~= false
            and (tracker.config.unit == "player" or tracker.config.unit == "group") then
            local result = LiveBuffUptimeEngine.Calculate(fight, tracker, playerId, targetId, true)
            local buff = { id = tracker.config.id, key = tracker.config.key, name = nameOf(tracker.config.id),
                unit = tracker.config.unit, groupRole = tracker.config.groupRole, basis = result.personalTime, covered = result.covered,
                duration = result.duration, percent = result.percent, truncated = result.truncated, members = {} }
            local function add(id, name, account, row, role)
                local deathKey = account or encounterPlayerKey
                if account == "player" or (account and account:match("^group%d+$")) then account = nil end
                buff.members[#buff.members + 1] = { id = id, name = name or L("Spieler"), account = account, role = role,
                    deathKey = deathKey,
                    counted = tracker.config.groupRole ~= "damage" or (LFG_ROLE_DPS ~= nil and role == LFG_ROLE_DPS),
                    covered = row and row.covered or 0, duration = row and row.duration or 0 }
            end
            if tracker.config.unit == "group" and fight.groupMembers then
                for key, member in pairs(fight.groupMembers) do
                    local row
                    for _, candidate in ipairs(result.members) do
                        if candidate.id == (member.id or key) then row = candidate; break end
                    end
                    add(member.id or key, member.name, key, row, member.role)
                end
            else
                for _, member in ipairs(result.members) do
                    add(member.id, member.name or (GetUnitName and GetUnitName("player")),
                        GetUnitDisplayName and GetUnitDisplayName("player"), member, fight.personalRole)
                end
            end
            table.sort(buff.members, function(a, b) return (a.account or a.name) < (b.account or b.name) end)
            report.buffs[#report.buffs + 1] = buff
        end
    end
    attachEncounter(report, trackers)
    if #report.buffs > 0 or #report.debuffs > 0 then
        capturedFight = fight
        Reports.Save(report)
    end
    return report
end

function Reports.Save(report)
    if saved and (#report.buffs > 0 or #(report.debuffs or {}) > 0) then
        local preserveSelection = opened or selectionChosen
        local previous = preserveSelection and currentReport()
        report.timestamp = report.timestamp or (GetTimeStamp and GetTimeStamp())
        report.clock = report.clock or (GetTimeString and GetTimeString())
        report.date = report.date or (GetDate and tostring(GetDate()))
        report.zone = report.zone or (GetUnitZone and GetUnitZone("player"))
        report.zoneIndex = report.zoneIndex or (GetUnitZoneIndex and GetUnitZoneIndex("player"))
        report.zoneId = report.zoneId or (report.zoneIndex and GetZoneId and GetZoneId(report.zoneIndex))
        report.placeIcon = report.placeIcon or placeIcon(report.zone, report.zoneIndex)
        table.insert(saved.uptimeHistory, 1, report)
        trimHistory(saved.uptimeHistory)
        saved.lastUptimeReport = saved.uptimeHistory[1]
        if saved.uptimeHistory[1] ~= report then
            d(L("LiveBuffUptime: Kampfspeicher vollstaendig gesperrt. Neuen Kampf nicht gespeichert; bitte einen Kampf entsperren oder loeschen."))
        end
        if previous then
            selectedFight = math.min(selectedFight + 1, #saved.uptimeHistory)
            for index, record in ipairs(saved.uptimeHistory) do
                if record == previous then selectedFight = index; break end
            end
        else selectedFight, selected, page = 1, 1, 1 end
        if opened then Reports.Refresh() end
    end
end

function Reports.CaptureFallback(trackers, starts, ends, duration, scoped, nameOf, roster, exclude, personalRole, receiptWindow)
    if not saved or not starts or not ends or ends <= starts then return end
    local meter = LiveBuffUptimeMeter
    local names = {}
    for _, member in ipairs(roster) do names[member.key] = GetUnitName and GetUnitName(member.tag) or member.key end
    local report = { version = 1, started = starts, ended = ends, fallback = true, buffs = {} }
    for _, tracker in ipairs(trackers) do
        local unit = tracker.config.unit
        if tracker.config.enabled ~= false and tracker.config.showInReports ~= false
            and (unit == "player" or unit == "group") then
            local buff = { id = tracker.config.id, key = tracker.config.key, name = nameOf(tracker.config.id),
                unit = unit, groupRole = tracker.config.groupRole, basis = "combat", covered = 0, duration = 0,
                percent = tracker.displayPercent or 0, members = {} }
            if unit == "group" then
                local window = tracker.group.measurementWindow
                local first, last = window and window.starts or tracker.group.firstDamageAt or starts,
                    window and window.ends or tracker.group.lastDamageAt or ends
                for key, member in pairs(tracker.group.members) do
                    local counted = tracker.config.groupRole ~= "damage" or (LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS)
                    local covered = meter.IntervalTotal(member.meter.intervals, first, last)
                    local eligible = meter.IntervalTotal(member.eligibility.intervals, first, last)
                    if exclude(tracker) then eligible = math.max(0, eligible - meter.ExcludedTotal(member.meter.intervals, member.excluded, first, last)) end
                    buff.members[#buff.members + 1] = { name = names[key] or key, account = key, role = member.role,
                        counted = counted, covered = covered, duration = eligible, deathKey = key }
                    if counted then buff.covered, buff.duration = buff.covered + covered, buff.duration + eligible end
                end
            else
                local first = math.max(tracker.state.since, starts)
                local eligible = math.min(duration or math.max(1, ends - first), math.max(1, ends - first))
                local intervals = {}
                local source = scoped and tracker.scope or tracker.state
                for _, interval in ipairs(source.intervals) do intervals[#intervals + 1] = { interval[1], interval[2] } end
                if scoped and source.starts then intervals[#intervals + 1] = { source.starts, ends } end
                buff.covered = meter.IntervalTotal(intervals, first, ends)
                if exclude(tracker) then eligible = math.max(1, eligible - meter.ExcludedTotal(intervals, tracker.cooldownState, first, ends)) end
                buff.duration = eligible
                buff.members[1] = { name = GetUnitName and GetUnitName("player") or L("Spieler"), account = GetUnitDisplayName and GetUnitDisplayName("player"),
                    covered = buff.covered, duration = buff.duration, role = personalRole }
            end
            table.sort(buff.members, function(a, b) return (a.account or a.name) < (b.account or b.name) end)
            report.buffs[#report.buffs + 1] = buff
        end
    end
    attachEncounter(report, trackers, receiptWindow)
    Reports.Save(report)
end

local function label(parent, name, x, y, width, height, font, color)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    control:SetFont(font or "ZoFontGamepad27")
    control:SetColor(unpack(color or { 0.91, 0.93, 0.94, 1 }))
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if TEXT_WRAP_MODE_ELLIPSIS then control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    return control
end

local function band(parent, x, y, width, height, color)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    control:SetCenterColor(unpack(color))
    control:SetEdgeColor(0, 0, 0, 0)
    return control
end

function Reports.Refresh()
    if not window or deletePending then return end
    local report = currentReport()
    selected = math.max(1, math.min(selected, #currentEffects(report)))
    if nativeList then
        local history = saved and saved.uptimeHistory or {}
        local zones, seen = {}, {}
        for index, record in ipairs(history) do
            local key = zoneKey(record)
            if not seen[key] then
                seen[key] = { key = key, record = record, count = 0, locked = 0, first = index }
                zones[#zones + 1] = seen[key]
            end
            seen[key].count = seen[key].count + 1
            if record.locked then seen[key].locked = seen[key].locked + 1 end
        end
        if not selectedZone or not seen[selectedZone] then selectedZone = report and zoneKey(report) end
        if report and selectedZone and zoneKey(report) ~= selectedZone then
            selectedFight, selected, page = seen[selectedZone].first, 1, 1
            report = currentReport()
        end
        rebuildingList = true
        local rebuilt = false
        if historyFirst ~= history[1] or historyCount ~= #history or lastListMode ~= listMode
            or (listMode == "fights" and listZone ~= selectedZone)
            or (listMode == "buffs" and (listCategory ~= category or listReport ~= report)) then
            nativeList:Clear()
            nativeList:SetNoItemText(listMode == "buffs" and L("Keine aufgezeichneten Effekte") or L("Noch kein abgeschlossener Kampf"))
            selectionIndices = {}
            if listMode == "zones" then
                for _, zone in ipairs(zones) do
                    local fullyLocked = zone.locked == zone.count
                    local entry = ZO_GamepadEntryData:New(zoneTitle(zone.record) .. (fullyLocked and LOCK_MARKER or ""),
                        zone.record.placeIcon or DEFAULT_PLACE_ICON)
                    entry.zoneKey = zone.key
                    entry.locked = fullyLocked
                    if entry.AddSubLabel then
                        local subtitle = string.format("%s | %d %s", reportDate(zone.record), zone.count,
                            zone.count == 1 and L("Kampf") or L("Kaempfe"))
                        if zone.locked > 0 and not fullyLocked then
                            subtitle = subtitle .. " | " .. string.format(L("%d gesperrt"), zone.locked)
                        end
                        entry:AddSubLabel(subtitle)
                    end
                    nativeList:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
                    selectionIndices[#selectionIndices + 1] = zone.key
                end
            elseif listMode == "buffs" then
                for index, buff in ipairs(currentEffects(report)) do
                    local entry = ZO_GamepadEntryData:New(buff.name, GetAbilityIcon(buff.id))
                    entry.buffIndex = index
                    if entry.AddSubLabel then entry:AddSubLabel(category == "debuffs" and L("Auf dem Gegner") or buff.groupRole == "damage" and L("Nur DDs")
                        or buff.unit == "group" and L("Auf der Gruppe") or L("Auf mir")) end
                    nativeList:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
                    selectionIndices[#selectionIndices + 1] = index
                end
            else
                for index, record in ipairs(history) do
                    if zoneKey(record) == selectedZone then
                        local entry = ZO_GamepadEntryData:New(enemyTitle(record) .. (record.locked and LOCK_MARKER or ""),
                            record.placeIcon or DEFAULT_PLACE_ICON)
                        entry.fightIndex = index
                        local duration = math.max(0, (record.ended or 0) - (record.started or 0))
                        entry.locked = record.locked == true
                        if entry.AddSubLabel then entry:AddSubLabel((record.locked and (L("Gesperrt") .. " | ") or "") ..
                            string.format("%s  %s  |  %d:%s", reportDate(record), record.clock or "",
                                math.floor(duration / 60), decimal(duration % 60, "%04.1f"))) end
                        nativeList:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
                        selectionIndices[#selectionIndices + 1] = index
                    end
                end
            end
            nativeList:Commit()
            historyFirst, historyCount = history[1], #history
            listReport, lastListMode, listZone = report, listMode, selectedZone
            listCategory = category
            rebuilt = true
        end
        local key = listMode == "zones" and selectedZone or listMode == "fights" and selectedFight or selected
        local index = 1
        for position, value in ipairs(selectionIndices) do if value == key then index = position; break end end
        if #selectionIndices > 0 and (rebuilt or not nativeList.GetSelectedIndex or nativeList:GetSelectedIndex() ~= index) then
            if rebuilt and nativeList.SetSelectedIndexWithoutAnimation then
                nativeList:SetSelectedIndexWithoutAnimation(index, true)
            else nativeList:SetSelectedIndex(index) end
        end
        rebuildingList = false
        nativeScreen.headerData.titleText = listMode == "zones" and L("Kampfstatistiken")
            or listMode == "fights" and (report and zoneTitle(report) or L("Kaempfe")) or (category == "debuffs" and L("Debuff-Uptime") or L("Buff-Uptime"))
        if nativeScreen.header and ZO_GamepadGenericHeader_Refresh then
            ZO_GamepadGenericHeader_Refresh(nativeScreen.header, nativeScreen.headerData)
        end
    end
    local buffs = currentEffects(report)
    local debuffs = category == "debuffs"
    controls.heading:SetText(debuffs and L("Debuff-Uptime") or L("Buff-Uptime"))
    controls.subject:SetText(debuffs and L("Gegner") or L("Spieler"))
    controls.coverage:SetText(debuffs and L("Debuffzeit") or L("Buffzeit"))
    controls.receiptHeading:SetHidden(debuffs)
    selected = math.max(1, math.min(selected, #buffs))
    local buff = buffs[selected]
    local members = buff and buff.members or {}
    local pages = math.max(1, math.ceil(#members / ROWS))
    page = math.max(1, math.min(page, pages))
    controls.buff:SetText(buff and (buff.name .. "  |  " .. (debuffs and L("Auf dem Gegner") or buff.groupRole == "damage" and L("Nur DDs")
        or buff.unit == "group" and L("Auf der Gruppe") or L("Auf mir"))) or (report and L("Keine aufgezeichneten Effekte") or L("Noch kein abgeschlossener Kampf")))
    controls.selection:SetText(string.format("%d / %d", buff and selected or 0, #buffs))
    local duration = report and math.max(0, (report.ended or 0) - (report.started or 0)) or 0
    controls.subtitle:SetText(report and string.format("%s  |  %d:%s  |  %d %s", displayTitle(report), math.floor(duration / 60), decimal(duration % 60, "%04.1f"), #members, debuffs and L("Gegner") or L("Spieler")) or "")
    if buff and buff.groupRole == "damage" then
        local count = 0
        for _, member in ipairs(members) do if member.counted ~= false then count = count + 1 end end
        controls.subtitle:SetText(string.format(L("%s  |  %d:%s  |  %d Spieler, %d DDs gewertet"),
            displayTitle(report), math.floor(duration / 60), decimal(duration % 60, "%04.1f"), #members, count))
    end
    controls.basis:SetText(buff and (debuffs and L("Kampfzeit") or report.fallback and L("Ersatzmessung: HUD-Bezugszeit")
        or buff.unit == "group" and L("Gruppen-Lebendzeit") or buff.basis == "alive" and L("Lebendzeit") or L("Aktive Kampfzeit")) or "")
    for index = 1, ROWS do
        local member = members[(page - 1) * ROWS + index]
        local row = controls.rows[index]
        local counted = member and member.counted ~= false
        row.background:SetHidden(member == nil)
        row.name:SetText(member and (member.account or member.name) or "")
        row.death:SetText(not debuffs and member and (member.deaths ~= nil and string.format(L("%d Tode / %s s tot"), member.deaths,
            decimal(member.deadTime or 0, "%.1f")) or L("Keine Todesdaten")) or "")
        row.name:SetColor(counted and 0.91 or 0.55, counted and 0.93 or 0.59, counted and 0.94 or 0.6, 1)
        row.role:SetText(not debuffs and member and roleName(member.role) or "")
        local icon = not debuffs and member and roleIcon(member.role)
        row.roleIcon:SetHidden(not icon)
        if icon then row.roleIcon:SetTexture(icon) end
        row.roleIcon:SetColor(counted and 1 or 0.55, counted and 1 or 0.55, counted and 1 or 0.55, 1)
        row.covered:SetText(member and (counted and (decimal(member.covered) .. " s") or "-") or "")
        row.duration:SetText(member and (counted and (decimal(member.duration) .. " s") or "-") or "")
        row.percent:SetText(member and (counted and (decimal(member.duration > 0 and member.covered / member.duration * 100 or 0, "%.1f") .. " %") or "-") or "")
        row.percent:SetColor(member and member.covered > 0 and 0.55 or 0.9, member and member.covered > 0 and 0.95 or 0.65, 0.65, 1)
        row.buffIcon:SetHidden(not member or debuffs)
        if member and buff and not debuffs then row.buffIcon:SetTexture(GetAbilityIcon(buff.id)) end
        row.received:SetText(not debuffs and member and string.format("%s / %s",
            member.received ~= nil and tostring(member.received) or "-",
            member.renewed ~= nil and tostring(member.renewed) or "-") or "")
    end
    controls.total:SetText(buff and string.format("%s  %s %%", debuffs and L("Debuff-Uptime") or buff.groupRole == "damage" and L("DD-Uptime")
        or buff.unit == "group" and L("Gruppen-Uptime") or L("Persoenliche Uptime"), decimal(buff.percent, "%.1f")) or "")
    controls.times:SetText(buff and string.format(L("%s %s s  /  Bezugszeit %s s"), debuffs and L("Debuffzeit") or L("Buffzeit"), decimal(buff.covered), decimal(buff.duration)) or "")
    local pageText = debuffs and L("Seite 2 / 2") or L("Seite 1 / 2")
    if pages > 1 then pageText = pageText .. string.format("\n%s %d / %d", debuffs and L("Gegner") or L("Spieler"), page, pages) end
    controls.page:SetText(pageText)
    controls.warning:SetText(buff and buff.truncated and L("Einzelwerte unvollstaendig") or "")
    if opened and keybinds and KEYBIND_STRIP and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds)
    end
end

function Reports.ChangeBuff(delta)
    if deletePending then return end
    local report = currentReport()
    local count = #currentEffects(report)
    if count > 0 then
        selected = ((selected - 1 + delta) % count) + 1
        page = 1
        rememberEffectSelection()
        Reports.Refresh()
    end
end

function Reports.ChangeCategory()
    if deletePending or listMode ~= "buffs" then return end
    rememberEffectSelection()
    category = category == "buffs" and "debuffs" or "buffs"
    restoreEffectSelection()
    Reports.Refresh()
end

function Reports.ChangePage()
    if deletePending then return end
    local report = currentReport()
    local buff = currentEffects(report)[selected]
    if buff then
        page = page % math.max(1, math.ceil(#buff.members / ROWS)) + 1
        rememberEffectSelection()
        Reports.Refresh()
    end
end

function Reports.SelectFight(index)
    if deletePending then return end
    if not saved or not saved.uptimeHistory[index] then return end
    selectionChosen = true
    selectedZone, listMode = zoneKey(saved.uptimeHistory[index]), "fights"
    if selectedFight ~= index then selectedFight, selected, page = index, 1, 1 end
    Reports.Refresh()
end

function Reports.SelectZone(key)
    if deletePending then return end
    if selectedZone ~= key then
        for index, report in ipairs(saved.uptimeHistory) do
            if zoneKey(report) == key then
                selectedZone, selectedFight, selected, page = key, index, 1, 1
                selectionChosen = true
                break
            end
        end
    end
    Reports.Refresh()
end

function Reports.ShowZone()
    if deletePending or not currentReport() then return end
    listMode = "fights"
    Reports.Refresh()
end

function Reports.ConfirmSelection()
    if listMode == "zones" then Reports.ShowZone()
    elseif listMode == "fights" then Reports.ShowBuffs() end
end

function Reports.ToggleLock()
    if deletePending or (listMode ~= "fights" and listMode ~= "zones") then return end
    local report = currentReport()
    if not report then return end
    local locked = not selectionLocked() or nil
    if listMode == "zones" then
        for _, record in ipairs(saved.uptimeHistory) do
            if zoneKey(record) == selectedZone then record.locked = locked end
        end
    else report.locked = locked end
    selectionChosen = true
    historyCount = nil
    Reports.Refresh()
end

local function canDeleteSelection()
    local report = currentReport()
    if not report then return false end
    if listMode == "fights" then return not report.locked end
    if listMode == "zones" then
        for _, record in ipairs(saved.uptimeHistory) do
            if zoneKey(record) == selectedZone and not record.locked then return true end
        end
    end
    return false
end

function Reports.DeleteFight(report)
    if not saved or not report or report.locked then return end
    for index, record in ipairs(saved.uptimeHistory) do
        if record == report then
            table.remove(saved.uptimeHistory, index)
            if index < selectedFight then selectedFight = selectedFight - 1 end
            selectedFight = math.max(1, math.min(selectedFight, #saved.uptimeHistory))
            selected, page, listMode = 1, 1, "fights"
            local areaExists = false
            for _, other in ipairs(saved.uptimeHistory) do if zoneKey(other) == selectedZone then areaExists = true; break end end
            if not areaExists then selectedZone, listMode = nil, "zones" end
            saved.lastUptimeReport = saved.uptimeHistory[1]
            historyCount = nil
            Reports.Refresh()
            return
        end
    end
end

function Reports.DeleteZone(records)
    if not saved or not records then return end
    local targets = {}
    for _, report in ipairs(records) do targets[report] = true end
    local previous = currentReport()
    for index = #saved.uptimeHistory, 1, -1 do
        if targets[saved.uptimeHistory[index]] and not saved.uptimeHistory[index].locked then table.remove(saved.uptimeHistory, index) end
    end
    selectedFight = math.max(1, math.min(selectedFight, #saved.uptimeHistory))
    for index, report in ipairs(saved.uptimeHistory) do
        if report == previous then selectedFight = index; break end
    end
    saved.lastUptimeReport = saved.uptimeHistory[1]
    selected, page, listMode = 1, 1, "zones"
    historyCount = nil
    Reports.Refresh()
end

local function finishDeleteDialog()
    if not deletePending then return end
    deletePending = nil
    if not opened then return end
    Reports.Refresh()
    window:SetHidden(false)
    detailWindow:SetHidden(false)
    if KEYBIND_STRIP then KEYBIND_STRIP:AddKeybindButtonGroup(keybinds) end
    if nativeScreen then nativeScreen:SetCurrentList(nativeList) end
    if nativeList then nativeList:Activate() end
end

function Reports.RequestDelete()
    if (listMode ~= "fights" and listMode ~= "zones") or deletePending then return end
    local report = currentReport()
    if not report then return end
    if listMode == "fights" and report.locked then return end
    if not ZO_Dialogs_RegisterCustomDialog or not ZO_Dialogs_ShowGamepadDialog then return end
    local data = { report = report }
    if listMode == "zones" then
        data.zone, data.records, data.protectedCount = zoneTitle(report) .. " (" .. reportDate(report) .. ")", {}, 0
        for _, record in ipairs(saved.uptimeHistory) do
            if zoneKey(record) == selectedZone then
                if record.locked then data.protectedCount = data.protectedCount + 1
                else data.records[#data.records + 1] = record end
            end
        end
        if #data.records == 0 then return end
    end
    if not deleteDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog(deleteDialogName, {
            mustChoose = true,
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
            title = { text = function(dialog) return dialog.data.records and L("Gebiet loeschen?") or L("Kampf loeschen?") end },
            finishedCallback = finishDeleteDialog,
            mainText = { text = function(dialog)
                if dialog.data.records then
                    local text = string.format(L("%s: %d gespeicherte Kaempfe wirklich loeschen?"), dialog.data.zone, #dialog.data.records)
                    if (dialog.data.protectedCount or 0) > 0 then
                        text = text .. "\n" .. string.format(L("%d gesperrte Kaempfe bleiben erhalten."), dialog.data.protectedCount)
                    end
                    return text
                end
                return string.format(L("%s (%s) wirklich loeschen?"), displayTitle(dialog.data.report), dialog.data.report.clock or "")
            end },
            buttons = {
                { text = L("Loeschen"), callback = function(dialog)
                    if dialog.data.records then Reports.DeleteZone(dialog.data.records)
                    else Reports.DeleteFight(dialog.data.report) end
                end },
                { text = SI_DIALOG_CANCEL },
            },
        })
        deleteDialogRegistered = true
    end
    deletePending = report
    if nativeScreen and nativeScreen.Deactivate then nativeScreen:Deactivate() end
    if nativeList then nativeList:Deactivate() end
    window:SetHidden(true)
    detailWindow:SetHidden(true)
    if KEYBIND_STRIP then KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds) end
    local ok, reason = pcall(ZO_Dialogs_ShowGamepadDialog, deleteDialogName, data)
    if not ok then finishDeleteDialog(); d(L("LiveBuffUptime: Loeschbestaetigung konnte nicht geoeffnet werden: ") .. tostring(reason)) end
end

function Reports.ChangeFight(delta)
    if deletePending then return end
    local count = saved and #saved.uptimeHistory or 0
    if count > 0 then Reports.SelectFight((selectedFight - 1 + delta) % count + 1) end
end

function Reports.ShowBuffs()
    if deletePending then return end
    if not currentReport() then return end
    listMode = "buffs"
    restoreEffectSelection()
    Reports.Refresh()
end

function Reports.Back()
    if deletePending then return end
    if listMode == "buffs" then rememberEffectSelection(); listMode = "fights"; Reports.Refresh()
    elseif listMode == "fights" then listMode = "zones"; Reports.Refresh()
    else Reports.Close() end
end

local function release()
    if not opened then return end
    opened = false
    deletePending = nil
    if nativeList then nativeList:Deactivate() end
    if KEYBIND_STRIP and keybinds then KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds) end
    if previousUI == false and SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(false) end
    if previousCamera == false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
    previousUI, previousCamera = nil, nil
    if ClearTooltip then ClearTooltip(InformationTooltip) end
    if consoleLayout and detailWindow then detailWindow:SetHidden(true) end
    window:SetHidden(true)
end

function Reports.Close()
    if not opened then return end
    release()
    if scene and SCENE_MANAGER and SCENE_MANAGER.Show then SCENE_MANAGER:Show(previousScene or "hud") end
end

local function createWindow()
    local wm = WINDOW_MANAGER
    consoleLayout = ZO_Gamepad_ParametricList_Screen and ZO_GamepadEntryData and wm.CreateControlFromVirtual
        and ZO_SharedGamepadEntry_OnSetup and ZO_GamepadMenuEntryTemplateParametricListFunction
    if not consoleLayout then
        d(L("LiveBuffUptime: Konsolen-Menue nicht verfuegbar; bitte Controller-Modus aktivieren und /reloadui ausfuehren."))
        return false
    end
    if consoleLayout then
        window = wm:CreateControlFromVirtual("LiveBuffUptimeReportWindow", GuiRoot, "LiveBuffUptimeReportScreenTemplate")
        scene = ZO_Scene:New(sceneName, SCENE_MANAGER)
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
        local rightBackground = GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT
            or (ZO_SharedGamepadNavQuadrant_2_3_Background and ZO_FadeSceneFragment:New(ZO_SharedGamepadNavQuadrant_2_3_Background))
        for _, fragment in pairs({ GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT, rightBackground,
            not rightBackground and GAMEPAD_NAV_QUADRANT_2_BACKGROUND_FRAGMENT or nil,
            not rightBackground and GAMEPAD_NAV_QUADRANT_3_BACKGROUND_FRAGMENT or nil,
            MINIMIZE_CHAT_FRAGMENT, GAMEPAD_MENU_SOUND_FRAGMENT }) do
            if fragment then scene:AddFragment(fragment) end
        end
        local Screen = ZO_Gamepad_ParametricList_Screen:Subclass()
        function Screen:Initialize(control)
            ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, scene)
        end
        function Screen:InitializeKeybindStripDescriptors() self.keybindStripDescriptor = {} end
        function Screen:PerformUpdate()
            if controls.rows then Reports.Refresh() end
            self.dirty = false
        end
        nativeScreen = Screen:New(window)
        nativeList = nativeScreen:GetMainList()
        -- Keep both native panels in the scene even on clients with deferred list setup.
        scene:AddFragment(nativeScreen:GetHeaderFragment())
        scene:AddFragment(nativeScreen:GetListFragment(nativeList))
        nativeList:AddDataTemplate("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        nativeList:SetNoItemText(L("Noch kein abgeschlossener Kampf"))
        nativeList:SetOnSelectedDataChangedCallback(function(_, entry)
            if rebuildingList or not entry then return end
            if entry.zoneKey then Reports.SelectZone(entry.zoneKey)
            elseif entry.fightIndex then Reports.SelectFight(entry.fightIndex)
            elseif entry.buffIndex then
                if selected ~= entry.buffIndex then selected, page = entry.buffIndex, 1 end
                rememberEffectSelection()
                Reports.Refresh()
            end
        end)
        nativeScreen.headerData = { titleText = L("Kampfstatistiken") }
        if nativeScreen.header and ZO_GamepadGenericHeader_Refresh then
            ZO_GamepadGenericHeader_Refresh(nativeScreen.header, nativeScreen.headerData)
        end
    end
    window:SetClampedToScreen(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)
    window:SetMouseEnabled(false)
    window:SetHidden(true)
    local root = window
    -- The native root follows quadrant 1; the report occupies separate screen space.
    local window = wm:CreateTopLevelWindow("LiveBuffUptimeReportDetails")
    detailWindow = window
    window:SetAnchor(TOPLEFT, ZO_SharedGamepadNavQuadrant_2_Background or GuiRoot, TOPLEFT,
        ZO_SharedGamepadNavQuadrant_2_Background and 24 or GuiRoot:GetWidth() * 0.26, 12)
    window:SetDimensions(960, 1130)
    if consoleLayout then
        window:SetDrawLayer(DL_OVERLAY)
        window:SetDrawTier(DT_HIGH)
        window:SetHidden(true)
    end
    local heading = label(window, nil, 28, 0, 760, 46, "ZoFontGamepad42")
    controls.heading = heading
    heading:SetText(L("Buff-Uptime"))
    controls.subtitle = label(window, "LiveBuffUptimeReportSubtitle", 28, 48, 880, 32, "ZoFontGamepad27")
    controls.buff = label(window, "LiveBuffUptimeReportBuff", 28, 82, 740, 44, "ZoFontGamepad42")
    controls.selection = label(window, nil, 820, 82, 100, 44, "ZoFontGamepad34")
    controls.basis = label(window, nil, 28, 126, 720, 30, "ZoFontGamepad27", { 0.64, 0.72, 0.7, 1 })
    local columns = { { L("Spieler"), 36, 308 }, { L("Buffzeit"), 362, 150 }, { L("Bezugszeit"), 528, 150 }, { "Uptime", 694, 150 } }
    for index, column in ipairs(columns) do
        local control = label(window, nil, column[2], 158, column[3], 38, "ZoFontGamepad34")
        control:SetText(column[1])
        if index == 1 then controls.subject = control elseif index == 2 then controls.coverage = control end
    end
    controls.receiptHeading = label(window, "LiveBuffUptimeReportReceiptHeading", 854, 150, 80, 44, "ZoFontGamepad18")
    controls.receiptHeading:SetText(L("Erhalten /\nErneuert"))
    controls.receiptHeading:SetMaxLineCount(2)
    controls.receiptHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    controls.rows = {}
    for index = 1, ROWS do
        local y = 204 + (index - 1) * 70
        local row = { background = band(window, 28, y, 904, 70, { 0, 0, 0, index % 2 == 0 and 0.16 or 0.04 }) }
        row.roleIcon = wm:CreateControl("LiveBuffUptimeReportRoleIcon" .. index, window, CT_TEXTURE)
        row.roleIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 36, y + 6)
        row.roleIcon:SetDimensions(54, 54)
        row.name = label(window, "LiveBuffUptimeReportName" .. index, 100, y, 244, 42, "ZoFontGamepad42")
        row.death = label(window, "LiveBuffUptimeReportDeaths" .. index, 100, y + 42, 244, 28, "ZoFontGamepad27", { 0.64, 0.72, 0.7, 1 })
        row.role = label(window, "LiveBuffUptimeReportRole" .. index, 356, y, 80, 70, "ZoFontGamepad27", { 0.64, 0.72, 0.7, 1 })
        row.role:SetHidden(true)
        row.covered = label(window, "LiveBuffUptimeReportCovered" .. index, 362, y, 150, 70, "ZoFontGamepad54")
        row.duration = label(window, nil, 528, y, 150, 70, "ZoFontGamepad54")
        row.percent = label(window, "LiveBuffUptimeReportPercent" .. index, 694, y, 150, 70, "ZoFontGamepad54")
        row.buffIcon = wm:CreateControl("LiveBuffUptimeReportBuffIcon" .. index, window, CT_TEXTURE)
        row.buffIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 875, y + 10)
        row.buffIcon:SetDimensions(38, 38)
        row.received = label(window, "LiveBuffUptimeReportReceived" .. index, 854, y + 48, 80, 22, "ZoFontGamepad22")
        row.received:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        for _, value in ipairs({row.covered, row.duration, row.percent}) do
            value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            value:SetMaxLineCount(1)
        end
        controls.rows[index] = row
    end
    controls.total = label(window, "LiveBuffUptimeReportTotal", 36, 1054, 580, 42, "ZoFontGamepad42", { 0.55, 0.95, 0.7, 1 })
    controls.times = label(window, nil, 36, 1096, 650, 30, "ZoFontGamepad27")
    controls.page = label(window, "LiveBuffUptimeReportPage", 708, 1084, 224, 44, "ZoFontGamepad22")
    controls.page:SetMaxLineCount(2)
    controls.warning = label(window, nil, 650, 1054, 282, 28, "ZoFontGamepad22", { 1, 0.7, 0.4, 1 })
    keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { name = L("Zurueck"), keybind = "UI_SHORTCUT_NEGATIVE", callback = Reports.Back },
        { name = function() return category == "buffs" and L("Debuff-Uptime") or L("Buff-Uptime") end,
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = Reports.ChangeCategory,
            visible = function() return listMode == "buffs" end },
        { name = function() return category == "buffs" and L("Debuff-Uptime") or L("Buff-Uptime") end,
            keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = Reports.ChangeCategory,
            visible = function() return listMode == "buffs" end },
        { name = function() return category == "debuffs" and L("Weitere Gegner") or L("Weitere Spieler") end,
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER", callback = Reports.ChangePage,
            visible = function() local effect = currentEffects(currentReport())[selected]; return listMode == "buffs" and effect and #effect.members > ROWS end },
        { name = function() return listMode == "zones" and L("Kaempfe anzeigen") or L("Buffs anzeigen") end,
            keybind = "UI_SHORTCUT_PRIMARY", callback = Reports.ConfirmSelection,
            visible = function() return listMode ~= "buffs" and currentReport() ~= nil end },
        { name = L("Loeschen"), keybind = "UI_SHORTCUT_RIGHT_STICK", callback = Reports.RequestDelete,
            enabled = canDeleteSelection,
            visible = function() return (listMode == "fights" or listMode == "zones") and currentReport() ~= nil end },
        { name = function() return selectionLocked() and L("Entsperren") or L("Sperren") end,
            keybind = "UI_SHORTCUT_SECONDARY", callback = Reports.ToggleLock,
            visible = function() return (listMode == "fights" or listMode == "zones") and currentReport() ~= nil end },
    }
    if ZO_Scene and ZO_FadeSceneFragment and SCENE_MANAGER then
        scene = scene or ZO_Scene:New(sceneName, SCENE_MANAGER)
        scene:AddFragment(ZO_FadeSceneFragment:New(root))
        if consoleLayout then scene:AddFragment(ZO_FadeSceneFragment:New(detailWindow)) end
        scene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_HIDING or state == SCENE_HIDDEN or state == "hiding" or state == "hidden" then release() end
        end)
    end
end

function Reports.Open()
    if not window then createWindow() end
    if not window then return end
    if opened then Reports.Refresh(); return end
    local current = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
    previousScene = current and current:GetName()
    previousUI = SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode()
    previousCamera = IsGameCameraUIModeActive and IsGameCameraUIModeActive()
    opened = true
    listMode = "zones"
    if consoleLayout then
        window:SetScale(1)
        local quadrant = ZO_SharedGamepadNavQuadrant_2_Background
        local width = quadrant and quadrant:GetWidth() * 2 or GuiRoot:GetWidth() * 0.74
        local height = quadrant and quadrant:GetHeight() or GuiRoot:GetHeight()
        local background = ZO_SharedGamepadNavQuadrant_2_3_Background or ZO_SharedGamepadNavQuadrant_3_Background
        local left = quadrant and quadrant.GetLeft and quadrant:GetLeft()
        local right = background and background.GetRight and background:GetRight()
        -- Native backgrounds can be narrower than two nominal quadrant widths.
        if type(left) == "number" and type(right) == "number" and right > left then width = math.min(width, right - left) end
        detailWindow:SetScale(math.min(1, (width - 72) / 960, (height - 24) / 1130))
    end
    if scene and SCENE_MANAGER.Push then SCENE_MANAGER:Push(sceneName) end
    if SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(true) end
    if SetGameCameraUIMode then SetGameCameraUIMode(true) end
    window:SetHidden(false)
    if consoleLayout then detailWindow:SetHidden(false) end
    if KEYBIND_STRIP then KEYBIND_STRIP:AddKeybindButtonGroup(keybinds) end
    Reports.Refresh()
    if nativeScreen then nativeScreen:SetCurrentList(nativeList) end
    if nativeList then nativeList:Activate() end
end
