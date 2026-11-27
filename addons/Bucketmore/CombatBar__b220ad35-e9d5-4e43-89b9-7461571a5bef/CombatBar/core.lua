-- Combat Bar : データ層(スロット解決・効果追跡・キャスト・ULT)
-- 表示には触れない。変更があれば CB.MarkChanged() を呼び、UI側が反映する。
local CB = CombatBar

local FIRST_SLOT = 3
local LAST_SLOT = 7
local ULT_SLOT = 8
local HB_FRONT = HOTBAR_CATEGORY_PRIMARY
local HB_BACK = HOTBAR_CATEGORY_BACKUP

CB.FIRST_SLOT, CB.LAST_SLOT, CB.ULT_SLOT = FIRST_SLOT, LAST_SLOT, ULT_SLOT
CB.HB_FRONT, CB.HB_BACK = HB_FRONT, HB_BACK

-- [hotbar][slot] = abilityId (0 = 空)
CB.slotIds = { [HB_FRONT] = {}, [HB_BACK] = {} }
-- [abilityId] = { units = { [unitKey] = endTime(0=時間なし) }, stacks = { [unitKey] = n }, beginTime = n, count = n }
CB.state = {}
CB.cast = nil -- { hotbar, slot, endTime, channel }

local trackedIds = {}   -- 追跡対象の能力ID
local trackedNames = {} -- 能力名 -> 能力ID (名前一致で効果IDのずれを吸収)
local overrideRev = {}  -- 効果ID -> 能力ID (手動設定)
local ownerCache = {}   -- 効果ID -> 能力ID or false

local SV -- 設定(Initialize後に設定)
function CB.SetSV(sv) SV = sv end

local function now() return GetGameTimeSeconds() end
CB.Now = now

-- スロットのスキルIDを取得
local function GetSlotAbilityId(slot, hotbar)
    local actionType = GetSlotType(slot, hotbar)
    if actionType == ACTION_TYPE_NOTHING then return 0 end
    local id = GetSlotBoundId(slot, hotbar)
    if actionType == ACTION_TYPE_CRAFTED_ABILITY and GetAbilityIdForCraftedAbilityId then
        id = GetAbilityIdForCraftedAbilityId(id)
    end
    return id or 0
end
CB.GetSlotAbilityId = GetSlotAbilityId

-- 全スロットを読み直し、追跡対象テーブルを組み立てる
function CB.RefreshSlots()
    trackedIds, trackedNames, overrideRev, ownerCache = {}, {}, {}, {}
    for _, hb in ipairs({ HB_FRONT, HB_BACK }) do
        local list = CB.slotIds[hb]
        for slot = FIRST_SLOT, ULT_SLOT do
            local id = GetSlotAbilityId(slot, hb)
            list[slot] = id
            if id > 0 then
                trackedIds[id] = true
                local name = GetAbilityName(id)
                if name and name ~= "" and not trackedNames[name] then
                    trackedNames[name] = id
                end
            end
        end
    end
    if SV then
        for abilityId in pairs(SV.widgets) do
            trackedIds[abilityId] = true
            local name = GetAbilityName(abilityId)
            if name and name ~= "" and not trackedNames[name] then trackedNames[name] = abilityId end
        end
        for abilityId, effectId in pairs(SV.effectOverride) do
            if effectId and effectId > 0 then
                overrideRev[effectId] = abilityId
                trackedIds[abilityId] = true
            end
        end
    end
end

local function ResolveOwner(effectId, effectName)
    local cached = ownerCache[effectId]
    if cached ~= nil then return cached end
    local owner = overrideRev[effectId]
    if not owner and trackedIds[effectId] then owner = effectId end
    if not owner then
        local name = effectName
        if not name or name == "" then name = GetAbilityName(effectId) end
        owner = trackedNames[name]
    end
    owner = owner or false
    ownerCache[effectId] = owner
    return owner
end

local function NewState()
    return { units = {}, stacks = {}, beginTime = 0, count = 0 }
end

local function CountUnits(st)
    local n = 0
    for _ in pairs(st.units) do n = n + 1 end
    st.count = n
end

