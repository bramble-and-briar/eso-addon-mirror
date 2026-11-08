local L = LiveBuffUptimeLocalization and LiveBuffUptimeLocalization.Text or function(text) return text end
local Reports = {}
LiveBuffUptimeReports = Reports
local saved, window, scene, previousScene, previousUI, previousCamera
local controls, selected, page, selectedFight = {}, 1, 1, 1
local detailFragments, detailsAttached = {}, false
local capturedFight
local consoleLayout, nativeList, nativeScreen, rebuildingList, detailWindow
local historyFirst, historyCount
local listMode, listReport, lastListMode = "zones", nil, nil
local category, listCategory = "buffs", nil
local skillTarget = "all"
local enemyTypeIndex, enemyTypePage, listEffect = 1, 1, nil
local effectSelections = setmetatable({}, { __mode = "k" })
local enemyEffects, activeEnemyEffects = {}, {}
local selectedZone, listZone, selectionIndices = nil, nil, {}
local encounterTargets, encounterLocation, encounterBoss = {}, nil, nil
local encounterSkills, encounterSkillCount, encounterDamage, encounterSkillDuration = {}, 0, 0, nil
local nativeDamage = { buffer = {}, count = 0, index = 0 }
local skillEncounterClock, encounterGroupDamageDuration
local categories = { "buffs", "debuffs", "skills" }
local function categoryName(value)
    return value == "skills" and L("Skills") or value == "debuffs" and L("Debuffs") or L("Buffs")
end
local function categoryIndex()
    for index, value in ipairs(categories) do if category == value then return index end end
    return 1
end
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
local skillScrollUpdate
local function updateDetailVisibility()
    local visible = opened and not deletePending and (listMode == "buffs" or listMode == "enemyTypes")
    if scene and detailsAttached ~= visible then
        for _, fragment in ipairs(detailFragments) do
            if visible then scene:AddFragment(fragment)
            elseif scene.RemoveFragment then scene:RemoveFragment(fragment) end
        end
        detailsAttached = visible
    end
    if detailWindow then
        detailWindow:SetHidden(not visible)
        local skillsVisible = visible and category == "skills"
        detailWindow:SetMouseEnabled(skillsVisible)
        detailWindow:SetHandler("OnUpdate", skillsVisible and skillScrollUpdate or nil)
        if controls.skillScrollTrack then
            controls.skillScrollTrack:SetHidden(not skillsVisible)
            controls.skillScrollThumb:SetHidden(not skillsVisible)
        end
    end
end
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
    encounterSkills, encounterSkillCount, encounterDamage, encounterSkillDuration = {}, 0, 0, nil
    encounterGroupDamageDuration=nil
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

