local AlabuzyaUI = AlabuzyaUI
-- Bundled QuestArrow 0.2.2 by alabuzya.
if not AlabuzyaUI.UseBundledQuestArrow then return end
local A = AlabuzyaUI.QuestArrow
local P, U = A.Planner, A.UI
A.name, A.version = "AlabuzyaUIQuestArrow", "0.2.2"
A.pending, A.targets, A.nodes = {}, {}, {}
A.generation, A.nextRequest, A.nextPlan, A.nextNodes = 0, 0, 0, 0
A.defaults = { x = 0.5, y = 0.27, scale = 1, alpha = 1, locked = true,
    travel = true, threshold = 1, questId = 0, debug = false }

local function now() return GetFrameTimeMilliseconds() / 1000 end
local function chat(text) d("|cFFD36AQuestArrow|r: " .. tostring(text)) end
local function formatted(text) return zo_strformat("<<1>>", text or "") end

function A:CancelRequests()
    for taskId in pairs(self.pending) do CancelRequestJournalQuestConditionAssistance(taskId) end
    self.pending = {}
    self.generation = self.generation + 1
end

function A:Invalidate()
    self.CrossTravel:Clear()
    self:CancelRequests()
    self.targets, self.nodes, self.plan = {}, {}, nil
    self.context, self.interval = nil, nil
    self.lastPlayer, self.targetList = nil, {}
    self.nextRequest, self.nextNodes, self.nextPlan = 0, 0, 0
end

function A:FindQuest()
    if not self.questId then return nil end
    for i = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i) and GetJournalQuestId(i) == self.questId then return i end
    end
end

function A:Stop()
    self:Invalidate()
    self.questId, self.questIndex = nil, nil
    self.saved.questId = 0
    U.root:SetHidden(self.saved.locked)
    U:UpdateButton()
end

function A:ToggleQuest(index)
    if not IsValidQuestIndex(index) then chat("Выберите задание в журнале.") return end
    local id = GetJournalQuestId(index)
    if not id or id == 0 then chat("Не удалось определить ID задания.") return end
    if self.questId == id then self:Stop() return end
    self:Invalidate()
    self.questId, self.questIndex, self.saved.questId = id, index, id
    self.manualKey = nil
    U:UpdateButton()
    chat("Навигация: " .. formatted(GetJournalQuestName(index)))
end

function A:MapKey()
    return tostring(GetCurrentMapId()) .. ":" .. tostring(GetMapFloorInfo()) .. ":" .. tostring(GetMapTileTexture(1))
end

function A:MapVisible()
    return ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing()
end

function A:EnsureMap()
    -- Never take control of a map the player is browsing.
    if self:MapVisible() then return false end
    if not DoesCurrentMapMatchMapForPlayerLocation() then
        local result = SetMapToPlayerLocation()
        if result == SET_MAP_RESULT_FAILED then return false end
        if result == SET_MAP_RESULT_MAP_CHANGED then CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") end
    end
    if not DoesCurrentMapMatchMapForPlayerLocation() then return false end
    local key = self:MapKey()
    if key ~= self.context then
        self:Invalidate()
        self.context = key
        local columns, rows = GetMapNumTiles()
        self.aspect = (rows and rows > 0) and columns / rows or 1
    end
    return true
end

function A:Player()
    local x, y, _, shown, symbolic = GetMapPlayerPosition("player")
    local point = { x = x, y = y }
    if shown and not symbolic and P.ValidPoint(point) then return point end
end