-- 効果イベント(自分が発動した効果のみ。登録側でフィルタ)
function CB.OnEffectChanged(_, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, _, _, _, _, _, _, unitId, abilityId)
    local owner = ResolveOwner(abilityId, effectName)
    if not owner then return end

    local st = CB.state[owner]
    local key = (unitTag == "player") and "p" or (unitId or unitTag)

    if change == EFFECT_RESULT_FADED then
        if not st then return end
        st.units[key] = nil
        st.stacks[key] = nil
        CountUnits(st)
    elseif change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
        local timed = endTime and beginTime and endTime > beginTime
        -- 手動設定の効果は秒数フィルタを無視する
        if timed and not overrideRev[abilityId] then
            local dur = endTime - beginTime
            if SV and (dur < SV.durationMin or dur > SV.durationMax) then
                -- 範囲外の効果は時間表示の対象外。ただし効果中のハイライト用に時間なしで記録する
                timed = false
            end
        end
        if not st then st = NewState(); CB.state[owner] = st end
        st.units[key] = timed and endTime or 0
        st.beginTime = beginTime or 0
        if stackCount and stackCount > 0 then st.stacks[key] = stackCount else st.stacks[key] = nil end
        CountUnits(st)
    else
        return
    end
    CB.MarkChanged(true)
end

-- 現在のバフを読み直して状態を同期する(スロット変更後・ゾーン移動後)
function CB.SyncPlayerBuffs()
    for _, st in pairs(CB.state) do
        st.units["p"] = nil
        st.stacks["p"] = nil
        CountUnits(st)
    end
    for i = 1, GetNumBuffs("player") do
        local buffName, beginTime, endTime, _, stackCount, _, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("player", i)
        if castByPlayer then
            CB.OnEffectChanged(nil, EFFECT_RESULT_GAINED, 0, buffName, "player", beginTime, endTime, stackCount, nil, nil, nil, nil, nil, nil, 0, abilityId)
        end
    end
    CB.MarkChanged(true)
end

-- スキルの残り時間と状態を返す。 remain: 秒 / 0=時間なしで効果中 / nil=効果なし
function CB.GetEffectInfo(abilityId, t)
    local st = CB.state[abilityId]
    if not st or st.count == 0 then return nil end
    local maxEnd, timed, stacks = 0, false, 0
    for key, endTime in pairs(st.units) do
        if endTime > 0 then
            if endTime <= t then
                -- 期限切れの残り物を掃除
                st.units[key] = nil
                st.stacks[key] = nil
            else
                timed = true
                if endTime > maxEnd then maxEnd = endTime end
            end
        end
        local s = st.stacks[key]
        if s and s > stacks then stacks = s end
    end
    CountUnits(st)
    if st.count == 0 then return nil end
    if timed then return maxEnd - t, stacks, st.beginTime, maxEnd end
    return 0, stacks, st.beginTime, 0
end

-- 時間付きの効果が1つでもあるか(更新ループ継続判定)
function CB.HasTimedEffect(t)
    for abilityId, st in pairs(CB.state) do
        if st.count > 0 then
            for _, endTime in pairs(st.units) do
                if endTime > t then return true end
            end
        end
    end
    return false
end

-- キャスト/チャネル開始
function CB.OnAbilityUsed(_, slot)
    if not SV or not SV.showCast then return end
    if slot < FIRST_SLOT or slot > ULT_SLOT then return end
    local hb = GetActiveHotbarCategory()
    local id = GetSlotAbilityId(slot, hb)
    if id <= 0 then return end
    local isChannel, castMs, channelMs = GetAbilityCastInfo(id, nil, "player")
    castMs = castMs or 0
    channelMs = channelMs or 0
    local totalMs = (channelMs > castMs) and channelMs or castMs
    if totalMs > 0 then
        CB.cast = { hotbar = hb, slot = slot, endTime = now() + totalMs / 1000, channel = isChannel and true or false }
        CB.MarkChanged(true)
    end
end

function CB.ClearCast()
    if CB.cast then
        CB.cast = nil
        CB.MarkChanged(true)
    end
end

-- ULT
function CB.GetUltCost(hotbar)
    local id = CB.slotIds[hotbar] and CB.slotIds[hotbar][ULT_SLOT] or 0
    if id <= 0 then return 0 end
    return GetAbilityCost(id, COMBAT_MECHANIC_FLAGS_ULTIMATE, nil, "player") or 0
end

function CB.GetUltValue()
    local current = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
    return current or 0
end
