-- Combat Bar : 初期化とイベント登録
local CB = CombatBar
local EM = EVENT_MANAGER
local NAME = CB.name

local SV
local registered = false
local slotRefreshPending = false

-- スロット関連のイベントは短時間にまとめて来るので1回にまとめる
local function ScheduleSlotRefresh()
    if slotRefreshPending then return end
    slotRefreshPending = true
    zo_callLater(function()
        slotRefreshPending = false
        CB.RefreshSlots()
        CB.RefreshIcons()
        CB.SyncPlayerBuffs()
    end, 50)
end

local function OnAbilityUsed(eventCode, slot)
    CB.OnAbilityUsed(eventCode, slot)
    CB.StartGCD()
end

local function OnUltChanged()
    CB.UpdateUltimate()
end

local function OnDeathChanged(_, _, isDead)
    if isDead then CB.ClearCast() end
end

local function OnUIModeChanged()
    -- ゲーム側の再配置が済んでから取り直す
    zo_callLater(function()
        CB.ForgetStandardAnchor()
        CB.ApplyLayout()
    end, 150)
end

local function OnQuickslotChanged()
    CB.UpdateQuickslot()
end

local function RegisterEvents()
    if registered then return end
    registered = true

    EM:RegisterForEvent(NAME .. "Effect", EVENT_EFFECT_CHANGED, CB.OnEffectChanged)
    EM:AddFilterForEvent(NAME .. "Effect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "Used", EVENT_ACTION_SLOT_ABILITY_USED, OnAbilityUsed)

    EM:RegisterForEvent(NAME .. "Active", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, ScheduleSlotRefresh)
    EM:RegisterForEvent(NAME .. "All", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, ScheduleSlotRefresh)
    EM:RegisterForEvent(NAME .. "Slot", EVENT_HOTBAR_SLOT_UPDATED, ScheduleSlotRefresh)
    EM:RegisterForEvent(NAME .. "Weapon", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, ScheduleSlotRefresh)

    EM:RegisterForEvent(NAME .. "Ult", EVENT_POWER_UPDATE, OnUltChanged)
    EM:AddFilterForEvent(NAME .. "Ult", EVENT_POWER_UPDATE,
        REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE,
        REGISTER_FILTER_UNIT_TAG, "player")
    EM:RegisterForEvent(NAME .. "UltCost", EVENT_ULTIMATE_ABILITY_COST_CHANGED, OnUltChanged)

    EM:RegisterForEvent(NAME .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathChanged)
    EM:AddFilterForEvent(NAME .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EM:RegisterForEvent(NAME .. "Mode", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnUIModeChanged)

    -- クイックスロット: 使用でクールダウン・残数が変わった時だけ更新
    EM:RegisterForEvent(NAME .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnQuickslotChanged)
    EM:AddFilterForEvent(NAME .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    if EVENT_ACTION_UPDATE_COOLDOWNS then
        EM:RegisterForEvent(NAME .. "Cd", EVENT_ACTION_UPDATE_COOLDOWNS, OnQuickslotChanged)
    end
    if EVENT_ACTIVE_QUICKSLOT_CHANGED then
        EM:RegisterForEvent(NAME .. "Qs", EVENT_ACTIVE_QUICKSLOT_CHANGED, OnQuickslotChanged)
    end
end

local fabNoticeDone = false
local function OnPlayerActivated()
    CB.CreateControls()
    -- Fancy Action Bar+ が有効なら、標準バー管理ともう一方のバー表示を最初に1度だけOFFにする
    if FancyActionBar and not SV.fabHandled then
        SV.fabHandled = true
        SV.manageStandardBar = false
        SV.showBack = false
        if not fabNoticeDone then
            fabNoticeDone = true
            d("[Combat Bar] " .. CB.T("FAB_DETECTED"))
        end
    end
    CB.RefreshSlots()
    CB.ApplyLayout()
    CB.RebuildWidgets()
    CB.SyncPlayerBuffs()
    CB.UpdateQuickslot()
    RegisterEvents()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= NAME then return end
    EM:UnregisterForEvent(NAME .. "Loaded", EVENT_ADD_ON_LOADED)

    SV = ZO_SavedVars:NewAccountWide(CB.svName, CB.svVersion, nil, CB.defaults)
    CB.sv = SV
    CB.SelectLanguage(SV)
    CB.SetSV(SV)
    CB.SetUISV(SV)
    CB.BuildMenu(SV)

    EM:RegisterForEvent(NAME .. "Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EM:RegisterForEvent(NAME .. "Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
