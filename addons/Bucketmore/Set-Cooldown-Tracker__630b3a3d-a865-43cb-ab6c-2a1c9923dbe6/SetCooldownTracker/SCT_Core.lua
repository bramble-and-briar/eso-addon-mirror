-- SetCooldownTracker v1.0.0 : コア(検知・CD管理)
SetCooldownTracker = SetCooldownTracker or {}
local SCT = SetCooldownTracker
local EM = EVENT_MANAGER
local ADDON = "SetCooldownTracker"
local TICK_NS = ADDON .. "_Tick"
local GLOBAL_NS = ADDON .. "_Global"

SCT.name = ADDON
SCT.version = "1.0.3"

local defaults = {
    enabled = true,
    showReady = true,
    readySeconds = 0,        -- 0 = READYを常時表示
    showUnknown = true,      -- ICD不明セットの経過時間表示
    useTooltipICD = true,    -- DBにICDが無い場合のみ、ツールチップ記載値を使う(*付き)
    resetOnDeath = true,
    resetOnZone = false,
    showTitle = true,
    posX = 75, posY = 30,    -- 画面内位置(%)
    width = 260, scale = 100, fontSize = 20, bgAlpha = 40,
}

local states, byAbility, bySetId = {}, {}, {}
local registered = {}
local rescanPending = false
local demoUntil = 0

-- 検知対象から外す結果種別(DoT/HoTの継続ティックはProc発動ではない)
local IGNORED_RESULTS = {}
local function IgnoreResult(const)
    if const ~= nil then IGNORED_RESULTS[const] = true end
end
IgnoreResult(ACTION_RESULT_DOT_TICK)
IgnoreResult(ACTION_RESULT_DOT_TICK_CRITICAL)
IgnoreResult(ACTION_RESULT_HOT_TICK)
IgnoreResult(ACTION_RESULT_HOT_TICK_CRITICAL)
IgnoreResult(ACTION_RESULT_EFFECT_FADED)   -- 戦闘イベント側の結果種別(EFFECT_RESULT_FADEDとは別物)

local ARMOR_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_NECK, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_HAND,
    EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
}

---------------------------------------------------------------------------
-- ツールチップからの内部CD解析(DBにICDが無い場合の補助。誤認防止のため「CD」を示す表現のみ)
---------------------------------------------------------------------------
local ICD_PATTERNS = {
    "once every (%d+%.?%d*) seconds?",
    "(%d+%.?%d*) seconds? cooldown",
    "cooldown of (%d+%.?%d*) seconds?",
    "(%d+%.?%d*)秒に1回",
    "(%d+%.?%d*)秒ごとに1回",
    "(%d+%.?%d*)秒間に1回",
    "クールダウン[はが]?(%d+%.?%d*)秒",
    "(%d+%.?%d*)秒のクールダウン",
}

local function ParseICD(text)
    if not text or text == "" then return nil end
    local lower = string.lower(text)
    for _, p in ipairs(ICD_PATTERNS) do
        local v = string.match(lower, p) or string.match(text, p)
        if v then
            local n = tonumber(v)
            if n and n > 0 and n < 600 then return n end
        end
    end
    return nil
end

local function ParseTooltip(st, link)
    st.tipDone = true
    local _, _, numBonuses = GetItemLinkSetInfo(link, false)
    if not numBonuses then return end
    for i = 1, numBonuses do
        local numRequired, desc = GetItemLinkSetBonusInfo(link, false, i)
        local icd = ParseICD(desc)
        if icd then
            st.tipICD = icd
            st.tipReq = numRequired
            return
        end
    end
end

