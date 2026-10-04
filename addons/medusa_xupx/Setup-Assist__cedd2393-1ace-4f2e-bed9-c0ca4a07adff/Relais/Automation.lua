-- Relais: contextual rules. The observation is always refreshed before a swap.
local R = Relais
local POLL_MS = 250
local STABLE_MS = 600
local NO_BOSS_MS = 3000
local POINT_RADIUS = 1200 -- Raw level coordinates use centimetres.
local POINT_EXIT_FACTOR = 1.25
local POINT_HEIGHT = 200 -- Y is the vertical axis; avoid nearby points on another floor.
local MAX_POINTS = 128
local MAX_POINT_ID = 2147483647
local NATIVE_DUNGEON_BOSS = "Boss du donjon signalé par ESO"

local function SavedDataChanged(self)
    if type(self.SavedDataChanged) == "function" then self:SavedDataChanged() end
end

local function Now()
    return GetFrameTimeMilliseconds()
end

local function Finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function ZoneIdentifier(value)
    return Finite(value) and value > 0 and value == math.floor(value)
end

local function ReadBoolean(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, value = pcall(api, ...)
    if ok and type(value) == "boolean" then return value end
end

local function Activity()
    local combat = ReadBoolean(IsUnitInCombat, "player")
    local dead = ReadBoolean(IsUnitDeadOrReincarnating, "player")
    if combat == nil or dead == nil then return nil, nil, "Le personnage n’est pas encore prêt. Changements automatiques en pause." end
    return combat, dead
end

local function GroupActivity()
    if type(GetGroupSize) ~= "function" or type(GetGroupUnitTagByIndex) ~= "function" then
        return nil, "Informations du groupe en attente. Setup de zone en pause."
    end
    local ok, size = pcall(GetGroupSize)
    if not ok or not Finite(size) or size < 0 or size ~= math.floor(size) or size > 24 then
        return nil, "Informations du groupe en attente. Setup de zone en pause."
    end
    for index = 1, size do
        local tagOK, tag = pcall(GetGroupUnitTagByIndex, index)
        if not tagOK or type(tag) ~= "string" or tag == "" then
            return nil, "Informations du groupe en attente. Setup de zone en pause."
        end
        local inCombat = ReadBoolean(IsUnitInCombat, tag)
        if inCombat == nil then return nil, "Informations du groupe en attente. Setup de zone en pause." end
        if inCombat then return true end
    end
    return false
end

local function ZoneFallbackProblem()
    local combat, problem = GroupActivity()
    return problem or (combat and "Le groupe est encore en combat. Setup de zone en attente." or nil)
end

local function DisplayName(name)
    if type(name) ~= "string" or name == "" then return "" end
    local ok, display = pcall(zo_strformat, SI_UNIT_NAME, name)
    return ok and type(display) == "string" and display or ""
end

function R:NormalizeBossName(name)
    local ok, normalized = pcall(zo_strlower, DisplayName(name))
    return ok and type(normalized) == "string" and normalized or ""
end

function R:GetZoneId()
    if type(GetUnitZoneIndex) ~= "function" or type(GetZoneId) ~= "function" then return 0 end
    local indexOK, zoneIndex = pcall(GetUnitZoneIndex, "player")
    if not indexOK or not ZoneIdentifier(zoneIndex) then return 0 end
    local zoneOK, zoneId = pcall(GetZoneId, zoneIndex)
    return zoneOK and ZoneIdentifier(zoneId) and zoneId or 0
end

function R:GetZoneLabel()
    local zoneId = self:GetZoneId()
    if zoneId == 0 then return "Zone indisponible" end
    local ok, name = pcall(GetZoneNameById, zoneId)
    local display = ok and DisplayName(name) or ""
    return display ~= "" and display or "Zone actuelle"
end

function R:GetPlayerPosition()
    if not self.automation or not self.automation.worldReady then
        return nil, "Position indisponible pendant le chargement."
    end
    if type(IsPlayerActivated) == "function" then
        local activatedOK, activated = pcall(IsPlayerActivated)
        if not activatedOK or activated ~= true then return nil, "Position indisponible pendant le chargement." end
    end
    if type(GetUnitRawWorldPosition) ~= "function" then
        return nil, "Les points de passage ne sont pas disponibles sur cette version du jeu."
    end
    local zoneOK, zoneId = pcall(self.GetZoneId, self)
    if not zoneOK or not ZoneIdentifier(zoneId) then
        return nil, "La zone du personnage est indisponible."
    end
    local success, worldZoneId, x, y, z = pcall(GetUnitRawWorldPosition, "player")
    if not success then return nil, "Le jeu n’a pas fourni la position du personnage." end
    if not ZoneIdentifier(worldZoneId) or not Finite(x) or not Finite(y) or not Finite(z) then
        return nil, "La position du personnage n’est pas disponible."
    end
    -- The logical zone and the raw coordinate-space zone are independent keys.
    return { zoneId = zoneId, worldZoneId = worldZoneId, coordinateSpace = "raw", x = x, y = y, z = z }
end

local function BossTags()
    local tags = {}
    local first, last = BOSS_RANK_ITERATION_BEGIN or 1, BOSS_RANK_ITERATION_END or MAX_BOSSES or 6
    if not ZoneIdentifier(first) or not ZoneIdentifier(last) or first > last or last > 16 then first, last = 1, 8 end
    for index = first, last do
        tags[#tags + 1] = "boss" .. tostring(index)
    end
    return tags
end

function R:GetTargetBossName()
    if ReadBoolean(DoesUnitExist, "reticleover") ~= true or ReadBoolean(IsUnitAttackable, "reticleover") ~= true or ReadBoolean(IsUnitDead, "reticleover") ~= false then
        return nil
    end
    local targetOK, targetName = pcall(GetUnitName, "reticleover")
    local target = targetOK and self:NormalizeBossName(targetName) or ""
    if target == "" then return nil end
    for _, tag in ipairs(BossTags()) do
        if ReadBoolean(DoesUnitExist, tag) == true and ReadBoolean(IsUnitDead, tag) == false then
            local nameOK, bossName = pcall(GetUnitName, tag)
            if nameOK and (ReadBoolean(AreUnitsEqual, "reticleover", tag) == true or target == self:NormalizeBossName(bossName)) then
                return DisplayName(bossName)
            end
        end
    end
    -- Monster difficulty alone does not distinguish bosses from elite enemies.
    return nil
end

function R:GetObservedBossNames()
    local names, seen, deadNames, slots = {}, {}, {}, {}
    for _, tag in ipairs(BossTags()) do
        local exists = ReadBoolean(DoesUnitExist, tag)
        if exists == nil then return {}, "Reconnaissance des boss en attente." end
        if exists then
            local isDead = ReadBoolean(IsUnitDead, tag)
            if isDead == nil then return {}, "Reconnaissance des boss en attente." end
            local nameOK, name = pcall(GetUnitName, tag)
            local display = nameOK and DisplayName(name) or ""
            local key = self:NormalizeBossName(display)
            if not isDead and key == "" then return {}, "Un boss apparaît. Attente de sa reconnaissance." end
            if not isDead and key ~= "" and not seen[key] then
                seen[key] = true
                names[#names + 1] = display
            end
            if isDead and key ~= "" then deadNames[#deadNames + 1] = display end
            if key ~= "" then slots[tag .. "\031" .. key] = { key = key, name = display, dead = isDead } end
        end
    end
    table.sort(names, function(a, b) return self:NormalizeBossName(a) < self:NormalizeBossName(b) end)
    return names, nil, deadNames, slots
end

local function RecoverRule(self, path, value)
    if type(self.db.recoveredRules) ~= "table" then
        self.db.recoveredRules = { previous = self.db.recoveredRules }
    end
    self.db.recoveredRules[#self.db.recoveredRules + 1] = { path = path, value = value }
    self.db.settings.automatic = false
    self.automationDataDirty = true
    self.automationDataMessage = "Certaines associations ne pouvaient pas être lues. Elles ont été conservées à part ; vérifie tes associations avant de réactiver l’automatique."
end

local function SetupIdentifier(value)
    return ZoneIdentifier(value) or (type(value) == "string" and value ~= "")
end

local function AllocatePointId(rules, used)
    local number = rules.nextPointId
    while used["point:" .. tostring(number)] do number = number >= MAX_POINT_ID and 1 or number + 1 end
    local id = "point:" .. tostring(number)
    used[id] = true
    rules.nextPointId = number >= MAX_POINT_ID and 1 or number + 1
    return id
end

local function EnsureRules(self)
    -- Core repairs settings and profiles before initialization. The guards also
    -- cover a saved-variable edit or damaged rule discovered after startup.
    if type(self.db.settings) ~= "table" then self.db.settings = { automatic = false } self.automationDataDirty = true end
    if type(self.db.rules) ~= "table" then
        if self.db.rules ~= nil then RecoverRule(self, "rules", self.db.rules) end
        self.db.rules = {}
        self.automationDataDirty = true
    end
    local rules = self.db.rules
    for _, name in ipairs({ "zones", "bosses", "positions", "trashAfterBosses" }) do
        if type(rules[name]) ~= "table" then
            if rules[name] ~= nil then RecoverRule(self, name, rules[name]) end
            rules[name] = {}
            self.automationDataDirty = true
        end
    end
    for zoneId, id in pairs(rules.zones) do
        if not ZoneIdentifier(zoneId) or not SetupIdentifier(id) then
            RecoverRule(self, "zones", { zoneId = zoneId, profileId = id })
            rules.zones[zoneId] = nil
        end
    end
    for _, mapName in ipairs({ "bosses", "trashAfterBosses" }) do
    for zoneId, associations in pairs(rules[mapName]) do
        if not ZoneIdentifier(zoneId) or type(associations) ~= "table" then
            RecoverRule(self, mapName, { zoneId = zoneId, associations = associations })
            rules[mapName][zoneId] = nil
        else
            for name, id in pairs(associations) do
                if type(name) ~= "string" or name == "" or not SetupIdentifier(id) then
                    RecoverRule(self, mapName, { zoneId = zoneId, name = name, profileId = id })
                    associations[name] = nil
                end
            end
        end
    end
    end
    -- ipairs would silently hide every point following the first array hole.
    local keys, positions = {}, rules.positions
    for key, point in pairs(positions) do
        if ZoneIdentifier(key) and type(point) == "table" and ZoneIdentifier(point.zoneId) and SetupIdentifier(point.profileId) then keys[#keys + 1] = key
        else
            RecoverRule(self, "positions", { key = key, point = point })
            positions[key] = nil
        end
    end
    table.sort(keys)
    local compact = {}
    for _, key in ipairs(keys) do compact[#compact + 1] = positions[key] end
    local dense = #keys == #positions
    for index, key in ipairs(keys) do if key ~= index then dense = false break end end
    if not dense then
        for key in pairs(positions) do positions[key] = nil end
        for index, point in ipairs(compact) do positions[index] = point end
        self.automationDataDirty = true
    end
    if not ZoneIdentifier(rules.nextPointId) or rules.nextPointId > MAX_POINT_ID then
        if rules.nextPointId ~= nil then RecoverRule(self, "nextPointId", rules.nextPointId) end
        rules.nextPointId = 1
        self.automationDataDirty = true
    end
    local used = {}
    for _, point in ipairs(positions) do
        local number = type(point.id) == "string" and tonumber(point.id:match("^point:(%d+)$")) or nil
        if ZoneIdentifier(number) and number <= MAX_POINT_ID and not used[point.id] then
            used[point.id] = true
        else
            if point.id ~= nil then RecoverRule(self, "pointId", { id = point.id, zoneId = point.zoneId, profileId = point.profileId }) end
            point.id = nil
        end
    end
    for _, point in ipairs(positions) do
        if not point.id then
            point.id = AllocatePointId(rules, used)
            self.automationDataDirty = true
        end
        if type(point.name) ~= "string" or point.name == "" then
            point.name = "Point " .. point.id:match("(%d+)$")
            self.automationDataDirty = true
        end
        if type(point) == "table" and point.coordinateSpace ~= "raw" then
            -- Existing world coordinates may be remapped/scaled. Preserve the
            -- record, but never reinterpret its numbers as raw coordinates.
            if point.coordinateSpace == nil then point.coordinateSpace = "world" self.automationDataDirty = true end
            if point.needsRerecording ~= true then point.needsRerecording = true self.automationDataDirty = true end
        end
    end
    if self.automationDataDirty then
        self.automationDataDirty = nil
        SavedDataChanged(self)
    end
    return rules
end

local function SetStatus(self, status)
    local state = self.automation
    if state and state.legacyPointsInZone then
        status = status .. "\nDes anciens points doivent être réenregistrés sur place."
    end
    if state and state.rawPointsInZone and state.positionProblem then
        status = status .. "\nPoints de passage en pause : " .. state.positionProblem
    end
    if self.automationDataMessage then status = status .. "\n" .. self.automationDataMessage end
    if self.automationStatus ~= status then
        self.automationStatus = status
        self.automationMessage = status
        if self.RefreshUI then self:RefreshUI() end
    end
end

local function ValidProfile(self, id)
    return SetupIdentifier(id) and type(self.db.profiles) == "table" and type(self.db.profiles[id]) == "table"
        and type(self.db.profiles[id].name) == "string" and self.db.profiles[id].name ~= ""
end

local function PositionKey(point)
    return table.concat({tostring(point.id), tostring(point.zoneId), tostring(point.worldZoneId), tostring(point.coordinateSpace), tostring(point.x), tostring(point.y), tostring(point.z), tostring(point.profileId)}, ":")
end

local function PointRadius(point)
    if point.radius == nil then return POINT_RADIUS end
    return point.radius
end

local function ValidPoint(point)
    if type(point) ~= "table" then return false end
    local radius = PointRadius(point)
    return point.coordinateSpace == "raw" and not point.needsRerecording
        and ZoneIdentifier(point.zoneId) and ZoneIdentifier(point.worldZoneId)
        and Finite(point.x) and Finite(point.y) and Finite(point.z)
        and Finite(radius) and radius > 0 and radius <= POINT_RADIUS
end

local function PointAssignment(self, point, content)
    if point.contentId == nil and point.encounterId == nil and point.slot == nil then return point.profileId end
    if type(point.contentId) ~= "string" or point.contentId == "" or type(point.encounterId) ~= "string" or point.encounterId == "" then
        return nil, "Ce point de préparation doit être enregistré à nouveau."
    end
    if not content or not content.content or content.content.id ~= point.contentId then
        return nil, "Le contenu de ce point de préparation n’est pas reconnu. Choisis ton setup manuellement."
    end
    if point.stepId ~= nil or point.routeId ~= nil then
        if type(point.stepId) ~= "string" or type(point.routeId) ~= "string" or point.slot ~= "stage:" .. point.stepId
            or not content.raidProgress or content.raidProgress.routeId ~= point.routeId then return nil, "Ce point appartient à un autre parcours. Choisis une reprise." end
        local step = self:GetRaidStep(point.contentId, content.pageId, point.stepId)
        if not step or step.kind ~= "boss" or step.encounterId ~= point.encounterId then return nil, "L’étape de ce point n’est plus disponible." end
        local id = self:GetEffectiveRaidStepProfile(point.contentId, content.pageId, step.id)
        if not id then return nil, "Associe un setup à l’étape de ce point dans la page active." end
        return id
    end
    if point.slot ~= nil and point.slot ~= "prepare:" .. point.encounterId then return nil, "Ce point de préparation doit être enregistré à nouveau." end
    local id = content.pageId and type(self.GetAssignedProfile) == "function"
        and self:GetAssignedProfile(content.setupId or point.contentId, content.pageId, "prepare:" .. point.encounterId) or nil
    if id == nil then return nil, "Aucun setup de préparation n’est associé à ce point dans la page active." end
    return id
end

local function ApplicablePoint(point, content)
    if point.stepId == nil and point.routeId == nil then return true end
    local progress = content and content.raidProgress
    if progress and point.contentId == content.content.id and type(point.routeId) == "string" and type(point.stepId) == "string" then
        return point.routeId == progress.routeId and not progress.completedRun and not progress.completed[point.stepId]
    end
    return true
end

local function FindPosition(self, zoneId, content)
    local state = self.automation
    state.legacyPointsInZone = false
    state.rawPointsInZone = false
    state.invalidPointsInZone = false
    state.pointProblem = nil
    state.zoneProblem = nil
    for _, point in ipairs(self.db.rules.positions) do
        if type(point) == "table" and point.zoneId == zoneId and ApplicablePoint(point, content) then
            if point.coordinateSpace ~= "raw" or point.needsRerecording then
                state.legacyPointsInZone = true
            else
                state.rawPointsInZone = true
                if not ValidPoint(point) then state.invalidPointsInZone = true end
            end
        end
    end
    local position, problem = self:GetPlayerPosition()
    if position and position.zoneId ~= zoneId then
        position, problem = nil, "La zone a changé pendant la lecture de la position."
        state.zoneProblem = "La zone est encore en cours de changement. Changements automatiques en pause."
    end
    state.positionProblem = problem
    if not position then return nil end
    state.lastWorldZoneId = position.worldZoneId
    local nearest, nearestDistance, retained, matchedProfile, ambiguous, assignedProfiles = nil, nil, nil, nil, nil, {}
    for _, point in ipairs(self.db.rules.positions) do
        if ValidPoint(point) and point.zoneId == zoneId and point.worldZoneId == position.worldZoneId and ApplicablePoint(point, content) then
            local dx, dy, dz = position.x - point.x, position.y - point.y, position.z - point.z
            local distance = dx * dx + dy * dy + dz * dz
            if not Finite(distance) then
                state.positionProblem = "La position du personnage n’est pas disponible."
                return nil
            end
            local radius = PointRadius(point)
            local inside = Finite(distance) and math.abs(dy) <= POINT_HEIGHT and distance <= radius * radius
            local staying = state.pointKey == PositionKey(point) and Finite(distance)
                and math.abs(dy) <= POINT_HEIGHT * POINT_EXIT_FACTOR and distance <= (radius * POINT_EXIT_FACTOR) ^ 2
            if staying then
                retained = point
            end
            if inside or staying then
                local assigned, assignmentProblem = PointAssignment(self, point, content)
                if assignmentProblem then state.pointProblem = assignmentProblem return nil end
                assignedProfiles[point] = assigned
                if matchedProfile ~= nil and matchedProfile ~= assigned then ambiguous = true end
                matchedProfile = assigned
            end
            if inside and (not nearestDistance or distance < nearestDistance) then
                nearest, nearestDistance = point, distance
            end
        end
    end
    if ambiguous then
        state.pointProblem = "Plusieurs points proches correspondent à des setups différents. Choisis ton setup ou éloigne ces points."
        return nil
    end
    local point = retained or nearest
    if not point and state.invalidPointsInZone then
        state.pointProblem = "Un point enregistré ne peut plus être utilisé. Supprime son association et réenregistre-le sur place."
        return nil
    end
    state.pointKey = point and PositionKey(point) or nil
    return point, point and assignedProfiles[point]
end

local function ContentContext(self, bossNames)
    if type(self.GetCurrentContent) ~= "function" then return {} end
    local content = self:GetCurrentContent()
    if content == nil then return {} end
    if type(content) ~= "table" or type(content.id) ~= "string" or content.id == "" then
        return { problem = "Contenu en attente. Changements automatiques en pause." }
    end
    -- Dungeon setup pages are shared, while observation and victory evidence
    -- always remain attached to the actual dungeon and its zone.
    local setupId = type(self.GetContentSetupId) == "function" and self:GetContentSetupId(content) or content.id
    if type(setupId) ~= "string" or setupId == "" then
        return { content = content, problem = "Pages du contenu en attente. Changements automatiques en pause." }
    end
    local difficulty
    if type(self.GetContentDifficulty) == "function" then difficulty = self:GetContentDifficulty(content) end
    if difficulty ~= nil and difficulty ~= "normal" and difficulty ~= "veteran" and difficulty ~= "hard" then
        return { content = content, problem = "Difficulté en attente. Changements automatiques en pause." }
    end
    local state = self.automation
    if state and difficulty == nil and state.lastKnownContentId == content.id and state.lastKnownContentDifficulty ~= nil then
        return { content = content, setupId = setupId, difficulty = state.lastKnownContentDifficulty, pageId = state.lastKnownContentPage,
            problem = "Difficulté en attente. Le choix manuel est conservé et les changements automatiques sont en pause." }
    end
    if state and content.category == "trials" and difficulty ~= nil then
        local changed = state.raidContentId == content.id and state.raidDifficulty ~= nil and state.raidDifficulty ~= difficulty
        -- Store the new identity before cancellation can inspect the context.
        state.raidContentId, state.raidDifficulty = content.id, difficulty
        if changed then self:ResetAutomationContext("difficulty") end
    end
    local pageId = type(self.GetActiveContentPage) == "function" and self:GetActiveContentPage(setupId, difficulty) or nil
    if pageId ~= nil and not ZoneIdentifier(pageId) then
        return { content = content, problem = "Page active indisponible. Changements automatiques en pause." }
    end
    if state then
        state.lastKnownContentId, state.lastKnownContentDifficulty, state.lastKnownContentPage = content.id, difficulty, pageId
    end
    local nativeDungeonBossEnabled = content.category == "dungeons" and setupId == "dungeons:general" and pageId ~= nil
        and type(self.IsDungeonBossObservationEnabled) == "function" and self:IsDungeonBossObservationEnabled(pageId) == true
    local raidProgress = content.category == "trials" and pageId and type(self.GetRaidProgress) == "function"
        and self:GetRaidProgress(content.id, pageId) or nil
    local encounter, unknown, ambiguous
    for _, name in ipairs(bossNames) do
        local found = type(self.GetEncounterForBoss) == "function" and self:GetEncounterForBoss(content, self:NormalizeBossName(name)) or nil
        if type(found) ~= "table" or type(found.id) ~= "string" or found.id == "" then unknown = true
        elseif encounter and encounter.id ~= found.id then ambiguous = true
        else encounter = found end
    end
    if unknown or ambiguous then encounter = nil end
    return { content = content, setupId = setupId, difficulty = difficulty, pageId = pageId, encounter = encounter, unknownBoss = unknown, ambiguous = ambiguous,
        nativeDungeonBossEnabled = nativeDungeonBossEnabled == true, raidProgress = raidProgress }
end

local function Assigned(self, context, slot)
    if not context.content or not context.pageId or type(self.GetAssignedProfile) ~= "function" then return nil end
    -- Missing associations deliberately allow a fallback. An association that
    -- exists but no longer resolves must not silently select another setup.
    local assignments = self.db.contentAssignments
    local setupId = context.setupId or context.content.id
    local pages = type(assignments) == "table" and assignments[setupId] or nil
    local slots = type(pages) == "table" and pages[context.pageId] or nil
    local issue = "Une association de cette page n’est plus disponible. Vérifie ses setups avant de reprendre l’automatique."
    if (assignments ~= nil and type(assignments) ~= "table") or (pages ~= nil and type(pages) ~= "table")
        or (slots ~= nil and type(slots) ~= "table") then return nil, issue end
    local stored = type(slots) == "table" and slots[slot] or nil
    if stored ~= nil and not ValidProfile(self, stored) then return nil, issue end
    local assigned = self:GetAssignedProfile(setupId, context.pageId, slot)
    if (stored ~= nil and assigned ~= stored) or (assigned ~= nil and not ValidProfile(self, assigned)) then return nil, issue end
    return assigned
end

local function AssignedFallback(self, context, slot, fallback)
    local assigned, issue = Assigned(self, context, slot)
    if assigned ~= nil or issue then return assigned, issue end
    return Assigned(self, context, fallback)
end

local function ContentScope(context)
    return table.concat({ tostring(context.content and context.content.id or ""), tostring(context.setupId or ""), tostring(context.difficulty or ""), tostring(context.pageId or ""),
        tostring(context.nativeDungeonBossEnabled == true), tostring(context.raidProgress and context.raidProgress.routeId or ""),
        tostring(context.raidProgress and context.raidProgress.currentStepId or ""), tostring(context.raidProgress and context.raidProgress.revision or "") }, "\031")
end

local function Observe(self)
    local zoneId = self:GetZoneId()
    if not ZoneIdentifier(zoneId) then return { zoneId = 0, bosses = {}, keys = {}, signature = self.automation.stableSignature or "" } end
    local bosses, bossProblem, deadNames, bossSlots = self:GetObservedBossNames()
    local content = ContentContext(self, bosses)
    local keys = {}
    for _, name in ipairs(bosses) do keys[#keys + 1] = self:NormalizeBossName(name) end
    if bossProblem then keys = self.automation.lastBossKeys or {}
    else self.automation.lastBossKeys = keys end
    local point, pointProfileId = FindPosition(self, zoneId, content)
    local pointSignature = point and PositionKey(point) or ""
    if self.automation.positionProblem or self.automation.pointProblem then
        -- A measurement failure must not manufacture a context transition and
        -- release a user's manual override. Resolution still sees no usable point.
        pointSignature = self.automation.pointKey or ""
    end
    local deadKeys = {}
    for _, name in ipairs(deadNames or {}) do deadKeys[self:NormalizeBossName(name)] = true end
    local raidStep, raidProblem
    if content.raidProgress and #bosses > 0 and not bossProblem and type(self.GetObservedRaidStep) == "function" then
        raidStep, raidProblem = self:GetObservedRaidStep(content.content.id, content.pageId, bossSlots)
    end
    local bossSignature = content.raidProgress and content.raidProgress.currentStepId or table.concat(keys, "\031")
    local signature = tostring(zoneId) .. "\030" .. tostring(bossSignature) .. "\030" .. pointSignature
        .. "\030" .. tostring(self.automation.lastWorldZoneId or "")
        .. "\030" .. tostring(not content.raidProgress and self.automation.previousBossKey or "")
        .. "\030" .. tostring(content.content and content.content.id or "")
        .. "\030" .. tostring(content.setupId or "")
        .. "\030" .. tostring(content.difficulty or "") .. "\030" .. tostring(content.pageId or "")
        .. "\030" .. tostring(not content.raidProgress and self.automation.previousEncounterId or "")
        .. "\030" .. tostring(content.raidProgress and content.raidProgress.routeId or "")
        .. "\030" .. tostring(content.raidProgress and content.raidProgress.revision or "")
    return { zoneId = zoneId, bosses = bosses, keys = keys, deadKeys = deadKeys, bossSlots = bossSlots or {}, point = point, pointProfileId = pointProfileId, signature = signature,
        bossProblem = bossProblem, zoneProblem = self.automation.zoneProblem, contentProblem = content.problem,
        content = content.content, setupId = content.setupId, difficulty = content.difficulty, pageId = content.pageId, catalogEncounter = content.encounter,
        unknownCatalogBoss = content.unknownBoss, ambiguousCatalogBoss = content.ambiguous, nativeDungeonBossEnabled = content.nativeDungeonBossEnabled,
        raidProgress = content.raidProgress, raidObservedStep = raidStep, raidProblem = raidProblem }
end

local function RequiredMembers(catalog)
    if not catalog or catalog.groupVerified ~= true or type(catalog.members) ~= "table" or type(catalog.requiredMembers) ~= "table" then return nil end
    local known, memberCount = {}, 0
    for key, member in pairs(catalog.members) do
        if not ZoneIdentifier(key) or key > 64 or type(member) ~= "table" or type(member.id) ~= "string" or member.id == "" or known[member.id] then return nil end
        known[member.id], memberCount = true, memberCount + 1
    end
    if memberCount == 0 then return nil end
    for index = 1, memberCount do if catalog.members[index] == nil then return nil end end
    local count, required = 0, {}
    for key, member in pairs(catalog.requiredMembers) do
        local id = type(member) == "table" and member.id or member
        if not ZoneIdentifier(key) or key > 64 or type(id) ~= "string" or id == "" or not known[id] or required[id] then return nil end
        required[id] = true
        count = count + 1
    end
    if count ~= memberCount or count > 64 then return nil end
    for index = 1, count do if catalog.requiredMembers[index] == nil then return nil end end
    return required
end

-- A missing boss bar is not evidence of a victory. Keep only encounters for
-- which a named live boss was observed fighting, followed by its actual death.
-- A player death, an unknown observation or a new live boss invalidates that
-- evidence. Group combat must have ended before using an after-boss setup.
local function AbortRaid(self, encounter)
    if encounter and encounter.raidToken and self.AbortRaidEncounter then
        self:AbortRaidEncounter(encounter.contentId, encounter.raidPageId, encounter.raidToken)
    end
end
local function TrackEncounter(self, context, inCombat, dead, now)
    local state = self.automation
    if dead then
        if state.encounter then state.encounter.failed = true; AbortRaid(self, state.encounter) end
        state.previousBossKey, state.previousBossName = nil, nil
        state.previousEncounterId, state.previousEncounterName, state.previousContentId = nil, nil, nil
        state.encounterSeen = true
        return
    end
    local groupCombat, groupProblem = GroupActivity()
    local fighting = inCombat or groupCombat == true
    if #context.keys > 0 and (fighting or groupProblem) then state.encounterSeen = true end
    if context.bossProblem or context.zoneProblem or context.contentProblem or groupProblem then
        if state.encounter then state.encounter.failed = true; AbortRaid(self, state.encounter) end
        return
    end
    local raidToken
    if context.raidObservedStep and self.ObserveRaidEncounter then
        raidToken = self:ObserveRaidEncounter(context.content.id, context.pageId, context.raidObservedStep.encounterId, context.raidObservedStep.id)
    elseif #context.keys == 0 and context.point and context.point.stepId and self.ObserveRaidPreparation then
        self:ObserveRaidPreparation(context.content.id, context.pageId, context.point.stepId, context.point.routeId)
    end
    local function RecordSlots(encounter)
        for slot, observation in pairs(context.bossSlots) do
            if not observation.dead then
                encounter.slots[slot] = true
                -- A revived or reused boss tag must be witnessed dying again.
                encounter.killedSlots[slot] = nil
                if encounter.catalogId then
                    local found, memberId
                    if type(self.GetEncounterMemberForBoss) == "function" then
                        found, memberId = self:GetEncounterMemberForBoss(context.content, observation.key)
                    end
                    if type(found) ~= "table" or found.id ~= encounter.catalogId or type(memberId) ~= "string" or memberId == "" then
                        encounter.catalogFailed = true
                    else encounter.slotMembers[slot] = memberId end
                end
            end
            if observation.dead and encounter.slots[slot] then encounter.killedSlots[slot] = true end
        end
    end
    if #context.keys > 0 then
        state.previousBossKey, state.previousBossName = nil, nil
        state.previousEncounterId, state.previousEncounterName, state.previousContentId = nil, nil, nil
        if fighting then
            state.encounterSeen = true
            local encounter = state.encounter
            if not encounter then
                local catalog = context.catalogEncounter
                encounter = { zoneId = context.zoneId, names = {}, slots = {}, killedSlots = {}, slotMembers = {}, started = now,
                    contentId = context.content and context.content.id, difficulty = context.difficulty,
                    catalogId = catalog and catalog.id, catalog = catalog, raidToken = raidToken,
                    raidPageId = context.raidProgress and context.pageId or nil }
                state.encounter = encounter
            end
            if encounter.catalogId and (not context.catalogEncounter or context.catalogEncounter.id ~= encounter.catalogId
                or not context.content or context.content.id ~= encounter.contentId or context.difficulty ~= encounter.difficulty) then
                encounter.catalogFailed = true
            end
            if encounter.raidToken and (encounter.raidPageId ~= context.pageId or raidToken ~= encounter.raidToken) then encounter.failed = true end
            for index, key in ipairs(context.keys) do
                encounter.names[key] = context.bosses[index]
            end
            RecordSlots(encounter)
        elseif state.encounter then
            -- A reset live boss outside combat is a new attempt, never a kill.
            AbortRaid(self, state.encounter)
            state.encounter = nil
        end
        return
    end
    local encounter = state.encounter
    if not encounter then return end
    RecordSlots(encounter)
    if fighting then return end
    if encounter.failed or encounter.zoneId ~= context.zoneId then AbortRaid(self, encounter); state.encounter = nil return end
    for slot in pairs(encounter.slots) do if not encounter.killedSlots[slot] then AbortRaid(self, encounter); state.encounter = nil return end end
    local required = RequiredMembers(encounter.catalog)
    local catalogComplete = false
    if encounter.catalogId and not encounter.catalogFailed and context.content and context.content.id == encounter.contentId
        and context.difficulty == encounter.difficulty and required then
        local killedMembers = {}
        for slot in pairs(encounter.killedSlots) do
            local memberId = encounter.slotMembers[slot]
            if memberId then killedMembers[memberId] = true end
        end
        catalogComplete = true
        for memberId in pairs(required) do if not killedMembers[memberId] then catalogComplete = false end end
    end
    local completedKey, completedName
    local multipleNames = false
    for key, name in pairs(encounter.names) do
        -- Distinct bosses in the same encounter cannot define a unique previous
        -- boss. The user can still use points or the generic zone association.
        if completedKey and completedKey ~= key then multipleNames = true end
        completedKey, completedName = key, name
    end
    if multipleNames or (encounter.catalog and not catalogComplete) then completedKey, completedName = nil, nil end
    encounter.catalogComplete = catalogComplete
    if catalogComplete and encounter.raidToken and self.ConfirmRaidEncounterVictory then
        if not self:ConfirmRaidEncounterVictory(encounter.contentId, encounter.raidPageId, encounter.catalogId, encounter.raidToken, encounter) then AbortRaid(self, encounter) end
    elseif encounter.raidToken then AbortRaid(self, encounter) end
    state.encounter = nil
    state.previousBossKey, state.previousBossName = completedKey, completedName
    if catalogComplete then
        state.previousEncounterId, state.previousEncounterName, state.previousContentId = encounter.catalogId,
            DisplayName(encounter.catalog.name or encounter.catalog.nameEn or completedName), encounter.contentId
    end
    state.absentSince = nil
end

local function Resolve(self, context)
    if context.zoneProblem then return nil, nil, context.zoneProblem end
    if context.bossProblem then return nil, nil, context.bossProblem end
    if context.contentProblem then return nil, nil, context.contentProblem end
    local mapping = self.db.rules.bosses[context.zoneId] or {}
    local profileId, matchedName
    for index, key in ipairs(context.keys) do
        local candidate = mapping[key]
        if candidate ~= nil then
            if profileId ~= nil and candidate ~= profileId then
                return nil, nil, "Plusieurs boss associés à des setups différents : choix manuel requis."
            end
            profileId, matchedName = candidate, context.bosses[index]
        end
    end
    if profileId ~= nil then
        return profileId, "boss : " .. matchedName
    end
    if context.raidProgress and #context.bosses > 0 then
        if context.raidProblem then return nil, nil, context.raidProblem end
        local step = context.raidObservedStep
        if not step then return nil, nil, "Choisis l’étape correspondant au boss visible." end
        local assigned, source = self:GetEffectiveRaidStepProfile(context.content.id, context.pageId, step.id)
        if not assigned then return nil, nil, source == "invalid" and "L’association de cette étape n’est plus disponible. Vérifie son setup."
            or "Associe un setup à cette étape Boss ou à son remplacement." end
        local groupProblem = ZoneFallbackProblem()
        if groupProblem then return nil, nil, groupProblem end
        return assigned, "étape : " .. step.name
    end
    if context.nativeDungeonBossEnabled and #context.bosses > 0 then
        -- This is an explicit association with ESO's native dungeon boss bars,
        -- not a guessed encounter name. Victory tracking remains independent.
        local assigned, issue = Assigned(self, context, "boss")
        if issue then return nil, nil, issue end
        if assigned == nil then return nil, nil, "Associe un setup Boss à la page Donjons pour utiliser les boss signalés par ESO." end
        return assigned, NATIVE_DUNGEON_BOSS .. (context.catalogEncounter and "" or " ; victoire non vérifiée")
    end
    if context.catalogEncounter then
        local assigned, issue
        if context.setupId == "dungeons:general" then
            assigned, issue = Assigned(self, context, "boss")
        else
            assigned, issue = AssignedFallback(self, context, "encounter:" .. context.catalogEncounter.id, "boss")
        end
        if issue then return nil, nil, issue end
        if assigned ~= nil then return assigned, "rencontre : " .. DisplayName(context.catalogEncounter.name or context.bosses[1]) end
    elseif context.ambiguousCatalogBoss then
        return nil, nil, "Plusieurs rencontres sont reconnues en même temps. Choix manuel requis."
    end
    if context.point then
        return context.pointProfileId or context.point.profileId, "point de passage"
    end
    if self.automation.pointProblem then return nil, nil, self.automation.pointProblem end
    if self.automation.rawPointsInZone and self.automation.positionProblem then
        -- An unavailable measurement is not proof that the player left a point.
        -- Keep explicit boss rules available, but never infer the zone fallback.
        return nil, nil, "Position en attente. Changements automatiques en pause."
    end
    if self.automation.legacyPointsInZone then
        -- Their coordinates cannot be compared to raw level coordinates. An
        -- ignored old point is not evidence that the zone fallback is intended.
        return nil, nil, "Réenregistre les anciens points de cette zone avant de reprendre les changements automatiques."
    end
    if #context.bosses > 0 then
        return nil, nil, "Aucun setup associé à ce boss : " .. table.concat(context.bosses, ", ")
    end
    if context.raidProgress and self.ResolveRaidProgressSetup then
        if context.raidProgress.needsResume and not self.automation.encounterSeen and self.IsInitialTrashEnabled
            and self:IsInitialTrashEnabled(context.content.id, context.pageId) == true and self.StartRaidInitialTrash then
            self:StartRaidInitialTrash(context.content.id, context.pageId)
        end
        local assigned, step, issue = self:ResolveRaidProgressSetup(context.content.id, context.pageId)
        if issue then return nil, nil, issue end
        local groupProblem = ZoneFallbackProblem()
        if groupProblem then return nil, nil, groupProblem end
        if assigned and step then return assigned, (step.kind == "trash" and "zone — étape : " or "étape : ") .. step.name end
    end
    local afterBoss = self.automation.previousBossKey and (self.db.rules.trashAfterBosses[context.zoneId] or {})[self.automation.previousBossKey]
    local zoneProfile = self.db.rules.zones[context.zoneId]
    local fallbackId, fallbackReason, issue
    if afterBoss ~= nil then
        fallbackId, fallbackReason = afterBoss, "Trash après " .. (self.automation.previousBossName or "le boss")
    end
    if fallbackId == nil and context.content and self.automation.previousContentId == context.content.id and self.automation.previousEncounterId then
        if context.setupId == "dungeons:general" then
            fallbackId, issue = Assigned(self, context, "trash")
        else
            fallbackId, issue = AssignedFallback(self, context, "after:" .. self.automation.previousEncounterId, "trash")
        end
        if issue then return nil, nil, issue end
        if fallbackId ~= nil then fallbackReason = "Trash après " .. (self.automation.previousEncounterName or "la rencontre") end
    end
    if fallbackId == nil and zoneProfile ~= nil then fallbackId, fallbackReason = zoneProfile, "zone" end
    if fallbackId == nil and context.content and context.pageId and not self.automation.encounterSeen and type(self.IsInitialTrashEnabled) == "function"
        and self:IsInitialTrashEnabled(context.setupId or context.content.id, context.pageId) == true then
        fallbackId, issue = Assigned(self, context, "trash")
        if issue then return nil, nil, issue end
        if fallbackId ~= nil then fallbackReason = "zone — Trash au début du contenu" end
    end
    if fallbackId == nil then
        fallbackId, issue = Assigned(self, context, "generic")
        if issue then return nil, nil, issue end
        if fallbackId ~= nil then fallbackReason = "zone — page du contenu" end
    end
    if fallbackId ~= nil then
        local groupProblem = ZoneFallbackProblem()
        if groupProblem then
            self.automation.absentSince = nil
            return nil, nil, groupProblem
        end
        return fallbackId, fallbackReason
    end
    return nil, "zone"
end

function R:ResetAutomationContext(reason)
    if not self.automation then return end
    if (reason == "world" or reason == "zone" or reason == "difficulty" or reason == "initial") and self.InvalidateRaidProgress then self:InvalidateRaidProgress(nil, nil, reason) end
    if reason == "world" or reason == "zone" or reason == "initial" then self.automation.raidContentId, self.automation.raidDifficulty = nil, nil end
    self.automation.candidate = nil
    self.automation.attempted = nil
    self.automation.manualSignature = nil
    self.automation.manualAwaitingObservation = nil
    self.automation.absentSince = nil
    self.automation.pointKey = nil
    self.automation.stableSignature = nil
    self.automation.candidateSignature = nil
    self.automation.contextSince = nil
    self.automation.requestSignature = nil
    self.automation.requestProfileId = nil
    self.automation.requestContentScope = nil
    self.automation.legacyPointsInZone = nil
    self.automation.rawPointsInZone = nil
    self.automation.positionProblem = nil
    self.automation.pointProblem = nil
    self.automation.invalidPointsInZone = nil
    self.automation.zoneProblem = nil
    self.automation.lastWorldZoneId = nil
    self.automation.lastBossKeys = nil
    self.automation.observationFault = nil
    self.automation.encounter = nil
    self.automation.previousBossKey, self.automation.previousBossName = nil, nil
    self.automation.previousEncounterId, self.automation.previousEncounterName, self.automation.previousContentId = nil, nil, nil
    self.automation.encounterSeen = nil
    self.automation.lastKnownContentId, self.automation.lastKnownContentDifficulty, self.automation.lastKnownContentPage = nil, nil, nil
    if self.CancelAutomaticSwap then self:CancelAutomaticSwap() end
end

function R:GetAutomationStatus()
    return self.automationStatus or "Changements automatiques en attente."
end

function R:GetContentDetectionSummary()
    if not self.automation or not self.automation.worldReady then return "Chargement du contenu…" end
    local ok, context = pcall(Observe, self)
    if not ok or context.zoneId == 0 or context.contentProblem or context.bossProblem or context.zoneProblem then
        return "Reconnaissance en attente. Aucun changement automatique sur une information incertaine."
    end
    if not context.content then return "Zone reconnue. Aucun contenu du catalogue identifié ; les associations personnelles restent disponibles." end
    local name = type(self.GetContentName) == "function" and self:GetContentName(context.content) or context.content.name
    name = DisplayName(name)
    local difficulty = context.difficulty == "hard" and "Mode difficile choisi manuellement"
        or context.difficulty == "veteran" and "Vétéran" or context.difficulty == "normal" and "Normal" or "Difficulté non déterminée"
    local page = context.pageId and type(self.GetPageName) == "function" and self:GetPageName(context.pageId) or nil
    local summary = (name ~= "" and name or "Contenu reconnu") .. " — " .. difficulty .. "."
        .. (type(page) == "string" and (" Page active : " .. page .. ".") or " Aucune page active disponible.")
    if context.nativeDungeonBossEnabled and #context.bosses > 0 then
        return summary .. " " .. NATIVE_DUNGEON_BOSS .. "."
            .. (context.catalogEncounter and "" or " Victoire non vérifiée ; aucun Trash commun déduit de cette observation.")
    end
    if context.ambiguousCatalogBoss then return summary .. " Plusieurs rencontres sont visibles ; choix manuel requis." end
    if context.unknownCatalogBoss then return summary .. " Boss visible non identifié dans le catalogue ; aucune rencontre choisie par supposition." end
    if context.catalogEncounter then
        return summary .. " Rencontre reconnue : " .. DisplayName(context.catalogEncounter.name or context.bosses[1]) .. "."
    end
    if self.automation.previousContentId == context.content.id and self.automation.previousEncounterId then return summary .. " Victoire confirmée sur la rencontre précédente." end
    return summary .. " Aucune rencontre confirmée actuellement."
end

function R:SuppressAutomationForContext()
    if not self.automation then return end
    local observed, context = pcall(function()
        EnsureRules(self)
        return Observe(self)
    end)
    if not observed or context.zoneId == 0 or context.bossProblem or context.zoneProblem or context.contentProblem or (self.automation.rawPointsInZone and self.automation.positionProblem) then
        if self.automation.encounter then self.automation.encounter.failed = true end
        self.automation.manualSignature = self.automation.stableSignature or self.automation.manualSignature
        self.automation.manualAwaitingObservation = true
    else
        self.automation.manualSignature = context.signature
        self.automation.manualAwaitingObservation = nil
    end
    self.automation.candidate = nil
    if self.CancelAutomaticSwap then pcall(self.CancelAutomaticSwap, self) end
    -- A faulty automatic observation or a UI refresh must not prevent Core
    -- from handing the user's manual request to the engine.
    pcall(SetStatus, self, "Choix manuel conservé jusqu’à un changement de zone, de boss ou de point.")
end

local function SuspendAfterFault(self)
    local state = self.automation
    if state then
        state.observationFault = true
        if state.encounter then state.encounter.failed = true end
        state.requestSignature, state.requestProfileId = nil, nil
        state.candidate, state.candidateSignature, state.contextSince, state.absentSince = nil, nil, nil, nil
    end
    -- Clear the request first: Core may ask whether a queued automatic request
    -- is still current while cancelling. A manual request remains independent.
    if self.CancelAutomaticSwap then pcall(self.CancelAutomaticSwap, self) end
    SetStatus(self, "Le jeu ne fournit pas encore les informations nécessaires. Changements automatiques en pause.")
end

-- The engine uses this immediately before resuming an automatic request. It
-- prevents a paused boss setup from finishing after the encounter has changed.
local function AutomaticRequestCurrent(self, profileId)
    local state = self.automation
    if not state or not state.worldReady or state.observationFault or not self.db then return false end
    EnsureRules(self)
    if self.db.settings.automatic ~= true then return false end
    if self.IsSavingSetup and self:IsSavingSetup() then return false end
    if self.bankTransfer then return false end
    if not state.requestSignature or state.requestProfileId ~= profileId or not ValidProfile(self, profileId) then return false end
    if state.manualAwaitingObservation or state.manualSignature == state.requestSignature then return false end
    -- A vanished boss tag during combat is not evidence that an encounter ended.
    -- The engine itself must still prohibit mutations while in combat or dead.
    local inCombat, dead, problem = Activity()
    if problem then return false end
    if inCombat or dead then
        -- Boss bars may disappear in combat, but an explicit page/difficulty
        -- change must still invalidate the earlier automatic request.
        local scope = ContentContext(self, {})
        if scope.problem and state.encounter then state.encounter.failed = true end
        return state.requestSignature ~= nil and state.requestProfileId == profileId and not scope.problem
            and (state.requestContentScope == nil or ContentScope(scope) == state.requestContentScope)
    end
    local context = Observe(self)
    if context.zoneId == 0 or context.bossProblem or context.zoneProblem or context.contentProblem then
        if state.encounter then state.encounter.failed = true end
        return false
    end
    local desired, _, issue = Resolve(self, context)
    return context.signature == state.requestSignature and desired == profileId
        and not issue and state.manualSignature ~= context.signature
end

function R:IsAutomaticRequestCurrent(profileId)
    local ok, current = pcall(AutomaticRequestCurrent, self, profileId)
    if not ok then SuspendAfterFault(self) end
    return ok and current == true
end

local function EvaluateAutomation(self)
    if not self.db or not self.automation then return end
    EnsureRules(self)
    local state, now = self.automation, Now()
    if self.IsSavingSetup and self:IsSavingSetup() then
        if state.encounter then state.encounter.failed = true end
        state.candidate, state.candidateSignature, state.contextSince, state.absentSince = nil, nil, nil, nil
        if self.CancelAutomaticSwap then self:CancelAutomaticSwap() end
        SetStatus(self, "Changements automatiques en pause pendant l’enregistrement.")
        return
    end
    if self.bankTransfer then
        if state.encounter then state.encounter.failed = true end
        state.candidate, state.candidateSignature, state.contextSince, state.absentSince = nil, nil, nil, nil
        if self.CancelAutomaticSwap then self:CancelAutomaticSwap() end
        SetStatus(self, "Changements automatiques en pause pendant le transfert en banque.")
        return
    end
    if not state.worldReady then
        SetStatus(self, "Chargement de la zone…")
        return
    end
    local context = Observe(self)
    self.observedBossNames = context.bosses
    self.observedZoneId = context.zoneId
    if context.zoneId == 0 then
        if state.encounter then state.encounter.failed = true end
        state.candidate, state.candidateSignature, state.contextSince, state.absentSince = nil, nil, nil, nil
        SetStatus(self, "Zone en attente. Changements automatiques en pause.")
        return
    end
    if context.zoneId ~= state.zoneId then
        self:ResetAutomationContext(ZoneIdentifier(state.zoneId) and "zone" or "initial")
        state.zoneId = context.zoneId
        -- Do not retain a point from a different zone.
        context = Observe(self)
    end
    local inCombat, dead, activityProblem = Activity()
    if not activityProblem then
        TrackEncounter(self, context, inCombat, dead, now)
        -- Previous-boss evidence is part of the automatic context, so a manual
        -- choice remains latched unless that evidence genuinely changes.
        context = Observe(self)
    elseif state.encounter then
        state.encounter.failed = true
    end
    if activityProblem or context.bossProblem or context.zoneProblem or context.contentProblem then
        state.candidate, state.candidateSignature, state.contextSince, state.absentSince = nil, nil, nil, nil
        SetStatus(self, activityProblem or context.bossProblem or context.zoneProblem or context.contentProblem)
        return
    end
    if inCombat or dead then
        state.candidate = nil
        state.candidateSignature = nil
        state.contextSince = nil
        state.absentSince = nil
        -- Boss tags can vanish during a phase or while dead. Never infer trash here.
        SetStatus(self, dead and "Mort ou résurrection : changement suspendu." or "En combat : changement suspendu.")
        return
    end
    if #context.bosses == 0 then
        state.absentSince = state.absentSince or now
    else
        state.absentSince = nil
    end
    if self.db.settings.automatic ~= true then
        state.candidate = nil
        SetStatus(self, "Changements automatiques désactivés.")
        return
    end
    if state.manualAwaitingObservation then
        if state.rawPointsInZone and state.positionProblem then
            SetStatus(self, "Choix manuel conservé pendant l’attente de la position.")
            return
        end
        state.manualSignature = context.signature
        state.manualAwaitingObservation = nil
    end
    local profileId, reason, issue = Resolve(self, context)
    local token = context.signature .. "\030" .. tostring(profileId)
    if state.candidate ~= token then
        state.candidate, state.candidateSince = token, now
    end
    -- A return to a former context is a fresh attempt, but a failed swap in the
    -- unchanged context remains latched instead of retrying every poll.
    if state.stableSignature ~= context.signature then
        if state.candidateSignature ~= context.signature then
            state.candidateSignature = context.signature
            state.contextSince = now
        end
        if now - state.contextSince < STABLE_MS then
            SetStatus(self, "Vérification de la zone et de la rencontre…")
            return
        end
        if state.stableSignature and self.CancelAutomaticSwap then self:CancelAutomaticSwap() end
        state.stableSignature = context.signature
        state.candidateSignature = nil
        state.attempted = nil
        if state.manualSignature ~= context.signature then state.manualSignature = nil end
    end
    if state.manualSignature == context.signature then
        state.candidate = nil
        SetStatus(self, "Choix manuel conservé.")
        return
    end
    if issue then
        state.candidate = nil
        SetStatus(self, issue)
        return
    end
    if not profileId then
        state.candidate = nil
        SetStatus(self, "Aucun setup associé à " .. self:GetZoneLabel() .. ".")
        return
    end
    if not ValidProfile(self, profileId) then
        state.candidate = nil
        SetStatus(self, "Le setup associé n’est plus disponible. Choisis une nouvelle association.")
        return
    end
    if (reason:sub(1, #"zone") == "zone" or reason:sub(1, #"Trash après ") == "Trash après ") and (not state.absentSince or now - state.absentSince < NO_BOSS_MS) then
        SetStatus(self, "Attente après disparition des boss…")
        return
    end
    if state.attempted == token then
        SetStatus(self, "Setup automatique prévu : " .. self.db.profiles[profileId].name .. "."
            .. (reason:sub(1, #NATIVE_DUNGEON_BOSS) == NATIVE_DUNGEON_BOSS and ("\n" .. reason .. ".") or ""))
        return
    end
    if now - state.candidateSince < STABLE_MS then
        SetStatus(self, "Setup prévu : " .. self.db.profiles[profileId].name .. "."
            .. (reason:sub(1, #NATIVE_DUNGEON_BOSS) == NATIVE_DUNGEON_BOSS and ("\n" .. reason .. ".") or ""))
        return
    end
    -- Read current game state again immediately before handing work to the engine.
    local latestCombat, latestDead, latestActivityProblem = Activity()
    if latestActivityProblem or latestCombat or latestDead then return end
    local latest = Observe(self)
    local latestId, latestReason, latestIssue = Resolve(self, latest)
    if latest.signature ~= context.signature or latestId ~= profileId or latestIssue then
        state.candidate = nil
        return
    end
    state.attempted, state.candidate = token, nil
    state.requestSignature, state.requestProfileId = context.signature, profileId
    state.requestContentScope = ContentScope(context)
    self.automationDesired = profileId
    SetStatus(self, "Changement demandé : " .. self.db.profiles[profileId].name .. " (" .. latestReason .. ").")
    local accepted = self:EquipSetup(profileId, "Automatique — " .. latestReason, true)
    if accepted and latest.raidProgress and self.RegisterRaidSetupRequest then
        local step = latest.raidObservedStep or self:GetRaidStep(latest.content.id, latest.pageId, latest.raidProgress.currentStepId)
        if step then self:RegisterRaidSetupRequest(latest.content.id, latest.pageId, step.id, profileId) end
    end
end

function R:EvaluateAutomation()
    if self.automation then self.automation.observationFault = nil end
    local ok = pcall(EvaluateAutomation, self)
    if not ok then SuspendAfterFault(self) end
end

local function RulesChanged(self, message, rearm)
    if rearm then
        local state = self.automation
        local seen, previousBossKey, previousBossName = state and state.encounterSeen, state and state.previousBossKey, state and state.previousBossName
        local previousEncounterId, previousEncounterName, previousContentId = state and state.previousEncounterId, state and state.previousEncounterName, state and state.previousContentId
        self:ResetAutomationContext("rearm")
        if state then
            -- Toggling is a rearm, not evidence of a fresh dungeon instance.
            state.encounterSeen, state.previousBossKey, state.previousBossName = seen, previousBossKey, previousBossName
            state.previousEncounterId, state.previousEncounterName, state.previousContentId = previousEncounterId, previousEncounterName, previousContentId
        end
    elseif self.automation then
        local state = self.automation
        state.candidate, state.candidateSignature, state.contextSince, state.attempted = nil, nil, nil, nil
        state.requestSignature, state.requestProfileId = nil, nil
        if self.CancelAutomaticSwap then self:CancelAutomaticSwap() end
    end
    SavedDataChanged(self)
    if self.Notify then self:Notify(message) end
    if self.RefreshUI then self:RefreshUI() end
    self:EvaluateAutomation()
end

function R:BindZone(id, expectedZoneId)
    EnsureRules(self)
    if not ValidProfile(self, id) then return false end
    local zoneId = self:GetZoneId()
    if not self.automation or not self.automation.worldReady or not ZoneIdentifier(zoneId) then
        self:Notify("Attends la fin du chargement avant d’associer un setup à cette zone.") return false
    end
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then
        self:Notify("La zone a changé. Rouvre les associations dans la zone voulue.") return false
    end
    self.db.rules.zones[zoneId] = id
    RulesChanged(self, "Setup associé à la zone : " .. self:GetZoneLabel() .. ".")
    return true
end

function R:BindBossName(id, name, expectedZoneId)
    EnsureRules(self)
    if not ValidProfile(self, id) then return false end
    local zoneId = self:GetZoneId()
    if not self.automation or not self.automation.worldReady or not ZoneIdentifier(zoneId) then
        self:Notify("Attendre la fin du chargement avant d’associer un boss.")
        return false
    end
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then
        self:Notify("La zone a changé. Rouvrir les associations de boss dans la zone voulue.")
        return false
    end
    local key, observedName = self:NormalizeBossName(name)
    for _, observed in ipairs(self:GetObservedBossNames()) do
        if key ~= "" and self:NormalizeBossName(observed) == key then observedName = observed break end
    end
    if not observedName then
        self:Notify("Ce boss n’est plus reconnu par le jeu. Pour anticiper son apparition, enregistrer un point de passage.")
        return false
    end
    self.db.rules.bosses[zoneId] = self.db.rules.bosses[zoneId] or {}
    self.db.rules.bosses[zoneId][key] = id
    RulesChanged(self, "Setup associé à " .. observedName .. " dans cette zone.")
    return true
end

function R:BindTargetBoss(id)
    local name = self:GetTargetBossName()
    if not name then
        self:Notify("Aucun boss confirmé sous le réticule. Choisir un boss reconnu dans les associations de Setup Assist.")
        return false
    end
    return self:BindBossName(id, name, self:GetZoneId())
end

function R:ClearZoneRule(expectedZoneId)
    EnsureRules(self)
    local zoneId = self:GetZoneId()
    if not self.automation or not self.automation.worldReady or not ZoneIdentifier(zoneId) then
        self:Notify("Attends la fin du chargement avant de retirer cette association.") return false
    end
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then
        self:Notify("La zone a changé. Rouvre les associations dans la zone voulue.") return false
    end
    self.db.rules.zones[zoneId] = nil
    RulesChanged(self, "Association de la zone supprimée.")
    return true
end

function R:ClearBossAssociation(name, expectedZoneId)
    EnsureRules(self)
    local zoneId, key = self:GetZoneId(), self:NormalizeBossName(name)
    if not self.automation or not self.automation.worldReady or not ZoneIdentifier(zoneId) then
        self:Notify("Attendre la fin du chargement avant de retirer une association.")
        return false
    end
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then
        self:Notify("La zone a changé. Rouvrir les associations de boss dans la zone voulue.")
        return false
    end
    local associations = self.db.rules.bosses[zoneId]
    if key == "" or not associations or associations[key] == nil then
        self:Notify("Aucune association pour ce boss dans la zone actuelle.")
        return false
    end
    associations[key] = nil
    RulesChanged(self, "Association de " .. DisplayName(name) .. " supprimée.")
    return true
end

function R:ClearBossRule()
    local name = self:GetTargetBossName()
    if not name then self:Notify("Choisir l’association à retirer dans le menu de Setup Assist.") return false end
    return self:ClearBossAssociation(name, self:GetZoneId())
end

function R:BindPosition(id, name, expectedZoneId, preparation)
    EnsureRules(self)
    if not ValidProfile(self, id) then return false end
    if preparation ~= nil and (type(preparation) ~= "table" or type(preparation.contentId) ~= "string" or preparation.contentId == ""
        or type(preparation.encounterId) ~= "string" or preparation.encounterId == "") then
        self:Notify("Choisis une rencontre disponible avant d’enregistrer ce point.") return false
    end
    local inCombat, dead, activityProblem = Activity()
    if activityProblem then self:Notify("Le personnage n’est pas encore prêt. Réessaie dans un instant.") return false end
    if inCombat or dead then
        self:Notify("Enregistrer le point hors combat, avec le personnage vivant.")
        return false
    end
    local position, problem = self:GetPlayerPosition()
    if not position then
        self:Notify(problem or "Position indisponible. Réessayer après le chargement.")
        return false
    end
    if expectedZoneId ~= nil and expectedZoneId ~= position.zoneId then
        self:Notify("La zone a changé. Rouvre les associations dans la zone voulue.") return false
    end
    if name ~= nil and (type(name) ~= "string" or not name:find("%S") or #name > 240) then
        self:Notify("Donne un nom court à ce point.") return false
    end
    local positions = self.db.rules.positions
    local existing, nearestDistance
    for _, point in ipairs(positions) do
        local samePreparation = preparation and point.contentId == preparation.contentId and point.encounterId == preparation.encounterId
            and point.stepId == preparation.stepId and point.routeId == preparation.routeId
        local sameLegacy = not preparation and point.contentId == nil and point.encounterId == nil and point.profileId == id
        if ValidPoint(point) and point.zoneId == position.zoneId and point.worldZoneId == position.worldZoneId and (samePreparation or sameLegacy) then
            local dx, dy, dz = position.x - point.x, position.y - point.y, position.z - point.z
            local distance = dx * dx + dy * dy + dz * dz
            if Finite(distance) and math.abs(dy) <= POINT_HEIGHT and distance <= POINT_RADIUS ^ 2 and (not nearestDistance or distance < nearestDistance) then
                existing, nearestDistance = point, distance
            end
        end
    end
    if not existing and #positions >= MAX_POINTS then self:Notify("Limite de 128 points atteinte. Supprime un ancien point.") return false end
    position.profileId, position.radius = id, POINT_RADIUS
    if preparation then
        position.contentId, position.encounterId = preparation.contentId, preparation.encounterId
        position.stepId, position.routeId = preparation.stepId, preparation.routeId
        position.slot = preparation.stepId and ("stage:" .. preparation.stepId) or ("prepare:" .. preparation.encounterId)
    end
    if existing then
        for key, value in pairs(position) do existing[key] = value end
        if name ~= nil then existing.name = name end
    else
        local used = {}
        for _, point in ipairs(positions) do used[point.id] = true end
        position.id = AllocatePointId(self.db.rules, used)
        position.name = name or ("Point " .. position.id:match("(%d+)$"))
        positions[#positions + 1] = position
    end
    RulesChanged(self, "Point enregistré ici. Le setup se déclenchera à proximité, à une hauteur similaire et hors combat.")
    return true
end

function R:BindPreparationPoint(contentId, encounterId, name, expectedZoneId, pageId)
    local content = type(self.GetCurrentContent) == "function" and self:GetCurrentContent() or nil
    if type(content) ~= "table" or content.id ~= contentId then
        self:Notify("Enregistre ce point dans le contenu de la rencontre choisie.") return false
    end
    local found
    for _, encounter in ipairs(content.encounters or {}) do
        if type(encounter) == "table" and encounter.id == encounterId and encounter.verified ~= false then found = true break end
    end
    if not found then self:Notify("Cette rencontre n’est pas disponible pour un point de préparation.") return false end
    local context = ContentContext(self, {})
    if context.problem then self:Notify(context.problem) return false end
    local selectedPage = pageId or context.pageId
    local profileId = selectedPage and type(self.GetAssignedProfile) == "function"
        and self:GetAssignedProfile(context.setupId or contentId, selectedPage, "prepare:" .. encounterId) or nil
    if not ValidProfile(self, profileId) then
        self:Notify("Associe d’abord un setup de préparation à cette rencontre dans la page choisie.") return false
    end
    return self:BindPosition(profileId, name, expectedZoneId, { contentId = contentId, encounterId = encounterId })
end

function R:BindRaidPreparationPoint(contentId, pageId, stepId, name, expectedZoneId)
    local current = self.GetCurrentContent and self:GetCurrentContent()
    if not current or current.id ~= contentId then self:Notify("Enregistre ce point dans le raid choisi."); return false end
    local step = self.GetRaidStep and self:GetRaidStep(contentId, pageId, stepId)
    if not step or step.kind ~= "boss" or type(step.encounterId) ~= "string" then self:Notify("Choisis une étape Boss reconnue dans ce parcours."); return false end
    local route = self:GetRaidRoute(contentId, pageId)
    local id = self:GetEffectiveRaidStepProfile(contentId, pageId, step.id)
    if not route or not ValidProfile(self, id) then self:Notify("Associe d’abord un setup à cette étape Boss."); return false end
    if self.bankTransfer or (self.IsSavingSetup and self:IsSavingSetup()) or ZoneFallbackProblem() then self:Notify("Attends la fin de l’action ou du combat du groupe."); return false end
    return self:BindPosition(id, name, expectedZoneId, { contentId = contentId, encounterId = step.encounterId, stepId = step.id, routeId = route.id })
end

function R:ClearPositionRule(id, expectedZoneId)
    EnsureRules(self)
    local zoneId, positions, removed = self:GetZoneId(), self.db.rules.positions, 0
    if not self.automation or not self.automation.worldReady or not ZoneIdentifier(zoneId) then
        self:Notify("Attends la fin du chargement avant de retirer ces points.") return 0
    end
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then
        self:Notify("La zone a changé. Rouvre les associations dans la zone voulue.") return 0
    end
    for index = #positions, 1, -1 do
        local point = positions[index]
        if type(point) == "table" and point.zoneId == zoneId and (id == nil or point.profileId == id) then
            table.remove(positions, index)
            removed = removed + 1
        end
    end
    local message = removed == 0 and "Aucun point à supprimer dans cette zone."
        or removed == 1 and "Un point supprimé dans cette zone."
        or tostring(removed) .. " points supprimés dans cette zone."
    if removed > 0 then RulesChanged(self, message) elseif self.Notify then self:Notify(message) end
    return removed
end

local function ZoneName(zoneId)
    local ok, name = pcall(GetZoneNameById, zoneId)
    local display = ok and DisplayName(name) or ""
    return display ~= "" and display or "Zone enregistrée"
end

function R:GetPointEntries(id)
    EnsureRules(self)
    local entries = {}
    for _, point in ipairs(self.db.rules.positions) do
        if id == nil or point.profileId == id then
            entries[#entries + 1] = {
                key = point.id, id = point.id, name = point.name, zoneId = point.zoneId,
                zoneName = ZoneName(point.zoneId), profileId = point.profileId,
                contentId = point.contentId, encounterId = point.encounterId,
                slot = point.slot, stepId = point.stepId, routeId = point.routeId,
                needsRerecording = point.needsRerecording == true or not ValidPoint(point),
            }
        end
    end
    table.sort(entries, function(a, b)
        if a.zoneName ~= b.zoneName then return a.zoneName < b.zoneName end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    return entries
end

function R:GetContentPointEntries(contentId, encounterId)
    local entries = {}
    for _, entry in ipairs(self:GetPointEntries()) do
        if entry.contentId == contentId and (encounterId == nil or entry.encounterId == encounterId) then entries[#entries + 1] = entry end
    end
    return entries
end

function R:GetRaidPreparationPoints(contentId, pageId, stepId)
    local route, step = self:GetRaidRoute(contentId, pageId), self:GetRaidStep(contentId, pageId, stepId)
    local entries = {}
    if not route or not step then return entries end
    for _, entry in ipairs(self:GetContentPointEntries(contentId)) do
        if entry.routeId == route.id and entry.stepId == step.id then entries[#entries + 1] = entry end
    end
    return entries
end

local function FindPoint(self, key, expectedZoneId)
    EnsureRules(self)
    for index, point in ipairs(self.db.rules.positions) do
        if point.id == key then
            if expectedZoneId ~= nil and point.zoneId ~= expectedZoneId then
                self:Notify("Ce point ne correspond plus à la zone choisie. Rouvre la liste des points.")
                return nil
            end
            return point, index
        end
    end
    self:Notify("Ce point n’existe plus. Rouvre la liste des points.")
end

function R:RemovePointById(key, expectedZoneId)
    local point, index = FindPoint(self, key, expectedZoneId)
    if not point then return false end
    table.remove(self.db.rules.positions, index)
    RulesChanged(self, "Point supprimé : " .. point.name .. ".")
    return true
end

function R:RenamePointById(key, name, expectedZoneId)
    local point = FindPoint(self, key, expectedZoneId)
    if not point then return false end
    if type(name) ~= "string" or not name:find("%S") or #name > 240 then
        self:Notify("Donne un nom court à ce point.") return false
    end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if point.name ~= name then
        point.name = name
        SavedDataChanged(self)
        if self.RefreshUI then self:RefreshUI() end
    end
    self:Notify("Point renommé : " .. point.name .. ".")
    return true
end

function R:GetKnownBossNames(expectedZoneId)
    EnsureRules(self)
    local zoneId = self:GetZoneId()
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then return {} end
    local names, seen = {}, {}
    local function Add(name)
        local key = self:NormalizeBossName(name)
        if key ~= "" and not seen[key] then seen[key] = true names[#names + 1] = DisplayName(name) end
    end
    for _, name in ipairs(self:GetObservedBossNames()) do Add(name) end
    for name in pairs(self.db.rules.bosses[zoneId] or {}) do Add(name) end
    for name in pairs(self.db.rules.trashAfterBosses[zoneId] or {}) do Add(name) end
    if self.automation and self.automation.zoneId == zoneId then Add(self.automation.previousBossName) end
    table.sort(names)
    return names
end

function R:BindTrashAfterBoss(id, name, expectedZoneId)
    EnsureRules(self)
    if not ValidProfile(self, id) then return false end
    local zoneId, key = self:GetZoneId(), self:NormalizeBossName(name)
    if not self.automation or not self.automation.worldReady or not ZoneIdentifier(zoneId) then
        self:Notify("Attends la fin du chargement avant d’associer un setup après un boss.") return false
    end
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then
        self:Notify("La zone a changé. Rouvre les associations dans la zone voulue.") return false
    end
    local known = false
    for _, knownName in ipairs(self:GetKnownBossNames(zoneId)) do
        if key ~= "" and self:NormalizeBossName(knownName) == key then known = true break end
    end
    if not known then self:Notify("Choisis un boss reconnu ou déjà associé dans cette zone.") return false end
    local associations = self.db.rules.trashAfterBosses[zoneId] or {}
    self.db.rules.trashAfterBosses[zoneId] = associations
    associations[key] = id
    RulesChanged(self, "Setup Trash associé après la victoire sur " .. DisplayName(name) .. ".")
    return true
end

function R:ClearTrashAfterBoss(name, expectedZoneId)
    EnsureRules(self)
    local zoneId, key = self:GetZoneId(), self:NormalizeBossName(name)
    if not self.automation or not self.automation.worldReady or not ZoneIdentifier(zoneId) then
        self:Notify("Attends la fin du chargement avant de retirer cette association.") return false
    end
    if expectedZoneId ~= nil and expectedZoneId ~= zoneId then
        self:Notify("La zone a changé. Rouvre les associations dans la zone voulue.") return false
    end
    local associations = self.db.rules.trashAfterBosses[zoneId]
    if key == "" or not associations or associations[key] == nil then
        self:Notify("Aucun setup Trash associé après ce boss.") return false
    end
    associations[key] = nil
    RulesChanged(self, "Association Trash après " .. DisplayName(name) .. " supprimée.")
    return true
end

function R:GetRuleCounts(id)
    EnsureRules(self)
    local counts = { zones = 0, bosses = 0, points = 0, trashAfterBosses = 0, total = 0 }
    for _, profileId in pairs(self.db.rules.zones) do if id == nil or profileId == id then counts.zones = counts.zones + 1 end end
    for _, mapName in ipairs({ "bosses", "trashAfterBosses" }) do
        for _, associations in pairs(self.db.rules[mapName]) do
            for _, profileId in pairs(associations) do if id == nil or profileId == id then counts[mapName] = counts[mapName] + 1 end end
        end
    end
    for _, point in ipairs(self.db.rules.positions) do if id == nil or point.profileId == id then counts.points = counts.points + 1 end end
    counts.total = counts.zones + counts.bosses + counts.points + counts.trashAfterBosses
    return counts
end

function R:GetRuleSummary(id)
    local count = self:GetRuleCounts(id).total
    return count == 0 and "Aucune association automatique" or count == 1 and "1 association automatique" or tostring(count) .. " associations automatiques"
end

function R:GetRuleDescriptions(id)
    EnsureRules(self)
    local descriptions = {}
    for zoneId, profileId in pairs(self.db.rules.zones) do
        if id == nil or profileId == id then descriptions[#descriptions + 1] = "Zone : " .. ZoneName(zoneId) end
    end
    for _, mapName in ipairs({ "bosses", "trashAfterBosses" }) do
        for zoneId, associations in pairs(self.db.rules[mapName]) do
            for name, profileId in pairs(associations) do
                if id == nil or profileId == id then
                    local prefix = mapName == "bosses" and "Boss : " or "Trash après victoire : "
                    descriptions[#descriptions + 1] = prefix .. DisplayName(name) .. " — " .. ZoneName(zoneId)
                end
            end
        end
    end
    for _, entry in ipairs(self:GetPointEntries(id)) do
        descriptions[#descriptions + 1] = "Point : " .. entry.name .. " — " .. entry.zoneName .. (entry.needsRerecording and " (à réenregistrer)" or "")
    end
    table.sort(descriptions)
    return descriptions
end

function R:ToggleAutomatic()
    EnsureRules(self)
    self.db.settings.automatic = self.db.settings.automatic ~= true
    if self.db.settings.automatic then self.automationDataMessage = nil end
    RulesChanged(self, self.db.settings.automatic and "Changements automatiques activés." or "Changements automatiques désactivés.", true)
    return self.db.settings.automatic
end

function R:InitializeAutomation()
    if self.automation then return end
    EnsureRules(self)
    local activated = type(IsPlayerActivated) ~= "function" or ReadBoolean(IsPlayerActivated) == true
    self.automation = { worldReady = activated and ReadBoolean(DoesUnitExist, "player") == true and self:GetZoneId() > 0 }
    local namespace = "RelaisAutomation"
    local function Evaluate() self:EvaluateAutomation() end
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_DEACTIVATED, function()
        self.automation.worldReady = false
        self:ResetAutomationContext("world")
        SetStatus(self, "Chargement de la zone…")
    end)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, function()
        self.automation.worldReady = true
        self:ResetAutomationContext("world")
        Evaluate()
    end)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_ZONE_CHANGED, Evaluate)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_BOSSES_CHANGED, Evaluate)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_COMBAT_STATE, Evaluate)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_DEAD, Evaluate)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ALIVE, Evaluate)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_RETICLE_TARGET_CHANGED, Evaluate)
    if EVENT_UNIT_DEATH_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag)
            if type(unitTag) == "string" and (unitTag == "player" or unitTag:match("^boss%d+$")) then Evaluate() end
        end)
    end
    EVENT_MANAGER:RegisterForUpdate(namespace, POLL_MS, Evaluate)
    Evaluate()
end