function Reports.RecordDamage(sourceType, targetType, targetId, targetName, damage, abilityId, abilityName, metadataOnly, time)
    if sourceType == nil or COMBAT_UNIT_TYPE_PLAYER == nil then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and (COMBAT_UNIT_TYPE_PLAYER_PET == nil or sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then return end
    if targetType == COMBAT_UNIT_TYPE_PLAYER or (COMBAT_UNIT_TYPE_GROUP ~= nil and targetType == COMBAT_UNIT_TYPE_GROUP)
        or (COMBAT_UNIT_TYPE_PLAYER_PET ~= nil and targetType == COMBAT_UNIT_TYPE_PLAYER_PET)
        or (COMBAT_UNIT_TYPE_GROUP_PET ~= nil and targetType == COMBAT_UNIT_TYPE_GROUP_PET) then return end
    if type(damage) ~= "number" or damage <= 0 or damage ~= damage or damage == math.huge then return end
    if not metadataOnly then
    local skillId = type(abilityId) == "number" and abilityId > 0 and abilityId or 0
    local skill = encounterSkills[skillId]
    -- Bounded per-skill aggregates; no individual-hit event history is saved.
    if not skill and encounterSkillCount < 512 then
        skill = { id = skillId, name = abilityName and abilityName ~= "" and zo_strformat("<<1>>", abilityName)
            or (skillId > 0 and GetAbilityName and zo_strformat("<<1>>", GetAbilityName(skillId))) or L("Unbekannter Skill"), damage = 0, hits = 0 }
        encounterSkills[skillId], encounterSkillCount = skill, encounterSkillCount + 1
    end
    encounterDamage = encounterDamage + damage
    if skill then skill.damage, skill.hits = skill.damage + damage, skill.hits + 1 end
    end
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
    if not metadataOnly then
        entry.damage = entry.damage + damage
        local id = type(abilityId) == "number" and abilityId > 0 and abilityId or 0
        entry.skills = entry.skills or {}
        local row = entry.skills[id] or { damage = 0, hits = 0, name = abilityName }
        entry.skills[id] = row
        row.damage, row.hits = row.damage + damage, row.hits + 1
        time = time or (GetFrameTimeSeconds and GetFrameTimeSeconds())
        if time then entry.starts, entry.ends = math.min(entry.starts or time,time), math.max(entry.ends or time,time) end
    end
    refreshBossCandidates()
    if entry.name and bossCandidates[entry.name] then encounterBossNames[entry.name],entry.isBoss = true,true end
end

local function addNativeDamage(snapshot, event)
    local id = event.abilityId or 0
    local skill = snapshot.skills[id]
    if not skill and snapshot.skillCount < 512 then
        skill = { damage = 0, hits = 0, name = event.abilityName }
        snapshot.skills[id] = skill
        snapshot.skillCount = snapshot.skillCount + 1
    end
    if skill then skill.damage, skill.hits = skill.damage + event.damage, skill.hits + 1 end
    snapshot.total = snapshot.total + event.damage
    snapshot.firstHit = math.min(snapshot.firstHit or event.time, event.time)
    snapshot.ends = math.max(snapshot.ends, event.time)
    local key = event.targetId or (event.targetName and ("name:" .. event.targetName))
    if key then
        local target = snapshot.targets[key]
        if not target and snapshot.targetCount < 48 then
            target = { damage = 0, name = event.targetName, skills = {} }
            snapshot.targets[key] = target
            snapshot.targetCount = snapshot.targetCount + 1
        end
        if target then
            target.damage = target.damage + event.damage
            local row = target.skills[id] or { damage = 0, hits = 0, name = event.abilityName }
            target.skills[id] = row
            row.damage, row.hits = row.damage + event.damage, row.hits + 1
            target.starts, target.ends = math.min(target.starts or event.time,event.time), math.max(target.ends or event.time,event.time)
        end
    end
end

function Reports.RecordNativeDamage(time, sourceType, targetType, targetId, targetName, damage, abilityId, abilityName)
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and (COMBAT_UNIT_TYPE_PLAYER_PET == nil or sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then return end
    if targetType == COMBAT_UNIT_TYPE_PLAYER or (COMBAT_UNIT_TYPE_GROUP ~= nil and targetType == COMBAT_UNIT_TYPE_GROUP)
        or (COMBAT_UNIT_TYPE_PLAYER_PET ~= nil and targetType == COMBAT_UNIT_TYPE_PLAYER_PET)
        or (COMBAT_UNIT_TYPE_GROUP_PET ~= nil and targetType == COMBAT_UNIT_TYPE_GROUP_PET) then return end
    if type(damage) ~= "number" or damage <= 0 or damage ~= damage or damage == math.huge then return end
    local event = { time = time, damage = damage, abilityId = abilityId, abilityName = abilityName,
        targetId = type(targetId) == "number" and targetId > 0 and targetId or nil,
        targetName = targetName and targetName ~= "" and targetName or nil }
    if nativeDamage.active then
        addNativeDamage(nativeDamage.active, event)
    else
        -- BattleScrolls also replays the last second of pre-combat damage.
        -- This bounded ring survives library callbacks that start/reset later.
        nativeDamage.index = nativeDamage.index % 200 + 1
        nativeDamage.buffer[nativeDamage.index] = event
        nativeDamage.count = math.min(200, nativeDamage.count + 1)
    end
end

function Reports.BeginNativeDamage(time, continuation, preserveActive)
    if (continuation or preserveActive) and nativeDamage.active then return end
    local snapshot = { skills = {}, targets = {}, total = 0, skillCount = 0, targetCount = 0, starts = time, ends = time }
    local now = GetFrameTimeSeconds and GetFrameTimeSeconds() or time
    snapshot.clockStartMS = GetGameTimeMilliseconds and GetGameTimeMilliseconds() + (time - now) * 1000 or time * 1000
    snapshot.clockEndMS = snapshot.clockStartMS
    nativeDamage.active = snapshot
    for index = 1, nativeDamage.count do
        local event = nativeDamage.buffer[(nativeDamage.index - nativeDamage.count + index - 1) % 200 + 1]
        if event.time >= time - 1 and event.time <= time then addNativeDamage(snapshot, event) end
    end
    nativeDamage.buffer, nativeDamage.count, nativeDamage.index = {}, 0, 0
end

function Reports.StartNativeEncounterClock(timeMS)
    local snapshot = nativeDamage.active
    if snapshot and not snapshot.clockConfirmed then
        snapshot.clockStartMS, snapshot.clockEndMS, snapshot.clockConfirmed = timeMS, timeMS, true
    end
end

function Reports.RecordNativeEncounterDamage(timeMS)
    local snapshot = nativeDamage.active
    if snapshot then snapshot.clockEndMS = math.max(snapshot.clockEndMS, timeMS) end
end

function Reports.ObserveNativeUnitDamage(time, sourceId, targetId)
    local snapshot=nativeDamage.active
    if not snapshot then return end
    snapshot.unitTimes=snapshot.unitTimes or {}
    snapshot.unitTimeCount=snapshot.unitTimeCount or 0
    for _,id in ipairs({sourceId or 0,targetId or 0}) do
        if type(id)=="number" and id>0 then
            local unit=snapshot.unitTimes[id]
            if not unit and snapshot.unitTimeCount<256 then
                unit={starts=time,ends=time}; snapshot.unitTimes[id]=unit; snapshot.unitTimeCount=snapshot.unitTimeCount+1
            end
            if unit then unit.starts,unit.ends=math.min(unit.starts,time),math.max(unit.ends,time) end
        end
    end
end

function Reports.FinishNativeDamage()
    local snapshot = nativeDamage.active
    nativeDamage.active = nil
    if not snapshot or snapshot.total <= 0 then return end
    -- Match SimpleGroupDPS: combat initialization to the last valid damage
    -- event of any source. Only the numerator remains own player/pet damage.
    -- As in the group display, use current time until a later damage exists.
    local ends = snapshot.clockEndMS
    if ends <= snapshot.clockStartMS then
        ends = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or snapshot.ends * 1000
    end
    snapshot.duration = math.max(0, ends - snapshot.clockStartMS) / 1000
    for id, target in pairs(snapshot.targets) do
        local unit=snapshot.unitTimes and snapshot.unitTimes[id]
        local starts=unit and math.min(unit.starts,target.starts) or target.starts
        local ends=unit and math.max(unit.ends,target.ends) or target.ends
        target.duration = math.max(1,ends-starts)
    end
    return snapshot
end

function Reports.StartSkillEncounterClock(timeMS, confirmed)
    if not skillEncounterClock or (confirmed and not skillEncounterClock.confirmed) then
        skillEncounterClock={starts=timeMS,ends=timeMS,confirmed=confirmed}
    end
end

function Reports.RecordSkillEncounterDamage(timeMS)
    if skillEncounterClock then skillEncounterClock.ends=math.max(skillEncounterClock.ends,timeMS) end
end

function Reports.FinishSkillEncounterClock()
    local clock=skillEncounterClock; skillEncounterClock=nil
    if not clock then return end
    local ends=clock.ends
    if ends<=clock.starts then ends=GetGameTimeMilliseconds() end
    return math.max(0,ends-clock.starts)/1000
end

function Reports.SkillDamageSummary(duration, units, snapshot, groupDuration)
    encounterGroupDamageDuration=groupDuration
    if snapshot then
        -- Replace partial live counters with v2's complete per-ID aggregates.
        -- Never add the snapshot on top of the same already-counted hits.
        encounterSkills, encounterSkillCount, encounterDamage = {}, 0, snapshot.total
        for id, data in pairs(snapshot.skills) do
            if encounterSkillCount < 512 then
                encounterSkills[id] = { id = id, name = data.name and data.name ~= "" and zo_strformat("<<1>>", data.name)
                    or (GetAbilityName and zo_strformat("<<1>>", GetAbilityName(id))) or tostring(id),
                    damage = data.damage, hits = data.hits }
                encounterSkillCount = encounterSkillCount + 1
            end
        end
        for _, target in pairs(encounterTargets) do target.damage, target.skills, target.starts, target.ends, target.duration = 0, nil, nil, nil, nil end
        local count = 0
        for _ in pairs(encounterTargets) do count = count + 1 end
        for id, data in pairs(snapshot.targets) do
            local target = encounterTargets[id]
            if not target and count < 48 then
                target = { id = id }; encounterTargets[id] = target; count = count + 1
            end
            if target then
                target.damage = data.damage
                target.skills, target.duration = data.skills, data.duration
                if data.name then target.name = zo_strformat("<<C:1>>", data.name) end
            end
        end
    end
    if type(duration) == "number" and duration >= 0 and duration < math.huge then encounterSkillDuration = duration end
    for id, unit in pairs(units or {}) do
        local target = encounterTargets[id]
        if target and unit.name then target.name = zo_strformat("<<C:1>>", unit.name) end
        if target and (unit.isBoss or unit.bossId) then target.isBoss=true end
        -- CMX's target list divides by this exact v1 unit damage window.
        -- Skill rows themselves continue to use the whole-fight dpstime.
        if target and type(unit.dpsstart)=="number" and type(unit.dpsend)=="number" then
            target.duration=math.max(1,(unit.dpsend-unit.dpsstart)/1000)
        end
    end
end

local function attachEncounter(report, trackers, receiptWindow)
    report.skills, report.ownDamage, report.skillDamageRecorded = {}, encounterDamage, true
    report.skillDamageDuration = encounterSkillDuration
    report.groupDamageDuration = encounterGroupDamageDuration
    for _, skill in pairs(encounterSkills) do
        report.skills[#report.skills + 1] = { id = skill.id, name = skill.name, damage = skill.damage, hits = skill.hits }
    end
    table.sort(report.skills, function(a,b) if a.damage == b.damage then return a.id < b.id end; return a.damage > b.damage end)
    report.skills = Reports.SkillRows(report)
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
    local targetSkillCount,targetDamageTotal=0,0
    for key, target in pairs(encounterTargets) do
        local skills = {}
        for id, data in pairs(target.skills or {}) do
            if targetSkillCount<1024 then
            skills[#skills+1] = { id=id, name=data.name and data.name~="" and zo_strformat("<<1>>",data.name)
                or (GetAbilityName and zo_strformat("<<1>>",GetAbilityName(id))) or tostring(id), damage=data.damage,hits=data.hits }
            targetSkillCount=targetSkillCount+1
            else report.skillTargetsTruncated=true end
        end
        targetDamageTotal=targetDamageTotal+target.damage
        if #skills>0 then report.skillTargetsRecorded=true end
        report.enemies[#report.enemies + 1] = { id = target.id, key=key, name = target.name or (L("Gegner ") .. tostring(target.id or key)), damage = target.damage,
            skills=skills, duration=target.duration or (target.starts and target.ends and math.max(1,target.ends-target.starts)),
            isBoss=target.isBoss or encounterBossNames[target.name]==true }
    end
    if report.skillTargetsRecorded and targetDamageTotal<report.ownDamage then report.skillTargetsTruncated=true end
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
                    isBoss = encounterBossNames[target.name] == true,
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
    nativeDamage = { buffer = {}, count = 0, index = 0 }
    skillEncounterClock,encounterGroupDamageDuration=nil,nil
    saved.uptimeHistory = saved.uptimeHistory or {}
    if #saved.uptimeHistory == 0 and saved.lastUptimeReport then saved.uptimeHistory[1] = saved.lastUptimeReport end
    trimHistory(saved.uptimeHistory)
    saved.lastUptimeReport = saved.uptimeHistory[1]
    selectedFight = 1
    category, listCategory = "buffs", nil
    skillTarget="all"
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

function Reports.SkillRows(report, targetKey)
    local rows, byId = {}, {}
    local source = report and report.skills or {}
    if targetKey and targetKey~="all" then
        source = {}
        for _,target in ipairs(report and report.enemies or {}) do if (target.key or target.id)==targetKey then source=target.skills or {}; break end end
    end
    for _, skill in ipairs(source) do
        local name = zo_strformat("<<1>>", skill.name or tostring(skill.id or 0))
        local key = skill.id or 0
        local group = byId[key]
        if not group then
            group = { id = skill.id, name = name, damage = 0, hits = 0 }
            rows[#rows + 1], byId[key] = group, group
        end
        local amount = skill.damage or 0
        group.damage, group.hits = group.damage + amount, group.hits + (skill.hits or 0)
    end
    table.sort(rows, function(a,b) if a.damage == b.damage then return (a.id or 0) < (b.id or 0) end; return a.damage > b.damage end)
    return rows
end

function Reports.SkillTargets(report)
    local duration=report and (report.skillDamageDuration or math.max(0,(report.ended or 0)-(report.started or 0))) or 0
    local targets={{key="all",name=L("Alle Ziele"),damage=report and report.ownDamage or 0,duration=duration}}
    local names={}
    for _,target in ipairs(report and report.enemies or {}) do
        if target.damage>0 and #(target.skills or {})>0 then names[target.name]=(names[target.name] or 0)+1 end
    end
    for _,target in ipairs(report and report.enemies or {}) do
        if target.damage>0 and #(target.skills or {})>0 then
            local isBoss=target.isBoss==true
            for _,name in ipairs(report.bossNames or {}) do if name==target.name then isBoss=true end end
            local targetDuration=isBoss and (report.groupDamageDuration or duration) or (target.duration or duration)
            targets[#targets+1]={key=target.key or target.id,name=target.name..((names[target.name] or 0)>1 and (" ["..tostring(target.id or target.key).."]") or ""),
                damage=target.damage,duration=targetDuration,fightDuration=duration,isBoss=isBoss}
        end
    end
    return targets
end

local function selectedSkillTarget(report)
    local targets=Reports.SkillTargets(report)
    for _,target in ipairs(targets) do if target.key==skillTarget then return target end end
    skillTarget="all"; return targets[1]
end

local function currentEffects(report)
    if category == "skills" then selectedSkillTarget(report); return Reports.SkillRows(report,skillTarget) end
    return report and report[category] or {}
end

function Reports.EnemyGroups(report, effect)
    local groups, byKey, bosses = {}, {}, {}
    local function normalize(name)
        return zo_strformat("<<1>>", name or L("Gegner")):lower()
    end
    for _, name in ipairs(report and report.bossNames or {}) do bosses[normalize(name)] = true end
    for index, member in ipairs(effect and effect.members or {}) do
        local name = member.name or L("Gegner")
        local boss = member.isBoss == true or bosses[normalize(name)] == true
        local key = boss and ("boss:" .. tostring(member.id or index)) or ("type:" .. normalize(name))
        local group = byKey[key]
        if not group then
            group = {key = key, name = name, isBoss = boss, covered = 0, duration = 0, count = 0, members = {}}
            byKey[key], groups[#groups + 1] = group, group
        end
        group.count = group.count + 1
        group.covered = group.covered + (member.covered or 0)
        group.duration = group.duration + (member.duration or 0)
        group.members[#group.members + 1] = member
    end
    for _, group in ipairs(groups) do
        group.percent = group.duration > 0 and group.covered / group.duration * 100 or 0
        group.label = (group.isBoss or group.count == 1) and group.name or string.format(L("%s x%d"), group.name, group.count)
        table.sort(group.members, function(a, b) return tostring(a.id or "") < tostring(b.id or "") end)
    end
    table.sort(groups, function(a, b)
        if a.isBoss ~= b.isBoss then return a.isBoss end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    return groups
end

local function displayMembers(report, effect)
    if category ~= "debuffs" then return effect and effect.members or {} end
    local groups = Reports.EnemyGroups(report, effect)
    if listMode == "enemyTypes" then
        enemyTypeIndex = math.max(1, math.min(enemyTypeIndex, #groups))
        local group = groups[enemyTypeIndex]
        return group and group.members or {}, group, groups
    end
    return groups, nil, groups
end

local function rememberEffectSelection()
    local report = currentReport()
    if not report then return end
    local selections = effectSelections[report] or {}
    selections[category] = { selected = selected, page = page, enemyTypeIndex = enemyTypeIndex, enemyTypePage = enemyTypePage, skillTarget=skillTarget }
    effectSelections[report] = selections
end

local function restoreEffectSelection()
    local report = currentReport()
    local selection = report and effectSelections[report] and effectSelections[report][category]
    selected, page = selection and selection.selected or 1, selection and selection.page or 1
    skillTarget=selection and selection.skillTarget or "all"
    enemyTypeIndex, enemyTypePage = selection and selection.enemyTypeIndex or 1, selection and selection.enemyTypePage or 1
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
    if #report.buffs > 0 or #report.debuffs > 0 or #report.skills > 0 then
        capturedFight = fight
        Reports.Save(report)
    end
    return report
end

function Reports.Save(report)
    if saved and (#report.buffs > 0 or #(report.debuffs or {}) > 0 or #(report.skills or {}) > 0) then
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

local function isOverview()
    return category == "skills" or listMode == "fights"
end

local function overviewRows(report)
    return currentEffects(report)
end

local function renderOverview(report)
    local skills = category == "skills"
    local rows = overviewRows(report)
    local pages = math.max(1, math.ceil(#rows / ROWS))
    if skills then
        -- In this category page is the first visible row, not a page number.
        page = math.max(1, math.min(page, math.max(1, #rows - ROWS + 1)))
    else
        page = math.max(1, math.min(page, pages))
    end
    local offset = skills and page - 1 or (page - 1) * ROWS
    local duration = report and math.max(0, (report.ended or 0) - (report.started or 0)) or 0
    local totalDamage = report and report.ownDamage or 0
    local damageDuration = report and report.skillDamageDuration or duration
    local target=skills and selectedSkillTarget(report)
    local targetDamage=target and target.damage or totalDamage
    if target and target.isBoss then damageDuration=target.duration end
    local legacy = skills and report and not report.skillDamageRecorded
    controls.heading:SetText(categoryName(category))
    controls.subject:SetText(skills and L("Skill") or categoryName(category))
    controls.coverage:SetText(skills and L("Schaden") or category == "debuffs" and L("Debuffzeit") or L("Buffzeit"))
    controls.durationHeading:SetText(skills and "DPS" or L("Bezugszeit"))
    controls.percentHeading:SetText(skills and L("Anteil") or "Uptime")
    controls.receiptHeading:SetHidden(true)
    controls.buff:SetText(report and displayTitle(report) or L("Noch kein abgeschlossener Kampf"))
    controls.selection:SetText("")
    controls.subtitle:SetText(report and string.format("%s | %s | %d:%s", reportDate(report), report.clock or "",
        math.floor(duration / 60), decimal(duration % 60, "%04.1f")) or "")
    controls.basis:SetText(skills and L("Eigener Schaden inklusive eigener Begleiter") or L("Uebersicht des ausgewaehlten Kampfes"))
    if target and report and report.skillTargetsRecorded then
        controls.basis:SetText(target.name)
    end
    for index = 1, ROWS do
        local entry = rows[offset + index]
        local row = controls.rows[index]
        row.background:SetHidden(not entry)
        row.name:SetFont("ZoFontGamepad34")
        row.name:SetText(entry and entry.name or "")
        row.name:SetColor(0.91,0.93,0.94,1)
        row.death:SetFont(skills and "ZoFontGamepad22" or "ZoFontGamepad27")
        row.death:SetText(entry and (skills and string.format(L("%d Treffer | ID %d"), entry.hits or 0, entry.id or 0)
            or entry.groupRole == "damage" and L("Nur DDs") or entry.unit == "group" and L("Auf der Gruppe")
            or category == "debuffs" and L("Auf dem Gegner") or L("Auf mir")) or "")
        row.role:SetText("")
        local icon = entry and entry.id and entry.id > 0 and GetAbilityIcon(entry.id)
        row.roleIcon:SetHidden(not icon)
        row.roleIcon:SetColor(1,1,1,1)
        if icon then row.roleIcon:SetTexture(icon) end
        local covered = entry and (skills and entry.damage or entry.covered) or 0
        local reference = skills and targetDamage or entry and entry.duration or 0
        row.covered:SetText(entry and (skills and decimal(covered,"%.0f") or decimal(covered).." s") or "")
        row.duration:SetText(entry and (skills and decimal(damageDuration > 0 and covered / damageDuration or 0,"%.0f")
            or decimal(entry.duration).." s") or "")
        row.percent:SetText(entry and (decimal(reference > 0 and covered/reference*100 or 0,"%.1f").." %") or "")
        row.percent:SetColor(0.55,0.95,0.65,1)
        row.buffIcon:SetHidden(true); row.received:SetText("")
    end
    local singleTarget=skills and target and target.key~="all"
    local footerDamage=singleTarget and targetDamage or totalDamage
    controls.total:SetText(report and not legacy and (skills and (L(singleTarget and "Schaden" or "Gesamtschaden").."  "..decimal(footerDamage,"%.0f"))
        or categoryName(category).."  "..#rows) or "")
    local footerDuration=singleTarget and target.duration or (report and report.skillDamageDuration or duration)
    controls.times:SetText(skills and report and not legacy and (L(singleTarget and (target.isBoss and "Boss-DPS" or "DPS") or "Gesamt-DPS").."  "..decimal(footerDuration > 0 and footerDamage/footerDuration or 0,"%.0f")) or "")
    controls.page:SetText(listMode == "buffs" and (string.format(L("Seite %d / 3"),categoryIndex())
        .. (not skills and pages>1 and string.format("\n%d / %d",page,pages) or "")) or "")
    local scrollable = skills and listMode == "buffs" and #rows > ROWS
    controls.skillScrollTrack:SetHidden(not scrollable)
    controls.skillScrollThumb:SetHidden(not scrollable)
    if scrollable then
        local height = ROWS * 70
        local thumbHeight = math.max(28, height * ROWS / #rows)
        controls.skillScrollThumb:ClearAnchors()
        controls.skillScrollThumb:SetAnchor(TOPLEFT, detailWindow, TOPLEFT, 942,
            204 + (height - thumbHeight) * offset / (#rows - ROWS))
        controls.skillScrollThumb:SetDimensions(5, thumbHeight)
    end
    if legacy then controls.basis:SetText(L("Alte Kaempfe enthalten keine Skill-Schadensdaten.")) end
    controls.warning:SetText(skills and report and report.skillTargetsTruncated and L("Einzelwerte unvollstaendig") or #rows == 0 and (legacy
        and L("Keine Skill-Daten")
        or skills and L("Kein eigener Schaden aufgezeichnet") or L("Keine aufgezeichneten Effekte")) or "")
end

function Reports.Refresh()
    if not window or deletePending then return end
    updateDetailVisibility()
    local report = currentReport()
    selected = math.max(1, math.min(selected, #currentEffects(report)))
    local effect = currentEffects(report)[selected]
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
            effect = currentEffects(report)[selected]
        end
        if listMode == "enemyTypes" then
            enemyTypeIndex = math.max(1, math.min(enemyTypeIndex, #Reports.EnemyGroups(report, effect)))
        end
        rebuildingList = true
        local rebuilt = false
        if historyFirst ~= history[1] or historyCount ~= #history or lastListMode ~= listMode
            or (listMode == "fights" and listZone ~= selectedZone)
            or (listMode == "buffs" and (listCategory ~= category or listReport ~= report))
            or (listMode == "enemyTypes" and (listEffect ~= effect or listReport ~= report)) then
            nativeList:Clear()
            nativeList:SetNoItemText(listMode == "enemyTypes" and L("Keine aufgezeichneten Gegner")
                or listMode == "buffs" and L("Keine aufgezeichneten Effekte") or L("Noch kein abgeschlossener Kampf"))
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
            elseif listMode == "enemyTypes" then
                for index, group in ipairs(Reports.EnemyGroups(report, effect)) do
                    local entry = ZO_GamepadEntryData:New(group.label, GetAbilityIcon(effect.id))
                    entry.enemyTypeIndex = index
                    if entry.AddSubLabel then entry:AddSubLabel(string.format("%s %%", decimal(group.percent, "%.1f"))) end
                    nativeList:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
                    selectionIndices[#selectionIndices + 1] = index
                end
            elseif listMode == "buffs" then
                if category=="skills" and report and report.skillTargetsRecorded then
                    for _,target in ipairs(Reports.SkillTargets(report)) do
                        local entry=ZO_GamepadEntryData:New(target.name,report.placeIcon or DEFAULT_PLACE_ICON)
                        entry.skillTargetKey=target.key
                        nativeList:AddEntry("ZO_GamepadMenuEntryTemplate",entry)
                        selectionIndices[#selectionIndices+1]=target.key
                    end
                else
                for index, buff in ipairs(currentEffects(report)) do
                    local entry = ZO_GamepadEntryData:New(buff.name, GetAbilityIcon(buff.id))
                    entry.buffIndex = index
                    if entry.AddSubLabel then entry:AddSubLabel(category == "skills" and (L("Schaden") .. " " .. decimal(buff.damage,"%.0f"))
                        or category == "debuffs" and L("Auf dem Gegner") or buff.groupRole == "damage" and L("Nur DDs")
                        or buff.unit == "group" and L("Auf der Gruppe") or L("Auf mir")) end
                    nativeList:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
                    selectionIndices[#selectionIndices + 1] = index
                end
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
            listEffect = effect
            rebuilt = true
        end
        local key = listMode == "zones" and selectedZone or listMode == "fights" and selectedFight
            or listMode == "enemyTypes" and enemyTypeIndex or (category=="skills" and report and report.skillTargetsRecorded and skillTarget) or selected
        local index = 1
        for position, value in ipairs(selectionIndices) do if value == key then index = position; break end end
        if #selectionIndices > 0 and (rebuilt or not nativeList.GetSelectedIndex or nativeList:GetSelectedIndex() ~= index) then
            if rebuilt and nativeList.SetSelectedIndexWithoutAnimation then
                nativeList:SetSelectedIndexWithoutAnimation(index, true)
            else nativeList:SetSelectedIndex(index) end
        end
        rebuildingList = false
        nativeScreen.headerData.titleText = listMode == "zones" and L("Kampfstatistiken")
            or listMode == "fights" and (report and zoneTitle(report) or L("Kaempfe"))
            or listMode == "enemyTypes" and L("Gegnertypen") or categoryName(category)
        -- Use the native tabbar for its title, pips and platform button icons.
        -- Only our keybind strip handles input; activating the native tabbar as
        -- well would advance twice for one shoulder press on PC/controller.
        nativeScreen.headerData.tabBarEntries = nil
        if listMode == "buffs" or listMode == "enemyTypes" then
            nativeScreen.headerData.tabBarEntries = {}
            for _, value in ipairs(categories) do
                nativeScreen.headerData.tabBarEntries[#nativeScreen.headerData.tabBarEntries + 1] = { text = categoryName(value) }
            end
        end
        if nativeScreen.header and ZO_GamepadGenericHeader_Refresh then
            ZO_GamepadGenericHeader_Refresh(nativeScreen.header, nativeScreen.headerData)
            if nativeScreen.headerData.tabBarEntries and ZO_GamepadGenericHeader_SetActiveTabIndex then
                ZO_GamepadGenericHeader_SetActiveTabIndex(nativeScreen.header, categoryIndex())
                if ZO_GamepadGenericHeader_RefreshData then
                    ZO_GamepadGenericHeader_RefreshData(nativeScreen.header, nativeScreen.headerData)
                end
            end
        end
    end
    if isOverview() then
        renderOverview(report)
        if opened and keybinds and KEYBIND_STRIP and KEYBIND_STRIP.UpdateKeybindButtonGroup then KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds) end
        return
    end
    controls.durationHeading:SetText(L("Bezugszeit")); controls.percentHeading:SetText("Uptime")
    local buffs = currentEffects(report)
    local debuffs = category == "debuffs"
    controls.heading:SetText(debuffs and L("Debuff-Uptime") or L("Buff-Uptime"))
    controls.subject:SetText(debuffs and (listMode == "enemyTypes" and L("Gegner") or L("Gegnertyp")) or L("Spieler"))
    controls.coverage:SetText(debuffs and L("Debuffzeit") or L("Buffzeit"))
    controls.receiptHeading:SetHidden(debuffs)
    selected = math.max(1, math.min(selected, #buffs))
    local buff = buffs[selected]
    local members, enemyGroup, enemyGroups = displayMembers(report, buff)
    local pages = math.max(1, math.ceil(#members / ROWS))
    local visiblePage = math.max(1, math.min(listMode == "enemyTypes" and enemyTypePage or page, pages))
    if listMode == "enemyTypes" then enemyTypePage = visiblePage else page = visiblePage end
    controls.buff:SetText(buff and (buff.name .. "  |  " .. (debuffs and L("Auf dem Gegner") or buff.groupRole == "damage" and L("Nur DDs")
        or buff.unit == "group" and L("Auf der Gruppe") or L("Auf mir"))) or (report and L("Keine aufgezeichneten Effekte") or L("Noch kein abgeschlossener Kampf")))
    controls.selection:SetText(string.format("%d / %d", buff and selected or 0, #buffs))
    local duration = report and math.max(0, (report.ended or 0) - (report.started or 0)) or 0
    controls.subtitle:SetText(report and string.format("%s  |  %d:%s  |  %d %s", displayTitle(report), math.floor(duration / 60), decimal(duration % 60, "%04.1f"), #members, debuffs and L("Gegner") or L("Spieler")) or "")
    if debuffs and buff then
        controls.subtitle:SetText(string.format(L("%s | %d Gegner | %d Typen"), displayTitle(report), #buff.members, #enemyGroups))
    end
    if buff and buff.groupRole == "damage" then
        local count = 0
        for _, member in ipairs(members) do if member.counted ~= false then count = count + 1 end end
        controls.subtitle:SetText(string.format(L("%s  |  %d:%s  |  %d Spieler, %d DDs gewertet"),
            displayTitle(report), math.floor(duration / 60), decimal(duration % 60, "%04.1f"), #members, count))
    end
    controls.basis:SetText(buff and (debuffs and L("Kampfzeit") or report.fallback and L("Ersatzmessung: HUD-Bezugszeit")
        or buff.unit == "group" and L("Gruppen-Lebendzeit") or buff.basis == "alive" and L("Lebendzeit") or L("Aktive Kampfzeit")) or "")
    if enemyGroup then controls.basis:SetText(L("Kampfzeit") .. " | " .. enemyGroup.label) end
    for index = 1, ROWS do
        local memberIndex = (visiblePage - 1) * ROWS + index
        local member = members[memberIndex]
        local row = controls.rows[index]
        local counted = member and member.counted ~= false
        row.background:SetHidden(member == nil)
        local memberName = member and (member.label or member.account or member.name) or ""
        if enemyGroup and member then memberName = string.format("%s #%d", member.name, memberIndex) end
        row.name:SetText(memberName)
        row.name:SetFont("ZoFontGamepad42")
        row.death:SetFont("ZoFontGamepad27")
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
    local totals = enemyGroup or buff
    controls.total:SetText(totals and string.format("%s  %s %%", debuffs and L("Debuff-Uptime") or buff.groupRole == "damage" and L("DD-Uptime")
        or buff.unit == "group" and L("Gruppen-Uptime") or L("Persoenliche Uptime"), decimal(totals.percent, "%.1f")) or "")
    controls.times:SetText(totals and string.format(L("%s %s s  /  Bezugszeit %s s"), debuffs and L("Debuffzeit") or L("Buffzeit"), decimal(totals.covered), decimal(totals.duration)) or "")
    local pageText = (listMode == "buffs" or listMode == "enemyTypes") and string.format(L("Seite %d / 3"),categoryIndex()) or ""
    if pages > 1 then pageText = pageText .. string.format("\n%s %d / %d", debuffs and (enemyGroup and L("Gegner") or L("Gegnertypen")) or L("Spieler"), visiblePage, pages) end
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
        if category == "skills" then
            if selected < page then page = selected
            elseif selected >= page + ROWS then page = selected - ROWS + 1 end
        else page = 1 end
        enemyTypeIndex, enemyTypePage = 1, 1
        rememberEffectSelection()
        Reports.Refresh()
    end
end

function Reports.SetCategory(value)
    if deletePending or category == value or (listMode ~= "buffs" and listMode ~= "enemyTypes") then return end
    if value ~= "buffs" and value ~= "debuffs" and value ~= "skills" then return end
    rememberEffectSelection()
    if listMode == "enemyTypes" then listMode = "buffs" end
    category = value
    restoreEffectSelection()
    Reports.Refresh()
end

function Reports.ChangeCategory(delta)
    Reports.SetCategory(categories[(categoryIndex()-1+(delta or 1)) % #categories+1])
end

function Reports.ChangePage()
    if deletePending then return end
    if category == "skills" and listMode == "buffs" then return end
    local report = currentReport()
    if isOverview() then
        page = page % math.max(1, math.ceil(#overviewRows(report)/ROWS)) + 1
        rememberEffectSelection(); Reports.Refresh(); return
    end
    local buff = currentEffects(report)[selected]
    if buff then
        local members = displayMembers(report, buff)
        local pages = math.max(1, math.ceil(#members / ROWS))
        if listMode == "enemyTypes" then enemyTypePage = enemyTypePage % pages + 1
        else page = page % pages + 1 end
        rememberEffectSelection()
        Reports.Refresh()
    end
end

function Reports.ScrollSkills(delta)
    if not opened or deletePending or listMode ~= "buffs" or category ~= "skills" then return end
    local count = #currentEffects(currentReport())
    local first = math.max(1, math.min(page + delta, math.max(1, count - ROWS + 1)))
    if first == page then return end
    page = first
    rememberEffectSelection()
    Reports.Refresh()
end

function Reports.SelectFight(index)
    if deletePending then return end
    if not saved or not saved.uptimeHistory[index] then return end
    selectionChosen = true
    selectedZone, listMode = zoneKey(saved.uptimeHistory[index]), "fights"
    if selectedFight ~= index then
        selectedFight, selected, page = index, 1, 1
        enemyTypeIndex, enemyTypePage = 1, 1
    end
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
    if deletePending then return end
    if listMode == "zones" then Reports.ShowZone()
    elseif listMode == "fights" then Reports.ShowBuffs()
    elseif listMode == "buffs" and category == "debuffs" then Reports.ShowEnemyTypes() end
end

function Reports.ShowEnemyTypes()
    if deletePending or category ~= "debuffs" or listMode ~= "buffs" then return end
    local report = currentReport()
    if #Reports.EnemyGroups(report, currentEffects(report)[selected]) == 0 then return end
    listMode = "enemyTypes"
    Reports.Refresh()
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
    updateDetailVisibility()
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
    if listMode == "enemyTypes" then rememberEffectSelection(); listMode = "buffs"; Reports.Refresh()
    elseif listMode == "buffs" then
        rememberEffectSelection(); listMode = "fights"; restoreEffectSelection(); Reports.Refresh()
    elseif listMode == "fights" then listMode = "zones"; Reports.Refresh()
    else Reports.Close() end
end

local function release()
    if not opened then return end
    opened = false
    updateDetailVisibility()
    deletePending = nil
    if nativeList then nativeList:Deactivate() end
    if KEYBIND_STRIP and keybinds then KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds) end
    if previousUI == false and SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(false) end
    if previousCamera == false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
    previousUI, previousCamera = nil, nil
    if ClearTooltip then ClearTooltip(InformationTooltip) end
    if detailWindow then detailWindow:SetHidden(true) end
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
        for _, fragment in pairs({ rightBackground,
            not rightBackground and GAMEPAD_NAV_QUADRANT_2_BACKGROUND_FRAGMENT or nil,
            not rightBackground and GAMEPAD_NAV_QUADRANT_3_BACKGROUND_FRAGMENT or nil }) do
            if fragment then detailFragments[#detailFragments + 1] = fragment end
        end
        for _, fragment in pairs({ GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT, MINIMIZE_CHAT_FRAGMENT, GAMEPAD_MENU_SOUND_FRAGMENT }) do
            if fragment then scene:AddFragment(fragment) end
        end
        local Screen = ZO_Gamepad_ParametricList_Screen:Subclass()
        function Screen:Initialize(control)
            ZO_Gamepad_ParametricList_Screen.Initialize(self, control, true, true, scene)
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
            elseif entry.skillTargetKey then
                if skillTarget~=entry.skillTargetKey then skillTarget,page=entry.skillTargetKey,1 end
                rememberEffectSelection(); Reports.Refresh()
            elseif entry.buffIndex then
                if selected ~= entry.buffIndex then
                    selected = entry.buffIndex
                    if category == "skills" then
                        if selected < page then page = selected
                        elseif selected >= page + ROWS then page = selected - ROWS + 1 end
                    else page = 1 end
                    enemyTypeIndex, enemyTypePage = 1, 1
                end
                rememberEffectSelection()
                Reports.Refresh()
            elseif entry.enemyTypeIndex then
                if enemyTypeIndex ~= entry.enemyTypeIndex then enemyTypeIndex, enemyTypePage = entry.enemyTypeIndex, 1 end
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
    window:SetHandler("OnMouseWheel", function(_, delta) Reports.ScrollSkills(-delta) end)
    local nextScrollAt, scrollDirection = 0, 0
    skillScrollUpdate = function()
        local y = GetGamepadRightStickY and GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
        local direction = y > 0.35 and -1 or y < -0.35 and 1 or 0
        if direction == 0 then scrollDirection, nextScrollAt = 0, 0; return end
        local now = GetFrameTimeSeconds()
        if direction ~= scrollDirection or now >= nextScrollAt then
            nextScrollAt = now + (direction ~= scrollDirection and 0.3 or 0.1)
            scrollDirection = direction
            Reports.ScrollSkills(direction)
        end
    end
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
    controls.basis = label(window, "LiveBuffUptimeReportBasis", 28, 126, 720, 30, "ZoFontGamepad27", { 0.64, 0.72, 0.7, 1 })
    local columns = { { L("Spieler"), 36, 308 }, { L("Buffzeit"), 362, 150 }, { L("Bezugszeit"), 528, 150 }, { "Uptime", 694, 150 } }
    for index, column in ipairs(columns) do
        local control = label(window, nil, column[2], 158, column[3], 38, "ZoFontGamepad34")
        control:SetText(column[1])
        if index == 1 then controls.subject = control elseif index == 2 then controls.coverage = control
        elseif index == 3 then controls.durationHeading = control else controls.percentHeading = control end
    end
    controls.receiptHeading = label(window, "LiveBuffUptimeReportReceiptHeading", 854, 150, 80, 44, "ZoFontGamepad18")
    controls.receiptHeading:SetText(L("Erhalten /\nErneuert"))
    controls.receiptHeading:SetMaxLineCount(2)
    controls.receiptHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    controls.rows = {}
    controls.skillScrollTrack = band(window, 942, 204, 5, ROWS * 70, { 1, 1, 1, 0.15 })
    controls.skillScrollThumb = band(window, 942, 204, 5, ROWS * 70, { 0.8, 0.8, 0.7, 0.9 })
    controls.skillScrollTrack:SetHidden(true)
    controls.skillScrollThumb:SetHidden(true)
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
    controls.times = label(window, "LiveBuffUptimeReportTimes", 36, 1096, 650, 30, "ZoFontGamepad27")
    controls.page = label(window, "LiveBuffUptimeReportPage", 708, 1084, 224, 44, "ZoFontGamepad22")
    controls.page:SetMaxLineCount(2)
    controls.warning = label(window, "LiveBuffUptimeReportWarning", 650, 1054, 282, 28, "ZoFontGamepad22", { 1, 0.7, 0.4, 1 })
    keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { name = L("Zurueck"), keybind = "UI_SHORTCUT_NEGATIVE", callback = Reports.Back },
        { name = function() return categoryName(categories[categoryIndex()%3+1]) end,
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = function() Reports.ChangeCategory(1) end,
            visible = function() return not deletePending and (listMode == "buffs" or listMode == "enemyTypes") end },
        { name = function() return categoryName(categories[(categoryIndex()+1)%3+1]) end,
            keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() Reports.ChangeCategory(-1) end,
            visible = function() return not deletePending and (listMode == "buffs" or listMode == "enemyTypes") end },
        { name = function() return isOverview() and L("Weitere Eintraege") or category == "debuffs" and (listMode == "enemyTypes" and L("Weitere Gegner") or L("Weitere Gegnertypen")) or L("Weitere Spieler") end,
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER", callback = Reports.ChangePage,
            visible = function()
                local report = currentReport()
                if category == "skills" and listMode == "buffs" then return false end
                if isOverview() then return #overviewRows(report) > ROWS end
                local members = displayMembers(report, currentEffects(report)[selected])
                return (listMode == "buffs" or listMode == "enemyTypes") and #members > ROWS
            end },
        { name = function() return listMode == "zones" and L("Kaempfe anzeigen")
                or listMode == "buffs" and L("Gegnertypen anzeigen") or L("Buffs anzeigen") end,
            keybind = "UI_SHORTCUT_PRIMARY", callback = Reports.ConfirmSelection,
            visible = function()
                local report = currentReport()
                if category == "skills" and listMode == "buffs" then return false end
                if listMode == "buffs" then
                    return category == "debuffs" and #Reports.EnemyGroups(report, currentEffects(report)[selected]) > 0
                end
                return listMode ~= "enemyTypes" and report ~= nil
            end },
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
        -- Statistics visibility is managed directly. A scene-wide fade fragment
        -- would briefly reveal the previous report while opening the browser.
        scene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_HIDING or state == SCENE_HIDDEN or state == "hiding" or state == "hidden" then release() end
            if (SCENE_SHOWN and state == SCENE_SHOWN) or state == "shown" then Reports.Refresh() end
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
    listMode, category = "zones", "buffs"
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
    detailWindow:SetHidden(true)
    if KEYBIND_STRIP then KEYBIND_STRIP:AddKeybindButtonGroup(keybinds) end
    Reports.Refresh()
    if nativeScreen then nativeScreen:SetCurrentList(nativeList) end
    if nativeList then nativeList:Activate() end
end