---------------------------------------------------------------------------
-- 初期化(DBからインデックス構築)
---------------------------------------------------------------------------
local function BuildIndex()
    for _, e in ipairs(SCT.DB) do
        if e.abilityIds and #e.abilityIds > 0 and e.setIds and #e.setIds > 0 then
            local st = {
                entry = e, cdEnd = 0, lastProc = 0, equipped = false, pieces = 0,
                ignored = 0, procs = 0, setName = e.nameEn,
            }
            states[#states + 1] = st
            for _, id in ipairs(e.abilityIds) do byAbility[id] = st end
            for _, sid in ipairs(e.setIds) do bySetId[sid] = st end
        end
    end
end

---------------------------------------------------------------------------
-- 装備スキャン(自分の装備のみ。非アクティブバーの武器は数えない)
---------------------------------------------------------------------------
local function ScanEquipment()
    local counts, names, links = {}, {}, {}
    local function addSlot(slot, isWeapon)
        if not HasItemInSlot(BAG_WORN, slot) then return end
        local link = GetItemLink(BAG_WORN, slot)
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
        if hasSet and setId and setId > 0 and bySetId[setId] then
            local n = 1
            if isWeapon and GetItemLinkEquipType(link) == EQUIP_TYPE_TWO_HAND then n = 2 end
            counts[setId] = (counts[setId] or 0) + n
            names[setId] = setName
            links[setId] = links[setId] or link
        end
    end
    for _, slot in ipairs(ARMOR_SLOTS) do addSlot(slot, false) end
    local pair = GetActiveWeaponPairInfo()
    if pair and pair ~= 0 and pair ~= ACTIVE_WEAPON_PAIR_MAIN then
        addSlot(EQUIP_SLOT_BACKUP_MAIN, true)
        addSlot(EQUIP_SLOT_BACKUP_OFF, true)
    else
        addSlot(EQUIP_SLOT_MAIN_HAND, true)
        addSlot(EQUIP_SLOT_OFF_HAND, true)
    end
    return counts, names, links
end

function SCT:Rescan()
    local db = self.db
    if not db or not db.enabled then return end
    local counts, names, links = ScanEquipment()
    for _, st in ipairs(states) do
        local e = st.entry
        local pieces = 0
        for _, sid in ipairs(e.setIds) do pieces = pieces + (counts[sid] or 0) end
        st.pieces = pieces
        if pieces > 0 then
            for _, sid in ipairs(e.setIds) do
                if names[sid] then st.setName = names[sid] end
                if not st.tipDone and links[sid] then ParseTooltip(st, links[sid]) end
            end
        end
        local need = e.minPieces or st.tipReq or 5
        st.equipped = pieces >= need
        -- 有効ICDの決定: DB値を優先。無ければツールチップ値(設定ON時のみ)。どちらも無ければ不明。
        if e.icd then
            st.icd, st.icdMark = e.icd, ""
        elseif db.useTooltipICD and st.tipICD then
            st.icd, st.icdMark = st.tipICD, "*"
        else
            st.icd, st.icdMark = nil, ""
        end
    end
    self:SyncRegistrations()
    self:Refresh()
end

function SCT:ScheduleRescan(delay)
    if rescanPending then return end
    rescanPending = true
    zo_callLater(function()
        rescanPending = false
        SCT:Rescan()
    end, delay or 250)
end

---------------------------------------------------------------------------
-- イベント登録(装備中セットのAbility IDだけ。プレイヤー自身起因のみ)
---------------------------------------------------------------------------
local function OnEffectChanged(_, changeType, _, _, unitTag, _, _, _, _, _, _, _, _, _, _, abilityId, sourceType)
    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    SCT:OnProc(abilityId, "EFFECT")
end

local function OnCombatEvent(_, result, isError, _, _, _, _, sourceType, _, _, _, _, _, _, _, _, abilityId)
    if isError or IGNORED_RESULTS[result] then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    SCT:OnProc(abilityId, "COMBAT")
end

local function Register(id)
    local nsE, nsC = ADDON .. "_E" .. id, ADDON .. "_C" .. id
    EM:RegisterForEvent(nsE, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(nsE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_UNIT_TAG, "player")
    EM:RegisterForEvent(nsC, EVENT_COMBAT_EVENT, OnCombatEvent)
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE ~= nil then
        EM:AddFilterForEvent(nsC, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    else
        EM:AddFilterForEvent(nsC, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id)
    end
    registered[id] = true
end

local function Unregister(id)
    EM:UnregisterForEvent(ADDON .. "_E" .. id, EVENT_EFFECT_CHANGED)
    EM:UnregisterForEvent(ADDON .. "_C" .. id, EVENT_COMBAT_EVENT)
    registered[id] = nil
end

function SCT:SyncRegistrations()
    local needed = {}
    if self.db and self.db.enabled then
        for _, st in ipairs(states) do
            if st.equipped then
                for _, id in ipairs(st.entry.abilityIds) do needed[id] = true end
            end
        end
    end
    for id in pairs(needed) do
        if not registered[id] then Register(id) end
    end
    for id in pairs(registered) do
        if not needed[id] then Unregister(id) end
    end
end

---------------------------------------------------------------------------
-- Proc処理
---------------------------------------------------------------------------
function SCT:OnProc(abilityId, channel)
    local st = byAbility[abilityId]
    if not st or not st.equipped then return end
    local trig = st.entry.trigger
    if trig and trig ~= "ANY" and trig ~= channel then return end
    local now = GetGameTimeMilliseconds()
    if st.icd then
        -- CD中のイベントは無視(延長・再起動しない)
        if now < st.cdEnd then st.ignored = st.ignored + 1 return end
        st.cdEnd = now + math.floor(st.icd * 1000)
    else
        -- ICD不明: 500ms以内の重複(EFFECT/COMBAT二重検知・範囲ヒット)だけ除外
        if now - st.lastProc < 500 then st.ignored = st.ignored + 1 return end
    end
    st.lastProc = now
    st.procs = st.procs + 1
    self:Refresh()
end

function SCT:ClearAll()
    for _, st in ipairs(states) do
        st.cdEnd = 0
        st.lastProc = 0
    end
    self:Refresh()
end

---------------------------------------------------------------------------
-- 表示更新(必要な間だけ100msタイマーを動かす)
---------------------------------------------------------------------------
local function BuildRows(db, now)
    local rows, needTick = {}, false
    if demoUntil > now then
        rows[1] = { name = "Set A", text = "12.4s", r = 1, g = 0.7, b = 0.2, order = 1, key = 12.4 }
        rows[2] = { name = "Set B", text = "5.2s", r = 1, g = 0.7, b = 0.2, order = 1, key = 5.2 }
        rows[3] = { name = "Set C", text = "READY", r = 0.4, g = 1, b = 0.4, order = 3, key = 0 }
        table.sort(rows, function(a, b)
            if a.order ~= b.order then return a.order < b.order end
            return a.key < b.key
        end)
        return rows, true
    end
    for _, st in ipairs(states) do
        if st.equipped then
            if st.icd then
                if now < st.cdEnd then
                    local rem = (st.cdEnd - now) / 1000
                    rows[#rows + 1] = { name = st.setName, text = string.format("%.1fs%s", rem, st.icdMark),
                        r = 1, g = 0.7, b = 0.2, order = 1, key = rem }
                    needTick = true
                elseif db.showReady then
                    local show = false
                    if db.readySeconds == 0 then
                        show = true
                    elseif st.cdEnd > 0 and now < st.cdEnd + db.readySeconds * 1000 then
                        show = true
                        needTick = true
                    end
                    if show then
                        rows[#rows + 1] = { name = st.setName, text = "READY", r = 0.4, g = 1, b = 0.4,
                            order = 3, key = 0 }
                    end
                end
            elseif db.showUnknown then
                if st.lastProc > 0 and now - st.lastProc < 60000 then
                    rows[#rows + 1] = { name = st.setName, text = string.format("+%.1fs ?", (now - st.lastProc) / 1000),
                        r = 0.7, g = 0.7, b = 0.7, order = 2, key = now - st.lastProc }
                    needTick = true
                else
                    rows[#rows + 1] = { name = st.setName, text = "ICD ?", r = 0.7, g = 0.7, b = 0.7,
                        order = 2, key = 1e9 }
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        if a.key ~= b.key then return a.key < b.key end
        return a.name < b.name
    end)
    return rows, needTick
end

function SCT:Render()
    local db = self.db
    if not db or not db.enabled then
        self.UI:Hide()
        return false
    end
    local rows, needTick = BuildRows(db, GetGameTimeMilliseconds())
    self.UI:SetRows(rows)
    return needTick
end

function SCT:Refresh()
    if self:Render() then
        if not self.ticking then
            self.ticking = true
            EM:RegisterForUpdate(TICK_NS, 100, function() SCT:Tick() end)
        end
    elseif self.ticking then
        self.ticking = false
        EM:UnregisterForUpdate(TICK_NS)
    end
end

function SCT:Tick()
    if not self:Render() then
        self.ticking = false
        EM:UnregisterForUpdate(TICK_NS)
    end
end

function SCT:ShowDemo()
    demoUntil = GetGameTimeMilliseconds() + 15000
    self.UI:Layout(self.db)
    self:Refresh()
    zo_callLater(function() SCT:Refresh() end, 15100)
end

function SCT:ApplyLayout()
    self.UI:Layout(self.db)
    self:Refresh()
end

---------------------------------------------------------------------------
-- 有効/無効(OFF時は全イベント・タイマーを解除)
---------------------------------------------------------------------------
local function OnActivated()
    if SCT.db.resetOnZone then SCT:ClearAll() end
    SCT:ScheduleRescan(1500)
    zo_callLater(function() SCT:Rescan() end, 4000)
end

local function OnSlotUpdate() SCT:ScheduleRescan(250) end
local function OnHotbar() SCT:ScheduleRescan(150) end
local function OnDead() if SCT.db.resetOnDeath then SCT:ClearAll() end end
local function OnAlive() SCT:ScheduleRescan(500) end

function SCT:SetEnabled(enabled)
    self.db.enabled = enabled
    EM:UnregisterForEvent(GLOBAL_NS .. "_act", EVENT_PLAYER_ACTIVATED)
    EM:UnregisterForEvent(GLOBAL_NS .. "_slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EM:UnregisterForEvent(GLOBAL_NS .. "_bar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED)
    EM:UnregisterForEvent(GLOBAL_NS .. "_dead", EVENT_PLAYER_DEAD)
    EM:UnregisterForEvent(GLOBAL_NS .. "_alive", EVENT_PLAYER_ALIVE)
    if enabled then
        EM:RegisterForEvent(GLOBAL_NS .. "_act", EVENT_PLAYER_ACTIVATED, OnActivated)
        EM:RegisterForEvent(GLOBAL_NS .. "_slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
        EM:AddFilterForEvent(GLOBAL_NS .. "_slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
        EM:RegisterForEvent(GLOBAL_NS .. "_bar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnHotbar)
        EM:RegisterForEvent(GLOBAL_NS .. "_dead", EVENT_PLAYER_DEAD, OnDead)
        EM:RegisterForEvent(GLOBAL_NS .. "_alive", EVENT_PLAYER_ALIVE, OnAlive)
        self:Rescan()
    else
        self:SyncRegistrations()
        if self.ticking then
            self.ticking = false
            EM:UnregisterForUpdate(TICK_NS)
        end
        self.UI:Hide()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EM:UnregisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED)
    SCT.db = ZO_SavedVars:NewAccountWide("SetCooldownTrackerSV", 1, nil, defaults)
    SCT.defaults = defaults
    BuildIndex()
    SCT.UI:Create()
    SCT.UI:Layout(SCT.db)
    if SCT.InitSettings then SCT:InitSettings() end
    SCT:SetEnabled(SCT.db.enabled)
end

EM:RegisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