function A:RequestTargets()
    self:CancelRequests()
    self.targets = {}
    self.nextRequest = now() + 15
    local index = self.questIndex
    local complete = GetJournalQuestIsComplete(index)
    local function request(step, condition)
        local id = RequestJournalQuestConditionAssistance(index, step, condition)
        if id then
            self.pending[id] = { generation = self.generation, context = self.context,
                questId = self.questId, step = step, condition = condition, started = now() }
        end
    end
    if complete then
        request(QUEST_MAIN_STEP_INDEX, 1)
    else
        for step = QUEST_MAIN_STEP_INDEX, GetJournalQuestNumSteps(index) do
            for condition = 1, GetJournalQuestNumConditions(index, step) do
                local _, _, failed, done, _, visible = GetJournalQuestConditionValues(index, step, condition)
                if visible and not failed and not done then request(step, condition) end
            end
        end
    end
    self.nextPlan = 0
end

function A:OnPosition(taskId, pinType, x, y, radius, inside, breadcrumb, teleportNPCId, waypointId, symbolic)
    local request = self.pending[taskId]
    if not request then return end
    self.pending[taskId] = nil
    if request.generation ~= self.generation or request.questId ~= self.questId
        or request.context ~= self.context or self:MapKey() ~= self.context
        or self:MapVisible() or not DoesCurrentMapMatchMapForPlayerLocation() then return end
    local point = { x = x, y = y }
    -- A symbolic icon is not a geographical destination.
    if not inside or not P.ValidPoint(point) or pinType == MAP_PIN_TYPE_INVALID
        or symbolic == QUEST_PIN_STATE_IS_SYMBOLIC_POSITION then return end
    point.key = tostring(request.step) .. ":" .. tostring(request.condition)
    point.radius, point.breadcrumb = math.max(0, radius or 0), breadcrumb
    point.step, point.condition = request.step, request.condition
    point.text = GetJournalQuestConditionInfo(self.questIndex, request.step, request.condition)
    self.targets[point.key] = point
    self.nextPlan = 0
end

