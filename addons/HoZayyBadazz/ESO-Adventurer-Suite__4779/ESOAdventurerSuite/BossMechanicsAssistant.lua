-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Endgame Boss Mechanics Coach: live boss recognition, mechanic callouts,
-- role-aware positioning, adaptive next-mechanic learning, and execution review.
-- Guidance only. It never moves the player, targets, blocks, interrupts, casts,
-- activates synergies, or performs any other protected gameplay action.

local EPC = ESOProgressionCoach
EPC.BossMechanicsAssistant = EPC.BossMechanicsAssistant or {}
local M = EPC.BossMechanicsAssistant
local wm = WINDOW_MANAGER

local BOSS_BASE_W029203, BOSS_BASE_H029203 = 640, 154
local BOSS_MIN_W029203, BOSS_MIN_H029203 = 420, 110
local BOSS_MAX_W029203, BOSS_MAX_H029203 = 1000, 300

local function clamp029203(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function font029203(kind, size)
    size = math.max(10, math.floor((tonumber(size) or 14) + 0.5))
    if kind == "bold" then return "$(BOLD_FONT)|" .. tostring(size) .. "|soft-shadow-thick" end
    return "$(MEDIUM_FONT)|" .. tostring(size) .. "|soft-shadow-thin"
end

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e, f
end

local function nowMs()
    return tonumber(safe(GetFrameTimeMilliseconds, 0)) or 0
end

local function clean(value)
    value = tostring(value or "")
    if value == "" then return "" end
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", value)
        if ok and formatted and formatted ~= "" then value = formatted end
    end
    value = value:gsub("%^%a+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function norm(value)
    value = string.lower(clean(value))
    value = value:gsub("[%c%p%s]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function has(list, wanted)
    wanted = tostring(wanted or "")
    for i = 1, #(list or {}) do
        if tostring(list[i]) == wanted then return true end
    end
    return false
end

local function containsAction(mechanic, wanted)
    wanted = tostring(wanted or "")
    for i = 1, #(mechanic and mechanic.actions or {}) do
        if tostring(mechanic.actions[i]) == wanted then return true end
    end
    return false
end

local function copyArray(input)
    local out = {}
    for i = 1, #(input or {}) do out[i] = input[i] end
    return out
end

local function joinLimited(input, separator, limit)
    local out = {}
    for i = 1, math.min(#(input or {}), limit or 3) do
        if input[i] and tostring(input[i]) ~= "" then out[#out + 1] = tostring(input[i]) end
    end
    return table.concat(out, separator or "  •  ")
end

local function makeBackdrop(parent)
    local bg = wm:CreateControl(nil, parent, CT_BACKDROP)
    bg:SetCenterColor(0.018, 0.022, 0.032, 0.96)
    bg:SetEdgeColor(0.33, 0.37, 0.46, 0.92)
    bg:SetEdgeTexture(nil, 1, 1, 1)
    return bg
end

local function makeLabel(parent, font, r, g, b, a)
    local label = wm:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetColor(r or 1, g or 1, b or 1, a or 1)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local PRIORITY_COLORS = {
    [5] = { 1.00, 0.25, 0.18, 1.00 },
    [4] = { 1.00, 0.62, 0.20, 1.00 },
    [3] = { 1.00, 0.84, 0.34, 1.00 },
    [2] = { 0.72, 0.82, 0.94, 1.00 },
}

local EAS_BOSS_ACTION_BINDINGS029199 = {
    BLOCK = "SPECIAL_MOVE_BLOCK",
    INTERRUPT = "SPECIAL_MOVE_INTERRUPT",
    DODGE = "ROLL_DODGE",
    SYNERGY = "USE_SYNERGY",
    ["WEAPON SWAP"] = "SPECIAL_MOVE_WEAPON_SWAP",
    SWAP = "SPECIAL_MOVE_WEAPON_SWAP",
}

function M:ActionPrompt029199(action)
    action = tostring(action or "")
    if action == "" then return "" end
    local normalized = string.upper(action)
    local bindingName = EAS_BOSS_ACTION_BINDINGS029199[normalized]
    if bindingName and EPC.GetActionBindingMarkup029199 then
        local glyph = EPC:GetActionBindingMarkup029199(bindingName, 24)
        if glyph ~= "" then return glyph .. " " .. action end
    end

    -- ESO's Break Free input is a simultaneous Attack + Block chord rather than
    -- a separate player-facing binding. Show both of the player's real controls.
    if normalized == "BREAK" or normalized == "BREAK FREE" then
        local block = EPC.GetActionBindingMarkup029199 and EPC:GetActionBindingMarkup029199("SPECIAL_MOVE_BLOCK", 22) or ""
        local attack = EPC.GetActionBindingMarkup029199 and EPC:GetActionBindingMarkup029199("SPECIAL_MOVE_ATTACK", 22) or ""
        if block ~= "" and attack ~= "" then return block .. "+" .. attack .. " " .. action end
    end
    return action
end

function M:FormatActions029199(actions, limit)
    local out = {}
    for i = 1, math.min(#(actions or {}), tonumber(limit) or 3) do
        local action = actions[i]
        if action and tostring(action) ~= "" then out[#out + 1] = self:ActionPrompt029199(action) end
    end
    return table.concat(out, "  •  ")
end

function M:GetRoleKey()
    local role = EPC.Role and EPC.Role.GetRole and EPC.Role:GetRole() or "DAMAGE"
    role = string.upper(tostring(role or "DAMAGE"))
    if role == "TANK" then return "tank", "TANK" end
    if role == "HEALER" then return "healer", "HEALER" end
    return "dps", "DPS"
end

function M:GetZoneInfo()
    local zoneName = clean(safe(GetUnitZone, "", "player"))
    local zoneId = 0
    local zoneIndex = tonumber(safe(GetUnitZoneIndex, 0, "player")) or 0
    if zoneIndex > 0 and type(GetZoneId) == "function" then zoneId = tonumber(safe(GetZoneId, 0, zoneIndex)) or 0 end
    if zoneName == "" and zoneId > 0 and type(GetZoneNameById) == "function" then
        zoneName = clean(safe(GetZoneNameById, "", zoneId))
    end
    return zoneName, zoneId
end

function M:BuildIndexes()
    self.bossNameIndex = {}
    self.activityNameIndex = {}
    self.activityZoneIndex = {}
    local data = EPC.BossMechanicsData
    if type(data) ~= "table" or type(data.activities) ~= "table" then return end

    local function addBossAlias(alias, ref)
        local key = norm(alias)
        if key == "" then return end
        self.bossNameIndex[key] = self.bossNameIndex[key] or {}
        self.bossNameIndex[key][#self.bossNameIndex[key] + 1] = ref
    end

    for _, activity in ipairs(data.activities) do
        activity._bossById = {}
        activity._castIndex = {}
        local activityKey = norm(activity.name)
        if activityKey ~= "" then self.activityNameIndex[activityKey] = activity end
        for _, alias in ipairs(activity.aliases or {}) do
            local aliasKey = norm(alias)
            if aliasKey ~= "" then self.activityNameIndex[aliasKey] = activity end
        end
        for _, zoneId in ipairs(activity.zoneIds or {}) do
            zoneId = tonumber(zoneId) or 0
            if zoneId > 0 then self.activityZoneIndex[zoneId] = activity end
        end

        for _, boss in ipairs(activity.bosses or {}) do
            boss._activity = activity
            boss._mechanicByKey = {}
            boss._castIndex = {}
            boss._abilityIdIndex = {}
            activity._bossById[boss.id] = boss
            local ref = { activity = activity, boss = boss }
            addBossAlias(boss.name, ref)

            -- Multi-boss encounter display names often combine the actual ESO
            -- boss unit names. Index each readable side as a fallback.
            local splitSource = tostring(boss.name or "")
            for part in splitSource:gmatch("[^%+&/]+") do
                part = clean(part:gsub("^and%s+", ""))
                if #part >= 4 then addBossAlias(part, ref) end
            end
            local lowerName = string.lower(splitSource)
            local andPos = lowerName:find(" and ", 1, true)
            if andPos then
                local left = clean(splitSource:sub(1, andPos - 1))
                local right = clean(splitSource:sub(andPos + 5))
                if #left >= 4 then addBossAlias(left, ref) end
                if #right >= 4 then addBossAlias(right, ref) end
            end

            for _, mechanic in ipairs(boss.mechanics or {}) do
                mechanic._boss = boss
                mechanic._activity = activity
                mechanic._tagSet = {}
                for _, tag in ipairs(mechanic.tags or {}) do mechanic._tagSet[tostring(tag)] = true end
                boss._mechanicByKey[mechanic.key] = mechanic
                for _, castName in ipairs(mechanic.casts or {}) do
                    local castKey = norm(castName)
                    if castKey ~= "" then
                        boss._castIndex[castKey] = boss._castIndex[castKey] or {}
                        boss._castIndex[castKey][#boss._castIndex[castKey] + 1] = mechanic
                        activity._castIndex[castKey] = activity._castIndex[castKey] or {}
                        activity._castIndex[castKey][#activity._castIndex[castKey] + 1] = { boss = boss, mechanic = mechanic }
                    end
                end
            end
        end
    end

    self:LoadLearnedAbilityIds()
end

function M:EnsureSaved()
    if not EPC.saved then return end
    if type(EPC.saved.bossMechanicsAbilityMap029198) ~= "table" then EPC.saved.bossMechanicsAbilityMap029198 = {} end
    if type(EPC.saved.bossMechanicsLearning029198) ~= "table" then EPC.saved.bossMechanicsLearning029198 = {} end
    if tonumber(EPC.saved.bossMechanicsWidth029203) == nil then EPC.saved.bossMechanicsWidth029203 = BOSS_BASE_W029203 end
    if tonumber(EPC.saved.bossMechanicsHeight029203) == nil then EPC.saved.bossMechanicsHeight029203 = BOSS_BASE_H029203 end
end

function M:BossKey(boss)
    if not boss then return "unknown" end
    local activity = boss._activity
    return tostring(activity and activity.id or "unknown") .. "|" .. tostring(boss.id or norm(boss.name))
end

function M:LoadLearnedAbilityIds()
    self:EnsureSaved()
    if not EPC.saved then return end
    local learned = EPC.saved.bossMechanicsAbilityMap029198
    for bossKey, ids in pairs(learned or {}) do
        if type(ids) == "table" then
            for _, candidates in pairs(self.bossNameIndex or {}) do
                for _, ref in ipairs(candidates or {}) do
                    local boss = ref.boss
                    if self:BossKey(boss) == bossKey then
                        for abilityId, mechanicKey in pairs(ids) do
                            local mechanic = boss._mechanicByKey and boss._mechanicByKey[mechanicKey]
                            if mechanic then boss._abilityIdIndex[tonumber(abilityId) or abilityId] = mechanic end
                        end
                    end
                end
            end
        end
    end
end

function M:LearnAbilityId(boss, mechanic, abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 or not boss or not mechanic or not mechanic.key then return end
    boss._abilityIdIndex = boss._abilityIdIndex or {}
    boss._abilityIdIndex[abilityId] = mechanic
    if EPC.saved and EPC.saved.bossMechanicsLearningEnabled029198 ~= false then
        self:EnsureSaved()
        local bossKey = self:BossKey(boss)
        EPC.saved.bossMechanicsAbilityMap029198[bossKey] = EPC.saved.bossMechanicsAbilityMap029198[bossKey] or {}
        EPC.saved.bossMechanicsAbilityMap029198[bossKey][tostring(abilityId)] = mechanic.key
    end
end

-- v0.29.200 - Infinite Archive is an endless-dungeon instance rather than a
-- normal fixed activity from the Codex data set. Reuse any known boss profile
-- when the Archive rolls that boss, and create a lightweight generic profile for
-- Archive-only/unknown bosses so heavy-attack coaching and encounter tracking
-- still stay alive instead of hiding the coach completely.
function M:IsInfiniteArchive029200()
    return type(IsInstanceEndlessDungeon) == "function" and safe(IsInstanceEndlessDungeon, false) == true
end

function M:GetInfiniteArchiveActivity029200()
    if not self.archiveActivity029200 then
        self.archiveActivity029200 = {
            id = "infinite_archive", name = "Infinite Archive", kind = "ENDLESS_DUNGEON",
            aliases = { "Infinite Archive", "Endless Archive" }, zoneIds = {}, bosses = {},
            _bossById = {}, _castIndex = {},
        }
    end
    return self.archiveActivity029200
end

function M:GetOrCreateArchiveBossRef029200(name)
    if not self:IsInfiniteArchive029200() then return nil end
    local key = norm(name)
    if key == "" then return nil end
    self.archiveBossRefs029200 = self.archiveBossRefs029200 or {}
    if self.archiveBossRefs029200[key] then return self.archiveBossRefs029200[key] end
    local activity = self:GetInfiniteArchiveActivity029200()
    local boss = {
        id = "archive_" .. key:gsub("%s+", "_"), name = clean(name), mechanics = {},
        _activity = activity, _mechanicByKey = {}, _castIndex = {}, _abilityIdIndex = {},
    }
    local ref = { activity = activity, boss = boss, archiveGeneric = true }
    self.archiveBossRefs029200[key] = ref
    activity._bossById[boss.id] = boss
    return ref
end

function M:ResolveCurrentActivity()
    if self:IsInfiniteArchive029200() then
        local activity = self:GetInfiniteArchiveActivity029200()
        self.currentActivity = activity
        return activity
    end
    local zoneName, zoneId = self:GetZoneInfo()
    local activity = self.activityZoneIndex and self.activityZoneIndex[tonumber(zoneId) or 0] or nil
    if activity then self.currentActivity = activity return activity end
    local zoneKey = norm(zoneName)
    activity = self.activityNameIndex and self.activityNameIndex[zoneKey] or nil
    if not activity and zoneKey ~= "" then
        for key, candidate in pairs(self.activityNameIndex or {}) do
            if #key >= 5 and (zoneKey:find(key, 1, true) or key:find(zoneKey, 1, true)) then
                activity = candidate
                break
            end
        end
    end
    self.currentActivity = activity
    return activity
end

function M:FindBossProfile(name, allowArchiveDynamic)
    local key = norm(name)
    if key == "" then return nil end
    local candidates = self.bossNameIndex and self.bossNameIndex[key]
    if not candidates or #candidates == 0 then
        if allowArchiveDynamic == true then return self:GetOrCreateArchiveBossRef029200(name) end
        return nil
    end
    local activity = self.currentActivity or self:ResolveCurrentActivity()
    if activity then
        for _, ref in ipairs(candidates) do if ref.activity == activity then return ref end end
    end
    return candidates[1]
end

function M:GetBossHealthPercent(tag)
    if not tag or tag == "" or POWER_HEALTH == nil or type(GetUnitPower) ~= "function" then return nil end
    local current, maximum = safe(GetUnitPower, 0, tag, POWER_HEALTH)
    current, maximum = tonumber(current) or 0, tonumber(maximum) or 0
    if maximum <= 0 then return nil end
    return math.max(0, math.min(100, current / maximum * 100))
end

function M:ScanBosses()
    self:ResolveCurrentActivity()
    local found = {}
    local maxBosses = tonumber(rawget(_G, "MAX_BOSSES")) or 6
    for i = 1, maxBosses do
        local tag = "boss" .. tostring(i)
        if safe(DoesUnitExist, false, tag) == true then
            local name = clean(safe(GetUnitName, "", tag))
            local ref = self:FindBossProfile(name, true)
            found[#found + 1] = { tag = tag, name = name, ref = ref, health = self:GetBossHealthPercent(tag) }
        end
    end

    -- Some encounters briefly drop boss unit tags between phases. The target
    -- under the reticle is a useful fallback without polling every NPC nearby.
    if #found == 0 and safe(DoesUnitExist, false, "reticleover") == true then
        local name = clean(safe(GetUnitName, "", "reticleover"))
        local ref = self:FindBossProfile(name, true)
        if ref then found[#found + 1] = { tag = "reticleover", name = name, ref = ref, health = self:GetBossHealthPercent("reticleover") } end
    end

    self.activeBosses = found
    local previousKey = self.currentBoss and self.currentBoss.ref and self:BossKey(self.currentBoss.ref.boss) or nil
    local selected = nil
    for _, row in ipairs(found) do
        if row.ref then selected = row break end
    end
    self.currentBoss = selected
    local currentKey = selected and selected.ref and self:BossKey(selected.ref.boss) or nil
    if currentKey ~= previousKey then
        self.prePullShownAt = nowMs()
        if currentKey and previousKey and currentKey ~= previousKey then self.hmDetected = false end
        self.lastMechanicKey = nil
        self.lastMechanicAt = nil
        self.lastHealthBucket = nil
    end
    self:Refresh()
end

function M:IsBossNameActive(name)
    local key = norm(name)
    if key == "" then return false, nil end
    for _, row in ipairs(self.activeBosses or {}) do
        if norm(row.name) == key then return true, row end
        if row.ref and norm(row.ref.boss.name) == key then return true, row end
    end
    return false, nil
end

function M:FindBossBySourceName(sourceName)
    local active, row = self:IsBossNameActive(sourceName)
    if active then return row and row.ref end
    local ref = self:FindBossProfile(sourceName)
    if ref and (not self.currentActivity or ref.activity == self.currentActivity) then return ref end
    return nil
end

function M:MatchMechanic(boss, abilityName, abilityId)
    if not boss then return nil end
    abilityId = tonumber(abilityId) or 0
    if abilityId > 0 and boss._abilityIdIndex and boss._abilityIdIndex[abilityId] then return boss._abilityIdIndex[abilityId] end
    local key = norm(abilityName)
    if key == "" then return nil end
    local exact = boss._castIndex and boss._castIndex[key]
    if exact and #exact > 0 then return exact[1] end

    -- ESO combat log labels sometimes add one descriptive word compared with
    -- guide/death-recap labels. Keep fuzzy matching boss-local and conservative.
    if #key >= 7 then
        local only = nil
        for castKey, mechanics in pairs(boss._castIndex or {}) do
            if #castKey >= 7 and (key:find(castKey, 1, true) or castKey:find(key, 1, true)) then
                local candidate = mechanics and mechanics[1]
                if candidate then
                    if only and only ~= candidate then return nil end
                    only = candidate
                end
            end
        end
        if only then return only end
    end
    return nil
end

function M:MatchActivityMechanic(abilityName)
    local activity = self.currentActivity
    if not activity then return nil, nil end
    local key = norm(abilityName)
    if key == "" then return nil, nil end
    local rows = activity._castIndex and activity._castIndex[key]
    if rows and #rows > 0 then
        if self.currentBoss and self.currentBoss.ref then
            for _, row in ipairs(rows) do
                if row.boss == self.currentBoss.ref.boss then return row.boss, row.mechanic end
            end
        end
        if #rows == 1 then return rows[1].boss, rows[1].mechanic end
        return nil, nil
    end

    -- Add/cast labels can differ slightly from the guide label. Allow a fuzzy
    -- match only when the entire current activity resolves to one mechanic.
    if #key >= 7 then
        local onlyBoss, onlyMechanic = nil, nil
        for castKey, candidates in pairs(activity._castIndex or {}) do
            if #castKey >= 7 and (key:find(castKey, 1, true) or castKey:find(key, 1, true)) then
                for _, row in ipairs(candidates or {}) do
                    if onlyMechanic and onlyMechanic ~= row.mechanic then return nil, nil end
                    onlyBoss, onlyMechanic = row.boss, row.mechanic
                end
            end
        end
        if onlyMechanic then return onlyBoss, onlyMechanic end
    end
    return nil, nil
end

function M:HealthBucket()
    local health = self.currentBoss and self.currentBoss.health or nil
    if self.currentBoss and self.currentBoss.tag then
        health = self:GetBossHealthPercent(self.currentBoss.tag) or health
        self.currentBoss.health = health
    end
    if not health then return "ANY" end
    if health > 75 then return "100-75" end
    if health > 50 then return "75-50" end
    if health > 25 then return "50-25" end
    return "25-0"
end

function M:LearningRow(boss)
    if not boss or not EPC.saved then return nil end
    self:EnsureSaved()
    local key = self:BossKey(boss)
    local all = EPC.saved.bossMechanicsLearning029198
    all[key] = all[key] or { transitions = {}, repeats = {}, pulls = 0 }
    return all[key]
end

local function updateAverage(row, value)
    row.count = (tonumber(row.count) or 0) + 1
    local avg = tonumber(row.avg) or value
    row.avg = avg + ((value - avg) / row.count)
end

function M:LearnTransition(boss, mechanic, eventAt, healthBucket)
    if EPC.saved and EPC.saved.bossMechanicsLearningEnabled029198 == false then
        self.lastMechanicKey = mechanic.key
        self.lastMechanicAt = eventAt
        self.lastHealthBucket = healthBucket
        return
    end
    local learning = self:LearningRow(boss)
    if not learning then return end
    eventAt = tonumber(eventAt) or nowMs()
    local previousKey, previousAt, previousBucket = self.lastMechanicKey, self.lastMechanicAt, self.lastHealthBucket
    if previousKey and previousAt and previousKey ~= mechanic.key then
        local delta = math.max(0.1, (eventAt - previousAt) / 1000)
        local function record(indexKey)
            learning.transitions[indexKey] = learning.transitions[indexKey] or {}
            local row = learning.transitions[indexKey][mechanic.key] or { count = 0, avg = delta }
            updateAverage(row, delta)
            learning.transitions[indexKey][mechanic.key] = row
        end
        record(previousKey)
        if previousBucket and previousBucket ~= "ANY" then record(previousKey .. "@" .. previousBucket) end
    end
    if previousKey == mechanic.key and previousAt then
        local delta = math.max(0.1, (eventAt - previousAt) / 1000)
        local row = learning.repeats[mechanic.key] or { count = 0, avg = delta }
        updateAverage(row, delta)
        learning.repeats[mechanic.key] = row
    end
    self.lastMechanicKey = mechanic.key
    self.lastMechanicAt = eventAt
    self.lastHealthBucket = healthBucket
end

function M:GetPrediction(boss)
    if EPC.saved and EPC.saved.bossMechanicsPredictionEnabled029198 == false then return nil end
    if not boss or not self.lastMechanicKey then return nil end
    local learning = self:LearningRow(boss)
    if not learning then return nil end
    local bucket = self:HealthBucket()
    local rows = learning.transitions[self.lastMechanicKey .. "@" .. bucket] or learning.transitions[self.lastMechanicKey]
    if type(rows) ~= "table" then return nil end
    local bestKey, best, total = nil, nil, 0
    for nextKey, row in pairs(rows) do
        local count = tonumber(row.count) or 0
        total = total + count
        if count > 0 and (not best or count > (tonumber(best.count) or 0)) then bestKey, best = nextKey, row end
    end
    if not best or (tonumber(best.count) or 0) < 2 then return nil end
    local mechanic = boss._mechanicByKey and boss._mechanicByKey[bestKey]
    if not mechanic then return nil end
    return {
        mechanic = mechanic,
        seconds = tonumber(best.avg) or 0,
        confidence = total > 0 and ((tonumber(best.count) or 0) / total) or 0,
        samples = tonumber(best.count) or 0,
    }
end

function M:CreateSession(boss)
    if not boss then return nil end
    local activity = boss._activity
    self.session = {
        bossKey = self:BossKey(boss), bossName = boss.name, activityName = self:IsInfiniteArchive029200() and "Infinite Archive" or (activity and activity.name or ""),
        startedAt = nowMs(), alerts = 0, avoidableHits = 0, cleanAvoids = 0,
        interruptRequired = 0, interruptSuccess = 0, missedInterrupts = 0,
        blockRequired = 0, blockSuccess = 0, missedBlocks = 0,
        dodgeRequired = 0, dodgeSuccess = 0, missedDodges = 0,
        breakRequired = 0, breakSuccess = 0,
        seen = {}, pending = {}, attached = false,
    }
    local learning = self:LearningRow(boss)
    if learning then learning.pulls = (tonumber(learning.pulls) or 0) + 1 end
    return self.session
end

function M:EnsureSession(boss)
    if self.session and boss and self.session.bossKey == self:BossKey(boss) then return self.session end
    return self:CreateSession(boss)
end

function M:MechanicNeeds(mechanic, tag)
    return mechanic and mechanic._tagSet and mechanic._tagSet[tag] == true
end

function M:CreatePending(boss, mechanic, abilityName, abilityId, at)
    local session = self:EnsureSession(boss)
    if not session then return nil end
    local pending = {
        mechanic = mechanic, abilityName = clean(abilityName), abilityKey = norm(abilityName), abilityId = tonumber(abilityId) or 0,
        startedAt = at, deadline = at + 4500, hit = false, resolved = false,
        needInterrupt = self:MechanicNeeds(mechanic, "INTERRUPT") or containsAction(mechanic, "INTERRUPT"),
        needBlock = self:MechanicNeeds(mechanic, "BLOCK") or containsAction(mechanic, "BLOCK"),
        needDodge = self:MechanicNeeds(mechanic, "DODGE") or containsAction(mechanic, "DODGE"),
        needBreak = self:MechanicNeeds(mechanic, "BREAK") or containsAction(mechanic, "BREAK FREE"),
        avoidable = self:MechanicNeeds(mechanic, "MOVE") or self:MechanicNeeds(mechanic, "POSITION")
            or self:MechanicNeeds(mechanic, "FRONTAL") or self:MechanicNeeds(mechanic, "DANGER")
            or self:MechanicNeeds(mechanic, "WIPE") or self:MechanicNeeds(mechanic, "SPREAD")
            or self:MechanicNeeds(mechanic, "KITE"),
    }
    if pending.needInterrupt then session.interruptRequired = session.interruptRequired + 1 end
    if pending.needBlock then session.blockRequired = session.blockRequired + 1 end
    if pending.needDodge then session.dodgeRequired = session.dodgeRequired + 1 end
    if pending.needBreak then session.breakRequired = session.breakRequired + 1 end
    session.pending[#session.pending + 1] = pending
    while #session.pending > 12 do table.remove(session.pending, 1) end
    return pending
end

function M:TriggerMechanic(boss, mechanic, abilityName, abilityId, sourceName)
    if not boss or not mechanic then return end
    local at = nowMs()
    local dedupeKey = self:BossKey(boss) .. "|" .. tostring(mechanic.key)
    if self.lastTriggerKey == dedupeKey and at - (tonumber(self.lastTriggerAt) or 0) < 650 then return end
    self.lastTriggerKey, self.lastTriggerAt = dedupeKey, at

    self:LearnAbilityId(boss, mechanic, abilityId)
    local bucket = self:HealthBucket()
    self:LearnTransition(boss, mechanic, at, bucket)
    local session = self:EnsureSession(boss)
    if session then
        session.alerts = session.alerts + 1
        local seen = session.seen[mechanic.key] or { name = mechanic.short or mechanic.name, count = 0, hits = 0 }
        seen.count = seen.count + 1
        session.seen[mechanic.key] = seen
    end
    self:CreatePending(boss, mechanic, abilityName, abilityId, at)

    local duration = mechanic.priority >= 5 and 4300 or (mechanic.priority >= 4 and 3400 or 2800)
    self.currentAlert = {
        boss = boss, mechanic = mechanic, abilityName = clean(abilityName), abilityId = tonumber(abilityId) or 0,
        sourceName = clean(sourceName), startedAt = at, expiresAt = at + duration, priority = tonumber(mechanic.priority) or 3,
    }
    if mechanic.hmOnly then self.hmDetected = true end
    self:Refresh()
end

function M:BuildGenericHeavy(boss, abilityName)
    return {
        key = "suite_generic_heavy", name = clean(abilityName) ~= "" and clean(abilityName) or "Heavy Attack",
        short = "Heavy Attack", casts = {}, tags = { "BLOCK", "DANGER" }, priority = 5,
        actions = { "BLOCK" }, positions = { "AVOID FRONT" }, hmOnly = false,
        roles = { tank = { "BLOCK", "FACE_AWAY" }, healer = { "BLOCK" }, dps = { "BLOCK" } },
        _tagSet = { BLOCK = true, DANGER = true },
    }
end

function M:OnBeginEvent(abilityName, abilityActionSlotType, sourceName, targetName, abilityId)
    if EPC.saved and EPC.saved.bossMechanicsEnabled029198 == false then return end
    local ref = self:FindBossBySourceName(sourceName)
    local boss, mechanic = ref and ref.boss or nil, nil
    if boss then mechanic = self:MatchMechanic(boss, abilityName, abilityId) end
    if not mechanic then
        local activityBoss, activityMechanic = self:MatchActivityMechanic(abilityName)
        if activityMechanic then boss, mechanic = activityBoss, activityMechanic end
    end
    if mechanic and boss then
        self:TriggerMechanic(boss, mechanic, abilityName, abilityId, sourceName)
        return
    end

    if boss and ACTION_SLOT_TYPE_HEAVY_ATTACK ~= nil and abilityActionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
        self:TriggerMechanic(boss, self:BuildGenericHeavy(boss, abilityName), abilityName, abilityId, sourceName)
    end
end

function M:FindPendingForAbility(abilityName, abilityId)
    local session = self.session
    if not session then return nil end
    local id = tonumber(abilityId) or 0
    local key = norm(abilityName)
    for i = #session.pending, 1, -1 do
        local pending = session.pending[i]
        if not pending.resolved and nowMs() <= (tonumber(pending.deadline) or 0) + 1200 then
            if id > 0 and tonumber(pending.abilityId) == id then return pending end
            if key ~= "" and pending.abilityKey ~= "" and key == pending.abilityKey then return pending end
            if key ~= "" and pending.mechanic then
                for _, castName in ipairs(pending.mechanic.casts or {}) do if norm(castName) == key then return pending end end
            end
        end
    end
    return nil
end

function M:MarkPendingHit(pending)
    if not pending or pending.hit then return end
    pending.hit = true
    local session = self.session
    if not session then return end
    if pending.avoidable then session.avoidableHits = session.avoidableHits + 1 end
    local seen = pending.mechanic and session.seen[pending.mechanic.key]
    if seen then seen.hits = (tonumber(seen.hits) or 0) + 1 end
end

function M:MarkInterruptSuccess()
    local session = self.session
    if not session then return end
    for i = #session.pending, 1, -1 do
        local p = session.pending[i]
        if p.needInterrupt and not p.interruptDone and nowMs() <= p.deadline + 800 then
            p.interruptDone = true
            session.interruptSuccess = session.interruptSuccess + 1
            return
        end
    end
end

function M:MarkBreakSuccess()
    local session = self.session
    if not session then return end
    for i = #session.pending, 1, -1 do
        local p = session.pending[i]
        if p.needBreak and not p.breakDone and nowMs() <= p.deadline + 800 then
            p.breakDone = true
            session.breakSuccess = session.breakSuccess + 1
            return
        end
    end
end

function M:TryTriggerFromResult(abilityName, sourceName, abilityId)
    if EPC.saved and EPC.saved.bossMechanicsEnabled029198 == false then return nil end
    local ref = self:FindBossBySourceName(sourceName)
    local boss, mechanic = ref and ref.boss or nil, nil
    if boss then mechanic = self:MatchMechanic(boss, abilityName, abilityId) end
    if not mechanic then
        local activityBoss, activityMechanic = self:MatchActivityMechanic(abilityName)
        if activityMechanic then boss, mechanic = activityBoss, activityMechanic end
    end
    if mechanic and boss then
        self:TriggerMechanic(boss, mechanic, abilityName, abilityId, sourceName)
        return self:FindPendingForAbility(abilityName, abilityId)
    end
    return nil
end

function M:OnResultEvent(result, abilityName, sourceName, targetName, abilityId)
    if not self.session and not self.inCombat then return end
    if ACTION_RESULT_INTERRUPT ~= nil and result == ACTION_RESULT_INTERRUPT then
        self:MarkInterruptSuccess()
        return
    end
    if ACTION_RESULT_BREAK_FREE ~= nil and result == ACTION_RESULT_BREAK_FREE then
        self:MarkBreakSuccess()
        return
    end
    local pending = self:FindPendingForAbility(abilityName, abilityId)
    if not pending then
        local isUsefulFallback = (ACTION_RESULT_DAMAGE ~= nil and result == ACTION_RESULT_DAMAGE)
            or (ACTION_RESULT_CRITICAL_DAMAGE ~= nil and result == ACTION_RESULT_CRITICAL_DAMAGE)
            or (ACTION_RESULT_DAMAGE_SHIELDED ~= nil and result == ACTION_RESULT_DAMAGE_SHIELDED)
            or (ACTION_RESULT_EFFECT_GAINED ~= nil and result == ACTION_RESULT_EFFECT_GAINED)
            or (ACTION_RESULT_EFFECT_GAINED_DURATION ~= nil and result == ACTION_RESULT_EFFECT_GAINED_DURATION)
        if isUsefulFallback then pending = self:TryTriggerFromResult(abilityName, sourceName, abilityId) end
    end
    if not pending then return end
    if (ACTION_RESULT_BLOCKED_DAMAGE ~= nil and result == ACTION_RESULT_BLOCKED_DAMAGE)
        or (ACTION_RESULT_BLOCKED ~= nil and result == ACTION_RESULT_BLOCKED) then
        if pending.needBlock and not pending.blockDone then
            pending.blockDone = true
            self.session.blockSuccess = self.session.blockSuccess + 1
        end
        return
    end
    if ACTION_RESULT_DODGED ~= nil and result == ACTION_RESULT_DODGED then
        if pending.needDodge and not pending.dodgeDone then
            pending.dodgeDone = true
            self.session.dodgeSuccess = self.session.dodgeSuccess + 1
        end
        return
    end
    if result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DAMAGE_SHIELDED
        or result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL then
        self:MarkPendingHit(pending)
    end
end

function M:FinalizePending(force)
    local session = self.session
    if not session then return end
    local at = nowMs()
    local keep = {}
    for _, p in ipairs(session.pending or {}) do
        if force or at > (tonumber(p.deadline) or 0) then
            if p.avoidable and not p.hit then session.cleanAvoids = session.cleanAvoids + 1 end
            if p.needInterrupt and not p.interruptDone then session.missedInterrupts = session.missedInterrupts + 1 end
            if p.needBlock and p.hit and not p.blockDone then session.missedBlocks = session.missedBlocks + 1 end
            if p.needDodge and p.hit and not p.dodgeDone then session.missedDodges = session.missedDodges + 1 end
            p.resolved = true
        else
            keep[#keep + 1] = p
        end
    end
    session.pending = keep
end

function M:BuildSessionSummary()
    local session = self.session
    if not session then return nil end
    local penalty = math.min(65, session.avoidableHits * 11)
        + math.min(20, session.missedInterrupts * 8)
        + math.min(12, session.missedBlocks * 6)
        + math.min(12, session.missedDodges * 6)
    local score = math.max(0, math.min(100, math.floor(100 - penalty + 0.5)))
    local grade = score >= 97 and "S" or (score >= 90 and "A" or (score >= 80 and "B" or (score >= 70 and "C" or "D")))
    if session.alerts <= 0 then grade, score = "N/A", 0 end
    local seen = {}
    for _, row in pairs(session.seen or {}) do
        seen[#seen + 1] = { name = row.name or "Mechanic", count = tonumber(row.count) or 0, hits = tonumber(row.hits) or 0 }
    end
    table.sort(seen, function(a, b)
        if a.hits ~= b.hits then return a.hits > b.hits end
        return a.count > b.count
    end)
    while #seen > 10 do table.remove(seen) end
    return {
        bossName = session.bossName or "Boss", activityName = session.activityName or "",
        alerts = session.alerts or 0, avoidableHits = session.avoidableHits or 0, cleanAvoids = session.cleanAvoids or 0,
        interruptRequired = session.interruptRequired or 0, interruptSuccess = session.interruptSuccess or 0,
        blockRequired = session.blockRequired or 0, blockSuccess = session.blockSuccess or 0,
        dodgeRequired = session.dodgeRequired or 0, dodgeSuccess = session.dodgeSuccess or 0,
        score = score, grade = grade, hmDetected = self.hmDetected == true, seen = seen,
    }
end

function M:AttachFightData(fight)
    if type(fight) ~= "table" or not self.session then return end
    self:FinalizePending(true)
    fight.bossMechanics = self:BuildSessionSummary()
    self.session.attached = true
end

function M:GetLiveSummary()
    if not self.session then return nil end
    return self:BuildSessionSummary()
end

function M:OnCombatState(inCombat)
    inCombat = inCombat == true
    self.inCombat = inCombat
    if inCombat then
        self:ScanBosses()
        local boss = self.currentBoss and self.currentBoss.ref and self.currentBoss.ref.boss or nil
        if boss then self:CreateSession(boss) else self.session = nil end
        self.hmDetected = false
    else
        self:FinalizePending(true)
        self.lastSessionSummary = self:BuildSessionSummary()
        self.session = nil
        self.currentAlert = nil
        self.lastMechanicKey = nil
        self.lastMechanicAt = nil
        self.lastHealthBucket = nil
        self.hmDetected = false
    end
    self:Refresh()
end

function M:RoleHint(mechanic)
    local roleKey = self:GetRoleKey()
    local flags = mechanic and mechanic.roles and mechanic.roles[roleKey] or {}
    local phrases = {}
    local function add(v)
        if v and v ~= "" then
            for _, existing in ipairs(phrases) do if existing == v then return end end
            phrases[#phrases + 1] = v
        end
    end

    if roleKey == "tank" then
        if has(flags, "TAUNT") then add("TAUNT / CONTROL") end
        if has(flags, "FACE_AWAY") then add("FACE AWAY") end
        if has(flags, "SOAK") then add("SOAK / HOLD") end
        if has(flags, "STACK_ADDS") then add("STACK ADDS") end
        if has(flags, "HOLD_CENTER") then add("HOLD CENTER") end
        if has(flags, "BLOCK") then add("BLOCK") end
    elseif roleKey == "healer" then
        if has(flags, "PREHOT") then add("PRE-HOT") end
        if has(flags, "BURST_HEAL") then add("BURST HEAL") end
        if has(flags, "CLEANSE") then add("CLEANSE") end
        if has(flags, "MITIGATE") then add("MITIGATION") end
        if has(flags, "INTERRUPT") then add("INTERRUPT") end
    else
        if has(flags, "FOCUS_ADDS") or has(flags, "FOCUS_PRIORITY") then add("FOCUS PRIORITY") end
        if has(flags, "BURN") then add("BURN") end
        if has(flags, "INTERRUPT") then add("INTERRUPT") end
        if has(flags, "STOP_DAMAGE") then add("STOP DAMAGE") end
        if has(flags, "CLEAVE") then add("CLEAVE") end
    end
    return joinLimited(phrases, "  •  ", 2)
end

function M:PrePullMechanics(boss)
    local choices = {}
    for _, mechanic in ipairs(boss and boss.mechanics or {}) do
        if not mechanic.hmOnly or self.hmDetected then choices[#choices + 1] = mechanic end
    end
    table.sort(choices, function(a, b)
        if (a.priority or 0) ~= (b.priority or 0) then return (a.priority or 0) > (b.priority or 0) end
        return tostring(a.short or a.name) < tostring(b.short or b.name)
    end)
    local names = {}
    for i = 1, math.min(3, #choices) do names[#names + 1] = choices[i].short or choices[i].name end
    return table.concat(names, "  •  ")
end

function M:LayoutForSize029203()
    if not self.frame then return end
    local w, h = self.frame:GetDimensions()
    w = clamp029203(w, BOSS_MIN_W029203, BOSS_MAX_W029203)
    h = clamp029203(h, BOSS_MIN_H029203, BOSS_MAX_H029203)
    local sx, sy = w / BOSS_BASE_W029203, h / BOSS_BASE_H029203
    local contentScale = clamp029203(math.min(sx, sy), 0.70, 1.75)
    local leftPad = math.max(10, math.floor(16 * sx + 0.5))
    local rightPad = leftPad
    local innerW = math.max(100, w - leftPad - rightPad)

    local titleY = math.floor(7 * sy + 0.5)
    local dividerY = math.floor(31 * sy + 0.5)
    local actionY = math.floor(38 * sy + 0.5)
    local mechanicY = math.floor(77 * sy + 0.5)
    local positionY = math.floor(101 * sy + 0.5)
    local nextY = math.floor(127 * sy + 0.5)

    if self.accent then self.accent:SetWidth(math.max(4, math.floor(5 * contentScale + 0.5))) end
    if self.titleLabel then
        self.titleLabel:ClearAnchors()
        self.titleLabel:SetAnchor(TOPLEFT, self.frame, TOPLEFT, leftPad, titleY)
        self.titleLabel:SetDimensions(math.floor(innerW * 0.48), math.max(18, dividerY - titleY - 2))
        self.titleLabel:SetFont(font029203("bold", 16 * contentScale))
    end
    if self.bossLabel then
        self.bossLabel:ClearAnchors()
        self.bossLabel:SetAnchor(TOPRIGHT, self.frame, TOPRIGHT, -rightPad, titleY + 1)
        self.bossLabel:SetDimensions(math.floor(innerW * 0.50), math.max(18, dividerY - titleY - 2))
        self.bossLabel:SetFont(font029203("regular", 14 * contentScale))
    end
    if self.divider029203 then
        self.divider029203:ClearAnchors()
        self.divider029203:SetAnchor(TOPLEFT, self.frame, TOPLEFT, math.max(8, leftPad - 4), dividerY)
        self.divider029203:SetAnchor(TOPRIGHT, self.frame, TOPRIGHT, -math.max(8, rightPad - 4), dividerY)
        self.divider029203:SetHeight(math.max(1, math.floor(contentScale + 0.5)))
    end
    if self.actionLabel then
        self.actionLabel:ClearAnchors()
        self.actionLabel:SetAnchor(TOPLEFT, self.frame, TOPLEFT, leftPad, actionY)
        self.actionLabel:SetDimensions(innerW, math.max(24, mechanicY - actionY - 2))
        self.actionLabel:SetFont(font029203("bold", 25 * contentScale))
        self.actionLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if self.mechanicLabel then
        self.mechanicLabel:ClearAnchors()
        self.mechanicLabel:SetAnchor(TOPLEFT, self.frame, TOPLEFT, leftPad, mechanicY)
        self.mechanicLabel:SetDimensions(innerW, math.max(18, positionY - mechanicY - 2))
        self.mechanicLabel:SetFont(font029203("bold", 17 * contentScale))
        self.mechanicLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if self.positionLabel then
        self.positionLabel:ClearAnchors()
        self.positionLabel:SetAnchor(TOPLEFT, self.frame, TOPLEFT, leftPad, positionY)
        self.positionLabel:SetDimensions(innerW, math.max(18, nextY - positionY - 2))
        self.positionLabel:SetFont(font029203("regular", 16 * contentScale))
        self.positionLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if self.nextLabel then
        self.nextLabel:ClearAnchors()
        self.nextLabel:SetAnchor(TOPLEFT, self.frame, TOPLEFT, leftPad, nextY)
        self.nextLabel:SetDimensions(innerW, math.max(16, h - nextY - math.max(4, math.floor(5 * sy))))
        self.nextLabel:SetFont(font029203("regular", 13 * contentScale))
        self.nextLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
end

function M:CreateUI()
    if self.frame then return end
    local frame = wm:CreateTopLevelWindow("EAS_BossMechanicsCoach029198")
    local savedWidth = EPC.saved and tonumber(EPC.saved.bossMechanicsWidth029203) or BOSS_BASE_W029203
    local savedHeight = EPC.saved and tonumber(EPC.saved.bossMechanicsHeight029203) or BOSS_BASE_H029203
    savedWidth = clamp029203(savedWidth, BOSS_MIN_W029203, BOSS_MAX_W029203)
    savedHeight = clamp029203(savedHeight, BOSS_MIN_H029203, BOSS_MAX_H029203)
    frame:SetDimensions(savedWidth, savedHeight)
    if frame.SetDimensionConstraints then
        frame:SetDimensionConstraints(BOSS_MIN_W029203, BOSS_MIN_H029203, BOSS_MAX_W029203, BOSS_MAX_H029203)
    end
    if frame.SetResizeHandleSize then frame:SetResizeHandleSize(0) end
    local savedLeft = EPC.saved and tonumber(EPC.saved.bossMechanicsLeft029198) or -1
    local savedTop = EPC.saved and tonumber(EPC.saved.bossMechanicsTop029198) or -1
    if savedLeft and savedLeft >= 0 and savedTop and savedTop >= 0 then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedLeft, savedTop)
    else
        frame:SetAnchor(TOP, GuiRoot, TOP, 0, 125)
    end
    frame:SetScale(EPC.saved and tonumber(EPC.saved.bossMechanicsScale029198) or 1.0)
    frame:SetAlpha(EPC.saved and tonumber(EPC.saved.bossMechanicsAlpha029198) or 0.97)
    frame:SetDrawTier(DT_HIGH)
    frame:SetDrawLayer(DL_OVERLAY)
    frame:SetDrawLevel(310)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame:SetHidden(true)
    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.bossMechanicsLeft029198 = math.floor(control:GetLeft() or 0)
            EPC.saved.bossMechanicsTop029198 = math.floor(control:GetTop() or 0)
        end
    end)
    frame:SetHandler("OnResizeStart", function(control)
        self.resizing029203 = true
        control:SetHandler("OnUpdate", function()
            if self.resizing029203 then self:LayoutForSize029203() end
        end)
    end)
    frame:SetHandler("OnResizeStop", function(control)
        self.resizing029203 = false
        control:SetHandler("OnUpdate", nil)
        local w, h = control:GetDimensions()
        w = math.floor(clamp029203(w, BOSS_MIN_W029203, BOSS_MAX_W029203) + 0.5)
        h = math.floor(clamp029203(h, BOSS_MIN_H029203, BOSS_MAX_H029203) + 0.5)
        control:SetDimensions(w, h)
        if EPC.saved then
            EPC.saved.bossMechanicsWidth029203 = w
            EPC.saved.bossMechanicsHeight029203 = h
        end
        self:LayoutForSize029203()
    end)

    local bg = makeBackdrop(frame)
    bg:SetAnchorFill(frame)
    local accent = wm:CreateControl(nil, frame, CT_BACKDROP)
    accent:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    accent:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    accent:SetWidth(5)
    accent:SetCenterColor(1, 0.82, 0.28, 1)
    accent:SetEdgeColor(0, 0, 0, 0)

    local title = makeLabel(frame, "ZoFontGameBold", 1, 0.83, 0.32, 1)
    title:SetText("BOSS MECHANICS COACH")

    local boss = makeLabel(frame, "ZoFontGameSmall", 0.78, 0.82, 0.90, 1)
    boss:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local divider = wm:CreateControl(nil, frame, CT_BACKDROP)
    divider:SetCenterColor(0.24, 0.28, 0.36, 0.9)
    divider:SetEdgeColor(0, 0, 0, 0)

    local action = makeLabel(frame, "ZoFontWindowTitle", 1, 1, 1, 1)
    action:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local mechanic = makeLabel(frame, "ZoFontGameBold", 0.94, 0.95, 0.98, 1)
    mechanic:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local position = makeLabel(frame, "ZoFontGame", 0.90, 0.80, 0.42, 1)
    position:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local nextLine = makeLabel(frame, "ZoFontGameSmall", 0.66, 0.73, 0.84, 1)
    nextLine:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.frame, self.bg, self.accent, self.divider029203 = frame, bg, accent, divider
    self.titleLabel, self.bossLabel, self.actionLabel = title, boss, action
    self.mechanicLabel, self.positionLabel, self.nextLabel = mechanic, position, nextLine
    self:LayoutForSize029203()
end

function M:SetAccent(priority)
    local color = PRIORITY_COLORS[tonumber(priority) or 3] or PRIORITY_COLORS[3]
    if self.accent then self.accent:SetCenterColor(unpack(color)) end
    if self.actionLabel then self.actionLabel:SetColor(unpack(color)) end
end

function M:IsSuppressed()
    if self.layoutMode then return false end
    if EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true then return true end
    return false
end

function M:TriggerReaction029203(action, detail, durationMs, priority)
    action = string.upper(tostring(action or ""))
    if action == "" then return end
    if self:IsHandlingAction(action) then return end
    self.genericReaction029203 = {
        action = action, detail = clean((detail ~= nil and tostring(detail) ~= "") and detail or (action .. " NOW")),
        expiresAt = nowMs() + (tonumber(durationMs) or 1800), priority = tonumber(priority) or 5,
    }
    self:Refresh()
end

function M:Refresh()
    self:CreateUI()
    if not self.frame then return end
    self:LayoutForSize029203()
    if self:IsSuppressed() then self.frame:SetHidden(true) return end

    local at = nowMs()
    local reaction = self.genericReaction029203
    local reactionActive = reaction and at <= (tonumber(reaction.expiresAt) or 0)
    if reaction and not reactionActive then self.genericReaction029203 = nil reaction = nil end

    local bossEnabled = not (EPC.saved and EPC.saved.bossMechanicsEnabled029198 == false)
    if not bossEnabled and not reactionActive and not self.layoutMode then
        self.frame:SetHidden(true)
        return
    end

    local roleKey, roleDisplay = self:GetRoleKey()
    if self.layoutMode then
        self.frame:SetHidden(false)
        self:SetAccent(5)
        self.titleLabel:SetText("BOSS MECHANICS + REACTIONS  •  " .. roleDisplay)
        self.bossLabel:SetText("HUD LAYOUT PREVIEW")
        self.actionLabel:SetText(self:FormatActions029199({ "BLOCK", "INTERRUPT" }, 3))
        self.mechanicLabel:SetText("One panel for boss mechanics and combat reactions")
        self.positionLabel:SetText("POSITION: OUTER EDGE  •  ROLE: " .. (roleKey == "tank" and "FACE AWAY" or (roleKey == "healer" and "PRE-HOT" or "FOCUS PRIORITY")))
        self.nextLabel:SetText("DRAG TO MOVE  •  DRAG EDGES/CORNERS TO RESIZE")
        return
    end

    local bossRow = self.currentBoss
    local boss = bossRow and bossRow.ref and bossRow.ref.boss or nil
    local visibility = EPC.saved and tostring(EPC.saved.bossMechanicsVisibility029204 or "MECHANIC") or "MECHANIC"
    local alert = self.currentAlert
    local alertActive = bossEnabled and alert and at <= (tonumber(alert.expiresAt) or 0)
    local prePull = bossEnabled and boss and not self.inCombat and EPC.saved and EPC.saved.bossMechanicsPrePull029204 == true
    local showBossState = bossEnabled and boss and self.inCombat and (visibility == "BOSS" or visibility == "COMBAT" or visibility == "ALWAYS")
    local showCombatState = bossEnabled and self.inCombat and (visibility == "COMBAT" or visibility == "ALWAYS")
    local showAlwaysState = bossEnabled and visibility == "ALWAYS"

    -- A specific boss mechanic always wins. Otherwise the same panel becomes the
    -- generic combat-reaction warning (BLOCK, DODGE, INTERRUPT, etc.).
    if not alertActive and reactionActive then
        self.frame:SetHidden(false)
        self:SetAccent(reaction.priority or 5)
        self.titleLabel:SetText((boss and "BOSS MECHANICS + REACTIONS" or "COMBAT REACTION") .. "  •  " .. roleDisplay)
        if boss then
            local health = bossRow and bossRow.tag and self:GetBossHealthPercent(bossRow.tag) or bossRow.health
            bossRow.health = health
            self.bossLabel:SetText(string.format("%s  •  %s%s", boss.name, health and string.format("%.0f%%", health) or "BOSS", self.hmDetected and "  •  HM" or ""))
        else
            self.bossLabel:SetText("INCOMING ATTACK")
        end
        self.actionLabel:SetText(self:ActionPrompt029199(reaction.action))
        self.mechanicLabel:SetText(reaction.detail ~= "" and reaction.detail or (reaction.action .. " NOW"))
        self.positionLabel:SetText("REACTION: " .. reaction.action)
        self.nextLabel:SetText(boss and "Boss coach remains active after this reaction" or "Live combat reaction guidance")
        local pulse = 0.78 + 0.22 * math.abs(math.sin(at / 105))
        self.frame:SetAlpha((EPC.saved and tonumber(EPC.saved.bossMechanicsAlpha029198) or 0.97) * pulse)
        return
    end

    -- No supported boss is currently resolved. COMBAT and ALWAYS modes may still
    -- keep the unified reaction panel available as a low-noise status surface.
    if not boss then
        if not alertActive and not showCombatState and not showAlwaysState then
            self.frame:SetHidden(true)
            return
        end

        self.frame:SetHidden(false)
        self:SetAccent(self.inCombat and 2 or 1)
        self.titleLabel:SetText("BOSS MECHANICS + REACTIONS  •  " .. roleDisplay)
        if self.inCombat then
            self.bossLabel:SetText("COMBAT ACTIVE")
            self.actionLabel:SetText("WATCHING FOR REACTIONS")
            self.mechanicLabel:SetText("Waiting for a block, interrupt, dodge, or recognized boss mechanic")
            self.positionLabel:SetText("ROLE: " .. roleDisplay .. "  •  No supported boss mechanic active")
            self.nextLabel:SetText("Panel hides automatically when your selected visibility mode allows it")
        else
            self.bossLabel:SetText("READY")
            self.actionLabel:SetText("NO ACTIVE MECHANIC")
            self.mechanicLabel:SetText("Boss Mechanics / Combat Reaction coach is standing by")
            self.positionLabel:SetText("ROLE: " .. roleDisplay)
            self.nextLabel:SetText("Visibility: Always")
        end
        self.frame:SetAlpha(EPC.saved and tonumber(EPC.saved.bossMechanicsAlpha029198) or 0.97)
        return
    end

    if not alertActive and not prePull and not showBossState and not showAlwaysState then
        self.frame:SetHidden(true)
        return
    end

    self.frame:SetHidden(false)
    local health = bossRow and bossRow.tag and self:GetBossHealthPercent(bossRow.tag) or bossRow.health
    bossRow.health = health
    local healthText = health and string.format("%.0f%%", health) or "BOSS"
    self.titleLabel:SetText("BOSS MECHANICS + REACTIONS  •  " .. roleDisplay)
    self.bossLabel:SetText(string.format("%s  •  %s%s", boss.name, healthText, self.hmDetected and "  •  HM" or ""))

    if alertActive then
        local mechanic = alert.mechanic
        self:SetAccent(mechanic.priority or 3)
        local action = self:FormatActions029199(mechanic.actions or {}, 3)
        if action == "" then action = "MECHANIC NOW" end
        self.actionLabel:SetText(action)
        self.mechanicLabel:SetText(mechanic.short or mechanic.name or alert.abilityName or "Boss mechanic")
        local position = joinLimited(mechanic.positions or {}, "  +  ", 2)
        local roleHint = EPC.saved and EPC.saved.bossMechanicsRoleAware029198 == false and "" or self:RoleHint(mechanic)
        local positionParts = {}
        if position ~= "" then positionParts[#positionParts + 1] = "POSITION: " .. position end
        if roleHint ~= "" then positionParts[#positionParts + 1] = "ROLE: " .. roleHint end
        self.positionLabel:SetText(#positionParts > 0 and table.concat(positionParts, "  •  ") or "FOLLOW THE MECHANIC")
    elseif prePull then
        self:SetAccent(3)
        self.actionLabel:SetText("PRE-PULL CHECK")
        self.mechanicLabel:SetText(self:PrePullMechanics(boss))
        self.positionLabel:SetText("ROLE: " .. roleDisplay .. "  •  Ready for encounter-specific callouts")
    elseif self.inCombat then
        self:SetAccent(2)
        self.actionLabel:SetText("BOSS ACTIVE")
        self.mechanicLabel:SetText("Watching casts, phase pressure, and dangerous mechanics")
        self.positionLabel:SetText("PHASE: " .. self:HealthBucket() .. "  •  ROLE: " .. roleDisplay)
    else
        self:SetAccent(1)
        self.actionLabel:SetText("BOSS NEARBY")
        self.mechanicLabel:SetText("No active mechanic")
        self.positionLabel:SetText("ROLE: " .. roleDisplay .. "  •  Visibility: Always")
    end

    local prediction = self:GetPrediction(boss)
    if prediction then
        self.nextLabel:SetText(string.format("LIKELY NEXT: %s  •  ~%.1fs learned timing  •  %.0f%% confidence (%d samples)",
            prediction.mechanic.short or prediction.mechanic.name, prediction.seconds or 0, (prediction.confidence or 0) * 100, prediction.samples or 0))
    elseif EPC.saved and EPC.saved.bossMechanicsPredictionEnabled029198 ~= false then
        self.nextLabel:SetText("NEXT MECHANIC: learning this boss from repeated pulls")
    else
        self.nextLabel:SetText("LIVE encounter guidance")
    end

    if alertActive and (alert.priority or 0) >= 5 then
        local pulse = 0.83 + 0.17 * math.abs(math.sin(at / 115))
        self.frame:SetAlpha((EPC.saved and tonumber(EPC.saved.bossMechanicsAlpha029198) or 0.97) * pulse)
    else
        self.frame:SetAlpha(EPC.saved and tonumber(EPC.saved.bossMechanicsAlpha029198) or 0.97)
    end
end

function M:SetLayoutMode(active)
    self:CreateUI()
    active = active == true
    self.layoutMode = active
    self.frame:SetMouseEnabled(active)
    self.frame:SetMovable(active)
    if self.frame.SetResizeHandleSize then self.frame:SetResizeHandleSize(active and 24 or 0) end
    if self.bg then
        if active then self.bg:SetEdgeColor(1, 0.82, 0.28, 1) else self.bg:SetEdgeColor(0.33, 0.37, 0.46, 0.92) end
    end
    self:Refresh()
end

function M:RaiseForLayout()
    if not self.frame then return end
    self.frame:SetTopLevel(true)
    self.frame:SetDrawTier(DT_HIGH)
    self.frame:SetDrawLayer(DL_OVERLAY)
    self.frame:SetDrawLevel(950)
    if self.frame.BringWindowToTop then self.frame:BringWindowToTop() end
end

function M:ResetPosition()
    self:CreateUI()
    self.frame:ClearAnchors()
    self.frame:SetAnchor(TOP, GuiRoot, TOP, 0, 125)
    if EPC.saved then
        EPC.saved.bossMechanicsLeft029198 = -1
        EPC.saved.bossMechanicsTop029198 = -1
    end
end

function M:SetSize029203(width, height)
    self:CreateUI()
    width = math.floor(clamp029203(width or (select(1, self.frame:GetDimensions())), BOSS_MIN_W029203, BOSS_MAX_W029203) + 0.5)
    height = math.floor(clamp029203(height or (select(2, self.frame:GetDimensions())), BOSS_MIN_H029203, BOSS_MAX_H029203) + 0.5)
    self.frame:SetDimensions(width, height)
    if EPC.saved then
        EPC.saved.bossMechanicsWidth029203 = width
        EPC.saved.bossMechanicsHeight029203 = height
    end
    self:LayoutForSize029203()
end

function M:ResetSize029203()
    self:SetSize029203(BOSS_BASE_W029203, BOSS_BASE_H029203)
end

function M:ApplyScale()
    if self.frame and EPC.saved then
        self.frame:SetScale(tonumber(EPC.saved.bossMechanicsScale029198) or 1.0)
        self.frame:SetAlpha(tonumber(EPC.saved.bossMechanicsAlpha029198) or 0.97)
        self:LayoutForSize029203()
    end
end

function M:IsHandlingAction(action)
    action = string.upper(tostring(action or ""))
    if action == "" then return false end
    if self.currentAlert and nowMs() <= (tonumber(self.currentAlert.expiresAt) or 0)
        and containsAction(self.currentAlert.mechanic, action) then return true end
    local reaction = self.genericReaction029203
    return reaction ~= nil and nowMs() <= (tonumber(reaction.expiresAt) or 0)
        and string.upper(tostring(reaction.action or "")) == action
end

function M:RegisterCombatEvents()
    if not EVENT_COMBAT_EVENT or not EVENT_MANAGER then return end
    local prefix = EPC.name .. "_BossMechanics029198_"

    local function callback(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
        if ACTION_RESULT_BEGIN ~= nil and result == ACTION_RESULT_BEGIN then
            self:OnBeginEvent(abilityName, abilityActionSlotType, sourceName, targetName, abilityId)
        else
            self:OnResultEvent(result, abilityName, sourceName, targetName, abilityId)
        end
    end

    local function register(suffix, result, targetPlayer)
        if result == nil or REGISTER_FILTER_COMBAT_RESULT == nil then return end
        local name = prefix .. suffix
        local filters = { { REGISTER_FILTER_COMBAT_RESULT, result } }
        if REGISTER_FILTER_IS_ERROR then filters[#filters + 1] = { REGISTER_FILTER_IS_ERROR, false } end
        if targetPlayer and REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER ~= nil then
            filters[#filters + 1] = { REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER }
        end
        EPC.Runtime:RegisterEvent("BossMechanicsAssistant", suffix, EVENT_COMBAT_EVENT, callback, filters)
    end

    register("Begin", ACTION_RESULT_BEGIN, false)
    register("Interrupt", ACTION_RESULT_INTERRUPT, false)
    register("BreakFree", ACTION_RESULT_BREAK_FREE, false)
    register("BlockedDamage", ACTION_RESULT_BLOCKED_DAMAGE, true)
    register("Blocked", ACTION_RESULT_BLOCKED, true)
    register("Dodged", ACTION_RESULT_DODGED, true)
    register("Damage", ACTION_RESULT_DAMAGE, true)
    register("CriticalDamage", ACTION_RESULT_CRITICAL_DAMAGE, true)
    register("Shielded", ACTION_RESULT_DAMAGE_SHIELDED, true)
    register("Dot", ACTION_RESULT_DOT_TICK, true)
    register("DotCritical", ACTION_RESULT_DOT_TICK_CRITICAL, true)
    register("EffectGained", ACTION_RESULT_EFFECT_GAINED, true)
    register("EffectGainedDuration", ACTION_RESULT_EFFECT_GAINED_DURATION, true)
end

function M:Initialize()
    self:EnsureSaved()
    self:BuildIndexes()
    self.inCombat = safe(IsUnitInCombat, false, "player") == true
    self.activeBosses = {}
    self.currentBoss = nil
    self.currentAlert = nil
    self.genericReaction029203 = nil
    self.layoutMode = false
    self:CreateUI()
    self:RegisterCombatEvents()

    local prefix = EPC.name .. "_BossMechanics029198"
    if EVENT_BOSSES_CHANGED then
        EPC.Runtime:RegisterEvent("BossMechanicsAssistant", "Bosses", EVENT_BOSSES_CHANGED, function() self:ScanBosses() end)
    end
    if EVENT_RETICLE_TARGET_CHANGED then
        EPC.Runtime:RegisterEvent("BossMechanicsAssistant", "Reticle", EVENT_RETICLE_TARGET_CHANGED, function()
            if not self.currentBoss or #(self.activeBosses or {}) == 0 then self:ScanBosses() end
        end)
    end
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("BossMechanicsAssistant", "Activated", EVENT_PLAYER_ACTIVATED, function() self:ScanBosses() end)
    end
    EPC.Runtime:RegisterUpdate("BossMechanicsAssistant", "Tick", 250, function()
        -- v0.29.341: keep the combat cadence, but make the callback effectively
        -- dormant during ordinary roaming. Boss/reticle events wake the feature
        -- immediately; there is no reason to run pending-mechanic work at 4 Hz
        -- when no encounter, alert, or layout preview exists.
        if not self.inCombat and not self.currentBoss and not self.currentAlert
            and not self.genericReaction029203 and not self.layoutMode then return end
        self:FinalizePending(false)
        if self.currentBoss and self.currentBoss.tag then
            self.currentBoss.health = self:GetBossHealthPercent(self.currentBoss.tag) or self.currentBoss.health
        end
        if self.currentBoss or self.currentAlert or self.genericReaction029203 or self.layoutMode then self:Refresh() end
    end)
    self:ScanBosses()
end