function A:RefreshNodes()
    self.nodes = {}
    self.nodeReason = "overland"
    self.nextNodes = now() + 30
    self.interval = nil
    -- Restrict automatic travel suggestions to the normal overland zone map.
    if (GetMapType() ~= MAPTYPE_ZONE and GetMapType() ~= MAPTYPE_SUBZONE) or GetMapContentType() ~= MAP_CONTENT_NONE
        or IsUnitInDungeon("player") or IsPlayerInAvAWorld() or IsActiveWorldBattleground() then
        self.nodeReason = "unsupported_map"
        return
    end
    local currentZone = GetCurrentMapZoneIndex()
    for id = 1, GetNumFastTravelNodes() do
        local known, name, x, y, _, _, kind, shown, locked = GetFastTravelNodeInfo(id)
        local zone = GetFastTravelNodePOIIndicies(id)
        local node = { id = id, name = formatted(name), x = x, y = y }
        if known and shown and not locked and kind == POI_TYPE_WAYSHRINE
            and (zone == currentZone or GetMapType() == MAPTYPE_SUBZONE) and P.ValidPoint(node) then
            node.outbound = GetFastTravelNodeOutboundOnlyInfo(id)
            self.nodes[#self.nodes + 1] = node
        end
    end
    self.interval = P.Interval(self.nodes, self.aspect)
end

function A:ChooseTarget(player)
    local list = {}
    for _, target in pairs(self.targets) do list[#list + 1] = target end
    table.sort(list, function(a, b)
        if a.step ~= b.step then return a.step < b.step end
        return a.condition < b.condition
    end)
    self.targetList = list
    if self.manualKey then
        for _, target in ipairs(list) do if target.key == self.manualKey then return target end end
    end
    -- Prefer the main step; keep the current branch until it disappears.
    local firstStep = list[1] and list[1].step
    local oldKey = self.plan and self.plan.target.key
    local best, distance
    for _, target in ipairs(list) do
        if target.step == firstStep then
            if target.key == oldKey then return target end
            local d = P.Distance(player, target, self.aspect)
            if not distance or d < distance then best, distance = target, d end
        end
    end
    return best
end

function A:CycleTarget()
    local list = self.targetList or {}
    if #list == 0 then chat("Доступных целей пока нет.") return end
    local current = self.plan and self.plan.target.key
    local selected = 1
    for i, target in ipairs(list) do if target.key == current then selected = i % #list + 1 end end
    self.manualKey, self.plan, self.nextPlan = list[selected].key, nil, 0
    chat("Цель " .. selected .. "/" .. #list .. ": " .. formatted(list[selected].text))
end

function A:Tick()
    if now() >= (self.nextUI or 0) then
        U:Journal()
        U:UpdateButton()
        self.nextUI = now() + 1
    end
    local hud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    local show = hud and (self.questId ~= nil or not self.saved.locked)
    U.root:SetHidden(not show)
    if not show then
        if self.context and self:MapVisible() then self:Invalidate() end
        return
    end
    if not self.questId then
        U:SetQuest("QuestArrow — перемещение")
        U:Arrow(0, true)
        U:Message("Перетащите рамку мышью", "/qa lock — закрепить")
        return
    end
    local index = self:FindQuest()
    if not index then self:Stop() chat("Задание больше не найдено в журнале.") return end
    if index ~= self.questIndex then self:Invalidate() self.questIndex = index end
    U:SetQuest(formatted(GetJournalQuestName(index)))
    if not self:EnsureMap() then
        U:Arrow(0, false) U:Message("Ожидание карты игрока", "Закройте карту для навигации") return
    end
    local player = self:Player()
    if not player then U:Arrow(0, false) U:Message("Позиция игрока недоступна", "") return end
    local t = now()
    -- Catch same-map teleports too; never keep the old departure after arrival elsewhere.
    if self.lastPlayer and P.Distance(player, self.lastPlayer, self.aspect) > 0.04 then
        self:Invalidate()
        self.context = self:MapKey()
    end
    self.lastPlayer = player
    if t >= self.nextNodes then self:RefreshNodes() end
    if t >= self.nextRequest then self:RequestTargets() end
    for id, request in pairs(self.pending) do
        if t - request.started > 5 then CancelRequestJournalQuestConditionAssistance(id) self.pending[id] = nil end
    end
    if t >= self.nextPlan then
        -- Wait for all results, otherwise the first network response wins branch selection.
        local target = next(self.pending) == nil and self:ChooseTarget(player) or nil
        if target then
            self.plan = self.CrossTravel:Plan(player,target,self.nodes,self.aspect,t)
                or P.Plan(player, target, self.nodes, self.aspect, self.saved, self.plan, t, self.interval)
            if self:MapKey() ~= self.context or not DoesCurrentMapMatchMapForPlayerLocation() then
                self:Invalidate()
                U:Arrow(0,false)
                U:Message("Ожидание восстановления карты", "")
                return
            end
        elseif next(self.pending) == nil then self.plan = nil end
        self.nextPlan = t + 1
    end
    if next(self.pending) ~= nil then
        U:Arrow(0, false) U:Message("Получаю метку задания…", "") return
    end
    local plan = self.plan
    if not plan then
        U:Arrow(0, false)
        U:Message("Нет доступной метки задания", "Проверьте карту; /qa refresh — повторить")
        return
    end
    local travel = plan.mode == "travel"
    local target = travel and plan.a or plan.target
    local distance = P.Distance(player, target, self.aspect)
    local arrived = distance <= (travel and math.min(0.008, plan.spacing * 0.05) or math.max(0.002, target.radius or 0))
    U:Arrow(P.Angle(player, target, self.aspect, GetPlayerCameraHeading()), not arrived, travel)
    local detail
    if travel then
        U:Message(arrived and "Переместитесь в" or "К святилищу",
            arrived and "Откройте святилище и выберите перенос" or ("Затем:\n" .. plan.b.name),
            arrived and plan.b.name or plan.a.name)
    else
        local title = target.breadcrumb and "К переходу по заданию" or (target.radius > 0 and "К области поиска" or "К цели задания")
        if arrived then title = target.radius > 0 and "Ищите цель в этой области" or "Вы у метки — выполните действие" end
        detail = string.format("~%.1f%% высоты карты", distance * 100)
        if self.targetList and #self.targetList > 1 then detail = detail .. " | /qa next: другая цель" end
        U:Message(title, detail)
    end
end

function A:Diagnostics()
    local count = 0
    for _ in pairs(self.targets) do count = count + 1 end
    chat("v" .. self.version .. "; API=" .. GetAPIVersion() .. "; quest=" .. tostring(self.questId)
        .. "; map=" .. self:MapKey() .. "; targets=" .. count .. "; nodes=" .. #self.nodes
        .. "; mode=" .. (self.plan and self.plan.mode or "none") .. "; error=" .. tostring(self.lastError))
    local x, y, heading, shown, symbolic = GetMapPlayerPosition("player")
    chat(string.format("player=(%.4f, %.4f), heading=%.3f, camera=%.3f, shown=%s, symbolic=%s", x, y, heading,
        GetPlayerCameraHeading(), tostring(shown), tostring(symbolic)))
    if self.plan then
        local q = self.plan.target
        chat(string.format("target %s=(%.4f, %.4f), radius=%.4f, breadcrumb=%s", q.key, q.x, q.y, q.radius, tostring(q.breadcrumb)))
        local reasons = {
            travel_disabled = "рекомендации выключены (/qa travel on)",
            search_area = "цель — область поиска",
            not_enough_nodes = "найдено меньше двух пригодных святилищ",
            no_spacing = "не удалось вычислить интервал святилищ",
            below_threshold = "дистанция меньше порога",
            no_useful_transfer = "перенос не даёт достаточного выигрыша",
            useful_transfer = "выгодный перенос найден",
            cross_zone = "прямой перенос к месту назначения в другой зоне",
        }
        chat("Решение: " .. (reasons[self.plan.reason] or tostring(self.plan.reason)))
        chat(string.format("direct=%.4f, spacing=%s, threshold=%s, travelCost=%s", self.plan.directDistance or self.plan.distance,
            tostring(self.plan.spacing), tostring(self.plan.threshold), tostring(self.plan.travelCost)))
    end
    chat("mapType=" .. tostring(GetMapType()) .. "; content=" .. tostring(GetMapContentType())
        .. "; zoneIndex=" .. tostring(GetCurrentMapZoneIndex()) .. "; dungeon=" .. tostring(IsUnitInDungeon("player"))
        .. "; nodeFilter=" .. tostring(self.nodeReason))
    local unknown, hidden, locked, wrongZone = 0, 0, 0, 0
    for id = 1, GetNumFastTravelNodes() do
        local known, _, _, _, _, _, kind, shown, isLocked = GetFastTravelNodeInfo(id)
        if kind == POI_TYPE_WAYSHRINE then
            if not known then unknown = unknown + 1
            elseif not shown then hidden = hidden + 1
            elseif isLocked then locked = locked + 1
            elseif GetMapType() ~= MAPTYPE_SUBZONE and GetFastTravelNodePOIIndicies(id) ~= GetCurrentMapZoneIndex() then wrongZone = wrongZone + 1 end
        end
    end
    chat(string.format("nodes excluded (whole API list): unknown=%d, hidden=%d, locked=%d, wrongZone=%d", unknown, hidden, locked, wrongZone))
    local cross=self.CrossTravel.diagnostic
    if cross then
        chat("destination: reason="..tostring(cross.reason).."; map="..tostring(cross.map).."; zone="..tostring(cross.zone)
            .."; node="..tostring(cross.node and cross.node.id).."; zoneNodes="..tostring(cross.zoneNodes)
            .."; anchor="..tostring(cross.anchor).."; error="..tostring(cross.error))
    end
end

function A:Command(input)
    local command, value = string.match(string.lower(input or ""), "^%s*(%S*)%s*(.-)%s*$")
    if command == "stop" then self:Stop()
    elseif command == "unlock" or command == "lock" then
        self.saved.locked = command == "lock" U:ApplySettings()
        chat(self.saved.locked and "Стрелка закреплена." or "Включите курсор клавишей . и перетащите рамку. /qa lock — закрепить.")
    elseif command == "reset" then
        self.saved.x, self.saved.y, self.saved.scale, self.saved.alpha = 0.5, 0.27, 1, 1 U:ApplySettings()
    elseif command == "scale" or command == "alpha" or command == "threshold" then
        local n = tonumber(value)
        local low, high = command == "alpha" and 0.2 or 0.5, command == "alpha" and 1 or 2
        if n and n >= low and n <= high then self.saved[command] = n U:ApplySettings() self.plan = nil self.nextPlan = 0
        else chat(command .. ": допустимо от " .. low .. " до " .. high) end
    elseif command == "travel" then
        if value == "on" or value == "off" then self.saved.travel = value == "on" self.plan = nil self.nextPlan = 0 end
        chat("Святилища: " .. (self.saved.travel and "включены" or "выключены"))
    elseif command == "next" then self:CycleTarget()
    elseif command == "refresh" then self.lastError = nil self:Invalidate()
    elseif command == "debug" then self:Diagnostics()
    elseif command == "track" or command == "" then
        local index
        if U.journal and not U.journal.control:IsHidden() then index = U.journal:GetSelectedQuestIndex() end
        if not index and QUEST_JOURNAL_MANAGER then index = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex() end
        if index then self:ToggleQuest(index) else chat("Выберите задание в журнале.") end
    else
        chat("/qa — выбранное/отслеживаемое задание; /qa stop; /qa unlock; /qa lock; /qa reset")
        chat("/qa next; /qa travel on|off; /qa threshold 0.5–2; /qa scale 0.5–2; /qa alpha 0.2–1; /qa refresh; /qa debug")
    end
end

function A:Initialize()
    if not AlabuzyaUI.Settings.StyleEnabled() or not AlabuzyaUI.Settings.Enabled("questArrow") then return end
    self.saved = AlabuzyaUI.SavedVariables.Character("questArrow", self.defaults)
    U:Create()
    U:Journal()
    SLASH_COMMANDS["/qa"] = function(input) self:Command(input) end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_POSITION_REQUEST_COMPLETE, function(_, ...) self:OnPosition(...) end)
    local function invalidate() self:Invalidate() end
    for _, event in ipairs({ EVENT_PLAYER_ACTIVATED, EVENT_PLAYER_DEACTIVATED, EVENT_QUEST_LIST_UPDATED,
        EVENT_QUEST_ADDED, EVENT_QUEST_REMOVED, EVENT_QUEST_ADVANCED, EVENT_QUEST_CONDITION_COUNTER_CHANGED,
        EVENT_QUEST_OPTIONAL_STEP_ADVANCED, EVENT_POI_DISCOVERED, EVENT_LINKED_WORLD_POSITION_CHANGED,
        EVENT_PATH_FINDING_NETWORK_LINK_CHANGED }) do
        EVENT_MANAGER:RegisterForEvent(self.name, event, invalidate)
    end
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", invalidate)
    EVENT_MANAGER:RegisterForEvent(self.name .. "Restore", EVENT_PLAYER_ACTIVATED, function()
        if not self.questId and self.saved.questId and self.saved.questId > 0 then
            self.questId = self.saved.questId
            self.questIndex = self:FindQuest()
            if not self.questIndex then self:Stop() end
        end
    end)
    EVENT_MANAGER:RegisterForUpdate(self.name, 50, function()
        if self.lastError then return end
        local ok, err = pcall(self.Tick, self)
        if not ok then
            self.lastError = tostring(err)
            U:Arrow(0, false)
            U:Message("Навигация приостановлена", "/qa debug — диагностика; /qa refresh — повторить")
            chat("Ошибка: " .. self.lastError)
        end
    end)
    chat("v" .. self.version .. " загружен. Кнопка в журнале; /qa help — команды.")
end

